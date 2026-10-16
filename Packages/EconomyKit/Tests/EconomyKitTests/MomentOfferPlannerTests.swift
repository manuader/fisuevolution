import Foundation
import Testing
@testable import EconomyKit

/// El planificador del momento justo (2.1 E15 F3 T3, contrato C4): `base` nunca ve nada, sin video no sale
/// nada ni se gasta frecuencia, los topes mandan y el bandido elige entre los brazos del primer momento.
@Suite("El planificador del momento justo")
struct MomentOfferPlannerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let seed: UInt64 = 20_261_016

    private func seedConfig() throws -> MomentsConfig {
        try MomentsConfigTests.decode()
    }

    /// La semilla con los priors cambiados: un `α` enorme hace que el brazo gane casi seguro, un `β` enorme
    /// que pierda casi seguro.
    private func steered(toward winner: String) throws -> MomentsConfig {
        var config = try seedConfig()
        for index in config.arms.indices {
            let wins = config.arms[index].id == winner
            config.arms[index].alpha = wins ? 1_000_000 : 1
            config.arms[index].beta = wins ? 1 : 1_000_000
        }
        return config
    }

    private func next(
        _ moments: [NeedMoment] = [.priceWall],
        segment: PlayerSegment = .high,
        adReady: Bool = true,
        history: MomentHistory = MomentHistory(),
        at now: Date? = nil,
        config: MomentsConfig,
        seed: UInt64? = nil,
        canPay: (MomentReward) -> Bool = { _ in true }
    ) -> MomentDecision {
        var rng = SplitMix64(seed: seed ?? self.seed)
        return MomentOfferPlanner.next(
            moments: moments, segment: segment, adReady: adReady, history: history, now: now ?? start,
            config: config, bandit: config.bandit(), rng: &rng, canPay: canPay
        )
    }

    // MARK: - base y el video

    @Test("base nunca ve nada, con cualquier momento, video y semilla")
    func baseNeverSeesAnything() throws {
        let config = try steered(toward: "pw_small")
        for seed in UInt64(0)..<50 {
            #expect(next(NeedMoment.allCases, segment: .base, config: config, seed: seed) == .none)
        }
    }

    @Test("base no ve ni el control: el turno no se gasta")
    func baseDoesNotEvenGetTheControl() throws {
        #expect(next(segment: .base, config: try steered(toward: "control")) == .none)
    }

    @Test("sin video no sale nada y no se gasta frecuencia")
    func noAdNoOfferNoSpend() throws {
        let config = try steered(toward: "pw_small")
        var history = MomentHistory()
        for minute in 0..<30 {
            let now = start.addingTimeInterval(Double(minute) * 60)
            let decision = next(adReady: false, history: history, at: now, config: config)
            #expect(decision == .none)
            history.record(decision, at: now)
        }
        #expect(history.sessionTurns == 0)
        #expect(history.turns.isEmpty)
        let later = start.addingTimeInterval(30 * 60)
        #expect(next(history: history, at: later, config: config)
                == .offer(armId: "pw_small", moment: .priceWall, reward: .grant(.coinsSeconds(300))))
    }

    @Test("sin momentos no sale nada")
    func noMomentsNothing() throws {
        #expect(next([], config: try steered(toward: "pw_small")) == .none)
    }

    // MARK: - Lo que sale

    @Test("la oferta paga exactamente el premio de su brazo")
    func theOfferCarriesTheArmReward() throws {
        let config = try steered(toward: "pw_big")
        #expect(next(config: config) == .offer(armId: "pw_big", moment: .priceWall, reward: .grant(.coinsSeconds(600))))
        let merge = try steered(toward: "ff_merge")
        #expect(next([.floorFull], config: merge) == .offer(armId: "ff_merge", moment: .floorFull, reward: .mergeAll))
    }

    @Test("el control puede salir, con el momento para el ctx, y gasta el turno")
    func theControlCanWin() throws {
        let config = try steered(toward: "control")
        let decision = next(config: config)
        #expect(decision == .control(armId: "control", moment: .priceWall))
        var history = MomentHistory()
        history.record(decision, at: start)
        #expect(history.sessionTurns == 1)
        #expect(!history.offerOpen, "el control no muestra nada")
    }

    @Test("con los priors parejos salen ofertas y control: el bandido reparte")
    func evenPriorsSpread() throws {
        let config = try seedConfig()
        let picks = Set((UInt64(0)..<200).compactMap { next(config: config, seed: $0).armId })
        #expect(picks == ["pw_small", "pw_big", "control"])
    }

    @Test("un brazo de otro segmento no sale aunque sea el favorito")
    func armsOfOtherSegmentsNeverShow() throws {
        let config = try steered(toward: "pw_big")
        for seed in UInt64(0)..<200 {
            let decision = next(segment: .low, config: config, seed: seed)
            #expect(decision.armId != "pw_big")
            #expect(decision != .none)
        }
    }

    @Test("un momento sin brazos de oferta no saca al control solo")
    func aMomentWithoutOffersIsSkipped() throws {
        let config = try steered(toward: "control")
        #expect(next([.mattressReady, .backOffline], config: config) == .none)
    }

    @Test("el primer momento con oferta manda; si no hay nada que pagar, pasa al siguiente")
    func firstPayableMomentWins() throws {
        let config = try steered(toward: "ff_merge")
        #expect(next([.floorFull, .priceWall], config: config).armId == "ff_merge")
        let nothingToMerge = next([.floorFull, .priceWall], config: config, canPay: { $0 != .mergeAll })
        #expect(nothingToMerge.armId == "pw_small" || nothingToMerge.armId == "pw_big"
                || nothingToMerge.armId == "control")
        #expect(nothingToMerge.armId != "ff_merge")
        #expect(next([.floorFull], config: config, canPay: { $0 != .mergeAll }) == .none)
    }

    @Test("plata por encima del tope no sale aunque la config no se haya validado")
    func unvalidatedRewardAboveCapNeverShows() throws {
        var config = try steered(toward: "pw_big")
        let index = try #require(config.arms.firstIndex { $0.id == "pw_big" })
        config.arms[index].reward = .grant(.coinsSeconds(100_000))
        #expect(next(config: config).armId != "pw_big")
    }

    @Test("determinista con semilla: la misma semilla da la misma tanda")
    func deterministicWithSeed() throws {
        let config = try seedConfig()
        let first = (UInt64(0)..<40).map { next(config: config, seed: $0) }
        let second = (UInt64(0)..<40).map { next(config: config, seed: $0) }
        #expect(first == second)
    }

    // MARK: - Los topes

    @Test("una oferta a la vista por vez: hasta aceptar o rechazar no sale otra")
    func oneOfferAtATime() throws {
        let config = try steered(toward: "pw_small")
        var history = MomentHistory()
        history.record(next(config: config), at: start)
        let later = start.addingTimeInterval(3600)
        #expect(next(history: history, at: later, config: config) == .none)
        history.recordAccepted()
        #expect(next(history: history, at: later, config: config) != .none)
    }

    @Test("minSecondsBetween separa los turnos")
    func minSecondsBetweenIsRespected() throws {
        let config = try steered(toward: "pw_small")
        var history = MomentHistory()
        history.record(next(config: config), at: start)
        history.recordAccepted()
        let gap = config.caps.minSecondsBetween
        #expect(next(history: history, at: start.addingTimeInterval(gap - 1), config: config) == .none)
        #expect(next(history: history, at: start.addingTimeInterval(gap), config: config) != .none)
    }

    @Test("maxPerHour respetado en la hora corrida")
    func maxPerHourIsRespected() throws {
        var config = try steered(toward: "pw_small")
        config.caps.minSecondsBetween = 300
        config.caps.maxPerSession = MomentsConfig.Caps.hard.maxPerSession
        var history = MomentHistory()
        var shown: [TimeInterval] = []
        // Cada 5 minutos durante 3 horas, aceptando todo lo que sale.
        for step in 0..<36 {
            let now = start.addingTimeInterval(Double(step) * 300)
            let decision = next(history: history, at: now, config: config)
            history.record(decision, at: now)
            history.recordAccepted()
            if decision != .none { shown.append(now.timeIntervalSince(start)) }
        }
        for time in shown {
            let inHour = shown.filter { $0 >= time && $0 - time < 3600 }.count
            #expect(inHour <= config.caps.maxPerHour)
        }
        // Tres seguidos, la hora se llena, y vuelve a ofrecer cuando el primero sale de la ventana.
        #expect(shown == [0, 300, 600, 3600, 3900, 4200, 7200, 7500])
    }

    @Test("maxPerSession corta la sesión; una sesión nueva vuelve a contar")
    func maxPerSessionIsRespected() throws {
        var config = try steered(toward: "pw_small")
        config.caps.maxPerHour = MomentsConfig.Caps.hard.maxPerHour
        var history = MomentHistory()
        var now = start
        var shown = 0
        for _ in 0..<40 {
            let decision = next(history: history, at: now, config: config)
            history.record(decision, at: now)
            history.recordAccepted()
            if decision != .none { shown += 1 }
            now.addTimeInterval(config.caps.minSecondsBetween)
        }
        #expect(shown == config.caps.maxPerSession)
        #expect(next(history: history, at: now, config: config) == .none)
        history.startSession()
        #expect(next(history: history, at: now, config: config) != .none)
    }

    @Test("un rechazo abre la espera de ese momento, no la de los otros")
    func declineCoolsDownThatMoment() throws {
        let config = try steered(toward: "ff_merge")
        var history = MomentHistory()
        let first = next([.floorFull], history: history, config: config)
        #expect(first.armId == "ff_merge")
        history.record(first, at: start)
        history.recordDeclined(.floorFull, at: start)
        #expect(!history.offerOpen)

        let afterGap = start.addingTimeInterval(config.caps.minSecondsBetween)
        #expect(next([.floorFull], history: history, at: afterGap, config: config) == .none)
        let fallsThrough = next([.floorFull, .priceWall], history: history, at: afterGap, config: config)
        #expect(fallsThrough != .none)
        #expect(fallsThrough.armId != "ff_merge")

        let afterCooldown = start.addingTimeInterval(config.caps.cooldownAfterDeclineSeconds)
        #expect(next([.floorFull], history: history, at: afterCooldown, config: config).armId == "ff_merge")
    }

    @Test("una config sin validar no pasa los topes del código")
    func unvalidatedCapsAreClamped() throws {
        var config = try steered(toward: "pw_small")
        config.caps = .init(maxPerHour: 100, minSecondsBetween: 0, cooldownAfterDeclineSeconds: 0, maxPerSession: 100)
        var history = MomentHistory()
        history.record(next(config: config), at: start)
        history.recordAccepted()
        let hardGap = MomentsConfig.Caps.hard.minSecondsBetween
        #expect(next(history: history, at: start.addingTimeInterval(hardGap - 1), config: config) == .none)
    }

    @Test("con el reloj para atrás no sale nada antes de tiempo")
    func backwardsClockOffersLess() throws {
        let config = try steered(toward: "pw_small")
        var history = MomentHistory()
        history.record(next(config: config), at: start)
        history.recordAccepted()
        #expect(next(history: history, at: start.addingTimeInterval(-3600), config: config) == .none)
    }
}
