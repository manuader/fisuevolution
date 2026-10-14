import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El director de las lecciones contextuales (`GameState+TutorialTips`). La
/// regla que se pinea acá es la del dueño: **ninguna lección manda a una
/// pantalla donde en ese momento no hay nada que hacer** — ni al nacer, ni
/// después de esperar turno.
///
/// ⚠️ Las banderas de lecciones de cada caso viven en su propio dominio
/// (`UserDefaults.isolatedForTest()`): una lección "dada" por el test anterior
/// no cambia qué nace en éste, y nada le queda al host. Y el director arranca
/// APAGADO bajo XCTest (mismo criterio que el gate del bootstrap): cada test lo
/// prende explícito.
@Suite("Lecciones contextuales del tutorial", .serialized)
@MainActor
struct TutorialTipsTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tips-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        // Una partida nueva ya tiene un giro de la ruleta listo: sin esto las
        // lecciones de la columna le ganan el turno a todas las demás. Con plata, el atajo
        // (primero del orden) le gana a Mejoras: queda dado para que los tests midan lo suyo.
        gameState.markLessonDone(.sideRail)
        gameState.markLessonDone(.wheel)
        gameState.markLessonDone(.quickHire)
        return gameState
    }

    @Test("sin señal no nace ninguna lección; con la señal, nace la primera del orden")
    func lessonsWaitForTheirSignal() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "partida nueva sin plata: no hay nada que hacer en ninguna pantalla")

        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades,
                "con plata, la mejora es pagable y la lección de Mejoras es la primera del orden")
        #expect(gameState.showing == .tutorialTip, "y viaja por la cola como cualquier celebración")
    }

    @Test("con la fase obligatoria viva no nace ninguna lección")
    func noLessonsDuringThePhase() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "las lecciones arrancan recién cuando la fase termina")
        gameState.finishTutorialCore()
        // El cofre de bienvenida toma el turno al cerrar la fase; la lección
        // nace con la cola libre (director v2).
        gameState.dismissChestReward()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)
    }

    @Test("una lección dada no vuelve, y el turno la marca al cerrarse")
    func aLessonPlaysOnce() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.showing == .tutorialTip)

        gameState.finishUpgradesLessonForTest()
        #expect(gameState.showing != .tutorialTip)
        #expect(gameState.isLessonDone(.upgrades), "cumplirla la deja dada: no vuelve nunca")

        gameState.advanceTutorial(delta: TutorialPacing.gapBetweenLessons)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson != .upgrades, "la que sigue puede nacer, la dada no")
    }

    @Test("la lección de la placa nace con el tercer piso, no antes")
    func theKeypadLessonWaitsForTheThirdFloor() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .elevatorKeypad {
            gameState.markLessonDone(lesson)
        }
        gameState.debugUnlockFloors(throughTier: 5)
        gameState.refreshProjections()
        #expect(gameState.unlockedFloorsCount == 2)
        #expect(gameState.tutorialTip == nil, "con dos pisos todavía no hay placa que enseñar")

        for tier in 6...12 where gameState.unlockedFloorsCount < 3 {
            gameState.debugUnlockFloors(throughTier: tier)
        }
        gameState.refreshProjections()
        #expect(gameState.unlockedFloorsCount >= 3)
        #expect(gameState.tutorialTip?.lesson == .elevatorKeypad)
        #expect(GameState.TutorialLesson.elevatorKeypad.steps.first?.textKey == "tutorial.tip.elevator.hold")
    }

    @Test("desplegar la placa cumple la lección aunque no se haya visto")
    func openingTheKeypadCompletesTheLesson() async {
        let gameState = await makeGameState()
        gameState.elevatorKeypadOpened()
        #expect(gameState.isLessonDone(.elevatorKeypad))
    }

    @Test("desplegar la placa con la lección en pantalla la retira")
    func openingTheKeypadDismissesTheShownTip() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .elevatorKeypad {
            gameState.markLessonDone(lesson)
        }
        for tier in 5...12 where gameState.unlockedFloorsCount < 3 {
            gameState.debugUnlockFloors(throughTier: tier)
        }
        gameState.refreshProjections()
        #expect(gameState.showing == .tutorialTip)
        gameState.elevatorKeypadOpened()
        #expect(gameState.showing != .tutorialTip)
    }

    @Test("hacer lo que señala cumple la lección sin esperar el piso de skip")
    func openingTheDestinationCompletesTheLesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades)

        gameState.finishUpgradesLessonForTest()
        #expect(gameState.showing != .tutorialTip, "hacer lo que señala es la mejor salida")
        #expect(gameState.isLessonDone(.upgrades))
    }

    /// Una lección esperando turno, armada a mano: el director v2 sólo hace nacer lecciones
    /// con la cola libre, así que la espera sale de una cola restringida.
    private func pendingUpgradesLesson() async -> GameState {
        let gameState = await makeGameState()
        gameState.tutorialLessonsAutorun = false
        gameState.celebrations.restrict(to: [.boardCelebration])
        gameState.debugGrantCoins()
        gameState.startTutorialRun(.lesson("upgrades"), steps: GameState.TutorialLesson.upgrades.steps)
        #expect(gameState.tutorialRun != nil)
        #expect(gameState.showing != .tutorialTip, "la cola restringida la deja esperando turno")
        return gameState
    }

    @Test("la condición que muere esperando turno la retira sin quemarla")
    func aStaleTipRetiresWithoutBurningTheLesson() async {
        let gameState = await pendingUpgradesLesson()
        gameState.player?.run.coins = 0
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "la regla principal vale hasta el último frame")
        #expect(!gameState.celebrations.contains(.tutorialTip), "y suelta su lugar en la fila")
        #expect(!gameState.isLessonDone(.upgrades),
                "no se quema: nunca estuvo en pantalla")
    }

    @Test("la señal de una lección que espera turno no la cumple ni la quema")
    func aPendingTipIsNotBurnedByItsSignal() async {
        let gameState = await pendingUpgradesLesson()
        gameState.tutorialTipHandled(opening: .upgrades)
        #expect(gameState.tutorialRun != nil, "avanzar espera al turno")
        #expect(!gameState.isLessonDone(.upgrades),
                "no se marca dada sin haberse visto")
    }

    @Test("el primer evento corriendo enseña su chip, y abrirlo la cumple")
    func theFirstEventTeachesItsChip() async throws {
        let gameState = await makeGameState()
        gameState.markLessonDone(.visitor)
        gameState.debugStartEvent(id: "devaluacion")
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .eventChip)
        gameState.openEventPopup(id: "devaluacion")
        #expect(gameState.showing != .tutorialTip)
        #expect(gameState.isLessonDone(.eventChip))
    }

    @Test("con una hoja tapando el tablero no nace nada")
    func noLessonUnderAnOpenSheet() async {
        let gameState = await makeGameState()
        gameState.uiCoversBoard = true
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "el coach señala controles que están DEBAJO de la hoja")

        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .upgrades, "al cerrarse, el próximo refresh la agarra")
    }

    /// La lección de Pintas y su fuente nueva. Desde que las 41 pintas de piso
    /// salen **sólo** de cofres, la vía vieja —la skin de milestone del piso 2—
    /// no existe más, y lo primero que el jugador puede ponerse es la pinta del
    /// **cofre de bienvenida**, que cae al cerrar la fase obligatoria.
    ///
    /// Por eso la señal sigue siendo `!ownedSkins.isEmpty`: esa proyección
    /// publica `allOwnedSkins` —tienda ∪ milestone—, que es literalmente "tiene
    /// una pinta que ponerse", que es la regla principal, y es donde el cofre
    /// acredita. Una señal atada a `welcomeChestGiven` mandaría a Pintas por
    /// haber DADO el cofre y no por tener la pinta, y de paso se olvidaría de
    /// la vía de la tienda.
    @Test("la lección de Pintas espera al cofre de bienvenida, que es lo que le da algo que hacer")
    func theSkinsLessonWaitsForTheWelcomeChest() async {
        let gameState = await makeGameState()
        // Con la bandera del cofre se abren pestañas: el deslizar y el «¡Nuevo!» son de otras lecciones.
        gameState.markLessonDone(.menuSwipe)
        gameState.markLessonDone(.newTabs)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil,
                "partida nueva sin una sola pinta: en Pintas no hay nada que ponerse")

        // La bandera del cofre NO es la señal: dice que el cofre se dio, no que
        // haya una pinta puesta en la bolsa.
        gameState.player?.meta.welcomeChestGiven = true
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil,
                "la bandera sola manda a una pantalla donde todavía no hay nada que ponerse")
        gameState.player?.meta.welcomeChestGiven = false

        gameState.beginTutorialPhase()
        gameState.finishTutorialCore()
        gameState.dismissChestReward()
        gameState.refreshProjections()

        #expect(gameState.tutorialTip?.lesson == .skins,
                "con la pinta del cofre acreditada, Pintas por fin tiene algo que hacer")
    }

    /// La lección del primer blue (dueño, 2026-08-28: "que te lleve a la
    /// pestaña de mejoras permanentes y te haga elegir"). La señal es una
    /// permanente de blue PAGABLE — no el blue pelado: si el primer premio no
    /// alcanza para la línea más barata, mandar a Mejoras violaría la regla
    /// principal (no habría nada que hacer).
    @Test("el primer blue con una permanente pagable dispara su lección")
    func theFirstBlueLessonFiresWhenAPermanentIsAffordable() async throws {
        let gameState = await makeGameState()
        // Las lecciones anteriores del orden ya quedaron atrás en una partida
        // real (la de Mejoras salió con la primera plata): dadas.
        for lesson in [GameState.TutorialLesson.upgrades, .elevator, .quickHire, .skins, .achievements] {
            gameState.markLessonDone(lesson)
        }
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "sin blue no hay nada que canjear en las permanentes")

        // El primer blue, como lo paga un logro: justo lo que sale la línea
        // más barata.
        let lines = try #require(gameState.content?.upgradesConfig.upgrades)
        let cheapest = try #require(
            lines.filter { $0.currency == .blue }
                .map { Int(gameState.upgradeCost(of: $0).rounded(.up)) }
                .min()
        )
        gameState.player?.meta.blue += cheapest
        gameState.refreshProjections()
        #expect(gameState.canAffordAnyBlueUpgrade)
        #expect(gameState.tutorialTip?.lesson == .blueUpgrades,
                "el primer blue pagable tiene que llevar a las permanentes")
    }

    @Test("con el piso lleno y plata la lección del atajo no nace: no hay nada que comprar")
    func theQuickHireLessonNeedsARealPurchase() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        let capacity = gameState.floorOccupancy(ordinal: 0).capacity
        for _ in gameState.floorOccupancy(ordinal: 0).occupied..<capacity {
            gameState.hireCharacter(typeId: "homeless")
        }
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        let offer = try #require(gameState.quickHireOffer)
        #expect(offer.affordable && !offer.fits)
        for lesson in [GameState.TutorialLesson.upgrades, .elevator, .skins, .achievements] {
            gameState.markLessonDone(lesson)
        }
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson != .quickHire, "enseñaría un botón que no compra")
    }

    @Test("el badge de logros: la señal nace con el cobrable y muere al cobrarlo")
    func claimableSignalTracksTheSets() async throws {
        let gameState = await makeGameState()
        let before = gameState.hasClaimableAchievements
        gameState.debugSeedAchievements()
        gameState.refreshProjections()
        #expect(gameState.hasClaimableAchievements, "tres logros conseguidos y sin cobrar: hay puntito")

        let player = try #require(gameState.player)
        for id in player.meta.unlockedAchievements.subtracting(player.meta.claimedAchievements) {
            gameState.claimAchievement(id: id)
        }
        #expect(!gameState.hasClaimableAchievements, "cobrado el último, el puntito muere")
        _ = before
    }

    @Test("el primer especial enseña el Álbum, y abrir la Oficina la cumple")
    func theFirstSpecialTeachesTheAlbum() async throws {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .album { gameState.markLessonDone(lesson) }
        gameState.player?.meta.ownedSpecials.append("sp_cryptobro")
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .album)
        gameState.tutorialTipHandled(opening: .menu)
        #expect(gameState.isLessonDone(.album))
    }

    @Test("la primera visita enseña el chip, y abrir su popup la cumple")
    func theFirstVisitorTeachesTheChip() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 2)
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .visitor)
        #expect(gameState.showing == .tutorialTip)
        gameState.openVisitorPopup()
        #expect(gameState.visitorPopup != nil)
        #expect(gameState.showing != .tutorialTip)
        #expect(gameState.isLessonDone(.visitor))
    }

    @Test("un paquete esperando enseña a tocarlo, y tocarlo cumple la lección")
    func thePackagesLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .packages {
            gameState.markLessonDone(lesson)
        }
        gameState.debugAddPackages(1)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .packages)
        #expect(gameState.showing == .tutorialTip)
        #expect(GameState.TutorialLesson.packages.anchorTarget == .sidePackages)
        _ = gameState.packageTapped()
        #expect(gameState.showing != .tutorialTip)
        #expect(gameState.isLessonDone(.packages))
    }

    @Test("un colchón esperando enseña a abrirlo, y tocarlo la cumple")
    func theMattressLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .mattress {
            gameState.markLessonDone(lesson)
        }
        gameState.debugSpawnMattress()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .mattress)
        #expect(GameState.TutorialLesson.mattress.anchorTarget == .sideMattress)
        gameState.mattressTapped()
        #expect(gameState.showing != .tutorialTip)
        #expect(gameState.isLessonDone(.mattress))
    }

    @Test("la ruleta se enseña en la columna, no en Regalos, y tocarla la cumple")
    func theWheelLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .wheel {
            gameState.markLessonDone(lesson)
        }
        gameState.flagDefaults.removeObject(forKey: GameState.TutorialLesson.wheel.defaultsKey)
        gameState.debugAddWheelSpins(1)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .wheel)
        #expect(GameState.TutorialLesson.wheel.anchorTarget == .sideWheel)
        #expect(GameState.TutorialLesson.wheel.destinationScreen == nil)
        _ = gameState.sideRailTapped(.wheel)
        #expect(gameState.showing != .tutorialTip)
    }

    @Test("con algo listo en la columna, la primera lección es abrirla, y abrirla la cumple")
    func openTheRailFirst() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .sideRail && lesson != .packages {
            gameState.markLessonDone(lesson)
        }
        gameState.flagDefaults.removeObject(forKey: GameState.TutorialLesson.sideRail.defaultsKey)
        gameState.debugAddPackages(1)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .sideRail, "la de los paquetes espera a la de abrir la columna")
        #expect(GameState.TutorialLesson.sideRail.anchorTarget == .sideRail)
        gameState.sideRailOpened()
        #expect(gameState.showing != .tutorialTip)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "la siguiente espera los 20 s del ritmo")
        gameState.advanceTutorial(delta: TutorialPacing.gapBetweenLessons)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .packages, "abierta, ahora sí el botón de los paquetes")
    }

    @Test("sin la lección de abrirla, la de la ruleta no nace: primero se enseña a abrir la columna")
    func buttonLessonsWaitForTheRailLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .sideRail {
            gameState.markLessonDone(lesson)
        }
        gameState.flagDefaults.removeObject(forKey: GameState.TutorialLesson.sideRail.defaultsKey)
        gameState.debugAddWheelSpins(1)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .sideRail)
    }

    @Test("Fusionar todo por video se enseña con pares en el piso, señalando su botón")
    func mergeAllVideoLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .mergeAllVideo {
            gameState.markLessonDone(lesson)
        }
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .mergeAllVideo)
        #expect(GameState.TutorialLesson.mergeAllVideo.anchorTarget == .sideBoost)
        #expect(GameState.TutorialLesson.mergeAllVideo.destinationScreen == nil)
        _ = gameState.sideRailTapped(.boost)
        #expect(gameState.showing != .tutorialTip, "tocar el botón la cumple")
    }

    @Test("una partida nueva no enseña los premios: no hay nada que hacer")
    func prizeLessonsNeedSomethingToDo() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where ![.packages, .mattress].contains(lesson) {
            gameState.markLessonDone(lesson)
        }
        gameState.markLessonDone(.wheel)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil)
    }
}
