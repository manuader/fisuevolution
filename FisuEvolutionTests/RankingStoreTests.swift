import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El store del ranking (E12 T8): registro, sello, nombre y reintentos, contra el servidor de mentira.
@MainActor
@Suite("Store del ranking")
struct RankingStoreTests {

    // MARK: - Dobles

    final class Host: RankingStateHost {
        var state: RankingState?
        var godTier: Int? = 12
        private(set) var saves = 0

        init(_ state: RankingState? = .newGame) { self.state = state }

        var rankingState: RankingState? { state }

        func updateRanking(_ change: (inout RankingState) -> Void) {
            guard var copy = state else { return }
            change(&copy)
            state = copy
            saves += 1
        }
    }

    /// El servidor de mentira con interruptor de red, un error forzable para el cierre y una compuerta
    /// que suspende `startRun`/`finishRun` hasta `release()`.
    actor Switchable: RankingClient {
        let inner: SimulatedRankingClient
        private var online = true
        private var finishError: RankingError?
        private var holding = false
        private var waiting: [CheckedContinuation<Void, Never>] = []
        private(set) var entered = 0

        init(_ inner: SimulatedRankingClient) { self.inner = inner }

        func setOnline(_ value: Bool) { online = value }
        func failFinish(with error: RankingError?) { finishError = error }
        func hold() { holding = true }

        func release() {
            holding = false
            waiting.forEach { $0.resume() }
            waiting = []
        }

        private func suspendIfHeld() async {
            entered += 1
            guard holding else { return }
            await withCheckedContinuation { waiting.append($0) }
        }

        func startRun(_ request: StartRunRequest) async throws(RankingError) -> StartRunResponse {
            guard online else { throw .offline }
            await suspendIfHeld()
            return try await inner.startRun(request)
        }
        func finishRun(_ request: FinishRunRequest) async throws(RankingError) -> FinishRunResponse {
            guard online else { throw .offline }
            await suspendIfHeld()
            if let finishError { _ = try? await inner.finishRun(request); throw finishError }
            return try await inner.finishRun(request)
        }
        func leaderboard(_ request: LeaderboardRequest) async throws(RankingError) -> LeaderboardResponse {
            guard online else { throw .offline }
            return try await inner.leaderboard(request)
        }
        func report(_ request: ReportRequest) async throws(RankingError) {
            guard online else { throw .offline }
            try await inner.report(request)
        }
    }

    final class Clock: @unchecked Sendable {
        var value: TimeInterval = 0
    }

    struct Fixture {
        let store: RankingStore
        let host: Host
        let client: Switchable
        let simulated: SimulatedRankingClient
        let clock: Clock
        let cache: URL
    }

    static let runA = "6f1c2a52-8d3e-4c1b-9a41-0d1e2f3a4b5c"
    static let runB = "b7d9e0f1-2a3b-4c5d-8e6f-7a8b9c0d1e2f"

    static let usable = RankingConfig(
        schemaVersion: 1, enabled: true, baseURL: URL(string: "https://example.test"), anonKey: "k")

    func make(
        _ scenario: SimulatedRankingClient.Scenario = .happy,
        state: RankingState? = .newGame,
        config: RankingConfig = RankingStoreTests.usable,
        cache: URL? = nil
    ) -> Fixture {
        let clock = Clock()
        let simulated = SimulatedRankingClient(scenario: scenario, now: { 1_000 + clock.value })
        let client = Switchable(simulated)
        let cacheURL = cache ?? URL.temporaryDirectory.appending(path: "ranking-board-\(UUID().uuidString).json")
        let store = RankingStore(
            client: client, config: config, now: { clock.value }, appVersion: "2.0", cacheURL: cacheURL)
        let host = Host(state)
        store.host = host
        return Fixture(store: store, host: host, client: client, simulated: simulated, clock: clock, cache: cacheURL)
    }

    /// Una partida registrada a la que le falta llegar a Dios (`reachedGod()` hace la transición).
    func runningState() -> RankingState {
        var state = RankingState(phase: .running(runId: Self.runA, serverStartedAt: 1_000))
        state.playedSeconds = 120
        return state
    }

    func waitForEntered(_ f: Fixture, _ count: Int) async {
        for _ in 0..<2_000 {
            if await f.client.entered >= count { return }
            await Task.yield()
        }
    }

