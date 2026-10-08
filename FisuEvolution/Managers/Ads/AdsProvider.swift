import Foundation
import Observation

/// La costura de anuncios (bible §4.4). `StubAdsProvider` en dev,
/// `AdMobAdsProvider` cuando `feature_flags.useRealAds` está prendido — el
/// gameplay y la UI no cambian entre uno y otro.
///
/// ⚠️ **`showRewarded()` tiene que devolver `true` SÓLO si el premio se ganó de
/// verdad.** Es el único contrato que importa acá: quien lo llama
/// (`GiftsView.watch`) acredita el premio con ese booleano, así que un
/// proveedor que devuelva `true` al cerrar el anuncio a la mitad regala la
/// economía. AdMob distingue los dos casos con callbacks distintos
/// (`userDidEarnRewardHandler` vs. `adDidDismissFullScreenContent`) y el
/// proveedor real los mantiene separados.
@MainActor
protocol AdsProvider: AnyObject {
    /// Si hay un rewarded listo para ESE lugar. Se pregunta por placement
    /// porque cada uno tiene su unidad y su inventario: que haya video en
    /// Regalos no dice nada sobre el del cofre.
    func isRewardedReady(for placement: RewardedPlacement) -> Bool

    /// Pide que se precargue el video de ese lugar. Lo llama la UI **antes** de
    /// ofrecer el botón: un rewarded tarda 1-3 s en cargar, así que pedirlo
    /// recién cuando el jugador toca deja el botón muerto la primera vez.
    func preloadRewarded(for placement: RewardedPlacement)

    /// Presenta un rewarded; `true` sólo si el jugador se ganó el premio.
    func showRewarded(for placement: RewardedPlacement) async -> Bool

    /// Si hay un interstitial cargado y listo para mostrarse.
    var isInterstitialReady: Bool { get }
    /// Presenta un interstitial y vuelve cuando se cerró. No devuelve nada
    /// porque **un interstitial nunca paga**: es publicidad pura, sin premio, y
    /// por eso quien lo llama no tiene ninguna decisión que tomar con el
    /// resultado.
    func showInterstitial() async

    /// Si hay una pausa publicitaria (intersticial bonificado) cargada y fresca.
    var isRewardedInterstitialReady: Bool { get }
    /// Pide que se precargue. Lo llama quien va a ofrecer la pausa **antes** de
    /// la pantalla previa con cuenta regresiva: si el anuncio no está, la
    /// pantalla no se ofrece, porque una cuenta regresiva que termina en nada
    /// es peor que no haber interrumpido.
    func preloadRewardedInterstitial()
    /// Presenta la pausa publicitaria; `true` sólo si el jugador se ganó el
    /// premio. Es **el mismo contrato que `showRewarded`**, con la misma
    /// trampa: devolver `true` al cerrarla a la mitad regala la economía.
    func showRewardedInterstitial() async -> Bool

    /// Si hay un app open cargado y fresco.
    var isAppOpenReady: Bool { get }
    /// Pide que se precargue el app open. Se pide al irse a background, no al
    /// volver: un anuncio tarda segundos en cargar, y al volver es tarde.
    func preloadAppOpen()
    /// Presenta un app open y vuelve cuando se cerró. Como el interstitial, no
    /// paga nada y no devuelve nada.
    func showAppOpen() async

    /// Arranca la precarga. Se llama una vez al bootstrap; los proveedores que
    /// no precargan nada (el stub) lo implementan vacío.
    func prepare()
}

/// Cuánto vive un anuncio cargado antes de que haya que tirarlo, por formato.
///
/// AdMob declara una hora para rewarded, interstitial y rewarded interstitial,
/// y cuatro horas para el app open. Los dos márgenes son el mismo criterio que
/// ya tenía el inventario: un anuncio que se vence entre el chequeo y la
/// presentación falla igual, así que se tira un rato antes del borde.
enum AdInventoryLifetime {
    /// Rewarded, interstitial y pausa publicitaria: una hora menos cinco
    /// minutos.
    static let standard: TimeInterval = 55 * 60
    /// App open: cuatro horas menos media hora. El margen es más largo porque
    /// el app open se precarga al irse a background y se muestra al volver,
    /// horas después: es justo el formato que más vive cerca del borde.
    static let appOpen: TimeInterval = 3 * 60 * 60 + 30 * 60
}

/// Simulador de dev: 2 s de "anuncio" falso.
///
/// ⚠️ **Esto NO puede llegar a la App Store**, y no por prolijidad: con el stub
/// activo el juego ofrece "mirá un video" y paga el premio sin mostrar ningún
/// anuncio, mientras la tienda vende `remove_ads`. Vender la remoción de una
/// publicidad que no existe es exactamente lo que la guideline 2.3.1 llama
/// engañoso. Quien elige el proveedor es `RootView`, mirando `useRealAds`.
@Observable @MainActor
final class StubAdsProvider: AdsProvider {
    private(set) var isShowing = false
    var isInterstitialReady: Bool { !isShowing }
    var isRewardedInterstitialReady: Bool { !isShowing }
    var isAppOpenReady: Bool { !isShowing }

