import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Persistence round-trips")
struct PersistenceTests {
    private func makeState(coins: Double = 0) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 1_700_000_000
        )
        state.run.coins = coins
        return state
    }

    private func temporarySnapshotURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "snapshot-\(UUID().uuidString).json")
    }

    @Test func roundTripThroughCoreData() async {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL()
        )
        let state = makeState(coins: 1234)
        await repository.save(state)
        let loaded = await repository.load()
        #expect(loaded == .loaded(state))
    }

    @Test func saveOverwritesPreviousRecord() async {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL()
        )
        await repository.save(makeState(coins: 1))
        await repository.save(makeState(coins: 2))
        let loaded = await repository.load()
        #expect(loaded == .loaded(makeState(coins: 2)))
    }

    @Test func fallsBackToSnapshotWhenCoreDataIsEmpty() async throws {
        let snapshotURL = temporarySnapshotURL()
        let state = makeState(coins: 42)
        try JSONEncoder().encode(state).write(to: snapshotURL)

        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: snapshotURL
        )
        let loaded = await repository.load()
        #expect(loaded == .loaded(state))
    }

    @Test func returnsEmptyWithoutAnySave() async {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL()
        )
        let loaded = await repository.load()
        #expect(loaded == .empty)
    }

    @Test func corruptSnapshotDoesNotCrash() async throws {
        let snapshotURL = temporarySnapshotURL()
        try Data("no es json".utf8).write(to: snapshotURL)

        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: snapshotURL
        )
        let loaded = await repository.load()
        guard case .unreadable = loaded else {
            Issue.record("un snapshot corrupto es un save ilegible, no una partida vacía: \(loaded)")
            return
        }
    }

    @Test("cada carga buena deja una copia y quedan las últimas diez")
    func rotatesTheLastTenGoodLoads() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "backups-\(UUID().uuidString)")
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL(),
            backups: SaveBackupStore(directory: directory)
        )
        await repository.save(makeState(coins: 1))
        for _ in 0..<12 { _ = await repository.load() }
        let copies = try FileManager.default.contentsOfDirectory(atPath: directory.path())
            .filter { $0.hasPrefix("save-") }
        #expect(copies.count == SaveBackupStore.keptRotating)
    }

    @Test("la copia de antes de migrar se escribe una sola vez")
    func keepsThePremigrationCopyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "backups-\(UUID().uuidString)")
        let snapshot = temporarySnapshotURL()
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(makeState())) as? [String: Any])
        object["schemaVersion"] = 5
        let v5 = try JSONSerialization.data(withJSONObject: object)
        try v5.write(to: snapshot)
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true), snapshotURL: snapshot,
            backups: SaveBackupStore(directory: directory)
        )
        _ = await repository.load()
        _ = await repository.load()
        #expect(try Data(contentsOf: directory.appending(path: "save_v5_premigration.json")) == v5)
    }
}
