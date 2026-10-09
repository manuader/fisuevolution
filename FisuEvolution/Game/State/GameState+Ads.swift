import EconomyKit
import Foundation

/// Los anuncios forzados de la 2.0 en la partida (PLAN-v2 E7): el único lugar
/// que muestra un intersticial. Arma lo que el juego sabe en el instante, le
/// pregunta a la política por medio de `ForcedAdsPacer` y presenta por
/// `AdsCoordinator`, que no deja encimar dos anuncios.
///
/// ⚠️ Mientras un forzado está en pantalla la cola de celebraciones queda
/// retenida. El SDK presenta su controlador encima de todo, y una hoja de
/// SwiftUI que intentara presentarse en ese momento fallaría sin aviso: su
/// turno quedaría tomado y nadie la vería.
extension GameState {

    // MARK: - El contexto

    /// Lo que el juego sabe ahora, en los términos de la política. "Hoja
    /// abierta" es todo lo que tapa el tablero o no se puede interrumpir: una
    /// hoja, la ficha, la carrera, la escena inactiva, el viaje en ascensor o una
    /// compra en curso. La celebración incluye la cinemática, que viaja por la cola.
    var naturalBreakContext: NaturalBreakContext {
        NaturalBreakContext(
            removedAds: player?.meta.removedAds ?? false,
            tutorialActive: tutorialPhaseActive || celebrations.allowedKinds != nil,
            sheetOpen: uiCoversBoard || characterSheet != nil || careerPrompt != nil
                || !isSceneActive || fullScreenUIActive(),
            celebrationActive: celebrations.current != nil,
            adOnScreen: ads?.isPresentingFullScreen ?? false,
            lastRewardedAt: ads?.lastRewardedAt,
            // La pausa entra con su pantalla previa; hasta entonces la política
            // sólo ve el común.
            readyFormats: (ads?.readyForcedFormats ?? []).subtracting([.rewardedInterstitial])
        )
    }

    // MARK: - Los cortes

    /// Pide un corte natural y vuelve en el acto. El corte espera
    /// `settleDelay`, decide con el contexto de ESE instante y, si toca,
    /// muestra. Uno a la vez: los que lleguen con otro en vuelo se descartan
    /// (dos cortes juntos son uno).
    func scheduleNaturalBreak(_ kind: NaturalBreak) {
        guard let ads, ads.pacer != nil, ads.naturalBreakTask == nil else { return }
        ads.naturalBreakTask = Task { [weak self] in
            await self?.runNaturalBreak(kind)
            self?.ads?.naturalBreakTask = nil
        }
    }

    /// Lo mismo, para un llamador `async` que espera a que se resuelva.
    func naturalBreak(_ kind: NaturalBreak) async {
        scheduleNaturalBreak(kind)
        await ads?.naturalBreakTask?.value
    }

    private func runNaturalBreak(_ kind: NaturalBreak) async {
        guard let ads, let pacer = ads.pacer else { return }
        if ads.settleDelay > .zero {
            try? await Task.sleep(for: ads.settleDelay)
        }
        guard phase == .ready else { return }
        let decision = pacer.decide(kind, context: naturalBreakContext)
        Log.ads.info("corte \(kind.rawValue): \(String(describing: decision))")
        guard case .show(let format) = decision else { return }
        await present(format, pacer: pacer)
    }

    private func present(_ format: ForcedAdFormat, pacer: ForcedAdsPacer) async {
        switch format {
        case .interstitial, .appOpen:
            holdCelebrationsForAd()
            await presentHeld(format, pacer: pacer)
        case .rewardedInterstitial:
            break
        }
    }

    /// Muestra con la cola ya retenida y la suelta al volver. Se anota en el
    /// reloj sólo si el anuncio llegó a la pantalla: un inventario vencido o una
    /// falla al presentar no gastan el cupo de nadie.
    private func presentHeld(_ format: ForcedAdFormat, pacer: ForcedAdsPacer) async {
        guard let ads else { return }
        let presented = switch format {
        case .appOpen: await ads.showAppOpen()
        default: await ads.showInterstitial()
        }
        if presented { pacer.recordShown(format) }
        releaseCelebrationsAfterAd()
    }

    // MARK: - La cola, quieta mientras hay un anuncio

    /// Nada de la cola toma el turno mientras un forzado tapa la pantalla. Se
    /// guarda la restricción que hubiera (la del tutorial) para devolverla tal
    /// cual. Retener dos veces no pisa lo guardado.
    func holdCelebrationsForAd() {
        guard restrictionBeforeAd == nil else { return }
        restrictionBeforeAd = .some(celebrations.allowedKinds)
        celebrations.restrict(to: [])
    }

    func releaseCelebrationsAfterAd() {
        guard let previous = restrictionBeforeAd else { return }
        restrictionBeforeAd = nil
        celebrations.restrict(to: previous)
        syncCelebrations()
    }

    // MARK: - Irse y volver

    /// La app se fue, o quedó inactiva viniendo de activa (lo llama el sellado).
    /// Si a la vuelta podría salir un app open, se pide ahora: un anuncio tarda
    /// segundos en cargar y al volver es tarde.
    func adsDidEnterBackground() {
        guard let pacer = ads?.pacer else { return }
        pacer.didEnterBackground()
        if pacer.couldShowAppOpenOnReturn { ads?.preloadAppOpen() }
    }

    /// La app volvió: la gracia de los intersticiales arranca de nuevo (el
    /// tiempo afuera no es tiempo de juego), y el app open se decide ACÁ, antes
    /// de acreditar el offline. Si sale, la cola queda retenida desde ya (esta
    /// misma pasada acredita el offline) y el popup de ganancias aparece después
    /// del anuncio, no debajo. Como la gracia arranca de cero y el app open
    /// anota el reloj común, ningún intersticial sale pegado a él.
    func adsDidReturnFromBackground() {
        guard let ads, let pacer = ads.pacer else { return }
        pacer.didReturnFromBackground()
        guard ads.naturalBreakTask == nil,
              case .show(.appOpen) = pacer.decide(.returnFromBackground, context: naturalBreakContext)
        else { return }
        holdCelebrationsForAd()
        ads.naturalBreakTask = Task { [weak self] in
            await self?.presentHeld(.appOpen, pacer: pacer)
            self?.ads?.naturalBreakTask = nil
        }
    }
}

extension CelebrationKind {
    /// Si el final de esta celebración —con la cola vacía detrás— es un corte
    /// natural (`celebrationsDrained`). Las grandes sí: el jugador acaba de
    /// mirar algo y todavía no volvió a tocar. Los avisos chicos no, el offline
    /// tiene su propio corte, y la cinemática no: la reencarnación que la trae
    /// ya pidió el suyo y el cofre que la sigue cierra la cola.
    var endsInNaturalBreak: Bool {
        switch self {
        case .boardCelebration, .chestOpening, .skinAward, .specialDrop, .dailyReward, .careerChoice:
            true
        case .offlineEarnings, .eventBanner, .achievements, .towerNotice, .tutorialTip, .cinematic:
            false
        }
    }
}
