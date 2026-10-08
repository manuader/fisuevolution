import EconomyKit
import Foundation
import Observation
import Testing
@testable import FisuEvolution

/// La oferta del botón "contratar al mejor" de la pantalla principal.
///
/// Lo que se pinea acá es la REGLA DE SELECCIÓN contra el `economy.json`
/// bundleado, que es la única forma de saber que el botón ofrece lo que el
/// jugador puede comprar de verdad: el **tier más alto pagable** entre los que
/// FisuJobs da por contratables, el más barato como meta de ahorro cuando no
/// alcanza, y nada cuando no hay nada.
///
/// ⚠️ **Media suite cambió de significado DOS veces, y la segunda la devolvió a
/// donde estaba.** El 2026-08-21 la regla pasó a "el tier BASE del piso más
/// alto" (§4.5 del rebalance) y el 2026-08-28 volvió a "el más alto pagable"
/// (pedido del dueño). Los escenarios sobrevivieron los dos cambios sin tocarse
/// —los Senior de corporativo, el techo del urbano— y por eso siguen siendo
/// buenos: prueban que lo que el atajo ofrece o deja afuera **estaba pagable y
/// contratable**, no simplemente fuera de alcance. El porqué de la vuelta
/// atrás, con los tres datos que la sostienen, está en `computeQuickHireOffer()`.
///
/// FisuJobs nunca cambió en ninguna de las dos: siempre vendió todo lo
/// desbloqueado. Lo que se movió fue el atajo, y sólo el atajo.
///
/// La compuerta la sigue repartiendo `jobRows`/`jobState` (piso abierto, gate,
/// lugar libre y —sobre todo— tipo YA VISTO): esta proyección no inventa
/// autorización propia, la consume. Por eso el test del `unseen` es el que más
/// importa: es el único que impide que el botón espoilee la cadena (RF-03).
@Suite("quickHireOffer: la oferta del atajo de contratar", .serialized)
@MainActor
struct QuickHireOfferTests {
    /// Plata suficiente, escrita directo sobre el saldo.
    ///
    /// `debugGrantCoins()` acredita **un millón fijo** en estos escenarios (su
    /// cotización de referencia es el tier base del callejón, que sale 25 y no
    /// se mueve mientras no compres ahí), y un Senior de corporativo cuesta
    /// 290.206.483: llegar ahí serían 291 llamadas con su `refreshProjections`
    /// cada una. Donde alcanza el millón se usa el helper de debug; donde no, se
    /// escribe el saldo.
    private func giveCoins(_ amount: Double, to gameState: GameState) throws {
        var player = try #require(gameState.player)
        player.run.coins = amount
        gameState.player = player
    }

    // MARK: La regla

    @Test("partida nueva: aunque sobre la plata, la oferta es el tier base")
    func freshRunOffersTheBaseTypeEvenWithAFortune() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()

