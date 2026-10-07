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

    static func version(of data: Data) throws -> Int {
        try JSONDecoder().decode(VersionPeek.self, from: data).schemaVersion
    }

    static func migrate(_ data: Data) throws -> PlayerState {
        let version = try Self.version(of: data)
        switch version {
        case PlayerState.currentSchemaVersion:
            return try JSONDecoder().decode(PlayerState.self, from: data)
        case 1:
            return try JSONDecoder().decode(
                PlayerState.self,
                from: migrateV5toV6(migrateV4toV5(migrateV3toV4(migrateV2toV3(migrateV1toV2(data)))))
            )
        case 2:
            return try JSONDecoder().decode(
                PlayerState.self, from: migrateV5toV6(migrateV4toV5(migrateV3toV4(migrateV2toV3(data))))
            )
        case 3:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV5toV6(migrateV4toV5(migrateV3toV4(data))))
        case 4:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV5toV6(migrateV4toV5(data)))
        case 5:
            return try JSONDecoder().decode(PlayerState.self, from: migrateV5toV6(data))
        default:
            throw SaveMigrationError.unsupportedVersion(version)
        }
    }

    /// Las seis pestañas de la v1. Un veterano las tiene todas (PLAN-v2 E3); es
    /// una foto, como `rebalanceLevelCaps`: no se lee de `GameScreen`.
    static let v1Tabs = ["jobs", "upgrades", "skins", "gifts", "store", "menu"]

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
    /// el cableado y no la función, y desde v5 los call sites son DOS:
    /// `migrateV3toV4` la aplica al diccionario ENTERO —un v3 es pre-rebalance
    /// por definición— y `migrateV4toV5` sólo a las LÍNEAS que superan su tope
    /// de hoy. Un v3 los cruza a los dos en la misma cadena y aun así se
    /// reescala una sola vez, porque acá abajo hay un `min(caps.actual, …)`:
    /// después de la primera pasada ninguna línea queda arriba del tope, así que
    /// el filtro del segundo call site devuelve el conjunto VACÍO. Y `migrate`
    /// despacha por versión, así que lo que se guarda después ya es v5 y no
    /// vuelve a entrar. `SaveMigratorTests` pinea las tres cosas.
    ///
    /// (Desde v6 lo que se guarda después es v6, pero el argumento no cambia: la
    /// cadena sigue estampando cada paso y `migrate` despacha por versión.)
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
            // v3 no tenía cooldown de videos: el que migra arranca con los cinco
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

    /// v4 → v5: alta de los campos del cofre, y la corrección de las skins
    /// doradas.
    ///
    /// ⚠️ **Lo que arregla.** Hasta v4 no había forma de distinguir un save
    /// escrito ANTES del rebalance de pacing de uno escrito después, así que uno
    /// pre-rebalance con `crit` entre 10 y 24 pasaba el `nivel >= maxLevel` de
    /// `awardEligibleMilestoneSkins` y se llevaba las 43 skins de oro sin
    /// haberlas ganado (deuda declarada en
    /// `Docs/PROMPT-merge-con-rebalance-pacing.md` §6, aceptada justamente a la
    /// espera de este bump). La huella detectable es un nivel POR ENCIMA del
    /// tope de hoy —imposible en un save post-rebalance—, y a esas líneas se les
    /// aplica el mismo reescalado proporcional que v3 → v4.
    ///
    /// ⚠️ **Lo que NO toca, y las dos veces por decisión del dueño.** El
    /// reescalado va LÍNEA POR LÍNEA y sólo sobre las que superan su tope
    /// actual, porque un save puede CRUZAR el rebalance: teniendo `crit 24` de
    /// antes, `income` se pudo comprar de 3 a 10 DESPUÉS —la compra lo permite
    /// porque 3 < 10— y esos siete niveles se pagaron con la curva nueva. Pasar
    /// el diccionario entero por el reescalado se los llevaba puestos
    /// (`income 10 → 5`). Quedan dos agujeros, los dos elegidos antes que
    /// tocarle un nivel a quien lo compró:
    ///
    /// 1. La línea parada EXACTAMENTE en el tope nuevo. `crit 10/25` (no
    ///    maxeado, pre-rebalance) y `crit 10/10` (maxeado, post-rebalance) son
    ///    idénticos en disco: ése sí puede seguir llevándose las doradas, y
    ///    separarlo pediría un campo que los saves viejos no tienen.
    /// 2. La línea pre-rebalance por DEBAJO del tope nuevo dentro de un save que
    ///    sí disparó la huella: `crit 7/25` se queda en 7 en vez de bajar a 3.
    ///    Ésa no regala doradas —7 no llega al `>= maxLevel` de 10— pero deja en
    ///    pie niveles que con la curva vieja salían mucho más baratos.
    private static func migrateV4toV5(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var meta = object["meta"] as? [String: Any],
              var run = object["run"] as? [String: Any]
        else { throw SaveMigrationError.unsupportedVersion(4) }

        let levels = meta["oroUpgradeLevels"] as? [String: Int] ?? [:]
        let porEncimaDelTope = levels.filter { id, nivel in
            guard let caps = rebalanceLevelCaps[id] else { return false }
            return nivel > caps.actual
        }
        if !porEncimaDelTope.isEmpty {
            meta["oroUpgradeLevels"] = levels.merging(
                rescaleUpgradeLevelsForRebalance(porEncimaDelTope)
            ) { _, reescalado in reescalado }
        }
        meta["chestsPending"] = 0
        meta["prestigeChestsPending"] = 0
        meta["welcomeChestGiven"] = false
        // Back-fill y NO cero, por decisión del dueño (2026-08-27). Con cero,
        // un save parado en el piso 8 cobraba cuatro cofres de golpe en el
        // primer merge — y dos saves igual de veteranos cobraban distinto,
        // porque `unlockedFloors` vive en `run` y muere al reencarnar: al
        // recién reencarnado la actualización lo agarraba en cero. Contando
        // los pisos que ya tiene, el veterano queda como el jugador nuevo: la
        // torre le paga del piso siguiente en adelante.
        //
        // El 2 va hardcodeado por lo mismo que `rebalanceLevelCaps`: un
        // migrador es una foto de un momento, y leer `floorsPerChest` de
        // `chests.json` haría que esta conversión cambiara de significado con
        // el próximo ajuste de la cadencia.
        let pisosYaAbiertos = (run["unlockedFloors"] as? [String])?.count ?? 0
        run["floorChestsAwarded"] = pisosYaAbiertos / 2

        object["meta"] = meta
        object["run"] = run
        object["schemaVersion"] = 5
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// v5 → v6 (la 2.0): sube la versión y fija los defaults que dependen de
    /// otros campos. El resto entra por `decodeIfPresent`.
    private static func migrateV5toV6(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var run = object["run"] as? [String: Any],
              var meta = object["meta"] as? [String: Any]
        else { throw SaveMigrationError.unsupportedVersion(5) }
        run["revealedTier"] = run["maxTierReached"] as? Int ?? 1
        meta["unlockedTabs"] = v1Tabs
        meta["purchasedOroReconstructed"] = false
        object["run"] = run
        object["meta"] = meta
        object["schemaVersion"] = 6
        return try JSONSerialization.data(withJSONObject: object)
    }
}
