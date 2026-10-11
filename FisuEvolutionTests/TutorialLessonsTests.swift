import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las lecciones del tablero y la torre (PLAN-v2 E9b T1): cada una nace sólo cuando hay algo que
/// hacer en su pantalla —y los tests de «no nace si X» prueban también que con X cumplida SÍ—.
@Suite("Las lecciones del currículo v2: el tablero y la torre", .serialized)
@MainActor
struct TutorialLessonsTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "lessons-\(UUID().uuidString).json")
        ))
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    /// Deja a `lesson` como la única que puede nacer.
    private func only(_ lesson: GameState.TutorialLesson, in gameState: GameState) {
        for other in GameState.TutorialLesson.allCases where other != lesson { gameState.markLessonDone(other) }
    }

    private func baseType(_ gameState: GameState) throws -> CharacterType {
        try #require(gameState.content?.tiers.baseType)
    }

    private func fillFloor(_ gameState: GameState, ordinal: Int = 0) {
        let capacity = gameState.floorOccupancy(ordinal: ordinal).capacity
        for _ in gameState.floorOccupancy(ordinal: ordinal).occupied..<capacity {
            gameState.hireCharacter(typeId: "homeless")
        }
        gameState.refreshProjections()
    }

    // MARK: El atajo

    @Test("el atajo: tocar → mantener → fijar → soltar → el botón gris")
    func quickHireWalksItsFiveSteps() async throws {
        let gameState = await makeGameState()
        only(.quickHire, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.tap")

        gameState.tutorialTipCompleted(.quickHire)
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.hold")
        #expect(gameState.tutorialRun?.step?.hand == .hold)

        gameState.tutorialSignal(.pickerOpened)
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.pin")
        #expect(gameState.tutorialRun?.step?.target == .pickerFace)

        gameState.pinQuickHire(typeId: try baseType(gameState).id)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.unpin")

        gameState.pinQuickHire(typeId: nil)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.blocked")
        #expect(gameState.tutorialRun?.step?.clockKind == .explain)
    }

    @Test("fijar sin que el selector se haya abierto no salta el paso de mantener")
    func pinningBeforeTheHoldStepDoesNotSkip() async throws {
        let gameState = await makeGameState()
        only(.quickHire, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.tutorialTipCompleted(.quickHire)
        gameState.pinQuickHire(typeId: try baseType(gameState).id)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.hold")
    }

    @Test("el atajo no nace con el piso lleno, y con lugar sí")
    func quickHireNeedsARealPurchase() async {
        let gameState = await makeGameState()
        only(.quickHire, in: gameState)
        gameState.debugGrantCoins()
        gameState.markLessonDone(.quickHire)
        fillFloor(gameState)
        gameState.debugGrantCoins()
        #expect(gameState.quickHireOffer?.blocker == .floorFull)
        gameState.tutorialLessonsAutorun = true
        #expect(!gameState.isEligible(.quickHire), "enseñaría un botón que no compra")
        gameState.player?.run.units = [:]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.quickHireOffer?.blocker == nil)
        #expect(gameState.isEligible(.quickHire))
    }

    @Test("el piso lleno: nace con el botón gris por piso lleno, y no con lugar en el piso")
    func floorFullNeedsTheBlocker() async {
        let gameState = await makeGameState()
        only(.floorFull, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.floorFull), "con lugar en el piso el botón compra: no hay nada que explicar")
        fillFloor(gameState)
        gameState.debugGrantCoins()
        #expect(gameState.isEligible(.floorFull))
        #expect(GameState.TutorialLesson.floorFull.steps.map(\.id) == ["floor_full.explain"])
    }

    // MARK: Mejoras y pasivo

    @Test("el pasivo nace sólo con un pasivo pagable")
    func passiveNeedsAnAffordablePassive() async throws {
        let gameState = await makeGameState()
        only(.passive, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "sin plata no hay nada que pagar")
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.lessonID == "passive")
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["passive.open", "passive.unlock", "passive.done"])
    }

    @Test("el pasivo ya desbloqueado en todos los vistos no enseña nada")
    func passiveAlreadyUnlockedTeachesNothing() async throws {
        let gameState = await makeGameState()
        only(.passive, in: gameState)
        gameState.debugGrantCoins()
        for id in try #require(gameState.player).run.seenTypes { gameState.player?.run.passiveUnlocked[id] = true }
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.passive))
        #expect(gameState.tutorialRun == nil)
        for id in try #require(gameState.player).run.seenTypes { gameState.player?.run.passiveUnlocked[id] = false }
        gameState.refreshProjections()
        #expect(gameState.isEligible(.passive))
    }

    @Test("Mejoras: abrir → comprar un nivel → el cierre vive en el tablero")
    func upgradesWalksItsSteps() async {
        let gameState = await makeGameState()
        only(.upgrades, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "upgrades.open")
        gameState.tutorialTipHandled(opening: .upgrades)
        gameState.uiCoversBoard = true
        #expect(gameState.tutorialRun?.step?.id == "upgrades.buy")
        #expect(gameState.tutorialRun?.step?.surface == .page(.upgrades))
        if let type = gameState.characterUpgradeTypes.first { gameState.buyCharacterUpgrade(typeID: type.id) }
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "upgrades.done")
        #expect(gameState.tutorialRun?.step?.surface == .board,
                "cerrada la hoja, un paso de hoja volvería a pedir «abrí Mejoras»")
    }

    @Test("cerrar el menú después de comprar no vuelve a pedir abrir Mejoras")
    func closingTheMenuAfterBuyingDoesNotLoop() async {
        let gameState = await makeGameState()
        only(.upgrades, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.tutorialTipHandled(opening: .upgrades)
        gameState.uiCoversBoard = true
        if let type = gameState.characterUpgradeTypes.first { gameState.buyCharacterUpgrade(typeID: type.id) }
        gameState.refreshProjections()
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "upgrades.done")
    }

    // MARK: El menú, los pisos y la reencarnación

    @Test("el organigrama nace con cuatro tipos vistos y el Menú abierto en la barra")
    func orgChartNeedsFourTypesAndTheMenu() async throws {
        let gameState = await makeGameState()
        only(.orgChart, in: gameState)
        let concrete = try #require(gameState.content).tiers.concreteTypes.map(\.id)
        gameState.player?.run.seenTypes = Set(concrete.prefix(4))
        gameState.refreshProjections()
        #expect(!gameState.unlockedTabs.contains(.menu))
        #expect(!gameState.isEligible(.orgChart), "sin la pestaña del Menú no hay a dónde ir")
        TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
        gameState.player?.run.seenTypes = Set(concrete.prefix(3))
        gameState.refreshProjections()
        #expect(gameState.unlockedTabs.contains(.menu))
        #expect(!gameState.isEligible(.orgChart), "con tres tipos todavía no hay jerarquías")
        gameState.player?.run.seenTypes = Set(concrete.prefix(4))
        gameState.refreshProjections()
        #expect(gameState.isEligible(.orgChart))
        #expect(GameState.TutorialLesson.orgChart.steps.map(\.id) == ["org_chart.open", "org_chart.card"])
    }

    @Test("deslizar pisos espera a la lección del ascensor y al segundo piso")
    func floorSwipeNeedsTwoFloorsAndTheElevatorLesson() async {
        let gameState = await makeGameState()
        only(.floorSwipe, in: gameState)
        gameState.markLessonDone(.elevator)
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.floorSwipe), "con un solo piso no hay a dónde deslizar")
        gameState.debugUnlockFloors(throughTier: 5)
        gameState.refreshProjections()
        #expect(gameState.unlockedFloorsCount >= 2)
        #expect(gameState.isEligible(.floorSwipe))
        #expect(gameState.tutorialRun?.step?.hand == .swipe(.up))
    }

    @Test("los pisos en marcha: sólo con la perilla prendida y un piso lleno")
    func staffedFloorsNeedTheKnobAndAFullFloor() async throws {
        let gameState = await makeGameState()
        only(.staffedFloors, in: gameState)
        let content = try #require(gameState.content)
        let base = try baseType(gameState)
        gameState.player?.run.units = [base.id: content.floorTable[0].capacity]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.staffedFloors), "con la perilla en 0 el bono no existe")
        gameState.replaceEconomy(try content.economy.tuned(EconomyKnobs(staffedFloorBonus: 0.05)))
        #expect(gameState.isEligible(.staffedFloors))
        gameState.player?.run.units = [base.id: 1]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.staffedFloors), "sin un piso lleno no hay nada en marcha")
    }

    @Test("el piso móvil: nace bloqueado por la pared, y la reencarnación lista ya no")
    func prestigeGateNeedsTheWall() async throws {
        let gameState = await makeGameState()
        only(.prestigeGate, in: gameState)
        let content = try #require(gameState.content)
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.prestigeGate))
        gameState.economy = StandardEconomy(config: try content.economy.tuned(EconomyKnobs(requiresLastRunWall: true)))
        gameState.giveEarningsForPrestigeTesting(oro: 9)
        gameState.player?.meta.lastRunMaxTier = 13
        _ = gameState.player?.run.raiseFrontier(to: 9)
        gameState.refreshProjections()
        #expect(gameState.prestigePreview.isBlockedByWall)
        #expect(gameState.isEligible(.prestigeGate))
        #expect(GameState.TutorialLesson.prestigeGate.steps.first?.target == .prestige)
    }

    @Test("reencarnar: el ORO se explica y después se pide tocar")
    func prestigeExplainsThenAsks() async {
        let gameState = await makeGameState()
        only(.prestige, in: gameState)
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["prestige.oro", "prestige.open"])
        #expect(gameState.tutorialRun?.step?.clockKind == .explain)
    }

    // MARK: La ficha

    @Test("la ficha nace con tres contrataciones y alguien en el piso, y señala a un empleado")
    func characterSheetNeedsHiresAndSomeone() async {
        let gameState = await makeGameState()
        only(.characterSheet, in: gameState)
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.characterSheet), "una partida nueva no contrató a nadie")
        gameState.player?.meta.stats.totalHiresEver = 3
        gameState.refreshProjections()
        #expect(gameState.isEligible(.characterSheet))
        #expect(gameState.tutorialRun?.step?.id == "character_sheet.hold")
        #expect(gameState.tutorialBoardTarget == .anyUnit, "las lecciones también piden el recorte del tablero")
        gameState.tutorialSignal(.characterSheetOpened)
        gameState.characterSheet = gameState.characterSheet(forTypeId: "homeless")
        #expect(gameState.characterSheet != nil)
        #expect(gameState.tutorialRun?.step?.id == "character_sheet.inside")
        #expect(gameState.tutorialRun?.step?.surface == .characterSheet)
        gameState.refreshProjections()
        #expect(gameState.tutorialBoardTarget == nil, "dentro de la ficha ya no se señala el tablero")
    }

    @Test("al terminar la lección el recorte del tablero se suelta")
    func theBoardTargetIsReleasedWhenTheRunEnds() async {
        let gameState = await makeGameState()
        only(.characterSheet, in: gameState)
        gameState.player?.meta.stats.totalHiresEver = 3
        gameState.refreshProjections()
        #expect(gameState.tutorialBoardTarget == .anyUnit)
        gameState.finishTutorialRun()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.tutorialBoardTarget == nil)
    }

    // MARK: El registro

    @Test("las de la 2.0 no se dan por vistas al veterano, y las de la v1 sí")
    func declaredRelease() {
        let v2: [GameState.TutorialLesson] = [.quickHire, .staffedFloors, .prestigeGate, .characterSheet]
        for lesson in v2 { #expect(lesson.introducedIn == .v2, "\(lesson)") }
        let v1: [GameState.TutorialLesson] = [.passive, .upgrades, .orgChart, .elevator, .floorSwipe, .floorFull, .prestige]
        for lesson in v1 { #expect(lesson.introducedIn == .v1, "\(lesson)") }
    }

    @Test("cada lección con guion propio tiene sus pasos y ya no lleva el texto heredado")
    func scriptedLessonsLeaveTheLegacyText() {
        let scripted: [GameState.TutorialLesson] = [
            .quickHire, .passive, .upgrades, .orgChart, .floorSwipe, .floorFull, .staffedFloors, .prestigeGate,
            .prestige, .characterSheet,
        ]
        for lesson in scripted {
            #expect(lesson.textKey == nil, "\(lesson)")
            #expect(!lesson.steps.isEmpty, "\(lesson)")
        }
    }

    @Test("los huecos de T1 quedaron cubiertos por su lección")
    func theT1GapsAreCovered() {
        let expected: [TutorialMechanic: GameState.TutorialLesson] = [
            .passiveIncome: .passive, .orgChart: .orgChart, .floorSwipe: .floorSwipe, .floorFull: .floorFull,
            .characterSheet: .characterSheet, .staffedFloors: .staffedFloors, .prestigeGate: .prestigeGate,
        ]
        for (mechanic, lesson) in expected {
            #expect(mechanic.coverage == .lesson(lesson), "\(mechanic)")
            #expect(!TutorialMechanic.knownGaps.contains(mechanic), "\(mechanic)")
        }
    }
}
