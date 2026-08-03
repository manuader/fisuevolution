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
