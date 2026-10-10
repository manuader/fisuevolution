import EconomyKit
import Foundation

/// La tienda de ORO en la partida (PLAN-v2 E6): los ×3 comprados que esperan su
/// momento y el auto-tap.
extension GameState {
    /// El Offline ×3 comprado multiplica la vuelta que muestra el popup y se
    /// consume ahí. Una ausencia corta, que se acredita en silencio, no lo gasta:
    /// el jugador lo compró para ver el número grande.
    func applyPendingOfflineMultiplier(to amount: Double) -> Double {
        guard amount > 0, var player, let multiplier = player.meta.engagement.shop.pendingOfflineMultiplier else {
            return amount
        }
        let extra = amount * (multiplier - 1)
        player.run.coins += extra
        player.meta.lifetimeEarnings += extra
        player.meta.engagement.shop.pendingOfflineMultiplier = nil
        self.player = player
        Log.economy.info("offline ×\(multiplier) from the oro shop: +\(extra)")
        return amount + extra
    }

    /// El Diario ×3 multiplica la plata del próximo diario. Un día que da un
    /// especial o un cofre no lo gasta: espera al que pague plata.
    func applyPendingDailyMultiplier(to claim: DailyRewardManager.Claim) -> DailyRewardManager.Claim {
        guard claim.coinsGranted > 0, var player,
              let multiplier = player.meta.engagement.shop.pendingDailyMultiplier
        else { return claim }
        let extra = claim.coinsGranted * (multiplier - 1)
        player.run.coins += extra
        player.meta.lifetimeEarnings += extra
        player.meta.engagement.shop.pendingDailyMultiplier = nil
        self.player = player
        return DailyRewardManager.Claim(
            day: claim.day,
            coinsGranted: claim.coinsGranted + extra,
            specialGranted: claim.specialGranted,
            chestGranted: claim.chestGranted
        )
    }

    /// Los toques automáticos. Lo llama `advanceEngagement` con el delta del tick
    /// (juego activo, con tope de 2 s). No espera a `engagementAutorun`: es un
    /// efecto que el jugador compró, no un motor que aparece solo.
    func advanceAutoTap(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let economy, var player else { return }
        let paid = AutoTapper.advance(
            state: &player, delta: delta, now: now,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy
        )
        guard paid > 0 else { return }
        self.player = player
    }
}
