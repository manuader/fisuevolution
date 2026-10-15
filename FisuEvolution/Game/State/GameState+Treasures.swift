import EconomyKit
import Foundation

/// Lo que salió de un colchón, ya acreditado.
struct MattressOutcome: Equatable {
    let prizeId: String
    let rewards: [RewardSpec]
    /// La plata acreditada (0 si el premio no era plata).
    let coins: Double
    /// Los "otro colchón" que le quedan.
    let extraOpensLeft: Int
    /// Llegó de regalo (D4): al cobrarlo ofrece su ×2 con video (E14b B29). El pagado y el «otro colchón», no.
    var isGift = false
}

/// El Colchón en la partida (PLAN-v2 E5): "tus empleados escondieron plata en
/// el colchón". El recorrido (E14b B6, D3/D4): aparece en la columna y se paga con un
/// video, o llega de regalo; en los dos casos cae al tablero, y ahí se abre.
extension GameState {
    private var mattressPhase: TreasuresState.Phase { player?.meta.engagement.treasures.phase ?? .none }

    /// En la columna, esperando su video.
    var mattressWaiting: Bool { mattressPhase == .waiting }

    /// Pagado o regalado: en el tablero, listo para abrir.
    var mattressOnBoard: Bool { mattressPhase == .onBoard }

    /// Hay uno en juego, en la columna o en el tablero: el reloj no corre.
    var mattressInPlay: Bool { mattressPhase != .none }

    var mattressExtraOpensLeft: Int { player?.meta.engagement.treasures.extraOpensLeft ?? 0 }

    /// El «otro colchón» de uno ya abierto sigue guardado: sobrevive a cerrar el
    /// popup y a matar la app, hasta que aparece un colchón nuevo.
    var mattressExtraPending: Bool { mattressPhase == .none && mattressExtraOpensLeft > 0 }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advanceTreasures(delta: TimeInterval) {
        guard engagementAutorun, !tutorialPhaseActive, mattressPopup == nil, let content, var player else { return }
        let arrival = TreasureScheduler.advance(&player.meta.engagement.treasures, delta: delta,
                                                config: content.treasures, using: &rng)
        self.player = player
        guard let arrival else { return }
        let kind = arrival == .gift ? "gift" : "column"
        Log.economy.info("mattress appeared: \(kind)")
        scheduleSave()
    }

    /// Se miró el video de la columna: el colchón cae al tablero, todavía cerrado.
    @discardableResult
    func payMattress() -> Bool {
        guard var player, TreasureScheduler.markPaid(&player.meta.engagement.treasures) else { return false }
        self.player = player
        Log.economy.info("mattress paid")
        scheduleSave()
        return true
    }

    /// Se abrió el del tablero: sortea, acredita y habilita "otro colchón".
    @discardableResult
    func openMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, mattressOnBoard,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player
        else { return nil }
        let gifted = player.meta.engagement.treasures.gifted
        guard TreasureScheduler.markOpened(&player.meta.engagement.treasures, config: content.treasures) else { return nil }
        self.player = player
        return deliver(prize, now: now, gifted: gifted)
    }

    /// Después del segundo video: otro sorteo, una vez por colchón.
    @discardableResult
    func openExtraMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, player?.meta.engagement.treasures.extraOpensLeft ?? 0 > 0,
              let prize = TreasureRoller.roll(content.treasures, using: &rng),
              var player
        else { return nil }
        player.meta.engagement.treasures.extraOpensLeft -= 1
        self.player = player
        return deliver(prize, now: now)
    }

    /// El colchón ya quedó gastado: acredita su premio por el único punto de premios.
    private func deliver(_ prize: TreasuresConfig.Prize, now: TimeInterval, gifted: Bool = false) -> MattressOutcome {
        let coins = grant(prize.rewards, source: "treasure.\(prize.id)", now: now)
        announceReward(prize.rewards, coins: coins)
        Log.economy.info("mattress opened: \(prize.id)")
        return MattressOutcome(prizeId: prize.id, rewards: prize.rewards, coins: coins,
                               extraOpensLeft: mattressExtraOpensLeft, isGift: gifted)
    }

    #if DEBUG
    /// En la columna; `onBoard`: ya pagado o regalado, en el tablero; `extraSaved`: el colchón ya
    /// se abrió y le queda «otro colchón» guardado.
    func debugSpawnMattress(onBoard: Bool = false, extraSaved: Bool = false) {
        guard var player else { return }
        player.meta.engagement.treasures.phase = extraSaved ? .none : onBoard ? .onBoard : .waiting
        player.meta.engagement.treasures.extraOpensLeft = extraSaved ? 1 : 0
        self.player = player
    }
    #endif
}
