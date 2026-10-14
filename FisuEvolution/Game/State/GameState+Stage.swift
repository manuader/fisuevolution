import EconomyKit
import Foundation

/// El escenario (PLAN-v2 E4): quien entra, habla y se va. Esta extensión es la
/// máquina de estados; `StageController` la dibuja y avisa cuando el que entraba
/// llegó o el que se iba salió.
extension GameState {
    /// El escenario del piso que se mira está libre y es un momento calmo: puede
    /// entrar alguien. Un piso con un visitante congelado no está libre (E14b B7).
    var canPresentOnStage: Bool {
        stageVisit == nil && waitingVisitor(onFloor: visibleFloorOrdinal) == nil
            && isCalmMoment && ads?.isPresentingFullScreen != true
    }

    /// Pone a alguien en escena. Entra cuando la cola le da el turno
    /// (`.visitorEncounter`); hasta entonces no se ve. Devuelve si lo puso: con el
    /// escenario ocupado o fuera de un momento calmo, no.
    @discardableResult
    func presentOnStage(actorId: String, role: StageVisit.Role) -> Bool {
        guard canPresentOnStage else { return false }
        stageVisit = StageVisit(id: UUID(), actorId: actorId, role: role, phase: .entering, bubble: nil, offer: nil,
                                floorOrdinal: visibleFloorOrdinal)
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
        if syncStageWithVisibleFloor() { bumpBoard() }
        blipIfBubbleChanged()
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

    // MARK: Un visitante por piso (E14b B7, D6)

    /// El que espera congelado en un piso que no se mira.
    func waitingVisitor(onFloor floor: Int) -> FloorVisitor? {
        player.flatMap { VisitorScheduler.waiting(onFloor: floor, state: $0.meta.engagement.visitors) }
    }

    /// Los que esperan en los otros pisos, del más alto al más bajo. Lo leen el
    /// aviso de la columna y el ascensor: se recalcula con `boardVersion`, que
    /// sube con cada cambio de piso, el único momento en que esta lista cambia.
    var visitorsWaitingElsewhere: [FloorVisitor] {
        (player?.meta.engagement.visitors.waiting ?? [])
            .filter { $0.floorOrdinal != visibleFloorOrdinal }
            .sorted { $0.floorOrdinal > $1.floorOrdinal }
    }

    /// Al cambiar de piso (D6): lo del piso que se deja se congela, la espera y
    /// la escena, y lo que esperaba en el piso nuevo sigue desde donde quedó. Lo
    /// llaman `setVisibleFloor` (en el acto) y `advanceStage` (cualquier otro
    /// camino que mueva el piso). Devuelve si cambió la lista de los que esperan.
    @discardableResult
    func syncStageWithVisibleFloor() -> Bool {
        let before = player?.meta.engagement.visitors.waiting
        let floor = visibleFloorOrdinal
        if let visit = stageVisit, visit.floorOrdinal != floor { leaveStageFloor(visit, for: floor) }
        if stageVisit == nil { resumeWaitingVisitor(onFloor: floor) }
        return player?.meta.engagement.visitors.waiting != before
    }

    /// Despacha desde el aviso al que espera en otro piso: se va a su piso y se
    /// abre su popup.
    func attendWaitingVisitor(onFloor floor: Int) {
        guard waitingVisitor(onFloor: floor) != nil else { return }
        // `setVisibleFloor` y no `jumpToFloor`: pudo quedar esperando en el piso
        // cerrado al que el jugador se asomaba.
        setVisibleFloor(floor)
        guard stageVisit?.floorOrdinal == floor else { return }
        openVisitorPopup()
    }

    /// Reencarnar: los congelados son de la run que se fue, como el que está en escena.
    func dismissWaitingVisitors() {
        stageRuntime.parked = [:]
        guard var player, !player.meta.engagement.visitors.waiting.isEmpty else { return }
        player.meta.engagement.visitors.waiting = []
        self.player = player
        scheduleSave()
    }

    private func leaveStageFloor(_ visit: StageVisit, for floor: Int) {
        switch visit.phase {
        case .leaving:
            // Ya se iba: se termina de ir.
            stageActorLeft(id: visit.id)
        case .entering where showing != .visitorEncounter:
            // Todavía no se vio: entra en el piso nuevo, o, si ahí ya espera otro,
            // no entra y el reloj vuelve a llamar pronto.
            if waitingVisitor(onFloor: floor) == nil {
                stageVisit?.floorOrdinal = floor
            } else {
                sendStageActorAway()
                retryVisitSoon()
            }
        case .entering:
            // Caminaba a la vista: llega en el acto y se congela parado en su lugar.
            stageActorArrived(id: visit.id)
            if let arrived = stageVisit, arrived.phase == .waiting { leaveStageFloor(arrived, for: floor) }
        case .waiting:
            if case .presenter = visit.role {
                // El presentador habla de un evento de toda la torre: acompaña.
                stageVisit?.floorOrdinal = floor
            } else if stageChallenge != nil {
                // El reto corre en todos los pisos: se congela cuando termine.
            } else if visit.offer == nil {
                // Ya cerró su trato (o no lo tenía): se iba en un rato, se va.
                stageVisit = nil
                visitorPopup = nil
                stageRuntime.patienceLeft = 0
            } else {
                park(visit)
            }
        }
    }

    private func park(_ visit: StageVisit) {
        guard case .visitor(let scriptId) = visit.role, var player else { return }
        VisitorScheduler.park(
            FloorVisitor(floorOrdinal: visit.floorOrdinal, visitorId: visit.actorId, scriptId: scriptId,
                         patienceLeft: stageRuntime.patienceLeft),
            state: &player.meta.engagement.visitors
        )
        self.player = player
        stageRuntime.parked[visit.floorOrdinal] = visit
        stageVisit = nil
        visitorPopup = nil
        stageRuntime.patienceLeft = 0
        scheduleSave()
    }

    /// Vuelve el que esperaba, con su espera intacta. Si la partida se relanzó en
    /// el medio, la oferta se cotiza de nuevo (como al llegar).
    private func resumeWaitingVisitor(onFloor floor: Int) {
        guard var player, waitingVisitor(onFloor: floor) != nil else { return }
        guard let waiting = VisitorScheduler.resume(floor: floor, state: &player.meta.engagement.visitors) else { return }
        self.player = player
        stageRuntime.patienceLeft = waiting.patienceLeft
        if let kept = stageRuntime.parked.removeValue(forKey: floor), kept.actorId == waiting.visitorId {
            stageVisit = kept
        } else {
            var visit = StageVisit(id: UUID(), actorId: waiting.visitorId, role: .visitor(scriptId: waiting.scriptId),
                                   phase: .waiting, bubble: nil, offer: nil, floorOrdinal: floor)
            arriveVisitor(&visit, scriptId: waiting.scriptId)
            stageVisit = visit
        }
        scheduleSave()
    }

    private func retryVisitSoon() {
        guard let content, var player else { return }
        VisitorScheduler.retrySoon(state: &player.meta.engagement.visitors, config: content.visitors)
        self.player = player
    }

    /// Un blip con la voz del que habla cada vez que el globo cambia a un texto.
    private func blipIfBubbleChanged() {
        guard let visit = stageVisit, visit.phase == .waiting, let text = visit.bubble, !text.isEmpty else {
            stageRuntime.lastBlipText = nil
            return
        }
        guard stageRuntime.lastBlipText != text else { return }
        stageRuntime.lastBlipText = text
        audio?.play(.talkBlip, gain: .action, pitch: AudioManager.talkPitch(for: visit.actorId))
    }

    private func completeArrival() {
        guard var visit = stageVisit, visit.phase == .entering else { return }
        audio?.play(.visitorArrive, gain: .action)
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
