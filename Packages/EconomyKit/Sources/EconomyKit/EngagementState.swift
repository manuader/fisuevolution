import Foundation

/// Lo que suman las épicas de engagement (visitantes, paquetes, colchón, ruleta,
/// tienda, ofertas). Crece campo a campo con `decodeIfPresent ?? default` y su
/// regla en `resolve`, sin volver a subir el schema del save. Nace vacío.
public struct EngagementState: Codable, Sendable, Equatable {
    public static let initial = EngagementState()

    public init() {}

    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        winner
    }
}
