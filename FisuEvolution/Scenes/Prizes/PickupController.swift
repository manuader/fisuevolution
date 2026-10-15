import EconomyKit
import SpriteKit

/// Las cajas del Paquete de la Aduana y el colchón, en el tablero (PLAN-v2 E5).
/// Colaborador de `BoardScene` como el escenario de E4b: vive en la capa de la
/// cámara, se mueve por frame y le pasa los toques a `GameState`. Lo que muestra
/// sale de `GameState.prizeAccess`, lo mismo que los chips.
///
/// Cada caja es de un piso (E14b B18): se dibuja sólo en el suyo, en su lugar, y se corre con
/// la cámara como el piso (`floorShift`), así en el viaje se va con su piso en vez de flotar.
@MainActor
final class PickupController {
    /// La capa no suma profundidad: cada caja y el colchón van con el z de su línea de apoyo
    /// (`DepthOrder`), entre los empleados y los visitantes (E14b B19, D13).
    static let layerZ: CGFloat = PickupNode.layerZ

    let layer = SKNode()
    private weak var gameState: GameState?
    private let manifest: LoopsManifest
    private let pool: VideoPlayerPool
    private let packs: ArtPacks
    private var sceneVisible = true
    private var layout = PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    /// Las pilas de cajas de los pisos que la cámara tiene a la vista, por ordinal.
    private var floorBoxes: [Int: [PickupNode]] = [:]
    /// El piso que se mira en este frame.
    private var visibleOrdinal = 0
    /// Cuánto subió la cámara respecto del piso 0 (`camera.y - alto/2`), como en `StageController`.
    private var cameraOffsetY: CGFloat?
    private(set) var mattress: PickupNode?
    /// El empleado que acaba de salir de una caja del tablero y dónde estaba la caja (en `layer`):
    /// la escena lo hace caminar de ahí a su lugar cuando juega la llegada (E14b B5).
    private var boxExit: (typeId: String, point: CGPoint)?
    /// El colchón estaba en la columna en el frame anterior: si ahora está en el tablero, se pagó y
    /// cae desde arriba; uno de regalo (o el que ya estaba al volver a abrir la app) aparece en su lugar.
    private var mattressWasInColumn = false
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

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat, floorBottom: CGFloat? = nil) {
        layout = PickupLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize,
                              background: layout.background, backgroundOffset: layout.backgroundOffset,
                              floorBottom: floorBottom)
        for node in floorBoxes.values.joined() { node.resize(side: layout.side) }
        mattress?.resize(side: layout.side)
    }

    /// Las cajas del piso que se mira, la de abajo primero.
    var boxes: [PickupNode] { floorBoxes[visibleOrdinal] ?? [] }

    /// Las cajas que se dibujan en el piso `ordinal` (vacío si la cámara no lo tiene a la vista).
    func boxes(onFloor ordinal: Int) -> [PickupNode] { floorBoxes[ordinal] ?? [] }

    /// `cameraOffsetY`: cuánto subió la cámara respecto del piso 0 (`camera.y - alto/2`). Sin él, la
    /// cámara está quieta en el piso que se mira.
    func update(delta: TimeInterval, reduceMotion: Bool, cameraOffsetY: CGFloat? = nil) {
        guard let gameState else { return }
        self.reduceMotion = reduceMotion
        self.cameraOffsetY = cameraOffsetY
        visibleOrdinal = gameState.visibleFloorOrdinal
        let access = gameState.prizeAccess
        layer.isHidden = gameState.celebrationHidesUI
        followHorizon(of: gameState)
        syncBoxes(of: gameState)
        syncMattress(present: access.mattressOnBoard, falling: mattressWasInColumn)
        mattressWasInColumn = access.mattressReady
        syncWaitingVideos(visible: sceneVisible && !layer.isHidden)
        for (ordinal, nodes) in floorBoxes {
            let floorLayout = pickupLayout(onFloor: ordinal, gameState: gameState)
            let place = nodes.first?.packageBox?.x
            let shift = floorShift(ordinal)
            // La pila entera apoya en la línea de la de abajo: se ordena como una sola pieza y,
            // adentro, cada caja va delante de la que pisa.
            let stackZ = DepthOrder.z(forFeetY: floorLayout.baselineY)
            for (index, box) in nodes.enumerated() {
                let spot = floorLayout.packagePosition(index: index, at: place)
                box.position = CGPoint(x: spot.x, y: spot.y + shift)
                box.zPosition = stackZ + CGFloat(index) * DepthOrder.stackStep
                box.update(delta: delta, reduceMotion: reduceMotion)
            }
        }
        if let mattress {
            mattress.update(delta: delta, reduceMotion: reduceMotion)
            let spot = layout.mattressPosition
            mattress.position = CGPoint(x: spot.x, y: spot.y + mattress.fallOffset)
            // Mientras cae va con el z de donde va a apoyar, no con el de la altura de la caída.
            mattress.zPosition = DepthOrder.z(forFeetY: layout.baselineY)
        }
        gameState.publishBoardPackage(marker(of: boxes.last))
        gameState.publishBoardMattress(marker(of: mattress?.isFalling == false ? mattress : nil))
    }

    /// La pieza normalizada a la pantalla con el origen arriba a la izquierda (como la coordenada de
    /// XCUITest), o "" sin pieza.
    private func marker(of node: PickupNode?) -> String {
        guard let node, !layer.isHidden, layout.sceneSize.width > 0, layout.sceneSize.height > 0 else {
            return ""
        }
        let x = node.position.x / layout.sceneSize.width
        let y = 1 - node.position.y / layout.sceneSize.height
        return String(format: "%.3f,%.3f", x, y)
    }

    /// El horizonte del colchón es el del fondo del piso que se ve: si cambia, lo sigue.
    private func followHorizon(of gameState: GameState) {
        layout = pickupLayout(onFloor: gameState.visibleFloorOrdinal, gameState: gameState)
    }

    /// Las cajas de cada piso se paran en el horizonte del fondo de SU piso.
    private func pickupLayout(onFloor ordinal: Int, gameState: GameState) -> PickupLayout {
        let table = gameState.content?.floorTable
        let floor = table.flatMap { $0.floors.indices.contains(ordinal) ? $0[ordinal] : nil }
        var floorLayout = layout
        floorLayout.background = floor?.background
        floorLayout.backgroundOffset = floor?.backgroundOffset ?? 0
        return floorLayout
    }

    /// Lo que se corre un piso respecto de la cámara: 0 con la cámara en ese piso.
    private func floorShift(_ ordinal: Int) -> CGFloat {
        let height = layout.sceneSize.height
        let camera = cameraOffsetY ?? CGFloat(visibleOrdinal) * height
        return CGFloat(ordinal) * height - camera
    }

    /// Los pisos que la cámara tiene a la vista: el que se mira y, en un viaje, los dos entre los
    /// que está pasando.
    private func floorsInView(of gameState: GameState) -> Set<Int> {
        let count = gameState.content?.floorTable.count ?? 0
        let height = layout.sceneSize.height
        var floors: Set<Int> = [visibleOrdinal]
        if let cameraOffsetY, height > 0 {
            let position = cameraOffsetY / height
            floors.insert(Int(position.rounded(.down)))
            floors.insert(Int(position.rounded(.up)))
        }
        return floors.filter { $0 >= 0 && $0 < max(count, 1) }
    }

    /// El z de la escena de la pieza que está bajo `point` (coordenadas de `layer`), o `nil`.
    /// `BoardScene` lo compara con el del visitante y el de los empleados: el toque es de lo de
    /// adelante (E14b B19). Una caja detrás de un empleado se toca en la parte que se ve.
    func hitDepth(at point: CGPoint) -> CGFloat? {
        guard !layer.isHidden else { return nil }
        let pieces = [mattress].compactMap { $0 } + floorBoxes.values.joined()
        return pieces.filter { $0.hitTest(point) }.map { layer.zPosition + $0.zPosition }.max()
    }

    /// `point` en coordenadas de `layer`. Devuelve si el toque era suyo.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, !layer.isHidden else { return false }
        if let mattress, mattress.hitTest(point) {
            if !mattress.isOpening, gameState.boardMattressTapped() {
                mattress.playOpening { [weak self, weak mattress] in
                    guard let self, let mattress else { return }
                    self.finishOpening(mattress: mattress)
                }
            }
            return true
        }
        // Primero las del piso que se mira; en un viaje, también las del piso que pasa.
        let floors = [visibleOrdinal] + floorBoxes.keys.filter { $0 != visibleOrdinal }
        let stacks = floors.compactMap { floorBoxes[$0] }
        guard let stack = stacks.first(where: { nodes in nodes.contains { node in node.hitTest(point) } }) else {
            return false
        }
        guard let top = stack.last, !top.isOpening else { return true }
        switch gameState.boardPackageTapped(box: top.packageBox) {
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
        guard case let .opened(typeId, _) = gameState.openPackageOnBoard(box: box.packageBox) else {
            box.cancelOpening()
            return
        }
        boxExit = (typeId, box.position)
        for ordinal in Array(floorBoxes.keys) { floorBoxes[ordinal]?.removeAll { $0 === box } }
        box.vanish(reduceMotion: reduceMotion)
    }

    /// El colchón terminó de abrirse en el tablero (E14b B6, D3): recién ahora se sortea y se acredita,
    /// sale el pop-up del premio y el colchón abierto se desvanece.
    private func finishOpening(mattress node: PickupNode) {
        guard let gameState, node.parent != nil else { return }
        guard gameState.openMattressOnBoard() != nil else {
            node.cancelOpening()
            return
        }
        if mattress === node { mattress = nil }
        node.vanish(reduceMotion: reduceMotion)
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

    /// Con el rol `.icon` compartido sólo vive el más nuevo (la caja de arriba del piso que se mira, o
    /// el colchón); el resto, póster. Las de los otros pisos, de paso en un viaje, quietas.
    private func syncWaitingVideos(visible: Bool) {
        for (ordinal, nodes) in floorBoxes {
            for (index, box) in nodes.enumerated() {
                box.setWaiting(visible && ordinal == visibleOrdinal && index == nodes.count - 1)
            }
        }
        mattress?.setWaiting(visible)
    }

    /// Cada piso a la vista con sus cajas (hasta `maxVisibleBoxes`), cada nodo con la suya: la que
    /// sigue esperando conserva su nodo, la que se fue se retira y la nueva entra.
    private func syncBoxes(of gameState: GameState) {
        let floors = floorsInView(of: gameState)
        let stale = floorBoxes.keys.filter { !floors.contains($0) }
        for ordinal in stale {
            floorBoxes.removeValue(forKey: ordinal)?.forEach { $0.retire() }
        }
        for ordinal in floors {
            let wanted = Array(gameState.visiblePackageBoxes(onFloor: ordinal).prefix(PickupLayout.maxVisibleBoxes))
            var spare = floorBoxes[ordinal] ?? []
            var nodes: [PickupNode] = []
            for box in wanted {
                if let index = spare.firstIndex(where: { $0.packageBox == box }) {
                    nodes.append(spare.remove(at: index))
                } else {
                    nodes.append(makeBox(box))
                }
            }
            spare.forEach { $0.retire() }
            for (index, node) in nodes.enumerated() {
                let isTop = index == nodes.count - 1
                node.showsFull = isTop && !(node.packageBox.map(gameState.packageBoxOpenable) ?? true)
            }
            floorBoxes[ordinal] = nodes.isEmpty ? nil : nodes
        }
    }

    private func makeBox(_ box: PackageBox) -> PickupNode {
        let node = PickupNode(kind: .package, texture: PickupArt.texture(.package), side: layout.side,
                              waitingClip: .object("paquete_espera"), manifest: manifest, pool: pool, packs: packs)
        node.packageBox = box
        layer.addChild(node)
        return node
    }

    private func syncMattress(present: Bool, falling: Bool) {
        if present, mattress == nil {
            let node = PickupNode(kind: .mattress, texture: PickupArt.texture(.mattress), side: layout.side,
                                  waitingClip: .object("colchon_espera"), manifest: manifest, pool: pool, packs: packs)
            layer.addChild(node)
            mattress = node
            if falling, !reduceMotion {
                node.drop(from: max(0, layout.sceneSize.height - layout.mattressPosition.y))
            }
        } else if !present, let node = mattress {
            node.retire()
            mattress = nil
        }
    }
}
