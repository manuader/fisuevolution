import Testing
@testable import EconomyKit

/// RF-03: la lista de mejoras se arma con los tipos VISTOS en la run, no con las
/// unidades vivas. Mergear tu último Fisura no puede borrarte de la pantalla la
/// mejora que le compraste y que te sigue rindiendo.
@Suite struct SeenTypesTests {
    private func fxState() -> PlayerState {
        PlayerState.newGame(
            startTypeId: "a",
            startFloorId: "f1",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 0
        )
    }

    @Test("un tipo visto queda registrado aunque no quede ninguna unidad viva")
    func seenSurvivesTheLastUnit() {
        var state = fxState()
        state.run.units["b"] = 2
        state.markSeen("b")
        state.run.units["b"] = nil
        #expect(state.run.seenTypes.contains("b"))
    }

    @Test("el tipo base ya está visto en una run recién nacida")
    func freshRunSeesTheBaseType() {
        let state = fxState()
        #expect(state.run.seenTypes == ["a"])
    }

    @Test("reencarnar borra los vistos salvo el tipo base")
    func reincarnationResetsSeen() {
        var state = fxState()
        state.markSeen("b")
        state.markSeen("c_prog")
        state.run = .fresh(startTypeId: "a", startFloorId: "f1")
        #expect(state.run.seenTypes == ["a"])
    }

    @Test("un save viejo sin el campo recupera los vistos de sus unidades vivas")
    func reconcileBackfillsSeenFromLiveUnits() throws {
        var state = fxState()
        // Simula el save v4 anterior al campo: decodifica con `seenTypes` vacío.
        state.run.seenTypes = []
        state.run.units = ["a": 2, "b": 1]
        TowerReconciler.reconcile(
            run: &state.run,
            floorTable: try fxFloorTable(),
            tiers: try fxTiers()
        )
        #expect(state.run.seenTypes.isSuperset(of: ["a", "b"]))
    }

    @Test("contratar y mergear dejan registrado el tipo nuevo")
    func hireAndMergeMarkSeen() throws {
        let config = fxConfig()
        let tiers = try fxTiers()
        let floorTable = try fxFloorTable(config: config)
        var state = fxState()
        state.run.seenTypes = ["a"]
        state.run.units = [:]
        var tower = TowerState(floorTable: floorTable)

        state.run.coins = 1_000_000
        let quote = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: floorTable,
            config: config, economy: StandardEconomy(config: config)
        ))
        let first = try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        let second = try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        #expect(state.run.seenTypes.contains(quote.type.id))

        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: first.slot, targetSlot: second.slot,
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        #expect(state.run.seenTypes.contains("b"))
    }
}
