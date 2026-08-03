import SwiftUI

/// Bonus: boosts gratuitos con cooldown (bible §1) + rewarded ads (bible §4.4).
/// Los boosts muestran los textos review-safe cuando buildVariant == "store".
struct BonusView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    let adsProvider: any AdsProvider
    @State private var watchingRewardId: String?
    @State private var chestAmount: Double?
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // effectsVersion observado → cooldowns se refrescan al activar.
        let _ = gameState.effectsVersion

        NavigationStack {
            List {
                Section("bonus.section.boosts") {
                    ForEach(gameState.content?.boosts.boosts ?? []) { boost in
                        boostRow(boost)
                    }
                }
                .listRowBackground(Color.clear)
                Section("bonus.section.ads") {
                    ForEach(gameState.content?.rewardedAds.rewards ?? []) { reward in
                        rewardedRow(reward)
                    }
                }
                .listRowBackground(Color.clear)
                if let chestAmount {
                    Section {
                        Label {
                            Text(verbatim: "+\(CoinFormatter.string(from: chestAmount))")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "gift.fill")
                                .foregroundStyle(Color("PaletteYellow"))
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 22, for: .scrollContent)
            .contentMargins(.top, 20, for: .scrollContent)
            .background { PanelBackground(art: "panel_reward") }
            .safeAreaInset(edge: .top) {
                PanelTitleBanner(titleKey: "ads.title").padding(.top, 6).padding(.bottom, 4)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ArtCloseButton { dismiss() }
                }
            }
            .onReceive(timer) { now = $0 }
        }
    }

    private func boostRow(_ boost: BoostsConfig.Boost) -> some View {
        let variant = gameState.content?.flags.buildVariant ?? "dev"
        let remaining = gameState.boostCooldownRemaining(boost)

        return HStack {
            if let icon = UIArt.image("ui_boost_\(boost.id)") {
                icon.resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(boost.displayNameKey(buildVariant: variant)))
                    .font(.headline)
                if boost.durationSeconds > 0 {
                    Text("bonus.duration \(String(Int(boost.durationSeconds)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if remaining > 0 {
                Text(verbatim: cooldownText(remaining))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Button("bonus.activate") {
                    chestAmount = gameState.activateBoost(id: boost.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("PaletteOrange"))
            }
        }
    }

    private func rewardedRow(_ reward: RewardedAdsConfig.Reward) -> some View {
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

    private func cooldownText(_ remaining: TimeInterval) -> String {
        let total = Int(remaining)
        if total >= 3600 { return "\(total / 3600)h \(total % 3600 / 60)m" }
        if total >= 60 { return "\(total / 60)m \(total % 60)s" }
        return "\(total)s"
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
