import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// RF-08: el mapa de pisos. Lo que se prueba acá es la PROYECCIÓN —que lista
/// toda la torre, que la lee de arriba para abajo y que un piso bloqueado no es
/// un destino— y la regla de duración del vuelo. El vuelo en sí no se testea:
/// un test no ve un tirón.
@Suite("Mapa de pisos")
@MainActor
struct FloorMapTests {
    /// Copia local a propósito: el helper compartido de fixtures lo está
    /// creando otro frente de la misma ola y dos árboles no pueden crear el
    /// mismo archivo sin chocar.
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "map-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    @Test("el mapa lista todos los pisos, de Dios para abajo, con los bloqueados marcados")
    func mapListsEveryFloor() async throws {
        let gameState = await makeGameState()
        let map = gameState.floorMap

        #expect(map.count == gameState.content?.economy.floors.count)
        #expect(map.first?.ordinal == map.count - 1, "Dios va primero: la torre se lee de arriba para abajo")
        #expect(map.last?.isUnlocked == true, "el callejón siempre está abierto")
        #expect(map.first?.isUnlocked == false, "en una partida nueva el último piso está cerrado")
        #expect(map.last?.isVisible == true, "una partida nueva arranca parada en el callejón")
        // Los ordinales bajan de a uno sin huecos: la vista los apila sin
        // volver a preguntarle nada al estado.
        #expect(map.map(\.ordinal) == Array((0..<map.count).reversed()))
    }

    @Test("cada fila trae lo que la vista dibuja, sacado de floors[]")
    func rowsCarryEverythingTheViewDraws() async throws {
        let gameState = await makeGameState()
        let floors = try #require(gameState.content?.floorTable.floors)
        let alley = try #require(gameState.floorMap.last)

        #expect(alley.id == floors[0].id)
        #expect(alley.backgroundKey == floors[0].background, "la miniatura sale del fondo real del piso")
        #expect(alley.capacity == floors[0].capacity)
        #expect(alley.occupied == gameState.floorOccupancy(ordinal: 0).occupied)
        #expect(alley.occupied > 0, "la partida nueva arranca con el Fisura inicial en el callejón")
    }

    @Test("saltar a un piso bloqueado no hace nada")
    func lockedFloorsAreNotReachable() async throws {
        let gameState = await makeGameState()
        let start = gameState.visibleFloorOrdinal

        gameState.jumpToFloor(ordinal: gameState.floorMap.count - 1)
        #expect(gameState.visibleFloorOrdinal == start)

        // Fuera de rango tampoco: la vista es data-driven y la torre cambia de
        // largo entre versiones.
        gameState.jumpToFloor(ordinal: -1)
        gameState.jumpToFloor(ordinal: gameState.floorMap.count + 5)
        #expect(gameState.visibleFloorOrdinal == start)
    }

    @Test("saltar a un piso desbloqueado lleva directo, sin pasar por los del medio")
    func unlockedFloorsAreReachableInOneJump() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 30)
        let map = gameState.floorMap
        let top = try #require(map.first { $0.isUnlocked })
        #expect(top.ordinal > gameState.visibleFloorOrdinal + 1, "el fixture tiene que abrir más de un piso")

        let versionBefore = gameState.boardVersion
        gameState.jumpToFloor(ordinal: top.ordinal)

        #expect(gameState.visibleFloorOrdinal == top.ordinal)
        #expect(gameState.towerNavigation.floorID == top.id)
        #expect(gameState.boardVersion > versionBefore, "la escena tiene que enterarse del salto")
        #expect(gameState.floorMap.first { $0.isVisible }?.ordinal == top.ordinal)
    }

    /// El vuelo dura más cuanto más lejos vas, pero se aplana: el salto más
    /// largo posible no puede durar diez veces más que el más corto o deja de
    /// ser un atajo. La regla sale del ALTO DE LA TORRE, así que sigue dando
    /// 0,6…0,9 s cuando la Ola 2 la deje en diez pisos.
    @Test("la duración del vuelo se aplana entre 0,6 y 0,9 s para cualquier torre")
    func flightDurationStaysInsideItsBudget() throws {
        for totalFloors in [4, 10, 11, 20] {
            #expect(BoardScene.flightDuration(floors: 2, totalFloors: totalFloors) == 0.6)
            #expect(BoardScene.flightDuration(floors: totalFloors - 1, totalFloors: totalFloors) == 0.9)
            var previous = 0.0
            for distance in 2...(totalFloors - 1) {
                let duration = BoardScene.flightDuration(floors: distance, totalFloors: totalFloors)
                #expect(duration >= 0.6 && duration <= 0.9, "\(distance)/\(totalFloors) se fue del presupuesto")
                #expect(duration >= previous, "un salto más largo no puede durar menos")
                previous = duration
            }
        }
    }
}
