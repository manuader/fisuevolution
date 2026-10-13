import EconomyKit
import SwiftUI

/// En qué momento está el colchón. El premio se acredita al llegar el resultado
/// (`opening`); el clip de apertura sólo demora mostrarlo.
enum MattressStage: Equatable {
    case waiting, opening, revealed

    init(hasOutcome: Bool, revealed: Bool) {
        self = switch (hasOutcome, revealed) {
        case (false, _): .waiting
        case (true, false): .opening
        case (true, true): .revealed
        }
    }
}

/// El Colchón (PLAN-v2 E5): "tus empleados escondieron plata en el colchón".
/// Se abre sólo con video, y lo que puede tocar está a la vista antes de
/// mirarlo. Después: lo que salió y "otro colchón" con un segundo video.
/// Vive en el `PopupContainer` de la casa (E14 C15); sus tres momentos los
/// rediseña T17.
struct MattressPopupView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void
    /// Un video del colchón está en curso: el popup no se cierra bajo el anuncio.
    @State private var watching = false
    /// El clip de apertura terminó (o la política lo dejó quieto): ya se ve lo que salió.
    @State private var revealed = false

    private func close() {
        if !watching { onClose() }
    }

    var body: some View {
        let outcome = gameState.mattressPopup?.outcome
        let stage = MattressStage(hasOutcome: outcome != nil, revealed: revealed)
        PopupContainer("mattress.title", ribbonTint: Color("PaletteOrange"), onClose: close) {
            if stage == .opening {
                AnimatedArtView(clip: .object("colchon_abre"), role: .popup, playback: .once { revealed = true }) {
                    GameIcon(artKey: "pickup_mattress", size: 160) { MattressGlyph() }
                }
            } else if let outcome {
                result(outcome)
            } else if gameState.mattressPopup?.extraOnly == true {
                AnimatedArtView(clip: .object("colchon_espera"), role: .popup) {
                    GameIcon(artKey: "pickup_mattress", size: 160) { MattressGlyph() }
                }
            } else {
                Text("mattress.pitch")
                    .font(Tokens.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk"))
                AnimatedArtView(clip: .object("colchon_espera"), role: .popup) {
                    GameIcon(artKey: "pickup_mattress", size: 160) { MattressGlyph() }
                }
                OddsDisclosureView(titleKey: "mattress.odds.title", rows: oddsRows, identifier: "mattress.odds")
            }
        } actions: {
            if stage != .opening {
                if let outcome {
                    if outcome.extraOpensLeft > 0 {
                        RewardedOfferButton(title: String(localized: "mattress.extra"), identifier: "mattress.extra",
                                            placement: .treasure, isBusy: $watching, gameRole: .video) {
                            gameState.extraMattressVideoWatched()
                        }
                    }
                    GameButton("mattress.collect", role: .free, identifier: "mattress.collect", action: close)
                } else if gameState.mattressPopup?.extraOnly == true {
                    RewardedOfferButton(title: String(localized: "mattress.extra"), identifier: "mattress.extra",
                                        placement: .treasure, isBusy: $watching, gameRole: .video) {
                        gameState.extraMattressVideoWatched()
                    }
                } else {
                    RewardedOfferButton(title: String(localized: "mattress.open"), identifier: "mattress.open",
                                        placement: .treasure, isBusy: $watching, gameRole: .video) {
                        gameState.mattressVideoWatched()
                    }
                }
            }
        }
    }

    private func result(_ outcome: MattressOutcome) -> some View {
        let text = outcome.coins > 0
            ? "+\(CoinFormatter.string(from: outcome.coins))"
            : outcome.rewards.map(RewardCopy.title).joined(separator: " + ")
        return VStack(spacing: Tokens.s8) {
            RewardIllustration(kind: .mattressTreasure, size: 96)
            Text(verbatim: text)
                .font(Tokens.display)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
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
