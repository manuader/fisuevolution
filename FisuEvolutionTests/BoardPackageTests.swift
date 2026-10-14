import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("La caja se abre en el tablero (E14b B5, D2)")
@MainActor
struct BoardPackageTests {
    private func seenIntro(_ gameState: GameState) {
        gameState.player?.meta.engagement.packageIntroSeen = true
    }

    private func fillTheTower(_ gameState: GameState) throws {
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
    }

    private func packageArrivals(_ gameState: GameState) -> [BoardChange] {
        gameState.pendingBoardChanges.filter { $0.origin == .package }
    }

    // MARK: Las dos ramas del flag

    @Test("la primera vez la caja del tablero abre la pantalla de C28, sin gastar nada")
    func firstTimeOpensThePopup() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        #expect(!gameState.packageIntroSeen)
        #expect(gameState.boardPackageTapped() == .popup)
        #expect(gameState.packagePopup != nil)
        #expect(gameState.packagesWaiting == 2)
        #expect(packageArrivals(gameState).isEmpty)
    }

    @Test("abrir uno desde la pantalla la da por vista; cerrarla sin abrir, no")
    func openingFromThePopupMarksItSeen() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.boardPackageTapped()
        gameState.closePackagePopup()
        #expect(!gameState.packageIntroSeen, "sólo mirarla no cuenta")
        gameState.boardPackageTapped()
        gameState.openPackageFromPopup()
        #expect(gameState.packageIntroSeen)
        gameState.closePackagePopup()
        #expect(gameState.boardPackageTapped() == .openInPlace)
        #expect(gameState.packagePopup == nil)
    }

    @Test("«Abrir todos» también la da por vista")
    func openAllMarksItSeen() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.packageTapped()
        gameState.openAllPackagesFromPopup()
        #expect(gameState.packageIntroSeen)
    }

    @Test("desde la segunda, un toque: sin pop-up, el paquete se gasta al abrirse y el empleado llega")
    func secondTimeOpensInPlace() async throws {
        let gameState = await makeGameState()
        seenIntro(gameState)
        gameState.debugAddPackages(1)
        #expect(gameState.boardPackageTapped() == .openInPlace)
        #expect(gameState.packagePopup == nil)
        #expect(gameState.packagesWaiting == 1, "no se gasta hasta que la caja termina de abrirse")
        #expect(packageArrivals(gameState).isEmpty)
        let result = gameState.openPackageOnBoard()
        guard case let .opened(typeId, _) = result else {
            Issue.record("la caja se abrió y no salió nadie: \(result)")
            return
        }
        #expect(gameState.packagePopup == nil)
        #expect(gameState.packagesWaiting == 0)
        let arrival = try #require(packageArrivals(gameState).first)
        #expect(arrival.kind == .arrival(typeId: typeId))
    }

    @Test("desde la columna (y Regalos) sigue abriendo la pantalla aunque ya se haya visto (D5)")
    func theRailAlwaysOpensThePopup() async {
        let gameState = await makeGameState()
        seenIntro(gameState)
        gameState.debugAddPackages(1)
        #expect(gameState.packageTapped())
        #expect(gameState.packagePopup != nil)
    }

    @Test("sin lugar la caja no se abre y avisa arriba (C28 punto 4)")
    func fullDoesNotOpen() async throws {
        let gameState = await makeGameState()
        seenIntro(gameState)
        try fillTheTower(gameState)
        gameState.debugAddPackages(1)
        #expect(gameState.boardPackageTapped() == .full)
        #expect(gameState.packagePopup == nil)
        #expect(gameState.towerNotice?.kind == .packageFull)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("si se llenó todo mientras se abría, no se gasta y avisa")
    func fullWhileOpening() async throws {
        let gameState = await makeGameState()
        seenIntro(gameState)
        gameState.debugAddPackages(1)
        #expect(gameState.boardPackageTapped() == .openInPlace)
        try fillTheTower(gameState)
        #expect(gameState.openPackageOnBoard() == .full)
        #expect(gameState.packagesWaiting == 1)
        #expect(gameState.towerNotice?.kind == .packageFull)
        #expect(packageArrivals(gameState).isEmpty)
    }

    // MARK: En la escena

    private func pickups() async -> (GameState, PickupController) {
        let gameState = await makeGameState()
        // Política quieta: los clips de apertura terminan en el acto y la caja se abre en el mismo toque.
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let controller = PickupController(gameState: gameState, pool: pool)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    @Test("la caja del tablero, ya vista: se abre en el lugar, se va, y deja dónde sale el empleado")
    func theBoxOpensOnTheBoard() async throws {
        let (gameState, controller) = await pickups()
        seenIntro(gameState)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        let spot = box.position
        #expect(controller.handleTap(at: spot))
        #expect(gameState.packagePopup == nil)
        #expect(gameState.packagesWaiting == 0)
        #expect(controller.boxes.isEmpty)
        let arrival = try #require(packageArrivals(gameState).first)
        guard case let .arrival(typeId) = arrival.kind else {
            Issue.record("el paquete no encoló una llegada")
            return
        }
        #expect(controller.takeBoxExit(typeId: typeId) == spot)
        #expect(controller.takeBoxExit(typeId: typeId) == nil, "se usa una sola vez")
    }

    @Test("la caja del tablero, sin ver: abre la pantalla y la caja se queda")
    func theBoxOpensThePopupFirst() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        #expect(controller.handleTap(at: box.position))
        #expect(gameState.packagePopup != nil)
        #expect(controller.boxes.count == 1)
        #expect(!box.isOpening)
    }

    @Test("el marcador de la caja: dónde tocarla, y vacío sin caja")
    func theMarker() async throws {
        let (gameState, controller) = await pickups()
        controller.update(delta: 1, reduceMotion: true)
        #expect(gameState.boardPackageMarker.isEmpty)
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let parts = gameState.boardPackageMarker.split(separator: ",").compactMap { Double($0) }
        #expect(parts.count == 2)
        #expect(parts.allSatisfy { (0...1).contains($0) })
    }
}
