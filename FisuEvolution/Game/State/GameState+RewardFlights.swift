import EconomyKit
import Foundation

/// El aviso de cada fuente de recompensa a la capa de vuelos (E14b B13). Se llama
/// **después** de acreditar: `grant` y la plata ya están en el saldo, esto sólo
/// hace que se vean llegar. El saldo final es el mismo con y sin animación.
extension GameState {
    /// `coins` es la plata ya acreditada (lo que devolvió `grant` más lo que se cobró
    /// aparte); `multiplier` el mismo ×2 con que se entregó `rewards`.
    func announceReward(
        _ rewards: [RewardSpec],
        coins: Double = 0,
        multiplier: Int = 1,
        from origin: RewardFlightOrigin = .popup,
        after delay: TimeInterval = RewardFlightTiming.defaultDelay
    ) {
        RewardFlightCenter.shared.launch(
            RewardFlightPlan.items(for: rewards, multiplier: multiplier, coins: coins), from: origin, after: delay
        )
    }

    func announceReward(
        _ reward: RewardSpec,
        coins: Double = 0,
        from origin: RewardFlightOrigin = .popup,
        after delay: TimeInterval = RewardFlightTiming.defaultDelay
    ) {
        announceReward([reward], coins: coins, from: origin, after: delay)
    }

    func announceCoins(
        _ amount: Double,
        from origin: RewardFlightOrigin = .popup,
        after delay: TimeInterval = RewardFlightTiming.defaultDelay
    ) {
        announceReward([], coins: amount, from: origin, after: delay)
    }

    func announceBlue(
        _ amount: Int,
        from origin: RewardFlightOrigin = .popup,
        after delay: TimeInterval = RewardFlightTiming.defaultDelay
    ) {
        announceReward([.oro(amount)], from: origin, after: delay)
    }
}
