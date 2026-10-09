import Foundation
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// El proveedor real de anuncios: AdMob detrás de `feature_flags.useRealAds`.
///
/// Toda la clase es `@MainActor`, y no por costumbre: la API del SDK que
/// presenta —`present(from:)`, `canPresent(from:)` y **todos** los métodos de
/// `FullScreenContentDelegate`— viene anotada `NS_SWIFT_UI_ACTOR` en los
/// headers, que es `@MainActor` del otro lado del puente. Aislar la clase
/// entera es lo que hace que eso no genere un solo salto de actor.
///
/// ## Las tres cosas que hacen que esto no sea un wrapper trivial
///
/// **1. "Se ganó el premio" y "se cerró el anuncio" son eventos distintos, y
/// llegan por caminos distintos.** El premio llega por el
/// `userDidEarnRewardHandler` de `present`; el cierre, por
/// `adDidDismissFullScreenContent` del delegate. Un jugador que abre el video y
/// lo cierra a los dos segundos dispara **el segundo y no el primero**. Por eso
/// `showRewarded` espera el CIERRE y devuelve lo que haya pasado con el premio:
/// si esperara el premio, el `await` de un jugador que cierra el anuncio no
/// volvería nunca y la fila quedaría con el spinner para siempre.
///
/// La doc de AdMob confirma que el orden es seguro para los anuncios de Google
/// ("all `userDidEarnRewardHandler` calls occur before
/// `adDidDismissFullScreenContent:`"), y avisa que **con mediación el orden lo
/// decide el SDK de terceros** — otra razón para no atarse al orden y esperar
/// el cierre.
///
/// **2. Un anuncio se consume.** Una instancia sirve para UNA presentación.
/// Por eso el ad cargado se saca del inventario ANTES de presentarse (no
/// después): si el jugador toca dos veces rápido, el segundo toque encuentra
/// vacío y no intenta re-presentar un anuncio ya usado, que el SDK rechaza.
///
/// **3. Los anuncios se vencen a la hora.** Lo dice la doc de AdMob: *"ads
/// expire after an hour, you should clear this cache and reload with new ads
/// every hour"*. Un idle se deja abierto o en background durante horas, así que
/// éste es el caso normal y no el raro: sin el chequeo de frescura, el primer
/// video de la tarde falla al presentarse y el jugador ve un botón que no hace
/// nada. Ver `AdInventory.isFresh`. El app open vive más (cuatro horas), y por
/// eso la vida es del inventario y no una constante del tipo: ver
/// `AdInventoryLifetime`.
@Observable @MainActor
final class AdMobAdsProvider: AdsProvider {

    private let unitIDs: FeatureFlags.AdUnitIDs
    /// Inyectable para que los tests puedan envejecer el inventario sin esperar
    /// 55 minutos.
    private let now: @Sendable () -> Date

    @ObservationIgnored private var rewarded: [RewardedPlacement: AdInventory<RewardedAd>] = [:]
    /// Los placements con una carga en vuelo, para no pedir dos veces el mismo.
    @ObservationIgnored private var loadingRewarded: Set<RewardedPlacement> = []
    @ObservationIgnored private var interstitial: AdInventory<InterstitialAd>?
    @ObservationIgnored private var loadingInterstitial = false
    @ObservationIgnored private var rewardedInterstitial: AdInventory<RewardedInterstitialAd>?
    @ObservationIgnored private var loadingRewardedInterstitial = false
    @ObservationIgnored private var appOpen: AdInventory<AppOpenAd>?
    @ObservationIgnored private var loadingAppOpen = false
    /// ⚠️ Un solo observador para los cuatro formatos, y por eso nunca puede
    /// haber dos presentaciones a la vez: la segunda pisaría la continuación de
    /// la primera, que no volvería nunca. Lo garantiza `AdsCoordinator`, que es
    /// el único que llama acá y rechaza un anuncio mientras hay otro en
    /// pantalla.
    @ObservationIgnored private let presentation = FullScreenAdObserver()
    @ObservationIgnored private(set) var lastRewardedAttempt = RewardedAttempt.noInventory
    @ObservationIgnored private var didStartSDK = false

