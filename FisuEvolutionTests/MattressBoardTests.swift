import EconomyKit
import Testing
@testable import FisuEvolution

/// El colchón después del video (E14b B24): cae en un lugar del piso que se mira, se queda ahí, y
/// al abrirlo sale siempre el pop-up del premio con su nombre y su imagen.
@Suite("El colchón en el tablero: su lugar y su premio (E14b B24)")
@MainActor
struct MattressBoardTests {
    @Test("pagado con el video cae en el piso que se mira, en un lugar de adelante")
    func thePaidOneLandsOnTheVisibleFloor() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        #expect(gameState.mattressFloor == nil, "en la columna no tiene lugar")
        gameState.mattressTapped()
        gameState.mattressVideoWatched()
        #expect(gameState.mattressOnBoard)
        #expect(gameState.mattressPopup == nil, "el pop-up del video se cierra")
        #expect(gameState.mattressFloor == gameState.visibleFloorOrdinal)
        let spot = try #require(gameState.mattressSpot)
        #expect(spot.y < GameState.mattressBackDepth.lowerBound)
    }

    @Test("su lugar viaja en el save: no se mueve al volver a ubicarlo, y abierto se olvida")
    func itStaysWhereItLanded() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        let floor = try #require(gameState.mattressFloor)
        let spot = try #require(gameState.mattressSpot)
        gameState.placeMattressIfNeeded()
        #expect(gameState.mattressFloor == floor && gameState.mattressSpot == spot, "uno que ya tiene lugar no se mueve")
        #expect(gameState.player?.meta.engagement.treasures.floor == floor)
        _ = try #require(gameState.openMattressOnBoard())
        #expect(gameState.mattressFloor == nil && gameState.mattressSpot == nil)
    }

    @Test("el de un save anterior a B24 (en el tablero, sin lugar) se ubica al cargar")
    func aLegacyBoardMattressGetsASpot() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.engagement.treasures = TreasuresState(secondsUntilNext: 100, phase: .onBoard)
        #expect(gameState.mattressSpot == nil)
        gameState.advanceTreasures(delta: 0.016)
        #expect(gameState.mattressSpot != nil)
        #expect(gameState.mattressFloor == gameState.visibleFloorOrdinal)
    }

    @Test("reencarnar con el colchón en un piso que se cierra: al tick cae en un piso abierto")
    func reincarnatingMovesItOffAClosedFloor() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.setVisibleFloor(2)
        try #require(gameState.visibleFloorOrdinal == 2)
        gameState.debugSpawnMattress(onBoard: true)
        #expect(gameState.mattressFloor == 2)
        gameState.giveEarningsForPrestigeTesting(blue: 3)
        gameState.confirmPrestige()
        gameState.advanceTreasures(delta: 0.016)
        let open = Set(gameState.floorMap.filter(\.isUnlocked).map(\.ordinal))
        #expect(!open.contains(2), "la run nueva cerró ese piso")
        #expect(gameState.mattressOnBoard, "sigue en el tablero, cerrado")
        let floor = try #require(gameState.mattressFloor)
        #expect(open.contains(floor))
        #expect(floor == gameState.visibleFloorOrdinal, "el que se mira, si está abierto")
        let spot = try #require(gameState.mattressSpot)
        #expect(spot.y < GameState.mattressBackDepth.lowerBound)
    }

    @Test("asomado al piso cerrado de adelante, el nuevo cae en el más alto abierto")
    func itNeverLandsOnThePeekFloor() async throws {
        let gameState = await makeGameState()
        let open = Set(gameState.floorMap.filter(\.isUnlocked).map(\.ordinal))
        let highest = try #require(open.max())
        gameState.setVisibleFloor(highest + 1)
        try #require(gameState.visibleFloorOrdinal == highest + 1, "se asoma al de adelante")
        gameState.debugSpawnMattress(onBoard: true)
        #expect(gameState.mattressFloor == highest)
    }

    @Test("el gratis (B31) sigue el mismo camino: lugar en el piso, se abre ahí y su cobro ofrece el ×2 (B29)")
    func theFreeOneTakesTheSamePath() async throws {
        let gameState = await makeGameState()
        gameState.debugDropFreeMattress()
        #expect(gameState.mattressSpot(.free) != nil)
        #expect(gameState.mattressFloor(.free) == gameState.visibleFloorOrdinal)
        #expect(!gameState.mattressOnBoard, "no ocupa el lugar del de la columna")
        let outcome = try #require(gameState.openMattressOnBoard(.free))
        #expect(outcome.isGift, "el cobro del gratis dispara el paso 2")
        #expect(outcome.extraOpensLeft == 0, "el gratis no ofrece «otro colchón»")
        #expect(gameState.mattressPopup?.openedOnBoard == true)
        #expect(!gameState.freeMattressOnBoard)
        let restarted = try #require(gameState.player?.meta.engagement.treasures.freeBoard.clockStartedAt)
        #expect(abs(restarted - Date().timeIntervalSince1970) < 60, "su reloj arranca al abrirlo")
    }

    @Test("los dos colchones a la vez: cada uno en su lugar, sin pisarse, y se abren por separado")
    func bothMattressesAtOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.debugDropFreeMattress()
        let column = try #require(gameState.mattressSpot(.column))
        let free = try #require(gameState.mattressSpot(.free))
        #expect(column != free)
        let area = try #require(gameState.packageAreas(onFloor: gameState.visibleFloorOrdinal).first)
        #expect(PackagePlacer.crowding(of: free, among: [], in: area) >= 1, "las cajas tampoco caen encima")
        #expect(PackagePlacer.crowding(of: column, among: [], in: area) >= 1)
        let opened = try #require(gameState.openMattressOnBoard(.free))
        #expect(opened.isGift)
        #expect(gameState.mattressOnBoard, "abrir el gratis deja el de la columna")
    }

    @Test("es de su piso: mirar otro piso no lo mueve, y en el save queda su piso (pedido del dueño)")
    func itStaysOnItsFloor() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)
        gameState.setVisibleFloor(1)
        gameState.debugSpawnMattress(onBoard: true)
        gameState.debugDropFreeMattress()
        #expect(gameState.mattressFloor(.column) == 1 && gameState.mattressFloor(.free) == 1)
        for floor in [0, 2, 0] {
            gameState.setVisibleFloor(floor)
            gameState.advanceTreasures(delta: 0.016)
            #expect(gameState.mattressFloor(.column) == 1, "mirando el piso \(floor)")
            #expect(gameState.mattressFloor(.free) == 1, "mirando el piso \(floor)")
        }
    }

    @Test("cada premio del colchón tiene nombre e imagen aprobada en el pop-up")
    func everyPrizeHasANameAndAnImage() async throws {
        let gameState = await makeGameState()
        let prizes = try #require(gameState.content?.treasures.prizes)
        #expect(!prizes.isEmpty)
        for prize in prizes {
            let paysCoins = prize.rewards.contains { RewardKind($0) == .coins }
            let outcome = MattressOutcome(prizeId: prize.id, rewards: prize.rewards, coins: paysCoins ? 1234 : 0,
                                          extraOpensLeft: 1)
            let reveal = MattressReveal(outcome)
            #expect(reveal.kind.resolvedArtKey != nil, "\(prize.id): sin imagen")
            #expect(reveal.kind != .mattressTreasure, "\(prize.id): cae en la imagen genérica")
            let name = reveal.caption ?? reveal.text
            #expect(!name.isEmpty, "\(prize.id): sin nombre")
        }
    }

    @Test("la plata dice cuánto y qué es; lo que no es plata dice su nombre")
    func revealText() {
        let coins = MattressReveal(MattressOutcome(prizeId: "coins", rewards: [.coinsSeconds(1200)], coins: 1500,
                                                   extraOpensLeft: 0))
        #expect(coins.kind == .coins)
        #expect(coins.text.hasPrefix("+"))
        #expect(coins.caption == RewardCopy.title(.coinsSeconds(1200)))
        let blue = MattressReveal(MattressOutcome(prizeId: "blue", rewards: [.blue(2)], coins: 0, extraOpensLeft: 0))
        #expect(blue.kind == .blue)
        #expect(blue.text == RewardCopy.title(.blue(2)))
        #expect(blue.caption == nil)
    }
}
