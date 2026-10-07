# E5a — Paquete de la Aduana, El Colchón y Ruleta, el motor: sorteos, relojes y premios · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que la 2.0 tenga, puros en EconomyKit y validados al arrancar, los tres premios de E5
—el Paquete de la Aduana (cae cada 2 min de juego, hasta 2 esperando, y trae a un empleado que
FisuJobs vende con lugar), El Colchón (cada ~8 min de juego, se abre con video, plata, ORO o un
Paquete) y la Ruleta (10 segmentos con la tabla visible, 6 giros por video por día, giro extra a
12 ORO, "repetir premio")— con su estado en `meta.engagement` y el juego ya entregándolos por el
único punto de premios (`GameState.grant`) y por el embudo de cambios del tablero de E1.

**Architecture:** todo lo que decide vive en EconomyKit, en `Prizes/`: `PackagesConfig` +
`PackageScheduler` + `PackageRoller` (cuándo cae y a quién trae), `TreasuresConfig` +
`TreasureScheduler` + `TreasureRoller` (el colchón), `WheelConfig` + `WheelState` + `WheelRoller`
(la tabla efectiva, el día y los cupos), y `WeightedDraw` (el sorteo con pesos que comparten los
tres). La app sólo engancha: los relojes cuelgan de `advanceEngagement` (E4a), los premios salen
por `grant` (E4a T8), el paquete llega por `BoardChangePlanner.planArrival` + `enqueueBoardChange`
(E1) y la ruleta se guarda en el acto. Lo que se ve —la ruleta girando, los chips, el popup del
colchón, las cajas en el tablero, Regalos— es E5b (`2026-10-07-v2-e5b-aduana-colchon-ruleta.md`).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · StoreKit 2 (`Storefront`) · EconomyKit (SPM puro, `Sendable`) · Swift Testing ·
XcodeGen (el `.xcodeproj` no se versiona).

**Fuente:** `Docs/PLAN-v2.md` §4 "E5 — Paquete de la Aduana + El Colchón + Ruleta", §2 (decisiones
cerradas del dueño: Paquete, Ruleta, El Colchón, El Colchón frecuencia, Loot boxes, Escala del
ORO; **no se re-litigan**), la tabla de premios de E2a (Colchón y Ruleta), "Cimientos compartidos"
(`RewardSpec`, `meta.engagement`), §0.1 (agentes concurrentes) y el Anexo A (los guiones que dan
Paquetes o giros). Lo que el código contradice o la spec deja abierto está en "Para el dueño /
dudas", con un default que no frena.

**Rama de la épica:** `v2/e5-premios`, desde `version-2`. Cada tarea sale de su punta en un
worktree propio (`Agent(isolation: "worktree")`, PLAN-v2 §0.1) y el controlador integra de a una.

### Por qué E5 va en dos planes

E5 son tres sistemas con un motor y una cara cada uno. En un solo documento serían ~16 tareas. Se
parte como E3 y E4, por **qué decide contra qué se ve**:

- **E5a (este plan) — el motor:** los tres configs con su validador, los sorteos y los relojes
  puros, el estado en `meta.engagement`, el contenido (`packages.json`, `treasures.json`,
  `wheel.json`) y los tres sistemas andando en la partida sin UI propia (se prueban por unit y por
  las puertas de debug). **No toca ningún archivo caliente ni el catálogo de strings**: corre al
  lado de E4b.
- **E5b — lo que se ve:** la ruleta (`Canvas`, ease-out de 3,8 s, ticks), los chips y el popup del
  colchón, las hojas raíz, las cajas en el tablero y la apertura del paquete en el turno del
  tablero, la tarjeta de Regalos, las lecciones y la notificación `wheel_ready`.

E5b depende de E5a en todo: arranca cuando E5a cerró.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build (una `var` que no se muta, también). **Nada de `Timer` para lógica de juego**
  (regla 2): los relojes del paquete y del colchón avanzan con el delta del tick
  (`advanceEngagement`, E4a T9), con tope de 2 s y sólo con la escena activa (E1 T8). Afuera no
  corren: "sin acumular offline" sale gratis.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo** de la app o de sus tests (Swift, JSON de `Resources/Config`), en el mismo paso en
  que se crea. Un archivo nuevo de EconomyKit no lo pide.
- **E5a no suma strings.** Todo texto de E5 es de E5b (snapshots `Tools/v2/claves-pendientes/e5b-tN.json`).
  Si una tarea de E5a necesitara uno, para con `NEEDS_CONTEXT`.
- **Data-driven**: cadencias, topes, ventanas, razones, tablas, pesos, cupos y costos viven en
  `packages.json`, `treasures.json` y `wheel.json`, con validador al arrancar (patrón
  `GameContentLoader.validate`). En código sólo quedan constantes con nombre y su porqué.
- **EconomyKit no conoce UI, `Bundle`, `StoreKit` ni `Date()`**: recibe el delta, el día ya
  formateado, el RNG y los predicados resueltos. `EconomyKitTests` no tiene recursos: sus tests
  usan fixtures sintéticos (`fxPackages`, `fxTreasures`, `fxWheel`, más los `fx*` de siempre);
  los hechos de los JSON reales se pinean del lado de la app.
- **Todo estado nuevo vive en `meta.engagement`** (`EngagementState`, E1 T4) con
  `decodeIfPresent ?? default` y su regla en `resolve`: **no se sube el schema** (v6). Trampa
  E7a: un `Codable` con `var x = 0` no decodifica un JSON sin esa clave; todo lo que se persiste
  lleva su `init(from:)`.
- **Un premio se entrega por un solo lugar**: `GameState.grant(_:multiplier:source:now:)` (E4a
  T8). E5 suma `.package` y `.wheelSpin` a `grantableRewardKinds` y su caso en `grant`; nadie
  acredita plata, ORO ni cofres a mano. La plata en minutos la cotiza `grant` (`coinsSeconds`,
  que E2a T11 y E4a duda 2 apoyan sobre `RewardScale`): **E5 no llama a `coinPayout` directo**.
- **Ningún cambio del tablero que no hizo el jugador se aplica en el acto**: el paquete trae a su
  empleado por el embudo `BoardChange` de E1 (`planArrival` → `enqueueBoardChange` → turno a la
  vista → `placeUnit`), con `Origin.package`. Llegar no es contratar: no toca la curva ni
  `totalHiresEver`.
- **Lo mostrado es lo sorteado**: la tabla que la UI muestra (ruleta, colchón) sale de la misma
  función que sortea (`WheelConfig.effectiveSegments`, `TreasuresConfig.odds`). Apple 3.1.1.
- **Nada nuevo corre bajo XCTest ni bajo `--uitest*` salvo que el test lo pida**: los relojes
  respetan `engagementAutorun` (E4a T9) y la fase obligatoria del tutorial
  (`tutorialPhaseActive`: durante el núcleo no nace ningún paquete ni colchón, PLAN-v2 E9). Las
  puertas de test son `--uitest-packages=N`, `--uitest-mattress` y `--uitest-wheel-spins=N`, en
  `applyEngagementFixtures` (E4a T9: una sola línea del bootstrap, no se vuelve a abrir
  `GameState.swift`).
- Código nuevo limpio y con pocos comentarios (regla del dueño: prolijidad antes que
  comentarios); los heredados no se borran por deporte, pero **el que miente se corrige** en el
  commit que lo vuelve mentira (los "E5 suma `.package`" de E4a, sobre todo).
- **Commits en español, estilo `feat(premios): …` / `feat(paquetes): …` / `feat(ruleta): …`, SIN
  `Co-Authored-By`.** Staging selectivo por archivo y `git diff --cached --stat` antes de cada
  commit. Un comando git por llamada a Bash (guard de la sesión).
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración con
  `oraculo.sh rapido` → `Docs/SESION-<fecha>-v2-e5.md` → las cuatro ediciones de
  `Docs/HANDOFF.md` (§4, §5, §7, §9) → journal AVO y latido del `LOCK`. Ningún subagente toca
  `Docs/`, `handoffs/`, el journal ni `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

**El oráculo del run** juzga cada integración:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
```

- Termina en 0 (`VERDE`) sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`. E5 no
  declara rojos nuevos. Los tests nuevos entran solos (corre las suites enteras): **así suma E5
  sus tests al oráculo**, sin tocar `oraculo.sh`. Un VERDE con la misma cuenta que antes de sumar
  tests no probó nada (HANDOFF §6).
- `rapido` al cerrar T1–T5, T7 y T8; `completo` al cerrar T6 (los eventos Lluvia y Piquete
  entran al sorteo y cinco guiones de visitantes despiertan) y la épica (T9).
- ⚠️ El `pacing-sim` no modela paquetes, colchón ni ruleta (es trabajo de E2b): su número no se
  mueve con E5a. Si se mueve, se busca por qué antes de integrar.

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…")
swift test --package-path Packages/EconomyKit --filter "PackageRollerTests|PackageSchedulerTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE (sin "()" no corre nada)
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e5-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e5" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e5" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/PackageRuntimeTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y de `-only-testing:`). Mirá la salida. Ante un rojo en masa, antes
de culpar al código: `uptime`, `ps aux | grep '[x]codebuild'` y las rutas de los `SwiftCompile`
en el log (trampas 16, 33 y 44). La máquina está cargada (hasta 3 agentes compilando): un build
lento no es un error.

## Las referencias de PLAN-v2 E5, verificadas contra el árbol (`d22eb7a`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E5 |
|---|---|---|
| `packages.json`, `treasures.json`, `wheel.json` | no existen (`Resources/Config/` tiene 17 JSON, ninguno de E5) | T5 los crea; los tipos, T1–T3 |
| `PackageScheduler`, `PackageRoller`, `WheelRoller` | no existen | T1 y T3, en `EconomyKit/Prizes/` |
| "Coloca con `placeGrantedUnit` generalizado, que no toca el contador de contrataciones" | `placeGrantedUnit` es `private` en `GameState+Bonus.swift:237-254`: muta el tablero en el acto, sube la frontera y "el regalo se pierde con log" con el piso lleno. **E1 T12 lo borra**; el camino generalizado es `BoardChangePlanner.planArrival(…, origin:)` + `TowerActions.placeUnit` (E1 T7) + `enqueueBoardChange` (E1 T9) | T6 usa el embudo con `Origin.package` (lo suma T6). Ver duda 9 |
| "candidatos = tipos contratables con lugar" | la regla de "contratable" vive en `GameState+Hiring.swift:333-362` (`jobState`, `private`): visto en la run, piso abierto, compuerta `TowerActions.canHire` (`TowerActions.swift:173-195`), lugar libre | T1 la escribe pura (`PackageRoller.eligibleTypes`) y T6 pinea que da lo mismo que `jobRows.filter { .hirable }` |
| "Ventana de los 4 tiers más altos elegibles con pesos 1, r, r², r³ (r = 2): el tope sale el 6,7 %" | — | T1: el tope pesa 1 y cada tier de abajo `r` veces más; 1/15 = 6,67 % |
| "El permanente 'mejor proveedor' baja r a 1,8 / 1,6 / 1,4" | la tienda de ORO no existe (E6) | T1: `tierRatioByBestSupplierLevel` en el dato; T6 lee el nivel 0 hasta E6 |
| "Un tipo nunca visto pasa por la revelación de E1" | `confirmWithoutGesture` → `presentResolution` (E1 T10) | con candidatos = contratables (vistos) no pasa nunca; la red de E1 queda igual. Duda 1 |
| `packageRateMultiplier` (Lluvia ×10, Piquete ×0) | lo crea **E4a T2** en `ActiveModifier.Effect`; `ModifierMath.factor` en `ActiveModifier.swift:39-44` | T6 se lo pasa al reloj; los eventos Lluvia y Piquete entran solos al sorteo (`eventIsApplicable` mira `grantableRewardKinds`) |
| `RewardedPlacement.treasure` | ya existe (E7a): `FeatureFlags.swift:28-29`, y `.wheel` en `:26-27`; `rewarded(for:)` `:129-141` cae a `rewardedGifts`; `ads.json` trae `rewardedWheel`/`rewardedTreasure` en `null` | E5b los usa; no hay que sumar nada |
| "Si el cofre no tiene nada que dar, su peso pasa a plata" | `canOpenChest` (`GameState+Chests.swift:150-157`) pregunta `ChestRoller.hasSomethingToGive(owned:unlocked:skins:)` contra `chestUnlockedCharacterTypes` (`:134-143`) | T3 (`effectiveSegments`) y T8 (`wheelChestHasSomethingToGive`, sin cofres pendientes) |
| giro extra con ORO "apagado en Bélgica y Australia" | `AdsRemoteConfig.restrictedStorefronts` + `isRestricted(storefront:)` (`AdsRemoteConfig.swift:126-134`); `ads.json` trae `["BEL", "AUS"]`; `AdsRemoteConfigLoader.current()` (`:99-113`) lee caché o bundle sin red. **Nadie lee `Storefront.current` ni usa el loader en la app** | T8 crea `LootBoxGate` (PLAN lo ponía en E6, que lo reusa para el cofre por ORO). Duda 8 |
| "Reset por día calendario (como el diario)" | `DailyRewardManager.dayString(for:calendar:)` (`ContentSystems.swift:358-361`), "yyyy-MM-dd" en el huso del dispositivo | T3 recibe el día como `String`; T8 lo arma con esa función |
| "giro extra con ORO a 12 ORO, tope 6 por día" + "Un solo `MetaState.spendOro`" | `MetaState.spendOro` (`PlayerState.swift:483-489`, E1 T4), suma a `stats.oroSpentEver` | T8 paga por ahí |
| `meta.engagement` con `packages`, `treasures`, `wheel` | `EngagementState.swift` (E1 T4) es un struct vacío de 14 líneas; E3b T9 le suma `sharedMoments` y E4a T3 `visitors` y `events`, con su `init(from:)` | T4 suma los tres de E5 al mismo `init` y al mismo `resolve` |
| PLAN-v2 E1: "RunState: … buzón de paquetes, colchón y visitante" | el plan de E1 (duda 1) los mandó a `meta.engagement` para no subir a v7 | viven en `meta`: sobreviven a la reencarnación (duda 3) |
| `Canvas`, ticks hápticos, `UI/Wheel/WheelView` | `HapticsManager.Pattern` no tiene un tick (`HapticsManager.swift:13-19`); `sfx_wheel_tick.caf` está en `Resources/Audio` sin caso en `AudioManager.SFX` (`AudioManager.swift:14-30`) | E5b T1 |
| "Vive en Regalos y en la columna lateral; la presenta el Conductor" | `GiftsView` (`UI/Gifts/GiftsView.swift`, 919 líneas) no navega; la columna es de E7b (🔒 del dueño: pisa la multitud en iPhone); el Conductor es `npc_conductor`, guion `conductor_ruleta` (E4a T7) | E5b: Regalos (T4), la hoja raíz con `openWheel()` para el Conductor y la columna (T2) |
| `OddsDisclosureView` "compartida por la ruleta, el cofre por ORO y el Colchón" | no existe; PLAN la pone en E6 | la crea E5b T1 (E6 la reusa) |

## Lo que E5 hereda de E1, E4a y E3b (todavía no está en el árbol)

E5 corre "luego" (PLAN-v2 §0.1), al lado de E4 **por tarea**. Las APIs se citan como las definen
sus planes; cada tarea dice de cuál depende y su paso 0 lo comprueba con `grep`. Si al despachar
una tarea su API no está en la punta de `version-2`, el agente para con `NEEDS_CONTEXT`: no se
inventa.

| API | La define | La usa |
|---|---|---|
| `RunState.raiseFrontier(to:) -> Bool` (`@discardableResult`) | E1 T3 ✅ en el árbol | T1 (tests) |
| `MetaState.engagement: EngagementState`, `MetaState.spendOro(_:)` | E1 T4 ✅ en el árbol | T4, T8 |
| `BoardChange`, `BoardChange.Origin` (`String`), `BoardChangePlanner.planArrival(typeId:state:tower:tiers:floorTable:origin:)`, `TowerActions.placeUnit` | E1 T7 | T6 |
| `GameState.enqueueBoardChange(_:)`, `pendingBoardChanges`, `beginNextBoardChange()`, `confirmBoardChange(id:)`, `discardBoardChange(_:)` | E1 T9 | T6 |
| la escena confirma `.arrival` (`confirmWithoutGesture` → `presentResolution`) | E1 T10 | T6 (y la apertura de E5b T3) |
| `discardBoardChange` con `switch` exhaustivo sobre `Origin` | E1 T14 | T6 suma `.package` |
| `GameState.isSceneActive`, el tick con `guard isSceneActive` y delta con tope | E1 T8 | T6, T7 (por `advanceEngagement`) |
| `EngagementState.sharedMoments` + su `init(from:)` | E3b T9 | T4 |
| `RewardSpec` (con `.package(Int)`, `.wheelSpin(Int)`, `.skinChest(Int)`, `.oro(Int)`, `.coinsSeconds(Double)`, `.modifier(effect:magnitude:seconds:)`), `RewardSpec.Kind`, `validate()` | E4a T1 | T2, T3, T5–T8 |
| `ActiveModifier.Effect.packageRateMultiplier` | E4a T2 | T6 |
| `VisitorsState`, `EventsState` en `EngagementState` (con su `init(from:)` y su `resolve`) | E4a T3 | T4 |
| `VisitorsConfig` con el guion `conductor_ruleta` (`wheelSpin(1)`, `dailyCap` 1) y los que dan `package(1)` | E4a T5, T7 | T6, T8 (despiertan solos) |
| `GameState.grant(_:multiplier:source:now:) -> Double`, `grantableRewardKinds`, `coinsPerProductionSecond` | E4a T8 | T6–T8 |
| `GameState+Engagement.swift`: `advanceEngagement(delta:)`, `applyEngagementFixtures(arguments:)`, `fixtureValue(_:in:)`; `GameState.engagementAutorun` | E4a T9 | T6–T8 |
| `EventsRuntimeTests.applicability` ("los paquetes esperan a E5"), `RewardGrantTests.notYetGrantable` / `grantableKinds` | E4a T8, T9 | T6, T8 los actualizan |
| `GameState.coinPayout(minutes:player:content:)` (E2a T7) y `RewardScale` (E2a T1, T11) | E2a | **ninguna directo**: la plata de la ruleta y el colchón son `coinsSeconds` y la cotiza `grant` (E4a duda 2 y E2a "Lo que deja a E4"); el día que `grant` pase a `RewardScale`, E5 cobra igual sin tocar nada |
| `GameState.chestUnlockedCharacterTypes`, `ChestRoller.hasSomethingToGive` | ✅ en el árbol (`GameState+Chests.swift:134-157`) | T8 |

## El premio y el sorteo en una página

```
tick (escena activa, delta ≤ 2 s) → advanceEngagement (E4a T9)
   ├─ advanceEvents (E4a) · advanceStage/Visitors (E4b)
   ├─ advancePackages ── PackageScheduler.advance(rate = ModifierMath.factor(…, .packageRateMultiplier))
   │                       120 s de juego por paquete · hasta 2 esperando (con 2, el reloj espera)
   └─ advanceTreasures ─ TreasureScheduler.advance: 480 s de juego · 1 esperando como mucho

