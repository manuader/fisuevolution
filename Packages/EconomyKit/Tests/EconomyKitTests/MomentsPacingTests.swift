import Foundation
import Testing
@testable import EconomyKit

/// Las ofertas del momento en el simulador (2.1 E15 F3-T4): el bot de un segmento las juega en el peor caso
/// (el brazo que más paga, cada vez que su estado da una pared de precio o el piso lleno y los topes lo
/// dejan). Apagadas —sin `moments`, sin segmento del jugador o con `base`— el simulador es el de la 2.0.
@Suite("Los momentos en el simulador")
struct MomentsPacingTests {
    private func wheel() -> WheelConfig {
        WheelConfig(
            schemaVersion: 1, videoSpinsPerDay: 2, blueSpinCost: 1, blueSpinsPerDay: 0, spinSeconds: 1,
            chestFallbackSegmentId: "plata",
            segments: [.init(id: "plata", weight: 3, reward: .coinsSeconds(300)),
                       .init(id: "giro", weight: 1, reward: .wheelSpin(1))]
        )
    }

    private func ads(moments: MomentsConfig?) -> AdsSources {
        var ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: wheel(), wheelRepeats: true, treasures: fxTreasures(),
            adBreakIntervalSeconds: 600,
            adBreakPrizes: [.coinsSeconds(600), .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 300), .package(1)],
            mergeAllCooldownSeconds: 600, packageRainCooldownSeconds: 3600, packageRain: .package(5),
            giftDoubles: true
        )
        ads.moments = moments
        return ads
    }

    private func sources(moments: MomentsConfig?) -> PacingSources {
        PacingSources(
            packages: PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: 300, firstPackageAfterSeconds: 300,
                                     maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4]),
            dailyMinutes: [5, 8, 12, 18, 25, 40, 15],
            freeBoosts: [.init(id: "fernet", cooldownSeconds: 3600, effect: .incomeBurst(multiplier: 3, seconds: 90))],
            freeHireSeconds: 120,
            freeMattress: fxTreasures(freeBoardIntervalSeconds: 1800),
            ads: ads(moments: moments),
            shop: ShopPermanents(extraSlots: 1, bestSupplierLevel: 1, bonusDailyWheelSpins: 1)
        )
    }

    /// La semilla de `moments.json`.
    static let seed = MomentsConfig(
        version: "seed-2026-10-16",
        thresholds: .seed,
        caps: .seed,
        arms: [
            .init(id: "pw_small", moment: "price_wall", reward: .grant(.coinsSeconds(300)), segments: ["low", "mid", "high"]),
            .init(id: "pw_big", moment: "price_wall", reward: .grant(.coinsSeconds(600)), segments: ["mid", "high"]),
            .init(id: "ff_merge", moment: "floor_full", reward: .mergeAll, segments: ["low", "mid", "high"]),
            .init(id: "control", moment: "*", control: true),
        ]
    )

    /// Una config donde casi toda contratación es una pared, para que los topes sean lo único que frena las
    /// ofertas. El umbral es una fracción de segundo de ingreso: en la fixture chica el ingreso crece mucho
    /// más rápido que los precios (la contratación sale de 1e-2 a 1e-6 segundos de ingreso) y el piso nunca
    /// se llena, así que con medio minuto no salía ninguna pared.
    static func eager(_ caps: MomentsConfig.Caps) -> MomentsConfig {
        var config = seed
        config.thresholds = NeedThresholds(priceWallMinutes: 1e-6, backOfflineMinutes: 120)
        config.caps = caps
        return config
    }

    private func run(
        _ profile: PacingProfile, moments: MomentsConfig?, player: PlayerSegment? = nil,
        segment: PacingSegment? = nil, days: Int = 8
    ) throws -> PacingSimulator.Report {
        try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                            profile: profile, sources: sources(moments: moments), segment: segment,
                            playerSegment: player).run(maxDays: days)
    }

    private static let profiles: [PacingProfile] = [.free, .ads, .max]

    @Test("apagados, el simulador es el de la 2.0: el reporte entero, campo a campo", arguments: profiles)
    func offIsTheBase(_ profile: PacingProfile) throws {
        let base = try run(profile, moments: nil)
        try expectSameReport(run(profile, moments: Self.seed), base, "con momentos y sin segmento del jugador")
        try expectSameReport(run(profile, moments: nil, player: .high), base, "sin momentos y con high")
        try expectSameReport(run(profile, moments: Self.seed, player: .base), base, "base nunca ve una oferta del momento")
        #expect(base.momentTurnWalls.isEmpty)
    }

    @Test("sin videos no hay ofertas del momento: .free con la semilla y high es .free")
    func freeNeverWatches() throws {
        let report = try run(.free, moments: Self.seed, player: .high)
        try expectSameReport(report, run(.free, moments: nil))
        #expect(report.sourceTotals["moments.accepted"] == nil)
    }

    @Test("con la semilla y high, Dios no llega más tarde que sin momentos", arguments: [PacingProfile.ads, .max])
    func highIsNotSlower(_ profile: PacingProfile) throws {
        let high = PacingSegment(acceptRate: PacingSegment.referenceAcceptRate(for: .high))
        let base = try #require(try run(profile, moments: nil, segment: high).godActive, "la fixture tiene que llegar a dios")
        let withMoments = try #require(try run(profile, moments: Self.seed, player: .high, segment: high).godActive)
        // El bot es codicioso y depende del camino: más plata puede reordenar una compra y mover Dios unos
        // segundos. El mismo margen de ruido que `PacingSegmentTests.biggerRewardsAreNotSlower` (0,5 %).
        #expect(withMoments <= base * 1.005, "con momentos \(withMoments) s vs sin \(base) s")
    }

    @Test("el peor caso cobra la oferta más grande: la plata del momento entra y cada una cuesta un video")
    func theWorstCasePays() throws {
        let caps = MomentsConfig.Caps(maxPerHour: 4, minSecondsBetween: 300, cooldownAfterDeclineSeconds: 600, maxPerSession: 8)
        let without = try run(.ads, moments: nil, days: 3)
        let report = try run(.ads, moments: Self.eager(caps), player: .high, days: 3)
        let accepted = try #require(report.sourceTotals["moments.accepted"], "con medio minuto de pared tiene que haber ofertas")
        #expect(accepted > 0)
        #expect(Double(report.momentTurnWalls.count) == accepted, "high acepta todas")
        #expect(try #require(report.sourceTotals["coins.moment"]) > 0)
        #expect((report.sourceTotals["videos"] ?? 0) > (without.sourceTotals["videos"] ?? 0))
    }

    @Test("los topes por hora y la espera entre ofertas se respetan en el reloj del sim")
    func capsHoldOnTheSimClock() throws {
        let caps = MomentsConfig.Caps(maxPerHour: 2, minSecondsBetween: 300, cooldownAfterDeclineSeconds: 600, maxPerSession: 8)
        let walls = try run(.ads, moments: Self.eager(caps), player: .high, days: 4).momentTurnWalls
        #expect(!walls.isEmpty)
        #expect(walls == walls.sorted())
        for (earlier, later) in zip(walls, walls.dropFirst()) {
            #expect(later - earlier >= 300, "dos ofertas a \(later - earlier) s")
        }
        for (index, start) in walls.enumerated() {
            let inHour = walls[index...].prefix { $0 - start < 3600 }.count
            #expect(inHour <= 2, "\(inHour) ofertas en la hora que arranca en \(start)")
        }
    }

    @Test("el tope por sesión se respeta en cada sesión del bot")
    func sessionCapHolds() throws {
        let caps = MomentsConfig.Caps(maxPerHour: 4, minSecondsBetween: 300, cooldownAfterDeclineSeconds: 600, maxPerSession: 1)
        let walls = try run(.ads, moments: Self.eager(caps), player: .high, days: 3).momentTurnWalls
        #expect(!walls.isEmpty)
        let offsets = PacingSimulator.HumanModel().sessionStartOffsets.sorted()
        let sessions = walls.map { wall -> Double in
            let dayStart = (wall / 86_400).rounded(.down) * 86_400
            return dayStart + (offsets.last { dayStart + $0 <= wall } ?? 0)
        }
        let perSession = Dictionary(grouping: sessions, by: { $0 }).mapValues(\.count)
        #expect(perSession.values.allSatisfy { $0 <= 1 }, "\(perSession)")
    }

    @Test("quien rechaza abre la espera: low rechaza ofertas y no le cuestan video")
    func lowDeclines() throws {
        let caps = MomentsConfig.Caps(maxPerHour: 4, minSecondsBetween: 300, cooldownAfterDeclineSeconds: 600, maxPerSession: 8)
        let low = PacingSegment(acceptRate: PacingSegment.referenceAcceptRate(for: .low))
        let report = try run(.ads, moments: Self.eager(caps), player: .low, segment: low, days: 3)
        let turns = Double(report.momentTurnWalls.count)
        let accepted = report.sourceTotals["moments.accepted"] ?? 0
        #expect(turns > 0)
        #expect(accepted < turns, "low (0,25) rechaza parte de las ofertas")
    }

    @Test("es determinístico: dos corridas con momentos dan el mismo reporte")
    func deterministic() throws {
        let mid = PacingSegment(acceptRate: PacingSegment.referenceAcceptRate(for: .mid))
        try expectSameReport(run(.ads, moments: Self.seed, player: .mid, segment: mid),
                             run(.ads, moments: Self.seed, player: .mid, segment: mid))
    }
}

