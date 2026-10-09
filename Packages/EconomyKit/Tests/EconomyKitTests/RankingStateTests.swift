import Foundation
import Testing
@testable import EconomyKit

@Suite("RankingState: la partida rankeada")
struct RankingStateTests {
    private func running(_ id: String = "r1", started: TimeInterval = 1_000) -> RankingState {
        var s = RankingState.newGame
        s.registered(runId: id, serverStartedAt: started)
        return s
    }

    private func god(_ id: String = "r1", sealed: Bool = false) -> RankingState {
        var s = running(id)
        s.reachedGod(at: 5_000)
        if sealed { s.sealed(realSeconds: 4_000, underReview: false, nameStatus: .missing) }
        return s
    }

    private func roundTrip(_ s: RankingState) throws -> RankingState {
        try JSONDecoder().decode(RankingState.self, from: JSONEncoder().encode(s))
    }

    // MARK: clientRunId

    @Test("el clientRunId nace una vez, se reusa, sobrevive al guardado y se suelta al registrar")
    func clientRunIdIsStableUntilRegistered() throws {
        var s = RankingState.newGame
        let first = s.startAttemptId(make: { "id-1" })
        let second = s.startAttemptId(make: { "id-2" })
        #expect(first == "id-1" && second == "id-1")
        var reloaded = try roundTrip(s)
        #expect(reloaded.startAttemptId(make: { "id-3" }) == "id-1")
        reloaded.registered(runId: "r", serverStartedAt: 1)
        #expect(reloaded.clientRunId == nil)
        #expect(RankingState.newGame.clientRunId == nil)
        #expect(running().forNewGame().clientRunId == nil)
    }

    // MARK: transiciones

    @Test("registered sólo mueve awaitingStart a running")
    func registeredOnlyFromAwaiting() {
        var s = RankingState.newGame
        let c1 = s.registered(runId: "a", serverStartedAt: 10)
        #expect(c1)
        #expect(s.phase == .running(runId: "a", serverStartedAt: 10))
        let c2 = s.registered(runId: "b", serverStartedAt: 20)
        #expect(!c2)
        #expect(s.phase == .running(runId: "a", serverStartedAt: 10))
        var legacy = RankingState.legacy
        let c3 = legacy.registered(runId: "a", serverStartedAt: 10)
        #expect(!c3)
        var arrived = god()
        let c4 = arrived.registered(runId: "z", serverStartedAt: 1)
        #expect(!c4)
    }

    @Test("reachedGod: running sella pendiente, awaitingStart no compite, el resto no cambia")
    func reachedGodTransitions() {
        var s = running()
        let c5 = s.reachedGod(at: 2_000)
        #expect(c5)
        #expect(s.phase == .reachedGod(runId: "r1", serverStartedAt: 1_000, sealed: false))
        let c6 = s.reachedGod(at: 3_000)
        #expect(!c6)

        var unregistered = RankingState.newGame
        let c7 = unregistered.reachedGod(at: 2_000)
        #expect(c7)
        #expect(unregistered.phase == .unregisteredGod)
        let c8 = unregistered.reachedGod(at: 3_000)
        #expect(!c8)

        var legacy = RankingState.legacy
        let c9 = legacy.reachedGod(at: 2_000)
        #expect(!c9)
        #expect(legacy.phase == .ineligible)
    }

    @Test("el tiempo jugado suma sesiones, ignora el reloj hacia atrás y la sesión huérfana")
    func playedSeconds() {
        var s = running()
        s.sessionEnded(at: 100)
        #expect(s.playedSeconds == 0)
        s.sessionBegan(at: 100)
        s.sessionEnded(at: 160)
        s.sessionBegan(at: 500)
        s.sessionEnded(at: 400)
        #expect(s.playedSeconds == 60)
        #expect(s.activeSince == nil)

        s.sessionBegan(at: 1_000)
        s.sessionBegan(at: 2_000)
        s.sessionEnded(at: 2_030)
        #expect(s.playedSeconds == 90)
    }

