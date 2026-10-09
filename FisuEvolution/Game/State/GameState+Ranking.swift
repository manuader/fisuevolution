import EconomyKit
import Foundation

/// El `GameState` guarda la partida rankeada en `meta.ranking` (E12); el `RankingStore` la lee y la muta por acá.
extension GameState: RankingStateHost {
    var rankingState: RankingState? { player?.meta.ranking }

    /// Todavía sin uso: el tier de Dios llega con la config remota (E12 T16).
    var godTier: Int? { nil }

    func updateRanking(_ change: (inout RankingState) -> Void) {
        guard var ranking = player?.meta.ranking else { return }
        change(&ranking)
        player?.meta.ranking = ranking
        scheduleSave()
    }
}
