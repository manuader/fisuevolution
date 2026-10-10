import Foundation

/// Cuánto vale un segundo de producción y cuánto cuesta reponer a alguien: lo
/// resuelve la app (`GameState.coinsPerProductionSecond`, el descuento de
/// prestigio) y el planificador sólo lo usa.
public struct VisitValuation: Sendable, Equatable {
    public let coinsPerSecond: Double
    public let hireCostMultiplier: Double

    public init(coinsPerSecond: Double, hireCostMultiplier: Double = 1) {
        self.coinsPerSecond = coinsPerSecond
        self.hireCostMultiplier = hireCostMultiplier
    }
}

/// Lo que promete un reto de toques, ya cotizado.
public struct ChallengeTerms: Sendable, Equatable {
    public let taps: Int
    public let windowSeconds: Double
    public let coins: Double
    public let rewards: [RewardSpec]
    public let videoDoubles: Bool

    public init(taps: Int, windowSeconds: Double, coins: Double, rewards: [RewardSpec], videoDoubles: Bool) {
        self.taps = taps
        self.windowSeconds = windowSeconds
        self.coins = coins
        self.rewards = rewards
        self.videoDoubles = videoDoubles
    }
}

/// Una opción del popup: lo que cobra o paga (`coins`, ya cotizado), lo que da
/// además, a quién se lleva y si pide un video.
public struct VisitOption: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case accept, acceptWithVideo, payBail, release, payFine, forgiveWithVideo
        case sell, exchange, startChallenge, card, listen
    }

    public let id: String
    public let kind: Kind
    /// Positivo: lo cobrás. Negativo: lo pagás (fianza, multa, cambio).
    public let coins: Double
    /// Lo que da que no es plata (la plata ya está en `coins`).
    public let rewards: [RewardSpec]
    public let departures: [BoardChange]
    public let requiresVideo: Bool
    public let challenge: ChallengeTerms?

    public init(
        id: String, kind: Kind, coins: Double, rewards: [RewardSpec], departures: [BoardChange],
        requiresVideo: Bool, challenge: ChallengeTerms?
    ) {
        self.id = id
        self.kind = kind
        self.coins = coins
        self.rewards = rewards
        self.departures = departures
        self.requiresVideo = requiresVideo
        self.challenge = challenge
    }

    public var cost: Double { max(0, -coins) }
}

public struct VisitOffer: Sendable, Equatable {
    public let scriptId: String
    public let visitorId: String
    /// A quién se lleva, compra o arresta (el globo lo nombra).
    public let subjectTypeId: String?
    public let options: [VisitOption]

    public init(scriptId: String, visitorId: String, subjectTypeId: String?, options: [VisitOption]) {
        self.scriptId = scriptId
        self.visitorId = visitorId
        self.subjectTypeId = subjectTypeId
        self.options = options
    }

    public func option(id: String) -> VisitOption? {
        options.first { $0.id == id }
    }
}

/// La oferta de un visitante (PLAN-v2 E4). Se concreta AL LLEGAR —así el globo y
/// el popup dicen lo mismo— y se revalida al aceptar.
public enum VisitPlanner {
    /// Ningún guion deja la torre con menos que esto.
    public static let minimumUnitsLeft = 2

