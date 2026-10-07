# E4a — Visitantes y eventos v2, el motor: premios, relojes, guiones y eventos compuestos · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que la 2.0 tenga, puros en EconomyKit y validados al arrancar, el vocabulario único de
premios (`RewardSpec`), los relojes de juego activo de visitantes y eventos guardados en
`meta.engagement`, los 26 guiones del Anexo A con sus invariantes (nunca te dejan sin gente,
el arresto siempre indemniza) y los 18 eventos compuestos de schema 2, con el juego corriendo
ya sobre el motor nuevo.

**Architecture:** todo lo que decide vive en EconomyKit: `RewardSpec` (qué se da),
`EventCatalog` + `EventScheduler` + `EventPlanner` (qué evento, cuándo y qué hace),
`VisitorsConfig` + `VisitorScheduler` + `VisitPlanner` (quién viene, cuándo y qué ofrece, con
las monedas ya cotizadas al llegar). La app sólo engancha: un punto de entrega
(`GameState.grant`), un predicado de momento calmo (`isCalmMoment`), un reloj de engagement
colgado del tick (`advanceEngagement`) y el motor de eventos v2 (`GameState+Events.swift`), que
reemplaza a `EventManager`. Lo que se ve —la escena, los chips con cara, los popups, el Álbum—
es E4b (`2026-10-07-v2-e4b-visitantes-eventos.md`).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · EconomyKit (SPM puro, `Sendable`) · Swift Testing · XCUITest · XcodeGen (el
`.xcodeproj` no se versiona) · Python 3 (la herramienta del catálogo).

**Fuente:** `Docs/PLAN-v2.md` §4 "E4 — Visitantes + Eventos v2 + Álbum de especiales",
"Cimientos compartidos" (la primera tarea de E4, de la que dependen E5–E7), Anexo A (guiones y
frases), Anexo B (los 8 visitantes nuevos), §2 (decisiones cerradas: **no se re-litigan**), §5
(arte) y §0.1 (agentes concurrentes). `Docs/biblia-visitantes.md` fija los ids de arte. Lo que
el código contradice o la spec deja abierto está en "Para el dueño / dudas", con un default que
no frena.

**Rama de la épica:** `v2/e4-visitantes`, desde `version-2`. Cada tarea sale de su punta en un
worktree propio (`Agent(isolation: "worktree")`, PLAN-v2 §0.1) y el controlador integra de a una.

### Por qué E4 va en dos planes

E4 son tres sistemas (visitantes, eventos v2, Álbum) más los cimientos que heredan E5–E7. En un
solo documento serían ~20 tareas y ~6.000 líneas. Se parte por **qué decide contra qué se ve**,
como E3:

- **E4a (este plan) — el motor:** `RewardSpec`, los efectos nuevos de modificador, el estado en
  `meta.engagement`, los dos motores puros (eventos y visitantes), el contenido (`visitors.json`,
  `events.json` v2, textos), el punto de entrega de premios y la mudanza del juego al motor de
  eventos v2 (con el banner de siempre todavía).
- **E4b — lo que se ve:** el escenario de la escena (`StageController`, globo vectorial), los
  visitantes en el juego, los chips y popups, los eventos con presentador (se borra el banner),
  los retos y el Vendedor, los efectos de escena (Apagón, Campeones, Liquidación), el Álbum y los
  especiales fuera del tablero.

E4b depende de E4a en todo: arranca cuando E4a cerró.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build. **Nada de `Timer` para lógica de juego** (regla 2): los relojes de visitantes y
  eventos avanzan con el delta del tick (`advanceEngagement`), con tope de 2 s y sólo con la
  escena activa (E1 T8).
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo** (Swift, JSON de `Resources/Config` o test), en el mismo paso en que se crea. Un
  archivo nuevo de EconomyKit no lo pide (el proyecto referencia el paquete, no sus archivos).
- **Strings nuevos, es + en, en el mismo commit que el código que los usa**, siempre por
  `Tools/v2/catalogo.py` (E3a T1, formato canónico, trampa 29). Cada tarea escribe sus claves en
  `Tools/v2/claves-pendientes/e4a-tN.json` y las aplica con
  `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4a-tN.json` para correr sus tests.
  **Si en su ola es dueña de `Localizable.xcstrings`** (lo dice el despacho), commitea el catálogo
  y borra el JSON; **si no**, commitea sólo el JSON y descarta el catálogo
  (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`): el controlador lo aplica al
  integrar. Las claves que se **borran** van en `Tools/v2/claves-pendientes/e4a-tN.quitar` (una
  por línea) y se aplican con `Tools/v2/catalogo.py quitar` (lo suma la Task 9).
- Los textos con números **interpolan el dato**, nunca lo escriben a mano (la regla de `IAPCopy`,
  HANDOFF §5): el valor lleva `%1$@`/`%2$@` y la app lo llena con `String(format:)` sobre
  `Bundle.main.localizedString(forKey:value:table:)`. Las frases de humor del Anexo A pierden sus
  números (el chip y el popup dicen cuánto y cuánto dura).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis).
- **FisuJobs es la referencia visual de toda pieza nueva** (`PanelCard`/`GameCard`,
  `ActionPill`/`PricePill`/`StateBadge`, paleta y tipografía de la casa). Nada de botones ni
  alertas del sistema. Toda hoja se presenta con `fisuSheet()` (E3a T6).
- **Nada nuevo corre bajo XCTest ni bajo `--uitest*` salvo que el test lo pida**:
  `GameState.engagementAutorun` (patrón `tutorialLessonsAutorun`) arranca falso en los dos, y un
  test de UI que lo quiere vivo pasa `--uitest-engagement`. Las puertas de test son
  `--uitest-event=<id>` (E4a T9) y `--uitest-visitor=<guion>` (E4b T2).
- **Data-driven**: cadencias, pesos, topes, premios, presentadores y salidas viven en
  `visitors.json` y `events.json` v2, con validador al arrancar (patrón
  `GameContentLoader.validate`). En código sólo quedan geometría y constantes con nombre y su
  porqué.
- **EconomyKit no conoce UI, `Bundle` ni `Date()`**: recibe el `now`, el RNG, la valuación de un
  segundo de producción y los predicados ya resueltos. `EconomyKitTests` no tiene recursos: sus
  tests usan fixtures sintéticos; los hechos de los JSON reales se pinean del lado de la app.
- **Todo estado nuevo vive en `meta.engagement`** (`EngagementState`, E1 T4) con
  `decodeIfPresent ?? default` y su regla en `resolve`: **no se sube el schema** (v6). Trampa
  E7a: un `Codable` con `var x = 0` no decodifica un JSON sin esa clave; todo lo que se persiste
  y puede crecer lleva su `init(from:)`.
- **Ningún cambio del tablero que no hizo el jugador se aplica en el acto**: Startup, Blanqueo y
  las salidas de visitantes pasan por el embudo `BoardChange` de E1 (T7–T12).
- **Sólo arquetipos**: ni personas reales, ni marcas, ni insignias (PLAN-v2 §2 y §6). Los guiones
  no usan palabras de cripto aunque el Crypto Bro se llame así.
- Código nuevo limpio y con pocos comentarios (regla del dueño: prolijidad antes que
  comentarios); los heredados no se borran por deporte, pero **el que miente se corrige** en el
  commit que lo vuelve mentira.
- **Commits en español, estilo `feat(eventos): …` / `feat(visitantes): …`, SIN
  `Co-Authored-By`.** Staging selectivo por archivo y `git diff --cached --stat` antes de cada
  commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración con
  `oraculo.sh rapido` → `Docs/SESION-<fecha>-v2-e4.md` → las cuatro ediciones de
  `Docs/HANDOFF.md` (§4, §5, §7, §9) → journal AVO y latido del `LOCK`. Ningún subagente toca
  `Docs/`, `handoffs/`, el journal ni `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

**El oráculo del run** juzga cada integración:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
```

- Termina en 0 (`VERDE`) sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`. E4 no
  declara rojos nuevos. Los tests nuevos entran solos (corre las suites enteras): **así suma E4
  sus tests al oráculo**, sin tocar `oraculo.sh`.
- `rapido` al cerrar T1–T8; `completo` al cerrar T9 (cambia lo que el jugador ve) y la épica (T10).
- ⚠️ El `pacing-sim` no modela eventos ni visitantes (es trabajo de E2b): su número no se mueve con
  E4a. Si se mueve, se busca por qué antes de integrar.

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…")
swift test --package-path Packages/EconomyKit --filter "RewardSpecTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE (sin "()" no corre nada)
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e4-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e4" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e4" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/RewardGrantTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y de `-only-testing:`). Mirá la salida. Ante un rojo en masa, antes
de culpar al código: `uptime`, `ps aux | grep '[x]codebuild'` y las rutas de los `SwiftCompile`
en el log (trampas 16, 33 y 44).

## Las referencias de PLAN-v2 E4, verificadas contra el árbol (`68bb47c`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E4 |
|---|---|---|
| predicado de momento calmo `GameState.swift:468-473` | `isSafeMomentForInterstitial` (`GameState.swift:468-473`): `phase == .ready`, `!uiCoversBoard`, `celebrations.current == nil`, `!tutorialPhaseActive` | `isCalmMoment` **no existe**: lo crea la Task 8 en un archivo frío (+ escena activa y ficha cerrada); E7b pasa los intersticiales a él |
| `coinReward(seconds:)` `GameState+Achievements.swift:453-470` | igual, `private static` | **E1 T14** lo deja `static` interno; E4 lo usa tal cual (ver duda 2: no se muda a `RewardMath`) |
| "El motor se muda a EconomyKit (`EventScheduler`)" | `EventManager` en `ContentSystems.swift:124-251`; `EventsConfig` en `ContentConfigs.swift:6-32`; el reloj `nextEventAt`/`eventLastFired` en memoria (`GameState.swift:425-427`), reiniciado en cada arranque (`GameState.swift:708`) | T4 crea el motor puro con otro nombre (`EventCatalog`, para no chocar con el `EventsConfig` de la app); T9 borra los dos viejos. El reloj pasa al save y a juego activo |
| "Cayó Mercado Pago" → "Se cayó el home banking" | `events.json` id `cayo_mercado_pago`, clave `event.cayo_mercado_pago.flavor` (en "The payment app is down") | T9: id `home_banking`, claves `event.home_banking.title/.phrase` |
| `ActiveBonus.Icon.face` | `ActiveBonus.Icon` sólo tiene `.art` y `.symbol` (`ActiveBonus.swift:21-24`); los eventos quedan afuera por `excludedPrefix = "event."` (`:50`) | E4b T4 |
| `HireQuote.listCost` | no existe (`TowerActions.swift:4-20`) | E4b T7 lo resuelve en la app (`JobRow.listCostText`) sin tocar `TowerActions` |
| efectos nuevos `passiveMultiplier`, `eventImmunity`, `packageRateMultiplier` | `ActiveModifier.Effect` tiene 3 casos (`ActiveModifier.swift:7-14`); E1 T13 suma `spendingFrozen` y T15 lo vuelve `CaseIterable` | T2 suma los tres que usa E4 (`autoTapPerSecond` es de E6 y `freeHire` de E2a) |
| "Ya no quedan chiquitos en el tablero" | `renderAnchoredSpecials` `BoardScene.swift:1255-1288`, `specialID(at:)` `:1240-1253`, long-press `:630-642`; `visibleFloorSpecials`/`presentSpecialInfo` `GameState+Tower.swift:75-93` | E4b T9 (y E3a T10 los toca antes: va después) |
| `meta.engagement` con `visitors` y `events` | `EngagementState` lo crea **E1 T4** vacío; **E3b T9** le suma `sharedMoments` con su `init(from:)` | T3 suma `visitors` y `events` a ese mismo `init` y a ese mismo `resolve` |
| `RewardedPlacement.visitor` | ya existe (E7a): `FeatureFlags.swift:30-32` | los videos de E4 van por `.visitor` |
| arte de los visitantes | `assets_manifest.json` no tiene sección `npcs` (la crea `process_dropbox.py` con el primer visitante, `scripts/process_dropbox.py:42,161`); los 10 especiales tienen canónica en `characters["sp_*"]`; `loops_manifest.json` vacío | E4b resuelve todo con respaldo: sin entrada, arte quieto o placeholder por código |
| `sfx_blackout` | `Resources/Audio/sfx_blackout.caf` existe sin caso en `AudioManager.SFX` (`AudioManager.swift:14-30`); `AudioWiringTests` exige un call site por caso en `Game/State` o `UI/Popups` | E4b T6 lo cablea desde `GameState+Events.swift` |
| Anexo A "24 guiones" | la tabla tiene **26** filas (con el blue del Arbolito y los dos retos) | se implementan las 26 |

## Lo que E4 hereda de E1 y E3 (todavía no está en el árbol)

E4 corre "luego" (PLAN-v2 §0.1): **después de E1 T16**. Las APIs se citan como las definen sus
planes; cada tarea dice de cuál depende. Si al despachar una tarea su API no está en la punta de
`version-2`, el agente para con `NEEDS_CONTEXT`: no se inventa.

| API | La define | La usa |
|---|---|---|
| `MetaState.engagement: EngagementState` (`static let initial`, `resolve(winner:loser:)`), save v6 | E1 T4 | E4a T3 |
| `EngagementState.sharedMoments` + su `init(from:)` | E3b T9 | E4a T3 (suma sus campos ahí) |
| `RunState.raiseFrontier(to:)` (único mutador de la frontera) | E1 T3 | E4a T6 (los tests), E4b |
| `BoardChange` (`.departure`, `.arrival`, `.evolve`), `BoardChange.Origin` (con `eventStartup`, `eventBlanqueo`), `BoardChangePlanner.planEvolve/planArrival/revalidate`, `BoardChange.replanned(_:)` (interno de EK) | E1 T7 | E4a T6, T9 |
| `GameState.isSceneActive`, `handleScenePhase(from:to:now:)` (llama a `postponeOverdueEvent(now:)`), el tick con `guard isSceneActive` y `advanceCelebrations(delta: min(delta, IncomeTicker.deltaClampThreshold))` | E1 T8 | E4a T8, T9 |
| `EventsConfig.resumeGraceSeconds` y `GameState.postponeOverdueEvent(now:)` | E1 T8 | E4a T9 los reemplaza con el mismo nombre de función |
| `GameState.enqueueBoardChange(_:)`, `pendingBoardChanges`, `discardBoardChange(_:)` (con su `switch` sobre `Origin`) | E1 T9, T14 | E4a T6 (suma `.visitor` al `switch`), T9 |
| la escena reproduce `.arrival`/`.departure` (`confirmWithoutGesture`) | E1 T10 | E4b (las salidas de visitantes) |
| `EventManager.fireRandomEvent(…, isApplicable:)`, `blanqueoType`, `GameState.eventIsApplicable(_:)`, `EventsConfig.retryWhenNoneApplicableSeconds` | E1 T11 | E4a T9 los reemplaza |
| `EventManager.BoardIntent`, `Roll.boardIntent`, `GameState.handleEventRoll(_:now:)` | E1 T12 | E4a T9 los reemplaza |
| `ActiveModifier.Effect.spendingFrozen`, `EventsConfig.Event.escape`, `EventManager.ActiveEvent.escapableByVideo`, `GameState.escapeActiveEvent(now:)`, `debugStartCorralito()`, `--uitest-corralito`, el botón `event.escape` del banner, la clave `event.escape.video` | E1 T13 | E4a T2, T9 |
| `GameState.coinReward(seconds:player:content:economy:)` `static` interno | E1 T14 | E4a T8 |
| `ActiveModifier.Effect: CaseIterable`, `EventsConfig.EffectType: CaseIterable`, `EffectContractTests` | E1 T15 | E4a T2 (filas nuevas), T9 (reescribe `eventEffects`) |
| `Tools/v2/catalogo.py` (`aplicar`, `verificar`) y `Tools/v2/claves-pendientes/` | E3a T1 | toda tarea con strings; T9 le suma `quitar` |
| `GameContentLoader` con `notifications` (E11 T2) y `tabs` (E3a T9) | E11 T2, E3a T9 | E4a T7, T9 (suman sus configs al lado) |
| `LocalizationCompletenessTests.DynamicFamily` con `notifications` y `settingsRows` extendido | E11 T2, T4 | E4a T7, T9 (suman `visitors` y cambian `events`) |
| `fisuSheet()`, `playColumn()` | E3a T6, T4 | E4b |

## El premio, de punta a punta

```
visitors.json / events.json / (E5) wheel.json / (E6) offers.json
   │   "rewards": [{"kind": "coinsSeconds", "seconds": 900}, {"kind": "package", "count": 1}]
   ▼
RewardSpec (EK) ── validate() al cargar · scaled(by: 2) = el "×2 con video"
   │                 (lo contable se duplica; un efecto con duración dura el doble)
   ├─► VisitPlanner.offer (EK): las monedas se COTIZAN AL LLEGAR el visitante
   │      → VisitOption.coins (lo que dice el globo = lo que dice el popup = lo que se cobra)
   │      → VisitOption.rewards (lo que no es plata)
   ▼
GameState.grant(_:multiplier:source:) ── el ÚNICO punto de entrega (Task 8)
   ├─ coinsSeconds → coinReward(seconds:) (E1 T14), al cobrar
   ├─ oro → sólo el balance (como logros y tienda)
   ├─ modifier / eventImmunity → ActiveModifier con sourceKey = source
   ├─ skinChest → meta.chestsPending · clearBoostCooldowns → meta.boostActivations
   └─ package · wheelSpin · autoTap · nextOffline/Daily · extraSlots → todavía no: E5/E6
        (`grantableRewardKinds`: un guion o evento que da algo que no está ahí NO se ofrece)
```

## Los eventos v2 en una página

```
tick (escena activa, delta ≤ 2 s) → advanceEngagement → advanceEvents
   │  EventScheduler.advance: reloj de JUEGO ACTIVO en meta.engagement.events (sobrevive al cierre)
   ▼ vence
EventScheduler.takeDue: el que la Vecina adelantó (si sigue elegible) o un sorteo
   │  elegible = minTier · cooldown (en reloj de juego) · inmunidad saca los NEGATIVOS (no los mixtos)
   │             · aplicable (Aguinaldo con pasivo, Startup con alguien que crezca, Blanqueo con lugar,
   │               paquetes sólo si E5 ya entrega paquetes)
   ├─ vacío → retrySoon (30 s): no gasta el intervalo (E1 T11)
   ▼
markFired (cooldown + próximo 900–1200 s) → startEvent        ← E4b: lo llama el PRESENTADOR al llegar
   │  EventPlanner.apply: modificadores con sourceKey "event.<id>" · segundos de producción
   │                      · intención de tablero → BoardChangePlanner → embudo E1
   │                      · llamado a un visitante (Cepo → el blue del Arbolito, E4b)
   ▼
banner (E4a) ─ salidas: video / cuota / gratis → EventPlanner.escape (Hiperinflación: el video
               saca sólo el ×2 de contratar)                   ← E4b: chip con cara + popup
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift` | **nuevo** — el vocabulario de premios, su JSON, el ×2 y el validador | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` | `passiveMultiplier`, `eventImmunity`, `packageRateMultiplier`; `ModifierMath.isImmuneToEvents` | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift` | el pasivo multiplica por `passiveMultiplier` | 2 |
| `FisuEvolution/Game/State/ActiveBonus.swift`, `FisuEvolution/UI/HUD/ActiveBonusBar.swift` | texto y color de los tres efectos nuevos (los `switch` exhaustivos) | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsState.swift` | **nuevo** — relojes, anti-repetición y topes del día | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/Events/EventsState.swift` | **nuevo** — reloj de juego, cooldowns y el próximo ya sorteado | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` | `visitors` y `events` con su `init(from:)` y su `resolve` | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/Events/EventCatalog.swift` | **nuevo** — `events.json` schema 2 y su validador | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/Events/EventScheduler.swift` | **nuevo** — avanzar, elegibles, sortear, adelantar, reintentar, gracia | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/Events/EventPlanner.swift` | **nuevo** — aplicar, salidas, cortar negativos, eventos corriendo, velitas | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsConfig.swift` | **nuevo** — `visitors.json`: visitantes, guiones, mecánicas y validador | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorScheduler.swift` | **nuevo** — los dos carriles, elegibles, sorteo, topes, anti-repetición | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitPlanner.swift` | **nuevo** — la oferta cotizada al llegar, la revalidación y las invariantes | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` | `Origin.visitor` (archivo de E1 T7) | 6 |
| `FisuEvolution/Resources/Config/visitors.json` | **nuevo** — los 18 visitantes y los 26 guiones del Anexo A | 7 |
| `FisuEvolution/Managers/VisitCopy.swift` | **nuevo** — las claves de los visitantes y cómo se llenan | 7 |
| `FisuEvolution/Managers/GameContentLoader.swift` | carga y valida `visitors.json` (T7) y `events.json` v2 (T9) | 7, 9 |
| `FisuEvolution/Game/State/GameState+Rewards.swift` | **nuevo** — `grant`, `grantableRewardKinds`, `isCalmMoment`, `coinsPerProductionSecond` | 8 |
| `FisuEvolution/Resources/Config/events.json` | schema 2: los 18 eventos del Anexo A | 9 |
| `FisuEvolution/Game/State/GameState+Events.swift` | **nuevo** — el motor v2 enganchado: vencer, arrancar, salidas, gracia, adelantar | 9 |
| `FisuEvolution/Game/State/GameState+Engagement.swift` | **nuevo** — `advanceEngagement(delta:)` y las puertas de test del engagement | 9 |
| `FisuEvolution/Game/State/GameState.swift` | `activeEvent` (tipo nuevo), `engagementAutorun`, el gancho del tick y del bootstrap; se van `nextEventAt`/`eventLastFired` | 9 |
| `FisuEvolution/Game/State/GameState+Bonus.swift`, `FisuEvolution/Managers/ContentSystems.swift`, `FisuEvolution/Managers/ContentConfigs.swift` | se van `EventManager`, `EventsConfig` y la sección de eventos | 9 |
| `FisuEvolution/UI/HUD/EventBannerView.swift` | el banner lee el evento v2 y ofrece sus salidas | 9 |
| `Tools/v2/catalogo.py`, `Tools/v2/test_catalogo.py` | `quitar <clave>…` | 9 |
| tests | EK: `RewardSpecTests`, `EventModifierEffectsTests`, `EngagementStageStateTests`, `EventCatalogTests`, `EventSchedulerTests`, `EventPlannerTests`, `VisitorsConfigTests`, `VisitorSchedulerTests`, `VisitPlannerTests`; app: `VisitorsContentTests`, `RewardGrantTests`, `EventsRuntimeTests`, `EventsContentTests` (+ las suites de E1 que se reescriben en T9) | 1–9 |

## Orden, olas y paralelismo

**Archivos calientes** (un solo dueño por ola, PLAN-v2 §0.1): `GameState.swift`,
`RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`, `GameState+Bonus.swift`,
`SettingsView.swift`, `PlayerState.swift`, `TowerActions.swift`, `project.yml`,
`Localizable.xcstrings`. **Tibios** (otra épica los toca en su ola): `GameContentLoader.swift`
(E11 T2, E3a T9, E5–E7 suman configs), `LocalizationCompletenessTests.swift` (E11, E5…),
`EngagementState.swift` (E3b T9, E5, E6), `GameState+Debug.swift`, `GameState+Celebrations.swift`,
`GameState+BoardChanges.swift`, `ContentConfigs.swift`, `EffectContractTests.swift`,
`ActiveBonus.swift`/`ActiveBonusBar.swift`.

E4a **no toca** `RootView.swift`, `BoardScene.swift`, `SettingsView.swift`, `PlayerState.swift`,
`TowerActions.swift` ni `project.yml`.

| T | Qué | Archivos | 🔥 / tibios | Depende de |
|---|---|---|---|---|
| 1 | `RewardSpec` | `RewardSpec.swift`, `RewardSpecTests.swift` | — | — (puede correr ya) |
| 2 | efectos nuevos de modificador | `ActiveModifier.swift`, `IncomeTicker.swift`, `EventModifierEffectsTests.swift`, `ActiveBonus.swift`, `ActiveBonusBar.swift`, `EffectContractTests.swift`, catálogo | catálogo (o snapshot) · tibios: `ActiveBonus*`, `EffectContractTests` | **E1 T13, T15** (o E1 cerrada) |
| 3 | estado en `meta.engagement` | `VisitorsState.swift`, `EventsState.swift`, `EngagementState.swift`, `EngagementStageStateTests.swift` | tibio: `EngagementState.swift` | **E1 T4**, **E3b T9** |
| 4 | motor de eventos (EK) | `EventCatalog.swift`, `EventScheduler.swift`, `EventPlanner.swift`, `EventsEngineTests.swift` | — | T1, T2, T3 |
| 5 | visitantes: config y relojes (EK) | `VisitorsConfig.swift`, `VisitorScheduler.swift`, `VisitorsEngineTests.swift` | — | T1, T3 |
| 6 | `VisitPlanner` (EK) | `VisitPlanner.swift`, `BoardChange.swift`, `VisitPlannerTests.swift`, `GameState+BoardChanges.swift` (1 línea) | tibio: `+BoardChanges` | T5, **E1 T7, T14** |
| 7 | contenido de los visitantes | `visitors.json`, `VisitCopy.swift`, `GameContentLoader.swift`, `VisitorsContentTests.swift`, `LocalizationCompletenessTests.swift`, catálogo | catálogo (o snapshot) · tibios: loader, `LocalizationCompletenessTests` | T5, T6, **E11 T2**, **E3a T1** |
| 8 | `grant` + `isCalmMoment` | `GameState+Rewards.swift`, `RewardGrantTests.swift` | — | T1, T2, **E1 T8, T14** |
| 9 | la mudanza a eventos v2 | ver la tarea (17 archivos) | 🔥 `GameState.swift`, `GameState+Bonus.swift`, `ContentSystems.swift`, catálogo · tibios: `ContentConfigs`, `+Debug`, loader, las suites de E1 | T2, T4, T7, T8, **E1 cerrada (T16)** |
| 10 | cierre | `Docs/` (controlador) | — | todas |

```
Ola 1 (fría, puede ir junto a E1 T5+)   T1 RewardSpec ║ T3 estado en engagement (tras E1 T4 y E3b T9)
Ola 2 (tras E1 T15)                     T2 efectos ║ T5 visitantes EK ║ T8 grant
Ola 3                                   T4 eventos EK ║ T6 VisitPlanner ║ T7 contenido
── caliente ──
Ola 4                                   T9 la mudanza   (dueña de GameState.swift, +Bonus, ContentSystems y el catálogo)
Ola 5                                   T10 cierre
```

**Reglas del paralelismo:**

1. Cada tarea corre en su worktree aislado desde la punta de `v2/e4-visitantes`, con su
   DerivedData (`build/DD-e4`) y su simulador por UDID, que apaga y borra al terminar. Hasta 3
   compilando a la vez en todo el run; las tareas puras de EK (T1, T3, T4, T5, T6) no compilan
   la app salvo en el paso de oráculo.
2. Si en una ola dos tareas necesitan strings (T2 y T7, por ejemplo), la que **no** es dueña del
   catálogo entrega su snapshot y el controlador lo aplica al integrar.
3. **E4 ∥ E5 por tarea** (comparten `GameState`): T9 es la única de E4a que toca
   `GameState.swift`; no va en la misma ola que una tarea de E5 que lo toque. Un agente que
   necesita un caliente ajeno para con `NEEDS_CONTEXT`.
4. **T9 sale de una `v2/e4-visitantes` que ya tiene mergeada `version-2` con E1 entera.** Su paso
   0 lo comprueba (`grep -n "func handleEventRoll\|retryWhenNoneApplicableSeconds\|escapableByVideo" FisuEvolution -r`
   tiene que encontrar las tres); si falta algo, `NEEDS_CONTEXT`.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` (async, **no** throws; repo en memoria) | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| el contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift:31` |
| config/estado sintético de EK | `fxConfig`, `fxEconomy`, `fxType`, `fxTiers`, `fxFloorTable`, `fxState`, `fxStateAndTower`, `fxSlot`, `fxSlots` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` |
| RNG determinista en EK | `SeededRNG(seed:)` | `Fixtures.swift` |
| pisos abiertos y frontera | `debugUnlockFloors(throughTier:)` (sube la frontera), `debugGrantCoins()`, `debugGrantPair()`, `debugMarkTypesSeen(throughTier:)` | `GameState+Debug.swift` |
| vaciar la cola de celebraciones | `drainCelebrations(_:)` (privado: copiarlo) | `CelebrationWiringTests.swift` |
| leer el catálogo de strings | `LocalizationCompletenessTests.catalog("Localizable")` | `LocalizationCompletenessTests.swift` |
| el embudo y la contabilidad de reveal (E1) | `BoardChangePlanner`, `beginNextBoardChange()`, `confirmBoardChange(id:)`, `markRevealed(tier:)` | E1 T7, T9 |

La escalera sintética de EK: `a(1) → b(2) → [choice] c_prog/c_law (3) → d(4)`; pisos `f1 {1–2}`
y `f2 {3–4}`, capacidad 5. El tipo base real es `homeless`; los pisos reales `alley` (1–4),
`urban` (5–8), `corporate` (9–12) … `god_realm` (37); capacidad 10 hasta que E2a la pase a 15.

---

### Task 1: `RewardSpec` — el vocabulario único de premios

**Objetivo:** el cimiento que comparten visitantes, eventos, ruleta, colchón, tienda, ofertas y
escapes (PLAN-v2 "Cimientos compartidos"): los 12 tipos de premio, su forma en JSON, el "×2 con
video" y su validador. Puro, sin app. Puede correr ya: no depende de nada.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/RewardSpecTests.swift`

**Interfaces:**
- Produces: `public enum RewardSpec: Sendable, Equatable, Hashable, Codable` con
  `coinsSeconds(Double)`, `oro(Int)`, `package(Int)`, `skinChest(Int)`,
  `modifier(effect: ActiveModifier.Effect, magnitude: Double, seconds: Double)`,
  `clearBoostCooldowns`, `autoTap(perSecond: Double, seconds: Double)`,
  `nextOfflineMultiplier(Double)`, `nextDailyMultiplier(Double)`, `wheelSpin(Int)`,
  `extraSlots(Int)`, `eventImmunity(seconds: Double)`.
- Produces: `RewardSpec.Kind: String, CaseIterable, Sendable, Codable` (los 12), `var kind: Kind`,
  `func scaled(by multiplier: Int) -> RewardSpec`, `func validate() throws`,
  `enum ValidationError: Error, Equatable { case notPositive(Kind), neutralModifier }`.
- JSON: `{"kind": "<kind>", …}` con `seconds` (coinsSeconds, modifier, autoTap, eventImmunity),
  `amount` (oro), `count` (package, skinChest, wheelSpin, extraSlots), `effect` + `magnitude`
  (modifier), `perSecond` (autoTap), `multiplier` (nextOffline/DailyMultiplier).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/RewardSpecTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("RewardSpec: el vocabulario de premios")
