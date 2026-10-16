import EconomyKit
import Foundation

/// Qué servicio de personalización tiene cada partida. `GameState.swift` no tiene lugar para él (nadie
/// toca ese archivo en la 2.1), así que vive acá, con la partida por referencia débil: un
/// `GameState` nuevo en la misma dirección que uno muerto no hereda su servicio.
@MainActor
private enum PersonalizationAttachments {
    struct Entry {
        weak var owner: GameState?
        let service: PersonalizationService
    }

    static var entries: [ObjectIdentifier: Entry] = [:]

    static func service(for owner: GameState) -> PersonalizationService? {
        guard let entry = entries[ObjectIdentifier(owner)], entry.owner === owner else { return nil }
        return entry.service
    }

    static func attach(_ service: PersonalizationService, to owner: GameState) {
        entries = entries.filter { $0.value.owner != nil }
        entries[ObjectIdentifier(owner)] = Entry(owner: owner, service: service)
    }
}

/// El segmento del jugador (2.1 E15 F1 T5). **Nada lo consume todavía**: lo van a leer las palancas
/// (F2), los momentos (F3) y las ofertas (F5). Sin servicio (tests, recuperación), `base`: la 2.0.
extension GameState {
    var personalization: PersonalizationService? {
        PersonalizationAttachments.service(for: self)
    }

    /// El segmento que vive el jugador: `base` si la compuerta está cerrada o no hay cálculo.
    var segment: PlayerSegment {
        personalization?.segment ?? .base
    }

    /// El último cálculo, sólo con la compuerta abierta (para F2/F3/F5 y el panel de debug).
    var playerValue: PlayerValueEstimate? {
        personalization?.playerValue
    }

    /// Se adjunta una vez, después de la telemetría: los eventos `segment` y `exposure` salen por
    /// ella. Si la escena ya estaba en primer plano, la sesión arranca ya.
    func attachPersonalization(_ service: PersonalizationService) {
        PersonalizationAttachments.attach(service, to: self)
        service.attach(
            player: { [weak self] in self?.player },
            record: { [weak self] event in self?.telemetry?.record(event) }
        )
        service.start(inForeground: sceneActiveSince != nil)
    }
}
