import Foundation
import Testing
@testable import EconomyKit

@Suite("La tienda de blue: qué se ve, cuánto cuesta, qué lo bloquea y qué se compra")
struct BlueShopTests {
    let catalog: BlueShopCatalog

    init() throws {
        catalog = try BlueShopCatalogTests.catalog()
    }

    private func context(
        today: String = "2026-10-07",
        grantable: Set<RewardSpec.Kind> = Set(RewardSpec.Kind.allCases),
        chanceAllowed: Bool = true,
        reached: Set<String> = ["alley"],
        mergeAllPairs: Int = 3,
        anyBoostCoolingDown: Bool = true,
        chestHasSomethingToGive: Bool = true,
        perks: Set<BlueShopCatalog.Perk> = Set(BlueShopCatalog.Perk.allCases)
    ) -> BlueShop.Context {
        BlueShop.Context(
            today: today, grantableKinds: grantable, chanceAllowed: chanceAllowed, reachedFloorIds: reached,
            mergeAllPairs: mergeAllPairs, anyBoostCoolingDown: anyBoostCoolingDown,
            chestHasSomethingToGive: chestHasSomethingToGive, supportedPerks: perks
        )
    }

    private func rich(_ blue: Int = 10_000) -> PlayerState {
        var state = fxState()
        state.meta.blue = blue
        return state
    }

    private func item(_ id: String) throws -> BlueShopCatalog.Item {
        try #require(catalog.item(id: id))
    }

