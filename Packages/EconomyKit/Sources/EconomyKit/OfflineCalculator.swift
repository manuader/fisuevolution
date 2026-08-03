import Foundation

/// Offline progression: `min(elapsed, cap) × passivePerSecond × efficiency`.
/// Toda la torre produce offline (F7 §3.5).
public enum OfflineCalculator {
    /// Below this the popup is not worth showing; the tick simply resumes.
    public static let minimumRelevantSeconds: TimeInterval = 30

    public static func earnings(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        let elapsed = max(0, now - state.meta.lastSeenTimestamp)
        let capped = min(elapsed, config.offlineCapHours * 3600)
        return capped
            * IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
            * state.meta.derivedEffects.offlineEfficiency
    }

    /// Applies offline earnings and stamps `lastSeenTimestamp`. Returns the amount
    /// credited (0 when nothing relevant happened).
    @discardableResult
    public static func apply(
        state: inout PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        let elapsed = now - state.meta.lastSeenTimestamp
        let amount = elapsed >= minimumRelevantSeconds
            ? earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
            : 0
        state.meta.lastSeenTimestamp = now
        guard amount > 0 else { return 0 }
        state.run.coins += amount
        state.meta.lifetimeEarnings += amount
        return amount
    }
}
