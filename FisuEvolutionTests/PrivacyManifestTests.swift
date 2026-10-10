import Foundation
import Testing
@testable import FisuEvolution

/// El manifiesto de privacidad que viaja en el bundle: lo que el ranking de la
/// llegada a Dios recolecta (el `installId` y el nombre), sin vínculo ni
/// seguimiento. Tiene que coincidir con la App Privacy de App Store Connect.
@Suite("El manifiesto de privacidad")
struct PrivacyManifestTests {
    private var manifest: [String: Any] {
        guard let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    private var collected: [[String: Any]] {
        manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
    }

    @Test("declara exactamente el identificador del dispositivo y el contenido de usuario")
    func declaresTheRankingData() {
        let types = Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String })
        #expect(types == ["NSPrivacyCollectedDataTypeDeviceID", "NSPrivacyCollectedDataTypeOtherUserContent"])
    }

    @Test("ninguno está vinculado a la identidad ni se usa para seguimiento")
    func neitherLinkedNorTracked() {
        #expect(!collected.isEmpty)
        for entry in collected {
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == false)
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        }
    }

    @Test("el único propósito es la funcionalidad de la app")
    func appFunctionalityOnly() {
        for entry in collected {
            #expect(entry["NSPrivacyCollectedDataTypePurposes"] as? [String]
                    == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        }
    }

    @Test("si declara seguimiento tiene que listar sus dominios (Apple rechaza el build si no: ITMS-91064)")
    func trackingNeedsDomains() {
        let tracking = manifest["NSPrivacyTracking"] as? Bool ?? false
        let domains = manifest["NSPrivacyTrackingDomains"] as? [String] ?? []
        #expect(!tracking || !domains.isEmpty)
    }

    @Test("las APIs de razón requerida siguen declaradas")
    func requiredReasonAPIsRemain() {
        let apis = (manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? [])
            .compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        #expect(Set(apis) == ["NSPrivacyAccessedAPICategoryUserDefaults", "NSPrivacyAccessedAPICategoryFileTimestamp"])
    }
}
