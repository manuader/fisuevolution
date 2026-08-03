import SwiftUI

/// Reincarnation confirmation (bible §5): reset the run, keep the soul.
struct PrestigeView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GamePanel(art: "panel_prestige", insets: EdgeInsets(top: 76, leading: 22, bottom: 24, trailing: 22)) {
            VStack(spacing: 18) {
                Text("prestige.title")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                Text("prestige.body \(String(gameState.prestigeSoulPointsGained))")
                    .font(.body)
                    .multilineTextAlignment(.center)

                Button {
                    gameState.confirmPrestige()
                    dismiss()
                } label: {
                    Text("prestige.confirm")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PalettePink"))
                .accessibilityIdentifier("prestige.confirm")

                Button {
                    dismiss()
                } label: {
                    Text("prestige.cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.46)])
    }
}
