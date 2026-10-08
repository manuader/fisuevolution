import Foundation
import Testing
@testable import EconomyKit

@Suite("Pisos en marcha")
struct StaffedFloorsTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func bonus(_ value: Double) throws -> EconomyConfig {
        try fxConfig().tuned(EconomyKnobs(staffedFloorBonus: value))
    }

    @Test("un piso con todos sus lugares ocupados está en marcha; con uno libre, no")
    func fullMeansStaffed() throws {
        let floorTable = try fxFloorTable()
        #expect(StaffedFloors.ordinals(state: fxState(units: ["a": 3, "b": 2]), tiers: tiers, floorTable: floorTable) == [0])
        #expect(StaffedFloors.ordinals(state: fxState(units: ["a": 4]), tiers: tiers, floorTable: floorTable).isEmpty)
    }

    @Test("sin la perilla no suma nada: es la v1")
    func zeroBonusIsV1() throws {
        #expect(StaffedFloors.multiplier(state: fxState(units: ["a": 5]), tiers: tiers,
                                         floorTable: try fxFloorTable(), config: fxConfig()) == 1)
    }

    @Test("dos pisos en marcha suman dos veces")
    func bonusesAdd() throws {
        let multiplier = StaffedFloors.multiplier(state: fxState(units: ["a": 5, "d": 5]), tiers: tiers,
                                                  floorTable: try fxFloorTable(), config: try bonus(0.05))
        #expect(abs(multiplier - 1.10) < 1e-12)
    }

    @Test("el bono es global: el mismo número en el pasivo, el toque y el offline")
    func theBonusIsGlobal() throws {
        let tuned = try bonus(0.05)
        let floorTable = try fxFloorTable()
        var state = fxState(units: ["a": 5])
        state.run.passiveUnlocked["a"] = true
        let passive = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: tuned)
            / IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(abs(passive - 1.05) < 1e-12)

        let type = try #require(tiers.type(id: "a"))
        var boosted = state
        var plain = state
        let boostedTap = fxEconomy(config: tuned).applyTap(type: type, state: &boosted, tiers: tiers, floorTable: floorTable, now: 0)
        let plainTap = fxEconomy().applyTap(type: type, state: &plain, tiers: tiers, floorTable: floorTable, now: 0)
        #expect(abs(boostedTap / plainTap - 1.05) < 1e-12)

        state.meta.lastSeenTimestamp = 0
        let offline = OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: tuned, now: 600)
            / OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 600)
        #expect(abs(offline - 1.05) < 1e-12)
    }

    @Test("el bono es un ingreso: un Corralito vivo no lo congela")
    func spendingFreezeLeavesTheBonus() throws {
        let floorTable = try fxFloorTable()
        var state = fxState(units: ["a": 5])
        state.run.passiveUnlocked["a"] = true
        state.run.activeModifiers = [ActiveModifier(effect: .spendingFrozen, magnitude: 1, expiresAt: 100, sourceKey: "corralito")]
        let frozen = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: try bonus(0.05), now: 10)
        let plain = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 10)
        #expect(abs(frozen / plain - 1.05) < 1e-12)
    }

    @Test("una torre de 5 lugares entra entera en una de 7: la capacidad sólo crece")
    func growingCapacityKeepsEveryUnit() throws {
        var run = fxState(units: ["a": 5, "d": 5]).run
        let small = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable(), tiers: tiers)
        #expect(small.autoMerged == 0 && small.discarded.isEmpty)
        let grown = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable(config: fxConfig(capacity: 7)), tiers: tiers)
        #expect(grown.autoMerged == 0 && grown.discarded.isEmpty)
        #expect(run.units == ["a": 5, "d": 5])
        #expect(grown.tower.floors.map(\.occupiedCount) == [5, 5])
    }
}
