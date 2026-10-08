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
    static let budget = 0.12
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    /// Las sesiones enteras más el offline entre sesiones, con la eficiencia
    /// base y el tope (556 min con el modelo y el `economy.json` de hoy).
    private func productionMinutesPerDay(_ human: PacingSimulator.HumanModel) -> Double {
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
    private func asadoClaimsPerDay(_ human: PacingSimulator.HumanModel, cooldown: Double) -> Double {
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
        let asadoPerDay = asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        let perDay = daily.reduce(0, +) / Double(daily.count) + asadoPerDay
        let budget = Self.budget * productionMinutesPerDay(human)
        #expect(perDay <= budget, "\(perDay) min contra \(budget)")
    }

    @Test("ni el mejor día del ciclo pasa del 12 %")
    func theBestDayFitsTheBudget() throws {
        let human = PacingSimulator.HumanModel()
        let bestDay = try #require(try dailyMinutes().max())
        let asado = try asado()
        let best = bestDay + asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        let budget = Self.budget * productionMinutesPerDay(human)
        #expect(best <= budget, "\(best) min contra \(budget)")
    }
}
