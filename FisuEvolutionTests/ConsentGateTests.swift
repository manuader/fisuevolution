import AppTrackingTransparency
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La intro espera al consentimiento")
@MainActor
struct ConsentGateTests {
    /// Un reloj que no espera: cuenta los pasos y deja que el test actúe entre uno y otro.
    @MainActor private final class Clock {
        var ticks = 0
        var onTick: (Int) -> Void = { _ in }

        func sleep(_ duration: Duration) async {
            ticks += 1
            onTick(ticks)
            await Task.yield()
        }
    }

    private func gate(_ clock: Clock) -> ConsentGate {
        ConsentGate(cap: .seconds(10), tick: .milliseconds(100)) { await clock.sleep($0) }
    }

    @Test("vuelve apenas el consentimiento termina")
    func returnsWhenResolved() async {
        let clock = Clock()
        let gate = gate(clock)
        clock.onTick = { if $0 == 3 { gate.resolve() } }
        #expect(await gate.wait() == .resolved)
        #expect(clock.ticks == 3)
        #expect(!gate.mustYieldToCalm)
    }

    @Test("sin ningún diálogo en pantalla el tope es de 10 s y la intro sigue")
    func capExpiresWithoutADialog() async {
        let clock = Clock()
        let gate = gate(clock)
        #expect(await gate.wait() == .gaveUp)
        #expect(clock.ticks == 100)
        #expect(gate.mustYieldToCalm)
    }

    @Test("con un diálogo en pantalla no hay tope: se espera la respuesta")
    func noCapWhileADialogIsUp() async {
        let clock = Clock()
        let gate = gate(clock)
        gate.dialogAppeared()
        clock.onTick = { if $0 == 5_000 { gate.resolve() } }
        #expect(await gate.wait() == .resolved)
        #expect(clock.ticks == 5_000)
    }

    @Test("el tiempo sin diálogo cuenta, y el diálogo lo congela")
    func capOnlyCountsTimeWithoutADialog() async {
        let clock = Clock()
        let gate = gate(clock)
        clock.onTick = {
            if $0 == 40 { gate.dialogAppeared() }
            if $0 == 1_040 { gate.dialogDismissed() }
        }
        #expect(await gate.wait() == .gaveUp)
        #expect(clock.ticks == 1_100, "40 antes + 1000 con el diálogo + 60 hasta completar los 100")
    }

    @Test("quien no tiene nada que responder no espera")
    func skipWaiting() async {
        let clock = Clock()
        let gate = gate(clock)
        gate.skipWaiting()
        #expect(await gate.wait() == .gaveUp)
        #expect(clock.ticks == 0)
    }

    @Test("el consentimiento que la intro no esperó cede el paso a un momento tranquilo")
    func yieldsToCalm() async {
        let clock = Clock()
        let gate = gate(clock)
        var calm = false
        clock.onTick = { if $0 == 7 { calm = true } }
        gate.skipWaiting()
        await gate.waitForCalm { calm }
        #expect(clock.ticks == 7)
    }

    @Test("si la intro esperó, no hay nada que ceder")
    func noYieldWhenIntroWaited() async {
        let clock = Clock()
        let gate = gate(clock)
        await gate.waitForCalm { false }
        #expect(clock.ticks == 0)
    }

    // MARK: - La intro en GameState

    private func world(_ gate: ConsentGate?) async -> GameState {
        let gameState = await makeGameState()
        gameState.cinematicsAutorun = true
        if let gate { gameState.attachConsentGate(gate) }
        return gameState
    }

    @Test("la intro no empieza antes de la señal y empieza con ella")
    func introWaitsForTheSignal() async {
        let clock = Clock()
        let gate = gate(clock)
        gate.dialogAppeared()
        let gameState = await world(gate)
        #expect(gameState.reconcileIntro(isNewGame: true))
        #expect(gameState.showing == nil)
        #expect(gameState.cinematic == nil)
        await Task.yield()
        #expect(gameState.cinematic == nil, "con el formulario en pantalla sigue esperando")
        gate.resolve()
        await gameState.introWait?.value
        #expect(gameState.showing == .cinematic)
        #expect(gameState.cinematic == .intro)
    }

    @Test("con el tope vencido la intro arranca igual")
    func introStartsWhenTheCapExpires() async {
        let gate = gate(Clock())
        let gameState = await world(gate)
        #expect(gameState.reconcileIntro(isNewGame: true))
        await gameState.introWait?.value
        #expect(gameState.showing == .cinematic)
        #expect(gate.mustYieldToCalm)
    }

