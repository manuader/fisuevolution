import EconomyKit
import Foundation
import SwiftUI
import Testing
@testable import FisuEvolution

@MainActor
private final class RecordingBackgroundTasks: BackgroundTaskRunning {
    private(set) var begun: [BackgroundTaskToken] = []
    private(set) var ended: [BackgroundTaskToken] = []

    func begin(_ name: String) -> BackgroundTaskToken {
        let token = BackgroundTaskToken()
        begun.append(token)
        return token
    }

    func end(_ token: BackgroundTaskToken) {
        ended.append(token)
    }
}

@Suite("Ciclo de vida: la secuencia completa de fases")
@MainActor
struct LifecycleTests {
    private func producingGame() async throws -> GameState {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        return gameState
    }

    @Test("volver del background pasando por inactive no re-sella: la hora afuera se paga")
    func returningThroughInactiveKeepsTheSeal() async throws {
        let gameState = try await producingGame()
        let t0 = Date().timeIntervalSince1970
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        gameState.handleScenePhase(from: .inactive, to: .background, now: t0 + 1)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + 3600)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 3601)
        #expect((gameState.offlineReward?.amount ?? 0) > 0)
    }

    @Test("bajar el centro de notificaciones sella y acredita en silencio")
    func notificationCenterPull() async throws {
        let gameState = try await producingGame()
        let t0 = Date().timeIntervalSince1970
        let before = try #require(gameState.player?.run.coins)
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 10)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.offlineReward == nil)
    }

    @Test("con la escena inactiva el tick no cobra: lo paga el offline")
    func tickPaysNothingWhileInactive() async throws {
        let gameState = try await producingGame()
        gameState.handleScenePhase(from: .active, to: .inactive)
        let before = try #require(gameState.player?.run.coins)
        gameState.tick(delta: 1)
        #expect(gameState.player?.run.coins == before)
    }

    @Test("sellar pide tiempo de background y lo devuelve al terminar de guardar")
    func sealRunsInsideABackgroundTask() async throws {
        let gameState = try await producingGame()
        let tasks = RecordingBackgroundTasks()
        gameState.attachBackgroundTasks(tasks)
        gameState.handleScenePhase(from: .inactive, to: .background)
        await gameState.sealTask?.value
        #expect(tasks.begun.count == 1)
        #expect(tasks.ended == tasks.begun)
    }

    @Test("un evento vencido no dispara al volver: se corre la gracia del dato")
    func overdueEventIsPostponed() async throws {
        let gameState = await makeGameState()
        let t0 = Date().timeIntervalSince1970
        gameState.nextEventAt = t0 + 10
        gameState.handleScenePhase(from: .active, to: .background, now: t0)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + 3600)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 3601)
        let grace = try #require(gameState.content?.events.resumeGraceSeconds)
        #expect(gameState.nextEventAt == t0 + 3601 + grace)
    }

    @Test("el watchdog recibe el delta con tope: el salto del background no vence nada")
    func watchdogGetsAClampedDelta() async {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(gameState.showing == .towerNotice)
        gameState.tick(delta: 3600)
        #expect(gameState.showing == .towerNotice)
    }

    @Test("la escena sigue corriendo mientras está inactiva: el tramo se paga una sola vez")
    func inactiveStretchIsPaidOnce() async throws {
        let gameState = try await producingGame()
        let content = try #require(gameState.content)
        let start = try #require(gameState.player)
        let t0 = Date().timeIntervalSince1970
        var sealed = start
        sealed.meta.lastSeenTimestamp = t0
        let expected = OfflineCalculator.earnings(
            state: sealed, tiers: content.tiers, floorTable: content.floorTable,
            config: content.economy, now: t0 + 10
        )
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        for _ in 0..<10 { gameState.tick(delta: 1) }
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 10)
        let gained = try #require(gameState.player?.run.coins) - start.run.coins
        #expect(expected > 0)
        #expect(abs(gained - expected) < 1e-9)
    }

    @Test("la hora afuera se paga entera, medida desde que la escena dejó de estar activa")
    func hourAwayIsPaidInFull() async throws {
        let gameState = try await producingGame()
        let content = try #require(gameState.content)
        var start = try #require(gameState.player)
        let t0 = Date().timeIntervalSince1970
        start.meta.lastSeenTimestamp = t0
        let expected = OfflineCalculator.earnings(
            state: start, tiers: content.tiers, floorTable: content.floorTable,
            config: content.economy, now: t0 + 3601
        )
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        gameState.handleScenePhase(from: .inactive, to: .background, now: t0 + 25)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + 3600)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 3601)
        let paid = try #require(gameState.offlineReward?.amount)
        #expect(expected > 0)
        #expect(abs(paid - expected) < 1e-9)
    }

    @Test("salir de inactive a background guarda pero no corre el sello")
    func secondLeaveKeepsTheFirstSeal() async throws {
        let gameState = try await producingGame()
        let tasks = RecordingBackgroundTasks()
        gameState.attachBackgroundTasks(tasks)
        let t0 = Date().timeIntervalSince1970
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        await gameState.sealTask?.value
        gameState.handleScenePhase(from: .inactive, to: .background, now: t0 + 25)
        await gameState.sealTask?.value
        #expect(gameState.player?.meta.lastSeenTimestamp == t0)
        #expect(tasks.begun.count == 2)
        #expect(tasks.ended == tasks.begun)
    }

    @Test("con la escena inactiva el flush no dispara el evento, no arma el anuncio ni poda buffs")
    func flushWhileInactiveWaitsForActive() async throws {
        let gameState = try await producingGame()
        let content = try #require(gameState.content)
        let clock = TestClock()
        let ads = AdsCoordinator(now: clock.read, provider: ScriptedAdsProvider())
        gameState.attachAds(ads)
        clock.advance(by: 10_000)
        let t0 = Date().timeIntervalSince1970
        let overdue = t0 - 1
        gameState.nextEventAt = overdue
        let buff = ActiveModifier(
            effect: .incomeMultiplier, magnitude: 3, expiresAt: t0 - 1800, sourceKey: "test.buff"
        )
        gameState.player?.run.activeModifiers.append(buff)
        var sealed = try #require(gameState.player)
        sealed.meta.lastSeenTimestamp = t0 - 3600
        let expected = OfflineCalculator.earnings(
            state: sealed, tiers: content.tiers, floorTable: content.floorTable,
            config: content.economy, now: t0
        )

        gameState.handleScenePhase(from: .active, to: .background, now: t0 - 3600)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0)
        for _ in 0..<8 { gameState.flushHUD() }
        #expect(gameState.nextEventAt == overdue)
        #expect(!ads.isInterstitialArmed)
        #expect(gameState.player?.run.activeModifiers == [buff])

        gameState.handleScenePhase(from: .inactive, to: .active, now: t0)
        let grace = content.events.resumeGraceSeconds
        #expect(gameState.nextEventAt == t0 + grace)
        let paid = try #require(gameState.offlineReward?.amount)
        #expect(abs(paid - expected) < 1e-9)
    }

    @Test("la gracia de un evento vencido es de un minuto")
    func resumeGraceIsOneMinute() async {
        let gameState = await makeGameState()
        #expect(gameState.content?.events.resumeGraceSeconds == 60)
    }

    @Test("con la escena inactiva el latido no sella")
    func heartbeatSleepsWhileInactive() async {
        let gameState = await makeGameState()
        let t0 = Date().timeIntervalSince1970
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        gameState.beatIfDue(now: t0 + 2 * GameState.heartbeatSeconds)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0)
    }

    @Test("el latido sella cada 15 s con la escena activa, y no antes")
    func heartbeat() async {
        let gameState = await makeGameState()
        let t0 = Date().timeIntervalSince1970
        gameState.beatIfDue(now: t0)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0)
        gameState.beatIfDue(now: t0 + GameState.heartbeatSeconds - 1)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0)
        gameState.beatIfDue(now: t0 + GameState.heartbeatSeconds)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0 + GameState.heartbeatSeconds)
    }
}
