import Foundation

/// Lo que se recuerda de los eventos v2 (PLAN-v2 E4). Hasta la 1.x el reloj vivía
/// en memoria y se reiniciaba en cada arranque: quien abría la app de a ratos
/// cortos no veía nunca un evento.
public struct EventsState: Codable, Sendable, Equatable {
    /// Segundos de juego activo acumulados. Los cooldowns se miden contra esto.
    public var clock: Double
    /// Segundos de juego hasta el próximo sorteo. `nil` = nunca se programó.
    public var secondsUntilNext: Double?
    /// Cuándo salió cada evento, en `clock`.
    public var lastFiredAt: [String: Double]
    /// El próximo, ya sorteado: la Vecina chusma lo adelanta y es el que sale.
    public var upcomingId: String?
    /// Cuándo salió el último evento de compra, en `clock` (C25).
    public var lastShopEventAt: Double?
    /// Cuándo se acreditó la última compra con plata real (segundos desde 1970).
    public var lastPurchaseAt: Double?

    public static let initial = EventsState()

    public init(
        clock: Double = 0,
        secondsUntilNext: Double? = nil,
        lastFiredAt: [String: Double] = [:],
        upcomingId: String? = nil,
        lastShopEventAt: Double? = nil,
        lastPurchaseAt: Double? = nil
    ) {
        self.clock = clock
        self.secondsUntilNext = secondsUntilNext
        self.lastFiredAt = lastFiredAt
        self.upcomingId = upcomingId
        self.lastShopEventAt = lastShopEventAt
        self.lastPurchaseAt = lastPurchaseAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clock = try container.decodeIfPresent(Double.self, forKey: .clock) ?? 0
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        lastFiredAt = try container.decodeIfPresent([String: Double].self, forKey: .lastFiredAt) ?? [:]
        upcomingId = try container.decodeIfPresent(String.self, forKey: .upcomingId)
        lastShopEventAt = try container.decodeIfPresent(Double.self, forKey: .lastShopEventAt)
        lastPurchaseAt = try container.decodeIfPresent(Double.self, forKey: .lastPurchaseAt)
    }

    /// El reloj más avanzado y el cooldown más reciente de cada evento: un
    /// evento que salió en cualquiera de los dos dispositivos no vuelve antes.
    public static func resolve(winner: EventsState, loser: EventsState) -> EventsState {
        var resolved = winner
        resolved.clock = max(winner.clock, loser.clock)
        resolved.lastFiredAt = winner.lastFiredAt.merging(loser.lastFiredAt, uniquingKeysWith: max)
        resolved.lastShopEventAt = [winner.lastShopEventAt, loser.lastShopEventAt].compactMap { $0 }.max()
        resolved.lastPurchaseAt = [winner.lastPurchaseAt, loser.lastPurchaseAt].compactMap { $0 }.max()
        return resolved
    }
}
