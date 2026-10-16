import Foundation
import Testing
@testable import EconomyKit

/// El colchón gratis del tablero (E14b B31, D20): cada 30 minutos de reloj real cae uno, también con
/// el juego cerrado; guarda uno solo y el reloj arranca de nuevo al abrirlo.
@Suite("El colchón gratis: el reloj real")
struct FreeMattressClockTests {
    let config = fxTreasures(freeBoardIntervalSeconds: 1800)
    let start = 1_760_000_000.0

    /// El reloj ya arrancado en `start`, sin uno esperando.
    private func running() -> TreasuresState {
        TreasuresState(freeBoard: FreeBoardMattress(clockStartedAt: start))
    }

    @Test("una partida nueva arranca el reloj al cargar y el primero cae a los 30 minutos, no antes")
    func theFirstOneTakesThirtyMinutes() {
        var state = TreasuresState.initial
        #expect(!FreeMattressClock.advance(&state, now: start, config: config))
        #expect(state.freeBoard.clockStartedAt == start, "arrancó al cargar")
        #expect(!FreeMattressClock.advance(&state, now: start + 1799.9, config: config))
        #expect(!state.freeBoard.waiting)
        #expect(FreeMattressClock.advance(&state, now: start + 1800, config: config))
        #expect(state.freeBoard.waiting)
    }

    @Test("con el juego cerrado el reloj sigue: al volver horas después espera uno solo")
    func itRunsWhileClosedAndKeepsOne() {
        var state = running()
        #expect(FreeMattressClock.advance(&state, now: start + 5 * 3600, config: config))
        #expect(state.freeBoard.waiting)
        for later in [start + 5 * 3600, start + 6 * 3600, start + 48 * 3600] {
            let before = state
            #expect(!FreeMattressClock.advance(&state, now: later, config: config), "nunca se acumulan")
            #expect(state == before)
        }
    }

    @Test("el reloj arranca de nuevo al abrirlo, no cuando cayó")
    func theClockRestartsWhenOpened() {
        var state = running()
        #expect(FreeMattressClock.advance(&state, now: start + 1800, config: config))
        let opened = start + 3 * 3600
        #expect(FreeMattressClock.markOpened(&state, now: opened))
        #expect(!state.freeBoard.waiting)
        #expect(state.freeBoard.clockStartedAt == opened)
        #expect(!FreeMattressClock.advance(&state, now: opened + 1799, config: config))
        #expect(FreeMattressClock.advance(&state, now: opened + 1800, config: config))
    }

    @Test("abrir sin uno esperando no hace nada")
    func openingNothingDoesNothing() {
        var state = running()
        #expect(!FreeMattressClock.markOpened(&state, now: start + 100))
        #expect(state == running(), "ni rearma el reloj")
    }

    @Test("si la hora del teléfono vuelve para atrás, el reloj arranca de nuevo y no se traba")
    func aClockGoingBackRestarts() {
        var state = running()
        #expect(!FreeMattressClock.advance(&state, now: start - 600, config: config))
        #expect(state.freeBoard.clockStartedAt == start - 600)
        #expect(FreeMattressClock.advance(&state, now: start - 600 + 1800, config: config))
    }

    @Test("sin el reloj en el dato no cae ninguno, ni arranca")
    func noIntervalNoMattress() {
        var state = TreasuresState.initial
        let off = fxTreasures(freeBoardIntervalSeconds: 0)
        #expect(!FreeMattressClock.advance(&state, now: start, config: off))
        #expect(!FreeMattressClock.advance(&state, now: start + 100 * 3600, config: off))
        #expect(state == .initial)
    }

    @Test("es independiente del ciclo de 12 minutos: el de la columna en juego no lo frena")
    func theColumnDoesNotStopIt() {
        for phase in [TreasuresState.Phase.waiting, .onBoard] {
            var state = running()
            state.phase = phase
            state.secondsUntilNext = 40
            #expect(FreeMattressClock.advance(&state, now: start + 1800, config: config), "con el de la columna \(phase)")
            #expect(state.phase == phase && state.secondsUntilNext == 40, "no toca al de la columna")
        }
    }

