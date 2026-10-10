import EconomyKit
import SwiftUI

/// El popup de un visitante (PLAN-v2 E4): su retrato, su pedido en el globo de
/// la 2.0 y una opción por botón. Lo que da es verde; lo que cobra, naranja —o
/// un badge apagado si no alcanza o hay corralito: nunca `.disabled`—; lo que
/// pide video, `RewardedOfferButton`, que entrega SÓLO si el video se premió.
/// Los montos son los que se cotizaron al llegar, los mismos del globo.
struct VisitorPopupView: View {
    @Environment(GameState.self) private var gameState
    private static let portraitSide: CGFloat = 112

    var body: some View {
        PanelCard {
            if let visit = gameState.stageVisit, let offer = visit.offer, let content = gameState.content,
               let script = content.visitors.script(id: offer.scriptId),
               let visitor = content.visitors.visitor(id: offer.visitorId) {
                VStack(spacing: Tokens.s12) {
                    PanelTitleBanner(verbatim: VisitCopy.name(of: visitor))
                    // El loop si existe y el pool lo deja; si no, la cara de siempre.
                    AnimatedArtView(clip: .portrait(visitor.id), role: .popup) {
                        VisitorFace(visitorId: visitor.id, side: Self.portraitSide)
                    }
                    .frame(width: Self.portraitSide, height: Self.portraitSide)
                    Text(verbatim: VisitCopy.ask(for: script, offer: offer, content: content))
                        .font(Tokens.prose)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Tokens.s12)
                        .padding(.top, BubbleGeometry.tailHeight)
                        .background(bubble)
                    VStack(spacing: Tokens.s8) {
                        ForEach(offer.options) { option in
                            optionButton(option, script: script, content: content)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.s8)
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.closeVisitorPopup() }
                .padding(10)
        }
        .padding(16)
        // Sin identifier en el contenedor: pisaría el de los botones (trampa 9a-bis).
        .presentationDetents([.fraction(0.72)])
        .fisuSheet()
    }

    /// La cola del globo apunta ARRIBA, al retrato: por eso la forma va rotada 180°.
    private var bubble: some View {
        BubbleShape(tailFraction: 0.5)
            .rotation(.degrees(180))
            .fill(Color("PaletteCream"))
            .overlay(BubbleShape(tailFraction: 0.5).rotation(.degrees(180))
                .stroke(Color("PaletteInk"), lineWidth: 2))
    }

    @ViewBuilder
    private func optionButton(_ option: VisitOption, script: VisitorsConfig.Script, content: GameContent) -> some View {
        let title = VisitCopy.optionTitle(option, script: script, content: content)
        let identifier = "visit.option.\(option.id)"
        if option.requiresVideo {
            RewardedOfferButton(title: title, identifier: identifier) {
                gameState.chooseVisitOption(option.id)
            }
        } else if option.cost > 0, !gameState.canAfford(option) {
            StateBadge(text: title, systemImage: "lock.fill", textAlignment: .center, muted: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
        } else {
            ActionPill(verbatim: title, systemImage: Self.symbol(for: option.kind),
                       tint: option.cost > 0 ? Color("PaletteOrange") : Color("PaletteGreen"),
                       identifier: identifier) {
                gameState.chooseVisitOption(option.id)
            }
        }
    }

    private static func symbol(for kind: VisitOption.Kind) -> String {
        switch kind {
        case .payBail, .payFine, .exchange: "banknote.fill"
        case .release, .sell: "hand.wave.fill"
        case .startChallenge: "hand.tap.fill"
        case .listen: "ear.fill"
        case .accept, .acceptWithVideo, .forgiveWithVideo, .card: "checkmark"
        }
    }
}
