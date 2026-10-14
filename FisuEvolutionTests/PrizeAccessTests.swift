import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los accesos al Paquete, el Colchón y la Ruleta")
@MainActor
struct PrizeAccessTests {
    @Test("publica cuántos paquetes, si están trabados, si hay colchón y cuántos giros sin pagar")
    func publishes() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.prizeAccess == PrizeAccess(packagesWaiting: 0, packagesBlocked: false, mattressReady: false, wheelSpinsReady: 6))
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress()
        gameState.debugAddWheelSpins(1)
        gameState.refreshProjections()
        #expect(gameState.prizeAccess == PrizeAccess(packagesWaiting: 2, packagesBlocked: false, mattressReady: true, wheelSpinsReady: 7))
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshProjections()
        #expect(!gameState.prizeAccess.mattressReady, "ya no está en la columna")
        #expect(gameState.prizeAccess.mattressOnBoard)
    }

    @Test("tocar el paquete abre su pantalla sin gastarlo")
    func tappingAPackage() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        #expect(gameState.packageTapped())
        #expect(gameState.packagePopup?.arrivals.isEmpty == true)
        #expect(gameState.prizeAccess.packagesWaiting == 1)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("sin paquetes, tocar no abre nada")
    func tappingWithoutPackages() async {
        let gameState = await makeGameState()
        #expect(!gameState.packageTapped())
        #expect(gameState.packagePopup == nil)
    }

    @Test("«¡Abrir!» resta uno, encola la llegada en el piso que se anuncia y el doble toque no trae a otro")
    func openingFromTheScreen() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.packageTapped()
        gameState.openPackageFromPopup()
        let arrival = try #require(gameState.packagePopup?.arrivals.first)
        #expect(gameState.prizeAccess.packagesWaiting == 1)
        let change = try #require(gameState.pendingBoardChanges.last)
        #expect(change.kind == .arrival(typeId: arrival.typeId))
        let ordinal = try #require(gameState.floorOrdinal(of: change))
        #expect(gameState.content?.floorTable[ordinal].id == arrival.floorId)
        gameState.openPackageFromPopup()
        #expect(gameState.packagesWaiting == 1, "ya salió uno: otro toque a «Abrir» no gasta más")
        #expect(gameState.pendingBoardChanges.filter { $0.origin == .package }.count == 1)
    }

    @Test("«Abrir otro» vuelve a la caja cerrada y «Abrir todos» abre los que entran")
    func openAnotherAndOpenAll() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.packageTapped()
        gameState.openPackageFromPopup()
        gameState.packagePopupOpenAnother()
        #expect(gameState.packagePopup?.arrivals.isEmpty == true)
        gameState.debugAddPackages(1)
        gameState.openAllPackagesFromPopup()
        #expect(gameState.packagePopup?.arrivals.count == 2)
        #expect(gameState.packagesWaiting == 0)
        #expect(gameState.pendingBoardChanges.filter { $0.origin == .package }.count == 3)
        gameState.closePackagePopup()
        #expect(gameState.packagePopup == nil)
    }

    @Test("con la pantalla del paquete abierta, el tablero espera y nada más se abre encima")
    func theScreenKeepsTheBoardBusy() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        gameState.packageTapped()
        #expect(gameState.isBoardBusy)
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup == nil)
        #expect(!gameState.packageTapped(), "no se apila sobre sí misma")
    }

    @Test("el colchón (E14b B6): la columna pide el video, cae al tablero, se abre ahí y sale el premio, y otro más")
    func theMattressFlow() async throws {
        let gameState = await makeGameState()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup == nil, "sin colchón no hay popup")
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup?.outcome == nil)
        #expect(!gameState.boardMattressTapped(), "todavía no está en el tablero")
        let before = try #require(gameState.player)
        gameState.mattressVideoWatched()
        #expect(gameState.mattressPopup == nil, "el video cierra el popup y el colchón cae")
        #expect(gameState.mattressOnBoard)
        #expect(gameState.prizeAccess.mattressOnBoard && !gameState.prizeAccess.mattressReady)
        #expect(gameState.player?.run.coins == before.run.coins && gameState.player?.meta.blue == before.meta.blue,
                "pagar el video no acredita nada: el premio sale al abrirlo")
        #expect(gameState.boardMattressTapped())
        let first = try #require(gameState.openMattressOnBoard())
        #expect(gameState.mattressPopup?.outcome == first)
        #expect(gameState.mattressPopup?.openedOnBoard == true, "el premio se ve directo")
        #expect(first.extraOpensLeft == 1)
        #expect(!gameState.mattressInPlay)
        gameState.extraMattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome?.extraOpensLeft == 0)
        #expect(gameState.mattressPopup?.openedOnBoard == false, "el «otro colchón» se abre tocándolo en el popup")
        gameState.closeMattressPopup()
        #expect(gameState.mattressPopup == nil)
    }

    @Test("un video del colchón que llega dos veces lo paga una sola vez")
    func theMattressVideoPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        gameState.mattressVideoWatched()
        #expect(gameState.mattressOnBoard)
        let after = gameState.player
        gameState.mattressVideoWatched()
        #expect(gameState.player == after)
        #expect(gameState.mattressPopup == nil)
    }

    @Test("el de regalo está en el tablero: la columna no lo abre y el tablero sí, una vez")
    func theGiftOpensOnTheBoardOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.refreshProjections()
        #expect(gameState.sideRailTapped(.mattress) == .refused)
        #expect(gameState.mattressPopup == nil)
        _ = try #require(gameState.openMattressOnBoard())
        let after = gameState.player
        gameState.closeMattressPopup()
        #expect(gameState.openMattressOnBoard() == nil, "abierto, no paga otra vez")
        #expect(gameState.player == after)
    }

    @Test("con otro popup arriba, el colchón del tablero no se abre ni gasta")
    func theBoardMattressWaitsForACalmScreen() async {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.openWheel()
        #expect(!gameState.boardMattressTapped())
        #expect(gameState.openMattressOnBoard() == nil)
        #expect(gameState.mattressOnBoard)
    }

    @Test("el segundo video del colchón paga una vez")
    func theExtraVideoPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.openMattressOnBoard()
        gameState.extraMattressVideoWatched()
        let second = try #require(gameState.mattressPopup?.outcome)
        let blue = gameState.player?.meta.blue
        let coins = gameState.player?.run.coins
        gameState.extraMattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome == second)
        #expect(gameState.player?.meta.blue == blue)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("sin popup, un video del colchón no lo paga")
    func noPopupNoMattressOpen() async {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        gameState.mattressVideoWatched()
        #expect(gameState.mattressWaiting)
        #expect(gameState.mattressPopup == nil)
    }

    @Test("el giro que regala un visitante abre la ruleta cuando su popup se va; los demás, no")
    func theHostOpensTheWheel() async {
        let gameState = await makeGameState()
        gameState.grant(.wheelSpin(1), source: "treasure.test")
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet == nil)
        gameState.grant(.wheelSpin(1), source: "visit.conductor_ruleta")
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet == nil, "un giro de visita sin popup abierto (un reto) no abre nada")
        gameState.visitorPopup = VisitorPopup(id: UUID())
        gameState.grant(.wheelSpin(1), source: "visit.conductor_ruleta")
        gameState.visitorPopup = nil
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet != nil)
        gameState.closeWheel()
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet == nil, "se abre una vez por giro regalado")
    }

    @Test("la ruleta y el colchón no se pisan")
    func oneSheetAtATime() async {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        gameState.openWheel()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup == nil)
        gameState.closeWheel()
        gameState.mattressTapped()
        gameState.openWheel()
        #expect(gameState.wheelSheet == nil)
    }

    @Test("con el popup del colchón o la ruleta abiertos, el tablero está ocupado")
    func sheetsBusyTheBoard() async {
        let gameState = await makeGameState()
        let calm = gameState.isBoardBusy
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        #expect(gameState.isBoardBusy)
        gameState.closeMattressPopup()
        #expect(gameState.isBoardBusy == calm)
        gameState.openWheel()
        #expect(gameState.isBoardBusy)
        gameState.closeWheel()
        #expect(gameState.isBoardBusy == calm)
    }

    @Test("si algo más tapa la pantalla, la ruleta no se abre: el giro queda para Regalos")
    func theWheelWaitsForACalmBoard() async {
        let gameState = await makeGameState()
        gameState.uiCoversBoard = true
        gameState.openWheel()
        #expect(gameState.wheelSheet == nil)
        gameState.uiCoversBoard = false
        gameState.openWheel()
        #expect(gameState.wheelSheet != nil)
    }

    @Test("con dos paquetes y un solo lugar, el segundo toque dice LLENO y no encola otra llegada")
    func queuedArrivalsTakeTheRoom() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity - 1]
        gameState.reconcileTower()
        gameState.debugAddPackages(2)
        gameState.packageTapped()
        gameState.openPackageFromPopup()
        #expect(gameState.packagePopup?.arrivals.count == 1)
        #expect(gameState.openPackage() == .full)
        #expect(gameState.pendingBoardChanges.filter { $0.origin == .package }.count == 1)
        #expect(gameState.prizeAccess.packagesWaiting == 1)
        #expect(gameState.prizeAccess.packagesBlocked)
    }
}

