import Foundation
import Testing
@testable import EconomyKit

/// El simulador por segmento (2.1 E15 F2-T2, contrato C2; R7). Corre sobre la escalera chica de
/// `PacingSimulatorTests` con todas las fuentes prendidas: los números de la 2.0 (Dios 45,40 h con
/// `.free`) los fija el contrato de la app (F2-T4) contra el contenido real.
@Suite("El simulador por segmento")
struct PacingSegmentTests {
    private func wheel() -> WheelConfig {
        WheelConfig(
            schemaVersion: 1, videoSpinsPerDay: 2, blueSpinCost: 1, blueSpinsPerDay: 0, spinSeconds: 1,
            chestFallbackSegmentId: "plata",
            segments: [.init(id: "plata", weight: 3, reward: .coinsSeconds(300)),
                       .init(id: "giro", weight: 1, reward: .wheelSpin(1))]
        )
    }

    private func ads() -> AdsSources {
        AdsSources(
            videoSeconds: 30, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: wheel(), wheelRepeats: true, treasures: fxTreasures(),
            adBreakIntervalSeconds: 600,
            adBreakPrizes: [.coinsSeconds(600), .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 300), .package(1)],
            mergeAllCooldownSeconds: 600, packageRainCooldownSeconds: 3600, packageRain: .package(5),
            giftDoubles: true
        )
    }

    /// Todas las fuentes: las de regalo, las de video y los permanentes de la tienda.
    private func sources() -> PacingSources {
        PacingSources(
            packages: PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: 300, firstPackageAfterSeconds: 300,
                                     maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4]),
            dailyMinutes: [5, 8, 12, 18, 25, 40, 15],
            freeBoosts: [.init(id: "fernet", cooldownSeconds: 3600, effect: .incomeBurst(multiplier: 3, seconds: 90))],
            freeHireSeconds: 120,
            freeMattress: fxTreasures(freeBoardIntervalSeconds: 1800),
            ads: ads(),
            shop: ShopPermanents(extraSlots: 1, bestSupplierLevel: 1, bonusDailyWheelSpins: 1)
        )
    }

    private func run(
        _ profile: PacingProfile, segment: PacingSegment? = nil, seed: Double = 0.5, days: Int = 8
    ) throws -> PacingSimulator.Report {
        try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                            profile: profile, sources: sources(), seedFraction: seed, segment: segment).run(maxDays: days)
    }

    private func run(_ profile: PacingProfile, sources: PacingSources, segment: PacingSegment?, days: Int = 1) throws
        -> PacingSimulator.Report {
        try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                            profile: profile, sources: sources, segment: segment).run(maxDays: days)
    }

    private static let profiles: [PacingProfile] = [.free, .ads, .max]

    @Test("sin segmento el simulador es el de la 2.0: el reporte entero, campo a campo (G1.5)", arguments: profiles)
    func nilIsTheBase(_ profile: PacingProfile) throws {
        let base = try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                       profile: profile, sources: sources()).run(maxDays: 8)
        #expect(try run(profile, segment: nil) == base)
    }

    @Test("la identidad aceptando todo es la base: el reporte entero, campo a campo", arguments: profiles)
    func identityIsTheBase(_ profile: PacingProfile) throws {
        let base = try run(profile)
        #expect(try run(profile, segment: .identity) == base)
        #expect(try run(profile, segment: PacingSegment(levers: .identity, acceptRate: 1)) == base)
        #expect(try run(profile, segment: .reference(.base, levers: SegmentLevers(
            version: "x", segments: [.base: PacingSegment.sweep(rewardMultiplier: [.offline: 2.5],
                                                                offerIntervalScale: 0.75).levers]
        ))) == base, "base es la identidad aunque el archivo diga otra cosa")
    }

    @Test("quien rechaza todas las ofertas juega exactamente como .free")
    func rejectingEverythingIsFree() throws {
        let free = try run(.free)
        let rejecting = try run(.ads, segment: PacingSegment(acceptRate: 0))
        #expect(rejecting == free)
        #expect(rejecting.sourceTotals["videos"] == nil)
    }

    @Test("con acceptRate en el medio mira parte de los videos y rechaza el resto")
    func partialAcceptance() throws {
        let all = try run(.ads, days: 3)
        let some = try run(.ads, segment: PacingSegment(acceptRate: 0.6), days: 3)
        let watched = try #require(some.sourceTotals["videos"])
        let declined = try #require(some.sourceTotals["videos.declined"])
        #expect(watched > 0 && declined > 0)
        #expect(watched < (all.sourceTotals["videos"] ?? 0))
        #expect(all.sourceTotals["videos.declined"] == nil, "sin segmento no se rechaza nada")
        let rate = watched / (watched + declined)
        #expect(rate > 0.45 && rate < 0.75, "aceptó \(rate) de las ofertas con 0,6")
    }

    @Test("es determinístico: dos corridas iguales dan el mismo reporte")
    func deterministic() throws {
        let segment = PacingSegment(
            levers: PacingSegment.sweep(rewardMultiplier: [.offline: 2.5, .mattress: 2.25], offerIntervalScale: 0.9).levers,
            acceptRate: 0.6
        )
        #expect(try run(.ads, segment: segment) == run(.ads, segment: segment))
        #expect(try run(.max, segment: segment, seed: 0.1) == run(.max, segment: segment, seed: 0.1))
    }

    @Test("un premio por video más grande no hace llegar a Dios más tarde")
    func biggerRewardsAreNotSlower() throws {
        let base = try #require(try run(.ads).godActive, "la fixture tiene que llegar a dios")
        // Los topes de premio y de ofertas, con la pausa publicitaria como en la base: espaciarla saca
        // premios de la pausa y eso lo mide el contrato por segmento (F2-T4), no este test.
        var generous = SegmentLevers.Caps.worstCase
        generous.forcedSpacingScale = 1
        let caps = try #require(try run(.ads, segment: PacingSegment(levers: generous)).godActive)
        let offline = try #require(try run(.ads, segment: .sweep(rewardMultiplier: [.offline: 2.5],
                                                                   offerIntervalScale: 1)).godActive)
        #expect(caps <= base, "topes \(caps) s vs base \(base) s")
        #expect(offline <= base, "offline ×2,5 \(offline) s vs base \(base) s")
    }

    @Test("el offline ×2,5 paga 1,25 veces lo del ×2 al volver")
    func offlinePaysItsMultiplier() throws {
        var quiet = PacingSources.none
        quiet.ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 2, dailyMultiplier: 1, careerMultiplier: 1,
            wheel: nil, wheelRepeats: false, treasures: nil, adBreakIntervalSeconds: .infinity, adBreakPrizes: [],
            mergeAllCooldownSeconds: .infinity, packageRainCooldownSeconds: .infinity, packageRain: nil
        )
        // Un día, una sola vuelta del offline: la primera ausencia es la misma con los dos multiplicadores.
        let doubled = try run(.ads, sources: quiet, segment: nil)
        let bigger = try run(.ads, sources: quiet, segment: .sweep(rewardMultiplier: [.offline: 2.5], offerIntervalScale: 1))
        let base = try #require(doubled.sourceTotals["coins.offline"])
        #expect(try #require(bigger.sourceTotals["coins.offline"]) > base)
        #expect(bigger.sourceTotals["videos"] == doubled.sourceTotals["videos"], "el mismo video, más premio")
    }

    @Test("el ×N del colchón gratis: la plata ×N, lo que no es plata una vez más (como en el juego)")
    func theGiftDoublePaysNonCoinsOnceMore() throws {
        var blueOnly = PacingSources.none
        blueOnly.freeMattress = fxTreasures(freeBoardIntervalSeconds: 600,
                                            prizes: [.init(id: "blue", weight: 1, rewards: [.blue(1)])])
        blueOnly.ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 1, dailyMultiplier: 1, careerMultiplier: 1,
            wheel: nil, wheelRepeats: false, treasures: nil, adBreakIntervalSeconds: .infinity, adBreakPrizes: [],
            mergeAllCooldownSeconds: .infinity, packageRainCooldownSeconds: .infinity, packageRain: nil,
            giftDoubles: true
        )
        let report = try run(.ads, sources: blueOnly,
                             segment: .sweep(rewardMultiplier: [.mattress: 2.5], offerIntervalScale: 1))
        let opened = try #require(report.sourceTotals["freeMattress.opened"])
        #expect(report.sourceTotals["blue.fromSources"] == 2 * opened, "el blue no se paga ×2,5")

        #expect(PacingSimulator.videoTimes(.coinsSeconds(60), multiplier: 2.5) == 2.5)
        #expect(PacingSimulator.videoTimes(.blue(1), multiplier: 2.5) == 2)
        #expect(PacingSimulator.videoTimes(.package(1), multiplier: 2.5) == 2)
        #expect(PacingSimulator.videoTimes(.blue(1), multiplier: 2) == 2)
    }
}

