import SpriteKit

/// Una caja del Paquete o el colchón, en el tablero. Todo lo que se mueve va por
/// frame (`update`): entra con un resorte, respira, y tiembla si se la toca sin
/// lugar. Si tiene clip de espera, lo reproduce en loop sobre su textura mientras la escena lo
/// pide (`setWaiting`): el póster no se saca nunca, y sin video queda quieto.
@MainActor
final class PickupNode: SKNode {
    enum Kind: Equatable {
        case package
        case mattress
    }

    static let popSeconds: TimeInterval = 0.35
    static let shakeSeconds: TimeInterval = 0.4

    let kind: Kind
    private let sprite: SKSpriteNode
    private let waitingVideo: LoopingVideoNode?
    private let fullSign = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var age: TimeInterval = 0
    private var shakeLeft: TimeInterval = 0

    init(kind: Kind, texture: SKTexture, side: CGFloat, waitingClip: ArtClip? = nil,
         manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared) {
        self.kind = kind
        sprite = SKSpriteNode(texture: texture)
        waitingVideo = waitingClip.map {
            LoopingVideoNode(clip: $0, poster: texture, size: .zero, role: .icon, manifest: manifest, pool: pool)
        }
        super.init()
        addChild(sprite)
        if let waitingVideo {
            waitingVideo.zPosition = 0.5
            addChild(waitingVideo)
        }
        fullSign.text = String(localized: "prize.package.full")
        fullSign.fontColor = UIColor(named: "PaletteOrange")
        fullSign.verticalAlignmentMode = .center
        fullSign.isHidden = true
        addChild(fullSign)
        resize(side: side)
        setScale(0.01)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resize(side: CGFloat) {
        let size = sprite.texture?.size() ?? CGSize(width: 1, height: 1)
        sprite.size = CGSize(width: side, height: side * size.height / max(size.width, 1))
        waitingVideo?.resize(sprite.size)
        fullSign.fontSize = side * 0.3
        fullSign.position = CGPoint(x: 0, y: sprite.size.height * 0.75)
    }

    private(set) var isWaiting = false
    var waitingVideoNode: LoopingVideoNode? { waitingVideo }

    /// Sólo la caja que está a la vista pide el cupo del pool; al salir o taparse lo suelta.
    func setWaiting(_ waiting: Bool) {
        guard waiting != isWaiting else { return }
        isWaiting = waiting
        waitingVideo?.setVisible(waiting)
    }

    /// Se va del tablero: suelta el video antes de salir de la escena.
    func retire() {
        setWaiting(false)
        removeFromParent()
    }

    /// El cartel "LLENO" (PLAN-v2 §2).
    var showsFull: Bool {
        get { !fullSign.isHidden }
        set { fullSign.isHidden = !newValue }
    }

    func shake() {
        shakeLeft = Self.shakeSeconds
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        age += delta
        if reduceMotion {
            setScale(1)
            zRotation = 0
            alpha = CGFloat(min(1, age / Self.popSeconds))
            return
        }
        alpha = 1
        let pop = min(1, age / Self.popSeconds)
        let overshoot = pop < 1 ? 0.2 * sin(pop * .pi) : 0
        let breathe = kind == .package ? 0.025 * sin(age * 3) : 0.015 * sin(age * 2)
        setScale(CGFloat(pop + overshoot + breathe))
        guard shakeLeft > 0 else {
            zRotation = 0
            return
        }
        shakeLeft = max(0, shakeLeft - delta)
        zRotation = CGFloat(sin(shakeLeft * 60) * 0.14 * (shakeLeft / Self.shakeSeconds))
    }

    /// `point` en las coordenadas del padre, con un margen generoso para el dedo.
    func hitTest(_ point: CGPoint) -> Bool {
        calculateAccumulatedFrame().insetBy(dx: -8, dy: -8).contains(point)
    }
}
