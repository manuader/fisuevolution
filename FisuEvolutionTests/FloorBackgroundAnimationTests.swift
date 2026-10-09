import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("El fondo del piso visible, animado")
@MainActor
struct FloorBackgroundAnimationTests {
    /// `BoardScene` guarda el `GameState` como `unowned`: el test tiene que sostenerlo.
    private func makeScene(floors: [String: String], pool: VideoPlayerPool) async throws -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        let manifest = try LoopsManifestTests.fixture(floors: floors)
        let scene = BoardScene(gameState: gameState, loops: manifest, videoPool: pool)
        scene.layoutBoard()
        scene.scrollSettled()
        return (scene, gameState)
    }

    @Test("el piso visible asentado tiene video y los vecinos sólo póster")
    func onlyTheVisibleFloorAnimates() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await makeScene(
            floors: ["alley": "cine_arresto.mov", "urban": "cine_arresto.mov"], pool: pool)
        #expect(scene.animatedFloorOrdinal == 0)
        #expect(pool.liveCount == 1)
        withExtendedLifetime(gameState) {}
    }

    @Test("empezar a scrollear baja el video a póster y asentarse en otro piso lo pasa a ése")
    func scrollingDropsToPosterAndSettlingMovesIt() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await makeScene(
            floors: ["alley": "cine_arresto.mov", "urban": "cine_arresto.mov"], pool: pool)

        scene.scrollBegan()
        #expect(scene.animatedFloorOrdinal == nil && pool.liveCount == 0)

        #expect(gameState.moveVisibleFloor(by: 1))
        scene.layoutBoard()
        #expect(scene.animatedFloorOrdinal == nil && pool.liveCount == 0, "el viaje sigue en curso")

        scene.scrollSettled()
        #expect(scene.animatedFloorOrdinal == 1 && pool.liveCount == 1)
    }

    @Test("arrastrar el dedo por la torre también deja el póster")
    func swipeDragSuspendsTheVideo() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await makeScene(floors: ["alley": "cine_arresto.mov"], pool: pool)
        scene.simulateSwipeDrag(true)
        #expect(scene.animatedFloorOrdinal == nil && pool.liveCount == 0)
        scene.simulateSwipeDrag(false)
        #expect(scene.animatedFloorOrdinal == 0 && pool.liveCount == 1)
        withExtendedLifetime(gameState) {}
    }

    @Test("sin entrada en el manifest no hay ningún video en la escena")
    func noEntryNoVideo() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = try await makeScene(floors: [:], pool: pool)
        #expect(scene.animatedFloorOrdinal == nil && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("con la política apagada el piso queda en póster")
    func stillPolicyKeepsThePoster() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (scene, gameState) = try await makeScene(floors: ["alley": "cine_arresto.mov"], pool: pool)
        #expect(scene.animatedFloorOrdinal == nil && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("los fondos reales del bundle ya tienen entrada para cada piso con su clave")
    func realBackgroundsResolve() async throws {
        let gameState = await makeGameState()
        let table = try #require(gameState.floorTable)
        for floor in table.floors {
            #expect(LoopsManifest.main.url(for: .floor(floor.background)) != nil, "\(floor.background)")
        }
    }
}
