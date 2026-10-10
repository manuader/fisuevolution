import EconomyKit
import Foundation

/// El escenario (PLAN-v2 E4): quien entra, habla y se va. Esta extensión es la
/// máquina de estados; `StageController` la dibuja y avisa cuando el que entraba
/// llegó o el que se iba salió.
extension GameState {
    /// El escenario está libre y es un momento calmo: puede entrar alguien.
    var canPresentOnStage: Bool { stageVisit == nil && isCalmMoment && ads?.isPresentingFullScreen != true }

    /// Pone a alguien en escena. Entra cuando la cola le da el turno
    /// (`.visitorEncounter`); hasta entonces no se ve. Devuelve si lo puso: con el
    /// escenario ocupado o fuera de un momento calmo, no.
    @discardableResult
    func presentOnStage(actorId: String, role: StageVisit.Role) -> Bool {
        guard canPresentOnStage else { return false }
        stageVisit = StageVisit(id: UUID(), actorId: actorId, role: role, phase: .entering, bubble: nil, offer: nil)
        stageRuntime.patienceLeft = 0
        syncCelebrations()
        return true
    }

    /// La escena terminó la entrada.
    func stageActorArrived(id: UUID) {
        guard stageVisit?.id == id, stageVisit?.phase == .entering else { return }
        completeArrival()
        celebrationFinished(.visitorEncounter)
    }

    /// El turno de entrada se cerró sin que la escena avisara (el toque que
    /// saltea, el watchdog): llega igual, una sola vez. Lo llama `releasePayload`.
    func settleStageArrival() {
        guard stageVisit?.phase == .entering else { return }
        completeArrival()
    }

    func stageActorLeft(id: UUID) {
        guard stageVisit?.id == id, stageVisit?.phase == .leaving else { return }
        stageVisit = nil
        visitorPopup = nil
        stageRuntime.patienceLeft = 0
    }

    /// El jugador tocó al que está en escena.
    func stageActorTapped(id: UUID) {
        guard stageVisit?.id == id, stageVisit?.phase == .waiting else { return }
        openStagePopup()
    }

    /// Que se vaya: se agotó la paciencia, se resolvió su popup o terminó de hablar.
    func sendStageActorAway() {
        guard var visit = stageVisit, visit.phase != .leaving else { return }
        let wasEntering = visit.phase == .entering
        // Si la entrada se cancela antes de que le toque el turno, nunca se vio:
        // no hay nada que hacer salir.
        if wasEntering, showing != .visitorEncounter {
            stageVisit = nil
            visitorPopup = nil
            celebrationFinished(.visitorEncounter)
            return
        }
        visit.phase = .leaving
        visit.bubble = nil
        visit.offer = nil
        stageVisit = visit
        visitorPopup = nil
        if wasEntering { celebrationFinished(.visitorEncounter) }
    }

    /// La paciencia corre con el delta del tick y sólo en un momento calmo, con
    /// su popup cerrado, sin un anuncio en pantalla y sin un reto en curso. El
    /// reto corre con el delta del juego activo (`challengeClock`): vence antes
    /// de la puerta de la paciencia. `now` fija el reloj, para los tests.
    func advanceStage(delta: TimeInterval, now: TimeInterval? = nil) {
        if let now { stageRuntime.challengeClock = now } else if stageChallenge != nil { stageRuntime.challengeClock += delta }
        if let challenge = stageChallenge, stageRuntime.challengeClock >= challenge.endsAt {
            finishChallenge(won: false, now: stageRuntime.challengeClock)
        }
        guard stageVisit?.phase == .waiting, isCalmMoment, ads?.isPresentingFullScreen != true,
              visitorPopup == nil, eventPopup == nil, stageChallenge == nil
        else { return }
        stageRuntime.patienceLeft -= delta
        if stageRuntime.patienceLeft <= 0 { sendStageActorAway() }
    }

    private func completeArrival() {
        guard var visit = stageVisit, visit.phase == .entering else { return }
        visit.phase = .waiting
        stageRuntime.patienceLeft = content?.visitors.patienceSeconds ?? 30
        // Ya `.waiting` en el estado ANTES de llegar: lo que `arrive` dispara
        // (`syncCelebrations`) no tiene que ver una entrada pendiente y re-encolarla.
        stageVisit = visit
        arrive(&visit)
        stageVisit = visit
    }

    /// Lo que pasa cuando alguien llega: la oferta del visitante se cotiza acá
    /// y el evento del presentador se aplica acá.
    private func arrive(_ visit: inout StageVisit) {
        switch visit.role {
        case .visitor(let scriptId):
            arriveVisitor(&visit, scriptId: scriptId)
        case .presenter(let eventId):
            arrivePresenter(&visit, eventId: eventId)
        }
    }

    private func openStagePopup() {
        guard let visit = stageVisit else { return }
        switch visit.role {
        case .visitor:
            openVisitorPopup()
        case .presenter(let eventId):
            openEventPopup(id: eventId)
        }
    }
}
