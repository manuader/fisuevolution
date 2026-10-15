import Foundation
import UserMessagingPlatform

/// La telemetría anónima (E15 F0): recibe los eventos del juego, los pasa por la compuerta y los
/// manda en lotes. Apagada por defecto en tres capas (C5): la tabla, el interruptor remoto y
/// `TelemetryGate`.
///
/// Con la compuerta cerrada los eventos **se descartan**, no se encolan: nada se junta antes de
/// tiempo. Lo que se pide antes de que el interruptor conteste espera en memoria detrás de esa
/// pregunta (nunca en disco) y entra a la cola sólo si la respuesta fue `true`.
///
/// Ni siquiera la pregunta al interruptor sale si la compuerta local está cerrada (sin
/// consentimiento, UI test, DEBUG sin `--telemetry-debug`): si el consentimiento llega a mitad de
/// sesión, se pregunta la primera vez que `record` o `flush` lo vean. Sin consentimiento, o con un
/// `false` explícito del servidor, la cola se vacía: lo juntado no sale nunca.
///
/// Nada de esto bloquea el main actor: el trabajo corre en tareas encadenadas (en orden) que
/// esperan a la cola y a la red fuera de él.
@MainActor
final class TelemetryService {
    private let queue: TelemetryQueue
    private let telemetrySwitch: TelemetrySwitch
    private let uploader: TelemetryUploader
    private let device: DeviceContext
    private let identity: InstallIdentity
    private let canRequestAds: @MainActor () -> Bool
    private let arguments: [String]
    private let isDebug: Bool
    private let now: @MainActor () -> Date

    private(set) var remoteEnabled = false
    /// Si ya se le preguntó al interruptor en esta sesión (con respuesta o sin ella).
    private var switchAsked = false
    private var sessionId = UUID()
    private var recordedSinceFlush = 0
    private var failedUploads = 0
    private var nextAttemptAt: Date?
    private var tail: Task<Void, Never>?
    /// El Keychain se lee una sola vez y fuera del main actor, recién cuando hace falta.
    private var installIdTask: Task<String, Never>?

    init(
        queue: TelemetryQueue,
        telemetrySwitch: TelemetrySwitch,
        uploader: TelemetryUploader,
        device: DeviceContext,
        identity: InstallIdentity,
        canRequestAds: @escaping @MainActor () -> Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        isDebug: Bool = TelemetryService.isDebugBuild,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.queue = queue
        self.telemetrySwitch = telemetrySwitch
        self.uploader = uploader
        self.device = device
        self.identity = identity
        self.canRequestAds = canRequestAds
        self.arguments = arguments
        self.isDebug = isDebug
        self.now = now
    }

    /// El de la app: la `RankingConfig` del ranking (la misma `baseURL`/`anonKey`). Bajo XCTest o
    /// `--uitest*` no recibe config, así que el interruptor nunca pregunta y queda apagado.
    static func live(config: RankingConfig?) -> TelemetryService {
        let usable = RankingStore.isLive ? config : nil
        return TelemetryService(
            queue: TelemetryQueue(),
            telemetrySwitch: TelemetrySwitch(config: usable),
            uploader: TelemetryUploader(config: usable),
            device: DeviceContext(),
            identity: InstallIdentity(),
            canRequestAds: { ConsentInformation.shared.canRequestAds }
        )
    }

    nonisolated static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Cada insumo de C5.3 leído ahora mismo.
    var gate: TelemetryGate {
        TelemetryGate(remoteEnabled: remoteEnabled, canRequestAds: canRequestAds(), arguments: arguments, isDebug: isDebug)
    }

    // MARK: - El ciclo de vida

    /// Al arrancar: si la compuerta local deja, pregunta el interruptor en segundo plano y, si
    /// quedó algo de otra vez, lo manda.
    func start() {
        chain { service in
            guard await service.localGateAllows() else { return }
            await service.refreshSwitch(force: true)
            await service.drain()
        }
    }

    /// Al volver del background: re-pregunta el interruptor si la respuesta tiene 6 h o más (o si
    /// todavía no se preguntó, porque el consentimiento llegó después del arranque).
    func didBecomeActive() {
        chain { service in
            guard await service.localGateAllows() else { return }
            await service.refreshSwitch(force: !service.switchAsked)
        }
    }

    /// Al irse a background (y cada 50 eventos): manda lo que haya en la cola.
    func flush() {
        chain { service in
            guard await service.localGateAllows() else { return }
            await service.askSwitchIfNeeded()
            await service.drain()
        }
    }

    /// Espera a que termine todo lo pedido hasta ahora. Para los tests y para quien necesite orden.
    func settle() async {
        await tail?.value
    }

    // MARK: - Los eventos

    /// La única entrada de eventos. Con la compuerta cerrada, el evento se pierde a propósito.
    func record(_ event: TelemetryPayload) {
        if case .sessionStart = event { sessionId = UUID() }
        guard gate.localAllows else { return }
        let session = sessionId
        let at = now()
        chain { service in
            await service.askSwitchIfNeeded()
            guard service.gate.canSend else { return }
            let device = await service.device.snapshot()
            let installId = await service.resolvedInstallId()
            let row = TelemetryEvent(event, installId: installId, sessionId: session, at: at, device: device)
            await service.queue.append(row)
            service.recordedSinceFlush += 1
            if service.recordedSinceFlush >= TelemetryQueue.batchSize { await service.drain() }
        }
    }

    // MARK: - Por dentro

    /// Encadena el trabajo detrás del anterior: los eventos esperan a que el interruptor conteste y
    /// salen en el orden en que llegaron.
    private func chain(_ work: @escaping @MainActor @Sendable (TelemetryService) async -> Void) {
        let previous = tail
        tail = Task { [self] in
            await previous?.value
            await work(self)
        }
    }

    private func refreshSwitch(force: Bool) async {
        switchAsked = true
        remoteEnabled = await telemetrySwitch.refresh(force: force)
        if await telemetrySwitch.saidNo { await queue.removeAll() }
    }

    /// La pregunta perezosa: la primera vez que la compuerta local deja pasar algo en la sesión.
    private func askSwitchIfNeeded() async {
        guard !switchAsked, gate.localAllows else { return }
        await refreshSwitch(force: true)
    }

    /// La compuerta local, leída ahora. Sin consentimiento de UMP, además, se vacía la cola.
    private func localGateAllows() async -> Bool {
        let gate = self.gate
        if !gate.canRequestAds { await queue.removeAll() }
        return gate.localAllows
    }

    private func resolvedInstallId() async -> String {
        if let installIdTask { return await installIdTask.value }
        let identity = identity
        let task = Task.detached(priority: .utility) { identity.installId() }
        installIdTask = task
        return await task.value
    }

    /// Con la compuerta cerrada no sale nada, ni siquiera lo que quedó en la cola de antes.
    private func drain() async {
        recordedSinceFlush = 0
        guard gate.canSend else { return }
        if let nextAttemptAt, now() < nextAttemptAt { return }
        switch await uploader.drain(queue) {
        case .drained:
            failedUploads = 0
            nextAttemptAt = nil
        case .retryLater:
            failedUploads += 1
            nextAttemptAt = now().addingTimeInterval(TelemetryBackoff.delay(afterFailures: failedUploads))
        }
    }
}
