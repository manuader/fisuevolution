import EconomyKit
import Foundation

/// Compartir los momentos virales (PLAN-v2 E3): se encolan donde pasan, se
/// ofrecen en una pausa como botón (nunca un popup) y pagan una vez por momento.
extension GameState {
    /// Un momento nuevo. Uno ya compartido no se ofrece más; si ya hay uno
    /// esperando, queda el más grande.
    func queueShareMoment(_ moment: ShareMoment) {
        guard shareOffersEnabled, let player,
              !player.meta.engagement.sharedMoments.contains(moment.key)
        else { return }
        if let pending = pendingShareMoment, pending.weight > moment.weight { return }
        pendingShareMoment = moment
    }

    /// Lo llama `refreshProjections`: el momento pendiente pasa a oferta en una
    /// pausa natural (`isCalmMoment`: sin celebración, sin hoja, sin la fase del
    /// tutorial) y sin otra tarjeta u oferta en pantalla.
    func presentShareMomentIfCalm() {
        guard let moment = pendingShareMoment, shareOffer == nil, shareCardMoment == nil,
              isCalmMoment
        else { return }
        pendingShareMoment = nil
        shareOffer = moment
    }

    /// El reveal de un tier (lo llama `markRevealed`): personaje nuevo, o Dios.
    func noteRevealedTier(_ tier: Int) {
        guard let content, let player else { return }
        let candidates = content.tiers.concreteTypes.filter { $0.tier == tier }
        guard let type = candidates.first(where: { player.run.seenTypes.contains($0.id) }) ?? candidates.first
        else { return }
        queueShareMoment(tier == content.tiers.maxTier ? .god(type) : .newCharacter(type))
    }

    func openShareCard() {
        guard let moment = shareOffer else { return }
        tutorialTipCompleted(.share)
        shareOffer = nil
        shareCardMoment = moment
    }

    func dismissShareOffer() {
        tutorialTipCompleted(.share)
        shareOffer = nil
    }

    func dismissShareCard() {
        shareCardMoment = nil
    }

    /// Los minutos del premio, para el botón ("+5 min").
    var shareRewardMinutesText: String {
        String(content?.viral.momentRewardMinutes ?? 0)
    }

    /// La hoja del sistema confirmó que se compartió. El premio en minutos de
    /// producción, una vez por momento; el bonus viral (+0,5 %, tope 20) y el
    /// logro, siempre.
    func registerShareCompleted(_ moment: ShareMoment) {
        guard let content, let economy, var player else { return }
        if player.meta.engagement.sharedMoments.insert(moment.key).inserted {
            let seconds = Double(content.viral.momentRewardMinutes) * 60
            let credited = Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
            player.run.coins += credited
            player.meta.lifetimeEarnings += credited
            audio?.play(.coin)
        }
        if player.meta.sharesCompleted < content.viral.maxShares {
            player.meta.sharesCompleted += 1
            UpgradeManager.recomputeDerivedEffects(
                state: &player,
                config: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                boosts: content.boosts,
                economy: economy
            )
            effectsVersion += 1
        }
        self.player = player
        evaluateAchievements()
        refreshProjections()
        scheduleSave()
    }

    #if DEBUG
    /// La puerta de los tests de UI: un piso nuevo para compartir, ya mismo.
    func debugOfferShareMoment() {
        guard let content, content.floorTable.floors.count > 1 else { return }
        queueShareMoment(.newFloor(floorID: content.floorTable[1].id))
        refreshProjections()
    }
    #endif
}
