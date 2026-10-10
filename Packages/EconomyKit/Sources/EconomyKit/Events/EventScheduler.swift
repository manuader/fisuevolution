import Foundation

/// El sorteo de eventos v2 (PLAN-v2 E4), con reloj de JUEGO ACTIVO guardado en el
/// save. Puro: lo aplicable y la inmunidad llegan resueltos.
public enum EventScheduler {
    /// Avanza el reloj. Devuelve `true` si ya toca sortear. El delta trae el
    /// mismo tope que el tick: el salto de volver del background no es juego.
    @discardableResult
    public static func advance(_ state: inout EventsState, delta: TimeInterval, catalog: EventCatalog) -> Bool {
        let step = min(max(delta, 0), IncomeTicker.deltaClampThreshold)
        state.clock += step
        let remaining = (state.secondsUntilNext ?? catalog.firstEventAfterSeconds) - step
        state.secondsUntilNext = remaining
        return remaining <= 0
    }

    /// Los que pueden salir ahora: tier, cooldown en reloj de juego, inmunidad
    /// (saca los NEGATIVOS; un mixto también da) y aplicabilidad.
    public static func eligible(
        catalog: EventCatalog,
        state: EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool
    ) -> [EventCatalog.Event] {
        catalog.events.filter { event in
            maxTier >= event.minTier
                && state.clock - (state.lastFiredAt[event.id] ?? -.infinity) >= event.cooldownSeconds
                && !(isImmune && event.polarity == .negative)
                && isApplicable(event)
        }
    }

    public static func roll(
        catalog: EventCatalog,
        state: EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> EventCatalog.Event? {
        let pool = eligible(catalog: catalog, state: state, maxTier: maxTier, isImmune: isImmune, isApplicable: isApplicable)
        let total = pool.map(\.weight).reduce(0, +)
        guard total > 0 else { return nil }
        var pick = Int.random(in: 0..<total, using: &rng)
        for event in pool {
            pick -= event.weight
            if pick < 0 { return event }
        }
        return pool.last
    }

    /// Lo que viene: el ya sorteado si sigue elegible; si no, un sorteo que queda
    /// anotado. Es lo que adelanta la Vecina, y por eso es lo que sale.
    public static func peekUpcoming(
        catalog: EventCatalog,
        state: inout EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> EventCatalog.Event? {
        let pool = eligible(catalog: catalog, state: state, maxTier: maxTier, isImmune: isImmune, isApplicable: isApplicable)
        if let id = state.upcomingId, let upcoming = pool.first(where: { $0.id == id }) { return upcoming }
        let next = roll(catalog: catalog, state: state, maxTier: maxTier, isImmune: isImmune,
                        isApplicable: isApplicable, rng: &rng)
        state.upcomingId = next?.id
        return next
    }

    /// Al vencer: el adelantado si sigue elegible, o un sorteo. Limpia el adelantado.
    public static func takeDue(
        catalog: EventCatalog,
        state: inout EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> EventCatalog.Event? {
        let event = peekUpcoming(catalog: catalog, state: &state, maxTier: maxTier, isImmune: isImmune,
                                 isApplicable: isApplicable, rng: &rng)
        state.upcomingId = nil
        return event
    }

    /// Salió: arranca su cooldown y se programa el próximo.
    public static func markFired(
        _ event: EventCatalog.Event,
        state: inout EventsState,
        catalog: EventCatalog,
        rng: inout some RandomNumberGenerator
    ) {
        state.lastFiredAt[event.id] = state.clock
        let jitter = catalog.intervalJitterSeconds > 0
            ? Double.random(in: 0..<catalog.intervalJitterSeconds, using: &rng)
            : 0
        state.secondsUntilNext = catalog.intervalSeconds + jitter
    }

    /// Un sorteo vacío no gasta el intervalo: reintenta pronto (E1 T11).
    public static func retrySoon(state: inout EventsState, catalog: EventCatalog) {
        state.secondsUntilNext = catalog.retryWhenNoneApplicableSeconds
    }

    /// Al volver a la app, un evento vencido no dispara en la cara (E1 T8).
    public static func applyResumeGrace(state: inout EventsState, catalog: EventCatalog) {
        state.secondsUntilNext = max(state.secondsUntilNext ?? catalog.firstEventAfterSeconds, catalog.resumeGraceSeconds)
    }
}
