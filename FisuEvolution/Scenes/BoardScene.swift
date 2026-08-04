import EconomyKit
import SpriteKit
import UIKit

/// The merge board. Owns the entire per-frame world (bible §4.1): the income tick
/// and all gestures run here; SwiftUI only sees throttled projections. Reads state
/// from `GameState` and renders the grid + character nodes.
final class BoardScene: SKScene {
    private unowned let gameState: GameState
    private let renderer = PlaceholderRenderer()
    private let pool = CharacterNodePool()
    private let particles = ParticlePool()
    private let cameraNode = SKCameraNode()
    /// Overlay fijo a la cámara: reveal, flash y textos no se quedan atrás al
    /// cambiar de piso.
    private let cameraOverlay = SKNode()

    /// Campo de juego (estilo Cow Evolution): fondo de escena + personajes
    /// parados en anclas orgánicas — sin grilla visible.
    private let backgroundLayer = SKNode()
    private let fieldNode = SKNode()
    private var floorNodes: [Int: FloorNode] = [:]
    private var characterNodes: [Int: CharacterNode] = [:]
    /// Qué está mostrando cada slot, para reconciliar en vez de reconstruir.
    /// Se mantiene en paralelo a `characterNodes` y sólo `renderPlacements`
    /// escribe en los dos.
    private var renderedUnits: [Int: RenderedUnit] = [:]
    private var lastLayoutSize: CGSize = .zero
    private var renderedBoardVersion = -1
    private var displayedFloorOrdinal = -1

    // Geometría del campo, cacheada por layoutBoard.
    private var boardColumns = 0
    private var boardRows = 0
    private var cellSize: CGFloat = 0
    /// Punto de anclaje por cellIndex: grilla lógica + jitter determinístico.
    private var anchorPoints: [CGPoint] = []

    // Drag state
    private var dragNode: CharacterNode?
    private var dragOriginCell = -1
    private var isDragging = false
    private var emptyTouchStart: CGPoint?
    private static let dragThreshold: CGFloat = 10
    private static let longPressKey = "longPress"
    private static let ascentDuration: TimeInterval = 0.7
    private static let ascentDistanceRatio: CGFloat = 0.78
    private static let specialNodePrefix = "special."

    // FTUE hint
    private var hintNode: SKShapeNode?
    private var hintTargetCell = -1

    // Tick state
    private var lastUpdateTime: TimeInterval = 0
    private var frameCounter = 0
    /// 60 fps / 8 ≈ 8 Hz HUD flush (Docs/concurrency-conventions.md regla 2).
    private static let hudFlushEveryNFrames = 8

    /// Vertical insets leaving room for the SwiftUI HUD above and controls below.
    private static let topInset: CGFloat = 130
    private static let bottomInset: CGFloat = 110
    private static let horizontalInset: CGFloat = 16

    init(gameState: GameState) {
        self.gameState = gameState
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = Palette.cream
        addChild(backgroundLayer)
        addChild(fieldNode)
        cameraNode.addChild(cameraOverlay)
        addChild(cameraNode)
        camera = cameraNode
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BoardScene is never decoded")
    }

    override func didMove(to view: SKView) {
        layoutBoard()
        particles.preheat()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Called during init too, before children exist — only relayout when live.
        guard scene?.view != nil, size != lastLayoutSize else { return }
        layoutBoard()
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        // El primer frame (o el primero tras resume) trae un delta gigante;
        // IncomeTicker lo clampa (el offline ya cubrió ese tiempo).
        let delta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        gameState.tick(delta: delta)

        frameCounter += 1
        if frameCounter >= Self.hudFlushEveryNFrames {
            frameCounter = 0
            gameState.flushHUD()
        }

        if gameState.boardVersion != renderedBoardVersion {
            layoutBoard()
        }

        updateFTUEHint()
    }

