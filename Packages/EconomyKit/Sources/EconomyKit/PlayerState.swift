import Foundation

/// A character occupying a board cell.
public struct BoardPlacement: Codable, Sendable, Equatable {
    public let cellIndex: Int
    public var typeId: String

    public init(cellIndex: Int, typeId: String) {
        self.cellIndex = cellIndex
        self.typeId = typeId
    }
}

/// Derived upgrade effects cached in the save (recomputed by UpgradeManager
/// from `upgradeLevels` × upgrades.json; bible §2.2 + las 7 líneas del plan).
public struct UpgradeState: Codable, Sendable, Equatable {
    public var offlineEfficiency: Double
    public var tapMultiplier: Double
    public var critChance: Double
    /// Multiplicador global de income de la línea de upgrade "income" (v3).
    public var incomeMultiplier: Double
    /// Chance de tap dorado (paga x10) de la línea "golden" (v3).
    public var goldenChance: Double
    /// Descuento de spawn de la línea "spawn", 0…1 (v3).
    public var spawnDiscount: Double
    /// Bonus sobre el multiplicador por soul point de la línea "prestige" (v3).
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

/// The complete player save, mirrored from build bible §2.2 plus fields required by
/// later phases (`lifetimeEarnings` for prestige, `maxTierReached` for progressive
/// spawn, skins for the store). This struct is the canonical save format: CoreData
/// stores it as a JSON blob and the snapshot backup is the same encoding.
public struct PlayerState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var coins: Double
    /// Monotonically increasing across the whole account — never reset, not even by
    /// prestige. Drives soul points and CloudKit conflict resolution.
    public var lifetimeEarnings: Double
    public var board: [BoardPlacement]
    public var passiveUnlocked: [String: Bool]
    public var chosenCareerPath: String?
    public var globalMultiplier: Double
    public var soulPoints: Int
    public var prestigeLevel: Int
    /// Spawn purchases per spawned type id (cost curve resets when the spawn tier advances).
    public var spawnPurchases: [String: Int]
    public var upgrades: UpgradeState
    /// Highest tier ever reached this run; input to the progressive-spawn mechanic.
    public var maxTierReached: Int
    public var lastSeenTimestamp: TimeInterval
    public var unlockedBackgrounds: [String]
    public var ownedSpecials: [String]
    public var ownedSkins: [String]
    public var activeSkin: String?
    public var removedAds: Bool
    /// Modificadores temporales vivos (rewarded/eventos/boosts) — schema v2.
    public var activeModifiers: [ActiveModifier]
    /// Niveles comprados por línea de upgrade (upgrades.json) — v3.
    public var upgradeLevels: [String: Int]
    /// Última activación por boost id (cooldowns de boosts.json) — v3.
    public var boostActivations: [String: TimeInterval]
    /// Estado del daily reward — v3.
    public var daily: DailyRewardState
    /// Shares completados (referral local de viral.json) — v3.
    public var sharesCompleted: Int

    public static let currentSchemaVersion = 3

    public init(
        schemaVersion: Int,
        coins: Double,
        lifetimeEarnings: Double,
        board: [BoardPlacement],
        passiveUnlocked: [String: Bool],
        chosenCareerPath: String?,
        globalMultiplier: Double,
        soulPoints: Int,
        prestigeLevel: Int,
        spawnPurchases: [String: Int],
        upgrades: UpgradeState,
        maxTierReached: Int,
        lastSeenTimestamp: TimeInterval,
        unlockedBackgrounds: [String],
        ownedSpecials: [String],
        ownedSkins: [String],
        activeSkin: String?,
        removedAds: Bool,
        activeModifiers: [ActiveModifier],
        upgradeLevels: [String: Int] = [:],
        boostActivations: [String: TimeInterval] = [:],
        daily: DailyRewardState = DailyRewardState(),
        sharesCompleted: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.coins = coins
        self.lifetimeEarnings = lifetimeEarnings
        self.board = board
        self.passiveUnlocked = passiveUnlocked
        self.chosenCareerPath = chosenCareerPath
        self.globalMultiplier = globalMultiplier
        self.soulPoints = soulPoints
        self.prestigeLevel = prestigeLevel
        self.spawnPurchases = spawnPurchases
        self.upgrades = upgrades
        self.maxTierReached = maxTierReached
        self.lastSeenTimestamp = lastSeenTimestamp
        self.unlockedBackgrounds = unlockedBackgrounds
        self.ownedSpecials = ownedSpecials
        self.ownedSkins = ownedSkins
        self.activeSkin = activeSkin
        self.removedAds = removedAds
        self.activeModifiers = activeModifiers
        self.upgradeLevels = upgradeLevels
        self.boostActivations = boostActivations
        self.daily = daily
        self.sharesCompleted = sharesCompleted
    }

    /// A fresh run: one starter unit on cell 0, everything else at its baseline.
    /// The starter type id comes from data (`TierRepository.baseType`), never from code.
    public static func newGame(
        startTypeId: String,
        offlineEfficiencyBase: Double,
        critChanceBase: Double,
        now: TimeInterval
    ) -> PlayerState {
        PlayerState(
            schemaVersion: currentSchemaVersion,
            coins: 0,
            lifetimeEarnings: 0,
            board: [BoardPlacement(cellIndex: 0, typeId: startTypeId)],
            passiveUnlocked: [:],
            chosenCareerPath: nil,
            globalMultiplier: 1.0,
            soulPoints: 0,
            prestigeLevel: 0,
            spawnPurchases: [:],
            upgrades: UpgradeState(
                offlineEfficiency: offlineEfficiencyBase,
                tapMultiplier: 1.0,
                critChance: critChanceBase
            ),
            maxTierReached: 1,
            lastSeenTimestamp: now,
            unlockedBackgrounds: ["alley"],
            ownedSpecials: [],
            ownedSkins: [],
            activeSkin: nil,
            removedAds: false,
            activeModifiers: []
        )
    }
}
