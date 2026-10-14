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
        // Apagada a mano: el `economy.json` de la 2.0 la trae en 0,05 (E2b T14).
        gameState.replaceEconomy(try content.economy.tuned(EconomyKnobs(staffedFloorBonus: 0)))
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
        gameState.giveEarningsForPrestigeTesting(blue: 9)
        gameState.player?.meta.lastRunMaxTier = 13
        _ = gameState.player?.run.raiseFrontier(to: 9)
        gameState.refreshProjections()
        #expect(gameState.prestigePreview.isBlockedByWall)
        #expect(gameState.isEligible(.prestigeGate))
        #expect(GameState.TutorialLesson.prestigeGate.steps.first?.target == .prestige)
    }

    @Test("reencarnar: el blue se explica y después se pide tocar")
    func prestigeExplainsThenAsks() async {
        let gameState = await makeGameState()
        only(.prestige, in: gameState)
        gameState.giveEarningsForPrestigeTesting(blue: 3)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["prestige.blue", "prestige.open"])
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

    // MARK: Regalos: boosts y cofres

    /// Todas las pestañas abiertas, como en el fixture de UI.
    private func openAllTabs(_ gameState: GameState) {
        gameState.progressiveTabsEnabled = false
        gameState.refreshProjections()
    }

    @Test("los boosts: nacen con un boost listo y Regalos aprendido, y no con uno ya usado")
    func boostsNeedAReadyBoostAndTheGiftsLesson() async throws {
        let gameState = await makeGameState()
        only(.boosts, in: gameState)
        openAllTabs(gameState)
        gameState.flagDefaults.removeObject(forKey: GameState.TutorialLesson.gifts.defaultsKey)
        #expect(!gameState.isEligible(.boosts), "Regalos todavía no se enseñó")
        gameState.markLessonDone(.gifts)
        #expect(gameState.isEligible(.boosts))

        gameState.player?.meta.stats.boostsActivatedEver = 1
        #expect(!gameState.isEligible(.boosts), "ya usó uno")
        gameState.player?.meta.stats.boostsActivatedEver = 0
        let now = Date().timeIntervalSince1970
        for boost in try #require(gameState.content).boosts.boosts { gameState.player?.meta.boostActivations[boost.id] = now }
        #expect(!gameState.isEligible(.boosts), "todos enfriándose: nada que activar")
        gameState.player?.meta.boostActivations = [:]
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["boosts.open", "boosts.explain"])
        #expect(gameState.tutorialRun?.steps.last?.target == .giftsBoosts)
    }

    @Test("los cofres: nacen con uno que se puede abrir")
    func chestsNeedAnOpenableChest() async throws {
        let gameState = await makeGameState()
        only(.chests, in: gameState)
        openAllTabs(gameState)
        #expect(!gameState.isEligible(.chests), "sin cofre esperando")
        gameState.player?.meta.chestsPending = 1
        #expect(gameState.isEligible(.chests))

        let reachable = gameState.chestUnlockedCharacterTypes
        let pool = try #require(gameState.content).skins.chestPool
        gameState.player?.meta.ownedSkins.append(contentsOf: pool.filter { reachable.contains($0.characterType) }.map(\.id))
        #expect(!pool.allSatisfy { gameState.player?.meta.ownedSkins.contains($0.id) == true }, "falta alguna de más arriba")
        #expect(!gameState.canOpenChest, "ya tiene todas las pintas a las que llegó")
        #expect(!gameState.isEligible(.chests), "abrir Regalos no tiene qué ofrecer")
        gameState.player?.meta.ownedSkins.removeAll()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["chests.open", "chests.explain"])
        #expect(gameState.tutorialRun?.steps.last?.target == .giftsChest)
    }

    // MARK: FisuJobs y el menú

    @Test("el +6 %: nace con cinco contrataciones y la fila recomendada a la vista, y no antes")
    func hirePriceStepNeedsFiveHires() async {
        let gameState = await makeGameState()
        only(.hirePriceStep, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.hirePriceStep), "todavía no contrató cinco")
        gameState.player?.meta.stats.totalHiresEver = 5
        #expect(gameState.isEligible(.hirePriceStep))
        gameState.player?.run.coins = 0
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.hirePriceStep), "sin plata la fila no es la recomendada")
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["hire_price_step.open", "hire_price_step.explain"])
    }

    @Test("deslizar el menú se cumple deslizando, y no nace con dos pestañas")
    func menuSwipeNeedsAPagerMove() async {
        let gameState = await makeGameState()
        only(.menuSwipe, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "una partida nueva tiene dos pestañas: no hay a dónde deslizar")
        openAllTabs(gameState)
        #expect(gameState.tutorialRun?.step?.id == "menu_swipe.open")
        gameState.menuDidOpen(at: .upgrades)
        #expect(gameState.tutorialRun?.step?.id == "menu_swipe.swipe")
        #expect(gameState.tutorialRun?.step?.hand == .swipe(.left))
        #expect(gameState.tutorialRun?.step?.target == .menuPager)
        gameState.menuPageChanged(to: .skins)
        #expect(gameState.tutorialRun == nil || gameState.tutorialRun?.isFinished == true)
    }

    @Test("abrir otra página sin deslizar no cumple el deslizar")
    func openingAnotherPageIsNotASwipe() async {
        let gameState = await makeGameState()
        only(.menuSwipe, in: gameState)
        openAllTabs(gameState)
        gameState.menuDidOpen(at: .upgrades)
        gameState.tutorialTipHandled(opening: .skins)
        #expect(gameState.tutorialRun?.step?.id == "menu_swipe.swipe")
    }

    @Test("las pestañas nuevas: nacen con un «¡Nuevo!» y no sin él")
    func newTabsNeedANewBadge() async {
        let gameState = await makeGameState()
        only(.newTabs, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.newTabs.isEmpty)
        #expect(gameState.tutorialRun == nil)
        gameState.progressiveTabsEnabled = false
        gameState.flagDefaults.set([GameScreen.gifts.rawValue], forKey: GameState.newTabsKey)
        gameState.refreshProjections()
        #expect(gameState.newTabs == [.gifts])
        #expect(gameState.isEligible(.newTabs))
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["new_tabs.explain"])
    }

    // MARK: La tienda de blue

    @Test("la tienda de blue pasa por la pestaña Boosts de Mejoras")
    func blueShopNeedsTheSpendHalf() async throws {
        let gameState = await makeGameState()
        only(.blueShop, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "sin blue no hay qué gastar")
        let cheapest = try #require(gameState.cheapestBlueShopPrice())
        gameState.player?.meta.blue = cheapest - 1
        #expect(!gameState.isEligible(.blueShop), "le falta uno")
        gameState.player?.meta.blue = cheapest
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["blue_shop.open", "blue_shop.spend", "blue_shop.caps"])

        gameState.menuDidOpen(at: .upgrades)
        #expect(gameState.tutorialRun?.step?.id == "blue_shop.spend", "abrir Mejoras no basta")
        gameState.blueShopSpendChosen()
        #expect(gameState.tutorialRun?.step?.id == "blue_shop.caps")
    }

    @Test("abrir la pestaña Boosts no cumple el paso de otra lección")
    func spendingHalfOnlyAnswersTheShopLessons() async {
        let gameState = await makeGameState()
        only(.prestige, in: gameState)
        gameState.startTutorialRun(.lesson("prestige"), steps: GameState.TutorialLesson.prestige.steps)
        gameState.tutorialSignal(.lessonAction("prestige.open"))
        let before = gameState.tutorialRun?.step?.id
        gameState.blueShopSpendChosen()
        #expect(gameState.tutorialRun?.step?.id == before)
    }

    @Test("la suerte: nace con la puerta del azar abierta y la tienda de blue aprendida")
    func luckNeedsTheChanceGateOpen() async {
        let gameState = await makeGameState()
        only(.luck, in: gameState)
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.flagDefaults.removeObject(forKey: GameState.TutorialLesson.blueShop.defaultsKey)
        #expect(!gameState.luckMomentIsOn(chanceAllowed: true), "la tienda de blue todavía no se enseñó")
        gameState.markLessonDone(.blueShop)
        #expect(gameState.luckMomentIsOn(chanceAllowed: true))
        #expect(!gameState.luckMomentIsOn(chanceAllowed: false), "en una tienda restringida no se vende azar")
        #expect(!gameState.isEligible(.luck), "la puerta arranca cerrada hasta que StoreKit contesta")
        #expect(GameState.TutorialLesson.luck.steps.map(\.id) == ["luck.open", "luck.odds"])
    }

    @Test("los cosméticos: nacen con una pinta de blue que el saldo alcanza y la tienda aprendida")
    func cosmeticsNeedAnAffordableOutfit() async throws {
        let gameState = await makeGameState()
        only(.cosmetics, in: gameState)
        gameState.flagDefaults.removeObject(forKey: GameState.TutorialLesson.blueShop.defaultsKey)
        let cheapest = try #require(gameState.cheapestCosmeticPrice())
        gameState.player?.meta.blue = cheapest
        #expect(!gameState.isEligible(.cosmetics), "la tienda de blue todavía no se enseñó")
        gameState.markLessonDone(.blueShop)
        #expect(gameState.isEligible(.cosmetics))
        gameState.player?.meta.blue = cheapest - 1
        #expect(!gameState.isEligible(.cosmetics))
        gameState.player?.meta.blue = cheapest
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["cosmetics.open", "cosmetics.where"])
        #expect(gameState.tutorialRun?.steps.last?.target == .storeCosmetics)
    }

    @Test("lo más barato de la tienda no cuenta el azar con la puerta cerrada ni lo que el piso no abrió")
    func cheapestPriceSkipsWhatIsNotOnSale() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        func price(_ item: BlueShopCatalog.Item) -> Int? { item.price ?? item.levels.first?.price }
        let onSale = content.blueShop.items.filter { item in
            !item.isChance && item.unlockFloorId.map { content.floorTable.ordinal(of: $0) == 0 } ?? true
        }
        let hidden = content.blueShop.items.filter { !onSale.contains($0) }
        #expect(!hidden.isEmpty, "el catálogo tiene algo que hoy no se vende")
        #expect(gameState.cheapestBlueShopPrice() == onSale.compactMap(price).min())
    }

    // MARK: Lo que corre bajo el HUD

    @Test("el ×3 guardado: nace con uno comprado esperando, el de la vuelta o el del diario")
    func pendingTripleNeedsASavedMultiplier() async {
        let gameState = await makeGameState()
        only(.pendingTriple, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        gameState.player?.meta.engagement.shop.pendingDailyMultiplier = 3
        #expect(gameState.isEligible(.pendingTriple))
        gameState.player?.meta.engagement.shop.pendingDailyMultiplier = nil
        gameState.player?.meta.engagement.shop.pendingOfflineMultiplier = 3
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["pending_triple.explain"])
    }

    @Test("el auto-tap: nace con el auto-tap corriendo y señala su chip")
    func autoTapNeedsARunningAutoTap() async {
        let gameState = await makeGameState()
        only(.autoTap, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        gameState.grant(.autoTap(perSecond: 1, seconds: 60), source: "test")
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["auto_tap.explain"])
        #expect(gameState.tutorialRun?.step?.target == .autoTapChip)
    }

    @Test("las ofertas: nacen cuando la oferta ya se vio y quedó su chip, no mientras la hoja la presenta")
    func offersNeedAnOpenedChip() async {
        let gameState = await makeGameState()
        only(.offers, in: gameState)
        gameState.refreshProjections()
        #expect(!gameState.isEligible(.offers))
        gameState.debugOpenOffer(id: "renacer")
        #expect(!gameState.isEligible(.offers), "la hoja todavía no la mostró")
        gameState.markOfferPresented(id: "renacer")
        #expect(gameState.isEligible(.offers) == !gameState.visibleOffers().isEmpty)
        gameState.markLessonDone(.offers)
        #expect(GameState.TutorialLesson.offers.steps.map(\.id) == ["offers.chip"])
        #expect(GameState.TutorialLesson.offers.steps.first?.target == .offerChip)
    }

    @Test("los lugares extra: nacen con un nivel comprado")
    func extraSlotsNeedAPurchasedLevel() async {
        let gameState = await makeGameState()
        only(.extraSlots, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        gameState.player?.meta.engagement.shop.levels["extra_slots"] = 1
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["extra_slots.explain"])
    }

    // MARK: El registro

    @Test("las de la 2.0 no se dan por vistas al veterano, y las de la v1 sí")
    func declaredRelease() {
        let v2: [GameState.TutorialLesson] = [.quickHire, .staffedFloors, .prestigeGate, .characterSheet]
        for lesson in v2 { #expect(lesson.introducedIn == .v2, "\(lesson)") }
        let v1: [GameState.TutorialLesson] = [.passive, .upgrades, .orgChart, .elevator, .floorSwipe, .floorFull, .prestige]
        for lesson in v1 { #expect(lesson.introducedIn == .v1, "\(lesson)") }
    }

    @Test("las de T2 declaran su versión")
    func declaredReleaseT2() {
        for lesson in [GameState.TutorialLesson.boosts, .chests] { #expect(lesson.introducedIn == .v1, "\(lesson)") }
        let v2: [GameState.TutorialLesson] = [.hirePriceStep, .menuSwipe, .newTabs, .blueShop, .luck, .cosmetics,
                                               .pendingTriple, .autoTap, .offers, .extraSlots]
        for lesson in v2 { #expect(lesson.introducedIn == .v2, "\(lesson)") }
    }

    @Test("los huecos de T2 quedaron cubiertos por su lección, salvo el que no existe")
    func theT2GapsAreCovered() {
        let expected: [TutorialMechanic: GameState.TutorialLesson] = [
            .boosts: .boosts, .chests: .chests, .hirePriceStep: .hirePriceStep, .menuSwipe: .menuSwipe,
            .newTabs: .newTabs, .blueShopShelf: .blueShop, .luckOdds: .luck, .cosmetics: .cosmetics,
            .pendingTriple: .pendingTriple, .autoTap: .autoTap, .offers: .offers, .extraSlots: .extraSlots,
        ]
        for (mechanic, lesson) in expected {
            #expect(mechanic.coverage == .lesson(lesson), "\(mechanic)")
            #expect(!TutorialMechanic.knownGaps.contains(mechanic), "\(mechanic)")
        }
        #expect(TutorialMechanic.knownGaps == [.skinEffects])
        #expect(TutorialMechanic.gapReasons[.skinEffects]?.isEmpty == false)
    }

    @Test("cada lección declara su versión a mano, y ninguna conserva el paso heredado")
    func everyLessonIsExplicit() {
        for lesson in GameState.TutorialLesson.allCases {
            #expect(!lesson.steps.isEmpty, "\(lesson)")
            #expect(!lesson.steps.contains { $0.id.hasSuffix(".legacy") }, "\(lesson)")
        }
    }

    @Test("el orden: lo que se usa primero, se enseña primero")
    func order() {
        let all = GameState.TutorialLesson.allCases
        let index = { (lesson: GameState.TutorialLesson) in all.firstIndex(of: lesson)! }
        #expect(index(.quickHire) < index(.upgrades))
        #expect(index(.newTabs) < index(.skins))
        #expect(index(.newTabs) < index(.store))
        #expect(index(.newTabs) < index(.menuSwipe))
        #expect(index(.elevator) < index(.elevatorKeypad))
        #expect(index(.elevator) < index(.floorSwipe))
        #expect(index(.blueShop) < index(.luck))
        #expect(index(.blueShop) < index(.cosmetics))
        #expect(index(.sideRail) < index(.packages))
        #expect(index(.sideRail) < index(.mattress))
        #expect(index(.sideRail) < index(.wheel))
        #expect(index(.sideRail) < index(.mergeAllVideo))
    }

    @Test("cada lección está una sola vez y ninguna se perdió")
    func everyLessonIsListedOnce() {
        let all = GameState.TutorialLesson.allCases
        #expect(Set(all).count == all.count)
        #expect(all.count == 38)
    }

    @Test("las que dejaron el paso heredado conservan su señal, su ancla y su texto")
    func formerLegacyLessonsKeepTheirSignal() {
        typealias Lesson = GameState.TutorialLesson
        let expected: [(Lesson, TutorialSignal, TutorialTarget, String)] = [
            (.share, .lessonAction, .share, "tutorial.tip.share"),
            (.visitor, .lessonAction, .visitor, "tutorial.tip.visitor"),
            (.eventChip, .lessonAction, .eventChip, "tutorial.tip.event_chip"),
            (.album, .screenOpened(.menu), .menu, "tutorial.tip.album"),
            (.packages, .lessonAction, .sidePackages, "tutorial.tip.packages"),
            (.mattress, .lessonAction, .sideMattress, "tutorial.tip.mattress"),
            (.wheel, .lessonAction, .sideWheel, "tutorial.tip.wheel.rail"),
            (.sideRail, .lessonAction, .sideRail, "tutorial.tip.side_rail"),
            (.mergeAllVideo, .lessonAction, .sideBoost, "tutorial.tip.merge_all_video"),
            (.elevator, .lessonAction, .map, "tutorial.tip.elevator"),
            (.elevatorKeypad, .lessonAction, .map, "tutorial.tip.elevator.hold"),
            (.skins, .screenOpened(.skins), .skins, "tutorial.tip.skins"),
            (.achievements, .screenOpened(.menu), .menu, "tutorial.tip.achievements"),
            (.blueUpgrades, .screenOpened(.upgrades), .upgrades, "tutorial.tip.blue"),
            (.gifts, .screenOpened(.gifts), .gifts, "tutorial.tip.gifts"),
            (.store, .screenOpened(.store), .store, "tutorial.tip.store"),
        ]
        for (lesson, signal, target, textKey) in expected {
            #expect(lesson.steps.count == 1, "\(lesson)")
            let step = lesson.steps[0]
            #expect(step.signal == signal, "\(lesson)")
            #expect(step.target == target, "\(lesson)")
            #expect(step.textKey == textKey, "\(lesson)")
            #expect(step.surface == .board, "\(lesson)")
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
