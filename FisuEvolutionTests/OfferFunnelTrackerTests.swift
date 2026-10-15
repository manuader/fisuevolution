import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El embudo de ofertas por lugar (E15 T3): qué cuenta un botón de video según lo que le pasa, y que
/// el juego lo anote en el save sin tocar nada más.
@Suite("El embudo de ofertas por lugar")
@MainActor
struct OfferFunnelTrackerTests {
    private func run(_ transitions: [OfferFunnelTracker.Transition]) -> [OfferStage] {
        var tracker = OfferFunnelTracker()
        return transitions.flatMap { tracker.handle($0) }
    }

    @Test("aparece listo: shown una vez, aunque el sondeo lo vuelva a ver")
    func shownOncePerAppearance() {
        #expect(run([.appearedReady]) == [.shown])
        #expect(run([.appearedReady, .appearedReady, .appearedReady, .appearedReady]) == [.shown])
    }

    @Test("doble toque: accepted una vez")
    func doubleTapIsOneAcceptance() {
        #expect(run([.appearedReady, .tapped, .tapped]) == [.shown, .accepted])
    }

    @Test("el premio cuenta completed, y la vuelta del video siguiente no vuelve a contar shown")
    func earnedCountsCompleted() {
        #expect(run([.appearedReady, .tapped, .earned, .appearedReady]) == [.shown, .accepted, .completed])
    }

    @Test("se va sin tocar: dismissed")
    func leavingUntouchedIsDismissed() {
        #expect(run([.appearedReady, .disappeared]) == [.shown, .dismissed])
    }

    @Test("se va después de tocar: nada")
    func leavingAfterTappingCountsNothing() {
        #expect(run([.appearedReady, .tapped, .earned, .disappeared]) == [.shown, .accepted, .completed])
        #expect(run([.appearedReady, .tapped, .endedWithoutReward, .disappeared]) == [.shown, .accepted])
    }

    @Test("se va con el video en curso: nada, y la aparición sigue abierta")
    func leavingMidVideoKeepsTheAppearance() {
        #expect(run([.appearedReady, .tapped, .disappeared, .appearedReady, .earned])
                == [.shown, .accepted, .completed])
    }

    @Test("nunca estuvo listo: irse no es dismissed")
    func neverShownIsNeverDismissed() {
        #expect(run([.disappeared]).isEmpty)
    }

    @Test("sin inventario: unfilled, y el reintento es otro accepted")
    func noInventoryIsUnfilled() {
        #expect(run([.appearedReady, .tapped, .noInventory]) == [.shown, .accepted, .unfilled])
        #expect(run([.appearedReady, .tapped, .noInventory, .tapped, .earned])
                == [.shown, .accepted, .unfilled, .accepted, .completed])
    }

    @Test("el resultado llega con el botón ya ido: completed y unfilled no dependen de su estado")
    func outcomesCountWithoutState() {
        #expect(run([.earned]) == [.completed])
        #expect(run([.noInventory]) == [.unfilled])
    }

    @Test("una aparición nueva vuelve a contar shown")
    func reappearingCountsAgain() {
        #expect(run([.appearedReady, .disappeared, .appearedReady])
                == [.shown, .dismissed, .shown])
    }

    @Test("cómo terminó el intento, según el proveedor")
    func outcomeMapping() {
        #expect(RewardedOfferButton.outcome(earned: true, attempt: .presented) == .earned)
        #expect(RewardedOfferButton.outcome(earned: false, attempt: .noInventory) == .noInventory)
        #expect(RewardedOfferButton.outcome(earned: false, attempt: .presented) == .endedWithoutReward)
        #expect(RewardedOfferButton.outcome(earned: false, attempt: .busy) == .endedWithoutReward)
    }

    @Test("el reporter del juego anota en meta.offerFunnel, por lugar")
    func reporterRecordsInTheSave() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)
        let reporter = gameState.offerFunnelReporter

        reporter.report("double.offline", .shown)
        reporter.report("double.offline", .dismissed)
        reporter.report("ads.watch.double_earnings", .shown)

        let after = try #require(gameState.player)
        let funnel = after.meta.offerFunnel
        #expect(funnel.counts(site: "double.offline").shown == 1)
        #expect(funnel.counts(site: "double.offline").dismissed == 1)
        #expect(funnel.counts(site: "ads.watch.double_earnings").shown == 1)
        #expect(after.run.coins == before.run.coins, "medir no acredita nada")
        #expect(after.meta.stats == before.meta.stats)
    }

    @Test("la sonda: una entrada por lugar y etapa, con su contador")
    func probeEntries() {
        var funnel = OfferFunnel.empty
        funnel.record(.shown, site: "double.offline")
        let entries = AdValueProbe.funnelEntries(funnel)
        #expect(entries.count == OfferStage.allCases.count)
        #expect(entries.contains(AdValueProbe.FunnelEntry(id: "ads.funnel.double.offline.shown", count: 1)))
        #expect(entries.contains(AdValueProbe.FunnelEntry(id: "ads.funnel.double.offline.dismissed", count: 0)))
        #expect(AdValueProbe.funnelEntries(nil).isEmpty)
    }
}
