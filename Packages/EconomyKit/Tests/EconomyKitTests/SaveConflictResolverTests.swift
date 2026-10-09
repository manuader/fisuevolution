import Foundation
import Testing
@testable import EconomyKit

// MARK: - Sync CloudKit: el save que más progresó gana, lo comprado nunca se pierde

@Suite("SaveConflictResolver (sync CloudKit)")
struct SaveConflictResolverTests {
    /// Estado v4 con el meta mínimo que mira el resolver.
    private func fxSave(lifetime: Double, lastSeen: TimeInterval = 1000) -> PlayerState {
        var state = fxState()
        state.meta.lifetimeEarnings = lifetime
        state.meta.lastSeenTimestamp = lastSeen
        return state
    }

    @Test("gana el de mayor lifetimeEarnings, sin importar de qué lado venga")
    func higherLifetimeWinsBothDirections() {
        // El timestamp del atrasado es más nuevo a propósito: no debe pesar.
        let ahead = fxSave(lifetime: 1000, lastSeen: 1)
        let behind = fxSave(lifetime: 10, lastSeen: 999)
        #expect(SaveConflictResolver.resolve(local: ahead, remote: behind).meta.lifetimeEarnings == 1000)
        #expect(SaveConflictResolver.resolve(local: behind, remote: ahead).meta.lifetimeEarnings == 1000)
    }

    @Test("empate de lifetime: desempata lastSeenTimestamp")
    func timestampBreaksTies() {
        let older = fxSave(lifetime: 500, lastSeen: 100)
        let newer = fxSave(lifetime: 500, lastSeen: 200)
        #expect(SaveConflictResolver.resolve(local: older, remote: newer).meta.lastSeenTimestamp == 200)
        #expect(SaveConflictResolver.resolve(local: newer, remote: older).meta.lastSeenTimestamp == 200)
    }

    @Test("empate total: gana el local (el ≥ del desempate)")
    func fullTieFavorsLocal() {
        // Mismo lifetime y mismo timestamp; marcamos el local por las coins de la run.
        var local = fxSave(lifetime: 500, lastSeen: 100)
        local.run.coins = 42
        let remote = fxSave(lifetime: 500, lastSeen: 100)
        #expect(SaveConflictResolver.resolve(local: local, remote: remote).run.coins == 42)
    }

    @Test("los cofres de piso cobrados no retroceden, gane quien gane")
    func floorChestsAwardedTakeTheMax() {
        var ahead = fxSave(lifetime: 1000)
        ahead.meta.floorChestsAwarded = 2
        var behind = fxSave(lifetime: 10)
        behind.meta.floorChestsAwarded = 4
        #expect(SaveConflictResolver.resolve(local: ahead, remote: behind).meta.floorChestsAwarded == 4)
        #expect(SaveConflictResolver.resolve(local: behind, remote: ahead).meta.floorChestsAwarded == 4)
    }

    @Test("compras, milestones y specials se unen sobre el ganador")
    func purchasesMergeByUnion() {
        // Lo comprado/ganado en el device perdedor no se puede esfumar.
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.meta.removedAds = true
        loser.meta.ownedSkins = ["golden"]
        loser.meta.milestoneSkins = ["m_first"]
        loser.meta.ownedSpecials = ["sp_cryptobro"]
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.meta.ownedSkins = ["god"]
        winner.meta.milestoneSkins = ["m_tower"]
        winner.meta.ownedSpecials = ["sp_coach"]

        let resolved = SaveConflictResolver.resolve(local: loser, remote: winner)
        #expect(resolved.meta.lifetimeEarnings == 1000)
        #expect(resolved.meta.removedAds)
        // Unión ORDENADA: el resolver normaliza para que el resultado sea determinista.
        #expect(resolved.meta.ownedSkins == ["god", "golden"])
        #expect(resolved.meta.milestoneSkins == ["m_first", "m_tower"])
        #expect(resolved.meta.ownedSpecials == ["sp_coach", "sp_cryptobro"])
    }

