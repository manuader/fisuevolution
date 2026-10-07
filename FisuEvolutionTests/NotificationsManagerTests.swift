import EconomyKit
import Foundation
import Testing
import UserNotifications
@testable import FisuEvolution

/// El manager de la 2.0 (PLAN-v2 E11): la preferencia del jugador, el permiso de
/// iOS en dos pasos y la ausencia programada con el planificador.
///
/// ⚠️ Cada test arma su dominio de `UserDefaults` y su centro espía:
/// `UNUserNotificationCenter` no se puede fabricar ni preconfigurar, y un test
/// que escriba en `.standard` le deja al dueño las notificaciones apagadas.
@Suite("NotificationsManager")
@MainActor
struct NotificationsManagerTests {
    let config: NotificationsConfig
    let calendar: Calendar
    /// Lunes 5 de octubre de 2026, 10:00 en Buenos Aires: la caja a las 20, el
    /// diario el 6 a las 19 y el regreso el 8 a las 10. Nada en el silencio.
    let leaving: TimeInterval

    init() throws {
        config = try GameContentLoader.load(from: .main).notifications
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Argentina/Buenos_Aires"))
        self.calendar = calendar
        let components = DateComponents(year: 2026, month: 10, day: 5, hour: 10)
        leaving = try #require(calendar.date(from: components)).timeIntervalSince1970
    }

    private func snapshot(producesOffline: Bool = true) -> NotificationSnapshot {
        NotificationSnapshot(now: leaving, producesOffline: producesOffline, offlineCapHours: 10, dailyClaimedToday: true)
    }

    private func makeManager(
        _ spy: SpyNotificationCenter,
        _ scratch: SettingsPersistenceTests.ScratchDefaults,
        isLive: Bool = true
    ) -> NotificationsManager {
        NotificationsManager(center: spy, defaults: scratch.defaults, isLive: isLive)
    }

    private static let allIDs: Set<String> = ["fisu.notif.vault_full", "fisu.notif.daily_ready", "fisu.notif.comeback"]

    // MARK: La preferencia

    @Test("recién instalado: prendidas por defecto y sin preguntarle nada a iOS")
    func onByDefault() {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()

        let notifications = makeManager(spy, scratch)

        #expect(notifications.isEnabled)
        #expect(NotificationKind.allCases.allSatisfy { notifications.isEnabled(for: $0) })
        #expect(spy.requestedOptions == nil)
    }

    @Test("el false de la v1 se respeta: ni permiso ni avisos")
    func v1FalseIsRespected() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .notDetermined
        let notifications = makeManager(spy, scratch)