    public static func offer(
        _ script: VisitorsConfig.Script,
        config: VisitorsConfig,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        economy: EconomyConfig,
        valuation: VisitValuation
    ) -> VisitOffer? {
        let coinsPerSecond = config.coinsSecondsScale * valuation.coinsPerSecond

        func priced(_ rewards: [RewardSpec]) -> (coins: Double, others: [RewardSpec]) {
            var coins = 0.0
            var others: [RewardSpec] = []
            for reward in rewards {
                if case .coinsSeconds(let seconds) = reward {
                    coins += seconds * coinsPerSecond
                } else {
                    others.append(reward)
                }
            }
            return (coins, others)
        }

        /// Lo que cuesta reponerlo, sin los modificadores del momento: un
        /// Liquidación no abarata una indemnización.
        func replacement(_ typeId: String) -> Double? {
            var bare = state
            bare.run.activeModifiers = []
            return TowerActions.hireQuote(typeId: typeId, state: bare, config: economy, floorTable: floorTable,
                                          tiers: tiers, costMultiplier: valuation.hireCostMultiplier)?.cost
        }

        func option(
            _ id: String, _ kind: VisitOption.Kind, coins: Double = 0, rewards: [RewardSpec] = [],
            departures: [BoardChange] = [], video: Bool = false, challenge: ChallengeTerms? = nil
        ) -> VisitOption {
            VisitOption(id: id, kind: kind, coins: coins, rewards: rewards, departures: departures,
                        requiresVideo: video, challenge: challenge)
        }

        func make(_ options: [VisitOption], subject: String? = nil) -> VisitOffer {
            VisitOffer(scriptId: script.id, visitorId: script.visitor, subjectTypeId: subject, options: options)
        }

        func pick(_ unitPick: VisitorsConfig.UnitPick, count: Int, maxTier: Int = .max) -> PickedUnits? {
            pickUnits(unitPick, count: count, maxTier: maxTier, state: state, tower: tower, tiers: tiers, floorTable: floorTable)
        }

        switch script.mechanic {
        case let .gift(rewards, videoDoubles):
            let base = priced(rewards)
            var options = [option("accept", .accept, coins: base.coins, rewards: base.others)]
            if videoDoubles {
                let doubled = priced(rewards.map { $0.scaled(by: 2) })
                options.append(option("video", .acceptWithVideo, coins: doubled.coins, rewards: doubled.others, video: true))
            }
            return make(options)

        case let .arrest(unitPick, bailMultiplier, releaseMultiplier):
            guard let unit = pick(unitPick, count: 1), let price = replacement(unit.typeId) else { return nil }
            return make([
                option("bail", .payBail, coins: -price * bailMultiplier),
                option("release", .release, coins: price * releaseMultiplier, departures: unit.departures),
            ], subject: unit.typeId)

        case let .fine(seconds, capFraction, stamp):
            let amount = min(seconds * coinsPerSecond, state.run.coins * capFraction)
            guard amount >= 1 else { return nil }
            return make([
                option("pay", .payFine, coins: -amount, rewards: [stamp]),
                option("video", .forgiveWithVideo, video: true),
            ])

        case let .exchange(costSeconds, oro, dailyOroCap):
            if let dailyOroCap, state.meta.engagement.visitors.oroExchangedToday + oro > dailyOroCap { return nil }
            return make([option("exchange", .exchange, coins: -costSeconds * coinsPerSecond, rewards: [.oro(oro)])])

        case let .sale(unitPick, priceMultiplier, tiersBelowFrontier):
            guard let unit = pick(unitPick, count: 1, maxTier: state.run.maxTierReached - tiersBelowFrontier),
                  let price = replacement(unit.typeId)
            else { return nil }
            return make([option("sell", .sell, coins: price * priceMultiplier, departures: unit.departures)], subject: unit.typeId)

        case let .take(unitPick, count, rewards, minValueMultiplier):
            guard let unit = pick(unitPick, count: count), let price = replacement(unit.typeId) else { return nil }
            let base = priced(rewards)
            let coins = max(base.coins, price * Double(count) * minValueMultiplier)
            return make([option("accept", .accept, coins: coins, rewards: base.others, departures: unit.departures)],
                        subject: unit.typeId)

        case let .challenge(taps, windowSeconds, rewards, videoDoubles):
            let base = priced(rewards)
            let terms = ChallengeTerms(taps: taps, windowSeconds: windowSeconds, coins: base.coins,
                                       rewards: base.others, videoDoubles: videoDoubles)
            return make([option("challenge", .startChallenge, challenge: terms)])

        case .vendor(let cards):
            return make(cards.map { option("card.\($0.id)", .card, rewards: [$0.reward], video: true) })

        case .gossip(let rewards):
            let base = priced(rewards)
            return make([option("listen", .listen, coins: base.coins, rewards: base.others)])
        }
    }

    /// La opción contra el tablero y la caja de AHORA: sigue valiendo, se
    /// replanea a quién se lleva (mismo tipo, mismo piso) o `nil` si ya no hay trato.
    public static func revalidate(_ option: VisitOption, state: PlayerState, tower: TowerState) -> VisitOption? {
        guard state.run.coins >= option.cost else { return nil }
        guard let first = option.departures.first else { return option }
        guard case let .departure(ordinal, _, typeId) = first.kind,
              state.run.totalUnits - option.departures.count >= minimumUnitsLeft,
              (state.run.units[typeId] ?? 0) - option.departures.count >= 1
        else { return nil }
        let stillThere = option.departures.allSatisfy { change in
            guard case let .departure(floor, slot, type) = change.kind else { return false }
            return tower.typeId(floorOrdinal: floor, slot: slot) == type
        }
        if stillThere { return option }
        let slots = tower.placements(onFloor: ordinal)
            .filter { $0.typeId == typeId }
            .map(\.slot)
            .sorted()
            .suffix(option.departures.count)
        guard slots.count == option.departures.count else { return nil }
        let departures = zip(option.departures, slots).map { change, slot in
            change.replanned(.departure(floorOrdinal: ordinal, slot: slot, typeId: typeId))
        }
        return VisitOption(id: option.id, kind: option.kind, coins: option.coins, rewards: option.rewards,
                           departures: departures, requiresVideo: option.requiresVideo, challenge: option.challenge)
    }

    struct PickedUnits {
        let typeId: String
        let departures: [BoardChange]
    }

    /// A quién se lleva: un tipo con por lo menos `count + 1` (nunca el último de
    /// su tipo), sin dejar la torre con menos de `minimumUnitsLeft`.
    static func pickUnits(
        _ unitPick: VisitorsConfig.UnitPick,
        count: Int,
        maxTier: Int,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> PickedUnits? {
        guard count >= 1, state.run.totalUnits - count >= minimumUnitsLeft else { return nil }
        let candidates = state.run.units
            .compactMap { id, amount -> CharacterType? in
                guard let type = tiers.type(id: id), !type.isChoiceNode, type.tier <= maxTier, amount - count >= 1 else {
                    return nil
                }
                return type
            }
            .sorted { $0.tier == $1.tier ? $0.id < $1.id : $0.tier < $1.tier }
        guard let type = unitPick == .highestDuplicate ? candidates.last : candidates.first else { return nil }
        let ordinal = floorTable.ordinal(forTier: type.tier)
        let slots = tower.placements(onFloor: ordinal).filter { $0.typeId == type.id }.map(\.slot).sorted().suffix(count)
        guard slots.count == count else { return nil }
        return PickedUnits(typeId: type.id, departures: slots.map { slot in
            BoardChange(kind: .departure(floorOrdinal: ordinal, slot: slot, typeId: type.id), origin: .visitor)
        })
    }
}
