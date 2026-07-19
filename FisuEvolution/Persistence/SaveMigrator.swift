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
            return try JSONDecoder().decode(PlayerState.self, from: migrateV2toV3(migrateV1toV2(data)))
        case 2:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV2toV3(data))
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

    /// v2 → v3: niveles de upgrades, cooldowns de boosts, daily y shares (F5).
    private static func migrateV2toV3(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SaveMigrationError.unsupportedVersion(2)
        }
        object["upgradeLevels"] = [:] as [String: Int]
        object["boostActivations"] = [:] as [String: Double]
        object["daily"] = ["cycleDay": 1] as [String: Any]
        object["sharesCompleted"] = 0
        if var upgrades = object["upgrades"] as? [String: Any] {
            upgrades["incomeMultiplier"] = upgrades["incomeMultiplier"] ?? 1.0
            upgrades["goldenChance"] = upgrades["goldenChance"] ?? 0.0
            upgrades["spawnDiscount"] = upgrades["spawnDiscount"] ?? 0.0
            upgrades["prestigeBonus"] = upgrades["prestigeBonus"] ?? 0.0
            object["upgrades"] = upgrades
        }
        object["schemaVersion"] = 3
        return try JSONSerialization.data(withJSONObject: object)
    }
}
