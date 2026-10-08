import Foundation

/// El auto-tap (PLAN-v2 E6): toques automáticos que pagan como un toque del
/// jugador sobre el personaje de tier más alto que tiene. Sin crítico ni toque
/// dorado (son tiradas del gesto, no del toque) y sin contar para las
/// estadísticas: el que toca es la tienda, no el jugador.
public enum AutoTapper {
    /// El de tier más alto. A igual tier (las ramas de carrera) gana el id, para
    /// que la elección no dependa del orden de un diccionario.
    public static func target(state: PlayerState, tiers: TierRepository) -> CharacterType? {
        state.run.units
            .filter { $0.value > 0 }
            .compactMap { tiers.type(id: $0.key) }
            .filter { !$0.isChoiceNode }
            .max { ($0.tier, $0.id) < ($1.tier, $1.id) }
    }

    /// Cobra `delta` segundos de auto-tap. Devuelve lo cobrado (0 sin auto-tap vivo).
    @discardableResult
    public static func advance(
        state: inout PlayerState,
        delta: TimeInterval,
        now: TimeInterval,
        tiers: TierRepository,
        floorTable: FloorTable,
        economy: StandardEconomy
    ) -> Double {
        let rate = ModifierMath.autoTapsPerSecond(state.run.activeModifiers, now: now)
        guard rate > 0, delta > 0, let type = target(state: state, tiers: tiers) else { return 0 }
        // El toque se cotiza sobre una copia: `applyTap` acredita, y acá se
        // acredita una sola vez el total.
        var probe = state
        let perTap = economy.applyTap(type: type, state: &probe, tiers: tiers, floorTable: floorTable, now: now)
        let paid = perTap * rate * delta
        state.run.coins += paid
        state.meta.lifetimeEarnings += paid
        return paid
    }
}
