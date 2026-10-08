import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El amortiguador sobre los datos reales: absorbe el salto de hoy y, con D = 1,
/// no cambia ni un precio de la v1.
@Suite("El amortiguador sobre los datos reales")
struct PriceCushionContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("el salto que absorbe es el de hoy: ×1,87 abajo y ×2,99 desde el tier 8")
    func theJumpIsTodaysJump() throws {
        let cushion = try content.economy.tuned(EconomyKnobs(priceReliefPurchases: 24)).priceCushion
        #expect(abs(cushion.jump(from: 3, to: 4) - 2.8 / 1.5) < 1e-12)
        #expect(abs(cushion.jump(from: 10, to: 11) - 2.8 / 1.5 * 1.6) < 1e-12)
        #expect(abs(cushion.step(atFrontier: 11) - pow(2.8 / 1.5 * 1.6, 1.0 / 24)) < 1e-12)
    }

    @Test("el economy.json real trae la perilla apagada: la v1")
    func theShippedKnobIsOff() {
        #expect(content.economy.hire.priceReliefPurchases == 0)
        #expect(!content.economy.priceCushion.isEnabled)
    }

    @Test("con D = 1 el precio es el de la v1 en los 37 tiers")
    func reliefOneIsV1Everywhere() throws {
        let cushioned = try content.economy.tuned(EconomyKnobs(priceReliefPurchases: 24))
        var state = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id, startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: 0, critChanceBase: 0, now: 0
        )
        for frontier in [1, 7, 8, 20, content.tiers.maxTier] {
            state.run.raiseFrontier(to: frontier)
            for type in content.tiers.concreteTypes {
                let v1 = try #require(TowerActions.hireQuote(
                    typeId: type.id, state: state, config: content.economy,
                    floorTable: content.floorTable, tiers: content.tiers
                )).cost
                let withCushion = try #require(TowerActions.hireQuote(
                    typeId: type.id, state: state, config: cushioned,
                    floorTable: content.floorTable, tiers: content.tiers
                )).cost
                #expect(withCushion == v1, "\(type.id) con la frontera en \(frontier)")
            }
        }
    }
}
