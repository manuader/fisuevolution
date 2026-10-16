import EconomyKit
import Foundation

/// La oferta del momento a la vista (2.1 E15 F3, T5): lo que eligió el planificador en un momento de
/// necesidad natural y lo que la tarjeta muestra (T6). Paga exactamente `reward`, una sola vez.
///
/// `site` (`moment.<brazo>`) es el id de accesibilidad del botón del video y el lugar del embudo de
/// ofertas; el video sale del bloque `gifts` (`PLAN-v2.1.md` §3.7: sin unidades nuevas en AdMob), y el
/// ledger lo distingue por `site`.
struct MomentOffer: Identifiable, Equatable {
    /// El bloque de anuncios de todas las ofertas del momento.
    static let placement = RewardedPlacement.gifts
    /// El prefijo del `site` y del `source` de los premios.
    static let sitePrefix = "moment."

    let id = UUID()
    let armId: String
    let moment: NeedMoment
    let reward: MomentReward
    /// La `version` de la sección `moments` que la eligió (la del `exposure`).
    let configVersion: String
    /// El video está cargando o en pantalla: desde el toque hasta que el anuncio vuelve. Mientras tanto
    /// nada la rechaza; el video visto se cobra.
    var isWatching = false
    /// Un «No, gracias» que llegó con el video en curso: se aplica si el anuncio vuelve sin premio.
    var declinePending = false

    var site: String { Self.site(armId: armId) }

    static func site(armId: String) -> String { sitePrefix + armId }
}
