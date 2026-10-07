import Foundation

public struct OfflineCredit: Equatable, Sendable {
    public let amount: Double
    public let elapsed: TimeInterval
    public let showsPopup: Bool
}

/// Offline: `min(ausencia, tope) × pasivo base × factor integrado × eficiencia`.
/// Toda la torre produce offline (F7 §3.5).
public enum OfflineCalculator {
    /// El mismo corte con el que `IncomeTicker` descarta el delta: lo que el
    /// tick no paga lo paga esto, y nada se paga dos veces.
    public static let minimumCreditedSeconds = IncomeTicker.deltaClampThreshold

    public static func earnings(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        let from = state.meta.lastSeenTimestamp
        let capped = min(max(0, now - from), config.offlineCapHours * 3600)
        guard capped > 0 else { return 0 }
        let base = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
        let factor = ModifierMath.offlineFactor(
            state.run.activeModifiers, effect: .incomeMultiplier, from: from, to: from + capped
        )
        return capped * base * factor * state.meta.derivedEffects.offlineEfficiency
    }

    @discardableResult
    public static func apply(
        state: inout PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> OfflineCredit {
        let elapsed = max(0, now - state.meta.lastSeenTimestamp)
        let amount = elapsed > minimumCreditedSeconds
            ? earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
            : 0
        state.meta.lastSeenTimestamp = now
        if amount > 0 {
            state.run.coins += amount
            state.meta.lifetimeEarnings += amount
        }
        return OfflineCredit(
            amount: amount,
            elapsed: elapsed,
            showsPopup: amount > 0 && elapsed >= config.offlinePopupThreshold
        )
    }
}
