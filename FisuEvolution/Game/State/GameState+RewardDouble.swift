import EconomyKit
import Foundation

/// Toda recompensa gratis en dos pasos (E14b B29, D17): el pop-up de la fuente cobra con un solo botón y
/// recién después sale `RewardDouble` con «×2 con video». Nunca se ofrece duplicar de entrada.
///
/// Las reglas, en un solo lugar:
/// - **Sólo lo gratis.** Lo que ya costó un video (el colchón pagado, el giro por video, una carta del
///   Vendedor) o se pagó (blue, plata, un intercambio) no tiene paso 2.
/// - **Sólo lo que se duplica** (`doublableRewardKinds`): una skin o un personaje de la caja son únicos;
///   un giro de ruleta tiene su propio paso 2 en la Ruleta; vaciar los cooldowns no es una cantidad.
/// - **Sin video listo, no hay paso 2**: sin anuncio cargado, sin consentimiento o sin conexión, el
///   proveedor no tiene inventario (`isRewardedReady`) y la oferta no aparece.
/// - **Una sola vez.** El video premiado paga lo del paso 1, y el paso 2 se borra ANTES de pagar: un
///   segundo premio del mismo video no encuentra nada que cobrar.
/// - **El ×N del segmento, a la vista** (2.1 E15 F2): la plata se paga por `RewardDouble.multiplier`
///   (la palanca de la fuente, dentro de los topes del código; ×2 en la base) y el pop-up muestra eso
///   mismo. Lo que no es plata se da una vez más: no hay media caja.
extension GameState {
    /// Lo que el paso 2 vuelve a dar además de la plata (que va cotizada aparte, en `coins`). Un efecto con
    /// duración no pega dos veces: dura el doble, como el `scaled(by: 2)` de siempre.
    static let doublableRewardKinds: Set<RewardSpec.Kind> = [.blue, .package, .modifier, .autoTap, .eventImmunity]

    static func doublableRewards(_ rewards: [RewardSpec]) -> [RewardSpec] {
        rewards.filter { doublableRewardKinds.contains($0.kind) }
    }

    /// Las celebraciones que son un pop-up: con una de ellas en pantalla, el paso 2 del tablero no sale
    /// (D14). Los avisos, los logros y las animaciones del tablero no tapan nada.
    static let popupCelebrations: Set<CelebrationKind> = [
        .offlineEarnings, .dailyReward, .careerChoice, .skinAward, .specialDrop, .chestOpening, .cinematic,
        .offer, .newCharacter, .tutorialTip,
    ]

    /// Lo que la cola no promueve con el paso 2 abierto sobre el tablero: los pop-ups, lo que cambia el
    /// tablero y la entrada de un visitante. Los avisos y los logros siguen, no tapan nada.
    static let heldDuringRewardDouble: Set<CelebrationKind> =
        popupCelebrations.union([.boardCelebration, .visitorEncounter])

    /// La retención que corresponde ahora: la del paso 2 del tablero o ninguna.
    var rewardDoubleHold: Set<CelebrationKind> {
        rewardDouble?.host == .board ? Self.heldDuringRewardDouble : []
    }

    /// Hay un video listo para esta unidad: sin él, el paso 2 no se ofrece.
    func isRewardDoubleAdReady(_ placement: RewardedPlacement) -> Bool {
        ads?.isRewardedReady(for: placement) == true
    }

