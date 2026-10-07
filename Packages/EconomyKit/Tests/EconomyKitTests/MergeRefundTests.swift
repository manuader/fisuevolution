import Foundation
import Testing
@testable import EconomyKit

@Suite("Reintegro al fusionar")
struct MergeRefundTests {
    @Test("sin la perilla, fusionar no devuelve nada: es la v1")
    func defaultRefundsNothing() throws {
        #expect(fxConfig().hire.mergeRefundCounts == 0)
        #expect(try fxConfig().tuned(EconomyKnobs()).hire.mergeRefundCounts == 0)
    }

    @Test("devuelve compras a la curva del tipo y a la de su piso, y nunca baja de cero")
    func refundLowersBothCurves() {
        var run = fxState().run
        run.hireCounts = ["f1": 3]
        run.hireCountsByType = ["a": 3, "b": 1]
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 1)
        #expect(run.hireCountsByType == ["a": 2, "b": 1])
        #expect(run.hireCounts == ["f1": 2])
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 5)
        #expect(run.hireCountsByType == ["b": 1])
        #expect(run.hireCounts.isEmpty)
    }

    @Test("un contador que llega justo a cero sale del diccionario")
    func exactZeroLeavesTheDictionary() {
        var run = fxState().run
        run.hireCounts = ["f1": 2]
        run.hireCountsByType = ["a": 2]
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 2)
        #expect(run.hireCountsByType.isEmpty)
        #expect(run.hireCounts.isEmpty)
    }

    @Test("un reintegro de cero no toca nada")
    func zeroIsANoOp() {
        var run = fxState().run
        run.hireCountsByType = ["a": 3]
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 0)
        #expect(run.hireCountsByType == ["a": 3])
    }

    @Test("con fusión continua la curva crece g^(1 − r/2) por compra")
    func continuousMergingGrowsSlower() throws {
        let config = fxConfig()
        let floor = try fxFloorTable()[0]
        for refund in [0.0, 0.5, 1.0, 2.0] {
            var run = fxState().run
            for _ in 0..<10 {
                run.hireCountsByType["a", default: 0] += 2
                run.refundMergeCounts(typeId: "a", floorId: "f1", counts: refund)
            }
            let purchases = run.hireCountsByType["a"] ?? 0
            #expect(abs(purchases - 10 * (2 - refund)) < 1e-9)
            let perPurchase = pow(
                config.hireCost(floor: floor, tier: 1, frontierTier: 1, purchases: purchases)
                    / config.hireCost(floor: floor, tier: 1, frontierTier: 1, purchases: 0),
                1.0 / 20
            )
            #expect(abs(perPurchase - pow(config.hireCostGrowth(for: floor), 1 - refund / 2)) < 1e-9)
        }
    }
}
