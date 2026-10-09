import EconomyKit
import Foundation

/// La cola que hace que las celebraciones se reproduzcan **de a una**
/// (`Docs/superpowers/specs/2026-08-06-cola-de-celebraciones-design.md`).
///
/// El reparto es a propósito: `CelebrationQueue` —en EconomyKit, pura— decide el
/// TURNO sobre identificadores, y esta extensión es el único lugar que conoce los
/// payloads. Las vistas no llaman a la cola: leen `showing`.
extension GameState {
    // MARK: Entrar a la cola

    /// Encola una celebración. Deduplica, así que llamarla de más es gratis.
    func celebrate(_ kind: CelebrationKind) {
        celebrations.enqueue(kind)
        publishCelebration()
    }

    /// Encola la del tablero anotando si ESA trae algo nuevo —personaje o piso—,
    /// que es lo único que apaga la UI (ver `celebrationHidesUI`).
    ///
    /// La bandera es del payload y no del turno: mientras la del tablero espera
    /// en la fila la cola la deduplica en un solo casillero y la escena pisa su
    /// payload con el del último merge, así que lo que se reproduce es el último
    /// y la bandera tiene que ser la del último también.
    func celebrateBoard(showsSomethingNew: Bool) {
        // Salvo que ya esté EN PANTALLA: ahí la escena tampoco cambia lo que está
        // reproduciendo —se quedó con el vuelo que arrancó y `enqueue` deduplica
        // el turno—, así que pisar la bandera prendería el HUD a la mitad del
        // vuelo que el jugador está mirando.
        if celebrations.current != .boardCelebration {
            boardCelebrationShowsSomethingNew = showsSomethingNew
        }
        celebrate(.boardCelebration)
    }

    /// La bandera de "algo nuevo" del cambio que arranca su turno. A diferencia de
    /// `celebrateBoard`, el turno ya es suyo: se publica en el acto.
    ///
    /// Sólo prende: si la celebración que está en pantalla ya la prendió —un
    /// merge del jugador con un personaje nuevo—, bajarla devolvería el HUD a
    /// mitad del vuelo, que es lo que `celebrateBoard` también evita.
    func setBoardCelebrationShowsSomethingNew(_ value: Bool) {
        if value { boardCelebrationShowsSomethingNew = true }
        publishCelebration()
    }

    /// El eslabón siguiente de "Fusionar todo" sigue en el mismo turno: el reloj
    /// del watchdog vuelve a cero. La bandera de "algo nuevo" ya es la suya:
    /// `beginNextChainLink` la baja antes de arrancarlo.
    func renewBoardTurnForNextLink() {
        celebrations.renew(.boardCelebration)
    }

    /// Encola lo que tenga payload y todavía no esté en la fila.
    ///
    /// Se llama después de cada acción que puede crear una celebración, en vez
    /// de poner un `celebrate(...)` al lado de cada una de las doce asignaciones
    /// repartidas en seis archivos. Es idempotente por la deduplicación de la
    /// cola, así que el modo de fallar es "se llamó de más", no "alguien se
    /// olvidó de encolar y esa celebración no aparece nunca".
    func syncCelebrations() {
        if offlineReward != nil { celebrations.enqueue(.offlineEarnings) }
        if dailyClaim != nil { celebrations.enqueue(.dailyReward) }
        if careerPrompt != nil { celebrations.enqueue(.careerChoice) }
        if skinAward != nil { celebrations.enqueue(.skinAward) }
        if specialDrop != nil { celebrations.enqueue(.specialDrop) }
        if chestReward != nil { celebrations.enqueue(.chestOpening) }
        if towerNotice != nil { celebrations.enqueue(.towerNotice) }
        if achievementToast != nil || !pendingAchievementToasts.isEmpty {
            celebrations.enqueue(.achievements)
        }
        if let event = activeEvent, event.id != announcedEventID {
            celebrations.enqueue(.eventBanner)
        }
        if tutorialTip != nil { celebrations.enqueue(.tutorialTip) }
        if boardIsVisibleForChanges, !pendingBoardChanges.isEmpty || typePendingReveal != nil {
            celebrations.enqueue(.boardCelebration)
        }
        publishCelebration()
    }

    // MARK: El tutorial como cliente

    /// Arranca la fase obligatoria del tutorial: desde acá y hasta
    /// `tutorialPhaseFinished()`, la cola sólo promueve el reveal del tablero
    /// —que es EL momento de la fase, no un estorbo— y todo lo demás queda en
    /// `pending`: no se presenta (su sheet está gateado por el tutorial y
    /// congelaría la cola) ni se pierde.
    func beginTutorialPhase() {
        tutorialPhaseActive = true
        celebrations.restrict(to: [.boardCelebration])
        publishCelebration()
    }

