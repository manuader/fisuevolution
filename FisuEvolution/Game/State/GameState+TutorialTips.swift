import EconomyKit
import Foundation

/// Las lecciones contextuales del tutorial: después de la fase obligatoria
/// (tap → contratar → fusionar), el resto de la app se enseña de a una lección,
/// cada una la PRIMERA vez que hay algo que hacer en su pantalla — nunca antes.
///
/// La regla de oro es del dueño y es el criterio de aceptación: ninguna lección
/// manda a una pantalla donde EN ESE MOMENTO no hay nada que hacer. Por eso
/// cada lección declara su señal de gating (una proyección barata, nunca una
/// fila computada), y por eso viajan por la `CelebrationQueue` como
/// `.tutorialTip`: el "de a una" y el no-pisarse con premios y reveals salen
/// del árbitro que ya existe, no de un segundo tutorial paralelo.
extension GameState {
    /// Una pantalla de la app, con su momento. El orden de `allCases` es el
    /// desempate cuando hay más de una elegible a la vez (el de la tabla del
    /// prompt); en la práctica casi siempre decide el gating solo.
    enum TutorialLesson: String, CaseIterable {
        /// Hay una mejora pagable (personaje, pasivo o permanente).
        case upgrades
        /// Se desbloqueó el segundo piso: recién ahora el mapa tiene a dónde ir.
        case elevator
        /// El atajo de contratar al mejor, cuando hay algo contratable.
        case quickHire
        /// La primera pinta ganada (la skin de milestone del piso 2).
        case skins
        /// El primer logro COBRABLE: enseña el circuito del puntito rojo.
        case achievements
        /// El primer daily cobrado de verdad: el calendario vive en Regalos.
        case gifts
        /// Una vez, suave, en la segunda sesión con la fase hecha.
        case store
        /// El indicador de reencarnar se encendió por primera vez.
        case prestige

        /// La bandera persistida de "esta lección ya se dio". Versionable por
        /// prefijo, y `--uitest-reset` las barre (`+Debug`).
        var defaultsKey: String { "tutorial.lesson.\(rawValue)" }

        /// El control que el coach-mark señala.
        var anchorTarget: TutorialTarget {
            switch self {
            case .upgrades: .upgrades
            case .elevator: .map
            case .quickHire: .quickHire
            case .skins: .skins
            case .achievements: .menu
            case .gifts: .gifts
            case .store: .store
            case .prestige: .prestige
            }
        }

        /// La hoja de la barra que "hace" la lección, para que abrirla la dé
        /// por cumplida. `nil` = el destino no es una hoja de la barra (el
        /// mapa, el atajo y el prestigio avisan desde su propia acción).
        var destinationScreen: GameScreen? {
            switch self {
            case .upgrades: .upgrades
            case .skins: .skins
            case .achievements: .menu
            case .gifts: .gifts
            case .store: .store
            case .elevator, .quickHire, .prestige: nil
            }
        }

        /// La clave del globo. Escrita entera, nunca interpolada (trampa 5).
        var textKey: String {
            switch self {
            case .upgrades: "tutorial.tip.upgrades"
            case .elevator: "tutorial.tip.elevator"
            case .quickHire: "tutorial.tip.quickhire"
            case .skins: "tutorial.tip.skins"
            case .achievements: "tutorial.tip.achievements"
            case .gifts: "tutorial.tip.gifts"
            case .store: "tutorial.tip.store"
            case .prestige: "tutorial.tip.prestige"
            }
        }
    }

    /// El payload de `.tutorialTip`: qué lección tiene (o espera) el turno.
    struct TutorialTip: Equatable {
        let lesson: TutorialLesson
    }

    static let sessionsAfterPhaseKey = "tutorial.sessionsAfterPhase"

    /// Borra el progreso persistido de las lecciones (los flags por lección y
    /// el contador de sesiones). Lo comparten `--uitest-reset` y el "Resetear
    /// partida" del panel de debug: las lecciones viven en `UserDefaults` y
    /// sobrevivirían a cualquier partida nueva — la misma trampa que el
    /// tutorial y los ajustes.
    func wipeTutorialLessonProgress() {
        let defaults = UserDefaults.standard
        for lesson in TutorialLesson.allCases {
            defaults.removeObject(forKey: lesson.defaultsKey)
        }
        defaults.removeObject(forKey: Self.sessionsAfterPhaseKey)
    }

    // MARK: El director

