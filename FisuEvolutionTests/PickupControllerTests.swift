import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Las cajas y el colchón en el tablero")
@MainActor
struct PickupControllerTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "pickups-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    private func pickups() async -> (GameState, PickupController) {
        let gameState = await makeGameState()
        let controller = PickupController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    @Test("una caja por paquete esperando, hasta tres")
    func oneBoxPerPackage() async {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(5)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.count == 3)
        #expect(controller.mattress == nil)
    }

    @Test("tocar una caja abre un paquete, y la caja se va")
    func tappingABox() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        #expect(controller.handleTap(at: box.position))
        #expect(gameState.pendingBoardChanges.last?.origin == .package)
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.boxes.isEmpty)
    }

    @Test("sin lugar la de arriba dice LLENO, y tocarla no gasta el paquete")
    func aFullTower() async throws {
        let (gameState, controller) = await pickups()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(2)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.last?.showsFull == true)
        #expect(controller.boxes.first?.showsFull == false)
        let top = try #require(controller.boxes.last)
        #expect(controller.handleTap(at: top.position))
        #expect(gameState.packagesWaiting == 2)
    }

    @Test("el colchón aparece y tocarlo abre su popup")
    func theMattress() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        #expect(controller.handleTap(at: mattress.position))
        #expect(gameState.mattressPopup != nil)
    }

    @Test("un toque lejos no es suyo, y con la UI apagada no se ven")
    func farTapsAndCelebrations() async {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(!controller.handleTap(at: CGPoint(x: 380, y: 800)))
        gameState.celebrationHidesUI = true
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.layer.isHidden)
        gameState.celebrationHidesUI = false
    }
}