tocar un paquete ─► openPackage()
   │  candidatos = PackageRoller.eligibleTypes (visto · piso abierto · compuerta · lugar)
   │  vacío → .full ("LLENO"), el paquete se queda
   ▼  PackageRoller.roll: ventana de 4 tiers, pesos 1·r·r²·r³ (r = 2: el tope sale 6,7 %)
BoardChangePlanner.planArrival(origin: .package) → enqueueBoardChange → turno a la vista (E1)
   │  ya no entra en su turno → discardBoardChange → refundPackage (vuelve al buzón)
   ▼
placeUnit: no cuenta como contratación                         ← E5b T3: la caja se abre ahí

colchón esperando ─(video, .treasure)─► openMattress() ─► TreasureRoller.roll ─► grant(prize.rewards)
                    └─(2º video)─► openExtraMattress()   (uno por colchón)

ruleta ─► spinWheel(.bonus | .video | .oro) — el día rueda (DailyRewardManager.dayString)
   │  .oro: storefrontAllows (LootBoxGate) · cupo 6/día · spendOro(12)
   │  tabla = WheelConfig.effectiveSegments(chestHasSomethingToGive:)  ← la misma que se muestra
   ▼  WheelRoller.roll → grant(segment.reward) → persistNow  (el premio, ANTES de animar)
repeatWheelPrize() ─(2º video)─► grant(el mismo premio), una vez por giro

grant (E4a T8) ─ .package → meta.engagement.packages.waiting += n   (pasa el tope: ya está ganado)
               └ .wheelSpin → meta.engagement.wheel.bonusSpins += n
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/WeightedDraw.swift` | **nuevo** — el sorteo con pesos y `PrizeOdds` (la tabla que se muestra) | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesConfig.swift` | **nuevo** — `packages.json` como tipo, con su validador | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesState.swift` | **nuevo** — el reloj y el buzón | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/PackageEngine.swift` | **nuevo** — `PackageScheduler` y `PackageRoller` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresConfig.swift` | **nuevo** — `treasures.json` y su validador | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresState.swift` | **nuevo** — el reloj, si espera y los "otro colchón" que quedan | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasureEngine.swift` | **nuevo** — `TreasureScheduler` y `TreasureRoller` | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelConfig.swift` | **nuevo** — `wheel.json`, la tabla efectiva y el validador | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelState.swift` | **nuevo** — el día, los cupos usados, los giros regalados y el "repetir" | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelRoller.swift` | **nuevo** — `WheelSpinSource`, cupos, gastar y sortear | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` | `packages`, `treasures` y `wheel` con su `init(from:)` y su `resolve` | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` | `Origin.package` (archivo de E1 T7) | 6 |
| `FisuEvolution/Resources/Config/packages.json`, `treasures.json`, `wheel.json` | **nuevos** — los números de PLAN-v2 | 5 |
| `FisuEvolution/Managers/GameContentLoader.swift` | carga y valida los tres | 5 |
| `FisuEvolution/Game/State/GameState+Packages.swift` | **nuevo** — el reloj, abrir, "LLENO" y devolver | 6 |
| `FisuEvolution/Game/State/GameState+Treasures.swift` | **nuevo** — el reloj, abrir y "otro colchón" | 7 |
| `FisuEvolution/Game/State/GameState+Wheel.swift` | **nuevo** — el día, la disponibilidad, girar, repetir | 8 |
| `FisuEvolution/Managers/LootBoxGate.swift` | **nuevo** — el azar con ORO, apagado donde la tienda lo prohíbe | 8 |
| `FisuEvolution/Game/State/GameState+Rewards.swift` | `.package` (T6) y `.wheelSpin` (T8) entregables | 6, 8 |
| `FisuEvolution/Game/State/GameState+Engagement.swift` | los dos relojes y las tres puertas de test | 6, 7, 8 |
| `FisuEvolution/Game/State/GameState+BoardChanges.swift` | `discardBoardChange`: `.package` devuelve el paquete | 6 |
| tests | EK: `PackageRollerTests`, `PackageSchedulerTests`, `PackagesConfigTests`, `TreasureSchedulerTests`, `TreasureRollerTests`, `TreasuresConfigTests`, `WheelTableTests`, `WheelStateTests`, `WheelRollerTests`, `EngagementPrizesStateTests`; app: `PrizesContentTests`, `PackageRuntimeTests`, `MattressRuntimeTests`, `WheelRuntimeTests`, `LootBoxGateTests` (+ `RewardGrantTests` y `EventsRuntimeTests` de E4a, retocados) | 1–8 |

## Orden, olas y paralelismo

**Archivos calientes** (un solo dueño por ola, PLAN-v2 §0.1): `GameState.swift`,
`RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`, `GameState+Bonus.swift`,
`SettingsView.swift`, `PlayerState.swift`, `TowerActions.swift`, `project.yml`,
`Localizable.xcstrings`. **E5a no toca ninguno.** **Tibios** (otra épica los toca en su ventana):
`EngagementState.swift` (E3b T9, E4a T3, E6), `BoardChange.swift` (E1 T7, E2a T6/T9, E4a T6),
`GameContentLoader.swift` (E11 T2, E3a T9, E4a T7/T9, E6), `GameState+Rewards.swift` (E4a T8, E6),
`GameState+Engagement.swift` (E4a T9, E4b T1/T2), `GameState+BoardChanges.swift` (E1 T9/T14, E2a
T9/T14, E4a T6), `RewardGrantTests.swift` y `EventsRuntimeTests.swift` (E4a).

| T | Qué | Archivos | 🔥 / tibios | Depende de |
|---|---|---|---|---|
| 1 | el paquete, puro | `WeightedDraw.swift`, `PackagesConfig.swift`, `PackagesState.swift`, `PackageEngine.swift`, `PackagesEngineTests.swift` | — | E1 T3 ✅ — **puede correr ya** |
| 2 | el colchón, puro | `TreasuresConfig.swift`, `TreasuresState.swift`, `TreasureEngine.swift`, `TreasuresEngineTests.swift` | — | T1 (`WeightedDraw`), **E4a T1** |
| 3 | la ruleta, pura | `WheelConfig.swift`, `WheelState.swift`, `WheelRoller.swift`, `WheelEngineTests.swift` | — | T1, **E4a T1** |
| 4 | estado en `meta.engagement` | `EngagementState.swift`, `EngagementPrizesStateTests.swift` | tibio: `EngagementState.swift` | T1–T3, **E3b T9**, **E4a T3** |
| 5 | el contenido | los tres JSON, `GameContentLoader.swift`, `PrizesContentTests.swift` | tibio: loader | T1–T3; **E4a T7/T9** (dueños previos del loader) |
| 6 | el paquete en la partida | `GameState+Packages.swift`, `+Rewards`, `+Engagement`, `+BoardChanges`, `BoardChange.swift`, `PackageRuntimeTests.swift`, `RewardGrantTests.swift`, `EventsRuntimeTests.swift` | tibios: los siete | T4, T5; **E1 T9, T10, T14**; **E4a T2, T6, T8, T9** |
| 7 | el colchón en la partida | `GameState+Treasures.swift`, `+Engagement`, `MattressRuntimeTests.swift` | tibio: `+Engagement` | T6 (comparten `+Engagement`) |
| 8 | la ruleta en la partida | `GameState+Wheel.swift`, `LootBoxGate.swift`, `+Rewards`, `+Engagement`, `WheelRuntimeTests.swift`, `LootBoxGateTests.swift`, `RewardGrantTests.swift` | tibios: `+Rewards`, `+Engagement`, `RewardGrantTests` | T7 (comparten `+Engagement`) |
| 9 | cierre | `Docs/` (controlador) | — | todas |

```
Ola 1 (fría, puede ir ya, al lado de E1)   T1 el paquete (EK)
Ola 2 (tras E4a T1)                        T2 el colchón (EK) ║ T3 la ruleta (EK)
Ola 3 (tras E4a T3 y E3b T9)               T4 meta.engagement ║ T5 el contenido (tras E4a T7)
Ola 4 (tras E1 cerrada y E4a T9)           T6 el paquete en la partida        ← rapido + completo
Ola 5                                      T7 el colchón → T8 la ruleta        (comparten +Engagement)
Ola 6                                      T9 cierre
```

**Reglas del paralelismo:**

1. Cada tarea corre en su worktree aislado desde la punta de `v2/e5-premios`, con su DerivedData
   (`build/DD-e5`) y su simulador por UDID, que apaga y borra al terminar. Hasta 3 compilando a
   la vez en todo el run; las tareas puras de EK (T1–T4) no compilan la app salvo en el paso de
   oráculo.
2. **E4 ∥ E5 por tarea.** E5a no toca calientes, así que puede ir en la misma ola que cualquier
   tarea de E4b, salvo que comparta un tibio en la misma ola: T6 no va con E4b T2 (los dos tocan
   `+Engagement`), ni T6–T8 con una tarea de E4a/E4b que esté tocando `+Rewards` o
   `+BoardChanges`.
3. **T6 sale de una `v2/e5-premios` que ya tiene mergeada `version-2` con E1 entera y E4a T9.**
   Su paso 0 lo comprueba; si falta algo, `NEEDS_CONTEXT`.
4. Un agente que necesita un archivo caliente para con `NEEDS_CONTEXT`: E5a no debería
   necesitar ninguno; si pasa, es una señal de que algo del plan cambió.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` (async, **no** throws; repo en memoria) | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| el contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift:33` |
| config/estado sintético de EK | `fxConfig`, `fxEconomy`, `fxType`, `fxTiers`, `fxFloorTable`, `fxState`, `fxStateAndTower`, `fxSlot`, `fxSlots` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` |
| RNG determinista en EK | `SeededRNG(seed:)` | `Fixtures.swift:134` |
| pisos abiertos, frontera y vistos | `debugUnlockFloors(throughTier:)` (sube la frontera), `debugMarkTypesSeen(throughTier:)`, `debugGrantCoins()` | `GameState+Debug.swift:183, 199, 127` |
| reconciliar la torre después de tocar `run.units` | `reconcileTower()` | `GameState.swift:731` |
| las filas de FisuJobs | `jobRows` (`JobRow.State.hirable`) | `GameState+Hiring.swift:110` |
| la fase obligatoria del tutorial | `beginTutorialPhase()`, `tutorialPhaseFinished()` | `GameState+Celebrations.swift:69, 91` |
| un bundle con un JSON cambiado | el patrón de `NotificationsContentTests.loaderRejectsAnUnknownKind` (copiar los JSON a un `.bundle` temporal) | `NotificationsContentTests.swift:32-54` |
| el embudo y la contabilidad (E1) | `beginNextBoardChange()`, `confirmBoardChange(id:)`, `discardBoardChange(_:)` | E1 T9, T14 |
| el motor de E4a | `grant`, `advanceEngagement(delta:)`, `engagementAutorun`, `fixtureValue(_:in:)` | E4a T8, T9 |

La escalera sintética de EK: `a(1) → b(2) → [choice] c_prog/c_law (3) → d(4)`; pisos `f1 {1–2}`
y `f2 {3–4}`, capacidad 5; `fxConfig()` tiene la compuerta apagada (`gateTierDistance` 0).
`fxState` arranca con la frontera en 1 y sólo `a` visto. El tipo base real es `homeless`; los
pisos reales `alley` (1–4), `urban` (5–8), `corporate` (9–12) … `god_realm` (37); capacidad 10
hasta que E2b la pase a 15.

---

### Task 1: El Paquete de la Aduana, puro — a quién trae y cuándo cae

**Objetivo:** el sorteo y el reloj del paquete (PLAN-v2 E5 y §2), puros en EconomyKit, con el
sorteo con pesos que después reusan el colchón y la ruleta. Puede correr ya: sólo depende de lo
que E1 T3 dejó en el árbol.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/WeightedDraw.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesConfig.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesState.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/PackageEngine.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/PackagesEngineTests.swift`

**Interfaces:**
- Consumes: `TowerActions.canHire(tier:maxTierReached:floorTable:config:)`, `TierRepository.concreteTypes`, `TowerState.Floor.firstFreeSlot()`, `RunState.raiseFrontier(to:)` (tests).
- Produces: `public struct PrizeOdds: Sendable, Equatable` (`id: String`, `probability: Double`,
  `init(id:probability:)`); `public enum WeightedDraw` con
  `index<R: RandomNumberGenerator>(weights: [Double], using: inout R) -> Int?` y
  `probabilities(weights: [Double]) -> [Double]`.
- Produces: `public struct PackagesConfig: Codable, Sendable, Equatable` (`schemaVersion`,
  `spawnIntervalSeconds: Double`, `firstPackageAfterSeconds: Double`, `maxWaiting: Int`,
  `windowTiers: Int`, `tierRatioByBestSupplierLevel: [Double]`), `tierRatio(bestSupplierLevel:) -> Double`,
  `enum ValidationError: Error, Equatable { notPositive(String), noRatios, ratioBelowOne(Double) }`, `validate() throws`.
- Produces: `public struct PackagesState: Codable, Sendable, Equatable` (`secondsUntilNext: Double?`,
  `waiting: Int`, `static let initial`, `init(from:)` con `decodeIfPresent`).
- Produces: `PackageScheduler.advance(_ state: inout PackagesState, delta: Double, rateMultiplier: Double, config: PackagesConfig) -> Int`
  (`@discardableResult`, devuelve cuántos cayeron).
- Produces: `PackageRoller.Odds` (`tier`, `typeIds`, `probability`),
  `PackageRoller.eligibleTypes(state:tower:tiers:floorTable:config:) -> [CharacterType]`,
  `odds(eligible:windowTiers:ratio:) -> [Odds]`,
  `roll<R>(eligible:windowTiers:ratio:using:) -> CharacterType?`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/PackagesEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// `packages.json` sintético, con los números de PLAN-v2 E5.
func fxPackages(
    spawnIntervalSeconds: Double = 120,
    firstPackageAfterSeconds: Double = 120,
    maxWaiting: Int = 2,
    windowTiers: Int = 4,
    ratios: [Double] = [2, 1.8, 1.6, 1.4]
) -> PackagesConfig {
    PackagesConfig(
        schemaVersion: 1,
        spawnIntervalSeconds: spawnIntervalSeconds,
        firstPackageAfterSeconds: firstPackageAfterSeconds,
        maxWaiting: maxWaiting,
        windowTiers: windowTiers,
        tierRatioByBestSupplierLevel: ratios
    )
}

@Suite("Paquete de la Aduana: a quién trae")
struct PackageRollerTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// Un tipo por tier, para mirar la ventana sin la torre.
    private func ladder(_ maxTier: Int) -> [CharacterType] {
        (1...maxTier).map { fxType("t\($0)", tier: $0) }
    }

    private func total(_ odds: [PackageRoller.Odds]) -> Double {
        odds.map(\.probability).reduce(0, +)
    }

    private func eligibleIds(_ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable)) -> [String] {
        PackageRoller.eligibleTypes(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, config: fxConfig()
        ).map(\.id)
    }

    @Test("con la ventana entera, el tope sale 1 de cada 15 y el de más abajo 8 de cada 15")
    func theTopTierIsOneInFifteen() {
        let odds = PackageRoller.odds(eligible: ladder(4), windowTiers: 4, ratio: 2)
        #expect(odds.map(\.tier) == [4, 3, 2, 1])
        #expect(abs(odds[0].probability - 1.0 / 15) < 1e-12)
        #expect(abs(odds[3].probability - 8.0 / 15) < 1e-12)
        #expect(abs(total(odds) - 1) < 1e-12)
    }

    @Test("sólo entran los cuatro tiers más altos")
    func onlyTheTopFourTiersEnter() {
        let odds = PackageRoller.odds(eligible: ladder(6), windowTiers: 4, ratio: 2)
        #expect(odds.map(\.tier) == [6, 5, 4, 3])
    }

    @Test("con menos tiers la ventana se achica y sigue sumando 1")
    func aShortWindowStillAddsUp() {
        let odds = PackageRoller.odds(eligible: ladder(2), windowTiers: 4, ratio: 2)
        #expect(odds.map(\.tier) == [2, 1])
        #expect(abs(odds[0].probability - 1.0 / 3) < 1e-12)
        #expect(abs(total(odds) - 1) < 1e-12)
    }

    @Test("los tipos de un mismo tier se reparten su parte")
    func typesOfATierShareItsWeight() {
        let eligible = [fxType("y", tier: 3), fxType("x", tier: 3), fxType("z", tier: 2)]
        let odds = PackageRoller.odds(eligible: eligible, windowTiers: 4, ratio: 2)
        #expect(odds.first?.typeIds == ["x", "y"])
    }

    @Test("el mejor proveedor baja r", arguments: zip([0, 1, 2, 3], [2.0, 1.8, 1.6, 1.4]))
    func bestSupplierLowersTheRatio(level: Int, ratio: Double) {
        #expect(fxPackages().tierRatio(bestSupplierLevel: level) == ratio)
    }

    @Test("cada nivel del mejor proveedor sube la chance del tope; un nivel de más se queda en el último")
    func bestSupplierRaisesTheTop() {
        let config = fxPackages()
        let tops = (0...3).map { level in
            PackageRoller.odds(eligible: ladder(4), windowTiers: 4, ratio: config.tierRatio(bestSupplierLevel: level))[0].probability
        }
        #expect(tops == tops.sorted())
        #expect((tops.last ?? 0) > 0.14)
        #expect(config.tierRatio(bestSupplierLevel: 9) == 1.4)
        #expect(config.tierRatio(bestSupplierLevel: -1) == 2)
    }

    @Test("lo que no se vio en esta run no viene")
    func unseenTypesStayOut() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b"]
        #expect(eligibleIds(fx) == ["a", "b"])
    }

    @Test("un piso lleno saca a los suyos")
    func aFullFloorKeepsItsTypesOut() throws {
        var fx = try fxStateAndTower(units: ["a": 5])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "c_prog", "d"]
        #expect(Set(eligibleIds(fx)) == ["c_prog", "d"])
    }

    @Test("un piso cerrado, también")
    func aLockedFloorKeepsItsTypesOut() throws {
        var fx = try fxStateAndTower(units: ["a": 1], unlockedFloors: ["f1"])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "c_prog", "d"]
        #expect(Set(eligibleIds(fx)) == ["a", "b"])
    }

    @Test("el nodo de carrera no es un empleado: nunca viene")
    func theChoiceNodeNeverComes() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.raiseFrontier(to: 4)
        fx.state.run.seenTypes = ["a", "b", "choice", "c_prog"]
        #expect(!eligibleIds(fx).contains("choice"))
    }

    @Test("sin elegibles no hay sorteo")
    func nothingEligibleRollsNothing() {
        var rng = SeededRNG(seed: 1)
        #expect(PackageRoller.roll(eligible: [], windowTiers: 4, ratio: 2, using: &rng) == nil)
    }

    @Test("el sorteo respeta la tabla: el tope cae cerca del 6,7 %")
    func theRollFollowsTheTable() throws {
        var rng = SeededRNG(seed: 20_261_007)
        let eligible = ladder(4)
        let draws = 15_000
        var tops = 0
        for _ in 0..<draws {
            let pick = try #require(PackageRoller.roll(eligible: eligible, windowTiers: 4, ratio: 2, using: &rng))
            if pick.tier == 4 { tops += 1 }
        }
        let share = Double(tops) / Double(draws)
        #expect(share > 0.055 && share < 0.078, "el tope salió \(share)")
    }
}

