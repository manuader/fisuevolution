# HANDOFF — de la v1.0.0 (build 4) a la v2

Punto de partida para que un agente trabaje la **versión 2** de
HoboEvolution / FisuEvolution sobre el mismo código que está publicado en la
App Store. Leer completo antes de tocar nada.

> **Actualizado en E10 T7 (2026-10-11, relevo 31).** El documento nació como el
> puente de la v1 a la v2; ahora también dice lo que la 2.0 **es**: ver la
> sección 2.1 (iPad, iOS 18 y los 37 tiers). Lo que depende de una épica que
> todavía no entró a `version-2` lleva la marca **«pendiente de cierre»** y se
> junta en la sección 9; cuando cierre cada una, esa fila se borra. El árbol
> contado acá es el de `version-2` (`e1e39c1`, `rapido4` VERDE: EK 845 · unit
> 1448 · Release 0) más lo que el relevo 31 integra en `v2i/integ-r31`.

---

## 0. Dónde se trabaja la v2: la rama `version-2`

**La v2 se desarrolla en la rama `version-2`** (creada el 2026-10-06 desde la
punta de `appstore-submission-check`). Cuando esté lista se mergea a `main` y de
ahí sale el build a la App Store. Ya trae:

- **Todo lo que había fuera del build**: `origin/main` (`59c0d61`), el arreglo
  del congelón de 466 ms al abrir el cofre (`97cb618`, que estaba sólo en un
  `main` local sin pushear) y las dos features del 2026-08-28 que nunca se
  habían mergeado: **cofres sólo de personajes desbloqueados** y **el atajo del
  HUD que vende el mejor tier** (revierte la decisión 9; ver HANDOFF §5).
  Como `version-2` contiene a `main`, el merge final es un fast-forward.
- `MARKETING_VERSION 2.0.0` · `CURRENT_PROJECT_VERSION 5`.
- La limpieza de lo obsoleto, y dos bugs arreglados. El detalle y los números
  están en `Docs/SESION-2026-10-06-preparacion-v2.md`.

```bash
git clone https://github.com/manuader/fisuevolution.git
cd fisuevolution
git checkout version-2
/opt/homebrew/bin/xcodegen generate   # el .xcodeproj NO se versiona
```

**Descartada a propósito** (decisión del dueño, 2026-10-06): la rama
`feat/reacciones-de-campo` (las 352 reacciones a eventos). Sigue en GitHub sin
tocar.

**El plan de la 2.0 está aprobado: `Docs/PLAN-v2.md`** (2026-10-06, noche).
Se ejecuta con relevo automático de agentes (§0 del plan); el tablero vivo es
`tasks.md`. Varios datos de abajo cambiaron cuando cerró su épica:

- **Desde E3a T5** (`3956fd3`, 2026-10-07) `version-2` es universal, con el iPad
  sólo vertical y de pantalla completa, e iOS 18 de mínimo (sección 2.1).
- **Los packs de ORO** ya valen 160 / 550 / 1.400 (`products.json`, E6a), y hay
  **14 productos**, no 11: se sumaron las tres ofertas de 24 h
  (`offer_bienvenida`, `offer_renacer`, `offer_mudanza`).
- **Hay un backend**, opcional: el ranking de la llegada a Dios (E12, sección 5).
- **La mediación es Google + Unity Ads + Meta Audience Network**. AppLovin y
  Mintegral quedaron afuera por decisión del dueño (2026-10-08).

---

## 1. El commit exacto del build publicado

| Dato | Valor |
|---|---|
| **Commit del build 4** | **`adb1e26`** — `chore(release): build 4` (2026-09-23 15:20 -03) |
| Tag | **`v1.0.0-build4`**, apunta a `adb1e26` |
| Rama | **`appstore-submission-check`** |
| Repo | `https://github.com/manuader/fisuevolution` |
| Versión / build | `MARKETING_VERSION 1.0.0` · `CURRENT_PROJECT_VERSION 4` (en `project.yml`) |
| Archive | creado 2026-09-23 15:19:54 -03 desde ese árbol. El único cambio sin commitear en ese momento era el `"3"`→`"4"` de `project.yml`, que es exactamente lo que agrega `adb1e26`. |

**Después de `adb1e26` sólo hay documentación** (`Docs/monetizacion-anuncios.md`
y este archivo), así que la punta de la rama tiene el mismo código que el build.

### ⚠️ Cuál copia es la buena

- **La buena es la rama `appstore-submission-check`.** Se trabajó en un
  worktree de Conductor: `~/conductor/workspaces/fisuevolution/brussels`.
- **`main` en GitHub (`59c0d61`) está desactualizada y NO es el build.** Se
  separó en `805dc06`. La rama del build tiene 26 commits que `main` no tiene:
  AdMob, privacidad, sólo iPhone, tienda y legal.
