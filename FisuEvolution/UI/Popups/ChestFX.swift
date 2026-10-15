import EconomyKit
import SwiftUI

/// Una partícula del cofre: estrella, chispa, papelito o polvo. Pura (sin
/// reloj): su estado en el segundo `t` lo calcula `ChestFX.state`.
struct ChestParticle: Equatable, Sendable {
    enum Shape: Equatable, Sendable { case star, spark, confetti, dust }

    var shape: Shape
    var colorAsset: String
    var origin: CGPoint
    var velocity: CGVector
    var gravity: CGFloat
    var spin: Double
    var size: CGFloat
    var life: Double
    var delay: Double = 0
}

/// Las partículas del cofre (r56): cuántas, de qué colores y cómo vuelan. Todo
/// determinista (semilla fija) para que los tests lo pineen y dos cofres
/// iguales se vean iguales.
enum ChestFX {
    /// El tope de partículas por emisión. El SE (el escalón conservador del
    /// pool de video) dibuja menos: lo que se ahorra en el `Canvas` lo usa el
    /// decodificador de la apertura.
    struct Budget: Equatable, Sendable {
        let tap: Int
        let burst: Int
        let dust: Int
    }

    static let fullBudget = Budget(tap: 10, burst: 44, dust: 12)
    static let conservativeBudget = Budget(tap: 6, burst: 26, dust: 8)

    static func budget(maxLiveVideos: Int) -> Budget {
        maxLiveVideos <= VideoPlayerPool.conservativeMaxLive ? conservativeBudget : fullBudget
    }

    /// Lo más largo que vive una partícula, con su retardo: la capa se apaga
    /// pasado esto.
    static let maxLifetime: Double = 1.9

    private static let party = ["PaletteYellow", "PaletteOrange", "PalettePink", "PaletteBlue", "PaletteGreen"]

    /// Las chispas de un toque: salen de la cerradura hacia arriba y a los
    /// costados, más y más lejos con cada toque (1, 2, 3).
    static func tapSparks(tap: Int, at origin: CGPoint, budget: Budget) -> [ChestParticle] {
        var rng = ChestRandom(seed: UInt64(1_000 + tap))
        let strength = CGFloat(min(max(tap, 1), 3))
        let count = min(budget.tap, 4 + 2 * Int(strength))
        return (0..<count).map { index in
            let angle = -Double.pi / 2 + Double.random(in: -1.25...1.25, using: &rng)
            let speed = CGFloat.random(in: 150...240, using: &rng) * (0.8 + 0.2 * strength)
            return ChestParticle(
                shape: index.isMultiple(of: 3) ? .star : .spark,
                colorAsset: index.isMultiple(of: 2) ? "PaletteYellow" : "PaletteCream",
                origin: origin,
                velocity: CGVector(dx: CGFloat(cos(angle)) * speed, dy: CGFloat(sin(angle)) * speed),
                gravity: 520,
                spin: Double.random(in: -360...360, using: &rng),
                size: CGFloat.random(in: 7...12, using: &rng),
                life: Double.random(in: 0.45...0.7, using: &rng)
            )
        }
    }

    /// El estallido de la apertura: estrellas del color de la rareza y
    /// papelitos de la casa, en abanico hacia arriba, con gravedad.
    static func burst(rarity: SkinsConfig.Rarity, at origin: CGPoint, budget: Budget) -> [ChestParticle] {
        var rng = ChestRandom(seed: 4_242)
        let rarityAsset = ChestCardStyle.glowAsset(rarity)
        return (0..<budget.burst).map { index in
            let angle = -Double.pi / 2 + Double.random(in: -1.45...1.45, using: &rng)
            let speed = CGFloat.random(in: 260...520, using: &rng)
            let isStar = index % 3 != 2
            return ChestParticle(
                shape: isStar ? .star : .confetti,
                colorAsset: isStar && index.isMultiple(of: 2) ? rarityAsset : party[index % party.count],
                origin: origin,
                velocity: CGVector(dx: CGFloat(cos(angle)) * speed, dy: CGFloat(sin(angle)) * speed),
                gravity: 620,
                spin: Double.random(in: -540...540, using: &rng),
                size: isStar ? CGFloat.random(in: 10...18, using: &rng) : CGFloat.random(in: 8...12, using: &rng),
                life: Double.random(in: 1.1...1.6, using: &rng),
                delay: Double(index % 4) * 0.025
            )
        }
    }

    /// La nube de polvo de la caída: bocanadas que se abren a ras del piso,
    /// desde los dos pies del cofre hacia afuera.
    static func dust(at origin: CGPoint, budget: Budget) -> [ChestParticle] {
        var rng = ChestRandom(seed: 77)
        return (0..<budget.dust).map { index in
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            return ChestParticle(
                shape: .dust,
                colorAsset: index % 3 == 0 ? "PaletteCream" : "PaletteBrown",
                origin: CGPoint(x: origin.x + side * CGFloat.random(in: 70...120, using: &rng),
                                y: origin.y - CGFloat.random(in: 0...14, using: &rng)),
                velocity: CGVector(dx: side * CGFloat.random(in: 90...190, using: &rng),
                                   dy: -CGFloat.random(in: 20...70, using: &rng)),
                gravity: 0,
                spin: 0,
                size: CGFloat.random(in: 26...44, using: &rng),
                life: Double.random(in: 0.5...0.75, using: &rng),
                delay: Double(index / 2) * 0.02
            )
        }
    }

