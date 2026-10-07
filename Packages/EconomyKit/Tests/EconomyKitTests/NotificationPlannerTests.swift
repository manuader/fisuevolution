import Foundation
import Testing
@testable import EconomyKit

/// El catálogo con las reglas de PLAN-v2 E11: silencio de 22 a 9, 4 h entre
/// avisos, 3 por ausencia, el diario a las 19 y el regreso a las 72 h.
func fxNotifications(
    ids: [String] = NotificationKind.allCases.map(\.rawValue),
    quietStart: Int = 22,
    quietEnd: Int = 9,
    minSpacingHours: Double = 4,
    maxPerAbsence: Int = 3,
    dailyReadyHour: Int = 19,
    comebackAfterHours: Double = 72
) -> NotificationsConfig {
    NotificationsConfig(
        schemaVersion: 1,
        notifications: ids.map(NotificationsConfig.Entry.init(id:)),
        quietHours: NotificationsConfig.QuietHours(startHour: quietStart, endHour: quietEnd),
        minSpacingHours: minSpacingHours,
        maxPerAbsence: maxPerAbsence,
        dailyReadyHour: dailyReadyHour,
        comebackAfterHours: comebackAfterHours,
        permissionCard: NotificationsConfig.PermissionCard(maxOffers: 2, retryAfterHours: 72)
    )
}

/// Octubre de 2026 en Buenos Aires: sin horario de verano, una hora es una hora.
private struct BuenosAires {
    let calendar: Calendar

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Argentina/Buenos_Aires"))
        self.calendar = calendar
    }

    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> TimeInterval {
        let components = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components)).timeIntervalSince1970
    }

    func hour(of time: TimeInterval) -> Int {
        calendar.component(.hour, from: Date(timeIntervalSince1970: time))
    }
}

@Suite("Notificaciones: el planificador de la ausencia")
struct NotificationPlannerTests {
    private let ba: BuenosAires

    init() throws {
        ba = try BuenosAires()
    }

    private func plan(
        leavingAt now: TimeInterval,
        producesOffline: Bool = true,
        capHours: Double = 10,
        dailyClaimedToday: Bool = true,
        config: NotificationsConfig = fxNotifications(),
        preferences: NotificationPreferences = NotificationPreferences()
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(
            NotificationSnapshot(
                now: now,
                producesOffline: producesOffline,
                offlineCapHours: capHours,
                dailyClaimedToday: dailyClaimedToday
            ),
            config: config,
            preferences: preferences,
            calendar: ba.calendar
        )
    }

    private func fireAt(_ kind: NotificationKind, in planned: [PlannedNotification]) -> TimeInterval? {
        planned.first { $0.kind == kind }?.fireAt
    }

    // MARK: Cada motivo

    @Test("la caja fuerte avisa cuando se llena: al irse más el tope offline")
    func vaultFullAtTheOfflineCap() throws {
        let leaving = try ba.at(5, 8)
        let full = try ba.at(5, 18)
        #expect(fireAt(.vaultFull, in: plan(leavingAt: leaving, capHours: 10)) == full)
    }

    @Test("sin pasivo no hay caja fuerte que se llene")
    func noPassiveNoVault() throws {
        let planned = plan(leavingAt: try ba.at(5, 8), producesOffline: false)
        #expect(fireAt(.vaultFull, in: planned) == nil)
    }

    @Test("el diario cobrado hoy avisa mañana a las 19")
    func dailyClaimedTodayAnnouncesTomorrow() throws {
        let tomorrow = try ba.at(6, 19)
        let planned = plan(leavingAt: try ba.at(5, 10), dailyClaimedToday: true)
        #expect(fireAt(.dailyReady, in: planned) == tomorrow)
    }

    @Test("el diario sin cobrar avisa hoy a las 19, o mañana si ya pasó la hora")
    func dailyUnclaimed() throws {
        let today = try ba.at(5, 19)
        let tomorrow = try ba.at(6, 19)
        #expect(fireAt(.dailyReady, in: plan(leavingAt: try ba.at(5, 10), dailyClaimedToday: false)) == today)
        #expect(fireAt(.dailyReady, in: plan(leavingAt: try ba.at(5, 20), dailyClaimedToday: false)) == tomorrow)
    }

