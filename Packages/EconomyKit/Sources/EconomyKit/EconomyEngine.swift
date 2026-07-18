import Foundation

/// Pure economy math shared by the game, the tier generator and the balance simulator.
/// No UIKit, no SpriteKit, no side effects — everything is testable in isolation.
public protocol EconomyCalculating: Sendable {
    func tapYield(forTier tier: Int) -> Double
    func passiveYield(forTier tier: Int) -> Double
    func passiveUnlockCost(forTier tier: Int) -> Double
    /// Progressive-spawn: which tier the shop currently offers.
    func spawnTier(maxTierReached: Int) -> Int
    /// Cost of the next spawn purchase of `tier`, after `purchases` prior purchases of it.
    func spawnCost(spawnTier tier: Int, purchases: Int) -> Double
    func soulPoints(lifetimeEarnings: Double) -> Int
    func globalMultiplier(soulPoints: Int) -> Double
}

/// The standard implementation of the build-bible §3 formulas.
///
///     tapYield(t)          = baseTapYieldTier1 × yieldGrowthPerTier^(t−1)
///     passiveYield(t)      = tapYield(t) × passiveRatio
///     passiveUnlockCost(t) = tapYield(t) × passiveUnlockCostMultiplier
///     spawnTier            = max(1, maxTierReached − spawn.tierOffset)
///     spawnCost(t, n)      = spawn.baseCost × tapYield(t)/tapYield(1) × spawn.costGrowth^n
///     soulPoints           = floor((lifetimeEarnings / divisor)^exponent)
///     globalMultiplier     = 1 + soulPoints × globalMultiplierPerSoulPoint
public struct StandardEconomy: EconomyCalculating {
    public let config: EconomyConfig

    public init(config: EconomyConfig) {
        self.config = config
    }

    public func tapYield(forTier tier: Int) -> Double {
        config.baseTapYieldTier1 * pow(config.yieldGrowthPerTier, Double(tier - 1))
    }

    public func passiveYield(forTier tier: Int) -> Double {
        tapYield(forTier: tier) * config.passiveRatio
    }

    public func passiveUnlockCost(forTier tier: Int) -> Double {
        tapYield(forTier: tier) * config.passiveUnlockCostMultiplier
    }

    public func spawnTier(maxTierReached: Int) -> Int {
        max(1, maxTierReached - config.spawn.tierOffset)
    }

    public func spawnCost(spawnTier tier: Int, purchases: Int) -> Double {
        let tierScale = tapYield(forTier: tier) / tapYield(forTier: 1)
        return config.spawn.baseCost * tierScale * pow(config.spawn.costGrowth, Double(purchases))
    }

    public func soulPoints(lifetimeEarnings: Double) -> Int {
        guard lifetimeEarnings > 0 else { return 0 }
        let raw = pow(lifetimeEarnings / config.prestige.soulPointsDivisor, config.prestige.soulPointsExponent)
        return Self.clampedFloor(raw)
    }

    public func globalMultiplier(soulPoints: Int) -> Double {
        1.0 + Double(soulPoints) * config.prestige.globalMultiplierPerSoulPoint
    }

    /// `Int(_:)` on a Double at or beyond 2^63 traps; idle-game magnitudes get there.
    static func clampedFloor(_ value: Double) -> Int {
        guard value.isFinite else { return .max }
        guard value < 9.2e18 else { return .max }
        guard value > 0 else { return 0 }
        return Int(value.rounded(.down))
    }
}
