import SpriteKit

/// Lo que los eventos le hacen a la escena (PLAN-v2 E4): el velo y las velitas
/// del Apagón, el baile y el confeti de los Campeones. Colaborador de
/// `BoardScene`, como `StageController`: todo por frame, probado sin vista.
@MainActor
final class StageEffects {
    /// Encima del tablero y DEBAJO del escenario (190): el presentador del Apagón
    /// se ve aunque esté oscuro.
    static let layerZ: CGFloat = 185
    static let maxVeilAlpha: CGFloat = 0.62
    static let confettiEvery: TimeInterval = 1.2
    /// El balanceo del baile: radianes y vaivenes por segundo.
    static let danceAngle: CGFloat = 0.12
    static let danceRate: Double = 1.6

    let layer = SKNode()
    private weak var gameState: GameState?
    private let veil = SKSpriteNode(color: .black, size: .zero)
    private var candles: [SKNode] = []
    private let particles = ParticlePool()
    private var sceneSize = CGSize(width: 393, height: 852)
    private var bottomInset: CGFloat = 118
    private var clock: TimeInterval = 0
    private var confettiClock: TimeInterval = 0
    private(set) var veilAlpha: CGFloat = 0
    private(set) var litCandles = 0
    private(set) var isDancing = false

    init(gameState: GameState) {
        self.gameState = gameState
        layer.zPosition = Self.layerZ
        layer.name = "stage.effects"
        veil.anchorPoint = .zero
        veil.alpha = 0
        layer.addChild(veil)
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat) {
        self.sceneSize = sceneSize
        self.bottomInset = bottomInset
        veil.size = sceneSize
        candles.forEach { $0.removeFromParent() }
        candles = []
    }

    /// `units`: los personajes del piso visible (los pasa la escena, que es su dueña).
    func update(delta: TimeInterval, reduceMotion: Bool, units: [SKNode]) {
        clock += delta
        let scenes = gameState?.runningEventScenes() ?? []
        updateBlackout(reduceMotion: reduceMotion)
        updateChampions(scenes.contains(.champions) && !reduceMotion, delta: delta, units: units)
    }

    // MARK: Apagón

    private func updateBlackout(reduceMotion: Bool) {
        guard let state = gameState?.blackoutCandles() else {
            veilAlpha = 0
            veil.alpha = 0
            litCandles = 0
            candles.forEach { $0.isHidden = true }
            return
        }
        litCandles = state.lit
        veilAlpha = Self.maxVeilAlpha * (1 - CGFloat(state.lit) / CGFloat(state.total))
        veil.alpha = veilAlpha
        if candles.count != state.total { buildCandles(count: state.total) }
        for (index, candle) in candles.enumerated() {
            candle.isHidden = false
            let flame = candle.childNode(withName: "flame")
            let isLit = index < state.lit
            flame?.alpha = isLit ? 1 : 0
            if isLit, !reduceMotion {
                flame?.setScale(1 + 0.12 * CGFloat(sin(clock * 9 + Double(index))))
            }
        }
    }

    private func buildCandles(count: Int) {
        candles.forEach { $0.removeFromParent() }
        let spacing = sceneSize.width * 0.44 / CGFloat(max(count - 1, 1))
        let startX = sceneSize.width * 0.28
        candles = (0..<count).map { index in
            let candle = SKNode()
            candle.position = CGPoint(x: startX + CGFloat(index) * spacing, y: bottomInset + 6)
            let stick = SKShapeNode(rectOf: CGSize(width: 6, height: 16), cornerRadius: 2)
            stick.fillColor = Palette.cream
            stick.strokeColor = Palette.ink
            stick.lineWidth = 1
            stick.position = CGPoint(x: 0, y: 8)
            candle.addChild(stick)
            let flame = SKShapeNode(ellipseOf: CGSize(width: 8, height: 12))
            flame.name = "flame"
            flame.fillColor = Palette.yellow
            flame.strokeColor = SKColor(named: "PaletteOrange") ?? .orange
            flame.glowWidth = 4
            flame.position = CGPoint(x: 0, y: 22)
            flame.alpha = 0
            candle.addChild(flame)
            layer.addChild(candle)
            return candle
        }
    }

    // MARK: Campeones

    private func updateChampions(_ active: Bool, delta: TimeInterval, units: [SKNode]) {
        guard active else {
            if isDancing {
                units.forEach { $0.zRotation = 0 }
                isDancing = false
            }
            return
        }
        isDancing = true
        for (index, unit) in units.enumerated() {
            unit.zRotation = Self.danceAngle * CGFloat(sin(clock * 2 * .pi * Self.danceRate + Double(index) * 0.9))
        }
        confettiClock += delta
        if confettiClock >= Self.confettiEvery {
            confettiClock = 0
            let x = CGFloat.random(in: sceneSize.width * 0.15...sceneSize.width * 0.85)
            particles.emit(.confetti, at: CGPoint(x: x, y: sceneSize.height - 60), in: layer)
        }
    }
}
