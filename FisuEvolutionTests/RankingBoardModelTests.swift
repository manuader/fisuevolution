import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El modelo de la pestaña del ranking")
struct RankingBoardModelTests {
    private func row(_ rank: Int, name: String? = "Fisu", real: Int = 100_000, isMe: Bool = false) -> LeaderboardRow {
        LeaderboardRow(runId: "run-\(rank)", rank: rank, name: name, realSeconds: real, playedSeconds: real / 2, isMe: isMe)
    }

    private func board(
        top: [LeaderboardRow], me: LeaderboardRow? = nil, stale: Bool = false
    ) -> BoardSnapshot {
        BoardSnapshot(top: top, me: me, myRank: me?.rank, fetchedAt: 1_000, isStale: stale)
    }

    private func running(since started: TimeInterval = 0) -> RankingState {
        RankingState(phase: .running(runId: "mine", serverStartedAt: started))
    }

    @Test func theOwnRowInsideTheTopIsNotPinned() {
        let top = (1...5).map { row($0, isMe: $0 == 3) }
        let model = RankingBoardModel(board: board(top: top, me: top[2]), state: running())
        #expect(model.top == top)
        #expect(model.pinned == nil)
    }

    @Test func theOwnRowOutsideTheTopIsPinnedWithItsRank() {
        let top = (1...5).map { row($0) }
        let me = row(214, name: "Yo", isMe: true)
        let model = RankingBoardModel(board: board(top: top, me: me), state: running())
        #expect(model.pinned == me)
        #expect(model.pinned?.rank == 214)
    }

    @Test func withTenOrMoreRowsTheHookChasesTheTenth() {
        let top = (1...12).map { row($0, real: 10_000 * $0) }
        let model = RankingBoardModel(board: board(top: top), state: running(since: 1_000), now: 4_600)
        #expect(model.hook == .chase(mine: 3_600, tenth: 100_000))
    }

    @Test func withFewerThanTenRowsTheHookChasesTheLast() {
        let top = (1...4).map { row($0, real: 10_000 * $0) }
        let model = RankingBoardModel(board: board(top: top), state: running(), now: 60)
        #expect(model.hook == .last(mine: 60, last: 40_000))
    }

    @Test func withNoRowsTheHookInvitesToBeFirst() {
        let model = RankingBoardModel(board: board(top: []), state: running())
        #expect(model.hook == .first)
        #expect(model.isEmpty)
    }

    @Test func aRunningGameBeforeItsStartNeverGoesNegative() {
        let model = RankingBoardModel(board: board(top: []), state: running(since: 5_000), now: 100)
        #expect(model.hook == .first)
        let chase = RankingBoardModel(board: board(top: (1...10).map { row($0) }), state: running(since: 5_000), now: 100)
        #expect(chase.hook == .chase(mine: 0, tenth: 100_000))
    }

    @Test func aLegacyGameSaysWhyItDoesNotCompete() {
        #expect(RankingBoardModel(board: nil, state: .legacy).hook == .legacy)
    }

    @Test func anUnregisteredGameSaysItWaitsForConnection() {
        #expect(RankingBoardModel(board: nil, state: .newGame).hook == .unregistered)
    }

    @Test func noStateOrAReachedGodHasNoHook() {
        #expect(RankingBoardModel(board: nil, state: nil).hook == .none)
        let god = RankingState(phase: .reachedGod(runId: "mine", serverStartedAt: 0, sealed: true))
        #expect(RankingBoardModel(board: nil, state: god).hook == .none)
    }

    @Test func staleAndFetchTimeComeFromTheSnapshot() {
        let model = RankingBoardModel(board: board(top: [], stale: true), state: nil)
        #expect(model.isStale)
        #expect(model.fetchedAt == 1_000)
        #expect(RankingBoardModel(board: nil, state: nil).isStale == false)
    }

    @Test func aPostponedArrivalLeavesAPendingEntry() {
        var state = RankingState(phase: .reachedGod(runId: "mine", serverStartedAt: 0, sealed: true))
        state.submission = .init(realSeconds: 9_000, underReview: true)
        state.lastName = "Fisu"
        let pending = RankingBoardModel(board: nil, state: state).pendingEntry
        #expect(pending == EntryPrompt(realSeconds: 9_000, underReview: true, lastName: "Fisu"))
    }

    @Test func aSentOrInFlightNameLeavesNoPendingEntry() {
        var state = RankingState(phase: .reachedGod(runId: "mine", serverStartedAt: 0, sealed: true))
        state.submission = .init(name: "Fisu", nameStatus: .missing, realSeconds: 9_000)
        #expect(RankingBoardModel(board: nil, state: state).pendingEntry == nil)
        state.submission = .init(name: "Fisu", nameStatus: .ok, realSeconds: 9_000)
        #expect(RankingBoardModel(board: nil, state: state).pendingEntry == nil)
        state.submission = .init(name: "Fisu", nameStatus: .pending, realSeconds: 9_000)
        #expect(RankingBoardModel(board: nil, state: state).pendingEntry == nil)
    }

    @Test func aRejectedNameAsksForAnotherOne() {
        var state = RankingState(phase: .reachedGod(runId: "mine", serverStartedAt: 0, sealed: true))
        state.submission = .init(name: "Mal", nameStatus: .rejected, realSeconds: 9_000)
        #expect(RankingBoardModel(board: nil, state: state).pendingEntry != nil)
    }

    @Test func aRunningGameHasNoPendingEntry() {
        #expect(RankingBoardModel(board: nil, state: running()).pendingEntry == nil)
    }

    @Test func aNilNameShowsAsAnonymous() throws {
        let path = try #require(Bundle.main.path(forResource: "es", ofType: "lproj"))
        let es = try #require(Bundle(path: path))
        #expect(RankingCopy.displayName(nil, bundle: es) == "Anónimo")
        #expect(RankingCopy.displayName("%@ Fisu", bundle: es) == "%@ Fisu")
    }
}
