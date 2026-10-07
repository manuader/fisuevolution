import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Offline: el popup sólo desde el umbral")
@MainActor
struct OfflinePopupTests {
    private func producingGame() async throws -> GameState {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        return gameState
    }

    @Test("diez segundos afuera se acreditan en silencio")
    func shortAbsenceIsSilent() async throws {
        let gameState = try await producingGame()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.lastSeenTimestamp = now - 10
        let before = try #require(gameState.player?.run.coins)
        gameState.applyOfflineProgressIfNeeded(now: now)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.offlineReward == nil)
    }

    @Test("una hora afuera abre el popup con lo acreditado")
    func longAbsenceShowsThePopup() async throws {
        let gameState = try await producingGame()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.lastSeenTimestamp = now - 3600
        gameState.applyOfflineProgressIfNeeded(now: now)
        #expect((gameState.offlineReward?.amount ?? 0) > 0)
    }
}
