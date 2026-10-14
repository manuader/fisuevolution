import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Ningún tip queda sin salida (E14b B11): el chip de compartir sigue a la vista mientras su
/// lección lo señala, y toda lección del tablero se cierra con su botón.
@Suite("Los tips siempre tienen salida", .serialized)
@MainActor
struct TutorialTipExitTests {
    private func makeGameState(keeping kept: GameState.TutorialLesson = .share) async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tip-exit-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        gameState.shareOffersEnabled = true
        for lesson in GameState.TutorialLesson.allCases where lesson != kept { gameState.markLessonDone(lesson) }
        return gameState
    }

    private func startShareLesson(_ gameState: GameState) {
        gameState.shareOffer = .newFloor(floorID: "urban")
        gameState.refreshProjections()
    }

    @Test("el chip de compartir se ve mientras su lección lo señala")
    func theChipStaysWhileItsLessonPointsAtIt() async {
        let gameState = await makeGameState()
        startShareLesson(gameState)
        #expect(gameState.tutorialTip?.lesson == .share)
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.shareOfferIsOnScreen, "el tip señala un chip que se escondió")
    }

    @Test("con otra celebración en pantalla el chip sigue escondido")
    func theChipHidesBehindAnyOtherTurn() async {
        let gameState = await makeGameState(keeping: .upgrades)
        gameState.shareOffer = .newFloor(floorID: "urban")
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
        #expect(!gameState.shareOfferIsOnScreen, "dos avisos apilados")
    }

    @Test("toda lección del tablero se puede cerrar con su botón; el núcleo y las demostraciones no")
    func everyLessonIsClosable() async {
        let gameState = await makeGameState()
        let probe = gameState.tutorialProbe()
        for lesson in GameState.TutorialLesson.allCases {
            let run = TutorialRun(script: .lesson(lesson.rawValue), steps: lesson.steps, probe: probe)
            #expect(gameState.tutorialTipIsClosable(run), "\(lesson) no tiene salida")
        }
        #expect(!gameState.tutorialTipIsClosable(TutorialRun(script: .core, steps: TutorialCurriculum.core, probe: probe)))
        #expect(!gameState.tutorialTipIsClosable(TutorialRun(script: .tour, steps: GameState.TutorialLesson.share.steps, probe: probe)))
        #expect(!gameState.tutorialTipIsClosable(TutorialRun(script: .replay, steps: GameState.TutorialLesson.share.steps, probe: probe)))
    }

    @Test("cerrar el tip suelta el turno y deja la lección dada")
    func closingReleasesTheTurn() async {
        let gameState = await makeGameState()
        startShareLesson(gameState)
        #expect(gameState.showing == .tutorialTip)
        gameState.closeTutorialTip()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.showing == nil)
        #expect(gameState.isLessonDone(.share))
        #expect(gameState.shareOffer != nil, "cerrar el tip no se lleva la oferta")
        #expect(gameState.shareOfferIsOnScreen, "sin el tip, el chip sigue a la vista")
    }
}
