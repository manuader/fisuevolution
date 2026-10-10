import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    // MARK: Frame loop (called by BoardScene)

    /// Passive income tick. Mutates only non-observed state — zero SwiftUI work.
    func tick(delta: TimeInterval) {
        guard isSceneActive, let content, var player else { return }
        IncomeTicker.tick(
            state: &player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            delta: delta * debugTimeScale,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        advanceEngagement(delta: min(delta, IncomeTicker.deltaClampThreshold))
        // El watchdog de la cola de celebraciones corre acá y no en un `Timer`
        // (regla 2 de concurrencia). `delta` sin `debugTimeScale`: el time-warp
        // acelera la economía, no el tiempo que el jugador tiene para mirar. Con el
        // mismo tope que la plata: el primer frame tras volver del background trae
        // todo el salto, y el watchdog no debe darlo todo por vencido.
        advanceCelebrations(delta: min(delta, IncomeTicker.deltaClampThreshold))
    }

    /// 8 Hz projection flush driven by the scene's frame counter. Also prunes
    /// expired modifiers and retires the event banner.
    ///
    /// Con la escena inactiva sólo proyecta: el regreso del background pasa por
    /// `.inactive` con la escena ya dibujando, y podar buffs, disparar el evento
    /// vencido o armar el anuncio ahí se adelanta a lo que `.active` resuelve
    /// (el offline integra los buffs que vencieron afuera, el evento se corre y
    /// la gracia de sesión se reinicia).
    func flushHUD() {
        let now = Date().timeIntervalSince1970
        if isSceneActive {
            if var player {
                let pruned = ModifierMath.prune(&player, now: now)
                if pruned {
                    self.player = player
                    scheduleSave()
                }
            }
            expireActiveEvent(now: now)
            beatIfDue(now: now)
        }
        refreshProjections()
    }
}
