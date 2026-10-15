import EconomyKit
import Foundation

/// Cómo convierte cada oferta con video, anotado en el save (E15 C3). Medición pura, como
/// `recordImpression`: no acredita nada, no toca cooldowns y ningún cálculo de economía lo lee.
extension GameState {
    func recordOfferStage(_ stage: OfferStage, site: String) {
        guard player != nil else { return }
        player?.meta.offerFunnel.record(stage, site: site)
        scheduleSave()
        telemetryOffer(stage, site: site)
    }

    /// Lo que se pone en el entorno para que todo `RewardedOfferButton` —el paso 2 de B29 incluido—
    /// anote su embudo sin que ningún pop-up se entere.
    var offerFunnelReporter: OfferFunnelReporter {
        OfferFunnelReporter { [weak self] site, stage in self?.recordOfferStage(stage, site: site) }
    }
}
