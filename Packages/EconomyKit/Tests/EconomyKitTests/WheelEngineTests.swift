import Foundation
import Testing
@testable import EconomyKit

/// La tabla propuesta (duda 4): diez segmentos que suman 100.
let fxWheelSegments: [WheelConfig.Segment] = [
    .init(id: "coins_30", weight: 18, reward: .coinsSeconds(1800)),
    .init(id: "coins_45", weight: 12, reward: .coinsSeconds(2700)),
    .init(id: "coins_60", weight: 8, reward: .coinsSeconds(3600)),
    .init(id: "income_x2", weight: 14, reward: .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 600)),
    .init(id: "income_x3", weight: 8, reward: .modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 600)),
    .init(id: "income_x5", weight: 3, reward: .modifier(effect: .incomeMultiplier, magnitude: 5, seconds: 600)),
    .init(id: "oro_1", weight: 15, reward: .oro(1)),
    .init(id: "oro_3", weight: 5, reward: .oro(3)),
    .init(id: "package", weight: 12, reward: .package(1)),
    .init(id: "chest", weight: 5, reward: .skinChest(1)),
]

func fxWheel(
    videoSpinsPerDay: Int = 6,
    oroSpinCost: Int = 12,
    oroSpinsPerDay: Int = 6,
    chestFallbackSegmentId: String = "coins_30",
    segments: [WheelConfig.Segment] = fxWheelSegments
) -> WheelConfig {
    WheelConfig(
        schemaVersion: 1,
        videoSpinsPerDay: videoSpinsPerDay,
        oroSpinCost: oroSpinCost,
        oroSpinsPerDay: oroSpinsPerDay,
        spinSeconds: 3.8,
        chestFallbackSegmentId: chestFallbackSegmentId,
        segments: segments
    )
}

@Suite("La ruleta: la tabla")
struct WheelTableTests {
    @Test("los diez del plan validan y suman 100")
    func thePlanValidates() throws {
        try fxWheel().validate()
        #expect(fxWheel().segments.map(\.weight).reduce(0, +) == WheelConfig.totalWeight)
    }

    @Test("con el cofre lleno de pintas por dar, la tabla es la del dato")
    func aUsefulChestKeepsTheTable() {
        let config = fxWheel()
        #expect(config.effectiveSegments(chestHasSomethingToGive: true) == config.segments)
    }

    @Test("con el cofre vacío, su peso pasa a la plata y la tabla mostrada es la que gira")
    func anEmptyChestMovesItsWeightToCoins() throws {
        let config = fxWheel()
        let effective = config.effectiveSegments(chestHasSomethingToGive: false)
        #expect(!effective.contains { $0.reward.kind == .skinChest })
        #expect(try #require(effective.first { $0.id == "coins_30" }).weight == 23)
        #expect(effective.map(\.weight).reduce(0, +) == WheelConfig.totalWeight)
        #expect(config.odds(chestHasSomethingToGive: false).map(\.id) == effective.map(\.id))
    }

    @Test("las probabilidades son el peso sobre 100")
    func theOddsAreTheWeights() throws {
        let odds = fxWheel().odds(chestHasSomethingToGive: true)
        #expect(odds.count == 10)
        #expect(abs(try #require(odds.first { $0.id == "coins_30" }).probability - 0.18) < 1e-12)
        #expect(abs(try #require(odds.first { $0.id == "income_x5" }).probability - 0.03) < 1e-12)
    }

    @Test("una tabla que no suma 100, repetida o con un segmento sin peso no carga")
    func theTableIsChecked() {
        var short = fxWheelSegments
        short[0] = .init(id: "coins_30", weight: 17, reward: .coinsSeconds(1800))
        #expect(throws: WheelConfig.ValidationError.weightsMustSumTo100(99)) { try fxWheel(segments: short).validate() }
        var twice = fxWheelSegments
        twice[1] = .init(id: "coins_30", weight: 12, reward: .coinsSeconds(2700))
        #expect(throws: WheelConfig.ValidationError.duplicateSegment("coins_30")) { try fxWheel(segments: twice).validate() }
        var empty = fxWheelSegments
        empty[9] = .init(id: "chest", weight: 0, reward: .skinChest(1))
        #expect(throws: WheelConfig.ValidationError.badWeight("chest")) { try fxWheel(segments: empty).validate() }
    }

    @Test("un peso negativo no carga, aunque la suma dé 100")
    func aNegativeWeightIsRejected() {
        var negative = fxWheelSegments
        negative[0] = .init(id: "coins_30", weight: 28, reward: .coinsSeconds(1800))
        negative[9] = .init(id: "chest", weight: -5, reward: .skinChest(1))
        #expect(negative.map(\.weight).reduce(0, +) == WheelConfig.totalWeight)
        #expect(throws: WheelConfig.ValidationError.badWeight("chest")) { try fxWheel(segments: negative).validate() }
    }

