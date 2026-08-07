import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// RF-15: elegir carrera en el piso corporativo tiene que definir algo. Las cuatro
/// ramas se reabsorben en el Director, así que lo único que puede diferenciarlas es
/// el premio de una vez — y tiene que ser de tipo distinto en cada una: cuatro
/// montos de plata distintos son otra vez la misma elección decorativa.
@Suite("Recompensa por elegir carrera")
@MainActor
struct CareerRewardTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "career-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("cada carrera da una recompensa, y las cuatro son de tipo distinto")
    func everyCareerGivesADifferentKindOfReward() async {
        let gameState = await makeGameState()
        let rewards = gameState.careerRewards

        #expect(rewards.count == 4)
        #expect(Set(rewards.values.map(\.kind)).count == 4, "cuatro variantes del mismo premio no son una elección")
    }

    @Test("la pantalla puede mostrar la recompensa antes de elegir")
    func everyRewardHasAPreview() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let options = try #require(content.tiers.type(id: "junior")?.choiceOptions)
        let rewards = gameState.careerRewards

        for option in options {
            let reward = try #require(rewards[option], "\(option) no tiene premio declarado")
            #expect(!reward.previewText.isEmpty, "\(option) no dice qué da: elegir a ciegas no es elegir")
        }
    }

    @Test("el programador cobra un cofre de plata")
    func programmerGetsACoinChest() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player?.run.coins)
        let earnedBefore = try #require(gameState.player?.meta.lifetimeEarnings)

        gameState.grantCareerReward(optionId: "junior_programmer", now: 1000)

        let after = try #require(gameState.player?.run.coins)
        let earnedAfter = try #require(gameState.player?.meta.lifetimeEarnings)
        #expect(after > before)
        // El cofre cuenta para el ORO como cualquier otra plata.
        #expect(earnedAfter > earnedBefore)
        #expect(gameState.careerRewards["junior_programmer"]?.kind == .coinChest)
    }

    @Test("el arquitecto se lleva una skin desbloqueada")
    func architectGetsASkin() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let career = try #require(content.careers.careers.first { $0.id == "junior_architect" })
        let skinId = try #require(career.skinId)
        #expect(gameState.player?.meta.allOwnedSkins.contains(skinId) == false)

        gameState.grantCareerReward(optionId: "junior_architect", now: 1000)

        #expect(gameState.player?.meta.allOwnedSkins.contains(skinId) == true)
        #expect(gameState.careerRewards["junior_architect"]?.kind == .skin)
    }

    /// "Gratis" tiene que ser literal: el regalo activa el boost pero no le come al
    /// jugador el cooldown, o el premio sería adelantarle algo que ya tenía.
    @Test("el médico activa un boost gratis sin gastar su cooldown")
    func doctorGetsAFreeBoost() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let career = try #require(content.careers.careers.first { $0.id == "junior_doctor" })
        let boostId = try #require(career.boostId)
        let boost = try #require(content.boosts.boosts.first { $0.id == boostId })

        gameState.grantCareerReward(optionId: "junior_doctor", now: 1000)

        let player = try #require(gameState.player)
        #expect(player.run.activeModifiers.contains { $0.sourceKey == "boost.\(boostId)" }, "el boost regalado no se activó")
        #expect(BoostManager.cooldownRemaining(of: boost, state: player, now: 1000) == 0, "el regalo no puede quemar el cooldown")
        #expect(gameState.careerRewards["junior_doctor"]?.kind == .freeBoost)
    }

    @Test("el abogado consigue contratar más barato un rato")
    func lawyerGetsATemporaryModifier() async throws {
        let gameState = await makeGameState()

        gameState.grantCareerReward(optionId: "junior_lawyer", now: 1000)

        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "career.junior_lawyer" })
        #expect(modifier.effect == .spawnCostMultiplier)
        #expect(modifier.magnitude < 1, "un modificador de costo mayor a 1 sería un castigo, no un premio")
        #expect(modifier.expiresAt > 1000)
        #expect(gameState.careerRewards["junior_lawyer"]?.kind == .temporaryModifier)
    }

    /// El descuento se muestra como descuento y no como el factor crudo: la pieza
    /// compartida ya sabe que 0,5 es −50%.
    @Test("el premio del abogado se lee como descuento")
    func lawyerPreviewReadsAsDiscount() async throws {
        let gameState = await makeGameState()
        let preview = try #require(gameState.careerRewards["junior_lawyer"]?.previewText)

        #expect(preview.contains("50%"))
        #expect(!preview.contains("0,5"))
    }

    /// El premio se paga una sola vez: la carrera dura hasta la reencarnación y
    /// nada vuelve a llamar acá, pero la skin ya acreditada no se duplica.
    @Test("acreditar dos veces la misma skin no la duplica")
    func skinIsCreditedOnce() async throws {
        let gameState = await makeGameState()
        gameState.grantCareerReward(optionId: "junior_architect", now: 1000)
        let after = try #require(gameState.player?.meta.milestoneSkins)

        gameState.grantCareerReward(optionId: "junior_architect", now: 2000)

        #expect(gameState.player?.meta.milestoneSkins == after)
    }
}