struct RewardSpecTests {
    /// Un ejemplo por tipo, con un `switch` SIN `default`: un tipo nuevo sin
    /// ejemplo no compila, así que nunca queda uno sin ida y vuelta por JSON.
    static func sample(_ kind: RewardSpec.Kind) -> RewardSpec {
        switch kind {
        case .coinsSeconds: .coinsSeconds(900)
        case .oro: .oro(3)
        case .package: .package(1)
        case .skinChest: .skinChest(1)
        case .modifier: .modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600)
        case .clearBoostCooldowns: .clearBoostCooldowns
        case .autoTap: .autoTap(perSecond: 5, seconds: 600)
        case .nextOfflineMultiplier: .nextOfflineMultiplier(3)
        case .nextDailyMultiplier: .nextDailyMultiplier(3)
        case .wheelSpin: .wheelSpin(1)
        case .extraSlots: .extraSlots(3)
        case .eventImmunity: .eventImmunity(seconds: 1800)
        }
    }

    @Test("todo tipo va y vuelve por JSON", arguments: RewardSpec.Kind.allCases)
    func roundTrip(kind: RewardSpec.Kind) throws {
        let spec = Self.sample(kind)
        let decoded = try JSONDecoder().decode(RewardSpec.self, from: JSONEncoder().encode(spec))
        #expect(decoded == spec)
        #expect(decoded.kind == kind)
    }

    @Test("se lee la forma que escriben los JSON del juego")
    func decodesTheDataShape() throws {
        let json = """
        [
          {"kind": "coinsSeconds", "seconds": 900},
          {"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 90},
          {"kind": "package", "count": 1},
          {"kind": "oro", "amount": 1},
          {"kind": "clearBoostCooldowns"}
        ]
        """
        let specs = try JSONDecoder().decode([RewardSpec].self, from: Data(json.utf8))
        #expect(specs == [
            .coinsSeconds(900),
            .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90),
            .package(1),
            .oro(1),
            .clearBoostCooldowns,
        ])
    }

    @Test("un tipo desconocido no se adivina: el archivo entero no carga")
    func unknownKindFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RewardSpec.self, from: Data(#"{"kind": "jackpot", "count": 1}"#.utf8))
        }
    }

    @Test("el ×2 con video: lo contable se duplica y lo que dura, dura el doble")
    func videoDoublesAmountsAndDurations() {
        #expect(RewardSpec.coinsSeconds(900).scaled(by: 2) == .coinsSeconds(1800))
        #expect(RewardSpec.package(1).scaled(by: 2) == .package(2))
        #expect(RewardSpec.oro(1).scaled(by: 2) == .oro(2))
        #expect(RewardSpec.wheelSpin(1).scaled(by: 2) == .wheelSpin(2))
        // Un −30 % al doble sería un −60 % que nadie diseñó: lo que crece es el tiempo.
        #expect(RewardSpec.modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 60).scaled(by: 2)
                == .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 120))
        #expect(RewardSpec.eventImmunity(seconds: 1800).scaled(by: 2) == .eventImmunity(seconds: 3600))
    }

    @Test("lo que no es una cantidad no se duplica")
    func nonQuantitiesStayTheSame() {
        for spec in [RewardSpec.clearBoostCooldowns, .nextOfflineMultiplier(3), .nextDailyMultiplier(3), .extraSlots(3)] {
            #expect(spec.scaled(by: 2) == spec)
        }
    }

    @Test("validar rechaza premios vacíos y modificadores neutros")
    func validationRejectsEmptyRewards() {
        #expect(throws: RewardSpec.ValidationError.notPositive(.coinsSeconds)) { try RewardSpec.coinsSeconds(0).validate() }
        #expect(throws: RewardSpec.ValidationError.notPositive(.package)) { try RewardSpec.package(0).validate() }
        #expect(throws: RewardSpec.ValidationError.notPositive(.modifier)) {
            try RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 0).validate()
        }
        #expect(throws: RewardSpec.ValidationError.neutralModifier) {
            try RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 1, seconds: 60).validate()
        }
        #expect(throws: RewardSpec.ValidationError.notPositive(.nextOfflineMultiplier)) {
            try RewardSpec.nextOfflineMultiplier(1).validate()
        }
        for kind in RewardSpec.Kind.allCases {
            #expect(throws: Never.self) { try Self.sample(kind).validate() }
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter RewardSpecTests`
Expected: no compila (`RewardSpec` no existe).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift`:

```swift
import Foundation

/// El vocabulario único de premios de la 2.0 (PLAN-v2, "Cimientos compartidos"):
/// visitantes, eventos, ruleta, colchón, tienda, ofertas y escapes dicen QUÉ dan
/// con esto, y la app lo entrega en un solo punto (`GameState.grant`).
///
/// En los JSON es un objeto con `kind` y los campos de ese tipo:
/// `{"kind": "coinsSeconds", "seconds": 900}`,
/// `{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 1.5, "seconds": 600}`.
public enum RewardSpec: Sendable, Equatable, Hashable {
    /// Segundos de producción real (el `S(n)` del Anexo A). Se cotizan al cobrar,
    /// o al llegar el visitante (`VisitPlanner`).
    case coinsSeconds(Double)
    case oro(Int)
    /// Paquetes de la Aduana. Los entrega E5.
    case package(Int)
    case skinChest(Int)
    case modifier(effect: ActiveModifier.Effect, magnitude: Double, seconds: Double)
    case clearBoostCooldowns
    /// Toques automáticos. Los entrega E6.
    case autoTap(perSecond: Double, seconds: Double)
    case nextOfflineMultiplier(Double)
    case nextDailyMultiplier(Double)
    /// Giros de la ruleta. Los entrega E5.
    case wheelSpin(Int)
    /// Lugares extra por piso. Los entrega E6.
    case extraSlots(Int)
    case eventImmunity(seconds: Double)

    public enum Kind: String, CaseIterable, Sendable, Codable {
        case coinsSeconds, oro, package, skinChest, modifier, clearBoostCooldowns, autoTap
        case nextOfflineMultiplier, nextDailyMultiplier, wheelSpin, extraSlots, eventImmunity
    }

    public var kind: Kind {
        switch self {
        case .coinsSeconds: .coinsSeconds
        case .oro: .oro
        case .package: .package
        case .skinChest: .skinChest
        case .modifier: .modifier
        case .clearBoostCooldowns: .clearBoostCooldowns
        case .autoTap: .autoTap
        case .nextOfflineMultiplier: .nextOfflineMultiplier
        case .nextDailyMultiplier: .nextDailyMultiplier
        case .wheelSpin: .wheelSpin
        case .extraSlots: .extraSlots
        case .eventImmunity: .eventImmunity
        }
    }

    /// El "×2 con video" (`multiplier` 2). Lo contable se multiplica; un efecto con
    /// duración dura N veces más, no pega más fuerte (un −30 % al doble sería un
    /// −60 % que nadie diseñó); lo que no es una cantidad queda igual.
    public func scaled(by multiplier: Int) -> RewardSpec {
        let factor = Double(multiplier)
        switch self {
        case .coinsSeconds(let seconds): return .coinsSeconds(seconds * factor)
        case .oro(let amount): return .oro(amount * multiplier)
        case .package(let count): return .package(count * multiplier)
        case .skinChest(let count): return .skinChest(count * multiplier)
        case let .modifier(effect, magnitude, seconds):
            return .modifier(effect: effect, magnitude: magnitude, seconds: seconds * factor)
        case let .autoTap(perSecond, seconds): return .autoTap(perSecond: perSecond, seconds: seconds * factor)
        case .wheelSpin(let count): return .wheelSpin(count * multiplier)
        case .eventImmunity(let seconds): return .eventImmunity(seconds: seconds * factor)
        case .clearBoostCooldowns, .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots: return self
        }
    }

    public enum ValidationError: Error, Equatable {
        case notPositive(Kind)
        /// Un premio de ×1 no da nada: es un error de dato, no un premio.
        case neutralModifier
    }

    public func validate() throws {
        switch self {
        case .coinsSeconds(let seconds), .eventImmunity(seconds: let seconds):
            guard seconds > 0 else { throw ValidationError.notPositive(kind) }
        case .oro(let count), .package(let count), .skinChest(let count), .wheelSpin(let count), .extraSlots(let count):
            guard count > 0 else { throw ValidationError.notPositive(kind) }
        case let .modifier(_, magnitude, seconds):
            guard seconds > 0, magnitude > 0 else { throw ValidationError.notPositive(kind) }
            guard magnitude != 1 else { throw ValidationError.neutralModifier }
        case let .autoTap(perSecond, seconds):
            guard perSecond > 0, seconds > 0 else { throw ValidationError.notPositive(kind) }
        case .nextOfflineMultiplier(let multiplier), .nextDailyMultiplier(let multiplier):
            guard multiplier > 1 else { throw ValidationError.notPositive(kind) }
        case .clearBoostCooldowns:
            break
        }
    }
}

extension RewardSpec: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, seconds, amount, count, effect, magnitude, perSecond, multiplier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .coinsSeconds: self = .coinsSeconds(try container.decode(Double.self, forKey: .seconds))
        case .oro: self = .oro(try container.decode(Int.self, forKey: .amount))
        case .package: self = .package(try container.decode(Int.self, forKey: .count))
        case .skinChest: self = .skinChest(try container.decode(Int.self, forKey: .count))
        case .modifier:
            self = .modifier(
                effect: try container.decode(ActiveModifier.Effect.self, forKey: .effect),
                magnitude: try container.decode(Double.self, forKey: .magnitude),
                seconds: try container.decode(Double.self, forKey: .seconds)
            )
        case .clearBoostCooldowns: self = .clearBoostCooldowns
        case .autoTap:
            self = .autoTap(
                perSecond: try container.decode(Double.self, forKey: .perSecond),
                seconds: try container.decode(Double.self, forKey: .seconds)
            )
        case .nextOfflineMultiplier: self = .nextOfflineMultiplier(try container.decode(Double.self, forKey: .multiplier))
        case .nextDailyMultiplier: self = .nextDailyMultiplier(try container.decode(Double.self, forKey: .multiplier))
        case .wheelSpin: self = .wheelSpin(try container.decode(Int.self, forKey: .count))
        case .extraSlots: self = .extraSlots(try container.decode(Int.self, forKey: .count))
        case .eventImmunity: self = .eventImmunity(seconds: try container.decode(Double.self, forKey: .seconds))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .coinsSeconds(let seconds), .eventImmunity(seconds: let seconds):
            try container.encode(seconds, forKey: .seconds)
        case .oro(let amount):
            try container.encode(amount, forKey: .amount)
        case .package(let count), .skinChest(let count), .wheelSpin(let count), .extraSlots(let count):
            try container.encode(count, forKey: .count)
        case let .modifier(effect, magnitude, seconds):
            try container.encode(effect, forKey: .effect)
            try container.encode(magnitude, forKey: .magnitude)
            try container.encode(seconds, forKey: .seconds)
        case .clearBoostCooldowns:
            break
        case let .autoTap(perSecond, seconds):
            try container.encode(perSecond, forKey: .perSecond)
            try container.encode(seconds, forKey: .seconds)
        case .nextOfflineMultiplier(let multiplier), .nextDailyMultiplier(let multiplier):
            try container.encode(multiplier, forKey: .multiplier)
        }
    }
}
```

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter RewardSpecTests`
Expected: PASS — 7 tests, uno de ellos con 12 argumentos. Después
`swift test --package-path Packages/EconomyKit` entero → PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift Packages/EconomyKit/Tests/EconomyKitTests/RewardSpecTests.swift
git diff --cached --stat
git commit -m "feat(premios): RewardSpec, el vocabulario único de premios de la 2.0"
```

---

### Task 2: Los efectos nuevos de modificador — paro, inmunidad y ritmo de paquetes

**Objetivo:** los tres efectos de `ActiveModifier` que los eventos v2 necesitan:
`passiveMultiplier` (el Paro General: frena el pasivo, el toque sigue), `eventImmunity` (la Obra
social: los negativos no salen) y `packageRateMultiplier` (Lluvia de Paquetes ×10, Piquete ×0; lo
lee el `PackageScheduler` de E5). Cada uno con su texto de chip, su color y su fila en el
contrato de E1 T15 (el `switch` sin `default` obliga).

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (`Effect` + `ModifierMath.isImmuneToEvents`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift` (`passivePerSecond`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/EventModifierEffectsTests.swift`
- Modify: `FisuEvolution/Game/State/ActiveBonus.swift` (`ActiveBonusBuilder.effectText`)
- Modify: `FisuEvolution/UI/HUD/ActiveBonusBar.swift` (`tint`)
- Modify: `FisuEvolutionTests/EffectContractTests.swift` (`modifierEffects`, tres filas)
- Strings: `Tools/v2/claves-pendientes/e4a-t2.json` (2 claves)

**Interfaces:**
- Consumes: `ActiveModifier.Effect.spendingFrozen` (E1 T13), `Effect: CaseIterable` y
  `EffectContractTests` (E1 T15).
- Produces: `ActiveModifier.Effect.passiveMultiplier`, `.eventImmunity`, `.packageRateMultiplier`;
  `ModifierMath.isImmuneToEvents(_ modifiers: [ActiveModifier], now: TimeInterval) -> Bool`.

- [ ] **Step 0: ¿Ya existe alguno?**

Run: `grep -n "case passiveMultiplier\|case eventImmunity\|case packageRateMultiplier" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift`
Si E2a ya sumó alguno (la Obra social del Médico es de su tabla de premios), **no se crea de
nuevo**: se suman sólo los que faltan y los tests de abajo verifican que el que existía haga lo
que dicen. Si su semántica difiere (por ejemplo, una inmunidad que filtra también los mixtos),
para con `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/EventModifierEffectsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Efectos de modificador de los eventos v2")
struct EventModifierEffectsTests {
    let tiers: TierRepository
    let floorTable: FloorTable
    let config = fxConfig()

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func producing() -> PlayerState {
        var state = fxState(units: ["a": 2])
        state.run.passiveUnlocked["a"] = true
        return state
    }

    private func passive(_ state: PlayerState, now: TimeInterval) -> Double {
        IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
    }

    private func tap(_ state: PlayerState, now: TimeInterval) throws -> Double {
        var copy = state
        return fxEconomy().applyTap(type: try #require(tiers.type(id: "a")), state: &copy, floorTable: floorTable, now: now)
    }

    @Test("el paro frena el pasivo y deja el toque; vencido, vuelve")
    func passiveMultiplierStopsOnlyThePassive() throws {
        var state = producing()
        let before = passive(state, now: 10)
        let tapBefore = try tap(state, now: 10)
        state.run.activeModifiers = [
            ActiveModifier(effect: .passiveMultiplier, magnitude: 0, expiresAt: 40, sourceKey: "event.paro_general"),
        ]
        #expect(before > 0)
        #expect(passive(state, now: 10) == 0)
        #expect(try tap(state, now: 10) == tapBefore, "el paro es del pasivo: tocar sigue pagando")
        #expect(passive(state, now: 40) == before)
    }

    @Test("un pasivo ×3 multiplica el pasivo y no el toque")
    func passiveMultiplierBuffs() throws {
        var state = producing()
        let before = passive(state, now: 10)
        let tapBefore = try tap(state, now: 10)
        state.run.activeModifiers = [ActiveModifier(effect: .passiveMultiplier, magnitude: 3, expiresAt: 40, sourceKey: "x")]
        #expect(abs(passive(state, now: 10) - before * 3) < 1e-9)
        #expect(try tap(state, now: 10) == tapBefore)
    }

    @Test("la inmunidad se nota mientras dura y no toca los ingresos")
    func immunity() throws {
        var state = producing()
        let before = passive(state, now: 10)
        state.run.activeModifiers = [ActiveModifier(effect: .eventImmunity, magnitude: 1, expiresAt: 1800, sourceKey: "career.junior_doctor")]
        #expect(ModifierMath.isImmuneToEvents(state.run.activeModifiers, now: 10))
        #expect(!ModifierMath.isImmuneToEvents(state.run.activeModifiers, now: 1800))
        #expect(!ModifierMath.isImmuneToEvents([], now: 10))
        #expect(passive(state, now: 10) == before)
    }

    @Test("el ritmo de paquetes no toca ni el pasivo ni el toque")
    func packageRateIsOnlyForPackages() throws {
        var state = producing()
        let before = passive(state, now: 10)
        let tapBefore = try tap(state, now: 10)
        state.run.activeModifiers = [ActiveModifier(effect: .packageRateMultiplier, magnitude: 10, expiresAt: 60, sourceKey: "event.lluvia_paquetes")]
        #expect(passive(state, now: 10) == before)
        #expect(try tap(state, now: 10) == tapBefore)
        #expect(ModifierMath.factor(state.run.activeModifiers, effect: .packageRateMultiplier, now: 10) == 10)
    }

    @Test("los efectos nuevos se leen de un save que todavía no los conocía")
    func newEffectsDecode() throws {
        let json = #"{"id":"6A1D2F3E-0000-0000-0000-000000000000","effect":"passiveMultiplier","magnitude":0,"expiresAt":30,"sourceKey":"event.paro_general"}"#
        let modifier = try JSONDecoder().decode(ActiveModifier.self, from: Data(json.utf8))
        #expect(modifier.effect == .passiveMultiplier)
    }
}
```

En `FisuEvolutionTests/EffectContractTests.swift`, dentro del `switch effect` de `modifierEffects`
(el de E1 T15, sin `default`), las tres filas nuevas:

```swift
            case .passiveMultiplier:
                #expect(chip == applied(passive(boosted) / passive(plain), as: .multiplier))
                let tapPlain = economy.applyTap(type: base, state: &plain, floorTable: content.floorTable, now: 0)
                let tapBoosted = economy.applyTap(type: base, state: &boosted, floorTable: content.floorTable, now: 0)
                #expect(tapBoosted == tapPlain, "el pasivo no es el toque")
            case .eventImmunity:
                #expect(chip == String(localized: "bonus.chip.immunity"))
                #expect(passive(boosted) == passive(plain))
                #expect(ModifierMath.isImmuneToEvents(boosted.run.activeModifiers, now: 0))
            case .packageRateMultiplier:
                #expect(chip == String(localized: "bonus.chip.packages \(applied(3, as: .multiplier))"))
                #expect(passive(boosted) == passive(plain))
```

(`tower` sigue sin usarse en esas filas; si el compilador avisa "never used" porque cambió la
forma de la tupla, se usa `_` en el `var (plain, _)` de la fila, nunca un `default`.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter EventModifierEffectsTests`
Expected: no compila (`passiveMultiplier` no existe).

- [ ] **Step 3: EconomyKit**

`ActiveModifier.swift`, en `enum Effect` (después de `spendingFrozen`, que trajo E1 T13):

```swift
        /// Multiplica SÓLO el pasivo (el Paro General lo lleva a ×0): el toque sigue.
        case passiveMultiplier
        /// Inmunidad a los eventos negativos (la Obra social del Médico). La
        /// magnitud no importa: lo que cuenta es hasta cuándo.
        case eventImmunity
        /// Multiplica el ritmo del Paquete de la Aduana (Lluvia ×10, Piquete ×0).
        /// Lo lee el `PackageScheduler` de E5; no toca los ingresos.
        case packageRateMultiplier
```

y en `ModifierMath`:

```swift
    /// Hay una inmunidad viva: los eventos negativos no salen en el sorteo (los
    /// mixtos sí: la inmunidad es contra lo que sólo resta).
    public static func isImmuneToEvents(_ modifiers: [ActiveModifier], now: TimeInterval) -> Bool {
        modifiers.contains { $0.effect == .eventImmunity && $0.isActive(at: now) }
    }
```

`IncomeTicker.passivePerSecond`:

```swift
    public static func passivePerSecond(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
            * ModifierMath.factor(state.run.activeModifiers, effect: .incomeMultiplier, now: now)
            * ModifierMath.factor(state.run.activeModifiers, effect: .passiveMultiplier, now: now)
    }
```

`OfflineCalculator` **no cambia**: hoy el único `passiveMultiplier` es un debuff (el Paro), y los
debuffs no cuentan afuera (E1 T1). Un buff de pasivo futuro tendría que sumarse a su integral.

- [ ] **Step 4: La app**

`ActiveBonus.swift`, `ActiveBonusBuilder.effectText(for:)` queda (los casos de E1 T13 se
conservan):

```swift
    private static func effectText(for modifier: ActiveModifier) -> String {
        let boostEffect: BoostsConfig.EffectType
        switch modifier.effect {
        case .incomeMultiplier, .passiveMultiplier: boostEffect = .incomeMultiplier
        case .tapMultiplier: boostEffect = .tapMultiplier
        case .spawnCostMultiplier: boostEffect = .spawnCostMultiplier
        case .spendingFrozen: return String(localized: "bonus.chip.spending_frozen")
        case .eventImmunity: return String(localized: "bonus.chip.immunity")
        case .packageRateMultiplier:
            let value = EffectFormatter.text(EffectDescriptor.amount(forBoost: .incomeMultiplier, magnitude: modifier.magnitude))
            return String(localized: "bonus.chip.packages \(value)")
        }
        return EffectFormatter.text(EffectDescriptor.amount(forBoost: boostEffect, magnitude: modifier.magnitude))
    }
```

`ActiveBonusBar.tint(_:)` (el color dice QUÉ potencia; el número va siempre al lado):

```swift
        case .passiveMultiplier: Color("PaletteGreen")
        case .eventImmunity: Color("PaletteYellow")
        case .packageRateMultiplier: Color("PaletteBrown")
```

`Tools/v2/claves-pendientes/e4a-t2.json`:

```json
{
  "bonus.chip.immunity": {"es": "Inmune", "en": "Immune"},
  "bonus.chip.packages %@": {"es": "Paquetes %@", "en": "Packages %@"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4a-t2.json` (el catálogo aplicado
es lo que deja correr los tests; ver Global Constraints para qué se commitea).

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `EventModifierEffectsTests`,
5 tests); Receta R con `-only-testing:FisuEvolutionTests/EffectContractTests -only-testing:FisuEvolutionTests/ActiveBonusTests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/EventModifierEffectsTests.swift FisuEvolution/Game/State/ActiveBonus.swift \
  FisuEvolution/UI/HUD/ActiveBonusBar.swift FisuEvolutionTests/EffectContractTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4a-t2.json, según la ola
git diff --cached --stat
git commit -m "feat(eventos): el paro, la inmunidad y el ritmo de paquetes como efectos de modificador"
```

---

### Task 3: Los relojes de visitantes y eventos viven en `meta.engagement`

**Objetivo:** el estado persistente de E4 entra al contenedor de E1 sin subir el schema:
`visitors` (dos relojes de juego activo, anti-repetición, visitas del día y ORO cambiado hoy) y
`events` (reloj de juego, cooldowns y el próximo ya sorteado). Un save que no los tiene
decodifica con `.initial`; dos saves en conflicto no duplican el cupo del día.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsState.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Events/EventsState.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/EngagementStageStateTests.swift`

**Interfaces:**
- Consumes: `EngagementState` (E1 T4) con `sharedMoments` y su `init(from:)` (E3b T9).
- Produces: `public struct VisitorsState: Codable, Sendable, Equatable` con
  `secondsUntilVisit: Double?`, `secondsUntilVendor: Double?`, `recentScripts: [String]`,
  `day: String?`, `visitsToday: [String: Int]`, `oroExchangedToday: Int`, `static let initial`,
  `static func resolve(winner:loser:)`.
- Produces: `public struct EventsState: Codable, Sendable, Equatable` con `clock: Double`,
  `secondsUntilNext: Double?`, `lastFiredAt: [String: Double]`, `upcomingId: String?`,
  `static let initial`, `static func resolve(winner:loser:)`.
- Produces: `EngagementState.visitors: VisitorsState`, `EngagementState.events: EventsState`.

⚠️ **Si E3b T9 todavía no entró** (no hay `sharedMoments`), esta tarea va después: las dos
escriben el mismo `init(from:)`. Si el controlador decide adelantarla igual, se sacan las líneas
marcadas `// E3b T9` del struct y el test `keepsWhatWasWrittenBefore` pierde su primera aserción.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/EngagementStageStateTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// Los relojes de visitantes y eventos viven en `meta.engagement` (PLAN-v2 E4),
/// sin subir el schema del save.
@Suite("EngagementState: visitantes y eventos")
struct EngagementStageStateTests {
    @Test("un engagement escrito antes de E4 decodifica con los dos en su estado inicial")
    func decodesWithoutTheKeys() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.visitors == .initial)
        #expect(state.events == .initial)
    }

    @Test("lo que ya estaba escrito se conserva")
    func keepsWhatWasWrittenBefore() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(#"{"sharedMoments": ["god"]}"#.utf8))
        #expect(state.sharedMoments == ["god"])  // E3b T9
        #expect(state.visitors.secondsUntilVisit == nil, "sin programar: el scheduler arranca en la primera visita")
    }

    @Test("un estado a medias también decodifica")
    func partialStatesDecode() throws {
        let json = #"{"visitors": {"secondsUntilVisit": 42}, "events": {"clock": 900}}"#
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(json.utf8))
        #expect(state.visitors.secondsUntilVisit == 42)
        #expect(state.visitors.recentScripts.isEmpty)
        #expect(state.events.clock == 900)
        #expect(state.events.lastFiredAt.isEmpty)
    }

    @Test("ida y vuelta, adentro del save entero")
    func roundTripInsideTheSave() throws {
        var player = fxState()
        player.meta.engagement.visitors = VisitorsState(
            secondsUntilVisit: 120, secondsUntilVendor: 30, recentScripts: ["turista_propina"],
            day: "2026-10-07", visitsToday: ["turista_propina": 1], oroExchangedToday: 2
        )
        player.meta.engagement.events = EventsState(
            clock: 1234, secondsUntilNext: 600, lastFiredAt: ["devaluacion": 1000], upcomingId: "apagon"
        )
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(player))
        #expect(decoded.meta.engagement == player.meta.engagement)
    }

    @Test("al resolver un conflicto, el cupo del mismo día no se duplica")
    func resolveKeepsTheDailyCaps() {
        let winner = VisitorsState(secondsUntilVisit: 10, day: "2026-10-07", visitsToday: ["a": 1], oroExchangedToday: 1)
        let loser = VisitorsState(secondsUntilVisit: 99, day: "2026-10-07", visitsToday: ["a": 2, "b": 1], oroExchangedToday: 3)
        let resolved = VisitorsState.resolve(winner: winner, loser: loser)
        #expect(resolved.secondsUntilVisit == 10, "los relojes viajan con el ganador")
        #expect(resolved.visitsToday == ["a": 2, "b": 1])
        #expect(resolved.oroExchangedToday == 3)
    }

    @Test("el cupo de otro día no cuenta")
    func resolveIgnoresAnotherDay() {
        let winner = VisitorsState(day: "2026-10-08", visitsToday: ["a": 1])
        let loser = VisitorsState(day: "2026-10-07", visitsToday: ["a": 3], oroExchangedToday: 3)
        #expect(VisitorsState.resolve(winner: winner, loser: loser) == winner)
    }

    @Test("los cooldowns de eventos se quedan con el más reciente")
    func resolveEventCooldowns() {
        let winner = EventsState(clock: 500, secondsUntilNext: 100, lastFiredAt: ["a": 400])
        let loser = EventsState(clock: 900, secondsUntilNext: 5, lastFiredAt: ["a": 800, "b": 700])
        let resolved = EventsState.resolve(winner: winner, loser: loser)
        #expect(resolved.clock == 900)
        #expect(resolved.secondsUntilNext == 100)
        #expect(resolved.lastFiredAt == ["a": 800, "b": 700])
    }

    @Test("EngagementState.resolve usa las dos reglas")
    func engagementResolveDelegates() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.visitors = VisitorsState(day: "d", visitsToday: ["a": 1])
        loser.visitors = VisitorsState(day: "d", visitsToday: ["a": 2])
        loser.events = EventsState(clock: 50, lastFiredAt: ["x": 40])
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.visitors.visitsToday == ["a": 2])
        #expect(resolved.events.lastFiredAt == ["x": 40])
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter EngagementStageStateTests`
Expected: no compila (`VisitorsState` no existe).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsState.swift`:

```swift
import Foundation

/// Lo que se recuerda de los visitantes entre partidas (PLAN-v2 E4). Los relojes
/// son de JUEGO ACTIVO: el background no los mueve.
public struct VisitorsState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta la próxima visita del carril principal. `nil` =
    /// nunca se programó (partida nueva o save anterior a E4): el scheduler
    /// arranca en `firstVisitAfterSeconds`.
    public var secondsUntilVisit: Double?
    /// Ídem, el carril del Vendedor Ambulante.
    public var secondsUntilVendor: Double?
    /// Los últimos guiones que salieron, el más nuevo al final.
    public var recentScripts: [String]
    /// El día calendario ("yyyy-MM-dd") de los dos contadores de abajo.
    public var day: String?
    public var visitsToday: [String: Int]
    /// ORO que el del Arbolito ya te cambió hoy (tope diario del guion).
    public var oroExchangedToday: Int

    public static let initial = VisitorsState()

    public init(
        secondsUntilVisit: Double? = nil,
        secondsUntilVendor: Double? = nil,
        recentScripts: [String] = [],
        day: String? = nil,
        visitsToday: [String: Int] = [:],
        oroExchangedToday: Int = 0
    ) {
        self.secondsUntilVisit = secondsUntilVisit
        self.secondsUntilVendor = secondsUntilVendor
        self.recentScripts = recentScripts
        self.day = day
        self.visitsToday = visitsToday
        self.oroExchangedToday = oroExchangedToday
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilVisit = try container.decodeIfPresent(Double.self, forKey: .secondsUntilVisit)
        secondsUntilVendor = try container.decodeIfPresent(Double.self, forKey: .secondsUntilVendor)
        recentScripts = try container.decodeIfPresent([String].self, forKey: .recentScripts) ?? []
        day = try container.decodeIfPresent(String.self, forKey: .day)
        visitsToday = try container.decodeIfPresent([String: Int].self, forKey: .visitsToday) ?? [:]
        oroExchangedToday = try container.decodeIfPresent(Int.self, forKey: .oroExchangedToday) ?? 0
    }

    /// Los relojes viajan con el ganador. Los topes del día, si los dos saves
    /// hablan del mismo día, se quedan con lo más alto: dos dispositivos no
    /// duplican el cupo.
    public static func resolve(winner: VisitorsState, loser: VisitorsState) -> VisitorsState {
        guard winner.day != nil, winner.day == loser.day else { return winner }
        var resolved = winner
        resolved.visitsToday = winner.visitsToday.merging(loser.visitsToday, uniquingKeysWith: max)
        resolved.oroExchangedToday = max(winner.oroExchangedToday, loser.oroExchangedToday)
        return resolved
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Events/EventsState.swift`:

```swift
import Foundation

/// Lo que se recuerda de los eventos v2 (PLAN-v2 E4). Hasta la 1.x el reloj vivía
/// en memoria y se reiniciaba en cada arranque: quien abría la app de a ratos
/// cortos no veía nunca un evento.
public struct EventsState: Codable, Sendable, Equatable {
    /// Segundos de juego activo acumulados. Los cooldowns se miden contra esto.
    public var clock: Double
    /// Segundos de juego hasta el próximo sorteo. `nil` = nunca se programó.
    public var secondsUntilNext: Double?
    /// Cuándo salió cada evento, en `clock`.
    public var lastFiredAt: [String: Double]
    /// El próximo, ya sorteado: la Vecina chusma lo adelanta y es el que sale.
    public var upcomingId: String?

    public static let initial = EventsState()

    public init(
        clock: Double = 0,
        secondsUntilNext: Double? = nil,
        lastFiredAt: [String: Double] = [:],
        upcomingId: String? = nil
    ) {
        self.clock = clock
        self.secondsUntilNext = secondsUntilNext
        self.lastFiredAt = lastFiredAt
        self.upcomingId = upcomingId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clock = try container.decodeIfPresent(Double.self, forKey: .clock) ?? 0
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        lastFiredAt = try container.decodeIfPresent([String: Double].self, forKey: .lastFiredAt) ?? [:]
        upcomingId = try container.decodeIfPresent(String.self, forKey: .upcomingId)
    }

    /// El reloj más avanzado y el cooldown más reciente de cada evento: un
    /// evento que salió en cualquiera de los dos dispositivos no vuelve antes.
    public static func resolve(winner: EventsState, loser: EventsState) -> EventsState {
        var resolved = winner
        resolved.clock = max(winner.clock, loser.clock)
        resolved.lastFiredAt = winner.lastFiredAt.merging(loser.lastFiredAt, uniquingKeysWith: max)
        return resolved
    }
}
```

`EngagementState.swift` queda así (lo de E1 T4 y E3b T9 se conserva; si otra épica ya sumó otro
campo, se agrega al mismo `init` y al mismo `resolve`):

```swift
import Foundation

/// Lo que suman las épicas de engagement (visitantes, paquetes, colchón, ruleta,
/// tienda, ofertas). Crece campo a campo con `decodeIfPresent ?? default` y su
/// regla en `resolve`, sin volver a subir el schema del save.
public struct EngagementState: Codable, Sendable, Equatable {
    public static let initial = EngagementState()

    /// Las claves de los momentos virales ya compartidos (E3b T9).
    public var sharedMoments: Set<String>  // E3b T9
    /// Visitantes: relojes de juego activo, anti-repetición y topes del día (E4).
    public var visitors: VisitorsState
    /// Eventos v2: reloj de juego, cooldowns y el próximo ya sorteado (E4).
    public var events: EventsState

    public init(
        sharedMoments: Set<String> = [],  // E3b T9
        visitors: VisitorsState = .initial,
        events: EventsState = .initial
    ) {
        self.sharedMoments = sharedMoments  // E3b T9
        self.visitors = visitors
        self.events = events
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sharedMoments = try container.decodeIfPresent(Set<String>.self, forKey: .sharedMoments) ?? []  // E3b T9
        visitors = try container.decodeIfPresent(VisitorsState.self, forKey: .visitors) ?? .initial
        events = try container.decodeIfPresent(EventsState.self, forKey: .events) ?? .initial
    }

    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        var resolved = winner
        resolved.sharedMoments.formUnion(loser.sharedMoments)  // E3b T9
        resolved.visitors = VisitorsState.resolve(winner: winner.visitors, loser: loser.visitors)
        resolved.events = EventsState.resolve(winner: winner.events, loser: loser.events)
        return resolved
    }
}
```

(los comentarios `// E3b T9` son marcas para este plan: **no se commitean**.)

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit` → PASS, con `EngagementStageStateTests` (8)
y las suites de E1/E3b sobre el save (`SaveCompatibilityTests`, `SaveConflictResolverTests`,
`EngagementStateTests`) sin cambios. Receta R con `-only-testing:FisuEvolutionTests/SaveMigratorTests -only-testing:FisuEvolutionTests/PersistenceTests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsState.swift \
  Packages/EconomyKit/Sources/EconomyKit/Events/EventsState.swift \
  Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/EngagementStageStateTests.swift
git diff --cached --stat
git commit -m "feat(save): los relojes de visitantes y eventos viven en meta.engagement"
```

---

### Task 4: El motor de eventos v2, puro — catálogo compuesto, sorteo en reloj de juego y salidas

**Objetivo:** `events.json` schema 2 como tipo de EconomyKit (efectos compuestos, `polarity`,
`presenters[]`, `escapes[]` con `video | fee | free`, escena y velitas) con su validador; el
sorteo con reloj de juego activo (cooldowns en ese reloj, inmunidad contra los negativos y no
contra los mixtos, lo inaplicable afuera, sorteo vacío que reintenta, gracia al volver, el
próximo que se puede adelantar); y el planificador que traduce un evento a modificadores,
segundos de producción, una intención de tablero y un llamado a un visitante. Se llama
`EventCatalog` para no chocar con el `EventsConfig` de la app, que se borra en la Task 9.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Events/EventCatalog.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Events/EventScheduler.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Events/EventPlanner.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/EventsEngineTests.swift` (tres suites: `EventCatalogTests`, `EventSchedulerTests`, `EventPlannerTests`)

**Interfaces:**
- Consumes: `EventsState` (T3); `ActiveModifier.Effect` con los casos de T2;
  `IncomeTicker.deltaClampThreshold`; `TierRepository.concreteTypes`.
- Produces: `public struct EventCatalog: Codable, Sendable, Equatable` con `schemaVersion`,
  `firstEventAfterSeconds`, `intervalSeconds`, `intervalJitterSeconds`, `resumeGraceSeconds`,
  `retryWhenNoneApplicableSeconds`, `events: [Event]`, `func event(id:) -> Event?`,
  `func validate(visitorIDs: Set<String>, scriptIDs: Set<String>) throws`.
- Produces: `EventCatalog.Polarity` (`positive | negative | mixed`), `EventCatalog.Scene`
  (`blackout | champions | sale`), `EventCatalog.Effect` (`modifier(effect:magnitude:)`,
  `coinsSeconds(Double)`, `evolveBestUnit`, `grantUnit(tiersBelowFrontier:)`,
  `callVisitor(script:)`), `EventCatalog.Escape` (`kind: Kind` = `video | fee | free`,
  `feeSeconds: Double?`, `removes: [ActiveModifier.Effect]?`), `EventCatalog.Event` (`id`,
  `polarity`, `durationSeconds`, `weight`, `minTier`, `cooldownSeconds`, `titleKey`, `phraseKey`,
  `presenters`, `effects`, `escapes`, `scene: Scene?`, `candleStep: Double?`, `sourceKey`,
  `modifierEffects: Set<ActiveModifier.Effect>`).
- Produces: `EventScheduler.advance(_:delta:catalog:) -> Bool`,
  `eligible(catalog:state:maxTier:isImmune:isApplicable:)`, `roll(…, rng:)`,
  `peekUpcoming(catalog:state:maxTier:isImmune:isApplicable:rng:)` (inout state),
  `takeDue(…)` (inout state), `markFired(_:state:catalog:rng:)`, `retrySoon(state:catalog:)`,
  `applyResumeGrace(state:catalog:)`.
- Produces: `EventPlanner.apply(_:state:tiers:now:) -> EventApplication`
  (`modifiers`, `coinsSeconds`, `boardIntent: EventBoardIntent?`, `calledScript: String?`,
  `scene`), `EventBoardIntent` (`evolveBestUnit | grantUnit(typeId:)`),
  `grantedUnitType(tiersBelowFrontier:state:tiers:)`, `escape(_:of:from:)`,
  `cutNegatives(_:catalog:)`, `running(_:catalog:now:) -> [RunningEvent]`,
  `lightCandle(_:event:now:) -> [ActiveModifier]?`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/EventsEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// Un catálogo chico con un evento de cada forma.
func fxEventCatalog(
    first: Double = 900,
    interval: Double = 900,
    jitter: Double = 300,
    events: [EventCatalog.Event]? = nil
) -> EventCatalog {
    EventCatalog(
        schemaVersion: 2,
        firstEventAfterSeconds: first,
        intervalSeconds: interval,
        intervalJitterSeconds: jitter,
        resumeGraceSeconds: 60,
        retryWhenNoneApplicableSeconds: 30,
        events: events ?? [
            fxEvent("boom", .positive, effects: [.modifier(effect: .incomeMultiplier, magnitude: 3)]),
            fxEvent("bajon", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)],
                    escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)]),
            fxEvent("mezcla", .mixed, effects: [
                .modifier(effect: .spawnCostMultiplier, magnitude: 2),
                .modifier(effect: .incomeMultiplier, magnitude: 3),
            ], escapes: [.init(kind: .video, feeSeconds: nil, removes: [.spawnCostMultiplier])]),
            fxEvent("regalo", .positive, duration: 0, effects: [.grantUnit(tiersBelowFrontier: 1), .coinsSeconds(300)]),
        ]
    )
}

func fxEvent(
    _ id: String,
    _ polarity: EventCatalog.Polarity,
    duration: Double = 60,
    weight: Int = 10,
    minTier: Int = 1,
    cooldown: Double = 600,
    effects: [EventCatalog.Effect],
    escapes: [EventCatalog.Escape] = [],
    scene: EventCatalog.Scene? = nil,
    candleStep: Double? = nil
) -> EventCatalog.Event {
    EventCatalog.Event(
        id: id, polarity: polarity, durationSeconds: duration, weight: weight, minTier: minTier,
        cooldownSeconds: cooldown, titleKey: "event.\(id).title", phraseKey: "event.\(id).phrase",
        presenters: ["npc_ministro"], effects: effects, escapes: escapes, scene: scene, candleStep: candleStep
    )
}

@Suite("Eventos v2: el catálogo")
struct EventCatalogTests {
    @Test("se lee la forma del JSON del juego")
    func decodesTheDataShape() throws {
        let json = """
        {"schemaVersion": 2, "firstEventAfterSeconds": 900, "intervalSeconds": 900, "intervalJitterSeconds": 300,
         "resumeGraceSeconds": 60, "retryWhenNoneApplicableSeconds": 30,
         "events": [
           {"id": "paro_general", "polarity": "negative", "durationSeconds": 30, "weight": 8, "minTier": 6,
            "cooldownSeconds": 2400, "titleKey": "event.paro_general.title", "phraseKey": "event.paro_general.phrase",
            "presenters": ["npc_sindicalista"],
            "effects": [{"kind": "modifier", "effect": "passiveMultiplier", "magnitude": 0}],
            "escapes": [{"kind": "fee", "feeSeconds": 120}, {"kind": "video"}]},
           {"id": "cepo", "polarity": "negative", "durationSeconds": 60, "weight": 6, "minTier": 6,
            "cooldownSeconds": 3600, "titleKey": "event.cepo.title", "phraseKey": "event.cepo.phrase",
            "presenters": ["npc_ministro"],
            "effects": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 1.5},
                        {"kind": "callVisitor", "script": "arbolito_blue"}],
            "escapes": [{"kind": "video"}]},
           {"id": "apagon", "polarity": "negative", "durationSeconds": 45, "weight": 8, "minTier": 5,
            "cooldownSeconds": 2400, "titleKey": "event.apagon.title", "phraseKey": "event.apagon.phrase",
            "presenters": ["npc_vecina"], "scene": "blackout", "candleStep": 0.07,
            "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 0.3}],
            "escapes": [{"kind": "video"}]},
           {"id": "blanqueo", "polarity": "positive", "durationSeconds": 0, "weight": 4, "minTier": 9,
            "cooldownSeconds": 5400, "titleKey": "event.blanqueo.title", "phraseKey": "event.blanqueo.phrase",
            "presenters": ["npc_ministro"], "effects": [{"kind": "grantUnit", "tiersBelowFrontier": 3}], "escapes": []},
           {"id": "startup_comprada", "polarity": "positive", "durationSeconds": 0, "weight": 8, "minTier": 5,
            "cooldownSeconds": 2700, "titleKey": "event.startup_comprada.title", "phraseKey": "event.startup_comprada.phrase",
            "presenters": ["npc_conductor"], "effects": [{"kind": "evolveBestUnit"}], "escapes": []}
         ]}
        """
        let catalog = try JSONDecoder().decode(EventCatalog.self, from: Data(json.utf8))
        let paro = try #require(catalog.event(id: "paro_general"))
        #expect(paro.effects == [.modifier(effect: .passiveMultiplier, magnitude: 0)])
        #expect(paro.escapes.map(\.kind) == [.fee, .video])
        #expect(paro.escapes.first?.feeSeconds == 120)
        #expect(catalog.event(id: "cepo")?.effects.last == .callVisitor(script: "arbolito_blue"))
        #expect(catalog.event(id: "apagon")?.scene == .blackout)
        #expect(catalog.event(id: "apagon")?.candleStep == 0.07)
        #expect(catalog.event(id: "blanqueo")?.effects == [.grantUnit(tiersBelowFrontier: 3)])
        #expect(catalog.event(id: "startup_comprada")?.effects == [.evolveBestUnit])
        #expect(try JSONDecoder().decode(EventCatalog.self, from: JSONEncoder().encode(catalog)) == catalog)
        try catalog.validate(
            visitorIDs: ["npc_sindicalista", "npc_ministro", "npc_vecina", "npc_conductor"],
            scriptIDs: ["arbolito_blue"]
        )
    }

