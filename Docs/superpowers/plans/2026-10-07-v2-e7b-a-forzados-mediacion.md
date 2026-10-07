# E7b-a — Anuncios v2, los forzados: la config remota en marcha, los cortes naturales, la pausa publicitaria, el app open, UMP y la mediación · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que los tres formatos forzados de la 2.0 corran de verdad y sólo en pausas naturales:
el intersticial común y la pausa publicitaria alternados cada ≥ 2 min, la pausa con su pantalla
previa de 5 s y un "No, gracias" que no castiga, el app open al volver tras ≥ 3 min; que la
config remota de `adergames-site` mande sin build nuevo; que Ajustes tenga "Opciones de
privacidad" (UMP); y que la mediación (AppLovin, Unity Ads, Mintegral y Meta) entre al binario.

**Architecture:** E7a dejó todo sin llamadores: la política pura (`NaturalBreakPolicy`), su
estado (`ForcedAdsPacer`), la config remota (`AdsRemoteConfig` + `AdsRemoteConfigLoader`) y los
formatos nuevos en el proveedor. E7b-a los enchufa:

- la App crea **un pacer por proceso** con la config que haya en disco y la refresca en segundo
  plano (`ForcedAdsSetup`); en Release los IDs del sitio mandan sobre los del bundle;
- `GameState+Ads` es **el único lugar que muestra un forzado**: arma el contexto desde el juego,
  le pregunta al pacer y presenta por `AdsCoordinator`, con la **cola de celebraciones retenida**
  mientras el anuncio está en pantalla (el SDK presenta un modal y una hoja de SwiftUI que
  intentara presentarse encima fallaría sin aviso);
- los tres llamadores del intersticial de la 1.x pasan a ser cortes (`sheetClosed`,
  `offlinePopupDismissed`, `reincarnation`), se suma `celebrationsDrained`, y el reloj de la 1.x
  (`armIfDue`, `cadence`, `sessionResumed`, la sección `interstitial` de `rewarded_ads.json`) se
  borra;
- la pausa publicitaria es un **overlay** con cuenta regresiva (`RewardedInterstitialIntroView`),
  no una hoja, y su premio rota (10 min de producción → ×2 por 5 min → un Paquete);
- el app open se decide al volver **antes** de acreditar el offline, así el popup de ganancias
  aparece después del anuncio y no debajo;
- la fila de UMP va en Ajustes, y la mediación entra como cuatro paquetes de adaptador, la unión
  de SKAdNetwork en el `Info.plist` y el Ad Inspector en el panel de debug.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
Google Mobile Ads 13.x + UMP · SPM vía XcodeGen · EconomyKit · Swift Testing · XCUITest ·
Python 3 (la herramienta de SKAdNetwork).

**Fuente:** `Docs/PLAN-v2.md` §2 (Intersticiales, App open, Sin anuncios, Mediación, Pausa
publicitaria: **no se re-litigan**), §4 "E7 — Anuncios v2", §6 (política de AdMob) y §0.1
(agentes concurrentes); `Docs/SESION-2026-10-06-v2-e7a-anuncios.md` (lo que E7a hizo, su
"Qué queda" y la investigación de mediación). Lo que el árbol contradice o PLAN deja abierto está
en "Para el dueño / dudas", con el default con el que se sigue.

### Por qué E7b va en dos planes

E7b son dos frentes que casi no comparten archivos:

- **E7b-a (este plan) — los forzados y la plomería:** la config remota en marcha, los cortes
  naturales, la pausa publicitaria, el app open, UMP y la mediación. Es lógica de anuncios y la
  pantalla previa; no toca el tablero.
- **E7b-b (`2026-10-07-v2-e7b-b-columna-ubicaciones.md`) — lo que el jugador toca:** la columna
  lateral (con el 🔒 de la multitud), sus dos videos (Fusionar todo y la lluvia de paquetes), el
  diario ×2 y la carrera ×2, el botón de video con precarga y el contrato del mapa de ubicaciones.

E7b-b usa de este plan sólo `TowerNotice.Kind.rewardGranted` (T3) y la regla "todo anuncio pasa
por `AdsCoordinator`".

### Lo de E7 que YA está hecho (no se replanifica)

E7a (`Docs/SESION-2026-10-06-v2-e7a-anuncios.md`, integrado en `version-2`):

- el **protocolo** con pausa publicitaria y app open (`AdsProvider.swift:38-57`) y su
  implementación en AdMob (`AdMobAdsProvider.swift:202-285`) y en el stub;
- la **vida del inventario** por formato (`AdInventoryLifetime`, `AdsProvider.swift:70-78`);
- las **unidades por momento** (`RewardedPlacement`, 8 casos, `FeatureFlags.swift:17-36`), la pausa
  con la unidad `ca-app-pub-8575641544774372/1615619906` y el app open en `null` (gate del dueño);
- **`AdsRemoteConfig`** con su validación de todo o nada y sus pisos, y el loader con caché y
  respaldo `Resources/Config/ads.json`;
- la **política** (`NaturalBreakPolicy`) y su estado persistido (`ForcedAdsPacer`, `AdsPacingStore`,
  `AdsPacingState` en `UserDefaults`);
- **`remove_ads` corta los tres forzados** (`AdsCoordinator.swift:40-50, 144-230`) y el
  coordinador no deja encimar dos anuncios (`isPresentingFullScreen`, `:54-62`);
- **los Términos** ya dicen que "Sin anuncios" saca sólo los forzados
  (`Distribution/site/terms.md:86-88` y `Resources/Legal/terms.md`, sesión E10 docs del
  2026-10-06). El espejo del sitio (`adergames-site`, `content/legal.ts`) es de E10.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build. Nada de `Timer` para lógica de juego (regla 2): los relojes del juego van por el
  tick o el flush de 8 Hz; en vistas, `.task(id:)` con `Task.sleep`.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar un
  archivo Swift, un recurso o un paquete**, en el mismo paso.
- **Todo anuncio pasa por `AdsCoordinator`** (trampa de E7a: el proveedor real tiene un solo
  observador de presentación; dos `show…` encimados dejan un `await` colgado para siempre). Y
  **todo forzado pasa por `GameState+Ads`**: ningún otro archivo llama `showInterstitial()`,
  `showRewardedInterstitial()` ni `showAppOpen()`.
- **Mientras un forzado está en pantalla, la cola de celebraciones está retenida**
  (`holdCelebrationsForAd`), y ningún forzado se presenta antes de `AdsCoordinator.settleDelay`
  (0,6 s) desde el corte: la hoja que se cerró termina de irse y el toque que la cerró no cae en
  el anuncio (política de clics accidentales de AdMob).
- **Lo remoto puede espaciar más, nunca menos** (decisión de E7a): no se tocan los pisos de
  `AdsRemoteConfig.Floor`. Los valores de prueba van en políticas construidas a mano, nunca en
  `ads.json`.
- **Nada de forzados bajo XCTest ni bajo `--uitest*`** salvo que el test lo pida con su flag
  (`--uitest-ad-break`); el pacer de los UI tests guarda en su propia clave de `UserDefaults`.
- **Política de AdMob** (PLAN-v2 §6): la pausa lleva pantalla previa con el premio dicho y
  "No, gracias" visible desde el primer cuadro; el app open sólo al volver; los videos con premio
  son opt-in con el premio dicho antes.
- **Strings nuevos, es + en**, por snapshot: cada tarea escribe sus claves en
  `Tools/v2/claves-pendientes/e7b-a-tN.json` y las aplica con
  `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e7b-a-tN.json` para correr sus tests.
  **Si en su ola es dueña de `Localizable.xcstrings`** (lo dice el despacho), commitea el
  catálogo y borra el JSON; **si no**, commitea sólo el JSON y descarta el catálogo
  (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`). Un número interpolado va
  como `String`, nunca `Int` (trampa 5).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis); los marcadores para tests van como `Color.clear` de fondo con `.accessibilityElement()`.
- **FisuJobs es la referencia visual**: `PanelCard`/`GameCard`, `ActionPill`/`StateBadge`,
  `PanelTitleBanner`, paleta y `Tokens`. Nada de alertas ni botones del sistema.
- **Reduce Motion**: la cuenta regresiva no anima los dígitos; la pantalla previa entra y sale
  con fundido.
- Código nuevo limpio, pocos comentarios; los heredados no se borran por deporte, pero **el que
  deja de ser verdad se reescribe en el mismo commit** (sobre todo los que hablan de `armIfDue`,
  "la cadencia de 7 min" y `showInterstitialIfAppropriate`).
- **Commits en español**, `feat(anuncios): …`, `test(anuncios): …`, `chore(mediacion): …`,
  **SIN `Co-Authored-By`**. Staging selectivo por archivo y `git diff --cached --stat` antes de
  cada commit; un comando git por llamada.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración con
  `oraculo.sh rapido` → `Docs/SESION-<fecha>-v2-e7b.md` → las cuatro ediciones de
  `Docs/HANDOFF.md` → journal AVO. Ningún subagente toca `Docs/`, `handoffs/`, el journal ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI + pipeline + pacing-sim + Release
```

- `rapido` al cerrar cada tarea; `completo` al cerrar T3 (pantalla previa y UI test), T6 (la
  mediación cambia el binario: el paso `release` compila con `-ObjC` y los adaptadores) y T7.
- Los tests nuevos entran solos (el oráculo corre las suites enteras).

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e7b-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e7b" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e7b" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/NaturalBreakWiringTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

Para el SE o el iPad se cambia sólo el dispositivo del `simctl create`:
`"iPhone SE (3rd generation)"` o `"iPad Pro 13-inch (M4)"`.

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `-only-testing:`). Antes de culpar al código ante un rojo en masa: `uptime`,
`ps aux | grep '[x]codebuild'` y qué árbol compiló (las rutas de los `SwiftCompile` del log).

## Las referencias de PLAN-v2 E7, verificadas contra el árbol (`8d17b8d`)

| Lo que cita el plan | Dónde está hoy | Qué hace E7b-a |
|---|---|---|
| `showRewardedInterstitial()` / `showAppOpen()` + `isReady`/`preload`; vida 55 min / 3 h 30 | `AdsProvider.swift:38-57, 70-78`; `AdMobAdsProvider.swift:202-285` | ✅ E7a; nada |
| Unidades nuevas; `rewarded(for:)` exhaustivo | `FeatureFlags.swift:17-36, 118-130`; `feature_flags.json`; `ads.json:3-15` | ✅ E7a; `appOpen` y las 4 de video en `null` (gate del dueño) |
| `AdsRemoteConfig` "IDs, cadencia, alternancia, app open, interruptores, `restrictedStorefronts`" | `AdsRemoteConfig.swift`, `AdsRemoteConfigLoader.swift`; **nadie lo instancia en la app** y **nadie llama `refresh()`** (la caché nunca se escribe); `LootBoxGate` (E5a T8) leerá `current()` | **T1**: un pacer por proceso, `refresh()` en segundo plano, IDs remotos en Release |
| `enum NaturalBreak` "reemplaza a `showInterstitialIfAppropriate`" | `NaturalBreakPolicy.swift:6-18`; `ForcedAdsPacer.swift:37-54` ("todavía no lo crea nadie") | **T1–T2** |
| los llamadores del intersticial de la 1.x | `GameState.swift:474-486` (`isSafeMomentForInterstitial`, `showInterstitialIfAppropriate`); `RootView.swift:250-259` (cerrar hoja; **E3b T4 lo muda a `menuDidClose()`** en `GameState+Menu.swift`), `:291-303` (popup offline); `GameState+Prestige.swift:131-143` | **T2**: cortes |
| el reloj de la 1.x | `AdsCoordinator.swift:64-84, 149-154, 232-272` (`cadence`, `sessionStartedAt`, `armIfDue`, `showInterstitialIfArmed`, `sessionResumed`); `GameState.swift:943` (`armIfDue` en `flushHUD`), `:962` (`sessionResumed`, **E1 T8 lo muda a `GameState+Lifecycle.swift`**); `RewardedAdsConfig.Interstitial` (`AdsProvider.swift:160-196`); `rewarded_ads.json:39-43` | **T2**: se borra |
| `lastFullScreenAt` único, alternancia persistida, nunca dos formatos en un corte, gracia de 90 s | `AdsPacingState` (`NaturalBreakPolicy.swift:49-73`), `decide` (`:194-222`) | ✅ E7a |
| "Pausa publicitaria: `RewardedInterstitialIntroView` con cuenta regresiva de 5 s y «No, gracias» visible; premio rotativo" | no existe | **T3** |
| "App open: sólo `returnFromBackground`, ≥ 180 s afuera, 1 cada 20 min, desde la 2ª sesión" | la regla está (`decideAppOpen`, `:224-239`); nadie precarga al irse ni decide al volver | **T4** |
| `remove_ads` (y starter) cortan los tres forzados | `AdsCoordinator.swift:144-230`; `GameState+Store.swift:215-217` llama `setRemovedAds` | ✅ E7a |
| Copia de los Términos | `Distribution/site/terms.md:86-88`, `Resources/Legal/terms.md` | ✅ (E10 docs); el sitio es de E10 |
| UMP: fila "Opciones de privacidad" (`settings.privacy.options`) visible si `AdsConsent.showsPrivacyOptions` | `AdsConsent.swift:64-76` (`showsPrivacyOptions`, `presentPrivacyOptions()`); **nadie los llama**; `SettingsView.swift:105-111` sin la sección | **T5** |
| Mediación: adaptadores SPM, SKAdNetwork, Ad Inspector, `PrivacyInfo` | `project.yml:10-30` (sólo `GoogleMobileAds` `from: 13.9.0`); `Info.plist` 50 `SKAdNetworkItems`; `Resources/PrivacyInfo.xcprivacy` (`NSPrivacyTracking` false); `DebugPanelView.swift` sin anuncios | **T6** (versiones de la tabla de E7a: **verificar URL y versión al implementar**) |
| Columna lateral; mapa de ubicaciones | — | E7b-b |

## Lo que E7b-a usa de otros planes (y el paso 0 que lo comprueba)