    init(
        unitIDs: FeatureFlags.AdUnitIDs,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.unitIDs = unitIDs
        self.now = now
    }

    // MARK: - Arranque

    /// Arranca el SDK y deja precargado lo que se usa primero.
    ///
    /// ⚠️ El orden importa y es el del checklist de `Docs/ads-integration.md`:
    /// el consentimiento (UMP + ATT) va ANTES de `start()`. Quien lo garantiza
    /// es `AdsConsent.resolve()`, que el llamador espera antes de llamar acá.
    ///
    /// Precarga **sólo `gifts` y el interstitial**, no las cuatro unidades: un
    /// rewarded pesa y se vence, así que traer los cuatro al arranque gasta red
    /// del jugador en tres anuncios que quizá no vea nunca. Los otros los pide
    /// la UI con `preloadRewarded(for:)` cuando la oferta está por aparecer.
    ///
    /// Por lo mismo **no precarga la pausa publicitaria ni el app open**: los
    /// pide quien los va a mostrar (`preloadRewardedInterstitial()` antes de
    /// ofrecer la pausa, `preloadAppOpen()` al irse a background). Un anuncio
    /// cargado y nunca mostrado no es gratis: gasta red del jugador y se vence
    /// en la memoria, y en los reportes de AdMob baja la tasa de presentación
    /// (*show rate*) de su unidad.
    func prepare() {
        guard !didStartSDK else { return }
        didStartSDK = true
        Task {
            await MobileAds.shared.start()
            // El rating del contenido se limita a "Teen" para no romper el 12+
            // declarado de la app: un ad de casino o de contenido adulto en un
            // juego con rating 12+ es una queja de review con la app publicada.
            MobileAds.shared.requestConfiguration.maxAdContentRating = .teen
            preloadRewarded(for: .gifts)
            preloadInterstitial()
        }
    }

    // MARK: - Rewarded

    func isRewardedReady(for placement: RewardedPlacement) -> Bool {
        guard let entry = rewarded[placement] else { return false }
        return entry.isFresh(now: now())
    }

    func preloadRewarded(for placement: RewardedPlacement) {
        // Ya hay uno fresco, o ya se está pidiendo.
        if isRewardedReady(for: placement) || loadingRewarded.contains(placement) { return }
        rewarded[placement] = nil
        loadingRewarded.insert(placement)
        Task { await loadRewarded(placement) }
    }

    private func loadRewarded(_ placement: RewardedPlacement) async {
        defer { loadingRewarded.remove(placement) }
        do {
            let ad = try await RewardedAd.load(
                with: unitIDs.rewarded(for: placement), request: Request()
            )
            rewarded[placement] = AdInventory(ad: ad, loadedAt: now(), lifetime: AdInventoryLifetime.standard)
        } catch {
            // Quedarse sin anuncio es NORMAL (sin red, sin inventario, cuota
            // del día): no es un error que el jugador tenga que ver. La fila
            // del video se apaga sola y vuelve cuando haya inventario.
            rewarded[placement] = nil
        }
    }

    /// ⚠️ **No devuelve `false` en el acto si el video no está.** Espera la
    /// carga en curso —o la arranca— hasta `AdLoadWait.rewardedTimeout` y
    /// presenta apenas llega: antes el primer toque pedía el video y se rendía,
    /// y recién el segundo andaba (PLAN-v2 E13 ítem 1). `false` sin presentar
    /// (`lastRewardedAttempt == .noInventory`) es "no hubo inventario a tiempo".
    func showRewarded(for placement: RewardedPlacement) async -> Bool {
        lastRewardedAttempt = .noInventory
        if !isRewardedReady(for: placement) {
            preloadRewarded(for: placement)
            let arrived = await AdLoadWait.until(
                isReady: { isRewardedReady(for: placement) },
                isLoading: { loadingRewarded.contains(placement) }
            )
            guard arrived else { return false }
        }
        guard let entry = rewarded[placement], entry.isFresh(now: now()) else { return false }
        // Se saca del inventario ANTES de presentar: el ad se consume.
        rewarded[placement] = nil

        var earnedReward = false
        let ad = entry.ad
        ad.fullScreenContentDelegate = presentation
        // Se anota cuando el SDK confirma que va a presentar, no antes: si
        // `present` falla, nada llegó a la pantalla.
        presentation.onWillPresent = { [weak self] in self?.lastRewardedAttempt = .presented }
        defer { presentation.onWillPresent = nil }
        await presentation.present {
            ad.present(from: nil) { earnedReward = true }
        }

        // Reponer inventario para la próxima, gane o no gane.
        preloadRewarded(for: placement)
        return earnedReward
    }

