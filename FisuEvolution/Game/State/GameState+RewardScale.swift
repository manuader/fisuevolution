import EconomyKit
import Foundation

/// Los premios en minutos de producción (PLAN-v2 E2a): todo lo que paga "N
/// minutos" pasa por acá, y la cuenta vive en `RewardScale` (EconomyKit).
extension GameState {
    static func coinPayout(minutes: Double, player: PlayerState, content: GameContent) -> Double {
        RewardScale.coinPayout(
            minutes: minutes, state: player, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy
        )
    }
}
