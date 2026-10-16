import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Ejemplos de la config remota (C3) para los tests de la personalización.
enum PersonalizationFixtures {
    /// C2 válido: pesos que suman 1, umbrales en orden, países alfa-3.
    static let playerValue = """
    {"version":"seed-2026-10-16","countryTier":{"USA":1,"GBR":1,"ARG":3},"defaultCountryTier":3,
     "tierMicros":{"1":18000,"2":6000,"3":1500},"deviceTier":{"iPhone17,":1,"iPhone16,":1,"iPad":2},
     "defaultDeviceTier":3,"minOwnImpressions":5,"ownWeight":0.7,
     "engagement":{"sessionsFor1":14,"secondsFor1":900},
     "weights":{"value":0.6,"engagement":0.25,"purchase":0.15},
     "thresholds":{"mid":0.35,"high":0.7},"hysteresis":0.05}
    """

    /// `segments.json` válido: todo en la identidad.
    static let segments = """
    {"version":"seed-2026-10-16","segments":{"low":{},"mid":{},"high":{"forcedSpacingScale":1.5}}}
    """

    /// `segments` fuera de tope (×9 por video): no valida.
    static let segmentsOutOfCaps = """
    {"version":"x","segments":{"high":{"videoRewardMultiplier":{"offline":9}}}}
    """

    static func envelope(version: Int = 3, sections: [String: String]) -> String {
        let body = sections.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        return "{\"version\":\(version),\"sections\":{\(body)}}"
    }

    static let full = envelope(sections: ["player_value": playerValue, "segments": segments])
}

@Suite("Personalización: la config y sus secciones")
struct PersonalizationConfigTests {
    @Test("decodifica el envoltorio y cada fase saca su sección")
    func decodesSections() throws {
        let config = try #require(PersonalizationConfig.decode(Data(PersonalizationFixtures.full.utf8)))
        #expect(config.version == 3)
        #expect(config.sectionKeys == ["player_value", "segments"])

        let tables = try #require(config.section("player_value", as: PlayerValueTables.self))
        #expect(tables.version == "seed-2026-10-16")
        let levers = try #require(config.section("segments", as: SegmentLevers.self))
        #expect(levers.levers(for: .high).forcedSpacingScale == 1.5)
    }

    @Test("una sección que falta es nil; las demás siguen")
    func missingSectionIsNil() throws {
        let config = try #require(PersonalizationConfig.decode(Data(PersonalizationFixtures.full.utf8)))
        #expect(config.section("moments", as: SegmentLevers.self) == nil)
        #expect(config.section("segments", as: SegmentLevers.self) != nil)
    }

    @Test("una sección que no valida es nil; las demás quedan intactas")
    func invalidSectionIsNilOthersIntact() throws {
        let json = PersonalizationFixtures.envelope(sections: [
            "player_value": PersonalizationFixtures.playerValue,
            "segments": PersonalizationFixtures.segmentsOutOfCaps,
        ])
        let config = try #require(PersonalizationConfig.decode(Data(json.utf8)))
        #expect(config.section("segments", as: SegmentLevers.self) == nil)
        #expect(config.section("player_value", as: PlayerValueTables.self) != nil)
    }

    @Test("una sección que no decodifica con el tipo pedido es nil")
    func undecodableSectionIsNil() throws {
        let json = PersonalizationFixtures.envelope(sections: ["player_value": "{\"version\":\"x\"}", "segments": "[1,2]"])
        let config = try #require(PersonalizationConfig.decode(Data(json.utf8)))
        #expect(config.section("player_value", as: PlayerValueTables.self) == nil)
        #expect(config.section("segments", as: SegmentLevers.self) == nil)
    }

    @Test("pesos de PlayerValueTables que no suman 1: la sección no pasa validate()")
    func playerValueValidationApplies() throws {
        let broken = PersonalizationFixtures.playerValue.replacingOccurrences(of: "\"value\":0.6", with: "\"value\":0.9")
        let json = PersonalizationFixtures.envelope(sections: ["player_value": broken])
        let config = try #require(PersonalizationConfig.decode(Data(json.utf8)))
        #expect(config.section("player_value", as: PlayerValueTables.self) == nil)
    }

