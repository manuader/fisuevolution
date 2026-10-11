import SpriteKit

/// La apertura del Paquete de la Aduana, adentro del turno del tablero (E1): la
/// caja cae donde va a quedar el empleado, se sacude, la tapa vuela, saltan
/// monedas y recién ahí se confirma la llegada, que hace el resto (el pop del
/// empleado y, si fuera nuevo, su revelación). Por frame, como el escenario de
/// E4b: se prueba sin vista.
///
/// Si el manifest tiene `paquete_abre` y el pool deja decodificar, la apertura es el video (una
/// pasada, sobre el póster de la caja). La confirmación de la llegada nunca depende de él: si no
/// hay video, no arranca o falla, corre la animación por código; y un tope por cuadros cierra el
/// video que no avise.
@MainActor
final class PackageOpeningPlayer {
    static let dropSeconds: TimeInterval = 0.25
    static let shakeSeconds: TimeInterval = 0.5
    static let lidSeconds: TimeInterval = 0.3
    static let fadeSeconds: TimeInterval = 0.3
    static var totalSeconds: TimeInterval { dropSeconds + shakeSeconds + lidSeconds }
    static let videoBurstSeconds: TimeInterval = 1.5
    static let videoCapSeconds: TimeInterval = 4

    private let manifest: LoopsManifest
    private let pool: VideoPlayerPool

    private var box: SKSpriteNode?
    private var lid: SKSpriteNode?
    private var point: CGPoint = .zero
    private var side: CGFloat = 0
    private var elapsed: TimeInterval = 0
    private var burstDone = false
    private var onBurst: ((CGPoint) -> Void)?
    private var onOpened: (() -> Void)?

    private(set) var video: LoopingVideoNode?

    var isPlaying: Bool { box != nil }

    init(manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared) {
        self.manifest = manifest
        self.pool = pool
    }

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
        mountVideo(on: box)
    }

    /// `.once` termina en el acto si no hay video (manifest, política, pack): ahí queda la animación
    /// por código. Si termina sin haberse visto (el pool no lo dejó vivo), también.
    private func mountVideo(on box: SKSpriteNode) {
        let mount = MountState()
        let node = LoopingVideoNode(
            clip: .object("paquete_abre"), poster: PickupArt.texture(.package), size: box.size, role: .popup,
            playback: .once { [weak self] in
                if mount.isMounting {
                    mount.endedAtMount = true
                } else {
                    self?.videoEnded()
                }
            },
            manifest: manifest, pool: pool
        )
        node.zPosition = 0.5
        box.addChild(node)
        video = node
        node.setVisible(true)
        mount.isMounting = false
        if mount.endedAtMount {
            dropVideo()
        } else {
            lid?.isHidden = true
        }
    }

    private final class MountState {
        var isMounting = true
        var endedAtMount = false
    }

    private func videoEnded() {
        if video?.didShowVideo == true {
            finish()
        } else {
            dropVideo()
        }
    }

    /// Vuelve a la animación por código, desde el principio.
    private func dropVideo() {
        releaseVideo()
        lid?.isHidden = false
        elapsed = 0
        burstDone = false
    }

    private func releaseVideo() {
        video?.setVisible(false)
        video?.removeFromParent()
        video = nil
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let box, let lid else { return }
        if video != nil, reduceMotion { dropVideo() }
        elapsed += delta
        if video != nil {
            updateVideo()
            return
        }
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

    private func updateVideo() {
        if !burstDone, elapsed >= Self.videoBurstSeconds {
            burstDone = true
            onBurst?(point)
        }
        if elapsed >= Self.videoCapSeconds { finish() }
    }

    /// Se corta (el salto o el watchdog del turno): sin avisos. El cambio en
    /// vuelo lo asienta `GameState` (E1).
    func cancel() {
        releaseVideo()
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
