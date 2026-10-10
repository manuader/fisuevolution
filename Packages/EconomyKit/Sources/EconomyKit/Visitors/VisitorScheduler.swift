import Foundation

/// Lo que el scheduler necesita saber de la partida, ya resuelto por la app.
public struct VisitContext: Sendable, Equatable {
    public let maxTier: Int
    /// Un especial sólo visita si ya lo conseguiste: si no, el Álbum dejaría de
    /// tener sorpresas.
    public let ownedSpecials: Set<String>
    /// Lo que la app ya sabe entregar (`GameState.grantableRewardKinds`).
    public let grantable: Set<RewardSpec.Kind>

    public init(maxTier: Int, ownedSpecials: Set<String>, grantable: Set<RewardSpec.Kind>) {
        self.maxTier = maxTier
        self.ownedSpecials = ownedSpecials
        self.grantable = grantable
    }
}

/// Cuándo viene alguien y quién (PLAN-v2 E4): dos carriles de juego ACTIVO, el
/// principal y el del Vendedor Ambulante.
public enum VisitorScheduler {
    /// Avanza los dos relojes. Devuelve el carril que quedó listo (el principal
    /// primero). Un carril listo sigue listo hasta que alguien entra.
    public static func advance(
        _ state: inout VisitorsState,
        delta: TimeInterval,
        config: VisitorsConfig,
        rng: inout some RandomNumberGenerator
    ) -> VisitorsConfig.Lane? {
        let step = min(max(delta, 0), IncomeTicker.deltaClampThreshold)
        let visit = (state.secondsUntilVisit ?? config.firstVisitAfterSeconds) - step
        let vendor = (state.secondsUntilVendor ?? config.firstVisitAfterSeconds + vendorInterval(config, rng: &rng)) - step
        state.secondsUntilVisit = visit
        state.secondsUntilVendor = vendor
        if visit <= 0 { return .main }
        if vendor <= 0 { return .vendor }
        return nil
    }

    /// Un día calendario nuevo vacía los topes.
    public static func rollDay(_ state: inout VisitorsState, today: String) {
        guard state.day != today else { return }
        state.day = today
        state.visitsToday = [:]
        state.oroExchangedToday = 0
    }

    /// Puede venir ahora, sea por sorteo o porque lo llama un evento.
    public static func isAvailable(
        _ script: VisitorsConfig.Script,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool
    ) -> Bool {
        guard let visitor = config.visitor(id: script.visitor) else { return false }
        return context.maxTier >= script.minTier
            && (state.visitsToday[script.id] ?? 0) < script.dailyCap
            && (visitor.kind == .npc || context.ownedSpecials.contains(visitor.id))
            && script.mechanic.rewards.allSatisfy { context.grantable.contains($0.kind) }
            && isOfferable(script)
    }

    /// Los del sorteo de un carril. Los recientes no vuelven si hay otro: si son
    /// los únicos, vuelven igual (mejor repetir que dejar el carril vacío).
    public static func eligible(
        lane: VisitorsConfig.Lane,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool
    ) -> [VisitorsConfig.Script] {
        let candidates = config.scripts.filter { script in
            script.lane == lane && !script.eventOnly
                && isAvailable(script, config: config, state: state, context: context, isOfferable: isOfferable)
        }
        let recent = Set(state.recentScripts.suffix(config.antiRepeat))
        let fresh = candidates.filter { !recent.contains($0.id) }
        return fresh.isEmpty ? candidates : fresh
    }

    public static func pickNext(
        lane: VisitorsConfig.Lane,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> VisitorsConfig.Script? {
        let pool = eligible(lane: lane, config: config, state: state, context: context, isOfferable: isOfferable)
        let total = pool.map(\.weight).reduce(0, +)
        guard total > 0 else { return nil }
        var pick = Int.random(in: 0..<total, using: &rng)
        for script in pool {
            pick -= script.weight
            if pick < 0 { return script }
        }
        return pool.last
    }

    /// Entró: memoria de repetidos, cuenta del día y el próximo de su carril.
    public static func markVisited(
        _ script: VisitorsConfig.Script,
        state: inout VisitorsState,
        config: VisitorsConfig,
        rng: inout some RandomNumberGenerator
    ) {
        state.recentScripts.append(script.id)
        let memory = max(config.antiRepeat, 1) * 2
        if state.recentScripts.count > memory {
            state.recentScripts.removeFirst(state.recentScripts.count - memory)
        }
        state.visitsToday[script.id, default: 0] += 1
        switch script.lane {
        case .main:
            state.secondsUntilVisit = Double.random(in: config.intervalMinSeconds...config.intervalMaxSeconds, using: &rng)
        case .vendor:
            state.secondsUntilVendor = vendorInterval(config, rng: &rng)
        }
    }

    /// Un carril listo sin nadie para mandar reintenta pronto, no espera otro intervalo entero.
    public static func retrySoon(lane: VisitorsConfig.Lane, state: inout VisitorsState, config: VisitorsConfig) {
        switch lane {
        case .main: state.secondsUntilVisit = config.retryWhenNoneSeconds
        case .vendor: state.secondsUntilVendor = config.retryWhenNoneSeconds
        }
    }

    static func vendorInterval(_ config: VisitorsConfig, rng: inout some RandomNumberGenerator) -> Double {
        config.vendorIntervalSeconds
            + Double.random(in: -config.vendorJitterSeconds...config.vendorJitterSeconds, using: &rng)
    }
}
