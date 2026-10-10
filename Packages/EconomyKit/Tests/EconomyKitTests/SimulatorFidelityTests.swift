import Foundation
import Testing
@testable import EconomyKit

@Suite("El simulador cobra con las funciones del juego")
struct SimulatorFidelityTests {
    private func midGame() throws -> (simulator: PacingSimulator, state: PlayerState) {
        let simulator = try upSimulator()
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1", offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        state.run.units = ["t1": 3, "t5": 2, "t6": 1]
        state.run.passiveUnlocked = ["t1": true, "t5": true]
        _ = state.run.raiseFrontier(to: 6, cushion: upConfig().priceCushion)
        state.meta.prestigeLevel = 3
        return (simulator, state)
    }

    private func floorTable() throws -> FloorTable {
        try FloorTable(floors: upConfig().floors, maxTier: 20)
    }

    @Test("el offline del bot es OfflineCalculator.earnings")
    func offlineIsTheGames() throws {
        let (simulator, state) = try midGame()
        var stamped = state
        stamped.meta.lastSeenTimestamp = 1000
        let expected = OfflineCalculator.earnings(
            state: stamped, tiers: try upTiers(), floorTable: try floorTable(), config: upConfig(), now: 1000 + 7200
        )
        #expect(expected > 0)
        #expect(abs(simulator.offlineCredit(state: state, from: 1000, to: 1000 + 7200) - expected) < 1e-9)
    }

    @Test("el offline del bot respeta el tope de horas del juego")
    func offlineIsCapped() throws {
        let (simulator, state) = try midGame()
        let cap = upConfig().offlineCapHours * 3600
        let atCap = simulator.offlineCredit(state: state, from: 0, to: cap)
        #expect(simulator.offlineCredit(state: state, from: 0, to: cap * 10) == atCap)
    }

    @Test("el pasivo del bot es IncomeTicker.basePassivePerSecond")
    func passiveIsTheGames() throws {
        let (simulator, state) = try midGame()
        let passive = IncomeTicker.basePassivePerSecond(
            state: state, tiers: try upTiers(), floorTable: try floorTable(), config: upConfig()
        )
        #expect(passive > 0)
        #expect(simulator.activeIncomeRate(state: state) > passive)
        #expect(abs(simulator.passiveRate(state: state) - passive) < 1e-12)
    }

    @Test("con el descuento de prestigio, el bot cotiza lo que cotiza FisuJobs")
    func prestigeDiscountIsTheGames() throws {
        let unlocks = PrestigeUnlocks(schemaVersion: 1, spawnDiscountCap: 0.5, levels: [
            .init(level: 1, spawnCostDiscount: 0.05), .init(level: 3, spawnCostDiscount: 0.1),
        ])
        let (_, state) = try midGame()
        let simulator = try PacingSimulator(config: upConfig(), tiers: upTiers(), prestigeUnlocks: unlocks)
        let game = try #require(TowerActions.hireQuote(
            typeId: "t1", state: state, config: upConfig(), floorTable: try floorTable(), tiers: try upTiers(),
            costMultiplier: 1 - unlocks.cumulativeSpawnDiscount(atPrestigeLevel: 3), now: 0
        ))
        let list = try #require(TowerActions.hireQuote(
            typeId: "t1", state: state, config: upConfig(), floorTable: try floorTable(), tiers: try upTiers()
        ))
        let bot = try #require(simulator.quote(typeId: "t1", state: state, now: 0))
        #expect(bot.cost == game.cost)
        #expect(bot.cost < list.cost)
    }

    @Test("sin descuento de prestigio el bot juega igual que antes, y con uno vacío también")
    func nilUnlocksIsTheBaseline() throws {
        let empty = PrestigeUnlocks(schemaVersion: 1, spawnDiscountCap: 0, levels: [])
        let base = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let withEmpty = try PacingSimulator(
            config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(), prestigeUnlocks: empty
        ).run(maxDays: 5)
        #expect(fingerprint(withEmpty) == fingerprint(base))
    }

    @Test("el reporte trae las series del contrato")
    func contractSeries() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(report.reincarnations > 1)
        #expect(report.tierReachedPerRun.count == report.reincarnations + 1)
        #expect(report.oroGainedPerReincarnation.count == report.reincarnations)
        #expect(report.actionSecondsBackToPreviousWall.count == report.secondsBackToPreviousWall.count)
        for (action, back) in zip(report.actionSecondsBackToPreviousWall, report.secondsBackToPreviousWall) {
            #expect(action > 0 && action <= back, "acción \(action) contra vuelta \(back)")
        }
        for (ceiling, payoff) in zip(report.prestigeCeilingPerRun, report.prestigePayoffPerRun) {
            #expect(payoff <= ceiling + 1e-12, "el pago no puede pasar su techo")
        }
        for run in report.tierReachedPerRun {
            #expect(run[1] == 0)
        }
    }

    @Test("el ORO al llegar a Dios cuenta el que había por reencarnar")
    func oroAtGod() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 90)
        let atGod = try #require(report.oroAtGod)
        #expect(atGod >= report.oroGainedPerReincarnation.reduce(0, +))
    }
}