- `main` tiene un único commit propio (`59c0d61`, el Influencer sin marcas),
  que la rama del build reimplementó por su cuenta (`cb2bd6b`). Tampoco
  hace falta nada de `main`.
- El build se hizo en **otra máquina**. En la del dueño, `~/Desktop/projects/fisuevolution`
  es el mismo checkout que `~/Desktop/projects/FisuEvolution` (el disco no
  distingue mayúsculas). Ese checkout no tiene el worktree de Conductor ni
  las capturas. Las capturas de la ficha no van a git: las regenera
  `AppStoreScreenshotTests`.

---

## 2. Qué es el juego

Merge/idle de humor argentino para iPhone. Tocás al personaje para ganar plata,
contratás más y los fusionás para subir de tier: **37 tiers** (44 personajes,
porque la cadena se abre en el tier 11 —el nodo de elección— y en el 12, que
tiene cuatro carreras) en una torre de **10 pisos**, de un linyera a un dios
del universo. Tiene reencarnación (prestige), cofres de skins, boosts, eventos
y jefes/carreras. Es una sátira de la precariedad económica. La 2.0 le suma
visitantes y eventos nuevos, la Ruleta, el Colchón, la Aduana, una tienda de
ORO con ofertas, un tutorial nuevo y un ranking de la llegada a Dios.

| Dato | Valor |
|---|---|
| Nombre en la tienda | **HoboEvolution** (en español, FisuEvolution) |
| Bundle ID | `com.manuader.fisuevolution` |
| App Store ID | `6814521946` |
| Team ID | `2TS7P7VDQJ` (Apple Developer Program, **Individual**) |
| Dispositivos | v1: **sólo iPhone** (`TARGETED_DEVICE_FAMILY: "1"`), sólo vertical · 2.0: iPhone y iPad (`"1,2"`), sólo vertical |
| iOS mínimo | v1: 17.0 · 2.0: 18.0 |
| Idiomas | español (base) e inglés |
| Rating | 12+ |
| Stack | Swift 6 (strict concurrency), SwiftUI + SpriteKit, XcodeGen. El juego es local; el único servidor propio es el del ranking (Supabase, opcional) |
| Dependencias externas | Google Mobile Ads SDK por SPM (trae UMP). Los adaptadores de Unity Ads y Meta (SPM) **no están todavía**: los trae E7b-a T6, que es del dueño (**pendiente de cierre**) |

### 2.1 Lo que la 2.0 es: iPad, iOS 18 y los 37 tiers

Las tres cosas que `PLAN-v2.md` (E10) pide dejar escritas. Cada dato está
verificado contra el árbol; el archivo que lo prueba va al lado.

**iPad (universal, sólo vertical).** La v1 era sólo iPhone y el iPad la corría
en compatibilidad (barras negras, tablero estirado). La 2.0 es universal:

| Pieza | Valor | Dónde |
|---|---|---|
| Familia de dispositivos | `TARGETED_DEVICE_FAMILY "1,2"`, en `settings.base` **y** en el target | `project.yml:42,149` |
| Orientación | iPhone y iPad sólo `Portrait` (el iPad sin «upside down») | `project.yml:137,150` |
| Pantalla completa | `INFOPLIST_KEY_UIRequiresFullScreen: YES`: es lo que permite un iPad vertical | `project.yml:151` |
| Contrato | `UIDeviceFamily == [1,2]`, `UIRequiresFullScreen == true` y Portrait | `InfoPlistContractTests` |
| Layout | `PlayLayout` (celda `min((W−32)/cols, 112)`, `textScale` 1,25 en iPad), `PlayColumn` de 592 pt máx. y `ScreenInsets`; en iPhone (W ≤ 440) es idéntico al de la v1 | `Scenes/PlayLayout.swift` |
| Prueba | `IPadLayoutUITests` (marcador `board.layout`), sólo corre en iPad: el paso `ipad-ui` del oráculo lo hace en un iPad Pro 13" | `FisuEvolutionUITests/` |

