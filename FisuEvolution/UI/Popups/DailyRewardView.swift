import SwiftUI

/// Popup del daily reward (ciclo de 7 días).
struct DailyRewardView: View {
    @Environment(GameState.self) private var gameState
    let claim: DailyRewardManager.Claim

    var body: some View {
        VStack(spacing: 16) {
            Text("daily.title")
                .font(.title2.weight(.heavy))
            Text(LocalizedStringKey(claim.day.titleKey))
                .font(.headline)

            if let special = claim.specialGranted,
               let config = gameState.content?.specials.specials.first(where: { $0.id == special }) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color("PaletteYellow"))
                Text(LocalizedStringKey(config.displayNameKey))
                    .font(.title3.weight(.bold))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(Color("PaletteYellow"))
                    Text(verbatim: "+\(CoinFormatter.string(from: claim.coinsGranted))")
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                }
            }

            Button {
                gameState.dismissDailyClaim()
            } label: {
                Text("offline.collect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PaletteGreen"))
        }
        .padding(24)
        .presentationDetents([.fraction(0.45)])
    }
}
