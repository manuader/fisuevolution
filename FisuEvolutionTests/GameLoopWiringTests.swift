import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// F2 wiring: GameState orquestando merge, carrera, pasivo, offline y prestige
/// sobre el contenido real bundleado. La matemática pura vive en EconomyKitTests;
/// acá se prueba la orquestación.
@Suite("GameState F2 wiring")
@MainActor
struct GameLoopWiringTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "wire-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    @Test func dropOnSameTypeMerges() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair() // 2 fisuras extra en celdas 1 y 2
        #expect(gameState.player?.board.count == 3)

        let resolution = gameState.handleDrop(fromCell: 1, toCell: 2)
        guard case .merged(let cell) = resolution else {
            Issue.record("expected merge, got \(resolution)")
            return
        }
        #expect(cell == 2)
        #expect(gameState.player?.board.count == 2)
        #expect(gameState.player?.board.contains { $0.typeId == "cartonero" } == true)
        #expect(gameState.player?.maxTierReached == 2)
        #expect(gameState.unitCount == 2)
    }

    @Test func dropOnEmptyCellMoves() async throws {
        let gameState = await makeGameState()
        let resolution = gameState.handleDrop(fromCell: 0, toCell: 7)
        guard case .moved = resolution else {
            Issue.record("expected move, got \(resolution)")
            return
        }
        #expect(gameState.player?.board == [BoardPlacement(cellIndex: 7, typeId: "homeless")])
    }

    @Test func dropOnDifferentTypeSnapsBack() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(2)
        gameState.debugGrantPair() // 2 cartoneros en 1 y 2
        let resolution = gameState.handleDrop(fromCell: 0, toCell: 1) // fisura → cartonero
        guard case .snapBack = resolution else {
            Issue.record("expected snapBack, got \(resolution)")
            return
        }
        #expect(gameState.player?.board.count == 3)
    }

    @Test func tier8MergeAsksForCareerAndResolvesAfterChoice() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(8)
        gameState.debugGrantPair() // 2 administrativos en 1 y 2

        let resolution = gameState.handleDrop(fromCell: 1, toCell: 2)
        guard case .careerPending = resolution else {
            Issue.record("expected careerPending, got \(resolution)")
            return
        }
        let prompt = try #require(gameState.careerPrompt)
        #expect(prompt.options.count == 4)
        // El board no cambió todavía (merge diferido, snap-back visual).
        #expect(gameState.player?.board.count == 3)

        gameState.chooseCareer(optionId: "junior_programmer")
        #expect(gameState.careerPrompt == nil)
        #expect(gameState.player?.chosenCareerPath == "programmer")
        #expect(gameState.player?.board.contains { $0.typeId == "junior_programmer" } == true)
        #expect(gameState.player?.maxTierReached == 9)
    }

    @Test func passiveUnlockMakesTickEarn() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        #expect(gameState.player?.passiveUnlocked["homeless"] == true)

        let coinsBefore = try #require(gameState.player?.coins)
        gameState.tick(delta: 1.0)
        let coinsAfter = try #require(gameState.player?.coins)
        #expect(abs(coinsAfter - coinsBefore - 0.3) < 1e-9)
    }

    @Test func hugeTickDeltaIsClamped() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        let coinsBefore = try #require(gameState.player?.coins)
        gameState.tick(delta: 3600)
        #expect(gameState.player?.coins == coinsBefore)
    }

    @Test func offlineSimulationCreditsAndPresentsPopup() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        gameState.debugSimulateOffline(hours: 4)

        let reward = try #require(gameState.offlineReward)
        // 1 fisura × 0.3/s × 4h × 0.5 efficiency (tolerancia: el reloj real avanza
        // unos ms entre bootstrap y apply).
        #expect(abs(reward.amount - 0.3 * 4 * 3600 * 0.5) < 1.0)
    }

    @Test func prestigeFlowResetsRun() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins() // suma lifetimeEarnings → habrá Soul Points
        gameState.debugSetMaxTier(30)
        gameState.debugGrantPair() // 2 dioses… con eso alcanza uno
        #expect(gameState.prestigeAvailable)
        #expect(gameState.prestigeSoulPointsGained > 0)

        gameState.confirmPrestige()
        #expect(gameState.player?.prestigeLevel == 1)
        #expect(gameState.player?.board.count == 1)
        #expect(gameState.player?.maxTierReached == 1)
        #expect(gameState.prestigeAvailable == false)
        #expect((gameState.player?.globalMultiplier ?? 0) > 1.0)
    }

    @Test func spawnQuoteAppliesPrestigeDiscount() async throws {
        let gameState = await makeGameState()
        let baseCost = try #require(gameState.spawnQuote?.cost)

        gameState.debugSetMaxTier(30)
        gameState.debugGrantPair()
        gameState.confirmPrestige()

        let discounted = try #require(gameState.spawnQuote?.cost)
        // prestige nivel 1 → 5% de descuento según prestige_unlocks.json
        #expect(abs(discounted - baseCost * 0.95) < 1e-9)
    }
}

@Suite("SaveMigrator")
struct SaveMigratorTests {
    @Test func currentVersionDecodes() throws {
        let state = PlayerState.newGame(startTypeId: "homeless", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0)
        let data = try JSONEncoder().encode(state)
        let migrated = try SaveMigrator.migrate(data)
        #expect(migrated == state)
    }

    @Test func futureVersionThrowsInsteadOfCorrupting() throws {
        var state = PlayerState.newGame(startTypeId: "homeless", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0)
        state.schemaVersion = 99
        let data = try JSONEncoder().encode(state)
        #expect(throws: SaveMigrationError.unsupportedVersion(99)) {
            try SaveMigrator.migrate(data)
        }
    }

    @Test func v1SaveMigratesToV2WithEmptyModifiers() throws {
        var state = PlayerState.newGame(startTypeId: "homeless", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0)
        state.coins = 77
        guard var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any] else {
            Issue.record("fixture no serializable")
            return
        }
        object.removeValue(forKey: "activeModifiers")
        object["schemaVersion"] = 1
        let v1Data = try JSONSerialization.data(withJSONObject: object)

        let migrated = try SaveMigrator.migrate(v1Data)
        #expect(migrated.schemaVersion == 2)
        #expect(migrated.coins == 77)
        #expect(migrated.activeModifiers.isEmpty)
    }
}