- **Dispositivos que se comparan** (PLAN-v2 §8): iPhone SE, 16 Pro y 16 Pro Max;
  iPad mini, Air 11" y Pro 13". El oráculo corre en automático el SE
  (`LocalizationLayoutUITests`, `iPhone SE (3rd generation)`) y el iPad Pro 13"
  (`IPadLayoutUITests`, `iPad Pro 13-inch (M4)`). El resto son 🔒 del dueño
  (escenarios a mano en SE y iPad 13", claro y oscuro, con y sin Reduce Motion).
- **Slots de capturas de la ficha**: iPhone 6,9" (17 Pro Max, 1320 × 2868),
  iPhone 6,3" (17 Pro, 1206 × 2622) e iPad 13" (iPad Pro 13-inch, 2064 × 2752),
  en inglés y en castellano. El arnés es `AppStoreScreenshotTests`
  (`--screenshot-mode`); hoy navega con las hojas de la v1 y E10 T6 lo pasa al
  menú de la 2.0 (**pendiente de cierre**).
- ⚠️ **`UIRequiresFullScreen` está deprecada** y se ignora al compilar con el SDK
  de iOS 27. `InfoPlistContractTests` tiene un test que se pone rojo a propósito
  en ese momento (`major < 27`): al pasar de SDK, el iPad sólo vertical hay que
  repensarlo (ventanas de 500 × 800 y 700 × 1000; `PlayLayoutTests` ya las cubre).
- Vale lo de la v1: si el build sale con la familia mal, Apple lo rechaza (90474).
  Se mira en el `.app` del archive, no en el fuente (sección 6).
- Falta el iPad real: la prueba en dispositivo es 🔒 del dueño, en TestFlight.

**iOS 18 de mínimo.** `IPHONEOS_DEPLOYMENT_TARGET: "18.0"` (`project.yml:41`),
y `deploymentTarget` de XcodeGen. La v1 era iOS 17. Lo que habilita: el tamaño
de las hojas en iPad (`presentationSizing`) y el historial de consumibles para
reconstruir el ORO comprado en la v1. Se retiró el camino iOS 17 de
`clearNavigationBackdrop`.

- **Matriz de dos runtimes**: **iOS 26.5** (casi todo) e **iOS 18.6** (las tres
  suites de tienda, porque StoreKit Testing está roto en el 26: trampa 30 de
  HANDOFF). Es el piso: lo que anda en 18.6 anda en todo lo que soportamos.
- El oráculo (`Tools/v2/oraculo.sh`) crea sus simuladores por UDID y los borra:
  `tarea` (EK + build + clases), `rapido` (EK + build + unit + Release 0 avisos)
  y `completo` (rapido + store-unit y store-ui en 18.6, la UI entera en 26.5,
  iPad, SE, pipeline y pacing-sim).
- El archive se firma con el SDK de Xcode 26.6; el mínimo no cambia eso.

**37 tiers.** Contados en `FisuEvolution/Resources/Data/tiers.json`: tiers 1 a
37, **44 tipos** (el tier 11 tiene 5, por ser el nodo de elección —`isChoiceNode`—
y el 12 tiene 4, las carreras; el resto, uno). El archivo lo **genera**
`Tools/generate-tiers`: no se edita a mano. `FisuEvolution-plan.md` dice
«30 tiers»: es de julio y la verdad es el JSON. Los 37 tiers recorren los **10
pisos** de `economy.json` (`alley`, `urban`, …). En este documento la única
mención de «30 tiers» es la que cita ese plan, en la sección 3.

---

## 3. Documentación del repo — qué leer y en qué orden

1. **`Docs/HANDOFF.md`** (~2950 líneas): **el documento principal**.
   §2 *Reglas del repo* (romperlas rompe el build), §3 *Arquitectura*,
   §5 *Decisiones del dueño que NO se re-litigan*, §6 *Cómo verificar*.
   Tiene la lista de "trampas" numeradas: leerla antes de tocar build, tests o
   StoreKit.
2. **`Docs/SESION-2026-10-06-preparacion-v2.md`**: cómo quedó `version-2` y qué
   quedó anotado para el plan.
3. **`FisuEvolution-plan.md`**: la biblia del diseño. Tono y cultura argentina,
   modelo de datos, economía, prestige, viralidad. Sus números son de julio
   (dice 30 tiers): la verdad de hoy está en los JSON.
4. **`Docs/ads-integration.md`** y **`Docs/monetizacion-anuncios.md`**: cómo
   están integrados los anuncios, y el plan para ganar más (mediación,
   intersticial bonificado, app open).
5. **`Docs/balance-log.md`** + `Docs/balance-run-*.csv`: historia y números
   del balance de la economía.
6. **`Docs/PLAN-v2.md`** y **`tasks.md`**: el plan aprobado de la 2.0 (E1–E13)
   y el tablero vivo de la implementación (estado por tarea, 🔒 del dueño,
   decisiones B1–B26). Si un ledger de `.superpowers/sdd/` dice otra cosa que
   `tasks.md`, manda el ledger.
6b. **`Docs/SESION-*.md`**: bitácora por sesión. Sirve para entender por qué
   algo es como es.
7. **`Tools/asset-pipeline/README.md`**: cómo se integra arte nuevo. La
   generación vive en `~/Desktop/projects/automatic-image-generation`;
   `Docs/HANDOFF-arte-gemini.md` queda por sus bugs y lecciones.
8. **`IOS-developing-skill.md`**: convenciones de desarrollo iOS del proyecto.

### Distribución y App Store (`Distribution/`)

| Archivo | Para qué |
|---|---|
| `store-metadata.md` | Textos de la ficha de la App Store |
| `checklist-submission.md` | Checklist de la entrega v1 como Individual |
| `iap-appstore-connect.md` | Los 11 productos tal como se cargaron en App Store Connect |
| `app-review-reply.md` / `.txt` | Respuesta al pedido de información de la guideline 2.1 |
| `ExportOptions.plist` | Export por CLI. ⚠️ `destination: upload`: **sube directo** a App Store Connect. Ningún agente lo corre: es 🔒 del dueño |
| `setup-v2-asc-admob-mediacion.md` | El doc de configuración de la 2.0: ASC, IAP, AdMob y las redes, paso a paso |
| `release/release.json` | Fuente de verdad versionada de lo comercial (compras, ficha, notas a App Review, AdMob); la valida y aplica `Tools/releaseops` |
| `release/app-review-notes-e12.md`, `release/AUDITORIA-*.md` | Notas a App Review del ranking; la auditoría de compras y unidades |
| `site/privacy.md` | La política de privacidad (copia en `Resources/Legal/privacy.md`) |

---

## 4. Mapa del código

```
FisuEvolution/
  App/            arranque de la app, raíz SwiftUI
  Game/           lógica del juego (State/, Effects/)
  Scenes/         escenas SpriteKit (tablero, fusiones)
  UI/             SwiftUI: HUD, Store, Skins, Gifts, Jobs, Menu, Popups,
                  Tutorial, Share, Art
  Managers/
    Ads/          AdsProvider (protocolo), AdMobAdsProvider, AdsCoordinator
                  (cadencia), AdsConsent (UMP / GDPR)
    Store/        StoreManager (StoreKit 2), ProductCatalog, SkinResolver
    FeatureFlags.swift   flags + IDs de anuncios + RewardedPlacement
  Persistence/    guardado local
  Audio/, Utilities/ (Log.swift: un Logger por subsistema; print() prohibido)
  Resources/
    Config/       TODO el contenido y la economía son datos JSON (ver abajo)
    Assets.xcassets, *.atlas (sprites), PrivacyInfo.xcprivacy, Localizable
Packages/EconomyKit/   la economía pura, con sus propios tests (swift test)
FisuEvolutionTests/    unit tests
FisuEvolutionUITests/  UI tests
StoreKitConfig/FisuEvolution.storekit   catálogo local de los 11 IAP
Tools/asset-pipeline/  integración de arte (Python); ver su README
Tools/pacing-sim/      el simulador de economía (el instrumento del balance)
Tools/generate-tiers/  genera Resources/Data/tiers.json
Tools/audio-synth/     sintetiza los .caf del juego
project.yml            FUENTE DE VERDAD del proyecto Xcode (XcodeGen)
```

### Contenido por datos (`FisuEvolution/Resources/Data/` y `Config/`)

El código nunca hardcodea contenido: todo sale de estos JSON.

| Archivo | Qué define |
|---|---|
| `Data/tiers.json` | Los 37 tiers y 44 tipos. **Generado** por `Tools/generate-tiers`: no se edita a mano |
| `Data/economy.json` | Curvas, los 10 pisos, precios de contratación y ORO |
| `Data/assets_manifest.json` | El único puente entre código y arte |
| `careers.json` | Las 4 carreras y la recompensa de cada una |
| `upgrades.json` | Mejoras, incluidas las que se pagan con ORO |
| `boosts.json` | Boosts temporales |
| `chests.json`, `skins.json`, `specials.json` | Cofres, skins y personajes especiales |
| `events.json`, `daily_rewards.json`, `achievements.json` | Eventos, recompensas diarias y logros |
| `prestige_unlocks.json` | El descuento de contratación por nivel de reencarnación |
| `products.json` | Los **14** IAP (ID, tipo y qué entregan; los 3 nuevos son las ofertas de 24 h) |
| `rewarded_ads.json` | Premios de Regalos, el corte publicitario (`adBreak`), la columna lateral (`sideRail`) y la compensación |
| `feature_flags.json`, `ads.json` | Flags y **IDs de unidades de AdMob** (11); `ads.json` es el respaldo del bundle de la config remota |
| `gamecenter.json`, `viral.json` | Game Center (apagado) y la parte viral |
| `oro_shop.json`, `offers.json` | La tienda de ORO (13 ítems) y las ofertas de 24 h |
| `wheel.json`, `treasures.json`, `packages.json`, `visitors.json` | La Ruleta, el Colchón, los paquetes de la Aduana y los visitantes |
| `tabs.json`, `notifications.json`, `ranking.json` | Las pestañas y cuándo aparecen, las notificaciones y la config del ranking (`baseURL`/`anonKey` en `null` hasta el despliegue real) |
| `Data/loops_manifest.json` | Los videos en loop (E8e) |

---

## 5. Integraciones que están en producción

### Compras dentro de la app (StoreKit 2)

- **14 productos**: 9 consumibles (plata S/M/L, ORO S/M/L de **160 / 550 / 1.400**,
  y las ofertas `offer_bienvenida` US$0,99, `offer_renacer` US$2,99 y
  `offer_mudanza` US$4,99, de 24 h) y 5 no consumibles (remove_ads,
  starter_pack, skin_mundialista, skin_parrillero, skins_diamante).
  IDs `com.fisuevolution.iap.*`. Los 11 originales están en
  `Distribution/iap-appstore-connect.md`; las tres ofertas, en `release.json`.
  Las ofertas y los 11 se cargan en App Store Connect con `releaseops`
  (siempre en modo verificación; aplicar es 🔒 del dueño).
- Para cambiar un producto hay que tocar **cuatro** cosas que tienen que coincidir:
  `products.json`, `StoreKitConfig/FisuEvolution.storekit`, `release.json` y
  App Store Connect. Desde la 2.0 la app muestra los nombres de su propio
  catálogo (`IAPCopy`), así que App Store Connect ya no los dicta.
  StoreKit **omite en silencio** los IDs que no resuelve: un typo no da error,
  el producto desaparece.
- El nombre, la descripción y el precio que ve el jugador vienen de StoreKit,
  o sea de App Store Connect, no del juego.
- `StoreManager` loguea `catálogo completo: N productos` o
  `catálogo incompleto: N de 14; StoreKit no resolvió …`. Es el primer lugar
  donde mirar si la tienda aparece vacía.

### Anuncios (AdMob)

- App ID AdMob: `ca-app-pub-8575641544774372~3243441080`, en
  `Info.plist` → `GADApplicationIdentifier`.
- Unidades, en `feature_flags.json` → `adUnitIDs` (11; todas con el prefijo
  `ca-app-pub-8575641544774372/`):

| Clave | ID | Formato | Lugar |
|---|---|---|---|
| `rewardedGifts` | `…/8304196070` | Bonificado | Los premios de Regalos |
| `rewardedOfflineX2` | `…/6825744243` | Bonificado | Duplicar ganancias offline |
| `rewardedChestExtra` | `…/3981807683` | Bonificado | Abrir otro cofre |
| `rewardedBoost` | `…/4913896772` | Bonificado | Boost sin esperar |
| `rewardedWheel` | `…/1366235671` | Bonificado | Ruleta (girar y repetir premio) |
| `rewardedTreasure` | `…/1912941292` | Bonificado | Colchón (abrir y «otro colchón») |
| `rewardedVisitor` | `…/8454388206` | Bonificado | Visitantes |
| `rewardedDaily` | `…/1697408166` | Bonificado | Diario y carrera ×2 |
| `interstitial` | `…/5270838626` | Intersticial | Cortes naturales |
| `rewardedInterstitial` | `…/1615619906` | Intersticial bonificado | La pausa publicitaria («ad break») |
| `appOpen` | `…/3573507326` | App open | Al volver a la app |

- **La config remota** (E7b-a T1): los IDs se pueden cambiar sin pasar por la
  revisión de Apple desde `public/config/ads.json` en `adergames-site`; rigen
  desde el próximo arranque, **sólo en producción y Release** (DEBUG usa siempre
  los IDs de prueba de Google). Si la config cae, se usa el respaldo del bundle
  (`Config/ads.json`).
- **Los anuncios que aparecen solos** (E7b-a): sólo en cortes naturales —cerrar
  una pantalla del menú, cerrar el popup de ganancias offline, reencarnar, el
  final de una cadena de celebraciones—, nunca en el tutorial ni sobre una
  pantalla abierta, con al menos 2 minutos entre uno y otro y 90 s de gracia
  después de un bonificado (son pisos de `AdsRemoteConfig.Floor`: la config
  remota puede subirlos, no bajarlos). El intersticial
  alterna con el bonificado (la pausa lleva una intro con cuenta de 5 s y
  «No, gracias»); el app open sólo vuelve tras 3+ minutos afuera, a lo sumo uno
  cada 20 minutos y desde la segunda sesión. «Quitar anuncios» y el Starter Pack
  sacan esos tres formatos; los bonificados quedan, porque el jugador los pide.
- **La columna lateral** de ubicaciones (E7b-b): Fusionar todo y la lluvia de
  paquetes por video. **Pendiente de cierre** (sección 9).
- **Mediación**: Google + **Unity Ads** + **Meta Audience Network** (AppLovin y
  Mintegral, afuera). Unity y Meta no pujan en el app open. Los adaptadores por
  SPM, los SKAdNetwork de Unity y el Ad Inspector los trae E7b-a T6, que es del
  dueño: **pendiente de cierre**.
- En DEBUG se usan los IDs de prueba de Google (`FeatureFlags.swift`).
- Consentimiento: UMP (`AdsConsent.swift`) antes de pedir anuncios, más el
  aviso de ATT (`NSUserTrackingUsageDescription`). `Info.plist` trae 50
  `SKAdNetworkItems`, los de Google; falta la lista ampliada de Unity (+39),
  que llega con la mediación (**pendiente de cierre**, E7b-a T6). «Opciones de
  privacidad» (UMP) está en Ajustes.
- `app-ads.txt` publicado en `https://adergames-site.vercel.app/app-ads.txt`
  (repo `manuader/adergames-site`, archivo `public/app-ads.txt`). La versión con
  Unity y Meta se prepara en una rama local (E10 T4) y **publicarla es 🔒**:
  `git push` a `main` despliega.

### Ranking de la llegada a Dios (E12)

El único servidor propio. Opcional: con `ranking.json` en `enabled: false` (o
sin `baseURL`) la pestaña y la tarjeta no salen.

- Backend en `supabase/` (esquema, RLS, cuatro Edge Functions, cron, lista de
  términos); `supabase/test.sh` corre los casos SQL. El nombre (máx. 15
  caracteres) pasa por reglas (`NameRules`, tabla compartida cliente/servidor),
  una lista y un clasificador automático (**Anthropic, modelo Claude Haiku**,
  que sólo recibe el nombre); con 3 reportes se oculta.
- El cliente guarda una identidad anónima en el Keychain. Entrar con un nombre
  sólo se ofrece al llegar a Dios, que lleva horas: por eso las notas a App
  Review dan un atajo para ver el Ranking (guideline 1.2).
- **Pendiente de cierre**: el despliegue real y el humo (E12 T16, 🔒: URL y
  anon key de Supabase, `ANTHROPIC_API_KEY` y la lista aprobada), el reset que
  abre un intento nuevo (E12 T12) y el piso calibrado (E12 T17, tras E2b).

### Privacidad

`PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, sin
`NSPrivacyTrackingDomains`. Desde la 2.0 declara dos tipos de dato, **sin
vincular y sin rastreo**, para el funcionamiento de la app (el ranking):
identificador del dispositivo (`DeviceID`) y contenido del usuario (el nombre,
`OtherUserContent`). APIs declaradas: UserDefaults (CA92.1) y FileTimestamp
(C617.1).
⚠️ Poner `NSPrivacyTracking = true` sin dominios hace que Apple rechace
el build (ITMS-91064; la v1, dos veces). **B22:** queda en `false` hasta que el
dueño pase los dominios de AdMob, Unity y Meta (E10 T14, 🔒, no frena el cierre).
Los SDKs de terceros traen su propio manifiesto.
La política de privacidad (`Distribution/site/privacy.md` y su copia en
`Resources/Legal/`) ya cuenta el ranking y nombra a Anthropic; falta nombrar a
Unity y Meta (E10 T3, **pendiente de cierre**).

### Lo que está apagado (sólo por flag)

`gameCenterEnabled: false`, `cloudKitEnabled: false` en `feature_flags.json`.
El código existe, pero no hay entitlements cableados: prenderlos pide sumar
las capabilities y declararlo en la App Store.

### Sitio y legal

`https://adergames-site.vercel.app`, repo `manuader/adergames-site` (Next.js,
deploy automático de Vercel al pushear a `main`). Ahí están la política de
privacidad (`content/legal.ts`) y los términos (`content/terms.ts`). La app los
muestra en el menú (`UI/Menu/LegalView.swift`), desde el bundle.
⚠️ `legal.ts` quedó viejo dos veces (redes y ranking): dice «No tenemos
servidores propios». Se corrige en la rama local de E10 T4, y publicar es 🔒.

