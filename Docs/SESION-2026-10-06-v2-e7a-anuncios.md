# Sesión 2026-10-06 — E7a: la infraestructura de anuncios de la 2.0

## El pedido

Primera mitad de la épica E7 de `Docs/PLAN-v2.md`: **la infraestructura** de
anuncios, sin UI y sin cambiar a quién llama a qué. Cinco piezas:

1. Formatos nuevos en el proveedor: pausa publicitaria (intersticial
   bonificado) y app open.
2. Unidades por momento para los videos de la 2.0, más la unidad de la pausa y
   el lugar del app open.
3. `AdsRemoteConfig`: IDs y cadencia publicados en `adergames-site`.
4. La política de cortes naturales, pura y con reloj inyectado.
5. La investigación de la mediación (AppLovin, Unity Ads, Mintegral y Meta),
   sin agregarla todavía a `project.yml`.

La pantalla previa de la pausa, la fila de UMP en Ajustes, la columna lateral y
el cableado de la política son de E7b.

## Lo que se hizo

### 1. Unidades y placements

- `RewardedPlacement` suma `wheel`, `treasure`, `visitor` y `daily`, que es el
  mapa de ubicaciones de E7: cada uno agrupa las ofertas de un mismo momento.
- `FeatureFlags.AdUnitIDs` suma sus cuatro unidades, que caen a la de Regalos
  mientras sean `null`, más `rewardedInterstitial` y `appOpen`.
- El `switch` de `rewarded(for:)` sigue exhaustivo y sin `default`: un
  placement sin unidad no compila.
- `feature_flags.json` trae:
  - la pausa con la unidad que ya existía, `ca-app-pub-8575641544774372/1615619906`;
  - **el app open en `null`**, apagado: es el gate del dueño.
- Los IDs de prueba de Google cubren los cuatro formatos. `usesAnyGoogleTestID`
  ahora mira el publisher de prueba (`3940256099942544`) en cualquier unidad,
  en vez de comparar contra dos IDs conocidos, que se quedaban cortos con
  cada formato nuevo.

### 2. Formatos nuevos en el proveedor

- `AdsProvider` suma `isRewardedInterstitialReady`,
  `preloadRewardedInterstitial()`, `showRewardedInterstitial() -> Bool`,
  `isAppOpenReady`, `preloadAppOpen()` y `showAppOpen()`.
- La pausa tiene el mismo contrato que el rewarded: `true` sólo si se ganó el
  premio, esperando el cierre y no el premio.
- **Vida del inventario por formato** (`AdInventoryLifetime`): 55 min para
  rewarded, intersticial y pausa, y 3 h 30 para el app open. AdMob declara
  1 h y 4 h; el margen es el mismo criterio que ya había.
- `AdInventory` salió del proveedor a nivel de archivo para poder envejecerlo
  en un test con un `String`.
- `AdMobAdsProvider` implementa los dos formatos con
  `RewardedInterstitialAd` y `AppOpenAd` del SDK 13.11.0 (verificado en los
  headers). `prepare()` **no** precarga ninguno de los dos.
- El stub los simula igual que a los otros.
- `AdsCoordinator`:
  - `remove_ads` corta los **tres** forzados (intersticial, pausa y app open),
    también sus precargas, y deja los videos opt-in;
  - nuevo `isPresentingFullScreen`: rechaza cualquier `show…` mientras hay
    otro anuncio en pantalla;
  - una pausa o un app open cerrados desarman el intersticial de la 1.x, igual
    que uno común;
  - `lastRewardedAt` pasa a `private(set)`, para que lo lea la política;
  - el `init` acepta un proveedor inyectado, que en producción sigue siendo el
    stub.

### 3. `AdsRemoteConfig`

- `AdsRemoteConfig` es el modelo y su validación; `AdsRemoteConfigLoader`, la
  red, la caché y el respaldo.
- Fuente: `https://adergames-site.vercel.app/config/ads.json`.
- Contenido: IDs, cadencia, alternancia (un patrón, p. ej.
  `["interstitial", "rewardedInterstitial"]`), reglas del app open,
  interruptores por formato forzado y `restrictedStorefronts`.
