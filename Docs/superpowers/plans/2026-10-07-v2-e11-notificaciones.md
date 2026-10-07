# E11 — Notificaciones · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que la 2.0 avise con notificaciones **locales**, prendidas por defecto y
desactivables, cuando hay un motivo de estado para volver (la caja fuerte llena, el premio
diario sin cobrar, tres días afuera), sin interrumpir a nadie el primer día y sin vender nada.

**Architecture:** las reglas viven **puras en EconomyKit**: `NotificationsConfig` (el catálogo
`notifications.json`, con validador) y `NotificationPlanner`, que recibe la partida ya resuelta
(`NotificationSnapshot`) y devuelve qué avisar y cuándo. `NotificationsManager` (app) separa
tres cosas que la v1 mezclaba en un booleano: la **preferencia** del jugador (maestro + una por
tipo, en `UserDefaults`), lo que **iOS concedió** (provisional al cerrar el núcleo del
tutorial, completo desde una tarjeta en el popup offline) y la **ausencia programada** (se arma
al irse, se borra al volver). `GameState` sólo arma el snapshot y engancha el manager al ciclo
de vida que deja E1 T8.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
UserNotifications (locales, sin APNs) · EconomyKit (SPM puro, `Sendable`) · Swift Testing ·
XCUITest · XcodeGen (el `.xcodeproj` no se versiona).

**Fuente:** `Docs/PLAN-v2.md` §4, "E11 — Notificaciones" (decisiones cerradas: no se
re-litigan), más §0.1 (agentes concurrentes), §2 y "Cimientos compartidos". Lo que el código
contradice está en la sección final "Para el dueño / dudas", con un default que no frena.

**Rama de la épica:** `v2/e11-notificaciones`, desde `version-2`. Cada tarea sale de su punta
en un worktree propio (§0.1) y el controlador integra de a una.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build. Nada de `Timer` (regla 2): ningún reloj nuevo; el planificador recibe `now`.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo** (Swift, JSON de `Resources/Config` o test), en el mismo paso en que se crea.
- **Strings nuevos** en `FisuEvolution/Resources/Localizable.xcstrings`, **es + en,
  `"extractionState" : "manual"`, en el mismo commit que la vista o el código que los usa**.
  Sólo con el script de la sección "El catálogo de strings" (formato canónico, trampa 29).
  Claves en minúscula y con `_`: el orden natural del script y el de Xcode coinciden así.
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor** (trampa
  9a-bis). Los marcadores para tests van como `Color.clear` de fondo con
  `.accessibilityElement()`, igual que `board.units` (`RootView.swift:349-355`).
- **FisuJobs es la referencia visual**: `PanelCard`/`GameCard`, `ActionPill`, `StateBadge`,
  `SectionHeader`, `RowDivider`, paleta de la casa. Nada de botones ni alertas del sistema.
- **Nada habla con iOS bajo `--uitest*` ni bajo XCTest** (ni el permiso ni la programación):
  `NotificationsManager.isLive` es falso. Un UI test que lo necesite lo pide con
  `--uitest-notifications-provisional` o `--uitest-notifications-denied` (centro en memoria,
  sin diálogo del sistema). Las preferencias se guardan igual.
- **Locales, no remotas**: sin APNs, sin entitlement `aps-environment`, sin claves nuevas de
  Info.plist y **sin tocar `project.yml`** (más allá de `xcodegen generate`).
- **Data-driven**: horario silencioso, espaciado, tope, hora del diario, regreso y la tarjeta
  viven en `notifications.json`. `NotificationPlanner` no conoce `UserDefaults`,
  `UNUserNotificationCenter` ni `Date()`: todo le llega resuelto.
- **Nunca anuncios, ofertas ni precios** en un aviso (guía 4.5.4): un test lo vigila.
- **Preferencia de dispositivo**: todo en `UserDefaults`, nada en el save. Sobrevive a
  cualquier reset de partida (el de E9 incluido); sólo `--uitest-reset` la borra.
- **Las trampas de concurrencia de `NotificationsManager.swift` se conservan**: el protocolo
  `@MainActor`, el envoltorio `SystemNotificationCenter` con callbacks (no `async`), el
  `sending` de `add` y los constructores de peticiones `nonisolated static`. Se reescribe la
  lógica del manager, no esas piezas.
- Código nuevo limpio y con pocos comentarios (regla del dueño: prolijidad antes que
  comentarios); los comentarios heredados no se borran por deporte, pero **el que miente se
  corrige** en el commit que lo vuelve mentira.
- **Commits en español, estilo `feat(notif): …`, SIN `Co-Authored-By`.** Staging selectivo por
  archivo y `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración →
  `Tools/v2/oraculo.sh rapido` → `Docs/SESION-<fecha>-v2-e11.md` → las cuatro ediciones de
  `Docs/HANDOFF.md` → journal AVO y latido del `LOCK`. Ningún subagente toca `Docs/`,
  `handoffs/` ni el journal.

## Verificación (vale para toda tarea)

**El oráculo del run** juzga cada commit integrado:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
```

- Termina en 0 (`VERDE`) sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`. E11 no
  declara rojos nuevos. Los tests nuevos entran solos (corre las suites enteras).
- `rapido` al cerrar T1, T2 y T3; `completo` al cerrar T4, T5 y T6 (tocan UI o el arranque) y
  al cerrar la épica (T7).

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…")
swift test --package-path Packages/EconomyKit --filter "NotificationPlannerTests|NotificationsConfigTests|PermissionCardPolicyTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e11-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e11" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e11" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/NotificationsManagerTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y de `-only-testing:`). Mirá la salida. Ante un rojo en masa, antes
de culpar al código: `uptime`, `ps aux | grep '[x]codebuild'` y qué árbol compiló (trampas 16,
33 y 44).

## El catálogo de strings (trampa 29)

Las tareas T2–T5 tocan `Localizable.xcstrings` **sólo** con este script. Cada worktree lo
crea en `build/` (ignorado por git) si no lo tiene:

`build/xcstrings_e11.py`:

```python
#!/usr/bin/env python3
"""Edita Localizable.xcstrings en el formato canónico de Xcode (trampa 29).

Uso: python3 build/xcstrings_e11.py build/e11-tN-strings.json
Edición: {"set": {"clave": {"es": "…", "en": "…"}}, "remove": ["clave"]}
"""
import json
import re
import sys

CATALOG = "FisuEvolution/Resources/Localizable.xcstrings"


def natural(key):
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", key)]


def dump(catalog):
    catalog = dict(catalog)
    catalog["strings"] = {key: catalog["strings"][key] for key in sorted(catalog["strings"], key=natural)}
    text = json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : "))
    return text.replace("{}", "{\n\n}")


def entry(es, en):
    def unit(value):
        return {"stringUnit": {"state": "translated", "value": value}}
    return {"extractionState": "manual", "localizations": {"en": unit(en), "es": unit(es)}}


raw = open(CATALOG, encoding="utf-8").read()
catalog = json.loads(raw)
if dump(catalog) != raw:
    sys.exit("el catálogo no está en formato canónico: no se escribe nada (trampa 29)")
edits = json.load(open(sys.argv[1], encoding="utf-8"))
for key in edits.get("remove", []):
    del catalog["strings"][key]
for key, texts in edits.get("set", {}).items():
    catalog["strings"][key] = entry(texts["es"], texts["en"])
with open(CATALOG, "w", encoding="utf-8") as out:
    out.write(dump(catalog))
print(f"{len(edits.get('set', {}))} claves escritas, {len(edits.get('remove', []))} borradas")
```

Verificado contra `4fd77c8`: serializar el catálogo sin cambios da **byte a byte** el mismo
archivo. Si el script sale con "no está en formato canónico", alguien lo editó a mano: se para
y se reporta, no se "arregla" de paso. Después de escribir, `git diff --stat` del catálogo
tiene que mostrar sólo las líneas de las claves tocadas.

## Las referencias, verificadas contra el árbol (`4fd77c8`)

| Lo que pide la spec | Dónde está hoy | Qué significa para E11 |
|---|---|---|
| `NotificationsManager`: recordatorio 19:00, apagado por defecto | `FisuEvolution/Managers/NotificationsManager.swift:102-227` (`defaultsKey` 106, `requestIdentifier` "fisu.daily.reminder" 110, `reminderHour` 113, `isEnabled = defaults.bool(…)` 135) | T3 reescribe el manager; el protocolo `NotificationScheduling` (13-25) y `SystemNotificationCenter` (46-85) se quedan con sus trampas y suman `removeAllDeliveredNotifications()` |
| la fila `settings.notifications` | `SettingsView.swift:240-257`, en la cinta "En el juego" junto a partículas; `.task { syncWithSystem() }` en 137 | T3 migra tres llamadas; T4 la muda a una sección propia |
| la suite `NotificationsManager` con `SpyNotificationCenter` | `FisuEvolutionTests/SettingsPersistenceTests.swift:120-320` | T3 la muda a `NotificationsManagerTests.swift` y la reescribe |
| el manager se construye al arrancar | `FisuEvolutionApp.swift:12`, **antes** del bootstrap | `applyLaunchArgumentDefaults` (`GameState+Debug.swift:25-37`) borra la clave **después** de que el manager la leyó: el `--uitest-reset` lo resuelve el propio manager (T3) |
| `GameState.handleScenePhase` | `GameState.swift:897-917`. **E1 T8** lo muda a `GameState+Lifecycle.swift` como `handleScenePhase(from:to:now:)` con `seal(now:)`, `isSceneActive` y `backgroundTasks` | T6 se engancha a esa API, no a la de hoy |
| `DailyRewardManager` | `ContentSystems.swift:346-426`. **El cobro es automático**: `claimDailyIfAvailable()` corre en el bootstrap y en cada `.active` (`GameState+Bonus.swift:258-279`) | al irse, el diario de hoy ya está cobrado: ver duda 1 |
| `EconomyConfig.offlineCapHours` | `EconomyConfig.swift:296`, `economy.json:31` = **10**; ningún efecto lo extiende | la caja fuerte avisa a `ahora + 10 h` |
| `core.finish` | hoy no existe con ese nombre: el cierre del núcleo es `tutorialPhaseFinished()` (`GameState+Celebrations.swift:91-97`, el que entrega el cofre de bienvenida), disparado por el paso `finish` de `TutorialOverlay.swift:93` | T6 pide el provisional ahí; E9 lo renombra y hereda la llamada |
| familias de `LocalizationCompletenessTests` | `DynamicFamily`, `LocalizationCompletenessTests.swift:91-153` | T2 suma la familia `notifications`; T4 extiende `settingsRows` |
| "nada bajo `--uitest*` ni XCTest" | patrón `AudioManager.launchAllowsFloorMusic` (`AudioManager.swift:81-86`) | `NotificationsManager.launchAllowsSystem(arguments:environment:)` |
| el popup offline | `FisuEvolution/UI/Popups/OfflineEarningsView.swift` (`PanelCard` + `ActionPill`); fixture `--uitest-offline` (`GameState.swift:623`) | T5 aloja la tarjeta adentro |
| los textos viejos | `Localizable.xcstrings:4390-4420`: `notif.daily.title/.body`; `settings.notifications.hint` = "Un aviso por día, a las 19." | T3 borra los dos `notif.daily.*` y corrige el hint, que pasa a mentir |

## Lo que la 2.0 cambia del manager de la v1

| | v1 | 2.0 |
|---|---|---|
| `isEnabled` | lo que iOS concedió (sólo se escribe `true` si el permiso salió) | **la preferencia del jugador**: `true` si la clave no existe; un `false` escrito se respeta |
| permiso | se pedía al prender el toggle, completo | provisional al cerrar el núcleo (sin diálogo); completo desde la tarjeta del popup offline o al prender el maestro con iOS sin preguntar |
| qué se programa | un recordatorio repetido a las 19:00 (`fisu.daily.reminder`) | la ausencia: `fisu.notif.<id>` sueltos, planificados al irse, borrados al volver |
| iOS denegado | apagaba el toggle | el toggle queda como el jugador lo dejó; la fila lo dice y ofrece "Abrir Ajustes" |
| bajo tests | construía el centro real pero no lo usaba hasta el toque | `isLive = false`: nunca habla con iOS salvo fixture |

El recordatorio repetido de la v1 desaparece solo: volver a la app borra **todo** lo pendiente
(`appBecameActive`), y la primera ausencia de la 2.0 programa lo nuevo.

## Las reglas del planificador en una página

```
NotificationSnapshot (now, producesOffline, offlineCapHours, dailyClaimedToday)   ← la app, al irse
   │  moments: cada motivo propone su hora
   │    vault_full  = now + offlineCapHours        (sólo si la torre produce afuera)
   │    daily_ready = primer día sin cobrar, a dailyReadyHour (19)
   │    comeback    = now + comebackAfterHours (72)
   ▼
filtro: maestro apagado → nada · tipo apagado → afuera · hora pasada → afuera
   ▼
tope por ausencia (3): se quedan los de MÁS PRIORIDAD (orden de notifications.json)
   ▼
horario silencioso 22–9: lo que cae adentro se corre a las 9
   ▼
orden en el tiempo (empate: prioridad) y espaciado ≥ 4 h: el segundo SE CORRE (y vuelve a
mirar el silencio), nunca se descarta — todo motivo sigue siendo cierto hasta que el jugador vuelve
   ▼
[PlannedNotification(kind, fireAt)]   → el manager arma UNTimeIntervalNotificationTrigger(fireAt − now)
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/NotificationsConfig.swift` | **nuevo** — `NotificationKind`, el espejo de `notifications.json` y su validador | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/NotificationPlanner.swift` | **nuevo** — snapshot, preferencias, el planificador y la política de la tarjeta | 1 |
| `Packages/EconomyKit/Tests/EconomyKitTests/NotificationPlannerTests.swift` | **nuevo** — las tres suites de EK y `fxNotifications` | 1 |
| `FisuEvolution/Resources/Config/notifications.json` | **nuevo** — el catálogo y las reglas | 2 |
| `FisuEvolution/Managers/GameContentLoader.swift` | carga y valida `notifications.json` en `GameContent.notifications` | 2 |
| `FisuEvolution/Managers/NotificationCopy.swift` | **nuevo** — las claves de texto de cada motivo | 2 |
| `FisuEvolutionTests/NotificationsContentTests.swift` | **nuevo** — el catálogo real pineado y la guarda de "no vende" | 2 |
| `FisuEvolution/Managers/NotificationsManager.swift` | preferencia, permiso en dos pasos, ausencia, tarjeta, compuerta de tests | 3 |
| `FisuEvolutionTests/NotificationsManagerTests.swift` | **nuevo** — la suite del manager (sale de `SettingsPersistenceTests.swift`) | 3 |
| `FisuEvolution/UI/Menu/SettingsView.swift` | T3: tres llamadas; T4: la sección "Avisos" | 3, 4 |
| `FisuEvolutionUITests/NotificationsSettingsUITests.swift` | **nuevo** — los toggles de Ajustes | 4 |
| `FisuEvolution/UI/Popups/NotificationPermissionCard.swift` | **nuevo** — "¿Te aviso cuando la caja fuerte se llene?" | 5 |
| `FisuEvolution/UI/Popups/OfflineEarningsView.swift` | aloja la tarjeta | 5 |
| `FisuEvolutionUITests/NotificationPermissionCardUITests.swift` | **nuevo** — la tarjeta y la compuerta de `--uitest` | 5 |
| `FisuEvolution/Game/State/GameState+Notifications.swift` | **nuevo** — snapshot, programar al irse, borrar al volver, provisional | 6 |
| `FisuEvolutionTests/NotificationsWiringTests.swift` | **nuevo** — el ciclo de vida con el manager enganchado | 6 |

## Orden, olas y paralelismo

**Archivos por tarea** (🔥 = caliente según PLAN-v2 §0.1; ♨️ = compartido con otra épica en
curso, no caliente pero se integra con cuidado):

