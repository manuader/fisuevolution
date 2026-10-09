import Foundation

/// La partida rankeada (E12): desde el núcleo del tutorial (o el reset) hasta Dios, a través de
/// todas las reencarnaciones. NO es `RunState`: `runId` es el id de la tabla `runs` del servidor.
///
/// Crece con `decodeIfPresent ?? default` y su regla en `resolve`, sin subir el schema del save.
public struct RankingState: Codable, Sendable, Equatable {
    public enum Phase: Codable, Sendable, Equatable {
        /// Partida empezada antes de la 2.0: no compite hasta resetear.
        case ineligible
        /// Partida nueva sin registrar todavía (sin red, o antes del núcleo del tutorial).
        case awaitingStart
        case running(runId: String, serverStartedAt: TimeInterval)
        /// Llegó a Dios. `sealed` = el servidor ya anotó la hora de llegada.
        case reachedGod(runId: String, serverStartedAt: TimeInterval, sealed: Bool)
        /// Llegó a Dios sin haber podido registrar nunca la partida: no compite.
        case unregisteredGod
    }

    public enum NameStatus: String, Codable, Sendable { case ok, pending, rejected, missing }

    /// `name != nil` con `nameStatus == .missing` es un nombre elegido que todavía no se envió.
    public struct Submission: Codable, Sendable, Equatable {
        public var name: String?
        public var nameStatus: NameStatus
        public var realSeconds: Int?
        public var underReview: Bool
        public var rank: Int?

        public init(name: String? = nil, nameStatus: NameStatus = .missing, realSeconds: Int? = nil,
                    underReview: Bool = false, rank: Int? = nil) {
            self.name = name
            self.nameStatus = nameStatus
            self.realSeconds = realSeconds
            self.underReview = underReview
            self.rank = rank
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            nameStatus = try c.decodeIfPresent(NameStatus.self, forKey: .nameStatus) ?? .missing
            realSeconds = try c.decodeIfPresent(Int.self, forKey: .realSeconds)
            underReview = try c.decodeIfPresent(Bool.self, forKey: .underReview) ?? false
            rank = try c.decodeIfPresent(Int.self, forKey: .rank)
        }
    }

    /// Una llegada a Dios que el reset encontró sin enviar: se conserva para no perderla.
    public struct CarriedSubmission: Codable, Sendable, Equatable {
        public var runId: String
        public var name: String?
        /// El servidor ya anotó la llegada: sólo falta el nombre (si lo hay).
        public var sealed: Bool
        /// El tiempo jugado de esa partida: el servidor sella con este valor si todavía no la selló.
        public var playedSeconds: Int

        public init(runId: String, name: String? = nil, sealed: Bool = false, playedSeconds: Int = 0) {
            self.runId = runId
            self.name = name
            self.sealed = sealed
            self.playedSeconds = playedSeconds
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            runId = try c.decode(String.self, forKey: .runId)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            sealed = try c.decodeIfPresent(Bool.self, forKey: .sealed) ?? false
            playedSeconds = try c.decodeIfPresent(Int.self, forKey: .playedSeconds) ?? 0
        }
    }

    public enum PendingWork: Sendable, Equatable {
        case start
        case seal
        case name(String)
        case none
    }

    public var phase: Phase
    /// Segundos con la app en `.active` en esta partida. Sólo se muestra.
    public var playedSeconds: Double
    /// Inicio de la sesión `.active` en curso. Si la app se cierra a la fuerza queda huérfano:
    /// el próximo `sessionBegan` lo pisa y esa sesión no se cuenta.
    public var activeSince: TimeInterval?
    public var submission: Submission?
    public var lastName: String?
    /// La tarjeta de Dios ya se ofreció en esta partida (no vuelve a saltar; queda la pestaña).
    public var cardOffered: Bool
    public var carriedSubmission: CarriedSubmission?
    /// El id que el cliente genera una vez por partida nueva o reset: reenviarlo hace idempotente al `start-run`.
    public var clientRunId: String?

    public static let legacy = RankingState(phase: .ineligible)
    public static let newGame = RankingState(phase: .awaitingStart)