- El respaldo del bundle es `Resources/Config/ads.json`, con la misma forma.
- **Validación de todo o nada:**
  - esquema 1;
  - cada ID con el publisher del `GADApplicationIdentifier` (`8575641544774372`);
  - pisos numéricos;
  - alternancia no vacía, sin app open y de hasta 8 pasos;
  - tiendas en ISO alfa-3.
  - Con un solo campo inválido se descarta el archivo entero.
- **Red:**
  - un `GET` pelado, sin query, cuerpo, headers ni cookies, en una sesión
    efímera;
  - sólo HTTPS: una URL `http://` no se pide nunca, y una redirección a
    `http://` se descarta;
  - sólo se acepta un 200 de hasta 64 KB.
  - Un archivo malo no pisa la caché buena.
- **Arranque:** `current()` lee sólo el disco (la caché revalidada, o el
  bundle) y no toca la red; `refresh()` es aparte y asíncrono.
- La caché vive en `Caches/ads-remote-config.json`.

### 4. La política de cortes naturales

Son dos piezas, sin llamadores todavía:

- `NaturalBreakPolicy` (pura). Recibe el corte (`NaturalBreak`), el contexto
  del juego, el estado persistido, la sesión y la hora, y devuelve
  `.show(formato)` o `.skip(motivo)`.
- `ForcedAdsPacer`. Es el estado mínimo alrededor de la política: cuenta los
  arranques, mide la ausencia en background, guarda en `UserDefaults` lo que
  se mostró y le pregunta a la política.

Las reglas, en el orden en que se evalúan:

1. `remove_ads`, otro anuncio en pantalla, tutorial, hoja abierta o
   celebración: nada.
2. **≥ 2 min desde el último forzado, de cualquier formato**
   (`lastFullScreenAt` único). Eso mismo impide dos formatos en un corte.
3. 90 s después de un video con premio.
4. `returnFromBackground` sólo puede dar **app open**:
   - desde la 2ª sesión;
   - con ≥ 180 s afuera (un arranque en frío no tiene ausencia, así que
     nunca da app open);
   - como máximo 1 cada 20 min;
   - con el interruptor prendido y el anuncio cargado.
5. Los otros cuatro cortes dan intersticial o pausa:
   - después de la gracia de arranque;
   - en el turno de la alternancia persistida.
   - Si al que le toca le falta inventario o está apagado, sale el otro **y
     el turno no avanza**.

Los valores salen de la config remota (`NaturalBreakPolicy(config:)`), con
`.default` igual al `ads.json` embarcado. El cableado, paso a paso, está en el
docstring de `ForcedAdsPacer`.

### 5. La mediación (investigada, no agregada)

Ver la sección "Mediación" más abajo.

## Decisiones y su porqué

- **Lo remoto puede espaciar más, nunca menos.**
  - Los pisos de `AdsRemoteConfig.Floor` son las decisiones de PLAN-v2 §2:
    120 s entre forzados, 90 s post-video, y para el app open 180 s afuera,
    1 cada 20 min y desde la sesión 2.
  - Un `0` publicado por error no puede convertir el juego en una
    ametralladora de intersticiales, que es política de AdMob.
  - Para ir más agresivo hace falta un build: eso es a propósito.
- **Los IDs remotos se validan contra el App ID del `Info.plist`.** Un ID de
  otro publisher es plata que va a otra cuenta, y uno mal tipeado deja un
  lugar sin anuncios. Aplicar "la mitad buena" de un archivo roto mezclaría
  dos versiones que nadie probó juntas.
- **La gracia de arranque (180 s) se conserva** para los intersticiales,
  aunque el plan no la nombra: es la protección de la primera sesión de la
  1.x, y es remota. El app open no la mira, porque su momento es la vuelta.
- **El `ads.json` embarcado trae 120 s entre forzados (la decisión de la 2.0)
  y no los 420 s de `rewarded_ads.json`.** El respaldo es lo que rige sin red
  en la 2.0, y tiene que decir lo mismo que lo publicado. Los 420 s siguen
  mandando en el camino de la 1.x, que no se tocó, hasta que E7b cablee la
  política.
