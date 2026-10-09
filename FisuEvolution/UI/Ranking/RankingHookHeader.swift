import SwiftUI

/// El gancho de arriba de la pestaña: contra quién corre la partida en curso, y el atajo a la Tienda.
struct RankingHookHeader: View {
    let hook: RankingBoardModel.Hook
    let onStore: () -> Void

    private var showsStore: Bool {
        switch hook {
        case .chase, .last, .first: true
        case .none, .legacy, .unregistered: false
        }
    }

    var body: some View {
        if let text = RankingCopy.hook(hook) {
            GameCard(style: .highlighted(Color("PaletteOrange"))) {
                VStack(spacing: Tokens.s8) {
                    Text(verbatim: text)
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("ranking.hook")
                    if showsStore {
                        ActionPill(
                            titleKey: "ranking.hook.store", systemImage: "cart.fill",
                            identifier: "ranking.hook.store", action: onStore)
                    }
                }
            }
        }
    }
}
