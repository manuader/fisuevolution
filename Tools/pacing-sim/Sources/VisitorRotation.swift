import EconomyKit
import Foundation

/// La rotación de visitantes sobre la partida simulada (E14 C5): el motor de la
/// app (`VisitorScheduler`, un reloj y la bolsa) corriendo sobre el tiempo
/// ACTIVO del bot, con el tier de la run de cada momento. El bot no juega a los
/// visitantes: esto mide quién viene y cuánto, no lo que cambia la curva.
///
/// Supuestos (declarados en la salida): los especiales se cuentan conseguidos
/// (el bot no junta especiales, y sin eso diez de los 18 no vendrían nunca),
/// todo premio es entregable y toda oferta es posible (el bot no tiene un
/// tablero con duplicados que mirar).
struct VisitorRotation {
    struct Row {
        let visitor: String
        let visits: Int
        /// Horas ACTIVAS en que el visitante estuvo desbloqueado.
        let unlockedHours: Double
        var perHour: Double { unlockedHours > 0 ? Double(visits) / unlockedHours : 0 }
    }

    let rows: [Row]
    let totalVisits: Int
    let hours: Double
    /// Minutos de producción que regalan los guiones de regalo, por visita.
    let giftMinutesPerVisit: Double
    /// Las visitas de guiones con cupo semanal (la Marcha, E14b B25) y el blue que pagan si se ganan
    /// todas, sin el ×2 de video.
    let weeklyVisits: Int
    let weeklyBlue: Int
    let weeks: Double

    /// El tier de la run abierta a los `active` segundos activos.
    static func tier(at active: Double, report: PacingSimulator.Report) -> Int {
        var start = 0.0
        for (index, reached) in report.tierReachedPerRun.enumerated() {
            let end = index < report.reincarnationActiveSeconds.count ? report.reincarnationActiveSeconds[index] : .infinity
            if active < end || index == report.tierReachedPerRun.count - 1 {
                let elapsed = active - start
                return reached.filter { $0.value <= elapsed }.keys.max() ?? 1
            }
            start = end
        }
        return 1
    }

    static func run(
        config: VisitorsConfig,
        report: PacingSimulator.Report,
        human: PacingSimulator.HumanModel,
        seed: UInt64
    ) -> VisitorRotation {
        let horizon = report.godActive ?? report.reincarnationActiveSeconds.last ?? 0
        let activePerDay = Double(human.sessionStartOffsets.count) * human.sessionSeconds
        let specials = Set(config.visitors.filter { $0.kind == .special }.map(\.id))
        let grantable = Set(RewardSpec.Kind.allCases)
        var rng = SplitMix64(seed: seed)
        var state = VisitorsState.initial
        var visits: [String: Int] = [:]
        var unlockedSeconds: [String: Double] = [:]
        var giftSeconds = 0.0
        var total = 0
        var weeklyVisits = 0
        var weeklyBlue = 0
        // El tick de la app: el reloj de visitas no cuenta más que eso por paso.
        let step = min(1.0, IncomeTicker.deltaClampThreshold)
        var active = 0.0
        while active < horizon {
            let context = VisitContext(maxTier: tier(at: active, report: report), ownedSpecials: specials, grantable: grantable)
            for id in VisitorScheduler.unlockedVisitors(config: config, context: context) {
                unlockedSeconds[id, default: 0] += step
            }
            let day = Int(active / max(activePerDay, 1))
            VisitorScheduler.rollWeek(&state, week: "w\(day / 7)")
            VisitorScheduler.rollDay(&state, today: "d\(day)")
            if VisitorScheduler.advance(&state, delta: step, config: config) {
                if let script = VisitorScheduler.pickNext(config: config, state: &state, context: context,
                                                          isOfferable: { _ in true }, rng: &rng) {
                    VisitorScheduler.markVisited(script, state: &state, config: config, rng: &rng)
                    visits[script.visitor, default: 0] += 1
                    total += 1
                    giftSeconds += giftCoinsSeconds(script) * config.coinsSecondsScale
                    if script.weeklyCap != nil {
                        weeklyVisits += 1
                        weeklyBlue += script.mechanic.rewards.reduce(0) { total, reward in
                            if case .blue(let amount) = reward { return total + amount }
                            return total
                        }
                    }
                } else {
                    VisitorScheduler.retrySoon(state: &state, config: config)
                }
            }
            active += step
        }
        let rows = config.visitors.map {
            Row(visitor: $0.id, visits: visits[$0.id] ?? 0, unlockedHours: (unlockedSeconds[$0.id] ?? 0) / 3600)
        }
        return VisitorRotation(rows: rows, totalVisits: total, hours: horizon / 3600,
                               giftMinutesPerVisit: total > 0 ? giftSeconds / Double(total) / 60 : 0,
                               weeklyVisits: weeklyVisits, weeklyBlue: weeklyBlue,
                               weeks: horizon / max(activePerDay, 1) / 7)
    }

    private static func giftCoinsSeconds(_ script: VisitorsConfig.Script) -> Double {
        switch script.mechanic {
        case .gift, .challenge, .gossip:
            script.mechanic.rewards.reduce(0.0) { total, reward in
                if case .coinsSeconds(let seconds) = reward { return total + seconds }
                return total
            }
        default: 0
        }
    }

    func print() {
        Swift.print("\n-- Visitantes (E14 C5): la bolsa sobre \(String(format: "%.1f", hours)) h ACTIVAS hasta Dios --")
        Swift.print("  supuestos: especiales conseguidos, premios entregables, toda oferta posible;"
            + " sin tutorial ni presentadores de eventos ocupando el escenario")
        for row in rows.sorted(by: { $0.perHour > $1.perHour }) {
            Swift.print("  \(pad(row.visitor, 22)) \(String(format: "%4d", row.visits)) visitas"
                + "  \(String(format: "%6.1f", row.unlockedHours)) h desbloqueado"
                + "  \(String(format: "%5.2f", row.perHour)) por hora")
        }
        let rates = rows.filter { $0.unlockedHours > 0 }.map(\.perHour)
        let missing = rows.filter { $0.visits == 0 }.map(\.visitor)
        Swift.print("  total \(totalVisits) visitas · por hora entre \(String(format: "%.2f", rates.min() ?? 0))"
            + " y \(String(format: "%.2f", rates.max() ?? 0)) · regalo medio \(String(format: "%.2f", giftMinutesPerVisit)) min de producción por visita")
        Swift.print(missing.isEmpty ? "  ✅ vinieron los \(rows.count)" : "  ❌ no vinieron: \(missing.joined(separator: ", "))")
        Swift.print("  cupo semanal (la Marcha): \(weeklyVisits) visitas en \(String(format: "%.1f", weeks)) semanas"
            + " · hasta \(weeklyBlue) blue si se ganan todas (×2 con video: \(weeklyBlue * 2)); el bot no las juega")
    }
}

/// Un generador con semilla: la rotación sale igual en cada corrida.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
