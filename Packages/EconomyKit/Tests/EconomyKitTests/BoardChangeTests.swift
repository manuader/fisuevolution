import Foundation
import Testing
@testable import EconomyKit

private typealias Board = (state: PlayerState, tower: TowerState, floorTable: FloorTable)

/// La frontera sube con lo revelado: un fixture que sólo sube `maxTierReached`
/// deja `revealedTier` atrás (`raiseFrontier` no lo toca) y `revealsSomethingNew`
/// contestaría por casualidad.
private func marking(_ board: Board, revealedUpTo tier: Int) -> Board {
    var board = board
    board.state.run.raiseFrontier(to: tier)
    board.state.run.revealedTier = tier
    return board
}

@Suite("BoardChange: planear y aplicar")
struct BoardChangeTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func board(
        units: [String: Int],
        unlockedFloors: [String] = ["f1", "f2"],
        chosenCareerPath: String? = nil
    ) throws -> Board {
        var fx = try fxStateAndTower(units: units, unlockedFloors: unlockedFloors)
        fx.state.run.chosenCareerPath = chosenCareerPath
        let top = units.keys.compactMap { tiers.type(id: $0)?.tier }.max() ?? 1
        return marking(fx, revealedUpTo: top)
    }

    private func autoMerge(_ fx: Board) -> BoardChange? {
        BoardChangePlanner.planAutoMerge(state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .debug)
    }

    private func evolve(_ fx: Board, maxSourceTier: Int = .max, origin: BoardChange.Origin = .debug) -> BoardChange? {
        BoardChangePlanner.planEvolve(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable,
            maxSourceTier: maxSourceTier, origin: origin
        )
    }

    private func arrival(_ typeId: String, _ fx: Board, origin: BoardChange.Origin = .debug) -> BoardChange? {
        BoardChangePlanner.planArrival(
            typeId: typeId, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: origin
        )
    }

    private func revalidated(_ change: BoardChange, _ fx: Board) -> BoardChange? {
        BoardChangePlanner.revalidate(change, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable)
    }

    private func reveals(_ change: BoardChange, _ fx: Board) -> Bool {
        BoardChangePlanner.revealsSomethingNew(change, state: fx.state, tiers: tiers, floorTable: fx.floorTable)
    }

    @discardableResult
    private func apply(_ change: BoardChange, _ fx: inout Board) throws -> BoardChangeOutcome {
        try BoardChangeApplier.apply(change, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig())
    }

    // MARK: Merge automático

    @Test("el merge automático saltea el par que pide carrera")
    func autoMergeSkipsTheCareerPair() throws {
        let change = try #require(autoMerge(try board(units: ["a": 2, "b": 2])))
        #expect(change.resultTypeId == "b")
    }

    @Test("con la carrera elegida, el par más alto se funde")
    func autoMergeTakesTheHighestPairWithACareer() throws {
        let fx = try board(units: ["a": 2, "b": 2], chosenCareerPath: "prog")
        #expect(try #require(autoMerge(fx)).resultTypeId == "c_prog")
    }

    @Test("sin lugar arriba no se planea el ascenso")
    func autoMergeNeedsRoomUpstairs() throws {
        let fx = try board(units: ["b": 2, "d": 5], chosenCareerPath: "prog")
        #expect(autoMerge(fx) == nil)
    }

    @Test("si el par más alto no cabe, cae al siguiente")
    func autoMergeFallsBackToTheNextPair() throws {
        let fx = try board(units: ["a": 2, "b": 2, "d": 5], chosenCareerPath: "prog")
        #expect(try #require(autoMerge(fx)).resultTypeId == "b")
    }

    @Test("sin ningún par no hay merge")
    func autoMergeNeedsAPair() throws {
        #expect(autoMerge(try board(units: ["a": 1, "b": 1])) == nil)
    }

    @Test("a igual tier, el par se elige por id: el plan no depende del orden de un diccionario")
    func autoMergeTieBreaksByTypeId() throws {
        let fx = try board(units: ["c_prog": 2, "c_law": 2])
        let change = try #require(autoMerge(fx))
        guard case .merge(_, let typeId, _, _, _) = change.kind else {
            Issue.record("el plan no es un merge")
            return
        }
        #expect(typeId == "c_law")
    }

    @Test("el merge planeado funde el par en los dos slots más bajos y conserva el origen")
    func autoMergePicksTheLowestSlots() throws {
        var fx = try board(units: ["a": 3])
        let free = try #require(fx.tower.floors[0].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: 0, fromSlot: 0, toSlot: free, tower: &fx.tower))
        let change = try #require(BoardChangePlanner.planAutoMerge(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .rewardedInstantMerge
        ))
        #expect(change.origin == .rewardedInstantMerge)
        #expect(change.kind == .merge(floorOrdinal: 0, typeId: "a", sourceSlot: 1, targetSlot: 2, newTypeId: "b"))
    }

    // MARK: Evolución

    @Test("la evolución elige la mejor unidad que puede crecer sola")
    func evolveSkipsChoiceNodes() throws {
        let fx = try board(units: ["a": 1, "b": 1])
        let change = try #require(evolve(fx, origin: .eventStartup))
        #expect(change.resultTypeId == "b")
        #expect(change.origin == .eventStartup)
    }

    @Test("si la mejor unidad no puede crecer, cae a la siguiente")
    func evolveFallsBackToTheNextUnit() throws {
        let fx = try board(units: ["a": 1, "d": 1])
        let change = try #require(evolve(fx))
        #expect(change.kind == .evolve(floorOrdinal: 0, slot: 0, typeId: "a", newTypeId: "b"))
    }

    @Test("la evolución con tope nunca toca una unidad por encima de él")
    func evolveRespectsTheCap() throws {
        let fx = try board(units: ["a": 1, "b": 1], unlockedFloors: ["f1", "f2"])
        #expect(evolve(fx, maxSourceTier: 0) == nil, "nadie está tan abajo")
        let change = try #require(evolve(fx, maxSourceTier: 1))
        guard case .evolve(_, _, let typeId, let newTypeId) = change.kind else { Issue.record("no es una evolución"); return }
        #expect(typeId == "a" && newTypeId == "b")
    }

    @Test("sin ninguna unidad que pueda crecer sola no hay evolución")
    func evolveNeedsAGrowableUnit() throws {
        #expect(evolve(try board(units: ["b": 1, "d": 1])) == nil)
    }

    @Test("evolucionar sube la frontera, marca visto y no toca las curvas")
    func applyingAnEvolution() throws {
        var fx = try board(units: ["a": 1])
        let change = try #require(evolve(fx, origin: .eventStartup))
        let outcome = try apply(change, &fx)
        #expect(outcome.tierBefore == 1)
        #expect(outcome.resultTypeId == "b")
        #expect(fx.state.run.maxTierReached == 2)
        #expect(fx.state.run.units == ["b": 1])
        #expect(fx.state.run.seenTypes.contains("b"))
        #expect(fx.state.run.hireCounts.isEmpty)
        #expect(fx.state.run.hireCountsByType.isEmpty)
        #expect(fx.state.meta.stats.totalHiresEver == 0)
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("evolucionar no es fusionar ni revela solo: la revelación es de quien la muestra")
    func evolvingIsNotAMergeNorARevelation() throws {
        var fx = try board(units: ["a": 1])
        let outcome = try apply(try #require(evolve(fx)), &fx)
        #expect(outcome.slot == 0)
        #expect(fx.state.meta.stats.totalMergesEver == 0)
        #expect(fx.state.run.revealedTier == 1)
    }

    // MARK: Merge aplicado

    @Test("un merge que asciende abre el piso nuevo y cuenta como fusión")
    func applyingAPromotingMerge() throws {
        var fx = try board(units: ["b": 2], unlockedFloors: ["f1"], chosenCareerPath: "prog")
        let change = try #require(autoMerge(fx))
        let outcome = try apply(change, &fx)
        #expect(outcome.tierBefore == 2)
        #expect(outcome.slot == nil)
        #expect(outcome.resultTypeId == "c_prog")
        #expect(outcome.promotedToFloor == 1)
        #expect(outcome.unlockedFloorId == "f2")
        #expect(fx.state.run.unlockedFloors == ["f1", "f2"])
        #expect(fx.state.run.maxTierReached == 3)
        #expect(fx.state.meta.stats.totalMergesEver == 1)
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("un merge que no cambia de piso deja el resultado en el slot destino")
    func applyingAStayingMerge() throws {
        var fx = try board(units: ["a": 2])
        let outcome = try apply(try #require(autoMerge(fx)), &fx)
        #expect(outcome.slot == 1)
        #expect(outcome.promotedToFloor == nil)
        #expect(outcome.unlockedFloorId == nil)
        #expect(fx.state.run.units == ["b": 1])
    }

    // MARK: Llegada

    @Test("una llegada necesita lugar en su piso, y su piso abierto")
    func arrivalNeedsRoom() throws {
        let full = try board(units: ["a": 5])
        #expect(arrival("b", full) == nil)
        let locked = try board(units: ["a": 1], unlockedFloors: ["f1"])
        #expect(arrival("d", locked) == nil)
    }

    @Test("un nodo de carrera no llega: no es un personaje")
    func arrivalIsNeverAChoiceNode() throws {
        #expect(arrival("choice", try board(units: ["a": 1])) == nil)
        #expect(arrival("nadie", try board(units: ["a": 1])) == nil)
    }

    @Test("una llegada no es una contratación")
    func arrivalIsNotAHire() throws {
        var fx = try board(units: ["a": 1])
        let change = try #require(arrival("a", fx, origin: .eventBlanqueo))
        try apply(change, &fx)
        #expect(fx.state.run.units["a"] == 2)
        #expect(fx.state.run.hireCounts.isEmpty)
        #expect(fx.state.run.hireCountsByType.isEmpty)
        #expect(fx.state.meta.stats.totalHiresEver == 0)
    }

    @Test("una llegada se coloca en su piso, se marca vista y sube la frontera")
    func applyingAnArrival() throws {
        var fx = try board(units: ["a": 1])
        let outcome = try apply(try #require(arrival("d", fx)), &fx)
        #expect(outcome.slot == 0)
        #expect(outcome.resultTypeId == "d")
        #expect(outcome.tierBefore == 1)
        #expect(fx.tower.typeId(floorOrdinal: 1, slot: 0) == "d")
        #expect(fx.state.run.seenTypes.contains("d"))
        #expect(fx.state.run.maxTierReached == 4)
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    // MARK: Salida

    @Test("una salida saca a la unidad del slot")
    func applyingADeparture() throws {
        var fx = try board(units: ["a": 2])
        let outcome = try apply(BoardChange(kind: .departure(floorOrdinal: 0, slot: 0, typeId: "a"), origin: .debug), &fx)
        #expect(outcome.slot == nil)
        #expect(outcome.resultTypeId == nil)
        #expect(fx.state.run.units == ["a": 1])
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("la última unidad de la torre no se va")
    func theLastUnitNeverLeaves() throws {
        var fx = try board(units: ["a": 1])
        let before = fx
        let change = BoardChange(kind: .departure(floorOrdinal: 0, slot: 0, typeId: "a"), origin: .debug)
        #expect(throws: TowerError.invalidSlot) { try apply(change, &fx) }
        #expect(fx.state == before.state)
        #expect(fx.tower == before.tower)
    }

    // MARK: Un plan viejo no aplica sobre otro tipo

    @Test("un plan viejo no aplica sobre un slot que cambió de tipo")
    func anOutdatedPlanNeverTouchesAnotherType() throws {
        let fx = try board(units: ["a": 2, "b": 1])
        let b = try #require(fx.tower.placements(onFloor: 0).first { $0.typeId == "b" })
        let a = try #require(fx.tower.placements(onFloor: 0).first { $0.typeId == "a" })
        let outdated: [BoardChange.Kind] = [
            .evolve(floorOrdinal: 0, slot: b.slot, typeId: "a", newTypeId: "b"),
            .departure(floorOrdinal: 0, slot: b.slot, typeId: "a"),
            .merge(floorOrdinal: 0, typeId: "a", sourceSlot: a.slot, targetSlot: b.slot, newTypeId: "b"),
            .merge(floorOrdinal: 0, typeId: "a", sourceSlot: b.slot, targetSlot: a.slot, newTypeId: "b"),
        ]
        for kind in outdated {
            var copy = fx
            #expect(throws: TowerError.invalidSlot) { try apply(BoardChange(kind: kind, origin: .debug), &copy) }
            #expect(copy.state == fx.state)
            #expect(copy.tower == fx.tower)
        }
    }

    // MARK: Revalidación

    @Test("lo planeado se replanea si el par se movió y se descarta si ya no está")
    func revalidation() throws {
        var fx = try board(units: ["a": 2])
        let change = try #require(autoMerge(fx))
        guard case .merge(let ordinal, _, let source, _, _) = change.kind else {
            Issue.record("el plan no es un merge")
            return
        }
        let free = try #require(fx.tower.floors[ordinal].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: ordinal, fromSlot: source, toSlot: free, tower: &fx.tower))
        let replanned = try #require(revalidated(change, fx))
        #expect(replanned.id == change.id)
        #expect(replanned != change)

        let pair = fxSlots(of: "a", onFloor: ordinal, in: fx.tower).sorted()
        _ = try TowerActions.applyMerge(
            floorOrdinal: ordinal, sourceSlot: pair[0], targetSlot: pair[1], newTypeId: "b",
            state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig()
        )
        #expect(revalidated(change, fx) == nil)
    }

    @Test("un plan intacto se devuelve tal cual")
    func revalidationKeepsAValidPlan() throws {
        let fx = try board(units: ["a": 2])
        let change = try #require(autoMerge(fx))
        #expect(revalidated(change, fx) == change)
    }

    @Test("un merge cuyo piso destino se llenó se descarta")
    func revalidationDropsAMergeWithoutRoom() throws {
        var fx = try board(units: ["b": 2], chosenCareerPath: "prog")
        let change = try #require(autoMerge(fx))
        for _ in 0..<5 {
            _ = try TowerActions.placeUnit(typeId: "d", state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig())
        }
        #expect(revalidated(change, fx) == nil)
    }

    @Test("una evolución sigue a su unidad cuando se movió y se descarta cuando ya no está")
    func evolveRevalidation() throws {
        var fx = try board(units: ["a": 1])
        let change = try #require(evolve(fx))
        let free = try #require(fx.tower.floors[0].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: 0, fromSlot: 0, toSlot: free, tower: &fx.tower))
        let replanned = try #require(revalidated(change, fx))
        #expect(replanned.id == change.id)
        #expect(replanned.kind == .evolve(floorOrdinal: 0, slot: free, typeId: "a", newTypeId: "b"))

        try apply(replanned, &fx)
        #expect(revalidated(change, fx) == nil)
    }

    @Test("una llegada vale mientras su piso esté abierto y con lugar")
    func arrivalRevalidation() throws {
        var fx = try board(units: ["a": 3])
        let change = try #require(arrival("a", fx))
        #expect(revalidated(change, fx) == change)
        for _ in 0..<2 {
            _ = try TowerActions.placeUnit(typeId: "a", state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig())
        }
        #expect(revalidated(change, fx) == nil)
    }

    @Test("una salida sigue a su unidad y se descarta cuando ya no está")
    func departureRevalidation() throws {
        var fx = try board(units: ["a": 1, "b": 1])
        let slot = try #require(fxSlot(of: "b", onFloor: 0, in: fx.tower))
        let change = BoardChange(kind: .departure(floorOrdinal: 0, slot: slot, typeId: "b"), origin: .debug)
        #expect(revalidated(change, fx) == change)

        let free = try #require(fx.tower.floors[0].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: 0, fromSlot: slot, toSlot: free, tower: &fx.tower))
        let replanned = try #require(revalidated(change, fx))
        #expect(replanned.id == change.id)
        #expect(replanned.kind == .departure(floorOrdinal: 0, slot: free, typeId: "b"))

        try apply(replanned, &fx)
        #expect(revalidated(change, fx) == nil)
    }

    // MARK: Qué apaga la UI

    @Test("un personaje sin revelar es algo nuevo")
    func revealsAnUnrevealedCharacter() throws {
        let fx = try board(units: ["a": 2])
        #expect(fx.state.run.revealedTier == 1)
        #expect(reveals(try #require(autoMerge(fx)), fx))
    }

    @Test("un personaje ya revelado, en un piso abierto, no es nada nuevo")
    func revealsNothingWhenEverythingIsKnown() throws {
        let fx = marking(try board(units: ["a": 2]), revealedUpTo: 2)
        #expect(!reveals(try #require(autoMerge(fx)), fx))
        #expect(!reveals(try #require(arrival("b", fx)), fx))
    }

    @Test("un piso sin abrir es algo nuevo aunque el personaje ya se haya revelado")
    func revealsAFloorThatWasClosed() throws {
        let closed = marking(try board(units: ["b": 2], unlockedFloors: ["f1"], chosenCareerPath: "prog"), revealedUpTo: 3)
        let change = try #require(autoMerge(closed))
        #expect(change.resultTypeId == "c_prog")
        #expect(reveals(change, closed))

        let open = marking(try board(units: ["b": 2], chosenCareerPath: "prog"), revealedUpTo: 3)
        #expect(!reveals(try #require(autoMerge(open)), open))
    }

    @Test("lo revelado se mide con revealedTier y no con la frontera")
    func revealsReadsRevealedTierNotTheFrontier() throws {
        var fx = try board(units: ["a": 2])
        fx.state.run.raiseFrontier(to: 3)
        #expect(fx.state.run.revealedTier == 1)
        #expect(reveals(try #require(autoMerge(fx)), fx))

        fx.state.run.revealedTier = 3
        #expect(!reveals(try #require(autoMerge(fx)), fx))
    }

    @Test("una salida no revela nada")
    func aDepartureRevealsNothing() throws {
        let fx = try board(units: ["a": 2])
        #expect(!reveals(BoardChange(kind: .departure(floorOrdinal: 0, slot: 0, typeId: "a"), origin: .debug), fx))
    }

    // MARK: Las preguntas del tipo

    @Test("cada cambio sabe a qué piso tiene que ir la escena")
    func floorOrdinalOfEachKind() throws {
        let fx = try board(units: ["b": 2, "d": 1], chosenCareerPath: "prog")
        let floorTable = fx.floorTable
        let merge = try #require(autoMerge(fx))
        #expect(merge.floorOrdinal(floorTable: floorTable, tiers: tiers) == 0)
        #expect(arrival("d", fx)?.floorOrdinal(floorTable: floorTable, tiers: tiers) == 1)
        let departure = BoardChange(kind: .departure(floorOrdinal: 1, slot: 0, typeId: "d"), origin: .debug)
        #expect(departure.floorOrdinal(floorTable: floorTable, tiers: tiers) == 1)
        #expect(BoardChange(kind: .arrival(typeId: "nadie"), origin: .debug).floorOrdinal(floorTable: floorTable, tiers: tiers) == nil)
    }

    @Test("el resultado de cada cambio")
    func resultTypeIdOfEachKind() {
        #expect(BoardChange(kind: .merge(floorOrdinal: 0, typeId: "a", sourceSlot: 0, targetSlot: 1, newTypeId: "b"), origin: .debug).resultTypeId == "b")
        #expect(BoardChange(kind: .evolve(floorOrdinal: 0, slot: 0, typeId: "a", newTypeId: "b"), origin: .debug).resultTypeId == "b")
        #expect(BoardChange(kind: .arrival(typeId: "d"), origin: .debug).resultTypeId == "d")
        #expect(BoardChange(kind: .departure(floorOrdinal: 0, slot: 0, typeId: "a"), origin: .debug).resultTypeId == nil)
    }
}

@Suite("BoardChange: los mutadores de TowerActions")
struct BoardChangeMutatorsTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func board(units: [String: Int], unlockedFloors: [String] = ["f1", "f2"]) throws -> Board {
        try fxStateAndTower(units: units, unlockedFloors: unlockedFloors)
    }

    private func evolve(
        _ newTypeId: String, floorOrdinal: Int = 0, slot: Int = 0, _ fx: inout Board
    ) throws -> TowerMergeResult {
        try TowerActions.evolveUnit(
            floorOrdinal: floorOrdinal, slot: slot, newTypeId: newTypeId,
            state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig()
        )
    }

    private func place(_ typeId: String, _ fx: inout Board) throws -> TowerPlacement {
        try TowerActions.placeUnit(
            typeId: typeId, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig()
        )
    }

    @Test("evolveUnit en el mismo piso deja el resultado en el slot de la unidad")
    func evolveStaysOnTheFloor() throws {
        var fx = try board(units: ["a": 2])
        let result = try evolve("b", slot: 1, &fx)
        #expect(result == .stayed(floorOrdinal: 0, slot: 1, newTypeId: "b"))
        #expect(fx.state.run.units == ["a": 1, "b": 1])
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("evolveUnit que cruza de piso abre el piso nuevo y no cuenta como fusión")
    func evolvePromotesAndUnlocks() throws {
        var fx = try board(units: ["b": 1], unlockedFloors: ["f1"])
        let result = try evolve("c_prog", &fx)
        #expect(result == .promoted(toFloorOrdinal: 1, slot: 0, newTypeId: "c_prog", unlockedFloorId: "f2"))
        #expect(fx.state.run.unlockedFloors == ["f1", "f2"])
        #expect(fx.state.run.units == ["c_prog": 1])
        #expect(fx.state.run.maxTierReached == 3)
        #expect(fx.state.run.seenTypes.contains("c_prog"))
        #expect(fx.state.meta.stats.totalMergesEver == 0)
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("evolveUnit con el piso destino lleno no muta nada")
    func evolveNeedsRoomUpstairs() throws {
        var fx = try board(units: ["b": 1, "d": 5])
        let before = fx
        #expect(throws: TowerError.destinationFloorFull(floorId: "f2")) { try evolve("c_prog", &fx) }
        #expect(fx.state == before.state)
        #expect(fx.tower == before.tower)
    }

    @Test("evolveUnit sobre un slot vacío o hacia un tipo inexistente no muta nada")
    func evolveRejectsWhatIsNotThere() throws {
        var fx = try board(units: ["a": 1])
        let before = fx
        #expect(throws: TowerError.invalidSlot) { try evolve("b", slot: 3, &fx) }
        #expect(throws: TowerError.invalidSlot) { try evolve("nadie", &fx) }
        #expect(fx.state == before.state)
        #expect(fx.tower == before.tower)
    }

    @Test("placeUnit usa el primer slot libre del piso del tipo y no toca contadores de compra")
    func placeTakesTheFirstFreeSlot() throws {
        var fx = try board(units: ["a": 2])
        let placement = try place("b", &fx)
        #expect(placement == TowerPlacement(floorOrdinal: 0, slot: 2, typeId: "b"))
        #expect(fx.state.run.units == ["a": 2, "b": 1])
        #expect(fx.state.run.hireCounts.isEmpty)
        #expect(fx.state.meta.stats.totalHiresEver == 0)
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("placeUnit en un piso cerrado o lleno no muta nada")
    func placeNeedsAnOpenFloorWithRoom() throws {
        var locked = try board(units: ["a": 1], unlockedFloors: ["f1"])
        let lockedBefore = locked
        #expect(throws: TowerError.floorLocked) { try place("d", &locked) }
        #expect(locked.state == lockedBefore.state)
        #expect(locked.tower == lockedBefore.tower)

        var full = try board(units: ["a": 5])
        let fullBefore = full
        #expect(throws: TowerError.floorFull) { try place("b", &full) }
        #expect(full.state == fullBefore.state)
        #expect(full.tower == fullBefore.tower)
    }

    @Test("placeUnit rechaza un nodo de carrera y un tipo inexistente")
    func placeRejectsWhatIsNotACharacter() throws {
        var fx = try board(units: ["a": 1])
        #expect(throws: TowerError.invalidSlot) { try place("choice", &fx) }
        #expect(throws: TowerError.invalidSlot) { try place("nadie", &fx) }
    }
}
