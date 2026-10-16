import Foundation
import Testing
@testable import EconomyKit

/// `treasures.json` sintético, con la tabla del plan (60 / 25 / 15).
func fxTreasures(
    spawnIntervalSeconds: Double = 480,
    firstTreasureAfterSeconds: Double = 480,
    extraOpensPerTreasure: Int = 1,
    freeBoardIntervalSeconds: Double = 1800,
    prizes: [TreasuresConfig.Prize] = [
        .init(id: "coins", weight: 60, rewards: [.coinsSeconds(1200)]),
        .init(id: "package", weight: 25, rewards: [.package(1)]),
        .init(id: "blue", weight: 15, rewards: [.blue(2)]),
    ],
    freeBoardPrizes: [TreasuresConfig.Prize]? = nil
) -> TreasuresConfig {
    TreasuresConfig(
        schemaVersion: 1,
        spawnIntervalSeconds: spawnIntervalSeconds,
        firstTreasureAfterSeconds: firstTreasureAfterSeconds,
        extraOpensPerTreasure: extraOpensPerTreasure,
        freeBoardIntervalSeconds: freeBoardIntervalSeconds,
        prizes: prizes,
        freeBoardPrizes: freeBoardPrizes
    )
}

/// El reloj de la columna: `true` si apareció uno.
@discardableResult
func advanceTreasure(_ state: inout TreasuresState, delta: Double, config: TreasuresConfig) -> Bool {
    TreasureScheduler.advance(&state, delta: delta, config: config)
}

@Suite("El Colchón: el reloj")
struct TreasureSchedulerTests {
    let config = fxTreasures()

    @Test("aparece a los 8 minutos de juego, en la columna")
    func itAppearsAfterEightMinutes() {
        var state = TreasuresState.initial
        #expect(!advanceTreasure(&state, delta: 479, config: config))
        #expect(advanceTreasure(&state, delta: 1, config: config))
        #expect(state.phase == .waiting)
    }

    @Test("no se acumula: con uno en la columna o en el tablero el reloj no corre")
    func oneAtATime() {
        for phase in [TreasuresState.Phase.waiting, .onBoard] {
            var state = TreasuresState(secondsUntilNext: 5, phase: phase, extraOpensLeft: 0)
            #expect(!advanceTreasure(&state, delta: 10_000, config: config))
            #expect(state == TreasuresState(secondsUntilNext: 5, phase: phase, extraOpensLeft: 0), "en \(phase)")
        }
    }

    @Test("abrir el del tablero habilita «otro colchón» y rearma el reloj")
    func openingArmsTheExtra() {
        var state = TreasuresState(secondsUntilNext: 480, phase: .onBoard, extraOpensLeft: 0)
        #expect(TreasureScheduler.markOpened(&state, config: config))
        #expect(state.phase == .none)
        #expect(state.extraOpensLeft == 1)
        #expect(state.secondsUntilNext == 480)
    }

    @Test("uno nuevo se lleva el «otro colchón» que quedó sin usar")
    func aNewOneDropsTheUnusedExtra() {
        var state = TreasuresState(secondsUntilNext: 1, phase: .none, extraOpensLeft: 1)
        #expect(advanceTreasure(&state, delta: 1, config: config))
        #expect(state.extraOpensLeft == 0)
    }

    @Test("un colchón escrito antes de E5 decodifica vacío")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(TreasuresState.self, from: Data("{}".utf8)) == .initial)
    }
}

@Suite("El Colchón: el recorrido columna → video → tablero → abierto (E14b B6)")
struct TreasureJourneyTests {
    let config = fxTreasures()

    @Test("el video de la columna lo hace caer al tablero; sólo si esperaba")
    func payingDropsItOnTheBoard() {
        var state = TreasuresState(secondsUntilNext: 480, phase: .waiting, extraOpensLeft: 0)
        #expect(TreasureScheduler.markPaid(&state))
        #expect(state == TreasuresState(secondsUntilNext: 480, phase: .onBoard, extraOpensLeft: 0))
        #expect(!TreasureScheduler.markPaid(&state), "ya está en el tablero: no se paga dos veces")
        var empty = TreasuresState(secondsUntilNext: 100, phase: .none, extraOpensLeft: 1)
        #expect(!TreasureScheduler.markPaid(&empty))
        #expect(empty == TreasuresState(secondsUntilNext: 100, phase: .none, extraOpensLeft: 1))
    }

    @Test("sólo se abre el del tablero: el de la columna pide su video primero")
    func onlyTheBoardOneOpens() {
        var waiting = TreasuresState(secondsUntilNext: 5, phase: .waiting, extraOpensLeft: 0)
        #expect(!TreasureScheduler.markOpened(&waiting, config: config))
        #expect(waiting == TreasuresState(secondsUntilNext: 5, phase: .waiting, extraOpensLeft: 0))
        var none = TreasuresState(secondsUntilNext: 5, phase: .none, extraOpensLeft: 0)
        #expect(!TreasureScheduler.markOpened(&none, config: config))
        #expect(none.extraOpensLeft == 0, "abrir la nada no regala «otro colchón»")
    }

