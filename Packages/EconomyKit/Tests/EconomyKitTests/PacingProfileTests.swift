import Foundation
import Testing
@testable import EconomyKit

@Suite("Los perfiles del simulador: lo que se da sin video")
struct PacingProfileTests {
    private func packages(interval: Double = 120) -> PackagesConfig {
        PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: interval, firstPackageAfterSeconds: interval,
                       maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4])
    }

    private func sources() -> PacingSources {
        PacingSources(
            packages: packages(),
            dailyMinutes: [5, 8, 12, 18, 25, 40, 15],
            freeBoosts: [
                .init(id: "fernet", cooldownSeconds: 3600, effect: .incomeBurst(multiplier: 3, seconds: 90)),
                .init(id: "asado", cooldownSeconds: 21600, effect: .payoutMinutes(10)),
                .init(id: "milanesa", cooldownSeconds: 86400, effect: .offlineStep(step: 0.05, cap: 1.0)),
            ],
            freeHireSeconds: 120
        )
    }

    private func run(_ profile: PacingProfile, _ sources: PacingSources, seed: Double = 0.5) throws -> PacingSimulator.Report {
        try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                            profile: profile, sources: sources, seedFraction: seed).run(maxDays: 5)
    }

    @Test(".bare con fuentes es la base: las fuentes sólo se juegan con su perfil")
    func bareIgnoresSources() throws {
        let base = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(fingerprint(try run(.bare, sources())) == fingerprint(base))
        #expect(fingerprint(try run(.free, .none)) == fingerprint(base))
    }

    @Test(".free cobra sus fuentes y llega antes")
    func freeUsesItsSources() throws {
        let base = try run(.bare, .none)
        let free = try run(.free, sources())
        #expect((free.sourceTotals["packages.opened"] ?? 0) > 0)
        #expect((free.sourceTotals["coins.daily"] ?? 0) > 0)
        #expect((free.sourceTotals["coins.boosts"] ?? 0) > 0)
        #expect(free.finalLifetimeEarnings > base.finalLifetimeEarnings)
    }

    @Test("el paquete sigue su reloj de juego: con la mitad del intervalo caen casi el doble")
    func packageCadence() throws {
        func opened(_ interval: Double) throws -> Double {
            let report = try run(.free, PacingSources(packages: packages(interval: interval), dailyMinutes: [],
                                                      freeBoosts: [], freeHireSeconds: 0))
            return report.sourceTotals["packages.opened"] ?? 0
        }
        let slow = try opened(240)
        let fast = try opened(120)
        #expect(slow > 0)
        #expect(fast >= 1.6 * slow, "120 s: \(fast) · 240 s: \(slow)")
    }

    @Test("es determinístico, y la semilla sólo mueve el orden de los sorteos")
    func deterministic() throws {
        #expect(fingerprint(try run(.free, sources())) == fingerprint(try run(.free, sources())))
        // Cambia el orden de los sorteos y con él el instante en que llega a
        // Dios, así que lo que se compara es el ritmo (paquetes por segundo activo).
        func rate(_ report: PacingSimulator.Report) -> Double {
            (report.sourceTotals["packages.opened"] ?? 0) / (report.godActive ?? .infinity)
        }
        let a = rate(try run(.free, sources(), seed: 0.1))
        let b = rate(try run(.free, sources(), seed: 0.9))
        #expect(a > 0)
        #expect(abs(a - b) <= 0.05 * a, "0,1: \(a) · 0,9: \(b)")
    }

    @Test("el sorteo del paquete sin torre es el de la torre")
    func eligibleWithoutTowerIsTheGames() throws {
        var fx = try fxStateAndTower(units: ["a": 2, "b": 1])
        fx.state.run.raiseFrontier(to: 4, cushion: fxConfig().priceCushion)
        let occupancy = fx.tower.floors.map(\.occupiedCount)
        let withTower = PackageRoller.eligibleTypes(state: fx.state, tower: fx.tower, tiers: try fxTiers(),
                                                    floorTable: fx.floorTable, config: fxConfig())
        let without = PackageRoller.eligibleTypes(state: fx.state, tiers: try fxTiers(), floorTable: fx.floorTable,
                                                  config: fxConfig(), occupancy: occupancy)
        #expect(without.map(\.id) == withTower.map(\.id))
    }
}
