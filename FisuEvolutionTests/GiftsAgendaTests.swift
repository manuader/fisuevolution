import Foundation
import Testing
@testable import FisuEvolution

/// El orden de Regalos por estado (E14 C29): lo listo arriba, el reloj después,
/// lo bloqueado al final.
@Suite("Regalos ordenado por estado")
struct GiftsAgendaTests {
    private func boost(
        _ id: String, unlocked: Bool = true, cooldown: TimeInterval = 0, offersAd: Bool = false
    ) -> GameState.BoostRow {
        GameState.BoostRow(
            id: id, displayName: id, iconKey: "boost_\(id)", effectText: "", flavorText: "",
            isUnlocked: unlocked, unlockFloorName: unlocked ? nil : "El Callejón",
            cooldownRemaining: cooldown, cooldownTotal: 600, offersAd: offersAd
        )
    }

    private func video(_ id: String, cooldown: TimeInterval = 0, reason: String? = nil) -> GameState.RewardRow {
        GameState.RewardRow(
            id: id, titleKey: "ads.watch", rewardText: "", cooldownRemaining: cooldown,
            cooldownTotal: 14_400, unavailableReason: reason
        )
    }

    private func agenda(
        chests: Int = 0, canOpen: Bool = true, wheel: WheelAvailability = .none, wheelReadyIn: TimeInterval? = nil,
        boosts: [GameState.BoostRow] = [], videos: [GameState.RewardRow] = []
    ) -> GiftsAgenda {
        GiftsAgenda(
            chests: chests, canOpenChest: canOpen, wheel: wheel, wheelReadyIn: wheelReadyIn,
            boosts: boosts, videos: videos
        )
    }

    private let freeSpin = WheelAvailability(bonus: 1, videoLeft: 0, blueLeft: 0, blueCost: 0, canPayBlue: false)

    @Test("lo listo va por valor: cofre, ruleta, boosts y videos")
    func readyOrder() {
        let result = agenda(
            chests: 2, wheel: freeSpin,
            boosts: [boost("mate"), boost("milanesa")], videos: [video("double")]
        )
        #expect(result.ready.map(\.id) == ["chest", "wheel", "mate", "milanesa", "double"])
        #expect(result.hero?.id == "chest")
        #expect(result.rest.map(\.id) == ["wheel", "mate", "milanesa", "double"])
        #expect(result.soon.isEmpty && result.later.isEmpty)
    }

    @Test("sin cofre, el hero es lo más valioso que queda")
    func heroFallsThrough() {
        let result = agenda(boosts: [boost("mate")], videos: [video("double")])
        #expect(result.hero?.id == "mate")
    }

    @Test("lo que corre con reloj va a Pronto, el que antes vuelve primero")
    func soonSortedByClock() {
        let result = agenda(
            wheelReadyIn: 900,
            boosts: [boost("mate", cooldown: 300), boost("milanesa", cooldown: 60)],
            videos: [video("double", cooldown: 3_000)]
        )
        #expect(result.ready.isEmpty)
        #expect(result.hero == nil)
        #expect(result.soon.map(\.id) == ["milanesa", "mate", "wheel", "double"])
    }

    @Test("lo bloqueado y lo que hoy no se ofrece va al final, sin reloj")
    func laterHoldsWhatCannotBeDone() {
        let result = agenda(
            chests: 1, canOpen: false,
            boosts: [boost("asado", unlocked: false)], videos: [video("gift", reason: "Ya tenés todo")]
        )
        #expect(result.ready.isEmpty)
        #expect(result.later.map(\.id) == ["chest", "wheel", "asado", "gift"])
    }

    @Test("un boost que termina su cooldown pasa de Pronto a Para cobrar")
    func cooldownEndsMovesUp() {
        let waiting = agenda(boosts: [boost("mate", cooldown: 5)])
        #expect(waiting.hero == nil && waiting.soon.map(\.id) == ["mate"])
        let done = agenda(boosts: [boost("mate", cooldown: 0)])
        #expect(done.hero?.id == "mate" && done.soon.isEmpty)
    }

    @Test("la ruleta sin giros pero con reloj espera; sin reloj, queda para más adelante")
    func wheelWithoutSpins() {
        #expect(agenda(wheelReadyIn: 120).soon.map(\.id) == ["wheel"])
        #expect(agenda().later.map(\.id) == ["wheel"])
    }
}