// MARK: - El mismo reporte, campo a campo

/// Dos reportes iguales campo a campo, con los `Double` a 1e-9 relativo (el income se suma recorriendo
/// diccionarios cuyo orden cambia entre instancias). La misma vara que `PacingSegmentTests`.
private func expectSameReport(
    _ lhs: PacingSimulator.Report, _ rhs: PacingSimulator.Report, _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let difference = firstDifference(lhs, rhs, path: "report")
    #expect(difference == nil, "\(comment.map { "\($0): " } ?? "")difieren en \(difference ?? "")",
            sourceLocation: sourceLocation)
}

private func firstDifference(_ lhs: Any, _ rhs: Any, path: String) -> String? {
    if let a = lhs as? Double, let b = rhs as? Double {
        if a == b || (a.isNaN && b.isNaN) { return nil }
        return abs(a - b) <= 1e-9 * max(abs(a), abs(b)) ? nil : "\(path): \(a) vs \(b)"
    }
    let left = Mirror(reflecting: lhs), right = Mirror(reflecting: rhs)
    if left.children.isEmpty && right.children.isEmpty {
        return String(describing: lhs) == String(describing: rhs) ? nil : "\(path): \(lhs) vs \(rhs)"
    }
    guard left.children.count == right.children.count else {
        return "\(path): \(left.children.count) vs \(right.children.count) elementos"
    }
    if left.displayStyle == .dictionary {
        func entries(_ mirror: Mirror) -> [String: Any] {
            Dictionary(uniqueKeysWithValues: mirror.children.map { child in
                let pair = Array(Mirror(reflecting: child.value).children)
                return (String(describing: pair[0].value), pair[1].value)
            })
        }
        let rightEntries = entries(right)
        for (key, value) in entries(left) {
            guard let other = rightEntries[key] else { return "\(path)[\(key)]: falta" }
            if let difference = firstDifference(value, other, path: "\(path)[\(key)]") { return difference }
        }
        return nil
    }
    for (index, (a, b)) in zip(left.children, right.children).enumerated() {
        if let difference = firstDifference(a.value, b.value, path: "\(path).\(a.label ?? String(index))") {
            return difference
        }
    }
    return nil
}
