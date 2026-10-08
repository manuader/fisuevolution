import Foundation
import Testing
@testable import EconomyKit

@Suite("Las cinemáticas vistas, en el save")
struct SeenCinematicsTests {
    private func fxSave(lifetime: Double, lastSeen: TimeInterval) -> PlayerState {
        var state = fxState()
        state.meta.lifetimeEarnings = lifetime
        state.meta.lastSeenTimestamp = lastSeen
        return state
    }

    @Test("un save de antes, sin la clave, decodifica vacío")
    func missingKeyDecodesEmpty() throws {
        let decoded = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(decoded.seenCinematics.isEmpty)
        #expect(decoded == .initial)
    }

    @Test("un save entero sin la clave de engagement.seenCinematics sigue decodificando")
    func oldFullSaveDecodes() throws {
        let data = try JSONEncoder().encode(fxState())
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var meta = try #require(json["meta"] as? [String: Any])
        meta["engagement"] = [String: Any]()
        json["meta"] = meta
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(PlayerState.self, from: old)
        #expect(decoded.meta.engagement.seenCinematics.isEmpty)
    }

    @Test("anotar suma y sobrevive la ida y vuelta")
    func recordRoundTrips() throws {
        var state = EngagementState.initial
        state.recordCinematic("arresto")
        state.recordCinematic("arresto")
        state.recordCinematic("dios")
        let back = try JSONDecoder().decode(EngagementState.self, from: JSONEncoder().encode(state))
        #expect(back.seenCinematics == ["arresto": 2, "dios": 1])
    }

    @Test("entre dispositivos gana el máximo por id, en los dos sentidos")
    func resolveTakesTheMaxPerId() {
        let a = EngagementState(seenCinematics: ["arresto": 2, "reencarnacion": 1])
        let b = EngagementState(seenCinematics: ["arresto": 1, "dios": 1])
        let expected = ["arresto": 2, "reencarnacion": 1, "dios": 1]
        #expect(EngagementState.resolve(winner: a, loser: b).seenCinematics == expected)
        #expect(EngagementState.resolve(winner: b, loser: a).seenCinematics == expected)
        let twice = EngagementState.resolve(winner: EngagementState.resolve(winner: a, loser: b), loser: b)
        #expect(twice.seenCinematics == expected, "idempotente: el resolver corre en cada sync")
    }

    @Test("el resolver del save la respeta")
    func saveResolverKeepsIt() {
        var winner = fxSave(lifetime: 100, lastSeen: 1)
        var loser = fxSave(lifetime: 10, lastSeen: 2)
        loser.meta.engagement.recordCinematic("dios")
        winner.meta.engagement.recordCinematic("arresto")
        let resolved = SaveConflictResolver.resolve(local: winner, remote: loser)
        #expect(resolved.meta.engagement.seenCinematics == ["arresto": 1, "dios": 1])
        let flipped = SaveConflictResolver.resolve(local: loser, remote: winner)
        #expect(flipped.meta.engagement.seenCinematics == ["arresto": 1, "dios": 1])
    }
}
