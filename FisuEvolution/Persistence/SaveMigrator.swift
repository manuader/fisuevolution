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
            return try JSONDecoder().decode(PlayerState.self, from: migrateV3toV4(migrateV2toV3(migrateV1toV2(data))))
        case 2:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV3toV4(migrateV2toV3(data)))
        case 3:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV3toV4(data))
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

    /// v3 → v4 (F7 "La Torre"): split Run/Meta, board→units por tipo, soul
    /// points→ORO 1:1, skins global→por tipo. `unlockedFloors` queda vacío y el
    /// `TowerReconciler` lo puebla en la carga (corre en TODO load).
    private static func migrateV3toV4(_ data: Data) throws -> Data {
        guard let old = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SaveMigrationError.unsupportedVersion(3)
        }

        // board (posicional) → units (por tipo): el mapeo tier→piso vigente lo
        // resuelve el reconciliador, no la migración (spec ⚠️10).
        var units: [String: Int] = [:]
        for placement in old["board"] as? [[String: Any]] ?? [] {
            if let typeId = placement["typeId"] as? String {
                units[typeId, default: 0] += 1
            }
        }

        let soulPoints = old["soulPoints"] as? Int ?? 0
        let ownedSkins = old["ownedSkins"] as? [String] ?? []

        // Skin global legacy → aplicada a todos los tipos presentes (el jugador
        // la veía en todo el tablero; no pierde nada).
        var activeSkinByType: [String: String] = [:]
        if let legacy = old["activeSkin"] as? String {
            for typeId in units.keys {
                activeSkinByType[typeId] = legacy
            }
        }

        var run: [String: Any] = [
            "coins": old["coins"] as? Double ?? 0,
            "units": units,
            "passiveUnlocked": old["passiveUnlocked"] as? [String: Bool] ?? [:],
            // Curva de hire nueva por piso: arranca fresca (lo generoso).
            "hireCounts": [:] as [String: Int],
            "maxTierReached": old["maxTierReached"] as? Int ?? 1,
            "charUpgradeLevels": [:] as [String: Int],
            "unlockedFloors": [] as [String],
            "activeModifiers": old["activeModifiers"] as? [[String: Any]] ?? [],
        ]
        if let career = old["chosenCareerPath"] as? String {
            run["chosenCareerPath"] = career
        }

        let meta: [String: Any] = [
            "lifetimeEarnings": old["lifetimeEarnings"] as? Double ?? 0,
            // Soul points → ORO 1:1 (balance y earned — decisión ⚠️3).
            "oro": soulPoints,
            "oroEarnedLifetime": soulPoints,
            "prestigeLevel": old["prestigeLevel"] as? Int ?? 0,
            // Mejoras globales ya compradas se convierten nivel a nivel.
            "oroUpgradeLevels": old["upgradeLevels"] as? [String: Int] ?? [:],
            "derivedEffects": old["upgrades"] as? [String: Any] ?? [:],
            "globalMultiplier": old["globalMultiplier"] as? Double ?? 1.0,
            "ownedSpecials": old["ownedSpecials"] as? [String] ?? [],
            "specialAnchors": [:] as [String: String],
            "ownedSkins": ownedSkins,
            "milestoneSkins": [] as [String],
            "activeSkinByType": activeSkinByType,
            "removedAds": old["removedAds"] as? Bool ?? false,
            "boostActivations": old["boostActivations"] as? [String: Double] ?? [:],
            // v3 no tenía cooldown de videos: el que migra arranca con los cuatro
            // disponibles, que es lo generoso y lo que ya veía en pantalla.
            "rewardedActivations": [:] as [String: Double],
            "daily": old["daily"] as? [String: Any] ?? ["cycleDay": 1],
            "sharesCompleted": old["sharesCompleted"] as? Int ?? 0,
            "lastSeenTimestamp": old["lastSeenTimestamp"] as? Double ?? 0,
            "stats": ["maxFloorOrdinalEver": 0],
        ]

        let object: [String: Any] = [
            "schemaVersion": 4,
            "run": run,
            "meta": meta,
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }
}