| T | Qué | Crea | Modifica | 🔥 / ♨️ | Depende de |
|---|---|---|---|---|---|
| T1 | catálogo y planificador (EK puro) | `NotificationsConfig.swift`, `NotificationPlanner.swift`, `NotificationPlannerTests.swift` | — | ninguno | — |
| T2 | `notifications.json`, carga y textos | `notifications.json`, `NotificationCopy.swift`, `NotificationsContentTests.swift` | `GameContentLoader.swift`, `Localizable.xcstrings` (+6 claves), `LocalizationCompletenessTests.swift` | 🔥 `Localizable.xcstrings` · ♨️ `GameContentLoader.swift` (E4–E7 suman configs ahí después), `LocalizationCompletenessTests.swift` | T1 |
| T3 | el manager de la 2.0 | `NotificationsManagerTests.swift` | `NotificationsManager.swift`, `SettingsView.swift` (sólo 3 llamadas), `Localizable.xcstrings` (−2 claves, 1 texto), `SettingsPersistenceTests.swift` (sale la suite vieja), `FisuEvolutionApp.swift` (sólo el comentario de las líneas 10-11) | 🔥 `SettingsView.swift`, `Localizable.xcstrings` · ♨️ `FisuEvolutionApp.swift` (E1 T5 y T8 lo tocan después: el comentario no está en sus líneas) | T1, T2 |
| T4 | Ajustes: maestro, uno por tipo, "Abrir Ajustes" | `NotificationsSettingsUITests.swift` | `SettingsView.swift`, `Localizable.xcstrings` (+5 claves, 1 texto), `LocalizationCompletenessTests.swift` | 🔥 `SettingsView.swift`, `Localizable.xcstrings` | T3 |
| T5 | la tarjeta del permiso completo | `NotificationPermissionCard.swift`, `NotificationPermissionCardUITests.swift` | `OfflineEarningsView.swift`, `Localizable.xcstrings` (+4 claves) | 🔥 `Localizable.xcstrings` · ♨️ `OfflineEarningsView.swift` (E9 aloja ahí la lección offline) | T3 |
| T6 | cableado al ciclo de vida | `GameState+Notifications.swift`, `NotificationsWiringTests.swift` | `GameState.swift` (2 propiedades), `GameState+Lifecycle.swift` (de E1 T8), `GameState+Celebrations.swift` (1 línea), `FisuEvolutionApp.swift` (`startServices`) | 🔥 `GameState.swift` · ♨️ `GameState+Lifecycle.swift`, `GameState+Celebrations.swift` y `FisuEvolutionApp.swift` (todos de E1) | T3; **E1 T1** (`IncomeTicker.basePassivePerSecond`), **E1 T5** (`startServices()`), **E1 T8** (`+Lifecycle`) y **después de E1 T9** (que toca `+Celebrations`) |
| T7 | cierre de la épica | — | `Docs/` (controlador) | — | T1–T6 |

E11 **no toca** `RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`,
`GameState+Bonus.swift`, `PlayerState.swift`, `TowerActions.swift` ni `project.yml`.

**Las olas** (las del calendario de PLAN-v2 §0.1, con las huellas reales de arriba):

```
Ola B   T1 → T2 → T3            ∥ E1 T3 → T4     E11 es dueño de Localizable.xcstrings y SettingsView.swift
Ola D   T4 ║ T5                 ∥ E1 T8 ∥ E3     T4 es dueño de SettingsView.swift; Localizable: ver abajo
Ola E   E1 T9 → T6              ∥ E3             T6 es dueño de GameState.swift
Cierre  T7 (controlador)
```

**Reglas del paralelismo:**

1. T1 → T2 → T3 son **secuenciales** (cada una consume los tipos y las claves de la anterior).
   Ninguna toca un archivo de E1 T3/T4 (`PlayerState.swift`, `TowerActions.swift`,
   `EconomyConfig.swift`, `SaveMigrator.swift`…): van en paralelo con E1 sin cruzarse.
2. T4 y T5 no comparten archivos salvo el catálogo. Si van juntas, **T5 entrega sus 4 claves
   como snapshot** (el JSON de edición de su paso de strings, sin correr el script) y el
   controlador lo aplica al integrar. Si el controlador prefiere, van de a una (T4 → T5).
3. Si en la ola D otra épica (E3) necesita `SettingsView.swift` o `OfflineEarningsView.swift`,
   la de E11 va primero o después, nunca a la vez: un agente que necesita un caliente ajeno
   para y reporta `NEEDS_CONTEXT`.
4. **T6 sale de una `v2/e11-notificaciones` que ya tiene mergeada `version-2` con E1 T1, T5, T8
   y T9 adentro.** Su paso 0 lo comprueba; si falta algo, `NEEDS_CONTEXT`, no se inventa la API.
5. Cada agente: su worktree, su DerivedData (`build/DD-e11`) y su simulador por UDID, que
   apaga y borra al terminar. Hasta 3 compilando a la vez en todo el run.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` (async, **no** throws; repo en memoria) | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| dominio de `UserDefaults` descartable | `SettingsPersistenceTests.ScratchDefaults()` (`.defaults`, `.stored`, `.clear()`) | `SettingsPersistenceTests.swift:99-117` |
| centro de notificaciones espía | `SpyNotificationCenter` — hoy `NotificationsManagerTests.SpyNotificationCenter` en `SettingsPersistenceTests.swift:288-319`; T3 lo muda a `NotificationsManagerTests.swift` con el mismo nombre calificado | T3 |
| leer el catálogo de strings fuente | `LocalizationCompletenessTests.catalog("Localizable")` y `.languages` | `LocalizationCompletenessTests.swift:27, 183-189` |
| el contenido real | `try GameContentLoader.load(from: .main)` (nonisolated) | `GameContentLoader.swift:31` |
| UI tests: abrir el menú | copiar `openMenu`/`attach` de `MenuUITests.swift:277-301` (son `private`) | |

EconomyKit no tiene recursos: los tests de T1 usan `fxNotifications(...)` (lo crea T1) y un
calendario fijo de Buenos Aires (sin horario de verano: las cuentas de horas no se corren).

---

### Task 1: El catálogo y el planificador de la ausencia, puros en EconomyKit

**Objetivo:** las reglas de E11 en EconomyKit, sin UI ni sistema: el espejo de
`notifications.json` con su validador, el planificador (tope offline, diario, regreso,
silencio, espaciado, tope por prioridad, tipo y maestro apagados) y cuándo se ofrece la
tarjeta del permiso. Puede arrancar ya: no toca nada de E1.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/NotificationsConfig.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/NotificationPlanner.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/NotificationPlannerTests.swift`

**Interfaces:**
- Produces: `public enum NotificationKind: String, CaseIterable, Sendable { case vaultFull = "vault_full", dailyReady = "daily_ready", comeback }`.
- Produces: `public struct NotificationsConfig: Codable, Sendable, Equatable` con `schemaVersion: Int`, `notifications: [Entry]` (`Entry.id: String`, `Entry.kind: NotificationKind?`), `quietHours: QuietHours` (`startHour`, `endHour`, `contains(hour:)`), `minSpacingHours: Double`, `maxPerAbsence: Int`, `dailyReadyHour: Int`, `comebackAfterHours: Double`, `permissionCard: PermissionCard` (`maxOffers: Int`, `retryAfterHours: Double`), `kinds: [NotificationKind]`, `validate() throws` y `enum ValidationError: Error, Equatable`.
- Produces: `public struct NotificationSnapshot: Sendable, Equatable { now, producesOffline, offlineCapHours, dailyClaimedToday }`, `public struct NotificationPreferences: Sendable, Equatable { masterEnabled, disabledKinds; allows(_:) }`, `public struct PlannedNotification: Sendable, Equatable { kind, fireAt }`.
- Produces: `NotificationPlanner.plan(_:config:preferences:calendar:) -> [PlannedNotification]`, `NotificationPlanner.moments(for:config:calendar:)`, `NotificationPlanner.outsideQuietHours(_:config:calendar:) -> TimeInterval`.
- Produces: `PermissionCardPolicy.isDue(offersMade:lastOfferAt:now:config:) -> Bool`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/NotificationPlannerTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// El catálogo con las reglas de PLAN-v2 E11: silencio de 22 a 9, 4 h entre
/// avisos, 3 por ausencia, el diario a las 19 y el regreso a las 72 h.
func fxNotifications(
    ids: [String] = NotificationKind.allCases.map(\.rawValue),
    quietStart: Int = 22,
    quietEnd: Int = 9,
    minSpacingHours: Double = 4,
    maxPerAbsence: Int = 3,
    dailyReadyHour: Int = 19,
    comebackAfterHours: Double = 72
) -> NotificationsConfig {
    NotificationsConfig(
        schemaVersion: 1,
        notifications: ids.map(NotificationsConfig.Entry.init(id:)),
        quietHours: NotificationsConfig.QuietHours(startHour: quietStart, endHour: quietEnd),
        minSpacingHours: minSpacingHours,
        maxPerAbsence: maxPerAbsence,
        dailyReadyHour: dailyReadyHour,
        comebackAfterHours: comebackAfterHours,
        permissionCard: NotificationsConfig.PermissionCard(maxOffers: 2, retryAfterHours: 72)
    )
}

/// Octubre de 2026 en Buenos Aires: sin horario de verano, una hora es una hora.
private struct BuenosAires {
    let calendar: Calendar

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Argentina/Buenos_Aires"))
        self.calendar = calendar
    }

    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> TimeInterval {
        let components = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components)).timeIntervalSince1970
    }

    func hour(of time: TimeInterval) -> Int {
        calendar.component(.hour, from: Date(timeIntervalSince1970: time))
    }
}

@Suite("Notificaciones: el planificador de la ausencia")
struct NotificationPlannerTests {
    private let ba: BuenosAires

    init() throws {
        ba = try BuenosAires()
    }

    private func plan(
        leavingAt now: TimeInterval,
        producesOffline: Bool = true,
        capHours: Double = 10,
        dailyClaimedToday: Bool = true,
        config: NotificationsConfig = fxNotifications(),
        preferences: NotificationPreferences = NotificationPreferences()
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(
            NotificationSnapshot(
                now: now,
                producesOffline: producesOffline,
                offlineCapHours: capHours,
                dailyClaimedToday: dailyClaimedToday
            ),
            config: config,
            preferences: preferences,
            calendar: ba.calendar
        )
    }

    private func fireAt(_ kind: NotificationKind, in planned: [PlannedNotification]) -> TimeInterval? {
        planned.first { $0.kind == kind }?.fireAt
    }

    // MARK: Cada motivo

    @Test("la caja fuerte avisa cuando se llena: al irse más el tope offline")
    func vaultFullAtTheOfflineCap() throws {
        let leaving = try ba.at(5, 8)
        let full = try ba.at(5, 18)
        #expect(fireAt(.vaultFull, in: plan(leavingAt: leaving, capHours: 10)) == full)
    }

    @Test("sin pasivo no hay caja fuerte que se llene")
    func noPassiveNoVault() throws {
        let planned = plan(leavingAt: try ba.at(5, 8), producesOffline: false)
        #expect(fireAt(.vaultFull, in: planned) == nil)
    }

    @Test("el diario cobrado hoy avisa mañana a las 19")
    func dailyClaimedTodayAnnouncesTomorrow() throws {
        let tomorrow = try ba.at(6, 19)
        let planned = plan(leavingAt: try ba.at(5, 10), dailyClaimedToday: true)
        #expect(fireAt(.dailyReady, in: planned) == tomorrow)
    }

    @Test("el diario sin cobrar avisa hoy a las 19, o mañana si ya pasó la hora")
    func dailyUnclaimed() throws {
        let today = try ba.at(5, 19)
        let tomorrow = try ba.at(6, 19)
        #expect(fireAt(.dailyReady, in: plan(leavingAt: try ba.at(5, 10), dailyClaimedToday: false)) == today)
        #expect(fireAt(.dailyReady, in: plan(leavingAt: try ba.at(5, 20), dailyClaimedToday: false)) == tomorrow)
    }

    @Test("el regreso: 72 h después de irse, una sola vez por ausencia")
    func comebackAfterThreeDays() throws {
        let threeDaysLater = try ba.at(8, 10)
        let planned = plan(leavingAt: try ba.at(5, 10))
        #expect(fireAt(.comeback, in: planned) == threeDaysLater)
        #expect(planned.filter { $0.kind == .comeback }.count == 1)
    }

    // MARK: El horario silencioso

    @Test("lo que cae en el horario silencioso se corre a las 9")
    func quietHoursShiftToNine() throws {
        // 14 h + 10 h = medianoche, adentro del silencio.
        let nine = try ba.at(6, 9)
        #expect(fireAt(.vaultFull, in: plan(leavingAt: try ba.at(5, 14), capHours: 10)) == nine)
    }

    @Test("los bordes del silencio: 21:59 y 9:00 suenan; 22:00 y 8:59 se corren")
    func quietHoursBoundaries() throws {
        let config = fxNotifications()
        let beforeQuiet = try ba.at(5, 21, 59)
        let quietStarts = try ba.at(5, 22)
        let almostNine = try ba.at(5, 8, 59)
        let nine = try ba.at(5, 9)
        let nextNine = try ba.at(6, 9)
        #expect(NotificationPlanner.outsideQuietHours(beforeQuiet, config: config, calendar: ba.calendar) == beforeQuiet)
        #expect(NotificationPlanner.outsideQuietHours(nine, config: config, calendar: ba.calendar) == nine)
        #expect(NotificationPlanner.outsideQuietHours(quietStarts, config: config, calendar: ba.calendar) == nextNine)
        #expect(NotificationPlanner.outsideQuietHours(almostNine, config: config, calendar: ba.calendar) == nine)
    }

    // MARK: Espaciado y tope

    @Test("dos avisos quedan a 4 h o más: el segundo se corre, no se pierde")
    func spacingPushesTheLaterOne() throws {
        // 5 h + 12 h = la caja a las 17; el diario sin cobrar a las 19 queda a 2 h y pasa a las 21.
        let vault = try ba.at(5, 17)
        let daily = try ba.at(5, 21)
        let planned = plan(leavingAt: try ba.at(5, 5), capHours: 12, dailyClaimedToday: false)
        #expect(fireAt(.vaultFull, in: planned) == vault)
        #expect(fireAt(.dailyReady, in: planned) == daily)
    }

    @Test("si correrlo lo mete en el silencio, sale a las 9 del día siguiente")
    func spacingIntoQuietHours() throws {
        // La caja y el diario empatan a las 19: gana la prioridad del catálogo y
        // el diario pasa a las 23, adentro del silencio → las 9 del 6.
        let vault = try ba.at(5, 19)
        let daily = try ba.at(6, 9)
        let planned = plan(leavingAt: try ba.at(5, 5), capHours: 14, dailyClaimedToday: false)
        #expect(fireAt(.vaultFull, in: planned) == vault)
        #expect(fireAt(.dailyReady, in: planned) == daily)
    }

    @Test("el tope por ausencia se aplica por prioridad, no por orden de llegada")
    func capKeepsTheMostImportant() throws {
        let leaving = try ba.at(5, 10)
        #expect(plan(leavingAt: leaving).count == 3)
        let capped = plan(leavingAt: leaving, config: fxNotifications(maxPerAbsence: 2))
        #expect(capped.map(\.kind) == [.vaultFull, .dailyReady])
        let comebackFirst = plan(
            leavingAt: leaving,
            config: fxNotifications(ids: ["comeback", "vault_full", "daily_ready"], maxPerAbsence: 2)
        )
        #expect(comebackFirst.map(\.kind) == [.vaultFull, .comeback])
    }

    // MARK: Ajustes

    @Test("un tipo apagado en Ajustes no se programa")
    func disabledKindIsSkipped() throws {
        let planned = plan(
            leavingAt: try ba.at(5, 10),
            preferences: NotificationPreferences(disabledKinds: [.vaultFull])
        )
        #expect(planned.map(\.kind) == [.dailyReady, .comeback])
    }

    @Test("con el maestro apagado no se programa nada")
    func masterOffSchedulesNothing() throws {
        let planned = plan(leavingAt: try ba.at(5, 10), preferences: NotificationPreferences(masterEnabled: false))
        #expect(planned.isEmpty)
    }

    // MARK: Las reglas, a cualquier hora

    @Test("a cualquier hora que te vayas: nada en el silencio, nada pegado, nunca más de 3",
          arguments: 0..<24)
    func invariantsAtEveryHour(hour: Int) throws {
        let config = fxNotifications()
        let leaving = try ba.at(5, hour)
        let planned = plan(leavingAt: leaving, dailyClaimedToday: hour.isMultiple(of: 2))
        #expect(planned.count <= config.maxPerAbsence)
        for (earlier, later) in zip(planned, planned.dropFirst()) {
            #expect(later.fireAt - earlier.fireAt >= config.minSpacingHours * 3600)
        }
        for notice in planned {
            #expect(notice.fireAt > leaving)
            #expect(!config.quietHours.contains(hour: ba.hour(of: notice.fireAt)),
                    "\(notice.kind.rawValue) suena a las \(ba.hour(of: notice.fireAt))")
        }
    }
}

