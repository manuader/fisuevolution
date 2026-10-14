import Foundation
import Testing
@testable import EconomyKit

private let everything = Set(RewardSpec.Kind.allCases)

/// Ocho de la calle, cada uno con uno o dos guiones de regalo, y el vendedor.
private func fxCrowd(dailyCap: Int = 99) -> VisitorsConfig {
    let names = ["comisario", "sindicalista", "turista", "puntero", "ministro", "vecina", "vendedor", "conductor"]
    let visitors = names.map {
        VisitorsConfig.Visitor(id: "npc_\($0)", kind: .npc, nameKey: "visitor.npc_\($0).name",
                               fallbackSymbol: "x", fallbackTint: "PaletteGreen")
    }
    var scripts = names.filter { $0 != "vendedor" }.flatMap { name in
        [fxScript("\(name)_a", visitor: "npc_\(name)", dailyCap: dailyCap,
                  mechanic: .gift(rewards: [.coinsSeconds(60)], videoDoubles: false)),
         fxScript("\(name)_b", visitor: "npc_\(name)", weight: 1, dailyCap: dailyCap,
                  mechanic: .gift(rewards: [.coinsSeconds(120)], videoDoubles: false))]
    }
    scripts.append(fxScript("vendedor_ofertas", visitor: "npc_vendedor", dailyCap: dailyCap, mechanic: .vendor(cards: [
        .init(id: "mate", nameKey: "boost.mate.name", iconKey: "ui_boost_mate",
              reward: .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90)),
    ])))
    return VisitorsConfig(
        schemaVersion: 1, firstVisitAfterSeconds: 600, intervalMinSeconds: 240, intervalMaxSeconds: 360,
        retryWhenNoneSeconds: 30, patienceSeconds: 30, presenterTalkSeconds: 4, coinsSecondsScale: 1,
        visitors: visitors, scripts: scripts
    )
}

@Suite("Visitantes: el reloj")
struct VisitorClockTests {
    let config = fxVisitors()

    private func play(_ state: inout VisitorsState, seconds: Int) -> Bool {
        var due = false
        for _ in 0..<seconds {
            due = VisitorScheduler.advance(&state, delta: 1, config: config) || due
        }
        return due
    }

    @Test("la primera visita llega a los 600 s de juego, no antes")
    func firstVisit() {
        var state = VisitorsState.initial
        #expect(!play(&state, seconds: 599))
        #expect(play(&state, seconds: 1))
    }

    @Test("un salto grande del tick no cuenta")
    func clampedDelta() {
        var state = VisitorsState.initial
        #expect(!VisitorScheduler.advance(&state, delta: 3600, config: config))
        #expect(state.secondsUntilVisit == 600 - IncomeTicker.deltaClampThreshold)
    }

    @Test("después de una visita, sea quien sea (el vendedor también), la próxima entre 240 y 360 s")
    func nextVisitInterval() throws {
        var rng = SeededRNG(seed: 4)
        for id in ["propina", "ofertas"] {
            for _ in 0..<50 {
                var state = VisitorsState(secondsUntilVisit: 0)
                VisitorScheduler.markVisited(try #require(config.script(id: id)), state: &state, config: config, rng: &rng)
                let next = try #require(state.secondsUntilVisit)
                #expect(next >= 240 && next <= 360)
            }
        }
    }

    @Test("le tocaba a alguien y nadie puede: reintenta a los 30 s")
    func retrySoon() {
        var state = VisitorsState(secondsUntilVisit: -1)
        VisitorScheduler.retrySoon(state: &state, config: config)
        #expect(state.secondsUntilVisit == 30)
    }

    @Test("el día nuevo resetea los topes; el mismo día no")
    func rollDay() {
        var state = VisitorsState(day: "2026-10-07", visitsToday: ["a": 2], oroExchangedToday: 3)
        VisitorScheduler.rollDay(&state, today: "2026-10-07")
        #expect(state.visitsToday == ["a": 2])
        VisitorScheduler.rollDay(&state, today: "2026-10-08")
        #expect(state.visitsToday.isEmpty)
        #expect(state.oroExchangedToday == 0)
        #expect(state.day == "2026-10-08")
    }
}

@Suite("Visitantes: la bolsa barajada")
struct VisitorBagTests {
    let context = VisitContext(maxTier: 5, ownedSpecials: [], grantable: [.coinsSeconds, .oro, .modifier])

    /// Visitas seguidas, siempre con alguien que puede venir: devuelve quién vino.
    private func visits(_ count: Int, config: VisitorsConfig, state: inout VisitorsState, seed: UInt64,
                        isOfferable: (VisitorsConfig.Script) -> Bool = { _ in true }) -> [VisitorsConfig.Script] {
        var rng = SeededRNG(seed: seed)
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        var seen: [VisitorsConfig.Script] = []
        for _ in 0..<count {
            guard let script = VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                         isOfferable: isOfferable, rng: &rng) else { break }
            VisitorScheduler.markVisited(script, state: &state, config: config, rng: &rng)
            seen.append(script)
        }
        return seen
    }

