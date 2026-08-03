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
        #expect(player.run.coins == 0)
        #expect(player.meta.prestigeLevel == 0)
        // v4: el save guarda unidades POR TIPO; arranca con una del tipo base.
        #expect(player.run.units == [content.tiers.baseType.id: 1])
        #expect(player.run.unlockedFloors == ["alley"])
        #expect(player.meta.derivedEffects.offlineEfficiency == content.economy.offlineEfficiencyBase)
        // La torre reconciliada ubica esa unidad en el piso 1 (el visible al arrancar).
        #expect(gameState.visibleFloorOrdinal == 0)
        let placements = gameState.visiblePlacements
        #expect(placements.count == 1)
        #expect(placements.first?.typeId == content.tiers.baseType.id)
    }

    @Test func bootstrapLoadsExistingSave() async throws {
        let repository = makeRepository()
        var existing = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 1_700_000_000
        )
        existing.run.coins = 999
        // Daily ya reclamado hoy: este test verifica la carga del save, no el daily.
        existing.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        await repository.save(existing)

        let gameState = GameState(repository: repository)
        await gameState.bootstrap()

        #expect(gameState.phase == .ready)
        #expect(gameState.player?.run.coins == 999)
    }
}
