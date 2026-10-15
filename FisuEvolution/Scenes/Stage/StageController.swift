import EconomyKit
import SpriteKit

/// El escenario de la escena (PLAN-v2 E4, E14 C2/C6/C16, E14b B20/B21): quien entra
/// desde un borde camina hasta el medio de su piso y espera caminando despacio de lado a
/// lado; su popup se abre sólo si lo tocan, y se va por el otro lado. El visitante va por profundidad con todo lo que está parado en el piso
/// (`DepthOrder`, E14b B19); su globo de texto no se dibuja acá: se publica en
/// `bubbleFeed` y lo dibuja SwiftUI encima del HUD. Se queda en el piso donde
/// apareció (`StageVisit.floorOrdinal`; si se deja de mirar, `+Stage` lo congela,
/// E14b B7): la capa cuelga de la cámara, pero la posición de cada visita se
/// corre con el desplazamiento de la cámara para que scrollear lo deje en su piso. Todo se mueve por frame y no con `SKAction`: lo
/// que hace se prueba con un `SKNode` pelado y deltas inyectados
/// (`StageControllerTests`).
@MainActor
final class StageController {
    /// La capa no suma profundidad: el visitante va con el z de sus pies (`DepthOrder`), entre los
    /// empleados, las cajas y el colchón (E14b B19, D13).
    static let layerZ: CGFloat = 0
    /// El globo con la cara del que piden es una etiqueta: va arriba de la multitud y de lo que se
    /// arrastra, como antes, y detrás del reveal (su velo arranca en 195): un ascenso lo tapa.
    static let requestZ: CGFloat = 191
    /// Con el velo del Apagón arriba (`StageEffects`, 185) el que está en escena sale por encima de
    /// él, como siempre: el presentador se ve aunque esté oscuro. Debajo del pedido y del reveal.
    static let aboveEffectsZ: CGFloat = StageEffects.layerZ + 1
    static let fadeDuration: TimeInterval = 0.3
    static let bubblePopDuration: TimeInterval = 0.18
    static let feedbackDuration: TimeInterval = 0.35
    /// El vendedor ofendido se va a este múltiplo de la velocidad normal.
    static let offendedSpeed: CGFloat = 1.8

    /// Qué pasó con un empleado soltado sobre quien está en escena.
    enum DropOutcome: Equatable {
        case ignored, delivered, bounced
    }

    /// Lo que se recuerda de una visita congelada: su x, hacia dónde caminaba y por dónde entró.
    private struct Frozen {
        let x: CGFloat
        let heading: CGFloat
        let fromLeft: Bool
    }

    let layer = SKNode()
    private weak var gameState: GameState?
    private(set) var actor: VisitorNode?
    /// El globo de texto que se le publica a SwiftUI (`StageBubbleLayer`).
    let bubbleFeed = StageBubbleFeed()
    /// Lo que dice el globo ahora, o `nil`.
    var bubble: StageBubble? { bubbleFeed.bubble }
    /// Una celebración tapa el escenario (el velo del reveal): el globo, que va en SwiftUI por
    /// encima de todo, se esconde mientras tanto. Lo pone `BoardScene` por cuadro.
    var bubbleSuppressed = false
    /// El velo del Apagón está arriba: el visitante va por encima de él (`aboveEffectsZ`). Lo pone
    /// `BoardScene` por cuadro.
    var aboveEffects = false
    /// El texto del globo que se está mostrando: lo que dice la visita mientras espera.
    private var bubbleText: String?
    /// El globo con la cara del empleado que pide (`take`, `arrest`, `sale`).
    private(set) var request: RequestBubbleNode?
    /// El piso donde apareció la visita: ahí se queda.
    private(set) var anchorOrdinal = 0
    private var layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    private var entersFromLeft = false
    /// Hacia dónde camina mientras espera: 1 a la derecha, −1 a la izquierda (B20).
    private var heading: CGFloat = 1
    /// Dónde está parado, sin el bamboleo de una entrega rebotada: de acá sigue la caminata.
    private var walkX: CGFloat = 0
    private var requestClock: TimeInterval = 0
    private var cameraOffsetY: CGFloat?
    /// Dónde quedó cada visita que se dejó de mirar (B7, B21): al volver a su piso retoma la
    /// caminata desde ahí, sin saltar a su lugar.
    private var frozen: [UUID: Frozen] = [:]
    private var leavingOffended = false
    private var feedback: (kind: DropOutcome, age: TimeInterval)?
    private var hoveringRight = false
    private var marked = false
    private var textures: [String: SKTexture] = [:]
    private let loops: LoopsManifest
    private let pool: VideoPlayerPool
    private let packs: ArtPacks

