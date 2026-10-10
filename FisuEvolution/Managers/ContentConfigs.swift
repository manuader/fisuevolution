import Foundation

/// Codable mirrors de los JSON del track Content (F5). Nada de esto se hardcodea:
/// boosts, upgrades, specials, daily, viral y Game Center son datos.

struct SpecialsConfig: Codable, Sendable, Equatable {
    struct PassiveEffect: Codable, Sendable, Equatable {
        enum Kind: String, Codable, Sendable, CaseIterable {
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
    /// `EffectDescriptorTests` recorrer todos los tipos y verificar que ninguno
    /// se queda sin descripción en pantalla.
    enum EffectType: String, Codable, Sendable, CaseIterable {
        case incomeMultiplier
        case spawnCostDiscount
        case offlineEfficiency
        case tapMultiplier
        case critChance
        case goldenTouchChance
        case luckyTouch
        case prestigeBonusPerSoulPoint
    }

    struct Line: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let titleKey: String
        let iconKey: String
        let effectType: EffectType
        let magnitudePerLevel: Double
        /// Sólo `luckyTouch` lo usa: el dorado que da por nivel (el crítico es `magnitudePerLevel`).
        let goldenPerLevel: Double
        let maxLevel: Int
        let baseCost: Double
        let costGrowth: Double
        /// Los JSON v1 no tenían moneda: se decodifican como coins para que un
        /// catálogo viejo siga siendo válido durante la transición F7.4.
        let currency: Currency

        private enum CodingKeys: String, CodingKey {
            case id, titleKey, iconKey, effectType, magnitudePerLevel, goldenPerLevel, maxLevel, baseCost, costGrowth, currency
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            titleKey = try container.decode(String.self, forKey: .titleKey)
            iconKey = try container.decode(String.self, forKey: .iconKey)
            effectType = try container.decode(EffectType.self, forKey: .effectType)
            magnitudePerLevel = try container.decode(Double.self, forKey: .magnitudePerLevel)
            goldenPerLevel = try container.decodeIfPresent(Double.self, forKey: .goldenPerLevel) ?? 0
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
        /// Minutos de producción que paga el día (PLAN-v2 E2a). En el día del
        /// special es lo que paga si no hay special ni cofre que dar.
        let minutes: Double?
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
        /// Su `magnitude` son minutos de producción.
        case periodicPayout
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
        /// Piso que hay que haber alcanzado para que el boost aparezca (RF-12).
        /// El mapeo vive acá y no en código: repartirlos distinto es editar JSON.
        let unlockFloorId: String
        let reviewSafe: ReviewSafeText

        /// La build de store sirve SOLO los textos review-safe (Guideline 2.3.1).
        func displayNameKey(buildVariant: String) -> String {
            buildVariant == "store" ? reviewSafe.displayNameKey : displayNameKey
        }

        /// Gemelo del anterior: el chiste también tiene su versión review-safe.
        func flavorTextKey(buildVariant: String) -> String {
            buildVariant == "store" ? reviewSafe.flavorTextKey : flavorTextKey
        }
    }

    let schemaVersion: Int
    let boosts: [Boost]
}

/// Qué se lleva el jugador por elegir cada carrera en el piso corporativo (RF-15).
///
/// Las cuatro ramas se reabsorben en el Director, así que sin esto la elección no
/// define nada. Qué premio le toca a cada una vive en `careers.json` y no en
/// código: cambiarlo es editar el JSON, y el loader valida que el payload que
/// necesita cada tipo esté declarado.
struct CareersConfig: Codable, Sendable, Equatable {
    /// Los cuatro tipos son distintos ENTRE SÍ a propósito: cuatro variantes del
    /// mismo premio vuelven a ser la elección decorativa que esto arregla.
    enum RewardKind: String, Codable, Sendable, CaseIterable {
        /// El Programador: contratar gratis un rato, sin mover la curva.
        case freeHires
        /// El Arquitecto: una skin desbloqueada de una.
        case skin
        /// El Abogado, "Juicio ganado": una suma en minutos de producción.
        case lawsuit
        /// El Médico, "Obra social": inmunidad a los eventos negativos, corta el
        /// que está corriendo y paga unos minutos de producción.
        case healthPlan
    }

    struct Career: Codable, Sendable, Equatable, Identifiable {
        /// typeId de la opción (una de `tiers.json → junior.choiceOptions`).
        let id: String
        let rewardKind: RewardKind
        /// `skin`: qué skin se desbloquea.
        let skinId: String?
        /// `freeHires` y `healthPlan`: cuánto dura el efecto.
        let durationSeconds: Double?
        /// `lawsuit` y `healthPlan`: minutos de producción que paga al elegir.
        let lumpMinutes: Double?
    }

