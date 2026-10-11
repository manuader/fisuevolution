import SwiftUI

/// La tarjeta que sale al lado de "Premios" cuando lo que se tocó ofrece un
/// video: dice qué da ANTES del anuncio (política de AdMob: el video con premio
/// es opt-in y el premio se conoce de antemano).
///
/// El gate es de quien la abre (`sideRailTapped`): la tarjeta no apaga su botón
/// ni prende `uiCoversBoard`. El cerrojo corta el aviso repetido del anuncio
/// antes de pagar.
struct SideRailOfferCard: View {
    let kind: SideRailKind
    let close: () -> Void
    @Environment(GameState.self) private var gameState
    @State private var latch = PurchaseLatch()

    var body: some View {
        GameCard(style: .normal) {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                HStack(alignment: .firstTextBaseline) {
                    title
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                    Spacer(minLength: Tokens.s8)
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color("PaletteInk").opacity(0.6))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("siderail.offer.close")
                    .accessibilityLabel(Text("siderail.offer.close.ax"))
                }
                Text(verbatim: pitch)
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                video
            }
            .frame(width: 220, alignment: .leading)
        }
    }

    @ViewBuilder private var title: some View {
        switch kind {
        case .boost: Text("ads.reward.merge_all")
        default: Text("siderail.rain.title")
        }
    }

    /// Un botón por unidad, escrito entero: el contrato del mapa (T7) lee la
    /// unidad en la fuente.
    @ViewBuilder private var video: some View {
        switch kind {
        case .boost:
            RewardedOfferButton(title: String(localized: "siderail.boost.video"),
                                identifier: "siderail.offer.video", placement: .boost) {
                gameState.railVideoWatched(.boost, latch: &latch)
                close()
            }
        default:
            RewardedOfferButton(title: String(localized: "siderail.rain.video"),
                                identifier: "siderail.offer.video", placement: .treasure) {
                gameState.railVideoWatched(.packages, latch: &latch)
                close()
            }
        }
    }

    private var pitch: String {
        switch kind {
        case .boost:
            String(localized: "siderail.boost.pitch \(String(gameState.sideRail.mergeAllPairs))")
        default:
            String(localized: "siderail.rain.pitch \(RewardCopy.title(gameState.content?.rewardedAds.effectiveSideRail.packageRain ?? RewardedAdsConfig.SideRail.default.packageRain))")
        }
    }
}
