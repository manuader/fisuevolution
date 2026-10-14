import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El contenido real traducido a lo que el simulador entiende. Es el único
/// lugar donde la app arma `PacingSources`; el CLI tiene su espejo
/// (`Tools/pacing-sim/Sources/SourcesLoader.swift`) y E2b T14 compara las dos salidas.
enum PacingFixture {
    static let contractPolicy = PacingSimulator.ReincarnationPolicy.whenBlueMultiplies(4)

    /// Lo que cuesta mirar un video en segundos de sesión del bot.
    private static let videoSeconds = 30.0

    static func sources(_ content: GameContent) throws -> PacingSources {
        var sources = PacingSources(
            packages: content.packages,
            dailyMinutes: content.dailyRewards.days.sorted { $0.day < $1.day }.compactMap(\.minutes),
            freeBoosts: content.boosts.boosts.compactMap(freeBoost),
            freeHireSeconds: content.careers.careers.first { $0.id == "junior_programmer" }?.durationSeconds ?? 0
        )
        let rail = content.rewardedAds.effectiveSideRail
        sources.ads = AdsSources(
            videoSeconds: videoSeconds, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: content.wheel, wheelRepeats: true, treasures: content.treasures,
            adBreakIntervalSeconds: try adBreakIntervalSeconds(),
            adBreakPrizes: content.rewardedAds.effectiveAdBreak.prizes,
            mergeAllCooldownSeconds: rail.mergeAllCooldownSeconds,
            packageRainCooldownSeconds: rail.packageRainCooldownSeconds,
            packageRain: rail.packageRain
        )
        let topLevels = Dictionary(
            uniqueKeysWithValues: content.blueShop.items.filter(\.isPermanent).map { ($0.id, $0.levels.count) }
        )
        sources.shop = ShopPermanents(
            extraSlots: BlueShop.extraSlots(levels: topLevels, catalog: content.blueShop),
            bestSupplierLevel: BlueShop.bestSupplierLevel(levels: topLevels, catalog: content.blueShop),
            bonusDailyWheelSpins: BlueShop.bonusDailyWheelSpins(levels: topLevels, catalog: content.blueShop)
        )
        return sources
    }

    /// Cada cuántos segundos sale la pausa bonificada con el `ads.json` embarcado:
    /// la cadencia entre forzados, repartida según cuántos turnos de la
    /// alternancia son el intersticial con premio.
    private static func adBreakIntervalSeconds() throws -> Double {
        let url = try #require(Bundle.main.url(forResource: "ads", withExtension: "json"))
        let config = try JSONDecoder().decode(AdsRemoteConfig.self, from: Data(contentsOf: url))
        let rewarded = config.alternation.filter { $0 == .rewardedInterstitial }.count
        guard rewarded > 0 else { return .infinity }
        return config.cadence.minSecondsBetweenForced * Double(config.alternation.count) / Double(rewarded)
    }

    private static func freeBoost(_ boost: BoostsConfig.Boost) -> PacingSources.FreeBoost? {
        let effect: PacingSources.FreeBoost.Effect
        switch boost.effectType {
        case .incomeMultiplier: effect = .incomeBurst(multiplier: boost.magnitude, seconds: boost.durationSeconds)
        case .tapMultiplier: effect = .tapBurst(multiplier: boost.magnitude, seconds: boost.durationSeconds)
        case .periodicPayout: effect = .payoutMinutes(boost.magnitude)
        case .offlineEfficiencyPermanent: effect = .offlineStep(step: boost.magnitude, cap: EffectCaps.offline)
        case .spawnCostMultiplier: return nil
        }
        return .init(id: boost.id, cooldownSeconds: boost.cooldownSeconds, effect: effect)
    }

    static func simulator(
        _ content: GameContent, profile: PacingProfile, policy: PacingSimulator.ReincarnationPolicy
    ) throws -> PacingSimulator {
        try PacingSimulator(
            config: content.economy,
            tiers: content.tiers,
            human: .init(reincarnation: policy),
            upgrades: try PacingTests.permanentLines(from: content.upgradesConfig),
            prestigeUnlocks: content.prestigeUnlocks,
            profile: profile,
            sources: try sources(content)
        )
    }
}

/// Las cuatro partidas del contrato, simuladas UNA vez por proceso: swift-testing
/// construye una instancia de suite por test, y cada simulación entera cuesta
/// segundos (PLAN-v2: "una suite aparte con el reporte cacheado").
enum PacingReports {
    static let free = play(.free, PacingFixture.contractPolicy)
    static let ads = play(.ads, PacingFixture.contractPolicy)
    static let max = play(.max, PacingFixture.contractPolicy)
    static let never = play(.free, .never)

    private static func play(
        _ profile: PacingProfile, _ policy: PacingSimulator.ReincarnationPolicy
    ) -> Result<PacingSimulator.Report, any Error> {
        Result {
            let content = try GameContentLoader.load(from: .main)
            return try PacingFixture.simulator(content, profile: profile, policy: policy).run(maxDays: 400)
        }
    }
}
