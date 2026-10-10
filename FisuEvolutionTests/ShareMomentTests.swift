import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Compartir los momentos virales (PLAN-v2 E3): qué se ofrece, cuándo, y que el
/// premio se cobra una vez por momento.
@Suite("Compartir los momentos virales", .serialized)
@MainActor
struct ShareMomentTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "share-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        gameState.shareOffersEnabled = true
        return gameState
    }

    @Test("las claves con las que se recuerda lo compartido")
    func keys() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType)
        #expect(ShareMoment.newCharacter(base).key == "character.\(base.id)")
        #expect(ShareMoment.newFloor(floorID: "urban").key == "floor.urban")
        #expect(ShareMoment.reincarnation(level: 3).key == "reincarnation.3")
        #expect(ShareMoment.god(base).key == "god")
    }

    @Test("el premio del dato: cinco minutos de producción")
    func rewardComesFromTheData() async throws {
        let gameState = await makeGameState()
        #expect(gameState.content?.viral.momentRewardMinutes == 5)
    }

    @Test("el momento se ofrece en una pausa, nunca con una hoja arriba")
    func offeredOnlyWhenCalm() async {
        let gameState = await makeGameState()
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.uiCoversBoard = true
        gameState.refreshProjections()
        #expect(gameState.shareOffer == nil, "con una hoja abierta no se ofrece")
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.shareOffer == .newFloor(floorID: "urban"))
    }

    @Test("si caen dos en la misma celebración, se ofrece el más grande")
    func theBiggerMomentWins() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType)
        gameState.uiCoversBoard = true
        gameState.queueShareMoment(.newCharacter(base))
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.queueShareMoment(.newCharacter(base))
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.shareOffer == .newFloor(floorID: "urban"))
    }

    @Test("compartir paga una vez por momento y siempre suma al bonus viral")
    func paysOncePerMoment() async throws {
        let gameState = await makeGameState()
        let coins0 = try #require(gameState.player?.run.coins)
        let lifetime0 = try #require(gameState.player?.meta.lifetimeEarnings)

        gameState.registerShareCompleted(.newFloor(floorID: "urban"))
        let coins1 = try #require(gameState.player?.run.coins)
        #expect(gameState.player?.meta.lifetimeEarnings == lifetime0 + (coins1 - coins0),
                "el premio también cuenta en lo ganado de por vida")
        #expect(coins1 > coins0, "el primer share del momento paga")
        #expect(gameState.player?.meta.sharesCompleted == 1)
        #expect(gameState.player?.meta.engagement.sharedMoments.contains("floor.urban") == true)
        #expect(gameState.player?.meta.unlockedAchievements.contains("ach_share_1") == true,
                "el logro de compartir vuelve a ser posible")

        gameState.registerShareCompleted(.newFloor(floorID: "urban"))
        #expect(gameState.player?.run.coins == coins1, "el mismo momento no paga dos veces")
        #expect(gameState.player?.meta.sharesCompleted == 2, "pero el bonus viral sí cuenta")
    }

    @Test("un momento ya compartido no se vuelve a ofrecer")
    func aSharedMomentIsNotOfferedAgain() async {
        let gameState = await makeGameState()
        gameState.registerShareCompleted(.newFloor(floorID: "urban"))
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.refreshProjections()
        #expect(gameState.shareOffer == nil)
    }

    @Test("apagado (corridas de UI sin --uitest-share), no se ofrece nada")
    func disabledOffersNothing() async {
        let gameState = await makeGameState()
        gameState.shareOffersEnabled = false
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.refreshProjections()
        #expect(gameState.shareOffer == nil)
    }
}
