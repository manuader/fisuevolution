import SwiftUI

/// El botón de compartir un momento viral (PLAN-v2 E3): aparece cuando terminó
/// la celebración, encima de la franja de abajo, y se va solo. **Nunca es un
/// popup**: no tapa nada ni pide nada.
struct ShareMomentChip: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let moment: ShareMoment

    static let lifetime: Duration = .seconds(10)

    /// Arriba de los dos toasts de `RootView` (el de logros llega a 264 pt de
    /// la safe area con su aire), para que los tres se lean apilados.
    @MainActor static var bottomPadding: CGFloat {
        GameTabBar.barHeight + 8 + QuickHireButton.capsuleHeight + 8 + 45 + 63 + 63 + GameTabBar.bottomFloor
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: Tokens.s8) {
                ActionPill(
                    titleKey: "share.offer \(gameState.shareRewardMinutesText)",
                    systemImage: "square.and.arrow.up",
                    tint: Color("PaletteBlue"),
                    identifier: "share.offer"
                ) {
                    gameState.openShareCard()
                }
                .tutorialAnchor(.share)
                Button { gameState.dismissShareOffer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color("PaletteInk"))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(Color("PaletteCream"))
                                .overlay(Circle().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share.offer.dismiss")
                .accessibilityLabel(Text("share.skip"))
            }
            .padding(.bottom, Self.bottomPadding)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .task(id: moment.id) {
            try? await Task.sleep(for: Self.lifetime)
            // Si el tutorial lo está señalando, se queda hasta que el jugador
            // decida.
            guard !Task.isCancelled, gameState.tutorialTip?.lesson != .share else { return }
            gameState.dismissShareOffer()
        }
    }
}
