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

    /// Cuántas copias del PNG de la pieza dibuja el árbol del nodo (el póster del video cuenta).
    private func artCopies(in node: SKNode, texture: SKTexture) -> Int {
        let own = (node as? SKSpriteNode).map { $0.texture === texture ? 1 : 0 } ?? 0
        return own + node.children.reduce(0) { $0 + artCopies(in: $1, texture: texture) }
    }

    @Test("un solo nodo dibuja cada caja y el colchón, y el arte quieto cede cuando el video se ve")
    func oneNodePerPickup() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        #expect(controller.boxes.count == 2)
        for box in controller.boxes {
            #expect(artCopies(in: box, texture: PickupArt.texture(.package)) == 1)
            #expect(box.waitingVideoNode != nil)
        }
        #expect(artCopies(in: mattress, texture: PickupArt.texture(.mattress)) == 1)
        let box = try #require(controller.boxes.first)
        box.syncArt(videoAlpha: 0)
        #expect(box.staticArtAlpha == 1)
        box.syncArt(videoAlpha: 1)
        #expect(box.staticArtAlpha == 0)
    }

    @Test("la caja y el colchón van debajo de los empleados y de los visitantes, y encima de los fondos")
    func layerOrder() async {
        let (_, controller) = await pickups()
        #expect(controller.layer.zPosition == PickupController.layerZ)
        #expect(PickupController.layerZ > FloorNode.backgroundZ(ordinal: 99))
        #expect(PickupController.layerZ < BoardScene.fieldBaseZ)
        #expect(PickupController.layerZ < StageController.layerZ)
    }

    @Test("tocar una caja abre la pantalla del paquete, sin gastarlo")
    func tappingABox() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        #expect(controller.handleTap(at: box.position))
        #expect(gameState.packagePopup != nil)
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.packagesWaiting == 1)
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

    @Test("el área de toque nunca baja de 60 pt, ni con una caja chica")
    func touchTargetIsAtLeastSixty() {
        let node = PickupNode(kind: .package, texture: PickupArt.texture(.package), side: 20)
        node.position = CGPoint(x: 200, y: 300)
        #expect(node.hitTest(CGPoint(x: 200 + 29, y: 300 + 29)))
        #expect(!node.hitTest(CGPoint(x: 200 + 40, y: 300)))
    }

    @Test("las cajas se paran en el horizonte del piso que se ve, no en la barra de abajo")
    func boxesStandOnTheHorizon() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        let stage = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(box.position.y - 72 * PickupLayout.sideRatio / 2 > stage.baselineY + 72)
    }

    // MARK: con video (E8e T6)

    private func pickupsWithVideo(pool: VideoPlayerPool) async -> (GameState, PickupController) {
        let gameState = await makeGameState()
        let controller = PickupController(gameState: gameState, pool: pool)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    @Test("sólo la caja de arriba espera con video; el cupo vuelve cuando se van")
    func onlyTheTopBoxHasVideo() async {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugAddPackages(3)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.boxes.map(\.isWaiting) == [false, false, true])
        #expect(pool.liveCount == 1)
        gameState.player?.meta.engagement.packages.waiting = 0
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.boxes.isEmpty && pool.liveCount == 0)
    }

    @Test("al bajar una caja la que queda arriba toma el video, y la que se va lo suelta")
    func videoMovesToTheNewTop() async {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugAddPackages(2)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.boxes.map(\.isWaiting) == [false, true])
        gameState.player?.meta.engagement.packages.waiting = 1
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.boxes.map(\.isWaiting) == [true] && pool.liveCount == 1)
    }

    @Test("el colchón espera con video y lo suelta al irse")
    func theMattressHasVideo() async {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.mattress?.isWaiting == true && pool.liveCount == 1)
        gameState.player?.meta.engagement.treasures.waiting = false
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.mattress == nil && pool.liveCount == 0)
    }

    @Test("con la política quieta (Reduce Motion, bajo consumo): póster, y nada vivo")
    func stillPolicyKeepsThePoster() async {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.count == 1 && pool.liveCount == 0)
        #expect(controller.boxes.first?.waitingVideoNode?.videoNode == nil)
    }

    @Test("cuando una celebración tapa la UI, las cajas sueltan el cupo")
    func hiddenLayerReleasesTheLease() async {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(pool.liveCount == 1)
        gameState.celebrationHidesUI = true
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(pool.liveCount == 0)
        gameState.celebrationHidesUI = false
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(pool.liveCount == 1)
    }

    @Test("con la escena fuera del SKView las esperas sueltan el cupo, y al volver lo piden")
    func detachedSceneReleasesTheLease() async {
        let pool = VideoPlayerPool(policy: .allowAll)
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(pool.liveCount == 1)
        controller.setSceneVisible(false)
        #expect(pool.liveCount == 0)
        controller.update(delta: 1, reduceMotion: false)
        #expect(pool.liveCount == 0, "el update no lo vuelve a pedir")
        controller.setSceneVisible(true)
        #expect(pool.liveCount == 1)
    }
}