    let schemaVersion: Int
    let careers: [Career]
}

struct ViralConfig: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let shareBonusGlobalMultiplier: Double
    let maxShares: Int
    /// El premio de compartir un momento viral, en minutos de producción real, una
    /// vez por momento.
    let momentRewardMinutes: Int
}

/// Los logros del spec §10.3. Data-driven como todo lo demás: qué hay que hacer
/// (`trigger`) y qué se lleva por hacerlo (`reward`) son dato, no código.
///
/// `trigger.type` y `reward.kind` viajan como `String` —el schema que fija el
/// spec— y se leen a través de los dos enums de abajo. Esa indirección es la que
/// hace que el switch del motor pueda ser **exhaustivo**: agregar un gatillo al
/// enum sin su caso en el motor no compila, en vez de dejar un logro que no se
/// desbloquea nunca y no se queja. Un `type` que no esté en el enum lo rechaza
/// `GameContentLoader.validate` al arrancar, no en runtime.
struct AchievementsConfig: Codable, Sendable, Equatable {
    /// Los quince gatillos que el motor sabe evaluar.
    enum TriggerKind: String, Sendable, CaseIterable {
        /// El piso de `floorId` está abierto (o lo estuvo alguna vez).
        case floorUnlocked
        case tierReached
        case totalMerges
        case totalHires
        case totalTaps
        case prestigeLevel
        case skinsOwned
        /// TODAS las skins del catálogo. Sin `value`: el objetivo es
        /// `skins.count`, así que sumar la skin 46 mueve el logro sin tocar
        /// este JSON ni re-balancear nada.
        case skinsAll
        case specialsOwned
        case videosWatched
        case boostsActivated
        case lifetimeEarnings
        /// Los tipos CONCRETOS de `tiers.json` (el nodo de elección `junior` no
        /// cuenta: es una bifurcación, no un personaje). Sin `value`, ídem.
        case seenAllTypes
        /// El ciclo del daily llegó a su último día.
        case dailyDay7
        case sharesCompleted

        /// Los que se miden contra un número escrito en el JSON. Los otros tres
        /// sacan el objetivo de otro lado (un piso, o el tamaño de un catálogo).
        var requiresValue: Bool {
            switch self {
            case .floorUnlocked, .skinsAll, .seenAllTypes: false
            default: true
            }
        }

        var requiresFloorID: Bool { self == .floorUnlocked }
    }

    /// Las tres formas de pagar un logro.
    enum RewardKind: String, Sendable, CaseIterable {
        /// `seconds` × lo que la torre produce por segundo, igual que el
        /// Aguinaldo: el premio es **tiempo de tu producción de hoy**, así que
        /// nunca queda ni de lingote ni de polvo (ver `GameState.coinReward`).
        case coins
        /// `amount` de ORO al BALANCE. Nunca a `oroEarnedLifetime`.
        case oro
        /// Un boost regalado que no consume su cooldown (premio del Médico).
        case freeBoost
    }

    struct Trigger: Codable, Sendable, Equatable {
        let type: String
        let value: Double?
        let floorId: String?

        var kind: TriggerKind? { TriggerKind(rawValue: type) }
    }

    struct Reward: Codable, Sendable, Equatable {
        let kind: String
        /// Sólo `coins`: **cuántos segundos de la producción actual** paga el
        /// logro. Se llamaba `factor` y multiplicaba un COSTO, que no veía ni el
        /// multiplicador global ni las char upgrades: el premio era un lingote
        /// temprano y polvo tarde. Ahora la unidad es la del Aguinaldo y el
        /// nombre lo dice.
        let seconds: Double?
        let amount: Int?
        let boostId: String?

        var rewardKind: RewardKind? { RewardKind(rawValue: kind) }
    }

    struct Achievement: Codable, Sendable, Equatable, Identifiable {
        /// Estable para siempre: se persiste en `meta.unlockedAchievements`.
        let id: String
        let titleKey: String
        let descKey: String
        /// `trophy_bronze` / `trophy_silver` / `trophy_gold`. La vista mapea al
        /// arte; el catálogo no conoce nombres de assets.
        let icon: String
        let trigger: Trigger
        let reward: Reward
    }

    let schemaVersion: Int
    let achievements: [Achievement]
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