        // Con un millón en la mano, lo que manda es la compuerta y no el saldo:
        // el callejón es el único piso abierto y el Fisura el único tipo visto.
        let best = try #require(gameState.quickHireOffer)
        #expect(best.typeId == "homeless")
        #expect(best.tier == 1, "el firstTier del callejón (floorTable: alley 1-4)")
        // Traducido y con el runner en inglés: se pinea que haya nombre, no cuál
        // (ver `JobRowsTests.newGameOffersOnlyTheFisura`).
        #expect(best.displayName != "???")
        #expect(best.faceKey == "homeless_face")
        #expect(best.costText == "25", "el primer Fisura cuesta 25 (decisión del dueño)")
        #expect(best.affordable)
    }

    @Test("sin plata la oferta es el más barato, como meta de ahorro")
    func brokePlayerSeesTheCheapestAsAGoal() async throws {
        let gameState = await makeGameState()
        gameState.refreshProjections()

        // Arrancás con 0 monedas: la oferta igual existe (el botón muestra a
        // cuánto hay que llegar), pero desaturada.
        let best = try #require(gameState.quickHireOffer)
        #expect(best.typeId == "homeless")
        #expect(best.costText == "25")
        #expect(!best.affordable, "sin plata la oferta es meta, no compra")
    }

    /// El corazón de la regla: un tier NO-base, **pagable y contratable**, no es
    /// la oferta. El del piso más alto que sí lo es, sí.
    ///
    /// Derivado a mano de `economy.json`, ya con el precio anclado a la frontera
    /// (2026-08-23): el factor de piso es el MISMO que cobra el tap
    /// (`tapFloorMultiplier`, hoy con el exponente en 0 y por lo tanto 1 en los
    /// diez pisos), el ancla es `tapYield(frontera)` con `1,5^(tier − frontera)`
    /// por la distancia, y desde la desaceleración lleva además
    /// `1,6^(frontera − 7)`. Con la frontera en 18 esa escalada vale 1,6¹¹ =
    /// 175,92, así que un Senior (tier 12) cotiza **370.348.029.352,24** y el
    /// Oficinista —el `firstTier` del piso— **109.732.749.437,70**. Con
    /// cuatrocientos mil millones en la mano los dos se pagan y los dos salen
    /// `hirable`, así que lo único que puede elegir al Oficinista es la regla
    /// del tier base.
    /// El tier NO-base pagable **es** la oferta: ésa es la regla, y este test es
    /// su cara exacta.
    ///
    /// **Pineó lo contrario entre el 2026-08-21 y el 2026-08-28** con este mismo
    /// escenario. Se conserva tal cual porque lo que lo hace fuerte no cambió: el
    /// Senior está `hirable` y pagado, así que si el atajo lo dejara afuera sería
    /// por la regla y no por la plata ni por la compuerta.
    @Test("el tier más alto pagable es la oferta, aunque no sea tier base")
    func theOfferIsTheHighestPayableTier() async throws {
        let gameState = await makeGameState()
        // La frontera en 18 es lo que le abre la compuerta al Senior (T12 + 6).
        // El Director queda afuera por DOS razones a la vez —sin ver, y con su
        // compuerta cerrada, que pediría 19—, así que no compite ni aunque una
        // de las dos se caiga.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(18)
        try giveCoins(400_000_000_000, to: gameState)
        gameState.refreshProjections()

        // El escenario, antes del assert: el Senior es una fila que FisuJobs
        // vende hoy mismo. Si dejara de serlo, este test probaría otra cosa.
        let senior = try #require(gameState.jobRows.first { $0.id == "senior_architect" })
        #expect(senior.state == .hirable, "el tier 12 está contratable de verdad")
        #expect(senior.affordable, "y la plata le alcanza")

        let best = try #require(gameState.quickHireOffer)
        #expect(best.tier == 12, "el más alto pagable, no el firstTier de corporativo")
        #expect(best.typeId == "senior_architect")
        #expect(best.affordable)

        // Y el Oficinista, que es el tier base, sigue estando ahí y pagado: lo
        // que lo deja afuera es que hay algo MEJOR, no que él no se pueda.
        let oficinista = try #require(gameState.jobRows.first { $0.id == "oficinista" })
        #expect(oficinista.state == .hirable)
        #expect(oficinista.affordable)
    }

    /// Abrir un piso sube la oferta al tier más alto que ese piso vende y la
    /// compuerta habilita — no a su tier base.
    ///
    /// **Pineó lo contrario entre el 2026-08-21 y el 2026-08-28**, con el mismo
    /// escenario: es la vuelta al assert original.
    ///
    /// Con la frontera en 14 y la compuerta en 6 tiers, lo contratable llega
    /// hasta el tier 8 —el TOPE del urbano—, y el tier base de corporativo (9)
    /// pediría 15. Así que el techo lo pone la COMPUERTA y no un piso cerrado:
    /// el escenario abre corporativo a propósito para que eso quede claro.
    @Test("con el urbano al tope la oferta sube a su tier más alto, no a su base")
    func unlockedFloorsRaiseTheOfferUpToTheGate() async throws {
        let gameState = await makeGameState()
        // Frontera 14: el Fast Food (T8) pide 14 y el Oficinista (T9) pide 15,
        // así que lo contratable termina JUSTO en el tope del urbano.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugSetMaxTier(14)
        // Hasta 9 y no hasta 8: el Oficinista tiene que estar VISTO para que su
        // fila diga `gated` y no `unseen`, que gana sobre todo lo demás.
        gameState.debugMarkTypesSeen(throughTier: 9)
        // El saldo tiene que cubrir al Fast Food para que el test pueda decir
        // que lo que decide es la regla y no la plata.
        try giveCoins(1_000_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.quickHireOffer)
        #expect(best.tier == 8, "el tope del urbano que la compuerta habilita")
        #expect(best.typeId == "fast_food")
        #expect(best.affordable)

        // Y el Mantero, el tier base del mismo piso, sigue contratable: lo que
        // lo deja afuera es que hay algo más alto y pagable.
        let mantero = try #require(gameState.jobRows.first { $0.id == "mantero" })
        #expect(mantero.state == .hirable)
        #expect(mantero.affordable)

        // El Oficinista queda afuera por la COMPUERTA: es lo que hace que el
        // techo del atajo sea el urbano y no corporativo.
        #expect(try #require(gameState.jobRows.first { $0.id == "oficinista" }).state == .gated(requiredTier: 15))
    }

    /// Cuando el tier más alto no se paga, la oferta baja **un tier**, no un
    /// piso: el escalón vuelve a ser fino.
    ///
    /// **Entre el 2026-08-21 y el 2026-08-28 el escalón era de PISO** (bajaba de
    /// corporativo al urbano) porque cada piso aportaba un solo candidato. Sin el
    /// recorte, entre el Oficinista y el Mantero hay cuatro escalones más.
    ///
    /// El saldo se DERIVA de la config y no es un literal, y ésa es la otra
    /// mitad de este test: un literal que dejó de caer donde su nombre dice sigue
    /// pareciendo válido y pasa a medir lo contrario. Acá se pide exactamente un
    /// peso menos que el tier más alto habilitado, y el que tiene que ganar es
    /// el de abajo.
    @Test("si el tier más alto no se paga, la oferta baja un tier")
    func theOfferFallsBackToWhatTheCoinsActuallyCover() async throws {
        let gameState = await makeGameState()
        // Frontera 15: le abre la compuerta al Oficinista (T9 + 6) y deja al
        // Administrativo (T10) pidiendo 16, así que el techo es el 9.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(15)
        let content = try #require(gameState.content)
        let corporate = try #require(content.floorTable.floors.first { $0.id == "corporate" })
        let player0 = try #require(gameState.player)
        let oficinistaCost = content.economy.hireCost(
            floor: corporate, tier: 9, frontierTier: player0.run.maxTierReached, purchases: 0
        )
        // Un peso menos que el techo, derivado de la config.
        try giveCoins(oficinistaCost - 1, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.quickHireOffer)
        #expect(best.tier == 8, "un tier abajo del techo, no un piso entero")
        #expect(best.typeId == "fast_food")
        #expect(best.affordable)

        // Y el Oficinista estaba contratable: lo único que lo frenó fue el precio.
        let oficinista = try #require(gameState.jobRows.first { $0.id == "oficinista" })
        #expect(oficinista.state == .hirable)
        #expect(!oficinista.affordable, "el saldo es exactamente un peso menos que el suyo")
    }

    @Test("el tipo que nunca viste no se ofrece, por más que su piso esté abierto")
    func unseenTypesAreNeverOffered() async throws {
        let gameState = await makeGameState()
        // Pisos abiertos SIN marcar los tipos como vistos: el urbano entero y
        // los tres tiers de arriba del callejón siguen sin verse.
        gameState.debugUnlockFloors(throughTier: 8)
        try giveCoins(10_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.quickHireOffer)
        let player = try #require(gameState.player)
        #expect(player.run.seenTypes.contains(best.typeId), "RF-03: no se espoilea la cadena")
        #expect(best.tier == 1,
                "con plata y piso abierto, lo único que frena la oferta en el Fisura es no haber visto al Mantero")
        #expect(best.typeId == "homeless")
    }

    @Test("sin plata, la meta es el más barato de todos los tier base contratables")
    func withoutCoinsTheGoalIsTheCheapestOfMany() async throws {
        let gameState = await makeGameState()
        // Tres tier base contratables (Fisura, Mantero y Oficinista) y cero
        // monedas: acá el que elige es el `min` por costo, no el único candidato
        // que hay. Es la única rama de `computeQuickHireOffer` donde el criterio de
        // PRECIO sigue teniendo con qué comparar; el desempate por id de ese
        // mismo `min` es tan inalcanzable como los dos del `max`, porque después
        // del filtro de tier base dos candidatos distintos no cotizan igual.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(0, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.quickHireOffer)
        #expect(best.typeId == "homeless", "el más barato de los tier base contratables")
        #expect(best.tier == 1)
        // ⚠️ **Acá el Fisura ya no sale 25, y son las dos mitades nuevas de la
        // regla juntas**: con la frontera en 13 el ancla es lo que rinde un click
        // de TU frontera —(2,8/1,5)¹² = 1.789,8×— y encima pesa la desaceleración
        // desde el tier 7 —1,6⁶ = 16,78×—. 25 × 1.789,8 × 16,78 = 750.690,94.
        // Los 25 pelados sólo valen con la frontera en T1, y eso lo pinea
        // `hirePricesFollowTheOwnersRule`.
        let fisuraConLaFronteraEn13 = 25 * pow(2.8 / 1.5, 12) * pow(1.6, 6)
        #expect(abs(fisuraConLaFronteraEn13 - 750_690.94) < 0.01)
        #expect(best.costText == CoinFormatter.string(from: fisuraConLaFronteraEn13))
        #expect(!best.affordable)
    }

    /// **El desempate de precio vuelve a decidir.** Los cuatro Senior arrancan
    /// costando lo mismo; comprar uno le sube la curva —que es POR TIPO
    /// (`run.hireCountsByType`), un `growth` de ×1,06 desde el rebalance— y la
    /// oferta pasa al siguiente más barato del mismo tier.
    ///
    /// Este test **existió, se retiró el 2026-08-21 por inalcanzable y vuelve el
    /// 2026-08-28**: con el recorte de tier base cada piso aportaba un solo
    /// candidato y dos no podían empatar. Sin él, los tiers 11 y 12 aportan
    /// cuatro cada uno y el empate es la regla, no el borde.
    @Test("empatados en tier, gana el más barato")
    func tiesOnTierPreferTheCheapest() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(18)   // la compuerta del Senior (T12) pide 18
        // Saldo para DOS Senior: si sólo alcanzara para uno, después de comprar
        // la oferta se caería de tier y el test mediría otra cosa.
        try giveCoins(2_000_000_000_000, to: gameState)
        gameState.refreshProjections()
        let before = try #require(gameState.quickHireOffer)
        #expect(before.typeId == "senior_architect", "empate a cuatro: gana el id ascendente")

        gameState.hireCharacter(typeId: "senior_architect")
        gameState.refreshProjections()

        // La compra entró de verdad —si no, el test no probaría nada—.
        #expect(gameState.player?.run.hireCountsByType["senior_architect"] == 1)
        let best = try #require(gameState.quickHireOffer)
        #expect(best.tier == 12, "sigue siendo el tier más alto: lo que se movió es CUÁL")
        #expect(best.typeId == "senior_doctor", "el Arquitecto se encareció y pasó el siguiente")
    }

    /// **El desempate por id vuelve a decidir**: el tier 12 tiene CUATRO tipos
    /// concretos y el precio no depende del id —`hireCost` es `multiplicador ×
    /// tapYield(frontera) × tapFloorMultiplier(piso) × priceGrowthPerTier^(tier −
    /// frontera) × growth^compras`, y las compras de los cuatro están en 0—, así
    /// que empatan en tier Y en costo y gana el id ascendente.
    ///
    /// Como el de arriba: existió, se retiró el 2026-08-21 por inalcanzable, y
    /// vuelve el 2026-08-28.
    @Test("empatados en tier y en precio, gana el id ascendente")
    func tiesFallBackToTheAscendingID() async throws {
        let gameState = await makeGameState()
        // La frontera en 18 es lo que le abre la compuerta a los ocho (el Sr.
        // es T12 y pide 18); lujo queda con la suya cerrada y sin ver, así que
        // no compite.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(18)
        try giveCoins(400_000_000_000, to: gameState)
        gameState.refreshProjections()

        let seniors = ["senior_architect", "senior_doctor", "senior_lawyer", "senior_programmer"]
        // Los cuatro son ofertas vivas de FisuJobs en este mismo estado: sin
        // eso, "gana el primero" no probaría un desempate sino un único candidato.
        for id in seniors {
            let row = try #require(gameState.jobRows.first { $0.id == id })
            #expect(row.state == .hirable, "\(id) tiene que estar contratable para que el test pruebe algo")
            #expect(row.affordable, "\(id) tiene que estar pagado para que el test pruebe algo")
        }

        // Y el empate de precio es real, no supuesto.
        let player = try #require(gameState.player)
        let quotes = seniors.compactMap { gameState.currentQuote(player: player, typeId: $0)?.cost }
        #expect(quotes.count == 4)
        #expect(Set(quotes).count == 1, "los cuatro cotizan 370.348.029.352,24")
        #expect(abs(try #require(quotes.first) - 370_348_029_352.24) < 0.01)

        let best = try #require(gameState.quickHireOffer)
        #expect(best.tier == 12)
        #expect(best.typeId == "senior_architect", "el primero en orden alfabético de los cuatro empatados")
        #expect(best.affordable)
    }

    @Test("sin ningún contratable no hay oferta, y el botón no contrata nada")
    func noHirableMeansNoOffer() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        // El callejón lleno y el resto de la cadena sin ver: no queda un solo
        // tipo en estado `hirable`.
        let capacity = gameState.floorOccupancy(ordinal: 0).capacity
        for _ in gameState.floorOccupancy(ordinal: 0).occupied..<capacity {
            gameState.hireCharacter(typeId: "homeless")
        }
        gameState.refreshProjections()

        #expect(gameState.floorOccupancy(ordinal: 0).occupied == capacity)
        #expect(gameState.quickHireOffer == nil, "sin nada contratable el botón no se dibuja")

        let unitsBefore = try #require(gameState.player?.run.units)
        let coinsBefore = try #require(gameState.player?.run.coins)
        gameState.hireQuickOffer()
        #expect(gameState.player?.run.units == unitsBefore, "sin oferta no hay compra")
        #expect(gameState.player?.run.coins == coinsBefore)
    }

    // MARK: La acción

    @Test("contratar al mejor pasa por el mismo camino de compra que FisuJobs")
    func hiringTheBestGoesThroughTheRegularPurchase() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        let best = try #require(gameState.quickHireOffer)
        let unitsBefore = try #require(gameState.player?.run.totalUnits)
        let coinsBefore = try #require(gameState.player?.run.coins)
        let boardBefore = gameState.boardVersion

        gameState.hireQuickOffer()

        #expect(gameState.player?.run.totalUnits == unitsBefore + 1)
        #expect(gameState.player?.run.units[best.typeId] == 2, "la unidad es la que ofrecía el botón")
        // Los efectos de `hireCharacter` entero, no una compra paralela: el
        // cobro, el contador por tipo, la estadística y el redibujo.
        #expect(gameState.player?.run.coins == coinsBefore - 25)
        #expect(gameState.player?.run.hireCountsByType[best.typeId] == 1)
        #expect(gameState.player?.meta.stats.totalHiresEver == 1)
        #expect(gameState.boardVersion > boardBefore)
    }

    /// El botón **no** está deshabilitado cuando no alcanza: se toca igual y
    /// tiembla (patrón `PricePill`, spec §11.2). Eso deja una ruta de compra
    /// abierta con el saldo corto, y lo que la cierra no es la vista sino
    /// `TowerActions.hire`, que revalida el saldo. Este test es el que pinea
    /// que la revalidación esté puesta: si algún día la ruta rápida se saltea
    /// el guard —o si el botón pasara a recalcular la oferta en el toque en vez
    /// de leer la proyección—, acá se contrata gratis y el test lo dice.
    @Test("tocar la oferta sin saldo no compra ni cobra ni cuenta")
    func tappingAnUnaffordableOfferBuysNothing() async throws {
        let gameState = await makeGameState()
        gameState.refreshProjections()

        // Partida nueva: cero monedas y el Fisura a 25 como meta de ahorro.
        let best = try #require(gameState.quickHireOffer)
        #expect(!best.affordable, "el escenario del test es justamente el saldo corto")

        let unitsBefore = try #require(gameState.player?.run.units)
        let totalUnitsBefore = try #require(gameState.player?.run.totalUnits)
        let coinsBefore = try #require(gameState.player?.run.coins)
        let hiresBefore = try #require(gameState.player?.meta.stats.totalHiresEver)

        gameState.hireQuickOffer()

        #expect(gameState.player?.run.units == unitsBefore, "no se coloca ninguna unidad")
        #expect(gameState.player?.run.totalUnits == totalUnitsBefore)
        #expect(gameState.player?.run.coins == coinsBefore, "no se cobra nada")
        #expect(gameState.player?.meta.stats.totalHiresEver == hiresBefore, "no cuenta como contratación")
        #expect(gameState.player?.run.hireCountsByType[best.typeId] == nil,
                "la curva del tipo no se mueve con una compra que no ocurrió")

        // Y la oferta sigue igual después del rechazo: el botón no se apaga ni
        // cambia de personaje por haberlo tocado.
        gameState.refreshProjections()
        #expect(gameState.quickHireOffer == best)
    }

    @Test("comprar mueve la oferta: la curva del tipo sube y el precio nuevo se publica")
    func buyingMovesTheOffer() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.quickHireOffer?.costText == "25")

        gameState.hireQuickOffer()
        gameState.refreshProjections()

        // Mismo tipo (sigue siendo el único visto) pero un escalón más caro:
        // 25 × 1,03 = 25,75, la curva por tipo de `hireCountsByType`. Era 30 con
        // el growth en 1,2 y 26,5 con 1,06; la quinta ronda bajó el del callejón
        // a 1,03 (el PRIMER Fisura sigue en 25: cambia la pendiente, no el ancla).
        //
        // Que se lea "26" y no "25" es `CoinFormatter.cost`, que redondea los
        // precios hacia ARRIBA: con 25,75 truncado este assert se caía, y con él
        // otros tres. Un precio nunca puede leerse más barato de lo que se cobra.
        #expect(gameState.quickHireOffer?.typeId == "homeless")
        #expect(gameState.quickHireOffer?.costText == "26", "el segundo Fisura cuesta 25,75 (growth 1,03)")
    }

    // MARK: La proyección

    /// Caja para el flag del observador: `withObservationTracking` pide un
    /// `@Sendable`, y bajo concurrencia estricta un `var` local capturado no
    /// compila. El callback llega sincrónico, en la misma mutación y en el mismo
    /// hilo, así que la caja nunca cruza aislamiento.
    private final class PublishFlag: @unchecked Sendable {
        var published = false
    }

    @Test("la proyección se publica sólo cuando la oferta cambia")
    func theProjectionOnlyPublishesOnChange() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.quickHireOffer != nil)

        // Ocho veces por segundo con la oferta quieta: escribir igual
        // invalidaría SwiftUI en cada flush.
        let quiet = PublishFlag()
        withObservationTracking {
            _ = gameState.quickHireOffer
        } onChange: {
            quiet.published = true
        }
        gameState.refreshProjections()
        #expect(!quiet.published, "una oferta que no cambió no se re-publica")

        // Y cuando cambia de verdad, sí se publica.
        let moved = PublishFlag()
        withObservationTracking {
            _ = gameState.quickHireOffer
        } onChange: {
            moved.published = true
        }
        gameState.hireCharacter(typeId: "homeless")   // sube la curva → precio nuevo
        gameState.refreshProjections()
        #expect(moved.published, "si el precio se movió, la vista tiene que enterarse")
    }
}
