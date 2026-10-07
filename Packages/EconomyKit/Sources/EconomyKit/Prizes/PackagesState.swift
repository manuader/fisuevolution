import Foundation

/// El buzón del Paquete de la Aduana (vive en `meta.engagement`). El reloj es
/// de JUEGO ACTIVO: el background no lo mueve.
public struct PackagesState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta el próximo. `nil` = nunca se programó (partida
    /// nueva o save anterior a E5): el reloj arranca en `firstPackageAfterSeconds`.
    public var secondsUntilNext: Double?
    /// Los que esperan que el jugador los abra.
    public var waiting: Int

    public static let initial = PackagesState()

    public init(secondsUntilNext: Double? = nil, waiting: Int = 0) {
        self.secondsUntilNext = secondsUntilNext
        self.waiting = waiting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        waiting = try container.decodeIfPresent(Int.self, forKey: .waiting) ?? 0
    }
}
