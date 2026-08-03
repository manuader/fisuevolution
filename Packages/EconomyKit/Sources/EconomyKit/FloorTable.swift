import Foundation

/// Un piso de la Torre (F7): rango de tiers que aloja, fondo, capacidad y con
/// qué tier se desbloquea. 100% data-driven desde `economy.json → floors[]` —
/// la cantidad de pisos y el mapeo tier→piso son INTERCAMBIABLES editando solo
/// la config (spec F7 §3.1/§3.8).
public struct FloorDef: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    /// Key dentro de `manifest.backgrounds` (p.ej. "alley").
    public let background: String
    public let firstTier: Int
    public let lastTier: Int
    public let capacity: Int
    /// Multiplicador de income de todo lo que vive en este piso. [TUNEABLE]
    public let incomeMultiplier: Double
    /// Multiplicador del costo de contratar el tier base de ESTE piso, sobre
    /// `tapYield(firstTier)`. El default global vive en `hire.defaultCostMultiplier`
    /// (punitivo — spec §3.3); un piso puede overridear (piso 1 = barato). [TUNEABLE]
    public let hireCostMultiplierOverride: Double?
    /// Growth de la curva de hire de este piso (exponente sobre `hireCounts[id]`).
    public let hireCostGrowthOverride: Double?
    /// Tier cuya PRIMERA creación desbloquea este piso. Default: `firstTier`.
    /// Overrideable por config (spec §3.8, default ⚠️9).
    public let unlockTierOverride: Int?

    public var unlockTier: Int { unlockTierOverride ?? firstTier }

    public func contains(tier: Int) -> Bool { tier >= firstTier && tier <= lastTier }

    public init(
        id: String,
        background: String,
        firstTier: Int,
        lastTier: Int,
        capacity: Int,
        incomeMultiplier: Double,
        hireCostMultiplierOverride: Double? = nil,
        hireCostGrowthOverride: Double? = nil,
        unlockTierOverride: Int? = nil
    ) {
        self.id = id
        self.background = background
        self.firstTier = firstTier
        self.lastTier = lastTier
        self.capacity = capacity
        self.incomeMultiplier = incomeMultiplier
        self.hireCostMultiplierOverride = hireCostMultiplierOverride
        self.hireCostGrowthOverride = hireCostGrowthOverride
        self.unlockTierOverride = unlockTierOverride
    }

    enum CodingKeys: String, CodingKey {
        case id, background, firstTier, lastTier, capacity, incomeMultiplier
        case hireCostMultiplierOverride = "hireCostMultiplier"
        case hireCostGrowthOverride = "hireCostGrowth"
        case unlockTierOverride = "unlockTier"
    }
}

public enum FloorValidationError: Error, Equatable, CustomStringConvertible {
    case empty
    case duplicateId(String)
    case nonAscendingRange(floorId: String)
    case overlappingFloors(String, String)
    case tierNotCovered(Int)
    case tierBeyondFloors(maxFloorTier: Int, maxTier: Int)
    case invalidCapacity(floorId: String)
    case unlockTierOutOfRange(floorId: String)

    public var description: String {
        switch self {
        case .empty: "floors[] vacío"
        case .duplicateId(let id): "id de piso duplicado: \(id)"
        case .nonAscendingRange(let id): "rango invertido en piso \(id)"
        case .overlappingFloors(let a, let b): "pisos solapados: \(a) y \(b)"
        case .tierNotCovered(let t): "el tier \(t) no pertenece a ningún piso"
        case .tierBeyondFloors(let maxFloorTier, let maxTier):
            "los pisos cubren hasta T\(maxFloorTier) pero la escalera llega a T\(maxTier)"
        case .invalidCapacity(let id): "capacity inválida en piso \(id)"
        case .unlockTierOutOfRange(let id): "unlockTier fuera de rango en piso \(id)"
        }
    }
}

/// Tabla validada de pisos. Análoga a `TierRepository`: valida en el init y
/// después ofrece lookups totales (sin optionals en los caminos calientes).
///
/// Invariantes (validadas):
/// - ≥ 1 piso, ids únicos, capacity > 0.
/// - Rangos ascendentes, sin solapes ni huecos: cobertura EXACTA de `1...maxTier`.
/// - `unlockTier` dentro del rango global de tiers.
public struct FloorTable: Sendable, Equatable {
    /// Pisos en orden ascendente de tiers (ordinal 0 = piso 1).
    public let floors: [FloorDef]
    /// tier → ordinal de piso (índice denso; tier 1 está en la posición 1).
    private let ordinalByTier: [Int]
    private let ordinalById: [String: Int]

    public var count: Int { floors.count }

    public init(floors rawFloors: [FloorDef], maxTier: Int) throws {
        guard !rawFloors.isEmpty else { throw FloorValidationError.empty }
        let sorted = rawFloors.sorted { $0.firstTier < $1.firstTier }

        var seenIds = Set<String>()
        for floor in sorted {
            guard seenIds.insert(floor.id).inserted else {
                throw FloorValidationError.duplicateId(floor.id)
            }
            guard floor.firstTier <= floor.lastTier else {
                throw FloorValidationError.nonAscendingRange(floorId: floor.id)
            }
            guard floor.capacity > 0 else {
                throw FloorValidationError.invalidCapacity(floorId: floor.id)
            }
            guard floor.unlockTier >= 1, floor.unlockTier <= maxTier else {
                throw FloorValidationError.unlockTierOutOfRange(floorId: floor.id)
            }
        }
        // Cobertura exacta 1...maxTier, sin solapes ni huecos.
        var expected = 1
        for (index, floor) in sorted.enumerated() {
            if floor.firstTier < expected {
                throw FloorValidationError.overlappingFloors(sorted[index - 1].id, floor.id)
            }
            if floor.firstTier > expected {
                throw FloorValidationError.tierNotCovered(expected)
            }
            expected = floor.lastTier + 1
        }
        guard expected == maxTier + 1 else {
            if expected < maxTier + 1 {
                throw FloorValidationError.tierBeyondFloors(maxFloorTier: expected - 1, maxTier: maxTier)
            }
            throw FloorValidationError.tierNotCovered(maxTier)
        }

        self.floors = sorted
        var byTier = [Int](repeating: 0, count: maxTier + 1)
        for (ordinal, floor) in sorted.enumerated() {
            for tier in floor.firstTier...floor.lastTier { byTier[tier] = ordinal }
        }
        self.ordinalByTier = byTier
        self.ordinalById = Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($1.id, $0) })
    }

    public subscript(ordinal: Int) -> FloorDef { floors[ordinal] }

    /// Total: todo tier 1...maxTier tiene piso (invariante del init).
    public func ordinal(forTier tier: Int) -> Int {
        ordinalByTier[min(max(tier, 1), ordinalByTier.count - 1)]
    }

    public func floor(forTier tier: Int) -> FloorDef { floors[ordinal(forTier: tier)] }

    public func ordinal(of floorId: String) -> Int? { ordinalById[floorId] }
}
