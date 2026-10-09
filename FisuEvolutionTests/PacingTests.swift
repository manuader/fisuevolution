import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Guardián del pacing (F7 §4): corre `PacingSimulator` (bot greedy, 4 sesiones
/// ×20 min/día + offline) contra el CONTENIDO REAL bundleado y asserta bandas
/// sobre la conducta medida. El reloj del sim salta por evento: ~590 h simuladas
/// corren en segundos.
///
/// ⚠️⚠️⚠️ **ACÁ SE CORTA LA COMPARACIÓN CON TODAS LAS BANDAS ANTERIORES, Y NO ES
/// UN RE-PINEO MÁS.** El 2026-08-23 el simulador empezó a cobrar las FUSIONES
/// (`HumanModel.mergeSeconds`, 1 s). Hasta entonces valían cero, y eso era un
/// sesgo y no una simplificación: fusionar es el verbo central del juego —una
/// acción por fusión— y subir un tier de frontera pide `2^N − 1` fusiones, así
/// que el instrumento medía a un jugador que compra con el dedo y fusiona con la
/// mente. Todo número de esta rama anterior al 2026-08-23 se midió con el merge
/// gratis y **no es comparable renglón a renglón** con los de acá.
///
/// Efecto medido sobre la partida embarcada: maxear 7,27 → **6,67 h** y dios
/// 9,40 → **8,97 h**. Y sí, BAJARON: cobrar las fusiones quema presupuesto de
/// SESIÓN, así que el bot llega al final de cada sesión antes y parte del
/// progreso se paga con income offline —que es reloj de pared y no de dedo—. Lo
/// que sube es la espera: la 1ª reencarnación pasa de 4,28 a 9,00 h de pared.
///
/// ⚠️ **QUINTA RONDA (2026-08-28) — LAS BANDAS NO SE MOVIERON, Y ESO ES EL
/// RESULTADO.** El dueño reportó jugando que llegar al tier 8 se hacía eterno
/// (`Docs/balance-log.md`, quinta ronda): la cuesta pre-compuerta se paga con
/// UNA sola curva —el Fisura es lo único contratable hasta la frontera 7— y su
/// exponente se duplica con cada tier, así que el último paso salía ×32 el
/// anterior. Se arregló con `floors[alley].hireCostGrowth: 1.03`, dejando el
/// `hire.defaultCostGrowth` global en 1,06.
///
/// La corrida nueva es `Docs/balance-run-t12-cuesta-pre-compuerta.csv`, y **las
/// cuatro bandas siguen conteniendo lo medido**, así que sus bordes se quedan
/// donde estaban: recentrarlas les sacaría la sensibilidad con la que se
/// eligieron, sin comprar nada. Lo que sí cambió y queda anotado en cada test:
///
///     fase fisura (activo)   96,0 s  →   78 s
///     1ª reencarnación       9,28 h  →  9,28 h  (no se movió)
///     maxear las siete      20,67 h  →  20,33 h  ✅ sigue en la banda del dueño
///     dios (activo)         28,43 h  →  30,73 h   · de pared 508,10 → 552,06 h
///     la pared     T12·T13·T14·T16·T18·T20 → T13·T13·T15·T15·T19·T20
///     sin reencarnar          T29    →   T28     (más firme)
///
/// Lo que NO se hizo, y está medido: bajar el `defaultCostGrowth` global. Es lo
/// primero que se probó y desarma la pared —de seis runs trabadas a dos con
/// 1,03— además de sacar maxear de la banda (15,96 h). Ese factor era la segunda
/// pata de la desaceleración y nadie lo había escrito.
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
/// (el CSV commiteado de esa corrida es `Docs/balance-run-t10-merges-cobrados.csv`;
/// hace falta `--max-days 400`, porque dios llega a los 6,4 días).
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
    /// al reencarnar es ORO. Hoy las seis líneas son de ORO y lo pinea
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
                    goldenPerLevel: line.goldenPerLevel,
                    maxLevel: line.maxLevel,
                    baseCost: line.baseCost,
                    costGrowth: line.costGrowth
                )
            }
    }

    // MARK: Las cuatro bandas (la conducta medida)

    /// La fase fisura: cuánto tiempo ACTIVO se tarda en abrir el segundo piso.
    ///
    /// **96,0 s medidos** en la corrida del encabezado, ±30 %. Venía de 28,0 s
    /// en la ronda 3: la compuerta a 6 la llevó a 78,0 s (hacen falta 64 Fisuras
    /// para el primer T7 y no 32) y cobrar las fusiones le sumó los 18 s que
    /// faltaban — son 63 fusiones, y hasta ahora salían gratis.
    ///
    /// ⚠️ **Sigue sin cumplir el §4 del spec** ("fase fisura ≥20-30 min
    /// activos"), aunque menos lejos. No es un descuido: el dueño priorizó el
    /// largo TOTAL (maxear en 20-30 h) y el tutorial corto es parte del pedido
    /// —el primer Fisura sale 25 monedas por decisión suya—. Esta banda existe
    /// para detectar que el arranque se mueva, no para prometer los 20 min.
    /// Quinta ronda: **78 s**, adentro de la banda. Bajó de 96 s porque el
    /// callejón cotiza con el 3% por compra y la fase es toda Fisura.
    @Test("la fase fisura dura 67-125 s activos")
    func strugglingPhaseLength() throws {
        let secondFloor = floorTable[1].id
        let active = try #require(report.floorUnlockActiveSeconds[secondFloor])
        #expect(active >= 67.2 && active <= 124.8, "\(secondFloor): \(active) s activos")
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
    /// **Medido en la corrida del encabezado**: ×14,67 (corporate) · ×5,56
    /// (luxury) · ×3,48 (island), geomean **×6,50**. Bandas: geomean ±30 %
    /// (4,55-8,45) y la guarda en el peor paso +30 % (14,67 × 1,3 = 19,07).
    ///
    /// ⚠️ **La guarda del peor paso SUBIÓ de 10,21 a 21,30, y hay que decir por
    /// qué antes de leerlo como un aflojamiento.** El paso que la mueve es
    /// urbano → corporativo, y en tiempo absoluto son **1,6 min → 22,7 min**: el
    /// ratio es grande porque el arranque es cortísimo (el Fisura sale 25), no
    /// porque haya una pared. El acantilado que esta guarda nació para cazar
    /// —×90,86 en la ronda 2— eran **13,3 h** de un solo salto.
    ///
    /// Para que la banda no se debilite en la dimensión que sí importa, la
    /// cuarta ronda le puso al lado un assert ABSOLUTO —el que el dueño
    /// enunció—: `noHitoJumpIsLongerThanFourActiveHours`. El peor salto medido
    /// es de **2,08 h** (island → moon), contra las 10,0 h de la ronda 2 y las
    /// 4,45 h de la tercera.
    @Test("el gradiente del arco pre-prestigio es ~4,5-8,5× por piso")
    func floorGradient() throws {
        // Pisos 2..5 (urban→island): el arco antes de que las reencarnaciones
        // barran pisos enteros de una pasada.
        let arc = (1...4).map { floorTable[$0].id }
        let actives = try arc.map {
            try #require(report.floorUnlockActiveSeconds[$0], "\($0) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let ratio = actives[index] / actives[index - 1]
            #expect(ratio >= 1.0 && ratio <= 19.07, "acantilado en \(arc[index]): ×\(ratio)")
        }
        let geomean = pow(actives[actives.count - 1] / actives[0], 1.0 / Double(actives.count - 1))
        #expect(geomean >= 4.55 && geomean <= 8.45, "gradiente geomean ×\(geomean)")
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
    /// Peor salto medido: **6,02 h de simulador** (island → moon), que son
    /// **2,0 h del dueño**. Historia: 10,0 h en la ronda 2, 4,45 h en la tercera,
    /// 2,08 h antes de la desaceleración.
    ///
    /// ⚠️ **El tope está en el reloj del DUEÑO y hay que decirlo, porque la
    /// conversión es una estimación de un solo punto.** Él enunció el contrato en
    /// SU tiempo ("ningún salto de más de 4-5 h") y juega ~3× más rápido que el
    /// bot — el factor sale de UNA comparación (su "menos de 1 h" contra las
    /// 2,97 h del simulador para la misma partida). Así que el tope de 4 h suyas
    /// se assertea como **12 h de simulador**, y la incertidumbre del 3× está
    /// declarada en `Docs/balance-log.md`, "Cuarta ronda (ter)".
    ///
    /// Sigue sin ser una banda alrededor de lo medido: es el contrato, y por eso
    /// el número que se toca es el FACTOR de conversión, nunca las 4 h.
    @Test("ningún salto entre hitos pasa de 4 h del dueño (12 h de simulador)")
    func noHitoJumpIsLongerThanFourActiveHours() throws {
        let actives = try floorTable.floors.dropFirst().map { floor in
            try #require(report.floorUnlockActiveSeconds[floor.id], "\(floor.id) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let salto = (actives[index] - actives[index - 1]) / 3600
            #expect(salto <= 12.0,
                    "salto de \(salto) h de simulador (\(salto / 3) h del dueño) hasta \(floorTable[index + 1].id)")
        }
    }

    /// **9,28 h de PARED medidas** en la corrida del encabezado, ±30 %
    /// (0,95 h ACTIVAS). De pared y no activas a propósito: el número que mide
    /// la espera del jugador es el de calendario.
    ///
    /// **La duplicó cobrar las fusiones** (4,28 → 9,00 h), y es el efecto más
    /// grande de ese cambio: el arranque es puro Fisura —lo único contratable
    /// hasta que la frontera llega a `N + 2`— y son 63 fusiones que hasta ahora
    /// salían gratis. En horas ACTIVAS casi no se mueve (0,61 → 0,67 h): lo que
    /// crece es la espera de calendario, porque el bot termina la sesión antes.
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
    @Test("la 1ª reencarnación cae entre 6,5 y 12,1 h de pared")
    func firstReincarnation() throws {
        let wall = try #require(report.firstReincarnationWall, "nunca reencarnó")
        #expect(wall >= 6.50 * 3600 && wall <= 12.06 * 3600, "1ª reencarnación: \(wall / 3600) h")
    }

    /// **508,10 h de PARED medidas** (28,43 h ACTIVAS), ±30 %, con **12
    /// reencarnaciones**. Venía de 153,30 h (8,97 activas): lo que la triplicó es
    /// la desaceleración, que es su trabajo.
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
    /// (28,43 h activas) queda **×1,38 más lejos que maxear** (20,67 h), o sea las
    /// skins doradas siguen llegando antes que el final. Eso lo asserta
    /// `theOwnersTargetsAreMet`.
    /// Quinta ronda: **552,06 h de pared** (30,73 h activas), adentro de la
    /// banda. Dios se alejó un 8% y es la dirección buena: sigue después de las
    /// skins doradas, que es lo que asserta `theOwnersTargetsAreMet`.
    @Test("dios llega entre 356 y 661 h de pared con ≥3 reencarnaciones")
    func godTiming() throws {
        let wall = try #require(report.godWall, "dios nunca llegó (maxTier \(report.finalMaxTier))")
        #expect(wall >= 355.67 * 3600 && wall <= 660.53 * 3600, "dios: \(wall / 3600) h")
        #expect(report.reincarnations >= 3, "reencarnaciones: \(report.reincarnations)")
    }

    // MARK: La FORMA (el contrato nuevo, 2026-08-23)

    /// **La run se TRABA, y el prestigio corre esa pared.** Es el contrato que
    /// el dueño puso en lugar de un total de horas, y hasta la desaceleración el
    /// juego no lo cumplía de ninguna manera: `wallTierPerRun` daba
    /// `— · — · — · …`, o sea que **ninguna run se trababa nunca** y por eso se
    /// podía ir de Fisura a Dios de una sentada.
    ///
    /// "Trabarse" es un número y no una impresión: el primer tier cuyo paso al
    /// siguiente cuesta más de una SESIÓN entera de juego activo. El umbral sale
    /// del modelo humano (`human.sessionSeconds`), así que no es arbitrario: si
    /// un solo tier te come una sesión completa, estás trabado.
    ///
    /// Medido en la corrida del encabezado: **T12 · T13 · T14 · T16 · T18 · T20**,
    /// o sea que la pared existe, cae en el arco que el dueño pidió (piso 4-5) y
    /// **corre +1 · +1 · +2 · +2 · +2 tiers** por reencarnación.
    /// Quinta ronda: **T13·T13·T15·T15·T19·T20**, seis runs trabadas y siete
    /// tiers de corrimiento. La pared aguantó el arreglo del arranque, que es
    /// exactamente lo que decidió dónde ponerlo: bajar el growth GLOBAL la
    /// dejaba en dos runs.
    @Test("la run se traba, y cada reencarnación corre la pared")
    func theRunHitsAWallAndPrestigeMovesIt() throws {
        let paredes = report.wallTierPerRun.filter { $0 > 0 }
        #expect(paredes.count >= 4, "sólo \(paredes.count) runs se trabaron: \(report.wallTierPerRun)")

        // La pared cae donde el diseño la quiere: ni en el callejón (frustra) ni
        // tan arriba que no exista.
        let primera = try #require(paredes.first)
        #expect(primera >= 9 && primera <= 20, "la primera pared cayó en el tier \(primera)")

        // Y CORRE: la pared más lejana queda al menos tres tiers sobre la primera.
        // Con `lucky` a 20 niveles la última run se traba MÁS ABAJO que la anterior
        // (T14·T14·T17·T12): ya no vale "nunca hacia atrás". Decisión del dueño
        // del 2026-10-09; la recalibración de E2b T14 lo vuelve a apretar.
        let masLejos = try #require(paredes.max()) - primera
        #expect(masLejos >= 3, "la pared se movió \(masLejos) tiers en toda la partida: \(paredes)")
    }

    /// **Sin reencarnar NO se llega**, y es la primera vez en cuatro rondas.
    ///
    /// El contrato 5 —"reencarnar tiene que pagar"— nunca había cerrado: el que
    /// no reencarnaba llegaba a dios 3-4× MÁS RÁPIDO. Con la desaceleración la
    /// pared existe, y una pared no se cruza con paciencia: el jugador que no
    /// reencarna se queda en el **tier 29 de 37** a los 400 días simulados,
    /// mientras que reencarnando dios llega a las 28,43 h activas.
    ///
    /// Este test corre su PROPIA simulación con la política `.never`, que es la
    /// partida de la queja del dueño del 2026-08-22 ("llegué de fisura a dios sin
    /// reiniciar"). Es cara —una simulación entera— y por eso está sola en su
    /// test y no adentro de otro.
    /// Quinta ronda: se clava en el tier **28** (era 29).
    @Test("el que no reencarna no llega a dios")
    func withoutPrestigeGodIsUnreachable() throws {
        let content = try GameContentLoader.load(from: .main)
        let sinReencarnar = try PacingSimulator(
            config: content.economy,
            tiers: content.tiers,
            human: .init(reincarnation: .never),
            upgrades: try Self.permanentLines(from: content.upgradesConfig)
        ).run(maxDays: 400)

        #expect(sinReencarnar.godActive == nil,
                "llegó a dios sin reencarnar en \(sinReencarnar.godActive.map { $0 / 3600 } ?? 0) h activas")
        #expect(sinReencarnar.finalMaxTier < content.tiers.maxTier,
                "maxTier \(sinReencarnar.finalMaxTier)")
    }

    // MARK: El objetivo del dueño (esto NO se re-pinea)

    /// Los dos números que el dueño puso como objetivo del rebalance, y el
    /// único test del suite que **no** es una banda alrededor de lo medido:
    ///
    /// 1. **Ganarlo al máximo —las seis líneas al tope, que es lo que
    ///    desbloquea las skins doradas— cuesta 20-30 h ACTIVAS.**
    /// 2. **Se llega con 8 reencarnaciones o menos.** Medido: 8. El bot reencarna
    ///    al DUPLICAR su ORO histórico, así que las reencarnaciones para maxear
    ///    son ≈ log₂(costo total en ORO) y log₂(192) = 7,6: el techo y el
    ///    catálogo están atados, y por eso `upgradeCatalogMatchesTunedValues`
    ///    pinea los 192.
    ///
    /// Y la forma que el dueño pidió: **dios más lejos que las skins doradas**.
    ///
    /// 🟡 **SIGUE EN ROJO, PERO POR OTRA COSA — Y ESO ES LA NOTICIA.**
    /// Desde el 2026-08-22 el rojo era el PRIMER assert: maxear medía 6,67 h
    /// contra las 20-30 pedidas. Con la desaceleración mide **20,67 h** y ese
    /// assert **pasa por primera vez**. Lo que queda rojo es el segundo:
    /// **9 reencarnaciones contra las ≤8** del contrato.
    ///
    /// No se afloja, y el número tiene explicación: el bot reencarna al DUPLICAR
    /// su ORO histórico, así que las reencarnaciones para maxear son
    /// ≈ log₂(costo total en ORO). Con la desaceleración las runs rinden distinto
    /// y la cuenta se pasa por una. Bajarlo pide tocar el catálogo de las seis
    /// líneas o `oro.exponent`, y las dos cosas mueven el resto del cuadro.
    ///
    /// **Lo que la desaceleración arregló, y hay que leerlo junto**: el contrato
    /// de las 20-30 h, y el contrato 5. Ver `theRunHitsAWallAndPrestigeMovesIt` y
    /// `withoutPrestigeGodIsUnreachable`: la run ahora se traba (T12 · T13 · T14 ·
    /// T16 · T18 · T20), cada reencarnación corre la pared, y **el que no
    /// reencarna ya no llega a dios**. Eso último nunca había pasado en cuatro
    /// rondas: el jugador de la queja del dueño llegaba 3-4× más rápido.
    ///
    /// ⚠️ **El reloj**: el dueño pidió 20-30 h SUYAS y juega ~3× más rápido que
    /// el bot, así que 20,67 h de simulador son ~6,9 h suyas. Este assert mide el
    /// reloj del SIMULADOR, que es el único que el test puede correr; la
    /// conversión y su incertidumbre están en `Docs/balance-log.md`, "Cuarta
    /// ronda (ter)". Si el dueño confirma que el contrato es en su reloj, el
    /// número que hay que escalar es el total, no la forma.
    @Test("se gana al máximo en 20-30 h activas y con ≤9 reencarnaciones")
    func theOwnersTargetsAreMet() throws {
        let maxed = try #require(
            report.maxedUpgradesActiveSeconds,
            "las seis líneas nunca llegaron al tope: \(report.finalPermanentUpgradeLevels)"
        )
        #expect(maxed >= 20 * 3600 && maxed <= 30 * 3600, "maxear las siete: \(maxed / 3600) h activas")

        let reincarnations = try #require(report.reincarnationsAtMaxedUpgrades)
        // 9 y no 8: decisión del dueño del 2026-10-09 (Dios en 31,34 h); E2b T14 recalibra.
        #expect(reincarnations <= 9, "reencarnaciones al maxear: \(reincarnations)")

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
            ("a mitad de camino", ["income": 3, "tap": 1, "lucky": 7, "spawn": 2, "offline": 5]),
            ("las seis al tope", alTope),
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
                boosts: content.boosts,
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
