import Foundation
import Testing
@testable import EconomyKit

@Suite("Los perfiles del simulador: lo que se da sin video")
struct PacingProfileTests {
    private func packages(interval: Double = 120) -> PackagesConfig {
        PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: interval, firstPackageAfterSeconds: interval,
                       maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4])
    }

    private func sources() -> PacingSources {
        PacingSources(
            packages: packages(),
            dailyMinutes: [5, 8, 12, 18, 25, 40, 15],
            freeBoosts: [
                .init(id: "fernet", cooldownSeconds: 3600, effect: .incomeBurst(multiplier: 3, seconds: 90)),
                .init(id: "asado", cooldownSeconds: 21600, effect: .payoutMinutes(10)),
                .init(id: "milanesa", cooldownSeconds: 86400, effect: .offlineStep(step: 0.05, cap: 1.0)),
            ],
            freeHireSeconds: 120
        )
    }

    private func run(_ profile: PacingProfile, _ sources: PacingSources, seed: Double = 0.5) throws -> PacingSimulator.Report {
        try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                            profile: profile, sources: sources, seedFraction: seed).run(maxDays: 5)
    }

    @Test(".bare con fuentes es la base: las fuentes sólo se juegan con su perfil")
    func bareIgnoresSources() throws {
        let base = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(fingerprint(try run(.bare, sources())) == fingerprint(base))
        #expect(fingerprint(try run(.free, .none)) == fingerprint(base))
    }

    @Test(".free cobra sus fuentes y llega antes")
    func freeUsesItsSources() throws {
        let base = try run(.bare, .none)
        let free = try run(.free, sources())
        #expect((free.sourceTotals["packages.opened"] ?? 0) > 0)
        #expect((free.sourceTotals["coins.daily"] ?? 0) > 0)
        #expect((free.sourceTotals["coins.boosts"] ?? 0) > 0)
        #expect(free.finalLifetimeEarnings > base.finalLifetimeEarnings)
    }

    @Test("el paquete sigue su reloj de juego: con la mitad del intervalo caen casi el doble")
    func packageCadence() throws {
        func opened(_ interval: Double) throws -> Double {
            let report = try run(.free, PacingSources(packages: packages(interval: interval), dailyMinutes: [],
                                                      freeBoosts: [], freeHireSeconds: 0))
            return report.sourceTotals["packages.opened"] ?? 0
        }
        let slow = try opened(240)
        let fast = try opened(120)
        #expect(slow > 0)
        #expect(fast >= 1.6 * slow, "120 s: \(fast) · 240 s: \(slow)")
    }

    @Test("es determinístico, y la semilla sólo mueve el orden de los sorteos")
    func deterministic() throws {
        #expect(fingerprint(try run(.free, sources())) == fingerprint(try run(.free, sources())))
        // Cambia el orden de los sorteos y con él el instante en que llega a
        // Dios, así que lo que se compara es el ritmo (paquetes por segundo activo).
        func rate(_ report: PacingSimulator.Report) -> Double {
            (report.sourceTotals["packages.opened"] ?? 0) / (report.godActive ?? .infinity)
        }
        let a = rate(try run(.free, sources(), seed: 0.1))
        let b = rate(try run(.free, sources(), seed: 0.9))
        #expect(a > 0)
        #expect(abs(a - b) <= 0.05 * a, "0,1: \(a) · 0,9: \(b)")
    }

    @Test("el sorteo del paquete sin torre es el de la torre")
    func eligibleWithoutTowerIsTheGames() throws {
        var fx = try fxStateAndTower(units: ["a": 2, "b": 1])
        fx.state.run.raiseFrontier(to: 4, cushion: fxConfig().priceCushion)
        let occupancy = fx.tower.floors.map(\.occupiedCount)
        let withTower = PackageRoller.eligibleTypes(state: fx.state, tower: fx.tower, tiers: try fxTiers(),
                                                    floorTable: fx.floorTable, config: fxConfig())
        let without = PackageRoller.eligibleTypes(state: fx.state, tiers: try fxTiers(), floorTable: fx.floorTable,
                                                  config: fxConfig(), occupancy: occupancy)
        #expect(without.map(\.id) == withTower.map(\.id))
    }
}