---

## 6. Cómo compilar, testear y archivar

### Requisitos

- **Xcode 26.6**, macOS, XcodeGen en `/opt/homebrew/bin/xcodegen` (2.46).
- Runtimes de simulador: **iOS 26.5** y **iOS 18.6**. Mínimo de la app: iOS 18.

### Reglas que rompen el build si se ignoran

- **El `.xcodeproj` no se versiona.** Después de agregar o borrar archivos
  Swift, o de tocar `project.yml`: `xcodegen generate`.
- `TARGETED_DEVICE_FAMILY: "1,2"` va **en el target** de la app y también en
  `settings.base`, junto con `UIRequiresFullScreen` y la orientación Portrait
  del iPad. Si el target pierde la familia, el build sale mal para Apple
  (en la v1 fue al revés: salía para iPad y daba el error 90474). Ver 2.1.
- Warnings como errores (`SWIFT_TREAT_WARNINGS_AS_ERRORS`), strict concurrency
  `complete`.
- **Cada subida a App Store Connect necesita un `CURRENT_PROJECT_VERSION`
  nuevo.** El 1–4 ya están quemados: `version-2` está en **2.0.0 (5)**
  (`project.yml:192-193`). Si el 5 se quemó no se sabe desde el repo: E10 T2
  (`releaseops asc builds`, **pendiente de cierre**) lista los builds de ASC.
  Cada subida que falle o se repita quema otro número.