    func isRewardedReady(for placement: RewardedPlacement) -> Bool { !isShowing }

    /// El stub no precarga: su "anuncio" es un `Task.sleep`.
    func preloadRewarded(for placement: RewardedPlacement) {}
    func preloadRewardedInterstitial() {}
    func preloadAppOpen() {}

    func showRewarded(for placement: RewardedPlacement) async -> Bool {
        await fakeAd(for: .seconds(2))
    }

    func showInterstitial() async {
        await fakeAd(for: .seconds(1))
    }

    /// Dura lo que un rewarded: es un video con premio, aunque nadie lo pidió.
    func showRewardedInterstitial() async -> Bool {
        await fakeAd(for: .seconds(2))
    }

    func showAppOpen() async {
        await fakeAd(for: .seconds(1))
    }

    /// El "anuncio" falso: ocupa la pantalla un rato y siempre paga. Devuelve
    /// `false` sólo si ya había otro en curso, como el real.
    @discardableResult
    private func fakeAd(for duration: Duration) async -> Bool {
        guard !isShowing else { return false }
        isShowing = true
        defer { isShowing = false }
        try? await Task.sleep(for: duration)
        return true
    }

    /// El stub no precarga: su "anuncio" es un `Task.sleep`.
    func prepare() {}
}

/// Mirrored 1:1 from `rewarded_ads.json` — the four effects of bible §4.4 plus
/// el cofre de pintas, que llegó con el sistema de cofres.
struct RewardedAdsConfig: Codable, Sendable, Equatable {
    enum EffectType: String, Codable, Sendable {
        /// Temporary income multiplier (double earnings / temp multiplier).
        case incomeMultiplier
        /// Free instant merge of the highest mergeable pair (accelerate evolution).
        case instantMerge
        /// Grants a unit of the highest tier reached (spawn rare — F4 stub;
        /// F5 rewires this to the real special-character drop).
        case rareUnit
        /// Un cofre de pintas. Es la única fuente con freno propio: el cooldown
        /// del video es lo que evita que la colección se vacíe en una tarde.
        case skinChest
    }

    struct Reward: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let effectType: EffectType
        let magnitude: Double?
        let durationSeconds: Double?
        let titleKey: String
        /// Cuánto tarda ESTA recompensa en volver a ofrecerse (RF-11). Los
        /// cooldowns corren en paralelo: mirar un video no bloquea a los otros.
        let cooldownSeconds: Double
    }

    /// La cadencia del interstitial. Vive en `rewarded_ads.json` porque ése ES
    /// el archivo de configuración de anuncios del juego, aunque su nombre
    /// histórico diga "rewarded".
    ///
    /// ⚠️ **Los tres números son la política de "no molestar", y ninguno es
    /// decorativo.** El pedido del dueño (2026-09-02) fue "un anuncio normal
    /// cada 5 o 10 minutos de juego"; esto lo implementa con dos frenos que
    /// evitan los dos casos que arruinan la primera sesión:
    ///
    /// - `graceSecondsAfterLaunch`: nadie come un interstitial en sus primeros
    ///   minutos. Es el tramo donde se decide si el juego se desinstala.
    /// - `graceSecondsAfterRewarded`: un jugador que acaba de mirar un video
    ///   por elección propia no se come otro de arranque. Sin esto, mirar un
    ///   rewarded y cerrar la hoja podía encadenar dos pantallas completas de
    ///   publicidad seguidas, que es la queja número uno de los idle.
    struct Interstitial: Codable, Sendable, Equatable {
        /// Segundos de juego ACTIVO (foreground) entre dos interstitials.
        let minSecondsBetween: Double
        /// Gracia desde que arrancó la app.
        let graceSecondsAfterLaunch: Double
        /// Gracia desde que terminó un rewarded.
        let graceSecondsAfterRewarded: Double

        /// Los defaults, para los JSON viejos (schema 1) que no traen la sección.
        static let `default` = Interstitial(
            minSecondsBetween: 420,
            graceSecondsAfterLaunch: 180,
            graceSecondsAfterRewarded: 90
        )
    }

    let schemaVersion: Int
    let rewards: [Reward]
    /// Segundos de producción que se acreditan cuando un video visto ya no tiene
    /// dónde aplicar su efecto.
    let compensationSeconds: Double
    /// Ausente en schema 1.
    let interstitial: Interstitial?

    var effectiveInterstitial: Interstitial { interstitial ?? .default }
}
