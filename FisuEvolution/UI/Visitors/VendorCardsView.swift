import EconomyKit
import SwiftUI

/// Las cartas del Vendedor Ambulante (PLAN-v2 E4, Anexo A): cada boost con su
/// arte, su nombre, su efecto y su duración, y el video que lo regala. Una carta
/// por visita: elegir una cierra el trato.
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
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundStyle(Color("PaletteOrange"))
                            }
                        }
                        .frame(width: 44, height: 44)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        RewardedOfferButton(title: String(localized: "visit.vendor.take"),
                                            identifier: "visit.option.card.\(card.id)") {
                            gameState.chooseVisitOption("card.\(card.id)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
