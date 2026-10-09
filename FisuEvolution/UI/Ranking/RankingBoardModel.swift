import EconomyKit
import Foundation

/// Lo que dibuja la pestaña del ranking, ya resuelto: la vista no decide nada, sólo lo pinta.
struct RankingBoardModel: Equatable {
    /// El gancho de arriba. Sólo la partida en curso compite; las demás fases dicen por qué no.
    enum Hook: Equatable {
        case none
        /// Hay diez o más filas: la meta es el puesto 10.
        case chase(mine: Int, tenth: Int)
        /// Hay menos de diez: la meta es el último del ranking.
        case last(mine: Int, last: Int)
        case first
        case legacy
        case unregistered
    }

    let isEnabled: Bool
    let top: [LeaderboardRow]
    /// La propia, cuando no está entre las del top: va fija abajo con su puesto.
    let pinned: LeaderboardRow?
    let hook: Hook
    let isStale: Bool
    let fetchedAt: TimeInterval?
    /// La llegada a Dios que todavía no tiene nombre enviado (se posterga desde la tarjeta o se rechazó).
    let pendingEntry: EntryPrompt?

    init(
        board: BoardSnapshot?, state: RankingState?, isEnabled: Bool = true,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.isEnabled = isEnabled
        let rows = board?.top ?? []
        top = rows
        pinned = board?.me.flatMap { me in rows.contains { $0.runId == me.runId } ? nil : me }
        isStale = board?.isStale ?? false
        fetchedAt = board?.fetchedAt
        hook = Self.hook(top: rows, state: state, now: now)
        pendingEntry = Self.pendingEntry(state)
    }

    var isEmpty: Bool { top.isEmpty }

    private static let chaseRank = 10

    private static func hook(top: [LeaderboardRow], state: RankingState?, now: TimeInterval) -> Hook {
        guard let state else { return .none }
        switch state.phase {
        case .ineligible:
            return .legacy
        case .awaitingStart:
            return .unregistered
        case .running(_, let startedAt):
            let mine = Int(max(0, now - startedAt))
            if top.count >= chaseRank { return .chase(mine: mine, tenth: top[chaseRank - 1].realSeconds) }
            if let last = top.last { return .last(mine: mine, last: last.realSeconds) }
            return .first
        case .reachedGod, .unregisteredGod:
            return .none
        }
    }

    private static func pendingEntry(_ state: RankingState?) -> EntryPrompt? {
        guard let state, case .reachedGod = state.phase else { return nil }
        let submission = state.submission
        switch submission?.nameStatus {
        case .ok?, .pending?:
            return nil
        case .rejected?, .missing?, nil:
            guard submission?.name == nil || submission?.nameStatus == .rejected else { return nil }
            return EntryPrompt(
                realSeconds: submission?.realSeconds, underReview: submission?.underReview ?? false,
                lastName: state.lastName)
        }
    }
}
