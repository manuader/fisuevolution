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
    /// Las banderas de cada test viven en su propio dominio: arranca sin lecciones dadas y no
    /// le deja nada al host ni al test siguiente.
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "director-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        // Una partida nueva ya tiene un giro de la ruleta listo: sin esto las lecciones de la
        // columna le ganan el turno a la de Mejoras (el mismo arreglo que `TutorialTipsTests`), y el
        // atajo, primero del orden, también: queda dado.
        gameState.markLessonDone(.sideRail)
        gameState.markLessonDone(.wheel)
        gameState.markLessonDone(.quickHire)
        return gameState
    }

    @Test("una lección nace como corrida de pasos y toma el turno de la cola")
    func aLessonBecomesARun() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .lesson("upgrades"))
        #expect(gameState.tutorialRun?.step?.id == "upgrades.open")
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialTip?.lesson == .upgrades, "el alias que leen los tests de E4b/E5b/E7b-b")
    }

    @Test("hacer lo que señala la cumple, y la siguiente espera 20 s")
    func pacingAfterALesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.finishUpgradesLessonForTest()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.isLessonDone(.upgrades))
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
        #expect(gameState.isLessonDone(.upgrades))
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

    @Test("la cola ya no vence una lección: sin timeout, sigue con su turno")
    func theQueueNoLongerTimesOutALesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        #expect(gameState.showing == .tutorialTip)
        gameState.advanceCelebrations(delta: 60)
        #expect(gameState.showing == .tutorialTip, "los 12 s de la v1 ya no la sueltan")
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        #expect(!gameState.isLessonDone(.upgrades))
    }

    @Test("el toque al tablero no saltea la lección")
    func theBoardTapDoesNotSkip() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.advanceCelebrations(delta: 5)
        #expect(gameState.showing == .tutorialTip)
        #expect(!gameState.skipCurrentCelebration())
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialRun != nil)
        #expect(!gameState.isLessonDone(.upgrades))
        // Y lo que sí la cumple, la sigue cumpliendo: el toque no la rompió.
        gameState.finishUpgradesLessonForTest()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.isLessonDone(.upgrades))
    }

    /// El carry de T4: sin timeout ni salto, una lección en pantalla cuyo momento murió
    /// trabaría la cola —y el scrim— hasta el watchdog de 3 min.
    @Test("una lección en pantalla cuyo momento murió se retira, marcada, y suelta la cola")
    func aShownLessonWhoseMomentDiedRetires() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        gameState.player?.run.coins = 0
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "ya no se puede cumplir: no se queda 3 min")
        #expect(gameState.showing != .tutorialTip, "y la cola queda libre")
        #expect(gameState.isLessonDone(.upgrades), "estuvo en pantalla: no vuelve")
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(gameState.showing == .towerNotice, "lo que venía detrás toma el turno")
    }

    @Test("con su momento vivo, una lección en pantalla no se retira")
    func aShownLessonWithItsMomentStays() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        for _ in 0..<5 {
            gameState.advanceTutorial(delta: 1)
            gameState.refreshProjections()
        }
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        #expect(gameState.showing == .tutorialTip)
        #expect(!gameState.isLessonDone(.upgrades))
    }

    @Test("la forzada (--uitest-lesson) no se retira por su señal")
    func theForcedLessonIgnoresItsSignal() async {
        let gameState = await makeGameState()
        gameState.tutorialEngine.forcedLesson = "upgrades"
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades, "sin plata, nace igual: es forzada")
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        #expect(gameState.showing == .tutorialTip)
    }

    @Test("probe_explain (DEBUG): un paso de explicar con su candado, para el test de UI")
    func theProbeLesson() async {
        let gameState = await makeGameState()
        gameState.tutorialEngine.forcedLesson = "probe_explain"
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .lesson("probe_explain"))
        #expect(gameState.tutorialRun?.step?.id == "probe_explain.one")
        #expect(gameState.tutorialRun?.step?.clockKind == .explain)
        #expect(gameState.showing == .tutorialTip)
        gameState.advanceCelebrations(delta: 4)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun != nil, "con el candado puesto no avanza")
        gameState.advanceCelebrations(delta: 1)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun == nil)
        #expect(TutorialFlags.isLessonDone("probe_explain", in: gameState.flagDefaults))
    }

    @Test("abrir otra pestaña no cumple la lección de Mejoras")
    func anotherScreenDoesNotCompleteTheLesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        gameState.tutorialTipHandled(opening: .store)
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        #expect(gameState.showing == .tutorialTip)
        #expect(!gameState.isLessonDone(.upgrades))
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
