import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La columna en la partida", .serialized)
@MainActor
struct SideRailProjectionTests {
    private func gameStateWithPairs() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.refreshProjections()
        return gameState
    }

    @Test("con el núcleo del tutorial no hay columna; sin él, los cuatro")
    func visibility() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.sideRail.items.map(\.kind) == SideRailKind.allCases)
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(gameState.sideRail == .hidden)
    }

    @Test("lee los accesos de E5: paquetes, colchón y giros")
    func readsThePrizeAccess() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress()
        gameState.refreshProjections()
        #expect(gameState.sideRail.status(of: .packages) == .ready(count: 2))
        #expect(gameState.sideRail.status(of: .mattress) == .ready(count: nil))
        #expect(gameState.sideRail.status(of: .wheel) == .ready(count: gameState.prizeAccess.wheelSpinsReady))
    }

    @Test("Fusionar todo: con pares en el piso se ofrece y dice cuántos; con uno solo, no")
    func mergeAllNeedsPairs() async {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.sideRail.status(of: .boost) == .idle)
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.sideRail.status(of: .boost) == .ready(count: nil))
        #expect(gameState.sideRail.mergeAllPairs == 3)
    }

    @Test("Fusionar todo ya encolado (por video, por ORO o en cadena) no vuelve a contar los mismos pares")
    func queuedMergeAllIsNotCountedAgain() async {
        for origin in [BoardChange.Origin.rewardedMergeAll, .oroShop] {
            let gameState = await gameStateWithPairs()
            #expect(gameState.enqueueMergeAll(onFloor: gameState.visibleFloorOrdinal, origin: origin) == 3)
            gameState.refreshProjections()
            #expect(gameState.sideRail.mergeAllPairs == 0, "\(origin): los pares ya están en la cola")
            #expect(gameState.sideRail.status(of: .boost) == .idle)
        }
    }

    @Test("el par que ya va en vuelo tampoco se cuenta")
    func inFlightMergeAllIsNotCounted() async {
        let gameState = await gameStateWithPairs()
        gameState.enqueueMergeAll(onFloor: gameState.visibleFloorOrdinal, origin: .rewardedMergeAll)
        gameState.inFlightBoardChange = gameState.pendingBoardChanges.removeFirst()
        gameState.pendingBoardChanges.removeAll()
        gameState.refreshProjections()
        #expect(gameState.sideRail.mergeAllPairs == 0)
    }

    @Test("el video de Fusionar todo en enfriamiento muestra el reloj, aun con pares")
    func mergeAllCoolsDown() async throws {
        let gameState = await gameStateWithPairs()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.rewardedActivations[GameState.mergeAllVideoKey] = now - 100
        gameState.refreshSideRail(now: now)
        let rail = try #require(gameState.content?.rewardedAds.effectiveSideRail)
        #expect(gameState.sideRail.status(of: .boost) == .waiting(seconds: Int(rail.mergeAllCooldownSeconds) - 100))
    }

    @Test("la lluvia: se ofrece con lugar en el buzón; con el buzón lleno, no")
    func packageRain() async {
        let gameState = await makeGameState()
        gameState.refreshSideRail()
        #expect(gameState.sideRail.packageRain == .available)
        gameState.debugAddPackages(gameState.content?.packages.maxWaiting ?? 0)
        gameState.refreshSideRail()
        #expect(gameState.sideRail.packageRain == .notApplicable)
    }

    @Test("un video de Fusionar todo con otro ya en la cola no tiene efecto: compensa y no toca la cola")
    func rewardedMergeAllWithQueuedChainCompensates() async throws {
        let gameState = await gameStateWithPairs()
        gameState.enqueueMergeAll(onFloor: gameState.visibleFloorOrdinal, origin: .oroShop)
        let queued = gameState.pendingBoardChanges
        let coins = try #require(gameState.player?.run.coins)
        gameState.mergeAllVideoWatched()
        #expect(try #require(gameState.player?.run.coins) > coins)
        guard case .rewardCompensated? = gameState.towerNotice?.kind else {
            Issue.record("no hubo compensación")
            return
        }
        #expect(gameState.pendingBoardChanges == queued)
    }

    @Test("un reloj atrasado no infla el enfriamiento más allá de su tope")
    func backwardsClockIsCapped() async throws {
        let gameState = await gameStateWithPairs()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.rewardedActivations[GameState.mergeAllVideoKey] = now + 100_000
        gameState.refreshSideRail(now: now)
        let rail = try #require(gameState.content?.rewardedAds.effectiveSideRail)
        #expect(gameState.sideRail.status(of: .boost) == .waiting(seconds: Int(rail.mergeAllCooldownSeconds)))
    }

    @Test("un rewarded_ads.json sin sideRail usa el default")
    func missingSectionUsesDefault() throws {
        let json = #"{"schemaVersion": 2, "compensationSeconds": 180, "rewards": []}"#
        let config = try JSONDecoder().decode(RewardedAdsConfig.self, from: Data(json.utf8))
        #expect(config.sideRail == nil)
        #expect(config.effectiveSideRail == .default)
    }

    @Test("el JSON trae la sección de la columna y la lluvia se puede entregar")
    func configIsThere() throws {
        let content = try GameContentLoader.load(from: .main)
        let rail = try #require(content.rewardedAds.sideRail)
        #expect(rail.mergeAllCooldownSeconds > 0)
        #expect(rail.packageRainCooldownSeconds > 0)
        try rail.packageRain.validate()
        #expect(GameState.grantableRewardKinds.contains(rail.packageRain.kind))
    }
}