    init(gameState: GameState, loops: LoopsManifest = .main, pool: VideoPlayerPool = .shared,
         packs: ArtPacks = .shared) {
        self.gameState = gameState
        self.loops = loops
        self.pool = pool
        self.packs = packs
        layer.zPosition = Self.layerZ
        layer.name = "stage"
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat, floorBottom: CGFloat? = nil) {
        layout = StageLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize, floorBottom: floorBottom)
        actor?.resize(side: layout.actorSide)
    }

    /// `cameraOffsetY`: cuánto subió la cámara respecto del piso 0 (`camera.y - alto/2`). Sin él, la
    /// cámara está en el piso de la visita.
    func update(delta: TimeInterval, reduceMotion: Bool, cameraOffsetY: CGFloat? = nil) {
        self.cameraOffsetY = cameraOffsetY
        // Entrando, se lo dibuja en su turno o si ya se lo ve caminar: desde ahí, otra celebración
        // que tome el turno no lo borra (B21).
        guard let gameState, let visit = gameState.stageVisit,
              visit.phase != .entering || visit.onStage || gameState.showing == .visitorEncounter
        else { return clear() }
        let node = actorNode(for: visit, reduceMotion: reduceMotion)
        anchorOrdinal = visit.floorOrdinal
        if visit.phase == .entering, !visit.onStage { gameState.stageEntranceBegan(id: visit.id) }
        switch visit.phase {
        case .entering: enter(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        case .waiting: wait(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        case .leaving: leave(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        }
        node.zPosition = aboveEffects ? Self.aboveEffectsZ : DepthOrder.z(forFeetY: feetY)
        applyFloorShift(to: node)
        publishBubble(for: visit, actor: node)
    }

    /// Corre al actor con el desplazamiento de su piso y lo apaga si ese piso no se ve.
    private func applyFloorShift(to node: VisitorNode) {
        let shift = floorShift
        node.position.y += shift
        let onScreen = node.position.y + layout.actorSide > 0 && node.position.y < layout.sceneSize.height
        node.setOnScreen(onScreen)
        request?.position.y += shift
        request?.isHidden = !onScreen
    }

    /// Lo que se corre la capa respecto de la cámara: 0 con la cámara en el piso de la visita.
    private var floorShift: CGFloat {
        let height = layout.sceneSize.height
        guard let cameraOffsetY else { return 0 }
        return CGFloat(anchorOrdinal) * height - cameraOffsetY
    }

    /// Los pies del visitante: en el medio de su piso (B20).
    private var feetY: CGFloat {
        let table = gameState?.content?.floorTable
        let floor = table.flatMap { $0.floors.indices.contains(anchorOrdinal) ? $0[anchorOrdinal] : nil }
        return layout.visitorY(background: floor?.background, backgroundOffset: floor?.backgroundOffset ?? 0)
    }

    /// Por dónde camina mientras espera, sin tocar las esquinas que le quedan a la altura de sus pies
    /// en la pantalla (con el corrimiento de su piso).
    private var walkRange: ClosedRange<CGFloat> {
        layout.walkRange(feetY: feetY + floorShift, corners: bubbleFeed.cornerFrames)
    }

    /// Tocar al que espera (o su globo del pedido) abre su popup. `point` en coordenadas de `layer`.
    /// El globo de texto se toca en SwiftUI (`tapBubble`).
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, let visit = tappableVisit,
              actor?.contains(point) == true || (request?.contains(point) ?? false)
        else { return false }
        gameState.stageActorTapped(id: visit.id)
        return true
    }

    /// El toque sobre el globo de texto (lo dibuja SwiftUI): lo mismo que tocar al visitante.
    @discardableResult
    func tapBubble() -> Bool {
        guard let gameState, let visit = tappableVisit, bubbleText != nil else { return false }
        gameState.stageActorTapped(id: visit.id)
        return true
    }

    /// La visita que acepta un toque, o `nil`. Durante un reto de toques no se come nada: los
    /// toques son para los empleados. Entrando tampoco: el toque sigue al tablero (B21). Esperando,
    /// se lo toca donde esté de su caminata (B20).
    private var tappableVisit: StageVisit? {
        guard let gameState, let actor, let visit = gameState.stageVisit,
              visit.id == actor.visitId, visit.phase == .waiting, gameState.stageChallenge == nil,
              actor.alpha >= 1
        else { return nil }
        return visit
    }

    /// El z de la escena de lo que el escenario tiene bajo `point` (coordenadas de `layer`), o `nil`.
    /// `BoardScene` lo compara con el de las cajas y los empleados: el toque es de lo de adelante
    /// (E14b B19). El globo del pedido va siempre arriba; el visitante, con el z de sus pies.
    func hitDepth(at point: CGPoint) -> CGFloat? {
        if let request, !request.isHidden, request.contains(point) {
            return layer.zPosition + request.zPosition
        }
        if let actor, !actor.isHidden, actor.contains(point) {
            return layer.zPosition + actor.zPosition
        }
        return nil
    }

    /// Un empleado soltado sobre el que pide (C16): el pedido se entrega; cualquier otro rebota. Las dos
    /// vías, popup y arrastre, llaman a la misma acción del juego. `point` en coordenadas de `layer`.
    func handleDrop(at point: CGPoint, typeId: String) -> DropOutcome {
        guard let gameState, let actor, let visit = gameState.stageVisit, visit.id == actor.visitId,
              visit.phase == .waiting, gameState.stageChallenge == nil, actor.alpha >= 1,
              let ask = requestedUnit(of: visit),
              actor.frame.insetBy(dx: -24, dy: -24).contains(point) || (request?.contains(point) ?? false)
        else { return .ignored }
        hoveringRight = false
        let outcome: DropOutcome = ask.typeId == typeId && gameState.chooseVisitOption(ask.optionId) ? .delivered : .bounced
        feedback = (outcome, 0)
        return outcome
    }

    /// El empleado en la mano pasa (o sale) por encima del que pide: el globo se agranda si es el pedido.
    func dragHover(at point: CGPoint?, typeId: String?) {
        guard let point, let typeId, let actor, let visit = gameState?.stageVisit, visit.id == actor.visitId,
              visit.phase == .waiting, let ask = requestedUnit(of: visit)
        else { hoveringRight = false; return }
        let over = actor.frame.insetBy(dx: -24, dy: -24).contains(point) || (request?.contains(point) ?? false)
        hoveringRight = over && ask.typeId == typeId
    }

    /// A quién pide el que está en escena y con qué opción se lo entregás.
    private struct RequestedUnit {
        let typeId: String
        let count: Int
        let optionId: String
        let kind: RequestBubbleNode.Kind
        let slots: [(floor: Int, slot: Int)]
    }

    private func requestedUnit(of visit: StageVisit) -> RequestedUnit? {
        guard case .visitor(let scriptId) = visit.role, let offer = visit.offer, let typeId = offer.subjectTypeId,
              let option = offer.options.first(where: { !$0.departures.isEmpty }),
              let mechanic = gameState?.content?.visitors.script(id: scriptId)?.mechanic
        else { return nil }
        let kind: RequestBubbleNode.Kind
        switch mechanic {
        case .take: kind = .take
        case .arrest: kind = .arrest
        case .sale: kind = .sale
        default: return nil
        }
        let slots = option.departures.compactMap { change -> (Int, Int)? in
            guard case let .departure(floor, slot, _) = change.kind else { return nil }
            return (floor, slot)
        }
        return RequestedUnit(typeId: typeId, count: option.departures.count, optionId: option.id, kind: kind, slots: slots)
    }

    /// Marca en el tablero a quien piden (un «!» del color del globo) mientras dure el pedido.
    func markRequested(_ nodes: [CharacterNode]) {
        let ask = gameState?.stageVisit.flatMap { $0.phase == .waiting ? requestedUnit(of: $0) : nil }
        guard ask != nil || marked else { return }
        let floor = gameState?.visibleFloorOrdinal
        let slots = Set(ask?.slots.filter { $0.floor == floor }.map(\.slot) ?? [])
        marked = false
        for node in nodes {
            let existing = node.childNode(withName: "stage.mark")
            guard let ask, slots.contains(node.cellIndex) else { existing?.removeFromParent(); continue }
            marked = true
            let badge = existing ?? makeMark(accent: ask.kind.accent, on: node)
            badge.xScale = node.xScale < 0 ? -1 : 1
        }
    }

    private func makeMark(accent: SKColor, on node: CharacterNode) -> SKNode {
        let badge = SKShapeNode(circleOfRadius: 11)
        badge.name = "stage.mark"
        badge.fillColor = accent
        badge.strokeColor = Palette.cream
        badge.lineWidth = 2.5
        badge.zPosition = 30
        badge.position = CGPoint(x: layout.cellSize * 0.3, y: layout.cellSize * 0.95)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "!"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        badge.addChild(label)
        badge.run(.repeatForever(.sequence([.scale(to: 1.18, duration: 0.5), .scale(to: 0.94, duration: 0.5)])))
        node.addChild(badge)
        return badge
    }

    private func actorNode(for visit: StageVisit, reduceMotion: Bool) -> VisitorNode {
        if let actor, actor.visitId == visit.id { return actor }
        clear()
        anchorOrdinal = visit.floorOrdinal
        let parked = Set(gameState?.stageRuntime.parked.values.map(\.id) ?? [])
        frozen = frozen.filter { $0.key == visit.id || parked.contains($0.key) }
        let kept = frozen.removeValue(forKey: visit.id)
        if let kept {
            entersFromLeft = kept.fromLeft
            heading = kept.heading
        } else {
            entersFromLeft.toggle()
            heading = entersFromLeft ? 1 : -1
        }
        leavingOffended = false
        feedback = nil
        let node = VisitorNode(visitId: visit.id, actorId: visit.actorId,
                               texture: texture(for: visit.actorId, pose: .canonical), side: layout.actorSide,
                               loops: loops, pool: pool, packs: packs)
        let walksIn = visit.phase == .entering && !reduceMotion
        let startX = walksIn ? layout.offstageX(left: entersFromLeft) : layout.standX
        walkX = kept?.x ?? startX
        node.position = CGPoint(x: walkX, y: feetY)
        node.face(heading)
        node.alpha = visit.phase == .entering && reduceMotion ? 0 : 1
        layer.addChild(node)
        actor = node
        return node
    }

    private func enter(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        hideBubble()
        hideRequest()
        showPose(on: node, visit: visit, talking: false, animated: false)
        if reduceMotion {
            walkX = layout.standX
            node.position = CGPoint(x: walkX, y: feetY)
            node.alpha = min(1, node.alpha + CGFloat(delta / Self.fadeDuration))
            if node.alpha >= 1 { gameState?.stageActorArrived(id: visit.id) }
            return
        }
        let target = layout.standX
        let step = StageLayout.walkSpeed * CGFloat(delta)
        let x = walkX < target ? min(target, walkX + step) : max(target, walkX - step)
        if x != walkX { heading = x > walkX ? 1 : -1 }
        walkX = x
        node.face(heading)
        let arrived = x == target
        node.position = CGPoint(x: x, y: feetY + (arrived ? 0 : node.walkBob(delta: delta)))
        if arrived { gameState?.stageActorArrived(id: visit.id) }
    }

    private func wait(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        node.alpha = 1
        var lift: CGFloat = 0
        var sway: CGFloat = 0
        if var current = feedback {
            current.age += delta
            let progress = CGFloat(min(1, current.age / Self.feedbackDuration))
            if current.kind == .delivered { lift = reduceMotion ? 0 : 14 * sin(progress * .pi) }
            if current.kind == .bounced { sway = reduceMotion ? 0 : 8 * sin(progress * .pi * 4) * (1 - progress) }
            feedback = progress >= 1 ? nil : current
        }
        // Sin bamboleo: los pies quedan en su línea (el globo no tiembla) y el paso lo da la respiración.
        walkX = stroll(node, delta: delta, reduceMotion: reduceMotion)
        node.position = CGPoint(x: walkX + sway, y: feetY + lift)
        if reduceMotion { node.scaleKeepingFacing(1) } else { node.breathe(delta: delta) }
        if hoveringRight, !reduceMotion { node.scaleKeepingFacing(node.yScale * 1.08) }

        if let ask = requestedUnit(of: visit) {
            hideBubble()
            showRequest(ask, above: node, delta: delta, reduceMotion: reduceMotion)
            showPose(on: node, visit: visit, talking: false, animated: true)
            return
        }
        hideRequest()
        // Con un trato abierto la frase vive en el popup y la escena queda limpia (C2).
        let talking = visit.offer == nil && (visit.bubble.map { !$0.isEmpty } ?? false)
        showPose(on: node, visit: visit, talking: talking, animated: true)
        guard talking, let text = visit.bubble else { return hideBubble() }
        if case .visitor(let scriptId) = visit.role, visit.offer == nil, text == VisitCopy.text("visit.declined"),
           let script = gameState?.content?.visitors.script(id: scriptId), VisitorPopupView.isVendor(script) {
            leavingOffended = true
        }
        bubbleText = text
    }

    /// Le dice a SwiftUI qué dice el globo y a qué cabeza apunta, ya con el corrimiento del piso.
    /// Sin texto, con su piso fuera de la pantalla o con una celebración encima, no hay globo.
    private func publishBubble(for visit: StageVisit, actor node: VisitorNode) {
        guard let text = bubbleText, visit.phase == .waiting, !node.isHidden, !bubbleSuppressed else {
            return bubbleFeed.publish(nil)
        }
        let height = layout.sceneSize.height
        let head = node.position.y + layout.actorSide + 4
        bubbleFeed.publish(StageBubble(
            visitId: visit.id,
            text: text,
            tip: CGPoint(x: Self.halfPoint(node.position.x), y: Self.halfPoint(height - head)),
            sceneSize: layout.sceneSize,
            preferredWidth: layout.bubbleMaxWidth,
            maxDrop: layout.actorSide * Self.bubbleMaxDropRatio,
            tappable: tappableVisit != nil
        ))
    }

    /// Cuánto de la cabeza puede tapar el globo para no tapar el HUD (`StageBubbleLayout`).
    static let bubbleMaxDropRatio: CGFloat = 0.2

    /// Medio punto: la cabeza que respira o se balancea no republica el globo en cada cuadro.
    private static func halfPoint(_ value: CGFloat) -> CGFloat {
        (value * 2).rounded() / 2
    }

    /// La caminata de espera (B20, D15): despacio, de lado a lado dentro de `walkRange`, dándose
    /// vuelta en los bordes. Se queda quieto mientras reacciona a una entrega o le pasan por encima
    /// al que pide, con un popup abierto y con Reduce Motion. El popup ya no sale solo (B21): se
    /// abre al tocarlo, a él, a su globo, a su tarjeta o a su aviso.
    private func stroll(_ node: VisitorNode, delta: TimeInterval, reduceMotion: Bool) -> CGFloat {
        let x = walkX
        let still = reduceMotion || feedback != nil || hoveringRight || gameState?.visitorPopup != nil
        guard !still else { return x }
        let step = StageLayout.stroll(x: x, heading: heading, range: walkRange,
                                      step: StageLayout.strollSpeed * CGFloat(delta))
        heading = step.heading
        node.face(heading)
        return step.x
    }

    private func showRequest(_ ask: RequestedUnit, above node: VisitorNode, delta: TimeInterval, reduceMotion: Bool) {
        let bubble = request.flatMap { $0.asks(for: ask.typeId, count: ask.count, kind: ask.kind) ? $0 : nil }
            ?? makeRequest(ask)
        requestClock += delta
        let beat = reduceMotion ? 0 : CGFloat(sin(requestClock * .pi * 2.2))
        bubble.setScale(1 + 0.05 * beat + (hoveringRight && !reduceMotion ? 0.25 : 0))
        bubble.position = CGPoint(x: node.position.x, y: node.position.y + layout.actorSide + 2)
    }

    private func leave(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        hideBubble()
        hideRequest()
        showPose(on: node, visit: visit, talking: false, animated: false)
        node.scaleKeepingFacing(1)
        if reduceMotion {
            node.alpha = max(0, node.alpha - CGFloat(delta / Self.fadeDuration))
            if node.alpha <= 0 { gameState?.stageActorLeft(id: visit.id) }
            return
        }
        let exit = layout.offstageX(left: !entersFromLeft)
        let speed = leavingOffended ? Self.offendedSpeed : 1
        let step = StageLayout.walkSpeed * speed * CGFloat(delta)
        let x = walkX < exit ? min(exit, walkX + step) : max(exit, walkX - step)
        if x != walkX { node.face(x > walkX ? 1 : -1) }
        walkX = x
        node.position = CGPoint(x: x, y: feetY + node.walkBob(delta: delta, stomp: leavingOffended))
        if x == exit { gameState?.stageActorLeft(id: visit.id) }
    }

    /// Parado: con globo, su clip hablado; sin globo, su clip de acción; sin clip, su pose quieta.
    /// Caminando (`animated == false`) va con la textura y el `walkBob`.
    private func showPose(on node: VisitorNode, visit: StageVisit, talking: Bool, animated: Bool) {
        let pose: VisitorArt.Pose = talking ? .talk : .canonical
        let clip = animated ? ArtClips.stageVisitor(visit.actorId, talking: talking, in: loops) : nil
        let poster: VisitorArt.Pose = clip.map { if case .visitorAction = $0 { .action } else { .talk } } ?? pose
        node.showClip(clip, poster: texture(for: visit.actorId, pose: poster))
    }

    private func hideBubble() {
        bubbleText = nil
    }

    private func makeRequest(_ ask: RequestedUnit) -> RequestBubbleNode {
        hideRequest()
        let bubble = RequestBubbleNode(kind: ask.kind, typeId: ask.typeId, count: ask.count,
                                       face: faceTexture(typeId: ask.typeId), tint: faceTint(typeId: ask.typeId))
        bubble.zPosition = Self.requestZ
        layer.addChild(bubble)
        request = bubble
        requestClock = 0
        return bubble
    }

    private func hideRequest() {
        request?.removeFromParent()
        request = nil
    }

    private func faceTexture(typeId: String) -> SKTexture? {
        AtlasCache.texture(named: "\(typeId)_face", inAtlas: "ui")
    }

    /// La cara con la pinta que el jugador le puso (sólo las de color; las de textura no cambian la cara).
    private func faceTint(typeId: String) -> SKColor? {
        guard let gameState, let skins = gameState.content?.skins else { return nil }
        let treatment = SkinResolver.treatment(for: gameState.activeSkinID(forCharacterType: typeId),
                                               characterType: typeId, config: skins)
        return SkinResolver.tintColor(for: treatment)
    }

    private func clear() {
        hideBubble()
        bubbleFeed.publish(nil)
        hideRequest()
        if let actor {
            frozen[actor.visitId] = Frozen(x: walkX, heading: heading, fromLeft: entersFromLeft)
        }
        actor?.removeClip()
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