@Suite("Paquete de la Aduana: el reloj de juego activo")
struct PackageSchedulerTests {
    let config = fxPackages()

    @Test("el primero cae a los 120 s de juego, y el reloj se rearma")
    func theFirstDropsAfterTwoMinutes() {
        var state = PackagesState.initial
        #expect(PackageScheduler.advance(&state, delta: 119, rateMultiplier: 1, config: config) == 0)
        #expect(PackageScheduler.advance(&state, delta: 1, rateMultiplier: 1, config: config) == 1)
        #expect(state.waiting == 1)
        #expect(state.secondsUntilNext == 120)
    }

    @Test("con dos esperando el reloj se queda quieto: no se acumula")
    func aFullInboxStopsTheClock() {
        var state = PackagesState(secondsUntilNext: 30, waiting: 2)
        #expect(PackageScheduler.advance(&state, delta: 1000, rateMultiplier: 1, config: config) == 0)
        #expect(state == PackagesState(secondsUntilNext: 30, waiting: 2))
    }

    @Test("al llegar al tope, el siguiente arranca un intervalo entero")
    func reachingTheCapRestartsTheInterval() {
        var state = PackagesState(secondsUntilNext: 1, waiting: 1)
        #expect(PackageScheduler.advance(&state, delta: 2, rateMultiplier: 1, config: config) == 1)
        #expect(state.waiting == 2)
        #expect(state.secondsUntilNext == 120)
    }

    @Test("la Lluvia de Paquetes corre el reloj ×10: uno cada 12 s")
    func packageRainRunsTenTimesFaster() {
        var state = PackagesState(secondsUntilNext: 120, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 12, rateMultiplier: 10, config: config) == 1)
    }

    @Test("el Piquete lo frena: ×0 no mueve el reloj")
    func theBlockadeStopsIt() {
        var state = PackagesState(secondsUntilNext: 50, waiting: 0)
        #expect(PackageScheduler.advance(&state, delta: 500, rateMultiplier: 0, config: config) == 0)
        #expect(state.secondsUntilNext == 50)
    }

    @Test("los regalados pasan el tope y el reloj no les saca nada")
    func giftedPackagesCanExceedTheCap() {
        var state = PackagesState(secondsUntilNext: 10, waiting: 5)
        #expect(PackageScheduler.advance(&state, delta: 50, rateMultiplier: 1, config: config) == 0)
        #expect(state.waiting == 5)
    }

    @Test("un delta nulo no mueve nada")
    func aZeroDeltaDoesNothing() {
        var state = PackagesState.initial
        #expect(PackageScheduler.advance(&state, delta: 0, rateMultiplier: 1, config: config) == 0)
        #expect(state == .initial)
    }
}

@Suite("Paquete de la Aduana: el dato")
struct PackagesConfigTests {
    @Test("los números de PLAN-v2 validan")
    func theOwnersNumbersValidate() throws {
        try fxPackages().validate()
    }

