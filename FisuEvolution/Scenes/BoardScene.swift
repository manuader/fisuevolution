import EconomyKit
import SpriteKit

/// The merge board. Owns the entire per-frame world (bible §4.1): SwiftUI never
/// re-renders because of anything happening in here. Reads state from `GameState`
/// and renders the grid + character nodes; F1/F2 add tap, drag-and-drop and the
/// income tick on top of this layout.
final class BoardScene: SKScene {
    private unowned let gameState: GameState
    private let renderer = PlaceholderRenderer()
    private let pool = CharacterNodePool()

    private let gridNode = SKNode()
    private var cellNodes: [SKShapeNode] = []
    private var characterNodes: [Int: CharacterNode] = [:]
    private var lastLayoutSize: CGSize = .zero

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
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Called during init too, before children exist — only relayout when live.
        guard scene?.view != nil, size != lastLayoutSize else { return }
        layoutBoard()
    }

    /// Rebuilds the grid and re-renders every placement from the current player state.
    /// Cheap at F0 scale; F1/F2 switch to incremental updates driven by state changes.
    func layoutBoard() {
        guard let content = gameState.content, let player = gameState.player else { return }
        lastLayoutSize = size

        let board = content.economy.board
        let availableWidth = size.width - Self.horizontalInset * 2
        let availableHeight = size.height - Self.topInset - Self.bottomInset
        let cellSize = min(availableWidth / CGFloat(board.columns), availableHeight / CGFloat(board.rows))

        let gridWidth = cellSize * CGFloat(board.columns)
        let gridHeight = cellSize * CGFloat(board.rows)
        let originX = (size.width - gridWidth) / 2
        let originY = Self.bottomInset + (availableHeight - gridHeight) / 2
        gridNode.position = CGPoint(x: originX, y: originY)

        rebuildCells(board: board, cellSize: cellSize)
        renderPlacements(player: player, content: content, board: board, cellSize: cellSize)

        Log.board.debug("board laid out: \(board.columns)x\(board.rows), cell \(cellSize, format: .fixed(precision: 1))pt")
    }

    private func rebuildCells(board: EconomyConfig.BoardConfig, cellSize: CGFloat) {
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
            cell.position = position(ofCell: index, board: board, cellSize: cellSize, centered: false)
            gridNode.addChild(cell)
            cellNodes.append(cell)
        }
    }

    private func renderPlacements(
        player: PlayerState,
        content: GameContent,
        board: EconomyConfig.BoardConfig,
        cellSize: CGFloat
    ) {
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
            node.position = position(ofCell: placement.cellIndex, board: board, cellSize: cellSize, centered: true)
            gridNode.addChild(node)
            characterNodes[placement.cellIndex] = node
        }
    }

    /// Cell `index` → point in grid coordinates. Row 0 sits at the bottom.
    private func position(
        ofCell index: Int,
        board: EconomyConfig.BoardConfig,
        cellSize: CGFloat,
        centered: Bool
    ) -> CGPoint {
        let column = index % board.columns
        let row = index / board.columns
        let offset = centered ? cellSize / 2 : cellSize * 0.02
        return CGPoint(
            x: CGFloat(column) * cellSize + offset,
            y: CGFloat(row) * cellSize + offset
        )
    }
}
