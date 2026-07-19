import Foundation

/// Resolución de conflictos de saves entre devices (CloudKit, F6).
///
/// Regla (plan aprobado): gana el save con mayor `lifetimeEarnings` — es
/// monótonamente creciente en TODAS las mecánicas, incluido prestige, así que
/// ordena progreso real; `lastSeenTimestamp` solo desempata (los relojes entre
/// devices no son confiables). Excepciones por unión: compras y drops raros
/// nunca se pierden por pisar un save.
public enum SaveConflictResolver {
    public static func resolve(local: PlayerState, remote: PlayerState) -> PlayerState {
        var winner = pickWinner(local: local, remote: remote)
        winner.removedAds = local.removedAds || remote.removedAds
        winner.ownedSkins = Array(Set(local.ownedSkins).union(remote.ownedSkins)).sorted()
        winner.ownedSpecials = Array(Set(local.ownedSpecials).union(remote.ownedSpecials)).sorted()
        return winner
    }

    static func pickWinner(local: PlayerState, remote: PlayerState) -> PlayerState {
        if local.lifetimeEarnings != remote.lifetimeEarnings {
            return local.lifetimeEarnings > remote.lifetimeEarnings ? local : remote
        }
        return local.lastSeenTimestamp >= remote.lastSeenTimestamp ? local : remote
    }

    /// Scores de Game Center son Int64; `Int64(Double)` en magnitudes idle TRAPEA
    /// (crítico verificado: tapYield T30 ≈ 6.5e16 → lifetime supera 9.2e18 en
    /// ~140 taps). Clamp seguro, jamás conversión directa.
    public static func clampedScore(_ value: Double) -> Int64 {
        guard value.isFinite else { return .max }
        guard value < 9.2e18 else { return .max }
        guard value > 0 else { return 0 }
        return Int64(value)
    }
}
