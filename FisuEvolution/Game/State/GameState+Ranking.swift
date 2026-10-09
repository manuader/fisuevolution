import EconomyKit
import Foundation

/// El ranking de la llegada a Dios (E12): el `GameState` guarda el `RankingState` en `meta.ranking`
/// y avisa al `RankingStore` de los cuatro momentos que le importan. La lógica vive en el store.
extension GameState: RankingStateHost {
    var rankingState: RankingState? { player?.meta.ranking }

    /// El tier de Dios: el más alto del contenido.
    var godTier: Int? { content?.tiers.maxTier }

    func updateRanking(_ change: (inout RankingState) -> Void) {
        guard var player else { return }
        change(&player.meta.ranking)
        self.player = player
        scheduleSave()
    }

    /// Un arranque en frío también es volver a `.active` (`onChange(of: scenePhase)` no dispara para el
    /// estado inicial).
    func attachRanking(_ store: RankingStore) {
        ranking = store
        store.host = self
        rankingReconcile()
        if isSceneActive { rankingBecameActive() }
    }

    /// Con el tutorial en curso la partida todavía no empezó: ni se registra ni se cuenta el tiempo.
    func rankingBecameActive() {
        guard !tutorialPhaseActive else { return }
        ranking?.becameActive()
    }

    /// El núcleo del tutorial es el inicio de la partida rankeada.
    func rankingCoreFinished() {
        guard let ranking else { return }
        ranking.newGameStarted()
        if isSceneActive { ranking.becameActive() }
    }

    /// Al adjuntar el store: una sesión huérfana (cierre a la fuerza) no se cuenta, y una llegada a Dios que
    /// quedó sin registrar se registra.
    func rankingReconcile() {
        guard let godTier, let state = rankingState else { return }
        if state.activeSince != nil { updateRanking { $0.activeSince = nil } }
        if case .running = state.phase, player?.run.maxTierReached ?? 0 >= godTier { ranking?.reachedGod() }
    }
}
