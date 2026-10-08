import Foundation
import Testing
@testable import EconomyKit

@Suite("Corralito: se congela el gasto, no los ingresos")
struct SpendingFrozenTests {
    let tiers: TierRepository
    let economy = fxEconomy()

    init() throws {
        tiers = try fxTiers()
    }

    private let freeze = ActiveModifier(effect: .spendingFrozen, magnitude: 1, expiresAt: 45, sourceKey: "event.corralito")

    @Test("contratar rebota mientras dura y vuelve cuando vence")
    func hiringIsFrozen() throws {
        let fixture = try fxStateAndTower()
        var state = fixture.state
        var tower = fixture.tower
        state.run.coins = 1_000_000
        state.run.activeModifiers = [freeze]
        let frozen = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: fixture.floorTable, tiers: tiers, now: 10
        ))
        #expect(frozen.spendingFrozen)
        #expect(throws: TowerError.spendingFrozen) {
            try TowerActions.hire(quote: frozen, state: &state, tower: &tower, floorTable: fixture.floorTable,
                                  config: fxConfig(), countsAsPurchase: true)
        }
        let thawed = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: fixture.floorTable, tiers: tiers, now: 50
        ))
        #expect(!thawed.spendingFrozen)
    }

    @Test("los ingresos siguen")
    func incomeKeepsFlowing() throws {
        var state = fxState(units: ["a": 2])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers, now: 0)
        let before = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: try fxFloorTable(), config: fxConfig(), now: 10)
        state.run.activeModifiers = [freeze]
        let during = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: try fxFloorTable(), config: fxConfig(), now: 10)
        #expect(during == before)
    }

    @Test("mejorar y desbloquear pasivos también rebotan")
    func upgradesAndPassivesAreFrozen() throws {
        var state = fxState(units: ["a": 2])
        state.run.coins = 1_000_000
        state.run.activeModifiers = [freeze]
        let type = try #require(tiers.type(id: "a"))
        #expect(throws: CharUpgrades.PurchaseError.spendingFrozen) {
            try CharUpgrades.purchase(type: type, state: &state, config: fxConfig(), economy: economy, now: 10)
        }
        #expect(throws: PassiveUnlockError.spendingFrozen) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers, now: 10)
        }
    }
}