    @Test("llegar a Dios cierra la sesión y congela el tiempo jugado")
    func godFreezesPlayTime() {
        var s = running()
        s.sessionBegan(at: 100)
        s.reachedGod(at: 160)
        #expect(s.playedSeconds == 60)
        s.sessionEnded(at: 900)
        s.sessionBegan(at: 1_000)
        s.sessionEnded(at: 1_500)
        #expect(s.playedSeconds == 60)
    }

    @Test("el tiempo no corre en una partida heredada")
    func legacyDoesNotCount() {
        var s = RankingState.legacy
        s.sessionBegan(at: 0)
        s.sessionEnded(at: 100)
        #expect(s.playedSeconds == 0)
    }

    @Test("sealed fija los tiempos una sola vez")
    func sealedOnce() {
        var s = god()
        s.sealed(realSeconds: 4_000, underReview: true, nameStatus: .missing)
        #expect(s.phase == .reachedGod(runId: "r1", serverStartedAt: 1_000, sealed: true))
        #expect(s.submission == .init(nameStatus: .missing, realSeconds: 4_000, underReview: true))
        s.sealed(realSeconds: 9_999, underReview: false, nameStatus: .missing)
        #expect(s.submission?.realSeconds == 4_000)
        #expect(s.submission?.underReview == true)
    }

    @Test("sealed fuera de reachedGod no hace nada")
    func sealedOutsideGod() {
        var s = running()
        s.sealed(realSeconds: 1, underReview: false, nameStatus: .missing)
        #expect(s == running())
    }

    @Test("nameAnswered ok guarda lastName; pending y rejected no")
    func nameAnswers() {
        var ok = god(sealed: true)
        ok.nameAnswered("Fisu", status: .ok, rank: 7)
        #expect(ok.submission?.name == "Fisu")
        #expect(ok.submission?.nameStatus == .ok)
        #expect(ok.submission?.rank == 7)
        #expect(ok.lastName == "Fisu")

        var pending = god(sealed: true)
        pending.nameAnswered("Fisu", status: .pending, rank: nil)
        #expect(pending.submission?.nameStatus == .pending)
        #expect(pending.lastName == nil)

        var rejected = god(sealed: true)
        rejected.nameAnswered("Mal", status: .rejected, rank: nil)
        #expect(rejected.submission?.nameStatus == .rejected)
        #expect(rejected.lastName == nil)
    }

    @Test("nameAnswered antes del sello o fuera de Dios no hace nada")
    func nameAnsweredGuards() {
        var unsealed = god()
        unsealed.nameAnswered("Fisu", status: .ok, rank: 1)
        #expect(unsealed == god())
        var s = running()
        s.nameAnswered("Fisu", status: .ok, rank: 1)
        #expect(s == running())
    }

    @Test("nameChosen: acepta si falta o fue rechazado; no pisa uno ya aceptado o pendiente")
    func nameChosenRules() {
        var s = god(sealed: true)
        let c10 = s.nameChosen("Uno")
        #expect(c10)
        s.nameAnswered("Uno", status: .rejected, rank: nil)
        let c11 = s.nameChosen("Dos")
        #expect(c11)
        #expect(s.submission?.nameStatus == .missing)
        s.nameAnswered("Dos", status: .pending, rank: nil)
        let c12 = s.nameChosen("Tres")
        #expect(!c12)
        s.nameAnswered("Dos", status: .ok, rank: 3)
        let c13 = s.nameChosen("Tres")
        #expect(!c13)
        #expect(s.submission?.name == "Dos")

        var notGod = running()
        let c14 = notGod.nameChosen("X")
        #expect(!c14)
    }

    // MARK: trabajo pendiente

    @Test("pendingWork en cada fase")
    func pendingWorkPerPhase() {
        #expect(RankingState.legacy.pendingWork == .none)
        #expect(RankingState.newGame.pendingWork == .start)
        #expect(running().pendingWork == .none)
        #expect(god().pendingWork == .seal)
        #expect(god(sealed: true).pendingWork == .none)
        var unregistered = RankingState.newGame
        unregistered.reachedGod(at: 1)
        #expect(unregistered.pendingWork == .none)
    }