    @Test("lo que no es un objeto con sections no es una config", arguments: [
        "null", "[]", "{}", "{\"version\":3}", "{\"version\":3,\"sections\":[]}", "{\"sections\":", "true",
        "{\"version\":\"tres\",\"sections\":{}}",
    ])
    func rejectsNonEnvelopes(body: String) {
        #expect(PersonalizationConfig.decode(Data(body.utf8)) == nil)
    }

    @Test("sin version cuenta como 0; sections vacío es una config válida y vacía")
    func emptyConfig() throws {
        let config = try #require(PersonalizationConfig.decode(Data("{\"sections\":{}}".utf8)))
        #expect(config.version == 0)
        #expect(config.sectionKeys.isEmpty)
    }
}

@Suite("Personalización: el cargador de la config remota")
struct PersonalizationConfigLoaderTests {
    /// Un Supabase de mentira para `rpc/personalization_config`.
    final class FakeServer: @unchecked Sendable {
        enum Reply: Sendable {
            case status(Int, body: String, url: String = "https://proyecto.supabase.co/rest/v1/rpc/personalization_config")
            case failure(URLError)
        }

        private let lock = NSLock()
        private var seen: [URLRequest] = []
        private var next: Reply

        init(_ reply: Reply) { next = reply }

        var requests: [URLRequest] { lock.withLock { seen } }

        func answer(_ reply: Reply) { lock.withLock { next = reply } }

