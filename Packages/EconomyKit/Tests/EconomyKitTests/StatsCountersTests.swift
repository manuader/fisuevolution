import Foundation
import Testing
@testable import EconomyKit

// MARK: - Contadores históricos de `meta.stats` (choke points de EconomyKit)
//
// `meta.stats` es la materia prima de la pantalla de stats y de los logros, así
// que tiene que contar lo que el JUGADOR hizo, ni más ni menos:
//
// - Se incrementa DESPUÉS de los guards. Una acción que el guard rechaza no
//   ocurrió, y los tests de rechazo existentes comparan el `state` entero: un
//   contador que se moviera antes del guard los rompería a los dos.
// - El auto-merge de `TowerReconciler` NO cuenta. No pasa por `applyMerge` —
//   resuelve los pares por su cuenta— y ni siquiera recibe el `PlayerState`
//   entero, sólo `run`, así que no puede tocar `meta` aunque quisiera.

@Suite("Contadores: fusiones")
struct MergeCounterTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// Camino 1: el resultado se queda en el mismo piso (a + a → b).
    @Test func mergeInPlaceCountsOne() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 2])
        let slots = fxSlots(of: "a", onFloor: 0, in: tower)
        #expect(state.meta.stats.totalMergesEver == 0)

        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )

        #expect(state.meta.stats.totalMergesEver == 1)
    }

    /// Camino 2: el resultado asciende de piso (b + b → c_law, T3 vive en f2).
    @Test func mergeThatPromotesCountsOne() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["b": 2], unlockedFloors: ["f1"])
        state.run.chosenCareerPath = "law"
        let slots = fxSlots(of: "b", onFloor: 0, in: tower)

        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "c_law", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )

        #expect(state.meta.stats.totalMergesEver == 1)
    }

    /// Camino 3: el merge de una variante de carrera ya elegida (c_law + c_law → d).
    @Test func mergeAfterCareerChoiceCountsOne() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["c_law": 2])
        state.run.chosenCareerPath = "law"
        let slots = fxSlots(of: "c_law", onFloor: 1, in: tower)

        _ = try TowerActions.applyMerge(
            floorOrdinal: 1, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "d", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )

        #expect(state.meta.stats.totalMergesEver == 1)
    }

    /// El contador es acumulativo, no un flag: tres fusiones seguidas son tres.
    @Test func mergesAccumulate() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 4])
        let slots = fxSlots(of: "a", onFloor: 0, in: tower)

        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[2], targetSlot: slots[3],
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        let bSlots = fxSlots(of: "b", onFloor: 0, in: tower)
        state.run.chosenCareerPath = "law"
        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: bSlots[0], targetSlot: bSlots[1],
            newTypeId: "c_law", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )

        #expect(state.meta.stats.totalMergesEver == 3)
    }

    /// Piso destino lleno: el merge se bloquea y no muta NADA, contador incluido.
    @Test func mergeBlockedByFullDestinationDoesNotCount() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["b": 2, "c_law": 5])
        state.run.chosenCareerPath = "law"
        let slots = fxSlots(of: "b", onFloor: 0, in: tower)

        #expect(throws: TowerError.destinationFloorFull(floorId: "f2")) {
            try TowerActions.applyMerge(
                floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
                newTypeId: "c_law", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
            )
        }

        #expect(state.meta.stats.totalMergesEver == 0)
    }

    /// Slot inválido (el otro guard): tampoco cuenta.
    @Test func mergeWithInvalidSlotDoesNotCount() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1])
        let slot = try #require(fxSlot(of: "a", onFloor: 0, in: tower))
        let empty = try #require(tower.floors[0].firstFreeSlot())

        #expect(throws: TowerError.invalidSlot) {
            try TowerActions.applyMerge(
                floorOrdinal: 0, sourceSlot: slot, targetSlot: empty,
                newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
            )
        }

        #expect(state.meta.stats.totalMergesEver == 0)
    }

    /// El auto-merge del reconciliador es de la CARGA, no del jugador: resuelve
    /// los pares sin pasar por `applyMerge` y ni siquiera ve `meta`.
    @Test func reconcilerAutoMergeDoesNotCount() throws {
        let floorTable = try fxFloorTable()
        // f1 tiene capacity 5: seis "a" desbordan y el reconciliador auto-mergea.
        var state = fxState(units: ["a": 6])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)

        #expect(outcome.autoMerged > 0, "sin auto-merge el test no prueba nada")
        #expect(state.meta.stats.totalMergesEver == 0)
    }

    /// `meta` sobrevive a la reencarnación por construcción; el contador también.
    @Test func mergeCounterSurvivesReincarnation() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 2])
        let slots = fxSlots(of: "a", onFloor: 0, in: tower)
        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )

        state.run = .fresh(startTypeId: "a", startFloorId: "f1")

        #expect(state.meta.stats.totalMergesEver == 1)
    }
}

@Suite("Contadores: contrataciones")
struct HireCounterTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func makeQuote(on floorOrdinal: Int, state: PlayerState, floorTable: FloorTable) throws -> HireQuote {
        try #require(TowerActions.hireQuote(
            floorOrdinal: floorOrdinal, state: state, tiers: tiers,
            floorTable: floorTable, config: config, economy: economy
        ))
    }

    @Test func hireCountsTotalAndByType() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1])
        state.run.coins = 1_000
        #expect(state.meta.stats.totalHiresEver == 0)

        for _ in 0..<2 {
            let quote = try makeQuote(on: 0, state: state, floorTable: floorTable)
            _ = try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        }

        #expect(state.meta.stats.totalHiresEver == 2)
        // El conteo POR TIPO es la curva de la pantalla de laburos; el POR PISO,
        // el de la torre. Se llevan en paralelo y no se derivan uno del otro.
        #expect(state.run.hireCountsByType["a"] == 2)
        #expect(state.run.hireCounts["f1"] == 2)
    }

    @Test func rejectedHireDoesNotCount() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1])
        state.run.coins = 14  // el hire de f1 sale 15
        let quote = try makeQuote(on: 0, state: state, floorTable: floorTable)

        #expect(throws: TowerError.insufficientCoins) {
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        }

        #expect(state.meta.stats.totalHiresEver == 0)
        #expect(state.run.hireCountsByType.isEmpty)
    }

    /// El conteo por tipo es del tipo contratado, no del piso: dos pisos distintos
    /// que venden tipos distintos no se pisan la curva.
    @Test func hireCountsByTypeSeparatesTypes() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1, "c_law": 1])
        state.run.chosenCareerPath = "law"
        state.run.coins = 100_000

        let f1Quote = try makeQuote(on: 0, state: state, floorTable: floorTable)
        _ = try TowerActions.hire(quote: f1Quote, state: &state, tower: &tower, floorTable: floorTable)
        let f2Quote = try makeQuote(on: 1, state: state, floorTable: floorTable)
        _ = try TowerActions.hire(quote: f2Quote, state: &state, tower: &tower, floorTable: floorTable)

        #expect(state.meta.stats.totalHiresEver == 2)
        #expect(state.run.hireCountsByType["a"] == 1)
        #expect(state.run.hireCountsByType["c_law"] == 1)
    }
}
