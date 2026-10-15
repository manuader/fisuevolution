import Foundation

/// La compuerta única (C5.3): decide si algo de la telemetría sale del teléfono. Pura: todos los
/// insumos vienen de afuera, así que cada combinación se prueba sin red ni SDK.
///
/// Pasa sólo si las cuatro cosas son ciertas: el interruptor remoto dijo `true`, hay
/// consentimiento (`canRequestAds`: en la app es `TelemetryConsent`, que además de UMP exige los
/// propósitos de TCF donde aplica el RGPD), no es un UI test (`--uitest*`) y no es un build
/// `DEBUG` (salvo `--telemetry-debug`). ATT no entra: el id de la telemetría es propio, distinto
/// del del ranking, y no se cruza con nadie (Dudas 1 del plan de E15).
struct TelemetryGate: Sendable, Equatable {
    static let debugOverride = "--telemetry-debug"

    var remoteEnabled: Bool
    var canRequestAds: Bool
    var arguments: [String]
    var isDebug: Bool

    var canSend: Bool { remoteEnabled && localAllows }

    /// Todo menos el interruptor remoto: lo que se sabe sin preguntarle nada a la red.
    var localAllows: Bool {
        canRequestAds && !isUITest && (!isDebug || arguments.contains(Self.debugOverride))
    }

    private var isUITest: Bool {
        arguments.contains { $0.hasPrefix("--uitest") }
    }
}
