import Foundation

/// Lo que suman las épicas de engagement (visitantes, paquetes, colchón, ruleta,
/// tienda, ofertas). Crece campo a campo con `decodeIfPresent ?? default` y su
/// regla en `resolve`, sin volver a subir el schema del save. Nace vacío.
public struct EngagementState: Codable, Sendable, Equatable {
    public static let initial = EngagementState()

    /// Cuántas veces vio la cuenta cada cinemática (PLAN-v2 E8), por su id
    /// (`reencarnacion`, `arresto`, `dios`). Es de la cuenta: reencarnar no la
    /// toca. La app decide cuántas veces se muestra cada una.
    public var seenCinematics: [String: Int]

    /// Las claves de los momentos virales ya compartidos (`ShareMoment.key` en la
    /// app): cada uno paga su premio una sola vez (PLAN-v2 E3).
    public var sharedMoments: Set<String>

    public init(seenCinematics: [String: Int] = [:], sharedMoments: Set<String> = []) {
        self.seenCinematics = seenCinematics
        self.sharedMoments = sharedMoments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seenCinematics = try container.decodeIfPresent([String: Int].self, forKey: .seenCinematics) ?? [:]
        sharedMoments = try container.decodeIfPresent(Set<String>.self, forKey: .sharedMoments) ?? []
    }

    public mutating func recordCinematic(_ id: String) {
        seenCinematics[id, default: 0] += 1
    }

    /// Lo visto no se des-ve: el máximo por id. Un `+` contaría dos veces la misma
    /// función en cada sync.
    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        var resolved = winner
        resolved.seenCinematics.merge(loser.seenCinematics, uniquingKeysWith: max)
        // Lo compartido se une: un momento cobrado en cualquier dispositivo no se cobra de nuevo.
        resolved.sharedMoments.formUnion(loser.sharedMoments)
        return resolved
    }
}
