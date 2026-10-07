import EconomyKit
import Foundation
import Observation
import UserNotifications

/// Lo que este manager le pide al sistema de notificaciones. Existe para que los
/// tests puedan ejercer el camino completo —conceder, negar, fallar, apagar— sin
/// el diálogo del sistema, que en un test es un muro: `UNUserNotificationCenter`
/// no se puede fabricar ni preconfigurar.
///
/// Es `@MainActor` como el manager que lo usa; `UNUserNotificationCenter` lo
/// satisface tal cual, salvo el estado del permiso, que en el SDK viaja adentro
/// de `notificationSettings()`.
@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    /// ⚠️ `sending` no es adorno: `UNNotificationRequest` **no es `Sendable`** y
    /// el método real de `UNUserNotificationCenter` es `nonisolated`, así que la
    /// petición cruza del main actor al ejecutor genérico. Marcarla como enviada
    /// es lo que le dice al compilador que el que la crea se desprende de ella
    /// —cosa que es cierta: se arma en `request(for:in:)` y nadie más la toca—.
    /// Sin esto no compila con `SWIFT_STRICT_CONCURRENCY: complete`.
    func add(_ request: sending UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
    func authorizationStatus() async -> UNAuthorizationStatus
}

/// El centro de verdad, envuelto.
///
/// ⚠️ **`UNUserNotificationCenter` no puede conformar el protocolo directamente.**
/// Sus métodos son `nonisolated`, así que witnesses de requisitos `@MainActor`
/// obligan a la petición —que no es `Sendable`— a cruzar del main actor al
/// ejecutor genérico dentro del thunk de conformidad, y eso no compila con
/// concurrencia estricta. Con el envoltorio, el cruce ocurre acá adentro, con la
/// petición ya marcada como enviada: el compilador puede ver que nadie más la
/// toca.
/// ⚠️⚠️ **Las tres llamadas van por el callback y no por su versión `async`, y
/// no es gusto.** `UNUserNotificationCenter`, `UNNotificationRequest` y
/// `UNNotificationSettings` **no son `Sendable`** en el SDK. Cualquier `await`
/// sobre un método `nonisolated` del centro desde este actor manda al ejecutor
/// genérico o al propio centro (`sending 'self.center'`), o trae de vuelta un
/// ajuste que no puede cruzar — tres errores distintos, todos del mismo hueco de
/// anotaciones. Con el callback, la llamada es **síncrona**: nada cruza de
/// actor, y lo único que viaja de vuelta por la continuación son valores que sí
/// son `Sendable` (un `Bool`, un `Error`, un `enum`). Es la convención de la
/// casa para APIs legacy (`Docs/concurrency-conventions.md`).
@MainActor
final class SystemNotificationCenter: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: options) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func add(_ request: sending UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}

#if DEBUG
/// El centro de los UI tests que piden notificaciones
/// (`--uitest-notifications-provisional|denied`): contesta sin diálogo del
/// sistema —que en un runner es un muro— y guarda la cola en memoria. Fuera de
/// esos tests no se construye nunca.
@MainActor
final class InMemoryNotificationCenter: NotificationScheduling {
    private var status: UNAuthorizationStatus
    private var pending: [String: UNNotificationRequest] = [:]

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        guard status != .denied else { return false }
        status = options.contains(.provisional) ? .provisional : .authorized
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending[request.identifier] = request
    }

    func removeAllPendingNotificationRequests() {
        pending.removeAll()
    }

    func removeAllDeliveredNotifications() {}

    func authorizationStatus() async -> UNAuthorizationStatus { status }
}
#endif

/// **Las notificaciones de la 2.0** (PLAN-v2 E11): locales, prendidas por
/// defecto y desactivables, una por motivo para volver.
///
/// Separa tres cosas que la v1 mezclaba en un solo booleano:
/// - **la preferencia del jugador** (`isEnabled` y una por tipo), en
///   `UserDefaults`: prendida si la clave no existe; un `false` escrito —el
///   veterano que las apagó en la v1— se respeta;
/// - **lo que iOS concedió** (`authorization`), que se lee y no se escribe;
/// - **la ausencia programada**, que se arma al irse con `NotificationPlanner` y
///   se borra entera al volver.
///
/// El permiso va en dos pasos: el provisional al terminar el núcleo del
/// tutorial (sin diálogo, los avisos llegan en silencio al Centro de
/// notificaciones) y el completo desde la tarjeta del popup offline.
///
/// ⚠️ **Si `isLive` es falso, nada habla con iOS**: bajo XCTest y `--uitest*` el
/// juego no pide permiso ni programa, salvo que el UI test lo pida con
/// `--uitest-notifications-provisional|denied`. Las preferencias se guardan
/// igual: es lo que ejercen los tests de Ajustes.
@Observable @MainActor
final class NotificationsManager {
    /// El maestro. **Es la clave de la v1** a propósito: el `false` de un
    /// veterano que las apagó tiene que seguir valiendo.
    nonisolated static let defaultsKey = "settings.notificationsEnabled"
    nonisolated static let cardOffersKey = "notifications.card.offers"
    nonisolated static let cardLastOfferKey = "notifications.card.lastOfferAt"
    nonisolated static let cardAcceptedKey = "notifications.card.accepted"
    /// Un id fijo por motivo (`fisu.notif.vault_full`…): reprogramar reemplaza
    /// en vez de duplicar.
    nonisolated static let requestPrefix = "fisu.notif."
    nonisolated static var fullOptions: UNAuthorizationOptions { [.alert, .sound, .badge] }

