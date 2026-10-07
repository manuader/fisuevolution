import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cambios del tablero: el turno")
@MainActor
struct BoardChangeWiringTests {
    /// Partida nueva con un par del tipo base planeado como lo planearía un video.
    private func gameWithPlannedMerge() async throws -> GameState {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let tower = try #require(gameState.tower)
        let change = try #require(BoardChangePlanner.planAutoMerge(
            state: player, tower: tower,
            tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        gameState.enqueueBoardChange(change)
        return gameState
    }

    @Test("con una hoja abierta el cambio espera")
    func waitsForTheBoard() async throws {
        let gameState = try await gameWithPlannedMerge()
        gameState.uiCoversBoard = true
        #expect(gameState.beginNextBoardChange() == nil)
        gameState.uiCoversBoard = false
        #expect(gameState.beginNextBoardChange() != nil)
    }

    @Test("confirmar aplica exactamente una vez")
    func confirmsExactlyOnce() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        let change = try #require(gameState.beginNextBoardChange())
        #expect(gameState.confirmBoardChange(id: change.id) != nil)
        #expect(gameState.confirmBoardChange(id: change.id) == nil)
        gameState.settleInFlightBoardChange()
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("el skip y el watchdog asientan en silencio lo que estaba en vuelo")
    func settlingConfirmsTheInFlightChange() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        _ = try #require(gameState.beginNextBoardChange())
        gameState.settleInFlightBoardChange()
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("al irse, todo lo pendiente queda aplicado antes de guardar")
    func sealSettlesEverything() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.handleScenePhase(from: .active, to: .background)
        await gameState.sealTask?.value
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("revelar sólo sube, y la red nombra al más alto sin revelar")
    func revealBookkeeping() async throws {
        let gameState = try await gameWithPlannedMerge()
        let change = try #require(gameState.beginNextBoardChange())
        gameState.confirmBoardChange(id: change.id)
        #expect(gameState.typePendingReveal?.tier == 2)
        gameState.markRevealed(tier: 2)
        gameState.markRevealed(tier: 1)
        #expect(gameState.player?.run.revealedTier == 2)
        #expect(gameState.typePendingReveal == nil)
    }
}