    @Test("lo que no puede ser cero, no lo es")
    func zerosAreRejected() {
        #expect(throws: PackagesConfig.ValidationError.notPositive("spawnIntervalSeconds")) {
            try fxPackages(spawnIntervalSeconds: 0).validate()
        }
        #expect(throws: PackagesConfig.ValidationError.notPositive("firstPackageAfterSeconds")) {
            try fxPackages(firstPackageAfterSeconds: 0).validate()
        }
        #expect(throws: PackagesConfig.ValidationError.notPositive("maxWaiting")) {
            try fxPackages(maxWaiting: 0).validate()
        }
        #expect(throws: PackagesConfig.ValidationError.notPositive("windowTiers")) {
            try fxPackages(windowTiers: 0).validate()
        }
    }

    @Test("sin razones, o con una que haría más probable al tope, no carga")
    func ratiosAreChecked() {
        #expect(throws: PackagesConfig.ValidationError.noRatios) { try fxPackages(ratios: []).validate() }
        #expect(throws: PackagesConfig.ValidationError.ratioBelowOne(0.5)) { try fxPackages(ratios: [2, 0.5]).validate() }
    }

    @Test("un buzón escrito antes de E5 decodifica vacío, y uno a medias también")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(PackagesState.self, from: Data("{}".utf8)) == .initial)
        let partial = try JSONDecoder().decode(PackagesState.self, from: Data(#"{"waiting": 2}"#.utf8))
        #expect(partial == PackagesState(secondsUntilNext: nil, waiting: 2))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "PackageRollerTests|PackageSchedulerTests|PackagesConfigTests"`
Expected: no compila (`PackagesConfig` no existe).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/Prizes/WeightedDraw.swift`:

```swift
import Foundation

/// Una fila de la tabla de un premio con azar, tal como se le muestra al
/// jugador (Apple 3.1.1). Sale de la misma tabla con la que se sortea.
public struct PrizeOdds: Sendable, Equatable {
    public let id: String
    public let probability: Double

    public init(id: String, probability: Double) {
        self.id = id
        self.probability = probability
    }
}

/// El sorteo con pesos que comparten el paquete, el colchón y la ruleta: los
/// tres muestran la tabla con la que sortean, así que la cuenta es una sola.
public enum WeightedDraw {
    /// El índice sorteado, o `nil` si no hay ningún peso positivo. Los pesos
    /// negativos cuentan como cero.
    public static func index<R: RandomNumberGenerator>(weights: [Double], using rng: inout R) -> Int? {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return nil }
        var ticket = Double.random(in: 0..<total, using: &rng)
        for (index, weight) in weights.enumerated() where weight > 0 {
            if ticket < weight { return index }
            ticket -= weight
        }
        return weights.lastIndex { $0 > 0 }
    }

    /// Cada peso sobre el total.
    public static func probabilities(weights: [Double]) -> [Double] {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return weights.map { _ in 0 } }
        return weights.map { max(0, $0) / total }
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesConfig.swift`:

```swift
import Foundation

/// `packages.json`: el Paquete de la Aduana (PLAN-v2 E5 y §2). Cae uno cada
/// tanto de juego activo, hasta un tope en espera, y al tocarlo sortea a quién
/// trae entre lo que FisuJobs vende con lugar.
public struct PackagesConfig: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    /// Segundos de juego activo entre dos paquetes.
    public let spawnIntervalSeconds: Double
    /// El primero de una partida (o de un save anterior a E5).
    public let firstPackageAfterSeconds: Double
    /// Cuántos esperan como mucho. Los regalados (visitantes, ruleta, colchón,
    /// ofertas) pueden pasarlo: el tope es del reloj, no del buzón.
    public let maxWaiting: Int
    /// Cuántos tiers elegibles, desde el más alto, entran al sorteo.
    public let windowTiers: Int
    /// La razón r entre un tier y el de arriba (el de abajo pesa r veces más),
    /// por nivel del permanente "mejor proveedor" de la tienda de ORO (E6).
    public let tierRatioByBestSupplierLevel: [Double]

    public init(
        schemaVersion: Int,
        spawnIntervalSeconds: Double,
        firstPackageAfterSeconds: Double,
        maxWaiting: Int,
        windowTiers: Int,
        tierRatioByBestSupplierLevel: [Double]
    ) {
        self.schemaVersion = schemaVersion
        self.spawnIntervalSeconds = spawnIntervalSeconds
        self.firstPackageAfterSeconds = firstPackageAfterSeconds
        self.maxWaiting = maxWaiting
        self.windowTiers = windowTiers
        self.tierRatioByBestSupplierLevel = tierRatioByBestSupplierLevel
    }

    /// La razón de ese nivel; uno fuera de rango se queda en el borde.
    public func tierRatio(bestSupplierLevel: Int) -> Double {
        let index = min(max(0, bestSupplierLevel), tierRatioByBestSupplierLevel.count - 1)
        return tierRatioByBestSupplierLevel[index]
    }

    public enum ValidationError: Error, Equatable {
        case notPositive(String)
        case noRatios
        /// Una razón menor que 1 haría al tope MÁS probable que los de abajo.
        case ratioBelowOne(Double)
    }

    public func validate() throws {
        guard spawnIntervalSeconds > 0 else { throw ValidationError.notPositive("spawnIntervalSeconds") }
        guard firstPackageAfterSeconds > 0 else { throw ValidationError.notPositive("firstPackageAfterSeconds") }
        guard maxWaiting > 0 else { throw ValidationError.notPositive("maxWaiting") }
        guard windowTiers > 0 else { throw ValidationError.notPositive("windowTiers") }
        guard !tierRatioByBestSupplierLevel.isEmpty else { throw ValidationError.noRatios }
        if let low = tierRatioByBestSupplierLevel.first(where: { $0 < 1 }) {
            throw ValidationError.ratioBelowOne(low)
        }
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesState.swift`:

```swift
import Foundation

/// El buzón del Paquete de la Aduana (vive en `meta.engagement`). El reloj es
/// de JUEGO ACTIVO: el background no lo mueve.
public struct PackagesState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta el próximo. `nil` = nunca se programó (partida
    /// nueva o save anterior a E5): el reloj arranca en `firstPackageAfterSeconds`.
    public var secondsUntilNext: Double?
    /// Los que esperan que el jugador los abra.
    public var waiting: Int

    public static let initial = PackagesState()

    public init(secondsUntilNext: Double? = nil, waiting: Int = 0) {
        self.secondsUntilNext = secondsUntilNext
        self.waiting = waiting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        waiting = try container.decodeIfPresent(Int.self, forKey: .waiting) ?? 0
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/PackageEngine.swift`:

```swift
import Foundation

/// El reloj del Paquete de la Aduana. Lo llama el tick, que no corre en
/// segundo plano: afuera no se acumula nada.
public enum PackageScheduler {
    /// Avanza el reloj y devuelve cuántos cayeron. Con el buzón en el tope el
    /// reloj espera; `rateMultiplier` es el `packageRateMultiplier` de los
    /// eventos (×10 la Lluvia, ×0 el Piquete).
    @discardableResult
    public static func advance(
        _ state: inout PackagesState,
        delta: Double,
        rateMultiplier: Double,
        config: PackagesConfig
    ) -> Int {
        guard delta > 0, state.waiting < config.maxWaiting else { return 0 }
        var remaining = (state.secondsUntilNext ?? config.firstPackageAfterSeconds) - delta * max(0, rateMultiplier)
        var dropped = 0
        while remaining <= 0, state.waiting < config.maxWaiting {
            state.waiting += 1
            dropped += 1
            remaining += config.spawnIntervalSeconds
        }
        state.secondsUntilNext = state.waiting < config.maxWaiting ? remaining : config.spawnIntervalSeconds
        return dropped
    }
}

/// A quién trae un paquete. El sorteo es al tocarlo: los candidatos son los que
/// FisuJobs vende con lugar, y entre ellos pesan más los tiers de abajo.
public enum PackageRoller {
    /// Un tier de la ventana con su chance (sus tipos se la reparten parejo).
    public struct Odds: Sendable, Equatable {
        public let tier: Int
        public let typeIds: [String]
        public let probability: Double
    }

    /// Los que un paquete puede traer AHORA: visto en esta run, piso abierto,
    /// compuerta de contratación abierta y lugar libre en su piso. Es la fila
    /// "contratable" de FisuJobs (`GameState.jobState`): un paquete no
    /// espoilea la cadena ni trae a quien no entra.
    public static func eligibleTypes(
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> [CharacterType] {
        tiers.concreteTypes.filter { type in
            let ordinal = floorTable.ordinal(forTier: type.tier)
            return state.run.seenTypes.contains(type.id)
                && state.run.unlockedFloors.contains(floorTable[ordinal].id)
                && TowerActions.canHire(
                    tier: type.tier, maxTierReached: state.run.maxTierReached,
                    floorTable: floorTable, config: config
                )
                && tower.floors.indices.contains(ordinal)
                && tower.floors[ordinal].firstFreeSlot() != nil
        }
    }

    /// La tabla: los `windowTiers` tiers más altos entre los elegibles; el tope
    /// pesa 1 y cada uno de abajo `ratio` veces más (1, r, r², r³).
    public static func odds(eligible: [CharacterType], windowTiers: Int, ratio: Double) -> [Odds] {
        let byTier = Dictionary(grouping: eligible, by: \.tier)
        let window = Array(byTier.keys.sorted(by: >).prefix(max(0, windowTiers)))
        let weights = window.indices.map { pow(ratio, Double($0)) }
        return zip(window, WeightedDraw.probabilities(weights: weights)).map { tier, probability in
            Odds(tier: tier, typeIds: byTier[tier, default: []].map(\.id).sorted(), probability: probability)
        }
    }

    public static func roll<R: RandomNumberGenerator>(
        eligible: [CharacterType],
        windowTiers: Int,
        ratio: Double,
        using rng: inout R
    ) -> CharacterType? {
        let table = odds(eligible: eligible, windowTiers: windowTiers, ratio: ratio)
        guard let pick = WeightedDraw.index(weights: table.map(\.probability), using: &rng),
              let typeId = table[pick].typeIds.randomElement(using: &rng)
        else { return nil }
        return eligible.first { $0.id == typeId }
    }
}
```

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter "PackageRollerTests|PackageSchedulerTests|PackagesConfigTests"`
Expected: PASS — 12 + 7 + 4 tests (uno con 4 argumentos). Después
`swift test --package-path Packages/EconomyKit` entero → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/WeightedDraw.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesConfig.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesState.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/PackageEngine.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/PackagesEngineTests.swift
git diff --cached --stat
git commit -m "feat(paquetes): el Paquete de la Aduana, puro — a quién trae y cuándo cae"
```

(un comando git por llamada a Bash: así lo pide el guard de la sesión.)

---

### Task 2: El Colchón, puro — cuándo aparece y qué trae

**Objetivo:** el colchón de PLAN-v2 E5 y §2 ("aparece cada ~8 min de juego activo", "no se
acumula más de 1", "espera hasta que lo abras", "otro colchón con un 2º video"): el dato con su
validador, el reloj y el sorteo, puros. La tabla visible es la del sorteo.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresConfig.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresState.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasureEngine.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/TreasuresEngineTests.swift`

**Interfaces:**
- Consumes: `RewardSpec` + `validate()` (**E4a T1**), `WeightedDraw`, `PrizeOdds` (T1).
- Produces: `public struct TreasuresConfig: Codable, Sendable, Equatable` (`schemaVersion`,
  `spawnIntervalSeconds`, `firstTreasureAfterSeconds`, `extraOpensPerTreasure: Int`,
  `prizes: [Prize]`), `TreasuresConfig.Prize` (`id`, `weight: Int`, `rewards: [RewardSpec]`,
  `init(id:weight:rewards:)`), `var odds: [PrizeOdds]`,
  `enum ValidationError { outOfRange(String), noPrizes, duplicatePrize(String), badWeight(String), emptyPrize(String), invalidReward(String) }`,
  `validate() throws`.
- Produces: `public struct TreasuresState: Codable, Sendable, Equatable` (`secondsUntilNext: Double?`,
  `waiting: Bool`, `extraOpensLeft: Int`, `static let initial`, `init(from:)`).
- Produces: `TreasureScheduler.advance(_:delta:config:) -> Bool` (`@discardableResult`: apareció
  uno), `TreasureScheduler.markOpened(_:config:)`; `TreasureRoller.roll<R>(_:using:) -> TreasuresConfig.Prize?`.

- [ ] **Step 0: `RewardSpec` está**

Run: `grep -n "public enum RewardSpec" Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift`
Expected: una línea (E4a T1). Si no, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/TreasuresEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// `treasures.json` sintético, con la tabla del plan (60 / 25 / 15).
func fxTreasures(
    spawnIntervalSeconds: Double = 480,
    firstTreasureAfterSeconds: Double = 480,
    extraOpensPerTreasure: Int = 1,
    prizes: [TreasuresConfig.Prize] = [
        .init(id: "coins", weight: 60, rewards: [.coinsSeconds(1200)]),
        .init(id: "package", weight: 25, rewards: [.package(1)]),
        .init(id: "oro", weight: 15, rewards: [.oro(2)]),
    ]
) -> TreasuresConfig {
    TreasuresConfig(
        schemaVersion: 1,
        spawnIntervalSeconds: spawnIntervalSeconds,
        firstTreasureAfterSeconds: firstTreasureAfterSeconds,
        extraOpensPerTreasure: extraOpensPerTreasure,
        prizes: prizes
    )
}

@Suite("El Colchón: el reloj")
struct TreasureSchedulerTests {
    let config = fxTreasures()

    @Test("aparece a los 8 minutos de juego")
    func itAppearsAfterEightMinutes() {
        var state = TreasuresState.initial
        #expect(!TreasureScheduler.advance(&state, delta: 479, config: config))
        #expect(TreasureScheduler.advance(&state, delta: 1, config: config))
        #expect(state.waiting)
    }

    @Test("no se acumula: con uno esperando el reloj no corre")
    func oneAtATime() {
        var state = TreasuresState(secondsUntilNext: 5, waiting: true, extraOpensLeft: 0)
        #expect(!TreasureScheduler.advance(&state, delta: 10_000, config: config))
        #expect(state == TreasuresState(secondsUntilNext: 5, waiting: true, extraOpensLeft: 0))
    }

    @Test("abrirlo habilita «otro colchón» y rearma el reloj")
    func openingArmsTheExtra() {
        var state = TreasuresState(secondsUntilNext: 480, waiting: true, extraOpensLeft: 0)
        TreasureScheduler.markOpened(&state, config: config)
        #expect(!state.waiting)
        #expect(state.extraOpensLeft == 1)
        #expect(state.secondsUntilNext == 480)
    }

    @Test("uno nuevo se lleva el «otro colchón» que quedó sin usar")
    func aNewOneDropsTheUnusedExtra() {
        var state = TreasuresState(secondsUntilNext: 1, waiting: false, extraOpensLeft: 1)
        #expect(TreasureScheduler.advance(&state, delta: 1, config: config))
        #expect(state.extraOpensLeft == 0)
    }

    @Test("un colchón escrito antes de E5 decodifica vacío")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(TreasuresState.self, from: Data("{}".utf8)) == .initial)
        let partial = try JSONDecoder().decode(TreasuresState.self, from: Data(#"{"waiting": true}"#.utf8))
        #expect(partial == TreasuresState(secondsUntilNext: nil, waiting: true, extraOpensLeft: 0))
    }
}

@Suite("El Colchón: qué trae")
struct TreasureRollerTests {
    @Test("la tabla visible es la del sorteo")
    func theVisibleTableIsTheDrawnOne() {
        let odds = fxTreasures().odds
        #expect(odds.map(\.id) == ["coins", "package", "oro"])
        #expect(odds.map(\.probability) == [0.6, 0.25, 0.15])
    }

    @Test("el sorteo respeta la tabla")
    func theRollFollowsTheTable() throws {
        var rng = SeededRNG(seed: 42)
        let config = fxTreasures()
        let draws = 10_000
        var coins = 0
        for _ in 0..<draws {
            if try #require(TreasureRoller.roll(config, using: &rng)).id == "coins" { coins += 1 }
        }
        let share = Double(coins) / Double(draws)
        #expect(share > 0.58 && share < 0.62, "la plata salió \(share)")
    }

    @Test("sin premios no hay sorteo")
    func noPrizesNoDraw() {
        var rng = SeededRNG(seed: 1)
        #expect(TreasureRoller.roll(fxTreasures(prizes: []), using: &rng) == nil)
    }
}

@Suite("El Colchón: el dato")
struct TreasuresConfigTests {
    @Test("la tabla del plan valida")
    func thePlanValidates() throws {
        try fxTreasures().validate()
    }

    @Test("relojes y extras fuera de rango no cargan")
    func rangesAreChecked() {
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("spawnIntervalSeconds")) {
            try fxTreasures(spawnIntervalSeconds: 0).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.outOfRange("extraOpensPerTreasure")) {
            try fxTreasures(extraOpensPerTreasure: -1).validate()
        }
    }

    @Test("un premio sin peso, vacío, repetido o inválido no carga")
    func prizesAreChecked() {
        #expect(throws: TreasuresConfig.ValidationError.noPrizes) { try fxTreasures(prizes: []).validate() }
        #expect(throws: TreasuresConfig.ValidationError.badWeight("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 0, rewards: [.oro(1)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.emptyPrize("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.duplicatePrize("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [.oro(1)]), .init(id: "x", weight: 1, rewards: [.oro(2)])]).validate()
        }
        #expect(throws: TreasuresConfig.ValidationError.invalidReward("x")) {
            try fxTreasures(prizes: [.init(id: "x", weight: 1, rewards: [.coinsSeconds(0)])]).validate()
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "TreasureSchedulerTests|TreasureRollerTests|TreasuresConfigTests"`
Expected: no compila (`TreasuresConfig` no existe).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresConfig.swift`:

```swift
import Foundation

/// `treasures.json`: El Colchón (PLAN-v2 E5 y §2), "tus empleados escondieron
/// plata en el colchón". Aparece cada tanto de juego activo, espera hasta que
/// lo abras con un video y sortea un premio de esta tabla.
public struct TreasuresConfig: Codable, Sendable, Equatable {
    public struct Prize: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let weight: Int
        public let rewards: [RewardSpec]

        public init(id: String, weight: Int, rewards: [RewardSpec]) {
            self.id = id
            self.weight = weight
            self.rewards = rewards
        }
    }

    public let schemaVersion: Int
    /// Segundos de juego activo entre dos colchones (cuenta sólo sin uno esperando).
    public let spawnIntervalSeconds: Double
    /// El primero de una partida (o de un save anterior a E5).
    public let firstTreasureAfterSeconds: Double
    /// Cuántas veces se puede pedir "otro colchón" (un video más cada una).
    public let extraOpensPerTreasure: Int
    public let prizes: [Prize]

    public init(
        schemaVersion: Int,
        spawnIntervalSeconds: Double,
        firstTreasureAfterSeconds: Double,
        extraOpensPerTreasure: Int,
        prizes: [Prize]
    ) {
        self.schemaVersion = schemaVersion
        self.spawnIntervalSeconds = spawnIntervalSeconds
        self.firstTreasureAfterSeconds = firstTreasureAfterSeconds
        self.extraOpensPerTreasure = extraOpensPerTreasure
        self.prizes = prizes
    }

    /// La tabla que se muestra: la misma con la que sortea `TreasureRoller`.
    public var odds: [PrizeOdds] {
        zip(prizes, WeightedDraw.probabilities(weights: prizes.map { Double($0.weight) }))
            .map { PrizeOdds(id: $0.id, probability: $1) }
    }

    public enum ValidationError: Error, Equatable {
        case outOfRange(String)
        case noPrizes
        case duplicatePrize(String)
        case badWeight(String)
        case emptyPrize(String)
        case invalidReward(String)
    }

    public func validate() throws {
        guard spawnIntervalSeconds > 0 else { throw ValidationError.outOfRange("spawnIntervalSeconds") }
        guard firstTreasureAfterSeconds > 0 else { throw ValidationError.outOfRange("firstTreasureAfterSeconds") }
        guard extraOpensPerTreasure >= 0 else { throw ValidationError.outOfRange("extraOpensPerTreasure") }
        guard !prizes.isEmpty else { throw ValidationError.noPrizes }
        var seen: Set<String> = []
        for prize in prizes {
            guard seen.insert(prize.id).inserted else { throw ValidationError.duplicatePrize(prize.id) }
            guard prize.weight > 0 else { throw ValidationError.badWeight(prize.id) }
            guard !prize.rewards.isEmpty else { throw ValidationError.emptyPrize(prize.id) }
            for reward in prize.rewards {
                do {
                    try reward.validate()
                } catch {
                    throw ValidationError.invalidReward(prize.id)
                }
            }
        }
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresState.swift`:

```swift
import Foundation

/// El Colchón (vive en `meta.engagement`). El reloj es de JUEGO ACTIVO y sólo
/// corre sin uno esperando: no se acumula más de uno.
public struct TreasuresState: Codable, Sendable, Equatable {
    /// Segundos de juego hasta el próximo. `nil` = nunca se programó.
    public var secondsUntilNext: Double?
    /// Hay uno esperando que lo abran.
    public var waiting: Bool
    /// Los "otro colchón" que le quedan al último que se abrió. Se pierden
    /// cuando aparece uno nuevo.
    public var extraOpensLeft: Int

    public static let initial = TreasuresState()

    public init(secondsUntilNext: Double? = nil, waiting: Bool = false, extraOpensLeft: Int = 0) {
        self.secondsUntilNext = secondsUntilNext
        self.waiting = waiting
        self.extraOpensLeft = extraOpensLeft
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        waiting = try container.decodeIfPresent(Bool.self, forKey: .waiting) ?? false
        extraOpensLeft = try container.decodeIfPresent(Int.self, forKey: .extraOpensLeft) ?? 0
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasureEngine.swift`:

```swift
import Foundation

/// El reloj del Colchón. Lo llama el tick: afuera no corre.
public enum TreasureScheduler {
    /// Avanza el reloj; devuelve si apareció uno. Con uno esperando no corre.
    @discardableResult
    public static func advance(_ state: inout TreasuresState, delta: Double, config: TreasuresConfig) -> Bool {
        guard delta > 0, !state.waiting else { return false }
        let remaining = (state.secondsUntilNext ?? config.firstTreasureAfterSeconds) - delta
        guard remaining <= 0 else {
            state.secondsUntilNext = remaining
            return false
        }
        state.waiting = true
        state.extraOpensLeft = 0
        state.secondsUntilNext = config.spawnIntervalSeconds
        return true
    }

    /// Se abrió (con el primer video): deja de esperar, habilita "otro
    /// colchón" y el reloj arranca de nuevo.
    public static func markOpened(_ state: inout TreasuresState, config: TreasuresConfig) {
        state.waiting = false
        state.extraOpensLeft = config.extraOpensPerTreasure
        state.secondsUntilNext = config.spawnIntervalSeconds
    }
}

public enum TreasureRoller {
    public static func roll<R: RandomNumberGenerator>(_ config: TreasuresConfig, using rng: inout R) -> TreasuresConfig.Prize? {
        WeightedDraw.index(weights: config.prizes.map { Double($0.weight) }, using: &rng).map { config.prizes[$0] }
    }
}
```

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter "TreasureSchedulerTests|TreasureRollerTests|TreasuresConfigTests"`
Expected: PASS — 5 + 3 + 3 tests. Después `swift test --package-path Packages/EconomyKit` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresConfig.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasuresState.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/TreasureEngine.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/TreasuresEngineTests.swift
git diff --cached --stat
git commit -m "feat(colchon): El Colchón, puro — cuándo aparece y qué trae"
```

---

### Task 3: La Ruleta, pura — la tabla efectiva, el día y los cupos

**Objetivo:** la ruleta de PLAN-v2 E5 y §2: 10 segmentos con pesos que suman 100 y son la tabla
visible; si el cofre no tiene nada que dar, su peso pasa a plata y **la tabla mostrada es la
efectiva**; 6 giros por video por día, giro extra a 12 ORO con tope 6 por día, giros regalados
(el Conductor, los visitantes, las ofertas de E6); "repetir premio" es otro video que vuelve a dar
el mismo premio; el día es el calendario, como el diario.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelConfig.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelState.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelRoller.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/WheelEngineTests.swift`

**Interfaces:**
- Consumes: `RewardSpec` (**E4a T1**), `WeightedDraw`, `PrizeOdds` (T1).
- Produces: `public struct WheelConfig: Codable, Sendable, Equatable` (`schemaVersion`,
  `videoSpinsPerDay`, `oroSpinCost`, `oroSpinsPerDay`, `spinSeconds: Double`,
  `chestFallbackSegmentId: String`, `segments: [Segment]`), `WheelConfig.Segment` (`id`,
  `weight: Int`, `reward: RewardSpec`, `init(id:weight:reward:)`), `static let totalWeight = 100`,
  `effectiveSegments(chestHasSomethingToGive: Bool) -> [Segment]`,
  `odds(chestHasSomethingToGive: Bool) -> [PrizeOdds]`,
  `enum ValidationError { outOfRange(String), weightsMustSumTo100(Int), duplicateSegment(String), badWeight(String), unknownFallback(String), fallbackMustPayCoins, invalidReward(String) }`,
  `validate() throws`.
- Produces: `public struct WheelState: Codable, Sendable, Equatable` (`day: String?`,
  `videoSpinsUsed`, `oroSpinsUsed`, `bonusSpins`, `repeatableSegmentId: String?`,
  `static let initial`, `init(from:)`), `rolledOver(to today: String) -> WheelState`,
  `static func resolve(winner:loser:) -> WheelState`.
- Produces: `public enum WheelSpinSource: String, Sendable, Equatable, CaseIterable { bonus, video, oro }`;
  `WheelRoller.spinsLeft(_:state:config:) -> Int`, `consume(_:state:config:) -> Bool`
  (`@discardableResult`), `roll<R>(_ segments: [WheelConfig.Segment], using:) -> Int?`.

- [ ] **Step 0: `RewardSpec` está**

Run: `grep -n "public enum RewardSpec" Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift`
Expected: una línea (E4a T1). Si no, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/WheelEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// La tabla propuesta (duda 4): diez segmentos que suman 100.
let fxWheelSegments: [WheelConfig.Segment] = [
    .init(id: "coins_30", weight: 18, reward: .coinsSeconds(1800)),
    .init(id: "coins_45", weight: 12, reward: .coinsSeconds(2700)),
    .init(id: "coins_60", weight: 8, reward: .coinsSeconds(3600)),
    .init(id: "income_x2", weight: 14, reward: .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 600)),
    .init(id: "income_x3", weight: 8, reward: .modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 600)),
    .init(id: "income_x5", weight: 3, reward: .modifier(effect: .incomeMultiplier, magnitude: 5, seconds: 600)),
    .init(id: "oro_1", weight: 15, reward: .oro(1)),
    .init(id: "oro_3", weight: 5, reward: .oro(3)),
    .init(id: "package", weight: 12, reward: .package(1)),
    .init(id: "chest", weight: 5, reward: .skinChest(1)),
]

func fxWheel(
    videoSpinsPerDay: Int = 6,
    oroSpinCost: Int = 12,
    oroSpinsPerDay: Int = 6,
    chestFallbackSegmentId: String = "coins_30",
    segments: [WheelConfig.Segment] = fxWheelSegments
) -> WheelConfig {
    WheelConfig(
        schemaVersion: 1,
        videoSpinsPerDay: videoSpinsPerDay,
        oroSpinCost: oroSpinCost,
        oroSpinsPerDay: oroSpinsPerDay,
        spinSeconds: 3.8,
        chestFallbackSegmentId: chestFallbackSegmentId,
        segments: segments
    )
}

@Suite("La ruleta: la tabla")
struct WheelTableTests {
    @Test("los diez del plan validan y suman 100")
    func thePlanValidates() throws {
        try fxWheel().validate()
        #expect(fxWheel().segments.map(\.weight).reduce(0, +) == WheelConfig.totalWeight)
    }

    @Test("con el cofre lleno de pintas por dar, la tabla es la del dato")
    func aUsefulChestKeepsTheTable() {
        let config = fxWheel()
        #expect(config.effectiveSegments(chestHasSomethingToGive: true) == config.segments)
    }

    @Test("con el cofre vacío, su peso pasa a la plata y la tabla mostrada es la que gira")
    func anEmptyChestMovesItsWeightToCoins() throws {
        let config = fxWheel()
        let effective = config.effectiveSegments(chestHasSomethingToGive: false)
        #expect(!effective.contains { $0.reward.kind == .skinChest })
        #expect(try #require(effective.first { $0.id == "coins_30" }).weight == 23)
        #expect(effective.map(\.weight).reduce(0, +) == WheelConfig.totalWeight)
        #expect(config.odds(chestHasSomethingToGive: false).map(\.id) == effective.map(\.id))
    }

    @Test("las probabilidades son el peso sobre 100")
    func theOddsAreTheWeights() throws {
        let odds = fxWheel().odds(chestHasSomethingToGive: true)
        #expect(odds.count == 10)
        #expect(abs(try #require(odds.first { $0.id == "coins_30" }).probability - 0.18) < 1e-12)
        #expect(abs(try #require(odds.first { $0.id == "income_x5" }).probability - 0.03) < 1e-12)
    }

    @Test("una tabla que no suma 100, repetida o con un segmento sin peso no carga")
    func theTableIsChecked() {
        var short = fxWheelSegments
        short[0] = .init(id: "coins_30", weight: 17, reward: .coinsSeconds(1800))
        #expect(throws: WheelConfig.ValidationError.weightsMustSumTo100(99)) { try fxWheel(segments: short).validate() }
        var twice = fxWheelSegments
        twice[1] = .init(id: "coins_30", weight: 12, reward: .coinsSeconds(2700))
        #expect(throws: WheelConfig.ValidationError.duplicateSegment("coins_30")) { try fxWheel(segments: twice).validate() }
        var empty = fxWheelSegments
        empty[9] = .init(id: "chest", weight: 0, reward: .skinChest(1))
        #expect(throws: WheelConfig.ValidationError.badWeight("chest")) { try fxWheel(segments: empty).validate() }
    }

    @Test("el respaldo del cofre tiene que existir y pagar plata")
    func theFallbackIsChecked() {
        #expect(throws: WheelConfig.ValidationError.unknownFallback("nope")) {
            try fxWheel(chestFallbackSegmentId: "nope").validate()
        }
        #expect(throws: WheelConfig.ValidationError.fallbackMustPayCoins) {
            try fxWheel(chestFallbackSegmentId: "oro_1").validate()
        }
    }

    @Test("un premio inválido o un cupo fuera de rango no cargan")
    func rewardsAndQuotasAreChecked() {
        var broken = fxWheelSegments
        broken[6] = .init(id: "oro_1", weight: 15, reward: .oro(0))
        #expect(throws: WheelConfig.ValidationError.invalidReward("oro_1")) { try fxWheel(segments: broken).validate() }
        #expect(throws: WheelConfig.ValidationError.outOfRange("videoSpinsPerDay")) { try fxWheel(videoSpinsPerDay: 0).validate() }
        #expect(throws: WheelConfig.ValidationError.outOfRange("oroSpinCost")) { try fxWheel(oroSpinCost: 0).validate() }
        #expect(throws: WheelConfig.ValidationError.outOfRange("oroSpinsPerDay")) { try fxWheel(oroSpinsPerDay: -1).validate() }
    }
}

@Suite("La ruleta: el día y los giros")
struct WheelStateTests {
    let config = fxWheel()

    @Test("un día nuevo devuelve los cupos, pierde el «repetir» y conserva los regalados")
    func aNewDayResetsTheQuotas() {
        let yesterday = WheelState(day: "2026-10-06", videoSpinsUsed: 6, oroSpinsUsed: 2, bonusSpins: 1, repeatableSegmentId: "oro_3")
        #expect(yesterday.rolledOver(to: "2026-10-07") == WheelState(day: "2026-10-07", videoSpinsUsed: 0, oroSpinsUsed: 0, bonusSpins: 1, repeatableSegmentId: nil))
    }

    @Test("el mismo día no cambia nada")
    func theSameDayKeepsEverything() {
        let today = WheelState(day: "2026-10-07", videoSpinsUsed: 3, oroSpinsUsed: 1, bonusSpins: 0, repeatableSegmentId: "package")
        #expect(today.rolledOver(to: "2026-10-07") == today)
    }

    @Test("quedan 6 por video, 6 con ORO y los regalados")
    func spinsLeftPerSource() {
        let state = WheelState(day: "d", videoSpinsUsed: 2, oroSpinsUsed: 5, bonusSpins: 3)
        #expect(WheelRoller.spinsLeft(.video, state: state, config: config) == 4)
        #expect(WheelRoller.spinsLeft(.oro, state: state, config: config) == 1)
        #expect(WheelRoller.spinsLeft(.bonus, state: state, config: config) == 3)
    }

    @Test("gastar uno descuenta de su fuente; sin cupo no se gasta")
    func consumingSpendsFromItsSource() {
        var state = WheelState(day: "d", videoSpinsUsed: 5, oroSpinsUsed: 6, bonusSpins: 1)
        #expect(WheelRoller.consume(.video, state: &state, config: config))
        #expect(!WheelRoller.consume(.video, state: &state, config: config))
        #expect(!WheelRoller.consume(.oro, state: &state, config: config))
        #expect(WheelRoller.consume(.bonus, state: &state, config: config))
        #expect(state == WheelState(day: "d", videoSpinsUsed: 6, oroSpinsUsed: 6, bonusSpins: 0))
    }

    @Test("al resolver un conflicto del mismo día, los cupos usados se quedan con lo más alto")
    func resolvingKeepsTheDailyQuotas() {
        let winner = WheelState(day: "d", videoSpinsUsed: 1, oroSpinsUsed: 4, bonusSpins: 2)
        let loser = WheelState(day: "d", videoSpinsUsed: 5, oroSpinsUsed: 0, bonusSpins: 0)
        #expect(WheelState.resolve(winner: winner, loser: loser) == WheelState(day: "d", videoSpinsUsed: 5, oroSpinsUsed: 4, bonusSpins: 2))
        let otherDay = WheelState(day: "c", videoSpinsUsed: 6, oroSpinsUsed: 6)
        #expect(WheelState.resolve(winner: winner, loser: otherDay) == winner)
    }

    @Test("una ruleta escrita antes de E5 decodifica vacía")
    func theStateDecodesFromNothing() throws {
        #expect(try JSONDecoder().decode(WheelState.self, from: Data("{}".utf8)) == .initial)
        let partial = try JSONDecoder().decode(WheelState.self, from: Data(#"{"day": "d", "bonusSpins": 2}"#.utf8))
        #expect(partial == WheelState(day: "d", bonusSpins: 2))
    }
}

@Suite("La ruleta: el sorteo")
struct WheelRollerTests {
    @Test("el sorteo sigue la tabla efectiva, y sin cofre no sale cofre")
    func theRollFollowsTheEffectiveTable() throws {
        var rng = SeededRNG(seed: 7)
        let segments = fxWheel().effectiveSegments(chestHasSomethingToGive: false)
        let draws = 20_000
        var coins30 = 0
        for _ in 0..<draws {
            let index = try #require(WheelRoller.roll(segments, using: &rng))
            #expect(segments[index].reward.kind != .skinChest)
            if segments[index].id == "coins_30" { coins30 += 1 }
        }
        let share = Double(coins30) / Double(draws)
        #expect(share > 0.215 && share < 0.245, "coins_30 salió \(share)")
    }

    @Test("sin segmentos no hay giro")
    func noSegmentsNoSpin() {
        var rng = SeededRNG(seed: 1)
        #expect(WheelRoller.roll([], using: &rng) == nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "WheelTableTests|WheelStateTests|WheelRollerTests"`
Expected: no compila (`WheelConfig` no existe).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelConfig.swift`:

```swift
import Foundation

/// `wheel.json`: la Ruleta (PLAN-v2 E5 y §2). Los pesos suman 100 y son la
/// tabla que ve el jugador; la que se sortea es siempre la misma que se
/// muestra (`effectiveSegments`).
public struct WheelConfig: Codable, Sendable, Equatable {
    public struct Segment: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let weight: Int
        public let reward: RewardSpec

        public init(id: String, weight: Int, reward: RewardSpec) {
            self.id = id
            self.weight = weight
            self.reward = reward
        }
    }

    public static let totalWeight = 100

    public let schemaVersion: Int
    public let videoSpinsPerDay: Int
    public let oroSpinCost: Int
    /// 0 apaga el giro con ORO en todas las tiendas.
    public let oroSpinsPerDay: Int
    /// Lo que dura la animación del giro (la usa la vista).
    public let spinSeconds: Double
    /// A qué segmento de plata va el peso del cofre cuando el cofre no tiene
    /// nada que dar.
    public let chestFallbackSegmentId: String
    public let segments: [Segment]

    public init(
        schemaVersion: Int,
        videoSpinsPerDay: Int,
        oroSpinCost: Int,
        oroSpinsPerDay: Int,
        spinSeconds: Double,
        chestFallbackSegmentId: String,
        segments: [Segment]
    ) {
        self.schemaVersion = schemaVersion
        self.videoSpinsPerDay = videoSpinsPerDay
        self.oroSpinCost = oroSpinCost
        self.oroSpinsPerDay = oroSpinsPerDay
        self.spinSeconds = spinSeconds
        self.chestFallbackSegmentId = chestFallbackSegmentId
        self.segments = segments
    }

    /// La tabla que se sortea Y se muestra. Si un cofre de pintas hoy no tiene
    /// nada que dar, sus segmentos se van y su peso pasa a la plata.
    public func effectiveSegments(chestHasSomethingToGive: Bool) -> [Segment] {
        guard !chestHasSomethingToGive else { return segments }
        let moved = segments.filter { $0.reward.kind == .skinChest }.reduce(0) { $0 + $1.weight }
        guard moved > 0 else { return segments }
        return segments.compactMap { segment in
            if segment.reward.kind == .skinChest { return nil }
            guard segment.id == chestFallbackSegmentId else { return segment }
            return Segment(id: segment.id, weight: segment.weight + moved, reward: segment.reward)
        }
    }

    public func odds(chestHasSomethingToGive: Bool) -> [PrizeOdds] {
        let table = effectiveSegments(chestHasSomethingToGive: chestHasSomethingToGive)
        return zip(table, WeightedDraw.probabilities(weights: table.map { Double($0.weight) }))
            .map { PrizeOdds(id: $0.id, probability: $1) }
    }

    public enum ValidationError: Error, Equatable {
        case outOfRange(String)
        case weightsMustSumTo100(Int)
        case duplicateSegment(String)
        case badWeight(String)
        case unknownFallback(String)
        case fallbackMustPayCoins
        case invalidReward(String)
    }

    public func validate() throws {
        guard videoSpinsPerDay > 0 else { throw ValidationError.outOfRange("videoSpinsPerDay") }
        guard oroSpinCost > 0 else { throw ValidationError.outOfRange("oroSpinCost") }
        guard oroSpinsPerDay >= 0 else { throw ValidationError.outOfRange("oroSpinsPerDay") }
        guard spinSeconds > 0 else { throw ValidationError.outOfRange("spinSeconds") }
        var ids: Set<String> = []
        for segment in segments {
            guard ids.insert(segment.id).inserted else { throw ValidationError.duplicateSegment(segment.id) }
            guard segment.weight > 0 else { throw ValidationError.badWeight(segment.id) }
            do {
                try segment.reward.validate()
            } catch {
                throw ValidationError.invalidReward(segment.id)
            }
        }
        let total = segments.map(\.weight).reduce(0, +)
        guard total == Self.totalWeight else { throw ValidationError.weightsMustSumTo100(total) }
        guard let fallback = segments.first(where: { $0.id == chestFallbackSegmentId }) else {
            throw ValidationError.unknownFallback(chestFallbackSegmentId)
        }
        guard fallback.reward.kind == .coinsSeconds else { throw ValidationError.fallbackMustPayCoins }
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelState.swift`:

```swift
import Foundation

/// La ruleta en `meta.engagement`: el día calendario de los cupos, lo usado
/// hoy, los giros regalados y el premio que todavía se puede repetir.
public struct WheelState: Codable, Sendable, Equatable {
    /// "yyyy-MM-dd" en el huso del dispositivo, como el diario.
    public var day: String?
    public var videoSpinsUsed: Int
    public var oroSpinsUsed: Int
    /// Giros que alguien regaló (el Conductor, un visitante, una oferta). No
    /// piden video y no vencen con el día.
    public var bonusSpins: Int
    /// El último premio, mientras se pueda repetir con un video.
    public var repeatableSegmentId: String?

    public static let initial = WheelState()

    public init(
        day: String? = nil,
        videoSpinsUsed: Int = 0,
        oroSpinsUsed: Int = 0,
        bonusSpins: Int = 0,
        repeatableSegmentId: String? = nil
    ) {
        self.day = day
        self.videoSpinsUsed = videoSpinsUsed
        self.oroSpinsUsed = oroSpinsUsed
        self.bonusSpins = bonusSpins
        self.repeatableSegmentId = repeatableSegmentId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decodeIfPresent(String.self, forKey: .day)
        videoSpinsUsed = try container.decodeIfPresent(Int.self, forKey: .videoSpinsUsed) ?? 0
        oroSpinsUsed = try container.decodeIfPresent(Int.self, forKey: .oroSpinsUsed) ?? 0
        bonusSpins = try container.decodeIfPresent(Int.self, forKey: .bonusSpins) ?? 0
        repeatableSegmentId = try container.decodeIfPresent(String.self, forKey: .repeatableSegmentId)
    }

    /// El mismo estado pasado a `today`: en otro día los cupos vuelven a cero
    /// y el "repetir" se pierde; los regalados se quedan.
    public func rolledOver(to today: String) -> WheelState {
        guard day != today else { return self }
        return WheelState(day: today, bonusSpins: bonusSpins)
    }

    /// Dos dispositivos el mismo día no duplican el cupo: se queda lo más
    /// usado. Lo regalado y el "repetir" viajan con el ganador.
    public static func resolve(winner: WheelState, loser: WheelState) -> WheelState {
        guard winner.day != nil, winner.day == loser.day else { return winner }
        var resolved = winner
        resolved.videoSpinsUsed = max(winner.videoSpinsUsed, loser.videoSpinsUsed)
        resolved.oroSpinsUsed = max(winner.oroSpinsUsed, loser.oroSpinsUsed)
        return resolved
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelRoller.swift`:

```swift
import Foundation

/// Con qué se paga un giro.
public enum WheelSpinSource: String, Sendable, Equatable, CaseIterable {
    /// Uno regalado: no pide nada.
    case bonus
    /// Uno de los diarios por video.
    case video
    /// El extra con ORO (apagado donde la tienda no lo permite: lo decide la app).
    case oro
}

/// Los cupos y el sorteo de la ruleta. El estado que recibe ya está pasado al
/// día de hoy (`WheelState.rolledOver`).
public enum WheelRoller {
    public static func spinsLeft(_ source: WheelSpinSource, state: WheelState, config: WheelConfig) -> Int {
        switch source {
        case .bonus: max(0, state.bonusSpins)
        case .video: max(0, config.videoSpinsPerDay - state.videoSpinsUsed)
        case .oro: max(0, config.oroSpinsPerDay - state.oroSpinsUsed)
        }
    }

    /// Gasta un giro de esa fuente. Sin cupo, no toca nada y devuelve `false`.
    @discardableResult
    public static func consume(_ source: WheelSpinSource, state: inout WheelState, config: WheelConfig) -> Bool {
        guard spinsLeft(source, state: state, config: config) > 0 else { return false }
        switch source {
        case .bonus: state.bonusSpins -= 1
        case .video: state.videoSpinsUsed += 1
        case .oro: state.oroSpinsUsed += 1
        }
        return true
    }

    /// El índice ganador dentro de `segments` (la tabla efectiva).
    public static func roll<R: RandomNumberGenerator>(_ segments: [WheelConfig.Segment], using rng: inout R) -> Int? {
        WeightedDraw.index(weights: segments.map { Double($0.weight) }, using: &rng)
    }
}
```

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter "WheelTableTests|WheelStateTests|WheelRollerTests"`
Expected: PASS — 7 + 6 + 2 tests. Después `swift test --package-path Packages/EconomyKit` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelConfig.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelState.swift
git add Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelRoller.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/WheelEngineTests.swift
git diff --cached --stat
git commit -m "feat(ruleta): la Ruleta, pura — la tabla efectiva, el día y los cupos"
```

---

### Task 4: Paquetes, colchón y ruleta viven en `meta.engagement`

**Objetivo:** el estado de E5 entra al contenedor de E1 sin subir el schema: `packages`,
`treasures` y `wheel`. Un save que no los tiene decodifica con `.initial`; en un conflicto de
CloudKit el buzón y el colchón viajan con el ganador (son relojes y un buzón: unirlos crearía
paquetes) y la ruleta no duplica el cupo del día.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/EngagementPrizesStateTests.swift`

**Interfaces:**
- Consumes: `EngagementState` con `sharedMoments` (**E3b T9**) y `visitors`/`events` (**E4a T3**),
  los tres con su `init(from:)` y su `resolve`; `PackagesState` (T1), `TreasuresState` (T2),
  `WheelState` (T3).
- Produces: `EngagementState.packages: PackagesState`, `.treasures: TreasuresState`, `.wheel: WheelState`.

- [ ] **Step 0: El contenedor ya tiene lo de E3b y E4a**

Run: `grep -n "sharedMoments\|var visitors\|var events" Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
Expected: las tres. Si falta `visitors`/`events` (E4a T3) o `sharedMoments` (E3b T9), esta tarea
espera: las tres escriben el mismo `init(from:)`. Si el controlador decide adelantarla igual, se
sacan del struct de abajo las líneas marcadas `// E3b T9` o `// E4a T3` que falten, y el test
`keepsWhatE4Wrote` pierde su primera aserción.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/EngagementPrizesStateTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// El buzón, el colchón y la ruleta viven en `meta.engagement` (PLAN-v2 E5),
/// sin subir el schema del save.
@Suite("EngagementState: paquetes, colchón y ruleta")
struct EngagementPrizesStateTests {
    @Test("un engagement escrito antes de E5 decodifica con los tres en su estado inicial")
    func decodesWithoutTheKeys() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.packages == .initial)
        #expect(state.treasures == .initial)
        #expect(state.wheel == .initial)
    }

    @Test("lo que escribió E4 se conserva al lado")
    func keepsWhatE4Wrote() throws {
        let json = #"{"visitors": {"secondsUntilVisit": 42}, "packages": {"waiting": 2}, "wheel": {"day": "2026-10-07", "bonusSpins": 1}}"#
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(json.utf8))
        #expect(state.visitors.secondsUntilVisit == 42)  // E4a T3
        #expect(state.packages.waiting == 2)
        #expect(state.wheel.bonusSpins == 1)
        #expect(state.wheel.videoSpinsUsed == 0)
        #expect(state.treasures == .initial)
    }

    @Test("ida y vuelta, adentro del save entero")
    func roundTripInsideTheSave() throws {
        var player = fxState()
        player.meta.engagement.packages = PackagesState(secondsUntilNext: 33, waiting: 3)
        player.meta.engagement.treasures = TreasuresState(secondsUntilNext: 200, waiting: false, extraOpensLeft: 1)
        player.meta.engagement.wheel = WheelState(day: "2026-10-07", videoSpinsUsed: 2, oroSpinsUsed: 1, bonusSpins: 1, repeatableSegmentId: "oro_3")
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(player))
        #expect(decoded.meta.engagement == player.meta.engagement)
    }

    @Test("al resolver: buzón y colchón con el ganador; la ruleta no duplica el cupo del día")
    func resolveKeepsWinnerClocksAndDailyQuotas() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.packages = PackagesState(secondsUntilNext: 10, waiting: 1)
        loser.packages = PackagesState(secondsUntilNext: 90, waiting: 2)
        winner.treasures = TreasuresState(secondsUntilNext: 100, waiting: false)
        loser.treasures = TreasuresState(secondsUntilNext: 5, waiting: true)
        winner.wheel = WheelState(day: "d", videoSpinsUsed: 1)
        loser.wheel = WheelState(day: "d", videoSpinsUsed: 4)
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.packages == winner.packages)
        #expect(resolved.treasures == winner.treasures)
        #expect(resolved.wheel.videoSpinsUsed == 4)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter EngagementPrizesStateTests`
Expected: no compila (`EngagementState` no tiene `packages`).

- [ ] **Step 3: La implementación**

`EngagementState.swift` queda así (lo de E1 T4, E3b T9 y E4a T3 se conserva tal cual haya
quedado; si otra épica sumó otro campo, también se queda en el mismo `init` y el mismo `resolve`):

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
    public var visitors: VisitorsState  // E4a T3
    /// Eventos v2: reloj de juego, cooldowns y el próximo ya sorteado (E4).
    public var events: EventsState  // E4a T3
    /// El buzón del Paquete de la Aduana (E5).
    public var packages: PackagesState
    /// El Colchón (E5).
    public var treasures: TreasuresState
    /// La ruleta: el día, los cupos, los giros regalados y el "repetir" (E5).
    public var wheel: WheelState

    public init(
        sharedMoments: Set<String> = [],  // E3b T9
        visitors: VisitorsState = .initial,  // E4a T3
        events: EventsState = .initial,  // E4a T3
        packages: PackagesState = .initial,
        treasures: TreasuresState = .initial,
        wheel: WheelState = .initial
    ) {
        self.sharedMoments = sharedMoments  // E3b T9
        self.visitors = visitors  // E4a T3
        self.events = events  // E4a T3
        self.packages = packages
        self.treasures = treasures
        self.wheel = wheel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sharedMoments = try container.decodeIfPresent(Set<String>.self, forKey: .sharedMoments) ?? []  // E3b T9
        visitors = try container.decodeIfPresent(VisitorsState.self, forKey: .visitors) ?? .initial  // E4a T3
        events = try container.decodeIfPresent(EventsState.self, forKey: .events) ?? .initial  // E4a T3
        packages = try container.decodeIfPresent(PackagesState.self, forKey: .packages) ?? .initial
        treasures = try container.decodeIfPresent(TreasuresState.self, forKey: .treasures) ?? .initial
        wheel = try container.decodeIfPresent(WheelState.self, forKey: .wheel) ?? .initial
    }

    /// El buzón y el colchón viajan con el ganador: son relojes y un buzón, y
    /// unirlos crearía paquetes que nadie ganó. La ruleta no duplica el cupo
    /// del mismo día.
    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        var resolved = winner
        resolved.sharedMoments.formUnion(loser.sharedMoments)  // E3b T9
        resolved.visitors = VisitorsState.resolve(winner: winner.visitors, loser: loser.visitors)  // E4a T3
        resolved.events = EventsState.resolve(winner: winner.events, loser: loser.events)  // E4a T3
        resolved.wheel = WheelState.resolve(winner: winner.wheel, loser: loser.wheel)
        return resolved
    }
}
```

(los comentarios `// E3b T9` y `// E4a T3` son marcas para este plan: **no se commitean**.)

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit` → PASS, con `EngagementPrizesStateTests` (4)
y las suites del save de E1/E3b/E4a (`SaveCompatibilityTests`, `SaveConflictResolverTests`,
`EngagementStateTests`, `EngagementStageStateTests`) sin cambios. Receta R con
`-only-testing:FisuEvolutionTests/SaveMigratorTests -only-testing:FisuEvolutionTests/PersistenceTests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/EngagementPrizesStateTests.swift
git diff --cached --stat
git commit -m "feat(save): el buzón, el colchón y la ruleta viven en meta.engagement"
```

---

### Task 5: El contenido — `packages.json`, `treasures.json` y `wheel.json`, validados al arrancar

**Objetivo:** los números de PLAN-v2 como dato (y la tabla propuesta de la ruleta y del colchón,
dudas 4 y 5), cargados y validados en el arranque: un JSON roto no deja arrancar con un premio a
medias, igual que el resto del contenido.

**Files:**
- Create: `FisuEvolution/Resources/Config/packages.json`
- Create: `FisuEvolution/Resources/Config/treasures.json`
- Create: `FisuEvolution/Resources/Config/wheel.json`
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`GameContent` + `load`)
- Create: `FisuEvolutionTests/PrizesContentTests.swift`

**Interfaces:**
- Consumes: `PackagesConfig`, `TreasuresConfig`, `WheelConfig` y sus `validate()` (T1–T3).
- Produces: `GameContent.packages: PackagesConfig`, `.treasures: TreasuresConfig`, `.wheel: WheelConfig`.

- [ ] **Step 0: Quién tocó el loader antes**

Run: `grep -n "let notifications: NotificationsConfig\|let visitors\|let events" FisuEvolution/Managers/GameContentLoader.swift`
Expected: `notifications` (E11 T2, ya en el árbol) y, si E4a T7/T9 entraron, `visitors` y el
`events` nuevo. Los tres de E5 van al final de `GameContent` y de su `return`, después del
último que haya.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PrizesContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los números del Paquete, el Colchón y la Ruleta tal como quedaron en el dato
/// (PLAN-v2 E5 y §2; la tabla de premios de E2a).
@Suite("Paquete, colchón y ruleta: el contenido real")
struct PrizesContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("el paquete: uno cada 2 min de juego, hasta 2, ventana de 4 tiers y el tope al 6,7 %")
    func packages() {
        let packages = content.packages
        #expect(packages.spawnIntervalSeconds == 120)
        #expect(packages.maxWaiting == 2)
        #expect(packages.windowTiers == 4)
        #expect(packages.tierRatioByBestSupplierLevel == [2, 1.8, 1.6, 1.4])
        let ladder = content.tiers.concreteTypes.filter { $0.tier <= 4 }
        let top = PackageRoller.odds(eligible: ladder, windowTiers: packages.windowTiers, ratio: packages.tierRatio(bestSupplierLevel: 0))[0]
        #expect(top.probability > 0.05 && top.probability < 0.08, "§2: el tope sale ~5–8 %")
    }

    @Test("el colchón: cada 8 min de juego, uno solo, y plata 20 min / un Paquete / 2 ORO")
    func treasures() {
        let treasures = content.treasures
        #expect(treasures.spawnIntervalSeconds == 480)
        #expect(treasures.extraOpensPerTreasure == 1)
        #expect(treasures.prizes.map(\.id) == ["coins", "package", "oro"])
        #expect(treasures.prizes[0].rewards == [.coinsSeconds(1200)])
        #expect(treasures.prizes[1].rewards == [.package(1)])
        #expect(treasures.prizes[2].rewards == [.oro(2)])
    }

    @Test("la ruleta: 10 segmentos que suman 100, 6 por video, 12 ORO con tope 6 y 3,8 s de giro")
    func wheel() {
        let wheel = content.wheel
        #expect(wheel.segments.count == 10)
        #expect(wheel.segments.map(\.weight).reduce(0, +) == 100)
        #expect(wheel.videoSpinsPerDay == 6)
        #expect(wheel.oroSpinCost == 12)
        #expect(wheel.oroSpinsPerDay == 6)
        #expect(wheel.spinSeconds == 3.8)
    }

    @Test("la ruleta da lo que dice E2a: plata 30–60 min, ×2/×3/×5 por 10 min, ORO 1–3, paquete y cofre")
    func wheelPrizes() {
        var kinds: Set<RewardSpec.Kind> = []
        for segment in content.wheel.segments {
            kinds.insert(segment.reward.kind)
            switch segment.reward {
            case .coinsSeconds(let seconds):
                #expect((1800...3600).contains(seconds), "\(segment.id): \(seconds) s")
            case let .modifier(effect, magnitude, seconds):
                #expect(effect == .incomeMultiplier)
                #expect([2, 3, 5].contains(magnitude))
                #expect(seconds == 600)
            case .oro(let amount):
                #expect((1...3).contains(amount))
            case .package(let count), .skinChest(let count):
                #expect(count == 1)
            default:
                Issue.record("\(segment.id): la ruleta no da \(segment.reward.kind)")
            }
        }
        #expect(kinds == [.coinsSeconds, .modifier, .oro, .package, .skinChest])
        #expect(content.wheel.chestFallbackSegmentId == "coins_30")
    }

    @Test("el arranque rechaza una ruleta que no suma 100")
    func loaderRejectsABrokenWheel() throws {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory.appending(path: "e5-\(UUID().uuidString).bundle")
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: bundleURL) }
        for url in Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] {
            try fileManager.copyItem(at: url, to: bundleURL.appending(path: url.lastPathComponent))
        }
        let wheelURL = bundleURL.appending(path: "wheel.json")
        var wheel = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: wheelURL)) as? [String: Any])
        var segments = try #require(wheel["segments"] as? [[String: Any]])
        segments[0]["weight"] = 1
        wheel["segments"] = segments
        try JSONSerialization.data(withJSONObject: wheel).write(to: wheelURL)
        let bundle = try #require(Bundle(url: bundleURL))

        #expect {
            _ = try GameContentLoader.load(from: bundle)
        } throws: { error in
            guard case .contentInvalid(let file, let reason)? = error as? GameError else { return false }
            return file == "wheel.json" && reason.contains("weightsMustSumTo100")
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/PrizesContentTests`.
Expected: no compila (`GameContent` no tiene `packages`).

- [ ] **Step 3: El dato**

`FisuEvolution/Resources/Config/packages.json`:

```json
{
  "schemaVersion": 1,
  "spawnIntervalSeconds": 120,
  "firstPackageAfterSeconds": 120,
  "maxWaiting": 2,
  "windowTiers": 4,
  "tierRatioByBestSupplierLevel": [2.0, 1.8, 1.6, 1.4]
}
```

`FisuEvolution/Resources/Config/treasures.json`:

```json
{
  "schemaVersion": 1,
  "spawnIntervalSeconds": 480,
  "firstTreasureAfterSeconds": 480,
  "extraOpensPerTreasure": 1,
  "prizes": [
    {"id": "coins", "weight": 60, "rewards": [{"kind": "coinsSeconds", "seconds": 1200}]},
    {"id": "package", "weight": 25, "rewards": [{"kind": "package", "count": 1}]},
    {"id": "oro", "weight": 15, "rewards": [{"kind": "oro", "amount": 2}]}
  ]
}
```

`FisuEvolution/Resources/Config/wheel.json`:

```json
{
  "schemaVersion": 1,
  "videoSpinsPerDay": 6,
  "oroSpinCost": 12,
  "oroSpinsPerDay": 6,
  "spinSeconds": 3.8,
  "chestFallbackSegmentId": "coins_30",
  "segments": [
    {"id": "coins_30", "weight": 18, "reward": {"kind": "coinsSeconds", "seconds": 1800}},
    {"id": "income_x2", "weight": 14, "reward": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 600}},
    {"id": "oro_1", "weight": 15, "reward": {"kind": "oro", "amount": 1}},
    {"id": "coins_45", "weight": 12, "reward": {"kind": "coinsSeconds", "seconds": 2700}},
    {"id": "package", "weight": 12, "reward": {"kind": "package", "count": 1}},
    {"id": "income_x3", "weight": 8, "reward": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 3, "seconds": 600}},
    {"id": "coins_60", "weight": 8, "reward": {"kind": "coinsSeconds", "seconds": 3600}},
    {"id": "chest", "weight": 5, "reward": {"kind": "skinChest", "count": 1}},
    {"id": "oro_3", "weight": 5, "reward": {"kind": "oro", "amount": 3}},
    {"id": "income_x5", "weight": 3, "reward": {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 5, "seconds": 600}}
  ]
}
```

(el orden es el de la rueda: plata, multiplicador, ORO, plata, paquete… alternados para que dos
colores iguales no queden pegados; E5b T1 los dibuja en este orden.)

- [ ] **Step 4: El loader**

`GameContentLoader.swift`, en `struct GameContent`, después del último campo:

```swift
    /// El Paquete de la Aduana, El Colchón y la Ruleta (PLAN-v2 E5).
    let packages: PackagesConfig
    let treasures: TreasuresConfig
    let wheel: WheelConfig
```

En `load(from:)`, junto a los otros `decode`:

```swift
        let packages: PackagesConfig = try decode("packages", from: bundle)
        let treasures: TreasuresConfig = try decode("treasures", from: bundle)
        let wheel: WheelConfig = try decode("wheel", from: bundle)
```

después de la validación de `skins` (antes del `return`):

```swift
        try validatePrize(packages.validate, file: "packages.json")
        try validatePrize(treasures.validate, file: "treasures.json")
        try validatePrize(wheel.validate, file: "wheel.json")
```

en el `return GameContent(...)`, al final:

```swift
            packages: packages,
            treasures: treasures,
            wheel: wheel
```

y, junto a `decode` (al final del `enum`):

```swift
    /// Un premio mal declarado se descubre al arrancar, no cuando el jugador lo
    /// abre: el error dice qué archivo y por qué.
    private static func validatePrize(_ validate: () throws -> Void, file: String) throws {
        do {
            try validate()
        } catch {
            throw GameError.contentInvalid(file: file, reason: "\(error)")
        }
    }
```

(si E4a dejó un helper equivalente en el loader —`validateContent(_:file:)` o similar— se usa
ése y no se suma otro.)

- [ ] **Step 5: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/PrizesContentTests -only-testing:FisuEvolutionTests/GameContentValidationTests -only-testing:FisuEvolutionTests/NotificationsContentTests`
→ PASS (5 nuevos; los otros sin cambios: el loader sigue cargando el bundle entero).
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Resources/Config/packages.json
git add FisuEvolution/Resources/Config/treasures.json
git add FisuEvolution/Resources/Config/wheel.json
git add FisuEvolution/Managers/GameContentLoader.swift
git add FisuEvolutionTests/PrizesContentTests.swift
git diff --cached --stat
git commit -m "feat(premios): paquetes, colchón y ruleta como dato, validados al arrancar"
```

---

### Task 6: El Paquete en la partida — cae, se abre y llega por el embudo

**Objetivo:** que el paquete ande en el juego sin UI propia: su reloj cuelga de
`advanceEngagement` y lee la Lluvia y el Piquete; `openPackage()` sortea entre lo que FisuJobs
vende con lugar y deja la llegada en el embudo de E1 (`Origin.package`), o dice "LLENO" y el
paquete se queda; si al llegar su turno ya no entra, vuelve al buzón; y `grant(.package(n))` lo
regala aunque pase el tope. Con `.package` entregable, despiertan solos los guiones del Puntero
(acto y bolsón), del Sindicalista (asado), de la Influencer (novio) y de la Vecina (favor), y los
eventos Lluvia de Paquetes y Piquete entran al sorteo (E4a duda 8).

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Packages.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (`Origin.package`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (`discardBoardChange`, una línea)
- Modify: `FisuEvolution/Game/State/GameState+Rewards.swift` (`grantableRewardKinds` y el caso de `grant`)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`advanceEngagement` y `applyEngagementFixtures`)
- Create: `FisuEvolutionTests/PackageRuntimeTests.swift`
- Modify: `FisuEvolutionTests/RewardGrantTests.swift` (E4a T8: `notYetGrantable`, `grantableKinds`)
- Modify: `FisuEvolutionTests/EventsRuntimeTests.swift` (E4a T9: `applicability`)

**Interfaces:**
- Consumes: T1, T4, T5; **E1 T7** (`BoardChangePlanner.planArrival`), **T9**
  (`enqueueBoardChange`, `pendingBoardChanges`, `beginNextBoardChange`, `confirmBoardChange`),
  **T14** (`discardBoardChange` con `switch` sobre `Origin`); **E4a T2**
  (`.packageRateMultiplier`), **T6** (`Origin.visitor`, el `switch` ya lo tiene), **T8**
  (`grant`, `grantableRewardKinds`), **T9** (`advanceEngagement`, `applyEngagementFixtures`,
  `fixtureValue`, `engagementAutorun`).
- Produces: `BoardChange.Origin.package`; `enum PackageOpenResult: Equatable { opened(typeId: String), full, noneWaiting }`;
  `GameState.packagesWaiting: Int`, `packageCandidates: [CharacterType]`, `packagesBlocked: Bool`,
  `advancePackages(delta:now:)`, `openPackage() -> PackageOpenResult` (`@discardableResult`),
  `refundPackage()`; DEBUG: `debugAddPackages(_:)`, el fixture `--uitest-packages=N`.

- [ ] **Step 0: E1 entera y E4a T9 están**

Run (uno por llamada):

```bash
grep -n "func enqueueBoardChange\|func discardBoardChange" FisuEvolution/Game/State/GameState+BoardChanges.swift
grep -n "public static func planArrival" Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift
grep -n "func grant(\|static let grantableRewardKinds" FisuEvolution/Game/State/GameState+Rewards.swift
grep -n "func advanceEngagement\|func applyEngagementFixtures" FisuEvolution/Game/State/GameState+Engagement.swift
grep -n "case packageRateMultiplier" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift
```

Expected: una línea por función. Si falta alguna, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PackageRuntimeTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Paquete de la Aduana en la partida")
@MainActor
struct PackageRuntimeTests {
    private func playing() async -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        return gameState
    }

    @Test("bajo XCTest no cae nada solo")
    func autorunIsOffUnderTests() async {
        let gameState = await makeGameState()
        #expect(!gameState.engagementAutorun)
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 0)
    }

    @Test("con el juego andando, cae uno cuando vence el reloj")
    func aPackageDrops() async {
        let gameState = await playing()
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("durante la fase obligatoria del tutorial no nace ninguno")
    func noPackagesDuringTheTutorialCore() async {
        let gameState = await playing()
        gameState.beginTutorialPhase()
        gameState.player?.meta.engagement.packages.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 0)
    }

    @Test("el Piquete frena el reloj y la Lluvia lo corre ×10")
    func eventsMoveTheClock() async {
        let gameState = await playing()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.engagement.packages.secondsUntilNext = 10
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .packageRateMultiplier, magnitude: 0, expiresAt: now + 90, sourceKey: "event.piquete"),
        ]
        gameState.advanceEngagement(delta: 2)
        #expect(gameState.player?.meta.engagement.packages.secondsUntilNext == 10)
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .packageRateMultiplier, magnitude: 10, expiresAt: now + 60, sourceKey: "event.lluvia_paquetes"),
        ]
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("lo que el paquete puede traer es exactamente lo que FisuJobs vende con lugar")
    func candidatesMatchFisuJobs() async {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.debugMarkTypesSeen(throughTier: 12)
        let hirable = Set(gameState.jobRows.filter { $0.state == .hirable }.map(\.id))
        #expect(hirable.count > 1)
        #expect(Set(gameState.packageCandidates.map(\.id)) == hirable)
    }

    @Test("abrir uno sortea entre los candidatos y deja la llegada en el embudo")
    func openingPlansAnArrival() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        let candidates = Set(gameState.packageCandidates.map(\.id))
        guard case .opened(let typeId) = gameState.openPackage() else {
            Issue.record("el paquete no se abrió")
            return
        }
        #expect(candidates.contains(typeId))
        #expect(gameState.packagesWaiting == 0)
        let change = try #require(gameState.pendingBoardChanges.last)
        #expect(change.origin == .package)
        #expect(change.kind == .arrival(typeId: typeId))
    }

    @Test("llegar es colocar: no cuenta como contratación")
    func arrivingIsNotHiring() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        let before = try #require(gameState.player)
        _ = gameState.openPackage()
        let change = try #require(gameState.beginNextBoardChange())
        gameState.confirmBoardChange(id: change.id)
        let after = try #require(gameState.player)
        #expect(after.run.totalUnits == before.run.totalUnits + 1)
        #expect(after.run.hireCounts == before.run.hireCounts)
        #expect(after.run.hireCountsByType == before.run.hireCountsByType)
        #expect(after.meta.stats.totalHiresEver == before.meta.stats.totalHiresEver)
    }

    @Test("sin lugar dice LLENO y el paquete no se gasta")
    func aFullTowerKeepsThePackage() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(1)
        #expect(gameState.packagesBlocked)
        #expect(gameState.openPackage() == .full)
        #expect(gameState.packagesWaiting == 1)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("sin paquetes esperando, abrir no hace nada")
    func nothingToOpen() async {
        let gameState = await makeGameState()
        #expect(gameState.openPackage() == .noneWaiting)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("si al llegar su turno ya no entra, el paquete vuelve al buzón")
    func aStaleArrivalGivesThePackageBack() async throws {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        _ = gameState.openPackage()
        let change = try #require(gameState.pendingBoardChanges.last)
        gameState.discardBoardChange(change)
        #expect(gameState.packagesWaiting == 1)
    }

    @Test("uno regalado entra aunque haya dos esperando")
    func grantedPackagesSkipTheCap() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.grant(.package(1), source: "visit.puntero_bolson")
        #expect(gameState.packagesWaiting == 3)
    }
}
```

En `FisuEvolutionTests/RewardGrantTests.swift` (E4a T8):

- `notYetGrantable`: se saca `RewardSpec.package(1)` de los argumentos, que quedan
  `[RewardSpec.wheelSpin(1), .autoTap(perSecond: 5, seconds: 60), .nextOfflineMultiplier(3), .nextDailyMultiplier(3), .extraSlots(3)]`
  (el primero lleva el tipo explícito; `.wheelSpin` lo saca la Task 8).
- `grantableKinds`:

```swift
    @Test("lo entregable es exactamente lo que este punto sabe dar")
    func grantableKinds() {
        #expect(GameState.grantableRewardKinds == [.coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity, .package])
    }
