import Foundation

/// Quien espera en un piso que no se está mirando (E14b B7, D6): congelado con
/// la paciencia que le quedaba. Vuelve a la escena cuando se vuelve a su piso.
public struct FloorVisitor: Codable, Sendable, Equatable {
    public var floorOrdinal: Int
    public var visitorId: String
    public var scriptId: String
    public var patienceLeft: Double

    public init(floorOrdinal: Int, visitorId: String, scriptId: String, patienceLeft: Double) {
        self.floorOrdinal = floorOrdinal
        self.visitorId = visitorId
        self.scriptId = scriptId
        self.patienceLeft = patienceLeft
    }
}

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
    /// Blue que el del Arbolito ya te cambió hoy (tope diario del guion).
    public var blueExchangedToday: Int
    /// Los que esperan en los pisos que no se miran, uno por piso (E14b B7).
    /// Ningún reloj los toca: sólo `VisitorScheduler.park`/`resume`.
    public var waiting: [FloorVisitor]
    /// La semana calendario ISO ("2026-W42") del cupo semanal (E14b B25).
    public var week: String?
    public var visitsThisWeek: [String: Int]
    /// Cuántas sesiones (arranques de la app) vio la partida: un guion con cupo semanal no sale en
    /// la primera (E14b B25).
    public var sessions: Int
    /// La Marcha en curso o resuelta y sin cobrar (E14b B25). Vive en el save con su reloj de pared.
    public var march: MarchState?
    /// El inicio de la última Marcha cobrada (E14b B25). Con dos dispositivos, la Marcha que ya se
    /// cobró en uno no se vuelve a pagar en el otro: `resolve` la descarta.
    public var lastSettledMarchStartedAt: Double?

    public static let initial = VisitorsState()

    public init(
        secondsUntilVisit: Double? = nil,
        visitorBag: [String] = [],
        lastVisitor: String? = nil,
        lastScriptByVisitor: [String: String] = [:],
        day: String? = nil,
        visitsToday: [String: Int] = [:],
        blueExchangedToday: Int = 0,
        waiting: [FloorVisitor] = [],
        week: String? = nil,
        visitsThisWeek: [String: Int] = [:],
        sessions: Int = 0,
        march: MarchState? = nil,
        lastSettledMarchStartedAt: Double? = nil
    ) {
        self.secondsUntilVisit = secondsUntilVisit
        self.visitorBag = visitorBag
        self.lastVisitor = lastVisitor
        self.lastScriptByVisitor = lastScriptByVisitor
        self.day = day
        self.visitsToday = visitsToday
        self.blueExchangedToday = blueExchangedToday
        self.waiting = waiting
        self.week = week
        self.visitsThisWeek = visitsThisWeek
        self.sessions = sessions
        self.march = march
        self.lastSettledMarchStartedAt = lastSettledMarchStartedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilVisit = try container.decodeIfPresent(Double.self, forKey: .secondsUntilVisit)
        visitorBag = try container.decodeIfPresent([String].self, forKey: .visitorBag) ?? []
        lastVisitor = try container.decodeIfPresent(String.self, forKey: .lastVisitor)
        lastScriptByVisitor = try container.decodeIfPresent([String: String].self, forKey: .lastScriptByVisitor) ?? [:]
        day = try container.decodeIfPresent(String.self, forKey: .day)
        visitsToday = try container.decodeIfPresent([String: Int].self, forKey: .visitsToday) ?? [:]
        blueExchangedToday = try container.decodeIfPresent(Int.self, forKey: .blueExchangedToday)
            ?? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(Int.self, forKey: .blueExchangedToday) ?? 0
        waiting = try container.decodeIfPresent([FloorVisitor].self, forKey: .waiting) ?? []
        week = try container.decodeIfPresent(String.self, forKey: .week)
        visitsThisWeek = try container.decodeIfPresent([String: Int].self, forKey: .visitsThisWeek) ?? [:]
        sessions = try container.decodeIfPresent(Int.self, forKey: .sessions) ?? 0
        march = try container.decodeIfPresent(MarchState.self, forKey: .march)
        lastSettledMarchStartedAt = try container.decodeIfPresent(Double.self, forKey: .lastSettledMarchStartedAt)
    }

    /// El reloj, la bolsa, los que esperan en cada piso y la Marcha viajan con el ganador. Los topes del
    /// día y de la semana, si los dos saves hablan del mismo día o de la misma semana, se quedan con lo
    /// más alto: dos dispositivos no duplican el cupo. Las sesiones, también lo más alto. La Marcha que
    /// cualquiera de los dos ya cobró no viaja: el blue del perdedor ya trae ese premio.
    public static func resolve(winner: VisitorsState, loser: VisitorsState) -> VisitorsState {
        var resolved = winner
        resolved.sessions = max(winner.sessions, loser.sessions)
        resolved.lastSettledMarchStartedAt = [winner.lastSettledMarchStartedAt, loser.lastSettledMarchStartedAt]
            .compactMap { $0 }.max()
        if let march = resolved.march, let lastSettled = resolved.lastSettledMarchStartedAt,
           march.startedAt <= lastSettled {
            resolved.march = nil
        }
        if winner.week != nil, winner.week == loser.week {
            resolved.visitsThisWeek = winner.visitsThisWeek.merging(loser.visitsThisWeek, uniquingKeysWith: max)
        }
        guard winner.day != nil, winner.day == loser.day else { return resolved }
        resolved.visitsToday = winner.visitsToday.merging(loser.visitsToday, uniquingKeysWith: max)
        resolved.blueExchangedToday = max(winner.blueExchangedToday, loser.blueExchangedToday)
        return resolved
    }

    /// La clave con que se guardaba hasta E14b B14 (ver `MetaState.LegacyKeys`). Sólo se lee.
    private enum LegacyKeys: String, CodingKey {
        case blueExchangedToday = "oroExchangedToday"
    }
}