    nonisolated static func enabledKey(for kind: NotificationKind) -> String {
        "\(defaultsKey).\(kind.rawValue)"
    }

    private(set) var isEnabled: Bool
    private(set) var disabledKinds: Set<NotificationKind>
    /// Lo último que contestó iOS. Se refresca al volver, al abrir Ajustes y
    /// después de cada pedido: el permiso se puede revocar desde Ajustes de iOS
    /// sin que la app se entere.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    var isDenied: Bool { authorization == .denied }

    var canDeliver: Bool {
        switch authorization {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    var preferences: NotificationPreferences {
        NotificationPreferences(masterEnabled: isEnabled, disabledKinds: disabledKinds)
    }

    @ObservationIgnored private let center: any NotificationScheduling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let isLive: Bool
    /// Qué ausencia es la vigente. Programar tiene un `await` por aviso, y volver
    /// a la app en el medio tiene que ganarle.
    @ObservationIgnored private var generation = 0

    init(center: any NotificationScheduling, defaults: UserDefaults = .standard, isLive: Bool = true) {
        self.center = center
        self.defaults = defaults
        self.isLive = isLive
        isEnabled = defaults.object(forKey: Self.defaultsKey) as? Bool ?? true
        // El nombre de la clase y no `Self`: adentro de un closure, antes de
        // terminar el init, `Self` arrastra a `self`.
        let disabled = NotificationKind.allCases.filter {
            defaults.object(forKey: NotificationsManager.enabledKey(for: $0)) as? Bool == false
        }
        disabledKinds = Set(disabled)
    }

    /// El del juego. Se construye antes del bootstrap (`FisuEvolutionApp`), así
    /// que el `--uitest-reset` de sus claves lo resuelve acá: el de
    /// `applyLaunchArgumentDefaults` llega tarde, cuando ya las leyó.
    convenience init(launchArguments arguments: [String] = ProcessInfo.processInfo.arguments) {
        let defaults = UserDefaults.standard
        #if DEBUG
        if arguments.contains("--uitest-reset") {
            NotificationsManager.wipePreferences(in: defaults)
        }
        if let status = NotificationsManager.uiTestStatus(in: arguments) {
            self.init(center: InMemoryNotificationCenter(status: status), defaults: defaults, isLive: true)
            return
        }
        #endif
        self.init(
            center: SystemNotificationCenter(),
            defaults: defaults,
            isLive: NotificationsManager.launchAllowsSystem(arguments: arguments)
        )
    }

    // MARK: La preferencia

    /// El maestro. Apagarlo borra todo lo pendiente; prenderlo con iOS sin
    /// preguntar pide el permiso completo (el jugador lo está pidiendo).
    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.defaultsKey)
        guard enabled else {
            cancelAbsence()
            return
        }
        guard isLive else { return }
        await refreshAuthorization()
        if authorization == .notDetermined {
            await askSystem(Self.fullOptions)
        }
    }

    func setEnabled(_ enabled: Bool, for kind: NotificationKind) {
        if enabled {
            disabledKinds.remove(kind)
        } else {
            disabledKinds.insert(kind)
        }
        defaults.set(enabled, forKey: Self.enabledKey(for: kind))
    }

    func isEnabled(for kind: NotificationKind) -> Bool {
        !disabledKinds.contains(kind)
    }

    // MARK: El permiso

    func refreshAuthorization() async {
        guard isLive else { return }
        authorization = await center.authorizationStatus()
        if authorization == .denied {
            // Un aviso pendiente sin permiso es basura en la cola.
            center.removeAllPendingNotificationRequests()
        }
    }

    /// El primer paso: al terminar el núcleo del tutorial, sin diálogo.
    func requestProvisional() async {
        guard isLive, isEnabled else { return }
        await refreshAuthorization()
        guard authorization == .notDetermined else { return }
        await askSystem(Self.fullOptions.union(.provisional))
    }