@Suite("Las fuentes con las palancas de un segmento")
struct PacingSourcesLeversTests {
    private func sources(offline: Double = 2) -> PacingSources {
        PacingSources(
            packages: nil, dailyMinutes: [5], freeBoosts: [], freeHireSeconds: 120,
            freeMattress: fxTreasures(freeBoardIntervalSeconds: 1800),
            ads: AdsSources(
                videoSeconds: 30, offlineMultiplier: offline, dailyMultiplier: 2, careerMultiplier: 2,
                wheel: nil, wheelRepeats: true, treasures: fxTreasures(),
                adBreakIntervalSeconds: 600, adBreakPrizes: [.coinsSeconds(60)],
                mergeAllCooldownSeconds: 600, packageRainCooldownSeconds: 3600, packageRain: .package(5),
                giftDoubles: true
            )
        )
    }

    @Test("la identidad devuelve las mismas fuentes")
    func identity() {
        #expect(sources().applying(.identity) == sources())
        #expect(PacingSources.none.applying(SegmentLevers.Caps.worstCase) == .none)
    }

    @Test("cada palanca va a su campo y a ningún otro")
    func eachLeverToItsField() throws {
        let levers = SegmentLevers.Levers(
            videoRewardMultiplier: ["offline": 2.5, "daily": 2.25, "career": 2.1, "mattress": 2.4, "wheel": 2.2,
                                    "visit": 2.5, "achievement": 2.5, "event": 2.5],
            freeMattressIntervalScale: 0.8, visitorIntervalScale: 0.75, sideRailCooldownScale: 0.9,
            forcedSpacingScale: 1.25
        )
        let applied = sources().applying(levers)
        let ads = try #require(applied.ads)
        let base = try #require(sources().ads)
        #expect(ads.offlineMultiplier == 2.5)
        #expect(ads.dailyMultiplier == 2.25)
        #expect(ads.careerMultiplier == 2.1)
        #expect(ads.giftDoubleMultiplier == 2.4)
        #expect(ads.wheelRepeatMultiplier == 2.2)
        #expect(ads.mergeAllCooldownSeconds == 540)
        #expect(ads.packageRainCooldownSeconds == 3240)
        #expect(ads.adBreakIntervalSeconds == 750)
        #expect(applied.freeMattress?.freeBoardIntervalSeconds == 1440)
        #expect(applied.freeMattress?.prizes == sources().freeMattress?.prizes)
        // Lo que ninguna palanca toca.
        #expect(ads.videoSeconds == base.videoSeconds)
        #expect(ads.treasures == base.treasures)
        #expect(ads.adBreakPrizes == base.adBreakPrizes)
        #expect(applied.dailyMinutes == sources().dailyMinutes)
        #expect(applied.freeHireSeconds == sources().freeHireSeconds)
    }

