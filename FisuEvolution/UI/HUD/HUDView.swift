import SwiftUI

/// Coin counter overlay. Observes `GameState`; F1 swaps the raw number for
/// `CoinFormatter` output and adds the spawn button.
struct HUDView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(Color("PaletteYellow"))
            Text(verbatim: gameState.coins.formatted(.number.precision(.fractionLength(0))))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("hud.coins")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color("PaletteCream"), in: .capsule)
        .overlay(Capsule().stroke(Color("PaletteInk").opacity(0.3), lineWidth: 1.5))
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("hud.coins.label"))
        .accessibilityValue(Text(verbatim: gameState.coins.formatted(.number.precision(.fractionLength(0)))))
    }
}
