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

/// Per-line upgrade levels stored in the save (build bible §2.2).
public struct UpgradeState: Codable, Sendable, Equatable {
    public var offlineEfficiency: Double
    public var tapMultiplier: Double
    public var critChance: Double

    public init(offlineEfficiency: Double, tapMultiplier: Double, critChance: Double) {
        self.offlineEfficiency = offlineEfficiency
        self.tapMultiplier = tapMultiplier
        self.critChance = critChance
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

    public static let currentSchemaVersion = 1

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
        removedAds: Bool
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
            removedAds: false
        )
    }
}
