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

    // MARK: meta.derivedEffects.spawnDiscount (mejora permanente en blue)

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

    // MARK: ModifierMath.renew (C32: el mismo boost no se apila)

    @Test("renovar el mismo origen N veces no pasa su magnitud y se queda con el vencimiento más tardío")
    func renovarElMismoOrigenNoMultiplica() {
        var mods: [ActiveModifier] = []
        for activation in 0..<10 {
            let start = Double(activation) * 5
            ModifierMath.renew(mod(.incomeMultiplier, magnitude: 5, expiresAt: start + 30, sourceKey: "boost.turbo"), in: &mods)
        }
        #expect(ModifierMath.factor(mods, effect: .incomeMultiplier, now: 46) == 5)
        #expect(mods.count == 1)
        #expect(mods.first?.expiresAt == 75)

        // Una renovación que vence antes no acorta la que ya corría.
        ModifierMath.renew(mod(.incomeMultiplier, magnitude: 5, expiresAt: 60, sourceKey: "boost.turbo"), in: &mods)
        #expect(mods.first?.expiresAt == 75)
    }

    @Test("orígenes distintos se siguen multiplicando (B2)")
    func renovarNoTocaOtrosOrigenes() {
        var mods = [
            mod(.incomeMultiplier, magnitude: 3, expiresAt: 100, sourceKey: "boost.fernet"),
            mod(.tapMultiplier, magnitude: 2, expiresAt: 100, sourceKey: "boost.turbo"),
        ]
        ModifierMath.renew(mod(.incomeMultiplier, magnitude: 5, expiresAt: 100, sourceKey: "boost.turbo"), in: &mods)
        #expect(ModifierMath.factor(mods, effect: .incomeMultiplier, now: 50) == 15)
        #expect(ModifierMath.factor(mods, effect: .tapMultiplier, now: 50) == 2)
        #expect(mods.count == 3)
    }

    // MARK: Tope del ritmo de paquetes

    @Test("la lluvia de paquetes de varias fuentes no pasa de ×10; con una sola fuente sigue siendo ×10")
    func packageRateStackIsCapped() {
        let sources = ["shop.package_rain", "ad.package_rain", "event.lluvia_paquetes", "shop.again", "x"]
        let mods = sources.map { mod(.packageRateMultiplier, magnitude: 10, expiresAt: 100, sourceKey: $0) }
        #expect(ModifierMath.factor(Array(mods.prefix(1)), effect: .packageRateMultiplier, now: 50) == 10)
        #expect(ModifierMath.factor(mods, effect: .packageRateMultiplier, now: 50) == 10)
        #expect(ModifierMath.factor(mods, effect: .packageRateMultiplier, now: 150) == 1, "vencidos no cuentan")
    }

    @Test("el piquete (×0) sigue frenando los paquetes aunque haya lluvia")
    func strikeStillStopsPackages() {
        let mods = [
            mod(.packageRateMultiplier, magnitude: 10, expiresAt: 100, sourceKey: "shop.package_rain"),
            mod(.packageRateMultiplier, magnitude: 0, expiresAt: 100, sourceKey: "event.piquete"),
        ]
        #expect(ModifierMath.factor(mods, effect: .packageRateMultiplier, now: 50) == 0)
    }

    @Test("otros efectos no tienen ese tope")
    func otherEffectsAreNotCapped() {
        let mods = (0..<3).map { mod(.incomeMultiplier, magnitude: 10, expiresAt: 100, sourceKey: "s\($0)") }
        #expect(ModifierMath.factor(mods, effect: .incomeMultiplier, now: 50) == 1000)
    }
}
