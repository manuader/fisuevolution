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

@Suite("La ruleta: la tabla, los bordes")
struct WheelTableEdgesTests {
    private func table(_ segments: [WheelConfig.Segment]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: segments.map { ($0.id, $0.weight) })
    }

    @Test("con el cofre vacío sólo cambia el respaldo: el resto de la tabla queda como estaba")
    func onlyTheFallbackChanges() {
        let config = fxWheel()
        let effective = config.effectiveSegments(chestHasSomethingToGive: false)
        let expected = fxWheelSegments.filter { $0.id != "chest" }.map { ($0.id, $0.id == "coins_30" ? 23 : $0.weight) }
        #expect(effective.map(\.id) == expected.map(\.0))
        #expect(effective.map(\.weight) == expected.map(\.1))
    }

    @Test("el peso va al respaldo que dice el dato, no al primer segmento")
    func theWeightGoesToTheConfiguredFallback() {
        let config = fxWheel(chestFallbackSegmentId: "coins_45")
        let effective = table(config.effectiveSegments(chestHasSomethingToGive: false))
        #expect(effective["coins_45"] == 17)
        #expect(effective["coins_30"] == 18)
        #expect(effective.values.reduce(0, +) == WheelConfig.totalWeight)
    }

    @Test("con varios cofres, todos sus pesos se suman al respaldo")
    func everyChestWeightMoves() {
        var segments = fxWheelSegments
        segments[5] = .init(id: "chest_2", weight: 3, reward: .skinChest(2))
        let config = fxWheel(segments: segments)
        let effective = config.effectiveSegments(chestHasSomethingToGive: false)
        #expect(!effective.contains { $0.reward.kind == .skinChest })
        #expect(table(effective)["coins_30"] == 26)
        #expect(effective.map(\.weight).reduce(0, +) == WheelConfig.totalWeight)
    }

    @Test("sin ningún cofre en la tabla, vacío o no, es la misma tabla")
    func noChestSegmentsMeansNoChange() {
        let withoutChest = fxWheelSegments.filter { $0.id != "chest" }
        let config = fxWheel(segments: withoutChest)
        #expect(config.effectiveSegments(chestHasSomethingToGive: false) == withoutChest)
    }

    @Test("las probabilidades con el cofre vacío salen de la tabla que gira")
    func oddsFollowTheEffectiveTable() throws {
        let odds = fxWheel().odds(chestHasSomethingToGive: false)
        #expect(odds.count == 9)
        #expect(abs(try #require(odds.first { $0.id == "coins_30" }).probability - 0.23) < 1e-12)
        #expect(abs(try #require(odds.first { $0.id == "oro_3" }).probability - 0.05) < 1e-12)
    }

    @Test("ORO apagado (cero giros por día) es un dato válido")
    func zeroOroSpinsIsValid() throws {
        try fxWheel(oroSpinsPerDay: 0).validate()
    }

    @Test("la animación tiene que durar algo")
    func theSpinDurationIsChecked() {
        for seconds in [0.0, -1.0] {
            let config = WheelConfig(
                schemaVersion: 1,
                videoSpinsPerDay: 6,
                oroSpinCost: 12,
                oroSpinsPerDay: 6,
                spinSeconds: seconds,
                chestFallbackSegmentId: "coins_30",
                segments: fxWheelSegments
            )
            #expect(throws: WheelConfig.ValidationError.outOfRange("spinSeconds")) { try config.validate() }
        }
    }

    @Test("una tabla que pasa de 100 tampoco carga")
    func aHeavyTableIsRejected() {
        var heavy = fxWheelSegments
        heavy[0] = .init(id: "coins_30", weight: 19, reward: .coinsSeconds(1800))
        #expect(throws: WheelConfig.ValidationError.weightsMustSumTo100(101)) { try fxWheel(segments: heavy).validate() }
    }

    @Test("el respaldo del cofre no puede pagar otra cosa que plata")
    func theFallbackMustBeMoney() {
        for id in ["package", "income_x2", "chest"] {
            #expect(throws: WheelConfig.ValidationError.fallbackMustPayCoins, "con \(id)") {
                try fxWheel(chestFallbackSegmentId: id).validate()
            }
        }
    }
}

@Suite("La ruleta: el día y los giros, los bordes")
struct WheelStateEdgesTests {
    let config = fxWheel()

    @Test("sin día todavía, el primero se estrena sin perder los regalados")
    func theFirstDayKeepsTheGifts() {
        let fresh = WheelState(bonusSpins: 2)
        #expect(fresh.rolledOver(to: "2026-10-07") == WheelState(day: "2026-10-07", bonusSpins: 2))
    }

