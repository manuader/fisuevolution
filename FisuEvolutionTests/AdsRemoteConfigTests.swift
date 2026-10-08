import Foundation
import Testing
@testable import FisuEvolution

/// La config remota de anuncios (PLAN-v2, E7): sólo HTTPS, cada ID del
/// publisher propio, todo o nada, caché + respaldo del bundle, y sin red en el
/// arranque.
///
/// La red está inyectada: cada test decide qué "contesta el sitio" con un
/// fixture, y la caché vive en un directorio temporal propio del test.
@Suite("Config remota de anuncios")
struct AdsRemoteConfigTests {

    // MARK: - Los cinco fixtures del encargo

    @Test("un archivo válido se acepta, queda en la caché y rige desde ahí")
    func aValidFileIsAcceptedAndCached() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Fixture.serving(Fixture.valid()))

        let outcome = await loader.refresh()

        guard case .updated(let config) = outcome else {
            Issue.record("se esperaba .updated y llegó \(outcome)")
            return
        }
        #expect(config.cadence.minSecondsBetweenForced == 120)
        #expect(FileManager.default.fileExists(atPath: sandbox.cacheURL.path))
        #expect(loader.current() == AdsRemoteConfigLoader.Loaded(config: config, source: .cache))
    }

    @Test("con UN ID de otro publisher se descarta el archivo entero")
    func aForeignAdUnitDiscardsTheWholeFile() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let foreign = "ca-app-pub-1111111111111111/2222222222"
        let loader = sandbox.loader(fetch: Fixture.serving(Fixture.valid(rewardedWheel: "\"\(foreign)\"")))

        #expect(await loader.refresh() == .rejected(.foreignAdUnit(foreign)))
        #expect(!FileManager.default.fileExists(atPath: sandbox.cacheURL.path))
        #expect(loader.current()?.source == .bundle)
    }

    @Test("una URL http:// no se pide nunca")
    func plainHTTPIsNeverRequested() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let spy = FetchSpy()
        let loader = sandbox.loader(
            remoteURL: URL(string: "http://adergames-site.vercel.app/config/ads.json")!,
            fetch: Fixture.serving(Fixture.valid(), spy: spy)
        )

        #expect(await loader.refresh() == .rejected(.notHTTPS))
        #expect(spy.requests.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sandbox.cacheURL.path))
    }

    @Test("un JSON roto se descarta")
    func brokenJSONIsRejected() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Fixture.serving(Data(#"{"schemaVersion": 1, "adUnitIDs": {"#.utf8)))

        #expect(await loader.refresh() == .rejected(.undecodable))
        #expect(loader.current()?.source == .bundle)
    }

    @Test("sin red y sin caché rige el respaldo del bundle")
    func networkDownFallsBackToTheBundle() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Fixture.networkDown)

        #expect(await loader.refresh() == .unreachable)
        let loaded = try #require(loader.current())
        #expect(loaded.source == .bundle)
        #expect(loaded.config.adUnitIDs.interstitial == "ca-app-pub-8575641544774372/5270838626")
    }

    // MARK: - La caché

    @Test("sin red pero con una caché buena, rige la caché")
    func networkDownKeepsAGoodCache() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let tuned = Fixture.valid(minSecondsBetweenForced: 300)
        #expect(await sandbox.loader(fetch: Fixture.serving(tuned)).refresh() != .unreachable)

        let offline = sandbox.loader(fetch: Fixture.networkDown)
        #expect(await offline.refresh() == .unreachable)
        let loaded = try #require(offline.current())
        #expect(loaded.source == .cache)
        #expect(loaded.config.cadence.minSecondsBetweenForced == 300)
    }

    @Test("un archivo malo publicado después no pisa la última caché buena")
    func aBadFileNeverOverwritesAGoodCache() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let good = Fixture.valid(minSecondsBetweenForced: 300)
        _ = await sandbox.loader(fetch: Fixture.serving(good)).refresh()
        let cached = try Data(contentsOf: sandbox.cacheURL)

        let bad = Fixture.valid(interstitial: "\"ca-app-pub-1111111111111111/5270838626\"")
        _ = await sandbox.loader(fetch: Fixture.serving(bad)).refresh()

        #expect(try Data(contentsOf: sandbox.cacheURL) == cached)
        #expect(sandbox.loader(fetch: Fixture.networkDown).current()?.source == .cache)
    }

    /// Una caché escrita por un build anterior puede no cumplir las reglas de
    /// este: se revalida al leerla.
    @Test("una caché que ya no valida se ignora y rige el bundle")
    func anInvalidCacheIsIgnored() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try Fixture.valid(minSecondsBetweenForced: 30).write(to: sandbox.cacheURL)

        #expect(sandbox.loader(fetch: Fixture.networkDown).current()?.source == .bundle)
    }

    // MARK: - El resto de lo que se descarta

    @Test("una redirección que termina en http:// se descarta")
    func aRedirectToPlainHTTPIsRejected() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let downgraded = URL(string: "http://adergames-site.vercel.app/config/ads.json")!
        let loader = sandbox.loader(fetch: Fixture.serving(Fixture.valid(), finalURL: downgraded))

        #expect(await loader.refresh() == .rejected(.notHTTPS))
        #expect(!FileManager.default.fileExists(atPath: sandbox.cacheURL.path))
    }

    @Test("un estado distinto de 200 se descarta, aunque traiga un cuerpo válido")
    func aNon200IsRejected() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let loader = sandbox.loader(fetch: Fixture.serving(Fixture.valid(), status: 404))
        #expect(await loader.refresh() == .rejected(.badResponse))
    }

    @Test("un cuerpo de más de 64 KB se descarta sin decodificarlo")
    func anOversizedBodyIsRejected() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let huge = Data(repeating: 0x20, count: AdsRemoteConfigLoader.maxBytes + 1)
        let loader = sandbox.loader(fetch: Fixture.serving(huge))
        #expect(await loader.refresh() == .rejected(.tooLarge))
    }

    /// Lo remoto puede espaciar más los anuncios, nunca menos que las
    /// decisiones del dueño (PLAN-v2 §2).
    @Test("lo remoto no puede ser más agresivo que las decisiones del dueño", arguments: [
        (Fixture.valid(minSecondsBetweenForced: 60), "cadence.minSecondsBetweenForced"),
        (Fixture.valid(graceSecondsAfterRewarded: 30), "cadence.graceSecondsAfterRewarded"),
        (Fixture.valid(appOpenMinSecondsAway: 60), "appOpen.minSecondsAway"),
        (Fixture.valid(appOpenMinSecondsBetween: 600), "appOpen.minSecondsBetween"),
        (Fixture.valid(appOpenMinSessionNumber: 1), "appOpen.minSessionNumber"),
        (Fixture.valid(graceSecondsAfterLaunch: -1), "cadence.graceSecondsAfterLaunch"),
    ])
    func floorsAreEnforced(file: Data, field: String) {
        #expect(throws: AdsRemoteConfig.Rejection.belowFloor(field)) {
            try AdsRemoteConfig.decodeValidated(file, publisherID: Fixture.publisher)
        }
    }

    @Test("el app open no entra en la alternancia, y la alternancia no puede venir vacía",
          arguments: [#"["interstitial", "appOpen"]"#, "[]"])
    func alternationIsValidated(alternation: String) {
        #expect(throws: AdsRemoteConfig.Rejection.invalidAlternation) {
            try AdsRemoteConfig.decodeValidated(Fixture.valid(alternation: alternation), publisherID: Fixture.publisher)
        }
    }

    @Test("los códigos de tienda son ISO alfa-3 en mayúsculas")
    func storefrontCodesAreValidated() {
        #expect(throws: AdsRemoteConfig.Rejection.invalidStorefront("be")) {
            try AdsRemoteConfig.decodeValidated(Fixture.valid(storefronts: #"["be"]"#), publisherID: Fixture.publisher)
        }
    }

    @Test("un esquema que este build no conoce se descarta")
    func anUnknownSchemaIsRejected() {
        #expect(throws: AdsRemoteConfig.Rejection.unsupportedSchema(2)) {
            try AdsRemoteConfig.decodeValidated(Fixture.valid(schemaVersion: 2), publisherID: Fixture.publisher)
        }
    }

    @Test("sin publisher propio no se acepta nada")
    func withoutAPublisherNothingIsAccepted() {
        #expect(throws: AdsRemoteConfig.Rejection.unknownPublisher) {
            try AdsRemoteConfig.decodeValidated(Fixture.valid(), publisherID: nil)
        }
    }

    // MARK: - Privacidad y arranque

    @Test("el pedido es un GET pelado: sin query, sin cuerpo, sin headers, sin cookies")
    func theRequestCarriesNoPlayerData() async throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let spy = FetchSpy()
        let loader = sandbox.loader(remoteURL: AdsRemoteConfigLoader.productionURL,
                                    fetch: Fixture.serving(Fixture.valid(), spy: spy))

        _ = await loader.refresh()

        let request = try #require(spy.requests.first)
        #expect(spy.requests.count == 1)
        #expect(request.url == URL(string: "https://adergames-site.vercel.app/config/ads.json"))
        #expect(request.url?.query == nil)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.allHTTPHeaderFields?.isEmpty ?? true)
        #expect(!request.httpShouldHandleCookies)
    }

    @Test("leer la config al arrancar no toca la red")
    func currentNeverTouchesTheNetwork() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let spy = FetchSpy()
        let loader = sandbox.loader(fetch: Fixture.serving(Fixture.valid(), spy: spy))

        _ = loader.current()

        #expect(spy.requests.isEmpty)
    }

    // MARK: - El publisher y el respaldo embarcado

    @Test("el publisher sale del App ID, con su ~, y nada que no sea uno")
    func publisherIsParsedFromTheAppID() {
        #expect(AdsRemoteConfig.publisherID(fromAppID: "ca-app-pub-8575641544774372~3243441080") == "8575641544774372")
        #expect(AdsRemoteConfig.publisherID(fromAppID: "ca-app-pub-8575641544774372/3243441080") == nil)
        #expect(AdsRemoteConfig.publisherID(fromAppID: "ca-app-pub-~3243441080") == nil)
        #expect(AdsRemoteConfig.publisherID(fromAppID: "") == nil)
    }

    @Test("el publisher propio es el del Info.plist")
    func ownPublisherComesFromTheInfoPlist() {
        #expect(AdsRemoteConfig.ownPublisherID == "8575641544774372")
    }

    @Test("un ID de unidad es del publisher, con una barra y sólo dígitos después")
    func adUnitShape() {
        let publisher = Fixture.publisher
        #expect(AdsRemoteConfig.isAdUnit("ca-app-pub-8575641544774372/5270838626", of: publisher))
        #expect(!AdsRemoteConfig.isAdUnit("ca-app-pub-8575641544774372~5270838626", of: publisher))
        #expect(!AdsRemoteConfig.isAdUnit("ca-app-pub-8575641544774372/", of: publisher))
        #expect(!AdsRemoteConfig.isAdUnit("ca-app-pub-8575641544774372/52708x8626", of: publisher))
        #expect(!AdsRemoteConfig.isAdUnit("ca-app-pub-3940256099942544/4411468910", of: publisher))
    }

    /// El respaldo del bundle es lo que rige sin red: tiene que validar contra
    /// el publisher real y decir lo mismo que `feature_flags.json`, o los dos
    /// archivos se desincronizan en silencio.
    @Test("el ads.json embarcado es válido y sus IDs son los de feature_flags.json")
    func theBundledFallbackIsValidAndInSync() throws {
        let url = try #require(Bundle.main.url(forResource: "ads", withExtension: "json"))
        let config = try AdsRemoteConfig.decodeValidated(Data(contentsOf: url), publisherID: AdsRemoteConfig.ownPublisherID)
        let flags = try GameContentLoader.load(from: .main).flags

        #expect(config.adUnitIDs == flags.declaredAdUnitIDs)
        // El gate del dueño se cumplió el 2026-10-08: la unidad de app open
        // existe (release.json) y el setup pide prenderlo con ella.
        #expect(config.switches.appOpen == true)
        #expect(config.adUnitIDs.appOpen == "ca-app-pub-8575641544774372/3573507326")
        #expect(config.isRestricted(storefront: "BEL"))
        #expect(config.isRestricted(storefront: "aus"))
        #expect(!config.isRestricted(storefront: "ARG"))
    }
}

