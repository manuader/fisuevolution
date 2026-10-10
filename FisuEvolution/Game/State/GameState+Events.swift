import EconomyKit
import Foundation

/// Los eventos v2 (PLAN-v2 E4) enganchados a la partida. El motor es puro
/// (`EventScheduler`, `EventPlanner`); acá se resuelve lo que necesita la
/// partida y se aplica. El reloj es de juego activo y vive en el save
/// (`meta.engagement.events`): cerrar la app ya no reinicia la espera y el
/// background no cuenta.
extension GameState {
    /// La Startup sólo hace crecer a quien está a esta distancia de la frontera o
    /// más abajo: un evento nunca abre un tier (PLAN-v2 E13).
    static let startupTiersBelowFrontier = 2

    /// Lo llama `advanceEngagement` con el delta del tick (juego activo, con tope).
    /// Durante la fase obligatoria del tutorial no corre.
    func advanceEvents(delta: TimeInterval) {
        // Con un evento esperando su presentador el reloj no sortea otro: pisaría
        // al que ya gastó su cooldown.
        guard engagementAutorun, !tutorialPhaseActive, stageRuntime.pendingEvent == nil,
              let content, var player else { return }
        let due = EventScheduler.advance(&player.meta.engagement.events, delta: delta, catalog: content.events)
        self.player = player
        if due { fireDueEvent(now: Date().timeIntervalSince1970) }
    }

