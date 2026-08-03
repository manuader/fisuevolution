import SwiftUI

/// Popup del daily reward (ciclo de 7 días).
struct DailyRewardView: View {
    @Environment(GameState.self) private var gameState
    let claim: DailyRewardManager.Claim

    var body: some View {
        GamePanel(art: "panel_reward", insets: EdgeInsets(top: 84, leading: 22, bottom: 24, trailing: 22)) {
            VStack(spacing: 16) {
                Text("daily.title")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
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
                        CoinIcon(size: 34)
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
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.dismissDailyClaim() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.52)])
    }
}