    @Test("entran a la bolsa los desbloqueados: tier, especial conseguido y premios entregables")
    func unlocked() {
        let config = fxVisitors()
        #expect(VisitorScheduler.unlockedVisitors(config: config, context: context)
                == ["npc_turista", "npc_comisario", "npc_vendedor"], "sin el especial y sin lo que llama un evento")
        let low = VisitContext(maxTier: 2, ownedSpecials: ["sp_cryptobro"], grantable: context.grantable)
        #expect(VisitorScheduler.unlockedVisitors(config: config, context: low)
                == ["npc_turista", "npc_vendedor", "sp_cryptobro"], "el arresto pide tier 3")
    }

    @Test("N visitas con todos desbloqueados: nadie repite dentro de una vuelta")
    func nobodyRepeatsWithinARound() {
        let config = fxCrowd()
        for seed in UInt64(1)...20 {
            var state = VisitorsState.initial
            let seen = visits(8 * 12, config: config, state: &state, seed: seed).map(\.visitor)
            #expect(seen.count == 8 * 12)
            for start in stride(from: 0, to: seen.count, by: 8) {
                let round = seen[start..<start + 8]
                #expect(Set(round).count == 8, "semilla \(seed), vuelta \(start / 8): \(Array(round))")
            }
        }
    }

    @Test("en dos vueltas salen todos los elegibles, con conteos parejos")
    func twoRoundsBringEveryone() {
        let config = fxCrowd()
        var state = VisitorsState.initial
        let seen = visits(16, config: config, state: &state, seed: 3).map(\.visitor)
        #expect(Set(seen) == Set(config.visitors.map(\.id)))
        let counts = Dictionary(grouping: seen, by: { $0 }).mapValues(\.count)
        #expect(counts.values.allSatisfy { $0 == 2 }, "\(counts)")
    }

    @Test("nadie dos veces seguidas, tampoco en el borde de la bolsa ni el vendedor")
    func neverTwiceInARow() {
        let config = fxCrowd()
        for seed in UInt64(1)...20 {
            var state = VisitorsState.initial
            let seen = visits(100, config: config, state: &state, seed: seed).map(\.visitor)
            for (previous, next) in zip(seen, seen.dropFirst()) {
                #expect(previous != next, "semilla \(seed): \(previous) dos veces")
            }
        }
    }

    @Test("el vendedor no sale dos seguidas aunque sea el único que puede ahora")
    func vendorNeverTwiceEvenAlone() throws {
        let config = fxCrowd()
        var state = VisitorsState(visitorBag: ["npc_vendedor", "npc_turista"], lastVisitor: "npc_vendedor")
        var rng = SeededRNG(seed: 1)
        let onlyVendor: (VisitorsConfig.Script) -> Bool = { $0.visitor == "npc_vendedor" }
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        #expect(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                          isOfferable: onlyVendor, rng: &rng) == nil)
    }

    @Test("un visitante que no es el vendedor repite si es el único con cupo")
    func nonVendorRepeatsWhenAlone() throws {
        let config = fxCrowd()
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        let onlySindicalista: (VisitorsConfig.Script) -> Bool = { $0.visitor == "npc_sindicalista" }
        for seed in UInt64(1)...10 {
            var state = VisitorsState(visitorBag: ["npc_turista", "npc_sindicalista"], lastVisitor: "npc_sindicalista")
            var rng = SeededRNG(seed: seed)
            let script = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                                isOfferable: onlySindicalista, rng: &rng))
            #expect(script.visitor == "npc_sindicalista", "semilla \(seed)")
        }
    }

    @Test("con otro candidato, el último no repite aunque pueda")
    func nonVendorYieldsToAnotherCandidate() throws {
        let config = fxCrowd()
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        var state = VisitorsState(visitorBag: ["npc_sindicalista", "npc_turista"], lastVisitor: "npc_sindicalista")
        var rng = SeededRNG(seed: 1)
        let script = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                            isOfferable: { _ in true }, rng: &rng))
        #expect(script.visitor == "npc_turista")
    }

    @Test("el único desbloqueado puede repetir: mejor eso que nadie")
    func aLoneVisitorRepeats() throws {
        let config = fxVisitors(scripts: [fxScript("propina", mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false))])
        var state = VisitorsState(lastVisitor: "npc_turista")
        var rng = SeededRNG(seed: 1)
        #expect(VisitorScheduler.pickNext(config: config, state: &state, context: context,
                                          isOfferable: { _ in true }, rng: &rng)?.id == "propina")
    }

    @Test("el que no puede venir ahora deja pasar al siguiente y queda primero para la próxima")
    func skippedVisitorStaysFirst() throws {
        let config = fxCrowd()
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        var state = VisitorsState(visitorBag: ["npc_turista", "npc_ministro", "npc_vecina"])
        var rng = SeededRNG(seed: 1)
        let notTurista: (VisitorsConfig.Script) -> Bool = { $0.visitor != "npc_turista" }
        let first = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                           isOfferable: notTurista, rng: &rng))
        #expect(first.visitor == "npc_ministro")
        VisitorScheduler.markVisited(first, state: &state, config: config, rng: &rng)
        #expect(state.visitorBag == ["npc_turista", "npc_vecina"])
        let second = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                            isOfferable: { _ in true }, rng: &rng))
        #expect(second.visitor == "npc_turista")
    }

    @Test("si nadie de la bolsa puede, la vuelta siguiente entra detrás de los que esperan")
    func nextRoundGoesBehindTheWaiting() throws {
        let config = fxCrowd()
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        var state = VisitorsState(visitorBag: ["npc_turista"], lastVisitor: "npc_ministro")
        var rng = SeededRNG(seed: 2)
        let notTurista: (VisitorsConfig.Script) -> Bool = { $0.visitor != "npc_turista" }
        let script = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                            isOfferable: notTurista, rng: &rng))
        #expect(script.visitor != "npc_turista")
        #expect(script.visitor != "npc_ministro", "el último no repite en el borde")
        #expect(state.visitorBag.first == "npc_turista")
        #expect(Set(state.visitorBag) == Set(config.visitors.map(\.id)))
    }

    @Test("el tope del día también lo hace esperar")
    func dailyCapWaits() throws {
        let config = fxCrowd(dailyCap: 1)
        let all = VisitContext(maxTier: 99, ownedSpecials: [], grantable: everything)
        var state = VisitorsState(visitorBag: ["npc_turista", "npc_vecina"], day: "d",
                                  visitsToday: ["turista_a": 1, "turista_b": 1])
        var rng = SeededRNG(seed: 1)
        let script = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: all,
                                                            isOfferable: { _ in true }, rng: &rng))
        #expect(script.visitor == "npc_vecina")
    }

    @Test("los guiones de un visitante se alternan")
    func scriptsAlternate() {
        let config = fxCrowd()
        var state = VisitorsState.initial
        let seen = visits(8 * 6, config: config, state: &state, seed: 9)
        for visitor in config.visitors.map(\.id) where visitor != "npc_vendedor" {
            let mine = seen.filter { $0.visitor == visitor }.map(\.id)
            for (previous, next) in zip(mine, mine.dropFirst()) {
                #expect(previous != next, "\(visitor): \(mine)")
            }
        }
    }

    @Test("los que se bloquean (otra run, tier bajo) salen de la bolsa; los nuevos esperan la vuelta")
    func lockedLeaveTheBag() throws {
        let config = fxVisitors()
        var state = VisitorsState(visitorBag: ["npc_comisario", "npc_turista"])
        var rng = SeededRNG(seed: 1)
        let low = VisitContext(maxTier: 1, ownedSpecials: [], grantable: context.grantable)
        let script = try #require(VisitorScheduler.pickNext(config: config, state: &state, context: low,
                                                            isOfferable: { _ in true }, rng: &rng))
        #expect(script.visitor == "npc_turista")
        #expect(state.visitorBag == ["npc_turista"])
    }

    @Test("lo que llama un evento no sale de la bolsa ni le gasta el turno")
    func eventOnlyKeepsTheTurn() throws {
        let config = fxVisitors()
        let blue = try #require(config.script(id: "blue"))
        let owned = VisitContext(maxTier: 5, ownedSpecials: ["sp_cryptobro"], grantable: context.grantable)
        #expect(VisitorScheduler.isAvailable(blue, config: config, state: .initial, context: owned) { _ in true })
        #expect(!VisitorScheduler.isAvailable(blue, config: config, state: .initial, context: context) { _ in true },
                "el especial no está conseguido")
        #expect(!VisitorScheduler.availableScripts(of: "sp_cryptobro", config: config, state: .initial, context: owned) { _ in true }
            .map(\.id).contains("blue"))
        var state = VisitorsState(visitorBag: ["sp_cryptobro"])
        var rng = SeededRNG(seed: 1)
        VisitorScheduler.markVisited(blue, state: &state, config: config, rng: &rng)
        #expect(state.visitorBag == ["sp_cryptobro"])
        #expect(state.visitsToday["blue"] == 1)
    }

    @Test("visitar saca de la bolsa, anota el último y su guion, y cuenta el día")
    func markVisitedBookkeeping() throws {
        let config = fxVisitors()
        var state = VisitorsState(visitorBag: ["npc_comisario", "npc_turista"], day: "d")
        var rng = SeededRNG(seed: 2)
        VisitorScheduler.markVisited(try #require(config.script(id: "propina")), state: &state, config: config, rng: &rng)
        #expect(state.visitorBag == ["npc_comisario"])
        #expect(state.lastVisitor == "npc_turista")
        #expect(state.lastScriptByVisitor == ["npc_turista": "propina"])
        #expect(state.visitsToday["propina"] == 1)
    }
}