@Suite("El perfil .ads")
struct PacingAdsProfileTests {
    private func ads(_ change: (inout AdsSources) -> Void = { _ in }) -> AdsSources {
        var ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: nil, wheelRepeats: true, treasures: nil,
            adBreakIntervalSeconds: 240,
            adBreakPrizes: [.coinsSeconds(600), .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 300), .package(1)],
            mergeAllCooldownSeconds: 600, packageRainCooldownSeconds: 1800, packageRain: .package(10)
        )
        change(&ads)
        return ads
    }

    private func run(_ profile: PacingProfile, ads: AdsSources?, days: Int = 5) throws -> PacingSimulator.Report {
        var sources = PacingSources.none
        sources.dailyMinutes = [5, 8, 12, 18, 25, 40, 15]
        sources.ads = ads
        return try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                   profile: profile, sources: sources).run(maxDays: days)
    }

    @Test("una pausa sin premios no vence nunca: el reloj no se clava en cero")
    func emptyAdBreakDoesNotStall() throws {
        let report = try run(.ads, ads: ads { $0.adBreakPrizes = [] }, days: 2)
        #expect(report.finalLifetimeEarnings > 0)
    }

    @Test(".free ignora las fuentes de video")
    func freeIgnoresAds() throws {
        #expect(fingerprint(try run(.free, ads: ads())) == fingerprint(try run(.free, ads: nil)))
    }

    @Test(".ads cobra más y mira videos")
    func adsEarnsMore() throws {
        let free = try run(.free, ads: ads())
        let withAds = try run(.ads, ads: ads())
        #expect((withAds.sourceTotals["videos"] ?? 0) > 0)
        #expect((withAds.sourceTotals["coins.adBreak"] ?? 0) > 0)
        #expect(withAds.finalLifetimeEarnings > free.finalLifetimeEarnings)
    }

    @Test("mirar un video cuesta tiempo de sesión: con videos de 10 minutos, .ads pierde")
    func videosCostTime() throws {
        let slow = try run(.ads, ads: ads { $0.videoSeconds = 600 })
        let fast = try run(.ads, ads: ads())
        #expect(slow.finalLifetimeEarnings < fast.finalLifetimeEarnings)
    }

    @Test("el offline ×2 duplica lo que cobra al volver")
    func offlineDoubles() throws {
        // Un día: la partida de cinco llega a Dios a distinta hora con cada
        // multiplicador y el total de offline compara recorridos, no el ×2.
        let base = try run(.ads, ads: ads { $0.offlineMultiplier = 1 }, days: 1)
        let doubled = try run(.ads, ads: ads(), days: 1)
        #expect((doubled.sourceTotals["coins.offline"] ?? 0) > 1.5 * (base.sourceTotals["coins.offline"] ?? 0))
    }

    @Test("un premio ignorado no mueve nada")
    func ignoredRewardsDoNothing() throws {
        let chest = try run(.ads, ads: ads { $0.adBreakPrizes = [.skinChest(1)] })
        let none = try run(.ads, ads: ads { $0.adBreakPrizes = [] ; $0.adBreakIntervalSeconds = .infinity })
        #expect(chest.finalLifetimeEarnings <= none.finalLifetimeEarnings)
    }
}

