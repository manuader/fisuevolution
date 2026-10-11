import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los pasos que viven adentro de una hoja", .serialized)
@MainActor
struct TutorialSheetCoachTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "coach-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        return gameState
    }

    private let sheetLesson: [TutorialStep] = [
        .act("probe.open", .screenOpened(.upgrades), text: "tutorial.confirm", on: .upgrades),
        .explain("probe.inside", text: "tutorial.confirm", surface: .page(.upgrades)),
    ]

    @Test("el paso de la hoja se ve sólo con esa página abierta")
    func visibleOnlyOnItsPage() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: sheetLesson)
        gameState.uiCoversBoard = true
        gameState.tutorialTipHandled(opening: .upgrades)
        #expect(gameState.tutorialRun?.step?.id == "probe.inside")
        #expect(gameState.tutorialStepIsVisible)
        gameState.menuPageChanged(to: .skins)
        #expect(!gameState.tutorialStepIsVisible, "deslizó a otra página")
    }

    @Test("el coach de la hoja calla mientras otra celebración tiene el turno (nunca dos scrims)")
    func theCoachWaitsForItsTurn() async {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(gameState.showing == .towerNotice)
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .explain("probe.inside", text: "tutorial.confirm", surface: .page(.upgrades)),
        ])
        gameState.uiCoversBoard = true
        gameState.tutorialEngine.openPage = .upgrades
        #expect(!gameState.tutorialStepIsVisible)
        gameState.celebrationFinished(.towerNotice)
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialStepIsVisible)
    }

    @Test("cerrar la hoja vuelve al paso que la abre")
    func closingRewinds() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: sheetLesson)
        gameState.uiCoversBoard = true
        gameState.tutorialTipHandled(opening: .upgrades)
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "probe.open")
    }

    @Test("el núcleo contrata adentro de FisuJobs con el coach")
    func coreHireHasASheetStep() {
        let ids = TutorialCurriculum.core.map(\.id)
        #expect(ids == ["core.tap", "core.hire", "core.hire.inside", "core.merge", "core.finish"])
        #expect(TutorialCurriculum.core[2].surface == .page(.jobs))
        #expect(TutorialCurriculum.core[2].target == .jobsRecommended)
    }

    @Test("una lección cuyo próximo paso es de una hoja termina por watchdog: no rebota cada 3 min")
    func theWatchdogEndsALessonThatWouldBounce() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: sheetLesson)
        gameState.advanceTutorial(delta: 179)
        #expect(gameState.tutorialRun != nil)
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "no se salta a un paso invisible que rewindToBoard devolvería")
        #expect(gameState.showing != .tutorialTip)
        #expect(TutorialFlags.isLessonDone("probe", in: gameState.flagDefaults))
    }

    @Test("una lección de pasos de tablero sigue avanzando por watchdog como siempre")
    func theWatchdogStillAdvancesBoardSteps() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .act("probe.one", .screenOpened(.upgrades), text: "tutorial.confirm", on: .upgrades),
            .act("probe.two", .screenOpened(.skins), text: "tutorial.confirm", on: .skins),
        ])
        gameState.advanceTutorial(delta: 180)
        #expect(gameState.tutorialRun?.step?.id == "probe.two")
    }

    @Test("entrar a la ficha avisa que se abrió: el paso de la ficha avanza")
    func theCharacterSheetSignal() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .act("probe.sheet", .characterSheetOpened, text: "tutorial.confirm", on: nil),
            .explain("probe.done", text: "tutorial.confirm"),
        ])
        gameState.tutorialSignal(.characterSheetOpened)
        #expect(gameState.tutorialRun?.step?.id == "probe.done")
    }
}