    @Test("ORO del perdedor: se acredita la diferencia y el lifetime sube al máximo")
    func loserOroCreditsDifference() {
        // El perdedor ganó 25 de ORO en su device; el ganador solo vio 10 y le
        // quedan 3 en el balance (gastó 7). Le entran los 15 que nunca vio.
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.meta.oro = 3
        winner.meta.oroEarnedLifetime = 10
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.meta.oro = 25
        loser.meta.oroEarnedLifetime = 25

        let resolved = SaveConflictResolver.resolve(local: loser, remote: winner)
        #expect(resolved.meta.oro == 18)
        #expect(resolved.meta.oroEarnedLifetime == 25)
    }

    @Test("ORO del ganador ya mayor: el balance gastado se respeta, nada cambia")
    func winnerOroAheadStaysUntouched() {
        // El ganador ya ganó más ORO que el perdedor: no hay crédito, y el balance
        // bajo (porque GASTÓ) no se "repone" con el del perdedor.
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.meta.oro = 3
        winner.meta.oroEarnedLifetime = 25
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.meta.oro = 10
        loser.meta.oroEarnedLifetime = 10

        let resolved = SaveConflictResolver.resolve(local: winner, remote: loser)
        #expect(resolved.meta.oro == 3)
        #expect(resolved.meta.oroEarnedLifetime == 25)
    }

    @Test("skin activa: manda el ganador y se completan las keys que solo tenía el perdedor")
    func activeSkinsWinnerRulesLoserFills() {
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.meta.activeSkinByType = ["a": "god"]
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.meta.activeSkinByType = ["a": "golden", "b": "casual"]

        let resolved = SaveConflictResolver.resolve(local: loser, remote: winner)
        // "a" la eligió el ganador; "b" solo existía en el otro device, se completa.
        #expect(resolved.meta.activeSkinByType == ["a": "god", "b": "casual"])
    }

    @Test("stats de cuenta: cada contador queda en el máximo de los dos devices")
    func statsMergeByMax() {
        // Contadores cruzados a propósito: cada device lideró en unos y no en otros.
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.meta.stats = MetaStats(
            maxFloorOrdinalEver: 3, totalMergesEver: 100, totalHiresEver: 5,
            totalTapsEver: 900, videosWatchedEver: 1, boostsActivatedEver: 8
        )
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.meta.stats = MetaStats(
            maxFloorOrdinalEver: 7, totalMergesEver: 20, totalHiresEver: 50,
            totalTapsEver: 12, videosWatchedEver: 9, boostsActivatedEver: 2
        )
        let expected = MetaStats(
            maxFloorOrdinalEver: 7, totalMergesEver: 100, totalHiresEver: 50,
            totalTapsEver: 900, videosWatchedEver: 9, boostsActivatedEver: 8
        )

        // Da igual de qué lado venga cada uno: el resultado es el mismo.
        #expect(SaveConflictResolver.resolve(local: winner, remote: loser).meta.stats == expected)
        #expect(SaveConflictResolver.resolve(local: loser, remote: winner).meta.stats == expected)
    }

