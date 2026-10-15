import Foundation
import Security
import Testing
@testable import FisuEvolution

/// La Opción A de privacidad: la telemetría exige más que «UMP deja pedir anuncios» y, ante la
/// duda, no pasa. Y su id no es el del ranking.
@MainActor
@Suite("Telemetría: el consentimiento y el id propio")
struct TelemetryConsentTests {
    /// Los diez propósitos de TCF dados.
    private static let all = "1111111111"
    /// Sólo el propósito 1: alcanza para que UMP deje pedir anuncios, no para las estadísticas.
    private static let storageOnly = "1000000000"

    // MARK: - La regla pura

    @Test("sin consentimiento de UMP no pasa nunca, aunque estén todos los propósitos")
    func umpNoIsNo() {
        for gdpr in [nil, 0, 1] as [Int?] {
            #expect(!TelemetryConsent.allows(
                gdprApplies: gdpr, purposeConsents: Self.all, umpCanRequestAds: false, umpSaysNotRequired: true))
        }
    }

    @Test("sin RGPD (gdprApplies = 0) alcanza con UMP")
    func noGDPR() {
        #expect(TelemetryConsent.allows(
            gdprApplies: 0, purposeConsents: nil, umpCanRequestAds: true, umpSaysNotRequired: false))
    }

    @Test("con RGPD exige los propósitos 1, 8, 9 y 10 a la vez", arguments: [
        ("1111111111", true),
        ("1000000111", true),
        ("10000001110", true),
        ("1000000000", false),
        ("0000000111", false),
        ("1000000011", false),
        ("1000000101", false),
        ("1000000110", false),
        ("100000011", false),
        ("", false),
    ])
    func gdprNeedsThePurposes(consents: String, expected: Bool) {
        #expect(TelemetryConsent.requiredPurposes == [1, 8, 9, 10])
        #expect(TelemetryConsent.allows(
            gdprApplies: 1, purposeConsents: consents, umpCanRequestAds: true, umpSaysNotRequired: false) == expected)
    }

    @Test("con RGPD y sin la tira de propósitos, no pasa")
    func gdprWithoutConsentsString() {
        #expect(!TelemetryConsent.allows(
            gdprApplies: 1, purposeConsents: nil, umpCanRequestAds: true, umpSaysNotRequired: true))
    }

    @Test("sin la clave: pasa sólo si UMP dice que la región no requiere consentimiento")
    func missingKey() {
        #expect(TelemetryConsent.allows(
            gdprApplies: nil, purposeConsents: nil, umpCanRequestAds: true, umpSaysNotRequired: true))
        #expect(!TelemetryConsent.allows(
            gdprApplies: nil, purposeConsents: Self.all, umpCanRequestAds: true, umpSaysNotRequired: false))
    }

    @Test("un gdprApplies raro cierra")
    func oddGDPRValue() {
        for value in [-1, 2] {
            #expect(!TelemetryConsent.allows(
                gdprApplies: value, purposeConsents: Self.all, umpCanRequestAds: true, umpSaysNotRequired: true))
        }
    }

    // MARK: - Leyendo UserDefaults

    @Test("lee las claves de TCF como número o como texto; un texto ilegible cierra")
    func readsDefaults() {
        let defaults = Self.freshDefaults()
        #expect(TelemetryConsent.gdprApplies(in: defaults) == nil)
        defaults.set(1, forKey: TelemetryConsent.gdprAppliesKey)
        #expect(TelemetryConsent.gdprApplies(in: defaults) == 1)
        defaults.set("0", forKey: TelemetryConsent.gdprAppliesKey)
        #expect(TelemetryConsent.gdprApplies(in: defaults) == 0)
        defaults.set("sí", forKey: TelemetryConsent.gdprAppliesKey)
        #expect(TelemetryConsent.gdprApplies(in: defaults) == -1)
        #expect(!TelemetryConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: true))

        defaults.set(1, forKey: TelemetryConsent.gdprAppliesKey)
        defaults.set(Self.all, forKey: TelemetryConsent.purposeConsentsKey)
        #expect(TelemetryConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: false))
        defaults.set(Self.storageOnly, forKey: TelemetryConsent.purposeConsentsKey)
        #expect(!TelemetryConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: false))
    }

    // MARK: - Dentro de la compuerta

    @Test("retirar el propósito de estadísticas (con UMP todavía en sí) vacía la cola y no sale nada")
    func withdrawnPurposePurgesTheQueue() async {
        let defaults = Self.freshDefaults()
        defaults.set(1, forKey: TelemetryConsent.gdprAppliesKey)
        defaults.set(Self.all, forKey: TelemetryConsent.purposeConsentsKey)
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = TelemetryService(
            queue: queue,
            telemetrySwitch: TelemetrySwitch(config: TelemetryFakeNetwork.config, fetch: network.fetch),
            uploader: TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch),
            device: DeviceContext(appVersion: "2.0", build: "1", osVersion: "18.2", deviceModel: "iPhone16,2", storefront: { nil }),
            identity: InstallIdentity(store: MemoryIdentityStore()),
            canRequestAds: {
                TelemetryConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: false)
            },
            arguments: [],
            isDebug: false
        )

        service.start()
        service.record(.sessionStart(number: 1))
        await service.settle()
        #expect(await queue.count == 1)

        defaults.set(Self.storageOnly, forKey: TelemetryConsent.purposeConsentsKey)
        service.flush()
        await service.settle()

        #expect(network.inserts.isEmpty)
        #expect(await queue.count == 0)
    }

    // MARK: - El id propio

    @Test("el ítem del Keychain de la telemetría es otro que el del ranking, y sólo de este dispositivo")
    func telemetryKeychainItemIsSeparate() throws {
        let ranking = KeychainInstallIdentityStore.ranking
        let telemetry = try #require(InstallIdentity.telemetry.store as? KeychainInstallIdentityStore)

        #expect(telemetry.service != ranking.service)
        #expect(telemetry.thisDeviceOnly)
        #expect((telemetry.accessibility as String) == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String))
        #expect(!ranking.thisDeviceOnly)
        #expect((ranking.accessibility as String) == (kSecAttrAccessibleAfterFirstUnlock as String))
        #expect(ranking.service == "com.adergames.fisu.ranking")
    }

    @Test("en el Keychain: los dos ids son distintos y cada uno es estable entre lecturas")
    func idsAreDistinctAndStable() {
        let suffix = UUID().uuidString
        let rankingStore = KeychainInstallIdentityStore(
            service: "test.ranking.\(suffix)", account: "installId", thisDeviceOnly: false)
        let telemetryStore = KeychainInstallIdentityStore(
            service: "test.telemetry.\(suffix)", account: "installId", thisDeviceOnly: true)
        defer { Self.delete(rankingStore, telemetryStore) }

        let ranking = InstallIdentity(store: rankingStore).installId()
        let telemetry = InstallIdentity(store: telemetryStore).installId()

        #expect(ranking != telemetry)
        #expect(InstallIdentity(store: telemetryStore).installId() == telemetry)
        #expect(InstallIdentity(store: rankingStore).installId() == ranking)
    }

    // MARK: - Ayudas

    private static func freshDefaults() -> UserDefaults {
        let name = "telemetry-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func delete(_ stores: KeychainInstallIdentityStore...) {
        for store in stores {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: store.service,
                kSecAttrAccount: store.account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
