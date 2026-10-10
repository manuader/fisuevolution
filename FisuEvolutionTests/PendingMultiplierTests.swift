import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los premios nuevos de la tienda: auto-tap, Offline ×3 y Diario ×3")
@MainActor
struct PendingMultiplierTests {
    /// Tres Fisuras con su pasivo: la torre produce y una ausencia paga.
    private func producing() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 3]
        gameState.player?.run.passiveUnlocked["homeless"] = true
        gameState.reconcileTower()
        return gameState
    }

    @Test("el Offline ×3 triplica la vuelta del popup y se consume")
    func offlineTriples() async throws {
        let plain = await producing()
        let boosted = await producing()
        boosted.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        #expect(boosted.player?.meta.engagement.shop.pendingOfflineMultiplier == 3)
        for gameState in [plain, boosted] {
            gameState.player?.meta.lastSeenTimestamp = 1_000
            gameState.applyOfflineProgressIfNeeded(now: 1_000 + 3_600)
        }
        let base = try #require(plain.offlineReward?.amount)
        let tripled = try #require(boosted.offlineReward?.amount)
        #expect(abs(tripled - base * 3) < 1e-6 * tripled)
        #expect(boosted.player?.meta.engagement.shop.pendingOfflineMultiplier == nil)
    }

    @Test("una ausencia corta, sin popup, no gasta el ×3")
    func shortAbsenceKeepsIt() async throws {
        let gameState = await producing()
        gameState.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        gameState.player?.meta.lastSeenTimestamp = 1_000
        gameState.applyOfflineProgressIfNeeded(now: 1_000 + 10)
        #expect(gameState.offlineReward == nil)
        #expect(gameState.player?.meta.engagement.shop.pendingOfflineMultiplier == 3)
    }

    @Test("lo que agrega el ×3 llega a la caja y a lo ganado de por vida")
    func extraIsCredited() async throws {
        let gameState = await makeGameState()
        gameState.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        let before = try #require(gameState.player)
        #expect(gameState.applyPendingOfflineMultiplier(to: 100) == 300)
        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins + 200)
        #expect(after.meta.lifetimeEarnings == before.meta.lifetimeEarnings + 200)
        #expect(gameState.applyPendingOfflineMultiplier(to: 100) == 100, "se usa una vez")
    }

    @Test("sin nada que pagar, el ×3 no se gasta (magnitud 0)")
    func zeroAmountKeepsIt() async throws {
        let gameState = await makeGameState()
        gameState.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        #expect(gameState.applyPendingOfflineMultiplier(to: 0) == 0)
        #expect(gameState.player?.meta.engagement.shop.pendingOfflineMultiplier == 3)
    }

    @Test("un multiplicador que no multiplica (×1, ×0) no se guarda")
    func neutralMultiplierIsIgnored() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)
        gameState.grant(.nextOfflineMultiplier(1), source: "a")
        gameState.grant(.nextOfflineMultiplier(0), source: "a")
        gameState.grant(.nextDailyMultiplier(1), source: "a")
        gameState.grant(.nextDailyMultiplier(0), source: "a")
        #expect(gameState.player == before)
    }

    @Test("el Diario ×3 triplica la plata del próximo diario y se consume")
    func dailyTriples() async throws {
        let plain = await makeGameState()
        let boosted = await makeGameState()
        boosted.grant(.nextDailyMultiplier(3), source: "shop.daily_x3")
        let yesterday = DailyRewardManager.dayString(for: Date().addingTimeInterval(-86_400))
        for gameState in [plain, boosted] {
            gameState.player?.meta.daily.lastClaimDay = yesterday
            gameState.player?.meta.daily.cycleDay = 1
            gameState.claimDailyIfAvailable()
        }
        let base = try #require(plain.dailyClaim?.coinsGranted)
        let tripled = try #require(boosted.dailyClaim?.coinsGranted)
        #expect(base > 0)
        #expect(abs(tripled - base * 3) < 1e-6 * tripled)
        #expect(boosted.player?.meta.engagement.shop.pendingDailyMultiplier == nil)
    }

    @Test("un diario sin plata (especial o cofre) no gasta el ×3")
    func dailyWithoutCoinsKeepsIt() async throws {
        let gameState = await makeGameState()
        gameState.grant(.nextDailyMultiplier(3), source: "shop.daily_x3")
        let claim = try #require(gameState.content?.dailyRewards.days.first)
        let bare = DailyRewardManager.Claim(day: claim, coinsGranted: 0, specialGranted: "x", chestGranted: false)
        #expect(gameState.applyPendingDailyMultiplier(to: bare) == bare)
        #expect(gameState.player?.meta.engagement.shop.pendingDailyMultiplier == 3)
    }

    @Test("el auto-tap cobra en cada tick, también sin los motores de engagement")
    func autoTapPaysOnTheTick() async throws {
        let gameState = await producing()
        #expect(!gameState.engagementAutorun, "bajo XCTest los motores arrancan apagados")
        let now = Date().timeIntervalSince1970
        gameState.grant(.autoTap(perSecond: 5, seconds: 600), source: "shop.auto_tap", now: now)
        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.effect == .autoTapPerSecond })
        #expect(modifier.magnitude == 5)
        #expect(modifier.sourceKey == "shop.auto_tap")
        let coins = try #require(gameState.player?.run.coins)
        gameState.advanceEngagement(delta: 1)
        #expect((gameState.player?.run.coins ?? 0) > coins, "un efecto comprado no espera al autorun")
    }

    @Test("comprar dos ×3 no los apila: queda el más alto")
    func pendingDoesNotStack() async throws {
        let gameState = await makeGameState()
        gameState.grant(.nextDailyMultiplier(3), source: "a")
        gameState.grant(.nextDailyMultiplier(2), source: "b")
        #expect(gameState.player?.meta.engagement.shop.pendingDailyMultiplier == 3)
    }
}
