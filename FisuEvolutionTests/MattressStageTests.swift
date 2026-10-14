import Testing
import UIKit
@testable import FisuEvolution

@Suite("El colchón espera y se abre: el video demora el resultado, no el pago")
@MainActor
struct MattressStageTests {
    @Test("sin resultado espera; con resultado y sin terminar el video se abre; terminado, se ve lo que salió")
    func stages() {
        #expect(MattressStage(hasOutcome: false, revealed: false) == .waiting)
        #expect(MattressStage(hasOutcome: true, revealed: false) == .opening)
        #expect(MattressStage(hasOutcome: true, revealed: true) == .revealed)
        #expect(MattressStage(hasOutcome: false, revealed: true) == .waiting)
    }

    @Test("abierto en el tablero el premio sale directo; el «otro colchón» ya está acreditado mientras se abre")
    func paymentPrecedesTheReveal() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        gameState.openMattressOnBoard()
        let popup = try #require(gameState.mattressPopup)
        #expect(popup.openedOnBoard, "la animación ya se vio en el tablero")
        gameState.extraMattressVideoWatched()
        let extra = try #require(gameState.mattressPopup)
        #expect(!extra.openedOnBoard, "el «otro colchón» se abre tocándolo en el popup")
        let outcome = try #require(extra.outcome)
        #expect(outcome.coins > 0 || !outcome.rewards.isEmpty, "el pago no espera al clip")
    }

    @Test("abrir el del tablero dos veces paga una sola")
    func doubleOpenPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress(onBoard: true)
        let first = try #require(gameState.openMattressOnBoard())
        let coins = try #require(gameState.player?.run.coins)
        #expect(gameState.openMattressOnBoard() == nil)
        #expect(gameState.mattressPopup?.outcome == first)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("con la política quieta el clip termina en el acto y el resultado se ve sin esperar")
    func stillPolicyRevealsAtOnce() throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let url = try #require(LoopsManifest.main.url(for: .object("colchon_abre")))
        var revealed = false
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .once { revealed = true }, pool: pool)
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 200, height: 200))
        window.addSubview(layer)
        #expect(layer.player == nil)
        #expect(MattressStage(hasOutcome: true, revealed: revealed) == .revealed)
    }
}
