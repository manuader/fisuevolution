import EconomyKit
import Foundation

/// Los eventos v2 (PLAN-v2 E4) enganchados a la partida. El motor es puro
/// (`EventScheduler`, `EventPlanner`); acá se resuelve lo que necesita la
/// partida y se aplica. El reloj es de juego activo y vive en el save
/// (`meta.engagement.events`): cerrar la app ya no reinicia la espera y el
/// background no cuenta.
extension GameState {
    /// El evento del banner. E4b lo reemplaza por el chip con la cara del presentador.
    struct ActiveEvent: Equatable, Identifiable {
        let id: String
        let phraseKey: String
        let polarity: EventCatalog.Polarity
        let endsAt: TimeInterval
        let escapes: [EventCatalog.Escape]
    }

    /// Lo que dura el banner de un evento sin duración (Aguinaldo, Startup, Blanqueo).
    static let instantEventBannerSeconds: TimeInterval = 6

    /// La Startup sólo hace crecer a quien está a esta distancia de la frontera o
    /// más abajo: un evento nunca abre un tier (PLAN-v2 E13).
    static let startupTiersBelowFrontier = 2

    /// Lo llama `advanceEngagement` con el delta del tick (juego activo, con tope).
    /// Durante la fase obligatoria del tutorial no corre.
    func advanceEvents(delta: TimeInterval) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
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
        startEvent(event, now: now)
    }

    /// Aplica un evento: sus modificadores (`event.<id>`), su plata por `grant`, su
    /// intención de tablero por el embudo de E1 y el anuncio. E4b lo llama cuando
    /// el presentador llega a escena.
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
        activeEvent = ActiveEvent(
            id: event.id, phraseKey: event.phraseKey, polarity: event.polarity,
            endsAt: now + max(event.durationSeconds, Self.instantEventBannerSeconds), escapes: event.escapes
        )
        audio?.play(AudioManager.accent(forEvent: event.id))
        effectsVersion += 1
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(event.id)")
    }

    /// El banner se va cuando el evento termina. Lo llama `flushHUD`.
    func expireActiveEvent(now: TimeInterval) {
        if let active = activeEvent, now >= active.endsAt { activeEvent = nil }
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
              player.run.activeModifiers.contains(where: { $0.sourceKey == event.sourceKey && $0.isActive(at: now) })
        else { return false }
        if kind == .fee {
            let fee = eventFee(id: id) ?? 0
            guard player.run.coins >= fee else { return false }
            player.run.coins -= fee
        }
        player.run.activeModifiers = EventPlanner.escape(escape, of: event, from: player.run.activeModifiers)
        self.player = player
        if activeEvent?.id == id, !player.run.activeModifiers.contains(where: { $0.sourceKey == event.sourceKey }) {
            activeEvent = nil
        }
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
        if let active = activeEvent, active.polarity == .negative { activeEvent = nil }
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
}
