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
        case insufficientOro
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
        let level = state.meta.oroUpgradeLevels[lineId] ?? 0
        guard level < line.maxLevel else { throw PurchaseError.maxLevelReached }
        let price = cost(of: line, level: level)
        switch line.currency {
        case .coins:
            guard state.run.coins >= price else { throw PurchaseError.insufficientCoins }
            state.run.coins -= price
        case .oro:
            let oroCost = Int(price.rounded(.up))
            guard state.meta.oro >= oroCost else { throw PurchaseError.insufficientOro }
            state.meta.oro -= oroCost
        }
        state.meta.oroUpgradeLevels[lineId] = level + 1
        recomputeDerivedEffects(state: &state, config: config, specials: specials, viral: viral, economy: economy)
    }

    /// ÚNICO punto que deriva `meta.derivedEffects` desde niveles + specials + shares.
    /// Se llama tras comprar upgrade, drop de special, share o milanesa.
    /// (Los multiplicadores POR PERSONAJE no entran acá: son per-type vía
    /// `CharUpgrades.multiplier` en los caminos de income — F7 §3.6.)
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
            // CLAMPEADO al tope, igual que `CharUpgrades.multiplier` y que el
            // espejo de EconomyKit. Un save anterior al rebalance de pacing
            // trae `income: 20` contra un tope que hoy es 10: sin el clamp ese
            // save cobra ×5,0 donde el máximo comprable es 3,0, y con `crit: 25`
            // el juego lo recorta por `EffectCaps` mientras el simulador no —
            // justo la divergencia que `upgradeLinesNeverReachTheirEffectCaps`
            // existe para prevenir.
            let level = Double(min(state.meta.oroUpgradeLevels[line.id] ?? 0, line.maxLevel))
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

        for special in specials.specials where state.meta.ownedSpecials.contains(special.id) {
            switch special.passiveEffect.type {
            case .incomeMultiplier: income *= special.passiveEffect.magnitude
            case .offlineEfficiencyBonus: offline += special.passiveEffect.magnitude
            case .critChanceBonus: crit += special.passiveEffect.magnitude
            case .spawnDiscount: spawnDiscount += special.passiveEffect.magnitude
            }
        }

        // Milanesa (boost permanente) reusa el dict de niveles con key propia.
        offline += Double(state.meta.oroUpgradeLevels[BoostManager.milanesaLevelKey] ?? 0) * 0.05

        // Referral local (bible §8): bonus permanente chico por share, con cap.
        let shares = min(state.meta.sharesCompleted, viral.maxShares)
        income *= 1.0 + Double(shares) * viral.shareBonusGlobalMultiplier

        state.meta.derivedEffects.incomeMultiplier = income
        state.meta.derivedEffects.tapMultiplier = tap
        // Los topes salen de `EffectCaps` y no de literales sueltos: son los
        // mismos que usa `EffectDescriptor` para armar la fila de la UI. Si se
        // duplican, la fila promete un efecto que esta función después recorta.
        state.meta.derivedEffects.critChance = min(crit, EffectCaps.crit)
        state.meta.derivedEffects.offlineEfficiency = min(offline, EffectCaps.offline)
        state.meta.derivedEffects.goldenChance = min(golden, EffectCaps.golden)
        state.meta.derivedEffects.spawnDiscount = min(spawnDiscount, EffectCaps.spawnDiscount)
        state.meta.derivedEffects.prestigeBonus = prestigeBonus
        state.meta.globalMultiplier = economy.globalMultiplier(
            oroEarnedLifetime: state.meta.oroEarnedLifetime,
            prestigeBonus: prestigeBonus
        )
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
        /// Tipo de unidad regalada (freeHighTier): el CALLER la coloca en la torre
        /// (EventManager no conoce los pisos).
        let grantedUnitTypeId: String?
        /// true si el evento mutó `run.units` (instantEvolution): el caller debe
        /// re-sincronizar la torre.
        let unitsChanged: Bool
    }

    /// Sortea el próximo evento elegible (weighted, respeta minTier y cooldowns)
    /// y aplica su efecto. Devuelve nil si nada es elegible.
    static func fireRandomEvent(
        state: inout PlayerState,
        config: EventsConfig,
        tiers: TierRepository,
        floorTable: FloorTable,
        economy: StandardEconomy,
        now: TimeInterval,
        lastFired: [String: TimeInterval],
        rng: inout some RandomNumberGenerator
    ) -> Roll? {
        let eligible = config.events.filter { event in
            state.run.maxTierReached >= event.minTier
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

        return apply(event: chosen, state: &state, tiers: tiers, floorTable: floorTable, economy: economy, now: now)
    }

    private static func apply(
        event: EventsConfig.Event,
        state: inout PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        economy: StandardEconomy,
        now: TimeInterval
    ) -> Roll? {
        var grantedUnitTypeId: String?
        var unitsChanged = false

        switch event.effectType {
        case .incomeMultiplier:
            state.run.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: event.magnitude,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
        case .spawnCostMultiplier:
            state.run.activeModifiers.append(ActiveModifier(
                effect: .spawnCostMultiplier,
                magnitude: event.magnitude,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
        case .frozenCoins:
            // Corralito: los coins no crecen (income x0) durante N segundos.
            state.run.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: 0,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
        case .bonusCoins:
            // Aguinaldo: magnitude = segundos de income pasivo actual, al toque.
            let bonus = IncomeTicker.passivePerSecond(
                state: state, tiers: tiers, floorTable: floorTable, config: economy.config, now: now
            ) * event.magnitude
            guard bonus > 0 else { return nil }
            state.run.coins += bonus
            state.meta.lifetimeEarnings += bonus
        case .instantEvolution:
            // Startup comprada: evoluciona una unidad top (merge gratis conceptual).
            guard let top = state.run.units.keys
                .compactMap({ tiers.type(id: $0) })
                .filter({ (state.run.units[$0.id] ?? 0) > 0 })
                .max(by: { $0.tier < $1.tier }),
                let nextId = top.mergesInto,
                let next = tiers.type(id: nextId), !next.isChoiceNode
            else { return nil }
            state.run.units[top.id, default: 0] -= 1
            if state.run.units[top.id] == 0 { state.run.units[top.id] = nil }
            state.run.units[nextId, default: 0] += 1
            state.run.markSeen(nextId)
            state.run.maxTierReached = max(state.run.maxTierReached, next.tier)
            unitsChanged = true
        case .freeHighTier:
            // Blanqueo: unidad gratis de tier (máx alcanzado − magnitude).
            let tier = max(1, state.run.maxTierReached - Int(event.magnitude))
            guard let type = tiers.concreteTypes.first(where: { candidate in
                candidate.tier == tier && (state.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
            }) ?? tiers.concreteTypes.first(where: { $0.tier == tier }) else { return nil }
            grantedUnitTypeId = type.id
        }

        let active: ActiveEvent = if event.durationSeconds > 0 {
            ActiveEvent(id: event.id, flavorTextKey: event.flavorTextKey, isBuff: event.isBuff, endsAt: now + event.durationSeconds)
        } else {
            // Efectos instantáneos: banner corto informativo.
            ActiveEvent(id: event.id, flavorTextKey: event.flavorTextKey, isBuff: event.isBuff, endsAt: now + 6)
        }
        return Roll(event: event, active: active, grantedUnitTypeId: grantedUnitTypeId, unitsChanged: unitsChanged)
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
        let last = state.meta.boostActivations[boost.id] ?? -.infinity
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

        state.meta.boostActivations[boost.id] = now

        switch boost.effectType {
        case .incomeMultiplier, .tapMultiplier, .spawnCostMultiplier:
            let effect: ActiveModifier.Effect = switch boost.effectType {
            case .incomeMultiplier: .incomeMultiplier
            case .tapMultiplier: .tapMultiplier
            default: .spawnCostMultiplier
            }
            state.run.activeModifiers.append(ActiveModifier(
                effect: effect,
                magnitude: boost.magnitude,
                expiresAt: now + boost.durationSeconds,
                sourceKey: "boost.\(boost.id)"
            ))
            return nil
        case .offlineEfficiencyPermanent:
            // Milanesa: mejora permanente, acumulable, capeada en la derivación.
            state.meta.oroUpgradeLevels[milanesaLevelKey, default: 0] += 1
            UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: specials, viral: viral, economy: economy)
            return nil
        case .periodicChest:
            // Asado del Domingo: cofre = factor × passiveUnlockCost(tier máximo).
            let chest = economy.passiveUnlockCost(forTier: state.run.maxTierReached) * boost.magnitude
            state.run.coins += chest
            state.meta.lifetimeEarnings += chest
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
            !state.meta.ownedSpecials.contains(special.id)
                && state.run.maxTierReached >= special.minTier
                && state.meta.prestigeLevel >= special.requiresPrestigeLevel
        }
        for special in eligible {
            if Double.random(in: 0..<1, using: &rng) < special.dropChanceOnMerge {
                state.meta.ownedSpecials.append(special.id)
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
        guard state.meta.daily.lastClaimDay != todayString else { return nil }

        if let last = state.meta.daily.lastClaimDay,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           last != dayString(for: yesterday, calendar: calendar) {
            state.meta.daily.cycleDay = 1
        }

        let cycleDay = min(max(state.meta.daily.cycleDay, 1), config.days.count)
        guard let day = config.days.first(where: { $0.day == cycleDay }) else { return nil }

        var coins = 0.0
        var special: String?
        if day.type == "special_roll" {
            let eligible = specials.specials.filter {
                !state.meta.ownedSpecials.contains($0.id) && state.meta.prestigeLevel >= $0.requiresPrestigeLevel
            }
            if let picked = eligible.randomElement(using: &rng) {
                state.meta.ownedSpecials.append(picked.id)
                UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: specials, viral: viral, economy: economy)
                special = picked.id
            } else {
                coins = economy.passiveUnlockCost(forTier: state.run.maxTierReached) * 6.0
                state.run.coins += coins
                state.meta.lifetimeEarnings += coins
            }
        } else {
            coins = economy.passiveUnlockCost(forTier: state.run.maxTierReached) * (day.coinsFactor ?? 1.0)
            state.run.coins += coins
            state.meta.lifetimeEarnings += coins
        }

        state.meta.daily.lastClaimDay = todayString
        state.meta.daily.cycleDay = cycleDay >= config.days.count ? 1 : cycleDay + 1
        return Claim(day: day, coinsGranted: coins, specialGranted: special)
    }
}