- **Una "sesión" es un arranque en frío.** Volver del background no suma.
  "Desde la 2ª sesión" quiere decir que el jugador abrió la app dos veces: en
  el primer día (el que decide si desinstala) no hay app open aunque vaya y
  vuelva.
- **La alternancia no avanza si sale el otro por falta de inventario.** Es un
  orden, no una penalidad: si la pausa no tiene anuncio, sale el común y la
  pausa sigue primera en la fila.
- **Un solo `lastFullScreenAt` y un solo `lastAppOpenAt`.** Un intersticial
  cierra la ventana de 2 min para el app open, pero no le gasta el cupo de
  20 min.
- **El estado de la política va en `UserDefaults`, no en el save.** No es
  progreso: un reset de partida o un save de iCloud no tienen por qué mover el
  reloj de anuncios.
- **`isPresentingFullScreen` en el coordinador.** El proveedor real usa un
  solo observador de presentación para todos los formatos: dos `show…`
  encimados pisarían la continuación del primero, que se quedaría colgado
  para siempre. Con un solo formato forzado no pasaba; con tres que disparan
  desde lugares distintos, sí.
- **Ni la pausa ni el app open se precargan en `prepare()`.** Los pide quien
  los muestra: la pausa antes de su pantalla previa, el app open al irse a
  background. Un anuncio cargado y nunca mostrado gasta red del jugador y
  baja la tasa de presentación (*show rate*) de su unidad en los reportes.
- **Un reloj que fue para atrás más allá de la ventana cuenta como "pasó"**:
  si no, un jugador que corrige la hora del teléfono no vería un forzado en
  días. Un salto chico hacia atrás sigue frenando.

## Mediación

Relevado el 2026-10-06 sobre las páginas de Google
(`developers.google.com/admob/ios/mediation/<red>`), los `Package.swift` de
cada adaptador y la doc de cada red. Lo que no se pudo leer en una fuente
primaria dice **NO VERIFICADO**.

### Resumen

| Red | Paquete SPM (repo de Google) | Producto | Adaptador (tag SPM) | SDK de la red | GMA | iOS mín. |
|---|---|---|---|---|---|---|
| AppLovin | `https://github.com/googleads/googleads-mobile-ios-mediation-applovin.git` | `AppLovinAdapterTarget` | 13.6.4.0 (`13.6.400`) | AppLovinSDK 13.6.4 | ≥ 13.3.0 | 13.0 |
| Unity Ads | `https://github.com/googleads/googleads-mobile-ios-mediation-unity.git` | `UnityAdapterTarget` | 4.21.0.0 (`4.21.000`) | UnityAds 4.21.0 | ≥ 13.0.0 (probado con 13.11.0) | 13.0 |
| Mintegral | `https://github.com/googleads/googleads-mobile-ios-mediation-mintegral.git` | `MintegralAdapterTarget` | 8.1.7.0 (`8.1.700`) | MintegralAdSDK 8.1.7 | ≥ 13.3.0 | 13.0 |
| Meta | `https://github.com/googleads/googleads-mobile-ios-mediation-meta.git` | `MetaAdapterTarget` | 6.22.0.0 (`6.22.000`) | FBAudienceNetwork 6.22.0 | ≥ 13.4.0 | **15.0** |

- Las cuatro declaran GMA `from:` hasta antes de la 14: **son compatibles con
  el 13.11.0 que resuelve el repo**.
- Cada adaptador fija el SDK de su red con `exact:`. **No hay que sumar el
  paquete de la red aparte**, o SPM no resuelve.
- Google documenta "Branch: main" para las cuatro. Los tags existen y
  codifican la versión de 4 partes como semver de 3 (13.6.4.0 → `13.6.400`).
  NO VERIFICADO si SPM acepta como versión un tag con ceros a la izquierda
  (`4.21.000`). Si no, se fija por `revision`.
- AppLovin pide `-ObjC` en Other Linker Flags: hay que verificarlo en el
  target al agregarlo.

### Formatos por bidding

| Formato | AppLovin | Unity | Mintegral | Meta |
|---|---|---|---|---|
| Rewarded | Sí | Sí | Sí | Sí |
| Intersticial | Sí | Sí | Sí | Sí |
| **Pausa publicitaria** (rewarded interstitial) | No | No | No | Sí |
| **App open** | No | No | Sí | NO VERIFICADO |

