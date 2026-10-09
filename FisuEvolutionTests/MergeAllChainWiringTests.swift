import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Fusionar todo: el turno de la cadena")
@MainActor
struct MergeAllChainWiringTests {
    /// Ocho Homeless en el callejón: siete eslabones (4 + 2 + 1) y tres tiers nuevos.
    private func chainOnTheBoard() async throws -> (GameState, Int) {
        let gameState = await makeGameState()
        let links = gameState.debugSeedMergeAll(homeless: 8)
        gameState.syncCelebrations()
        return (gameState, links)
    }

    /// Lo que hace la escena con un eslabón: arrancarlo y confirmarlo.
    private func playLink(_ gameState: GameState, _ change: BoardChange) {
        _ = gameState.confirmBoardChange(id: change.id)
    }

    @Test("el fixture arma la cadena del callejón")
    func theFixtureSeedsSevenLinks() async throws {
        let (gameState, links) = try await chainOnTheBoard()
        #expect(links == 7)
        #expect(gameState.pendingBoardChanges.compactMap(\.chain?.index) == Array(0..<7))
        #expect(gameState.showing == .boardCelebration)
    }

    @Test("los siete eslabones se juegan en un solo turno, y el logro espera al final")
    func theWholeChainIsOneTurn() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        var change = try #require(gameState.beginNextBoardChange())
        var played = 0
        while true {
            playLink(gameState, change)
            played += 1
            #expect(gameState.showing == .boardCelebration, "eslabón \(played): nadie le gana el turno")
            guard let chain = change.chain, let next = gameState.beginNextChainLink(after: chain) else { break }
            #expect(next.chain?.id == chain.id)
            #expect(next.chain?.index == chain.index + 1)
            change = next
        }
        #expect(played == 7)
        #expect(gameState.pendingBoardChanges.isEmpty)
        let homeless = gameState.player?.run.units["homeless"] ?? 0
        #expect(homeless == 0)
        #expect(gameState.player?.run.units["cartonero"] == 1)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .achievements || gameState.showing == .boardCelebration,
                "el logro del primer merge sale recién ahora (o la red revela antes)")
    }

    @Test("el watchdog cuida cada eslabón, no la cadena")
    func theWatchdogIsPerLink() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        var change = try #require(gameState.beginNextBoardChange())
        for _ in 0..<3 {
            for _ in 0..<10 { gameState.tick(delta: 1) }
            #expect(gameState.inFlightBoardChange == change, "a los 10 s de un eslabón, sigue en vuelo")
            playLink(gameState, change)
            let chain = try #require(change.chain)
            change = try #require(gameState.beginNextChainLink(after: chain))
        }
        #expect(gameState.showing == .boardCelebration)
    }

    @Test("una hoja que tapa el tablero corta la cadena; el resto se juega en el turno siguiente")
    func aSheetBreaksTheChainAndItResumes() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        let first = try #require(gameState.beginNextBoardChange())
        playLink(gameState, first)
        gameState.uiCoversBoard = true
        let chain = try #require(first.chain)
        #expect(gameState.beginNextChainLink(after: chain) == nil)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.pendingBoardChanges.count == 6)
        gameState.uiCoversBoard = false
        gameState.syncCelebrations()
        if gameState.showing == .achievements { gameState.celebrationFinished(.achievements) }
        let resumed = try #require(gameState.beginNextBoardChange())
        #expect(resumed.chain?.index == 1, "el contador sigue donde quedó")
    }

    @Test("si lo próximo no es de la cadena, el turno se suelta")
    func aForeignChangeEndsTheTurn() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        let first = try #require(gameState.beginNextBoardChange())
        let foreign = BoardChange(kind: .arrival(typeId: "homeless"), origin: .debug)
        gameState.pendingBoardChanges.insert(foreign, at: 0)
        playLink(gameState, first)
        let chain = try #require(first.chain)
        #expect(gameState.beginNextChainLink(after: chain) == nil)
    }

    @Test("entre eslabones el HUD vuelve: la bandera de algo nuevo es de cada uno")
    func theHUDComesBackBetweenLinks() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        var change = try #require(gameState.beginNextBoardChange())
        // El primer eslabón trae al Trapito (tier 2, nuevo): apaga el HUD.
        #expect(gameState.celebrationHidesUI)
        gameState.markRevealed(tier: 2)
        playLink(gameState, change)
        // El segundo es otro Trapito: nada nuevo.
        let chain = try #require(change.chain)
        change = try #require(gameState.beginNextChainLink(after: chain))
        #expect(gameState.celebrationHidesUI == false)
    }

    @Test("apurar asienta el eslabón en vuelo sin soltar el turno")
    func hurrySettlesWithoutReleasing() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        let first = try #require(gameState.beginNextBoardChange())
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hurryChainLink()
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units - 1)
        #expect(gameState.showing == .boardCelebration)
        let chain = try #require(first.chain)
        #expect(gameState.beginNextChainLink(after: chain)?.chain?.index == 1)
    }
}
