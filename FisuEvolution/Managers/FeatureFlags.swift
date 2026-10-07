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
///
/// Los cuatro de la 2.0 (`wheel`, `treasure`, `visitor`, `daily`) agrupan cada
/// uno varias ofertas del mismo momento (PLAN-v2, mapa de ubicaciones de E7):
/// quince ofertas en quince unidades serían quince columnas de reporte con
/// tres impresiones cada una, que no dicen nada.
enum RewardedPlacement: String, Sendable, CaseIterable {
    /// La lista de videos de **Regalos**: los cinco premios de `rewarded_ads.json`.
    case gifts
    /// El popup de ganancias offline: duplicar lo que juntó mientras no estabas.
    case offlineX2
    /// Después de cerrar un cofre: abrir otro.
    case chestExtra
    /// Un boost en cooldown: activarlo sin esperar. También "Fusionar todo".
    case boost
    /// La ruleta: el giro por video y el "repetir premio".
    case wheel
    /// El Colchón: abrirlo, "otro colchón" y la lluvia de paquetes.
    case treasure
    /// Visitantes y eventos: el ×2 del visitante, la multa perdonada, los
    /// boosts del Vendedor, el ×2 del reto y los escapes de eventos negativos.
    case visitor
    /// El diario ×2 y la carrera ×2.
    case daily
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
        /// demás de video caen a ésta si faltan, así que un juego con una sola
        /// unidad creada funciona entero (pierde el reporting por oferta, nada
        /// más).
        let rewardedGifts: String
        let rewardedOfflineX2: String?
        let rewardedChestExtra: String?
        let rewardedBoost: String?
        /// Las cuatro de la 2.0. Mientras el dueño no cree la unidad en AdMob
        /// quedan en `nil` y sirven por la de Regalos: la oferta anda igual,
        /// sólo que su plata se reporta mezclada con la de Regalos.
        let rewardedWheel: String?
        let rewardedTreasure: String?
        let rewardedVisitor: String?
        let rewardedDaily: String?

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

        /// La pausa publicitaria (intersticial bonificado). Mismo criterio que
        /// `interstitial`: `nil` es "este build no la muestra", nunca un hueco
        /// a rellenar con la de prueba.
        let rewardedInterstitial: String?

        /// El app open, al volver a la app.
        ///
        /// ⚠️ **[GATE DEL DUEÑO]** La unidad todavía no existe en AdMob, así que
        /// el `feature_flags.json` la trae en `null` a propósito: con `nil` el
        /// proveedor no la precarga y el formato queda apagado. Se prende
        /// creando la unidad (formato "Inicio de aplicación") y poniendo su ID
        /// acá y en la config remota, cuyo interruptor `appOpen` también
        /// arranca apagado.
        let appOpen: String?

        init(
            rewardedGifts: String,
            rewardedOfflineX2: String? = nil,
            rewardedChestExtra: String? = nil,
            rewardedBoost: String? = nil,
            rewardedWheel: String? = nil,
            rewardedTreasure: String? = nil,
            rewardedVisitor: String? = nil,
            rewardedDaily: String? = nil,
            interstitial: String? = nil,
            rewardedInterstitial: String? = nil,
            appOpen: String? = nil
        ) {
            self.rewardedGifts = rewardedGifts
            self.rewardedOfflineX2 = rewardedOfflineX2
            self.rewardedChestExtra = rewardedChestExtra
            self.rewardedBoost = rewardedBoost
            self.rewardedWheel = rewardedWheel
            self.rewardedTreasure = rewardedTreasure
            self.rewardedVisitor = rewardedVisitor
            self.rewardedDaily = rewardedDaily
            self.interstitial = interstitial
            self.rewardedInterstitial = rewardedInterstitial
            self.appOpen = appOpen
        }

        /// Qué unidad sirve a cada oferta, con el fallback ya resuelto.
        ///
        /// ⚠️ El `switch` es exhaustivo **a propósito**, sin `default`: un
        /// placement nuevo que no diga de qué unidad sale no compila.
        func rewarded(for placement: RewardedPlacement) -> String {
            let specific: String? = switch placement {
            case .gifts: rewardedGifts
            case .offlineX2: rewardedOfflineX2
            case .chestExtra: rewardedChestExtra
            case .boost: rewardedBoost
            case .wheel: rewardedWheel
            case .treasure: rewardedTreasure
            case .visitor: rewardedVisitor
            case .daily: rewardedDaily
            }
            return specific ?? rewardedGifts
        }

        /// Todos los IDs declarados, de cualquier formato. Es lo que miran las
        /// dos validaciones que no pueden olvidarse de ninguno: la de los IDs
        /// de prueba y la del publisher propio de la config remota.
        var allDeclared: [String] {
            [
                rewardedGifts, rewardedOfflineX2, rewardedChestExtra, rewardedBoost,
                rewardedWheel, rewardedTreasure, rewardedVisitor, rewardedDaily,
                interstitial, rewardedInterstitial, appOpen,
            ].compactMap { $0 }
        }

        /// El publisher de las unidades de prueba de Google.
        static let googleTestPublisher = "3940256099942544"

