import EconomyKit
import Foundation

/// Las cuatro fuentes de bonus del bible §1/§4.4: rewarded ads, boosts, eventos
/// y el daily con sus shares. Separado de `GameState.swift` para que el frente de
/// bonus no comparta archivo con los otros cinco dominios.
extension GameState {
    // MARK: Rewarded ads (F4 — efectos del bible §4.4)

    /// Cuánto falta para que ESTA recompensa vuelva a ofrecerse (RF-11).
    ///
    /// `now` es parámetro y no `Date()` adentro por lo mismo que en los boosts:
    /// es la única forma de testear cuatro horas sin esperarlas.
    func rewardCooldownRemaining(id: String, now: TimeInterval = Date().timeIntervalSince1970) -> TimeInterval {
        guard let content, let player,
              let reward = content.rewardedAds.rewards.first(where: { $0.id == id })
        else { return 0 }
        let last = player.meta.rewardedActivations[id] ?? -.infinity
        return max(0, reward.cooldownSeconds - (now - last))
    }

    /// Acredita el premio de un video ya mirado y arranca su cooldown.
    func applyRewardedReward(rewardId: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content,
              let reward = content.rewardedAds.rewards.first(where: { $0.id == rewardId }),
              var player
        else { return }
        guard rewardCooldownRemaining(id: rewardId, now: now) <= 0 else {
            Log.economy.info("rewarded on cooldown: \(rewardId)")
            return
        }

        // El cooldown se marca ANTES de aplicar el efecto: el video ya se miró y
        // el anunciante ya cobró. Si el efecto dejó de tener dónde caer entre el
        // toque y el final del video, se compensa en producción.
        player.meta.rewardedActivations[rewardId] = now
        // El contador va donde va el cooldown, y por el mismo motivo.
        player.meta.stats.videosWatchedEver += 1
        self.player = player

        guard isRewardApplicable(rewardId) else {
            compensateRewardedVideo()
            effectsVersion += 1
            evaluateAchievements()
            return
        }

        switch reward.effectType {
        case .incomeMultiplier:
            guard let magnitude = reward.magnitude, let duration = reward.durationSeconds else { break }
            player.run.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: magnitude,
                expiresAt: now + duration,
                sourceKey: "rewarded.\(reward.id)"
            ))
            self.player = player
            refreshProjections()
        case .instantMerge:
            if let tower {
                BoardChangePlanner.planAutoMerge(
                    state: player, tower: tower, tiers: content.tiers,
                    floorTable: content.floorTable, origin: .rewardedInstantMerge
                ).map(enqueueBoardChange)
            }
        case .rareUnit:
            rareUnitChange().map(enqueueBoardChange)
        case .skinChest:
            awardChest(minRarity: nil)
        }
        // La fila tiene que pasar de botón a cuenta regresiva sin cerrar el panel.
        effectsVersion += 1
        evaluateAchievements()
        scheduleSave()
        Log.economy.info("rewarded effect applied: \(reward.id)")
    }

    /// El "Personaje de regalo": una unidad del tier máximo (respetando la carrera)
    /// que llega por el embudo. La usa también la fila del video (T14).
    func rareUnitChange() -> BoardChange? {
        guard let content, let player, let tower else { return nil }
        let tier = player.run.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return nil }
        return BoardChangePlanner.planArrival(
            typeId: type.id, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, origin: .rewardedRareUnit
        )
    }

    /// Por qué este video no tendría efecto ahora, o `nil` si lo tiene.
    func rewardUnavailableReason(_ rewardId: String) -> String? {
        guard let content, let player, let tower,
              let reward = content.rewardedAds.rewards.first(where: { $0.id == rewardId })
        else { return nil }
        switch reward.effectType {
        case .incomeMultiplier, .skinChest:
            return nil
        case .instantMerge:
            let plan = BoardChangePlanner.planAutoMerge(
                state: player, tower: tower, tiers: content.tiers,
                floorTable: content.floorTable, origin: .rewardedInstantMerge
            )
            return plan == nil ? String(localized: "ads.unavailable.merge") : nil
        case .rareUnit:
            return rareUnitChange() == nil ? String(localized: "ads.unavailable.floor_full") : nil
        }
    }

    func isRewardApplicable(_ rewardId: String) -> Bool {
        rewardUnavailableReason(rewardId) == nil
    }

    /// Un video visto que no tiene dónde aplicarse paga producción en vez de nada.
    /// Sólo lo llaman los caminos de video, y cada uno una sola vez por video.
    func compensateRewardedVideo() {
        guard let content, let economy, var player else { return }
        let seconds = content.rewardedAds.compensationSeconds
        let amount = Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
        player.run.coins += amount
        player.meta.lifetimeEarnings += amount
        self.player = player
        towerNotice = TowerNotice(kind: .rewardCompensated(durationText: Self.durationText(seconds)))
        if isSceneActive { audio?.play(.coin) }
        refreshProjections()
        scheduleSave()
    }

    // MARK: Boosts (F5 — bible §1)

    /// ¿Llegó el jugador al piso que abre este boost? (RF-12)
    ///
    /// Se mide contra `meta.stats.maxFloorOrdinalEver` y no contra los pisos de la
    /// run: si muriera al reencarnar, cada reencarnación te sacaría los boosts que
    /// ya te habías ganado, que es exactamente lo contrario de "se van
    /// desbloqueando a medida que avanzás".
    func isBoostUnlocked(_ boost: BoostsConfig.Boost) -> Bool {
        guard let content, let player,
              let required = content.floorTable.ordinal(of: boost.unlockFloorId)
        else { return false }
        return player.meta.stats.maxFloorOrdinalEver >= required
    }

    /// Devuelve las coins de la picada si el boost era el Asado.
    @discardableResult
    func activateBoost(id: String) -> Double? {
        guard let economy, let content, var player = player else { return nil }
        // Un boost bloqueado no se activa ni por accidente: la fila lo esconde,
        // pero la regla vive acá y no en la vista.
        guard let boost = content.boosts.boosts.first(where: { $0.id == id }), isBoostUnlocked(boost) else {
            Log.economy.info("boost locked: \(id)")
            return nil
        }
        do {
            let payout = try BoostManager.activate(
                boostId: id,
                state: &player,
                config: content.boosts,
                upgrades: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                tiers: content.tiers,
                floorTable: content.floorTable,
                economy: economy,
                now: Date().timeIntervalSince1970
            )
            // Adentro del `do` y después del `activate`: un boost bloqueado sale
            // por el guard de arriba y uno en cooldown tira, y ninguno de los dos
            // es una activación.
            player.meta.stats.boostsActivatedEver += 1
            self.player = player
            effectsVersion += 1
            // La picada del Asado es la otra vez que cae plata de golpe (el resto
            // de los boosts no pagan nada al activarse, devuelven nil).
            if payout != nil { audio?.play(.coin) }
            // Después del `+= 1` y dentro del `do`: un boost bloqueado o en
            // cooldown no es una activación y no mueve el logro.
            evaluateAchievements()
            refreshProjections()
            scheduleSave()
            return payout
        } catch {
            Log.economy.info("boost rejected: \(error)")
            return nil
        }
    }

    /// Cómo se lee lo que pagó la picada. El lookup vive acá y no adentro del
    /// `body` de la vista porque un `String(localized:)` metido en SwiftUI no lo
    /// mira ningún test: con la clave rota devuelve la clave cruda, y el build
    /// sigue verde mientras el jugador lee "gifts.payout 8,4 M".
    static func payoutText(_ amount: Double) -> String {
        String(localized: "gifts.payout \(CoinFormatter.string(from: amount))")
    }

    // MARK: Eventos (F5 — bible §1)

    func scheduleNextEvent(from now: TimeInterval) {
        guard let content else { return }
        let jitter = Double.random(in: 0..<max(content.events.intervalJitterSeconds, 1), using: &rng)
        nextEventAt = now + content.events.baseIntervalSeconds + jitter
    }

    /// Un evento que venció mientras la app estaba afuera no dispara al volver:
    /// se corre `resumeGraceSeconds` para que el jugador mire el tablero antes.
    func postponeOverdueEvent(now: TimeInterval) {
        guard let content, nextEventAt <= now else { return }
        nextEventAt = now + content.events.resumeGraceSeconds
    }

    func eventIsApplicable(_ event: EventsConfig.Event) -> Bool {
        guard let content, let player, let tower else { return false }
        // La Obra social: un evento negativo no cae mientras dure la inmunidad.
        if !event.isBuff, ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: Date().timeIntervalSince1970) {
            return false
        }
        switch event.effectType {
        case .incomeMultiplier, .spawnCostMultiplier, .spendingFrozen:
            return true
        case .bonusCoins:
            return IncomeTicker.basePassivePerSecond(
                state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy
            ) > 0
        case .instantEvolution:
            return BoardChangePlanner.planEvolve(
                state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .eventStartup
            ) != nil
        case .freeHighTier:
            guard let type = EventManager.blanqueoType(for: event, state: player, tiers: content.tiers) else { return false }
            return BoardChangePlanner.planArrival(
                typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                floorTable: content.floorTable, origin: .eventBlanqueo
            ) != nil
        }
    }

    func fireEventIfDue(now: TimeInterval) {
        guard let economy, let content, var player else { return }
        if let active = activeEvent, now >= active.endsAt {
            activeEvent = nil
        }
        guard now >= nextEventAt else { return }
        let applicable = Set(content.events.events.filter(eventIsApplicable).map(\.id))
        guard let roll = EventManager.fireRandomEvent(
            state: &player,
            config: content.events,
            tiers: content.tiers,
            floorTable: content.floorTable,
            economy: economy,
            now: now,
            lastFired: eventLastFired,
            isApplicable: { applicable.contains($0.id) },
            rng: &rng
        ) else {
            nextEventAt = now + content.events.retryWhenNoneApplicableSeconds
            return
        }
        scheduleNextEvent(from: now)
        self.player = player
        handleEventRoll(roll, now: now)
    }

    /// La salida por video de un evento negativo. E4 la mueve al popup del chip.
    func escapeActiveEvent(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let event = activeEvent, event.escapableByVideo else { return }
        cutNegativeEvent()
        Log.economy.info("event escaped by video: \(event.id)")
    }

    /// Corta en el acto el evento malo que esté corriendo (la Obra social, la
    /// salida por video del Corralito): saca sus modificadores y limpia el aviso.
    /// Un buff no se corta.
    @discardableResult
    func cutNegativeEvent() -> Bool {
        guard let event = activeEvent, !event.isBuff, var player else { return false }
        player.run.activeModifiers.removeAll { $0.sourceKey == "event.\(event.id)" }
        self.player = player
        activeEvent = nil
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        return true
    }

    func handleEventRoll(_ roll: EventManager.Roll, now: TimeInterval) {
        guard let content, let player, let tower else { return }
        switch roll.boardIntent {
        case .evolveBestUnit:
            BoardChangePlanner.planEvolve(
                state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .eventStartup
            ).map(enqueueBoardChange)
        case .grantUnit(let typeId):
            BoardChangePlanner.planArrival(
                typeId: typeId, state: player, tower: tower, tiers: content.tiers,
                floorTable: content.floorTable, origin: .eventBlanqueo
            ).map(enqueueBoardChange)
        case nil:
            break
        }
        eventLastFired[roll.event.id] = now
        activeEvent = roll.active
        audio?.play(.event)
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(roll.event.id)")
    }

    // MARK: Daily + shares (F5)

    func claimDailyIfAvailable() {
        guard let economy, let content, var player else { return }
        if let claim = DailyRewardManager.claimIfAvailable(
            state: &player,
            config: content.dailyRewards,
            specials: content.specials,
            skins: content.skins,
            upgrades: content.upgradesConfig,
            viral: content.viral,
            boosts: content.boosts,
            economy: economy,
            tiers: content.tiers,
            floorTable: content.floorTable,
            today: Date(),
            rng: &rng
        ) {
            self.player = player
            dailyClaim = claim
            audio?.play(.daily)
            // El día 7 del ciclo y el special que puede tirar el cofre: los dos
            // logros que sólo se cruzan por acá.
            evaluateAchievements()
            refreshProjections()
            scheduleSave()
        }
    }

    func dismissDailyClaim() {
        dailyClaim = nil
        celebrationFinished(.dailyReward)
    }

    /// La semana del daily como la dibuja `GiftsView` (spec §9).
    ///
    /// ⚠️ **Es informativo y no cobra nada.** El claim sigue siendo automático
    /// (bootstrap + vuelta a foreground); un botón acá abriría el doble camino de
    /// claim que el spec descarta, con su carrera entre los dos.
    ///
    /// La semántica de `cycleDay`: **apunta al día que el ciclo VA A PAGAR**, no
    /// al que ya pagó. `DailyRewardManager.claimIfAvailable` cobra el día
    /// `cycleDay` y recién entonces lo avanza (`ContentSystems.swift:396-397`),
    /// así que los días menores son los cobrados y ese es el que está en juego.
    /// Después del claim automático de hoy, el resaltado ya es el de mañana: la
    /// tira se lee como "esto llevás, esto viene".
    ///
    /// ⚠️⚠️ **Y por eso no se deduce "el día cobrado hoy" de `lastClaimDay`**,
    /// que sería la otra lectura posible. En una instalación nueva el bootstrap
    /// escribe `lastClaimDay = hoy` **sin cobrar y sin mover `cycleDay`**
    /// (`GameState.swift:436-440`, para que el popup no compita con el tutorial):
    /// con esa regla, una partida recién empezada mostraría los siete días
    /// tildados. Está pineado en `DailyCalendarTests`.
    var dailyCalendar: [DailyDayRow] {
        guard let content, let player else { return [] }
        let days = content.dailyRewards.days.sorted { $0.day < $1.day }
        guard !days.isEmpty else { return [] }
        let current = min(max(player.meta.daily.cycleDay, 1), days.count)
        return days.map { day in
            DailyDayRow(
                id: day.day,
                titleKey: day.titleKey,
                isToday: day.day == current,
                isClaimed: day.day < current,
                // El mismo literal que decide el premio en `claimIfAvailable`: el
                // día del cofre es el que tira un special en vez de monedas.
                isChest: day.type == "special_roll"
            )
        }
    }

    /// La escena ofrece el share card al terminar el reveal de evolución.
    func offerShareCard(for type: CharacterType) {
        shareCardSubject = type
    }

    func dismissShareCard() {
        shareCardSubject = nil
    }

    // MARK: Proyecciones de la pantalla de Bonus (RF-06, RF-11, RF-12)

    /// Las filas de boost, ya resueltas: qué hace cada uno, si está abierto y qué
    /// piso lo abre. `GiftsView` no lee `PlayerState` (regla de arquitectura), y
    /// que la traducción viva acá evita que la vista invente la suya.
    var boostRows: [BoostRow] {
        guard let content, let player else { return [] }
        let variant = content.flags.effectiveBuildVariant
        let now = Date().timeIntervalSince1970
        return content.boosts.boosts.map { boost in
            let unlocked = isBoostUnlocked(boost)
            return BoostRow(
                id: boost.id,
                displayName: Self.localized(boost.displayNameKey(buildVariant: variant)),
                iconKey: boost.iconKey,
                effectText: Self.effectText(for: boost),
                flavorText: Self.localized(boost.flavorTextKey(buildVariant: variant)),
                isUnlocked: unlocked,
                unlockFloorName: unlocked ? nil : TowerNaming.floorName(for: boost.unlockFloorId),
                cooldownRemaining: BoostManager.cooldownRemaining(of: boost, state: player, now: now),
                cooldownTotal: boost.cooldownSeconds
            )
        }
    }

    // MARK: Contadores de bonus activos (HUD)

    /// Los bonus temporales corriendo, ya resueltos a chips.
    ///
    /// El catálogo se arma acá y no se cachea porque hay un portero barato antes:
    /// sin ningún modificador vivo —que es el estado normal de la partida— no se
    /// construye nada. Mientras un boost corre son siete entradas cada 125 ms,
    /// que es ruido al lado de lo que ya hace `refreshProjections`.
    func makeActiveBonuses(player: PlayerState, content: GameContent) -> [ActiveBonus] {
        guard !player.run.activeModifiers.isEmpty else { return [] }
        return ActiveBonusBuilder.bonuses(
            from: player.run.activeModifiers,
            catalog: Self.bonusCatalog(content: content),
            now: Date().timeIntervalSince1970
        )
    }

    /// `sourceKey` → con qué se dibuja y cuánto duraba. Es lo único que el
    /// `ActiveModifier` no sabe de sí mismo: guarda cuándo vence, no cuánto
    /// duraba, y el aro necesita las dos cosas.
    private static func bonusCatalog(content: GameContent) -> [String: BonusSource] {
        var catalog: [String: BonusSource] = [:]
        for boost in content.boosts.boosts {
            catalog["boost.\(boost.id)"] = BonusSource(
                icon: .art(boost.iconKey), duration: boost.durationSeconds
            )
        }
        for reward in content.rewardedAds.rewards {
            guard let duration = reward.durationSeconds else { continue }
            catalog["rewarded.\(reward.id)"] = BonusSource(
                icon: .symbol("play.rectangle.fill"), duration: duration
            )
        }
        for career in content.careers.careers {
            guard let duration = career.durationSeconds else { continue }
            catalog["career.\(career.id)"] = BonusSource(
                icon: .symbol("briefcase.fill"), duration: duration
            )
        }
        return catalog
    }

    /// Las recompensas por video con su cuenta regresiva (RF-11) y qué da
    /// cada una.
    var rewardRows: [RewardRow] {
        guard let content else { return [] }
        let now = Date().timeIntervalSince1970
        return content.rewardedAds.rewards.map { reward in
            let cooldown = rewardCooldownRemaining(id: reward.id, now: now)
            return RewardRow(
                id: reward.id,
                titleKey: reward.titleKey,
                rewardText: Self.rewardText(for: reward),
                cooldownRemaining: cooldown,
                cooldownTotal: reward.cooldownSeconds,
                unavailableReason: cooldown > 0 ? nil : rewardUnavailableReason(reward.id)
            )
        }
    }

    /// Qué te da ESTE video, resuelto del dato (spec §9).
    ///
    /// Hasta acá la fila mostraba sólo su `titleKey`, y los dos multiplicadores
    /// llevaban el número **escrito en el catálogo** ("Ganancias x2 (2 min)"):
    /// cambiar `magnitude` en `rewarded_ads.json` dejaba la copy mintiendo, que
    /// es la misma trampa que RF-06 corrigió en los boosts. El número sale ahora
    /// de la pieza compartida `EffectDescriptor`, la misma que usan boosts,
    /// mejoras y los chips del HUD, y los títulos quedaron como nombres.
    ///
    /// El `.incomeMultiplier` que se le pasa es el de `BoostsConfig` —son dos
    /// enums distintos con el mismo caso— porque el descriptor traduce EFECTOS,
    /// no orígenes: un ×2 a los ingresos se lee igual venga de un mate o de un
    /// video.
    private static func rewardText(for reward: RewardedAdsConfig.Reward) -> String {
        switch reward.effectType {
        case .incomeMultiplier:
            // Sin magnitud o sin duración no hay frase que armar: la fila se queda
            // con su título en vez de publicar un "× por" a medio llenar.
            guard let magnitude = reward.magnitude, let duration = reward.durationSeconds else { return "" }
            let value = EffectFormatter.text(
                EffectDescriptor.amount(forBoost: .incomeMultiplier, magnitude: magnitude)
            )
            return String(localized: "ads.reward.text.income \(value) \(durationText(duration))")
        case .instantMerge:
            return String(localized: "ads.reward.text.merge")
        case .rareUnit:
            return String(localized: "ads.reward.text.rare")
        case .skinChest:
            return String(localized: "ads.reward.text.chest")
        }
    }

    /// "2 min" o "45 s". Los dos videos con duración duran minutos redondos, pero
    /// la duración es un dato: si mañana uno dura 45 s, la frase sigue siendo
    /// cierta sin tocar código.
    ///
    /// ⚠️ El número va como `String` a propósito: una clave con `%@` interpolada
    /// con un `Int` sale en pantalla como la clave cruda (trampa 5).
    private static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 60, total % 60 == 0 {
            return String(localized: "ads.duration.min \(String(total / 60))")
        }
        return String(localized: "ads.duration.sec \(String(total))")
    }

    /// La línea de "qué hace" de un boost (RF-06). El número sale entero de la
    /// pieza compartida `EffectDescriptor` —incluido el mate, cuya magnitud 0,7 es
    /// un factor de costo y se lee **−30%**—; acá sólo se le pone la frase
    /// alrededor. Los segundos van como `String` a propósito: una clave con `%@`
    /// interpolada con un `Int` sale en pantalla como la clave cruda.
    private static func effectText(for boost: BoostsConfig.Boost) -> String {
        let value = EffectFormatter.text(
            EffectDescriptor.amount(forBoost: boost.effectType, magnitude: boost.magnitude)
        )
        let seconds = String(Int(boost.durationSeconds))
        switch boost.effectType {
        case .incomeMultiplier: return String(localized: "bonus.effect.income \(value) \(seconds)")
        case .tapMultiplier: return String(localized: "bonus.effect.tap \(value) \(seconds)")
        case .spawnCostMultiplier: return String(localized: "bonus.effect.spawn \(value) \(seconds)")
        case .offlineEfficiencyPermanent: return String(localized: "bonus.effect.offline \(value)")
        case .periodicPayout: return String(localized: "bonus.effect.payout_minutes \(value)")
        }
    }

    /// Lookup de una clave que viene del JSON. `String(localized:)` sólo acepta
    /// literales, así que las claves data-driven pasan por el bundle.
    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: Recompensa por elegir carrera (RF-15)

    /// Qué se lleva cada carrera, ya formateado para mostrarlo ANTES de elegir:
    /// una elección a ciegas no es una elección.
    var careerRewards: [String: CareerReward] {
        guard let content, let player else { return [:] }
        var rewards: [String: CareerReward] = [:]
        for career in content.careers.careers {
            guard let preview = Self.previewText(for: career, content: content, player: player) else { continue }
            rewards[career.id] = CareerReward(kind: career.rewardKind, previewText: preview)
        }
        return rewards
    }

    private static func previewText(
        for career: CareersConfig.Career,
        content: GameContent,
        player: PlayerState
    ) -> String? {
        switch career.rewardKind {
        case .freeHires:
            guard let duration = career.durationSeconds else { return nil }
            return String(localized: "career.reward.free_hires \(minutesText(seconds: duration))")
        case .skin:
            guard let skin = content.skins.skins.first(where: { $0.id == career.skinId }) else { return nil }
            return String(localized: "career.reward.skin \(localized(skin.displayNameKey ?? skin.id))")
        case .lawsuit:
            guard let minutes = career.lumpMinutes else { return nil }
            let coins = CoinFormatter.string(from: coinPayout(minutes: minutes, player: player, content: content))
            return String(localized: "career.reward.lawsuit \(coins)")
        case .healthPlan:
            guard let duration = career.durationSeconds, let minutes = career.lumpMinutes else { return nil }
            let coins = CoinFormatter.string(from: coinPayout(minutes: minutes, player: player, content: content))
            return String(localized: "career.reward.health_plan \(minutesText(seconds: duration)) \(coins)")
        }
    }

    private static func minutesText(seconds: Double) -> String {
        EffectFormatter.text(EffectAmount(unit: .minutes, value: seconds / 60, isCapped: false))
    }

    /// Acredita el premio de una vez de la carrera elegida. La llama `chooseCareer`
    /// desde `+Actions`: la elección es de allá, el bonus es de acá. Todo lo que
    /// no es una skin pasa por `grant`, el único punto de premios.
    func grantCareerReward(optionId: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let career = content.careers.careers.first(where: { $0.id == optionId }) else { return }
        let source = "career.\(optionId)"

        switch career.rewardKind {
        case .freeHires:
            grant(.modifier(effect: .freeHire, magnitude: 1, seconds: career.durationSeconds ?? 0), source: source, now: now)
        case .skin:
            grantSkin(career.skinId)
        case .lawsuit:
            grant(.coinsSeconds((career.lumpMinutes ?? 0) * 60), source: source, now: now)
        case .healthPlan:
            grant(.eventImmunity(seconds: career.durationSeconds ?? 0), source: source, now: now)
            cutNegativeEvent()
            grant(.coinsSeconds((career.lumpMinutes ?? 0) * 60), source: source, now: now)
        }
        Log.economy.info("career reward granted: \(optionId) (\(career.rewardKind.rawValue))")
    }

    private func grantSkin(_ skinId: String?) {
        guard var player, let skinId, !player.meta.milestoneSkins.contains(skinId) else { return }
        player.meta.milestoneSkins = (player.meta.milestoneSkins + [skinId]).sorted()
        self.player = player
        skinSelectionVersion &+= 1
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
    }

    /// Referral local (bible §8): compartir da un boost permanente chico, capeado.
    func registerShareCompleted() {
        guard let economy, let content, var player = player else { return }
        guard player.meta.sharesCompleted < content.viral.maxShares else { return }
        player.meta.sharesCompleted += 1
        UpgradeManager.recomputeDerivedEffects(
            state: &player,
            config: content.upgradesConfig,
            specials: content.specials,
            viral: content.viral,
            boosts: content.boosts,
            economy: economy
        )
        self.player = player
        effectsVersion += 1
        evaluateAchievements()
        scheduleSave()
    }
}

