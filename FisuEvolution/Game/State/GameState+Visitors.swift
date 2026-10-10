import EconomyKit
import Foundation

/// Los visitantes enganchados a la partida (PLAN-v2 E4). El motor es puro
/// (`VisitorScheduler`, `VisitPlanner`); acá se resuelve lo que necesita la
/// partida y se aplica. Quién entra y cómo camina es del escenario (`+Stage`).
extension GameState {
    /// Lo que se queda el que no tiene trato (o ya lo cerró) antes de irse.
    static let shortStaySeconds: TimeInterval = 4

    var visitContext: VisitContext? {
        guard let player else { return nil }
        return VisitContext(maxTier: player.run.maxTierReached,
                            ownedSpecials: Set(player.meta.ownedSpecials),
                            grantable: Self.grantableRewardKinds)
    }

    /// La misma valuación que FisuJobs: el segundo de producción y el descuento
    /// de prestigio (reponer a alguien cuesta lo que cuesta contratarlo).
    var visitValuation: VisitValuation {
        let discount = content?.prestigeUnlocks.cumulativeSpawnDiscount(
            atPrestigeLevel: player?.meta.prestigeLevel ?? 0
        ) ?? 0
        return VisitValuation(coinsPerSecond: coinsPerProductionSecond, hireCostMultiplier: 1 - discount)
    }

    func visitOffer(for script: VisitorsConfig.Script) -> VisitOffer? {
        guard let content, let player, let tower else { return nil }
        return VisitPlanner.offer(script, config: content.visitors, state: player, tower: tower,
                                  tiers: content.tiers, floorTable: content.floorTable,
                                  economy: content.economy, valuation: visitValuation)
    }

    /// Lo llama `advanceEngagement` con el delta del tick (juego activo, con tope).
    /// El guion que llamó un evento entra primero; un evento esperando a su
    /// presentador, antes que cualquier visitante (T4).
    func advanceVisitors(delta: TimeInterval, today: String = DailyRewardManager.dayString(for: Date())) {
        #if DEBUG
        if let scriptId = stageRuntime.debugScript, canPresentOnStage {
            stageRuntime.debugScript = nil
            if let script = content?.visitors.script(id: scriptId) { presentVisitor(script) }
            return
        }
        #endif
        if stageRuntime.calledScript != nil, canPresentOnStage {
            presentCalledScript()
            return
        }
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        VisitorScheduler.rollDay(&player.meta.engagement.visitors, today: today)
        let lane = VisitorScheduler.advance(&player.meta.engagement.visitors, delta: delta,
                                            config: content.visitors, rng: &rng)
        self.player = player
        guard let lane, canPresentOnStage, stageRuntime.pendingEvent == nil else { return }
        presentNextVisitor(lane: lane)
    }

    func presentNextVisitor(lane: VisitorsConfig.Lane) {
        guard let content, var player, let context = visitContext else { return }
        // Lo ofrecible se resuelve ANTES: el sorteo no puede leer `self` mientras
        // `rng` está prestado como `inout` (la misma regla que `fireDueEvent`).
        let offerable = Set(content.visitors.scripts.filter { visitOffer(for: $0) != nil }.map(\.id))
        guard let script = VisitorScheduler.pickNext(
            lane: lane, config: content.visitors, state: player.meta.engagement.visitors,
            context: context, isOfferable: { offerable.contains($0.id) }, rng: &rng
        ) else {
            VisitorScheduler.retrySoon(lane: lane, state: &player.meta.engagement.visitors, config: content.visitors)
            self.player = player
            return
        }
        presentVisitor(script)
    }

    /// Pone en escena un guion ya elegido: el sorteo, el llamado de un evento o
    /// la puerta de debug. Cuenta como visita (repetidos, tope del día, próximo).
    func presentVisitor(_ script: VisitorsConfig.Script) {
        guard let content, var player,
              presentOnStage(actorId: script.visitor, role: .visitor(scriptId: script.id))
        else { return }
        VisitorScheduler.markVisited(script, state: &player.meta.engagement.visitors,
                                     config: content.visitors, rng: &rng)
        self.player = player
        scheduleSave()
        Log.economy.info("visitor presented: \(script.id)")
    }

