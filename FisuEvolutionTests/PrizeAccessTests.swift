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

    @Test("el colchón: el popup, el video, lo que salió y otro más")
    func theMattressFlow() async throws {
        let gameState = await makeGameState()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup == nil, "sin colchón no hay popup")
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup?.outcome == nil)
        gameState.mattressVideoWatched()
        let first = try #require(gameState.mattressPopup?.outcome)
        #expect(first.extraOpensLeft == 1)
        #expect(!gameState.prizeAccess.mattressReady)
        gameState.extraMattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome?.extraOpensLeft == 0)
        gameState.closeMattressPopup()
        #expect(gameState.mattressPopup == nil)
    }

    @Test("un video del colchón que llega dos veces abre uno solo, aunque haya otro esperando")
    func theMattressVideoPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        gameState.mattressVideoWatched()
        let first = try #require(gameState.mattressPopup?.outcome)
        gameState.debugSpawnMattress()
        gameState.mattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome == first, "el resultado a la vista no se pisa")
        #expect(gameState.mattressWaiting, "el colchón nuevo sigue sin abrir")
    }

    @Test("el segundo video del colchón paga una vez")
    func theExtraVideoPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        gameState.mattressVideoWatched()
        gameState.extraMattressVideoWatched()
        let second = try #require(gameState.mattressPopup?.outcome)
        let oro = gameState.player?.meta.oro
        let coins = gameState.player?.run.coins
        gameState.extraMattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome == second)
        #expect(gameState.player?.meta.oro == oro)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("sin popup, un video del colchón no abre nada")
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
    @Test("dos toques seguidos al giro por ORO cobran uno solo")
    func oroSpinChargesOnce() async {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 100
        var latch = PurchaseLatch()
        let before = gameState.wheelAvailability(storefrontAllows: true).oroLeft
        #expect(gameState.beginWheelSpin(.oro, latch: &latch, storefrontAllows: true) != nil)
        #expect(gameState.beginWheelSpin(.oro, latch: &latch, storefrontAllows: true) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: true).oroLeft == before - 1)
    }

    @Test("un giro que no sale suelta el cerrojo")
    func aFailedSpinReleasesTheLatch() async {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 0
        var latch = PurchaseLatch()
        #expect(gameState.beginWheelSpin(.oro, latch: &latch, storefrontAllows: true) == nil)
        #expect(!latch.isLocked)
    }
}
