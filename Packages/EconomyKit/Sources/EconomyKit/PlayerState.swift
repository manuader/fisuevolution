import Foundation

/// Derived upgrade effects cached in the save (recomputed by UpgradeManager
/// from `meta.oroUpgradeLevels` × upgrades.json; bible §2.2 + las 7 líneas del plan).
public struct UpgradeState: Codable, Sendable, Equatable {
    public var offlineEfficiency: Double
    public var tapMultiplier: Double
    public var critChance: Double
    /// Multiplicador global de income de la línea de upgrade "income" (v3).
    public var incomeMultiplier: Double
    /// Chance de tap dorado (paga x10) de la línea "golden" (v3).
    public var goldenChance: Double
    /// Descuento de hire de la línea "spawn", 0…1 (v3).
    public var spawnDiscount: Double
    /// Bonus sobre el multiplicador por ORO de la línea "prestige" (v3).
    public var prestigeBonus: Double

    public init(
        offlineEfficiency: Double,
        tapMultiplier: Double,
        critChance: Double,
        incomeMultiplier: Double = 1.0,
        goldenChance: Double = 0.0,
        spawnDiscount: Double = 0.0,
        prestigeBonus: Double = 0.0
    ) {
        self.offlineEfficiency = offlineEfficiency
        self.tapMultiplier = tapMultiplier
        self.critChance = critChance
        self.incomeMultiplier = incomeMultiplier
        self.goldenChance = goldenChance
        self.spawnDiscount = spawnDiscount
        self.prestigeBonus = prestigeBonus
    }
}

/// Estado del daily reward (ciclo de 7 días).
public struct DailyRewardState: Codable, Sendable, Equatable {
    /// Día calendario del último claim, "yyyy-MM-dd" en el timezone del device.
    public var lastClaimDay: String?
    /// Posición 1…7 dentro del ciclo (el próximo claim usa este día).
    public var cycleDay: Int

    public init(lastClaimDay: String? = nil, cycleDay: Int = 1) {
        self.lastClaimDay = lastClaimDay
        self.cycleDay = cycleDay
    }
}

/// Lo que MUERE al reencarnar (F7 §6.2). La reencarnación es `run = .fresh(...)`:
/// imposible olvidarse de resetear (o de preservar) un campo.
///
/// Las unidades se guardan POR TIPO (`units`), nunca por posición/piso: la
/// ubicación se reconcilia contra el mapeo `floors[]` vigente en cada carga
/// (`TowerReconciler`), así un remapeo tier→piso entre versiones reacomoda
/// partidas en vez de romperlas (spec §3.1, default ⚠️10).
public struct RunState: Codable, Sendable, Equatable {
    public var coins: Double
    /// typeId → cantidad de instancias vivas. Fuente de verdad canónica.
    public var units: [String: Int]
    public var passiveUnlocked: [String: Bool]
    public var chosenCareerPath: String?
    /// Compras de hire POR PISO (floorId → count): curva de costo del piso.
    public var hireCounts: [String: Int]
    /// Tier máximo alcanzado en esta run; gatea events/specials/asado/daily.
    public var maxTierReached: Int
    /// Mejoras por personaje compradas con plata (typeId → nivel). ×2/nivel.
    public var charUpgradeLevels: [String: Int]
    /// Pisos desbloqueados, por ID de piso (nunca por índice ni tier: un remapeo
    /// futuro no re-bloquea lo ya desbloqueado — spec §3.8).
    public var unlockedFloors: [String]
    /// Modificadores temporales vivos (rewarded/eventos/boosts).
    public var activeModifiers: [ActiveModifier]
    /// Tipos que el jugador vio alguna vez EN ESTA RUN. La lista de mejoras se
    /// arma con esto y no con las unidades vivas: mergear tu último Fisura no
    /// tiene por qué borrarte de la pantalla la mejora que le compraste
    /// (RF-03). Tiene valor por defecto para que los saves v4 anteriores al
    /// campo decodifiquen; `TowerReconciler` los rellena en la carga.
    public var seenTypes: Set<String> = []

