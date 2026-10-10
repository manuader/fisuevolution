import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("El escenario: entrar, esperar y salir")
@MainActor
struct StageControllerTests {
    private func stage() async -> (GameState, StageController) {
        let gameState = await makeGameState()
        let controller = StageController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    private func run(_ controller: StageController, seconds: Double, reduceMotion: Bool = false, until done: () -> Bool) {
        var elapsed = 0.0
        while elapsed < seconds, !done() {
            controller.update(delta: 1.0 / 60, reduceMotion: reduceMotion)
            elapsed += 1.0 / 60
        }
    }

    @Test("entra caminando en su turno, llega al centro, espera y se va por el otro lado")
    func walksInWaitsAndLeaves() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        #expect(gameState.showing == .visitorEncounter)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let entering = try #require(controller.actor)
        #expect(entering.position.x < 0 || entering.position.x > 393, "arranca afuera de la pantalla")
        run(controller, seconds: 8) { gameState.stageVisit?.phase == .waiting }
        #expect(gameState.stageVisit?.phase == .waiting)
        #expect(gameState.showing != .visitorEncounter, "llegar libera el turno")
        let actor = try #require(controller.actor)
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(layout.stageRange.contains(actor.position.x))
        gameState.sendStageActorAway()
        run(controller, seconds: 8) { gameState.stageVisit == nil }
        #expect(gameState.stageVisit == nil)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor == nil)
    }

    @Test("mientras espera su turno no se ve")
    func invisibleUntilItsTurn() async throws {
        let (gameState, controller) = await stage()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        #expect(gameState.showing == .towerNotice)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor == nil)
    }

    @Test("con Reduce Motion aparece con un fundido en el centro, sin caminar")
    func reduceMotionFades() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        let actor = try #require(controller.actor)
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(actor.position.x == layout.standX)
        #expect(actor.alpha < 1)
        run(controller, seconds: 1, reduceMotion: true) { gameState.stageVisit?.phase == .waiting }
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("el globo aparece con lo que dice y se va con él")
    func bubble() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.stageVisit?.bubble = "¡Hola, vecino!"
        controller.update(delta: 0.5, reduceMotion: false)
        #expect(controller.bubble?.text == "¡Hola, vecino!")
        gameState.stageVisit?.bubble = nil
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.bubble == nil)
    }

    @Test("saltear la entrada lo deja llegado, una sola vez")
    func skippingTheEntrance() async throws {
        let (gameState, _) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        gameState.advanceCelebrations(delta: CelebrationQueue.skipFloor)
        #expect(gameState.skipCurrentCelebration())
        #expect(gameState.stageVisit?.phase == .waiting)
        gameState.settleStageArrival()
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("tocarlo mientras espera le avisa a la partida; antes, no")
    func tapping() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let entering = try #require(controller.actor)
        #expect(!controller.handleTap(at: entering.position))
        run(controller, seconds: 8) { gameState.stageVisit?.phase == .waiting }
        let actor = try #require(controller.actor)
        #expect(controller.handleTap(at: CGPoint(x: actor.position.x, y: actor.position.y + 10)))
        #expect(!controller.handleTap(at: CGPoint(x: 5, y: 5)))
    }

    @Test("la paciencia corre sólo en un momento calmo, y al agotarse se va")
    func patience() async throws {
        let (gameState, _) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        // Llegar por la escena cierra el turno: con `.visitorEncounter` en pantalla
        // no es un momento calmo y la paciencia no correría.
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.uiCoversBoard = true
        gameState.advanceStage(delta: 60)
        #expect(gameState.stageVisit?.phase == .waiting, "con una hoja abierta no se impacienta")
        gameState.uiCoversBoard = false
        gameState.advanceStage(delta: 29)
        #expect(gameState.stageVisit?.phase == .waiting)
        gameState.advanceStage(delta: 2)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("cancelar la entrada mientras espera su turno no lo muestra: desaparece sin entrar")
    func cancellingBeforeItsTurn() async throws {
        let (gameState, controller) = await stage()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        gameState.sendStageActorAway()
        #expect(gameState.stageVisit == nil)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor == nil)
    }

    @Test("el watchdog del turno deja la visita llegada")
    func watchdogSettlesTheArrival() async throws {
        let (gameState, _) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        #expect(gameState.showing == .visitorEncounter)
        gameState.advanceCelebrations(delta: 11)
        #expect(gameState.stageVisit?.phase == .waiting)
        #expect(gameState.showing != .visitorEncounter)
    }
}