@Suite("Notificaciones: el validador del catálogo")
struct NotificationsConfigTests {
    private let allIDs = NotificationKind.allCases.map(\.rawValue)

    @Test("el catálogo con las reglas de PLAN-v2 es válido")
    func validCatalog() throws {
        try fxNotifications().validate()
    }

    @Test("un id repetido no pasa")
    func duplicateID() {
        let config = fxNotifications(ids: allIDs + ["comeback"])
        #expect(throws: NotificationsConfig.ValidationError.duplicateID("comeback")) { try config.validate() }
    }

    @Test("un id que no es un motivo conocido no pasa")
    func unknownID() {
        let config = fxNotifications(ids: allIDs + ["pizza_ready"])
        #expect(throws: NotificationsConfig.ValidationError.unknownID("pizza_ready")) { try config.validate() }
    }

    @Test("un motivo sin entrada no pasa: nunca sonaría")
    func missingKind() {
        let config = fxNotifications(ids: allIDs.filter { $0 != "comeback" })
        #expect(throws: NotificationsConfig.ValidationError.missingKind(.comeback)) { try config.validate() }
    }

    @Test("las horas van de 0 a 23")
    func hoursInRange() {
        #expect(throws: NotificationsConfig.ValidationError.hourOutOfRange(field: "quietHours.startHour", hour: 24)) {
            try fxNotifications(quietStart: 24).validate()
        }
    }

    @Test("el diario no puede caer adentro del silencio")
    func dailyOutsideQuietHours() {
        #expect(throws: NotificationsConfig.ValidationError.dailyHourIsQuiet(23)) {
            try fxNotifications(dailyReadyHour: 23).validate()
        }
    }

    @Test("el espaciado y el tope son positivos")
    func positiveAmounts() {
        #expect(throws: NotificationsConfig.ValidationError.notPositive(field: "minSpacingHours")) {
            try fxNotifications(minSpacingHours: 0).validate()
        }
        #expect(throws: NotificationsConfig.ValidationError.notPositive(field: "maxPerAbsence")) {
            try fxNotifications(maxPerAbsence: 0).validate()
        }
    }

    @Test("el silencio cruza la medianoche")
    func quietHoursWrapMidnight() {
        let quiet = NotificationsConfig.QuietHours(startHour: 22, endHour: 9)
        #expect(quiet.contains(hour: 22) && quiet.contains(hour: 0) && quiet.contains(hour: 8))
        #expect(!quiet.contains(hour: 9) && !quiet.contains(hour: 21))
    }
}

@Suite("Notificaciones: cuándo se ofrece la tarjeta del permiso")
struct PermissionCardPolicyTests {
    private let card = NotificationsConfig.PermissionCard(maxOffers: 2, retryAfterHours: 72)

    @Test("la primera vez se ofrece")
    func firstOffer() {
        #expect(PermissionCardPolicy.isDue(offersMade: 0, lastOfferAt: nil, now: 1000, config: card))
    }

    @Test("una sola vez más, a los 3 días")
    func secondOfferAfterThreeDays() {
        #expect(!PermissionCardPolicy.isDue(offersMade: 1, lastOfferAt: 1000, now: 1000 + 72 * 3600 - 1, config: card))
        #expect(PermissionCardPolicy.isDue(offersMade: 1, lastOfferAt: 1000, now: 1000 + 72 * 3600, config: card))
    }