| API | La define | La usa |
|---|---|---|
| `GameState.handleScenePhase(from:to:now:)`, `seal(now:)`, `isSceneActive` en `GameState+Lifecycle.swift` | E1 T8 | T2, T4 |
| `GameState.menuDidClose() async` (y `MenuSessionTests`) en `GameState+Menu.swift` | E3b T3, T4 | T2 |
| `GameState.isCalmMoment`, `grant(_:multiplier:source:now:)`, `grantableRewardKinds` (con `.package` sumado por E5) | E4a T8; E5a T6 | T2 (test cruzado), T3 |
| `RootView.coversBoard` y sus `onChange` | E4b T3 | T3 |
| `RewardCopy.title(_:)` y `RewardCopy.symbol(_:)` sobre un `RewardSpec` | E5b T1 | T3 |
| `TowerNotice.Kind.rewardCompensated(durationText:)` y su clave en `TowerNoticeView` | E1 T14 | T3 (suma su caso al lado) |
| `fisuSheet()` (no se usa: la pantalla previa NO es hoja) | E3a T6 | — |
| las filas y secciones de Ajustes de E11 | E11 T4 | T5 |
| `InfoPlistContractTests` (no se toca: la mediación tiene su suite) | E3a T5 | — |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Managers/Ads/ForcedAdsSetup.swift` | **nuevo** — modo, pacer por proceso, aplicar el refresco | 1 |
| `FisuEvolution/Managers/Ads/AdsCoordinator.swift` | `pacer`, `settleDelay`, `naturalBreakTask`, `readyForcedFormats`, IDs remotos; se borra el reloj de la 1.x | 1, 2 |
| `FisuEvolution/Managers/FeatureFlags.swift` | `effectiveAdUnitIDs(remote:)`, `releaseAdUnitIDs(declared:remote:)` | 1 |
| `FisuEvolution/App/FisuEvolutionApp.swift` | `startServices`: la config, el pacer y el refresco | 1, 2 |
| `FisuEvolution/Game/State/GameState+Ads.swift` | **nuevo** — contexto, cortes, retener la cola, irse/volver, la pausa, el app open | 2, 3, 4 |
| `FisuEvolution/Utilities/Log.swift` | `Log.ads` | 1 |
| `FisuEvolution/Managers/Ads/AdsProvider.swift` (`RewardedAdsConfig`) | sin `Interstitial`; con `AdBreak` | 2, 3 |
| `FisuEvolution/Resources/Config/rewarded_ads.json` | sin `interstitial`; con `adBreak` | 2, 3 |
| `FisuEvolution/Managers/Ads/NaturalBreakPolicy.swift` | `secondsUntilAlternatingDue`; `AdsPacingState.adBreakPrizeIndex` | 3 |
| `FisuEvolution/Managers/Ads/ForcedAdsPacer.swift` | el turno, el premio de la pausa, `couldShowAppOpenOnReturn` | 3, 4 |
| `FisuEvolution/Game/State/GameState.swift` 🔥 | se borran los dos del intersticial; `flushHUD`; `adBreakOffer`; `TowerNotice.Kind.rewardGranted` | 2, 3 |
| `FisuEvolution/Game/State/GameState+Lifecycle.swift` | irse y volver | 2 |
| `FisuEvolution/Game/State/GameState+Prestige.swift`, `+Menu.swift`, `+Celebrations.swift` | los cortes | 2 |
| `FisuEvolution/App/RootView.swift` 🔥 | el corte del offline; la pantalla previa; el aviso del premio | 2, 3 |
| `FisuEvolution/UI/Ads/RewardedInterstitialIntroView.swift` | **nuevo** — la pantalla previa | 3 |
| `FisuEvolution/UI/DebugPanelView.swift` | sección "Anuncios": Ad Inspector y la pausa ahora | 3, 6 |
| `FisuEvolution/Managers/Ads/AdsConsent.swift` | `privacyRowVisible` | 5 |
| `FisuEvolution/UI/Menu/SettingsView.swift` 🔥 | la sección de privacidad | 5 |
| `project.yml` 🔥 | los cuatro adaptadores y `-ObjC` | 6 |
| `FisuEvolution/Info.plist` | la unión de SKAdNetwork | 6 |
| `FisuEvolution/Managers/Ads/AdMobAdsProvider.swift` | `AdInspector` (DEBUG) | 6 |
| `Tools/v2/skadnetwork.py`, `Tools/v2/test_skadnetwork.py` | **nuevos** — bajar, unir y escribir las listas | 6 |
| `Distribution/setup-v2-asc-admob-mediacion.md` | lo que declaran los SDK (App Privacy) | 6 |
| tests | `ForcedAdsSetupTests`, `NaturalBreakWiringTests`, `AdBreakTests`, `AppOpenWiringTests`, `MediationContractTests` (unit); `AdBreakUITests`, `SettingsPrivacyUITests` (UI); retocados `AdFormatsTests`, `NaturalBreakPolicyTests`, `MenuSessionTests` | 1–6 |

## Orden, olas y paralelismo

**Archivos calientes** (PLAN-v2 §0.1, un solo dueño por ola): `GameState.swift`,
`RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`, `GameState+Bonus.swift`,
`SettingsView.swift`, `PlayerState.swift`, `TowerActions.swift`, `project.yml`,
`Localizable.xcstrings`. **Tibios** (de varios planes, se secuencian): `FisuEvolutionApp.swift`
(E1 T5/T8, E11 T6), `GameState+Lifecycle.swift` (E1 T8, E11 T6), `GameState+Celebrations.swift`
(E1 T9/T10, E4b, E6a T12), `GameState+Menu.swift` (E3b), `Info.plist` (E1 T6, E3a T5),
`DebugPanelView.swift` (E2a T14, E3b, E4b, E5b).

| T | Archivos | 🔥 calientes | Tibios | Depende de |
|---|---|---|---|---|
| 1 | `ForcedAdsSetup.swift`, `AdsCoordinator.swift`, `FeatureFlags.swift`, `FisuEvolutionApp.swift`, `Log.swift`, `ForcedAdsSetupTests.swift` | — | `FisuEvolutionApp` | **E1 T8, E11 T6** (últimos en `FisuEvolutionApp`) |
| 2 | `GameState+Ads.swift`, `AdsCoordinator.swift`, `AdsProvider.swift`, `rewarded_ads.json`, `GameState.swift`, `+Lifecycle`, `+Prestige`, `+Menu`, `+Celebrations`, `RootView.swift`, `FisuEvolutionApp.swift`, `AdFormatsTests`, `MenuSessionTests`, `NaturalBreakWiringTests` | `GameState.swift`, `RootView.swift` | `+Lifecycle`, `+Celebrations`, `+Menu`, `FisuEvolutionApp` | T1; **E1 T8**; **E3b T4**; **E4a T8** (el test cruzado con `isCalmMoment`) |
| 3 | `RewardedInterstitialIntroView.swift`, `GameState+Ads.swift`, `GameState.swift`, `NaturalBreakPolicy.swift`, `ForcedAdsPacer.swift`, `AdsProvider.swift`, `rewarded_ads.json`, `RootView.swift`, `DebugPanelView.swift`, `NaturalBreakPolicyTests`, `AdBreakTests`, `AdBreakUITests`, catálogo | `GameState.swift`, `RootView.swift`, catálogo | `DebugPanelView` | T2; **E4a T8**, **E5a T6** (`.package` entregable), **E5b T1** (`RewardCopy`), **E4b T3** (`coversBoard`), **E1 T14** (`TowerNotice`) |
| 4 | `GameState+Ads.swift`, `ForcedAdsPacer.swift`, `AppOpenWiringTests` | — | — | T2 (T3 ∥ T4 NO: los dos editan `+Ads`) |
| 5 | `AdsConsent.swift`, `SettingsView.swift`, `SettingsPrivacyUITests`, catálogo | `SettingsView.swift`, catálogo | — | **E11 T4** (último en `SettingsView`); antes de las tareas de Ajustes de E9 |
| 6 | `project.yml`, `Info.plist`, `skadnetwork.py`, `test_skadnetwork.py`, `AdMobAdsProvider.swift`, `DebugPanelView.swift`, `MediationContractTests`, `Distribution/setup-v2-asc-admob-mediacion.md` | `project.yml` | `Info.plist`, `DebugPanelView` | T1 (`Log.ads`); **E3a T5** (último en `project.yml`/`Info.plist`) |
| 7 | cierre (controlador) | — | `Docs/` | todas |

```
Ola 1 (fría)                         T1 la config en marcha ║ T5 UMP (si E11 T4 cerró)
Ola 2 (caliente: GameState+RootView) T2 los cortes ║ T6 mediación (archivos disjuntos de T2)
Ola 3 (caliente + catálogo)          T3 la pausa publicitaria
Ola 4                                T4 el app open
Ola 5                                T7 cierre
```

**Reglas del paralelismo:**

1. Cada tarea en su worktree aislado (`Agent(isolation: "worktree")`), desde la punta de la rama
   de la épica (`v2/e7b-anuncios`), con su DerivedData y su simulador por UDID.
2. El controlador integra de a una (`git rebase` + `git merge --ff-only`), corre `rapido`, aplica
   los snapshots de `Tools/v2/claves-pendientes/` y recién ahí hace los docs.
3. Hasta 3 agentes compilando a la vez. T6 resuelve paquetes de red: su primera compilación es
   lenta; no es un error.
4. Un agente que necesita un archivo caliente que no es suyo en la ola para y reporta
   `NEEDS_CONTEXT`.
5. E7b-b arranca su T3 después de este T3 (`TowerNotice.Kind.rewardGranted`) y de su propio T1.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| Un reloj que avanza cuando el test lo pide | `TestClock` (`read`, `advance(by:)`), interno | `FisuEvolutionTests/AdFormatsTests.swift:158` |
| Un proveedor que anota y deja cerrar el anuncio | `ScriptedAdsProvider` (`shown`, `preloaded`, `earnsReward`, `holdsOpen`, `closeCurrentAd()`, `waitUntilShowing()`), interno | `AdFormatsTests.swift:174` |
| La política con el app open prendido | `NaturalBreakPolicy.with(appOpenEnabled:)`, extensión interna del target de tests | `NaturalBreakPolicyTests.swift:456` |
| `UserDefaults` descartable | `ScratchPacingDefaults` (**privado: copiarlo** como `ScratchDefaults`) | `NaturalBreakPolicyTests.swift:464` |
| Reencarnar en un test | `giveEarningsForPrestigeTesting(oro:)` + `confirmPrestige()` | `GameState+Debug.swift:119`; `GameLoopWiringTests.swift:226-230` |
| La fase obligatoria del tutorial | `beginTutorialPhase()` | `GameState+Celebrations.swift:69` |
| Cerrar celebraciones como el jugador | `dismissChestReward()`, `dismissDailyClaim()`, `dismissSpecialDrop()`, `celebrationFinished(_:)` | `GameState+Chests.swift:268`, `GameState+Bonus.swift:283`, `GameState+Actions.swift:325`, `GameState+Celebrations.swift:102` |
| Un juego que produce (para el popup offline) | `player?.run.passiveUnlocked[base] = true` con `content.tiers.baseType.id` | patrón de `LifecycleTests` (E1 T8) |
| Fixtures de UI | `--uitest-reset`, `--uitest-skip-tutorial`, `--uitest-coins`, `--uitest-offline` | `GameState.swift:530-765`, `GameState+Debug.swift:48-60` |
| Esperas de UI | `waitForExistence`, `waitForNonExistence(timeout:)`; `waitUntilHittable` (privado: copiarlo) | XCTest; `BottomMenuUITests.swift:183` |
| Marcadores | `board.units` (`RootView.swift:350-356`), `tower.notice` (`TowerNoticeView`, `RootView.swift:726`), `sheet.close` (`GameArt.swift:205`), `hud.upgrades`, `menu.card.settings` | — |

---

### Task 1: La config remota en marcha — un pacer por proceso, los IDs del sitio y el refresco

**Objetivo:** que la App cree **un** `ForcedAdsPacer` por proceso con la config que haya en disco
(caché o respaldo del bundle), que pida la versión publicada en segundo plano y la aplique a la
cadencia apenas llega, y que en Release los IDs de anuncio salgan de esa config. Sin cambiar
todavía quién muestra qué: el reloj de la 1.x sigue hasta T2. Bajo XCTest y bajo `--uitest*` no
se crea pacer, salvo `--uitest-ad-break` (la política de los UI tests de T3).

**Files:**
- Create: `FisuEvolution/Managers/Ads/ForcedAdsSetup.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Managers/Ads/AdsCoordinator.swift`
- Modify: `FisuEvolution/Managers/FeatureFlags.swift`
- Modify: `FisuEvolution/App/FisuEvolutionApp.swift` (`startServices`)
- Modify: `FisuEvolution/Utilities/Log.swift` (`Log.ads`)
- Create: `FisuEvolutionTests/ForcedAdsSetupTests.swift`

**Interfaces:**
- Consumes: `AdsRemoteConfigLoader` (`current()`, `refresh()`, `RefreshOutcome`),
  `NaturalBreakPolicy(config:)`, `ForcedAdsPacer(policy:store:now:)`, `AdsPacingStore(defaults:key:)`.
- Produces: `@MainActor enum ForcedAdsSetup` (`enum Mode { off, production, uiTestAdBreak }`,
  `nonisolated static func mode(arguments:environment:) -> Mode`, `static let uiTestAdBreakPolicy`,
  `static func makePacer(mode:config:defaults:) -> ForcedAdsPacer?`,
  `static func apply(_:to:)`); `AdsCoordinator.pacer`, `attachPacer(_:)`, `settleDelay: Duration`,
  `naturalBreakTask: Task<Void, Never>?`, `readyForcedFormats: Set<ForcedAdFormat>`,
  `configure(flags:remoteUnitIDs:cadence:removedAds:)` (T2 le saca `cadence:`);
  `FeatureFlags.effectiveAdUnitIDs(remote:)`, `static FeatureFlags.releaseAdUnitIDs(declared:remote:)`;
  `Log.ads`.

- [ ] **Step 0: Los dueños previos de `FisuEvolutionApp.swift` cerraron**

Run (uno por llamada):

```bash
grep -n "attachBackgroundTasks" FisuEvolution/App/FisuEvolutionApp.swift
grep -n "private func startServices" FisuEvolution/App/FisuEvolutionApp.swift
grep -n "ads.configure" FisuEvolution/App/FisuEvolutionApp.swift
```

Expected: una línea cada uno (E1 T8 adjuntó las tareas de background; E11 T6 tocó
`startServices`). Si `startServices` cambió de forma, se respeta lo que haya y sólo se reemplaza
la llamada a `ads.configure` por el bloque del Step 4.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/ForcedAdsSetupTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

/// Cómo arrancan los forzados de la 2.0 en un proceso (PLAN-v2 E7): con qué
/// política, desde qué config, y nunca bajo los tests salvo que lo pidan.
@Suite("Los forzados arrancan con la config que hay", .serialized)
@MainActor
struct ForcedAdsSetupTests {

    @Test("bajo XCTest no corren; bajo UI tests, sólo si el test los pide")
    func modeFollowsTheRun() {
        let xctest = ["XCTestConfigurationFilePath": "/tmp/fixture.xctestconfiguration"]
        #expect(ForcedAdsSetup.mode(arguments: [], environment: xctest) == .off)
        #expect(ForcedAdsSetup.mode(arguments: ["--uitest-reset"], environment: [:]) == .off)
        #expect(ForcedAdsSetup.mode(arguments: ["--uitest-reset", "--uitest-ad-break"], environment: [:]) == .uiTestAdBreak)
        #expect(ForcedAdsSetup.mode(arguments: [], environment: [:]) == .production)
    }

    @Test("en producción la política sale de la config; sin config, del respaldo de código")
    func productionPolicyComesFromTheConfig() throws {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let config = try Self.bundledConfig()

        let pacer = try #require(ForcedAdsSetup.makePacer(mode: .production, config: config, defaults: scratch.defaults))
        #expect(pacer.policy == NaturalBreakPolicy(config: config))

        let fallback = try #require(ForcedAdsSetup.makePacer(mode: .production, config: nil, defaults: scratch.defaults))
        #expect(fallback.policy == .default)

        #expect(ForcedAdsSetup.makePacer(mode: .off, config: config, defaults: scratch.defaults) == nil)
    }

    @Test("el pacer de los UI tests guarda aparte: no toca el reloj del jugador")
    func uiTestPacerUsesItsOwnKey() throws {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let pacer = try #require(ForcedAdsSetup.makePacer(mode: .uiTestAdBreak, config: nil, defaults: scratch.defaults))
        #expect(pacer.policy == ForcedAdsSetup.uiTestAdBreakPolicy)
        #expect(scratch.defaults.data(forKey: "ads.pacing") == nil)
        #expect(scratch.defaults.data(forKey: "ads.pacing.uitest") != nil)
    }

    @Test("una config nueva del sitio rige en el acto; una rechazada o la red caída, no")
    func refreshUpdatesThePolicy() throws {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let pacer = ForcedAdsPacer(policy: .default, store: AdsPacingStore(defaults: scratch.defaults))

        ForcedAdsSetup.apply(.unreachable, to: pacer)
        ForcedAdsSetup.apply(.rejected(.badResponse), to: pacer)
        #expect(pacer.policy == .default)

        var config = try Self.bundledConfig()
        config = try Self.withCadence(config, minSecondsBetweenForced: 300)
        ForcedAdsSetup.apply(.updated(config), to: pacer)
        #expect(pacer.policy.minSecondsBetweenForced == 300)
    }

    @Test("en Release mandan los IDs del sitio; si no hay, el JSON; si tampoco, los de prueba")
    func releaseUnitIDs() {
        let remote = FeatureFlags.AdUnitIDs(rewardedGifts: "ca-app-pub-8575641544774372/1")
        let declared = FeatureFlags.AdUnitIDs(rewardedGifts: "ca-app-pub-8575641544774372/2")
        #expect(FeatureFlags.releaseAdUnitIDs(declared: declared, remote: remote) == remote)
        #expect(FeatureFlags.releaseAdUnitIDs(declared: declared, remote: nil) == declared)
        #expect(FeatureFlags.releaseAdUnitIDs(declared: nil, remote: nil) == .googleTest)
    }

    @Test("el coordinador dice qué forzados están listos, y ninguno con remove_ads")
    func readyForcedFormats() {
        let ads = AdsCoordinator(provider: ScriptedAdsProvider())
        #expect(ads.readyForcedFormats == Set(ForcedAdFormat.allCases))
        ads.setRemovedAds(true)
        #expect(ads.readyForcedFormats.isEmpty)
    }

    // MARK: - Andamio

    /// El `ads.json` embarcado, validado contra el publisher del `Info.plist`.
    private static func bundledConfig() throws -> AdsRemoteConfig {
        let loader = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "ads-\(UUID().uuidString).json")
        )
        return try #require(loader.current()?.config)
    }

    /// Una copia de la config con otra cadencia, por JSON (los tipos son `let`).
    private static func withCadence(_ config: AdsRemoteConfig, minSecondsBetweenForced: Double) throws -> AdsRemoteConfig {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var cadence = try #require(object["cadence"] as? [String: Any])
        cadence["minSecondsBetweenForced"] = minSecondsBetweenForced
        object["cadence"] = cadence
        return try JSONDecoder().decode(AdsRemoteConfig.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

/// Un dominio de `UserDefaults` descartable por test (copia de `ScratchPacingDefaults`).
private struct ScratchDefaults {
    let name = "e7b-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/ForcedAdsSetupTests`.