    public init(phase: Phase, playedSeconds: Double = 0, activeSince: TimeInterval? = nil,
                submission: Submission? = nil, lastName: String? = nil, cardOffered: Bool = false,
                carriedSubmission: CarriedSubmission? = nil, clientRunId: String? = nil) {
        self.phase = phase
        self.playedSeconds = playedSeconds
        self.activeSince = activeSince
        self.submission = submission
        self.lastName = lastName
        self.cardOffered = cardOffered
        self.carriedSubmission = carriedSubmission
        self.clientRunId = clientRunId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decodeIfPresent(Phase.self, forKey: .phase) ?? .ineligible
        playedSeconds = try c.decodeIfPresent(Double.self, forKey: .playedSeconds) ?? 0
        activeSince = try c.decodeIfPresent(TimeInterval.self, forKey: .activeSince)
        submission = try c.decodeIfPresent(Submission.self, forKey: .submission)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        cardOffered = try c.decodeIfPresent(Bool.self, forKey: .cardOffered) ?? false
        carriedSubmission = try c.decodeIfPresent(CarriedSubmission.self, forKey: .carriedSubmission)
        clientRunId = try c.decodeIfPresent(String.self, forKey: .clientRunId)
    }

    // MARK: - Transiciones (puras; devuelven si cambió algo las que pueden no hacer nada)

    /// El id con el que se (re)intenta el `start-run`: nace al primer intento y se reusa hasta que el servidor responde.
    public mutating func startAttemptId(make: () -> String) -> String {
        if let clientRunId { return clientRunId }
        let id = make()
        clientRunId = id
        return id
    }

    @discardableResult
    public mutating func registered(runId: String, serverStartedAt: TimeInterval) -> Bool {
        guard phase == .awaitingStart else { return false }
        phase = .running(runId: runId, serverStartedAt: serverStartedAt)
        clientRunId = nil
        return true
    }

    public mutating func sessionBegan(at now: TimeInterval) {
        activeSince = countsPlayTime ? now : nil
    }

    public mutating func sessionEnded(at now: TimeInterval) {
        guard let since = activeSince else { return }
        activeSince = nil
        playedSeconds += max(0, now - since)
    }

    /// Cierra la sesión en curso (el tiempo jugado queda fijo desde Dios).
    @discardableResult
    public mutating func reachedGod(at now: TimeInterval) -> Bool {
        switch phase {
        case .running(let runId, let startedAt):
            sessionEnded(at: now)
            phase = .reachedGod(runId: runId, serverStartedAt: startedAt, sealed: false)
            return true
        case .awaitingStart:
            sessionEnded(at: now)
            phase = .unregisteredGod
            return true
        case .ineligible, .reachedGod, .unregisteredGod:
            return false
        }
    }

    /// El servidor anotó la llegada. Los tiempos quedan fijos: un segundo sello no los pisa.
    public mutating func sealed(realSeconds: Int, underReview: Bool, nameStatus: NameStatus) {
        guard case .reachedGod(let runId, let startedAt, let alreadySealed) = phase else { return }
        phase = .reachedGod(runId: runId, serverStartedAt: startedAt, sealed: true)
        guard !alreadySealed else { return }
        var current = submission ?? Submission()
        current.realSeconds = realSeconds
        current.underReview = underReview
        if nameStatus != .missing { current.nameStatus = nameStatus }
        submission = current
    }

    /// Un nombre válido que el jugador eligió y falta mandar (o reemplazo de uno rechazado).
    @discardableResult
    public mutating func nameChosen(_ name: String) -> Bool {
        guard case .reachedGod = phase else { return false }
        var current = submission ?? Submission()
        guard current.nameStatus == .missing || current.nameStatus == .rejected else { return false }
        current.name = name
        current.nameStatus = .missing
        submission = current
        return true
    }

    /// La respuesta del servidor al nombre. `ok` lo guarda como `lastName` para el próximo intento.
    public mutating func nameAnswered(_ name: String, status: NameStatus, rank: Int?) {
        guard case .reachedGod(_, _, true) = phase else { return }
        var current = submission ?? Submission()
        current.name = name
        current.nameStatus = status
        current.rank = rank
        submission = current
        if status == .ok { lastName = name }
    }

    /// "Ahora no": la tarjeta no vuelve a saltar; el nombre se completa desde la pestaña.
    public mutating func postponed() {
        cardOffered = true
    }

