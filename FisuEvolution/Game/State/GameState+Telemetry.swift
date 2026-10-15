import EconomyKit
import Foundation
import SwiftUI

/// Lo que el juego le pide a la telemetría. Lo cumple `TelemetryService` (con su compuerta, que
/// decide si algo sale) y, en los tests, un espía.
@MainActor
protocol TelemetryRecording: AnyObject {
    func start()
    func didBecomeActive()
    func record(_ event: TelemetryPayload)
    func flush()
}

extension TelemetryService: TelemetryRecording {}

/// El enganche de la telemetría con la partida (E15 T6): el servicio y la sesión en curso.
///
/// La sesión va de `.active` a `.background`. Un `.inactive` en el medio (el centro de control,
/// una llamada) no la corta: abrir dos veces o cerrar sin abrir no hace nada. El número de sesión
/// es un contador local de esta instalación; no sale del teléfono más que como `n`.
@MainActor
final class TelemetryHookup {
    static let sessionNumberKey = "telemetry.sessionNumber"

    let recorder: any TelemetryRecording
    private let defaults: UserDefaults
    private var sessionStartedAt: TimeInterval?

    init(recorder: any TelemetryRecording, defaults: UserDefaults = .standard) {
        self.recorder = recorder
        self.defaults = defaults
    }

    var isSessionOpen: Bool { sessionStartedAt != nil }

    func record(_ event: TelemetryPayload) {
        recorder.record(event)
    }

    func beginSession(at now: TimeInterval) {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = now
        let number = defaults.integer(forKey: Self.sessionNumberKey) + 1
        defaults.set(number, forKey: Self.sessionNumberKey)
        recorder.didBecomeActive()
        recorder.record(.sessionStart(number: number))
    }

    /// Cierra la sesión con su duración y manda lo juntado: es lo último antes de que iOS suspenda.
    func endSession(at now: TimeInterval) {
        guard let startedAt = sessionStartedAt else { return }
        sessionStartedAt = nil
        recorder.record(.sessionEnd(seconds: Int((now - startedAt).rounded())))
        recorder.flush()
    }
}

/// El cableado de la telemetría (E15 T6): cada fuente emite **un** evento y todo pasa por
/// `TelemetryService.record`, cuya compuerta manda. Medición pura: nada de esto acredita, cobra ni
/// toca el ritmo, y sin telemetría adjunta (tests, recuperación) es un no-op.
extension GameState {
    /// Se adjunta una vez, con la partida lista. Si la escena ya está activa, la sesión arranca acá:
    /// el primer `.active` del arranque llega antes que los servicios.
    func attachTelemetry(_ recorder: any TelemetryRecording, defaults: UserDefaults = .standard) {
        let hookup = TelemetryHookup(recorder: recorder, defaults: defaults)
        telemetry = hookup
        recorder.start()
        if isSceneActive { hookup.beginSession(at: Date().timeIntervalSince1970) }
    }

    /// `session_start` al volver a `.active`; `session_end` y el envío al irse a `.background`.
    func telemetrySceneChanged(to phase: ScenePhase, now: TimeInterval) {
        guard let telemetry else { return }
        switch phase {
        case .active: telemetry.beginSession(at: now)
        case .background: telemetry.endSession(at: now)
        default: break
        }
    }

    func telemetryImpression(_ impression: AdImpression) {
        telemetry?.record(.impression(impression))
    }

    func telemetryOffer(_ stage: OfferStage, site: String) {
        telemetry?.record(.offer(site: site, stage: stage))
    }

    /// Sólo lo que se acreditó de verdad: ni una transacción ya acreditada (restaurar, reentregar)
    /// ni una revocación pasan por acá.
    func telemetryPurchase(_ entry: ProductCatalog.Entry) {
        telemetry?.record(.purchase(product: entry.id))
    }

    func telemetryPrestige() {
        guard let count = player?.meta.prestigeLevel else { return }
        telemetry?.record(.prestige(count: count))
    }
}
