import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Corralito en el juego")
@MainActor
struct CorralitoTests {
    @Test("el evento congela el gasto con su motivo, y el video lo levanta")
    func corralitoFreezesAndTheVideoLifts() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.debugStartCorralito()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil != nil)
        let base = try #require(gameState.content?.tiers.baseType.id)
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units)
        #expect(gameState.towerNotice?.kind == .spendingFrozen)
        gameState.escapeActiveEvent()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil == nil)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units + 1)
    }

    @Test("el JSON del Corralito dice lo que hace")
    func corralitoDataMatchesTheDecision() async throws {
        let gameState = await makeGameState()
        let corralito = try #require(gameState.content?.events.events.first { $0.id == "corralito" })
        #expect(corralito.effectType == .spendingFrozen)
        #expect(corralito.escape == "video")
        #expect(corralito.durationSeconds == 45)
    }
}
