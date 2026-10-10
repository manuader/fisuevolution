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

    /// Visitantes: relojes de juego activo, anti-repetición y topes del día (PLAN-v2 E4).
    public var visitors: VisitorsState

    /// Eventos v2: reloj de juego, cooldowns y el próximo ya sorteado (PLAN-v2 E4).
    public var events: EventsState

    /// El buzón del Paquete de la Aduana: reloj de juego y los que esperan (PLAN-v2 E5).
    public var packages: PackagesState

    /// El Colchón: reloj de juego, si espera y los "otro colchón" que quedan (PLAN-v2 E5).
    public var treasures: TreasuresState

    /// La ruleta: el día de los cupos, lo usado y los giros regalados (PLAN-v2 E5).
    public var wheel: WheelState

    public init(
        seenCinematics: [String: Int] = [:],
        sharedMoments: Set<String> = [],
        visitors: VisitorsState = .initial,
        events: EventsState = .initial,
        packages: PackagesState = .initial,
        treasures: TreasuresState = .initial,
        wheel: WheelState = .initial
    ) {
        self.seenCinematics = seenCinematics
        self.sharedMoments = sharedMoments
        self.visitors = visitors
        self.events = events
        self.packages = packages
        self.treasures = treasures
        self.wheel = wheel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seenCinematics = try container.decodeIfPresent([String: Int].self, forKey: .seenCinematics) ?? [:]
        sharedMoments = try container.decodeIfPresent(Set<String>.self, forKey: .sharedMoments) ?? []
        visitors = try container.decodeIfPresent(VisitorsState.self, forKey: .visitors) ?? .initial
        events = try container.decodeIfPresent(EventsState.self, forKey: .events) ?? .initial
        packages = try container.decodeIfPresent(PackagesState.self, forKey: .packages) ?? .initial
        treasures = try container.decodeIfPresent(TreasuresState.self, forKey: .treasures) ?? .initial
        wheel = try container.decodeIfPresent(WheelState.self, forKey: .wheel) ?? .initial
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
        resolved.visitors = VisitorsState.resolve(winner: winner.visitors, loser: loser.visitors)
        resolved.events = EventsState.resolve(winner: winner.events, loser: loser.events)
        // El buzón y el colchón son relojes y una cuenta: unirlos fabricaría paquetes. Viajan con el ganador.
        resolved.wheel = WheelState.resolve(winner: winner.wheel, loser: loser.wheel)
        return resolved
    }
}
