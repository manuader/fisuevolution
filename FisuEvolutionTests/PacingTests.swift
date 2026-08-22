import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Guardián del pacing (F7 §4): corre `PacingSimulator` (bot greedy, 4 sesiones
/// ×20 min/día + offline) contra el CONTENIDO REAL bundleado y asserta bandas
/// sobre la conducta medida. El reloj del sim salta por evento: ~470 h simuladas
/// corren en segundos.
///
/// ⚠️ **RE-PINEADO ENTERO EL 2026-08-21 (rebalance de pacing).** Las bandas de
/// antes medían un bot que **no era el jugador**: se construía sin catálogo de
/// mejoras permanentes, así que `meta.derivedEffects` viajaba en cero toda la
/// simulación —sin el tap ×6,0, sin el income ×3,0, sin `offline`, sin
/// `spawnCostDiscount` y sin `prestigeBonus`—, y tapeaba 3 veces por segundo en
/// vez de 6. Los targets del plan F7.1c se estaban asserteando contra una
/// ficción (`Docs/PROMPT-rebalance-pacing.md` §2.2).
///
/// Acá el simulador recibe `content.upgradesConfig` mapeado a
/// `PermanentUpgradeLine`, o sea el MISMO catálogo que compra el jugador. Que
/// las dos derivaciones de `derivedEffects` no se separen lo vigila
/// `PermanentUpgradesMirrorTests`, abajo en este mismo archivo.
///
/// **Las cuatro bandas son ±30 % de lo medido**, y cada una dice de qué corrida
/// salió. La corrida es siempre la misma y se puede repetir a mano:
///
///     cd Tools/pacing-sim && swift run -c release pacing-sim \
///       --economy ../../FisuEvolution/Resources/Data/economy.json \
///       --tiers ../../FisuEvolution/Resources/Data/tiers.json --max-days 90
///
/// (el CSV commiteado de esa corrida es `Docs/balance-run-t5-rebalance.csv`;
/// `--max-days 400` da los mismos hitos, porque dios llega a los 19,6 días).
///
/// ⚠️ **Las bandas fijan la CONDUCTA, los dos asserts del final fijan el
/// OBJETIVO.** Son cosas distintas y por eso están separadas: una banda de ±30 %
/// detecta regresiones y se re-pinea cada vez que el dueño cambia el balance a
/// propósito; `theOwnersTargetsAreMet` asserta lo que el dueño PIDIÓ —maxear las
/// siete líneas en 20-30 h activas y con 8 reencarnaciones o menos— y no se
/// re-pinea: si se pone en rojo, el juego dejó de cumplir el objetivo.
@Suite("Pacing (simulación contra targets F7)")
struct PacingTests {
    let report: PacingSimulator.Report
    let floorTable: FloorTable

    init() throws {
        let content = try GameContentLoader.load(from: .main)
        let simulator = try PacingSimulator(
            config: content.economy,
            tiers: content.tiers,
            upgrades: try Self.permanentLines(from: content.upgradesConfig)
        )
        report = simulator.run(maxDays: 90)
        floorTable = content.floorTable
    }

    /// El catálogo de la app traducido a lo que EconomyKit entiende.
    ///
    /// El paquete es PURO y no puede importar `UpgradesConfig` (arrastra
    /// `titleKey`, `iconKey` y moneda, o sea presentación), así que el mapeo lo
    /// hace el LLAMADOR — igual que `pacing-sim` con su `UpgradesFile`.
    ///
    /// Filtra por ORO porque es lo que el bot puede pagar: lo único que le entra
    /// al reencarnar es ORO. Hoy las siete líneas son de ORO y lo pinea
    /// `upgradeCatalogMatchesTunedValues`.
    ///
    /// El `Effect(rawValue:)` REVIENTA en vez de saltearse la línea: los dos
    /// enums son espejos con los mismos `rawValue` a propósito, y un tipo de
    /// efecto nuevo del lado de la app tiene que romper acá y no traducirse en
    /// silencio a "esta línea no existe" —que es exactamente cómo el bot dejaría
    /// de modelar al jugador sin que nadie se entere.
    static func permanentLines(from config: UpgradesConfig) throws -> [PermanentUpgradeLine] {
        try config.upgrades
            .filter { $0.currency == .oro }
            .map { line in
                let effect = try #require(
                    PermanentUpgradeLine.Effect(rawValue: line.effectType.rawValue),
                    "\(line.id): el efecto '\(line.effectType.rawValue)' no existe en EconomyKit"
                )
                return PermanentUpgradeLine(
                    id: line.id,
                    effect: effect,
                    magnitudePerLevel: line.magnitudePerLevel,
                    maxLevel: line.maxLevel,
                    baseCost: line.baseCost,
                    costGrowth: line.costGrowth
                )
            }
    }

    // MARK: Las cuatro bandas (la conducta medida)

    /// La fase fisura: cuánto tiempo ACTIVO se tarda en abrir el segundo piso.
    ///
    /// **28,0 s medidos** en la corrida del encabezado, ±30 %. Era una banda de
    /// 102-187 s contra el bot viejo: el tapeo al doble (3 → 6 taps/s) más las
    /// mejoras permanentes cortan el arranque a la mitad, y el resto lo hizo el
    /// rebalance.
    ///
    /// ⚠️ **Sigue sin cumplir el §4 del spec** ("fase fisura ≥20-30 min
    /// activos"), y por lejos. No es un descuido: el dueño priorizó el largo
    /// TOTAL (maxear en 20-30 h) y el tutorial corto es parte del pedido —el
    /// primer Fisura sale 25 monedas por decisión suya. Esta banda existe para
    /// detectar que el arranque se mueva, no para prometer los 20 min.
    @Test("la fase fisura dura 20-36 s activos")
    func strugglingPhaseLength() throws {
        let secondFloor = floorTable[1].id
        let active = try #require(report.floorUnlockActiveSeconds[secondFloor])
        #expect(active >= 19.6 && active <= 36.4, "\(secondFloor): \(active) s activos")
    }

    /// El gradiente del arco pre-prestigio, en tiempo ACTIVO por piso.
    ///
    /// Diseño del assert (ver `Docs/balance-log.md` §F7.1): los unlocks se pegan
    /// a los inicios de sesión del modelo humano (el offline paga cadenas
    /// enteras durante los gaps), así que el ratio PISO A PISO es discreto por
    /// estructura, no por curva. Se asserta la MEDIA GEOMÉTRICA del arco
    /// urban→island más una guarda anti-acantilado por paso. Post-island los
    /// ratios tienden a 1 POR DISEÑO (sweep de reencarnación) y quedan afuera.
    ///
    /// **Medido en la corrida del encabezado**: ×17,28 (corporate) · ×24,80
    /// (luxury) · ×3,70 (island), geomean **×11,66**. Bandas: geomean ±30 % y la
    /// guarda en el peor paso +30 % (24,80 × 1,3 = 32,2). Venían de una geomean
    /// de 4,0-7,5 y una guarda de 32 contra el bot viejo — la guarda queda en el
    /// mismo número por coincidencia de dos calibraciones distintas.
    @Test("el gradiente del arco pre-prestigio es ~8-15× por piso")
    func floorGradient() throws {
        // Pisos 2..5 (urban→island): el arco antes de que las reencarnaciones
        // barran pisos enteros de una pasada.
        let arc = (1...4).map { floorTable[$0].id }
        let actives = try arc.map {
            try #require(report.floorUnlockActiveSeconds[$0], "\($0) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let ratio = actives[index] / actives[index - 1]
            #expect(ratio >= 1.0 && ratio <= 32.2, "acantilado en \(arc[index]): ×\(ratio)")
        }
        let geomean = pow(actives[actives.count - 1] / actives[0], 1.0 / Double(actives.count - 1))
        #expect(geomean >= 8.16 && geomean <= 15.16, "gradiente geomean ×\(geomean)")
    }

    /// **62,00 h de PARED medidas** en la corrida del encabezado, ±30 %. Venía
    /// de una banda de 0,05-0,25 h: con el bot viejo reencarnar era un trámite
    /// del primer minuto, y el rebalance lo convirtió en un hito —que era el
    /// pedido del dueño ("casi nunca conviene reencarnar hasta estar muy
    /// avanzado").
    ///
    /// De pared y no activas a propósito: 62 h de pared son **3,67 h activas**,
    /// y el número que mide la espera del jugador es el de calendario.
    @Test("la 1ª reencarnación cae entre 43 y 81 h de pared")
    func firstReincarnation() throws {
        let wall = try #require(report.firstReincarnationWall, "nunca reencarnó")
        #expect(wall >= 43.40 * 3600 && wall <= 80.60 * 3600, "1ª reencarnación: \(wall / 3600) h")
    }

    /// **470,26 h de PARED medidas** (26,59 h ACTIVAS), ±30 %, con **9
    /// reencarnaciones**. Venía de 242-449 h con ≥3.
    ///
    /// El assert de forma que importa no es el largo sino la relación: dios
    /// (26,59 h activas) queda **×1,11 más lejos que maxear** (24,00 h), o sea
    /// las skins doradas llegan antes que el final. Eso lo asserta
    /// `theOwnersTargetsAreMet`.
    @Test("dios llega entre 329 y 611 h de pared con ≥3 reencarnaciones")
    func godTiming() throws {
        let wall = try #require(report.godWall, "dios nunca llegó (maxTier \(report.finalMaxTier))")
        #expect(wall >= 329.18 * 3600 && wall <= 611.33 * 3600, "dios: \(wall / 3600) h")
        #expect(report.reincarnations >= 3, "reencarnaciones: \(report.reincarnations)")
    }

    // MARK: El objetivo del dueño (esto NO se re-pinea)

    /// Los dos números que el dueño puso como objetivo del rebalance, y el
    /// único test del suite que **no** es una banda alrededor de lo medido:
    ///
    /// 1. **Ganarlo al máximo —las siete líneas al tope, que es lo que
    ///    desbloquea las skins doradas— cuesta 20-30 h ACTIVAS.** Medido: 24,00
    ///    h, el medio de la banda. Venía de 15,49 h (corto) y el rebalance lo
    ///    subió sin volver a alargar la pared.
    /// 2. **Se llega con 8 reencarnaciones o menos.** Medido: 8, justo en el
    ///    techo. El bot reencarna al DUPLICAR su ORO histórico, así que las
    ///    reencarnaciones para maxear son ≈ log₂(costo total en ORO) y
    ///    log₂(193) = 7,6: el techo y el catálogo están atados, y por eso
    ///    `upgradeCatalogMatchesTunedValues` pinea los 193.
    ///
    /// Y la forma que el dueño pidió: **dios más lejos que las skins doradas**.
    @Test("se gana al máximo en 20-30 h activas y con ≤8 reencarnaciones")
    func theOwnersTargetsAreMet() throws {
        let maxed = try #require(
            report.maxedUpgradesActiveSeconds,
            "las siete líneas nunca llegaron al tope: \(report.finalPermanentUpgradeLevels)"
        )
        #expect(maxed >= 20 * 3600 && maxed <= 30 * 3600, "maxear las siete: \(maxed / 3600) h activas")

        let reincarnations = try #require(report.reincarnationsAtMaxedUpgrades)
        #expect(reincarnations <= 8, "reencarnaciones al maxear: \(reincarnations)")

        // Dios queda DESPUÉS de las skins doradas: si se diera vuelta, maxear
        // dejaría de ser una meta y pasaría a ser un trámite del final.
        let god = try #require(report.floorUnlockActiveSeconds[floorTable[floorTable.count - 1].id])
        #expect(god > maxed, "dios \(god / 3600) h activas vs maxear \(maxed / 3600) h")
    }
}