@Suite("El perfil .ads: cada fuente y el traductor de premios")
struct PacingAdsSourcesTests {
    /// Todas las fuentes de video apagadas: cada test prende la que mide.
    private func quiet(_ change: (inout AdsSources) -> Void = { _ in }) -> AdsSources {
        var ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 1, dailyMultiplier: 1, careerMultiplier: 1,
            wheel: nil, wheelRepeats: false, treasures: nil,
            adBreakIntervalSeconds: .infinity, adBreakPrizes: [],
            mergeAllCooldownSeconds: .infinity, packageRainCooldownSeconds: .infinity, packageRain: nil
        )
        change(&ads)
        return ads
    }

    private func packages() -> PackagesConfig {
        PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: 600, firstPackageAfterSeconds: 600,
                       maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4])
    }

    private func run(
        _ ads: AdsSources?, profile: PacingProfile = .ads, days: Int = 1, freeHireSeconds: Double = 0,
        withPackages: Bool = false
    ) throws -> PacingSimulator.Report {
        var sources = PacingSources.none
        sources.freeHireSeconds = freeHireSeconds
        sources.packages = withPackages ? packages() : nil
        sources.ads = ads
        return try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                   profile: profile, sources: sources).run(maxDays: days)
    }

    private func breakWith(_ prize: RewardSpec, withPackages: Bool = false) throws -> PacingSimulator.Report {
        try run(quiet { $0.adBreakIntervalSeconds = 120; $0.adBreakPrizes = [prize] }, withPackages: withPackages)
    }

    @Test("sin ninguna fuente prendida no se mira ningún video")
    func quietWatchesNothing() throws {
        let report = try run(quiet())
        #expect((report.sourceTotals["videos"] ?? 0) == 0)
    }

    @Test("el traductor: segundos de monedas, modificadores de ingreso y de toque pagan monedas")
    func coinRewardsPay() throws {
        for prize in [RewardSpec.coinsSeconds(600),
                      .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 300),
                      .modifier(effect: .passiveMultiplier, magnitude: 2, seconds: 300),
                      .modifier(effect: .tapMultiplier, magnitude: 2, seconds: 300)] {
            let report = try breakWith(prize)
            #expect((report.sourceTotals["coins.adBreak"] ?? 0) > 0, "\(prize)")
        }
    }

    @Test("el traductor: lo que no mueve la economía del bot no paga monedas ni ORO")
    func ignoredRewardsPayNothing() throws {
        for prize in [RewardSpec.skinChest(1), .clearBoostCooldowns, .autoTap(perSecond: 3, seconds: 60),
                      .extraSlots(1), .eventImmunity(seconds: 60),
                      .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 300)] {
            let report = try breakWith(prize)
            #expect((report.sourceTotals["coins.adBreak"] ?? 0) == 0, "\(prize)")
            #expect((report.sourceTotals["oro.fromSources"] ?? 0) == 0, "\(prize)")
        }
    }

    @Test("el ORO de una fuente se gasta en líneas en el acto, sin tocar el ORO histórico")
    func oroBuysLines() throws {
        let report = try breakWith(.oro(2))
        #expect((report.sourceTotals["oro.fromSources"] ?? 0) > 0)
        #expect(report.finalPermanentUpgradeLevels.values.reduce(0, +) > 0)
    }

    @Test("los paquetes de un premio se suman a la cola y se abren")
    func packagesJoinTheQueue() throws {
        let with = try breakWith(.package(2), withPackages: true)
        let without = try run(quiet(), withPackages: true)
        #expect((with.sourceTotals["packages.opened"] ?? 0) > (without.sourceTotals["packages.opened"] ?? 0))
    }

    @Test("la pausa rota sus premios en orden: el segundo también sale")
    func adBreakRotates() throws {
        let rotating = try run(quiet {
            $0.adBreakIntervalSeconds = 120
            $0.adBreakPrizes = [.skinChest(1), .coinsSeconds(60)]
        })
        let stuck = try run(quiet {
            $0.adBreakIntervalSeconds = 120
            $0.adBreakPrizes = [.skinChest(1)]
        })
        #expect((rotating.sourceTotals["coins.adBreak"] ?? 0) > 0)
        #expect((stuck.sourceTotals["coins.adBreak"] ?? 0) == 0)
    }

    @Test("el diario ×2 es un video por día")
    func dailyDoublesWithOneVideoPerDay() throws {
        var sources = PacingSources.none
        sources.dailyMinutes = [5, 8, 12]
        sources.ads = quiet { $0.dailyMultiplier = 2 }
        let report = try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                         profile: .ads, sources: sources).run(maxDays: 2)
        #expect(report.sourceTotals["videos"] == 2)
        #expect((report.sourceTotals["coins.daily"] ?? 0) > 0)
    }

    @Test("la carrera ×2 duplica la contratación gratis con un video, y sin ella no se mira")
    func careerDoublesWithOneVideo() throws {
        func grant(_ ads: AdsSources, freeHireSeconds: Double) throws -> (video: Double, seconds: Double, videos: Double) {
            var sources = PacingSources.none
            sources.freeHireSeconds = freeHireSeconds
            sources.ads = ads
            let simulator = try PacingSimulator(config: upConfig(), tiers: upTiers(), profile: .ads, sources: sources)
            var state = PlayerState.newGame(
                startTypeId: "t1", startFloorId: "f1", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0
            )
            var report = PacingSimulator.Report()
            let video = simulator.grantFreeHire(state: &state, wall: 100, report: &report)
            let modifier = state.run.activeModifiers.first { $0.effect == .freeHire }
            return (video, (modifier?.expiresAt ?? 100) - 100, report.sourceTotals["videos"] ?? 0)
        }
        let doubled = try grant(quiet { $0.careerMultiplier = 2 }, freeHireSeconds: 120)
        #expect(doubled.seconds == 240 && doubled.videos == 1 && doubled.video == 30)
        let plain = try grant(quiet(), freeHireSeconds: 120)
        #expect(plain.seconds == 120 && plain.videos == 0 && plain.video == 0)
        let none = try grant(quiet { $0.careerMultiplier = 2 }, freeHireSeconds: 0)
        #expect(none.videos == 0 && none.video == 0)
    }

    @Test("la ruleta: giros del día, y el repetir premio es otro video por giro")
    func wheelSpinsAndRepeats() throws {
        let wheel = WheelConfig(
            schemaVersion: 1, videoSpinsPerDay: 3, oroSpinCost: 1, oroSpinsPerDay: 0, spinSeconds: 1,
            chestFallbackSegmentId: "plata",
            segments: [.init(id: "plata", weight: 60, reward: .coinsSeconds(300)),
                       .init(id: "cofre", weight: 40, reward: .skinChest(1))]
        )
        let single = try run(quiet { $0.wheel = wheel })
        let repeating = try run(quiet { $0.wheel = wheel; $0.wheelRepeats = true })
        #expect(single.sourceTotals["videos"] == 3)
        #expect(repeating.sourceTotals["videos"] == 6)
        // Sin pintas que dar, el peso del cofre se va a la plata: 3 × 300 s.
        #expect((single.sourceTotals["coins.wheel"] ?? 0) > 0)
        #expect((repeating.sourceTotals["coins.wheel"] ?? 0) > (single.sourceTotals["coins.wheel"] ?? 0))
    }

    @Test("el colchón: cada apertura es un video, con sus 'otro colchón'")
    func mattressOpens() throws {
        func treasures(extra: Int) -> TreasuresConfig {
            TreasuresConfig(
                schemaVersion: 1, spawnIntervalSeconds: 300, firstTreasureAfterSeconds: 300,
                extraOpensPerTreasure: extra,
                prizes: [.init(id: "plata", weight: 1, rewards: [.coinsSeconds(600)])]
            )
        }
        let single = try run(quiet { $0.treasures = treasures(extra: 0) })
        let more = try run(quiet { $0.treasures = treasures(extra: 1) })
        #expect((single.sourceTotals["coins.mattress"] ?? 0) > 0)
        #expect(more.sourceTotals["videos"] == 2 * (single.sourceTotals["videos"] ?? 0))
    }

    @Test("Fusionar todo: sólo con ficha, y sólo cuando la tanda hace dos fusiones o más")
    func mergeAllCostsAVideo() throws {
        let off = try run(quiet())
        let on = try run(quiet { $0.mergeAllCooldownSeconds = 60 })
        #expect((off.sourceTotals["videos"] ?? 0) == 0)
        #expect((on.sourceTotals["videos"] ?? 0) > 0)
    }

    @Test("la lluvia de paquetes: un video por cooldown de pared")
    func packageRainRespectsItsCooldown() throws {
        let rain = try run(quiet { $0.packageRainCooldownSeconds = 3600; $0.packageRain = .package(5) }, withPackages: true)
        let none = try run(quiet(), withPackages: true)
        #expect((rain.sourceTotals["videos"] ?? 0) > 0)
        #expect((rain.sourceTotals["packages.opened"] ?? 0) > (none.sourceTotals["packages.opened"] ?? 0))
        let daily = try run(quiet { $0.packageRainCooldownSeconds = 86_400; $0.packageRain = .package(5) }, withPackages: true)
        #expect((daily.sourceTotals["videos"] ?? 0) < (rain.sourceTotals["videos"] ?? 0))
    }

    @Test(".max también mira videos; .bare no")
    func maxWatchesBareDoesNot() throws {
        let ads = quiet { $0.adBreakIntervalSeconds = 120; $0.adBreakPrizes = [.coinsSeconds(60)] }
        #expect((try run(ads, profile: .max).sourceTotals["videos"] ?? 0) > 0)
        #expect((try run(ads, profile: .bare).sourceTotals["videos"] ?? 0) == 0)
    }
}

