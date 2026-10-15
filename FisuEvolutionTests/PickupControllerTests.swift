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
        gameState.debugSpawnMattress(onBoard: true)
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

    /// E14b B19 (D13): ya no van en una capa fija detrás de todos. La capa no suma z; cada pieza
    /// lleva el de su línea de apoyo (`DepthOrderTests` prueba el orden contra los demás).
    @Test("la caja y el colchón van por profundidad y encima de los fondos")
    func layerOrder() async throws {
        let (gameState, controller) = await pickups()
        #expect(controller.layer.zPosition == PickupController.layerZ)
        #expect(PickupController.layerZ == 0)
        gameState.debugAddPackages(3)
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        for box in controller.boxes {
            #expect(box.zPosition > FloorNode.backgroundZ(ordinal: 99))
        }
        #expect(mattress.zPosition > FloorNode.backgroundZ(ordinal: 99))
    }

    // MARK: E14b B22: cada caja en su lugar del piso

    /// La superficie del piso que se mira, como la arma el controlador.
    private func floorLayout(_ gameState: GameState) throws -> PickupLayout {
        let floor = try #require(gameState.visibleFloorDef)
        return PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72,
                            background: floor.background, backgroundOffset: floor.backgroundOffset)
    }

    @Test("cada caja está en su x y su y del save, con el z que le da la profundidad de sus pies")
    func eachBoxStandsOnItsSpot() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(3)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let layout = try floorLayout(gameState)
        #expect(controller.boxes.count == 3)
        for node in controller.boxes {
            let box = try #require(node.packageBox)
            let spot = try #require(box.spot, "cada caja sorteada tiene x e y")
            let feet = layout.packageFeet(at: spot)
            #expect(abs(node.position.x - feet.x) < 0.01, "en su x")
            #expect(abs(node.position.y - (feet.y + layout.side / 2)) < 0.01, "en su y")
            #expect(abs(node.zPosition - DepthOrder.z(forFeetY: feet.y)) < 0.0005, "con el z de sus pies")
        }
        let feet = controller.boxes.map { $0.position.y }
        #expect(Set(feet.map { Int($0) }).count > 1 || Set(controller.boxes.map { Int($0.position.x) }).count > 1,
                "no caen todas en el mismo punto")
    }

    @Test("dos cajas que se tocan bajo el dedo: se abre la de adelante")
    func theFrontBoxTakesTheTap() async throws {
        let (gameState, controller) = await pickups()
        let floor = 0
        let typeId = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.meta.engagement.packages.boxes = [
            PackageBox(floor: floor, typeId: typeId, x: 0.5, y: 0.2),
            PackageBox(floor: floor, typeId: typeId, x: 0.52, y: 0.25),
        ]
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let front = try #require(controller.boxes.first, "la de y más chica va adelante")
        let back = try #require(controller.boxes.last)
        #expect(front.zPosition > back.zPosition)
        #expect(controller.handleTap(at: CGPoint(x: (front.position.x + back.position.x) / 2, y: front.position.y)))
        #expect(gameState.packagePopup?.box == front.packageBox)
    }

    @Test("la que cae mientras se juega entra cayendo desde arriba; las que ya estaban, no")
    func aNewBoxFallsIn() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: false)
        let first = try #require(controller.boxes.first)
        #expect(!first.isFalling, "la que estaba al abrir la app aparece en su lugar")
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: false)
        let fresh = try #require(controller.boxes.last)
        #expect(fresh !== first)
        #expect(fresh.isFalling && fresh.fallOffset > 0, "cae desde arriba")
        #expect(!gameState.boardPackagesMarker.contains(";"), "mientras cae no se toca: el marcador trae sólo la quieta")
        let airborne = fresh.position.y
        run(controller, seconds: 1)
        #expect(!fresh.isFalling && fresh.position.y < airborne, "llegó a su lugar")
        #expect(gameState.boardPackagesMarker.split(separator: ";").count == 2)

        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: true)
        #expect(controller.boxes.allSatisfy { !$0.isFalling }, "con Reduce Motion aparece")
    }

    @Test("al cambiar de piso y volver, cada caja vuelve a estar en el mismo lugar")
    func boxesKeepTheirSpotAcrossFloors() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugDropPackage(onFloor: "alley", count: 3)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let before = controller.boxes.map(\.position)
        #expect(before.count == 3)
        gameState.setVisibleFloor(2)
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes(onFloor: 0).isEmpty)
        gameState.setVisibleFloor(0)
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.map(\.position) == before)
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

    @Test("sin lugar cada caja dice LLENO, y tocarla no gasta el paquete")
    func aFullTower() async throws {
        let (gameState, controller) = await pickups()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(2)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.count == 2)
        #expect(controller.boxes.allSatisfy(\.showsFull))
        let top = try #require(controller.boxes.last)
        #expect(controller.handleTap(at: top.position))
        #expect(gameState.packagesWaiting == 2)
    }

    @Test("el colchón de la columna no está en el tablero; pagado, cae, y tocarlo lo abre ahí y sale el premio (E14b B6)")
    func theMattress() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.mattress == nil, "en la columna, sólo en la columna (D3)")
        #expect(gameState.payMattress())
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        #expect(gameState.mattressPopup == nil)
        // Con la política quieta los clips de la sacudida y la apertura terminan en el acto.
        #expect(controller.handleTap(at: mattress.position))
        let outcome = try #require(gameState.mattressPopup?.outcome, "abierto en el tablero, el pop-up del premio sale siempre")
        #expect(gameState.mattressPopup?.openedOnBoard == true)
        #expect(!outcome.rewards.isEmpty)
        #expect(controller.mattress == nil, "el colchón abierto se va del tablero")
        #expect(!gameState.mattressInPlay)
    }

    @Test("con otro popup arriba, tocar el colchón del tablero no lo abre")
    func theBoardMattressWaits() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        gameState.openWheel()
        #expect(controller.handleTap(at: mattress.position))
        #expect(gameState.mattressPopup == nil)
        #expect(gameState.mattressOnBoard)
        #expect(!mattress.isOpening)
    }

    /// Avanza el controlador `seconds` en cuadros de 60 Hz, como la escena.
    private func run(_ controller: PickupController, seconds: TimeInterval, reduceMotion: Bool = false) {
        for _ in 0..<Int((seconds * 60).rounded(.up)) {
            controller.update(delta: 1.0 / 60, reduceMotion: reduceMotion)
        }
    }

    @Test("el pagado espera que el pop-up se vaya y recién ahí cae; el que ya estaba al abrir la app aparece ahí mismo")
    func thePaidOneFalls() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: false)
        gameState.mattressTapped()
        gameState.mattressVideoWatched()
        #expect(gameState.mattressOnBoard && gameState.mattressPopup == nil)
        // El pop-up del video se está yendo: el colchón todavía no está a la vista.
        controller.update(delta: 0.016, reduceMotion: false)
        let falling = try #require(controller.mattress)
        #expect(falling.isAwaitingDrop && falling.alpha == 0, "no cae bajo el pop-up que se cierra")
        #expect(gameState.boardMattressMarker.isEmpty, "mientras cae no se toca")
        #expect(controller.hitDepth(at: falling.position) == nil)
        run(controller, seconds: PickupNode.popupCloseSeconds - 0.1)
        #expect(falling.isAwaitingDrop, "espera lo que tarda el pop-up en irse")
        run(controller, seconds: 0.15)
        #expect(!falling.isAwaitingDrop && falling.isFalling && falling.fallOffset > 0, "ahora sí cae, a la vista")
        #expect(falling.alpha > 0)
        let airborne = falling.position.y
        run(controller, seconds: PickupNode.fallSeconds + 0.1)
        #expect(!falling.isFalling && falling.fallOffset == 0)
        #expect(falling.position.y < airborne, "cayó")
        #expect(gameState.boardMattressMarker.contains(","))

        let (giftState, giftController) = await pickups()
        giftState.debugSpawnMattress(onBoard: true)
        giftState.refreshPrizeAccess()
        giftController.update(delta: 0.016, reduceMotion: false)
        let gift = try #require(giftController.mattress)
        #expect(!gift.isFalling && gift.fallOffset == 0)
    }

    @Test("con un pop-up arriba la caída no arranca: espera a que se vaya")
    func theDropWaitsForThePopup() async throws {
        let (gameState, controller) = await pickups()
        controller.update(delta: 0.016, reduceMotion: false)
        gameState.debugSpawnMattress(onBoard: true, gifted: true)
        gameState.refreshPrizeAccess()
        gameState.mattressPopup = MattressPopup(extraOnly: true)
        run(controller, seconds: 2)
        let mattress = try #require(controller.mattress)
        #expect(mattress.isAwaitingDrop, "de regalo, mientras se juega, también cae; pero no bajo un pop-up")
        gameState.closeMattressPopup()
        run(controller, seconds: PickupNode.popupCloseSeconds + PickupNode.fallSeconds + 0.2)
        #expect(!mattress.isFalling)
        #expect(gameState.boardMattressMarker.contains(","))
    }

    @Test("el primer cuadro después del anuncio, con un delta enorme, no se come la caída")
    func aHugeDeltaDoesNotSkipTheFall() async throws {
        let (gameState, controller) = await pickups()
        controller.update(delta: 0.016, reduceMotion: false)
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: false)
        run(controller, seconds: PickupNode.popupCloseSeconds + 0.05)
        let mattress = try #require(controller.mattress)
        #expect(mattress.isFalling && !mattress.isAwaitingDrop)
        controller.update(delta: 3, reduceMotion: false)
        #expect(mattress.isFalling && mattress.fallOffset > 0, "un cuadro de 3 s avanza a lo sumo un paso")
    }

    @Test("cae en el piso que se mira, en su lugar libre de adelante, delante de las hileras, y se queda en ese piso")
    func itLandsOnTheVisibleFloorInFront() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        let floor = try #require(gameState.mattressFloor)
        let spot = try #require(gameState.mattressSpot)
        #expect(floor == gameState.visibleFloorOrdinal)
        #expect(spot.y < GameState.mattressBackDepth.lowerBound, "en la mitad de adelante")
        let layout = try floorLayout(gameState)
        let feet = layout.packageFeet(at: spot)
        #expect(abs(mattress.position.x - feet.x) < 0.01)
        #expect(abs(mattress.position.y - (feet.y + mattress.boxSize.height / 2)) < 0.01, "los pies en su lugar")
        #expect(abs(mattress.zPosition - DepthOrder.z(forFeetY: feet.y)) < 0.0005, "con el z de sus pies (B19)")
        #expect(mattress.zPosition >= DepthOrder.z(forFeetY: layout.baselineY), "nunca detrás de la hilera de atrás")
        // El centro del colchón es suyo: el toque de ahí lo abre (lo que pide el UI test de B24).
        #expect(controller.hitDepth(at: mattress.position) == mattress.zPosition)
        #expect(mattress.callsForTap, "pide que lo toquen")
    }

    @Test("una caja nueva no cae encima del colchón, ni el colchón encima de una caja")
    func boxesKeepClearOfTheMattress() async throws {
        let (gameState, _) = await pickups()
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress(onBoard: true)
        let floor = try #require(gameState.mattressFloor)
        let spot = try #require(gameState.mattressSpot)
        let areas = gameState.packageAreas(onFloor: floor)
        #expect(!areas.isEmpty)
        #expect(PackagePlacer.crowding(of: spot, among: [], in: areas) >= Double(areas.count), "su lugar está ocupado")
        let boxes = gameState.packageBoxes.filter { $0.floor == floor }.compactMap(\.spot)
        let bare = PickupLayout.placementAreas(background: gameState.visibleFloorDef?.background,
                                               backgroundOffset: gameState.visibleFloorDef?.backgroundOffset ?? 0)
        #expect(PackagePlacer.crowding(of: spot, among: boxes, in: bare.map { $0.keepingToTheFront(GameState.mattressBackDepth) }) == 0,
                "cayó en un lugar libre de las cajas y adelante")
    }

    @Test("con Reduce Motion el pagado no cae: aparece en su lugar")
    func reduceMotionDoesNotFall() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: true)
        gameState.payMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.016, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        #expect(!mattress.isFalling && mattress.fallOffset == 0)
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

    @Test("las cajas se paran entre el horizonte del piso que se ve y la barra de abajo, sin tocarla")
    func boxesStandOnTheFloor() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(2)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let layout = try floorLayout(gameState)
        let stage = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        for box in controller.boxes {
            let feet = box.position.y - layout.side / 2
            #expect(feet >= stage.groundFloorY - 0.01, "arriba de la barra")
            #expect(feet <= layout.baselineY + 0.01, "no más atrás que el horizonte")
        }
    }

    // MARK: E14b B23: el empleado sale de adentro de la caja

    /// Abre en el tablero la caja de un paquete y devuelve la caja, dónde estaba y a quién trae.
    private func openOnBoard(_ gameState: GameState, _ controller: PickupController) throws -> (PickupNode, CGPoint, String) {
        let box = try #require(controller.boxes.last)
        let spot = box.position
        #expect(controller.handleTap(at: spot))
        let typeId = try #require(gameState.pendingBoardChanges.last { $0.origin == .package }.flatMap { change -> String? in
            if case let .arrival(typeId) = change.kind { return typeId }
            return nil
        })
        return (box, spot, typeId)
    }

    @Test("la caja abierta espera a su empleado: no se toca, deja la salida una sola vez y se va sola")
    func theOpenedBoxWaitsAndLeaves() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.player?.meta.engagement.packageIntroSeen = true
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let (box, spot, typeId) = try openOnBoard(gameState, controller)
        #expect(controller.boxes.isEmpty, "ya no es una caja que espera")
        #expect(controller.openedBoxNodes.contains { $0 === box })
        #expect(box.parent === controller.layer, "abierta, se queda hasta que salga el empleado")
        #expect(controller.hitDepth(at: spot) == nil, "no se come los toques: el que toca ahí agarra lo de atrás")
        #expect(!controller.handleTap(at: spot))
        let exit = try #require(controller.takeBoxExit(typeId: typeId))
        #expect(exit.node === box)
        #expect(abs(exit.feet.x - spot.x) < 0.01)
        #expect(exit.rimY > exit.feet.y)
        #expect(controller.takeBoxExit(typeId: typeId) == nil, "se usa una sola vez")
        // El empleado saltó: la caja vacía se queda un instante y se va, por frame (sin `SKView`).
        box.leaveEmpty()
        controller.update(delta: PickupNode.emptyLingerSeconds + 0.01, reduceMotion: false)
        #expect(box.parent === controller.layer && box.isCollapsing, "se está yendo")
        controller.update(delta: PickupNode.collapseSeconds + 0.01, reduceMotion: false)
        #expect(box.parent == nil, "se fue sola")
        #expect(controller.openedBoxNodes.isEmpty, "y el controlador la soltó")
    }

    @Test("si la llegada no juega, la caja abierta se va sola igual y su salida deja de valer")
    func theOpenedBoxLeavesWithoutItsEmployee() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.player?.meta.engagement.packageIntroSeen = true
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let (box, _, typeId) = try openOnBoard(gameState, controller)
        controller.update(delta: PickupNode.openHoldSeconds + 0.01, reduceMotion: true)
        controller.update(delta: PickupNode.collapseSeconds + 0.01, reduceMotion: true)
        #expect(box.parent == nil)
        #expect(controller.openedBoxNodes.isEmpty)
        #expect(controller.takeBoxExit(typeId: typeId) == nil, "la caja ya no está: no hay de dónde salir")
    }

    @Test("dos cajas abiertas seguidas: cada llegada sale de la suya, en el orden en que se abrieron")
    func twoOpenedBoxesKeepTheirExits() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let (gameState, controller) = await pickupsWithVideo(pool: pool)
        gameState.player?.meta.engagement.packageIntroSeen = true
        gameState.debugAddPackages(2)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let (first, _, firstType) = try openOnBoard(gameState, controller)
        controller.update(delta: 0.01, reduceMotion: true)
        let (second, _, secondType) = try openOnBoard(gameState, controller)
        #expect(first !== second)
        let firstExit = try #require(controller.takeBoxExit(typeId: firstType))
        let secondExit = try #require(controller.takeBoxExit(typeId: secondType))
        #expect(firstExit.node === first, "la primera llegada sale de la primera caja")
        #expect(secondExit.node === second, "la segunda no pisó la salida de la primera")
    }

    @Test("una caja que está cayendo no se come el toque: no cuenta para la profundidad ni se abre")
    func aFallingBoxDoesNotEatTheTouch() async throws {
        let (gameState, controller) = await pickups()
        gameState.player?.meta.engagement.packageIntroSeen = true
        controller.update(delta: 0.01, reduceMotion: false)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 0.01, reduceMotion: false)
        let box = try #require(controller.boxes.first)
        #expect(box.isFalling, "cayó mientras se juega: entra desde arriba")
        #expect(controller.hitDepth(at: box.position) == nil)
        #expect(!controller.handleTap(at: box.position), "el toque sigue a lo de atrás")
        #expect(gameState.packagesWaiting == 1, "no se abrió")
        run(controller, seconds: PickupNode.fallSeconds + 0.1)
        #expect(!box.isFalling)
        #expect(controller.hitDepth(at: box.position) != nil, "ya en el piso, se toca")
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
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: false)
        #expect(controller.mattress?.isWaiting == true && pool.liveCount == 1)
        gameState.player?.meta.engagement.treasures.phase = .none
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
