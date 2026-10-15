import Foundation
import OSLog

/// Manda la cola a `public.telemetry_events` por PostgREST, de a lotes.
///
/// `Prefer: return=minimal` es obligatorio: `anon` no tiene `select` sobre la tabla y un
/// `return=representation` fallaría. 2xx confirma el lote; 4xx lo descarta (es un bug del cliente
/// o el interruptor del servidor apagado: reintentar no lo arregla); 5xx o sin red lo deja en la
/// cola para el próximo intento.
struct TelemetryUploader: Sendable {
    enum Outcome: Equatable, Sendable {
        case accepted
        case rejected(status: Int)
        case retryLater
    }

    enum DrainOutcome: Equatable, Sendable {
        case drained
        case retryLater
    }

    /// Lotes por vaciado: una cola llena (1000) sale entera en una vuelta.
    static let maxBatchesPerDrain = 20

    private static let log = Logger(subsystem: "com.adergames.fisu", category: "telemetry")

    let config: RankingConfig?
    let fetch: TelemetryNetwork.Fetch

    init(config: RankingConfig?, fetch: @escaping TelemetryNetwork.Fetch = TelemetryNetwork.urlSessionFetch) {
        self.config = config
        self.fetch = fetch
    }

    func upload(_ events: [TelemetryEvent]) async -> Outcome {
        guard !events.isEmpty else { return .accepted }
        guard let body = try? TelemetryEvent.makeEncoder().encode(events),
              var request = TelemetryNetwork.post("telemetry_events", body: body, config: config) else {
            return .retryLater
        }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        guard let reply = await TelemetryNetwork.send(request, with: fetch) else { return .retryLater }
        switch reply.1.statusCode {
        case 200...299: return .accepted
        case 400...499: return .rejected(status: reply.1.statusCode)
        default: return .retryLater
        }
    }

    /// Vacía la cola lote por lote hasta que no queda nada o el servidor pide esperar.
    func drain(_ queue: TelemetryQueue) async -> DrainOutcome {
        for _ in 0..<Self.maxBatchesPerDrain {
            let batch = await queue.nextBatch()
            if batch.isEmpty { return .drained }
            switch await upload(batch.events) {
            case .accepted:
                await queue.ack(batch)
            case .rejected(let status):
                Self.log.error("telemetría rechazada (HTTP \(status)): se descartan \(batch.entries.count) eventos")
                await queue.ack(batch)
            case .retryLater:
                return .retryLater
            }
        }
        return .drained
    }
}

/// La espera entre intentos fallidos: 30 s, el doble cada vez, hasta 30 min.
enum TelemetryBackoff {
    static let initial: TimeInterval = 30
    static let ceiling: TimeInterval = 30 * 60

    static func delay(afterFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        return min(initial * pow(2, Double(min(failures - 1, 16))), ceiling)
    }
}
