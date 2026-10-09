import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El punto de Regalos avisa también de un boost gratis listo (PLAN-v2 E13).
@Suite("El punto de Regalos y los boosts")
@MainActor
struct GiftsBadgeTests {
    @Test("con el Mate desbloqueado y frío, el punto se prende; activarlo lo apaga")
    func readyBoostLightsTheDot() async throws {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.hasReadyBoost, "el Mate se abre en el callejón")
        _ = gameState.activateBoost(id: "mate")
        gameState.refreshProjections()
        #expect(!gameState.hasReadyBoost, "los demás boosts siguen cerrados")
    }

    @Test("vencido el enfriamiento, vuelve")
    func cooldownEndRelights() async throws {
        let gameState = await makeGameState()
        _ = gameState.activateBoost(id: "mate")
        let cooldown = try #require(gameState.content?.boosts.boosts.first { $0.id == "mate" }?.cooldownSeconds)
        gameState.player?.meta.boostActivations["mate"] = Date().timeIntervalSince1970 - cooldown - 1
        gameState.refreshProjections()
        #expect(gameState.hasReadyBoost)
    }
}