// MARK: - Andamio

/// Los archivos que "publica el sitio" en cada test.
private enum Fixture {
    static let publisher = "8575641544774372"

    static func valid(
        schemaVersion: Int = 1,
        interstitial: String = "\"ca-app-pub-8575641544774372/5270838626\"",
        rewardedWheel: String = "null",
        minSecondsBetweenForced: Double = 120,
        graceSecondsAfterLaunch: Double = 180,
        graceSecondsAfterRewarded: Double = 90,
        alternation: String = #"["interstitial", "rewardedInterstitial"]"#,
        appOpenMinSecondsAway: Double = 180,
        appOpenMinSecondsBetween: Double = 1200,
        appOpenMinSessionNumber: Int = 2,
        storefronts: String = #"["BEL", "AUS"]"#
    ) -> Data {
        Data("""
        {
          "schemaVersion": \(schemaVersion),
          "adUnitIDs": {
            "rewardedGifts": "ca-app-pub-8575641544774372/8304196070",
            "rewardedWheel": \(rewardedWheel),
            "interstitial": \(interstitial),
            "rewardedInterstitial": "ca-app-pub-8575641544774372/1615619906"
          },
          "cadence": {
            "minSecondsBetweenForced": \(minSecondsBetweenForced),
            "graceSecondsAfterLaunch": \(graceSecondsAfterLaunch),
            "graceSecondsAfterRewarded": \(graceSecondsAfterRewarded)
          },
          "alternation": \(alternation),
          "appOpen": {
            "minSecondsAway": \(appOpenMinSecondsAway),
            "minSecondsBetween": \(appOpenMinSecondsBetween),
            "minSessionNumber": \(appOpenMinSessionNumber)
          },
          "switches": {"interstitial": true, "rewardedInterstitial": true, "appOpen": false},
          "restrictedStorefronts": \(storefronts)
        }
        """.utf8)
    }

