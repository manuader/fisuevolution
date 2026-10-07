import Foundation

/// A temporary (or permanent) gameplay modifier: rewarded ads (F4), events and
/// boosts (F5) all flow through this one system. Modifiers live in `PlayerState`
/// so they survive backgrounding; expiry is an absolute timestamp.
public struct ActiveModifier: Codable, Sendable, Equatable, Identifiable {
    public enum Effect: String, Codable, Sendable {
        /// Multiplies passive income AND tap gains (events like "x3 income").
        case incomeMultiplier
        /// Multiplies tap gains only (Café Cargado).
        case tapMultiplier
        /// Multiplies the spawn cost (Unos Mates: 0.7 = 30% discount).
        case spawnCostMultiplier
    }

    public let id: UUID
    public let effect: Effect
    public let magnitude: Double
    /// Absolute epoch seconds; `.infinity` for permanent modifiers.
    public let expiresAt: TimeInterval
    /// Provenance for UI/debug: "rewarded.double_earnings", "event.plan_platita", "boost.mate".
    public let sourceKey: String

    public init(id: UUID = UUID(), effect: Effect, magnitude: Double, expiresAt: TimeInterval, sourceKey: String) {
        self.id = id
        self.effect = effect
        self.magnitude = magnitude
        self.expiresAt = expiresAt
        self.sourceKey = sourceKey
    }

    public func isActive(at now: TimeInterval) -> Bool {
        expiresAt > now
    }
}

public enum ModifierMath {
    /// Product of the magnitudes of every live modifier with the given effect.
    public static func factor(_ modifiers: [ActiveModifier], effect: ActiveModifier.Effect, now: TimeInterval) -> Double {
        modifiers
            .filter { $0.effect == effect && $0.isActive(at: now) }
            .map(\.magnitude)
            .reduce(1, *)
    }

    /// Promedio del factor de `effect` sobre `[from, to]` contando sólo los buffs
    /// (magnitud ≥ 1): cada uno paga hasta que vence y los debuffs no cuentan afuera.
    public static func offlineFactor(
        _ modifiers: [ActiveModifier],
        effect: ActiveModifier.Effect,
        from: TimeInterval,
        to: TimeInterval
    ) -> Double {
        let buffs = modifiers.filter { $0.effect == effect && $0.magnitude >= 1 }
        guard to > from else { return factor(buffs, effect: effect, now: from) }
        let cuts = buffs.map(\.expiresAt).filter { $0 > from && $0 < to }
        let edges = ([from, to] + cuts).sorted()
        let area = zip(edges, edges.dropFirst()).reduce(0.0) { total, segment in
            total + factor(buffs, effect: effect, now: segment.0) * (segment.1 - segment.0)
        }
        return area / (to - from)
    }

    /// Drops expired modifiers. Returns true if anything was removed.
    @discardableResult
    public static func prune(_ state: inout PlayerState, now: TimeInterval) -> Bool {
        let before = state.run.activeModifiers.count
        state.run.activeModifiers.removeAll { !$0.isActive(at: now) }
        return state.run.activeModifiers.count != before
    }
}