        var fetch: TelemetryNetwork.Fetch {
            { [self] request in
                let reply = lock.withLock { () -> Reply in
                    seen.append(request)
                    return next
                }
                switch reply {
                case .failure(let error):
                    throw error
                case .status(let code, let body, let url):
                    let response = HTTPURLResponse(url: URL(string: url)!, statusCode: code, httpVersion: nil, headerFields: nil)!
                    return (Data(body.utf8), response)
                }
            }
        }
    }

    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var current = Date(timeIntervalSince1970: 1_790_000_000)
        var now: Date { lock.withLock { current } }
        func advance(_ seconds: TimeInterval) { lock.withLock { current = current.addingTimeInterval(seconds) } }
    }

    static let rankingConfig = RankingConfig(
        schemaVersion: 1, enabled: true, baseURL: URL(string: "https://proyecto.supabase.co"), anonKey: "sb_publishable_test"
    )

    /// Una carpeta temporal propia por test: la caché y los archivos del «bundle».
    struct Sandbox {
        let folder: URL
        var cacheURL: URL { folder.appending(path: "personalization-config.json") }

        init() throws {
            folder = FileManager.default.temporaryDirectory.appending(path: "personalization-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        func write(_ text: String, named name: String) throws -> URL {
            let url = folder.appending(path: name)
            try Data(text.utf8).write(to: url)
            return url
        }

        var cacheExists: Bool { FileManager.default.fileExists(atPath: cacheURL.path()) }
    }

    private func makeLoader(
        _ server: FakeServer, sandbox: Sandbox, bundled: [String: URL] = [:], clock: Clock = Clock(),
        config: RankingConfig? = PersonalizationConfigLoaderTests.rankingConfig
    ) -> PersonalizationConfigLoader {
        PersonalizationConfigLoader(
            config: config, cacheURL: sandbox.cacheURL, bundledSections: bundled,
            fetch: server.fetch, now: { clock.now }
        )
    }

    @Test("un objeto con sections: prendido, a la caché y current() lo devuelve; el POST va a rpc/personalization_config")
    func objectTurnsOnAndCaches() async throws {
        let sandbox = try Sandbox()
        let server = FakeServer(.status(200, body: PersonalizationFixtures.full))
        let loader = makeLoader(server, sandbox: sandbox)

        #expect(await loader.isEnabled == false)
        #expect(await loader.refresh(force: true) == .enabled)
        #expect(await loader.isEnabled)
        #expect(sandbox.cacheExists)
        #expect(await loader.current() == PersonalizationConfig.decode(Data(PersonalizationFixtures.full.utf8)))

        let request = try #require(server.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://proyecto.supabase.co/rest/v1/rpc/personalization_config")
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(request.httpBody == Data("{}".utf8))
    }

    @Test("null del servidor = apagado y borra la caché (el interruptor manda sobre la caché)")
    func nullTurnsOffAndClearsCache() async throws {
        let sandbox = try Sandbox()
        let server = FakeServer(.status(200, body: PersonalizationFixtures.full))
        let loader = makeLoader(server, sandbox: sandbox)
        #expect(await loader.refresh(force: true) == .enabled)

        server.answer(.status(200, body: "null"))
        #expect(await loader.refresh(force: true) == .disabled)
        #expect(await loader.isEnabled == false)
        #expect(!sandbox.cacheExists)
        #expect(await loader.current().sectionKeys.isEmpty)
    }

    @Test("500, sin red o timeout: queda lo anterior (estado y caché)", arguments: [
        FakeServer.Reply.status(500, body: "null"),
        .status(404, body: "null"),
        .failure(URLError(.notConnectedToInternet)),
        .failure(URLError(.timedOut)),
    ])
    func failuresKeepPrevious(reply: FakeServer.Reply) async throws {
        let sandbox = try Sandbox()
        let server = FakeServer(.status(200, body: PersonalizationFixtures.full))
        let loader = makeLoader(server, sandbox: sandbox)
        #expect(await loader.refresh(force: true) == .enabled)
        let before = await loader.current()

        server.answer(reply)
        #expect(await loader.refresh(force: true) == .kept)
        #expect(await loader.isEnabled)
        #expect(sandbox.cacheExists)
        #expect(await loader.current() == before)
    }

    @Test("más de 64 KB, http://, JSON roto o sin sections: queda la caché anterior", arguments: [
        FakeServer.Reply.status(200, body: "{\"version\":4,\"sections\":{},\"pad\":\"" + String(repeating: "x", count: 64 * 1024) + "\"}"),
        .status(200, body: PersonalizationFixtures.envelope(version: 4, sections: [:]), url: "http://proyecto.supabase.co/rest/v1/rpc/personalization_config"),
        .status(200, body: "{\"version\":4,\"sections\":"),
        .status(200, body: "{\"version\":4}"),
        .status(200, body: "[]"),
        .status(200, body: "\"null\""),
    ])
    func badBodiesKeepPrevious(reply: FakeServer.Reply) async throws {
        let sandbox = try Sandbox()
        let server = FakeServer(.status(200, body: PersonalizationFixtures.full))
        let loader = makeLoader(server, sandbox: sandbox)
        #expect(await loader.refresh(force: true) == .enabled)
        let cached = try Data(contentsOf: sandbox.cacheURL)

        server.answer(reply)
        #expect(await loader.refresh(force: true) == .kept)
        #expect(await loader.isEnabled)
        #expect(try Data(contentsOf: sandbox.cacheURL) == cached)
        #expect(await loader.current().version == 3)
    }

    @Test("una respuesta mala sin nada anterior deja todo apagado y sin caché")
    func badBodyFromScratchStaysOff() async throws {
        let sandbox = try Sandbox()
        let loader = makeLoader(FakeServer(.status(200, body: "{roto")), sandbox: sandbox)
        #expect(await loader.refresh(force: true) == .kept)
        #expect(await loader.isEnabled == false)
        #expect(!sandbox.cacheExists)
    }

    @Test("una sección inválida en lo remoto: esa sección nil, las demás intactas")
    func invalidRemoteSection() async throws {
        let sandbox = try Sandbox()
        let body = PersonalizationFixtures.envelope(sections: [
            "player_value": PersonalizationFixtures.playerValue,
            "segments": PersonalizationFixtures.segmentsOutOfCaps,
        ])
        let loader = makeLoader(FakeServer(.status(200, body: body)), sandbox: sandbox)
        #expect(await loader.refresh(force: true) == .enabled)

        let config = await loader.current()
        #expect(config.section("segments", as: SegmentLevers.self) == nil)
        #expect(config.section("player_value", as: PlayerValueTables.self) != nil)
    }

    @Test("sin caché, current() arma el envoltorio con los archivos del bundle que existan")
    func bundleFallback() async throws {
        let sandbox = try Sandbox()
        let bundled = try [
            "player_value": sandbox.write(PersonalizationFixtures.playerValue, named: "player_value.json"),
            "segments": sandbox.write(PersonalizationFixtures.segments, named: "segments.json"),
            "moments": sandbox.folder.appending(path: "no-existe.json"),
        ]
        let loader = makeLoader(FakeServer(.failure(URLError(.notConnectedToInternet))), sandbox: sandbox, bundled: bundled)

        let config = await loader.current()
        #expect(config.version == 0)
        #expect(config.sectionKeys == ["player_value", "segments"])
        #expect(config.section("player_value", as: PlayerValueTables.self) != nil)
        #expect(config.section("segments", as: SegmentLevers.self) != nil)
        #expect(await loader.isEnabled == false)
    }

    @Test("una caché ilegible cae al bundle")
    func corruptCacheFallsBackToBundle() async throws {
        let sandbox = try Sandbox()
        try Data("{roto".utf8).write(to: sandbox.cacheURL)
        let bundled = try ["segments": sandbox.write(PersonalizationFixtures.segments, named: "segments.json")]
        let loader = makeLoader(FakeServer(.status(500, body: "")), sandbox: sandbox, bundled: bundled)
        #expect(await loader.current().sectionKeys == ["segments"])
    }

    @Test("sin RankingConfig usable no pregunta y queda apagado")
    func unusableConfigNeverAsks() async throws {
        let sandbox = try Sandbox()
        let server = FakeServer(.status(200, body: PersonalizationFixtures.full))
        let configs: [RankingConfig?] = [
            nil,
            RankingConfig(schemaVersion: 1, enabled: false, baseURL: URL(string: "https://x.supabase.co"), anonKey: "k"),
            RankingConfig(schemaVersion: 1, enabled: true, baseURL: URL(string: "http://x.supabase.co"), anonKey: "k"),
        ]
        for config in configs {
            let loader = makeLoader(server, sandbox: sandbox, config: config)
            #expect(await loader.refresh(force: true) == .kept)
            #expect(await loader.isEnabled == false)
        }
        #expect(server.requests.isEmpty)
        #expect(!sandbox.cacheExists)
    }

    @Test("refresca como mucho cada 6 h; force pregunta siempre")
    func refreshesAtMostEverySixHours() async throws {
        let sandbox = try Sandbox()
        let clock = Clock()
        let server = FakeServer(.status(200, body: PersonalizationFixtures.full))
        let loader = makeLoader(server, sandbox: sandbox, clock: clock)

        #expect(await loader.refresh(force: false) == .enabled)
        clock.advance(5 * 60 * 60)
        #expect(await loader.refresh(force: false) == .notDue)
        #expect(server.requests.count == 1)
        #expect(await loader.refresh(force: true) == .enabled)
        #expect(server.requests.count == 2)
        clock.advance(6 * 60 * 60)
        #expect(await loader.refresh(force: false) == .enabled)
        #expect(server.requests.count == 3)
    }

    @Test("una pregunta sin respuesta no cuenta para las 6 h: la próxima vuelta pregunta de nuevo")
    func unansweredDoesNotCount() async throws {
        let sandbox = try Sandbox()
        let server = FakeServer(.failure(URLError(.notConnectedToInternet)))
        let loader = makeLoader(server, sandbox: sandbox)
        #expect(await loader.refresh(force: false) == .kept)
        server.answer(.status(200, body: PersonalizationFixtures.full))
        #expect(await loader.refresh(force: false) == .enabled)
        #expect(server.requests.count == 2)
    }
}
