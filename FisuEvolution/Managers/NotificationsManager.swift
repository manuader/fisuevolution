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
    /// —cosa que es cierta: se arma en `dailyRequest()` y nadie más la toca—.
    /// Sin esto no compila con `SWIFT_STRICT_CONCURRENCY: complete`.
    func add(_ request: sending UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
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

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}

/// **El recordatorio diario** (spec §10.4): un aviso local por día para el
/// jugador que lo pidió. Nada de push, nada de servidor, nada de entitlements —
/// una notificación local no necesita ninguno.
///
/// ⚠️ **`isEnabled` es de sólo lectura desde afuera y eso es la mitad del
/// diseño.** El estado del toggle no es una preferencia del jugador: es lo que
/// iOS concedió. Con un `var` público, cualquier vista podría escribir `true` sin
/// permiso y el toggle prometería un recordatorio que el sistema nunca va a
/// mostrar. Se prende con `requestAndSchedule()` —que pide permiso y programa— y
/// se apaga con `disable()` —que limpia la cola—, así que el estado y la realidad
/// no pueden separarse.
///
/// El brief pedía `var isEnabled: Bool` con AppStorage: la persistencia es la
/// misma (`UserDefaults`, clave `settings.notificationsEnabled`, default
/// `false`), lo que cambia es quién puede escribirla.
@Observable @MainActor
final class NotificationsManager {
    /// Dónde vive la preferencia. Mismo prefijo que `settings.hapticsEnabled` y
    /// `settings.particlesEnabled`: las tres son del mismo cajón.
    nonisolated static let defaultsKey = "settings.notificationsEnabled"
    /// El id del recordatorio. Es **fijo** a propósito: `add` reemplaza la
    /// petición que tenga el mismo identifier, así que prender el toggle dos
    /// veces deja un recordatorio, no dos.
    nonisolated static let requestIdentifier = "fisu.daily.reminder"
    /// Las 19:00, hora local. Después del laburo y antes de la cena: es cuando
    /// el juego se juega, no cuando el teléfono está en un bolsillo.
    nonisolated static let reminderHour = 19

    private(set) var isEnabled: Bool
    /// El jugador dijo que no (o iOS ya lo tenía denegado). Lo publica la vista
    /// para explicar por qué el toggle no se queda prendido: sin esto, tocarlo y
    /// que vuelva solo se lee como un bug.
    private(set) var permissionDenied = false

    @ObservationIgnored private let center: any NotificationScheduling
    @ObservationIgnored private let defaults: UserDefaults
    /// Qué decisión del jugador es la vigente. Misma guarda que la de generación
    /// de `StoreManager`: pedir el permiso tiene dos `await` en el medio, y lo
    /// que el jugador haga mientras tanto —apagar el toggle— tiene que ganarle a
    /// la respuesta que llega después. Sin esto, un apagado durante el pedido se
    /// vería volver solo a prendido.
    @ObservationIgnored private var generation = 0

    init(center: any NotificationScheduling = SystemNotificationCenter(),
         defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        // Default `false`: las notificaciones se piden, no se asumen.
        isEnabled = defaults.bool(forKey: Self.defaultsKey)
    }

    /// Pide el permiso y, si lo dan, deja programado el recordatorio diario.
    ///
    /// Todos los caminos que no terminan en un recordatorio programado dejan
    /// `isEnabled` en `false`.
    func requestAndSchedule() async {
        generation &+= 1
        let mine = generation
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            // El jugador apagó el toggle mientras el sistema contestaba: su
            // decisión es más nueva que esta respuesta.
            guard mine == generation else { return }
            guard granted else {
                permissionDenied = true
                store(false)
                return
            }
            permissionDenied = false
            try await center.add(Self.dailyRequest())
            guard mine == generation else {
                // Alcanzó a apagarlo mientras se programaba: el recordatorio que
                // acaba de entrar en la cola no puede quedar vivo.
                center.removeAllPendingNotificationRequests()
                return
            }
            store(true)
        } catch {
            Log.lifecycle.error("notifications unavailable: \(error.localizedDescription)")
            guard mine == generation else { return }
            store(false)
        }
    }

    /// Apaga el recordatorio: la cola queda limpia y la preferencia en `false`.
    ///
    /// Se borra **todo** lo pendiente y no sólo `requestIdentifier` porque el
    /// juego no programa ninguna otra notificación: si algún día programa otra,
    /// este método es el lugar donde se decide qué sobrevive.
    func disable() {
        generation &+= 1
        center.removeAllPendingNotificationRequests()
        permissionDenied = false
        store(false)
    }

    /// Re-sincroniza contra el sistema. El permiso se puede revocar desde
    /// Ajustes de iOS sin que la app se entere, y un toggle prendido contra un
    /// permiso denegado es exactamente la mentira que este manager evita.
    func syncWithSystem() async {
        guard isEnabled else { return }
        let status = await center.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return
        default:
            center.removeAllPendingNotificationRequests()
            store(false)
        }
    }

    // MARK: - Internals

    private func store(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.defaultsKey)
    }

    /// El recordatorio: título y cuerpo del catálogo (con el humor de la casa) y
    /// un disparador de calendario que repite todos los días a la misma hora.
    ///
    /// ⚠️ `repeats: true` con `DateComponents` de sólo hora y minuto es lo que lo
    /// hace **diario**. Con la fecha completa sonaría una vez; con `repeats:
    /// false`, también.
    ///
    /// ⚠️ `nonisolated` a propósito: la petición no es `Sendable`, y lo que sale
    /// de una función aislada al main actor pertenece a la región del main actor
    /// —o sea que no se puede "enviar" a `add`—. Fabricada afuera, nace suelta,
    /// que es exactamente lo que es: un objeto recién hecho que nadie más toca.
    nonisolated private static func dailyRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.daily.title")
        content.body = String(localized: "notif.daily.body")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: reminderHour, minute: 0),
            repeats: true
        )
        return UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
    }
}
