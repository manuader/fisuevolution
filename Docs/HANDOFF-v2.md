# HANDOFF — de la v1.0.0 (build 4) a la v2

Punto de partida para que un agente trabaje la **versión 2** de
HoboEvolution / FisuEvolution sobre el mismo código que está publicado en la
App Store. Leer completo antes de tocar nada.

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
Se ejecuta con relevo automático de agentes (§0 del plan). Varios datos de
abajo cambian cuando su épica cierre. **Ya cambió uno**: desde E3a T5
(`3956fd3`, 2026-10-07) `version-2` es universal, con el iPad sólo vertical y
de pantalla completa, e iOS 18 de mínimo; la tabla de §2 describe la v1
publicada. Los packs de ORO todavía no pasaron a 160/550/1.400 (E6a).

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
porque en el tier 12 la cadena se abre en cuatro carreras) en una torre de
**10 pisos**, de un linyera a un dios del universo. Tiene reencarnación (prestige), cofres de skins, boosts,
eventos y jefes/carreras. Es una sátira de la precariedad económica.

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
| Stack | Swift 6 (strict concurrency), SwiftUI + SpriteKit, XcodeGen, sin backend |
| Única dependencia externa | Google Mobile Ads SDK por SPM (trae UMP) |

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
6. **`Docs/SESION-*.md`**: bitácora por sesión. Sirve para entender por qué
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
| `ExportOptions.plist` | Export por CLI. ⚠️ `destination: upload`: **sube directo** a App Store Connect |

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
| `products.json` | Los 11 IAP (ID, tipo y qué entregan) |
| `rewarded_ads.json` | Los 5 premios de Regalos y la cadencia del intersticial |
| `feature_flags.json` | Flags y **IDs de unidades de AdMob** |
| `gamecenter.json`, `viral.json` | Game Center (apagado) y la parte viral |

---

## 5. Integraciones que están en producción

### Compras dentro de la app (StoreKit 2)

- 11 productos: 6 consumibles (plata S/M/L, ORO S/M/L) y 5 no consumibles
  (remove_ads, starter_pack, skin_mundialista, skin_parrillero, skins_diamante).
  IDs `com.fisuevolution.iap.*`. Detalle completo en `Distribution/iap-appstore-connect.md`.
- Para cambiar un producto hay que tocar **tres** cosas que tienen que coincidir:
  `products.json`, `StoreKitConfig/FisuEvolution.storekit` y App Store Connect.
  StoreKit **omite en silencio** los IDs que no resuelve: un typo no da error,
  el producto desaparece.
- El nombre, la descripción y el precio que ve el jugador vienen de StoreKit,
  o sea de App Store Connect, no del juego.
- `StoreManager` loguea `catálogo completo: N productos` o
  `catálogo incompleto: N de 11; StoreKit no resolvió …`. Es el primer lugar
  donde mirar si la tienda aparece vacía.

### Anuncios (AdMob)

- App ID AdMob: `ca-app-pub-8575641544774372~3243441080`, en
  `Info.plist` → `GADApplicationIdentifier`.
- Unidades, todas en `feature_flags.json` → `adUnitIDs`:

| Clave | ID | Formato | Lugar |
|---|---|---|---|
| `rewardedGifts` | `…/8304196070` | Bonificado | Los 5 premios de Regalos |
| `rewardedOfflineX2` | `…/6825744243` | Bonificado | Duplicar ganancias offline |
| `rewardedChestExtra` | `…/3981807683` | Bonificado | Abrir otro cofre |
| `rewardedBoost` | `…/4913896772` | Bonificado | Boost sin esperar |
| `interstitial` | `…/5270838626` | Intersticial | Entre momentos de juego |

- Además existe en AdMob la unidad `…/1615619906` (intersticial bonificado),
  creada para la v2 y **no usada** en el build 4.
- Cadencia del intersticial (`rewarded_ads.json`): como máximo uno cada 420 s;
  nunca en los primeros 180 s de la sesión, ni en los 90 s después de un bonificado.
- En DEBUG se usan los IDs de prueba de Google (`FeatureFlags.swift`).
- Consentimiento: UMP (`AdsConsent.swift`) antes de pedir anuncios, más el
  aviso de ATT (`NSUserTrackingUsageDescription`). `Info.plist` trae 50
  `SKAdNetworkItems`, los de Google.
