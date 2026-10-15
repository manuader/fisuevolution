import EconomyKit
import SpriteKit

/// Una caja del Paquete o el colchón, en el tablero. Todo lo que se mueve va por
/// frame (`update`): entra con un resorte, respira, y tiembla si se la toca sin
/// lugar. Si tiene clip de espera, lo reproduce en loop sobre su textura mientras la escena lo
/// pide (`setWaiting`), y sin video queda quieto. El clip es con alfa y encuadra distinto que el PNG:
/// el arte quieto se apaga mientras el video se ve, o la caja se dibuja dos veces (E14b B2).
@MainActor
final class PickupNode: SKNode {
    enum Kind: Equatable {
        case package
        case mattress
    }

    static let popSeconds: TimeInterval = 0.35
    static let shakeSeconds: TimeInterval = 0.4
    static let vanishSeconds: TimeInterval = 0.3
    /// El colchón pagado cae desde arriba al tablero (E14b B6, D3), y la caja que cae mientras se
    /// juega (B22).
    static let fallSeconds: TimeInterval = 0.55
    /// La caja abierta espera a que salga su empleado (E14b B23); si la llegada no juega en este
    /// tiempo, se va sola.
    static let openHoldSeconds: TimeInterval = 6
    /// Lo que la caja vacía se queda después de que el empleado saltó afuera, antes de irse.
    static let emptyLingerSeconds: TimeInterval = 0.35
    static let collapseSeconds: TimeInterval = 0.3
    private static let emptyKey = "empty"
    private static let collapseKey = "collapse"

    /// La capa de las cajas no suma profundidad: cada pieza lleva el z de su línea de apoyo
    /// (`DepthOrder`, E14b B19). Lo de adentro de la pieza se apila en pasos de `DepthOrder.innerStep`,
    /// para que su video no se dibuje encima de alguien parado delante.
    static let layerZ: CGFloat = 0
    /// El cartel «LLENO» es una etiqueta: va arriba de la multitud y de lo que se arrastra, como
    /// las etiquetas del campo.
    static let labelZ: CGFloat = 100

    let kind: Kind
    /// La caja del save que dibuja (E14b B18): su piso, a quién trae y dónde se para.
    var packageBox: PackageBox?
    private let sprite: SKSpriteNode
    private let waitingVideo: LoopingVideoNode?
    private let fullSign = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var age: TimeInterval = 0
    private var shakeLeft: TimeInterval = 0
    private let manifest: LoopsManifest
    private let pool: VideoPlayerPool
    private let packs: ArtPacks
    /// Los clips de la apertura en el tablero (E14b B5): la sacudida y, encima, la apertura.
    private var openingClips: [LoopingVideoNode] = []
    private(set) var isOpening = false
    /// La caja vacía se está yendo (B23): el resorte y la respiración ya no la mueven.
    private(set) var isCollapsing = false
    /// La caída que queda: desde qué altura y cuánto tiempo le falta.
    private var fall: (height: CGFloat, left: TimeInterval)?
    /// Cuánto más arriba de su lugar está mientras cae (0 quieto). Lo suma quien lo ubica.
    private(set) var fallOffset: CGFloat = 0

    init(kind: Kind, texture: SKTexture, side: CGFloat, waitingClip: ArtClip? = nil,
         manifest: LoopsManifest = .main, pool: VideoPlayerPool = .shared,
         packs: ArtPacks = .shared) {
        self.kind = kind
        self.manifest = manifest
        self.pool = pool
        self.packs = packs
        sprite = SKSpriteNode(texture: texture)
        waitingVideo = waitingClip.map {
            // El póster va transparente: el arte quieto es `sprite`, y dos copias del PNG se sumarían.
            LoopingVideoNode(clip: $0, poster: Self.clearTexture, size: .zero, role: .icon, manifest: manifest, pool: pool,
                             packs: packs)
        }
        super.init()
        addChild(sprite)
        if let waitingVideo {
            waitingVideo.zPosition = DepthOrder.innerStep
            addChild(waitingVideo)
        }
        fullSign.text = String(localized: "prize.package.full")
        fullSign.fontColor = UIColor(named: "PaletteOrange")
        fullSign.verticalAlignmentMode = .center
        fullSign.isHidden = true
        fullSign.zPosition = Self.labelZ
        addChild(fullSign)
        resize(side: side)
        setScale(0.01)
    }

