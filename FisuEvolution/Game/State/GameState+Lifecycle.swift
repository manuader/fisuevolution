import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    func handleScenePhase(
        from old: ScenePhase,
        to new: ScenePhase,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        switch (old, new) {
        case (_, .background), (.active, .inactive):
            let wasActive = isSceneActive
            isSceneActive = false
            if wasActive { ranking?.resignedActive() }
            if new == .background { settleAllPendingBoardChanges() } else { settlePrepaidBoardChanges() }
            seal(now: now, stamping: wasActive)
            adsDidEnterBackground()
            if new == .background { scheduleNotificationsForAbsence(now: now) }
        case (_, .active):
            isSceneActive = true
            rankingBecameActive()
            clearNotificationsOnReturn()
            guard phase == .ready else { return }
            // El tiempo en background NO es tiempo de juego: reiniciar la gracia
            // evita que volver después de horas te reciba con un interstitial.
            adsDidReturnFromBackground()
            applyOfflineProgressIfNeeded(now: now)
            postponeOverdueEvent(now: now)
            claimDailyIfAvailable()
            refreshProjections()
        default:
            // `.background → .inactive` NO sella: re-sellar acá hacía que `.active`
            // midiera ~0 s de ausencia y el pasivo "se congelaba".
            break
        }
    }

    /// Fija la hora de la última vez que se vio la partida y la guarda, dentro de
    /// un `beginBackgroundTask` para que iOS no suspenda la app a mitad de la
    /// escritura.
    ///
    /// Sólo el primer sello de una salida corre la hora (`stamping`): `inactive →
    /// background` guarda igual, pero la hora queda donde la dejó `active →
    /// inactive`, porque el tick está mudo desde entonces y el tramo en medio no
    /// lo pagaría nadie.
    func seal(now: TimeInterval, stamping: Bool = true) {
        guard phase == .ready else { return }
        guard var player else { return }
        if stamping {
            player.meta.lastSeenTimestamp = now
            self.player = player
            lastHeartbeatAt = now
        }
        saveTask?.cancel()
        let runner = backgroundTasks
        let token = runner?.begin("fisu.save")
        sealTask = Task {
            await persistNow()
            if let runner, let token { runner.end(token) }
        }
    }

    /// Con la escena activa, sella y guarda cada `heartbeatSeconds`. Sin el
    /// latido, un kill en foreground pagaría offline desde el último regreso a
    /// `.active` y repetiría toda la sesión; con él repite a lo sumo ese tramo
    /// (la plata ganada en vivo y guardada con la hora del último latido, a la
    /// eficiencia offline).
    func beatIfDue(now: TimeInterval) {
        guard phase == .ready, isSceneActive, now - lastHeartbeatAt >= Self.heartbeatSeconds,
              var player
        else { return }
        lastHeartbeatAt = now
        player.meta.lastSeenTimestamp = now
        self.player = player
        Task { await persistNow(includingCloud: false) }
    }

    /// La llama también `+Debug`, para simular una vuelta después de N horas.
    func applyOfflineProgressIfNeeded(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, var player else { return }
        let credit = OfflineCalculator.apply(
            state: &player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            now: now
        )
        self.player = player
        guard credit.amount > 0 else { return }
        Log.economy.info("offline earnings credited: \(credit.amount) after \(credit.elapsed) s")
        guard credit.showsPopup else { return }
        // Vuelta nueva, oferta nueva: el video puede duplicar ESTE premio.
        offlineRewardDoubled = false
        offlineReward = OfflineReward(amount: applyPendingOfflineMultiplier(to: credit.amount))
        // Plata que cae de golpe: suena como tal, igual que un tap dorado.
        audio?.play(.coin)
    }
}
