import Foundation

/// Codable mirrors de los JSON del track Content (F5). Nada de esto se hardcodea:
/// eventos, boosts, upgrades, specials, daily, viral y Game Center son datos.

struct EventsConfig: Codable, Sendable, Equatable {
    enum EffectType: String, Codable, Sendable {
        case incomeMultiplier
        case instantEvolution
        case freeHighTier
        case spawnCostMultiplier
        case frozenCoins
        case bonusCoins
    }

    struct Event: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let effectType: EffectType
        let magnitude: Double
        let durationSeconds: Double
        let weight: Int
        let minTier: Int
        let cooldownSeconds: Double
        let flavorTextKey: String
        let isBuff: Bool
    }

    let schemaVersion: Int
    let baseIntervalSeconds: Double
    let intervalJitterSeconds: Double
    let events: [Event]
}

struct SpecialsConfig: Codable, Sendable, Equatable {
    struct PassiveEffect: Codable, Sendable, Equatable {
        enum Kind: String, Codable, Sendable {
            case incomeMultiplier
            case offlineEfficiencyBonus
            case critChanceBonus
            case spawnDiscount
        }

        let type: Kind
        let magnitude: Double
    }

    struct Special: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let displayNameKey: String
        let flavorTextKey: String
        let dropChanceOnMerge: Double
        let minTier: Int
        let requiresPrestigeLevel: Int
        let passiveEffect: PassiveEffect
    }

    let schemaVersion: Int
    let specials: [Special]
}

struct UpgradesConfig: Codable, Sendable, Equatable {
    enum Currency: String, Codable, Sendable {
        case coins
        case oro
    }
    /// `CaseIterable` no es cosmético: es lo que le deja a
    /// `EffectDescriptorTests` recorrer los siete tipos y verificar que ninguno
    /// se queda sin descripción en pantalla.
    enum EffectType: String, Codable, Sendable, CaseIterable {
        case incomeMultiplier
        case spawnCostDiscount
        case offlineEfficiency
        case tapMultiplier
        case critChance
        case goldenTouchChance
        case prestigeBonusPerSoulPoint
    }

    struct Line: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let titleKey: String
        let iconKey: String
        let effectType: EffectType
        let magnitudePerLevel: Double
        let maxLevel: Int
        let baseCost: Double
        let costGrowth: Double
        /// Los JSON v1 no tenían moneda: se decodifican como coins para que un
        /// catálogo viejo siga siendo válido durante la transición F7.4.
        let currency: Currency

        private enum CodingKeys: String, CodingKey {
            case id, titleKey, iconKey, effectType, magnitudePerLevel, maxLevel, baseCost, costGrowth, currency
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            titleKey = try container.decode(String.self, forKey: .titleKey)
            iconKey = try container.decode(String.self, forKey: .iconKey)
            effectType = try container.decode(EffectType.self, forKey: .effectType)
            magnitudePerLevel = try container.decode(Double.self, forKey: .magnitudePerLevel)
            maxLevel = try container.decode(Int.self, forKey: .maxLevel)
            baseCost = try container.decode(Double.self, forKey: .baseCost)
            costGrowth = try container.decode(Double.self, forKey: .costGrowth)
            currency = try container.decodeIfPresent(Currency.self, forKey: .currency) ?? .coins
        }
    }

    let schemaVersion: Int
    let upgrades: [Line]
}

struct DailyRewardsConfig: Codable, Sendable, Equatable {
    struct Day: Codable, Sendable, Equatable {
        let day: Int
        let type: String
        let coinsFactor: Double?
        let titleKey: String
    }

    let schemaVersion: Int
    let days: [Day]
}

struct BoostsConfig: Codable, Sendable, Equatable {
    /// Ídem `UpgradesConfig.EffectType`: `CaseIterable` es lo que hace real el
    /// test de cobertura de `EffectDescriptor`.
    enum EffectType: String, Codable, Sendable, CaseIterable {
        case incomeMultiplier
        case tapMultiplier
        case spawnCostMultiplier
        case offlineEfficiencyPermanent
        case periodicChest
    }

    struct ReviewSafeText: Codable, Sendable, Equatable {
        let displayNameKey: String
        let flavorTextKey: String
    }

    struct Boost: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let iconKey: String
        let effectType: EffectType
        let magnitude: Double
        let durationSeconds: Double
        let cooldownSeconds: Double
        let displayNameKey: String
        let flavorTextKey: String
        let reviewSafe: ReviewSafeText

        /// La build de store sirve SOLO los textos review-safe (Guideline 2.3.1).
        func displayNameKey(buildVariant: String) -> String {
            buildVariant == "store" ? reviewSafe.displayNameKey : displayNameKey
        }
    }

    let schemaVersion: Int
    let boosts: [Boost]
}

struct ViralConfig: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let shareBonusGlobalMultiplier: Double
    let maxShares: Int
}

struct GameCenterConfig: Codable, Sendable, Equatable {
    struct Leaderboard: Codable, Sendable, Equatable {
        let id: String
        let titleKey: String
    }

    struct Achievement: Codable, Sendable, Equatable {
        let id: String
        let titleKey: String
        let trigger: String
        let tier: Int?
    }

    let schemaVersion: Int
    let leaderboards: [Leaderboard]
    let achievements: [Achievement]
}
