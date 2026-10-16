import Foundation

/// El consentimiento que pide la personalización (2.1 E15 F1, contrato C5): la misma forma que
/// `TelemetryConsent`, con más propósitos TCF v2.2 donde aplica el RGPD (`IABTCF_gdprApplies == 1`).
///
/// | Propósito | Qué es | Por qué |
/// |---|---|---|
/// | 1 | Guardar o leer información del dispositivo | el segmento y la caché de la config viven en el teléfono |
/// | 5 | Crear un perfil para personalizar contenido | el segmento **es** un perfil |
/// | 6 | Usar perfiles para elegir contenido personalizado | las ayudas y ofertas por segmento |
/// | 8 | Medir el rendimiento del contenido | el evento `segment` y las exposiciones |
/// | 9 | Entender a la audiencia con estadísticas | las métricas por segmento |
/// | 10 | Desarrollar y mejorar los servicios | recalibrar las tablas |
///
/// **Decidido por el dueño (V9).** `[VERIFICAR CON ABOGADO]` en F1-T9: si la lista cambia, es
/// `requiredPurposes` y su test. Fuera del RGPD vale lo mismo que en F0; ante la duda, no pasa.
enum PersonalizationConsent {
    static let requiredPurposes = [1, 5, 6, 8, 9, 10]

    /// La regla, pura. Los insumos son los de `TelemetryConsent.allows`.
    static func allows(
        gdprApplies: Int?, purposeConsents: String?, umpCanRequestAds: Bool, umpSaysNotRequired: Bool
    ) -> Bool {
        guard umpCanRequestAds else { return false }
        switch gdprApplies {
        case 1: return grantsRequiredPurposes(purposeConsents)
        case 0: return true
        case nil: return umpSaysNotRequired
        default: return false
        }
    }

    /// La misma regla, leyendo las claves de TCF de `defaults` con el lector de la telemetría.
    static func allows(defaults: UserDefaults, umpCanRequestAds: Bool, umpSaysNotRequired: Bool) -> Bool {
        allows(
            gdprApplies: TelemetryConsent.gdprApplies(in: defaults),
            purposeConsents: defaults.string(forKey: TelemetryConsent.purposeConsentsKey),
            umpCanRequestAds: umpCanRequestAds,
            umpSaysNotRequired: umpSaysNotRequired
        )
    }

    /// `IABTCF_PurposeConsents` es una tira de «0» y «1»: la posición `n - 1` es el propósito `n`.
    static func grantsRequiredPurposes(_ consents: String?) -> Bool {
        let bits = Array(consents ?? "")
        return requiredPurposes.allSatisfy { $0 <= bits.count && bits[$0 - 1] == "1" }
    }
}
