import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ruleta: la geometría")
struct WheelGeometryTests {
    @Test("rebanadas iguales que dan la vuelta entera")
    func equalSlices() {
        let arcs = WheelGeometry.arcs(count: 10)
        #expect(arcs.count == 10)
        #expect(arcs.first?.start == 0)
        #expect(arcs.last?.end == 360)
        #expect(arcs.allSatisfy { abs($0.span - 36) < 1e-9 })
        #expect(WheelGeometry.arcs(count: 0).isEmpty)
    }

    @Test("el puntero cae adentro de la rebanada ganadora, lejos de la raya, después de cinco vueltas",
          arguments: [0.0, 0.5, 1.0])
    func theStopLandsInsideTheWinner(landing: Double) {
        for count in [9, 10] {
            let arcs = WheelGeometry.arcs(count: count)
            for from in [0.0, 123.4, 3_000] {
                for (index, arc) in arcs.enumerated() {
                    let stop = WheelGeometry.stopRotation(from: from, arc: arc, turns: 5, landing: landing)
                    #expect(stop >= from + 5 * 360 && stop < from + 6 * 360)
                    let angle = WheelGeometry.pointerAngle(rotation: stop)
                    #expect(WheelGeometry.segmentIndex(at: angle, count: count) == index)
                    #expect(angle - arc.start >= arc.span * 0.15 - 1e-6)
                    #expect(arc.end - angle >= arc.span * 0.15 - 1e-6)
                }
            }
        }
    }

    @Test("una vuelta entera hace un tic por rebanada")
    func oneTickPerSlice() {
        #expect(WheelGeometry.boundariesCrossed(from: 0, to: 360, count: 10) == 10)
        #expect(WheelGeometry.boundariesCrossed(from: 10, to: 30, count: 10) == 0)
        #expect(WheelGeometry.boundariesCrossed(from: 30, to: 40, count: 10) == 1)
        #expect(WheelGeometry.boundariesCrossed(from: 40, to: 30, count: 10) == 0)
    }

    @Test("el tic no es una ametralladora: uno por ventana")
    func tickGate() {
        var gate = WheelTickGate()
        let first = gate.allows(at: 100)
        let soon = gate.allows(at: 100.025)
        let almost = gate.allows(at: 100.079)
        let next = gate.allows(at: 100.08)
        #expect(first && !soon && !almost && next)
    }

    @Test("una raya justa cuenta una vez, y los argumentos fuera de rango se acotan")
    func edges() {
        #expect(WheelGeometry.boundariesCrossed(from: 36, to: 36.5, count: 10) == 0)
        #expect(WheelGeometry.boundariesCrossed(from: 35.9, to: 36, count: 10) == 1)
        let arc = WheelGeometry.arcs(count: 10)[3]
        let low = WheelGeometry.stopRotation(from: 0, arc: arc, turns: 5, landing: -4)
        let high = WheelGeometry.stopRotation(from: 0, arc: arc, turns: 5, landing: 9)
        for stop in [low, high] {
            #expect(WheelGeometry.segmentIndex(at: WheelGeometry.pointerAngle(rotation: stop), count: 10) == 3)
        }
    }

    @Test("frena como una rueda: arranca rápido y llega justo")
    func easeOut() {
        #expect(WheelGeometry.easeOut(0) == 0)
        #expect(WheelGeometry.easeOut(1) == 1)
        #expect(WheelGeometry.easeOut(0.5) > 0.8)
        #expect(WheelGeometry.easeOut(2) == 1)
    }

    @Test("la animación arranca donde estaba y termina donde dijo el sorteo")
    func theSpinAnimation() {
        let segment = WheelConfig.Segment(id: "x", weight: 100, reward: .oro(1))
        let outcome = WheelSpinOutcome(segments: [segment], index: 0, coins: 0)
        let start = Date(timeIntervalSince1970: 1000)
        let spin = WheelSpinAnimation(outcome: outcome, from: 10, to: 1900, start: start, duration: 3.8)
        #expect(spin.rotation(at: start) == 10)
        #expect(spin.rotation(at: start.addingTimeInterval(3.8)) == 1900)
        #expect(!spin.isFinished(at: start.addingTimeInterval(3.7)))
        #expect(spin.isFinished(at: start.addingTimeInterval(3.8)))
        #expect(spin.rotation(at: start.addingTimeInterval(1)) < spin.rotation(at: start.addingTimeInterval(2)))
    }
}
