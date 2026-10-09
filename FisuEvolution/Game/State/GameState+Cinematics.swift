import EconomyKit
import Foundation

/// Cuándo se reproduce una cinemática (PLAN-v2 E8): la de reencarnación cada vez,
/// la del arresto las dos primeras, la de Dios una por cuenta. El turno lo da la
/// cola (`CelebrationKind.cinematic`); acá sólo se pide y se anota.
extension GameState {
    func timesSeen(_ id: CinematicID) -> Int {
        player?.meta.engagement.seenCinematics[id.rawValue] ?? 0
    }

    func isCinematicDue(_ id: CinematicID) -> Bool {
        guard cinematicsAutorun, LoopsManifest.main.cinematicURL(for: id) != nil else { return false }
        return id.maxPlays.map { timesSeen(id) < $0 } ?? true
    }

    /// Pide el turno si le toca. Una sola a la vez: la que llega mientras otra
    /// espera se descarta (no hay dos momentos así en el mismo segundo).
    @discardableResult
    func playCinematicIfDue(_ id: CinematicID) -> Bool {
        guard cinematic == nil, isCinematicDue(id) else { return false }
        cinematic = id
        syncCelebrations()
        return true
    }

    /// La llama `releasePayload(.cinematic)`: el fin del video, "Saltar" y el
    /// watchdog cuentan igual — la pantalla ya fue suya.
    func recordCinematicSeen() {
        guard let id = cinematic else { return }
        cinematic = nil
        guard var player else { return }
        player.meta.engagement.recordCinematic(id.rawValue)
        self.player = player
        scheduleSave()
    }

    /// Al arrancar: lo que esperaba turno no se guarda, así que una partida parada en
    /// Dios que la cuenta todavía no vio (la app murió entre el reveal y la cinemática,
    /// o un veterano que llega a la 2.0 en el tope) se vuelve a pedir. Una vez vista no
    /// vuelve: `isCinematicDue` lo corta.
    func reconcileCinematics() {
        guard let godTier, let player, player.run.revealedTier >= godTier else { return }
        playCinematicIfDue(.dios)
    }
}