// MARK: - El espejo de EconomyKit

/// El guard que el docstring de `PermanentUpgrades.recomputeDerivedEffects`
/// prometía y **que no existía**.
///
/// Ese docstring dice que la derivación de EconomyKit es el espejo de
/// `UpgradeManager.recomputeDerivedEffects` y que un test impide que se separen.
/// El test que nombraba —`PermanentUpgradesTests`, en EconomyKitTests— sólo
/// prueba el lado de EconomyKit contra líneas escritas a mano: no puede ver el
/// app target, así que no podía comparar nada. El guard real tiene que vivir
/// acá, que es el único target que importa los dos.
///
/// Es una suite aparte de `PacingTests` a propósito: aquélla corre la simulación
/// entera en su `init`, y swift-testing construye una instancia POR TEST.
@Suite("Mejoras permanentes: el espejo de EconomyKit")
struct PermanentUpgradesMirrorTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func player(levels: [String: Int]) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: 0
        )
        state.meta.oroUpgradeLevels = levels
        state.meta.oroEarnedLifetime = 40
        return state
    }

    @Test("las dos derivaciones dan el mismo derivedEffects campo a campo")
    func bothDerivationsAgreeFieldByField() throws {
        let lines = try PacingTests.permanentLines(from: content.upgradesConfig)
        let economy = StandardEconomy(config: content.economy)

        // El mapeo filtra por ORO y la derivación de la app NO: si alguna línea
        // se pagara con plata, el bot no la vería y las dos columnas
        // divergirían con razón. Hoy las siete son de ORO.
        #expect(lines.count == content.upgradesConfig.upgrades.count,
                "hay líneas que no se pagan con ORO: el espejo dejaría de ser comparable")

        let alTope = Dictionary(uniqueKeysWithValues: content.upgradesConfig.upgrades.map { ($0.id, $0.maxLevel) })
        let escenarios: [(String, [String: Int])] = [
            ("sin comprar nada", [:]),
            ("a mitad de camino", ["income": 3, "tap": 1, "crit": 7, "spawn": 2, "offline": 5]),
            ("las siete al tope", alTope),
            // Un save anterior al rebalance: trae más niveles de los que la línea
            // admite hoy. Las dos derivaciones tienen que clampear IGUAL — que es
            // justo el borde donde una copia se separa de la otra sin ruido.
            ("un save viejo por encima del tope", alTope.mapValues { $0 * 3 }),
        ]

        for (nombre, niveles) in escenarios {
            var app = player(levels: niveles)
            var kit = app
            UpgradeManager.recomputeDerivedEffects(
                state: &app,
                config: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                economy: economy
            )
            PermanentUpgrades.recomputeDerivedEffects(state: &kit, lines: lines, economy: economy)

            #expect(app.meta.derivedEffects.incomeMultiplier == kit.meta.derivedEffects.incomeMultiplier, "\(nombre)")
            #expect(app.meta.derivedEffects.tapMultiplier == kit.meta.derivedEffects.tapMultiplier, "\(nombre)")
            #expect(app.meta.derivedEffects.critChance == kit.meta.derivedEffects.critChance, "\(nombre)")
            #expect(app.meta.derivedEffects.offlineEfficiency == kit.meta.derivedEffects.offlineEfficiency, "\(nombre)")
            #expect(app.meta.derivedEffects.goldenChance == kit.meta.derivedEffects.goldenChance, "\(nombre)")
            #expect(app.meta.derivedEffects.spawnDiscount == kit.meta.derivedEffects.spawnDiscount, "\(nombre)")
            #expect(app.meta.derivedEffects.prestigeBonus == kit.meta.derivedEffects.prestigeBonus, "\(nombre)")
            // El multiplicador global cuelga del `prestigeBonus` que las dos
            // acaban de escribir: si se separaran, el bot ganaría plata a otro
            // ritmo que el juego.
            #expect(app.meta.globalMultiplier == kit.meta.globalMultiplier, "\(nombre)")
        }
    }

    /// El escenario que hace que la comparación de arriba pruebe algo: con las
    /// siete al tope los efectos NO son los neutros, así que dos derivaciones
    /// rotas en cero seguirían empatando pero no acá.
    @Test("con las siete al tope el espejo compara efectos que no son el neutro")
    func theMirrorComparesNonNeutralEffects() throws {
        let lines = try PacingTests.permanentLines(from: content.upgradesConfig)
        let economy = StandardEconomy(config: content.economy)
        var kit = player(
            levels: Dictionary(uniqueKeysWithValues: content.upgradesConfig.upgrades.map { ($0.id, $0.maxLevel) })
        )
        PermanentUpgrades.recomputeDerivedEffects(state: &kit, lines: lines, economy: economy)

        // Los siete efectos del catálogo de hoy, derivados a mano: base + tope ×
        // magnitud. Escritos y no calculados con la misma fórmula que el código
        // bajo test, que sería tautológico.
        #expect(kit.meta.derivedEffects.incomeMultiplier == 3.0)        // 1 + 10 × 0,2
        #expect(kit.meta.derivedEffects.tapMultiplier == 6.0)           // 1 + 10 × 0,5
        #expect(kit.meta.derivedEffects.critChance == 0.25)             // 0 + 10 × 0,025
        #expect(abs(kit.meta.derivedEffects.offlineEfficiency - 0.85) < 1e-12)  // 0,35 + 10 × 0,05
        #expect(abs(kit.meta.derivedEffects.goldenChance - 0.05) < 1e-12)       // 0 + 10 × 0,005
        #expect(abs(kit.meta.derivedEffects.spawnDiscount - 0.30) < 1e-12)      // 0 + 10 × 0,03
        #expect(abs(kit.meta.derivedEffects.prestigeBonus - 0.05) < 1e-12)      // 0 + 10 × 0,005
    }
}
