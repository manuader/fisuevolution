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
    /// Espera a que termine lo pedido hasta ahora (el envío al irse incluido).
    func settle() async
}

extension TelemetryService: TelemetryRecording {}

/// El enganche de la telemetría con la partida (E15 T6): el servicio y la sesión en curso.
///
/// La sesión va de `.active` a `.background`. Un `.inactive` en el medio (el centro de control,
/// una llamada) no la corta: abrir dos veces o cerrar sin abrir no hace nada. El número de sesión
/// es un contador local de esta instalación; no sale del teléfono más que como `n`.
///
/// Cerrar la app desde el selector de apps la mata sin pasar por `.background` en la mayoría de los
/// casos: esa sesión queda con su `session_start` y sin `session_end` (y lo que estaba en la cola
/// sale en el arranque siguiente). Al leer duraciones, una sesión sin cierre no es una de 0 s.
@MainActor
final class TelemetryHookup {
    static let sessionNumberKey = "telemetry.sessionNumber"
    /// Las transacciones que ya emitieron `purchase`. Es de la telemetría y no del save: las no
    /// consumibles no anotan su id al acreditarse, y StoreKit las vuelve a entregar.
    static let emittedPurchasesKey = "telemetry.emittedPurchases"
    /// Las últimas que se recuerdan. Una reentrega de algo más viejo que esto volvería a contar:
    /// hacen falta cientos de compras en el medio, y es un error de medición, no de plata.
    static let emittedPurchasesLimit = 200

    let recorder: any TelemetryRecording
    private let defaults: UserDefaults
    private var sessionStartedAt: TimeInterval?
    /// El envío del cierre de sesión, con su tarea de background; los tests lo esperan.
    private(set) var flushTask: Task<Void, Never>?

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

    /// Cierra la sesión con su duración (y el `progress` de la partida, si lo hay: 2.1 C6) y manda
    /// lo juntado: es lo último antes de que iOS suspenda, así que pide unos segundos de vida
    /// (`fisu.telemetry`, como `seal` con `fisu.save`) y los devuelve cuando el servicio terminó.
    func endSession(at now: TimeInterval, progress: TelemetryPayload? = nil,
                    backgroundTasks: (any BackgroundTaskRunning)? = nil) {
        guard let startedAt = sessionStartedAt else { return }
        sessionStartedAt = nil
        let token = backgroundTasks?.begin("fisu.telemetry")
        recorder.record(.sessionEnd(seconds: Int((now - startedAt).rounded())))
        if let progress { recorder.record(progress) }
        recorder.flush()
        let recorder = recorder
        let previous = flushTask
        flushTask = Task {
            await previous?.value
            await recorder.settle()
            if let backgroundTasks, let token { backgroundTasks.end(token) }
        }
    }

    /// Un `purchase` por transacción comprada por esta cuenta: ni la reentrega de StoreKit
    /// (`Transaction.updates`, `unfinished`, `retryUnfinished`) ni lo que llega por En Familia.
    func recordPurchase(product: String, transactionID: String, boughtByThisAccount: Bool) {
        guard boughtByThisAccount else { return }
        var emitted = defaults.stringArray(forKey: Self.emittedPurchasesKey) ?? []
        guard !emitted.contains(transactionID) else { return }
        emitted.append(transactionID)
        if emitted.count > Self.emittedPurchasesLimit {
            emitted.removeFirst(emitted.count - Self.emittedPurchasesLimit)
        }
        defaults.set(emitted, forKey: Self.emittedPurchasesKey)
        recorder.record(.purchase(product: product))
    }
}

