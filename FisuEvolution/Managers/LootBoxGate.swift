import Foundation
import StoreKit

/// El azar que se paga con ORO —el giro extra de la ruleta y, en E6, el cofre
/// por ORO— se apaga en las tiendas de `restrictedStorefronts` (PLAN-v2 §2:
/// Bélgica y Australia). La lista viaja en la config remota de anuncios.
enum LootBoxGate {
    /// Sin tienda conocida, no: mejor no ofrecerlo que ofrecerlo donde está
    /// prohibido.
    static func allows(countryCode: String?, config: AdsRemoteConfig) -> Bool {
        guard let countryCode, !countryCode.isEmpty else { return false }
        return !config.isRestricted(storefront: countryCode)
    }

    /// La respuesta de hoy: la tienda del jugador contra la config que haya en
    /// disco (caché o respaldo del bundle, sin red). Sin config, no.
    static func current(loader: AdsRemoteConfigLoader = AdsRemoteConfigLoader()) async -> Bool {
        guard let config = loader.current()?.config else { return false }
        return allows(countryCode: await Storefront.current?.countryCode, config: config)
    }
}
