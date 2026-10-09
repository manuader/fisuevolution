import Foundation
import Testing
@testable import EconomyKit

@Suite("La época de reset en el resolver")
struct ResetEpochTests {
    private func state(epoch: Int, earnings: Double, oro: Int, purchases: [String: Int] = [:]) -> PlayerState {
        var state = fxState()
        state.meta.resetEpoch = epoch
        state.meta.lifetimeEarnings = earnings
        state.meta.oro = oro
        for (id, amount) in purchases { state.meta.recordOroPurchase(transactionID: id, amount: amount) }
        state.meta.creditedPurchases = Set(purchases.keys)
        return state
    }

    @Test("gana la época más nueva aunque tenga menos progreso, de los dos lados")
    func newerEpochWinsBothDirections() {
        let fresh = state(epoch: 1, earnings: 10, oro: 0)
        let old = state(epoch: 0, earnings: 1e12, oro: 500)
        for resolved in [
            SaveConflictResolver.resolve(local: fresh, remote: old),
            SaveConflictResolver.resolve(local: old, remote: fresh)
        ] {
            #expect(resolved.meta.resetEpoch == 1)
            #expect(resolved.meta.lifetimeEarnings == 10)
            #expect(resolved.meta.oro == 0)
        }
    }

    @Test("el contador de cofres de piso no cruza el reset: manda el de la época nueva, aunque sea cero")
    func floorChestsDoNotCrossTheReset() {
        let fresh = state(epoch: 1, earnings: 10, oro: 0)
        var old = state(epoch: 0, earnings: 1e12, oro: 0)
        old.meta.floorChestsAwarded = 6
        for resolved in [
            SaveConflictResolver.resolve(local: fresh, remote: old),
            SaveConflictResolver.resolve(local: old, remote: fresh)
        ] {
            #expect(resolved.meta.floorChestsAwarded == 0)
        }
    }

    @Test("entre tres épocas manda la mayor, sin importar el orden")
    func highestEpochOfThree() {
        let a = state(epoch: 0, earnings: 9e9, oro: 0)
        let b = state(epoch: 1, earnings: 5e5, oro: 0)
        let c = state(epoch: 2, earnings: 1, oro: 0)
        let left = SaveConflictResolver.resolve(local: SaveConflictResolver.resolve(local: a, remote: b), remote: c)
        let right = SaveConflictResolver.resolve(local: a, remote: SaveConflictResolver.resolve(local: c, remote: b))
        #expect(left.meta.resetEpoch == 2 && right.meta.resetEpoch == 2)
        #expect(left.meta.lifetimeEarnings == 1 && right.meta.lifetimeEarnings == 1)
    }

    @Test("las compras cruzan: el ORO que el lado nuevo no vio se suma una vez")
    func purchasesCross() {
        let fresh = state(epoch: 1, earnings: 10, oro: 160, purchases: ["a": 160])
        var oldWithAds = state(epoch: 0, earnings: 1e9, oro: 3, purchases: ["a": 160, "b": 550])
        oldWithAds.meta.removedAds = true
        oldWithAds.meta.ownedSkins = ["skin1"]
        let resolved = SaveConflictResolver.resolve(local: fresh, remote: oldWithAds)
        #expect(resolved.meta.oro == 160 + 550, "el pack «b» no lo había visto el lado nuevo")
        #expect(resolved.meta.creditedPurchases == ["a", "b"])
        #expect(resolved.meta.oroPurchasedLifetime == 710)
        #expect(resolved.meta.removedAds)
        #expect(resolved.meta.ownedSkins == ["skin1"])
        let again = SaveConflictResolver.resolve(local: resolved, remote: oldWithAds)
        #expect(again.meta.oro == resolved.meta.oro, "idempotente")
        let reversed = SaveConflictResolver.resolve(local: oldWithAds, remote: fresh)
        #expect(reversed.meta.oro == resolved.meta.oro, "el orden de los lados no cambia el resultado")
    }

    @Test("una compra reembolsada, de cualquier lado, no acredita ORO")
    func revokedPurchaseDoesNotCredit() {
        let fresh = state(epoch: 1, earnings: 10, oro: 0)
        var old = state(epoch: 0, earnings: 1e9, oro: 0, purchases: ["b": 550])
        old.meta.revokePurchase(transactionID: "b")
        #expect(SaveConflictResolver.resolve(local: fresh, remote: old).meta.oro == 0)

        var freshRevoking = state(epoch: 1, earnings: 10, oro: 0)
        freshRevoking.meta.revokePurchase(transactionID: "c")
        let oldSeesC = state(epoch: 0, earnings: 1e9, oro: 0, purchases: ["c": 100])
        let resolved = SaveConflictResolver.resolve(local: freshRevoking, remote: oldSeesC)
        #expect(resolved.meta.oro == 0, "el reembolso pudo llegar antes que la compra")
        #expect(resolved.meta.oroPurchasedLifetime == 0)
    }

