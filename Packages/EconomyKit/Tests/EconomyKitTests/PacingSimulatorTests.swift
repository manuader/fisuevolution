import Foundation
import Testing
@testable import EconomyKit

// MARK: - Fixtures propias del simulador

/// Escalera larga a propósito. Con la fixture chica (4 tiers) el bot llega a
/// dios en la primera sesión y `run` corta ahí, o sea ANTES de la primera
/// reencarnación — que es el único momento en el que entra ORO y justo lo que
/// estos tests miden.
private func upTiers(maxTier: Int = 20) throws -> TierRepository {
    let types = (1...maxTier).map { tier in
        fxType(
            "t\(tier)",
            tier: tier,
            tapYield: pow(2.8, Double(tier - 1)),
            mergesInto: tier < maxTier ? "t\(tier + 1)" : nil
        )
    }
    return try TierRepository(types: types)
}

/// Espejo chico de `economy.json`: las mismas fórmulas con un `oro.divisor`
/// bajísimo, para que el ORO llegue dentro del horizonte del test (con el
/// divisor real harían falta cientos de días simulados por assert).
private func upConfig(maxTier: Int = 20) -> EconomyConfig {
    let floors = stride(from: 1, through: maxTier, by: 4).enumerated().map { index, first in
        FloorDef(
            id: "f\(index + 1)",
            background: "alley",
            firstTier: first,
            lastTier: first + 3,
            capacity: 10,
            incomeMultiplier: pow(2.0, Double(index)),
            hireCostMultiplierOverride: index == 0 ? 25 : nil,
            hireGateExempt: index == 1
        )
    }
    return EconomyConfig(
        schemaVersion: 2,
        baseTapYieldTier1: 1,
        yieldGrowthPerTier: 2.8,
        passiveRatio: 0.5,
        passiveUnlockCostMultiplier: 60,
        hire: .init(defaultCostMultiplier: 600, defaultCostGrowth: 1.2, tierPremium: 1.8),
        charUpgrades: .init(baseCostMultiplier: 50, costGrowth: 4.0, effectFactorPerLevel: 2.0, maxLevel: 20),
        oro: .init(divisor: 1000, exponent: 0.45, globalMultiplierPerOro: 0.18),
        critChanceBase: 0,
        critMultiplier: 5,
        offlineEfficiencyBase: 0.35,
        offlineCapHours: 10,
        floors: floors
    )
}

/// Catálogo barato: llega al tope dentro del horizonte del test.
private func upCheapLines() -> [PermanentUpgradeLine] {
    [
        PermanentUpgradeLine(
            id: "income", effect: .incomeMultiplier,
            magnitudePerLevel: 1.0, maxLevel: 3, baseCost: 1, costGrowth: 2
        ),
        PermanentUpgradeLine(
            id: "tap", effect: .tapMultiplier,
            magnitudePerLevel: 1.0, maxLevel: 3, baseCost: 1, costGrowth: 2
        ),
    ]
}

/// Catálogo inalcanzable: un solo nivel que cuesta más ORO del que la economía
/// entera produce en el horizonte.
private func upUnreachableLines() -> [PermanentUpgradeLine] {
    [
        PermanentUpgradeLine(
            id: "income", effect: .incomeMultiplier,
            magnitudePerLevel: 0.1, maxLevel: 1, baseCost: 1e18, costGrowth: 2
        )
    ]
}

private func upSimulator(upgrades: [PermanentUpgradeLine] = []) throws -> PacingSimulator {
    try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upgrades)
}

// MARK: - Tests

