import Foundation
import Testing
@testable import EconomyKit

/// `treasures.json` sintético, con la tabla del plan (60 / 25 / 15).
func fxTreasures(
    spawnIntervalSeconds: Double = 480,
    firstTreasureAfterSeconds: Double = 480,
    extraOpensPerTreasure: Int = 1,
    prizes: [TreasuresConfig.Prize] = [
        .init(id: "coins", weight: 60, rewards: [.coinsSeconds(1200)]),
        .init(id: "package", weight: 25, rewards: [.package(1)]),
        .init(id: "oro", weight: 15, rewards: [.oro(2)]),
    ]
) -> TreasuresConfig {
    TreasuresConfig(
        schemaVersion: 1,
        spawnIntervalSeconds: spawnIntervalSeconds,
        firstTreasureAfterSeconds: firstTreasureAfterSeconds,
        extraOpensPerTreasure: extraOpensPerTreasure,
        prizes: prizes
    )
}

@Suite("El Colchón: el reloj")
struct TreasureSchedulerTests {
    let config = fxTreasures()

    @Test("aparece a los 8 minutos de juego")
    func itAppearsAfterEightMinutes() {
        var state = TreasuresState.initial
        #expect(!TreasureScheduler.advance(&state, delta: 479, config: config))
        #expect(TreasureScheduler.advance(&state, delta: 1, config: config))
        #expect(state.waiting)
    }

    @Test("no se acumula: con uno esperando el reloj no corre")
    func oneAtATime() {
        var state = TreasuresState(secondsUntilNext: 5, waiting: true, extraOpensLeft: 0)
        #expect(!TreasureScheduler.advance(&state, delta: 10_000, config: config))
        #expect(state == TreasuresState(secondsUntilNext: 5, waiting: true, extraOpensLeft: 0))
    }

    @Test("abrirlo habilita «otro colchón» y rearma el reloj")
    func openingArmsTheExtra() {
        var state = TreasuresState(secondsUntilNext: 480, waiting: true, extraOpensLeft: 0)
        TreasureScheduler.markOpened(&state, config: config)
        #expect(!state.waiting)
        #expect(state.extraOpensLeft == 1)
        #expect(state.secondsUntilNext == 480)
    }

    @Test("uno nuevo se lleva el «otro colchón» que quedó sin usar")
    func aNewOneDropsTheUnusedExtra() {
        var state = TreasuresState(secondsUntilNext: 1, waiting: false, extraOpensLeft: 1)
        #expect(TreasureScheduler.advance(&state, delta: 1, config: config))
        #expect(state.extraOpensLeft == 0)
    }

    @Test("un colchón escrito antes de E5 decodifica vacío")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(TreasuresState.self, from: Data("{}".utf8)) == .initial)
        let partial = try JSONDecoder().decode(TreasuresState.self, from: Data(#"{"waiting": true}"#.utf8))
        #expect(partial == TreasuresState(secondsUntilNext: nil, waiting: true, extraOpensLeft: 0))
    }
}

@Suite("El Colchón: qué trae")
struct TreasureRollerTests {
    @Test("la tabla visible es la del sorteo")
    func theVisibleTableIsTheDrawnOne() {
        let odds = fxTreasures().odds
        #expect(odds.map(\.id) == ["coins", "package", "oro"])
        #expect(odds.map(\.probability) == [0.6, 0.25, 0.15])
    }

    @Test("el sorteo respeta la tabla")
    func theRollFollowsTheTable() throws {
        var rng = SeededRNG(seed: 42)
        let config = fxTreasures()
        let draws = 10_000
        var coins = 0
        for _ in 0..<draws {
            if try #require(TreasureRoller.roll(config, using: &rng)).id == "coins" { coins += 1 }
        }
        let share = Double(coins) / Double(draws)
        #expect(share > 0.58 && share < 0.62, "la plata salió \(share)")
    }

    @Test("sin premios no hay sorteo")
    func noPrizesNoDraw() {
        var rng = SeededRNG(seed: 1)
        #expect(TreasureRoller.roll(fxTreasures(prizes: []), using: &rng) == nil)
    }
}

@Suite("El Colchón: el dato")
struct TreasuresConfigTests {
    @Test("la tabla del plan valida")
    func thePlanValidates() throws {
        try fxTreasures().validate()
    }

    @Test("relojes y extras fuera de rango no cargan")
    func rangesAreChecked() {
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("spawnIntervalSeconds")) {
            try fxTreasures(spawnIntervalSeconds: 0).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("extraOpensPerTreasure")) {
            try fxTreasures(extraOpensPerTreasure: -1).validate()
        }
    }

    @Test("un premio sin peso, vacío, repetido o inválido no carga")
    func prizesAreChecked() {
        #expect(throws: TreasuresConfig.ValidationError.noPrizes) { try fxTreasures(prizes: []).validate() }
        #expect(throws: TreasuresConfig.ValidationError.badWeight("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 0, rewards: [.oro(1)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.badWeight("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: -3, rewards: [.oro(1)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.emptyPrize("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.duplicatePrize("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [.oro(1)]), .init(id: "x", weight: 1, rewards: [.oro(2)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.invalidReward("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [.coinsSeconds(0)])]).validate()
        }
    }
}

/// Un sorteo que cae siempre en el mismo punto de la tabla (`fraction` de 0 a
/// casi 1), para saber QUÉ salió y no sólo cuánto. `Double.random` sólo mira
/// los 53 bits bajos del número que le da el generador.
struct FixedPointRNG: RandomNumberGenerator {
    let fraction: Double

