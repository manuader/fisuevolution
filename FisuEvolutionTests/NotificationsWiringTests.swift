import EconomyKit
import Foundation
import Testing
import UserNotifications
@testable import FisuEvolution

/// El manager enganchado al ciclo de vida de E1 (PLAN-v2 E11): se programa todo
/// al irse y se borra todo al volver; el provisional, al cerrar el núcleo.
@Suite("Notificaciones: el ciclo de vida")
@MainActor
struct NotificationsWiringTests {
    private struct Rig {
        let gameState: GameState
        let spy: NotificationsManagerTests.SpyNotificationCenter
        let scratch: SettingsPersistenceTests.ScratchDefaults
    }

    /// `launched` recorre el camino real: el arranque lee el permiso, como en `startServices`.
    private func makeRig(status: UNAuthorizationStatus = .provisional, launched: Bool = true) async -> Rig {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        let spy = NotificationsManagerTests.SpyNotificationCenter()
        spy.status = status
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)
        let gameState = await makeGameState()
        gameState.attachNotifications(manager)
        if launched { await gameState.notificationsLaunched(tutorialDone: false) }
        return Rig(gameState: gameState, spy: spy, scratch: scratch)
    }

    private func producing(_ gameState: GameState) throws {
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        gameState.player?.run.units[base] = 1
    }

    @Test("irse a background programa la ausencia completa")
    func backgroundSchedulesTheAbsence() async throws {
        let rig = await makeRig()
        defer { rig.scratch.clear() }
        try producing(rig.gameState)
        let now = Date().timeIntervalSince1970

        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: now)
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: now + 1)
        await rig.gameState.notificationsTask?.value

        #expect(Set(rig.spy.pending.keys) == ["fisu.notif.vault_full", "fisu.notif.daily_ready", "fisu.notif.comeback"])
    }

    @Test("sin pasivo no hay caja fuerte que avisar")
    func noPassiveNoVault() async {
        let rig = await makeRig()
        defer { rig.scratch.clear() }

        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: Date().timeIntervalSince1970)
        await rig.gameState.notificationsTask?.value

        #expect(Set(rig.spy.pending.keys) == ["fisu.notif.daily_ready", "fisu.notif.comeback"])
    }

    @Test("bajar el centro de notificaciones no programa nada")
    func notificationCenterPullSchedulesNothing() async {
        let rig = await makeRig()
        defer { rig.scratch.clear() }
        let now = Date().timeIntervalSince1970

        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: now)
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: now + 5)
        await rig.gameState.notificationsTask?.value

        #expect(rig.spy.pending.isEmpty)
    }

    @Test("volver borra lo pendiente y lo entregado")
    func returningClearsEverything() async throws {
        let rig = await makeRig()
        defer { rig.scratch.clear() }
        try producing(rig.gameState)
        let now = Date().timeIntervalSince1970
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: now)
        await rig.gameState.notificationsTask?.value
        #expect(!rig.spy.pending.isEmpty)
        let deliveredBefore = rig.spy.removeDeliveredCount

        rig.gameState.handleScenePhase(from: .background, to: .inactive, now: now + 3600)
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: now + 3601)
        await rig.gameState.notificationsTask?.value

        #expect(rig.spy.pending.isEmpty)
        #expect(rig.spy.removeDeliveredCount == deliveredBefore + 1)
    }

    @Test("terminar el núcleo del tutorial pide el provisional, sin diálogo")
    func coreFinishRequestsProvisional() async {
        let rig = await makeRig(status: .notDetermined)
        defer { rig.scratch.clear() }

        rig.gameState.beginTutorialPhase()
        rig.gameState.tutorialPhaseFinished()
        await rig.gameState.notificationsTask?.value

        #expect(rig.spy.requestedOptions == [.alert, .sound, .badge, .provisional])
    }

    @Test("al arrancar limpia la ausencia y, si el tutorial ya estaba hecho, pide el provisional")
    func launchClearsAndAsksVeterans() async {
        let veteran = await makeRig(status: .notDetermined, launched: false)
        defer { veteran.scratch.clear() }
        await veteran.gameState.notificationsLaunched(tutorialDone: true)
        #expect(veteran.spy.removeDeliveredCount == 1)
        #expect(veteran.spy.requestedOptions == [.alert, .sound, .badge, .provisional])

        let newcomer = await makeRig(status: .notDetermined, launched: false)
        defer { newcomer.scratch.clear() }
        await newcomer.gameState.notificationsLaunched(tutorialDone: false)
        #expect(newcomer.spy.requestedOptions == nil)
    }

    @Test("arrancar, irse y programar: el camino real lee el permiso solo")
    func launchedThenBackgroundSchedules() async {
        let rig = await makeRig(launched: false)
        defer { rig.scratch.clear() }

        await rig.gameState.notificationsLaunched(tutorialDone: false)
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: Date().timeIntervalSince1970)
        await rig.gameState.notificationsTask?.value

        #expect(!rig.spy.pending.isEmpty)
    }

    @Test("sin manager, el ciclo de vida sigue como antes")
    func withoutManagerNothingChanges() async {
        let gameState = await makeGameState()
        gameState.handleScenePhase(from: .inactive, to: .background, now: Date().timeIntervalSince1970)
        #expect(gameState.notificationsTask == nil)
    }
}
