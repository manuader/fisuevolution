import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Lugares extra en la partida")
@MainActor
struct ExtraSlotsWiringTests {
    private func rich() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 5_000
        return gameState
    }

    @Test("comprar los lugares agranda todos los pisos en el acto: torre, mapa y ocupación")
    func buyingGrowsEveryFloor() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.baseFloorTable.floors.map(\.capacity))
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.content?.floorTable.floors.map(\.capacity) == base.map { $0 + 3 })
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base[0] + 3)
        #expect(gameState.tower?.floors[0].slots.count == base[0] + 3)
        #expect(gameState.floorMap.last?.capacity == base[0] + 3, "el mapa dice cuánto entra")
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base[0] + 5)
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .refused(.maxed))
    }

    @Test("lo que desbordaba entra: con los lugares, nadie se fusiona solo al cargar")
    func moreRoomNoAutoMerge() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.baseFloorTable[0].capacity)
        gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true)
        let type = try #require(gameState.content?.tiers.baseType)
        gameState.player?.run.units = [type.id: base + 3]
        gameState.reconcileTower()
        #expect(gameState.player?.run.units[type.id] == base + 3)
    }

    @Test("los lugares se recuerdan: una carga nueva los vuelve a aplicar")
    func levelsArePersisted() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.baseFloorTable[0].capacity)
        gameState.player?.meta.engagement.shop.levels["extra_slots"] = 2
        gameState.reconcileTower()
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base + 5)
    }

    @Test("el Paquete de la Aduana (E5a) entra en los lugares comprados")
    func packagesUseTheExtraRoom() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(1)
        #expect(gameState.packagesBlocked, "con la torre llena, LLENO")
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(!gameState.packagesBlocked, "E5a lee content.floorTable: con los lugares nuevos, entra")
    }

    @Test("con 20 lugares, el tablero son 4 filas")
    func fourRows() {
        #expect(PlayLayout.rows(forCapacity: 20) == 4)
        #expect(PlayLayout(size: CGSize(width: 375, height: 667), capacity: 20).rows == 4)
    }

    // MARK: La plata

    @Test("se cobra una sola vez el precio del nivel, ni un ORO más")
    func chargedExactlyOnce() async throws {
        let gameState = await rich()
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.oro == 5_000 - 600)
        #expect(gameState.player?.meta.engagement.shop.levels["extra_slots"] == 1)
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.oro == 5_000 - 600 - 1_500, "el segundo toque es el nivel 2, a su precio")
    }

    @Test("el segundo toque con plata sólo para uno no cobra ni agranda de nuevo")
    func secondTapWithOneLevelOfOro() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.baseFloorTable[0].capacity)
        gameState.player?.meta.oro = 600
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .refused(.cantAfford))
        #expect(gameState.player?.meta.oro == 0)
        #expect(gameState.player?.meta.engagement.shop.levels["extra_slots"] == 1)
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base + 3)
    }

    @Test("un ORO menos que el precio no cobra ni agranda")
    func oneShortOfThePrice() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.baseFloorTable[0].capacity)
        gameState.player?.meta.oro = 599
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .refused(.cantAfford))
        #expect(gameState.player?.meta.oro == 599)
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base)
    }

    @Test("un precio 0, 1 o negativo en el dato no se vende: el catálogo no carga")
    func badPricesAreRejected() throws {
        let floorIDs = Set(try GameContentLoader.load(from: .main).floorTable.floors.map(\.id))
        for price in [0, -1] {
            let json = """
            {"schemaVersion": 1, "items": [
              {"id": "extra_slots", "shelf": "permanents", "iconKey": "x", "symbol": "x",
               "perk": "extraSlots", "levels": [{"price": \(price), "value": 3}]}]}
            """
            let shop = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
            #expect(throws: OroShopCatalog.ValidationError.nonPositivePrice("extra_slots")) {
                try shop.validate(floorIDs: floorIDs)
            }
        }
        let one = """
        {"schemaVersion": 1, "items": [
          {"id": "extra_slots", "shelf": "permanents", "iconKey": "x", "symbol": "x",
           "perk": "extraSlots", "levels": [{"price": 1, "value": 3}]}]}
        """
        let shop = try JSONDecoder().decode(OroShopCatalog.self, from: Data(one.utf8))
        #expect(throws: Never.self) { try shop.validate(floorIDs: floorIDs) }
    }

    // MARK: El tablero no se mueve

    @Test("comprar no reacomoda a nadie: cada unidad sigue en su lugar")
    func arrangementSurvives() async throws {
        let gameState = await rich()
        let type = try #require(gameState.content?.tiers.baseType)
        gameState.player?.run.units = [type.id: 3]
        gameState.reconcileTower()
        var tower = try #require(gameState.tower)
        tower.floors[0].slots = tower.floors[0].slots.map { _ in nil }
        tower.floors[0].slots[0] = type.id
        tower.floors[0].slots[4] = type.id
        tower.floors[0].slots[7] = type.id
        gameState.tower = tower
        let before = gameState.tower?.floors[0].slots
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        let after = try #require(gameState.tower?.floors[0].slots)
        #expect(Array(after.prefix(before?.count ?? 0)) == before, "los huecos quedan donde estaban")
        #expect(after.count == (before?.count ?? 0) + 3)
    }

    @Test("un cambio del tablero en vuelo sigue valiendo después de comprar")
    func inFlightChangeSurvivesThePurchase() async throws {
        let gameState = await rich()
        let type = try #require(gameState.content?.tiers.baseType)
        gameState.player?.run.units = [type.id: 2]
        gameState.reconcileTower()
        let tower = try #require(gameState.tower)
        let slots = tower.placements(onFloor: 0).map(\.slot)
        let next = try #require(gameState.content?.tiers.type(id: type.id)?.mergesInto)
        let change = BoardChange(
            kind: .merge(floorOrdinal: 0, typeId: type.id, sourceSlot: slots[0], targetSlot: slots[1], newTypeId: next),
            origin: .oroShop
        )
        gameState.inFlightBoardChange = change
        gameState.pendingBoardChanges = [change]
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.inFlightBoardChange == change, "la compra no lo toca")
        #expect(gameState.pendingBoardChanges == [change])
        let player = try #require(gameState.player)
        let content = try #require(gameState.content)
        let tower2 = try #require(gameState.tower)
        #expect(BoardChangePlanner.revalidate(
            change, state: player, tower: tower2, tiers: content.tiers, floorTable: content.floorTable
        ) == change, "el mismo cambio, intacto, contra la torre agrandada")
    }

    @Test("el piso que se mira no cambia al comprar")
    func visibleFloorStays() async throws {
        let gameState = await rich()
        gameState.visibleFloorOrdinal = 0
        gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true)
        #expect(gameState.visibleFloorOrdinal == 0)
    }
}