    @Test("sin el «1 de cada 4» (D4 se fue con B31): todos aparecen en la columna, pidiendo su video")
    func everyOneAppearsInTheColumn() {
        for _ in 0..<100 {
            var state = TreasuresState(secondsUntilNext: 1)
            #expect(advanceTreasure(&state, delta: 1, config: config))
            #expect(state.phase == .waiting)
        }
    }

    @Test("el recorrido entero: aparece, se paga, cae, se abre y el reloj vuelve a correr")
    func theWholeJourney() {
        var state = TreasuresState.initial
        #expect(advanceTreasure(&state, delta: 480, config: config))
        #expect(!advanceTreasure(&state, delta: 10_000, config: config))
        #expect(TreasureScheduler.markPaid(&state))
        #expect(!advanceTreasure(&state, delta: 10_000, config: config), "en el tablero tampoco corre")
        #expect(TreasureScheduler.markOpened(&state, config: config))
        #expect(state == TreasuresState(secondsUntilNext: 480, phase: .none, extraOpensLeft: 1))
        #expect(!advanceTreasure(&state, delta: 479, config: config))
        #expect(advanceTreasure(&state, delta: 1, config: config))
    }
}

@Suite("El Colchón: el save del recorrido (migración E14b B6)")
struct TreasureStateMigrationTests {
    private func decode(_ json: String) throws -> TreasuresState {
        try JSONDecoder().decode(TreasuresState.self, from: Data(json.utf8))
    }

    @Test("un save anterior a B6 con uno esperando lo deja en la columna, pidiendo su video")
    func theOldWaitingOneStaysInTheColumn() throws {
        #expect(try decode(#"{"waiting": true, "secondsUntilNext": 30, "extraOpensLeft": 0}"#)
            == TreasuresState(secondsUntilNext: 30, phase: .waiting, extraOpensLeft: 0))
        #expect(try decode(#"{"waiting": false, "extraOpensLeft": 1}"#)
            == TreasuresState(secondsUntilNext: nil, phase: .none, extraOpensLeft: 1))
    }

    @Test("cada fase vuelve igual del save")
    func everyPhaseRoundTrips() throws {
        for phase in [TreasuresState.Phase.none, .waiting, .onBoard] {
            let state = TreasuresState(secondsUntilNext: 12.5, phase: phase, extraOpensLeft: 2)
            #expect(try JSONDecoder().decode(TreasuresState.self, from: JSONEncoder().encode(state)) == state)
        }
    }

    @Test("un save anterior a B29 no trae la marca del regalo: el del tablero es el de la columna")
    func noGiftMarkStaysInTheColumnJourney() throws {
        let state = try decode(#"{"phase": "onBoard"}"#)
        #expect(state.phase == .onBoard)
        #expect(!state.freeBoard.waiting)
    }

    @Test("la fase manda sobre el `waiting` viejo, y uno desconocido no tira el save")
    func thePhaseWins() throws {
        #expect(try decode(#"{"phase": "onBoard", "waiting": true}"#).phase == .onBoard)
        #expect(try decode(#"{"phase": "none", "waiting": true}"#).phase == .none)
        #expect(try decode(#"{"phase": "enElTecho", "waiting": true}"#).phase == .waiting)
    }

    @Test("una versión anterior que lea el save sigue viendo el colchón en juego")
    func theOldKeyIsStillWritten() throws {
        func written(_ phase: TreasuresState.Phase) throws -> Bool? {
            let data = try JSONEncoder().encode(TreasuresState(secondsUntilNext: 1, phase: phase))
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["waiting"] as? Bool
        }
        #expect(try written(.none) == false)
        #expect(try written(.waiting) == true)
        #expect(try written(.onBoard) == true)
    }

    @Test("`giftOneIn` ya no existe: un dato viejo que lo trae carga igual y no lo vuelve a escribir")
    func theGiftKnobIsGone() throws {
        let json = #"{"schemaVersion":1,"spawnIntervalSeconds":720,"firstTreasureAfterSeconds":480,"extraOpensPerTreasure":1,"giftOneIn":4,"prizes":[{"id":"x","weight":1,"rewards":[{"kind":"blue","amount":1}]}]}"#
        let config = try JSONDecoder().decode(TreasuresConfig.self, from: Data(json.utf8))
        try config.validate()
        let written = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        #expect(written["giftOneIn"] == nil)
        #expect(config.freeBoardIntervalSeconds == 0, "sin el reloj del gratis en el dato, no cae ninguno")
    }
}

