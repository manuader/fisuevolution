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
        if newCharacterCard != nil { celebrations.enqueue(.newCharacter) }
        if specialDrop != nil { celebrations.enqueue(.specialDrop) }
        if chestReward != nil { celebrations.enqueue(.chestOpening) }
        if towerNotice != nil { celebrations.enqueue(.towerNotice) }
        // Una hoja que se quedó sin oferta (venció, se compró, cerró la puerta del
        // azar) no tiene quién la cierre: se suelta el turno acá.
        if celebrations.current == .offer, !offerTurnHasSomethingToShow {
            presentingOfferId = nil
            celebrations.finish(.offer)
        }
        // Una oferta no se apila sobre otra hoja: sólo toma el turno con el tablero a la vista.
        if offerToPresent != nil, isCalmMoment { celebrations.enqueue(.offer) }
        if achievementToast != nil || !pendingAchievementToasts.isEmpty {
            celebrations.enqueue(.achievements)
        }
        // El turno es la puerta de la entrada; la que ya se ve no vuelve a pedirlo (B21).
        if boardIsVisibleForChanges, let visit = stageVisit, visit.phase == .entering, !visit.onStage {
            celebrations.enqueue(.visitorEncounter)
        }
        // Una lección no tapa al visitante que entra caminando (B21): la encola su llegada.
        if let tutorialRun, runTakesAQueueTurn(tutorialRun), !stageEntranceInProgress {
            celebrations.enqueue(.tutorialTip)
        }
        if cinematic != nil { celebrations.enqueue(.cinematic) }
        if boardIsVisibleForChanges, !pendingBoardChanges.isEmpty || typePendingReveal != nil {
            celebrations.enqueue(.boardCelebration)
        }
        publishCelebration()
    }

    // MARK: El tutorial como cliente

    /// Arranca la fase obligatoria del tutorial —el núcleo, que corre el
    /// director (`TutorialCurriculum.core`)—: desde acá y hasta
    /// `finishTutorialCore()`, la cola sólo promueve el reveal del tablero
    /// —que es EL momento de la fase, no un estorbo— y todo lo demás queda en
    /// `pending`: no se presenta (su sheet está gateado por el tutorial y
    /// congelaría la cola) ni se pierde. El núcleo no pide turno en la cola:
    /// la restringe, y la libera su cierre.
    func beginTutorialPhase() {
        tutorialPhaseActive = true
        celebrations.restrict(to: [.boardCelebration])
        publishCelebration()
        startTutorialRun(.core, steps: TutorialCurriculum.core)
        refreshTutorial()
    }

    /// El gate del arranque: el núcleo corre sólo si no está hecho. Un veterano
    /// de la v1 lo trae hecho por la migración (`applyTutorialMigration`, que
    /// corre antes) y no lo ve otra vez.
    func startTutorialCoreIfPending() {
        if !TutorialFlags.coreCompleted(in: flagDefaults) {
            beginTutorialPhase()
        } else {
            // La lección de Tienda espera a la SEGUNDA sesión con la fase
            // hecha ("una vez, suave": nunca en el mismo arranque en el que el
            // jugador recién aprendió a jugar).
            let sessions = flagDefaults.integer(forKey: TutorialFlags.sessionsAfterCoreKey)
            flagDefaults.set(sessions + 1, forKey: TutorialFlags.sessionsAfterCoreKey)
        }
    }

    /// El cierre del núcleo (`core.finish`, su "¡Vamos!" con el candado de
    /// 5 s): se levanta la restricción y lo que esperó su turno desfila en su
    /// orden de siempre — el daily del día 2 primero, después la skin, al
    /// final los toasts. Lo llama el director al confirmar el último paso del
    /// núcleo —nunca el repaso—; ya no hay "Saltar".
    ///
    /// Y acá cae el **cofre de bienvenida** (una vez por save:
    /// `welcomeChestGiven`), que es el momento que el dueño pidió para enseñar
    /// la mecánica: el jugador acaba de fusionar y todavía no vio una sola
    /// pinta.
    ///
    /// ⚠️ **Se otorga DESPUÉS de levantar la restricción**, y el orden es la
    /// decisión: así el cofre entra a la cola detrás de lo que ya estaba
    /// esperando, en vez de pasarle por encima con su prioridad. En una partida
    /// nueva no hay nada esperando —no hay offline, el día 1 del daily no se
    /// cobra y la carrera está a horas de distancia—, así que en la práctica se
    /// abre en el acto.
    func finishTutorialCore() {
        guard tutorialPhaseActive else { return }
        tutorialPhaseActive = false
        TutorialFlags.setCoreCompleted(true, in: flagDefaults)
        if tutorialRun?.script == .core { tutorialRun = nil }
        tutorialBoardTarget = nil
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
        // El toque al tablero, salteé o no: el ritmo no hace nacer una lección
        // en medio de una ráfaga de toques.
        tutorialEngine.pacing.boardTouched()
        guard let showingNow = celebrations.current else { return false }
        // La entrada del visitante no se saltea (B21, D15): el toque va al tablero
        // y él sigue caminando. Su turno lo cierra la escena (o el watchdog).
        guard showingNow != .visitorEncounter, celebrations.skip() else { return false }
        releasePayload(for: showingNow)
        syncCelebrations()
        return true
    }

    /// El ítem en pantalla no se puede saltear: lo consulta la escena para comerse
    /// el toque en vez de dejarlo agarrar un personaje.
    var currentCelebrationIsUnskippable: Bool { celebrations.isSkipLocked }

    /// Arranca la celebración de un piso recién abierto (E14 C21, D6): la anota
    /// como vista en esta vida y, si le toca, deja el turno del tablero
    /// insalteable hasta que termine. Devuelve cómo se presenta.
    @discardableResult
    func beginFloorUnlockCelebration(floorID: String) -> FloorUnlockPresentation {
        guard var player else { return FloorUnlockPresentation(skippable: true, short: false) }
        let life = player.meta.prestigeLevel
        let presentation = player.meta.engagement.floorUnlockPresentation(floorID: floorID, life: life)
        player.meta.engagement.recordFloorUnlock(floorID: floorID, life: life)
        self.player = player
        scheduleSave()
        if !presentation.skippable { celebrations.lockSkip(.boardCelebration) }
        return presentation
    }

    /// Corre el watchdog. Lo llama el tick que ya existe por frame: sin `Timer`
    /// (regla 2 de concurrencia) y con tests que inyectan deltas en vez de
    /// esperar segundos reales.
    func advanceCelebrations(delta: TimeInterval) {
        advanceTutorial(delta: delta)
        guard let expired = celebrations.tick(delta) else { return }
        // No es un caso normal: es el síntoma de que una animación no avisó que
        // terminó. Sin el watchdog eso congelaría TODAS las celebraciones hasta
        // reiniciar la app, así que se destraba y se deja el rastro.
        Log.lifecycle.error("celebración destrabada por watchdog: \(expired.rawValue)")
        releasePayload(for: expired)
        syncCelebrations()
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
        case .boardCelebration:
            settleInFlightBoardChange()
            // La bandera describe UNA celebración, no un estado de la partida: si
            // sobreviviera a la suya, el próximo ascenso sin novedad heredaría la
            // pantalla apagada. Acá caen las tres salidas: el fin que avisa la
            // escena, el tap que saltea y el watchdog que destraba.
            boardCelebrationShowsSomethingNew = false
        case .tutorialTip:
            // Estuvo en pantalla y su turno terminó —el último paso, el watchdog
            // del paso o su momento que murió en pantalla—: no vuelve. Ni timeout
            // ni tap que saltee (PLAN-v2 §2). La retirada SIN marcar (la condición
            // que murió esperando turno) no pasa por acá: la maneja el director
            // (`progressTutorialRun`).
            releaseTutorialTurn()
        case .cinematic:
            // Fin del video, "Saltar" y watchdog cuentan igual: la pantalla ya fue suya.
            recordCinematicSeen()
        case .visitorEncounter:
            // Las salidas del turno —la escena que empieza a mostrarlo o avisa que
            // llegó, el toque que saltea y el watchdog— pasan por acá. Si la escena
            // ya lo muestra caminando, la llegada es suya (B21); si no, llega igual,
            // una sola vez.
            settleStageArrival()
        case .offer:
            // Se mostró su única vez (se marcó al abrir la hoja): de acá en más vive en el chip.
            presentingOfferId = nil
        case .newCharacter:
            // Sólo el watchdog llega acá sin que el jugador haya elegido: la
            // card no vuelve (el bonus no se cobra, no se completó nada).
            newCharacterCard = nil
        case .offlineEarnings, .dailyReward,
             .careerChoice, .skinAward, .specialDrop, .chestOpening:
            break
        }
    }

    func publishCelebration() {
        let kind = celebrations.current
        let finished = showing
        if showing != kind { showing = kind }
        // El cofre y la cinemática apagan la UI SIEMPRE: ocupan la pantalla entera y el
        // HUD asomando por debajo rompe el telón.
        let hides = (kind == .boardCelebration && boardCelebrationShowsSomethingNew)
            || kind == .chestOpening || kind == .cinematic
        if celebrationHidesUI != hides { celebrationHidesUI = hides }
        // La cola se vació y en esta tanda hubo alguna de las grandes —aunque un
        // aviso chico haya sido el último en irse—: corte natural.
        guard let finished, showing != finished else { return }
        bigCelebrationSinceIdle = bigCelebrationSinceIdle || finished.endsInNaturalBreak
        if kind == nil {
            if bigCelebrationSinceIdle { scheduleNaturalBreak(.celebrationsDrained) }
            bigCelebrationSinceIdle = false
        }
    }
}
