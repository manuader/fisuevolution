import Foundation
import Testing
@testable import EconomyKit

/// Los momentos compartidos viven en `meta.engagement` (sin subir el schema).
@Suite("EngagementState: los momentos compartidos")
struct EngagementStateTests {
    @Test("un engagement escrito antes de E3 decodifica sin momentos")
    func decodesWithoutTheKey() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.sharedMoments.isEmpty)
    }

    @Test("ida y vuelta")
    func roundTrip() throws {
        var state = EngagementState.initial
        state.sharedMoments = ["floor.urban", "god"]
        let decoded = try JSONDecoder().decode(EngagementState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }

    @Test("al resolver un conflicto de saves, lo compartido se une: nunca se cobra dos veces")
    func resolveUnions() {
        var winner = EngagementState.initial
        winner.sharedMoments = ["floor.urban"]
        var loser = EngagementState.initial
        loser.sharedMoments = ["god"]
        #expect(EngagementState.resolve(winner: winner, loser: loser).sharedMoments == ["floor.urban", "god"])
    }
}
