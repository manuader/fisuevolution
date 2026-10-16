import EconomyKit
import SwiftUI

/// El paso 2 de toda recompensa gratis (E14b B29, D17): centrado, «¿Lo duplicás?» con la misma
/// recompensa que se acaba de cobrar, «×2 con video» y «No, gracias». Un solo componente para todo el
/// juego; qué paga y dónde se cuenta lo dice `RewardDouble`.
///
/// El botón del video lleva el `site` como id de accesibilidad (`double.visit.ministro_subsidio`,
/// `double.offline`…): es el lugar del embudo de ofertas de E15, estable por fuente.
///
/// Con el ×N de un segmento (2.1 E15 F2) el botón dice su número («×2,5 con video») y la tarjeta muestra
/// la plata extra exacta que paga el video (`extraCoins`, G4). Con ×2 es el pop-up de la 2.0, igual.
struct RewardDoubleOffer: View {
    let double: RewardDouble
    @Environment(GameState.self) private var gameState

    var body: some View {
        PopupContainer(LocalizedStringKey(Self.titleKey(multiplier: double.multiplier)),
                       ribbonTint: Color("PaletteGreen"), onClose: decline) {
            RewardIllustration(kind: Self.kind(coins: double.shownCoins, rewards: double.shownRewards), size: 110)
            Text(verbatim: Self.label(coins: double.extraCoins, rewards: double.shownRewards))
                .font(Tokens.display)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("reward.double.amount")
                .accessibilityValue(Text(verbatim: double.site))
        } actions: {
            RewardedOfferButton(
                title: Self.videoTitle(multiplier: double.multiplier),
                identifier: double.site,
                placement: double.placement,
                gameRole: .video,
                // El «video en curso» vive en el estado, no en la vista: AdMob presenta encima de la hoja y
                // SwiftUI puede desmontarla, pero el video visto se cobra igual.
                onWatchStarted: { gameState.beginRewardDoubleWatch(id: double.id) },
                onWatchEnded: { _ in gameState.endRewardDoubleWatch(id: double.id) }
            ) {
                gameState.claimRewardDouble(id: double.id)
            }
            GameButton("reward.double.decline", role: .neutral, medallion: .none,
                       identifier: "reward.double.decline", action: decline)
        }
    }

    /// «No, gracias» y la X no hacen nada con el video cargando o en pantalla.
    private func decline() {
        guard gameState.rewardDouble?.isWatching != true else { return }
        gameState.declineRewardDouble(id: double.id)
    }

    /// El título: «¿Lo duplicás?» con ×2; con otro ×N, uno que no promete el doble.
    static func titleKey(multiplier: Double) -> String {
        isBase(multiplier) ? "reward.double.title" : "reward.double.title.boosted"
    }

    /// El botón del video: «×2 con video» con la base; con otro ×N, «×2,5 con video».
    static func videoTitle(multiplier: Double) -> String {
        isBase(multiplier)
            ? String(localized: "reward.double.video")
            : String(localized: "reward.double.video.boosted \(multiplierText(multiplier))")
    }

    /// El ×N como se lee en el idioma del jugador: «2,5», «2.25».
    static func multiplierText(_ multiplier: Double) -> String {
        multiplier.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func isBase(_ multiplier: Double) -> Bool {
        multiplier == SegmentLevers.Levers.baseVideoRewardMultiplier
    }

    /// La ilustración: la plata si la hay; si no, el primer premio con dibujo.
    static func kind(coins: Double, rewards: [RewardSpec]) -> RewardKind {
        if coins > 0 { return .coins }
        return rewards.lazy.compactMap { RewardKind($0) }.first ?? .gift
    }

    /// Lo que paga el video: «+1,2 M» (con ×2, lo mismo que el paso 1), o los premios por nombre.
    static func label(coins: Double, rewards: [RewardSpec]) -> String {
        var parts: [String] = []
        if coins > 0 { parts.append("+" + CoinFormatter.string(from: coins)) }
        parts += rewards.map(RewardCopy.title)
        return parts.joined(separator: " + ")
    }
}

/// La capa del paso 2: un pop-up centrado sobre lo que haya en `host` (el tablero, la hoja de la Ruleta o
/// la del Menú). Es un `ViewModifier` porque `RootView.body` está al límite del type-checker.
struct RewardDoubleLayer: ViewModifier {
    let host: RewardDouble.Host
    /// Re-publica lo que tapa el tablero cuando el pop-up sale o se va (sólo el del tablero).
    var syncCover: () -> Void = {}
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content
            .gamePopup(item: binding) { double in
                RewardDoubleOffer(double: double)
            }
            .onChange(of: gameState.rewardDouble?.id) { syncCover() }
            // Sin `onDisappear`: AdMob presenta a pantalla completa encima de la hoja y SwiftUI puede darla por
            // desaparecida con el video en curso. El rechazo por cerrar la hoja sale de su cierre real
            // (`closeWheel`, `menuDidClose`), y aun así espera al video (`declineRewardDouble`).
    }

    private var binding: Binding<RewardDouble?> {
        Binding(
            get: { gameState.rewardDouble.flatMap { $0.host == host ? $0 : nil } },
            set: { value in
                // Con el video en curso, `declineRewardDouble` sólo lo anota: no borra lo que se está mirando.
                if value == nil, let id = gameState.rewardDouble?.id { gameState.declineRewardDouble(id: id) }
            }
        )
    }
}
