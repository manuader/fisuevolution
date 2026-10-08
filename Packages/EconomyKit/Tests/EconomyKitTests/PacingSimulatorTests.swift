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
///
/// La compuerta va con la distancia REAL del juego: el bot la consume
/// (`nextAction` filtra el backfill con `TowerActions.canHire`), así que una
/// fixture sin compuerta mediría un bot que compra donde el jugador no puede.
/// Lo que la compuerta hace por sí sola lo mide `HireGateTests`; acá está para
/// que el instrumental corra contra la torre que existe.
private func upConfig(maxTier: Int = 20, gateTierDistance: Int = 5) -> EconomyConfig {
    let floors = stride(from: 1, through: maxTier, by: 4).enumerated().map { index, first in
        FloorDef(
            id: "f\(index + 1)",
            background: "alley",
            firstTier: first,
            lastTier: first + 3,
            capacity: 10,
            incomeMultiplier: pow(2.0, Double(index)),
            hireCostMultiplierOverride: index == 0 ? 25 : nil
        )
    }
    return EconomyConfig(
        schemaVersion: 2,
        baseTapYieldTier1: 1,
        yieldGrowthPerTier: 2.8,
        passiveRatio: 0.5,
        passiveUnlockCostMultiplier: 60,
        hire: .init(defaultCostMultiplier: 600, defaultCostGrowth: 1.2,
                    priceGrowthPerTier: 1.5, gateTierDistance: gateTierDistance),
        charUpgrades: .init(baseCostMultiplier: 50, costGrowth: 4.0, effectStepPerLevel: 1.0, maxLevel: 19),
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

private func upSimulator(upgrades: [PermanentUpgradeLine] = [], maxTier: Int = 20) throws -> PacingSimulator {
    try PacingSimulator(config: upConfig(maxTier: maxTier), tiers: upTiers(maxTier: maxTier), upgrades: upgrades)
}

/// Lo que distingue dos corridas del bot: si una perilla no mueve esto, el
/// simulador no la lee (trampa 28: un knob horneado no hace nada).
private func fingerprint(_ report: PacingSimulator.Report) -> [Double] {
    [report.godActive ?? -1, Double(report.reincarnations), report.finalLifetimeEarnings, Double(report.finalMaxTier)]
        + report.reincarnationActiveSeconds
}

// MARK: - Tests

@Suite("PacingSimulator: las perillas de E2a")
struct PacingSimulatorKnobTests {
    @Test("con el reintegro en cero el bot juega exactamente igual que sin la clave")
    func zeroRefundIsTheBaseline() throws {
        let base = try upSimulator().run(maxDays: 5)
        let tuned = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(mergeRefundCounts: 0)), tiers: upTiers()).run(maxDays: 5)
        #expect(fingerprint(tuned) == fingerprint(base))
    }

    @Test("el simulador lee el reintegro")
    func theSimulatorReadsTheRefund() throws {
        let base = try upSimulator().run(maxDays: 5)
        let tuned = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(mergeRefundCounts: 1)), tiers: upTiers()).run(maxDays: 5)
        #expect(fingerprint(tuned) != fingerprint(base))
    }
}

