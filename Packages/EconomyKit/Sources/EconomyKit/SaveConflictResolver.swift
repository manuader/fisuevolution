import Foundation

/// Resolución de conflictos de saves entre devices (CloudKit).
///
/// Regla: gana el save con mayor `meta.lifetimeEarnings` — es monótonamente
/// creciente en TODAS las mecánicas, incluida la reencarnación, así que ordena
/// progreso real; `meta.lastSeenTimestamp` solo desempata (los relojes entre
/// devices no son confiables). Excepciones por unión/máximo: compras, drops
/// raros y ORO ganado nunca se pierden por pisar un save.
public enum SaveConflictResolver {
    public static func resolve(local: PlayerState, remote: PlayerState) -> PlayerState {
        var winner = pickWinner(local: local, remote: remote)
        let loser = winner == local ? remote : local

        winner.meta.removedAds = local.meta.removedAds || remote.meta.removedAds
        winner.meta.ownedSkins = Array(Set(local.meta.ownedSkins).union(remote.meta.ownedSkins)).sorted()
        winner.meta.milestoneSkins = Array(Set(local.meta.milestoneSkins).union(remote.meta.milestoneSkins)).sorted()
        winner.meta.ownedSpecials = Array(Set(local.meta.ownedSpecials).union(remote.meta.ownedSpecials)).sorted()

        // ORO ganado nunca retrocede: si el perdedor había ganado más ORO del que
        // el ganador vio, acreditá la diferencia (fue ganado en serio en el otro
        // device; el balance gastado del ganador se respeta).
        if loser.meta.oroEarnedLifetime > winner.meta.oroEarnedLifetime {
            winner.meta.oro += loser.meta.oroEarnedLifetime - winner.meta.oroEarnedLifetime
            winner.meta.oroEarnedLifetime = loser.meta.oroEarnedLifetime
        }

        // Skins activas: manda el ganador; las keys que solo el perdedor tenía se
        // completan (elección cosmética hecha en el otro device).
        for (typeId, skinId) in loser.meta.activeSkinByType
        where winner.meta.activeSkinByType[typeId] == nil {
            winner.meta.activeSkinByType[typeId] = skinId
        }

        // Stats de cuenta: son monótonas, así que el máximo de cada contador es el
        // valor real. Lo jugado en el otro device no se borra por perder el sync.
        winner.meta.stats.maxFloorOrdinalEver = max(local.meta.stats.maxFloorOrdinalEver, remote.meta.stats.maxFloorOrdinalEver)
        winner.meta.stats.totalMergesEver = max(local.meta.stats.totalMergesEver, remote.meta.stats.totalMergesEver)
        winner.meta.stats.totalHiresEver = max(local.meta.stats.totalHiresEver, remote.meta.stats.totalHiresEver)
        winner.meta.stats.totalTapsEver = max(local.meta.stats.totalTapsEver, remote.meta.stats.totalTapsEver)
        winner.meta.stats.videosWatchedEver = max(local.meta.stats.videosWatchedEver, remote.meta.stats.videosWatchedEver)
        winner.meta.stats.boostsActivatedEver = max(local.meta.stats.boostsActivatedEver, remote.meta.stats.boostsActivatedEver)

        // Logros: un logro conseguido no se des-consigue, y uno cobrado no se
        // vuelve a pagar. Unión de los dos lados en ambos conjuntos.
        winner.meta.unlockedAchievements = local.meta.unlockedAchievements.union(remote.meta.unlockedAchievements)
        winner.meta.claimedAchievements = local.meta.claimedAchievements.union(remote.meta.claimedAchievements)
        return winner
    }

    static func pickWinner(local: PlayerState, remote: PlayerState) -> PlayerState {
        if local.meta.lifetimeEarnings != remote.meta.lifetimeEarnings {
            return local.meta.lifetimeEarnings > remote.meta.lifetimeEarnings ? local : remote
        }
        return local.meta.lastSeenTimestamp >= remote.meta.lastSeenTimestamp ? local : remote
    }

    /// Scores de Game Center son Int64; `Int64(Double)` en magnitudes idle TRAPEA.
    /// Clamp seguro, jamás conversión directa.
    public static func clampedScore(_ value: Double) -> Int64 {
        guard value.isFinite else { return .max }
        guard value < 9.2e18 else { return .max }
        guard value > 0 else { return 0 }
        return Int64(value)
    }
}
