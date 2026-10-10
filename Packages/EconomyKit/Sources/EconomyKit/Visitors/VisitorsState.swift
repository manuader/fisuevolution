import Foundation

/// Lo que se recuerda de los visitantes entre partidas (PLAN-v2 E4). Los relojes
/// son de JUEGO ACTIVO: el background no los mueve.
public struct VisitorsState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta la próxima visita del carril principal. `nil` =
    /// nunca se programó (partida nueva o save anterior a E4): el scheduler
    /// arranca en `firstVisitAfterSeconds`.
    public var secondsUntilVisit: Double?
    /// Ídem, el carril del Vendedor Ambulante.
    public var secondsUntilVendor: Double?
    /// Los últimos guiones que salieron, el más nuevo al final.
    public var recentScripts: [String]
    /// El día calendario ("yyyy-MM-dd") de los dos contadores de abajo.
    public var day: String?
    public var visitsToday: [String: Int]
    /// ORO que el del Arbolito ya te cambió hoy (tope diario del guion).
    public var oroExchangedToday: Int

    public static let initial = VisitorsState()

    public init(
        secondsUntilVisit: Double? = nil,
        secondsUntilVendor: Double? = nil,
        recentScripts: [String] = [],
        day: String? = nil,
        visitsToday: [String: Int] = [:],
        oroExchangedToday: Int = 0
    ) {
        self.secondsUntilVisit = secondsUntilVisit
        self.secondsUntilVendor = secondsUntilVendor
        self.recentScripts = recentScripts
        self.day = day
        self.visitsToday = visitsToday
        self.oroExchangedToday = oroExchangedToday
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilVisit = try container.decodeIfPresent(Double.self, forKey: .secondsUntilVisit)
        secondsUntilVendor = try container.decodeIfPresent(Double.self, forKey: .secondsUntilVendor)
        recentScripts = try container.decodeIfPresent([String].self, forKey: .recentScripts) ?? []
        day = try container.decodeIfPresent(String.self, forKey: .day)
        visitsToday = try container.decodeIfPresent([String: Int].self, forKey: .visitsToday) ?? [:]
        oroExchangedToday = try container.decodeIfPresent(Int.self, forKey: .oroExchangedToday) ?? 0
    }

    /// Los relojes viajan con el ganador. Los topes del día, si los dos saves
    /// hablan del mismo día, se quedan con lo más alto: dos dispositivos no
    /// duplican el cupo.
    public static func resolve(winner: VisitorsState, loser: VisitorsState) -> VisitorsState {
        guard winner.day != nil, winner.day == loser.day else { return winner }
        var resolved = winner
        resolved.visitsToday = winner.visitsToday.merging(loser.visitsToday, uniquingKeysWith: max)
        resolved.oroExchangedToday = max(winner.oroExchangedToday, loser.oroExchangedToday)
        return resolved
    }
}
