import EconomyKit
import Foundation
import Observation
import OSLog

/// Quien guarda el `RankingState` de la partida (el `GameState`, en la app; un doble, en los tests).
@MainActor protocol RankingStateHost: AnyObject {
    var rankingState: RankingState? { get }
    var godTier: Int? { get }
    /// Muta `meta.ranking` y agenda el guardado.
    func updateRanking(_ change: (inout RankingState) -> Void)
}

struct BoardSnapshot: Codable, Sendable, Equatable {
    var top: [LeaderboardRow]
    var me: LeaderboardRow?
    var myRank: Int?
    var fetchedAt: TimeInterval
    /// Verdadero hasta el primer refresco bueno (o tras uno fallido): lo que se ve puede estar viejo.
    var isStale: Bool
}

/// La tarjeta de llegada a Dios: el tiempo real, si quedó en revisión, el último nombre y el error del campo.
struct EntryPrompt: Equatable, Sendable {
    enum NameError: Equatable, Sendable {
        case invalid(NameRules.Rejection)
        case rejected
    }

    var realSeconds: Int?
    var underReview: Bool
    var lastName: String?
    var error: NameError?
}

/// El estado observable del ranking y quien habla con el servidor. El `RankingState` vive en el
/// guardado (vía el `host`); acá sólo está lo que se muestra y la lógica de reintento.
///
/// Sin config usable (hasta el despliegue real) no hace red: es un no-op limpio.
@MainActor @Observable
final class RankingStore {
    private static let log = Logger(subsystem: "com.adergames.fisu", category: "ranking")
    private static let boardRefreshInterval: TimeInterval = 60
    private static let maxStepsPerPump = 6

    @ObservationIgnored weak var host: (any RankingStateHost)?

    private(set) var board: BoardSnapshot?
    private(set) var myRuns: [MyRun] = []
    private(set) var isEnabled: Bool
    private(set) var entryPrompt: EntryPrompt?
    private(set) var isSubmitting = false

    @ObservationIgnored private let client: any RankingClient
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let appVersion: String
    @ObservationIgnored private let makeID: () -> String
    @ObservationIgnored private let cacheURL: URL
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var lastBoardRefresh: TimeInterval?
    @ObservationIgnored private var pumpTask: Task<Void, Never>?
    @ObservationIgnored private var pumpAgain = false
    @ObservationIgnored private var scheduled: [Task<Void, Never>] = []

    init(
        client: any RankingClient,
        config: RankingConfig,
        now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        makeID: @escaping () -> String = { UUID().uuidString.lowercased() },
        cacheURL: URL = RankingStore.defaultCacheURL
    ) {
        self.client = client
        self.now = now
        self.appVersion = appVersion
        self.makeID = makeID
        self.cacheURL = cacheURL
        isEnabled = config.isUsable
        board = Self.loadCache(at: cacheURL)
    }

    static var defaultCacheURL: URL {
        URL.cachesDirectory.appending(path: "ranking-board.json")
    }

    /// Falso bajo XCTest y `--uitest*`: ahí el ranking nunca toca la red real.
    nonisolated static var isLive: Bool {
        NotificationsManager.launchAllowsSystem(arguments: ProcessInfo.processInfo.arguments)
    }

    /// HTTP si estamos en vivo y la config es usable; con `--uitest-ranking-<escenario>`, el servidor
    /// de mentira; si no, un store apagado (sin config no hace red).
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> RankingStore {
        if let scenario = SimulatedRankingClient.scenario(from: arguments) {
            let simulated = RankingConfig(
                schemaVersion: RankingConfig.supportedSchemaVersion, enabled: true,
                baseURL: URL(string: "https://simulated.invalid"), anonKey: "simulated")
            return RankingStore(client: SimulatedRankingClient(scenario: scenario), config: simulated)
        }
        let config = RankingConfigLoader().current()?.config
        if isLive, let config, config.isUsable {
            return RankingStore(client: HTTPRankingClient(config: config, identity: InstallIdentity()), config: config)
        }
        let off = RankingConfig(
            schemaVersion: RankingConfig.supportedSchemaVersion, enabled: false, baseURL: nil, anonKey: nil)
        return RankingStore(client: SimulatedRankingClient(), config: off)
    }

    // MARK: - Eventos del ciclo de vida

