import EconomyKit
import SwiftUI

/// La tarjeta del momento (2.1 E15 F3 T6): el jugador está en un momento de necesidad natural y hay un
/// video cargado; se le ofrece, centrado y a la vista, algo concreto a cambio del video, con «No, gracias».
/// Mismo ritmo que el paso 2 del ×2 (`RewardDoubleOffer`): título, ilustración, el premio exacto y los dos
/// botones.
///
/// El botón del video es el de la casa (`RewardedOfferButton`, lugar `moment.<brazo>`) con el reporter del
/// momento en el entorno: el embudo lo cuenta solo y lleva el `ctx` del momento. El «video en curso» vive en
/// el estado (`beginMomentWatch`/`endMomentWatch`), no en la vista: AdMob presenta encima y SwiftUI puede
/// desmontarla, pero el video visto se cobra igual.
struct MomentOfferCard: View {
    let offer: MomentOffer
    @Environment(GameState.self) private var gameState

    var body: some View {
        PopupContainer("moment.card.title", ribbonTint: Color("PaletteGreen"), onClose: decline) {
            RewardIllustration(kind: Self.kind(for: offer.reward), size: 110)
            Text(verbatim: Self.amountLabel(reward: offer.reward, coins: gameState.momentOfferCoins))
                .font(Tokens.display)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("moment.offer.amount")
                .accessibilityValue(Text(verbatim: offer.site))
            Text(LocalizedStringKey(Self.bodyKey(for: offer.moment)))
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("moment.offer.body")
        } actions: {
            RewardedOfferButton(
                title: String(localized: "moment.card.video"),
                identifier: offer.site,
                placement: .gifts,
                gameRole: .video,
                onWatchStarted: { gameState.beginMomentWatch(id: offer.id) },
                onWatchEnded: { _ in gameState.endMomentWatch(id: offer.id) }
            ) {
                gameState.claimMomentOffer(id: offer.id)
            }
            .environment(\.offerFunnelReporter, gameState.momentOfferFunnelReporter)
            GameButton("moment.card.decline", role: .neutral, medallion: .none,
                       identifier: "moment.offer.decline", action: decline)
        }
    }

    /// «No, gracias» y la X no hacen nada con el video cargando o en pantalla.
    private func decline() {
        guard offer.isWatching == false else { return }
        gameState.declineMomentOffer(id: offer.id)
    }

    /// La clave del texto del momento.
    static func bodyKey(for moment: NeedMoment) -> String {
        "moment.card.body.\(moment.rawValue)"
    }

    /// La ilustración: la plata si es plata; «Fusionar todo», la evolución.
    static func kind(for reward: MomentReward) -> RewardKind {
        reward.coinsSeconds == nil ? .evolve : .coins
    }

    /// El premio exacto: «+1,2 M» (lo que paga `grant` ahora) o «Fusionar todo».
    static func amountLabel(reward: MomentReward, coins: Double?) -> String {
        if let coins { return "+" + CoinFormatter.string(from: coins) }
        return String(localized: "moment.card.reward.merge_all")
    }
}

/// La capa de la tarjeta: un pop-up centrado sobre el tablero. Es un `ViewModifier` porque
/// `RootView.body` está al límite del type-checker.
struct MomentOfferLayer: ViewModifier {
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content.gamePopup(item: binding) { offer in
            MomentOfferCard(offer: offer)
        }
    }

    private var binding: Binding<MomentOffer?> {
        Binding(
            get: { gameState.momentOffer },
            set: { value in
                // Con el video en curso, `declineMomentOffer` sólo lo anota: no borra lo que se está mirando.
                if value == nil, let id = gameState.momentOffer?.id { gameState.declineMomentOffer(id: id) }
            }
        )
    }
}
