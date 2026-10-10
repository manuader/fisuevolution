import EconomyKit
import Foundation

/// Lo que el CLI lee de `Resources/Config` para armar las fuentes del simulador.
/// Los tipos que EconomyKit conoce se decodifican con ellos; lo que es de la app
/// (`ContentConfigs`) entra por espejos mínimos de acá abajo, como `UpgradesFile`.
struct LoadedSources {
    var sources = PacingSources.none
    var prestigeUnlocks: PrestigeUnlocks?
    /// Una línea `⚠️ sin <archivo>` por cada archivo que faltó o no decodificó.
    var warnings: [String] = []
    var loaded: [String] = []
}

/// Dónde están las fuentes cuando nadie lo dijo: `../Config/` al lado de
/// `--economy`, igual que `--upgrades`.
func resolveSourcesURL(nextTo economyURL: URL) -> URL? {
    let directory = economyURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Config")
    return FileManager.default.fileExists(atPath: directory.path) ? directory : nil
}

private struct DailyRewardsFile: Decodable {
    struct Day: Decodable { let minutes: Double }
    let days: [Day]
}

private struct BoostsFile: Decodable {
    struct Boost: Decodable {
        let id: String
        let effectType: String
        let magnitude: Double
        let durationSeconds: Double?
        let cooldownSeconds: Double
    }
    let boosts: [Boost]

    /// `spawnCostMultiplier` (el Mate) queda afuera: es un descuento de 60 s que
    /// el simulador no modela (declarado). El tope del offline es `EffectCaps.offline`
    /// de la app (`EffectDescriptor.swift`), 1,0.
    var freeBoosts: [PacingSources.FreeBoost] {
        boosts.compactMap { boost in
            let effect: PacingSources.FreeBoost.Effect
            switch boost.effectType {
            case "incomeMultiplier": effect = .incomeBurst(multiplier: boost.magnitude, seconds: boost.durationSeconds ?? 0)
            case "tapMultiplier": effect = .tapBurst(multiplier: boost.magnitude, seconds: boost.durationSeconds ?? 0)
            case "periodicPayout": effect = .payoutMinutes(boost.magnitude)
            case "offlineEfficiencyPermanent": effect = .offlineStep(step: boost.magnitude, cap: 1.0)
            default: return nil
            }
            return PacingSources.FreeBoost(id: boost.id, cooldownSeconds: boost.cooldownSeconds, effect: effect)
        }
    }
}

private struct CareersFile: Decodable {
    struct Career: Decodable {
        let id: String
        let durationSeconds: Double?
    }
    let careers: [Career]
}

/// `rewarded_ads.json`: lo que la tabla de videos de la app define. `sideRail` y
/// `adBreak` son de E7b: mientras el archivo no los traiga, esas fuentes quedan
/// apagadas (el "Fusionar todo" cae al `merge_all` de `rewards`).
private struct RewardedAdsFile: Decodable {
    struct Reward: Decodable {
        let id: String
        let cooldownSeconds: Double?
    }
    struct SideRail: Decodable {
        let mergeAllCooldownSeconds: Double?
        let packageRainCooldownSeconds: Double?
        let packageRain: RewardSpec?
    }
    struct AdBreak: Decodable {
        let intervalSeconds: Double?
        let prizes: [RewardSpec]
    }
    let rewards: [Reward]?
    let sideRail: SideRail?
    let adBreak: AdBreak?
}

private struct AdsCadenceFile: Decodable {
    struct Cadence: Decodable { let minSecondsBetweenForced: Double }
    let cadence: Cadence
}

/// Cuánto cuesta mirar un video en segundos de sesión del bot.
private let videoSeconds = 30.0

func loadSources(from directory: URL, requireDiscount: Bool) -> LoadedSources {
    var result = LoadedSources()

    func read<T: Decodable>(_ file: String, as type: T.Type) -> T? {
        let url = directory.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else {
            result.warnings.append("⚠️ sin \(file)")
            return nil
        }
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            result.loaded.append(file)
            return value
        } catch {
            result.warnings.append("⚠️ \(file) no se pudo leer (\(error))")
            return nil
        }
    }

    result.sources.packages = read("packages.json", as: PackagesConfig.self)
    result.sources.dailyMinutes = read("daily_rewards.json", as: DailyRewardsFile.self)?.days.map(\.minutes) ?? []
    result.sources.freeBoosts = read("boosts.json", as: BoostsFile.self)?.freeBoosts ?? []
    result.sources.freeHireSeconds = read("careers.json", as: CareersFile.self)?
        .careers.first { $0.id == "junior_programmer" }?.durationSeconds ?? 0
    result.prestigeUnlocks = read("prestige_unlocks.json", as: PrestigeUnlocks.self)

    let wheel = read("wheel.json", as: WheelConfig.self)
    let treasures = read("treasures.json", as: TreasuresConfig.self)
    let rewardedAds = read("rewarded_ads.json", as: RewardedAdsFile.self)
    let cadence = read("ads.json", as: AdsCadenceFile.self)?.cadence
    let mergeAllCooldown = rewardedAds?.sideRail?.mergeAllCooldownSeconds
        ?? rewardedAds?.rewards?.first { $0.id == "merge_all" }?.cooldownSeconds
        ?? 0
    result.sources.ads = AdsSources(
        videoSeconds: videoSeconds, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
        wheel: wheel, wheelRepeats: true, treasures: treasures,
        adBreakIntervalSeconds: rewardedAds?.adBreak?.intervalSeconds ?? cadence?.minSecondsBetweenForced ?? .infinity,
        adBreakPrizes: rewardedAds?.adBreak?.prizes ?? [],
        mergeAllCooldownSeconds: mergeAllCooldown,
        packageRainCooldownSeconds: rewardedAds?.sideRail?.packageRainCooldownSeconds ?? 0,
        packageRain: rewardedAds?.sideRail?.packageRain
    )

    if let catalog = read("oro_shop.json", as: OroShopCatalog.self) {
        let top = Dictionary(uniqueKeysWithValues: catalog.items.filter(\.isPermanent).map { ($0.id, $0.levels.count) })
        result.sources.shop = ShopPermanents(
            extraSlots: OroShop.extraSlots(levels: top, catalog: catalog),
            bestSupplierLevel: OroShop.bestSupplierLevel(levels: top, catalog: catalog),
            bonusDailyWheelSpins: OroShop.bonusDailyWheelSpins(levels: top, catalog: catalog)
        )
    }
    return result
}
