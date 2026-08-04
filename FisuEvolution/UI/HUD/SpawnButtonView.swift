import EconomyKit
import SwiftUI

/// Spawn purchase button: shows the progressive-spawn offer (type + current cost)
/// and disables itself while coins are short. F2 adds the merge loop on top.
struct SpawnButtonView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        if let quote = gameState.spawnQuote {
            ArtButton(art: "ui_btn_buy", tint: Color("PaletteGreen")) {
                gameState.buySpawn()
            } label: {
                VStack(spacing: 2) {
                    buttonTitle(for: quote)
                    if gameState.visibleFloorIsFull {
                        Text("spawn.button.full.detail")
                            .font(.subheadline.weight(.semibold))
                    } else if !gameState.visibleFloorIsUnlocked {
                        Text("spawn.button.locked.detail")
                            .font(.subheadline.weight(.semibold))
                    } else {
                        HStack(spacing: 4) {
                            CoinIcon(size: 18)
                            Text(verbatim: CoinFormatter.string(from: quote.cost))
                                .monospacedDigit()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            // Sin saldo: NO usamos `.disabled` (el dimming del sistema bajaba el
            // texto a ~0.3 y lo volvía ilegible). El botón queda tappable —
            // `buySpawn()` falla solo si no alcanza — y comunicamos el estado con
            // texto blanco (afford) o ink (sin saldo) + una leve desaturación.
            .foregroundStyle(gameState.canAffordSpawn ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(gameState.canAffordSpawn ? 0.55 : 0), radius: 2, y: 1)
            .shadow(color: .black.opacity(gameState.canAffordSpawn ? 0.35 : 0), radius: 0.5, y: 0)
            .saturation(gameState.canAffordSpawn ? 1 : 0.7)
            .opacity(gameState.canAffordSpawn ? 1 : 0.92)
            .frame(maxWidth: 300)
            .fixedSize(horizontal: false, vertical: true)
            .scaleEffect(gameState.showSpawnHint && pulsing && !reduceMotion ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .accessibilityIdentifier("hud.spawn")
            .accessibilityHint(Text("spawn.button.hint"))
        }
    }

    @ViewBuilder
    private func buttonTitle(for quote: HireQuote) -> some View {
        Group {
            if gameState.visibleFloorIsFull {
                Text("spawn.button.full")
            } else if !gameState.visibleFloorIsUnlocked {
                Text("spawn.button.locked")
            } else {
                Text("spawn.button.title \(quote.type.displayName)")
            }
        }
        .font(.system(.headline, design: .rounded).weight(.bold))
    }
}