    func finishRuns(_ f: Fixture) async -> [FinishRunRequest] {
        await f.simulated.calls.compactMap { call in
            if case .finishRun(let request) = call { request } else { nil }
        }
    }

    func startRunCount(_ f: Fixture) async -> Int {
        await f.simulated.calls.filter { if case .startRun = $0 { true } else { false } }.count
    }

    // MARK: - Registro

    @Test("con red, la partida nueva queda corriendo con el inicio del servidor")
    func registersWithNetwork() async {
        let f = make()
        f.store.newGameStarted()
        await f.store.settled()
        #expect(f.host.state?.phase == .running(runId: "00000000-0000-4000-8000-000000000001", serverStartedAt: 1_000))
        #expect(f.host.state?.clientRunId == nil)
    }

    @Test("el intento se guarda antes de mandar el start-run y se reenvía con el mismo id")
    func attemptIsPersistedBeforeSending() async {
        let f = make()
        await f.client.setOnline(false)
        f.store.newGameStarted()
        await f.store.settled()
        let saved = f.host.state?.clientRunId
        #expect(saved != nil)
        #expect(f.host.state?.phase == .awaitingStart)

        await f.client.setOnline(true)
        await f.store.pump()
        let sent = await f.simulated.calls.compactMap { call -> String? in
            if case .startRun(let request) = call { request.clientRunId } else { nil }
        }
        #expect(sent == [saved])
    }

    @Test("sin red queda esperando; al volver activo con red se registra")
    func staysAwaitingThenRegisters() async {
        let f = make()
        await f.client.setOnline(false)
        f.store.newGameStarted()
        await f.store.settled()
        #expect(f.host.state?.phase == .awaitingStart)

        await f.client.setOnline(true)
        f.store.becameActive()
        await f.store.settled()
        guard case .running = f.host.state?.phase else {
            Issue.record("se esperaba .running y quedó \(String(describing: f.host.state?.phase))")
            return
        }
    }

    @Test("tres vueltas a la vez con el pedido en vuelo hacen un solo start-run")
    func concurrentLapsMakeOneRequest() async {
        let f = make()
        await f.client.hold()
        f.store.becameActive()
        await waitForEntered(f, 1)
        f.store.becameActive()
        f.store.becameActive()
        await Task.yield()
        await f.client.release()
        await f.store.settled()
        #expect(await startRunCount(f) == 1)
        guard case .running = f.host.state?.phase else {
            Issue.record("se esperaba .running")
            return
        }
    }

    @Test("reintento: sin red y después con red registra una sola partida")
    func retryRegistersOnce() async {
        let f = make()
        await f.client.setOnline(false)
        f.store.newGameStarted()
        await f.store.settled()
        await f.client.setOnline(true)
        await f.store.pump()
        await f.store.pump()
        #expect(await startRunCount(f) == 1)
    }

    @Test("el reset registra una partida nueva")
    func resetRegistersANewRun() async {
        let f = make()
        f.store.newGameStarted()
        await f.store.settled()
        f.host.state = f.host.state?.forNewGame()
        f.store.newGameStarted()
        await f.store.settled()
        #expect(await startRunCount(f) == 2)
    }

    @Test("una partida vieja no hace nada")
    func legacyDoesNothing() async {
        let f = make(state: .legacy)
        f.store.newGameStarted()
        f.store.becameActive()
        await f.store.settled()
        #expect(await startRunCount(f) == 0)
        #expect(f.host.state?.phase == .ineligible)
    }

    @Test("sin config usable no hay red")
    func noConfigMeansNoNetwork() async {
        let off = RankingConfig(schemaVersion: 1, enabled: false, baseURL: nil, anonKey: nil)
        let f = make(config: off)
        f.store.newGameStarted()
        f.store.becameActive()
        await f.store.refreshBoard(mine: true)
        await f.store.settled()
        #expect(f.store.isEnabled == false)
        #expect(await f.simulated.calls.isEmpty)
    }

    // MARK: - Tiempo jugado