- **Archive siempre desde cero** (borrar DerivedData o usar un
  `-derivedDataPath` nuevo). Un build incremental no recompila los atlas de
  SpriteKit, y ya se subió un sprite viejo así.

### Tests: una matriz de dos runtimes

StoreKit Testing está **roto en el runtime iOS 26**. Las tres suites de tienda
(`StoreManagerTests`, `StoreProductsTests`, `StoreUITests`) corren en un sim
**iOS 18.6**; todo lo demás, en **iOS 26.5**. Unit **antes** que UI. Los
comandos exactos y los conteos esperados están en `Docs/HANDOFF.md` §6.

```bash
cd Packages/EconomyKit && swift test        # economía pura
# luego xcodebuild … -only-testing:FisuEvolutionTests test       (unit)
# luego xcodebuild … -only-testing:FisuEvolutionUITests test     (UI)
```

### Probar la tienda

| Dónde | ¿Anda? | Por qué |
|---|---|---|
| Simulador **iOS 26** (Run de Xcode o `simctl`) | ❌ | Xcode 26.6 descarta la config de StoreKit del esquema (loguea `Remove configuration`), y el simulador no puede hablar con el sandbox real |
| Simulador **iOS 18.6** | ✅ catálogo local | La app levanta el `.storekit` del bundle con `SKTestSession` (sólo DEBUG) |
| iPhone real, TestFlight o App Store | ✅ productos reales | Sandbox/producción contra App Store Connect |

