import Foundation
import Observation

/// Rewarded-ads seam (bible §4.4). `StubAdsProvider` in dev; `AdMobAdsProvider`
/// lands in F5.5 behind `feature_flags.useRealAds` — gameplay and UI never change.
@MainActor
protocol AdsProvider: AnyObject {
    var isRewardedReady: Bool { get }
    /// Presents a rewarded ad; returns true only if the reward was earned.
    func showRewarded() async -> Bool
}

/// Dev-only simulator: 2 s of fake "ad". Never ships — `useRealAds` selects the
/// real provider in store builds (F5.5), and the bonus UI hides without one.
@Observable @MainActor
final class StubAdsProvider: AdsProvider {
    private(set) var isShowing = false
    var isRewardedReady: Bool { !isShowing }

    func showRewarded() async -> Bool {
        guard !isShowing else { return false }
        isShowing = true
        defer { isShowing = false }
        try? await Task.sleep(for: .seconds(2))
        return true
    }
}

/// Mirrored 1:1 from `rewarded_ads.json` — the four effects of bible §4.4.
struct RewardedAdsConfig: Codable, Sendable, Equatable {
    enum EffectType: String, Codable, Sendable {
        /// Temporary income multiplier (double earnings / temp multiplier).
        case incomeMultiplier
        /// Free instant merge of the highest mergeable pair (accelerate evolution).
        case instantMerge
        /// Grants a unit of the highest tier reached (spawn rare — F4 stub;
        /// F5 rewires this to the real special-character drop).
        case rareUnit
    }

    struct Reward: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let effectType: EffectType
        let magnitude: Double?
        let durationSeconds: Double?
        let titleKey: String
        /// Cuánto tarda ESTA recompensa en volver a ofrecerse (RF-11). Los cuatro
        /// cooldowns corren en paralelo: mirar un video no bloquea a los otros.
        let cooldownSeconds: Double
    }

    let schemaVersion: Int
    let rewards: [Reward]
}
