import Foundation

/// `wheel.json`: la Ruleta (PLAN-v2 E5 y §2). Los pesos suman 100 y son la
/// tabla que ve el jugador; la que se sortea es siempre la misma que se
/// muestra (`effectiveSegments`).
public struct WheelConfig: Codable, Sendable, Equatable {
    public struct Segment: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let weight: Int
        public let reward: RewardSpec

        public init(id: String, weight: Int, reward: RewardSpec) {
            self.id = id
            self.weight = weight
            self.reward = reward
        }
    }

    public static let totalWeight = 100

    public let schemaVersion: Int
    public let videoSpinsPerDay: Int
    public let oroSpinCost: Int
    /// 0 apaga el giro con ORO en todas las tiendas.
    public let oroSpinsPerDay: Int
    /// Lo que dura la animación del giro (la usa la vista).
    public let spinSeconds: Double
    /// A qué segmento de plata va el peso del cofre cuando el cofre no tiene
    /// nada que dar.
    public let chestFallbackSegmentId: String
    public let segments: [Segment]

    public init(
        schemaVersion: Int,
        videoSpinsPerDay: Int,
        oroSpinCost: Int,
        oroSpinsPerDay: Int,
        spinSeconds: Double,
        chestFallbackSegmentId: String,
        segments: [Segment]
    ) {
        self.schemaVersion = schemaVersion
        self.videoSpinsPerDay = videoSpinsPerDay
        self.oroSpinCost = oroSpinCost
        self.oroSpinsPerDay = oroSpinsPerDay
        self.spinSeconds = spinSeconds
        self.chestFallbackSegmentId = chestFallbackSegmentId
        self.segments = segments
    }

    /// La tabla que se sortea Y se muestra. Si un cofre de pintas hoy no tiene
    /// nada que dar, sus segmentos se van y su peso pasa a la plata.
    public func effectiveSegments(chestHasSomethingToGive: Bool) -> [Segment] {
        guard !chestHasSomethingToGive else { return segments }
        let moved = segments.filter { $0.reward.kind == .skinChest }.reduce(0) { $0 + $1.weight }
        guard moved > 0 else { return segments }
        return segments.compactMap { segment in
            if segment.reward.kind == .skinChest { return nil }
            guard segment.id == chestFallbackSegmentId else { return segment }
            return Segment(id: segment.id, weight: segment.weight + moved, reward: segment.reward)
        }
    }

    public func odds(chestHasSomethingToGive: Bool) -> [PrizeOdds] {
        let table = effectiveSegments(chestHasSomethingToGive: chestHasSomethingToGive)
        return zip(table, WeightedDraw.probabilities(weights: table.map { Double($0.weight) }))
            .map { PrizeOdds(id: $0.id, probability: $1) }
    }

    public enum ValidationError: Error, Equatable {
        case outOfRange(String)
        case weightsMustSumTo100(Int)
        case duplicateSegment(String)
        case badWeight(String)
        case unknownFallback(String)
        case fallbackMustPayCoins
        case invalidReward(String)
    }

    public func validate() throws {
        guard videoSpinsPerDay > 0 else { throw ValidationError.outOfRange("videoSpinsPerDay") }
        guard oroSpinCost > 0 else { throw ValidationError.outOfRange("oroSpinCost") }
        guard oroSpinsPerDay >= 0 else { throw ValidationError.outOfRange("oroSpinsPerDay") }
        guard spinSeconds > 0 else { throw ValidationError.outOfRange("spinSeconds") }
        var ids: Set<String> = []
        for segment in segments {
            guard ids.insert(segment.id).inserted else { throw ValidationError.duplicateSegment(segment.id) }
            guard segment.weight > 0 else { throw ValidationError.badWeight(segment.id) }
            do {
                try segment.reward.validate()
            } catch {
                throw ValidationError.invalidReward(segment.id)
            }
        }
        let total = segments.map(\.weight).reduce(0, +)
        guard total == Self.totalWeight else { throw ValidationError.weightsMustSumTo100(total) }
        guard let fallback = segments.first(where: { $0.id == chestFallbackSegmentId }) else {
            throw ValidationError.unknownFallback(chestFallbackSegmentId)
        }
        guard fallback.reward.kind == .coinsSeconds else { throw ValidationError.fallbackMustPayCoins }
    }
}
