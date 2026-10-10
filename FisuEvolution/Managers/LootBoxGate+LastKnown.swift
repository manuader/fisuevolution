import Foundation

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
}
