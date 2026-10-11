import EconomyKit
import Foundation

/// "Resetear partida" (PLAN-v2 E9). La pantalla pide el plan, lo muestra, y si el jugador
/// confirma ejecuta ESE plan: lo que se mostró es lo que se escribe.
extension GameState {
    /// El plan contra la partida de hoy. La partida nueva trae el freno del día 1 del FTUE
    /// (el daily de HOY no pisa el arranque), igual que la instalación fresca del bootstrap.
    func resetPlan() -> ResetPlan? {
        guard let content, let player else { return nil }
        var fresh = newGame(content: content)
        fresh.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        return ResetPlan.make(current: player, fresh: fresh)
    }

    /// Ejecuta el plan. `false` (y la partida de antes intacta, en memoria y en disco) si no
    /// hay copia donde guardar la de hoy, si el disco no pudo escribir la nueva, o si ese
    /// plan ya se ejecutó (el doble toque: la época del plan ya no es mayor que la actual).
    ///
    /// El orden importa: 1) la copia de la partida de hoy, 2) se reclama la época en memoria
    /// (desde acá un segundo toque ya no pasa, aunque el primero siga esperando al disco),
    /// 3) se escribe la nueva y se verifica, 4) recién entonces la sesión vieja se va. Si el
    /// paso 3 falla se vuelve a escribir la de antes y la memoria la recupera.
    ///
    /// `repushEntitlements` es el `StoreManager.repushEntitlements()` que le pasa quien lo
    /// tenga a mano (Ajustes): StoreKit manda y el save sólo lo cachea.
    @discardableResult
    func resetGame(_ plan: ResetPlan, repushEntitlements: () -> Void = {}) async -> Bool {
        guard let repository, let old = player, !isRecoveryPending,
              plan.result.meta.resetEpoch > old.meta.resetEpoch else { return false }
        guard repository.keepBeforeReset(old) else {
            Log.persistence.error("reset cancelado: no se pudo guardar la copia de antes")
            return false
        }
        saveTask?.cancel()
        player = plan.result
        guard await repository.saveVerifying(plan.result) else {
            player = old
            await repository.save(old)
            Log.persistence.error("reset cancelado: no se pudo escribir la partida nueva")
            return false
        }
        applyReset(plan)
        repushEntitlements()
        await persistNow()
        Log.lifecycle.info("partida reseteada: época \(plan.result.meta.resetEpoch)")
        return true
    }

    /// La mitad en memoria: la partida del plan, la sesión vieja fuera y el tutorial de
    /// vuelta. Es lo que hacía `debugResetSave` y lo repite el reset real: sin soltar la
    /// corrida del tutorial, rehacer la cola y borrar las banderas, la cola puede quedar
    /// restringida (revisión de E9a T5).
    func applyReset(_ plan: ResetPlan) {
        player = plan.result
        clearSessionRuntime()
        TutorialFlags.wipeGameFlags()
        ftueTapped = false
        ftueSpawned = false
        ftueMerged = false
        beginTutorialPhase()
        reconcileTower()
        bumpBoard()
    }

    /// Todo lo de la sesión vieja: payloads de celebraciones, la cola, el escenario, los
    /// cambios del tablero en vuelo… Es la lista que `debugResetSave` fue juntando épica por
    /// épica; vive acá para que el reset real no se olvide de ninguno. Una celebración nueva
    /// con payload propio se suma acá.
    func clearSessionRuntime() {
        offlineReward = nil
        dailyClaim = nil
        careerPrompt = nil
        skinAward = nil
        specialDrop = nil
        cinematic = nil
        towerNotice = nil
        achievementToast = nil
        pendingAchievementToasts.removeAll()
        shareCardMoment = nil
        shareOffer = nil
        pendingShareMoment = nil
        tutorialRun = nil
        tutorialEngine.clock = TutorialStepClock(kind: .explain, lock: tutorialEngine.lockSeconds)
        tutorialEngine.pacing = TutorialPacing()
        tutorialEngine.openPage = nil
        stageVisit = nil
        visitorPopup = nil
        eventPopup = nil
        stageChallenge = nil
        stageRuntime = StageRuntime()
        boardCelebrationShowsSomethingNew = false
        pendingBoardChanges.removeAll()
        inFlightBoardChange = nil
        celebrations = CelebrationQueue()
    }
}
