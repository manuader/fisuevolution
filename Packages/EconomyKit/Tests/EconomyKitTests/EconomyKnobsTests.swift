import Foundation
import Testing
@testable import EconomyKit

@Suite("Las perillas de E2a")
struct EconomyKnobsTests {
    @Test("sin perillas, la config sale igual")
    func noKnobsIsTheSameConfig() throws {
        #expect(try fxConfig().tuned(EconomyKnobs()) == fxConfig())
        #expect(!fxConfig().oro.requiresWall)
    }

    @Test("cada perilla llega a su campo por el decoder, y el resto no se mueve")
    func eachKnobLands() throws {
        let tuned = try fxConfig().tuned(EconomyKnobs(defaultCostGrowth: 1.12, mergeRefundCounts: 1, priceReliefPurchases: 24, staffedFloorBonus: 0.05, requiresLastRunWall: true))
        #expect(tuned.oro.requiresWall)
        #expect(tuned.hire.defaultCostGrowth == 1.12)
        #expect(tuned.hire.mergeRefundCounts == 1)
        #expect(tuned.hire.priceReliefPurchases == 24)
        #expect(tuned.staffedBonusPerFloor == 0.05)
        #expect(tuned.floors == fxConfig().floors)
        #expect(tuned.oro.divisor == fxConfig().oro.divisor)
        #expect(tuned.oro.exponent == fxConfig().oro.exponent)
        #expect(tuned.oro.globalMultiplierPerOro == fxConfig().oro.globalMultiplierPerOro)
        #expect(tuned.oro.prestigeTeaserFloorId == fxConfig().oro.prestigeTeaserFloorId)
    }

    @Test("las perillas de E2b llegan por el decoder")
    func e2bKnobsLand() throws {
        let band = EconomyConfig.HireConfig.EscalationBand(fromTier: 8, factor: 1.45)
        let tuned = try fxConfig().tuned(EconomyKnobs(
            escalationBands: [band], costGrowthStepPerFloor: 0.01, costGrowthStepFromFloorId: "f2"
        ))
        #expect(tuned.hire.escalationBands == [band])
        #expect(tuned.hire.costGrowthStepPerFloor == 0.01)
        #expect(tuned.hire.costGrowthStepFromFloorId == "f2")
        #expect(try fxConfig().tuned(EconomyKnobs()) == fxConfig())
    }
}
