import Foundation
import Testing
@testable import EconomyKit

// MARK: - Reconciliador (F7 §3.1/⚠️10): run.units es lo canónico, la torre se
// reconstruye en CADA carga. Estas suites cubren colocación, overflow (auto-merge
// y descarte), sync de unlockedFloors y el drill de remapeo (§7) que justifica
// que el reconciliador exista.

@Suite("TowerReconciler: colocación")
struct TowerReconcilerPlacementTests {
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    @Test("cada tipo cae al piso de su tier y unitCounts == units")
    func basicPlacement() throws {
        var state = fxState(units: ["a": 2, "d": 1])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        // a (T1) vive en f1, d (T4) en f2; sin overflow no pasa nada más.
        #expect(fxSlots(of: "a", onFloor: 0, in: outcome.tower).count == 2)
        #expect(fxSlots(of: "d", onFloor: 1, in: outcome.tower).count == 1)
        #expect(state.run.units == ["a": 2, "d": 1])
        #expect(outcome.tower.unitCounts == state.run.units)
        #expect(outcome.autoMerged == 0)
        #expect(outcome.discarded.isEmpty)
    }

    @Test("dentro del piso, mayor tier primero: los mejores van a los primeros slots")
    func higherTierTakesFirstSlot() throws {
        var state = fxState(units: ["a": 1, "b": 1])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(outcome.tower.typeId(floorOrdinal: 0, slot: 0) == "b")
        #expect(outcome.tower.typeId(floorOrdinal: 0, slot: 1) == "a")
        #expect(outcome.tower.unitCounts == state.run.units)
    }

    @Test("tipos que ya no existen en la escalera se descartan con registro y salen de units")
    func unknownTypesAreDiscarded() throws {
        // "fantasma_v1" quedó de una config vieja: no rompe la carga, se anota y chau.
        var state = fxState(units: ["a": 1, "fantasma_v1": 3])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(outcome.discarded == ["fantasma_v1": 3])
        #expect(state.run.units == ["a": 1])
        #expect(outcome.tower.unitCounts == state.run.units)
    }

    @Test("un choice node guardado en units no es un tipo concreto: se descarta")
    func choiceNodeIsDiscarded() throws {
        var state = fxState(units: ["a": 1, "choice": 2])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(outcome.discarded == ["choice": 2])
        #expect(state.run.units == ["a": 1])
        #expect(outcome.tower.unitCounts == state.run.units)
    }
}

// MARK: - Overflow: primero auto-merge, después descarte de menor tier

@Suite("TowerReconciler: overflow y auto-merge")
struct TowerReconcilerOverflowTests {
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    @Test("overflow dentro del piso se resuelve auto-mergeando pares, sin descartar")
    func overflowAutoMergesWithinFloor() throws {
        // 8 a en capacity 5: 3 pares → b, quedan a:2 + b:3 = 5 justos.
        var state = fxState(units: ["a": 8])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.units == ["a": 2, "b": 3])
        #expect(outcome.autoMerged == 3)
        #expect(outcome.discarded.isEmpty)
        #expect(state.run.maxTierReached == 2)
        #expect(outcome.tower.floors[0].occupiedCount == 5)
        #expect(outcome.tower.unitCounts == state.run.units)
    }

    @Test("sin carrera elegida el choice bloquea el auto-merge y el sobrante de b se descarta")
    func crossFloorMergeBlockedWithoutCareer() throws {
        // b+b pide elección de carrera (MergeRules): sin chosenCareerPath no hay
        // merge legal, así que el overflow cae al descarte.
        var state = fxState(units: ["b": 12])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.units == ["b": 5])
        #expect(outcome.autoMerged == 0)
        #expect(outcome.discarded == ["b": 7])
        #expect(outcome.tower.floors[0].occupiedCount == 5)
        #expect(outcome.tower.unitCounts == state.run.units)
    }

    @Test("con carrera elegida los pares cruzan a f2 y el punto fijo cascadea el overflow")
    func crossFloorMergeWithCareerCascades() throws {
        // 6 pares b→c_law suben a f2 (f1 queda vacío); f2 queda 6/5 y la pasada
        // siguiente cascadea 1 par c_law→d hasta entrar en capacidad. Nada se pierde.
        var state = fxState(units: ["b": 12])
        state.run.chosenCareerPath = "law"
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.units == ["c_law": 4, "d": 1])
        #expect(outcome.autoMerged == 7)
        #expect(outcome.discarded.isEmpty)
        #expect(state.run.maxTierReached == 4)
        #expect(outcome.tower.floors[0].occupiedCount == 0)
        #expect(outcome.tower.floors[1].occupiedCount == 5)
        #expect(outcome.tower.unitCounts == state.run.units)
    }

    @Test("tier terminal sin merge posible: se descarta el excedente")
    func terminalOverflowDiscards() throws {
        var state = fxState(units: ["d": 6])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.units == ["d": 5])
        #expect(outcome.autoMerged == 0)
        #expect(outcome.discarded == ["d": 1])
        #expect(outcome.tower.unitCounts == state.run.units)
    }

    @Test("cuando hay que descartar, caen primero los de menor tier")
    func discardDropsLowestTierFirst() throws {
        // f2 con c_law:3 + d:4 = 7/5: 1 par c_law→d (impar, queda 1 suelto) y el
        // c_law huérfano —el menor tier del piso— es el que se descarta, no un d.
        var state = fxState(units: ["c_law": 3, "d": 4])
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.units == ["d": 5])
        #expect(outcome.autoMerged == 1)
        #expect(outcome.discarded == ["c_law": 1])
        #expect(outcome.tower.unitCounts == state.run.units)
    }
}

