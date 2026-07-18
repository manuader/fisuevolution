import SwiftUI

/// Per-type passive unlock (bible §2.3 regla 3): buying it makes every instance
/// of that type on the board earn on its own.
struct PassiveUnlockView: View {
    @Environment(GameState.self) private var gameState
    let prompt: GameState.PassivePrompt

    var body: some View {
        VStack(spacing: 16) {
            Text("passive.title \(prompt.type.displayName)")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            Text("passive.explainer \(String(prompt.instanceCount)) \(CoinFormatter.string(from: prompt.type.passiveYieldPerInstance))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if prompt.isUnlocked {
                Label("passive.unlocked", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color("PaletteGreen"))
            } else {
                Button {
                    gameState.unlockPassive(typeId: prompt.type.id)
                } label: {
                    HStack(spacing: 6) {
                        Text("passive.unlock")
                        Image(systemName: "dollarsign.circle.fill")
                        Text(verbatim: CoinFormatter.string(from: prompt.type.passiveUnlockCost))
                            .monospacedDigit()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteGreen"))
                .disabled(!prompt.canAfford)

                if !prompt.canAfford {
                    Text("passive.insufficient")
                        .font(.footnote)
                        .foregroundStyle(Color("PalettePink"))
                }
            }
        }
        .padding(24)
        .presentationDetents([.fraction(0.35)])
    }
}