    @Test("se ve lo que se puede entregar; el azar, sólo donde se permite")
    func visibility() throws {
        #expect(BlueShop.visibleItems(catalog: catalog, context: context()).map(\.id)
                == ["income_x2", "time_jump_1h", "merge_all", "better_supplier", "skin_chest"])
        let restricted = BlueShop.visibleItems(catalog: catalog, context: context(chanceAllowed: false)).map(\.id)
        #expect(!restricted.contains("skin_chest"), "Bélgica y Australia: el azar con blue se apaga")
        let noChests = BlueShop.visibleItems(catalog: catalog, context: context(grantable: [.coinsSeconds, .modifier])).map(\.id)
        #expect(!noChests.contains("skin_chest"), "lo que la app no sabe entregar no se vende")
        let noPerk = BlueShop.visibleItems(catalog: catalog, context: context(perks: [])).map(\.id)
        #expect(!noPerk.contains("better_supplier"), "un permanente sin quien lo lea no se vende")
    }

    @Test("el salto de 1 h sube ×1,25 por compra del día y vuelve al otro día")
    func priceGrowsWithinTheDay() throws {
        var state = rich()
        let jump = try item("time_jump_1h")
        #expect(BlueShop.quote(jump, state: state, context: context()).price == 90)
        _ = try BlueShop.purchase("time_jump_1h", state: &state, catalog: catalog, context: context())
        #expect(BlueShop.quote(jump, state: state, context: context()).price == 113, "90 × 1,25 = 112,5 → 113")
        _ = try BlueShop.purchase("time_jump_1h", state: &state, catalog: catalog, context: context())
        let capped = BlueShop.quote(jump, state: state, context: context())
        #expect(capped.blocker == .dailyLimitReached)
        #expect(capped.boughtToday == 2)
        let tomorrow = BlueShop.quote(jump, state: state, context: context(today: "2026-10-08"))
        #expect(tomorrow.price == 90)
        #expect(tomorrow.blocker == nil)
    }

    @Test("comprar gasta blue por spendBlue, nunca el blue de por vida")
    func purchaseSpends() throws {
        var state = rich(100)
        state.meta.blueEarnedLifetime = 500
        let purchase = try BlueShop.purchase("income_x2", state: &state, catalog: catalog, context: context())
        #expect(purchase.price == 30)
        #expect(purchase.item.id == "income_x2")
        #expect(state.meta.blue == 70)
        #expect(state.meta.stats.blueSpentEver == 30)
        #expect(state.meta.blueEarnedLifetime == 500, "gastar no nerfea el multiplicador")
        #expect(state.meta.engagement.shop.purchasesToday == ["income_x2": 1])
        #expect(state.meta.engagement.shop.day == "2026-10-07")
    }

    @Test("sin blue, no compra ni toca nada")
    func cantAfford() throws {
        var state = rich(10)
        let before = state
        #expect(BlueShop.quote(try item("income_x2"), state: state, context: context()).blocker == .cantAfford)
        #expect(throws: BlueShop.PurchaseError.blocked(.cantAfford)) {
            try BlueShop.purchase("income_x2", state: &state, catalog: catalog, context: context())
        }
        #expect(state == before)
    }

    @Test("los permanentes suben de a un nivel y paran en el máximo")
    func permanents() throws {
        var state = rich()
        let supplier = try item("better_supplier")
        #expect(BlueShop.bestSupplierLevel(levels: state.meta.engagement.shop.levels, catalog: catalog) == 0)
        for price in [150, 400, 1000] {
            #expect(BlueShop.quote(supplier, state: state, context: context()).price == price)
            let purchase = try BlueShop.purchase("better_supplier", state: &state, catalog: catalog, context: context())
            #expect(purchase.newLevel == [150, 400, 1000].firstIndex(of: price)! + 1)
        }
        let maxed = BlueShop.quote(supplier, state: state, context: context())
        #expect(maxed.price == nil)
        #expect(maxed.blocker == .maxed)
        #expect(maxed.level == 3)
        #expect(BlueShop.bestSupplierLevel(levels: state.meta.engagement.shop.levels, catalog: catalog) == 3)
        #expect(state.meta.engagement.shop.purchasesToday.isEmpty, "un permanente no gasta cupo del día")
    }

    @Test("lo que no tiene nada que hacer no cobra")
    func nothingToDo() throws {
        var state = rich()
        #expect(BlueShop.quote(try item("merge_all"), state: state, context: context(mergeAllPairs: 0)).blocker == .nothingToDo)
        #expect(BlueShop.quote(try item("skin_chest"), state: state, context: context(chestHasSomethingToGive: false)).blocker == .nothingToDo)
        #expect(throws: BlueShop.PurchaseError.blocked(.nothingToDo)) {
            try BlueShop.purchase("merge_all", state: &state, catalog: catalog, context: context(mergeAllPairs: 0))
        }
        #expect(state.meta.blue == 10_000)
    }

    @Test("un ítem que no se ve no se compra, aunque alguien lo pida por id")
    func hiddenCantBeBought() throws {
        var state = rich()
        #expect(throws: BlueShop.PurchaseError.notOffered) {
            try BlueShop.purchase("skin_chest", state: &state, catalog: catalog, context: context(chanceAllowed: false))
        }
        #expect(throws: BlueShop.PurchaseError.unknownItem) {
            try BlueShop.purchase("nope", state: &state, catalog: catalog, context: context())
        }
    }

    @Test("un ×3 pendiente bloquea comprar otro hasta que se use")
    func pendingMultipliers() throws {
        let json = #"""
        {"schemaVersion": 1, "items": [
          {"id": "offline_x3", "shelf": "shortcuts", "iconKey": "k", "symbol": "s", "price": 120,
           "rewards": [{"kind": "nextOfflineMultiplier", "multiplier": 3}]},
          {"id": "daily_x3", "shelf": "shortcuts", "iconKey": "k", "symbol": "s", "price": 40, "dailyLimit": 1,
           "rewards": [{"kind": "nextDailyMultiplier", "multiplier": 3}]}
        ]}
        """#
        let pending = try JSONDecoder().decode(BlueShopCatalog.self, from: Data(json.utf8))
        var state = rich()
        state.meta.engagement.shop.pendingOfflineMultiplier = 3
        #expect(BlueShop.quote(try #require(pending.item(id: "offline_x3")), state: state, context: context()).blocker == .alreadyPending)
        #expect(BlueShop.quote(try #require(pending.item(id: "daily_x3")), state: state, context: context()).blocker == nil)
        state.meta.engagement.shop.pendingDailyMultiplier = 3
        #expect(BlueShop.quote(try #require(pending.item(id: "daily_x3")), state: state, context: context()).blocker == .alreadyPending)
    }

    @Test("los perks salen de los niveles: los lugares se suman, el resto es el del nivel")
    func perks() throws {
        let json = #"""
        {"schemaVersion": 1, "items": [
          {"id": "extra_slots", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "extraSlots",
           "levels": [{"price": 600, "value": 3}, {"price": 1500, "value": 2}]},
          {"id": "wheel_spins", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "wheelDailySpins",
           "levels": [{"price": 120, "value": 1}, {"price": 300, "value": 2}, {"price": 750, "value": 3}]}
        ]}
        """#
        let perks = try JSONDecoder().decode(BlueShopCatalog.self, from: Data(json.utf8))
        #expect(BlueShop.extraSlots(levels: [:], catalog: perks) == 0)
        #expect(BlueShop.extraSlots(levels: ["extra_slots": 1], catalog: perks) == 3)
        #expect(BlueShop.extraSlots(levels: ["extra_slots": 2], catalog: perks) == 5)
        #expect(BlueShop.extraSlots(levels: ["extra_slots": 9], catalog: perks) == 5, "un nivel de más en el save no inventa lugares")
        #expect(BlueShop.bonusDailyWheelSpins(levels: ["wheel_spins": 2], catalog: perks) == 2)
        #expect(BlueShop.bonusDailyWheelSpins(levels: [:], catalog: perks) == 0)
    }

    @Test("un ítem de piso no se ve hasta llegar")
    func unlockFloor() throws {
        let json = #"{"schemaVersion": 1, "items": [{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "unlockFloorId": "urban", "rewards": [{"kind": "blue", "amount": 1}]}]}"#
        let gated = try JSONDecoder().decode(BlueShopCatalog.self, from: Data(json.utf8))
        #expect(BlueShop.visibleItems(catalog: gated, context: context(reached: ["alley"])).isEmpty)
        #expect(BlueShop.visibleItems(catalog: gated, context: context(reached: ["alley", "urban"])).map(\.id) == ["x"])
    }
}
