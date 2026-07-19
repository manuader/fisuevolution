import EconomyKit
import Foundation

/// Sistemas de contenido de F5 como funciones puras sobre `PlayerState` + configs.
/// RNG y reloj siempre inyectados — todo determinístico en tests.

// MARK: - Upgrades (las 7 líneas) + derivación única de efectos

enum UpgradeManager {
    static func cost(of line: UpgradesConfig.Line, level: Int) -> Double {
        line.baseCost * pow(line.costGrowth, Double(level))
    }

    enum PurchaseError: Error, Equatable {
        case unknownLine
        case maxLevelReached
        case insufficientCoins
    }

    static func purchase(
        lineId: String,
        state: inout PlayerState,
        config: UpgradesConfig,
        specials: SpecialsConfig,
        viral: ViralConfig,
        economy: StandardEconomy
    ) throws {
        guard let line = config.upgrades.first(where: { $0.id == lineId }) else {
            throw PurchaseError.unknownLine
        }
        let level = state.upgradeLevels[lineId] ?? 0
        guard level < line.maxLevel else { throw PurchaseError.maxLevelReached }
        let price = cost(of: line, level: level)
        guard state.coins >= price else { throw PurchaseError.insufficientCoins }

        state.coins -= price
        state.upgradeLevels[lineId] = level + 1
        recomputeDerivedEffects(state: &state, config: config, specials: specials, viral: viral, economy: economy)
    }

    /// ÚNICO punto que deriva `UpgradeState` desde niveles + specials + shares.
    /// Se llama tras comprar upgrade, drop de special, share o milanesa.
    static func recomputeDerivedEffects(
        state: inout PlayerState,
        config: UpgradesConfig,
        specials: SpecialsConfig,
        viral: ViralConfig,
        economy: StandardEconomy
    ) {
        var income = 1.0
        var tap = 1.0
        var crit = economy.config.critChanceBase
        var offline = economy.config.offlineEfficiencyBase
        var golden = 0.0
        var spawnDiscount = 0.0
        var prestigeBonus = 0.0

        for line in config.upgrades {
            let level = Double(state.upgradeLevels[line.id] ?? 0)
            guard level > 0 else { continue }
            switch line.effectType {
            case .incomeMultiplier: income += level * line.magnitudePerLevel
            case .tapMultiplier: tap += level * line.magnitudePerLevel
            case .critChance: crit += level * line.magnitudePerLevel
            case .offlineEfficiency: offline += level * line.magnitudePerLevel
            case .goldenTouchChance: golden += level * line.magnitudePerLevel
            case .spawnCostDiscount: spawnDiscount += level * line.magnitudePerLevel
            case .prestigeBonusPerSoulPoint: prestigeBonus += level * line.magnitudePerLevel
            }
        }

        for special in specials.specials where state.ownedSpecials.contains(special.id) {
            switch special.passiveEffect.type {
            case .incomeMultiplier: income *= special.passiveEffect.magnitude
            case .offlineEfficiencyBonus: offline += special.passiveEffect.magnitude
            case .critChanceBonus: crit += special.passiveEffect.magnitude
            case .spawnDiscount: spawnDiscount += special.passiveEffect.magnitude
            }
        }

        // Milanesa (boost permanente) reusa el dict de niveles con key propia.
        offline += Double(state.upgradeLevels[BoostManager.milanesaLevelKey] ?? 0) * 0.05

        // Referral local (bible §8): bonus permanente chico por share, con cap.
        let shares = min(state.sharesCompleted, viral.maxShares)
        income *= 1.0 + Double(shares) * viral.shareBonusGlobalMultiplier

        state.upgrades.incomeMultiplier = income
        state.upgrades.tapMultiplier = tap
        state.upgrades.critChance = min(crit, 0.5)
        state.upgrades.offlineEfficiency = min(offline, 1.0)
        state.upgrades.goldenChance = min(golden, 0.1)
        state.upgrades.spawnDiscount = min(spawnDiscount, 0.6)
        state.upgrades.prestigeBonus = prestigeBonus
        state.globalMultiplier = economy.globalMultiplier(soulPoints: state.soulPoints, prestigeBonus: prestigeBonus)
    }
}

// MARK: - Eventos argentinizados (bible §1)

enum EventManager {
    struct ActiveEvent: Equatable, Identifiable {
        let id: String
        let flavorTextKey: String
        let isBuff: Bool
        let endsAt: TimeInterval
    }

    struct Roll {
        let event: EventsConfig.Event
        let active: ActiveEvent?
    }