    private func reject(_ event: EventCatalog.Event) {
        let catalog = fxEventCatalog(events: [event])
        #expect(throws: EventCatalog.ValidationError.self) {
            try catalog.validate(visitorIDs: ["npc_ministro"], scriptIDs: ["arbolito_blue"])
        }
    }

    @Test("el validador frena lo que el juego no puede cumplir")
    func validationRejectsBrokenEvents() {
        // Un negativo siempre tiene salida por video (decisión del dueño, PLAN-v2 §2).
        reject(fxEvent("a", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)]))
        reject(fxEvent("b", .mixed, effects: [.modifier(effect: .incomeMultiplier, magnitude: 3)],
                       escapes: [.init(kind: .free, feeSeconds: nil, removes: nil)]))
        reject(fxEvent("c", .positive, duration: 0, effects: [.modifier(effect: .incomeMultiplier, magnitude: 3)]))
        reject(fxEvent("d", .positive, effects: []))
        reject(fxEvent("e", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)],
                       escapes: [.init(kind: .video, feeSeconds: nil, removes: [.tapMultiplier])]))
        reject(fxEvent("f", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.5)],
                       escapes: [.init(kind: .fee, feeSeconds: 0, removes: nil), .init(kind: .video, feeSeconds: nil, removes: nil)]))
        reject(fxEvent("g", .positive, effects: [.callVisitor(script: "nadie")]))
        reject(fxEvent("h", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.3)],
                       escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)], scene: .blackout))
        reject(EventCatalog.Event(
            id: "i", polarity: .positive, durationSeconds: 0, weight: 1, minTier: 1, cooldownSeconds: 0,
            titleKey: "t", phraseKey: "p", presenters: ["npc_nadie"], effects: [.coinsSeconds(300)], escapes: [],
            scene: nil, candleStep: nil
        ))
    }

    @Test("dos eventos con el mismo id no se distinguen en los cooldowns")
    func duplicateIds() {
        let event = fxEvent("x", .positive, effects: [.coinsSeconds(10)])
        #expect(throws: EventCatalog.ValidationError.duplicateId("x")) {
            try fxEventCatalog(events: [event, event]).validate(visitorIDs: ["npc_ministro"], scriptIDs: [])
        }
    }

    @Test("el fixture es válido")
    func fixtureIsValid() throws {
        try fxEventCatalog().validate(visitorIDs: ["npc_ministro"], scriptIDs: [])
    }
}

@Suite("Eventos v2: el sorteo en reloj de juego")
struct EventSchedulerTests {
    let catalog = fxEventCatalog()

    private func advance(_ state: inout EventsState, seconds: Double) -> Bool {
        var due = false
        var elapsed = 0.0
        while elapsed < seconds {
            due = EventScheduler.advance(&state, delta: 1, catalog: catalog) || due
            elapsed += 1
        }
        return due
    }

    @Test("el primero vence a los firstEventAfterSeconds de juego, no antes")
    func firstEventAfterPlayTime() {
        var state = EventsState.initial
        #expect(!advance(&state, seconds: 899))
        #expect(advance(&state, seconds: 1))
        #expect(state.clock == 900)
    }

    @Test("un salto grande del tick no cuenta: el background no es juego")
    func deltaIsClamped() {
        var state = EventsState.initial
        _ = EventScheduler.advance(&state, delta: 3600, catalog: catalog)
        #expect(state.clock == IncomeTicker.deltaClampThreshold)
        #expect(state.secondsUntilNext == 900 - IncomeTicker.deltaClampThreshold)
    }

    @Test("el cooldown se mide en reloj de juego")
    func cooldownInPlayClock() {
        var state = EventsState(clock: 1000, lastFiredAt: ["boom": 500])
        let ids = EventScheduler.eligible(catalog: catalog, state: state, maxTier: 5, isImmune: false) { _ in true }.map(\.id)
        #expect(!ids.contains("boom"))
        state.clock = 1100
        #expect(EventScheduler.eligible(catalog: catalog, state: state, maxTier: 5, isImmune: false) { _ in true }
            .map(\.id).contains("boom"))
    }

    @Test("el tier mínimo y lo inaplicable quedan afuera")
    func tierAndApplicability() {
        let gated = fxEventCatalog(events: [fxEvent("alto", .positive, minTier: 9, effects: [.coinsSeconds(1)])])
        #expect(EventScheduler.eligible(catalog: gated, state: .initial, maxTier: 8, isImmune: false) { _ in true }.isEmpty)
        #expect(EventScheduler.eligible(catalog: catalog, state: .initial, maxTier: 5, isImmune: false) { $0.id != "regalo" }
            .map(\.id).sorted() == ["bajon", "boom", "mezcla"])
    }

    @Test("con inmunidad no sale un negativo; un mixto sí")
    func immunityFiltersNegativesOnly() {
        let ids = EventScheduler.eligible(catalog: catalog, state: .initial, maxTier: 5, isImmune: true) { _ in true }.map(\.id)
        #expect(!ids.contains("bajon"))
        #expect(ids.contains("mezcla"))
    }

    @Test("el sorteo respeta los pesos y sólo elige elegibles")
    func rollRespectsWeights() {
        var rng = SeededRNG(seed: 7)
        var seen: Set<String> = []
        for _ in 0..<200 {
            guard let event = EventScheduler.roll(catalog: catalog, state: .initial, maxTier: 5, isImmune: true,
                                                  isApplicable: { $0.id != "boom" }, rng: &rng) else { continue }
            seen.insert(event.id)
        }
        #expect(seen == ["mezcla", "regalo"])
    }

    @Test("sin elegibles no hay evento")
    func emptyRoll() {
        var rng = SeededRNG(seed: 1)
        #expect(EventScheduler.roll(catalog: catalog, state: .initial, maxTier: 5, isImmune: false,
                                    isApplicable: { _ in false }, rng: &rng) == nil)
    }

    @Test("lo que la Vecina adelanta es lo que sale")
    func upcomingIsWhatComes() throws {
        var state = EventsState.initial
        var rng = SeededRNG(seed: 3)
        let peeked = try #require(EventScheduler.peekUpcoming(catalog: catalog, state: &state, maxTier: 5, isImmune: false,
                                                              isApplicable: { _ in true }, rng: &rng))
        for seed in UInt64(0)..<20 {
            var other = SeededRNG(seed: seed)
            var copy = state
            #expect(EventScheduler.takeDue(catalog: catalog, state: &copy, maxTier: 5, isImmune: false,
                                           isApplicable: { _ in true }, rng: &other)?.id == peeked.id)
            #expect(copy.upcomingId == nil)
        }
    }

    @Test("si lo adelantado dejó de ser elegible, se sortea otro")
    func upcomingDroppedWhenIneligible() throws {
        var state = EventsState(upcomingId: "bajon")
        var rng = SeededRNG(seed: 3)
        let event = try #require(EventScheduler.takeDue(catalog: catalog, state: &state, maxTier: 5, isImmune: true,
                                                        isApplicable: { _ in true }, rng: &rng))
        #expect(event.id != "bajon")
    }

    @Test("salir programa el próximo entre el intervalo y el intervalo más el jitter")
    func markFiredSchedulesTheNext() throws {
        var state = EventsState(clock: 1234)
        var rng = SeededRNG(seed: 9)
        let event = try #require(catalog.event(id: "boom"))
        EventScheduler.markFired(event, state: &state, catalog: catalog, rng: &rng)
        #expect(state.lastFiredAt["boom"] == 1234)
        let next = try #require(state.secondsUntilNext)
        #expect(next >= 900 && next < 1200)
    }

    @Test("un sorteo vacío reintenta pronto, sin gastar el intervalo")
    func retrySoon() {
        var state = EventsState(secondsUntilNext: -3)
        EventScheduler.retrySoon(state: &state, catalog: catalog)
        #expect(state.secondsUntilNext == 30)
    }

    @Test("al volver, un evento vencido espera la gracia; uno lejano no se toca")
    func resumeGrace() {
        var overdue = EventsState(secondsUntilNext: 0)
        EventScheduler.applyResumeGrace(state: &overdue, catalog: catalog)
        #expect(overdue.secondsUntilNext == 60)
        var far = EventsState(secondsUntilNext: 500)
        EventScheduler.applyResumeGrace(state: &far, catalog: catalog)
        #expect(far.secondsUntilNext == 500)
    }
}

@Suite("Eventos v2: qué hace cada uno")
struct EventPlannerTests {
    let catalog = fxEventCatalog()
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test("los modificadores llevan el origen del evento y vencen con él")
    func modifiersCarryTheSourceKey() throws {
        let event = try #require(catalog.event(id: "mezcla"))
        let application = EventPlanner.apply(event, state: fxState(), tiers: tiers, now: 100)
        #expect(application.modifiers.map(\.effect) == [.spawnCostMultiplier, .incomeMultiplier])
        #expect(application.modifiers.allSatisfy { $0.sourceKey == "event.mezcla" && $0.expiresAt == 160 })
        #expect(application.boardIntent == nil)
    }

