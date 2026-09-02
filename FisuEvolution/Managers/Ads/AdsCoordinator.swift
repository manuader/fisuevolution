import Foundation

/// El único dueño de la decisión "stub o AdMob", y el objeto que el resto de la
/// app conoce.
///
/// Existe porque la elección de proveedor **no se puede hacer donde se creaba
/// el proveedor**: `RootView` construía un `StubAdsProvider()` en un `@State`,
/// que se inicializa antes de que `GameState.bootstrap()` haya leído
/// `feature_flags.json`. Sin este intermediario habría que elegir con los flags
/// todavía sin cargar, o swapear el `@State` a mitad de sesión.
///
/// Así que el coordinador se crea temprano y **vacío**, con el stub adentro, y
/// `configure(flags:…)` lo resuelve cuando los flags existen.
///
/// Además es el dueño de las **dos políticas** que no son del SDK:
/// 1. Qué respeta `remove_ads` y qué no (ver `removedAds`).
/// 2. **Cuándo se puede mostrar un interstitial** (ver `armIfDue` / `showInterstitialIfArmed`).
///
/// ## `@Observable`, pero con TODO `@ObservationIgnored` — y no es una
/// contradicción
///
/// El macro está sólo por la plomería del entorno: `.environment(ads)` y
/// `@Environment(AdsCoordinator.self)` funcionan únicamente sobre tipos
/// `@Observable`, y ése es el mecanismo con el que el resto de los servicios
/// del proyecto viajan hasta las vistas.
///
/// Lo que NO queremos es la observación en sí, y por eso las propiedades
/// almacenadas están marcadas `@ObservationIgnored`. La razón es medible: los
/// consumidores leen el estado de los anuncios **dentro de acciones**, nunca en
/// un `body`. Sin los `@ObservationIgnored`, cada reposición de inventario del
/// SDK —varias por sesión, sin que cambie un pixel— invalidaría las vistas que
/// lo tengan en el entorno. Es lo que la regla de las proyecciones evita.
@Observable @MainActor
final class AdsCoordinator: AdsProvider {

    /// El proveedor real detrás de la costura. Arranca en stub para que el
    /// juego funcione entre el lanzamiento y el fin del bootstrap.
    @ObservationIgnored private var active: any AdsProvider = StubAdsProvider()

    /// Si el jugador compró `remove_ads`. Los **interstitials** lo respetan; los
    /// **rewarded NO**, y esa asimetría es deliberada: quitar los anuncios paga
    /// por no ser interrumpido, no por perder los premios que el jugador elige
    /// mirar. Sacarle los rewarded a quien pagó sería quitarle una fuente de
    /// premios por haber pagado.
    @ObservationIgnored private var removedAds = false

    @ObservationIgnored private(set) var isConfigured = false

    // MARK: - La política del interstitial

    @ObservationIgnored private var cadence = RewardedAdsConfig.Interstitial.default
    @ObservationIgnored private let now: @Sendable () -> Date
    /// Cuándo arrancó la app (o volvió del background, que cuenta igual para la
    /// gracia: llegar y comerse un anuncio se siente igual de mal).
    @ObservationIgnored private var sessionStartedAt: Date
    @ObservationIgnored private var lastInterstitialAt: Date?
    @ObservationIgnored private var lastRewardedAt: Date?
    /// El interstitial está ARMADO: le toca, y espera una pausa natural.
    ///
    /// ⚠️ **Esta bandera es toda la idea.** El pedido del dueño fue "un anuncio
    /// normal cada 5 o 10 minutos de juego", y la implementación literal —un
    /// timer que presenta— es la que Google penaliza: un interstitial que cae
    /// encima del tablero mientras el jugador tapea produce clicks accidentales
    /// (política de invalid traffic) y es la peor experiencia posible en un
    /// juego de tapear. Así que el reloj sólo **arma**; el disparo lo pide la UI
    /// desde un lugar donde se sabe que no hay nada en curso.
    @ObservationIgnored private(set) var isInterstitialArmed = false

