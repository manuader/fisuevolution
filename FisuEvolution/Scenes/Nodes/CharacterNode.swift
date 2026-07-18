import EconomyKit
import SpriteKit
import UIKit

/// A reusable board unit: colored plate (phase color) + sprite (placeholder or real
/// art) + tier label. Instances are pooled — merges create and destroy nodes
/// constantly and per-event allocations are off-limits (60 FPS rule).
final class CharacterNode: SKNode {
    static let nodeName = "character"

    private let plate = SKShapeNode()
    private let sprite = SKSpriteNode()
    private let tierLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    private(set) var typeId: String = ""
    private(set) var cellIndex: Int = -1

    override init() {
        super.init()
        name = Self.nodeName

        plate.lineWidth = 2
        addChild(plate)

        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(sprite)

        tierLabel.horizontalAlignmentMode = .center
        tierLabel.verticalAlignmentMode = .top
        addChild(tierLabel)

        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .bottom
        addChild(nameLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CharacterNode is never decoded")
    }

    func configure(type: CharacterType, texture: SKTexture?, cellIndex: Int, cellSize: CGFloat, skinTint: SKColor? = nil) {
        typeId = type.id
        self.cellIndex = cellIndex

        let plateSize = cellSize * 0.92
        plate.path = CGPath(
            roundedRect: CGRect(x: -plateSize / 2, y: -plateSize / 2, width: plateSize, height: plateSize),
            cornerWidth: plateSize * 0.18,
            cornerHeight: plateSize * 0.18,
            transform: nil
        )
        plate.fillColor = Palette.color(for: type.phase)
        plate.strokeColor = skinTint ?? Palette.ink
        plate.lineWidth = skinTint == nil ? 2 : 3
        plate.glowWidth = skinTint == nil ? 0 : 3

        sprite.texture = texture
        sprite.isHidden = texture == nil
        let spriteSide = plateSize * 0.52
        sprite.size = CGSize(width: spriteSide, height: spriteSide)
        sprite.position = CGPoint(x: 0, y: plateSize * 0.04)

        tierLabel.text = "T\(type.tier)"
        tierLabel.fontSize = plateSize * 0.2
        tierLabel.fontColor = Palette.ink
        tierLabel.position = CGPoint(x: 0, y: plateSize * 0.46)

        nameLabel.text = type.displayName
        nameLabel.fontSize = plateSize * 0.11
        nameLabel.fontColor = Palette.ink
        nameLabel.position = CGPoint(x: 0, y: -plateSize * 0.46)
    }
}

/// Minimal object pool for `CharacterNode` (bible §4.2: reuse nodes, never
/// create/destroy per event).
@MainActor
final class CharacterNodePool {
    private var free: [CharacterNode] = []

    func obtain() -> CharacterNode {
        free.popLast() ?? CharacterNode()
    }

    func recycle(_ node: CharacterNode) {
        node.removeFromParent()
        free.append(node)
    }
}

/// Palette lookups backed by the asset catalog Color Sets (single source of the
/// visual identity — see Asset-generation.md §3).
@MainActor
enum Palette {
    static var ink: SKColor { named("PaletteInk", fallback: .darkGray) }
    static var cream: SKColor { named("PaletteCream", fallback: .white) }
    static var yellow: SKColor { named("PaletteYellow", fallback: .yellow) }

    static func color(for phase: GamePhase) -> SKColor {
        switch phase {
        case .earth: named("PaletteOrange", fallback: .orange)
        case .cosmic: named("PaletteBlue", fallback: .blue)
        }
    }

    private static func named(_ name: String, fallback: SKColor) -> SKColor {
        SKColor(named: name) ?? fallback
    }
}
