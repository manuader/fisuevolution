import Foundation
import Testing
@testable import FisuEvolution

/// Cómo arrancan los forzados de la 2.0 en un proceso (PLAN-v2 E7): con qué
/// política, desde qué config, y nunca bajo los tests salvo que lo pidan.
@Suite("Los forzados arrancan con la config que hay", .serialized)
@MainActor
struct ForcedAdsSetupTests {

    @Test("bajo XCTest no corren; bajo UI tests, sólo si el test los pide")
    func modeFollowsTheRun() {
        let xctest = ["XCTestConfigurationFilePath": "/tmp/fixture.xctestconfiguration"]
        #expect(ForcedAdsSetup.mode(arguments: [], environment: xctest) == .off)
        #expect(ForcedAdsSetup.mode(arguments: ["--uitest-reset"], environment: [:]) == .off)
        #expect(ForcedAdsSetup.mode(arguments: ["--uitest-reset", "--uitest-ad-break"], environment: [:]) == .uiTestAdBreak)
        #expect(ForcedAdsSetup.mode(arguments: [], environment: [:]) == .production)
    }

    @Test("en producción la política sale de la config; sin config, del respaldo de código")
    func productionPolicyComesFromTheConfig() throws {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let config = try Self.bundledConfig()

        let pacer = try #require(ForcedAdsSetup.makePacer(mode: .production, config: config, defaults: scratch.defaults))
        #expect(pacer.policy == NaturalBreakPolicy(config: config))

        let fallback = try #require(ForcedAdsSetup.makePacer(mode: .production, config: nil, defaults: scratch.defaults))
        #expect(fallback.policy == .default)

        #expect(ForcedAdsSetup.makePacer(mode: .off, config: config, defaults: scratch.defaults) == nil)
    }

    @Test("el pacer de los UI tests guarda aparte: no toca el reloj del jugador")
    func uiTestPacerUsesItsOwnKey() throws {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let pacer = try #require(ForcedAdsSetup.makePacer(mode: .uiTestAdBreak, config: nil, defaults: scratch.defaults))
        #expect(pacer.policy == ForcedAdsSetup.uiTestAdBreakPolicy)
        #expect(scratch.defaults.data(forKey: "ads.pacing") == nil)
        #expect(scratch.defaults.data(forKey: "ads.pacing.uitest") != nil)
    }

    @Test("una config nueva del sitio rige en el acto; una rechazada o la red caída, no")
    func refreshUpdatesThePolicy() throws {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let pacer = ForcedAdsPacer(policy: .default, store: AdsPacingStore(defaults: scratch.defaults))

        ForcedAdsSetup.apply(.unreachable, to: pacer)
        ForcedAdsSetup.apply(.rejected(.badResponse), to: pacer)
        #expect(pacer.policy == .default)

        let config = try Self.withCadence(try Self.bundledConfig(), minSecondsBetweenForced: 300)
        ForcedAdsSetup.apply(.updated(config), to: pacer)
        #expect(pacer.policy.minSecondsBetweenForced == 300)
    }

    @Test("en Release mandan los IDs del sitio; si no hay, el JSON; si tampoco, los de prueba")
    func releaseUnitIDs() {
        let remote = FeatureFlags.AdUnitIDs(rewardedGifts: "ca-app-pub-8575641544774372/1")
        let declared = FeatureFlags.AdUnitIDs(rewardedGifts: "ca-app-pub-8575641544774372/2")
        #expect(FeatureFlags.releaseAdUnitIDs(declared: declared, remote: remote) == remote)
        #expect(FeatureFlags.releaseAdUnitIDs(declared: declared, remote: nil) == declared)
        #expect(FeatureFlags.releaseAdUnitIDs(declared: nil, remote: nil) == .googleTest)
    }

    @Test("el coordinador dice qué forzados están listos, y ninguno con remove_ads")
    func readyForcedFormats() {
        let ads = AdsCoordinator(provider: ScriptedAdsProvider())
        #expect(ads.readyForcedFormats == Set(ForcedAdFormat.allCases))
        ads.setRemovedAds(true)
        #expect(ads.readyForcedFormats.isEmpty)
    }

    // MARK: - Andamio

    /// El `ads.json` embarcado, validado contra el publisher del `Info.plist`.
    private static func bundledConfig() throws -> AdsRemoteConfig {
        let loader = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "ads-\(UUID().uuidString).json")
        )
        return try #require(loader.current()?.config)
    }

    /// Una copia de la config con otra cadencia, por JSON (los tipos son `let`).
    private static func withCadence(_ config: AdsRemoteConfig, minSecondsBetweenForced: Double) throws -> AdsRemoteConfig {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var cadence = try #require(object["cadence"] as? [String: Any])
        cadence["minSecondsBetweenForced"] = minSecondsBetweenForced
        object["cadence"] = cadence
        return try JSONDecoder().decode(AdsRemoteConfig.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

/// Un dominio de `UserDefaults` descartable por test (copia de `ScratchPacingDefaults`).
private struct ScratchDefaults {
    let name = "e7b-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