/// El cableado de la telemetría (E15 T6): cada fuente emite **un** evento y todo pasa por
/// `TelemetryService.record`, cuya compuerta manda. Medición pura: nada de esto acredita, cobra ni
/// toca el ritmo, y sin telemetría adjunta (tests, recuperación) es un no-op.
extension GameState {
    /// Se adjunta una vez, al principio de los servicios (antes de la tienda, para no perder el
    /// `purchase` de una compra que llega al arrancar). Si la escena ya estaba en primer plano, la
    /// sesión arranca con la hora de ese `.active` (`sceneActiveSince`), no con la de adjuntar: el
    /// primer `.active` del arranque llega antes que los servicios. En un arranque en background no
    /// hay `.active` anotado y no se abre nada.
    func attachTelemetry(_ recorder: any TelemetryRecording, defaults: UserDefaults = .standard) {
        let hookup = TelemetryHookup(recorder: recorder, defaults: defaults)
        telemetry = hookup
        recorder.start()
        if let sceneActiveSince { hookup.beginSession(at: sceneActiveSince) }
    }

    /// El arranque en frío: `onChange(of: scenePhase)` no avisa la fase inicial, así que la app
    /// dice acá si arrancó en primer plano. En background no anota nada.
    func noteLaunchScene(inBackground: Bool, now: TimeInterval = Date().timeIntervalSince1970) {
        guard !inBackground, sceneActiveSince == nil else { return }
        sceneActiveSince = now
    }

    /// `session_start` al volver a `.active`; `session_end` y el envío al irse a `.background`.
    /// La hora del `.active` se anota aunque la telemetría no esté adjunta todavía.
    func telemetrySceneChanged(to phase: ScenePhase, now: TimeInterval) {
        switch phase {
        case .active:
            if sceneActiveSince == nil { sceneActiveSince = now }
            telemetry?.beginSession(at: now)
        case .background:
            sceneActiveSince = nil
            telemetry?.endSession(at: now, progress: telemetryProgress(now: now), backgroundTasks: backgroundTasks)
        default:
            break
        }
    }

    /// El `progress` que acompaña al `session_end` (2.1 C6), para comparar el ritmo real con el
    /// simulado: el tier de esta vida (`run.maxTierReached`, vuelve a 1 al reencarnar), las
    /// reencarnaciones y los minutos activos de la partida. Los minutos son los del ranking
    /// (`meta.ranking.playedSeconds`: la app en `.active`, sin el tutorial, congelados en Dios) más
    /// la sesión que todavía no cerró: la telemetría se entera del `.background` antes que el ranking.
    /// Sin jugador (recuperación), nada.
    func telemetryProgress(now: TimeInterval) -> TelemetryPayload? {
        guard let player else { return nil }
        let ranking = player.meta.ranking
        let open = ranking.activeSince.map { max(0, now - $0) } ?? 0
        let minutes = Int(((ranking.playedSeconds + open) / 60).rounded(.down))
        return .progress(maxTier: player.run.maxTierReached, activeMinutes: minutes,
                         prestige: player.meta.prestigeLevel)
    }

    func telemetryImpression(_ impression: AdImpression) {
        telemetry?.record(.impression(impression))
    }

    /// Un evento por etapa. Regalos es el pico: abrirlo con los videos listos dispara un `shown` por
    /// tarjeta (~13, todas a la vez) y cerrarlo sin tocar, un `dismissed` cada una: ~26 eventos por
    /// visita. Es el volumen esperado, no un bucle (la cola los manda en lotes de 50).
    /// `ctx` (2.1 C6): el momento de necesidad que la sacó, cuando sale por uno (F3).
    func telemetryOffer(_ stage: OfferStage, site: String, ctx: NeedMoment? = nil) {
        telemetry?.record(.offer(site: site, stage: stage, ctx: ctx))
    }

    /// Sólo lo que se acreditó de verdad y una vez por transacción: ni una ya acreditada (restaurar,
    /// reentregar), ni una revocación, ni una compra de En Familia (`boughtByThisAccount`).
    func telemetryPurchase(_ entry: ProductCatalog.Entry, transactionID: String, boughtByThisAccount: Bool) {
        telemetry?.recordPurchase(product: entry.id, transactionID: transactionID,
                                  boughtByThisAccount: boughtByThisAccount)
    }

    func telemetryPrestige() {
        guard let count = player?.meta.prestigeLevel else { return }
        telemetry?.record(.prestige(count: count))
    }
}
