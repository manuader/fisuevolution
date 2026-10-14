import Foundation
import Testing
@testable import EconomyKit

@Suite("Comprar una pinta con blue")
struct BlueSkinPurchaseTests {
    @Test("cobra por spendBlue y la deja entre las tuyas")
    func buys() throws {
        var state = fxState()
        state.meta.blue = 500
        try BlueShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(state.meta.blue == 350)
        #expect(state.meta.stats.blueSpentEver == 150)
        #expect(state.meta.engagement.shop.skins == ["neon"])
        #expect(state.meta.allOwnedSkins.contains("neon"))
    }

    @Test("con el blue justo alcanza y deja el saldo en cero")
    func exactBalance() throws {
        var state = fxState()
        state.meta.blue = 150
        try BlueShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(state.meta.blue == 0)
        #expect(state.meta.engagement.shop.skins == ["neon"])
    }

    @Test("con un blue menos no cobra ni entrega")
    func oneShort() {
        var state = fxState()
        state.meta.blue = 149
        #expect(throws: BlueShop.SkinPurchaseError.cantAfford) { try BlueShop.purchaseSkin("neon", price: 150, state: &state) }
        #expect(state.meta.blue == 149)
        #expect(state.meta.stats.blueSpentEver == 0)
        #expect(state.meta.engagement.shop.skins.isEmpty)
    }

    @Test("un precio de cero o negativo no regala ni cobra")
    func invalidPriceIsRefused() {
        for price in [0, -50] {
            var state = fxState()
            state.meta.blue = 500
            #expect(throws: BlueShop.SkinPurchaseError.invalidPrice) { try BlueShop.purchaseSkin("neon", price: price, state: &state) }
            #expect(state.meta.blue == 500)
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
            state.meta.blue = 500
            #expect(throws: BlueShop.SkinPurchaseError.alreadyOwned) { try BlueShop.purchaseSkin("neon", price: 150, state: &state) }
            #expect(state.meta.blue == 500)
        }
    }

    @Test("un doble toque cobra una sola vez: la segunda llamada ve la primera")
    func secondCallDoesNotCharge() throws {
        var state = fxState()
        state.meta.blue = 500
        try BlueShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(throws: BlueShop.SkinPurchaseError.alreadyOwned) { try BlueShop.purchaseSkin("neon", price: 150, state: &state) }
        #expect(state.meta.blue == 350)
        #expect(state.meta.stats.blueSpentEver == 150)
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
