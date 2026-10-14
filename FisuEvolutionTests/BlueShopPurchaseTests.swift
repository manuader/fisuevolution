import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Comprar en la tienda de blue")
@MainActor
struct BlueShopPurchaseTests {
    private func rich(_ blue: Int = 5_000) async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = blue
        return gameState
    }

    @Test("un boost cobra blue, gasta cupo y arranca su modificador con el origen de la tienda")
    func boostStarts() async throws {
        let gameState = await rich(100)
        #expect(gameState.buyBlueShopItem(id: "income_x2", chanceAllowed: true) == .bought)
        let player = try #require(gameState.player)
        #expect(player.meta.blue == 70)
        #expect(player.meta.stats.blueSpentEver == 30)
        #expect(player.meta.engagement.shop.purchasesToday["income_x2"] == 1)
        let modifier = try #require(player.run.activeModifiers.first { $0.sourceKey == "shop.income_x2" })
        #expect(modifier.effect == .incomeMultiplier)
        #expect(modifier.magnitude == 2)
    }

    @Test("lo gastado en la tienda no toca el multiplicador global")
    func spendingDoesNotNerf() async throws {
        let gameState = await rich()
        let before = try #require(gameState.player?.meta)
        gameState.buyBlueShopItem(id: "income_x3", chanceAllowed: true)
        let after = try #require(gameState.player?.meta)
        #expect(after.blueEarnedLifetime == before.blueEarnedLifetime)
        #expect(after.globalMultiplier == before.globalMultiplier)
    }

    @Test("el salto de 1 h paga una hora de producción, y la segunda del día sale x1,25")
    func timeJumpPaysAnHour() async throws {
        let gameState = await rich()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let expected = GameState.coinReward(seconds: 3600, player: before, content: content, economy: economy)
        #expect(gameState.buyBlueShopItem(id: "time_jump_1h", chanceAllowed: true) == .bought)
        let after = try #require(gameState.player)
        #expect(abs(after.run.coins - before.run.coins - expected) < 1e-6 * max(1, expected))
        let second = try #require(gameState.blueShopRows(chanceAllowed: true).first { $0.id == "time_jump_1h" })
        #expect(second.quote.price == 113)
    }

    @Test("el tope del día frena y no cobra; en el borde exacto cobra la última")
    func dailyCap() async throws {
        let gameState = await rich()
        for _ in 0..<3 {
            #expect(gameState.buyBlueShopItem(id: "income_x2", chanceAllowed: true) == .bought)
        }
        let blue = try #require(gameState.player?.meta.blue)
        #expect(gameState.buyBlueShopItem(id: "income_x2", chanceAllowed: true) == .refused(.dailyLimitReached))
        #expect(gameState.player?.meta.blue == blue)
        #expect(gameState.player?.run.activeModifiers.filter { $0.sourceKey == "shop.income_x2" }.count == 3)
    }

    @Test("el crecimiento del precio por compra: 90, 113, y la tercera no se ofrece")
    func priceGrowthBoundary() async throws {
        let gameState = await rich(90 + 113)
        #expect(gameState.buyBlueShopItem(id: "time_jump_1h", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.blue == 113)
        #expect(gameState.buyBlueShopItem(id: "time_jump_1h", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.blue == 0, "con el blue justo se compra y queda en cero")
        #expect(gameState.buyBlueShopItem(id: "time_jump_1h", chanceAllowed: true) == .refused(.dailyLimitReached))
        #expect(gameState.player?.meta.blue == 0)
    }

    @Test("a un blue del precio no compra y no cobra")
    func oneShort() async throws {
        let gameState = await rich(89)
        #expect(gameState.buyBlueShopItem(id: "time_jump_1h", chanceAllowed: true) == .refused(.cantAfford))
        #expect(gameState.player?.meta.blue == 89)
        #expect(gameState.player?.meta.stats.blueSpentEver == 0)
    }

    @Test("un doble toque no cobra dos veces lo que tiene tope de uno")
    func doubleTap() async throws {
        let gameState = await rich()
        for id in ["time_jump_4h", "daily_x3"] {
            let before = try #require(gameState.player?.meta.blue)
            #expect(gameState.buyBlueShopItem(id: id, chanceAllowed: true) == .bought)
            #expect(gameState.buyBlueShopItem(id: id, chanceAllowed: true) == .refused(.dailyLimitReached))
            let price = try #require(gameState.content?.blueShop.item(id: id)?.price)
            #expect(gameState.player?.meta.blue == before - price)
        }
    }

    @Test("el cobro y la entrega salen en el mismo paso: un x3 comprado queda pendiente")
    func chargeAndDeliveryTogether() async throws {
        let gameState = await rich(200)
        #expect(gameState.buyBlueShopItem(id: "offline_x3", chanceAllowed: true) == .bought)
        let shop = try #require(gameState.player?.meta.engagement.shop)
        #expect(gameState.player?.meta.blue == 80)
        #expect(shop.pendingOfflineMultiplier == 3)
        #expect(shop.purchasesToday["offline_x3"] == 1)
    }

    @Test("Fusionar todo encola los pares del piso visible por el embudo, con su origen")
    func mergeAll() async throws {
        let gameState = await rich()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        #expect(gameState.buyBlueShopItem(id: "merge_all", chanceAllowed: true) == .bought)
        let queued = gameState.pendingBoardChanges + [gameState.inFlightBoardChange].compactMap { $0 }
        #expect(queued.count == 3)
        #expect(queued.allSatisfy { $0.origin == .blueShop })
        #expect(gameState.player?.meta.blue == 4_980)
    }

    @Test("sin pares, Fusionar todo no cobra")
    func mergeAllWithoutPairs() async throws {
        let gameState = await rich()
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        let blue = try #require(gameState.player?.meta.blue)
        #expect(gameState.buyBlueShopItem(id: "merge_all", chanceAllowed: true) == .refused(.nothingToDo))
        #expect(gameState.player?.meta.blue == blue)
    }

    @Test("el cofre por blue no se vende donde el azar está apagado; donde sí, espera en Regalos")
    func chest() async throws {
        let gameState = await rich()
        gameState.debugUnlockFloors(throughTier: 12)
        let chests = try #require(gameState.player?.meta.chestsPending)
        #expect(gameState.buyBlueShopItem(id: "skin_chest", chanceAllowed: false) == .unavailable)
        #expect(gameState.player?.meta.chestsPending == chests)
        #expect(gameState.player?.meta.blue == 5_000)
        #expect(!gameState.blueShopRows(chanceAllowed: false).contains { $0.id == "skin_chest" })
        #expect(gameState.buyBlueShopItem(id: "skin_chest", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.chestsPending == chests + 1)
    }

    @Test("Saltear cooldowns sólo se vende con un boost esperando")
    func skipCooldowns() async throws {
        let gameState = await rich()
        #expect(gameState.buyBlueShopItem(id: "skip_cooldowns", chanceAllowed: true) == .refused(.nothingToDo))
        let boost = try #require(gameState.content?.boosts.boosts.first)
        gameState.player?.meta.boostActivations[boost.id] = Date().timeIntervalSince1970
        #expect(gameState.buyBlueShopItem(id: "skip_cooldowns", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.boostActivations.isEmpty == true)
        #expect(gameState.buyBlueShopItem(id: "skip_cooldowns", chanceAllowed: true) == .refused(.nothingToDo))
    }

    @Test("Saltear cooldowns: tres por día, y el día nuevo vuelve a venderse")
    func skipCooldownsDailyCap() async throws {
        let gameState = await rich()
        let boost = try #require(gameState.content?.boosts.boosts.first)
        let coolDown = { (at: Date) in gameState.player?.meta.boostActivations[boost.id] = at.timeIntervalSince1970 }
        for _ in 0..<3 {
            coolDown(Date())
            #expect(gameState.buyBlueShopItem(id: "skip_cooldowns", chanceAllowed: true) == .bought)
        }
        coolDown(Date())
        #expect(gameState.buyBlueShopItem(id: "skip_cooldowns", chanceAllowed: true) == .refused(.dailyLimitReached))
        #expect(gameState.player?.meta.boostActivations.isEmpty == false, "lo que no se vende no limpia nada")
        let tomorrow = Date().addingTimeInterval(86_400 * 2)
        coolDown(tomorrow)
        #expect(gameState.buyBlueShopItem(id: "skip_cooldowns", chanceAllowed: true, now: tomorrow) == .bought)
    }

    @Test("mejor proveedor sube de a un nivel, para en el tercero, y el Paquete usa su r")
    func supplier() async throws {
        let gameState = await rich()
        let packages = try #require(gameState.content?.packages)
        #expect(gameState.bestSupplierLevel == 0)
        for level in 1...3 {
            #expect(gameState.buyBlueShopItem(id: "better_supplier", chanceAllowed: true) == .bought)
            #expect(gameState.bestSupplierLevel == level)
            #expect(packages.tierRatio(bestSupplierLevel: gameState.bestSupplierLevel)
                    == packages.tierRatio(bestSupplierLevel: level))
        }
        let blue = try #require(gameState.player?.meta.blue)
        #expect(gameState.buyBlueShopItem(id: "better_supplier", chanceAllowed: true) == .refused(.maxed))
        #expect(gameState.player?.meta.blue == blue)
    }

    @Test("el abono a la ruleta suma giros por video al día, también en lo que ofrece la ruleta")
    func wheelSpins() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.wheel.videoSpinsPerDay)
        #expect(gameState.bonusDailyWheelSpins == 0)
        #expect(gameState.wheelAvailability(storefrontAllows: false).videoLeft == base)
        gameState.buyBlueShopItem(id: "wheel_spins", chanceAllowed: true)
        #expect(gameState.bonusDailyWheelSpins == 1)
        #expect(gameState.wheelAvailability(storefrontAllows: false).videoLeft == base + 1)
        gameState.buyBlueShopItem(id: "wheel_spins", chanceAllowed: true)
        #expect(gameState.effectiveWheel?.videoSpinsPerDay == base + 2)
    }

    @Test("los giros de más se pueden gastar: spinWheel cobra contra el cupo agrandado")
    func bonusSpinsAreSpendable() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.wheel.videoSpinsPerDay)
        gameState.buyBlueShopItem(id: "wheel_spins", chanceAllowed: true)
        for _ in 0..<(base + 1) {
            #expect(gameState.spinWheel(.video) != nil)
        }
        #expect(gameState.spinWheel(.video) == nil)
    }

    @Test("un x3 se compra una vez hasta que se use, y el segundo no cobra")
    func pendingOnce() async throws {
        let gameState = await rich()
        for id in ["offline_x3", "daily_x3"] {
            #expect(gameState.buyBlueShopItem(id: id, chanceAllowed: true) == .bought)
            gameState.player?.meta.engagement.shop.purchasesToday = [:]
            let blue = try #require(gameState.player?.meta.blue)
            let pending = try #require(gameState.player?.meta.engagement.shop)
            #expect(gameState.buyBlueShopItem(id: id, chanceAllowed: true) == .refused(.alreadyPending))
            #expect(gameState.player?.meta.blue == blue)
            #expect(gameState.player?.meta.engagement.shop == pending)
        }
    }

    @Test("cada ítem del catálogo real se puede entregar: ninguno queda sin vender por un premio roto")
    func everyItemDeliverable() async throws {
        let gameState = await rich()
        gameState.debugUnlockFloors(throughTier: 12)
        let catalog = try #require(gameState.content?.blueShop)
        let rows = gameState.blueShopRows(chanceAllowed: true)
        #expect(Set(rows.map(\.id)) == Set(catalog.items.map(\.id)))
    }

    @Test("sin blue no compra nada y lo dice")
    func broke() async throws {
        let gameState = await rich(5)
        #expect(gameState.buyBlueShopItem(id: "income_x2", chanceAllowed: true) == .refused(.cantAfford))
        #expect(gameState.player?.meta.blue == 5)
    }

    @Test("un id que no existe no se vende")
    func unknownItem() async throws {
        let gameState = await rich()
        #expect(gameState.buyBlueShopItem(id: "no_existe", chanceAllowed: true) == .unavailable)
        #expect(gameState.player?.meta.blue == 5_000)
    }

    @Test("un segundo toque de Fusionar todo, con los pares ya encolados, no cobra ni duplica")
    func mergeAllDoubleTap() async throws {
        let gameState = await rich()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        #expect(gameState.buyBlueShopItem(id: "merge_all", chanceAllowed: true) == .bought)
        let queued = gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1)
        #expect(gameState.buyBlueShopItem(id: "merge_all", chanceAllowed: true) == .refused(.nothingToDo))
        #expect(gameState.player?.meta.blue == 4_980)
        #expect(gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1) == queued)
    }

    @Test("el día de la tienda es gregoriano aunque el calendario del sistema no lo sea")
    func gregorianDay() async throws {
        let gameState = await rich()
        let date = Date(timeIntervalSince1970: 1_791_000_000)
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = .current
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        let today = try #require(gameState.blueShopContext(chanceAllowed: true, now: date)?.today)
        #expect(today == DailyRewardManager.dayString(for: date, calendar: gregorian))
        #expect(today != DailyRewardManager.dayString(for: date, calendar: buddhist))
    }
}
