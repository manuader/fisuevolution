import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("GameState bootstrap")
@MainActor
struct GameStateTests {
    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "gs-\(UUID().uuidString).json")
        )
    }

    @Test func bootstrapStartsNewGameWithOneFisura() async throws {
        let gameState = GameState(repository: makeRepository())
        await gameState.bootstrap()

        #expect(gameState.phase == .ready)
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        #expect(player.coins == 0)
        #expect(player.prestigeLevel == 0)
        #expect(player.board == [BoardPlacement(cellIndex: 0, typeId: content.tiers.baseType.id)])
        #expect(player.upgrades.offlineEfficiency == content.economy.offlineEfficiencyBase)
    }

    @Test func bootstrapLoadsExistingSave() async throws {
        let repository = makeRepository()
        var existing = PlayerState.newGame(
            startTypeId: "homeless",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 1_700_000_000
        )
        existing.coins = 999
        // Daily ya reclamado hoy: este test verifica la carga del save, no el daily.
        existing.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        await repository.save(existing)

        let gameState = GameState(repository: repository)
        await gameState.bootstrap()

        #expect(gameState.phase == .ready)
        #expect(gameState.player?.coins == 999)
    }
}
