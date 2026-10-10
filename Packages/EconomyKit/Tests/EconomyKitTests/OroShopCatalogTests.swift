import Foundation
import Testing
@testable import EconomyKit

@Suite("oro_shop.json: el catálogo y su validador")
struct OroShopCatalogTests {
    static let json = """
    {
      "schemaVersion": 1,
      "items": [
        {"id": "income_x2", "shelf": "boosts", "iconKey": "ui_shop_x2", "symbol": "chart.line.uptrend.xyaxis",
         "price": 30, "dailyLimit": 3,
         "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 1800}]},
        {"id": "time_jump_1h", "shelf": "shortcuts", "iconKey": "ui_shop_jump1", "symbol": "forward.fill",
         "price": 90, "dailyLimit": 2, "priceGrowthPerPurchase": 1.25,
         "rewards": [{"kind": "coinsSeconds", "seconds": 3600}]},
        {"id": "merge_all", "shelf": "shortcuts", "iconKey": "ui_shop_mergeall", "symbol": "arrow.triangle.merge",
         "price": 20, "dailyLimit": 5, "action": "mergeAll"},
        {"id": "better_supplier", "shelf": "permanents", "iconKey": "ui_shop_supplier", "symbol": "shippingbox.fill",
         "perk": "bestSupplier",
         "levels": [{"price": 150, "value": 1}, {"price": 400, "value": 2}, {"price": 1000, "value": 3}]},
        {"id": "skin_chest", "shelf": "luck", "iconKey": "ui_shop_chest", "symbol": "gift.fill",
         "price": 45, "isChance": true, "rewards": [{"kind": "skinChest", "count": 1}]}
      ]
    }
    """

    static func catalog() throws -> OroShopCatalog {
        try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
    }

    @Test("se lee la forma del JSON, con sus defaults")
    func decodes() throws {
        let catalog = try Self.catalog()
        #expect(catalog.items.map(\.id) == ["income_x2", "time_jump_1h", "merge_all", "better_supplier", "skin_chest"])
        let x2 = try #require(catalog.item(id: "income_x2"))
        #expect(x2.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 1800)])
        #expect(x2.levels.isEmpty)
        #expect(!x2.isChance)
        #expect(!x2.isPermanent)
        let supplier = try #require(catalog.item(id: "better_supplier"))
        #expect(supplier.isPermanent)
        #expect(supplier.levels.map(\.price) == [150, 400, 1000])
        #expect(throws: Never.self) { try catalog.validate(floorIDs: ["alley"]) }
    }

    private func rejects(_ item: String, with error: OroShopCatalog.ValidationError) throws {
        let json = #"{"schemaVersion": 1, "items": [\#(item)]}"#
        let catalog = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        #expect(throws: error) { try catalog.validate(floorIDs: ["alley"]) }
    }

    @Test("un ítem que no da nada no entra")
    func emptyItem() throws {
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 10}"#, with: .emptyItem("x"))
    }

    @Test("un consumible que además es permanente no entra")
    func mixedKinds() throws {
        try rejects(
            #"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 10, "perk": "bestSupplier", "levels": [{"price": 1, "value": 1}], "rewards": [{"kind": "oro", "amount": 1}]}"#,
            with: .mixedKinds("x")
        )
    }

    @Test("precios, topes y crecimiento tienen que tener sentido")
    func numbers() throws {
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 0, "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .nonPositivePrice("x"))
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "dailyLimit": 0, "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .invalidLimit("x"))
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "priceGrowthPerPurchase": 0.9, "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .invalidGrowth("x"))
        try rejects(#"{"id": "x", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "bestSupplier", "levels": [{"price": 400, "value": 1}, {"price": 150, "value": 2}]}"#,
                    with: .descendingPrices("x"))
    }

    @Test("un premio inválido o un piso desconocido no entran")
    func references() throws {
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "rewards": [{"kind": "coinsSeconds", "seconds": 0}]}"#,
                    with: .badReward("x"))
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "unlockFloorId": "luna", "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .unknownFloor("luna"))
    }

    @Test("ids repetidos no entran")
    func duplicates() throws {
        let item = #"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "rewards": [{"kind": "oro", "amount": 1}]}"#
        let catalog = try JSONDecoder().decode(OroShopCatalog.self, from: Data(#"{"schemaVersion": 1, "items": [\#(item), \#(item)]}"#.utf8))
        #expect(throws: OroShopCatalog.ValidationError.duplicateID("x")) { try catalog.validate(floorIDs: []) }
    }
}
