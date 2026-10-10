import Foundation
import Testing
@testable import EconomyKit

@Suite("El plan del reset")
struct ResetPlanTests {
    private func current(balance: Int, purchased: [String: Int], revoked: Set<String> = []) -> PlayerState {
        var state = fxState(units: ["a": 4, "b": 2])
        state.meta.oro = balance
        for (id, amount) in purchased { state.meta.recordOroPurchase(transactionID: id, amount: amount) }
        for id in revoked { state.meta.revokePurchase(transactionID: id) }
        state.meta.creditedPurchases = Set(purchased.keys)
        state.meta.prestigeLevel = 3
        state.meta.removedAds = true
        state.meta.ownedSkins = ["iap_skin"]
        state.meta.milestoneSkins = ["m1", "m2"]
        state.meta.unlockedAchievements = ["a1", "a2", "a3"]
        state.meta.welcomeChestGiven = true
        state.meta.floorChestsAwarded = 7
        state.meta.resetEpoch = 4
        return state
    }

    @Test("la matriz del ORO: se conserva min(saldo, comprado)",
          arguments: [
            (1250, ["p": 500], 500, 750),
            (300, ["p": 500], 300, 0),
            (0, ["p": 500], 0, 0),
            (800, [String: Int](), 0, 800),
            (2000, ["p": 160, "q": 550], 710, 1290),
          ])
    func oroMatrix(balance: Int, purchased: [String: Int], kept: Int, earned: Int) {
        let plan = ResetPlan.make(current: current(balance: balance, purchased: purchased), fresh: fxState())
        #expect(plan.summary.oroBalance == balance)
        #expect(plan.summary.oroKept == kept)
        #expect(plan.summary.oroEarned == earned)
        #expect(plan.result.meta.oro == kept, "lo que se muestra es lo que se ejecuta")
    }

    @Test("una compra reembolsada no se conserva")
    func refundedDoesNotCount() {
        let plan = ResetPlan.make(
            current: current(balance: 1000, purchased: ["p": 500, "r": 300], revoked: ["r"]),
            fresh: fxState()
        )
        #expect(plan.summary.oroPurchased == 500)
        #expect(plan.result.meta.oro == 500)
        #expect(plan.result.meta.revokedPurchases == ["r"])
    }

    @Test("se conserva lo comprado; lo demás es partida nueva")
    func keptAndLost() {
        let plan = ResetPlan.make(current: current(balance: 0, purchased: ["p": 500]), fresh: fxState())
        let meta = plan.result.meta
        #expect(meta.removedAds)
        #expect(meta.ownedSkins == ["iap_skin"])
        #expect(meta.creditedPurchases == ["p"], "sin esto, una transacción re-entregada se acreditaría dos veces")
        #expect(meta.oroPurchasedLifetime == 500)
        #expect(meta.prestigeLevel == 0)
        #expect(meta.milestoneSkins.isEmpty)
        #expect(meta.unlockedAchievements.isEmpty)
        #expect(!meta.welcomeChestGiven, "vuelve el cofre de bienvenida")
        #expect(meta.resetEpoch == 5)
        #expect(plan.result.run == fxState().run)
        #expect(plan.summary.prestigeLevel == 3)
        #expect(plan.summary.unitsOnBoard == 6)
        #expect(plan.summary.achievements == 3)
        #expect(plan.summary.skinsLost == 2)
        #expect(plan.summary.keptSkins == 1)
        #expect(plan.summary.keepsRemoveAds)
    }

    @Test("el contador de cofres de piso queda coherente con la partida nueva")
    func floorChestsCoherent() {
        let plan = ResetPlan.make(current: current(balance: 0, purchased: [:]), fresh: fxState())
        #expect(plan.result.meta.floorChestsAwarded == 0)
        #expect(plan.result.meta.floorChestsAwarded == fxState().meta.floorChestsAwarded)
    }

    @Test("las pintas de la tienda de ORO se pierden y cuentan como perdidas")
    func shopSkinsLost() {
        var state = current(balance: 0, purchased: [:])
        state.meta.engagement.shop.skins = ["oro_skin"]
        let plan = ResetPlan.make(current: state, fresh: fxState())
        #expect(plan.summary.skinsLost == 3)
        #expect(plan.result.meta.engagement.shop.skins.isEmpty)
    }

    @Test("las ofertas de una vez no vuelven, lo pagado queda y las abiertas se cierran")
    func offersSurvive() {
        var state = current(balance: 0, purchased: [:])
        state.meta.engagement.offers.everOpened = ["bienvenida"]
        state.meta.engagement.offers.purchases = ["renacer": 1]
        state.meta.engagement.offers.lastClosedAt = ["renacer": 50]
        state.meta.engagement.offers.active = [ActiveOffer(id: "x", openedAt: 1, expiresAt: 2, presented: true)]
        state.meta.engagement.offers.seenPrestigeLevel = 3
        state.meta.engagement.firstLaunchDay = "2026-10-01"
        let plan = ResetPlan.make(current: state, fresh: fxState())
        let offers = plan.result.meta.engagement.offers
        #expect(offers.everOpened == ["bienvenida"])
        #expect(offers.purchases == ["renacer": 1])
        #expect(offers.lastClosedAt == ["renacer": 50])
        #expect(plan.result.meta.engagement.firstLaunchDay == "2026-10-01")
        #expect(offers.active.isEmpty)
        #expect(offers.seenPrestigeLevel == nil)
    }

    @Test("las cinemáticas vistas son de la cuenta y sobreviven")
    func cinematicsSurvive() {
        var state = current(balance: 0, purchased: [:])
        state.meta.engagement.seenCinematics = ["dios": 2]
        let plan = ResetPlan.make(current: state, fresh: fxState())
        #expect(plan.result.meta.engagement.seenCinematics == ["dios": 2])
    }

    @Test("la pinta comprada con plata sigue puesta; la de un cofre, no")
    func equippedSkins() {
        var state = current(balance: 0, purchased: [:])
        state.meta.activeSkinByType = ["homeless": "iap_skin", "chef": "m1"]
        let plan = ResetPlan.make(current: state, fresh: fxState())
        #expect(plan.result.meta.activeSkinByType == ["homeless": "iap_skin"])
    }

    @Test("el resultado gana el resolver contra el save viejo y no acredita dos veces")
    func resultWinsAndNeverDoubleCredits() {
        let old = current(balance: 1250, purchased: ["p": 500])
        let plan = ResetPlan.make(current: old, fresh: fxState())
        for resolved in [
            SaveConflictResolver.resolve(local: plan.result, remote: old),
            SaveConflictResolver.resolve(local: old, remote: plan.result)
        ] {
            #expect(resolved.meta.resetEpoch == 5)
            #expect(resolved.meta.oro == 500, "la transacción ya anotada no suma otra vez")
            #expect(resolved.meta.prestigeLevel == 0)
        }
    }
}
