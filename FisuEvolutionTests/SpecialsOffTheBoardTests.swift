import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los especiales viven en el Álbum, no en el piso")
@MainActor
struct SpecialsOffTheBoardTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "offboard-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    @Test("el drop ya no ancla al especial a un piso")
    func theDropDoesNotAnchor() async throws {
        let gameState = await makeGameState()
        gameState.debugDropFirstSpecial()
        let special = try #require(gameState.content?.specials.specials.first)
        #expect(gameState.player?.meta.ownedSpecials.contains(special.id) == true)
        #expect(gameState.player?.meta.specialAnchors.isEmpty == true)
        #expect(gameState.specialDrop?.id == special.id, "la carta del drop sigue saliendo")
    }

    @Test("un save viejo con anclas decodifica y las ignora")
    func oldAnchorsStillDecode() async throws {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "anchors-\(UUID().uuidString).json")
        )
        var seeded = PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley",
            offlineEfficiencyBase: 0.35, critChanceBase: 0,
            now: Date().timeIntervalSince1970
        )
        seeded.meta.ownedSpecials = ["sp_arbolito"]
        seeded.meta.specialAnchors = ["sp_arbolito": "alley"]
        await repository.save(seeded)
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        #expect(gameState.player?.meta.ownedSpecials == ["sp_arbolito"])
        #expect(gameState.albumOwnedCount == 1)
    }
}
