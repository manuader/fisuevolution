import EconomyKit
import Foundation
import Observation

/// Los relojes de la base de cada partida: los que trajo el contenido antes de la primera palanca.
/// `GameState.swift` no tiene lugar para ellos (nadie toca ese archivo en la 2.1), así que viven
/// acá, con la partida por referencia débil, como el servicio de personalización.
@MainActor
private enum SegmentClockAttachments {
    struct Entry {
        weak var owner: GameState?
        let base: GameContent.SegmentClocks
    }

    static var entries: [ObjectIdentifier: Entry] = [:]

    /// Los de la base; la primera vez, los del contenido de ahora.
    static func base(for owner: GameState, current: GameContent.SegmentClocks) -> GameContent.SegmentClocks {
        if let entry = entries[ObjectIdentifier(owner)], entry.owner === owner { return entry.base }
        entries = entries.filter { $0.value.owner != nil }
        entries[ObjectIdentifier(owner)] = Entry(owner: owner, base: current)
        return current
    }
}

/// Las palancas del segmento (2.1 E15 F2): las de reloj las aplica este archivo transformando el
/// contenido; el premio por video (T6) y los forzados (T8) las leen de `segmentLevers` al decidir.
extension GameState {
    /// Las palancas del segmento que vive el jugador, leídas en el momento de la config. Sin servicio,
    /// con la compuerta cerrada o sin una sección `segments` válida: la base.
    var segmentLevers: SegmentLevers.Levers {
        personalization?.config.section("segments", as: SegmentLevers.self)?.levers(for: segment) ?? .identity
    }

    /// Aplica los relojes cada vez que cambian el segmento o la config: al empezar cada sesión, que
    /// es cuando el servicio los recalcula. La llama `attachPersonalization`, una vez.
    func trackSegmentClocks() {
        guard personalization != nil else { return }
        let levers = withObservationTracking {
            segmentLevers
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackSegmentClocks() }
        }
        applySegmentClocks(levers)
    }

    /// Los relojes de la base con `levers`, sobre el contenido de ahora (lo demás no se toca). Un reloj
    /// que ya está corriendo no se reinicia: el próximo intervalo usa el valor nuevo. El fixture del
    /// colchón gratis (`--uitest-free-mattress-every`) manda sobre el segmento.
    func applySegmentClocks(_ levers: SegmentLevers.Levers) {
        guard let content else { return }
        let base = SegmentClockAttachments.base(for: self, current: content.segmentClocks)
        var clocks = base.applying(levers)
        if freeMattressAutorun { clocks.treasures = content.treasures }
        guard clocks != content.segmentClocks else { return }
        self.content = content.replacing(clocks)
    }
}
