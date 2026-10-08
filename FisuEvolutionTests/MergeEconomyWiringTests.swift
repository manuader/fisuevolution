import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las fusiones del juego —la del jugador y las del embudo de cambios— usan la
/// misma cuenta que el simulador: amortiguan la frontera y devuelven el reintegro.
@Suite("Las fusiones del juego pasan por el amortiguador y el reintegro", .serialized)
@MainActor
struct MergeEconomyWiringTests {
    private func game(_ knobs: EconomyKnobs) async throws -> GameState {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let tuned = try content.economy.tuned(knobs)
        gameState.replaceEconomy(tuned)
        gameState.debugGrantCoins()
        return gameState
    }

    private func homelessPair(_ gameState: GameState) throws -> (source: Int, target: Int) {
        let slots = gameState.visiblePlacements.filter { $0.typeId == "homeless" }.map(\.slot).sorted()
        try #require(slots.count >= 2)
        return (slots[0], slots[1])
    }

    private func price(_ gameState: GameState) throws -> Double {
        let player = try #require(gameState.player)
        return try #require(gameState.currentQuote(player: player, typeId: "homeless")).cost
    }

    @Test("con el amortiguador, fusionar y subir la frontera no hace saltar el precio")
    func mergingDoesNotJumpThePrice() async throws {
        let gameState = try await game(EconomyKnobs(priceReliefPurchases: 24))
        gameState.hireCharacter(typeId: "homeless")
        let before = try price(gameState)
        let pair = try homelessPair(gameState)
        _ = gameState.handleDrop(fromCell: pair.source, toCell: pair.target)
        #expect(gameState.player?.run.maxTierReached == 2)
        let after = try price(gameState)
        #expect(abs(after / before - 1) < 1e-9)
    }

    @Test("sin el amortiguador, el precio salta como en la v1")
    func withoutTheCushionThePriceJumps() async throws {
        let gameState = try await game(EconomyKnobs())
        gameState.hireCharacter(typeId: "homeless")
        let before = try price(gameState)
        let pair = try homelessPair(gameState)
        _ = gameState.handleDrop(fromCell: pair.source, toCell: pair.target)
        let after = try price(gameState)
        #expect(abs(after / before - 2.8 / 1.5) < 1e-9)
    }

    @Test("con el reintegro, la fusión del jugador devuelve compras a la curva")
    func mergingRefundsPurchases() async throws {
        let gameState = try await game(EconomyKnobs(mergeRefundCounts: 1))
        gameState.hireCharacter(typeId: "homeless")
        gameState.hireCharacter(typeId: "homeless")
        #expect(gameState.player?.run.hireCountsByType["homeless"] == 2)
        let pair = try homelessPair(gameState)
        _ = gameState.handleDrop(fromCell: pair.source, toCell: pair.target)
        #expect(gameState.player?.run.hireCountsByType["homeless"] == 1)
    }

    @Test("un cambio del tablero que sube la frontera también amortigua")
    func boardChangesAreCushionedToo() async throws {
        let gameState = try await game(EconomyKnobs(priceReliefPurchases: 24))
        gameState.hireCharacter(typeId: "homeless")
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let tower = try #require(gameState.tower)
        let change = try #require(BoardChangePlanner.planAutoMerge(
            state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        gameState.enqueueBoardChange(change)
        let running = try #require(gameState.beginNextBoardChange())
        gameState.confirmBoardChange(id: running.id)
        #expect(abs((gameState.player?.run.priceRelief ?? 0) - 2.8 / 1.5) < 1e-9)
    }
}
