import EconomyKit
import Foundation

/// Arma las entradas de `PlayerValue` (2.1 E15 F1, contrato C1) con lo que ya hay en el teléfono:
/// el ledger y los contadores del save, la tienda y el aparato (`DeviceContext`) y las sesiones de
/// `PersonalizationStore`. Puro: mismo save, mismas sesiones y misma hora, mismas entradas.
enum PlayerValueInputsBuilder {
    /// La ventana de «los últimos 7 días».
    static let window: TimeInterval = 7 * 24 * 60 * 60

    static func inputs(
        player: PlayerState,
        storefront: String?,
        deviceModel: String?,
        sessions: [PersonalizationRecord.Session],
        now: Date
    ) -> PlayerValueInputs {
        let meta = player.meta
        let ledger = meta.adRevenue
        let recent = sessions
            .filter { $0.startedAt <= now && now.timeIntervalSince($0.startedAt) < window }
            .sorted { $0.startedAt < $1.startedAt }
        let durations = recent.compactMap(\.seconds).filter { $0.isFinite && $0 >= 0 }
        let shownNow = offersShown(meta.offerFunnel)
        // Lo que pasó en la ventana: los contadores de ahora menos los del comienzo de la sesión más
        // vieja que entra. Un reset que los bajó no da negativo.
        let oldest = recent.first

        return PlayerValueInputs(
            storefront: storefront,
            deviceModel: deviceModel,
            rewardedCount: ledger.stats(.rewarded).count,
            averageRewardedMicros: ledger.averageRewardedMicros,
            recentRewardedMicros: ledger.recentMicros(format: .rewarded),
            hasPurchased: !meta.creditedPurchases.isEmpty,
            sessionsLast7Days: recent.count,
            meanSessionSeconds: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            videosWatchedEver: meta.stats.videosWatchedEver,
            offersSeenLast7Days: max(0, shownNow - (oldest?.offersShown ?? shownNow)),
            prestigesLast7Days: max(0, meta.prestigeLevel - (oldest?.prestige ?? meta.prestigeLevel))
        )
    }

    /// Las ofertas mostradas desde siempre, de todos los lugares.
    static func offersShown(_ funnel: OfferFunnel) -> Int {
        funnel.sites.values.reduce(0) { $0 + $1.shown }
    }
}