    /// La fase terminó (el botón del cierre o "Saltar"): se levanta la
    /// restricción y lo que esperó su turno desfila en su orden de siempre —
    /// el daily del día 2 primero, después la skin, al final los toasts.
    ///
    /// Y acá cae el **cofre de bienvenida**, que es el momento que el dueño pidió
    /// para enseñar la mecánica: el jugador acaba de fusionar y todavía no vio
    /// una sola pinta. Cae por las DOS salidas de la fase —el botón del cierre y
    /// "Saltar"—, porque saltear el tutorial no puede costarle la única pinta
    /// temprana que el juego reparte.
    ///
    /// ⚠️ **Se otorga DESPUÉS de levantar la restricción**, y el orden es la
    /// decisión: así el cofre entra a la cola detrás de lo que ya estaba
    /// esperando, en vez de pasarle por encima con su prioridad. En una partida
    /// nueva no hay nada esperando —no hay offline, el día 1 del daily no se
    /// cobra y la carrera está a horas de distancia—, así que en la práctica se
    /// abre en el acto.
    func tutorialPhaseFinished() {
        guard tutorialPhaseActive else { return }
        tutorialPhaseActive = false
        celebrations.restrict(to: nil)
        rankingCoreFinished()
        grantWelcomeChest()
        // El primer paso del permiso de notificaciones (E11): provisional, sin diálogo.
        requestProvisionalNotifications()
        syncCelebrations()
    }

    // MARK: Salir de la cola

    /// Terminó el ítem: lo cerró el jugador, se cerró solo, o la escena avisó.
    func celebrationFinished(_ kind: CelebrationKind) {
        celebrations.finish(kind)
        releasePayload(for: kind)
        syncCelebrations()
    }

    /// El jugador tocó la pantalla. Saltea el ítem actual **entero** si es
    /// salteable y ya pasó el piso de tiempo. Devuelve si salteó algo.
    @discardableResult
    func skipCurrentCelebration() -> Bool {
        guard let showingNow = celebrations.current else { return false }
        guard celebrations.skip() else { return false }
        releasePayload(for: showingNow)
        syncCelebrations()
        return true
    }

    /// Corre el watchdog. Lo llama el tick que ya existe por frame: sin `Timer`
    /// (regla 2 de concurrencia) y con tests que inyectan deltas en vez de
    /// esperar segundos reales.
    func advanceCelebrations(delta: TimeInterval) {
        guard let expired = celebrations.tick(delta) else { return }
        // No es un caso normal: es el síntoma de que una animación no avisó que
        // terminó. Sin el watchdog eso congelaría TODAS las celebraciones hasta
        // reiniciar la app, así que se destraba y se deja el rastro.
        Log.lifecycle.error("celebración destrabada por watchdog: \(expired.rawValue)")
        releasePayload(for: expired)
        syncCelebrations()
    }

    /// El banner acompaña al evento durante toda su vida, pero su ANUNCIO pide
    /// turno como cualquier otra celebración. Una vez anunciado se queda sin
    /// volver a la cola: el evento dura ~30 s y el banner libera a los 6.
    var eventBannerIsVisible: Bool {
        guard let event = activeEvent else { return false }
        return showing == .eventBanner || announcedEventID == event.id
    }

    // MARK: Internos

    /// Limpia el payload de lo que se cierra SOLO.
    ///
    /// Es lo que corta el bucle: si el payload siguiera puesto, `syncCelebrations`
    /// lo volvería a encolar ni bien termina y el aviso reaparecería para
    /// siempre. Lo que cierra el jugador ya se limpia en su propio dismiss.
    private func releasePayload(for kind: CelebrationKind) {
        switch kind {
        case .towerNotice:
            towerNotice = nil
        case .achievements:
            achievementToast = nil
            pendingAchievementToasts.removeAll()
        case .eventBanner:
            // El banner ya se anunció; de acá en más acompaña al evento sin
            // volver a pedir turno.
            announcedEventID = activeEvent?.id
        case .boardCelebration:
            settleInFlightBoardChange()
            // La bandera describe UNA celebración, no un estado de la partida: si
            // sobreviviera a la suya, el próximo ascenso sin novedad heredaría la
            // pantalla apagada. Acá caen las tres salidas: el fin que avisa la
            // escena, el tap que saltea y el watchdog que destraba.
            boardCelebrationShowsSomethingNew = false
        case .tutorialTip:
            // Estuvo en pantalla y su turno terminó —por el botón, por el tap
            // que saltea o por el timeout—: no vuelve. La retirada SIN marcar
            // (la condición que murió esperando turno) no pasa por acá: la
            // maneja el director (`refreshTutorialTip`).
            if let tip = tutorialTip { markLessonDone(tip.lesson) }
            tutorialTip = nil
        case .offlineEarnings, .dailyReward,
             .careerChoice, .skinAward, .specialDrop, .chestOpening:
            break
        }
    }

    private func publishCelebration() {
        let kind = celebrations.current
        if showing != kind { showing = kind }
        // El cofre apaga la UI SIEMPRE: su animación ocupa la pantalla entera y el
        // HUD asomando por debajo rompe el telón.
        let hides = (kind == .boardCelebration && boardCelebrationShowsSomethingNew)
            || kind == .chestOpening
        if celebrationHidesUI != hides { celebrationHidesUI = hides }
    }
}
