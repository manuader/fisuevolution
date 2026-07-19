import Foundation
import Testing
@testable import EconomyKit

@Suite("SaveConflictResolver (sync CloudKit)")
struct SaveConflictResolverTests {
    private func makeState(lifetime: Double, lastSeen: TimeInterval) -> PlayerState {
        var state = PlayerState.newGame(startTypeId: "a", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: lastSeen)
        state.lifetimeEarnings = lifetime
        return state
    }

    @Test func higherLifetimeWinsBothDirections() {
        let ahead = makeState(lifetime: 1000, lastSeen: 1)
        let behind = makeState(lifetime: 10, lastSeen: 999)
        #expect(SaveConflictResolver.resolve(local: ahead, remote: behind).lifetimeEarnings == 1000)
        #expect(SaveConflictResolver.resolve(local: behind, remote: ahead).lifetimeEarnings == 1000)
    }

    @Test func timestampBreaksTies() {
        let older = makeState(lifetime: 500, lastSeen: 100)
        let newer = makeState(lifetime: 500, lastSeen: 200)
        #expect(SaveConflictResolver.resolve(local: older, remote: newer).lastSeenTimestamp == 200)
        #expect(SaveConflictResolver.resolve(local: newer, remote: older).lastSeenTimestamp == 200)
    }

    @Test func purchasesAndSpecialsMergeByUnion() {
        var loser = makeState(lifetime: 10, lastSeen: 1)
        loser.removedAds = true
        loser.ownedSkins = ["golden"]
        loser.ownedSpecials = ["sp_cryptobro"]
        var winner = makeState(lifetime: 1000, lastSeen: 2)
        winner.ownedSkins = ["god"]
        winner.ownedSpecials = ["sp_coach"]

        let resolved = SaveConflictResolver.resolve(local: loser, remote: winner)
        #expect(resolved.lifetimeEarnings == 1000)
        #expect(resolved.removedAds)
        #expect(resolved.ownedSkins == ["god", "golden"])
        #expect(resolved.ownedSpecials == ["sp_coach", "sp_cryptobro"])
    }

    @Test func scoreClampNeverTraps() {
        #expect(SaveConflictResolver.clampedScore(0) == 0)
        #expect(SaveConflictResolver.clampedScore(-5) == 0)
        #expect(SaveConflictResolver.clampedScore(1234.9) == 1234)
        #expect(SaveConflictResolver.clampedScore(1e19) == .max)
        #expect(SaveConflictResolver.clampedScore(1e20) == .max)
        #expect(SaveConflictResolver.clampedScore(.infinity) == .max)
        #expect(SaveConflictResolver.clampedScore(.nan) == .max)
    }
}