    @Test("y el gratis esperando no frena ni toca al reloj de la columna")
    func itDoesNotStopTheColumn() {
        var state = running()
        #expect(FreeMattressClock.advance(&state, now: start + 1800, config: config))
        state.freeBoard.land(onFloor: 1, at: PackageSpot(x: 0.4, y: 0.2))
        let free = state.freeBoard
        state.secondsUntilNext = 10
        #expect(TreasureScheduler.advance(&state, delta: 10, config: config), "el de la columna aparece igual")
        #expect(state.phase == .waiting)
        #expect(state.freeBoard == free, "el gratis sigue donde estaba")
        #expect(TreasureScheduler.markPaid(&state))
        #expect(TreasureScheduler.markOpened(&state, config: config))
        #expect(state.freeBoard == free, "abrir el de la columna no abre el gratis")
        #expect(FreeMattressClock.markOpened(&state, now: start + 4000))
        #expect(state.phase == .none && state.extraOpensLeft == config.extraOpensPerTreasure,
                "abrir el gratis no toca al de la columna ni su «otro colchón»")
    }
}

@Suite("El colchón gratis: su lugar en el tablero")
struct FreeMattressPlacementTests {
    @Test("el que cae no tiene lugar todavía; sólo el que espera se ubica, y abrirlo lo olvida")
    func onlyTheWaitingOneHasASpot() {
        var idle = FreeBoardMattress(clockStartedAt: 0)
        idle.land(onFloor: 2, at: PackageSpot(x: 0.3, y: 0.2))
        #expect(idle.floor == nil && idle.spot == nil && !idle.needsPlacement)

        var state = TreasuresState(freeBoard: FreeBoardMattress(clockStartedAt: 0))
        #expect(FreeMattressClock.advance(&state, now: 1800, config: fxTreasures()))
        #expect(state.freeBoard.needsPlacement)
        state.freeBoard.land(onFloor: 2, at: PackageSpot(x: 0.3, y: 0.2))
        #expect(!state.freeBoard.needsPlacement)
        #expect(state.freeBoard.floor == 2 && state.freeBoard.spot == PackageSpot(x: 0.3, y: 0.2))
        #expect(FreeMattressClock.markOpened(&state, now: 2000))
        #expect(state.freeBoard.floor == nil && state.freeBoard.spot == nil)
    }

    @Test("uno que cae de nuevo no hereda el lugar viejo")
    func aNewOneIsPlacedFromScratch() {
        var state = TreasuresState(freeBoard: FreeBoardMattress(clockStartedAt: 0, floor: 1, spot: PackageSpot(x: 0.5, y: 0.1)))
        #expect(FreeMattressClock.advance(&state, now: 1800, config: fxTreasures()))
        #expect(state.freeBoard.floor == nil && state.freeBoard.needsPlacement)
    }
}

@Suite("El colchón gratis: el save (sin cambiar la versión)")
struct FreeMattressSaveTests {
    private func decode(_ json: String) throws -> TreasuresState {
        try JSONDecoder().decode(TreasuresState.self, from: Data(json.utf8))
    }

    @Test("ida y vuelta: el reloj, el que espera y su lugar")
    func roundTrip() throws {
        let states = [
            TreasuresState(secondsUntilNext: 30, phase: .onBoard, extraOpensLeft: 1, floor: 0,
                           spot: PackageSpot(x: 0.6, y: 0.3),
                           freeBoard: FreeBoardMattress(clockStartedAt: 1_760_000_000, waiting: true, floor: 2,
                                                        spot: PackageSpot(x: 0.2, y: 0.1))),
            TreasuresState(freeBoard: FreeBoardMattress(clockStartedAt: 1_760_000_123.5)),
            TreasuresState.initial,
        ]
        for state in states {
            #expect(try JSONDecoder().decode(TreasuresState.self, from: JSONEncoder().encode(state)) == state)
        }
    }