    /// La partida nueva (o el reset, después de `forNewGame()`): si quedó sin registrar, se registra.
    func newGameStarted() {
        guard let state = host?.rankingState, state.phase == .awaitingStart else { return }
        entryPrompt = nil
        if isActive { host?.updateRanking { $0.sessionBegan(at: now()) } }
        schedulePump()
    }

    func becameActive() {
        isActive = true
        host?.updateRanking { $0.sessionBegan(at: now()) }
        schedulePump()
        if lastBoardRefresh.map({ now() - $0 >= Self.boardRefreshInterval }) ?? true {
            schedule { await $0.refreshBoard(mine: false) }
        }
    }

    func resignedActive() {
        isActive = false
        host?.updateRanking { $0.sessionEnded(at: now()) }
    }

    func reachedGod() {
        var changed = false
        host?.updateRanking { changed = $0.reachedGod(at: now()) }
        guard changed, let state = host?.rankingState, case .reachedGod = state.phase else { return }
        if !state.cardOffered {
            host?.updateRanking { $0.cardWasOffered() }
            entryPrompt = prompt(for: state, error: nil)
        }
        schedulePump()
    }

    // MARK: - El nombre

    func submit(name: String) async {
        guard let state = host?.rankingState, case .reachedGod = state.phase else { return }
        switch NameRules.validate(name) {
        case .failure(let rejection):
            entryPrompt = prompt(for: state, error: .invalid(rejection))
        case .success(let valid):
            var chosen = false
            host?.updateRanking { chosen = $0.nameChosen(valid) }
            guard chosen else { return }
            entryPrompt = entryPrompt.map { var kept = $0; kept.error = nil; return kept }
            isSubmitting = true
            await pump()
            isSubmitting = false
            settlePrompt()
        }
    }

    /// "Ahora no": la tarjeta no vuelve a saltar; el nombre queda para la pestaña.
    func postpone() {
        host?.updateRanking { $0.postponed() }
        entryPrompt = nil
    }

    // MARK: - El tablero

    func refreshBoard(mine: Bool) async {
        guard isEnabled else { return }
        do {
            let response = try await client.leaderboard(LeaderboardRequest(mine: mine))
            lastBoardRefresh = now()
            let snapshot = BoardSnapshot(
                top: response.top, me: response.me, myRank: response.myRank,
                fetchedAt: response.fetchedAt, isStale: false)
            board = snapshot
            if let runs = response.mine { myRuns = runs }
            Self.saveCache(snapshot, at: cacheURL)
        } catch {
            board?.isStale = true
            note(error)
        }
    }

    @discardableResult
    func report(runId: String) async -> Bool {
        guard isEnabled else { return false }
        do {
            try await client.report(ReportRequest(runId: runId))
            return true
        } catch {
            note(error)
            return false
        }
    }

    // MARK: - Los pedidos pendientes

    /// Hace lo que diga `pendingWork`, de a un pedido por vez. Un solo recorrido en vuelo: el que llega
    /// mientras tanto lo pide de nuevo y espera al mismo. Sin red queda para la próxima vuelta.
    func pump() async {
        if let running = pumpTask {
            pumpAgain = true
            await running.value
            return
        }
        let task = Task { [self] in
            repeat {
                pumpAgain = false
                if await runPump() == false { pumpAgain = false }
            } while pumpAgain
            pumpTask = nil
        }
        pumpTask = task
        await task.value
    }

    /// Espera lo que `newGameStarted`, `becameActive` y `reachedGod` dejaron en marcha.
    func settled() async {
        while let next = scheduled.first {
            await next.value
            scheduled.removeFirst()
        }
    }

    private func schedulePump() {
        schedule { await $0.pump() }
    }

    private func schedule(_ work: @escaping @MainActor (RankingStore) async -> Void) {
        scheduled.append(Task { await work(self) })
    }

    /// Devuelve si terminó sin error (si no, no tiene sentido insistir en este mismo recorrido).
    private func runPump() async -> Bool {
        guard isEnabled else { return true }
        for _ in 0..<Self.maxStepsPerPump {
            guard let state = host?.rankingState else { return true }
            if let carried = state.carriedSubmission {
                guard await sendCarried(carried) else { return false }
                continue
            }
            switch state.pendingWork {
            case .none:
                settlePrompt()
                return true
            case .start:
                guard await register() else { return false }
            case .seal:
                guard await seal() else { return false }
            case .name(let name):
                guard await sendName(name) else { return false }
            }
        }
        return true
    }

