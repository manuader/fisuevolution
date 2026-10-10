import EconomyKit
import Foundation

/// Everything data-driven the game needs, loaded and validated once at launch.
struct GameContent: Sendable {
    var economy: EconomyConfig
    let tiers: TierRepository
    /// La Torre (F7): mapeo tier→piso validado, derivado de `economy.floors`.
    let floorTable: FloorTable
    let manifest: AssetsManifest
    let flags: FeatureFlags
    let prestigeUnlocks: PrestigeUnlocks
    let rewardedAds: RewardedAdsConfig
    let events: EventCatalog
    let specials: SpecialsConfig
    let skins: SkinsConfig
    let chests: ChestsConfig
    let upgradesConfig: UpgradesConfig
    let dailyRewards: DailyRewardsConfig
    let boosts: BoostsConfig
    let careers: CareersConfig
    let viral: ViralConfig
    let gameCenter: GameCenterConfig
    let achievements: AchievementsConfig
    /// Qué abre cada pestaña de la barra (PLAN-v2 E3).
    let tabs: TabsConfig
    /// Las notificaciones locales: el catálogo y sus reglas (PLAN-v2 E11).
    let notifications: NotificationsConfig
    /// Los visitantes y sus guiones (PLAN-v2 E4, Anexos A y B).
    let visitors: VisitorsConfig
    /// El Paquete de la Aduana, El Colchón y la Ruleta (PLAN-v2 E5).
    let packages: PackagesConfig
    let treasures: TreasuresConfig
    let wheel: WheelConfig
    /// Las ofertas de 24 h (PLAN-v2 E6).
    let offers: OffersCatalog
}