    @Test("el respaldo del cofre tiene que existir y pagar plata")
    func theFallbackIsChecked() {
        #expect(throws: WheelConfig.ValidationError.unknownFallback("nope")) {
            try fxWheel(chestFallbackSegmentId: "nope").validate()
        }
        #expect(throws: WheelConfig.ValidationError.fallbackMustPayCoins) {
            try fxWheel(chestFallbackSegmentId: "oro_1").validate()
        }
    }

    @Test("un premio inválido o un cupo fuera de rango no cargan")
    func rewardsAndQuotasAreChecked() {
        var broken = fxWheelSegments
        broken[6] = .init(id: "oro_1", weight: 15, reward: .oro(0))
        #expect(throws: WheelConfig.ValidationError.invalidReward("oro_1")) { try fxWheel(segments: broken).validate() }
        #expect(throws: WheelConfig.ValidationError.outOfRange("videoSpinsPerDay")) { try fxWheel(videoSpinsPerDay: 0).validate() }
        #expect(throws: WheelConfig.ValidationError.outOfRange("oroSpinCost")) { try fxWheel(oroSpinCost: 0).validate() }
        #expect(throws: WheelConfig.ValidationError.outOfRange("oroSpinsPerDay")) { try fxWheel(oroSpinsPerDay: -1).validate() }
    }
}

@Suite("La ruleta: el día y los giros")
struct WheelStateTests {
    let config = fxWheel()

    @Test("un día nuevo devuelve los cupos, pierde el «repetir» y conserva los regalados")
    func aNewDayResetsTheQuotas() {
        let yesterday = WheelState(day: "2026-10-06", videoSpinsUsed: 6, oroSpinsUsed: 2, bonusSpins: 1, repeatableSegmentId: "oro_3")
        #expect(yesterday.rolledOver(to: "2026-10-07") == WheelState(day: "2026-10-07", videoSpinsUsed: 0, oroSpinsUsed: 0, bonusSpins: 1, repeatableSegmentId: nil))
    }

    @Test("el mismo día no cambia nada")
    func theSameDayKeepsEverything() {
        let today = WheelState(day: "2026-10-07", videoSpinsUsed: 3, oroSpinsUsed: 1, bonusSpins: 0, repeatableSegmentId: "package")
        #expect(today.rolledOver(to: "2026-10-07") == today)
    }

    @Test("quedan 6 por video, 6 con ORO y los regalados")
    func spinsLeftPerSource() {
        let state = WheelState(day: "d", videoSpinsUsed: 2, oroSpinsUsed: 5, bonusSpins: 3)
        #expect(WheelRoller.spinsLeft(.video, state: state, config: config) == 4)
        #expect(WheelRoller.spinsLeft(.oro, state: state, config: config) == 1)
        #expect(WheelRoller.spinsLeft(.bonus, state: state, config: config) == 3)
    }

    @Test("gastar uno descuenta de su fuente; sin cupo no se gasta")
    func consumingSpendsFromItsSource() {
        var state = WheelState(day: "d", videoSpinsUsed: 5, oroSpinsUsed: 6, bonusSpins: 1)
        #expect(WheelRoller.consume(.video, state: &state, config: config))
        #expect(!WheelRoller.consume(.video, state: &state, config: config))
        #expect(!WheelRoller.consume(.oro, state: &state, config: config))
        #expect(WheelRoller.consume(.bonus, state: &state, config: config))
        #expect(state == WheelState(day: "d", videoSpinsUsed: 6, oroSpinsUsed: 6, bonusSpins: 0))
    }

    @Test("al resolver un conflicto del mismo día, los cupos usados se quedan con lo más alto")
    func resolvingKeepsTheDailyQuotas() {
        let winner = WheelState(day: "d", videoSpinsUsed: 1, oroSpinsUsed: 4, bonusSpins: 2)
        let loser = WheelState(day: "d", videoSpinsUsed: 5, oroSpinsUsed: 0, bonusSpins: 0)
        #expect(WheelState.resolve(winner: winner, loser: loser) == WheelState(day: "d", videoSpinsUsed: 5, oroSpinsUsed: 4, bonusSpins: 2))
        let otherDay = WheelState(day: "c", videoSpinsUsed: 6, oroSpinsUsed: 6)
        #expect(WheelState.resolve(winner: winner, loser: otherDay) == winner)
    }

    @Test("una ruleta escrita antes de E5 decodifica vacía")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(WheelState.self, from: Data("{}".utf8)) == .initial)
        let partial = try JSONDecoder().decode(WheelState.self, from: Data(#"{"day": "d", "bonusSpins": 2}"#.utf8))
        #expect(partial == WheelState(day: "d", bonusSpins: 2))
    }
}

@Suite("La ruleta: el sorteo")
struct WheelRollerTests {
    @Test("el sorteo sigue la tabla efectiva, y sin cofre no sale cofre")
    func theRollFollowsTheEffectiveTable() throws {
        var rng = SeededRNG(seed: 7)
        let segments = fxWheel().effectiveSegments(chestHasSomethingToGive: false)
        let draws = 20_000
        var coins30 = 0
        for _ in 0..<draws {
            let index = try #require(WheelRoller.roll(segments, using: &rng))
            #expect(segments[index].reward.kind != .skinChest)
            if segments[index].id == "coins_30" { coins30 += 1 }
        }
        let share = Double(coins30) / Double(draws)
        #expect(share > 0.215 && share < 0.245, "coins_30 salió \(share)")
    }

    @Test("sin segmentos no hay giro")
    func noSegmentsNoSpin() {
        var rng = SeededRNG(seed: 1)
        #expect(WheelRoller.roll([], using: &rng) == nil)
    }
}