    // MARK: - Interstitial

    var isInterstitialReady: Bool {
        guard let interstitial else { return false }
        return interstitial.isFresh(now: now())
    }

    func preloadInterstitial() {
        // Sin unidad declarada, este build no muestra interstitials y no hay
        // nada que precargar. Ver el aviso en `FeatureFlags.AdUnitIDs`.
        guard let unitID = unitIDs.interstitial else { return }
        if isInterstitialReady || loadingInterstitial { return }
        interstitial = nil
        loadingInterstitial = true
        Task {
            defer { loadingInterstitial = false }
            do {
                let ad = try await InterstitialAd.load(with: unitID, request: Request())
                interstitial = AdInventory(ad: ad, loadedAt: now(), lifetime: AdInventoryLifetime.standard)
            } catch {
                interstitial = nil
            }
        }
    }

    func showInterstitial() async -> Bool {
        guard let entry = interstitial, entry.isFresh(now: now()) else {
            interstitial = nil
            preloadInterstitial()
            return false
        }
        interstitial = nil

        let ad = entry.ad
        ad.fullScreenContentDelegate = presentation
        let presented = await presentation.present { ad.present(from: nil) }

        preloadInterstitial()
        return presented
    }

    // MARK: - Pausa publicitaria (intersticial bonificado)

    var isRewardedInterstitialReady: Bool {
        guard let rewardedInterstitial else { return false }
        return rewardedInterstitial.isFresh(now: now())
    }

    func preloadRewardedInterstitial() {
        // Sin unidad declarada, este build no muestra la pausa publicitaria.
        guard let unitID = unitIDs.rewardedInterstitial else { return }
        if isRewardedInterstitialReady || loadingRewardedInterstitial { return }
        rewardedInterstitial = nil
        loadingRewardedInterstitial = true
        Task {
            defer { loadingRewardedInterstitial = false }
            do {
                let ad = try await RewardedInterstitialAd.load(with: unitID, request: Request())
                rewardedInterstitial = AdInventory(
                    ad: ad, loadedAt: now(), lifetime: AdInventoryLifetime.standard
                )
            } catch {
                rewardedInterstitial = nil
            }
        }
    }

    /// Mismo baile que `showRewarded`: se espera el CIERRE y se devuelve lo que
    /// haya pasado con el premio, que llega por otro callback (ver el punto 1
    /// del docstring de la clase).
    func showRewardedInterstitial() async -> Bool {
        guard let entry = rewardedInterstitial, entry.isFresh(now: now()) else {
            rewardedInterstitial = nil
            preloadRewardedInterstitial()
            return false
        }
        rewardedInterstitial = nil

        var earnedReward = false
        let ad = entry.ad
        ad.fullScreenContentDelegate = presentation
        await presentation.present {
            ad.present(from: nil) { earnedReward = true }
        }

        preloadRewardedInterstitial()
        return earnedReward
    }

    // MARK: - App open

    var isAppOpenReady: Bool {
        guard let appOpen else { return false }
        return appOpen.isFresh(now: now())
    }

