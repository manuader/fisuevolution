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

    /// Campo de juego (estilo Cow Evolution): fondo de escena + personajes
    /// parados en anclas orgánicas — sin grilla visible.
    private let backgroundLayer = SKNode()
    private let fieldNode = SKNode()
    private var characterNodes: [Int: CharacterNode] = [:]
    private var lastLayoutSize: CGSize = .zero
    private var renderedBoardVersion = -1
    private var renderedStageKey = ""

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
    private static let dragThreshold: CGFloat = 10
    private static let longPressKey = "longPress"

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
        if gameState.showTapHint {
            targetCell = gameState.player?.board.first?.cellIndex ?? -1
        } else if gameState.showMergeHint, let player = gameState.player {
            var byType: [String: Int] = [:]
            outer: for placement in player.board {
                if let first = byType[placement.typeId] {
                    targetCell = first
                    break outer
                }
                byType[placement.typeId] = placement.cellIndex
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
        guard let node = characterNode(at: touch.location(in: self)) else { return }
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
                self.gameState.presentPassivePrompt(cellIndex: held.cellIndex)
            },
        ]), withKey: Self.longPressKey)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        case .merged(let cell, let evolvedTo):
            dragNode = nil
            layoutBoard()
            let mergedNode = characterNodes[cell]
            if let mergedNode {
                particles.emit(.merge, at: mergedNode.position, in: fieldNode)
                mergedNode.run(.sequence([
                    .scale(to: 1.25, duration: 0.1),
                    .scale(to: 1.0, duration: 0.12),
                ]))
            }
            if let evolvedTo {
                gameState.playHaptic(.evolution)
                runEvolutionReveal(for: evolvedTo, at: mergedNode?.position)
            } else {
                gameState.playHaptic(.merge)
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

    private func runEvolutionReveal(for type: CharacterType, at position: CGPoint?) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let hold: TimeInterval = 1.5

        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 200
        addChild(flash)
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
        addChild(scrim)
        scrim.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.2),
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))

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
            addChild(photo)
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
        addChild(tag)

        // Nombre del personaje ARRIBA de la foto.
        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = type.displayName.uppercased()
        banner.fontSize = 38
        banner.fontColor = SKColor(named: "PalettePink") ?? .magenta
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        banner.zPosition = 210
        banner.alpha = 0
        banner.setScale(reduceMotion ? 1.0 : 0.4)
        addChild(banner)

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

    /// Reconstruye el campo: fondo de la etapa actual, anclas orgánicas y
    /// personajes parados con orden de profundidad por Y.
    func layoutBoard() {
        guard let content = gameState.content, let player = gameState.player else { return }
        lastLayoutSize = size
        renderedBoardVersion = gameState.boardVersion

        let board = content.economy.board
        boardColumns = board.columns
        boardRows = board.rows

        // Los personajes conviven en la franja de piso (parte inferior de la
        // pantalla, donde el fondo generado tiene el suelo). La celda se ajusta al
        // ancho para que entren las columnas; las filas se apilan cerca y hacia
        // arriba (profundidad de multitud, no una grilla que llena la pantalla).
        let availableWidth = size.width - Self.horizontalInset * 2
        cellSize = availableWidth / CGFloat(max(board.columns, 1))
        fieldNode.position = CGPoint(x: Self.horizontalInset, y: Self.bottomInset)

        rebuildAnchors(board: board)
        renderFieldBackground(content: content, player: player)
        renderPlacements(player: player, content: content)
    }

    /// Ancla por cellIndex: punto de grilla lógica + jitter determinístico
    /// (hash del índice), para que el campo se vea orgánico pero estable entre
    /// launches y consistente con el modelo de board persistido.
    private func rebuildAnchors(board: EconomyConfig.BoardConfig) {
        let cols = max(boardColumns, 1)
        // Margen lateral para que los personajes grandes de las puntas no se corten
        // contra el borde de la pantalla; las columnas se centran dentro del campo.
        let edgeInset = cellSize * 0.68
        let colSpacing = (cellSize * CGFloat(cols) - 2 * edgeInset) / CGFloat(cols)
        let frontY = cellSize * 0.55            // pies de la fila delantera, sobre el piso
        let rowDepth = cellSize * 0.95          // franja de piso más alta: filas más separadas
        anchorPoints = (0..<board.cellCount).map { index in
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

    // MARK: - Fondo por etapa (bible §6.4: 11 stages)

    /// maxTierReached → key de background. Umbrales [TUNEABLE].
    private static let stageThresholds: [(minTier: Int, key: String)] = [
        (30, "god_realm"), (28, "cosmic"), (26, "galaxy"), (24, "solar"),
        (22, "mars"), (18, "moon"), (14, "island"), (10, "luxury"),
        (6, "corporate"), (3, "urban"), (1, "alley"),
    ]

    /// Colores de fallback (cielo, piso) hasta que el arte real llene el manifest.
    private static let stageFallbackColors: [String: (sky: SKColor, ground: SKColor)] = [
        "alley": (SKColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1), SKColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1)),
        "urban": (SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1), SKColor(red: 0.72, green: 0.66, blue: 0.55, alpha: 1)),
        "corporate": (SKColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 1), SKColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1)),
        "luxury": (SKColor(red: 0.45, green: 0.8, blue: 0.85, alpha: 1), SKColor(red: 0.93, green: 0.89, blue: 0.78, alpha: 1)),
        "island": (SKColor(red: 0.4, green: 0.85, blue: 0.95, alpha: 1), SKColor(red: 0.96, green: 0.87, blue: 0.62, alpha: 1)),
        "moon": (SKColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1), SKColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)),
        "mars": (SKColor(red: 0.25, green: 0.1, blue: 0.1, alpha: 1), SKColor(red: 0.75, green: 0.4, blue: 0.25, alpha: 1)),
        "solar": (SKColor(red: 0.06, green: 0.07, blue: 0.2, alpha: 1), SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1)),
        "galaxy": (SKColor(red: 0.12, green: 0.05, blue: 0.25, alpha: 1), SKColor(red: 0.4, green: 0.3, blue: 0.6, alpha: 1)),
        "cosmic": (SKColor(red: 0.04, green: 0.02, blue: 0.1, alpha: 1), SKColor(red: 0.3, green: 0.15, blue: 0.45, alpha: 1)),
        "god_realm": (SKColor(red: 1.0, green: 0.92, blue: 0.7, alpha: 1), SKColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1)),
    ]

    private func renderFieldBackground(content: GameContent, player: PlayerState) {
        let stage = Self.stageThresholds.first { player.maxTierReached >= $0.minTier }?.key ?? "alley"
        guard stage != renderedStageKey || backgroundLayer.children.isEmpty else { return }
        renderedStageKey = stage
        backgroundLayer.removeAllChildren()

        // Arte real del manifest si existe; si no, cielo + piso de fallback.
        if let assetName = content.manifest.backgrounds[stage].flatMap({ $0.isEmpty ? nil : $0 }),
           UIImage(named: assetName) != nil {
            let sprite = SKSpriteNode(imageNamed: assetName)
            // Aspect-FILL: escalar para cubrir la pantalla SIN deformar (se recorta
            // el excedente). Un poco extra para agrandar la franja de piso, y
            // anclado abajo para que el piso jugable se vea completo y grande.
            let tex = sprite.texture?.size() ?? CGSize(width: 1024, height: 1024)
            let scale = max(size.width / tex.width, size.height / tex.height) * 1.18
            sprite.size = CGSize(width: tex.width * scale, height: tex.height * scale)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            sprite.position = CGPoint(x: size.width / 2, y: 0)
            sprite.zPosition = -100
            backgroundLayer.addChild(sprite)
            return
        }

        let colors = Self.stageFallbackColors[stage] ?? (Palette.cream, Palette.yellow)
        let sky = SKSpriteNode(color: colors.sky, size: size)
        sky.anchorPoint = .zero
        sky.position = .zero
        sky.zPosition = -100
        backgroundLayer.addChild(sky)

        let groundHeight = size.height * 0.62
        let ground = SKSpriteNode(color: colors.ground, size: CGSize(width: size.width, height: groundHeight))
        ground.anchorPoint = .zero
        ground.position = .zero
        ground.zPosition = -99
        backgroundLayer.addChild(ground)
    }

    private func renderPlacements(player: PlayerState, content: GameContent) {
        for (_, node) in characterNodes {
            pool.recycle(node)
        }
        characterNodes.removeAll(keepingCapacity: true)

        let skinTint = SkinResolver.tint(for: player.activeSkin)
        for placement in player.board {
            guard let type = content.tiers.type(id: placement.typeId) else {
                Log.board.error("placement references unknown type '\(placement.typeId)'")
                continue
            }
            let hasRealArt = content.manifest.characters[type.id] != nil
            let node = pool.obtain()
            node.configure(
                type: type,
                texture: renderer.texture(for: type, manifest: content.manifest),
                cellIndex: placement.cellIndex,
                cellSize: cellSize,
                skinTint: skinTint,
                hasRealArt: hasRealArt
            )
            node.position = position(ofCell: placement.cellIndex)
            node.zPosition = depthZ(for: node.position)
            node.setScale(1.0)
            fieldNode.addChild(node)
            characterNodes[placement.cellIndex] = node
            startWander(node)
        }
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