    @Test("pendingWork con un nombre por enviar, pendiente, aceptado y rechazado")
    func pendingWorkWithName() {
        var s = god(sealed: true)
        s.nameChosen("Fisu")
        #expect(s.pendingWork == .name("Fisu"))
        s.nameAnswered("Fisu", status: .rejected, rank: nil)
        #expect(s.pendingWork == .none)
        s.nameChosen("Otro")
        #expect(s.pendingWork == .name("Otro"))
        s.nameAnswered("Otro", status: .pending, rank: nil)
        #expect(s.pendingWork == .none)
        s.nameAnswered("Otro", status: .ok, rank: 2)
        #expect(s.pendingWork == .none)
    }

    @Test("un nombre elegido antes del sello manda primero el sello")
    func sealBeforeName() {
        var s = god()
        s.nameChosen("Fisu")
        #expect(s.pendingWork == .seal)
        s.sealed(realSeconds: 10, underReview: false, nameStatus: .missing)
        #expect(s.submission?.name == "Fisu")
        #expect(s.pendingWork == .name("Fisu"))
    }

    @Test("postponed no deja trabajo pendiente hasta que haya nombre")
    func postponedLeavesNothing() {
        var s = god(sealed: true)
        s.postponed()
        #expect(s.cardOffered)
        #expect(s.pendingWork == .none)
        s.nameChosen("Fisu")
        #expect(s.pendingWork == .name("Fisu"))
    }

    // MARK: reset

    @Test("forNewGame desde cada fase arranca en awaitingStart y conserva lastName")
    func forNewGamePerPhase() {
        var withName = running()
        withName.lastName = "Fisu"
        withName.playedSeconds = 99
        withName.cardOffered = true
        let phases: [RankingState] = [.legacy, .newGame, withName, god(), god(sealed: true)]
        for source in phases {
            let fresh = source.forNewGame()
            #expect(fresh.phase == .awaitingStart)
            #expect(fresh.playedSeconds == 0)
            #expect(fresh.activeSince == nil)
            #expect(fresh.submission == nil)
            #expect(!fresh.cardOffered)
            #expect(fresh.lastName == source.lastName)
        }
        #expect(withName.forNewGame().carriedSubmission == nil)
        var unregistered = RankingState.newGame
        unregistered.reachedGod(at: 1)
        #expect(unregistered.forNewGame().carriedSubmission == nil)
    }

