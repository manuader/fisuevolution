import Foundation

/// Espejo Codable de `chests.json`. Los pesos y los pagos son datos: cambiar el
/// ritmo del sistema no debe pedir un rebuild de lógica.
public struct ChestsConfig: Codable, Sendable, Equatable {
    public struct RarityWeight: Codable, Sendable, Equatable {
        public let rarity: SkinsConfig.Rarity
        public let weight: Int

        public init(rarity: SkinsConfig.Rarity, weight: Int) {
            self.rarity = rarity
            self.weight = weight
        }
    }

    public let schemaVersion: Int
    public let weights: [RarityWeight]
    /// Cada cuántos pisos desbloqueados cae un cofre de la torre.
    public let floorsPerChest: Int
    /// Multiplicador sobre `passiveUnlockCost(forTier:)` cuando ya no queda skin.
    public let completedPayoutFactor: Double
    /// Lo mismo para el cofre de la reencarnación, que paga más.
    public let prestigePayoutFactor: Double
    /// Qué pinta trae el cofre del tutorial. Es FIJA y no una tirada —es un
    /// momento guionado— pero vive acá y no en Swift: la constraint global dice
    /// que ningún id de skin se hardcodea, y esta es la única que el código
    /// necesitaría nombrar.
    public let welcomeSkinId: String

    /// Memberwise público porque las fixtures arman configs a mano: el sorteo se
    /// verifica variando los pesos, no sólo con los que se shippean.
    public init(
        schemaVersion: Int,
        weights: [RarityWeight],
        floorsPerChest: Int,
        completedPayoutFactor: Double,
        prestigePayoutFactor: Double,
        welcomeSkinId: String
    ) {
        self.schemaVersion = schemaVersion
        self.weights = weights
        self.floorsPerChest = floorsPerChest
        self.completedPayoutFactor = completedPayoutFactor
        self.prestigePayoutFactor = prestigePayoutFactor
        self.welcomeSkinId = welcomeSkinId
    }

    public func weight(for rarity: SkinsConfig.Rarity) -> Int {
        weights.first { $0.rarity == rarity }?.weight ?? 0
    }
}
