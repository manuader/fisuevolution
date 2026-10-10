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

    public init(packages: PackagesConfig?, dailyMinutes: [Double], freeBoosts: [FreeBoost], freeHireSeconds: Double) {
        self.packages = packages
        self.dailyMinutes = dailyMinutes
        self.freeBoosts = freeBoosts
        self.freeHireSeconds = freeHireSeconds
    }

    public static let none = PacingSources(packages: nil, dailyMinutes: [], freeBoosts: [], freeHireSeconds: 0)
}