    @Test("la llegada arrastrada lleva el tiempo jugado de su partida")
    func carriedSubmissionKeepsPlayedSeconds() throws {
        var unsealed = god()
        unsealed.playedSeconds = 119.6
        #expect(unsealed.forNewGame().carriedSubmission?.playedSeconds == 120)
        let legacy = try JSONDecoder().decode(RankingState.CarriedSubmission.self, from: Data(#"{"runId":"q"}"#.utf8))
        #expect(legacy.playedSeconds == 0)
    }

    @Test("forNewGame conserva la llegada a Dios que no se envió")
    func forNewGameCarriesUnsent() {
        #expect(god().forNewGame().carriedSubmission == .init(runId: "r1"))
        var named = god(sealed: true)
        named.nameChosen("Fisu")
        #expect(named.forNewGame().carriedSubmission == .init(runId: "r1", name: "Fisu", sealed: true))
        var rejected = god(sealed: true)
        rejected.nameAnswered("Mal", status: .rejected, rank: nil)
        #expect(rejected.forNewGame().carriedSubmission == .init(runId: "r1", sealed: true))
    }

    @Test("forNewGame no carga una llegada ya aceptada o pendiente, y no pierde la ya cargada")
    func forNewGameSkipsDelivered() {
        var ok = god(sealed: true)
        ok.nameAnswered("Fisu", status: .ok, rank: 1)
        #expect(ok.forNewGame().carriedSubmission == nil)
        var pending = god(sealed: true)
        pending.nameAnswered("Fisu", status: .pending, rank: nil)
        #expect(pending.forNewGame().carriedSubmission == nil)

        var again = god().forNewGame()
        again.carriedSubmission = .init(runId: "vieja")
        #expect(again.forNewGame().carriedSubmission == .init(runId: "vieja"))
        again.carriedSubmissionSent()
        #expect(again.carriedSubmission == nil)
    }

    // MARK: Codable

    @Test("ida y vuelta por JSON de cada fase")
    func codableRoundTrip() throws {
        var named = god(sealed: true)
        named.nameAnswered("Fisu", status: .ok, rank: 4)
        named.playedSeconds = 123.5
        named.sessionBegan(at: 77)
        var unregistered = RankingState.newGame
        unregistered.reachedGod(at: 1)
        var carrying = RankingState.newGame
        carrying.carriedSubmission = .init(runId: "x", name: "N", sealed: true)
        carrying.lastName = "Fisu"
        let all: [RankingState] = [.legacy, .newGame, running(), god(), god(sealed: true), named, unregistered, carrying]
        for state in all { #expect(try roundTrip(state) == state) }
    }

    @Test("un JSON sin ninguna clave decodifica a legacy")
    func emptyJSONIsLegacy() throws {
        let decoded = try JSONDecoder().decode(RankingState.self, from: Data("{}".utf8))
        #expect(decoded == .legacy)
        #expect(decoded.phase == .ineligible)
    }

    @Test("un JSON con sólo la fase decodifica con los defaults")
    func partialJSON() throws {
        let json = #"{"phase":{"awaitingStart":{}}}"#
        let decoded = try JSONDecoder().decode(RankingState.self, from: Data(json.utf8))
        #expect(decoded == .newGame)
    }

    @Test("el formato guardado queda fijado: un save ya escrito sigue leyéndose")
    func pinnedFormat() throws {
        let json = """
        {"phase":{"reachedGod":{"runId":"abc","serverStartedAt":1000.5,"sealed":true}},
         "playedSeconds":3600,"activeSince":50,
         "submission":{"name":"Fisu","nameStatus":"ok","realSeconds":7200,"underReview":false,"rank":3},
         "lastName":"Fisu","cardOffered":true,
         "carriedSubmission":{"runId":"old","name":"Z","sealed":true}}
        """
        let decoded = try JSONDecoder().decode(RankingState.self, from: Data(json.utf8))
        #expect(decoded.phase == .reachedGod(runId: "abc", serverStartedAt: 1000.5, sealed: true))
        #expect(decoded.playedSeconds == 3600)
        #expect(decoded.activeSince == 50)
        #expect(decoded.submission == .init(name: "Fisu", nameStatus: .ok, realSeconds: 7200, underReview: false, rank: 3))
        #expect(decoded.lastName == "Fisu")
        #expect(decoded.cardOffered)
        #expect(decoded.carriedSubmission == .init(runId: "old", name: "Z", sealed: true))
        let legacyCarry = try JSONDecoder().decode(RankingState.CarriedSubmission.self, from: Data(#"{"runId":"q"}"#.utf8))
        #expect(legacyCarry == .init(runId: "q"))

        let runningJSON = #"{"phase":{"running":{"runId":"r","serverStartedAt":9}},"playedSeconds":1}"#
        let r = try JSONDecoder().decode(RankingState.self, from: Data(runningJSON.utf8))
        #expect(r.phase == .running(runId: "r", serverStartedAt: 9))
        #expect(r.submission == nil)

        let sub = try JSONDecoder().decode(RankingState.Submission.self, from: Data("{}".utf8))
        #expect(sub == .init())
    }

    // MARK: resolve

    @Test("resolve: la misma partida, gana la fase más avanzada sin importar el winner")
    func resolveByPhase() {
        let early = running()
        let late = god()
        #expect(RankingState.resolve(winner: early, loser: late).phase == late.phase)
        #expect(RankingState.resolve(winner: late, loser: early).phase == late.phase)
    }

    @Test("resolve: una partida vieja no se vuelve elegible por un conflicto")
    func resolveLegacyStaysIneligible() {
        var old = RankingState.legacy
        old.playedSeconds = 500
        #expect(RankingState.resolve(winner: old, loser: .newGame).phase == .ineligible)
        #expect(RankingState.resolve(winner: old, loser: running()).phase == .ineligible)
        #expect(RankingState.resolve(winner: old, loser: god()).phase == .ineligible)
        #expect(RankingState.resolve(winner: .newGame, loser: old).phase == .awaitingStart)
    }

    @Test("resolve: a igual fase gana el winner; lastName cae al del perdedor")
    func resolveTieBreak() {
        var winner = running("a")
        var loser = running("b")
        loser.lastName = "Viejo"
        #expect(RankingState.resolve(winner: winner, loser: loser).phase == winner.phase)
        #expect(RankingState.resolve(winner: winner, loser: loser).lastName == "Viejo")
        winner.lastName = "Nuevo"
        #expect(RankingState.resolve(winner: winner, loser: loser).lastName == "Nuevo")
    }

    @Test("resolve: Dios sin registrar y Dios registrado son partidas distintas, manda el winner")
    func resolveGodKinds() {
        var unregistered = RankingState.newGame
        unregistered.reachedGod(at: 1)
        #expect(RankingState.resolve(winner: unregistered, loser: god()).phase == .unregisteredGod)
        #expect(RankingState.resolve(winner: god(), loser: unregistered).phase == god().phase)
    }

    @Test("resolve: tiempo jugado máximo sólo dentro de la misma partida")
    func resolvePlayedSeconds() {
        var a = running(); a.playedSeconds = 50
        var b = running(); b.playedSeconds = 80
        #expect(RankingState.resolve(winner: a, loser: b).playedSeconds == 80)
        #expect(RankingState.resolve(winner: b, loser: a).playedSeconds == 80)
        var legacy = RankingState.legacy; legacy.playedSeconds = 500
        #expect(RankingState.resolve(winner: a, loser: legacy).playedSeconds == 50)
        var other = running("otra"); other.playedSeconds = 900
        #expect(RankingState.resolve(winner: a, loser: other).playedSeconds == 50)
    }

    @Test("resolve: la misma llegada funde el sello y prefiere el nombre aceptado")
    func resolveSameArrival() {
        var named = god(sealed: true)
        named.nameAnswered("Fisu", status: .ok, rank: 2)
        let bare = god()
        let a = RankingState.resolve(winner: bare, loser: named)
        #expect(a.submission?.nameStatus == .ok)
        #expect(a.phase == .reachedGod(runId: "r1", serverStartedAt: 1_000, sealed: true))
        let b = RankingState.resolve(winner: named, loser: bare)
        #expect(b.submission?.name == "Fisu")

        var sealedNoName = god(sealed: true)
        sealedNoName.postponed()
        let c = RankingState.resolve(winner: sealedNoName, loser: named)
        #expect(c.submission?.nameStatus == .ok)
        #expect(c.cardOffered)
    }

    @Test("resolve: dos Dios con partidas distintas, la del winner entera; la ajena sin enviar se carga")
    func resolveDifferentArrivals() {
        var named = god("otra", sealed: true)
        named.nameAnswered("Fisu", status: .ok, rank: 2)
        let mine = god("mia", sealed: true)
        let r = RankingState.resolve(winner: mine, loser: named)
        #expect(r.phase == mine.phase)
        #expect(r.submission == mine.submission)
        #expect(r.submission?.nameStatus == .missing)
        #expect(r.carriedSubmission == nil)

        let unsent = god("ajena")
        let carried = RankingState.resolve(winner: mine, loser: unsent)
        #expect(carried.phase == mine.phase)
        #expect(carried.carriedSubmission == .init(runId: "ajena"))

        var already = mine
        already.carriedSubmission = .init(runId: "vieja")
        #expect(RankingState.resolve(winner: already, loser: unsent).carriedSubmission == .init(runId: "vieja"))
    }

    @Test("resolve: dos running con runId distintos, el winner")
    func resolveDifferentRuns() {
        let r = RankingState.resolve(winner: running("a"), loser: running("b"))
        #expect(r.phase == .running(runId: "a", serverStartedAt: 1_000))
    }

    @Test("resolve: el perdedor sin datos propios no cambia al ganador")
    func resolveIdentity() {
        let a = god("x", sealed: true)
        #expect(RankingState.resolve(winner: a, loser: a) == a)
    }
}