    /// Decide si nace una lección. Corre al final de `refreshProjections` (8 Hz,
    /// contra señales ya publicadas: acá no se computa nada caro) y es la única
    /// puerta de entrada: una lección por vez, la primera elegible del orden.
    ///
    /// También es la puerta de SALIDA anticipada: si la condición de la lección
    /// murió mientras esperaba turno (gastó las monedas antes de que el tip
    /// saliera), se retira de la fila sin marcarse como dada — la regla de oro
    /// vale hasta el último frame, y la lección vuelve cuando su momento
    /// vuelva.
    func refreshTutorialTip() {
        guard tutorialLessonsAutorun, phase == .ready, !tutorialPhaseActive else { return }
        if let tip = tutorialTip {
            if showing != .tutorialTip, !isEligible(tip.lesson) {
                tutorialTip = nil
                celebrations.finish(.tutorialTip)
            }
            return
        }
        // Con una hoja abierta no nace nada: el coach señala controles que
        // están DEBAJO de la hoja. Al cerrarse, el próximo refresh la agarra.
        guard !uiCoversBoard, characterSheet == nil, shareCardSubject == nil else { return }
        guard let lesson = TutorialLesson.allCases.first(where: { !isLessonDone($0) && isEligible($0) })
        else { return }
        tutorialTip = TutorialTip(lesson: lesson)
        syncCelebrations()
    }

    /// La señal de cada lección, contra proyecciones ya publicadas.
    private func isEligible(_ lesson: TutorialLesson) -> Bool {
        switch lesson {
        case .upgrades:
            canAffordAnyUpgrade
        case .elevator:
            unlockedFloorsCount >= 2
        case .quickHire:
            bestHire?.affordable == true
        case .skins:
            !ownedSkins.isEmpty
        case .achievements:
            hasClaimableAchievements
        case .gifts:
            // `cycleDay` apunta al día que el ciclo VA a pagar y arranca en 1;
            // la instalación fresca marca `lastClaimDay` sin moverlo. O sea:
            // `> 1` es exactamente "ya cobró un daily de verdad" — sin bandera
            // nueva y persistido en el save.
            (player?.meta.daily.cycleDay ?? 1) > 1
        case .store:
            UserDefaults.standard.integer(forKey: Self.sessionsAfterPhaseKey) >= 2
        case .prestige:
            prestigeAvailable
        }
    }

    private func isLessonDone(_ lesson: TutorialLesson) -> Bool {
        UserDefaults.standard.bool(forKey: lesson.defaultsKey)
    }

    /// La marca `releasePayload`: las tres salidas del turno —el botón del
    /// globo, el tap que saltea y el timeout— pasan por ahí, así que una
    /// lección que estuvo en pantalla no vuelve, la hayan leído o ignorado.
    func markLessonDone(_ lesson: TutorialLesson) {
        UserDefaults.standard.set(true, forKey: lesson.defaultsKey)
    }

    // MARK: Salidas

    /// El botón del globo ("¡Dale!").
    func dismissTutorialTip() {
        guard showing == .tutorialTip else { return }
        celebrationFinished(.tutorialTip)
    }

    /// El jugador HIZO lo que la lección señalaba (abrió la hoja, el mapa, el
    /// prestigio, usó el atajo): la lección se cumple y el globo se va. Es la
    /// mejor de las tres salidas y por eso no espera el piso de skip.
    func tutorialTipCompleted(_ lesson: TutorialLesson) {
        guard showing == .tutorialTip, tutorialTip?.lesson == lesson else { return }
        celebrationFinished(.tutorialTip)
    }

    /// La variante para las hojas de la barra: `RootView.open` no tiene por qué
    /// saber qué lección está corriendo.
    func tutorialTipHandled(opening screen: GameScreen) {
        guard let lesson = tutorialTip?.lesson, lesson.destinationScreen == screen else { return }
        tutorialTipCompleted(lesson)
    }

    // MARK: La señal de Mejoras

    /// Cotiza costos CRUDOS contra los dos balances. Nunca `characterUpgradeRows`
    /// —que arma textos localizados por fila— ni nada por frame que no sea una
    /// comparación: esto corre a 8 Hz.
    func computeCanAffordAnyUpgrade(player: PlayerState, content: GameContent) -> Bool {
        let coins = player.run.coins
        for type in characterUpgradeTypes {
            if let cost = characterUpgradeCost(of: type), coins >= cost { return true }
            if player.run.passiveUnlocked[type.id] != true, coins >= type.passiveUnlockCost { return true }
        }
        let oro = Double(player.meta.oro)
        for line in content.upgradesConfig.upgrades where upgradeLevel(of: line.id) < line.maxLevel {
            let balance = line.currency == .oro ? oro : coins
            if balance >= upgradeCost(of: line) { return true }
        }
        return false
    }
}
