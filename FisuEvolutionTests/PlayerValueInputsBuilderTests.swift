import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las entradas de `PlayerValue` (2.1 E15 F1 T5, contrato C1) salen del save, del aparato y de las
/// sesiones del registro de la personalización, sin tocar nada.
@Suite("Personalización: las entradas del valor por jugador")
struct PlayerValueInputsBuilderTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let day: TimeInterval = 24 * 60 * 60

    static func player() -> PlayerState {
        PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley", offlineEfficiencyBase: 0.5, critChanceBase: 0,
            now: 1_700_000_000)
    }

    static func rewarded(_ micros: Int64, currency: String = "USD") -> AdImpression {
        AdImpression(format: .rewarded, site: "offline.x2", valueMicros: micros, currency: currency,
                     precision: .precise, adSource: "Google", at: 0)
    }

    static func session(daysAgo: Double, seconds: Double?, prestige: Int = 0, offers: Int = 0)
        -> PersonalizationRecord.Session {
        PersonalizationRecord.Session(
            startedAt: now.addingTimeInterval(-daysAgo * day), seconds: seconds, prestige: prestige, offersShown: offers)
    }

    @Test("una partida nueva: todo en cero, con la tienda y el aparato tal cual")
    func freshPlayer() {
        let inputs = PlayerValueInputsBuilder.inputs(
            player: Self.player(), storefront: "ARG", deviceModel: "iPhone16,2", sessions: [], now: Self.now)
        #expect(inputs == PlayerValueInputs(storefront: "ARG", deviceModel: "iPhone16,2"))
    }

    @Test("el ledger, las compras y los videos salen del save")
    func ledgerPurchasesAndVideos() {
        var player = Self.player()
        for micros: Int64 in [10_000, 20_000, 30_000] { player.meta.adRevenue.record(Self.rewarded(micros)) }
        player.meta.creditedPurchases = ["tx-1"]
        player.meta.stats.videosWatchedEver = 7

        let inputs = PlayerValueInputsBuilder.inputs(
            player: player, storefront: nil, deviceModel: nil, sessions: [], now: Self.now)
        #expect(inputs.rewardedCount == 3)
        #expect(inputs.averageRewardedMicros == 20_000)
        #expect(inputs.recentRewardedMicros == 20_000)
        #expect(inputs.hasPurchased)
        #expect(inputs.videosWatchedEver == 7)
    }

    @Test("sesiones de los últimos 7 días: cuántas y la duración media de las cerradas")
    func sessionsInTheWindow() {
        let sessions = [
            Self.session(daysAgo: 9, seconds: 5_000),
            Self.session(daysAgo: 6, seconds: 300),
            Self.session(daysAgo: 2, seconds: 900),
            Self.session(daysAgo: 1, seconds: nil),
            Self.session(daysAgo: 0, seconds: nil),
        ]
        let inputs = PlayerValueInputsBuilder.inputs(
            player: Self.player(), storefront: nil, deviceModel: nil, sessions: sessions, now: Self.now)
        #expect(inputs.sessionsLast7Days == 4, "la de hace 9 días no entra")
        #expect(inputs.meanSessionSeconds == 600, "las abiertas o sin cierre no cuentan en la media")
    }

    @Test("una sesión con fecha en el futuro (reloj tocado) no entra")
    func futureSessionIsIgnored() {
        let sessions = [Self.session(daysAgo: -2, seconds: 100)]
        let inputs = PlayerValueInputsBuilder.inputs(
            player: Self.player(), storefront: nil, deviceModel: nil, sessions: sessions, now: Self.now)
        #expect(inputs.sessionsLast7Days == 0)
        #expect(inputs.meanSessionSeconds == 0)
    }

    @Test("ofertas y reencarnaciones de la semana: lo de ahora menos lo de la sesión más vieja de la ventana")
    func offersAndPrestigesInTheWindow() {
        var player = Self.player()
        player.meta.prestigeLevel = 5
        for _ in 0..<12 { player.meta.offerFunnel.record(.shown, site: "offline.x2") }
        player.meta.offerFunnel.record(.shown, site: "gifts.card")
        player.meta.offerFunnel.record(.accepted, site: "gifts.card")
        let sessions = [
            Self.session(daysAgo: 10, seconds: 60, prestige: 1, offers: 2),
            Self.session(daysAgo: 5, seconds: 60, prestige: 3, offers: 8),
            Self.session(daysAgo: 1, seconds: 60, prestige: 4, offers: 11),
        ]
        let inputs = PlayerValueInputsBuilder.inputs(
            player: player, storefront: nil, deviceModel: nil, sessions: sessions, now: Self.now)
        #expect(PlayerValueInputsBuilder.offersShown(player.meta.offerFunnel) == 13)
        #expect(inputs.offersSeenLast7Days == 5)
        #expect(inputs.prestigesLast7Days == 2)
    }

    @Test("un reset que bajó los contadores no da negativo; sin sesiones, cero")
    func countersNeverNegative() {
        var player = Self.player()
        player.meta.prestigeLevel = 0
        let sessions = [Self.session(daysAgo: 1, seconds: 60, prestige: 6, offers: 40)]
        let inputs = PlayerValueInputsBuilder.inputs(
            player: player, storefront: nil, deviceModel: nil, sessions: sessions, now: Self.now)
        #expect(inputs.offersSeenLast7Days == 0)
        #expect(inputs.prestigesLast7Days == 0)

        player.meta.prestigeLevel = 3
        let empty = PlayerValueInputsBuilder.inputs(
            player: player, storefront: nil, deviceModel: nil, sessions: [], now: Self.now)
        #expect(empty.prestigesLast7Days == 0)
    }

    @Test("el registro guarda las últimas 30 sesiones y cierra sólo la abierta")
    func recordKeepsThirtySessions() {
        var record = PersonalizationRecord.empty
        for index in 0..<35 {
            record.beginSession(at: Self.now.addingTimeInterval(Double(index)), prestige: index, offersShown: 0)
        }
        #expect(record.sessions.count == PersonalizationRecord.maxSessions)
        #expect(record.sessions.first?.prestige == 5)

        record.endSession(at: Self.now.addingTimeInterval(134))
        #expect(record.sessions.last?.seconds == 100)
        record.endSession(at: Self.now.addingTimeInterval(500))
        #expect(record.sessions.last?.seconds == 100, "cerrar dos veces no la estira")
    }
}