/// El bot compra las siete mejoras permanentes con ORO. Sin esto todo
/// `derivedEffects` viajaba en cero durante la simulación entera —le faltaban el
/// **tap ×6,0** y el **income ×3,0** que el jugador real sí tiene— y calibrar
/// knobs contra ese bot era tunear contra una ficción
/// (`Docs/PROMPT-rebalance-pacing.md` §2.2).
///
/// Los dos números van como MULTIPLICADOR y no como sumando a propósito: las
/// líneas suman (`tap` 10 × 0,5 = +5,0 sobre una base de 1,0), y escribir uno de
/// cada forma —"tap +5,0" y "income +3,0"— mezclaba las unidades en la misma
/// frase.
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
        // La escalera va a 40 tiers y no a los 20 de siempre: desde que el bot
        // compra cualquier tier habilitado (y no sólo los bases) los 20 se
        // terminan dentro del horizonte, `run` corta en dios y la comparación
        // deja de ser justa — que es lo que el assert de abajo vigila.
        let without = try upSimulator(maxTier: 40).run(maxDays: 2)
        let with = try upSimulator(upgrades: upCheapLines(), maxTier: 40).run(maxDays: 2)
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
    @Test("la política de reencarnación por defecto es duplicar, como siempre")
    func defaultPolicyIsDoubling() {
        #expect(PacingSimulator.HumanModel().reincarnation == .whenOroMultiplies(1))
    }

    @Test("subir el umbral hace que el bot reencarne menos veces")
    func aHigherThresholdMeansFewerReincarnations() throws {
        let doubling = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let atTheWall = try PacingSimulator(
            config: upConfig(),
            tiers: upTiers(),
            human: .init(reincarnation: .whenOroMultiplies(1_000)),
            upgrades: upCheapLines()
        ).run(maxDays: 5)
        #expect(
            atTheWall.reincarnations < doubling.reincarnations,
            "con umbral 1000: \(atTheWall.reincarnations) vs duplicando: \(doubling.reincarnations)"
        )
    }

    /// La queja del dueño del 2026-08-22 —"en menos de una hora llegué de fisura
    /// a dios SIN REINICIAR"— es una política que el simulador no podía correr:
    /// subir el umbral no alcanza, porque el múltiplo se aplica sobre el ORO
    /// histórico y ése arranca en CERO. `N × 0 = 0` para cualquier N finito, así
    /// que la primera reencarnación caía igual con umbral 1 que con 1.000 y la
    /// corrida "sin reencarnar" era inexpresable.
    @Test("con la política `never` el bot no reencarna ni una vez")
    func theNeverPolicyNeverReincarnates() throws {
        let sinReencarnar = try PacingSimulator(
            config: upConfig(),
            tiers: upTiers(),
            human: .init(reincarnation: .never),
            upgrades: upCheapLines()
        ).run(maxDays: 5)

        #expect(sinReencarnar.reincarnations == 0)
        #expect(sinReencarnar.reincarnationActiveSeconds.isEmpty)
        #expect(sinReencarnar.firstReincarnationWall == nil)
        // Sin reencarnar no entra ORO, y sin ORO no hay mejoras permanentes: es
        // exactamente el jugador del que se queja el dueño.
        #expect(sinReencarnar.finalPermanentUpgradeLevels.isEmpty)
        #expect(sinReencarnar.maxedUpgradesActiveSeconds == nil)

        // Y que el cero lo produce la POLÍTICA, no un horizonte corto: la misma
        // economía con el umbral de siempre sí reencarna.
        let duplicando = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(duplicando.reincarnations > 0)
    }

    /// Dios publicaba sólo el reloj de PARED y el dueño mide en horas de dedo.
    /// Con la economía embarcada los dos números se podían sacar de la tabla de
    /// pisos —`god_realm` va del tier 37 al 37, o sea abre justo en el tier
    /// máximo—, pero eso es una coincidencia de ESA config: un piso final con
    /// varios tiers abre antes de que se llegue a dios.
    @Test("dios publica su tiempo ACTIVO, no sólo el de pared")
    func godPublishesActiveTime() throws {
        // La compuerta baja a 1 porque la torre baja a 8 tiers: con la distancia
        // real (5) sobre una escalera de 8, contratar cualquier cosa que no sea
        // el tier base es imposible POR CONSTRUCCIÓN —el t5 pediría una frontera
        // de 10, que no existe— y el bot se queda mergeando fisuras. La
        // proporción del juego (37 tiers, distancia 5) acá son ~1.
        let report = try PacingSimulator(
            config: upConfig(maxTier: 8, gateTierDistance: 1), tiers: upTiers(maxTier: 8)
        ).run(maxDays: 5)
        let wall = try #require(report.godWall, "la escalera corta tiene que llegar a dios")
        let active = try #require(report.godActive)
        #expect(active > 0 && active <= wall, "activo \(active) vs pared \(wall)")
        // El piso de arriba de esta fixture abre en su firstTier (5) y dios es
        // el 8: por eso `godActive` no puede derivarse de la tabla de pisos.
        let topFloor = try #require(report.floorUnlockActiveSeconds["f2"])
        #expect(topFloor < active, "f2 abre en el tier 5 y dios es el 8")
    }

    /// **Las fusiones cuestan tiempo, y hasta el 2026-08-23 salían gratis.**
    ///
    /// Era un sesgo del instrumento, no una simplificación: fusionar es el verbo
    /// central del juego —una acción por fusión, arrastrando o con doble toque— y
    /// subir un tier de frontera pide `2^N − 1` fusiones. Con el merge gratis el
    /// simulador medía a un jugador que compra con el dedo y fusiona con la
    /// mente, y cualquier cambio en la proporción compras/fusiones salía medido
    /// mal.
    ///
    /// El test lo mide donde no puede confundirse con otra cosa: la MISMA
    /// economía, corrida dos veces, cambiando sólo `mergeSeconds`. Con el merge
    /// gratis la partida es estrictamente más corta.
    @Test("cobrar las fusiones alarga la partida y sólo eso la mueve")
    func chargingMergesLengthensTheRun() throws {
        let gratis = try PacingSimulator(
            config: upConfig(), tiers: upTiers(),
            human: .init(mergeSeconds: 0), upgrades: upCheapLines()
        ).run(maxDays: 8)
        let cobrado = try PacingSimulator(
            config: upConfig(), tiers: upTiers(),
            human: .init(mergeSeconds: 1), upgrades: upCheapLines()
        ).run(maxDays: 8)

        let sinCobrar = try #require(gratis.godActive, "la fixture tiene que llegar a dios")
        let conCobro = try #require(cobrado.godActive)
        #expect(conCobro > sinCobrar, "\(conCobro) s no es más que \(sinCobrar) s")
        // Y el default del modelo humano es COBRARLAS: un `HumanModel()` sin
        // argumentos tiene que medir al jugador que mueve el dedo.
        #expect(PacingSimulator.HumanModel().mergeSeconds == 1)
        #expect(PacingSimulator.HumanModel().hireSeconds == 1)
    }

    /// **La regla de selección de contrataciones, pineada el 2026-08-23 con el
    /// precio anclado a la frontera.**
    ///
    /// Escenario: la frontera en el tier 10, la compuerta en 5. Lo contratable
    /// va del t1 —el exento— al t5, y el que gana es el **t4**: el tope del piso
    /// barato. El t1 es MÁS BARATO en pesos (mismo piso, mismo multiplicador de
    /// 25, tres tiers más abajo) y aun así es peor negocio, porque hacen falta
    /// 2⁹ = 512 para una unidad de frontera contra 2⁶ = 64 del t4.
    ///
    /// ⚠️ **La regla vieja (`min(by: cost)`) habría elegido el t1**, y ésa era
    /// la respuesta correcta hasta que el precio dejó de seguir a
    /// `tapYield(tier)`: con la curva vieja lo más barato era también lo más
    /// eficiente. Un bot que siga comparando precios mide a un jugador que se
    /// queda mergeando fisuras mientras la tienda le vende arriba.
    ///
    /// Que gane el t4 y no el t5 es la COSTURA del piso barato (25 contra 600),
    /// la misma que `elDescuentoDelCallejonSeAgotaSolo` pinea contra el juego
    /// real: adentro de un mismo multiplicador gana el más alto, y el salto de
    /// multiplicador es lo único que puede darlo vuelta.
    @Test("el bot contrata lo más barato POR UNIDAD DE FRONTERA, no lo más barato")
    func theBotHiresTheBestCostPerFrontierUnit() throws {
        let simulator = try upSimulator()
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        state.run.unlockedFloors = ["f1", "f2", "f3"]
        state.run.maxTierReached = 10
        state.run.coins = 1e12

        let elegido = try #require(simulator.bestHire(state: state))
        #expect(elegido.typeId == "t4", "el tope del piso barato, no el t1 que sale menos")

        // Y el escenario prueba algo: el t1 estaba ahí, era legal y era MÁS
        // BARATO. Lo que lo deja afuera es que su unidad de frontera sale
        // 2³/1,5³ = 2,37 veces más — 512 fisuras contra 64 t4.
        let config = upConfig()
        let unidad = { (tier: Int, piso: Int) in
            pow(2, Double(10 - tier)) * config.hireCost(
                floor: config.floors[piso], tier: tier, frontierTier: 10, purchases: 0
            )
        }
        #expect(
            config.hireCost(floor: config.floors[0], tier: 1, frontierTier: 10, purchases: 0)
                < config.hireCost(floor: config.floors[0], tier: 4, frontierTier: 10, purchases: 0),
            "el t1 tiene que ser el barato para que el test pruebe la regla"
        )
        #expect(abs(unidad(1, 0) / unidad(4, 0) - pow(2 / 1.5, 3)) < 1e-9)
        // Y dentro del piso caro pasa lo mismo: el t5 le gana al t8 por el salto
        // de multiplicador, pero entre t5 y t6 gana el más alto.
        #expect(unidad(5, 1) > unidad(6, 1))
    }

    /// La regla que el efecto secuencial invalidó, pineada para que no se
    /// vuelva a ir sola.
    ///
    /// Escenario: dos tipos con el MISMO aporte base, uno en nivel 0 y otro ya
    /// mejorado. El mejorado aporta más —su multiplicador comprado está adentro
    /// de `contribution`— pero su próximo nivel gana lo mismo en absoluto y
    /// cuesta `costGrowth^nivel` más. **La regla vieja (`max(by: contribution)`)
    /// habría elegido al mejorado**, que es la peor compra del tablero.
    @Test("el bot mejora al que da más income por moneda, no al que más aporta")
    func theBotPicksTheBestGainPerCoin() throws {
        let simulator = try upSimulator()
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        // Mismo tier ⇒ mismo `tapYield`, así que los dos tienen el mismo aporte
        // base y el mismo precio base: lo único que los diferencia es el nivel.
        state.run.units = ["t1": 1, "t2": 1]
        state.run.passiveUnlocked = ["t1": true, "t2": true]
        state.run.charUpgradeLevels = ["t2": 4]

        let elegido = try #require(simulator.bestCharUpgrade(state: state))
        #expect(elegido.typeId == "t1", "eligió \(elegido.typeId)")

        // Y los números que lo justifican, cotizando cada uno por separado.
        func soloUno(_ typeId: String) throws -> PacingSimulator.CharUpgradeChoice {
            var solo = state
            solo.run.units = [typeId: 1]
            return try #require(simulator.bestCharUpgrade(state: solo))
        }
        let barato = try soloUno("t1")
        let caro = try soloUno("t2")

        // Precio: `baseCostMultiplier × tapYield(tier) × costGrowth^nivel`, con
        // la fixture en 50 · 4,0 y `yieldGrowthPerTier` 2,8. t1 en nivel 0 sale
        // 50 × 1 × 1; t2 en el nivel 4 sale 50 × 2,8 × 4⁴ = 35.840, o sea 716,8
        // veces más caro.
        #expect(barato.cost == 50)
        #expect(caro.cost == 35_840)

        // Y la regla vieja lo habría elegido POR PARTIDA DOBLE: t2 no sólo
        // aporta más (su multiplicador ×5 está adentro de `contribution`), sino
        // que su próximo nivel gana más en ABSOLUTO, porque vive un tier arriba.
        #expect(caro.gain > barato.gain)
        // Aun así es la peor compra del tablero: 716,8× el precio por 2,8× la
        // ganancia.
        #expect(caro.gain / caro.cost < barato.gain / barato.cost)
    }

    /// Nadie con nivel que comprar ⇒ `nil`, y no una elección inventada sobre un
    /// tipo al tope que `nextLevelCost` ya rechaza.
    @Test("sin pasivo desbloqueado no hay mejora que elegir")
    func noUnlockedPassiveMeansNoChoice() throws {
        let simulator = try upSimulator()
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        state.run.units = ["t1": 1]
        state.run.passiveUnlocked = [:]
        #expect(simulator.bestCharUpgrade(state: state) == nil)
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
            // `isFinite` y no `> 0`: el escape de income cero devuelve
            // `.infinity`, que es > 0 y colaba una métrica sin medir.
            #expect(seconds.isFinite && seconds > 0, "\(floorId): \(seconds)")
        }
    }

    @Test("sin compras todavía, el pico no inventa un 0,0 s")
    func peakHireIsAbsentBeforeAnyPurchase() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        // El piso 0 se registra en el segundo cero, antes de comprar nada. Un
        // `0,0 s` ahí colisionaría con el "0,0 s = contratar es gratis" que es el
        // hallazgo central del rebalance, así que la serie no trae la clave.
        let ground = try #require(report.floorUnlockWallSeconds.keys.sorted().first { report.floorUnlockWallSeconds[$0] == 0 })
        #expect(report.floorUnlockPeakHireSeconds[ground] == nil, "el piso \(ground) no compró nada todavía")
        #expect(report.floorUnlockPeakHireType[ground] == nil)
        // Y donde SÍ hay dato, es un número real y trae de qué tipo es.
        for (floorId, seconds) in report.floorUnlockPeakHireSeconds {
            #expect(seconds.isFinite, "\(floorId): \(seconds)")
            #expect(report.floorUnlockPeakHireType[floorId] != nil)
        }
    }

    @Test("el compounding de hireCostGrowth se mide donde el bot compra de verdad")
    func peakHirePurchasesAreRecorded() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        // `floorUnlockHireSeconds` NO puede ver `hireCostGrowth`: un piso se
        // abre mergeando, así que el contador de su tier base vale 0 al abrirlo
        // y `growth^0 = 1`. El compounding vive en el tipo que el bot compra una
        // y otra vez, y es esta serie la que lo publica.
        let peaks = report.floorUnlockPeakHirePurchases
        #expect(!peaks.isEmpty)
        #expect(peaks.values.contains { $0 > 0 }, "el bot compró algo: \(peaks)")
        // Dos corridas de la misma economía eligen el MISMO tipo.
        //
        // ⚠️ Y lo que este assert NO puede probar es lo que su versión anterior
        // decía probar: el seed de hashing de `Dictionary` es POR PROCESO, así
        // que dos corridas adentro del mismo test recorren el diccionario en el
        // mismo orden aunque el desempate no existiera. Lo que descarta el seed
        // es el `sorted` de `peakHire` —empate de compras se rompe por `key`
        // ascendente, no por orden de iteración—, y eso se lee en el código, no
        // acá. Lo que este test sí atrapa es una corrida que dependa de estado
        // mutable compartido entre instancias del simulador.
        let otra = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(otra.floorUnlockPeakHireType == report.floorUnlockPeakHireType)
        #expect(otra.floorUnlockPeakHirePurchases == peaks)
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

    @Test("un nivel guardado por encima del tope no cobra de más")
    func storedLevelsAboveTheCapAreClamped() {
        // El rebalance de pacing bajó `income` y `tap` de 20 niveles a 10 y
        // `crit` de 25 a 10. Un save anterior trae los niveles viejos, y sin
        // clamp cobraría un efecto que ya no se puede comprar: income ×5,0
        // donde el tope es 3,0, tap ×11,0 donde el tope es 6,0, y un crit de
        // 0,25 que la app recorta por `EffectCaps` y este espejo no.
        let catalogoNuevo: [PermanentUpgradeLine] = [
            .init(id: "income", effect: .incomeMultiplier, magnitudePerLevel: 0.2, maxLevel: 10, baseCost: 1, costGrowth: 1.1),
            .init(id: "tap", effect: .tapMultiplier, magnitudePerLevel: 0.5, maxLevel: 10, baseCost: 1, costGrowth: 1.1),
            .init(id: "crit", effect: .critChance, magnitudePerLevel: 0.025, maxLevel: 10, baseCost: 1, costGrowth: 1.2),
        ]
        var viejo = fxState()
        viejo.meta.oroUpgradeLevels = ["income": 20, "tap": 20, "crit": 25]
        PermanentUpgrades.recomputeDerivedEffects(state: &viejo, lines: catalogoNuevo, economy: fxEconomy())
        #expect(abs(viejo.meta.derivedEffects.incomeMultiplier - 3.0) < 1e-9)
        #expect(abs(viejo.meta.derivedEffects.tapMultiplier - 6.0) < 1e-9)
        #expect(abs(viejo.meta.derivedEffects.critChance - 0.25) < 1e-9)

        // Y da exactamente lo mismo que un save al tope nuevo: el save viejo no
        // puede quedar ni mejor ni peor que el que compró las diez.
        var alTope = fxState()
        alTope.meta.oroUpgradeLevels = ["income": 10, "tap": 10, "crit": 10]
        PermanentUpgrades.recomputeDerivedEffects(state: &alTope, lines: catalogoNuevo, economy: fxEconomy())
        #expect(viejo.meta.derivedEffects == alTope.meta.derivedEffects)
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