    /// Ofrece el paso 2. `during` es la celebración que lo dio, si todavía está en curso (el offline, el
    /// diario): otro pop-up de la cola en pantalla lo deja sin paso 2 para no encimarlos (D14).
    @discardableResult
    func offerRewardDouble(
        site: String,
        placement: RewardedPlacement,
        host: RewardDouble.Host = .board,
        payout: RewardDouble.Payout,
        coins: Double,
        rewards: [RewardSpec],
        during celebration: CelebrationKind? = nil
    ) -> Bool {
        let coins = coins.isFinite ? max(0, coins) : 0
        guard rewardDouble == nil, coins > 0 || !rewards.isEmpty, isRewardDoubleAdReady(placement) else { return false }
        if host == .board, let current = showing, current != celebration,
           Self.popupCelebrations.contains(current) { return false }
        rewardDouble = RewardDouble(site: site, placement: placement, host: host, payout: payout,
                                    shownCoins: coins, shownRewards: rewards,
                                    multiplier: Self.rewardDoubleMultiplier(site: site, levers: segmentLevers))
        // El del tablero retiene la cola en el acto (`heldDuringRewardDouble`): ni lo próximo que se encole
        // le pasa por encima.
        publishCelebration()
        Log.ads.info("reward double offered: \(site)")
        return true
    }

    /// El ×N del video para un `site`: la palanca de su fuente, acotada por los topes del código (lo remoto
    /// ya se valida al leerse; esto es el último cerrojo). Un `site` sin fuente conocida, o un valor que no
    /// es un número, es ×2: la 2.0.
    static func rewardDoubleMultiplier(site: String, levers: SegmentLevers.Levers) -> Double {
        let base = SegmentLevers.Levers.baseVideoRewardMultiplier
        guard let source = SegmentLevers.Source(site: site) else { return base }
        let wanted = levers.rewardMultiplier(for: source)
        guard wanted.isFinite else { return base }
        let caps = SegmentLevers.Caps.videoRewardMultiplierRange(for: source)
        return min(max(wanted, caps.lowerBound), caps.upperBound)
    }

    /// El paso 2 de algo que se entregó por `grant`: la misma plata ya cotizada y los mismos premios.
    @discardableResult
    func offerGrantDouble(
        site: String,
        placement: RewardedPlacement,
        host: RewardDouble.Host = .board,
        coins: Double,
        rewards: [RewardSpec],
        source: String
    ) -> Bool {
        let again = Self.doublableRewards(rewards)
        let coins = coins.isFinite ? max(0, coins) : 0
        return offerRewardDouble(site: site, placement: placement, host: host,
                                 payout: .grant(coins: coins, rewards: again, source: source),
                                 coins: coins, rewards: again)
    }

    // MARK: - Las fuentes

    /// Un regalo, un chisme o un reto ganado de un visitante. Lo que se llevó a alguien o cobró algo
    /// es un trato, no un regalo: no tiene paso 2.
    @discardableResult
    func offerVisitDouble(scriptId: String, coins: Double, rewards: [RewardSpec], departures: [BoardChange] = [],
                          source: String) -> Bool {
        guard departures.isEmpty, coins >= 0 else { return false }
        return offerGrantDouble(site: "double.visit.\(scriptId)", placement: .visitor, coins: coins,
                                rewards: rewards, source: source)
    }

    /// Lo que juntó mientras no estabas: ya está acreditado; el paso 2 lo paga otra vez, una vez por vuelta.
    @discardableResult
    func offerOfflineDouble(_ reward: OfflineReward) -> Bool {
        guard !offlineRewardDoubled else { return false }
        return offerRewardDouble(site: "double.offline", placement: .offlineX2, payout: .offline(reward),
                                 coins: reward.amount, rewards: [], during: .offlineEarnings)
    }

    /// El diario: sólo la plata, una vez por día (el special y el cofre del día 7 no se duplican).
    @discardableResult
    func offerDailyDouble(_ claim: DailyRewardManager.Claim, now: Date = Date()) -> Bool {
        guard canDoubleDailyReward(claim, now: now) else { return false }
        return offerRewardDouble(site: "double.daily", placement: .daily, payout: .daily(claim),
                                 coins: claim.coinsGranted, rewards: [], during: .dailyReward)
    }