    @Test("nunca una tercera")
    func neverAThird() {
        #expect(!PermissionCardPolicy.isDue(offersMade: 2, lastOfferAt: 1000, now: 1000 + 1000 * 3600, config: card))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "NotificationPlannerTests|NotificationsConfigTests|PermissionCardPolicyTests"`
Expected: no compila — `cannot find type 'NotificationsConfig' in scope` (y `NotificationPlanner`,
`NotificationKind`, `PermissionCardPolicy`).

- [ ] **Step 3: `NotificationsConfig.swift`**

```swift
import Foundation

/// Un motivo para volver que el juego avisa con una notificación local (PLAN-v2
/// E11). El `rawValue` es el id de `notifications.json` y arma las claves de
/// texto `notif.<id>.title/.body`.
///
/// Cada épica que suma un motivo agrega su caso, su entrada en el catálogo y sus
/// textos: el validador y `LocalizationCompletenessTests` no dejan olvidar
/// ninguno de los tres.
public enum NotificationKind: String, CaseIterable, Sendable {
    /// La caja fuerte se llenó: el tope offline.
    case vaultFull = "vault_full"
    /// El premio diario está sin cobrar.
    case dailyReady = "daily_ready"
    /// Días sin entrar, una sola vez por ausencia.
    case comeback
}

/// Espejo Codable de `notifications.json`: el catálogo y las reglas del
/// planificador. Todo número de las reglas vive acá y no en Swift.
public struct NotificationsConfig: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public let id: String

        public init(id: String) {
            self.id = id
        }

        public var kind: NotificationKind? { NotificationKind(rawValue: id) }
    }

    /// Lo que cae adentro se corre al final. Cruza la medianoche cuando
    /// `startHour > endHour` (22 → 9).
    public struct QuietHours: Codable, Sendable, Equatable {
        public let startHour: Int
        public let endHour: Int

        public init(startHour: Int, endHour: Int) {
            self.startHour = startHour
            self.endHour = endHour
        }

        public func contains(hour: Int) -> Bool {
            startHour > endHour
                ? hour >= startHour || hour < endHour
                : hour >= startHour && hour < endHour
        }
    }

    /// La tarjeta que pide el permiso completo: cuántas veces se ofrece y cada cuánto.
    public struct PermissionCard: Codable, Sendable, Equatable {
        public let maxOffers: Int
        public let retryAfterHours: Double

        public init(maxOffers: Int, retryAfterHours: Double) {
            self.maxOffers = maxOffers
            self.retryAfterHours = retryAfterHours
        }
    }

    public let schemaVersion: Int
    /// El orden es la prioridad: con más motivos que `maxPerAbsence` se quedan
    /// los primeros. Es también el orden de las filas de Ajustes.
    public let notifications: [Entry]
    public let quietHours: QuietHours
    public let minSpacingHours: Double
    public let maxPerAbsence: Int
    public let dailyReadyHour: Int
    public let comebackAfterHours: Double
    public let permissionCard: PermissionCard

    public init(
        schemaVersion: Int,
        notifications: [Entry],
        quietHours: QuietHours,
        minSpacingHours: Double,
        maxPerAbsence: Int,
        dailyReadyHour: Int,
        comebackAfterHours: Double,
        permissionCard: PermissionCard
    ) {
        self.schemaVersion = schemaVersion
        self.notifications = notifications
        self.quietHours = quietHours
        self.minSpacingHours = minSpacingHours
        self.maxPerAbsence = maxPerAbsence
        self.dailyReadyHour = dailyReadyHour
        self.comebackAfterHours = comebackAfterHours
        self.permissionCard = permissionCard
    }

    public var kinds: [NotificationKind] { notifications.compactMap(\.kind) }

    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case duplicateID(String)
        case unknownID(String)
        case missingKind(NotificationKind)
        case hourOutOfRange(field: String, hour: Int)
        case emptyQuietHours
        case dailyHourIsQuiet(Int)
        case notPositive(field: String)

        public var description: String {
            switch self {
            case .duplicateID(let id): "el id \(id) está dos veces"
            case .unknownID(let id): "el id \(id) no es un NotificationKind"
            case .missingKind(let kind): "falta la entrada de \(kind.rawValue)"
            case .hourOutOfRange(let field, let hour): "\(field) = \(hour) no es una hora (0–23)"
            case .emptyQuietHours: "el horario silencioso empieza y termina a la misma hora"
            case .dailyHourIsQuiet(let hour): "el aviso del diario (\(hour) h) cae en el horario silencioso"
            case .notPositive(let field): "\(field) tiene que ser mayor que cero"
            }
        }
    }

    /// Lo llama `GameContentLoader` al arrancar: un catálogo mal armado es un
    /// aviso que nunca suena, y nadie se entera.
    public func validate() throws {
        var seen = Set<String>()
        for entry in notifications {
            guard seen.insert(entry.id).inserted else { throw ValidationError.duplicateID(entry.id) }
            guard entry.kind != nil else { throw ValidationError.unknownID(entry.id) }
        }
        if let missing = NotificationKind.allCases.first(where: { !seen.contains($0.rawValue) }) {
            throw ValidationError.missingKind(missing)
        }
        let hours = [
            ("quietHours.startHour", quietHours.startHour),
            ("quietHours.endHour", quietHours.endHour),
            ("dailyReadyHour", dailyReadyHour),
        ]
        if let bad = hours.first(where: { !(0...23).contains($0.1) }) {
            throw ValidationError.hourOutOfRange(field: bad.0, hour: bad.1)
        }
        guard quietHours.startHour != quietHours.endHour else { throw ValidationError.emptyQuietHours }
        guard !quietHours.contains(hour: dailyReadyHour) else {
            throw ValidationError.dailyHourIsQuiet(dailyReadyHour)
        }
        let amounts = [
            ("minSpacingHours", minSpacingHours),
            ("maxPerAbsence", Double(maxPerAbsence)),
            ("comebackAfterHours", comebackAfterHours),
            ("permissionCard.maxOffers", Double(permissionCard.maxOffers)),
            ("permissionCard.retryAfterHours", permissionCard.retryAfterHours),
        ]
        if let bad = amounts.first(where: { $0.1 <= 0 }) {
            throw ValidationError.notPositive(field: bad.0)
        }
    }
}
```

- [ ] **Step 4: `NotificationPlanner.swift`**

```swift
import Foundation

/// Lo que el planificador necesita saber de la partida al irse, ya resuelto por
/// la app: EconomyKit no conoce `UserDefaults`, ni el centro de notificaciones,
/// ni la hora del sistema.
public struct NotificationSnapshot: Sendable, Equatable {
    /// Cuándo se fue el jugador (epoch).
    public var now: TimeInterval
    /// La torre produce afuera: sin pasivo no hay caja fuerte que se llene.
    public var producesOffline: Bool
    public var offlineCapHours: Double
    /// El diario de hoy ya se cobró (al volver se cobra solo).
    public var dailyClaimedToday: Bool

    public init(now: TimeInterval, producesOffline: Bool, offlineCapHours: Double, dailyClaimedToday: Bool) {
        self.now = now
        self.producesOffline = producesOffline
        self.offlineCapHours = offlineCapHours
        self.dailyClaimedToday = dailyClaimedToday
    }
}

/// Lo que el jugador eligió en Ajustes.
public struct NotificationPreferences: Sendable, Equatable {
    public var masterEnabled: Bool
    public var disabledKinds: Set<NotificationKind>

    public init(masterEnabled: Bool = true, disabledKinds: Set<NotificationKind> = []) {
        self.masterEnabled = masterEnabled
        self.disabledKinds = disabledKinds
    }

    public func allows(_ kind: NotificationKind) -> Bool {
        masterEnabled && !disabledKinds.contains(kind)
    }
}

/// Un aviso con su hora (epoch).
public struct PlannedNotification: Sendable, Equatable {
    public let kind: NotificationKind
    public let fireAt: TimeInterval

    public init(kind: NotificationKind, fireAt: TimeInterval) {
        self.kind = kind
        self.fireAt = fireAt
    }
}

/// Qué se avisa y cuándo durante una ausencia (PLAN-v2 E11).
///
/// 1. Cada motivo propone su hora (`moments`).
/// 2. El maestro o el tipo apagados lo sacan.
/// 3. El tope por ausencia elige por **prioridad** (el orden del catálogo): con
///    más motivos que lugares, se queda el más importante, no el más temprano.
/// 4. Lo que cae en el horario silencioso se corre a su final.
/// 5. Dos avisos quedan a `minSpacingHours` o más: el segundo **se corre**, no se
///    descarta, porque todo motivo sigue siendo cierto hasta que el jugador vuelve.
public enum NotificationPlanner {
    public static func plan(
        _ snapshot: NotificationSnapshot,
        config: NotificationsConfig,
        preferences: NotificationPreferences,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard preferences.masterEnabled else { return [] }
        let priority = config.kinds
        let rank: (NotificationKind) -> Int = { priority.firstIndex(of: $0) ?? priority.count }
        let candidates = moments(for: snapshot, config: config, calendar: calendar).filter {
            priority.contains($0.kind) && preferences.allows($0.kind) && $0.fireAt > snapshot.now
        }
        let kept = candidates
            .sorted { rank($0.kind) < rank($1.kind) }
            .prefix(max(0, config.maxPerAbsence))
        let shifted = kept.map {
            PlannedNotification(kind: $0.kind, fireAt: outsideQuietHours($0.fireAt, config: config, calendar: calendar))
        }
        let ordered = shifted.sorted { ($0.fireAt, rank($0.kind)) < ($1.fireAt, rank($1.kind)) }
        let spacing = config.minSpacingHours * 3600
        var planned: [PlannedNotification] = []
        for moment in ordered {
            let earliest = planned.last.map { max(moment.fireAt, $0.fireAt + spacing) } ?? moment.fireAt
            planned.append(PlannedNotification(
                kind: moment.kind,
                fireAt: outsideQuietHours(earliest, config: config, calendar: calendar)
            ))
        }
        return planned
    }

    /// La hora que propone cada motivo, antes de las reglas.
    public static func moments(
        for snapshot: NotificationSnapshot,
        config: NotificationsConfig,
        calendar: Calendar
    ) -> [PlannedNotification] {
        var moments: [PlannedNotification] = []
        if snapshot.producesOffline {
            moments.append(PlannedNotification(
                kind: .vaultFull,
                fireAt: snapshot.now + snapshot.offlineCapHours * 3600
            ))
        }
        if let daily = nextDailyReady(snapshot, hour: config.dailyReadyHour, calendar: calendar) {
            moments.append(PlannedNotification(kind: .dailyReady, fireAt: daily))
        }
        moments.append(PlannedNotification(
            kind: .comeback,
            fireAt: snapshot.now + config.comebackAfterHours * 3600
        ))
        return moments
    }

    /// La hora del diario del primer día sin cobrar: hoy si todavía no se cobró
    /// y no pasó la hora; si no, mañana.
    static func nextDailyReady(_ snapshot: NotificationSnapshot, hour: Int, calendar: Calendar) -> TimeInterval? {
        let now = Date(timeIntervalSince1970: snapshot.now)
        let today = calendar.startOfDay(for: now)
        guard let day = calendar.date(byAdding: .day, value: snapshot.dailyClaimedToday ? 1 : 0, to: today),
              let sameDay = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        else { return nil }
        guard sameDay <= now else { return sameDay.timeIntervalSince1970 }
        return calendar.date(byAdding: .day, value: 1, to: sameDay)?.timeIntervalSince1970
    }

    /// `time`, corrido al final del horario silencioso si cae adentro.
    public static func outsideQuietHours(
        _ time: TimeInterval,
        config: NotificationsConfig,
        calendar: Calendar
    ) -> TimeInterval {
        let date = Date(timeIntervalSince1970: time)
        guard config.quietHours.contains(hour: calendar.component(.hour, from: date)),
              let end = calendar.nextDate(
                  after: date,
                  matching: DateComponents(hour: config.quietHours.endHour, minute: 0, second: 0),
                  matchingPolicy: .nextTime
              )
        else { return time }
        return end.timeIntervalSince1970
    }
}

/// Cuándo se ofrece la tarjeta del permiso completo: la primera vez que toca y
/// una sola vez más, pasado `retryAfterHours`.
public enum PermissionCardPolicy {
    public static func isDue(
        offersMade: Int,
        lastOfferAt: TimeInterval?,
        now: TimeInterval,
        config: NotificationsConfig.PermissionCard
    ) -> Bool {
        guard offersMade < config.maxOffers else { return false }
        guard offersMade > 0 else { return true }
        guard let lastOfferAt else { return false }
        return now - lastOfferAt >= config.retryAfterHours * 3600
    }
}
```

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter "NotificationPlannerTests|NotificationsConfigTests|PermissionCardPolicyTests"`
Expected: PASS — 24 tests en 3 suites (13 + 8 + 3; el de las 24 horas cuenta como uno con 24
casos), 0 fallas. Contá que aparezcan las tres suites. Después `swift test --package-path Packages/EconomyKit`
entero (nada viejo se rompe) y `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/NotificationsConfig.swift \
  Packages/EconomyKit/Sources/EconomyKit/NotificationPlanner.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/NotificationPlannerTests.swift
git diff --cached --stat
git commit -m "feat(notif): el catálogo y el planificador de la ausencia, puros en EconomyKit"
```

---

### Task 2: `notifications.json` validado al arrancar y sus textos en es + en

**Objetivo:** el catálogo real viaja en el bundle, lo carga y valida `GameContentLoader`
(como skins y cofres), y cada motivo tiene su título y su cuerpo con el humor de la casa,
exigidos por `LocalizationCompletenessTests` y vigilados para que nunca vendan nada.

**Files:**
- Create: `FisuEvolution/Resources/Config/notifications.json`
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`GameContent.notifications`, decode y validación)
- Create: `FisuEvolution/Managers/NotificationCopy.swift`
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (+6 claves) 🔥
- Modify: `FisuEvolutionTests/LocalizationCompletenessTests.swift` (familia `notifications`)
- Create: `FisuEvolutionTests/NotificationsContentTests.swift`

**Interfaces:**
- Consumes: `NotificationsConfig`, `NotificationKind` (T1).
- Produces: `GameContent.notifications: NotificationsConfig`.
- Produces: `extension NotificationKind { var titleKey: String; var bodyKey: String; var settingsKey: String }` (app) — `notif.<id>.title`, `notif.<id>.body`, `settings.notifications.<id>`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/NotificationsContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El catálogo de notificaciones que viaja en el bundle (PLAN-v2 E11).
@Suite("Notificaciones: el catálogo del bundle")
struct NotificationsContentTests {
    let config: NotificationsConfig

    init() throws {
        config = try GameContentLoader.load(from: .main).notifications
    }

    @Test("los tres motivos de la 2.0, en su orden de prioridad")
    func catalogOrder() {
        #expect(config.kinds == [.vaultFull, .dailyReady, .comeback])
    }

    @Test("las reglas de PLAN-v2 E11, pineadas")
    func rules() {
        #expect(config.quietHours == NotificationsConfig.QuietHours(startHour: 22, endHour: 9))
        #expect(config.minSpacingHours == 4)
        #expect(config.maxPerAbsence == 3)
        #expect(config.dailyReadyHour == 19)
        #expect(config.comebackAfterHours == 72)
        #expect(config.permissionCard == NotificationsConfig.PermissionCard(maxOffers: 2, retryAfterHours: 72))
    }

    /// Guía 4.5.4 de App Store: una notificación no puede promocionar. Sólo
    /// cuenta el estado del juego.
    @Test("ningún aviso habla de anuncios, ofertas ni precios")
    func copyNeverSells() throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        for kind in config.kinds {
            for key in [kind.titleKey, kind.bodyKey] {
                let values = LocalizationCompletenessTests.languages.flatMap { language in
                    catalog.strings[key]?.localizations?[language]?.units.map(\.value) ?? []
                }
                #expect(!values.isEmpty, "\(key) no tiene texto")
                for value in values {
                    let lowered = value.lowercased()
                    let hits = Self.promotional.filter { lowered.contains($0) }
                    #expect(hits.isEmpty, "\(key): «\(value)» habla de \(hits)")
                }
            }
        }
    }

    private static let promotional = [
        "oferta", "offer", "precio", "price", "gratis", "free", "descuento", "discount",
        "anuncio", "video", "compr", "buy", "purchase", "$", "usd",
    ]
}
```

`LocalizationCompletenessTests.swift`, en `DynamicFamily`, después de `case tutorialTips`:

```swift
        /// `notif.<id>.title` y `.body` (`NotificationCopy`), sobre `notifications.json`.
        case notifications
```

y en el `switch` de `keys(in:)`, después de `case .tutorialTips`:

```swift
            case .notifications:
                return content.notifications.kinds.flatMap { [$0.titleKey, $0.bodyKey] }
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/NotificationsContentTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`.
Expected: no compila — `value of type 'GameContent' has no member 'notifications'` y
`value of type 'NotificationKind' has no member 'titleKey'`.

- [ ] **Step 3: El catálogo y la carga**

`FisuEvolution/Resources/Config/notifications.json`:

```json
{
  "schemaVersion": 1,
  "notifications": [
    { "id": "vault_full" },
    { "id": "daily_ready" },
    { "id": "comeback" }
  ],
  "quietHours": { "startHour": 22, "endHour": 9 },
  "minSpacingHours": 4,
  "maxPerAbsence": 3,
  "dailyReadyHour": 19,
  "comebackAfterHours": 72,
  "permissionCard": { "maxOffers": 2, "retryAfterHours": 72 }
}
```

`GameContentLoader.swift` — en `GameContent`, después de `achievements`:

```swift
    /// Las notificaciones locales: el catálogo y sus reglas (PLAN-v2 E11).
    let notifications: NotificationsConfig
```

En `load(from:)`, después de decodificar `achievements`:

```swift
        let notifications: NotificationsConfig = try decode("notifications", from: bundle)
```

después de `try validate(achievements: …)`:

```swift
        do {
            try notifications.validate()
        } catch {
            throw GameError.contentInvalid(file: "notifications.json", reason: "\(error)")
        }
```

y `notifications: notifications` como último argumento de `GameContent(…)`.

`FisuEvolution/Managers/NotificationCopy.swift`:

```swift
import EconomyKit

/// Las claves de texto de cada motivo de notificación (PLAN-v2 E11), armadas en
/// un solo lugar: el manager las usa para el aviso, Ajustes para su fila y
/// `LocalizationCompletenessTests` para exigir es + en en todas.
extension NotificationKind {
    var titleKey: String { "notif.\(rawValue).title" }
    var bodyKey: String { "notif.\(rawValue).body" }
    /// El identifier de la fila de Ajustes, que es también la clave de su título.
    var settingsKey: String { "settings.notifications.\(rawValue)" }
}
```

- [ ] **Step 4: Los textos**

`build/e11-t2-strings.json` (con el script de "El catálogo de strings"):

```json
{
  "set": {
    "notif.comeback.body": { "es": "Hace días que no pasás. La torre sigue en pie… más o menos.", "en": "It's been days. The tower's still standing… mostly." },
    "notif.comeback.title": { "es": "Tus fisuras te extrañan", "en": "Your crew misses you" },
    "notif.daily_ready.body": { "es": "Está ahí, sin cobrar, juntando polvo. Entrá y es tuyo.", "en": "It's sitting there unclaimed, gathering dust. Hop in and it's yours." },
    "notif.daily_ready.title": { "es": "Tu premio del día te espera", "en": "Your daily prize is waiting" },
    "notif.vault_full.body": { "es": "Tus fisuras juntaron todo lo que entra. Pasá a vaciarla antes de que se tienten.", "en": "Your crew stuffed it to the brim. Come empty it before they get ideas." },
    "notif.vault_full.title": { "es": "¡La caja fuerte no cierra más!", "en": "The safe is full!" }
  }
}
```

Run: `python3 build/xcstrings_e11.py build/e11-t2-strings.json`
Expected: `6 claves escritas, 0 borradas`; `git diff --stat FisuEvolution/Resources/Localizable.xcstrings`
muestra sólo inserciones.

El regreso no dice "tres días" a propósito: las horas viven en el JSON y un número escrito
en dos idiomas se queda viejo en silencio (la misma razón de `IAPCopy`).

- [ ] **Step 5: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `NotificationsContentTests` y
`LocalizationCompletenessTests` → PASS (la familia `notifications` aparece entre los casos del
test parametrizado). Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Resources/Config/notifications.json FisuEvolution/Managers/GameContentLoader.swift \
  FisuEvolution/Managers/NotificationCopy.swift FisuEvolution/Resources/Localizable.xcstrings \
  FisuEvolutionTests/LocalizationCompletenessTests.swift FisuEvolutionTests/NotificationsContentTests.swift
git diff --cached --stat
git commit -m "feat(notif): notifications.json validado al arrancar y sus textos en es + en"
```

---

### Task 3: El manager de la 2.0 — prendidas por defecto, el permiso en dos pasos y la ausencia planificada

**Objetivo:** `NotificationsManager` deja de ser "un recordatorio a las 19 que se prende con
permiso" y pasa a separar preferencia, permiso y ausencia (tabla "Lo que la 2.0 cambia"). No
habla con iOS bajo XCTest ni `--uitest*` salvo fixture, y resuelve él mismo el
`--uitest-reset` de sus claves. Ajustes sólo migra sus tres llamadas: la sección nueva es T4.

**Files:**
- Modify: `FisuEvolution/Managers/NotificationsManager.swift` (el manager entero; el protocolo y `SystemNotificationCenter` suman un método)
- Modify: `FisuEvolution/UI/Menu/SettingsView.swift` (las tres llamadas: hint, toggle, `.task`) 🔥
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (−`notif.daily.title`, −`notif.daily.body`, `settings.notifications.hint` nuevo) 🔥
- Modify: `FisuEvolutionTests/SettingsPersistenceTests.swift` (sale la suite `NotificationsManager`, líneas 120-320)
- Create: `FisuEvolutionTests/NotificationsManagerTests.swift`

**Interfaces:**
- Consumes: `NotificationsConfig`, `NotificationSnapshot`, `NotificationPreferences`, `NotificationPlanner`, `PermissionCardPolicy` (T1); `GameContent.notifications`, `NotificationKind.titleKey/bodyKey` (T2).
- Produces (todo `@MainActor`): `NotificationsManager.init(center:defaults:isLive:)`, `convenience init(launchArguments:)`; `isEnabled: Bool`, `disabledKinds`, `authorization: UNAuthorizationStatus`, `isDenied`, `canDeliver`, `preferences`; `setEnabled(_:) async`, `setEnabled(_:for:)`, `isEnabled(for:)`; `refreshAuthorization() async`, `requestProvisional() async`; `scheduleAbsence(_:config:calendar:) async`, `cancelAbsence()`, `appBecameActive() async`; `permissionCardDue(now:config:)`, `recordPermissionCardOffer(now:)`, `acceptPermissionCard() async`.
- Produces (`nonisolated static`): `defaultsKey`, `cardOffersKey`, `cardLastOfferKey`, `cardAcceptedKey`, `requestPrefix` = `"fisu.notif."`, `fullOptions`, `enabledKey(for:)`, `request(for:in:)`, `launchAllowsSystem(arguments:environment:)`, `wipePreferences(in:)`; DEBUG: `uiTestStatus(in:)`.
- Produces: `NotificationScheduling.removeAllDeliveredNotifications()`; DEBUG: `InMemoryNotificationCenter(status:)`.
- Produces (tests): `NotificationsManagerTests.SpyNotificationCenter` con `beforeAdding`, `removeDeliveredCount` y el estado provisional.

- [ ] **Step 1: Los tests, en rojo**

Borrar de `SettingsPersistenceTests.swift` todo el bloque `// MARK: - Notificaciones` (la
`struct NotificationsManagerTests` entera, líneas 120-320): sus tests prueban el recordatorio
fijo y el `isEnabled` = "iOS concedió", que la 2.0 reemplaza. `ScratchDefaults` y
`LegalDocumentTests` se quedan donde están.

`FisuEvolutionTests/NotificationsManagerTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
import UserNotifications
@testable import FisuEvolution

/// El manager de la 2.0 (PLAN-v2 E11): la preferencia del jugador, el permiso de
/// iOS en dos pasos y la ausencia programada con el planificador.
///
/// ⚠️ Cada test arma su dominio de `UserDefaults` y su centro espía:
/// `UNUserNotificationCenter` no se puede fabricar ni preconfigurar, y un test
/// que escriba en `.standard` le deja al dueño las notificaciones apagadas.
@Suite("NotificationsManager")
@MainActor
struct NotificationsManagerTests {
    let config: NotificationsConfig
    let calendar: Calendar
    /// Lunes 5 de octubre de 2026, 10:00 en Buenos Aires: la caja a las 20, el
    /// diario el 6 a las 19 y el regreso el 8 a las 10. Nada en el silencio.
    let leaving: TimeInterval

    init() throws {
        config = try GameContentLoader.load(from: .main).notifications
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Argentina/Buenos_Aires"))
        self.calendar = calendar
        let components = DateComponents(year: 2026, month: 10, day: 5, hour: 10)
        leaving = try #require(calendar.date(from: components)).timeIntervalSince1970
    }

    private func snapshot(producesOffline: Bool = true) -> NotificationSnapshot {
        NotificationSnapshot(now: leaving, producesOffline: producesOffline, offlineCapHours: 10, dailyClaimedToday: true)
    }

    private func makeManager(
        _ spy: SpyNotificationCenter,
        _ scratch: SettingsPersistenceTests.ScratchDefaults,
        isLive: Bool = true
    ) -> NotificationsManager {
        NotificationsManager(center: spy, defaults: scratch.defaults, isLive: isLive)
    }

    private static let allIDs: Set<String> = ["fisu.notif.vault_full", "fisu.notif.daily_ready", "fisu.notif.comeback"]

    // MARK: La preferencia

    @Test("recién instalado: prendidas por defecto y sin preguntarle nada a iOS")
    func onByDefault() {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()

        let notifications = makeManager(spy, scratch)

        #expect(notifications.isEnabled)
        #expect(NotificationKind.allCases.allSatisfy { notifications.isEnabled(for: $0) })
        #expect(spy.requestedOptions == nil)
    }

    @Test("el false de la v1 se respeta: ni permiso ni avisos")
    func v1FalseIsRespected() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .notDetermined
        let notifications = makeManager(spy, scratch)

        await notifications.requestProvisional()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(notifications.isEnabled == false)
        #expect(spy.requestedOptions == nil)
        #expect(spy.pending.isEmpty)
    }

    @Test("un tipo apagado persiste y no se programa")
    func disabledKindPersistsAndIsSkipped() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        makeManager(spy, scratch).setEnabled(false, for: .comeback)

        let reopened = makeManager(spy, scratch)
        await reopened.refreshAuthorization()
        await reopened.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(reopened.isEnabled(for: .comeback) == false)
        #expect(Set(spy.pending.keys) == ["fisu.notif.vault_full", "fisu.notif.daily_ready"])
    }

    // MARK: El permiso en dos pasos

    @Test("al terminar el núcleo pide el provisional: sin diálogo")
    func provisionalAtCoreFinish() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .notDetermined
        let notifications = makeManager(spy, scratch)

        await notifications.requestProvisional()

        #expect(spy.requestedOptions == [.alert, .sound, .badge, .provisional])
        #expect(notifications.authorization == .provisional)
        #expect(notifications.canDeliver)
    }

    @Test("si iOS ya contestó, el provisional no se vuelve a pedir")
    func provisionalOnlyWhenUndetermined() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .authorized

        await makeManager(spy, scratch).requestProvisional()

        #expect(spy.requestedOptions == nil)
    }

    @Test("denegado: lo dice, no programa y no le toca la preferencia al jugador")
    func deniedIsReportedNotScheduled() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .denied
        let notifications = makeManager(spy, scratch)

        await notifications.refreshAuthorization()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(notifications.isDenied)
        #expect(notifications.isEnabled)
        #expect(spy.pending.isEmpty)
    }

    @Test("prender el maestro con iOS sin preguntar pide el permiso completo")
    func turningOnAsksForFullPermission() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .notDetermined
        let notifications = makeManager(spy, scratch)

        await notifications.setEnabled(true)

        #expect(notifications.isEnabled)
        #expect(scratch.defaults.bool(forKey: NotificationsManager.defaultsKey))
        #expect(spy.requestedOptions == [.alert, .sound, .badge])
    }

    @Test("prender el maestro con el provisional no muestra ningún diálogo")
    func turningOnWithProvisionalAsksNothing() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .provisional

        await makeManager(spy, scratch).setEnabled(true)

        #expect(spy.requestedOptions == nil)
    }

    @Test("un error del sistema no cambia ni la preferencia ni el permiso")
    func systemErrorChangesNothing() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.authorizationError = SpyError.nope
        let notifications = makeManager(spy, scratch)

        await notifications.setEnabled(true)

        #expect(notifications.isEnabled)
        #expect(notifications.authorization == .notDetermined)
    }

    // MARK: La ausencia

    @Test("programar la ausencia arma los avisos del planificador, con su texto")
    func schedulingBuildsThePlannedRequests() async throws {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(Set(spy.pending.keys) == Self.allIDs)
        let vault = try #require(spy.pending["fisu.notif.vault_full"])
        let trigger = try #require(vault.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 10 * 3600)
        #expect(trigger.repeats == false)
        // El texto sale del catálogo: una clave mal escrita llegaría cruda al teléfono.
        for request in spy.pending.values {
            #expect(!request.content.title.isEmpty && !request.content.title.hasPrefix("notif."))
            #expect(!request.content.body.isEmpty && !request.content.body.hasPrefix("notif."))
        }
    }

    @Test("sin pasivo, la caja fuerte no se avisa")
    func noPassiveNoVault() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.scheduleAbsence(snapshot(producesOffline: false), config: config, calendar: calendar)

        #expect(spy.pending["fisu.notif.vault_full"] == nil)
    }

    @Test("programar borra lo de antes, también el recordatorio fijo de la v1")
    func schedulingReplacesTheV1Reminder() async throws {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        try await spy.add(UNNotificationRequest(identifier: "fisu.daily.reminder", content: UNMutableNotificationContent(), trigger: nil))
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(spy.pending["fisu.daily.reminder"] == nil)
        #expect(Set(spy.pending.keys) == Self.allIDs)
    }

    @Test("apagar el maestro borra todo lo pendiente")
    func turningOffClearsPending() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)
        #expect(!spy.pending.isEmpty)

        await notifications.setEnabled(false)

        #expect(spy.pending.isEmpty)
        #expect(scratch.defaults.object(forKey: NotificationsManager.defaultsKey) as? Bool == false)
    }

    @Test("volver a la app borra lo pendiente y lo entregado")
    func returningClearsEverything() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        await notifications.appBecameActive()

        #expect(spy.pending.isEmpty)
        #expect(spy.removeDeliveredCount == 1)
    }

    /// ⚠️ Programar tiene un `await` por aviso. Si el jugador vuelve en el medio,
    /// gana la vuelta: un aviso que entra en la cola después sonaría con el
    /// jugador adentro.
    @Test("volver mientras se programaba la ausencia gana: no queda nada pendiente")
    func returningDuringSchedulingWins() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        spy.beforeAdding = { notifications.cancelAbsence() }

        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)

        #expect(spy.pending.isEmpty, "quedó programado un aviso de una ausencia que ya terminó")
    }

    // MARK: Fuera del juego de verdad

    @Test("sin permiso de hablar con el sistema, sólo guarda la preferencia")
    func notLiveNeverTouchesTheSystem() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        let notifications = makeManager(spy, scratch, isLive: false)

        await notifications.requestProvisional()
        await notifications.setEnabled(false)
        await notifications.setEnabled(true)
        await notifications.scheduleAbsence(snapshot(), config: config, calendar: calendar)
        await notifications.appBecameActive()

        #expect(spy.requestedOptions == nil)
        #expect(spy.removeAllCount == 0)
        #expect(spy.pending.isEmpty)
        #expect(notifications.isEnabled)
        #expect(scratch.defaults.bool(forKey: NotificationsManager.defaultsKey))
    }

    @Test("bajo XCTest o --uitest no se habla con iOS, salvo que el test lo pida")
    func launchGate() {
        #expect(NotificationsManager.launchAllowsSystem(arguments: [], environment: [:]))
        #expect(!NotificationsManager.launchAllowsSystem(arguments: ["--uitest-reset"], environment: [:]))
        #expect(!NotificationsManager.launchAllowsSystem(arguments: [], environment: ["XCTestConfigurationFilePath": "/x"]))
        #expect(NotificationsManager.uiTestStatus(in: ["--uitest-notifications-provisional"]) == .provisional)
        #expect(NotificationsManager.uiTestStatus(in: ["--uitest-notifications-denied"]) == .denied)
        #expect(NotificationsManager.uiTestStatus(in: ["--uitest-reset"]) == nil)
    }

    @Test("--uitest-reset borra todas las claves de notificaciones")
    func wipeClearsEveryKey() {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let keys = [
            "settings.notificationsEnabled", "settings.notificationsEnabled.vault_full",
            "settings.notificationsEnabled.daily_ready", "settings.notificationsEnabled.comeback",
            "notifications.card.offers", "notifications.card.lastOfferAt", "notifications.card.accepted",
        ]
        for key in keys { scratch.defaults.set(false, forKey: key) }

        NotificationsManager.wipePreferences(in: scratch.defaults)

        for key in keys { #expect(scratch.stored[key] == nil, "\(key) sobrevivió al reset") }
    }

    // MARK: La tarjeta del permiso

    @Test("con el provisional, la tarjeta se ofrece una vez y otra a los 3 días; nunca una tercera")
    func permissionCardSchedule() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        let card = config.permissionCard
        let retry = leaving + card.retryAfterHours * 3600

        #expect(notifications.permissionCardDue(now: leaving, config: card))
        notifications.recordPermissionCardOffer(now: leaving)
        #expect(!notifications.permissionCardDue(now: leaving + 3600, config: card))
        #expect(notifications.permissionCardDue(now: retry, config: card))
        notifications.recordPermissionCardOffer(now: retry)
        #expect(!notifications.permissionCardDue(now: retry + 1000 * 3600, config: card))
    }

    @Test("la tarjeta no se ofrece con el permiso completo, con iOS denegado ni con el maestro apagado")
    func permissionCardNeedsSomethingToUpgrade() async {
        for status in [UNAuthorizationStatus.authorized, .denied] {
            let scratch = SettingsPersistenceTests.ScratchDefaults()
            defer { scratch.clear() }
            let spy = SpyNotificationCenter()
            spy.status = status
            let notifications = makeManager(spy, scratch)
            await notifications.refreshAuthorization()
            #expect(!notifications.permissionCardDue(now: leaving, config: config.permissionCard), "status \(status.rawValue)")
        }
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        scratch.defaults.set(false, forKey: NotificationsManager.defaultsKey)
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()
        #expect(!notifications.permissionCardDue(now: leaving, config: config.permissionCard))
    }

    @Test("«Sí, avisame» abre el diálogo del sistema y la tarjeta no vuelve")
    func acceptingAsksAndRetires() async {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        defer { scratch.clear() }
        let spy = SpyNotificationCenter()
        spy.status = .provisional
        let notifications = makeManager(spy, scratch)
        await notifications.refreshAuthorization()

        await notifications.acceptPermissionCard()

        #expect(spy.requestedOptions == [.alert, .sound, .badge])
        #expect(notifications.authorization == .authorized)
        // Aunque iOS volviera al provisional, la tarjeta ya cumplió.
        spy.status = .provisional
        await notifications.refreshAuthorization()
        #expect(!notifications.permissionCardDue(now: leaving + 1000 * 3600, config: config.permissionCard))
    }

    // MARK: Andamio

    enum SpyError: Error { case nope }

    /// El centro de notificaciones, de mentira. Modela lo que importa del de
    /// verdad: `add` **reemplaza** por identifier (por eso es un diccionario), el
    /// permiso puede negarse o fallar, y el provisional se concede sin diálogo.
    @MainActor
    final class SpyNotificationCenter: NotificationScheduling {
        var granted = true
        var authorizationError: Error?
        var status: UNAuthorizationStatus = .notDetermined
        /// Se ejecuta adentro del pedido de permiso, antes de contestar.
        var beforeAnswering: (() -> Void)?
        /// Se ejecuta adentro de `add`, antes de guardar: el hueco donde el
        /// jugador vuelve a la app mientras se programa la ausencia.
        var beforeAdding: (() -> Void)?
        private(set) var requestedOptions: UNAuthorizationOptions?
        private(set) var pending: [String: UNNotificationRequest] = [:]
        private(set) var removeAllCount = 0
        private(set) var removeDeliveredCount = 0

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requestedOptions = options
            beforeAnswering?()
            if let authorizationError { throw authorizationError }
            if granted {
                status = options.contains(.provisional) ? .provisional : .authorized
            } else {
                status = .denied
            }
            return granted
        }

        func add(_ request: UNNotificationRequest) async throws {
            beforeAdding?()
            pending[request.identifier] = request
        }

        func removeAllPendingNotificationRequests() {
            removeAllCount += 1
            pending.removeAll()
        }

        func removeAllDeliveredNotifications() {
            removeDeliveredCount += 1
        }

        func authorizationStatus() async -> UNAuthorizationStatus { status }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/NotificationsManagerTests`.
Expected: no compila — `extra argument 'isLive' in call` y
`value of type 'NotificationsManager' has no member 'requestProvisional'` (y `setEnabled`,
`scheduleAbsence`, `isEnabled(for:)`…). El espía nuevo compila igual: tener un método de más
que el protocolo no es un error.

- [ ] **Step 3: El protocolo y el centro real**

En `NotificationsManager.swift`, el protocolo suma (después de `removeAllPendingNotificationRequests`):

```swift
    func removeAllDeliveredNotifications()
```

y `SystemNotificationCenter`, después de su `removeAllPendingNotificationRequests()`:

```swift
    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
```

Los comentarios ⚠️ del protocolo y del envoltorio **no se tocan**. Debajo de
`SystemNotificationCenter`, el centro de los UI tests:

```swift
#if DEBUG
/// El centro de los UI tests que piden notificaciones
/// (`--uitest-notifications-provisional|denied`): contesta sin diálogo del
/// sistema —que en un runner es un muro— y guarda la cola en memoria. Fuera de
/// esos tests no se construye nunca.
@MainActor
final class InMemoryNotificationCenter: NotificationScheduling {
    private var status: UNAuthorizationStatus
    private var pending: [String: UNNotificationRequest] = [:]

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        guard status != .denied else { return false }
        status = options.contains(.provisional) ? .provisional : .authorized
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending[request.identifier] = request
    }

    func removeAllPendingNotificationRequests() {
        pending.removeAll()
    }

    func removeAllDeliveredNotifications() {}

    func authorizationStatus() async -> UNAuthorizationStatus { status }
}
#endif
```

- [ ] **Step 4: El manager**

Reemplazar la clase `NotificationsManager` entera (desde su docstring, línea 87, hasta el final
del archivo) por:

```swift
/// **Las notificaciones de la 2.0** (PLAN-v2 E11): locales, prendidas por
/// defecto y desactivables, una por motivo para volver.
///
/// Separa tres cosas que la v1 mezclaba en un solo booleano:
/// - **la preferencia del jugador** (`isEnabled` y una por tipo), en
///   `UserDefaults`: prendida si la clave no existe; un `false` escrito —el
///   veterano que las apagó en la v1— se respeta;
/// - **lo que iOS concedió** (`authorization`), que se lee y no se escribe;
/// - **la ausencia programada**, que se arma al irse con `NotificationPlanner` y
///   se borra entera al volver.
///
/// El permiso va en dos pasos: el provisional al terminar el núcleo del
/// tutorial (sin diálogo, los avisos llegan en silencio al Centro de
/// notificaciones) y el completo desde la tarjeta del popup offline.
///
/// ⚠️ **Si `isLive` es falso, nada habla con iOS**: bajo XCTest y `--uitest*` el
/// juego no pide permiso ni programa, salvo que el UI test lo pida con
/// `--uitest-notifications-provisional|denied`. Las preferencias se guardan
/// igual: es lo que ejercen los tests de Ajustes.
@Observable @MainActor
final class NotificationsManager {
    /// El maestro. **Es la clave de la v1** a propósito: el `false` de un
    /// veterano que las apagó tiene que seguir valiendo.
    nonisolated static let defaultsKey = "settings.notificationsEnabled"
    nonisolated static let cardOffersKey = "notifications.card.offers"
    nonisolated static let cardLastOfferKey = "notifications.card.lastOfferAt"
    nonisolated static let cardAcceptedKey = "notifications.card.accepted"
    /// Un id fijo por motivo (`fisu.notif.vault_full`…): reprogramar reemplaza
    /// en vez de duplicar.
    nonisolated static let requestPrefix = "fisu.notif."
    nonisolated static var fullOptions: UNAuthorizationOptions { [.alert, .sound, .badge] }

    nonisolated static func enabledKey(for kind: NotificationKind) -> String {
        "\(defaultsKey).\(kind.rawValue)"
    }

    private(set) var isEnabled: Bool
    private(set) var disabledKinds: Set<NotificationKind>
    /// Lo último que contestó iOS. Se refresca al volver, al abrir Ajustes y
    /// después de cada pedido: el permiso se puede revocar desde Ajustes de iOS
    /// sin que la app se entere.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    var isDenied: Bool { authorization == .denied }

    var canDeliver: Bool {
        switch authorization {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    var preferences: NotificationPreferences {
        NotificationPreferences(masterEnabled: isEnabled, disabledKinds: disabledKinds)
    }

    @ObservationIgnored private let center: any NotificationScheduling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let isLive: Bool
    /// Qué ausencia es la vigente. Programar tiene un `await` por aviso, y volver
    /// a la app en el medio tiene que ganarle.
    @ObservationIgnored private var generation = 0

    init(center: any NotificationScheduling, defaults: UserDefaults = .standard, isLive: Bool = true) {
        self.center = center
        self.defaults = defaults
        self.isLive = isLive
        isEnabled = defaults.object(forKey: Self.defaultsKey) as? Bool ?? true
        // El nombre de la clase y no `Self`: adentro de un closure, antes de
        // terminar el init, `Self` arrastra a `self`.
        let disabled = NotificationKind.allCases.filter {
            defaults.object(forKey: NotificationsManager.enabledKey(for: $0)) as? Bool == false
        }
        disabledKinds = Set(disabled)
    }

    /// El del juego. Se construye antes del bootstrap (`FisuEvolutionApp`), así
    /// que el `--uitest-reset` de sus claves lo resuelve acá: el de
    /// `applyLaunchArgumentDefaults` llega tarde, cuando ya las leyó.
    convenience init(launchArguments arguments: [String] = ProcessInfo.processInfo.arguments) {
        let defaults = UserDefaults.standard
        #if DEBUG
        if arguments.contains("--uitest-reset") {
            NotificationsManager.wipePreferences(in: defaults)
        }
        if let status = NotificationsManager.uiTestStatus(in: arguments) {
            self.init(center: InMemoryNotificationCenter(status: status), defaults: defaults, isLive: true)
            return
        }
        #endif
        self.init(
            center: SystemNotificationCenter(),
            defaults: defaults,
            isLive: NotificationsManager.launchAllowsSystem(arguments: arguments)
        )
    }

    // MARK: La preferencia

    /// El maestro. Apagarlo borra todo lo pendiente; prenderlo con iOS sin
    /// preguntar pide el permiso completo (el jugador lo está pidiendo).
    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.defaultsKey)
        guard enabled else {
            cancelAbsence()
            return
        }
        guard isLive else { return }
        await refreshAuthorization()
        if authorization == .notDetermined {
            await askSystem(Self.fullOptions)
        }
    }

    func setEnabled(_ enabled: Bool, for kind: NotificationKind) {
        if enabled {
            disabledKinds.remove(kind)
        } else {
            disabledKinds.insert(kind)
        }
        defaults.set(enabled, forKey: Self.enabledKey(for: kind))
    }

    func isEnabled(for kind: NotificationKind) -> Bool {
        !disabledKinds.contains(kind)
    }

    // MARK: El permiso

    func refreshAuthorization() async {
        guard isLive else { return }
        authorization = await center.authorizationStatus()
        if authorization == .denied {
            // Un aviso pendiente sin permiso es basura en la cola.
            center.removeAllPendingNotificationRequests()
        }
    }

    /// El primer paso: al terminar el núcleo del tutorial, sin diálogo.
    func requestProvisional() async {
        guard isLive, isEnabled else { return }
        await refreshAuthorization()
        guard authorization == .notDetermined else { return }
        await askSystem(Self.fullOptions.union(.provisional))
    }

    @discardableResult
    private func askSystem(_ options: UNAuthorizationOptions) async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: options)
            await refreshAuthorization()
            return granted
        } catch {
            Log.lifecycle.error("notifications unavailable: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: La tarjeta del permiso completo

    /// Hay algo que mejorar (provisional o sin preguntar), el jugador no las
    /// apagó y la política de `notifications.json` dice que toca.
    func permissionCardDue(now: TimeInterval, config: NotificationsConfig.PermissionCard) -> Bool {
        guard isLive, isEnabled, !defaults.bool(forKey: Self.cardAcceptedKey) else { return false }
        guard authorization == .provisional || authorization == .notDetermined else { return false }
        return PermissionCardPolicy.isDue(
            offersMade: defaults.integer(forKey: Self.cardOffersKey),
            lastOfferAt: defaults.object(forKey: Self.cardLastOfferKey) as? Double,
            now: now,
            config: config
        )
    }

    /// Mostrada es ofrecida: cerrar el popup sin contestar gasta la oferta igual
    /// que "Ahora no".
    func recordPermissionCardOffer(now: TimeInterval) {
        defaults.set(defaults.integer(forKey: Self.cardOffersKey) + 1, forKey: Self.cardOffersKey)
        defaults.set(now, forKey: Self.cardLastOfferKey)
    }

    /// "Sí, avisame": el diálogo del sistema. Conteste lo que conteste, la
    /// tarjeta ya cumplió.
    func acceptPermissionCard() async {
        defaults.set(true, forKey: Self.cardAcceptedKey)
        guard isLive else { return }
        await askSystem(Self.fullOptions)
    }

    // MARK: La ausencia

    /// Al irse: borra lo anterior (también el recordatorio fijo de la v1) y
    /// programa lo que dice el planificador.
    func scheduleAbsence(
        _ snapshot: NotificationSnapshot,
        config: NotificationsConfig,
        calendar: Calendar = .current
    ) async {
        guard isLive else { return }
        generation &+= 1
        let mine = generation
        center.removeAllPendingNotificationRequests()
        guard canDeliver else { return }
        let plan = NotificationPlanner.plan(snapshot, config: config, preferences: preferences, calendar: calendar)
        for planned in plan {
            do {
                try await center.add(Self.request(for: planned.kind, in: planned.fireAt - snapshot.now))
            } catch {
                Log.lifecycle.error("notification \(planned.kind.rawValue) not scheduled: \(error.localizedDescription)")
            }
            // Volvió a la app mientras esto esperaba: su vuelta es más nueva que esta ausencia.
            guard mine == generation else {
                center.removeAllPendingNotificationRequests()
                return
            }
        }
        Log.lifecycle.info("notifications scheduled: \(plan.map(\.kind.rawValue).joined(separator: ", "), privacy: .public)")
    }

    /// La ausencia terminó: lo pendiente y lo entregado ya no dicen nada.
    func cancelAbsence() {
        generation &+= 1
        guard isLive else { return }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func appBecameActive() async {
        cancelAbsence()
        await refreshAuthorization()
    }

    /// ⚠️ `nonisolated` a propósito: la petición no es `Sendable`, y fabricada
    /// afuera del main actor nace suelta, que es lo que `add(_: sending …)`
    /// necesita (la misma trampa del `dailyRequest()` de la v1).
    nonisolated static func request(for kind: NotificationKind, in interval: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: String.LocalizationValue(kind.titleKey))
        content.body = String(localized: String.LocalizationValue(kind.bodyKey))
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        return UNNotificationRequest(identifier: requestPrefix + kind.rawValue, content: content, trigger: trigger)
    }

    // MARK: Lanzamiento

    /// Bajo XCTest o `--uitest*` el juego no le habla a iOS: ni permiso ni avisos.
    nonisolated static func launchAllowsSystem(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        let uiTest = arguments.contains { $0.hasPrefix("--uitest") }
        let unitTestHost = environment["XCTestConfigurationFilePath"] != nil
        return !uiTest && !unitTestHost
    }

    #if DEBUG
    nonisolated static func uiTestStatus(in arguments: [String]) -> UNAuthorizationStatus? {
        if arguments.contains("--uitest-notifications-provisional") { return .provisional }
        if arguments.contains("--uitest-notifications-denied") { return .denied }
        return nil
    }
    #endif

    /// Sólo para `--uitest-reset`: estas claves son preferencia de dispositivo y
    /// sobreviven a cualquier reset de partida.
    nonisolated static func wipePreferences(in defaults: UserDefaults) {
        defaults.removeObject(forKey: defaultsKey)
        for kind in NotificationKind.allCases {
            defaults.removeObject(forKey: enabledKey(for: kind))
        }
        defaults.removeObject(forKey: cardOffersKey)
        defaults.removeObject(forKey: cardLastOfferKey)
        defaults.removeObject(forKey: cardAcceptedKey)
    }
}
```

Al tope del archivo, `import EconomyKit` (antes de `import Foundation`). `FisuEvolutionApp`
no cambia: `NotificationsManager()` resuelve al `convenience init(launchArguments:)`. Su
comentario (líneas 10-11, "No pide permiso al arrancar —lo pide el toggle—") pasa a mentir: se
reemplaza por

```swift
    /// Las notificaciones locales (E11). Construirlo no le habla a iOS: el
    /// provisional y la ausencia los dispara el ciclo de vida.
```

y `FisuEvolutionApp.swift` suma a los archivos de esta tarea (sólo ese comentario).

- [ ] **Step 5: Ajustes migra sus tres llamadas**

`SettingsView.swift:240-257`, la fila de notificaciones:

```swift
                    ToggleRow(
                        titleKey: "settings.notifications",
                        identifier: "settings.notifications",
                        hintKey: notifications.isDenied
                            ? "settings.notifications.denied"
                            : "settings.notifications.hint",
                        isOn: notifications.isEnabled
                    ) { wantsOn in
                        // Es la preferencia del jugador: el toque la escribe
                        // siempre, y prenderla con iOS sin preguntar pide permiso.
                        Task { await notifications.setEnabled(wantsOn) }
                    }
```

y el `.task` de la línea 137 (con su comentario):

```swift
        // El permiso se puede revocar desde Ajustes de iOS sin que la app se
        // entere: al abrir la pantalla se vuelve a leer antes de mostrarlo.
        .task { await notifications.refreshAuthorization() }
```

- [ ] **Step 6: Los textos**

`build/e11-t3-strings.json`:

```json
{
  "remove": ["notif.daily.body", "notif.daily.title"],
  "set": {
    "settings.notifications.hint": { "es": "Te avisamos cuando pasa algo en la torre. Nunca de noche.", "en": "We'll let you know when something happens in your tower. Never at night." }
  }
}
```

Run: `python3 build/xcstrings_e11.py build/e11-t3-strings.json` → `1 claves escritas, 2 borradas`.
`grep -rn "notif.daily" FisuEvolution FisuEvolutionTests` → nada.

- [ ] **Step 7: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `NotificationsManagerTests`,
`SettingsPersistenceTests` y `LocalizationCompletenessTests` → PASS (21 tests de la suite del
manager). Receta R con `-only-testing:FisuEvolutionUITests/MenuUITests` → PASS (sigue
encontrando el switch `settings.notifications`, ahora `on`). Después
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Managers/NotificationsManager.swift FisuEvolution/UI/Menu/SettingsView.swift \
  FisuEvolution/App/FisuEvolutionApp.swift FisuEvolution/Resources/Localizable.xcstrings \
  FisuEvolutionTests/SettingsPersistenceTests.swift FisuEvolutionTests/NotificationsManagerTests.swift
git diff --cached --stat
git commit -m "feat(notif): el manager de la 2.0 — prendidas por defecto, provisional y la ausencia planificada"
```

---

### Task 4: Ajustes — el maestro, un toggle por motivo y la salida a Ajustes de iOS

**Objetivo:** "Notificaciones" deja de ser una fila de "En el juego" y pasa a tener su sección:
el maestro (prendido por defecto), un toggle por motivo en el orden del catálogo (escondidos
con el maestro apagado, sin perder lo elegido) y, si iOS las bloqueó, la fila lo dice y ofrece
un `ActionPill` "Abrir Ajustes" (`UIApplication.openNotificationSettingsURLString`), sin
alertas del sistema.

**Files:**
- Modify: `FisuEvolution/UI/Menu/SettingsView.swift` (sección nueva, la fila sale de `gameSection`, docstrings) 🔥
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (+5 claves, `settings.notifications.denied` nuevo) 🔥
- Modify: `FisuEvolutionTests/LocalizationCompletenessTests.swift` (`settingsRows` suma las filas por tipo)
- Create: `FisuEvolutionUITests/NotificationsSettingsUITests.swift`

**Interfaces:**
- Consumes: `NotificationsManager.isEnabled`, `isDenied`, `setEnabled(_:)`, `setEnabled(_:for:)`, `isEnabled(for:)`, `refreshAuthorization()` (T3); `GameContent.notifications.kinds`, `NotificationKind.settingsKey` (T2).
- Produces: identifiers `settings.notifications` (switch), `settings.notifications.<id>` (switch, uno por motivo), `settings.notifications.open_settings` (botón).

- [ ] **Step 1: El UI test, en rojo**

`FisuEvolutionUITests/NotificationsSettingsUITests.swift`:

```swift
import XCTest

/// La sección "Avisos" de Ajustes (PLAN-v2 E11): el maestro, uno por motivo y la
/// salida a Ajustes de iOS cuando el sistema las bloqueó.
///
/// ⚠️ Todo por identifier y por valor sin traducir (`on`/`off`): el runner corre
/// la app en inglés (trampa 6). Bajo `--uitest*` el juego no le habla a iOS: los
/// toggles guardan la preferencia y nada más, que es justo lo que se prueba.
/// El estado bloqueado lo arma `--uitest-notifications-denied` (centro en memoria).
final class NotificationsSettingsUITests: XCTestCase {
    private static let kinds = ["vault_full", "daily_ready", "comeback"]