// MARK: - Los tipos que consume la pantalla de Bonus

extension GameState {
    /// Una fila de boost tal como se ve: nombre, qué hace, el chiste, y si está
    /// abierta. Los textos vienen resueltos —no como claves— porque el número de
    /// `effectText` sale de `EffectDescriptor` y tiene que poder testearse.
    struct BoostRow: Identifiable, Equatable {
        let id: String
        let displayName: String
        let iconKey: String
        /// "×3 a los ingresos, por 90 s".
        let effectText: String
        /// El chiste corto del config (respeta la variante review-safe).
        let flavorText: String
        let isUnlocked: Bool
        /// Nombre del piso que lo desbloquea. Nil si ya está abierto.
        let unlockFloorName: String?
        let cooldownRemaining: TimeInterval
        /// Cuánto dura el cooldown entero. Es una CONSTANTE del config, no algo
        /// que cambie con el tiempo, y va acá por lo mismo que `totalDuration`
        /// va en `ActiveBonus`: el aro necesita las dos cosas —cuánto falta y
        /// sobre cuánto— y la vista no lee el config.
        let cooldownTotal: TimeInterval
    }

    /// Una recompensa por video con lo que falta para volver a ofrecerla.
    struct RewardRow: Identifiable, Equatable {
        let id: String
        let titleKey: String
        /// "×2 a los ingresos, por 2 min" — **ya resuelto**, no una clave: el
        /// número sale de `EffectDescriptor` y tiene que poder testearse.
        let rewardText: String
        let cooldownRemaining: TimeInterval
        /// Las cuatro horas enteras del cooldown, para el aro (ver `BoostRow`).
        let cooldownTotal: TimeInterval
        /// Por qué el video no se ofrece ahora (ya resuelto), o `nil` si se puede mirar.
        let unavailableReason: String?
    }

    /// Un día del ciclo de 7 del daily, tal como se dibuja la tira del
    /// calendario. Ver `dailyCalendar` para qué significa exactamente "hoy".
    struct DailyDayRow: Identifiable, Equatable {
        /// 1...7 — el mismo número del config y el que muestra la casilla.
        let id: Int
        /// Clave del nombre del día ("Día 3: Quincena Chica"). Va como clave y no
        /// resuelta porque no lleva ningún número adentro: la vista la localiza.
        let titleKey: String
        /// El día que el ciclo va a pagar. **No** es "el que cobraste hoy": ver
        /// el docstring de `dailyCalendar`.
        let isToday: Bool
        let isClaimed: Bool
        /// El día 7 no paga monedas: tira un personaje special.
        let isChest: Bool
    }

    /// El premio de una carrera. El `kind` es lo que hace que la elección sea una
    /// elección: los cuatro son distintos entre sí, no cuatro montos de plata.
    typealias CareerRewardKind = CareersConfig.RewardKind

    struct CareerReward: Equatable {
        let kind: CareerRewardKind
        /// Texto ya formateado para mostrar ANTES de elegir.
        let previewText: String
    }
}
