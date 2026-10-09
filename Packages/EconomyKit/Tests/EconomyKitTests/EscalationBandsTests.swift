import Foundation
import Testing
@testable import EconomyKit

@Suite("La escalada por bandas y la curva por piso")
struct EscalationBandsTests {
    private typealias Band = EconomyConfig.HireConfig.EscalationBand

    private func v1() -> EconomyConfig {
        fxConfig(frontierEscalationPerTier: 1.6, frontierEscalationFromTier: 7)
    }

    @Test("sin bandas, la escalada es la de la v1 en los 37 tiers")
    func noBandsIsV1() {
        let hire = v1().hire
        for frontier in 1...37 {
            let expected = pow(1.6, Double(max(0, frontier - 7)))
            #expect(abs(hire.escalation(atFrontier: frontier) / expected - 1) < 1e-12, "T\(frontier)")
        }
    }

    @Test("una banda desde el tier siguiente al umbral reproduce la v1 exacta")
    func oneBandIsV1() throws {
        let banded = try v1().tuned(EconomyKnobs(escalationBands: [Band(fromTier: 8, factor: 1.6)]))
        for frontier in 1...37 {
            #expect(abs(banded.hire.escalation(atFrontier: frontier) / v1().hire.escalation(atFrontier: frontier) - 1) < 1e-12)
        }
    }

    @Test("cada tier de frontera paga el factor de SU banda")
    func eachTierPaysItsBand() throws {
        let bands = [Band(fromTier: 8, factor: 1.45), Band(fromTier: 13, factor: 1.6), Band(fromTier: 25, factor: 1.7)]
        let hire = try v1().tuned(EconomyKnobs(escalationBands: bands)).hire
        #expect(hire.escalation(atFrontier: 7) == 1)
        #expect(abs(hire.escalation(atFrontier: 12) - pow(1.45, 5)) < 1e-9)
        #expect(abs(hire.escalation(atFrontier: 13) - pow(1.45, 5) * 1.6) < 1e-9)
        #expect(abs(hire.escalation(atFrontier: 25) / (pow(1.45, 5) * pow(1.6, 12) * 1.7) - 1) < 1e-12)
    }

    @Test("hireCost cobra la escalada de las bandas, y comprar hondo sigue sin ser atajo")
    func hireCostUsesTheBands() throws {
        let bands = [Band(fromTier: 2, factor: 1.45), Band(fromTier: 4, factor: 1.7)]
        let config = try fxConfig().tuned(EconomyKnobs(escalationBands: bands))
        let floor = config.floors[1]
        let at3 = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 0)
        let at4 = config.hireCost(floor: floor, tier: 3, frontierTier: 4, purchases: 0)
        let yieldOverPrice = config.yieldGrowthPerTier / config.hire.priceGrowthPerTier
        #expect(abs(at4 / at3 / (yieldOverPrice * 1.7) - 1) < 1e-12)
        let deeper = config.hireCost(floor: floor, tier: 3, frontierTier: 4, purchases: 0)
        let top = config.hireCost(floor: floor, tier: 4, frontierTier: 4, purchases: 0)
        #expect(abs(top / deeper - config.hire.priceGrowthPerTier) < 1e-12)
    }

    @Test("el amortiguador salta exactamente lo que salta el precio")
    func cushionJumpIsThePriceJump() throws {
        let bands = [Band(fromTier: 2, factor: 1.45), Band(fromTier: 4, factor: 1.7)]
        let config = try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 24, escalationBands: bands))
        let floor = config.floors[1]
        for frontier in 2...4 {
            let before = config.hireCost(floor: floor, tier: 3, frontierTier: frontier - 1, purchases: 0)
            let after = config.hireCost(floor: floor, tier: 3, frontierTier: frontier, purchases: 0)
            #expect(abs(config.priceCushion.jump(from: frontier - 1, to: frontier) / (after / before) - 1) < 1e-12)
        }
    }

    @Test("unas bandas desordenadas, con un factor bajo 1 o desde el tier 1 no cargan")
    func badBandsDoNotDecode() {
        for bands in [[Band(fromTier: 13, factor: 1.6), Band(fromTier: 8, factor: 1.45)],
                      [Band(fromTier: 8, factor: 0.9)],
                      [Band(fromTier: 1, factor: 1.2)]] {
            #expect(throws: (any Error).self) { try fxConfig().tuned(EconomyKnobs(escalationBands: bands)) }
        }
    }

    @Test("la curva sube un escalón por piso desde el indicado, y los overrides no se tocan")
    func growthStepsByFloor() throws {
        let base = fxConfig()
        let fromSecond = try base.tuned(EconomyKnobs(costGrowthStepPerFloor: 0.01, costGrowthStepFromFloorId: "f2"))
        #expect(fromSecond.hireCostGrowth(for: base.floors[0]) == base.hireCostGrowth(for: base.floors[0]))
        #expect(abs(fromSecond.hireCostGrowth(for: base.floors[1]) - (base.hire.defaultCostGrowth + 0.01)) < 1e-12)
        let fromFirst = try base.tuned(EconomyKnobs(costGrowthStepPerFloor: 0.01, costGrowthStepFromFloorId: "f1"))
        #expect(fromFirst.hireCostGrowth(for: base.floors[0]) == base.floors[0].hireCostGrowthOverride)
        #expect(abs(fromFirst.hireCostGrowth(for: base.floors[1]) - (base.hire.defaultCostGrowth + 0.02)) < 1e-12)
    }
}
