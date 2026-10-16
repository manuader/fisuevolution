import Foundation

/// El reloj del Colchón de la columna y su recorrido (E14b B6, D3). Lo llama el tick: afuera no corre.
public enum TreasureScheduler {
    /// Avanza el reloj; `true` si apareció uno en la columna, que pide su video. Con uno en juego
    /// (en la columna o en el tablero) no corre. El gratis del tablero no lo frena (`FreeMattressClock`).
    @discardableResult
    public static func advance(_ state: inout TreasuresState, delta: Double, config: TreasuresConfig) -> Bool {
        guard delta > 0, !state.isPresent else { return false }
        let remaining = (state.secondsUntilNext ?? config.firstTreasureAfterSeconds) - delta
        guard remaining <= 0 else {
            state.secondsUntilNext = remaining
            return false
        }
        state.phase = .waiting
        state.clearPlacement()
        state.extraOpensLeft = 0
        state.secondsUntilNext = config.spawnIntervalSeconds
        return true
    }

    /// Se miró el video de la columna: el colchón cae al tablero. `false` si no esperaba uno.
    @discardableResult
    public static func markPaid(_ state: inout TreasuresState) -> Bool {
        guard state.phase == .waiting else { return false }
        state.phase = .onBoard
        return true
    }

    /// Se abrió el del tablero: deja de estar en juego, habilita "otro colchón" y el reloj
    /// arranca de nuevo. `false` si no había uno en el tablero.
    @discardableResult
    public static func markOpened(_ state: inout TreasuresState, config: TreasuresConfig) -> Bool {
        guard state.phase == .onBoard else { return false }
        state.phase = .none
        state.clearPlacement()
        state.extraOpensLeft = config.extraOpensPerTreasure
        state.secondsUntilNext = config.spawnIntervalSeconds
        return true
    }
}

/// El reloj del colchón gratis del tablero (E14b B31, D20): de reloj real, así que corre también con
/// el juego cerrado. Guarda uno solo y arranca de nuevo al abrirlo. No mira al de la columna, ni el de
/// la columna a él.
public enum FreeMattressClock {
    /// Avanza a `now` (segundos de reloj real); `true` si cayó uno. Uno esperando frena el reloj. El
    /// reloj que nunca arrancó (partida nueva, save anterior a B31) arranca ahora; si la hora del
    /// teléfono volvió para atrás, arranca de nuevo desde ahora en vez de quedarse trabado.
    @discardableResult
    public static func advance(_ state: inout TreasuresState, now: Double, config: TreasuresConfig) -> Bool {
        let interval = config.freeBoardIntervalSeconds
        guard interval > 0, now.isFinite, !state.freeBoard.waiting else { return false }
        guard let started = state.freeBoard.clockStartedAt, started <= now else {
            state.freeBoard.clockStartedAt = now
            return false
        }
        guard now - started >= interval else { return false }
        state.freeBoard.waiting = true
        state.freeBoard.clearPlacement()
        return true
    }

    /// Se abrió el que esperaba: se va del tablero y el reloj arranca de nuevo en `now`. `false` si
    /// no había uno.
    @discardableResult
    public static func markOpened(_ state: inout TreasuresState, now: Double) -> Bool {
        guard state.freeBoard.waiting else { return false }
        state.freeBoard.waiting = false
        state.freeBoard.clearPlacement()
        state.freeBoard.clockStartedAt = now
        return true
    }
}

public enum TreasureRoller {
    public static func roll<R: RandomNumberGenerator>(_ config: TreasuresConfig, using rng: inout R) -> TreasuresConfig.Prize? {
        draw(config.prizes, using: &rng)
    }

    /// El sorteo del colchón gratis del tablero (E14b B31): con su tabla, o la de la columna.
    public static func rollFree<R: RandomNumberGenerator>(_ config: TreasuresConfig, using rng: inout R) -> TreasuresConfig.Prize? {
        draw(config.freePrizes, using: &rng)
    }

    private static func draw<R: RandomNumberGenerator>(_ prizes: [TreasuresConfig.Prize], using rng: inout R) -> TreasuresConfig.Prize? {
        WeightedDraw.index(weights: prizes.map { Double($0.weight) }, using: &rng).map { prizes[$0] }
    }
}
