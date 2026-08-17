import Foundation
import Testing
@testable import EconomyKit

// MARK: - Modifiers temporales (rewarded/eventos/boosts) — viven en run.activeModifiers (F7)

@Suite("ActiveModifier (rewarded/eventos/boosts)")
struct ActiveModifierTests {
    private func mod(
        _ effect: ActiveModifier.Effect,
        magnitude: Double,
        expiresAt: TimeInterval,
        sourceKey: String = "test"
    ) -> ActiveModifier {
        ActiveModifier(effect: effect, magnitude: magnitude, expiresAt: expiresAt, sourceKey: sourceKey)
    }

    // MARK: isActive

    @Test("vivo antes del vencimiento, muerto desde el instante exacto")
    func isActiveRespetaElVencimiento() {
        let m = mod(.incomeMultiplier, magnitude: 2, expiresAt: 100)
        #expect(m.isActive(at: 50))
        // expiresAt > now: en el segundo exacto ya no corre.
        #expect(!m.isActive(at: 100))
        #expect(!m.isActive(at: 200))
    }

    @Test("permanente (.infinity) no vence nunca")
    func permanenteNuncaVence() {
        let m = mod(.tapMultiplier, magnitude: 1.5, expiresAt: .infinity)
        #expect(m.isActive(at: 1e12))
    }

    // MARK: ModifierMath.factor

    @Test("factor multiplica las magnitudes del efecto pedido (stackean)")
    func factorEsElProductoDeLosVivos() {
        let mods = [
            mod(.incomeMultiplier, magnitude: 2, expiresAt: 100),
            mod(.incomeMultiplier, magnitude: 3, expiresAt: 100, sourceKey: "test2"),
        ]
        #expect(ModifierMath.factor(mods, effect: .incomeMultiplier, now: 50) == 6)
    }

    @Test("factor ignora otros efectos y los vencidos")
    func factorFiltraEfectoYVencimiento() {
        let mods = [
            mod(.incomeMultiplier, magnitude: 2, expiresAt: 100),
            // Otro efecto: no cuenta para income.
            mod(.tapMultiplier, magnitude: 3, expiresAt: 100),
            // Vencido a now 50: tampoco.
            mod(.incomeMultiplier, magnitude: 5, expiresAt: 40),
        ]
        #expect(ModifierMath.factor(mods, effect: .incomeMultiplier, now: 50) == 2)
        #expect(ModifierMath.factor(mods, effect: .tapMultiplier, now: 50) == 3)
    }

    @Test("sin modifiers el factor es neutro (1)")
    func factorVacioEsNeutro() {
        #expect(ModifierMath.factor([], effect: .spawnCostMultiplier, now: 0) == 1)
    }

    // MARK: ModifierMath.prune

    @Test("prune borra solo los vencidos y avisa solo si sacó algo")
    func pruneBorraSoloVencidos() {
        var state = fxState()
        state.run.activeModifiers = [
            mod(.incomeMultiplier, magnitude: 2, expiresAt: 100, sourceKey: "muerto"),
            mod(.tapMultiplier, magnitude: 2, expiresAt: 500, sourceKey: "vivo"),
            mod(.tapMultiplier, magnitude: 2, expiresAt: .infinity, sourceKey: "permanente"),
        ]
        #expect(ModifierMath.prune(&state, now: 200))
        #expect(state.run.activeModifiers.map(\.sourceKey) == ["vivo", "permanente"])
        // Segunda pasada: no queda nada que sacar.
        #expect(!ModifierMath.prune(&state, now: 200))
        #expect(state.run.activeModifiers.count == 2)
    }

    // MARK: spawnCostMultiplier × hireQuote ("Unos Mates" sobre la contratación)

    @Test("spawnCostMultiplier descuenta el hire mientras está vivo; vencido, precio pleno")
    func spawnCostModifierDescuentaElHire() throws {
        let config = fxConfig()
        let tiers = try fxTiers()
        let fixture = try fxStateAndTower(config: config)
        var state = fixture.state
        state.run.activeModifiers = [mod(.spawnCostMultiplier, magnitude: 0.5, expiresAt: 100)]

        // f1 vende su tier base T1 a 15 (override barato, 0 compras previas).
        let quote = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: fixture.floorTable,
            config: config, now: 50
        ))
        #expect(abs(quote.cost - 15 * 0.5) < 1e-9)

        let expired = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: fixture.floorTable,
            config: config, now: 200
        ))
        #expect(abs(expired.cost - 15) < 1e-9)
    }

    // MARK: meta.derivedEffects.spawnDiscount (mejora permanente en ORO)

    @Test("spawnDiscount permanente descuenta el hire y se combina con el modifier")
    func spawnDiscountSeCombinaConElModifier() throws {
        let config = fxConfig()
        let tiers = try fxTiers()
        let fixture = try fxStateAndTower(config: config)
        var state = fixture.state
        state.meta.derivedEffects.spawnDiscount = 0.2

        // Solo el descuento permanente: 15 × (1 − 0.2).
        let solo = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: fixture.floorTable,
            config: config, now: 50
        ))
        #expect(abs(solo.cost - 15 * 0.8) < 1e-9)

        // Con "Unos Mates" encima: los factores se multiplican, no se suman.
        state.run.activeModifiers = [mod(.spawnCostMultiplier, magnitude: 0.5, expiresAt: 100)]
        let combined = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: fixture.floorTable,
            config: config, now: 50
        ))
        #expect(abs(combined.cost - 15 * 0.5 * 0.8) < 1e-9)
    }
}
