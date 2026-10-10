import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los premios que no piden anuncio no pasan del 12 % de la producción de un
/// día (PLAN-v2 E2a). Analítico: el día es el del jugador del simulador
/// (`PacingSimulator.HumanModel`) y la producción se mide en minutos del pasivo
/// base, la misma unidad en la que se pagan los premios. Cuenta lo que se
/// repite cada día (el diario y el asado); logros, carreras y cofres son de una vez.
/// Se mide en minutos de producción base: con la torre parada (arranque o
/// recién reencarnado) el piso del premio puede pasar el 12 %.
@Suite("Presupuesto de premios sin anuncios")
struct RewardBudgetTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func dailyMinutes() throws -> [Double] {
        let days = content.dailyRewards.days.sorted { $0.day < $1.day }
        let minutes = days.compactMap(\.minutes)
        try #require(minutes.count == days.count, "cada día declara sus minutos")
        return minutes
    }

    private func asado() throws -> BoostsConfig.Boost {
        try #require(content.boosts.boosts.first { $0.effectType == .periodicPayout })
    }

    @Test("los minutos del dueño: el diario 5/8/12/18/25/40 y 15, el asado 10")
    func theOwnersTable() throws {
        #expect(try dailyMinutes() == [5, 8, 12, 18, 25, 40, 15])
        #expect(try asado().magnitude == 10)
    }

    @Test("el diario promedio más el asado no pasan del 12 % de un día")
    func recurringRewardsFitTheBudget() throws {
        let human = PacingSimulator.HumanModel()
        let daily = try dailyMinutes()
        let asado = try asado()
        let asadoPerDay = RewardBudget.asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        let perDay = daily.reduce(0, +) / Double(daily.count) + asadoPerDay
        let budget = RewardBudget.share * RewardBudget.productionMinutesPerDay(content: content, human: human)
        #expect(perDay <= budget, "\(perDay) min contra \(budget)")
    }

    @Test("ni el mejor día del ciclo pasa del 12 %")
    func theBestDayFitsTheBudget() throws {
        let human = PacingSimulator.HumanModel()
        let bestDay = try #require(try dailyMinutes().max())
        let asado = try asado()
        let best = bestDay + RewardBudget.asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        let budget = RewardBudget.share * RewardBudget.productionMinutesPerDay(content: content, human: human)
        #expect(best <= budget, "\(best) min contra \(budget)")
    }
}

/// El día del jugador del simulador, en minutos de producción (E2a T11).
enum RewardBudget {
    static let share = 0.12

    /// Las sesiones enteras más el offline entre sesiones, con la eficiencia
    /// base y el tope (556 min con el modelo y el `economy.json` de hoy).
    static func productionMinutesPerDay(content: GameContent, human: PacingSimulator.HumanModel) -> Double {
        let starts = human.sessionStartOffsets.sorted()
        let cap = content.economy.offlineCapHours * 3600
        var offline = 0.0
        for (index, start) in starts.enumerated() {
            let next = index + 1 < starts.count ? starts[index + 1] : human.daySeconds + starts[0]
            offline += min(max(0, next - (start + human.sessionSeconds)), cap)
        }
        let active = Double(starts.count) * human.sessionSeconds
        return (active + offline * content.economy.offlineEfficiencyBase) / 60
    }

    /// Cuántas veces por día se cobra el asado: al empezar cada sesión, si ya pasó el cooldown.
    static func asadoClaimsPerDay(_ human: PacingSimulator.HumanModel, cooldown: Double) -> Double {
        let starts = human.sessionStartOffsets.sorted()
        var lastClaim = -Double.infinity
        var claims = 0
        for day in 0..<7 {
            for start in starts {
                let now = Double(day) * human.daySeconds + start
                if now - lastClaim >= cooldown {
                    claims += 1
                    lastClaim = now
                }
            }
        }
        return Double(claims) / 7
    }

    /// Lo que queda del 12 % de un día después del diario promedio y el asado.
    static func leftAfterDailyAndAsado(content: GameContent, human: PacingSimulator.HumanModel) throws -> Double {
        let minutes = content.dailyRewards.days.compactMap(\.minutes)
        let daily = minutes.reduce(0, +) / Double(max(1, minutes.count))
        let asado = try #require(content.boosts.boosts.first { $0.effectType == .periodicPayout })
        let asadoPerDay = asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        return share * productionMinutesPerDay(content: content, human: human) - (daily + asadoPerDay)
    }
}

