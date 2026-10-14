import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El «otro colchón» sobrevive a matar la app")
@MainActor
struct MattressExtraSavedTests {
    /// Lo que pasa al matar y volver a abrir: el save sale y entra por JSON y el runtime nace vacío.
    private func relaunch(_ gameState: GameState) throws {
        let data = try JSONEncoder().encode(try #require(gameState.player))
        gameState.player = try JSONDecoder().decode(PlayerState.self, from: data)
        gameState.mattressPopup = nil
        gameState.refreshPrizeAccess()
    }

    private func openedFirst() async throws -> GameState {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        _ = try #require(gameState.openMattressOnBoard())
        _ = try #require(gameState.mattressPopup?.outcome)
        return gameState
    }

    @Test("matar con el popup abierto después del primero: el «otro colchón» vuelve por la columna y paga una vez")
    func comesBackAndPaysOnce() async throws {
        let gameState = try await openedFirst()
        try relaunch(gameState)
        #expect(gameState.prizeAccess.mattressExtraReady)
        #expect(!gameState.prizeAccess.mattressReady, "el colchón de verdad no está esperando")
        #expect(gameState.sideRailTapped(.mattress) == .acted)
        #expect(gameState.mattressPopup?.extraOnly == true)
        gameState.extraMattressVideoWatched()
        let second = try #require(gameState.mattressPopup?.outcome)
        #expect(second.extraOpensLeft == 0)
        let coins = gameState.player?.run.coins
        let blue = gameState.player?.meta.blue
        gameState.extraMattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome == second)
        #expect(gameState.player?.run.coins == coins && gameState.player?.meta.blue == blue, "el video paga una sola vez")
        try relaunch(gameState)
        #expect(!gameState.prizeAccess.mattressExtraReady, "usado, no vuelve")
        #expect(gameState.sideRailTapped(.mattress) == .refused)
    }

    @Test("matar después de usarlo no lo duplica ni vuelve a cobrar el primero")
    func noDuplicate() async throws {
        let gameState = try await openedFirst()
        gameState.extraMattressVideoWatched()
        try relaunch(gameState)
        #expect(gameState.mattressExtraOpensLeft == 0)
        #expect(gameState.openMattress() == nil)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("cerrar sin pedirlo no lo gasta: sigue en la columna; el reloj de 8 min no se toca")
    func closingKeepsIt() async throws {
        let gameState = try await openedFirst()
        let clock = gameState.player?.meta.engagement.treasures.secondsUntilNext
        gameState.closeMattressPopup()
        try relaunch(gameState)
        #expect(gameState.mattressExtraPending)
        #expect(gameState.player?.meta.engagement.treasures.secondsUntilNext == clock)
    }

    @Test("un colchón nuevo reemplaza al «otro colchón» pendiente: una vez por colchón")
    func newMattressSupersedes() async throws {
        let gameState = try await openedFirst()
        try relaunch(gameState)
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressInPlay)
        #expect(!gameState.mattressExtraPending)
        if gameState.mattressWaiting {
            #expect(gameState.sideRailTapped(.mattress) == .acted)
            #expect(gameState.mattressPopup?.extraOnly == false)
        } else {
            #expect(gameState.mattressOnBoard, "de regalo, directo al tablero")
            #expect(gameState.sideRailTapped(.mattress) == .refused, "se abre en el tablero, no en la columna")
        }
    }

    @Test("un save viejo sin el campo carga sin «otro colchón»; un reset lo borra")
    func oldSaveAndReset() async throws {
        let gameState = try await openedFirst()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(gameState.player)) as? [String: Any])
        var meta = try #require(json["meta"] as? [String: Any])
        var engagement = try #require(meta["engagement"] as? [String: Any])
        var treasures = try #require(engagement["treasures"] as? [String: Any])
        treasures.removeValue(forKey: "extraOpensLeft")
        engagement["treasures"] = treasures
        meta["engagement"] = engagement
        json["meta"] = meta
        let old = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.meta.engagement.treasures.extraOpensLeft == 0)
        let plan = try #require(gameState.resetPlan())
        #expect(plan.result.meta.engagement.treasures.extraOpensLeft == 0)
    }
}

@Suite("El «otro colchón» y el reloj del colchón nuevo")
@MainActor
struct MattressExtraClockTests {
    @Test("con el popup del «otro colchón» abierto, el próximo colchón no pisa el pago")
    func newMattressWaitsForThePopup() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.openMattressOnBoard()
        gameState.closeMattressPopup()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup?.extraOnly == true)
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(!gameState.mattressInPlay)
        gameState.extraMattressVideoWatched()
        let paid = try #require(gameState.mattressPopup?.outcome, "el video se vio y tiene que pagar")
        #expect(paid.extraOpensLeft == 0)
    }
}