    /// El guion que llamó un evento (el blue del Arbolito, en el Cepo). Si ya no
    /// puede venir (no tenés al especial, se pasó del tope), el llamado se pierde:
    /// el evento igual pasó.
    func presentCalledScript() {
        guard let id = stageRuntime.calledScript else { return }
        stageRuntime.calledScript = nil
        guard let content, let player, let context = visitContext,
              let script = content.visitors.script(id: id),
              VisitorScheduler.isAvailable(script, config: content.visitors, state: player.meta.engagement.visitors,
                                           context: context, isOfferable: { visitOffer(for: $0) != nil })
        else { return }
        presentVisitor(script)
    }

    /// Llegó: se cotiza la oferta y el globo la cuenta. Sin trato posible (el
    /// tablero cambió mientras caminaba), una disculpa y se va.
    func arriveVisitor(_ visit: inout StageVisit, scriptId: String) {
        guard let content, let script = content.visitors.script(id: scriptId),
              let offer = visitOffer(for: script)
        else {
            visit.bubble = VisitCopy.text("visit.wrong_office")
            stageRuntime.patienceLeft = Self.shortStaySeconds
            return
        }
        visit.offer = offer
        visit.bubble = VisitCopy.bubble(for: script, offer: offer, content: content)
    }

    func openVisitorPopup() {
        guard let visit = stageVisit, visit.phase == .waiting, visit.offer != nil, stageChallenge == nil else { return }
        visitorPopup = VisitorPopup(id: visit.id)
        tutorialTipCompleted(.visitor)
    }

    /// Cerrar sin elegir no lo echa: sigue esperando con su paciencia.
    func closeVisitorPopup() {
        visitorPopup = nil
    }

    /// Lo que se paga se puede pagar: alcanza la plata y no hay corralito.
    func canAfford(_ option: VisitOption, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard option.cost > 0 else { return true }
        guard let player, ModifierMath.spendingFrozenUntil(player.run.activeModifiers, now: now) == nil else { return false }
        return player.run.coins >= option.cost
    }

    /// El jugador eligió (y, si pedía video, ya lo miró: lo llama la vista al
    /// terminar). Se revalida contra el tablero y la caja de AHORA. Devuelve si
    /// hubo trato.
    @discardableResult
    func chooseVisitOption(_ optionId: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard let visit = stageVisit, visit.phase == .waiting, let offer = visit.offer,
              let option = offer.option(id: optionId)
        else { return false }
        guard canAfford(option, now: now) else { return false }
        guard let player, let tower, let checked = VisitPlanner.revalidate(option, state: player, tower: tower) else {
            finishVisit(saying: "visit.deal_off")
            return false
        }
        let source = Self.rewardSource(for: checked, scriptId: offer.scriptId)
        switch checked.kind {
        case .startChallenge:
            guard let terms = checked.challenge else { return false }
            beginChallenge(scriptId: offer.scriptId, terms: terms, now: now)
            return true
        case .listen:
            creditCoins(checked.coins)
            grant(checked.rewards, source: source, now: now)
            revealGossip()
            return true
        case .accept, .acceptWithVideo, .payBail, .release, .payFine, .forgiveWithVideo, .sell, .exchange, .card:
            creditCoins(checked.coins)
            grant(checked.rewards, source: source, now: now)
            noteOroExchanged(checked, scriptId: offer.scriptId)
            // La plata ya está; la salida, a la vista y en su turno (E1). Si al
            // llegar su turno ya no es válida se descarta y la plata queda: el
            // trato se cerró con lo que había (duda 6 de E4a).
            for change in checked.departures { enqueueBoardChange(change) }
            finishVisit(saying: "visit.thanks")
            return true
        }
    }

