import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La proyección de FisuJobs (§5.1) y la contratación por tipo.
///
/// Lo que estos tests protegen no es el formato de una fila: es **qué se puede
/// comprar**. La cotización por tipo (`TowerActions.hireQuote(typeId:)`) le pone
/// precio a cualquier personaje del juego —también a los de pisos que todavía no
/// abriste—, y su docstring lo dice explícito: *cotizar un tipo no es
/// autorizarlo*. La autorización la reparten dos piezas, y las dos están acá:
/// `jobRows` decide qué fila se ofrece, y los guards de `TowerActions.hire`
/// (piso abierto, gate, saldo, slot) rechazan lo que igual se intente comprar.
@Suite("FisuJobs: filas y contratación por tipo", .serialized)
@MainActor
struct JobRowsTests {
    private func jobRow(_ gameState: GameState, _ typeId: String) throws -> JobRow {
        try #require(gameState.jobRows.first { $0.id == typeId })
    }

    // MARK: La proyección

    @Test("partida nueva: el Fisura se contrata a 25 y nadie más se espoilea")
    func newGameOffersOnlyTheFisura() async throws {
        let gameState = await makeGameState()
        let rows = gameState.jobRows

        let first = try #require(rows.first)
        #expect(first.id == "homeless")
        #expect(first.state == .hirable)
        #expect(first.costText == "25", "el primer Fisura cuesta 25 (decisión del dueño)")
        // ⚠️ El nombre viaja TRADUCIDO (`tier.name.<id>`) y el runner corre la
        // app en inglés (trampa 6), así que pinearlo en castellano haría pasar
        // el test por la razón equivocada. Lo que importa acá es el contraste
        // con el "???" del no visto; que la traducción exista la cubre
        // `GameContentValidationTests.everyTierHasItsNameInBothLanguages`.
        #expect(first.displayName != "???")
        #expect(first.faceKey == "homeless_face")
        #expect(first.hiredCount == 1, "la unidad con la que arranca la partida")
        #expect(first.purchases == 0)
        #expect(first.tier == 1)
        #expect(first.floorID == "alley")
        #expect(!first.affordable, "arrancás con 0 monedas")

        let rest = rows.dropFirst()
        #expect(rest.allSatisfy { $0.state == .unseen })
        #expect(rest.allSatisfy { $0.displayName == "???" })
        #expect(rest.allSatisfy { $0.costText.isEmpty })
        #expect(rest.allSatisfy { !$0.affordable })
    }

