import Foundation
import Testing
@testable import EconomyKit

@Suite("El amortiguador: el precio no salta al subir la frontera")
struct PriceCushionTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// La fixture con la desaceleración desde el tier 2, para que un salto
    /// cruce el umbral de la escalada.
    private func v1() -> EconomyConfig {
        fxConfig(frontierEscalationPerTier: 1.6, frontierEscalationFromTier: 2)
    }

    private func cushioned(_ purchases: Int = 4) throws -> EconomyConfig {
        try v1().tuned(EconomyKnobs(priceReliefPurchases: purchases))
    }

    private func price(_ typeId: String, _ state: PlayerState, _ config: EconomyConfig) throws -> Double {
        try #require(TowerActions.hireQuote(
            typeId: typeId, state: state, config: config, floorTable: try fxFloorTable(config: config), tiers: tiers
        )).cost
    }

    private func buy(_ typeId: String, _ fx: inout (state: PlayerState, tower: TowerState, floorTable: FloorTable),
                     _ config: EconomyConfig) throws {
        let quote = try #require(TowerActions.hireQuote(
            typeId: typeId, state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
        ))
        try TowerActions.hire(quote: quote, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                              config: config, countsAsPurchase: true)
    }

    @Test("subir la frontera no hace saltar ningún precio")
    func raisingTheFrontierKeepsEveryPrice() throws {
        let config = try cushioned()
        var state = fxState(units: ["a": 2, "b": 1])
        let types = ["a", "b", "c_prog", "d"]
        let before = try types.map { try price($0, state, config) }
        let raised = state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        #expect(raised)
        let after = try types.map { try price($0, state, config) }
        for (old, new) in zip(before, after) {
            #expect(abs(new / old - 1) < 1e-12)
        }
        #expect(state.run.priceRelief > 1)
    }

    @Test("cruzando el umbral de la desaceleración tampoco salta")
    func acrossTheEscalationThreshold() throws {
        let config = try cushioned()
        var state = fxState(units: ["a": 1])
        state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        let before = try price("a", state, config)
        state.run.raiseFrontier(to: 3, cushion: config.priceCushion)
        #expect(abs(try price("a", state, config) / before - 1) < 1e-12)
        #expect(abs(config.priceCushion.jump(from: 2, to: 3) - 3.8 / 1.5 * 1.6) < 1e-12)
    }

    @Test("después de K compras el precio vuelve exacto al de la v1")
    func afterKPurchasesThePriceIsV1() throws {
        let config = try cushioned(4)
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.coins = 1e9
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        for _ in 0..<4 {
            try buy("a", &fx, config)
        }
        #expect(fx.state.run.priceRelief == 1)
        #expect(try price("a", fx.state, config) == price("a", fx.state, v1()))
    }

    @Test("mientras dura, cada compra cuesta ρ = J^(1/K) más que con la v1")
    func eachPurchasePaysTheStep() throws {
        let config = try cushioned(4)
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.coins = 1e9
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        let first = try price("a", fx.state, config)
        try buy("a", &fx, config)
        let rho = pow(config.priceCushion.jump(from: 1, to: 2), 1.0 / 4)
        // 1,15: la curva propia del callejón de la fixture.
        #expect(abs(try price("a", fx.state, config) / first - 1.15 * rho) < 1e-9)
    }

    @Test("D divide a todos por igual: comprar hondo sigue sin ser atajo")
    func theDepthRuleSurvives() throws {
        let config = try cushioned()
        var state = fxState(units: ["a": 1])
        state.run.raiseFrontier(to: 3)
        let flat = try price("a", state, config) / price("b", state, config)
        state.run.priceRelief = 3
        #expect(abs(try price("a", state, config) / price("b", state, config) / flat - 1) < 1e-12)
    }

    @Test("una contratación gratis no descuenta el amortiguador")
    func freeHiresDoNotDecay() throws {
        let config = try cushioned()
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        let relief = fx.state.run.priceRelief
        let free = try #require(TowerActions.hireQuote(
            typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers, costMultiplier: 0
        ))
        try TowerActions.hire(quote: free, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                              config: config, countsAsPurchase: false)
        #expect(fx.state.run.priceRelief == relief)
    }

    @Test("el Corralito congela la compra también con el amortiguador, y la gratis pasa")
    func spendingFreezeStillBlocks() throws {
        let config = try cushioned()
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.coins = 1e9
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        fx.state.run.activeModifiers = [
            ActiveModifier(effect: .spendingFrozen, magnitude: 1, expiresAt: 600, sourceKey: "event.corralito")
        ]
        let quote = try #require(TowerActions.hireQuote(
            typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers, now: 10
        ))
        #expect(quote.spendingFrozen)
        let relief = fx.state.run.priceRelief
        #expect(throws: TowerError.spendingFrozen) {
            try TowerActions.hire(quote: quote, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                                  config: config, countsAsPurchase: true)
        }
        #expect(fx.state.run.priceRelief == relief)
        #expect(fx.state.run.hireCountsByType["a"] == nil)
        let free = try #require(TowerActions.hireQuote(
            typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers,
            costMultiplier: 0, now: 10
        ))
        try TowerActions.hire(quote: free, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                              config: config, countsAsPurchase: false)
        #expect(fx.state.run.units["a"] == 2)
    }

    @Test("apagado, el precio es el de la v1 aunque el save traiga un D, y la próxima compra lo limpia")
    func offMeansV1() throws {
        let config = fxConfig()
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.coins = 1e9
        fx.state.run.priceRelief = 5
        #expect(try price("a", fx.state, config) == config.hireCost(floor: fx.floorTable[0], tier: 1, frontierTier: 1, purchases: 0))
        try buy("a", &fx, config)
        #expect(fx.state.run.priceRelief == 1)
    }

    @Test("reencarnar vuelve el amortiguador a 1")
    func reincarnationResetsIt() throws {
        var state = fxState()
        state.run.priceRelief = 4
        PrestigeCalculator.applyReincarnation(state: &state, economy: fxEconomy(), tiers: tiers, floorTable: try fxFloorTable(), now: 0)
        #expect(state.run.priceRelief == 1)
    }

    @Test("la perilla viaja por el JSON y su falta es la v1")
    func theKnobDecodes() throws {
        #expect(fxConfig().hire.priceReliefPurchases == 0)
        #expect(!fxConfig().priceCushion.isEnabled)
        #expect(try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 24)).hire.priceReliefPurchases == 24)
    }

    @Test("con la perilla en 0 la raíz de la compra es la de siempre: no toca D ni cambia el precio")
    func offIsInertEverywhere() throws {
        let config = fxConfig(frontierEscalationPerTier: 1.6, frontierEscalationFromTier: 2)
        var plain = try fxStateAndTower(units: ["a": 1], config: config)
        var viaCushion = plain
        plain.state.run.coins = 1e9
        viaCushion.state.run.coins = 1e9
        plain.state.run.raiseFrontier(to: 3)
        viaCushion.state.run.raiseFrontier(to: 3, cushion: config.priceCushion)
        #expect(viaCushion.state.run == plain.state.run)
        for _ in 0..<3 {
            try buy("a", &plain, config)
            try buy("a", &viaCushion, config)
            #expect(try price("a", viaCushion.state, config) == price("a", plain.state, config))
        }
        #expect(viaCushion.state.run == plain.state.run)
    }
}

