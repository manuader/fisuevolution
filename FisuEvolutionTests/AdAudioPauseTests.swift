import Foundation
import Testing
@testable import FisuEvolution

/// E14b B1: mientras hay un anuncio de pantalla completa en pantalla no suena nada del juego, y al
/// cerrarse —por el desenlace que sea— vuelve lo que sonaba. Dos capas: el coordinador pausa y
/// reanuda una sola vez por anuncio (con un espía en el lugar del audio), y el `AudioManager` pausa
/// y reanuda de verdad sus players sin prender lo que estaba apagado.
@MainActor
private final class AudioSpy: AdAudioGate {
    private(set) var events: [String] = []
    var pauses: Int { events.filter { $0 == "pause" }.count }
    var resumes: Int { events.filter { $0 == "resume" }.count }
    func pauseForAd() { events.append("pause") }
    func resumeAfterAd() { events.append("resume") }
}

@Suite("Audio en pausa durante los anuncios")
@MainActor
struct AdAudioPauseTests {
    private func makeCoordinator() -> (AdsCoordinator, ScriptedAdsProvider, AudioSpy) {
        let provider = ScriptedAdsProvider()
        let coordinator = AdsCoordinator(provider: provider)
        let spy = AudioSpy()
        coordinator.attachAudio(spy)
        return (coordinator, provider, spy)
    }

    // MARK: - Coordinador: cada desenlace, una pausa y un resume

    @Test("un rewarded visto completo pausa al empezar y reanuda al cerrar")
    func rewardedWatched() async {
        let (ads, provider, spy) = makeCoordinator()
        provider.holdsOpen = true
        let task = Task { await ads.showRewarded(for: .gifts) }
        await provider.waitUntilShowing()
        #expect(spy.events == ["pause"], "calla mientras el anuncio está en pantalla")
        provider.closeCurrentAd()
        #expect(await task.value)
        #expect(spy.events == ["pause", "resume"])
    }

    @Test("un rewarded cerrado antes de ganar el premio también reanuda")
    func rewardedClosedEarly() async {
        let (ads, provider, spy) = makeCoordinator()
        provider.earnsReward = false
        #expect(await ads.showRewarded(for: .gifts) == false)
        #expect(spy.events == ["pause", "resume"])
    }

    @Test("un rewarded que no se pudo presentar o no cargó reanuda igual")
    func rewardedFailedToPresent() async {
        let (ads, provider, spy) = makeCoordinator()
        provider.hasInventory = false
        #expect(await ads.showRewarded(for: .gifts) == false)
        #expect(spy.events == ["pause", "resume"])
    }

    @Test("un rewarded cancelado mientras cargaba reanuda igual")
    func rewardedCancelledWhileLoading() async {
        let (ads, provider, spy) = makeCoordinator()
        provider.loadDelay = .seconds(30)
        let task = Task { await ads.showRewarded(for: .gifts) }
        while spy.pauses == 0 { await Task.yield() }
        task.cancel()
        #expect(await task.value == false)
        #expect(spy.events == ["pause", "resume"])
    }

    @Test("el intersticial, la pausa publicitaria y el app open: visto y sin inventario")
    func forcedFormats() async {
        let (ads, provider, spy) = makeCoordinator()
        await ads.showInterstitial()
        _ = await ads.showRewardedInterstitial()
        await ads.showAppOpen()
        #expect(spy.events == Array(repeating: ["pause", "resume"], count: 3).flatMap { $0 })

        provider.hasInventory = false
        await ads.showInterstitial()
        _ = await ads.showRewardedInterstitial()
        await ads.showAppOpen()
        #expect(spy.pauses == 6 && spy.resumes == 6, "sin inventario también se cierra el par")
    }

    @Test("un segundo anuncio rechazado por el que está en pantalla no reanuda el audio del primero")
    func rejectedSecondAdDoesNotResume() async {
        let (ads, provider, spy) = makeCoordinator()
        provider.holdsOpen = true
        let first = Task { await ads.showRewarded(for: .gifts) }
        await provider.waitUntilShowing()
        #expect(await ads.showRewardedInterstitial() == false)
        #expect(await ads.showRewarded(for: .gifts) == false)
        await ads.showInterstitial()
        #expect(spy.events == ["pause"], "ni pausa de más ni resume antes de tiempo")
        provider.closeCurrentAd()
        _ = await first.value
        #expect(spy.events == ["pause", "resume"])
    }

    @Test("con remove_ads el intersticial ni se presenta: el audio no se toca")
    func removedAdsDoesNotTouchAudio() async {
        let (ads, _, spy) = makeCoordinator()
        ads.setRemovedAds(true)
        await ads.showInterstitial()
        #expect(spy.events.isEmpty)
    }

    // MARK: - AudioManager: pausa y reanuda de verdad

    @Test("un ambiente que suena se pausa con el anuncio y vuelve al cerrarse")
    func ambientPausesAndResumes() {
        let audio = AudioManager()
        audio.sfxVolume = 0.9
        audio.startAmbient(.packageRattle)
        #expect(audio.debugIsPlaying(.packageRattle))

        audio.pauseForAd()
        #expect(!audio.debugIsPlaying(.packageRattle))
        audio.resumeAfterAd()
        #expect(audio.debugIsPlaying(.packageRattle))
        audio.stop(.packageRattle)
    }

    @Test("durante el anuncio no arranca ningún efecto ni ambiente nuevo")
    func nothingStartsDuringAnAd() {
        let audio = AudioManager()
        audio.sfxVolume = 0.9
        audio.pauseForAd()
        audio.play(.coin)
        audio.startAmbient(.mattressSqueak)
        #expect(!audio.debugIsPlaying(.coin))
        #expect(!audio.debugIsPlaying(.mattressSqueak))
        audio.resumeAfterAd()
        #expect(!audio.debugIsPlaying(.mattressSqueak), "lo que no sonaba antes no se prende al volver")
    }

    @Test("la música sigue la misma regla, y apagada en Ajustes no se prende sola")
    func musicPausesAndStaysOffWhenMuted() async {
        let audio = AudioManager()
        await audio.startMusic()
        #expect(audio.debugIsMusicPlaying)
        audio.pauseForAd()
        #expect(!audio.debugIsMusicPlaying)
        audio.resumeAfterAd()
        #expect(audio.debugIsMusicPlaying)

        // Música parada de antemano (otro player sin arrancar): el resume no inventa nada.
        let silent = AudioManager()
        silent.pauseForAd()
        silent.resumeAfterAd()
        #expect(!silent.debugIsMusicPlaying)
    }

    @Test("pausar o reanudar dos veces no hace nada de más")
    func pauseAndResumeAreIdempotent() {
        let audio = AudioManager()
        audio.startAmbient(.packageRattle)
        audio.pauseForAd()
        audio.pauseForAd()
        #expect(audio.isPausedForAd)
        audio.resumeAfterAd()
        audio.resumeAfterAd()
        #expect(!audio.isPausedForAd)
        #expect(audio.debugIsPlaying(.packageRattle))
        audio.stop(.packageRattle)
    }

    @Test("un efecto cortado durante el anuncio no resucita al cerrarse")
    func stoppedDuringAdStaysStopped() {
        let audio = AudioManager()
        audio.startAmbient(.packageRattle)
        audio.pauseForAd()
        audio.stop(.packageRattle)
        audio.resumeAfterAd()
        #expect(!audio.debugIsPlaying(.packageRattle))
    }
}