/// Lo que el simulador no juega (PLAN-v2 E2b): visitantes y eventos se miden
/// acá, contra el mismo 12 % de un día que el diario y el asado.
@Suite("Presupuesto: visitantes, eventos, consumibles y logros")
struct EngagementBudgetTests {
    let content: GameContent
    let human = PacingSimulator.HumanModel()

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private var activeMinutesPerDay: Double {
        Double(human.sessionStartOffsets.count) * human.sessionSeconds / 60
    }

    private func isGift(_ mechanic: VisitorsConfig.Mechanic) -> Bool {
        switch mechanic {
        case .gift, .challenge, .gossip: true
        default: false
        }
    }

    private func giftMinutesPerVisit() -> Double {
        let visitors = content.visitors
        let main = visitors.scripts.filter { $0.lane == .main && !$0.eventOnly }
        let weights = main.reduce(0.0) { $0 + Double($1.weight) }
        guard weights > 0 else { return 0 }
        let gifts = main.filter { isGift($0.mechanic) }.reduce(0.0) { sum, script in
            let seconds = script.mechanic.rewards.reduce(0.0) { total, reward in
                if case .coinsSeconds(let s) = reward { return total + s }
                return total
            }
            return sum + Double(script.weight) * seconds
        }
        return gifts / weights * visitors.coinsSecondsScale / 60
    }

    private func giftMinutesPerEvent() -> Double {
        let events = content.events.events
        let weights = events.reduce(0.0) { $0 + Double($1.weight) }
        guard weights > 0 else { return 0 }
        let gifts = events.filter { $0.polarity == .positive }.reduce(0.0) { sum, event in
            sum + Double(event.weight) * event.effects.reduce(0.0) { total, effect in
                if case .coinsSeconds(let s) = effect { return total + s }
                return total
            }
        }
        return gifts / weights / 60
    }

    private func spentPerDay() -> Double {
        let visits = content.visitors
        let minutesBetweenVisits = (visits.intervalMinSeconds + visits.intervalMaxSeconds) / 2 / 60
        let visitsPerDay = activeMinutesPerDay / minutesBetweenVisits
        let eventsPerDay = activeMinutesPerDay / (content.events.intervalSeconds / 60)
        return visitsPerDay * giftMinutesPerVisit() + eventsPerDay * giftMinutesPerEvent()
    }

    @Test("los números que leemos del contenido son finitos y positivos")
    func theInputsAreSane() {
        let visits = content.visitors
        #expect(visits.coinsSecondsScale.isFinite && visits.coinsSecondsScale > 0)
        #expect(visits.intervalMinSeconds.isFinite && visits.intervalMaxSeconds.isFinite)
        #expect(content.events.intervalSeconds.isFinite && content.events.intervalSeconds > 0)
        #expect(spentPerDay().isFinite)
    }

    @Test("visitantes y eventos entran en lo que el diario y el asado dejan del 12 %")
    func visitorsAndEventsFit() throws {
        let spent = spentPerDay()
        let left = try RewardBudget.leftAfterDailyAndAsado(content: content, human: human)
        #expect(spent <= left, "visitantes y eventos regalan \(spent) min/día; quedan \(left)")
    }

    @Test("los consumibles de ORO respetan el ancla: 1 h de producción vale 45 a 135 ORO")
    func consumablesFollowTheAnchor() {
        for item in content.oroShop.items where !item.isPermanent {
            guard let price = item.price else { continue }
            let hours = item.rewards.reduce(0.0) { total, reward in
                switch reward {
                case .coinsSeconds(let s): return total + s / 3600
                case .modifier(let effect, let k, let seconds)
                    where effect == .incomeMultiplier || effect == .passiveMultiplier:
                    return total + (k - 1) * seconds / 3600
                default: return total
                }
            }
            guard hours > 0 else { continue }
            let perHour = Double(price) / hours
            #expect(perHour >= 45 && perHour <= 135, "\(item.id): \(perHour) ORO por hora de producción")
        }
    }
}
