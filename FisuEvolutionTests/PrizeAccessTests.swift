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

    @Test("tocar el paquete lo abre y el acceso se actualiza en el acto")
    func tappingAPackage() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        guard case .opened = gameState.packageTapped() else {
            Issue.record("el paquete no se abrió")
            return
        }
        #expect(gameState.prizeAccess.packagesWaiting == 0)
    }

    @Test("el doble toque sobre un único paquete trae a uno solo")
    func doubleTapOnAPackage() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        gameState.packageTapped()
        #expect(gameState.packageTapped() == .noneWaiting)
        #expect(gameState.pendingBoardChanges.filter { $0.origin == .package }.count == 1)
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
}