Expected: no compila (`ForcedAdsSetup`, `releaseAdUnitIDs`, `readyForcedFormats` no existen).

- [ ] **Step 3: `ForcedAdsSetup` y los IDs**

`FisuEvolution/Managers/Ads/ForcedAdsSetup.swift`:

```swift
import Foundation

/// Cómo arrancan los anuncios forzados de la 2.0 en este proceso (PLAN-v2 E7):
/// si corren, con qué política y desde qué config. Es lo único que la App
/// llama: `ForcedAdsPacer` y `NaturalBreakPolicy` (E7a) no saben de dónde salen
/// sus números.
@MainActor
enum ForcedAdsSetup {
    enum Mode: Equatable {
        /// Sin forzados: los unit tests, y los UI tests que no los piden.
        case off
        case production
        /// `--uitest-ad-break`: la pausa publicitaria en cada corte, sin esperas.
        case uiTestAdBreak
    }

    nonisolated static func mode(arguments: [String], environment: [String: String]) -> Mode {
        if environment["XCTestConfigurationFilePath"] != nil { return .off }
        if arguments.contains("--uitest-ad-break") { return .uiTestAdBreak }
        if arguments.contains(where: { $0.hasPrefix("--uitest") }) { return .off }
        return .production
    }

    /// La política de los UI tests de la pausa: es lo único que sale, en cada
    /// corte y sin gracias. Construida a mano a propósito: `ads.json` no puede
    /// bajar de los pisos (E7a), y no tiene por qué.
    static let uiTestAdBreakPolicy = NaturalBreakPolicy(
        minSecondsBetweenForced: 0,
        graceSecondsAfterLaunch: 0,
        graceSecondsAfterRewarded: 0,
        alternation: [.rewardedInterstitial],
        appOpenMinSecondsAway: AdsRemoteConfig.Floor.appOpenMinSecondsAway,
        appOpenMinSecondsBetween: AdsRemoteConfig.Floor.appOpenMinSecondsBetween,
        appOpenMinSessionNumber: AdsRemoteConfig.Floor.appOpenMinSessionNumber,
        enabledFormats: [.rewardedInterstitial]
    )

    /// Construirlo cuenta un arranque en frío (`ForcedAdsPacer.init`): se llama
    /// una vez por proceso, desde `startServices`.
    static func makePacer(mode: Mode, config: AdsRemoteConfig?, defaults: UserDefaults = .standard) -> ForcedAdsPacer? {
        switch mode {
        case .off:
            nil
        case .production:
            ForcedAdsPacer(
                policy: config.map(NaturalBreakPolicy.init(config:)) ?? .default,
                store: AdsPacingStore(defaults: defaults)
            )
        case .uiTestAdBreak:
            ForcedAdsPacer(
                policy: uiTestAdBreakPolicy,
                store: AdsPacingStore(defaults: defaults, key: "ads.pacing.uitest")
            )
        }
    }

    /// Lo que llegó del sitio rige desde ya para la cadencia y los interruptores.
    /// Los IDs, desde el próximo arranque: el proveedor ya está creado.
    static func apply(_ outcome: AdsRemoteConfigLoader.RefreshOutcome, to pacer: ForcedAdsPacer) {
        guard case .updated(let config) = outcome else { return }
        pacer.policy = NaturalBreakPolicy(config: config)
    }
}
```

`FeatureFlags.swift`, junto a `effectiveAdUnitIDs` (que pasa a delegar):

```swift
    var effectiveAdUnitIDs: AdUnitIDs { effectiveAdUnitIDs(remote: nil) }

    /// Los IDs efectivos con los de la config remota adelante (PLAN-v2 E7: los
    /// IDs cambian sin pasar por Apple). En DEBUG, los de prueba de Google
    /// siempre, por lo que explica el docstring de arriba.
    func effectiveAdUnitIDs(remote: AdUnitIDs?) -> AdUnitIDs {
        #if DEBUG
        .googleTest
        #else
        Self.releaseAdUnitIDs(declared: adUnitIDs, remote: remote)
        #endif
    }

    /// La regla de Release, sin `#if` para poder probarla en Debug: lo remoto
    /// (que llegó validado contra el publisher propio) gana; si no hay, el JSON;
    /// si tampoco, los de prueba.
    static func releaseAdUnitIDs(declared: AdUnitIDs?, remote: AdUnitIDs?) -> AdUnitIDs {
        remote ?? declared ?? .googleTest
    }
```

(La propiedad `effectiveAdUnitIDs` existente se reemplaza por la de una línea; su docstring
largo queda sobre la función nueva.)

`AdsCoordinator.swift`, después de `isPresentingFullScreen`:

```swift
    // MARK: - Los forzados de la 2.0

    /// El estado de la política de cortes naturales. `nil` = este proceso no
    /// muestra forzados (tests, o UI tests que no los piden).
    @ObservationIgnored private(set) var pacer: ForcedAdsPacer?
    /// Cuánto se espera entre el corte y el anuncio: que termine de irse la hoja
    /// que se cerró, y que el toque que la cerró no caiga en el anuncio. Los
    /// tests lo ponen en cero.
    @ObservationIgnored var settleDelay: Duration = .milliseconds(600)
    /// El corte en vuelo: uno a la vez, y los tests lo esperan.
    @ObservationIgnored var naturalBreakTask: Task<Void, Never>?

    func attachPacer(_ pacer: ForcedAdsPacer) {
        self.pacer = pacer
    }

    /// Los forzados con inventario, ya filtrados por `remove_ads` y por el
    /// anuncio en pantalla: lo que la política llama `readyFormats`.
    var readyForcedFormats: Set<ForcedAdFormat> {
        var ready: Set<ForcedAdFormat> = []
        if isInterstitialReady { ready.insert(.interstitial) }
        if isRewardedInterstitialReady { ready.insert(.rewardedInterstitial) }
        if isAppOpenReady { ready.insert(.appOpen) }
        return ready
    }
```

y `configure` suma los IDs remotos (en T2 pierde `cadence:`):

```swift
    func configure(
        flags: FeatureFlags,
        remoteUnitIDs: FeatureFlags.AdUnitIDs?,
        cadence: RewardedAdsConfig.Interstitial,
        removedAds: Bool
    ) async {
        …
        let provider = AdMobAdsProvider(unitIDs: flags.effectiveAdUnitIDs(remote: remoteUnitIDs), now: now)
        …
    }
```

- [ ] **Step 4: La App lo arma**

`FisuEvolutionApp.swift`, en `startServices`, el bloque de `ads.configure` queda:

```swift
        gameState.attachAds(ads)
        if let content = gameState.content {
            let process = ProcessInfo.processInfo
            let mode = ForcedAdsSetup.mode(arguments: process.arguments, environment: process.environment)
            // Disco y nada más: la caché revalidada o el respaldo del bundle. La red
            // va aparte, abajo, y no demora el arranque (E7a).
            let loader = AdsRemoteConfigLoader()
            let remote = loader.current()?.config
            await ads.configure(
                flags: content.flags,
                remoteUnitIDs: mode == .production ? remote?.adUnitIDs : nil,
                cadence: content.rewardedAds.effectiveInterstitial,
                removedAds: gameState.player?.meta.removedAds ?? false
            )
            if let pacer = ForcedAdsSetup.makePacer(mode: mode, config: remote) {
                ads.attachPacer(pacer)
                if mode == .production {
                    Task {
                        let outcome = await loader.refresh()
                        Log.ads.info("config remota: \(String(describing: outcome))")
                        ForcedAdsSetup.apply(outcome, to: pacer)
                    }
                }
            }
        }
```

`Log.swift`, junto a los otros:

```swift
    static let ads = Logger(subsystem: subsystem, category: "ads")
```

- [ ] **Step 5: Verde y oráculo**

Run: Receta R con `ForcedAdsSetupTests`, `AdFormatsTests`, `AdsRemoteConfigTests`, `AdUnitIDsTests` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Managers/Ads/ForcedAdsSetup.swift
git add FisuEvolution/Managers/Ads/AdsCoordinator.swift
git add FisuEvolution/Managers/FeatureFlags.swift
git add FisuEvolution/App/FisuEvolutionApp.swift
git add FisuEvolution/Utilities/Log.swift
git add FisuEvolutionTests/ForcedAdsSetupTests.swift
git diff --cached --stat
git commit -m "feat(anuncios): la config remota en marcha — un pacer por proceso, los IDs del sitio y el refresco en segundo plano"
```

---

### Task 2: Los cortes naturales — el único lugar que muestra un forzado, y adiós al reloj de la 1.x

**Objetivo:** `GameState+Ads` arma el contexto, pide el corte con una pausa de 0,6 s, decide con
el pacer y muestra el intersticial común con la cola de celebraciones retenida. Los tres
llamadores de la 1.x pasan a ser cortes (`.sheetClosed` al cerrar el menú, `.offlinePopupDismissed`
al cerrar el popup offline, `.reincarnation` al reencarnar), se suma `.celebrationsDrained` (la
última celebración grande se fue) y las dos vueltas del ciclo de vida alimentan el pacer. Se
borra el reloj de la 1.x entero. La pausa publicitaria todavía no se ofrece (T3).

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Ads.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Managers/Ads/AdsCoordinator.swift` (se borra el reloj de la 1.x)
- Modify: `FisuEvolution/Managers/Ads/AdsProvider.swift` (`RewardedAdsConfig` sin `Interstitial`)
- Modify: `FisuEvolution/Resources/Config/rewarded_ads.json` (sin `interstitial`)
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (`:456-486` y la línea `:943`)
- Modify: `FisuEvolution/Game/State/GameState+Lifecycle.swift` (E1 T8)
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift` (`:131-143`)
- Modify: `FisuEvolution/Game/State/GameState+Menu.swift` (E3b T3)
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`publishCelebration`)
- Modify: `FisuEvolution/App/RootView.swift` 🔥 (el `onDismiss` del offline, `:291-303`)
- Modify: `FisuEvolution/App/FisuEvolutionApp.swift` (`configure` sin `cadence:`)
- Modify: `FisuEvolutionTests/AdFormatsTests.swift`, `FisuEvolutionTests/MenuSessionTests.swift` (E3b T3)
- Create: `FisuEvolutionTests/NaturalBreakWiringTests.swift`

**Interfaces:**
- Consumes: T1 (`pacer`, `settleDelay`, `naturalBreakTask`, `readyForcedFormats`); **E1 T8**
  (`isSceneActive`, `handleScenePhase(from:to:now:)`); **E3b T3** (`menuDidClose() async`);
  **E4a T8** (`isCalmMoment`, sólo en el test cruzado).
- Produces: `GameState.naturalBreakContext`, `scheduleNaturalBreak(_:)`, `naturalBreak(_:) async`,
  `holdCelebrationsForAd()`, `releaseCelebrationsAfterAd()`, `adsDidEnterBackground()`,
  `adsDidReturnFromBackground()`; `CelebrationKind.endsInNaturalBreak`;
  `AdsCoordinator.configure(flags:remoteUnitIDs:removedAds:)`.
- Borra: `GameState.isSafeMomentForInterstitial`, `showInterstitialIfAppropriate()`;
  `AdsCoordinator.cadence`, `sessionStartedAt`, `lastInterstitialAt`, `isInterstitialArmed`,
  `armIfDue()`, `showInterstitialIfArmed()`, `sessionResumed()`, `forcedAdFinished()`;
  `RewardedAdsConfig.Interstitial`, `.interstitial`, `.effectiveInterstitial`.

- [ ] **Step 0: Los dueños previos cerraron**

Run (uno por llamada):

```bash
grep -n "func handleScenePhase(from" FisuEvolution/Game/State/GameState+Lifecycle.swift
grep -n "ads?.sessionResumed()" FisuEvolution/Game/State/GameState+Lifecycle.swift
grep -n "func menuDidClose" FisuEvolution/Game/State/GameState+Menu.swift
grep -n "var isCalmMoment" FisuEvolution/Game/State/GameState+Rewards.swift
grep -rn "showInterstitialIfAppropriate\|armIfDue\|isInterstitialArmed\|sessionResumed\|effectiveInterstitial" FisuEvolution FisuEvolutionTests
grep -n "case " Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift
```