    public init(
        coins: Double,
        units: [String: Int],
        passiveUnlocked: [String: Bool],
        chosenCareerPath: String?,
        hireCounts: [String: Int],
        maxTierReached: Int,
        charUpgradeLevels: [String: Int],
        unlockedFloors: [String],
        activeModifiers: [ActiveModifier],
        seenTypes: Set<String> = []
    ) {
        self.coins = coins
        self.units = units
        self.passiveUnlocked = passiveUnlocked
        self.chosenCareerPath = chosenCareerPath
        self.hireCounts = hireCounts
        self.maxTierReached = maxTierReached
        self.charUpgradeLevels = charUpgradeLevels
        self.unlockedFloors = unlockedFloors
        self.activeModifiers = activeModifiers
        self.seenTypes = seenTypes
    }

    /// Run recién nacida: una unidad base, piso 1 desbloqueado. Reencarnar es
    /// exactamente esto, así que los vistos arrancan sólo con el tipo base.
    public static func fresh(startTypeId: String, startFloorId: String) -> RunState {
        RunState(
            coins: 0,
            units: [startTypeId: 1],
            passiveUnlocked: [:],
            chosenCareerPath: nil,
            hireCounts: [:],
            maxTierReached: 1,
            charUpgradeLevels: [:],
            unlockedFloors: [startFloorId],
            activeModifiers: [],
            seenTypes: [startTypeId]
        )
    }

    /// Total de unidades vivas en la torre.
    public var totalUnits: Int { units.values.reduce(0, +) }

    /// Registra un tipo como visto en esta run. Lo llama TODO camino que crea
    /// una unidad: contratar, mergear, los regalos de evento y los fixtures.
    public mutating func markSeen(_ typeId: String) { seenTypes.insert(typeId) }
}

/// Estadísticas de cuenta (no afectan gameplay).
public struct MetaStats: Codable, Sendable, Equatable {
    /// Ordinal máximo de piso alcanzado en la historia de la cuenta.
    public var maxFloorOrdinalEver: Int

    public init(maxFloorOrdinalEver: Int = 0) {
        self.maxFloorOrdinalEver = maxFloorOrdinalEver
    }
}

/// Lo que SOBREVIVE a la reencarnación (F7 §6.2): ORO, mejoras permanentes,
/// skins, entitlements, daily, stats.
public struct MetaState: Codable, Sendable, Equatable {
    /// Monotonically increasing across the whole account — never reset, not even by
    /// reincarnation. Drives ORO and CloudKit conflict resolution.
    public var lifetimeEarnings: Double
    /// Balance gastable de ORO (moneda de prestigio).
    public var oro: Int
    /// ORO ganado en la historia de la cuenta (monótono). El multiplicador global
    /// se computa sobre ESTO, no sobre el balance: gastar ORO nunca nerfea.
    public var oroEarnedLifetime: Int
    /// Cantidad de reencarnaciones.
    public var prestigeLevel: Int
    /// Niveles comprados por línea de mejora PERMANENTE (upgrades.json, en ORO).
    public var oroUpgradeLevels: [String: Int]
    /// Efectos derivados cacheados (recomputados por UpgradeManager en bootstrap).
    public var derivedEffects: UpgradeState
    /// 1 + oroEarnedLifetime × perOro × (1 + prestigeBonus). Cacheado.
    public var globalMultiplier: Double
    public var ownedSpecials: [String]
    /// Piso (id) al que quedó anclado visualmente cada special. Sin slot (⚠️5).
    public var specialAnchors: [String: String]
    /// Skins de IAP (cache de entitlements — StoreKit la REESCRIBE entera).
    public var ownedSkins: [String]
    /// Skins ganadas por milestone (separadas: StoreKit no debe pisarlas).
    public var milestoneSkins: [String]
    /// Skin activa POR TIPO de personaje (typeId → skinId). Una por tipo (⚠️7).
    public var activeSkinByType: [String: String]
    public var removedAds: Bool
    /// Última activación por boost id (cooldowns; sobreviven la reencarnación
    /// para evitar el exploit de resetear cooldowns reencarnando).
    public var boostActivations: [String: TimeInterval]
    public var daily: DailyRewardState
    public var sharesCompleted: Int
    public var lastSeenTimestamp: TimeInterval
    public var stats: MetaStats

