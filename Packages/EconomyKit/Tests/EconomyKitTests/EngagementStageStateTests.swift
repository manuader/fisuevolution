import Foundation
import Testing
@testable import EconomyKit

/// Los relojes de visitantes y eventos viven en `meta.engagement` (PLAN-v2 E4),
/// sin subir el schema del save.
@Suite("EngagementState: visitantes y eventos")
struct EngagementStageStateTests {
    @Test("un engagement escrito antes de E4 decodifica con los dos en su estado inicial")
    func decodesWithoutTheKeys() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.visitors == .initial)
        #expect(state.events == .initial)
    }

    @Test("lo que ya estaba escrito se conserva")
    func keepsWhatWasWrittenBefore() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(#"{"sharedMoments": ["god"]}"#.utf8))
        #expect(state.sharedMoments == ["god"])  // E3b T9
        #expect(state.visitors.secondsUntilVisit == nil, "sin programar: el scheduler arranca en la primera visita")
    }

    @Test("un estado a medias también decodifica")
    func partialStatesDecode() throws {
        let json = #"{"visitors": {"secondsUntilVisit": 42}, "events": {"clock": 900}}"#
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(json.utf8))
        #expect(state.visitors.secondsUntilVisit == 42)
        #expect(state.visitors.recentScripts.isEmpty)
        #expect(state.events.clock == 900)
        #expect(state.events.lastFiredAt.isEmpty)
    }

    @Test("ida y vuelta, adentro del save entero")
    func roundTripInsideTheSave() throws {
        var player = fxState()
        player.meta.engagement.visitors = VisitorsState(
            secondsUntilVisit: 120, secondsUntilVendor: 30, recentScripts: ["turista_propina"],
            day: "2026-10-07", visitsToday: ["turista_propina": 1], oroExchangedToday: 2
        )
        player.meta.engagement.events = EventsState(
            clock: 1234, secondsUntilNext: 600, lastFiredAt: ["devaluacion": 1000], upcomingId: "apagon"
        )
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(player))
        #expect(decoded.meta.engagement == player.meta.engagement)
    }

    @Test("al resolver un conflicto, el cupo del mismo día no se duplica")
    func resolveKeepsTheDailyCaps() {
        let winner = VisitorsState(secondsUntilVisit: 10, day: "2026-10-07", visitsToday: ["a": 1], oroExchangedToday: 1)
        let loser = VisitorsState(secondsUntilVisit: 99, day: "2026-10-07", visitsToday: ["a": 2, "b": 1], oroExchangedToday: 3)
        let resolved = VisitorsState.resolve(winner: winner, loser: loser)
        #expect(resolved.secondsUntilVisit == 10, "los relojes viajan con el ganador")
        #expect(resolved.visitsToday == ["a": 2, "b": 1])
        #expect(resolved.oroExchangedToday == 3)
    }

    @Test("el cupo de otro día no cuenta")
    func resolveIgnoresAnotherDay() {
        let winner = VisitorsState(day: "2026-10-08", visitsToday: ["a": 1])
        let loser = VisitorsState(day: "2026-10-07", visitsToday: ["a": 3], oroExchangedToday: 3)
        #expect(VisitorsState.resolve(winner: winner, loser: loser) == winner)
    }

    @Test("los cooldowns de eventos se quedan con el más reciente")
    func resolveEventCooldowns() {
        let winner = EventsState(clock: 500, secondsUntilNext: 100, lastFiredAt: ["a": 400])
        let loser = EventsState(clock: 900, secondsUntilNext: 5, lastFiredAt: ["a": 800, "b": 700])
        let resolved = EventsState.resolve(winner: winner, loser: loser)
        #expect(resolved.clock == 900)
        #expect(resolved.secondsUntilNext == 100)
        #expect(resolved.lastFiredAt == ["a": 800, "b": 700])
    }

    @Test("EngagementState.resolve usa las dos reglas")
    func engagementResolveDelegates() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.visitors = VisitorsState(day: "d", visitsToday: ["a": 1])
        loser.visitors = VisitorsState(day: "d", visitsToday: ["a": 2])
        loser.events = EventsState(clock: 50, lastFiredAt: ["x": 40])
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.visitors.visitsToday == ["a": 2])
        #expect(resolved.events.lastFiredAt == ["x": 40])
    }
}