/// Decodes and validates the bundled JSON content. Any failure produces a typed
/// `GameError` with a precise log detail; Debug builds assert so bad content is
/// caught immediately, Release builds show a friendly error screen.
enum GameContentLoader {
    static func load(from bundle: Bundle) throws -> GameContent {
        let tiersFile: TiersFile = try decode("tiers", from: bundle)
        let economy: EconomyConfig = try decode("economy", from: bundle)
        let manifest: AssetsManifest = try decode("assets_manifest", from: bundle)
        let flags: FeatureFlags = try decode("feature_flags", from: bundle)
        let prestigeUnlocks: PrestigeUnlocks = try decode("prestige_unlocks", from: bundle)
        let rewardedAds: RewardedAdsConfig = try decode("rewarded_ads", from: bundle)
        let events: EventCatalog = try decode("events", from: bundle)
        let specials: SpecialsConfig = try decode("specials", from: bundle)
        let skins: SkinsConfig = try decode("skins", from: bundle)
        let chests: ChestsConfig = try decode("chests", from: bundle)
        let upgradesConfig: UpgradesConfig = try decode("upgrades", from: bundle)
        let dailyRewards: DailyRewardsConfig = try decode("daily_rewards", from: bundle)
        let boosts: BoostsConfig = try decode("boosts", from: bundle)
        let careers: CareersConfig = try decode("careers", from: bundle)
        let viral: ViralConfig = try decode("viral", from: bundle)
        let gameCenter: GameCenterConfig = try decode("gamecenter", from: bundle)
        let achievements: AchievementsConfig = try decode("achievements", from: bundle)
        let notifications: NotificationsConfig = try decode("notifications", from: bundle)
        let tabs: TabsConfig = try decode("tabs", from: bundle)
        let visitors: VisitorsConfig = try decode("visitors", from: bundle)
        let packages: PackagesConfig = try decode("packages", from: bundle)
        let treasures: TreasuresConfig = try decode("treasures", from: bundle)
        let wheel: WheelConfig = try decode("wheel", from: bundle)
        let offers: OffersCatalog = try decode("offers", from: bundle)

        let tiers: TierRepository
        do {
            tiers = try TierRepository(types: tiersFile.types)
        } catch {
            throw GameError.contentInvalid(file: "tiers.json", reason: "\(error)")
        }

        let floorTable: FloorTable
        do {
            floorTable = try FloorTable(floors: economy.floors, maxTier: tiers.maxTier)
        } catch {
            throw GameError.contentInvalid(file: "economy.json (floors)", reason: "\(error)")
        }
        // Todo fondo referenciado por un piso tiene que existir en el manifest.
        for floor in floorTable.floors where manifest.backgrounds[floor.background] == nil {
            throw GameError.contentInvalid(
                file: "economy.json (floors)",
                reason: "floor \(floor.id) references unknown background \(floor.background)"
            )
        }
        do {
            try skins.validate(
                characterTypeIDs: Set(tiers.concreteTypes.map(\.id)),
                floorIDs: Set(floorTable.floors.map(\.id))
            )
        } catch {
            throw GameError.contentInvalid(file: "skins.json", reason: "\(error)")
        }

        // RF-12: el mapeo boost→piso vive en el JSON, así que un id mal escrito
        // dejaría un boost inalcanzable para siempre y en silencio.
        let floorIDs = Set(floorTable.floors.map(\.id))
        for boost in boosts.boosts where !floorIDs.contains(boost.unlockFloorId) {
            throw GameError.contentInvalid(
                file: "boosts.json",
                reason: "boost \(boost.id) references unknown floor \(boost.unlockFloorId)"
            )
        }
        try validate(careers: careers, tiers: tiers, skins: skins)
        try validate(achievements: achievements, floorTable: floorTable, boosts: boosts)
        try tabs.validate()
        do {
            try notifications.validate()
        } catch {
            throw GameError.contentInvalid(file: "notifications.json", reason: "\(error)")
        }
        do {
            try visitors.validate()
        } catch {
            throw GameError.contentInvalid(file: "visitors.json", reason: "\(error)")
        }
        do {
            try events.validate(
                visitorIDs: Set(visitors.visitors.map(\.id)),
                scriptIDs: Set(visitors.scripts.map(\.id))
            )
        } catch {
            throw GameError.contentInvalid(file: "events.json", reason: "\(error)")
        }
        // Un especial que visita tiene que existir: si no, su guion nunca sale
        // (nadie lo consigue) y su arte no se encuentra.
        let specialIDs = Set(specials.specials.map(\.id))
        for visitor in visitors.visitors where visitor.kind == .special && !specialIDs.contains(visitor.id) {
            throw GameError.contentInvalid(file: "visitors.json", reason: "\(visitor.id) no está en specials.json")
        }

        try validatePrize(packages.validate, file: "packages.json")
        try validatePrize(treasures.validate, file: "treasures.json")
        try validatePrize(wheel.validate, file: "wheel.json")
        try validatePrize(offers.validate, file: "offers.json")

        return GameContent(
            economy: economy,
            tiers: tiers,
            floorTable: floorTable,
            manifest: manifest,
            flags: flags,
            prestigeUnlocks: prestigeUnlocks,
            rewardedAds: rewardedAds,
            events: events,
            specials: specials,
            skins: skins,
            chests: chests,
            upgradesConfig: upgradesConfig,
            dailyRewards: dailyRewards,
            boosts: boosts,
            careers: careers,
            viral: viral,
            gameCenter: gameCenter,
            achievements: achievements,
            tabs: tabs,
            notifications: notifications,
            visitors: visitors,
            packages: packages,
            treasures: treasures,
            wheel: wheel,
            offers: offers
        )
    }

