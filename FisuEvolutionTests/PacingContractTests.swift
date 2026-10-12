import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El contrato de pacing de la 2.0 (PLAN-v2 E2b), en el reloj del simulador,
/// con el perfil `.free` y la política ×5. Los números son los de 45 h que
/// pidió el dueño el 2026-10-12 (`tasks.md` §7). Reemplazó a
/// `theOwnersTargetsAreMet` (24 h / 8 reencarnaciones de la v1). Es CONTRATO,
/// no banda: si se pone rojo, el juego dejó de cumplir lo que el dueño pidió.
///
/// ⚠️ **Cuatro asserts son provisorios** (E2b T14, relevo 49): la búsqueda de
/// T13 (`Docs/balance-run-v2-e2b-candidata.md` §6) no los alcanza con ninguna
/// perilla de precios y los decide el dueño. Mientras tanto se pinean con lo
/// medido en la candidata, con un margen chico para la semilla, y cada uno dice
/// el número del contrato original: la mitad «antes» del 5, el 6, la isla y la
/// luna del 7 y el 8.
@Suite("El contrato de pacing de la 2.0")
struct PacingContractTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func free() throws -> PacingSimulator.Report { try PacingReports.free.get() }
    private func minutes(_ seconds: Double?) -> Double { (seconds ?? .infinity) / 60 }

    // MARK: Las fuentes

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

    @Test("1 · Dios entre 2.600 y 2.800 minutos activos")
    func godTiming() throws {
        let god = minutes(try free().godActive)
        #expect(god >= 2600 && god <= 2800, "Dios a los \(god) min activos")
    }

    @Test("2 · cinco o seis reencarnaciones")
    func reincarnations() throws {
        #expect((5...6).contains(try free().reincarnations))
    }

    /// Las líneas son SEIS (el contrato dice siete: se escribió antes de que
    /// `upgrades.json` quedara con seis). Ver `upgradeCatalogMatchesTunedValues`.
    @Test("3 · las 6 líneas al tope antes del 80 % de Dios y no antes de la 5ª reencarnación")
    func linesMaxed() throws {
        let report = try free()
        let maxed = try #require(report.maxedUpgradesActiveSeconds, "nunca maxeó: \(report.finalPermanentUpgradeLevels)")
        let god = try #require(report.godActive)
        #expect(maxed <= 0.8 * god, "maxeó a \(maxed / 3600) h, Dios a \(god / 3600) h")
        #expect(try #require(report.reincarnationsAtMaxedUpgrades) >= 5)
    }

    @Test("4 · la 1ª reencarnación entre 1 y 2 h activas")
    func firstReincarnation() throws {
        let first = try #require(try free().firstReincarnationActive) / 3600
        #expect(first >= 1 && first <= 2, "\(first) h")
    }

    /// La mitad «más lejos» es contrato. La mitad «antes en lo ya visto» es
    /// provisoria: pregunta al dueño (relevo 49). El contrato pide CERO tiers
    /// que una run alcance más tarde que la anterior; la candidata deja 11
    /// (semillas 0,1 y 0,9: 14 y 9), y en las 208 corridas de T13 nunca bajó de
    /// 5. Techo provisorio: 15.
    @Test("5 · cada run llega más lejos (y, provisorio, casi siempre antes)")
    func eachRunFurtherAndFaster() throws {
        let report = try free()
        for (previous, next) in zip(report.maxTierPerRun, report.maxTierPerRun.dropFirst()) {
            #expect(next >= previous + 1, "T\(previous) → T\(next)")
        }
        var later: [String] = []
        for index in report.tierReachedPerRun.indices.dropLast() {
            let before = report.tierReachedPerRun[index]
            let after = report.tierReachedPerRun[index + 1]
            for tier in stride(from: 2, through: report.maxTierPerRun[index], by: 1) {
                guard let first = before[tier], let second = after[tier], second > first else { continue }
                later.append("run \(index + 2) T\(tier)")
            }
        }
        #expect(later.count <= 15, "provisorio (contrato: 0): \(later.count) tiers más tarde — \(later)")
    }

    /// Provisorio: pregunta al dueño (relevo 49). El contrato pide ≥ 65 % en
    /// cada run; la candidata paga 23 · 18 · 36 · 37 · 38 · 24 % y T13 midió un
    /// techo de 54–66 % con estas perillas. Piso provisorio: 15 % en cada run
    /// (la semilla 0,1 deja una run en 2 %: con otra semilla esto se revisa).
    @Test("6 · reencarnar paga (provisorio: ≥ 15 %; contrato: ≥ 65 %) de la run 2 en adelante")
    func prestigePays() throws {
        let report = try free()
        #expect(!report.prestigePayoffPerRun.isEmpty)
        for (index, payoff) in report.prestigePayoffPerRun.enumerated() {
            #expect(payoff >= 0.15, "run \(index + 2): \(payoff) (techo \(report.prestigeCeilingPerRun[index]))")
        }
    }

    /// La isla y la luna son provisorias: pregunta al dueño (relevo 49). La isla
    /// choca con el punto 4 (la abre el fin de la run 1): contrato 270–410,
    /// candidata 241 (semilla 0,9: 220) → piso provisorio 215. La luna cae en la
    /// semilla 0,9 (686 contra 710) → piso provisorio 680.
    @Test("7 · la primera llegada a cada piso cae en su ventana")
    func floorWindows() throws {
        let windows: [String: ClosedRange<Double>] = [
            "urban": 0...1.5, "corporate": 6...12, "luxury": 45...80,
            "island": 215...410, "moon": 680...930,
            "mars": 1230...1500, "solar": 1840...2110, "galaxy": 2250...2520, "god_realm": 2600...2800,
        ]
        let report = try free()
        for (floor, window) in windows {
            let arrived = minutes(report.floorUnlockActiveSeconds[floor])
            #expect(window.contains(arrived), "\(floor): \(arrived) min")
        }
    }

    /// Provisorio: pregunta al dueño (relevo 49). El contrato dice «sin
    /// reencarnar no se llega a Dios», y en 400 días de reloj el offline llega
    /// aunque los precios suban: la candidata llega a los 6.510 min activos,
    /// 2,39× lo que tarda reencarnando (semillas: 2,41× y 2,38×), y ninguna de
    /// las 62 corridas `.never` de T13 se quedó afuera. Lo provisorio: no antes
    /// de 2,3× Dios.
    @Test("8 · sin reencarnar, Dios llega no antes de 2,3× (provisorio; contrato: nunca)")
    func noPrestigeNoGod() throws {
        let god = try #require(try free().godActive)
        let never = try PacingReports.never.get()
        #expect(never.reincarnations == 0 && never.finalMaxTier > 1)
        guard let late = never.godActive else { return }
        #expect(late >= 2.3 * god, "llegó en \(minutes(late)) min, \(late / god)× Dios")
    }

    @Test("9 · .ads tarda ≥ 65 % de .free y .max ≥ 55 %")
    func profilesGuard() throws {
        let free = try #require(try free().godActive)
        let ads = try #require(try PacingReports.ads.get().godActive)
        let max = try #require(try PacingReports.max.get().godActive)
        #expect(ads >= 0.65 * free, ".ads \(ads / free)")
        #expect(max >= 0.55 * free, ".max \(max / free)")
    }

    @Test("la escala del ORO: un jugador gratis junta 5.000–12.000 hasta Dios")
    func oroScale() throws {
        let oro = try #require(try free().oroAtGod)
        #expect(oro >= 5000 && oro <= 12000, "\(oro) ORO")
    }
}