Para leer el log de un iPhone conectado **por cable**:
`sudo log collect --device-udid <UDID de hardware> --last 30m --output x.logarchive`
(el UDID de hardware es `00008…`, no el identificador de CoreDevice).

### Archivar y subir

```bash
# 1) subir CURRENT_PROJECT_VERSION en project.yml
/opt/homebrew/bin/xcodegen generate
rm -rf build-archiveN
xcodebuild -project FisuEvolution.xcodeproj -scheme FisuEvolution -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build-archiveN/DD \
  -archivePath build-archiveN/FisuEvolution.xcarchive archive
open build-archiveN/FisuEvolution.xcarchive    # Organizer ▸ Distribute App ▸ App Store Connect
```

**Un agente archiva pero no exporta.** `ExportOptions.plist` tiene
`destination: upload`: `xcodebuild -exportArchive` con ese archivo sube
directo a App Store Connect. Exportar, firmar y subir es del dueño. El
`.xcarchive` se hace con la firma automática del proyecto (`2TS7P7VDQJ`); si
`xcodebuild archive` pide un certificado, un perfil o el llavero, se para.

Antes de subir, verificar en el `.app` del archive —ahora con un comando,
`python3 Tools/releaseops/releaseops.py app verify <.app|.xcarchive>`, que
también acepta el `.xcarchive` (E10 T1, ✅)—: versión y build,
**`UIDeviceFamily = [1,2]`**, `UIRequiresFullScreen`, `NSPrivacyTracking =
false`, el `GADApplicationIdentifier` y los `SKAdNetworkIdentifier` (los de
Google, y los de Unity y Meta cuando entre la mediación). Después de subir,
TestFlight: 1–2 días de playtest del dueño con pacing real, anuncios reales por
unidad, compras en sandbox y un iPad real.