    @Test("el tiempo jugado suma las sesiones activas")
    func playedTimeAddsSessions() {
        let f = make(state: RankingState(phase: .running(runId: "r", serverStartedAt: 1_000)))
        f.clock.value = 0
        f.store.becameActive()
        f.clock.value = 100
        f.store.resignedActive()
        f.clock.value = 500
        f.store.becameActive()
        f.clock.value = 550
        f.store.resignedActive()
        #expect(f.host.state?.playedSeconds == 150)
    }

    // MARK: - Dios y el nombre

    @Test("Dios con red: sella, muestra el tiempo real y el nombre se acepta")
    func godWithNetwork() async {
        let f = make(state: .newGame)
        f.store.newGameStarted()
        await f.store.settled()
        f.clock.value = 5_000
        f.store.reachedGod()
        #expect(f.store.entryPrompt != nil)
        await f.store.settled()
        #expect(f.store.entryPrompt?.realSeconds == 5_000)

        await f.store.submit(name: "Juan")
        #expect(f.host.state?.submission?.nameStatus == .ok)
        #expect(f.host.state?.lastName == "Juan")
        #expect(f.store.entryPrompt == nil)
        #expect(f.store.isSubmitting == false)
    }

    @Test("Dios sin red: el sello y el nombre quedan pendientes y salen en orden")
    func godOfflineThenOnline() async {
        let f = make(state: runningState())
        await f.client.setOnline(false)
        f.store.reachedGod()
        await f.store.settled()
        #expect(f.host.state?.phase == .reachedGod(runId: Self.runA, serverStartedAt: 1_000, sealed: false))

        await f.store.submit(name: "Juan")
        #expect(f.host.state?.submission?.name == "Juan")
        #expect(f.host.state?.submission?.nameStatus == .missing)

        await f.client.setOnline(true)
        await f.store.pump()
        let finishes: [String?] = await f.simulated.calls.compactMap { call in
            if case .finishRun(let request) = call { request.name } else { nil }
        }
        #expect(finishes == [nil, "Juan"])
        #expect(await finishRuns(f).first?.playedSeconds == 120)
        #expect(f.host.state?.submission?.nameStatus == .ok)
    }

    @Test("un nombre rechazado reabre el campo y el segundo intento no cambia el tiempo real")
    func rejectedNameReopensTheField() async {
        let f = make(.rejectFirstName, state: runningState())
        f.store.reachedGod()
        await f.store.settled()
        let real = f.host.state?.submission?.realSeconds

        await f.store.submit(name: "Mala")
        #expect(f.store.nameError == .rejected)

        await f.store.submit(name: "Buena")
        #expect(f.host.state?.submission?.nameStatus == .ok)
        #expect(f.host.state?.submission?.realSeconds == real)
        #expect(f.store.entryPrompt == nil)
    }

    @Test("un nombre inválido no llama al cliente")
    func invalidNameStaysLocal() async {
        let f = make(state: runningState())
        f.store.reachedGod()
        await f.store.settled()
        let before = await f.simulated.calls.count

        await f.store.submit(name: "<b>")
        #expect(f.store.nameError == .invalid(.forbidden))
        #expect(await f.simulated.calls.count == before)
    }

    @Test("\"Ahora no\" cierra la tarjeta y el nombre se puede mandar después")
    func postponeThenSubmitFromTheTab() async {
        let f = make(state: runningState())
        f.store.reachedGod()
        await f.store.settled()
        f.store.postpone()
        #expect(f.store.entryPrompt == nil)
        #expect(f.host.state?.cardOffered == true)
        #expect(f.host.state?.pendingWork == RankingState.PendingWork.none)

        await f.store.submit(name: "Juan")
        #expect(f.host.state?.submission?.nameStatus == .ok)
    }

    @Test("un sello que el servidor rechaza da la partida por perdida")
    func refusedSealLosesTheRun() async {
        for error in [RankingError.notActive, .notOwner] {
            let f = make(state: runningState())
            await f.client.failFinish(with: error)
            f.store.reachedGod()
            await f.store.settled()
            #expect(f.host.state?.phase == .unregisteredGod)
        }
    }

