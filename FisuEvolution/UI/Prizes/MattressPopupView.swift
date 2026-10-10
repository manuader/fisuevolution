import EconomyKit
import SwiftUI

/// El Colchón (PLAN-v2 E5): "tus empleados escondieron plata en el colchón".
/// Se abre sólo con video, y lo que puede tocar está a la vista antes de
/// mirarlo. Después: lo que salió y "otro colchón" con un segundo video.
struct MattressPopupView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let outcome = gameState.mattressPopup?.outcome
        PanelCard {
            VStack(spacing: Tokens.s12) {
                PanelTitleBanner(titleKey: "mattress.title")
                if let outcome {
                    result(outcome)
                    if outcome.extraOpensLeft > 0 {
                        RewardedOfferButton(title: String(localized: "mattress.extra"), identifier: "mattress.extra",
                                            placement: .treasure) { gameState.extraMattressVideoWatched() }
                    }
                    ActionPill(titleKey: "mattress.collect", systemImage: "checkmark",
                               identifier: "mattress.collect") { dismiss() }
                } else {
                    Text("mattress.pitch")
                        .font(Tokens.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("PaletteInk"))
                    GameIcon(artKey: "pickup_mattress", size: 88) { MattressGlyph() }
                    RewardedOfferButton(title: String(localized: "mattress.open"), identifier: "mattress.open",
                                        placement: .treasure) { gameState.mattressVideoWatched() }
                    OddsDisclosureView(titleKey: "mattress.odds.title", rows: oddsRows, identifier: "mattress.odds")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(outcome == nil ? 0.66 : 0.5)])
        .fisuSheet()
    }

    private func result(_ outcome: MattressOutcome) -> some View {
        let text = outcome.coins > 0
            ? "+\(CoinFormatter.string(from: outcome.coins))"
            : outcome.rewards.map(RewardCopy.title).joined(separator: " + ")
        return GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s8) {
                Image(systemName: outcome.rewards.first.map(RewardCopy.symbol) ?? "gift.fill")
                    .font(.system(size: 28, weight: .heavy))
                Text(verbatim: text)
                    .font(Tokens.title)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color("PaletteInk"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mattress.result")
        .accessibilityValue(Text(verbatim: outcome.prizeId))
    }

    private var oddsRows: [OddsDisclosureView.Row] {
        guard let treasures = gameState.content?.treasures else { return [] }
        return zip(treasures.prizes, treasures.odds).map { prize, odds in
            OddsDisclosureView.Row(
                id: prize.id,
                title: prize.rewards.map(RewardCopy.title).joined(separator: " + "),
                symbol: prize.rewards.first.map(RewardCopy.symbol) ?? "gift.fill",
                probability: odds.probability
            )
        }
    }
}