    @Test("un save anterior a B31 carga sin el gratis y su reloj arranca al cargar")
    func anOldSaveStartsTheClockOnLoad() throws {
        var old = try decode(#"{"secondsUntilNext": 120, "phase": "waiting", "extraOpensLeft": 0}"#)
        #expect(old.freeBoard == FreeBoardMattress())
        #expect(old.phase == .waiting && old.secondsUntilNext == 120, "el de la columna, igual")
        let now = 1_760_000_000.0
        #expect(!FreeMattressClock.advance(&old, now: now, config: fxTreasures()))
        #expect(old.freeBoard.clockStartedAt == now)
    }

    @Test("el de regalo de antes de B31 que estaba en el tablero pasa a ser el gratis, en su lugar")
    func theOldGiftBecomesTheFreeOne() throws {
        let old = try decode(#"{"secondsUntilNext": 720, "phase": "onBoard", "gifted": true, "extraOpensLeft": 0, "floor": 1, "x": 0.4, "y": 0.2}"#)
        #expect(old.phase == .none, "la columna queda libre y su reloj corre")
        #expect(old.floor == nil && old.spot == nil)
        #expect(old.secondsUntilNext == 720)
        #expect(old.freeBoard.waiting)
        #expect(old.freeBoard.floor == 1 && old.freeBoard.spot == PackageSpot(x: 0.4, y: 0.2))
        let unplaced = try decode(#"{"phase": "onBoard", "gifted": true}"#)
        #expect(unplaced.freeBoard.waiting && unplaced.freeBoard.needsPlacement, "sin lugar, se ubica al cargar")
    }

    @Test("la marca vieja sin el colchón en el tablero no inventa uno")
    func aStaleGiftMarkInventsNothing() throws {
        for phase in ["none", "waiting"] {
            let state = try decode(#"{"phase": "\#(phase)", "gifted": true}"#)
            #expect(!state.freeBoard.waiting, "en \(phase)")
            #expect(state.phase.rawValue == phase)
        }
    }

    @Test("la marca vieja ya no se escribe")
    func theGiftMarkIsNoLongerWritten() throws {
        let data = try JSONEncoder().encode(TreasuresState(phase: .onBoard, freeBoard: FreeBoardMattress(waiting: true)))
        let written = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(written["gifted"] == nil)
        #expect(written["freeBoard"] != nil)
    }
}

@Suite("El colchón gratis: el dato y su tabla")
struct FreeMattressConfigTests {
    private let coinsOnly: [TreasuresConfig.Prize] = [.init(id: "coins", weight: 1, rewards: [.coinsSeconds(600)])]

    @Test("el reloj negativo o infinito no carga; cero es válido (apagado)")
    func theIntervalIsChecked() throws {
        for bad in [-1.0, .infinity, .nan] {
            #expect(throws: TreasuresConfig.ValidationError.outOfRange("freeBoardIntervalSeconds")) {
                try fxTreasures(freeBoardIntervalSeconds: bad).validate()
            }
        }
        try fxTreasures(freeBoardIntervalSeconds: 0).validate()
        try fxTreasures(freeBoardIntervalSeconds: 1800).validate()
    }

    @Test("sin tabla propia sortea con la de la columna; con la suya, con la suya")
    func itsOwnTableOrTheColumnOne() throws {
        let shared = fxTreasures()
        #expect(shared.freePrizes == shared.prizes)
        #expect(shared.freeOdds == shared.odds)
        let own = fxTreasures(freeBoardPrizes: coinsOnly)
        #expect(own.freePrizes == coinsOnly)
        #expect(own.freeOdds.map(\.id) == ["coins"])
        #expect(own.odds.map(\.id) == ["coins", "package", "blue"], "la de la columna no cambia")
        for fraction in [0.0, 0.5, 0.99] {
            var rng = FixedPointRNG(fraction: fraction)
            #expect(try #require(TreasureRoller.rollFree(own, using: &rng)).id == "coins")
            var free = FixedPointRNG(fraction: fraction)
            var column = FixedPointRNG(fraction: fraction)
            #expect(TreasureRoller.rollFree(shared, using: &free) == TreasureRoller.roll(shared, using: &column),
                    "sin tabla propia, el mismo premio en \(fraction)")
        }
    }

    @Test("la tabla propia se valida como la otra")
    func itsTableIsValidated() {
        #expect(throws: TreasuresConfig.ValidationError.noPrizes) {
            try fxTreasures(freeBoardPrizes: []).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.invalidReward("x")) {
            try fxTreasures(freeBoardPrizes: [.init(id: "x", weight: 1, rewards: [.coinsSeconds(0)])]).validate()
        }
    }

    @Test("la tabla propia viaja en el dato; un dato sin ella carga con la de la columna")
    func theTableDecodes() throws {
        let config = fxTreasures(freeBoardPrizes: coinsOnly)
        #expect(try JSONDecoder().decode(TreasuresConfig.self, from: JSONEncoder().encode(config)) == config)
        let json = #"{"schemaVersion":1,"spawnIntervalSeconds":720,"firstTreasureAfterSeconds":480,"extraOpensPerTreasure":1,"freeBoardIntervalSeconds":1800,"prizes":[{"id":"x","weight":1,"rewards":[{"kind":"blue","amount":1}]}]}"#
        let plain = try JSONDecoder().decode(TreasuresConfig.self, from: Data(json.utf8))
        #expect(plain.freeBoardIntervalSeconds == 1800)
        #expect(plain.freeBoardPrizes == nil && plain.freePrizes == plain.prizes)
    }
}

/// Pedido del dueño (2026-10-16): los dos colchones siguen la dinámica de la caja (B18/B22). Son de UN
/// piso, caen en un lugar de su superficie, el save guarda piso y lugar, y se quedan ahí: mirar otro
/// piso no los mueve.
@Suite("Los colchones son de un piso, como las cajas")
struct MattressFloorTests {
    private let home = PackageSpot(x: 0.3, y: 0.2)

