import EconomyKit
import Foundation

/// La geometría de la ruleta, pura. Las rebanadas son iguales —la tabla de
/// probabilidades va abajo, a la vista—, el puntero está arriba y la rueda gira
/// en sentido horario. Los ángulos van en grados, desde arriba, horarios.
enum WheelGeometry {
    struct Arc: Equatable {
        let start: Double
        let end: Double
        var mid: Double { (start + end) / 2 }
        var span: Double { end - start }
    }

    static func arcs(count: Int) -> [Arc] {
        guard count > 0 else { return [] }
        let span = 360 / Double(count)
        return (0..<count).map { Arc(start: Double($0) * span, end: Double($0 + 1) * span) }
    }

    /// El ángulo de la rueda que queda bajo el puntero con la rueda girada
    /// `rotation` grados.
    static func pointerAngle(rotation: Double) -> Double {
        let angle = (-rotation).truncatingRemainder(dividingBy: 360)
        return angle < 0 ? angle + 360 : angle
    }

    static func segmentIndex(at angle: Double, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(count - 1, Int(angle / (360 / Double(count))))
    }

    /// La rotación final para que el puntero caiga dentro de `arc` después de
    /// por lo menos `turns` vueltas. `landing` ∈ [0, 1] elige el punto adentro
    /// del 70 % del medio: nunca sobre la raya, que se lee como "casi".
    static func stopRotation(from current: Double, arc: Arc, turns: Int, landing: Double) -> Double {
        let inside = arc.start + arc.span * (0.15 + 0.7 * min(max(landing, 0), 1))
        let target = (360 - inside).truncatingRemainder(dividingBy: 360)
        let minimum = current + Double(turns) * 360
        var delta = target - minimum.truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        return minimum + delta
    }

    /// Cuántas rayas pasan bajo el puntero entre dos rotaciones: el ritmo del tic.
    static func boundariesCrossed(from: Double, to: Double, count: Int) -> Int {
        guard count > 0, to > from else { return 0 }
        let span = 360 / Double(count)
        return Int(floor(to / span)) - Int(floor(from / span))
    }

    /// Frena como una rueda de verdad: rápido al principio, despacio al final.
    static func easeOut(_ progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return 1 - pow(1 - t, 3)
    }
}

/// Un giro en pantalla. El premio ya está acreditado: esto es el espectáculo.
struct WheelSpinAnimation: Equatable {
    let outcome: WheelSpinOutcome
    let from: Double
    let to: Double
    let start: Date
    let duration: TimeInterval

    /// Las fechas son `Double` y `start + duration - start` puede dar una
    /// milmillonésima de menos: el final se mide con esa tolerancia.
    private static let tolerance = 1e-6

    func rotation(at date: Date) -> Double {
        guard duration > 0, !isFinished(at: date) else { return to }
        return from + (to - from) * WheelGeometry.easeOut(date.timeIntervalSince(start) / duration)
    }

    func isFinished(at date: Date) -> Bool {
        date.timeIntervalSince(start) >= duration - Self.tolerance
    }
}

/// El freno del tic: sonido y háptico a la vez, a lo sumo uno por ventana (la
/// misma que el corte de `AudioManager`). Al arrancar la rueda pasa una raya
/// cada ~25 ms y cada tic crea un reproductor háptico.
struct WheelTickGate {
    static let window: TimeInterval = 0.08
    private var last: TimeInterval = -.infinity

    mutating func allows(at now: TimeInterval) -> Bool {
        guard now - last >= Self.window - 1e-9 else { return false }
        last = now
        return true
    }
}