@Suite("El perfil .max")
struct PacingMaxProfileTests {
    private func shop(slots: Int = 0, supplier: Int = 0, spins: Int = 0) -> PacingSources {
        var sources = PacingSources.none
        sources.shop = ShopPermanents(extraSlots: slots, bestSupplierLevel: supplier, bonusDailyWheelSpins: spins)
        return sources
    }

    @Test(".max agranda los pisos y sólo .max lo hace")
    func maxExpandsFloors() throws {
        let sources = shop(slots: 5, supplier: 3, spins: 3)
        let maxed = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), profile: .max, sources: sources)
        let ads = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), profile: .ads, sources: sources)
        #expect(maxed.floorTable[0].capacity == 9)
        #expect(ads.floorTable[0].capacity == 4)
    }

    @Test("con lugares extra el bot llega más lejos en el mismo tiempo")
    func maxIsFaster() throws {
        let sources = shop(slots: 5)
        let ads = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), upgrades: upCheapLines(),
                                      profile: .ads, sources: sources).run(maxDays: 5)
        let maxed = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), upgrades: upCheapLines(),
                                        profile: .max, sources: sources).run(maxDays: 5)
        #expect(maxed.finalLifetimeEarnings > ads.finalLifetimeEarnings)
    }

    @Test("sin permanentes, .max juega igual que .ads")
    func maxWithoutShopIsAds() throws {
        let ads = try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                      profile: .ads, sources: .none).run(maxDays: 3)
        let maxed = try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                        profile: .max, sources: .none).run(maxDays: 3)
        #expect(fingerprint(maxed) == fingerprint(ads))
    }

    @Test("los giros de más son videos de más, y sólo con .max")
    func bonusSpinsAreVideos() throws {
        let wheel = WheelConfig(
            schemaVersion: 1, videoSpinsPerDay: 3, oroSpinCost: 1, oroSpinsPerDay: 0, spinSeconds: 1,
            chestFallbackSegmentId: "plata",
            segments: [.init(id: "plata", weight: 100, reward: .coinsSeconds(300))]
        )
        func videos(_ profile: PacingProfile) throws -> Double {
            var sources = shop(spins: 2)
            sources.ads = AdsSources(
                videoSeconds: 30, offlineMultiplier: 1, dailyMultiplier: 1, careerMultiplier: 1,
                wheel: wheel, wheelRepeats: false, treasures: nil, adBreakIntervalSeconds: .infinity,
                adBreakPrizes: [], mergeAllCooldownSeconds: 0, packageRainCooldownSeconds: 0, packageRain: nil
            )
            let report = try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                             profile: profile, sources: sources).run(maxDays: 1)
            return report.sourceTotals["videos"] ?? 0
        }
        #expect(try videos(.ads) == 3)
        #expect(try videos(.max) == 5)
    }

    @Test("el mejor proveedor mueve el r del paquete sólo con .max")
    func supplierShiftsPackages() throws {
        var sources = shop(supplier: 3)
        sources.packages = PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: 120, firstPackageAfterSeconds: 120,
                                          maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4])
        func run(_ profile: PacingProfile) throws -> PacingSimulator.Report {
            try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                profile: profile, sources: sources).run(maxDays: 5)
        }
        #expect(fingerprint(try run(.max)) != fingerprint(try run(.free)))
    }
}