- **AppLovin app open**: la tabla de Google todavía lo muestra (waterfall en
  beta cerrada), pero el adaptador 13.6.4.0 ya no lo trae (commit `0769a0e`,
  "Remove App Open format support", 22-jun-2026). Nunca fue por bidding.
- **Meta app open**: el código lo implementa desde el 27-oct-2025 (por
  dentro usa el intersticial), pero no figura en la tabla ni en el CHANGELOG.
- Consecuencia (la regla del plan): **la pausa publicitaria queda en AdMob +
  Meta y el app open en AdMob + Mintegral.** Rewarded e intersticial
  compiten con las cuatro.

### SKAdNetwork

| Red | Lista oficial | IDs hoy |
|---|---|---|
| AppLovin | `https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json` | 152 |
| Unity | `https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json` | 76 |
| Mintegral | `https://dev.mintegral.com/skadnetworkids.json` | 105 únicos (106 entradas) |
| Meta | `v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork` | 2 |

- Los 50 de Google que ya trae `Info.plist` están todos dentro de la lista de
  AppLovin, e incluyen el ID propio de cada una de las otras tres redes.
- **La unión de las cuatro más Google es de 156 IDs únicos**: los 152 de
  AppLovin más 4 que sólo trae Unity.
- Las listas cambian: se bajan de nuevo el día que se agreguen.

### Privacy manifests y datos

- **AppLovin**: trae manifest desde el SDK 12.4.1. Su contenido es NO
  VERIFICADO (SDK binario, no publicado en la doc).
- **Unity**: manifest desde 4.10.0, contenido NO VERIFICADO. Su etiqueta de
  privacidad declara Device ID **vinculado y usado para tracking**, además
  de ubicación aproximada, User ID, historial de compras, datos de
  publicidad, de uso y de rendimiento.
- **Mintegral**: manifest desde 7.5.4, contenido NO VERIFICADO. Su tabla de
  cumplimiento declara IDFA, IDFV, IP y user-agent **usados para tracking**;
  país, locale, clics, diagnósticos e info de la app, no.
- **Meta**: manifest desde 6.15.0, "con el dominio de tracking
  pre-cargado". Por regla de Apple eso implica `NSPrivacyTracking = true`:
  es una inferencia, NO VERIFICADA.
- Cómo cerrarlo el día que se agreguen: resolver los paquetes y correr
  `plutil -p` sobre cada `PrivacyInfo.xcprivacy` de
  `SourcePackages/artifacts`, o "Generate Privacy Report" sobre un archive.
- **Hoy el `PrivacyInfo.xcprivacy` de la app declara `NSPrivacyTracking =
  false`.** Con estas redes, App Privacy en App Store Connect va a tener que
  declarar tracking; lo tiene E10.

### Configuración por red

- **AppLovin**: no lleva `AppLovinSdkKey` en `Info.plist`; la key va en el
  mapeo de AdMob. Opcional: `ALPrivacySettings.setDoNotSell`. Se apaga sola
  con child-directed.
- **Unity**: nada en código. Opcional: `UADSMetaData` para el consentimiento
  de EE. UU.
- **Mintegral**: nada obligatorio.
- **Meta**: `FBAdSettings.setAdvertiserTrackingEnabled` sólo pesa en iOS
  15–16; desde iOS 17 usa ATT. Con iOS mínimo 18 (decisión de la 2.0) **no
  hace falta**. Para probar, la app de Facebook instalada y logueada.
- **Las cuatro piden sus líneas en `app-ads.txt`**, que es el repo
  `adergames-site`, `public/app-ads.txt`. Las líneas las da cada panel.

## Verificación

`Tools/v2/oraculo.sh rapido` sobre el árbol final del worktree (corrida
`20261006-214045-rapido`, con el oráculo arreglado que compila el proyecto del
worktree y no el del cwd):

| Paso | Resultado |
|---|---|
| EconomyKit | **267/267** |
| xcodegen + build-for-testing (iOS 26.5) | OK, sin warnings nuevos |
| Unit (iOS 26.5, sin las dos suites de Store) | **545 verdes, 1 rojo, 0 salteados**. El rojo es el declarado, `PacingTests.theOwnersTargetsAreMet` |
| Veredicto | **VERDE** |

