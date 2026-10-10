import SpriteKit

/// El escenario de la escena (PLAN-v2 E4): quien entra desde un borde, habla y se
/// va por el otro. Cuelga de la capa de la cámara para que navegar pisos no lo
/// deje atrás. Todo se mueve por frame y no con `SKAction`: lo que hace se prueba
/// con un `SKNode` pelado y deltas inyectados (`StageControllerTests`).
@MainActor
final class StageController {
    /// Delante de toda la multitud (el campo llega a ~110 con sus etiquetas) y
    /// detrás del reveal (su velo arranca en 195): un ascenso tapa al visitante,
    /// nunca al revés.
    static let layerZ: CGFloat = 190
    static let fadeDuration: TimeInterval = 0.3
    static let bubblePopDuration: TimeInterval = 0.18

    let layer = SKNode()
    private weak var gameState: GameState?
    private(set) var actor: VisitorNode?
    private(set) var bubble: SpeechBubbleNode?
    private var layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    private var entersFromLeft = false
    private var bubbleAge: TimeInterval = 0
    private var textures: [String: SKTexture] = [:]

    init(gameState: GameState) {
        self.gameState = gameState
        layer.zPosition = Self.layerZ
        layer.name = "stage"
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat) {
        layout = StageLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize)
        actor?.resize(side: layout.actorSide)
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let gameState, let visit = gameState.stageVisit,
              visit.phase != .entering || gameState.showing == .visitorEncounter
        else { return clear() }
        let node = actorNode(for: visit, reduceMotion: reduceMotion)
        switch visit.phase {
        case .entering: enter(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        case .waiting: wait(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        case .leaving: leave(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        }
    }

    /// Tocar al que espera (o su globo) abre su popup. `point` en coordenadas de `layer`.
    /// Durante un reto de toques no se come nada: los toques son para los empleados.
    /// Y tiene que estar parado en su lugar: el toque que saltea la entrada deja
    /// la fase en `waiting` en el acto, pero el nodo sigue a mitad de camino hasta
    /// el próximo frame, y ese mismo toque no puede abrir además el popup.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, let actor, let visit = gameState.stageVisit,
              visit.id == actor.visitId, visit.phase == .waiting, gameState.stageChallenge == nil,
              actor.alpha >= 1, abs(actor.position.x - layout.standX) < 1,
              actor.contains(point) || (bubble?.contains(point) ?? false)
        else { return false }
        gameState.stageActorTapped(id: visit.id)
        return true
    }

    private func actorNode(for visit: StageVisit, reduceMotion: Bool) -> VisitorNode {
        if let actor, actor.visitId == visit.id { return actor }
        clear()
        entersFromLeft.toggle()
        let node = VisitorNode(visitId: visit.id, actorId: visit.actorId,
                               texture: texture(for: visit.actorId, pose: .canonical), side: layout.actorSide)
        let walksIn = visit.phase == .entering && !reduceMotion
        node.position = CGPoint(x: walksIn ? layout.offstageX(left: entersFromLeft) : layout.standX, y: layout.baselineY)
        node.alpha = visit.phase == .entering && reduceMotion ? 0 : 1
        layer.addChild(node)
        actor = node
        return node
    }

    private func enter(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        hideBubble()
        if reduceMotion {
            node.position = CGPoint(x: layout.standX, y: layout.baselineY)
            node.alpha = min(1, node.alpha + CGFloat(delta / Self.fadeDuration))
            if node.alpha >= 1 { gameState?.stageActorArrived(id: visit.id) }
            return
        }
        let target = layout.standX
        let step = StageLayout.walkSpeed * CGFloat(delta)
        let x = node.position.x < target ? min(target, node.position.x + step) : max(target, node.position.x - step)
        let arrived = x == target
        node.position = CGPoint(x: x, y: layout.baselineY + (arrived ? 0 : node.walkBob(delta: delta)))
        if arrived { gameState?.stageActorArrived(id: visit.id) }
    }

    private func wait(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        node.alpha = 1
        node.position = CGPoint(x: layout.standX, y: layout.baselineY)
        if reduceMotion { node.setScale(1) } else { node.breathe(delta: delta) }
        let talking = visit.bubble.map { !$0.isEmpty } ?? false
        let pose = texture(for: visit.actorId, pose: talking ? .talk : .canonical)
        if node.texture !== pose { node.texture = pose }
        guard talking, let text = visit.bubble else { return hideBubble() }
        let bubble = self.bubble ?? makeBubble()
        if bubble.text != text {
            bubble.setText(text, maxWidth: layout.bubbleMaxWidth)
            bubbleAge = 0
        }
        let tip = CGPoint(x: node.position.x, y: layout.baselineY + layout.actorSide + 4)
        bubble.pointTail(at: tip.x - layout.bubbleLeft(width: bubble.size.width, tipX: tip.x))
        bubble.position = tip
        bubbleAge += delta
        let progress = reduceMotion ? 1 : min(1, bubbleAge / Self.bubblePopDuration)
        bubble.setScale(CGFloat(0.6 + 0.4 * progress))
        bubble.alpha = CGFloat(progress)
    }

    private func leave(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        hideBubble()
        node.setScale(1)
        if reduceMotion {
            node.alpha = max(0, node.alpha - CGFloat(delta / Self.fadeDuration))
            if node.alpha <= 0 { gameState?.stageActorLeft(id: visit.id) }
            return
        }
        let exit = layout.offstageX(left: !entersFromLeft)
        let step = StageLayout.walkSpeed * CGFloat(delta)
        let x = node.position.x < exit ? min(exit, node.position.x + step) : max(exit, node.position.x - step)
        node.position = CGPoint(x: x, y: layout.baselineY + node.walkBob(delta: delta))
        if x == exit { gameState?.stageActorLeft(id: visit.id) }
    }

    private func makeBubble() -> SpeechBubbleNode {
        let node = SpeechBubbleNode()
        node.zPosition = 1
        layer.addChild(node)
        bubble = node
        return node
    }

    private func hideBubble() {
        bubble?.removeFromParent()
        bubble = nil
    }

    private func clear() {
        hideBubble()
        actor?.removeFromParent()
        actor = nil
    }

    /// Se pide por frame (la pose cambia con el globo): va cacheada, porque el
    /// respaldo se DIBUJA y dibujarlo 60 veces por segundo se nota.
    private func texture(for actorId: String, pose: VisitorArt.Pose) -> SKTexture {
        let key = actorId + pose.rawValue
        if let cached = textures[key] { return cached }
        let texture: SKTexture
        if let manifest = gameState?.content?.manifest,
           let art = VisitorArt.texture(for: actorId, pose: pose, manifest: manifest) {
            texture = art
        } else {
            let visitor = gameState?.content?.visitors.visitor(id: actorId)
            texture = VisitorArt.placeholderTexture(symbol: visitor?.fallbackSymbol ?? "person.fill",
                                                    tint: visitor?.fallbackTint ?? "PaletteBlue")
        }
        textures[key] = texture
        return texture
    }
}