    @Test("el regreso: 72 h después de irse, una sola vez por ausencia")
    func comebackAfterThreeDays() throws {
        let threeDaysLater = try ba.at(8, 10)
        let planned = plan(leavingAt: try ba.at(5, 10))
        #expect(fireAt(.comeback, in: planned) == threeDaysLater)
        #expect(planned.filter { $0.kind == .comeback }.count == 1)
    }

    // MARK: El horario silencioso

    @Test("lo que cae en el horario silencioso se corre a las 9")
    func quietHoursShiftToNine() throws {
        // 14 h + 10 h = medianoche, adentro del silencio.
        let nine = try ba.at(6, 9)
        #expect(fireAt(.vaultFull, in: plan(leavingAt: try ba.at(5, 14), capHours: 10)) == nine)
    }

    @Test("los bordes del silencio: 21:59 y 9:00 suenan; 22:00 y 8:59 se corren")
    func quietHoursBoundaries() throws {
        let config = fxNotifications()
        let beforeQuiet = try ba.at(5, 21, 59)
        let quietStarts = try ba.at(5, 22)
        let almostNine = try ba.at(5, 8, 59)
        let nine = try ba.at(5, 9)
        let nextNine = try ba.at(6, 9)
        #expect(NotificationPlanner.outsideQuietHours(beforeQuiet, config: config, calendar: ba.calendar) == beforeQuiet)
        #expect(NotificationPlanner.outsideQuietHours(nine, config: config, calendar: ba.calendar) == nine)
        #expect(NotificationPlanner.outsideQuietHours(quietStarts, config: config, calendar: ba.calendar) == nextNine)
        #expect(NotificationPlanner.outsideQuietHours(almostNine, config: config, calendar: ba.calendar) == nine)
    }

    // MARK: Espaciado y tope

    @Test("dos avisos quedan a 4 h o más: el segundo se corre, no se pierde")
    func spacingPushesTheLaterOne() throws {
        // 5 h + 12 h = la caja a las 17; el diario sin cobrar a las 19 queda a 2 h y pasa a las 21.
        let vault = try ba.at(5, 17)
        let daily = try ba.at(5, 21)
        let planned = plan(leavingAt: try ba.at(5, 5), capHours: 12, dailyClaimedToday: false)
        #expect(fireAt(.vaultFull, in: planned) == vault)
        #expect(fireAt(.dailyReady, in: planned) == daily)
    }

    @Test("si correrlo lo mete en el silencio, sale a las 9 del día siguiente")
    func spacingIntoQuietHours() throws {
        // La caja y el diario empatan a las 19: gana la prioridad del catálogo y
        // el diario pasa a las 23, adentro del silencio → las 9 del 6.
        let vault = try ba.at(5, 19)
        let daily = try ba.at(6, 9)
        let planned = plan(leavingAt: try ba.at(5, 5), capHours: 14, dailyClaimedToday: false)
        #expect(fireAt(.vaultFull, in: planned) == vault)
        #expect(fireAt(.dailyReady, in: planned) == daily)
    }

    @Test("el tope por ausencia se aplica por prioridad, no por orden de llegada")
    func capKeepsTheMostImportant() throws {
        let leaving = try ba.at(5, 10)
        #expect(plan(leavingAt: leaving).count == 3)
        let capped = plan(leavingAt: leaving, config: fxNotifications(maxPerAbsence: 2))
        #expect(capped.map(\.kind) == [.vaultFull, .dailyReady])
        let comebackFirst = plan(
            leavingAt: leaving,
            config: fxNotifications(ids: ["comeback", "vault_full", "daily_ready"], maxPerAbsence: 2)
        )
        #expect(comebackFirst.map(\.kind) == [.vaultFull, .comeback])
    }

    // MARK: Ajustes

    @Test("un tipo apagado en Ajustes no se programa")
    func disabledKindIsSkipped() throws {
        let planned = plan(
            leavingAt: try ba.at(5, 10),
            preferences: NotificationPreferences(disabledKinds: [.vaultFull])
        )
        #expect(planned.map(\.kind) == [.dailyReady, .comeback])
    }

    @Test("con el maestro apagado no se programa nada")
    func masterOffSchedulesNothing() throws {
        let planned = plan(leavingAt: try ba.at(5, 10), preferences: NotificationPreferences(masterEnabled: false))
        #expect(planned.isEmpty)
    }

    // MARK: Las reglas, a cualquier hora

