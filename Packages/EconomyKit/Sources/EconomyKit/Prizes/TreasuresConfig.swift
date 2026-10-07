import Foundation

/// `treasures.json`: El Colchón (PLAN-v2 E5 y §2), "tus empleados escondieron
/// plata en el colchón". Aparece cada tanto de juego activo, espera hasta que
/// lo abras con un video y sortea un premio de esta tabla.
public struct TreasuresConfig: Codable, Sendable, Equatable {
    public struct Prize: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let weight: Int
        public let rewards: [RewardSpec]

        public init(id: String, weight: Int, rewards: [RewardSpec]) {
            self.id = id
            self.weight = weight
            self.rewards = rewards
        }
    }

    public let schemaVersion: Int
    /// Segundos de juego activo entre dos colchones (cuenta sólo sin uno esperando).
    public let spawnIntervalSeconds: Double
    /// El primero de una partida (o de un save anterior a E5).
    public let firstTreasureAfterSeconds: Double
    /// Cuántas veces se puede pedir "otro colchón" (un video más cada una).
    public let extraOpensPerTreasure: Int
    public let prizes: [Prize]

    public init(
        schemaVersion: Int,
        spawnIntervalSeconds: Double,
        firstTreasureAfterSeconds: Double,
        extraOpensPerTreasure: Int,
        prizes: [Prize]
    ) {
        self.schemaVersion = schemaVersion
        self.spawnIntervalSeconds = spawnIntervalSeconds
        self.firstTreasureAfterSeconds = firstTreasureAfterSeconds
        self.extraOpensPerTreasure = extraOpensPerTreasure
        self.prizes = prizes
    }

    /// La tabla que se muestra: la misma con la que sortea `TreasureRoller`.
    public var odds: [PrizeOdds] {
        zip(prizes, WeightedDraw.probabilities(weights: prizes.map { Double($0.weight) }))
            .map { PrizeOdds(id: $0.id, probability: $1) }
    }

    public enum ValidationError: Error, Equatable {
        case outOfRange(String)
        case noPrizes
        case duplicatePrize(String)
        case badWeight(String)
        case emptyPrize(String)
        case invalidReward(String)
    }

    public func validate() throws {
        guard spawnIntervalSeconds > 0 else { throw ValidationError.outOfRange("spawnIntervalSeconds") }
        guard firstTreasureAfterSeconds > 0 else { throw ValidationError.outOfRange("firstTreasureAfterSeconds") }
        guard extraOpensPerTreasure >= 0 else { throw ValidationError.outOfRange("extraOpensPerTreasure") }
        guard !prizes.isEmpty else { throw ValidationError.noPrizes }
        var seen: Set<String> = []
        for prize in prizes {
            guard seen.insert(prize.id).inserted else { throw ValidationError.duplicatePrize(prize.id) }
            guard prize.weight > 0 else { throw ValidationError.badWeight(prize.id) }
            guard !prize.rewards.isEmpty else { throw ValidationError.emptyPrize(prize.id) }
            for reward in prize.rewards {
                do {
                    try reward.validate()
                } catch {
                    throw ValidationError.invalidReward(prize.id)
                }
            }
        }
    }
}