    @Test("mientras espera, el reveal del tablero no le pasa por delante")
    func queueStaysStillWhileWaiting() async {
        let gate = gate(Clock())
        gate.dialogAppeared()
        let gameState = await world(gate)
        gameState.reconcileIntro(isNewGame: true)
        gameState.celebrations.enqueue(.boardCelebration)
        gameState.syncCelebrations()
        #expect(gameState.showing == nil)
        gate.resolve()
        await gameState.introWait?.value
        #expect(gameState.showing == .cinematic, "la intro toma el turno antes que el reveal")
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.showing == .boardCelebration)
    }

    @Test("el tutorial arranca después de la intro, no durante la espera")
    func tutorialStartsAfterTheIntro() async {
        let gate = gate(Clock())
        gate.dialogAppeared()
        let gameState = await world(gate)
        gameState.reconcileIntro(isNewGame: true)
        gameState.tutorialStartAfterIntro = true
        #expect(!gameState.tutorialPhaseActive)
        gate.resolve()
        await gameState.introWait?.value
        #expect(gameState.cinematic == .intro)
        #expect(!gameState.tutorialStartAfterIntro)
    }

    @Test("quien ya consintió, o no tiene formulario: la intro arranca sin espera")
    func noWaitWhenAlreadyResolved() async {
        let gate = gate(Clock())
        gate.resolve()
        let gameState = await world(gate)
        #expect(!gameState.reconcileIntro(isNewGame: true))
        #expect(gameState.showing == .cinematic)
        #expect(gameState.introWait == nil)
    }

    @Test("sin señal conectada (tests, desarrollo) la intro arranca como siempre")
    func noGateNoWait() async {
        let gameState = await world(nil)
        #expect(!gameState.reconcileIntro(isNewGame: true))
        #expect(gameState.showing == .cinematic)
    }

    @Test("un save viejo da la intro por vista sin esperar al consentimiento")
    func veteransDoNotWait() async {
        let gate = gate(Clock())
        gate.dialogAppeared()
        let gameState = await world(gate)
        #expect(!gameState.reconcileIntro(isNewGame: false))
        #expect(gameState.player?.meta.engagement.seenCinematics["intro"] == 1)
    }

    // MARK: - El ATT nunca encima de una cinemática ni de una lección

    @Test("el consentimiento diferido espera a que la cinemática termine")
    func deferredConsentWaitsForTheCinematic() async {
        let clock = Clock()
        let gate = gate(clock)
        let gameState = await world(gate)
        gameState.playCinematicIfDue(.intro)
        gate.skipWaiting()
        clock.onTick = { if $0 == 20 { gameState.celebrationFinished(.cinematic) } }
        await gate.waitForCalm { gameState.isCalmMoment }
        #expect(clock.ticks >= 20)
        #expect(gameState.showing != .cinematic)
    }

    @Test("ni encima de la fase obligatoria del tutorial")
    func deferredConsentWaitsForTheTutorial() async {
        let clock = Clock()
        let gate = gate(clock)
        let gameState = await world(gate)
        gameState.beginTutorialPhase()
        gate.skipWaiting()
        var calmWhileTutorial = false
        clock.onTick = { _ in calmWhileTutorial = calmWhileTutorial || gameState.isCalmMoment }
        await gate.waitForCalm { clock.ticks >= 5 }
        #expect(!calmWhileTutorial)
        #expect(clock.ticks == 5)
    }

    // MARK: - Decisiones puras

    @Test("la intro sólo espera a quien tiene algo que responder")
    func introNeedsToWait() {
        #expect(AdsConsent.introNeedsToWait(attStatus: .notDetermined, canRequestAds: true))
        #expect(AdsConsent.introNeedsToWait(attStatus: .authorized, canRequestAds: false))
        #expect(!AdsConsent.introNeedsToWait(attStatus: .authorized, canRequestAds: true))
        #expect(!AdsConsent.introNeedsToWait(attStatus: .denied, canRequestAds: true))
    }

    @Test("el tope se levanta sólo cuando UMP va a mostrar algo")
    func formIsLikely() {
        #expect(AdsConsent.formIsLikely(consentRequired: true, formAvailable: true, attUndetermined: false))
        #expect(AdsConsent.formIsLikely(consentRequired: false, formAvailable: true, attUndetermined: true))
        #expect(!AdsConsent.formIsLikely(consentRequired: false, formAvailable: true, attUndetermined: false))
        #expect(!AdsConsent.formIsLikely(consentRequired: false, formAvailable: false, attUndetermined: true))
    }

    @Test("la geografía de prueba sale del argumento de lanzamiento")
    func debugGeography() {
        #expect(AdsConsent.debugConsentGeography(arguments: ["--debug-consent-eea"]) == .eea)
        #expect(AdsConsent.debugConsentGeography(arguments: ["--debug-consent-us"]) == .regulatedUSState)
        #expect(AdsConsent.debugConsentGeography(arguments: []) == nil)
    }
}
