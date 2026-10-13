import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("El fondo del piso es sólo la foto")
@MainActor
struct FloorBackgroundStillTests {
    /// `BoardScene` guarda el `GameState` como `unowned`: el test tiene que sostenerlo.
    private func settledScene(pool: VideoPlayerPool) async -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        let scene = BoardScene(gameState: gameState, loops: .main, videoPool: pool)
        scene.layoutBoard()
        scene.scrollSettled()
        return (scene, gameState)
    }

    @Test("quieto, tras un viaje o con la política abierta, el tablero no monta ningún video de fondo")
    func settledSceneHasNoVideo() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = await settledScene(pool: pool)
        #expect(scene["//*"].allSatisfy { !($0 is SKVideoNode) } && pool.liveCount == 0)
        #expect(gameState.moveVisibleFloor(by: 1))
        scene.layoutBoard()
        scene.scrollSettled()
        #expect(scene["//*"].allSatisfy { !($0 is SKVideoNode) } && pool.liveCount == 0)
        withExtendedLifetime(gameState) {}
    }

    @Test("cada piso monta su foto como sprite")
    func everyFloorMountsItsPhoto() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (scene, gameState) = await settledScene(pool: pool)
        let sprites = scene["//*"].compactMap { $0 as? SKSpriteNode }.filter { $0.texture != nil && $0.size.width > scene.size.width }
        #expect(!sprites.isEmpty, "la foto del piso visible tiene que estar montada")
        withExtendedLifetime(gameState) {}
    }
}