    @Test("el regalo pide una llegada un tier abajo de la frontera, y paga sus segundos")
    func grantUnitAndCoins() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 4)
        let application = EventPlanner.apply(try #require(catalog.event(id: "regalo")), state: state, tiers: tiers, now: 0)
        #expect(application.boardIntent == .grantUnit(typeId: "c_prog") || application.boardIntent == .grantUnit(typeId: "c_law"))
        #expect(application.coinsSeconds == 300)
    }

    @Test("el tipo regalado respeta la carrera elegida")
    func grantedTypeRespectsTheCareer() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 4)
        state.run.chosenCareerPath = "law"
        #expect(EventPlanner.grantedUnitType(tiersBelowFrontier: 1, state: state, tiers: tiers)?.id == "c_law")
        #expect(EventPlanner.grantedUnitType(tiersBelowFrontier: 9, state: state, tiers: tiers)?.tier == 1)
    }

    @Test("la startup pide evolucionar y el cepo llama a su visitante")
    func intents() {
        let startup = fxEvent("startup", .positive, duration: 0, effects: [.evolveBestUnit])
        #expect(EventPlanner.apply(startup, state: fxState(), tiers: tiers, now: 0).boardIntent == .evolveBestUnit)
        let cepo = fxEvent("cepo", .negative, effects: [.modifier(effect: .spawnCostMultiplier, magnitude: 1.5), .callVisitor(script: "arbolito_blue")])
        #expect(EventPlanner.apply(cepo, state: fxState(), tiers: tiers, now: 0).calledScript == "arbolito_blue")
    }

    @Test("una salida saca todo el evento; la de la hiperinflación, sólo lo que dice")
    func escapes() throws {
        let mezcla = try #require(catalog.event(id: "mezcla"))
        let other = ActiveModifier(effect: .tapMultiplier, magnitude: 2, expiresAt: 999, sourceKey: "boost.cafe")
        let modifiers = EventPlanner.apply(mezcla, state: fxState(), tiers: tiers, now: 0).modifiers + [other]
        let partial = EventPlanner.escape(mezcla.escapes[0], of: mezcla, from: modifiers)
        #expect(partial.map(\.effect) == [.incomeMultiplier, .tapMultiplier])
        let full = EventPlanner.escape(EventCatalog.Escape(kind: .free, feeSeconds: nil, removes: nil), of: mezcla, from: modifiers)
        #expect(full == [other])
    }

    @Test("la obra social corta los negativos y deja mixtos y positivos")
    func cutNegatives() throws {
        let modifiers = ["boom", "bajon", "mezcla"].flatMap { id in
            EventPlanner.apply(catalog.event(id: id)!, state: fxState(), tiers: tiers, now: 0).modifiers
        }
        let kept = EventPlanner.cutNegatives(modifiers, catalog: catalog)
        #expect(Set(kept.map(\.sourceKey)) == ["event.boom", "event.mezcla"])
    }

    @Test("un chip por evento corriendo, con su vencimiento más lejano")
    func runningEvents() throws {
        let mezcla = try #require(catalog.event(id: "mezcla"))
        var modifiers = EventPlanner.apply(mezcla, state: fxState(), tiers: tiers, now: 0).modifiers
        modifiers.append(ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: 5, sourceKey: "event.boom"))
        let running = EventPlanner.running(modifiers, catalog: catalog, now: 10)
        #expect(running.map(\.id) == ["mezcla"], "el boom ya venció")
        #expect(running.first?.expiresAt == 60)
        #expect(running.first?.presenterId == "npc_ministro")
    }

    @Test("cada velita sube el apagón hasta ×1, y ahí no hay más")
    func candles() throws {
        let apagon = fxEvent("apagon", .negative, effects: [.modifier(effect: .incomeMultiplier, magnitude: 0.3)],
                             escapes: [.init(kind: .video, feeSeconds: nil, removes: nil)], scene: .blackout, candleStep: 0.07)
        var modifiers = EventPlanner.apply(apagon, state: fxState(), tiers: tiers, now: 0).modifiers
        var lit = 0
        while let next = EventPlanner.lightCandle(modifiers, event: apagon, now: 1) {
            modifiers = next
            lit += 1
        }
        #expect(lit == 10)
        #expect(modifiers.first?.magnitude == 1)
        #expect(EventPlanner.lightCandle(modifiers, event: apagon, now: 1) == nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "EventCatalogTests|EventSchedulerTests|EventPlannerTests"`
Expected: no compila (`EventCatalog` no existe).

- [ ] **Step 3: `EventCatalog.swift`**

```swift
import Foundation

/// `events.json` schema 2 (PLAN-v2 E4): cada evento tiene efectos compuestos, una
/// polaridad, quiénes lo presentan y por dónde se sale. Se llama así y no
/// `EventsConfig` para no chocar con el config de la v1 mientras conviven.
public struct EventCatalog: Codable, Sendable, Equatable {
    public enum Polarity: String, Codable, Sendable {
        case positive, negative, mixed
    }

    /// Lo que el evento le hace a la escena, además de sus números (E4b).
    public enum Scene: String, Codable, Sendable, CaseIterable {
        case blackout, champions, sale
    }

    public enum Effect: Sendable, Equatable {
        /// Dura lo que dura el evento.
        case modifier(effect: ActiveModifier.Effect, magnitude: Double)
        /// Segundos de producción real, al arrancar.
        case coinsSeconds(Double)
        /// La mejor unidad que puede crecer sola sube un tier (Startup).
        case evolveBestUnit
        /// Una unidad `tiersBelowFrontier` abajo de tu frontera (Blanqueo).
        case grantUnit(tiersBelowFrontier: Int)
        /// Un guion que entra por el evento (Cepo → el blue del Arbolito).
        case callVisitor(script: String)
    }

    public struct Escape: Codable, Sendable, Equatable {
        public enum Kind: String, Codable, Sendable {
            case video, fee, free
        }

        public let kind: Kind
        /// La cuota, en segundos de producción (`fee`).
        public let feeSeconds: Double?
        /// Qué efectos saca. `nil` = todos (la Hiperinflación saca sólo el ×2 de contratar).
        public let removes: [ActiveModifier.Effect]?

        public init(kind: Kind, feeSeconds: Double?, removes: [ActiveModifier.Effect]?) {
            self.kind = kind
            self.feeSeconds = feeSeconds
            self.removes = removes
        }
    }

    public struct Event: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let polarity: Polarity
        public let durationSeconds: Double
        public let weight: Int
        public let minTier: Int
        public let cooldownSeconds: Double
        public let titleKey: String
        public let phraseKey: String
        /// Quiénes lo pueden anunciar (ids de `visitors.json`). El primero es su cara en el chip.
        public let presenters: [String]
        public let effects: [Effect]
        public let escapes: [Escape]
        public let scene: Scene?
        /// Cuánto sube el multiplicador cada velita del Apagón (hasta ×1).
        public let candleStep: Double?

        public init(
            id: String, polarity: Polarity, durationSeconds: Double, weight: Int, minTier: Int,
            cooldownSeconds: Double, titleKey: String, phraseKey: String, presenters: [String],
            effects: [Effect], escapes: [Escape], scene: Scene?, candleStep: Double?
        ) {
            self.id = id
            self.polarity = polarity
            self.durationSeconds = durationSeconds
            self.weight = weight
            self.minTier = minTier
            self.cooldownSeconds = cooldownSeconds
            self.titleKey = titleKey
            self.phraseKey = phraseKey
            self.presenters = presenters
            self.effects = effects
            self.escapes = escapes
            self.scene = scene
            self.candleStep = candleStep
        }

        /// El origen de sus modificadores: así los encuentran el chip y las salidas.
        public var sourceKey: String { "event.\(id)" }

        public var modifierEffects: Set<ActiveModifier.Effect> {
            Set(effects.compactMap { effect in
                if case .modifier(let modifierEffect, _) = effect { return modifierEffect }
                return nil
            })
        }
    }

    public let schemaVersion: Int
    /// Segundos de juego antes del primero de una partida (o de un save anterior a E4).
    public let firstEventAfterSeconds: Double
    public let intervalSeconds: Double
    public let intervalJitterSeconds: Double
    /// Al volver a la app, un evento vencido espera esto (E1 T8).
    public let resumeGraceSeconds: Double
    /// Un sorteo sin candidatos reintenta a este plazo (E1 T11).
    public let retryWhenNoneApplicableSeconds: Double
    public let events: [Event]

    public init(
        schemaVersion: Int, firstEventAfterSeconds: Double, intervalSeconds: Double,
        intervalJitterSeconds: Double, resumeGraceSeconds: Double,
        retryWhenNoneApplicableSeconds: Double, events: [Event]
    ) {
        self.schemaVersion = schemaVersion
        self.firstEventAfterSeconds = firstEventAfterSeconds
        self.intervalSeconds = intervalSeconds
        self.intervalJitterSeconds = intervalJitterSeconds
        self.resumeGraceSeconds = resumeGraceSeconds
        self.retryWhenNoneApplicableSeconds = retryWhenNoneApplicableSeconds
        self.events = events
    }

    public func event(id: String) -> Event? {
        events.first { $0.id == id }
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedSchema(Int)
        case duplicateId(String)
        case invalid(id: String, reason: String)
    }

    /// Un evento mal declarado no rompe nada visible: no sale nunca, o sale sin
    /// salida, y nadie se entera hasta que un jugador lo reporta.
    public func validate(visitorIDs: Set<String>, scriptIDs: Set<String>) throws {
        guard schemaVersion == 2 else { throw ValidationError.unsupportedSchema(schemaVersion) }
        guard intervalSeconds > 0, intervalJitterSeconds >= 0, firstEventAfterSeconds >= 0,
              resumeGraceSeconds >= 0, retryWhenNoneApplicableSeconds > 0
        else { throw ValidationError.invalid(id: "catalog", reason: "los relojes tienen que ser positivos") }
        var seen: Set<String> = []
        for event in events {
            func fail(_ reason: String) -> ValidationError { .invalid(id: event.id, reason: reason) }
            guard seen.insert(event.id).inserted else { throw ValidationError.duplicateId(event.id) }
            guard event.weight > 0, event.minTier >= 1, event.cooldownSeconds >= 0 else { throw fail("peso, tier o cooldown") }
            guard !event.titleKey.isEmpty, !event.phraseKey.isEmpty else { throw fail("sin textos") }
            guard !event.presenters.isEmpty, event.presenters.allSatisfy(visitorIDs.contains) else {
                throw fail("presentador desconocido")
            }
            guard !event.effects.isEmpty else { throw fail("sin efectos") }
            if !event.modifierEffects.isEmpty, event.durationSeconds <= 0 { throw fail("un modificador necesita duración") }
            if event.polarity != .positive, !event.escapes.contains(where: { $0.kind == .video }) {
                throw fail("un negativo siempre tiene salida por video")
            }
            for escape in event.escapes {
                if escape.kind == .fee, (escape.feeSeconds ?? 0) <= 0 { throw fail("cuota sin monto") }
                if let removes = escape.removes, !Set(removes).isSubset(of: event.modifierEffects) {
                    throw fail("la salida saca un efecto que el evento no tiene")
                }
            }
            for case .callVisitor(let script) in event.effects where !scriptIDs.contains(script) {
                throw fail("llama a un guion que no existe: \(script)")
            }
            if event.scene == .blackout, (event.candleStep ?? 0) <= 0 { throw fail("el apagón necesita candleStep") }
        }
    }
}

extension EventCatalog.Effect: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, effect, magnitude, seconds, tiersBelowFrontier, script
    }

    private enum Kind: String, Codable {
        case modifier, coinsSeconds, evolveBestUnit, grantUnit, callVisitor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .modifier:
            self = .modifier(
                effect: try container.decode(ActiveModifier.Effect.self, forKey: .effect),
                magnitude: try container.decode(Double.self, forKey: .magnitude)
            )
        case .coinsSeconds: self = .coinsSeconds(try container.decode(Double.self, forKey: .seconds))
        case .evolveBestUnit: self = .evolveBestUnit
        case .grantUnit: self = .grantUnit(tiersBelowFrontier: try container.decode(Int.self, forKey: .tiersBelowFrontier))
        case .callVisitor: self = .callVisitor(script: try container.decode(String.self, forKey: .script))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .modifier(effect, magnitude):
            try container.encode(Kind.modifier, forKey: .kind)
            try container.encode(effect, forKey: .effect)
            try container.encode(magnitude, forKey: .magnitude)
        case .coinsSeconds(let seconds):
            try container.encode(Kind.coinsSeconds, forKey: .kind)
            try container.encode(seconds, forKey: .seconds)
        case .evolveBestUnit:
            try container.encode(Kind.evolveBestUnit, forKey: .kind)
        case .grantUnit(let below):
            try container.encode(Kind.grantUnit, forKey: .kind)
            try container.encode(below, forKey: .tiersBelowFrontier)
        case .callVisitor(let script):
            try container.encode(Kind.callVisitor, forKey: .kind)
            try container.encode(script, forKey: .script)
        }
    }
}
```

- [ ] **Step 4: `EventScheduler.swift`**

```swift
import Foundation

/// El sorteo de eventos v2 (PLAN-v2 E4), con reloj de JUEGO ACTIVO guardado en el
/// save. Puro: lo aplicable y la inmunidad llegan resueltos.
public enum EventScheduler {
    /// Avanza el reloj. Devuelve `true` si ya toca sortear. El delta trae el
    /// mismo tope que el tick: el salto de volver del background no es juego.
    @discardableResult
    public static func advance(_ state: inout EventsState, delta: TimeInterval, catalog: EventCatalog) -> Bool {
        let step = min(max(delta, 0), IncomeTicker.deltaClampThreshold)
        state.clock += step
        let remaining = (state.secondsUntilNext ?? catalog.firstEventAfterSeconds) - step
        state.secondsUntilNext = remaining
        return remaining <= 0
    }

    /// Los que pueden salir ahora: tier, cooldown en reloj de juego, inmunidad
    /// (saca los NEGATIVOS; un mixto también da) y aplicabilidad.
    public static func eligible(
        catalog: EventCatalog,
        state: EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool
    ) -> [EventCatalog.Event] {
        catalog.events.filter { event in
            maxTier >= event.minTier
                && state.clock - (state.lastFiredAt[event.id] ?? -.infinity) >= event.cooldownSeconds
                && !(isImmune && event.polarity == .negative)
                && isApplicable(event)
        }
    }

    public static func roll(
        catalog: EventCatalog,
        state: EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> EventCatalog.Event? {
        let pool = eligible(catalog: catalog, state: state, maxTier: maxTier, isImmune: isImmune, isApplicable: isApplicable)
        let total = pool.map(\.weight).reduce(0, +)
        guard total > 0 else { return nil }
        var pick = Int.random(in: 0..<total, using: &rng)
        for event in pool {
            pick -= event.weight
            if pick < 0 { return event }
        }
        return pool.last
    }

    /// Lo que viene: el ya sorteado si sigue elegible; si no, un sorteo que queda
    /// anotado. Es lo que adelanta la Vecina, y por eso es lo que sale.
    public static func peekUpcoming(
        catalog: EventCatalog,
        state: inout EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> EventCatalog.Event? {
        let pool = eligible(catalog: catalog, state: state, maxTier: maxTier, isImmune: isImmune, isApplicable: isApplicable)
        if let id = state.upcomingId, let upcoming = pool.first(where: { $0.id == id }) { return upcoming }
        let next = roll(catalog: catalog, state: state, maxTier: maxTier, isImmune: isImmune,
                        isApplicable: isApplicable, rng: &rng)
        state.upcomingId = next?.id
        return next
    }

    /// Al vencer: el adelantado si sigue elegible, o un sorteo. Limpia el adelantado.
    public static func takeDue(
        catalog: EventCatalog,
        state: inout EventsState,
        maxTier: Int,
        isImmune: Bool,
        isApplicable: (EventCatalog.Event) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> EventCatalog.Event? {
        let event = peekUpcoming(catalog: catalog, state: &state, maxTier: maxTier, isImmune: isImmune,
                                 isApplicable: isApplicable, rng: &rng)
        state.upcomingId = nil
        return event
    }

    /// Salió: arranca su cooldown y se programa el próximo.
    public static func markFired(
        _ event: EventCatalog.Event,
        state: inout EventsState,
        catalog: EventCatalog,
        rng: inout some RandomNumberGenerator
    ) {
        state.lastFiredAt[event.id] = state.clock
        let jitter = catalog.intervalJitterSeconds > 0
            ? Double.random(in: 0..<catalog.intervalJitterSeconds, using: &rng)
            : 0
        state.secondsUntilNext = catalog.intervalSeconds + jitter
    }

    /// Un sorteo vacío no gasta el intervalo: reintenta pronto (E1 T11).
    public static func retrySoon(state: inout EventsState, catalog: EventCatalog) {
        state.secondsUntilNext = catalog.retryWhenNoneApplicableSeconds
    }

    /// Al volver a la app, un evento vencido no dispara en la cara (E1 T8).
    public static func applyResumeGrace(state: inout EventsState, catalog: EventCatalog) {
        state.secondsUntilNext = max(state.secondsUntilNext ?? catalog.firstEventAfterSeconds, catalog.resumeGraceSeconds)
    }
}
```

- [ ] **Step 5: `EventPlanner.swift`**

```swift
import Foundation

/// Lo que el evento le pide al tablero. NO se aplica acá: la app lo planea por el
/// embudo `BoardChange` (E1) y la escena lo reproduce a la vista.
public enum EventBoardIntent: Sendable, Equatable {
    case evolveBestUnit
    case grantUnit(typeId: String)
}

public struct EventApplication: Sendable, Equatable {
    public let modifiers: [ActiveModifier]
    public let coinsSeconds: Double
    public let boardIntent: EventBoardIntent?
    public let calledScript: String?
    public let scene: EventCatalog.Scene?
}

/// Un evento con algo corriendo: lo que dibuja su chip.
public struct RunningEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let polarity: EventCatalog.Polarity
    public let expiresAt: TimeInterval
    public let presenterId: String
    public let scene: EventCatalog.Scene?
}

public enum EventPlanner {
    public static func apply(
        _ event: EventCatalog.Event,
        state: PlayerState,
        tiers: TierRepository,
        now: TimeInterval
    ) -> EventApplication {
        var modifiers: [ActiveModifier] = []
        var coinsSeconds = 0.0
        var intent: EventBoardIntent?
        var called: String?
        for effect in event.effects {
            switch effect {
            case let .modifier(modifierEffect, magnitude):
                modifiers.append(ActiveModifier(
                    effect: modifierEffect, magnitude: magnitude,
                    expiresAt: now + event.durationSeconds, sourceKey: event.sourceKey
                ))
            case .coinsSeconds(let seconds):
                coinsSeconds += seconds
            case .evolveBestUnit:
                intent = .evolveBestUnit
            case .grantUnit(let below):
                intent = grantedUnitType(tiersBelowFrontier: below, state: state, tiers: tiers).map { .grantUnit(typeId: $0.id) }
            case .callVisitor(let script):
                called = script
            }
        }
        return EventApplication(modifiers: modifiers, coinsSeconds: coinsSeconds, boardIntent: intent,
                                calledScript: called, scene: event.scene)
    }

    /// El que regala el Blanqueo: tantos tiers abajo de tu frontera, respetando la
    /// carrera elegida (la misma regla que la v1 y que E1 T11).
    public static func grantedUnitType(tiersBelowFrontier: Int, state: PlayerState, tiers: TierRepository) -> CharacterType? {
        let tier = max(1, state.run.maxTierReached - tiersBelowFrontier)
        return tiers.concreteTypes.first { candidate in
            candidate.tier == tier && (state.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        } ?? tiers.concreteTypes.first { $0.tier == tier }
    }

    /// Los modificadores que quedan después de salir por `escape`.
    public static func escape(
        _ escape: EventCatalog.Escape,
        of event: EventCatalog.Event,
        from modifiers: [ActiveModifier]
    ) -> [ActiveModifier] {
        modifiers.filter { modifier in
            guard modifier.sourceKey == event.sourceKey else { return true }
            guard let removes = escape.removes else { return false }
            return !removes.contains(modifier.effect)
        }
    }

    /// La Obra social corta los negativos en curso. Los mixtos se quedan: tienen
    /// su parte buena.
    public static func cutNegatives(_ modifiers: [ActiveModifier], catalog: EventCatalog) -> [ActiveModifier] {
        let negative = Set(catalog.events.filter { $0.polarity == .negative }.map(\.sourceKey))
        return modifiers.filter { !negative.contains($0.sourceKey) }
    }

    /// Uno por evento con algún modificador vivo, el que vence primero adelante.
    public static func running(_ modifiers: [ActiveModifier], catalog: EventCatalog, now: TimeInterval) -> [RunningEvent] {
        catalog.events.compactMap { event -> RunningEvent? in
            let live = modifiers.filter { $0.sourceKey == event.sourceKey && $0.isActive(at: now) }
            guard let expiresAt = live.map(\.expiresAt).max() else { return nil }
            return RunningEvent(id: event.id, polarity: event.polarity, expiresAt: expiresAt,
                                presenterId: event.presenters.first ?? "", scene: event.scene)
        }
        .sorted { $0.expiresAt < $1.expiresAt }
    }

    /// Una velita más en el Apagón: el multiplicador de ingresos del evento sube
    /// `candleStep`, hasta ×1. `nil` si no hay apagón vivo o ya no hay qué prender.
    public static func lightCandle(_ modifiers: [ActiveModifier], event: EventCatalog.Event, now: TimeInterval) -> [ActiveModifier]? {
        guard let step = event.candleStep,
              let index = modifiers.firstIndex(where: {
                  $0.sourceKey == event.sourceKey && $0.effect == .incomeMultiplier && $0.isActive(at: now)
              }),
              modifiers[index].magnitude < 1
        else { return nil }
        let old = modifiers[index]
        var result = modifiers
        result[index] = ActiveModifier(id: old.id, effect: old.effect, magnitude: min(1, old.magnitude + step),
                                       expiresAt: old.expiresAt, sourceKey: old.sourceKey)
        return result
    }
}
```

- [ ] **Step 6: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter "EventCatalogTests|EventSchedulerTests|EventPlannerTests"`
Expected: PASS — 4 + 12 + 8 tests. Después `swift test --package-path Packages/EconomyKit` → PASS.

⚠️ El test de velitas cuenta **10**: 0,3 + 10 × 0,07 = 1,0000000000000002 y el `min(1, …)` lo
clava en 1. Si da 11, es que el `min` se perdió.

- [ ] **Step 7: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Events/EventCatalog.swift \
  Packages/EconomyKit/Sources/EconomyKit/Events/EventScheduler.swift \
  Packages/EconomyKit/Sources/EconomyKit/Events/EventPlanner.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/EventsEngineTests.swift
git diff --cached --stat
git commit -m "feat(eventos): el motor de eventos v2 en EconomyKit — catálogo compuesto, sorteo en reloj de juego y salidas"
```

---

### Task 5: Los visitantes, puros — `visitors.json` como tipo y los dos carriles de juego activo

**Objetivo:** el config de los visitantes (quiénes son, con qué arte de respaldo, y sus guiones
con una mecánica cada uno: regalo, arresto, multa, cambio, compra, se lleva gente, reto,
vendedor, chisme) con su validador; y el scheduler de dos carriles —el principal (primera visita
a los 600 s de juego y después cada 240–360 s) y el del Vendedor Ambulante (cada ~180 s)— con
anti-repetición, topes diarios, especiales sólo si ya los conseguiste y nada que dé algo que la
app todavía no sabe entregar.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsConfig.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorScheduler.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/VisitorsEngineTests.swift` (suites `VisitorsConfigTests` y `VisitorSchedulerTests`)

**Interfaces:**
- Consumes: `RewardSpec` (T1), `VisitorsState` (T3), `IncomeTicker.deltaClampThreshold`.
- Produces: `public struct VisitorsConfig: Codable, Sendable, Equatable` con `schemaVersion`,
  `firstVisitAfterSeconds`, `intervalMinSeconds`, `intervalMaxSeconds`, `vendorIntervalSeconds`,
  `vendorJitterSeconds`, `retryWhenNoneSeconds`, `patienceSeconds`, `presenterTalkSeconds`,
  `antiRepeat`, `coinsSecondsScale`, `visitors: [Visitor]`, `scripts: [Script]`,
  `visitor(id:)`, `script(id:)`, `validate() throws`.
- Produces: `VisitorsConfig.Visitor` (`id`, `kind: Kind` = `npc | special`, `nameKey`,
  `fallbackSymbol`, `fallbackTint`), `Lane` (`main | vendor`), `UnitPick`
  (`lowestDuplicate | highestDuplicate`), `VendorCard` (`id`, `nameKey`, `iconKey`,
  `reward: RewardSpec`), `Script` (`id`, `visitor`, `lane`, `weight`, `minTier`, `dailyCap`,
  `eventOnly`, `mechanic`, `bubbleKey`, `askKey`), `Mechanic` (`gift(rewards:videoDoubles:)`,
  `arrest(pick:bailMultiplier:releaseMultiplier:)`, `fine(seconds:capFraction:stamp:)`,
  `exchange(costSeconds:oro:dailyOroCap:)`, `sale(pick:priceMultiplier:tiersBelowFrontier:)`,
  `take(pick:count:rewards:minValueMultiplier:)`, `challenge(taps:windowSeconds:rewards:videoDoubles:)`,
  `vendor(cards:)`, `gossip(rewards:)`; `var rewards: [RewardSpec]`).
- Produces: `public struct VisitContext: Sendable, Equatable` (`maxTier`, `ownedSpecials`,
  `grantable: Set<RewardSpec.Kind>`); `VisitorScheduler.advance(_:delta:config:rng:) -> Lane?`,
  `rollDay(_:today:)`, `isAvailable(_:config:state:context:isOfferable:) -> Bool`,
  `eligible(lane:config:state:context:isOfferable:)`, `pickNext(lane:config:state:context:isOfferable:rng:)`,
  `markVisited(_:state:config:rng:)`, `retrySoon(lane:state:config:)`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/VisitorsEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

func fxScript(
    _ id: String,
    visitor: String = "npc_turista",
    lane: VisitorsConfig.Lane = .main,
    weight: Int = 10,
    minTier: Int = 1,
    dailyCap: Int = 3,
    eventOnly: Bool = false,
    mechanic: VisitorsConfig.Mechanic
) -> VisitorsConfig.Script {
    VisitorsConfig.Script(id: id, visitor: visitor, lane: lane, weight: weight, minTier: minTier,
                          dailyCap: dailyCap, eventOnly: eventOnly, mechanic: mechanic)
}

/// Visitantes sintéticos: dos de la calle, un especial y el vendedor.
func fxVisitors(scripts: [VisitorsConfig.Script]? = nil, antiRepeat: Int = 1, coinsSecondsScale: Double = 1) -> VisitorsConfig {
    VisitorsConfig(
        schemaVersion: 1,
        firstVisitAfterSeconds: 600,
        intervalMinSeconds: 240,
        intervalMaxSeconds: 360,
        vendorIntervalSeconds: 180,
        vendorJitterSeconds: 30,
        retryWhenNoneSeconds: 30,
        patienceSeconds: 30,
        presenterTalkSeconds: 4,
        antiRepeat: antiRepeat,
        coinsSecondsScale: coinsSecondsScale,
        visitors: [
            .init(id: "npc_turista", kind: .npc, nameKey: "visitor.npc_turista.name", fallbackSymbol: "camera.fill", fallbackTint: "PaletteGreen"),
            .init(id: "npc_comisario", kind: .npc, nameKey: "visitor.npc_comisario.name", fallbackSymbol: "figure.stand", fallbackTint: "PaletteBlue"),
            .init(id: "npc_vendedor", kind: .npc, nameKey: "visitor.npc_vendedor.name", fallbackSymbol: "cart.fill", fallbackTint: "PaletteOrange"),
            .init(id: "sp_cryptobro", kind: .special, nameKey: "special.cryptobro.name", fallbackSymbol: "chart.line.uptrend.xyaxis", fallbackTint: "PaletteOrange"),
        ],
        scripts: scripts ?? [
            fxScript("propina", mechanic: .gift(rewards: [.coinsSeconds(900)], videoDoubles: true)),
            fxScript("subsidio", mechanic: .gift(rewards: [.coinsSeconds(1200)], videoDoubles: true)),
            fxScript("senal", visitor: "sp_cryptobro",
                     mechanic: .gift(rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 60)], videoDoubles: true)),
            fxScript("bolson", mechanic: .gift(rewards: [.package(1)], videoDoubles: true)),
            fxScript("arresto", visitor: "npc_comisario", minTier: 3,
                     mechanic: .arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 2)),
            fxScript("ofertas", visitor: "npc_vendedor", lane: .vendor, dailyCap: 20, mechanic: .vendor(cards: [
                .init(id: "mate", nameKey: "boost.mate.name", iconKey: "ui_boost_mate",
                      reward: .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90)),
            ])),
            fxScript("blue", visitor: "sp_cryptobro", eventOnly: true,
                     mechanic: .exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil)),
        ]
    )
}

private let everything = Set(RewardSpec.Kind.allCases)

@Suite("Visitantes: el config")
struct VisitorsConfigTests {
    @Test("se lee la forma del JSON del juego, una mecánica de cada una")
    func decodesEveryMechanic() throws {
        let json = """
        {"schemaVersion": 1, "firstVisitAfterSeconds": 600, "intervalMinSeconds": 240, "intervalMaxSeconds": 360,
         "vendorIntervalSeconds": 180, "vendorJitterSeconds": 30, "retryWhenNoneSeconds": 30, "patienceSeconds": 30,
         "presenterTalkSeconds": 4, "antiRepeat": 3, "coinsSecondsScale": 1,
         "visitors": [{"id": "npc_comisario", "kind": "npc", "nameKey": "visitor.npc_comisario.name",
                       "fallbackSymbol": "figure.stand", "fallbackTint": "PaletteBlue"}],
         "scripts": [
          {"id": "g", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "gift", "rewards": [{"kind": "coinsSeconds", "seconds": 900}], "videoDoubles": true}},
          {"id": "a", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "arrest", "pick": "lowestDuplicate", "bailMultiplier": 1, "releaseMultiplier": 2}},
          {"id": "f", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "fine", "seconds": 180, "capFraction": 0.08,
                        "stamp": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 1.25, "seconds": 180}}},
          {"id": "e", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1, "eventOnly": true,
           "mechanic": {"kind": "exchange", "costSeconds": 3600, "oro": 1}},
          {"id": "s", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "sale", "pick": "highestDuplicate", "priceMultiplier": 4, "tiersBelowFrontier": 2}},
          {"id": "t", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "take", "pick": "lowestDuplicate", "count": 3, "minValueMultiplier": 1.5,
                        "rewards": [{"kind": "package", "count": 1}, {"kind": "coinsSeconds", "seconds": 600}]}},
          {"id": "c", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "challenge", "taps": 40, "windowSeconds": 30,
                        "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 90}]}},
          {"id": "v", "visitor": "npc_comisario", "lane": "vendor", "weight": 1, "minTier": 1, "dailyCap": 9,
           "mechanic": {"kind": "vendor", "cards": [{"id": "mate", "nameKey": "boost.mate.name", "iconKey": "ui_boost_mate",
                        "reward": {"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 90}}]}},
          {"id": "o", "visitor": "npc_comisario", "weight": 1, "minTier": 1, "dailyCap": 1,
           "mechanic": {"kind": "gossip", "rewards": [{"kind": "coinsSeconds", "seconds": 300}]}}
         ]}
        """
        let config = try JSONDecoder().decode(VisitorsConfig.self, from: Data(json.utf8))
        try config.validate()
        #expect(config.script(id: "g")?.lane == .main, "sin carril, el principal")
        #expect(config.script(id: "g")?.eventOnly == false)
        #expect(config.script(id: "e")?.eventOnly == true)
        #expect(config.script(id: "e")?.mechanic == .exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil))
        #expect(config.script(id: "c")?.mechanic == .challenge(
            taps: 40, windowSeconds: 30,
            rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)], videoDoubles: false
        ))
        #expect(config.script(id: "t")?.mechanic.rewards == [.package(1), .coinsSeconds(600)])
        #expect(config.script(id: "a")?.mechanic.rewards.isEmpty == true)
        #expect(config.script(id: "o")?.bubbleKey == "visit.o.bubble")
        #expect(try JSONDecoder().decode(VisitorsConfig.self, from: JSONEncoder().encode(config)) == config)
    }

    private func reject(_ script: VisitorsConfig.Script) {
        #expect(throws: VisitorsConfig.ValidationError.self) { try fxVisitors(scripts: [script]).validate() }
    }

    @Test("el validador frena lo que el juego no puede cumplir")
    func validationRejectsBrokenScripts() {
        // El arresto siempre indemniza más de lo que cuesta reponer (PLAN-v2 E4).
        reject(fxScript("a", mechanic: .arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 1)))
        reject(fxScript("b", mechanic: .vendor(cards: [])))
        reject(fxScript("c", lane: .vendor, mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false)))
        reject(fxScript("d", visitor: "npc_nadie", mechanic: .gift(rewards: [.coinsSeconds(1)], videoDoubles: false)))
        reject(fxScript("e", mechanic: .take(pick: .lowestDuplicate, count: 1, rewards: [.coinsSeconds(1)], minValueMultiplier: 0.9)))
        reject(fxScript("f", mechanic: .sale(pick: .highestDuplicate, priceMultiplier: 1, tiersBelowFrontier: 2)))
        reject(fxScript("g", mechanic: .gift(rewards: [.coinsSeconds(0)], videoDoubles: false)))
        reject(fxScript("h", mechanic: .fine(seconds: 180, capFraction: 1.5,
                                             stamp: .modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180))))
        reject(fxScript("i", mechanic: .challenge(taps: 0, windowSeconds: 30, rewards: [.coinsSeconds(1)], videoDoubles: false)))
    }

    @Test("el id de un visitante es su id de arte: npc_ para los nuevos, sp_ para los especiales")
    func visitorIdsFollowTheArtConvention() {
        let config = VisitorsConfig(
            schemaVersion: 1, firstVisitAfterSeconds: 600, intervalMinSeconds: 240, intervalMaxSeconds: 360,
            vendorIntervalSeconds: 180, vendorJitterSeconds: 30, retryWhenNoneSeconds: 30, patienceSeconds: 30,
            presenterTalkSeconds: 4, antiRepeat: 1, coinsSecondsScale: 1,
            visitors: [.init(id: "comisario", kind: .npc, nameKey: "x", fallbackSymbol: "x", fallbackTint: "x")],
            scripts: []
        )
        #expect(throws: VisitorsConfig.ValidationError.self) { try config.validate() }
    }

    @Test("el fixture es válido")
    func fixtureIsValid() throws {
        try fxVisitors().validate()
    }
}

@Suite("Visitantes: los dos carriles")
struct VisitorSchedulerTests {
    let config = fxVisitors()
    let context = VisitContext(maxTier: 5, ownedSpecials: [], grantable: [.coinsSeconds, .oro, .modifier])

    private func play(_ state: inout VisitorsState, seconds: Int, rng: inout SeededRNG) -> VisitorsConfig.Lane? {
        var lane: VisitorsConfig.Lane?
        for _ in 0..<seconds {
            lane = VisitorScheduler.advance(&state, delta: 1, config: config, rng: &rng) ?? lane
        }
        return lane
    }

    @Test("la primera visita llega a los 600 s de juego, no antes")
    func firstVisit() {
        var state = VisitorsState.initial
        var rng = SeededRNG(seed: 1)
        #expect(play(&state, seconds: 599, rng: &rng) == nil)
        #expect(play(&state, seconds: 1, rng: &rng) == .main)
    }

    @Test("un salto grande del tick no cuenta")
    func clampedDelta() {
        var state = VisitorsState.initial
        var rng = SeededRNG(seed: 1)
        #expect(VisitorScheduler.advance(&state, delta: 3600, config: config, rng: &rng) == nil)
        #expect(state.secondsUntilVisit == 600 - IncomeTicker.deltaClampThreshold)
    }

    @Test("después de una visita, la próxima entre 240 y 360 s")
    func nextVisitInterval() throws {
        var rng = SeededRNG(seed: 4)
        for _ in 0..<50 {
            var state = VisitorsState(secondsUntilVisit: 0)
            VisitorScheduler.markVisited(try #require(config.script(id: "propina")), state: &state, config: config, rng: &rng)
            let next = try #require(state.secondsUntilVisit)
            #expect(next >= 240 && next <= 360)
        }
    }

    @Test("el vendedor tiene su carril: cada 180 s ± 30")
    func vendorLane() throws {
        var rng = SeededRNG(seed: 5)
        for _ in 0..<50 {
            var state = VisitorsState(secondsUntilVisit: 999, secondsUntilVendor: 0)
            VisitorScheduler.markVisited(try #require(config.script(id: "ofertas")), state: &state, config: config, rng: &rng)
            let next = try #require(state.secondsUntilVendor)
            #expect(next >= 150 && next <= 210)
            #expect(state.secondsUntilVisit == 999, "un carril no mueve al otro")
        }
    }

    @Test("si vencen los dos, primero el principal")
    func mainBeatsVendor() {
        var state = VisitorsState(secondsUntilVisit: 0.5, secondsUntilVendor: 0.5)
        var rng = SeededRNG(seed: 1)
        #expect(VisitorScheduler.advance(&state, delta: 1, config: config, rng: &rng) == .main)
    }

    @Test("elegibles: carril, tier, tope, especiales conseguidos y premios entregables")
    func eligibility() {
        let ids = VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: context) { _ in true }.map(\.id)
        #expect(Set(ids) == ["propina", "subsidio", "arresto"], "sin el especial, sin paquetes y sin lo que llama un evento")
        let withSpecial = VisitContext(maxTier: 2, ownedSpecials: ["sp_cryptobro"], grantable: context.grantable)
        #expect(Set(VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: withSpecial) { _ in true }.map(\.id))
                == ["propina", "subsidio", "senal"], "el arresto pide tier 3")
        let capped = VisitorsState(day: "d", visitsToday: ["propina": 3])
        #expect(!VisitorScheduler.eligible(lane: .main, config: config, state: capped, context: context) { _ in true }
            .map(\.id).contains("propina"))
        #expect(VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: context) { $0.id == "subsidio" }
            .map(\.id) == ["subsidio"], "lo que no tiene oferta posible no viene")
        #expect(VisitorScheduler.eligible(lane: .vendor, config: config, state: .initial, context: context) { _ in true }
            .map(\.id) == ["ofertas"])
    }

    @Test("anti-repetición: el último no vuelve si hay otro; si es el único, sí")
    func antiRepeat() throws {
        let recent = VisitorsState(recentScripts: ["propina"])
        let ids = VisitorScheduler.eligible(lane: .main, config: config, state: recent, context: context) { _ in true }.map(\.id)
        #expect(!ids.contains("propina"))
        let only = VisitorScheduler.eligible(lane: .main, config: config, state: recent, context: context) { $0.id == "propina" }
        #expect(only.map(\.id) == ["propina"])
    }

    @Test("lo que llama un evento no sale en el sorteo, pero sí cuando lo llaman")
    func eventOnlyScripts() throws {
        let blue = try #require(config.script(id: "blue"))
        #expect(!VisitorScheduler.isAvailable(blue, config: config, state: .initial, context: context) { _ in true },
                "el especial no está conseguido")
        let owned = VisitContext(maxTier: 5, ownedSpecials: ["sp_cryptobro"], grantable: context.grantable)
        #expect(VisitorScheduler.isAvailable(blue, config: config, state: .initial, context: owned) { _ in true })
        #expect(!VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: owned) { _ in true }
            .map(\.id).contains("blue"))
    }

    @Test("el sorteo sale de los elegibles y respeta los pesos")
    func pick() {
        var rng = SeededRNG(seed: 11)
        var seen: Set<String> = []
        for _ in 0..<200 {
            if let script = VisitorScheduler.pickNext(lane: .main, config: config, state: .initial, context: context,
                                                      isOfferable: { _ in true }, rng: &rng) {
                seen.insert(script.id)
            }
        }
        #expect(seen == ["propina", "subsidio", "arresto"])
    }

    @Test("visitar anota el guion, cuenta el día y recorta la memoria")
    func markVisitedBookkeeping() throws {
        var state = VisitorsState(day: "d")
        var rng = SeededRNG(seed: 2)
        let propina = try #require(config.script(id: "propina"))
        for _ in 0..<5 { VisitorScheduler.markVisited(propina, state: &state, config: config, rng: &rng) }
        #expect(state.visitsToday["propina"] == 5)
        #expect(state.recentScripts.count <= max(config.antiRepeat, 1) * 2)
        #expect(state.recentScripts.last == "propina")
    }

    @Test("el día nuevo resetea los topes; el mismo día no")
    func rollDay() {
        var state = VisitorsState(day: "2026-10-07", visitsToday: ["a": 2], oroExchangedToday: 3)
        VisitorScheduler.rollDay(&state, today: "2026-10-07")
        #expect(state.visitsToday == ["a": 2])
        VisitorScheduler.rollDay(&state, today: "2026-10-08")
        #expect(state.visitsToday.isEmpty)
        #expect(state.oroExchangedToday == 0)
        #expect(state.day == "2026-10-08")
    }

    @Test("un carril sin nadie para mandar reintenta pronto")
    func retrySoon() {
        var state = VisitorsState(secondsUntilVisit: -1, secondsUntilVendor: -1)
        VisitorScheduler.retrySoon(lane: .vendor, state: &state, config: config)
        #expect(state.secondsUntilVendor == 30)
        #expect(state.secondsUntilVisit == -1)
    }

    @Test("con todo entregable, todo guion del fixture sale por su carril")
    func everythingGrantable() {
        let all = VisitContext(maxTier: 9, ownedSpecials: ["sp_cryptobro"], grantable: everything)
        let main = VisitorScheduler.eligible(lane: .main, config: config, state: .initial, context: all) { _ in true }.map(\.id)
        #expect(Set(main) == ["propina", "subsidio", "senal", "bolson", "arresto"])
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "VisitorsConfigTests|VisitorSchedulerTests"`
Expected: no compila (`VisitorsConfig` no existe).

- [ ] **Step 3: `VisitorsConfig.swift`**

```swift
import Foundation

/// `visitors.json` (PLAN-v2 E4, Anexos A y B): quiénes visitan y qué guion trae
/// cada uno. El id de un visitante ES su id de arte (`npc_<nombre>` para los 8
/// nuevos, `sp_<id>` para los 10 especiales): con él se buscan las poses en el
/// manifest y el loop de retrato en `loops_manifest.json`.
public struct VisitorsConfig: Codable, Sendable, Equatable {
    public struct Visitor: Codable, Sendable, Equatable, Identifiable {
        public enum Kind: String, Codable, Sendable {
            case npc, special
        }

        public let id: String
        public let kind: Kind
        public let nameKey: String
        /// Mientras no hay arte: un SF Symbol sobre un disco de este color de la paleta.
        public let fallbackSymbol: String
        public let fallbackTint: String

        public init(id: String, kind: Kind, nameKey: String, fallbackSymbol: String, fallbackTint: String) {
            self.id = id
            self.kind = kind
            self.nameKey = nameKey
            self.fallbackSymbol = fallbackSymbol
            self.fallbackTint = fallbackTint
        }
    }

    public enum Lane: String, Codable, Sendable {
        case main, vendor
    }

    /// A quién elige un guion que se lleva, compra o arresta gente. Siempre un
    /// DUPLICADO: nunca el último de su tipo.
    public enum UnitPick: String, Codable, Sendable {
        case lowestDuplicate, highestDuplicate
    }

    public struct VendorCard: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let nameKey: String
        public let iconKey: String
        public let reward: RewardSpec

        public init(id: String, nameKey: String, iconKey: String, reward: RewardSpec) {
            self.id = id
            self.nameKey = nameKey
            self.iconKey = iconKey
            self.reward = reward
        }
    }

    public enum Mechanic: Sendable, Equatable {
        /// Da algo. Con `videoDoubles`, un video lo duplica (`RewardSpec.scaled`).
        case gift(rewards: [RewardSpec], videoDoubles: Bool)
        /// Se lleva un duplicado: pagás la fianza (× lo que cuesta reponerlo) o lo
        /// dejás ir y te indemnizan (× reponerlo, siempre > 1).
        case arrest(pick: UnitPick, bailMultiplier: Double, releaseMultiplier: Double)
        /// Multa de `seconds` de producción con tope en una fracción de la caja.
        /// Pagarla da `stamp`; un video la perdona; ignorarla no cobra nada.
        case fine(seconds: Double, capFraction: Double, stamp: RewardSpec)
        /// ORO por plata. `dailyOroCap` nil = sin tope (el blue del Cepo).
        case exchange(costSeconds: Double, oro: Int, dailyOroCap: Int?)
        /// Compra un duplicado hasta `tiersBelowFrontier` abajo de tu frontera.
        case sale(pick: UnitPick, priceMultiplier: Double, tiersBelowFrontier: Int)
        /// Se lleva `count` y deja `rewards`, con la plata llevada a por lo menos
        /// `minValueMultiplier` × lo que cuesta reponerlos.
        case take(pick: UnitPick, count: Int, rewards: [RewardSpec], minValueMultiplier: Double)
        /// `taps` toques en `windowSeconds`. Si no llegás, no pasa nada.
        case challenge(taps: Int, windowSeconds: Double, rewards: [RewardSpec], videoDoubles: Bool)
        /// Una carta por video (el Vendedor Ambulante).
        case vendor(cards: [VendorCard])
        /// Te adelanta el próximo evento y deja `rewards` (la Vecina).
        case gossip(rewards: [RewardSpec])

        /// Todo lo que el guion puede dar: si uno no se puede entregar todavía,
        /// el guion no se ofrece.
        public var rewards: [RewardSpec] {
            switch self {
            case .gift(let rewards, _), .take(_, _, let rewards, _), .challenge(_, _, let rewards, _), .gossip(let rewards):
                rewards
            case .fine(_, _, let stamp):
                [stamp]
            case .exchange(_, let oro, _):
                [.oro(oro)]
            case .vendor(let cards):
                cards.map(\.reward)
            case .arrest, .sale:
                []
            }
        }
    }

    public struct Script: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let visitor: String
        public let lane: Lane
        public let weight: Int
        public let minTier: Int
        public let dailyCap: Int
        /// Sólo entra si lo llama un evento (el blue del Arbolito, en el Cepo).
        public let eventOnly: Bool
        public let mechanic: Mechanic

        public init(
            id: String, visitor: String, lane: Lane, weight: Int, minTier: Int,
            dailyCap: Int, eventOnly: Bool, mechanic: Mechanic
        ) {
            self.id = id
            self.visitor = visitor
            self.lane = lane
            self.weight = weight
            self.minTier = minTier
            self.dailyCap = dailyCap
            self.eventOnly = eventOnly
            self.mechanic = mechanic
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            visitor = try container.decode(String.self, forKey: .visitor)
            lane = try container.decodeIfPresent(Lane.self, forKey: .lane) ?? .main
            weight = try container.decode(Int.self, forKey: .weight)
            minTier = try container.decode(Int.self, forKey: .minTier)
            dailyCap = try container.decode(Int.self, forKey: .dailyCap)
            eventOnly = try container.decodeIfPresent(Bool.self, forKey: .eventOnly) ?? false
            mechanic = try container.decode(Mechanic.self, forKey: .mechanic)
        }

        /// Las claves van por convención (Anexo A): una sola fuente para el globo y el popup.
        public var bubbleKey: String { "visit.\(id).bubble" }
        public var askKey: String { "visit.\(id).ask" }
    }

    public let schemaVersion: Int
    public let firstVisitAfterSeconds: Double
    public let intervalMinSeconds: Double
    public let intervalMaxSeconds: Double
    public let vendorIntervalSeconds: Double
    public let vendorJitterSeconds: Double
    public let retryWhenNoneSeconds: Double
    /// Lo que espera alguien en escena, contado sólo en un momento calmo.
    public let patienceSeconds: Double
    /// Lo que se queda el presentador de un evento hablando antes de irse.
    public let presenterTalkSeconds: Double
    /// Cuántos guiones recientes no vuelven si hay otro para mandar.
    public let antiRepeat: Int
    /// Escala de todos los `coinsSeconds` de los guiones: la palanca de E2b.
    public let coinsSecondsScale: Double
    public let visitors: [Visitor]
    public let scripts: [Script]

    public init(
        schemaVersion: Int, firstVisitAfterSeconds: Double, intervalMinSeconds: Double,
        intervalMaxSeconds: Double, vendorIntervalSeconds: Double, vendorJitterSeconds: Double,
        retryWhenNoneSeconds: Double, patienceSeconds: Double, presenterTalkSeconds: Double,
        antiRepeat: Int, coinsSecondsScale: Double, visitors: [Visitor], scripts: [Script]
    ) {
        self.schemaVersion = schemaVersion
        self.firstVisitAfterSeconds = firstVisitAfterSeconds
        self.intervalMinSeconds = intervalMinSeconds
        self.intervalMaxSeconds = intervalMaxSeconds
        self.vendorIntervalSeconds = vendorIntervalSeconds
        self.vendorJitterSeconds = vendorJitterSeconds
        self.retryWhenNoneSeconds = retryWhenNoneSeconds
        self.patienceSeconds = patienceSeconds
        self.presenterTalkSeconds = presenterTalkSeconds
        self.antiRepeat = antiRepeat
        self.coinsSecondsScale = coinsSecondsScale
        self.visitors = visitors
        self.scripts = scripts
    }

    public func visitor(id: String) -> Visitor? {
        visitors.first { $0.id == id }
    }

    public func script(id: String) -> Script? {
        scripts.first { $0.id == id }
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedSchema(Int)
        case duplicateId(String)
        case invalid(id: String, reason: String)
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ValidationError.unsupportedSchema(schemaVersion) }
        guard firstVisitAfterSeconds >= 0, intervalMinSeconds > 0, intervalMaxSeconds >= intervalMinSeconds,
              vendorJitterSeconds >= 0, vendorIntervalSeconds > vendorJitterSeconds, retryWhenNoneSeconds > 0,
              patienceSeconds > 0, presenterTalkSeconds > 0, antiRepeat >= 0, coinsSecondsScale > 0
        else { throw ValidationError.invalid(id: "config", reason: "relojes y escalas tienen que ser positivos") }

        var visitorIDs: Set<String> = []
        for visitor in visitors {
            guard visitorIDs.insert(visitor.id).inserted else { throw ValidationError.duplicateId(visitor.id) }
            let prefix = visitor.kind == .npc ? "npc_" : "sp_"
            guard visitor.id.hasPrefix(prefix) else {
                throw ValidationError.invalid(id: visitor.id, reason: "el id de arte es npc_<nombre> o sp_<id>")
            }
            guard !visitor.nameKey.isEmpty, !visitor.fallbackSymbol.isEmpty, !visitor.fallbackTint.isEmpty else {
                throw ValidationError.invalid(id: visitor.id, reason: "sin nombre o sin respaldo de arte")
            }
        }

        var scriptIDs: Set<String> = []
        for script in scripts {
            func fail(_ reason: String) -> ValidationError { .invalid(id: script.id, reason: reason) }
            guard scriptIDs.insert(script.id).inserted else { throw ValidationError.duplicateId(script.id) }
            guard visitorIDs.contains(script.visitor) else { throw fail("visitante desconocido") }
            guard script.weight > 0, script.minTier >= 1, script.dailyCap > 0 else { throw fail("peso, tier o tope") }
            let isVendor: Bool = if case .vendor = script.mechanic { true } else { false }
            guard isVendor == (script.lane == .vendor) else { throw fail("el vendedor, y sólo él, va por su carril") }
            for reward in script.mechanic.rewards {
                do { try reward.validate() } catch { throw fail("premio inválido: \(error)") }
            }
            switch script.mechanic {
            case .gift(let rewards, _), .gossip(let rewards):
                guard !rewards.isEmpty else { throw fail("sin premios") }
            case let .arrest(_, bail, release):
                guard bail > 0, release > 1 else { throw fail("el arresto indemniza más de lo que cuesta reponer") }
            case let .fine(seconds, capFraction, _):
                guard seconds > 0, capFraction > 0, capFraction <= 1 else { throw fail("multa") }
            case let .exchange(costSeconds, oro, dailyOroCap):
                guard costSeconds > 0, oro > 0, (dailyOroCap ?? 1) > 0 else { throw fail("cambio") }
            case let .sale(_, priceMultiplier, tiersBelowFrontier):
                guard priceMultiplier > 1, tiersBelowFrontier >= 0 else { throw fail("la compra paga más de lo que vale") }
            case let .take(_, count, rewards, minValueMultiplier):
                guard count >= 1, minValueMultiplier >= 1, !rewards.isEmpty else {
                    throw fail("se lleva gente y paga por lo menos lo que vale")
                }
            case let .challenge(taps, windowSeconds, rewards, _):
                guard taps > 0, windowSeconds > 0, !rewards.isEmpty else { throw fail("reto") }
            case .vendor(let cards):
                guard (1...3).contains(cards.count), Set(cards.map(\.id)).count == cards.count else {
                    throw fail("de una a tres cartas")
                }
            }
        }
    }
}

extension VisitorsConfig.Mechanic: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, rewards, videoDoubles, pick, bailMultiplier, releaseMultiplier, seconds, capFraction, stamp
        case costSeconds, oro, dailyOroCap, priceMultiplier, tiersBelowFrontier, count, minValueMultiplier
        case taps, windowSeconds, cards
    }

    private enum Kind: String, Codable {
        case gift, arrest, fine, exchange, sale, take, challenge, vendor, gossip
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .gift:
            self = .gift(rewards: try c.decode([RewardSpec].self, forKey: .rewards),
                         videoDoubles: try c.decodeIfPresent(Bool.self, forKey: .videoDoubles) ?? false)
        case .arrest:
            self = .arrest(pick: try c.decode(VisitorsConfig.UnitPick.self, forKey: .pick),
                           bailMultiplier: try c.decode(Double.self, forKey: .bailMultiplier),
                           releaseMultiplier: try c.decode(Double.self, forKey: .releaseMultiplier))
        case .fine:
            self = .fine(seconds: try c.decode(Double.self, forKey: .seconds),
                         capFraction: try c.decode(Double.self, forKey: .capFraction),
                         stamp: try c.decode(RewardSpec.self, forKey: .stamp))
        case .exchange:
            self = .exchange(costSeconds: try c.decode(Double.self, forKey: .costSeconds),
                             oro: try c.decode(Int.self, forKey: .oro),
                             dailyOroCap: try c.decodeIfPresent(Int.self, forKey: .dailyOroCap))
        case .sale:
            self = .sale(pick: try c.decode(VisitorsConfig.UnitPick.self, forKey: .pick),
                         priceMultiplier: try c.decode(Double.self, forKey: .priceMultiplier),
                         tiersBelowFrontier: try c.decode(Int.self, forKey: .tiersBelowFrontier))
        case .take:
            self = .take(pick: try c.decode(VisitorsConfig.UnitPick.self, forKey: .pick),
                         count: try c.decode(Int.self, forKey: .count),
                         rewards: try c.decode([RewardSpec].self, forKey: .rewards),
                         minValueMultiplier: try c.decode(Double.self, forKey: .minValueMultiplier))
        case .challenge:
            self = .challenge(taps: try c.decode(Int.self, forKey: .taps),
                              windowSeconds: try c.decode(Double.self, forKey: .windowSeconds),
                              rewards: try c.decode([RewardSpec].self, forKey: .rewards),
                              videoDoubles: try c.decodeIfPresent(Bool.self, forKey: .videoDoubles) ?? false)
        case .vendor:
            self = .vendor(cards: try c.decode([VisitorsConfig.VendorCard].self, forKey: .cards))
        case .gossip:
            self = .gossip(rewards: try c.decode([RewardSpec].self, forKey: .rewards))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .gift(rewards, videoDoubles):
            try c.encode(Kind.gift, forKey: .kind)
            try c.encode(rewards, forKey: .rewards)
            try c.encode(videoDoubles, forKey: .videoDoubles)
        case let .arrest(pick, bail, release):
            try c.encode(Kind.arrest, forKey: .kind)
            try c.encode(pick, forKey: .pick)
            try c.encode(bail, forKey: .bailMultiplier)
            try c.encode(release, forKey: .releaseMultiplier)
        case let .fine(seconds, capFraction, stamp):
            try c.encode(Kind.fine, forKey: .kind)
            try c.encode(seconds, forKey: .seconds)
            try c.encode(capFraction, forKey: .capFraction)
            try c.encode(stamp, forKey: .stamp)
        case let .exchange(costSeconds, oro, dailyOroCap):
            try c.encode(Kind.exchange, forKey: .kind)
            try c.encode(costSeconds, forKey: .costSeconds)
            try c.encode(oro, forKey: .oro)
            try c.encodeIfPresent(dailyOroCap, forKey: .dailyOroCap)
        case let .sale(pick, priceMultiplier, tiersBelowFrontier):
            try c.encode(Kind.sale, forKey: .kind)
            try c.encode(pick, forKey: .pick)
            try c.encode(priceMultiplier, forKey: .priceMultiplier)
            try c.encode(tiersBelowFrontier, forKey: .tiersBelowFrontier)
        case let .take(pick, count, rewards, minValueMultiplier):
            try c.encode(Kind.take, forKey: .kind)
            try c.encode(pick, forKey: .pick)
            try c.encode(count, forKey: .count)
            try c.encode(rewards, forKey: .rewards)
            try c.encode(minValueMultiplier, forKey: .minValueMultiplier)
        case let .challenge(taps, windowSeconds, rewards, videoDoubles):
            try c.encode(Kind.challenge, forKey: .kind)
            try c.encode(taps, forKey: .taps)
            try c.encode(windowSeconds, forKey: .windowSeconds)
            try c.encode(rewards, forKey: .rewards)
            try c.encode(videoDoubles, forKey: .videoDoubles)
        case .vendor(let cards):
            try c.encode(Kind.vendor, forKey: .kind)
            try c.encode(cards, forKey: .cards)
        case .gossip(let rewards):
            try c.encode(Kind.gossip, forKey: .kind)
            try c.encode(rewards, forKey: .rewards)
        }
    }
}
```

- [ ] **Step 4: `VisitorScheduler.swift`**

```swift
import Foundation

/// Lo que el scheduler necesita saber de la partida, ya resuelto por la app.
public struct VisitContext: Sendable, Equatable {
    public let maxTier: Int
    /// Un especial sólo visita si ya lo conseguiste: si no, el Álbum dejaría de
    /// tener sorpresas.
    public let ownedSpecials: Set<String>
    /// Lo que la app ya sabe entregar (`GameState.grantableRewardKinds`).
    public let grantable: Set<RewardSpec.Kind>

    public init(maxTier: Int, ownedSpecials: Set<String>, grantable: Set<RewardSpec.Kind>) {
        self.maxTier = maxTier
        self.ownedSpecials = ownedSpecials
        self.grantable = grantable
    }
}

/// Cuándo viene alguien y quién (PLAN-v2 E4): dos carriles de juego ACTIVO, el
/// principal y el del Vendedor Ambulante.
public enum VisitorScheduler {
    /// Avanza los dos relojes. Devuelve el carril que quedó listo (el principal
    /// primero). Un carril listo sigue listo hasta que alguien entra.
    public static func advance(
        _ state: inout VisitorsState,
        delta: TimeInterval,
        config: VisitorsConfig,
        rng: inout some RandomNumberGenerator
    ) -> VisitorsConfig.Lane? {
        let step = min(max(delta, 0), IncomeTicker.deltaClampThreshold)
        let visit = (state.secondsUntilVisit ?? config.firstVisitAfterSeconds) - step
        let vendor = (state.secondsUntilVendor ?? config.firstVisitAfterSeconds + vendorInterval(config, rng: &rng)) - step
        state.secondsUntilVisit = visit
        state.secondsUntilVendor = vendor
        if visit <= 0 { return .main }
        if vendor <= 0 { return .vendor }
        return nil
    }

    /// Un día calendario nuevo vacía los topes.
    public static func rollDay(_ state: inout VisitorsState, today: String) {
        guard state.day != today else { return }
        state.day = today
        state.visitsToday = [:]
        state.oroExchangedToday = 0
    }

    /// Puede venir ahora, sea por sorteo o porque lo llama un evento.
    public static func isAvailable(
        _ script: VisitorsConfig.Script,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool
    ) -> Bool {
        guard let visitor = config.visitor(id: script.visitor) else { return false }
        return context.maxTier >= script.minTier
            && (state.visitsToday[script.id] ?? 0) < script.dailyCap
            && (visitor.kind == .npc || context.ownedSpecials.contains(visitor.id))
            && script.mechanic.rewards.allSatisfy { context.grantable.contains($0.kind) }
            && isOfferable(script)
    }

    /// Los del sorteo de un carril. Los recientes no vuelven si hay otro: si son
    /// los únicos, vuelven igual (mejor repetir que dejar el carril vacío).
    public static func eligible(
        lane: VisitorsConfig.Lane,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool
    ) -> [VisitorsConfig.Script] {
        let candidates = config.scripts.filter { script in
            script.lane == lane && !script.eventOnly
                && isAvailable(script, config: config, state: state, context: context, isOfferable: isOfferable)
        }
        let recent = Set(state.recentScripts.suffix(config.antiRepeat))
        let fresh = candidates.filter { !recent.contains($0.id) }
        return fresh.isEmpty ? candidates : fresh
    }

    public static func pickNext(
        lane: VisitorsConfig.Lane,
        config: VisitorsConfig,
        state: VisitorsState,
        context: VisitContext,
        isOfferable: (VisitorsConfig.Script) -> Bool,
        rng: inout some RandomNumberGenerator
    ) -> VisitorsConfig.Script? {
        let pool = eligible(lane: lane, config: config, state: state, context: context, isOfferable: isOfferable)
        let total = pool.map(\.weight).reduce(0, +)
        guard total > 0 else { return nil }
        var pick = Int.random(in: 0..<total, using: &rng)
        for script in pool {
            pick -= script.weight
            if pick < 0 { return script }
        }
        return pool.last
    }

    /// Entró: memoria de repetidos, cuenta del día y el próximo de su carril.
    public static func markVisited(
        _ script: VisitorsConfig.Script,
        state: inout VisitorsState,
        config: VisitorsConfig,
        rng: inout some RandomNumberGenerator
    ) {
        state.recentScripts.append(script.id)
        let memory = max(config.antiRepeat, 1) * 2
        if state.recentScripts.count > memory {
            state.recentScripts.removeFirst(state.recentScripts.count - memory)
        }
        state.visitsToday[script.id, default: 0] += 1
        switch script.lane {
        case .main:
            state.secondsUntilVisit = Double.random(in: config.intervalMinSeconds...config.intervalMaxSeconds, using: &rng)
        case .vendor:
            state.secondsUntilVendor = vendorInterval(config, rng: &rng)
        }
    }

    /// Un carril listo sin nadie para mandar reintenta pronto, no espera otro intervalo entero.
    public static func retrySoon(lane: VisitorsConfig.Lane, state: inout VisitorsState, config: VisitorsConfig) {
        switch lane {
        case .main: state.secondsUntilVisit = config.retryWhenNoneSeconds
        case .vendor: state.secondsUntilVendor = config.retryWhenNoneSeconds
        }
    }

    static func vendorInterval(_ config: VisitorsConfig, rng: inout some RandomNumberGenerator) -> Double {
        config.vendorIntervalSeconds
            + Double.random(in: -config.vendorJitterSeconds...config.vendorJitterSeconds, using: &rng)
    }
}
```

- [ ] **Step 5: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter "VisitorsConfigTests|VisitorSchedulerTests"`
Expected: PASS — 4 + 13 tests. Después `swift test --package-path Packages/EconomyKit` → PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsConfig.swift \
  Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorScheduler.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/VisitorsEngineTests.swift
git diff --cached --stat
git commit -m "feat(visitantes): visitors.json como tipo y los dos carriles de juego activo"
```

---

### Task 6: `VisitPlanner` — la oferta cotizada al llegar y las tres invariantes

**Objetivo:** que cada guion se traduzca en 1–3 opciones concretas **cotizadas en el momento en
que el visitante llega** (así el globo, el popup y lo que se cobra dicen lo mismo), con las
salidas de unidades como `BoardChange.departure` de origen `.visitor` (el embudo de E1), y que al
aceptar se revalide contra el tablero de ahora. Tres invariantes pineadas por test (PLAN-v2 E4):
**nunca se lleva al último de su tipo ni deja la torre con menos de 2**; **el arresto siempre
indemniza más de lo que cuesta reponer**; **toda visita es de suma positiva o neutra** (ignorarla
no cuesta nada, y lo que se lleva gente paga por lo menos lo que vale reponerla).

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitPlanner.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (`Origin.visitor`; archivo de E1 T7)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (el `switch` de `discardBoardChange`, E1 T14)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/VisitPlannerTests.swift`

**Interfaces:**
- Consumes: `VisitorsConfig` (T5), `RewardSpec` (T1), `VisitorsState.oroExchangedToday` (T3),
  `BoardChange`, `BoardChange.replanned(_:)` (E1 T7), `TowerActions.hireQuote(typeId:…)`,
  `TowerActions.move(floorOrdinal:fromSlot:toSlot:tower:)`, `RunState.raiseFrontier(to:)` (E1 T3).
- Produces: `BoardChange.Origin.visitor`.
- Produces: `public struct VisitValuation: Sendable, Equatable` (`coinsPerSecond`,
  `hireCostMultiplier`); `ChallengeTerms` (`taps`, `windowSeconds`, `coins`, `rewards`,
  `videoDoubles`); `VisitOption` (`id`, `kind: Kind`, `coins`, `rewards`, `departures`,
  `requiresVideo`, `challenge`, `cost`) con `Kind: String, CaseIterable` = `accept`,
  `acceptWithVideo`, `payBail`, `release`, `payFine`, `forgiveWithVideo`, `sell`, `exchange`,
  `startChallenge`, `card`, `listen`; `VisitOffer` (`scriptId`, `visitorId`, `subjectTypeId`,
  `options`, `option(id:)`).
- Produces: `VisitPlanner.offer(_:config:state:tower:tiers:floorTable:economy:valuation:) -> VisitOffer?`,
  `VisitPlanner.revalidate(_:state:tower:) -> VisitOption?`, `VisitPlanner.minimumUnitsLeft` (2).
- Los ids de opción son fijos: `accept`, `video`, `bail`, `release`, `pay`, `sell`, `exchange`,
  `challenge`, `listen`, `card.<id>` (los usan los identificadores de E4b: `visit.option.<id>`).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/VisitPlannerTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Visitantes: la oferta, cotizada al llegar")
struct VisitPlannerTests {
    let tiers: TierRepository
    let economy = fxConfig()
    let valuation = VisitValuation(coinsPerSecond: 10)

    init() throws {
        tiers = try fxTiers()
    }

    /// Pisos de 10 lugares: con los de 5 del fixture, siete unidades en `f1` se
    /// auto-fusionarían al reconciliar y el test mediría otra torre.
    private func world(_ units: [String: Int], frontier: Int = 1, coins: Double = 1_000_000) throws
        -> (state: PlayerState, tower: TowerState, floorTable: FloorTable) {
        var fx = try fxStateAndTower(units: units, config: fxConfig(capacity: 10))
        fx.state.run.raiseFrontier(to: frontier)
        fx.state.run.coins = coins
        return fx
    }

    private func offer(
        _ mechanic: VisitorsConfig.Mechanic,
        in fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable),
        config: VisitorsConfig = fxVisitors()
    ) -> VisitOffer? {
        VisitPlanner.offer(fxScript("x", mechanic: mechanic), config: config, state: fx.state, tower: fx.tower,
                           tiers: tiers, floorTable: fx.floorTable, economy: economy, valuation: valuation)
    }

    private func replacement(_ typeId: String, in fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable)) throws -> Double {
        try #require(TowerActions.hireQuote(typeId: typeId, state: fx.state, config: economy,
                                            floorTable: fx.floorTable, tiers: tiers)).cost
    }

    private let arrest = VisitorsConfig.Mechanic.arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 2)

    @Test("un regalo cotiza sus segundos al llegar y el video duplica plata y duración")
    func giftIsPricedOnArrival() throws {
        let gift = VisitorsConfig.Mechanic.gift(
            rewards: [.coinsSeconds(900), .modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600)], videoDoubles: true
        )
        let offer = try #require(offer(gift, in: try world(["a": 1])))
        let accept = try #require(offer.option(id: "accept"))
        let video = try #require(offer.option(id: "video"))
        #expect(accept.coins == 9000)
        #expect(accept.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600)])
        #expect(!accept.requiresVideo)
        #expect(video.coins == 18000)
        #expect(video.requiresVideo)
        #expect(video.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 1200)])
    }

    @Test("la escala del config mueve toda la plata de los guiones (la palanca de E2b)")
    func coinsScale() throws {
        let gift = VisitorsConfig.Mechanic.gift(rewards: [.coinsSeconds(900)], videoDoubles: false)
        let offer = try #require(offer(gift, in: try world(["a": 1]), config: fxVisitors(coinsSecondsScale: 0.5)))
        #expect(offer.option(id: "accept")?.coins == 4500)
        #expect(offer.option(id: "video") == nil)
    }

    @Test("el arresto se lleva un duplicado del tier más bajo y siempre indemniza más de lo que cuesta reponerlo")
    func arrestAlwaysCompensates() throws {
        let fx = try world(["a": 3, "b": 2])
        let offer = try #require(offer(arrest, in: fx))
        let price = try replacement("a", in: fx)
        #expect(offer.subjectTypeId == "a")
        let bail = try #require(offer.option(id: "bail"))
        let release = try #require(offer.option(id: "release"))
        #expect(bail.coins == -price)
        #expect(bail.departures.isEmpty, "pagar la fianza no se lleva a nadie")
        #expect(release.coins > price)
        #expect(release.departures.count == 1)
        #expect(release.departures.first?.origin == .visitor)
        guard case .departure(_, _, let typeId)? = release.departures.first?.kind else {
            Issue.record("la salida no es una departure")
            return
        }
        #expect(typeId == "a")
    }

    @Test("nunca se lleva al último de su tipo ni deja la torre con menos de dos")
    func neverTakesTheLastOne() throws {
        #expect(offer(arrest, in: try world(["a": 1, "b": 1])) == nil, "sin duplicados no hay arresto")
        #expect(offer(arrest, in: try world(["a": 2])) == nil, "dejaría un solo empleado en la torre")
        let take = VisitorsConfig.Mechanic.take(pick: .lowestDuplicate, count: 3, rewards: [.coinsSeconds(600)], minValueMultiplier: 1.5)
        #expect(offer(take, in: try world(["a": 3, "b": 2])) == nil, "se llevaría a todos los de su tipo")
        let fine = try #require(offer(take, in: try world(["a": 4, "b": 1])))
        #expect(fine.option(id: "accept")?.departures.count == 3)
        #expect(Set(fine.option(id: "accept")?.departures.map(\.id) ?? []).count == 3)
    }

    @Test("lo que se lleva gente paga por lo menos lo que cuesta reponerla")
    func takingPaysAtLeastTheReplacement() throws {
        let fx = try world(["a": 5])
        let take = VisitorsConfig.Mechanic.take(pick: .lowestDuplicate, count: 3, rewards: [.coinsSeconds(1), .package(1)], minValueMultiplier: 1.5)
        let accept = try #require(offer(take, in: fx)?.option(id: "accept"))
        #expect(accept.coins >= 1.5 * 3 * (try replacement("a", in: fx)))
        #expect(accept.rewards == [.package(1)])
    }

    @Test("el turista compra el duplicado más alto que respeta su distancia a la frontera, a su múltiplo del precio")
    func saleRespectsTheFrontier() throws {
        let fx = try world(["a": 3, "b": 2, "d": 1], frontier: 4)
        let sale = VisitorsConfig.Mechanic.sale(pick: .highestDuplicate, priceMultiplier: 4, tiersBelowFrontier: 2)
        let offer = try #require(offer(sale, in: fx))
        #expect(offer.subjectTypeId == "b")
        #expect(offer.option(id: "sell")?.coins == 4 * (try replacement("b", in: fx)))
        #expect(self.offer(sale, in: try world(["a": 3, "b": 2], frontier: 3))?.subjectTypeId == "a")
        #expect(self.offer(sale, in: try world(["a": 3, "b": 2], frontier: 2)) == nil, "nada a dos tiers de la frontera")
    }

    @Test("la multa topea en su fracción de la caja; sin caja no hay multa; el video la perdona")
    func fineIsCapped() throws {
        let stamp = RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180)
        let fine = VisitorsConfig.Mechanic.fine(seconds: 180, capFraction: 0.08, stamp: stamp)
        let capped = try #require(offer(fine, in: try world(["a": 1], coins: 1000)))
        #expect(capped.option(id: "pay")?.coins == -80)
        #expect(capped.option(id: "pay")?.rewards == [stamp])
        #expect(capped.option(id: "video")?.coins == 0)
        #expect(capped.option(id: "video")?.requiresVideo == true)
        #expect(offer(fine, in: try world(["a": 1], coins: 0)) == nil)
    }

    @Test("el cambio cotiza su costo y respeta el tope del día")
    func exchangeCap() throws {
        var fx = try world(["a": 1])
        let exchange = VisitorsConfig.Mechanic.exchange(costSeconds: 5400, oro: 1, dailyOroCap: 3)
        let open = try #require(offer(exchange, in: fx)?.option(id: "exchange"))
        #expect(open.coins == -54000)
        #expect(open.rewards == [.oro(1)])
        fx.state.meta.engagement.visitors.oroExchangedToday = 3
        #expect(offer(exchange, in: fx) == nil)
        let blue = VisitorsConfig.Mechanic.exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil)
        #expect(offer(blue, in: fx) != nil, "el blue no tiene tope")
    }

    @Test("el reto, el vendedor y el chisme")
    func otherMechanics() throws {
        let fx = try world(["a": 1])
        let challenge = VisitorsConfig.Mechanic.challenge(
            taps: 40, windowSeconds: 30, rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)], videoDoubles: false
        )
        let terms = try #require(offer(challenge, in: fx)?.option(id: "challenge")?.challenge)
        #expect(terms.taps == 40 && terms.windowSeconds == 30)
        #expect(terms.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)])
        let card = VisitorsConfig.VendorCard(id: "mate", nameKey: "boost.mate.name", iconKey: "ui_boost_mate",
                                             reward: .modifier(effect: .spawnCostMultiplier, magnitude: 0.7, seconds: 90))
        let vendor = try #require(offer(.vendor(cards: [card]), in: fx))
        #expect(vendor.options.map(\.id) == ["card.mate"])
        #expect(vendor.options.allSatisfy(\.requiresVideo))
        #expect(offer(.gossip(rewards: [.coinsSeconds(300)]), in: fx)?.option(id: "listen")?.coins == 3000)
    }

    @Test("ignorar no cuesta nada: ninguna opción gratis resta, y lo que resta da algo a cambio")
    func everyVisitIsPositiveOrNeutral() throws {
        let fx = try world(["a": 5, "b": 2], frontier: 4)
        let stamp = RewardSpec.modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180)
        let mechanics: [VisitorsConfig.Mechanic] = [
            .gift(rewards: [.coinsSeconds(900)], videoDoubles: true),
            arrest,
            .fine(seconds: 180, capFraction: 0.08, stamp: stamp),
            .exchange(costSeconds: 5400, oro: 1, dailyOroCap: 3),
            .sale(pick: .highestDuplicate, priceMultiplier: 4, tiersBelowFrontier: 2),
            .take(pick: .lowestDuplicate, count: 3, rewards: [.coinsSeconds(600)], minValueMultiplier: 1.5),
            .gossip(rewards: [.coinsSeconds(300)]),
        ]
        for mechanic in mechanics {
            let offer = try #require(offer(mechanic, in: fx))
            for option in offer.options {
                if option.coins < 0 {
                    #expect(!option.rewards.isEmpty || option.kind == .payBail, "\(option.id): resta sin dar nada")
                }
                for change in option.departures {
                    guard case .departure(_, _, let typeId) = change.kind else { continue }
                    #expect(option.coins >= (try replacement(typeId, in: fx)) * Double(option.departures.count),
                            "\(option.id): se lleva gente sin pagarla")
                }
            }
        }
    }

    @Test("aceptar revalida: si el arrestado se movió se replanea; si ya no está, no hay trato")
    func revalidation() throws {
        var fx = try world(["a": 3, "b": 1])
        let release = try #require(offer(arrest, in: fx)?.option(id: "release"))
        guard case let .departure(ordinal, slot, _)? = release.departures.first?.kind else {
            Issue.record("sin salida")
            return
        }
        let free = try #require(fx.tower.floors[ordinal].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: ordinal, fromSlot: slot, toSlot: free, tower: &fx.tower))
        let moved = try #require(VisitPlanner.revalidate(release, state: fx.state, tower: fx.tower))
        #expect(moved.departures.first?.id == release.departures.first?.id, "mismo cambio, replaneado")
        #expect(moved != release)
        fx.state.run.units["a"] = 1
        #expect(VisitPlanner.revalidate(release, state: fx.state, tower: fx.tower) == nil)
    }

    @Test("sin plata no se paga la fianza; la salida gratis sigue en pie")
    func bailNeedsTheMoney() throws {
        let fx = try world(["a": 3, "b": 1])
        let offer = try #require(offer(arrest, in: fx))
        var broke = fx
        broke.state.run.coins = 0
        #expect(VisitPlanner.revalidate(try #require(offer.option(id: "bail")), state: broke.state, tower: broke.tower) == nil)
        #expect(VisitPlanner.revalidate(try #require(offer.option(id: "release")), state: broke.state, tower: broke.tower) != nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter VisitPlannerTests`
Expected: no compila (`VisitPlanner` no existe).

- [ ] **Step 3: El origen nuevo**

`BoardChange.swift`, en `enum Origin` (de E1 T7; "E4/E5 suman los suyos"):

```swift
        /// Un visitante se llevó a alguien (arresto, compra, novio, acto).
        case visitor
```

`GameState+BoardChanges.swift`, en el `switch change.origin` de `discardBoardChange(_:)` (E1 T14),
el caso nuevo va con los que no compensan:

```swift
        case .eventStartup, .eventBlanqueo, .career, .debug, .visitor: break
```

(una salida de visitante descartada —el empleado ya no estaba— no cobra nada: la plata se dio al
aceptar y el visitante se fue sin él; ver duda 6.)

- [ ] **Step 4: `VisitPlanner.swift`**

```swift
import Foundation

/// Cuánto vale un segundo de producción y cuánto cuesta reponer a alguien: lo
/// resuelve la app (`GameState.coinsPerProductionSecond`, el descuento de
/// prestigio) y el planificador sólo lo usa.
public struct VisitValuation: Sendable, Equatable {
    public let coinsPerSecond: Double
    public let hireCostMultiplier: Double

    public init(coinsPerSecond: Double, hireCostMultiplier: Double = 1) {
        self.coinsPerSecond = coinsPerSecond
        self.hireCostMultiplier = hireCostMultiplier
    }
}

/// Lo que promete un reto de toques, ya cotizado.
public struct ChallengeTerms: Sendable, Equatable {
    public let taps: Int
    public let windowSeconds: Double
    public let coins: Double
    public let rewards: [RewardSpec]
    public let videoDoubles: Bool

    public init(taps: Int, windowSeconds: Double, coins: Double, rewards: [RewardSpec], videoDoubles: Bool) {
        self.taps = taps
        self.windowSeconds = windowSeconds
        self.coins = coins
        self.rewards = rewards
        self.videoDoubles = videoDoubles
    }
}

/// Una opción del popup: lo que cobra o paga (`coins`, ya cotizado), lo que da
/// además, a quién se lleva y si pide un video.
public struct VisitOption: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case accept, acceptWithVideo, payBail, release, payFine, forgiveWithVideo
        case sell, exchange, startChallenge, card, listen
    }

    public let id: String
    public let kind: Kind
    /// Positivo: lo cobrás. Negativo: lo pagás (fianza, multa, cambio).
    public let coins: Double
    /// Lo que da que no es plata (la plata ya está en `coins`).
    public let rewards: [RewardSpec]
    public let departures: [BoardChange]
    public let requiresVideo: Bool
    public let challenge: ChallengeTerms?

    public init(
        id: String, kind: Kind, coins: Double, rewards: [RewardSpec], departures: [BoardChange],
        requiresVideo: Bool, challenge: ChallengeTerms?
    ) {
        self.id = id
        self.kind = kind
        self.coins = coins
        self.rewards = rewards
        self.departures = departures
        self.requiresVideo = requiresVideo
        self.challenge = challenge
    }

    public var cost: Double { max(0, -coins) }
}

public struct VisitOffer: Sendable, Equatable {
    public let scriptId: String
    public let visitorId: String
    /// A quién se lleva, compra o arresta (el globo lo nombra).
    public let subjectTypeId: String?
    public let options: [VisitOption]

    public init(scriptId: String, visitorId: String, subjectTypeId: String?, options: [VisitOption]) {
        self.scriptId = scriptId
        self.visitorId = visitorId
        self.subjectTypeId = subjectTypeId
        self.options = options
    }

    public func option(id: String) -> VisitOption? {
        options.first { $0.id == id }
    }
}

/// La oferta de un visitante (PLAN-v2 E4). Se concreta AL LLEGAR —así el globo y
/// el popup dicen lo mismo— y se revalida al aceptar.
public enum VisitPlanner {
    /// Ningún guion deja la torre con menos que esto.
    public static let minimumUnitsLeft = 2

    public static func offer(
        _ script: VisitorsConfig.Script,
        config: VisitorsConfig,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        economy: EconomyConfig,
        valuation: VisitValuation
    ) -> VisitOffer? {
        let coinsPerSecond = config.coinsSecondsScale * valuation.coinsPerSecond

        func priced(_ rewards: [RewardSpec]) -> (coins: Double, others: [RewardSpec]) {
            var coins = 0.0
            var others: [RewardSpec] = []
            for reward in rewards {
                if case .coinsSeconds(let seconds) = reward {
                    coins += seconds * coinsPerSecond
                } else {
                    others.append(reward)
                }
            }
            return (coins, others)
        }

        /// Lo que cuesta reponerlo, sin los modificadores del momento: un
        /// Liquidación no abarata una indemnización.
        func replacement(_ typeId: String) -> Double? {
            var bare = state
            bare.run.activeModifiers = []
            return TowerActions.hireQuote(typeId: typeId, state: bare, config: economy, floorTable: floorTable,
                                          tiers: tiers, costMultiplier: valuation.hireCostMultiplier)?.cost
        }

        func option(
            _ id: String, _ kind: VisitOption.Kind, coins: Double = 0, rewards: [RewardSpec] = [],
            departures: [BoardChange] = [], video: Bool = false, challenge: ChallengeTerms? = nil
        ) -> VisitOption {
            VisitOption(id: id, kind: kind, coins: coins, rewards: rewards, departures: departures,
                        requiresVideo: video, challenge: challenge)
        }

        func make(_ options: [VisitOption], subject: String? = nil) -> VisitOffer {
            VisitOffer(scriptId: script.id, visitorId: script.visitor, subjectTypeId: subject, options: options)
        }

        func pick(_ unitPick: VisitorsConfig.UnitPick, count: Int, maxTier: Int = .max) -> PickedUnits? {
            pickUnits(unitPick, count: count, maxTier: maxTier, state: state, tower: tower, tiers: tiers, floorTable: floorTable)
        }

        switch script.mechanic {
        case let .gift(rewards, videoDoubles):
            let base = priced(rewards)
            var options = [option("accept", .accept, coins: base.coins, rewards: base.others)]
            if videoDoubles {
                let doubled = priced(rewards.map { $0.scaled(by: 2) })
                options.append(option("video", .acceptWithVideo, coins: doubled.coins, rewards: doubled.others, video: true))
            }
            return make(options)

        case let .arrest(unitPick, bailMultiplier, releaseMultiplier):
            guard let unit = pick(unitPick, count: 1), let price = replacement(unit.typeId) else { return nil }
            return make([
                option("bail", .payBail, coins: -price * bailMultiplier),
                option("release", .release, coins: price * releaseMultiplier, departures: unit.departures),
            ], subject: unit.typeId)

        case let .fine(seconds, capFraction, stamp):
            let amount = min(seconds * coinsPerSecond, state.run.coins * capFraction)
            guard amount >= 1 else { return nil }
            return make([
                option("pay", .payFine, coins: -amount, rewards: [stamp]),
                option("video", .forgiveWithVideo, video: true),
            ])

        case let .exchange(costSeconds, oro, dailyOroCap):
            if let dailyOroCap, state.meta.engagement.visitors.oroExchangedToday + oro > dailyOroCap { return nil }
            return make([option("exchange", .exchange, coins: -costSeconds * coinsPerSecond, rewards: [.oro(oro)])])

        case let .sale(unitPick, priceMultiplier, tiersBelowFrontier):
            guard let unit = pick(unitPick, count: 1, maxTier: state.run.maxTierReached - tiersBelowFrontier),
                  let price = replacement(unit.typeId)
            else { return nil }
            return make([option("sell", .sell, coins: price * priceMultiplier, departures: unit.departures)], subject: unit.typeId)

        case let .take(unitPick, count, rewards, minValueMultiplier):
            guard let unit = pick(unitPick, count: count), let price = replacement(unit.typeId) else { return nil }
            let base = priced(rewards)
            let coins = max(base.coins, price * Double(count) * minValueMultiplier)
            return make([option("accept", .accept, coins: coins, rewards: base.others, departures: unit.departures)],
                        subject: unit.typeId)

        case let .challenge(taps, windowSeconds, rewards, videoDoubles):
            let base = priced(rewards)
            let terms = ChallengeTerms(taps: taps, windowSeconds: windowSeconds, coins: base.coins,
                                       rewards: base.others, videoDoubles: videoDoubles)
            return make([option("challenge", .startChallenge, challenge: terms)])

        case .vendor(let cards):
            return make(cards.map { option("card.\($0.id)", .card, rewards: [$0.reward], video: true) })

        case .gossip(let rewards):
            let base = priced(rewards)
            return make([option("listen", .listen, coins: base.coins, rewards: base.others)])
        }
    }

    /// La opción contra el tablero y la caja de AHORA: sigue valiendo, se
    /// replanea a quién se lleva (mismo tipo, mismo piso) o `nil` si ya no hay trato.
    public static func revalidate(_ option: VisitOption, state: PlayerState, tower: TowerState) -> VisitOption? {
        guard state.run.coins >= option.cost else { return nil }
        guard let first = option.departures.first else { return option }
        guard case let .departure(ordinal, _, typeId) = first.kind,
              state.run.totalUnits - option.departures.count >= minimumUnitsLeft,
              (state.run.units[typeId] ?? 0) - option.departures.count >= 1
        else { return nil }
        let stillThere = option.departures.allSatisfy { change in
            guard case let .departure(floor, slot, type) = change.kind else { return false }
            return tower.typeId(floorOrdinal: floor, slot: slot) == type
        }
        if stillThere { return option }
        let slots = tower.placements(onFloor: ordinal)
            .filter { $0.typeId == typeId }
            .map(\.slot)
            .sorted()
            .suffix(option.departures.count)
        guard slots.count == option.departures.count else { return nil }
        let departures = zip(option.departures, slots).map { change, slot in
            change.replanned(.departure(floorOrdinal: ordinal, slot: slot, typeId: typeId))
        }
        return VisitOption(id: option.id, kind: option.kind, coins: option.coins, rewards: option.rewards,
                           departures: departures, requiresVideo: option.requiresVideo, challenge: option.challenge)
    }

    struct PickedUnits {
        let typeId: String
        let departures: [BoardChange]
    }

    /// A quién se lleva: un tipo con por lo menos `count + 1` (nunca el último de
    /// su tipo), sin dejar la torre con menos de `minimumUnitsLeft`.
    static func pickUnits(
        _ unitPick: VisitorsConfig.UnitPick,
        count: Int,
        maxTier: Int,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> PickedUnits? {
        guard count >= 1, state.run.totalUnits - count >= minimumUnitsLeft else { return nil }
        let candidates = state.run.units
            .compactMap { id, amount -> CharacterType? in
                guard let type = tiers.type(id: id), !type.isChoiceNode, type.tier <= maxTier, amount - count >= 1 else {
                    return nil
                }
                return type
            }
            .sorted { $0.tier == $1.tier ? $0.id < $1.id : $0.tier < $1.tier }
        guard let type = unitPick == .highestDuplicate ? candidates.last : candidates.first else { return nil }
        let ordinal = floorTable.ordinal(forTier: type.tier)
        let slots = tower.placements(onFloor: ordinal).filter { $0.typeId == type.id }.map(\.slot).sorted().suffix(count)
        guard slots.count == count else { return nil }
        return PickedUnits(typeId: type.id, departures: slots.map { slot in
            BoardChange(kind: .departure(floorOrdinal: ordinal, slot: slot, typeId: type.id), origin: .visitor)
        })
    }
}
```

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter VisitPlannerTests` → PASS (12 tests);
`swift test --package-path Packages/EconomyKit` → PASS (incluida `BoardChangeTests` de E1, sin
cambios). Receta R con `-only-testing:FisuEvolutionTests/BoardChangeWiringTests` → PASS (el
`switch` de la app compila con el caso nuevo). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitPlanner.swift \
  Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/VisitPlannerTests.swift \
  FisuEvolution/Game/State/GameState+BoardChanges.swift
git diff --cached --stat
git commit -m "feat(visitantes): VisitPlanner — la oferta cotizada al llegar, con sus tres invariantes"
```

---

### Task 7: El contenido de los visitantes — `visitors.json`, sus textos y su validación al arrancar

**Objetivo:** los 18 visitantes (los 8 del Anexo B y los 10 especiales) y los 26 guiones del
Anexo A como dato, validados al arrancar; sus textos en es + en (nombres, globo y popup de cada
guion, los motivos absurdos del arresto por piso y las opciones genéricas); y `VisitCopy`, que
llena los textos con los números del dato. Las frases del Anexo que llevaban un número del dato
("30 % off", "cuarenta veces") lo interpolan.

**Files:**
- Create: `FisuEvolution/Resources/Config/visitors.json`
- Create: `FisuEvolution/Managers/VisitCopy.swift`
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`GameContent.visitors`, decode, validate, especiales cruzados)
- Modify: `FisuEvolutionTests/LocalizationCompletenessTests.swift` (familia `visitors`)
- Create: `FisuEvolutionTests/VisitorsContentTests.swift`
- Strings: `Tools/v2/claves-pendientes/e4a-t7.json` (81 claves)

