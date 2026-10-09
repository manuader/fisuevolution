import Foundation
import Testing
@testable import FisuEvolution

@Suite("Config del ranking")
struct RankingConfigTests {
    private static func json(enabled: Bool = true, base: String? = "https://x.supabase.co", key: String? = "k1") -> Data {
        func quoted(_ s: String?) -> String { s.map { "\"\($0)\"" } ?? "null" }
        return Data("""
        {"schemaVersion": 1, "enabled": \(enabled), "baseURL": \(quoted(base)), "anonKey": \(quoted(key))}
        """.utf8)
    }

    private struct Sandbox {
        let dir = FileManager.default.temporaryDirectory.appending(path: "ranking-config-\(UUID().uuidString)")
        var cacheURL: URL { dir.appending(path: "cache.json") }
        var bundleURL: URL { dir.appending(path: "bundle.json") }

        init(bundle: Data? = RankingConfigTests.json()) throws {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let bundle { try bundle.write(to: bundleURL) }
        }

        func remove() { try? FileManager.default.removeItem(at: dir) }

        func loader(remote: String = "https://adergames-site.vercel.app/config/ranking.json",
                    fetch: @escaping RankingConfigLoader.Fetch) -> RankingConfigLoader {
            RankingConfigLoader(remoteURL: URL(string: remote)!, cacheURL: cacheURL, bundledURL: bundleURL, fetch: fetch)
        }
    }

    private static func serving(_ data: Data, status: Int = 200, url: String = "https://adergames-site.vercel.app/config/ranking.json")
        -> RankingConfigLoader.Fetch {
        { request in
            let response = HTTPURLResponse(url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
    }

    @Test("el JSON que se embarca es válido, nace sin URL ni clave y no es usable")
    func shippedBundleIsValidAndInert() throws {
        let url = try #require(Bundle.main.url(forResource: "ranking", withExtension: "json"))
        let config = try RankingConfig.decodeValidated(Data(contentsOf: url))
        #expect(config.baseURL == nil)
        #expect(config.anonKey == nil)
        #expect(!config.isUsable)
    }

    @Test("isUsable pide enabled, https y clave")
    func isUsableRules() throws {
        func config(_ data: Data) throws -> RankingConfig { try RankingConfig.decodeValidated(data) }
        #expect(try config(Self.json()).isUsable)
        #expect(try !config(Self.json(enabled: false)).isUsable)
        #expect(try !config(Self.json(base: nil)).isUsable)
        #expect(try !config(Self.json(key: nil)).isUsable)
        #expect(try !config(Self.json(key: "")).isUsable)
    }

    @Test("sin caché rige el bundle")
    func bundleWhenNoCache() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loaded = try #require(sandbox.loader(fetch: Self.serving(Data())).current())
        #expect(loaded.source == .bundle)
    }

    @Test("un remoto válido queda en la caché y pisa al bundle")
    func validRemoteBecomesTheCache() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Self.serving(Self.json(base: "https://otro.supabase.co")))

        guard case .updated(let config) = await loader.refresh() else {
            Issue.record("se esperaba .updated")
            return
        }
        #expect(config.baseURL?.host == "otro.supabase.co")
        #expect(loader.current() == RankingConfigLoader.Loaded(config: config, source: .cache))
    }

    @Test("un remoto inválido no pisa la caché")
    func invalidRemoteKeepsTheCache() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        _ = await sandbox.loader(fetch: Self.serving(Self.json(base: "https://otro.supabase.co"))).refresh()
        let before = try Data(contentsOf: sandbox.cacheURL)

        let broken = sandbox.loader(fetch: Self.serving(Data("{roto".utf8)))
        #expect(await broken.refresh() == .rejected(.undecodable))
        #expect(try Data(contentsOf: sandbox.cacheURL) == before)
        #expect(broken.current()?.source == .cache)
    }

    @Test("un remoto con otra clave se rechaza")
    func foreignAnonKeyIsRejected() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Self.serving(Self.json(key: "otra-clave")))

        #expect(await loader.refresh() == .rejected(.foreignAnonKey))
        #expect(!FileManager.default.fileExists(atPath: sandbox.cacheURL.path))
    }

    @Test("un remoto que apaga el ranking se acepta")
    func remoteCanSwitchItOff() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Self.serving(Self.json(enabled: false)))

        guard case .updated(let config) = await loader.refresh() else {
            Issue.record("se esperaba .updated")
            return
        }
        #expect(!config.isUsable)
    }

    @Test("http:// no se pide, un estado distinto de 200 o un cuerpo enorme se rechazan, y sin red es unreachable")
    func transportRules() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let spy = Spy()
        let plain = sandbox.loader(remote: "http://adergames-site.vercel.app/config/ranking.json") { request in
            spy.record(request)
            return try await Self.serving(Self.json())(request)
        }
        #expect(await plain.refresh() == .rejected(.notHTTPS))
        #expect(spy.count == 0)

        #expect(await sandbox.loader(fetch: Self.serving(Self.json(), status: 404)).refresh() == .rejected(.badResponse))
        #expect(await sandbox.loader(fetch: Self.serving(Data(repeating: 0x20, count: 20_000))).refresh() == .rejected(.tooLarge))
        #expect(await sandbox.loader(fetch: Self.serving(Self.json(), url: "http://x.test/c.json")).refresh() == .rejected(.notHTTPS))
        #expect(await sandbox.loader(fetch: { _ in throw URLError(.notConnectedToInternet) }).refresh() == .unreachable)
    }
}

private final class Spy: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    var count: Int { lock.withLock { requests.count } }
    func record(_ request: URLRequest) { lock.withLock { requests.append(request) } }
}
