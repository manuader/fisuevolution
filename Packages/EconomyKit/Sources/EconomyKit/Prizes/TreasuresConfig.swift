import Foundation

/// `treasures.json`: El Colchón (PLAN-v2 E5 y §2), "tus empleados escondieron
/// plata en el colchón". Aparece cada tanto de juego activo, espera hasta que
/// lo abras con un video y sortea un premio de esta tabla. Aparte, cada tanto de
/// reloj real cae uno gratis en el tablero (E14b B31, D20), con la misma tabla.
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
    /// Segundos de reloj real entre dos colchones gratis del tablero (E14b B31, D20). Corre también
    /// con el juego cerrado, guarda uno solo y arranca de nuevo al abrirlo. 0 = no cae ninguno.
    public let freeBoardIntervalSeconds: Double
    public let prizes: [Prize]
    /// La tabla del colchón gratis del tablero, si el pacing pide otra (E14b B31). Sin ella, la misma
    /// que el de la columna.
    public let freeBoardPrizes: [Prize]?

    public init(
        schemaVersion: Int,
        spawnIntervalSeconds: Double,
        firstTreasureAfterSeconds: Double,
        extraOpensPerTreasure: Int,
        freeBoardIntervalSeconds: Double = 0,
        prizes: [Prize],
        freeBoardPrizes: [Prize]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.spawnIntervalSeconds = spawnIntervalSeconds
        self.firstTreasureAfterSeconds = firstTreasureAfterSeconds
        self.extraOpensPerTreasure = extraOpensPerTreasure
        self.freeBoardIntervalSeconds = freeBoardIntervalSeconds
        self.prizes = prizes
        self.freeBoardPrizes = freeBoardPrizes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        spawnIntervalSeconds = try container.decode(Double.self, forKey: .spawnIntervalSeconds)
        firstTreasureAfterSeconds = try container.decode(Double.self, forKey: .firstTreasureAfterSeconds)
        extraOpensPerTreasure = try container.decode(Int.self, forKey: .extraOpensPerTreasure)
        freeBoardIntervalSeconds = try container.decodeIfPresent(Double.self, forKey: .freeBoardIntervalSeconds) ?? 0
        prizes = try container.decode([Prize].self, forKey: .prizes)
        freeBoardPrizes = try container.decodeIfPresent([Prize].self, forKey: .freeBoardPrizes)
    }

    /// La tabla del colchón gratis del tablero: la suya o, sin ella, la del de la columna.
    public var freePrizes: [Prize] { freeBoardPrizes ?? prizes }

    /// La tabla que se muestra: la misma con la que sortea `TreasureRoller`.
    public var odds: [PrizeOdds] { Self.odds(of: prizes) }

    /// La del colchón gratis, con la que sortea `TreasureRoller.rollFree`.
    public var freeOdds: [PrizeOdds] { Self.odds(of: freePrizes) }

    private static func odds(of prizes: [Prize]) -> [PrizeOdds] {
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
        guard spawnIntervalSeconds > 0, spawnIntervalSeconds.isFinite else { throw ValidationError.outOfRange("spawnIntervalSeconds") }
        guard firstTreasureAfterSeconds > 0, firstTreasureAfterSeconds.isFinite else { throw ValidationError.outOfRange("firstTreasureAfterSeconds") }
        guard extraOpensPerTreasure >= 0 else { throw ValidationError.outOfRange("extraOpensPerTreasure") }
        guard freeBoardIntervalSeconds >= 0, freeBoardIntervalSeconds.isFinite else {
            throw ValidationError.outOfRange("freeBoardIntervalSeconds")
        }
        try Self.validate(prizes)
        if let freeBoardPrizes { try Self.validate(freeBoardPrizes) }
    }

    private static func validate(_ prizes: [Prize]) throws {
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
