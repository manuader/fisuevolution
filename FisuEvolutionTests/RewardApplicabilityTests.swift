import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Videos: sin efecto no se cobra el cooldown")
@MainActor
struct RewardApplicabilityTests {
    @Test("sin pares, la evolución gratis no se ofrece y dice por qué")
    func freeMergeWithoutPairsIsNotOffered() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.isRewardApplicable("accelerate_evolution"))
        let row = try #require(gameState.rewardRows.first { $0.id == "accelerate_evolution" })
        let reason = try #require(row.unavailableReason)
        #expect(!reason.contains("ads.unavailable"), "la clave cruda no puede llegar a pantalla")
        #expect(row.cooldownRemaining == 0)
    }

    @Test("con un par, la evolución gratis se ofrece sin motivo de rechazo")
    func freeMergeWithPairIsOffered() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        #expect(gameState.isRewardApplicable("accelerate_evolution"))
        let row = try #require(gameState.rewardRows.first { $0.id == "accelerate_evolution" })
        #expect(row.unavailableReason == nil)
    }

    @Test("los videos que siempre aplican nunca traen motivo de rechazo")
    func alwaysApplicableRewardsHaveNoReason() async throws {
        let gameState = await makeGameState()
        for id in ["double_earnings", "temp_multiplier"] {
            let row = try #require(gameState.rewardRows.first { $0.id == id })
            #expect(row.unavailableReason == nil)
        }
    }

    @Test("si dejó de aplicar durante el video, compensa los minutos del dato")
    func inapplicableAtTheEndCompensates() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player?.run.coins)
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.pendingBoardChanges.isEmpty)
        if case .rewardCompensated? = gameState.towerNotice?.kind {} else {
            Issue.record("falta el aviso de la compensación")
        }
        #expect(gameState.rewardCooldownRemaining(id: "accelerate_evolution") > 0, "el video se miró")
    }

    @Test("un video que aplica no compensa: paga el cambio, no la plata")
    func applicableRewardDoesNotCompensate() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        let before = try #require(gameState.player?.run.coins)
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        #expect(try #require(gameState.player?.run.coins) == before)
        #expect(gameState.pendingBoardChanges.count == 1)
        #expect(gameState.towerNotice == nil)
    }

    @Test("un cambio de video que ya no cabe en su turno también compensa, una sola vez")
    func staleRewardedChangeCompensates() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        let before = try #require(gameState.player?.run.coins)
        let change = try #require(gameState.pendingBoardChanges.first)
        gameState.pendingBoardChanges.removeAll()
        gameState.discardBoardChange(change)
        let paid = try #require(gameState.player?.run.coins)
        #expect(paid > before)
        gameState.settleAllPendingBoardChanges()
        #expect(try #require(gameState.player?.run.coins) == paid, "no queda nada pendiente que pague de nuevo")
    }

    @Test("descartar un cambio que no vino de un video no paga nada")
    func discardingNonVideoChangeDoesNotPay() async throws {
        let gameState = await makeGameState()
        gameState.debugPlanBoardChange()
        let change = try #require(gameState.pendingBoardChanges.first)
        let before = try #require(gameState.player?.run.coins)
        gameState.pendingBoardChanges.removeAll()
        gameState.discardBoardChange(change)
        #expect(try #require(gameState.player?.run.coins) == before)
    }
}
