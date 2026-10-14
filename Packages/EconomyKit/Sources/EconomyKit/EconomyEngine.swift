import Foundation

/// Pure economy math shared by the game, the tier generator and the pacing simulator.
/// No UIKit, no SpriteKit, no side effects — everything is testable in isolation.
///
///     tapYield(t)          = baseTapYieldTier1 × yieldGrowthPerTier^(t−1)
///     passiveYield(t)      = tapYield(t) × passiveRatio
///     passiveUnlockCost(t) = tapYield(t) × passiveUnlockCostMultiplier
///     blueTotal             = floor((lifetimeEarnings / blue.divisor)^blue.exponent)
///     globalMultiplier     = 1 + blueEarnedLifetime × perBlue × (1 + prestigeBonus)
public struct StandardEconomy: Sendable {
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

    /// Blue total que corresponde a un lifetimeEarnings dado (fórmula F7 §3.7).
    public func blueTotal(lifetimeEarnings: Double) -> Int {
        guard lifetimeEarnings > 0 else { return 0 }
        let raw = pow(lifetimeEarnings / config.blue.divisor, config.blue.exponent)
        return Self.clampedFloor(raw)
    }

    /// Multiplicador global. Se computa sobre `blueEarnedLifetime` (monótono):
    /// gastar blue nunca nerfea.
    public func globalMultiplier(blueEarnedLifetime: Int, prestigeBonus: Double = 0) -> Double {
        1.0 + Double(blueEarnedLifetime) * config.blue.globalMultiplierPerBlue * (1 + prestigeBonus)
    }

    /// `Int(_:)` on a Double at or beyond 2^63 traps; idle-game magnitudes get there.
    static func clampedFloor(_ value: Double) -> Int {
        guard value.isFinite else { return .max }
        guard value < 9.2e18 else { return .max }
        guard value > 0 else { return 0 }
        return Int(value.rounded(.down))
    }
}
