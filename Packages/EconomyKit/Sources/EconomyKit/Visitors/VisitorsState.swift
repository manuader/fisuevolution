import Foundation

/// Lo que se recuerda de los visitantes entre partidas (PLAN-v2 E4). El reloj
/// es de JUEGO ACTIVO: el background no lo mueve.
///
/// La bolsa (E14 C5) entró sin subir el schema del save: todo campo nuevo es
/// opcional al leer. Un save de antes trae el reloj del vendedor y los guiones
/// recientes del carril viejo; se ignoran, y la bolsa arranca vacía (se baraja
/// en la próxima visita).
public struct VisitorsState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta la próxima visita. `nil` = nunca se programó
    /// (partida nueva o save anterior a E4): el scheduler arranca en
    /// `firstVisitAfterSeconds`.
    public var secondsUntilVisit: Double?
    /// Los visitantes que faltan en esta vuelta, el próximo primero.
    public var visitorBag: [String]
    /// El último que entró: no repite en el borde de la bolsa.
    public var lastVisitor: String?
    /// El último guion de cada visitante: sus guiones se alternan.
    public var lastScriptByVisitor: [String: String]
    /// El día calendario ("yyyy-MM-dd") de los dos contadores de abajo.
    public var day: String?
    public var visitsToday: [String: Int]
    /// ORO que el del Arbolito ya te cambió hoy (tope diario del guion).
    public var oroExchangedToday: Int

    public static let initial = VisitorsState()

    public init(
        secondsUntilVisit: Double? = nil,
        visitorBag: [String] = [],
        lastVisitor: String? = nil,
        lastScriptByVisitor: [String: String] = [:],
        day: String? = nil,
        visitsToday: [String: Int] = [:],
        oroExchangedToday: Int = 0
    ) {
        self.secondsUntilVisit = secondsUntilVisit
        self.visitorBag = visitorBag
        self.lastVisitor = lastVisitor
        self.lastScriptByVisitor = lastScriptByVisitor
        self.day = day
        self.visitsToday = visitsToday
        self.oroExchangedToday = oroExchangedToday
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilVisit = try container.decodeIfPresent(Double.self, forKey: .secondsUntilVisit)
        visitorBag = try container.decodeIfPresent([String].self, forKey: .visitorBag) ?? []
        lastVisitor = try container.decodeIfPresent(String.self, forKey: .lastVisitor)
        lastScriptByVisitor = try container.decodeIfPresent([String: String].self, forKey: .lastScriptByVisitor) ?? [:]
        day = try container.decodeIfPresent(String.self, forKey: .day)
        visitsToday = try container.decodeIfPresent([String: Int].self, forKey: .visitsToday) ?? [:]
        oroExchangedToday = try container.decodeIfPresent(Int.self, forKey: .oroExchangedToday) ?? 0
    }

    /// El reloj y la bolsa viajan con el ganador. Los topes del día, si los dos
    /// saves hablan del mismo día, se quedan con lo más alto: dos dispositivos no
    /// duplican el cupo.
    public static func resolve(winner: VisitorsState, loser: VisitorsState) -> VisitorsState {
        guard winner.day != nil, winner.day == loser.day else { return winner }
        var resolved = winner
        resolved.visitsToday = winner.visitsToday.merging(loser.visitsToday, uniquingKeysWith: max)
        resolved.oroExchangedToday = max(winner.oroExchangedToday, loser.oroExchangedToday)
        return resolved
    }
}
