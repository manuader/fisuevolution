import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Qué hace un toque a un botón de la columna, y el cerrojo de los dos videos
/// (tocan plata: un video mirado una sola vez paga una sola vez).
@Suite("Los toques de la columna", .serialized)
@MainActor
struct SideRailTapTests {
    private func gameStateWithPairs() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.refreshProjections()
        return gameState
    }

    private func queuedCount(_ gameState: GameState) -> Int {
        gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1)
    }

    // MARK: Los toques

    @Test("la ruleta abre su hoja; con el tablero ocupado, el botón tiembla")
    func wheel() async {
        let gameState = await makeGameState()
        #expect(gameState.sideRailTapped(.wheel) == .acted)
        #expect(gameState.wheelSheet != nil)
        gameState.closeWheel()
        gameState.mattressPopup = MattressPopup()
        #expect(gameState.sideRailTapped(.wheel) == .refused)
    }

    @Test("el colchón abre su popup sólo si hay uno esperando")
    func mattress() async {
        let gameState = await makeGameState()
        #expect(gameState.sideRailTapped(.mattress) == .refused)
        #expect(gameState.mattressPopup == nil)
        gameState.debugSpawnMattress()
        #expect(gameState.sideRailTapped(.mattress) == .acted)
        #expect(gameState.mattressPopup != nil)
    }

    @Test("los paquetes: con alguno esperando se abre uno; con el buzón vacío ofrece la lluvia")
    func packages() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.sideRailTapped(.packages) == .offer)
        gameState.debugAddPackages(1)
        #expect(gameState.sideRailTapped(.packages) == .acted)
        #expect(gameState.packagesWaiting == 0)
        #expect(gameState.pendingBoardChanges.filter { $0.origin == .package }.count == 1)
    }

    @Test("sin lugar para ninguno, el paquete se queda y el botón tiembla")
    func packagesFull() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(1)
        #expect(gameState.packagesBlocked)
        #expect(gameState.sideRailTapped(.packages) == .refused)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("los paquetes sin nada que abrir y la lluvia agotada: tiembla")
    func packageRainUnavailable() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(0)
        gameState.player?.meta.rewardedActivations[GameState.packageRainVideoKey] = Date().timeIntervalSince1970
        gameState.refreshProjections()
        #expect(gameState.sideRailTapped(.packages) == .refused)
    }

    @Test("Fusionar todo ofrece el video con pares y el tablero libre")
    func boostOffersTheVideo() async {
        let gameState = await gameStateWithPairs()
        #expect(gameState.sideRailTapped(.boost) == .offer)
    }

    @Test("Fusionar todo: sin pares o con una hoja encima el botón tiembla, y lo decide el tablero de AHORA")
    func boostIsGatedAtTapTime() async {
        let gameState = await gameStateWithPairs()
        gameState.mattressPopup = MattressPopup()
        #expect(gameState.sideRail.status(of: .boost) == .ready(count: nil), "la proyección todavía lo ofrece")
        #expect(gameState.sideRailTapped(.boost) == .refused)
        gameState.mattressPopup = nil
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        #expect(gameState.sideRailTapped(.boost) == .refused, "los pares se releen en vivo")
    }

    @Test("la lluvia se ofrece al tocar Paquetes sin paquetes, y con una hoja encima no")
    func rainIsGatedAtTapTime() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        gameState.mattressPopup = MattressPopup()
        #expect(gameState.sideRailTapped(.packages) == .refused)
    }

    @Test("ofrecer el video no tapa el tablero: no prende ninguna de las dos banderas")
    func offeringDoesNotCoverTheBoard() async {
        let gameState = await gameStateWithPairs()
        #expect(gameState.sideRailTapped(.boost) == .offer)
        #expect(!gameState.uiCoversBoard)
        #expect(!gameState.fullScreenUIActive())
        #expect(gameState.canOfferMergeAllVideo(), "con la tarjeta a la vista el botón de video sigue vivo")
    }

    // MARK: El cerrojo de los videos

    @Test("Fusionar todo: el video mirado dos veces paga una sola")
    func mergeAllLatch() async throws {
        let gameState = await gameStateWithPairs()
        var latch = PurchaseLatch()
        #expect(gameState.railVideoWatched(.boost, latch: &latch))
        let queued = queuedCount(gameState)
        let coins = try #require(gameState.player?.run.coins)
        let videos = try #require(gameState.player?.meta.stats.videosWatchedEver)
        #expect(!gameState.railVideoWatched(.boost, latch: &latch), "el segundo aviso lo corta el cerrojo")
        #expect(queuedCount(gameState) == queued)
        #expect(gameState.player?.run.coins == coins, "ni compensa: no es un video más")
        #expect(gameState.player?.meta.stats.videosWatchedEver == videos)
    }

    @Test("la lluvia: el video mirado dos veces paga una sola")
    func packageRainLatch() async throws {
        let gameState = await makeGameState()
        var latch = PurchaseLatch()
        let now = Date().timeIntervalSince1970
        #expect(gameState.railVideoWatched(.packages, latch: &latch, now: now))
        let modifiers = try #require(gameState.player?.run.activeModifiers)
        #expect(modifiers.contains { $0.effect == .packageRateMultiplier })
        let coins = try #require(gameState.player?.run.coins)
        #expect(!gameState.railVideoWatched(.packages, latch: &latch, now: now))
        #expect(gameState.player?.run.activeModifiers == modifiers)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("sólo Fusionar todo y Paquetes tienen video: los otros dos no cobran ni gastan el cerrojo")
    func otherKindsHaveNoVideo() async throws {
        let gameState = await makeGameState()
        var latch = PurchaseLatch()
        let coins = try #require(gameState.player?.run.coins)
        #expect(!gameState.railVideoWatched(.wheel, latch: &latch))
        #expect(!gameState.railVideoWatched(.mattress, latch: &latch))
        #expect(!latch.isLocked)
        #expect(gameState.player?.run.coins == coins)
    }
}

@Suite("La tarjeta del video sigue a la columna")
struct SideRailOfferKeptTests {
    private func rail(boost: SideRailStatus = .ready(count: nil), rain: RailVideoStatus = .available) -> SideRailState {
        SideRailState(
            items: SideRailKind.allCases.map { SideRailItem(kind: $0, status: $0 == .boost ? boost : .idle) },
            packageRain: rain)
    }

    @Test("con la columna escondida la tarjeta se cierra")
    func hiddenRailClosesTheCard() {
        #expect(SideRailOffer.kept(.boost, in: .hidden) == nil)
        #expect(SideRailOffer.kept(.packages, in: .hidden) == nil)
    }

    @Test("con la columna a la vista y el video ofrecible, se queda")
    func visibleRailKeepsTheCard() {
        #expect(SideRailOffer.kept(.boost, in: rail()) == .boost)
        #expect(SideRailOffer.kept(.packages, in: rail()) == .packages)
    }

    @Test("cuando el video deja de estar listo, se cierra")
    func notReadyAnymoreClosesTheCard() {
        #expect(SideRailOffer.kept(.boost, in: rail(boost: .waiting(seconds: 30))) == nil)
        #expect(SideRailOffer.kept(.packages, in: rail(rain: .coolingDown(seconds: 30))) == nil)
        #expect(SideRailOffer.kept(nil, in: rail()) == nil)
    }
}