    /// Un sitio que contesta `data` con ese estado. `finalURL` simula una
    /// redirección: es la URL que trae la respuesta.
    static func serving(
        _ data: Data,
        status: Int = 200,
        finalURL: URL? = nil,
        spy: FetchSpy? = nil
    ) -> AdsRemoteConfigLoader.Fetch {
        { request in
            spy?.record(request)
            let url = finalURL ?? request.url!
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (data, response)
        }
    }

    static let networkDown: AdsRemoteConfigLoader.Fetch = { _ in
        throw URLError(.notConnectedToInternet)
    }
}

/// Anota los pedidos que llegan "al sitio".
private final class FetchSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { recorded } }

    func record(_ request: URLRequest) {
        lock.withLock { recorded.append(request) }
    }
}

/// Un directorio temporal por test, para la caché.
private struct Sandbox {
    let directory: URL
    var cacheURL: URL { directory.appending(path: "ads-remote-config.json") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ads-remote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Un loader contra el bundle real (el respaldo embarcado) y el publisher
    /// real, con la red y la caché de este test.
    func loader(
        remoteURL: URL = AdsRemoteConfigLoader.productionURL,
        fetch: @escaping AdsRemoteConfigLoader.Fetch
    ) -> AdsRemoteConfigLoader {
        AdsRemoteConfigLoader(
            remoteURL: remoteURL,
            publisherID: Fixture.publisher,
            cacheURL: cacheURL,
            bundledURL: Bundle.main.url(forResource: "ads", withExtension: "json"),
            fetch: fetch
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
