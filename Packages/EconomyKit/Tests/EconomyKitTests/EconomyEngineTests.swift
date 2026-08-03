import Foundation
import Testing
@testable import EconomyKit

// MARK: - Fórmulas puras de StandardEconomy (F7 §3)

@Suite("StandardEconomy fórmulas (F7 §3)")
struct EconomyEngineTests {
    let economy = fxEconomy()

    @Test("tapYield sigue la fórmula 1 × 3.8^(t−1)")
    func tapYieldSigueLaFormula() {
        #expect(economy.tapYield(forTier: 1) == 1)
        #expect(abs(economy.tapYield(forTier: 2) - 3.8) < 1e-12)
        #expect(abs(economy.tapYield(forTier: 3) - 14.44) < 1e-9)
        #expect(abs(economy.tapYield(forTier: 4) - 54.872) < 1e-9)
        #expect(abs(economy.tapYield(forTier: 9) - pow(3.8, 8)) < 1e-6)
    }

    @Test("tapYield es estrictamente creciente")
    func tapYieldEsCreciente() {
        for tier in 1..<30 {
            #expect(economy.tapYield(forTier: tier + 1) > economy.tapYield(forTier: tier))
        }
    }

    @Test("passiveYield es tapYield × passiveRatio")
    func passiveYieldEsProporcionDelTap() {
        for tier in [1, 5, 17, 30] {
            #expect(abs(economy.passiveYield(forTier: tier) - economy.tapYield(forTier: tier) * 0.3) < 1e-9)
        }
    }

    @Test("passiveUnlockCost es tapYield × 100")
    func passiveUnlockCostEsMultiploDelTap() {
        for tier in [1, 9, 30] {
            #expect(abs(economy.passiveUnlockCost(forTier: tier) - economy.tapYield(forTier: tier) * 100) < 1e-9)
        }
    }

    @Test("oroTotal: floor((lifetime/divisor)^exponent), 0 bajo el divisor")
    func oroTotalSigueLaFormula() {
        #expect(economy.oroTotal(lifetimeEarnings: 0) == 0)
        #expect(economy.oroTotal(lifetimeEarnings: -5) == 0)
        #expect(economy.oroTotal(lifetimeEarnings: 999_999) == 0)
        #expect(economy.oroTotal(lifetimeEarnings: 1_000_000) == 1)
        #expect(economy.oroTotal(lifetimeEarnings: 4_000_000) == 2)
        #expect(economy.oroTotal(lifetimeEarnings: 9_000_000) == 3)
        #expect(economy.oroTotal(lifetimeEarnings: 1e12) == 1000)
    }

    @Test("oroTotal clampea en vez de trapear con magnitudes idle")
    func oroTotalClampeaSinTrapear() {
        // Int(Double) trapea desde 2^63; un idle llega ahí sin despeinarse.
        #expect(economy.oroTotal(lifetimeEarnings: .greatestFiniteMagnitude) == .max)
        #expect(StandardEconomy.clampedFloor(.infinity) == .max)
        #expect(StandardEconomy.clampedFloor(.nan) == .max)
        #expect(StandardEconomy.clampedFloor(9.2e18) == .max)
        #expect(StandardEconomy.clampedFloor(1e19) == .max)
        #expect(StandardEconomy.clampedFloor(-5) == 0)
        #expect(StandardEconomy.clampedFloor(0) == 0)
        #expect(StandardEconomy.clampedFloor(3.7) == 3)
    }

    @Test("globalMultiplier: 1 + oro × 0.02 × (1 + prestigeBonus)")
    func globalMultiplierPorOro() {
        #expect(economy.globalMultiplier(oroEarnedLifetime: 0, prestigeBonus: 0) == 1.0)
        #expect(abs(economy.globalMultiplier(oroEarnedLifetime: 50, prestigeBonus: 0) - 2.0) < 1e-12)
        // El bonus de prestigio amplifica el aporte del ORO, no el 1 base.
        #expect(abs(economy.globalMultiplier(oroEarnedLifetime: 50, prestigeBonus: 0.5) - 2.5) < 1e-12)
        #expect(abs(economy.globalMultiplier(oroEarnedLifetime: 10, prestigeBonus: 1.0) - 1.4) < 1e-12)
    }
}