@Suite("“+6 % por compra”: lo que se muestra es lo que se cobra")
struct HireStepTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test("el paso de la próxima compra es lo que sube el precio, con y sin amortiguador")
    func theStepIsWhatTheNextPurchaseCosts() throws {
        for config in [fxConfig(), try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 4))] {
            var fx = try fxStateAndTower(units: ["a": 1], config: config)
            fx.state.run.coins = 1e9
            fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
            let step = try #require(TowerActions.nextHireStep(
                typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
            ))
            let before = try #require(TowerActions.hireQuote(
                typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
            ))
            try TowerActions.hire(quote: before, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                                  config: config, countsAsPurchase: true)
            let after = try #require(TowerActions.hireQuote(
                typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
            ))
            #expect(abs(after.cost / before.cost - 1 - step) < 1e-12)
        }
    }

    @Test("sin amortiguador, el paso es la curva del piso: 15 % en el callejón de la fixture")
    func withoutCushionTheStepIsTheGrowth() throws {
        let fx = try fxStateAndTower(units: ["a": 1])
        let step = try #require(TowerActions.nextHireStep(
            typeId: "a", state: fx.state, config: fxConfig(), floorTable: fx.floorTable, tiers: tiers
        ))
        #expect(abs(step - 0.15) < 1e-12)
    }

    @Test("con el reintegro, fusionar baja lo que dice")
    func mergeReliefIsWhatTheRefundTakes() throws {
        let config = try fxConfig().tuned(EconomyKnobs(mergeRefundCounts: 1))
        let floorTable = try fxFloorTable(config: config)
        var state = fxState(units: ["a": 2])
        state.run.hireCountsByType = ["a": 4]
        state.run.hireCounts = ["f1": 4]
        let relief = try #require(TowerActions.mergeRelief(
            typeId: "a", state: state, config: config, floorTable: floorTable, tiers: tiers
        ))
        let before = try #require(TowerActions.hireQuote(typeId: "a", state: state, config: config, floorTable: floorTable, tiers: tiers)).cost
        state.run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 1)
        let after = try #require(TowerActions.hireQuote(typeId: "a", state: state, config: config, floorTable: floorTable, tiers: tiers)).cost
        #expect(abs(1 - after / before - relief) < 1e-12)
    }

    @Test("en el paquete, sólo la carga sube la frontera sin amortiguar")
    func onlyTheLoaderRaisesTheFrontierUncushioned() throws {
        let sources = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/EconomyKit")
        let exempt: Set = ["PlayerState.swift", "TowerReconciler.swift"]
        let offenders = try FileManager.default
            .contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && !exempt.contains($0.lastPathComponent) }
            .filter { file in
                try String(contentsOf: file, encoding: .utf8)
                    .split(separator: "\n")
                    .contains { $0.contains("raiseFrontier(to:") && !$0.contains("cushion:") }
            }
            .map(\.lastPathComponent)
        #expect(offenders.isEmpty, "suben la frontera sin el amortiguador: \(offenders)")
    }

    @Test("sin reintegro, o con un tipo que no se fusiona, no hay nada que prometer")
    func noReliefWithoutRefund() throws {
        let refunding = try fxConfig().tuned(EconomyKnobs(mergeRefundCounts: 1))
        var state = fxState(units: ["a": 2, "d": 1])
        state.run.hireCountsByType = ["a": 4, "d": 2]
        #expect(TowerActions.mergeRelief(typeId: "a", state: state, config: fxConfig(), floorTable: try fxFloorTable(), tiers: tiers) == nil)
        #expect(TowerActions.mergeRelief(typeId: "d", state: state, config: refunding, floorTable: try fxFloorTable(), tiers: tiers) == nil)
    }
}
