import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La Marcha del Puntero en la partida (E14b B25, D16): qué toques cuentan, el save, el cobro único
/// con el paso 2 de B29 y la derrota sin premio. Las reglas puras (reloj real, cupo semanal) las
/// cubre `MarchTests` en EconomyKit.
@Suite("La Marcha del Puntero en la partida", .serialized)
@MainActor
struct MarchRuntimeTests {
    private func calm(_ gameState: GameState) {
        var guardrail = 12
        while let kind = gameState.showing, guardrail > 0 {
            guardrail -= 1
            switch kind {
            case .dailyReward: gameState.dismissDailyClaim()
            case .offlineEarnings:
                gameState.dismissOfflineReward()
                gameState.celebrationFinished(.offlineEarnings)
            case .careerChoice:
                gameState.careerPrompt = nil
                gameState.celebrationFinished(.careerChoice)
            case .chestOpening: gameState.dismissChestReward()
            case .specialDrop: gameState.dismissSpecialDrop()
            case .skinAward:
                gameState.skinAward = nil
                gameState.celebrationFinished(.skinAward)
            default: gameState.celebrationFinished(kind)
            }
        }
    }

    /// Frontera en 6, plata, duplicados y el Puntero que ya propuso la Marcha y la aceptaron.
    private func marching(ads: (any AdsProvider)? = nil) async throws -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        calm(gameState)
        if let ads { gameState.ads = AdsCoordinator(provider: ads) }
        let script = try #require(gameState.content?.visitors.script(id: "puntero_marcha"))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        #expect(gameState.chooseVisitOption("challenge"))
        return gameState
    }

    private func march(_ gameState: GameState) -> MarchState? { gameState.player?.meta.engagement.visitors.march }
    private func blue(_ gameState: GameState) -> Int { gameState.player?.meta.blue ?? 0 }

    @Test("aceptarla la guarda en el save con la hora de pared y el Puntero se va: no es un reto del escenario")
    func acceptingStoresTheMarch() async throws {
        let before = Date().timeIntervalSince1970
        let gameState = try await marching()
        let stored = try #require(march(gameState))
        #expect(stored.goal == 420 && stored.rewards == [.blue(30)])
        #expect(stored.startedAt >= before && stored.endsAt == stored.startedAt + 3600)
        #expect(gameState.stageChallenge == nil, "no traba el tablero ni los cortes una hora")
        #expect(gameState.stageVisit?.offer == nil, "el trato se cerró")
        #expect(gameState.visitorPopup == nil)
    }

    @Test("sólo cuentan los toques a mano que dan monedas: ni el segundo toque de una fusión ni el autotoque")
    func whichTapsCount() async throws {
        let gameState = try await marching()
        let slot = try #require(gameState.visiblePlacements.first?.slot)
        #expect(gameState.registerTap(cellIndex: slot) != nil)
        #expect(march(gameState)?.taps == 1, "un toque a mano suma")
        #expect(gameState.registerTap(cellIndex: slot, countsForMarch: false) != nil, "la fusión asistida cobra igual")
        #expect(march(gameState)?.taps == 1, "pero no suma")
        let now = Date().timeIntervalSince1970
        gameState.grant(.autoTap(perSecond: 5, seconds: 600), source: "shop.auto_tap", now: now)
        gameState.advanceAutoTap(delta: 2, now: now + 1)
        #expect(march(gameState)?.taps == 1, "el autotoque comprado no suma")
    }

    @Test("el toque 420 la gana, sale el festejo, cobra 30 blue UNA vez y después ofrece el ×2")
    func winningPaysOnce() async throws {
        let gameState = try await marching(ads: ScriptedAdsProvider())
        let started = try #require(march(gameState))
        gameState.player?.meta.engagement.visitors.march?.taps = 419
        gameState.noteMarchTap(now: started.startedAt + 60)
        #expect(march(gameState)?.outcome == .won)
        #expect(gameState.marchPopup == .result, "el Puntero sale a festejar")
        let before = blue(gameState)
        let settled = try #require(gameState.settleMarch(now: started.startedAt + 61))
        #expect(settled.outcome == .won)
        #expect(blue(gameState) == before + 30)
        #expect(march(gameState) == nil && gameState.marchPopup == nil)
        #expect(gameState.settleMarch() == nil, "la segunda vez no hay nada")
        #expect(blue(gameState) == before + 30)
        let double = try #require(gameState.rewardDouble, "el paso 2 de B29")
        #expect(double.site == "double.marcha")
        #expect(gameState.claimRewardDouble(id: double.id))
        #expect(blue(gameState) == before + 60)
    }

    @Test("si se acaba la hora (aunque la app estuviera cerrada), dice su línea y no paga")
    func expiringPaysNothing() async throws {
        let gameState = try await marching()
        let started = try #require(march(gameState))
        gameState.player?.meta.engagement.visitors.march?.taps = 419
        gameState.advanceMarch(now: started.endsAt + 7200)
        #expect(march(gameState)?.outcome == .lost)
        #expect(gameState.marchPopup == .result)
        gameState.noteMarchTap(now: started.endsAt + 7201)
        #expect(march(gameState)?.taps == 419, "vencida no cuenta más")
        let before = blue(gameState)
        let settled = try #require(gameState.settleMarch())
        #expect(settled.outcome == .lost)
        #expect(blue(gameState) == before)
        #expect(gameState.rewardDouble == nil)
    }

    @Test("el chip abre el estado mientras corre; cerrarlo no toca la Marcha")
    func theChipOpensTheStatus() async throws {
        let gameState = try await marching()
        gameState.openMarchPopup()
        #expect(gameState.marchPopup == .status)
        #expect(gameState.isBoardBusy, "con el popup abierto no cae un corte")
        gameState.closeMarchStatus()
        #expect(gameState.marchPopup == nil)
        #expect(march(gameState)?.isRunning == true)
    }

    @Test("los botones y el final son los del guion; los otros retos siguen con los de siempre")
    func scriptLines() throws {
        let content = try GameContentLoader.load(from: .main)
        let marcha = try #require(content.visitors.script(id: "puntero_marcha"))
        let coach = try #require(content.visitors.script(id: "coach_reto"))
        let start = VisitOption(id: "challenge", kind: .startChallenge, coins: 0, rewards: [], departures: [],
                                requiresVideo: false, challenge: nil)
        #expect(VisitCopy.optionTitle(start, script: marcha, content: content) == VisitCopy.text("visit.puntero_marcha.accept"))
        #expect(VisitCopy.declineTitle(for: marcha) == VisitCopy.text("visit.puntero_marcha.decline"))
        #expect(VisitCopy.marchLine(for: marcha, won: true) == VisitCopy.text("visit.puntero_marcha.won"))
        #expect(VisitCopy.marchLine(for: marcha, won: false) == VisitCopy.text("visit.puntero_marcha.lost"))
        #expect(VisitCopy.optionTitle(start, script: coach, content: content) == VisitCopy.text("visit.option.start_challenge"))
        #expect(VisitCopy.declineTitle(for: coach) == VisitCopy.text("visit.option.decline"))
    }

    @Test("nunca en la primera sesión ni antes de terminar el tutorial")
    func notInTheFirstSession() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.player?.meta.engagement.visitors.sessions = 1
        #expect(gameState.visitContext?.allowsWeekly == false, "primera sesión")
        gameState.player?.meta.engagement.visitors.sessions = 2
        #expect(gameState.visitContext?.allowsWeekly == TutorialFlags.coreCompleted(in: gameState.flagDefaults))
    }
}
