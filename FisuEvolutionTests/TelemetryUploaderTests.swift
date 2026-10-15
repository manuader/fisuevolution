import Foundation
import Testing
@testable import FisuEvolution

@Suite("Telemetría: el envío")
struct TelemetryUploaderTests {
    private static func event(_ number: Int) -> TelemetryEvent {
        TelemetryEvent(
            .sessionStart(number: number), installId: "11111111-2222-4333-8444-555555555555",
            sessionId: UUID(), at: Date(), device: TelemetryFakeNetwork.device)
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

    @Test("5xx, 408, 429 o sin red conserva el lote en la cola", arguments: [
        TelemetryFakeNetwork.Reply.status(500, body: ""),
        .status(503, body: ""),
        .status(408, body: ""),
        .status(429, body: ""),
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

    @Test("un lote que no se puede codificar se descarta sin pedir nada (como un 4xx)")
    func unencodableBatchDrops() async throws {
        let network = TelemetryFakeNetwork()
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let broken = try Self.eventWithNaN()
        await queue.append(broken)
        let uploader = TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch)

        #expect(await uploader.upload([broken]) == .unencodable)
        #expect(await uploader.drain(queue) == .drained)
        #expect(await queue.count == 0)
        #expect(network.requests.isEmpty)
    }

    /// Un evento con un `NaN` en `props`: `JSONEncoder` no lo puede escribir. Por la puerta de
    /// `TelemetryPayload` no se arma; se lee con un decoder que acepta «nan».
    private static func eventWithNaN() throws -> TelemetryEvent {
        let json = """
        {"install_id": "11111111-2222-4333-8444-555555555555", "session_id": "0b7d9a1e-6c3f-4e2a-8d5b-7f1a2c3d4e5f",
         "client_ts": "\(ISO8601DateFormatter().string(from: Date()))", "name": "session_end",
         "app_version": "2.0", "build": "42", "os_version": "18.2", "device_model": "iPhone16,2", "storefront": null,
         "props": {"seconds": "nan"}}
        """
        let decoder = TelemetryEvent.makeDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        let event = try decoder.decode(TelemetryEvent.self, from: Data(json.utf8))
        guard case .double(let value) = event.props["seconds"], value.isNaN else {
            throw CocoaError(.coderInvalidValue)
        }
        return event
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
