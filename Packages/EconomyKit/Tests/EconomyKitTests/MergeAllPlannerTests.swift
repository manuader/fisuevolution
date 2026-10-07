import Foundation
import Testing
@testable import EconomyKit

@Suite("Fusionar todo: el plan del piso")
struct MergeAllPlannerTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func plan(_ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable), floor: Int = 0) -> [BoardChange] {
        BoardChangePlanner.planMergeAll(
            floorOrdinal: floor, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .debug
        )
    }

    @Test("funde todos los pares del piso, de abajo para arriba, y lo que sale vuelve a contar")
    func mergesEveryPairInAChain() throws {
        var fx = try fxStateAndTower(units: ["a": 4])
        fx.state.run.chosenCareerPath = "prog"
        #expect(plan(fx).map(\.resultTypeId) == ["b", "b", "c_prog"])
    }

    @Test("con dos pares a la vez, funde primero el de tier más bajo")
    func lowestTierFirst() throws {
        var fx = try fxStateAndTower(units: ["a": 2, "b": 2])
        fx.state.run.chosenCareerPath = "prog"
        #expect(plan(fx).map(\.resultTypeId) == ["b", "c_prog"])
    }

    @Test("sin carrera elegida no toca el par que la pide")
    func neverTheCareerPair() throws {
        #expect(plan(try fxStateAndTower(units: ["a": 4])).map(\.resultTypeId) == ["b", "b"])
    }

    @Test("sin lugar arriba no planea el ascenso")
    func noRoomUpstairs() throws {
        var fx = try fxStateAndTower(units: ["b": 2, "d": 5])
        fx.state.run.chosenCareerPath = "prog"
        #expect(plan(fx).isEmpty)
    }

    @Test("aplicado en orden deja el piso sin pares y no toca los otros pisos")
    func applyingThePlanLeavesNoPairs() throws {
        var fx = try fxStateAndTower(units: ["a": 3, "c_prog": 2])
        fx.state.run.chosenCareerPath = "prog"
        for change in plan(fx) {
            _ = try BoardChangeApplier.apply(change, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable)
        }
        let pairs = Dictionary(grouping: fx.tower.placements(onFloor: 0), by: \.typeId).filter { $0.value.count >= 2 }
        #expect(pairs.isEmpty)
        #expect(fx.state.run.units["c_prog"] == 2)
    }

    @Test("cada cambio tiene su id y lleva el origen pedido")
    func changesAreDistinctAndKeepTheirOrigin() throws {
        let changes = plan(try fxStateAndTower(units: ["a": 4]))
        #expect(Set(changes.map(\.id)).count == changes.count)
        #expect(changes.allSatisfy { $0.origin == .debug })
    }

    @Test("un piso que no existe no planea nada")
    func unknownFloor() throws {
        #expect(plan(try fxStateAndTower(units: ["a": 4]), floor: 9).isEmpty)
    }
}
