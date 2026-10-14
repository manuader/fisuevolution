import SwiftUI

/// Las medidas de la imagen principal de un popup (E14b B9, D9), puras para
/// poder pinearlas.
enum PopupHeroMetrics {
    /// La imagen principal: grande, vistosa y centrada.
    static let side: CGFloat = 132
    /// La pila de «todos los premios»: bastante más grande que una fila (D9).
    static let pileSide: CGFloat = 140
    /// El aire de los rayos alrededor de la imagen.
    static let raysFactor: CGFloat = 1.3

    static func frameSide(for side: CGFloat) -> CGFloat { (side * raysFactor).rounded() }
}

/// La imagen principal de un popup: un arte de `ui.atlas` grande, centrado y
/// con los rayos detrás, como la ilustración de un premio. Si el arte no está
/// integrado, cae al dibujo del premio de respaldo y no deja el hueco.
struct PopupHero: View {
    let artKey: String
    var fallback: RewardKind = .mystery
    var side: CGFloat = PopupHeroMetrics.side
    var spinsRays = true

    var body: some View {
        ZStack {
            RewardRays(spins: spinsRays)
            art
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
        .frame(width: PopupHeroMetrics.frameSide(for: side), height: PopupHeroMetrics.frameSide(for: side))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var art: some View {
        if let image = UIArt.image(artKey) {
            image.resizable().scaledToFit()
        } else {
            RewardArt(kind: fallback)
        }
    }
}

/// «Todos los premios juntos» (los tesoros con el mate): la imagen que va
/// arriba de la lista de posibilidades de toda pantalla que da recompensa.
struct PrizePileHero: View {
    var side: CGFloat = PopupHeroMetrics.pileSide

    var body: some View {
        RewardIllustration(kind: .mystery, size: side)
    }
}

/// Qué imagen principal lleva cada oferta de 24 h (`OfferSheet`): la de lo que
/// trae el pack. Una oferta nueva sin imagen propia usa la de su ícono.
enum OfferHeroArt {
    static func key(forOfferId id: String, iconKey: String) -> String {
        switch id {
        case "mudanza": "rw_pack_mudanza"
        case "bienvenida": "rw_pack_bienvenida"
        case "renacer": "rw_pack_renacer"
        default: iconKey
        }
    }
}
