import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("«Tu meta»: la permanente recomendada y su ahorro (E14 C29)")
@MainActor
struct SavingsGoalTests {
    private func offer(_ id: String, _ price: Int) -> PermanentOffer {
        PermanentOffer(source: .shop(id: id), price: price)
    }

    private func player(blue: Int) async -> GameState {
        let gameState = await makeGameState()
        gameState.flagDefaults = UserDefaults(suiteName: "savings-goal-\(UUID().uuidString)") ?? .standard
        gameState.player?.meta.blue = blue
        return gameState
    }

    @Test("sin elección propia manda la de mayor impacto; la fijada gana mientras se pueda comprar")
    func pickPrefersThePinnedOne() {
        let offers = [offer("a", 600), offer("b", 150), offer("c", 120)]
        #expect(SavingsGoal.pick(from: offers, pinned: nil)?.id == "a")
        #expect(SavingsGoal.pick(from: offers, pinned: "c")?.id == "c")
        #expect(SavingsGoal.pick(from: offers, pinned: "ya-comprada")?.id == "a")
        #expect(SavingsGoal.pick(from: [], pinned: "c") == nil)
    }

    @Test("«Otra meta» recorre la lista y da la vuelta")
    func nextWraps() {
        let offers = [offer("a", 600), offer("b", 150), offer("c", 120)]
        #expect(SavingsGoal.next(after: offers[0], in: offers)?.id == "b")
        #expect(SavingsGoal.next(after: offers[2], in: offers)?.id == "a")
    }

    @Test("la barra cuenta lo ahorrado hasta el precio y se vuelve botón cuando alcanza")
    func progressAndReadiness() {
        let target = offer("a", 200)
        let saving = SavingsGoal(offer: target, balance: 160)
        #expect(saving.saved == 160)
        #expect(abs(saving.progress - 0.8) < 1e-9)
        #expect(!saving.isReady)
        let rich = SavingsGoal(offer: target, balance: 900)
        #expect(rich.saved == 200)
        #expect(rich.progress == 1)
        #expect(rich.isReady)
    }

    @Test("los lugares extra de la torre van primero; después el catálogo y las siete globales")
    func extraSlotsComeFirst() async throws {
        let gameState = await player(blue: 0)
        let offers = gameState.permanentOffers
        #expect(offers.first?.source == .shop(id: "extra_slots"))
        let lines = try #require(gameState.content).upgradesConfig.upgrades.map(\.id)
        let lineOffers = offers.compactMap { offer -> String? in
            if case .line(let id) = offer.source { id } else { nil }
        }
        #expect(lineOffers == lines, "las globales, en el orden del dato, después de las del catálogo")
        let firstLine = try #require(offers.firstIndex { if case .line = $0.source { true } else { false } })
        #expect(offers[..<firstLine].allSatisfy { if case .shop = $0.source { true } else { false } })
    }

    @Test("la meta por defecto son los lugares extra, y con el saldo justo se compra por su estante")
    func buyingTheGoalChargesTheShelfPrice() async throws {
        let gameState = await player(blue: 599)
        var goal = try #require(gameState.savingsGoal)
        #expect(goal.offer.source == .shop(id: "extra_slots"))
        #expect(goal.offer.price == 600)
        #expect(!goal.isReady)
        gameState.buyPermanentOffer(goal.offer)
        #expect(gameState.player?.meta.blue == 599, "sin saldo no se cobra")

        gameState.player?.meta.blue = 600
        goal = try #require(gameState.savingsGoal)
        #expect(goal.isReady)
        gameState.buyPermanentOffer(goal.offer)
        #expect(gameState.player?.meta.blue == 0)
        #expect(gameState.player?.meta.engagement.shop.levels["extra_slots"] == 1)
        #expect(gameState.savingsGoal?.offer.price == 1500, "la meta sigue: el segundo nivel de lugares")
    }

    @Test("fijar otra meta la deja elegida y comprar una global la cobra por su línea")
    func cyclingPinsTheNextOne() async throws {
        let gameState = await player(blue: 10_000)
        let first = try #require(gameState.savingsGoal).offer
        gameState.cycleSavingsGoal()
        let second = try #require(gameState.savingsGoal).offer
        #expect(second.id != first.id)
        #expect(gameState.savingsGoal?.offer == second, "queda fijada")

        let line = try #require(gameState.permanentOffers.first { if case .line = $0.source { true } else { false } })
        let before = try #require(gameState.player?.meta.blue)
        gameState.buyPermanentOffer(line)
        #expect(gameState.player?.meta.blue == before - line.price)
    }

    @Test("lo comprado al máximo sale de las ofertas")
    func maxedOffersLeave() async throws {
        let gameState = await player(blue: 100_000)
        for _ in 0..<2 { gameState.buyPermanentOffer(offer("extra_slots", 0)) }
        #expect(!gameState.permanentOffers.contains { $0.source == .shop(id: "extra_slots") })
    }
}
