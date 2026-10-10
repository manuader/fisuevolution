import Foundation

/// A temporary (or permanent) gameplay modifier: rewarded ads (F4), events and
/// boosts (F5) all flow through this one system. Modifiers live in `PlayerState`
/// so they survive backgrounding; expiry is an absolute timestamp.
public struct ActiveModifier: Codable, Sendable, Equatable, Identifiable {
    public enum Effect: String, Codable, Sendable, CaseIterable {
        /// Multiplies passive income AND tap gains (events like "x3 income").
        case incomeMultiplier
        /// Multiplies tap gains only (Café Cargado).
        case tapMultiplier
        /// Multiplies the spawn cost (Unos Mates: 0.7 = 30% discount).
        case spawnCostMultiplier
        /// No se puede gastar plata mientras dura (Corralito). Los ingresos siguen.
        case spendingFrozen
        /// Multiplica SÓLO el pasivo (el Paro General lo lleva a ×0): el toque sigue.
        case passiveMultiplier
        /// Inmunidad a los eventos negativos (la Obra social del Médico). La
        /// magnitud no importa: lo que cuenta es hasta cuándo.
        case eventImmunity
        /// Multiplica el ritmo del Paquete de la Aduana (Lluvia ×10, Piquete ×0).
        /// Lo lee el `PackageScheduler` de E5; no toca los ingresos.
        case packageRateMultiplier
        /// Toques automáticos por segundo (el auto-tap de la tienda de ORO). La
        /// magnitud son toques, no un factor: dos auto-taps se SUMAN. Lo cobra
        /// `AutoTapper` y no entra en ningún `factor` de ingresos.
        case autoTapPerSecond
        /// Contratar es gratis mientras dura (el Programador). No cuenta para la
        /// curva: la compra cuesta 0 y la app pasa `countsAsPurchase: false`.
        case freeHire
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
    /// El piso de los descuentos de contratar apilados (Liquidación × Mate ×
    /// Factura A): contratar nunca sale menos que un cuarto del precio de lista.
    /// Sin él, tres descuentos juntos regalan la torre.
    public static let spawnCostStackFloor = 0.25

    /// Product of the magnitudes of every live modifier with the given effect.
    /// The hiring cost has a floor (`spawnCostStackFloor`).
    public static func factor(_ modifiers: [ActiveModifier], effect: ActiveModifier.Effect, now: TimeInterval) -> Double {
        let product = modifiers
            .filter { $0.effect == effect && $0.isActive(at: now) }
            .map(\.magnitude)
            .reduce(1, *)
        return effect == .spawnCostMultiplier ? max(product, spawnCostStackFloor) : product
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

    /// Cuántos toques por segundo dan los auto-taps vivos: la suma de sus magnitudes.
    public static func autoTapsPerSecond(_ modifiers: [ActiveModifier], now: TimeInterval) -> Double {
        modifiers
            .filter { $0.effect == .autoTapPerSecond && $0.isActive(at: now) }
            .reduce(0) { $0 + $1.magnitude }
    }

    /// Hasta cuándo dura el efecto vivo más largo de este tipo, o `nil` si no hay.
    public static func activeUntil(_ effect: ActiveModifier.Effect, in modifiers: [ActiveModifier], now: TimeInterval) -> TimeInterval? {
        modifiers.filter { $0.effect == effect && $0.isActive(at: now) }.map(\.expiresAt).max()
    }

    public static func spendingFrozenUntil(_ modifiers: [ActiveModifier], now: TimeInterval) -> TimeInterval? {
        activeUntil(.spendingFrozen, in: modifiers, now: now)
    }

    /// Hay una inmunidad viva: los eventos negativos no salen en el sorteo (los
    /// mixtos sí: la inmunidad es contra lo que sólo resta).
    public static func isImmuneToEvents(_ modifiers: [ActiveModifier], now: TimeInterval) -> Bool {
        modifiers.contains { $0.effect == .eventImmunity && $0.isActive(at: now) }
    }

    /// Drops expired modifiers. Returns true if anything was removed.
    @discardableResult
    public static func prune(_ state: inout PlayerState, now: TimeInterval) -> Bool {
        let before = state.run.activeModifiers.count
        state.run.activeModifiers.removeAll { !$0.isActive(at: now) }
        return state.run.activeModifiers.count != before
    }
}
