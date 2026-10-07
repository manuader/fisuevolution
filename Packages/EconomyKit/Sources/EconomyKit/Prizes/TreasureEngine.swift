import Foundation

/// El reloj del Colchón. Lo llama el tick: afuera no corre.
public enum TreasureScheduler {
    /// Avanza el reloj; devuelve si apareció uno. Con uno esperando no corre.
    @discardableResult
    public static func advance(_ state: inout TreasuresState, delta: Double, config: TreasuresConfig) -> Bool {
        guard delta > 0, !state.waiting else { return false }
        let remaining = (state.secondsUntilNext ?? config.firstTreasureAfterSeconds) - delta
        guard remaining <= 0 else {
            state.secondsUntilNext = remaining
            return false
        }
        state.waiting = true
        state.extraOpensLeft = 0
        state.secondsUntilNext = config.spawnIntervalSeconds
        return true
    }

    /// Se abrió (con el primer video): deja de esperar, habilita "otro
    /// colchón" y el reloj arranca de nuevo.
    public static func markOpened(_ state: inout TreasuresState, config: TreasuresConfig) {
        state.waiting = false
        state.extraOpensLeft = config.extraOpensPerTreasure
        state.secondsUntilNext = config.spawnIntervalSeconds
    }
}

public enum TreasureRoller {
    public static func roll<R: RandomNumberGenerator>(_ config: TreasuresConfig, using rng: inout R) -> TreasuresConfig.Prize? {
        WeightedDraw.index(weights: config.prizes.map { Double($0.weight) }, using: &rng).map { config.prizes[$0] }
    }
}
