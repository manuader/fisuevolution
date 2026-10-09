import Testing
@testable import FisuEvolution

@Suite("La fila de privacidad de UMP")
struct PrivacyRowTests {
    @Test("se ve sólo si UMP la pide, o si el test de UI la fuerza")
    func visibility() {
        #expect(AdsConsent.privacyRowVisible(required: true, arguments: []))
        #expect(!AdsConsent.privacyRowVisible(required: false, arguments: []))
        #expect(AdsConsent.privacyRowVisible(required: false, arguments: ["--uitest-privacy-options"]))
    }
}
