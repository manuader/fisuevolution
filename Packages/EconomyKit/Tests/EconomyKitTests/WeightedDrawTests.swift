import Foundation
import Testing
@testable import EconomyKit

@Suite("Sorteo con pesos")
struct WeightedDrawTests {
    private func draws(_ weights: [Double], count: Int, seed: UInt64) -> [Int] {
        var rng = SeededRNG(seed: seed)
        return (0..<count).compactMap { _ in WeightedDraw.index(weights: weights, using: &rng) }
    }

    @Test("un peso en cero o negativo no sale nunca, y los demás se reparten por peso")
    func onlyPositiveWeightsAreDrawn() {
        let picks = draws([0, -5, 3, 0, 1, 0, -1], count: 8_000, seed: 20_261_007)
        #expect(picks.count == 8_000)
        #expect(Set(picks) == [2, 4])
        let share = Double(picks.filter { $0 == 2 }.count) / Double(picks.count)
        #expect(share > 0.72 && share < 0.78, "el índice 2 salió \(share)")
    }

    @Test("sin ningún peso positivo no hay sorteo")
    func nothingPositiveDrawsNothing() {
        var rng = SeededRNG(seed: 1)
        #expect(WeightedDraw.index(weights: [], using: &rng) == nil)
        #expect(WeightedDraw.index(weights: [0, 0], using: &rng) == nil)
        #expect(WeightedDraw.index(weights: [-1, -2], using: &rng) == nil)
    }

    @Test("un único peso positivo sale siempre")
    func aSinglePositiveWeightAlwaysWins() {
        #expect(Set(draws([0, 0, 4, 0], count: 200, seed: 7)) == [2])
    }

    @Test("la misma semilla da la misma secuencia")
    func theSameSeedRepeats() {
        let weights = [1.0, 2, 3, 4]
        #expect(draws(weights, count: 64, seed: 42) == draws(weights, count: 64, seed: 42))
        #expect(draws(weights, count: 64, seed: 42) != draws(weights, count: 64, seed: 43))
    }

    @Test("el ticket cae en el tramo de su peso, y justo en el borde pasa al siguiente")
    func aTicketLandsInItsSpan() {
        let weights = [2.0, 3]
        #expect(WeightedDraw.index(weights: weights, ticket: 0) == 0)
        #expect(WeightedDraw.index(weights: weights, ticket: 1.9) == 0)
        #expect(WeightedDraw.index(weights: weights, ticket: 2) == 1)
        #expect(WeightedDraw.index(weights: weights, ticket: 4.9) == 1)
    }

    @Test("un ticket que se pasa por redondeo cae en el último con peso, no en un cero de la cola")
    func anOvershootingTicketFallsOnTheLastPositive() {
        #expect(WeightedDraw.index(weights: [2, 3], ticket: 5) == 1)
        #expect(WeightedDraw.index(weights: [0, 4, 0, -1], ticket: 99) == 1)
        #expect(WeightedDraw.index(weights: [-1, -2], ticket: 0) == nil)
    }

    @Test("las probabilidades son cada peso sobre el total, y los negativos cuentan cero")
    func probabilitiesAreWeightsOverTotal() {
        #expect(WeightedDraw.probabilities(weights: [1, -1, 3]) == [0.25, 0, 0.75])
        #expect(WeightedDraw.probabilities(weights: []) == [])
        #expect(WeightedDraw.probabilities(weights: [0, 0]) == [0, 0])
        #expect(WeightedDraw.probabilities(weights: [-1, -2]) == [0, 0])
    }
}