    @Test("lo ganado del lado viejo NO cruza el reset: ni logros, ni pintas, ni cofres, ni ORO ganado")
    func progressDoesNotCross() {
        var old = state(epoch: 0, earnings: 1e12, oro: 900)
        old.meta.oroEarnedLifetime = 5000
        old.meta.unlockedAchievements = ["a1"]
        old.meta.claimedAchievements = ["a1"]
        old.meta.milestoneSkins = ["s1"]
        old.meta.chestsPending = 3
        old.meta.prestigeChestsPending = 2
        old.meta.stats.totalMergesEver = 99
        old.meta.unlockedTabs = ["store"]
        let fresh = state(epoch: 1, earnings: 10, oro: 0)
        let resolved = SaveConflictResolver.resolve(local: fresh, remote: old)
        #expect(resolved.meta.unlockedAchievements.isEmpty)
        #expect(resolved.meta.claimedAchievements.isEmpty)
        #expect(resolved.meta.milestoneSkins.isEmpty)
        #expect(resolved.meta.chestsPending == 0)
        #expect(resolved.meta.prestigeChestsPending == 0)
        #expect(resolved.meta.oro == 0)
        #expect(resolved.meta.oroEarnedLifetime == 0)
        #expect(resolved.meta.stats.totalMergesEver == 0)
        #expect(resolved.meta.unlockedTabs.isEmpty)
    }

    @Test("la reconstrucción de ORO comprado sólo cuenta como hecha si los dos lados la hicieron")
    func reconstructionFlagIsAnd() {
        var fresh = state(epoch: 1, earnings: 10, oro: 0)
        fresh.meta.purchasedOroReconstructed = true
        var old = state(epoch: 0, earnings: 1e9, oro: 0)
        old.meta.purchasedOroReconstructed = false
        #expect(SaveConflictResolver.resolve(local: fresh, remote: old).meta.purchasedOroReconstructed == false)
    }

    @Test("con la misma época, la regla de siempre")
    func sameEpoch() {
        let a = state(epoch: 2, earnings: 100, oro: 5)
        let b = state(epoch: 2, earnings: 200, oro: 7)
        #expect(SaveConflictResolver.resolve(local: a, remote: b).meta.lifetimeEarnings == 200)
        #expect(SaveConflictResolver.resolve(local: b, remote: a).meta.lifetimeEarnings == 200)
    }

    @Test("un save sin la clave decodifica en época 0")
    func decodesWithoutTheKey() throws {
        let data = try JSONEncoder().encode(fxState())
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var meta = try #require(json["meta"] as? [String: Any])
        #expect(meta["resetEpoch"] != nil, "el encoder la escribe")
        meta.removeValue(forKey: "resetEpoch")
        json["meta"] = meta
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.meta.resetEpoch == 0)
    }

    @Test("la época viaja en el save: encode y decode la conservan")
    func roundTrips() throws {
        var original = fxState()
        original.meta.resetEpoch = 3
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(original))
        #expect(decoded.meta.resetEpoch == 3)
    }

    @Test("un save nuevo arranca en época 0")
    func newGameStartsAtZero() {
        #expect(fxState().meta.resetEpoch == 0)
    }

    @Test("tres devices: el saldo es el mismo en cualquier orden de cruce")
    func threeDevicesAreAssociative() {
        let a = state(epoch: 1, earnings: 10, oro: 0)
        let b = state(epoch: 0, earnings: 1e6, oro: 0, purchases: ["b": 550])
        let c = state(epoch: 1, earnings: 500, oro: 0)
        let ab = SaveConflictResolver.resolve(local: a, remote: b)
        let abThenC = SaveConflictResolver.resolve(local: c, remote: ab)
        let cThenA = SaveConflictResolver.resolve(local: a, remote: c)
        let acThenB = SaveConflictResolver.resolve(local: cThenA, remote: b)
        let bc = SaveConflictResolver.resolve(local: b, remote: c)
        let bcThenA = SaveConflictResolver.resolve(local: a, remote: bc)
        for resolved in [abThenC, acThenB, bcThenA] {
            #expect(resolved.meta.oro == 550, "el pack «b» se acredita una vez, en cualquier orden")
            #expect(resolved.meta.oroPurchases["b"] == 550)
        }
        #expect(SaveConflictResolver.resolve(local: abThenC, remote: b).meta.oro == 550)
    }

    @Test("misma época: el ORO comprado del perdedor se acredita una sola vez")
    func sameEpochCreditsLoserPurchaseOnce() {
        let winner = state(epoch: 1, earnings: 900, oro: 10)
        let loser = state(epoch: 1, earnings: 5, oro: 0, purchases: ["p": 300])
        let resolved = SaveConflictResolver.resolve(local: winner, remote: loser)
        #expect(resolved.meta.oro == 310)
        #expect(SaveConflictResolver.resolve(local: resolved, remote: loser).meta.oro == 310)
        #expect(SaveConflictResolver.resolve(local: loser, remote: winner).meta.oro == 310)
    }

    @Test("un id ya acreditado por el camino viejo no se acredita de nuevo")
    func creditedIdIsNotDuplicated() {
        var fresh = state(epoch: 1, earnings: 10, oro: 160)
        fresh.meta.creditedPurchases = ["legacy"]
        let old = state(epoch: 0, earnings: 1e9, oro: 0, purchases: ["legacy": 160])
        #expect(SaveConflictResolver.resolve(local: fresh, remote: old).meta.oro == 160)

        let winner = state(epoch: 2, earnings: 900, oro: 160)
        var winnerCredited = winner
        winnerCredited.meta.creditedPurchases = ["legacy"]
        let loser = state(epoch: 2, earnings: 5, oro: 0, purchases: ["legacy": 160])
        #expect(SaveConflictResolver.resolve(local: winnerCredited, remote: loser).meta.oro == 160)
    }
}
