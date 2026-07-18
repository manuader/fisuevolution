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
        default:
            throw SaveMigrationError.unsupportedVersion(version)
        }
    }
}
