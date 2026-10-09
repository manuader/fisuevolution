import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    /// Servicios opcionales detrás de feature flags (Game Center, CloudKit).
    func attachGameCenter(_ manager: GameCenterManager) {
        gameCenter = manager
    }

    func attachHaptics(_ manager: HapticsManager) {
        haptics = manager
    }

    /// Los anuncios. Los usa `+Prestige` (interstitial post-reencarnación) y
    /// el cierre del popup de offline; nunca el frame loop.
    func attachAds(_ coordinator: AdsCoordinator) {
        ads = coordinator
    }

    /// Si ESTE instante es un buen momento para tapar la pantalla con un
    /// interstitial.
    ///
    /// El pedido del dueño fue "un anuncio cada 5 o 10 minutos de juego"; el
    /// reloj que cuenta eso vive en `AdsCoordinator`. Esta propiedad contesta la
    /// otra mitad —**dónde** se puede— y las cuatro condiciones son cada una un
    /// caso que se ve horrible si se saltea:
    ///
    /// - `phase == .ready`: no durante la carga.
    /// - `!uiCoversBoard`: no encima de una hoja abierta; sería un anuncio
    ///   sobre un panel que el jugador estaba leyendo.
    /// - `celebrations.current == nil`: no encima de un ascenso, un cofre o un
    ///   premio. Es el momento de más dopamina del juego y taparlo con
    ///   publicidad es la peor decisión posible.
    /// - `!tutorialPhaseActive`: nunca durante el tutorial. Un jugador que
    ///   todavía no entendió el juego y come un anuncio, desinstala.
    ///
    /// ⚠️ Que sea "buen momento" NO alcanza para mostrar nada: también tiene que
    /// tocarle por reloj. Las dos mitades se juntan en
    /// `showInterstitialIfArmed()`, y ninguna de las dos sirve sola.
    var isSafeMomentForInterstitial: Bool {
        phase == .ready
            && !uiCoversBoard
            && celebrations.current == nil
            && !tutorialPhaseActive
    }

    /// Pide un interstitial si le toca Y estamos en un buen momento. La llama la
    /// UI al volver al tablero desde una pantalla.
    func showInterstitialIfAppropriate() async {
        guard isSafeMomentForInterstitial else { return }
        await ads?.showInterstitialIfArmed()
    }

    func attachAudio(_ manager: AudioManager) {
        audio = manager
    }

    /// Las fusiones que no hizo el jugador también suenan; en "Fusionar todo"
    /// el plin sube de tono eslabón a eslabón.
    func playBoardMergeFeedback(chainIndex: Int?, evolved: Bool) {
        let rate = chainIndex.map { MergeAllTempo(reduceMotion: false).pitch(index: $0) } ?? 1
        audio?.play(evolved ? .evolution : .merge, rate: evolved ? 1 : rate)
        if !evolved { haptics?.play(.merge) }
    }

    func playMergeAllFinale() {
        audio?.play(.mergeAllDone)
        haptics?.play(.mergeAllFinale)
    }

    func attachBackgroundTasks(_ runner: any BackgroundTaskRunning) {
        backgroundTasks = runner
    }

    func playRevealWhoosh() {
        audio?.play(.revealWhoosh)
    }

    /// La escena pide feedback háptico sin conocer al manager.
    func playHaptic(_ pattern: HapticsManager.Pattern) {
        haptics?.play(pattern)
    }

    /// Un ascenso no es un merge más: la unidad se muda de piso. Se le da un
    /// acento propio para que se distinga del merge que se queda en el lugar.
    func playAscentFeedback() {
        haptics?.play(.evolution)
        audio?.play(.rare)
    }

    /// Abrir un piso es el hito grande del loop de la torre; lleva el acento más
    /// fuerte que tenemos, a la par de la reencarnación.
    func playFloorUnlockFeedback() {
        haptics?.play(.rarity)
        audio?.play(.prestige)
    }
}
