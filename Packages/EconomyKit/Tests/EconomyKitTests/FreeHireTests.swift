import Foundation
import Testing
@testable import EconomyKit

@Suite("Contrataciones gratis (el premio del Programador)")
struct FreeHireTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private let free = ActiveModifier(effect: .freeHire, magnitude: 1, expiresAt: 120, sourceKey: "career.junior_programmer")

    @Test("mientras dura, contratar es gratis; cuando vence, vuelve el precio")
    func freeWhileItLasts() throws {
        var state = fxState()
        state.run.activeModifiers = [free]
        let floorTable = try fxFloorTable()
        let during = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: floorTable, tiers: tiers, now: 60
        ))
        let after = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: floorTable, tiers: tiers, now: 121
        ))
        #expect(during.cost == 0)
        #expect(after.cost > 0)
    }

    @Test("el precio del piso también se hace gratis")
    func floorQuoteIsFreeToo() throws {
        var state = fxState()
        state.run.activeModifiers = [free]
        let floorTable = try fxFloorTable()
        let quote = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 60
        ))
        #expect(quote.cost == 0)
    }

    @Test("una contratación gratis no mueve la curva ni el amortiguador")
    func freeHiresDoNotCount() throws {
        let config = try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 4))
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        fx.state.run.activeModifiers = [free]
        let relief = fx.state.run.priceRelief
        let coins = fx.state.run.coins
        let quote = try #require(TowerActions.hireQuote(
            typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers, now: 60
        ))
        try TowerActions.hire(
            quote: quote, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
            config: config, countsAsPurchase: quote.cost > 0
        )
        #expect(fx.state.run.hireCountsByType.isEmpty)
        #expect(fx.state.run.priceRelief == relief)
        #expect(fx.state.run.units["a"] == 2)
        #expect(fx.state.run.coins == coins)
    }

    @Test("activeUntil dice hasta cuándo dura el más largo, y nil sin ninguno vivo")
    func activeUntil() {
        let longer = ActiveModifier(effect: .freeHire, magnitude: 1, expiresAt: 300, sourceKey: "x")
        #expect(ModifierMath.activeUntil(.freeHire, in: [free, longer], now: 0) == 300)
        #expect(ModifierMath.activeUntil(.freeHire, in: [free], now: 200) == nil)
        #expect(ModifierMath.activeUntil(.eventImmunity, in: [free], now: 0) == nil)
    }
}
