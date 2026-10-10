import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La tabla de la tienda de ORO que aprobó el dueño (PLAN-v2 §4 E6; la escala
/// es 1 h de producción ≈ 90 ORO). Los números finales los mueve el simulador
/// en E2b: si cambia uno, se cambia acá y en `oro_shop.json` en el mismo commit.
@Suite("oro_shop.json: la tabla aprobada")
@MainActor
struct OroShopContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    static let approvedPrices: [String: [Int]] = [
        "income_x2": [30], "income_x3": [60], "package_rain": [15], "auto_tap": [25],
        "time_jump_1h": [90], "time_jump_4h": [320], "offline_x3": [120], "daily_x3": [40],
        "skip_cooldowns": [25], "merge_all": [20],
        "better_supplier": [150, 400, 1000], "wheel_spins": [120, 300, 750],
        "skin_chest": [45],
    ]

    static let approvedDailyLimits: [String: Int] = [
        "income_x2": 3, "income_x3": 2, "package_rain": 5, "auto_tap": 3,
        "time_jump_1h": 2, "time_jump_4h": 1, "daily_x3": 1, "merge_all": 5,
    ]

    private func item(_ id: String) throws -> OroShopCatalog.Item {
        try #require(content.oroShop.item(id: id), "falta \(id)")
    }

    @Test("los precios y los topes son los aprobados")
    func pricesAndCaps() throws {
        #expect(Set(content.oroShop.items.map(\.id)) == Set(Self.approvedPrices.keys))
        for item in content.oroShop.items {
            let prices = item.isPermanent ? item.levels.map(\.price) : [item.price ?? 0]
            #expect(prices == Self.approvedPrices[item.id], "\(item.id)")
            #expect(item.dailyLimit == Self.approvedDailyLimits[item.id], "\(item.id)")
        }
        #expect(try item("time_jump_1h").priceGrowthPerPurchase == 1.25)
    }

    @Test("lo que dice cada fila es lo que da")
    func rewardsAreTheTable() throws {
        #expect(try item("income_x2").rewards == [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 1800)])
        #expect(try item("income_x3").rewards == [.modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 1800)])
        #expect(try item("package_rain").rewards == [.modifier(effect: .packageRateMultiplier, magnitude: 10, seconds: 60)])
        #expect(try item("auto_tap").rewards == [.autoTap(perSecond: 5, seconds: 600)])
        #expect(try item("time_jump_1h").rewards == [.coinsSeconds(3600)])
        #expect(try item("time_jump_4h").rewards == [.coinsSeconds(14_400)])
        #expect(try item("offline_x3").rewards == [.nextOfflineMultiplier(3)])
        #expect(try item("daily_x3").rewards == [.nextDailyMultiplier(3)])
        #expect(try item("skip_cooldowns").rewards == [.clearBoostCooldowns])
        #expect(try item("skin_chest").rewards == [.skinChest(1)])
        #expect(try item("merge_all").action == .mergeAll)
        #expect(try item("better_supplier").perk == .bestSupplier)
        #expect(try item("better_supplier").levels.map(\.value) == [1, 2, 3])
        #expect(try item("wheel_spins").perk == .wheelDailySpins)
        #expect(try item("wheel_spins").levels.map(\.value) == [1, 2, 3])
    }

    @Test("cada nivel de 'mejor proveedor' tiene su r en packages.json, el 1,8 / 1,6 / 1,4 aprobado")
    func supplierLevelsExistInE5() throws {
        let levels = try item("better_supplier").levels.map { Int($0.value) }
        #expect(content.packages.tierRatioByBestSupplierLevel.count == levels.count + 1, "el nivel 0 más los que se venden")
        #expect(levels.map { content.packages.tierRatio(bestSupplierLevel: $0) } == [1.8, 1.6, 1.4])
    }

    @Test("el azar con ORO que vende la tienda es exactamente el cofre (Apple 3.1.1); el giro extra es de la ruleta")
    func chanceItems() {
        #expect(Set(content.oroShop.items.filter(\.isChance).map(\.id)) == ["skin_chest"])
        #expect(!content.oroShop.items.contains { $0.rewards.contains(.wheelSpin(1)) })
    }

    @Test("cada ítem y cada estante tienen nombre en los dos idiomas; lo propio, también descripción",
          arguments: ["es", "en"])
    func copyInBothLanguages(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        for item in content.oroShop.items {
            #expect(OroShopCopy.name(for: item, bundle: bundle) != OroShopCopy.nameKey(item.id), "\(item.id): sin nombre en \(language)")
            guard OroShopCopy.hasOwnDescription(item) else { continue }
            let detail = OroShopCopy.detail(for: item, level: 0, bundle: bundle)
            #expect(detail != OroShopCopy.descriptionKey(item.id), "\(item.id): sin descripción en \(language)")
            #expect(!detail.contains("%"), "\(item.id): quedó un placeholder sin llenar en \(language)")
        }
        for shelf in OroShopCatalog.Shelf.allCases {
            let key = OroShopCopy.shelfKey(shelf)
            #expect(bundle.localizedString(forKey: key, value: "(falta)", table: nil) != "(falta)", "\(key) en \(language)")
        }
    }

    @Test("lo que da un consumible se dice como cualquier premio (RewardCopy)")
    func consumablesSayTheirReward() throws {
        for item in content.oroShop.items where !item.rewards.isEmpty {
            #expect(OroShopCopy.detail(for: item, level: 0) == item.rewards.map(RewardCopy.title).joined(separator: " + "))
        }
    }

    @Test("un nivel de 'mejor proveedor' que packages.json no conoce se rechaza al arrancar")
    func unknownSupplierLevelIsRejected() throws {
        let json = """
        {"schemaVersion": 1, "items": [
          {"id": "better_supplier", "shelf": "permanents", "iconKey": "x", "symbol": "x",
           "perk": "bestSupplier", "levels": [{"price": 150, "value": 9}]}]}
        """
        let shop = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        let floorIDs = Set(content.floorTable.floors.map(\.id))
        #expect(throws: GameContentLoader.OroShopContentError.supplierLevelUnknown("better_supplier")) {
            try GameContentLoader.validate(oroShop: shop, floorIDs: floorIDs, packages: content.packages)
        }
    }
}
