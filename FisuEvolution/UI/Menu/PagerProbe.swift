import Foundation
import os

/// Instrumentación del paginador del menú (E14b B4), sólo en DEBUG: cuenta
/// cuántas veces se arma el cuerpo del paginador y de cada ranura, y cuánto tarda
/// en el hilo principal cada decodificación fría de arte. En Release no hace nada.
///
/// Se lee en la consola (`subsystem == "fisu.pager"`) al deslizar entre menús: un
/// `slot.body` repetido para la misma página en reposo es una reconstrucción, y un
/// `art.cold` con `main=true` es una carga síncrona en el hilo principal.
@MainActor
enum PagerProbe {
    #if DEBUG
    private static let log = Logger(subsystem: "fisu.pager", category: "menu")
    private static var counts: [String: Int] = [:]
    #endif

    static func hit(_ tag: @autoclosure () -> String) {
        #if DEBUG
        let key = tag()
        let name = key.split(separator: " ").prefix(2).joined(separator: " ")
        counts[name, default: 0] += 1
        log.debug("\(key, privacy: .public) · \(name, privacy: .public) x\(counts[name] ?? 0)")
        #endif
    }

    /// Una decodificación fría de arte que acaba de terminar; `since` es el
    /// instante en que empezó.
    static func coldDecode(_ label: @autoclosure () -> String, since start: ContinuousClock.Instant) {
        #if DEBUG
        let elapsed = start.duration(to: ContinuousClock.now)
        let milliseconds = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        let text = label()
        log.debug("art.cold \(text, privacy: .public) main=\(Thread.isMainThread) ms=\(milliseconds, format: .fixed(precision: 1))")
        #endif
    }
}
