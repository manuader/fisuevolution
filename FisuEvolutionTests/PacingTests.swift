import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Guardián del pacing (F7 §4): corre `PacingSimulator` (bot greedy, 4 sesiones
/// ×20 min/día + offline) contra el CONTENIDO REAL bundleado y asserta bandas
/// sobre la conducta medida. El reloj del sim salta por evento: ~590 h simuladas
/// corren en segundos.
///
/// ⚠️⚠️ **RE-PINEADO EL 2026-08-23 (cuarta ronda) Y `theOwnersTargetsAreMet`
/// SIGUE EN ROJO A PROPÓSITO.** Esta ronda atacó la causa raíz que midió la
/// tercera: el precio de contratar dejó de seguir a `tapYield(tier)` y pasó a
/// anclarse en **tu frontera**, con una pendiente por tier (1,5) por DEBAJO del
/// factor de merge. Con eso comprar hondo dejó de ser el atajo y la compuerta
/// pasó a ser un dial de dificultad real: medido, N=5 → 4,14 h y N=6 → 7,27 h,
/// donde antes N=4 → 6,67 h y N=6 → 5,34 h (o sea, al revés).
///
/// El bot también cambió, y por la misma razón: elegía la contratación **más
/// barata**, que hasta el 2026-08-22 era también la más eficiente y desde el
/// precio nuevo es la PEOR (el Fisura). Ahora elige la más barata por unidad de
/// frontera. Las dos correcciones juntas dejan la partida embarcada en **7,27 h
/// activas hasta maxear las siete** y **9,40 h hasta dios**, con la compuerta
/// en 6.
///
/// 🔴 **El contrato de 20-30 h sigue sin cumplirse, y la causa que queda está
/// medida**: ~la mitad del tiempo activo es apretar el botón (1 s por compra) y
/// no esperar plata, así que los knobs de precio son sublineales —×16 en
/// `defaultCostMultiplier` compra ×1,75 de partida—. El barrido completo está en
/// `Docs/balance-log.md`, cuarta ronda.
///
/// ⚠️ **RE-PINEADO EL 2026-08-22 (tercera ronda).** Esta ronda arregló DOS cegueras del bot —elegía
/// la mejora por personaje más cara y sólo compraba el tier BASE de cada piso,
/// cuando FisuJobs vende todo lo contratable— y con eso el instrumento pasó a
/// medir al jugador real. Lo que apareció: la partida dura **13,64 h activas
/// hasta dios** y **6,67 h hasta maxear las siete**, no las 24,67 h que la
/// ronda 2 creyó medir. Y sin reencarnar dios llega en **3,28 h activas**, que
/// es al minuto lo que el dueño reportó a mano ("me lo gané en 3 horas").
///
/// O sea: el contrato de 20-30 h nunca se cumplió; lo cumplía un bot que jugaba
/// mal. Las cuatro bandas se re-derivaron de la corrida nueva
/// (`Docs/balance-run-t8-compuerta.csv`); el objetivo del dueño **no se re-pinea
/// y por eso está rojo**. El diagnóstico completo y las salidas medidas están en
/// `Docs/balance-log.md` y en `Docs/SESION-2026-08-22-compuerta-por-distancia.md`.
///
/// ⚠️ **RE-PINEADO EL 2026-08-22 (segunda ronda de balance).** El efecto de las
/// mejoras POR PERSONAJE pasó de `2^nivel` a `1 + nivel` (pedido del dueño), y
/// con eso el ingreso del juego se derrumbó: maxear las siete pasó de 24,00 h a
/// **322,00 h**. La recalibración que lo devuelve al contrato movió dos knobs
/// —`charUpgrades.costGrowth` 4,0 → 1,5 y `oro.divisor` 3e12 → 1e9— y las cuatro
/// bandas se re-derivaron de la corrida nueva. La corrida está en
/// `Docs/balance-run-t7-secuencial.csv` y el porqué en `Docs/balance-log.md`.
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
/// (el CSV commiteado de esa corrida es `Docs/balance-run-t9-precio-frontera.csv`;
/// hace falta `--max-days 400`, porque dios llega a los 7,0 días).
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
    /// **78,0 s medidos** en la corrida del encabezado, ±30 %. Venía de 28,0 s:
    /// la cuarta ronda la casi triplicó sin tocar el Fisura, y no por un knob de
    /// arranque sino por la compuerta —con 6 tiers de distancia hacen falta 64
    /// Fisuras para el primer T7 y no 32—.
    ///
    /// ⚠️ **Sigue sin cumplir el §4 del spec** ("fase fisura ≥20-30 min
    /// activos"), aunque menos lejos. No es un descuido: el dueño priorizó el
    /// largo TOTAL (maxear en 20-30 h) y el tutorial corto es parte del pedido
    /// —el primer Fisura sale 25 monedas por decisión suya—. Esta banda existe
    /// para detectar que el arranque se mueva, no para prometer los 20 min.
    @Test("la fase fisura dura 55-101 s activos")
    func strugglingPhaseLength() throws {
        let secondFloor = floorTable[1].id
        let active = try #require(report.floorUnlockActiveSeconds[secondFloor])
        #expect(active >= 54.6 && active <= 101.4, "\(secondFloor): \(active) s activos")
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
    /// **Medido en la corrida del encabezado**: ×16,38 (corporate) · ×5,71
    /// (luxury) · ×1,83 (island), geomean **×5,55**. Bandas: geomean ±30 %
    /// (3,88-7,21) y la guarda en el peor paso +30 % (16,38 × 1,3 = 21,30).
    ///
    /// ⚠️ **La guarda del peor paso SUBIÓ de 10,21 a 21,30, y hay que decir por
    /// qué antes de leerlo como un aflojamiento.** El paso que la mueve es
    /// urbano → corporativo, y en tiempo absoluto son **1,3 min → 21,3 min**: el
    /// ratio es grande porque el arranque es cortísimo (el Fisura sale 25), no
    /// porque haya una pared. El acantilado que esta guarda nació para cazar
    /// —×90,86 en la ronda 2— eran **13,3 h** de un solo salto.
    ///
    /// Para que la banda no se debilite en la dimensión que sí importa, la
    /// cuarta ronda le puso al lado un assert ABSOLUTO —el que el dueño
    /// enunció—: `noHitoJumpIsLongerThanFourActiveHours`. El peor salto medido
    /// es de **2,02 h** (island → moon), contra las 10,0 h de la ronda 2 y las
    /// 4,45 h de la tercera.
    @Test("el gradiente del arco pre-prestigio es ~4-7× por piso")
    func floorGradient() throws {
        // Pisos 2..5 (urban→island): el arco antes de que las reencarnaciones
        // barran pisos enteros de una pasada.
        let arc = (1...4).map { floorTable[$0].id }
        let actives = try arc.map {
            try #require(report.floorUnlockActiveSeconds[$0], "\($0) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let ratio = actives[index] / actives[index - 1]
            #expect(ratio >= 1.0 && ratio <= 21.30, "acantilado en \(arc[index]): ×\(ratio)")
        }
        let geomean = pow(actives[actives.count - 1] / actives[0], 1.0 / Double(actives.count - 1))
        #expect(geomean >= 3.88 && geomean <= 7.21, "gradiente geomean ×\(geomean)")
    }

    /// **El anti-acantilado en HORAS, que es como lo enunció el dueño**:
    /// "ningún salto entre hitos de más de 4-5 h activas".
    ///
    /// Es nuevo de la cuarta ronda y existe porque `floorGradient` mide RATIOS,
    /// y un ratio no distingue una pared de un arranque corto: el ×16,38 de
    /// urbano → corporativo son 20 minutos. La serie que importa es la de los
    /// saltos absolutos, y va sobre los DIEZ pisos (no sólo el arco
    /// pre-prestigio), porque una pared del final es tan pared como una del
    /// principio.
    ///
    /// Peor salto medido: **2,02 h** (island → moon). Historia: 10,0 h en la
    /// ronda 2, 4,45 h en la tercera. El tope es 4 h y no "lo medido +30 %" a
    /// propósito — éste no es una banda alrededor de la conducta sino el
    /// contrato del dueño, y por eso no se re-pinea con cada calibración.
    @Test("ningún salto entre hitos pasa de 4 h activas")
    func noHitoJumpIsLongerThanFourActiveHours() throws {
        let actives = try floorTable.floors.dropFirst().map { floor in
            try #require(report.floorUnlockActiveSeconds[floor.id], "\(floor.id) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let salto = (actives[index] - actives[index - 1]) / 3600
            #expect(salto <= 4.0, "salto de \(salto) h activas hasta \(floorTable[index + 1].id)")
        }
    }

    /// **4,28 h de PARED medidas** en la corrida del encabezado, ±30 %
    /// (0,61 h ACTIVAS). De pared y no activas a propósito: el número que mide
    /// la espera del jugador es el de calendario.
    ///
    /// Las rondas 3 y 4 casi no la movieron (4,07 → 4,13 → 4,28 h): el arranque
    /// depende del Fisura, que es lo único contratable hasta que la frontera
    /// llega a `N + 2`, y su primer precio es una decisión cerrada.
    ///
    /// ⚠️ **Volvió a caer temprano, y es el costo declarado de la ronda 2.** El
    /// rebalance de la ronda 1 la había llevado a 62,00 h de pared (3,67 h
    /// activas) subiendo `oro.divisor` a 3e12, para que reencarnar dejara de ser
    /// un trámite del primer minuto. Con el efecto secuencial el ingreso cayó
    /// tanto que ESE divisor pone la primera reencarnación a las **25,67 h
    /// activas** y maxear a 122 h: el hito llega tan tarde que el juego se
    /// vuelve otra cosa. El divisor bajó a 1e9 para recuperar el contrato de
    /// 20-30 h, y con él la primera reencarnación se adelanta.
    ///
    /// Lo que **sí** se conservó es la pregunta que de verdad importaba
    /// ("¿conviene reencarnar temprano?"), y ahora se contesta mejor que en la
    /// ronda 1: el barrido de `--prestige-threshold` es MONÓTONO (×1 → 24,67 h ·
    /// ×8 → 30,54 h · ×1000 → 50,51 h · nunca → dios a 66,34 h). Antes ×8 daba
    /// 15,29 h, o sea guardarse las reencarnaciones ganaba. Ver `balance-log`.
    @Test("la 1ª reencarnación cae entre 3,0 y 5,6 h de pared")
    func firstReincarnation() throws {
        let wall = try #require(report.firstReincarnationWall, "nunca reencarnó")
        #expect(wall >= 3.00 * 3600 && wall <= 5.56 * 3600, "1ª reencarnación: \(wall / 3600) h")
    }

    /// **168,06 h de PARED medidas** (9,40 h ACTIVAS), ±30 %, con **10
    /// reencarnaciones**. Venía de 240,31 h (13,64 activas).
    ///
    /// La caída no la produjo un knob de dificultad: la produjo cerrar el atajo
    /// de comprar hondo. Con el precio viejo el camino óptimo era mergear
    /// `2^(frontera−1)` Fisuras por tier, y esa montaña de compras era, sin que
    /// nadie lo hubiera diseñado, **la mitad del largo del juego** —el
    /// simulador cobra 1 s por compra—. Con el precio anclado a la frontera el
    /// camino óptimo pasa a ser `2^N` compras del tier que la compuerta habilita,
    /// que son muchas menos. Por eso la compuerta subió a 6: es el knob que
    /// devuelve ese trabajo, ahora a propósito y con un número.
    ///
    /// El assert de forma que importa no es el largo sino la relación: dios
    /// (9,40 h activas) queda **×1,29 más lejos que maxear** (7,27 h), o sea las
    /// skins doradas siguen llegando antes que el final. Eso lo asserta
    /// `theOwnersTargetsAreMet`.
    @Test("dios llega entre 118 y 219 h de pared con ≥3 reencarnaciones")
    func godTiming() throws {
        let wall = try #require(report.godWall, "dios nunca llegó (maxTier \(report.finalMaxTier))")
        #expect(wall >= 117.64 * 3600 && wall <= 218.48 * 3600, "dios: \(wall / 3600) h")
        #expect(report.reincarnations >= 3, "reencarnaciones: \(report.reincarnations)")
    }

    // MARK: El objetivo del dueño (esto NO se re-pinea)

    /// Los dos números que el dueño puso como objetivo del rebalance, y el
    /// único test del suite que **no** es una banda alrededor de lo medido:
    ///
    /// 1. **Ganarlo al máximo —las siete líneas al tope, que es lo que
    ///    desbloquea las skins doradas— cuesta 20-30 h ACTIVAS.**
    /// 2. **Se llega con 8 reencarnaciones o menos.** Medido: 8. El bot reencarna
    ///    al DUPLICAR su ORO histórico, así que las reencarnaciones para maxear
    ///    son ≈ log₂(costo total en ORO) y log₂(193) = 7,6: el techo y el
    ///    catálogo están atados, y por eso `upgradeCatalogMatchesTunedValues`
    ///    pinea los 193.
    ///
    /// Y la forma que el dueño pidió: **dios más lejos que las skins doradas**.
    ///
    /// 🔴 **ESTE TEST ESTÁ EN ROJO DESDE EL 2026-08-22 Y NO ES UN DESCUIDO.**
    /// El primer assert mide **7,27 h** contra las 20-30 pedidas. No se aflojó
    /// —el objetivo es del dueño y esta suite existe para gritar cuando el juego
    /// deja de cumplirlo—.
    ///
    /// La causa que midió la tercera ronda **ya está arreglada**: el precio dejó
    /// de seguir a `tapYield(tier)` y comprar hondo pasó a costar 1,33× por tier
    /// de profundidad en vez de 0,71×. Con eso la compuerta se volvió el dial
    /// que el diseño esperaba (N=5 → 4,14 h · N=6 → 7,27 h · N=7 → 10,34 h) y se
    /// subió a 6.
    ///
    /// **La causa que queda es otra, y también está medida**: ~la mitad del
    /// tiempo ACTIVO del bot es apretar el botón, no esperar plata —el simulador
    /// cobra 1 s por compra, y sin ese segundo maxear cae de 4,14 h a 2,19 h—.
    /// Por eso los knobs de precio son sublineales: `defaultCostMultiplier` ×16
    /// compra ×1,75 de partida, y ninguna combinación de los diez knobs pasa de
    /// **13 h** sin romper otro contrato. Lo que sí escala es el número de
    /// COMPRAS por tier, que es `2^gateTierDistance`, y arriba de 6 se despierta
    /// el muro del early game (N=7 sin tocar nada: 185 h y un paso de ×4.441).
    ///
    /// La otra mitad del diagnóstico es el acelerador que queda abierto: el
    /// `incomeMultiplier` del piso (1 → 620) lo cobra el PASIVO y no lo cobra el
    /// precio, así que el ingreso crece 3,33× por tier contra los 2,8× del
    /// precio y la torre se acelera sola — medido, "entrar al piso" cae de 100 s
    /// a 0,0 s del callejón al reino divino. Aplanar esa curva a 1,0 lleva la
    /// partida a 6,83 h (12,16 h con N=6); anclarle el precio al
    /// `incomeMultiplier` de la frontera, a 6,63 h. Las dos están medidas en
    /// `Docs/balance-log.md` (cuarta ronda) y las dos son decisión del dueño.
    ///
    /// ⚠️ **Y el otro contrato que sigue roto es el de reencarnar**: sin
    /// reencarnar dios llega en **2,84 h** activas contra 9,40 h reencarnando.
    /// Misma causa de fondo: reencarnar te devuelve la torre al tier 1 y el ORO
    /// sólo te saca la ESPERA, no las compras — y las compras son la mitad del
    /// reloj.
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