    private func register() async -> Bool {
        host?.updateRanking { _ = $0.startAttemptId(make: makeID) }
        guard let id = host?.rankingState?.clientRunId else { return false }
        do {
            let response = try await client.startRun(StartRunRequest(appVersion: appVersion, clientRunId: id))
            host?.updateRanking {
                if $0.clientRunId == id { $0.registered(runId: response.runId, serverStartedAt: response.startedAt) }
            }
            return true
        } catch {
            note(error)
            return false
        }
    }

    private func seal() async -> Bool {
        guard let state = host?.rankingState, let runId = state.phase.rankedRunId else { return true }
        do {
            let response = try await client.finishRun(FinishRunRequest(
                runId: runId, playedSeconds: Int(state.playedSeconds.rounded()), name: nil))
            host?.updateRanking {
                if $0.phase.rankedRunId == runId {
                    $0.sealed(realSeconds: response.realSeconds, underReview: response.status == .review,
                              nameStatus: response.nameStatus)
                }
            }
            return true
        } catch {
            if error == .notActive || error == .notOwner {
                Self.log.error("el sello fue rechazado (\(String(describing: error))): la partida no compite")
                host?.updateRanking { $0.phase = .unregisteredGod }
                return true
            }
            note(error)
            return false
        }
    }

    private func sendName(_ name: String) async -> Bool {
        guard let state = host?.rankingState, let runId = state.phase.rankedRunId else { return true }
        do {
            let response = try await client.finishRun(FinishRunRequest(
                runId: runId, playedSeconds: Int(state.playedSeconds.rounded()), name: name))
            host?.updateRanking {
                if $0.phase.rankedRunId == runId {
                    $0.nameAnswered(name, status: response.nameStatus, rank: response.rank)
                }
            }
            if response.nameStatus == .rejected { settlePrompt(error: .rejected) }
            return true
        } catch {
            switch error {
            case .invalidName:
                host?.updateRanking { $0.nameAnswered(name, status: .rejected, rank: nil) }
                settlePrompt(error: .rejected)
                return true
            case .notActive, .notOwner:
                host?.updateRanking { $0.phase = .unregisteredGod }
                return true
            default:
                note(error)
                return false
            }
        }
    }

    /// Una llegada que el reset encontró sin enviar. Reenviarla es idempotente: lo definitivo la descarta.
    private func sendCarried(_ carried: RankingState.CarriedSubmission) async -> Bool {
        do {
            _ = try await client.finishRun(FinishRunRequest(runId: carried.runId, playedSeconds: 0, name: carried.name))
            host?.updateRanking { $0.carriedSubmissionSent() }
            return true
        } catch {
            if error == .notActive || error == .notOwner || error == .invalidName {
                host?.updateRanking { $0.carriedSubmissionSent() }
                return true
            }
            note(error)
            return false
        }
    }

    // MARK: - Lo que se muestra

    private func prompt(for state: RankingState, error: EntryPrompt.NameError?) -> EntryPrompt {
        EntryPrompt(
            realSeconds: state.submission?.realSeconds, underReview: state.submission?.underReview ?? false,
            lastName: state.lastName, error: error)
    }

    /// Pone la tarjeta al día con el estado: cierra la tarjeta si el nombre ya salió, o lo muestra rechazado.
    private func settlePrompt(error: EntryPrompt.NameError? = nil) {
        guard let current = entryPrompt, let state = host?.rankingState else { return }
        guard case .reachedGod = state.phase else {
            entryPrompt = nil
            return
        }
        switch state.submission?.nameStatus {
        case .ok?, .pending?:
            entryPrompt = nil
        case .rejected?:
            entryPrompt = prompt(for: state, error: .rejected)
        default:
            if state.submission?.name != nil {
                entryPrompt = nil
            } else {
                var updated = prompt(for: state, error: error ?? current.error)
                updated.error = error ?? current.error
                entryPrompt = updated
            }
        }
    }

    private func note(_ error: RankingError) {
        if error == .disabled { isEnabled = false }
    }

    // MARK: - La caché del tablero

    private static func loadCache(at url: URL) -> BoardSnapshot? {
        guard let data = try? Data(contentsOf: url),
              var snapshot = try? JSONDecoder().decode(BoardSnapshot.self, from: data) else { return nil }
        snapshot.isStale = true
        return snapshot
    }

    private static func saveCache(_ snapshot: BoardSnapshot, at url: URL) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private extension RankingState.Phase {
    var rankedRunId: String? {
        if case .reachedGod(let id, _, _) = self { return id }
        return nil
    }
}
