import SwiftUI

/// Rewarded-ads del bible §4.4: 4 recompensas opt-in a cambio de un video.
/// En dev el "video" es el stub de 2 s; F5.5 enchufa AdMob detrás del mismo botón.
struct BonusView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    let adsProvider: any AdsProvider
    @State private var watchingRewardId: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(gameState.content?.rewardedAds.rewards ?? []) { reward in
                    HStack {
                        Text(LocalizedStringKey(reward.titleKey))
                            .font(.headline)
                        Spacer()
                        Button {
                            watch(reward)
                        } label: {
                            if watchingRewardId == reward.id {
                                ProgressView()
                            } else {
                                Label("ads.watch", systemImage: "play.rectangle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("PaletteGreen"))
                        .disabled(watchingRewardId != nil || !adsProvider.isRewardedReady)
                        .accessibilityIdentifier("ads.watch.\(reward.id)")
                    }
                }
            }
            .navigationTitle(Text("ads.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("store.close") { dismiss() }
                }
            }
        }
    }

    private func watch(_ reward: RewardedAdsConfig.Reward) {
        watchingRewardId = reward.id
        Task {
            let earned = await adsProvider.showRewarded()
            if earned {
                gameState.applyRewardedReward(reward)
            }
            watchingRewardId = nil
        }
    }
}
