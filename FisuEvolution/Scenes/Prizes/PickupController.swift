import SpriteKit

/// Las cajas del Paquete de la Aduana y el colchón, en el tablero (PLAN-v2 E5).
/// Colaborador de `BoardScene` como el escenario de E4b: vive en la capa de la
/// cámara, se mueve por frame y le pasa los toques a `GameState`. Lo que muestra
/// sale de `GameState.prizeAccess`, lo mismo que los chips.
@MainActor
final class PickupController {
    /// Detrás de los personajes: los empleados (campo, `fieldBaseZ` 10) y los visitantes (190) los pisan siempre.
    static let layerZ: CGFloat = PickupNode.layerZ

    let layer = SKNode()
    private weak var gameState: GameState?
    private let manifest: LoopsManifest
    private let pool: VideoPlayerPool
    private let packs: ArtPacks
    private var sceneVisible = true
    private var layout = PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    private(set) var boxes: [PickupNode] = []
    private(set) var mattress: PickupNode?
    /// El empleado que acaba de salir de una caja del tablero y dónde estaba la caja (en `layer`):
    /// la escena lo hace caminar de ahí a su lugar cuando juega la llegada (E14b B5).
    private var boxExit: (typeId: String, point: CGPoint)?
    private var reduceMotion = false

    init(gameState: GameState, manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared,
         packs: ArtPacks = .shared) {
        self.gameState = gameState
        self.manifest = manifest
        self.pool = pool
        self.packs = packs
        layer.zPosition = Self.layerZ
        layer.name = "pickups"
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat) {
        layout = PickupLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize,
                              background: layout.background, backgroundOffset: layout.backgroundOffset)
        for node in boxes { node.resize(side: layout.side) }
        mattress?.resize(side: layout.side)
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let gameState else { return }
        self.reduceMotion = reduceMotion
        let access = gameState.prizeAccess
        layer.isHidden = gameState.celebrationHidesUI
        followHorizon(of: gameState)
        syncBoxes(count: min(access.packagesWaiting, PickupLayout.maxVisibleBoxes), blocked: access.packagesBlocked)
        syncMattress(present: access.mattressReady)
        syncWaitingVideos(visible: sceneVisible && !layer.isHidden)
        for (index, box) in boxes.enumerated() {
            box.position = layout.packagePosition(index: index)
            box.update(delta: delta, reduceMotion: reduceMotion)
        }
        if let mattress {
            mattress.position = layout.mattressPosition
            mattress.update(delta: delta, reduceMotion: reduceMotion)
        }
        gameState.publishBoardPackage(boxMarker)
    }

    /// La caja de arriba, normalizada a la pantalla con el origen arriba a la izquierda (como la
    /// coordenada de XCUITest), o "" sin caja.
    private var boxMarker: String {
        guard let top = boxes.last, !layer.isHidden, layout.sceneSize.width > 0, layout.sceneSize.height > 0 else {
            return ""
        }
        let x = top.position.x / layout.sceneSize.width
        let y = 1 - top.position.y / layout.sceneSize.height
        return String(format: "%.3f,%.3f", x, y)
    }

    /// El horizonte es el del fondo del piso que se ve: si cambia, las cajas lo siguen.
    private func followHorizon(of gameState: GameState) {
        let table = gameState.content?.floorTable
        let ordinal = gameState.visibleFloorOrdinal
        let floor = table.flatMap { $0.floors.indices.contains(ordinal) ? $0[ordinal] : nil }
        layout.background = floor?.background
        layout.backgroundOffset = floor?.backgroundOffset ?? 0
    }

    /// `point` en coordenadas de `layer`. Devuelve si el toque era suyo.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, !layer.isHidden else { return false }
        if let mattress, mattress.hitTest(point) {
            gameState.mattressTapped()
            return true
        }
        guard boxes.contains(where: { $0.hitTest(point) }) else { return false }
        guard let top = boxes.last, !top.isOpening else { return true }
        switch gameState.boardPackageTapped() {
        case .openInPlace:
            top.playOpening { [weak self, weak top] in
                guard let self, let top else { return }
                self.finishOpening(top)
            }
        case .full:
            top.shake()
        case .popup, .refused:
            break
        }
        return true
    }

    /// La caja terminó de abrirse: recién ahora se gasta el paquete y el empleado sale de ahí.
    private func finishOpening(_ box: PickupNode) {
        guard let gameState, box.parent != nil else { return }
        guard case let .opened(typeId, _) = gameState.openPackageOnBoard() else {
            box.cancelOpening()
            return
        }
        boxExit = (typeId, box.position)
        boxes.removeAll { $0 === box }
        box.vanish(reduceMotion: reduceMotion)
    }

    /// Dónde estaba la caja de la que salió `typeId`, una sola vez: la llegada que juega la escena.
    func takeBoxExit(typeId: String) -> CGPoint? {
        guard let exit = boxExit, exit.typeId == typeId else { return nil }
        boxExit = nil
        return exit.point
    }

    /// La escena entra o sale del `SKView`: fuera de pantalla las esperas sueltan el cupo del pool.
    func setSceneVisible(_ visible: Bool) {
        sceneVisible = visible
        syncWaitingVideos(visible: visible && !layer.isHidden)
    }

    /// Con el rol `.icon` compartido sólo vive el más nuevo (la caja de arriba o el colchón); el resto, póster.
    private func syncWaitingVideos(visible: Bool) {
        for (index, box) in boxes.enumerated() {
            box.setWaiting(visible && index == boxes.count - 1)
        }
        mattress?.setWaiting(visible)
    }

    private func syncBoxes(count: Int, blocked: Bool) {
        while boxes.count > count { boxes.removeLast().retire() }
        while boxes.count < count {
            let box = PickupNode(kind: .package, texture: PickupArt.texture(.package), side: layout.side,
                                 waitingClip: .object("paquete_espera"), manifest: manifest, pool: pool, packs: packs)
            box.zPosition = CGFloat(boxes.count)
            layer.addChild(box)
            boxes.append(box)
        }
        for (index, box) in boxes.enumerated() {
            box.showsFull = blocked && index == boxes.count - 1
        }
    }

    private func syncMattress(present: Bool) {
        if present, mattress == nil {
            let node = PickupNode(kind: .mattress, texture: PickupArt.texture(.mattress), side: layout.side,
                                  waitingClip: .object("colchon_espera"), manifest: manifest, pool: pool, packs: packs)
            layer.addChild(node)
            mattress = node
        } else if !present, let node = mattress {
            node.retire()
            mattress = nil
        }
    }
}