```

En `FisuEvolutionTests/EventsRuntimeTests.swift` (E4a T9), `applicability` queda:

```swift
    @Test("sin pasivo, el Aguinaldo no aplica; los paquetes ya se entregan (E5)")
    func applicability() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.eventIsApplicable(try event("aguinaldo", in: gameState)))
        #expect(gameState.eventIsApplicable(try event("lluvia_paquetes", in: gameState)))
        #expect(gameState.eventIsApplicable(try event("piquete", in: gameState)))
        #expect(gameState.eventIsApplicable(try event("devaluacion", in: gameState)))
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/PackageRuntimeTests`.
Expected: no compila (`openPackage`, `Origin.package`).

- [ ] **Step 3: El origen en EconomyKit**

`BoardChange.swift`, en `enum Origin` (de E1 T7; "E4/E5 suman los suyos"), después del último caso
que haya (`visitor`, de E4a T6):

```swift
        /// Un Paquete de la Aduana abierto (E5): el empleado llega a la vista.
        case package
```

y en `GameState+BoardChanges.swift`, en el `switch change.origin` de `discardBoardChange` (E1
T14), sin tocar los demás casos:

```swift
        case .package: refundPackage()
```

- [ ] **Step 4: `GameState+Packages.swift`**

```swift
import EconomyKit
import Foundation

