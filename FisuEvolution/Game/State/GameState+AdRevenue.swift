import EconomyKit
import Foundation

/// Lo que pagó cada anuncio, anotado en el save (E15 F0: medir lo que vale cada jugador).
///
/// Medición pura, y ése es todo el contrato: anota en `meta.adRevenue` y marca el save sucio por el
/// mismo camino que el resto de `meta`. **No acredita nada ni toca cooldowns**: un video cerrado a la
/// mitad se anota igual (la impresión se pagó) y sigue sin dar premio, porque el premio lo decide el
/// `true` de `showRewarded`, que esto no mira.
extension GameState {
    func recordImpression(_ impression: AdImpression) {
        guard player != nil else { return }
        player?.meta.adRevenue.record(impression)
        scheduleSave()
    }
}
