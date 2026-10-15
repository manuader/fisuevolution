import Foundation

/// El consentimiento que pide la telemetría (Opción A del borrador de privacidad de E15): más
/// estricto que «UMP deja pedir anuncios», y cerrado ante la duda.
///
/// `canRequestAds` de UMP es `true` también con un consentimiento parcial (alcanza con el
/// propósito 1), así que en la UE, el Reino Unido y Suiza no dice nada sobre las estadísticas. Por
/// eso, donde aplica el RGPD (`IABTCF_gdprApplies == 1`) se exigen además, en
/// `IABTCF_PurposeConsents`, los propósitos TCF v2.2 que describen lo que hace la telemetría:
///
/// | Propósito | Qué es | Por qué |
/// |---|---|---|
/// | 1 | Guardar o leer información del dispositivo | el id de telemetría vive en el Keychain |
/// | 8 | Medir el rendimiento del contenido | sesiones, ofertas vistas y aceptadas |
/// | 9 | Entender a la audiencia con estadísticas | país, modelo y versión, agregados |
/// | 10 | Desarrollar y mejorar los servicios | para qué se junta todo esto |
///
/// Los cuatro a la vez: ante la duda, el más estricto. UMP escribe esas claves en
/// `UserDefaults.standard` (es la CMP del juego); sin la clave `IABTCF_gdprApplies` se deja pasar
/// sólo si UMP informa que en esta región no hace falta consentimiento (`.notRequired`). Si no se
/// puede saber, no pasa.
enum TelemetryConsent {
    static let gdprAppliesKey = "IABTCF_gdprApplies"
    static let purposeConsentsKey = "IABTCF_PurposeConsents"
    static let requiredPurposes = [1, 8, 9, 10]

    /// La regla, pura. `gdprApplies` es lo que dice la clave (`nil` si no está; cualquier valor
    /// que no sea 0 ni 1 cierra). `umpSaysNotRequired` es `consentStatus == .notRequired`.
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

    /// La misma regla, leyendo las claves de TCF de `defaults`.
    static func allows(defaults: UserDefaults, umpCanRequestAds: Bool, umpSaysNotRequired: Bool) -> Bool {
        allows(
            gdprApplies: gdprApplies(in: defaults),
            purposeConsents: defaults.string(forKey: purposeConsentsKey),
            umpCanRequestAds: umpCanRequestAds,
            umpSaysNotRequired: umpSaysNotRequired
        )
    }

    /// La CMP la guarda como número; algunas, como texto. Un texto que no es un número cuenta como
    /// «presente pero ilegible» (-1), que cierra.
    static func gdprApplies(in defaults: UserDefaults) -> Int? {
        switch defaults.object(forKey: gdprAppliesKey) {
        case let number as NSNumber: return number.intValue
        case let text as String: return Int(text) ?? -1
        case nil: return nil
        default: return -1
        }
    }

    /// `IABTCF_PurposeConsents` es una tira de «0» y «1»: la posición `n - 1` es el propósito `n`.
    static func grantsRequiredPurposes(_ consents: String?) -> Bool {
        let bits = Array(consents ?? "")
        return requiredPurposes.allSatisfy { $0 <= bits.count && bits[$0 - 1] == "1" }
    }
}