/// Lo que pasa al tocar un paquete.
enum PackageOpenResult: Equatable {
    /// Sorteó a quién trae y lo dejó en el embudo de E1: llega en su turno, a la vista.
    case opened(typeId: String)
    /// No hay a quién traer con lugar: "LLENO", y el paquete se queda.
    case full
    /// No había ninguno esperando.
    case noneWaiting
}

/// El Paquete de la Aduana en la partida (PLAN-v2 E5).
extension GameState {
    var packagesWaiting: Int { player?.meta.engagement.packages.waiting ?? 0 }

    /// A quién podría traer un paquete ahora: lo que FisuJobs vende con lugar.
    var packageCandidates: [CharacterType] {
        guard let content, let player, let tower else { return [] }
        return PackageRoller.eligibleTypes(
            state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy
        )
    }

    /// Hay paquetes esperando y ninguno entra: el cartel "LLENO".
    var packagesBlocked: Bool { packagesWaiting > 0 && packageCandidates.isEmpty }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advancePackages(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let rate = ModifierMath.factor(player.run.activeModifiers, effect: .packageRateMultiplier, now: now)
        let dropped = PackageScheduler.advance(
            &player.meta.engagement.packages, delta: delta, rateMultiplier: rate, config: content.packages
        )
        self.player = player
        guard dropped > 0 else { return }
        Log.economy.info("package dropped: \(player.meta.engagement.packages.waiting) waiting")
        scheduleSave()
    }

    /// Abre uno: sortea a quién trae y deja su llegada en el embudo. El
    /// paquete se gasta sólo si alguien entra.
    @discardableResult
    func openPackage() -> PackageOpenResult {
        guard let content, var player, let tower, player.meta.engagement.packages.waiting > 0 else {
            return .noneWaiting
        }
        // E6: el nivel del permanente "mejor proveedor".
        let ratio = content.packages.tierRatio(bestSupplierLevel: 0)
        guard let type = PackageRoller.roll(
                  eligible: packageCandidates, windowTiers: content.packages.windowTiers, ratio: ratio, using: &rng
              ),
              let change = BoardChangePlanner.planArrival(
                  typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                  floorTable: content.floorTable, origin: .package
              )
        else {
            haptics?.play(.error)
            audio?.play(.error)
            return .full
        }
        player.meta.engagement.packages.waiting -= 1
        self.player = player
        enqueueBoardChange(change)
        haptics?.play(.purchase)
        syncCelebrations()
        scheduleSave()
        Log.economy.info("package opened: \(type.id)")
        return .opened(typeId: type.id)
    }

    /// Un paquete cuyo empleado ya no entra cuando le toca el turno vuelve al
    /// buzón, aunque pase el tope: ya estaba ganado.
    func refundPackage() {
        guard var player else { return }
        player.meta.engagement.packages.waiting += 1
        self.player = player
        scheduleSave()
    }

