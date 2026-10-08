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
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.confirmBoardChange(id: change.id) == nil)
        gameState.settleInFlightBoardChange()
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("confirmar con otro id no toca lo que está en vuelo")
    func aForeignIdLeavesTheInFlightChangeAlone() async throws {
        let gameState = try await gameWithPlannedMerge()
        let change = try #require(gameState.beginNextBoardChange())
        #expect(gameState.confirmBoardChange(id: UUID()) == nil)
        #expect(gameState.inFlightBoardChange == change)
    }

    @Test("con uno en vuelo no arranca otro")
    func onlyOneChangeIsInFlight() async throws {
        let gameState = try await gameWithPlannedMerge()
        gameState.debugGrantPair()
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let tower = try #require(gameState.tower)
        let second = try #require(BoardChangePlanner.planAutoMerge(
            state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        let first = try #require(gameState.beginNextBoardChange())
        gameState.enqueueBoardChange(second)
        #expect(gameState.beginNextBoardChange() == nil)
        #expect(gameState.inFlightBoardChange == first)
        #expect(gameState.pendingBoardChanges == [second])
    }

    @Test("si el tablero cambió entre el inicio y la confirmación, no se aplica")
    func aStaleChangeIsDiscardedOnConfirm() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        let change = try #require(gameState.beginNextBoardChange())
        guard case let .merge(ordinal, _, source, _, _) = change.kind else { Issue.record("no es un merge"); return }
        gameState.tower?.floors[ordinal].slots[source] = nil
        #expect(gameState.confirmBoardChange(id: change.id) == nil)
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units)
    }

    @Test("si el tablero replanea con otros slots, no se funden tipos distintos")
    func aReplannedChangeIsDiscardedOnConfirm() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let tower = try #require(gameState.tower)
        let planned = try #require(BoardChangePlanner.planAutoMerge(
            state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        gameState.enqueueBoardChange(planned)
        let change = try #require(gameState.beginNextBoardChange())
        guard case let .merge(ordinal, _, source, _, _) = change.kind else { Issue.record("no es un merge"); return }
        let other = try #require(content.tiers.concreteTypes.first { $0.tier == 2 })
        gameState.tower?.floors[ordinal].slots[source] = other.id
        let units = try #require(gameState.player?.run.totalUnits)
        #expect(gameState.confirmBoardChange(id: change.id) == nil)
        #expect(gameState.player?.run.totalUnits == units)
        #expect(gameState.tower?.floors[ordinal].slots[source] == other.id)
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

    @Test("al irse, lo que estaba en vuelo y lo que esperaba quedan aplicados")
    func sealSettlesTheInFlightChangeToo() async throws {
        let gameState = try await gameWithPlannedMerge()
        gameState.debugGrantPair()
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let tower = try #require(gameState.tower)
        let second = try #require(BoardChangePlanner.planAutoMerge(
            state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        let units = player.run.totalUnits
        _ = try #require(gameState.beginNextBoardChange())
        gameState.enqueueBoardChange(second)
        gameState.handleScenePhase(from: .active, to: .background)
        await gameState.sealTask?.value
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.totalUnits == units - 2)
    }

    @Test("al pasar a inactivo se asienta lo ya pagado (un video) y el resto espera a background")
    func inactiveSettlesOnlyWhatWasPaidFor() async throws {
        let gameState = try await gameWithPlannedMerge()
        gameState.debugGrantPair()
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        #expect(gameState.pendingBoardChanges.map(\.origin) == [.debug, .rewardedInstantMerge])
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.handleScenePhase(from: .active, to: .inactive)
        await gameState.sealTask?.value
        #expect(gameState.pendingBoardChanges.map(\.origin) == [.debug])
        #expect(gameState.player?.run.totalUnits == units - 1)
        gameState.handleScenePhase(from: .inactive, to: .background)
        await gameState.sealTask?.value
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.totalUnits == units - 2)
    }

    @Test("en vuelo: un video pagado se asienta al pasar a inactivo, un evento sigue en vuelo")
    func inactiveSettlesAPaidInFlightChange() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        _ = try #require(gameState.beginNextBoardChange())
        #expect(gameState.inFlightBoardChange?.origin == .rewardedInstantMerge)
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.handleScenePhase(from: .active, to: .inactive)
        await gameState.sealTask?.value
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units - 1)

        let eventState = try await gameWithPlannedMerge()
        _ = try #require(eventState.beginNextBoardChange())
        eventState.handleScenePhase(from: .active, to: .inactive)
        await eventState.sealTask?.value
        #expect(eventState.inFlightBoardChange?.origin == .debug)
    }

    @Test("reencarnar asienta lo pendiente de la run que se va")
    func prestigeSettlesThePendingChanges() async throws {
        let gameState = try await gameWithPlannedMerge()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.maxTierReached == 1)
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