---

## 7. Historia de la entrega v1 (para no repetir errores)

| Build | Qué pasó | Arreglo |
|---|---|---|
| 1 | ITMS-91064 (manifiesto de privacidad) | — |
| 2 | ITMS-91064 de nuevo: se borraron los dominios, pero se dejó `NSPrivacyTracking = true` | — |
| 3 | Apple lo aceptó. App Review pidió información (guideline 2.1) | `NSPrivacyTracking = false` |
| 4 | **Aprobado y publicado** | Log de diagnóstico de la tienda |

Otros problemas resueltos durante la entrega:

- Error 90474: la app salía también para iPad.
- La nota para el mantenedor se mostraba dentro del texto legal (la cita `>`).
- El sprite del Influencer tenía marcas reales (GUCCI/BALENCIAGA).
- El sitio tenía mails muertos y una política sin anuncios.
- La tienda vacía en TestFlight resultó ser del lado de Apple: el Paid Apps
  Agreement estaba sin activar, y después hubo que esperar a que se propagara.
  La app no tenía nada roto.

En AdMob había **dos apps** duplicadas. Se vinculó la tienda a la que usa el App ID
`~3243441080`, que es la que tiene las unidades y la que usa el build.

---

## 8. Backlog para la v2

En orden sugerido; el estado está a la fecha del relevo 31. El detalle de
anuncios está en `Docs/monetizacion-anuncios.md` y el vivo en `tasks.md`.

