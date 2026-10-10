import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El precio tachado de un descuento temporal", .serialized)
@MainActor
struct DiscountedPriceTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "discount-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugMarkTypesSeen(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        return gameState
    }

    private func hirable(_ gameState: GameState) -> [JobRow] {
        gameState.jobRows.filter { $0.state == .hirable }
    }

    @Test("sin descuento no hay nada tachado")
    func noDiscountNoStrike() async throws {
        let gameState = await world()
        #expect(!hirable(gameState).isEmpty)
        #expect(hirable(gameState).allSatisfy { $0.listCostText == nil })
        #expect(gameState.quickHireOffer?.listCostText == nil)
    }

    @Test("con la Liquidación, FisuJobs y el atajo tachan el precio de lista")
    func theSaleStrikesTheListPrice() async throws {
        let gameState = await world()
        gameState.debugStartEvent(id: "liquidacion")
        gameState.refreshProjections()
        let row = try #require(hirable(gameState).first)
        let list = try #require(row.listCostText)
        #expect(list != row.costText)
        #expect(gameState.quickHireOffer?.listCostText != nil)
    }

    @Test("un recargo no tacha nada")
    func aSurchargeStrikesNothing() async throws {
        let gameState = await world()
        gameState.debugStartEvent(id: "home_banking")
        gameState.refreshProjections()
        #expect(hirable(gameState).allSatisfy { $0.listCostText == nil })
    }

    @Test("tres descuentos juntos cobran el piso: un cuarto de la lista")
    func stackedDiscountsChargeTheFloor() async throws {
        let gameState = await world()
        let player = try #require(gameState.player)
        let typeId = try #require(hirable(gameState).first?.id)
        let list = try #require(gameState.currentQuote(player: player, typeId: typeId)?.cost)
        gameState.debugStartEvent(id: "liquidacion")
        let now = Date().timeIntervalSince1970
        gameState.player?.run.activeModifiers += [
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.7, expiresAt: now + 60, sourceKey: "boost.mate"),
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.7, expiresAt: now + 60, sourceKey: "visit.arca_factura"),
        ]
        let discounted = try #require(gameState.player)
        let charged = try #require(gameState.currentQuote(player: discounted, typeId: typeId)?.cost)
        #expect(abs(charged / list - ModifierMath.spawnCostStackFloor) < 0.01)
    }
}
