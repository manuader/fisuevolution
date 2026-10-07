import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Save ilegible: nunca se pisa")
@MainActor
struct SaveRecoveryTests {
    private let garbage = Data("{\"schemaVersion\": 5, \"run\": ".utf8)

    private func unreadableGame() async throws -> (GameState, URL, URL) {
        let snapshot = FileManager.default.temporaryDirectory.appending(path: "rec-\(UUID().uuidString).json")
        let backups = FileManager.default.temporaryDirectory.appending(path: "rec-backups-\(UUID().uuidString)")
        try garbage.write(to: snapshot)
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: snapshot,
            backups: SaveBackupStore(directory: backups)
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return (gameState, snapshot, backups)
    }

    @Test("un save que no decodifica deja la partida en recuperación, sin jugador")
    func unreadableSaveEntersRecovery() async throws {
        let (gameState, _, _) = try await unreadableGame()
        #expect(gameState.isRecoveryPending)
        #expect(gameState.player == nil)
    }

    @Test("en recuperación no se escribe nada")
    func recoveryBlocksEveryWrite() async throws {
        let (gameState, snapshot, _) = try await unreadableGame()
        await gameState.persistNow()
        #expect(try Data(contentsOf: snapshot) == garbage)
    }

    @Test("empezar de nuevo arranca una partida y la copia ilegible queda")
    func startOverKeepsTheCopy() async throws {
        let (gameState, _, backups) = try await unreadableGame()
        await gameState.startOverFromRecovery()
        #expect(gameState.phase == .ready)
        #expect(gameState.player != nil)
        let kept = try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("unreadable-") }
        #expect(try kept.map { try Data(contentsOf: $0) } == [garbage])
    }

    @Test("reintentar con el save arreglado lo carga")
    func retryLoadsAFixedSave() async throws {
        let (gameState, snapshot, _) = try await unreadableGame()
        var state = PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: Date().timeIntervalSince1970
        )
        state.run.coins = 777
        try JSONEncoder().encode(state).write(to: snapshot)
        await gameState.retryLoad()
        #expect(gameState.phase == .ready)
        #expect((gameState.player?.run.coins ?? 0) >= 777)
    }
}
