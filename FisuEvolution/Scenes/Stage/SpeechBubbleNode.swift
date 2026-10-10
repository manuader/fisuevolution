import SpriteKit

/// El globo de la escena: el dibujo de `BubbleGeometry` con el texto envuelto
/// adentro. La punta de la cola está en el origen del nodo: posicionarlo es
/// posicionar la cola, y escalarlo hace el "pop" desde la boca del que habla.
final class SpeechBubbleNode: SKNode {
    static let padding: CGFloat = 12
    private let shape = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private(set) var text = ""
    private(set) var size: CGSize = .zero
    private var tailX: CGFloat = -1

    override init() {
        super.init()
        name = "stage.bubble"
        shape.fillColor = Palette.cream
        shape.strokeColor = Palette.ink
        shape.lineWidth = 2
        label.fontColor = Palette.ink
        label.fontSize = 15
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(shape)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("SpeechBubbleNode is never decoded")
    }

    /// Mide el texto y se queda con su tamaño (cola incluida).
    func setText(_ text: String, maxWidth: CGFloat) {
        self.text = text
        label.text = text
        label.preferredMaxLayoutWidth = maxWidth - Self.padding * 2
        let measured = label.frame.size
        size = CGSize(width: min(maxWidth, measured.width + Self.padding * 2),
                      height: measured.height + Self.padding * 2 + BubbleGeometry.tailHeight)
        tailX = -1
    }

    /// Redibuja con la cola a `tailX` del borde izquierdo del globo.
    func pointTail(at tailX: CGFloat) {
        guard tailX != self.tailX else { return }
        self.tailX = tailX
        let rect = CGRect(x: -tailX, y: 0, width: size.width, height: size.height)
        shape.path = BubbleGeometry.path(in: rect, tailX: 0, yUp: true)
        label.position = CGPoint(x: rect.midX, y: BubbleGeometry.tailHeight + (size.height - BubbleGeometry.tailHeight) / 2)
    }
}
