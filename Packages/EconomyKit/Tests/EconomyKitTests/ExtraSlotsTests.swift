import Foundation
import Testing
@testable import EconomyKit

@Suite("Lugares extra: la capacidad cambia en la tabla de pisos y en ningún otro lado")
struct ExtraSlotsTests {
    @Test("agranda todos los pisos y no mueve ningún tier")
    func expandsEveryFloor() throws {
        let table = try fxFloorTable()
        let bigger = table.expanded(by: 3)
        #expect(bigger.floors.map(\.capacity) == [8, 8])
        for tier in 1...4 {
            #expect(bigger.ordinal(forTier: tier) == table.ordinal(forTier: tier))
        }
        #expect(bigger.floors.map(\.id) == table.floors.map(\.id))
        #expect(table.expanded(by: 0) == table)
        #expect(table.expanded(by: -2) == table, "los lugares nunca restan")
    }

    @Test("la torre nace con los lugares de la tabla agrandada")
    func towerUsesTheTable() throws {
        let bigger = try fxFloorTable().expanded(by: 3)
        #expect(TowerState(floorTable: bigger).floors.map(\.slots.count) == [8, 8])
    }

    @Test("lo que desbordaba entra sin fusionar")
    func reconcileFitsMore() throws {
        let tiers = try fxTiers()
        var small = fxState(units: ["a": 8]).run
        let squeezed = TowerReconciler.reconcile(run: &small, floorTable: try fxFloorTable(), tiers: tiers)
        #expect(squeezed.autoMerged > 0, "con 5 lugares, 8 no entran")
        var roomy = fxState(units: ["a": 8]).run
        let fits = TowerReconciler.reconcile(run: &roomy, floorTable: try fxFloorTable().expanded(by: 3), tiers: tiers)
        #expect(fits.autoMerged == 0)
        #expect(fits.discarded.isEmpty)
        #expect(roomy.units["a"] == 8)
    }

    @Test("si los lugares se van, el reconciliador reacomoda con sus reglas")
    func shrinkingReconciles() throws {
        let tiers = try fxTiers()
        var run = fxState(units: ["a": 8]).run
        _ = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable().expanded(by: 3), tiers: tiers)
        let back = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable(), tiers: tiers)
        #expect(back.autoMerged > 0)
        #expect(back.tower.floors[0].occupiedCount <= 5)
    }

    @Test("los niveles del permanente dan los lugares que dice el dato")
    func perkFromLevels() throws {
        let json = #"{"schemaVersion": 1, "items": [{"id": "extra_slots", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "extraSlots", "levels": [{"price": 600, "value": 3}, {"price": 1500, "value": 2}]}]}"#
        let catalog = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        let table = try fxFloorTable()
        #expect(table.expanded(by: OroShop.extraSlots(levels: ["extra_slots": 1], catalog: catalog)).floors[0].capacity == 8)
        #expect(table.expanded(by: OroShop.extraSlots(levels: ["extra_slots": 2], catalog: catalog)).floors[0].capacity == 10)
    }

    @Test("un piso en marcha con lugares extra pide más gente")
    func staffedNeedsMorePeople() throws {
        let tiers = try fxTiers()
        let state = fxState(units: ["a": 5])
        #expect(StaffedFloors.ordinals(state: state, tiers: tiers, floorTable: try fxFloorTable()) == [0])
        #expect(StaffedFloors.ordinals(state: state, tiers: tiers, floorTable: try fxFloorTable().expanded(by: 2)).isEmpty)
    }
}
