import EconomyKit
import Foundation

enum SaveLoadResult: Equatable, Sendable {
    case empty
    case loaded(PlayerState)
    case unreadable(UnreadableSave)
}

struct UnreadableSave: Equatable, Sendable {
    let reason: String
    let backupURL: URL?
}

/// Save/load coordinator: CoreData is the primary store, a JSON snapshot in
/// Application Support is the crash-recovery backup. Load order: CoreData →
/// snapshot → empty (caller starts a new game). Progress is never lost silently —
/// every fallback is logged.
struct PlayerStateRepository: Sendable {
    let persistence: PersistenceController
    let snapshotURL: URL
    var backups: SaveBackupStore?

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

    /// CoreData → snapshot. Un save que existe y no se puede leer NUNCA se trata
    /// como "no hay save": el arranque grabaría una partida nueva encima.
    func load() async -> SaveLoadResult {
        var failure: String?
        var unreadable: Data?
        do {
            if let (payload, _) = try await persistence.loadLatest() {
                if let state = decode(payload, failure: &failure) { return .loaded(state) }
                unreadable = payload
            }
        } catch {
            failure = "store: \(error)"
            Log.persistence.error("CoreData load failed, trying snapshot: \(error)")
        }
        do {
            let payload = try Data(contentsOf: snapshotURL)
            if let state = decode(payload, failure: &failure) {
                Log.persistence.warning("recovered save from JSON snapshot")
                return .loaded(state)
            }
            unreadable = unreadable ?? payload
        } catch CocoaError.fileReadNoSuchFile {
        } catch {
            failure = "snapshot: \(error)"
        }
        guard let failure else { return .empty }
        Log.persistence.critical("save unreadable, not overwriting: \(failure)")
        let backupURL = unreadable.flatMap { backups?.keepUnreadable($0) }
        return .unreadable(UnreadableSave(reason: failure, backupURL: backupURL))
    }

    private func decode(_ payload: Data, failure: inout String?) -> PlayerState? {
        do {
            let version = try SaveMigrator.version(of: payload)
            if version < PlayerState.currentSchemaVersion {
                backups?.keepPremigration(payload, version: version)
            }
            let state = try SaveMigrator.migrate(payload)
            backups?.rotate(payload)
            return state
        } catch {
            failure = "\(error)"
            Log.persistence.error("save payload unreadable: \(error)")
            return nil
        }
    }

    #if DEBUG
    func debugWriteUnreadableSave() async {
        let garbage = Data("{\"schemaVersion\": 5, \"run\": ".utf8)
        try? await persistence.save(payload: garbage, schemaVersion: 5, updatedAt: Date())
        try? garbage.write(to: snapshotURL, options: .atomic)
    }
    #endif
}
