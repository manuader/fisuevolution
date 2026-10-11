import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El director del tutorial v2 (`GameState+Tutorial`): corridas de pasos, el candado de 5 s,
/// el watchdog de 3 min y el ritmo entre lecciones. El tiempo entra por `advanceTutorial(delta:)`:
/// nunca un `sleep`.
@Suite("El director del tutorial v2", .serialized)
@MainActor
struct TutorialDirectorTests {
    private func makeGameState() async -> GameState {
        for lesson in GameState.TutorialLesson.allCases {
            UserDefaults.standard.removeObject(forKey: lesson.defaultsKey)
        }
        UserDefaults.standard.removeObject(forKey: TutorialFlags.sessionsAfterCoreKey)
        // La corrida de prueba de los tests del candado se marca dada al terminar.
        UserDefaults.standard.removeObject(forKey: TutorialFlags.lessonKey("probe"))
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "director-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        // Una partida nueva ya tiene un giro de la ruleta listo: sin esto las lecciones de la
        // columna le ganan el turno a la de Mejoras (el mismo arreglo que `TutorialTipsTests`).
        gameState.markLessonDone(.sideRail)
        gameState.markLessonDone(.wheel)
        return gameState
    }

    @Test("una lección nace como corrida de pasos y toma el turno de la cola")
    func aLessonBecomesARun() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .lesson("upgrades"))
        #expect(gameState.tutorialRun?.step == GameState.TutorialLesson.upgrades.legacyStep)
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialTip?.lesson == .upgrades, "el alias que leen los tests de E4b/E5b/E7b-b")
    }

    @Test("cada lección de hoy es un paso: su destino o su acción firma, con su texto y su ancla")
    func everyLessonIsOneLegacyStep() {
        for lesson in GameState.TutorialLesson.allCases {
            #expect(lesson.steps == [lesson.legacyStep])
            let step = lesson.legacyStep
            #expect(step.textKey == lesson.textKey)
            #expect(step.target == lesson.anchorTarget)
            #expect(step.surface == .board)
            if let screen = lesson.destinationScreen {
                #expect(step.signal == .screenOpened(screen), "\(lesson.rawValue)")
            } else {
                #expect(step.signal == .lessonAction, "\(lesson.rawValue)")
            }
        }
    }

    @Test("hacer lo que señala la cumple, y la siguiente espera 20 s")
    func pacingAfterALesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.tutorialTipHandled(opening: .upgrades)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey))
        gameState.advanceTutorial(delta: 19)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "antes de los 20 s del fin no nace otra (con plata, el atajo ya es elegible)")
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun != nil)
    }

    @Test("con el dedo en el tablero en el último segundo no nace ninguna")
    func quietBoard() async {
        let gameState = await makeGameState()
        // El toque primero: `debugGrantCoins` ya corre un refresh.
        _ = gameState.skipCurrentCelebration()
        gameState.debugGrantCoins()
        #expect(gameState.tutorialRun == nil)
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun != nil)
    }

    @Test("con la cola ocupada no nace: la lección espera la cola libre y entonces toma el turno")
    func aLessonWaitsForAFreeQueue() async {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.showing == .towerNotice)
        #expect(gameState.tutorialRun == nil, "nacer detrás del aviso tomaría la foto del paso a destiempo")
        gameState.towerNotice = nil
        gameState.celebrationFinished(.towerNotice)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades, "un aviso que se va no es una lección: no hay ritmo que esperar")
        #expect(gameState.showing == .tutorialTip)
    }

    @Test("el reloj del paso corre sólo con el paso a la vista")
    func theClockRunsOnlyWhenVisible() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.uiCoversBoard = true
        gameState.advanceTutorial(delta: 3)
        #expect(gameState.tutorialEngine.clock.elapsed == 0)
        gameState.uiCoversBoard = false
        gameState.advanceTutorial(delta: 3)
        #expect(gameState.tutorialEngine.clock.elapsed == 3)
    }

    @Test("un paso de acción trabado 3 min se libera, sin premio, y la lección queda dada")
    func theWatchdog() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        let oro = gameState.player?.meta.oro
        let coins = gameState.player?.run.coins
        gameState.advanceTutorial(delta: 179)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun != nil)
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.showing != .tutorialTip)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey))
        #expect(gameState.player?.meta.oro == oro)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("«Entendido» no hace nada con el candado puesto")
    func confirmRespectsTheLock() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .explain("probe.one", text: "tutorial.step.finish"),
            .explain("probe.two", text: "tutorial.step.finish"),
        ])
        #expect(gameState.showing == .tutorialTip, "una corrida que no es del núcleo pide su turno")
        gameState.advanceTutorial(delta: 4.9)
        #expect(gameState.tutorialLockProgress < 1)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun?.index == 0)
        gameState.advanceTutorial(delta: 0.1)
        #expect(gameState.tutorialRun?.unlocked == true)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun?.index == 1)
        #expect(gameState.tutorialRun?.unlocked == false, "el paso siguiente vuelve a esperar sus 5 s")
        #expect(gameState.tutorialLockProgress == 0)
    }

    @Test("el último «Entendido» termina la corrida y suelta el turno")
    func theLastConfirmFinishesTheRun() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .explain("probe.one", text: "tutorial.step.finish"),
        ])
        gameState.advanceTutorial(delta: 5)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.showing != .tutorialTip)
    }

    @Test("una lección en pantalla congela los relojes con paciencia (no es un momento calmo)")
    func lessonsFreezePatience() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.showing == .tutorialTip)
        #expect(!gameState.isCalmMoment)
    }
}
