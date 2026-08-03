import SwiftUI

/// Per-type passive unlock (bible §2.3 regla 3): buying it makes every instance
/// of that type on the board earn on its own.
struct PassiveUnlockView: View {
    @Environment(GameState.self) private var gameState
    let prompt: GameState.PassivePrompt

    var body: some View {
        GamePanel(art: "panel_dialog", insets: EdgeInsets(top: 74, leading: 24, bottom: 26, trailing: 24)) {
            VStack(spacing: 16) {
                Text("passive.title \(prompt.type.displayName)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color("PaletteInk"))
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
                            CoinIcon(size: 18)
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

                if prompt.canDismiss {
                    Divider()
                    Button(role: .destructive) {
                        gameState.dismissCharacter(atCell: prompt.cellIndex)
                    } label: {
                        Label {
                            Text(verbatim: "Dejar de contratar")
                        } icon: {
                            Image(systemName: "person.fill.xmark")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("PalettePink"))
                }
            }
        }
        .padding(16)
        .presentationDetents([.fraction(0.54)])
    }
}