    @MainActor
    func testElMaestroArrancaPrendidoYGobiernaLosMotivos() throws {
        let app = launch()
        openSettings(app)
        let master = app.switches["settings.notifications"]
        XCTAssertTrue(master.waitForExistence(timeout: 10), "Ajustes no trae el maestro de notificaciones")
        scrollTo(master, in: app)
        attach(app, named: "E11 ajustes: avisos")

        XCTAssertEqual(master.value as? String, "on", "en la 2.0 las notificaciones arrancan prendidas")
        for kind in Self.kinds {
            XCTAssertEqual(app.switches["settings.notifications.\(kind)"].value as? String, "on",
                           "el motivo \(kind) arranca prendido")
        }

        let vault = app.switches["settings.notifications.vault_full"]
        scrollTo(vault, in: app)
        vault.tap()
        waitFor(vault, value: "off")

        scrollTo(master, in: app)
        master.tap()
        waitFor(master, value: "off")
        XCTAssertFalse(app.switches["settings.notifications.vault_full"].exists,
                       "con el maestro apagado no se ofrecen los motivos")
        attach(app, named: "E11 ajustes: maestro apagado")

        master.tap()
        waitFor(master, value: "on")
        XCTAssertEqual(app.switches["settings.notifications.vault_full"].value as? String, "off",
                       "prender el maestro no pisa lo elegido por motivo")

        // Es preferencia del dispositivo: sobrevive al cierre de la app.
        app.terminate()
        app.launchArguments = ["--uitest-skip-tutorial"]
        app.launch()
        openSettings(app)
        let reopened = app.switches["settings.notifications.vault_full"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertEqual(reopened.value as? String, "off", "lo elegido por motivo no persistió")
    }

    @MainActor
    func testConIOSBloqueadoLaFilaLoDiceYOfreceAbrirAjustes() throws {
        let app = launch(extraArguments: ["--uitest-notifications-denied"])
        openSettings(app)
        let open = app.buttons["settings.notifications.open_settings"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "con iOS bloqueado falta «Abrir Ajustes»")
        scrollTo(open, in: app)
        attach(app, named: "E11 ajustes: bloqueadas por iOS")
        // No se toca: saldría de la app. Lo que importa es que esté y que la
        // preferencia del jugador no se haya apagado sola.
        XCTAssertEqual(app.switches["settings.notifications"].value as? String, "on",
                       "el bloqueo de iOS no le apaga la preferencia al jugador")
    }

    // MARK: Andamio

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extraArguments
        app.launch()
        return app
    }

