import EconomyKit
import Foundation

/// Las notificaciones de la ausencia (PLAN-v2 E11), enganchadas al ciclo de vida
/// de `+Lifecycle`: el snapshot que el planificador necesita sale de acá, y el
/// manager hace el resto.
extension GameState {
    func attachNotifications(_ manager: NotificationsManager) {
        notifications = manager
    }

    /// Lo que el planificador necesita saber de la partida al irse, ya resuelto.
    /// El pasivo es el de base, sin modificadores temporales: un Paro General a
    /// la hora de irse no puede borrar el aviso de la caja fuerte.
    func notificationSnapshot(now: TimeInterval) -> NotificationSnapshot? {
        guard let content, let player else { return nil }
        let passive = IncomeTicker.basePassivePerSecond(
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy
        )
        let today = DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now))
        return NotificationSnapshot(
            now: now,
            producesOffline: passive > 0,
            offlineCapHours: content.economy.offlineCapHours,
            dailyClaimedToday: player.meta.daily.lastClaimDay == today,
            wheelSpinsReadyAt: wheelSpinsReadyAt(now: now)
        )
    }

    /// Al pasar a `.background`: programa la ausencia dentro de su propio tiempo
    /// de background (el guardado del sellado tiene el suyo).
    func scheduleNotificationsForAbsence(now: TimeInterval) {
        guard phase == .ready, let notifications, let content,
              let snapshot = notificationSnapshot(now: now)
        else { return }
        let runner = backgroundTasks
        let token = runner?.begin("fisu.notifications")
        notificationsTask = Task {
            await notifications.scheduleAbsence(snapshot, config: content.notifications)
            if let runner, let token { runner.end(token) }
        }
    }

    /// Al volver a `.active`: lo pendiente y lo entregado ya no dicen nada. El
    /// borrado es síncrono; la relectura del permiso, no.
    func clearNotificationsOnReturn() {
        guard let notifications else { return }
        notifications.cancelAbsence()
        notificationsTask = Task { await notifications.refreshAuthorization() }
    }

    /// Al cerrar el núcleo del tutorial: el primer paso del permiso, sin diálogo.
    func requestProvisionalNotifications() {
        guard let notifications else { return }
        notificationsTask = Task { await notifications.requestProvisional() }
    }

    /// El arranque (`startServices`): un arranque en frío también es volver, y un
    /// veterano —que nunca va a ver el cierre del núcleo— recibe acá su provisional.
    func notificationsLaunched(
        tutorialDone: Bool = UserDefaults.standard.bool(forKey: "fisuTutorialDone")
    ) async {
        guard let notifications else { return }
        await notifications.appBecameActive()
        if tutorialDone, !tutorialPhaseActive {
            await notifications.requestProvisional()
        }
    }
}
