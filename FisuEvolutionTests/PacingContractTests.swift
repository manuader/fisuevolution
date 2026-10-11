import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El contrato de pacing de la 2.0 (PLAN-v2 E2b), en el reloj del simulador,
/// con el perfil `.free` y la política ×5. Reemplaza a `theOwnersTargetsAreMet`
/// (24 h / 8 reencarnaciones de la v1). Es CONTRATO, no banda: si se pone rojo,
/// el juego dejó de cumplir lo que el dueño pidió.
@Suite("El contrato de pacing de la 2.0")
struct PacingContractTests {
    private static let pending = Comment(rawValue: "E2b T14 lo prende con la calibración")

    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func free() throws -> PacingSimulator.Report { try PacingReports.free.get() }
    private func minutes(_ seconds: Double?) -> Double { (seconds ?? .infinity) / 60 }

    // MARK: Lo que corre desde ya

    @Test("las fuentes del contenido real llegan enteras al simulador")
    func sourcesArrive() throws {
        let sources = try PacingFixture.sources(content)
        #expect(sources.packages == content.packages)
        #expect(sources.dailyMinutes.count == content.dailyRewards.days.count)
        #expect(sources.freeBoosts.map(\.id).contains("asado"))
        #expect(sources.freeHireSeconds > 0)
        #expect(sources.ads?.wheel == content.wheel)
        #expect(sources.ads?.treasures == content.treasures)
        #expect(sources.ads?.packageRain == content.rewardedAds.effectiveSideRail.packageRain)
        #expect(sources.ads?.mergeAllCooldownSeconds == content.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds)
        #expect(sources.ads?.adBreakPrizes == content.rewardedAds.effectiveAdBreak.prizes)
        #expect((sources.ads?.adBreakIntervalSeconds ?? 0) > 0)
        #expect((sources.shop?.bestSupplierLevel ?? 0) > 0)
        #expect((sources.shop?.bonusDailyWheelSpins ?? 0) > 0)
    }

    @Test("las partidas se simulan y llegan a algún lado")
    func reportsRun() throws {
        for report in [try PacingReports.free.get(), try PacingReports.ads.get(), try PacingReports.max.get()] {
            #expect(report.finalMaxTier > 1)
        }
    }

    // MARK: El contrato

    @Test("1 · Dios entre 1.900 y 2.100 minutos activos", .disabled(pending))
    func godTiming() throws {
        let god = minutes(try free().godActive)
        #expect(god >= 1900 && god <= 2100, "Dios a los \(god) min activos")
    }

    @Test("2 · cinco o seis reencarnaciones", .disabled(pending))
    func reincarnations() throws {
        #expect((5...6).contains(try free().reincarnations))
    }

    @Test("3 · las 7 líneas al tope antes del 80 % de Dios y no antes de la 5ª reencarnación", .disabled(pending))
    func linesMaxed() throws {
        let report = try free()
        let maxed = try #require(report.maxedUpgradesActiveSeconds, "nunca maxeó: \(report.finalPermanentUpgradeLevels)")
        let god = try #require(report.godActive)
        #expect(maxed <= 0.8 * god, "maxeó a \(maxed / 3600) h, Dios a \(god / 3600) h")
        #expect(try #require(report.reincarnationsAtMaxedUpgrades) >= 5)
    }

    @Test("4 · la 1ª reencarnación entre 0,75 y 1,5 h activas", .disabled(pending))
    func firstReincarnation() throws {
        let first = try #require(try free().firstReincarnationActive) / 3600
        #expect(first >= 0.75 && first <= 1.5, "\(first) h")
    }

    @Test("5 · cada run llega más lejos y antes a cada tier ya visto", .disabled(pending))
    func eachRunFurtherAndFaster() throws {
        let report = try free()
        for (previous, next) in zip(report.maxTierPerRun, report.maxTierPerRun.dropFirst()) {
            #expect(next >= previous + 1, "T\(previous) → T\(next)")
        }
        for index in report.tierReachedPerRun.indices.dropLast() {
            let before = report.tierReachedPerRun[index]
            let after = report.tierReachedPerRun[index + 1]
            for tier in stride(from: 2, through: report.maxTierPerRun[index], by: 1) {
                guard let first = before[tier], let second = after[tier] else { continue }
                #expect(second <= first, "run \(index + 2), T\(tier): \(second) s contra \(first) s")
            }
        }
    }

    @Test("6 · reencarnar paga ≥ 65 % de la run 2 en adelante", .disabled(pending))
    func prestigePays() throws {
        let report = try free()
        #expect(!report.prestigePayoffPerRun.isEmpty)
        for (index, payoff) in report.prestigePayoffPerRun.enumerated() {
            #expect(payoff >= 0.65, "run \(index + 2): \(payoff) (techo \(report.prestigeCeilingPerRun[index]))")
        }
    }

    @Test("7 · la primera llegada a cada piso cae en su ventana", .disabled(pending))
    func floorWindows() throws {
        let windows: [String: ClosedRange<Double>] = [
            "urban": 0...1.5, "corporate": 6...10, "luxury": 35...60, "island": 200...300,
            "moon": 520...680, "mars": 900...1100, "solar": 1350...1550, "galaxy": 1650...1850,
            "god_realm": 1900...2100,
        ]
        let report = try free()
        for (floor, window) in windows {
            let arrived = minutes(report.floorUnlockActiveSeconds[floor])
            #expect(window.contains(arrived), "\(floor): \(arrived) min")
        }
    }

    @Test("8 · sin reencarnar no se llega a Dios", .disabled(pending))
    func noPrestigeNoGod() throws {
        let never = try PacingReports.never.get()
        #expect(never.godActive == nil, "llegó en \(minutes(never.godActive)) min")
    }

    @Test("9 · .ads tarda ≥ 55 % de .free y .max ≥ 50 %", .disabled(pending))
    func profilesGuard() throws {
        let free = try #require(try free().godActive)
        let ads = try #require(try PacingReports.ads.get().godActive)
        let max = try #require(try PacingReports.max.get().godActive)
        #expect(ads >= 0.55 * free, ".ads \(ads / free)")
        #expect(max >= 0.50 * free, ".max \(max / free)")
    }

    @Test("la escala del ORO: un jugador gratis junta 5.000–12.000 hasta Dios", .disabled(pending))
    func oroScale() throws {
        let oro = try #require(try free().oroAtGod)
        #expect(oro >= 5000 && oro <= 12000, "\(oro) ORO")
    }
}