    /// Anillo pulsante sobre la unidad a tapear (hint 1) o sobre una del par
    /// mergeable (hint 3). El hint del botón de spawn vive en SwiftUI.
    private func updateFTUEHint() {
        var targetCell = -1
        // `visiblePlacements` construye un array nuevo: pedirlo antes de saber si
        // hay hint activo era una allocation por frame para siempre, incluso con
        // el tutorial terminado.
        if gameState.showTapHint {
            targetCell = gameState.visiblePlacements.first?.slot ?? -1
        } else if gameState.showMergeHint {
            var byType: [String: Int] = [:]
            outer: for placement in gameState.visiblePlacements {
                if let first = byType[placement.typeId] {
                    targetCell = first
                    break outer
                }
                byType[placement.typeId] = placement.slot
            }
        }

        guard targetCell != hintTargetCell else { return }
        hintTargetCell = targetCell
        hintNode?.removeFromParent()
        hintNode = nil
        guard targetCell >= 0 else { return }

        let ring = SKShapeNode(circleOfRadius: cellSize * 0.55)
        ring.strokeColor = SKColor(named: "PaletteBlue") ?? .systemBlue
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.position = position(ofCell: targetCell)
        ring.zPosition = 80
        fieldNode.addChild(ring)
        if !UIAccessibility.isReduceMotionEnabled {
            ring.run(.repeatForever(.sequence([
                .group([.scale(to: 1.15, duration: 0.5), .fadeAlpha(to: 0.5, duration: 0.5)]),
                .group([.scale(to: 1.0, duration: 0.5), .fadeAlpha(to: 1.0, duration: 0.5)]),
            ])))
        }
        hintNode = ring
    }

    // MARK: - Gestos: tap, drag-and-drop (§2.3 regla 2), long-press (pasivo)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragNode == nil, let touch = touches.first else { return }
        guard let node = characterNode(at: touch.location(in: self)) else {
            emptyTouchStart = touch.location(in: self)
            return
        }
        dragNode = node
        dragOriginCell = node.cellIndex
        isDragging = false
        node.removeAction(forKey: "wander")

        // Long-press: si en 0.45s sigue apretando sin arrastrar → popup de pasivo.
        run(.sequence([
            .wait(forDuration: 0.45),
            .run { [weak self] in
                guard let self, let held = self.dragNode, !self.isDragging else { return }
                self.cancelDrag(snapBack: false)
                self.gameState.presentCharacterSheet(cellIndex: held.cellIndex)
            },
        ]), withKey: Self.longPressKey)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if emptyTouchStart != nil { return }
        guard let node = dragNode, let touch = touches.first else { return }
        let location = touch.location(in: fieldNode)
        let origin = position(ofCell: dragOriginCell)

