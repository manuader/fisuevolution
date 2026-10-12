import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El Tour de novedades de la 2.0 (PLAN-v2 E9b T4): el veterano lo recibe una vez, en un
/// momento tranquilo, y al terminarlo lo que cubrió queda dado.
@Suite("El Tour de novedades", .serialized)
@MainActor
struct TutorialTourTests {
    private func makeGameState(veteran: Bool) async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tour-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        if veteran {
            TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
            TutorialFlags.setTourPending(true, in: gameState.flagDefaults)
        }
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    private func confirmEveryStep(_ gameState: GameState) {
        for _ in TutorialCurriculum.tour {
            gameState.advanceTutorial(delta: 5)
            gameState.confirmTutorialStep()
        }
    }

    @Test("el Tour gana sobre cualquier lección y es sólo de explicar")
    func tourFirstAndExplainOnly() async {
        let gameState = await makeGameState(veteran: true)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        #expect(gameState.tutorialRun?.isDemo == true)
        #expect(gameState.tutorialRun?.step?.id == "tour.intro")
        #expect(gameState.showing == .tutorialTip)
        #expect(!TutorialCurriculum.tour.isEmpty)
        #expect(TutorialCurriculum.tour.allSatisfy { $0.clockKind == .explain })
    }

    @Test("al terminar: sin Tour pendiente, lo cubierto queda dado y el save no cambió")
    func tourEnd() async {
        let gameState = await makeGameState(veteran: true)
        let before = gameState.player?.meta
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        confirmEveryStep(gameState)
        #expect(gameState.tutorialRun == nil)
        #expect(!TutorialFlags.tourPending(in: gameState.flagDefaults))
        #expect(!TutorialCurriculum.tourCoveredLessons.isEmpty)
        for lesson in TutorialCurriculum.tourCoveredLessons {
            #expect(gameState.isLessonDone(lesson), "\(lesson)")
        }
        #expect(gameState.player?.meta == before, "el Tour no toca el save")
    }

    @Test("el Tour no vuelve, y las lecciones que no cubrió siguen su camino")
    func tourDoesNotComeBack() async {
        let gameState = await makeGameState(veteran: true)
        gameState.refreshProjections()
        confirmEveryStep(gameState)
        gameState.advanceTutorial(delta: 60)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script != .tour)
        #expect(!GameState.TutorialLesson.allCases.filter { !TutorialCurriculum.tourCoveredLessons.contains($0) }.isEmpty)
    }

    @Test("el Tour espera un momento tranquilo y entonces nace")
    func tourWaitsForACalmMoment() async {
        let gameState = await makeGameState(veteran: true)
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "con un aviso en pantalla no nace")
        gameState.towerNotice = nil
        gameState.celebrationFinished(.towerNotice)
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        #expect(TutorialFlags.tourPending(in: gameState.flagDefaults), "mientras no termina sigue pendiente")
    }

    @Test("sin los autoarranques (tests ajenos, fixtures de UI) el Tour no nace")
    func tourRespectsTheAutorun() async {
        let gameState = await makeGameState(veteran: true)
        gameState.tutorialLessonsAutorun = false
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
    }

    @Test("una instalación nueva no ve el Tour; el veterano, sí")
    func freshInstallHasNoTourButAVeteranDoes() async {
        let fresh = await makeGameState(veteran: false)
        fresh.refreshProjections()
        #expect(fresh.tutorialRun?.script != .tour)
        #expect(!TutorialFlags.tourPending(in: fresh.flagDefaults))
        let veteran = await makeGameState(veteran: true)
        veteran.refreshProjections()
        #expect(veteran.tutorialRun?.script == .tour)
    }

    @Test("el Tour no arranca con el núcleo sin hacer")
    func tourNeedsTheCore() async {
        let gameState = await makeGameState(veteran: false)
        TutorialFlags.setTourPending(true, in: gameState.flagDefaults)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script != .tour)
    }

    @Test("el Tour espera al jugador: ni el tiempo ni abrir una hoja lo mueven de paso")
    func theTourWaitsForThePlayer() async {
        let gameState = await makeGameState(veteran: true)
        gameState.refreshProjections()
        gameState.advanceTutorial(delta: 400)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        #expect(gameState.tutorialRun?.step?.id == "tour.intro")
        gameState.tutorialTipHandled(opening: .menu)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "tour.intro", "una demostración no avanza por señales")
        gameState.advanceTutorial(delta: 5)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun?.step?.id == "tour.quick_hire")
    }

    @Test("cada paso del Tour tiene un id único y su texto")
    func stepsAreUnique() {
        let ids = TutorialCurriculum.tour.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("tour.") })
        #expect(TutorialCurriculum.tour.allSatisfy { $0.textKey.hasPrefix("tutorial.tour.") })
    }
}