    @Test("la tarjeta no se ofrece dos veces; se reconstruye si la llegada la encontró cerrada")
    func cardIsOfferedOnce() async {
        let f = make(state: runningState())
        f.store.reachedGod()
        await f.store.settled()
        #expect(f.store.entryPrompt != nil)
        f.store.postpone()
        f.store.becameActive()
        await f.store.settled()
        #expect(f.store.entryPrompt == nil)

        var arrived = runningState()
        arrived.reachedGod(at: 0)
        let g = make(state: arrived)
        g.store.becameActive()
        await g.store.settled()
        #expect(g.store.entryPrompt != nil)
        #expect(g.host.state?.cardOffered == true)
    }

    @Test("un rechazo desde la pestaña va a nameError y no reabre la tarjeta")
    func rejectionFromTheTabDoesNotReopenTheCard() async {
        let f = make(.rejectFirstName, state: runningState())
        f.store.reachedGod()
        await f.store.settled()
        f.store.postpone()
        await f.store.submit(name: "Mala")
        #expect(f.store.nameError == .rejected)
        #expect(f.store.entryPrompt == nil)
    }

    @Test("becameActive repetido no pisa el comienzo de la sesión")
    func repeatedActiveKeepsTheSessionStart() {
        let f = make(state: RankingState(phase: .running(runId: Self.runA, serverStartedAt: 1_000)))
        f.clock.value = 10
        f.store.becameActive()
        f.clock.value = 40
        f.store.becameActive()
        f.clock.value = 70
        f.store.resignedActive()
        #expect(f.host.state?.playedSeconds == 60)
    }

    @Test("el tablero se refresca al volver activo sólo pasados 60 segundos")
    func boardRefreshesAfterSixtySeconds() async {
        let f = make()
        func leaderboards() async -> Int {
            await f.simulated.calls.filter { if case .leaderboard = $0 { true } else { false } }.count
        }
        f.clock.value = 0
        f.store.becameActive()
        await f.store.settled()
        f.clock.value = 30
        f.store.becameActive()
        await f.store.settled()
        #expect(await leaderboards() == 1)
        f.clock.value = 61
        f.store.becameActive()
        await f.store.settled()
        #expect(await leaderboards() == 2)
    }

    @Test("una respuesta del tablero más vieja que la que ya hay se descarta")
    func staleBoardResponseIsDropped() async {
        let first = make()
        first.clock.value = 500
        await first.store.refreshBoard(mine: false)
        let second = make(cache: first.cache)
        second.clock.value = 0
        await second.store.refreshBoard(mine: false)
        #expect(second.store.board?.fetchedAt == 1_500)
        #expect(second.store.board?.isStale == true)
    }

    // MARK: - La llegada arrastrada por un reset

    @Test("la llegada arrastrada sale antes que el start-run nuevo y lleva el tiempo jugado")
    func carriedGoesBeforeTheNewStart() async {
        let f = make(state: runningState())
        await f.client.setOnline(false)
        f.store.reachedGod()
        await f.store.settled()
        f.host.state = f.host.state?.forNewGame()
        await f.client.setOnline(true)
        f.store.newGameStarted()
        await f.store.settled()
        let calls = await f.simulated.calls
        guard case .finishRun(let sent) = calls.first, case .startRun = calls.last else {
            Issue.record("orden inesperado: \(calls)")
            return
        }
        #expect(sent.runId == Self.runA)
        #expect(sent.playedSeconds == 120)
        #expect(f.host.state?.carriedSubmission == nil)
    }

    @Test("la llegada arrastrada se descarta con un cierre definitivo y se conserva sin red")
    func carriedDroppedOnDefinitiveErrorsKeptOffline() async {
        for error in [RankingError.notActive, .notOwner, .invalidName] {
            var state = RankingState.newGame
            state.carriedSubmission = .init(runId: Self.runB, sealed: true)
            let f = make(state: state)
            await f.client.failFinish(with: error)
            f.host.state?.carriedSubmission?.name = "Ana"
            f.store.becameActive()
            await f.store.settled()
            #expect(f.host.state?.carriedSubmission == nil)
        }
        var state = RankingState.newGame
        state.carriedSubmission = .init(runId: Self.runB, name: "Ana", sealed: false)
        let offline = make(state: state)
        await offline.client.setOnline(false)
        offline.store.becameActive()
        await offline.store.settled()
        #expect(offline.host.state?.carriedSubmission?.name == "Ana")
        #expect(offline.host.state?.phase == .awaitingStart)
        #expect(await startRunCount(offline) == 0)
    }

