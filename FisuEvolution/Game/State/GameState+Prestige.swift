import EconomyKit
import Foundation

/// Reencarnación (F7: gate por ORO). Separado de `GameState.swift` para que el
/// frente de prestigio no comparta archivo con los otros cinco dominios.
extension GameState {
    /// ORO que ganarías reencarnando ahora.
    var prestigeOroGained: Int {
        guard let economy, let player else { return 0 }
        return PrestigeCalculator.oroGained(state: player, economy: economy)
    }

    func confirmPrestige() {
        guard let economy, let content, var player = player,
              PrestigeCalculator.canReincarnate(state: player, economy: economy)
        else { return }
        PrestigeCalculator.applyReincarnation(
            state: &player,
            economy: economy,
            tiers: content.tiers,
            floorTable: content.floorTable,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        reconcileTower()
        audio?.play(.prestige)
        haptics?.play(.rarity)
        gameCenter?.report(.firstPrestige)
        bumpBoard()
        Task { await persistNow() }
        Log.economy.info("reincarnated: level \(player.meta.prestigeLevel), oro \(player.meta.oro)")
    }
}