    /// El agujero que abrió la acción de abrir cofres (F8): el resolver se
    /// llevaba los dos contadores del ganador tal cual, y `milestoneSkins` se
    /// UNE. O sea que abrir un cofre en el device A —pinta acreditada, contador
    /// 1 → 0— y perder el resolve contra B devolvía el contador con la pinta ya
    /// puesta: cofre gratis.
    @Test("cofres sin abrir: cada contador queda en el máximo de los dos devices")
    func pendingChestsMergeByMax() {
        // Los DOS contadores se prueban por los dos lados —una vuelta liderando
        // el ganador y otra el perdedor—: con un solo lado, "quedarse con los del
        // ganador" pasaría igual en la mitad de las líneas.
        for lideraElPerdedor in [true, false] {
            var winner = fxSave(lifetime: 1000, lastSeen: 2)
            winner.meta.chestsPending = lideraElPerdedor ? 1 : 4
            winner.meta.prestigeChestsPending = lideraElPerdedor ? 0 : 3
            var loser = fxSave(lifetime: 10, lastSeen: 1)
            loser.meta.chestsPending = lideraElPerdedor ? 4 : 1
            loser.meta.prestigeChestsPending = lideraElPerdedor ? 3 : 0

            // Y da igual de qué lado del sync venga cada uno.
            for resolved in [
                SaveConflictResolver.resolve(local: winner, remote: loser),
                SaveConflictResolver.resolve(local: loser, remote: winner),
            ] {
                #expect(resolved.meta.chestsPending == 4)
                #expect(resolved.meta.prestigeChestsPending == 3,
                        "un cofre de prestigio ganado en el otro device no se puede evaporar")
            }
        }
    }

    @Test("logros: desbloqueados y cobrados se unen, gane quien gane")
    func achievementsMergeByUnion() {
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.meta.unlockedAchievements = ["ach_merge", "ach_piso"]
        winner.meta.claimedAchievements = ["ach_merge"]
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.meta.unlockedAchievements = ["ach_video"]
        loser.meta.claimedAchievements = ["ach_video"]

        let resolved = SaveConflictResolver.resolve(local: loser, remote: winner)
        #expect(resolved.meta.lifetimeEarnings == 1000)
        // Lo conseguido en el device perdedor no se pierde ni se vuelve a cobrar.
        #expect(resolved.meta.unlockedAchievements == ["ach_merge", "ach_piso", "ach_video"])
        #expect(resolved.meta.claimedAchievements == ["ach_merge", "ach_video"])
    }

    @Test("los campos de la 2.0 no retroceden al resolver")
    func v6FieldsResolve() {
        var local = fxState()
        var remote = fxState()
        local.meta.lifetimeEarnings = 10
        remote.meta.lifetimeEarnings = 5
        remote.meta.recordOroPurchase(transactionID: "tx_550", amount: 550)
        remote.meta.unlockedTabs = ["gifts"]
        local.meta.unlockedTabs = ["jobs"]
        remote.meta.stats.oroSpentEver = 30
        let resolved = SaveConflictResolver.resolve(local: local, remote: remote)
        #expect(resolved.meta.oroPurchasedLifetime == 550)
        #expect(resolved.meta.unlockedTabs == ["gifts", "jobs"])
        #expect(resolved.meta.stats.oroSpentEver == 30)
    }

    @Test("ORO comprado, ORO gastado y pestañas: la unión o el máximo, gane quien gane")
    func v6MonotonicFieldsMergeBothWays() {
        var ahead = fxSave(lifetime: 1000, lastSeen: 2)
        ahead.meta.recordOroPurchase(transactionID: "tx_100", amount: 100)
        ahead.meta.stats.oroSpentEver = 80
        ahead.meta.unlockedTabs = ["jobs", "store"]
        var behind = fxSave(lifetime: 10, lastSeen: 1)
        behind.meta.recordOroPurchase(transactionID: "tx_550", amount: 550)
        behind.meta.stats.oroSpentEver = 30
        behind.meta.unlockedTabs = ["gifts", "store"]

        for resolved in [
            SaveConflictResolver.resolve(local: ahead, remote: behind),
            SaveConflictResolver.resolve(local: behind, remote: ahead),
        ] {
            #expect(resolved.meta.lifetimeEarnings == 1000)
            #expect(resolved.meta.oroPurchasedLifetime == 650, "las dos compras, ninguna pisa a la otra")
            #expect(resolved.meta.stats.oroSpentEver == 80)
            #expect(resolved.meta.unlockedTabs == ["gifts", "jobs", "store"])
        }
    }

    @Test("la reconstrucción sólo cuenta como hecha si los dos devices la hicieron")
    func reconstructionFlagNeedsBothSides() {
        var done = fxSave(lifetime: 10, lastSeen: 1)
        done.meta.purchasedOroReconstructed = true
        var pending = fxSave(lifetime: 1000, lastSeen: 2)
        pending.meta.purchasedOroReconstructed = false

        #expect(!SaveConflictResolver.resolve(local: done, remote: pending).meta.purchasedOroReconstructed)
        #expect(!SaveConflictResolver.resolve(local: pending, remote: done).meta.purchasedOroReconstructed)
        #expect(SaveConflictResolver.resolve(local: done, remote: done).meta.purchasedOroReconstructed)

        var bothPending = fxSave(lifetime: 10, lastSeen: 1)
        bothPending.meta.purchasedOroReconstructed = false
        #expect(!SaveConflictResolver.resolve(local: bothPending, remote: pending).meta.purchasedOroReconstructed)
    }

    // MARK: - ORO comprado exacto entre devices

    /// A reconstruyó un pack de la v1 (250); B, instalación nueva, compró uno de
    /// la v2 (750). Lo exacto es 1000: el `max` de antes daba 750.
    @Test("el pack de la v1 de un device y el de la v2 del otro suman los dos")
    func purchasesFromBothDevicesAddUp() {
        var deviceA = fxSave(lifetime: 1000, lastSeen: 2)
        deviceA.meta.creditedPurchases = ["v1_tx"]
        deviceA.meta.recordOroPurchase(transactionID: "v1_tx", amount: 250)
        var deviceB = fxSave(lifetime: 10, lastSeen: 1)
        deviceB.meta.creditedPurchases = ["v2_tx"]
        deviceB.meta.recordOroPurchase(transactionID: "v2_tx", amount: 750)

        for resolved in [
            SaveConflictResolver.resolve(local: deviceA, remote: deviceB),
            SaveConflictResolver.resolve(local: deviceB, remote: deviceA),
        ] {
            #expect(resolved.meta.oroPurchasedLifetime == 1000)
            #expect(resolved.meta.creditedPurchases == ["v1_tx", "v2_tx"])
        }
    }

    @Test("la misma transacción vista por los dos devices se cuenta una sola vez")
    func theSameTransactionCountsOnce() {
        var local = fxSave(lifetime: 1000, lastSeen: 2)
        local.meta.recordOroPurchase(transactionID: "shared", amount: 750)
        var remote = fxSave(lifetime: 10, lastSeen: 1)
        remote.meta.recordOroPurchase(transactionID: "shared", amount: 750)
        remote.meta.recordOroPurchase(transactionID: "only_remote", amount: 250)

        #expect(SaveConflictResolver.resolve(local: local, remote: remote).meta.oroPurchasedLifetime == 1000)
        #expect(SaveConflictResolver.resolve(local: remote, remote: local).meta.oroPurchasedLifetime == 1000)
    }

    @Test("si dos builds anotaron montos distintos para el mismo id, gana el mayor")
    func differingAmountsForTheSameIdTakeTheLarger() {
        var local = fxSave(lifetime: 1000, lastSeen: 2)
        local.meta.recordOroPurchase(transactionID: "tx", amount: 250)
        var remote = fxSave(lifetime: 10, lastSeen: 1)
        remote.meta.recordOroPurchase(transactionID: "tx", amount: 750)

        #expect(SaveConflictResolver.resolve(local: local, remote: remote).meta.oroPurchasedLifetime == 750)
        #expect(SaveConflictResolver.resolve(local: remote, remote: local).meta.oroPurchasedLifetime == 750)
    }

    @Test("resolver un save consigo mismo no cambia el ORO comprado")
    func resolvingASaveWithItselfIsIdempotent() {
        var save = fxSave(lifetime: 1000, lastSeen: 2)
        save.meta.creditedPurchases = ["a", "b"]
        save.meta.recordOroPurchase(transactionID: "a", amount: 250)
        save.meta.recordOroPurchase(transactionID: "b", amount: 750)
        save.meta.revokePurchase(transactionID: "b")

        let once = SaveConflictResolver.resolve(local: save, remote: save)
        let twice = SaveConflictResolver.resolve(local: once, remote: save)
        #expect(once.meta.oroPurchasedLifetime == 250)
        #expect(twice.meta.oroPurchasedLifetime == 250)
        #expect(twice.meta.oroPurchases == save.meta.oroPurchases)
        #expect(twice.meta.revokedPurchases == save.meta.revokedPurchases)
    }

    @Test("una compra reembolsada en un solo device no cuenta, aunque el otro la tenga")
    func aRevocationOnOneSideWins() {
        var refunded = fxSave(lifetime: 10, lastSeen: 1)
        refunded.meta.recordOroPurchase(transactionID: "refunded", amount: 750)
        refunded.meta.revokePurchase(transactionID: "refunded")
        var unaware = fxSave(lifetime: 1000, lastSeen: 2)
        unaware.meta.recordOroPurchase(transactionID: "refunded", amount: 750)
        unaware.meta.recordOroPurchase(transactionID: "kept", amount: 250)

        for resolved in [
            SaveConflictResolver.resolve(local: refunded, remote: unaware),
            SaveConflictResolver.resolve(local: unaware, remote: refunded),
        ] {
            #expect(resolved.meta.oroPurchasedLifetime == 250)
            #expect(resolved.meta.revokedPurchases == ["refunded"])
        }
    }

    @Test("el reembolso que llega antes que la compra igual la deja afuera")
    func aRevocationBeforeThePurchaseStillExcludesIt() {
        var refundSeen = fxSave(lifetime: 10, lastSeen: 1)
        refundSeen.meta.revokePurchase(transactionID: "late")
        var purchaseSeen = fxSave(lifetime: 1000, lastSeen: 2)
        purchaseSeen.meta.recordOroPurchase(transactionID: "late", amount: 750)

        #expect(SaveConflictResolver.resolve(local: refundSeen, remote: purchaseSeen).meta.oroPurchasedLifetime == 0)
        #expect(SaveConflictResolver.resolve(local: purchaseSeen, remote: refundSeen).meta.oroPurchasedLifetime == 0)
    }

    @Test("las compras acreditadas de los dos lados se unen")
    func creditedPurchasesAreUnited() {
        var local = fxSave(lifetime: 1000, lastSeen: 2)
        local.meta.creditedPurchases = ["a", "b"]
        var remote = fxSave(lifetime: 10, lastSeen: 1)
        remote.meta.creditedPurchases = ["b", "c"]

        #expect(SaveConflictResolver.resolve(local: local, remote: remote).meta.creditedPurchases == ["a", "b", "c"])
        #expect(SaveConflictResolver.resolve(local: remote, remote: local).meta.creditedPurchases == ["a", "b", "c"])
    }

    @Test("revealedTier, priceRelief, la pared de la última run y el pin viajan con el ganador")
    func v6WinnerOnlyFieldsTravelWithTheWinner() {
        var winner = fxSave(lifetime: 1000, lastSeen: 2)
        winner.run.revealedTier = 2
        winner.run.priceRelief = 0.5
        winner.meta.lastRunMaxTier = 3
        winner.meta.quickHirePinnedTypeId = "a"
        var loser = fxSave(lifetime: 10, lastSeen: 1)
        loser.run.revealedTier = 9
        loser.run.priceRelief = 1
        loser.meta.lastRunMaxTier = 8
        loser.meta.quickHirePinnedTypeId = "b"

        for resolved in [
            SaveConflictResolver.resolve(local: winner, remote: loser),
            SaveConflictResolver.resolve(local: loser, remote: winner),
        ] {
            #expect(resolved.run.revealedTier == 2)
            #expect(resolved.run.priceRelief == 0.5)
            #expect(resolved.meta.lastRunMaxTier == 3)
            #expect(resolved.meta.quickHirePinnedTypeId == "a")
            #expect(resolved.meta.engagement == .initial)
        }
    }

    @Test("el contenedor de engagement se resuelve por su propia regla")
    func engagementResolvesThroughItsOwnRule() {
        #expect(EngagementState.resolve(winner: .initial, loser: .initial) == .initial)
        #expect(EngagementState.initial == EngagementState())
    }

    @Test("clampedScore jamás trapea: no-finito y gigantes a .max, negativos a 0")
    func scoreClampNeverTraps() {
        #expect(SaveConflictResolver.clampedScore(0) == 0)
        #expect(SaveConflictResolver.clampedScore(-5) == 0)
        #expect(SaveConflictResolver.clampedScore(1234.9) == 1234)
        // 9.2e18 es el borde: ya no entra en Int64, va derecho a .max.
        #expect(SaveConflictResolver.clampedScore(9.2e18) == .max)
        #expect(SaveConflictResolver.clampedScore(1e19) == .max)
        #expect(SaveConflictResolver.clampedScore(.infinity) == .max)
        #expect(SaveConflictResolver.clampedScore(.nan) == .max)
    }
}
