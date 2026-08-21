import EconomyKit
import Observation
import Testing
@testable import FisuEvolution

/// La oferta del botón "contratar al mejor" de la pantalla principal.
///
/// Lo que se pinea acá es la REGLA DE SELECCIÓN contra el `economy.json`
/// bundleado, que es la única forma de saber que el botón ofrece lo que el
/// jugador puede comprar de verdad: tier más alto pagable **entre los que
/// FisuJobs da por contratables**, el más barato como meta de ahorro cuando no
/// alcanza, y nada cuando no hay nada.
///
/// La compuerta la sigue repartiendo `jobRows`/`jobState` (piso abierto, gate,
/// lugar libre y —sobre todo— tipo YA VISTO): esta proyección no inventa
/// autorización propia, la consume. Por eso el test del `unseen` es el que más
/// importa: es el único que impide que el botón espoilee la cadena (RF-03).
@Suite("bestHire: el mejor contratable que la plata alcanza", .serialized)
@MainActor
struct BestHireTests {
    /// Plata suficiente, escrita directo sobre el saldo.
    ///
    /// `debugGrantCoins()` acredita **un millón fijo** en estos escenarios (su
    /// cotización de referencia es el tier base del callejón, que sale 25 y no
    /// se mueve mientras no compres ahí), y un Senior de corporativo cuesta
    /// 1.218.867.229: llegar ahí serían 1.219 llamadas con su
    /// `refreshProjections` cada una. Donde alcanza el millón se usa el helper
    /// de debug; donde no, se escribe el saldo.
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
        let best = try #require(gameState.bestHire)
        #expect(best.typeId == "homeless")
        #expect(best.tier == 1, "el firstTier del callejón (floorTable: alley 1-4)")
        #expect(best.displayName == "El Fisura")
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
        let best = try #require(gameState.bestHire)
        #expect(best.typeId == "homeless")
        #expect(best.costText == "25")
        #expect(!best.affordable, "sin plata la oferta es meta, no compra")
    }

    /// El techo de la oferta lo pone el GATE, no el saldo.
    ///
    /// Verificado a mano contra `economy.json`: con el callejón y el urbano
    /// abiertos, el urbano es `hireGateExempt` (se contrata sin abrir
    /// corporativo) y llega hasta el tier 8 (`urban` = 5-8), mientras que
    /// corporativo (9-12) ni siquiera está desbloqueado. Así que el tier más
    /// alto contratable es 8 — "Empleado de Fast Food"— y no 9, por más plata
    /// que haya.
    @Test("con el urbano abierto la oferta sube al tier 8, que es su techo")
    func unlockedFloorsRaiseTheOfferUpToTheGate() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 8)   // abre alley + urban
        gameState.debugMarkTypesSeen(throughTier: 8)
        // 600 × 2,8⁷ × 2,0 × 1,8³ = 9.442.891,09 es el Fast Food: el millón de
        // `debugGrantCoins` no lo cubre solo.
        try giveCoins(10_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.tier == 8, "el techo del urbano, no el tier más alto del juego")
        #expect(best.typeId == "fast_food")
        #expect(best.affordable)

        let player = try #require(gameState.player)
        #expect(
            !player.run.unlockedFloors.contains("corporate"),
            "corporativo tiene que seguir cerrado: es lo que hace que el techo sea 8"
        )
    }

    /// Un peso menos que el Fast Food y la oferta baja un escalón: lo que corta
    /// es el saldo, y baja al tier más alto que SÍ se paga.
    @Test("con un peso menos la oferta baja al tier que sí se paga")
    func theOfferFallsBackToWhatTheCoinsActuallyCover() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 8)
        gameState.debugMarkTypesSeen(throughTier: 8)
        // Un peso menos que el Fast Food, DERIVADO de la config y no un literal:
        // el rebalance de pacing cambió el factor de piso del precio y el
        // 9.000.000 de antes pasó a alcanzar para el tier 8, con lo que el test
        // medía lo contrario de lo que dice su nombre y seguía pareciendo válido.
        let content = try #require(gameState.content)
        let urban = content.floorTable[1]
        let fastFood = content.economy.hireCost(floor: urban, tier: 8, purchases: 0)
        try giveCoins(fastFood - 1, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.tier == 7)
        #expect(best.typeId == "chofer_app")
        #expect(best.affordable)
    }

    @Test("el tipo que nunca viste no se ofrece, por más que su piso esté abierto")
    func unseenTypesAreNeverOffered() async throws {
        let gameState = await makeGameState()
        // Pisos abiertos SIN marcar los tipos como vistos: el urbano entero y
        // los tres tiers de arriba del callejón siguen sin verse.
        gameState.debugUnlockFloors(throughTier: 8)
        try giveCoins(10_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        let player = try #require(gameState.player)
        #expect(player.run.seenTypes.contains(best.typeId), "RF-03: no se espoilea la cadena")
        #expect(best.tier == 1, "con plata y piso abierto, lo único que frena la oferta es no haberlo visto")
        #expect(best.typeId == "homeless")
    }

    @Test("sin plata, la meta es el más barato de TODOS los contratables")
    func withoutCoinsTheGoalIsTheCheapestOfMany() async throws {
        let gameState = await makeGameState()
        // Ocho contratables en pantalla (callejón + urbano) y cero monedas: acá
        // el que elige es el `min` por costo, no el único candidato que hay.
        gameState.debugUnlockFloors(throughTier: 8)
        gameState.debugMarkTypesSeen(throughTier: 8)
        try giveCoins(0, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.typeId == "homeless", "el de 25, no el de 9.442.891")
        #expect(best.tier == 1)
        #expect(best.costText == "25")
        #expect(!best.affordable)
    }

    /// El desempate de PRECIO dentro del mismo tier, que es un `if` distinto del
    /// desempate por id y hay que romperlo por separado.
    ///
    /// Los cuatro Senior arrancan costando lo mismo, así que la única forma de
    /// separarlos es comprar uno: la curva es POR TIPO
    /// (`run.hireCountsByType`), así que ese sube un `growth` (×1,06) y los otros
    /// tres se quedan donde estaban. Si el comparador prefiriera el más caro, o
    /// si mirara el id antes que el precio, acá seguiría ganando el Arquitecto.
    @Test("empate de tier con precios distintos: gana el más barato")
    func tiesOnTierPreferTheCheapest() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(4_000_000_000, to: gameState)
        gameState.refreshProjections()
        #expect(gameState.bestHire?.typeId == "senior_architect", "de arranque empatan y manda el id")

        gameState.hireCharacter(typeId: "senior_architect")
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.tier == 12, "sigue siendo el tier más alto que la plata alcanza")
        #expect(best.typeId == "senior_doctor", "en el mismo tier gana el más barato, no el id más chico")
    }

    /// El desempate, contra los cuatro Senior de corporativo.
    ///
    /// Verificado a mano: el tier 12 tiene CUATRO tipos concretos
    /// (`senior_architect`, `senior_doctor`, `senior_lawyer`,
    /// `senior_programmer`) y el precio no depende del id —`hireCost` es
    /// `multiplicador × tapYield(tier) × incomeMultiplier × tierPremium^(tier −
    /// firstTier) × growth^compras`, y las compras de los cuatro están en 0—,
    /// así que empatan en tier Y en costo: 600 × 2,8¹¹ × 4,2 × 1,8³ =
    /// 1.218.867.229,80 cada uno. El único desempate que queda es el id
    /// ascendente, y ése es el que pinea este test.
    @Test("empate de tier y de precio: gana el id más chico")
    func tiesFallBackToTheAscendingID() async throws {
        let gameState = await makeGameState()
        // Abrir hasta lujo es lo que le abre el gate a corporativo (necesita el
        // piso de arriba); lujo mismo queda gated y sin ver, así que no compite.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(2_000_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.tier == 12)
        #expect(best.typeId == "senior_architect", "los cuatro empatan: manda el id ascendente")
        #expect(best.affordable)

        // Y el empate es real: los cuatro cotizan exactamente lo mismo.
        let player = try #require(gameState.player)
        let quotes = ["senior_architect", "senior_doctor", "senior_lawyer", "senior_programmer"]
            .compactMap { gameState.currentQuote(player: player, typeId: $0)?.cost }
        #expect(quotes.count == 4)
        #expect(Set(quotes).count == 1, "si dejaran de empatar, este test dejaría de probar el desempate")
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
        #expect(gameState.bestHire == nil, "sin nada contratable el botón no se dibuja")

        let unitsBefore = try #require(gameState.player?.run.units)
        let coinsBefore = try #require(gameState.player?.run.coins)
        gameState.hireBestCharacter()
        #expect(gameState.player?.run.units == unitsBefore, "sin oferta no hay compra")
        #expect(gameState.player?.run.coins == coinsBefore)
    }

    // MARK: La acción

    @Test("contratar al mejor pasa por el mismo camino de compra que FisuJobs")
    func hiringTheBestGoesThroughTheRegularPurchase() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        let best = try #require(gameState.bestHire)
        let unitsBefore = try #require(gameState.player?.run.totalUnits)
        let coinsBefore = try #require(gameState.player?.run.coins)
        let boardBefore = gameState.boardVersion

        gameState.hireBestCharacter()

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
        let best = try #require(gameState.bestHire)
        #expect(!best.affordable, "el escenario del test es justamente el saldo corto")

        let unitsBefore = try #require(gameState.player?.run.units)
        let totalUnitsBefore = try #require(gameState.player?.run.totalUnits)
        let coinsBefore = try #require(gameState.player?.run.coins)
        let hiresBefore = try #require(gameState.player?.meta.stats.totalHiresEver)

        gameState.hireBestCharacter()

        #expect(gameState.player?.run.units == unitsBefore, "no se coloca ninguna unidad")
        #expect(gameState.player?.run.totalUnits == totalUnitsBefore)
        #expect(gameState.player?.run.coins == coinsBefore, "no se cobra nada")
        #expect(gameState.player?.meta.stats.totalHiresEver == hiresBefore, "no cuenta como contratación")
        #expect(gameState.player?.run.hireCountsByType[best.typeId] == nil,
                "la curva del tipo no se mueve con una compra que no ocurrió")

        // Y la oferta sigue igual después del rechazo: el botón no se apaga ni
        // cambia de personaje por haberlo tocado.
        gameState.refreshProjections()
        #expect(gameState.bestHire == best)
    }

    @Test("comprar mueve la oferta: la curva del tipo sube y el precio nuevo se publica")
    func buyingMovesTheOffer() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.bestHire?.costText == "25")

        gameState.hireBestCharacter()
        gameState.refreshProjections()

        // Mismo tipo (sigue siendo el único visto) pero un escalón más caro:
        // 25 × 1,06 = 26,5, la curva por tipo de `hireCountsByType`. Era 30 con
        // el growth en 1,2; el rebalance de pacing lo bajó a 1,06 (el PRIMER
        // Fisura sigue en 25: cambia la pendiente, no el ancla).
        #expect(gameState.bestHire?.typeId == "homeless")
        #expect(gameState.bestHire?.costText == "26", "el segundo Fisura cuesta 26,5 (growth 1,06)")
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
        #expect(gameState.bestHire != nil)

        // Ocho veces por segundo con la oferta quieta: escribir igual
        // invalidaría SwiftUI en cada flush.
        let quiet = PublishFlag()
        withObservationTracking {
            _ = gameState.bestHire
        } onChange: {
            quiet.published = true
        }
        gameState.refreshProjections()
        #expect(!quiet.published, "una oferta que no cambió no se re-publica")

        // Y cuando cambia de verdad, sí se publica.
        let moved = PublishFlag()
        withObservationTracking {
            _ = gameState.bestHire
        } onChange: {
            moved.published = true
        }
        gameState.hireCharacter(typeId: "homeless")   // sube la curva → precio nuevo
        gameState.refreshProjections()
        #expect(moved.published, "si el precio se movió, la vista tiene que enterarse")
    }
}
