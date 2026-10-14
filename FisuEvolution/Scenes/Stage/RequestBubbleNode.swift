import SpriteKit

/// El globo de pensamiento de quien pide un empleado (PLAN-v2 E14 C16): las
/// burbujitas bajan hasta la cabeza y adentro va la cara de quien se lleva. La
/// punta de la cola está en el origen del nodo, igual que `SpeechBubbleNode`.
final class RequestBubbleNode: SKNode {
    enum Kind: Equatable {
        case take, arrest, sale

        var accent: SKColor {
            switch self {
            case .take: SKColor(red: 0.88, green: 0.27, blue: 0.48, alpha: 1)
            case .arrest: SKColor(red: 0.80, green: 0.18, blue: 0.16, alpha: 1)
            case .sale: SKColor(red: 0.20, green: 0.60, blue: 0.30, alpha: 1)
            }
        }
    }

    static let cloudSize = CGSize(width: 78, height: 70)
    static let faceSide: CGFloat = 52
    private static let cloudBottom: CGFloat = 26

    let kind: Kind
    private(set) var typeId: String
    private(set) var count: Int

    init(kind: Kind, typeId: String, count: Int, face: SKTexture?, tint: SKColor?) {
        self.kind = kind
        self.typeId = typeId
        self.count = count
        super.init()
        name = "stage.request"
        let accent = kind.accent
        addChild(dot(radius: 4, at: CGPoint(x: 0, y: 5), accent: accent))
        addChild(dot(radius: 6.5, at: CGPoint(x: 5, y: 15), accent: accent))

        let cloud = SKShapeNode(rectOf: Self.cloudSize, cornerRadius: 26)
        cloud.position = CGPoint(x: 0, y: Self.cloudBottom + Self.cloudSize.height / 2)
        cloud.fillColor = Palette.cream
        cloud.strokeColor = accent
        cloud.lineWidth = 3.5
        addChild(cloud)

        let crop = SKCropNode()
        crop.maskNode = SKShapeNode(circleOfRadius: Self.faceSide / 2)
        if let face {
            let sprite = SKSpriteNode(texture: face)
            sprite.size = CGSize(width: Self.faceSide, height: Self.faceSide)
            if let tint {
                sprite.color = tint
                sprite.colorBlendFactor = 0.25
            }
            crop.addChild(sprite)
        } else {
            let mark = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            mark.text = "?"
            mark.fontSize = 34
            mark.fontColor = accent
            mark.verticalAlignmentMode = .center
            crop.addChild(mark)
        }
        crop.position = cloud.position
        addChild(crop)

        if count > 1 {
            let badge = SKShapeNode(rectOf: CGSize(width: 32, height: 20), cornerRadius: 10)
            badge.fillColor = accent
            badge.strokeColor = Palette.cream
            badge.lineWidth = 2
            badge.position = CGPoint(x: Self.cloudSize.width / 2 - 8, y: Self.cloudBottom + 6)
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "×\(count)"
            label.fontSize = 13
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            badge.addChild(label)
            badge.zPosition = 1
            addChild(badge)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("RequestBubbleNode is never decoded")
    }

    private func dot(radius: CGFloat, at point: CGPoint, accent: SKColor) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = point
        node.fillColor = Palette.cream
        node.strokeColor = accent
        node.lineWidth = 2.5
        return node
    }

    /// Lo que mide de punta a punta, la cola incluida.
    var height: CGFloat { Self.cloudBottom + Self.cloudSize.height }

    /// El mismo pedido: no hace falta volver a armarlo.
    func asks(for typeId: String, count: Int, kind: Kind) -> Bool {
        self.typeId == typeId && self.count == count && self.kind == kind
    }
}
