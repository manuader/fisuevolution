import Foundation

/// Dónde aparece una oferta de video. Es lo que decide **qué unidad de AdMob**
/// sirve el anuncio, y existe como enum y no como string suelto para que
/// agregar una oferta sin darle unidad sea un error de compilación y no un
/// anuncio que no carga.
///
/// La separación es por MOMENTO y no por premio: AdMob reporta por unidad, así
/// que lo que conviene poder comparar es "¿factura más el video del cofre o el
/// del offline?". Los cinco premios de la lista de Regalos comparten pantalla y
/// momento, así que comparten unidad (`gifts`).
enum RewardedPlacement: String, Sendable, CaseIterable {
    /// La lista de videos de **Regalos**: los cinco premios de `rewarded_ads.json`.
    case gifts
    /// El popup de ganancias offline: duplicar lo que juntó mientras no estabas.
    case offlineX2
    /// Después de cerrar un cofre: abrir otro.
    case chestExtra
    /// Un boost en cooldown: activarlo sin esperar.
    case boost
}

/// Runtime feature switches, mirrored 1:1 from `feature_flags.json`.
/// F6 flips `gameCenterEnabled`/`cloudKitEnabled` by editing the JSON — no code changes.
struct FeatureFlags: Codable, Sendable, Equatable {

    /// Los ad unit IDs de AdMob, uno por lugar donde el juego ofrece un video.
    /// Son **datos de cuenta, no configuración de código**: cambian al pasar de
    /// la cuenta de prueba a la real sin que se recompile nada.
    ///
    /// ⚠️ El **App ID** de AdMob NO está acá y no puede estarlo: va en el
    /// `Info.plist` (`GADApplicationIdentifier`), porque el SDK lo lee del
    /// bundle antes de que corra una línea nuestra. Son dos lugares distintos
    /// para dos cosas distintas, y hay que cambiar los dos.
    ///
    /// ⚠️ Ojo con la forma de los ids: el App ID lleva **`~`**, los ad unit IDs
    /// llevan **`/`**. Confundirlos falla recién en runtime.
    struct AdUnitIDs: Codable, Sendable, Equatable {
        /// La unidad de la lista de Regalos. Es la **única obligatoria**: las
        /// otras tres caen a ésta si faltan, así que un juego con una sola
        /// unidad creada funciona entero (pierde el reporting por oferta, nada
        /// más).
        let rewardedGifts: String
        let rewardedOfflineX2: String?
        let rewardedChestExtra: String?
        let rewardedBoost: String?

        /// La unidad de interstitial, **opcional a propósito**.
        ///
        /// ⚠️ `nil` NO es un olvido: significa "este build no muestra
        /// interstitials". La alternativa —caer al ID de prueba de Google— sería
        /// mostrarle anuncios de relleno a jugadores reales, que no paga nada y
        /// encima gasta la paciencia del jugador. Mejor no mostrar ninguno.
        ///
        /// ⚠️⚠️ Y tiene una consecuencia que NO es técnica: **sin interstitial no
        /// hay nada que `remove_ads` pueda sacar.** Los rewarded son opt-in por
        /// política de Google ("Rewarded ads must always be an opt-in
        /// experience"), así que un juego rewarded-only no tiene publicidad
        /// interruptiva, y vender su remoción sería vender aire. Quien lo vigila
        /// es `theStoreDoesNotSellRemovingAdsThatDoNotExist`.
        let interstitial: String?

        /// Qué unidad sirve a cada oferta, con el fallback ya resuelto.
        func rewarded(for placement: RewardedPlacement) -> String {
            let specific: String? = switch placement {
            case .gifts: rewardedGifts
            case .offlineX2: rewardedOfflineX2
            case .chestExtra: rewardedChestExtra
            case .boost: rewardedBoost
            }
            return specific ?? rewardedGifts
        }

        /// Los IDs de PRUEBA públicos de Google
        /// (developers.google.com/admob/ios/test-ads). Sirven anuncios de
        /// relleno siempre, sin cuenta y sin riesgo de invalid traffic.
        ///
        /// Se usan como fallback cuando el JSON no trae NADA, para que el juego
        /// nunca quede sin anuncios por un archivo incompleto — pero **el
        /// `store` build tiene que traer los reales**, y de eso avisa
        /// `GameContentValidationTests.storeBuildsUseRealAdUnitIDs`.
        static let googleTest = AdUnitIDs(
            rewardedGifts: "ca-app-pub-3940256099942544/1712485313",
            rewardedOfflineX2: nil,
            rewardedChestExtra: nil,
            rewardedBoost: nil,
            interstitial: "ca-app-pub-3940256099942544/4411468910"
        )

        /// Si CUALQUIER id declarado es uno de prueba de Google. Es "cualquiera"
        /// y no "todos" porque el caso que hay que cazar es el build medio
        /// migrado: cuatro unidades reales puestas y una olvidada en la de
        /// prueba.
        var usesAnyGoogleTestID: Bool {
            let test = Self.googleTest
            let declared = [
                rewardedGifts, rewardedOfflineX2, rewardedChestExtra,
                rewardedBoost, interstitial,
            ].compactMap { $0 }
            return declared.contains(test.rewardedGifts)
                || declared.contains(test.interstitial ?? "")
        }
    }

    let schemaVersion: Int
    let gameCenterEnabled: Bool
    let cloudKitEnabled: Bool
    let useRealAds: Bool
    /// `"dev"` during development; `"store"` builds serve only review-safe content.
    let buildVariant: String
    /// Ausente en los JSON viejos (schema ≤2): cae a los IDs de prueba de Google.
    let adUnitIDs: AdUnitIDs?

    /// Los IDs efectivos, con el fallback ya resuelto.
    var effectiveAdUnitIDs: AdUnitIDs { adUnitIDs ?? .googleTest }

    /// Si este build es el que se manda a la App Store.
    var isStoreBuild: Bool { buildVariant == "store" }
}