Expected: E1 T8, E3b T3/T4 y E4a T8 entraron. El quinto lista **todos** los usos de la 1.x que
esta tarea tiene que reemplazar o borrar (hoy: `GameState.swift`, `+Lifecycle`, `+Prestige`,
`+Menu`, `RootView.swift`, `FisuEvolutionApp.swift`, `AdsCoordinator.swift`, `AdFormatsTests`,
`MenuSessionTests`); si aparece uno más, se trata igual y se anota en el reporte. El sexto lista
los `CelebrationKind` vigentes: **cada uno tiene que quedar clasificado** en
`endsInNaturalBreak` (Step 3); los defaults para los que suman otras épicas están en la duda 6.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/NaturalBreakWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los cortes naturales en la partida (PLAN-v2 E7): quién los pide, qué los
/// frena y que el intersticial se muestre una vez y quede anotado.
@Suite("Los cortes naturales en la partida", .serialized)
@MainActor
struct NaturalBreakWiringTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let clock: TestClock
        let pacer: ForcedAdsPacer
        let scratch: ScratchDefaults
    }

    /// Un juego listo, con un pacer cuya gracia de arranque ya pasó.
    private func rig(policy: NaturalBreakPolicy = .default) async -> Rig {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        let pacer = ForcedAdsPacer(policy: policy, store: AdsPacingStore(defaults: scratch.defaults), now: clock.read)
        ads.attachPacer(pacer)
        gameState.attachAds(ads)
        clock.advance(by: 1000)
        return Rig(gameState: gameState, ads: ads, provider: provider, clock: clock, pacer: pacer, scratch: scratch)
    }

    /// Cierra lo que haya en la cola como lo cerraría el jugador.
    private func drainCelebrations(_ gameState: GameState) {
        var guardrail = 12
        while let kind = gameState.showing, guardrail > 0 {
            guardrail -= 1
            switch kind {
            case .chestOpening: gameState.dismissChestReward()
            case .dailyReward: gameState.dismissDailyClaim()
            case .specialDrop: gameState.dismissSpecialDrop()
            case .skinAward:
                gameState.skinAward = nil
                gameState.celebrationFinished(.skinAward)
            default: gameState.celebrationFinished(kind)
            }
        }
    }

    @Test("cerrar el menú es un corte: sale el intersticial y queda anotado")
    func closingTheMenuShowsAnInterstitial() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.menuDidClose()
        #expect(rig.provider.shown == ["interstitial"])
        #expect(rig.pacer.pacing.lastFullScreenAt == rig.clock.read())
    }

    @Test("dos cortes seguidos: el segundo choca con los 2 min")
    func twoBreaksInARow() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.clock.advance(by: 30)
        await rig.gameState.naturalBreak(.offlinePopupDismissed)
        #expect(rig.provider.shown == ["interstitial"])
    }

    @Test("con el tutorial no sale nada")
    func nothingDuringTheTutorial() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.beginTutorialPhase()
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("si no es un momento calmo (E4a), la política tampoco lo es")
    func calmMomentAndContextAgree() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.uiCoversBoard = true
        #expect(!rig.gameState.isCalmMoment)
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.gameState.uiCoversBoard = false
        rig.gameState.debugPresentCareerChoice()
        #expect(!rig.gameState.isCalmMoment)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("terminar una celebración grande con la cola vacía es un corte")
    func aDrainedQueueIsABreak() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        let day = try #require(rig.gameState.content?.dailyRewards.days.first)
        rig.gameState.dailyClaim = DailyRewardManager.Claim(day: day, coinsGranted: 1, specialGranted: nil, chestGranted: false)
        rig.gameState.syncCelebrations()
        #expect(rig.gameState.showing == .dailyReward)
        rig.gameState.dismissDailyClaim()
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown == ["interstitial"])
    }

    @Test("un aviso chico que se va no es un corte")
    func aToastIsNotABreak() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        rig.gameState.syncCelebrations()
        rig.gameState.celebrationFinished(.towerNotice)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("reencarnar es un corte: un intersticial, cuando la cola queda libre")
    func reincarnationIsABreak() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.giveEarningsForPrestigeTesting()
        rig.gameState.confirmPrestige()
        await rig.ads.naturalBreakTask?.value
        drainCelebrations(rig.gameState)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown == ["interstitial"], "uno solo: el de la reencarnación o el del final de su cofre")
    }

    @Test("mientras el anuncio está en pantalla la cola no presenta nada, y después sí")
    func theQueueWaitsForTheAd() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.provider.holdsOpen = true
        rig.gameState.scheduleNaturalBreak(.sheetClosed)
        await rig.provider.waitUntilShowing()
        let day = try #require(rig.gameState.content?.dailyRewards.days.first)
        rig.gameState.dailyClaim = DailyRewardManager.Claim(day: day, coinsGranted: 1, specialGranted: nil, chestGranted: false)
        rig.gameState.syncCelebrations()
        #expect(rig.gameState.showing == nil, "una hoja no se presenta debajo del anuncio")
        rig.provider.closeCurrentAd()
        await rig.ads.naturalBreakTask?.value
        #expect(rig.gameState.showing == .dailyReward)
    }

    @Test("volver del background reinicia la gracia de arranque")
    func returningRestartsTheGrace() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.adsDidEnterBackground()
        rig.clock.advance(by: 3600)
        rig.gameState.adsDidReturnFromBackground()
        rig.clock.advance(by: 60)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }
}

private struct ScratchDefaults {
    let name = "e7b-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
```

(`DailyRewardManager.Claim` es la de hoy, `ContentSystems.swift:349-356`. Si E2a T11 le cambió la
forma, se arma con la que haya: el test sólo necesita un diario en cola.)

`MenuSessionTests.swift` (de E3b T3) deja de armar el reloj de la 1.x:

```swift
    @Test("el intersticial se pide una vez al cerrar el menú, nunca al cambiar de página")
    func interstitialOnlyOnClose() async {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let suite = "menu-session-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        ads.attachPacer(ForcedAdsPacer(store: AdsPacingStore(defaults: defaults), now: clock.read))
        gameState.attachAds(ads)
        clock.advance(by: 10_000)

        gameState.menuDidOpen(at: .upgrades)
        gameState.menuPageChanged(to: .skins)
        gameState.menuPageChanged(to: .jobs)
        #expect(provider.shown.isEmpty, "cambiar de página no es una pausa natural")

        await gameState.menuDidClose()
        #expect(provider.shown == ["interstitial"])
    }
```

`AdFormatsTests.swift`: se borra `aForcedFormatDisarmsTheLegacyInterstitial` (`:141-152`) y su
docstring: la 1.x no existe más (lo que probaba —un reloj para los tres— lo prueba
`lastFullScreenAt` en `NaturalBreakPolicyTests`).

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/NaturalBreakWiringTests -only-testing:FisuEvolutionTests/MenuSessionTests`.
Expected: no compila (`naturalBreak`, `scheduleNaturalBreak`, `adsDidEnterBackground` no existen).

- [ ] **Step 3: `GameState+Ads.swift`**

```swift
import EconomyKit
import Foundation

/// Los anuncios forzados de la 2.0 en la partida (PLAN-v2 E7): el único lugar
/// que muestra un intersticial, una pausa publicitaria o un app open. Arma lo
/// que el juego sabe en el instante, le pregunta a la política de E7a por medio
/// de `ForcedAdsPacer` y presenta por `AdsCoordinator`, que no deja encimar dos
/// anuncios.
///
/// ⚠️ Mientras un forzado está en pantalla la cola de celebraciones queda
/// retenida. El SDK presenta su controlador encima de todo, y una hoja de
/// SwiftUI que intentara presentarse en ese momento fallaría sin aviso: su
/// turno quedaría tomado y nadie la vería.
extension GameState {

    // MARK: - El contexto

    /// Lo que el juego sabe ahora, en los términos de la política. "Hoja
    /// abierta" son los términos de `isCalmMoment` (E4a): una hoja, la ficha, la
    /// carrera o la escena inactiva.
    var naturalBreakContext: NaturalBreakContext {
        NaturalBreakContext(
            removedAds: player?.meta.removedAds ?? false,
            tutorialActive: tutorialPhaseActive || celebrations.allowedKinds != nil,
            sheetOpen: uiCoversBoard || characterSheet != nil || careerPrompt != nil || !isSceneActive,
            celebrationActive: celebrations.current != nil,
            adOnScreen: ads?.isPresentingFullScreen ?? false,
            lastRewardedAt: ads?.lastRewardedAt,
            // La pausa entra con su pantalla previa (Task 3); hasta entonces la
            // política sólo ve el común.
            readyFormats: (ads?.readyForcedFormats ?? []).subtracting([.rewardedInterstitial])
        )
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
        guard let ads else { return }
        switch format {
        case .interstitial:
            holdCelebrationsForAd()
            await ads.showInterstitial()
            pacer.recordShown(.interstitial)
            releaseCelebrationsAfterAd()
        case .rewardedInterstitial:
            // Task 3: la pantalla previa. El contexto todavía no la ofrece.
            break
        case .appOpen:
            // Sólo sale al volver del background (Task 4), nunca de un corte.
            break
        }
    }

    // MARK: - La cola, quieta mientras hay un anuncio

    /// Nada de la cola toma el turno mientras un forzado tapa la pantalla. Los
    /// forzados nunca salen con el tutorial (la política), así que la cola no
    /// tenía otra restricción que haya que guardar.
    func holdCelebrationsForAd() {
        celebrations.restrict(to: [])
    }

    func releaseCelebrationsAfterAd() {
        celebrations.restrict(to: nil)
        syncCelebrations()
    }

    // MARK: - Irse y volver

    /// La app se fue, o quedó inactiva viniendo de activa (lo llama el sellado).
    func adsDidEnterBackground() {
        ads?.pacer?.didEnterBackground()
    }

    /// La app volvió: la gracia de los intersticiales arranca de nuevo (el
    /// tiempo afuera no es tiempo de juego). Va ANTES de acreditar el offline.
    func adsDidReturnFromBackground() {
        ads?.pacer?.didReturnFromBackground()
    }
}

extension CelebrationKind {
    /// Si el final de esta celebración —con la cola vacía detrás— es un corte
    /// natural (`celebrationsDrained`). Las grandes sí: el jugador acaba de
    /// mirar algo y todavía no volvió a tocar. Los avisos chicos no, y el
    /// offline tiene su propio corte.
    var endsInNaturalBreak: Bool {
        switch self {
        case .boardCelebration, .chestOpening, .skinAward, .specialDrop, .dailyReward, .careerChoice:
            true
        case .offlineEarnings, .eventBanner, .achievements, .towerNotice, .tutorialTip:
            false
        }
    }
}
```

(Sin `default` en el `switch`, a propósito: un kind nuevo de otra épica no compila hasta que
alguien decida si su final es una pausa. Los de E4b/E5/E6/E8 van según la duda 6.)

- [ ] **Step 4: Los llamadores pasan a ser cortes**

1. `GameState+Menu.swift` (E3b T3):

```swift
    func menuDidClose() async {
        await naturalBreak(.sheetClosed)
    }
```

2. `GameState+Prestige.swift`: el bloque de `:131-143` queda

```swift
        // **El corte más natural del juego** (PLAN-v2 E7): el reset ya ocurrió y
        // la partida nueva todavía no arrancó. Si el cofre de la reencarnación
        // tiene el turno, el corte no muestra nada y el intersticial sale cuando
        // el cofre termine (`celebrationsDrained`).
        scheduleNaturalBreak(.reincarnation)
```

3. `RootView.swift` 🔥, el `onDismiss` del offline (`:291-303`):

```swift
        .sheet(item: offlineRewardBinding, onDismiss: {
            gameState.celebrationFinished(.offlineEarnings)
            // El jugador acaba de cobrar lo de la noche y todavía no volvió al
            // juego: un corte natural. El que duplicó con video tiene la gracia
            // de 90 s de la política.
            gameState.scheduleNaturalBreak(.offlinePopupDismissed)
        }) { reward in
```

4. `GameState+Celebrations.swift`, `publishCelebration()`:

```swift
    private func publishCelebration() {
        let kind = celebrations.current
        let finished = showing
        if showing != kind { showing = kind }
        // El cofre apaga la UI SIEMPRE: su animación ocupa la pantalla entera y el
        // HUD asomando por debajo rompe el telón.
        let hides = (kind == .boardCelebration && boardCelebrationShowsSomethingNew)
            || kind == .chestOpening
        if celebrationHidesUI != hides { celebrationHidesUI = hides }
        // Se fue la última celebración y era de las grandes: corte natural.
        if kind == nil, let finished, finished.endsInNaturalBreak {
            scheduleNaturalBreak(.celebrationsDrained)
        }
    }
```

(Si E1 T9/T10, E4b o E6a T12 dejaron más líneas en `publishCelebration`, se conservan; lo nuevo
es `finished` y el último `if`.)

5. `GameState+Lifecycle.swift` (E1 T8): en la rama que sella (`(_, .background), (.active,
   .inactive)`), después de `seal(now:)`, `adsDidEnterBackground()`; en la rama `(_, .active)`,
   `ads?.sessionResumed()` se reemplaza por `adsDidReturnFromBackground()` **en el mismo lugar,
   antes de `applyOfflineProgressIfNeeded(now:)`** (T4 depende de ese orden). El comentario de
   arriba ("el tiempo en background NO es tiempo de juego…") se conserva.

6. `GameState.swift` 🔥: se borran `isSafeMomentForInterstitial` y `showInterstitialIfAppropriate()`
   con sus docstrings (`:456-486`), y en `flushHUD()` el comentario y la línea `ads?.armIfDue()`
   (`:938-943`). El docstring de `attachAds` (`:448-449`) pasa a decir "Los anuncios: los usan
   los cortes naturales (`+Ads`) y nunca el frame loop".

- [ ] **Step 5: Adiós al reloj de la 1.x**

`AdsCoordinator.swift`: se borran `cadence`, `sessionStartedAt`, `lastInterstitialAt`,
`isInterstitialArmed`, `armIfDue()`, `showInterstitialIfArmed()`, `sessionResumed()` y
`forcedAdFinished()` con sus docstrings (`:64-84`, `:149-154`, `:232-272`), y sus tres llamadas en
`showInterstitial`, `showRewardedInterstitial` y `showAppOpen`. En el docstring de la clase, el
punto 2 de "las dos políticas" (`:17`) pasa a: "2. **Que nunca haya dos anuncios encimados**
(`isPresentingFullScreen`); cuándo puede caer un forzado lo decide `NaturalBreakPolicy` y lo
pide `GameState+Ads`." El `init` sigue con `now:` (lo usa `lastRewardedAt`), pero
`sessionStartedAt = now()` se va. `configure` queda:

```swift
    func configure(flags: FeatureFlags, remoteUnitIDs: FeatureFlags.AdUnitIDs?, removedAds: Bool) async {
        self.removedAds = removedAds
        guard !isConfigured else { return }
        …
    }
```

`AdsProvider.swift`: se borran `RewardedAdsConfig.Interstitial` (`:160-189`), `let interstitial`
y `effectiveInterstitial` (`:193-196`); el docstring del tipo deja de nombrar la cadencia.
`rewarded_ads.json`: se borra la sección `"interstitial"` (`:39-43`) y la coma que la precede.
`FisuEvolutionApp.swift`: la llamada pierde `cadence:`.

- [ ] **Step 6: Verde y oráculo**

Run: Receta R con `NaturalBreakWiringTests`, `MenuSessionTests`, `AdFormatsTests`,
`NaturalBreakPolicyTests`, `GameLoopWiringTests`, `CelebrationWiringTests`, `LifecycleTests` → PASS.
`grep -rn "showInterstitialIfAppropriate\|armIfDue\|isInterstitialArmed\|sessionResumed\|effectiveInterstitial" FisuEvolution FisuEvolutionTests`
→ sin salida. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Ads.swift
git add FisuEvolution/Managers/Ads/AdsCoordinator.swift
git add FisuEvolution/Managers/Ads/AdsProvider.swift
git add FisuEvolution/Resources/Config/rewarded_ads.json
git add FisuEvolution/Game/State/GameState.swift
git add FisuEvolution/Game/State/GameState+Lifecycle.swift
git add FisuEvolution/Game/State/GameState+Prestige.swift
git add FisuEvolution/Game/State/GameState+Menu.swift
git add FisuEvolution/Game/State/GameState+Celebrations.swift
git add FisuEvolution/App/RootView.swift
git add FisuEvolution/App/FisuEvolutionApp.swift
git add FisuEvolutionTests/AdFormatsTests.swift
git add FisuEvolutionTests/MenuSessionTests.swift
git add FisuEvolutionTests/NaturalBreakWiringTests.swift
git diff --cached --stat
git commit -m "feat(anuncios): los cortes naturales — un solo lugar muestra los forzados, y adiós al reloj de la 1.x"
```

---

### Task 3: La pausa publicitaria — la pantalla previa de 5 s, "No, gracias" y el premio que rota

**Objetivo:** cuando a la pausa le toca su turno, aparece un overlay (no una hoja) que dice qué
se gana, cuenta 5 s y ofrece "No, gracias" desde el primer cuadro y "Ver ahora". Al llegar a cero
(o con "Ver ahora") se muestra el intersticial bonificado; si se gana, se entrega el premio de
turno (`rewarded_ads.json` → `adBreak.prizes`: 10 min de producción, ×2 por 5 min, un Paquete),
se avisa y el premio rota. "No, gracias" no castiga: no hay anuncio, cuenta como el corte (la
ventana de 2 min se cierra) y el turno pasa al común. Su anuncio se pide un minuto antes de que le
toque.

**Files:**
- Create: `FisuEvolution/UI/Ads/RewardedInterstitialIntroView.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Game/State/GameState+Ads.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (`adBreakOffer`, `TowerNotice.Kind.rewardGranted`, `flushHUD`)
- Modify: `FisuEvolution/Managers/Ads/NaturalBreakPolicy.swift` (`secondsUntilAlternatingDue`, `AdsPacingState.adBreakPrizeIndex`)
- Modify: `FisuEvolution/Managers/Ads/ForcedAdsPacer.swift`
- Modify: `FisuEvolution/Managers/Ads/AdsProvider.swift` (`RewardedAdsConfig.AdBreak`)
- Modify: `FisuEvolution/Resources/Config/rewarded_ads.json` (`adBreak`)
- Modify: `FisuEvolution/App/RootView.swift` 🔥 (el overlay, `coversBoard`, `TowerNoticeView`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (la pausa ahora)
- Modify: `FisuEvolutionTests/NaturalBreakPolicyTests.swift`
- Create: `FisuEvolutionTests/AdBreakTests.swift`, `FisuEvolutionUITests/AdBreakUITests.swift`
- Strings: el catálogo (dueña en su ola) o `Tools/v2/claves-pendientes/e7b-a-t3.json` (7 claves)

**Interfaces:**
- Consumes: T2; **E4a T8** (`grant(_:multiplier:source:now:)`, `grantableRewardKinds`); **E5a T6**
  (`.package` en `grantableRewardKinds`); **E5b T1** (`RewardCopy.title(_:)`, `RewardCopy.symbol(_:)`);
  **E4b T3** (`coversBoard` en `RootView`); **E1 T14** (`TowerNotice.Kind.rewardCompensated`).
- Produces: `struct AdBreakOffer: Identifiable, Equatable` (`id`, `prize: RewardSpec`,
  `countdownSeconds: Int`); `GameState.adBreakOffer` (observado), `adBreakAccepted() async`,
  `adBreakDeclined()`, `warmForcedAds()`, `static adWarmUpSeconds`, DEBUG `debugPresentAdBreak()`;
  `TowerNotice.Kind.rewardGranted(text: String)`; `RewardedAdsConfig.AdBreak` (`introSeconds`,
  `prizes`, `.default`), `adBreak`, `effectiveAdBreak`; `AdsPacingState.adBreakPrizeIndex`;
  `NaturalBreakPolicy.secondsUntilAlternatingDue(pacing:session:now:)`;
  `ForcedAdsPacer.nextAlternatingFormat`, `secondsUntilAlternatingDue()`, `adBreakPrize(in:)`,
  `advanceAdBreakPrize(count:)`; `RewardedInterstitialIntroView(offer:)`.
- Identificadores: `adbreak.intro` (marcador, valor = segundos que faltan), `adbreak.decline`,
  `adbreak.watch`, `debug.ads.adbreak`.

- [ ] **Step 0: Lo de las otras épicas está**

Run (uno por llamada):

```bash
grep -n "func grant(" FisuEvolution/Game/State/GameState+Rewards.swift
grep -n "\.package" FisuEvolution/Game/State/GameState+Rewards.swift
grep -n "static func title\|static func symbol" FisuEvolution/Managers/RewardCopy.swift
grep -n "private var coversBoard" FisuEvolution/App/RootView.swift
grep -n "rewardCompensated" FisuEvolution/Game/State/GameState.swift FisuEvolution/App/RootView.swift
```

Expected: una o más líneas cada uno. Si `RewardCopy.title`/`symbol` no toman un `RewardSpec`, se
usa la función de `RewardCopy` que diga el premio en una línea y se anota.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/AdBreakTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La pausa publicitaria (PLAN-v2 §2 y E7): pantalla previa, "No, gracias" que
/// no castiga y el premio que rota sólo cuando se gana.
@Suite("La pausa publicitaria", .serialized)
@MainActor
struct AdBreakTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let clock: TestClock
        let pacer: ForcedAdsPacer
        let scratch: ScratchDefaults
    }

