import Foundation
import Testing
@testable import FisuEvolution

@Suite("Telemetría: el interruptor remoto")
struct TelemetrySwitchTests {
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var current = Date(timeIntervalSince1970: 1_790_000_000)
        var now: Date { lock.withLock { current } }
        func advance(_ seconds: TimeInterval) { lock.withLock { current = current.addingTimeInterval(seconds) } }
    }

    @Test("true prendido: el POST va a rpc/telemetry_enabled con la clave anónima")
    func explicitTrueIsOn() async throws {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let telemetrySwitch = TelemetrySwitch(config: TelemetryFakeNetwork.config, fetch: network.fetch)

        #expect(await telemetrySwitch.refresh(force: true))
        #expect(await telemetrySwitch.isEnabled)

        let request = try #require(network.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://proyecto.supabase.co/rest/v1/rpc/telemetry_enabled")
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpShouldHandleCookies == false)
        #expect(request.timeoutInterval == 10)
    }

    @Test("false, 404, sin red, timeout o un cuerpo que no es un booleano: apagado", arguments: [
        TelemetryFakeNetwork.Reply.status(200, body: "false"),
        .status(404, body: "true"),
        .status(503, body: "true"),
        .failure(URLError(.notConnectedToInternet)),
        .failure(URLError(.timedOut)),
        .status(200, body: "null"),
        .status(200, body: "\"true\""),
        .status(200, body: "<html>"),
    ])
    func anythingElseIsOff(reply: TelemetryFakeNetwork.Reply) async {
        let network = TelemetryFakeNetwork()
        network.answerSwitch(reply)
        let telemetrySwitch = TelemetrySwitch(config: TelemetryFakeNetwork.config, fetch: network.fetch)

        #expect(await telemetrySwitch.refresh(force: true) == false)
        #expect(await telemetrySwitch.isEnabled == false)
    }

    @Test("sin RankingConfig usable (nula, apagada, http:// o sin clave) no pregunta y queda apagado")
    func unusableConfigIsOff() async {
        let configs: [RankingConfig?] = [
            nil,
            RankingConfig(schemaVersion: 1, enabled: false, baseURL: URL(string: "https://x.supabase.co"), anonKey: "k"),
            RankingConfig(schemaVersion: 1, enabled: true, baseURL: URL(string: "http://x.supabase.co"), anonKey: "k"),
            RankingConfig(schemaVersion: 1, enabled: true, baseURL: URL(string: "https://x.supabase.co"), anonKey: ""),
            RankingConfig(schemaVersion: 1, enabled: true, baseURL: nil, anonKey: "k"),
        ]
        for config in configs {
            let network = TelemetryFakeNetwork(switchBody: "true")
            let telemetrySwitch = TelemetrySwitch(config: config, fetch: network.fetch)
            #expect(await telemetrySwitch.refresh(force: true) == false)
            #expect(network.requests.isEmpty)
        }
    }

    @Test("una respuesta que termina en http:// es apagado")
    func downgradedResponseIsOff() async {
        let telemetrySwitch = TelemetrySwitch(config: TelemetryFakeNetwork.config) { _ in
            (Data("true".utf8),
             HTTPURLResponse(url: URL(string: "http://x.test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        #expect(await telemetrySwitch.refresh(force: true) == false)
    }

    @Test("la respuesta se guarda 6 h: antes no re-pregunta, después sí")
    func cachesForSixHours() async {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let clock = Clock()
        let telemetrySwitch = TelemetrySwitch(config: TelemetryFakeNetwork.config, fetch: network.fetch) { clock.now }

        await telemetrySwitch.refresh(force: true)
        clock.advance(TelemetrySwitch.maxAge - 1)
        #expect(await telemetrySwitch.refresh(force: false))
        #expect(network.switchQueries.count == 1)

        network.answerSwitch(.status(200, body: "false"))
        clock.advance(1)
        #expect(await telemetrySwitch.refresh(force: false) == false)
        #expect(network.switchQueries.count == 2)
    }

    @Test("una pregunta sin respuesta apaga, y la vuelta siguiente pregunta de nuevo")
    func unansweredAsksAgain() async {
        let network = TelemetryFakeNetwork()
        network.answerSwitch(.failure(URLError(.notConnectedToInternet)))
        let telemetrySwitch = TelemetrySwitch(config: TelemetryFakeNetwork.config, fetch: network.fetch)

        #expect(await telemetrySwitch.refresh(force: true) == false)
        network.answerSwitch(.status(200, body: "true"))
        #expect(await telemetrySwitch.refresh(force: false))
        #expect(network.switchQueries.count == 2)
    }
}
