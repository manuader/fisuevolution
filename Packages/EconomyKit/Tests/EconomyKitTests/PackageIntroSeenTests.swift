import Foundation
import Testing
@testable import EconomyKit

@Suite("La caja del tablero recuerda si ya se vio su pantalla (E14b B5, D2)")
struct PackageIntroSeenTests {
    @Test("un save de antes, sin la clave, decodifica en false y conserva lo demás")
    func legacySaveDecodesUnseen() throws {
        let legacy = Data(#"{"packages":{"waiting":2},"firstLaunchDay":"2026-09-01"}"#.utf8)
        let engagement = try JSONDecoder().decode(EngagementState.self, from: legacy)
        #expect(!engagement.packageIntroSeen)
        #expect(engagement.packages.waiting == 2)
        #expect(engagement.firstLaunchDay == "2026-09-01")
    }

    @Test("lo visto sobrevive la ida y vuelta del save")
    func roundTripKeepsTheFlag() throws {
        var engagement = EngagementState.initial
        engagement.packageIntroSeen = true
        let back = try JSONDecoder().decode(EngagementState.self, from: JSONEncoder().encode(engagement))
        #expect(back.packageIntroSeen)
        #expect(back == engagement)
    }

    @Test("entre dispositivos lo visto no se des-ve")
    func resolveKeepsSeen() {
        var seen = EngagementState.initial
        seen.packageIntroSeen = true
        #expect(EngagementState.resolve(winner: seen, loser: .initial).packageIntroSeen)
        #expect(EngagementState.resolve(winner: .initial, loser: seen).packageIntroSeen)
        #expect(!EngagementState.resolve(winner: .initial, loser: .initial).packageIntroSeen)
    }
}