    func preloadAppOpen() {
        // [GATE DEL DUEÑO] Mientras no exista la unidad, `appOpen` es `nil` y
        // no hay nada que pedir. Ver el aviso en `FeatureFlags.AdUnitIDs`.
        guard let unitID = unitIDs.appOpen else { return }
        // Sin consentimiento resuelto (UMP) el SDK no puede pedir anuncios.
        guard ConsentInformation.shared.canRequestAds else { return }
        if isAppOpenReady || loadingAppOpen { return }
        appOpen = nil
        loadingAppOpen = true
        Task {
            defer { loadingAppOpen = false }
            do {
                let ad = try await AppOpenAd.load(with: unitID, request: Request())
                appOpen = AdInventory(ad: ad, loadedAt: now(), lifetime: AdInventoryLifetime.appOpen)
            } catch {
                appOpen = nil
            }
        }
    }

    func showAppOpen() async -> Bool {
        guard let entry = appOpen, entry.isFresh(now: now()) else {
            appOpen = nil
            preloadAppOpen()
            return false
        }
        appOpen = nil

        let ad = entry.ad
        ad.fullScreenContentDelegate = presentation
        let presented = await presentation.present { ad.present(from: nil) }

        // No se repone acá: el próximo app open se pide al volver a irse a
        // background, que es cuando hace falta (y el que se cargue ahora
        // podría vencerse antes).
        return presented
    }
}

// MARK: - El inventario

/// Un anuncio cargado, con el momento en que se cargó y cuánto vive.
///
/// El `loadedAt` es la mitad del valor de este tipo: es lo que permite tirar el
/// anuncio vencido ANTES de intentar mostrarlo.
///
/// Es genérico y vive fuera del proveedor para que los tests puedan envejecerlo
/// con un `String` en lugar de un anuncio del SDK, que no se puede construir.
struct AdInventory<Ad> {
    let ad: Ad
    let loadedAt: Date
    /// Margen sobre lo que declara AdMob: ver `AdInventoryLifetime`.
    let lifetime: TimeInterval

    func isFresh(now: Date) -> Bool {
        now.timeIntervalSince(loadedAt) < lifetime
    }
}

// MARK: - El puente entre el delegate y async/await

/// Convierte el par "presentá" / "se cerró" del SDK en un `await` que vuelve
/// cuando la pantalla se liberó.
///
/// Existe como objeto aparte por una razón concreta: `FullScreenContentDelegate`
/// es un protocolo de Objective-C y exige `NSObject`, mientras que el proveedor
/// es `@Observable`. Mezclar el macro de observación con una subclase de
/// `NSObject` que además es delegate del SDK es pedir problemas; separarlos
/// cuesta veinte líneas y deja las dos cosas simples.
///
/// ⚠️ **La continuación se resume UNA sola vez, y el guard no es defensivo por
/// las dudas.** El SDK puede llamar a `didFailToPresent` y, según el caso,
/// igual llamar a `adDidDismiss` después. Resumir dos veces la misma
/// `CheckedContinuation` es un **crash**, no un warning.
@MainActor
private final class FullScreenAdObserver: NSObject, FullScreenContentDelegate {
    private var continuation: CheckedContinuation<Void, Never>?
    /// Si el SDK avisó que va a presentar lo que está en vuelo.
    private var willPresentSeen = false
    /// Avisa que el SDK está por poner el anuncio en pantalla.
    var onWillPresent: (() -> Void)?

    /// Cuánto se espera el primer aviso del SDK antes de darlo por perdido. Un
    /// `present` que no llama a ningún método del delegate dejaría el `await`
    /// colgado, y con él la cola de celebraciones retenida.
    static let presentDeadline: Duration = .seconds(10)

    /// Presenta y espera hasta que el anuncio se haya cerrado (o haya fallado).
    /// Devuelve si llegó a la pantalla.
    @discardableResult
    func present(_ show: () -> Void) async -> Bool {
        willPresentSeen = false
        let watchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.presentDeadline)
            guard !Task.isCancelled, let self, !self.willPresentSeen else { return }
            self.finish()
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            show()
        }
        watchdog.cancel()
        return willPresentSeen
    }

    private func finish() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        willPresentSeen = true
        onWillPresent?()
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        finish()
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        // Si no se pudo presentar no hay cierre que esperar: se libera acá o el
        // llamador se queda colgado en el `await` para siempre.
        finish()
    }
}
