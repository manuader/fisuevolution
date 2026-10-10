import SpriteKit

/// La apertura del Paquete de la Aduana, adentro del turno del tablero (E1): la
/// caja cae donde va a quedar el empleado, se sacude, la tapa vuela, saltan
/// monedas y recién ahí se confirma la llegada, que hace el resto (el pop del
/// empleado y, si fuera nuevo, su revelación). Por frame, como el escenario de
/// E4b: se prueba sin vista.
@MainActor
final class PackageOpeningPlayer {
    static let dropSeconds: TimeInterval = 0.25
    static let shakeSeconds: TimeInterval = 0.5
    static let lidSeconds: TimeInterval = 0.3
    static let fadeSeconds: TimeInterval = 0.3
    static var totalSeconds: TimeInterval { dropSeconds + shakeSeconds + lidSeconds }

    private var box: SKSpriteNode?
    private var lid: SKSpriteNode?
    private var point: CGPoint = .zero
    private var side: CGFloat = 0
    private var elapsed: TimeInterval = 0
    private var burstDone = false
    private var onBurst: ((CGPoint) -> Void)?
    private var onOpened: (() -> Void)?

    var isPlaying: Bool { box != nil }

    func play(
        at point: CGPoint,
        in parent: SKNode,
        z: CGFloat,
        side: CGFloat,
        burst: @escaping (CGPoint) -> Void,
        opened: @escaping () -> Void
    ) {
        cancel()
        let box = SKSpriteNode(texture: PickupArt.texture(.package))
        let textureSize = box.texture?.size() ?? CGSize(width: 1, height: 1)
        box.size = CGSize(width: side, height: side * textureSize.height / max(textureSize.width, 1))
        box.position = point
        box.zPosition = z
        let lid = SKSpriteNode(texture: PickupArt.texture(.packageLid))
        lid.size = CGSize(width: side * 1.04, height: side * 0.3)
        lid.position = CGPoint(x: 0, y: box.size.height / 2)
        lid.zPosition = 1
        box.addChild(lid)
        parent.addChild(box)
        self.box = box
        self.lid = lid
        self.point = point
        self.side = side
        elapsed = 0
        burstDone = false
        onBurst = burst
        onOpened = opened
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let box, let lid else { return }
        elapsed += delta
        if reduceMotion {
            box.setScale(1)
            box.zRotation = 0
            box.alpha = CGFloat(min(1, elapsed / Self.fadeSeconds))
            if elapsed >= Self.fadeSeconds { finish() }
            return
        }
        let shakeStart = Self.dropSeconds
        let lidStart = shakeStart + Self.shakeSeconds
        if elapsed < shakeStart {
            let t = elapsed / Self.dropSeconds
            box.setScale(CGFloat(0.3 + 0.7 * t + 0.15 * sin(t * .pi)))
            box.position = CGPoint(x: point.x, y: point.y + side * CGFloat(1 - t))
        } else if elapsed < lidStart {
            box.setScale(1)
            box.position = point
            let t = (elapsed - shakeStart) / Self.shakeSeconds
            box.zRotation = CGFloat(sin(t * .pi * 8) * 0.14 * (1 - t))
        } else {
            box.zRotation = 0
            if !burstDone {
                burstDone = true
                onBurst?(point)
            }
            let t = min(1, (elapsed - lidStart) / Self.lidSeconds)
            lid.position = CGPoint(x: side * 0.3 * CGFloat(t), y: box.size.height / 2 + side * 1.2 * CGFloat(t))
            lid.zRotation = CGFloat(0.9 * t)
            lid.alpha = CGFloat(1 - t)
            box.alpha = CGFloat(1 - 0.6 * t)
            if elapsed >= Self.totalSeconds { finish() }
        }
    }

    /// Se corta (el salto o el watchdog del turno): sin avisos. El cambio en
    /// vuelo lo asienta `GameState` (E1).
    func cancel() {
        box?.removeFromParent()
        box = nil
        lid = nil
        onBurst = nil
        onOpened = nil
    }

    private func finish() {
        let opened = onOpened
        cancel()
        opened?()
    }
}