**Interfaces:**
- Consumes: `VisitorsConfig` (T5), `VisitOffer`/`VisitOption` (T6), `EffectFormatter`,
  `EffectDescriptor.amount(forBoost:magnitude:)`, `CharacterType.localizedName`, las claves
  `ads.duration.min %@` / `ads.duration.sec %@` (existen).
- Produces: `GameContent.visitors: VisitorsConfig`.
- Produces: `enum VisitCopy` con `optionKey(_:)`, `reasonKey(floorID:)`, `name(of:)`,
  `bubble(for:offer:content:)`, `ask(for:offer:content:)`,
  `optionTitle(_:script:content:)`, `arguments(for:offer:content:) -> [String]`,
  `argumentCount(for:) -> Int`, `effectText(_:magnitude:)`, `durationText(_:)`,
  `text(_:_:bundle:)`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/VisitorsContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El elenco y los guiones de PLAN-v2 (Anexos A y B), tal como quedaron en el dato.
@Suite("Visitantes: el contenido real")
struct VisitorsContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("los 18: los 8 nuevos del Anexo B y los 10 especiales")
    func theCast() {
        let npcs = ["npc_comisario", "npc_sindicalista", "npc_turista", "npc_puntero",
                    "npc_ministro", "npc_vecina", "npc_vendedor", "npc_conductor"]
        let ids = Set(content.visitors.visitors.map(\.id))
        #expect(ids == Set(npcs).union(content.specials.specials.map(\.id)))
        #expect(content.visitors.visitors.filter { $0.kind == .special }.count == 10)
    }

    @Test("los 26 guiones del Anexo A, cada uno con su visitante")
    func theScripts() {
        let expected: [String: String] = [
            "comisario_arresto": "npc_comisario", "comisario_multa": "npc_comisario",
            "arca_paraiso": "sp_demonio_arca", "arca_factura": "sp_demonio_arca",
            "influencer_novio": "sp_influencer", "influencer_codigo": "sp_influencer",
            "sindicalista_aumento": "npc_sindicalista", "sindicalista_asado": "npc_sindicalista",
            "turista_compra": "npc_turista", "turista_propina": "npc_turista",
            "puntero_acto": "npc_puntero", "puntero_bolson": "npc_puntero",
            "ministro_subsidio": "npc_ministro",
            "vecina_chisme": "npc_vecina", "vecina_favor": "npc_vecina",
            "vendedor_ofertas": "npc_vendedor",
            "conductor_ruleta": "npc_conductor",
            "cryptobro_senal": "sp_cryptobro", "contador_credito": "sp_contador_dios",
            "zombie_reto": "sp_zombie_ceo", "lizard_lengua": "sp_lizard",
            "alien_inversion": "sp_alien_investor", "bug_reinicio": "sp_bug_simulacion",
            "arbolito_cambio": "sp_arbolito", "arbolito_blue": "sp_arbolito",
            "coach_reto": "sp_coach",
        ]
        #expect(Dictionary(uniqueKeysWithValues: content.visitors.scripts.map { ($0.id, $0.visitor) }) == expected)
    }

    @Test("los números del Anexo A")
    func annexValues() throws {
        func mechanic(_ id: String) throws -> VisitorsConfig.Mechanic {
            try #require(content.visitors.script(id: id)).mechanic
        }
        #expect(try mechanic("comisario_arresto") == .arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 2))
        #expect(try mechanic("arca_paraiso") == .arrest(pick: .highestDuplicate, bailMultiplier: 1, releaseMultiplier: 2))
        #expect(try mechanic("comisario_multa") == .fine(
            seconds: 180, capFraction: 0.08, stamp: .modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180)
        ))
        #expect(try mechanic("turista_propina") == .gift(rewards: [.coinsSeconds(900)], videoDoubles: true))
        #expect(try mechanic("turista_compra") == .sale(pick: .highestDuplicate, priceMultiplier: 4, tiersBelowFrontier: 2))
        #expect(try mechanic("puntero_acto") == .take(
            pick: .lowestDuplicate, count: 3, rewards: [.package(1), .coinsSeconds(600)], minValueMultiplier: 1.5
        ))
        #expect(try mechanic("arbolito_cambio") == .exchange(costSeconds: 5400, oro: 1, dailyOroCap: 3))
        #expect(try mechanic("arbolito_blue") == .exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil))
        #expect(content.visitors.script(id: "arbolito_blue")?.eventOnly == true)
        #expect(try mechanic("vecina_favor") == .challenge(taps: 15, windowSeconds: 20, rewards: [.package(1)], videoDoubles: true))
        #expect(try mechanic("zombie_reto") == .challenge(
            taps: 40, windowSeconds: 30, rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)], videoDoubles: false
        ))
        #expect(try mechanic("coach_reto") == .challenge(
            taps: 67, windowSeconds: 30, rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 120)], videoDoubles: false
        ))
        guard case .vendor(let cards) = try mechanic("vendedor_ofertas") else {
            Issue.record("el Vendedor no vende")
            return
        }
        #expect(cards.map(\.id) == ["mate", "cafe", "turbo"])
        #expect(content.visitors.script(id: "vendedor_ofertas")?.lane == .vendor)
    }

    @Test("los relojes de PLAN-v2: primera a los 600 s, después cada 240–360, el vendedor cada ~180, paciencia de 30")
    func theClocks() {
        let visitors = content.visitors
        #expect(visitors.firstVisitAfterSeconds == 600)
        #expect(visitors.intervalMinSeconds == 240 && visitors.intervalMaxSeconds == 360)
        #expect(visitors.vendorIntervalSeconds == 180)
        #expect(visitors.patienceSeconds == 30)
        #expect(visitors.coinsSecondsScale == 1, "E2b es quien la mueve, con el simulador")
    }

    @Test("todo texto recibe los datos que pide", arguments: ["es", "en"])
    func everyTextGetsItsArguments(language: String) throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        for script in content.visitors.scripts {
            let available = VisitCopy.argumentCount(for: script)
            for key in [script.bubbleKey, script.askKey] {
                let value = try #require(catalog.strings[key]?.localizations?[language]?.units.first?.value, "falta \(key) en \(language)")
                let wanted = Self.highestPlaceholder(in: value)
                #expect(wanted <= available, "\(key) [\(language)] pide %\(wanted)$@ y el guion da \(available)")
            }
        }
    }

    @Test("el globo del arresto nombra al empleado y un motivo de su piso")
    func arrestBubbleNamesTheWorker() throws {
        let script = try #require(content.visitors.script(id: "comisario_arresto"))
        let cartonero = try #require(content.tiers.type(id: "cartonero"))
        let offer = VisitOffer(scriptId: script.id, visitorId: script.visitor, subjectTypeId: cartonero.id, options: [])
        let bubble = VisitCopy.bubble(for: script, offer: offer, content: content)
        #expect(bubble.contains(cartonero.localizedName))
        #expect(bubble.contains(VisitCopy.text(VisitCopy.reasonKey(floorID: "alley"))))
        #expect(!bubble.contains("%"))
    }

    @Test("los textos interpolan el dato, no lo escriben")
    func textsInterpolateData() throws {
        let codigo = try #require(content.visitors.script(id: "influencer_codigo"))
        let offer = VisitOffer(scriptId: codigo.id, visitorId: codigo.visitor, subjectTypeId: nil, options: [])
        #expect(VisitCopy.bubble(for: codigo, offer: offer, content: content).contains(VisitCopy.effectText(.spawnCostMultiplier, magnitude: 0.7)))
        let coach = try #require(content.visitors.script(id: "coach_reto"))
        #expect(VisitCopy.ask(for: coach, offer: VisitOffer(scriptId: coach.id, visitorId: coach.visitor, subjectTypeId: nil, options: []),
                              content: content).contains("60"))
        #expect(VisitCopy.durationText(90) == String(localized: "ads.duration.sec \(String(90))"))
        #expect(VisitCopy.durationText(600) == String(localized: "ads.duration.min \(String(10))"))
    }

    /// El `%N$@` más alto de un texto; un `%@` suelto cuenta como el primero.
    static func highestPlaceholder(in text: String) -> Int {
        let positional = text.matches(of: /%(\d+)\$@/).compactMap { Int($0.1) }.max() ?? 0
        return max(positional, text.contains("%@") ? 1 : 0)
    }
}
```

En `LocalizationCompletenessTests.swift`, en `DynamicFamily` (con su docstring como los demás):

```swift
        /// Los visitantes (E4): el nombre de cada uno, el globo y el popup de cada
        /// guion, los motivos del arresto por piso y las opciones de los popups.
        case visitors