@Suite("El cerrojo de la ruleta")
@MainActor
struct WheelSpinLatchTests {
    @Test("dos toques seguidos al giro por blue cobran uno solo")
    func blueSpinChargesOnce() async {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = 100
        var latch = PurchaseLatch()
        let before = gameState.wheelAvailability(storefrontAllows: true).blueLeft
        #expect(gameState.beginWheelSpin(.blue, latch: &latch, storefrontAllows: true) != nil)
        #expect(gameState.beginWheelSpin(.blue, latch: &latch, storefrontAllows: true) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: true).blueLeft == before - 1)
    }

    @Test("con un video en curso no gira ni el regalado ni el de blue; el que paga ese video, sí")
    func aVideoInFlightBlocksTheOtherSpins() {
        #expect(!WheelSpinGate.allows(.bonus, spinning: false, videoBusy: true))
        #expect(!WheelSpinGate.allows(.blue, spinning: false, videoBusy: true))
        #expect(WheelSpinGate.allows(.video, spinning: false, videoBusy: true))
    }

    @Test("sin video en curso giran todos; con la rueda girando, ninguno")
    func theGateOnlyClosesWhenItMust() {
        for source in WheelSpinSource.allCases {
            #expect(WheelSpinGate.allows(source, spinning: false, videoBusy: false))
            #expect(!WheelSpinGate.allows(source, spinning: true, videoBusy: false))
            #expect(!WheelSpinGate.allows(source, spinning: true, videoBusy: true))
        }
    }

    @Test("un giro que no sale suelta el cerrojo")
    func aFailedSpinReleasesTheLatch() async {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = 0
        var latch = PurchaseLatch()
        #expect(gameState.beginWheelSpin(.blue, latch: &latch, storefrontAllows: true) == nil)
        #expect(!latch.isLocked)
    }
}