    /// Sortea el próximo evento elegible (weighted, respeta minTier y cooldowns)
    /// y aplica su efecto. Devuelve nil si nada es elegible.
    static func fireRandomEvent(
        state: inout PlayerState,
        config: EventsConfig,
        tiers: TierRepository,
        economy: StandardEconomy,
        now: TimeInterval,
        lastFired: [String: TimeInterval],
        rng: inout some RandomNumberGenerator
    ) -> Roll? {
        let eligible = config.events.filter { event in
            state.maxTierReached >= event.minTier
                && now - (lastFired[event.id] ?? -.infinity) >= event.cooldownSeconds
        }
        guard !eligible.isEmpty else { return nil }

        let totalWeight = eligible.map(\.weight).reduce(0, +)
        var pick = Int.random(in: 0..<max(totalWeight, 1), using: &rng)
        var chosen = eligible[0]
        for event in eligible {
            pick -= event.weight
            if pick < 0 {
                chosen = event
                break
            }
        }

        let active = apply(event: chosen, state: &state, tiers: tiers, economy: economy, now: now)
        return Roll(event: chosen, active: active)
    }

    private static func apply(
        event: EventsConfig.Event,
        state: inout PlayerState,
        tiers: TierRepository,
        economy: StandardEconomy,
        now: TimeInterval
    ) -> ActiveEvent? {
        switch event.effectType {
        case .incomeMultiplier:
            state.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: event.magnitude,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
        case .spawnCostMultiplier:
            state.activeModifiers.append(ActiveModifier(
                effect: .spawnCostMultiplier,
                magnitude: event.magnitude,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
        case .frozenCoins:
            // Corralito: los coins no crecen (income x0) durante N segundos.
            state.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: 0,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
        case .bonusCoins:
            // Aguinaldo: magnitude = segundos de income pasivo actual, al toque.
            let bonus = IncomeTicker.passivePerSecond(state: state, tiers: tiers, now: now) * event.magnitude
            guard bonus > 0 else { return nil }
            state.coins += bonus
            state.lifetimeEarnings += bonus
        case .instantEvolution:
            // Startup comprada: evoluciona la unidad top (merge gratis conceptual).
            guard let top = state.board
                .compactMap({ placement in tiers.type(id: placement.typeId).map { (placement, $0) } })
                .max(by: { $0.1.tier < $1.1.tier }),
                let nextId = top.1.mergesInto,
                let next = tiers.type(id: nextId), !next.isChoiceNode,
                let index = state.board.firstIndex(of: top.0)
            else { return nil }
            state.board[index] = BoardPlacement(cellIndex: top.0.cellIndex, typeId: nextId)
            state.maxTierReached = max(state.maxTierReached, next.tier)
        case .freeHighTier:
            // Blanqueo: unidad gratis de tier (máx alcanzado − magnitude).
            let tier = max(1, state.maxTierReached - Int(event.magnitude))
            guard let type = tiers.concreteTypes.first(where: { candidate in
                candidate.tier == tier && (state.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
            }) ?? tiers.concreteTypes.first(where: { $0.tier == tier }) else { return nil }
            let occupied = Set(state.board.map(\.cellIndex))
            guard let free = (0..<economy.config.board.cellCount).first(where: { !occupied.contains($0) }) else { return nil }
            state.board.append(BoardPlacement(cellIndex: free, typeId: type.id))
        }

        guard event.durationSeconds > 0 else {
            // Efectos instantáneos: banner corto informativo.
            return ActiveEvent(id: event.id, flavorTextKey: event.flavorTextKey, isBuff: event.isBuff, endsAt: now + 6)
        }
        return ActiveEvent(id: event.id, flavorTextKey: event.flavorTextKey, isBuff: event.isBuff, endsAt: now + event.durationSeconds)
    }
}

// MARK: - Boosts (bible §1, review-safe por buildVariant)

enum BoostManager {
    static let milanesaLevelKey = "_milanesa"

    enum ActivationError: Error, Equatable {
        case unknownBoost
        case onCooldown(remaining: TimeInterval)
    }

    static func cooldownRemaining(of boost: BoostsConfig.Boost, state: PlayerState, now: TimeInterval) -> TimeInterval {
        let last = state.boostActivations[boost.id] ?? -.infinity
        return max(0, boost.cooldownSeconds - (now - last))
    }

    /// Activa un boost gratuito respetando su cooldown. Devuelve las coins del
    /// cofre si fue el Asado (para el popup).
    @discardableResult
    static func activate(
        boostId: String,
        state: inout PlayerState,
        config: BoostsConfig,
        upgrades: UpgradesConfig,
        specials: SpecialsConfig,
        viral: ViralConfig,
        tiers: TierRepository,
        economy: StandardEconomy,
        now: TimeInterval
    ) throws -> Double? {
        guard let boost = config.boosts.first(where: { $0.id == boostId }) else {
            throw ActivationError.unknownBoost
        }
        let remaining = cooldownRemaining(of: boost, state: state, now: now)
        guard remaining <= 0 else { throw ActivationError.onCooldown(remaining: remaining) }

        state.boostActivations[boost.id] = now

        switch boost.effectType {
        case .incomeMultiplier, .tapMultiplier, .spawnCostMultiplier:
            let effect: ActiveModifier.Effect = switch boost.effectType {
            case .incomeMultiplier: .incomeMultiplier
            case .tapMultiplier: .tapMultiplier
            default: .spawnCostMultiplier
            }
            state.activeModifiers.append(ActiveModifier(
                effect: effect,
                magnitude: boost.magnitude,
                expiresAt: now + boost.durationSeconds,
                sourceKey: "boost.\(boost.id)"
            ))
            return nil
        case .offlineEfficiencyPermanent:
            // Milanesa: mejora permanente, acumulable, capeada en la derivación.
            state.upgradeLevels[milanesaLevelKey, default: 0] += 1
            UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: specials, viral: viral, economy: economy)
            return nil
        case .periodicChest:
            // Asado del Domingo: cofre = factor × passiveUnlockCost(tier máximo).
            let chest = economy.passiveUnlockCost(forTier: state.maxTierReached) * boost.magnitude
            state.coins += chest
            state.lifetimeEarnings += chest
            return chest
        }
    }
}

// MARK: - Special characters como rare drops (bible §1)

enum SpecialDropManager {
    /// Tirada tras cada merge. Devuelve el special dropeado (ya aplicado) o nil.
    static func rollOnMerge(
        state: inout PlayerState,
        config: SpecialsConfig,
        upgrades: UpgradesConfig,
        viral: ViralConfig,
        economy: StandardEconomy,
        rng: inout some RandomNumberGenerator
    ) -> SpecialsConfig.Special? {
        let eligible = config.specials.filter { special in
            !state.ownedSpecials.contains(special.id)
                && state.maxTierReached >= special.minTier
                && state.prestigeLevel >= special.requiresPrestigeLevel
        }
        for special in eligible {
            if Double.random(in: 0..<1, using: &rng) < special.dropChanceOnMerge {
                state.ownedSpecials.append(special.id)
                UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: config, viral: viral, economy: economy)
                return special
            }
        }
        return nil
    }
}

// MARK: - Daily reward (ciclo de 7 días)

enum DailyRewardManager {
    struct Claim: Equatable {
        let day: DailyRewardsConfig.Day
        let coinsGranted: Double
        let specialGranted: String?
    }