    mutating func next() -> UInt64 {
        UInt64(fraction * Double(UInt64(1) << 53))
    }
}

@Suite("El Colchón: el reloj con tiempos distintos")
struct TreasureClockEdgesTests {
    let config = fxTreasures(spawnIntervalSeconds: 600, firstTreasureAfterSeconds: 300, extraOpensPerTreasure: 2)

    @Test("el primero espera su propio plazo, no el intervalo, y el reloj va descontando")
    func theFirstOneUsesItsOwnDelay() {
        var state = TreasuresState.initial
        #expect(!TreasureScheduler.advance(&state, delta: 299, config: config))
        #expect(state.secondsUntilNext == 1)
        #expect(TreasureScheduler.advance(&state, delta: 1, config: config))
    }

    @Test("al aparecer queda esperando, sin extras y con el reloj rearmado al intervalo")
    func appearingRearmsTheClock() {
        var state = TreasuresState(secondsUntilNext: 10, waiting: false, extraOpensLeft: 2)
        #expect(TreasureScheduler.advance(&state, delta: 4_000, config: config))
        #expect(state == TreasuresState(secondsUntilNext: 600, waiting: true, extraOpensLeft: 0))
    }

    @Test("sin tiempo transcurrido, o con tiempo negativo, el reloj no se mueve")
    func nonPositiveDeltaDoesNothing() {
        var fresh = TreasuresState.initial
        #expect(!TreasureScheduler.advance(&fresh, delta: 0, config: config))
        #expect(fresh == .initial)
        var running = TreasuresState(secondsUntilNext: 100, waiting: false, extraOpensLeft: 0)
        #expect(!TreasureScheduler.advance(&running, delta: -500, config: config))
        #expect(running == TreasuresState(secondsUntilNext: 100, waiting: false, extraOpensLeft: 0))
    }

    @Test("abrirlo deja de esperar, da los extras del dato y rearma el reloj al intervalo")
    func openingUsesTheConfigValues() {
        var state = TreasuresState(secondsUntilNext: 5, waiting: true, extraOpensLeft: 0)
        TreasureScheduler.markOpened(&state, config: config)
        #expect(state == TreasuresState(secondsUntilNext: 600, waiting: false, extraOpensLeft: 2))
    }

    @Test("después de abrir, el siguiente tarda un intervalo entero")
    func theNextOneTakesAFullInterval() {
        var state = TreasuresState(secondsUntilNext: 5, waiting: true, extraOpensLeft: 0)
        TreasureScheduler.markOpened(&state, config: config)
        #expect(!TreasureScheduler.advance(&state, delta: 599, config: config))
        #expect(TreasureScheduler.advance(&state, delta: 1, config: config))
    }

    @Test("el estado guardado vuelve igual")
    func theStateRoundTrips() throws {
        let state = TreasuresState(secondsUntilNext: 12.5, waiting: true, extraOpensLeft: 2)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(TreasuresState.self, from: data) == state)
    }
}

@Suite("El Colchón: qué sale en cada punto de la tabla")
struct TreasureRollerPointsTests {
    @Test("cada punto del sorteo cae en su premio (60 / 25 / 15)")
    func eachPointLandsOnItsPrize() throws {
        let config = fxTreasures()
        for (fraction, expected) in [(0.0, "coins"), (0.3, "coins"), (0.7, "package"), (0.99, "oro")] {
            var rng = FixedPointRNG(fraction: fraction)
            #expect(try #require(TreasureRoller.roll(config, using: &rng)).id == expected, "en \(fraction)")
        }
    }
}

@Suite("El Colchón: el dato, los bordes")
struct TreasuresConfigEdgesTests {
    @Test("el primero tiene que tardar algo")
    func theFirstDelayIsChecked() {
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("firstTreasureAfterSeconds")) {
            try fxTreasures(firstTreasureAfterSeconds: 0).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("firstTreasureAfterSeconds")) {
            try fxTreasures(firstTreasureAfterSeconds: -5).validate()
        }
    }

    @Test("el intervalo negativo no carga")
    func aNegativeIntervalIsRejected() {
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("spawnIntervalSeconds")) {
            try fxTreasures(spawnIntervalSeconds: -1).validate()
        }
    }

    @Test("sin «otro colchón» (cero extras) es un dato válido")
    func zeroExtraOpensIsValid() throws {
        try fxTreasures(extraOpensPerTreasure: 0).validate()
    }

    @Test("un premio con varias recompensas las valida a todas, no sólo la primera")
    func everyRewardOfAPrizeIsChecked() {
        let prize = TreasuresConfig.Prize(id: "x", weight: 1, rewards: [.oro(1), .coinsSeconds(0)])
        #expect(throws: TreasuresConfig.ValidationError.invalidReward("x")) {
            try fxTreasures(prizes: [prize]).validate()
        }
    }

    @Test("un premio repetido se rechaza aunque el resto esté bien")
    func aRepeatedPrizeIsRejectedAmongOthers() {
        let prizes: [TreasuresConfig.Prize] = [
            .init(id: "a", weight: 1, rewards: [.oro(1)]),
            .init(id: "b", weight: 1, rewards: [.oro(1)]),
            .init(id: "a", weight: 1, rewards: [.oro(1)]),
        ]
        #expect(throws: TreasuresConfig.ValidationError.duplicatePrize("a")) {
            try fxTreasures(prizes: prizes).validate()
        }
    }
}
