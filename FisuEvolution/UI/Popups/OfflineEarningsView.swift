import SwiftUI

/// "Mientras no estabas…" — offline earnings already credited on apply; this is
/// the celebration. F4 adds the "double with an ad" option.
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GamePanel(art: "panel_reward", insets: EdgeInsets(top: 82, leading: 22, bottom: 24, trailing: 22)) {
            VStack(spacing: 18) {
                Text("offline.title")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                HStack(spacing: 8) {
                    CoinIcon(size: 34)
                    Text(verbatim: "+\(CoinFormatter.string(from: reward.amount))")
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                }
                Button {
                    dismiss()
                } label: {
                    Text("offline.collect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteYellow"))
                .foregroundStyle(Color("PaletteInk"))
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.42)])
    }
}
