import Foundation
import Testing
@testable import EconomyKit

/// E14b B7 (D6): un visitante por piso, varios pisos a la vez, y el que espera
/// en un piso que no se mira queda congelado.
@Suite("Visitantes: uno por piso, congelados")
struct VisitorFloorsTests {
    let config = fxVisitors()
    let all = VisitContext(maxTier: 99, ownedSpecials: ["sp_cryptobro"], grantable: Set(RewardSpec.Kind.allCases))

    private func turista(floor: Int, patience: Double = 17) -> FloorVisitor {
        FloorVisitor(floorOrdinal: floor, visitorId: "npc_turista", scriptId: "propina", patienceLeft: patience)
    }

    @Test("el tick con el piso fuera de pantalla deja la espera intacta")
    func tickKeepsTheParkedWait() {
        var state = VisitorsState(secondsUntilVisit: 300)
        VisitorScheduler.park(turista(floor: 2, patience: 17), state: &state)
        for _ in 0..<1000 {
            _ = VisitorScheduler.advance(&state, delta: 1, config: config)
        }
        #expect(state.waiting == [turista(floor: 2, patience: 17)])
        #expect(VisitorScheduler.resume(floor: 2, state: &state)?.patienceLeft == 17)
        #expect(state.waiting.isEmpty, "al volver sale de la lista")
    }

    @Test("varios pisos a la vez, uno por piso: volver a dejar uno en el mismo piso lo reemplaza")
    func oneVisitorPerFloor() {
        var state = VisitorsState.initial
        VisitorScheduler.park(turista(floor: 0, patience: 10), state: &state)
        VisitorScheduler.park(FloorVisitor(floorOrdinal: 3, visitorId: "npc_comisario", scriptId: "arresto",
                                           patienceLeft: 22), state: &state)
        VisitorScheduler.park(turista(floor: 0, patience: 5), state: &state)
        #expect(state.waiting.count == 2)
        #expect(VisitorScheduler.waiting(onFloor: 0, state: state)?.patienceLeft == 5)
        #expect(VisitorScheduler.waiting(onFloor: 3, state: state)?.visitorId == "npc_comisario")
        #expect(VisitorScheduler.waiting(onFloor: 1, state: state) == nil)
        #expect(VisitorScheduler.resume(floor: 1, state: &state) == nil)
        #expect(state.waiting.count == 2)
    }

    @Test("el que espera en otro piso no vuelve a entrar en otro lado")
    func aParkedVisitorIsNotPickedAgain() throws {
        var rng = SeededRNG(seed: 11)
        for _ in 0..<40 {
            var state = VisitorsState(secondsUntilVisit: 0)
            VisitorScheduler.park(turista(floor: 1), state: &state)
            let script = VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                   isOfferable: { _ in true }, rng: &rng)
            #expect(script?.visitor != "npc_turista")
            #expect(script != nil, "viene otro")
        }
        let propina = try #require(config.script(id: "propina"))
        var state = VisitorsState.initial
        VisitorScheduler.park(turista(floor: 1), state: &state)
        #expect(!VisitorScheduler.isAvailable(propina, config: config, state: state, context: all,
                                              isOfferable: { _ in true }), "ni llamado por un evento")
    }

    @Test("lo que espera viaja en el save; un save de antes arranca sin nadie esperando")
    func waitingIsSaved() throws {
        var state = VisitorsState(secondsUntilVisit: 12)
        VisitorScheduler.park(turista(floor: 4, patience: 9.5), state: &state)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(VisitorsState.self, from: data) == state)
        let old = Data(#"{"secondsUntilVisit": 12, "visitorBag": [], "lastScriptByVisitor": {}, "visitsToday": {}, "blueExchangedToday": 0}"#.utf8)
        #expect(try JSONDecoder().decode(VisitorsState.self, from: old).waiting.isEmpty)
    }

    @Test("dos dispositivos: lo que espera viaja con el ganador")
    func waitingTravelsWithTheWinner() {
        var winner = VisitorsState(day: "2026-10-14")
        VisitorScheduler.park(turista(floor: 2), state: &winner)
        var loser = VisitorsState(day: "2026-10-14")
        VisitorScheduler.park(turista(floor: 5), state: &loser)
        #expect(VisitorsState.resolve(winner: winner, loser: loser).waiting == winner.waiting)
    }
}
