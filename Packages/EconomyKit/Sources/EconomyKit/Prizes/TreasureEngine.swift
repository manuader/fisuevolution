import Foundation

/// El reloj del Colchón y su recorrido (E14b B6, D3/D4). Lo llama el tick: afuera no corre.
public enum TreasureScheduler {
    /// Cómo llegó el que acaba de aparecer.
    public enum Arrival: Equatable, Sendable {
        /// A la columna: se paga con un video y recién ahí cae al tablero.
        case column
        /// De regalo: directo al tablero, sin video.
        case gift
    }

    /// Avanza el reloj; devuelve cómo llegó, si apareció uno. Con uno en juego (en la columna o
    /// en el tablero) no corre. Uno de cada `giftOneIn` se sortea como regalo.
    @discardableResult
    public static func advance<R: RandomNumberGenerator>(
        _ state: inout TreasuresState, delta: Double, config: TreasuresConfig, using rng: inout R
    ) -> Arrival? {
        guard delta > 0, !state.isPresent else { return nil }
        let remaining = (state.secondsUntilNext ?? config.firstTreasureAfterSeconds) - delta
        guard remaining <= 0 else {
            state.secondsUntilNext = remaining
            return nil
        }
        let arrival: Arrival = Double.random(in: 0..<1, using: &rng) < config.giftShare ? .gift : .column
        state.phase = arrival == .gift ? .onBoard : .waiting
        state.gifted = arrival == .gift
        state.clearPlacement()
        state.extraOpensLeft = 0
        state.secondsUntilNext = config.spawnIntervalSeconds
        return arrival
    }

    /// Se miró el video de la columna: el colchón cae al tablero. `false` si no esperaba uno.
    @discardableResult
    public static func markPaid(_ state: inout TreasuresState) -> Bool {
        guard state.phase == .waiting else { return false }
        state.phase = .onBoard
        return true
    }

    /// Se abrió el del tablero: deja de estar en juego, habilita "otro colchón" y el reloj
    /// arranca de nuevo. `false` si no había uno en el tablero. Quien abre lee `gifted` antes.
    @discardableResult
    public static func markOpened(_ state: inout TreasuresState, config: TreasuresConfig) -> Bool {
        guard state.phase == .onBoard else { return false }
        state.phase = .none
        state.gifted = false
        state.clearPlacement()
        state.extraOpensLeft = config.extraOpensPerTreasure
        state.secondsUntilNext = config.spawnIntervalSeconds
        return true
    }
}

public enum TreasureRoller {
    public static func roll<R: RandomNumberGenerator>(_ config: TreasuresConfig, using rng: inout R) -> TreasuresConfig.Prize? {
        WeightedDraw.index(weights: config.prizes.map { Double($0.weight) }, using: &rng).map { config.prizes[$0] }
    }
}
