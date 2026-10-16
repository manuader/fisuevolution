import Foundation

/// Lo que el scheduler necesita saber de la partida, ya resuelto por la app.
public struct VisitContext: Sendable, Equatable {
    public let maxTier: Int
    /// Un especial sólo visita si ya lo conseguiste: si no, el Álbum dejaría de
    /// tener sorpresas.
    public let ownedSpecials: Set<String>
    /// Lo que la app ya sabe entregar (`GameState.grantableRewardKinds`).
    public let grantable: Set<RewardSpec.Kind>
    /// Pueden salir los guiones con cupo semanal: no es la primera sesión y el tutorial terminó
    /// (E14b B25).
    public let allowsWeekly: Bool

    public init(maxTier: Int, ownedSpecials: Set<String>, grantable: Set<RewardSpec.Kind>, allowsWeekly: Bool = true) {
        self.maxTier = maxTier
        self.ownedSpecials = ownedSpecials
        self.grantable = grantable
        self.allowsWeekly = allowsWeekly
    }
}

/// Cuándo viene alguien y quién (PLAN-v2 E4, E14 C5): un solo reloj de juego
/// ACTIVO y una bolsa barajada de VISITANTES. Entre los desbloqueados, cada uno
/// sale una vez antes de que alguno repita; el vendedor es uno más. Nadie viene
/// dos veces seguidas si hay otro candidato; sólo el vendedor no repite nunca.
public enum VisitorScheduler {
    /// Avanza el reloj. Devuelve si ya le toca a alguien: sigue tocándole hasta
    /// que alguien entra.
    public static func advance(_ state: inout VisitorsState, delta: TimeInterval, config: VisitorsConfig) -> Bool {
        let step = min(max(delta, 0), IncomeTicker.deltaClampThreshold)
        let visit = (state.secondsUntilVisit ?? config.firstVisitAfterSeconds) - step
        state.secondsUntilVisit = visit
        return visit <= 0
    }

    /// Un día calendario nuevo vacía los topes.
    public static func rollDay(_ state: inout VisitorsState, today: String) {
        guard state.day != today else { return }
        state.day = today
        state.visitsToday = [:]
        state.blueExchangedToday = 0
    }

    /// Una semana calendario nueva vacía el cupo semanal (E14b B25).
    public static func rollWeek(_ state: inout VisitorsState, week: String) {
        guard state.week != week else { return }
        state.week = week
        state.visitsThisWeek = [:]
    }

    /// La semana ISO de una fecha ("2026-W42"): empieza el lunes, en la zona del dispositivo.
    public static func weekKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    /// Una sesión nueva (un arranque de la app): la primera no trae guiones con cupo semanal.
    public static func noteSessionStarted(_ state: inout VisitorsState) {
        state.sessions += 1
    }

    /// Puede venir ahora, sea por la bolsa o porque lo llama un evento. Un guion de reloj de pared no
    /// vuelve mientras su Marcha sigue en el save.
    public static func isAvailable(
        _ script: VisitorsConfig.Script,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool
    ) -> Bool {
        isUnlocked(script, config: config, context: context)
            && !isWaiting(script.visitor, state: state)
            && (state.visitsToday[script.id] ?? 0) < script.dailyCap
            && script.weeklyCap.map { (state.visitsThisWeek[script.id] ?? 0) < $0 } ?? true
            && !(script.realClock && state.march != nil)
            && isOfferable(script)
    }

    /// Los que entran en la bolsa, en el orden del config: con algún guion de la
    /// rotación desbloqueado (tier, especial conseguido, premios entregables). El
    /// tope del día y la oferta posible son de AHORA: no lo sacan, lo hacen esperar.
    public static func unlockedVisitors(config: VisitorsConfig, context: VisitContext) -> [String] {
        let unlocked = Set(config.scripts.filter { !$0.eventOnly && isUnlocked($0, config: config, context: context) }
            .map(\.visitor))
        return config.visitors.map(\.id).filter(unlocked.contains)
    }

    /// Los guiones de la rotación que el visitante puede traer ahora.
    public static func availableScripts(
        of visitorId: String,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool
    ) -> [VisitorsConfig.Script] {
        config.scripts.filter { script in
            script.visitor == visitorId && !script.eventOnly
                && isAvailable(script, config: config, state: state, context: context, isOfferable: isOfferable)
        }
    }

