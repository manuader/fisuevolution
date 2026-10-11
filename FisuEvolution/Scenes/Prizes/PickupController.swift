import SpriteKit

/// Las cajas del Paquete de la Aduana y el colchón, en el tablero (PLAN-v2 E5).
/// Colaborador de `BoardScene` como el escenario de E4b: vive en la capa de la
/// cámara, se mueve por frame y le pasa los toques a `GameState`. Lo que muestra
/// sale de `GameState.prizeAccess`, lo mismo que los chips.
@MainActor
final class PickupController {
    /// Delante de la multitud, detrás del visitante (190) y del reveal (195).
    static let layerZ: CGFloat = 186

    let layer = SKNode()
    private weak var gameState: GameState?
    private let manifest: LoopsManifest
    private let pool: VideoPlayerPool
    private var layout = PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    private(set) var boxes: [PickupNode] = []
    private(set) var mattress: PickupNode?

    init(gameState: GameState, manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared) {
        self.gameState = gameState
        self.manifest = manifest
        self.pool = pool
        layer.zPosition = Self.layerZ
        layer.name = "pickups"
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat) {
        layout = PickupLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize)
        for node in boxes { node.resize(side: layout.side) }
        mattress?.resize(side: layout.side)
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let gameState else { return }
        let access = gameState.prizeAccess
        layer.isHidden = gameState.celebrationHidesUI
        syncBoxes(count: min(access.packagesWaiting, PickupLayout.maxVisibleBoxes), blocked: access.packagesBlocked)
        syncMattress(present: access.mattressReady)
        syncWaitingVideos(visible: !layer.isHidden)
        for (index, box) in boxes.enumerated() {
            box.position = layout.packagePosition(index: index)
            box.update(delta: delta, reduceMotion: reduceMotion)
        }
        if let mattress {
            mattress.position = layout.mattressPosition
            mattress.update(delta: delta, reduceMotion: reduceMotion)
        }
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
        if gameState.packageTapped() == .full { boxes.last?.shake() }
        return true
    }

    /// Un solo video de espera por vez: el de la caja de arriba y el del colchón; el resto, póster.
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
                                 waitingClip: .object("paquete_espera"), manifest: manifest, pool: pool)
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
                                  waitingClip: .object("colchon_espera"), manifest: manifest, pool: pool)
            layer.addChild(node)
            mattress = node
        } else if !present, let node = mattress {
            node.retire()
            mattress = nil
        }
    }
}