@Suite("El Colchón: qué trae")
struct TreasureRollerTests {
    @Test("la tabla visible es la del sorteo")
    func theVisibleTableIsTheDrawnOne() {
        let odds = fxTreasures().odds
        #expect(odds.map(\.id) == ["coins", "package", "blue"])
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
            try fxTreasures(prizes: [.init(id: "x", weight: 0, rewards: [.blue(1)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.badWeight("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: -3, rewards: [.blue(1)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.emptyPrize("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.duplicatePrize("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [.blue(1)]), .init(id: "x", weight: 1, rewards: [.blue(2)])]).validate()
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
        #expect(!advanceTreasure(&state, delta: 299, config: config))
        #expect(state.secondsUntilNext == 1)
        #expect(advanceTreasure(&state, delta: 1, config: config))
    }

    @Test("al aparecer queda en la columna, sin extras y con el reloj rearmado al intervalo")
    func appearingRearmsTheClock() {
        var state = TreasuresState(secondsUntilNext: 10, phase: .none, extraOpensLeft: 2)
        #expect(advanceTreasure(&state, delta: 4_000, config: config))
        #expect(state == TreasuresState(secondsUntilNext: 600, phase: .waiting, extraOpensLeft: 0))
    }

    @Test("sin tiempo transcurrido, o con tiempo negativo, el reloj no se mueve")
    func nonPositiveDeltaDoesNothing() {
        var fresh = TreasuresState.initial
        #expect(!advanceTreasure(&fresh, delta: 0, config: config))
        #expect(fresh == .initial)
        var running = TreasuresState(secondsUntilNext: 100, phase: .none, extraOpensLeft: 0)
        #expect(!advanceTreasure(&running, delta: -500, config: config))
        #expect(running == TreasuresState(secondsUntilNext: 100, phase: .none, extraOpensLeft: 0))
    }

    @Test("abrirlo deja el tablero, da los extras del dato y rearma el reloj al intervalo")
    func openingUsesTheConfigValues() {
        var state = TreasuresState(secondsUntilNext: 5, phase: .onBoard, extraOpensLeft: 0)
        TreasureScheduler.markOpened(&state, config: config)
        #expect(state == TreasuresState(secondsUntilNext: 600, phase: .none, extraOpensLeft: 2))
    }

    @Test("después de abrir, el siguiente tarda un intervalo entero")
    func theNextOneTakesAFullInterval() {
        var state = TreasuresState(secondsUntilNext: 5, phase: .onBoard, extraOpensLeft: 0)
        TreasureScheduler.markOpened(&state, config: config)
        #expect(!advanceTreasure(&state, delta: 599, config: config))
        #expect(advanceTreasure(&state, delta: 1, config: config))
    }

    @Test("el estado guardado vuelve igual")
    func theStateRoundTrips() throws {
        let state = TreasuresState(secondsUntilNext: 12.5, phase: .waiting, extraOpensLeft: 2)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(TreasuresState.self, from: data) == state)
    }
}

@Suite("El Colchón: qué sale en cada punto de la tabla")
struct TreasureRollerPointsTests {
    @Test("cada punto del sorteo cae en su premio (60 / 25 / 15)")
    func eachPointLandsOnItsPrize() throws {
        let config = fxTreasures()
        for (fraction, expected) in [(0.0, "coins"), (0.3, "coins"), (0.7, "package"), (0.99, "blue")] {
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
        let prize = TreasuresConfig.Prize(id: "x", weight: 1, rewards: [.blue(1), .coinsSeconds(0)])
        #expect(throws: TreasuresConfig.ValidationError.invalidReward("x")) {
            try fxTreasures(prizes: [prize]).validate()
        }
    }

    @Test("un premio repetido se rechaza aunque el resto esté bien")
    func aRepeatedPrizeIsRejectedAmongOthers() {
        let prizes: [TreasuresConfig.Prize] = [
            .init(id: "a", weight: 1, rewards: [.blue(1)]),
            .init(id: "b", weight: 1, rewards: [.blue(1)]),
            .init(id: "a", weight: 1, rewards: [.blue(1)]),
        ]
        #expect(throws: TreasuresConfig.ValidationError.duplicatePrize("a")) {
            try fxTreasures(prizes: prizes).validate()
        }
    }
}

@Suite("El «otro colchón» guardado en el save")
struct TreasureExtraSaveTests {
    @Test("el «otro colchón» pendiente viaja en el save y un save viejo sin el campo carga en cero")
    func roundTripAndOldSave() throws {
        let saved = TreasuresState(secondsUntilNext: 300, phase: .none, extraOpensLeft: 1)
        let back = try JSONDecoder().decode(TreasuresState.self, from: JSONEncoder().encode(saved))
        #expect(back == saved)
        let old = try JSONDecoder().decode(TreasuresState.self, from: Data(#"{"secondsUntilNext":120,"waiting":false}"#.utf8))
        #expect(old.extraOpensLeft == 0)
    }

    @Test("un reset borra el «otro colchón» pendiente")
    func resetClearsIt() {
        var current = fxState(units: ["a": 1])
        current.meta.engagement.treasures = TreasuresState(secondsUntilNext: 300, phase: .none, extraOpensLeft: 1)
        let plan = ResetPlan.make(current: current, fresh: fxState(units: [:]))
        #expect(plan.result.meta.engagement.treasures == .initial)
    }
}

@Suite("Un modificador desconocido no tira el save")
struct LossyModifierTests {
    @Test("el efecto que no se conoce se descarta y el resto del save carga")
    func unknownEffectIsDropped() throws {
        var state = fxState(units: ["a": 1])
        state.run.activeModifiers = [ActiveModifier(effect: .eventImmunity, magnitude: 1, expiresAt: 100, sourceKey: "k")]
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var run = try #require(json["run"] as? [String: Any])
        var mods = try #require(run["activeModifiers"] as? [[String: Any]])
        var unknown = mods[0]
        unknown["effect"] = "unknownX"
        mods.append(unknown)
        run["activeModifiers"] = mods
        json["run"] = run
        let back = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(back.run.activeModifiers.count == 1)
        #expect(back.run.activeModifiers.first?.effect == .eventImmunity)
    }
}

@Suite("El colchón del tablero tiene piso y lugar (E14b B24)")
struct TreasurePlacementTests {
    let config = fxTreasures()

    @Test("cae en un piso y un lugar, viaja en el save, y un save sin ellos pide ubicarlo")
    func landsAndRoundTrips() throws {
        var state = TreasuresState(secondsUntilNext: 300, phase: .onBoard)
        #expect(state.needsPlacement)
        state.land(onFloor: 2, at: PackageSpot(x: 0.3, y: 0.2))
        #expect(!state.needsPlacement)
        #expect(state.floor == 2 && state.spot == PackageSpot(x: 0.3, y: 0.2))
        let back = try JSONDecoder().decode(TreasuresState.self, from: JSONEncoder().encode(state))
        #expect(back == state)
        let old = try JSONDecoder().decode(TreasuresState.self, from: Data(#"{"phase":"onBoard"}"#.utf8))
        #expect(old.needsPlacement, "el de un save anterior a B24 se ubica al cargar")
    }

    @Test("en la columna no tiene lugar; abierto o reemplazado, lo olvida")
    func onlyTheBoardOneHasASpot() {
        var waiting = TreasuresState(phase: .waiting)
        waiting.land(onFloor: 1, at: PackageSpot(x: 0.5, y: 0.5))
        #expect(waiting.floor == nil && waiting.spot == nil)
        #expect(!waiting.needsPlacement)

        var opened = TreasuresState(secondsUntilNext: 1, phase: .onBoard, floor: 1, spot: PackageSpot(x: 0.5, y: 0.5))
        #expect(TreasureScheduler.markOpened(&opened, config: config))
        #expect(opened.floor == nil && opened.spot == nil)

        var stale = TreasuresState(secondsUntilNext: 1, phase: .none, floor: 1, spot: PackageSpot(x: 0.5, y: 0.5))
        #expect(advanceTreasure(&stale, delta: 1, config: config))
        #expect(stale.floor == nil && stale.spot == nil, "el nuevo, en la columna, no hereda el lugar viejo")
    }
}

@Suite("Lo que respeta una caja: el colchón y la mitad de atrás (E14b B24)")
struct PackageAreaClearanceTests {
    @Test("nada cae a menos de una separación de un lugar ocupado")
    func keepsClearOfASpot() {
        let area = PackageFloorArea(gapX: 0.2, gapY: 0.3).keepingClear(of: PackageSpot(x: 0.5, y: 0.5))
        #expect(PackagePlacer.crowding(of: PackageSpot(x: 0.55, y: 0.6), among: [], in: area) >= 1)
        #expect(PackagePlacer.crowding(of: PackageSpot(x: 0.9, y: 0.5), among: [], in: area) == 0)
        let flat = PackageFloorArea(gapX: 0.2, gapY: .infinity).keepingClear(of: PackageSpot(x: 0.5, y: 0))
        #expect(PackagePlacer.crowding(of: PackageSpot(x: 0.55, y: 1), among: [], in: flat) >= 1, "sin fondo separa el costado")
    }

    @Test("con la mitad de atrás prohibida, el lugar sale adelante")
    func keepsToTheFront() {
        let area = PackageFloorArea(gapX: 0.1, gapY: 0.1).keepingToTheFront(0.5...1)
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            #expect(PackagePlacer.place(among: [], in: area, using: &rng).y < 0.5)
        }
    }
}
