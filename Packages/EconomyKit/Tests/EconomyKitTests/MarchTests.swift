import Foundation
import Testing
@testable import EconomyKit

/// La Marcha del Puntero (E14b B25, D16): 420 toques en una hora de reloj real, en el save, una
/// vez por semana.
@Suite("Visitantes: la Marcha")
struct MarchTests {
    private let terms = ChallengeTerms(taps: 420, windowSeconds: 3600, coins: 0, rewards: [.blue(30)], realClock: true)
    private let start = 1_800_000_000.0

    private func marching() -> VisitorsState {
        var state = VisitorsState.initial
        #expect(VisitorScheduler.beginMarch(&state, scriptId: "marcha", terms: terms, now: start))
        return state
    }

    private func marcha(weeklyCap: Int? = 1) -> VisitorsConfig.Script {
        fxScript("marcha", dailyCap: 1,
                 mechanic: .challenge(taps: 420, windowSeconds: 3600, rewards: [.blue(30)], videoDoubles: true),
                 weeklyCap: weeklyCap, realClock: true)
    }

    private let context = VisitContext(maxTier: 5, ownedSpecials: [], grantable: Set(RewardSpec.Kind.allCases))

    // MARK: El save

    @Test("la Marcha va y vuelve del save tal cual: inicio, fin, meta, toques y premio")
    func roundTrip() throws {
        var state = marching()
        for _ in 0..<137 { VisitorScheduler.noteMarchTap(&state, now: start + 60) }
        state.week = "2027-W02"
        state.visitsThisWeek = ["marcha": 1]
        state.sessions = 3
        let decoded = try JSONDecoder().decode(VisitorsState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        let march = try #require(decoded.march)
        #expect(march.startedAt == start && march.endsAt == start + 3600)
        #expect(march.goal == 420 && march.taps == 137 && march.rewards == [.blue(30)])
        #expect(march.outcome == nil)
    }

    @Test("un save de antes de B25 no trae la Marcha ni el cupo semanal: arranca vacío")
    func oldSaveDecodes() throws {
        let json = #"{"secondsUntilVisit": 120, "visitorBag": ["npc_turista"], "visitsToday": {}, "blueExchangedToday": 0}"#
        let state = try JSONDecoder().decode(VisitorsState.self, from: Data(json.utf8))
        #expect(state.march == nil)
        #expect(state.week == nil && state.visitsThisWeek.isEmpty)
        #expect(state.sessions == 0)
        #expect(state.secondsUntilVisit == 120)
    }

    // MARK: El reloj real

    @Test("corre con el reloj de pared: con la app cerrada la hora pasa igual y, al volver, vence")
    func wallClock() {
        var state = marching()
        #expect(VisitorScheduler.resolveMarch(&state, now: start + 3599) == nil, "todavía corre")
        // Se cerró la app 2 h: ningún tick, sólo la fecha de pared al volver.
        #expect(VisitorScheduler.resolveMarch(&state, now: start + 7200) == .lost)
        #expect(state.march?.outcome == .lost)
    }

    @Test("los toques cuentan sólo dentro de la ventana de pared")
    func tapsOnlyInsideTheWindow() {
        var state = marching()
        VisitorScheduler.noteMarchTap(&state, now: start - 1)
        #expect(state.march?.taps == 0, "un reloj que volvió atrás no suma")
        VisitorScheduler.noteMarchTap(&state, now: start)
        VisitorScheduler.noteMarchTap(&state, now: start + 3599)
        #expect(state.march?.taps == 2)
        VisitorScheduler.noteMarchTap(&state, now: start + 3600)
        #expect(state.march?.taps == 2, "al vencer ya no cuenta")
    }

    @Test("una sola Marcha a la vez")
    func oneAtATime() {
        var state = marching()
        #expect(!VisitorScheduler.beginMarch(&state, scriptId: "otra", terms: terms, now: start + 10))
        #expect(state.march?.scriptId == "marcha")
    }

    // MARK: El premio

    @Test("el toque 420 la gana; cobra una sola vez")
    func paysOnce() throws {
        var state = marching()
        for tap in 1..<420 {
            #expect(!VisitorScheduler.noteMarchTap(&state, now: start + Double(tap)))
        }
        #expect(state.march?.outcome == nil)
        #expect(VisitorScheduler.noteMarchTap(&state, now: start + 500), "el 420 la gana")
        #expect(state.march?.outcome == .won)
        #expect(!VisitorScheduler.noteMarchTap(&state, now: start + 501), "ganada, no cuenta más")
        #expect(state.march?.taps == 420)
        // Ganada no vence aunque pase la hora antes de cobrarla (la app se cerró en el medio).
        #expect(VisitorScheduler.resolveMarch(&state, now: start + 9999) == .won)
        let settled = try #require(VisitorScheduler.settleMarch(&state))
        #expect(settled.outcome == .won && settled.rewards == [.blue(30)])
        #expect(state.march == nil)
        #expect(VisitorScheduler.settleMarch(&state) == nil, "la segunda vez no hay nada que cobrar")
    }

    @Test("vencida sin llegar: se cierra sin premio")
    func expiredPaysNothing() throws {
        var state = marching()
        for _ in 0..<419 { VisitorScheduler.noteMarchTap(&state, now: start + 100) }
        VisitorScheduler.resolveMarch(&state, now: start + 3600)
        let settled = try #require(VisitorScheduler.settleMarch(&state))
        #expect(settled.outcome == .lost)
        #expect(state.march == nil)
    }

    @Test("mientras corre no se cierra")
    func runningDoesNotSettle() {
        var state = marching()
        #expect(VisitorScheduler.settleMarch(&state) == nil)
        #expect(state.march != nil)
    }

    @Test("el planificador marca el reto de reloj de pared y cotiza su premio")
    func plannerCarriesRealClock() throws {
        let script = marcha()
        let fx = try fxStateAndTower(units: ["a": 1])
        let offer = try #require(VisitPlanner.offer(
            script, config: fxVisitors(scripts: [script]), state: fx.state, tower: fx.tower,
            tiers: try fxTiers(), floorTable: fx.floorTable, economy: fxConfig(),
            valuation: VisitValuation(coinsPerSecond: 10)
        ))
        let terms = try #require(offer.option(id: "challenge")?.challenge)
        #expect(terms.realClock && terms.taps == 420 && terms.windowSeconds == 3600 && terms.rewards == [.blue(30)])
    }

    // MARK: El cupo semanal

    @Test("una vez por semana: entrar gasta el cupo (aunque la rechace) y vuelve recién la semana siguiente")
    func weeklyCap() {
        let config = fxVisitors(scripts: [marcha()])
        var state = VisitorsState.initial
        var rng = SystemRandomNumberGenerator()
        VisitorScheduler.rollWeek(&state, week: "2027-W02")
        let script = marcha()
        #expect(VisitorScheduler.isAvailable(script, config: config, state: state, context: context, isOfferable: { _ in true }))
        VisitorScheduler.markVisited(script, state: &state, config: config, rng: &rng)
        #expect(state.visitsThisWeek["marcha"] == 1)
        VisitorScheduler.rollDay(&state, today: "2027-01-12")
        #expect(!VisitorScheduler.isAvailable(script, config: config, state: state, context: context, isOfferable: { _ in true }),
                "otro día de la misma semana, no")
        VisitorScheduler.rollWeek(&state, week: "2027-W02")
        #expect(state.visitsThisWeek["marcha"] == 1, "la misma semana no vacía el cupo")
        VisitorScheduler.rollWeek(&state, week: "2027-W03")
        #expect(VisitorScheduler.isAvailable(script, config: config, state: state, context: context, isOfferable: { _ in true }))
    }

    @Test("sin cupo semanal, el cupo semanal no cuenta")
    func noWeeklyCapNoCount() {
        let script = fxScript("propina", mechanic: .gift(rewards: [.coinsSeconds(900)], videoDoubles: true))
        var state = VisitorsState.initial
        var rng = SystemRandomNumberGenerator()
        VisitorScheduler.markVisited(script, state: &state, config: fxVisitors(), rng: &rng)
        #expect(state.visitsThisWeek.isEmpty)
    }

    @Test("nunca en la primera sesión ni antes del tutorial: con `allowsWeekly` apagado no está desbloqueada")
    func notInTheFirstSession() {
        let script = marcha()
        let config = fxVisitors(scripts: [script, fxScript("propina", mechanic: .gift(rewards: [.coinsSeconds(900)], videoDoubles: true))])
        let early = VisitContext(maxTier: 5, ownedSpecials: [], grantable: Set(RewardSpec.Kind.allCases), allowsWeekly: false)
        #expect(!VisitorScheduler.isAvailable(script, config: config, state: .initial, context: early, isOfferable: { _ in true }))
        #expect(VisitorScheduler.availableScripts(of: "npc_turista", config: config, state: .initial, context: early,
                                                  isOfferable: { _ in true }).map(\.id) == ["propina"])
        #expect(VisitorScheduler.isAvailable(script, config: config, state: .initial, context: context, isOfferable: { _ in true }))
    }

    @Test("con su Marcha en el save, el guion no vuelve aunque la semana sea otra")
    func notWhileMarching() {
        let script = marcha(weeklyCap: 5)
        let config = fxVisitors(scripts: [script])
        var state = marching()
        #expect(!VisitorScheduler.isAvailable(script, config: config, state: state, context: context, isOfferable: { _ in true }))
        VisitorScheduler.resolveMarch(&state, now: start + 3600)
        _ = VisitorScheduler.settleMarch(&state)
        #expect(VisitorScheduler.isAvailable(script, config: config, state: state, context: context, isOfferable: { _ in true }))
    }

    @Test("las sesiones se cuentan una por arranque")
    func sessions() {
        var state = VisitorsState.initial
        VisitorScheduler.noteSessionStarted(&state)
        VisitorScheduler.noteSessionStarted(&state)
        #expect(state.sessions == 2)
    }

    @Test("la semana es la ISO: arranca el lunes y cruza el año bien")
    func weekKey() {
        let utc = TimeZone(identifier: "UTC")!
        func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text + "T12:00:00Z")! }
        #expect(VisitorScheduler.weekKey(for: date("2026-10-15"), timeZone: utc) == "2026-W42")
        #expect(VisitorScheduler.weekKey(for: date("2026-10-18"), timeZone: utc) == "2026-W42", "el domingo cierra la semana")
        #expect(VisitorScheduler.weekKey(for: date("2026-10-19"), timeZone: utc) == "2026-W43", "el lunes abre otra")
        #expect(VisitorScheduler.weekKey(for: date("2027-01-01"), timeZone: utc) == "2026-W53")
    }

    @Test("dos dispositivos en la misma semana no duplican el cupo; la Marcha viaja con el ganador")
    func conflictResolution() {
        var winner = marching()
        winner.week = "2027-W02"
        winner.visitsThisWeek = [:]
        winner.sessions = 2
        var loser = VisitorsState.initial
        loser.week = "2027-W02"
        loser.visitsThisWeek = ["marcha": 1]
        loser.sessions = 5
        let resolved = VisitorsState.resolve(winner: winner, loser: loser)
        #expect(resolved.visitsThisWeek["marcha"] == 1)
        #expect(resolved.sessions == 5)
        #expect(resolved.march == winner.march)
        loser.week = "2027-W01"
        #expect(VisitorsState.resolve(winner: winner, loser: loser).visitsThisWeek.isEmpty, "otra semana no se mezcla")
    }

    // MARK: El config

    @Test("se leen el cupo semanal y el reloj de pared; el validador los frena mal puestos")
    func config() throws {
        let json = """
        {"id": "m", "visitor": "npc_turista", "weight": 20, "minTier": 3, "dailyCap": 1, "weeklyCap": 1, "realClock": true,
         "mechanic": {"kind": "challenge", "taps": 420, "windowSeconds": 3600, "videoDoubles": true,
                      "rewards": [{"kind": "blue", "amount": 30}]}}
        """
        let script = try JSONDecoder().decode(VisitorsConfig.Script.self, from: Data(json.utf8))
        #expect(script.weeklyCap == 1 && script.realClock)
        #expect(script.lineKey("won") == "visit.m.won")
        try fxVisitors(scripts: [script]).validate()
        let plain = try JSONDecoder().decode(VisitorsConfig.Script.self, from: JSONEncoder().encode(
            fxScript("p", mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false))))
        #expect(plain.weeklyCap == nil && !plain.realClock)
        #expect(throws: VisitorsConfig.ValidationError.self) {
            try fxVisitors(scripts: [fxScript("g", mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false),
                                              realClock: true)]).validate()
        }
        #expect(throws: VisitorsConfig.ValidationError.self) {
            try fxVisitors(scripts: [fxScript("w", mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false),
                                              weeklyCap: 0)]).validate()
        }
    }
}