    /// Elegir carrera (paso 1) y, si su premio de una vez es plata, el paso 2. La plata se cotiza ANTES de
    /// elegir: `chooseCareer` acredita antes del merge, y el ×2 paga lo mismo aunque el merge suba la
    /// producción.
    func chooseCareerOfferingDouble(optionId: String) {
        guard let prompt = careerPrompt, prompt.options.contains(where: { $0.id == optionId }) else { return }
        var coins = 0.0
        if let minutes = careerLumpMinutes(optionId: optionId), let content, let economy, let player {
            coins = Self.coinReward(seconds: minutes * 60, player: player, content: content, economy: economy)
        }
        chooseCareer(optionId: optionId)
        guard careerPrompt == nil, coins > 0 else { return }
        offerGrantDouble(site: "double.career", placement: .daily, coins: coins, rewards: [],
                         source: "career.x2.\(optionId)")
    }

    /// El giro GRATIS de la Ruleta: su «repetir premio» es este paso 2, el mismo gajo otra vez. El de video
    /// ya costó uno y el de blue se pagó; el cofre trae una skin única.
    @discardableResult
    func offerWheelDouble(_ outcome: WheelSpinOutcome, source: WheelSpinSource) -> Bool {
        guard var player else { return false }
        let repeatable = player.meta.engagement.wheel.repeatableSegmentId == outcome.segment.id
        // El «repetir» de este giro se gasta acá, se ofrezca o no: no queda colgado en el save.
        if player.meta.engagement.wheel.repeatableSegmentId != nil {
            player.meta.engagement.wheel.repeatableSegmentId = nil
            self.player = player
            scheduleSave()
        }
        guard source == .bonus, outcome.segment.reward.kind != .skinChest, repeatable else { return false }
        return offerGrantDouble(site: "double.wheel", placement: .wheel, host: .wheel, coins: outcome.coins,
                                rewards: [outcome.segment.reward], source: "wheel.\(outcome.segment.id)")
    }

    /// El colchón gratis del tablero (B31) se cobra y ofrece su ×2; el pagado con video y el «otro
    /// colchón», no.
    @discardableResult
    func offerMattressDouble(_ outcome: MattressOutcome) -> Bool {
        guard outcome.isGift else { return false }
        return offerGrantDouble(site: "double.mattress", placement: .treasure, coins: outcome.coins,
                                rewards: outcome.rewards, source: "treasure.\(outcome.prizeId)")
    }

    /// La plata o el blue de un logro, en el Menú.
    @discardableResult
    func offerAchievementDouble(coins: Double, rewards: [RewardSpec], achievementId: String) -> Bool {
        offerGrantDouble(site: "double.achievement", placement: .gifts, host: .menu, coins: coins,
                         rewards: rewards, source: "achievement.\(achievementId)")
    }

    /// La plata de un evento (el Aguinaldo). Llega sola, así que sólo con el tablero a la vista y fuera de la
    /// fase obligatoria del tutorial: nunca encima de otra cosa. (La entrada del presentador todavía ocupa
    /// la cola cuando el evento arranca: por eso no es `isCalmMoment`.)
    @discardableResult
    func offerEventDouble(eventId: String, coins: Double, source: String) -> Bool {
        guard !isBoardBusy, !tutorialPhaseActive else { return false }
        return offerGrantDouble(site: "double.event.\(eventId)", placement: .visitor, coins: coins, rewards: [],
                                source: source)
    }

    // MARK: - El paso 2

    /// El video se premió: paga lo del paso 1 otra vez, la plata por el ×N que mostró el pop-up
    /// (`extraCoins`). `false` si ya no había nada (otro premio del mismo video, o se resolvió por otro lado).
    @discardableResult
    func claimRewardDouble(id: UUID, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard let double = rewardDouble, double.id == id else { return false }
        rewardDouble = nil
        let extra = double.extraCoins
        switch double.payout {
        case let .grant(_, rewards, source):
            creditCoins(extra)
            let granted = rewards.reduce(0.0) { $0 + grantAgain($1, source: source, now: now) }
            announceReward(rewards, coins: extra + granted)
            noteRewardDoubleVideo()
        case .offline(let reward):
            guard !offlineRewardDoubled else { break }
            doubleOfflineReward(reward, multiplier: double.multiplier)
            announceCoins(extra)
            noteRewardDoubleVideo()
        case .daily(let claim):
            let day = Date(timeIntervalSince1970: now)
            guard canDoubleDailyReward(claim, now: day) else { break }
            // `doubleDailyReward` ya cuenta el video y evalúa los logros.
            doubleDailyReward(claim, multiplier: double.multiplier, now: day)
            announceCoins(extra)
        }
        Log.economy.info("reward double claimed: \(double.site)")
        double.followUps.forEach { $0() }
        syncCelebrations()
        return true
    }