        if !isDragging, hypot(location.x - origin.x, location.y - origin.y) > Self.dragThreshold {
            isDragging = true
            removeAction(forKey: Self.longPressKey)
            node.zPosition = 50
            node.run(.scale(to: 1.08, duration: 0.08))
        }
        if isDragging {
            node.position = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeAction(forKey: Self.longPressKey)
        if let start = emptyTouchStart, let touch = touches.first {
            emptyTouchStart = nil
            let end = touch.location(in: self)
            let deltaY = end.y - start.y
            let deltaX = end.x - start.x
            if abs(deltaY) > 48, abs(deltaY) > abs(deltaX) * 1.5 {
                _ = gameState.moveVisibleFloor(by: deltaY > 0 ? 1 : -1)
            }
            return
        }
        guard let node = dragNode, let touch = touches.first else { return }

        guard isDragging else {
            // Tap corto: §2.3 regla 1.
            dragNode = nil
            if let result = gameState.registerTap(cellIndex: node.cellIndex) {
                runTapFeedback(on: node, result: result)
            }
            return
        }

        let dropPoint = touch.location(in: fieldNode)
        guard let targetCell = cellIndex(at: dropPoint) else {
            cancelDrag(snapBack: true)
            return
        }

        switch gameState.handleDrop(fromCell: dragOriginCell, toCell: targetCell) {
        case .merged(let cell, let evolvedTo, let promotedType, let promotedToFloor, let unlockedFloorID):
            // `layoutBoard()` recicla los nodos del campo. Tomamos la coordenada
            // mundial antes de reconstruirlo para animar una copia independiente.
            let promotionStart = promotedToFloor == nil
                ? nil
                : fieldNode.convert(node.position, to: backgroundLayer)
            dragNode = nil
            layoutBoard()
            // Si el resultado ascendió de piso (F7 §3.4), ya no está en este piso:
            // feedback en el punto del drop. F7.2 agrega la animación de vuelo.
            let mergedNode = promotedToFloor == nil ? characterNodes[cell] : nil
            let feedbackPoint = mergedNode?.position ?? dropPoint
            particles.emit(.merge, at: feedbackPoint, in: fieldNode)
            if let mergedNode {
                mergedNode.run(.sequence([
                    .scale(to: 1.25, duration: 0.1),
                    .scale(to: 1.0, duration: 0.12),
                ]))
            }
            // Cadena: vuelo → reveal del personaje → piso nuevo → avisarle a
            // GameState, que recién ahí suelta el sheet de skin y el toast.
            // Antes los tres arrancaban juntos en t=0 y el sheet aparecía encima,
            // así que no se apreciaba ninguno — y es el momento más importante
            // del juego. Encadena por completion y no por delays fijos: con
            // Reduce Motion las duraciones colapsan y un offset quedaría
            // desalineado.
            let finish: () -> Void = { [weak self] in
                self?.gameState.celebrationsDidFinish()
            }
            let celebrateFloor: () -> Void = { [weak self] in
                guard let self, let unlockedFloorID, let promotedToFloor else {
                    finish()
                    return
                }
                self.runFloorUnlockCelebration(
                    floorID: unlockedFloorID,
                    destinationOrdinal: promotedToFloor,
                    completion: finish
                )
            }
            let revealEvolution: () -> Void = { [weak self] in
                guard let self, let evolvedTo else {
                    celebrateFloor()
                    return
                }
                self.gameState.playHaptic(.evolution)
                self.runEvolutionReveal(
                    for: evolvedTo,
                    at: mergedNode?.position,
                    completion: celebrateFloor
                )
            }
            if let promotedType, let promotionStart {
                runAscentAnimation(type: promotedType, from: promotionStart, completion: revealEvolution)
            } else {
                if evolvedTo == nil { gameState.playHaptic(.merge) }
                revealEvolution()
            }
        case .moved:
            dragNode = nil
            layoutBoard()
        case .careerPending, .snapBack:
            cancelDrag(snapBack: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeAction(forKey: Self.longPressKey)
        emptyTouchStart = nil
        cancelDrag(snapBack: true)
    }

    private func cancelDrag(snapBack: Bool) {
        guard let node = dragNode else { return }
        dragNode = nil
        isDragging = false
        node.zPosition = 0
        if snapBack {
            node.run(.sequence([
                .group([
                    .move(to: position(ofCell: node.cellIndex), duration: 0.15),
                    .scale(to: 1.0, duration: 0.15),
                ]),
                .run { [weak self, weak node] in
                    guard let node else { return }
                    node.zPosition = self?.depthZ(for: node.position) ?? 0
                    self?.startWander(node)
                },
            ]))
        } else {
            node.position = position(ofCell: node.cellIndex)
            node.setScale(1.0)
            node.zPosition = depthZ(for: node.position)
            startWander(node)
        }
    }

    /// Hit-testing returns the deepest node (sprite/label); climb to the unit.
    private func characterNode(at point: CGPoint) -> CharacterNode? {
        // Entre los personajes cuyo cuerpo (radio generoso alrededor del ancla)
        // contiene el toque, elegir el de ADELANTE (mayor zPosition); ante empate,
        // el de ancla más cercana. Es más fiable que `nodes(at:)` cuando están
        // amontonados y sus cajas transparentes se solapan.
        let local = fieldNode.convert(point, from: self)
        let radius = cellSize * 0.82
        var best: (node: CharacterNode, z: CGFloat, dist: CGFloat)?
        for (_, node) in characterNodes {
            let dx = local.x - node.position.x
            let dy = local.y - (node.position.y + cellSize * 0.25)  // el cuerpo va sobre el ancla
            let dist = hypot(dx, dy)
            guard dist <= radius else { continue }
            if best == nil || node.zPosition > best!.z
                || (node.zPosition == best!.z && dist < best!.dist) {
                best = (node, node.zPosition, dist)
            }
        }
        return best?.node
    }

    /// Bounce + "+N" flotante; crit y golden gritan más fuerte. F5.2 suma
    /// partículas, SFX y haptics ricos.
    private func runTapFeedback(on node: CharacterNode, result: GameState.TapResult) {
        node.removeAction(forKey: "tapBounce")
        let punch: CGFloat = result.isCrit || result.isGolden ? 1.22 : 1.12
        node.run(
            .sequence([.scale(to: punch, duration: 0.06), .scale(to: 1.0, duration: 0.1)]),
            withKey: "tapBounce"
        )

        particles.emit(result.isCrit || result.isGolden ? .coins : .tap, at: node.position, in: fieldNode)
        if result.isGolden || result.isCrit {
            gameState.playHaptic(.rarity)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(CoinFormatter.string(from: result.gain))"
        label.fontSize = result.isCrit || result.isGolden ? 24 : 17
        label.fontColor = result.isGolden ? Palette.yellow : (result.isCrit ? SKColor(named: "PalettePink") ?? .red : Palette.ink)
        label.position = CGPoint(x: node.position.x, y: node.position.y + 34)
        label.zPosition = 100
        fieldNode.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: result.isCrit || result.isGolden ? 44 : 30, duration: 0.55), .fadeOut(withDuration: 0.55)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Reveal de evolución (bible §8: el momento de video vertical)

    private func runEvolutionReveal(
        for type: CharacterType,
        at position: CGPoint?,
        completion: @escaping () -> Void = {}
    ) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let hold: TimeInterval = 1.5

        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 200
        cameraOverlay.addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: reduceMotion ? 0.35 : 0.75, duration: 0.08),
            .fadeOut(withDuration: 0.35),
            .removeFromParent(),
        ]))

        if let position, !reduceMotion {
            particles.emit(.evolution, at: position, in: fieldNode)
        }

        // Scrim para enfocar la atención en el personaje recién desbloqueado.
        let scrim = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.72), size: size)
        scrim.anchorPoint = .zero
        scrim.position = .zero
        scrim.zPosition = 195
        scrim.alpha = 0
        cameraOverlay.addChild(scrim)
        scrim.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.2),
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]), completion: completion)

        // Foto del personaje: el arte real (o el placeholder) en grande y centrado.
        if let content = gameState.content,
           let texture = renderer.texture(for: type, manifest: content.manifest) {
            let side = min(size.width * 0.82, size.height * 0.52)
            let photo = SKSpriteNode(texture: texture)
            photo.size = CGSize(width: side, height: side)
            photo.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
            photo.zPosition = 208
            photo.alpha = 0
            photo.setScale(reduceMotion ? 1.0 : 0.5)
            cameraOverlay.addChild(photo)
            let photoIn: SKAction = reduceMotion
                ? .fadeIn(withDuration: 0.25)
                : .group([.fadeIn(withDuration: 0.18), .sequence([.scale(to: 1.1, duration: 0.24), .scale(to: 1.0, duration: 0.12)])])
            photo.run(.sequence([
                photoIn,
                .wait(forDuration: hold - 0.2),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
        }

        // Etiqueta "¡NUEVO!" arriba de todo.
        let tag = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        tag.text = "¡NUEVO!"
        tag.fontSize = 24
        tag.fontColor = Palette.yellow
        tag.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        tag.zPosition = 210
        tag.alpha = 0
        tag.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: hold + 0.1),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
        cameraOverlay.addChild(tag)

        // Nombre del personaje ARRIBA de la foto.
        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = type.displayName.uppercased()
        banner.fontSize = 38
        banner.fontColor = SKColor(named: "PalettePink") ?? .magenta
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        banner.zPosition = 210
        banner.alpha = 0
        banner.setScale(reduceMotion ? 1.0 : 0.4)
        cameraOverlay.addChild(banner)

        let entrance: SKAction = reduceMotion
            ? .fadeIn(withDuration: 0.25)
            : .group([.fadeIn(withDuration: 0.15), .sequence([.scale(to: 1.15, duration: 0.2), .scale(to: 1.0, duration: 0.1)])])
        // El reveal cierra solo; ya no se ofrece el share card (interrumpía el
        // ritmo del juego). offerShareCard sigue disponible por si se dispara
        // desde otro lado en el futuro.
        banner.run(.sequence([
            entrance,
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    // MARK: - Layout (campo, no grilla)

    /// Reconstruye el campo: fondo del PISO VISIBLE (F7 La Torre), anclas
    /// orgánicas y personajes parados con orden de profundidad por Y.
    func layoutBoard() {
        guard let content = gameState.content, gameState.player != nil,
              let floorDef = gameState.visibleFloorDef else { return }
        lastLayoutSize = size
        renderedBoardVersion = gameState.boardVersion

        let floorOffset = CGFloat(gameState.visibleFloorOrdinal) * size.height
        backgroundLayer.position = .zero

        // Grilla del piso: 2 filas (franja de multitud), columnas según capacidad.
        boardRows = 2
        boardColumns = max(1, (floorDef.capacity + boardRows - 1) / boardRows)

        // Los personajes conviven en la franja de piso (parte inferior de la
        // pantalla, donde el fondo generado tiene el suelo). La celda se ajusta al
        // ancho para que entren las columnas; las filas se apilan cerca y hacia
        // arriba (profundidad de multitud, no una grilla que llena la pantalla).
        let availableWidth = size.width - Self.horizontalInset * 2
        cellSize = availableWidth / CGFloat(max(boardColumns, 1))
        fieldNode.position = CGPoint(x: Self.horizontalInset, y: Self.bottomInset + floorOffset)

        cameraOverlay.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
        moveCameraIfNeeded(to: floorOffset)

        rebuildAnchors(capacity: floorDef.capacity)
        renderLiveFloorNodes(content: content)
        renderPlacements(content: content)
        renderAnchoredSpecials(content: content)
        renderLockedFloorOverlay()
    }

    /// Los specials no ocupan slot (⚠️5): se anclan al borde del piso donde
    /// cayeron, detrás de la multitud, como parte del decorado. No son
    /// interactivos — `cellIndex(at:)` sólo mira `characterNodes`.
    private func renderAnchoredSpecials(content: GameContent) {
        fieldNode.children
            .filter { $0.name?.hasPrefix(Self.specialNodePrefix) == true }
            .forEach { $0.removeFromParent() }

        let specials = gameState.visibleFloorSpecials
        guard !specials.isEmpty else { return }

        let side = cellSize * 0.62
        for (index, special) in specials.enumerated() {
            guard let asset = content.manifest.characters[special.id] else { continue }
            guard let texture = AtlasCache.texture(named: asset.key, inAtlas: asset.atlas) else { continue }

            let node = SKSpriteNode(texture: texture)
            node.name = Self.specialNodePrefix + special.id
            node.size = CGSize(width: side, height: side)
            // Alternan izquierda/derecha y suben por el fondo del campo, para no
            // taparse entre sí ni pisar las anclas de personajes.
            let isLeft = index.isMultiple(of: 2)
            let row = CGFloat(index / 2)
            node.position = CGPoint(
                x: isLeft ? side * 0.55 : size.width - Self.horizontalInset * 2 - side * 0.55,
                y: cellSize * 1.65 + row * side * 0.9
            )
            node.zPosition = -1
            node.alpha = 0.95
            fieldNode.addChild(node)
        }
    }

    /// Mantiene sólo el piso visible y sus vecinos inmediatos. El resto de los
    /// fondos se descarga; al volver a entrar se reconstruyen desde el manifest.
    private func renderLiveFloorNodes(content: GameContent) {
        let visible = gameState.visibleFloorOrdinal
        let lower = max(0, visible - 1)
        let upper = min(content.floorTable.floors.count - 1, visible + 1)
        let liveOrdinals = Set(lower...upper)

        // Primero materializamos las claves: mutar un Dictionary mientras se lo
        // enumera puede invalidar su iterador al desalojar un piso lejano.
        let staleOrdinals = floorNodes.keys.filter { !liveOrdinals.contains($0) }
        for ordinal in staleOrdinals {
            floorNodes.removeValue(forKey: ordinal)?.removeFromParent()
        }

        for ordinal in liveOrdinals {
            let definition = content.floorTable[ordinal]
            let node = floorNodes[ordinal] ?? FloorNode(ordinal: ordinal, definition: definition)
            node.position = CGPoint(x: 0, y: CGFloat(ordinal) * size.height)
            node.render(content: content, size: size)
            node.isPaused = ordinal != visible
            if floorNodes[ordinal] == nil {
                backgroundLayer.addChild(node)
                floorNodes[ordinal] = node
            }
        }
    }

    private func moveCameraIfNeeded(to floorOffset: CGFloat) {
        let target = CGPoint(x: size.width / 2, y: size.height / 2 + floorOffset)
        guard displayedFloorOrdinal != gameState.visibleFloorOrdinal || cameraNode.position != target else { return }
        displayedFloorOrdinal = gameState.visibleFloorOrdinal
        cameraNode.removeAction(forKey: "floorCamera")
        guard !UIAccessibility.isReduceMotionEnabled else {
            cameraNode.position = target
            return
        }
        cameraNode.run(.move(to: target, duration: 0.35), withKey: "floorCamera")
    }

    /// Una promoción ya fue aplicada por EconomyKit antes de llegar acá. SpriteKit
    /// sólo presenta un clon temporal: vuela hacia el piso superior y vuelve al
    /// pool al finalizar, por lo que no deja un nodo interactivo duplicado.
    private func runAscentAnimation(
        type: CharacterType,
        from start: CGPoint,
        completion: @escaping () -> Void = {}
    ) {
        guard let content = gameState.content else { completion(); return }
        let skinTreatment = SkinResolver.treatment(
            for: gameState.activeSkinID(forCharacterType: type.id),
            characterType: type.id,
            config: content.skins
        )
        let flight = pool.obtain()
        let hasRealArt = content.manifest.characters[type.id] != nil
        flight.configure(
            type: type,
            texture: renderer.texture(
                for: type,
                manifest: content.manifest,
                skinTextureKey: {
                    if case let .texture(key) = skinTreatment { return key }
                    return nil
                }()
            ),
            cellIndex: -1,
            cellSize: cellSize,
            skinTint: SkinResolver.tintColor(for: skinTreatment),
            hasRealArt: hasRealArt
        )
        flight.position = start
        flight.zPosition = 120
        flight.setScale(0.92)
        backgroundLayer.addChild(flight)
        gameState.playAscentFeedback()

        let destination = CGPoint(x: start.x, y: start.y + size.height * Self.ascentDistanceRatio)
        let flightAction: SKAction = UIAccessibility.isReduceMotionEnabled
            ? .move(to: destination, duration: 0.01)
            : .group([
                .move(to: destination, duration: Self.ascentDuration),
                .sequence([
                    .scale(to: 1.12, duration: Self.ascentDuration * 0.45),
                    .scale(to: 0.72, duration: Self.ascentDuration * 0.55),
                ]),
                .sequence([
                    .wait(forDuration: Self.ascentDuration * 0.7),
                    .fadeOut(withDuration: Self.ascentDuration * 0.3),
                ]),
            ])
        // El completion va acá y no al final del método: más abajo hay un
        // `guard` por el asset del flash que puede cortar, y la cadena no puede
        // depender de que ese asset exista.
        flight.run(.sequence([
            flightAction,
            .run { [weak self, weak flight] in
                if let flight { self?.pool.recycle(flight) }
                completion()
            },
        ]))

        particles.emit(.evolution, at: start, in: backgroundLayer)
        guard let flashAsset = content.manifest.ui["fx_evolution_flash"] else { return }
        let flash = SKSpriteNode(texture: AtlasCache.atlas(named: "ui").textureNamed(flashAsset))
        let flashSide = cellSize * 2.1
        flash.size = CGSize(width: flashSide, height: flashSide)
        flash.position = start
        flash.zPosition = 121
        backgroundLayer.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.16), .fadeOut(withDuration: 0.24)]),
            .removeFromParent(),
        ]))
    }

    /// El primer ascenso que abre un piso conserva el vuelo en pantalla y, al
    /// terminar, lleva la cámara a la nueva escena. En promociones posteriores
    /// la cámara no roba el foco: queda un indicador de ascenso en F7.2.
    private func runFloorUnlockCelebration(
        floorID: String,
        destinationOrdinal: Int,
        completion: @escaping () -> Void = {}
    ) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = String(localized: "tower.unlock.title")
        title.fontSize = 29
        title.fontColor = Palette.yellow
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.63)
        title.zPosition = 220
        title.alpha = 0
        cameraOverlay.addChild(title)
        let titleEntrance: SKAction = reduceMotion
            ? .fadeIn(withDuration: 0.01)
            : .group([.fadeIn(withDuration: 0.15), .sequence([.scale(to: 1.12, duration: 0.18), .scale(to: 1, duration: 0.1)])])
        title.run(.sequence([
            titleEntrance,
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.22),
            .removeFromParent(),
        ]), completion: completion)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hint.text = String(localized: "tower.unlock.hint")
        hint.fontSize = 18
        hint.fontColor = Palette.cream
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        hint.zPosition = 220
        hint.alpha = 0
        cameraOverlay.addChild(hint)
        hint.run(.sequence([
            .fadeIn(withDuration: reduceMotion ? 0.01 : 0.15),
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.22),
            .removeFromParent(),
        ]))

        gameState.playFloorUnlockFeedback()
        run(.sequence([
            .wait(forDuration: reduceMotion ? 0.01 : Self.ascentDuration),
            .run { [weak self] in self?.gameState.setVisibleFloor(destinationOrdinal) },
        ]), withKey: "unlockCamera")
        Log.board.info("floor unlocked: \(floorID)")
    }

    /// Ancla por slot: punto de grilla lógica + jitter determinístico
    /// (hash del índice), para que el campo se vea orgánico pero estable entre
    /// launches y consistente con el modelo de slots del piso.
    private func rebuildAnchors(capacity: Int) {
        let cols = max(boardColumns, 1)
        // Margen lateral para que los personajes grandes de las puntas no se corten
        // contra el borde de la pantalla; las columnas se centran dentro del campo.
        let edgeInset = cellSize * 0.68
        let colSpacing = (cellSize * CGFloat(cols) - 2 * edgeInset) / CGFloat(cols)
        let frontY = cellSize * 0.55            // pies de la fila delantera, sobre el piso
        let rowDepth = cellSize * 0.95          // franja de piso más alta: filas más separadas
        anchorPoints = (0..<capacity).map { index in
            let column = index % cols
            let row = index / cols
            // Filas alternadas corridas un poco (centrado) para asomar entre sí.
            let rowStagger = (row % 2 == 0 ? -1.0 : 1.0) * colSpacing * 0.1
            var hash = UInt64(index &* 2654435761)
            hash = (hash ^ (hash >> 13)) &* 0x9E3779B97F4A7C15
            let jitterX = (CGFloat(hash % 1000) / 1000 - 0.5) * cellSize * 0.08
            let jitterY = (CGFloat((hash >> 10) % 1000) / 1000 - 0.5) * cellSize * 0.06
            return CGPoint(
                x: edgeInset + CGFloat(column) * colSpacing + colSpacing / 2 + rowStagger + jitterX,
                y: frontY + CGFloat(row) * rowDepth + jitterY
            )
        }
    }

    /// Reconcilia en vez de reconstruir: sólo se rearman los slots que de verdad
    /// cambiaron (ver `BoardReconciliation`). Un personaje que sigue igual
    /// conserva su nodo, su posición deambulada y sus acciones a medio correr.
    private func renderPlacements(content: GameContent) {
        var wanted: [Int: RenderedUnit] = [:]
        var types: [Int: CharacterType] = [:]
        for placement in gameState.visiblePlacements {
            guard let type = content.tiers.type(id: placement.typeId) else {
                Log.board.error("placement references unknown type '\(placement.typeId)'")
                continue
            }
            types[placement.slot] = type
            wanted[placement.slot] = RenderedUnit(
                typeId: type.id,
                skinID: gameState.activeSkinID(forCharacterType: type.id),
                cellSize: cellSize,
                columns: boardColumns
            )
        }

        let plan = BoardReconciliation(rendered: renderedUnits, wanted: wanted)

        // Devolver al pool ANTES de pedir: así `obtain()` reutiliza los nodos que
        // se acaban de liberar en vez de alocar de más en cada merge.
        for slot in plan.discarded {
            guard let node = characterNodes.removeValue(forKey: slot) else { continue }
            pool.recycle(node)
        }

        for slot in plan.rebuilt {
            guard let type = types[slot] else { continue }
            let skinTreatment = SkinResolver.treatment(
                for: wanted[slot]?.skinID,
                characterType: type.id,
                config: content.skins
            )
            let hasRealArt = content.manifest.characters[type.id] != nil
            let node = pool.obtain()
            node.configure(
                type: type,
                texture: renderer.texture(
                    for: type,
                    manifest: content.manifest,
                    skinTextureKey: {
                        if case let .texture(key) = skinTreatment { return key }
                        return nil
                    }()
                ),
                cellIndex: slot,
                cellSize: cellSize,
                skinTint: SkinResolver.tintColor(for: skinTreatment),
                hasRealArt: hasRealArt
            )
            node.position = position(ofCell: slot)
            node.zPosition = depthZ(for: node.position)
            node.setScale(1.0)
            fieldNode.addChild(node)
            characterNodes[slot] = node
            startWander(node)
        }

        renderedUnits = wanted
    }

    /// Un único vistazo al siguiente piso bloqueado hace visible la meta sin
    /// convertirlo en un tablero jugable. El scrim vive bajo la cámara, por lo
    /// que acompaña cualquier cambio de piso y no tapa el HUD de SwiftUI.
    private func renderLockedFloorOverlay() {
        cameraOverlay.childNode(withName: "lockedFloorOverlay")?.removeFromParent()
        guard !gameState.visibleFloorIsUnlocked else { return }

        let overlay = SKNode()
        overlay.name = "lockedFloorOverlay"
        overlay.zPosition = 210

        let veil = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        veil.fillColor = .black.withAlphaComponent(0.36)
        veil.strokeColor = .clear
        overlay.addChild(veil)

        let lock = SKNode()
        lock.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        let shackle = SKShapeNode(rectOf: CGSize(width: 38, height: 42), cornerRadius: 18)
        shackle.position.y = 17
        shackle.strokeColor = Palette.cream
        shackle.lineWidth = 5
        shackle.fillColor = .clear
        lock.addChild(shackle)
        let body = SKShapeNode(rectOf: CGSize(width: 62, height: 48), cornerRadius: 8)
        body.position.y = -18
        body.fillColor = Palette.yellow
        body.strokeColor = Palette.ink
        body.lineWidth = 3
        lock.addChild(body)
        overlay.addChild(lock)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = String(localized: "tower.locked.title")
        title.fontSize = 25
        title.fontColor = Palette.cream
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.40)
        overlay.addChild(title)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hint.text = String(localized: "tower.locked.hint")
        hint.fontSize = 17
        hint.fontColor = Palette.cream
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        overlay.addChild(hint)
        cameraOverlay.addChild(overlay)
    }

    /// Los de abajo (más "cerca") tapan a los de arriba — profundidad de campo.
    private func depthZ(for point: CGPoint) -> CGFloat {
        (CGFloat(boardRows) * cellSize - point.y) * 0.01
    }

    /// Deambulación idle alrededor del ancla (estilo Cow Evolution). Se corta al
    /// agarrar el nodo y se reinicia al soltarlo/relayout.
    private func startWander(_ node: CharacterNode) {
        node.removeAction(forKey: "wander")
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let anchor = position(ofCell: node.cellIndex)
        var hash = UInt64(node.cellIndex &* 40503 &+ 7)
        let step: () -> SKAction = {
            hash = (hash ^ (hash >> 13)) &* 0x9E3779B97F4A7C15
            let dx = (CGFloat(hash % 100) / 100 - 0.5) * 30
            let dy = (CGFloat((hash >> 8) % 100) / 100 - 0.5) * 24
            let pause = 0.6 + Double(hash % 140) / 100
            return .sequence([
                .wait(forDuration: pause),
                .move(to: CGPoint(x: anchor.x + dx, y: anchor.y + dy), duration: 1.2),
            ])
        }
        node.run(.repeatForever(.sequence([step(), step(), step()])), withKey: "wander")
    }

    /// Ancla del cellIndex (campo orgánico).
    private func position(ofCell index: Int) -> CGPoint {
        guard index >= 0, index < anchorPoints.count else { return .zero }
        return anchorPoints[index]
    }

    /// Punto del campo → cellIndex del ancla más cercana (radio generoso), nil
    /// si cae lejos de toda ancla.
    private func cellIndex(at point: CGPoint) -> Int? {
        guard cellSize > 0, !anchorPoints.isEmpty else { return nil }
        let occupied = Set(characterNodes.keys)
        var bestOcc: (index: Int, distance: CGFloat)?
        var bestAny: (index: Int, distance: CGFloat)?
        for (index, anchor) in anchorPoints.enumerated() {
            let distance = hypot(point.x - anchor.x, point.y - anchor.y)
            if bestAny == nil || distance < bestAny!.distance { bestAny = (index, distance) }
            if occupied.contains(index), bestOcc == nil || distance < bestOcc!.distance {
                bestOcc = (index, distance)
            }
        }
        // Para MERGEAR: preferir una celda ocupada cercana (soltás sobre otro
        // personaje aunque estén amontonados). Si no hay, la celda más cercana.
        if let occ = bestOcc, occ.distance <= cellSize * 0.95 { return occ.index }
        if let any = bestAny, any.distance <= cellSize * 1.05 { return any.index }
        return nil
    }
}
