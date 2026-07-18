import SwiftUI

/// Reincarnation confirmation (bible §5): reset the run, keep the soul.
struct PrestigeView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("prestige.title")
                .font(.title2.weight(.heavy))
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
        .padding(24)
        .presentationDetents([.fraction(0.35)])
    }
}