Los tests nuevos son 72 en cinco suites:

| Suite | Tests (casos) | Qué cubren |
|---|---|---|
| `AdUnitIDsTests` | 6 (9) | fallback a Regalos, unidad propia, JSON viejo, JSON embarcado, IDs de prueba |
| `AdFormatsTests` | 9 (11) | las vidas de 55 min y 3 h 30, remove_ads sobre los tres forzados, el premio de la pausa, nunca dos anuncios encimados, el reloj de la 1.x |
| `AdsRemoteConfigTests` | 22 (28) | ver abajo |
| `NaturalBreakPolicyTests` | 28 (66) | cada regla en cada corte, asertando el motivo exacto del `skip` |
| `ForcedAdsPacerTests` | 7 | sesiones, ausencia, persistencia, estado roto |

`AdsRemoteConfigTests` cubre:

- los cinco fixtures del encargo: válido, ID ajeno, HTTP, JSON roto y red
  caída con respaldo;
- la caché: buena, mala después de una buena, y vieja;
- lo que se descarta: redirección a http, un estado distinto de 200, más de
  64 KB, pisos, alternancia, tiendas, esquema y publisher;
- la privacidad del pedido, y que el arranque no toca la red;
- el respaldo sincronizado con `feature_flags.json`.

`StorePacksTests` (remove_ads a mitad de sesión) sigue verde.

## Trampas nuevas

- **El proveedor real tiene un solo observador de presentación para todos los
  formatos.** Dos `show…` en vuelo pisan la continuación del primero y ese
  `await` no vuelve nunca. No se ve en ningún test con el stub (que sólo
  devuelve `false`): lo frena `AdsCoordinator.isPresentingFullScreen`, y
  cualquier camino nuevo que presente un anuncio tiene que pasar por el
  coordinador.
- **La tabla de formatos de la página de mediación de Google está vencida
  para AppLovin** (sigue mostrando app open) y los resúmenes automáticos de
  esas páginas contradicen el HTML. Para decidir qué red sirve qué formato,
  leer el HTML de la página y el repo del adaptador.
- **Un `Codable` con `var x = 0` NO decodifica un JSON sin esa clave**: lo
  sintetizado usa `decode`, no `decodeIfPresent`. `AdsPacingState` tiene su
  `init(from:)` para que un estado guardado por una versión anterior no
  resetee la alternancia de todos.
- **Un `xcodebuild` sin `-project` compila el proyecto del cwd, no el del
  script.** La primera versión del oráculo, corrida por ruta absoluta desde
  otro worktree, probaba el código del otro. Ya está arreglado en `Tools/v2`
  (`cd "$REPO"`). Para saber qué se compiló, hay que mirar las rutas de
  `build-for-testing.log`, no el verde.
- **En esta sesión el guard de aislamiento bloqueó git, Bash y Edit/Write en
  el worktree asignado**, porque la sesión estaba atada a otro (v2-e0). Se
  trabajó editando un espejo en el scratchpad, copiándolo al worktree desde
  el cwd de v2-e0 y compilando por rutas absolutas. Los commits los hace el
  orquestador.

## Qué queda

- **E7b cablea la política** (ver el docstring de `ForcedAdsPacer`):
  - crear un `ForcedAdsPacer` por proceso con la config de
    `AdsRemoteConfigLoader.current()`, y disparar `refresh()` en segundo plano;
  - pasar los llamadores de `showInterstitialIfAppropriate` a cortes;
  - precargar el app open al irse a background;
  - la pantalla previa de la pausa;
  - decidir si rechazar la pausa cuenta para el reloj.
  - Con eso se borran `armIfDue`, `cadence` y la sección `interstitial` de
    `rewarded_ads.json`.
- **Gates del dueño**:
  - crear en AdMob la unidad de **app open** (y las cuatro de video nuevas);
  - poner sus IDs en `feature_flags.json` y en el `ads.json` publicado, y
    prender el interruptor;
  - publicar `config/ads.json` en `adergames-site` con el mismo contenido que
    el embarcado;
  - confirmar en la consola que la unidad "unidad" es
    `ca-app-pub-8575641544774372/1615619906`: en el repo sólo figuraba como
    `…/1615619906`, y el publisher se infirió del App ID.
