import SpriteKit
import UIKit

/// Pool de `SKEmitterNode` precargados (bible §4.2: partículas pooled, cero
/// allocations por evento). Los emitters se construyen en código en vez de .sks:
/// mismos visuales, pero versionables y diffeables — decisión documentada del plan.
@MainActor
final class ParticlePool {
    enum EffectType: CaseIterable {
        case tap
        case merge
        case evolution
        case coins
    }

    /// El toggle de Ajustes (spec §10.4). `nonisolated` porque lo lee también el
    /// `@AppStorage` de `SettingsView`, que se inicializa fuera del main actor.
    nonisolated static let particlesDefaultsKey = "settings.particlesEnabled"

    /// ⚠️ **El default es `true` y por eso esto es una función y no un
    /// `bool(forKey:)` pelado**: `UserDefaults.bool(forKey:)` devuelve `false`
    /// cuando la clave no existe, así que preguntarlo directo dejaría el juego
    /// SIN partículas en la primera partida de todos los jugadores, con el
    /// toggle mostrando lo contrario.
    nonisolated static func particlesEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: particlesDefaultsKey) == nil
            ? true
            : defaults.bool(forKey: particlesDefaultsKey)
    }

    private var pools: [EffectType: [SKEmitterNode]] = [:]
    private static let particleTexture: SKTexture = {
        let side: CGFloat = 12
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return SKTexture(image: image)
    }()

    /// Precarga N emitters por tipo para que el primer uso no aloque.
    func preheat(countPerType: Int = 3) {
        for type in EffectType.allCases {
            var pool = pools[type] ?? []
            while pool.count < countPerType {
                pool.append(makeEmitter(type))
            }
            pools[type] = pool
        }
    }

    /// Dispara un burst en `position`; el emitter vuelve solo al pool.
    ///
    /// ⚠️ **Con las partículas apagadas se sale acá y no antes.** El corte va en
    /// el pool y no en cada llamador (`BoardScene` tiene cinco) para que apagar
    /// las partículas sea exactamente eso: el tap sigue pagando, el merge sigue
    /// fusionando y la evolución sigue subiendo de piso. Es efecto, no lógica.
    ///
    /// La lectura de `UserDefaults` es un lookup en memoria y el ritmo de esto lo
    /// pone el dedo del jugador (un burst por toque, por fusión o por ascenso),
    /// no el frame loop: no hay nada que cachear.
    func emit(_ type: EffectType, at position: CGPoint, in parent: SKNode) {
        guard Self.particlesEnabled() else { return }
        let emitter = pools[type]?.popLast() ?? makeEmitter(type)
        emitter.position = position
        emitter.zPosition = 90
        emitter.resetSimulation()
        parent.addChild(emitter)

        let lifetime = TimeInterval(emitter.particleLifetime + 0.3)
        emitter.run(.sequence([
            .wait(forDuration: lifetime),
            .run { [weak self, weak emitter] in
                guard let emitter else { return }
                emitter.removeFromParent()
                self?.pools[type, default: []].append(emitter)
            },
        ]))
    }

    private func makeEmitter(_ type: EffectType) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.particleTexture
        emitter.particleBlendMode = .alpha
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlphaSpeed = -1.6

        switch type {
        case .tap:
            emitter.numParticlesToEmit = 6
            emitter.particleBirthRate = 200
            emitter.particleLifetime = 0.4
            emitter.particleSpeed = 90
            emitter.particleScale = 0.35
            emitter.particleScaleSpeed = -0.6
            emitter.particleColor = Palette.yellow
            emitter.particleColorBlendFactor = 1
        case .merge:
            emitter.numParticlesToEmit = 14
            emitter.particleBirthRate = 400
            emitter.particleLifetime = 0.55
            emitter.particleSpeed = 140
            emitter.particleScale = 0.5
            emitter.particleScaleSpeed = -0.8
            emitter.particleColor = SKColor(named: "PaletteOrange") ?? .orange
            emitter.particleColorBlendFactor = 1
        case .evolution:
            emitter.numParticlesToEmit = 30
            emitter.particleBirthRate = 800
            emitter.particleLifetime = 0.9
            emitter.particleSpeed = 200
            emitter.particleSpeedRange = 80
            emitter.particleScale = 0.6
            emitter.particleScaleSpeed = -0.5
            emitter.particleColor = SKColor(named: "PalettePink") ?? .magenta
            emitter.particleColorBlendFactor = 1
        case .coins:
            emitter.numParticlesToEmit = 10
            emitter.particleBirthRate = 300
            emitter.particleLifetime = 0.7
            emitter.particleSpeed = 110
            emitter.yAcceleration = -260
            emitter.particleScale = 0.45
            emitter.particleScaleSpeed = -0.4
            emitter.particleColor = Palette.yellow
            emitter.particleColorBlendFactor = 1
        }
        return emitter
    }
}