    /// El próximo de la bolsa que puede venir ahora, con el guion que trae. El
    /// que no puede queda primero para la próxima; si nadie de la bolsa puede, la
    /// vuelta siguiente se baraja detrás de ellos. Ordena la bolsa (la deja en
    /// `state`) pero no saca a nadie: eso es de `markVisited`, cuando entra.
    public static func pickNext(
        config: VisitorsConfig,
        state: inout VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> VisitorsConfig.Script? {
        let unlocked = unlockedVisitors(config: config, context: context)
        guard !unlocked.isEmpty else { return nil }
        let unlockedSet = Set(unlocked)
        var seen: Set<String> = []
        var bag = state.visitorBag.filter { unlockedSet.contains($0) && seen.insert($0).inserted }
        if bag.isEmpty {
            bag = shuffled(unlocked, notFirst: state.lastVisitor, rng: &rng)
        }
        // Nadie dos veces seguidas mientras haya otro candidato. Si no lo hay, repite
        // cualquiera menos el vendedor, que espera al siguiente.
        let last = state.lastVisitor
        let lastIsVendor = last.map { isVendor($0, config: config) } ?? false
        func firstAvailable(repeating: Bool = false) -> VisitorsConfig.Script? {
            let blocked = (repeating && !lastIsVendor) || unlocked.count == 1 ? nil : last
            for visitorId in bag where visitorId != blocked {
                let scripts = availableScripts(of: visitorId, config: config, state: state,
                                               context: context, isOfferable: isOfferable)
                if let script = alternate(scripts, last: state.lastScriptByVisitor[visitorId], rng: &rng) {
                    return script
                }
            }
            return nil
        }
        if let script = firstAvailable() {
            state.visitorBag = bag
            return script
        }
        let rest = unlocked.filter { !bag.contains($0) }
        bag += shuffled(rest, notFirst: state.lastVisitor, rng: &rng)
        state.visitorBag = bag
        return firstAvailable() ?? firstAvailable(repeating: true)
    }

    /// El vendedor es el que ofrece cartas por video.
    private static func isVendor(_ visitorId: String, config: VisitorsConfig) -> Bool {
        config.scripts.contains { script in
            if case .vendor = script.mechanic { return script.visitor == visitorId }
            return false
        }
    }

    /// Entró: sale de la bolsa, queda como el último, cuenta el día y programa el
    /// próximo. Lo que llama un evento no gasta el turno de la bolsa.
    public static func markVisited(
        _ script: VisitorsConfig.Script,
        state: inout VisitorsState,
        config: VisitorsConfig,
        rng: inout some RandomNumberGenerator
    ) {
        if !script.eventOnly, let index = state.visitorBag.firstIndex(of: script.visitor) {
            state.visitorBag.remove(at: index)
        }
        state.lastVisitor = script.visitor
        state.lastScriptByVisitor[script.visitor] = script.id
        state.visitsToday[script.id, default: 0] += 1
        // Entrar gasta el cupo de la semana: si la rechaza, no vuelve hasta la semana siguiente.
        if script.weeklyCap != nil { state.visitsThisWeek[script.id, default: 0] += 1 }
        state.secondsUntilVisit = Double.random(in: config.intervalMinSeconds...config.intervalMaxSeconds, using: &rng)
    }

    // MARK: Un visitante por piso (E14b B7, D6)

    /// Se fue del piso con alguien esperando: queda congelado ahí, con la
    /// paciencia que le quedaba. Uno por piso: el nuevo reemplaza al anterior.
    public static func park(_ visitor: FloorVisitor, state: inout VisitorsState) {
        state.waiting.removeAll { $0.floorOrdinal == visitor.floorOrdinal }
        state.waiting.append(visitor)
    }

    /// Volvió al piso: el que esperaba ahí sale de la lista tal como quedó.
    public static func resume(floor: Int, state: inout VisitorsState) -> FloorVisitor? {
        guard let index = state.waiting.firstIndex(where: { $0.floorOrdinal == floor }) else { return nil }
        return state.waiting.remove(at: index)
    }

    public static func waiting(onFloor floor: Int, state: VisitorsState) -> FloorVisitor? {
        state.waiting.first { $0.floorOrdinal == floor }
    }

    /// Está esperando en algún piso: no puede entrar en otro.
    public static func isWaiting(_ visitorId: String, state: VisitorsState) -> Bool {
        state.waiting.contains { $0.visitorId == visitorId }
    }

    /// Le tocaba a alguien y nadie puede venir: reintenta pronto, no espera otro
    /// intervalo entero.
    public static func retrySoon(state: inout VisitorsState, config: VisitorsConfig) {
        state.secondsUntilVisit = config.retryWhenNoneSeconds
    }

    private static func isUnlocked(_ script: VisitorsConfig.Script, config: VisitorsConfig, context: VisitContext) -> Bool {
        guard let visitor = config.visitor(id: script.visitor) else { return false }
        return context.maxTier >= script.minTier
            && (script.weeklyCap == nil || context.allowsWeekly)
            && (visitor.kind == .npc || context.ownedSpecials.contains(visitor.id))
            && script.mechanic.rewards.allSatisfy { context.grantable.contains($0.kind) }
    }

    /// Una vuelta nueva, sin repetir en el borde al último que vino.
    private static func shuffled(_ ids: [String], notFirst last: String?, rng: inout some RandomNumberGenerator) -> [String] {
        var bag = ids.shuffled(using: &rng)
        if bag.count > 1, bag.first == last {
            bag.swapAt(0, Int.random(in: 1..<bag.count, using: &rng))
        }
        return bag
    }

    /// Los guiones de un visitante se alternan; entre los que no son el último,
    /// el peso decide.
    private static func alternate(
        _ scripts: [VisitorsConfig.Script],
        last: String?,
        rng: inout some RandomNumberGenerator
    ) -> VisitorsConfig.Script? {
        let fresh = scripts.filter { $0.id != last }
        let pool = fresh.isEmpty ? scripts : fresh
        let total = pool.map(\.weight).reduce(0, +)
        guard total > 0 else { return pool.first }
        var pick = Int.random(in: 0..<total, using: &rng)
        for script in pool {
            pick -= script.weight
            if pick < 0 { return script }
        }
        return pool.last
    }
}
