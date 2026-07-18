import EconomyKit
import Foundation

/// Everything data-driven the game needs, loaded and validated once at launch.
struct GameContent: Sendable {
    let economy: EconomyConfig
    let tiers: TierRepository
    let manifest: AssetsManifest
    let flags: FeatureFlags
    let prestigeUnlocks: PrestigeUnlocks
    let rewardedAds: RewardedAdsConfig
}

/// Decodes and validates the bundled JSON content. Any failure produces a typed
/// `GameError` with a precise log detail; Debug builds assert so bad content is
/// caught immediately, Release builds show a friendly error screen.
enum GameContentLoader {
    static func load(from bundle: Bundle) throws -> GameContent {
        let tiersFile: TiersFile = try decode("tiers", from: bundle)
        let economy: EconomyConfig = try decode("economy", from: bundle)
        let manifest: AssetsManifest = try decode("assets_manifest", from: bundle)
        let flags: FeatureFlags = try decode("feature_flags", from: bundle)
        let prestigeUnlocks: PrestigeUnlocks = try decode("prestige_unlocks", from: bundle)
        let rewardedAds: RewardedAdsConfig = try decode("rewarded_ads", from: bundle)

        let tiers: TierRepository
        do {
            tiers = try TierRepository(types: tiersFile.types)
        } catch {
            throw GameError.contentInvalid(file: "tiers.json", reason: "\(error)")
        }

        return GameContent(economy: economy, tiers: tiers, manifest: manifest, flags: flags, prestigeUnlocks: prestigeUnlocks, rewardedAds: rewardedAds)
    }

    private static func decode<T: Decodable>(_ name: String, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw GameError.contentFileMissing("\(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw GameError.contentInvalid(file: "\(name).json", reason: "\(error)")
        }
    }
}