    @discardableResult
    private func askSystem(_ options: UNAuthorizationOptions) async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: options)
            await refreshAuthorization()
            return granted
        } catch {
            Log.lifecycle.error("notifications unavailable: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: La tarjeta del permiso completo

    /// Hay algo que mejorar (provisional o sin preguntar), el jugador no las
    /// apagó y la política de `notifications.json` dice que toca.
    func permissionCardDue(now: TimeInterval, config: NotificationsConfig.PermissionCard) -> Bool {
        guard isLive, isEnabled, !defaults.bool(forKey: Self.cardAcceptedKey) else { return false }
        guard authorization == .provisional || authorization == .notDetermined else { return false }
        return PermissionCardPolicy.isDue(
            offersMade: defaults.integer(forKey: Self.cardOffersKey),
            lastOfferAt: defaults.object(forKey: Self.cardLastOfferKey) as? Double,
            now: now,
            config: config
        )
    }

    /// Mostrada es ofrecida: cerrar el popup sin contestar gasta la oferta igual
    /// que "Ahora no".
    func recordPermissionCardOffer(now: TimeInterval) {
        defaults.set(defaults.integer(forKey: Self.cardOffersKey) + 1, forKey: Self.cardOffersKey)
        defaults.set(now, forKey: Self.cardLastOfferKey)
    }

    /// "Sí, avisame": el diálogo del sistema. Conteste lo que conteste, la
    /// tarjeta ya cumplió.
    func acceptPermissionCard() async {
        defaults.set(true, forKey: Self.cardAcceptedKey)
        guard isLive else { return }
        await askSystem(Self.fullOptions)
    }

    // MARK: La ausencia

    /// Al irse: borra lo anterior (también el recordatorio fijo de la v1) y
    /// programa lo que dice el planificador. Decide con la autorización ya leída:
    /// no la consulta, así que quien llama refresca antes.
    func scheduleAbsence(
        _ snapshot: NotificationSnapshot,
        config: NotificationsConfig,
        calendar: Calendar = .current
    ) async {
        guard isLive else { return }
        generation &+= 1
        let mine = generation
        center.removeAllPendingNotificationRequests()
        guard canDeliver else { return }
        let plan = NotificationPlanner.plan(snapshot, config: config, preferences: preferences, calendar: calendar)
        for planned in plan {
            do {
                try await center.add(Self.request(for: planned.kind, in: planned.fireAt - snapshot.now))
            } catch {
                Log.lifecycle.error("notification \(planned.kind.rawValue) not scheduled: \(error.localizedDescription)")
            }
            // Volvió a la app mientras esto esperaba: su vuelta es más nueva que esta ausencia.
            guard mine == generation else {
                center.removeAllPendingNotificationRequests()
                return
            }
        }
        Log.lifecycle.info("notifications scheduled: \(plan.map(\.kind.rawValue).joined(separator: ", "), privacy: .public)")
    }

    /// La ausencia terminó: lo pendiente y lo entregado ya no dicen nada.
    func cancelAbsence() {
        generation &+= 1
        guard isLive else { return }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func appBecameActive() async {
        cancelAbsence()
        await refreshAuthorization()
    }

    /// ⚠️ `nonisolated` a propósito: la petición no es `Sendable`, y fabricada
    /// afuera del main actor nace suelta, que es lo que `add(_: sending …)`
    /// necesita (la misma trampa del `dailyRequest()` de la v1).
    nonisolated static func request(for kind: NotificationKind, in interval: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: String.LocalizationValue(kind.titleKey))
        content.body = String(localized: String.LocalizationValue(kind.bodyKey))
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        return UNNotificationRequest(identifier: requestPrefix + kind.rawValue, content: content, trigger: trigger)
    }

    // MARK: Lanzamiento

    /// Bajo XCTest o `--uitest*` el juego no le habla a iOS: ni permiso ni avisos.
    nonisolated static func launchAllowsSystem(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        let uiTest = arguments.contains { $0.hasPrefix("--uitest") }
        let unitTestHost = environment["XCTestConfigurationFilePath"] != nil
        return !uiTest && !unitTestHost
    }

    #if DEBUG
    nonisolated static func uiTestStatus(in arguments: [String]) -> UNAuthorizationStatus? {
        if arguments.contains("--uitest-notifications-provisional") { return .provisional }
        if arguments.contains("--uitest-notifications-denied") { return .denied }
        return nil
    }
    #endif

    /// Sólo para `--uitest-reset`: estas claves son preferencia de dispositivo y
    /// sobreviven a cualquier reset de partida.
    nonisolated static func wipePreferences(in defaults: UserDefaults) {
        defaults.removeObject(forKey: defaultsKey)
        for kind in NotificationKind.allCases {
            defaults.removeObject(forKey: enabledKey(for: kind))
        }
        defaults.removeObject(forKey: cardOffersKey)
        defaults.removeObject(forKey: cardLastOfferKey)
        defaults.removeObject(forKey: cardAcceptedKey)
    }
}