    static func dayString(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// Reclama el daily si hoy no fue reclamado. Un día salteado resetea el ciclo.
    static func claimIfAvailable(
        state: inout PlayerState,
        config: DailyRewardsConfig,
        specials: SpecialsConfig,
        upgrades: UpgradesConfig,
        viral: ViralConfig,
        economy: StandardEconomy,
        today: Date,
        calendar: Calendar = .current,
        rng: inout some RandomNumberGenerator
    ) -> Claim? {
        let todayString = dayString(for: today, calendar: calendar)
        guard state.daily.lastClaimDay != todayString else { return nil }

        if let last = state.daily.lastClaimDay,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           last != dayString(for: yesterday, calendar: calendar) {
            state.daily.cycleDay = 1
        }

        let cycleDay = min(max(state.daily.cycleDay, 1), config.days.count)
        guard let day = config.days.first(where: { $0.day == cycleDay }) else { return nil }

        var coins = 0.0
        var special: String?
        if day.type == "special_roll" {
            let eligible = specials.specials.filter {
                !state.ownedSpecials.contains($0.id) && state.prestigeLevel >= $0.requiresPrestigeLevel
            }
            if let picked = eligible.randomElement(using: &rng) {
                state.ownedSpecials.append(picked.id)
                UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: specials, viral: viral, economy: economy)
                special = picked.id
            } else {
                coins = economy.passiveUnlockCost(forTier: state.maxTierReached) * 6.0
                state.coins += coins
                state.lifetimeEarnings += coins
            }
        } else {
            coins = economy.passiveUnlockCost(forTier: state.maxTierReached) * (day.coinsFactor ?? 1.0)
            state.coins += coins
            state.lifetimeEarnings += coins
        }

        state.daily.lastClaimDay = todayString
        state.daily.cycleDay = cycleDay >= config.days.count ? 1 : cycleDay + 1
        return Claim(day: day, coinsGranted: coins, specialGranted: special)
    }
}
