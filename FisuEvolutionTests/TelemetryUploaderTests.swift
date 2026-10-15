import Foundation
import Testing
@testable import FisuEvolution

@Suite("Telemetría: el envío")
struct TelemetryUploaderTests {
    private static func event(_ number: Int) -> TelemetryEvent {
        TelemetryEvent(
            .sessionStart(number: number), installId: "11111111-2222-4333-8444-555555555555",
            sessionId: UUID(), at: Date(timeIntervalSince1970: 1_790_000_000), device: TelemetryFakeNetwork.device)
    }

    private static func filledQueue(_ count: Int) async -> TelemetryQueue {
        let queue = TelemetryFakeNetwork.temporaryQueue()
        for number in 0..<count { await queue.append(event(number)) }
        return queue
    }

    @Test("el POST a la tabla lleva la clave anónima, JSON y Prefer: return=minimal; el cuerpo es el lote")
    func requestShape() async throws {
        let network = TelemetryFakeNetwork()
        let uploader = TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch)
        let events = [Self.event(1), Self.event(2)]

        #expect(await uploader.upload(events) == .accepted)

        let request = try #require(network.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://proyecto.supabase.co/rest/v1/telemetry_events")
        #expect(request.url?.query == nil)
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "return=minimal")
        #expect(request.httpShouldHandleCookies == false)
        let body = try #require(request.httpBody)
        #expect(try TelemetryEvent.makeDecoder().decode([TelemetryEvent].self, from: body) == events)
    }

    @Test("2xx confirma el lote y la cola queda vacía", arguments: [200, 201, 204])
    func successAcks(status: Int) async {
        let network = TelemetryFakeNetwork(insertStatus: status)
        let queue = await Self.filledQueue(3)

        let outcome = await TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch).drain(queue)

        #expect(outcome == .drained)
        #expect(await queue.count == 0)
        #expect(network.inserts.count == 1)
    }

    @Test("4xx descarta el lote: reintentarlo no lo arregla", arguments: [400, 401, 403, 409, 413])
    func clientErrorDrops(status: Int) async {
        let network = TelemetryFakeNetwork(insertStatus: status)
        let queue = await Self.filledQueue(3)
        let uploader = TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch)

        #expect(await uploader.upload([Self.event(1)]) == .rejected(status: status))
        #expect(await uploader.drain(queue) == .drained)
        #expect(await queue.count == 0)
    }

    @Test("5xx o sin red conserva el lote en la cola", arguments: [
        TelemetryFakeNetwork.Reply.status(500, body: ""),
        .status(503, body: ""),
        .failure(URLError(.notConnectedToInternet)),
        .failure(URLError(.timedOut)),
    ])
    func serverErrorKeeps(reply: TelemetryFakeNetwork.Reply) async {
        let network = TelemetryFakeNetwork()
        network.answerInserts(reply)
        let queue = await Self.filledQueue(3)

        let outcome = await TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch).drain(queue)

        #expect(outcome == .retryLater)
        #expect(await queue.count == 3)
        #expect(network.inserts.count == 1)
    }

    @Test("una cola de 120 sale en tres lotes de a 50 como mucho")
    func drainsInBatches() async throws {
        let network = TelemetryFakeNetwork()
        let queue = await Self.filledQueue(120)

        #expect(await TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch).drain(queue) == .drained)

        let sizes = try network.inserts.map { request -> Int in
            let body = try #require(request.httpBody)
            return try TelemetryEvent.makeDecoder().decode([TelemetryEvent].self, from: body).count
        }
        #expect(sizes == [50, 50, 20])
        #expect(await queue.count == 0)
    }

    @Test("sin config usable no pide nada y conserva la cola")
    func unusableConfigKeeps() async {
        let network = TelemetryFakeNetwork()
        let queue = await Self.filledQueue(2)

        #expect(await TelemetryUploader(config: nil, fetch: network.fetch).drain(queue) == .retryLater)
        #expect(network.requests.isEmpty)
        #expect(await queue.count == 2)
    }

    @Test("la espera entre intentos: 30 s, el doble cada vez, tope 30 min")
    func backoff() {
        #expect(TelemetryBackoff.delay(afterFailures: 0) == 0)
        #expect(TelemetryBackoff.delay(afterFailures: 1) == 30)
        #expect(TelemetryBackoff.delay(afterFailures: 2) == 60)
        #expect(TelemetryBackoff.delay(afterFailures: 6) == 960)
        #expect(TelemetryBackoff.delay(afterFailures: 7) == 1800)
        #expect(TelemetryBackoff.delay(afterFailures: 500) == 1800)
    }

    @MainActor
    @Test("el servicio no reintenta antes de que venza la espera")
    func serviceHonorsBackoff() async {
        let network = TelemetryFakeNetwork(switchBody: "true", insertStatus: 503)
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)

        service.start()
        service.record(.sessionStart(number: 1))
        service.flush()
        service.flush()
        await service.settle()

        #expect(network.inserts.count == 1)
        #expect(await queue.count == 1)
    }
}
