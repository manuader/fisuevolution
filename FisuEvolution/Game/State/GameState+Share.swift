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
    /// tutorial) y sin otra tarjeta u oferta en pantalla. La lección de compartir
    /// no la frena: es la que señala el chip, y sin él su tip queda colgado.
    func presentShareMomentIfCalm() {
        guard let moment = pendingShareMoment, shareOffer == nil, shareCardMoment == nil,
              isCalmMoment || (shareLessonHasTheTurn && !isBoardBusy)
        else { return }
        pendingShareMoment = nil
        shareOffer = moment
    }

    /// El chip de la oferta se ve cuando nadie más tiene el turno, o cuando el que lo tiene es la
    /// lección que lo señala: si se esconde, el tip queda sin recorte y sin nada que tocar (B11).
    var shareOfferIsOnScreen: Bool {
        guard shareOffer != nil else { return false }
        return showing == nil || shareLessonHasTheTurn
    }

    private var shareLessonHasTheTurn: Bool {
        showing == .tutorialTip && tutorialTip?.lesson == .share
    }

    /// El reveal de un tier (lo llama `markRevealed`): personaje nuevo, o Dios.
    /// Cada uno abre su card bloqueante (C24) cuando termina la celebración del
    /// tablero; el núcleo del tutorial no la abre (la fase obligatoria no
    /// comparte pantalla con nada).
    func noteRevealedTier(_ tier: Int) {
        guard let content, let player else { return }
        let candidates = content.tiers.concreteTypes.filter { $0.tier == tier }
        guard let type = candidates.first(where: { player.run.seenTypes.contains($0.id) }) ?? candidates.first
        else { return }
        queueNewCharacterCard(tier == content.tiers.maxTier ? .god(type) : .newCharacter(type))
    }

    /// Los primeros personajes salen en minutos: su card no ofrece compartir
    /// (sólo «¡Genial!») para no cortar el arranque cada 30 s. Dios nunca cae acá.
    static let tutorialTierCeiling = 3

    /// Si la card de este momento trae el botón de compartir.
    func newCharacterCardCanShare(_ moment: ShareMoment) -> Bool {
        guard case .newCharacter(let type) = moment else { return true }
        return type.tier > Self.tutorialTierCeiling
    }

    /// Un personaje nuevo pide su card. Uno cuyo momento ya se compartió (en
    /// otra vida) no la vuelve a pedir, como la oferta de siempre.
    func queueNewCharacterCard(_ moment: ShareMoment) {
        guard shareOffersEnabled, !tutorialPhaseActive, let player,
              !player.meta.engagement.sharedMoments.contains(moment.key)
        else { return }
        newCharacterCard = moment
        syncCelebrations()
    }

    /// El jugador eligió en la card: `shared` = la hoja del sistema se completó.
    /// El bonus se cobra una vez y, elija lo que elija, el juego sigue.
    func finishNewCharacterCard(shared: Bool) {
        guard let moment = newCharacterCard else { return }
        newCharacterCard = nil
        if shared { registerShareCompleted(moment) }
        celebrationFinished(.newCharacter)
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
            announceCoins(credited)
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

    /// La puerta de los tests de UI: la card de un personaje nuevo (de los que
    /// ofrecen compartir), ya mismo.
    func debugOfferNewCharacterCard() {
        guard let type = content?.tiers.concreteTypes.first(where: { $0.tier == Self.tutorialTierCeiling + 1 })
        else { return }
        queueNewCharacterCard(.newCharacter(type))
    }
    #endif
}