    /// Le toca a la pausa primero, con la gracia de arranque ya pasada.
    private func rig() async -> Rig {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        var policy = NaturalBreakPolicy.default
        policy.alternation = [.rewardedInterstitial, .interstitial]
        let pacer = ForcedAdsPacer(policy: policy, store: AdsPacingStore(defaults: scratch.defaults), now: clock.read)
        ads.attachPacer(pacer)
        gameState.attachAds(ads)
        clock.advance(by: 1000)
        return Rig(gameState: gameState, ads: ads, provider: provider, clock: clock, pacer: pacer, scratch: scratch)
    }

    @Test("le toca a la pausa: sale la pantalla previa con el premio de turno, sin anuncio todavía")
    func theIntroComesFirst() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        let offer = try #require(rig.gameState.adBreakOffer)
        let prizes = try #require(rig.gameState.content?.rewardedAds.effectiveAdBreak.prizes)
        #expect(offer.prize == prizes[0])
        #expect(offer.countdownSeconds == 5)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("aceptar muestra el anuncio, entrega el premio, avisa y rota el premio")
    func acceptingPaysAndRotates() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        let before = try #require(rig.gameState.player?.run.coins)
        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()
        #expect(rig.provider.shown == ["rewardedInterstitial"])
        #expect(rig.gameState.adBreakOffer == nil)
        #expect(try #require(rig.gameState.player?.run.coins) > before, "el primero es plata")
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 1)
        guard case .rewardGranted = rig.gameState.towerNotice?.kind else {
            Issue.record("sin aviso del premio")
            return
        }
    }

    @Test("si el anuncio se cierra sin premio, no paga ni rota")
    func noRewardNoPrize() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.provider.earnsReward = false
        let before = try #require(rig.gameState.player?.run.coins)
        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()
        #expect(rig.gameState.player?.run.coins == before)
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 0)
        #expect(rig.pacer.pacing.lastFullScreenAt == rig.clock.read(), "se vio igual: cuenta para los 2 min")
    }

    @Test("«No, gracias» no castiga: sin anuncio, cuenta como el corte y el turno pasa al común")
    func decliningIsFree() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.gameState.adBreakDeclined()
        #expect(rig.gameState.adBreakOffer == nil)
        #expect(rig.provider.shown.isEmpty)
        #expect(rig.pacer.nextAlternatingFormat == .interstitial)
        rig.clock.advance(by: 30)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty, "rechazarla cerró la ventana de 2 min")
    }

    @Test("con la pantalla previa arriba, ningún otro corte muestra nada")
    func theIntroBlocksOtherBreaks() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.clock.advance(by: 200)
        await rig.gameState.naturalBreak(.celebrationsDrained)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("el premio rota en orden y vuelve al primero")
    func prizesRotate() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        let count = try #require(rig.gameState.content?.rewardedAds.effectiveAdBreak.prizes.count)
        for _ in 0..<count {
            rig.pacer.advanceAdBreakPrize(count: count)
        }
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 0)
    }

    @Test("su anuncio se pide cuando le toca y falta menos de un minuto; antes no")
    func warmUpOnlyWhenDue() async {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        var policy = NaturalBreakPolicy.default
        policy.alternation = [.rewardedInterstitial, .interstitial]
        ads.attachPacer(ForcedAdsPacer(policy: policy, store: AdsPacingStore(defaults: scratch.defaults), now: clock.read))
        gameState.attachAds(ads)

        clock.advance(by: 100)
        gameState.warmForcedAds()
        #expect(!provider.preloaded.contains("rewardedInterstitial"), "faltan 80 s para la gracia de arranque")
        clock.advance(by: 30)
        gameState.warmForcedAds()
        #expect(provider.preloaded.contains("rewardedInterstitial"))
    }

    @Test("los premios de la pausa están en el JSON y se pueden entregar")
    func prizesAreGrantable() throws {
        let content = try GameContentLoader.load(from: .main)
        #expect(content.rewardedAds.adBreak != nil, "el respaldo de código es sólo la red")
        let prizes = content.rewardedAds.effectiveAdBreak.prizes
        #expect(prizes.count == 3)
        for prize in prizes {
            try prize.validate()
            #expect(GameState.grantableRewardKinds.contains(prize.kind), "\(prize.kind) no se entrega")
        }
    }
}

private struct ScratchDefaults {
    let name = "e7b-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
```

`NaturalBreakPolicyTests.swift`, en la suite de la política:

```swift
    @Test("cuánto falta para un intersticial: la gracia de arranque y el reloj común, el que llegue último")
    func secondsUntilAlternatingDue() {
        let session = AdsSession(startedAt: Self.t0, secondsAway: nil)
        #expect(Self.policy.secondsUntilAlternatingDue(pacing: AdsPacingState(), session: session, now: Self.t0) == 180)
        var pacing = AdsPacingState()
        pacing.lastFullScreenAt = Self.t0.addingTimeInterval(170)
        #expect(Self.policy.secondsUntilAlternatingDue(pacing: pacing, session: session, now: Self.t0.addingTimeInterval(200)) == 90)
        #expect(Self.policy.secondsUntilAlternatingDue(pacing: pacing, session: session, now: Self.t0.addingTimeInterval(400)) == 0)
    }

