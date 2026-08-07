import EconomyKit
import Foundation

/// Las cuatro fuentes de bonus del bible §1/§4.4: rewarded ads, boosts, eventos
/// y el daily con sus shares. Separado de `GameState.swift` para que el frente de
/// bonus no comparta archivo con los otros cinco dominios.
extension GameState {
    // MARK: Rewarded ads (F4 — efectos del bible §4.4)

    func applyRewardedReward(_ reward: RewardedAdsConfig.Reward) {
        guard var player else { return }
        let now = Date().timeIntervalSince1970
        switch reward.effectType {
        case .incomeMultiplier:
            guard let magnitude = reward.magnitude, let duration = reward.durationSeconds else { return }
            player.run.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: magnitude,
                expiresAt: now + duration,
                sourceKey: "rewarded.\(reward.id)"
            ))
            self.player = player
            refreshProjections()
            scheduleSave()
        case .instantMerge:
            performInstantMerge()
        case .rareUnit:
            grantRareUnit()
        }
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

    /// Devuelve las coins del cofre si el boost era el Asado.
    @discardableResult
    func activateBoost(id: String) -> Double? {
        guard let economy, let content, var player = player else { return nil }
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
