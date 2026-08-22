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

    /// Topes de las siete líneas ANTES y DESPUÉS del rebalance de pacing
    /// (2026-08-21), que bajó `income` y `tap` de 20 niveles a 10 y `crit` de 25
    /// a 10 con las magnitudes multiplicadas para que el efecto total no se
    /// moviera. Las dos formas van hardcodeadas acá porque un migrador es, por
    /// definición, una foto de un momento: leer el catálogo vigente haría que
    /// esta conversión cambiara de significado con el próximo rebalance.
    static let rebalanceLevelCaps: [String: (legacy: Int, actual: Int)] = [
        "income": (20, 10), "tap": (20, 10), "crit": (25, 10),
    ]

    /// Reescala PROPORCIONALMENTE los niveles de un save v3 a los topes de hoy.
    ///
    /// Proporcional y no un clamp, y el motivo es concreto:
    /// `GameState.awardEligibleMilestoneSkins` pregunta `nivel >= maxLevel`, y un
    /// save v3 arranca con `milestoneSkins` vacío (se resetea unas líneas más
    /// abajo). Con un clamp, cualquier save con `crit` ≥ 10 pasaría a contar como
    /// "las siete al tope" y se llevaría las skins doradas de "ganarlo al
    /// máximo" — y con la curva vieja (`3 × 2,5ⁿ`) llegar a crit 10 costaba
    /// ~19.100 ORO de los 1,776e10 que valía maxear esa línea: el 0,0001 %.
    ///
    /// Así, `crit 25/25` → `10/10` conserva el logro del que sí maxeó y
    /// `crit 10/25` → `4/10` no le regala nada al que no.
    ///
    /// ⚠️ **El redondeo no es neutro en los bordes, y se acepta a sabiendas.**
    /// Regala hasta un nivel arriba (`income`/`tap` 19 → 10 y `crit` 24 → 10
    /// quedan al tope sin haber estado) y destruye el último nivel abajo
    /// (`crit` 1 → 0). Las dos puntas son de UN nivel; la alternativa —guardar
    /// el nivel original para poder deshacer— pide un bump de schema.
    ///
    /// ⚠️ **Y no es idempotente**: cada pasada vuelve a dividir por el tope
    /// viejo, así que `crit 25 → 10 → 4 → 2 → 1 → 0`. Lo que la hace segura es
    /// el cableado y no la función: la llama UN SOLO call site (`migrateV3toV4`)
    /// y `migrate` despacha por versión, así que un save la cruza exactamente
    /// una vez y lo que se guarda después ya es v4. `SaveMigratorTests` pinea
    /// las dos cosas.
    static func rescaleUpgradeLevelsForRebalance(_ levels: [String: Int]) -> [String: Int] {
        var rescaled = levels
        for (id, caps) in rebalanceLevelCaps {
            guard let stored = levels[id] else { continue }
            let escalado = Double(stored) / Double(caps.legacy) * Double(caps.actual)
            rescaled[id] = min(caps.actual, max(0, Int(escalado.rounded())))
        }
        return rescaled
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
            // RF-03: lo que el jugador tenía en el tablero ya lo vio. Un save v3
            // no tiene el campo, así que se siembra acá (el reconciliador vuelve
            // a rellenarlo en la carga, pero la migración no depende de eso).
            "seenTypes": Array(units.keys),
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
            // Mejoras globales ya compradas: reescaladas al catálogo de hoy.
            "oroUpgradeLevels": rescaleUpgradeLevelsForRebalance(old["upgradeLevels"] as? [String: Int] ?? [:]),
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
