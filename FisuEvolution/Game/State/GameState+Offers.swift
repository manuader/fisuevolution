import EconomyKit
import Foundation

/// Las ofertas de 24 h en la partida (PLAN-v2 E6): el cobro.
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
            scheduleSave()
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
}
