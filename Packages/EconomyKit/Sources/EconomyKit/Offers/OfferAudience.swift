import Foundation

/// A quién se le abre una oferta (2.1 E15 F5, contrato C1). Sólo elige **qué** oferta ve cada
/// uno: el precio es el del producto de App Store y no cambia. Una oferta sin audiencia es para
/// todos, como en la 2.0.
public struct OfferAudience: Codable, Sendable, Equatable {
    public enum Buyer: String, Codable, Sendable, CaseIterable {
        /// Compró o no, da igual.
        case any
        /// Sólo quien todavía no compró nada.
        case nonBuyer
        /// Sólo quien ya compró algo.
        case buyer
    }

    /// Los segmentos que la ven; `nil` = todos. No puede estar vacía ni nombrar `base`.
    public let segments: [PlayerSegment]?
    public let buyer: Buyer

    public init(segments: [PlayerSegment]? = nil, buyer: Buyer = .any) {
        self.segments = segments
        self.buyer = buyer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        segments = try container.decodeIfPresent([PlayerSegment].self, forKey: .segments)
        buyer = try container.decodeIfPresent(Buyer.self, forKey: .buyer) ?? .any
    }

    /// `base` ve exactamente las ofertas de la 2.0: con `base` la audiencia se ignora, así el
    /// interruptor apaga F5 entero.
    public func admits(segment: PlayerSegment, hasPurchased: Bool) -> Bool {
        guard segment != .base else { return true }
        if let segments, !segments.contains(segment) { return false }
        switch buyer {
        case .any: return true
        case .nonBuyer: return !hasPurchased
        case .buyer: return hasPurchased
        }
    }

    /// Una lista vacía no le abriría a nadie y `base` no se apunta (es la 2.0). Un segmento que
    /// este build no conoce se lee como `base` y también cae acá.
    public var isValid: Bool {
        guard let segments else { return true }
        return !segments.isEmpty && !segments.contains(.base)
    }
}
