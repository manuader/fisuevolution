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
    public var inheritsPassiveUnlocks: Bool?
    public var floorCapacity: Int?
    public var blueDivisor: Double?
    public var blueExponent: Double?

    public init(
        defaultCostGrowth: Double? = nil,
        mergeRefundCounts: Double? = nil,
        priceReliefPurchases: Int? = nil,
        staffedFloorBonus: Double? = nil,
        requiresLastRunWall: Bool? = nil,
        escalationBands: [EconomyConfig.HireConfig.EscalationBand]? = nil,
        costGrowthStepPerFloor: Double? = nil,
        costGrowthStepFromFloorId: String? = nil,
        inheritsPassiveUnlocks: Bool? = nil,
        floorCapacity: Int? = nil,
        blueDivisor: Double? = nil,
        blueExponent: Double? = nil
    ) {
        self.requiresLastRunWall = requiresLastRunWall
        self.staffedFloorBonus = staffedFloorBonus
        self.defaultCostGrowth = defaultCostGrowth
        self.mergeRefundCounts = mergeRefundCounts
        self.priceReliefPurchases = priceReliefPurchases
        self.escalationBands = escalationBands
        self.costGrowthStepPerFloor = costGrowthStepPerFloor
        self.costGrowthStepFromFloorId = costGrowthStepFromFloorId
        self.inheritsPassiveUnlocks = inheritsPassiveUnlocks
        self.floorCapacity = floorCapacity
        self.blueDivisor = blueDivisor
        self.blueExponent = blueExponent
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
              var blue = root["blue"] as? [String: Any]
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
        if let value = knobs.requiresLastRunWall { blue["requiresLastRunWall"] = value }
        if let value = knobs.inheritsPassiveUnlocks { blue["inheritsPassiveUnlocks"] = value }
        if let value = knobs.blueDivisor { blue["divisor"] = value }
        if let value = knobs.blueExponent { blue["exponent"] = value }
        if let capacity = knobs.floorCapacity, let floors = root["floors"] as? [[String: Any]] {
            root["floors"] = floors.map { floor in
                var floor = floor
                floor["capacity"] = capacity
                return floor
            }
        }
        root["hire"] = hire
        root["blue"] = blue
        return try JSONDecoder().decode(EconomyConfig.self, from: JSONSerialization.data(withJSONObject: root))
    }
}
