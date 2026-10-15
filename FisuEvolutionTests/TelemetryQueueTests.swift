import Foundation
import Testing
@testable import FisuEvolution

@Suite("Telemetría: la cola offline")
struct TelemetryQueueTests {
    private static func fileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "telemetry-\(UUID().uuidString)")
            .appending(path: "telemetry-queue.json")
    }

    private static func event(_ number: Int, at date: Date = Date()) -> TelemetryEvent {
        TelemetryEvent(
            .sessionStart(number: number), installId: "11111111-2222-4333-8444-555555555555",
            sessionId: UUID(), at: date, device: TelemetryFakeNetwork.device)
    }

    private static func numbers(_ batch: TelemetryQueue.Batch) -> [Int64] {
        batch.events.compactMap { event -> Int64? in
            guard case .int(let number) = event.props["n"] else { return nil }
            return number
        }
    }

    @Test("ida y vuelta por disco, aunque la carpeta no exista todavía")
    func roundTripThroughDisk() async {
        let url = Self.fileURL()
        let saved = [Self.event(1), Self.event(2)]
        let queue = TelemetryQueue(fileURL: url)
        for event in saved { await queue.append(event) }

        let reopened = TelemetryQueue(fileURL: url)
        #expect(await reopened.count == 2)
        #expect(await reopened.nextBatch().events == saved)
    }

    @Test("el tope es 1000 y, al pasarlo, los más viejos salen primero (también al releer)")
    func capacityDropsTheOldest() async {
        #expect(TelemetryQueue.capacity == 1000)
        #expect(TelemetryQueue.batchSize == 50)

        let url = Self.fileURL()
        let queue = TelemetryQueue(fileURL: url, capacity: 10)
        for number in 1...15 { await queue.append(Self.event(number)) }

        #expect(await queue.count == 10)
        #expect(Self.numbers(await queue.nextBatch(max: 1)) == [6])
        #expect(await TelemetryQueue(fileURL: url, capacity: 4).count == 4)
    }

    @Test("lotes de 50, en orden; el ack saca sólo ese lote")
    func batchesAndAck() async {
        let queue = TelemetryQueue(fileURL: Self.fileURL())
        for number in 1...120 { await queue.append(Self.event(number)) }

        let first = await queue.nextBatch()
        #expect(first.entries.count == 50)
        #expect(Self.numbers(first) == Array(1...50).map(Int64.init))
        #expect(await queue.nextBatch() == first)

        await queue.ack(first)
        #expect(await queue.count == 70)
        #expect(Self.numbers(await queue.nextBatch()).first == 51)
    }

    @Test("un archivo roto se descarta entero y la cola arranca vacía")
    func brokenFileIsDiscarded() async throws {
        let url = Self.fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ esto no es una cola".utf8).write(to: url)

        let queue = TelemetryQueue(fileURL: url)
        #expect(await queue.count == 0)
        #expect(FileManager.default.fileExists(atPath: url.path()) == false)

        await queue.append(Self.event(1))
        #expect(await TelemetryQueue(fileURL: url).count == 1)
    }

    @Test("la cola vacía da un lote vacío")
    func emptyQueue() async {
        let queue = TelemetryQueue(fileURL: Self.fileURL())
        #expect(await queue.nextBatch().isEmpty)
    }

    @Test("el lote no lleva eventos con la hora corrida más de 29 días (la tabla los rechazaría) y se caen")
    func staleEventsNeverLeave() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 24 * 60 * 60
        #expect(TelemetryQueue.maxClockSkew == 29 * day)

        let url = Self.fileURL()
        let queue = TelemetryQueue(fileURL: url, now: { now })
        await queue.append(Self.event(1, at: now - 40 * day))
        await queue.append(Self.event(2, at: now - 28 * day))
        await queue.append(Self.event(3, at: now))
        await queue.append(Self.event(4, at: now + 28 * day))
        await queue.append(Self.event(5, at: now + 31 * day))

        #expect(Self.numbers(await queue.nextBatch()) == [2, 3, 4])
        #expect(await queue.count == 3)
        #expect(await TelemetryQueue(fileURL: url, now: { now }).count == 3)
    }

    @Test("removeAll vacía la cola y borra el archivo")
    func removeAllPurges() async {
        let url = Self.fileURL()
        let queue = TelemetryQueue(fileURL: url)
        for number in 1...3 { await queue.append(Self.event(number)) }

        await queue.removeAll()

        #expect(await queue.count == 0)
        #expect(FileManager.default.fileExists(atPath: url.path()) == false)
        #expect(await TelemetryQueue(fileURL: url).count == 0)
    }

    @Test("el archivo de la cola queda fuera del backup de iCloud, también después de reescribirlo")
    func excludedFromBackup() async throws {
        let url = Self.fileURL()
        let queue = TelemetryQueue(fileURL: url)
        await queue.append(Self.event(1))
        await queue.append(Self.event(2))

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
}