        /// Los IDs de PRUEBA públicos de Google
        /// (developers.google.com/admob/ios/test-ads). Sirven anuncios de
        /// relleno siempre, sin cuenta y sin riesgo de invalid traffic.
        ///
        /// Se usan como fallback cuando el JSON no trae NADA, para que el juego
        /// nunca quede sin anuncios por un archivo incompleto — pero **el
        /// `store` build tiene que traer los reales**, y de eso avisa
        /// `GameContentValidationTests.storeBuildsUseRealAdUnitIDs`.
        ///
        /// Trae los cuatro formatos, app open incluido, para que en DEBUG se
        /// puedan probar todos aunque la unidad real todavía no exista.
        static let googleTest = AdUnitIDs(
            rewardedGifts: "ca-app-pub-3940256099942544/1712485313",
            interstitial: "ca-app-pub-3940256099942544/4411468910",
            rewardedInterstitial: "ca-app-pub-3940256099942544/6978759866",
            appOpen: "ca-app-pub-3940256099942544/5575463023"
        )

        /// Si CUALQUIER id declarado es uno de prueba de Google. Es "cualquiera"
        /// y no "todos" porque el caso que hay que cazar es el build medio
        /// migrado: cuatro unidades reales puestas y una olvidada en la de
        /// prueba.
        ///
        /// Se mira el publisher y no una lista de IDs conocidos: Google tiene
        /// una unidad de prueba por formato, y una lista se queda corta en
        /// cuanto aparece un formato nuevo.
        var usesAnyGoogleTestID: Bool {
            allDeclared.contains { $0.hasPrefix("ca-app-pub-\(Self.googleTestPublisher)/") }
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
    ///
    /// ⚠️⚠️ **En DEBUG son SIEMPRE los de prueba de Google, pase lo que pase
    /// diga el JSON.** No es una comodidad: es la regla que Google escribe en
    /// mayúsculas en su propia guía — *"When building and testing your apps,
    /// make sure you use test ads rather than live, production ads. Failure to
    /// do so can lead to suspension of your account."*
    ///
    /// El riesgo es concreto y asimétrico. En el SIMULADOR el SDK se
    /// autodeclara test device y no pasa nada; en un **iPhone de verdad no**,
    /// así que un build de desarrollo instalado en el teléfono del dueño pide
    /// anuncios REALES de su propia cuenta, y cada toque suyo es click fraud
    /// contra sí mismo. La alternativa —acordarse de registrar cada device en
    /// la consola de AdMob— es un paso humano que se olvida una vez y cuesta la
    /// cuenta.
    ///
    /// Lo que se pierde: en Debug no se puede comprobar que las unidades reales
    /// sirven inventario. Eso se verifica donde corresponde, en TestFlight, que
    /// es un build Release.
    var effectiveAdUnitIDs: AdUnitIDs {
        #if DEBUG
        .googleTest
        #else
        adUnitIDs ?? .googleTest
        #endif
    }

    /// Los IDs tal como vienen del JSON, sin la sustitución de DEBUG. Es lo que
    /// mira el test que impide embarcar un build de tienda con los de prueba:
    /// los tests corren en Debug, así que preguntarle a `effectiveAdUnitIDs`
    /// siempre vería los de Google y el test no probaría nada.
    var declaredAdUnitIDs: AdUnitIDs { adUnitIDs ?? .googleTest }

    /// Si este build es el que se manda a la App Store.
    ///
    /// ⚠️ **Se deriva de la CONFIGURACIÓN DE BUILD, no del JSON**, y eso cambió
    /// el 2026-09-06. El valor de `buildVariant` quedó como documentación y
    /// como puerta de escape para los tests.
    ///
    /// El motivo es que el flip manual era un footgun con consecuencia real y
    /// silenciosa: lo que decide `buildVariant` es si los boosts muestran sus
    /// nombres **review-safe** (el fernet, que es alcohol, y que hay que
    /// declarar en el rating). Olvidarse de ponerlo en `"store"` antes de
    /// archivar **no rompe nada**: la app compila, corre y se sube igual, con
    /// el contenido de desarrollo adentro. Un paso humano que no falla cuando
    /// se olvida es un paso que se va a olvidar.
    ///
    /// Con esto, todo build Release —el único que se puede subir— es de tienda
    /// por construcción, y Debug nunca lo es.
    var isStoreBuild: Bool {
        #if DEBUG
        // ⚠️ `--screenshot-mode` cuenta como build de tienda, y no es un
        // detalle: las capturas de la ficha se sacan en DEBUG porque necesitan
        // los fixtures `--uitest-*`, pero **lo que muestran tiene que ser lo
        // que se publica**. Sin esto, las capturas salían con los nombres de
        // desarrollo de los boosts —"Fernet con Coca" en vez del review-safe—
        // y la ficha le habría mostrado a Apple una bebida alcohólica que el
        // build de tienda no nombra, justo el contenido sobre el que se
        // declara el rating. Detectado mirando el PNG, no el código.
        //
        // Los tests corren en Debug y algunos necesitan ejercer la rama de
        // tienda: para eso queda además el JSON como override explícito.
        buildVariant == "store"
            || ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
        #else
        true
        #endif
    }

    /// El variante EFECTIVO, que es lo que eligen los textos review-safe.
    /// Misma regla que `isStoreBuild`: lo manda la configuración de build.
    var effectiveBuildVariant: String { isStoreBuild ? "store" : buildVariant }
}
