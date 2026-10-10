import Foundation

/// Lo que el planificador necesita saber de la partida al irse, ya resuelto por
/// la app: EconomyKit no conoce `UserDefaults`, ni el centro de notificaciones,
/// ni la hora del sistema.
public struct NotificationSnapshot: Sendable, Equatable {
    /// Cuándo se fue el jugador (epoch).
    public var now: TimeInterval
    /// La torre produce afuera: sin pasivo no hay caja fuerte que se llene.
    public var producesOffline: Bool
    public var offlineCapHours: Double
    /// El diario de hoy ya se cobró (al volver se cobra solo).
    public var dailyClaimedToday: Bool
    /// Cuándo vuelve a haber giros de la ruleta (E5), o `nil` si no hay por qué avisar.
    public var wheelSpinsReadyAt: TimeInterval?

    public init(
        now: TimeInterval,
        producesOffline: Bool,
        offlineCapHours: Double,
        dailyClaimedToday: Bool,
        wheelSpinsReadyAt: TimeInterval? = nil
    ) {
        self.now = now
        self.producesOffline = producesOffline
        self.offlineCapHours = offlineCapHours
        self.dailyClaimedToday = dailyClaimedToday
        self.wheelSpinsReadyAt = wheelSpinsReadyAt
    }
}

/// Lo que el jugador eligió en Ajustes.
public struct NotificationPreferences: Sendable, Equatable {
    public var masterEnabled: Bool
    public var disabledKinds: Set<NotificationKind>

    public init(masterEnabled: Bool = true, disabledKinds: Set<NotificationKind> = []) {
        self.masterEnabled = masterEnabled
        self.disabledKinds = disabledKinds
    }

    public func allows(_ kind: NotificationKind) -> Bool {
        masterEnabled && !disabledKinds.contains(kind)
    }
}

/// Un aviso con su hora (epoch).
public struct PlannedNotification: Sendable, Equatable {
    public let kind: NotificationKind
    public let fireAt: TimeInterval

    public init(kind: NotificationKind, fireAt: TimeInterval) {
        self.kind = kind
        self.fireAt = fireAt
    }
}

/// Qué se avisa y cuándo durante una ausencia (PLAN-v2 E11).
///
/// 1. Cada motivo propone su hora (`moments`).
/// 2. El maestro o el tipo apagados lo sacan.
/// 3. El tope por ausencia elige por **prioridad** (el orden del catálogo): con
///    más motivos que lugares, se queda el más importante, no el más temprano.
/// 4. Lo que cae en el horario silencioso se corre a su final.
/// 5. Dos avisos quedan a `minSpacingHours` o más: el segundo **se corre**, no se
///    descarta, porque todo motivo sigue siendo cierto hasta que el jugador vuelve.
public enum NotificationPlanner {
    public static func plan(
        _ snapshot: NotificationSnapshot,
        config: NotificationsConfig,
        preferences: NotificationPreferences,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard preferences.masterEnabled else { return [] }
        let priority = config.kinds
        let rank: (NotificationKind) -> Int = { priority.firstIndex(of: $0) ?? priority.count }
        let candidates = moments(for: snapshot, config: config, calendar: calendar).filter {
            priority.contains($0.kind) && preferences.allows($0.kind) && $0.fireAt > snapshot.now
        }
        let kept = candidates
            .sorted { rank($0.kind) < rank($1.kind) }
            .prefix(max(0, config.maxPerAbsence))
        let shifted = kept.map {
            PlannedNotification(kind: $0.kind, fireAt: outsideQuietHours($0.fireAt, config: config, calendar: calendar))
        }
        let ordered = shifted.sorted { ($0.fireAt, rank($0.kind)) < ($1.fireAt, rank($1.kind)) }
        let spacing = config.minSpacingHours * 3600
        var planned: [PlannedNotification] = []
        for moment in ordered {
            let earliest = planned.last.map { max(moment.fireAt, $0.fireAt + spacing) } ?? moment.fireAt
            planned.append(PlannedNotification(
                kind: moment.kind,
                fireAt: outsideQuietHours(earliest, config: config, calendar: calendar)
            ))
        }
        return planned
    }

    /// La hora que propone cada motivo, antes de las reglas.
    public static func moments(
        for snapshot: NotificationSnapshot,
        config: NotificationsConfig,
        calendar: Calendar
    ) -> [PlannedNotification] {
        var moments: [PlannedNotification] = []
        if snapshot.producesOffline {
            moments.append(PlannedNotification(
                kind: .vaultFull,
                fireAt: snapshot.now + snapshot.offlineCapHours * 3600
            ))
        }
        if let daily = nextDailyReady(snapshot, hour: config.dailyReadyHour, calendar: calendar) {
            moments.append(PlannedNotification(kind: .dailyReady, fireAt: daily))
        }
        moments.append(PlannedNotification(
            kind: .comeback,
            fireAt: snapshot.now + config.comebackAfterHours * 3600
        ))
        if let wheel = snapshot.wheelSpinsReadyAt {
            moments.append(PlannedNotification(kind: .wheelReady, fireAt: wheel))
        }
        return moments
    }

    /// La hora del diario del primer día sin cobrar: hoy si todavía no se cobró
    /// y no pasó la hora; si no, mañana.
    static func nextDailyReady(_ snapshot: NotificationSnapshot, hour: Int, calendar: Calendar) -> TimeInterval? {
        let now = Date(timeIntervalSince1970: snapshot.now)
        let today = calendar.startOfDay(for: now)
        guard let day = calendar.date(byAdding: .day, value: snapshot.dailyClaimedToday ? 1 : 0, to: today),
              let sameDay = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        else { return nil }
        guard sameDay <= now else { return sameDay.timeIntervalSince1970 }
        return calendar.date(byAdding: .day, value: 1, to: sameDay)?.timeIntervalSince1970
    }

    /// `time`, corrido al final del horario silencioso si cae adentro.
    public static func outsideQuietHours(
        _ time: TimeInterval,
        config: NotificationsConfig,
        calendar: Calendar
    ) -> TimeInterval {
        let date = Date(timeIntervalSince1970: time)
        guard config.quietHours.contains(hour: calendar.component(.hour, from: date)),
              let end = calendar.nextDate(
                  after: date,
                  matching: DateComponents(hour: config.quietHours.endHour, minute: 0, second: 0),
                  matchingPolicy: .nextTime
              )
        else { return time }
        return end.timeIntervalSince1970
    }
}

/// Cuándo se ofrece la tarjeta del permiso completo: la primera vez que toca y
/// una sola vez más, pasado `retryAfterHours`.
public enum PermissionCardPolicy {
    public static func isDue(
        offersMade: Int,
        lastOfferAt: TimeInterval?,
        now: TimeInterval,
        config: NotificationsConfig.PermissionCard
    ) -> Bool {
        guard offersMade < config.maxOffers else { return false }
        guard offersMade > 0 else { return true }
        guard let lastOfferAt else { return false }
        return now - lastOfferAt >= config.retryAfterHours * 3600
    }
}