    private func roundTrip(_ state: TreasuresState) throws -> TreasuresState {
        try JSONDecoder().decode(TreasuresState.self, from: JSONEncoder().encode(state))
    }

    @Test("el de la columna, ya ubicado, no se mueve al aterrizar en otro piso; el save guarda su piso")
    func theColumnOneStaysOnItsFloor() throws {
        var state = TreasuresState(phase: .onBoard)
        state.land(onFloor: 2, at: home)
        for floor in [0, 1, 3, 2] {
            state.land(onFloor: floor, at: PackageSpot(x: 0.9, y: 0.4))
            #expect(state.floor == 2 && state.spot == home, "mirando el piso \(floor)")
        }
        let back = try roundTrip(state)
        var loaded = back
        loaded.land(onFloor: 0, at: PackageSpot(x: 0.1, y: 0.1))
        #expect(loaded.floor == 2 && loaded.spot == home, "cargado, sigue en su piso")
    }

    @Test("el gratis, ya ubicado, tampoco; el save guarda su piso y su lugar")
    func theFreeOneStaysOnItsFloor() throws {
        var state = TreasuresState(freeBoard: FreeBoardMattress(clockStartedAt: 0))
        #expect(FreeMattressClock.advance(&state, now: 1800, config: fxTreasures()))
        state.freeBoard.land(onFloor: 4, at: home)
        for floor in [0, 1, 2] {
            state.freeBoard.land(onFloor: floor, at: PackageSpot(x: 0.9, y: 0.4))
            #expect(state.freeBoard.floor == 4 && state.freeBoard.spot == home, "mirando el piso \(floor)")
        }
        var back = try roundTrip(state)
        #expect(back.freeBoard.floor == 4 && back.freeBoard.spot == home)
        back.freeBoard.land(onFloor: 0, at: PackageSpot(x: 0.1, y: 0.1))
        #expect(back.freeBoard.floor == 4, "cargado, sigue en su piso")
    }

    @Test("los relojes no los mueven: correr el tiempo deja a cada uno en su piso")
    func theClocksLeaveThemAlone() {
        var state = TreasuresState(secondsUntilNext: 10, phase: .onBoard, floor: 1, spot: home,
                                   freeBoard: FreeBoardMattress(clockStartedAt: 0, waiting: true, floor: 3, spot: home))
        #expect(!TreasureScheduler.advance(&state, delta: 10_000, config: fxTreasures()))
        #expect(!FreeMattressClock.advance(&state, now: 99_999, config: fxTreasures()))
        #expect(state.floor == 1 && state.freeBoard.floor == 3)
    }

    @Test("un save viejo sin piso pide ubicarse (en el piso visible al cargar); reubicar es olvidar y aterrizar")
    func anOldSaveWithoutAFloorGetsPlaced() throws {
        var old = try JSONDecoder().decode(TreasuresState.self, from: Data(#"{"phase":"onBoard"}"#.utf8))
        #expect(old.needsPlacement)
        old.land(onFloor: 1, at: home)
        #expect(old.floor == 1 && !old.needsPlacement)
        old.clearPlacement()
        old.land(onFloor: 0, at: home)
        #expect(old.floor == 0, "su piso se cerró: se olvida y cae en otro")
    }
}