/// El bot compra las siete mejoras permanentes con ORO. Sin esto todo
/// `derivedEffects` viajaba en cero durante la simulación entera —le faltaban
/// el `tap +5,0` y el `income +3,0` que el jugador real sí tiene— y calibrar
/// knobs contra ese bot era tunear contra una ficción
/// (`Docs/PROMPT-rebalance-pacing.md` §2.2).
@Suite("PacingSimulator: las mejoras permanentes")
struct PacingSimulatorUpgradeTests {
    @Test("el bot gasta el ORO de la reencarnación en mejoras permanentes")
    func botBuysPermanentUpgrades() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(report.reincarnations > 0, "sin reencarnación no hay ORO que gastar")
        let levels = report.finalPermanentUpgradeLevels
        #expect(levels.values.reduce(0, +) > 0, "niveles comprados: \(levels)")
    }

    @Test("sin catálogo el bot no compra nada — es el modelo viejo, y sigue disponible")
    func withoutCatalogNothingIsBought() throws {
        let report = try upSimulator().run(maxDays: 5)
        #expect(report.finalPermanentUpgradeLevels.isEmpty)
        #expect(report.maxedUpgradesActiveSeconds == nil, "un catálogo vacío nunca está maxeado")
    }

    @Test("los efectos comprados entran en las fórmulas: con mejoras el bot gana más")
    func boughtUpgradesRaiseIncome() throws {
        let without = try upSimulator().run(maxDays: 2)
        let with = try upSimulator(upgrades: upCheapLines()).run(maxDays: 2)
        // La comparación sólo es justa si ninguna de las dos corridas terminó
        // temprano por llegar a dios (`run` corta ahí).
        #expect(without.godWall == nil && with.godWall == nil, "el horizonte del test tiene que quedar corto de dios")
        #expect(
            with.finalLifetimeEarnings > without.finalLifetimeEarnings,
            "con mejoras \(with.finalLifetimeEarnings) vs sin mejoras \(without.finalLifetimeEarnings)"
        )
    }

    @Test("maxedUpgradesActiveSeconds es nil mientras no estén las siete al tope")
    func maxedIsNilWhenUnreachable() throws {
        let report = try upSimulator(upgrades: upUnreachableLines()).run(maxDays: 5)
        #expect(report.reincarnations > 0, "el bot tiene que haber tenido ORO y no haberle alcanzado")
        #expect(report.maxedUpgradesActiveSeconds == nil)
        #expect(report.maxedUpgradesWall == nil)
        #expect(report.reincarnationsAtMaxedUpgrades == nil)
    }

    @Test("maxedUpgradesActiveSeconds es un número cuando las maxea")
    func maxedIsReportedWhenReached() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let active = try #require(report.maxedUpgradesActiveSeconds, "niveles: \(report.finalPermanentUpgradeLevels)")
        let wall = try #require(report.maxedUpgradesWall)
        #expect(active > 0 && active <= wall, "activo \(active) vs pared \(wall)")
        #expect(report.reincarnationsAtMaxedUpgrades != nil)
        for line in upCheapLines() {
            #expect(report.finalPermanentUpgradeLevels[line.id] == line.maxLevel)
        }
    }

    @Test("el modelo humano tapea a un ritmo defendible (5-8 por segundo)")
    func humanTapsAtDefensibleRate() {
        let rate = PacingSimulator.HumanModel().tapsPerSecond
        #expect(rate >= 5 && rate <= 8, "tapsPerSecond: \(rate)")
    }
}

/// El instrumental del rebalance: cuándo conviene reencarnar y si el costo de
/// progresar sigue el ritmo del ingreso. Los dos son mediciones —no cambian la
/// conducta del bot por defecto—, pero sin ellos las decisiones de la Task 5 se
/// defienden con intuición y esta bitácora ya documenta dos veces que la
/// intuición falla en esta economía.
@Suite("PacingSimulator: el instrumental del rebalance")
struct PacingSimulatorInstrumentTests {
    @Test("el umbral de reencarnación por defecto es duplicar, como siempre")
    func defaultThresholdIsDoubling() {
        #expect(PacingSimulator.HumanModel().reincarnationThresholdMultiple == 1)
    }

    @Test("subir el umbral hace que el bot reencarne menos veces")
    func aHigherThresholdMeansFewerReincarnations() throws {
        let doubling = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let atTheWall = try PacingSimulator(
            config: upConfig(),
            tiers: upTiers(),
            human: .init(reincarnationThresholdMultiple: 1_000),
            upgrades: upCheapLines()
        ).run(maxDays: 5)
        #expect(
            atTheWall.reincarnations < doubling.reincarnations,
            "con umbral 1000: \(atTheWall.reincarnations) vs duplicando: \(doubling.reincarnations)"
        )
    }

    @Test("el reporte guarda el tiempo ACTIVO de cada reencarnación")
    func everyReincarnationIsTimestamped() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(report.reincarnations > 1)
        #expect(report.reincarnationActiveSeconds.count == report.reincarnations)
        // La cadencia es la métrica del dueño ("una reencarnación cada 2,5-4 h
        // de juego activo"): sin orden creciente no se puede leer.
        #expect(report.reincarnationActiveSeconds == report.reincarnationActiveSeconds.sorted())
        #expect(report.reincarnationActiveSeconds.first == report.firstReincarnationActive)
    }

    @Test("el reporte guarda cuántos segundos de income cuesta el hire de cada piso")
    func hireCostIsRecordedInSecondsOfIncome() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        // Es LA evidencia de la divergencia costos-vs-ingresos: si el número se
        // desploma piso a piso, los precios se quedaron quietos mientras el
        // ingreso se multiplicaba.
        for (floorId, wall) in report.floorUnlockWallSeconds {
            let seconds = try #require(
                report.floorUnlockHireSeconds[floorId],
                "el piso \(floorId) se abrió en \(wall) y no dejó su costo"
            )
            #expect(seconds > 0)
        }
    }
}

