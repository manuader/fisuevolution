import Foundation
import Testing
@testable import EconomyKit

@Suite("Comprar una pinta con ORO")
struct OroSkinPurchaseTests {
    @Test("cobra por spendOro y la deja entre las tuyas")
    func buys() throws {
        var state = fxState()
        state.meta.oro = 500
        try OroShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(state.meta.oro == 350)
        #expect(state.meta.stats.oroSpentEver == 150)
        #expect(state.meta.engagement.shop.skins == ["neon"])
        #expect(state.meta.allOwnedSkins.contains("neon"))
    }

    @Test("con el ORO justo alcanza y deja el saldo en cero")
    func exactBalance() throws {
        var state = fxState()
        state.meta.oro = 150
        try OroShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(state.meta.oro == 0)
        #expect(state.meta.engagement.shop.skins == ["neon"])
    }

    @Test("con un ORO menos no cobra ni entrega")
    func oneShort() {
        var state = fxState()
        state.meta.oro = 149
        #expect(throws: OroShop.SkinPurchaseError.cantAfford) { try OroShop.purchaseSkin("neon", price: 150, state: &state) }
        #expect(state.meta.oro == 149)
        #expect(state.meta.stats.oroSpentEver == 0)
        #expect(state.meta.engagement.shop.skins.isEmpty)
    }

    @Test("un precio de cero o negativo no regala ni cobra")
    func invalidPriceIsRefused() {
        for price in [0, -50] {
            var state = fxState()
            state.meta.oro = 500
            #expect(throws: OroShop.SkinPurchaseError.invalidPrice) { try OroShop.purchaseSkin("neon", price: price, state: &state) }
            #expect(state.meta.oro == 500)
            #expect(state.meta.engagement.shop.skins.isEmpty)
        }
    }

    @Test("lo que ya es tuyo no se cobra, venga de la vía que venga")
    func alreadyOwnedIsFree() {
        var viaMilestone = fxState()
        viaMilestone.meta.milestoneSkins = ["neon"]
        var viaStore = fxState()
        viaStore.meta.ownedSkins = ["neon"]
        for var state in [viaMilestone, viaStore] {
            state.meta.oro = 500
            #expect(throws: OroShop.SkinPurchaseError.alreadyOwned) { try OroShop.purchaseSkin("neon", price: 150, state: &state) }
            #expect(state.meta.oro == 500)
        }
    }

    @Test("un doble toque cobra una sola vez: la segunda llamada ve la primera")
    func secondCallDoesNotCharge() throws {
        var state = fxState()
        state.meta.oro = 500
        try OroShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(throws: OroShop.SkinPurchaseError.alreadyOwned) { try OroShop.purchaseSkin("neon", price: 150, state: &state) }
        #expect(state.meta.oro == 350)
        #expect(state.meta.stats.oroSpentEver == 150)
    }

    @Test("lo tuyo es la unión de las tres vías")
    func ownedIsTheUnion() {
        var state = fxState()
        state.meta.ownedSkins = ["mundialista"]
        state.meta.milestoneSkins = ["second_life"]
        state.meta.engagement.shop.skins = ["pijama"]
        #expect(state.meta.allOwnedSkins == ["mundialista", "second_life", "pijama"])
    }
}
