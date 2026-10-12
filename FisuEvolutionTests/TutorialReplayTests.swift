import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El repaso y el Tour pedidos desde Ajustes (PLAN-v2 E9b T5): demostraciones que no dejan
/// huella en la partida, ni en las banderas de las lecciones.
@Suite("El repaso del tutorial", .serialized)
@MainActor
struct TutorialReplayTests {
    private func makeGameState(coreDone: Bool = true) async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "replay-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        if coreDone {
            TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
            TutorialFlags.markLessonDone(GameState.TutorialLesson.upgrades.rawValue, in: gameState.flagDefaults)
        }
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = false
        return gameState
    }

    private func confirmEveryStep(_ gameState: GameState, count: Int) {
        for _ in 0..<count {
            gameState.advanceTutorial(delta: 5)
            gameState.confirmTutorialStep()
        }
    }

    @Test("el repaso es el núcleo y lo ya visto, sólo de explicar")
    func replayContents() {
        let steps = TutorialCurriculum.replay(seenLessons: [.upgrades])
        #expect(steps.first?.id == "replay.core.tap")
        #expect(steps.contains { $0.id.hasPrefix("replay.upgrades.") })
        #expect(!steps.contains { $0.id.hasPrefix("replay.passive") }, "lo no visto no se repasa")
        #expect(steps.allSatisfy { $0.clockKind == .explain && $0.surface == .board })
        #expect(Set(steps.map(\.id)).count == steps.count)
        #expect(TutorialCurriculum.replay(seenLessons: []).count == TutorialCurriculum.core.count)
    }

    @Test("pedirlo espera al tablero libre; el repaso muestra pasos y terminarlo no toca nada")
    func replayLeavesNoTrace() async {
        let gameState = await makeGameState()
        let before = gameState.player
        gameState.requestTutorialReplay()
        gameState.uiCoversBoard = true
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "espera a que se cierre la hoja")
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .replay)
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialRun?.step?.id == "replay.core.tap", "el repaso SÍ mostró pasos")
        confirmEveryStep(gameState, count: 1)
        #expect(gameState.tutorialRun?.step?.id == "replay.core.hire")
        gameState.endReplay()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.showing == nil)
        #expect(gameState.player?.meta == before?.meta, "el repaso no toca el save")
        #expect(gameState.player?.run == before?.run)
        #expect(TutorialFlags.isLessonDone(GameState.TutorialLesson.upgrades.rawValue, in: gameState.flagDefaults))
        #expect(!TutorialFlags.isLessonDone(GameState.TutorialLesson.passive.rawValue, in: gameState.flagDefaults))
        #expect(TutorialFlags.coreCompleted(in: gameState.flagDefaults))
        #expect(!gameState.tutorialPhaseActive, "el repaso del núcleo no reabre la fase")
    }

    @Test("un repaso entero termina solo, sin marcar nada, y no vuelve")
    func replayRunsToTheEnd() async {
        let gameState = await makeGameState()
        let before = gameState.player?.meta
        gameState.requestTutorialReplay()
        gameState.refreshProjections()
        let total = gameState.tutorialRun?.steps.count ?? 0
        #expect(total > TutorialCurriculum.core.count)
        confirmEveryStep(gameState, count: total)
        #expect(gameState.tutorialRun == nil)
        gameState.advanceTutorial(delta: 60)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "no vuelve por sí solo")
        #expect(gameState.player?.meta == before)
        #expect(!TutorialFlags.isLessonDone(GameState.TutorialLesson.passive.rawValue, in: gameState.flagDefaults))
    }

    @Test("el vigilante no mueve el repaso: espera al jugador y no vuelve a ningún paso")
    func watchdogLeavesTheReplayAlone() async {
        let gameState = await makeGameState()
        gameState.requestTutorialReplay()
        gameState.refreshProjections()
        confirmEveryStep(gameState, count: 3)
        let step = gameState.tutorialRun?.step?.id
        #expect(step == "replay.core.merge")
        gameState.advanceTutorial(delta: 400)
        gameState.refreshProjections()
        gameState.advanceTutorial(delta: 400)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == step, "ni salta ni rebobina a un paso de tablero")
    }

    @Test("«Ver novedades» corre el Tour aunque ya se haya visto, sin tocar banderas ni terminarse antes")
    func tourOnDemand() async {
        let gameState = await makeGameState()
        let before = gameState.player?.meta
        let flagsBefore = GameState.TutorialLesson.allCases.map { gameState.isLessonDone($0) }
        gameState.requestTour()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        gameState.endReplay()
        #expect(gameState.tutorialRun?.script == .tour, "«Terminar repaso» es sólo del repaso")
        confirmEveryStep(gameState, count: TutorialCurriculum.tour.count)
        #expect(gameState.tutorialRun == nil)
        #expect(GameState.TutorialLesson.allCases.map { gameState.isLessonDone($0) } == flagsBefore,
                "el Tour pedido no marca lecciones")
        #expect(gameState.player?.meta == before)
    }

    @Test("con el núcleo sin hacer no hay repaso: la fila lo dice y el pedido no hace nada")
    func unavailableWhileTheCoreIsAlive() async {
        let gameState = await makeGameState(coreDone: false)
        #expect(!gameState.tutorialReplayAvailable)
        gameState.requestTutorialReplay()
        gameState.requestTour()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script != .replay && gameState.tutorialRun?.script != .tour)
        TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "el pedido rechazado no queda pendiente")
        #expect(gameState.tutorialReplayAvailable)
    }

    @Test("lo pedido no depende de los autoarranques ni del ritmo")
    func requestedRunsIgnoreTheAutorunAndPacing() async {
        let gameState = await makeGameState()
        gameState.tutorialLessonsAutorun = false
        gameState.requestTutorialReplay()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .replay)
    }
}