    struct State: Equatable {
        var position: CGPoint
        var rotation: Double
        var scale: CGFloat
        var opacity: Double
    }

    /// Dónde está la partícula a los `t` segundos de su emisión; `nil` si
    /// todavía no salió o ya se apagó.
    static func state(of particle: ChestParticle, at t: Double) -> State? {
        let local = t - particle.delay
        guard local >= 0, local < particle.life else { return nil }
        let time = CGFloat(local)
        let drag: CGFloat = particle.shape == .dust ? 2.4 : 0.9
        let travel = (1 - exp(-drag * time)) / drag
        let position = CGPoint(
            x: particle.origin.x + particle.velocity.dx * travel,
            y: particle.origin.y + particle.velocity.dy * travel + 0.5 * particle.gravity * time * time
        )
        let progress = local / particle.life
        let scale: CGFloat = switch particle.shape {
        case .dust: 0.5 + 1.1 * CGFloat(progress)
        default: progress < 0.15 ? CGFloat(0.4 + progress / 0.15 * 0.6) : 1
        }
        let opacity = particle.shape == .dust
            ? 0.45 * (1 - progress)
            : (progress < 0.7 ? 1 : max(0, 1 - (progress - 0.7) / 0.3))
        return State(position: position, rotation: particle.spin * local, scale: scale, opacity: opacity)
    }
}

/// Un generador con semilla (SplitMix64): `SystemRandomNumberGenerator` no
/// repite, y las partículas tienen que salir iguales cada vez.
struct ChestRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Una tanda de partículas con su hora de salida.
struct ChestEmission: Identifiable {
    let id = UUID()
    let start: Date
    let particles: [ChestParticle]
}

/// Las partículas del cofre en UN `Canvas`: dibujar 50 formas por cuadro en una
/// sola capa cuesta mucho menos que 50 vistas animadas. El reloj corre sólo
/// mientras hay emisiones vivas.
struct ChestParticleField: View {
    let emissions: [ChestEmission]

    var body: some View {
        TimelineView(.animation(paused: emissions.isEmpty)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for emission in emissions {
                    let t = timeline.date.timeIntervalSince(emission.start)
                    for particle in emission.particles {
                        guard let state = ChestFX.state(of: particle, at: t) else { continue }
                        draw(particle, state, in: &context, center: center)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ particle: ChestParticle, _ state: ChestFX.State,
                      in context: inout GraphicsContext, center: CGPoint) {
        var layer = context
        layer.opacity = state.opacity
        layer.translateBy(x: center.x + state.position.x, y: center.y + state.position.y)
        layer.rotate(by: .degrees(state.rotation))
        layer.scaleBy(x: state.scale, y: state.scale)
        let side = particle.size
        let fill = Color(particle.colorAsset)
        let ink = Color("PaletteInk")
        switch particle.shape {
        case .star:
            let path = ChestStar().path(in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
            layer.fill(path, with: .color(fill))
            layer.stroke(path, with: .color(ink), lineWidth: 1.6)
        case .spark:
            let path = Path(ellipseIn: CGRect(x: -side / 4, y: -side / 2, width: side / 2, height: side))
            layer.fill(path, with: .color(fill))
            layer.stroke(path, with: .color(ink), lineWidth: 1.2)
        case .confetti:
            let path = Path(roundedRect: CGRect(x: -side / 2, y: -side / 4, width: side, height: side / 2),
                            cornerRadius: 1.5)
            layer.fill(path, with: .color(fill))
            layer.stroke(path, with: .color(ink), lineWidth: 1.2)
        case .dust:
            layer.fill(Path(ellipseIn: CGRect(x: -side / 2, y: -side / 2, width: side, height: side)),
                       with: .color(fill))
        }
    }
}

/// La estrella de cinco puntas de las chispas.
struct ChestStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                                y: center.y + radius * CGFloat(sin(angle)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// La onda de choque: un aro que se abre y se apaga, con su contorno de tinta.
/// Cada cambio de `trigger` dispara uno.
struct ChestShockwave: View {
    let trigger: Int
    let tint: Color
    var reach: CGFloat = 1

    var body: some View {
        Circle()
            .strokeBorder(tint, lineWidth: 10)
            .overlay(Circle().strokeBorder(Color("PaletteInk").opacity(0.7), lineWidth: 2))
            .keyframeAnimator(initialValue: Ring(), trigger: trigger) { content, ring in
                content
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.15, duration: 0.001)
                    CubicKeyframe(reach, duration: 0.45)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(trigger == 0 ? 0 : 0.95, duration: 0.001)
                    LinearKeyframe(0.9, duration: 0.15)
                    CubicKeyframe(0, duration: 0.3)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    struct Ring {
        var scale: CGFloat = 0.15
        var opacity: Double = 0
    }
}