    @Test("sin día en ninguno de los dos no hay nada que resolver: queda el ganador")
    func undatedStatesKeepTheWinner() {
        let winner = WheelState(day: nil, videoSpinsUsed: 1, oroSpinsUsed: 0, bonusSpins: 1)
        let loser = WheelState(day: nil, videoSpinsUsed: 5, oroSpinsUsed: 3)
        #expect(WheelState.resolve(winner: winner, loser: loser) == winner)
    }

    @Test("lo regalado y el «repetir» viajan con el ganador; el cupo más alto puede ser el del perdedor")
    func theWinnerKeepsGiftsAndRepeat() {
        let winner = WheelState(day: "d", videoSpinsUsed: 4, oroSpinsUsed: 1, bonusSpins: 2, repeatableSegmentId: "oro_3")
        let loser = WheelState(day: "d", videoSpinsUsed: 2, oroSpinsUsed: 5, bonusSpins: 7, repeatableSegmentId: "package")
        #expect(WheelState.resolve(winner: winner, loser: loser) == WheelState(day: "d", videoSpinsUsed: 4, oroSpinsUsed: 5, bonusSpins: 2, repeatableSegmentId: "oro_3"))
    }

    @Test("un cupo que se achicó en el dato no deja giros negativos")
    func spinsLeftNeverGoesNegative() {
        let state = WheelState(day: "d", videoSpinsUsed: 9, oroSpinsUsed: 8, bonusSpins: -2)
        #expect(WheelRoller.spinsLeft(.video, state: state, config: config) == 0)
        #expect(WheelRoller.spinsLeft(.oro, state: state, config: config) == 0)
        #expect(WheelRoller.spinsLeft(.bonus, state: state, config: config) == 0)
    }

    @Test("sin cupo de ningún tipo, consumir no toca el estado")
    func consumingWithoutQuotaTouchesNothing() {
        var state = WheelState(day: "d", videoSpinsUsed: 9, oroSpinsUsed: 8, bonusSpins: -2)
        let before = state
        for source in WheelSpinSource.allCases {
            #expect(!WheelRoller.consume(source, state: &state, config: config))
        }
        #expect(state == before)
    }

    @Test("gastar uno con ORO sólo suma al cupo de ORO")
    func consumingOroOnlyTouchesOro() {
        var state = WheelState(day: "d", videoSpinsUsed: 2, oroSpinsUsed: 5, bonusSpins: 3)
        #expect(WheelRoller.consume(.oro, state: &state, config: config))
        #expect(state == WheelState(day: "d", videoSpinsUsed: 2, oroSpinsUsed: 6, bonusSpins: 3))
    }

    @Test("gastar uno por video sólo suma al cupo de video")
    func consumingVideoOnlyTouchesVideo() {
        var state = WheelState(day: "d", videoSpinsUsed: 2, oroSpinsUsed: 5, bonusSpins: 3)
        #expect(WheelRoller.consume(.video, state: &state, config: config))
        #expect(state == WheelState(day: "d", videoSpinsUsed: 3, oroSpinsUsed: 5, bonusSpins: 3))
    }

    @Test("la ruleta guardada vuelve igual, con todos sus campos")
    func theStateRoundTrips() throws {
        let state = WheelState(day: "2026-10-07", videoSpinsUsed: 3, oroSpinsUsed: 2, bonusSpins: 4, repeatableSegmentId: "oro_3")
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(WheelState.self, from: data) == state)
    }

    @Test("una ruleta con sólo el día decodifica con los cupos en cero")
    func aDayOnlyStateDecodesWithZeroes() throws {
        let state = try JSONDecoder().decode(WheelState.self, from: Data(#"{"day": "d"}"#.utf8))
        #expect(state == WheelState(day: "d", videoSpinsUsed: 0, oroSpinsUsed: 0, bonusSpins: 0, repeatableSegmentId: nil))
    }
}

@Suite("La ruleta: el sorteo, punto por punto")
struct WheelRollerPointsTests {
    @Test("cada punto del sorteo cae en el segmento que le toca de la tabla")
    func eachPointLandsOnItsSegment() throws {
        let segments = fxWheel().effectiveSegments(chestHasSomethingToGive: true)
        // acumulados: 18 30 38 52 60 63 78 83 95 100
        let expected: [(Double, String)] = [(0.0, "coins_30"), (0.25, "coins_45"), (0.5, "income_x2"), (0.8, "oro_3"), (0.97, "chest")]
        for (fraction, id) in expected {
            var rng = FixedPointRNG(fraction: fraction)
            let index = try #require(WheelRoller.roll(segments, using: &rng))
            #expect(segments[index].id == id, "en \(fraction)")
        }
    }
}
