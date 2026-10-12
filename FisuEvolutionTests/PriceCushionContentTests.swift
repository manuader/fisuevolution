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

    /// Con las bandas de la 2.0 (E2b T14) el salto de cada tramo lleva el
    /// factor de su banda: ×1,7 del 8 al 12, ×2,0 del 13 al 16.
    @Test("el salto que absorbe es el de hoy: ×1,87 abajo, ×3,17 desde el tier 8 y ×3,73 desde el 13")
    func theJumpIsTodaysJump() throws {
        let cushion = try content.economy.tuned(EconomyKnobs(priceReliefPurchases: 24)).priceCushion
        #expect(abs(cushion.jump(from: 3, to: 4) - 2.8 / 1.5) < 1e-12)
        #expect(abs(cushion.jump(from: 10, to: 11) - 2.8 / 1.5 * 1.7) < 1e-12)
        #expect(abs(cushion.jump(from: 13, to: 14) - 2.8 / 1.5 * 2.0) < 1e-12)
        #expect(abs(cushion.step(atFrontier: 11) - pow(2.8 / 1.5 * 1.7, 1.0 / 24)) < 1e-12)
    }

    /// La 2.0 lo embarca prendido en K = 12 (E2b T14): con 24 la llegada a
    /// luxury quedaba en 36–41 min, debajo de la ventana de 45–80 del contrato.
    @Test("el economy.json real trae el amortiguador en 12 compras")
    func theShippedKnobIsTwelve() {
        #expect(content.economy.hire.priceReliefPurchases == 12)
        #expect(content.economy.priceCushion.isEnabled)
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
