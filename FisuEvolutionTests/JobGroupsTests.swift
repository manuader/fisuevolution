import EconomyKit
import Testing
@testable import FisuEvolution

@Suite("FisuJobs: grupos por sección y por piso", .serialized)
@MainActor
struct JobGroupsTests {
    /// La frontera al tope: la compuerta de tiers deja todo contratable, así que
    /// las abiertas se reparten por todos los pisos.
    private func openEverything(_ gameState: GameState) throws {
        let topTier = try #require(gameState.content).tiers.maxTier
        gameState.debugSetMaxTier(topTier)
        gameState.debugUnlockFloors(throughTier: topTier)
        gameState.debugMarkTypesSeen(throughTier: topTier)
    }

    @Test("las abiertas se parten por piso, en el orden de jobRows; el resto no lleva piso")
    func openJobsAreGroupedByFloor() async throws {
        let gameState = await makeGameState()
        try openEverything(gameState)
        let floorTable = try #require(gameState.content).floorTable

        let groups = JobGroups.make(gameState.jobRows) { floorTable.ordinal(of: $0) }

        let open = groups.filter { $0.section == .open }
        let ordinals = open.compactMap(\.floorOrdinal)
        #expect(open.count >= 2)
        #expect(ordinals.count == open.count)
        #expect(ordinals == ordinals.sorted(by: >), "jobRows entrega los tiers de arriba abajo y no se reordena")
        #expect(Set(open.compactMap(\.floorID)).count == open.count, "un piso, un grupo")
        #expect(open.allSatisfy { group in group.rows.allSatisfy { $0.floorID == group.floorID } })
        #expect(open.allSatisfy { $0.floorOrdinal == floorTable.ordinal(of: $0.floorID ?? "") })
        #expect(groups.filter { $0.section != .open }.allSatisfy { $0.floorID == nil })
        #expect(groups.first?.section == .open)
    }

    @Test("el título de la sección sale una sola vez y la cascada cuenta la lista completa")
    func sectionTitleOnceAndStartIndexesCountEverything() async throws {
        let gameState = await makeGameState()
        try openEverything(gameState)
        let floorTable = try #require(gameState.content).floorTable
        let rows = gameState.jobRows

        let groups = JobGroups.make(rows) { floorTable.ordinal(of: $0) }

        let sections = groups.map(\.section)
        #expect(groups.filter(\.opensSection).count == Set(sections).count)
        var expectedStart = 0
        for group in groups {
            #expect(group.startIndex == expectedStart)
            expectedStart += group.rows.count
        }
        #expect(expectedStart == rows.count)
    }

    @Test("el cartel del LED lleva el número y el nombre, o el misterio")
    func ledTextShowsNumberAndNameOrMystery() {
        #expect(TowerNaming.ledText(ordinal: 2, floorID: "corporate", isUnlocked: true)
            == "3 · \(TowerNaming.floorName(for: "corporate"))")
        #expect(TowerNaming.ledText(ordinal: 2, floorID: "corporate", isUnlocked: false)
            == "3 · \(String(localized: "tower.floor.unknown"))")
    }
}