// MARK: - Sync de unlockedFloors (paso 4: aditivo, nunca quita)

@Suite("TowerReconciler: sync de unlockedFloors")
struct TowerReconcilerUnlockSyncTests {
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    @Test("el piso base siempre queda desbloqueado aunque el save venga vacío")
    func baseFloorAlwaysUnlocked() throws {
        var state = fxState(units: ["a": 1], unlockedFloors: [])
        TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.unlockedFloors == ["f1"])
    }

    @Test("un piso con unidades se desbloquea aunque el save no lo tuviera")
    func floorWithUnitsUnlocks() throws {
        var state = fxState(units: ["a": 1, "d": 1], unlockedFloors: [])
        TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.unlockedFloors == ["f1", "f2"])
    }

    @Test("maxTierReached ≥ unlockTier desbloquea el piso aunque hoy esté vacío")
    func reachedTierUnlocksEmptyFloor() throws {
        // Ya llegó a T3 alguna vez: f2 (unlockTier 3) se desbloquea sin habitantes.
        var state = fxState(units: ["a": 1], unlockedFloors: [])
        state.run.maxTierReached = 3
        TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.unlockedFloors == ["f1", "f2"])
    }

    @Test("la sincronización nunca quita pisos ya desbloqueados")
    func neverRemovesUnlockedFloors() throws {
        // f2 vacío y maxTier 1: igual se conserva, desbloquear es one-way.
        var state = fxState(units: ["a": 1], unlockedFloors: ["f1", "f2"])
        TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
        #expect(state.run.unlockedFloors == ["f1", "f2"])
    }
}

// MARK: - Drill de remapeo (spec §7): cambiar floors[] entre versiones NO rompe saves

