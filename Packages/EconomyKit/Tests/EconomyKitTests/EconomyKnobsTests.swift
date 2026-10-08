import Foundation
import Testing
@testable import EconomyKit

@Suite("Las perillas de E2a")
struct EconomyKnobsTests {
    @Test("sin perillas, la config sale igual")
    func noKnobsIsTheSameConfig() throws {
        #expect(try fxConfig().tuned(EconomyKnobs()) == fxConfig())
    }

    @Test("cada perilla llega a su campo por el decoder, y el resto no se mueve")
    func eachKnobLands() throws {
        let tuned = try fxConfig().tuned(EconomyKnobs(defaultCostGrowth: 1.12, mergeRefundCounts: 1, priceReliefPurchases: 24, staffedFloorBonus: 0.05))
        #expect(tuned.hire.defaultCostGrowth == 1.12)
        #expect(tuned.hire.mergeRefundCounts == 1)
        #expect(tuned.hire.priceReliefPurchases == 24)
        #expect(tuned.staffedBonusPerFloor == 0.05)
        #expect(tuned.floors == fxConfig().floors)
        #expect(tuned.oro == fxConfig().oro)
    }
}
