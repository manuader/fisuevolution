import EconomyKit
import Observation
import Testing
@testable import FisuEvolution

/// La oferta del botón "contratar al mejor" de la pantalla principal.
///
/// Lo que se pinea acá es la REGLA DE SELECCIÓN contra el `economy.json`
/// bundleado, que es la única forma de saber que el botón ofrece lo que el
/// jugador puede comprar de verdad: el **tier base** (`floor.firstTier`) del
/// piso más alto pagable **entre los que FisuJobs da por contratables**, el más
/// barato como meta de ahorro cuando no alcanza, y nada cuando no hay nada.
///
/// ⚠️ **Media suite cambió de significado el 2026-08-21** y por eso varios
/// tests tienen el escenario de antes con el assert dado vuelta: hasta ese día
/// la regla era "el tier MÁS ALTO pagable", que es justo lo que saltea el merge
/// y acelera el juego (`Docs/PROMPT-rebalance-pacing.md` §4.5). Los escenarios
/// se conservaron a propósito —los Senior de corporativo, el techo del urbano—
/// porque son los que prueban que lo que queda afuera del atajo **estaba
/// pagable y contratable**, y no simplemente fuera de alcance.
///
/// FisuJobs **no** cambió: sigue vendiendo todo lo desbloqueado. Lo que se
/// recorta es el atajo, y sólo el atajo.
///
/// La compuerta la sigue repartiendo `jobRows`/`jobState` (piso abierto, gate,
/// lugar libre y —sobre todo— tipo YA VISTO): esta proyección no inventa
/// autorización propia, la consume. Por eso el test del `unseen` es el que más
/// importa: es el único que impide que el botón espoilee la cadena (RF-03).
@Suite("bestHire: el tier base del piso más alto que la plata alcanza", .serialized)
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

    /// El corazón de la regla: un tier NO-base, **pagable y contratable**, no es
    /// la oferta. El del piso más alto que sí lo es, sí.
    ///
    /// Derivado a mano de `economy.json`: con corporativo abierto y sus cuatro
    /// tiers vistos, un Senior (tier 12) cotiza 600 × 2,8¹¹ × 4,2 × 1,8³ =
    /// 1.218.867.229,80 y el Oficinista —el `firstTier` del piso— 600 × 2,8⁸ ×
    /// 4,2 = 9.520.610,36 (el `tierPremium` del tier base es 1,8⁰). Con dos mil
    /// millones en la mano los dos se pagan y los dos salen `hirable`, así que
    /// lo único que puede elegir al Oficinista es la regla del tier base.
    @Test("un tier no-base pagable y contratable no es la oferta")
    func payableNonBaseTiersAreNeverOffered() async throws {
        let gameState = await makeGameState()
        // Abrir hasta lujo es lo que le abre el gate a corporativo; lujo queda
        // sin ver, así que el Director no compite.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(2_000_000_000, to: gameState)
        gameState.refreshProjections()

        // El escenario, antes del assert: el Senior es una fila que FisuJobs
        // vende hoy mismo. Si dejara de serlo, este test probaría otra cosa.
        let senior = try #require(gameState.jobRows.first { $0.id == "senior_architect" })
        #expect(senior.state == .hirable, "el tier 12 está contratable de verdad")
        #expect(senior.affordable, "y la plata le alcanza")

        let best = try #require(gameState.bestHire)
        #expect(best.typeId == "oficinista", "el firstTier de corporativo, no el Senior pagable")
        #expect(best.tier == 9)
        #expect(best.affordable)

        let player = try #require(gameState.player)
        let cost = try #require(gameState.currentQuote(player: player, typeId: "oficinista")?.cost)
        #expect(abs(cost - 9_520_610.36) < 0.01, "600 × 2,8⁸ × 4,2, sin tierPremium")
    }

    /// Abrir un piso sube la oferta a SU tier base, no al tier más alto que ese
    /// piso vende.
    ///
    /// **Antes pineaba lo contrario** (`unlockedFloorsRaiseTheOfferUpToTheGate`:
    /// tier 8, el Fast Food) y el escenario se dejó igual justamente por eso —
    /// el Fast Food sigue estando `hirable` y sigue estando pagado, así que lo
    /// único que puede dejarlo afuera es la regla nueva.
    ///
    /// Verificado a mano contra `economy.json`: con el callejón y el urbano
    /// abiertos, el urbano es `hireGateExempt` (se contrata sin abrir
    /// corporativo) y llega hasta el tier 8 (`urban` = 5-8), mientras que
    /// corporativo (9-12) ni siquiera está desbloqueado. El techo de PISO lo
    /// sigue poniendo el gate; adentro del piso, el que se ofrece es el
    /// `firstTier`: el Mantero, 600 × 2,8⁴ × 2,0 = 73.758,72.
    @Test("con el urbano abierto la oferta sube a su tier base, no a su tier más alto")
    func unlockedFloorsRaiseTheOfferUpToTheirBaseTier() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 8)   // abre alley + urban
        gameState.debugMarkTypesSeen(throughTier: 8)
        // 600 × 2,8⁷ × 2,0 × 1,8³ = 9.442.891,09 es el Fast Food: el millón de
        // `debugGrantCoins` no lo cubre solo.
        try giveCoins(10_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.tier == 5, "el firstTier del urbano, no el 8 que el mismo piso vende")
        #expect(best.typeId == "mantero")
        #expect(best.affordable)

        // El Fast Food estaba ahí y estaba pagado: lo que lo deja afuera del
        // atajo es la regla del tier base, no la plata ni la compuerta.
        let fastFood = try #require(gameState.jobRows.first { $0.id == "fast_food" })
        #expect(fastFood.state == .hirable)
        #expect(fastFood.affordable)

        let player = try #require(gameState.player)
        #expect(
            !player.run.unlockedFloors.contains("corporate"),
            "corporativo tiene que seguir cerrado: es lo que hace que el techo sea el urbano"
        )
        let cost = try #require(gameState.currentQuote(player: player, typeId: "mantero")?.cost)
        #expect(abs(cost - 73_758.72) < 0.01, "600 × 2,8⁴ × 2,0, sin tierPremium")
    }

    /// Cuando el tier base del piso más alto no se paga, la oferta baja al tier
    /// base del piso de ABAJO: el escalón es de piso, no de tier.
    ///
    /// **Antes bajaba de tier dentro del mismo piso** (tier 8 → tier 7, el
    /// Chofer de App); ese escalón ya no existe. El saldo es el mismo de aquel
    /// test —9.000.000— y ahora cae entre el Mantero (73.758,72) y el
    /// Oficinista (600 × 2,8⁸ × 4,2 = 9.520.610,36), así que lo que se ofrece es
    /// el urbano y no corporativo.
    @Test("si el tier base del piso más alto no se paga, la oferta baja un piso")
    func theOfferFallsBackToWhatTheCoinsActuallyCover() async throws {
        let gameState = await makeGameState()
        // Hasta lujo, que es lo que le abre el gate a corporativo; el Director
        // (tier 13) queda sin ver, así que no compite.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(9_000_000, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.tier == 5, "el firstTier del urbano")
        #expect(best.typeId == "mantero")
        #expect(best.affordable)

        // Y corporativo estaba abierto y contratable: lo único que lo frenó fue
        // el precio de SU tier base.
        let oficinista = try #require(gameState.jobRows.first { $0.id == "oficinista" })
        #expect(oficinista.state == .hirable)
        #expect(!oficinista.affordable, "9.520.610,36 no entra en 9.000.000")
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
        #expect(best.tier == 1,
                "con plata y piso abierto, lo único que frena la oferta en el Fisura es no haber visto al Mantero")
        #expect(best.typeId == "homeless")
    }

    @Test("sin plata, la meta es el más barato de todos los tier base contratables")
    func withoutCoinsTheGoalIsTheCheapestOfMany() async throws {
        let gameState = await makeGameState()
        // Tres tier base contratables (Fisura, Mantero y Oficinista) y cero
        // monedas: acá el que elige es el `min` por costo, no el único candidato
        // que hay. Es la única rama de `computeBestHire` donde los comparadores
        // siguen teniendo con qué comparar.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(0, to: gameState)
        gameState.refreshProjections()

        let best = try #require(gameState.bestHire)
        #expect(best.typeId == "homeless", "el de 25, no el de 9.520.610")
        #expect(best.tier == 1)
        #expect(best.costText == "25")
        #expect(!best.affordable)
    }

    /// Comprar un tier NO-base desde FisuJobs no mueve la oferta del atajo.
    ///
    /// **Antes este escenario probaba el desempate de precio** (`tiesOnTierPreferTheCheapest`):
    /// los cuatro Senior arrancan costando lo mismo, comprar uno le sube la
    /// curva —que es POR TIPO, `run.hireCountsByType`— y la oferta pasaba del
    /// Arquitecto al Médico. Ahora ninguno de los cuatro es la oferta, así que
    /// lo que el mismo escenario pinea es que el atajo **no escucha** las
    /// compras que se hacen por afuera de él: sigue siendo el Oficinista, y al
    /// mismo precio, porque la curva que lo mueve es la suya.
    @Test("comprar un tier no-base desde FisuJobs no mueve la oferta")
    func buyingANonBaseTypeDoesNotMoveTheOffer() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(4_000_000_000, to: gameState)
        gameState.refreshProjections()
        let before = try #require(gameState.bestHire)
        #expect(before.typeId == "oficinista")

        gameState.hireCharacter(typeId: "senior_architect")
        gameState.refreshProjections()

        // La compra entró de verdad —si no, el test no probaría nada— y la
        // oferta no se enteró.
        #expect(gameState.player?.run.hireCountsByType["senior_architect"] == 1)
        let best = try #require(gameState.bestHire)
        #expect(best.tier == 9, "el firstTier de corporativo, antes y después")
        #expect(best.typeId == "oficinista")
        #expect(best.costText == before.costText, "la curva que mueve la oferta es la del Oficinista")
    }

    /// Las ocho ramas de carrera de corporativo —los cuatro Jr. y los cuatro
    /// Sr.— no son la oferta, ni una.
    ///
    /// **Antes este escenario pineaba el desempate por id**
    /// (`tiesFallBackToTheAscendingID`): el tier 12 tiene CUATRO tipos concretos
    /// y el precio no depende del id —`hireCost` es `multiplicador ×
    /// tapYield(tier) × incomeMultiplier × tierPremium^(tier − firstTier) ×
    /// growth^compras`, y las compras de los cuatro están en 0—, así que
    /// empataban en tier Y en costo (600 × 2,8¹¹ × 4,2 × 1,8³ = 1.218.867.229,80
    /// cada uno) y ganaba el id ascendente.
    ///
    /// El empate se conserva como assert porque es lo que hace fuerte al test
    /// nuevo: los ocho están vistos, contratables y pagados, y aun así el atajo
    /// ofrece el tier 9. Ese desempate ya **no es alcanzable** —después del
    /// filtro cada piso aporta un solo candidato— y el comentario de
    /// `computeBestHire` explica por qué los comparadores se conservan igual.
    @Test("las ramas de carrera no son la oferta, aunque estén pagadas")
    func careerBranchesAreNeverTheOffer() async throws {
        let gameState = await makeGameState()
        // Abrir hasta lujo es lo que le abre el gate a corporativo (necesita el
        // piso de arriba); lujo mismo queda gated y sin ver, así que no compite.
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        try giveCoins(2_000_000_000, to: gameState)
        gameState.refreshProjections()

        let branches = [
            "junior_architect", "junior_doctor", "junior_lawyer", "junior_programmer",
            "senior_architect", "senior_doctor", "senior_lawyer", "senior_programmer",
        ]
        // Las ocho son ofertas vivas de FisuJobs en este mismo estado.
        for id in branches {
            let row = try #require(gameState.jobRows.first { $0.id == id })
            #expect(row.state == .hirable, "\(id) tiene que estar contratable para que el test pruebe algo")
            #expect(row.affordable, "\(id) tiene que estar pagado para que el test pruebe algo")
        }

        let best = try #require(gameState.bestHire)
        #expect(!branches.contains(best.typeId), "ninguna rama de carrera es tier base de su piso")
        #expect(best.tier == 9)
        #expect(best.typeId == "oficinista")
        #expect(best.affordable)

        // Y el empate de los cuatro Sr. sigue siendo real: es lo que el atajo
        // ya no tiene que desempatar.
        let player = try #require(gameState.player)
        let quotes = ["senior_architect", "senior_doctor", "senior_lawyer", "senior_programmer"]
            .compactMap { gameState.currentQuote(player: player, typeId: $0)?.cost }
        #expect(quotes.count == 4)
        #expect(Set(quotes).count == 1, "los cuatro cotizan 1.218.867.229,80")
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
        // 25 × 1,2 = 30, la curva por tipo de `hireCountsByType`.
        #expect(gameState.bestHire?.typeId == "homeless")
        #expect(gameState.bestHire?.costText == "30", "el segundo Fisura cuesta 30 (growth 1,2)")
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
