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
    private let mergeHaptic = UIImpactFeedbackGenerator(style: .medium)

    private let gridNode = SKNode()
    private var cellNodes: [SKShapeNode] = []
    private var characterNodes: [Int: CharacterNode] = [:]
    private var lastLayoutSize: CGSize = .zero
    private var renderedBoardVersion = -1

    // Grid geometry cached by layoutBoard for hit-testing and drops.
    private var boardColumns = 0
    private var boardRows = 0
    private var cellSize: CGFloat = 0

    // Drag state
    private var dragNode: CharacterNode?
    private var dragOriginCell = -1
    private var isDragging = false
    private static let dragThreshold: CGFloat = 10
    private static let longPressKey = "longPress"

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
        addChild(gridNode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BoardScene is never decoded")
    }

    override func didMove(to view: SKView) {
        layoutBoard()
        mergeHaptic.prepare()
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
    }

    // MARK: - Gestos: tap, drag-and-drop (§2.3 regla 2), long-press (pasivo)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragNode == nil, let touch = touches.first else { return }
        guard let node = characterNode(at: touch.location(in: self)) else { return }
        dragNode = node
        dragOriginCell = node.cellIndex
        isDragging = false

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
        let location = touch.location(in: gridNode)
        let origin = position(ofCell: dragOriginCell, centered: true)

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
            if let gain = gameState.registerTap(cellIndex: node.cellIndex) {
                runTapFeedback(on: node, gain: gain)
            }
            return
        }

        let dropPoint = touch.location(in: gridNode)
        guard let targetCell = cellIndex(at: dropPoint) else {
            cancelDrag(snapBack: true)
            return
        }

        switch gameState.handleDrop(fromCell: dragOriginCell, toCell: targetCell) {
        case .merged(let cell):
            dragNode = nil
            mergeHaptic.impactOccurred()
            layoutBoard()
            characterNodes[cell]?.run(.sequence([
                .scale(to: 1.25, duration: 0.1),
                .scale(to: 1.0, duration: 0.12),
            ]))
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
            node.run(.group([
                .move(to: position(ofCell: node.cellIndex, centered: true), duration: 0.15),
                .scale(to: 1.0, duration: 0.15),
            ]))
        } else {
            node.position = position(ofCell: node.cellIndex, centered: true)
            node.setScale(1.0)
        }
    }

    /// Hit-testing returns the deepest node (sprite/label); climb to the unit.
    private func characterNode(at point: CGPoint) -> CharacterNode? {
        for candidate in nodes(at: point) {
            var current: SKNode? = candidate
            while let node = current {
                if let character = node as? CharacterNode {
                    return character
                }
                current = node.parent
            }
        }
        return nil
    }

    /// Feedback mínimo de F1/F2: bounce + "+N" flotante. F5 suma partícula, SFX y haptic.
    private func runTapFeedback(on node: CharacterNode, gain: Double) {
        node.removeAction(forKey: "tapBounce")
        node.run(
            .sequence([.scale(to: 1.12, duration: 0.06), .scale(to: 1.0, duration: 0.1)]),
            withKey: "tapBounce"
        )

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(CoinFormatter.string(from: gain))"
        label.fontSize = 17
        label.fontColor = Palette.ink
        label.position = CGPoint(x: node.position.x, y: node.position.y + 34)
        label.zPosition = 100
        gridNode.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 30, duration: 0.55), .fadeOut(withDuration: 0.55)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Layout

    /// Rebuilds the grid and re-renders every placement from the current player state.
    func layoutBoard() {
        guard let content = gameState.content, let player = gameState.player else { return }
        lastLayoutSize = size
        renderedBoardVersion = gameState.boardVersion

        let board = content.economy.board
        boardColumns = board.columns
        boardRows = board.rows

        let availableWidth = size.width - Self.horizontalInset * 2
        let availableHeight = size.height - Self.topInset - Self.bottomInset
        cellSize = min(availableWidth / CGFloat(board.columns), availableHeight / CGFloat(board.rows))

        let gridWidth = cellSize * CGFloat(board.columns)
        let gridHeight = cellSize * CGFloat(board.rows)
        let originX = (size.width - gridWidth) / 2
        let originY = Self.bottomInset + (availableHeight - gridHeight) / 2
        gridNode.position = CGPoint(x: originX, y: originY)

        rebuildCells(board: board)
        renderPlacements(player: player, content: content)
    }

    private func rebuildCells(board: EconomyConfig.BoardConfig) {
        for cell in cellNodes {
            cell.removeFromParent()
        }
        cellNodes.removeAll(keepingCapacity: true)

        for index in 0..<board.cellCount {
            let cell = SKShapeNode(
                rect: CGRect(x: 0, y: 0, width: cellSize * 0.96, height: cellSize * 0.96),
                cornerRadius: cellSize * 0.12
            )
            cell.fillColor = Palette.yellow.withAlphaComponent(0.15)
            cell.strokeColor = Palette.ink.withAlphaComponent(0.25)
            cell.lineWidth = 1.5
            cell.position = position(ofCell: index, centered: false)
            gridNode.addChild(cell)
            cellNodes.append(cell)
        }
    }

    private func renderPlacements(player: PlayerState, content: GameContent) {
        for (_, node) in characterNodes {
            pool.recycle(node)
        }
        characterNodes.removeAll(keepingCapacity: true)

        for placement in player.board {
            guard let type = content.tiers.type(id: placement.typeId) else {
                Log.board.error("placement references unknown type '\(placement.typeId)'")
                continue
            }
            let node = pool.obtain()
            node.configure(
                type: type,
                texture: renderer.texture(for: type, manifest: content.manifest),
                cellIndex: placement.cellIndex,
                cellSize: cellSize
            )
            node.position = position(ofCell: placement.cellIndex, centered: true)
            node.zPosition = 0
            node.setScale(1.0)
            gridNode.addChild(node)
            characterNodes[placement.cellIndex] = node
        }
    }

    /// Cell `index` → point in grid coordinates. Row 0 sits at the bottom.
    private func position(ofCell index: Int, centered: Bool) -> CGPoint {
        let column = index % max(boardColumns, 1)
        let row = index / max(boardColumns, 1)
        let offset = centered ? cellSize / 2 : cellSize * 0.02
        return CGPoint(
            x: CGFloat(column) * cellSize + offset,
            y: CGFloat(row) * cellSize + offset
        )
    }

    /// Grid point → cell index, nil outside the grid.
    private func cellIndex(at point: CGPoint) -> Int? {
        guard cellSize > 0 else { return nil }
        let column = Int(floor(point.x / cellSize))
        let row = Int(floor(point.y / cellSize))
        guard (0..<boardColumns).contains(column), (0..<boardRows).contains(row) else { return nil }
        return row * boardColumns + column
    }
}