/// La traducción niveles → `derivedEffects` es la misma que hace la app en
/// `UpgradeManager.recomputeDerivedEffects`. Vive acá porque el simulador es
/// puro y no puede llamar al app target; este test es lo que impide que las dos
/// se separen sin que nadie se entere.
@Suite("Mejoras permanentes: derivación de efectos")
struct PermanentUpgradesTests {
    private func lines() -> [PermanentUpgradeLine] {
        [
            .init(id: "income", effect: .incomeMultiplier, magnitudePerLevel: 0.1, maxLevel: 20, baseCost: 1, costGrowth: 2),
            .init(id: "tap", effect: .tapMultiplier, magnitudePerLevel: 0.25, maxLevel: 20, baseCost: 1, costGrowth: 2),
            .init(id: "offline", effect: .offlineEfficiency, magnitudePerLevel: 0.05, maxLevel: 10, baseCost: 2, costGrowth: 2.3),
            .init(id: "spawn", effect: .spawnCostDiscount, magnitudePerLevel: 0.03, maxLevel: 10, baseCost: 1, costGrowth: 2.2),
            .init(id: "crit", effect: .critChance, magnitudePerLevel: 0.01, maxLevel: 25, baseCost: 3, costGrowth: 2.5),
            .init(id: "golden", effect: .goldenTouchChance, magnitudePerLevel: 0.005, maxLevel: 10, baseCost: 4, costGrowth: 2.7),
            .init(id: "prestige", effect: .prestigeBonusPerSoulPoint, magnitudePerLevel: 0.005, maxLevel: 10, baseCost: 5, costGrowth: 3),
        ]
    }

    @Test("cada línea suma su efecto por nivel")
    func everyLineAddsItsEffect() {
        var state = fxState()
        state.meta.oroUpgradeLevels = [
            "income": 4, "tap": 2, "offline": 3, "spawn": 5, "crit": 6, "golden": 2, "prestige": 4,
        ]
        PermanentUpgrades.recomputeDerivedEffects(state: &state, lines: lines(), economy: fxEconomy())

        let effects = state.meta.derivedEffects
        #expect(abs(effects.incomeMultiplier - 1.4) < 1e-9)
        #expect(abs(effects.tapMultiplier - 1.5) < 1e-9)
        // La base sale de la config (`offlineEfficiencyBase` 0,5 en la fixture).
        #expect(abs(effects.offlineEfficiency - 0.65) < 1e-9)
        #expect(abs(effects.spawnDiscount - 0.15) < 1e-9)
        #expect(abs(effects.critChance - 0.06) < 1e-9)
        #expect(abs(effects.goldenChance - 0.01) < 1e-9)
        #expect(abs(effects.prestigeBonus - 0.02) < 1e-9)
    }

    @Test("el bonus de prestigio recalcula el multiplicador global")
    func prestigeBonusFeedsTheGlobalMultiplier() {
        var state = fxState()
        state.meta.oroEarnedLifetime = 100
        state.meta.oroUpgradeLevels = ["prestige": 4]
        PermanentUpgrades.recomputeDerivedEffects(state: &state, lines: lines(), economy: fxEconomy())
        // 1 + 100 × 0,02 × (1 + 0,02)
        #expect(abs(state.meta.globalMultiplier - 3.04) < 1e-9)
    }

    @Test("sin niveles, los efectos quedan en el neutro de la config")
    func noLevelsMeansNeutralEffects() {
        var state = fxState()
        PermanentUpgrades.recomputeDerivedEffects(state: &state, lines: lines(), economy: fxEconomy())
        #expect(state.meta.derivedEffects.incomeMultiplier == 1)
        #expect(state.meta.derivedEffects.tapMultiplier == 1)
        #expect(state.meta.derivedEffects.offlineEfficiency == 0.5)
        #expect(state.meta.derivedEffects.spawnDiscount == 0)
    }

    @Test("el precio del nivel siguiente es baseCost × growth^nivel")
    func nextLevelCostFollowsTheCurve() {
        let crit = PermanentUpgradeLine(
            id: "crit", effect: .critChance, magnitudePerLevel: 0.01,
            maxLevel: 25, baseCost: 3, costGrowth: 2.5
        )
        #expect(crit.cost(atLevel: 0) == 3)
        #expect(abs(crit.cost(atLevel: 3) - 3 * 2.5 * 2.5 * 2.5) < 1e-9)
    }

    @Test("un catálogo vacío nunca cuenta como maxeado")
    func emptyCatalogIsNeverMaxed() {
        #expect(PermanentUpgrades.allMaxed(levels: [:], lines: []) == false)
        #expect(PermanentUpgrades.allMaxed(levels: ["income": 99], lines: []) == false)
    }

    @Test("maxeado es TODAS las líneas al tope, no alguna")
    func maxedMeansEveryLine() {
        let catalog = lines()
        var levels = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.maxLevel) })
        #expect(PermanentUpgrades.allMaxed(levels: levels, lines: catalog))
        levels["crit"] = 24
        #expect(PermanentUpgrades.allMaxed(levels: levels, lines: catalog) == false)
    }
}
