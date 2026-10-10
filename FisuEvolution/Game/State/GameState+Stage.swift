import EconomyKit
import Foundation

/// El escenario (PLAN-v2 E4): quien entra, habla y se va. Esta extensión es la
/// máquina de estados; `StageController` la dibuja y avisa cuando el que entraba
/// llegó o el que se iba salió.
extension GameState {
    /// El escenario está libre y es un momento calmo: puede entrar alguien.
    var canPresentOnStage: Bool { stageVisit == nil && isCalmMoment }

    /// Pone a alguien en escena. Entra cuando la cola le da el turno
    /// (`.visitorEncounter`); hasta entonces no se ve.
    func presentOnStage(actorId: String, role: StageVisit.Role) {
        stageVisit = StageVisit(id: UUID(), actorId: actorId, role: role, phase: .entering, bubble: nil, offer: nil)
        stageRuntime.patienceLeft = 0
        syncCelebrations()
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
        visit.phase = .leaving
        visit.bubble = nil
        visit.offer = nil
        stageVisit = visit
        visitorPopup = nil
        if wasEntering { celebrationFinished(.visitorEncounter) }
    }

    /// La paciencia corre con el delta del tick y sólo en un momento calmo, con
    /// su popup cerrado y sin un reto en curso.
    func advanceStage(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard stageVisit?.phase == .waiting, isCalmMoment,
              visitorPopup == nil, eventPopup == nil, stageChallenge == nil
        else { return }
        stageRuntime.patienceLeft -= delta
        if stageRuntime.patienceLeft <= 0 { sendStageActorAway() }
    }

    private func completeArrival() {
        guard var visit = stageVisit, visit.phase == .entering else { return }
        visit.phase = .waiting
        stageRuntime.patienceLeft = content?.visitors.patienceSeconds ?? 30
        arrive(&visit)
        stageVisit = visit
    }

    /// Lo que pasa cuando alguien llega: la oferta del visitante se cotiza acá (T2)
    /// y el evento del presentador se aplica acá (T4).
    private func arrive(_ visit: inout StageVisit) {
        switch visit.role {
        case .visitor:
            break
        case .presenter:
            break
        }
    }

    private func openStagePopup() {
        // T2: el popup del visitante.
    }
}
