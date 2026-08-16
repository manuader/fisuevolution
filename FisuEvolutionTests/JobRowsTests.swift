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

    @Test("partida nueva: el Fisura se contrata a 50 y nadie más se espoilea")
    func newGameOffersOnlyTheFisura() async throws {
        let gameState = await makeGameState()
        let rows = gameState.jobRows

        let first = try #require(rows.first)
        #expect(first.id == "homeless")
        #expect(first.state == .hirable)
        #expect(first.costText == "50", "el primer Fisura cuesta 50 (decisión del dueño)")
        #expect(first.displayName == "El Fisura")
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

        let rows = gameState.jobRows
        let hirable = rows.prefix { $0.state == .hirable || $0.state == .floorFull }
        // Callejón (1-4) y urbano (5-8): el urbano es `hireGateExempt`.
        #expect(hirable.map(\.tier) == [8, 7, 6, 5, 4, 3, 2, 1], "el mejor arriba, como el Animal Shop")

        let blocked = rows.dropFirst(hirable.count).prefix { $0.state != .unseen }
        #expect(blocked.map(\.tier) == blocked.map(\.tier).sorted(), "los bloqueados suben: el próximo primero")
        #expect(blocked.first?.tier == 9)
        #expect(blocked.last?.tier == 16)

        let unseen = rows.dropFirst(hirable.count + blocked.count)
        #expect(!unseen.isEmpty)
        #expect(unseen.allSatisfy { $0.state == .unseen })
        #expect(unseen.allSatisfy { $0.tier >= 17 })
    }

    @Test("piso abierto con el gate cerrado dice qué piso hay que abrir")
    func closedGateNamesTheFloorAbove() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.debugMarkTypesSeen(throughTier: 16)

        // Corporativo está ABIERTO pero su gate pide lujo.
        let oficinista = try jobRow(gameState, "oficinista")
        #expect(oficinista.state == .gated(aboveFloorNameKey: TowerNaming.floorName(for: "luxury")))
        #expect(!oficinista.costText.isEmpty, "la fila bloqueada igual dice a cuánto va a salir")

        // Lujo ni siquiera está abierto: es otro estado y nombra su PROPIO piso.
        let director = try jobRow(gameState, "director")
        #expect(director.state == .lockedFloor(floorNameKey: TowerNaming.floorName(for: "luxury")))
    }

    @Test("un tipo visto se muestra con nombre aunque su piso esté cerrado")
    func seenTypesKeepTheirNameBehindALockedFloor() async throws {
        let gameState = await makeGameState()
        gameState.debugMarkTypesSeen(throughTier: 5)

        let mantero = try jobRow(gameState, "mantero")
        #expect(mantero.displayName == "El Mantero")
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
        guard case .gated(let floorName) = try jobRow(gameState, "oficinista").state else {
            Issue.record("el corporativo con el gate cerrado tiene que salir gated")
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
        #expect(gameState.player?.run.coins == coinsBefore - 50)
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
        #expect(row.costText == "60", "el segundo Fisura cuesta 60 (growth 1,2)")
        #expect(row.purchases == 1)
        #expect(row.hiredCount == 2)
        #expect(try jobRow(gameState, "trapito").costText == neighbourBefore)
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
