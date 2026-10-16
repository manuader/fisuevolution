import Foundation
import Testing
@testable import FisuEvolution

/// C5 (V9): para personalizar, donde aplica el RGPD hacen falta los propósitos TCF 1, 5, 6, 8, 9 y 10.
@Suite("Personalización: el consentimiento")
struct PersonalizationConsentTests {
    /// Una tira de `IABTCF_PurposeConsents` con sólo los propósitos dados en «1».
    private func consents(_ purposes: [Int], length: Int = 11) -> String {
        String((1...length).map { purposes.contains($0) ? "1" : "0" })
    }

    @Test("los propósitos que exige son exactamente {1, 5, 6, 8, 9, 10} (V9)")
    func requiredPurposesAreTheOwnersDecision() {
        #expect(PersonalizationConsent.requiredPurposes == [1, 5, 6, 8, 9, 10])
    }

    @Test("RGPD con los seis propósitos: sí")
    func gdprWithAllPurposesAllows() {
        #expect(PersonalizationConsent.allows(
            gdprApplies: 1, purposeConsents: consents([1, 5, 6, 8, 9, 10]),
            umpCanRequestAds: true, umpSaysNotRequired: false
        ))
    }

    @Test("RGPD al que le falta uno de los seis: no", arguments: [1, 5, 6, 8, 9, 10])
    func gdprMissingAnyPurposeDenies(missing: Int) {
        let granted = [1, 5, 6, 8, 9, 10].filter { $0 != missing }
        #expect(!PersonalizationConsent.allows(
            gdprApplies: 1, purposeConsents: consents(granted),
            umpCanRequestAds: true, umpSaysNotRequired: false
        ))
    }

    @Test("RGPD con lo que alcanza para la telemetría (1, 8, 9, 10) pero sin 5: no")
    func telemetryConsentIsNotEnough() {
        let telemetryOnly = consents(TelemetryConsent.requiredPurposes)
        #expect(TelemetryConsent.allows(
            gdprApplies: 1, purposeConsents: telemetryOnly, umpCanRequestAds: true, umpSaysNotRequired: false
        ))
        #expect(!PersonalizationConsent.allows(
            gdprApplies: 1, purposeConsents: telemetryOnly, umpCanRequestAds: true, umpSaysNotRequired: false
        ))
    }

    @Test("RGPD con una tira corta, vacía o ausente: no", arguments: ["", "11111", "111111111", nil] as [String?])
    func gdprWithShortOrMissingStringDenies(purposeConsents: String?) {
        #expect(!PersonalizationConsent.allows(
            gdprApplies: 1, purposeConsents: purposeConsents, umpCanRequestAds: true, umpSaysNotRequired: false
        ))
    }

    @Test("gdprApplies 2 (ni 0 ni 1) cierra, aunque estén todos los propósitos")
    func unknownGdprValueDenies() {
        #expect(!PersonalizationConsent.allows(
            gdprApplies: 2, purposeConsents: consents(Array(1...11)),
            umpCanRequestAds: true, umpSaysNotRequired: true
        ))
    }

    @Test("fuera del RGPD (gdprApplies 0): igual que la telemetría de F0, alcanza con UMP")
    func outsideGdprAllows() {
        #expect(PersonalizationConsent.allows(
            gdprApplies: 0, purposeConsents: nil, umpCanRequestAds: true, umpSaysNotRequired: false
        ))
    }

    @Test("sin la clave de TCF: sí sólo si UMP dice .notRequired")
    func missingKeyDependsOnUMP() {
        #expect(PersonalizationConsent.allows(
            gdprApplies: nil, purposeConsents: nil, umpCanRequestAds: true, umpSaysNotRequired: true
        ))
        #expect(!PersonalizationConsent.allows(
            gdprApplies: nil, purposeConsents: nil, umpCanRequestAds: true, umpSaysNotRequired: false
        ))
    }

    @Test("sin canRequestAds de UMP nunca pasa, ni con todo lo demás")
    func withoutUMPNeverAllows() {
        for gdpr in [0, 1, nil] as [Int?] {
            #expect(!PersonalizationConsent.allows(
                gdprApplies: gdpr, purposeConsents: consents(Array(1...11)),
                umpCanRequestAds: false, umpSaysNotRequired: true
            ))
        }
    }

    @Test("lee las claves IABTCF de UserDefaults (número o texto)")
    func readsDefaults() throws {
        let suite = "personalization-consent-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(1, forKey: TelemetryConsent.gdprAppliesKey)
        defaults.set(consents([1, 5, 6, 8, 9, 10]), forKey: TelemetryConsent.purposeConsentsKey)
        #expect(PersonalizationConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: false))

        defaults.set("1", forKey: TelemetryConsent.gdprAppliesKey)
        defaults.set(consents([1, 6, 8, 9, 10]), forKey: TelemetryConsent.purposeConsentsKey)
        #expect(!PersonalizationConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: false))

        defaults.set("sí", forKey: TelemetryConsent.gdprAppliesKey)
        defaults.set(consents(Array(1...11)), forKey: TelemetryConsent.purposeConsentsKey)
        #expect(!PersonalizationConsent.allows(defaults: defaults, umpCanRequestAds: true, umpSaysNotRequired: true))
    }
}
