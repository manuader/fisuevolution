import Foundation
import Security

/// Dónde vive el id de instalación. El Keychain en producción; en memoria en los tests.
protocol InstallIdentityStore: Sendable {
    func read() -> String?
    func write(_ value: String)
}

/// El UUID anónimo de esta instalación: lo único con lo que el servidor reconoce al jugador.
/// Sobrevive a reinstalar (Keychain) y no se sincroniza entre dispositivos.
struct InstallIdentity: Sendable {
    let store: any InstallIdentityStore

    init(store: any InstallIdentityStore = KeychainInstallIdentityStore()) {
        self.store = store
    }

    func installId() -> String {
        if let saved = store.read(), UUID(uuidString: saved) != nil { return saved.lowercased() }
        let fresh = UUID().uuidString.lowercased()
        store.write(fresh)
        return fresh
    }
}

struct KeychainInstallIdentityStore: InstallIdentityStore {
    static let service = "com.adergames.fisu.ranking"
    static let account = "installId"

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecAttrSynchronizable: false,
        ]
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
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
