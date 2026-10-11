import EconomyKit
import Foundation

/// El reloj, el ritmo y la página abierta del tutorial: cambian por frame y no se observan.
struct TutorialEngine {
    var clock = TutorialStepClock(kind: .explain)
    var pacing = TutorialPacing()
    /// La página del menú a la vista (`menuDidOpen`/`menuPageChanged`); `nil` con el tablero.
    var openPage: GameScreen?
    /// 5 s; `--uitest-tutorial-lock=<s>` lo baja para los fixtures de UI.
    var lockSeconds = TutorialStepClock.explainLock
    /// `--uitest-lesson=<id>`: gana sobre el orden mientras no esté dada.
    var forcedLesson: String?
}

/// El director del tutorial v2 (PLAN-v2 E9): arranca guiones, los avanza por señales, cuenta
/// el candado con el tick y respeta el ritmo. Es la única puerta de entrada y de salida.
extension GameState {
    /// El alias de la v1: lo leen las vistas y los tests de E3b–E7b-b.
    var tutorialTip: TutorialTip? {
        guard let id = tutorialRun?.lessonID, let lesson = TutorialLesson(rawValue: id) else { return nil }
        return TutorialTip(lesson: lesson)
    }

    // MARK: Entradas

    /// Corre al final de `refreshProjections` (8 Hz) contra señales ya publicadas.
    func refreshTutorial() {
        guard phase == .ready else { return }
        if !uiCoversBoard { tutorialEngine.openPage = nil }
        if tutorialRun != nil {
            progressTutorialRun()
            return
        }
        startNextLessonIfDue()
    }

    /// Lo llama `advanceCelebrations(delta:)`, que corre en cada tick con el delta clampeado.
    func advanceTutorial(delta: TimeInterval) {
        tutorialEngine.pacing.tick(delta)
        guard tutorialStepIsVisible, var run = tutorialRun else { return }
        tutorialEngine.clock.tick(delta)
        if tutorialEngine.clock.canConfirm, !run.unlocked {
            run.unlocked = true
            tutorialRun = run
        }
        if tutorialEngine.clock.watchdogExpired, let step = run.step {
            Log.lifecycle.error("tutorial: paso trabado liberado por watchdog: \(step.id, privacy: .public)")
            advanceTutorialStep()
        }
    }

    /// El botón "Entendido". Con el candado puesto no hace nada.
    func confirmTutorialStep() {
        guard let run = tutorialRun, run.step?.clockKind == .explain, run.unlocked else { return }
        advanceTutorialStep()
    }

    /// Lo que avisan las vistas y no queda en el save.
    func tutorialSignal(_ event: TutorialEvent) {
        guard var run = tutorialRun else { return }
        run.events.insert(event)
        tutorialRun = run
        progressTutorialRun()
    }

    /// El jugador hizo la acción firma de la lección (abrió el mapa, reencarnó, usó el atajo…).
    func tutorialTipCompleted(_ lesson: TutorialLesson) {
        tutorialSignal(.lessonAction(lesson.rawValue))
    }

    /// Abrió (o deslizó hasta) una pestaña. `RootView.open` no tiene por qué saber qué
    /// lección está corriendo.
    func tutorialTipHandled(opening screen: GameScreen) {
        tutorialEngine.openPage = screen
        tutorialSignal(.screenOpened(screen))
    }

    /// El botón del globo de la v1 (`TutorialTipView`, hasta T6): termina la lección.
    func dismissTutorialTip() {
        guard showing == .tutorialTip else { return }
        celebrationFinished(.tutorialTip)
    }

    // MARK: Lo que la UI lee

    /// El paso tiene a la vista la superficie donde se dibuja: sólo ahí corre su reloj.
    var tutorialStepIsVisible: Bool {
        guard let run = tutorialRun, let step = run.step else { return false }
        if run.script == .core {
            guard showing == nil else { return false }
        } else if !isInlineRun(run) {
            guard showing == .tutorialTip else { return false }
        }
        switch step.surface {
        case .board: return !uiCoversBoard
        case .page(let screen): return tutorialEngine.openPage == screen
        case .characterSheet: return characterSheet != nil
        case .embedded: return true
        }
    }

    var tutorialLockProgress: Double { tutorialEngine.clock.lockProgress }

    func tutorialProbe() -> TutorialProbe {
        guard let player else { return TutorialProbe() }
        return TutorialProbe(
            taps: player.meta.stats.totalTapsEver,
            hires: player.meta.stats.totalHiresEver,
            merges: player.meta.stats.totalMergesEver,
            upgradeLevels: player.run.charUpgradeLevels.values.reduce(0, +)
                + player.meta.oroUpgradeLevels.values.reduce(0, +),
            passivesUnlocked: player.run.passiveUnlocked.values.filter { $0 }.count,
            visibleFloor: visibleFloorOrdinal,
            pinnedTypeId: player.meta.quickHirePinnedTypeId,
            canAffordSpawn: canAffordSpawn,
            ftueTapped: ftueTapped,
            ftueSpawned: ftueSpawned,
            ftueMerged: ftueMerged
        )
    }

