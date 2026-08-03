import Foundation

/// Pure economy math shared by the game, the tier generator and the pacing simulator.
/// No UIKit, no SpriteKit, no side effects — everything is testable in isolation.
public protocol EconomyCalculating: Sendable {
    func tapYield(forTier tier: Int) -> Double
    func passiveYield(forTier tier: Int) -> Double
    func passiveUnlockCost(forTier tier: Int) -> Double
    /// ORO total que corresponde a un lifetimeEarnings dado (fórmula F7 §3.7).
    func oroTotal(lifetimeEarnings: Double) -> Int
    /// Multiplicador global. Se computa sobre `oroEarnedLifetime` (monótono):
    /// gastar ORO nunca nerfea.
    func globalMultiplier(oroEarnedLifetime: Int, prestigeBonus: Double) -> Double
}

/// The standard implementation of the F7 formulas.
///
///     tapYield(t)          = baseTapYieldTier1 × yieldGrowthPerTier^(t−1)
///     passiveYield(t)      = tapYield(t) × passiveRatio
///     passiveUnlockCost(t) = tapYield(t) × passiveUnlockCostMultiplier
///     oroTotal             = floor((lifetimeEarnings / oro.divisor)^oro.exponent)
///     globalMultiplier     = 1 + oroEarnedLifetime × perOro × (1 + prestigeBonus)
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

    public func oroTotal(lifetimeEarnings: Double) -> Int {
        guard lifetimeEarnings > 0 else { return 0 }
        let raw = pow(lifetimeEarnings / config.oro.divisor, config.oro.exponent)
        return Self.clampedFloor(raw)
    }

    public func globalMultiplier(oroEarnedLifetime: Int, prestigeBonus: Double = 0) -> Double {
        1.0 + Double(oroEarnedLifetime) * config.oro.globalMultiplierPerOro * (1 + prestigeBonus)
    }

    /// `Int(_:)` on a Double at or beyond 2^63 traps; idle-game magnitudes get there.
    static func clampedFloor(_ value: Double) -> Int {
        guard value.isFinite else { return .max }
        guard value < 9.2e18 else { return .max }
        guard value > 0 else { return 0 }
        return Int(value.rounded(.down))
    }
}
