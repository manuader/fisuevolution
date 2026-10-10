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
            // Ídem `BoostUnlockTests`: la clave cruda tampoco es vacía, así que
            // "no vacío" deja pasar una vista que imprime "career.reward.welcome 1,2 M".
            #expect(!reward.previewText.contains("career.reward."), "\(option) dejó una clave cruda: '\(reward.previewText)'")
        }
    }

    @Test("el programador contrata gratis 2 minutos, sin mover la curva")
    func programmerHiresForFree() async throws {
        let gameState = await makeGameState()
        gameState.grantCareerReward(optionId: "junior_programmer", now: 0)
        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "career.junior_programmer" })
        #expect(modifier.effect == .freeHire)
        #expect(modifier.expiresAt == 120)
        #expect(gameState.careerRewards["junior_programmer"]?.kind == .freeHires)
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

    @Test("el abogado gana el juicio: 20 minutos de producción")
    func lawyerWinsTheLawsuit() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let before = try #require(gameState.player)
        let expected = GameState.coinPayout(minutes: 20, player: before, content: content)
        gameState.grantCareerReward(optionId: "junior_lawyer", now: 0)
        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins + expected)
        #expect(after.meta.lifetimeEarnings == before.meta.lifetimeEarnings + expected)
        #expect(gameState.careerRewards["junior_lawyer"]?.kind == .lawsuit)
    }

    @Test("el médico tiene obra social: inmune 30 min, corta el evento malo y cobra 15 min")
    func doctorGetsAHealthPlan() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let farFuture = Date().timeIntervalSince1970 + 3600
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.5, expiresAt: farFuture, sourceKey: "event.devaluacion")
        ]
        gameState.activeEvent = GameState.ActiveEvent(
            id: "devaluacion", phraseKey: "event.devaluacion.phrase", polarity: .negative,
            endsAt: farFuture, escapes: []
        )
        let before = try #require(gameState.player)
        let expected = GameState.coinPayout(minutes: 15, player: before, content: content)
        let now = Date().timeIntervalSince1970

        gameState.grantCareerReward(optionId: "junior_doctor", now: now)

        let after = try #require(gameState.player)
        #expect(after.run.activeModifiers.contains { $0.effect == .eventImmunity && $0.expiresAt == now + 1800 })
        #expect(!after.run.activeModifiers.contains { $0.sourceKey == "event.devaluacion" })
        #expect(gameState.activeEvent == nil)
        #expect(after.run.coins == before.run.coins + expected)
        #expect(gameState.careerRewards["junior_doctor"]?.kind == .healthPlan)
    }

    @Test("la obra social no frena a los eventos buenos, y vencida deja pasar a los malos")
    func healthPlanOnlyBlocksNegativeEventsWhileItLasts() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let now = Date().timeIntervalSince1970
        gameState.player?.run.raiseFrontier(to: content.tiers.maxTier)
        gameState.grantCareerReward(optionId: "junior_doctor", now: now)

        func drawable() throws -> Set<String> {
            let player = try #require(gameState.player)
            let pool = EventScheduler.eligible(
                catalog: content.events, state: player.meta.engagement.events, maxTier: player.run.maxTierReached,
                isImmune: ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now),
                isApplicable: { _ in true }
            )
            return Set(pool.map(\.id))
        }

        let immune = try drawable()
        #expect(immune.contains("plan_platita"))
        #expect(!immune.contains("devaluacion"))

        gameState.player?.run.activeModifiers.removeAll()

        #expect(try drawable().contains("devaluacion"))
    }

    @Test("cortar el evento malo no toca un buff en curso")
    func cuttingLeavesABuffAlone() async throws {
        let gameState = await makeGameState()
        gameState.activeEvent = GameState.ActiveEvent(
            id: "plan_platita", phraseKey: "event.plan_platita.phrase", polarity: .positive, endsAt: .infinity, escapes: []
        )
        gameState.cutNegativeEvents()
        #expect(gameState.activeEvent != nil)
    }

    /// La vista previa dice la plata que se cobra, no un descuento.
    @Test("la vista previa del abogado dice la plata que cobra")
    func lawyerPreviewSaysTheCoins() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let preview = try #require(gameState.careerRewards["junior_lawyer"]?.previewText)
        #expect(preview.contains(CoinFormatter.string(from: GameState.coinPayout(minutes: 20, player: player, content: content))))
        #expect(!preview.contains("career.reward"), "quedó la clave cruda")
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
