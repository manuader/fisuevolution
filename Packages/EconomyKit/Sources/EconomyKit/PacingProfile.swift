import Foundation

/// Qué jugador simula el bot (PLAN-v2 E2b). `.free` define el contrato: lo que
/// el juego da sin mirar un video ni pagar. Los demás son las guardas.
public struct PacingProfile: Sendable, Equatable {
    public var usesFreeGifts: Bool
    public var watchesVideos: Bool
    public var ownsShopPermanents: Bool

    public static let bare = PacingProfile(usesFreeGifts: false, watchesVideos: false, ownsShopPermanents: false)
    public static let free = PacingProfile(usesFreeGifts: true, watchesVideos: false, ownsShopPermanents: false)
    public static let ads = PacingProfile(usesFreeGifts: true, watchesVideos: true, ownsShopPermanents: false)
    public static let max = PacingProfile(usesFreeGifts: true, watchesVideos: true, ownsShopPermanents: true)
}

/// Las fuentes de economía que no son comprar y fusionar, como datos. Las arma
/// el llamador desde el contenido real (`PacingFixture` en la app, el CLI desde
/// los JSON): EconomyKit no conoce la app.
public struct PacingSources: Sendable, Equatable {
    public struct FreeBoost: Sendable, Equatable {
        public enum Effect: Sendable, Equatable {
            case incomeBurst(multiplier: Double, seconds: Double)
            case tapBurst(multiplier: Double, seconds: Double)
            case payoutMinutes(Double)
            case offlineStep(step: Double, cap: Double)
        }

        public let id: String
        public let cooldownSeconds: Double
        public let effect: Effect

        public init(id: String, cooldownSeconds: Double, effect: Effect) {
            self.id = id
            self.cooldownSeconds = cooldownSeconds
            self.effect = effect
        }
    }

    public var packages: PackagesConfig?
    /// Minutos de producción del diario, del día 1 al 7 del ciclo.
    public var dailyMinutes: [Double]
    public var freeBoosts: [FreeBoost]
    /// Las contrataciones gratis del Programador al elegir carrera.
    public var freeHireSeconds: Double
    /// Lo que da mirar videos. Sólo lo juegan los perfiles que miran (`.ads`, `.max`).
    public var ads: AdsSources?
    /// Los permanentes de la tienda de ORO. Sólo los juega el perfil que paga (`.max`).
    public var shop: ShopPermanents?

    public init(
        packages: PackagesConfig?, dailyMinutes: [Double], freeBoosts: [FreeBoost], freeHireSeconds: Double,
        ads: AdsSources? = nil, shop: ShopPermanents? = nil
    ) {
        self.packages = packages
        self.dailyMinutes = dailyMinutes
        self.freeBoosts = freeBoosts
        self.freeHireSeconds = freeHireSeconds
        self.ads = ads
        self.shop = shop
    }

    public static let none = PacingSources(packages: nil, dailyMinutes: [], freeBoosts: [], freeHireSeconds: 0)
}

/// Los niveles de los tres permanentes de la tienda de ORO, ya resueltos por el
/// llamador con `OroShop.extraSlots/bestSupplierLevel/bonusDailyWheelSpins`.
public struct ShopPermanents: Sendable, Equatable {
    public var extraSlots: Int
    public var bestSupplierLevel: Int
    public var bonusDailyWheelSpins: Int

    public init(extraSlots: Int, bestSupplierLevel: Int, bonusDailyWheelSpins: Int) {
        self.extraSlots = extraSlots
        self.bestSupplierLevel = bestSupplierLevel
        self.bonusDailyWheelSpins = bonusDailyWheelSpins
    }
}

/// Las fuentes que se cobran mirando un video (PLAN-v2 E2b y E7b-b), con lo que
/// cuesta mirarlas: cada video le saca `videoSeconds` a la sesión del bot.
public struct AdsSources: Sendable, Equatable {
    /// Segundos de sesión que cuesta mirar un video.
    public var videoSeconds: Double
    /// El "×2 con video" del offline, del diario y de la carrera (1 = no se mira).
    public var offlineMultiplier: Double
    public var dailyMultiplier: Double
    public var careerMultiplier: Double
    public var wheel: WheelConfig?
    /// "Repetir premio": otro video por giro, y el mismo sorteo otra vez.
    public var wheelRepeats: Bool
    public var treasures: TreasuresConfig?
    /// Cada cuántos segundos activos sale la pausa publicitaria (`.infinity` = nunca).
    public var adBreakIntervalSeconds: Double
    /// Los premios de la pausa, que rotan en orden.
    public var adBreakPrizes: [RewardSpec]
    /// Cada cuántos segundos activos vuelve a haber un "Fusionar todo" por video.
    public var mergeAllCooldownSeconds: Double
    /// Cooldown de pared de la lluvia de paquetes.
    public var packageRainCooldownSeconds: Double
    public var packageRain: RewardSpec?

    public init(
        videoSeconds: Double, offlineMultiplier: Double, dailyMultiplier: Double, careerMultiplier: Double,
        wheel: WheelConfig?, wheelRepeats: Bool, treasures: TreasuresConfig?,
        adBreakIntervalSeconds: Double, adBreakPrizes: [RewardSpec],
        mergeAllCooldownSeconds: Double, packageRainCooldownSeconds: Double, packageRain: RewardSpec?
    ) {
        self.videoSeconds = videoSeconds
        self.offlineMultiplier = offlineMultiplier
        self.dailyMultiplier = dailyMultiplier
        self.careerMultiplier = careerMultiplier
        self.wheel = wheel
        self.wheelRepeats = wheelRepeats
        self.treasures = treasures
        self.adBreakIntervalSeconds = adBreakIntervalSeconds
        self.adBreakPrizes = adBreakPrizes
        self.mergeAllCooldownSeconds = mergeAllCooldownSeconds
        self.packageRainCooldownSeconds = packageRainCooldownSeconds
        self.packageRain = packageRain
    }
}