    /// El origen de lo que da una opción: con él la barra de bonus le pone la
    /// cara y la duración (T4). Cada carta del Vendedor dura lo suyo; el "×2 con
    /// video" tiene su propia fuente porque dura el doble.
    static func rewardSource(for option: VisitOption, scriptId: String) -> String {
        switch option.kind {
        case .card: "visit.\(scriptId).\(option.id)"
        case .acceptWithVideo: "visit.\(scriptId).x2"
        case .accept, .payBail, .release, .payFine, .forgiveWithVideo, .sell, .exchange, .startChallenge, .listen:
            "visit.\(scriptId)"
        }
    }

    /// El reto arranca: el popup se cierra y los toques van al tablero.
    func beginChallenge(scriptId: String, terms: ChallengeTerms, now: TimeInterval) {
        visitorPopup = nil
        stageRuntime.challengeClock = now
        stageChallenge = StageChallenge(scriptId: scriptId, terms: terms, taps: 0, endsAt: now + terms.windowSeconds)
        stageVisit?.bubble = nil
    }

    /// Un toque a un empleado (`registerTap`). Sólo cuenta dentro de la ventana,
    /// medida con el reloj del reto.
    func noteStageTap(now: TimeInterval? = nil) {
        let now = now ?? stageRuntime.challengeClock
        guard var challenge = stageChallenge, now < challenge.endsAt else { return }
        challenge.taps += 1
        stageChallenge = challenge
        if challenge.taps >= challenge.terms.taps { finishChallenge(won: true, now: now) }
    }

    func finishChallenge(won: Bool, now: TimeInterval? = nil) {
        guard let challenge = stageChallenge else { return }
        let now = now ?? Date().timeIntervalSince1970
        stageChallenge = nil
        guard won else { return finishVisit(saying: "visit.challenge.lost") }
        creditCoins(challenge.terms.coins)
        grant(challenge.terms.rewards, source: "visit.\(challenge.scriptId)", now: now)
        guard challenge.terms.videoDoubles, var visit = stageVisit else {
            return finishVisit(saying: "visit.challenge.won")
        }
        // El ×2 del reto es OTRA tanda igual, por video: lo ofrece el mismo
        // visitante, con su chip y su popup, y si no lo querés se va igual.
        let double = VisitOption(id: "video", kind: .acceptWithVideo, coins: challenge.terms.coins,
                                 rewards: challenge.terms.rewards, departures: [], requiresVideo: true, challenge: nil)
        visit.offer = VisitOffer(scriptId: challenge.scriptId, visitorId: visit.actorId, subjectTypeId: nil, options: [double])
        visit.bubble = VisitCopy.text("visit.challenge.double")
        stageVisit = visit
        stageRuntime.patienceLeft = content?.visitors.patienceSeconds ?? 30
    }

    /// Cierra el trato: sin oferta (el chip desaparece), una frase y se va al rato.
    func finishVisit(saying key: String, _ arguments: [String] = []) {
        guard var visit = stageVisit else { return }
        visitorPopup = nil
        visit.offer = nil
        visit.bubble = VisitCopy.text(key, arguments)
        stageVisit = visit
        stageRuntime.patienceLeft = Self.shortStaySeconds
    }

    /// La Vecina: el próximo evento, que queda anotado y es el que sale.
    func revealGossip() {
        guard let event = peekUpcomingEvent() else {
            return finishVisit(saying: "visit.gossip.none")
        }
        finishVisit(saying: "visit.gossip.next", [VisitCopy.text(event.titleKey)])
    }

    /// El tope diario de ORO es del cambio con tope (el Arbolito de siempre); el
    /// blue del Cepo no lo usa ni lo gasta.
    private func noteOroExchanged(_ option: VisitOption, scriptId: String) {
        guard option.kind == .exchange, var player,
              case .exchange(_, _, let cap?) = content?.visitors.script(id: scriptId)?.mechanic, cap > 0
        else { return }
        player.meta.engagement.visitors.oroExchangedToday += option.rewards.reduce(0) { total, reward in
            if case .oro(let amount) = reward { return total + amount }
            return total
        }
        self.player = player
    }
}