    /// El menú y la tarjeta de Ajustes (el camino de `MenuUITests`).
    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "la barra inferior nunca apareció")
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: tab)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed, "el tab del menú nunca quedó tocable")
        tab.tap()
        let card = app.buttons["menu.card.settings"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "el menú no abrió su grilla")
        card.tap()
    }

    /// La sección de avisos vive debajo de idioma, audio y "En el juego".
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element.identifier) no quedó a la vista")
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed,
                       "\(element.identifier) no pasó a \(value)")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

⚠️ Si E3 ya integró la barra progresiva y `hud.settings` no está en una partida nueva, usar
el mismo fixture que use `MenuUITests` para tener la pestaña del menú (y anotarlo en el
reporte). No se inventa uno propio.

En `LocalizationCompletenessTests.swift`, `case .settingsRows`:

```swift
            case .settingsRows:
                return LanguagePreference.allCases.map(\.identifier) + LegalDocument.Kind.allCases.map(\.identifier)
                    + content.notifications.kinds.map(\.settingsKey)
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionUITests/NotificationsSettingsUITests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`.
Expected: FAIL — `el motivo vault_full arranca prendido` (no existe el switch),
`con iOS bloqueado falta «Abrir Ajustes»`, y la familia `settingsRows` con
`settings.notifications.vault_full: no está en el catálogo` (y las otras dos).

- [ ] **Step 3: La sección**

`SettingsView.swift`:

1. Imports: `import EconomyKit` antes de `import SwiftUI`.
2. Junto a los otros `@Environment`:

```swift
    @Environment(GameState.self) private var gameState
    @Environment(\.openURL) private var openURL
```

3. En el `VStack` del `body`, `notificationsSection` entre `gameSection` y `purchasesSection`.
   El comentario "son ~14 filas contadas" pasa a "~18".
4. En `gameSection`, sale el `RowDivider()` y el `ToggleRow` de notificaciones: la cinta queda
   sólo con partículas.
5. Después de `gameSection`:

```swift
    // MARK: Avisos

    /// El maestro, uno por motivo en el orden del catálogo y, si iOS las
    /// bloqueó, la salida a sus Ajustes. Con el maestro apagado los motivos se
    /// esconden pero no se olvidan.
    private var notificationsSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.notifications")
            GameCard(style: .normal) {
                VStack(spacing: 0) {
                    ToggleRow(
                        titleKey: "settings.notifications",
                        identifier: "settings.notifications",
                        hintKey: notifications.isDenied
                            ? "settings.notifications.denied"
                            : "settings.notifications.hint",
                        isOn: notifications.isEnabled
                    ) { wantsOn in
                        Task { await notifications.setEnabled(wantsOn) }
                    }
                    if notifications.isDenied {
                        ActionPill(
                            titleKey: "settings.notifications.open_settings",
                            systemImage: "gearshape.fill",
                            tint: Color("PaletteBlue"),
                            identifier: "settings.notifications.open_settings",
                            action: openSystemNotificationSettings
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Tokens.s8)
                    }
                    if notifications.isEnabled {
                        ForEach(notificationKinds, id: \.self) { kind in
                            RowDivider()
                            ToggleRow(
                                titleKey: LocalizedStringKey(kind.settingsKey),
                                identifier: kind.settingsKey,
                                isOn: notifications.isEnabled(for: kind)
                            ) { notifications.setEnabled($0, for: kind) }
                        }
                    }
                }
            }
        }
    }

    private var notificationKinds: [NotificationKind] {
        gameState.content?.notifications.kinds ?? NotificationKind.allCases
    }

    /// Los Ajustes de notificaciones de ESTA app en iOS: una alerta del sistema
    /// sería otra pantalla que no es del juego.
    private func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        openURL(url)
    }
```

