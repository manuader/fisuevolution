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
        if towerNotice != nil { celebrations.enqueue(.towerNotice) }
        if achievementToast != nil || !pendingAchievementToasts.isEmpty {
            celebrations.enqueue(.achievements)
        }
        if let event = activeEvent, event.id != announcedEventID {
            celebrations.enqueue(.eventBanner)
        }
        publishCelebration()
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
        case .boardCelebration, .offlineEarnings, .dailyReward,
             .careerChoice, .skinAward, .specialDrop:
            break
        }
    }

    private func publishCelebration() {
        let kind = celebrations.current
        if showing != kind { showing = kind }
        let dims = kind == .boardCelebration
        if celebrationDimsHUD != dims { celebrationDimsHUD = dims }
    }
}