    /// «No, gracias»: no cobra nada y sigue lo que esperaba. Con el video en curso no rechaza: queda
    /// anotado y se aplica si el anuncio vuelve sin premio (`endRewardDoubleWatch`).
    func declineRewardDouble(id: UUID) {
        guard let double = rewardDouble, double.id == id else { return }
        if double.isWatching {
            rewardDouble?.declinePending = true
            return
        }
        rewardDouble = nil
        double.followUps.forEach { $0() }
        syncCelebrations()
    }

    /// La hoja que lo hospeda se cerró de verdad (`closeWheel`, el cierre del Menú): cuenta como
    /// «No, gracias», así no queda una oferta huérfana trabando las próximas.
    func declineRewardDouble(host: RewardDouble.Host) {
        guard let double = rewardDouble, double.host == host else { return }
        declineRewardDouble(id: double.id)
    }

    /// El jugador tocó «×2 con video»: desde acá y hasta que el anuncio vuelva, nada lo rechaza.
    func beginRewardDoubleWatch(id: UUID) {
        guard rewardDouble?.id == id else { return }
        rewardDouble?.isWatching = true
    }

    /// El anuncio volvió. Con premio, `claimRewardDouble` ya pagó y no queda nada; sin premio, el paso 2
    /// sigue a la vista, salvo que lo hayan rechazado (o cerrado su hoja) mientras se miraba.
    func endRewardDoubleWatch(id: UUID) {
        guard let double = rewardDouble, double.id == id else { return }
        rewardDouble?.isWatching = false
        if double.declinePending { declineRewardDouble(id: id) }
    }

    /// Corre `action` cuando el paso 2 en curso se resuelva, o ya si no hay ninguno.
    func whenRewardDoubleResolved(_ action: @escaping @MainActor () -> Void) {
        guard rewardDouble != nil else { return action() }
        rewardDouble?.followUps.append(action)
    }

    /// Un efecto con duración que sigue vivo con el mismo origen dura `seconds` más (el ×2 dura el doble,
    /// no pega dos veces); lo demás se entrega otra vez por el punto único de premios.
    private func grantAgain(_ reward: RewardSpec, source: String, now: TimeInterval) -> Double {
        guard let durable = Self.durableEffect(of: reward), var player,
              let index = player.run.activeModifiers.lastIndex(where: {
                  $0.sourceKey == source && $0.effect == durable.effect && $0.isActive(at: now)
              })
        else { return grant(reward, source: source, now: now) }
        let live = player.run.activeModifiers[index]
        player.run.activeModifiers[index] = ActiveModifier(
            id: live.id, effect: live.effect, magnitude: live.magnitude,
            expiresAt: live.expiresAt + durable.seconds, sourceKey: live.sourceKey
        )
        self.player = player
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        return 0
    }

    private static func durableEffect(of reward: RewardSpec) -> (effect: ActiveModifier.Effect, seconds: Double)? {
        switch reward {
        case let .modifier(effect, _, seconds): return (effect, seconds)
        case let .autoTap(_, seconds): return (.autoTapPerSecond, seconds)
        case .eventImmunity(let seconds): return (.eventImmunity, seconds)
        default: return nil
        }
    }

    private func noteRewardDoubleVideo() {
        guard var player else { return }
        player.meta.stats.videosWatchedEver += 1
        self.player = player
        evaluateAchievements()
        scheduleSave()
    }
}
