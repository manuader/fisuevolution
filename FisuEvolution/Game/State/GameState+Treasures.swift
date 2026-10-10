import EconomyKit
import Foundation

/// Lo que salió de un colchón, ya acreditado.
struct MattressOutcome: Equatable {
    let prizeId: String
    let rewards: [RewardSpec]
    /// La plata acreditada (0 si el premio no era plata).
    let coins: Double
    /// Los "otro colchón" que le quedan.
    let extraOpensLeft: Int
}

/// El Colchón en la partida (PLAN-v2 E5): "tus empleados escondieron plata en
/// el colchón". Se abre sólo con video; lo llama la vista al terminar.
extension GameState {
    var mattressWaiting: Bool { player?.meta.engagement.treasures.waiting ?? false }

    var mattressExtraOpensLeft: Int { player?.meta.engagement.treasures.extraOpensLeft ?? 0 }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advanceTreasures(delta: TimeInterval) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let appeared = TreasureScheduler.advance(&player.meta.engagement.treasures, delta: delta, config: content.treasures)
        self.player = player
        guard appeared else { return }
        Log.economy.info("mattress appeared")
        scheduleSave()
    }

    /// Después del video: sortea, acredita y habilita "otro colchón".
    @discardableResult
    func openMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, player?.meta.engagement.treasures.waiting == true,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player
        else { return nil }
        TreasureScheduler.markOpened(&player.meta.engagement.treasures, config: content.treasures)
        self.player = player
        return deliver(prize, now: now)
    }

    /// Después del segundo video: otro sorteo, una vez por colchón.
    @discardableResult
    func openExtraMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, player?.meta.engagement.treasures.extraOpensLeft ?? 0 > 0,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player
        else { return nil }
        player.meta.engagement.treasures.extraOpensLeft -= 1
        self.player = player
        return deliver(prize, now: now)
    }

    /// El colchón ya quedó gastado: acredita su premio por el único punto de premios.
    private func deliver(_ prize: TreasuresConfig.Prize, now: TimeInterval) -> MattressOutcome {
        let coins = grant(prize.rewards, source: "treasure.\(prize.id)", now: now)
        Log.economy.info("mattress opened: \(prize.id)")
        return MattressOutcome(prizeId: prize.id, rewards: prize.rewards, coins: coins, extraOpensLeft: mattressExtraOpensLeft)
    }

    #if DEBUG
    func debugSpawnMattress() {
        guard var player else { return }
        player.meta.engagement.treasures.waiting = true
        player.meta.engagement.treasures.extraOpensLeft = 0
        self.player = player
    }
    #endif
}
