import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Videos: sin efecto no se cobra el cooldown")
@MainActor
struct RewardApplicabilityTests {
    @Test("sin pares, Fusionar todo no se ofrece y dice por qué")
    func freeMergeWithoutPairsIsNotOffered() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.isRewardApplicable("merge_all"))
        let row = try #require(gameState.rewardRows.first { $0.id == "merge_all" })
        let reason = try #require(row.unavailableReason)
        #expect(!reason.contains("ads.unavailable"), "la clave cruda no puede llegar a pantalla")
        #expect(row.cooldownRemaining == 0)
    }

    @Test("con un par, Fusionar todo se ofrece sin motivo de rechazo")
    func freeMergeWithPairIsOffered() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        #expect(gameState.isRewardApplicable("merge_all"))
        let row = try #require(gameState.rewardRows.first { $0.id == "merge_all" })
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
        gameState.applyRewardedReward(rewardId: "merge_all")
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.pendingBoardChanges.isEmpty)
        if case .rewardCompensated? = gameState.towerNotice?.kind {} else {
            Issue.record("falta el aviso de la compensación")
        }
        #expect(gameState.rewardCooldownRemaining(id: "merge_all") > 0, "el video se miró")
    }

    @Test("un video que aplica no compensa: paga el cambio, no la plata")
    func applicableRewardDoesNotCompensate() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        let before = try #require(gameState.player?.run.coins)
        gameState.applyRewardedReward(rewardId: "merge_all")
        #expect(try #require(gameState.player?.run.coins) == before)
        #expect(gameState.pendingBoardChanges.count >= 1)
        #expect(gameState.pendingBoardChanges.allSatisfy { $0.origin == .rewardedMergeAll })
        #expect(gameState.towerNotice == nil)
    }

    @Test("el cooldown se cobra una sola vez: un segundo toque no paga ni encola de nuevo")
    func rewardedMergeAllPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        gameState.applyRewardedReward(rewardId: "merge_all", now: 1000)
        let queued = gameState.pendingBoardChanges.count
        let coins = try #require(gameState.player?.run.coins)
        gameState.applyRewardedReward(rewardId: "merge_all", now: 1001)
        #expect(gameState.pendingBoardChanges.count == queued)
        #expect(try #require(gameState.player?.run.coins) == coins)
        #expect(gameState.rewardCooldownRemaining(id: "merge_all", now: 1001) > 0)
    }

    @Test("un eslabón de Fusionar todo que ya no cabe no compensa: el video ya pagó")
    func staleMergeAllLinkDoesNotCompensate() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        gameState.applyRewardedReward(rewardId: "merge_all")
        let before = try #require(gameState.player?.run.coins)
        gameState.pendingBoardChanges.forEach { gameState.discardBoardChange($0) }
        #expect(try #require(gameState.player?.run.coins) == before)
    }

    /// El video cobró el cooldown y planeó su llegada; después el tablero quedó sin lugar.
    private func gameStateWithStaleRewardedPlan() async throws -> (GameState, expectedPay: Double, before: Double) {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "spawn_rare")
        var tower = try #require(gameState.tower)
        for floor in tower.floors.indices {
            tower.floors[floor].slots = tower.floors[floor].slots.map { $0 ?? "homeless" }
        }
        gameState.tower = tower
        let player = try #require(gameState.player)
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let seconds = content.rewardedAds.compensationSeconds
        let pay = GameState.coinReward(seconds: seconds, player: player, content: content, economy: economy)
        return (gameState, pay, player.run.coins)
    }

    @Test("un cambio de video que ya no cabe, al asentar, compensa exacto y una sola vez")
    func staleRewardedChangeCompensatesOnSettle() async throws {
        let (gameState, pay, before) = try await gameStateWithStaleRewardedPlan()
        gameState.settleAllPendingBoardChanges()
        #expect(try #require(gameState.player?.run.coins) == before + pay)
        #expect(gameState.pendingBoardChanges.isEmpty)
        gameState.settleAllPendingBoardChanges()
        #expect(try #require(gameState.player?.run.coins) == before + pay, "no queda nada pendiente que pague de nuevo")
    }

    @Test("un cambio de video que ya no cabe en su turno compensa exacto")
    func staleRewardedChangeCompensatesOnTurn() async throws {
        let (gameState, pay, before) = try await gameStateWithStaleRewardedPlan()
        #expect(gameState.beginNextBoardChange() == nil)
        #expect(try #require(gameState.player?.run.coins) == before + pay)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("compensar suma el video mirado a los logros")
    func compensationEvaluatesAchievements() async throws {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "merge_all")
        let unlocked = try #require(gameState.player?.meta.unlockedAchievements)
        #expect(unlocked.contains("ach_videos_1"))
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
