import Foundation

/// Reincarnation (bible §5): reaching god lets the player reset the run for
/// permanent soul points. `soulPoints` converges to `formula(lifetimeEarnings)`
/// — the gained amount is the delta, so points are never double-earned.
public enum PrestigeCalculator {
    public static func canPrestige(state: PlayerState, tiers: TierRepository) -> Bool {
        state.board.contains { $0.typeId == tiers.terminalType.id }
    }

    public static func soulPointsGained(state: PlayerState, economy: StandardEconomy) -> Int {
        max(0, economy.soulPoints(lifetimeEarnings: state.lifetimeEarnings) - state.soulPoints)
    }

    /// Resets the run (board, coins, spawns, passives, career, maxTier) and keeps
    /// the meta layer (soul points, upgrades, lifetime, purchases, cosmetics).
    public static func applyPrestige(
        state: inout PlayerState,
        economy: StandardEconomy,
        tiers: TierRepository,
        now: TimeInterval
    ) {
        let total = max(state.soulPoints, economy.soulPoints(lifetimeEarnings: state.lifetimeEarnings))
        state.soulPoints = total
        state.prestigeLevel += 1
        state.globalMultiplier = economy.globalMultiplier(soulPoints: total)
        state.coins = 0
        state.board = [BoardPlacement(cellIndex: 0, typeId: tiers.baseType.id)]
        state.spawnPurchases = [:]
        state.passiveUnlocked = [:]
        state.chosenCareerPath = nil
        state.maxTierReached = 1
        state.lastSeenTimestamp = now
    }
}

/// Data-driven prestige rewards (`prestige_unlocks.json`): per-level spawn cost
/// discount now; backgrounds/skins/secret specials consumed by F5 systems.
public struct PrestigeUnlocks: Codable, Sendable, Equatable {
    public struct Level: Codable, Sendable, Equatable {
        public let level: Int
        public let spawnCostDiscount: Double
        public let unlockBackgrounds: [String]
        public let unlockSkins: [String]
        public let unlockSpecials: [String]

        public init(level: Int, spawnCostDiscount: Double, unlockBackgrounds: [String], unlockSkins: [String], unlockSpecials: [String]) {
            self.level = level
            self.spawnCostDiscount = spawnCostDiscount
            self.unlockBackgrounds = unlockBackgrounds
            self.unlockSkins = unlockSkins
            self.unlockSpecials = unlockSpecials
        }
    }

    public let schemaVersion: Int
    /// Hard cap so stacked discounts never zero out the spawn cost. [TUNEABLE]
    public let spawnDiscountCap: Double
    public let levels: [Level]

    public init(schemaVersion: Int, spawnDiscountCap: Double, levels: [Level]) {
        self.schemaVersion = schemaVersion
        self.spawnDiscountCap = spawnDiscountCap
        self.levels = levels
    }

    /// Sum of discounts for every reached level, capped.
    public func cumulativeSpawnDiscount(atPrestigeLevel prestigeLevel: Int) -> Double {
        let sum = levels.filter { $0.level <= prestigeLevel }.map(\.spawnCostDiscount).reduce(0, +)
        return min(sum, spawnDiscountCap)
    }
}