1. ✅ **Unificar ramas**: `version-2` contiene a `main` y a la rama del build.
   Al lanzar, `main` avanza a `version-2` por fast-forward (sección 0).
2. **Mediación de anuncios**: ~~AppLovin, Unity, Mintegral y Meta~~ → **Unity y
   Meta** (decisión del dueño, 2026-10-08). Adaptadores por SPM en
   `project.yml`, sus SKAdNetwork IDs en `Info.plist`, sus líneas en
   `app-ads.txt` y la política de privacidad actualizada. ⏳ **Pendiente de
   cierre**: E7b-a T6 (SPM, del dueño) y T7; la política y el sitio, E10 T3–T4.
3. ✅ **Intersticial bonificado**: hecho como **la pausa publicitaria**
   (`rewardedInterstitial`, `…/1615619906`), en cortes naturales, no sólo al
   reencarnar (E7b-a T3).
4. ✅ **App open** al volver a la app, espaciado (E7b-a T4).
5. ✅ **IDs de anuncios remotos** (`public/config/ads.json`, E7b-a T1). Falta
   publicar la versión nueva del sitio (🔒).
6. Game Center y iCloud: el código ya existe detrás de flags (siguen apagados).
7. Recortar en App Store Connect el nombre «Todas las skins de Diamante», que
   se ve truncado en la fila de la tienda.
8. ~~Mover las capturas a git~~: no hace falta. `Distribution/screenshots/` está
   gitignoreado a propósito y `AppStoreScreenshotTests` las regenera en un
   comando (`Tools/v2/capturas.sh`, E10 T6, **pendiente de cierre**).

Lo que la preparación de `version-2` encontró y dejó para el plan (bugs de
producción, funciones a medio cablear y refactors) está en
`Docs/SESION-2026-10-06-preparacion-v2.md`, sección «Para el plan».

Para cada cambio de contenido o economía: editar el JSON, correr los tests de
`EconomyKit` y de la app, y anotar en `Docs/balance-log.md` si cambia el balance.

---

## 9. Pendiente de cierre y 🔒 del dueño

Lo que este documento da por hecho que existirá pero **todavía no está en
`version-2`** (la punta es `e1e39c1`; todo esto vive en ramas de integración o
no se hizo). Cuando una épica cierre, se borra su fila y se corrige la sección
que la nombra.

| Épica / tarea | Qué falta | Dónde nombrada acá |
|---|---|---|
| **E7b-b** (columna lateral) | T1–T2 integradas en `v2i/integ-r31`; faltan T3 (en pantalla), T5, T7 (mapa de ubicaciones) y T8 (cierre) | 5, notas a App Review |
| **E7b-a T6–T7** | Mediación por SPM, SKAdNetwork de Unity, Ad Inspector (🔒 del dueño) | 2, 5, 8 |
| **E9** (tutorial v2, Tour de novedades, Ajustes, reset) | E9a T1–T2 integradas; faltan T3–T10 y todo E9b (el reset de cuenta es E9b T8) | 5 (reset) |
| **E2b** (calibración) | T9 y T12–T15: la calibración declarada y el contrato de pacing prendido; el balance de los números de la sección 2 y `balance-log.md` (E10 T10) | 2, 8 |
| **E12 T12, T16–T18** | Reset que abre un intento; despliegue real y humo (🔒); piso calibrado; cierre | 5 |
| **E8e T10** | El tablero animado: T10a es un spike y el gate lo mide el dueño en su SE; T10b–T10f siguen | — |
| **E10** | T2 (`asc builds`), T3 (privacidad), T4 (sitio), T6 y T9 (capturas), T8 y T13 (auditoría), T11 (notas finales), T12 (archive desde cero) | 5, 6, 8 |

**🔒 del dueño** (ningún agente lo hace): subir a App Store Connect y exportar
(`-exportArchive` sube directo), TestFlight, App Privacy, el cuestionario de
edad, publicar `adergames-site`, la mediación en SPM y los paneles de las redes,
los dominios de B22 (`NSPrivacyTrackingDomains`), el despliegue de Supabase y
enviar a revisión. Los comandos de lectura de `releaseops` (`validate`, `asc
status/plan/diff/ready`, `asc listing plan/diff`, `admob plan`) sí son del
agente. Las notas a App Review están en `release.json → store.reviewNotes`
(borrador de E10 T5: 3.970 de 4.000 caracteres, sin margen).
