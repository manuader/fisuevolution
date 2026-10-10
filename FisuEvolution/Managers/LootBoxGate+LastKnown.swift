import Foundation
import StoreKit

/// `LootBoxGate.current()` pregunta a StoreKit y es `async`. Lo que se decide
/// dentro de un tick —si la oferta de Bienvenida, que trae un cofre, se puede
/// presentar— necesita una respuesta ya: la última que se obtuvo. Arranca
/// cerrada, como la puerta: hasta que StoreKit conteste, no se ofrece azar.
extension LootBoxGate {
    @MainActor static private(set) var lastKnown = false

    /// Pregunta de nuevo y guarda la respuesta.
    @MainActor
    @discardableResult
    static func refreshLastKnown(loader: AdsRemoteConfigLoader = AdsRemoteConfigLoader()) async -> Bool {
        let allows = await current(loader: loader)
        lastKnown = allows
        return allows
    }

    @MainActor private static var storefrontWatch: Task<Void, Never>?

    /// La tienda del jugador puede cambiar con la app abierta (se muda, cambia de
    /// cuenta): cada cambio vuelve a preguntar, así lo que se decide en un tick
    /// nunca se queda con el país de cuando arrancó la app.
    @MainActor
    static func startWatchingStorefront(loader: AdsRemoteConfigLoader = AdsRemoteConfigLoader()) {
        guard storefrontWatch == nil else { return }
        storefrontWatch = Task {
            for await _ in Storefront.updates {
                await refreshLastKnown(loader: loader)
            }
        }
    }
}
