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

        // El cooldown se marca ANTES de aplicar el efecto: si el efecto no
        // encuentra dónde caer (torre llena, sin par mergeable), el video igual
        // se miró y el anunciante igual cobró.
        player.meta.rewardedActivations[rewardId] = now
        self.player = player

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
            performInstantMerge()
        case .rareUnit:
            grantRareUnit()
        }
        // La fila tiene que pasar de botón a cuenta regresiva sin cerrar el panel.
        effectsVersion += 1
        scheduleSave()
        Log.economy.info("rewarded effect applied: \(reward.id)")
    }

    /// Merge gratis del par más alto disponible (saltea pares que pidan carrera).
    private func performInstantMerge() {
        guard var player, var tower, let content else { return }
        // Buscar el par de mayor tier en TODA la torre.
        let candidates: [(floorOrdinal: Int, slots: [Int], typeId: String, tier: Int)] = tower.floors.indices.flatMap { ordinal in
            var slotsByType: [String: [Int]] = [:]
            for placement in tower.placements(onFloor: ordinal) {
                slotsByType[placement.typeId, default: []].append(placement.slot)
            }
            return slotsByType.compactMap { typeId, slots -> (floorOrdinal: Int, slots: [Int], typeId: String, tier: Int)? in
                guard slots.count >= 2, let type = content.tiers.type(id: typeId) else { return nil }
                return (floorOrdinal: ordinal, slots: slots, typeId: typeId, tier: type.tier)
            }
        }.sorted { $0.tier > $1.tier }

        for candidate in candidates {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: candidate.typeId,
                targetTypeId: candidate.typeId,
                chosenCareerPath: player.run.chosenCareerPath,
                tiers: content.tiers
            ) else { continue }
            do {
                _ = try TowerActions.applyMerge(
                    floorOrdinal: candidate.floorOrdinal,
                    sourceSlot: candidate.slots[0],
                    targetSlot: candidate.slots[1],
                    newTypeId: newTypeId,
                    state: &player,
                    tower: &tower,
                    tiers: content.tiers,
                    floorTable: content.floorTable
                )
                self.player = player
                self.tower = tower
                updateMaxFloorStat()
                bumpBoard()
                scheduleSave()
                return
            } catch {
                continue  // piso destino lleno: probar el siguiente par
            }
        }
    }

    /// F4: "spawn rare" — dropea una unidad del tier máximo en su piso.
    private func grantRareUnit() {
        guard var player, var tower, let content else { return }
        let tier = player.run.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return }
        let ordinal = content.floorTable.ordinal(forTier: type.tier)
        guard let slot = tower.floors[ordinal].firstFreeSlot() else { return }
        tower.floors[ordinal].slots[slot] = type.id
        player.run.units[type.id, default: 0] += 1
        self.player = player
        self.tower = tower
        bumpBoard()
        scheduleSave()
    }

    // MARK: Boosts (F5 — bible §1)

    func boostCooldownRemaining(_ boost: BoostsConfig.Boost) -> TimeInterval {
        guard let player else { return .infinity }
        return BoostManager.cooldownRemaining(of: boost, state: player, now: Date().timeIntervalSince1970)
    }

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

    /// Devuelve las coins del cofre si el boost era el Asado.
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
            let chest = try BoostManager.activate(
                boostId: id,
                state: &player,
                config: content.boosts,
                upgrades: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                tiers: content.tiers,
                economy: economy,
                now: Date().timeIntervalSince1970
            )
            self.player = player
            effectsVersion += 1
            // El cofre del Asado es la otra vez que cae plata de golpe (el resto
            // de los boosts no pagan nada al activarse, devuelven nil).
            if chest != nil { audio?.play(.coin) }
            refreshProjections()
            scheduleSave()
            return chest
        } catch {
            Log.economy.info("boost rejected: \(error)")
            return nil
        }
    }

    // MARK: Eventos (F5 — bible §1)

    func scheduleNextEvent(from now: TimeInterval) {
        guard let content else { return }
        let jitter = Double.random(in: 0..<max(content.events.intervalJitterSeconds, 1), using: &rng)
        nextEventAt = now + content.events.baseIntervalSeconds + jitter
    }

    func fireEventIfDue(now: TimeInterval) {
        guard let economy, let content, var player else { return }
        if let active = activeEvent, now >= active.endsAt {
            activeEvent = nil
        }
        guard now >= nextEventAt else { return }
        scheduleNextEvent(from: now)
        guard let roll = EventManager.fireRandomEvent(
            state: &player,
            config: content.events,
            tiers: content.tiers,
            floorTable: content.floorTable,
            economy: economy,
            now: now,
            lastFired: eventLastFired,
            rng: &rng
        ) else { return }
        self.player = player
        // Si el evento regaló una unidad, colocarla en su piso (si hay lugar).
        if let grantedTypeId = roll.grantedUnitTypeId {
            placeGrantedUnit(typeId: grantedTypeId)
        }
        // instantEvolution mutó run.units directamente: re-sincronizar la torre.
        if roll.unitsChanged {
            resyncTower()
        }
        eventLastFired[roll.event.id] = now
        activeEvent = roll.active
        audio?.play(.event)
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(roll.event.id)")
    }

    /// Coloca una unidad regalada (evento) en el piso de su tier; si el piso está
    /// lleno, el regalo se pierde con log (sin bloquear el evento).
    private func placeGrantedUnit(typeId: String) {
        guard var player, var tower, let content,
              let type = content.tiers.type(id: typeId) else { return }
        let ordinal = content.floorTable.ordinal(forTier: type.tier)
        guard let slot = tower.floors[ordinal].firstFreeSlot() else {
            Log.economy.info("granted unit skipped (floor full): \(typeId)")
            return
        }
        tower.floors[ordinal].slots[slot] = typeId
        player.run.units[typeId, default: 0] += 1
        player.run.maxTierReached = max(player.run.maxTierReached, type.tier)
        self.player = player
        self.tower = tower
        updateMaxFloorStat()
    }

    // MARK: Daily + shares (F5)

    func claimDailyIfAvailable() {
        guard let economy, let content, var player else { return }
        if let claim = DailyRewardManager.claimIfAvailable(
            state: &player,
            config: content.dailyRewards,
            specials: content.specials,
            upgrades: content.upgradesConfig,
            viral: content.viral,
            economy: economy,
            today: Date(),
            rng: &rng
        ) {
            self.player = player
            dailyClaim = claim
            audio?.play(.daily)
            refreshProjections()
            scheduleSave()
        }
    }

    func dismissDailyClaim() {
        dailyClaim = nil
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
    /// piso lo abre. `BonusView` no lee `PlayerState` (regla de arquitectura), y
    /// que la traducción viva acá evita que la vista invente la suya.
    var boostRows: [BoostRow] {
        guard let content, let player else { return [] }
        let variant = content.flags.buildVariant
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
                cooldownRemaining: BoostManager.cooldownRemaining(of: boost, state: player, now: now)
            )
        }
    }

    /// Las cuatro recompensas por video con su cuenta regresiva (RF-11).
    var rewardRows: [RewardRow] {
        guard let content else { return [] }
        let now = Date().timeIntervalSince1970
        return content.rewardedAds.rewards.map { reward in
            RewardRow(
                id: reward.id,
                titleKey: reward.titleKey,
                cooldownRemaining: rewardCooldownRemaining(id: reward.id, now: now)
            )
        }
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
        case .periodicChest: return String(localized: "bonus.effect.chest \(value)")
        }
    }

    /// Lookup de una clave que viene del JSON. `String(localized:)` sólo acepta
    /// literales, así que las claves data-driven pasan por el bundle.
    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
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
            economy: economy
        )
        self.player = player
        effectsVersion += 1
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
    }

    /// Una recompensa por video con lo que falta para volver a ofrecerla.
    struct RewardRow: Identifiable, Equatable {
        let id: String
        let titleKey: String
        let cooldownRemaining: TimeInterval
    }
}
