import Foundation
import Testing
@testable import FisuEvolution

/// El manifiesto de privacidad que viaja en el bundle: lo que el código de la app
/// recolecta —el ranking de la llegada a Dios (el `installId` y el nombre) y la
/// telemetría de E15 (sesiones, ofertas, impresiones y compras, con su propio id al
/// azar)—, sin vínculo ni seguimiento, y para qué: la personalización de la 2.1 usa
/// las sesiones, las impresiones y las compras. Dice la verdad del binario aunque los
/// interruptores de la telemetría y de la personalización estén apagados.
///
/// Describe **sólo nuestro código**: cada SDK de anuncios trae su propio manifiesto,
/// y la App Privacy de App Store Connect es la unión de todos. Por eso allá Device ID y
/// Advertising Data figuran como vinculados y con tracking (los declaran los SDK de
/// anuncios) aunque acá no lo estén; lo nuestro sólo les suma propósitos.
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

    /// Cada tipo con sus propósitos: el ranking es funcionalidad de la app y la
    /// telemetría (C4 de E15) es analítica propia. Device ID cubre los dos ids (el del
    /// ranking y el propio de la telemetría). Product Personalization (2.1 F1 T7) va en
    /// los tipos que alimentan el segmento (`PlayerValueInputs`): sesiones y ofertas,
    /// lo que pagó cada anuncio y si hubo compras. Device ID no: el id sólo reparte el
    /// A/B del cálculo, no entra en él.
    private static let expectedPurposes: [String: Set<String>] = [
        "NSPrivacyCollectedDataTypeDeviceID": [
            "NSPrivacyCollectedDataTypePurposeAppFunctionality",
            "NSPrivacyCollectedDataTypePurposeAnalytics",
        ],
        "NSPrivacyCollectedDataTypeOtherUserContent": ["NSPrivacyCollectedDataTypePurposeAppFunctionality"],
        "NSPrivacyCollectedDataTypeProductInteraction": [
            "NSPrivacyCollectedDataTypePurposeAnalytics",
            "NSPrivacyCollectedDataTypePurposeProductPersonalization",
        ],
        "NSPrivacyCollectedDataTypeAdvertisingData": [
            "NSPrivacyCollectedDataTypePurposeAnalytics",
            "NSPrivacyCollectedDataTypePurposeProductPersonalization",
        ],
        "NSPrivacyCollectedDataTypePurchaseHistory": [
            "NSPrivacyCollectedDataTypePurposeAnalytics",
            "NSPrivacyCollectedDataTypePurposeProductPersonalization",
        ],
    ]

    @Test("declara exactamente lo del ranking y lo de la telemetría, una vez cada tipo")
    func declaresTheRankingAndTelemetryData() {
        let types = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        #expect(Set(types) == Set(Self.expectedPurposes.keys))
        #expect(types.count == Set(types).count, "un tipo repetido: Apple los quiere en una sola entrada")
    }

    @Test("ninguno está vinculado a la identidad ni se usa para seguimiento")
    func neitherLinkedNorTracked() {
        #expect(!collected.isEmpty)
        for entry in collected {
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == false)
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        }
    }

    @Test("cada tipo declara exactamente sus propósitos")
    func purposesPerType() {
        for entry in collected {
            let type = entry["NSPrivacyCollectedDataType"] as? String ?? "?"
            let purposes = entry["NSPrivacyCollectedDataTypePurposes"] as? [String] ?? []
            #expect(Set(purposes) == Self.expectedPurposes[type], "\(type) declara \(purposes)")
            #expect(purposes.count == Set(purposes).count, "\(type) repite un propósito")
        }
    }

    @Test("la personalización declara su propósito sin volverse seguimiento")
    func personalizationIsDeclaredButNotTracking() {
        let personalized = collected.filter {
            ($0["NSPrivacyCollectedDataTypePurposes"] as? [String] ?? [])
                .contains("NSPrivacyCollectedDataTypePurposeProductPersonalization")
        }
        #expect(!personalized.isEmpty, "la 2.1 personaliza: algún tipo tiene que decirlo")
        for entry in personalized {
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        }
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
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
