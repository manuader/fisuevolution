import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El panel de debug: las perillas de E2a y Fusionar todo")
@MainActor
struct DebugEconomyKnobsTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "knobs-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    /// Un dominio de `UserDefaults` propio: el `.standard` lo leen los
    /// `bootstrap` de las suites que corren al lado.
    private func scratch() throws -> (defaults: UserDefaults, name: String) {
        let name = "e2a-knobs-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test("las perillas cambian la economía en vivo y se guardan para el próximo arranque")
    func knobsApplyLiveAndPersist() async throws {
        let (defaults, name) = try scratch()
        defer { defaults.removePersistentDomain(forName: name) }
        let knobs = EconomyKnobs(defaultCostGrowth: 1.12, mergeRefundCounts: 1, priceReliefPurchases: 24)
        let gameState = await makeGameState()
        gameState.debugApplyEconomyKnobs(knobs, defaults: defaults)
        #expect(gameState.content?.economy.hire.priceReliefPurchases == 24)
        #expect(gameState.economy?.config.hire.mergeRefundCounts == 1)
        #expect(GameState.storedEconomyKnobs(in: defaults) == knobs)

        // Lo que hace `applyLaunchArgumentDefaults` al arrancar.
        let reopened = await makeGameState()
        reopened.debugApplyEconomyKnobs(GameState.storedEconomyKnobs(in: defaults), defaults: defaults)
        #expect(reopened.content?.economy.hire.defaultCostGrowth == 1.12)
    }

    @Test("volver a v1 deja el economy.json del bundle")
    func backToV1IsTheBundle() async throws {
        let (defaults, name) = try scratch()
        defer { defaults.removePersistentDomain(forName: name) }
        let gameState = await makeGameState()
        let bundled = try GameContentLoader.load(from: .main).economy
        gameState.debugApplyEconomyKnobs(EconomyKnobs(priceReliefPurchases: 24), defaults: defaults)
        gameState.debugApplyEconomyKnobs(EconomyKnobs(), defaults: defaults)
        #expect(gameState.content?.economy == bundled)
    }

    @Test("Fusionar todo encola todos los pares del piso visible, en cadena")
    func mergeAllQueuesEveryPair() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        #expect(gameState.debugMergeAllOnVisibleFloor() == 3)
        let queued = gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1)
        #expect(queued == 3)
    }
}