```

y en `keys(in:)`:

```swift
            case .visitors:
                return content.visitors.visitors.map(\.nameKey)
                    + content.visitors.scripts.flatMap { [$0.bubbleKey, $0.askKey] }
                    + content.floorTable.floors.map { VisitCopy.reasonKey(floorID: $0.id) }
                    + VisitOption.Kind.allCases.map(VisitCopy.optionKey)
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/VisitorsContentTests`.
Expected: no compila (`GameContent.visitors` no existe).

- [ ] **Step 3: `visitors.json`**

`FisuEvolution/Resources/Config/visitors.json` (los pesos, tiers y topes son la primera mano; E2b
los calibra con el simulador):

```json
{
  "schemaVersion": 1,
  "firstVisitAfterSeconds": 600,
  "intervalMinSeconds": 240,
  "intervalMaxSeconds": 360,
  "vendorIntervalSeconds": 180,
  "vendorJitterSeconds": 30,
  "retryWhenNoneSeconds": 30,
  "patienceSeconds": 30,
  "presenterTalkSeconds": 4,
  "antiRepeat": 3,
  "coinsSecondsScale": 1,
  "visitors": [
    {"id": "npc_comisario", "kind": "npc", "nameKey": "visitor.npc_comisario.name", "fallbackSymbol": "figure.stand", "fallbackTint": "PaletteBlue"},
    {"id": "npc_sindicalista", "kind": "npc", "nameKey": "visitor.npc_sindicalista.name", "fallbackSymbol": "megaphone.fill", "fallbackTint": "PalettePink"},
    {"id": "npc_turista", "kind": "npc", "nameKey": "visitor.npc_turista.name", "fallbackSymbol": "camera.fill", "fallbackTint": "PaletteGreen"},
    {"id": "npc_puntero", "kind": "npc", "nameKey": "visitor.npc_puntero.name", "fallbackSymbol": "bag.fill", "fallbackTint": "PaletteOrange"},
    {"id": "npc_ministro", "kind": "npc", "nameKey": "visitor.npc_ministro.name", "fallbackSymbol": "chart.line.downtrend.xyaxis", "fallbackTint": "PaletteBrown"},
    {"id": "npc_vecina", "kind": "npc", "nameKey": "visitor.npc_vecina.name", "fallbackSymbol": "eye.fill", "fallbackTint": "PalettePink"},
    {"id": "npc_vendedor", "kind": "npc", "nameKey": "visitor.npc_vendedor.name", "fallbackSymbol": "cart.fill", "fallbackTint": "PaletteOrange"},
    {"id": "npc_conductor", "kind": "npc", "nameKey": "visitor.npc_conductor.name", "fallbackSymbol": "mic.fill", "fallbackTint": "PaletteYellow"},
    {"id": "sp_cryptobro", "kind": "special", "nameKey": "special.cryptobro.name", "fallbackSymbol": "chart.line.uptrend.xyaxis", "fallbackTint": "PaletteOrange"},
    {"id": "sp_demonio_arca", "kind": "special", "nameKey": "special.demonio_arca.name", "fallbackSymbol": "doc.text.fill", "fallbackTint": "PaletteInk"},
    {"id": "sp_contador_dios", "kind": "special", "nameKey": "special.contador_dios.name", "fallbackSymbol": "book.closed.fill", "fallbackTint": "PaletteYellow"},
    {"id": "sp_zombie_ceo", "kind": "special", "nameKey": "special.zombie_ceo.name", "fallbackSymbol": "cup.and.saucer.fill", "fallbackTint": "PaletteGreen"},
    {"id": "sp_lizard", "kind": "special", "nameKey": "special.lizard.name", "fallbackSymbol": "eyes", "fallbackTint": "PaletteGreen"},
    {"id": "sp_alien_investor", "kind": "special", "nameKey": "special.alien_investor.name", "fallbackSymbol": "sparkles", "fallbackTint": "PaletteBlue"},
    {"id": "sp_bug_simulacion", "kind": "special", "nameKey": "special.bug_simulacion.name", "fallbackSymbol": "exclamationmark.triangle.fill", "fallbackTint": "PaletteBlue"},
    {"id": "sp_arbolito", "kind": "special", "nameKey": "special.arbolito.name", "fallbackSymbol": "banknote.fill", "fallbackTint": "PaletteGreen"},
    {"id": "sp_coach", "kind": "special", "nameKey": "special.coach.name", "fallbackSymbol": "figure.mind.and.body", "fallbackTint": "PaletteBrown"},
    {"id": "sp_influencer", "kind": "special", "nameKey": "special.influencer.name", "fallbackSymbol": "iphone", "fallbackTint": "PalettePink"}
  ],
  "scripts": [
    {"id": "comisario_arresto", "visitor": "npc_comisario", "weight": 8, "minTier": 3, "dailyCap": 2,
     "mechanic": {"kind": "arrest", "pick": "lowestDuplicate", "bailMultiplier": 1, "releaseMultiplier": 2}},
    {"id": "comisario_multa", "visitor": "npc_comisario", "weight": 6, "minTier": 2, "dailyCap": 2,
     "mechanic": {"kind": "fine", "seconds": 180, "capFraction": 0.08,
                  "stamp": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 1.25, "seconds": 180}}},
    {"id": "arca_paraiso", "visitor": "sp_demonio_arca", "weight": 5, "minTier": 9, "dailyCap": 1,
     "mechanic": {"kind": "arrest", "pick": "highestDuplicate", "bailMultiplier": 1, "releaseMultiplier": 2}},
    {"id": "arca_factura", "visitor": "sp_demonio_arca", "weight": 8, "minTier": 8, "dailyCap": 2,
     "mechanic": {"kind": "gift", "rewards": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 90}]}},
    {"id": "influencer_novio", "visitor": "sp_influencer", "weight": 6, "minTier": 4, "dailyCap": 1,
     "mechanic": {"kind": "take", "pick": "lowestDuplicate", "count": 1, "minValueMultiplier": 1.5,
                  "rewards": [{"kind": "coinsSeconds", "seconds": 600}, {"kind": "package", "count": 1}]}},
    {"id": "influencer_codigo", "visitor": "sp_influencer", "weight": 8, "minTier": 3, "dailyCap": 2,
     "mechanic": {"kind": "gift", "videoDoubles": true,
                  "rewards": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 60}]}},
    {"id": "sindicalista_aumento", "visitor": "npc_sindicalista", "weight": 8, "minTier": 2, "dailyCap": 2,
     "mechanic": {"kind": "gift", "videoDoubles": true,
                  "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 1.5, "seconds": 600}]}},
    {"id": "sindicalista_asado", "visitor": "npc_sindicalista", "weight": 6, "minTier": 3, "dailyCap": 1,
     "mechanic": {"kind": "gift", "videoDoubles": true,
                  "rewards": [{"kind": "package", "count": 1}, {"kind": "coinsSeconds", "seconds": 900}]}},
    {"id": "turista_compra", "visitor": "npc_turista", "weight": 6, "minTier": 6, "dailyCap": 1,
     "mechanic": {"kind": "sale", "pick": "highestDuplicate", "priceMultiplier": 4, "tiersBelowFrontier": 2}},
    {"id": "turista_propina", "visitor": "npc_turista", "weight": 10, "minTier": 1, "dailyCap": 3,
     "mechanic": {"kind": "gift", "videoDoubles": true, "rewards": [{"kind": "coinsSeconds", "seconds": 900}]}},
    {"id": "puntero_acto", "visitor": "npc_puntero", "weight": 5, "minTier": 3, "dailyCap": 1,
     "mechanic": {"kind": "take", "pick": "lowestDuplicate", "count": 3, "minValueMultiplier": 1.5,
                  "rewards": [{"kind": "package", "count": 1}, {"kind": "coinsSeconds", "seconds": 600}]}},
    {"id": "puntero_bolson", "visitor": "npc_puntero", "weight": 8, "minTier": 2, "dailyCap": 2,
     "mechanic": {"kind": "gift", "videoDoubles": true, "rewards": [{"kind": "package", "count": 1}]}},
    {"id": "ministro_subsidio", "visitor": "npc_ministro", "weight": 8, "minTier": 2, "dailyCap": 2,
     "mechanic": {"kind": "gift", "videoDoubles": true, "rewards": [{"kind": "coinsSeconds", "seconds": 1200}]}},
    {"id": "vecina_chisme", "visitor": "npc_vecina", "weight": 8, "minTier": 2, "dailyCap": 2,
     "mechanic": {"kind": "gossip", "rewards": [{"kind": "coinsSeconds", "seconds": 300}]}},
    {"id": "vecina_favor", "visitor": "npc_vecina", "weight": 6, "minTier": 2, "dailyCap": 2,
     "mechanic": {"kind": "challenge", "taps": 15, "windowSeconds": 20, "videoDoubles": true,
                  "rewards": [{"kind": "package", "count": 1}]}},
    {"id": "vendedor_ofertas", "visitor": "npc_vendedor", "lane": "vendor", "weight": 10, "minTier": 1, "dailyCap": 20,
     "mechanic": {"kind": "vendor", "cards": [
       {"id": "mate", "nameKey": "boost.mate.name", "iconKey": "ui_boost_mate",
        "reward": {"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.7, "seconds": 90}},
       {"id": "cafe", "nameKey": "boost.cafe.name", "iconKey": "ui_boost_cafe",
        "reward": {"kind": "modifier", "effect": "tapMultiplier", "magnitude": 2, "seconds": 60}},
       {"id": "turbo", "nameKey": "boost.turbo.name", "iconKey": "ui_boost_turbo",
        "reward": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 3, "seconds": 60}}
     ]}},
    {"id": "conductor_ruleta", "visitor": "npc_conductor", "weight": 6, "minTier": 2, "dailyCap": 1,
     "mechanic": {"kind": "gift", "rewards": [{"kind": "wheelSpin", "count": 1}]}},
    {"id": "cryptobro_senal", "visitor": "sp_cryptobro", "weight": 8, "minTier": 5, "dailyCap": 2,
     "mechanic": {"kind": "gift", "videoDoubles": true,
                  "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 60}]}},
    {"id": "contador_credito", "visitor": "sp_contador_dios", "weight": 5, "minTier": 9, "dailyCap": 1,
     "mechanic": {"kind": "gift", "rewards": [{"kind": "coinsSeconds", "seconds": 2400}]}},
    {"id": "zombie_reto", "visitor": "sp_zombie_ceo", "weight": 6, "minTier": 15, "dailyCap": 2,
     "mechanic": {"kind": "challenge", "taps": 40, "windowSeconds": 30,
                  "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 90}]}},
    {"id": "lizard_lengua", "visitor": "sp_lizard", "weight": 8, "minTier": 17, "dailyCap": 2,
     "mechanic": {"kind": "gift", "rewards": [{"kind": "modifier", "effect": "tapMultiplier", "magnitude": 3, "seconds": 45}]}},
    {"id": "alien_inversion", "visitor": "sp_alien_investor", "weight": 6, "minTier": 22, "dailyCap": 2,
     "mechanic": {"kind": "gift", "videoDoubles": true, "rewards": [{"kind": "coinsSeconds", "seconds": 1500}]}},
    {"id": "bug_reinicio", "visitor": "sp_bug_simulacion", "weight": 5, "minTier": 21, "dailyCap": 1,
     "mechanic": {"kind": "gift", "rewards": [{"kind": "clearBoostCooldowns"}]}},
    {"id": "arbolito_cambio", "visitor": "sp_arbolito", "weight": 6, "minTier": 6, "dailyCap": 3,
     "mechanic": {"kind": "exchange", "costSeconds": 5400, "oro": 1, "dailyOroCap": 3}},
    {"id": "arbolito_blue", "visitor": "sp_arbolito", "eventOnly": true, "weight": 1, "minTier": 6, "dailyCap": 3,
     "mechanic": {"kind": "exchange", "costSeconds": 3600, "oro": 1}},
    {"id": "coach_reto", "visitor": "sp_coach", "weight": 6, "minTier": 4, "dailyCap": 2,
     "mechanic": {"kind": "challenge", "taps": 67, "windowSeconds": 30,
                  "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 120}]}}
  ]
}
```

- [ ] **Step 4: La carga**

`GameContentLoader.swift`: `GameContent` suma, después de los configs que ya tenga (E11 T2 sumó
`notifications`; E3a T9, `tabs`):

```swift
    /// Los visitantes y sus guiones (PLAN-v2 E4, Anexos A y B).
    let visitors: VisitorsConfig
```

En `load(from:)`, junto a los otros `decode`:

```swift
        let visitors: VisitorsConfig = try decode("visitors", from: bundle)
```

y antes del `return`, con las otras validaciones:

```swift
        do {
            try visitors.validate()
        } catch {
            throw GameError.contentInvalid(file: "visitors.json", reason: "\(error)")
        }
        // Un especial que visita tiene que existir: si no, su guion nunca sale
        // (nadie lo consigue) y su arte no se encuentra.
        let specialIDs = Set(specials.specials.map(\.id))
        for visitor in visitors.visitors where visitor.kind == .special && !specialIDs.contains(visitor.id) {
            throw GameError.contentInvalid(file: "visitors.json", reason: "\(visitor.id) no está en specials.json")
        }
```

y `visitors: visitors` en el `GameContent(...)` del `return`.

- [ ] **Step 5: `VisitCopy.swift`**

`FisuEvolution/Managers/VisitCopy.swift`:

```swift
import EconomyKit
import Foundation

/// Los textos de los visitantes y cómo se llenan (PLAN-v2 E4, Anexo A).
///
/// Las claves van por convención y **los números salen del dato**: el valor del
/// catálogo lleva `%1$@`, `%2$@`… y acá se llenan con `String(format:)`, como
/// `IAPCopy`. Un "30 % off" escrito a mano se quedaría viejo en silencio el día
/// que el dato cambie.
enum VisitCopy {
    static func optionKey(_ kind: VisitOption.Kind) -> String {
        switch kind {
        case .accept: "visit.option.accept"
        case .acceptWithVideo: "visit.option.accept_video"
        case .payBail: "visit.option.pay_bail"
        case .release: "visit.option.release"
        case .payFine: "visit.option.pay_fine"
        case .forgiveWithVideo: "visit.option.forgive_video"
        case .sell: "visit.option.sell"
        case .exchange: "visit.option.exchange"
        case .startChallenge: "visit.option.start_challenge"
        case .card: "visit.option.card"
        case .listen: "visit.option.listen"
        }
    }

    /// El motivo absurdo del arresto, por el piso del arrestado.
    static func reasonKey(floorID: String) -> String { "visit.reason.\(floorID)" }

    static func name(of visitor: VisitorsConfig.Visitor, bundle: Bundle = .main) -> String {
        text(visitor.nameKey, bundle: bundle)
    }

    static func bubble(for script: VisitorsConfig.Script, offer: VisitOffer, content: GameContent, bundle: Bundle = .main) -> String {
        text(script.bubbleKey, arguments(for: script, offer: offer, content: content), bundle: bundle)
    }

    static func ask(for script: VisitorsConfig.Script, offer: VisitOffer, content: GameContent, bundle: Bundle = .main) -> String {
        text(script.askKey, arguments(for: script, offer: offer, content: content), bundle: bundle)
    }

    static func optionTitle(_ option: VisitOption, script: VisitorsConfig.Script, content: GameContent, bundle: Bundle = .main) -> String {
        let amount = CoinFormatter.string(from: abs(option.coins))
        switch option.kind {
        case .payBail, .release, .payFine, .sell:
            return text(optionKey(option.kind), [amount], bundle: bundle)
        case .exchange:
            let oro = option.rewards.reduce(0) { total, reward in
                if case .oro(let amount) = reward { return total + amount }
                return total
            }
            return text(optionKey(.exchange), [amount, String(oro)], bundle: bundle)
        case .card:
            guard case .vendor(let cards) = script.mechanic,
                  let card = cards.first(where: { "card.\($0.id)" == option.id })
            else { return text(optionKey(.card), [""], bundle: bundle) }
            return text(optionKey(.card), [text(card.nameKey, bundle: bundle)], bundle: bundle)
        case .accept, .acceptWithVideo, .forgiveWithVideo, .startChallenge, .listen:
            return text(optionKey(option.kind), bundle: bundle)
        }
    }

    /// Lo que llena el globo y el popup de un guion, en orden: el empleado y su
    /// motivo; el efecto y su duración; los toques y los segundos del reto; el
    /// tope del cambio.
    static func arguments(for script: VisitorsConfig.Script, offer: VisitOffer, content: GameContent) -> [String] {
        switch script.mechanic {
        case .arrest, .sale, .take:
            guard let typeId = offer.subjectTypeId, let type = content.tiers.type(id: typeId) else { return [] }
            let floor = content.floorTable.floor(forTier: type.tier)
            return [type.localizedName, text(reasonKey(floorID: floor.id))]
        case .gift(let rewards, _):
            return modifierArguments(rewards)
        case .fine(_, _, let stamp):
            return modifierArguments([stamp])
        case .exchange(_, _, let dailyOroCap):
            return dailyOroCap.map { [String($0)] } ?? []
        case let .challenge(taps, windowSeconds, rewards, _):
            return [String(taps), String(Int(windowSeconds))] + modifierArguments(rewards)
        case .vendor, .gossip:
            return []
        }
    }

    /// Cuántos datos le llegan a los textos de un guion (lo pinea
    /// `VisitorsContentTests`: un `%3$@` sin dato sería basura en pantalla).
    static func argumentCount(for script: VisitorsConfig.Script) -> Int {
        func modifiers(_ rewards: [RewardSpec]) -> Int {
            rewards.contains { if case .modifier = $0 { return true }; return false } ? 2 : 0
        }
        switch script.mechanic {
        case .arrest, .sale, .take: return 2
        case .gift(let rewards, _): return modifiers(rewards)
        case .fine: return 2
        case .exchange(_, _, let dailyOroCap): return dailyOroCap == nil ? 0 : 1
        case .challenge(_, _, let rewards, _): return 2 + modifiers(rewards)
        case .vendor, .gossip: return 0
        }
    }

    /// "×2", "−30%": el mismo número que el chip y el menú de Bonus.
    static func effectText(_ effect: ActiveModifier.Effect, magnitude: Double) -> String {
        let boostEffect: BoostsConfig.EffectType = switch effect {
        case .tapMultiplier: .tapMultiplier
        case .spawnCostMultiplier: .spawnCostMultiplier
        default: .incomeMultiplier
        }
        return EffectFormatter.text(EffectDescriptor.amount(forBoost: boostEffect, magnitude: magnitude))
    }

    /// "10 min" o "45 s", con las mismas claves que los videos de Regalos.
    static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 60, total % 60 == 0 {
            return String(localized: "ads.duration.min \(String(total / 60))")
        }
        return String(localized: "ads.duration.sec \(String(total))")
    }

    private static func modifierArguments(_ rewards: [RewardSpec]) -> [String] {
        for reward in rewards {
            if case let .modifier(effect, magnitude, seconds) = reward {
                return [effectText(effect, magnitude: magnitude), durationText(seconds)]
            }
        }
        return []
    }

    /// Un valor que ninguna traducción va a tener: `localizedString` devuelve el
    /// `value` cuando no encuentra la clave.
    private static let missing = "<visit.missing>"

    static func text(_ key: String, _ arguments: [String] = [], bundle: Bundle = .main) -> String {
        let format = bundle.localizedString(forKey: key, value: missing, table: nil)
        guard format != missing else { return key }
        // Sin datos no se formatea: `String(format:)` sobre un texto con un `%`
        // suelto se comería el carácter de al lado.
        guard !arguments.isEmpty else { return format }
        return String(format: format, arguments: arguments.map { $0 as CVarArg })
    }
}
```

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e4a-t7.json` (81 claves; las frases del Anexo A con los números del
dato pasados a `%N$@`):

```json
{
  "visitor.npc_comisario.name": {"es": "El Comisario", "en": "The Police Chief"},
  "visitor.npc_sindicalista.name": {"es": "El Sindicalista", "en": "The Union Rep"},
  "visitor.npc_turista.name": {"es": "El Turista Gringo", "en": "The Gringo Tourist"},
  "visitor.npc_puntero.name": {"es": "El Puntero", "en": "The Local Fixer"},
  "visitor.npc_ministro.name": {"es": "El Ministro de Economía", "en": "The Economy Minister"},
  "visitor.npc_vecina.name": {"es": "La Vecina Chusma", "en": "The Nosy Neighbor"},
  "visitor.npc_vendedor.name": {"es": "El Vendedor Ambulante", "en": "The Street Vendor"},
  "visitor.npc_conductor.name": {"es": "El Conductor de TV", "en": "The TV Host"},

  "visit.comisario_arresto.bubble": {"es": "¡Alto! Su %1$@ queda demorado por %2$@.", "en": "Freeze! Your %1$@ is being held for %2$@."},
  "visit.comisario_arresto.ask": {"es": "Si pagás la fianza, tu %1$@ vuelve a laburar. Si lo dejás ir, te indemnizan más de lo que cuesta reponerlo.", "en": "Pay the bail and your %1$@ gets back to work. Let him go and you're paid more than it costs to replace him."},
  "visit.comisario_multa.bubble": {"es": "Exceso de productividad en vía pública. Tiene 24 horas para quejarse… o sea, ahora.", "en": "Excessive productivity in a public space. You have 24 hours to complain… meaning right now."},
  "visit.comisario_multa.ask": {"es": "Pagala y te ganás un sello de productividad: ingresos %1$@ por %2$@. O mirá un video y te la perdona.", "en": "Pay it and earn a productivity stamp: income %1$@ for %2$@. Or watch a video and it's forgiven."},
  "visit.arca_paraiso.bubble": {"es": "Su %1$@ declaró un monoambiente y tiene tres islas en el Caribe. Queda detenido.", "en": "Your %1$@ declared a studio flat and owns three Caribbean islands. He's under arrest."},
  "visit.arca_paraiso.ask": {"es": "Pagá la fianza y tu %1$@ sigue en la torre. Si lo dejás ir, te indemnizan más de lo que cuesta reponerlo.", "en": "Pay the bail and your %1$@ stays in the tower. Let him go and you're paid more than it costs to replace him."},
  "visit.arca_factura.bubble": {"es": "Con factura A todo sale más barato. Firmá acá, acá y acá.", "en": "With a proper invoice everything's cheaper. Sign here, here and here."},
  "visit.arca_factura.ask": {"es": "Contratar %1$@ por %2$@.", "en": "Hiring %1$@ for %2$@."},
  "visit.influencer_novio.bubble": {"es": "¡Me puse de novio con tu %1$@! Nos vamos a Tulum. Te dejo un canje.", "en": "I'm dating your %1$@! We're off to Tulum. I'll leave you a sponsored gift."},
  "visit.influencer_novio.ask": {"es": "Se lleva a tu %1$@ y te deja plata y un Paquete de la Aduana: más de lo que vale.", "en": "Takes your %1$@ and leaves you cash and a Customs Package: worth more than him."},
  "visit.influencer_codigo.bubble": {"es": "¡Chicos! Con el código FISURA tienen %1$@ en TODO. Link en la bio.", "en": "Guys! Use code HOBO for %1$@ on EVERYTHING. Link in bio."},
  "visit.influencer_codigo.ask": {"es": "Contratar %1$@ por %2$@. Con video, dura el doble.", "en": "Hiring %1$@ for %2$@. With a video, it lasts twice as long."},
  "visit.sindicalista_aumento.bubble": {"es": "¡Paritaria cerrada! Tus muchachos cobran un plus. Yo me llevo el aplauso.", "en": "Wage deal closed! Your crew gets a bonus. I'll take the applause."},
  "visit.sindicalista_aumento.ask": {"es": "Ingresos %1$@ por %2$@. Con video, dura el doble.", "en": "Income %1$@ for %2$@. With a video, it lasts twice as long."},
  "visit.sindicalista_asado.bubble": {"es": "Hoy hay asado en el sindicato. Traje un paquetito para el barrio.", "en": "Barbecue at the union today. I brought a little package for the block."},
  "visit.sindicalista_asado.ask": {"es": "Un Paquete de la Aduana y plata para el barrio. Con video, el doble.", "en": "A Customs Package and cash for the block. Double with a video."},
  "visit.turista_compra.bubble": {"es": "¡Wow, very authentic! Pago cash por ese empleado. Todo es barato acá, che.", "en": "Wow, very authentic! I'll pay cash for that worker. Everything's so cheap here!"},
  "visit.turista_compra.ask": {"es": "Te paga por tu %1$@ mucho más de lo que cuesta reponerlo.", "en": "He pays far more for your %1$@ than it costs to replace him."},
  "visit.turista_propina.bubble": {"es": "¡Propina! En mi país es el 20 por ciento. Acá es más que un sueldo.", "en": "A tip! Back home it's 20 percent. Here it's more than a salary."},
  "visit.turista_propina.ask": {"es": "Una propina en efectivo. Con video, el doble.", "en": "A cash tip. Double with a video."},
  "visit.puntero_acto.bubble": {"es": "Necesito unos muchachos para un acto. Vuelven con choripán y un bolsón de regalo.", "en": "I need a few guys for a rally. They'll come back with a sausage sandwich and a gift bag."},
  "visit.puntero_acto.ask": {"es": "Se lleva unos %1$@ al acto y te deja un bolsón: un Paquete y plata, más de lo que valen.", "en": "Takes some of your %1$@ to the rally and leaves a gift bag: a Package and cash, worth more than them."},
  "visit.puntero_bolson.bubble": {"es": "Te dejo un bolsón. No preguntes de dónde sale ni quién lo manda.", "en": "Here's a gift bag. Don't ask where it came from or who sent it."},
  "visit.puntero_bolson.ask": {"es": "Un Paquete de la Aduana. Con video, el doble.", "en": "A Customs Package. Double with a video."},
  "visit.ministro_subsidio.bubble": {"es": "Subsidio focalizado a tu empresa. Focalizado en vos, sí.", "en": "A targeted subsidy for your company. Targeted at you, yes."},
  "visit.ministro_subsidio.ask": {"es": "Plata para tu empresa. Con video, el doble.", "en": "Cash for your company. Double with a video."},
  "visit.vecina_chisme.bubble": {"es": "¿Qué mirás, bobo? Andá pa' allá… ¡ah, sos vos! ¿Viste lo que dicen? Que se viene un evento… ¡yo no dije nada!", "en": "What are you looking at, dummy? Go over there… oh, it's you! Did you hear? Word is something's coming… I didn't say a thing!"},
  "visit.vecina_chisme.ask": {"es": "Te cuenta qué evento se viene y te deja algo de plata.", "en": "She tells you which event is coming and leaves you some cash."},
  "visit.vecina_favor.bubble": {"es": "Nene, ayudame con las bolsas del súper que me duele la cintura.", "en": "Sweetie, help me with the grocery bags, my back is killing me."},
  "visit.vecina_favor.ask": {"es": "Tocá a tus empleados %1$@ veces en %2$@ segundos y te regala un Paquete. Con video, el doble.", "en": "Tap your workers %1$@ times in %2$@ seconds and she gives you a Package. Double with a video."},
  "visit.vendedor_ofertas.bubble": {"es": "¡Llevá, llevá! Boost calentito, recién salido del horno. Con video te lo regalo.", "en": "Get it, get it! Fresh boosts, right out of the oven. Watch a video and it's yours."},
  "visit.vendedor_ofertas.ask": {"es": "Elegí un boost y miralo en video: es tuyo.", "en": "Pick a boost and watch a video: it's yours."},
  "visit.conductor_ruleta.bubble": {"es": "¡Y ahora… el momento que todos esperaban… LA RULETA! ¡Aplausos!", "en": "And now… the moment you've all been waiting for… THE WHEEL! Applause!"},
  "visit.conductor_ruleta.ask": {"es": "Un giro gratis de la ruleta.", "en": "A free spin of the wheel."},
  "visit.cryptobro_senal.bubble": {"es": "Hermano, el gráfico hizo six seven: todo en verde. Aprovechá y no preguntes cómo.", "en": "Bro, the chart went six seven: everything's green. Cash in and don't ask how."},
  "visit.cryptobro_senal.ask": {"es": "Ingresos %1$@ por %2$@. Con video, dura el doble.", "en": "Income %1$@ for %2$@. With a video, it lasts twice as long."},
  "visit.contador_credito.bubble": {"es": "Encontré un crédito fiscal en una dimensión que ni sabías que tenías.", "en": "I found a tax credit in a dimension you didn't even know you had."},
  "visit.contador_credito.ask": {"es": "Plata de una, sin trámite.", "en": "Cash right away, no paperwork."},
  "visit.zombie_reto.bubble": {"es": "No… duermo… hace… tres… quinquenios. ¿Tocamos… %1$@… veces?", "en": "Haven't… slept… in… fifteen… years. Shall we… tap… %1$@… times?"},
  "visit.zombie_reto.ask": {"es": "%1$@ toques en %2$@ segundos: ingresos %3$@ por %4$@. Si no llegás, no pasa nada.", "en": "%1$@ taps in %2$@ seconds: income %3$@ for %4$@. If you don't make it, nothing happens."},
  "visit.lizard_lengua.bubble": {"es": "Sssí, soy de este barrio. Tocá, tocá, que te rinde %1$@.", "en": "Yesss, I'm from around here. Tap, tap, it pays %1$@."},
  "visit.lizard_lengua.ask": {"es": "Tus toques valen %1$@ por %2$@.", "en": "Your taps are worth %1$@ for %2$@."},
  "visit.alien_inversion.bubble": {"es": "Mi planeta invierte en tu esquina. No entendemos la economía, pero nos gusta el dulce de leche.", "en": "My planet is investing in your corner. We don't get the economy, but we love dulce de leche."},
  "visit.alien_inversion.ask": {"es": "Plata de otro planeta. Con video, el doble.", "en": "Cash from another planet. Double with a video."},
  "visit.bug_reinicio.bubble": {"es": "Encontré un bug en la Matrix: tus boosts quedaron listos de nuevo. Que no se entere nadie.", "en": "Found a bug in the Matrix: your boosts are ready again. Don't tell anyone."},
  "visit.bug_reinicio.ask": {"es": "Todos tus boosts quedan listos para usar.", "en": "All your boosts are ready to use again."},
  "visit.arbolito_cambio.bubble": {"es": "¡Cambio, cambio, cambiooo! Plata por ORO, buen precio, sin preguntar.", "en": "Exchange, exchange, exchaaange! Cash for ORO, good rate, no questions asked."},
  "visit.arbolito_cambio.ask": {"es": "Te vende ORO a cambio de plata. Hasta %1$@ por día.", "en": "Sells you ORO for cash. Up to %1$@ a day."},
  "visit.arbolito_blue.bubble": {"es": "Con el cepo el único que te cambia soy yo… ¡al blue, ni preguntes!", "en": "With the currency clamp I'm the only one who'll swap… black-market rate, don't ask!"},
  "visit.arbolito_blue.ask": {"es": "Mientras dure el cepo, ORO más barato y sin tope.", "en": "While the clamp lasts, cheaper ORO with no limit."},
  "visit.coach_reto.bubble": {"es": "¿Y si el techo era una creencia limitante? Dale: %1$@ toques, ahora.", "en": "What if the ceiling was just a limiting belief? Come on: %1$@ taps, right now."},
  "visit.coach_reto.ask": {"es": "%1$@ toques en %2$@ segundos: ingresos %3$@ por %4$@. Si no llegás, es un proceso.", "en": "%1$@ taps in %2$@ seconds: income %3$@ for %4$@. If you don't make it, it's a journey."},

  "visit.reason.alley": {"es": "cuidar autos sin habilitación", "en": "parking cars without a permit"},
  "visit.reason.urban": {"es": "carrito en doble fila", "en": "double-parking a shopping cart"},
  "visit.reason.corporate": {"es": "responder un mail un domingo", "en": "answering an email on a Sunday"},
  "visit.reason.luxury": {"es": "estacionar el yate en la vereda", "en": "parking a yacht on the sidewalk"},
  "visit.reason.island": {"es": "broncearse sin factura", "en": "tanning without a receipt"},
  "visit.reason.moon": {"es": "hacer sombra sin permiso lunar", "en": "casting a shadow without a lunar permit"},
  "visit.reason.mars": {"es": "pisar el polvo rojo con zapatillas blancas", "en": "stepping on red dust in white sneakers"},
  "visit.reason.solar": {"es": "tapar el sol sin permiso", "en": "blocking the sun without a permit"},
  "visit.reason.galaxy": {"es": "exceso de velocidad warp", "en": "warp speeding"},
  "visit.reason.god_realm": {"es": "un milagro no declarado", "en": "an undeclared miracle"},

  "visit.option.accept": {"es": "¡De una!", "en": "Deal!"},
  "visit.option.accept_video": {"es": "×2 con video", "en": "×2 with a video"},
  "visit.option.pay_bail": {"es": "Pagar la fianza · %@", "en": "Pay the bail · %@"},
  "visit.option.release": {"es": "Que se lo lleve · +%@", "en": "Let him go · +%@"},
  "visit.option.pay_fine": {"es": "Pagar la multa · %@", "en": "Pay the fine · %@"},
  "visit.option.forgive_video": {"es": "Perdonala con un video", "en": "Let it slide with a video"},
  "visit.option.sell": {"es": "Vendérselo · +%@", "en": "Sell · +%@"},
  "visit.option.exchange": {"es": "Cambiar %1$@ por %2$@ ORO", "en": "Swap %1$@ for %2$@ ORO"},
  "visit.option.start_challenge": {"es": "¡Acepto el reto!", "en": "Challenge accepted!"},
  "visit.option.card": {"es": "%@ con video", "en": "%@ with a video"},
  "visit.option.listen": {"es": "Contame todo", "en": "Spill it"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4a-t7.json` → `81 claves nuevas`.

- [ ] **Step 7: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/VisitorsContentTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/GameContentValidationTests`
→ PASS (la familia nueva nombrada en la salida). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Resources/Config/visitors.json FisuEvolution/Managers/VisitCopy.swift \
  FisuEvolution/Managers/GameContentLoader.swift FisuEvolutionTests/LocalizationCompletenessTests.swift \
  FisuEvolutionTests/VisitorsContentTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4a-t7.json, según la ola
git diff --cached --stat
git commit -m "feat(visitantes): visitors.json con los 18 del elenco y los 26 guiones, validados y en dos idiomas"
```

---

### Task 8: Un solo punto de entrega de premios, y el momento calmo

**Objetivo:** `GameState.grant(_:multiplier:source:)` —el único lugar donde la 2.0 entrega un
premio (PLAN-v2 "Cimientos")— con los tipos que la app ya sabe dar (plata en segundos de
producción, ORO al balance, cofres, modificadores, cooldowns, inmunidad) y la lista explícita de
los que todavía no (paquete y ruleta los entrega E5; auto-tap, multiplicadores del próximo
offline/diario y lugares extra, E6). Más `isCalmMoment`, el predicado que comparten visitantes,
eventos e intersticiales, y `coinsPerProductionSecond`, la valuación que usa `VisitPlanner`. Un
archivo nuevo: no toca calientes.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Rewards.swift`
- Create: `FisuEvolutionTests/RewardGrantTests.swift`

**Interfaces:**
- Consumes: `RewardSpec` (T1), `.eventImmunity` (T2), `GameState.coinReward(seconds:player:content:economy:)`
  `static` (**E1 T14**), `GameState.isSceneActive` (**E1 T8**).
- Produces: `static let grantableRewardKinds: Set<RewardSpec.Kind>` (en `GameState`),
  `@discardableResult func grant(_ reward: RewardSpec, multiplier: Int = 1, source: String, now: TimeInterval = …) -> Double`,
  `@discardableResult func grant(_ rewards: [RewardSpec], multiplier: Int = 1, source: String, now: TimeInterval = …) -> Double`
  (las dos devuelven la plata acreditada), `func creditCoins(_ amount: Double)`,
  `var coinsPerProductionSecond: Double`, `var isCalmMoment: Bool`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/RewardGrantTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Premios: un solo punto de entrega")
@MainActor
struct RewardGrantTests {
    @Test("la plata se cotiza en segundos de producción y el video la duplica")
    func coinsAreProductionSeconds() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let expected = GameState.coinReward(seconds: 900, player: before, content: content, economy: economy)
        let credited = gameState.grant(.coinsSeconds(900), source: "test")
        #expect(abs(credited - expected) < 1e-6 * max(1, expected))
        let after = try #require(gameState.player)
        #expect(abs(after.run.coins - before.run.coins - expected) < 1e-6 * max(1, expected))
        #expect(abs(after.meta.lifetimeEarnings - before.meta.lifetimeEarnings - expected) < 1e-6 * max(1, expected))
        let doubled = gameState.grant(.coinsSeconds(900), multiplier: 2, source: "test")
        let expectedDouble = GameState.coinReward(seconds: 1800, player: after, content: content, economy: economy)
        #expect(abs(doubled - expectedDouble) < 1e-6 * max(1, expectedDouble))
    }

    @Test("un modificador dura lo que dice, lleva su origen, y el video lo estira")
    func modifiersLastAndCarryTheirSource() async throws {
        let gameState = await makeGameState()
        gameState.grant(.modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600),
                        multiplier: 2, source: "visit.sindicalista_aumento", now: 1000)
        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "visit.sindicalista_aumento" })
        #expect(modifier.magnitude == 1.5)
        #expect(modifier.expiresAt == 2200)
    }

    @Test("ORO al balance, nunca al ORO de por vida (el multiplicador lo gana sólo el prestigio)")
    func oroGoesToTheBalance() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player?.meta)
        gameState.grant(.oro(3), source: "visit.arbolito_cambio")
        #expect(gameState.player?.meta.oro == before.oro + 3)
        #expect(gameState.player?.meta.oroEarnedLifetime == before.oroEarnedLifetime)
    }

    @Test("cofres a la cola de cofres, cooldowns a cero, inmunidad como modificador")
    func theOtherKinds() async throws {
        let gameState = await makeGameState()
        let chests = try #require(gameState.player?.meta.chestsPending)
        gameState.grant(.skinChest(1), source: "test")
        #expect(gameState.player?.meta.chestsPending == chests + 1)
        gameState.player?.meta.boostActivations = ["mate": 1, "cafe": 2]
        gameState.grant(.clearBoostCooldowns, source: "visit.bug_reinicio")
        #expect(gameState.player?.meta.boostActivations.isEmpty == true)
        gameState.grant(.eventImmunity(seconds: 1800), source: "career.junior_doctor", now: 10)
        let player = try #require(gameState.player)
        #expect(ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: 11))
    }

    @Test("lo que todavía no se puede entregar no toca nada",
          arguments: [RewardSpec.package(1), .wheelSpin(1), .autoTap(perSecond: 5, seconds: 60),
                      .nextOfflineMultiplier(3), .nextDailyMultiplier(3), .extraSlots(3)])
    func notYetGrantable(reward: RewardSpec) async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)
        #expect(gameState.grant(reward, source: "test") == 0)
        #expect(gameState.player == before)
    }

    @Test("lo entregable es exactamente lo que este punto sabe dar")
    func grantableKinds() {
        #expect(GameState.grantableRewardKinds == [.coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity])
    }

    @Test("varios premios juntos: una sola pasada, la plata sumada")
    func severalRewards() async throws {
        let gameState = await makeGameState()
        let credited = gameState.grant([.coinsSeconds(60), .oro(1), .coinsSeconds(60)], source: "test")
        #expect(credited > 0)
        #expect(gameState.player?.meta.oro == 1)
    }

    @Test("un segundo de producción vale algo aunque la torre no produzca (el piso de los premios)")
    func productionSecondHasAFloor() async throws {
        let gameState = await makeGameState()
        #expect(gameState.coinsPerProductionSecond > 0)
    }

    @Test("el momento calmo: tablero a la vista, sin hoja, sin celebración, sin tutorial, sin ficha")
    func calmMoment() async throws {
        let gameState = await makeGameState()
        #expect(gameState.isCalmMoment)
        gameState.uiCoversBoard = true
        #expect(!gameState.isCalmMoment)
        gameState.uiCoversBoard = false
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(!gameState.isCalmMoment)
        gameState.celebrationFinished(.towerNotice)
        #expect(gameState.isCalmMoment)
        gameState.beginTutorialPhase()
        #expect(!gameState.isCalmMoment)
        gameState.tutorialPhaseFinished()
        drain(gameState)
        gameState.handleScenePhase(from: .active, to: .inactive)
        #expect(!gameState.isCalmMoment, "con la escena inactiva no aparece nadie")
    }

    /// El cofre de bienvenida que cae al cerrar la fase toma el turno: se vacía la cola.
    private func drain(_ gameState: GameState) {
        for _ in 0..<12 {
            guard let current = gameState.showing else { return }
            if current == .chestOpening { gameState.chestReward = nil }
            gameState.celebrationFinished(current)
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/RewardGrantTests`.
Expected: no compila (`grant` no existe).

- [ ] **Step 3: `GameState+Rewards.swift`**

```swift
import EconomyKit
import Foundation

/// El único punto donde la 2.0 entrega un premio (PLAN-v2, "Cimientos
/// compartidos"): visitantes, eventos y, después, ruleta, colchón, tienda y
/// ofertas pasan por acá. `multiplier` es el "×2 con video".
extension GameState {
    /// Lo que este punto ya sabe dar. E5 suma `.package` y `.wheelSpin`; E6,
    /// `.autoTap`, los multiplicadores del próximo offline y diario y `.extraSlots`.
    /// Un guion o un evento que da algo de afuera de esta lista **no se ofrece**
    /// (`VisitorScheduler`, `eventIsApplicable`): mejor que no venga a que prometa
    /// y no cumpla.
    static let grantableRewardKinds: Set<RewardSpec.Kind> = [
        .coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity,
    ]

    /// Un momento en que algo puede aparecer solo sin pisar al jugador: el tablero
    /// a la vista (escena activa, sin hoja, sin ficha, sin carrera), sin
    /// celebración en pantalla y fuera de la fase obligatoria del tutorial. Es
    /// `isSafeMomentForInterstitial` más la escena y la ficha; E7b pasa los
    /// intersticiales a éste.
    var isCalmMoment: Bool {
        phase == .ready && isSceneActive && !uiCoversBoard && celebrations.current == nil
            && !tutorialPhaseActive && characterSheet == nil && careerPrompt == nil
    }

    /// Cuánto vale un segundo de producción ahora: la misma base que los premios de
    /// logros (`coinReward`), con su piso del "trabajador solitario".
    var coinsPerProductionSecond: Double {
        guard let content, let economy, let player else { return 0 }
        return Self.coinReward(seconds: 1, player: player, content: content, economy: economy)
    }

    @discardableResult
    func grant(
        _ rewards: [RewardSpec],
        multiplier: Int = 1,
        source: String,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Double {
        rewards.reduce(0) { total, reward in
            total + grant(reward, multiplier: multiplier, source: source, now: now)
        }
    }

    /// Entrega UN premio. Devuelve la plata acreditada (0 si no era plata).
    @discardableResult
    func grant(
        _ reward: RewardSpec,
        multiplier: Int = 1,
        source: String,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Double {
        guard Self.grantableRewardKinds.contains(reward.kind) else {
            Log.economy.error("reward not grantable yet: \(reward.kind.rawValue) from \(source)")
            return 0
        }
        guard let content, let economy, var player else { return 0 }
        var credited = 0.0
        switch reward.scaled(by: multiplier) {
        case .coinsSeconds(let seconds):
            credited = Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
            player.run.coins += credited
            player.meta.lifetimeEarnings += credited
        case .oro(let amount):
            // Sólo el balance, como logros y tienda: `oroEarnedLifetime` alimenta el
            // multiplicador global y eso lo gana el prestigio.
            player.meta.oro += amount
        case .skinChest(let count):
            player.meta.chestsPending += count
        case let .modifier(effect, magnitude, seconds):
            player.run.activeModifiers.append(ActiveModifier(
                effect: effect, magnitude: magnitude, expiresAt: now + seconds, sourceKey: source
            ))
        case .clearBoostCooldowns:
            player.meta.boostActivations.removeAll()
        case .eventImmunity(let seconds):
            player.run.activeModifiers.append(ActiveModifier(
                effect: .eventImmunity, magnitude: 1, expiresAt: now + seconds, sourceKey: source
            ))
        case .package, .wheelSpin, .autoTap, .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots:
            return 0
        }
        self.player = player
        effectsVersion += 1
        if credited > 0 { audio?.play(.coin) }
        refreshProjections()
        scheduleSave()
        Log.economy.info("reward granted: \(reward.kind.rawValue) ×\(multiplier) from \(source)")
        return credited
    }

    /// Plata ya cotizada (la oferta de un visitante se cotiza al llegar).
    func creditCoins(_ amount: Double) {
        guard amount != 0, var player else { return }
        player.run.coins += amount
        if amount > 0 { player.meta.lifetimeEarnings += amount }
        self.player = player
        refreshProjections()
        scheduleSave()
    }
}
```

- [ ] **Step 4: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/RewardGrantTests`
→ PASS (9 tests, uno con 6 argumentos). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Rewards.swift FisuEvolutionTests/RewardGrantTests.swift
git diff --cached --stat
git commit -m "feat(premios): un solo punto de entrega y el momento calmo"
```

---

### Task 9: La mudanza — el juego corre sobre los eventos v2

**Objetivo:** que el juego use el motor de la Task 4 con el contenido del Anexo A: `events.json`
pasa a schema 2 con los 18 eventos; el reloj vive en el save y cuenta juego activo
(`advanceEngagement`, colgado del tick); vencer arranca el evento con sus efectos compuestos, su
intención de tablero por el embudo y su plata por `grant`; el banner de siempre muestra la frase
y **todas** las salidas (video, cuota, gratis). Se borran `EventsConfig`, `EventManager` y la
sección de eventos de `+Bonus`, con todo lo que E1 les sumó, y se reescriben contra el motor
nuevo las suites de E1 que los usaban. Es la única tarea caliente de E4a: corre sola en su ola.

**Files:**
- Modify: `FisuEvolution/Resources/Config/events.json` (schema 2, los 18)
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`events: EventCatalog` + validación cruzada con `visitors.json`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (se va `EventsConfig`)
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (se va `EventManager`, de `// MARK: - Eventos argentinizados` a `// MARK: - Boosts`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (se va la sección `// MARK: Eventos` entera)
- Create: `FisuEvolution/Game/State/GameState+Events.swift`
- Create: `FisuEvolution/Game/State/GameState+Engagement.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (🔥: `activeEvent` con el tipo nuevo; `engagementAutorun`; se van `nextEventAt`/`eventLastFired`; el gancho del tick, del flush y del bootstrap)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugStartEvent(id:)`, `debugStartCorralito()`, `applyLaunchArgumentDefaults`)
- Modify: `FisuEvolution/UI/HUD/EventBannerView.swift` (lee el evento v2; sus tres salidas)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (`debug.event.start`)
- Modify: `Tools/v2/catalogo.py`, `Tools/v2/test_catalogo.py` (`quitar`)
- Create: `FisuEvolutionTests/EventsRuntimeTests.swift`, `FisuEvolutionTests/EventsContentTests.swift`
- Modify: `FisuEvolutionTests/ContentSystemsTests.swift` (se van `// MARK: Eventos` y `// MARK: Cadencia y dosis de los eventos`, hasta `// MARK: Boosts`), `LocalizationCompletenessTests.swift` (familia `events`), `EffectContractTests.swift` (`eventEffects`), `LifecycleTests.swift` (`overdueEventIsPostponed`), `BoardChangeProducersTests.swift` (`startupPlansInsteadOfMutating`), `CorralitoTests.swift`
- Delete: `FisuEvolutionTests/EventSchedulingTests.swift` (E1 T11; sus cuatro casos pasan a `EventsRuntimeTests` y a `EventSchedulerTests`)
- Strings: `Tools/v2/claves-pendientes/e4a-t9.json` (38 claves) y `e4a-t9.quitar` (8 claves viejas)

**Interfaces:**
- Consumes: T2, T4, T7, T8; **toda E1**: `isSceneActive`, el tick y `handleScenePhase` de T8
  (que llama a `postponeOverdueEvent(now:)`), `enqueueBoardChange`/`pendingBoardChanges` (T9),
  `BoardChangePlanner.planEvolve/planArrival` (T7), `spendingFrozen` y el fixture
  `--uitest-corralito` (T13), `EffectContractTests` (T15).
- Produces: `GameState.ActiveEvent` (`id`, `phraseKey`, `polarity`, `endsAt`, `escapes`),
  `var activeEvent: ActiveEvent?` (mismo nombre), `@ObservationIgnored var engagementAutorun`.
- Produces: `GameState.advanceEngagement(delta:)` (el gancho que E4b y E5 extienden),
  `advanceEvents(delta:)`, `fireDueEvent(now:)`, `startEvent(_:now:)`, `expireActiveEvent(now:)`,
  `eventIsApplicable(_:) -> Bool`, `escapeEvent(id:via:now:) -> Bool`, `eventFee(id:) -> Double?`,
  `eventFeeText(id:) -> String`, `cutNegativeEvents(now:)`, `postponeOverdueEvent(now:)`,
  `peekUpcomingEvent() -> EventCatalog.Event?`, `static let instantEventBannerSeconds`.
- Produces (DEBUG): `debugStartEvent(id:)`, `applyEngagementFixtures(arguments:)`,
  `static func fixtureValue(_:in:) -> String?`, el fixture `--uitest-event=<id>`.
- Produces: `Tools/v2/catalogo.py quitar <clave>…`.

- [ ] **Step 0: E1 está entera**

Run: `grep -rn "func handleEventRoll\|retryWhenNoneApplicableSeconds\|escapableByVideo\|func postponeOverdueEvent" FisuEvolution`
Expected: las cuatro aparecen (son de E1 T8, T11, T12 y T13). Si falta alguna, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/EventsContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los 18 eventos del Anexo A, tal como quedaron en el dato.
@Suite("Eventos v2: el contenido real")
struct EventsContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func event(_ id: String) throws -> EventCatalog.Event {
        try #require(content.events.event(id: id))
    }

    @Test("los 18 del Anexo A: los 8 de siempre y los 10 nuevos")
    func theEighteen() {
        #expect(Set(content.events.events.map(\.id)) == [
            "plan_platita", "startup_comprada", "devaluacion", "blanqueo", "home_banking", "inversion_alienigena",
            "corralito", "aguinaldo", "campeones", "liquidacion", "feriado_puente", "lluvia_paquetes",
            "paro_general", "apagon", "hiperinflacion", "cepo", "piquete", "ola_calor",
        ])
        #expect(content.events.event(id: "cayo_mercado_pago") == nil, "la marca real se fue (guía 5.2.1)")
    }

    @Test("cada uno lo presenta quien dice el Anexo A")
    func presenters() {
        let expected: [String: String] = [
            "plan_platita": "npc_ministro", "startup_comprada": "npc_conductor", "devaluacion": "npc_ministro",
            "blanqueo": "npc_ministro", "home_banking": "npc_vendedor", "inversion_alienigena": "sp_alien_investor",
            "corralito": "npc_ministro", "aguinaldo": "npc_sindicalista", "campeones": "npc_conductor",
            "liquidacion": "npc_vendedor", "feriado_puente": "npc_sindicalista", "lluvia_paquetes": "npc_puntero",
            "paro_general": "npc_sindicalista", "apagon": "npc_vecina", "hiperinflacion": "npc_ministro",
            "cepo": "npc_ministro", "piquete": "npc_vecina", "ola_calor": "npc_vecina",
        ]
        #expect(Dictionary(uniqueKeysWithValues: content.events.events.map { ($0.id, $0.presenters.first ?? "") }) == expected)
    }

    /// La queja del dueño fue la FRECUENCIA (ContentSystemsTests de la v1): un evento
    /// cada 15–20 min, ahora de juego activo.
    @Test("la cadencia: uno cada 15 a 20 minutos de juego, el primero a los 15")
    func cadence() {
        #expect(content.events.intervalSeconds == 900)
        #expect(content.events.intervalJitterSeconds == 300)
        #expect(content.events.firstEventAfterSeconds == 900)
        #expect(content.events.retryWhenNoneApplicableSeconds == 30)
        #expect(content.events.resumeGraceSeconds == 60)
    }

    /// Los negativos son la tensión del juego: dosificar a los buenos no puede
    /// convertir la torre en un jardín (la regla de la v1 sigue).
    @Test("los malos pesan por lo menos lo que los buenos")
    func badEventsCarryAtLeastHalfTheWeight() {
        let good = content.events.events.filter { $0.polarity == .positive }.map(\.weight).reduce(0, +)
        let bad = content.events.events.filter { $0.polarity != .positive }.map(\.weight).reduce(0, +)
        #expect(bad >= good, "peso buenos \(good) vs malos \(bad)")
        #expect(good > 0)
    }

    @Test("todo negativo sale por video; el paro también con cuota; la hiperinflación saca sólo el ×2 de contratar")
    func escapes() throws {
        for event in content.events.events where event.polarity != .positive {
            #expect(event.escapes.contains { $0.kind == .video }, "\(event.id) sin salida por video")
        }
        let paro = try event("paro_general")
        #expect(paro.escapes.first { $0.kind == .fee }?.feeSeconds == 120)
        let hiper = try event("hiperinflacion")
        #expect(hiper.polarity == .mixed)
        #expect(hiper.escapes.first?.removes == [.spawnCostMultiplier])
    }

    @Test("los generosos siguen dosificados (los números de la v1)")
    func theGenerousEventsStayDialedDown() throws {
        #expect(try event("plan_platita").effects == [.modifier(effect: .incomeMultiplier, magnitude: 3)])
        #expect(try event("inversion_alienigena").effects == [.modifier(effect: .incomeMultiplier, magnitude: 5)])
        #expect(try event("aguinaldo").effects == [.coinsSeconds(300)])
        #expect(try event("blanqueo").effects == [.grantUnit(tiersBelowFrontier: 3)])
        #expect(try event("plan_platita").cooldownSeconds >= 1800)
        #expect(try event("startup_comprada").cooldownSeconds >= 2700)
        #expect(try event("inversion_alienigena").cooldownSeconds >= 7200)
        #expect(try event("aguinaldo").cooldownSeconds >= 5400)
        #expect(try event("blanqueo").cooldownSeconds >= 5400)
    }

    @Test("los efectos de §2: paro sobre el pasivo, corralito sobre el gasto, lluvia y piquete sobre los paquetes")
    func theNewEffects() throws {
        #expect(try event("paro_general").effects == [.modifier(effect: .passiveMultiplier, magnitude: 0)])
        #expect(try event("corralito").effects == [.modifier(effect: .spendingFrozen, magnitude: 1)])
        #expect(try event("lluvia_paquetes").effects == [.modifier(effect: .packageRateMultiplier, magnitude: 10)])
        #expect(try event("piquete").effects == [.modifier(effect: .packageRateMultiplier, magnitude: 0)])
        #expect(try event("hiperinflacion").effects == [
            .modifier(effect: .spawnCostMultiplier, magnitude: 2), .modifier(effect: .incomeMultiplier, magnitude: 3),
        ])
    }

    @Test("las escenas: el apagón con velitas, los campeones y la liquidación")
    func scenes() throws {
        #expect(try event("apagon").scene == .blackout)
        #expect(try event("apagon").candleStep == 0.07)
        #expect(try event("campeones").scene == .champions)
        #expect(try event("liquidacion").scene == .sale)
    }

    @Test("el cepo llama al blue del Arbolito")
    func cepoCallsTheArbolito() throws {
        #expect(try event("cepo").effects.contains(.callVisitor(script: "arbolito_blue")))
        #expect(content.visitors.script(id: "arbolito_blue")?.eventOnly == true)
    }
}
```

`FisuEvolutionTests/EventsRuntimeTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Eventos v2 en la partida")
@MainActor
struct EventsRuntimeTests {
    /// Partida con la torre abierta hasta `tier` y el Fisura produciendo.
    private func game(throughTier tier: Int = 12) async throws -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.debugUnlockFloors(throughTier: tier)
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        return gameState
    }

    private func event(_ id: String, in gameState: GameState) throws -> EventCatalog.Event {
        try #require(gameState.content?.events.event(id: id))
    }

    /// Lo que salió del sorteo, leído del cooldown y no del banner: E4b cambia
    /// cómo se anuncia (un presentador), no cómo se sortea.
    private func fired(_ gameState: GameState) -> Set<String> {
        Set(gameState.player?.meta.engagement.events.lastFiredAt.keys.map { $0 } ?? [])
    }

    @Test("bajo XCTest el motor no corre solo")
    func autorunIsOffUnderTests() async {
        let gameState = await makeGameState()
        #expect(!gameState.engagementAutorun)
        gameState.player?.meta.engagement.events.secondsUntilNext = 0
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.player?.meta.engagement.events.clock == 0)
        #expect(fired(gameState).isEmpty)
    }

    @Test("cuando vence, sale uno, anota su cooldown y programa el siguiente")
    func dueEventStartsAndReschedules() async throws {
        let gameState = try await game()
        gameState.player?.meta.engagement.events.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        let id = try #require(fired(gameState).first)
        let content = try #require(gameState.content)
        let state = try #require(gameState.player?.meta.engagement.events)
        #expect(state.lastFiredAt[id] == state.clock)
        let next = try #require(state.secondsUntilNext)
        #expect(next >= content.events.intervalSeconds)
        #expect(next < content.events.intervalSeconds + content.events.intervalJitterSeconds)
    }

    @Test("un sorteo sin candidatos no gasta el intervalo")
    func emptyDrawRetriesSoon() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.player?.meta.engagement.events.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(fired(gameState).isEmpty, "frontera 1: ningún evento es elegible")
        let retry = try #require(gameState.content?.events.retryWhenNoneApplicableSeconds)
        #expect(gameState.player?.meta.engagement.events.secondsUntilNext == retry)
    }

    @Test("sin nadie que pueda crecer solo, la Startup no aplica")
    func startupNeedsSomeoneWhoCanEvolve() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["administrativo": 1]
        gameState.reconcileTower()
        #expect(!gameState.eventIsApplicable(try event("startup_comprada", in: gameState)))
    }

    @Test("sin pasivo, el Aguinaldo no aplica; los paquetes esperan a E5")
    func applicability() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.eventIsApplicable(try event("aguinaldo", in: gameState)))
        #expect(!gameState.eventIsApplicable(try event("lluvia_paquetes", in: gameState)))
        #expect(!gameState.eventIsApplicable(try event("piquete", in: gameState)))
        #expect(gameState.eventIsApplicable(try event("devaluacion", in: gameState)))
    }

    @Test("con obra social no sale un negativo")
    func immunityFiltersNegatives() async throws {
        let gameState = try await game(throughTier: 30)
        gameState.grant(.eventImmunity(seconds: 1800), source: "test")
        let content = try #require(gameState.content)
        var seen: Set<String> = []
        for _ in 0..<60 {
            gameState.player?.meta.engagement.events.secondsUntilNext = 0.1
            gameState.player?.meta.engagement.events.lastFiredAt = [:]
            gameState.advanceEngagement(delta: 1)
            seen.formUnion(fired(gameState))
        }
        #expect(!seen.isEmpty)
        for id in seen {
            #expect(content.events.event(id: id)?.polarity != .negative, "\(id) salió con inmunidad")
        }
    }

    @Test("arrancar deja los modificadores con su origen")
    func startEventAppliesEverything() async throws {
        let gameState = try await game()
        let hiper = try event("hiperinflacion", in: gameState)
        gameState.startEvent(hiper, now: 1000)
        let modifiers = try #require(gameState.player?.run.activeModifiers.filter { $0.sourceKey == "event.hiperinflacion" })
        #expect(Set(modifiers.map(\.effect)) == [.spawnCostMultiplier, .incomeMultiplier])
        #expect(modifiers.allSatisfy { $0.expiresAt == 1060 })
    }

    @Test("el banner muestra el evento con sus salidas")
    func bannerShowsTheEvent() async throws {
        let gameState = try await game()
        gameState.startEvent(try event("hiperinflacion", in: gameState), now: 1000)
        #expect(gameState.activeEvent?.id == "hiperinflacion")
        #expect(gameState.activeEvent?.escapes.map(\.kind) == [.video])
    }

    @Test("la salida por video saca el evento; la de la hiperinflación, sólo el ×2 de contratar")
    func videoEscapes() async throws {
        let gameState = try await game()
        let now = Date().timeIntervalSince1970
        gameState.startEvent(try event("devaluacion", in: gameState), now: now)
        #expect(gameState.escapeEvent(id: "devaluacion", via: .video, now: now))
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "event.devaluacion" } == false)
        gameState.startEvent(try event("hiperinflacion", in: gameState), now: now)
        #expect(gameState.escapeEvent(id: "hiperinflacion", via: .video, now: now))
        let left = try #require(gameState.player?.run.activeModifiers.filter { $0.sourceKey == "event.hiperinflacion" })
        #expect(left.map(\.effect) == [.incomeMultiplier], "la caja ×3 se queda")
        #expect(!gameState.escapeEvent(id: "plan_platita", via: .video, now: now), "un positivo no tiene salida")
    }

    @Test("la cuota del paro cobra su plata y lo saca; sin plata, no")
    func feeEscape() async throws {
        let gameState = try await game()
        let now = Date().timeIntervalSince1970
        let paro = try event("paro_general", in: gameState)
        gameState.player?.run.coins = 0
        gameState.startEvent(paro, now: now)
        #expect(!gameState.escapeEvent(id: "paro_general", via: .fee, now: now))
        let fee = try #require(gameState.eventFee(id: "paro_general"))
        gameState.player?.run.coins = fee * 2
        #expect(gameState.escapeEvent(id: "paro_general", via: .fee, now: now))
        let coins = try #require(gameState.player?.run.coins)
        #expect(abs(coins - fee) < 1e-6 * max(1, fee))
    }

    @Test("la Startup y el Blanqueo pasan por el embudo de E1")
    func boardIntentsGoThroughTheFunnel() async throws {
        let gameState = try await game()
        let units = try #require(gameState.player?.run.units)
        gameState.startEvent(try event("startup_comprada", in: gameState), now: 0)
        #expect(gameState.player?.run.units == units, "no muta en el acto")
        #expect(gameState.pendingBoardChanges.last?.origin == .eventStartup)
        gameState.startEvent(try event("blanqueo", in: gameState), now: 0)
        guard case .arrival(let typeId)? = gameState.pendingBoardChanges.last?.kind else {
            Issue.record("el Blanqueo no planeó una llegada")
            return
        }
        #expect(gameState.content?.tiers.type(id: typeId)?.tier == 12 - 3)
    }

    @Test("el Aguinaldo paga sus segundos de producción")
    func aguinaldoPays() async throws {
        let gameState = try await game()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        gameState.startEvent(try event("aguinaldo", in: gameState), now: 0)
        let expected = GameState.coinReward(seconds: 300, player: before, content: content, economy: economy)
        let paid = try #require(gameState.player?.run.coins) - before.run.coins
        #expect(abs(paid - expected) < 1e-6 * max(1, expected))
    }

    @Test("cortar los negativos deja los mixtos y los positivos")
    func cutNegatives() async throws {
        let gameState = try await game()
        let now = Date().timeIntervalSince1970
        for id in ["devaluacion", "hiperinflacion", "plan_platita"] {
            gameState.startEvent(try event(id, in: gameState), now: now)
        }
        gameState.cutNegativeEvents(now: now)
        let sources = Set(gameState.player?.run.activeModifiers.map(\.sourceKey) ?? [])
        #expect(!sources.contains("event.devaluacion"))
        #expect(sources.contains("event.hiperinflacion"))
        #expect(sources.contains("event.plan_platita"))
    }

    @Test("lo que la Vecina adelanta es lo que sale")
    func upcomingIsWhatComes() async throws {
        let gameState = try await game(throughTier: 30)
        let peeked = try #require(gameState.peekUpcomingEvent())
        gameState.player?.meta.engagement.events.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(fired(gameState) == [peeked.id])
    }

    @Test("el banner de un evento instantáneo dura sus segundos y se va")
    func bannerLifetime() async throws {
        let gameState = try await game()
        gameState.startEvent(try event("aguinaldo", in: gameState), now: 100)
        #expect(gameState.activeEvent?.endsAt == 100 + GameState.instantEventBannerSeconds)
        gameState.expireActiveEvent(now: 100 + GameState.instantEventBannerSeconds)
        #expect(gameState.activeEvent == nil)
    }
}
```

Las suites de E1 que hablan del motor viejo, reescritas (se reemplaza el test entero; el resto
de cada suite no se toca):

`FisuEvolutionTests/BoardChangeProducersTests.swift`, `startupPlansInsteadOfMutating`:

```swift
    @Test("la Startup ya no evoluciona en el acto: deja el cambio planeado")
    func startupPlansInsteadOfMutating() async throws {
        let gameState = await makeGameState()
        let startup = try #require(gameState.content?.events.event(id: "startup_comprada"))
        gameState.player?.run.raiseFrontier(to: startup.minTier)
        let units = try #require(gameState.player?.run.units)
        gameState.startEvent(startup, now: 0)
        #expect(gameState.player?.run.units == units)
        #expect(gameState.pendingBoardChanges.first?.origin == .eventStartup)
    }