    #if DEBUG
    func debugAddPackages(_ count: Int) {
        guard var player, count > 0 else { return }
        player.meta.engagement.packages.waiting += count
        self.player = player
    }
    #endif
}
```

- [ ] **Step 5: `grant`, el reloj y la puerta de test**

`GameState+Rewards.swift` (E4a T8): el doc y la lista de `grantableRewardKinds` quedan

```swift
    /// Lo que este punto ya sabe dar. E5 suma `.package` y `.wheelSpin`; E6,
    /// `.autoTap`, los multiplicadores del próximo offline y diario y `.extraSlots`.
    /// Un guion o un evento que da algo de afuera de esta lista **no se ofrece**
    /// (`VisitorScheduler`, `eventIsApplicable`): mejor que no venga a que prometa
    /// y no cumpla.
    static let grantableRewardKinds: Set<RewardSpec.Kind> = [
        .coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity, .package,
    ]
```

y en el `switch reward.scaled(by: multiplier)` de `grant`, el caso que devolvía 0 se parte:

```swift
        case .package(let count):
            player.meta.engagement.packages.waiting += count
        case .wheelSpin, .autoTap, .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots:
            return 0
```

`GameState+Engagement.swift` (E4a T9): en `advanceEngagement(delta:)`, después de lo que haya
(eventos de E4a, escenario y visitantes de E4b):

```swift
        advancePackages(delta: delta)
```

y en `applyEngagementFixtures(arguments:)`, al final:

```swift
        if let count = Self.fixtureValue("--uitest-packages=", in: arguments).flatMap(Int.init) {
            debugAddPackages(count)
        }
```

- [ ] **Step 6: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter BoardChangeTests` → PASS (el origen
nuevo no rompe nada). `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/PackageRuntimeTests -only-testing:FisuEvolutionTests/RewardGrantTests -only-testing:FisuEvolutionTests/EventsRuntimeTests -only-testing:FisuEvolutionTests/BoardChangeWiringTests -only-testing:FisuEvolutionTests/RewardApplicabilityTests`
(más `-only-testing:FisuEvolutionTests/VisitorRuntimeTests` si E4b T2 ya entró) → PASS (11 nuevos). `Tools/v2/oraculo.sh completo` → `VERDE` (los guiones que daban paquetes y
la Lluvia y el Piquete entran a sus sorteos: la tarea cambia lo que el jugador puede ver).

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Packages.swift
git add Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift
git add FisuEvolution/Game/State/GameState+BoardChanges.swift
git add FisuEvolution/Game/State/GameState+Rewards.swift
git add FisuEvolution/Game/State/GameState+Engagement.swift
git add FisuEvolutionTests/PackageRuntimeTests.swift
git add FisuEvolutionTests/RewardGrantTests.swift
git add FisuEvolutionTests/EventsRuntimeTests.swift
git diff --cached --stat
git commit -m "feat(paquetes): el Paquete cae, se abre y llega por el embudo del tablero"
```

---

### Task 7: El Colchón en la partida — aparece, se abre con video y da "otro colchón"

**Objetivo:** el colchón andando sin UI propia: su reloj cuelga de `advanceEngagement`;
`openMattress()` (la vista lo llama después del video) sortea, acredita por `grant` y habilita un
"otro colchón"; `openExtraMattress()` (después del segundo video) sortea de nuevo, una vez por
colchón. Lo que salió vuelve como `MattressOutcome` para que E5b lo muestre.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Treasures.swift`
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift`
- Create: `FisuEvolutionTests/MattressRuntimeTests.swift`

**Interfaces:**
- Consumes: T2, T4, T5, T6 (`.package` entregable: el colchón puede dar un Paquete); **E4a T8**
  (`grant`), **T9** (`advanceEngagement`, `applyEngagementFixtures`, `engagementAutorun`).
- Produces: `struct MattressOutcome: Equatable` (`prizeId: String`, `rewards: [RewardSpec]`,
  `coins: Double`, `extraOpensLeft: Int`); `GameState.mattressWaiting: Bool`,
  `mattressExtraOpensLeft: Int`, `advanceTreasures(delta:)`,
  `openMattress(now:) -> MattressOutcome?` y `openExtraMattress(now:) -> MattressOutcome?`
  (`@discardableResult`); DEBUG: `debugSpawnMattress()`, el fixture `--uitest-mattress`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/MattressRuntimeTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El Colchón en la partida")
@MainActor
struct MattressRuntimeTests {
    @Test("bajo XCTest no aparece solo")
    func autorunIsOffUnderTests() async {
        let gameState = await makeGameState()
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(!gameState.mattressWaiting)
    }

    @Test("con el juego andando, aparece cuando vence su reloj; durante el núcleo del tutorial, no")
    func itAppears() async {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.beginTutorialPhase()
        gameState.player?.meta.engagement.treasures.secondsUntilNext = 0.5
        gameState.advanceEngagement(delta: 1)
        #expect(!gameState.mattressWaiting)
        gameState.tutorialPhaseFinished()
        gameState.advanceEngagement(delta: 1)
        #expect(gameState.mattressWaiting)
    }

    @Test("sin colchón esperando no se abre nada")
    func nothingToOpen() async {
        let gameState = await makeGameState()
        #expect(gameState.openMattress() == nil)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("abrirlo acredita su premio, deja de esperar y habilita uno más")
    func openingGrantsAndArmsTheExtra() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        let before = try #require(gameState.player)
        let outcome = try #require(gameState.openMattress())
        let after = try #require(gameState.player)
        #expect(!gameState.mattressWaiting)
        #expect(outcome.extraOpensLeft == 1)
        #expect(after.meta.engagement.treasures.secondsUntilNext == gameState.content?.treasures.spawnIntervalSeconds)
        switch outcome.prizeId {
        case "coins": #expect(after.run.coins > before.run.coins && outcome.coins > 0)
        case "package": #expect(after.meta.engagement.packages.waiting == before.meta.engagement.packages.waiting + 1)
        case "oro": #expect(after.meta.oro == before.meta.oro + 2)
        default: Issue.record("premio desconocido: \(outcome.prizeId)")
        }
    }

    @Test("«otro colchón» sortea de nuevo una sola vez")
    func theExtraIsOnce() async throws {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        _ = try #require(gameState.openMattress())
        let extra = try #require(gameState.openExtraMattress())
        #expect(extra.extraOpensLeft == 0)
        #expect(gameState.openExtraMattress() == nil)
    }

    @Test("la plata del colchón son 20 minutos de producción")
    func theCoinsAreTwentyMinutes() async throws {
        let gameState = await makeGameState()
        for _ in 0..<60 {
            gameState.debugSpawnMattress()
            let player = try #require(gameState.player)
            let content = try #require(gameState.content)
            let economy = try #require(gameState.economy)
            let outcome = try #require(gameState.openMattress())
            guard outcome.prizeId == "coins" else { continue }
            let expected = GameState.coinReward(seconds: 1200, player: player, content: content, economy: economy)
            #expect(abs(outcome.coins - expected) < 1e-6 * max(1, expected))
            return
        }
        Issue.record("en 60 colchones no salió plata (60 % cada uno)")
    }
}
```

(`coinReward(seconds:player:content:economy:)` es la base de `grant` para `coinsSeconds` desde
E1 T14; si E2a T11 ya la apoyó sobre `RewardScale`, el test sigue diciendo lo mismo: lo que se
acredita es lo que cotiza `grant`.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/MattressRuntimeTests`.
Expected: no compila (`openMattress` no existe).

- [ ] **Step 3: `GameState+Treasures.swift`**

```swift
import EconomyKit
import Foundation

/// Lo que salió de un colchón, ya acreditado.
struct MattressOutcome: Equatable {
    let prizeId: String
    let rewards: [RewardSpec]
    /// La plata acreditada (0 si el premio no era plata).
    let coins: Double
    /// Los "otro colchón" que le quedan.
    let extraOpensLeft: Int
}

/// El Colchón en la partida (PLAN-v2 E5): "tus empleados escondieron plata en
/// el colchón". Se abre sólo con video; lo llama la vista al terminar.
extension GameState {
    var mattressWaiting: Bool { player?.meta.engagement.treasures.waiting ?? false }

    var mattressExtraOpensLeft: Int { player?.meta.engagement.treasures.extraOpensLeft ?? 0 }

    /// El reloj de juego activo. Lo llama `advanceEngagement` con el delta del tick.
    func advanceTreasures(delta: TimeInterval) {
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        let appeared = TreasureScheduler.advance(&player.meta.engagement.treasures, delta: delta, config: content.treasures)
        self.player = player
        guard appeared else { return }
        Log.economy.info("mattress appeared")
        scheduleSave()
    }

    /// Después del video: sortea, acredita y habilita "otro colchón".
    @discardableResult
    func openMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard let content, var player, player.meta.engagement.treasures.waiting else { return nil }
        TreasureScheduler.markOpened(&player.meta.engagement.treasures, config: content.treasures)
        self.player = player
        return grantMattressPrize(now: now)
    }

    /// Después del segundo video: otro sorteo, una vez por colchón.
    @discardableResult
    func openExtraMattress(now: TimeInterval = Date().timeIntervalSince1970) -> MattressOutcome? {
        guard var player, player.meta.engagement.treasures.extraOpensLeft > 0 else { return nil }
        player.meta.engagement.treasures.extraOpensLeft -= 1
        self.player = player
        return grantMattressPrize(now: now)
    }

    private func grantMattressPrize(now: TimeInterval) -> MattressOutcome? {
        guard let content, let prize = TreasureRoller.roll(content.treasures, using: &rng) else { return nil }
        let coins = grant(prize.rewards, source: "treasure.\(prize.id)", now: now)
        scheduleSave()
        Log.economy.info("mattress opened: \(prize.id)")
        return MattressOutcome(prizeId: prize.id, rewards: prize.rewards, coins: coins, extraOpensLeft: mattressExtraOpensLeft)
    }

    #if DEBUG
    func debugSpawnMattress() {
        guard var player else { return }
        player.meta.engagement.treasures.waiting = true
        player.meta.engagement.treasures.extraOpensLeft = 0
        self.player = player
    }
    #endif
}
```

`GameState+Engagement.swift`: en `advanceEngagement(delta:)`, después de `advancePackages`:

```swift
        advanceTreasures(delta: delta)
```

y en `applyEngagementFixtures(arguments:)`:

```swift
        if arguments.contains("--uitest-mattress") {
            debugSpawnMattress()
        }
```

- [ ] **Step 4: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/MattressRuntimeTests -only-testing:FisuEvolutionTests/PackageRuntimeTests`
→ PASS (6 nuevos). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Treasures.swift
git add FisuEvolution/Game/State/GameState+Engagement.swift
git add FisuEvolutionTests/MattressRuntimeTests.swift
git diff --cached --stat
git commit -m "feat(colchon): El Colchón aparece, se abre con video y da otro colchón"
```

---

### Task 8: La Ruleta en la partida — el día, girar, repetir y el giro con ORO donde se puede

**Objetivo:** la ruleta andando sin UI propia. `spinWheel(_:storefrontAllows:now:)` pasa el estado
al día de hoy, cobra el giro de su fuente (regalado, video o 12 ORO por `spendOro`, sólo donde
la tienda lo permite), sortea **sobre la tabla efectiva** y acredita el premio **antes** de que la
vista anime, guardando en el acto; `repeatWheelPrize()` vuelve a dar el mismo premio una vez por
giro; `grant(.wheelSpin(n))` regala giros (el Conductor de TV despierta solo). `LootBoxGate`
decide si la tienda del jugador admite azar con ORO (Bélgica y Australia, no).

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Wheel.swift`
- Create: `FisuEvolution/Managers/LootBoxGate.swift`
- Modify: `FisuEvolution/Game/State/GameState+Rewards.swift` (`.wheelSpin` entregable)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`--uitest-wheel-spins=N`)
- Create: `FisuEvolutionTests/WheelRuntimeTests.swift`
- Create: `FisuEvolutionTests/LootBoxGateTests.swift`
- Modify: `FisuEvolutionTests/RewardGrantTests.swift` (E4a T8)

**Interfaces:**
- Consumes: T3, T4, T5, T6, T7; `chestUnlockedCharacterTypes` (`GameState+Chests.swift:134`),
  `ChestRoller.hasSomethingToGive(owned:unlocked:skins:)`, `MetaState.spendOro(_:)`,
  `DailyRewardManager.dayString(for:calendar:)`, `persistNow()` (`GameState.swift:1130`);
  `AdsRemoteConfigLoader.current()` (`AdsRemoteConfigLoader.swift:99`); **E4a T8** (`grant`).
- Produces: `struct WheelSpinOutcome: Equatable` (`segments: [WheelConfig.Segment]`, `index: Int`,
  `coins: Double`, `var segment`); `struct WheelAvailability: Equatable` (`bonus`, `videoLeft`,
  `oroLeft`, `oroCost`, `canPayOro: Bool`, `canRepeat: Bool`, `var hasFreeSpin: Bool`);
  `GameState.wheelSegments: [WheelConfig.Segment]`, `wheelOdds: [PrizeOdds]`,
  `wheelChestHasSomethingToGive: Bool`, `wheelAvailability(storefrontAllows:now:) -> WheelAvailability`,
  `spinWheel(_:storefrontAllows:now:) -> WheelSpinOutcome?` y `repeatWheelPrize(now:) -> WheelSpinOutcome?`
  (`@discardableResult`), `static func wheelDay(_ now: TimeInterval) -> String`; DEBUG:
  `debugAddWheelSpins(_:)`, `debugWheelNewDay()`, el fixture `--uitest-wheel-spins=N`.
- Produces: `enum LootBoxGate` con `static func allows(countryCode: String?, restricted: [String]) -> Bool`
  y `static func current(loader:) async -> Bool`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/LootBoxGateTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

/// El azar con ORO se apaga en Bélgica y Australia (PLAN-v2 §2, loot boxes).
@Suite("El azar con ORO, por tienda")
struct LootBoxGateTests {
    @Test("Argentina sí; Bélgica y Australia no, escriban como escriban")
    func restrictedStorefronts() {
        let restricted = ["BEL", "AUS"]
        #expect(LootBoxGate.allows(countryCode: "ARG", restricted: restricted))
        #expect(!LootBoxGate.allows(countryCode: "BEL", restricted: restricted))
        #expect(!LootBoxGate.allows(countryCode: "aus", restricted: restricted))
    }

    @Test("sin tienda conocida, no: mejor no ofrecer que ofrecer donde está prohibido")
    func unknownStorefrontFailsClosed() {
        #expect(!LootBoxGate.allows(countryCode: nil, restricted: []))
        #expect(!LootBoxGate.allows(countryCode: "", restricted: []))
    }

    @Test("la config que viaja en el bundle apaga Bélgica y Australia")
    func theBundledConfigRestricts() throws {
        let loader = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "e5-\(UUID().uuidString).json")
        )
        let config = try #require(loader.current()?.config)
        #expect(Set(config.restrictedStorefronts) == ["BEL", "AUS"])
    }
}
```

`FisuEvolutionTests/WheelRuntimeTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ruleta en la partida")
@MainActor
struct WheelRuntimeTests {
    private let day: TimeInterval = 86_400

    @Test("seis giros por video por día, y al día siguiente vuelven")
    func sixVideoSpinsADay() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        for _ in 0..<6 {
            #expect(gameState.spinWheel(.video, now: now) != nil)
        }
        #expect(gameState.spinWheel(.video, now: now) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: now).videoLeft == 0)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: now + day).videoLeft == 6)
        #expect(gameState.spinWheel(.video, now: now + day) != nil)
    }

    @Test("el premio se acredita al girar, antes de cualquier animación")
    func thePrizeIsGrantedOnSpin() async throws {
        let gameState = await makeGameState()
        for _ in 0..<6 {
            let before = try #require(gameState.player)
            let outcome = try #require(gameState.spinWheel(.video))
            let after = try #require(gameState.player)
            switch outcome.segment.reward {
            case .coinsSeconds: #expect(after.run.coins > before.run.coins && outcome.coins > 0)
            case .modifier: #expect(after.run.activeModifiers.contains { $0.sourceKey == "wheel.\(outcome.segment.id)" })
            case .oro(let amount): #expect(after.meta.oro == before.meta.oro + amount)
            case .package(let count): #expect(after.meta.engagement.packages.waiting == before.meta.engagement.packages.waiting + count)
            case .skinChest(let count): #expect(after.meta.chestsPending == before.meta.chestsPending + count)
            default: Issue.record("la ruleta dio \(outcome.segment.reward.kind)")
            }
        }
    }

    @Test("repetir da lo mismo, una sola vez por giro")
    func repeatingOnce() async throws {
        let gameState = await makeGameState()
        let outcome = try #require(gameState.spinWheel(.video))
        #expect(gameState.wheelAvailability(storefrontAllows: false).canRepeat)
        let again = try #require(gameState.repeatWheelPrize())
        #expect(again.segment.id == outcome.segment.id)
        #expect(gameState.repeatWheelPrize() == nil)
        #expect(!gameState.wheelAvailability(storefrontAllows: false).canRepeat)
        #expect(gameState.wheelAvailability(storefrontAllows: false).videoLeft == 5, "repetir no gasta un giro")
    }

    @Test("el giro con ORO cuesta 12, tiene su tope y se apaga donde la tienda no lo permite")
    func theOroSpin() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 100
        #expect(gameState.spinWheel(.oro, storefrontAllows: false) == nil)
        #expect(gameState.player?.meta.oro == 100)
        #expect(gameState.wheelAvailability(storefrontAllows: false).oroLeft == 0)
        for spin in 1...6 {
            _ = try #require(gameState.spinWheel(.oro, storefrontAllows: true))
            #expect(gameState.player?.meta.stats.oroSpentEver == 12 * spin)
        }
        #expect(gameState.spinWheel(.oro, storefrontAllows: true) == nil)
    }

    @Test("sin ORO no gira ni cobra")
    func noOroNoSpin() async {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 5
        #expect(gameState.spinWheel(.oro, storefrontAllows: true) == nil)
        #expect(gameState.player?.meta.oro == 5)
        #expect(!gameState.wheelAvailability(storefrontAllows: true).canPayOro)
    }

    @Test("un giro regalado no pide video y no vence con el día")
    func giftedSpins() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.grant(.wheelSpin(1), source: "visit.conductor_ruleta", now: now)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: now + day).bonus == 1)
        #expect(gameState.spinWheel(.bonus, now: now + day) != nil)
        #expect(gameState.spinWheel(.bonus, now: now + day) == nil)
        #expect(gameState.wheelAvailability(storefrontAllows: false, now: now + day).videoLeft == 6)
    }

    @Test("con el cofre sin nada que dar, la ruleta no tiene cofre y su peso es plata")
    func anEmptyChestLeavesTheWheel() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        #expect(gameState.wheelChestHasSomethingToGive)
        #expect(gameState.wheelSegments.contains { $0.reward.kind == .skinChest })
        let unlocked = gameState.chestUnlockedCharacterTypes
        gameState.player?.meta.milestoneSkins = content.skins.chestPool
            .filter { unlocked.contains($0.characterType) }.map(\.id)
        #expect(!gameState.wheelChestHasSomethingToGive)
        #expect(!gameState.wheelSegments.contains { $0.reward.kind == .skinChest })
        #expect(gameState.wheelSegments.map(\.weight).reduce(0, +) == 100)
        #expect(gameState.wheelOdds.map(\.id) == gameState.wheelSegments.map(\.id), "lo mostrado es lo que gira")
    }

    @Test("la ruleta y el colchón sólo dan lo que el juego sabe entregar")
    func everyPrizeIsGrantable() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let kinds = content.wheel.segments.map(\.reward.kind) + content.treasures.prizes.flatMap { $0.rewards.map(\.kind) }
        #expect(Set(kinds).isSubset(of: GameState.grantableRewardKinds))
    }
}
```

En `FisuEvolutionTests/RewardGrantTests.swift`: los argumentos de `notYetGrantable` quedan
`[RewardSpec.autoTap(perSecond: 5, seconds: 60), .nextOfflineMultiplier(3), .nextDailyMultiplier(3), .extraSlots(3)]`,
y `grantableKinds` pasa a esperar `[.coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity, .package, .wheelSpin]`.

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/WheelRuntimeTests -only-testing:FisuEvolutionTests/LootBoxGateTests`.
Expected: no compila (`spinWheel`, `LootBoxGate`).

