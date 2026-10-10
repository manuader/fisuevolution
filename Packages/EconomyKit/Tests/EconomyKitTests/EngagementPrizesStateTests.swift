import Foundation
import Testing
@testable import EconomyKit

/// El buzón, el colchón y la ruleta viven en `meta.engagement` (PLAN-v2 E5),
/// sin subir el schema del save.
@Suite("EngagementState: paquetes, colchón y ruleta")
struct EngagementPrizesStateTests {
    @Test("un engagement escrito antes de E5 decodifica con los tres en su estado inicial")
    func decodesWithoutTheKeys() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.packages == .initial)
        #expect(state.treasures == .initial)
        #expect(state.wheel == .initial)
    }

    @Test("lo que escribió E4 se conserva al lado")
    func keepsWhatE4Wrote() throws {
        let json = #"{"visitors": {"secondsUntilVisit": 42}, "packages": {"waiting": 2}, "wheel": {"day": "2026-10-07", "bonusSpins": 1}}"#
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(json.utf8))
        #expect(state.visitors.secondsUntilVisit == 42)
        #expect(state.packages.waiting == 2)
        #expect(state.wheel.bonusSpins == 1)
        #expect(state.wheel.videoSpinsUsed == 0)
        #expect(state.treasures == .initial)
    }

    @Test("ida y vuelta, adentro del save entero")
    func roundTripInsideTheSave() throws {
        var player = fxState()
        player.meta.engagement.packages = PackagesState(secondsUntilNext: 33, waiting: 3)
        player.meta.engagement.treasures = TreasuresState(secondsUntilNext: 200, waiting: false, extraOpensLeft: 1)
        player.meta.engagement.wheel = WheelState(day: "2026-10-07", videoSpinsUsed: 2, oroSpinsUsed: 1, bonusSpins: 1, repeatableSegmentId: "oro_3")
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(player))
        #expect(decoded.meta.engagement == player.meta.engagement)
    }

    @Test("al resolver: buzón y colchón con el ganador; la ruleta no duplica el cupo del día")
    func resolveKeepsWinnerClocksAndDailyQuotas() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.packages = PackagesState(secondsUntilNext: 10, waiting: 1)
        loser.packages = PackagesState(secondsUntilNext: 90, waiting: 2)
        winner.treasures = TreasuresState(secondsUntilNext: 100, waiting: false)
        loser.treasures = TreasuresState(secondsUntilNext: 5, waiting: true)
        winner.wheel = WheelState(day: "d", videoSpinsUsed: 1)
        loser.wheel = WheelState(day: "d", videoSpinsUsed: 4)
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.packages == winner.packages)
        #expect(resolved.treasures == winner.treasures)
        #expect(resolved.wheel.videoSpinsUsed == 4)
    }

    @Test("reencarnar no toca el buzón, el colchón ni la ruleta")
    func reincarnationKeepsThem() {
        var player = fxState()
        player.meta.engagement.packages = PackagesState(secondsUntilNext: 33, waiting: 3)
        player.meta.engagement.wheel = WheelState(day: "d", bonusSpins: 2)
        let before = player.meta.engagement
        player.run = fxState(units: [:]).run
        #expect(player.meta.engagement == before)
    }
}