6. Docstrings que pasan a mentir:
   - el de `SettingsView` ("**Seis cintas para las siete secciones del spec**: "Partículas" y
     "Notificaciones" comparten la de "En el juego"…") se reemplaza por: "**Siete cintas**:
     idioma, audio, en el juego, avisos (E11: el maestro, uno por motivo y la salida a Ajustes
     de iOS), compras, legales y acerca de. Los identifiers de las filas son lo que fijan el
     spec y los UI tests.";
   - el de `ToggleRow` ("un toggle que el sistema rechaza (las notificaciones) vuelve solo a
     su lugar") se reemplaza por "El estado lo decide quien la usa (`isOn`): la fila no guarda
     nada propio."

- [ ] **Step 4: Los textos**

`build/e11-t4-strings.json`:

```json
{
  "set": {
    "settings.notifications.comeback": { "es": "Si hace días que no venís", "en": "If you've been away for days" },
    "settings.notifications.daily_ready": { "es": "Premio diario sin cobrar", "en": "Daily prize waiting" },
    "settings.notifications.denied": { "es": "iOS las tiene bloqueadas para este juego.", "en": "iOS is blocking them for this game." },
    "settings.notifications.open_settings": { "es": "Abrir Ajustes", "en": "Open Settings" },
    "settings.notifications.vault_full": { "es": "Caja fuerte llena", "en": "Safe is full" },
    "settings.section.notifications": { "es": "Avisos", "en": "Alerts" }
  }
}
```

Run: `python3 build/xcstrings_e11.py build/e11-t4-strings.json` → `6 claves escritas, 0 borradas`.

- [ ] **Step 5: Verde, capturas y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `NotificationsSettingsUITests`,
`MenuUITests` y `LocalizationCompletenessTests` → PASS. Mirar las capturas del xcresult (las
tres de `attach`) **contra FisuJobs**: cinta naranja, tarjeta crema, toggles de la casa, la
píldora azul centrada y sin tocar el borde. Repetir el test de los toggles en un iPhone SE
(3ª generación) y comparar: ninguna fila cortada. Después `Tools/v2/oraculo.sh completo` →
`VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/UI/Menu/SettingsView.swift FisuEvolution/Resources/Localizable.xcstrings \
  FisuEvolutionTests/LocalizationCompletenessTests.swift FisuEvolutionUITests/NotificationsSettingsUITests.swift
git diff --cached --stat
git commit -m "feat(notif): Ajustes con el maestro, un toggle por motivo y la salida a Ajustes de iOS"
```

---

### Task 5: La tarjeta del permiso completo en el popup offline

**Objetivo:** en la primera vuelta con popup offline, debajo de "Cobrar", una tarjeta en estilo
FisuJobs: "¿Te aviso cuando la caja fuerte se llene?". "Sí, avisame" abre el diálogo del
sistema; "Ahora no" la cierra, deja el provisional y la tarjeta vuelve una sola vez más, 3 días
después (`notifications.json`). Es la lección `notifications.permission` (E9 la registra).

**Files:**
- Create: `FisuEvolution/UI/Popups/NotificationPermissionCard.swift`
- Modify: `FisuEvolution/UI/Popups/OfflineEarningsView.swift` (aloja la tarjeta; el detent crece con ella) ♨️
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (+4 claves) 🔥
- Create: `FisuEvolutionUITests/NotificationPermissionCardUITests.swift`

**Interfaces:**
- Consumes: `NotificationsManager.refreshAuthorization()`, `permissionCardDue(now:config:)`, `recordPermissionCardOffer(now:)`, `acceptPermissionCard()` (T3); `GameContent.notifications.permissionCard` (T2).
- Produces: `NotificationPermissionCard(accept:decline:)`, `NotificationPermissionCard.lessonID = "notifications.permission"`; identifiers `notifications.card` (marcador), `notifications.card.accept`, `notifications.card.decline`.

- [ ] **Step 1: El UI test, en rojo**

`FisuEvolutionUITests/NotificationPermissionCardUITests.swift`:

```swift
import XCTest

/// La tarjeta del permiso completo (PLAN-v2 E11), adentro del popup offline.
///
/// ⚠️ Bajo `--uitest*` el juego no le habla a iOS, así que sin
/// `--uitest-notifications-provisional` la tarjeta no aparece nunca (el segundo
/// test lo pinea). Con el fixture, un centro en memoria contesta "provisional"
/// sin el diálogo del sistema, que en un runner es un muro.
final class NotificationPermissionCardUITests: XCTestCase {
    @MainActor
    func testLaTarjetaApareceEnElPopupOfflineYAhoraNoLaCierra() throws {
        let app = launch(extraArguments: ["--uitest-notifications-provisional"])
        let decline = app.buttons["notifications.card.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 20), "la tarjeta del permiso no apareció en el popup offline")
        attach(app, named: "E11 tarjeta del permiso")
        XCTAssertTrue(app.buttons["notifications.card.accept"].exists, "falta «Sí, avisame»")
        XCTAssertTrue(app.otherElements["notifications.card"].exists, "falta el marcador de la tarjeta")

        decline.tap()

        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["notifications.card.accept"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "«Ahora no» no cerró la tarjeta")
        XCTAssertTrue(app.buttons["offline.collect"].exists, "«Ahora no» cierra la tarjeta, no el popup")
        attach(app, named: "E11 tarjeta cerrada")
    }

    @MainActor
    func testSinElFixtureBajoUITestNoSeOfreceNada() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["offline.collect"].waitForExistence(timeout: 20), "--uitest-offline no abrió el popup")
        XCTAssertFalse(app.buttons["notifications.card.accept"].waitForExistence(timeout: 3),
                       "bajo --uitest el juego ofreció el permiso sin que el test lo pidiera")
    }

    // MARK: Andamio

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-offline"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionUITests/NotificationPermissionCardUITests`.
Expected: `testLaTarjetaApareceEnElPopupOfflineYAhoraNoLaCierra` FAIL ("la tarjeta del permiso
no apareció en el popup offline"); el segundo, PASS (ya pinea la compuerta de T3).

- [ ] **Step 3: La tarjeta**

`FisuEvolution/UI/Popups/NotificationPermissionCard.swift`:

```swift
import SwiftUI

/// "¿Te aviso cuando la caja fuerte se llene?" (PLAN-v2 E11): el segundo paso del
/// permiso, adentro del popup offline, que es cuando el jugador acaba de ver lo
/// que la torre juntó sin él.
///
/// Es la lección `notifications.permission` del tutorial: E9 la registra en
/// `TutorialCoverageTests` (y decide si lleva el candado de 5 s de las
/// `TutorialInlineCard`).
struct NotificationPermissionCard: View {
    static let lessonID = "notifications.permission"

    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        GameCard(style: .highlighted(Color("PaletteBlue"))) {
            VStack(spacing: Tokens.s8) {
                HStack(spacing: Tokens.s8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color("PaletteBlue"))
                        .accessibilityHidden(true)
                    Text("notifications.card.title")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("notifications.card.body")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Tokens.s8) {
                    ActionPill(
                        titleKey: "notifications.card.decline",
                        systemImage: "clock",
                        tint: Color("PaletteBrown"),
                        identifier: "notifications.card.decline",
                        action: decline
                    )
                    ActionPill(
                        titleKey: "notifications.card.accept",
                        systemImage: "bell.fill",
                        tint: Color("PaletteGreen"),
                        identifier: "notifications.card.accept",
                        action: accept
                    )
                }
            }
        }
        // Marcador para los tests: la tarjeta no es un control (trampa 9a-bis).
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("notifications.card")
        )
    }
}
```

- [ ] **Step 4: El popup la aloja**

`OfflineEarningsView.swift`:

1. Junto a los otros `@Environment` y `@State`:

```swift
    @Environment(NotificationsManager.self) private var notifications
    /// La tarjeta del permiso completo (E11). Se decide UNA vez al abrir: en el
    /// `body` aparecería o se iría a mitad de la lectura cuando el permiso o el
    /// contador cambian atrás.
    @State private var offersPermission = false
```

2. En el `VStack` del `PanelCard`, **después** del `ActionPill` de cobrar (la tarjeta es
   secundaria: cobrar sigue siendo la salida):

```swift
                if offersPermission {
                    NotificationPermissionCard(
                        accept: {
                            offersPermission = false
                            Task { await notifications.acceptPermissionCard() }
                        },
                        decline: { offersPermission = false }
                    )
                }
```

3. Al principio del `.task` (antes de `doubled = gameState.offlineRewardDoubled`):

```swift
            await offerPermissionCardIfDue()
```

4. El detent: `.presentationDetents([.fraction(canOfferDouble || watching ? 0.52 : 0.42)])` y
   su comentario pasan a `.presentationDetents([.fraction(sheetFraction)])` con:

```swift
    /// Más alto con la oferta del video (0,42 recortaba el botón de cobrar) y más
    /// alto todavía con la tarjeta del permiso.
    private var sheetFraction: CGFloat {
        let base: CGFloat = canOfferDouble || watching ? 0.52 : 0.42
        return offersPermission ? base + 0.26 : base
    }

    /// La primera vuelta con popup offline es el momento del permiso completo
    /// (PLAN-v2 E11): el jugador acaba de ver lo que la torre juntó sin él.
    private func offerPermissionCardIfDue() async {
        guard let card = gameState.content?.notifications.permissionCard else { return }
        await notifications.refreshAuthorization()
        let now = Date().timeIntervalSince1970
        guard notifications.permissionCardDue(now: now, config: card) else { return }
        notifications.recordPermissionCardOffer(now: now)
        offersPermission = true
    }
```

- [ ] **Step 5: Los textos**

`build/e11-t5-strings.json` (si T5 corre en paralelo con T4, **no se ejecuta**: se entrega
este archivo al controlador como snapshot):

```json
{
  "set": {
    "notifications.card.accept": { "es": "Sí, avisame", "en": "Yes, ping me" },
    "notifications.card.body": { "es": "Un aviso cuando la torre junte todo lo que puede sin vos. Nunca de noche, nunca para venderte nada.", "en": "One ping when your tower has stashed all it can without you. Never at night, never to sell you anything." },
    "notifications.card.decline": { "es": "Ahora no", "en": "Not now" },
    "notifications.card.title": { "es": "¿Te aviso cuando la caja fuerte se llene?", "en": "Want a heads-up when the safe fills up?" }
  }
}
```

Run: `python3 build/xcstrings_e11.py build/e11-t5-strings.json` → `4 claves escritas, 0 borradas`.

- [ ] **Step 6: Verde, capturas y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `NotificationPermissionCardUITests` y
`LocalizationCompletenessTests` → PASS. Correr el primer test también en un **iPhone SE (3ª
generación)** y mirar las dos capturas: el panel con moño, el monto, "Cobrar" y la tarjeta
entran enteros, sin recorte contra el borde inferior. Si el SE recorta, se ajusta el `+ 0.26`
(nunca el texto) y se anota el valor medido en el reporte. Después
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/UI/Popups/NotificationPermissionCard.swift FisuEvolution/UI/Popups/OfflineEarningsView.swift \
  FisuEvolution/Resources/Localizable.xcstrings FisuEvolutionUITests/NotificationPermissionCardUITests.swift
git diff --cached --stat
git commit -m "feat(notif): la tarjeta del permiso completo en el popup offline"
```

---

### Task 6: El cableado al ciclo de vida — programar al irse, borrar al volver y el provisional al cerrar el núcleo

> ⚠️ **Va DESPUÉS de E1 T8** (y de E1 T1, T5 y T9). Se escribe contra la API que define el plan
> de E1 (`Docs/superpowers/plans/2026-10-06-v2-e1-correcciones-criticas.md`, Task 8):
> `GameState.handleScenePhase(from:to:now:)` y `seal(now:)` en `GameState+Lifecycle.swift`,
> `isSceneActive`, `backgroundTasks: (any BackgroundTaskRunning)?` con `begin(_:)`/`end(_:)`;
> de su Task 5, `startServices()` en `FisuEvolutionApp`; de su Task 1,
> `IncomeTicker.basePassivePerSecond(state:tiers:floorTable:config:)`.

**Objetivo:** al pasar a `.background` (en el sellado de E1 T8) se programa la ausencia dentro
de su propio tiempo de background; al volver a `.active` se borra todo; al cerrar el núcleo del
tutorial se pide el provisional; y al arrancar (`startServices`) se limpia lo de la ausencia y,
si el tutorial ya estaba hecho (un veterano), también se pide el provisional.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift` (dos propiedades) 🔥
- Create: `FisuEvolution/Game/State/GameState+Notifications.swift`
- Modify: `FisuEvolution/Game/State/GameState+Lifecycle.swift` (dos líneas en `handleScenePhase(from:to:now:)`) ♨️
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (una línea en `tutorialPhaseFinished()`) ♨️
- Modify: `FisuEvolution/App/FisuEvolutionApp.swift` (`startServices()`) ♨️
- Create: `FisuEvolutionTests/NotificationsWiringTests.swift`

**Interfaces:**
- Consumes: `NotificationsManager.scheduleAbsence(_:config:calendar:)`, `cancelAbsence()`, `refreshAuthorization()`, `requestProvisional()`, `appBecameActive()` (T3); `GameContent.notifications` (T2); `NotificationSnapshot` (T1); lo de E1 de arriba.
- Produces: `GameState.notifications: NotificationsManager?`, `GameState.notificationsTask: Task<Void, Never>?`, `attachNotifications(_:)`, `notificationSnapshot(now:) -> NotificationSnapshot?`, `scheduleNotificationsForAbsence(now:)`, `clearNotificationsOnReturn()`, `requestProvisionalNotifications()`, `notificationsLaunched(tutorialDone:) async`.

- [ ] **Step 0: Comprobar que E1 está adentro**

Run:

```bash
grep -n "func handleScenePhase(from" FisuEvolution/Game/State/GameState+Lifecycle.swift
grep -n "func seal(now" FisuEvolution/Game/State/GameState+Lifecycle.swift
grep -n "var backgroundTasks" FisuEvolution/Game/State/GameState.swift
grep -n "func startServices" FisuEvolution/App/FisuEvolutionApp.swift
grep -n "static func basePassivePerSecond" Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift
```

Expected: una línea por comando. Si alguno no imprime nada, E1 no está integrado en esta rama:
**parar y reportar `NEEDS_CONTEXT`** con el comando que falló. No se escribe contra la API de
hoy (`handleScenePhase(_:)`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/NotificationsWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
import UserNotifications
@testable import FisuEvolution

/// El manager enganchado al ciclo de vida de E1 (PLAN-v2 E11): se programa todo
/// al irse y se borra todo al volver; el provisional, al cerrar el núcleo.
@Suite("Notificaciones: el ciclo de vida")
@MainActor
struct NotificationsWiringTests {
    private struct Rig {
        let gameState: GameState
        let spy: NotificationsManagerTests.SpyNotificationCenter
        let scratch: SettingsPersistenceTests.ScratchDefaults
    }

    private func makeRig(status: UNAuthorizationStatus = .provisional) async -> Rig {
        let scratch = SettingsPersistenceTests.ScratchDefaults()
        let spy = NotificationsManagerTests.SpyNotificationCenter()
        spy.status = status
        let manager = NotificationsManager(center: spy, defaults: scratch.defaults)
        await manager.refreshAuthorization()
        let gameState = await makeGameState()
        gameState.attachNotifications(manager)
        return Rig(gameState: gameState, spy: spy, scratch: scratch)
    }

    private func producing(_ gameState: GameState) throws {
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
    }

    @Test("irse a background programa la ausencia completa")
    func backgroundSchedulesTheAbsence() async throws {
        let rig = await makeRig()
        defer { rig.scratch.clear() }
        try producing(rig.gameState)
        let now = Date().timeIntervalSince1970

        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: now)
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: now + 1)
        await rig.gameState.notificationsTask?.value

        #expect(Set(rig.spy.pending.keys) == ["fisu.notif.vault_full", "fisu.notif.daily_ready", "fisu.notif.comeback"])
    }

    @Test("sin pasivo no hay caja fuerte que avisar")
    func noPassiveNoVault() async {
        let rig = await makeRig()
        defer { rig.scratch.clear() }

        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: Date().timeIntervalSince1970)
        await rig.gameState.notificationsTask?.value

        #expect(Set(rig.spy.pending.keys) == ["fisu.notif.daily_ready", "fisu.notif.comeback"])
    }

    @Test("bajar el centro de notificaciones no programa nada")
    func notificationCenterPullSchedulesNothing() async {
        let rig = await makeRig()
        defer { rig.scratch.clear() }
        let now = Date().timeIntervalSince1970

        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: now)
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: now + 5)
        await rig.gameState.notificationsTask?.value

        #expect(rig.spy.pending.isEmpty)
    }

    @Test("volver borra lo pendiente y lo entregado")
    func returningClearsEverything() async throws {
        let rig = await makeRig()
        defer { rig.scratch.clear() }
        try producing(rig.gameState)
        let now = Date().timeIntervalSince1970
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: now)
        await rig.gameState.notificationsTask?.value
        #expect(!rig.spy.pending.isEmpty)

        rig.gameState.handleScenePhase(from: .background, to: .inactive, now: now + 3600)
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: now + 3601)
        await rig.gameState.notificationsTask?.value

        #expect(rig.spy.pending.isEmpty)
        #expect(rig.spy.removeDeliveredCount >= 1)
    }

    @Test("terminar el núcleo del tutorial pide el provisional, sin diálogo")
    func coreFinishRequestsProvisional() async {
        let rig = await makeRig(status: .notDetermined)
        defer { rig.scratch.clear() }

        rig.gameState.beginTutorialPhase()
        rig.gameState.tutorialPhaseFinished()
        await rig.gameState.notificationsTask?.value

        #expect(rig.spy.requestedOptions == [.alert, .sound, .badge, .provisional])
    }

    @Test("al arrancar limpia la ausencia y, si el tutorial ya estaba hecho, pide el provisional")
    func launchClearsAndAsksVeterans() async {
        let veteran = await makeRig(status: .notDetermined)
        defer { veteran.scratch.clear() }
        await veteran.gameState.notificationsLaunched(tutorialDone: true)
        #expect(veteran.spy.removeDeliveredCount == 1)
        #expect(veteran.spy.requestedOptions == [.alert, .sound, .badge, .provisional])

        let newcomer = await makeRig(status: .notDetermined)
        defer { newcomer.scratch.clear() }
        await newcomer.gameState.notificationsLaunched(tutorialDone: false)
        #expect(newcomer.spy.requestedOptions == nil)
    }

    @Test("sin manager, el ciclo de vida sigue como antes")
    func withoutManagerNothingChanges() async {
        let gameState = await makeGameState()
        gameState.handleScenePhase(from: .inactive, to: .background, now: Date().timeIntervalSince1970)
        #expect(gameState.notificationsTask == nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/NotificationsWiringTests`.
Expected: no compila — `value of type 'GameState' has no member 'attachNotifications'`
(y `notificationsTask`, `notificationsLaunched`).

- [ ] **Step 3: `GameState`**

`GameState.swift`, junto a `backgroundTasks` (lo agregó E1 T8):

```swift
    /// Las notificaciones locales (E11): las programa el sellado al irse y las
    /// borra la vuelta. `nil` en los tests que no las piden.
    @ObservationIgnored var notifications: NotificationsManager?
    /// El último trabajo con el manager, para que los tests lo esperen.
    @ObservationIgnored var notificationsTask: Task<Void, Never>?
```

`FisuEvolution/Game/State/GameState+Notifications.swift`:

```swift
import EconomyKit
import Foundation

/// Las notificaciones de la ausencia (PLAN-v2 E11), enganchadas al ciclo de vida
/// de `+Lifecycle`: el snapshot que el planificador necesita sale de acá, y el
/// manager hace el resto.
extension GameState {
    func attachNotifications(_ manager: NotificationsManager) {
        notifications = manager
    }

    /// Lo que el planificador necesita saber de la partida al irse, ya resuelto.
    /// El pasivo es el de base, sin modificadores temporales: un Paro General a
    /// la hora de irse no puede borrar el aviso de la caja fuerte.
    func notificationSnapshot(now: TimeInterval) -> NotificationSnapshot? {
        guard let content, let player else { return nil }
        let passive = IncomeTicker.basePassivePerSecond(
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy
        )
        let today = DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now))
        return NotificationSnapshot(
            now: now,
            producesOffline: passive > 0,
            offlineCapHours: content.economy.offlineCapHours,
            dailyClaimedToday: player.meta.daily.lastClaimDay == today
        )
    }

    /// Al pasar a `.background`: programa la ausencia dentro de su propio tiempo
    /// de background (el guardado del sellado tiene el suyo).
    func scheduleNotificationsForAbsence(now: TimeInterval) {
        guard phase == .ready, let notifications, let content,
              let snapshot = notificationSnapshot(now: now)
        else { return }
        let token = backgroundTasks?.begin("fisu.notifications")
        notificationsTask = Task {
            await notifications.scheduleAbsence(snapshot, config: content.notifications)
            if let token { backgroundTasks?.end(token) }
        }
    }

    /// Al volver a `.active`: lo pendiente y lo entregado ya no dicen nada. El
    /// borrado es síncrono; la relectura del permiso, no.
    func clearNotificationsOnReturn() {
        guard let notifications else { return }
        notifications.cancelAbsence()
        notificationsTask = Task { await notifications.refreshAuthorization() }
    }

    /// Al cerrar el núcleo del tutorial: el primer paso del permiso, sin diálogo.
    func requestProvisionalNotifications() {
        guard let notifications else { return }
        notificationsTask = Task { await notifications.requestProvisional() }
    }

    /// El arranque (`startServices`): un arranque en frío también es volver, y un
    /// veterano —que nunca va a ver el cierre del núcleo— recibe acá su provisional.
    func notificationsLaunched(
        tutorialDone: Bool = UserDefaults.standard.bool(forKey: "fisuTutorialDone")
    ) async {
        guard let notifications else { return }
        await notifications.appBecameActive()
        if tutorialDone, !tutorialPhaseActive {
            await notifications.requestProvisional()
        }
    }
}
```

- [ ] **Step 4: Los tres enganches**

`GameState+Lifecycle.swift`, en `handleScenePhase(from:to:now:)` de E1 T8 (las dos líneas
nuevas son las únicas que cambian):

```swift
        switch (old, new) {
        case (_, .background), (.active, .inactive):
            isSceneActive = false
            seal(now: now)
            if new == .background {
                scheduleNotificationsForAbsence(now: now)
            }
        case (_, .active):
            isSceneActive = true
            clearNotificationsOnReturn()
            guard phase == .ready else { return }
            // … lo de E1, sin cambios …
```

`(.active, .inactive)` sella pero **no** programa: es el Centro de notificaciones bajado o
una llamada, no una ausencia. `clearNotificationsOnReturn()` va **antes** del guard de fase:
lo pendiente se borra aunque el bootstrap no haya terminado.

`GameState+Celebrations.swift`, en `tutorialPhaseFinished()`, después de `grantWelcomeChest()`:

```swift
        // El primer paso del permiso de notificaciones (E11): provisional, sin diálogo.
        requestProvisionalNotifications()
```

`FisuEvolutionApp.swift`, al final de `startServices()` (de E1 T5: corre una sola vez, con
`.ready`):

```swift
        gameState.attachNotifications(notifications)
        await gameState.notificationsLaunched()
```

- [ ] **Step 5: Verde, escenario a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `NotificationsWiringTests`,
`LifecycleTests` (de E1) y `NotificationsManagerTests` → PASS.

Escenario a mano, en el simulador propio con la app **sin** argumentos de test (instalada por
la Receta R, lanzada tocando el ícono o con `xcrun simctl launch "$UDID" com.manuader.fisuevolution`):

1. En otra terminal:
   `xcrun simctl spawn "$UDID" log stream --level info --predicate 'subsystem == "com.manuader.fisuevolution" AND category == "lifecycle"'`.
2. Partida nueva: terminar el núcleo del tutorial → **ningún diálogo del sistema**.
3. Home (⇧⌘H) → en el log, `notifications scheduled: daily_ready, comeback` (o con
   `vault_full` adelante si ya hay pasivo).
4. Volver a la app → Ajustes › Avisos: el maestro prendido, los tres motivos prendidos, sin
   "Abrir Ajustes".
5. Ajustes de iOS › FisuEvolution › Notificaciones › desactivar → volver → Ajustes › Avisos
   dice que iOS las bloquea y "Abrir Ajustes" lleva a esa pantalla de iOS.

Después `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+Notifications.swift \
  FisuEvolution/Game/State/GameState+Lifecycle.swift FisuEvolution/Game/State/GameState+Celebrations.swift \
  FisuEvolution/App/FisuEvolutionApp.swift FisuEvolutionTests/NotificationsWiringTests.swift
git diff --cached --stat
git commit -m "feat(notif): programar al irse, borrar al volver y el provisional al cerrar el núcleo"
```

---

### Task 7: Cierre de la épica

**Objetivo:** la verificación de punta a punta de E11 y la documentación que deja a E5, E9 y
E10 arrancando sin leer esta sesión. La hace el controlador.

- [ ] **Step 1: Oráculo completo**

Run: `Tools/v2/oraculo.sh completo`.
Expected: `VERDE`, con `NotificationPlannerTests`, `NotificationsConfigTests`,
`PermissionCardPolicyTests`, `NotificationsContentTests`, `NotificationsManagerTests`,
`NotificationsWiringTests`, `NotificationsSettingsUITests` y
`NotificationPermissionCardUITests` en la salida. `rojos-declarados.txt` no cambió por E11.

- [ ] **Step 2: Los escenarios a mano**

En el simulador propio, app sin argumentos de test:

1. Partida nueva: el núcleo termina sin diálogo; Home → el log dice qué se programó.
2. Volver después de ≥ 30 s afuera con pasivo → el popup offline trae la tarjeta; "Ahora no"
   la cierra; volver otra vez enseguida → no está (falta que pasen 3 días).
3. Borrar la app, reinstalar, repetir 2 y tocar "Sí, avisame" → el diálogo del sistema; tras
   "Permitir", Ajustes › Avisos sin cartel.
4. Ajustes de iOS → desactivarlas → Ajustes › Avisos lo dice y "Abrir Ajustes" lleva a la
   pantalla de notificaciones de la app.
5. Instalar encima de una v1 con el toggle apagado (o `defaults write` de
   `settings.notificationsEnabled` en `false` sobre el simulador) → el maestro arranca
   apagado y no se pide nada.

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e11.md`: la tabla por tarea con su commit, lo medido (el detent
   del SE, los tiempos de los UI tests) y el porqué de cada default de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: entrada "E11 — notificaciones locales": preferencia ≠ permiso ≠ ausencia; el
     planificador puro; dónde se engancha cada cosa (`+Lifecycle`, `tutorialPhaseFinished`,
     `startServices`, el popup offline).
   - **§5**: lo que quedó decidido (los defaults de las dudas que el dueño no cambió).
   - **§7**: las trampas nuevas — "bajo `--uitest*` el manager no le habla a iOS: un UI test que
     necesite la tarjeta o el bloqueo pide `--uitest-notifications-provisional|denied`"; "el
     manager se construye antes del bootstrap: sus claves las borra él mismo en
     `--uitest-reset`"; "programar la ausencia tiene un `await` por aviso: la vuelta le gana
     por generación"; las que aparezcan en la ejecución.
   - **§9**: este plan y la sesión.
3. Journal AVO al día y `LOCK` liberado; `handoffs/HANDOFF-<fecha>-v2-e11.md` con lo abierto.

- [ ] **Step 4: Commit de docs**

```bash
git add Docs/SESION-*-v2-e11.md Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e11): cierre de la épica E11 — notificaciones"
```

---

## Lo que E11 le deja a otras épicas

- **E5 (`wheel_ready`)**: un motivo nuevo son cinco piezas, y el validador y
  `LocalizationCompletenessTests` no dejan olvidar ninguna:
  1. `case wheelReady = "wheel_ready"` en `NotificationKind`;
  2. `{ "id": "wheel_ready" }` en `notifications.json` (al final = la prioridad más baja; ver
     duda 4);
  3. `wheelSpinsReadyAt: TimeInterval?` en `NotificationSnapshot` (default `nil`) y su línea en
     `NotificationPlanner.moments`; `GameState.notificationSnapshot(now:)` lo llena;
  4. `notif.wheel_ready.title/.body` y `settings.notifications.wheel_ready` en es + en (sin
     anuncios ni precios: los giros por video no se mencionan);
  5. un test en `NotificationPlannerTests` con su hora.
- **E9**:
  - registrar la lección `notifications.permission` (`NotificationPermissionCard.lessonID`) en
    `TutorialCoverageTests`, y decidir si la tarjeta lleva el candado de 5 s de las
    `TutorialInlineCard`;
  - el Tour de los veteranos suma un paso en Ajustes con ancla en `settings.notifications`;
  - el "Resetear partida" **no** borra `settings.notificationsEnabled*` ni `notifications.card.*`
    (preferencia de dispositivo); `NotificationsManager.wipePreferences(in:)` es sólo de
    `--uitest-reset`;
  - al renombrar el cierre del núcleo a `core.finish`, la llamada a
    `requestProvisionalNotifications()` se muda con él; al cambiar las banderas de tutorial
    (`tutorial.v2.completed`), el default de `notificationsLaunched(tutorialDone:)` lee la nueva.
- **E10**: App Privacy no cambia (lo local no junta datos) y no hace falta `aps-environment`.
  Para las notas a App Review: "Las notificaciones son locales, sin servidor ni push, y
  opcionales (Ajustes › Avisos, una por motivo). Avisan el estado del juego —la caja fuerte
  llena, el premio diario y un regreso a los días—, nunca anuncios, ofertas ni precios. El
  permiso arranca provisional (llegan en silencio al Centro de notificaciones) y el completo
  se pide con una tarjeta propia que se puede rechazar."
- **E3**: si la barra progresiva esconde `hud.settings` en una partida nueva, los dos UI tests
  de E11 usan el mismo fixture que `MenuUITests`.

## Para el dueño / dudas

Cosas que la spec deja abiertas o que el código contradice. **Ninguna frena**: la ejecución
sigue con el default anotado hasta que el dueño diga otra cosa.

1. **El diario siempre avisa "mañana a las 19".** El premio diario se cobra solo al entrar
   (`claimDailyIfAvailable` en el bootstrap y en cada `.active`, `GameState+Bonus.swift:258`),
   así que al irse el de hoy ya está cobrado: "sin cobrar, a las 19:00 de ese día" sólo puede
   ser el de mañana. Default: el primer día sin cobrar, a las 19 (en la práctica, mañana si no
   volviste antes). Un aviso el mismo día pediría que el diario deje de cobrarse solo, que es
   otra decisión.
2. **Los veteranos nunca pasan por `core.finish`.** Default: el provisional se pide en el
   primer arranque de la 2.0 con el tutorial hecho, si el maestro está prendido e iOS nunca
   contestó. El que tenía la v1 prendida ya tiene el permiso completo; el que la apagó sigue
   apagado y no se le pide nada.
3. **La tarjeta vive adentro del popup offline**, no en un turno propio de la cola: no compite
   con el popup y no suma un `CelebrationKind`. **Mostrada cuenta como ofrecida**: cerrar el
   popup sin contestar gasta la oferta igual que "Ahora no". La alternativa (contar sólo "Ahora
   no") la dejaría reapareciendo en cada popup del que el jugador sale por "Cobrar".
4. **El espaciado corre, no descarta; el tope elige por prioridad.** "≥ 4 h entre dos avisos"
   se cumple corriendo el segundo (sigue siendo cierto: la caja sigue llena, el diario sin
   cobrar) y el tope de 3 se queda con los primeros del catálogo, no con los más tempranos.
   Consecuencia: cuando E5 sume `wheel_ready` al final, el regreso de 72 h le gana a la ruleta
   en una ausencia larga. Cambiar la prioridad es reordenar `notifications.json`, sin código.
5. **"Sí, avisame" y después "No permitir"**: iOS marca el permiso como denegado y se pierde
   también el provisional (es del sistema, no del juego). Ajustes lo muestra con "Abrir
   Ajustes". Se acepta: el jugador dijo que sí en la tarjeta antes de ver el diálogo.
6. **Los motivos se esconden con el maestro apagado**, como en los Ajustes de iOS, y su
   elección se conserva para cuando se prende.
7. **Las ofertas de 24 h de E6 no avisan.** Son un motivo para volver, pero la regla "nunca
   ofertas ni precios" (guía 4.5.4) las deja afuera aunque el texto no diga el precio.
8. **El silencio es el del huso horario al irse.** Los avisos se programan como intervalos: si
   el jugador viaja, el horario silencioso queda en la hora vieja. Se acepta (recalcular por
   viaje no vale lo que cuesta).
