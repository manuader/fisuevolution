import Foundation
import Testing
@testable import FisuEvolution

/// Menos forzados para el segmento que mira videos (2.1 E15 F2 T8): la escala del espaciado del
/// `ForcedAdsPacer` sólo puede espaciar más, nunca menos. Con escala 1 la decisión es la de la 2.0 en
/// todos los cortes; con 1,25 se espera 1,25× más; con menos de 1 se ignora (misma regla que
/// `AdsRemoteConfig.Floor`: lo de afuera puede espaciar más, nunca menos).
@Suite("Forzados según el segmento", .serialized)
@MainActor
struct ForcedAdsSegmentTests {
    private static let ready = NaturalBreakContext(readyFormats: Set(ForcedAdFormat.allCases))
    private static let base = NaturalBreakPolicy.default.minSecondsBetweenForced

    /// Un pacer con la gracia de arranque ya pasada y un forzado recién mostrado.
    private struct Rig {
        let pacer: ForcedAdsPacer
        let clock: TestClock
        let scratch: Scratch
    }

    private func rig(spacingScale: Double?) -> Rig {
        let clock = TestClock()
        let scratch = Scratch()
        let pacer = ForcedAdsPacer(store: AdsPacingStore(defaults: scratch.defaults), now: clock.read)
        if let spacingScale { pacer.spacingScale = spacingScale }
        clock.advance(by: 10_000)
        pacer.recordShown(.interstitial)
        return Rig(pacer: pacer, clock: clock, scratch: scratch)
    }

    @Test("escala 1 = la decisión de hoy en todos los cortes", arguments: NaturalBreak.allCases)
    func identityKeepsTodaysDecision(naturalBreak: NaturalBreak) {
        let scaled = rig(spacingScale: 1)
        let today = rig(spacingScale: nil)
        defer { scaled.scratch.clear(); today.scratch.clear() }
        // Los dos pacers caminan juntos por la ventana entre forzados, y los dos deciden lo que
        // decide la política de la 2.0 sola.
        var walked: TimeInterval = 0
        for elapsed: TimeInterval in [0, 60, Self.base - 1, Self.base, Self.base * 1.25, 3600] {
            scaled.clock.advance(by: elapsed - walked)
            today.clock.advance(by: elapsed - walked)
            walked = elapsed
            #expect(scaled.pacer.decide(naturalBreak, context: Self.ready) == today.pacer.decide(naturalBreak, context: Self.ready))
            #expect(scaled.pacer.secondsUntilAlternatingDue() == today.pacer.secondsUntilAlternatingDue())
            let expected = NaturalBreakPolicy.default.decide(
                naturalBreak, context: Self.ready, pacing: today.pacer.pacing,
                session: today.pacer.session, now: today.clock.read()
            )
            #expect(today.pacer.decide(naturalBreak, context: Self.ready) == expected)
        }
        #expect(today.pacer.spacingScale == 1)
    }

    @Test("escala 1,25: el próximo forzado espera 1,25× más")
    func widerScaleWaitsLonger() {
        let rig = rig(spacingScale: 1.25)
        defer { rig.scratch.clear() }
        #expect(rig.pacer.secondsUntilAlternatingDue() == Self.base * 1.25)

        rig.clock.advance(by: Self.base)
        #expect(rig.pacer.decide(.sheetClosed, context: Self.ready) == .skip(.tooSoonAfterForced))

        rig.clock.advance(by: Self.base * 0.25 - 1)
        #expect(rig.pacer.decide(.sheetClosed, context: Self.ready) == .skip(.tooSoonAfterForced))

        rig.clock.advance(by: 1)
        #expect(rig.pacer.decide(.sheetClosed, context: Self.ready).format != nil)
        #expect(rig.pacer.secondsUntilAlternatingDue() == 0)
    }

    @Test("la escala no toca la política guardada: una config remota nueva la sigue respetando")
    func scaleSurvivesPolicySwap() {
        let rig = rig(spacingScale: 2)
        defer { rig.scratch.clear() }
        var remote = NaturalBreakPolicy.default
        remote.minSecondsBetweenForced = 200
        rig.pacer.policy = remote
        #expect(rig.pacer.policy.minSecondsBetweenForced == 200)
        #expect(rig.pacer.secondsUntilAlternatingDue() == 400)
    }

    @Test("menos de 1 se ignora: nunca más agresivo que la base", arguments: [0.5, 0.99, 0, -1, .nan, .infinity])
    func belowOneIsIgnored(scale: Double) {
        let rig = rig(spacingScale: scale)
        defer { rig.scratch.clear() }
        #expect(rig.pacer.secondsUntilAlternatingDue() == Self.base)

        rig.clock.advance(by: Self.base - 1)
        #expect(rig.pacer.decide(.sheetClosed, context: Self.ready) == .skip(.tooSoonAfterForced))

        rig.clock.advance(by: 1)
        #expect(rig.pacer.decide(.sheetClosed, context: Self.ready).format != nil)
    }

    private struct Scratch {
        let name = "v21-f2-t8-\(UUID().uuidString)"
        let defaults: UserDefaults

        init() {
            defaults = UserDefaults(suiteName: name) ?? .standard
        }

        func clear() {
            defaults.removePersistentDomain(forName: name)
        }
    }
}
