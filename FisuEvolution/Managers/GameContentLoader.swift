import EconomyKit
import Foundation

/// Everything data-driven the game needs, loaded and validated once at launch.
struct GameContent: Sendable {
    let economy: EconomyConfig
    let tiers: TierRepository
    /// La Torre (F7): mapeo tier→piso validado, derivado de `economy.floors`.
    let floorTable: FloorTable
    let manifest: AssetsManifest
    let flags: FeatureFlags
    let prestigeUnlocks: PrestigeUnlocks
    let rewardedAds: RewardedAdsConfig
    let events: EventsConfig
    let specials: SpecialsConfig
    let upgradesConfig: UpgradesConfig
    let dailyRewards: DailyRewardsConfig
    let boosts: BoostsConfig
    let viral: ViralConfig
    let gameCenter: GameCenterConfig
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
        let events: EventsConfig = try decode("events", from: bundle)
        let specials: SpecialsConfig = try decode("specials", from: bundle)
        let upgradesConfig: UpgradesConfig = try decode("upgrades", from: bundle)
        let dailyRewards: DailyRewardsConfig = try decode("daily_rewards", from: bundle)
        let boosts: BoostsConfig = try decode("boosts", from: bundle)
        let viral: ViralConfig = try decode("viral", from: bundle)
        let gameCenter: GameCenterConfig = try decode("gamecenter", from: bundle)

        let tiers: TierRepository
        do {
            tiers = try TierRepository(types: tiersFile.types)
        } catch {
            throw GameError.contentInvalid(file: "tiers.json", reason: "\(error)")
        }

        let floorTable: FloorTable
        do {
            floorTable = try FloorTable(floors: economy.floors, maxTier: tiers.maxTier)
        } catch {
            throw GameError.contentInvalid(file: "economy.json (floors)", reason: "\(error)")
        }
        // Todo fondo referenciado por un piso tiene que existir en el manifest.
        for floor in floorTable.floors where manifest.backgrounds[floor.background] == nil {
            throw GameError.contentInvalid(
                file: "economy.json (floors)",
                reason: "floor \(floor.id) references unknown background \(floor.background)"
            )
        }

        return GameContent(
            economy: economy,
            tiers: tiers,
            floorTable: floorTable,
            manifest: manifest,
            flags: flags,
            prestigeUnlocks: prestigeUnlocks,
            rewardedAds: rewardedAds,
            events: events,
            specials: specials,
            upgradesConfig: upgradesConfig,
            dailyRewards: dailyRewards,
            boosts: boosts,
            viral: viral,
            gameCenter: gameCenter
        )
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