```

`FisuEvolutionTests/CorralitoTests.swift`, los dos tests:

```swift
    @Test("el evento congela el gasto con su motivo, y el video lo levanta")
    func corralitoFreezesAndTheVideoLifts() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.debugStartCorralito()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil != nil)
        let base = try #require(gameState.content?.tiers.baseType.id)
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units)
        #expect(gameState.towerNotice?.kind == .spendingFrozen)
        #expect(gameState.escapeEvent(id: "corralito", via: .video))
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil == nil)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units + 1)
    }

    @Test("el JSON del Corralito dice lo que hace")
    func corralitoDataMatchesTheDecision() async throws {
        let gameState = await makeGameState()
        let corralito = try #require(gameState.content?.events.event(id: "corralito"))
        #expect(corralito.effects == [.modifier(effect: .spendingFrozen, magnitude: 1)])
        #expect(corralito.escapes.map(\.kind) == [.video])
        #expect(corralito.durationSeconds == 45)
    }
```

`FisuEvolutionTests/LifecycleTests.swift`, `overdueEventIsPostponed`:

```swift
    @Test("un evento vencido no dispara al volver: se corre la gracia del dato")
    func overdueEventIsPostponed() async throws {
        let gameState = await makeGameState()
        let t0 = Date().timeIntervalSince1970
        gameState.player?.meta.engagement.events.secondsUntilNext = 0
        gameState.handleScenePhase(from: .active, to: .background, now: t0)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + 3600)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 3601)
        let grace = try #require(gameState.content?.events.resumeGraceSeconds)
        #expect(gameState.player?.meta.engagement.events.secondsUntilNext == grace)
    }
```

`FisuEvolutionTests/EffectContractTests.swift`, `eventEffects` (el `switch` sobre
`EventCatalog.Effect` va sin `default`: un efecto nuevo sin fila no compila):

```swift
    @Test("cada evento hace lo que su dato declara")
    func eventEffects() async throws {
        for event in content.events.events {
            let gameState = await makeGameState()
            gameState.debugUnlockFloors(throughTier: max(event.minTier, 12))
            gameState.player?.run.passiveUnlocked[base.id] = true
            let before = try #require(gameState.player)
            let now = Date().timeIntervalSince1970
            gameState.startEvent(event, now: now)
            let after = try #require(gameState.player)
            #expect(String(localized: String.LocalizationValue(event.phraseKey)) != event.phraseKey)
            #expect(String(localized: String.LocalizationValue(event.titleKey)) != event.titleKey)
            for effect in event.effects {
                switch effect {
                case let .modifier(kind, magnitude):
                    let modifier = try #require(after.run.activeModifiers.first { $0.sourceKey == event.sourceKey && $0.effect == kind })
                    #expect(modifier.magnitude == magnitude)
                    #expect(modifier.expiresAt == now + event.durationSeconds)
                case .coinsSeconds(let seconds):
                    let expected = GameState.coinReward(seconds: seconds, player: before, content: content, economy: economy)
                    #expect(abs(after.run.coins - before.run.coins - expected) < 1e-6 * max(1, expected))
                case .evolveBestUnit:
                    #expect(after.run.units == before.run.units, "el evento no muta el tablero: lo planea")
                    #expect(gameState.pendingBoardChanges.contains { $0.origin == .eventStartup })
                case .grantUnit(let below):
                    guard case .arrival(let typeId)? = gameState.pendingBoardChanges.first(where: { $0.origin == .eventBlanqueo })?.kind else {
                        Issue.record("\(event.id) no planeó una llegada")
                        continue
                    }
                    #expect(content.tiers.type(id: typeId)?.tier == max(1, before.run.maxTierReached - below))
                case .callVisitor(let script):
                    #expect(content.visitors.script(id: script) != nil)
                }
            }
        }
    }
```

`FisuEvolutionTests/LocalizationCompletenessTests.swift`, el caso `.events` de `keys(in:)`:

```swift
            case .events:
                return content.events.events.flatMap { [$0.titleKey, $0.phraseKey] }
