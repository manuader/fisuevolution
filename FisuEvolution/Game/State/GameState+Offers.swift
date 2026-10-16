import EconomyKit
import Foundation

/// Las ofertas de 24 h en la partida (PLAN-v2 E6): el cobro, el reloj y lo que se presenta.
extension GameState {
    /// Lo que trae una oferta pagada, esté abierta o no: la ventana gobierna qué
    /// se ofrece, no qué se entrega. Su blue es blue **comprado**: se anota por
    /// `recordBluePurchase`, así el reset de E9 lo conserva si no se gastó y un
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
        let coins = grant(offer.rewards, source: "offer.\(offerId)", now: now)
        announceReward(offer.rewards, coins: coins)
        guard var player else { return }
        player.meta.recordBluePurchase(transactionID: transactionID, amount: offer.blueAmount)
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
    ///
    /// `segment` es para los tests; sin él rige el del jugador (`base` con la personalización
    /// apagada: las ofertas de la 2.0).
    func advanceOffers(
        now: TimeInterval = Date().timeIntervalSince1970,
        chanceAllowed: Bool? = nil,
        segment: PlayerSegment? = nil
    ) {
        guard let content, var player else { return }
        let before = player.meta.engagement
        let today = Self.offersDay(now)
        if player.meta.engagement.firstLaunchDay == nil {
            player.meta.engagement.firstLaunchDay = today
        }
        if engagementAutorun, !tutorialPhaseActive {
            let signals = Self.offerSignals(player: player, today: today, segment: segment ?? self.segment)
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

    /// Lo que el motor mira para abrir una oferta. Desde la 2.1 lleva el segmento y si el jugador
    /// ya compró algo con plata: la audiencia de una oferta (`offers.json`) elige **qué** oferta ve
    /// cada uno, nunca el precio. Con `base` la audiencia se ignora.
    func offerSignals(today: String, segment: PlayerSegment? = nil) -> OfferSignals {
        guard let player else {
            return OfferSignals(today: today, firstLaunchDay: nil, prestigeLevel: 0, unlockedFloorCount: 0,
                                segment: segment ?? self.segment)
        }
        return Self.offerSignals(player: player, today: today, segment: segment ?? self.segment)
    }

    private static func offerSignals(player: PlayerState, today: String, segment: PlayerSegment) -> OfferSignals {
        OfferSignals(
            today: today,
            firstLaunchDay: player.meta.engagement.firstLaunchDay,
            prestigeLevel: player.meta.prestigeLevel,
            unlockedFloorCount: player.run.unlockedFloors.count,
            segment: segment,
            hasPurchased: !player.meta.creditedPurchases.isEmpty
        )
    }

    /// Si el jugador ya compró algo con plata (cualquier transacción acreditada, también las
    /// restauradas): lo que separa `buyer` de `nonBuyer`.
    var hasPaidPurchase: Bool {
        !(player?.meta.creditedPurchases.isEmpty ?? true)
    }

    /// La oferta se le abrió por ser quien es: tiene audiencia y el segmento no es `base` (con
    /// `base` la audiencia no cuenta y la oferta es la de todos).
    func isOfferChosenForPlayer(_ offerId: String, segment: PlayerSegment? = nil) -> Bool {
        guard let offer = content?.offers.offer(id: offerId) else { return false }
        return OfferNotice.isChosen(audience: offer.audience, segment: segment ?? self.segment)
    }

    /// El aviso «Oferta elegida para vos» de la hoja: una oferta elegida, en una tienda de la UE (V8).
    func showsChosenNotice(offerId: String, storefront: String?, segment: PlayerSegment? = nil) -> Bool {
        isOfferChosenForPlayer(offerId, segment: segment) && OfferNotice.isEU(storefront: storefront)
    }

    /// El pack que la Tienda destaca con «Elegido para vos» (2.1 F5, `StoreRecommendation`), o
    /// `nil`. Sólo entre `entries` —los productos que la Tienda muestra—: nunca destaca algo que no
    /// está a la venta, ni oculta, reordena o cambia el precio de nada. Con `base`, `nil`: la 2.0.
    ///
    /// «El último comprado» es el pack de blue más grande cuyo monto figura entre las compras de
    /// blue del jugador (la partida anota montos por transacción, no productos ni fechas).
    func storeHighlight(entries: [ProductCatalog.Entry], segment: PlayerSegment? = nil) -> String? {
        let packs = entries.compactMap { entry -> StoreRecommendation.Pack? in
            switch entry.entitlement {
            case .starterPack:
                return StoreRecommendation.Pack(id: entry.id, kind: .starter, blueAmount: 0)
            case .blue:
                return entry.blueAmount.map { StoreRecommendation.Pack(id: entry.id, kind: .blue, blueAmount: $0) }
            case .coins, .removeAds, .skin, .offer:
                return nil
            }
        }
        let boughtAmounts = Set(player.map { Array($0.meta.bluePurchases.values) } ?? [])
        let lastPurchased = packs
            .filter { $0.kind == .blue && boughtAmounts.contains($0.blueAmount) }
            .max { $0.blueAmount < $1.blueAmount }
        return StoreRecommendation.highlight(
            segment: segment ?? self.segment,
            hasPurchased: hasPaidPurchase,
            lastPurchasedID: lastPurchased?.id,
            packs: packs
        )
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
