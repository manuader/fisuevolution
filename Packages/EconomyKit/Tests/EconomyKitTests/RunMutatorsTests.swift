import Foundation
import Testing
@testable import EconomyKit

@Suite("Run: mutadores únicos")
struct RunMutatorsTests {
    @Test("la frontera sólo sube")
    func frontierOnlyRises() {
        var run = fxState().run
        let rose = run.raiseFrontier(to: 3)
        let lowered = run.raiseFrontier(to: 2)
        #expect(rose)
        #expect(!lowered)
        #expect(run.maxTierReached == 3)
    }

    @Test("nadie fuera de RunState escribe la frontera a mano")
    func onlyRunStateWritesTheFrontier() throws {
        let sources = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/EconomyKit")
        let offenders = try FileManager.default
            .contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "PlayerState.swift" }
            .filter { try String(contentsOf: $0, encoding: .utf8).contains("maxTierReached = ") }
            .map(\.lastPathComponent)
        #expect(offenders.isEmpty, "escriben la frontera a mano: \(offenders)")
    }

    @Test("una contratación gratis no mueve la curva, pero cuenta como contratación")
    func freeHireDoesNotMoveTheCurve() throws {
        let fixture = try fxStateAndTower()
        var state = fixture.state
        var tower = fixture.tower
        state.run.coins = 0
        let quote = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: fixture.floorTable, tiers: try fxTiers(),
            costMultiplier: 0
        ))
        try TowerActions.hire(
            quote: quote, state: &state, tower: &tower, floorTable: fixture.floorTable, config: fxConfig(),
            countsAsPurchase: false
        )
        #expect(state.run.hireCounts.isEmpty)
        #expect(state.run.hireCountsByType.isEmpty)
        #expect(state.meta.stats.totalHiresEver == 1)
    }

    @Test("los contadores de un save v5 (enteros) decodifican como Double")
    func integerCountersDecode() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fxState())) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        run["hireCounts"] = ["f1": 3]
        run["hireCountsByType"] = ["a": 2]
        object["run"] = run
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.run.hireCounts["f1"] == 3)
        #expect(decoded.run.hireCountsByType["a"] == 2)
    }

    @Test("un contador fraccionario cotiza entre sus vecinos")
    func fractionalCountsPriceBetweenNeighbours() throws {
        let config = fxConfig()
        let floor = try fxFloorTable()[1]
        let one = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 1)
        let half = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 1.5)
        let two = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 2)
        #expect(one < half && half < two)
    }
}
