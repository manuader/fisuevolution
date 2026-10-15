import Foundation

/// El Colchón (vive en `meta.engagement`). El reloj es de JUEGO ACTIVO y sólo
/// corre sin un colchón en juego: no se acumula más de uno.
public struct TreasuresState: Codable, Sendable, Equatable {
    /// El recorrido de un colchón (E14b B6, D3/D4): aparece en la columna y pide un video
    /// (`waiting`); pagado o regalado, cae al tablero (`onBoard`); abierto, vuelve a `none`.
    public enum Phase: String, Codable, Sendable, Equatable {
        case none
        case waiting
        case onBoard
    }

    /// Segundos de juego hasta el próximo. `nil` = nunca se programó.
    public var secondsUntilNext: Double?
    public var phase: Phase
    /// Los "otro colchón" que le quedan al último que se abrió. Se pierden
    /// cuando aparece uno nuevo.
    public var extraOpensLeft: Int
    /// El del tablero llegó de regalo (D4): al cobrarlo se ofrece el «×2 con video» (E14b B29).
    /// El pagado con video no, porque ya costó uno.
    public var gifted: Bool

    public static let initial = TreasuresState()

    public init(secondsUntilNext: Double? = nil, phase: Phase = .none, extraOpensLeft: Int = 0, gifted: Bool = false) {
        self.secondsUntilNext = secondsUntilNext
        self.phase = phase
        self.extraOpensLeft = extraOpensLeft
        self.gifted = gifted
    }

    /// Hay un colchón en juego, en la columna o en el tablero: el reloj no corre.
    public var isPresent: Bool { phase != .none }

    private enum CodingKeys: String, CodingKey {
        case secondsUntilNext, phase, extraOpensLeft, gifted
        /// El de antes de B6: un colchón esperando en la columna.
        case waiting
    }

    /// Un save anterior a B6 trae `waiting`: el que esperaba sigue esperando su video en la columna.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        extraOpensLeft = try container.decodeIfPresent(Int.self, forKey: .extraOpensLeft) ?? 0
        gifted = try container.decodeIfPresent(Bool.self, forKey: .gifted) ?? false
        if let phase = (try? container.decodeIfPresent(Phase.self, forKey: .phase)) ?? nil {
            self.phase = phase
        } else {
            let legacyWaiting = try container.decodeIfPresent(Bool.self, forKey: .waiting) ?? false
            phase = legacyWaiting ? .waiting : .none
        }
    }

    /// Escribe también `waiting` para que una versión anterior a B6 que lea este save siga viendo
    /// el colchón en juego (y lo ofrezca con video).
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(secondsUntilNext, forKey: .secondsUntilNext)
        try container.encode(phase, forKey: .phase)
        try container.encode(extraOpensLeft, forKey: .extraOpensLeft)
        try container.encode(gifted, forKey: .gifted)
        try container.encode(isPresent, forKey: .waiting)
    }
}