```

Y `git rm FisuEvolutionTests/EventSchedulingTests.swift` (sus casos viven en
`EventsRuntimeTests`: `emptyDrawRetriesSoon`, `startupNeedsSomeoneWhoCanEvolve`,
`applicability`, y en `EventSchedulerTests.tierAndApplicability`).

En `Tools/v2/test_catalogo.py`, un test más en `CatalogoTests`:

```python
    def test_quitar_borra_y_queda_canonico_y_frena_ante_una_clave_que_no_existe(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = Path(tmp) / "Localizable.xcstrings"
            destino.write_text(catalogo.LOCALIZABLE.read_text(encoding="utf-8"), encoding="utf-8")
            catalogo.quitar(["splash.tip.merge"], destino)
            self.assertTrue(catalogo.es_canonico(destino))
            self.assertNotIn("splash.tip.merge", json.loads(destino.read_text(encoding="utf-8"))["strings"])
            antes = destino.read_text(encoding="utf-8")
            with self.assertRaises(SystemExit):
                catalogo.quitar(["no.existe"], destino)
            self.assertEqual(destino.read_text(encoding="utf-8"), antes, "no escribe nada si frena")
```

- [ ] **Step 2: Verlos fallar**

Run: `python3 -m unittest discover -s Tools/v2 -p 'test_*.py' -v` → ERROR (`quitar` no existe).
Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/EventsRuntimeTests -only-testing:FisuEvolutionTests/EventsContentTests`.
Expected: no compila (`events.event(id:)`, `startEvent`, `engagementAutorun`).

- [ ] **Step 3: `catalogo.py quitar`**

En `Tools/v2/catalogo.py`, la línea de uso del docstring suma
`    Tools/v2/catalogo.py quitar <clave> [<clave> …]`, y después de `aplicar`:

```python
def quitar(claves, ruta=LOCALIZABLE):
    ruta = Path(ruta)
    if not es_canonico(ruta):
        sys.exit(f"✋ {ruta.name} no está en el formato canónico: no se escribe nada (trampa 29)")
    catalogo = json.loads(ruta.read_text(encoding="utf-8"))
    faltan = [clave for clave in claves if clave not in catalogo["strings"]]
    if faltan:
        sys.exit(f"✋ no existen: {faltan}")
    for clave in claves:
        del catalogo["strings"][clave]
    ruta.write_text(serializar(catalogo), encoding="utf-8")
    print(f"{ruta.name}: {len(claves)} claves borradas")
```

y en `main`, antes del `print(__doc__)`:

```python
    if argumentos[:1] == ["quitar"] and len(argumentos) > 1:
        quitar(argumentos[1:])
        return 0
```

- [ ] **Step 4: `events.json` schema 2**

`FisuEvolution/Resources/Config/events.json` entero (pesos, tiers y cooldowns de los 10 nuevos son
la primera mano; los de los 8 viejos, los de la v1):

```json
{
  "schemaVersion": 2,
  "firstEventAfterSeconds": 900,
  "intervalSeconds": 900,
  "intervalJitterSeconds": 300,
  "resumeGraceSeconds": 60,
  "retryWhenNoneApplicableSeconds": 30,
  "events": [
    {"id": "plan_platita", "polarity": "positive", "durationSeconds": 60, "weight": 12, "minTier": 2, "cooldownSeconds": 1800,
     "titleKey": "event.plan_platita.title", "phraseKey": "event.plan_platita.phrase", "presenters": ["npc_ministro"],
     "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 3}], "escapes": []},
    {"id": "startup_comprada", "polarity": "positive", "durationSeconds": 0, "weight": 8, "minTier": 5, "cooldownSeconds": 2700,
     "titleKey": "event.startup_comprada.title", "phraseKey": "event.startup_comprada.phrase", "presenters": ["npc_conductor"],
     "effects": [{"kind": "evolveBestUnit"}], "escapes": []},
    {"id": "devaluacion", "polarity": "negative", "durationSeconds": 90, "weight": 16, "minTier": 3, "cooldownSeconds": 900,
     "titleKey": "event.devaluacion.title", "phraseKey": "event.devaluacion.phrase", "presenters": ["npc_ministro"],
     "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 0.5}], "escapes": [{"kind": "video"}]},
    {"id": "blanqueo", "polarity": "positive", "durationSeconds": 0, "weight": 4, "minTier": 9, "cooldownSeconds": 5400,
     "titleKey": "event.blanqueo.title", "phraseKey": "event.blanqueo.phrase", "presenters": ["npc_ministro"],
     "effects": [{"kind": "grantUnit", "tiersBelowFrontier": 3}], "escapes": []},
    {"id": "home_banking", "polarity": "negative", "durationSeconds": 60, "weight": 14, "minTier": 4, "cooldownSeconds": 1200,
     "titleKey": "event.home_banking.title", "phraseKey": "event.home_banking.phrase", "presenters": ["npc_vendedor"],
     "effects": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 2}], "escapes": [{"kind": "video"}]},
    {"id": "inversion_alienigena", "polarity": "positive", "durationSeconds": 30, "weight": 3, "minTier": 20, "cooldownSeconds": 7200,
     "titleKey": "event.inversion_alienigena.title", "phraseKey": "event.inversion_alienigena.phrase", "presenters": ["sp_alien_investor"],
     "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 5}], "escapes": []},
    {"id": "corralito", "polarity": "negative", "durationSeconds": 45, "weight": 8, "minTier": 6, "cooldownSeconds": 2400,
     "titleKey": "event.corralito.title", "phraseKey": "event.corralito.phrase", "presenters": ["npc_ministro"],
     "effects": [{"kind": "modifier", "effect": "spendingFrozen", "magnitude": 1}], "escapes": [{"kind": "video"}]},
    {"id": "aguinaldo", "polarity": "positive", "durationSeconds": 0, "weight": 8, "minTier": 7, "cooldownSeconds": 5400,
     "titleKey": "event.aguinaldo.title", "phraseKey": "event.aguinaldo.phrase", "presenters": ["npc_sindicalista"],
     "effects": [{"kind": "coinsSeconds", "seconds": 300}], "escapes": []},
    {"id": "campeones", "polarity": "positive", "durationSeconds": 60, "weight": 5, "minTier": 4, "cooldownSeconds": 3600,
     "titleKey": "event.campeones.title", "phraseKey": "event.campeones.phrase", "presenters": ["npc_conductor"], "scene": "champions",
     "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 4}], "escapes": []},
    {"id": "liquidacion", "polarity": "positive", "durationSeconds": 60, "weight": 8, "minTier": 3, "cooldownSeconds": 1800,
     "titleKey": "event.liquidacion.title", "phraseKey": "event.liquidacion.phrase", "presenters": ["npc_vendedor"], "scene": "sale",
     "effects": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 0.5}], "escapes": []},
    {"id": "feriado_puente", "polarity": "positive", "durationSeconds": 60, "weight": 10, "minTier": 2, "cooldownSeconds": 1500,
     "titleKey": "event.feriado_puente.title", "phraseKey": "event.feriado_puente.phrase", "presenters": ["npc_sindicalista"],
     "effects": [{"kind": "modifier", "effect": "tapMultiplier", "magnitude": 3}], "escapes": []},
    {"id": "lluvia_paquetes", "polarity": "positive", "durationSeconds": 60, "weight": 8, "minTier": 5, "cooldownSeconds": 1800,
     "titleKey": "event.lluvia_paquetes.title", "phraseKey": "event.lluvia_paquetes.phrase", "presenters": ["npc_puntero"],
     "effects": [{"kind": "modifier", "effect": "packageRateMultiplier", "magnitude": 10}], "escapes": []},
    {"id": "paro_general", "polarity": "negative", "durationSeconds": 30, "weight": 8, "minTier": 6, "cooldownSeconds": 2400,
     "titleKey": "event.paro_general.title", "phraseKey": "event.paro_general.phrase", "presenters": ["npc_sindicalista"],
     "effects": [{"kind": "modifier", "effect": "passiveMultiplier", "magnitude": 0}],
     "escapes": [{"kind": "fee", "feeSeconds": 120}, {"kind": "video"}]},
    {"id": "apagon", "polarity": "negative", "durationSeconds": 45, "weight": 8, "minTier": 5, "cooldownSeconds": 2400,
     "titleKey": "event.apagon.title", "phraseKey": "event.apagon.phrase", "presenters": ["npc_vecina"],
     "scene": "blackout", "candleStep": 0.07,
     "effects": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 0.3}], "escapes": [{"kind": "video"}]},
    {"id": "hiperinflacion", "polarity": "mixed", "durationSeconds": 60, "weight": 6, "minTier": 8, "cooldownSeconds": 3600,
     "titleKey": "event.hiperinflacion.title", "phraseKey": "event.hiperinflacion.phrase", "presenters": ["npc_ministro"],
     "effects": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 2},
                 {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 3}],
     "escapes": [{"kind": "video", "removes": ["spawnCostMultiplier"]}]},
    {"id": "cepo", "polarity": "negative", "durationSeconds": 60, "weight": 6, "minTier": 6, "cooldownSeconds": 3600,
     "titleKey": "event.cepo.title", "phraseKey": "event.cepo.phrase", "presenters": ["npc_ministro"],
     "effects": [{"kind": "modifier", "effect": "spawnCostMultiplier", "magnitude": 1.5},
                 {"kind": "callVisitor", "script": "arbolito_blue"}],
     "escapes": [{"kind": "video"}]},
    {"id": "piquete", "polarity": "negative", "durationSeconds": 90, "weight": 8, "minTier": 5, "cooldownSeconds": 2400,
     "titleKey": "event.piquete.title", "phraseKey": "event.piquete.phrase", "presenters": ["npc_vecina"],
     "effects": [{"kind": "modifier", "effect": "packageRateMultiplier", "magnitude": 0}], "escapes": [{"kind": "video"}]},
    {"id": "ola_calor", "polarity": "negative", "durationSeconds": 45, "weight": 10, "minTier": 3, "cooldownSeconds": 1500,
     "titleKey": "event.ola_calor.title", "phraseKey": "event.ola_calor.phrase", "presenters": ["npc_vecina"],
     "effects": [{"kind": "modifier", "effect": "tapMultiplier", "magnitude": 0.5}], "escapes": [{"kind": "video"}]}
  ]
}
```

- [ ] **Step 5: La carga y lo que se va**

`GameContentLoader.swift`: `let events: EventsConfig` pasa a `let events: EventCatalog` (y su
`decode`); antes del `return`, **después** de validar `visitors` (T7):

```swift
        do {
            try events.validate(
                visitorIDs: Set(visitors.visitors.map(\.id)),
                scriptIDs: Set(visitors.scripts.map(\.id))
            )
        } catch {
            throw GameError.contentInvalid(file: "events.json", reason: "\(error)")
        }
```

`ContentConfigs.swift`: se borra `struct EventsConfig` entero (con lo que le sumaron E1 T8, T11,
T13 y T15). `ContentSystems.swift`: se borra desde `// MARK: - Eventos argentinizados (bible §1)`
hasta la línea antes de `// MARK: - Boosts`. `GameState+Bonus.swift`: se borra la sección
`// MARK: Eventos (F5 — bible §1)` entera (`scheduleNextEvent`, `fireEventIfDue`,
`eventIsApplicable`, `handleEventRoll`, `postponeOverdueEvent`, `escapeActiveEvent` y lo que haya
quedado de `placeGrantedUnit`): todo vive ahora en `+Events`.

- [ ] **Step 6: `GameState+Events.swift`**

```swift
import EconomyKit
import Foundation

/// Los eventos v2 (PLAN-v2 E4) enganchados a la partida. El motor es puro
/// (`EventScheduler`, `EventPlanner`); acá se resuelve lo que necesita la
/// partida y se aplica. El reloj es de juego activo y vive en el save
/// (`meta.engagement.events`): cerrar la app ya no reinicia la espera y el
/// background no cuenta.
extension GameState {
    /// El evento del banner. E4b lo reemplaza por el chip con la cara del presentador.
    struct ActiveEvent: Equatable, Identifiable {
        let id: String
        let phraseKey: String
        let polarity: EventCatalog.Polarity
        let endsAt: TimeInterval
        let escapes: [EventCatalog.Escape]
    }

    /// Lo que dura el banner de un evento sin duración (Aguinaldo, Startup, Blanqueo).
    static let instantEventBannerSeconds: TimeInterval = 6

    /// Lo llama `advanceEngagement` con el delta del tick (juego activo, con tope).
    /// Durante la fase obligatoria del tutorial no corre.
    func advanceEvents(delta: TimeInterval) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let due = EventScheduler.advance(&player.meta.engagement.events, delta: delta, catalog: content.events)
        self.player = player
        if due { fireDueEvent(now: Date().timeIntervalSince1970) }
    }

    /// Toma el que la Vecina adelantó (si sigue elegible) o sortea. Un sorteo vacío
    /// reintenta pronto sin gastar el intervalo (E1 T11).
    func fireDueEvent(now: TimeInterval) {
        guard let content, var player else { return }
        // Lo aplicable se resuelve ANTES: el sorteo no puede leer `self` mientras
        // `rng` está prestado como `inout`.
        let applicable = Set(content.events.events.filter(eventIsApplicable).map(\.id))
        let immune = ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now)
        guard let event = EventScheduler.takeDue(
            catalog: content.events, state: &player.meta.engagement.events,
            maxTier: player.run.maxTierReached, isImmune: immune,
            isApplicable: { applicable.contains($0.id) }, rng: &rng
        ) else {
            EventScheduler.retrySoon(state: &player.meta.engagement.events, catalog: content.events)
            self.player = player
            return
        }
        EventScheduler.markFired(event, state: &player.meta.engagement.events, catalog: content.events, rng: &rng)
        self.player = player
        startEvent(event, now: now)
    }

    /// Aplica un evento: sus modificadores (`event.<id>`), su plata por `grant`, su
    /// intención de tablero por el embudo de E1 y el anuncio. E4b lo llama cuando
    /// el presentador llega a escena.
    func startEvent(_ event: EventCatalog.Event, now: TimeInterval) {
        guard let content, var player, let tower else { return }
        let application = EventPlanner.apply(event, state: player, tiers: content.tiers, now: now)
        player.run.activeModifiers.removeAll { $0.sourceKey == event.sourceKey }
        player.run.activeModifiers += application.modifiers
        self.player = player
        if application.coinsSeconds > 0 {
            grant(.coinsSeconds(application.coinsSeconds), source: event.sourceKey, now: now)
        }
        if let player = self.player {
            let change: BoardChange? = switch application.boardIntent {
            case .evolveBestUnit:
                BoardChangePlanner.planEvolve(state: player, tower: tower, tiers: content.tiers,
                                              floorTable: content.floorTable, origin: .eventStartup)
            case .grantUnit(let typeId):
                BoardChangePlanner.planArrival(typeId: typeId, state: player, tower: tower, tiers: content.tiers,
                                               floorTable: content.floorTable, origin: .eventBlanqueo)
            case nil:
                nil
            }
            if let change { enqueueBoardChange(change) }
        }
        activeEvent = ActiveEvent(
            id: event.id, phraseKey: event.phraseKey, polarity: event.polarity,
            endsAt: now + max(event.durationSeconds, Self.instantEventBannerSeconds), escapes: event.escapes
        )
        audio?.play(.event)
        effectsVersion += 1
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(event.id)")
    }

    /// El banner se va cuando el evento termina. Lo llama `flushHUD`.
    func expireActiveEvent(now: TimeInterval) {
        if let active = activeEvent, now >= active.endsAt { activeEvent = nil }
    }

    /// Puede pasar AHORA: el Aguinaldo pide pasivo, la Startup alguien que crezca
    /// solo, el Blanqueo lugar en su piso, y los paquetes que E5 ya los entregue.
    func eventIsApplicable(_ event: EventCatalog.Event) -> Bool {
        guard let content, let player, let tower else { return false }
        return event.effects.allSatisfy { effect in
            switch effect {
            case .modifier(let modifierEffect, _):
                return modifierEffect != .packageRateMultiplier || Self.grantableRewardKinds.contains(.package)
            case .coinsSeconds:
                return IncomeTicker.basePassivePerSecond(
                    state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy
                ) > 0
            case .evolveBestUnit:
                return BoardChangePlanner.planEvolve(
                    state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .eventStartup
                ) != nil
            case .grantUnit(let below):
                guard let type = EventPlanner.grantedUnitType(tiersBelowFrontier: below, state: player, tiers: content.tiers)
                else { return false }
                return BoardChangePlanner.planArrival(
                    typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                    floorTable: content.floorTable, origin: .eventBlanqueo
                ) != nil
            case .callVisitor:
                // El llamado es un plus: si el visitante no puede venir, el evento igual pasa.
                return true
            }
        }
    }

    /// Lo que cuesta la cuota de un evento ahora, en plata.
    func eventFee(id: String) -> Double? {
        guard let feeSeconds = content?.events.event(id: id)?.escapes.first(where: { $0.kind == .fee })?.feeSeconds
        else { return nil }
        return feeSeconds * coinsPerProductionSecond
    }

    func eventFeeText(id: String) -> String {
        CoinFormatter.string(from: eventFee(id: id) ?? 0)
    }

    /// Salir de un evento por una de sus salidas. La cuota se cobra; el video ya se
    /// miró (lo llama la vista al terminar); gratis es gratis.
    @discardableResult
    func escapeEvent(
        id: String,
        via kind: EventCatalog.Escape.Kind,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> Bool {
        guard let content, let event = content.events.event(id: id),
              let escape = event.escapes.first(where: { $0.kind == kind }),
              var player,
              player.run.activeModifiers.contains(where: { $0.sourceKey == event.sourceKey && $0.isActive(at: now) })
        else { return false }
        if kind == .fee {
            let fee = eventFee(id: id) ?? 0
            guard player.run.coins >= fee else { return false }
            player.run.coins -= fee
        }
        player.run.activeModifiers = EventPlanner.escape(escape, of: event, from: player.run.activeModifiers)
        self.player = player
        if activeEvent?.id == id, !player.run.activeModifiers.contains(where: { $0.sourceKey == event.sourceKey }) {
            activeEvent = nil
        }
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        Log.economy.info("event escaped: \(id) via \(kind.rawValue)")
        return true
    }

    /// La Obra social del Médico corta los negativos en curso (no los mixtos).
    func cutNegativeEvents(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, var player else { return }
        player.run.activeModifiers = EventPlanner.cutNegatives(player.run.activeModifiers, catalog: content.events)
        self.player = player
        if let active = activeEvent, active.polarity == .negative { activeEvent = nil }
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
    }

    /// Al volver a la app, un evento vencido no dispara en la cara (E1 T8 lo llama
    /// desde `handleScenePhase`). Con el reloj de juego, el background no lo mueve:
    /// lo que se corre es el que ya estaba por salir.
    func postponeOverdueEvent(now: TimeInterval) {
        guard let content, var player else { return }
        EventScheduler.applyResumeGrace(state: &player.meta.engagement.events, catalog: content.events)
        self.player = player
    }

    /// Lo que viene, y queda anotado: es lo que va a salir (la Vecina chusma).
    func peekUpcomingEvent() -> EventCatalog.Event? {
        guard let content, var player else { return nil }
        let now = Date().timeIntervalSince1970
        let applicable = Set(content.events.events.filter(eventIsApplicable).map(\.id))
        let event = EventScheduler.peekUpcoming(
            catalog: content.events, state: &player.meta.engagement.events,
            maxTier: player.run.maxTierReached,
            isImmune: ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now),
            isApplicable: { applicable.contains($0.id) }, rng: &rng
        )
        self.player = player
        scheduleSave()
        return event
    }
}
```

`GameState+Engagement.swift`:

```swift
import EconomyKit
import Foundation

/// Los relojes de engagement (PLAN-v2 E4): colgados del tick, que sólo corre con
/// la escena activa (E1 T8) y trae el delta con tope. E4b suma visitantes y el
/// escenario; E5, paquetes y colchón. Todos acá, en este orden.
extension GameState {
    func advanceEngagement(delta: TimeInterval) {
        advanceEvents(delta: delta)
    }

    #if DEBUG
    /// Las puertas de test del engagement, colgadas de UNA línea del bootstrap:
    /// cada épica suma la suya acá y no vuelve a abrir `GameState.swift`.
    func applyEngagementFixtures(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let id = Self.fixtureValue("--uitest-event=", in: arguments) {
            debugStartEvent(id: id)
        }
    }

    /// El valor de un argumento `--uitest-algo=<valor>`.
    static func fixtureValue(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
    #endif
}
```

- [ ] **Step 7: `GameState.swift` (🔥, cinco toques)**

1. `var activeEvent: EventManager.ActiveEvent?` → `var activeEvent: ActiveEvent?` (el comentario
   de arriba queda: "Lo escribe `+Events`: el evento que arranca y el que vence").
2. Se borran `nextEventAt` y `eventLastFired` con su comentario ("El scheduler de eventos vive
   entero en `+Bonus`"), y en su lugar:

```swift
    /// Los motores de engagement (eventos; E4b visitantes; E5 paquetes y colchón)
    /// corren solos en la app real. Bajo XCTest arrancan apagados, y bajo
    /// `--uitest*` también salvo `--uitest-engagement` (`+Debug`): un evento que
    /// nace en medio de un test ajeno le tapa coordenadas (el criterio de
    /// `tutorialLessonsAutorun`).
    @ObservationIgnored var engagementAutorun =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
```

3. En `tick(delta:)` (el de E1 T8), justo antes de `advanceCelebrations(...)`:

```swift
        advanceEngagement(delta: min(delta, IncomeTicker.deltaClampThreshold))
```

4. En `flushHUD()`, `fireEventIfDue(now: now)` → `expireActiveEvent(now: now)`.
5. En el bootstrap: se borra `scheduleNextEvent(from: Date().timeIntervalSince1970)` (el reloj
   vive en el save), y al final del bloque `#if DEBUG` de fixtures (`finishBootstrap` desde
   E1 T5), después del último `if ProcessInfo…contains(…)`:

```swift
            applyEngagementFixtures()
```

- [ ] **Step 8: `+Debug`, el panel y el banner**

`GameState+Debug.swift`, en `applyLaunchArgumentDefaults`, junto al bloque que apaga las lecciones:

```swift
        if arguments.contains(where: { $0.hasPrefix("--uitest") }), !arguments.contains("--uitest-engagement") {
            engagementAutorun = false
        }
```

y en `#if DEBUG`:

```swift
    /// Un evento arrancado ya mismo, con su efecto real. Los eventos salen cada
    /// 15–20 min de juego: sin esta puerta no se pueden ni fotografiar ni probar.
    func debugStartEvent(id: String) {
        guard let event = content?.events.event(id: id) else { return }
        startEvent(event, now: Date().timeIntervalSince1970)
    }
```

El cuerpo de `debugStartCorralito()` (E1 T13) pasa a `debugStartEvent(id: "corralito")` (el
fixture `--uitest-corralito` y `CorralitoTests` lo siguen usando). En `debugResetSave`, junto a los
otros payloads: `activeEvent = nil`.

`DebugPanelView.swift`, en la sección de herramientas, después de "Simular 4 h offline":

```swift
                    Menu("Disparar un evento") {
                        ForEach(gameState.content?.events.events ?? []) { event in
                            Button(event.id) { gameState.debugStartEvent(id: event.id) }
                        }
                    }
                    .accessibilityIdentifier("debug.event.start")
```

`EventBannerView.swift` entero:

```swift
import SwiftUI

/// El banner del evento activo: la frase, cuánto falta y sus salidas. Accesible
/// para daltónicos: además del color lleva ícono direccional y texto — nunca
/// sólo color. Vive hasta que E4b lo reemplace por el chip con la cara del
/// presentador.
struct EventBannerView: View {
    let event: GameState.ActiveEvent
    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads
    @State private var now = Date()
    @State private var watching = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(LocalizedStringKey(event.phraseKey))
                    .font(Tokens.body)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if remainingSeconds > 0 {
                    Text(verbatim: "\(remainingSeconds)s")
                        .font(Tokens.caption)
                        .monospacedDigit()
                }
            }
            // El id va en la parte de texto y no en el contenedor: un id en un
            // contenedor pisa el de sus hijos (trampa 9a-bis) y los botones de
            // abajo desaparecerían del árbol.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("hud.event")
            if !event.escapes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(event.escapes, id: \.kind) { escape in
                        escapeButton(escape)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            let fill = tint.opacity(0.92)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(fill.deepened(0.3), lineWidth: 2)
                )
        }
        .foregroundStyle(Color("PaletteInk"))
        .padding(.horizontal, 16)
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private func escapeButton(_ escape: EventCatalog.Escape) -> some View {
        switch escape.kind {
        case .video:
            if watching {
                ProgressView()
                    .frame(height: 36)
            } else {
                ActionPill(titleKey: "event.escape.video", systemImage: "play.fill",
                           tint: Color("PaletteGreen"), identifier: "event.escape") {
                    watching = true
                    Task {
                        if await ads.showRewarded(for: .visitor) {
                            gameState.escapeEvent(id: event.id, via: .video)
                        }
                        watching = false
                    }
                }
            }
        case .fee:
            ActionPill(titleKey: "event.escape.fee \(gameState.eventFeeText(id: event.id))", systemImage: "banknote.fill",
                       tint: Color("PaletteOrange"), identifier: "event.escape.fee") {
                gameState.escapeEvent(id: event.id, via: .fee)
            }
        case .free:
            ActionPill(titleKey: "event.escape.free", systemImage: "xmark",
                       tint: Color("PaletteBlue"), identifier: "event.escape.free") {
                gameState.escapeEvent(id: event.id, via: .free)
            }
        }
    }

    private var tint: Color {
        switch event.polarity {
        case .positive: Color("PaletteGreen")
        case .negative: Color("PalettePink")
        case .mixed: Color("PaletteOrange")
        }
    }

    private var symbol: String {
        switch event.polarity {
        case .positive: "arrow.up.circle.fill"
        case .negative: "arrow.down.circle.fill"
        case .mixed: "arrow.up.arrow.down.circle.fill"
        }
    }

    private var remainingSeconds: Int {
        max(0, Int(event.endsAt - now.timeIntervalSince1970))
    }
}
```

- [ ] **Step 9: Los textos**

`Tools/v2/claves-pendientes/e4a-t9.json` (las frases del Anexo A sin los números del dato: el
banner y, en E4b, el chip dicen cuánto y cuánto dura):

```json
{
  "event.plan_platita.title": {"es": "Plan Platita", "en": "Plan Platita"},
  "event.plan_platita.phrase": {"es": "¡Plan Platita! Imprimimos alegría para todos. No preguntes de dónde sale.", "en": "Plan Platita! We're printing happiness for everyone. Don't ask where it comes from."},
  "event.startup_comprada.title": {"es": "Startup comprada", "en": "Startup acquired"},
  "event.startup_comprada.phrase": {"es": "¡Última hora! Una big tech te compró la startup. Tu mejor empleado evoluciona gratis.", "en": "Breaking news! A big tech just bought your startup. Your best worker evolves for free."},
  "event.devaluacion.title": {"es": "Devaluación", "en": "Devaluation"},
  "event.devaluacion.phrase": {"es": "Pequeño ajuste técnico: tu plata vale menos por un rato. Es por tu bien.", "en": "A small technical adjustment: your money's worth less for a while. It's for your own good."},
  "event.blanqueo.title": {"es": "Blanqueo", "en": "Capital amnesty"},
  "event.blanqueo.phrase": {"es": "Blanqueo de capitales: apareció un empleado top que siempre estuvo declarado.", "en": "Capital amnesty: a top worker showed up who was totally declared all along."},
  "event.home_banking.title": {"es": "Se cayó el home banking", "en": "Online banking down"},
  "event.home_banking.phrase": {"es": "¡Se cayó el home banking! Hoy sólo efectivo: contratar sale más caro.", "en": "Online banking is down! Cash only today: hiring costs more."},
  "event.inversion_alienigena.title": {"es": "Inversión alienígena", "en": "Alien investment"},
  "event.inversion_alienigena.phrase": {"es": "Inversores de otra galaxia apuestan por vos. No entienden la economía argentina.", "en": "Investors from another galaxy are betting on you. They don't get the local economy."},
  "event.corralito.title": {"es": "Corralito", "en": "Bank freeze"},
  "event.corralito.phrase": {"es": "Corralito express: tu plata está, pero no la podés tocar. ¿Te suena?", "en": "Express bank freeze: your money's there, you just can't touch it. Sound familiar?"},
  "event.aguinaldo.title": {"es": "Aguinaldo", "en": "Year-end bonus"},
  "event.aguinaldo.phrase": {"es": "¡Aguinaldo conseguido! Disfrutalo antes de que se licúe.", "en": "Year-end bonus secured! Enjoy it before inflation eats it."},
  "event.campeones.title": {"es": "¡Salimos campeones!", "en": "We're the champions!"},
  "event.campeones.phrase": {"es": "¡¡SALIMOS CAMPEONES!! Todo el mundo festeja y la caja se multiplica.", "en": "WE'RE THE CHAMPIONS!! Everybody's celebrating and the till is multiplying."},
  "event.liquidacion.title": {"es": "Liquidación total", "en": "Everything must go"},
  "event.liquidacion.phrase": {"es": "¡Liquidación total! Contratar sale más barato. ¡Llevá, llevá, que no se repite!", "en": "Everything must go! Hiring is cheaper. Get it while it lasts!"},
  "event.feriado_puente.title": {"es": "Feriado puente", "en": "Long weekend"},
  "event.feriado_puente.phrase": {"es": "Feriado puente por decreto: cada toque vale más. Descansar es trabajar.", "en": "Long weekend by decree: every tap is worth more. Resting is working."},
  "event.lluvia_paquetes.title": {"es": "Lluvia de paquetes", "en": "Package rain"},
  "event.lluvia_paquetes.phrase": {"es": "¡Llegaron los bolsones! Lluvia de paquetes: andá recogiendo, muchachos.", "en": "The gift bags are here! It's raining packages: start picking them up, folks."},
  "event.paro_general.title": {"es": "Paro general", "en": "General strike"},
  "event.paro_general.phrase": {"es": "¡Paro general! Hoy no produce ni el loro. Pagá la cuota o esperá que se negocie.", "en": "General strike! Not even the parrot is working. Pay the dues or wait for the talks."},
  "event.apagon.title": {"es": "Apagón", "en": "Blackout"},
  "event.apagon.phrase": {"es": "¡Se cortó la luz en todo el barrio! Prendé velitas tocando a tus empleados.", "en": "Blackout in the whole neighborhood! Light candles by tapping your workers."},
  "event.hiperinflacion.title": {"es": "Hiperinflación", "en": "Hyperinflation"},
  "event.hiperinflacion.phrase": {"es": "Hiperinflación controlada: contratar sale más caro, pero la caja rinde más.", "en": "Controlled hyperinflation: hiring costs more, but the till pays more."},
  "event.cepo.title": {"es": "Cepo cambiario", "en": "Currency clamp"},
  "event.cepo.phrase": {"es": "Cepo cambiario: contratar sale más caro. Pero aparece un señor que cambia al blue.", "en": "Currency clamp: hiring costs more. But a guy shows up who swaps on the black market."},
  "event.piquete.title": {"es": "Piquete en la autopista", "en": "Highway blockade"},
  "event.piquete.phrase": {"es": "Piquete en la autopista: no llegan los paquetes. Yo vi todo desde el balcón.", "en": "Highway blockade: no packages getting through. I saw it all from my balcony."},
  "event.ola_calor.title": {"es": "Ola de calor", "en": "Heat wave"},
  "event.ola_calor.phrase": {"es": "¡Ola de calor! Nadie quiere moverse: tus toques valen menos.", "en": "Heat wave! Nobody wants to move: your taps are worth less."},
  "event.escape.fee %@": {"es": "Pagar la cuota · %@", "en": "Pay the dues · %@"},
  "event.escape.free": {"es": "Sacarlo", "en": "Remove it"}
}
```

`Tools/v2/claves-pendientes/e4a-t9.quitar`:

```
event.aguinaldo.flavor
event.blanqueo.flavor
event.cayo_mercado_pago.flavor
event.corralito.flavor
event.devaluacion.flavor
event.inversion_alienigena.flavor
event.plan_platita.flavor
event.startup_comprada.flavor
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4a-t9.json` → `38 claves nuevas`;
`Tools/v2/catalogo.py quitar $(cat Tools/v2/claves-pendientes/e4a-t9.quitar)` → `8 claves borradas`.

- [ ] **Step 10: Verde, UI y oráculo**

Run: `python3 -m unittest discover -s Tools/v2 -p 'test_*.py' -v` → `Ran 4 tests … OK`.
Run: `grep -rn "EventManager\|EventsConfig\|nextEventAt\|eventLastFired\|fireEventIfDue\|handleEventRoll\|escapeActiveEvent" FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
→ sin resultados. `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/EventsRuntimeTests -only-testing:FisuEvolutionTests/EventsContentTests -only-testing:FisuEvolutionTests/EffectContractTests -only-testing:FisuEvolutionTests/LifecycleTests -only-testing:FisuEvolutionTests/BoardChangeProducersTests -only-testing:FisuEvolutionTests/CorralitoTests -only-testing:FisuEvolutionTests/ContentSystemsTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/CelebrationWiringTests -only-testing:FisuEvolutionTests/AudioWiringTests`
→ PASS. UI: `-only-testing:FisuEvolutionUITests/CorralitoUITests` → PASS (el banner sigue con
`event.escape`). A mano en el simulador propio: panel de debug → "Disparar un evento" →
`paro_general` (banner rosa con "Pagar la cuota" y "Liberar con video"), `hiperinflacion`
(naranja; el video deja el ×3) y `campeones`. Después `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 11: Commit**

```bash
git rm FisuEvolutionTests/EventSchedulingTests.swift
git add FisuEvolution/Resources/Config/events.json FisuEvolution/Managers/GameContentLoader.swift \
  FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Managers/ContentSystems.swift \
  FisuEvolution/Game/State/GameState+Bonus.swift FisuEvolution/Game/State/GameState+Events.swift \
  FisuEvolution/Game/State/GameState+Engagement.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolution/UI/HUD/EventBannerView.swift \
  FisuEvolution/UI/DebugPanelView.swift Tools/v2/catalogo.py Tools/v2/test_catalogo.py \
  FisuEvolutionTests/EventsRuntimeTests.swift FisuEvolutionTests/EventsContentTests.swift \
  FisuEvolutionTests/ContentSystemsTests.swift FisuEvolutionTests/LocalizationCompletenessTests.swift \
  FisuEvolutionTests/EffectContractTests.swift FisuEvolutionTests/LifecycleTests.swift \
  FisuEvolutionTests/BoardChangeProducersTests.swift FisuEvolutionTests/CorralitoTests.swift
# + el catálogo, o los dos archivos de Tools/v2/claves-pendientes/e4a-t9.*, según la ola
git diff --cached --stat
git commit -m "feat(eventos): el juego corre sobre los eventos v2 — 18 eventos compuestos con reloj de juego"
```

---

### Task 10: Cierre de E4a

**Objetivo:** la verificación de punta a punta del motor y la documentación que deja a E4b
arrancando sin leer esta sesión. La hace el controlador.

- [ ] **Step 1: Oráculo completo**

Run: `Tools/v2/oraculo.sh completo`.
Expected: `VERDE`, con `RewardSpecTests`, `EventModifierEffectsTests`, `EngagementStageStateTests`,
`EventCatalogTests`, `EventSchedulerTests`, `EventPlannerTests`, `VisitorsConfigTests`,
`VisitorSchedulerTests`, `VisitPlannerTests`, `VisitorsContentTests`, `RewardGrantTests`,
`EventsRuntimeTests` y `EventsContentTests` en la salida. `rojos-declarados.txt` no cambió por E4a.
El `pacing-sim` da lo mismo que antes de E4a (no modela eventos ni visitantes).

- [ ] **Step 2: Los escenarios a mano**

1. Panel de debug → "Disparar un evento" → los 18: cada uno muestra su frase, los negativos su
   salida por video, el paro también la cuota; la Startup y el Blanqueo pasan por el embudo (la
   evolución o la llegada se ven a la vista). Lluvia y Piquete arrancan igual por la puerta de
   debug, pero no salen en el sorteo hasta E5.
2. Con `--uitest-engagement` y el tiempo del dato bajado a mano en un build local (no se
   commitea): el primer evento a los 15 min de juego; Home y volver → no dispara en la cara.
3. Matar la app en medio de la espera y volver: el reloj siguió donde estaba.

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e4.md`: la tabla por tarea con su commit, y el porqué de cada default
   de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: "E4a — el motor de visitantes y eventos v2": `RewardSpec` + `grant` como único
     camino de premios; el reloj de eventos en el save y en juego activo; los 18 eventos
     compuestos; `visitors.json` con los 26 guiones (todavía sin escena).
   - **§5**: los defaults de las dudas que el dueño no cambió.
   - **§7**: las trampas nuevas — "un guion o evento que da algo que `grantableRewardKinds` no
     tiene no se ofrece: E5/E6 los habilitan sumándolo ahí"; "los textos de visitantes llevan
     `%N$@` en el VALOR y se llenan con `VisitCopy`; un `%` suelto en un texto con datos se come
     el carácter de al lado"; "el motor de eventos se llama `EventCatalog` (el `EventsConfig` de
     la v1 ya no existe)"; las que aparezcan.
   - **§9**: este plan y la sesión.
3. Journal AVO al día y `LOCK` liberado.

- [ ] **Step 4: Commit de docs**

```bash
git add Docs/SESION-*-v2-e4.md Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e4): cierre de E4a — el motor de visitantes y eventos v2"
```

---

## Lo que E4a le deja a E4b y a otras épicas

- **E4b** arranca con todo esto en la punta: `RewardSpec` + `GameState.grant` +
  `grantableRewardKinds`; `isCalmMoment` y `coinsPerProductionSecond`; `VisitorsConfig`,
  `VisitorScheduler` y `VisitPlanner` (con `VisitOption.Kind` y los ids fijos de opción);
  `VisitCopy`; `EventCatalog`/`EventScheduler`/`EventPlanner` (con `running(_:catalog:now:)` y
  `lightCandle(_:event:now:)` listos para los chips y el Apagón); `GameState.startEvent(_:now:)`,
  `escapeEvent(id:via:now:)`, `peekUpcomingEvent()`; el gancho `advanceEngagement(delta:)` y
  `applyEngagementFixtures()`; `engagementAutorun`; y el banner con las tres salidas, que E4b T4
  borra.
- **E5** (paquetes, colchón, ruleta):
  - para entregar un Paquete o un giro: sumar `.package` / `.wheelSpin` a
    `GameState.grantableRewardKinds` y su caso en `grant` (hoy devuelven 0). Con eso salen solos
    los guiones del Puntero (acto y bolsón), del Sindicalista (asado), de la Influencer (novio),
    de la Vecina (favor) y del Conductor (ruleta), y los eventos Lluvia de Paquetes y Piquete
    (`eventIsApplicable` mira la misma lista);
  - el `PackageScheduler` lee `ModifierMath.factor(…, effect: .packageRateMultiplier, now:)`:
    ×10 en la Lluvia, ×0 en el Piquete;
  - sus relojes van en `advanceEngagement(delta:)` y su estado en `meta.engagement` (mismo
    patrón que T3: `init(from:)` con `decodeIfPresent` y su regla en `resolve`);
  - sus puertas de test, en `applyEngagementFixtures`.
- **E6**: `.autoTap`, `.nextOfflineMultiplier`, `.nextDailyMultiplier` y `.extraSlots` en
  `grantableRewardKinds` y en `grant`; las ofertas y la tienda describen su contenido con
  `RewardSpec`.
- **E2a** (si todavía no lo hizo): la Obra social del Médico es
  `grant([.eventImmunity(seconds: 1800), .coinsSeconds(900)], source: "career.junior_doctor")` +
  `cutNegativeEvents()`. Si E2a ya creó `.eventImmunity`, E4a T2 lo reusó (su paso 0).
- **E2b**: la palanca de plata de los visitantes es `visitors.json` `coinsSecondsScale`; la de
  los eventos, sus `coinsSeconds` y magnitudes. Los relojes (600 / 240–360 / 180 / 900–1200)
  están en los dos JSON. El simulador tiene que modelarlos (PLAN-v2 §6, "las fuentes nuevas
  acortan el juego"); ver la duda 1.
- **E7b**: `isCalmMoment` es el predicado de los cortes naturales; los videos de visitantes y
  escapes van por `RewardedPlacement.visitor` (ya cableado en el banner).
- **E9**: E4a no suma mecánicas visibles por sí sola (el banner es el de siempre); las lecciones
  de visitante, chip de evento y Álbum las declara E4b.
- **E10**: nada nuevo para App Review en E4a (el escape por video del banner ya existía desde E1
  T13, ahora por la unidad `visitor`).

## Para el dueño / dudas

Cosas que la spec deja abiertas o que el código contradice. **Ninguna frena**: la ejecución sigue
con el default anotado hasta que el dueño diga otra cosa.

1. **La plata de los visitantes rompe el presupuesto de E2a.** Una visita cada ~5 min con
   propinas de S(900) a S(2400) son ~12 visitas por hora de juego: del orden de 2–3 h de
   producción regaladas por hora, contra el tope de `RewardBudgetTests` (los premios sin anuncios
   no pasan el 12 % de la producción diaria). **Default:** se implementan los números del Anexo A
   tal cual (están en el JSON) y la palanca es `visitors.json` `coinsSecondsScale` (hoy 1); E2b
   la calibra con el simulador junto con la frecuencia.
2. **`coinReward` no se muda a `RewardMath.coinPayout`.** PLAN-v2 lo pone en los cimientos de
   E4, pero E2a mueve los premios a `RewardScale` (EconomyKit) antes que E4. **Default:** `grant`
   llama a `GameState.coinReward` (E1 T14); si E2a ya creó `RewardScale`, `grant` es el único
   lugar que hay que cambiar para usarlo.
3. **El del Arbolito cambia 1 ORO por S(5400)**, que es ~135 veces peor que el ancla de la tienda
   (1 h ≈ 90 ORO). **Default:** el Anexo tal cual (es sátira del blue, y el ORO de prestigio es
   escaso al principio); E2b lo revisa con el resto.
4. **"Nunca deja menos de 2"** se leyó como "la torre nunca queda con menos de 2 empleados", y
   además nunca se lleva al último de su tipo (`VisitPlanner.minimumUnitsLeft`).
5. **"Toda visita es de suma positiva o neutra"** se leyó así: ignorarla nunca cuesta; lo que se
   lleva gente paga por lo menos lo que vale reponerla; lo que cobra plata da algo a cambio. Pagar
   la multa (S(180) por ×1,25 durante 3 min) pierde unos S(135) netos: queda como trueque
   opcional (está el video y está ignorarla). Si se quiere que **cada** opción sea ≥ 0, el sello
   pasa a ×2 por 3 min (dato).
6. **Una salida de visitante que ya no tiene a quién llevarse** (el empleado se fusionó entre
   aceptar y su turno) se descarta sin compensar: la plata se dio al aceptar. Es a favor del
   jugador y raro.
7. **Los especiales visitan sólo si ya los conseguiste** (si no, el Álbum dejaría de tener
   sorpresas). Vale también para el Arbolito que llama el Cepo: sin él, el Cepo es sólo el +50 %.
8. **Cinco guiones y dos eventos esperan a E5**: los que dan Paquetes o giros (acto, bolsón,
   asado, novio, favor, ruleta) y Lluvia/Piquete no se ofrecen hasta que E5 sepa entregarlos.
9. **Los botones de los popups son genéricos** (`visit.option.<tipo>`, once claves) y no
   `visit.<guion>.btn.<opción>` como propone el Anexo: serían ~50 claves repitiendo "Aceptar".
   El globo y el texto del popup sí son por guion.
10. **El reloj de eventos pasa a juego activo y al save**, con el primero a los 15 min de juego.
    En la v1 era reloj de pared en memoria, reiniciado en cada arranque: quien jugaba de a ratos
    cortos no veía nunca un evento. Se conserva la gracia de 60 s al volver (E1 T8).
11. **El ×2 con video de un modificador alarga, no potencia**: ×1,5 por 10 min pasa a ×1,5 por
    20 min (un −30 % al doble sería −60 %).
12. **Los 10 eventos nuevos llevan pesos, tiers y cooldowns de primera mano** (en el JSON); la
    regla de la v1 "los malos pesan por lo menos lo que los buenos" se conserva (78 contra 66).
13. **Las frases del Anexo pierden sus números** ("×3 por un minuto", "30 % off") o los
    interpolan del dato: la regla de `IAPCopy` (HANDOFF §5) es que un número nunca se escribe a
    mano en un texto.
