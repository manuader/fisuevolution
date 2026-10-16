import Foundation

/// En qué escalón de valor está un jugador (2.1 E15 F1, contrato C1). `base` es el juego de la
/// 2.0 tal cual: lo asigna la compuerta (interruptor, consentimiento, UI test), nunca las reglas.
/// Los demás los decide `PlayerValue.evaluate`.
public enum PlayerSegment: String, Codable, Sendable, CaseIterable, Comparable {
    case base, low, mid, high

    /// El orden de los escalones: `base` < `low` < `mid` < `high`.
    public var rank: Int {
        switch self {
        case .base: 0
        case .low: 1
        case .mid: 2
        case .high: 3
        }
    }

    public static func < (lhs: PlayerSegment, rhs: PlayerSegment) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Un segmento que este build no conoce (de una config o un build futuro) se lee como `base`:
    /// ante la duda, el juego de siempre.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlayerSegment(rawValue: raw) ?? .base
    }
}