    @Test("un estado viejo sin el premio de la pausa arranca en el primero")
    func oldStateHasNoPrizeIndex() throws {
        let old = try JSONDecoder().decode(AdsPacingState.self, from: Data(#"{"sessionNumber": 3}"#.utf8))
        #expect(old.adBreakPrizeIndex == 0)
    }
```

`FisuEvolutionUITests/AdBreakUITests.swift`:

```swift
import XCTest

/// La pausa publicitaria en pantalla (PLAN-v2 E7). Con `--uitest-ad-break` la
/// pausa sale en cada corte; el anuncio lo pone el stub (2 s, y paga).
final class AdBreakUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaPausaSeOfreceYSePuedeRechazar() {
        let app = launch()
        closeAScreen(app)
        let decline = app.buttons["adbreak.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5), "la pantalla previa no apareció al cerrar el menú")
        XCTAssertTrue(app.buttons["adbreak.watch"].exists)
        XCTAssertEqual(app.otherElements["adbreak.intro"].value as? String, "5")
        decline.tap()
        XCTAssertTrue(decline.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tower.notice"].exists, "rechazarla no da ni quita nada")
    }

    func testSiNoSeRechazaElAnuncioPagaSuPremio() {
        let app = launch()
        closeAScreen(app)
        XCTAssertTrue(app.buttons["adbreak.decline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tower.notice"].waitForExistence(timeout: 12), "5 s de cuenta + 2 s de anuncio + el aviso")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-ad-break"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.upgrades"].waitForExistence(timeout: 30))
        return app
    }

    private func closeAScreen(_ app: XCUIApplication) {
        app.buttons["hud.upgrades"].tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/AdBreakTests -only-testing:FisuEvolutionTests/NaturalBreakPolicyTests`.
Expected: no compila (`adBreakOffer`, `effectiveAdBreak`, `adBreakPrizeIndex`,
`secondsUntilAlternatingDue` no existen).

- [ ] **Step 3: La config y el estado**

`AdsProvider.swift`, en `RewardedAdsConfig` (y `import EconomyKit` arriba):

```swift
    /// La pausa publicitaria (PLAN-v2 §2): cuánto dura la pantalla previa y los
    /// premios que rotan. Opcional: un JSON sin la sección usa el default.
    struct AdBreak: Codable, Sendable, Equatable {
        let introSeconds: Int
        let prizes: [RewardSpec]

        static let `default` = AdBreak(
            introSeconds: 5,
            prizes: [
                .coinsSeconds(600),
                .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 300),
                .package(1),
            ]
        )
    }

    let adBreak: AdBreak?

    var effectiveAdBreak: AdBreak { adBreak ?? .default }
```

`rewarded_ads.json`, en la raíz:

```json
  "adBreak": {
    "introSeconds": 5,
    "prizes": [
      {"kind": "coinsSeconds", "seconds": 600},
      {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 300},
      {"kind": "package", "count": 1}
    ]
  }
```

`NaturalBreakPolicy.swift`, en `AdsPacingState` (propiedad, `init(from:)` y nada más: el
`CodingKeys` sintetizado la suma solo):

```swift
    /// Qué premio de la pausa publicitaria toca (índice en `adBreak.prizes`).
    /// Avanza sólo cuando se gana.
    var adBreakPrizeIndex = 0
```

```swift
        adBreakPrizeIndex = try container.decodeIfPresent(Int.self, forKey: .adBreakPrizeIndex) ?? 0
```

y en `NaturalBreakPolicy`, junto a `turnOrder`:

```swift
    /// Cuánto falta para que el reloj común y la gracia de arranque dejen pasar
    /// un intersticial; 0 si ya pueden. No cuenta la gracia post-video: depende
    /// de lo que haga el jugador. Mismo criterio que `hasElapsed` con un reloj
    /// que fue para atrás.
    func secondsUntilAlternatingDue(pacing: AdsPacingState, session: AdsSession, now: Date) -> TimeInterval {
        var due = session.startedAt.addingTimeInterval(graceSecondsAfterLaunch)
        if let last = pacing.lastFullScreenAt,
           !Self.hasElapsed(minSecondsBetweenForced, since: last, now: now) {
            due = max(due, last.addingTimeInterval(minSecondsBetweenForced))
        }
        return max(0, due.timeIntervalSince(now))
    }
```

`ForcedAdsPacer.swift`:

```swift
    /// El intersticial al que le toca: la pausa o el común.
    var nextAlternatingFormat: ForcedAdFormat? {
        policy.turnOrder(pacing).first
    }

    func secondsUntilAlternatingDue() -> TimeInterval {
        policy.secondsUntilAlternatingDue(pacing: pacing, session: session, now: now())
    }

    /// El premio de turno de la pausa publicitaria.
    func adBreakPrize(in prizes: [RewardSpec]) -> RewardSpec? {
        guard !prizes.isEmpty else { return nil }
        return prizes[((pacing.adBreakPrizeIndex % prizes.count) + prizes.count) % prizes.count]
    }

    /// La pausa se ganó: el próximo premio. Se persiste como lo demás.
    func advanceAdBreakPrize(count: Int) {
        guard count > 0 else { return }
        pacing.adBreakPrizeIndex = (pacing.adBreakPrizeIndex + 1) % count
        store.save(pacing)
    }
```

`GameState.swift` 🔥:

1. En `TowerNotice.Kind` (después del `rewardCompensated` de E1 T14):

```swift
            /// Un premio que entregó un anuncio (la pausa publicitaria, E7b).
            case rewardGranted(text: String)
```

2. En las proyecciones observadas:

```swift
    /// La pantalla previa de la pausa publicitaria, mientras está arriba (`+Ads`).
    var adBreakOffer: AdBreakOffer?
```

3. En `flushHUD()`, donde estaba `armIfDue` (T2 lo borró), después de `fireEventIfDue(now:)`:

```swift
        warmForcedAds()
```

- [ ] **Step 4: `GameState+Ads`: la pausa**

Se borra el `.subtracting([.rewardedInterstitial])` del contexto (con su comentario):

```swift
            readyFormats: ads?.readyForcedFormats ?? []
```

y `sheetOpen` suma la pantalla previa:

```swift
            sheetOpen: uiCoversBoard || characterSheet != nil || careerPrompt != nil
                || adBreakOffer != nil || !isSceneActive,
```

En `present(_:pacer:)`, el caso de la pausa:

```swift
        case .rewardedInterstitial:
            presentAdBreak(pacer: pacer)
```

y, en la misma extensión:

```swift
    /// Cuánto antes de su corte se pide el anuncio de la pausa.
    static let adWarmUpSeconds: TimeInterval = 60

    // MARK: - La pausa publicitaria

    private func presentAdBreak(pacer: ForcedAdsPacer) {
        guard adBreakOffer == nil, let content,
              let prize = pacer.adBreakPrize(in: content.rewardedAds.effectiveAdBreak.prizes)
        else { return }
        adBreakOffer = AdBreakOffer(prize: prize, countdownSeconds: content.rewardedAds.effectiveAdBreak.introSeconds)
    }

    /// La cuenta llegó a cero, o el jugador tocó "Ver ahora".
    func adBreakAccepted() async {
        guard let offer = adBreakOffer, let ads, let pacer = ads.pacer else { return }
        adBreakOffer = nil
        // La pantalla previa se va con un fundido; el anuncio entra después.
        if ads.settleDelay > .zero {
            try? await Task.sleep(for: ads.settleDelay)
        }
        holdCelebrationsForAd()
        let earned = await ads.showRewardedInterstitial()
        pacer.recordShown(.rewardedInterstitial)
        releaseCelebrationsAfterAd()
        guard earned, let content else { return }
        grant(offer.prize, source: "adbreak")
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
    }

    // MARK: - El anuncio que viene

    /// A 8 Hz desde `flushHUD`. Si a la pausa le toca y su corte se abre en
    /// menos de `adWarmUpSeconds`, se pide su anuncio: que esté cargado cuando
    /// llegue, sin pedir uno que no se va a mostrar (E7a: la tasa de
    /// presentación de la unidad). El proveedor ignora el pedido si ya hay uno.
    func warmForcedAds() {
        guard let ads, let pacer = ads.pacer, !(player?.meta.removedAds ?? false),
              pacer.nextAlternatingFormat == .rewardedInterstitial,
              pacer.secondsUntilAlternatingDue() <= Self.adWarmUpSeconds
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
}

/// La pantalla previa de la pausa publicitaria: qué se gana y cuánto falta.
struct AdBreakOffer: Identifiable, Equatable {
    let id = UUID()
    let prize: RewardSpec
    let countdownSeconds: Int
}
```

(`AdBreakOffer` va al final del archivo, después de la extensión de `CelebrationKind`.)

- [ ] **Step 5: La pantalla previa**

`FisuEvolution/UI/Ads/RewardedInterstitialIntroView.swift`:

```swift
import EconomyKit
import SwiftUI

/// La pantalla previa de la pausa publicitaria (PLAN-v2 E7; la política de
/// AdMob para el intersticial bonificado): dice qué se gana, cuenta 5 s y deja
/// rechazar desde el primer cuadro.
///
/// ⚠️ No es una hoja: el anuncio que viene después lo presenta el SDK, y una
/// hoja cerrándose debajo pelearía con él por la presentación.
struct RewardedInterstitialIntroView: View {
    let offer: AdBreakOffer
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining: Int

    init(offer: AdBreakOffer) {
        self.offer = offer
        _remaining = State(initialValue: offer.countdownSeconds)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            PanelCard {
                VStack(spacing: Tokens.s12) {
                    PanelTitleBanner(titleKey: "adbreak.title")
                    Text("adbreak.pitch")
                        .font(Tokens.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("PaletteInk"))
                    prizeCard
                    countdown
                    HStack(spacing: Tokens.s8) {
                        ActionPill(titleKey: "adbreak.decline", systemImage: "xmark",
                                   tint: Color("PaletteBlue"), identifier: "adbreak.decline") {
                            gameState.adBreakDeclined()
                        }
                        ActionPill(titleKey: "adbreak.watch", systemImage: "play.fill",
                                   identifier: "adbreak.watch") {
                            Task { await gameState.adBreakAccepted() }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: PlayColumn.tutorialCardMaxWidth)
            .padding(Tokens.s16)
        }
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("adbreak.intro")
                .accessibilityValue(Text(verbatim: String(remaining)))
        )
        .task(id: offer.id) {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
            }
            await gameState.adBreakAccepted()
        }
    }

    private var prizeCard: some View {
        GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s12) {
                Image(systemName: RewardCopy.symbol(offer.prize))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color("PaletteInk"))
                Text(verbatim: RewardCopy.title(offer.prize))
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private var countdown: some View {
        Text(verbatim: String(remaining))
            .font(.system(size: 34, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color("PaletteInk"))
            .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
            .animation(reduceMotion ? nil : .default, value: remaining)
            .frame(width: 64, height: 64)
            .background(Circle().fill(Color("PaletteCream")).overlay(Circle().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 3)))
            .accessibilityLabel(Text("adbreak.countdown.ax \(String(remaining))"))
    }
}
```

`RootView.swift` 🔥:

1. Al final del `ZStack` del `body`, después del `ZStack` del cofre:

```swift
            // La pantalla previa de la pausa publicitaria (E7b): encima de todo,
            // como el cofre, y sin hoja (ver la vista).
            ZStack {
                if let offer = gameState.adBreakOffer {
                    RewardedInterstitialIntroView(offer: offer)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gameState.adBreakOffer?.id)
```

2. `coversBoard` (E4b T3) suma `|| gameState.adBreakOffer != nil`, y junto a los otros `onChange`:

```swift
        .onChange(of: gameState.adBreakOffer?.id) { _, _ in
            gameState.uiCoversBoard = coversBoard
        }
```

3. `TowerNoticeView.messageKey`:

```swift
        case .rewardGranted(let text): "tower.notice.reward_granted \(text)"
```

`DebugPanelView.swift`, la sección "Anuncios" (si T6 ya la creó, se suma el botón adentro):

```swift
                Section("Anuncios") {
                    Button("Pausa publicitaria ahora") {
                        gameState.debugPresentAdBreak()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.ads.adbreak")
                }
```

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e7b-a-t3.json`:

```json
{
  "adbreak.title": {"es": "Pausa publicitaria", "en": "Ad break"},
  "adbreak.pitch": {"es": "Un anuncio cortito y te llevás esto. Si no querés, seguí jugando: no pasa nada.", "en": "One short ad and this is yours. Not in the mood? Keep playing, no harm done."},
  "adbreak.decline": {"es": "No, gracias", "en": "No, thanks"},
  "adbreak.watch": {"es": "Ver ahora", "en": "Watch now"},
  "adbreak.countdown.ax %@": {"es": "El anuncio empieza en %@ segundos", "en": "The ad starts in %@ seconds"},
  "tower.notice.reward_granted %@": {"es": "¡Te llevaste: %@!", "en": "You got: %@!"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e7b-a-t3.json` → `6 claves nuevas`.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `AdBreakTests`, `NaturalBreakPolicyTests`,
`NaturalBreakWiringTests`, `LocalizationCompletenessTests` → PASS; UI con
`-only-testing:FisuEvolutionUITests/AdBreakUITests` → PASS (2), y en el iPhone SE y el iPad Pro
13" con el mismo build → PASS. Capturas al reporte de la pantalla previa en el SE, el 16 Pro y el
iPad, con Reduce Motion prendido y apagado. A mano (DEBUG, sin flags): el panel de debug →
"Pausa publicitaria ahora" → la cuenta, el anuncio de prueba de Google y el aviso.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/Ads/RewardedInterstitialIntroView.swift
git add FisuEvolution/Game/State/GameState+Ads.swift
git add FisuEvolution/Game/State/GameState.swift
git add FisuEvolution/Managers/Ads/NaturalBreakPolicy.swift
git add FisuEvolution/Managers/Ads/ForcedAdsPacer.swift
git add FisuEvolution/Managers/Ads/AdsProvider.swift
git add FisuEvolution/Resources/Config/rewarded_ads.json
git add FisuEvolution/App/RootView.swift
git add FisuEvolution/UI/DebugPanelView.swift
git add FisuEvolutionTests/NaturalBreakPolicyTests.swift
git add FisuEvolutionTests/AdBreakTests.swift
git add FisuEvolutionUITests/AdBreakUITests.swift
git add Tools/v2/claves-pendientes/e7b-a-t3.json
git diff --cached --stat
git commit -m "feat(anuncios): la pausa publicitaria — pantalla previa de 5 s, «No, gracias» sin castigo y el premio que rota"
```

(Si la ola la hace dueña del catálogo: `git add FisuEvolution/Resources/Localizable.xcstrings` y
`git rm` del JSON, en vez de agregarlo.)

---

### Task 4: El app open al volver — se pide al irse, sale antes del popup offline

**Objetivo:** al irse, si en la próxima vuelta podría salir un app open (prendido y desde la
sesión mínima), se pide su anuncio. Al volver se decide **antes** de acreditar el offline: si
sale, la cola queda retenida mientras está en pantalla, y el popup de ganancias y el diario
aparecen después. Nunca en el primer arranque, nunca con una vuelta corta (el centro de
notificaciones), nunca con `remove_ads`.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Ads.swift`
- Modify: `FisuEvolution/Managers/Ads/ForcedAdsPacer.swift`
- Create: `FisuEvolutionTests/AppOpenWiringTests.swift`

**Interfaces:**
- Consumes: T2 (`adsDidEnterBackground`, `adsDidReturnFromBackground`, el orden en `+Lifecycle`);
  **E1 T8** (`handleScenePhase(from:to:now:)`).
- Produces: `ForcedAdsPacer.couldShowAppOpenOnReturn: Bool`; los dos hooks de `+Ads` con el app open.

- [ ] **Step 0: El orden en `+Lifecycle` es el de T2**

Run: `grep -n "adsDidReturnFromBackground\|applyOfflineProgressIfNeeded" FisuEvolution/Game/State/GameState+Lifecycle.swift`
Expected: `adsDidReturnFromBackground()` aparece **antes** que `applyOfflineProgressIfNeeded(now:)`
en la rama `.active`. Si no, `NEEDS_CONTEXT` (el orden es el contrato de esta tarea).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/AppOpenWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El app open al volver (PLAN-v2 §2): ≥ 3 min afuera, desde la 2ª sesión, y
/// antes del popup offline, nunca debajo.
@Suite("El app open al volver", .serialized)
@MainActor
struct AppOpenWiringTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let clock: TestClock
        let pacer: ForcedAdsPacer
        let scratch: ScratchDefaults
    }

    /// Un juego que produce (así hay popup offline), con el app open prendido,
    /// en la sesión `session`.
    private func rig(session: Int) async throws -> Rig {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        let store = AdsPacingStore(defaults: scratch.defaults)
        let policy = NaturalBreakPolicy.default.with(appOpenEnabled: true)
        var pacer = ForcedAdsPacer(policy: policy, store: store, now: clock.read)
        for _ in 1..<max(1, session) {
            pacer = ForcedAdsPacer(policy: policy, store: store, now: clock.read)
        }
        ads.attachPacer(pacer)
        gameState.attachAds(ads)
        return Rig(gameState: gameState, ads: ads, provider: provider, clock: clock, pacer: pacer, scratch: scratch)
    }

    /// Irse y volver como lo hace iOS, con `away` segundos afuera.
    private func leaveAndReturn(_ rig: Rig, away: TimeInterval) {
        let t0 = Date().timeIntervalSince1970
        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: t0 + 1)
        rig.clock.advance(by: away)
        rig.gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + away)
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + away + 1)
    }

    @Test("al irse se pide; al volver tras 10 min sale, y el popup offline espera a que se cierre")
    func appOpenBeforeTheOfflinePopup() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        rig.provider.holdsOpen = true
        leaveAndReturn(rig, away: 600)
        #expect(rig.provider.preloaded.contains("appOpen"))
        await rig.provider.waitUntilShowing()
        #expect(rig.provider.shown == ["appOpen"])
        #expect(rig.gameState.showing == nil, "el popup offline no se presenta debajo del anuncio")
        rig.provider.closeCurrentAd()
        await rig.ads.naturalBreakTask?.value
        #expect(rig.gameState.showing == .offlineEarnings)
        #expect(rig.pacer.pacing.lastAppOpenAt == rig.clock.read())
    }

    @Test("en la primera sesión no se pide ni sale")
    func notOnTheFirstSession() async throws {
        let rig = try await rig(session: 1)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(!rig.provider.preloaded.contains("appOpen"))
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("una vuelta corta (el centro de notificaciones) no da app open")
    func notAfterAShortAbsence() async throws {
        let rig = try await rig(session: 3)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 60)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("con remove_ads no se pide ni sale")
    func notWithRemovedAds() async throws {
        let rig = try await rig(session: 3)
        defer { rig.scratch.clear() }
        rig.gameState.player?.meta.removedAds = true
        rig.ads.setRemovedAds(true)
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(!rig.provider.preloaded.contains("appOpen"))
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("dos vueltas en 20 min: un solo app open")
    func oneEveryTwentyMinutes() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        leaveAndReturn(rig, away: 300)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown == ["appOpen"])
    }
}