    @Test("un nombre que el servidor no acepta se suelta y la llegada se reintenta sin nombre")
    func carriedRetriesWithoutTheName() async {
        var state = RankingState.newGame
        state.carriedSubmission = .init(runId: Self.runB, name: "Ana", sealed: false, playedSeconds: 90)
        let f = make(state: state)
        await f.client.failFinish(with: .invalidName)
        f.store.becameActive()
        await f.store.settled()
        let sent = await finishRuns(f)
        #expect(sent.map(\.name) == ["Ana", nil])
        #expect(sent.map(\.playedSeconds) == [90, 90])
        #expect(f.host.state?.carriedSubmission == nil)
    }

    @Test("una llegada ya sellada y sin nombre se descarta sin red; con nombre pendiente no frena el start")
    func sealedCarriedRules() async {
        var bare = RankingState.newGame
        bare.carriedSubmission = .init(runId: Self.runB, sealed: true)
        let a = make(state: bare)
        a.store.becameActive()
        await a.store.settled()
        #expect(a.host.state?.carriedSubmission == nil)
        #expect(await finishRuns(a).isEmpty)

        var named = RankingState.newGame
        named.carriedSubmission = .init(runId: Self.runB, name: "Ana", sealed: true)
        let b = make(state: named)
        await b.client.failFinish(with: .retryLater)
        b.store.becameActive()
        await b.store.settled()
        #expect(b.host.state?.carriedSubmission != nil)
        guard case .running = b.host.state?.phase else {
            Issue.record("el start no debía quedar frenado")
            return
        }
    }

    // MARK: - Respuestas viejas (un reset con el pedido en vuelo)

    @Test("un reset con el start-run en vuelo no registra la partida vieja en la nueva")
    func resetDuringStartDoesNotRegisterTheOldAttempt() async {
        let f = make()
        await f.client.hold()
        f.store.newGameStarted()
        await waitForEntered(f, 1)
        let first = f.host.state?.clientRunId
        f.host.state = f.host.state?.forNewGame()
        f.store.newGameStarted()
        await f.client.release()
        await f.store.settled()
        let sent = await f.simulated.calls.compactMap { call -> String? in
            if case .startRun(let request) = call { request.clientRunId } else { nil }
        }
        #expect(sent.count == 2)
        #expect(sent.first == first)
        #expect(sent.first != sent.last)
    }

    @Test("un reset con el sello en vuelo no sella la partida nueva")
    func resetDuringSealDoesNotSealTheNewGame() async {
        let f = make(state: runningState())
        await f.client.hold()
        f.store.reachedGod()
        await waitForEntered(f, 1)
        f.host.state = f.host.state?.forNewGame()
        await f.client.release()
        await f.store.settled()
        #expect(f.host.state?.submission == nil)
        guard case .running = f.host.state?.phase else {
            Issue.record("la partida nueva debía quedar corriendo")
            return
        }
    }

    // MARK: - Tablero

    @Test("sin red el tablero viene de la caché, marcado viejo")
    func boardComesFromTheCacheWhenOffline() async {
        let first = make()
        await first.store.refreshBoard(mine: false)
        #expect(first.store.board?.isStale == false)
        #expect(first.store.board?.myRank == 7)

        let second = make(.offline, cache: first.cache)
        #expect(second.store.board?.isStale == true)
        #expect(second.store.board?.top.count == 10)
        await second.store.refreshBoard(mine: false)
        #expect(second.store.board?.isStale == true)
    }

    @Test("mine trae mis partidas")
    func mineFillsMyRuns() async {
        let f = make()
        await f.store.refreshBoard(mine: true)
        #expect(f.store.myRuns.isEmpty)
        #expect(await f.simulated.calls == [.leaderboard(LeaderboardRequest(mine: true))])
    }

    // MARK: - 503

    @Test("un 503 apaga el ranking hasta el próximo arranque")
    func disabledTurnsTheStoreOff() async {
        let f = make(.disabled)
        f.store.newGameStarted()
        await f.store.settled()
        #expect(f.store.isEnabled == false)
        await f.store.refreshBoard(mine: false)
        #expect(await f.simulated.calls.count == 1)
    }
}