    public mutating func cardWasOffered() {
        cardOffered = true
    }

    public mutating func carriedSubmissionSent() {
        carriedSubmission = nil
    }

    /// Lo que el store tiene que mandar: start, sello, nombre pendiente, o nada.
    public var pendingWork: PendingWork {
        switch phase {
        case .awaitingStart:
            return .start
        case .reachedGod(_, _, false):
            return .seal
        case .reachedGod(_, _, true):
            if let submission, submission.nameStatus == .missing, let name = submission.name {
                return .name(name)
            }
            return .none
        case .ineligible, .running, .unregisteredGod:
            return .none
        }
    }

    /// Lo que sobrevive a un reset: `lastName`, y una llegada a Dios aún sin enviar (en
    /// `carriedSubmission`). La partida nueva arranca en `.awaitingStart`, sin sesión abierta:
    /// el que resetea llama a `sessionBegan`.
    public func forNewGame() -> RankingState {
        var fresh = RankingState.newGame
        fresh.lastName = lastName
        fresh.carriedSubmission = unsentArrival ?? carriedSubmission
        return fresh
    }

    private var unsentArrival: CarriedSubmission? {
        guard case .reachedGod(let runId, _, let sealed) = phase else { return nil }
        let played = Int(playedSeconds.rounded())
        switch submission?.nameStatus {
        case .ok?, .pending?: return nil
        case .rejected?: return CarriedSubmission(runId: runId, sealed: sealed, playedSeconds: played)
        default: return CarriedSubmission(runId: runId, name: submission?.name, sealed: sealed, playedSeconds: played)
        }
    }

    // MARK: - Conflicto entre dispositivos

    /// Con la misma partida (mismo `runId`) gana la fase más avanzada y se funden los datos
    /// (tiempo jugado máximo, sello, el nombre aceptado antes que el que no). Con partidas
    /// distintas manda el `winner` entero, aunque el otro tenga una fase más avanzada: una
    /// partida vieja no se vuelve elegible por un conflicto. La llegada a Dios sin enviar del
    /// perdedor pasa a `carriedSubmission` (sin pisar una ya cargada).
    public static func resolve(winner: RankingState, loser: RankingState) -> RankingState {
        guard winner.phase.isSameGame(as: loser.phase) else {
            var merged = winner
            merged.lastName = winner.lastName ?? loser.lastName
            merged.carriedSubmission = winner.carriedSubmission ?? loser.unsentArrival ?? loser.carriedSubmission
            return merged
        }
        let (base, other) = loser.phase.stage > winner.phase.stage ? (loser, winner) : (winner, loser)
        var merged = base
        merged.lastName = base.lastName ?? other.lastName
        merged.carriedSubmission = base.carriedSubmission ?? other.carriedSubmission
        merged.playedSeconds = max(base.playedSeconds, other.playedSeconds)
        merged.cardOffered = base.cardOffered || other.cardOffered
        if case .reachedGod(let runId, let startedAt, _) = base.phase,
           base.phase.isSealed || other.phase.isSealed {
            merged.phase = .reachedGod(runId: runId, serverStartedAt: startedAt, sealed: true)
        }
        if other.submission?.nameStatus == .ok, base.submission?.nameStatus != .ok {
            merged.submission = other.submission
        } else {
            merged.submission = base.submission ?? other.submission
        }
        return merged
    }

    private var countsPlayTime: Bool {
        switch phase {
        case .awaitingStart, .running: true
        case .ineligible, .reachedGod, .unregisteredGod: false
        }
    }
}

private extension RankingState.Phase {
    var stage: Int {
        switch self {
        case .ineligible: 0
        case .awaitingStart: 1
        case .running: 2
        case .reachedGod, .unregisteredGod: 3
        }
    }

    var runId: String? {
        switch self {
        case .running(let id, _), .reachedGod(let id, _, _): id
        case .ineligible, .awaitingStart, .unregisteredGod: nil
        }
    }

    var isSealed: Bool {
        if case .reachedGod(_, _, true) = self { return true }
        return false
    }

    func isSameGame(as other: Self) -> Bool {
        if runId != nil || other.runId != nil { return runId == other.runId }
        return stage == other.stage
    }
}
