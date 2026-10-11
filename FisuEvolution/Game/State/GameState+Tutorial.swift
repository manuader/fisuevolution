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
        // Nada pisa al núcleo vivo: su fase restringe la cola y sólo su cierre la levanta, así
        // que soltarlo a medias la dejaría congelada para siempre.
        if tutorialRun?.script == .core, tutorialPhaseActive, script != .core {
            Log.lifecycle.error("tutorial: corrida rechazada con el núcleo vivo: \(String(describing: script), privacy: .public)")
            return
        }
        // Una corrida por vez: la anterior se suelta sin marcarse (y sin su turno en la cola).
        if let previous = tutorialRun {
            Log.lifecycle.error("tutorial: corrida pisada sin terminar: \(String(describing: previous.script), privacy: .public)")
            if runTakesAQueueTurn(previous) { celebrations.finish(.tutorialTip) }
        }
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
              !uiCoversBoard, characterSheet == nil, shareCardMoment == nil
        else { return }
        #if DEBUG
        if let probe = probeLessonScript() {
            startTutorialRun(.lesson(Self.probeExplainLesson), steps: probe)
            return
        }
        #endif
        guard let lesson = nextLesson() else { return }
        startTutorialRun(.lesson(lesson.rawValue), steps: lesson.steps)
    }

    #if DEBUG
    /// Una lección SÓLO de DEBUG para `TutorialLockUITests`: un paso de explicar y nada más,
    /// para medir el candado real sin armar el momento de ninguna lección. No está en el
    /// currículo ni en la cobertura; la pide `--uitest-lesson=probe_explain`.
    static let probeExplainLesson = "probe_explain"

    private func probeLessonScript() -> [TutorialStep]? {
        guard tutorialEngine.forcedLesson == Self.probeExplainLesson,
              !TutorialFlags.isLessonDone(Self.probeExplainLesson, in: flagDefaults) else { return nil }
        return [.explain("probe_explain.one", text: "tutorial.confirm")]
    }
    #endif

    /// La forzada (`--uitest-lesson`) saltea la señal de gating y `needsCalmBoard`: es para
    /// fixtures que quieren la lección sin armar su momento.
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
        if run.script == .core {
            progressCore(probe: probe)
            return
        }
        let onScreen = showing == .tutorialTip
        // La regla de oro hasta el último frame: una lección que todavía no tomó el turno y
        // cuya condición murió se retira SIN marcarse, y vuelve cuando su momento vuelva.
        if !onScreen, lessonMomentDied(run) {
            tutorialRun = nil
            celebrations.finish(.tutorialTip)
            return
        }
        // Sin el turno de la cola no avanza: los eventos quedan anotados y cuentan cuando
        // le toque. Avanzar acá terminaría la lección (y la marcaría dada) sin haberse visto.
        if runTakesAQueueTurn(run), !onScreen { return }
        if !uiCoversBoard, run.rewindToBoard(probe: probe) {
            tutorialRun = run
            resetTutorialClock()
            return
        }
        if run.isStepSatisfied(probe: probe) {
            advanceTutorialStep()
            return
        }
        // Ya en pantalla y su momento murió (el visitante se fue, la plata se gastó): ya no
        // se puede cumplir y, sin timeout ni salto, trabaría la cola hasta el watchdog de
        // 3 min con el scrim puesto. Se retira MARCADA —estuvo en pantalla—, por la misma
        // salida del turno que el último paso.
        if lessonMomentDied(run) {
            Log.lifecycle.info("tutorial: lección retirada en pantalla, su momento murió: \(run.lessonID ?? "", privacy: .public)")
            celebrationFinished(.tutorialTip)
        }
    }

    /// La señal de gating de la lección se apagó antes de que el jugador avanzara un paso.
    /// Pasado el primero ya está adentro de la lección: la termina su guion (o el watchdog).
    /// La forzada (`--uitest-lesson`) no mira la señal al nacer y tampoco acá.
    private func lessonMomentDied(_ run: TutorialRun) -> Bool {
        guard run.index == 0, let id = run.lessonID, id != tutorialEngine.forcedLesson,
              let lesson = TutorialLesson(rawValue: id) else { return false }
        return !isEligible(lesson)
    }

    /// El núcleo avanza en bucle mientras el paso esté cumplido: sus señales son los
    /// milestones `ftue.*`, que persisten, así que matar la app a mitad de guion retoma en el
    /// primer paso no cumplido. El recorte del tablero lo pide el director (lo lee `BoardScene`);
    /// con una celebración en pantalla —el reveal del primer merge— se calla.
    private func progressCore(probe: TutorialProbe) {
        while let run = tutorialRun, run.script == .core, run.isStepSatisfied(probe: probe) {
            advanceTutorialStep()
        }
        let target = showing == nil ? tutorialRun?.step?.boardTarget : nil
        if tutorialBoardTarget != target { tutorialBoardTarget = target }
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
            tutorialRun = nil
            finishTutorialCore()
        case .lesson where isInlineRun(run):
            if let id = run.lessonID { TutorialFlags.markLessonDone(id, in: flagDefaults) }
            tutorialRun = nil
            tutorialEngine.pacing.lessonEnded()
        case .lesson, .tour, .replay:
            celebrationFinished(.tutorialTip)
        }
    }

    /// Lo que suelta el turno de `.tutorialTip` (`releasePayload`): el último paso, el
    /// watchdog del paso y el momento que murió en pantalla. Ya no hay timeout ni toque que
    /// saltee (PLAN-v2 §2). La lección queda dada y el ritmo empieza a contar. El Tour y el
    /// repaso no marcan lecciones acá: lo hacen al terminar (E9b).
    func releaseTutorialTurn() {
        // El núcleo y las tarjetas embebidas no tienen turno en la cola: no se sueltan acá.
        guard let run = tutorialRun, runTakesAQueueTurn(run) else { return }
        if let id = run.lessonID { TutorialFlags.markLessonDone(id, in: flagDefaults) }
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