private struct ScratchDefaults {
    let name = "e7b-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/AppOpenWiringTests`.
Expected: `appOpenBeforeTheOfflinePopup` y `oneEveryTwentyMinutes` FAIL (nadie precarga ni decide
el app open); los otros tres pasan (no sale nada todavía).

- [ ] **Step 3: El app open**

`ForcedAdsPacer.swift`:

```swift
    /// Si en la próxima vuelta podría salir un app open: prendido y desde la
    /// sesión mínima. Lo demás (la ausencia, el cupo) se sabe recién al volver.
    var couldShowAppOpenOnReturn: Bool {
        policy.enabledFormats.contains(.appOpen) && pacing.sessionNumber >= policy.appOpenMinSessionNumber
    }
```

`GameState+Ads.swift`, los dos hooks de T2 quedan:

```swift
    /// La app se fue, o quedó inactiva viniendo de activa. Si a la vuelta
    /// podría salir un app open, se pide ahora (E7a: al volver es tarde para
    /// cargarlo, y no se pide para quien no lo va a ver).
    func adsDidEnterBackground() {
        guard let ads, let pacer = ads.pacer else { return }
        pacer.didEnterBackground()
        if pacer.couldShowAppOpenOnReturn { ads.preloadAppOpen() }
    }

    /// La app volvió. La gracia de los intersticiales arranca de nuevo, y el
    /// app open se decide ACÁ, antes de acreditar el offline: si sale, la cola
    /// queda retenida y el popup de ganancias y el diario aparecen después del
    /// anuncio, no debajo.
    func adsDidReturnFromBackground() {
        guard let ads, let pacer = ads.pacer else { return }
        pacer.didReturnFromBackground()
        guard phase == .ready, ads.naturalBreakTask == nil,
              case .show(.appOpen) = pacer.decide(.returnFromBackground, context: naturalBreakContext)
        else { return }
        holdCelebrationsForAd()
        ads.naturalBreakTask = Task { [weak self] in
            await ads.showAppOpen()
            pacer.recordShown(.appOpen)
            self?.releaseCelebrationsAfterAd()
            self?.ads?.naturalBreakTask = nil
        }
    }
```

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `AppOpenWiringTests`, `NaturalBreakWiringTests`, `LifecycleTests`,
`OfflinePopupTests` → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`. A mano en el simulador
(DEBUG, la unidad de prueba de Google, con `ads.json` local con `"appOpen": true` **sin
commitearlo**): segundo arranque, Home, 3 min, volver → app open de prueba y después el popup
offline. Captura al reporte.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Ads.swift
git add FisuEvolution/Managers/Ads/ForcedAdsPacer.swift
git add FisuEvolutionTests/AppOpenWiringTests.swift
git diff --cached --stat
git commit -m "feat(anuncios): el app open al volver — se pide al irse y sale antes del popup offline"
```

---

### Task 5: "Opciones de privacidad" en Ajustes (UMP)

**Objetivo:** la fila que exige la UE para revisar el consentimiento (bug adicional 10 de
PLAN-v2 §3): una sección "Privacidad" en Ajustes con "Opciones de privacidad", visible sólo
donde UMP dice que hace falta (`AdsConsent.showsPrivacyOptions`), que abre el formulario de
Google.

**Files:**
- Modify: `FisuEvolution/Managers/Ads/AdsConsent.swift` (`privacyRowVisible`)
- Modify: `FisuEvolution/UI/Menu/SettingsView.swift` 🔥
- Create: `FisuEvolutionTests/PrivacyRowTests.swift`, `FisuEvolutionUITests/SettingsPrivacyUITests.swift`
- Strings: el catálogo (dueña) o `Tools/v2/claves-pendientes/e7b-a-t5.json` (3 claves)

**Interfaces:**
- Consumes: `AdsConsent.showsPrivacyOptions`, `presentPrivacyOptions()` (`AdsConsent.swift:68-76`);
  las secciones de E11 T4.
- Produces: `AdsConsent.privacyRowVisible: Bool`,
  `nonisolated static func AdsConsent.privacyRowVisible(required:arguments:) -> Bool`.
- Identificadores: `settings.privacy.options`.

- [ ] **Step 0: E11 cerró Ajustes**

Run: `grep -n "purchasesSection\|legalSection" FisuEvolution/UI/Menu/SettingsView.swift`
Expected: las dos, en el `VStack` del `body`. Si E9 ya sumó su zona de peligro, la sección nueva va
**antes** de ella.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PrivacyRowTests.swift`:

```swift
import Testing
@testable import FisuEvolution

@Suite("La fila de privacidad de UMP")
struct PrivacyRowTests {
    @Test("se ve sólo si UMP la pide, o si el test de UI la fuerza")
    func visibility() {
        #expect(AdsConsent.privacyRowVisible(required: true, arguments: []))
        #expect(!AdsConsent.privacyRowVisible(required: false, arguments: []))
        #expect(AdsConsent.privacyRowVisible(required: false, arguments: ["--uitest-privacy-options"]))
    }
}
```

`FisuEvolutionUITests/SettingsPrivacyUITests.swift`:

```swift
import XCTest

/// "Opciones de privacidad" (PLAN-v2 E7, UMP): sólo donde hace falta. Bajo UI
/// tests el SDK no arranca y UMP no sabe nada, así que la fila se fuerza con
/// `--uitest-privacy-options`.
final class SettingsPrivacyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaFilaSaleCuandoUMPLaPide() {
        let app = openSettings(extra: ["--uitest-privacy-options"])
        XCTAssertTrue(app.buttons["settings.privacy.options"].waitForExistence(timeout: 5))
    }