- **Mediación**, cuando estén las cuentas:
  - los cuatro paquetes en `project.yml` con la versión de la tabla;
  - los 156 SKAdNetwork IDs;
  - `-ObjC`;
  - el Ad Inspector en el panel de debug;
  - `app-ads.txt`;
  - el privacy manifest verificado sobre los binarios;
  - App Privacy y la política del sitio.
- **El contador de sesiones arranca en cero el día que se cablee**: los
  veteranos de la 1.x van a contar su primer arranque de la 2.0 como sesión 1
  y no ven app open hasta la segunda. Es prudente; si se quiere otra cosa, E7b
  puede sembrarlo desde el save.

## Para el HANDOFF general

### §4 (entrada de sesión)

> ### Sesión del 2026-10-06 — E7a: la infraestructura de anuncios de la 2.0
>
> Primera mitad de E7, sin UI y sin tocar llamadores. Entraron:
>
> - el **intersticial bonificado** (pausa publicitaria) y el **app open** en
>   el proveedor, con vida de inventario por formato (55 min / 3 h 30);
> - las **unidades por momento** de la 2.0 (`wheel`, `treasure`, `visitor`,
>   `daily`, con fallback a Regalos), la pausa con la unidad existente
>   `…/1615619906`, y el app open en `null` (gate del dueño);
> - **`AdsRemoteConfig`**: `config/ads.json` en `adergames-site`, sólo HTTPS,
>   IDs validados contra el publisher propio, todo o nada, pisos con las
>   decisiones del dueño, caché + respaldo `Resources/Config/ads.json`;
> - la **política de cortes naturales** (`NaturalBreakPolicy`, pura) y su
>   estado (`ForcedAdsPacer`), testeadas y **sin cablear**: la 1.x sigue con
>   `armIfDue`;
> - `remove_ads` corta los tres forzados, y `AdsCoordinator` ya no deja
>   encimar dos anuncios.
>
> La mediación quedó investigada: la pausa sólo la sirve Meta, y el app open
> sólo Mintegral. Detalle en **`Docs/SESION-2026-10-06-v2-e7a-anuncios.md`**.

### §5 (decisiones)

> - **Config remota de anuncios: más prudente sí, más agresiva no** (E7a). Los
>   pisos de `AdsRemoteConfig.Floor` son las decisiones de PLAN-v2 §2. Un
>   archivo remoto con un ID de otro publisher, un número bajo el piso o
>   cualquier campo inválido se descarta entero.
> - **Una sesión de anuncios es un arranque en frío** (E7a): "app open desde la
>   2ª sesión" = el jugador abrió la app dos veces.
> - **La alternancia común/pausa no avanza cuando sale el otro por falta de
>   inventario** (E7a).
> - **La gracia de arranque de 180 s se conserva** para los intersticiales en
>   la 2.0, y es remota (E7a).

### §7 (trampas)

> ### De la infraestructura de anuncios (2026-10-06, E7a)
>
> **El proveedor de AdMob tiene un solo observador de presentación para todos
> los formatos.** Dos `show…` encimados pisan la continuación del primero, y
> su `await` no vuelve nunca. Todo anuncio pasa por `AdsCoordinator`, que lo
> impide con `isPresentingFullScreen`.
>
> **La página de mediación de Google está vencida para AppLovin**: sigue
> mostrando app open, que el adaptador sacó en junio de 2026. Lo que manda es
> el repo del adaptador.
>
> **Un `Codable` con `var x = 0` no decodifica un JSON sin esa clave.** Lo que
> se persiste y puede crecer lleva `init(from:)` con `decodeIfPresent`.

### §9 (mapa de documentos)

> - **`Docs/SESION-2026-10-06-v2-e7a-anuncios.md`** — E7a: los formatos nuevos,
>   las unidades por momento, la config remota y sus pisos, la política de
>   cortes naturales y cómo se cablea, y la investigación de mediación
>   (paquetes, formatos por red, SKAdNetwork y privacy manifests).
