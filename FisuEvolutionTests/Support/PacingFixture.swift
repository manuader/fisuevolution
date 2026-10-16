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
            freeHireSeconds: content.careers.careers.first { $0.id == "junior_programmer" }?.durationSeconds ?? 0,
            freeMattress: content.treasures
        )
        let rail = content.rewardedAds.effectiveSideRail
        sources.ads = AdsSources(
            videoSeconds: videoSeconds, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: content.wheel, wheelRepeats: true, treasures: content.treasures,
            adBreakIntervalSeconds: try adBreakIntervalSeconds(),
            adBreakPrizes: content.rewardedAds.effectiveAdBreak.prizes,
            mergeAllCooldownSeconds: rail.mergeAllCooldownSeconds,
            packageRainCooldownSeconds: rail.packageRainCooldownSeconds,
            packageRain: rail.packageRain,
            giftDoubles: true
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

    // MARK: - Por segmento (2.1 E15 F2-T4)

    /// El jugador de un segmento para el contrato C3: qué brazos de los momentos ve (`segment`) y sus palancas
    /// con la fracción de videos que acepta (`pacing`).
    struct SegmentPlayer {
        var segment: PlayerSegment
        var pacing: PacingSegment

        /// El jugador de referencia de `segment` con las palancas de `levers` (el `segments.json` o los topes).
        static func reference(_ segment: PlayerSegment, levers: SegmentLevers) -> SegmentPlayer {
            SegmentPlayer(segment: segment, pacing: .reference(segment, levers: levers))
        }

        /// El peor caso remoto: las palancas en los topes del código y todas las ofertas aceptadas.
        static func worstCase(_ segment: PlayerSegment) -> SegmentPlayer {
            SegmentPlayer(segment: segment, pacing: PacingSegment(
                levers: SegmentLevers.Caps.worstCase, acceptRate: PacingSegment.referenceAcceptRate(for: segment)
            ))
        }
    }

    /// Las fuentes de la base más las ofertas del momento que ve `segment`. Las palancas **no** se aplican acá:
    /// el simulador las aplica en su `init` (`PacingSources.applying`), y aplicarlas dos veces sería ver otro
    /// juego. Que esa función y la del juego (`GameContent.applying`) den los mismos relojes lo cuida
    /// `SegmentPacingContractTests`. Con `base`, exactamente las fuentes de la 2.0.
    static func sources(_ content: GameContent, segment: PlayerSegment) throws -> PacingSources {
        var sources = try sources(content)
        guard segment != .base else { return sources }
        sources.ads?.moments = try momentsAtMaxFrequency()
        return sources
    }

    /// El `moments.json` del bundle con su frecuencia máxima: los topes de frecuencia del código
    /// (`MomentsConfig.Caps.hard`), el peor caso que podría mandar lo remoto.
    static func momentsAtMaxFrequency() throws -> MomentsConfig {
        var moments = try bundled("moments", as: MomentsConfig.self)
        moments.caps = .hard
        try moments.validate()
        return moments
    }

    /// El `segments.json` del bundle, validado con los topes del código.
    static func bundledSegmentLevers() throws -> SegmentLevers {
        let levers = try bundled("segments", as: SegmentLevers.self)
        try levers.validate()
        return levers
    }

    private static func bundled<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    static func simulator(
        _ content: GameContent, profile: PacingProfile, policy: PacingSimulator.ReincarnationPolicy,
        player: SegmentPlayer
    ) throws -> PacingSimulator {
        try PacingSimulator(
            config: content.economy,
            tiers: content.tiers,
            human: .init(reincarnation: policy),
            upgrades: try PacingTests.permanentLines(from: content.upgradesConfig),
            prestigeUnlocks: content.prestigeUnlocks,
            profile: profile,
            sources: try sources(content, segment: player.segment),
            segment: player.pacing,
            playerSegment: player.segment
        )
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

/// Las partidas del contrato por segmento (2.1 E15 F2-T4, C3), simuladas UNA vez por proceso como las de
/// `PacingReports`: no la matriz entera del CLI, sólo lo que el contrato lee. La base son `PacingReports`.
enum SegmentPacingReports {
    typealias Player = PacingFixture.SegmentPlayer

    // Los jugadores de referencia con el `segments.json` del bundle (C3.1–3 y C3.6).
    static let lowFree = play(.free) { .reference(.low, levers: $0) }
    static let midFree = play(.free) { .reference(.mid, levers: $0) }
    static let highFree = play(.free) { .reference(.high, levers: $0) }
    static let lowAds = play(.ads) { .reference(.low, levers: $0) }
    static let midAds = play(.ads) { .reference(.mid, levers: $0) }
    static let highAds = play(.ads) { .reference(.high, levers: $0) }

    // La base con la fracción de videos de `low` y de `mid` (C3.3: cada uno contra la base que acepta lo mismo).
    static let baseAdsLowRate = play(.ads) { _ in Player(segment: .base, pacing: PacingSegment(acceptRate: 0.25)) }
    static let baseAdsMidRate = play(.ads) { _ in Player(segment: .base, pacing: PacingSegment(acceptRate: 0.6)) }

    // `high` con los topes del código: el peor caso remoto (C3.1, C3.2 y el piso de C3.4).
    static let worstHighFree = play(.free) { _ in .worstCase(.high) }
    static let worstHighAds = play(.ads) { _ in .worstCase(.high) }
    static let worstHighMax = play(.max) { _ in .worstCase(.high) }

    // C3.5: la base como segmento (palancas de identidad, todo aceptado) con `.ads`.
    static let identityAds = play(.ads) { _ in Player(segment: .base, pacing: .identity) }

    private static func play(
        _ profile: PacingProfile, _ player: (SegmentLevers) -> Player
    ) -> Result<PacingSimulator.Report, any Error> {
        Result {
            let content = try GameContentLoader.load(from: .main)
            let levers = try PacingFixture.bundledSegmentLevers()
            return try PacingFixture.simulator(
                content, profile: profile, policy: PacingFixture.contractPolicy, player: player(levers)
            ).run(maxDays: 400)
        }
    }
}
