import Foundation

/// Los topes de los eventos que llevan a una tienda (C25): que no se sientan spam.
public struct ShopEventPolicy: Codable, Sendable, Equatable {
    /// Cuántos puede haber por sesión.
    public let maxPerSession: Int
    /// Juego activo mínimo entre dos de ellos.
    public let minSeparationSeconds: Double
    /// Si compró con plata real hace menos que esto, no sale el de la Tienda.
    public let purchaseQuietSeconds: Double
    /// Nunca en el arranque: juego activo mínimo de la sesión.
    public let minSessionSeconds: Double
    /// Nunca en la primera sesión: juego activo mínimo de la partida.
    public let minPlayedSeconds: Double

    public static let standard = ShopEventPolicy(
        maxPerSession: 1, minSeparationSeconds: 4 * 3600, purchaseQuietSeconds: 24 * 3600,
        minSessionSeconds: 180, minPlayedSeconds: 1800
    )

    public init(
        maxPerSession: Int, minSeparationSeconds: Double, purchaseQuietSeconds: Double,
        minSessionSeconds: Double, minPlayedSeconds: Double
    ) {
        self.maxPerSession = maxPerSession
        self.minSeparationSeconds = minSeparationSeconds
        self.purchaseQuietSeconds = purchaseQuietSeconds
        self.minSessionSeconds = minSessionSeconds
        self.minPlayedSeconds = minPlayedSeconds
    }

    /// Dónde está la sesión: el juego activo que lleva y los eventos de compra que ya salieron.
    public struct Session: Sendable, Equatable {
        public let activeSeconds: Double
        public let shopEventsSoFar: Int

        public init(activeSeconds: Double, shopEventsSoFar: Int) {
            self.activeSeconds = activeSeconds
            self.shopEventsSoFar = shopEventsSoFar
        }
    }

    /// Si `event` puede salir ahora. Lo que no es de compra siempre puede.
    public func allows(_ event: EventCatalog.Event, state: EventsState, session: Session, now: TimeInterval) -> Bool {
        guard let offer = event.shopOffer else { return true }
        guard session.shopEventsSoFar < maxPerSession,
              session.activeSeconds >= minSessionSeconds,
              state.clock >= minPlayedSeconds
        else { return false }
        if let last = state.lastShopEventAt, state.clock - last < minSeparationSeconds { return false }
        if offer.destination == .store, let bought = state.lastPurchaseAt, now - bought < purchaseQuietSeconds {
            return false
        }
        return true
    }
}
