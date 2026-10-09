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
    ///
    /// Si el video todavía no está, **espera la carga en curso (o la arranca)
    /// hasta `AdLoadWait.rewardedTimeout`** y presenta apenas llega: el botón
    /// responde al primer toque (PLAN-v2 E13 ítem 1). `false` sin presentar nada
    /// quiere decir que no hubo video; ver `lastRewardedAttempt` para distinguirlo
    /// de un jugador que cerró el video a la mitad.
    func showRewarded(for placement: RewardedPlacement) async -> Bool

    /// Qué pasó con el último `showRewarded`. Es lo que separa "no hay videos
    /// ahora" (`.noInventory`: la UI lo dice) de "lo cerró a los dos segundos"
    /// (`.presented` sin premio: la UI calla) y de "había otro anuncio en curso"
    /// (`.busy`: tampoco se avisa, el jugador ya está viendo un video).
    var lastRewardedAttempt: RewardedAttempt { get }

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

/// Cómo terminó el último intento de `showRewarded`.
enum RewardedAttempt: Equatable, Sendable {
    /// Hubo un video en pantalla, haya pagado o no.
    case presented
    /// No llegó inventario a tiempo (o la espera se canceló): nada se presentó.
    case noInventory
    /// Había otro anuncio en curso: este toque no hizo nada.
    case busy
}

/// La espera de un video que todavía se está cargando (PLAN-v2 E13 ítem 1).
///
/// Vive suelta y pura para poder probarse sin el SDK: el proveedor real le
/// pasa sus dos preguntas y ella sólo sabe esperar. Termina en cuanto el video
/// está, en cuanto la carga se cayó sin dejar nada (no hay inventario: esperar
/// el resto del plazo sería hacer mirar una ruedita para nada), o al vencer el
/// plazo.
enum AdLoadWait {
    /// Cuánto espera un toque a que llegue el video antes de decir que no hay.
    static let rewardedTimeout: Duration = .seconds(8)

    @MainActor
    static func until(
        timeout: Duration = rewardedTimeout,
        interval: Duration = .milliseconds(100),
        isReady: () -> Bool,
        isLoading: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while true {
            if isReady() { return true }
            if !isLoading() || clock.now >= deadline { return false }
            // Cancelada la espera (la vista se fue), se sale: `try?` tragaría el
            // error y el bucle bloquearía el main actor hasta el plazo.
            do { try await Task.sleep(for: interval) } catch { return false }
        }
    }
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
    @ObservationIgnored private(set) var lastRewardedAttempt = RewardedAttempt.noInventory
    /// Cuánto tarda en "llegar" el video antes de presentarse. Cero salvo bajo
    /// `--uitest-slow-ad-load`, que lo estira para que un UI test pueda tocar
    /// dos veces con el primer toque todavía cargando.
    @ObservationIgnored private let loadDelay: Duration = ProcessInfo.processInfo.arguments.contains("--uitest-slow-ad-load")
        ? .milliseconds(1500) : .zero
    var isInterstitialReady: Bool { !isShowing }
    var isRewardedInterstitialReady: Bool { !isShowing }
    var isAppOpenReady: Bool { !isShowing }

    func isRewardedReady(for placement: RewardedPlacement) -> Bool { !isShowing }

    /// El stub no precarga: su "anuncio" es un `Task.sleep`.
    func preloadRewarded(for placement: RewardedPlacement) {}
    func preloadRewardedInterstitial() {}
    func preloadAppOpen() {}

    func showRewarded(for placement: RewardedPlacement) async -> Bool {
        lastRewardedAttempt = .noInventory
        if loadDelay > .zero { try? await Task.sleep(for: loadDelay) }
        let earned = await fakeAd(for: .seconds(2))
        lastRewardedAttempt = earned ? .presented : .noInventory
        return earned
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

/// Mirrored 1:1 from `rewarded_ads.json` — los efectos de los videos: el
/// multiplicador de ingresos, "Fusionar todo", el personaje de regalo y el
/// cofre de pintas.
struct RewardedAdsConfig: Codable, Sendable, Equatable {
    enum EffectType: String, Codable, Sendable, CaseIterable {
        /// Temporary income multiplier (double earnings / temp multiplier).
        case incomeMultiplier
        /// "Fusionar todo" del piso a la vista, por el embudo (PLAN-v2 E13).
        case mergeAll
        /// Un personaje de `tiersBelowFrontier` por debajo de la frontera (E13).
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
        /// Sólo lo lleva `rareUnit`: cuántos tiers por debajo de la frontera llega.
        let tiersBelowFrontier: Int?
        let titleKey: String
        /// Cuánto tarda ESTA recompensa en volver a ofrecerse (RF-11). Los
        /// cooldowns corren en paralelo: mirar un video no bloquea a los otros.
        let cooldownSeconds: Double
    }

    let schemaVersion: Int
    let rewards: [Reward]
    /// Segundos de producción que se acreditan cuando un video visto ya no tiene
    /// dónde aplicar su efecto.
    let compensationSeconds: Double
}
