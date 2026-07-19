import SwiftUI

/// Spawn purchase button: shows the progressive-spawn offer (type + current cost)
/// and disables itself while coins are short. F2 adds the merge loop on top.
struct SpawnButtonView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        if let quote = gameState.spawnQuote {
            Button {
                gameState.buySpawn()
            } label: {
                VStack(spacing: 2) {
                    Text("spawn.button.title \(quote.type.displayName)")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                        Text(verbatim: CoinFormatter.string(from: quote.cost))
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PaletteGreen"))
            .foregroundStyle(Color("PaletteInk"))
            .disabled(!gameState.canAffordSpawn)
            .scaleEffect(gameState.showSpawnHint && pulsing && !reduceMotion ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .accessibilityIdentifier("hud.spawn")
            .accessibilityHint(Text("spawn.button.hint"))
        }
    }
}
