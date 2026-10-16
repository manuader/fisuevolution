import Foundation

/// Lo que la app junta del jugador para estimar su valor (2.1 E15 F1, contrato C1). Todo sale del
/// propio juego y del teléfono; nada viaja: el cálculo es local.
public struct PlayerValueInputs: Sendable, Equatable {
    /// ISO 3166 alfa-3 de la tienda (`DeviceContext`), nil si no se sabe.
    public var storefront: String?
    /// `utsname.machine`, p. ej. `"iPhone16,2"`.
    public var deviceModel: String?
    /// `ledger.stats(.rewarded).count`.
    public var rewardedCount: Int
    /// `ledger.averageRewardedMicros`.
    public var averageRewardedMicros: Int64
    /// `ledger.recentMicros(format: .rewarded)`.
    public var recentRewardedMicros: Int64
    /// `meta.creditedPurchases` no vacío.
    public var hasPurchased: Bool
    public var sessionsLast7Days: Int
    public var meanSessionSeconds: Double
    /// `meta.stats.videosWatchedEver`.
    public var videosWatchedEver: Int

    public init(
        storefront: String? = nil,
        deviceModel: String? = nil,
        rewardedCount: Int = 0,
        averageRewardedMicros: Int64 = 0,
        recentRewardedMicros: Int64 = 0,
        hasPurchased: Bool = false,
        sessionsLast7Days: Int = 0,
        meanSessionSeconds: Double = 0,
        videosWatchedEver: Int = 0
    ) {
        self.storefront = storefront
        self.deviceModel = deviceModel
        self.rewardedCount = rewardedCount
        self.averageRewardedMicros = averageRewardedMicros
        self.recentRewardedMicros = recentRewardedMicros
        self.hasPurchased = hasPurchased
        self.sessionsLast7Days = sessionsLast7Days
        self.meanSessionSeconds = meanSessionSeconds
        self.videosWatchedEver = videosWatchedEver
    }
}

/// El resultado de `PlayerValue.evaluate` (2.1 E15 F1, contrato C1).
public struct PlayerValueEstimate: Sendable, Equatable {
    /// Nunca `.base`: `.base` lo decide la compuerta, no las reglas.
    public let segment: PlayerSegment
    /// Lo que se espera que pague un video con premio de este jugador, en micros.
    public let expectedMicrosPerVideo: Int64
    /// 0…1, para los umbrales y para el panel de debug.
    public let score: Double
    /// `PlayerValueTables.version` de las tablas con que se calculó.
    public let tablesVersion: String

    public init(segment: PlayerSegment, expectedMicrosPerVideo: Int64, score: Double, tablesVersion: String) {
        self.segment = segment
        self.expectedMicrosPerVideo = expectedMicrosPerVideo
        self.score = score
        self.tablesVersion = tablesVersion
    }
}
