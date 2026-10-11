import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los dos videos de la columna (PLAN-v2 E7: "boost sin esperar y Fusionar
/// todo (boost)", "colchón, otro colchón y lluvia de paquetes (treasure)").
@Suite("Los videos de la columna", .serialized)
@MainActor
struct SideRailVideosTests {
    private func gameStateWithPairs() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        return gameState
    }

    private func queuedCount(_ gameState: GameState) -> Int {
        gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1)
    }

    private func strike(_ gameState: GameState, until expiresAt: TimeInterval) {
        gameState.player?.run.activeModifiers.append(ActiveModifier(
            effect: .packageRateMultiplier, magnitude: 0, expiresAt: expiresAt, sourceKey: "test.strike"
        ))
    }

    // MARK: Fusionar todo

    @Test("Fusionar todo por video encola los pares del piso y arranca el enfriamiento")
    func mergeAllQueuesThePairs() async throws {
        let gameState = await gameStateWithPairs()
        let now = Date().timeIntervalSince1970
        gameState.mergeAllVideoWatched(now: now)
        #expect(queuedCount(gameState) == 3)
        #expect(gameState.pendingBoardChanges.allSatisfy { $0.origin == .rewardedMergeAll })
        let cooldown = try #require(gameState.content?.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds)
        #expect(gameState.mergeAllVideoStatus(pairs: 3, now: now + 1) == .coolingDown(seconds: cooldown - 1))
    }

    @Test("sin pares el video no gasta el enfriamiento y compensa")
    func noPairsCompensates() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        let before = try #require(gameState.player?.run.coins)
        gameState.mergeAllVideoWatched(now: Date().timeIntervalSince1970)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.player?.meta.rewardedActivations[GameState.mergeAllVideoKey] == nil)
        #expect(gameState.player?.meta.stats.videosWatchedEver == 1)
    }

    @Test("un aviso repetido del mismo video no vuelve a encolar: compensa y el enfriamiento sigue siendo el primero")
    func aRepeatedCallbackQueuesOnce() async throws {
        let gameState = await gameStateWithPairs()
        gameState.mergeAllVideoWatched(now: 1000)
        let queued = queuedCount(gameState)
        let before = try #require(gameState.player?.run.coins)
        gameState.mergeAllVideoWatched(now: 1001)
        #expect(queuedCount(gameState) == queued)
        #expect(gameState.player?.meta.rewardedActivations[GameState.mergeAllVideoKey] == 1000)
        #expect(try #require(gameState.player?.run.coins) > before, "el segundo video se miró: compensa")
        #expect(!gameState.canOfferMergeAllVideo(now: 1002), "ya no se ofrece")
    }

    @Test("el video se ofrece con pares y el tablero libre; con una hoja encima, no")
    func offerIsGatedByTheBoard() async {
        let gameState = await gameStateWithPairs()
        let now = Date().timeIntervalSince1970
        #expect(gameState.canOfferMergeAllVideo(now: now))
        gameState.mattressPopup = MattressPopup()
        #expect(gameState.isBoardBusy)
        #expect(!gameState.canOfferMergeAllVideo(now: now))
    }

    @Test("la oferta relee el piso en vivo, no la proyección publicada")
    func offerRereadsThePairs() async {
        let gameState = await gameStateWithPairs()
        let now = Date().timeIntervalSince1970
        gameState.refreshSideRail(now: now)
        #expect(gameState.sideRail.status(of: .boost) == .ready(count: nil))
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        #expect(gameState.sideRail.status(of: .boost) == .ready(count: nil), "la proyección todavía no se enteró")
        #expect(!gameState.canOfferMergeAllVideo(now: now))
    }

    @Test("el aviso del video no mira la hoja: lo encolado espera su turno y el pago no se pierde")
    func busyBoardDoesNotEatThePayment() async {
        let gameState = await gameStateWithPairs()
        gameState.mattressPopup = MattressPopup()
        gameState.mergeAllVideoWatched(now: 1000)
        #expect(queuedCount(gameState) == 3)
    }

    // MARK: La cadena del video se descarta

    @Test("un par suelto descartado, que no es de ninguna cadena, no compensa")
    func aLooseDiscardedPairIsNotCompensated() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player?.run.coins)
        gameState.discardBoardChange(BoardChange(
            kind: .merge(floorOrdinal: 0, typeId: "homeless", sourceSlot: 0, targetSlot: 1, newTypeId: "homeless"),
            origin: .rewardedMergeAll
        ))
        #expect(gameState.player?.run.coins == before)
    }

    @Test("si todos los eslabones de la cadena se descartan, el video compensa, una sola vez")
    func aFullyDiscardedChainCompensatesOnce() async throws {
        let gameState = await gameStateWithPairs()
        gameState.mergeAllVideoWatched(now: 1000)
        let planned = gameState.pendingBoardChanges
        #expect(planned.count == 3)
        let before = try #require(gameState.player?.run.coins)
        gameState.pendingBoardChanges.removeAll()
        planned.dropLast().forEach(gameState.discardBoardChange)
        #expect(gameState.player?.run.coins == before, "faltaba un eslabón: la cadena sigue viva")
        gameState.discardBoardChange(try #require(planned.last))
        let coins = try #require(gameState.player?.run.coins)
        let content = try #require(gameState.content)
        #expect(coins == before + GameState.coinReward(
            seconds: content.rewardedAds.compensationSeconds, player: try #require(gameState.player),
            content: content, economy: try #require(gameState.economy)
        ), "una compensación, no tres")
    }

    @Test("con un solo eslabón jugado, descartar el resto no compensa: el video ya hizo algo")
    func aPartlyPlayedChainDoesNotCompensate() async throws {
        let gameState = await gameStateWithPairs()
        gameState.mergeAllVideoWatched(now: 1000)
        _ = try #require(gameState.beginNextBoardChange())
        let first = try #require(gameState.inFlightBoardChange)
        #expect(gameState.confirmBoardChange(id: first.id) != nil)
        let before = try #require(gameState.player?.run.coins)
        let rest = gameState.pendingBoardChanges
        gameState.pendingBoardChanges.removeAll()
        rest.forEach(gameState.discardBoardChange)
        #expect(gameState.player?.run.coins == before)
    }

    @Test("un evento que vacía el piso antes del turno descarta toda la cadena y el video compensa")
    func aBoardThatChangedUnderTheChainCompensates() async throws {
        let gameState = await gameStateWithPairs()
        gameState.mergeAllVideoWatched(now: 1000)
        let before = try #require(gameState.player?.run.coins)
        gameState.player?.run.units = [:]
        gameState.reconcileTower()
        gameState.settleAllPendingBoardChanges()
        #expect(gameState.pendingBoardChanges.isEmpty)
        let paid = try #require(gameState.player?.run.coins)
        #expect(paid > before)
        gameState.settleAllPendingBoardChanges()
        #expect(gameState.player?.run.coins == paid)
    }

    // MARK: La lluvia de paquetes

    @Test("la lluvia: ×10 paquetes por 60 s y su enfriamiento")
    func packageRain() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        #expect(gameState.packageRainStatus(now: now) == .available)
        gameState.packageRainVideoWatched(now: now)
        let rain = try #require(gameState.player?.run.activeModifiers.first { $0.effect == .packageRateMultiplier })
        #expect(rain.magnitude == 10)
        #expect(abs(rain.expiresAt - (now + 60)) < 0.001)
        guard case .coolingDown = gameState.packageRainStatus(now: now + 1) else {
            Issue.record("la lluvia no arrancó su enfriamiento")
            return
        }
    }

    @Test("un aviso repetido de la lluvia no da otra: compensa y queda una sola")
    func aRepeatedRainCallbackGrantsOnce() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.packageRainVideoWatched(now: now)
        let before = try #require(gameState.player?.run.coins)
        gameState.packageRainVideoWatched(now: now + 1)
        let rains = gameState.player?.run.activeModifiers.filter { $0.effect == .packageRateMultiplier }
        #expect(rains?.count == 1)
        #expect(try #require(gameState.player?.run.coins) > before)
    }

    @Test("con el buzón lleno la lluvia no se ofrece, y si el video termina igual, compensa")
    func fullBoxMeansNoRain() async throws {
        let gameState = await makeGameState()
        let maxWaiting = try #require(gameState.content?.packages.maxWaiting)
        gameState.debugAddPackages(maxWaiting)
        let now = Date().timeIntervalSince1970
        #expect(gameState.packageRainStatus(now: now) == .notApplicable)
        #expect(!gameState.canOfferPackageRainVideo(now: now))
        let before = try #require(gameState.player?.run.coins)
        gameState.packageRainVideoWatched(now: now)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.player?.run.activeModifiers.contains { $0.effect == .packageRateMultiplier } == false)
        #expect(gameState.player?.meta.rewardedActivations[GameState.packageRainVideoKey] == nil)
    }

    @Test("con un piquete la lluvia no se ofrece ni muestra reloj, y Paquetes tampoco")
    func strikeMeansNoRainAndNoClock() async {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.engagement.packages.secondsUntilNext = 120
        gameState.refreshSideRail(now: now)
        #expect(gameState.sideRail.status(of: .packages) == .waiting(seconds: 120))
        strike(gameState, until: now + 600)
        gameState.refreshSideRail(now: now)
        #expect(gameState.sideRail.packageRain == .notApplicable)
        #expect(gameState.sideRail.status(of: .packages) == .idle)
    }

    @Test("un piquete en pleno enfriamiento de la lluvia tampoco deja un reloj engañoso")
    func strikeBeatsTheCooldown() async {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.rewardedActivations[GameState.packageRainVideoKey] = now - 10
        strike(gameState, until: now + 600)
        #expect(gameState.packageRainStatus(now: now) == .notApplicable)
    }

    // MARK: La ruleta

    @Test("la ruleta sin giros cuenta hasta que vuelven los de video, no hasta cualquier medianoche")
    func wheelClockFollowsTheSavedDay() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        let perDay = try #require(gameState.effectiveWheel?.videoSpinsPerDay)
        for _ in 0..<perDay { _ = try #require(gameState.spinWheel(.video, now: now)) }
        gameState.refreshSideRail(now: now)
        let readyAt = try #require(gameState.wheelSpinsReadyAt(now: now))
        #expect(gameState.sideRail.status(of: .wheel) == .waiting(seconds: Int((readyAt - now).rounded(.up))))
    }

    @Test("con el día guardado en el futuro el reloj cuenta hasta el día que cierra el guardado")
    func wheelClockWithAFutureSavedDay() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        let tomorrow = now + 86_400
        let perDay = try #require(gameState.effectiveWheel?.videoSpinsPerDay)
        for _ in 0..<perDay { _ = try #require(gameState.spinWheel(.video, now: tomorrow)) }
        gameState.refreshSideRail(now: now)
        let readyAt = try #require(gameState.wheelSpinsReadyAt(now: now))
        #expect(readyAt - now > 86_400, "no es la medianoche de hoy")
        #expect(gameState.sideRail.status(of: .wheel) == .waiting(seconds: Int((readyAt - now).rounded(.up))))
    }
}