    @Test("un ×N no prende un video que el bot no mira (multiplicador 1)")
    func unwatchedStaysUnwatched() throws {
        let applied = sources(offline: 1).applying(SegmentLevers.Caps.worstCase)
        #expect(try #require(applied.ads).offlineMultiplier == 1)
    }
}

@Suite("La moneda de las ofertas y los jugadores de referencia")
struct PacingSegmentCoinTests {
    @Test("acceptRate 1 acepta todo y 0 nada")
    func extremes() {
        for index in 0..<200 {
            #expect(PacingSegment(acceptRate: 1).accepts(offer: index, seedFraction: 0.5))
            #expect(!PacingSegment(acceptRate: 0).accepts(offer: index, seedFraction: 0.5))
        }
    }

    @Test("la moneda es determinista y acepta la fracción pedida", arguments: [0.25, 0.6])
    func fraction(_ rate: Double) {
        let segment = PacingSegment(acceptRate: rate)
        let answers = (0..<2000).map { segment.accepts(offer: $0, seedFraction: 0.5) }
        #expect(answers == (0..<2000).map { segment.accepts(offer: $0, seedFraction: 0.5) })
        let accepted = Double(answers.filter { $0 }.count) / Double(answers.count)
        #expect(abs(accepted - rate) < 0.05, "\(accepted) con \(rate)")
        let otherSeed = (0..<2000).map { segment.accepts(offer: $0, seedFraction: 0.1) }
        #expect(otherSeed != answers, "otra semilla, otras monedas")
    }

    @Test("acceptRate fuera de 0…1 se acota")
    func clamped() {
        #expect(PacingSegment(acceptRate: 1.5).acceptRate == 1)
        #expect(PacingSegment(acceptRate: -0.2).acceptRate == 0)
    }

    @Test("los jugadores de referencia de R7: low 0,25 · mid 0,6 · high 1; base acepta todo con la identidad")
    func references() throws {
        #expect(PacingSegment.referenceAcceptRate(for: .low) == 0.25)
        #expect(PacingSegment.referenceAcceptRate(for: .mid) == 0.6)
        #expect(PacingSegment.referenceAcceptRate(for: .high) == 1)
        let high = SegmentLevers.Levers(videoRewardMultiplier: ["offline": 2.5], forcedSpacingScale: 1.25)
        let file = SegmentLevers(version: "t", segments: [.high: high])
        #expect(PacingSegment.reference(.base, levers: file) == .identity)
        #expect(PacingSegment.reference(.high, levers: file) == PacingSegment(levers: high, acceptRate: 1))
        #expect(PacingSegment.reference(.mid, levers: file) == PacingSegment(levers: .identity, acceptRate: 0.6))
    }
}
