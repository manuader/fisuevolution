import EconomyKit
import Foundation

/// La Marcha del Puntero (E14b B25, D16): 420 toques a mano en una hora de reloj real por 30 blue,
/// una vez por semana. Es el reto de toques de siempre (`ChallengeTerms`) con `realClock`: en vez de
/// vivir en el escenario (`stageChallenge`, reloj de juego activo) vive en el save
/// (`VisitorsState.march`), así que sigue con la app cerrada y se resuelve al volver. Cuenta en
/// cualquier piso y no traba nada: el Puntero se va apenas la acepta.
extension GameState {
    #if DEBUG
    /// `--uitest-marcha-corta`: la ventana del UI test.
    static let debugShortMarchSeconds: TimeInterval = 20
    #endif

    var march: MarchState? { player?.meta.engagement.visitors.march }

    /// Publica la Marcha del save (`shownMarch`) cuando cambia. La UI no puede leer `march`: sale de
    /// `player`, que no invalida nada, y el chip no se iba al cobrar, el contador no subía y el estado
    /// no abría (su presentador nunca había leído `marchPopup`).
    func refreshMarch() {
        let current = march
        if shownMarch != current { shownMarch = current }
    }

    /// Los guiones con cupo semanal no salen en la primera sesión ni antes de terminar el tutorial.
    var allowsWeeklyVisits: Bool {
        (player?.meta.engagement.visitors.sessions ?? 0) > 1 && TutorialFlags.coreCompleted(in: flagDefaults)
    }

    /// Una vez por proceso: el primer tick del motor de visitantes cuenta la sesión en el save.
    func countVisitorSessionIfNeeded() {
        guard !stageRuntime.sessionCounted, var player else { return }
        stageRuntime.sessionCounted = true
        VisitorScheduler.noteSessionStarted(&player.meta.engagement.visitors)
        self.player = player
        scheduleSave()
    }

    /// «¡Me prendo!»: arranca la Marcha con la fecha de pared y el Puntero se va.
    @discardableResult
    func beginMarch(scriptId: String, terms: ChallengeTerms, now: TimeInterval) -> Bool {
        guard var player else { return false }
        let terms = marchTerms(terms)
        guard VisitorScheduler.beginMarch(&player.meta.engagement.visitors, scriptId: scriptId, terms: terms, now: now)
        else { return false }
        self.player = player
        refreshMarch()
        finishVisit(saying: "visit.challenge.hint")
        scheduleSave()
        Log.economy.info("march started: \(scriptId)")
        return true
    }

    /// Los términos del dato; con `--uitest-marcha-corta`, la ventana del UI test.
    private func marchTerms(_ terms: ChallengeTerms) -> ChallengeTerms {
        #if DEBUG
        if stageRuntime.debugShortMarch {
            return ChallengeTerms(taps: terms.taps, windowSeconds: Self.debugShortMarchSeconds, coins: terms.coins,
                                  rewards: terms.rewards, realClock: true)
        }
        #endif
        return terms
    }

    /// Un toque a mano que dio monedas (`registerTap`). El autotoque y el segundo toque de una fusión
    /// asistida no pasan por acá.
    func noteMarchTap(now: TimeInterval = Date().timeIntervalSince1970) {
        guard var player, player.meta.engagement.visitors.march?.isRunning == true else { return }
        let won = VisitorScheduler.noteMarchTap(&player.meta.engagement.visitors, now: now)
        self.player = player
        refreshMarch()
        guard won else { return }
        scheduleSave()
        presentMarchResultIfDue()
    }

    /// Lo llama `advanceVisitors` en cada tick, con la fecha de pared: la que venció queda perdida y
    /// el final sale en el primer momento calmo. Sin Marcha en el save (se reseteó la partida), el
    /// popup que quedara abierto se cierra.
    func advanceMarch(now: TimeInterval = Date().timeIntervalSince1970) {
        defer { refreshMarch() }
        guard var player else { return }
        guard let march = player.meta.engagement.visitors.march else {
            if marchPopup != nil { marchPopup = nil }
            return
        }
        if march.isRunning {
            guard VisitorScheduler.resolveMarch(&player.meta.engagement.visitors, now: now) != nil else { return }
            self.player = player
            scheduleSave()
        }
        presentMarchResultIfDue()
    }

    /// El final (el festejo o la línea de la derrota) sale solo, sin encimarse con nada. Con el estado
    /// abierto, el estado pasa a ser el final.
    func presentMarchResultIfDue() {
        guard march?.outcome != nil else { return }
        if marchPopup == .status {
            marchPopup = .result
            return
        }
        guard marchPopup == nil, rewardDouble == nil, isCalmMoment else { return }
        marchPopup = .result
    }

    /// El chip: el estado mientras corre; resuelta, directo al final.
    func openMarchPopup() {
        guard let march, marchPopup == nil else { return }
        marchPopup = march.isRunning ? .status : .result
    }

    /// Cerrar el estado no cambia nada; el final no se cierra sin resolverse (`settleMarch`).
    func closeMarchStatus() {
        guard marchPopup == .status else { return }
        marchPopup = nil
    }

    /// El jugador cerró el final: la Marcha sale del save y, si la ganó, cobra con el vuelo de B13 y
    /// después sale el paso 2 de B29. Paga una sola vez: la segunda llamada no encuentra nada.
    @discardableResult
    func settleMarch(now: TimeInterval = Date().timeIntervalSince1970) -> MarchState? {
        marchPopup = nil
        guard var player, let march = VisitorScheduler.settleMarch(&player.meta.engagement.visitors) else { return nil }
        self.player = player
        refreshMarch()
        scheduleSave()
        guard march.outcome == .won else { return march }
        let source = "visit.\(march.scriptId)"
        creditCoins(march.coins)
        let granted = grant(march.rewards, source: source, now: now)
        announceReward(march.rewards, coins: max(0, march.coins) + granted)
        Log.economy.info("march won: \(march.scriptId)")
        offerGrantDouble(site: "double.marcha", placement: .visitor, coins: march.coins, rewards: march.rewards,
                         source: source)
        return march
    }

    #if DEBUG
    /// `--uitest-marcha-ganada`: una Marcha ya ganada en el save, para la foto del festejo.
    func debugSeedWonMarch(now: TimeInterval = Date().timeIntervalSince1970) {
        guard var player, let script = content?.visitors.scripts.first(where: \.realClock),
              case let .challenge(taps, windowSeconds, rewards, _) = script.mechanic
        else { return }
        player.meta.engagement.visitors.march = MarchState(
            scriptId: script.id, startedAt: now, endsAt: now + windowSeconds, goal: taps, coins: 0,
            rewards: rewards, taps: taps, outcome: .won
        )
        self.player = player
        refreshMarch()
    }
    #endif
}
