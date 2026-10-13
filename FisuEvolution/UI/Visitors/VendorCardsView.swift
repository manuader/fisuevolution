import EconomyKit
import SwiftUI

/// Las cartas del Vendedor Ambulante (PLAN-v2 E4, Anexo A): cada boost con su
/// arte, su nombre, su efecto y su duración, y el video que lo regala. Una carta
/// por visita: elegir una cierra el trato. Las tres van en una sola fila (E14
/// C15, M7b): chicas, con el botón sin medallón, para que entren en el SE.
struct VendorCardsView: View {
    let script: VisitorsConfig.Script
    let offer: VisitOffer
    @Environment(GameState.self) private var gameState

    private var cards: [VisitorsConfig.VendorCard] {
        guard case .vendor(let cards) = script.mechanic else { return [] }
        return cards.filter { offer.option(id: "card.\($0.id)") != nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.s8) {
            ForEach(cards) { card in
                GameCard(style: .normal) {
                    VStack(spacing: Tokens.s4) {
                        Group {
                            if let art = UIArt.image(card.iconKey) {
                                art.resizable().scaledToFit()
                            } else {
                                IconCanvas { MarkDisc(mark: "★", fill: Color("PaletteOrange")) }
                            }
                        }
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                        Text(verbatim: VisitCopy.text(card.nameKey))
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                        if case let .modifier(effect, magnitude, seconds) = card.reward {
                            Text(verbatim: "\(VisitCopy.effectText(effect, magnitude: magnitude)) · \(VisitCopy.durationText(seconds))")
                                .font(Tokens.caption)
                                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.6)
                        }
                        RewardedOfferButton(title: String(localized: "visit.vendor.take"),
                                            identifier: "visit.option.card.\(card.id)", placement: .visitor,
                                            gameRole: .video, gameCompact: true) {
                            gameState.chooseVisitOption("card.\(card.id)")
                        }
                        // Los tres botones reparten el ancho de su carta.
                        .environment(\.gameButtonFillsWidth, true)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
