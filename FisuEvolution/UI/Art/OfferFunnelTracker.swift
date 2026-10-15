import EconomyKit
import SwiftUI

/// Qué etapas del embudo (E15 C3) cuenta UN botón de video, a partir de lo que le pasa. Valor puro:
/// `RewardedOfferButton` le pasa las transiciones y anota lo que devuelve.
///
/// - `shown` una vez por aparición: ni por cada sondeo ni por cada vuelta del video siguiente.
/// - `accepted` una vez por toque efectivo: los toques con un video en curso no cuentan.
/// - `completed` y `unfilled` cuentan siempre: llegan cuando el anuncio vuelve, y para entonces el
///   botón suele haberse ido de la pantalla (y con él su estado).
/// - `dismissed` al irse, sólo si se mostró y nadie lo aceptó. Con un video en curso irse no cuenta
///   ni cierra la aparición: AdMob presenta encima de la hoja y SwiftUI puede darla por desaparecida.
///
/// Límites al leer los números:
/// - `accepted / shown` puede pasar de 1: cada reintento (después de un `unfilled` o de cerrar el
///   video a la mitad) es otro `accepted` dentro de la misma aparición.
/// - En Regalos cuentan `shown` también las filas fuera de pantalla: la lista es un `VStack` (no
///   `LazyVStack`) que arma todos sus botones al abrir, y el sondeo los da por mostrados aunque el
///   jugador no haya bajado hasta ellos.
/// - Un toque que choca con otro anuncio en curso (`.busy`) cuenta `accepted` y termina como
///   abandono, sin `completed` ni `unfilled`.
/// - El tracker vive en un `@State` del botón: si SwiftUI desmonta el paso 2 de B29 mientras AdMob
///   presenta, el botón que vuelve arranca de cero y puede contar otro `shown` de la misma oferta.
struct OfferFunnelTracker: Equatable {
    enum Transition: Equatable {
        /// El sondeo encontró el video listo: el botón ofrece.
        case appearedReady
        /// El toque arrancó un video (`RewardedOffer.tap` devolvió `true`).
        case tapped
        /// El video pagó.
        case earned
        /// Tocó y no hubo video.
        case noInventory
        /// El video volvió sin premio (lo cerró a la mitad) o el toque chocó con otro anuncio en curso.
        case endedWithoutReward
        /// El botón se fue de la pantalla.
        case disappeared
    }

    private var shown = false
    private var accepted = false
    private var inFlight = false

    mutating func handle(_ transition: Transition) -> [OfferStage] {
        switch transition {
        case .appearedReady:
            guard !shown else { return [] }
            shown = true
            return [.shown]
        case .tapped:
            guard !inFlight else { return [] }
            inFlight = true
            accepted = true
            return [.accepted]
        case .earned:
            inFlight = false
            return [.completed]
        case .noInventory:
            inFlight = false
            return [.unfilled]
        case .endedWithoutReward:
            // El abandono no se cuenta aparte: es `accepted − completed − unfilled`.
            inFlight = false
            return []
        case .disappeared:
            guard !inFlight else { return [] }
            let dismissed = shown && !accepted
            shown = false
            accepted = false
            return dismissed ? [.dismissed] : []
        }
    }
}

/// A dónde van las etapas del embudo: `(site, etapa)`, con el id de accesibilidad del botón como
/// `site`. Por defecto no hace nada, así los previews y los tests de vistas no cambian; el juego lo
/// pone en el entorno una sola vez (`GameState.offerFunnelReporter`).
struct OfferFunnelReporter: Sendable {
    let report: @MainActor @Sendable (_ site: String, _ stage: OfferStage) -> Void

    static let none = OfferFunnelReporter { _, _ in }
}

extension EnvironmentValues {
    @Entry var offerFunnelReporter: OfferFunnelReporter = .none
}
