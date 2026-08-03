import Foundation

/// Passive income tick (F7 §3.5): TODA la torre produce siempre — por cada tipo
/// con passive desbloqueado, `yield × count × charUpgrade × floorMult`, por los
/// multiplicadores globales, por el tiempo transcurrido.
public enum IncomeTicker {
    /// Deltas above this are dropped: the first frame after app resume carries the
    /// whole background gap, which offline earnings already covers — crediting it
    /// here would double-count (critic-verified bug class).
    public static let deltaClampThreshold: TimeInterval = 2.0

    public static func passivePerSecond(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        var total = 0.0
        for (typeId, count) in state.run.units where state.run.passiveUnlocked[typeId] == true {
            guard count > 0, let type = tiers.type(id: typeId) else { continue }
            total += type.passiveYieldPerInstance
                * Double(count)
                * CharUpgrades.multiplier(typeId: typeId, levels: state.run.charUpgradeLevels, config: config)
                * floorTable.floor(forTier: type.tier).incomeMultiplier
        }
        return total * state.meta.globalMultiplier * state.meta.derivedEffects.incomeMultiplier
            * ModifierMath.factor(state.run.activeModifiers, effect: .incomeMultiplier, now: now)
    }

    /// Returns the coins earned (0 for clamped or non-positive deltas).
    @discardableResult
    public static func tick(
        state: inout PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        delta: TimeInterval,
        now: TimeInterval
    ) -> Double {
        guard delta > 0, delta <= deltaClampThreshold else { return 0 }
        let earned = passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now) * delta
        guard earned > 0 else { return 0 }
        state.run.coins += earned
        state.meta.lifetimeEarnings += earned
        return earned
    }
}