- [ ] **Step 3: `LootBoxGate.swift`**

```swift
import Foundation
import StoreKit

/// El azar que se paga con ORO —el giro extra de la ruleta y, en E6, el cofre
/// por ORO— se apaga en las tiendas de `restrictedStorefronts` (PLAN-v2 §2:
/// Bélgica y Australia). La lista viaja en la config remota de anuncios.
enum LootBoxGate {
    /// Sin tienda conocida, no: mejor no ofrecerlo que ofrecerlo donde está
    /// prohibido.
    static func allows(countryCode: String?, restricted: [String]) -> Bool {
        guard let countryCode, !countryCode.isEmpty else { return false }
        return !restricted.contains(countryCode.uppercased())
    }

    /// La respuesta de hoy: la tienda del jugador contra la config que haya en
    /// disco (caché o respaldo del bundle, sin red). Sin config, no.
    static func current(loader: AdsRemoteConfigLoader = AdsRemoteConfigLoader()) async -> Bool {
        guard let config = loader.current()?.config else { return false }
        return allows(countryCode: await Storefront.current?.countryCode, restricted: config.restrictedStorefronts)
    }
}
```

- [ ] **Step 4: `GameState+Wheel.swift`**

```swift
import EconomyKit
import Foundation

/// Un giro ya resuelto: el premio se acreditó ANTES de que la rueda se mueva.
struct WheelSpinOutcome: Equatable {
    /// La tabla con la que se giró (la efectiva) y dónde cayó.
    let segments: [WheelConfig.Segment]
    let index: Int
    /// La plata acreditada (0 si el premio no era plata).
    let coins: Double

    var segment: WheelConfig.Segment { segments[index] }
}

/// Lo que la ruleta ofrece ahora.
struct WheelAvailability: Equatable {
    let bonus: Int
    let videoLeft: Int
    /// 0 donde la tienda no permite azar con ORO.
    let oroLeft: Int
    let oroCost: Int
    let canPayOro: Bool
    let canRepeat: Bool

    var hasFreeSpin: Bool { bonus > 0 || videoLeft > 0 }

    static let none = WheelAvailability(bonus: 0, videoLeft: 0, oroLeft: 0, oroCost: 0, canPayOro: false, canRepeat: false)
}

/// La Ruleta en la partida (PLAN-v2 E5).
extension GameState {
    /// La tabla que se muestra y la que gira: si un cofre hoy no tendría nada
    /// que dar, su peso pasa a la plata.
    var wheelSegments: [WheelConfig.Segment] {
        content?.wheel.effectiveSegments(chestHasSomethingToGive: wheelChestHasSomethingToGive) ?? []
    }

    var wheelOdds: [PrizeOdds] {
        content?.wheel.odds(chestHasSomethingToGive: wheelChestHasSomethingToGive) ?? []
    }

    /// La misma pregunta que `canOpenChest`, sin pedir cofres pendientes.
    var wheelChestHasSomethingToGive: Bool {
        guard let content, let player else { return false }
        return ChestRoller.hasSomethingToGive(
            owned: player.meta.allOwnedSkins, unlocked: chestUnlockedCharacterTypes, skins: content.skins
        )
    }

    func wheelAvailability(storefrontAllows: Bool, now: TimeInterval = Date().timeIntervalSince1970) -> WheelAvailability {
        guard let content, let player else { return .none }
        let state = player.meta.engagement.wheel.rolledOver(to: Self.wheelDay(now))
        let oroLeft = storefrontAllows ? WheelRoller.spinsLeft(.oro, state: state, config: content.wheel) : 0
        return WheelAvailability(
            bonus: WheelRoller.spinsLeft(.bonus, state: state, config: content.wheel),
            videoLeft: WheelRoller.spinsLeft(.video, state: state, config: content.wheel),
            oroLeft: oroLeft,
            oroCost: content.wheel.oroSpinCost,
            canPayOro: oroLeft > 0 && player.meta.oro >= content.wheel.oroSpinCost,
            canRepeat: state.repeatableSegmentId != nil
        )
    }

    /// Gira. El premio se sortea y se acredita acá, y se guarda en el acto: si
    /// matan la app en medio de la animación, el premio ya es del jugador. El
    /// video (o el ORO) ya se cobró antes de llamar.
    @discardableResult
    func spinWheel(
        _ source: WheelSpinSource,
        storefrontAllows: Bool = false,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> WheelSpinOutcome? {
        guard let content, var player else { return nil }
        var wheel = player.meta.engagement.wheel.rolledOver(to: Self.wheelDay(now))
        if source == .oro {
            guard storefrontAllows, WheelRoller.spinsLeft(.oro, state: wheel, config: content.wheel) > 0,
                  player.meta.spendOro(content.wheel.oroSpinCost)
            else { return nil }
        }
        let segments = wheelSegments
        guard WheelRoller.consume(source, state: &wheel, config: content.wheel),
              let index = WheelRoller.roll(segments, using: &rng)
        else { return nil }
        wheel.repeatableSegmentId = segments[index].id
        player.meta.engagement.wheel = wheel
        self.player = player
        let coins = grant(segments[index].reward, source: "wheel.\(segments[index].id)", now: now)
        Task { await persistNow() }
        Log.economy.info("wheel spin (\(source.rawValue)): \(segments[index].id)")
        return WheelSpinOutcome(segments: segments, index: index, coins: coins)
    }

    /// "Repetir premio": otro video que vuelve a dar lo mismo (no es otro
    /// giro). Una vez por giro.
    @discardableResult
    func repeatWheelPrize(now: TimeInterval = Date().timeIntervalSince1970) -> WheelSpinOutcome? {
        guard let content, var player else { return nil }
        var wheel = player.meta.engagement.wheel.rolledOver(to: Self.wheelDay(now))
        guard let id = wheel.repeatableSegmentId,
              let segment = content.wheel.segments.first(where: { $0.id == id })
        else { return nil }
        wheel.repeatableSegmentId = nil
        player.meta.engagement.wheel = wheel
        self.player = player
        let coins = grant(segment.reward, source: "wheel.\(segment.id)", now: now)
        Task { await persistNow() }
        Log.economy.info("wheel prize repeated: \(segment.id)")
        let segments = wheelSegments
        let index = segments.firstIndex { $0.id == id }
        return index.map { WheelSpinOutcome(segments: segments, index: $0, coins: coins) }
            ?? WheelSpinOutcome(segments: [segment], index: 0, coins: coins)
    }

    /// El día de los cupos: el mismo que el del diario.
    static func wheelDay(_ now: TimeInterval) -> String {
        DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now))
    }

    #if DEBUG
    func debugAddWheelSpins(_ count: Int) {
        guard var player, count > 0 else { return }
        player.meta.engagement.wheel.bonusSpins += count
        self.player = player
    }

    /// El próximo acceso arranca un día nuevo: los cupos vuelven.
    func debugWheelNewDay() {
        guard var player else { return }
        player.meta.engagement.wheel.day = nil
        self.player = player
    }
    #endif
}
```

- [ ] **Step 5: `grant` y la puerta de test**

`GameState+Rewards.swift`: `.wheelSpin` se suma a `grantableRewardKinds` (al final de la lista)
y en `grant`:

```swift
        case .wheelSpin(let count):
            player.meta.engagement.wheel.bonusSpins += count
        case .autoTap, .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots:
            return 0
```

El doc de `grantableRewardKinds` pierde "E5 suma `.package` y `.wheelSpin`;" (ya los sumó) y
queda "E6 suma `.autoTap`, los multiplicadores del próximo offline y diario y `.extraSlots`".

`GameState+Engagement.swift`, en `applyEngagementFixtures(arguments:)`:

```swift
        if let count = Self.fixtureValue("--uitest-wheel-spins=", in: arguments).flatMap(Int.init) {
            debugAddWheelSpins(count)
        }
```

- [ ] **Step 6: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/WheelRuntimeTests -only-testing:FisuEvolutionTests/LootBoxGateTests -only-testing:FisuEvolutionTests/RewardGrantTests`
(más `VisitorRuntimeTests` si E4b T2 ya entró) → PASS (11 nuevos; con `.wheelSpin` entregable el
guion del Conductor entra al sorteo de E4).
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Wheel.swift
git add FisuEvolution/Managers/LootBoxGate.swift
git add FisuEvolution/Game/State/GameState+Rewards.swift
git add FisuEvolution/Game/State/GameState+Engagement.swift
git add FisuEvolutionTests/WheelRuntimeTests.swift
git add FisuEvolutionTests/LootBoxGateTests.swift
git add FisuEvolutionTests/RewardGrantTests.swift
git diff --cached --stat
git commit -m "feat(ruleta): la Ruleta gira, repite y cobra ORO sólo donde la tienda lo permite"
```

---

### Task 9: Cierre de E5a

**Objetivo:** la verificación de punta a punta del motor y la documentación que deja a E5b
arrancando sin leer esta sesión. La hace el controlador.

- [ ] **Step 1: Oráculo completo**

Run: `Tools/v2/oraculo.sh completo`.
Expected: `VERDE`, con `PackageRollerTests`, `PackageSchedulerTests`, `PackagesConfigTests`,
`TreasureSchedulerTests`, `TreasureRollerTests`, `TreasuresConfigTests`, `WheelTableTests`,
`WheelStateTests`, `WheelRollerTests`, `EngagementPrizesStateTests`, `PrizesContentTests`,
`PackageRuntimeTests`, `MattressRuntimeTests`, `WheelRuntimeTests` y `LootBoxGateTests` en la
salida. `rojos-declarados.txt` no cambió por E5a. El `pacing-sim` da lo mismo que antes (no
modela premios).

- [ ] **Step 2: Los escenarios a mano**

1. `--uitest-packages=2` en el simulador: el panel de debug no tiene botones todavía (E5b T2);
   se mira el log (`package opened: …`) llamando a `openPackage()` desde un breakpoint, o se
   espera a E5b.
2. Con `--uitest-engagement` y `spawnIntervalSeconds` bajado a mano en un build local (no se
   commitea): a los 2 min de juego cae un paquete, a los 8 un colchón; Home y volver: los relojes
   siguieron donde estaban.
3. Matar la app con dos paquetes esperando: al volver siguen ahí (`meta.engagement`).

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e5.md`: la tabla por tarea con su commit, y el porqué de cada default
   de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: "E5a — el motor del Paquete, el Colchón y la Ruleta": los tres puros en
     `EconomyKit/Prizes/`, el estado en `meta.engagement`, el paquete por el embudo con
     `Origin.package`, la ruleta que acredita antes de animar, `LootBoxGate`.
   - **§5**: los defaults de las dudas que el dueño no cambió.
   - **§7**: las trampas nuevas — "un paquete sólo trae lo que FisuJobs vende con lugar
     (`PackageRoller.eligibleTypes` = `jobState == .hirable`): si cambia una regla de FisuJobs,
     `candidatesMatchFisuJobs` se pone rojo"; "la ruleta muestra y sortea la tabla EFECTIVA:
     nunca dibujar `wheel.segments` crudo"; "`LootBoxGate` falla cerrado: sin tienda conocida no
     hay giro con ORO"; las que aparezcan.
   - **§9**: este plan y la sesión.
3. Journal AVO al día y `LOCK` liberado.

- [ ] **Step 4: Commit de docs**

```bash
git add Docs/SESION-2026-10-07-v2-e5.md
git add Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e5): cierre de E5a — el motor del Paquete, el Colchón y la Ruleta"
```

---

## Lo que E5a le deja a E5b y a otras épicas

- **E5b** arranca con todo esto en la punta: `packagesWaiting`, `packagesBlocked`,
  `packageCandidates`, `openPackage()` (con `PackageOpenResult`) y la llegada en el embudo con
  `Origin.package` (E5b T3 la abre en el turno del tablero); `mattressWaiting`, `openMattress()`,
  `openExtraMattress()`, `MattressOutcome`, `content.treasures.odds`; `wheelSegments`,
  `wheelOdds`, `wheelAvailability(storefrontAllows:)`, `spinWheel`, `repeatWheelPrize`,
  `WheelSpinOutcome`, `content.wheel.spinSeconds`; `LootBoxGate.current()`; las tres puertas de
  test y los `debug*`.
- **E6** (tienda de ORO y ofertas):
  - "mejor proveedor N1/N2/N3" cambia el `0` de `openPackage()` por su nivel (la tabla de r ya
    está en `packages.json`);
  - "+1/+2/+3 giros diarios" suma su nivel a `WheelRoller.spinsLeft(.video, …)` (o a
    `videoSpinsPerDay` efectivo) en un solo lugar;
  - "Giro extra de ruleta, 12 ORO, 6/día" **ya existe**: el estante de Suerte llama a
    `spinWheel(.oro, storefrontAllows:)` o abre la ruleta;
  - "Lluvia de paquetes 60 s" = `grant(.modifier(effect: .packageRateMultiplier, magnitude: 10, seconds: 60), …)`;
    el reloj de T6 ya lo lee;
  - "Mudanza = 3 Paquetes" = `grant(.package(3), …)`, pasa el tope;
  - el cofre por ORO reusa `LootBoxGate` (y la `OddsDisclosureView` de E5b).
- **E7b** (columna lateral): lee `GameState.prizeAccess` (E5b T2) y llama a
  `packageTapped()`, `mattressTapped()` y `openWheel()` (E5b T2); la lluvia de paquetes por video
  va por `RewardedPlacement.treasure`. 🔒 del dueño: E5 no pone nada en la columna; ver E5b.
- **E9**: "Durante el núcleo no nace ningún paquete ni visitante" ya vale (los relojes miran
  `tutorialPhaseActive`); el colchón no tiene paciencia que congelar (espera hasta que lo abras).
  Las lecciones las declara E5b T5.
- **E2b**: los premios nuevos **acortan el juego** (PLAN-v2 §6): un paquete gratis cada 2 min de
  juego son ~30 empleados por hora sin anuncios. Las perillas: `packages.json`
  (`spawnIntervalSeconds`, `maxWaiting`, `windowTiers`, las razones), `treasures.json` (intervalo,
  pesos, minutos) y `wheel.json` (pesos, minutos, multiplicadores). El simulador tiene que
  modelarlos (perfil `.ads` para colchón y ruleta; el paquete es gratis, ver duda 10).
- **E10**: notas a App Review — la ruleta muestra su tabla de probabilidades en la misma pantalla,
  el colchón en su popup; el giro con ORO se apaga por tienda (`restrictedStorefronts`).

## Para el dueño / dudas

Cosas que la spec deja abiertas o que el código contradice. **Ninguna frena**: la ejecución sigue
con el default anotado hasta que el dueño diga otra cosa.

1. **Un paquete nunca trae a alguien que no viste.** "Candidatos = tipos contratables con lugar"
   (PLAN-v2 E5) son los vistos en la run: FisuJobs no vende lo que no viste (RF-03). Entonces "un
   tipo nunca visto pasa por la revelación de E1" no se da; la red de E1 queda igual por si la
   regla cambia. **Default:** así (el paquete no espoilea la cadena).
2. **El reloj del paquete se frena con dos esperando, y la Lluvia respeta el tope.** "Hasta 2 en
   espera" se leyó como "con 2 no cae más": el reloj espera y, al abrir uno, el siguiente tarda
   un intervalo entero. La Lluvia de Paquetes (×10) cae uno cada 12 s, pero sigue topeada en 2:
   hay que irlos abriendo ("andá recogiendo, muchachos"). **Default:** así; si el dueño quiere que
   la Lluvia llene el buzón, se le da su propio tope en `packages.json`.
3. **Paquetes y colchón sobreviven a la reencarnación.** Viven en `meta.engagement` (E1 duda 1);
   el sorteo del paquete es al abrirlo, así que uno guardado de la run anterior trae a alguien de
   la run nueva. **Default:** sobreviven; si tienen que morir, se resetean en
   `PrestigeCalculator.applyReincarnation`.
4. **La tabla de la ruleta es una propuesta.** E2a fija los premios (plata 30–60 min, ×2/×3/×5 por
   10 min, ORO 1–3, paquete, cofre) pero no los pesos. **Default:** plata 30 min 18 · 45 min 12 ·
   60 min 8 · ×2 14 · ×3 8 · ×5 3 · 1 ORO 15 · 3 ORO 5 · Paquete 12 · Cofre 5 (= 100); el cofre
   vacío pasa a la plata de 30 min. E2b calibra con el simulador.
5. **La tabla del colchón también.** **Default:** plata 20 min 60 % · un Paquete 25 % · 2 ORO
   15 %; "otro colchón" una vez por colchón; el reloj de 8 min corre sólo sin uno esperando.
6. **"Repetir premio" no gasta un giro del cupo de 6.** Es otro video aparte, una vez por giro, y
   queda guardado hasta el próximo giro o el cambio de día. Son hasta 12 videos de ruleta por día.
   **Default:** así.
7. **Los giros regalados no vencen con el día** (el Conductor, un visitante, una oferta).
   **Default:** así: fueron regalados.
8. **El giro con ORO falla cerrado y lo decide E5.** Sin tienda conocida (`Storefront.current`
   nulo) o sin config, no se ofrece. `LootBoxGate` nace en E5 (PLAN-v2 lo ponía en E6 junto al
   cofre por ORO, que lo reusa). **Default:** así.
9. **"`placeGrantedUnit` generalizado" ya no existe.** Era un `private` de `+Bonus` que mutaba el
   tablero en el acto y perdía el regalo con el piso lleno; E1 T12 lo borra. Lo generalizado es
   el embudo: `planArrival(…, origin: .package)` + `placeUnit` en su turno. **Default:** el
   embudo, con la devolución al buzón si en su turno ya no entra.
10. **El paquete es gratis y frecuente.** Cada 2 min de juego, sin anuncio (PLAN-v2 §2), son ~30
    empleados por hora, por encima de lo que da cualquier otra fuente sin video. PLAN-v2 E2b lo
    pone en el perfil `.ads` del simulador. **Default:** se implementa tal cual; la palanca es
    `packages.json` (`spawnIntervalSeconds`) y E2b lo calibra.
11. **CloudKit:** el buzón y el colchón viajan con el ganador de un conflicto; la ruleta toma el
    máximo de cupos usados del mismo día. **Default:** así (CloudKit sigue apagado por flag).
12. **El cofre de la ruleta suma un cofre pendiente**, no lo abre: se abre desde Regalos como los
    demás, con su regla de desbloqueo. **Default:** así.