- `app-ads.txt` publicado en `https://adergames-site.vercel.app/app-ads.txt`
  (repo `manuader/adergames-site`, archivo `public/app-ads.txt`).

### Privacidad

`PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, sin
`NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes = []`. APIs
declaradas: UserDefaults (CA92.1) y FileTimestamp (C617.1).
⚠️ Poner `NSPrivacyTracking = true` sin dominios hace que Apple rechace
el build (ITMS-91064). Los SDKs de terceros traen su propio manifiesto.

### Lo que está apagado (sólo por flag)

`gameCenterEnabled: false`, `cloudKitEnabled: false` en `feature_flags.json`.
El código existe, pero no hay entitlements cableados: prenderlos pide sumar
las capabilities y declararlo en la App Store.

### Sitio y legal

`https://adergames-site.vercel.app`, repo `manuader/adergames-site` (Next.js,
deploy automático de Vercel al pushear a `main`). Ahí están la política de
privacidad (`content/legal.ts`) y los términos. La app los muestra en el menú
(`UI/Menu/LegalView.swift`).

---

## 6. Cómo compilar, testear y archivar

### Requisitos

- **Xcode 26.6**, macOS, XcodeGen en `/opt/homebrew/bin/xcodegen` (2.46).
- Runtimes de simulador: **iOS 26.5** y **iOS 18.6**.

### Reglas que rompen el build si se ignoran

- **El `.xcodeproj` no se versiona.** Después de agregar o borrar archivos
  Swift, o de tocar `project.yml`: `xcodegen generate`.
- `TARGETED_DEVICE_FAMILY: "1"` va **en el target** de la app, no sólo en
  `settings.base`. Si no, el build sale para iPad y Apple lo rechaza (error 90474).
- Warnings como errores (`SWIFT_TREAT_WARNINGS_AS_ERRORS`), strict concurrency
  `complete`.
- **Cada subida a App Store Connect necesita un `CURRENT_PROJECT_VERSION`
  nuevo.** El 1–4 ya están quemados: `version-2` está en **2.0.0 (5)**. Cada
  subida que falle o se repita quema otro número.
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

Antes de subir, verificar en el `.app` del archive: versión y build,
`UIDeviceFamily = [1]`, `NSPrivacyTracking = false` y que esté el
`GADApplicationIdentifier`.

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

En orden sugerido. El detalle de anuncios está en `Docs/monetizacion-anuncios.md`.

1. ✅ **Unificar ramas**: `version-2` contiene a `main` y a la rama del build.
   Al lanzar, `main` avanza a `version-2` por fast-forward (sección 0).
2. **Mediación de anuncios**: AppLovin, Unity, Mintegral y Meta. Adaptadores
   por SPM en `project.yml`, sus SKAdNetwork IDs en `Info.plist`, sus líneas
   en `app-ads.txt` y la política de privacidad actualizada.
3. **Intersticial bonificado al reencarnar**, con la unidad `…/1615619906`.
   Agregar la clave a `adUnitIDs` y el método en `AdsProvider` y `AdMobAdsProvider`.
4. **App open** al volver a la app, espaciado.
5. **IDs de anuncios remotos**: un JSON en `adergames-site`, para cambiar
   unidades sin pasar por la revisión de Apple.
6. Game Center y iCloud: el código ya existe detrás de flags.
7. Recortar en App Store Connect el nombre "Todas las skins de Diamante", que
   se ve truncado en la fila de la tienda.
8. ~~Mover las capturas a git~~: no hace falta. `Distribution/screenshots/` está
   gitignoreado a propósito y `AppStoreScreenshotTests` las regenera en un
   comando.

Lo que la preparación de `version-2` encontró y dejó para el plan (bugs de
producción, funciones a medio cablear y refactors) está en
`Docs/SESION-2026-10-06-preparacion-v2.md`, sección "Para el plan".

Para cada cambio de contenido o economía: editar el JSON, correr los tests de
`EconomyKit` y de la app, y anotar en `Docs/balance-log.md` si cambia el balance.