    @Test("a cualquier hora que te vayas: nada en el silencio, nada pegado, nunca más de 3",
          arguments: 0..<24)
    func invariantsAtEveryHour(hour: Int) throws {
        let config = fxNotifications()
        let leaving = try ba.at(5, hour)
        let planned = plan(leavingAt: leaving, dailyClaimedToday: hour.isMultiple(of: 2))
        #expect(planned.count <= config.maxPerAbsence)
        for (earlier, later) in zip(planned, planned.dropFirst()) {
            #expect(later.fireAt - earlier.fireAt >= config.minSpacingHours * 3600)
        }
        for notice in planned {
            #expect(notice.fireAt > leaving)
            #expect(!config.quietHours.contains(hour: ba.hour(of: notice.fireAt)),
                    "\(notice.kind.rawValue) suena a las \(ba.hour(of: notice.fireAt))")
        }
    }
}

@Suite("Notificaciones: el validador del catálogo")
struct NotificationsConfigTests {
    private let allIDs = NotificationKind.allCases.map(\.rawValue)

    @Test("el catálogo con las reglas de PLAN-v2 es válido")
    func validCatalog() throws {
        try fxNotifications().validate()
    }

    @Test("un id repetido no pasa")
    func duplicateID() {
        let config = fxNotifications(ids: allIDs + ["comeback"])
        #expect(throws: NotificationsConfig.ValidationError.duplicateID("comeback")) { try config.validate() }
    }

    @Test("un id que no es un motivo conocido no pasa")
    func unknownID() {
        let config = fxNotifications(ids: allIDs + ["pizza_ready"])
        #expect(throws: NotificationsConfig.ValidationError.unknownID("pizza_ready")) { try config.validate() }
    }

    @Test("un motivo sin entrada no pasa: nunca sonaría")
    func missingKind() {
        let config = fxNotifications(ids: allIDs.filter { $0 != "comeback" })
        #expect(throws: NotificationsConfig.ValidationError.missingKind(.comeback)) { try config.validate() }
    }

    @Test("las horas van de 0 a 23")
    func hoursInRange() {
        #expect(throws: NotificationsConfig.ValidationError.hourOutOfRange(field: "quietHours.startHour", hour: 24)) {
            try fxNotifications(quietStart: 24).validate()
        }
    }

    @Test("el diario no puede caer adentro del silencio")
    func dailyOutsideQuietHours() {
        #expect(throws: NotificationsConfig.ValidationError.dailyHourIsQuiet(23)) {
            try fxNotifications(dailyReadyHour: 23).validate()
        }
    }

    @Test("el espaciado y el tope son positivos")
    func positiveAmounts() {
        #expect(throws: NotificationsConfig.ValidationError.notPositive(field: "minSpacingHours")) {
            try fxNotifications(minSpacingHours: 0).validate()
        }
        #expect(throws: NotificationsConfig.ValidationError.notPositive(field: "maxPerAbsence")) {
            try fxNotifications(maxPerAbsence: 0).validate()
        }
    }

    @Test("el silencio cruza la medianoche")
    func quietHoursWrapMidnight() {
        let quiet = NotificationsConfig.QuietHours(startHour: 22, endHour: 9)
        #expect(quiet.contains(hour: 22) && quiet.contains(hour: 0) && quiet.contains(hour: 8))
        #expect(!quiet.contains(hour: 9) && !quiet.contains(hour: 21))
    }
}

@Suite("Notificaciones: cuándo se ofrece la tarjeta del permiso")
struct PermissionCardPolicyTests {
    private let card = NotificationsConfig.PermissionCard(maxOffers: 2, retryAfterHours: 72)

    @Test("la primera vez se ofrece")
    func firstOffer() {
        #expect(PermissionCardPolicy.isDue(offersMade: 0, lastOfferAt: nil, now: 1000, config: card))
    }

    @Test("una sola vez más, a los 3 días")
    func secondOfferAfterThreeDays() {
        #expect(!PermissionCardPolicy.isDue(offersMade: 1, lastOfferAt: 1000, now: 1000 + 72 * 3600 - 1, config: card))
        #expect(PermissionCardPolicy.isDue(offersMade: 1, lastOfferAt: 1000, now: 1000 + 72 * 3600, config: card))
    }

    @Test("nunca una tercera")
    func neverAThird() {
        #expect(!PermissionCardPolicy.isDue(offersMade: 2, lastOfferAt: 1000, now: 1000 + 1000 * 3600, config: card))
    }
}
