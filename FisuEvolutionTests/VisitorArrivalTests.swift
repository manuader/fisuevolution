import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

/// E14b B21 (D15): la llegada del visitante no se corta nunca —ni con un toque, ni con un merge,
/// ni con un cambio de piso, ni con otra celebración— y su popup se abre sólo al tocarlo.
@Suite("La llegada del visitante no se corta", .serialized)
@MainActor
struct VisitorArrivalTests {
    private let size = CGSize(width: 393, height: 852)

    /// Un visitante que ya entró a escena y camina hacia su lugar, en el piso que se mira.
    private func walkingVisitor(frames count: Int = 20, openTower: Bool = false) async throws -> (GameState, StageController) {
        let gameState = await makeGameState()
        if openTower { gameState.debugUnlockFloors(throughTier: 6) }
        let controller = StageController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: size, bottomInset: 118, cellSize: 72)
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        #expect(gameState.showing == .visitorEncounter)
        frames(controller, count)
        #expect(gameState.stageVisit?.phase == .entering, "a mitad de la entrada")
        return (gameState, controller)
    }

    private func frames(_ controller: StageController, _ count: Int) {
        for _ in 0..<count { controller.update(delta: 1.0 / 60, reduceMotion: false) }
    }

    private func walkX(_ controller: StageController) throws -> CGFloat {
        try #require(controller.actor).position.x
    }

    @Test("un toque durante la entrada no cambia ni la fase ni la x")
    func aTapKeepsTheEntrance() async throws {
        let (gameState, controller) = try await walkingVisitor()
        gameState.advanceCelebrations(delta: CelebrationQueue.skipFloor * 2)
        let x = try walkX(controller)
        // Lo que hace `BoardScene.touchesBegan`: primero el salteo, después el toque al escenario.
        #expect(!gameState.skipCurrentCelebration())
        let actor = try #require(controller.actor)
        #expect(!controller.handleTap(at: CGPoint(x: actor.position.x, y: actor.position.y + 20)))
        #expect(gameState.stageVisit?.phase == .entering)
        controller.update(delta: 0, reduceMotion: false)
        #expect(abs(try walkX(controller) - x) < 0.01, "no saltó a su lugar")
        #expect(gameState.visitorPopup == nil)
    }

    @Test("un merge durante la entrada no cambia ni la fase ni la x, y su celebración no lo borra")
    func aMergeKeepsTheEntrance() async throws {
        let (gameState, controller) = try await walkingVisitor()
        gameState.debugGrantPair()
        let pair = try #require(Self.firstPair(in: gameState))
        let x = try walkX(controller)
        guard case .merged = gameState.handleDrop(fromCell: pair.0, toCell: pair.1) else {
            Issue.record("el toque fue al tablero y tenía que haber merge")
            return
        }
        #expect(gameState.stageVisit?.phase == .entering)
        controller.update(delta: 0, reduceMotion: false)
        #expect(abs(try walkX(controller) - x) < 0.01)
        #expect(gameState.showing != .visitorEncounter, "la celebración del merge puede tomar el turno")
        frames(controller, 10)
        #expect(controller.actor != nil, "otra celebración no lo borra")
        #expect(try walkX(controller) != x, "y sigue caminando")
        frames(controller, 600)
        #expect(gameState.stageVisit?.phase == .waiting, "termina la entrada entera")
    }

    @Test("un cambio de piso durante la entrada lo congela a mitad de camino")
    func aFloorChangeFreezesTheEntrance() async throws {
        let (gameState, controller) = try await walkingVisitor(openTower: true)
        let home = gameState.visibleFloorOrdinal
        let x = try walkX(controller)
        gameState.setVisibleFloor(home + 1)
        #expect(gameState.stageVisit == nil, "se quedó en su piso")
        let frozen = try #require(gameState.waitingVisitor(onFloor: home))
        #expect(frozen.patienceLeft == gameState.content?.visitors.patienceSeconds, "todavía no empezó a esperar")
        frames(controller, 60)
        #expect(controller.actor == nil)

        gameState.setVisibleFloor(home)
        #expect(gameState.stageVisit?.phase == .entering, "no llegó de golpe")
        controller.update(delta: 0, reduceMotion: false)
        #expect(abs(try walkX(controller) - x) < 0.01, "retoma desde donde quedó")
        frames(controller, 600)
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("el pop-up no se abre sin un toque")
    func thePopupNeedsATap() async throws {
        let (gameState, controller) = try await walkingVisitor()
        frames(controller, 900)
        #expect(gameState.stageVisit?.phase == .waiting)
        #expect(gameState.stageVisit?.offer != nil)
        #expect(gameState.visitorPopup == nil, "llegó, espera y no abrió nada solo")
        let actor = try #require(controller.actor)
        #expect(controller.handleTap(at: CGPoint(x: actor.position.x, y: actor.position.y + 20)))
        #expect(gameState.visitorPopup != nil, "tocarlo lo abre")
    }

    @Test("mientras espera camina por la zona central y se da vuelta en los bordes")
    func itStrollsWhileWaiting() async throws {
        let (gameState, controller) = try await walkingVisitor()
        frames(controller, 900)
        #expect(gameState.stageVisit?.phase == .waiting)
        let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: 72)
        let zone = layout.walkRange(feetY: try #require(controller.actor).position.y, corners: [])
        var xs: [CGFloat] = []
        var facings: Set<CGFloat> = []
        for _ in 0..<(60 * 30) {
            controller.update(delta: 1.0 / 60, reduceMotion: false)
            let actor = try #require(controller.actor)
            xs.append(actor.position.x)
            facings.insert(actor.xScale < 0 ? -1 : 1)
        }
        #expect(xs.allSatisfy { zone.lowerBound - 0.5 <= $0 && $0 <= zone.upperBound + 0.5 })
        #expect((xs.max() ?? 0) - (xs.min() ?? 0) > (zone.upperBound - zone.lowerBound) * 0.9, "la recorre de lado a lado")
        #expect(facings.count == 2, "se da vuelta")
    }

    /// Dos del mismo tipo en el piso que se mira.
    private static func firstPair(in gameState: GameState) -> (Int, Int)? {
        let placements = gameState.visiblePlacements
        for (index, first) in placements.enumerated() {
            if let second = placements[(index + 1)...].first(where: { $0.typeId == first.typeId }) {
                return (first.slot, second.slot)
            }
        }
        return nil
    }
}
