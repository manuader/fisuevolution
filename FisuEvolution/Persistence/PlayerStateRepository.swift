import EconomyKit
import Foundation

/// Save/load coordinator: CoreData is the primary store, a JSON snapshot in
/// Application Support is the crash-recovery backup. Load order: CoreData →
/// snapshot → nil (caller starts a new game). Progress is never lost silently —
/// every fallback is logged.
struct PlayerStateRepository: Sendable {
    let persistence: PersistenceController
    let snapshotURL: URL

    static func defaultSnapshotURL() -> URL {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "save_snapshot.json")
    }

    func save(_ state: PlayerState) async {
        let payload: Data
        do {
            payload = try JSONEncoder().encode(state)
        } catch {
            Log.persistence.error("failed to encode PlayerState: \(error)")
            return
        }
        do {
            try await persistence.save(payload: payload, schemaVersion: state.schemaVersion, updatedAt: Date())
        } catch {
            Log.persistence.error("CoreData save failed, snapshot is the only copy: \(error)")
        }
        do {
            try payload.write(to: snapshotURL, options: .atomic)
        } catch {
            Log.persistence.error("snapshot write failed: \(error)")
        }
    }

    func load() async -> PlayerState? {
        do {
            if let (payload, _) = try await persistence.loadLatest() {
                return try JSONDecoder().decode(PlayerState.self, from: payload)
            }
        } catch {
            Log.persistence.error("CoreData load failed, trying snapshot: \(error)")
        }
        do {
            let payload = try Data(contentsOf: snapshotURL)
            let state = try JSONDecoder().decode(PlayerState.self, from: payload)
            Log.persistence.warning("recovered save from JSON snapshot")
            return state
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            Log.persistence.error("snapshot unreadable, starting fresh: \(error)")
            return nil
        }
    }
}
