import AppTrackingTransparency
import Foundation
import UIKit
import UserMessagingPlatform

/// El consentimiento, que va ANTES de arrancar el SDK de anuncios.
///
/// Son **dos permisos distintos de dos dueños distintos**, y confundirlos es el
/// error clásico:
///
/// | | Quién lo pide | Qué habilita | Dónde es obligatorio |
/// |---|---|---|---|
/// | **UMP** (GDPR/TCF) | Google, con su propio formulario | servir anuncios **a la vez** | UE / UK / Suiza |
/// | **ATT** | Apple, con su diálogo de sistema | usar el IDFA para **personalizar** | en todo el mundo |
///
/// La consecuencia práctica de que sean distintos: **rechazar ATT no apaga los
/// anuncios**, sólo los vuelve no personalizados (pagan menos, y está bien).
/// Rechazar UMP en la UE sí puede dejar sin inventario.
///
/// ## El orden, que es lo único que no se puede improvisar
///
/// 1. **UMP primero.** `requestConsentInfoUpdate` + `loadAndPresentIfRequired`.
/// 2. **ATT después**, y sólo cuando UMP terminó. Los dos son diálogos modales:
///    pedirlos juntos los apila y el jugador ve dos permisos encima del otro en
///    el primer segundo de juego.
/// 3. **El SDK al final** (`AdMobAdsProvider.prepare()`).
///
/// ⚠️ **ATT necesita que la app esté ACTIVA.** Llamado durante el lanzamiento,
/// mientras la app todavía está `inactive`, `requestTrackingAuthorization`
/// devuelve sin mostrar nada y el estado queda en `.denied` — se ve como "el
/// usuario siempre rechaza" y no falla nada, que es lo que lo hace difícil de
/// diagnosticar. Por eso `resolve()` espera a que la app esté activa antes de
/// pedirlo.
@MainActor
enum AdsConsent {

    /// Resuelve los dos permisos, en orden, y vuelve cuando se puede arrancar
    /// el SDK. Nunca lanza: un consentimiento que falla no puede impedir que el
    /// juego arranque.
    static func resolve() async {
        await requestUMPIfNeeded()
        await requestATTWhenActive()
    }

    // MARK: - UMP (GDPR)

    private static func requestUMPIfNeeded() async {
        let parameters = RequestParameters()
        // El juego no está dirigido a menores de edad de consentimiento: el
        // rating es 12+. Declararlo mal acá restringe el inventario sin motivo.
        parameters.isTaggedForUnderAgeOfConsent = false

        let info = ConsentInformation.shared
        do {
            try await info.requestConsentInfoUpdate(with: parameters)
        } catch {
            // Sin red no hay formulario. Se sigue: `canRequestAds` decide
            // después, y el SDK sabe degradar a no personalizado.
            return
        }

        // `loadAndPresentIfRequired` es un no-op cuando no hace falta (fuera de
        // la UE, o con el consentimiento ya dado): no hay que preguntar
        // `formStatus` a mano antes de llamarlo.
        try? await ConsentForm.loadAndPresentIfRequired(from: nil)
    }

    /// Reabre el formulario de privacidad de UMP a pedido del jugador. La UE
    /// exige que el consentimiento se pueda REVISAR, no sólo dar una vez; el
    /// botón vive en Ajustes y sólo se muestra si
    /// `privacyOptionsRequirementStatus` dice que corresponde.
    static var showsPrivacyOptions: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Si Ajustes muestra "Opciones de privacidad".
    static var privacyRowVisible: Bool {
        privacyRowVisible(required: showsPrivacyOptions, arguments: ProcessInfo.processInfo.arguments)
    }

    nonisolated static func privacyRowVisible(required: Bool, arguments: [String]) -> Bool {
        #if DEBUG
        if arguments.contains("--uitest-privacy-options") { return true }
        #endif
        return required
    }

    static func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }

    // MARK: - ATT (Apple)

    private static func requestATTWhenActive() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await waitUntilActive()
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Espera a que la app esté activa, hasta ~5 s. Ver el aviso del docstring
    /// de arriba: pedir ATT antes de eso no muestra el diálogo.
    ///
    /// Es un sondeo y no `NotificationCenter.notifications(named:)`, que sería
    /// lo elegante, por una razón del compilador y no de estilo: esa secuencia
    /// asíncrona entrega `Notification`, que **no es `Sendable`**, y consumirla
    /// desde acá no compila con `SWIFT_STRICT_CONCURRENCY: complete`
    /// ("sending value of non-Sendable type ... risks causing data races").
    /// El sondeo lee `applicationState` en el main actor, no captura nada y
    /// está acotado, así que no puede colgar el arranque si la notificación
    /// nunca llega.
    private static func waitUntilActive() async {
        for _ in 0..<50 {
            if UIApplication.shared.applicationState == .active { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
