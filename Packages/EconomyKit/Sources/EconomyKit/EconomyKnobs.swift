import Foundation

/// Las perillas de E2a juntas (PLAN-v2 E2a): lo que el panel de debug deja
/// probar al dueño y lo que E2b barre con el simulador. `nil` deja el valor de
/// la config; con todas en `nil`, `tuned` devuelve la misma config.
public struct EconomyKnobs: Codable, Sendable, Equatable {
    public var defaultCostGrowth: Double?
    public var mergeRefundCounts: Double?
    public var priceReliefPurchases: Int?

    public init(
        defaultCostGrowth: Double? = nil,
        mergeRefundCounts: Double? = nil,
        priceReliefPurchases: Int? = nil
    ) {
        self.defaultCostGrowth = defaultCostGrowth
        self.mergeRefundCounts = mergeRefundCounts
        self.priceReliefPurchases = priceReliefPurchases
    }
}

public enum EconomyKnobsError: Error, Equatable {
    case notAnObject
}

extension EconomyConfig {
    /// La misma config con las perillas puestas. Pasa por el JSON a propósito:
    /// es el camino por el que una perilla llega al juego (`economy.json` y su
    /// decoder), y una clave que otra épica sume a la config viaja sola, sin que
    /// esta función tenga que enumerar los campos.
    public func tuned(_ knobs: EconomyKnobs) throws -> EconomyConfig {
        guard var root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any],
              var hire = root["hire"] as? [String: Any]
        else { throw EconomyKnobsError.notAnObject }
        if let value = knobs.defaultCostGrowth { hire["defaultCostGrowth"] = value }
        if let value = knobs.mergeRefundCounts { hire["mergeRefundCounts"] = value }
        if let value = knobs.priceReliefPurchases { hire["priceReliefPurchases"] = value }
        root["hire"] = hire
        return try JSONDecoder().decode(EconomyConfig.self, from: JSONSerialization.data(withJSONObject: root))
    }
}
