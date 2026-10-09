import Foundation

/// Resolución de conflictos de saves entre devices (CloudKit).
///
/// Regla: gana el save con mayor `meta.lifetimeEarnings` — es monótonamente
/// creciente en TODAS las mecánicas, incluida la reencarnación, así que ordena
/// progreso real; `meta.lastSeenTimestamp` solo desempata (los relojes entre
/// devices no son confiables). Excepciones por unión/máximo: compras, drops
/// raros y ORO ganado nunca se pierden por pisar un save. Una excepción a la
/// regla: con `meta.resetEpoch` distinta gana el save del reset más nuevo, entero
/// (ver `resolveAcrossReset`).
public enum SaveConflictResolver {
    public static func resolve(local: PlayerState, remote: PlayerState) -> PlayerState {
        if local.meta.resetEpoch != remote.meta.resetEpoch {
            return resolveAcrossReset(local: local, remote: remote)
        }
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

        // Cofres sin abrir: el máximo de los dos, por lo mismo que el ORO de
        // arriba —lo ganado no retrocede—. El caso que lo pide: el jugador junta
        // cofres en un device que todavía no sincronizó, ese save pierde el
        // resolve y los cofres se evaporan.
        //
        // El precio, dicho en voz alta: en el camino inverso REGALA. Abrir un
        // cofre en el device A baja el contador y acredita la pinta; si gana el
        // save de B —que todavía tenía el cofre— la pinta queda por la unión de
        // `milestoneSkins` de arriba y el contador vuelve. Se acepta a
        // sabiendas: entre regalar un cofre de vez en cuando y comerse uno que el
        // jugador se ganó, el juego prefiere lo primero. Son premios cosméticos.
        winner.meta.chestsPending = max(local.meta.chestsPending, remote.meta.chestsPending)
        winner.meta.prestigeChestsPending = max(local.meta.prestigeChestsPending, remote.meta.prestigeChestsPending)

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

        // La 2.0: lo comprado y lo gastado no retroceden y una pestaña revelada no
        // se vuelve a esconder. `revealedTier`, `priceRelief`, `lastRunMaxTier` y
        // el pin viajan con el ganador: son del estado de la run o de una
        // elección, no un acumulado.
        //
        // El ORO comprado se une por transacción y no por total: los dos devices
        // pueden haber acreditado compras distintas, y un `max` del contador
        // perdería la del otro. Las tres uniones son conmutativas e idempotentes;
        // si dos builds anotaron montos distintos para el mismo id, queda el mayor.
        // La reconstrucción cuenta como hecha sólo si los dos lados la hicieron:
        // repetirla no suma de más (asigna por id), saltearla sí perdería ORO.
        winner.meta.oro += unseenOro(of: loser, by: winner, revoked: local.meta.revokedPurchases.union(remote.meta.revokedPurchases))
        winner.meta.creditedPurchases = local.meta.creditedPurchases.union(remote.meta.creditedPurchases)
        winner.meta.oroPurchases = local.meta.oroPurchases.merging(remote.meta.oroPurchases, uniquingKeysWith: max)
        winner.meta.revokedPurchases = local.meta.revokedPurchases.union(remote.meta.revokedPurchases)
        winner.meta.purchasedOroReconstructed = local.meta.purchasedOroReconstructed && remote.meta.purchasedOroReconstructed
        winner.meta.unlockedTabs = local.meta.unlockedTabs.union(remote.meta.unlockedTabs)
        winner.meta.stats.oroSpentEver = max(local.meta.stats.oroSpentEver, remote.meta.stats.oroSpentEver)
        winner.meta.engagement = EngagementState.resolve(winner: winner.meta.engagement, loser: loser.meta.engagement)
        winner.meta.ranking = RankingState.resolve(winner: winner.meta.ranking, loser: loser.meta.ranking)
        return winner
    }

    /// El ORO comprado que `other` tiene anotado y `receiver` todavía no vio: ids que
    /// `receiver` no tiene en `oroPurchases`, que nadie revocó y que `receiver` no
    /// acreditó ya por el camino viejo (un id de la v1 sin reconstruir). Se suma al saldo
    /// de `receiver` antes de unir los mapas: así la unión es asociativa y el ORO de un
    /// pack no se pierde ni se cuenta dos veces según el orden en que se crucen los devices.
    private static func unseenOro(of other: PlayerState, by receiver: PlayerState, revoked: Set<String>) -> Int {
        other.meta.oroPurchases
            .filter {
                receiver.meta.oroPurchases[$0.key] == nil
                    && !revoked.contains($0.key)
                    && !receiver.meta.creditedPurchases.contains($0.key)
            }
            .values.reduce(0, +)
    }

    /// Dos épocas distintas: gana entera la del reset más nuevo, sin mirar el progreso. Del
    /// lado viejo cruzan sólo las compras —lo pagado con plata no se pierde por resetear— y
    /// el ORO de las transacciones que el lado nuevo todavía no vio (cada una, una vez: la
    /// segunda resolución ya las encuentra anotadas y no suma nada) y, del ranking, el último
    /// nombre y una llegada a Dios sin enviar (ver `RankingState.resolveAcrossReset`). Las compras que no son
    /// de ORO (monedas, starter) hechas en el dispositivo viejo después del reset no cruzan:
    /// es una decisión tomada.
    static func resolveAcrossReset(local: PlayerState, remote: PlayerState) -> PlayerState {
        var newer = local.meta.resetEpoch > remote.meta.resetEpoch ? local : remote
        let older = local.meta.resetEpoch > remote.meta.resetEpoch ? remote : local

        newer.meta.oro += unseenOro(
            of: older, by: newer,
            revoked: newer.meta.revokedPurchases.union(older.meta.revokedPurchases)
        )
        for (id, amount) in older.meta.oroPurchases {
            newer.meta.recordOroPurchase(transactionID: id, amount: amount)
        }
        for id in older.meta.revokedPurchases {
            newer.meta.revokePurchase(transactionID: id)
        }
        newer.meta.creditedPurchases.formUnion(older.meta.creditedPurchases)
        newer.meta.purchasedOroReconstructed = newer.meta.purchasedOroReconstructed && older.meta.purchasedOroReconstructed
        newer.meta.removedAds = newer.meta.removedAds || older.meta.removedAds
        newer.meta.ownedSkins = Array(Set(newer.meta.ownedSkins).union(older.meta.ownedSkins)).sorted()
        newer.meta.ranking = RankingState.resolveAcrossReset(newer: newer.meta.ranking, older: older.meta.ranking)
        return newer
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
