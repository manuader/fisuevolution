import Foundation
import Security

/// Dónde vive el id de instalación. El Keychain en producción; en memoria en los tests.
protocol InstallIdentityStore: Sendable {
    func read() -> String?
    func write(_ value: String)
}

/// El UUID al azar de esta instalación: lo único con lo que el servidor reconoce al jugador.
/// Sobrevive a reinstalar (Keychain) y no se sincroniza entre dispositivos.
///
/// Hay dos, cada uno en su ítem del Keychain: el del ranking (`InstallIdentity()`) y el de la
/// telemetría (`InstallIdentity.telemetry`), para que las estadísticas no se puedan cruzar con el
/// nombre del ranking por el id.
struct InstallIdentity: Sendable {
    let store: any InstallIdentityStore

    init(store: any InstallIdentityStore = KeychainInstallIdentityStore.ranking) {
        self.store = store
    }

    static var telemetry: InstallIdentity {
        InstallIdentity(store: KeychainInstallIdentityStore.telemetry)
    }

    func installId() -> String {
        if let saved = store.read(), UUID(uuidString: saved) != nil { return saved.lowercased() }
        let fresh = UUID().uuidString.lowercased()
        store.write(fresh)
        return fresh
    }
}

struct KeychainInstallIdentityStore: InstallIdentityStore {
    /// El del ranking, como estuvo siempre (cambiarle la accesibilidad no toca un ítem ya guardado).
    static let ranking = KeychainInstallIdentityStore(
        service: "com.adergames.fisu.ranking", account: "installId", thisDeviceOnly: false)
    /// El de la telemetría: aparte del ranking, sólo de este dispositivo (no viaja en un backup a
    /// otro teléfono) y no sincronizable.
    static let telemetry = KeychainInstallIdentityStore(
        service: "com.adergames.fisu.telemetry", account: "installId", thisDeviceOnly: true)

    let service: String
    let account: String
    let thisDeviceOnly: Bool

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
        ]
    }

    var accessibility: CFString {
        thisDeviceOnly ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly : kSecAttrAccessibleAfterFirstUnlock
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String) {
        let data = Data(value.utf8)
        let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard update == errSecItemNotFound else { return }
        var add = baseQuery
        add[kSecValueData] = data
        add[kSecAttrAccessible] = accessibility
        SecItemAdd(add as CFDictionary, nil)
    }
}