    init(now: @escaping @Sendable () -> Date = Date.init) {
        self.now = now
        self.sessionStartedAt = now()
    }

    /// Elige el proveedor y arranca la precarga. Idempotente.
    ///
    /// El orden acá es el checklist de `Docs/ads-integration.md` y no se puede
    /// permutar: **consentimiento (UMP → ATT) y sólo después el SDK.**
    func configure(
        flags: FeatureFlags,
        cadence: RewardedAdsConfig.Interstitial,
        removedAds: Bool
    ) async {
        self.removedAds = removedAds
        self.cadence = cadence
        guard !isConfigured else { return }
        isConfigured = true

        guard flags.useRealAds else {
            // Rama sin ads reales: queda el stub. Sirve para desarrollar, y el
            // test de contenido es el que impide que un build de tienda salga
            // así.
            active.prepare()
            return
        }

        await AdsConsent.resolve()
        let provider = AdMobAdsProvider(unitIDs: flags.effectiveAdUnitIDs, now: now)
        active = provider
        provider.prepare()
    }

    /// Se llama cuando el jugador compra `remove_ads` en la sesión.
    func setRemovedAds(_ removed: Bool) {
        removedAds = removed
    }

    /// La app volvió del background. Reinicia la gracia de sesión: el tiempo en
    /// background **no es tiempo de juego**, así que no debería acercar el
    /// próximo interstitial.
    func sessionResumed() {
        sessionStartedAt = now()
    }

    // MARK: - AdsProvider

    func isRewardedReady(for placement: RewardedPlacement) -> Bool {
        active.isRewardedReady(for: placement)
    }

    func preloadRewarded(for placement: RewardedPlacement) {
        active.preloadRewarded(for: placement)
    }

    func showRewarded(for placement: RewardedPlacement) async -> Bool {
        let earned = await active.showRewarded(for: placement)
        // Se anota SIEMPRE, gane o no: lo que abre la gracia es haber comido una
        // pantalla completa de publicidad, no haber cobrado.
        lastRewardedAt = now()
        return earned
    }

    /// ⚠️ Devuelve `false` para quien compró `remove_ads`, así que los
    /// llamadores no tienen que acordarse de chequearlo. Centralizarlo acá es lo
    /// que hace que agregar un punto de interstitial en el futuro no pueda
    /// olvidarse del `remove_ads`.
    var isInterstitialReady: Bool { !removedAds && active.isInterstitialReady }

    func showInterstitial() async {
        guard !removedAds else { return }
        await active.showInterstitial()
        lastInterstitialAt = now()
        isInterstitialArmed = false
    }

    // MARK: - El reloj del interstitial

    /// ¿Le toca? Arma la bandera si pasó el tiempo y las dos gracias.
    ///
    /// Lo llama el tick del juego. Es barato a propósito —tres restas de
    /// fechas— porque corre seguido.
    func armIfDue() {
        guard !removedAds, !isInterstitialArmed else { return }
        let instant = now()
        guard instant.timeIntervalSince(sessionStartedAt) >= cadence.graceSecondsAfterLaunch
        else { return }
        if let lastRewardedAt,
           instant.timeIntervalSince(lastRewardedAt) < cadence.graceSecondsAfterRewarded {
            return
        }
        // Sin interstitial previo, el reloj cuenta desde el arranque de sesión,
        // que ya pasó su gracia.
        let since = lastInterstitialAt ?? sessionStartedAt
        guard instant.timeIntervalSince(since) >= cadence.minSecondsBetween else { return }
        isInterstitialArmed = true
    }

    /// Muestra el interstitial **si estaba armado y hay uno cargado**. Se llama
    /// desde una pausa natural del juego; si no le toca, no hace nada y vuelve
    /// enseguida.
    ///
    /// El llamador no necesita saber ninguna de las reglas: pregunta "¿es un
    /// buen momento?" llamando acá, y la política vive de este lado.
    func showInterstitialIfArmed() async {
        guard isInterstitialArmed, isInterstitialReady else { return }
        await showInterstitial()
    }

    func prepare() {
        active.prepare()
    }
}
