import CloudKit
import EconomyKit
import Foundation

/// Sync del save vía CloudKit (private DB, record único `main_save`), detrás de
/// `feature_flags.cloudKitEnabled`. F6 agrega el entitlement y flipea el flag;
/// con el flag apagado esta clase jamás toca CloudKit.
///
/// Estrategia (plan aprobado): push tras autosave, fetch al volver a foreground
/// ANTES de aplicar offline; conflictos con `SaveConflictResolver` (gana mayor
/// lifetimeEarnings, unión de compras/drops).
actor CloudSaveSync {
    static let recordType = "PlayerSave"
    static let recordName = "main_save"

    private let containerIdentifier: String
    private var container: CKContainer?

    init(containerIdentifier: String = "iCloud.com.manuader.fisuevolution") {
        self.containerIdentifier = containerIdentifier
    }

    private func database() -> CKDatabase {
        let container = self.container ?? CKContainer(identifier: containerIdentifier)
        self.container = container
        return container.privateCloudDatabase
    }

    /// Sube el estado actual, resolviendo `serverRecordChanged` con el resolver.
    func push(_ state: PlayerState) async {
        do {
            let payload = try JSONEncoder().encode(state)
            let recordID = CKRecord.ID(recordName: Self.recordName)
            let record: CKRecord
            if let existing = try? await database().record(for: recordID) {
                record = existing
            } else {
                record = CKRecord(recordType: Self.recordType, recordID: recordID)
            }
            record["snapshotJSON"] = String(decoding: payload, as: UTF8.self)
            record["lifetimeEarnings"] = state.meta.lifetimeEarnings
            record["lastSeenTimestamp"] = state.meta.lastSeenTimestamp
            record["schemaVersion"] = state.schemaVersion

            do {
                try await database().save(record)
            } catch let error as CKError where error.code == .serverRecordChanged {
                if let remote = try await fetch() {
                    let resolved = SaveConflictResolver.resolve(local: state, remote: remote)
                    if resolved.meta.lifetimeEarnings > remote.meta.lifetimeEarnings {
                        await push(resolved)
                    }
                }
            }
        } catch {
            Log.persistence.info("cloud push skipped: \(error.localizedDescription)")
        }
    }

    /// Baja el save remoto (nil si no hay o no se puede decodificar).
    func fetch() async throws -> PlayerState? {
        let recordID = CKRecord.ID(recordName: Self.recordName)
        do {
            let record = try await database().record(for: recordID)
            guard let json = record["snapshotJSON"] as? String else { return nil }
            return try SaveMigrator.migrate(Data(json.utf8))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }
}
