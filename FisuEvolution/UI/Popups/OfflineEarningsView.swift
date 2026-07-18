import SwiftUI

/// "Mientras no estabas…" — offline earnings already credited on apply; this is
/// the celebration. F4 adds the "double with an ad" option.
struct OfflineEarningsView: View {
    let reward: GameState.OfflineReward
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("offline.title")
                .font(.title2.weight(.heavy))
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(Color("PaletteYellow"))
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
        .padding(24)
        .presentationDetents([.fraction(0.3)])
    }
}