@Suite("TowerReconciler: drill de remapeo")
struct TowerReconcilerRemapDrillTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// Run "vivida" con unidades repartidas por toda la escalera y los ids de
    /// pisos de la config VIEJA (f1/f2) en unlockedFloors.
    private func livedInState() -> PlayerState {
        fxState(units: ["a": 3, "b": 2, "c_prog": 1, "d": 1], unlockedFloors: ["f1", "f2"])
    }

    @Test("colapsar la torre a un solo piso recoloca todo sin pérdidas")
    func remapToSingleFloor() throws {
        var state = livedInState()
        let mono = try FloorTable(
            floors: [
                FloorDef(id: "mono", background: "unico", firstTier: 1, lastTier: 4, capacity: 20, incomeMultiplier: 1.0)
            ],
            maxTier: 4
        )
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: mono, tiers: tiers)
        // Con capacidad de sobra nada se mergea ni se pierde.
        #expect(state.run.units == ["a": 3, "b": 2, "c_prog": 1, "d": 1])
        #expect(outcome.autoMerged == 0)
        #expect(outcome.discarded.isEmpty)
        #expect(outcome.tower.unitCounts == state.run.units)
        #expect(outcome.tower.floors.count == 1)
        #expect(outcome.tower.floors[0].occupiedCount == 7)
        // El mejor tier va al slot 0; los ids viejos (f1/f2) se filtran del save.
        #expect(outcome.tower.typeId(floorOrdinal: 0, slot: 0) == "d")
        #expect(state.run.unlockedFloors == ["mono"])
    }

    @Test("expandir a un piso por tier reparte cada tipo a su piso nuevo")
    func remapToOneFloorPerTier() throws {
        var state = livedInState()
        let table = try FloorTable(
            floors: [
                FloorDef(id: "p1", background: "x", firstTier: 1, lastTier: 1, capacity: 5, incomeMultiplier: 1.0),
                FloorDef(id: "p2", background: "x", firstTier: 2, lastTier: 2, capacity: 5, incomeMultiplier: 1.0),
                FloorDef(id: "p3", background: "x", firstTier: 3, lastTier: 3, capacity: 5, incomeMultiplier: 1.0),
                FloorDef(id: "p4", background: "x", firstTier: 4, lastTier: 4, capacity: 5, incomeMultiplier: 1.0),
            ],
            maxTier: 4
        )
        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: table, tiers: tiers)
        #expect(state.run.units == ["a": 3, "b": 2, "c_prog": 1, "d": 1])
        #expect(outcome.autoMerged == 0)
        #expect(outcome.discarded.isEmpty)
        #expect(outcome.tower.unitCounts == state.run.units)
        #expect(fxSlots(of: "a", onFloor: 0, in: outcome.tower).count == 3)
        #expect(fxSlots(of: "b", onFloor: 1, in: outcome.tower).count == 2)
        #expect(fxSlots(of: "c_prog", onFloor: 2, in: outcome.tower).count == 1)
        #expect(fxSlots(of: "d", onFloor: 3, in: outcome.tower).count == 1)
        // Los pisos habitados quedan desbloqueados en orden de tabla nueva.
        #expect(state.run.unlockedFloors == ["p1", "p2", "p3", "p4"])
    }

    /// El caso que pide el spec §7 explícitamente: además de mover un tier de
    /// piso, la config nueva CORRE el `unlockTier`. Un piso que el jugador ya
    /// tenía abierto no se puede volver a cerrar (el desbloqueo se persiste por
    /// id, no se recalcula), y uno cuyo unlockTier bajó por debajo del progreso
    /// se abre solo.
    @Test("correr unlockTier no re-bloquea lo ganado y abre lo que corresponde")
    func remapWithShiftedUnlockTier() throws {
        var state = livedInState()
        state.run.maxTierReached = 3

        let shifted = try FloorTable(
            floors: [
                // f1 sigue cubriendo T1-2 pero ahora exige T2 para abrirse: el
                // jugador ya lo tenía, así que sigue abierto igual.
                FloorDef(
                    id: "f1", background: "alley", firstTier: 1, lastTier: 2,
                    capacity: 5, incomeMultiplier: 1.0, unlockTierOverride: 2
                ),
                // f2 exigía T3 (su firstTier); ahora exige T4, que el jugador NO
                // alcanzó. Pero tiene unidades ahí, así que se queda abierto.
                FloorDef(
                    id: "f2", background: "urban", firstTier: 3, lastTier: 3,
                    capacity: 5, incomeMultiplier: 1.0, unlockTierOverride: 4
                ),
                // Piso nuevo cuyo unlockTier (3) ya está alcanzado: se abre solo,
                // sin que el jugador haga nada.
                FloorDef(
                    id: "f3", background: "island", firstTier: 4, lastTier: 4,
                    capacity: 5, incomeMultiplier: 2.0, unlockTierOverride: 3
                ),
            ],
            maxTier: 4
        )

        let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: shifted, tiers: tiers)

        #expect(state.run.units == ["a": 3, "b": 2, "c_prog": 1, "d": 1])
        #expect(outcome.discarded.isEmpty)
        #expect(outcome.tower.unitCounts == state.run.units)
        // f2 conserva su desbloqueo pese a que su unlockTier nuevo (4) está por
        // encima del progreso; f3 entra por unlockTier alcanzado.
        #expect(state.run.unlockedFloors == ["f1", "f2", "f3"])
        // Y el remapeo movió a `d` (T4) del piso viejo f2 al f3 nuevo.
        #expect(fxSlots(of: "d", onFloor: 2, in: outcome.tower).count == 1)
        #expect(fxSlots(of: "c_prog", onFloor: 1, in: outcome.tower).count == 1)
    }
}