    public init(
        lifetimeEarnings: Double,
        oro: Int,
        oroEarnedLifetime: Int,
        prestigeLevel: Int,
        oroUpgradeLevels: [String: Int],
        derivedEffects: UpgradeState,
        globalMultiplier: Double,
        ownedSpecials: [String],
        specialAnchors: [String: String],
        ownedSkins: [String],
        milestoneSkins: [String],
        activeSkinByType: [String: String],
        removedAds: Bool,
        boostActivations: [String: TimeInterval],
        daily: DailyRewardState,
        sharesCompleted: Int,
        lastSeenTimestamp: TimeInterval,
        stats: MetaStats
    ) {
        self.lifetimeEarnings = lifetimeEarnings
        self.oro = oro
        self.oroEarnedLifetime = oroEarnedLifetime
        self.prestigeLevel = prestigeLevel
        self.oroUpgradeLevels = oroUpgradeLevels
        self.derivedEffects = derivedEffects
        self.globalMultiplier = globalMultiplier
        self.ownedSpecials = ownedSpecials
        self.specialAnchors = specialAnchors
        self.ownedSkins = ownedSkins
        self.milestoneSkins = milestoneSkins
        self.activeSkinByType = activeSkinByType
        self.removedAds = removedAds
        self.boostActivations = boostActivations
        self.daily = daily
        self.sharesCompleted = sharesCompleted
        self.lastSeenTimestamp = lastSeenTimestamp
        self.stats = stats
    }

    /// Meta virgen de cuenta nueva.
    public static func fresh(offlineEfficiencyBase: Double, critChanceBase: Double, now: TimeInterval) -> MetaState {
        MetaState(
            lifetimeEarnings: 0,
            oro: 0,
            oroEarnedLifetime: 0,
            prestigeLevel: 0,
            oroUpgradeLevels: [:],
            derivedEffects: UpgradeState(
                offlineEfficiency: offlineEfficiencyBase,
                tapMultiplier: 1.0,
                critChance: critChanceBase
            ),
            globalMultiplier: 1.0,
            ownedSpecials: [],
            specialAnchors: [:],
            ownedSkins: [],
            milestoneSkins: [],
            activeSkinByType: [:],
            removedAds: false,
            boostActivations: [:],
            daily: DailyRewardState(),
            sharesCompleted: 0,
            lastSeenTimestamp: now,
            stats: MetaStats()
        )
    }

    /// Todas las skins que el jugador posee (IAP ∪ milestones).
    public var allOwnedSkins: Set<String> { Set(ownedSkins).union(milestoneSkins) }
}

/// The complete player save (schema v4, F7 "La Torre"): un sobre con dos
/// secciones — `run` muere al reencarnar, `meta` sobrevive. CoreData lo guarda
/// como JSON blob y el snapshot es la misma codificación.
public struct PlayerState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var run: RunState
    public var meta: MetaState

    public static let currentSchemaVersion = 4

    public init(schemaVersion: Int, run: RunState, meta: MetaState) {
        self.schemaVersion = schemaVersion
        self.run = run
        self.meta = meta
    }

    /// Registra un tipo como visto en la run actual (RF-03).
    public mutating func markSeen(_ typeId: String) { run.markSeen(typeId) }

    /// A fresh account: one starter unit, everything else at its baseline.
    /// The starter type id comes from data (`TierRepository.baseType`), never from code.
    public static func newGame(
        startTypeId: String,
        startFloorId: String,
        offlineEfficiencyBase: Double,
        critChanceBase: Double,
        now: TimeInterval
    ) -> PlayerState {
        PlayerState(
            schemaVersion: currentSchemaVersion,
            run: .fresh(startTypeId: startTypeId, startFloorId: startFloorId),
            meta: .fresh(offlineEfficiencyBase: offlineEfficiencyBase, critChanceBase: critChanceBase, now: now)
        )
    }
}