    func testSinUMPNoHayFila() {
        let app = openSettings(extra: [])
        XCTAssertTrue(app.buttons["settings.restore"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.privacy.options"].exists)
    }

    private func openSettings(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
        app.launch()
        let menu = app.buttons["hud.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        let settings = app.buttons["menu.card.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        return app
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/PrivacyRowTests`.
Expected: no compila (`privacyRowVisible`).

- [ ] **Step 3: La regla y la fila**

`AdsConsent.swift`, después de `showsPrivacyOptions`:

```swift
    /// Si Ajustes muestra "Opciones de privacidad".
    static var privacyRowVisible: Bool {
        privacyRowVisible(required: showsPrivacyOptions, arguments: ProcessInfo.processInfo.arguments)
    }

    nonisolated static func privacyRowVisible(required: Bool, arguments: [String]) -> Bool {
        #if DEBUG
        if arguments.contains("--uitest-privacy-options") { return true }
        #endif
        return required
    }
```

`SettingsView.swift` 🔥: `@State private var showsPrivacyRow = false` junto a los otros `@State`;
`privacySection` en el `VStack` del `body` después de `purchasesSection`; en el `ScrollView`,
`.onAppear { showsPrivacyRow = AdsConsent.privacyRowVisible }` (si ya hay un `onAppear`, la línea
va adentro); y la sección, después de `// MARK: Compras`:

```swift
    // MARK: Privacidad

    /// "Opciones de privacidad" de UMP (PLAN-v2 §3, bug 10): la UE exige poder
    /// revisar el consentimiento, no sólo darlo una vez. Sale sólo donde UMP
    /// dice que hace falta.
    @ViewBuilder private var privacySection: some View {
        if showsPrivacyRow {
            VStack(spacing: Tokens.s12) {
                SectionHeader("settings.section.privacy")
                GameCard(style: .normal) {
                    VStack(spacing: Tokens.s8) {
                        Text("settings.privacy.hint")
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk").opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ActionPill(
                            titleKey: "settings.privacy.options",
                            systemImage: "hand.raised.fill",
                            tint: Color("PaletteBlue"),
                            identifier: "settings.privacy.options"
                        ) {
                            Task { await AdsConsent.presentPrivacyOptions() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
```

`Tools/v2/claves-pendientes/e7b-a-t5.json`:

```json
{
  "settings.section.privacy": {"es": "Privacidad", "en": "Privacy"},
  "settings.privacy.hint": {"es": "Revisá o cambiá cómo usan tus datos los anuncios.", "en": "Review or change how ads use your data."},
  "settings.privacy.options": {"es": "Opciones de privacidad", "en": "Privacy options"}
}
```

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `PrivacyRowTests`, `SettingsPersistenceTests`, `LocalizationCompletenessTests`
→ PASS; UI con `-only-testing:FisuEvolutionUITests/SettingsPrivacyUITests` → PASS (2), y
`LocalizationLayoutUITests` en el SE (E3a T12) sigue verde. `Tools/v2/oraculo.sh rapido` → `VERDE`.
A mano en un iPhone real o un simulador con la región en España y el SDK real (Release o un
dispositivo de prueba registrado): la fila aparece y abre el formulario de Google.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/Ads/AdsConsent.swift
git add FisuEvolution/UI/Menu/SettingsView.swift
git add FisuEvolutionTests/PrivacyRowTests.swift
git add FisuEvolutionUITests/SettingsPrivacyUITests.swift
git add Tools/v2/claves-pendientes/e7b-a-t5.json
git diff --cached --stat
git commit -m "feat(anuncios): «Opciones de privacidad» en Ajustes, sólo donde UMP la pide"
```

---

### Task 6: La mediación — los cuatro adaptadores, SKAdNetwork y el Ad Inspector

**Objetivo:** que AppLovin, Unity Ads, Mintegral y Meta pujen en AdMob: sus cuatro paquetes de
adaptador en `project.yml` (cada uno trae el SDK de su red), `-ObjC`, la unión de los
SKAdNetwork IDs de las cuatro redes y Google en el `Info.plist`, el Ad Inspector en el panel de
debug, y lo que declaran los SDK anotado para App Privacy. Si una red no sirve un formato (la
pausa: sólo Meta; el app open: sólo Mintegral, según E7a), ese formato queda en AdMob y lo
demás: no hay código por formato, lo decide el grupo de mediación en la consola (E10).

**Files:**
- Modify: `project.yml` 🔥 (`packages`, dependencias del target, `OTHER_LDFLAGS`)
- Modify: `FisuEvolution/Info.plist` (`SKAdNetworkItems`)
- Create: `Tools/v2/skadnetwork.py`, `Tools/v2/test_skadnetwork.py`
- Modify: `FisuEvolution/Managers/Ads/AdMobAdsProvider.swift` (`AdInspector`, DEBUG)
- Modify: `FisuEvolution/UI/DebugPanelView.swift`
- Create: `FisuEvolutionTests/MediationContractTests.swift`
- Modify: `Distribution/setup-v2-asc-admob-mediacion.md` (lo que declaran los SDK)

**Interfaces:**
- Produces: `Tools/v2/skadnetwork.py actualizar | verificar`; en Python `ids_en(texto)`,
  `union(actuales, nuevas)`, `reescribir(plist, ids)`; DEBUG `enum AdInspector { static func present() }`.
- Identificadores: `debug.ads.inspector`.

- [ ] **Step 0: Verificar URL, versión y producto de cada adaptador (no inventar)**

La tabla de E7a (`Docs/SESION-2026-10-06-v2-e7a-anuncios.md`, "Mediación") es del 2026-10-06:
**se verifica al implementar**. Para cada red, uno por llamada:

```bash
git ls-remote --tags https://github.com/googleads/googleads-mobile-ios-mediation-applovin.git
curl -s https://raw.githubusercontent.com/googleads/googleads-mobile-ios-mediation-applovin/main/Package.swift
```

(y lo mismo con `-unity`, `-mintegral` y `-meta`). Anotar en el reporte, por red: el tag más
nuevo, si es semver válido (semver **no admite ceros a la izquierda**: `4.21.000` no lo es, y SPM
ignora ese tag; en ese caso se fija por `revision:` con el SHA del tag), el nombre del producto
(`AppLovinAdapterTarget`, `UnityAdapterTarget`, `MintegralAdapterTarget`, `MetaAdapterTarget` según
E7a), el rango de GMA que pide (tiene que incluir el que resuelve el proyecto, `from: 13.9.0`) y
el iOS mínimo (≤ 18). Y las tres listas de SKAdNetwork responden:

```bash
curl -sI https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json
curl -sI https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json
curl -sI https://dev.mintegral.com/skadnetworkids.json
```

Si una URL o un producto cambió, se usa el vigente y se anota; si una red ya no tiene adaptador
SPM, `NEEDS_CONTEXT` con lo encontrado.

- [ ] **Step 1: Los tests, en rojo**

`Tools/v2/test_skadnetwork.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import skadnetwork  # noqa: E402

PLIST = """<plist version="1.0">
<dict>
\t<!-- un comentario que no se puede perder -->
\t<key>SKAdNetworkItems</key>
\t<array>
\t\t<dict>
\t\t\t<key>SKAdNetworkIdentifier</key>
\t\t\t<string>cstr6suwn9.skadnetwork</string>
\t\t</dict>
\t</array>
</dict>
</plist>
"""


class SKAdNetworkTests(unittest.TestCase):
    def test_saca_los_ids_de_cualquier_forma_y_en_minuscula(self):
        texto = '{"ids": [{"skadnetwork_id": "V9WTTPBFK9.skadnetwork"}], "x": "n38lu8286q.skadnetwork"}'
        self.assertEqual(skadnetwork.ids_en(texto), ["v9wttpbfk9.skadnetwork", "n38lu8286q.skadnetwork"])

    def test_la_union_conserva_el_orden_de_los_que_estaban_y_ordena_los_nuevos(self):
        self.assertEqual(
            skadnetwork.union(["b.skadnetwork", "a.skadnetwork"], ["c.skadnetwork", "a.skadnetwork", "0.skadnetwork"]),
            ["b.skadnetwork", "a.skadnetwork", "0.skadnetwork", "c.skadnetwork"],
        )

    def test_reescribe_solo_el_array_y_es_idempotente(self):
        ids = ["cstr6suwn9.skadnetwork", "v9wttpbfk9.skadnetwork"]
        una = skadnetwork.reescribir(PLIST, ids)
        self.assertIn("<!-- un comentario que no se puede perder -->", una)
        self.assertEqual(skadnetwork.ids_en(una), ids)
        self.assertEqual(skadnetwork.reescribir(una, ids), una)


if __name__ == "__main__":
    unittest.main()
```

`FisuEvolutionTests/MediationContractTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

/// La mediación está en el binario (PLAN-v2 E7): los cuatro adaptadores
/// enlazados y la unión de SKAdNetwork en el `Info.plist`. Sin los IDs, la
/// atribución no funciona y el inventario que paga por instalación no puja:
/// no falla nada, sólo se factura menos.
@Suite("La mediación está en el binario")
struct MediationContractTests {
    private var skadIDs: [String] {
        let items = Bundle.main.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [[String: String]] ?? []
        return items.compactMap { $0["SKAdNetworkIdentifier"] }
    }

    @Test("SKAdNetwork: Google y las cuatro redes, en minúscula y sin repetidos")
    func skadNetworkUnion() {
        let ids = skadIDs
        #expect(ids.count >= 150, "\(ids.count) IDs: la unión de E7a eran 156")
        #expect(Set(ids).count == ids.count, "hay repetidos")
        #expect(ids.allSatisfy { $0 == $0.lowercased() && $0.hasSuffix(".skadnetwork") })
        for required in ["cstr6suwn9.skadnetwork", "v9wttpbfk9.skadnetwork", "n38lu8286q.skadnetwork"] {
            #expect(ids.contains(required), "falta \(required)")
        }
    }

    /// Los nombres son los de los headers de cada adaptador: verificarlos al
    /// agregar los paquetes (Step 0) y corregir esta lista si cambiaron.
    @Test("los cuatro adaptadores están enlazados", arguments: [
        "GADMediationAdapterAppLovin",
        "GADMediationAdapterUnity",
        "GADMediationAdapterMintegral",
        "GADMediationAdapterFacebook",
    ])
    func adapterIsLinked(className: String) {
        #expect(NSClassFromString(className) != nil, "\(className) no está en el binario: falta el paquete o -ObjC")
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `python3 Tools/v2/test_skadnetwork.py` → error (`skadnetwork` no existe).
Receta R con `-only-testing:FisuEvolutionTests/MediationContractTests` → FAIL: 50 IDs y ningún
adaptador.

- [ ] **Step 3: La herramienta de SKAdNetwork**

`Tools/v2/skadnetwork.py`:

```python
#!/usr/bin/env python3
"""La unión de SKAdNetwork de la mediación en el Info.plist (PLAN-v2 E7).

Baja las listas oficiales de AppLovin, Unity y Mintegral (Meta son dos IDs
fijos), las une con las que ya trae el Info.plist (las de Google) y reescribe
SÓLO el <array> de SKAdNetworkItems: los comentarios del archivo se conservan.
Las que estaban quedan primero y en su orden; las nuevas, ordenadas.

    Tools/v2/skadnetwork.py actualizar   # baja, une y escribe
    Tools/v2/skadnetwork.py verificar    # exit 1 si al Info.plist le falta alguna
"""
import re
import sys
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
INFO_PLIST = RAIZ / "FisuEvolution" / "Info.plist"
LISTAS = {
    "AppLovin": "https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json",
    "Unity": "https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json",
    "Mintegral": "https://dev.mintegral.com/skadnetworkids.json",
}
META = ["v9wttpbfk9.skadnetwork", "n38lu8286q.skadnetwork"]
ID = re.compile(r"[a-z0-9]{10}\.skadnetwork", re.IGNORECASE)
BLOQUE = re.compile(r"(<key>SKAdNetworkItems</key>\s*<array>)(.*?)(\n\t</array>)", re.DOTALL)


def ids_en(texto):
    """Los IDs que aparezcan, en minúscula y sin repetir: la forma de cada
    lista cambia de red en red, el ID no."""
    vistos = []
    for encontrado in ID.findall(texto):
        normal = encontrado.lower()
        if normal not in vistos:
            vistos.append(normal)
    return vistos


def union(actuales, nuevas):
    return list(actuales) + sorted(set(nuevas) - set(actuales))


def reescribir(plist, ids):
    encontrado = BLOQUE.search(plist)
    if not encontrado:
        raise SystemExit("no encontré <key>SKAdNetworkItems</key> en el Info.plist")
    cuerpo = "".join(
        f"\n\t\t<dict>\n\t\t\t<key>SKAdNetworkIdentifier</key>\n\t\t\t<string>{i}</string>\n\t\t</dict>"
        for i in ids
    )
    return plist[: encontrado.start(2)] + cuerpo + plist[encontrado.end(2):]


def bajar(url):
    with urllib.request.urlopen(url, timeout=20) as respuesta:
        return respuesta.read().decode("utf-8", errors="replace")


def deseados(plist):
    nuevas = list(META)
    for red, url in LISTAS.items():
        de_la_red = ids_en(bajar(url))
        if not de_la_red:
            raise SystemExit(f"{red}: la lista vino vacía ({url})")
        print(f"{red}: {len(de_la_red)} IDs")
        nuevas += de_la_red
    return union(ids_en(plist), nuevas)


def main(argv):
    if len(argv) != 2 or argv[1] not in ("actualizar", "verificar"):
        raise SystemExit(__doc__)
    plist = INFO_PLIST.read_text(encoding="utf-8")
    ids = deseados(plist)
    if argv[1] == "verificar":
        faltan = sorted(set(ids) - set(ids_en(plist)))
        print(f"faltan {len(faltan)}" if faltan else f"completo: {len(ids)} IDs")
        return 1 if faltan else 0
    INFO_PLIST.write_text(reescribir(plist, ids), encoding="utf-8")
    print(f"Info.plist: {len(ids)} IDs")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Run: `python3 Tools/v2/test_skadnetwork.py` → OK (3). Después
`python3 Tools/v2/skadnetwork.py actualizar` → imprime los conteos por red y el total (E7a midió
156); `python3 Tools/v2/skadnetwork.py verificar` → `completo`. El comentario del `Info.plist`
sobre `SKAdNetworkItems` pasa a decir: "La unión de Google y las cuatro redes de mediación
(AppLovin, Unity, Mintegral y Meta), escrita por `Tools/v2/skadnetwork.py actualizar`. [CORRERLO DE
NUEVO EN CADA ACTUALIZACIÓN DE UN ADAPTADOR]: las listas crecen." `plutil -lint FisuEvolution/Info.plist` → OK.

- [ ] **Step 4: Los paquetes y `-ObjC`**

`project.yml` 🔥, en `packages` (con los valores verificados en el Step 0; los de abajo son los de
E7a y **no se copian sin verificar**):

```yaml
  # La mediación (PLAN-v2 E7; investigada en E7a, verificada al agregarla).
  # Un paquete de Google por red, y cada uno fija el SDK de su red con
  # `exact:`: NO se suma el paquete de la red aparte, o SPM no resuelve. Un tag
  # con ceros a la izquierda (4.21.000) no es semver: SPM lo ignora, y por eso
  # ésos van por `revision:`.
  GoogleMobileAdsMediationAppLovin:
    url: https://github.com/googleads/googleads-mobile-ios-mediation-applovin.git
    exactVersion: 13.6.400
  GoogleMobileAdsMediationUnity:
    url: https://github.com/googleads/googleads-mobile-ios-mediation-unity.git
    revision: <SHA del tag verificado>
  GoogleMobileAdsMediationMintegral:
    url: https://github.com/googleads/googleads-mobile-ios-mediation-mintegral.git
    exactVersion: 8.1.700
  GoogleMobileAdsMediationMeta:
    url: https://github.com/googleads/googleads-mobile-ios-mediation-meta.git
    revision: <SHA del tag verificado>
```

En `dependencies` del target, después de `GoogleMobileAds`:

```yaml
      - package: GoogleMobileAdsMediationAppLovin
        product: AppLovinAdapterTarget
      - package: GoogleMobileAdsMediationUnity
        product: UnityAdapterTarget
      - package: GoogleMobileAdsMediationMintegral
        product: MintegralAdapterTarget
      - package: GoogleMobileAdsMediationMeta
        product: MetaAdapterTarget
```

y en `settings.base` del target (no en el de tests):

```yaml
        # AppLovin lo pide (sus categorías de Objective-C no se enlazan sin
        # esto) y el test de contrato de la mediación lo vigila.
        OTHER_LDFLAGS: -ObjC
```

El comentario de `packages` que dice "ÚNICA dependencia externa del proyecto" (`:13-15`) pasa a
"Las únicas dependencias externas son las de anuncios: el SDK de Google y sus adaptadores de
mediación (…)".

Run: `/opt/homebrew/bin/xcodegen generate` y
`xcodebuild -resolvePackageDependencies -scheme FisuEvolution -derivedDataPath "$WT/build/DD-e7b"`
→ resuelve sin conflictos de GMA. Si dos adaptadores piden rangos de GMA incompatibles, se sube el
`from:` de `GoogleMobileAds` al mínimo común y se anota.

- [ ] **Step 5: El Ad Inspector**

`AdMobAdsProvider.swift`, al final:

```swift
#if DEBUG
/// El Ad Inspector de AdMob (PLAN-v2 E7): qué red sirvió cada anuncio y por qué
/// otra no llenó. Sólo para el panel de debug, y sólo en un dispositivo de
/// prueba (el simulador lo es).
@MainActor
enum AdInspector {
    static func present() {
        MobileAds.shared.presentAdInspector(from: nil) { error in
            if let error {
                Log.ads.error("ad inspector: \(error.localizedDescription)")
            }
        }
    }
}
#endif
```

(La firma es la de GMA 13 en Swift; **verificarla** en el header `GADMobileAds.h`
—`presentAdInspectorFromViewController:completionHandler:`— de la versión que resolvió el Step 4.)

`DebugPanelView.swift`, sección "Anuncios" (si T3 ya la creó, el botón va adentro):

```swift
                Section("Anuncios") {
                    Button("Ad Inspector (mediación)") {
                        AdInspector.present()
                    }
                    .accessibilityIdentifier("debug.ads.inspector")
                }
```

- [ ] **Step 6: Lo que declaran los SDK**

Run (uno por llamada):

```bash
find "$WT/build/DD-e7b/SourcePackages/artifacts" -name PrivacyInfo.xcprivacy
plutil -p <cada ruta que listó el anterior>
```

En `Distribution/setup-v2-asc-admob-mediacion.md`, sección de App Privacy, una tabla por SDK con
`NSPrivacyTracking`, `NSPrivacyTrackingDomains` y `NSPrivacyCollectedDataTypes` (lo que E7a dejó
**NO VERIFICADO**, ahora leído del binario), y la línea: "El `PrivacyInfo.xcprivacy` de la app
describe el código de la app (que no rastrea) y no cambia; App Privacy en App Store Connect
declara la unión de esta tabla (E10)". Ver la duda 4.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: Receta R con `MediationContractTests`, `AdFormatsTests`, `AdsRemoteConfigTests`,
`GameContentValidationTests` → PASS. A mano en el simulador (DEBUG): panel de debug → "Ad
Inspector" abre el inspector y lista las cuatro redes en la unidad de Regalos (sin cuenta de las
redes, "no configurada" es lo esperado). `Tools/v2/oraculo.sh completo` → `VERDE`, **con el paso
`release` verde** (es el que enlaza `-ObjC` en Release) y el tamaño del `.app` anotado en el
reporte.

- [ ] **Step 8: Commit**

```bash
git add project.yml
git add FisuEvolution/Info.plist
git add Tools/v2/skadnetwork.py
git add Tools/v2/test_skadnetwork.py
git add FisuEvolution/Managers/Ads/AdMobAdsProvider.swift
git add FisuEvolution/UI/DebugPanelView.swift
git add FisuEvolutionTests/MediationContractTests.swift
git add Distribution/setup-v2-asc-admob-mediacion.md
git diff --cached --stat
git commit -m "chore(mediacion): AppLovin, Unity, Mintegral y Meta en el binario, la unión de SKAdNetwork y el Ad Inspector"
```

---

### Task 7: Cierre de E7b-a (controlador)

- [ ] **Step 1: Oráculo y capturas**

`Tools/v2/oraculo.sh completo` sobre la punta de la épica → `VERDE`. Capturas al reporte: la
pantalla previa en el SE, el 16 Pro y el iPad 13"; Ajustes con la fila de privacidad
(`--uitest-privacy-options`); el Ad Inspector.

- [ ] **Step 2: Escenarios de PLAN-v2 §8 que toca esta mitad**

1. Anuncios con IDs de prueba + el Ad Inspector para la mediación.
2. Config remota caída → rige el respaldo del bundle (`AdsRemoteConfigTests`, y a mano en modo
   avión: el juego arranca igual).
3. Un intersticial y una pausa alternados en cortes reales (cerrar el menú, el popup offline,
   reencarnar), nunca encima de una celebración.
4. `remove_ads` (comprado en el sandbox) apaga los tres forzados en la misma sesión.

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e7b.md`: la tabla por tarea con su commit, lo medido y el porqué de
   cada default de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: "E7b-a — los forzados en marcha": un pacer por proceso con la config del sitio, los
     cortes naturales como único camino, la pausa con su pantalla previa, el app open antes del
     offline, UMP, la mediación.
   - **§5**: los defaults que el dueño no cambió (rechazar la pausa cuenta como el corte; los IDs
     del sitio mandan en Release; `celebrationsDrained` sólo tras las celebraciones grandes).
   - **§7** (trampas nuevas): "el SDK presenta un modal: con un forzado en pantalla la cola de
     celebraciones queda retenida, si no la hoja que toma el turno no se presenta nunca"; "ningún
     forzado antes de `settleDelay` desde el corte: la hoja que se cierra y el anuncio pelean la
     presentación"; "el app open se decide antes de acreditar el offline"; "un tag de adaptador con
     ceros a la izquierda no es semver: SPM lo ignora"; las que aparezcan.
   - **§9**: este plan y la sesión.
3. `Docs/PLAN-v2.md`: E7 marcada en curso (E7b-a hecha), con los desvíos que el dueño confirmó.

---

## Para el dueño / dudas

Cosas que PLAN-v2 deja abiertas o que el código contradice. **Ninguna frena**: la ejecución sigue
con el default anotado hasta que el dueño diga otra cosa.

1. **Rechazar la pausa cuenta como el corte.** "No, gracias" no muestra nada ni quita nada, pero
   cierra la ventana de 2 min y pasa el turno al intersticial común. Si no contara, el jugador que
   la rechaza la vería ofrecida otra vez al cerrar la próxima hoja, diez segundos después.
   **Default:** cuenta (E7a lo dejó para E7b).
2. **La pausa avisa su premio con un aviso de la torre** ("¡Te llevaste: 10 min de producción!"),
   y el premio rota sólo cuando se gana. **Default:** así; los tres premios y los 5 s viven en
   `rewarded_ads.json` (`adBreak`), no en la config remota (son contenido del juego, no cadencia).
3. **En Release los IDs de anuncio salen de la config remota** (caché o respaldo), y los de
   `feature_flags.json` son el respaldo del respaldo. Un test ya exige que los dos digan lo mismo
   al embarcar. Un ID nuevo publicado rige desde el **próximo** arranque (el proveedor ya está
   creado); la cadencia y los interruptores, en el acto. **Default:** así.
4. **App Privacy con la mediación.** Unity, Mintegral y Meta declaran datos usados para
   rastrear: App Store Connect tiene que declarar "Data Used to Track You" (E10). El
   `PrivacyInfo.xcprivacy` de la **app** sigue diciendo `NSPrivacyTracking = false` porque describe
   el código propio; los SDK traen el suyo y Xcode los suma en el reporte. **Default:** así, con la
   tabla de T6 como insumo de E10. 🔒 si el dueño prefiere declarar tracking también en el manifiesto
   de la app.
5. **El contador de sesiones arranca con E7b** (E7a): un veterano de la 1.x cuenta su primer
   arranque de la 2.0 como sesión 1 y no ve app open hasta el segundo. **Default:** así (prudente).
6. **Qué celebración termina en un corte (`celebrationsDrained`).** Sí: el reveal del tablero, el
   cofre, la pinta, el special, el diario y la carrera. No: el offline (tiene el suyo), los avisos
   chicos, los logros, el tip del tutorial. Para los kinds que suman otras épicas: **no** la llegada
   de un visitante (`.visitorEncounter`, E4b: el jugador interactúa enseguida) ni la oferta
   (`.offer`, E6a: un anuncio pegado a una oferta rechazada se lee como castigo); **sí** la
   cinemática (`.cinematic`, E8). **Default:** así; cambia en un `switch`.
7. **Sólo cerrar el menú es `sheetClosed`.** El popup de un visitante, el del colchón, la ruleta,
   la ficha o la oferta no son cortes (las tres primeras vienen de un video o de una interacción
   que el jugador acaba de elegir; E6a pidió excluir la oferta). **Default:** así.
8. **0,6 s entre el corte y el anuncio** (`settleDelay`). Deja terminar la animación de la hoja y
   aleja el anuncio del toque que la cerró (clics accidentales, política de AdMob). **Default:**
   0,6 s, en código.
9. **La pausa se pide un minuto antes de su turno** y no en `prepare()` (E7a lo prohibió para no
   bajar la tasa de presentación de la unidad). **Default:** 60 s.
10. **UMP en Ajustes lo hace E7b, no E9.** PLAN lo lista en las dos épicas. **Default:** E7b;
    E9 sólo lo cuenta en su Tour de Ajustes.
11. **La mediación entra sin las cuentas de las redes**: los adaptadores compilan y no piden
    nada hasta que AdMob tenga el mapeo (gate humano de E10). **Default:** se agregan ahora, así
    el binario que se prueba en TestFlight es el que se publica.
12. **Gates del dueño que siguen abiertos** (de E7a): crear en AdMob la unidad de app open y las
    cuatro de video; poner sus IDs en `feature_flags.json` y en el `ads.json` publicado; prender
    `switches.appOpen`; publicar `config/ads.json` en `adergames-site`; las líneas de
    `app-ads.txt` de las cuatro redes.