        await notifications.requestProvisional()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(notifications.isEnabled == false)
        #expect(spy.requestedOptions == nil)
        #expect(spy.pending.isEmpty)
    }

    @Test("un tipo apagado persiste y no se programa")
    func disabledKindPersistsAndIsSkipped() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        makeManager(spy, scratch).setEnabled(false, for: .comeback)

        let reopened = makeManager(spy, scratch)
        await reopened.refreshAuthorization()
        await reopened.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(reopened.isEnabled(for: .comeback) == false)
        #expect(Set(spy.pending.keys) == ["fisu.notif.vault_full", "fisu.notif.daily_ready"])
    }

    // MARK: El permiso en dos pasos

    @Test("al terminar el núcleo pide el provisional: sin diálogo")
    func provisionalAtCoreFinish() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .notDetermined
        let notifications = makeManager(spy, scratch)

        await notifications.requestProvisional()

        #expect(spy.requestedOptions == [.alert, .sound, .badge, .provisional])
        #expect(notifications.authorization == .provisional)
        #expect(notifications.canDeliver)
    }

    @Test("si iOS ya contestó, el provisional no se vuelve a pedir")
    func provisionalOnlyWhenUndetermined() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .authorized

        await makeManager(spy, scratch).requestProvisional()

        #expect(spy.requestedOptions == nil)
    }

    @Test("denegado: lo dice, no programa y no le toca la preferencia al jugador")
    func deniedIsReportedNotScheduled() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .denied
        let notifications = makeManager(spy, scratch)

        await notifications.refreshAuthorization()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(notifications.isDenied)
        #expect(notifications.isEnabled)
        #expect(spy.pending.isEmpty)
    }

    @Test("prender el maestro con iOS sin preguntar pide el permiso completo")
    func turningOnAsksForFullPermission() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .notDetermined
        let notifications = makeManager(spy, scratch)

        await notifications.setEnabled(true)

        #expect(notifications.isEnabled)
        #expect(scratch.defaults.bool(forKey: NotificationsManager.defaultsKey))
        #expect(spy.requestedOptions == [.alert, .sound, .badge])
    }

    @Test("prender el maestro con el provisional no muestra ningún diálogo")
    func turningOnWithProvisionalAsksNothing() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .provisional

        await makeManager(spy, scratch).setEnabled(true)

        #expect(spy.requestedOptions == nil)
    }

    @Test("un error del sistema no cambia ni la preferencia ni el permiso")
    func systemErrorChangesNothing() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.authorizationError = SpyError.nope
        let notifications = makeManager(spy, scratch)

        await notifications.setEnabled(true)

        #expect(notifications.isEnabled)
        #expect(notifications.authorization == .notDetermined)
    }

    // MARK: La ausencia

    @Test("programar la ausencia arma los avisos del planificador, con su texto")
    func schedulingBuildsThePlannedRequests() async throws {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(Set(spy.pending.keys) == Self.allIDs)
        let vault = try #require(spy.pending["fisu.notif.vault_full"])
        let trigger = try #require(vault.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 10 * 3600)
        #expect(trigger.repeats == false)
        // El texto sale del catálogo: una clave mal escrita llegaría cruda al teléfono.
        for request in spy.pending.values {
            #expect(!request.content.title.isEmpty && !request.content.title.hasPrefix("notif."))
            #expect(!request.content.body.isEmpty && !request.content.body.hasPrefix("notif."))
        }
    }

    @Test("sin pasivo, la caja fuerte no se avisa")
    func noPassiveNoVault() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.scheduleAbsence(snapshot(producesOffline: false), config: config, calendar: calendar)

        #expect(spy.pending["fisu.notif.vault_full"] == nil)
    }

    @Test("programar borra lo de antes, también el recordatorio fijo de la v1")
    func schedulingReplacesTheV1Reminder() async throws {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        try await spy.add(UNNotificationRequest(identifier: "fisu.daily.reminder", content: UNMutableNotificationContent(), trigger: nil))
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(spy.pending["fisu.daily.reminder"] == nil)
        #expect(Set(spy.pending.keys) == Self.allIDs)
    }

    @Test("apagar el maestro borra todo lo pendiente")
    func turningOffClearsPending() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)
        #expect(!spy.pending.isEmpty)

        await notifications.setEnabled(false)

        #expect(spy.pending.isEmpty)
        #expect(scratch.defaults.object(forKey: NotificationsManager.defaultsKey) as? Bool == false)
    }

    @Test("volver a la app borra lo pendiente y lo entregado")
    func returningClearsEverything() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        await notifications.appBecameActive()

        #expect(spy.pending.isEmpty)
        #expect(spy.removeDeliveredCount == 1)
    }

    /// ⚠️ Programar tiene un `await` por aviso. Si el jugador vuelve en el medio,
    /// gana la vuelta: un aviso que entra en la cola después sonaría con el
    /// jugador adentro.
    @Test("volver mientras se programaba la ausencia gana: no queda nada pendiente")
    func returningDuringSchedulingWins() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        spy.beforeAdding = { notifications.cancelAbsence() }

        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(spy.pending.isEmpty, "quedó programado un aviso de una ausencia que ya terminó")
    }

    // MARK: Fuera del juego de verdad

    @Test("sin permiso de hablar con el sistema, sólo guarda la preferencia")
    func notLiveNeverTouchesTheSystem() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let notifications = makeManager(spy, scratch, isLive: false)

        await notifications.requestProvisional()
        await notifications.setEnabled(false)
        await notifications.setEnabled(true)
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)
        await notifications.appBecameActive()

        #expect(spy.requestedOptions == nil)
        #expect(spy.removeAllCount == 0)
        #expect(spy.pending.isEmpty)
        #expect(notifications.isEnabled)
        #expect(scratch.defaults.bool(forKey: NotificationsManager.defaultsKey))
    }

    @Test("bajo XCTest o --uitest no se habla con iOS, salvo que el test lo pida")
    func launchGate() {
        #expect(NotificationsManager.launchAllowsSystem(arguments: [], environment: [:]))
        #expect(!NotificationsManager.launchAllowsSystem(arguments: ["--uitest-reset"], environment: [:]))
        #expect(!NotificationsManager.launchAllowsSystem(arguments: [], environment: ["XCTestConfigurationFilePath": "/x"]))
        #expect(NotificationsManager.uiTestStatus(in: ["--uitest-notifications-provisional"]) == .provisional)
        #expect(NotificationsManager.uiTestStatus(in: ["--uitest-notifications-denied"]) == .denied)
        #expect(NotificationsManager.uiTestStatus(in: ["--uitest-reset"]) == nil)
    }

    @Test("--uitest-reset borra todas las claves de notificaciones")
    func wipeClearsEveryKey() {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let keys = [
            "settings.notificationsEnabled", "settings.notificationsEnabled.vault_full",
            "settings.notificationsEnabled.daily_ready", "settings.notificationsEnabled.comeback",
            "notifications.card.offers", "notifications.card.lastOfferAt", "notifications.card.accepted",
        ]
        for key in keys { scratch.defaults.set(false, forKey: key) }

        NotificationsManager.wipePreferences(in: scratch.defaults)

        for key in keys { #expect(scratch.stored[key] == nil, "\(key) sobrevivió al reset") }
    }

    // MARK: La tarjeta del permiso

    @Test("con el provisional, la tarjeta se ofrece una vez y otra a los 3 días; nunca una tercera")
    func permissionCardSchedule() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        let card = config.permissionCard
        let retry = leaving + card.retryAfterHours * 3600

        #expect(notifications.permissionCardDue(now: leaving, config: card))
        notifications.recordPermissionCardOffer(now: leaving)
        #expect(!notifications.permissionCardDue(now: leaving + 3600, config: card))
        #expect(notifications.permissionCardDue(now: retry, config: card))
        notifications.recordPermissionCardOffer(now: retry)
        #expect(!notifications.permissionCardDue(now: retry + 1000 * 3600, config: card))
    }

    @Test("la tarjeta no se ofrece con el permiso completo, con iOS denegado ni con el maestro apagado")
    func permissionCardNeedsSomethingToUpgrade() async {
        for status in [UNAuthorizationStatus.authorized, .denied] {
            let scratch = SettingsPersistenceTests.ScratchDefaults()
            defer { scratch.clear() }
            let spy = SpyNotificationCenter()
            spy.status = status
            let notifications = makeManager(spy, scratch)
            await notifications.refreshAuthorization()
            #expect(!notifications.permissionCardDue(now: leaving, config: config.permissionCard), "status \(status.rawValue)")
        }
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        #expect(!notifications.permissionCardDue(now: leaving, config: config.permissionCard))
    }

    @Test("«Sí, avisame» abre el diálogo del sistema y la tarjeta no vuelve")
    func acceptingAsksAndRetires() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.acceptPermissionCard()

        #expect(spy.requestedOptions == [.alert, .sound, .badge])
        #expect(notifications.authorization == .authorized)
        // Aunque iOS volviera al provisional, la tarjeta ya cumplió.
        spy.status = .provisional
        await notifications.refreshAuthorization()
        #expect(!notifications.permissionCardDue(now: leaving + 1000 * 3600, config: config.permissionCard))
    }

    // MARK: Andamio

    enum SpyError: Error { case nope }

    /// El centro de notificaciones, de mentira. Modela lo que importa del de
    /// verdad: `add` **reemplaza** por identifier (por eso es un diccionario), el
    /// permiso puede negarse o fallar, y el provisional se concede sin diálogo.
    @MainActor
    final class SpyNotificationCenter: NotificationScheduling {
        var granted = true
        var authorizationError: Error?
        var status: UNAuthorizationStatus = .notDetermined
        /// Se ejecuta adentro del pedido de permiso, antes de contestar.
        var beforeAnswering: (() -> Void)?
        /// Se ejecuta adentro de `add`, antes de guardar: el hueco donde el
        /// jugador vuelve a la app mientras se programa la ausencia.
        var beforeAdding: (() -> Void)?
        private(set) var requestedOptions: UNAuthorizationOptions?
        private(set) var pending: [String: UNNotificationRequest] = [:]
        private(set) var removeAllCount = 0
        private(set) var removeDeliveredCount = 0

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requestedOptions = options
            beforeAnswering?()
            if let authorizationError { throw authorizationError }
            if granted {
                status = options.contains(.provisional) ? .provisional : .authorized
            } else {
                status = .denied
            }
            return granted
        }

        func add(_ request: UNNotificationRequest) async throws {
            beforeAdding?()
            pending[request.identifier] = request
        }

        func removeAllPendingNotificationRequests() {
            removeAllCount += 1
            pending.removeAll()
        }

        func removeAllDeliveredNotifications() {
            removeDeliveredCount += 1
        }

        func authorizationStatus() async -> UNAuthorizationStatus { status }
    }
}