    /// Toma el que la Vecina adelantó (si sigue elegible) o sortea. Un sorteo vacío
    /// reintenta pronto sin gastar el intervalo (E1 T11).
    func fireDueEvent(now: TimeInterval) {
        guard let content, var player else { return }
        // Lo aplicable se resuelve ANTES: el sorteo no puede leer `self` mientras
        // `rng` está prestado como `inout`.
        let applicable = Set(content.events.events.filter(eventIsApplicable).map(\.id))
        let immune = ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now)
        guard let event = EventScheduler.takeDue(
            catalog: content.events, state: &player.meta.engagement.events,
            maxTier: player.run.maxTierReached, isImmune: immune,
            isApplicable: { applicable.contains($0.id) }, rng: &rng
        ) else {
            EventScheduler.retrySoon(state: &player.meta.engagement.events, catalog: content.events)
            self.player = player
            return
        }
        EventScheduler.markFired(event, state: &player.meta.engagement.events, catalog: content.events, rng: &rng)
        self.player = player
        presentEvent(event)
    }

    /// Aplica un evento: sus modificadores (`event.<id>`), su plata por `grant`, su
    /// intención de tablero por el embudo de E1 y el anuncio. Lo llama el
    /// presentador al llegar a escena.
    func startEvent(_ event: EventCatalog.Event, now: TimeInterval) {
        guard let content, var player, let tower else { return }
        let application = EventPlanner.apply(event, state: player, tiers: content.tiers, now: now)
        player.run.activeModifiers.removeAll { $0.sourceKey == event.sourceKey }
        player.run.activeModifiers += application.modifiers
        self.player = player
        if let called = application.calledScript { stageRuntime.calledScript = called }
        if application.coinsSeconds > 0 {
            grant(.coinsSeconds(application.coinsSeconds), source: event.sourceKey, now: now)
        }
        if let player = self.player {
            let change: BoardChange? = switch application.boardIntent {
            case .evolveBestUnit:
                BoardChangePlanner.planEvolve(
                    state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable,
                    maxSourceTier: player.run.maxTierReached - Self.startupTiersBelowFrontier, origin: .eventStartup
                )
            case .grantUnit(let typeId):
                BoardChangePlanner.planArrival(
                    typeId: typeId, state: player, tower: tower, tiers: content.tiers,
                    floorTable: content.floorTable, origin: .eventBlanqueo
                )
            case nil:
                nil
            }
            if let change { enqueueBoardChange(change) }
        }
        audio?.play(AudioManager.accent(forEvent: event.id))
        effectsVersion += 1
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(event.id)")
    }

    /// Puede pasar AHORA: el Aguinaldo pide pasivo, la Startup alguien que crezca
    /// solo, el Blanqueo lugar en su piso, y los paquetes que E5 ya los entregue.
    func eventIsApplicable(_ event: EventCatalog.Event) -> Bool {
        guard let content, let player, let tower else { return false }
        return event.effects.allSatisfy { effect in
            switch effect {
            case .modifier(let modifierEffect, _):
                return modifierEffect != .packageRateMultiplier || Self.grantableRewardKinds.contains(.package)
            case .coinsSeconds:
                return IncomeTicker.basePassivePerSecond(
                    state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy
                ) > 0
            case .evolveBestUnit:
                return BoardChangePlanner.planEvolve(
                    state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable,
                    maxSourceTier: player.run.maxTierReached - Self.startupTiersBelowFrontier, origin: .eventStartup
                ) != nil
            case .grantUnit(let below):
                guard let type = EventPlanner.grantedUnitType(tiersBelowFrontier: below, state: player, tiers: content.tiers)
                else { return false }
                return BoardChangePlanner.planArrival(
                    typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                    floorTable: content.floorTable, origin: .eventBlanqueo
                ) != nil
            case .callVisitor:
                // El llamado es un plus: si el visitante no puede venir, el evento igual pasa.
                return true
            }
        }
    }

    /// Lo que cuesta la cuota de un evento ahora, en plata.
    func eventFee(id: String) -> Double? {
        guard let feeSeconds = content?.events.event(id: id)?.escapes.first(where: { $0.kind == .fee })?.feeSeconds
        else { return nil }
        return feeSeconds * coinsPerProductionSecond
    }

    func eventFeeText(id: String) -> String {
        CoinFormatter.string(from: eventFee(id: id) ?? 0)
    }

    /// La salida todavía saca algo: la del video de la Hiperinflación sólo saca el
    /// costo de contratar, y una vez usada no queda nada que sacar.
    func escapeStillRemoves(
        _ escape: EventCatalog.Escape, of event: EventCatalog.Event,
        in modifiers: [ActiveModifier], now: TimeInterval
    ) -> Bool {
        guard let removes = escape.removes else { return true }
        return modifiers.contains { $0.sourceKey == event.sourceKey && $0.isActive(at: now) && removes.contains($0.effect) }
    }

    /// Las salidas del popup: sólo las que todavía sirven.
    func usableEscapes(of event: EventCatalog.Event, now: TimeInterval = Date().timeIntervalSince1970) -> [EventCatalog.Escape] {
        let modifiers = player?.run.activeModifiers ?? []
        return event.escapes.filter { escapeStillRemoves($0, of: event, in: modifiers, now: now) }
    }

    /// Salir de un evento por una de sus salidas. La cuota se cobra; el video ya se
    /// miró (lo llama la vista al terminar); gratis es gratis.
    @discardableResult
    func escapeEvent(
        id: String,
        via kind: EventCatalog.Escape.Kind,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Bool {
        guard let content, let event = content.events.event(id: id),
              let escape = event.escapes.first(where: { $0.kind == kind }),
              var player,
              player.run.activeModifiers.contains(where: { $0.sourceKey == event.sourceKey && $0.isActive(at: now) }),
              escapeStillRemoves(escape, of: event, in: player.run.activeModifiers, now: now)
        else { return false }
        if kind == .fee {
            let fee = eventFee(id: id) ?? 0
            guard player.run.coins >= fee else { return false }
            player.run.coins -= fee
        }
        player.run.activeModifiers = EventPlanner.escape(escape, of: event, from: player.run.activeModifiers)
        self.player = player
        if eventPopup?.eventId == id, !isEventRunning(id: id, now: now) { eventPopup = nil }
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        Log.economy.info("event escaped: \(id) via \(kind.rawValue)")
        return true
    }

    /// La Obra social del Médico corta los negativos en curso (no los mixtos).
    func cutNegativeEvents(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, var player else { return }
        player.run.activeModifiers = EventPlanner.cutNegatives(player.run.activeModifiers, catalog: content.events)
        self.player = player
        if let popup = eventPopup, !isEventRunning(id: popup.eventId, now: now) { eventPopup = nil }
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
    }

    /// Al volver a la app, un evento vencido no dispara en la cara (E1 T8 lo llama
    /// desde `handleScenePhase`). Con el reloj de juego, el background no lo mueve:
    /// lo que se corre es el que ya estaba por salir.
    func postponeOverdueEvent(now: TimeInterval) {
        guard let content, var player else { return }
        EventScheduler.applyResumeGrace(state: &player.meta.engagement.events, catalog: content.events)
        self.player = player
    }

    /// Lo que viene, y queda anotado: es lo que va a salir (la Vecina chusma).
    func peekUpcomingEvent() -> EventCatalog.Event? {
        guard let content, var player else { return nil }
        let now = Date().timeIntervalSince1970
        let applicable = Set(content.events.events.filter(eventIsApplicable).map(\.id))
        let event = EventScheduler.peekUpcoming(
            catalog: content.events, state: &player.meta.engagement.events,
            maxTier: player.run.maxTierReached,
            isImmune: ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now),
            isApplicable: { applicable.contains($0.id) }, rng: &rng
        )
        self.player = player
        scheduleSave()
        return event
    }

    // MARK: El presentador

    /// El evento sale con su presentador: entra a escena, lo anuncia y recién al
    /// llegar pasa. Con el escenario ocupado espera, y ningún visitante entra antes.
    func presentEvent(_ event: EventCatalog.Event) {
        stageRuntime.pendingEvent = event
        presentPendingEventIfPossible()
    }

    func presentPendingEventIfPossible() {
        guard let event = stageRuntime.pendingEvent, canPresentOnStage else { return }
        stageRuntime.pendingEvent = nil
        presentOnStage(actorId: presenter(for: event), role: .presenter(eventId: event.id))
    }

    /// Uno de sus presentadores que pueda venir: un especial, sólo si lo tenés.
    func presenter(for event: EventCatalog.Event) -> String {
        let owned = Set(player?.meta.ownedSpecials ?? [])
        let candidates = event.presenters.filter { id in
            content?.visitors.visitor(id: id)?.kind == .npc || owned.contains(id)
        }
        return candidates.randomElement(using: &rng) ?? event.presenters.first ?? "npc_conductor"
    }

    /// La cara del chip: quien lo anunció, o el primero del dato (después de relanzar).
    func eventPresenterId(_ event: EventCatalog.Event) -> String {
        stageRuntime.eventPresenters[event.id] ?? event.presenters.first ?? "npc_conductor"
    }

    /// Llegó el presentador: el evento pasa ahora y él dice la frase. Si el evento
    /// dejó de aplicar mientras caminaba, no se presenta; contra un negativo con
    /// inmunidad (la Obra social), llega y avisa que no te toca.
    func arrivePresenter(_ visit: inout StageVisit, eventId: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let event = content.events.event(id: eventId), let player else { return }
        stageRuntime.patienceLeft = content.visitors.presenterTalkSeconds
        guard eventIsApplicable(event) else {
            stageRuntime.patienceLeft = 0
            return
        }
        if event.polarity == .negative, ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now) {
            visit.bubble = VisitCopy.text("event.immune")
            return
        }
        stageRuntime.eventPresenters[event.id] = visit.actorId
        startEvent(event, now: now)
        visit.bubble = VisitCopy.text(event.phraseKey)
    }

    func isEventRunning(id: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        player?.run.activeModifiers.contains { $0.sourceKey == "event.\(id)" && $0.isActive(at: now) } == true
    }

    /// El popup de un evento corriendo (su chip o su presentador).
    func openEventPopup(id: String) {
        guard isEventRunning(id: id) else { return }
        eventPopup = EventPopup(eventId: id)
        tutorialTipCompleted(.eventChip)
    }

    func closeEventPopup() {
        eventPopup = nil
    }

    // MARK: Las escenas (E4b T6)

    /// Las escenas de los eventos corriendo (Apagón, Campeones, Liquidación).
    func runningEventScenes(now: TimeInterval = Date().timeIntervalSince1970) -> Set<EventCatalog.Scene> {
        guard let content, let player else { return [] }
        return Set(EventPlanner.running(player.run.activeModifiers, catalog: content.events, now: now).compactMap(\.scene))
    }

    /// Las velitas del Apagón: cuántas hay prendidas y cuántas llevan a ×1.
    func blackoutCandles(now: TimeInterval = Date().timeIntervalSince1970) -> (lit: Int, total: Int)? {
        guard let content, let player,
              let event = content.events.events.first(where: { $0.scene == .blackout }),
              let step = event.candleStep, step > 0,
              let live = player.run.activeModifiers.first(where: {
                  $0.sourceKey == event.sourceKey && $0.effect == .incomeMultiplier && $0.isActive(at: now)
              })
        else { return nil }
        var base = live.magnitude
        for case let .modifier(effect, magnitude) in event.effects where effect == .incomeMultiplier {
            base = magnitude
        }
        // El épsilon salva el redondeo de 0,7 / 0,07 (= 10,000000000000002).
        let total = max(1, Int(((1 - base) / step - 1e-9).rounded(.up)))
        let lit = Int(((live.magnitude - base) / step).rounded())
        return (min(max(lit, 0), total), total)
    }

    /// Un toque a un empleado durante el Apagón prende una velita: el ingreso del
    /// evento sube `candleStep`, hasta ×1. Lo llama `registerTap`, que después
    /// refresca y guarda.
    @discardableResult
    func lightCandleIfBlackout(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard let content, var player,
              let event = content.events.events.first(where: { $0.scene == .blackout }),
              let lit = EventPlanner.lightCandle(player.run.activeModifiers, event: event, now: now)
        else { return false }
        player.run.activeModifiers = lit
        self.player = player
        effectsVersion += 1
        return true
    }
}
