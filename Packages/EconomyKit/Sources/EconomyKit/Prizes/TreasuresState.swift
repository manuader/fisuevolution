import Foundation

/// El Colchón (vive en `meta.engagement`). El reloj es de JUEGO ACTIVO y sólo
/// corre sin uno esperando: no se acumula más de uno.
public struct TreasuresState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta el próximo. `nil` = nunca se programó.
    public var secondsUntilNext: Double?
    /// Hay uno esperando que lo abran.
    public var waiting: Bool
    /// Los "otro colchón" que le quedan al último que se abrió. Se pierden
    /// cuando aparece uno nuevo.
    public var extraOpensLeft: Int

    public static let initial = TreasuresState()

    public init(secondsUntilNext: Double? = nil, waiting: Bool = false, extraOpensLeft: Int = 0) {
        self.secondsUntilNext = secondsUntilNext
        self.waiting = waiting
        self.extraOpensLeft = extraOpensLeft
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        waiting = try container.decodeIfPresent(Bool.self, forKey: .waiting) ?? false
        extraOpensLeft = try container.decodeIfPresent(Int.self, forKey: .extraOpensLeft) ?? 0
    }
}
