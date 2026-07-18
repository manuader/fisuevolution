import Foundation

/// Passive income tick, literal implementation of bible §2.4: for each distinct
/// type on the board with its passive unlocked, add `yield × count`, times the
/// global multiplier, times elapsed time.
public enum IncomeTicker {
    /// Deltas above this are dropped: the first frame after app resume carries the
    /// whole background gap, which offline earnings already covers — crediting it
    /// here would double-count (critic-verified bug class).
    public static let deltaClampThreshold: TimeInterval = 2.0

    public static func passivePerSecond(state: PlayerState, tiers: TierRepository, now: TimeInterval) -> Double {
        var counts: [String: Int] = [:]
        for placement in state.board {
            counts[placement.typeId, default: 0] += 1
        }
        var total = 0.0
        for (typeId, count) in counts where state.passiveUnlocked[typeId] == true {
            if let type = tiers.type(id: typeId) {
                total += type.passiveYieldPerInstance * Double(count)
            }
        }
        return total * state.globalMultiplier
            * ModifierMath.factor(state.activeModifiers, effect: .incomeMultiplier, now: now)
    }

    /// Returns the coins earned (0 for clamped or non-positive deltas).
    @discardableResult
    public static func tick(state: inout PlayerState, tiers: TierRepository, delta: TimeInterval, now: TimeInterval) -> Double {
        guard delta > 0, delta <= deltaClampThreshold else { return 0 }
        let earned = passivePerSecond(state: state, tiers: tiers, now: now) * delta
        guard earned > 0 else { return 0 }
        state.coins += earned
        state.lifetimeEarnings += earned
        return earned
    }
}
