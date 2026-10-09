import EconomyKit
import Foundation

/// El único punto donde la 2.0 entrega un premio (PLAN-v2, "Cimientos
/// compartidos"): visitantes, eventos y, después, ruleta, colchón, tienda y
/// ofertas pasan por acá. `multiplier` es el "×2 con video".
extension GameState {
    /// Lo que este punto ya sabe dar. E5 suma `.package` y `.wheelSpin`; E6,
    /// `.autoTap`, los multiplicadores del próximo offline y diario y `.extraSlots`.
    /// Un guion o un evento que da algo de afuera de esta lista **no se ofrece**
    /// (`VisitorScheduler`, `eventIsApplicable`): mejor que no venga a que prometa
    /// y no cumpla.
    static let grantableRewardKinds: Set<RewardSpec.Kind> = [
        .coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity,
    ]

    /// Un momento en que algo puede aparecer solo sin pisar al jugador: el tablero
    /// a la vista (escena activa, sin hoja, sin ficha, sin carrera), sin
    /// celebración en pantalla y fuera de la fase obligatoria del tutorial.
    var isCalmMoment: Bool {
        phase == .ready && isSceneActive && !uiCoversBoard && celebrations.current == nil
            && !tutorialPhaseActive && characterSheet == nil && careerPrompt == nil
    }

    /// Cuánto vale un segundo de producción ahora: la misma base que los premios de
    /// logros (`coinReward`), con su piso del "trabajador solitario".
    var coinsPerProductionSecond: Double {
        guard let content, let economy, let player else { return 0 }
        return Self.coinReward(seconds: 1, player: player, content: content, economy: economy)
    }

    @discardableResult
    func grant(
        _ rewards: [RewardSpec],
        multiplier: Int = 1,
        source: String,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Double {
        rewards.reduce(0) { total, reward in
            total + grant(reward, multiplier: multiplier, source: source, now: now)
        }
    }

    /// Entrega UN premio. Devuelve la plata acreditada (0 si no era plata).
    @discardableResult
    func grant(
        _ reward: RewardSpec,
        multiplier: Int = 1,
        source: String,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Double {
        guard Self.grantableRewardKinds.contains(reward.kind) else {
            Log.economy.error("reward not grantable yet: \(reward.kind.rawValue) from \(source)")
            return 0
        }
        guard let content, let economy, var player else { return 0 }
        var credited = 0.0
        switch reward.scaled(by: multiplier) {
        case .coinsSeconds(let seconds):
            credited = Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
            player.run.coins += credited
            player.meta.lifetimeEarnings += credited
        case .oro(let amount):
            // Sólo el balance, como logros y tienda: `oroEarnedLifetime` alimenta el
            // multiplicador global y eso lo gana el prestigio.
            player.meta.oro += amount
        case .skinChest(let count):
            player.meta.chestsPending += count
        case let .modifier(effect, magnitude, seconds):
            player.run.activeModifiers.append(ActiveModifier(
                effect: effect, magnitude: magnitude, expiresAt: now + seconds, sourceKey: source
            ))
        case .clearBoostCooldowns:
            player.meta.boostActivations.removeAll()
        case .eventImmunity(let seconds):
            player.run.activeModifiers.append(ActiveModifier(
                effect: .eventImmunity, magnitude: 1, expiresAt: now + seconds, sourceKey: source
            ))
        case .package, .wheelSpin, .autoTap, .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots:
            return 0
        }
        self.player = player
        effectsVersion += 1
        if credited > 0 { audio?.play(.coin) }
        refreshProjections()
        scheduleSave()
        Log.economy.info("reward granted: \(reward.kind.rawValue) ×\(multiplier) from \(source)")
        return credited
    }

    /// Plata ya cotizada (la oferta de un visitante se cotiza al llegar).
    func creditCoins(_ amount: Double) {
        guard amount != 0, var player else { return }
        player.run.coins += amount
        if amount > 0 { player.meta.lifetimeEarnings += amount }
        self.player = player
        refreshProjections()
        scheduleSave()
    }
}
