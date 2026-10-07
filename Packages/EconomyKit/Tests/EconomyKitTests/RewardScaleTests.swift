import Foundation
import Testing
@testable import EconomyKit

/// Doce tiers en tres pisos de cuatro: la escalera chica de `Fixtures` tiene dos
/// pisos y no deja ver el tope de "frontera + 3".
private func ladder() throws -> (tiers: TierRepository, floorTable: FloorTable) {
    let types = (1...12).map { tier in
        fxType("t\(tier)", tier: tier, tapYield: pow(3.8, Double(tier - 1)), mergesInto: tier < 12 ? "t\(tier + 1)" : nil)
    }
    let floors = (0..<3).map { index in
        FloorDef(id: "p\(index + 1)", background: "alley", firstTier: index * 4 + 1, lastTier: index * 4 + 4,
                 capacity: 5, incomeMultiplier: 1)
    }
    return try (TierRepository(types: types), FloorTable(floors: floors, maxTier: 12))
}

@Suite("RewardScale: los premios en minutos de producción")
struct RewardScaleTests {
    @Test("paga los minutos de lo que la torre produce, sin los modificadores temporales")
    func paysBaseProduction() throws {
        var state = fxState(units: ["a": 3])
        state.run.passiveUnlocked["a"] = true
        state.run.activeModifiers = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: .greatestFiniteMagnitude, sourceKey: "x")
        ]
        let tiers = try fxTiers()
        let floorTable = try fxFloorTable()
        let perSecond = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(perSecond > 0)
        let paid = RewardScale.coinPayout(minutes: 2, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(abs(paid - perSecond * 120) < 1e-9)
    }

    @Test("una torre que todavía no produce cobra el piso, no cero")
    func idleTowerPaysTheFloor() throws {
        let paid = RewardScale.coinPayout(
            seconds: 60, state: fxState(units: ["a": 1]), tiers: try fxTiers(),
            floorTable: try fxFloorTable(), config: fxConfig()
        )
        #expect(paid > 0)
        #expect(abs(paid - fxEconomy().passiveYield(forTier: 1) * 60) < 1e-9)
    }

    @Test("el piso recuerda el piso más alto de la cuenta, pero no más de tres tiers arriba de la frontera")
    func rewardTierIsCappedAboveTheFrontier() throws {
        let world = try ladder()
        var state = fxState(units: ["t1": 1], unlockedFloors: ["p1"])
        state.meta.stats.maxFloorOrdinalEver = 2
        #expect(RewardScale.rewardTier(state: state, floorTable: world.floorTable) == 4)
        state.run.raiseFrontier(to: 7)
        #expect(RewardScale.rewardTier(state: state, floorTable: world.floorTable) == 9)
        state.run.raiseFrontier(to: 10)
        #expect(RewardScale.rewardTier(state: state, floorTable: world.floorTable) == 10)
    }

    @Test("un ordinal fuera de la tabla se acota a sus pisos, no revienta")
    func ordinalIsClampedToTheTable() throws {
        let floorTable = try ladder().floorTable
        var state = fxState(units: ["t1": 1], unlockedFloors: ["p1"])
        state.run.raiseFrontier(to: 7)
        state.meta.stats.maxFloorOrdinalEver = 99
        #expect(RewardScale.rewardTier(state: state, floorTable: floorTable) == 9)
        state.meta.stats.maxFloorOrdinalEver = -4
        #expect(RewardScale.rewardTier(state: state, floorTable: floorTable) == 7)
    }

    @Test("sin historia, el piso es la frontera")
    func withoutHistoryTheFloorIsTheFrontier() throws {
        var state = fxState(units: ["t1": 1], unlockedFloors: ["p1"])
        state.run.raiseFrontier(to: 3)
        #expect(RewardScale.rewardTier(state: state, floorTable: try ladder().floorTable) == 3)
    }

    @Test("un minuto son sesenta segundos, y una duración no positiva no paga")
    func minutesAreSixtySeconds() throws {
        let state = fxState(units: ["a": 1])
        let tiers = try fxTiers()
        let floorTable = try fxFloorTable()
        let minute = RewardScale.coinPayout(minutes: 1, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        let seconds = RewardScale.coinPayout(seconds: 60, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(minute == seconds)
        #expect(RewardScale.coinPayout(minutes: -5, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig()) == 0)
    }
}
