import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Persistence round-trips")
struct PersistenceTests {
    private func makeState(coins: Double = 0) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: "homeless",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 1_700_000_000
        )
        state.coins = coins
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
        #expect(loaded == state)
    }

    @Test func saveOverwritesPreviousRecord() async {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL()
        )
        await repository.save(makeState(coins: 1))
        await repository.save(makeState(coins: 2))
        let loaded = await repository.load()
        #expect(loaded?.coins == 2)
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
        #expect(loaded == state)
    }

    @Test func returnsNilWithoutAnySave() async {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL()
        )
        let loaded = await repository.load()
        #expect(loaded == nil)
    }

    @Test func corruptSnapshotDoesNotCrash() async throws {
        let snapshotURL = temporarySnapshotURL()
        try Data("no es json".utf8).write(to: snapshotURL)

        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: snapshotURL
        )
        let loaded = await repository.load()
        #expect(loaded == nil)
    }
}
