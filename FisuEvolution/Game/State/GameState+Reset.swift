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

    /// Cómo terminó un `resetGame`. Sólo `.done` cambió algo; en los demás la partida de antes
    /// sigue intacta, en memoria y en disco.
    enum ResetOutcome: Equatable {
        case done
        /// El plan ya no corresponde a la partida de hoy (se ejecutó, o hubo una compra o un
        /// reembolso después de mostrarlo): hay que pedir uno nuevo y mostrarlo otra vez.
        case stale
        case noBackup
        case writeFailed
    }

    /// Ejecuta el plan.
    ///
    /// El orden importa: 1) el plan tiene que ser el de la partida de hoy (si cambió lo
    /// comprado, ejecutarlo borraría la compra nueva), 2) la copia de la partida de hoy,
    /// 3) se reclama la época en memoria y se apagan las compras (`isResetting`; desde acá un
    /// segundo toque ya no pasa y una compra que llegue queda sin finalizar para después),
    /// 4) se escribe la nueva y se verifica, 5) recién entonces la sesión vieja se va. Si el
    /// paso 4 falla se vuelve a escribir la de antes y la memoria la recupera.
    ///
    /// `repushEntitlements` es el `StoreManager.repushEntitlements()` (y el reintento de las
    /// compras sin finalizar) que le pasa quien lo tenga a mano (Ajustes): StoreKit manda y el
    /// save sólo lo cachea.
    @discardableResult
    func resetGame(_ plan: ResetPlan, repushEntitlements: () -> Void) async -> ResetOutcome {
        guard let repository, let old = player, !isRecoveryPending else { return .noBackup }
        guard plan.result.meta.resetEpoch > old.meta.resetEpoch,
              ResetPlan.make(current: old, fresh: plan.result).result == plan.result else { return .stale }
        guard repository.keepBeforeReset(old) else {
            Log.persistence.error("reset cancelado: no se pudo guardar la copia de antes")
            return .noBackup
        }
        saveTask?.cancel()
        isResetting = true
        player = plan.result
        guard await repository.saveVerifying(plan.result) else {
            player = old
            await repository.save(old)
            isResetting = false
            Log.persistence.error("reset cancelado: no se pudo escribir la partida nueva")
            return .writeFailed
        }
        finishReset()
        isResetting = false
        repushEntitlements()
        await persistNow()
        ranking?.resignedActive()
        ranking?.newGameStarted()
        Log.lifecycle.info("partida reseteada: época \(plan.result.meta.resetEpoch)")
        return .done
    }

    /// El reset en memoria, de un tirón (`debugResetSave` lo usa sin disco de por medio).
    func applyReset(_ plan: ResetPlan) {
        player = plan.result
        finishReset()
    }

    /// Lo que sigue a tener la partida nueva en `player`: la sesión vieja fuera y el tutorial de
    /// vuelta. Es lo que hacía `debugResetSave` y lo repite el reset real: sin soltar la corrida
    /// del tutorial, rehacer la cola y borrar las banderas, la cola puede quedar restringida
    /// (revisión de E9a T5).
    func finishReset() {
        clearSessionRuntime()
        TutorialFlags.wipeGameFlags(in: flagDefaults)
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
        chestReward = nil
        wheelSheet = nil
        mattressPopup = nil
        packagePopup = nil
        characterSheet = nil
        adBreakOffer = nil
        quickHireOffer = nil
        offlineRewardDoubled = false
        extraChestClaimed = false
        presentingOfferId = nil
        wheelOpensAfterVisit = false
        boardSpotlight = nil
        tutorialBoardTarget = nil
    }
}
