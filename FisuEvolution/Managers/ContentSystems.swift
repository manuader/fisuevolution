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
        case spendingFrozen
    }

    static func purchase(
        lineId: String,
        state: inout PlayerState,
        config: UpgradesConfig,
        specials: SpecialsConfig,
        viral: ViralConfig,
        boosts: BoostsConfig,
        economy: StandardEconomy,
        now: TimeInterval
    ) throws {
        guard let line = config.upgrades.first(where: { $0.id == lineId }) else {
            throw PurchaseError.unknownLine
        }
        let level = state.meta.oroUpgradeLevels[lineId] ?? 0
        guard level < line.maxLevel else { throw PurchaseError.maxLevelReached }
        let price = cost(of: line, level: level)
        switch line.currency {
        case .coins:
            guard ModifierMath.spendingFrozenUntil(state.run.activeModifiers, now: now) == nil else {
                throw PurchaseError.spendingFrozen
            }
            guard state.run.coins >= price else { throw PurchaseError.insufficientCoins }
            state.run.coins -= price
        case .oro:
            guard state.meta.spendOro(Int(price.rounded(.up))) else { throw PurchaseError.insufficientOro }
        }
        state.meta.oroUpgradeLevels[lineId] = level + 1
        recomputeDerivedEffects(state: &state, config: config, specials: specials, viral: viral, boosts: boosts, economy: economy)
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
        boosts: BoostsConfig,
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
            case .luckyTouch:
                crit += level * line.magnitudePerLevel
                golden += level * line.goldenPerLevel
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
        let milanesaStep = boosts.boosts.first { $0.effectType == .offlineEfficiencyPermanent }?.magnitude ?? 0
        offline += Double(state.meta.oroUpgradeLevels[BoostManager.milanesaLevelKey] ?? 0) * milanesaStep

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

    /// Activa un boost gratuito respetando su cooldown. Devuelve las coins de la
    /// picada si fue el Asado (para el popup).
    @discardableResult
    static func activate(
        boostId: String,
        state: inout PlayerState,
        config: BoostsConfig,
        upgrades: UpgradesConfig,
        specials: SpecialsConfig,
        viral: ViralConfig,
        tiers: TierRepository,
        floorTable: FloorTable,
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
            UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: specials, viral: viral, boosts: config, economy: economy)
            return nil
        case .periodicPayout:
            // Asado del Domingo: la picada son `magnitude` minutos de producción.
            let payout = RewardScale.coinPayout(
                minutes: boost.magnitude, state: state, tiers: tiers, floorTable: floorTable, config: economy.config
            )
            state.run.coins += payout
            state.meta.lifetimeEarnings += payout
            return payout
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
        boosts: BoostsConfig,
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
                UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: config, viral: viral, boosts: boosts, economy: economy)
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
        /// El segundo escalón del día 7. Los tres premios son excluyentes: el
        /// popup muestra uno solo.
        let chestGranted: Bool
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
        skins: SkinsConfig,
        upgrades: UpgradesConfig,
        viral: ViralConfig,
        boosts: BoostsConfig,
        economy: StandardEconomy,
        tiers: TierRepository,
        floorTable: FloorTable,
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
        var chest = false
        if day.type == "special_roll" {
            let eligible = specials.specials.filter {
                !state.meta.ownedSpecials.contains($0.id) && state.meta.prestigeLevel >= $0.requiresPrestigeLevel
            }
            if let picked = eligible.randomElement(using: &rng) {
                state.meta.ownedSpecials.append(picked.id)
                UpgradeManager.recomputeDerivedEffects(state: &state, config: upgrades, specials: specials, viral: viral, boosts: boosts, economy: economy)
                special = picked.id
            } else if Set(state.meta.ownedSpecials).isSuperset(of: specials.specials.map(\.id)),
                      !state.meta.allOwnedSkins.isSuperset(of: skins.chestPool.map(\.id)) {
                // Segundo escalón: ya tenés los diez specials pero te faltan
                // pintas. NO se toca el camino del special: el día 7 sigue
                // siendo, primero, su día.
                //
                // ⚠️ La pregunta es por el CATÁLOGO COMPLETO y no por `eligible`,
                // que además filtra por `requiresPrestigeLevel`. Siete de los
                // diez specials piden prestigio 0 y los otros piden 3, 5 y 8:
                // colgado de `eligible`, un jugador en prestigio 0 con esos
                // siete tomados tendría el sorteo vacío con TRES specials sin
                // sacar, y el día 7 se le volvería una canilla semanal de
                // cofres desde media partida. Sin los diez, la caída sigue
                // siendo la de siempre: plata.
                //
                // El cofre se acredita tocando el estado y no llamando a
                // `GameState.awardChest`: esta función es pura sobre `inout
                // PlayerState` y no conoce la capa de arriba.
                state.meta.chestsPending += 1
                chest = true
            } else {
                coins = RewardScale.coinPayout(
                    minutes: day.minutes ?? 0, state: state, tiers: tiers, floorTable: floorTable, config: economy.config
                )
                state.run.coins += coins
                state.meta.lifetimeEarnings += coins
            }
        } else {
            coins = RewardScale.coinPayout(
                minutes: day.minutes ?? 0, state: state, tiers: tiers, floorTable: floorTable, config: economy.config
            )
            state.run.coins += coins
            state.meta.lifetimeEarnings += coins
        }

        state.meta.daily.lastClaimDay = todayString
        state.meta.daily.cycleDay = cycleDay >= config.days.count ? 1 : cycleDay + 1
        return Claim(day: day, coinsGranted: coins, specialGranted: special, chestGranted: chest)
    }
}
