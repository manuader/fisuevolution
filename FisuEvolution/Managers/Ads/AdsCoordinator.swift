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
    @ObservationIgnored private var active: any AdsProvider

    /// Si el jugador compró `remove_ads`. Los **interstitials** lo respetan; los
    /// **rewarded NO**, y esa asimetría es deliberada: quitar los anuncios paga
    /// por no ser interrumpido, no por perder los premios que el jugador elige
    /// mirar. Sacarle los rewarded a quien pagó sería quitarle una fuente de
    /// premios por haber pagado.
    ///
    /// En la 2.0 son **tres los formatos forzados** que corta (decisión del
    /// dueño, PLAN-v2 §2): el interstitial, la pausa publicitaria y el app
    /// open. La pausa publicitaria paga un premio, pero nadie la pidió: es
    /// interrupción, y por eso cae del lado de los forzados.
    @ObservationIgnored private var removedAds = false

    @ObservationIgnored private(set) var isConfigured = false

    /// Si hay un anuncio de pantalla completa en pantalla, de cualquier formato.
    ///
    /// ⚠️ No es informativo: es lo que impide **dos anuncios encimados**. El
    /// proveedor real tiene un solo observador de presentación para los cuatro
    /// formatos, así que un segundo `show…` en vuelo pisaría la continuación
    /// del primero y ese `await` no volvería nunca. Con un solo formato forzado
    /// no podía pasar; con tres que disparan desde lugares distintos (cerrar una
    /// hoja, volver del background, reencarnar), sí.
    @ObservationIgnored private(set) var isPresentingFullScreen = false

    // MARK: - La política del interstitial

    @ObservationIgnored private var cadence = RewardedAdsConfig.Interstitial.default
    @ObservationIgnored private let now: @Sendable () -> Date
    /// Cuándo arrancó la app (o volvió del background, que cuenta igual para la
    /// gracia: llegar y comerse un anuncio se siente igual de mal).
    @ObservationIgnored private var sessionStartedAt: Date
    @ObservationIgnored private var lastInterstitialAt: Date?
    /// Cuándo se cerró el último video con premio. Lo lee también la política
    /// de cortes naturales de la 2.0 para su gracia post-video.
    @ObservationIgnored private(set) var lastRewardedAt: Date?
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

    /// `provider` es el que atiende hasta que `configure` decida; los tests
    /// pasan uno guionado para controlar cuándo se cierra un anuncio.
    init(
        now: @escaping @Sendable () -> Date = Date.init,
        provider: any AdsProvider = StubAdsProvider()
    ) {
        self.now = now
        self.sessionStartedAt = now()
        self.active = provider
    }

    /// Si esta corrida es una de tests de UI.
    ///
    /// ⚠️⚠️ **Sin esto los 55 tests de UI se caen todos**, y no de forma sutil:
    /// con AdMob real, el bootstrap presenta DOS diálogos de sistema encima de
    /// la app —el formulario de consentimiento de UMP y el prompt de ATT— que
    /// ningún test sabe cerrar, así que tapan cada coordenada que el runner
    /// toca. Medido el 2026-09-02 sacando una captura con el fixture de
    /// offline: el prompt de ATT ocupaba el centro de la pantalla y el popup
    /// que se quería fotografiar estaba abajo, inalcanzable.
    ///
    /// Es el mismo criterio con el que `applyLaunchArgumentDefaults` apaga las
    /// lecciones contextuales bajo `--uitest*`: en una corrida de tests, el
    /// estado lo declara el test y nunca el azar de un gating. Un test que
    /// quiera ejercitar la costura de anuncios usa el stub, que es
    /// determinístico y no pide permisos.
    private static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--uitest") }
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

        guard flags.useRealAds, !Self.isRunningUITests else {
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
        guard !isPresentingFullScreen else { return false }
        isPresentingFullScreen = true
        defer { isPresentingFullScreen = false }
        let earned = await active.showRewarded(for: placement)
        // Se anota gane o no gane, pero SÓLO si hubo video en pantalla: lo que
        // abre la gracia es haber comido una pantalla completa de publicidad,
        // no haber cobrado. Un toque que no encontró inventario no comió nada.
        if active.lastRewardedPresented { lastRewardedAt = now() }
        return earned
    }

    var lastRewardedPresented: Bool { active.lastRewardedPresented }

    /// ⚠️ Devuelve `false` para quien compró `remove_ads`, así que los
    /// llamadores no tienen que acordarse de chequearlo. Centralizarlo acá es lo
    /// que hace que agregar un punto de interstitial en el futuro no pueda
    /// olvidarse del `remove_ads`.
    var isInterstitialReady: Bool {
        !removedAds && !isPresentingFullScreen && active.isInterstitialReady
    }

    func showInterstitial() async {
        guard !removedAds, !isPresentingFullScreen else { return }
        isPresentingFullScreen = true
        defer { isPresentingFullScreen = false }
        await active.showInterstitial()
        forcedAdFinished()
    }

    /// Misma regla que el interstitial: `false` con `remove_ads`.
    var isRewardedInterstitialReady: Bool {
        !removedAds && !isPresentingFullScreen && active.isRewardedInterstitialReady
    }

    func preloadRewardedInterstitial() {
        // Quien compró `remove_ads` no la va a ver: pedirla gastaría su red.
        guard !removedAds else { return }
        active.preloadRewardedInterstitial()
    }

    /// `false` sin mostrar nada si el jugador compró `remove_ads` o si ya hay
    /// otro anuncio en pantalla.
    func showRewardedInterstitial() async -> Bool {
        guard !removedAds, !isPresentingFullScreen else { return false }
        isPresentingFullScreen = true
        defer { isPresentingFullScreen = false }
        let earned = await active.showRewardedInterstitial()
        forcedAdFinished()
        return earned
    }

    var isAppOpenReady: Bool {
        !removedAds && !isPresentingFullScreen && active.isAppOpenReady
    }

    func preloadAppOpen() {
        guard !removedAds else { return }
        active.preloadAppOpen()
    }

    func showAppOpen() async {
        guard !removedAds, !isPresentingFullScreen else { return }
        isPresentingFullScreen = true
        defer { isPresentingFullScreen = false }
        await active.showAppOpen()
        forcedAdFinished()
    }

    /// Un formato forzado terminó, el que sea. El reloj de la 1.x es uno solo
    /// para los tres: una pausa publicitaria o un app open recién cerrados
    /// cuentan como "acaba de comer un anuncio" para el próximo interstitial.
    /// Es el mismo criterio del `lastFullScreenAt` único de la 2.0.
    private func forcedAdFinished() {
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