// MARK: - Curva de contratación contextual al piso (F7 §3.3)

@Suite("Curva de hireQuote (F7 §3.3)")
struct HireQuoteCurveTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func quote(floor ordinal: Int, state: PlayerState) -> HireQuote? {
        TowerActions.hireQuote(
            floorOrdinal: ordinal, state: state, tiers: tiers,
            floorTable: floorTable, config: config, economy: economy
        )
    }

    @Test("f1 usa su override barato: 15 × 1.15^n")
    func f1CurvaBarata() throws {
        var (state, _, _) = try fxStateAndTower()
        let base = try #require(quote(floor: 0, state: state))
        #expect(abs(base.cost - 15) < 1e-9)
        #expect(base.purchases == 0)

        state.run.hireCounts["f1"] = 1
        let n1 = try #require(quote(floor: 0, state: state))
        #expect(abs(n1.cost - 17.25) < 1e-9)
        #expect(n1.purchases == 1)

        state.run.hireCounts["f1"] = 2
        let n2 = try #require(quote(floor: 0, state: state))
        #expect(abs(n2.cost - 19.8375) < 1e-9)
        #expect(n2.purchases == 2)
    }

    @Test("f2 usa el default punitivo: 100 × tapYield(T3) × 2^n")
    func f2CurvaPunitiva() throws {
        var (state, _, _) = try fxStateAndTower()
        // tapYield por FÓRMULA (3.8² = 14.44), no el campo almacenado del tipo.
        let base = try #require(quote(floor: 1, state: state))
        #expect(abs(base.cost - 1444) < 1e-9)
        #expect(base.purchases == 0)

        state.run.hireCounts["f2"] = 1
        let n1 = try #require(quote(floor: 1, state: state))
        #expect(abs(n1.cost - 2888) < 1e-9)
        #expect(n1.purchases == 1)
    }

    @Test("los contadores de compra son independientes por piso")
    func contadoresIndependientesPorPiso() throws {
        var (state, _, _) = try fxStateAndTower()
        // Comprar mucho en f1 no encarece f2.
        state.run.hireCounts["f1"] = 5
        let f2 = try #require(quote(floor: 1, state: state))
        #expect(abs(f2.cost - 1444) < 1e-9)
        #expect(f2.purchases == 0)
    }

    @Test("f1 cotiza su tier base: 'a'")
    func f1CotizaSuTierBase() throws {
        let (state, _, _) = try fxStateAndTower()
        let q = try #require(quote(floor: 0, state: state))
        #expect(q.type.id == "a")
    }

    @Test("f2 sin carrera elegida cotiza la primera rama alfabética")
    func f2SinCarreraEligeAlfabetico() throws {
        // T3 tiene ramas (c_prog/c_law); sin elección, determinismo alfabético.
        let (state, _, _) = try fxStateAndTower()
        let q = try #require(quote(floor: 1, state: state))
        #expect(q.type.id == "c_law")
    }

    @Test("f2 con carrera elegida cotiza la rama que matchea")
    func f2ConCarreraRespetaLaEleccion() throws {
        var (state, _, _) = try fxStateAndTower()
        // Mismo criterio que MergeRules.careerPath: match por sufijo del id.
        state.run.chosenCareerPath = "prog"
        let prog = try #require(quote(floor: 1, state: state))
        #expect(prog.type.id == "c_prog")

        state.run.chosenCareerPath = "law"
        let law = try #require(quote(floor: 1, state: state))
        #expect(law.type.id == "c_law")
    }

    @Test("floorOrdinal fuera de rango devuelve nil")
    func ordinalFueraDeRangoEsNil() throws {
        let (state, _, _) = try fxStateAndTower()
        #expect(quote(floor: -1, state: state) == nil)
        #expect(quote(floor: 99, state: state) == nil)
    }
}
