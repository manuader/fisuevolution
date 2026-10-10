import EconomyKit
import SwiftUI

/// La pantalla previa de la pausa publicitaria (PLAN-v2 E7; la política de
/// AdMob para el intersticial bonificado): dice qué se gana, cuenta 5 s y deja
/// rechazar desde el primer cuadro.
///
/// ⚠️ No es una hoja: el anuncio que viene después lo presenta el SDK, y una
/// hoja cerrándose debajo pelearía con él por la presentación.
struct RewardedInterstitialIntroView: View {
    let offer: AdBreakOffer
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining: Int

    init(offer: AdBreakOffer) {
        self.offer = offer
        _remaining = State(initialValue: offer.countdownSeconds)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            PanelCard {
                VStack(spacing: Tokens.s12) {
                    PanelTitleBanner(titleKey: "adbreak.title")
                    Text("adbreak.pitch")
                        .font(Tokens.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("PaletteInk"))
                    prizeCard
                    countdown
                    HStack(spacing: Tokens.s8) {
                        ActionPill(titleKey: "adbreak.decline", systemImage: "xmark",
                                   tint: Color("PaletteBlue"), identifier: "adbreak.decline") {
                            gameState.adBreakDeclined()
                        }
                        ActionPill(titleKey: "adbreak.watch", systemImage: "play.fill",
                                   identifier: "adbreak.watch") {
                            Task { await gameState.adBreakAccepted() }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: PlayColumn.tutorialCardMaxWidth)
            .padding(Tokens.s16)
        }
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("adbreak.intro")
                .accessibilityValue(Text(verbatim: String(remaining)))
        )
        .task(id: offer.id) {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
            }
            await gameState.adBreakAccepted()
        }
    }

    private var prizeCard: some View {
        GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s12) {
                Image(systemName: RewardCopy.symbol(offer.prize))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color("PaletteInk"))
                Text(verbatim: RewardCopy.title(offer.prize))
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private var countdown: some View {
        Text(verbatim: String(remaining))
            .font(.system(size: 34, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color("PaletteInk"))
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
            .animation(reduceMotion ? nil : .default, value: remaining)
            .frame(width: 64, height: 64)
            .background(Circle().fill(Color("PaletteCream")).overlay(Circle().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 3)))
            .accessibilityLabel(Text("adbreak.countdown.ax \(String(remaining))"))
    }
}
