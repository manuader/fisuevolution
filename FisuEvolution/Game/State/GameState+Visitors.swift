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
                            grantable: Self.grantableRewardKinds,
                            allowsWeekly: allowsWeeklyVisits)
    }

    /// La misma valuación que FisuJobs: el segundo de producción y el descuento
    /// de prestigio (reponer a alguien cuesta lo que cuesta contratarlo).
    var visitValuation: VisitValuation {
        let discount = content?.prestigeUnlocks.cumulativeSpawnDiscount(
            atPrestigeLevel: player?.meta.prestigeLevel ?? 0
        ) ?? 0
        return VisitValuation(coinsPerSecond: coinsPerProductionSecond, hireCostMultiplier: 1 - discount)
    }

    /// El ×2 nunca va en el primer pop-up: sale después de cobrar (E14b B29, D17).
    func visitOffer(for script: VisitorsConfig.Script) -> VisitOffer? {
        guard let content, let player, let tower else { return nil }
        return VisitPlanner.offer(script, config: content.visitors, state: player, tower: tower,
                                  tiers: content.tiers, floorTable: content.floorTable,
                                  economy: content.economy, valuation: visitValuation)
    }

    /// Lo llama `advanceEngagement` con el delta del tick (juego activo, con tope).
    /// El guion que llamó un evento entra primero; un evento esperando a su
    /// presentador, antes que cualquier visitante (T4). La Marcha corre con la
    /// fecha de pared, antes que todo (E14b B25).
    func advanceVisitors(delta: TimeInterval, today: String = DailyRewardManager.dayString(for: Date())) {
        advanceMarch()
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
        guard engagementAutorun, !tutorialPhaseActive, let content else { return }
        countVisitorSessionIfNeeded()
        guard var player else { return }
        // La semana sólo puede cambiar con el día: no se recalcula en cada tick.
        if player.meta.engagement.visitors.day != today || player.meta.engagement.visitors.week == nil {
            VisitorScheduler.rollWeek(&player.meta.engagement.visitors, week: VisitorScheduler.weekKey(for: Date()))
        }
        VisitorScheduler.rollDay(&player.meta.engagement.visitors, today: today)
        let due = VisitorScheduler.advance(&player.meta.engagement.visitors, delta: delta, config: content.visitors)
        self.player = player
        guard due, canPresentOnStage, stageRuntime.pendingEvent == nil else { return }
        presentNextVisitor()
    }

    /// El próximo de la bolsa (E14 C5). La bolsa reordenada se guarda aunque
    /// nadie pueda venir: el que esperaba sigue primero.
    func presentNextVisitor() {
        guard let content, var player, let context = visitContext else { return }
        // Lo ofrecible se resuelve ANTES: el sorteo no puede leer `self` mientras
        // `rng` está prestado como `inout` (la misma regla que `fireDueEvent`).
        let offerable = Set(content.visitors.scripts.filter { visitOffer(for: $0) != nil }.map(\.id))
        let script = VisitorScheduler.pickNext(
            config: content.visitors, state: &player.meta.engagement.visitors,
            context: context, isOfferable: { offerable.contains($0.id) }, rng: &rng
        )
        if script == nil {
            VisitorScheduler.retrySoon(state: &player.meta.engagement.visitors, config: content.visitors)
        }
        self.player = player
        if let script { presentVisitor(script) }
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

    /// «No, gracias» (E14 C5): a cualquiera, el vendedor incluido. Se va sin
    /// cobrar ni dar nada, y la visita cuenta como hecha (la bolsa ya lo sacó al
    /// entrar).
    func declineVisit() {
        guard let visit = stageVisit, visit.phase == .waiting, visit.offer != nil, stageChallenge == nil else { return }
        finishVisit(saying: "visit.declined")
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
            // La Marcha (E14b B25) va al save con el reloj de pared; los demás retos, al escenario.
            if terms.realClock { return beginMarch(scriptId: offer.scriptId, terms: terms, now: now) }
            beginChallenge(scriptId: offer.scriptId, terms: terms, now: now)
            return true
        case .listen:
            creditCoins(checked.coins)
            announceReward(
                checked.rewards, coins: max(0, checked.coins) + grant(checked.rewards, source: source, now: now)
            )
            revealGossip()
            offerVisitDouble(scriptId: offer.scriptId, coins: checked.coins, rewards: checked.rewards, source: source)
            return true
        case .accept, .payBail, .release, .payFine, .forgiveWithVideo, .sell, .exchange, .card:
            creditCoins(checked.coins)
            announceReward(
                checked.rewards, coins: max(0, checked.coins) + grant(checked.rewards, source: source, now: now)
            )
            noteBlueExchanged(checked, scriptId: offer.scriptId)
            // La plata ya está; la salida, a la vista y en su turno (E1). Si al
            // llegar su turno ya no es válida se descarta y la plata queda: el
            // trato se cerró con lo que había (duda 6 de E4a).
            if checked.kind == .release { playCinematicIfDue(.arresto) }
            for change in checked.departures { enqueueBoardChange(change) }
            finishVisit(saying: "visit.thanks")
            if checked.kind == .accept {
                offerVisitDouble(scriptId: offer.scriptId, coins: checked.coins, rewards: checked.rewards,
                                 departures: checked.departures, source: source)
            }
            return true
        }
    }

    /// El origen de lo que da una opción: con él la barra de bonus le pone la
    /// cara y la duración (T4). Cada carta del Vendedor dura lo suyo.
    static func rewardSource(for option: VisitOption, scriptId: String) -> String {
        switch option.kind {
        case .card: "visit.\(scriptId).\(option.id)"
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
        let granted = grant(challenge.terms.rewards, source: "visit.\(challenge.scriptId)", now: now)
        announceReward(challenge.terms.rewards, coins: max(0, challenge.terms.coins) + granted)
        finishVisit(saying: "visit.challenge.won")
        // Lo ganado es gratis: el ×2 sale en el paso 2, como el de cualquier regalo (E14b B29).
        offerVisitDouble(scriptId: challenge.scriptId, coins: challenge.terms.coins, rewards: challenge.terms.rewards,
                         source: "visit.\(challenge.scriptId)")
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

    /// El tope diario de blue es del cambio con tope (el Arbolito de siempre); el
    /// Blue del Cepo no lo usa ni lo gasta.
    private func noteBlueExchanged(_ option: VisitOption, scriptId: String) {
        guard option.kind == .exchange, var player,
              case .exchange(_, _, let cap?) = content?.visitors.script(id: scriptId)?.mechanic, cap > 0
        else { return }
        player.meta.engagement.visitors.blueExchangedToday += option.rewards.reduce(0) { total, reward in
            if case .blue(let amount) = reward { return total + amount }
            return total
        }
        self.player = player
    }
}
