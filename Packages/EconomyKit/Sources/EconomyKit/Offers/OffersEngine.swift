import Foundation

/// Lo que la app sabe de la partida y el motor necesita para disparar.
public struct OfferSignals: Sendable, Equatable {
    /// "yyyy-MM-dd" de hoy.
    public let today: String
    public let firstLaunchDay: String?
    public let prestigeLevel: Int
    /// Pisos abiertos en la run (`run.unlockedFloors.count`).
    public let unlockedFloorCount: Int

    public init(today: String, firstLaunchDay: String?, prestigeLevel: Int, unlockedFloorCount: Int) {
        self.today = today
        self.firstLaunchDay = firstLaunchDay
        self.prestigeLevel = prestigeLevel
        self.unlockedFloorCount = unlockedFloorCount
    }
}

/// Cuándo se abre y se cierra cada oferta (PLAN-v2 E6). Puro: el `now` es de
/// pared y lo pasa la app; el "ofrecible" también (lo entregable y el azar los
/// sabe ella).
public enum OffersEngine {
    /// Cierra las vencidas, mira los disparadores y abre lo que corresponde.
    /// Devuelve los ids que se abrieron ahora.
    @discardableResult
    public static func evaluate(
        _ state: inout OffersState,
        catalog: OffersCatalog,
        signals: OfferSignals,
        now: Double,
        isOfferable: (OffersCatalog.Offer) -> Bool
    ) -> [String] {
        closeExpired(&state, now: now)
        var fired: Set<OffersCatalog.Trigger> = []
        if let first = signals.firstLaunchDay, signals.today > first { fired.insert(.secondDay) }
        // La primera vez sólo se toma la línea de base: lo que ya pasó no dispara.
        if let seen = state.seenPrestigeLevel, signals.prestigeLevel > seen { fired.insert(.reincarnation) }
        state.seenPrestigeLevel = signals.prestigeLevel
        // Una run nueva arranca con menos pisos: se baja la línea sin disparar.
        if let seen = state.seenUnlockedFloors, signals.unlockedFloorCount > seen { fired.insert(.newFloor) }
        state.seenUnlockedFloors = signals.unlockedFloorCount

        var opened: [String] = []
        for offer in catalog.offers where fired.contains(offer.trigger) && isOfferable(offer) {
            if open(offer.id, in: &state, catalog: catalog, now: now) { opened.append(offer.id) }
        }
        return opened
    }

    /// Abre una oferta si se puede. Lo usa `evaluate` y la puerta de test.
    @discardableResult
    public static func open(_ id: String, in state: inout OffersState, catalog: OffersCatalog, now: Double) -> Bool {
        guard let offer = catalog.offer(id: id), canOpen(offer, state: state, catalog: catalog, now: now) else { return false }
        state.active.append(ActiveOffer(id: id, openedAt: now, expiresAt: now + catalog.windowSeconds, presented: false))
        state.everOpened.insert(id)
        return true
    }

    /// No está abierta (la ventana no se estira), no se usó (las de una vez) y
    /// pasó el enfriamiento desde que cerró.
    public static func canOpen(_ offer: OffersCatalog.Offer, state: OffersState, catalog: OffersCatalog, now: Double) -> Bool {
        guard !state.active.contains(where: { $0.id == offer.id }) else { return false }
        if offer.oncePerAccount, state.everOpened.contains(offer.id) { return false }
        if let closed = state.lastClosedAt[offer.id], now < closed + catalog.cooldownSeconds { return false }
        return true
    }

    public static func activeOffers(_ state: OffersState, now: Double) -> [ActiveOffer] {
        state.active.filter { $0.expiresAt > now }
    }

    /// Una compra pagada: se cuenta siempre, marca el cierre (arranca el
    /// enfriamiento y el otro dispositivo no la vuelve a vender) y cierra la
    /// ventana si estaba abierta.
    public static func markPurchased(_ id: String, in state: inout OffersState, now: Double) {
        state.purchases[id, default: 0] += 1
        state.lastClosedAt[id] = max(state.lastClosedAt[id] ?? 0, now)
        state.active.removeAll { $0.id == id }
    }

    private static func closeExpired(_ state: inout OffersState, now: Double) {
        for offer in state.active where offer.expiresAt <= now {
            state.lastClosedAt[offer.id] = max(state.lastClosedAt[offer.id] ?? 0, offer.expiresAt)
        }
        state.active.removeAll { $0.expiresAt <= now }
    }
}
