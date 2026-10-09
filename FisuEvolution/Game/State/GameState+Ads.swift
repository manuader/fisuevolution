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
        guard let ads else { return }
        switch format {
        case .interstitial:
            holdCelebrationsForAd()
            await ads.showInterstitial()
            pacer.recordShown(.interstitial)
            releaseCelebrationsAfterAd()
        case .rewardedInterstitial, .appOpen:
            break
        }
    }

    // MARK: - La cola, quieta mientras hay un anuncio

    /// Nada de la cola toma el turno mientras un forzado tapa la pantalla. Los
    /// forzados nunca salen con el tutorial (la política), así que la cola no
    /// tenía otra restricción que haya que guardar.
    func holdCelebrationsForAd() {
        celebrations.restrict(to: [])
    }

    func releaseCelebrationsAfterAd() {
        celebrations.restrict(to: nil)
        syncCelebrations()
    }

    // MARK: - Irse y volver

    /// La app se fue, o quedó inactiva viniendo de activa (lo llama el sellado).
    func adsDidEnterBackground() {
        ads?.pacer?.didEnterBackground()
    }

    /// La app volvió: la gracia de los intersticiales arranca de nuevo (el
    /// tiempo afuera no es tiempo de juego).
    func adsDidReturnFromBackground() {
        ads?.pacer?.didReturnFromBackground()
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
