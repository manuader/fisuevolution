import Foundation

/// Las perillas de E2a juntas (PLAN-v2 E2a): lo que el panel de debug deja
/// probar al dueño y lo que E2b barre con el simulador. `nil` deja el valor de
/// la config; con todas en `nil`, `tuned` devuelve la misma config.
public struct EconomyKnobs: Codable, Sendable, Equatable {
    public var defaultCostGrowth: Double?
    public var mergeRefundCounts: Double?
    public var priceReliefPurchases: Int?
    public var staffedFloorBonus: Double?
    public var requiresLastRunWall: Bool?
    public var escalationBands: [EconomyConfig.HireConfig.EscalationBand]?
    public var costGrowthStepPerFloor: Double?
    public var costGrowthStepFromFloorId: String?

    public init(
        defaultCostGrowth: Double? = nil,
        mergeRefundCounts: Double? = nil,
        priceReliefPurchases: Int? = nil,
        staffedFloorBonus: Double? = nil,
        requiresLastRunWall: Bool? = nil,
        escalationBands: [EconomyConfig.HireConfig.EscalationBand]? = nil,
        costGrowthStepPerFloor: Double? = nil,
        costGrowthStepFromFloorId: String? = nil
    ) {
        self.requiresLastRunWall = requiresLastRunWall
        self.staffedFloorBonus = staffedFloorBonus
        self.defaultCostGrowth = defaultCostGrowth
        self.mergeRefundCounts = mergeRefundCounts
        self.priceReliefPurchases = priceReliefPurchases
        self.escalationBands = escalationBands
        self.costGrowthStepPerFloor = costGrowthStepPerFloor
        self.costGrowthStepFromFloorId = costGrowthStepFromFloorId
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
              var hire = root["hire"] as? [String: Any],
              var oro = root["oro"] as? [String: Any]
        else { throw EconomyKnobsError.notAnObject }
        if let value = knobs.defaultCostGrowth { hire["defaultCostGrowth"] = value }
        if let value = knobs.mergeRefundCounts { hire["mergeRefundCounts"] = value }
        if let value = knobs.priceReliefPurchases { hire["priceReliefPurchases"] = value }
        if let bands = knobs.escalationBands {
            hire["escalationBands"] = bands.map { ["fromTier": $0.fromTier, "factor": $0.factor] }
        }
        if let value = knobs.costGrowthStepPerFloor { hire["costGrowthStepPerFloor"] = value }
        if let value = knobs.costGrowthStepFromFloorId { hire["costGrowthStepFromFloorId"] = value }
        if let value = knobs.staffedFloorBonus { root["staffedFloorBonus"] = value }
        if let value = knobs.requiresLastRunWall { oro["requiresLastRunWall"] = value }
        root["hire"] = hire
        root["oro"] = oro
        return try JSONDecoder().decode(EconomyConfig.self, from: JSONSerialization.data(withJSONObject: root))
    }
}