    // MARK: El guion

    /// Arma la corrida, reinicia el reloj y —salvo el núcleo y las tarjetas embebidas— pide
    /// el turno de la cola. Lo usan el director, el núcleo (T5), E9b y los tests.
    func startTutorialRun(_ script: TutorialRun.Script, steps: [TutorialStep]) {
        let run = TutorialRun(script: script, steps: steps, probe: tutorialProbe())
        tutorialRun = run
        resetTutorialClock()
        if runTakesAQueueTurn(run) {
            celebrations.enqueue(.tutorialTip)
            publishCelebration()
        }
    }

    /// Una lección nace sólo con la cola libre: así toma el turno en el acto y la foto del
    /// inicio del paso es la buena. Con una hoja abierta tampoco: el coach señala controles
    /// que están DEBAJO de la hoja; al cerrarse, el próximo refresh la agarra.
    private func startNextLessonIfDue() {
        guard tutorialLessonsAutorun, !tutorialPhaseActive, showing == nil,
              tutorialEngine.pacing.mayStartLesson,
              !uiCoversBoard, characterSheet == nil, shareCardMoment == nil,
              let lesson = nextLesson()
        else { return }
        startTutorialRun(.lesson(lesson.rawValue), steps: lesson.steps)
    }

    private func nextLesson() -> TutorialLesson? {
        if let forced = tutorialEngine.forcedLesson.flatMap(TutorialLesson.init(rawValue:)),
           !isLessonDone(forced) {
            return forced
        }
        return TutorialLesson.allCases.first {
            !isLessonDone($0) && isEligible($0) && (!$0.needsCalmBoard || isCalmMoment)
        }
    }

    private func progressTutorialRun() {
        guard var run = tutorialRun else { return }
        let probe = tutorialProbe()
        // La regla de oro hasta el último frame: una lección que todavía no tomó el turno y
        // cuya condición murió se retira SIN marcarse, y vuelve cuando su momento vuelva.
        if let id = run.lessonID, let lesson = TutorialLesson(rawValue: id),
           showing != .tutorialTip, run.index == 0, !isEligible(lesson) {
            tutorialRun = nil
            celebrations.finish(.tutorialTip)
            return
        }
        if !uiCoversBoard, run.rewindToBoard(probe: probe) {
            tutorialRun = run
            resetTutorialClock()
            return
        }
        if run.isStepSatisfied(probe: probe) {
            advanceTutorialStep()
        }
    }

    func advanceTutorialStep() {
        guard var run = tutorialRun else { return }
        run.advance(probe: tutorialProbe())
        tutorialRun = run
        if run.isFinished {
            finishTutorialRun()
        } else {
            resetTutorialClock()
        }
    }

    /// Fin de corrida. Las lecciones salen por la cola (`releasePayload` las marca dadas).
    func finishTutorialRun() {
        guard let run = tutorialRun else { return }
        switch run.script {
        case .core:
            // T5 lo muda a `finishTutorialCore()`.
            tutorialRun = nil
            tutorialPhaseFinished()
        case .lesson where isInlineRun(run):
            if let id = run.lessonID { TutorialFlags.markLessonDone(id) }
            tutorialRun = nil
            tutorialEngine.pacing.lessonEnded()
        case .lesson, .tour, .replay:
            celebrationFinished(.tutorialTip)
        }
    }

    /// Lo que suelta el turno de `.tutorialTip` (`releasePayload`): el último paso, el
    /// watchdog, el botón del globo y —hasta T6— el timeout y el toque que saltea. La lección
    /// queda dada y el ritmo empieza a contar. El Tour y el repaso no marcan lecciones acá:
    /// lo hacen al terminar (E9b).
    func releaseTutorialTurn() {
        if let id = tutorialRun?.lessonID { TutorialFlags.markLessonDone(id) }
        tutorialRun = nil
        tutorialEngine.pacing.lessonEnded()
    }

    /// La corrida pide el turno de la cola: todas menos el núcleo (que restringe la cola) y
    /// las tarjetas de las primeras veces (T8), que las aloja su popup.
    func runTakesAQueueTurn(_ run: TutorialRun) -> Bool {
        run.script != .core && !isInlineRun(run)
    }

    func isInlineRun(_ run: TutorialRun) -> Bool {
        run.steps.first?.surface == .embedded
    }

    private func resetTutorialClock() {
        let kind = tutorialRun?.step?.clockKind ?? .explain
        tutorialEngine.clock = TutorialStepClock(kind: kind, lock: tutorialEngine.lockSeconds)
    }
}
