import EconomyKit
import Foundation

/// Las ofertas de 24 h en la partida (PLAN-v2 E6): el cobro, el reloj y lo que se presenta.
extension GameState {
    /// Lo que trae una oferta pagada, esté abierta o no: la ventana gobierna qué
    /// se ofrece, no qué se entrega. Su ORO es ORO **comprado**: se anota por
    /// `recordOroPurchase`, así el reset de E9 lo conserva si no se gastó y un
    /// reembolso lo descuenta, igual que con un pack.
    func creditOffer(
        _ offerId: String?,
        transactionID: String,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        guard let offerId, let offer = content?.offers.offer(id: offerId) else {
            Log.store.error("offer purchase without a known offer: \(offerId ?? "nil")")
            return
        }
        grant(offer.rewards, source: "offer.\(offerId)", now: now)
        guard var player else { return }
        player.meta.recordOroPurchase(transactionID: transactionID, amount: offer.oroAmount)
        OffersEngine.markPurchased(offerId, in: &player.meta.engagement.offers, now: now)
        self.player = player
        refreshProjections()
        scheduleSave()
        Log.store.info("offer credited: \(offerId)")
    }

    /// Lo llama `advanceEngagement` en cada tick. El reloj de una oferta es de
    /// pared, pero se ABRE sólo jugando: una oferta nunca vence sin haber
    /// aparecido. El primer día se anota siempre, también con los motores
    /// apagados: es un dato de la cuenta, no un motor.
    ///
    /// `chanceAllowed` lo resuelve quien llama; sin él rige la última respuesta de
    /// StoreKit (`LootBoxGate.lastKnown`), que arranca cerrada y se renueva cuando
    /// cambia la tienda del jugador. Se consulta por oferta, al momento de abrirla.
    func advanceOffers(now: TimeInterval = Date().timeIntervalSince1970, chanceAllowed: Bool? = nil) {
        guard let content, var player else { return }
        let before = player.meta.engagement
        let today = Self.offersDay(now)
        if player.meta.engagement.firstLaunchDay == nil {
            player.meta.engagement.firstLaunchDay = today
        }
        if engagementAutorun, !tutorialPhaseActive {
            let signals = OfferSignals(
                today: today,
                firstLaunchDay: player.meta.engagement.firstLaunchDay,
                prestigeLevel: player.meta.prestigeLevel,
                unlockedFloorCount: player.run.unlockedFloors.count
            )
            OffersEngine.evaluate(&player.meta.engagement.offers, catalog: content.offers, signals: signals, now: now) {
                self.isOfferOfferable($0, chanceAllowed: chanceAllowed ?? LootBoxGate.lastKnown)
            }
        }
        guard player.meta.engagement != before else {
            // Nada cambió, pero el tablero pudo destaparse: la oferta que esperaba su lugar lo toma.
            if offerToPresent != nil, !celebrations.contains(.offer), isCalmMoment { syncCelebrations() }
            return
        }
        self.player = player
        effectsVersion += 1
        syncCelebrations()
        scheduleSave()
    }

    /// El día de las ofertas, en calendario gregoriano: el primer día y "hoy" se
    /// comparan como texto, y con otro calendario no ordenarían.
    private static func offersDay(_ now: TimeInterval) -> String {
        DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now), calendar: gregorianCalendar)
    }

    /// Se ofrece si todo lo que trae se puede entregar y, si trae azar, si en
    /// esta tienda se vende azar.
    func isOfferOfferable(_ offer: OffersCatalog.Offer, chanceAllowed: Bool) -> Bool {
        guard offer.rewards.allSatisfy({ Self.grantableRewardKinds.contains($0.kind) }) else { return false }
        return !offer.isChance || chanceAllowed
    }

    /// Las abiertas, ofrecibles o no.
    func activeOffers(now: TimeInterval = Date().timeIntervalSince1970) -> [ActiveOffer] {
        guard let player else { return [] }
        return OffersEngine.activeOffers(player.meta.engagement.offers, now: now)
    }

    /// Las abiertas que hoy se pueden ver y comprar: la puerta del azar se mira
    /// cada vez, porque la tienda del jugador puede cambiar con la oferta abierta.
    func visibleOffers(
        now: TimeInterval = Date().timeIntervalSince1970,
        chanceAllowed: Bool = LootBoxGate.lastKnown
    ) -> [ActiveOffer] {
        guard let content else { return [] }
        return activeOffers(now: now).filter {
            content.offers.offer(id: $0.id).map { offer in isOfferOfferable(offer, chanceAllowed: chanceAllowed) } ?? false
        }
    }

    /// La oferta que todavía no se mostró sola. Nunca en el tutorial.
    func presentableOffer(chanceAllowed: Bool = LootBoxGate.lastKnown) -> ActiveOffer? {
        guard !tutorialPhaseActive else { return nil }
        return visibleOffers(chanceAllowed: chanceAllowed).first { !$0.presented }
    }

    var offerToPresent: ActiveOffer? { presentableOffer() }

    /// La oferta que muestra la hoja ya se vio: no vuelve a presentarse sola, ni
    /// siquiera si la app se mata con la hoja arriba.
    func markOfferPresented(id: String) {
        guard var player,
              let index = player.meta.engagement.offers.active.firstIndex(where: { $0.id == id }),
              !player.meta.engagement.offers.active[index].presented
        else { return }
        player.meta.engagement.offers.active[index].presented = true
        self.player = player
        scheduleSave()
    }

    /// La hoja de esta oferta arrancó su turno de la cola: se marca vista y el
    /// turno es suyo hasta que se cierre.
    func offerPresentationStarted(_ id: String) {
        presentingOfferId = id
        markOfferPresented(id: id)
    }

    /// El turno de `.offer` sigue mientras la oferta que se muestra se pueda ver;
    /// si todavía no se mostró ninguna, mientras haya una por presentar.
    var offerTurnHasSomethingToShow: Bool {
        guard let presentingOfferId else { return offerToPresent != nil }
        return visibleOffers().contains { $0.id == presentingOfferId }
    }

    /// El permiso para iniciar la compra de una oferta, ANTES de llamar a StoreKit.
    /// Es plata: el cerrojo corta el segundo toque (sin apagar el botón), y una
    /// oferta que venció, ya se compró o no se vende en esta tienda no se cobra.
    /// Quien lo toma suelta el cerrojo cuando la compra termina.
    func beginOfferPurchase(
        _ offerId: String,
        latch: inout PurchaseLatch,
        chanceAllowed: Bool,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Bool {
        guard latch.claim() else { return false }
        guard visibleOffers(now: now, chanceAllowed: chanceAllowed).contains(where: { $0.id == offerId }) else {
            latch.release()
            return false
        }
        return true
    }

    #if DEBUG
    /// Una oferta abierta ya mismo: se disparan a las horas, sin esta puerta no
    /// se pueden ni fotografiar ni probar.
    func debugOpenOffer(id: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, var player else { return }
        guard OffersEngine.open(id, in: &player.meta.engagement.offers, catalog: content.offers, now: now) else { return }
        self.player = player
        effectsVersion += 1
        syncCelebrations()
        scheduleSave()
    }
    #endif
}
