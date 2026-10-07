import Foundation

/// Una fila de la tabla de un premio con azar, tal como se le muestra al
/// jugador (Apple 3.1.1). Sale de la misma tabla con la que se sortea.
public struct PrizeOdds: Sendable, Equatable {
    public let id: String
    public let probability: Double

    public init(id: String, probability: Double) {
        self.id = id
        self.probability = probability
    }
}

/// El sorteo con pesos que comparten el paquete, el colchón y la ruleta: los
/// tres muestran la tabla con la que sortean, así que la cuenta es una sola.
public enum WeightedDraw {
    /// El índice sorteado, o `nil` si no hay ningún peso positivo. Los pesos
    /// negativos cuentan como cero.
    public static func index<R: RandomNumberGenerator>(weights: [Double], using rng: inout R) -> Int? {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return nil }
        var ticket = Double.random(in: 0..<total, using: &rng)
        for (index, weight) in weights.enumerated() where weight > 0 {
            if ticket < weight { return index }
            ticket -= weight
        }
        return weights.lastIndex { $0 > 0 }
    }

    /// Cada peso sobre el total.
    public static func probabilities(weights: [Double]) -> [Double] {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return weights.map { _ in 0 } }
        return weights.map { max(0, $0) / total }
    }
}
