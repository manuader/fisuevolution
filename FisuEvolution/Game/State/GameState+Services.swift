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

    /// Los anuncios: los usan los cortes naturales (`+Ads`) y nunca el frame loop.
    func attachAds(_ coordinator: AdsCoordinator) {
        ads = coordinator
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
