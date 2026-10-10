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
    /// abierta" es `isBoardBusy`: todo lo que tapa el tablero o no se puede
    /// interrumpir. La celebración incluye la cinemática, que viaja por la cola.
    var naturalBreakContext: NaturalBreakContext {
        NaturalBreakContext(
            removedAds: player?.meta.removedAds ?? false,
            tutorialActive: tutorialPhaseActive || celebrations.allowedKinds != nil,
            // La oferta de Compartir gasta sus 10 s a la vista: la pausa no la tapa.
            sheetOpen: isBoardBusy || shareOffer != nil,
            celebrationActive: celebrations.current != nil,
            adOnScreen: ads?.isPresentingFullScreen ?? false,
            lastRewardedAt: ads?.lastRewardedAt,
            readyFormats: readyForcedFormats
        )
    }

    /// Los forzados con inventario; sin premios que ofrecer, la pausa no se elige
    /// (si no, se quedaría con el turno para siempre).
    private var readyForcedFormats: Set<ForcedAdFormat> {
        Self.offerableFormats(ads?.readyForcedFormats ?? [], adBreak: content?.rewardedAds.effectiveAdBreak)
    }

    static func offerableFormats(_ ready: Set<ForcedAdFormat>, adBreak: RewardedAdsConfig.AdBreak?) -> Set<ForcedAdFormat> {
        var formats = ready
        if adBreak?.prizes.isEmpty ?? true { formats.remove(.rewardedInterstitial) }
        return formats
    }

    /// El tablero no está a la vista o el jugador está en medio de algo: una
    /// hoja, la ficha, la carrera, el reto de un visitante (y el popup que lo
    /// ofrece, que entra por `uiCoversBoard`), la pantalla previa de la pausa,
    /// la escena inactiva, el viaje en ascensor o una compra en curso. Es la
    /// única definición: `isCalmMoment` y los cortes naturales la comparten.
    var isBoardBusy: Bool {
        uiCoversBoard || characterSheet != nil || careerPrompt != nil || stageChallenge != nil
            || adBreakOffer != nil || adBreakInFlight || !isSceneActive || fullScreenUIActive()
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
            presentAdBreak(pacer: pacer)
        }
    }

    /// Muestra con la cola ya retenida y la suelta al volver. Se anota en el
    /// reloj sólo si el anuncio llegó a la pantalla: un inventario vencido o una
    /// falla al presentar no gastan el cupo de nadie.
    private func presentHeld(_ format: ForcedAdFormat, pacer: ForcedAdsPacer) async {
        defer { releaseCelebrationsAfterAd() }
        guard let ads else { return }
        let presented = switch format {
        case .appOpen: await ads.showAppOpen()
        default: await ads.showInterstitial()
        }
        if presented { pacer.recordShown(format) }
    }

    // MARK: - La pausa publicitaria

    /// Cuánto antes de su corte se pide el anuncio de la pausa.
    static let adWarmUpSeconds: TimeInterval = 60
    /// Cada cuánto, como máximo, se reintenta pedirlo.
    static let adWarmRetrySeconds: TimeInterval = 30

    private func presentAdBreak(pacer: ForcedAdsPacer) {
        guard adBreakOffer == nil, let content else { return }
        let config = content.rewardedAds.effectiveAdBreak
        guard let prize = pacer.adBreakPrize(in: config.prizes) else { return }
        holdCelebrationsForAd()
        adBreakOffer = AdBreakOffer(prize: prize, countdownSeconds: config.introSeconds)
    }

    /// La cuenta llegó a cero, o el jugador tocó "Ver ahora". Si la app ya no
    /// está activa la oferta se cae sin costo: nadie la vio terminar.
    func adBreakAccepted() async {
        guard let offer = adBreakOffer, let ads, let pacer = ads.pacer else { return }
        adBreakOffer = nil
        guard isSceneActive else {
            releaseCelebrationsAfterAd()
            return
        }
        adBreakInFlight = true
        defer { adBreakInFlight = false }
        // La pantalla previa se va con un fundido; el anuncio entra después.
        if ads.settleDelay > .zero {
            try? await Task.sleep(for: ads.settleDelay)
        }
        let earned = await ads.showRewardedInterstitial()
        if ads.lastRewardedInterstitialAttempt == .presented {
            pacer.recordShown(.rewardedInterstitial)
        }
        releaseCelebrationsAfterAd()
        guard earned, let content else { return }
        grant(offer.prize, source: "adbreak")
        Task { await persistNow(includingCloud: false) }
        pacer.advanceAdBreakPrize(count: content.rewardedAds.effectiveAdBreak.prizes.count)
        towerNotice = TowerNotice(kind: .rewardGranted(text: RewardCopy.title(offer.prize)))
        syncCelebrations()
    }

    /// "No, gracias": no castiga. Cuenta como el corte —la ventana de 2 min se
    /// cierra y el turno pasa al común—, así no vuelve a ofrecerse al toque.
    func adBreakDeclined() {
        guard adBreakOffer != nil else { return }
        adBreakOffer = nil
        ads?.pacer?.recordShown(.rewardedInterstitial)
        releaseCelebrationsAfterAd()
    }

    /// A 8 Hz desde `flushHUD`. Si a la pausa le toca y su corte se abre en
    /// menos de `adWarmUpSeconds`, se pide su anuncio: que esté cargado cuando
    /// llegue, sin pedir uno que no se va a mostrar (E7a: la tasa de
    /// presentación de la unidad). El pacer limita los reintentos.
    func warmForcedAds() {
        guard let ads, let pacer = ads.pacer, !(player?.meta.removedAds ?? false),
              pacer.shouldRequestAdBreakAd(leadSeconds: Self.adWarmUpSeconds, retrySeconds: Self.adWarmRetrySeconds)
        else { return }
        ads.preloadRewardedInterstitial()
    }

    #if DEBUG
    /// El panel de debug: la pantalla previa ahora, con el premio de turno.
    func debugPresentAdBreak() {
        guard let pacer = ads?.pacer else { return }
        presentAdBreak(pacer: pacer)
    }
    #endif

    // MARK: - La cola, quieta mientras hay un anuncio

    /// Nada de la cola toma el turno mientras un forzado tapa la pantalla. Se
    /// guarda la restricción que hubiera (la del tutorial) para devolverla tal
    /// cual. Retener dos veces no pisa lo guardado.
    func holdCelebrationsForAd() {
        guard case .released = celebrationHold else { return }
        celebrationHold = .held(restoring: celebrations.allowedKinds)
        celebrations.restrict(to: [])
    }

    func releaseCelebrationsAfterAd() {
        guard case .held(let previous) = celebrationHold else { return }
        celebrationHold = .released
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

/// La cola de celebraciones retenida por un forzado (`holdCelebrationsForAd`).
enum CelebrationHold {
    case released
    /// `restoring`: la restricción que había antes (`nil` = ninguna).
    case held(restoring: Set<CelebrationKind>?)

    var isReleased: Bool {
        if case .released = self { return true }
        return false
    }
}

/// La pantalla previa de la pausa publicitaria: qué se gana y cuánto falta.
struct AdBreakOffer: Identifiable, Equatable {
    let id = UUID()
    let prize: RewardSpec
    let countdownSeconds: Int
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
        case .offlineEarnings, .eventBanner, .visitorEncounter, .achievements, .towerNotice, .tutorialTip, .cinematic:
            false
        }
    }
}
