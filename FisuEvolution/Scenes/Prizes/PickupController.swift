import EconomyKit
import SpriteKit

/// Las cajas del Paquete de la Aduana y el colchón, en el tablero (PLAN-v2 E5).
/// Colaborador de `BoardScene` como el escenario de E4b: vive en la capa de la
/// cámara, se mueve por frame y le pasa los toques a `GameState`. Lo que muestra
/// sale de `GameState.prizeAccess`, lo mismo que los chips.
///
/// Cada caja es de un piso (E14b B18): se dibuja sólo en el suyo, en su lugar, y se corre con
/// la cámara como el piso (`floorShift`), así en el viaje se va con su piso en vez de flotar.
/// Su lugar es una x y una y de la superficie del piso (B22), con el z de sus pies; la que cae
/// mientras se juega entra cayendo desde arriba. El colchón del tablero también (B24): cae en un
/// lugar libre del piso que se miraba, se queda en ese piso y pide que lo toquen hasta que se abre.
@MainActor
final class PickupController {
    /// La caja abierta de la que sale un empleado (E14b B23), en coordenadas de `layer`: dónde
    /// apoya (su línea de profundidad), dónde está su borde de arriba, su ancho y su nodo, que se
    /// queda abierto hasta que el empleado salta afuera (`PickupNode.leaveEmpty`).
    struct BoxExit {
        let feet: CGPoint
        let rimY: CGFloat
        let width: CGFloat
        let node: PickupNode
    }

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
    /// Las cajas de los pisos que la cámara tiene a la vista, por ordinal, la más vieja primero.
    private var floorBoxes: [Int: [PickupNode]] = [:]
    /// Las cajas del save en el frame anterior (`nil` antes del primero). Una que no estaba cayó
    /// recién y entra cayendo; las que ya estaban (al abrir la app, al llegar a su piso) aparecen.
    private var knownBoxes: Set<PackageBox>?
    /// Las cajas ya abiertas que esperan que salga su empleado, con su piso: siguen a la cámara.
    private var openedBoxes: [(ordinal: Int, node: PickupNode)] = []
    /// El piso que se mira en este frame.
    private var visibleOrdinal = 0
    /// Cuánto subió la cámara respecto del piso 0 (`camera.y - alto/2`), como en `StageController`.
    private var cameraOffsetY: CGFloat?
    private(set) var mattress: PickupNode?
    /// Una caja abierta en el tablero y a quién trae: la escena lo hace salir de ahí cuando juega su
    /// llegada (E14b B5, B23). No retiene la caja: si se va antes, la salida ya no vale.
    private struct PendingExit {
        let typeId: String
        weak var node: PickupNode?
    }
    /// Las salidas que esperan su llegada, en el orden en que se abrieron las cajas: dos cajas
    /// abiertas seguidas no se pisan la salida.
    private var pendingExits: [PendingExit] = []
    /// Si el colchón estaba en el tablero en el frame anterior (`nil` antes del primero). El que
    /// llega mientras se juega —pagado o de regalo— entra cayendo; el que ya estaba al abrir la app
    /// aparece en su lugar.
    private var mattressWasOnBoard: Bool?
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
        for opened in openedBoxes { opened.node.resize(side: layout.side) }
        mattress?.resize(side: layout.side)
    }

    /// Las cajas del piso que se mira, la más vieja primero.
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
        syncMattress(of: gameState, present: access.mattressOnBoard, falling: mattressWasOnBoard == false)
        mattressWasOnBoard = access.mattressOnBoard
        syncWaitingVideos(visible: sceneVisible && !layer.isHidden)
        for (ordinal, nodes) in floorBoxes {
            for box in nodes {
                box.update(delta: delta, reduceMotion: reduceMotion)
                place(box, onFloor: ordinal, gameState: gameState)
            }
        }
        // La caja abierta se va sola (`PickupNode.advanceEmpty`): la que salió del árbol se suelta.
        for opened in openedBoxes { opened.node.update(delta: delta, reduceMotion: reduceMotion) }
        openedBoxes.removeAll { $0.node.parent == nil }
        pendingExits.removeAll { $0.node?.parent !== layer }
        for opened in openedBoxes { place(opened.node, onFloor: opened.ordinal, gameState: gameState) }
        if let mattress {
            // La caída espera con el pop-up del video todavía yéndose o la pantalla tapada (B24): otra
            // hoja, otro pop-up o el paso 2 de una recompensa encima (`isBoardBusy`).
            mattress.dropHeld = gameState.isBoardBusy || layer.isHidden || !sceneVisible
                || mattressOrdinal(of: gameState) != visibleOrdinal
            mattress.update(delta: delta, reduceMotion: reduceMotion)
            placeMattress(mattress, gameState: gameState)
        }
        let resting = boxes.filter { !$0.isFalling }
        gameState.publishBoardPackage(marker(at: resting.last?.position))
        gameState.publishBoardPackages(layer.isHidden ? "" : resting.map { marker(at: $0.position) }.joined(separator: ";"))
        // El de reposo, sin el salto: el marcador no cambia en cada cuadro mientras pide que lo toquen.
        gameState.publishBoardMattress(marker(at: restingMattress.map { _ in mattressRestPosition(of: gameState) }))
    }

    /// El piso del colchón del tablero: donde cayó o, sin lugar todavía, el que se mira.
    private func mattressOrdinal(of gameState: GameState) -> Int {
        gameState.mattressFloor ?? visibleOrdinal
    }

    /// El colchón quieto en su lugar del piso que se mira: el que se toca y se marca.
    private var restingMattress: PickupNode? {
        guard let mattress, !mattress.isHidden, !mattress.isFalling else { return nil }
        return mattress
    }

    /// El colchón en su lugar de su piso, como una caja (B24): los pies en su x y su y, corrido con el
    /// piso y, si cae o salta, más arriba; con el z de sus pies. Fuera de la vista de la cámara no se
    /// dibuja.
    private func placeMattress(_ node: PickupNode, gameState: GameState) {
        let ordinal = mattressOrdinal(of: gameState)
        node.isHidden = !floorsInView(of: gameState).contains(ordinal)
        let rest = mattressRestPosition(of: gameState)
        let feet = mattressFeet(onFloor: ordinal, gameState: gameState)
        // La escala por distancia (B30) achica alrededor del centro: se baja el centro para que los pies no se muevan.
        node.depthScale = depthScale(forFeetY: feet.y, onFloor: ordinal, gameState: gameState)
        let height = node.boxSize.height
        node.position = CGPoint(x: rest.x, y: rest.y - height / 2 * (1 - node.depthScale) + node.fallOffset + node.hopOffset)
        node.zPosition = DepthOrder.z(forFeetY: feet.y)
    }

    /// El centro del colchón quieto en su lugar: los pies más medio alto, corrido con su piso; sin
    /// la caída ni el salto.
    private func mattressRestPosition(of gameState: GameState) -> CGPoint {
        let ordinal = mattressOrdinal(of: gameState)
        let feet = mattressFeet(onFloor: ordinal, gameState: gameState)
        let height = mattress?.boxSize.height ?? layout.side
        return CGPoint(x: feet.x, y: feet.y + height / 2 + floorShift(ordinal))
    }

    /// Dónde apoya el colchón en su piso: su lugar del save, en la superficie de ese piso.
    private func mattressFeet(onFloor ordinal: Int, gameState: GameState) -> CGPoint {
        pickupLayout(onFloor: ordinal, gameState: gameState).packageFeet(at: gameState.mattressSpot)
    }

    /// La escala por distancia (`DepthScale`, E14b B30) de unos pies en `feetY` del piso `ordinal`.
    private func depthScale(forFeetY feetY: CGFloat, onFloor ordinal: Int, gameState: GameState) -> CGFloat {
        DepthScale.scale(forFeetY: feetY, in: pickupLayout(onFloor: ordinal, gameState: gameState).depthSpan)
    }

    /// Una caja en su lugar de su piso: los pies en su x y su y, corrida con el piso y, si está
    /// cayendo, más arriba. Mientras cae va con el z de donde va a apoyar (B19).
    private func place(_ box: PickupNode, onFloor ordinal: Int, gameState: GameState) {
        let floorLayout = pickupLayout(onFloor: ordinal, gameState: gameState)
        let feet = floorLayout.packageFeet(at: box.packageBox?.spot, unplacedIndex: box.unplacedIndex)
        // La escala por distancia (B30) achica alrededor del centro: se baja el centro para que los pies no se muevan.
        box.depthScale = depthScale(forFeetY: feet.y, onFloor: ordinal, gameState: gameState)
        let half = floorLayout.side / 2 * box.depthScale
        box.position = CGPoint(x: feet.x, y: feet.y + half + floorShift(ordinal) + box.fallOffset)
        box.zPosition = DepthOrder.z(forFeetY: feet.y)
    }

    /// La pieza normalizada a la pantalla con el origen arriba a la izquierda (como la coordenada de
    /// XCUITest), o "" sin pieza.
    private func marker(at position: CGPoint?) -> String {
        guard let position, !layer.isHidden, layout.sceneSize.width > 0, layout.sceneSize.height > 0 else {
            return ""
        }
        let x = position.x / layout.sceneSize.width
        let y = 1 - position.y / layout.sceneSize.height
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
    /// adelante (E14b B19). Una caja detrás de un empleado se toca en la parte que se ve. Una que
    /// está cayendo no cuenta: el toque es de lo que hay debajo de ella.
    func hitDepth(at point: CGPoint) -> CGFloat? {
        guard !layer.isHidden else { return nil }
        let pieces = [restingMattress].compactMap { $0 } + floorBoxes.values.joined()
        return pieces.filter { !$0.isFalling && $0.hitTest(point) }.map { layer.zPosition + $0.zPosition }.max()
    }

    /// Las cajas abiertas que esperan que salga su empleado (o se están yendo).
    var openedBoxNodes: [PickupNode] { openedBoxes.map(\.node) }

    /// `point` en coordenadas de `layer`. Devuelve si el toque era suyo.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, !layer.isHidden else { return false }
        if let mattress = restingMattress, mattress.hitTest(point) {
            if !mattress.isOpening, gameState.boardMattressTapped() {
                mattress.playOpening { [weak self, weak mattress] in
                    guard let self, let mattress else { return }
                    self.finishOpening(mattress: mattress)
                }
            }
            return true
        }
        // Primero las del piso que se mira; en un viaje, también las del piso que pasa. Entre dos
        // que se tocan bajo el dedo, la de adelante (B19).
        let floors = [visibleOrdinal] + floorBoxes.keys.filter { $0 != visibleOrdinal }
        guard let box = floors.compactMap({ frontBox(onFloor: $0, at: point) }).first else { return false }
        guard !box.isOpening else { return true }
        switch gameState.boardPackageTapped(box: box.packageBox) {
        case .openInPlace:
            box.playOpening { [weak self, weak box] in
                guard let self, let box else { return }
                self.finishOpening(box)
            }
        case .full:
            box.shake()
        case .popup, .refused:
            break
        }
        return true
    }

    /// La caja de adelante del piso `ordinal` bajo `point`, si hay. Las que caen no se tocan.
    private func frontBox(onFloor ordinal: Int, at point: CGPoint) -> PickupNode? {
        floorBoxes[ordinal]?.filter { !$0.isFalling && $0.hitTest(point) }.max { $0.zPosition < $1.zPosition }
    }

    /// La caja terminó de abrirse: recién ahora se gasta el paquete y el empleado sale de ahí. La
    /// caja queda abierta hasta que él salta afuera (B23); si la llegada no juega, se va sola.
    private func finishOpening(_ box: PickupNode) {
        guard let gameState, box.parent != nil else { return }
        guard case let .opened(typeId, _) = gameState.openPackageOnBoard(box: box.packageBox) else {
            box.cancelOpening()
            return
        }
        pendingExits.append(PendingExit(typeId: typeId, node: box))
        for ordinal in Array(floorBoxes.keys) {
            guard floorBoxes[ordinal]?.contains(where: { $0 === box }) == true else { continue }
            floorBoxes[ordinal]?.removeAll { $0 === box }
            openedBoxes.append((ordinal, box))
        }
        box.holdOpen()
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

    /// La caja abierta de la que sale `typeId` (la primera que se abrió con él), una sola vez: la
    /// llegada que juega la escena. `nil` si ya se fue (la llegada tardó más que
    /// `PickupNode.openHoldSeconds`).
    func takeBoxExit(typeId: String) -> BoxExit? {
        pendingExits.removeAll { $0.node?.parent !== layer }
        guard let index = pendingExits.firstIndex(where: { $0.typeId == typeId }),
              let node = pendingExits.remove(at: index).node
        else { return nil }
        // El centro va medio lado arriba de los pies (`place`); el arte puede ser más alto que ancho.
        // La escala por distancia (B30) achica la caja alrededor del centro: se mide la caja ya achicada.
        let size = CGSize(width: node.boxSize.width * node.depthScale, height: node.boxSize.height * node.depthScale)
        return BoxExit(feet: CGPoint(x: node.position.x, y: node.position.y - size.width / 2),
                       rimY: node.position.y + size.height / 2, width: size.width, node: node)
    }

    /// La escena entra o sale del `SKView`: fuera de pantalla las esperas sueltan el cupo del pool.
    func setSceneVisible(_ visible: Bool) {
        sceneVisible = visible
        syncWaitingVideos(visible: visible && !layer.isHidden)
    }

    /// Con el rol `.icon` compartido sólo vive el más nuevo (la caja más nueva del piso que se mira, o
    /// el colchón); el resto, póster. Las de los otros pisos, de paso en un viaje, quietas.
    private func syncWaitingVideos(visible: Bool) {
        for (ordinal, nodes) in floorBoxes {
            for (index, box) in nodes.enumerated() {
                box.setWaiting(visible && ordinal == visibleOrdinal && index == nodes.count - 1)
            }
        }
        mattress?.setWaiting(visible && restingMattress != nil)
    }

    /// Cada piso a la vista con sus cajas (hasta `maxVisibleBoxes`), cada nodo con la suya: la que
    /// sigue esperando conserva su nodo, la que se fue se retira y la nueva entra (cayendo, si cayó
    /// recién). Cada una que no entra dice LLENO.
    private func syncBoxes(of gameState: GameState) {
        let saved = Set(gameState.packageBoxes)
        let fresh = knownBoxes.map { saved.subtracting($0) } ?? []
        knownBoxes = saved
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
                    nodes.append(makeBox(box, onFloor: ordinal, falling: fresh.contains(box), gameState: gameState))
                }
            }
            spare.forEach { $0.retire() }
            var unplaced = 0
            for node in nodes {
                node.showsFull = !(node.packageBox.map(gameState.packageBoxOpenable) ?? true)
                guard node.packageBox?.spot == nil else { continue }
                node.unplacedIndex = unplaced
                unplaced += 1
            }
            floorBoxes[ordinal] = nodes.isEmpty ? nil : nodes
        }
    }

    /// Una caja nueva en el tablero. La que acaba de caer (`falling`) entra desde arriba de la
    /// pantalla hasta su lugar (B22); con Reduce Motion, aparece.
    private func makeBox(_ box: PackageBox, onFloor ordinal: Int, falling: Bool, gameState: GameState) -> PickupNode {
        let node = PickupNode(kind: .package, texture: PickupArt.texture(.package), side: layout.side,
                              waitingClip: .object("paquete_espera"), manifest: manifest, pool: pool, packs: packs)
        node.packageBox = box
        layer.addChild(node)
        if falling, !reduceMotion {
            let feet = pickupLayout(onFloor: ordinal, gameState: gameState).packageFeet(at: box.spot)
            node.drop(from: max(0, layout.sceneSize.height - feet.y))
        }
        return node
    }

    /// El colchón del tablero entra o se va. El que llega mientras se juega entra cayendo desde
    /// arriba de la pantalla, pero recién cuando el pop-up que lo pagó terminó de irse (B24); con
    /// Reduce Motion, aparece. Hasta que lo tocan, pide que lo toquen.
    private func syncMattress(of gameState: GameState, present: Bool, falling: Bool) {
        if present, mattress == nil {
            let node = PickupNode(kind: .mattress, texture: PickupArt.texture(.mattress), side: layout.side,
                                  waitingClip: .object("colchon_espera"), manifest: manifest, pool: pool, packs: packs)
            node.callsForTap = true
            layer.addChild(node)
            mattress = node
            if falling, !reduceMotion {
                let feet = mattressFeet(onFloor: mattressOrdinal(of: gameState), gameState: gameState)
                node.drop(from: max(0, layout.sceneSize.height - feet.y + layout.side),
                          after: PickupNode.popupCloseSeconds)
            }
        } else if !present, let node = mattress {
            node.retire()
            mattress = nil
        }
    }
}
