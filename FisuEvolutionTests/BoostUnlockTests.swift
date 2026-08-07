import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// RF-12 (se desbloquean por piso) + RF-06 (dicen qué hacen) para los boosts.
///
/// El mapeo boost→piso vive en `boosts.json`: estos tests verifican la CONDUCTA
/// (uno solo al arranque, el resto detrás de su piso), no el reparto exacto, para
/// que rebalancearlo siga siendo editar el JSON.
@Suite("Boosts: desbloqueo y descripción")
@MainActor
struct BoostUnlockTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "boost-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    /// Mueve el piso máximo alcanzado de la cuenta, que es contra lo que se mide
    /// el desbloqueo (y no contra los pisos de la run: reencarnar no te los saca).
    private func reachFloor(_ floorId: String, in gameState: GameState) throws {
        let content = try #require(gameState.content)
        var player = try #require(gameState.player)
        player.meta.stats.maxFloorOrdinalEver = try #require(content.floorTable.ordinal(of: floorId))
        gameState.player = player
    }

    @Test("en una partida nueva sólo está disponible el primer boost")
    func boostsUnlockByFloor() async {
        let gameState = await makeGameState()
        let available = gameState.boostRows.filter(\.isUnlocked)

        #expect(available.count == 1)
        #expect(available.first?.id == "mate")
    }

    @Test("cada boost aparece al alcanzar su piso")
    func eachBoostAppearsAtItsFloor() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)

        for boost in content.boosts.boosts {
            try reachFloor(boost.unlockFloorId, in: gameState)
            let row = try #require(gameState.boostRows.first { $0.id == boost.id })
            #expect(row.isUnlocked, "\(boost.id) tendría que abrirse en \(boost.unlockFloorId)")
            #expect(row.unlockFloorName == nil, "un boost abierto no muestra requisito")
        }
    }

    @Test("el boost bloqueado dice en qué piso se abre")
    func lockedRowNamesItsFloor() async throws {
        let gameState = await makeGameState()
        let locked = try #require(gameState.boostRows.first { !$0.isUnlocked })

        #expect(locked.unlockFloorName?.isEmpty == false, "sin el nombre del piso, el candado no dice nada")
    }

    @Test("activar un boost bloqueado no hace nada")
    func lockedBoostCannotBeActivated() async throws {
        let gameState = await makeGameState()
        let locked = try #require(gameState.boostRows.first { !$0.isUnlocked })
        let before = gameState.player?.run.activeModifiers.count ?? 0

        _ = gameState.activateBoost(id: locked.id)

        #expect(gameState.player?.run.activeModifiers.count == before)
        #expect(gameState.player?.meta.boostActivations[locked.id] == nil, "un boost bloqueado tampoco puede quemar su cooldown")
    }

    /// La Ola 2 retira `cosmic` de la torre: un boost atado a ese piso quedaría
    /// inalcanzable sin que nadie se entere.
    @Test("ningún boost depende de un piso que la Ola 2 retira")
    func noBoostDependsOnCosmic() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        for boost in content.boosts.boosts {
            #expect(boost.unlockFloorId != "cosmic", "\(boost.id) queda inalcanzable cuando se retire cosmic")
        }
    }

    @Test("ningún boost queda sin decir qué hace")
    func everyBoostExplainsItself() async {
        let gameState = await makeGameState()
        for row in gameState.boostRows {
            #expect(!row.effectText.isEmpty, "\(row.id) no dice qué hace")
            #expect(!row.flavorText.isEmpty, "\(row.id) no tiene texto de color")
        }
    }

    @Test("el boost de costo se lee como descuento")
    func mateReadsAsDiscount() async throws {
        let gameState = await makeGameState()
        let mate = try #require(gameState.boostRows.first { $0.id == "mate" })

        #expect(mate.effectText.contains("30%"), "magnitud 0,7 es −30%, no '0,7'")
        #expect(!mate.effectText.contains("0,7"))
    }
}
