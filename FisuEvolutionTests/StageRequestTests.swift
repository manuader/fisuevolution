import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("El escenario: el popup solo, el piso y el pedido con la cara", .serialized)
@MainActor
struct StageRequestTests {
    private let size = CGSize(width: 393, height: 852)

    /// Frontera en 6 con plata y dos pares: hay a quién pedirle (como `VisitorRuntimeTests`).
    private func world(_ scriptId: String, arrival: Bool = true) async throws -> (GameState, StageController) {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        let controller = StageController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: size, bottomInset: 118, cellSize: 72)
        let script = try #require(gameState.content?.visitors.script(id: scriptId))
        gameState.presentVisitor(script)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        if arrival { try walkIn(gameState, controller) }
        return (gameState, controller)
    }

    private func walkIn(_ gameState: GameState, _ controller: StageController) throws {
        var elapsed = 0.0
        while gameState.stageVisit?.phase == .entering, elapsed < 10 {
            controller.update(delta: 1.0 / 60, reduceMotion: false)
            elapsed += 1.0 / 60
        }
        #expect(gameState.stageVisit?.phase == .waiting)
        for _ in 0..<3 { controller.update(delta: 1.0 / 60, reduceMotion: false) }
    }

    private func frames(_ controller: StageController, _ count: Int = 3, cameraOffsetY: CGFloat? = nil) {
        for _ in 0..<count { controller.update(delta: 1.0 / 60, reduceMotion: false, cameraOffsetY: cameraOffsetY) }
    }

    // MARK: - C2: el popup sale solo, una vez

    @Test("al llegar abre su popup solo; cerrado sin elegir, no se reabre solo")
    func popupOpensByItself() async throws {
        let (gameState, controller) = try await world("turista_propina")
        #expect(gameState.visitorPopup != nil)
        gameState.closeVisitorPopup()
        frames(controller, 10)
        #expect(gameState.visitorPopup == nil, "cerrar no lo reabre")
        #expect(gameState.stageVisit?.offer != nil, "sigue esperando")
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("sin globo de texto: el popup es el que habla")
    func noTextBubbleWhileThereIsAnOffer() async throws {
        let (_, controller) = try await world("turista_propina")
        #expect(controller.bubble == nil)
    }

    @Test("el popup no sale si no se mira su piso, y sale al volver a él")
    func popupWaitsForItsFloor() async throws {
        let (gameState, controller) = try await world("turista_propina", arrival: false)
        let home = gameState.visibleFloorOrdinal
        #expect(gameState.moveVisibleFloor(by: -1) || gameState.moveVisibleFloor(by: 1))
        #expect(gameState.stageVisit == nil, "se congeló en su piso (E14b B7)")
        frames(controller, 10)
        #expect(gameState.visitorPopup == nil, "estás en otro piso")
        gameState.setVisibleFloor(home)
        frames(controller, 3)
        #expect(controller.anchorOrdinal == home)
        #expect(gameState.visitorPopup != nil)
    }

    // MARK: - C6: anclado a su piso

    @Test("se queda en el piso donde apareció: con la cámara en otro piso no se ve, y al volver, sí")
    func staysOnItsFloor() async throws {
        let (gameState, controller) = try await world("turista_propina")
        gameState.closeVisitorPopup()
        let anchor = controller.anchorOrdinal
        frames(controller, 2, cameraOffsetY: CGFloat(anchor) * size.height)
        let actor = try #require(controller.actor)
        let home = actor.position.y
        #expect(!actor.isHidden)
        frames(controller, 2, cameraOffsetY: CGFloat(anchor + 3) * size.height)
        #expect(actor.isHidden, "en el piso +3 no está")
        #expect(actor.position.y < -size.height, "se fue con su piso hacia abajo")
        frames(controller, 2, cameraOffsetY: CGFloat(anchor) * size.height)
        #expect(!actor.isHidden)
        #expect(abs(actor.position.y - home) < 0.5, "vuelve exacto a su lugar")
    }

    @Test("a mitad de un scroll acompaña a su piso")
    func scrollsWithItsFloor() async throws {
        let (gameState, controller) = try await world("turista_propina")
        gameState.closeVisitorPopup()
        let anchor = controller.anchorOrdinal
        frames(controller, 2, cameraOffsetY: CGFloat(anchor) * size.height)
        let home = try #require(controller.actor).position.y
        frames(controller, 2, cameraOffsetY: CGFloat(anchor) * size.height + 100)
        #expect(abs(try #require(controller.actor).position.y - (home - 100)) < 0.5)
    }

    @Test("se para en el horizonte, no en la franja de abajo")
    func standsAtTheHorizon() async throws {
        let (gameState, controller) = try await world("turista_propina")
        gameState.closeVisitorPopup()
        frames(controller, 2)
        let actor = try #require(controller.actor)
        let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: 72)
        #expect(actor.position.y > layout.baselineY + 72)
        #expect(actor.position.x == layout.standX)
    }

    // MARK: - C16: el globo con la cara

    @Test("el comisario muestra el globo con el tier que eligió el pick, y sin texto")
    func arrestShowsTheFace() async throws {
        let (gameState, controller) = try await world("comisario_arresto")
        let offer = try #require(gameState.stageVisit?.offer)
        let request = try #require(controller.request)
        #expect(request.typeId == offer.subjectTypeId)
        #expect(request.kind == .arrest)
        #expect(request.count == 1)
        #expect(controller.bubble == nil)
    }

    @Test("el turista (venta) y la influencer (se lo lleva) tienen su globo; el puntero pide tres")
    func everyRequestingMechanic() async throws {
        for (script, kind, count) in [("turista_compra", RequestBubbleNode.Kind.sale, 1),
                                      ("influencer_novio", .take, 1), ("puntero_acto", .take, 3)] {
            let (gameState, controller) = try await world(script)
            guard gameState.stageVisit?.offer?.subjectTypeId != nil else { continue }
            let request = try #require(controller.request, "\(script)")
            #expect(request.kind == kind, "\(script)")
            #expect(request.count == count, "\(script)")
        }
    }

    @Test("un visitante sin pedido de empleado no tiene globo de pedido")
    func giftHasNoRequest() async throws {
        let (_, controller) = try await world("turista_propina")
        #expect(controller.request == nil)
    }

    @Test("tocar el globo abre el popup")
    func tappingTheBubbleOpensThePopup() async throws {
        let (gameState, controller) = try await world("comisario_arresto")
        gameState.closeVisitorPopup()
        frames(controller, 2)
        let request = try #require(controller.request)
        let inside = CGPoint(x: request.position.x, y: request.position.y + request.height / 2)
        #expect(controller.handleTap(at: inside))
        #expect(gameState.visitorPopup != nil)
    }

    @Test("arrastrar al pedido hasta el visitante lo entrega; otro empleado rebota")
    func dragToDeliver() async throws {
        let (gameState, controller) = try await world("comisario_arresto")
        gameState.closeVisitorPopup()
        let ask = try #require(gameState.stageVisit?.offer?.subjectTypeId)
        let actor = try #require(controller.actor)
        let onActor = CGPoint(x: actor.position.x, y: actor.position.y + 20)
        #expect(controller.handleDrop(at: CGPoint(x: 5, y: 5), typeId: ask) == .ignored, "lejos del visitante no pasa nada")
        #expect(controller.handleDrop(at: onActor, typeId: "no_es_el_pedido") == .bounced)
        #expect(gameState.stageVisit?.offer != nil, "el que no era no cierra el trato")
        let coinsBefore = gameState.player?.run.coins ?? 0
        #expect(controller.handleDrop(at: onActor, typeId: ask) == .delivered)
        #expect(gameState.stageVisit?.offer == nil, "el trato se cerró")
        #expect((gameState.player?.run.coins ?? 0) > coinsBefore, "y cobró lo mismo que por el popup")
    }

    @Test("el que no pide nada no recibe empleados")
    func nothingToDeliver() async throws {
        let (gameState, controller) = try await world("turista_propina")
        gameState.closeVisitorPopup()
        let actor = try #require(controller.actor)
        #expect(controller.handleDrop(at: CGPoint(x: actor.position.x, y: actor.position.y + 20), typeId: "homeless") == .ignored)
    }
}
