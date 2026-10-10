import Foundation
import Testing
@testable import EconomyKit

@Suite("La política de pisos en marcha del bot")
struct StaffingPolicyTests {
    private func simulator(bonus: Double, capacity: Int = 4) throws -> PacingSimulator {
        try PacingSimulator(
            config: upConfig(capacity: capacity).tuned(EconomyKnobs(staffedFloorBonus: bonus)),
            tiers: upTiers(), upgrades: upCheapLines()
        )
    }

    private func state(units: [String: Int], frontier: Int) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1", offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        state.run.units = units
        state.run.passiveUnlocked = Dictionary(uniqueKeysWithValues: units.keys.map { ($0, true) })
        state.run.raiseFrontier(to: frontier, cushion: upConfig().priceCushion)
        state.run.coins = 1e30
        return state
    }

    @Test("sin bono no hay objetivo ni pisos congelados: el bot de siempre")
    func noBonusNoPolicy() throws {
        let sim = try simulator(bonus: 0)
        let s = state(units: ["t1": 2, "t2": 1], frontier: 12)
        #expect(sim.staffingTarget(state: s) == nil)
        #expect(sim.frozenFloors(state: s).isEmpty)
    }

    @Test("con bono, el piso bajo y barato es el objetivo")
    func cheapLowFloorIsTheTarget() throws {
        let sim = try simulator(bonus: 0.5)
        let s = state(units: ["t1": 2, "t9": 4, "t10": 2], frontier: 12)
        #expect(sim.staffingTarget(state: s) == 0)
    }

    @Test("un piso en marcha bajo el piso de compra no se desarma fusionando")
    func staffedFloorIsFrozen() throws {
        let sim = try simulator(bonus: 0.5)
        let s = state(units: ["t1": 2, "t2": 2, "t13": 1], frontier: 13)
        #expect(sim.frozenFloors(state: s) == [0])
    }

    @Test("el piso donde el bot compra no es objetivo: ahí vive el material de fusión")
    func theBuyingFloorIsNeverTheTarget() throws {
        let sim = try simulator(bonus: 0.5)
        var s = state(units: ["t1": 1, "t5": 1, "t6": 1], frontier: 10)
        s.run.unlockedFloors = ["f1", "f2", "f3"]
        #expect(sim.staffingTarget(state: s) == 0)
        s.run.units["t1"] = 4
        #expect(sim.staffingTarget(state: s) == nil)
    }

    @Test("con más lugares que tiers por piso, el llenado no se fusiona y el piso se completa")
    func fillingSurvivesTheMerges() throws {
        let off = try simulator(bonus: 0, capacity: 10).run(maxDays: 5)
        let on = try simulator(bonus: 0.5, capacity: 10).run(maxDays: 5)
        #expect(off.maxStaffedFloors == 0)
        #expect(on.maxStaffedFloors >= 1)
    }

    @Test("con el bono en cero, la partida es la de la base exacta")
    func zeroBonusIsTheBaseline() throws {
        let base = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), upgrades: upCheapLines()).run(maxDays: 5)
        let zero = try simulator(bonus: 0).run(maxDays: 5)
        #expect(fingerprint(zero) == fingerprint(base))
        #expect(zero.maxStaffedFloors == base.maxStaffedFloors)
    }

    @Test("con bono, el bot llega a tener pisos en marcha y le rinde")
    func theBonusIsUsed() throws {
        let off = try simulator(bonus: 0).run(maxDays: 5)
        let on = try simulator(bonus: 0.5).run(maxDays: 5)
        #expect(on.maxStaffedFloors >= 1)
        #expect(on.finalLifetimeEarnings > off.finalLifetimeEarnings)
    }
}
