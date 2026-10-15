import Foundation
import OSLog

/// La cola offline de eventos: en disco (`Application Support/telemetry-queue.json`, escritura
/// atómica) para que lo que no salió sobreviva a cerrar la app.
///
/// Tiene tope (los más viejos se caen primero) y un archivo que no se puede leer se descarta
/// entero: la telemetría nunca puede trabar el juego. Sólo entra acá lo que la compuerta dejó
/// pasar (`TelemetryService`).
actor TelemetryQueue {
    static let capacity = 1000
    static let batchSize = 50

    /// El id es local: sirve para confirmar un lote y no viaja al servidor.
    struct Entry: Codable, Sendable, Equatable {
        let id: UUID
        let event: TelemetryEvent
    }

    struct Batch: Sendable, Equatable {
        let entries: [Entry]
        var events: [TelemetryEvent] { entries.map(\.event) }
        var isEmpty: Bool { entries.isEmpty }
    }

    private static let log = Logger(subsystem: "com.adergames.fisu", category: "telemetry")

    private let fileURL: URL
    private let limit: Int
    private var loaded: [Entry]?

    init(fileURL: URL = TelemetryQueue.defaultURL, capacity: Int = TelemetryQueue.capacity) {
        self.fileURL = fileURL
        limit = capacity
    }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "telemetry-queue.json")
    }

    var count: Int { entries().count }

    func append(_ event: TelemetryEvent) {
        var all = entries()
        all.append(Entry(id: UUID(), event: event))
        if all.count > limit { all.removeFirst(all.count - limit) }
        store(all)
    }

    /// Los más viejos primero. No saca nada: el lote se confirma (o se descarta) con `ack`.
    func nextBatch(max: Int = TelemetryQueue.batchSize) -> Batch {
        Batch(entries: Array(entries().prefix(Swift.max(0, max))))
    }

    /// Saca de la cola un lote que ya salió (2xx) o que no tiene arreglo (4xx).
    func ack(_ batch: Batch) {
        let done = Set(batch.entries.map(\.id))
        store(entries().filter { !done.contains($0.id) })
    }

    private func entries() -> [Entry] {
        if let loaded { return loaded }
        let read = readFromDisk()
        loaded = read
        return read
    }

    private func readFromDisk() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        if let saved = try? TelemetryEvent.makeDecoder().decode([Entry].self, from: data) {
            return Array(saved.suffix(limit))
        }
        Self.log.error("cola de telemetría ilegible: se descarta")
        try? FileManager.default.removeItem(at: fileURL)
        return []
    }

    private func store(_ all: [Entry]) {
        loaded = all
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TelemetryEvent.makeEncoder().encode(all).write(to: fileURL, options: .atomic)
        } catch {
            Self.log.error("no se pudo guardar la cola de telemetría (\(all.count) eventos)")
        }
    }
}