    private static let clearTexture = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        .image { _ in })

    /// El tamaño del arte, sin escala: el ancho es el lado de la caja.
    var boxSize: CGSize { sprite.size }

    /// El arte quieto cede mientras el video (con alfa) se ve: 0 con el video a pleno.
    var staticArtAlpha: CGFloat { sprite.alpha }
    var staticArtTexture: SKTexture? { sprite.texture }

    func syncArt(videoAlpha: CGFloat) {
        sprite.alpha = 1 - min(1, max(0, videoAlpha))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resize(side: CGFloat) {
        let size = sprite.texture?.size() ?? CGSize(width: 1, height: 1)
        sprite.size = CGSize(width: side, height: side * size.height / max(size.width, 1))
        waitingVideo?.resize(sprite.size)
        for clip in openingClips { clip.resize(sprite.size) }
        fullSign.fontSize = side * 0.3
        fullSign.position = CGPoint(x: 0, y: sprite.size.height * 0.75)
    }

    private(set) var isWaiting = false
    var waitingVideoNode: LoopingVideoNode? { waitingVideo }

    /// Sólo la caja que está a la vista pide el cupo del pool; al salir o taparse lo suelta.
    func setWaiting(_ waiting: Bool) {
        let waiting = waiting && !isOpening
        guard waiting != isWaiting else { return }
        isWaiting = waiting
        waitingVideo?.setVisible(waiting)
    }

    /// Se va del tablero: suelta el video antes de salir de la escena.
    func retire() {
        setWaiting(false)
        stopOpeningClips()
        removeFromParent()
    }

    /// Los clips de la apertura en el tablero: la sacudida y la apertura de cada pieza.
    private var openingClipIDs: (shake: String, open: String) {
        switch kind {
        case .package: (shake: "paquete_sacude", open: "paquete_abre")
        case .mattress: (shake: "colchon_sacude", open: "colchon_abre")
        }
    }

    /// La caja (E14b B5, D2) o el colchón (B6, D3) se abren en el tablero: la sacudida y después la
    /// apertura, una pasada cada una, y `onOpened` cuando terminó de abrirse. Sin video (política
    /// quieta, pack sin bajar) los `.once` terminan en el acto: queda el temblor de siempre.
    func playOpening(onOpened: @escaping @MainActor () -> Void) {
        guard !isOpening else { return }
        isOpening = true
        setWaiting(false)
        shake()
        // La sacudida va con el rol de ícono; la apertura, con el de popup: con el mismo rol el pool
        // bajaría la sacudida antes de que la apertura asome, y la caja quieta se vería un instante.
        let clips = openingClipIDs
        startOpeningClip(clips.shake, role: .icon) { [weak self] in
            self?.startOpeningClip(clips.open, role: .popup) { onOpened() }
        }
    }

    /// No se pudo abrir (se llenó todo en el medio): vuelve a esperar.
    func cancelOpening() {
        stopOpeningClips()
        isOpening = false
        shake()
    }

    /// La caja abierta espera a su empleado (B23). Si la llegada no juega, se va sola.
    func holdOpen(reduceMotion: Bool) {
        run(.sequence([
            .wait(forDuration: Self.openHoldSeconds),
            .run { [weak self] in self?.collapse(reduceMotion: reduceMotion) },
        ]), withKey: Self.emptyKey)
    }

    /// El empleado ya saltó afuera: la caja vacía se queda un instante y se va achicándose; con
    /// Reduce Motion, se desvanece.
    func leaveEmpty(reduceMotion: Bool) {
        run(.sequence([
            .wait(forDuration: Self.emptyLingerSeconds),
            .run { [weak self] in self?.collapse(reduceMotion: reduceMotion) },
        ]), withKey: Self.emptyKey)
    }

    private func collapse(reduceMotion: Bool) {
        guard !isCollapsing else { return }
        isCollapsing = true
        let fade = SKAction.fadeOut(withDuration: Self.collapseSeconds)
        let shrink = SKAction.scale(to: 0.05, duration: Self.collapseSeconds)
        shrink.timingMode = .easeIn
        let out: SKAction = reduceMotion ? fade : .group([fade, shrink])
        run(.sequence([out, .run { [weak self] in self?.retire() }]), withKey: Self.collapseKey)
    }

    /// Ya salió el premio del colchón: el colchón abierto se desvanece y se va del tablero.
    func vanish(reduceMotion: Bool) {
        let fade = SKAction.fadeOut(withDuration: Self.vanishSeconds)
        let out: SKAction = reduceMotion ? fade : .group([fade, .scale(to: 1.15, duration: Self.vanishSeconds)])
        run(.sequence([out, .run { [weak self] in self?.retire() }]))
    }

    private func startOpeningClip(_ id: String, role: VideoRole, onEnd: @escaping @MainActor () -> Void) {
        let clip = LoopingVideoNode(clip: .object(id), poster: Self.clearTexture, size: sprite.size, role: role,
                                    playback: .once(onEnd: onEnd), manifest: manifest, pool: pool, packs: packs)
        clip.zPosition = DepthOrder.innerStep * CGFloat(2 + openingClips.count)
        addChild(clip)
        openingClips.append(clip)
        clip.setVisible(true)
    }

    private func stopOpeningClips() {
        for clip in openingClips {
            clip.stop()
            clip.removeFromParent()
        }
        openingClips.removeAll()
    }

    /// El clip que se ve tapa al de abajo: cuando la apertura ya está a pleno, la sacudida se suelta.
    private func settleOpeningClips() -> CGFloat {
        if let top = openingClips.last, top.videoAlpha >= 1, openingClips.count > 1 {
            for clip in openingClips.dropLast() {
                clip.stop()
                clip.removeFromParent()
            }
            openingClips = [top]
        }
        return openingClips.map(\.videoAlpha).max() ?? 0
    }

    /// El cartel "LLENO" (PLAN-v2 §2).
    var showsFull: Bool {
        get { !fullSign.isHidden }
        set { fullSign.isHidden = !newValue }
    }

    func shake() {
        shakeLeft = Self.shakeSeconds
    }

    /// Cae desde `height` puntos más arriba de su lugar, ya a tamaño completo, y tiembla al llegar.
    func drop(from height: CGFloat) {
        guard height > 0 else { return }
        age = max(age, Self.popSeconds)
        fall = (height: height, left: Self.fallSeconds)
        fallOffset = height
    }

    var isFalling: Bool { fall != nil }

    private func advanceFall(delta: TimeInterval, reduceMotion: Bool) {
        guard let current = fall else { return }
        let left = current.left - delta
        guard left > 0, !reduceMotion else {
            fall = nil
            fallOffset = 0
            if !reduceMotion { shake() }
            return
        }
        fall = (height: current.height, left: left)
        let progress = 1 - left / Self.fallSeconds
        fallOffset = current.height * CGFloat(1 - progress * progress)
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        syncArt(videoAlpha: isOpening ? settleOpeningClips() : waitingVideo?.videoAlpha ?? 0)
        advanceFall(delta: delta, reduceMotion: reduceMotion)
        age += delta
        guard !isCollapsing else { return }
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

    /// `point` en las coordenadas del padre, con un margen generoso para el dedo: el
    /// área crece con la caja (8 pt de aire) y nunca baja de `minTouchSide` (C10).
    func hitTest(_ point: CGPoint) -> Bool {
        var area = calculateAccumulatedFrame().insetBy(dx: -8, dy: -8)
        let missingWidth = max(0, PickupLayout.minTouchSide - area.width)
        let missingHeight = max(0, PickupLayout.minTouchSide - area.height)
        area = area.insetBy(dx: -missingWidth / 2, dy: -missingHeight / 2)
        return area.contains(point)
    }
}