    /// Un logro mal declarado no rompe nada visible: se desbloquea nunca, o paga
    /// cero, y nadie se entera hasta que un jugador lo reporta. Por eso el
    /// catálogo se valida entero al arrancar, igual que las carreras.
    ///
    /// No es `private` a propósito: los casos que rechaza son el contrato del
    /// catálogo y `AchievementEngineTests` los ejerce uno por uno.
    static func validate(
        achievements: AchievementsConfig,
        floorTable: FloorTable,
        boosts: BoostsConfig
    ) throws {
        func fail(_ reason: String) -> GameError { .contentInvalid(file: "achievements.json", reason: reason) }

        let entries = achievements.achievements
        guard Set(entries.map(\.id)).count == entries.count else {
            throw fail("hay dos logros con el mismo id: el save no podría distinguirlos")
        }
        let floorIDs = Set(floorTable.floors.map(\.id))
        for achievement in entries {
            guard !achievement.titleKey.isEmpty, !achievement.descKey.isEmpty, !achievement.icon.isEmpty else {
                throw fail("\(achievement.id): titleKey, descKey e icon no pueden estar vacíos")
            }
            guard let trigger = achievement.trigger.kind else {
                throw fail("\(achievement.id): trigger desconocido '\(achievement.trigger.type)'")
            }
            if trigger.requiresValue {
                guard let value = achievement.trigger.value, value > 0 else {
                    throw fail("\(achievement.id): \(trigger.rawValue) necesita un value > 0")
                }
            }
            if trigger.requiresFloorID {
                guard let floorID = achievement.trigger.floorId, floorIDs.contains(floorID) else {
                    throw fail("\(achievement.id): floorId desconocido '\(achievement.trigger.floorId ?? "")'")
                }
            }
            guard let reward = achievement.reward.rewardKind else {
                throw fail("\(achievement.id): reward desconocida '\(achievement.reward.kind)'")
            }
            switch reward {
            case .coins:
                guard let seconds = achievement.reward.seconds, seconds > 0 else {
                    throw fail("\(achievement.id): coins necesita seconds > 0")
                }
            case .oro:
                guard let amount = achievement.reward.amount, amount > 0 else {
                    throw fail("\(achievement.id): oro necesita amount > 0")
                }
            case .freeBoost:
                guard let boostID = achievement.reward.boostId,
                      boosts.boosts.contains(where: { $0.id == boostID })
                else {
                    throw fail("\(achievement.id): freeBoost apunta a un boost inexistente")
                }
            }
        }
    }

    /// RF-15: cada carrera declara su premio en `careers.json`, así que acá se
    /// chequea que la opción exista, que el payload que ese tipo de premio
    /// necesita esté, y que no haya dos carreras con el mismo tipo — que es lo
    /// que convertiría la elección otra vez en cuatro variantes de lo mismo.
    private static func validate(
        careers: CareersConfig,
        tiers: TierRepository,
        skins: SkinsConfig
    ) throws {
        func fail(_ reason: String) -> GameError { .contentInvalid(file: "careers.json", reason: reason) }

        let options = Set(tiers.types.flatMap { $0.choiceOptions ?? [] })
        guard careers.careers.count == options.count else {
            throw fail("hay \(careers.careers.count) carreras declaradas y \(options.count) opciones en tiers.json")
        }
        guard Set(careers.careers.map(\.rewardKind)).count == careers.careers.count else {
            throw fail("dos carreras dan el mismo tipo de premio: la elección deja de ser una elección")
        }
        for career in careers.careers {
            guard options.contains(career.id) else {
                throw fail("\(career.id) no es una opción de carrera de tiers.json")
            }
            switch career.rewardKind {
            case .freeHires:
                guard let duration = career.durationSeconds, duration > 0 else {
                    throw fail("\(career.id): freeHires necesita durationSeconds > 0")
                }
            case .skin:
                guard let skinId = career.skinId, skins.skins.contains(where: { $0.id == skinId }) else {
                    throw fail("\(career.id): skin apunta a una skin inexistente")
                }
            case .lawsuit:
                guard let minutes = career.lumpMinutes, minutes > 0 else {
                    throw fail("\(career.id): lawsuit necesita lumpMinutes > 0")
                }
            case .healthPlan:
                guard let duration = career.durationSeconds, duration > 0,
                      let minutes = career.lumpMinutes, minutes > 0
                else {
                    throw fail("\(career.id): healthPlan necesita durationSeconds y lumpMinutes > 0")
                }
            }
        }
    }

    /// Un premio mal declarado se descubre al arrancar, no cuando el jugador lo
    /// abre: el error dice qué archivo y por qué.
    private static func validatePrize(_ validate: () throws -> Void, file: String) throws {
        do {
            try validate()
        } catch {
            throw GameError.contentInvalid(file: file, reason: "\(error)")
        }
    }

    private static func decode<T: Decodable>(_ name: String, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw GameError.contentFileMissing("\(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw GameError.contentInvalid(file: "\(name).json", reason: "\(error)")
        }
    }
}
