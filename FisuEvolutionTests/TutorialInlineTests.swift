import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las primeras veces en su popup", .serialized)
@MainActor
struct TutorialInlineTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "inline-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    @Test("con las lecciones apagadas (XCTest, --uitest*) la tarjeta no aparece")
    func silentWithoutAutorun() async {
        let gameState = await makeGameState()
        gameState.tutorialLessonsAutorun = false
        gameState.beginInlineLesson(.career)
        #expect(gameState.tutorialRun == nil)
        gameState.tutorialLessonsAutorun = true
        gameState.beginInlineLesson(.career)
        #expect(gameState.tutorialRun?.lessonID == "career", "con las lecciones prendidas SÍ aparece")
    }

    @Test("la tarjeta del offline espera 5 s, no pasa por la cola y queda dada una sola vez")
    func offlineCard() async {
        let gameState = await makeGameState()
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun?.lessonID == "offline", "la primera vez SÍ aparece")
        #expect(gameState.showing != .tutorialTip, "la aloja el popup: no toma un turno propio")
        #expect(gameState.tutorialStepIsVisible)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun != nil, "el candado de 5 s sigue puesto")
        gameState.advanceTutorial(delta: 5)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun == nil)
        #expect(TutorialFlags.isLessonDone("offline", in: gameState.flagDefaults))
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun == nil, "una sola vez")
    }

    @Test("cerrar el popup sin confirmar no la da por vista: vuelve la próxima vez")
    func closingWithoutConfirming() async {
        let gameState = await makeGameState()
        gameState.beginInlineLesson(.career)
        #expect(gameState.tutorialRun?.lessonID == "career")
        gameState.endInlineLesson(.career)
        #expect(gameState.tutorialRun == nil)
        #expect(!TutorialFlags.isLessonDone("career", in: gameState.flagDefaults))
        gameState.beginInlineLesson(.career)
        #expect(gameState.tutorialRun?.lessonID == "career", "vuelve")
    }

    @Test("cerrar otro popup no suelta la tarjeta de éste")
    func endingAnotherLessonKeepsTheRun() async {
        let gameState = await makeGameState()
        gameState.beginInlineLesson(.visitorPopup)
        gameState.endInlineLesson(.career)
        #expect(gameState.tutorialRun?.lessonID == "visitor_popup")
    }

    @Test("no pisa una lección que ya corre")
    func doesNotOverride() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [.explain("probe.one", text: "tutorial.confirm")])
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun?.lessonID == "probe")
    }

    @Test("con el núcleo activo sólo el offline entra (el veterano a medio núcleo)")
    func onlyOfflineDuringTheCore() async {
        let gameState = await makeGameState()
        gameState.tutorialPhaseActive = true
        gameState.beginInlineLesson(.career)
        gameState.beginInlineLesson(.visitorPopup)
        #expect(gameState.tutorialRun == nil)
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun?.lessonID == "offline")
    }

    @Test("cada lección tiene una tarjeta embebida con su texto")
    func everyLessonIsEmbedded() {
        for lesson in TutorialInlineLesson.allCases {
            #expect(lesson.steps.count == 1)
            #expect(lesson.steps.first?.surface == .embedded)
            #expect(lesson.steps.first?.textKey == "tutorial.\(lesson.rawValue).inline")
        }
    }
}
