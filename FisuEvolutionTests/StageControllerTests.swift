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

    // MARK: - El video del visitante

    private func clipManifest(talking: [String] = [], actions: [String] = []) throws -> LoopsManifest {
        func entries(_ ids: [String]) -> String {
            ids.map { #""\#($0)":{"file":"cine_arresto.mov","width":512,"height":512,"alpha":true,"audio":false}"# }
                .joined(separator: ",")
        }
        let json = #"{"schemaVersion":1,"talking":{\#(entries(talking))},"visitorActions":{\#(entries(actions))}}"#
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
    }

    private func videoStage(talking: [String] = ["npc_vecina"], actions: [String] = ["npc_vecina"])
        async throws -> (GameState, StageController, VideoPlayerPool) {
        let gameState = await makeGameState()
        let pool = VideoPlayerPool(policy: .allowAll)
        let controller = StageController(gameState: gameState, loops: try clipManifest(talking: talking, actions: actions),
                                         pool: pool)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        return (gameState, controller, pool)
    }

    private func arrive(_ gameState: GameState, _ controller: StageController) throws {
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.stageVisit?.bubble = nil
        controller.update(delta: 1.0 / 60, reduceMotion: false)
    }

    @Test("esperando con globo, su clip hablado")
    func waitingWithBubbleShowsTalking() async throws {
        let (gameState, controller, _) = try await videoStage()
        try arrive(gameState, controller)
        gameState.stageVisit?.bubble = "¡Hola, vecino!"
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor?.videoClip == .talking("npc_vecina"))
    }

    @Test("esperando sin globo, su clip de acción")
    func waitingWithoutBubbleShowsAction() async throws {
        let (gameState, controller, _) = try await videoStage()
        try arrive(gameState, controller)
        #expect(controller.actor?.videoClip == .visitorAction("npc_vecina"))
    }

    @Test("sin entradas en el manifest: ni clip ni nodo de video")
    func noClipNoVideoNode() async throws {
        let (gameState, controller, pool) = try await videoStage(talking: [], actions: [])
        try arrive(gameState, controller)
        gameState.stageVisit?.bubble = "¡Hola!"
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let actor = try #require(controller.actor)
        #expect(actor.videoClip == nil)
        #expect(!actor.children.contains { $0 is LoopingVideoNode })
        #expect(actor.texture != nil && pool.liveCount == 0)
    }

    @Test("entrando y saliendo camina con su textura: sin video")
    func enteringAndLeavingHaveNoVideo() async throws {
        let (gameState, controller, pool) = try await videoStage()
        let actor = try #require(controller.actor)
        #expect(actor.videoClip == nil, "entrando")
        try arrive(gameState, controller)
        #expect(actor.videoClip != nil && pool.liveCount == 1)
        gameState.sendStageActorAway()
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(actor.videoClip == nil, "saliendo")
        #expect(pool.liveCount == 0)
    }

    @Test("el mismo clip en dos frames no se vuelve a montar")
    func sameClipIsNotRemounted() async throws {
        let (gameState, controller, _) = try await videoStage()
        try arrive(gameState, controller)
        gameState.stageVisit?.bubble = "¡Hola, vecino!"
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let first = try #require(controller.actor?.children.first { $0 is LoopingVideoNode })
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let second = try #require(controller.actor?.children.first { $0 is LoopingVideoNode })
        #expect(ObjectIdentifier(first) == ObjectIdentifier(second))
    }

    @Test("sacar al visitante apaga su video")
    func clearStopsVideo() async throws {
        let (gameState, controller, pool) = try await videoStage()
        try arrive(gameState, controller)
        #expect(pool.liveCount == 1)
        gameState.stageVisit = nil
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor == nil && pool.liveCount == 0)
    }
}