    @Test("el nodo de elección de carrera no es un laburo")
    func theChoiceNodeIsNotAJob() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)

        #expect(!gameState.jobRows.contains { $0.id == "junior" })
        #expect(gameState.jobRows.count == content.tiers.concreteTypes.count)
    }

    @Test("los contratables bajan por tier y los bloqueados suben")
    func rowsAreGroupedByWhatYouCanDoWithThem() async throws {
        let gameState = await makeGameState()
        // Abre callejón + urbano + corporativo, y muestra hasta lujo.
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.debugMarkTypesSeen(throughTier: 16)
        // Frontera 11 y no 10: con la compuerta en 6 tiers, 11 deja el corte en
        // el MEDIO del urbano (5-8) en vez de justo en el borde del callejón, y
        // el corte a mitad de piso es lo único que la regla vieja no podía
        // producir.
        gameState.debugSetMaxTier(11)

        let rows = gameState.jobRows
        let hirable = rows.prefix { $0.state == .hirable || $0.state == .floorFull }
        #expect(hirable.map(\.tier) == [5, 4, 3, 2, 1], "el mejor arriba, como el Animal Shop")

        let blocked = rows.dropFirst(hirable.count).prefix { $0.state != .unseen }
        #expect(blocked.map(\.tier) == blocked.map(\.tier).sorted(), "los bloqueados suben: el próximo primero")
        #expect(blocked.first?.tier == 6, "el 6 está en un piso ABIERTO y aun así no se contrata")
        #expect(blocked.last?.tier == 16)

        let unseen = rows.dropFirst(hirable.count + blocked.count)
        #expect(!unseen.isEmpty)
        #expect(unseen.allSatisfy { $0.state == .unseen })
        #expect(unseen.allSatisfy { $0.tier >= 17 })
    }

    /// ⚠️ **Reescrito el 2026-08-22: la compuerta cambió de significado.** Decía
    /// "piso abierto con el gate cerrado dice qué piso hay que abrir" y
    /// asserteaba el nombre del piso de arriba. Ahora el estado dice a qué TIER
    /// hay que llegar, y el número está derivado a mano: tier del personaje +
    /// `hire.gateTierDistance`.
    @Test("piso abierto con la compuerta cerrada dice a qué tier hay que llegar")
    func closedGateNamesTheRequiredTier() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.debugMarkTypesSeen(throughTier: 16)
        let distancia = try #require(gameState.content?.economy.hire.gateTierDistance)

        // El oficinista es T9 y su piso está ABIERTO: lo que falta es frontera.
        let oficinista = try jobRow(gameState, "oficinista")
        #expect(oficinista.state == .gated(requiredTier: 9 + distancia))
        #expect(!oficinista.costText.isEmpty, "la fila bloqueada igual dice a cuánto va a salir")

        // Y dos tipos del MISMO piso piden tiers distintos, que es justo lo que
        // la compuerta por pisos no podía expresar.
        #expect(try jobRow(gameState, "repartidor").state == .gated(requiredTier: 6 + distancia))

        // Lujo ni siquiera está abierto: es otro estado y nombra su PROPIO piso.
        let director = try jobRow(gameState, "director")
        #expect(director.state == .lockedFloor(floorNameKey: TowerNaming.floorName(for: "luxury")))
    }

    @Test("un tipo visto se muestra con nombre aunque su piso esté cerrado")
    func seenTypesKeepTheirNameBehindALockedFloor() async throws {
        let gameState = await makeGameState()
        gameState.debugMarkTypesSeen(throughTier: 5)

        let mantero = try jobRow(gameState, "mantero")
        #expect(mantero.displayName != "???")
        #expect(mantero.state == .lockedFloor(floorNameKey: TowerNaming.floorName(for: "urban")))

        // Y el que nunca viste sigue siendo "???" aunque esté en el mismo piso.
        let repartidor = try jobRow(gameState, "repartidor")
        #expect(repartidor.state == .unseen)
        #expect(repartidor.displayName == "???")
    }

    @Test("con el piso lleno la fila lo dice")
    func fullFloorIsItsOwnState() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        let capacity = gameState.floorOccupancy(ordinal: 0).capacity

        for _ in gameState.floorOccupancy(ordinal: 0).occupied..<capacity {
            gameState.hireCharacter(typeId: "homeless")
        }

        #expect(gameState.floorOccupancy(ordinal: 0).occupied == capacity)
        #expect(try jobRow(gameState, "homeless").state == .floorFull)
    }

    @Test("los textos llegan resueltos: ninguna clave cruda llega a la pantalla")
    func textsAreResolvedInTheProjection() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.debugMarkTypesSeen(throughTier: 16)

        for row in gameState.jobRows {
            #expect(row.incomeText.contains("/s"), "la fila perdió la unidad, que es lo que la hace legible")
            #expect(!row.incomeText.contains("upgrades.character"), "quedó la clave cruda en pantalla")
        }
        guard case .lockedFloor(let floorName) = try jobRow(gameState, "director").state else {
            Issue.record("lujo todavía cerrado tiene que salir lockedFloor")
            return
        }
        #expect(!floorName.isEmpty)
        #expect(!floorName.contains("tower.floor"), "el nombre del piso llegó como clave, no como texto")
    }

    // MARK: La acción

    @Test("contratar coloca la unidad, cobra, cuenta por tipo y marca el FTUE")
    func hiringPlacesTheUnitAndMovesTheCounters() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        // El FTUE vive en UserDefaults, que sobrevive entre tests del runner.
        UserDefaults.standard.set(false, forKey: "ftue.spawned")
        gameState.ftueSpawned = false
        let coinsBefore = try #require(gameState.player?.run.coins)
        let boardBefore = gameState.boardVersion

        gameState.hireCharacter(typeId: "homeless")

        #expect(gameState.player?.run.units["homeless"] == 2)
        #expect(gameState.player?.run.hireCountsByType["homeless"] == 1)
        #expect(gameState.player?.meta.stats.totalHiresEver == 1)
        #expect(gameState.player?.run.coins == coinsBefore - 25)
        #expect(gameState.boardVersion > boardBefore, "la escena tiene que redibujar el piso")
        #expect(gameState.ftueSpawned)
        #expect(gameState.ftueMilestones.spawned, "el tutorial avanza con esta bandera")
    }

    @Test("cada contratación mueve la curva de ESE tipo y de ningún otro")
    func hiringMovesItsOwnCurve() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.debugMarkTypesSeen(throughTier: 4)
        let neighbourBefore = try jobRow(gameState, "trapito").costText

        gameState.hireCharacter(typeId: "homeless")

        let row = try jobRow(gameState, "homeless")
        // El contador es la prueba directa de que la curva se movió; el TEXTO
        // atrasa una compra desde la quinta ronda, porque el callejón cotiza con
        // el 3% por compra y 25 × 1,03 = 25,75 se muestra truncado a 25.
        #expect(row.purchases == 1)
        #expect(row.costText == "25", "25 × 1,03 = 25,75, truncado")
        #expect(row.hiredCount == 2)
        #expect(try jobRow(gameState, "trapito").costText == neighbourBefore)

        // A la segunda el precio ya se ve moverse: 25 × 1,03² = 26,52.
        gameState.hireCharacter(typeId: "homeless")
        #expect(try jobRow(gameState, "homeless").costText == "26")
        #expect(try jobRow(gameState, "trapito").costText == neighbourBefore,
                "y el vecino sigue sin enterarse")
    }

    @Test("sin plata no contrata, y no miente con un aviso de piso lleno")
    func hiringWithoutCoinsDoesNothing() async throws {
        let gameState = await makeGameState()

        gameState.hireCharacter(typeId: "homeless")

        #expect(gameState.player?.run.units["homeless"] == 1)
        #expect(gameState.player?.run.hireCountsByType["homeless"] == nil)
        #expect(gameState.towerNotice == nil)
    }

    @Test("el piso lleno avisa en vez de cobrar")
    func hiringOnAFullFloorRaisesTheNotice() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        let capacity = gameState.floorOccupancy(ordinal: 0).capacity
        for _ in gameState.floorOccupancy(ordinal: 0).occupied..<capacity {
            gameState.hireCharacter(typeId: "homeless")
        }
        let unitsBefore = gameState.player?.run.units["homeless"]
        let coinsBefore = gameState.player?.run.coins

        gameState.hireCharacter(typeId: "homeless")

        #expect(gameState.towerNotice?.kind == .floorFull)
        #expect(gameState.player?.run.units["homeless"] == unitsBefore)
        #expect(gameState.player?.run.coins == coinsBefore)
    }

    @Test("un tipo de piso cerrado cotiza pero no se vende")
    func lockedFloorQuotesButDoesNotSell() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.debugMarkTypesSeen(throughTier: 5)

        gameState.hireCharacter(typeId: "mantero")

        #expect(gameState.player?.run.units["mantero"] == nil, "el guard de `hire` es el que cobra la regla")
        #expect(gameState.player?.run.hireCountsByType["mantero"] == nil)
        #expect(gameState.towerNotice == nil)
    }

    @Test("con el gate cerrado tampoco se vende, aunque el piso esté abierto")
    func closedGateDoesNotSell() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugGrantCoins()

        gameState.hireCharacter(typeId: "oficinista")

        #expect(gameState.player?.run.units["oficinista"] == nil)
        #expect(gameState.player?.run.hireCountsByType["oficinista"] == nil)
    }

    @Test("contratar un tipo que no existe no hace nada")
    func hiringAnUnknownTypeIsANoOp() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        let coinsBefore = gameState.player?.run.coins

        gameState.hireCharacter(typeId: "no_existe")
        gameState.hireCharacter(typeId: "junior")

        #expect(gameState.player?.run.coins == coinsBefore)
        #expect(gameState.player?.run.units["junior"] == nil)
    }
}
