import Foundation

/// Offline progression (bible §3): `min(elapsed, cap) × passivePerSecond × efficiency`.
public enum OfflineCalculator {
    /// Below this the popup is not worth showing; the tick simply resumes.
    public static let minimumRelevantSeconds: TimeInterval = 30

    public static func earnings(
        state: PlayerState,
        tiers: TierRepository,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        let elapsed = max(0, now - state.lastSeenTimestamp)
        let capped = min(elapsed, config.offlineCapHours * 3600)
        return capped * IncomeTicker.passivePerSecond(state: state, tiers: tiers, now: now) * state.upgrades.offlineEfficiency
    }

    /// Applies offline earnings and stamps `lastSeenTimestamp`. Returns the amount
    /// credited (0 when nothing relevant happened).
    @discardableResult
    public static func apply(
        state: inout PlayerState,
        tiers: TierRepository,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        let elapsed = now - state.lastSeenTimestamp
        let amount = elapsed >= minimumRelevantSeconds
            ? earnings(state: state, tiers: tiers, config: config, now: now)
            : 0
        state.lastSeenTimestamp = now
        guard amount > 0 else { return 0 }
        state.coins += amount
        state.lifetimeEarnings += amount
        return amount
    }
}
