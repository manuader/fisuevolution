import EconomyKit
import Foundation

/// Quién está en escena (PLAN-v2 E4): un visitante con su oferta o el
/// presentador de un evento. Lo escribe `+Stage`; lo dibuja `StageController`.
struct StageVisit: Identifiable, Equatable {
    enum Role: Equatable {
        case visitor(scriptId: String)
        case presenter(eventId: String)
    }

    enum Phase: Equatable {
        case entering, waiting, leaving
    }

    let id: UUID
    /// El id de arte (`npc_<nombre>` / `sp_<id>`), el de `visitors.json`.
    let actorId: String
    let role: Role
    var phase: Phase
    /// Lo que dice el globo. Se resuelve al llegar.
    var bubble: String?
    /// La oferta del visitante, cotizada al llegar (`VisitPlanner`). `nil` después
    /// de elegir: el chip desaparece.
    var offer: VisitOffer?
}

/// El popup de quien está en escena: lo abrió el jugador (chip o toque).
struct VisitorPopup: Identifiable, Equatable {
    let id: UUID
}

/// El popup del chip de un evento corriendo (T4).
struct EventPopup: Identifiable, Equatable {
    let eventId: String
    var id: String { eventId }
}

/// Un reto de toques en curso (la Vecina, el Zombie, el Coach).
struct StageChallenge: Equatable {
    let scriptId: String
    let terms: ChallengeTerms
    var taps: Int
    let endsAt: TimeInterval
}

/// Lo del escenario que no se dibuja: relojes y pendientes.
struct StageRuntime {
    /// Lo que le queda de paciencia (o de charla, a un presentador).
    var patienceLeft: TimeInterval = 0
    /// El evento que espera a su presentador (T4).
    var pendingEvent: EventCatalog.Event?
    /// El guion que llamó un evento (el Cepo al Arbolito, T2).
    var calledScript: String?
    /// El guion que pidió un fixture de arranque (`--uitest-visitor=`): el
    /// bootstrap corre antes de `phase = .ready`, así que entra al primer
    /// momento calmo, salteando el sorteo.
    var debugScript: String?
    /// Quién anunció cada evento corriendo: su cara va en el chip (T4). En
    /// memoria: después de relanzar, el chip cae al primer presentador del dato.
    var eventPresenters: [String: String] = [:]
    /// El reloj del reto en curso: arranca en el `now` de la elección y avanza sólo
    /// con el delta del juego activo (`advanceStage`), nunca con la fecha de pared.
    var challengeClock: TimeInterval = 0
}

extension StageChallenge {
    /// Toques sobre la meta, con tope en 1.
    var progress: Double {
        min(1, Double(taps) / Double(max(terms.taps, 1)))
    }

    func remaining(at now: TimeInterval) -> TimeInterval {
        max(0, endsAt - now)
    }
}
