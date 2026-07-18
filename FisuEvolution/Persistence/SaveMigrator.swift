import EconomyKit
import Foundation

enum SaveMigrationError: Error, Equatable {
    case unsupportedVersion(Int)
}

/// Schema migrations are a pure Codable concern: peek the version, then either
/// decode directly (current) or apply stepwise migrations (future v1→v2→…).
/// Unsupported versions throw, so the repository falls back to the snapshot —
/// progress is never destroyed by a bad decode.
enum SaveMigrator {
    private struct VersionPeek: Decodable {
        let schemaVersion: Int
    }

    static func migrate(_ data: Data) throws -> PlayerState {
        let version = try JSONDecoder().decode(VersionPeek.self, from: data).schemaVersion
        switch version {
        case PlayerState.currentSchemaVersion:
            return try JSONDecoder().decode(PlayerState.self, from: data)
        case 1:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV1toV2(data))
        default:
            throw SaveMigrationError.unsupportedVersion(version)
        }
    }

    /// v1 → v2: aparece `activeModifiers` (F4). Transformación por diccionario para
    /// no depender de un tipo `PlayerStateV1` congelado.
    private static func migrateV1toV2(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SaveMigrationError.unsupportedVersion(1)
        }
        object["activeModifiers"] = []
        object["schemaVersion"] = 2
        return try JSONSerialization.data(withJSONObject: object)
    }
}
