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
            floorOrdinal: floor, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig(), origin: .debug
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
            _ = try BoardChangeApplier.apply(change, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig())
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

    @Test("cada cambio del plan es un eslabón de la misma cadena, en orden")
    func everyChangeIsALinkOfTheSameChain() throws {
        var fx = try fxStateAndTower(units: ["a": 4])
        fx.state.run.chosenCareerPath = "prog"
        let changes = plan(fx)
        let chains = changes.compactMap(\.chain)
        #expect(chains.count == changes.count)
        #expect(Set(chains.map(\.id)).count == 1)
        #expect(chains.map(\.index) == [0, 1, 2])
        #expect(chains.allSatisfy { $0.count == 3 })
        #expect(chains.map(\.isLast) == [false, false, true])
    }

    @Test("dos planes son dos cadenas")
    func twoPlansAreTwoChains() throws {
        let fx = try fxStateAndTower(units: ["a": 4])
        #expect(plan(fx).first?.chain?.id != plan(fx).first?.chain?.id)
    }

    @Test("replanear un eslabón con otros slots conserva el sello")
    func revalidationKeepsTheLink() throws {
        var fx = try fxStateAndTower(units: ["a": 3])
        let link = try #require(plan(fx).first)
        guard case let .merge(ordinal, typeId, source, _, _) = link.kind else {
            Issue.record("no es un merge")
            return
        }
        let free = try #require(fx.tower.floors[ordinal].firstFreeSlot())
        fx.tower.floors[ordinal].slots[free] = typeId
        fx.tower.floors[ordinal].slots[source] = nil
        let replanned = try #require(BoardChangePlanner.revalidate(
            link, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable
        ))
        #expect(replanned.kind != link.kind)
        #expect(replanned.chain == link.chain)
        #expect(replanned.id == link.id)
    }

    @Test("los cambios sueltos no son cadena")
    func singleChangesHaveNoChain() throws {
        var fx = try fxStateAndTower(units: ["a": 2])
        fx.state.run.chosenCareerPath = "prog"
        let auto = BoardChangePlanner.planAutoMerge(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .debug
        )
        #expect(auto?.chain == nil)
    }
}
