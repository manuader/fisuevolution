# E2a — Mecánicas de economía · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que la 2.0 tenga las mecánicas de economía que el dueño decidió —reintegro al
fusionar, el amortiguador del salto de precio, un "+6 % por compra" que dice la verdad, pisos
en marcha, piso móvil para reencarnar y "Fusionar todo"— **detrás de perillas que valen lo de
la v1**, y que todos los premios se paguen en minutos de producción real, con las tres
carreras nuevas.

**Architecture:** las cuentas viven puras en EconomyKit: `RewardScale` (premios en minutos),
`PriceCushion` (el amortiguador, sobre el `priceRelief` que nace en el save v6),
`RunState.refundMergeCounts` (reintegro), `StaffedFloors` (pisos en marcha),
`PrestigeCalculator.lastRunWallGoal` (piso móvil), `BoardChangePlanner.planMergeAll` y
`EconomyKnobs` (las perillas juntas). `PacingSimulator` usa esas mismas funciones, así que con
las perillas en su valor de la v1 reproduce la línea de base exacta. La app sólo cablea: las
fuentes de premios pasan a minutos, las fusiones le pasan `config:` a EconomyKit y las
pantallas muestran lo que EconomyKit calcula.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · EconomyKit (SPM puro, `Sendable`) · Swift Testing · XCUITest · XcodeGen (el
`.xcodeproj` no se versiona).

**Fuente:** `Docs/PLAN-v2.md` §4 "E2 — Economía y pacing", **sólo E2a** (la calibración y el
contrato son E2b: acá no se planifican, pero la sección "Lo que E2a le deja a otras épicas"
dice qué le entrega). También la tabla de §4 (ítems 10 y 12, C1, C2 y C5) y §2 (decisiones del
dueño: **no se re-litigan**). Lo que el código contradice está en "Para el dueño / dudas", con
un default que no frena.

**Rama de la épica:** `v2/e2a-mecanicas`, desde `version-2` **con E1 T4 adentro**. Cada tarea
sale de su punta en un worktree propio (`Agent(isolation: "worktree")`, PLAN-v2 §0.1) y el
controlador integra de a una.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build (una `var` que no se muta, también). Nada de `Timer` (regla 2).
- **Con cada perilla en su valor de la v1, el simulador reproduce la línea de base exacta**:
  `pacing-sim` da **Dios en 30,73 h activas · 13 reencarnaciones** (HANDOFF §6) y `PacingTests`
  sigue en sus bandas sin re-pinear nada. Las perillas nuevas se leen con
  `decodeIfPresent ?? <valor v1>` y **`economy.json` no las declara**: las declara E2b.
- **Ningún campo nuevo en `run` ni en `meta`.** Después de E1, uno más es save v7 (plan de E1,
  "Save v6"). E2a usa `RunState.priceRelief` y `MetaState.lastRunMaxTier`, que nacen en E1 T4.
- **Lo mostrado es lo aplicado.** Todo número nuevo que ve el jugador sale de la misma función
  de EconomyKit que cobra, y los tests lo comparan contra el efecto real, nunca contra una copia
  de la fórmula (trampa 24).
- **El simulador no reimplementa nada**: cotiza por `TowerActions.hireQuote`, compra por
  `registerHire`, fusiona con `refundMergeCounts` y `raiseFrontier(to:cushion:)`, cobra con
  `StaffedFloors` y reencarna por `PrestigeCalculator.canReincarnate` (trampa "duplicar la
  fórmula fue lo que llevó a que el simulador cotizara distinto que el juego").
- **Un parámetro que es una garantía va sin default** (HANDOFF §7): `config:` en las fusiones,
  `cushion:` en `raiseFrontier`/`registerHire`, `tiers:` en `applyTap`.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo Swift de la app o de sus tests**, en el mismo paso. Un archivo nuevo del paquete no
  lo pide (el proyecto referencia el paquete, no sus archivos).
- **Strings nuevos, es + en, en el mismo commit que la vista**, siempre por snapshot
  `Tools/v2/claves-pendientes/e2a-tN.json` y `Tools/v2/catalogo.py aplicar` (E3a T1, formato
  canónico, trampa 29). Si en su ola la tarea es dueña de `Localizable.xcstrings` (lo dice el
  despacho), commitea el catálogo y borra el JSON; si no, commitea sólo el JSON y descarta el
  catálogo (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`). A una clave con
  `%@` se le interpola un `String`, nunca un `Int` (trampa 5).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis). **FisuJobs es la referencia visual**: `PanelCard`/`GameCard`, `StateBadge`,
  `ActionPill`, `Tokens`, paleta de la casa. El panel de debug sigue siendo una `List` sin
  catálogo (`DebugPanelView` no shippea).
- **Nada nuevo corre bajo `--uitest*`** salvo que el test lo pida. Las perillas de debug se
  borran con `--uitest-reset`.
- EconomyKit no conoce UI ni `upgrades.json`. `EconomyKitTests` no tiene recursos: sus tests van
  con `fx*`; los hechos de los JSON reales se pinean del lado de la app.
- Código nuevo limpio y con pocos comentarios (regla del dueño); los heredados no se borran por
  deporte, pero **el que deja de ser verdad se reescribe en el mismo commit** (los que dicen
  "factor sobre `passiveUnlockCost`", sobre todo).
- **Commits en español, estilo `feat(economia): …`, SIN `Co-Authored-By`.** Staging selectivo
  por archivo y `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración →
  `Tools/v2/oraculo.sh rapido` (o `completo` donde la tarea lo dice) →
  `Docs/SESION-<fecha>-v2-e2a.md` → las cuatro ediciones de `Docs/HANDOFF.md` → journal AVO y
  latido del `LOCK`. Ningún subagente toca `Docs/`, `handoffs/`, el journal ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

**El oráculo del run** juzga cada commit integrado:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
```

- Termina en 0 (`VERDE`) sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`. **E2a no
  declara rojos.** Los tests nuevos entran solos (el oráculo corre las suites enteras): las
  suites de EconomyKit suben la cuenta de `economykit`, las de la app la de `unit`. Un VERDE con
  la misma cuenta que antes de sumar tests no probó nada (HANDOFF §6).
- `rapido` al cerrar T1–T6 (EconomyKit puro). `completo` al cerrar T7 (toca
  `StoreManagerTests`, que sólo corre en la suite `store-unit` de 18.6), T8–T14 (cambian lo que
  el jugador ve o fusiona) y T15.
- **El `pacing-sim` del `completo` es el juez de "con el default, la base exacta"**: cada
  `completo` de E2a tiene que imprimir `Dios en 30,73 h · 13 reencarnaciones` (o los números de
  la línea de base vigente si E1 T16 los re-tomó). Un número distinto es un knob que se coló o
  un camino que no pasa por la función de EconomyKit: se busca antes de integrar.

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…") (trampa del cierre de cofres)
swift test --package-path Packages/EconomyKit --filter "RewardScaleTests|PriceCushionTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE (sin "()" no corre nada)
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e2a-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e2a" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e2a" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/PriceCushionContentTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y de `-only-testing:`). Ante un rojo en masa, antes de culpar al
código: `uptime`, `ps aux | grep '[x]codebuild'` y qué árbol compiló (trampas 16, 33 y 44).

## Las referencias, verificadas contra el árbol (`68bb47c`)

| Lo que cita PLAN-v2 o E1 | Dónde está hoy | Qué significa para E2a |
|---|---|---|
| `coinReward` de logros, `GameState+Achievements.swift:453-470` | igual; `rewardTier` en `:484-489` (`max(frontera, firstTier del piso máximo de la cuenta)`) | T1 sube la cuenta a `RewardScale`; T11 la deja como envoltorio (E1 T14 la vuelve `static` para compensar videos; E3b T9 la usa para compartir) |
| premios con `passiveUnlockCost(maxTier) × factor` | diario `ContentSystems.swift:428`, y el día 7 sin special con **`× 6.0` escrito en código** (`:423`); asado `:309-314` (`magnitude` 4,0); cofres `GameState+Chests.swift:241` (6 / 12); carrera `GameState+Bonus.swift:516` y `:546` (`chestFactor` 6); packs `GameState+Store.swift:238-242` y `:266-278` (`coinFactor` 40/15/90/220) | T7 (cofres, packs), T11 (diario, asado), T12 (carreras) |
| `hireCost` `EconomyConfig.swift:428-438` | `:440-450`, con `purchases: Int` (E1 T3 lo pasa a `Double`) | el amortiguador divide su resultado; la fórmula no se toca |
| contadores `TowerActions.swift:306-309` | `:302-307` (E1 T3 los muda a `RunState.registerHire`) | T3 le suma el amortiguador a `registerHire` |
| frontera al fusionar | `TowerActions.swift:373` (E1 T3 → `raiseFrontier`; E1 T7 → el `land` privado) | T9 |
| `PrestigeCalculator.canReincarnate` | `PrestigeCalculator.swift:12-14` (sólo pide ORO ≥ 1) | T5 |
| pasivo base | `IncomeTicker.basePassivePerSecond`, `IncomeTicker.swift:14-29` (E1 T1, **ya en el árbol**) | T1 cotiza ahí; T4 multiplica ahí |
| el toque | `GameActions.swift:18-37`, `applyTap(type:state:floorTable:now:)` **sin `tiers`** | T4 le suma `tiers:` (1 llamada en la app, `GameState+Actions.swift:24`; 10 en `GameActionsTests`) |
| simulador: compra y fusión | compra `PacingSimulator.swift:598-605`; fusión `:624-679`, frontera `:662-663` | T2, T3 |
| simulador: pasivo, toque, offline | `:787-796`, `:861-884`, `:892-897` | T4 |
| simulador: reencarnar | `maybeReincarnate` `:683-701` (no pasa por `canReincarnate`) | T5 |
| `floors[].capacity` | `economy.json`: 10 en los diez pisos; pineado en `GameContentValidationTests.swift:594` | E2a **no** cambia el dato (duda 2) |
| `PrestigeButton` | `UI/HUD/PrestigeButton.swift:23` (se ve con `prestigeAvailable ∨ prestigeTeaser`); `prestigeAvailable` sale de `canReincarnate` en `GameState.swift:1035-1036` | T8 no toca `GameState.swift` |
| `GameContent.economy` | `GameContentLoader.swift:6`, `let` | T9 lo vuelve `var` |
| `content` | `GameState.swift:400`, `private(set)`; el bootstrap lo carga en `:509-511` y corre `applyLaunchArgumentDefaults` en `:522-525` | T9 (`replaceEconomy`), T14 (perillas al arrancar, sin tocar `GameState.swift`) |
| `var economy: StandardEconomy?` | `GameState.swift:404`, settable desde un test | T8 inyecta la perilla del piso móvil por acá |
| eventos negativos | `events.json`: `devaluacion` (ingresos ×0,5), `cayo_mercado_pago` (contratar ×2), `corralito` (`isBuff: false`) | T12 (Obra social) |
| `careers.json` | programador `coinChest` 6,0 · arquitecto `skin` obra · médico `freeBoost` café · abogado `temporaryModifier` 0,5 × 600 s | T12 |
| validación de carreras | `GameContentLoader.swift:174-214` (un tipo de premio por carrera, payload por tipo) | T12 |
| texto del asado | `bonus.effect.payout %@` = "Una picada de plata %@, cada vez", con `%@` = "×4" (`EffectDescriptor.amount(forBoost:)` da `.multiplier` para `.periodicPayout`) | T11 suma `EffectUnit.minutes` |
| la luz verde del piso | `ElevatorPanelModel.isStaffed` **no existe todavía**: la crea E3a T8 (`isUnlocked && occupied >= capacity`, plan `2026-10-07-v2-e3a-ux-nucleo.md:1889-1902`) | T13 pinea que coincide con `StaffedFloors` |
| `DebugPanelView` | `UI/DebugPanelView.swift` (80 líneas, `List` sin catálogo, todo `#if DEBUG`) | T14 |

## Las APIs de E1 que E2a consume (todavía NO están en el árbol)

Se citan como las define `Docs/superpowers/plans/2026-10-06-v2-e1-correcciones-criticas.md`. **El
paso 0 de cada tarea comprueba con `grep` que las que usa existen**; si falta una, la tarea para
con `NEEDS_CONTEXT` y no inventa la API.

| E1 | API | La usan |
|---|---|---|
| **T3** | `RunState.raiseFrontier(to:) -> Bool` (`@discardableResult`, sólo sube); `maxTierReached` `public internal(set)` | T1, T3, T5, T8, T9 |
| **T3** | `RunState.registerHire(floorId:typeId:)`; `hireCounts`, `hireCountsByType: [String: Double]`; `HireQuote.purchases: Double`; `EconomyConfig.hireCost(…, purchases: Double)` — "los contadores en `Double` los necesita el reintegro de E2a" | T2, T3 |
| **T3** | `TowerActions.hire(quote:state:tower:floorTable:config:countsAsPurchase:)`, sin default; la app pasa `countsAsPurchase: quote.cost > 0` | T3, T12 |
| **T4** | `RunState.priceRelief: Double` (default 1 = precio v1; `run = .fresh` lo vuelve a 1) | T3, T9 |
| **T4** | `MetaState.lastRunMaxTier: Int` (0 = sin requisito; lo graba `applyReincarnation`) | T5, T8 |
| **T7** | `BoardChange`, `BoardChangePlanner` (con el `fits` privado), `BoardChangeApplier.apply(_:state:tower:tiers:floorTable:)`, `TowerActions.evolveUnit`, `placeUnit` y el `land` privado | T6, T9 |
| **T9** | `GameState+BoardChanges.swift`: `enqueueBoardChange(_:)`, `beginNextBoardChange()`, `confirmBoardChange(id:)`, `pendingBoardChanges` | T9, T14 |
| **T11** | `GameState.eventIsApplicable(_ event:) -> Bool` en `+Bonus` | T12 |
| **T12** | `chooseCareer` y los videos pasan por el embudo; `performInstantMerge` se borró (E1 T12, relevo 8) | T9 |
| **T13** | `ActiveModifier.Effect.spendingFrozen`; el `switch` de `ActiveBonusBuilder.effectText` con ese caso; `escapeActiveEvent(now:)` | T12 |
| **T14** | `coinReward(seconds:player:content:economy:)` `static`; `discardBoardChange` con `switch` exhaustivo sobre `BoardChange.Origin` | T11, T14 |
| **T15** | `ActiveModifier.Effect: CaseIterable`; `EffectContractTests` (`applied(_:as:)`, `modifierEffects`, `boostEffects`, `careerPreviewEqualsCredited`) | T11, T12, T13 |

## Las perillas de E2a en una página

| Perilla | Dónde (`economy.json`) | v1 = default | Qué hace | Lo que pide PLAN-v2 (lo fija E2b) |
|---|---|---|---|---|
| `hire.mergeRefundCounts` | `hire` | **0** | fusionar un par devuelve `r` compras a la curva del tipo y de su piso | se barre en pares con `hire.defaultCostGrowth`: (1,12; 1) da ~1,058 si fusionás |
| `hire.priceReliefPurchases` | `hire` | **0** (apagado) | el amortiguador: `K` compras para pagar el salto | 24 |
| `staffedFloorBonus` | raíz | **0** | pisos en marcha: + por piso con todos sus lugares ocupados | 0,05 |
| `oro.requiresLastRunWall` | `oro` | **false** | piso móvil: para reencarnar, llegar al tier más alto de la run anterior | true |
| `floors[].capacity` | `floors` (ya existe) | 10 | lugares por piso | 15 |
| `hire.defaultCostGrowth` | `hire` (ya existe) | 1,06 | la curva por compra | par del reintegro |

`EconomyKnobs` las junta y `EconomyConfig.tuned(_:)` las aplica pasando por el JSON (el mismo
camino que el `economy.json`). Lo usan los tests, el panel de debug (T14) y el CLI de E2b.

## El amortiguador en una página

```
v1:          precio(tipo, frontera f, n) = hireCost(...)       ← anclado a f: subir f lo multiplica por J
             J(f→f+1) = yieldGrowth / priceGrowth · escalada   ← 2,8/1,5 = ×1,87 en el callejón,
                                                                  ×1,6 más desde el tier 8: ×2,99
amortiguado: precio = hireCost(...) / D                        ← D = run.priceRelief (E1 T4), ≥ 1
             al subir la frontera:   D ×= J                    ← el precio no salta
             cada compra que cuenta: D = max(1, D / ρ),  ρ = J(f−1→f)^(1/K)
                                                               ← +4,7 % extra por compra con K = 24
             después de K compras:   D = 1                     ← vuelve EXACTO a la v1
```

`D` divide a todos los tipos por igual, así que la regla de precios (§5.2: comprar hondo no es
atajo) y la compuerta no cambian. Apagado (`K = 0`), el precio ignora `D` y la primera compra lo
vuelve a 1. Las subidas de frontera de la carga (`TowerReconciler`) y del panel de debug no
amortiguan.

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/RewardScale.swift` | **nuevo** — premios en minutos: producción base con piso, `rewardTier` con el tope de frontera + 3 | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift` | **nuevo** — las perillas juntas y `EconomyConfig.tuned(_:)` | 2–5 |
| `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` | `hire.mergeRefundCounts`, `hire.priceReliefPurchases`, `staffedFloorBonus`, `oro.requiresLastRunWall` | 2–5 |
| `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` | `refundMergeCounts`; `raiseFrontier(to:cushion:)`, `registerHire(…cushion:)` | 2, 3 |
| `Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift` | **nuevo** — el amortiguador | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` | quotes ÷ D, compra con amortiguador, `nextHireStep`, `mergeRelief`; T9: `config:` en las fusiones; T12: contratación gratis | 3, 9, 12 |
| `Packages/EconomyKit/Sources/EconomyKit/StaffedFloors.swift` | **nuevo** — pisos en marcha | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift`, `GameActions.swift` | el bono en el pasivo y en el toque | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift` | `canReincarnate` con el piso móvil, `lastRunWallGoal` | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` | reintegro, amortiguador, bono, `wantsToReincarnate`, `maxTierPerRun` | 2–5 |
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` | `planMergeAll`; T9: `config:` | 6, 9 |
| `Packages/EconomyKit/Sources/EconomyKit/ChestsConfig.swift` | `completedPayoutMinutes`, `prestigePayoutMinutes` | 7 |
| `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` | `.freeHire`, `.eventImmunity`, `ModifierMath.activeUntil` | 12 |
| `FisuEvolution/Game/State/GameState+RewardScale.swift` | **nuevo** — `coinPayout(minutes:player:content:)` | 7 |
| `FisuEvolution/Game/State/GameState+Chests.swift`, `+Store.swift`, `Managers/Store/ProductCatalog.swift` | cofres y packs en minutos | 7 |
| `Resources/Config/chests.json`, `products.json` | `…PayoutMinutes`, `coinMinutes` | 7 |
| `FisuEvolution/Game/State/GameState+Prestige.swift`, `UI/HUD/PrestigeButton.swift`, `UI/Popups/PrestigeView.swift` | la meta del piso móvil | 8 |
| `FisuEvolution/Game/State/GameState.swift` | `replaceEconomy(_:)` (DEBUG) | 9 |
| `FisuEvolution/Managers/GameContentLoader.swift` | `var economy`; T12: validación de carreras | 9, 12 |
| `FisuEvolution/Game/State/GameState+Actions.swift` | `applyTap(…tiers:)` (T4), `applyMerge(…config:)` (T9) | 4, 9 |
| `FisuEvolution/Game/State/GameState+BoardChanges.swift` | `apply(…config:)` (T9), `enqueueMergeAll` (T14) | 9, 14 |
| `FisuEvolution/Game/State/GameState+Hiring.swift`, `UI/Jobs/FisuJobsView.swift` | "+6 % por compra · fusionar lo abarata 11 %" | 10 |
| `FisuEvolution/Managers/ContentSystems.swift` | diario y asado en minutos | 11 |
| `FisuEvolution/Managers/ContentConfigs.swift` | `Day.minutes` (T11); carreras nuevas (T12) | 11, 12 |
| `FisuEvolution/Managers/EffectDescriptor.swift` | `EffectUnit.minutes` | 11 |
| `FisuEvolution/Game/State/GameState+Bonus.swift` | llamadas del diario y el asado (T11); carreras, inmunidad y corte (T12) | 11, 12 |
| `FisuEvolution/Game/State/GameState+Achievements.swift`, `+AdOffers.swift` | `coinReward` → `RewardScale`; llamada del asado | 11 |
| `Resources/Config/daily_rewards.json`, `boosts.json`, `careers.json` | minutos | 11, 12 |
| `FisuEvolution/Game/State/ActiveBonus.swift`, `UI/HUD/ActiveBonusBar.swift` | chips de los dos efectos nuevos | 12 |
| `FisuEvolution/Game/State/GameState+Tower.swift`, `UI/Popups/FloorMapView.swift` | "Pisos en marcha 4/10 · +20 %" | 13 |
| `FisuEvolution/Game/State/GameState+Debug.swift`, `UI/DebugPanelView.swift` | variantes y perillas, "Fusionar todo" | 14 |
| tests EK | `RewardScaleTests`, `MergeRefundTests`, `EconomyKnobsTests`, `PriceCushionTests`, `HireStepTests`, `StaffedFloorsTests`, `MovingWallTests`, `MergeAllPlannerTests`, `FreeHireTests` (nuevos) + `PacingSimulatorTests`, `GameActionsTests`, `Fixtures` y las suites de fusión (T9) | 1–9, 12 |
| tests app | `PriceCushionContentTests`, `MergeEconomyWiringTests`, `RewardBudgetTests`, `DebugEconomyKnobsTests` (nuevos) + `ChestSourcesTests`, `StorePacksTests`, `StoreTimeoutTests`, `IAPCopyTests`, `StoreManagerTests`, `GameContentValidationTests`, `PrestigePreviewTests`, `JobRowsTests`, `ContentSystemsTests`, `CareerRewardTests`, `EffectContractTests` | 3, 7–14 |

## Orden, olas y paralelismo

**Archivos por tarea** (🔥 = caliente según PLAN-v2 §0.1; ♨️ = tibio: no caliente, pero otra
épica lo toca en la misma ventana):

| T | Qué | Archivos | 🔥 / ♨️ | Depende de | Choca con (E1 y otras) |
|---|---|---|---|---|---|
| T1 | `RewardScale` (EK puro) | `RewardScale.swift`, `RewardScaleTests.swift` | — | E1 T3 (sólo los tests: `raiseFrontier`) | nada |
| T2 | reintegro (EK puro) | `EconomyConfig.swift`, `PlayerState.swift`, `PacingSimulator.swift`, `EconomyKnobs.swift`, `MergeRefundTests.swift`, `EconomyKnobsTests.swift`, `PacingSimulatorTests.swift` | 🔥 `PlayerState.swift` | **E1 T3, T4** | E1 T3/T4 (los mismos archivos de EK): después de T4 |
| T3 | amortiguador y "+6 %" (EK) | `PriceCushion.swift`, `EconomyConfig.swift`, `PlayerState.swift`, `TowerActions.swift`, `PacingSimulator.swift`, `EconomyKnobs.swift`, `PriceCushionTests.swift`, `HireStepTests.swift`, `EconomyKnobsTests.swift`, `PacingSimulatorTests.swift`, `FisuEvolutionTests/PriceCushionContentTests.swift` | 🔥 `PlayerState.swift`, `TowerActions.swift` | T2; **E1 T3, T4** | **E1 T13** (`TowerActions.swift`): antes de T13 o después de T14 |
| T4 | pisos en marcha (EK) | `StaffedFloors.swift`, `EconomyConfig.swift`, `IncomeTicker.swift`, `GameActions.swift`, `PacingSimulator.swift`, `EconomyKnobs.swift`, `GameState+Actions.swift` (1 llamada), `StaffedFloorsTests.swift`, `GameActionsTests.swift`, `EconomyKnobsTests.swift`, `PacingSimulatorTests.swift` | ♨️ `GameState+Actions.swift` | T3 (comparten `EconomyConfig`, `PacingSimulator`, `EconomyKnobs`) | **E1 T12/T13** (`+Actions`, `GameActions.swift`): antes de T12 o después de T14 |
| T5 | piso móvil (EK) | `EconomyConfig.swift`, `PrestigeCalculator.swift`, `PacingSimulator.swift`, `EconomyKnobs.swift`, `MovingWallTests.swift`, `EconomyKnobsTests.swift`, `PacingSimulatorTests.swift` | — | T4; **E1 T4** | nada en F/G |
| T6 | "Fusionar todo", el plan (EK) | `BoardChange.swift`, `MergeAllPlannerTests.swift` | — | **E1 T7** | nada (E1 T12–T14 no tocan `BoardChange.swift`) |
| T7 | cofres y packs en minutos | `GameState+RewardScale.swift`, `GameState+Chests.swift`, `GameState+Store.swift`, `ProductCatalog.swift`, `ChestsConfig.swift`, `chests.json`, `products.json`, `Fixtures.swift`, `ChestSourcesTests.swift`, `StorePacksTests.swift`, `StoreTimeoutTests.swift`, `IAPCopyTests.swift`, `StoreManagerTests.swift`, `GameContentValidationTests.swift` | ♨️ `products.json` (E6 lo reescala después) | T1; E1 T6 (`+Store`) | nada en G |
| T8 | piso móvil en pantalla | `GameState+Prestige.swift`, `PrestigeButton.swift`, `PrestigeView.swift`, `PrestigePreviewTests.swift`, `claves-pendientes/e2a-t8.json` | catálogo (snapshot) | T5; **E1 T4** | nada |
| T9 | las fusiones del juego al amortiguador y al reintegro | `TowerActions.swift`, `BoardChange.swift`, `GameState.swift` (un método), `GameContentLoader.swift` (una palabra), `GameState+Actions.swift`, `GameState+BoardChanges.swift`, `MergeEconomyWiringTests.swift` + las suites de EK que llaman a las fusiones | 🔥 `TowerActions.swift`, `GameState.swift` · ♨️ `GameContentLoader.swift` | T2, T3, T6; **E1 T7, T9, T12** | **E1 T13** (`TowerActions`), **T14** (`+BoardChanges`): después de T14 · ventana de `GameState.swift` (E3a T9/T10, E3b T5/T9) |
| T10 | "+6 % por compra" en FisuJobs | `GameState+Hiring.swift`, `FisuJobsView.swift`, `JobRowsTests.swift`, `claves-pendientes/e2a-t10.json` | ♨️ `+Hiring` · catálogo | T3, T9 (`replaceEconomy` para el test) | **E1 T13** (`+Hiring`, `FisuJobsView`); **E3b T5/T6** (`+Hiring`): de a una |
| T11 | diario, asado y logros en minutos + presupuesto | `ContentSystems.swift`, `GameState+Bonus.swift`, `GameState+Achievements.swift`, `GameState+AdOffers.swift`, `ContentConfigs.swift`, `EffectDescriptor.swift`, `daily_rewards.json`, `boosts.json`, `ContentSystemsTests.swift`, `EffectContractTests.swift`, `RewardBudgetTests.swift`, `claves-pendientes/e2a-t11.json` | 🔥 `ContentSystems.swift`, `GameState+Bonus.swift` · catálogo | T1, T7; **E1 T14, T15** | E1 T11–T15; E4/E5 (comparten `ContentSystems`/`+Bonus`): por tarea |
| T12 | carreras: contratación gratis, Juicio ganado, Obra social | `ActiveModifier.swift`, `TowerActions.swift`, `ContentConfigs.swift`, `careers.json`, `GameContentLoader.swift`, `GameState+Bonus.swift`, `ActiveBonus.swift`, `ActiveBonusBar.swift`, `FreeHireTests.swift`, `CareerRewardTests.swift`, `EffectContractTests.swift`, `claves-pendientes/e2a-t12.json` | 🔥 `TowerActions.swift`, `GameState+Bonus.swift` · catálogo | T11, T7; **E1 T11, T13, T15** | E1 T15 (`ActiveModifier`, `ContentConfigs`, `EffectContractTests`); **E4 T1** (los "cimientos" listan `freeHire` y `eventImmunity`: ver "Lo que E2a le deja") |
| T13 | pisos en marcha en el mapa, con su contrato | `GameState+Tower.swift`, `FloorMapView.swift`, `EffectContractTests.swift`, `claves-pendientes/e2a-t13.json` | catálogo | T4, T9; **E1 T15**; E3a T8 (opcional, para el test de la botonera) | nada caliente |
| T14 | panel de debug: variantes, perillas y "Fusionar todo" | `GameState+Debug.swift`, `DebugPanelView.swift`, `GameState+BoardChanges.swift`, `DebugEconomyKnobsTests.swift` | ♨️ `+Debug`, `DebugPanelView` (E3b T2/T8/T9) | T5, T6, T9 | E3b T2/T8/T9 (`DebugPanelView`): de a una |
| T15 | cierre | `Docs/` (controlador) | — | T1–T14 | — |

E2a **no toca** `RootView.swift`, `BoardScene.swift`, `SettingsView.swift` ni `project.yml`.

**Las olas** (las del calendario de PLAN-v2 §0.1, con las huellas reales de arriba):

```
Ola F   T1 ║ T2 → T3 → T4               ∥ E1 T10 ║ T11     EK puro; T3 y T4 antes de E1 T12/T13
Ola G   T5 ║ T6 ║ T7 → T8                ∥ E1 T12 → T13 → T14 ∥ E3
Ola H   T9 → T10                         ∥ E1 T15 → T16       T9 en la ventana de GameState.swift
Luego   T11 → T12 ║ T13 → T14            ∥ E4/E5 por tarea    T11/T12 después de E1 T15
Cierre  T15 (controlador)
```

**Reglas del paralelismo:**

1. T2 → T3 → T4 → T5 van en serie: comparten `EconomyConfig.swift`, `PacingSimulator.swift`,
   `EconomyKnobs.swift` y `PacingSimulatorTests.swift`. T1 y T6 no comparten archivos con nadie y
   van al lado si hay lugar en el tope de compilación (≤ 3 en todo el run; en la ola F, E1 T10 y
   T11 ya ocupan dos).
2. **T3 y T4 tienen que integrarse antes de que arranque E1 T12** (T4 toca `+Actions` y
   `GameActions.swift`, T3 `TowerActions.swift`). Si la ola F no alcanza, se corren después de E1
   T14; nunca a la vez.
3. **T9 sale de una `v2/e2a-mecanicas` con `version-2` mergeada y E1 T14 adentro.** Su paso 0 lo
   comprueba (`grep -n "func discardBoardChange" FisuEvolution/Game/State/GameState+BoardChanges.swift`
   y `grep -rn "performInstantMerge" FisuEvolution` vacío: E1 T12 lo borró).
4. **T11, T12 y T13 salen con E1 T15 adentro** (`grep -n "struct EffectContractTests" FisuEvolutionTests/EffectContractTests.swift`).
5. Las que entregan strings sin ser dueñas del catálogo commitean el snapshot y el controlador lo
   aplica al integrar.
6. Cada agente: su worktree, su DerivedData (`build/DD-e2a`) y su simulador por UDID, que apaga y
   borra al terminar.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` (async, **no** throws; repo en memoria) | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| Config/estado sintético, EK | `fxConfig(capacity:…:frontierEscalationPerTier:frontierEscalationFromTier:)`, `fxEconomy`, `fxTiers`, `fxType`, `fxFloorTable`, `fxState`, `fxStateAndTower`, `fxSlots` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` |
| La escalera del simulador | `upTiers(maxTier:)`, `upConfig(maxTier:gateTierDistance:)`, `upSimulator`, `upCheapLines` (privados: los tests nuevos del simulador van **en el mismo archivo**) | `PacingSimulatorTests.swift:11-104` |
| Contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift:31` |
| `PlayerState` con contenido real | `makeState(maxTier:coins:)` (privado de la suite) | `ContentSystemsTests.swift:42` |
| Plata, frontera, pisos, ORO | `debugGrantCoins()` `:127`, `debugSetMaxTier(_:)` `:164`, `debugUnlockFloors(throughTier:)` `:181`, `giveEarningsForPrestigeTesting(oro:)` `:119` | `GameState+Debug.swift` |
| Una fila de FisuJobs | `jobRow(_:_:)` (privado) | `JobRowsTests.swift:18` |
| El modelo humano del simulador | `PacingSimulator.HumanModel()` (público: sesiones de 20 min a las 0, 4, 9 y 14 h) | `PacingSimulator.swift:19-72` |
| Las perillas | `EconomyKnobs` + `config.tuned(_:)` | **los crea T2** y crecen hasta T5 |

La escalera sintética de EK: `a(1) → b(2) → choice (3, nodo: c_prog/c_law) → d(4)`; pisos
`f1 {1–2}` (curva propia 15 / **1,15**) y `f2 {3–4}`, capacidad 5; `yieldGrowthPerTier` 3,8,
`priceGrowthPerTier` 1,5. El tipo base real es `homeless` (callejón, curva 1,03); los tiers 11 y
12 tienen cuatro ramas de carrera cada uno; el 13 es `director`.

---

### Task 1: `RewardScale` — los premios en minutos de producción real

**Objetivo:** la cuenta única de "N minutos de producción", pura en EconomyKit: lo que la torre
rinde por segundo sin modificadores temporales, con un piso para que una torre que todavía no
produce no cobre cero, y ese piso mirando la historia de la cuenta **sin pasar de la frontera
+ 3** (PLAN-v2 E2a). Sube la lógica de `coinReward` (`GameState+Achievements.swift:453-489`);
la app se muda a esto en T7 y T11.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/RewardScale.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/RewardScaleTests.swift`

**Interfaces:**
- Consumes: `IncomeTicker.basePassivePerSecond` (E1 T1, ya en el árbol); `RunState.raiseFrontier(to:)` (E1 T3, sólo en los tests).
- Produces: `public enum RewardScale` con `static let floorTiersAboveFrontier = 3`,
  `rewardTier(state:floorTable:) -> Int`, `productionPerSecond(state:tiers:floorTable:config:) -> Double`,
  `coinPayout(seconds:state:tiers:floorTable:config:) -> Double` y
  `coinPayout(minutes:state:tiers:floorTable:config:) -> Double`.

- [ ] **Step 0: Pararse en la base**

`grep -n "func raiseFrontier" Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` tiene que
devolver una línea (E1 T3). Si no, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/RewardScaleTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// Doce tiers en tres pisos de cuatro: la escalera chica de `Fixtures` tiene dos
/// pisos y no deja ver el tope de "frontera + 3".
private func ladder() throws -> (tiers: TierRepository, floorTable: FloorTable) {
    let types = (1...12).map { tier in
        fxType("t\(tier)", tier: tier, tapYield: pow(3.8, Double(tier - 1)), mergesInto: tier < 12 ? "t\(tier + 1)" : nil)
    }
    let floors = (0..<3).map { index in
        FloorDef(id: "p\(index + 1)", background: "alley", firstTier: index * 4 + 1, lastTier: index * 4 + 4,
                 capacity: 5, incomeMultiplier: 1)
    }
    return try (TierRepository(types: types), FloorTable(floors: floors, maxTier: 12))
}

@Suite("RewardScale: los premios en minutos de producción")
struct RewardScaleTests {
    @Test("paga los minutos de lo que la torre produce, sin los modificadores temporales")
    func paysBaseProduction() throws {
        var state = fxState(units: ["a": 3])
        state.run.passiveUnlocked["a"] = true
        state.run.activeModifiers = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: .greatestFiniteMagnitude, sourceKey: "x")
        ]
        let tiers = try fxTiers()
        let floorTable = try fxFloorTable()
        let perSecond = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(perSecond > 0)
        let paid = RewardScale.coinPayout(minutes: 2, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(abs(paid - perSecond * 120) < 1e-9)
    }

    @Test("una torre que todavía no produce cobra el piso, no cero")
    func idleTowerPaysTheFloor() throws {
        let paid = RewardScale.coinPayout(
            seconds: 60, state: fxState(units: ["a": 1]), tiers: try fxTiers(),
            floorTable: try fxFloorTable(), config: fxConfig()
        )
        #expect(paid > 0)
        #expect(abs(paid - fxEconomy().passiveYield(forTier: 1) * 60) < 1e-9)
    }

    @Test("el piso recuerda el piso más alto de la cuenta, pero no más de tres tiers arriba de la frontera")
    func rewardTierIsCappedAboveTheFrontier() throws {
        let world = try ladder()
        var state = fxState(units: ["t1": 1], unlockedFloors: ["p1"])
        state.meta.stats.maxFloorOrdinalEver = 2
        #expect(RewardScale.rewardTier(state: state, floorTable: world.floorTable) == 4)
        state.run.raiseFrontier(to: 7)
        #expect(RewardScale.rewardTier(state: state, floorTable: world.floorTable) == 9)
        state.run.raiseFrontier(to: 10)
        #expect(RewardScale.rewardTier(state: state, floorTable: world.floorTable) == 10)
    }

    @Test("sin historia, el piso es la frontera")
    func withoutHistoryTheFloorIsTheFrontier() throws {
        var state = fxState(units: ["t1": 1], unlockedFloors: ["p1"])
        state.run.raiseFrontier(to: 3)
        #expect(RewardScale.rewardTier(state: state, floorTable: try ladder().floorTable) == 3)
    }

    @Test("un minuto son sesenta segundos, y una duración no positiva no paga")
    func minutesAreSixtySeconds() throws {
        let state = fxState(units: ["a": 1])
        let tiers = try fxTiers()
        let floorTable = try fxFloorTable()
        let minute = RewardScale.coinPayout(minutes: 1, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        let seconds = RewardScale.coinPayout(seconds: 60, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(minute == seconds)
        #expect(RewardScale.coinPayout(minutes: -5, state: state, tiers: tiers, floorTable: floorTable, config: fxConfig()) == 0)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter RewardScaleTests`
Expected: no compila (`cannot find 'RewardScale' in scope`).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/RewardScale.swift`:

```swift
import Foundation

/// Los premios en minutos de producción real (PLAN-v2 E2a). Un premio dice
/// "N minutos" y paga lo que la torre rinde en N minutos ahora mismo.
///
/// Dos correcciones sobre el pasivo a secas, heredadas de los logros:
/// 1. **Sin los modificadores temporales.** Cobrar es una decisión del
///    jugador: si el premio mirara un ×3 vivo, guardárselo para el próximo
///    Plan Platita pagaría por esperar.
/// 2. **Con piso.** Al arrancar —o al volver de reencarnar— la torre produce
///    cero, y "cero × minutos" sería un premio que no paga. El piso es el
///    rinde de catálogo de UN personaje pelado (sin multiplicadores de piso,
///    global ni mejoras) del `rewardTier`.
public enum RewardScale {
    /// Hasta cuántos tiers por encima de la frontera mira el piso. El que
    /// reencarna conserva algo de su historia sin que guardarse un premio para
    /// después de reencarnar sea un golpe de suerte.
    public static let floorTiersAboveFrontier = 3

    /// El tier con el que se cotiza el piso: el primero del piso más alto que
    /// la cuenta tocó (sobrevive a reencarnar), nunca debajo de la frontera ni
    /// más de `floorTiersAboveFrontier` arriba de ella.
    public static func rewardTier(state: PlayerState, floorTable: FloorTable) -> Int {
        let frontier = state.run.maxTierReached
        let ordinal = min(max(state.meta.stats.maxFloorOrdinalEver, 0), floorTable.count - 1)
        let history = max(frontier, floorTable[ordinal].firstTier)
        return min(history, frontier + floorTiersAboveFrontier)
    }

    public static func productionPerSecond(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        let produced = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
        let lonelyWorker = StandardEconomy(config: config).passiveYield(forTier: rewardTier(state: state, floorTable: floorTable))
        return max(produced, lonelyWorker)
    }

    public static func coinPayout(
        seconds: Double,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        guard seconds > 0 else { return 0 }
        return productionPerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config) * seconds
    }

    public static func coinPayout(
        minutes: Double,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        coinPayout(seconds: minutes * 60, state: state, tiers: tiers, floorTable: floorTable, config: config)
    }
}
```

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter RewardScaleTests` → PASS, nombra los
cinco tests. Después `Tools/v2/oraculo.sh rapido` → `VERDE`, con la cuenta de `economykit` +5.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/RewardScale.swift Packages/EconomyKit/Tests/EconomyKitTests/RewardScaleTests.swift
git diff --cached --stat
git commit -m "feat(economia): los premios en minutos de producción, puros en EconomyKit"
```

---

### Task 2: El reintegro al fusionar, y las perillas juntas

**Objetivo:** `hire.mergeRefundCounts` (0 = v1) y el helper que la app y el simulador comparten
(`refundMergeCounts`): fusionar un par devuelve `r` compras a la curva del tipo fusionado y a la
de su piso. Con fusión continua la curva crece `g^(1−r/2)` por compra. Nace `EconomyKnobs`, que
junta las perillas de E2a para los tests, el panel de debug y E2b.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`HireConfig`: propiedad, `init`, decoder, `CodingKeys`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (extensión de `RunState` que creó E1 T3)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`doAllMerges`, después de consumir el par)
- Create: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/MergeRefundTests.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift` (helper `fingerprint` y una suite)

**Interfaces:**
- Consumes: `hireCounts`, `hireCountsByType: [String: Double]` y `hireCost(…, purchases: Double)` (E1 T3).
- Produces: `EconomyConfig.HireConfig.mergeRefundCounts: Double` (default 0).
- Produces: `RunState.refundMergeCounts(typeId: String, floorId: String, counts: Double)`.
- Produces: `public struct EconomyKnobs: Codable, Sendable, Equatable` (`defaultCostGrowth: Double?`, `mergeRefundCounts: Double?`), `EconomyConfig.tuned(_ knobs: EconomyKnobs) throws -> EconomyConfig`, `EconomyKnobsError.notAnObject`. **T3, T4 y T5 le suman un campo cada una.**
- Produces (tests, privado de `PacingSimulatorTests.swift`): `fingerprint(_ report: PacingSimulator.Report) -> [Double]`.

- [ ] **Step 0: Pararse en la base**

`grep -n "hireCountsByType: \[String: Double\]" Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift`
y `grep -n "priceRelief" Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` tienen que
devolver algo (E1 T3 y T4). Si no, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/MergeRefundTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Reintegro al fusionar")
struct MergeRefundTests {
    @Test("sin la perilla, fusionar no devuelve nada: es la v1")
    func defaultRefundsNothing() throws {
        #expect(fxConfig().hire.mergeRefundCounts == 0)
        #expect(try fxConfig().tuned(EconomyKnobs()).hire.mergeRefundCounts == 0)
    }

    @Test("devuelve compras a la curva del tipo y a la de su piso, y nunca baja de cero")
    func refundLowersBothCurves() {
        var run = fxState().run
        run.hireCounts = ["f1": 3]
        run.hireCountsByType = ["a": 3, "b": 1]
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 1)
        #expect(run.hireCountsByType == ["a": 2, "b": 1])
        #expect(run.hireCounts == ["f1": 2])
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 5)
        #expect(run.hireCountsByType == ["b": 1])
        #expect(run.hireCounts.isEmpty)
    }

    @Test("un reintegro de cero no toca nada")
    func zeroIsANoOp() {
        var run = fxState().run
        run.hireCountsByType = ["a": 3]
        run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 0)
        #expect(run.hireCountsByType == ["a": 3])
    }

    @Test("con fusión continua la curva crece g^(1 − r/2) por compra")
    func continuousMergingGrowsSlower() throws {
        let config = fxConfig()
        let floor = try fxFloorTable()[0]
        for refund in [0.0, 0.5, 1.0, 2.0] {
            var run = fxState().run
            for _ in 0..<10 {
                run.hireCountsByType["a", default: 0] += 2
                run.refundMergeCounts(typeId: "a", floorId: "f1", counts: refund)
            }
            let purchases = run.hireCountsByType["a"] ?? 0
            #expect(abs(purchases - 10 * (2 - refund)) < 1e-9)
            let perPurchase = pow(
                config.hireCost(floor: floor, tier: 1, frontierTier: 1, purchases: purchases)
                    / config.hireCost(floor: floor, tier: 1, frontierTier: 1, purchases: 0),
                1.0 / 20
            )
            #expect(abs(perPurchase - pow(config.hireCostGrowth(for: floor), 1 - refund / 2)) < 1e-9)
        }
    }
}
```

`Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Las perillas de E2a")
struct EconomyKnobsTests {
    @Test("sin perillas, la config sale igual")
    func noKnobsIsTheSameConfig() throws {
        #expect(try fxConfig().tuned(EconomyKnobs()) == fxConfig())
    }

    @Test("cada perilla llega a su campo por el decoder, y el resto no se mueve")
    func eachKnobLands() throws {
        let tuned = try fxConfig().tuned(EconomyKnobs(defaultCostGrowth: 1.12, mergeRefundCounts: 1))
        #expect(tuned.hire.defaultCostGrowth == 1.12)
        #expect(tuned.hire.mergeRefundCounts == 1)
        #expect(tuned.floors == fxConfig().floors)
        #expect(tuned.oro == fxConfig().oro)
    }
}
```

En `PacingSimulatorTests.swift`, después de `upSimulator` (son privados del archivo, por eso
los tests nuevos del simulador van acá):

```swift
/// Lo que distingue dos corridas del bot: si una perilla no mueve esto, el
/// simulador no la lee (trampa 28: un knob horneado no hace nada).
private func fingerprint(_ report: PacingSimulator.Report) -> [Double] {
    [report.godActive ?? -1, Double(report.reincarnations), report.finalLifetimeEarnings, Double(report.finalMaxTier)]
        + report.reincarnationActiveSeconds
}

@Suite("PacingSimulator: las perillas de E2a")
struct PacingSimulatorKnobTests {
    @Test("con el reintegro en cero el bot juega exactamente igual que sin la clave")
    func zeroRefundIsTheBaseline() throws {
        let base = try upSimulator().run(maxDays: 5)
        let tuned = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(mergeRefundCounts: 0)), tiers: upTiers()).run(maxDays: 5)
        #expect(fingerprint(tuned) == fingerprint(base))
    }

    @Test("el simulador lee el reintegro")
    func theSimulatorReadsTheRefund() throws {
        let base = try upSimulator().run(maxDays: 5)
        let tuned = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(mergeRefundCounts: 1)), tiers: upTiers()).run(maxDays: 5)
        #expect(fingerprint(tuned) != fingerprint(base))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "MergeRefundTests|EconomyKnobsTests|PacingSimulatorKnobTests"`
Expected: no compila (`mergeRefundCounts`, `refundMergeCounts`, `EconomyKnobs`).

- [ ] **Step 3: La implementación**

`EconomyConfig.swift`, en `HireConfig`, después de `frontierEscalationFromTier`:

```swift
        /// Cuántas compras le devuelve a la curva fusionar un par (PLAN-v2 E2a,
        /// "fusionar abarata, pero no tanto"). Con fusión continua la curva
        /// crece `defaultCostGrowth^(1 − r/2)` por compra, y acumular sin
        /// fusionar sigue pagando la curva entera; por eso se barre en pares
        /// con el growth. **0 = la v1**, y ése es el default mientras E2b no la
        /// calibre. [TUNEABLE]
        public let mergeRefundCounts: Double
```

El `init` suma `mergeRefundCounts: Double = 0` al final de su lista y `self.mergeRefundCounts =
mergeRefundCounts`. En `init(from:)`, después de `frontierEscalationFromTier`:

```swift
            // `decodeIfPresent` y al revés que las de arriba: el default (0) ES la
            // v1, una conducta conocida y medida, no una regla que se apaga.
            mergeRefundCounts = try container.decodeIfPresent(Double.self, forKey: .mergeRefundCounts) ?? 0
```

y `CodingKeys` suma `case mergeRefundCounts` (en la línea de `gateTierDistance, …`).

`PlayerState.swift`, en la extensión de `RunState` donde E1 T3 dejó `raiseFrontier` y
`registerHire`:

```swift
    /// Fusionar un par devuelve `counts` compras a la curva del tipo fusionado y
    /// a la de su piso (PLAN-v2 E2a, el reintegro). Nunca baja de cero, y un
    /// contador que llega a cero sale del diccionario.
    public mutating func refundMergeCounts(typeId: String, floorId: String, counts: Double) {
        guard counts > 0 else { return }
        hireCountsByType[typeId] = Self.lowered(hireCountsByType[typeId], by: counts)
        hireCounts[floorId] = Self.lowered(hireCounts[floorId], by: counts)
    }

    private static func lowered(_ count: Double?, by amount: Double) -> Double? {
        let left = (count ?? 0) - amount
        return left > 0 ? left : nil
    }
```

`PacingSimulator.swift`, en `doAllMerges`, justo después de consumir el par (las dos líneas
`state.run.units[type.id, default: 0] -= 2` / `… = nil`):

```swift
                // El reintegro de la fusión (PLAN-v2 E2a). Con la perilla en 0 no
                // hace nada y el bot juega como siempre.
                state.run.refundMergeCounts(
                    typeId: type.id,
                    floorId: floorTable.floor(forTier: type.tier).id,
                    counts: config.hire.mergeRefundCounts
                )
```

`Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift`:

```swift
import Foundation

/// Las perillas de E2a juntas (PLAN-v2 E2a): lo que el panel de debug deja
/// probar al dueño y lo que E2b barre con el simulador. `nil` deja el valor de
/// la config; con todas en `nil`, `tuned` devuelve la misma config.
public struct EconomyKnobs: Codable, Sendable, Equatable {
    public var defaultCostGrowth: Double?
    public var mergeRefundCounts: Double?

    public init(defaultCostGrowth: Double? = nil, mergeRefundCounts: Double? = nil) {
        self.defaultCostGrowth = defaultCostGrowth
        self.mergeRefundCounts = mergeRefundCounts
    }
}

public enum EconomyKnobsError: Error, Equatable {
    case notAnObject
}

extension EconomyConfig {
    /// La misma config con las perillas puestas. Pasa por el JSON a propósito:
    /// es el camino por el que una perilla llega al juego (`economy.json` y su
    /// decoder), y una clave que otra épica sume a la config viaja sola, sin que
    /// esta función tenga que enumerar los campos.
    public func tuned(_ knobs: EconomyKnobs) throws -> EconomyConfig {
        guard var root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any],
              var hire = root["hire"] as? [String: Any]
        else { throw EconomyKnobsError.notAnObject }
        if let value = knobs.defaultCostGrowth { hire["defaultCostGrowth"] = value }
        if let value = knobs.mergeRefundCounts { hire["mergeRefundCounts"] = value }
        root["hire"] = hire
        return try JSONDecoder().decode(EconomyConfig.self, from: JSONSerialization.data(withJSONObject: root))
    }
}
```

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS; la salida nombra `MergeRefundTests`,
`EconomyKnobsTests` y `PacingSimulatorKnobTests`. Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/MergeRefundTests.swift Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift
git diff --cached --stat
git commit -m "feat(economia): el reintegro al fusionar, detrás de una perilla en cero"
```

---

### Task 3: El amortiguador del salto de precio, y el "+6 %" que dice la verdad

**Objetivo:** que subir la frontera no haga saltar los precios (`D ×= J`), que la diferencia se
cobre en las K compras siguientes (`D = max(1, D/ρ)`) y que después el precio vuelva exacto a la
v1; detrás de `hire.priceReliefPurchases` (0 = apagado). Y las dos cuentas que la pantalla va a
mostrar: el paso de la próxima compra (`quote(n+1)/quote(n) − 1`, con D y reintegro adentro) y
cuánto baja fusionar.

En esta tarea el amortiguador queda **cableado en el simulador y en la compra**; las fusiones de
la app lo reciben en T9 (les falta `config:`). Con la perilla en 0 eso no cambia nada: `D` no se
mueve de 1.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`HireConfig.priceReliefPurchases`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (`raiseFrontier(to:cushion:)`; `registerHire` suma `cushion:`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (los dos `hireQuote`, `hire`, `nextHireStep`, `mergeRelief`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`cushion`, compra y frontera)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift` (`priceReliefPurchases`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/PriceCushionTests.swift` (`PriceCushionTests` y `HireStepTests`)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`, `PacingSimulatorTests.swift`
- Create: `FisuEvolutionTests/PriceCushionContentTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `RunState.priceRelief` (E1 T4); `RunState.raiseFrontier(to:)`, `registerHire(floorId:typeId:)`, `TowerActions.hire(…countsAsPurchase:)` (E1 T3); `refundMergeCounts`, `EconomyKnobs` (T2).
- Produces: `public struct PriceCushion: Sendable, Equatable` con `init(config:)`, `purchases: Int`, `isEnabled`, `jump(from:to:) -> Double`, `step(atFrontier:) -> Double`, `relief(_:raisingFrom:to:) -> Double`, `relief(_:afterPurchaseAt:) -> Double`, `price(v1:relief:) -> Double`; `EconomyConfig.priceCushion: PriceCushion`.
- Produces: `EconomyConfig.HireConfig.priceReliefPurchases: Int` (default 0); `EconomyKnobs.priceReliefPurchases: Int?`.
- Produces: `RunState.raiseFrontier(to:cushion:) -> Bool` (`@discardableResult`) y `RunState.registerHire(floorId:typeId:cushion:)` — **reemplaza** a la de dos argumentos de E1 T3 (sus únicos llamadores son `TowerActions.hire` y el simulador).
- Produces: `TowerActions.nextHireStep(typeId:state:config:floorTable:tiers:costMultiplier:now:) -> Double?` y `TowerActions.mergeRelief(typeId:state:config:floorTable:tiers:costMultiplier:now:) -> Double?` (`costMultiplier = 1`, `now = 0` por default, como `hireQuote`).

- [ ] **Step 0: Pararse en la base**

`grep -rn "registerHire(" Packages FisuEvolution FisuEvolutionTests` tiene que listar **sólo**
`PlayerState.swift`, `TowerActions.swift` y `PacingSimulator.swift`. Si aparece otro llamador,
se suma `cushion: config.priceCushion` ahí también y se anota en el reporte.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/PriceCushionTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("El amortiguador: el precio no salta al subir la frontera")
struct PriceCushionTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    /// La fixture con la desaceleración desde el tier 2, para que un salto
    /// cruce el umbral de la escalada.
    private func v1() -> EconomyConfig {
        fxConfig(frontierEscalationPerTier: 1.6, frontierEscalationFromTier: 2)
    }

    private func cushioned(_ purchases: Int = 4) throws -> EconomyConfig {
        try v1().tuned(EconomyKnobs(priceReliefPurchases: purchases))
    }

    private func price(_ typeId: String, _ state: PlayerState, _ config: EconomyConfig) throws -> Double {
        try #require(TowerActions.hireQuote(
            typeId: typeId, state: state, config: config, floorTable: try fxFloorTable(config: config), tiers: tiers
        )).cost
    }

    private func buy(_ typeId: String, _ fx: inout (state: PlayerState, tower: TowerState, floorTable: FloorTable),
                     _ config: EconomyConfig) throws {
        let quote = try #require(TowerActions.hireQuote(
            typeId: typeId, state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
        ))
        try TowerActions.hire(quote: quote, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                              config: config, countsAsPurchase: true)
    }

    @Test("subir la frontera no hace saltar ningún precio")
    func raisingTheFrontierKeepsEveryPrice() throws {
        let config = try cushioned()
        var state = fxState(units: ["a": 2, "b": 1])
        let types = ["a", "b", "c_prog", "d"]
        let before = try types.map { try price($0, state, config) }
        #expect(state.run.raiseFrontier(to: 2, cushion: config.priceCushion))
        let after = try types.map { try price($0, state, config) }
        for (old, new) in zip(before, after) {
            #expect(abs(new / old - 1) < 1e-12)
        }
        #expect(state.run.priceRelief > 1)
    }

    @Test("cruzando el umbral de la desaceleración tampoco salta")
    func acrossTheEscalationThreshold() throws {
        let config = try cushioned()
        var state = fxState(units: ["a": 1])
        state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        let before = try price("a", state, config)
        state.run.raiseFrontier(to: 3, cushion: config.priceCushion)
        #expect(abs(try price("a", state, config) / before - 1) < 1e-12)
        #expect(abs(config.priceCushion.jump(from: 2, to: 3) - 3.8 / 1.5 * 1.6) < 1e-12)
    }

    @Test("después de K compras el precio vuelve exacto al de la v1")
    func afterKPurchasesThePriceIsV1() throws {
        let config = try cushioned(4)
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.coins = 1e9
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        for _ in 0..<4 {
            try buy("a", &fx, config)
        }
        #expect(fx.state.run.priceRelief == 1)
        #expect(try price("a", fx.state, config) == price("a", fx.state, v1()))
    }

    @Test("mientras dura, cada compra cuesta ρ = J^(1/K) más que con la v1")
    func eachPurchasePaysTheStep() throws {
        let config = try cushioned(4)
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.coins = 1e9
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        let first = try price("a", fx.state, config)
        try buy("a", &fx, config)
        let rho = pow(config.priceCushion.jump(from: 1, to: 2), 1.0 / 4)
        // 1,15: la curva propia del callejón de la fixture.
        #expect(abs(try price("a", fx.state, config) / first - 1.15 * rho) < 1e-9)
    }

    @Test("D divide a todos por igual: comprar hondo sigue sin ser atajo")
    func theDepthRuleSurvives() throws {
        let config = try cushioned()
        var state = fxState(units: ["a": 1])
        state.run.raiseFrontier(to: 3)
        let flat = try price("a", state, config) / price("b", state, config)
        state.run.priceRelief = 3
        #expect(abs(try price("a", state, config) / price("b", state, config) / flat - 1) < 1e-12)
    }

    @Test("una contratación gratis no descuenta el amortiguador")
    func freeHiresDoNotDecay() throws {
        let config = try cushioned()
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        let relief = fx.state.run.priceRelief
        let free = try #require(TowerActions.hireQuote(
            typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers, costMultiplier: 0
        ))
        try TowerActions.hire(quote: free, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                              config: config, countsAsPurchase: false)
        #expect(fx.state.run.priceRelief == relief)
    }

    @Test("apagado, el precio es el de la v1 aunque el save traiga un D, y la próxima compra lo limpia")
    func offMeansV1() throws {
        let config = fxConfig()
        var fx = try fxStateAndTower(units: ["a": 1])
        fx.state.run.coins = 1e9
        fx.state.run.priceRelief = 5
        #expect(try price("a", fx.state, config) == config.hireCost(floor: fx.floorTable[0], tier: 1, frontierTier: 1, purchases: 0))
        try buy("a", &fx, config)
        #expect(fx.state.run.priceRelief == 1)
    }

    @Test("reencarnar vuelve el amortiguador a 1")
    func reincarnationResetsIt() throws {
        var state = fxState()
        state.run.priceRelief = 4
        PrestigeCalculator.applyReincarnation(state: &state, economy: fxEconomy(), tiers: tiers, floorTable: try fxFloorTable(), now: 0)
        #expect(state.run.priceRelief == 1)
    }

    @Test("la perilla viaja por el JSON y su falta es la v1")
    func theKnobDecodes() throws {
        #expect(fxConfig().hire.priceReliefPurchases == 0)
        #expect(!fxConfig().priceCushion.isEnabled)
        #expect(try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 24)).hire.priceReliefPurchases == 24)
    }
}

@Suite("“+6 % por compra”: lo que se muestra es lo que se cobra")
struct HireStepTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test("el paso de la próxima compra es lo que sube el precio, con y sin amortiguador")
    func theStepIsWhatTheNextPurchaseCosts() throws {
        for config in [fxConfig(), try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 4))] {
            var fx = try fxStateAndTower(units: ["a": 1], config: config)
            fx.state.run.coins = 1e9
            fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
            let step = try #require(TowerActions.nextHireStep(
                typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
            ))
            let before = try #require(TowerActions.hireQuote(
                typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
            ))
            try TowerActions.hire(quote: before, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                                  config: config, countsAsPurchase: true)
            let after = try #require(TowerActions.hireQuote(
                typeId: "a", state: fx.state, config: config, floorTable: fx.floorTable, tiers: tiers
            ))
            #expect(abs(after.cost / before.cost - 1 - step) < 1e-12)
        }
    }

    @Test("sin amortiguador, el paso es la curva del piso: 15 % en el callejón de la fixture")
    func withoutCushionTheStepIsTheGrowth() throws {
        let fx = try fxStateAndTower(units: ["a": 1])
        let step = try #require(TowerActions.nextHireStep(
            typeId: "a", state: fx.state, config: fxConfig(), floorTable: fx.floorTable, tiers: tiers
        ))
        #expect(abs(step - 0.15) < 1e-12)
    }

    @Test("con el reintegro, fusionar baja lo que dice")
    func mergeReliefIsWhatTheRefundTakes() throws {
        let config = try fxConfig().tuned(EconomyKnobs(mergeRefundCounts: 1))
        let floorTable = try fxFloorTable(config: config)
        var state = fxState(units: ["a": 2])
        state.run.hireCountsByType = ["a": 4]
        state.run.hireCounts = ["f1": 4]
        let relief = try #require(TowerActions.mergeRelief(
            typeId: "a", state: state, config: config, floorTable: floorTable, tiers: tiers
        ))
        let before = try #require(TowerActions.hireQuote(typeId: "a", state: state, config: config, floorTable: floorTable, tiers: tiers)).cost
        state.run.refundMergeCounts(typeId: "a", floorId: "f1", counts: 1)
        let after = try #require(TowerActions.hireQuote(typeId: "a", state: state, config: config, floorTable: floorTable, tiers: tiers)).cost
        #expect(abs(1 - after / before - relief) < 1e-12)
    }

    @Test("sin reintegro, o con un tipo que no se fusiona, no hay nada que prometer")
    func noReliefWithoutRefund() throws {
        let refunding = try fxConfig().tuned(EconomyKnobs(mergeRefundCounts: 1))
        var state = fxState(units: ["a": 2, "d": 1])
        state.run.hireCountsByType = ["a": 4, "d": 2]
        #expect(TowerActions.mergeRelief(typeId: "a", state: state, config: fxConfig(), floorTable: try fxFloorTable(), tiers: tiers) == nil)
        #expect(TowerActions.mergeRelief(typeId: "d", state: state, config: refunding, floorTable: try fxFloorTable(), tiers: tiers) == nil)
    }
}
```

En `EconomyKnobsTests.eachKnobLands`, sumar `priceReliefPurchases: 24` al `EconomyKnobs(…)` y
`#expect(tuned.hire.priceReliefPurchases == 24)`.

En `PacingSimulatorKnobTests` (T2):

```swift
    @Test("con el amortiguador en cero el bot juega igual; prendido, el simulador lo lee")
    func theSimulatorReadsTheCushion() throws {
        let base = try upSimulator().run(maxDays: 5)
        let zero = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(priceReliefPurchases: 0)), tiers: upTiers()).run(maxDays: 5)
        let on = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(priceReliefPurchases: 24)), tiers: upTiers()).run(maxDays: 5)
        #expect(fingerprint(zero) == fingerprint(base))
        #expect(fingerprint(on) != fingerprint(base))
    }
```

`FisuEvolutionTests/PriceCushionContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El amortiguador sobre los datos reales: absorbe el salto de hoy y, con D = 1,
/// no cambia ni un precio de la v1.
@Suite("El amortiguador sobre los datos reales")
struct PriceCushionContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("el salto que absorbe es el de hoy: ×1,87 abajo y ×2,99 desde el tier 8")
    func theJumpIsTodaysJump() throws {
        let cushion = try content.economy.tuned(EconomyKnobs(priceReliefPurchases: 24)).priceCushion
        #expect(abs(cushion.jump(from: 3, to: 4) - 2.8 / 1.5) < 1e-12)
        #expect(abs(cushion.jump(from: 10, to: 11) - 2.8 / 1.5 * 1.6) < 1e-12)
        #expect(abs(cushion.step(atFrontier: 11) - pow(2.8 / 1.5 * 1.6, 1.0 / 24)) < 1e-12)
    }

    @Test("con D = 1 el precio es el de la v1 en los 37 tiers")
    func reliefOneIsV1Everywhere() throws {
        let cushioned = try content.economy.tuned(EconomyKnobs(priceReliefPurchases: 24))
        var state = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id, startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: 0, critChanceBase: 0, now: 0
        )
        for frontier in [1, 7, 8, 20, content.tiers.maxTier] {
            state.run.raiseFrontier(to: frontier)
            for type in content.tiers.concreteTypes {
                let v1 = try #require(TowerActions.hireQuote(
                    typeId: type.id, state: state, config: content.economy,
                    floorTable: content.floorTable, tiers: content.tiers
                )).cost
                let withCushion = try #require(TowerActions.hireQuote(
                    typeId: type.id, state: state, config: cushioned,
                    floorTable: content.floorTable, tiers: content.tiers
                )).cost
                #expect(withCushion == v1, "\(type.id) con la frontera en \(frontier)")
            }
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "PriceCushionTests|HireStepTests|EconomyKnobsTests|PacingSimulatorKnobTests"`
Expected: no compila (`PriceCushion`, `priceReliefPurchases`, `raiseFrontier(to:cushion:)`, `nextHireStep`).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift`:

```swift
import Foundation

/// El amortiguador del salto de precio (PLAN-v2 E2a, "Fórmula B").
///
/// `hireCost` está anclado a la frontera, así que en la v1 subirla multiplica
/// en el acto el precio de TODO lo que se vende por `J` (×1,87 por tier en el
/// callejón, ×2,99 desde el tier 8). Con el amortiguador, al subir la frontera
/// `RunState.priceRelief` hace `D ×= J` y el precio se divide por `D`: no salta.
/// Cada compra que cuenta hace `D = max(1, D/ρ)` con `ρ = J^(1/K)`, así que la
/// diferencia se cobra en las K compras siguientes y el precio vuelve EXACTO a
/// la v1.
///
/// `D` divide a todos los tipos por igual: la regla de precios (comprar hondo
/// no es atajo) y la compuerta no cambian.
///
/// Apagado (`K = 0`, la v1) el precio ignora `D` y cualquier compra lo vuelve a
/// 1: un save que lo trae de una prueba en el panel de debug no paga de menos.
public struct PriceCushion: Sendable, Equatable {
    /// `K`: en cuántas compras se paga un salto. 0 = apagado.
    public let purchases: Int
    private let yieldGrowthPerTier: Double
    private let priceGrowthPerTier: Double
    private let escalationPerTier: Double
    private let escalationFromTier: Int

    /// Un `D` a menos de esto de 1 es 1: después de K divisiones el redondeo no
    /// puede dejar el precio un pelo debajo de la v1 para siempre.
    static let snap = 1e-9

    public init(config: EconomyConfig) {
        purchases = max(0, config.hire.priceReliefPurchases)
        yieldGrowthPerTier = config.yieldGrowthPerTier
        priceGrowthPerTier = config.hire.priceGrowthPerTier
        escalationPerTier = config.hire.frontierEscalationPerTier
        escalationFromTier = config.hire.frontierEscalationFromTier
    }

    public var isEnabled: Bool { purchases > 0 }

    /// Cuánto salta el precio v1 de cualquier tipo cuando la frontera va de
    /// `from` a `to`: el cociente de los factores de `hireCost` que dependen de
    /// la frontera (rendimiento, escalada y la pendiente por tier).
    public func jump(from: Int, to: Int) -> Double {
        guard to > from else { return 1 }
        let escalated = max(0, to - escalationFromTier) - max(0, from - escalationFromTier)
        return pow(yieldGrowthPerTier / priceGrowthPerTier, Double(to - from))
            * pow(escalationPerTier, Double(escalated))
    }

    /// `ρ` en esta frontera: el salto que llevó hasta ella, repartido en K compras.
    public func step(atFrontier frontier: Int) -> Double {
        guard isEnabled, frontier > 1 else { return 1 }
        return pow(jump(from: frontier - 1, to: frontier), 1 / Double(purchases))
    }

    public func relief(_ relief: Double, raisingFrom from: Int, to: Int) -> Double {
        isEnabled ? max(1, relief) * jump(from: from, to: to) : 1
    }

    public func relief(_ relief: Double, afterPurchaseAt frontier: Int) -> Double {
        guard isEnabled else { return 1 }
        let next = relief / step(atFrontier: frontier)
        return next <= 1 + Self.snap ? 1 : next
    }

    public func price(v1: Double, relief: Double) -> Double {
        isEnabled ? v1 / max(1, relief) : v1
    }
}

extension EconomyConfig {
    public var priceCushion: PriceCushion { PriceCushion(config: self) }
}
```

`EconomyConfig.swift`, en `HireConfig`, después de `mergeRefundCounts`:

```swift
        /// El amortiguador del salto de precio (`PriceCushion`): en cuántas
        /// compras se paga lo que subir la frontera habría subido de golpe.
        /// **0 = apagado, la v1**; PLAN-v2 E2a propone 24. [TUNEABLE]
        public let priceReliefPurchases: Int
```

`init` suma `priceReliefPurchases: Int = 0` al final; `init(from:)`:
`priceReliefPurchases = try container.decodeIfPresent(Int.self, forKey: .priceReliefPurchases) ?? 0`;
`CodingKeys` suma `case priceReliefPurchases`.

`PlayerState.swift`, en la extensión de `RunState`: **se borra** el `registerHire(floorId:typeId:)`
de E1 T3 y queda:

```swift
    /// Sube la frontera y, con el amortiguador, guarda el salto del precio en
    /// `priceRelief`. Es la que usan las fusiones del juego y el simulador; la
    /// de un argumento queda para la carga (`TowerReconciler`), los fixtures y
    /// el panel de debug, que no amortiguan.
    @discardableResult
    public mutating func raiseFrontier(to tier: Int, cushion: PriceCushion) -> Bool {
        let before = maxTierReached
        guard raiseFrontier(to: tier) else { return false }
        priceRelief = cushion.relief(priceRelief, raisingFrom: before, to: maxTierReached)
        return true
    }

    /// Una compra que cuenta para la curva: suma a los dos contadores y, con el
    /// amortiguador, descuenta un paso de `priceRelief`.
    public mutating func registerHire(floorId: String, typeId: String, cushion: PriceCushion) {
        hireCounts[floorId, default: 0] += 1
        hireCountsByType[typeId, default: 0] += 1
        priceRelief = cushion.relief(priceRelief, afterPurchaseAt: maxTierReached)
    }
```

`TowerActions.swift`: en los dos `hireQuote`, el `base` pasa a

```swift
        let base = config.priceCushion.price(
            v1: config.hireCost(
                floor: floor, tier: floor.firstTier,
                frontierTier: state.run.maxTierReached, purchases: purchases
            ),
            relief: state.run.priceRelief
        )
```

(en `hireQuote(typeId:)` con `tier: type.tier`). En `hire`, la línea de E1 T3 pasa a
`state.run.registerHire(floorId: floor.id, typeId: quote.type.id, cushion: config.priceCushion)`.
Y al final de la sección de hire:

```swift
    /// Cuánto sube el precio de este tipo con la próxima compra que cuenta
    /// ("+6 % por compra", PLAN-v2 E2a): `quote(n+1)/quote(n) − 1`, con la curva,
    /// el amortiguador y todo lo demás adentro, porque se calcula haciendo la
    /// compra sobre una copia. `nil` si no cotiza o es gratis.
    public static func nextHireStep(
        typeId: String,
        state: PlayerState,
        config: EconomyConfig,
        floorTable: FloorTable,
        tiers: TierRepository,
        costMultiplier: Double = 1.0,
        now: TimeInterval = 0
    ) -> Double? {
        guard let quote = hireQuote(typeId: typeId, state: state, config: config, floorTable: floorTable,
                                    tiers: tiers, costMultiplier: costMultiplier, now: now),
              quote.cost > 0
        else { return nil }
        var after = state
        after.run.registerHire(floorId: floorTable[quote.floorOrdinal].id, typeId: typeId, cushion: config.priceCushion)
        guard let next = hireQuote(typeId: typeId, state: after, config: config, floorTable: floorTable,
                                   tiers: tiers, costMultiplier: costMultiplier, now: now)
        else { return nil }
        return next.cost / quote.cost - 1
    }

    /// Cuánto baja el precio de este tipo si fusionás un par ("fusionar lo
    /// abarata X %"): el reintegro aplicado sobre una copia. `nil` sin reintegro,
    /// si el tipo no se fusiona o si no hay compras que devolver.
    public static func mergeRelief(
        typeId: String,
        state: PlayerState,
        config: EconomyConfig,
        floorTable: FloorTable,
        tiers: TierRepository,
        costMultiplier: Double = 1.0,
        now: TimeInterval = 0
    ) -> Double? {
        let refund = config.hire.mergeRefundCounts
        guard refund > 0, let type = tiers.type(id: typeId), type.mergesInto != nil,
              let quote = hireQuote(typeId: typeId, state: state, config: config, floorTable: floorTable,
                                    tiers: tiers, costMultiplier: costMultiplier, now: now),
              quote.cost > 0
        else { return nil }
        var after = state
        after.run.refundMergeCounts(typeId: typeId, floorId: floorTable[quote.floorOrdinal].id, counts: refund)
        guard let relieved = hireQuote(typeId: typeId, state: after, config: config, floorTable: floorTable,
                                       tiers: tiers, costMultiplier: costMultiplier, now: now)
        else { return nil }
        let relief = 1 - relieved.cost / quote.cost
        return relief > 0 ? relief : nil
    }
```

`PacingSimulator.swift`: una propiedad `let cushion: PriceCushion` junto a `economy`, con
`self.cushion = config.priceCushion` en el `init`. En `hireAction`, antes de armar el `Action`:
`let cushion = self.cushion`, y adentro del closure la línea de E1 T3 pasa a
`s.run.registerHire(floorId: floorId, typeId: typeId, cushion: cushion)`. En `doAllMerges`, la
de E1 T3 pasa a `state.run.raiseFrontier(to: newType.tier, cushion: cushion)`.

`EconomyKnobs.swift`: campo `public var priceReliefPurchases: Int?`, parámetro
`priceReliefPurchases: Int? = nil` en el `init` (después de `mergeRefundCounts`) y en `tuned`:
`if let value = knobs.priceReliefPurchases { hire["priceReliefPurchases"] = value }`.

`/opt/homebrew/bin/xcodegen generate` (archivo nuevo en `FisuEvolutionTests`).

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS, nombra `PriceCushionTests`,
`HireStepTests` y el test nuevo del simulador; la suite de E1 T3 (`RunMutatorsTests`) sigue verde.
Receta R con `-only-testing:FisuEvolutionTests/PriceCushionContentTests` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift \
  Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PriceCushionTests.swift Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift FisuEvolutionTests/PriceCushionContentTests.swift
git diff --cached --stat
git commit -m "feat(precios): el amortiguador del salto de precio y el paso de la próxima compra"
```

---

### Task 4: Pisos en marcha, y la capacidad que sólo crece

**Objetivo:** `staffedFloorBonus` (0 = v1): cada piso con todos sus lugares ocupados suma al
multiplicador global de ingresos, en el pasivo (y por lo tanto en el offline y en los premios en
minutos) y en el toque. Una sola función para el juego y el simulador. Y la prueba de que pasar
de 10 a 15 lugares no le saca nada a un save viejo (el dato no se cambia acá: duda 2).

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/StaffedFloors.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`staffedFloorBonus`, `staffedBonusPerFloor`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift` (`basePassivePerSecond`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/GameActions.swift` (`applyTap(…tiers:…)`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`passivePerSecond`, `incomeRate`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift`
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift:24-29` (la llamada de `registerTap`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/StaffedFloorsTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/GameActionsTests.swift` (mecánico: las 10 llamadas a `applyTap` suman `tiers:`), `EconomyKnobsTests.swift`, `PacingSimulatorTests.swift`

**Interfaces:**
- Produces: `EconomyConfig.staffedFloorBonus: Double?` y `EconomyConfig.staffedBonusPerFloor: Double` (`?? 0`).
- Produces: `public enum StaffedFloors` con `ordinals(state:tiers:floorTable:) -> [Int]` y `multiplier(state:tiers:floorTable:config:) -> Double`.
- Produces: `StandardEconomy.applyTap(type:state:tiers:floorTable:now:) -> Double` (`tiers` sin default).
- Produces: `EconomyKnobs.staffedFloorBonus: Double?`; en `PacingSimulatorTests`, `upConfig(maxTier:gateTierDistance:capacity:)` con `capacity: Int = 10`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/StaffedFloorsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Pisos en marcha")
struct StaffedFloorsTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func bonus(_ value: Double) throws -> EconomyConfig {
        try fxConfig().tuned(EconomyKnobs(staffedFloorBonus: value))
    }

    @Test("un piso con todos sus lugares ocupados está en marcha; con uno libre, no")
    func fullMeansStaffed() throws {
        let floorTable = try fxFloorTable()
        #expect(StaffedFloors.ordinals(state: fxState(units: ["a": 3, "b": 2]), tiers: tiers, floorTable: floorTable) == [0])
        #expect(StaffedFloors.ordinals(state: fxState(units: ["a": 4]), tiers: tiers, floorTable: floorTable).isEmpty)
    }

    @Test("sin la perilla no suma nada: es la v1")
    func zeroBonusIsV1() throws {
        #expect(StaffedFloors.multiplier(state: fxState(units: ["a": 5]), tiers: tiers,
                                         floorTable: try fxFloorTable(), config: fxConfig()) == 1)
    }

    @Test("dos pisos en marcha suman dos veces")
    func bonusesAdd() throws {
        let multiplier = StaffedFloors.multiplier(state: fxState(units: ["a": 5, "d": 5]), tiers: tiers,
                                                  floorTable: try fxFloorTable(), config: try bonus(0.05))
        #expect(abs(multiplier - 1.10) < 1e-12)
    }

    @Test("el bono es global: el mismo número en el pasivo, el toque y el offline")
    func theBonusIsGlobal() throws {
        let tuned = try bonus(0.05)
        let floorTable = try fxFloorTable()
        var state = fxState(units: ["a": 5])
        state.run.passiveUnlocked["a"] = true
        let passive = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: tuned)
            / IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig())
        #expect(abs(passive - 1.05) < 1e-12)

        let type = try #require(tiers.type(id: "a"))
        var boosted = state
        var plain = state
        let boostedTap = fxEconomy(config: tuned).applyTap(type: type, state: &boosted, tiers: tiers, floorTable: floorTable, now: 0)
        let plainTap = fxEconomy().applyTap(type: type, state: &plain, tiers: tiers, floorTable: floorTable, now: 0)
        #expect(abs(boostedTap / plainTap - 1.05) < 1e-12)

        state.meta.lastSeenTimestamp = 0
        let offline = OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: tuned, now: 600)
            / OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 600)
        #expect(abs(offline - 1.05) < 1e-12)
    }

    @Test("una torre de 5 lugares entra entera en una de 7: la capacidad sólo crece")
    func growingCapacityKeepsEveryUnit() throws {
        var run = fxState(units: ["a": 5, "d": 5]).run
        let small = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable(), tiers: tiers)
        #expect(small.autoMerged == 0 && small.discarded.isEmpty)
        let grown = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable(config: fxConfig(capacity: 7)), tiers: tiers)
        #expect(grown.autoMerged == 0 && grown.discarded.isEmpty)
        #expect(run.units == ["a": 5, "d": 5])
        #expect(grown.tower.floors.map(\.occupiedCount) == [5, 5])
    }
}
```

En `EconomyKnobsTests.eachKnobLands`: `staffedFloorBonus: 0.05` y
`#expect(tuned.staffedBonusPerFloor == 0.05)`.

En `PacingSimulatorTests.swift`, `upConfig` suma `capacity: Int = 10` (en vez del `10` escrito
en el `FloorDef`), y en `PacingSimulatorKnobTests`:

```swift
    @Test("con el bono en cero el bot juega igual; con pisos chicos y el bono puesto, cobra distinto")
    func theSimulatorReadsTheStaffedBonus() throws {
        // Con 10 lugares el bot fusiona todo y nunca llena un piso: llenarlos
        // a propósito es la política de E2b. Con 3, se llenan solos.
        let small = upConfig(capacity: 3)
        let base = try PacingSimulator(config: small, tiers: upTiers()).run(maxDays: 5)
        let zero = try PacingSimulator(config: small.tuned(EconomyKnobs(staffedFloorBonus: 0)), tiers: upTiers()).run(maxDays: 5)
        let on = try PacingSimulator(config: small.tuned(EconomyKnobs(staffedFloorBonus: 0.5)), tiers: upTiers()).run(maxDays: 5)
        #expect(fingerprint(zero) == fingerprint(base))
        #expect(fingerprint(on) != fingerprint(base))
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "StaffedFloorsTests|EconomyKnobsTests|PacingSimulatorKnobTests"`
Expected: no compila (`StaffedFloors`, `staffedFloorBonus`, `applyTap(…tiers:…)`).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/StaffedFloors.swift`:

```swift
import Foundation

/// Pisos en marcha (PLAN-v2 §2, crítica de Marco): cada piso con todos sus
/// lugares ocupados suma `staffedBonusPerFloor` a los ingresos globales. Los
/// pisos bajos vuelven a servir para algo.
///
/// La ocupación sale de `run.units` agrupadas por el piso de su tier: es lo que
/// la torre tiene en sus slots (`tower.unitCounts == run.units`) y lo único que
/// tiene el simulador, que no arma torre.
public enum StaffedFloors {
    public static func ordinals(state: PlayerState, tiers: TierRepository, floorTable: FloorTable) -> [Int] {
        var occupied = [Int](repeating: 0, count: floorTable.count)
        for (typeId, count) in state.run.units where count > 0 {
            guard let type = tiers.type(id: typeId), !type.isChoiceNode else { continue }
            occupied[floorTable.ordinal(forTier: type.tier)] += count
        }
        return occupied.indices.filter { occupied[$0] >= floorTable[$0].capacity }
    }

    public static func multiplier(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        let bonus = config.staffedBonusPerFloor
        guard bonus > 0 else { return 1 }
        return 1 + bonus * Double(ordinals(state: state, tiers: tiers, floorTable: floorTable).count)
    }
}
```

`EconomyConfig.swift`, después de `offlinePopupMinSeconds`:

```swift
    /// Pisos en marcha: cuánto suma a los ingresos globales cada piso con todos
    /// sus lugares ocupados (0,05 = +5 %). Vive en la raíz y no en `floors`,
    /// que es un array. Opcional como `tapFloorMultiplierExponent`: sin la
    /// clave vale 0, la v1. [TUNEABLE]
    public let staffedFloorBonus: Double?
```

`init` suma `staffedFloorBonus: Double? = nil` antes de `floors` y lo asigna; y junto a
`offlinePopupThreshold`:

```swift
    public var staffedBonusPerFloor: Double { staffedFloorBonus ?? 0 }
```

`IncomeTicker.basePassivePerSecond`, la última línea:

```swift
        return total * state.meta.globalMultiplier * state.meta.derivedEffects.incomeMultiplier
            * StaffedFloors.multiplier(state: state, tiers: tiers, floorTable: floorTable, config: config)
```

`GameActions.swift`, `applyTap` suma `tiers: TierRepository` entre `state:` y `floorTable:`, y al
producto de `gain`, después de `state.meta.globalMultiplier`:

```swift
            * StaffedFloors.multiplier(state: state, tiers: tiers, floorTable: floorTable, config: config)
```

(el docstring suma "y el de pisos en marcha"). `GameState+Actions.swift:24-29`:
`economy.applyTap(type: type, state: &player, tiers: content.tiers, floorTable: content.floorTable, now: …)`.
`GameActionsTests`: las 10 llamadas suman `tiers: try fxTiers()` (o la variable de tiers que use
la suite).

`PacingSimulator.swift`: `passivePerSecond(state:)` multiplica su `return` por
`StaffedFloors.multiplier(state: state, tiers: tiers, floorTable: floorTable, config: config)`; en
`incomeRate`, el término del toque (`rate += bestTap * …`) suma el mismo factor al final.

`EconomyKnobs.swift`: `public var staffedFloorBonus: Double?`, su parámetro en el `init` y en
`tuned`: `if let value = knobs.staffedFloorBonus { root["staffedFloorBonus"] = value }`.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `StaffedFloorsTests` y
`GameActionsTests` entera). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/StaffedFloors.swift Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift \
  Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift Packages/EconomyKit/Sources/EconomyKit/GameActions.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift \
  FisuEvolution/Game/State/GameState+Actions.swift Packages/EconomyKit/Tests/EconomyKitTests/StaffedFloorsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/GameActionsTests.swift Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift
git diff --cached --stat
git commit -m "feat(economia): pisos en marcha, un bono global por piso lleno detrás de una perilla"
```

---

### Task 5: El piso móvil para reencarnar

**Objetivo:** `oro.requiresLastRunWall` (false = v1): con la perilla, para reencarnar hay que
alcanzar el tier más alto de la run anterior (`MetaState.lastRunMaxTier`, E1 T4); la primera
reencarnación (0) no pide nada. El simulador pasa por la misma puerta que el botón, y su reporte
anota hasta dónde llegó cada run (lo necesita el contrato 5 de E2b).

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`OroConfig.requiresLastRunWall`, `requiresWall`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`wantsToReincarnate`, `Report.maxTierPerRun`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/MovingWallTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`, `PacingSimulatorTests.swift`

**Interfaces:**
- Consumes: `MetaState.lastRunMaxTier` (E1 T4).
- Produces: `EconomyConfig.OroConfig.requiresLastRunWall: Bool?` y `requiresWall: Bool`; `EconomyKnobs.requiresLastRunWall: Bool?`.
- Produces: `PrestigeCalculator.lastRunWallGoal(state:economy:) -> Int?`; `canReincarnate` además exige `lastRunWallGoal == nil`.
- Produces: `PacingSimulator.wantsToReincarnate(state:) -> Bool` (internal) y `PacingSimulator.Report.maxTierPerRun: [Int]`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/MovingWallTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Piso móvil para reencarnar")
struct MovingWallTests {
    /// Con mucho ORO por cobrar: lo único que puede frenar es la pared.
    private func ready(lastWall: Int, frontier: Int) -> PlayerState {
        var state = fxState()
        state.meta.lifetimeEarnings = 1e12
        state.meta.lastRunMaxTier = lastWall
        state.run.raiseFrontier(to: frontier)
        return state
    }

    private func walled() throws -> StandardEconomy {
        StandardEconomy(config: try fxConfig().tuned(EconomyKnobs(requiresLastRunWall: true)))
    }

    @Test("sin la perilla, reencarnar sigue pidiendo sólo ORO: la v1")
    func offIsV1() {
        let state = ready(lastWall: 4, frontier: 2)
        #expect(PrestigeCalculator.canReincarnate(state: state, economy: fxEconomy()))
        #expect(PrestigeCalculator.lastRunWallGoal(state: state, economy: fxEconomy()) == nil)
    }

    @Test("con la perilla, hace falta llegar a la pared de la run anterior")
    func onNeedsTheWall() throws {
        let economy = try walled()
        let blocked = ready(lastWall: 4, frontier: 2)
        #expect(!PrestigeCalculator.canReincarnate(state: blocked, economy: economy))
        #expect(PrestigeCalculator.lastRunWallGoal(state: blocked, economy: economy) == 4)
        #expect(PrestigeCalculator.canReincarnate(state: ready(lastWall: 4, frontier: 4), economy: economy))
    }

    @Test("la primera reencarnación no pide pared")
    func theFirstHasNoWall() throws {
        #expect(PrestigeCalculator.canReincarnate(state: ready(lastWall: 0, frontier: 1), economy: try walled()))
    }

    @Test("llegar a la pared no alcanza sin ORO")
    func theWallAloneIsNotEnough() throws {
        var state = ready(lastWall: 2, frontier: 2)
        state.meta.lifetimeEarnings = 0
        #expect(!PrestigeCalculator.canReincarnate(state: state, economy: try walled()))
    }
}
```

En `EconomyKnobsTests.eachKnobLands`: `requiresLastRunWall: true` y
`#expect(tuned.oro.requiresWall)`; y en `noKnobsIsTheSameConfig`, además
`#expect(!fxConfig().oro.requiresWall)`.

En `PacingSimulatorKnobTests`:

```swift
    @Test("el bot pasa por la misma puerta que el botón: con el piso móvil, no reencarna antes de su pared")
    func theBotHonorsTheMovingWall() throws {
        let walled = try PacingSimulator(config: upConfig().tuned(EconomyKnobs(requiresLastRunWall: true)), tiers: upTiers())
        let open = try upSimulator()
        var state = PlayerState.newGame(startTypeId: "t1", startFloorId: "f1", offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0)
        state.meta.lifetimeEarnings = 1e9
        state.meta.lastRunMaxTier = 9
        state.run.raiseFrontier(to: 5)
        #expect(!walled.wantsToReincarnate(state: state))
        #expect(open.wantsToReincarnate(state: state))
        state.run.raiseFrontier(to: 9)
        #expect(walled.wantsToReincarnate(state: state))
    }

    @Test("con la perilla apagada el bot reencarna como siempre, y cada run anota hasta dónde llegó")
    func offIsTheBaselineAndRunsReportTheirTop() throws {
        let base = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let off = try PacingSimulator(
            config: upConfig().tuned(EconomyKnobs(requiresLastRunWall: false)), tiers: upTiers(), upgrades: upCheapLines()
        ).run(maxDays: 5)
        #expect(fingerprint(off) == fingerprint(base))
        #expect(base.maxTierPerRun.count == base.reincarnations + 1)
        #expect(base.maxTierPerRun.last == base.finalMaxTier)
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "MovingWallTests|EconomyKnobsTests|PacingSimulatorKnobTests"`
Expected: no compila (`requiresLastRunWall`, `lastRunWallGoal`, `wantsToReincarnate`, `maxTierPerRun`).

- [ ] **Step 3: La implementación**

`EconomyConfig.swift`, en `OroConfig`, después de `prestigeTeaserFloorId`:

```swift
        /// Piso móvil (PLAN-v2 §2, crítica de Marco): para reencarnar hay que
        /// alcanzar el tier más alto de la run anterior. Opcional como el
        /// teaser: sin la clave, false, la v1. [TUNEABLE]
        public let requiresLastRunWall: Bool?

        public var requiresWall: Bool { requiresLastRunWall ?? false }
```

El `init` de `OroConfig` suma `requiresLastRunWall: Bool? = nil` al final y lo asigna.

`PrestigeCalculator.swift`:

```swift
    public static func canReincarnate(state: PlayerState, economy: StandardEconomy) -> Bool {
        oroGained(state: state, economy: economy) >= 1 && lastRunWallGoal(state: state, economy: economy) == nil
    }

    /// El tier al que todavía hay que llegar para reencarnar (piso móvil), o
    /// `nil` si no se pide nada: la perilla apagada, la primera reencarnación
    /// (`lastRunMaxTier` en 0) o la pared ya alcanzada.
    public static func lastRunWallGoal(state: PlayerState, economy: StandardEconomy) -> Int? {
        guard economy.config.oro.requiresWall, state.run.maxTierReached < state.meta.lastRunMaxTier else { return nil }
        return state.meta.lastRunMaxTier
    }
```

`PacingSimulator.swift`: en `Report`, junto a `reincarnations`:

```swift
        /// Hasta qué tier llegó cada run, en orden; la última es la que quedó
        /// abierta. Es la serie del contrato "cada run llega más lejos" (E2b).
        public var maxTierPerRun: [Int] = []
```

`maybeReincarnate` reemplaza su `guard case …` y el cálculo del umbral por
`guard wantsToReincarnate(state: state) else { return }`, y antes de `applyReincarnation` hace
`report.maxTierPerRun.append(state.run.maxTierReached)`. La función nueva (con el comentario del
umbral que estaba en `maybeReincarnate`):

```swift
    /// La política del bot más la regla del juego: el umbral de ORO de
    /// `human.reincarnation` y, encima, `PrestigeCalculator.canReincarnate`, la
    /// misma puerta que el botón. Así el piso móvil vale igual para el bot.
    func wantsToReincarnate(state: PlayerState) -> Bool {
        guard case .whenOroMultiplies(let multiple) = human.reincarnation else { return false }
        let gained = PrestigeCalculator.oroGained(state: state, economy: economy)
        // La cuenta va en Double: `oroEarnedLifetime × multiple` en Int desborda.
        let threshold = max(1, Double(state.meta.oroEarnedLifetime) * multiple)
        return Double(gained) >= threshold && PrestigeCalculator.canReincarnate(state: state, economy: economy)
    }
```

En `run(maxDays:)`, junto a `report.finalMaxTier = state.run.maxTierReached`:
`report.maxTierPerRun.append(state.run.maxTierReached)`.

`EconomyKnobs.swift` queda completo (las cinco perillas; `oro` recién ahora, porque una `var`
que no se muta es un warning):

```swift
public struct EconomyKnobs: Codable, Sendable, Equatable {
    public var defaultCostGrowth: Double?
    public var mergeRefundCounts: Double?
    public var priceReliefPurchases: Int?
    public var staffedFloorBonus: Double?
    public var requiresLastRunWall: Bool?

    public init(
        defaultCostGrowth: Double? = nil,
        mergeRefundCounts: Double? = nil,
        priceReliefPurchases: Int? = nil,
        staffedFloorBonus: Double? = nil,
        requiresLastRunWall: Bool? = nil
    ) {
        self.defaultCostGrowth = defaultCostGrowth
        self.mergeRefundCounts = mergeRefundCounts
        self.priceReliefPurchases = priceReliefPurchases
        self.staffedFloorBonus = staffedFloorBonus
        self.requiresLastRunWall = requiresLastRunWall
    }
}

extension EconomyConfig {
    public func tuned(_ knobs: EconomyKnobs) throws -> EconomyConfig {
        guard var root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any],
              var hire = root["hire"] as? [String: Any],
              var oro = root["oro"] as? [String: Any]
        else { throw EconomyKnobsError.notAnObject }
        if let value = knobs.defaultCostGrowth { hire["defaultCostGrowth"] = value }
        if let value = knobs.mergeRefundCounts { hire["mergeRefundCounts"] = value }
        if let value = knobs.priceReliefPurchases { hire["priceReliefPurchases"] = value }
        if let value = knobs.staffedFloorBonus { root["staffedFloorBonus"] = value }
        if let value = knobs.requiresLastRunWall { oro["requiresLastRunWall"] = value }
        root["hire"] = hire
        root["oro"] = oro
        return try JSONDecoder().decode(EconomyConfig.self, from: JSONSerialization.data(withJSONObject: root))
    }
}
```

(el docstring del struct, del error y de `tuned` son los de T2.)

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `MovingWallTests` y los dos
tests nuevos del simulador; `PacingSimulatorTests` entera sigue verde). `Tools/v2/oraculo.sh rapido`
→ `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/MovingWallTests.swift Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift
git diff --cached --stat
git commit -m "feat(prestigio): el piso móvil para reencarnar, también para el simulador"
```

---

### Task 6: "Fusionar todo" — el plan del piso

**Objetivo:** el planificador puro de "Fusionar todo" (PLAN-v2 §2): todos los pares de un piso,
en el orden en que se funden, en cadena (lo que sale de una fusión vuelve a contar), sin tocar el
par que pide carrera y sin planear un ascenso sin lugar arriba. Devuelve `BoardChange`s del
embudo de E1, así que cada uno se juega en su turno, revalidado y revelando lo nuevo. PLAN-v2 lo
nombra `TowerActions.planMergeAll(floor:)`; vive junto a sus hermanos en `BoardChangePlanner`.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (`BoardChangePlanner`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/MergeAllPlannerTests.swift`

**Interfaces:**
- Consumes: `BoardChange`, `BoardChangePlanner.fits` (privado), `BoardChangeApplier.apply(_:state:tower:tiers:floorTable:)` (E1 T7).
- Produces: `BoardChangePlanner.planMergeAll(floorOrdinal:state:tower:tiers:floorTable:origin:) -> [BoardChange]`. **T9 le suma `config:`** cuando el aplicador lo pide.
- No suma casos a `BoardChange.Origin`: cada épica que lo active usa el suyo (E6, E7b) y el panel de debug usa `.debug`. Así no rompe el `switch` exhaustivo de `discardBoardChange` (E1 T14).

- [ ] **Step 0: Pararse en la base**

`grep -n "enum BoardChangePlanner" Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (E1 T7).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/MergeAllPlannerTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Fusionar todo: el plan del piso")
struct MergeAllPlannerTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func plan(_ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable), floor: Int = 0) -> [BoardChange] {
        BoardChangePlanner.planMergeAll(
            floorOrdinal: floor, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .debug
        )
    }

    @Test("funde todos los pares del piso, de abajo para arriba, y lo que sale vuelve a contar")
    func mergesEveryPairInAChain() throws {
        var fx = try fxStateAndTower(units: ["a": 4])
        fx.state.run.chosenCareerPath = "prog"
        #expect(plan(fx).map(\.resultTypeId) == ["b", "b", "c_prog"])
    }

    @Test("sin carrera elegida no toca el par que la pide")
    func neverTheCareerPair() throws {
        #expect(plan(try fxStateAndTower(units: ["a": 4])).map(\.resultTypeId) == ["b", "b"])
    }

    @Test("sin lugar arriba no planea el ascenso")
    func noRoomUpstairs() throws {
        var fx = try fxStateAndTower(units: ["b": 2, "d": 5])
        fx.state.run.chosenCareerPath = "prog"
        #expect(plan(fx).isEmpty)
    }

    @Test("aplicado en orden deja el piso sin pares y no toca los otros pisos")
    func applyingThePlanLeavesNoPairs() throws {
        var fx = try fxStateAndTower(units: ["a": 3, "c_prog": 2])
        fx.state.run.chosenCareerPath = "prog"
        for change in plan(fx) {
            _ = try BoardChangeApplier.apply(change, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable)
        }
        let pairs = Dictionary(grouping: fx.tower.placements(onFloor: 0), by: \.typeId).filter { $0.value.count >= 2 }
        #expect(pairs.isEmpty)
        #expect(fx.state.run.units["c_prog"] == 2)
    }

    @Test("cada cambio tiene su id y lleva el origen pedido")
    func changesAreDistinctAndKeepTheirOrigin() throws {
        let changes = plan(try fxStateAndTower(units: ["a": 4]))
        #expect(Set(changes.map(\.id)).count == changes.count)
        #expect(changes.allSatisfy { $0.origin == .debug })
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter MergeAllPlannerTests`
Expected: no compila (`planMergeAll`).

- [ ] **Step 3: La implementación**

En `BoardChangePlanner` (después de `planAutoMerge`):

```swift
    /// "Fusionar todo" (PLAN-v2 §2): todos los pares de un piso, en el orden en
    /// que se funden. Lo que sale de una fusión vuelve a contar, así que la
    /// cadena sube sola; nunca toca el par que pide carrera ni planea un ascenso
    /// sin lugar arriba. Se planea sobre una copia: cada cambio se juega después
    /// en su turno, revalidado como cualquier otro.
    public static func planMergeAll(
        floorOrdinal: Int,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> [BoardChange] {
        guard tower.floors.indices.contains(floorOrdinal) else { return [] }
        var scratchState = state
        var scratchTower = tower
        var plan: [BoardChange] = []
        // Cada fusión saca al menos una unidad del piso: el tope es su capacidad.
        for _ in 0..<tower.floors[floorOrdinal].slots.count {
            guard let change = lowestPair(onFloor: floorOrdinal, state: scratchState, tower: scratchTower,
                                          tiers: tiers, floorTable: floorTable, origin: origin),
                  (try? BoardChangeApplier.apply(change, state: &scratchState, tower: &scratchTower,
                                                tiers: tiers, floorTable: floorTable)) != nil
            else { break }
            plan.append(change)
        }
        return plan
    }

    /// El par más bajo del piso que se puede fundir: la cadena sube de abajo.
    private static func lowestPair(
        onFloor ordinal: Int,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        let groups = Dictionary(grouping: tower.placements(onFloor: ordinal), by: \.typeId)
            .compactMap { typeId, placements -> (typeId: String, slots: [Int], tier: Int)? in
                guard placements.count >= 2, let type = tiers.type(id: typeId) else { return nil }
                return (typeId, placements.map(\.slot).sorted(), type.tier)
            }
            .sorted { $0.tier == $1.tier ? $0.typeId < $1.typeId : $0.tier < $1.tier }
        for group in groups {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: group.typeId, targetTypeId: group.typeId,
                chosenCareerPath: state.run.chosenCareerPath, tiers: tiers
            ), fits(newTypeId, from: ordinal, tower: tower, tiers: tiers, floorTable: floorTable)
            else { continue }
            return BoardChange(
                kind: .merge(floorOrdinal: ordinal, typeId: group.typeId,
                             sourceSlot: group.slots[0], targetSlot: group.slots[1], newTypeId: newTypeId),
                origin: origin
            )
        }
        return nil
    }
```

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter "MergeAllPlannerTests|BoardChangeTests"` →
PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift Packages/EconomyKit/Tests/EconomyKitTests/MergeAllPlannerTests.swift
git diff --cached --stat
git commit -m "feat(tablero): el plan de Fusionar todo, en cadena y por el embudo de cambios"
```

---

### Task 7: Los cofres y los packs de plata pagan minutos de producción

**Objetivo:** las dos fuentes de premios que no tocan archivos calientes pasan a la tabla del
dueño: cofre completo **20 min**, de reencarnación **45**; IAP de plata S/M/L **1 h / 6 h / 24 h**;
starter **4 h** + skin. Nace el envoltorio de la app (`GameState.coinPayout(minutes:)`) que usan
todas las fuentes. Las claves JSON pasan a `…Minutes` / `coinMinutes`.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+RewardScale.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Game/State/GameState+Chests.swift` (`presentChestReward` y sus dos llamadas, `:107-111` y `:196-202`; el pago en `:238-245`)
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (`creditStorePurchase` `:238-242`, `packRewardText` `:266-278`)
- Modify: `FisuEvolution/Managers/Store/ProductCatalog.swift` (`coinFactor` → `coinMinutes`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ChestsConfig.swift` (`…PayoutFactor` → `…PayoutMinutes`)
- Modify: `FisuEvolution/Resources/Config/chests.json`, `products.json`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` (`fxChests`)
- Test: `FisuEvolutionTests/ChestSourcesTests.swift:217-254`, `StorePacksTests.swift`, `StoreTimeoutTests.swift:28-35`, `IAPCopyTests.swift:66-68`, `StoreManagerTests.swift:82-91`, `GameContentValidationTests.swift:756-769`

**Interfaces:**
- Consumes: `RewardScale.coinPayout(minutes:…)` (T1).
- Produces: `static func GameState.coinPayout(minutes: Double, player: PlayerState, content: GameContent) -> Double`.
- Produces: `ChestsConfig.completedPayoutMinutes: Double`, `prestigePayoutMinutes: Double`; `ProductCatalog.Entry.coinMinutes: Double?`.

- [ ] **Step 1: Los tests, en rojo**

`GameContentValidationTests.chestConfigMatchesTunedValues`: las dos líneas de factores pasan a
`#expect(chests.completedPayoutMinutes == 20)` y `#expect(chests.prestigePayoutMinutes == 45)`, y
el `@Test` se llama "chests.json trae los pesos y los minutos del dueño". A su lado:

```swift
    @Test("los packs de plata pagan los minutos del dueño: 1 h, 6 h y 24 h, y el starter 4 h")
    func coinPacksPayTheOwnersMinutes() throws {
        let catalog = try ProductCatalog.load(from: .main)
        let minutes = Dictionary(uniqueKeysWithValues: catalog.products.compactMap { entry in
            entry.coinMinutes.map { (entry.id, $0) }
        })
        #expect(minutes == [
            "com.fisuevolution.iap.starter_pack": 240,
            "com.fisuevolution.iap.coins_small": 60,
            "com.fisuevolution.iap.coins_medium": 360,
            "com.fisuevolution.iap.coins_large": 1440,
        ])
    }
```

`ChestSourcesTests.anEmptyPoolPaysCoins`: el `@Test` pasa a "con la bolsa agotada el cofre paga
sus minutos de producción, y el de prestigio más"; `let economy = …` y `let base = …` salen, y:

```swift
        let player = try #require(state.player)
        let pagoNormal = GameState.coinPayout(minutes: content.chests.completedPayoutMinutes, player: player, content: content)
        let pagoDePrestigio = GameState.coinPayout(minutes: content.chests.prestigePayoutMinutes, player: player, content: content)
```

(antes de `awardChest`), la comparación del normal usa `pagoNormal` y la del de prestigio
`antesDelDePrestigio + pagoDePrestigio`, con el mensaje "el de la reencarnación paga sus 45 min".

`StorePacksTests`: `coinPack(id:factor:)` pasa a `coinPack(id:minutes:)` con
`coinMinutes: minutes`; `starterPack` con `coinMinutes: 240`; `oroPack` y el `removeAds` con
`coinMinutes: nil`. Los tres tests de plata calculan el esperado **antes** de acreditar y con la
misma función que el juego:

```swift
    @Test("un pack de plata paga sus minutos de producción")
    func coinPackPaysItsMinutes() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(12)
        let content = try #require(gameState.content)
        let before = try #require(gameState.player)
        let expected = GameState.coinPayout(minutes: 60, player: before, content: content)
        #expect(expected > 0)

        gameState.creditStorePurchase(coinPack(minutes: 60), transactionID: "1")

        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins + expected)
        #expect(after.meta.lifetimeEarnings == before.meta.lifetimeEarnings + expected)
    }
```

`coinPackRowSaysHowMuchItGives` usa
`CoinFormatter.string(from: GameState.coinPayout(minutes: 60, player: try #require(gameState.player), content: content))`
y `coinPack(minutes: 60)`; `starterPackCreditsItsCoins` usa
`GameState.coinPayout(minutes: 240, player: before, content: content)`.
`StoreTimeoutTests:33`: `coinMinutes: 60`. `IAPCopyTests:67`: `coinMinutes: nil`.
`StoreManagerTests.purchasingACoinPackCreditsCoins` (corre en 18.6):

```swift
        let content = try #require(gameState.content)
        let expected = GameState.coinPayout(minutes: 60, player: try #require(gameState.player), content: content)
```

en vez de `economy`/`passiveUnlockCost(forTier: 12) * 15`.

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/GameContentValidationTests -only-testing:FisuEvolutionTests/StorePacksTests -only-testing:FisuEvolutionTests/ChestSourcesTests`.
Expected: no compila (`coinPayout`, `coinMinutes`, `…PayoutMinutes`).

- [ ] **Step 3: La implementación**

`FisuEvolution/Game/State/GameState+RewardScale.swift`:

```swift
import EconomyKit
import Foundation

/// Los premios en minutos de producción (PLAN-v2 E2a): todo lo que paga "N
/// minutos" pasa por acá, y la cuenta vive en `RewardScale` (EconomyKit).
extension GameState {
    static func coinPayout(minutes: Double, player: PlayerState, content: GameContent) -> Double {
        RewardScale.coinPayout(
            minutes: minutes, state: player, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy
        )
    }
}
```

`ChestsConfig.swift`: las dos propiedades, sus docstrings, el `init` y las asignaciones:

```swift
    /// Minutos de producción que paga un cofre cuando ya no queda pinta que dar.
    public let completedPayoutMinutes: Double
    /// Lo mismo para el cofre de la reencarnación, que paga más.
    public let prestigePayoutMinutes: Double
```

`chests.json`: `"completedPayoutMinutes": 20,` y `"prestigePayoutMinutes": 45,` en lugar de los
dos factores. `Fixtures.fxChests`: `completedPayoutMinutes: 20, prestigePayoutMinutes: 45`.

`GameState+Chests.swift`: `presentChestReward(_:payoutFactor:origen:)` pasa a
`presentChestReward(_:payoutMinutes:origen:)` (su docstring: "`payoutMinutes` sólo se usa en la
rama de plata: los minutos de producción del cofre común o del de la reencarnación"; el párrafo
que hablaba de `economy` pasa a decir lo mismo de `content`), su guard a
`guard let content, var player else { return }`, y la rama de plata:

```swift
        case let .coins(rarity):
            // Los mismos minutos de producción que todos los premios de plata
            // del juego (`RewardScale`).
            let monto = Self.coinPayout(minutes: payoutMinutes, player: player, content: content)
```

Las dos llamadas pasan `payoutMinutes: dePrestigio ? content.chests.prestigePayoutMinutes : content.chests.completedPayoutMinutes`
y `payoutMinutes: content.chests.completedPayoutMinutes`.

`ProductCatalog.swift`:

```swift
        /// `coins` y `starterPack`: minutos de producción que paga (PLAN-v2 E2a:
        /// 1 h, 6 h y 24 h; el starter 4 h). Un monto fijo envejece mal en un
        /// idle exponencial.
        let coinMinutes: Double?
```

`products.json`: `"coinFactor": 40.0` → `"coinMinutes": 240`, `15.0` → `60`, `90.0` → `360`,
`220.0` → `1440`.

`GameState+Store.swift`: `creditStorePurchase` hace `guard let content, var player else { return }`
y

```swift
        case .coins, .starterPack:
            guard let minutes = entry.coinMinutes else { return }
            let amount = Self.coinPayout(minutes: minutes, player: player, content: content)
```

`packRewardText`: `guard let content, let player else { return nil }` y las dos ramas de plata
con `entry.coinMinutes` + `Self.coinPayout(minutes:player:content:)`.

`/opt/homebrew/bin/xcodegen generate`.

- [ ] **Step 4: Verde y oráculo**

Receta R con las tres suites → PASS. `swift test --package-path Packages/EconomyKit` → PASS
(`ChestRollerTests` usa `fxChests`). `Tools/v2/oraculo.sh completo` → `VERDE`, con
`StoreManagerTests` verde en `store-unit` (18.6) y el `pacing-sim` en la línea de base.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+RewardScale.swift FisuEvolution/Game/State/GameState+Chests.swift \
  FisuEvolution/Game/State/GameState+Store.swift FisuEvolution/Managers/Store/ProductCatalog.swift \
  Packages/EconomyKit/Sources/EconomyKit/ChestsConfig.swift FisuEvolution/Resources/Config/chests.json \
  FisuEvolution/Resources/Config/products.json Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift \
  FisuEvolutionTests/ChestSourcesTests.swift FisuEvolutionTests/StorePacksTests.swift FisuEvolutionTests/StoreTimeoutTests.swift \
  FisuEvolutionTests/IAPCopyTests.swift FisuEvolutionTests/StoreManagerTests.swift FisuEvolutionTests/GameContentValidationTests.swift
git diff --cached --stat
git commit -m "feat(premios): los cofres y los packs de plata pagan minutos de producción"
```

---

### Task 8: El piso móvil en pantalla — la meta para reencarnar

**Objetivo:** con la perilla del piso móvil, el botón de reencarnar aparece igual cuando hay ORO
por cobrar pero falta la pared, y dice la meta; la hoja la explica y no ofrece confirmar. La
copia es **"Meta para reencarnar: {personaje}"** (duda 6): el personaje de ese tier en la carrera
de esta run, o el número de tier si todavía hay cuatro carreras posibles. Sin tocar
`GameState.swift`: `prestigeAvailable` ya sale de `canReincarnate`.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift` (`PrestigePreview`, `prestigePreviewNow`, `wallGoalName`)
- Modify: `FisuEvolution/UI/HUD/PrestigeButton.swift`
- Modify: `FisuEvolution/UI/Popups/PrestigeView.swift`
- Create: `Tools/v2/claves-pendientes/e2a-t8.json`
- Test: `FisuEvolutionTests/PrestigePreviewTests.swift`

**Interfaces:**
- Consumes: `PrestigeCalculator.lastRunWallGoal(state:economy:)`, `OroConfig.requiresWall` (T5); `MetaState.lastRunMaxTier` (E1 T4).
- Produces: `PrestigePreview.wallGoalTier: Int?`, `wallGoalName: String?`, `isBlockedByWall: Bool`, `wallGoalText: String?`, `wallGoalShortText: String?`; `static func GameState.wallGoalName(tier:player:content:) -> String?`.

- [ ] **Step 1: Los tests, en rojo**

En `PrestigePreviewTests.swift`:

```swift
    private func walledGame(lastWall: Int, frontier: Int, career: String? = nil) async throws -> GameState {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.economy = StandardEconomy(config: try content.economy.tuned(EconomyKnobs(requiresLastRunWall: true)))
        gameState.giveEarningsForPrestigeTesting(oro: 9)
        gameState.player?.meta.lastRunMaxTier = lastWall
        gameState.player?.run.raiseFrontier(to: frontier)
        gameState.player?.run.chosenCareerPath = career.map { MergeRules.careerPath(fromOptionId: $0) }
        // `refreshProjections` y no sólo la vista previa: `prestigeAvailable`
        // también se republica ahí, y el fixture de ORO lo dejó calculado antes
        // de la pared.
        gameState.refreshProjections()
        return gameState
    }

    @Test("con el piso móvil, la vista previa nombra la meta y confirmar no hace nada")
    func theMovingWallNamesTheGoal() async throws {
        let gameState = try await walledGame(lastWall: 13, frontier: 9)
        let content = try #require(gameState.content)
        let preview = gameState.prestigePreview
        #expect(preview.isWorthIt)
        #expect(preview.wallGoalTier == 13)
        #expect(preview.wallGoalName == content.tiers.type(id: "director")?.localizedName)
        #expect(!gameState.prestigeAvailable)
        let level = gameState.player?.meta.prestigeLevel
        gameState.confirmPrestige()
        #expect(gameState.player?.meta.prestigeLevel == level)
    }

    @Test("con cuatro carreras posibles y ninguna elegida, la meta es el número de tier")
    func anAmbiguousWallNamesTheTier() async throws {
        let preview = try await walledGame(lastWall: 11, frontier: 9).prestigePreview
        #expect(preview.wallGoalTier == 11)
        #expect(preview.wallGoalName == nil)
        #expect(preview.wallGoalText?.contains("11") == true)
        #expect(preview.wallGoalText?.contains("prestige.wall") == false, "quedó la clave cruda")
    }

    @Test("con la carrera elegida, la meta es el personaje de esa rama")
    func theChosenCareerNamesTheBranch() async throws {
        let gameState = try await walledGame(lastWall: 12, frontier: 11, career: "junior_lawyer")
        let content = try #require(gameState.content)
        #expect(gameState.prestigePreview.wallGoalName == content.tiers.type(id: "senior_lawyer")?.localizedName)
    }

    @Test("sin la perilla no hay meta: es la v1")
    func withoutTheKnobThereIsNoWall() async throws {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 9)
        gameState.player?.meta.lastRunMaxTier = 13
        gameState.refreshProjections()
        #expect(!gameState.prestigePreview.isBlockedByWall)
        #expect(gameState.prestigeAvailable)
    }
```

(La suite suma `import EconomyKit` si no lo tiene.)

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/PrestigePreviewTests`.
Expected: no compila (`wallGoalTier`, `wallGoalName`, `isBlockedByWall`, `wallGoalText`).

- [ ] **Step 3: La implementación**

`GameState+Prestige.swift`, en `PrestigePreview` (después de `nextOroProgress`):

```swift
    /// Piso móvil: el tier al que hay que llegar para poder reencarnar, y el
    /// personaje de ese tier si es uno solo. `nil` en el tier = no se pide nada.
    let wallGoalTier: Int?
    let wallGoalName: String?

    var isBlockedByWall: Bool { wallGoalTier != nil }

    /// "Meta para reencarnar: Director" o "Meta para reencarnar: el tier 11".
    var wallGoalText: String? {
        guard let tier = wallGoalTier else { return nil }
        if let name = wallGoalName { return String(localized: "prestige.wall.goal \(name)") }
        return String(localized: "prestige.wall.goal_tier \(String(tier))")
    }

    /// La versión corta, para la cápsula del HUD.
    var wallGoalShortText: String? {
        guard let tier = wallGoalTier else { return nil }
        if let name = wallGoalName { return String(localized: "prestige.wall.short \(name)") }
        return String(localized: "prestige.wall.short_tier \(String(tier))")
    }
```

`PrestigePreview.empty` suma `wallGoalTier: nil, wallGoalName: nil`. En `prestigePreviewNow`, el
`guard` pasa a `guard let economy, let content, let player else { return .empty }` y el
`PrestigePreview(…)` suma:

```swift
            wallGoalTier: wallGoal,
            wallGoalName: wallGoal.flatMap { Self.wallGoalName(tier: $0, player: player, content: content) }
```

con `let wallGoal = PrestigeCalculator.lastRunWallGoal(state: player, economy: economy)` antes. Y
en la extensión:

```swift
    /// El nombre de la meta del piso móvil: el único personaje de ese tier, o el
    /// de la rama elegida en esta run. Con varias ramas posibles y ninguna
    /// elegida, `nil`: la pantalla dice el número de tier.
    static func wallGoalName(tier: Int, player: PlayerState, content: GameContent) -> String? {
        let candidates = content.tiers.concreteTypes.filter { $0.tier == tier }
        if candidates.count == 1 { return candidates[0].localizedName }
        guard let career = player.run.chosenCareerPath else { return nil }
        return candidates.first { $0.id.hasSuffix(career) }?.localizedName
    }
```

`PrestigeButton.swift`: la condición de `body` pasa a
`gameState.prestigeAvailable || gameState.prestigeTeaser || gameState.prestigePreview.isBlockedByWall`
(el comentario suma "y con el piso móvil, aunque falte la pared: dice la meta"); `secondLine`:

```swift
    private var secondLine: String {
        let preview = gameState.prestigePreview
        if let goal = preview.wallGoalShortText { return goal }
        return preview.isWorthIt
            ? "+\(preview.oroGained)"
            : preview.nextOroProgress.formatted(.percent.precision(.fractionLength(0)))
    }
```

y `spokenLabel` arranca con
`if let goal = preview.wallGoalText { return Text("prestige.button") + Text(verbatim: ", \(goal)") }`.

`PrestigeView.swift`: dentro de `if preview.isWorthIt { … }`, el `ActionPill` queda en la rama
`else` de:

```swift
                    if let goal = preview.wallGoalText {
                        // El piso móvil: hay ORO, falta la pared. No se apaga el
                        // botón, se dice qué falta (doctrina de `ActionPill`).
                        StateBadge(text: goal, systemImage: "lock.fill", textAlignment: .center, muted: true)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("prestige.wall")
                    } else {
                        ActionPill(…)   // el que ya estaba, sin cambios
                    }
```

`Tools/v2/claves-pendientes/e2a-t8.json`:

```json
{
  "prestige.wall.goal %@": {"es": "Meta para reencarnar: %@", "en": "Goal to reincarnate: %@"},
  "prestige.wall.goal_tier %@": {"es": "Meta para reencarnar: el tier %@", "en": "Goal to reincarnate: tier %@"},
  "prestige.wall.short %@": {"es": "Meta: %@", "en": "Goal: %@"},
  "prestige.wall.short_tier %@": {"es": "Meta: tier %@", "en": "Goal: tier %@"}
}
```

`Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e2a-t8.json` para correr los tests (y el
catálogo se commitea o se descarta según el despacho, Global Constraints).

- [ ] **Step 4: Verde y oráculo**

Receta R con `PrestigePreviewTests` y `LocalizationCompletenessTests` → PASS.
`Tools/v2/oraculo.sh completo` → `VERDE` (las UI de prestigio siguen verdes: con la perilla
apagada nada cambia en pantalla).

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Prestige.swift FisuEvolution/UI/HUD/PrestigeButton.swift \
  FisuEvolution/UI/Popups/PrestigeView.swift FisuEvolutionTests/PrestigePreviewTests.swift \
  Tools/v2/claves-pendientes/e2a-t8.json
git diff --cached --stat
git commit -m "feat(prestigio): el botón dice la meta del piso móvil"
```

---

### Task 9: Las fusiones del juego pasan por el amortiguador y el reintegro

**Objetivo:** que toda fusión, evolución y llegada del juego —la del jugador y las del embudo
`BoardChange`— suba la frontera **amortiguada** y devuelva su reintegro, por la misma función que
ya usa el simulador. Las mutaciones de la torre de EconomyKit reciben `config:` (sin default).
Nace `GameState.replaceEconomy(_:)` (DEBUG): cambia las perillas en vivo para los tests y el
panel de debug.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (`applyMerge`, `evolveUnit`, `placeUnit` y el `land` privado de E1 T7)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (`BoardChangeApplier.apply`, `planMergeAll`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (un método, junto a `reconcileTower` `:731`)
- Modify: `FisuEvolution/Managers/GameContentLoader.swift:6` (`let economy` → `var economy`)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`handleDrop`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (cada `BoardChangeApplier.apply`)
- Modify (mecánico): las suites de EK que llaman a `applyMerge`, `evolveUnit`, `placeUnit`, `BoardChangeApplier.apply` o `planMergeAll` suman `config: fxConfig()` (hoy: `GameLoopTests` ×5, `StatsCountersTests` ×9, `SeenTypesTests` ×1, `ExtensibilityDrillTests` ×1; más `BoardChangeTests` y `MergeAllPlannerTests`)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/PriceCushionTests.swift` (la guarda)
- Create: `FisuEvolutionTests/MergeEconomyWiringTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `raiseFrontier(to:cushion:)`, `PriceCushion` (T3); `refundMergeCounts` (T2); `planMergeAll` (T6); `enqueueBoardChange`, `beginNextBoardChange`, `confirmBoardChange(id:)` (E1 T9).
- Produces: `TowerActions.applyMerge(…, floorTable:, config:)`, `evolveUnit(…, floorTable:, config:)`, `placeUnit(…, floorTable:, config:)`; `BoardChangeApplier.apply(_:state:tower:tiers:floorTable:config:)`; `BoardChangePlanner.planMergeAll(floorOrdinal:state:tower:tiers:floorTable:config:origin:)`.
- Produces: `GameState.replaceEconomy(_ config: EconomyConfig)` (`#if DEBUG`); `GameContent.economy` pasa a `var`.

- [ ] **Step 0: Pararse en la base**

Con `version-2` mergeada (E1 T14 adentro): `grep -n "func discardBoardChange" FisuEvolution/Game/State/GameState+BoardChanges.swift`
devuelve una línea, y `grep -rn "applyMerge(\|BoardChangeApplier.apply(\|evolveUnit(\|placeUnit(\|planMergeAll(" FisuEvolution FisuEvolutionTests Packages`
lista los llamadores a actualizar (anotarlos en el reporte: **la lista es la verdad**, no la de
arriba).

- [ ] **Step 1: Los tests, en rojo**

En `PriceCushionTests.swift`, dentro de `PriceCushionTests`:

```swift
    @Test("en el paquete, sólo la carga sube la frontera sin amortiguar")
    func onlyTheLoaderRaisesTheFrontierUncushioned() throws {
        let sources = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/EconomyKit")
        let exempt: Set = ["PlayerState.swift", "TowerReconciler.swift"]
        let offenders = try FileManager.default
            .contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && !exempt.contains($0.lastPathComponent) }
            .filter { file in
                try String(contentsOf: file, encoding: .utf8)
                    .split(separator: "\n")
                    .contains { $0.contains("raiseFrontier(to:") && !$0.contains("cushion:") }
            }
            .map(\.lastPathComponent)
        #expect(offenders.isEmpty, "suben la frontera sin el amortiguador: \(offenders)")
    }
```

`FisuEvolutionTests/MergeEconomyWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las fusiones del juego —la del jugador y las del embudo de cambios— usan la
/// misma cuenta que el simulador: amortiguan la frontera y devuelven el reintegro.
@Suite("Las fusiones del juego pasan por el amortiguador y el reintegro", .serialized)
@MainActor
struct MergeEconomyWiringTests {
    private func game(_ knobs: EconomyKnobs) async throws -> GameState {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.replaceEconomy(try content.economy.tuned(knobs))
        gameState.debugGrantCoins()
        return gameState
    }

    private func homelessPair(_ gameState: GameState) throws -> (source: Int, target: Int) {
        let slots = gameState.visiblePlacements.filter { $0.typeId == "homeless" }.map(\.slot).sorted()
        try #require(slots.count >= 2)
        return (slots[0], slots[1])
    }

    private func price(_ gameState: GameState) throws -> Double {
        try #require(gameState.currentQuote(player: try #require(gameState.player), typeId: "homeless")).cost
    }

    @Test("con el amortiguador, fusionar y subir la frontera no hace saltar el precio")
    func mergingDoesNotJumpThePrice() async throws {
        let gameState = try await game(EconomyKnobs(priceReliefPurchases: 24))
        gameState.hireCharacter(typeId: "homeless")
        let before = try price(gameState)
        let pair = try homelessPair(gameState)
        _ = gameState.handleDrop(fromCell: pair.source, toCell: pair.target)
        #expect(gameState.player?.run.maxTierReached == 2)
        #expect(abs(try price(gameState) / before - 1) < 1e-9)
    }

    @Test("sin el amortiguador, el precio salta como en la v1")
    func withoutTheCushionThePriceJumps() async throws {
        let gameState = try await game(EconomyKnobs())
        gameState.hireCharacter(typeId: "homeless")
        let before = try price(gameState)
        let pair = try homelessPair(gameState)
        _ = gameState.handleDrop(fromCell: pair.source, toCell: pair.target)
        #expect(abs(try price(gameState) / before - 2.8 / 1.5) < 1e-9)
    }

    @Test("con el reintegro, la fusión del jugador devuelve compras a la curva")
    func mergingRefundsPurchases() async throws {
        let gameState = try await game(EconomyKnobs(mergeRefundCounts: 1))
        gameState.hireCharacter(typeId: "homeless")
        gameState.hireCharacter(typeId: "homeless")
        #expect(gameState.player?.run.hireCountsByType["homeless"] == 2)
        let pair = try homelessPair(gameState)
        _ = gameState.handleDrop(fromCell: pair.source, toCell: pair.target)
        #expect(gameState.player?.run.hireCountsByType["homeless"] == 1)
    }

    @Test("un cambio del tablero que sube la frontera también amortigua")
    func boardChangesAreCushionedToo() async throws {
        let gameState = try await game(EconomyKnobs(priceReliefPurchases: 24))
        gameState.hireCharacter(typeId: "homeless")
        let content = try #require(gameState.content)
        let change = try #require(BoardChangePlanner.planAutoMerge(
            state: try #require(gameState.player), tower: try #require(gameState.tower),
            tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        gameState.enqueueBoardChange(change)
        let running = try #require(gameState.beginNextBoardChange())
        gameState.confirmBoardChange(id: running.id)
        #expect(abs((gameState.player?.run.priceRelief ?? 0) - 2.8 / 1.5) < 1e-9)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter PriceCushionTests` → la guarda falla
listando `TowerActions.swift`. Receta R con `-only-testing:FisuEvolutionTests/MergeEconomyWiringTests`
→ no compila (`replaceEconomy`).

- [ ] **Step 3: La implementación**

`TowerActions.swift`:
- `land(…)` suma el parámetro `cushion: PriceCushion` al final y su línea de frontera pasa a
  `state.run.raiseFrontier(to: newType.tier, cushion: cushion)`.
- `applyMerge` suma `config: EconomyConfig` después de `floorTable:`. Después de consumir el par
  (y antes de `totalMergesEver`):

  ```swift
        // El reintegro (PLAN-v2 E2a): después de los guards, junto al resto de
        // la mutación. Un merge que tira no ocurrió y no devuelve nada.
        state.run.refundMergeCounts(
            typeId: sourceType, floorId: floorTable[floorOrdinal].id, counts: config.hire.mergeRefundCounts
        )
  ```

  y su `return land(…)` pasa `cushion: config.priceCushion`.
- `evolveUnit` suma `config: EconomyConfig` y pasa `cushion: config.priceCushion` a `land` (una
  evolución no es una fusión: no devuelve reintegro).
- `placeUnit` suma `config: EconomyConfig` y su frontera pasa a
  `state.run.raiseFrontier(to: type.tier, cushion: config.priceCushion)`.

`BoardChange.swift`: `BoardChangeApplier.apply` suma `config: EconomyConfig` después de
`floorTable:` y lo pasa a las tres llamadas de `TowerActions`; `planMergeAll` suma
`config: EconomyConfig` antes de `origin:` y lo pasa a su `BoardChangeApplier.apply`.

`GameContentLoader.swift:6`: `var economy: EconomyConfig` (el comentario del struct no cambia).

`GameState.swift`, después de `reconcileTower()`:

```swift
    #if DEBUG
    /// Cambia las perillas de `economy.json` en vivo: el panel de debug y los
    /// tests (PLAN-v2 E2a). La torre no se toca, así que una config que mueva
    /// `floors[]` se rechaza.
    func replaceEconomy(_ config: EconomyConfig) {
        guard var content, config.floors == content.economy.floors else { return }
        content.economy = config
        self.content = content
        economy = StandardEconomy(config: config)
        effectsVersion += 1
        refreshProjections()
    }
    #endif
```

`GameState+Actions.swift`, `handleDrop`: la llamada a `TowerActions.applyMerge` suma
`config: content.economy`. `GameState+BoardChanges.swift`: cada `BoardChangeApplier.apply(…)`
suma `config: content.economy`. Cualquier otro llamador que el paso 0 haya listado, lo mismo.

Las suites de EK del listado: `config: fxConfig()` (o la config que la suite ya use para su torre).

`/opt/homebrew/bin/xcodegen generate`.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (la guarda y todas las suites de
fusión). Receta R con `MergeEconomyWiringTests`, `BoardChangeWiringTests` y
`BoardChangeProducersTests` → PASS. `Tools/v2/oraculo.sh completo` → `VERDE`, con el
`pacing-sim` en la línea de base (el simulador no cambió en esta tarea).

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift \
  FisuEvolution/Game/State/GameState.swift FisuEvolution/Managers/GameContentLoader.swift \
  FisuEvolution/Game/State/GameState+Actions.swift FisuEvolution/Game/State/GameState+BoardChanges.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/ FisuEvolutionTests/MergeEconomyWiringTests.swift
git diff --cached --stat
git commit -m "feat(precios): las fusiones del juego amortiguan la frontera y devuelven el reintegro"
```

---

### Task 10: "+6 % por compra" en FisuJobs

**Objetivo:** cada tarjeta de FisuJobs dice cuánto sube su próxima compra ("+6 % por compra"; en
el callejón, +3 %) y, con reintegro, cuánto la abarata fusionar ("fusionar lo abarata 11 %").
Los dos números salen de `TowerActions.nextHireStep` y `mergeRelief`, que cotizan haciendo la
operación sobre una copia: lo mostrado es lo aplicado, con D adentro.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Hiring.swift` (`JobRow`, `jobRows`, `priceTrend(player:typeId:)`)
- Modify: `FisuEvolution/UI/Jobs/FisuJobsView.swift` (`JobCard.info` `:410-420` y `axLabel` `:525-537`)
- Create: `Tools/v2/claves-pendientes/e2a-t10.json`
- Test: `FisuEvolutionTests/JobRowsTests.swift`

**Interfaces:**
- Consumes: `TowerActions.nextHireStep`, `mergeRelief` (T3); `GameState.replaceEconomy` (T9, en el test); `currentQuote(player:typeId:)` (`GameState+Hiring.swift:311`).
- Produces: `JobRow.priceStep: Double?`, `JobRow.mergeRelief: Double?`, `JobRow.priceTrendText: String?`.

- [ ] **Step 1: Los tests, en rojo**

En `JobRowsTests.swift`:

```swift
    @Test("la fila dice cuánto sube la próxima compra, y es lo que sube")
    func theStepShownIsTheStepCharged() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        let row = try jobRow(gameState, "homeless")
        let step = try #require(row.priceStep)
        let text = try #require(row.priceTrendText)
        #expect(!text.contains("jobs.step"), "quedó la clave cruda")
        let player = try #require(gameState.player)
        let before = try #require(gameState.currentQuote(player: player, typeId: "homeless")).cost
        gameState.hireCharacter(typeId: "homeless")
        let after = try #require(gameState.currentQuote(player: try #require(gameState.player), typeId: "homeless")).cost
        #expect(abs(after / before - 1 - step) < 1e-9)
        #expect(text.contains(step.formatted(.percent.precision(.fractionLength(0)))))
    }

    @Test("sin reintegro no promete que fusionar abarata")
    func noReliefWithoutRefund() async throws {
        let row = try jobRow(await makeGameState(), "homeless")
        #expect(row.mergeRelief == nil)
    }

    @Test("con reintegro, lo que dice que baja fusionar es lo que baja")
    func theReliefShownIsTheReliefApplied() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.replaceEconomy(try content.economy.tuned(EconomyKnobs(mergeRefundCounts: 1)))
        gameState.debugGrantCoins()
        gameState.hireCharacter(typeId: "homeless")
        gameState.hireCharacter(typeId: "homeless")
        let relief = try #require(try jobRow(gameState, "homeless").mergeRelief)
        let slots = gameState.visiblePlacements.filter { $0.typeId == "homeless" }.map(\.slot).sorted()
        try #require(slots.count >= 2)
        _ = gameState.handleDrop(fromCell: slots[0], toCell: slots[1])
        let after = try #require(gameState.currentQuote(player: try #require(gameState.player), typeId: "homeless")).cost
        // La fusión subió la frontera (×1,87 en la v1), así que se compara
        // contra el precio a la frontera nueva SIN el reintegro: el mismo
        // estado con la compra devuelta otra vez en la curva.
        var unrefunded = try #require(gameState.player)
        unrefunded.run.hireCountsByType["homeless", default: 0] += 1
        let withoutRefund = try #require(gameState.currentQuote(player: unrefunded, typeId: "homeless")).cost
        #expect(abs(1 - after / withoutRefund - relief) < 1e-9)
    }
```

(La suite suma `import EconomyKit` si no lo tiene.)

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/JobRowsTests`.
Expected: no compila (`priceStep`, `mergeRelief`, `priceTrendText`).

- [ ] **Step 3: La implementación**

`GameState+Hiring.swift`, en `JobRow` (después de `costText`):

```swift
    /// Cuánto sube la próxima compra (0,06 = "+6 %"), con la curva, el
    /// amortiguador y todo lo demás adentro. `nil` en una fila "???".
    let priceStep: Double?
    /// Cuánto la abarata fusionar un par, con reintegro. `nil` sin reintegro.
    let mergeRelief: Double?
    /// "+6 % por compra · fusionar lo abarata 11 %", ya resuelto.
    let priceTrendText: String?
```

En `jobRows`, antes del `return JobRow(…)`:

```swift
            let trend = unseen ? (step: nil, relief: nil) : priceTrend(player: player, typeId: type.id)
```

y el `JobRow(…)` suma `priceStep: trend.step, mergeRelief: trend.relief,
priceTrendText: Self.priceTrendText(step: trend.step, relief: trend.relief)`. Junto a
`currentQuote`:

```swift
    /// El paso y el reintegro con los MISMOS argumentos que `currentQuote`: si
    /// cotizaran distinto, la tarjeta diría un número y la compra cobraría otro.
    func priceTrend(player: PlayerState, typeId: String) -> (step: Double?, relief: Double?) {
        guard let content else { return (nil, nil) }
        let costMultiplier = 1 - content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.meta.prestigeLevel)
        let now = Date().timeIntervalSince1970
        let step = TowerActions.nextHireStep(
            typeId: typeId, state: player, config: content.economy, floorTable: content.floorTable,
            tiers: content.tiers, costMultiplier: costMultiplier, now: now
        )
        let relief = TowerActions.mergeRelief(
            typeId: typeId, state: player, config: content.economy, floorTable: content.floorTable,
            tiers: content.tiers, costMultiplier: costMultiplier, now: now
        )
        return (step, relief)
    }

    /// ⚠️ Los porcentajes van como `String` (trampa 5).
    static func priceTrendText(step: Double?, relief: Double?) -> String? {
        guard let step else { return nil }
        let percent: (Double) -> String = { $0.formatted(.percent.precision(.fractionLength(0))) }
        let stepText = String(localized: "jobs.step \("+" + percent(step))")
        guard let relief else { return stepText }
        return stepText + " · " + String(localized: "jobs.merge_relief \(percent(relief))")
    }
```

`FisuJobsView.swift`, en `info`, después del `HStack` de `floorTag` + `jobs.hired_count`:

```swift
            if !isUnseen, let trend = row.priceTrendText {
                Text(verbatim: trend)
                    .font(Tokens.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
```

y `axLabel` suma `row.priceTrendText` al array, después de `jobs.hired_count`.

`Tools/v2/claves-pendientes/e2a-t10.json`:

```json
{
  "jobs.step %@": {"es": "%@ por compra", "en": "%@ per hire"},
  "jobs.merge_relief %@": {"es": "fusionar lo abarata %@", "en": "merging cuts it %@"}
}
```

`Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e2a-t10.json` para los tests.

- [ ] **Step 4: Verde y oráculo**

Receta R con `JobRowsTests` y `LocalizationCompletenessTests` → PASS. `Tools/v2/oraculo.sh completo`
→ `VERDE` (las UI de FisuJobs siguen verdes; mirar una captura de FisuJobs en el SE para
confirmar que el renglón nuevo no parte la tarjeta).

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolution/UI/Jobs/FisuJobsView.swift \
  FisuEvolutionTests/JobRowsTests.swift Tools/v2/claves-pendientes/e2a-t10.json
git diff --cached --stat
git commit -m "feat(precios): FisuJobs dice cuánto sube la próxima compra y cuánto la abarata fusionar"
```

---

### Task 11: El diario, el asado y los logros en minutos, con el presupuesto de premios

**Objetivo:** el diario paga **5 / 8 / 12 / 18 / 25 / 40** minutos (d1–d6) y el día 7, si no tira
special ni cofre, **15** (hoy es un `× 6.0` escrito en código); el asado **10 min** cada vez; los
logros y todo lo que pase por `coinReward` (la compensación de videos de E1 T14, el compartir de
E3b T9) cotizan por `RewardScale`. Y `RewardBudgetTests`: los premios sin anuncios no pasan el
12 % de la producción de un día.

**Files:**
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (`BoostManager.activate`, `DailyRewardManager.claimIfAvailable`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`DailyRewardsConfig.Day.minutes`; docstring de `BoostsConfig.EffectType.periodicPayout`)
- Modify: `FisuEvolution/Managers/EffectDescriptor.swift` (`EffectUnit.minutes`, el formateador, `.periodicPayout`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`activateBoost` `:155`, `claimDailyIfAvailable` `:260`, `grantCareerReward` `:559`, `effectText(for:)` `:478`)
- Modify: `FisuEvolution/Game/State/GameState+AdOffers.swift:122`, `GameState+Achievements.swift` (`grantFreeBoost` `:301`, `coinReward`, sale `rewardTier`)
- Modify: `FisuEvolution/Resources/Config/daily_rewards.json`, `boosts.json`
- Create: `FisuEvolutionTests/RewardBudgetTests.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolutionTests/ContentSystemsTests.swift`, `EffectContractTests.swift`
- Create: `Tools/v2/claves-pendientes/e2a-t11.json`

**Interfaces:**
- Consumes: `RewardScale` (T1), `GameState.coinPayout(minutes:player:content:)` (T7); `coinReward(seconds:player:content:economy:)` `static` (E1 T14); `EffectContractTests` (E1 T15).
- Produces: `BoostManager.activate(boostId:state:config:upgrades:specials:viral:tiers:floorTable:economy:now:)`; `DailyRewardManager.claimIfAvailable(state:config:specials:skins:upgrades:viral:boosts:economy:tiers:floorTable:today:calendar:rng:)`; `DailyRewardsConfig.Day.minutes: Double?`; `EffectUnit.minutes`.

- [ ] **Step 0: Pararse en la base**

`grep -n "static func coinReward" FisuEvolution/Game/State/GameState+Achievements.swift` (sin
`private`, E1 T14) y `grep -n "func applied" FisuEvolutionTests/EffectContractTests.swift` (E1 T15).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/RewardBudgetTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los premios que no piden anuncio no pasan del 12 % de la producción de un
/// día (PLAN-v2 E2a). Analítico: el día es el del jugador del simulador
/// (`PacingSimulator.HumanModel`) y la producción se mide en minutos del pasivo
/// base, la misma unidad en la que se pagan los premios. Cuenta lo que se
/// repite cada día (el diario y el asado); logros, carreras y cofres son de una vez.
@Suite("Presupuesto de premios sin anuncios")
struct RewardBudgetTests {
    static let budget = 0.12
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    /// Las sesiones enteras más el offline entre sesiones, con la eficiencia
    /// base y el tope (556 min con el modelo y el `economy.json` de hoy).
    private func productionMinutesPerDay(_ human: PacingSimulator.HumanModel) -> Double {
        let starts = human.sessionStartOffsets.sorted()
        let cap = content.economy.offlineCapHours * 3600
        var offline = 0.0
        for (index, start) in starts.enumerated() {
            let next = index + 1 < starts.count ? starts[index + 1] : human.daySeconds + starts[0]
            offline += min(max(0, next - (start + human.sessionSeconds)), cap)
        }
        let active = Double(starts.count) * human.sessionSeconds
        return (active + offline * content.economy.offlineEfficiencyBase) / 60
    }

    /// Cuántas veces por día se cobra el asado: al empezar cada sesión, si ya pasó el cooldown.
    private func asadoClaimsPerDay(_ human: PacingSimulator.HumanModel, cooldown: Double) -> Double {
        let starts = human.sessionStartOffsets.sorted()
        var lastClaim = -Double.infinity
        var claims = 0
        for day in 0..<7 {
            for start in starts {
                let now = Double(day) * human.daySeconds + start
                if now - lastClaim >= cooldown {
                    claims += 1
                    lastClaim = now
                }
            }
        }
        return Double(claims) / 7
    }

    private func dailyMinutes() throws -> [Double] {
        let days = content.dailyRewards.days.sorted { $0.day < $1.day }
        let minutes = days.compactMap(\.minutes)
        try #require(minutes.count == days.count, "cada día declara sus minutos")
        return minutes
    }

    private func asado() throws -> BoostsConfig.Boost {
        try #require(content.boosts.boosts.first { $0.effectType == .periodicPayout })
    }

    @Test("los minutos del dueño: el diario 5/8/12/18/25/40 y 15, el asado 10")
    func theOwnersTable() throws {
        #expect(try dailyMinutes() == [5, 8, 12, 18, 25, 40, 15])
        #expect(try asado().magnitude == 10)
    }

    @Test("el diario promedio más el asado no pasan del 12 % de un día")
    func recurringRewardsFitTheBudget() throws {
        let human = PacingSimulator.HumanModel()
        let daily = try dailyMinutes()
        let asado = try asado()
        let asadoPerDay = asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        let perDay = daily.reduce(0, +) / Double(daily.count) + asadoPerDay
        let budget = Self.budget * productionMinutesPerDay(human)
        #expect(perDay <= budget, "\(perDay) min contra \(budget)")
    }

    @Test("ni el mejor día del ciclo pasa del 12 %")
    func theBestDayFitsTheBudget() throws {
        let human = PacingSimulator.HumanModel()
        let bestDay = try #require(try dailyMinutes().max())
        let asado = try asado()
        let best = bestDay + asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        #expect(best <= Self.budget * productionMinutesPerDay(human))
    }
}
```

`ContentSystemsTests`: las seis llamadas a `claimIfAvailable` suman
`tiers: content.tiers, floorTable: content.floorTable` después de `economy: economy`; las de
`BoostManager.activate`, `floorTable: content.floorTable` después de `tiers:`. El test del asado
pasa a:

```swift
    @Test("el asado paga sus minutos de producción")
    func asadoPaysItsMinutes() throws {
        var state = makeState(maxTier: 5)
        let expected = RewardScale.coinPayout(minutes: 10, state: state, tiers: content.tiers,
                                              floorTable: content.floorTable, config: content.economy)
        let chest = try BoostManager.activate(
            boostId: "asado", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy, now: 1000
        )
        #expect(abs((chest ?? 0) - expected) < 1e-6)
        #expect(abs(state.run.coins - expected) < 1e-6)
    }
```

y suma:

```swift
    @Test("el diario paga los minutos de su día")
    func dailyPaysItsMinutes() throws {
        var state = makeState(maxTier: 5)
        var rng = FixedRNG(seed: 1)
        let expected = RewardScale.coinPayout(minutes: 5, state: state, tiers: content.tiers,
                                              floorTable: content.floorTable, config: content.economy)
        let claim = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials, skins: content.skins,
            upgrades: content.upgradesConfig, viral: content.viral, boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: Date(), rng: &rng
        ))
        #expect(abs(claim.coinsGranted - expected) < 1e-6)
    }
```

`EffectContractTests`: en `applied(_:as:)`, el caso nuevo
`case .minutes: EffectFormatter.text(EffectAmount(unit: .minutes, value: ratio, isCapped: false))`;
en `boostEffects`, justo antes de `let payout = gameState.activateBoost(id: boost.id)`:

```swift
            // Lo que el asado tiene que pagar, cotizado ANTES de activarlo.
            let expectedPayout = RewardScale.coinPayout(
                minutes: boost.magnitude, state: try #require(gameState.player),
                tiers: content.tiers, floorTable: content.floorTable, config: content.economy
            )
```

y el caso del asado del `switch` pasa a:

```swift
            case .periodicPayout:
                #expect(abs((payout ?? 0) - expectedPayout) < 1e-6 * max(1, expectedPayout))
```

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/RewardBudgetTests -only-testing:FisuEvolutionTests/ContentSystemsTests -only-testing:FisuEvolutionTests/EffectContractTests`.
Expected: no compila (`minutes`, `floorTable:` en `activate`/`claimIfAvailable`, `.minutes`).

- [ ] **Step 3: La implementación**

`ContentConfigs.swift`, `DailyRewardsConfig.Day`: `let coinsFactor: Double?` pasa a

```swift
        /// Minutos de producción que paga el día (PLAN-v2 E2a). En el día del
        /// special es lo que paga si no hay special ni cofre que dar.
        let minutes: Double?
```

y el docstring de `BoostsConfig.EffectType.periodicPayout` dice que su `magnitude` son minutos de
producción.

`daily_rewards.json`: `"coinsFactor": …` → `"minutes": 5`, `8`, `12`, `18`, `25`, `40` (días 1–6)
y el día 7 suma `"minutes": 15`. `boosts.json`: el asado `"magnitude": 10.0`.

`ContentSystems.swift`, `BoostManager.activate` suma `floorTable: FloorTable` después de `tiers:`,
y `.periodicPayout`:

```swift
        case .periodicPayout:
            // Asado del Domingo: la picada son `magnitude` minutos de producción.
            let payout = RewardScale.coinPayout(
                minutes: boost.magnitude, state: state, tiers: tiers, floorTable: floorTable, config: economy.config
            )
```

`DailyRewardManager.claimIfAvailable` suma `tiers: TierRepository, floorTable: FloorTable` después
de `economy:`. Las dos ramas de plata pasan a

```swift
                coins = RewardScale.coinPayout(
                    minutes: day.minutes ?? 0, state: state, tiers: tiers, floorTable: floorTable, config: economy.config
                )
```

(la del día 7 deja de llevar el `6.0` escrito en código).

Llamadores: `GameState+Bonus.activateBoost` y `grantCareerReward` (rama `.freeBoost`, que T12
borra), `GameState+AdOffers.swift:122` y `GameState+Achievements.grantFreeBoost` suman
`floorTable: content.floorTable`; `claimDailyIfAvailable` suma
`tiers: content.tiers, floorTable: content.floorTable`.

`EffectDescriptor.swift`: `EffectUnit` suma

```swift
    /// Minutos de producción (PLAN-v2 E2a): "10 min".
    case minutes
```

`EffectFormatter.text`:
`case .minutes: return String(localized: "effect.minutes \(String(Int(amount.value.rounded())))")`;
y en `amount(forBoost:)` el `.periodicPayout` sale de la línea de los multiplicadores:

```swift
        case .incomeMultiplier, .tapMultiplier:
            return EffectAmount(unit: .multiplier, value: magnitude, isCapped: false)
        case .periodicPayout:
            return EffectAmount(unit: .minutes, value: magnitude, isCapped: false)
```

`GameState+Bonus.effectText(for:)`:
`case .periodicPayout: return String(localized: "bonus.effect.payout_minutes \(value)")`.

`GameState+Achievements.swift`: `coinReward` queda como envoltorio y `rewardTier` se borra (vive
en `RewardScale`); el docstring largo se resume en dos renglones que apuntan a `RewardScale`:

```swift
    /// Cuántas monedas paga un premio de `seconds` segundos de producción. La
    /// cuenta —producción base sin modificadores, con el piso— es la de
    /// `RewardScale` (PLAN-v2 E2a); acá sólo se le pasa el contenido.
    static func coinReward(seconds: Double, player: PlayerState, content: GameContent, economy: StandardEconomy) -> Double {
        RewardScale.coinPayout(
            seconds: seconds, state: player, tiers: content.tiers, floorTable: content.floorTable, config: economy.config
        )
    }
```

`Tools/v2/claves-pendientes/e2a-t11.json`:

```json
{
  "bonus.effect.payout_minutes %@": {"es": "Una picada: %@ de producción, cada vez", "en": "A platter: %@ of production, every time"},
  "effect.minutes %@": {"es": "%@ min", "en": "%@ min"}
}
```

`Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e2a-t11.json`; `bonus.effect.payout %@`
queda sin uso y se lista en el reporte para que la saque una tarea dueña del catálogo.
`/opt/homebrew/bin/xcodegen generate`.

- [ ] **Step 4: Verde y oráculo**

Receta R con las tres suites, `AchievementEngineTests` (su `coinRewardFloorNeverBeatsTheOldMold`
sigue verde: el tope sólo baja el piso), `DailyCalendarTests` y `BoostUnlockTests` → PASS.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Managers/ContentConfigs.swift \
  FisuEvolution/Managers/EffectDescriptor.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Game/State/GameState+AdOffers.swift FisuEvolution/Game/State/GameState+Achievements.swift \
  FisuEvolution/Resources/Config/daily_rewards.json FisuEvolution/Resources/Config/boosts.json \
  FisuEvolutionTests/RewardBudgetTests.swift FisuEvolutionTests/ContentSystemsTests.swift \
  FisuEvolutionTests/EffectContractTests.swift Tools/v2/claves-pendientes/e2a-t11.json
git diff --cached --stat
git commit -m "feat(premios): el diario, el asado y los logros pagan minutos de producción"
```

---

### Task 12: Las carreras — contrataciones gratis, Juicio ganado y Obra social

**Objetivo:** las decisiones del dueño para la carrera de la UBA: **Programador → contrataciones
gratis 120 s**, sin contar para la curva ni para el amortiguador; **Abogado → "Juicio ganado"**,
20 min de producción; **Médico → "Obra social"**: inmune a los eventos negativos 30 min, corta en
el acto el negativo en curso y paga 15 min. El Arquitecto sigue con su skin. Nacen los efectos
`.freeHire` y `.eventImmunity` (los "cimientos" de E4 los listan: ver "Lo que E2a le deja").

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (dos casos, `ModifierMath.activeUntil`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (los dos `hireQuote`: gratis con `.freeHire`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`CareersConfig`)
- Modify: `FisuEvolution/Resources/Config/careers.json`
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`validate(careers:…)` y su llamada `:88`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`previewText`, `careerRewards`, `grantCareerReward`, `cutNegativeEvent`, `eventIsApplicable`)
- Modify: `FisuEvolution/Game/State/ActiveBonus.swift` (`ActiveBonusBuilder.effectText`), `FisuEvolution/UI/HUD/ActiveBonusBar.swift:128-134`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/FreeHireTests.swift`
- Modify: `FisuEvolutionTests/CareerRewardTests.swift`, `EffectContractTests.swift`
- Create: `Tools/v2/claves-pendientes/e2a-t12.json`

**Interfaces:**
- Consumes: `GameState.coinPayout(minutes:player:content:)` (T7); `eventIsApplicable` (E1 T11); el `switch` de `ActiveBonusBuilder.effectText` con `.spendingFrozen` (E1 T13); `ActiveModifier.Effect: CaseIterable` y `EffectContractTests` (E1 T15).
- Produces: `ActiveModifier.Effect.freeHire`, `.eventImmunity`; `ModifierMath.activeUntil(_:in:now:) -> TimeInterval?`.
- Produces: `CareersConfig.RewardKind` = `freeHires`, `skin`, `lawsuit`, `healthPlan`; `CareersConfig.Career` = `id`, `rewardKind`, `skinId?`, `durationSeconds?`, `lumpMinutes?`.
- Produces: `GameState.cutNegativeEvent(player:) -> Bool` (`@discardableResult`).

- [ ] **Step 0: Pararse en la base**

`grep -n "case spendingFrozen" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (E1 T13)
y `grep -n "CaseIterable" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (E1 T15).
Y **`grep -n "freeHire\|eventImmunity" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift`**:
si E4 T1 ya los creó, esta tarea usa los suyos (salta la parte de `ActiveModifier`, `ActiveBonus` y
`ActiveBonusBar` y lo anota en el reporte).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/FreeHireTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Contrataciones gratis (el premio del Programador)")
struct FreeHireTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private let free = ActiveModifier(effect: .freeHire, magnitude: 1, expiresAt: 120, sourceKey: "career.junior_programmer")

    @Test("mientras dura, contratar es gratis; cuando vence, vuelve el precio")
    func freeWhileItLasts() throws {
        var state = fxState()
        state.run.activeModifiers = [free]
        let during = try #require(TowerActions.hireQuote(typeId: "a", state: state, config: fxConfig(),
                                                        floorTable: try fxFloorTable(), tiers: tiers, now: 60))
        let after = try #require(TowerActions.hireQuote(typeId: "a", state: state, config: fxConfig(),
                                                       floorTable: try fxFloorTable(), tiers: tiers, now: 121))
        #expect(during.cost == 0)
        #expect(after.cost > 0)
    }

    @Test("una contratación gratis no mueve la curva ni el amortiguador")
    func freeHiresDoNotCount() throws {
        let config = try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 4))
        var fx = try fxStateAndTower(units: ["a": 1], config: config)
        fx.state.run.raiseFrontier(to: 2, cushion: config.priceCushion)
        fx.state.run.activeModifiers = [free]
        let relief = fx.state.run.priceRelief
        let quote = try #require(TowerActions.hireQuote(typeId: "a", state: fx.state, config: config,
                                                       floorTable: fx.floorTable, tiers: tiers, now: 60))
        try TowerActions.hire(quote: quote, state: &fx.state, tower: &fx.tower, floorTable: fx.floorTable,
                              config: config, countsAsPurchase: quote.cost > 0)
        #expect(fx.state.run.hireCountsByType.isEmpty)
        #expect(fx.state.run.priceRelief == relief)
        #expect(fx.state.run.units["a"] == 2)
    }

    @Test("activeUntil dice hasta cuándo dura el más largo, y nil sin ninguno vivo")
    func activeUntil() {
        let longer = ActiveModifier(effect: .freeHire, magnitude: 1, expiresAt: 300, sourceKey: "x")
        #expect(ModifierMath.activeUntil(.freeHire, in: [free, longer], now: 0) == 300)
        #expect(ModifierMath.activeUntil(.freeHire, in: [free], now: 200) == nil)
        #expect(ModifierMath.activeUntil(.eventImmunity, in: [free], now: 0) == nil)
    }
}
```

`CareerRewardTests.swift`: los tests del programador, el médico y el abogado se reescriben
(los del arquitecto, la vista previa y el de la skin acreditada una vez quedan):

```swift
    @Test("el programador contrata gratis 2 minutos, sin mover la curva")
    func programmerHiresForFree() async throws {
        let gameState = await makeGameState()
        gameState.grantCareerReward(optionId: "junior_programmer", now: 0)
        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "career.junior_programmer" })
        #expect(modifier.effect == .freeHire)
        #expect(modifier.expiresAt == 120)
        #expect(gameState.careerRewards["junior_programmer"]?.kind == .freeHires)
    }

    @Test("el abogado gana el juicio: 20 minutos de producción")
    func lawyerWinsTheLawsuit() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let before = try #require(gameState.player)
        let expected = GameState.coinPayout(minutes: 20, player: before, content: content)
        gameState.grantCareerReward(optionId: "junior_lawyer", now: 0)
        #expect(gameState.player?.run.coins == before.run.coins + expected)
    }

    @Test("el médico tiene obra social: inmune 30 min, corta el evento malo y cobra 15 min")
    func doctorGetsAHealthPlan() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let devaluacion = try #require(content.events.events.first { $0.id == "devaluacion" })
        let farFuture = Date().timeIntervalSince1970 + 3600
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.5, expiresAt: farFuture, sourceKey: "event.devaluacion")
        ]
        gameState.activeEvent = EventManager.ActiveEvent(
            id: "devaluacion", flavorTextKey: devaluacion.flavorTextKey, isBuff: false, endsAt: farFuture
        )
        let before = try #require(gameState.player)
        let expected = GameState.coinPayout(minutes: 15, player: before, content: content)
        let now = Date().timeIntervalSince1970

        gameState.grantCareerReward(optionId: "junior_doctor", now: now)

        let after = try #require(gameState.player)
        #expect(after.run.activeModifiers.contains { $0.effect == .eventImmunity && $0.expiresAt == now + 1800 })
        #expect(!after.run.activeModifiers.contains { $0.sourceKey == "event.devaluacion" })
        #expect(gameState.activeEvent == nil)
        #expect(after.run.coins == before.run.coins + expected)
        #expect(!gameState.eventIsApplicable(devaluacion))
    }
```

(Si `ActiveEvent` sumó campos en E1 T13 —`escapableByVideo`—, el `init` del test los pasa con su
valor neutro.) El que hoy pinea "el premio del abogado se lee como descuento" pasa a:

```swift
    @Test("la vista previa del abogado dice la plata que cobra")
    func lawyerPreviewSaysTheCoins() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let player = try #require(gameState.player)
        let preview = try #require(gameState.careerRewards["junior_lawyer"]?.previewText)
        #expect(preview.contains(CoinFormatter.string(from: GameState.coinPayout(minutes: 20, player: player, content: content))))
        #expect(!preview.contains("career.reward"), "quedó la clave cruda")
    }
```

`EffectContractTests`:
- en `modifierEffects`, dos casos más del `switch`:

  ```swift
            case .freeHire:
                #expect(chip == String(localized: "bonus.chip.free_hire"))
                #expect(try quote(boosted).cost == 0)
                #expect(passive(boosted) == passive(plain))
            case .eventImmunity:
                #expect(chip == String(localized: "bonus.chip.event_immunity"))
                #expect(passive(boosted) == passive(plain))
                #expect(ModifierMath.activeUntil(.eventImmunity, in: boosted.run.activeModifiers, now: 0) == 100)
  ```

- en `careerPreviewEqualsCredited`, el `switch kind` queda:

  ```swift
            case .freeHires:
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "career.\(career.id)" })
                #expect(modifier.effect == .freeHire)
                #expect(preview.contains(String(Int((career.durationSeconds ?? 0) / 60))))
            case .skin:
                #expect(gameState.player?.meta.milestoneSkins.contains(career.skinId ?? "") == true)
            case .lawsuit, .healthPlan:
                let credited = try #require(gameState.player?.run.coins) - coinsBefore
                #expect(preview.contains(CoinFormatter.string(from: credited)))
  ```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter FreeHireTests` y Receta R con
`CareerRewardTests` y `EffectContractTests`. Expected: no compila (`.freeHire`, `.eventImmunity`,
`activeUntil`, los `RewardKind` nuevos).

- [ ] **Step 3: La implementación**

`ActiveModifier.swift`, en `Effect`:

```swift
        /// Contratar es gratis mientras dura (el Programador). No cuenta para la
        /// curva: la compra cuesta 0 y la app pasa `countsAsPurchase: false`.
        case freeHire
        /// Inmune a los eventos negativos mientras dura (la Obra social del Médico).
        case eventImmunity
```

y en `ModifierMath`:

```swift
    /// Hasta cuándo dura el efecto vivo más largo de este tipo, o `nil` si no hay.
    public static func activeUntil(_ effect: ActiveModifier.Effect, in modifiers: [ActiveModifier], now: TimeInterval) -> TimeInterval? {
        modifiers.filter { $0.effect == effect && $0.isActive(at: now) }.map(\.expiresAt).max()
    }
```

`TowerActions.swift`, en los dos `hireQuote`, el `cost`:

```swift
        let free = ModifierMath.activeUntil(.freeHire, in: state.run.activeModifiers, now: now) != nil
        let cost = free ? 0 : base * costMultiplier * modifier * discount
```

`ContentConfigs.swift`, `CareersConfig`:

```swift
    /// Los cuatro tipos son distintos ENTRE SÍ a propósito: cuatro variantes del
    /// mismo premio vuelven a ser la elección decorativa que esto arregla.
    enum RewardKind: String, Codable, Sendable, CaseIterable {
        /// El Programador: contratar gratis un rato, sin mover la curva.
        case freeHires
        /// El Arquitecto: una skin desbloqueada de una.
        case skin
        /// El Abogado, "Juicio ganado": una suma en minutos de producción.
        case lawsuit
        /// El Médico, "Obra social": inmunidad a los eventos negativos, corta el
        /// que está corriendo y paga unos minutos de producción.
        case healthPlan
    }

    struct Career: Codable, Sendable, Equatable, Identifiable {
        /// typeId de la opción (una de `tiers.json → junior.choiceOptions`).
        let id: String
        let rewardKind: RewardKind
        /// `skin`: qué skin se desbloquea.
        let skinId: String?
        /// `freeHires` y `healthPlan`: cuánto dura el efecto.
        let durationSeconds: Double?
        /// `lawsuit` y `healthPlan`: minutos de producción que paga al elegir.
        let lumpMinutes: Double?
    }
```

`careers.json`:

```json
{
  "schemaVersion": 2,
  "careers": [
    { "id": "junior_programmer", "rewardKind": "freeHires", "durationSeconds": 120 },
    { "id": "junior_architect", "rewardKind": "skin", "skinId": "obra" },
    { "id": "junior_doctor", "rewardKind": "healthPlan", "durationSeconds": 1800, "lumpMinutes": 15 },
    { "id": "junior_lawyer", "rewardKind": "lawsuit", "lumpMinutes": 20 }
  ]
}
```

`GameContentLoader.validate(careers:tiers:skins:)` (sale el parámetro `boosts`, que ya no se usa;
la llamada de `:88` también), el `switch`:

```swift
            case .freeHires:
                guard let duration = career.durationSeconds, duration > 0 else {
                    throw fail("\(career.id): freeHires necesita durationSeconds > 0")
                }
            case .skin:
                guard let skinId = career.skinId, skins.skins.contains(where: { $0.id == skinId }) else {
                    throw fail("\(career.id): skin apunta a una skin inexistente")
                }
            case .lawsuit:
                guard let minutes = career.lumpMinutes, minutes > 0 else {
                    throw fail("\(career.id): lawsuit necesita lumpMinutes > 0")
                }
            case .healthPlan:
                guard let duration = career.durationSeconds, duration > 0,
                      let minutes = career.lumpMinutes, minutes > 0
                else { throw fail("\(career.id): healthPlan necesita durationSeconds y lumpMinutes > 0") }
```

`GameState+Bonus.swift`: `careerRewards` deja de pedir `economy`; `previewText(for:content:player:)`
(sin `economy`):

```swift
        switch career.rewardKind {
        case .freeHires:
            guard let duration = career.durationSeconds else { return nil }
            return String(localized: "career.reward.free_hires \(durationText(duration))")
        case .skin:
            guard let skin = content.skins.skins.first(where: { $0.id == career.skinId }) else { return nil }
            return String(localized: "career.reward.skin \(localized(skin.displayNameKey ?? skin.id))")
        case .lawsuit:
            guard let minutes = career.lumpMinutes else { return nil }
            let coins = CoinFormatter.string(from: coinPayout(minutes: minutes, player: player, content: content))
            return String(localized: "career.reward.lawsuit \(coins)")
        case .healthPlan:
            guard let duration = career.durationSeconds, let minutes = career.lumpMinutes else { return nil }
            let coins = CoinFormatter.string(from: coinPayout(minutes: minutes, player: player, content: content))
            return String(localized: "career.reward.health_plan \(durationText(duration)) \(coins)")
        }
```

`grantCareerReward` (su `guard` deja de pedir `economy`):

```swift
        switch career.rewardKind {
        case .freeHires:
            player.run.activeModifiers.append(ActiveModifier(
                effect: .freeHire, magnitude: 1,
                expiresAt: now + (career.durationSeconds ?? 0), sourceKey: "career.\(optionId)"
            ))
        case .skin:
            guard let skinId = career.skinId, !player.meta.milestoneSkins.contains(skinId) else { break }
            player.meta.milestoneSkins = (player.meta.milestoneSkins + [skinId]).sorted()
            skinSelectionVersion &+= 1
        case .lawsuit:
            let payout = Self.coinPayout(minutes: career.lumpMinutes ?? 0, player: player, content: content)
            player.run.coins += payout
            player.meta.lifetimeEarnings += payout
            audio?.play(.coin)
        case .healthPlan:
            let payout = Self.coinPayout(minutes: career.lumpMinutes ?? 0, player: player, content: content)
            player.run.activeModifiers.append(ActiveModifier(
                effect: .eventImmunity, magnitude: 1,
                expiresAt: now + (career.durationSeconds ?? 0), sourceKey: "career.\(optionId)"
            ))
            cutNegativeEvent(player: &player)
            player.run.coins += payout
            player.meta.lifetimeEarnings += payout
            audio?.play(.coin)
        }
```

y, junto a `escapeActiveEvent` (E1 T13):

```swift
    /// Corta en el acto el evento malo que esté corriendo (la Obra social). La
    /// misma limpieza que la salida por video del Corralito, para cualquier
    /// evento que no sea un buff.
    @discardableResult
    func cutNegativeEvent(player: inout PlayerState) -> Bool {
        guard let event = activeEvent, !event.isBuff else { return false }
        player.run.activeModifiers.removeAll { $0.sourceKey == "event.\(event.id)" }
        activeEvent = nil
        return true
    }
```

`eventIsApplicable` (E1 T11), al principio, después de su `guard`:

```swift
        // La Obra social: un evento negativo no cae mientras dure la inmunidad.
        if !event.isBuff,
           ModifierMath.activeUntil(.eventImmunity, in: player.run.activeModifiers, now: Date().timeIntervalSince1970) != nil {
            return false
        }
```

`ActiveBonus.swift`, en el `switch` de `ActiveBonusBuilder.effectText(for:)` que dejó E1 T13:

```swift
        case .freeHire: return String(localized: "bonus.chip.free_hire")
        case .eventImmunity: return String(localized: "bonus.chip.event_immunity")
```

`ActiveBonusBar.tint`: `case .freeHire: Color("PaletteYellow")` y
`case .eventImmunity: Color("PaletteBrown")`.

`Tools/v2/claves-pendientes/e2a-t12.json`:

```json
{
  "career.reward.free_hires %@": {"es": "Contratás gratis durante %@, sin que suban los precios", "en": "Free hires for %@, and prices don't go up"},
  "career.reward.lawsuit %@": {"es": "Juicio ganado: %@ de plata", "en": "Lawsuit won: %@ coins"},
  "career.reward.health_plan %@ %@": {"es": "Obra social: %1$@ sin eventos malos y %2$@ de plata", "en": "Health plan: %1$@ with no bad events and %2$@ coins"},
  "bonus.chip.free_hire": {"es": "Gratis", "en": "Free"},
  "bonus.chip.event_immunity": {"es": "Inmune", "en": "Immune"}
}
```

`Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e2a-t12.json`. Quedan sin uso
`career.reward.welcome %@`, `career.reward.boost %@ %@` y `career.reward.modifier %@ %@`: van al
reporte.

- [ ] **Step 4: Verde y oráculo**

`swift test --package-path Packages/EconomyKit` → PASS. Receta R con `CareerRewardTests`,
`EffectContractTests`, `EventSchedulingTests`, `CorralitoTests`, `ActiveBonusTests` y
`LocalizationCompletenessTests` → PASS. `Tools/v2/oraculo.sh completo` → `VERDE`
(`CareerChoiceUITests` incluida).

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift \
  FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Config/careers.json \
  FisuEvolution/Managers/GameContentLoader.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Game/State/ActiveBonus.swift FisuEvolution/UI/HUD/ActiveBonusBar.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/FreeHireTests.swift FisuEvolutionTests/CareerRewardTests.swift \
  FisuEvolutionTests/EffectContractTests.swift Tools/v2/claves-pendientes/e2a-t12.json
git diff --cached --stat
git commit -m "feat(carreras): contrataciones gratis, Juicio ganado y Obra social"
```

---

### Task 13: Pisos en marcha en el mapa, con su contrato

**Objetivo:** "Pisos en marcha 4/10 · +20 %" en la cabecera del mapa del ascensor (sólo con la
perilla puesta), y el contrato: el + que se lee es el que cobra la torre. Si la botonera de E3a
ya existe, su luz verde enciende exactamente los pisos que `StaffedFloors` cuenta.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Tower.swift` (`StaffedSummary`, `staffedSummary`)
- Modify: `FisuEvolution/UI/Popups/FloorMapView.swift` (`header` `:109-130`)
- Modify: `FisuEvolutionTests/EffectContractTests.swift`
- Create: `Tools/v2/claves-pendientes/e2a-t13.json`

**Interfaces:**
- Consumes: `StaffedFloors` (T4), `replaceEconomy` (T9), `EffectContractTests` (E1 T15), `ElevatorPanelModel(map:)` (E3a T8, opcional).
- Produces: `struct StaffedSummary: Equatable { staffed: Int; total: Int; bonus: Double }` y `GameState.staffedSummary: StaffedSummary?` (computada; `nil` con la perilla en 0).

- [ ] **Step 0: Pararse en la base**

`grep -n "struct EffectContractTests" FisuEvolutionTests/EffectContractTests.swift` (E1 T15) y
`grep -rn "struct ElevatorPanelModel" FisuEvolution`: si E3a T8 no está, el segundo test de abajo
no se escribe y se anota en el reporte para que lo sume quien integre E3a T8.

- [ ] **Step 1: Los tests, en rojo**

En `EffectContractTests`:

```swift
    @Test("pisos en marcha: lo que dice el mapa es lo que cobra la torre")
    func staffedFloorsShowWhatTheyPay() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let plainEconomy = content.economy
        gameState.replaceEconomy(try content.economy.tuned(EconomyKnobs(staffedFloorBonus: 0.05)))
        gameState.player?.run.units = [base.id: content.floorTable[0].capacity]
        gameState.player?.run.passiveUnlocked[base.id] = true
        gameState.reconcileTower()
        let summary = try #require(gameState.staffedSummary)
        #expect(summary.staffed == 1 && summary.total == content.floorTable.count)
        #expect(gameState.staffedSummaryText(summary).contains("1/\(content.floorTable.count)"),
                "sin la clave en el catálogo sale cruda y no dice 1/10")
        let player = try #require(gameState.player)
        let tuned = try #require(gameState.content).economy
        let staffed = IncomeTicker.basePassivePerSecond(state: player, tiers: content.tiers, floorTable: content.floorTable, config: tuned)
        let plain = IncomeTicker.basePassivePerSecond(state: player, tiers: content.tiers, floorTable: content.floorTable, config: plainEconomy)
        #expect(abs(staffed / plain - (1 + summary.bonus)) < 1e-9)
        #expect(abs(summary.bonus - 0.05) < 1e-12)
    }

    @Test("la luz verde de la botonera es la de los pisos en marcha")
    func theElevatorLightIsTheStaffedRule() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.player?.run.units = [base.id: content.floorTable[0].capacity]
        gameState.reconcileTower()
        let player = try #require(gameState.player)
        let lit = Set(ElevatorPanelModel(map: gameState.floorMap).floors.filter(\.isStaffed).map(\.id))
        let staffed = Set(StaffedFloors.ordinals(state: player, tiers: content.tiers, floorTable: content.floorTable)
            .map { content.floorTable[$0].id })
        #expect(lit == staffed)
    }
```

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/EffectContractTests`.
Expected: no compila (`staffedSummary`).

- [ ] **Step 3: La implementación**

`GameState+Tower.swift`, después de `FloorMapEntry`:

```swift
/// "Pisos en marcha 4/10 · +20 %" (PLAN-v2 §2, crítica de Marco).
struct StaffedSummary: Equatable {
    let staffed: Int
    let total: Int
    /// 0,20 = +20 % a los ingresos globales.
    let bonus: Double
}
```

y en la extensión:

```swift
    /// Cuántos pisos están en marcha y cuánto suman. Computada como `floorMap`:
    /// la lee una hoja modal. `nil` con la perilla en 0 (la v1): no se anuncia
    /// un bono que no existe.
    var staffedSummary: StaffedSummary? {
        guard let content, let player, content.economy.staffedBonusPerFloor > 0 else { return nil }
        let staffed = StaffedFloors.ordinals(state: player, tiers: content.tiers, floorTable: content.floorTable).count
        let multiplier = StaffedFloors.multiplier(state: player, tiers: content.tiers,
                                                  floorTable: content.floorTable, config: content.economy)
        return StaffedSummary(staffed: staffed, total: content.floorTable.count, bonus: multiplier - 1)
    }

    /// ⚠️ Los números van como `String` (trampa 5).
    func staffedSummaryText(_ summary: StaffedSummary) -> String {
        String(localized: "map.staffed \(String(summary.staffed)) \(String(summary.total)) \(summary.bonus.formatted(.percent.precision(.fractionLength(0))))")
    }
```

`FloorMapView.swift`, en `header`, después del `Text("elevator.subtitle")`:

```swift
            if let summary = gameState.staffedSummary {
                StateBadge(
                    text: gameState.staffedSummaryText(summary),
                    systemImage: "bolt.fill",
                    textAlignment: .center,
                    muted: summary.staffed == 0
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("map.staffed")
            }
```

`Tools/v2/claves-pendientes/e2a-t13.json`:

```json
{
  "map.staffed %@ %@ %@": {"es": "Pisos en marcha %1$@/%2$@ · +%3$@", "en": "Fully staffed floors %1$@/%2$@ · +%3$@"}
}
```

`Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e2a-t13.json`.

- [ ] **Step 4: Verde y oráculo**

Receta R con `EffectContractTests`, `FloorMapTests` y `LocalizationCompletenessTests` → PASS.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Tower.swift FisuEvolution/UI/Popups/FloorMapView.swift \
  FisuEvolutionTests/EffectContractTests.swift Tools/v2/claves-pendientes/e2a-t13.json
git diff --cached --stat
git commit -m "feat(torre): pisos en marcha en el mapa, y el contrato de su bono"
```

---

### Task 14: El panel de debug — variantes de precio, perillas y "Fusionar todo"

**Objetivo:** el selector que pidió el dueño para probar los precios ("si no convence, vuelve a
v1"), con el resto de las perillas de E2a y un botón de "Fusionar todo" sobre el piso visible.
Las perillas sobreviven a cerrar la app (`UserDefaults`) y se aplican al arrancar desde
`applyLaunchArgumentDefaults`, sin tocar `GameState.swift`. Nace `enqueueMergeAll`, la entrada que
E6 (por ORO) y E7b (por video) llaman con su propio origen.

⚠️ Los tests **no** escriben `UserDefaults.standard`: Swift Testing corre suites en paralelo y el
`bootstrap` de cualquier otra suite leería las perillas a mitad de camino. Las funciones reciben
el `UserDefaults` y los tests usan un dominio descartable.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`applyLaunchArgumentDefaults`, las perillas, `debugMergeAllOnVisibleFloor`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (`enqueueMergeAll`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (la sección "Economía 2.0")
- Create: `FisuEvolutionTests/DebugEconomyKnobsTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `EconomyKnobs`, `tuned` (T2–T5); `replaceEconomy` (T9); `planMergeAll(…config:origin:)` (T9); `enqueueBoardChange`, `pendingBoardChanges`, `inFlightBoardChange` (E1 T9).
- Produces: `GameState.enqueueMergeAll(onFloor:origin:) -> Int` (`@discardableResult`).
- Produces (DEBUG): `GameState.economyKnobsDefaultsKey`, `static GameState.storedEconomyKnobs(in:) -> EconomyKnobs`, `debugApplyEconomyKnobs(_:defaults:)`, `debugMergeAllOnVisibleFloor() -> Int`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/DebugEconomyKnobsTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El panel de debug: las perillas de E2a y Fusionar todo")
@MainActor
struct DebugEconomyKnobsTests {
    /// Un dominio de `UserDefaults` propio: el `.standard` lo leen los
    /// `bootstrap` de las suites que corren al lado.
    private func scratch() throws -> (defaults: UserDefaults, name: String) {
        let name = "e2a-knobs-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test("las perillas cambian la economía en vivo y se guardan para el próximo arranque")
    func knobsApplyLiveAndPersist() async throws {
        let (defaults, name) = try scratch()
        defer { defaults.removePersistentDomain(forName: name) }
        let knobs = EconomyKnobs(defaultCostGrowth: 1.12, mergeRefundCounts: 1, priceReliefPurchases: 24)
        let gameState = await makeGameState()
        gameState.debugApplyEconomyKnobs(knobs, defaults: defaults)
        #expect(gameState.content?.economy.hire.priceReliefPurchases == 24)
        #expect(gameState.economy?.config.hire.mergeRefundCounts == 1)
        #expect(GameState.storedEconomyKnobs(in: defaults) == knobs)

        // Lo que hace `applyLaunchArgumentDefaults` al arrancar.
        let reopened = await makeGameState()
        reopened.debugApplyEconomyKnobs(GameState.storedEconomyKnobs(in: defaults), defaults: defaults)
        #expect(reopened.content?.economy.hire.defaultCostGrowth == 1.12)
    }

    @Test("volver a v1 deja el economy.json del bundle")
    func backToV1IsTheBundle() async throws {
        let (defaults, name) = try scratch()
        defer { defaults.removePersistentDomain(forName: name) }
        let gameState = await makeGameState()
        let bundled = try GameContentLoader.load(from: .main).economy
        gameState.debugApplyEconomyKnobs(EconomyKnobs(priceReliefPurchases: 24), defaults: defaults)
        gameState.debugApplyEconomyKnobs(EconomyKnobs(), defaults: defaults)
        #expect(gameState.content?.economy == bundled)
    }

    @Test("Fusionar todo encola todos los pares del piso visible, en cadena")
    func mergeAllQueuesEveryPair() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        #expect(gameState.debugMergeAllOnVisibleFloor() == 3)
        let queued = gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1)
        #expect(queued == 3)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/DebugEconomyKnobsTests`.
Expected: no compila (`economyKnobsDefaultsKey`, `debugApplyEconomyKnobs`, `debugMergeAllOnVisibleFloor`).

- [ ] **Step 3: La implementación**

`GameState+BoardChanges.swift`:

```swift
    /// "Fusionar todo" (PLAN-v2 §2): encola todos los pares del piso como
    /// cambios del tablero, en el orden en que se funden; cada uno se juega en
    /// su turno y un tier nuevo se revela como siempre. Devuelve cuántos. E6
    /// (por ORO) y E7b (por video) lo llaman con su propio origen.
    @discardableResult
    func enqueueMergeAll(onFloor ordinal: Int, origin: BoardChange.Origin) -> Int {
        guard let content, let player, let tower else { return 0 }
        let plan = BoardChangePlanner.planMergeAll(
            floorOrdinal: ordinal, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy, origin: origin
        )
        plan.forEach(enqueueBoardChange)
        return plan.count
    }
```

`GameState+Debug.swift`, dentro del `#if DEBUG`:

```swift
    /// Las perillas de E2a que el dueño eligió en el panel. Viven en
    /// `UserDefaults` y no en el save: son de este dispositivo, no de la partida.
    static let economyKnobsDefaultsKey = "debug.economyKnobs"

    static func storedEconomyKnobs(in defaults: UserDefaults) -> EconomyKnobs {
        defaults.data(forKey: economyKnobsDefaultsKey)
            .flatMap { try? JSONDecoder().decode(EconomyKnobs.self, from: $0) } ?? EconomyKnobs()
    }

    /// Aplica las perillas sobre el `economy.json` del BUNDLE (no sobre el que
    /// está puesto: si no, apagar una no volvería a la v1) y las guarda.
    func debugApplyEconomyKnobs(_ knobs: EconomyKnobs, defaults: UserDefaults) {
        guard let bundled = try? GameContentLoader.load(from: .main).economy,
              let tuned = try? bundled.tuned(knobs)
        else { return }
        defaults.set(try? JSONEncoder().encode(knobs), forKey: Self.economyKnobsDefaultsKey)
        replaceEconomy(tuned)
    }

    @discardableResult
    func debugMergeAllOnVisibleFloor() -> Int {
        enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .debug)
    }
```

y en `applyLaunchArgumentDefaults` (su `defaults` local ya es `UserDefaults.standard`): dentro de
`if forceNewGame { … }`, `defaults.removeObject(forKey: Self.economyKnobsDefaultsKey)`; y al final
de la función:

```swift
        // Las perillas que el dueño dejó puestas en el panel (PLAN-v2 E2a).
        let knobs = Self.storedEconomyKnobs(in: defaults)
        if knobs != EconomyKnobs() {
            debugApplyEconomyKnobs(knobs, defaults: defaults)
        }
```

`DebugPanelView.swift`: un `@State private var knobs = EconomyKnobs()`, el `.onAppear` suma
`knobs = GameState.storedEconomyKnobs(in: .standard)`, y una sección después de "Economía":

```swift
                // El selector del dueño (PLAN-v2 §2, "Precios"): la curva y el
                // reintegro se prueban en pares; "v1" es lo que shippea hoy.
                Section("Economía 2.0 (E2a)") {
                    Picker("Curva · reintegro", selection: curveBinding) {
                        ForEach(Self.curves.indices, id: \.self) { index in
                            Text(Self.curves[index].name).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("debug.e2a.curve")
                    Toggle("Amortiguador (K = 24)", isOn: knobToggle(\.priceReliefPurchases, on: 24))
                        .accessibilityIdentifier("debug.e2a.cushion")
                    Toggle("Pisos en marcha (+5 %)", isOn: knobToggle(\.staffedFloorBonus, on: 0.05))
                        .accessibilityIdentifier("debug.e2a.staffed")
                    Toggle("Piso móvil", isOn: knobToggle(\.requiresLastRunWall, on: true))
                        .accessibilityIdentifier("debug.e2a.wall")
                    Button("Fusionar todo (piso visible)") {
                        gameState.debugMergeAllOnVisibleFloor()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.e2a.mergeAll")
                }
```

con, en la vista:

```swift
    /// Los pares (g, r) del plan: v1, y tres que dejan ~6 % por compra al que
    /// fusiona y cobran más al que acumula. El callejón conserva su 1,03.
    private static let curves: [(name: String, growth: Double?, refund: Double?)] = [
        ("v1", nil, nil),
        ("1,08 · 0,5", 1.08, 0.5),
        ("1,12 · 1", 1.12, 1),
        ("1,12 · 2", 1.12, 2),
    ]

    private var curveBinding: Binding<Int> {
        Binding(
            get: {
                Self.curves.firstIndex { $0.growth == knobs.defaultCostGrowth && $0.refund == knobs.mergeRefundCounts } ?? 0
            },
            set: { index in
                knobs.defaultCostGrowth = Self.curves[index].growth
                knobs.mergeRefundCounts = Self.curves[index].refund
                gameState.debugApplyEconomyKnobs(knobs, defaults: .standard)
            }
        )
    }

    private func knobToggle<Value: Equatable>(_ path: WritableKeyPath<EconomyKnobs, Value?>, on value: Value) -> Binding<Bool> {
        Binding(
            get: { knobs[keyPath: path] == value },
            set: { isOn in
                knobs[keyPath: path] = isOn ? value : nil
                gameState.debugApplyEconomyKnobs(knobs, defaults: .standard)
            }
        )
    }
```

(`DebugPanelView` suma `import EconomyKit`.) `/opt/homebrew/bin/xcodegen generate`.

- [ ] **Step 4: Verde y oráculo**

Receta R con `DebugEconomyKnobsTests` → PASS. `Tools/v2/oraculo.sh completo` → `VERDE`. A mano en
el simulador: abrir el panel, poner "1,12 · 1" + amortiguador, contratar y fusionar en el callejón
→ FisuJobs dice "+15 % por compra · fusionar lo abarata 11 %" (o los que den) y el precio no salta
al fusionar; cerrar y abrir la app → las perillas siguen; "v1" → todo como antes.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Debug.swift FisuEvolution/Game/State/GameState+BoardChanges.swift \
  FisuEvolution/UI/DebugPanelView.swift FisuEvolutionTests/DebugEconomyKnobsTests.swift
git diff --cached --stat
git commit -m "feat(debug): las variantes de precio y las perillas de E2a, y Fusionar todo"
```

---

### Task 15: Cierre de la épica

**Objetivo:** la verificación de punta a punta de E2a, las mediciones que E2b necesita para
arrancar, y la documentación. La hace el controlador.

- [ ] **Step 1: Oráculo completo**

Run: `Tools/v2/oraculo.sh completo`.
Expected: `VERDE`, con las suites de E2a en la salida (`RewardScaleTests`, `MergeRefundTests`,
`EconomyKnobsTests`, `PriceCushionTests`, `HireStepTests`, `StaffedFloorsTests`, `MovingWallTests`,
`MergeAllPlannerTests`, `FreeHireTests`, `PacingSimulatorKnobTests` en EconomyKit;
`PriceCushionContentTests`, `MergeEconomyWiringTests`, `RewardBudgetTests`,
`DebugEconomyKnobsTests` en unit) y **`pacing-sim: Dios en 30,73 h · 13 reencarnaciones`** (o la
línea de base vigente). `rojos-declarados.txt` no cambió por E2a.

- [ ] **Step 2: Las perillas medidas, una por una (para E2b)**

Con un `economy.json` temporal en `build/e2a-knobs/` por perilla (un script de Python por
llamada, que copia `FisuEvolution/Resources/Data/economy.json` y le suma la clave), y **siempre
`--upgrades`** (trampa 39):

```bash
swift run --package-path Tools/pacing-sim pacing-sim --economy build/e2a-knobs/<variante>.json \
  --tiers FisuEvolution/Resources/Data/tiers.json --upgrades FisuEvolution/Resources/Config/upgrades.json
```

Variantes: la base (primero, y tiene que dar la línea de base: trampa 40), `defaultCostGrowth`
1,12 + `mergeRefundCounts` 1, `priceReliefPurchases` 24, `staffedFloorBonus` 0,05,
`oro.requiresLastRunWall` true y `floors[].capacity` 15. La tabla (Dios activo, reencarnaciones,
1ª reencarnación, las 7 al tope) va a la sesión: es el punto de partida de E2b, no un veredicto.

- [ ] **Step 3: Los escenarios a mano**

En el simulador propio, app sin argumentos de test:

1. Carrera de la UBA con el fixture `--uitest-career`: Programador → chip "Gratis" y FisuJobs en
   0 durante 2 min, sin que suba el "+N %"; Abogado → la plata de la carta; Médico → chip
   "Inmune", el evento negativo en curso desaparece y no cae otro.
2. Panel de debug: las variantes de precio (Task 14, paso 4).
3. Piso móvil prendido + `lastRunMaxTier` alto (panel o fixture) → la cápsula dice "Meta: …" y la
   hoja no deja confirmar.
4. Pisos en marcha prendido + un piso lleno → la cabecera del mapa y, si está E3a T8, la luz
   verde.
5. "Fusionar todo" con un tier nuevo en el medio → se juega en cadena y el nuevo se revela.

- [ ] **Step 4: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e2a.md`: la tabla por tarea con su commit, la tabla de perillas
   medidas del paso 2 y el porqué de cada default de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: entrada "E2a — mecánicas de economía": las perillas (nombre, default v1, qué hace),
     `RewardScale` como única cuenta de premios, el amortiguador sobre `priceRelief`, y que el
     simulador usa las mismas funciones.
   - **§5**: lo que quedó decidido (los defaults de las dudas que el dueño no cambió; la tabla de
     minutos de los premios).
   - **§7**: las trampas nuevas — "una fusión de la carga o del panel de debug no amortigua: si un
     test sube la frontera con `raiseFrontier(to:)` y mira precios, mide la v1"; "con 10 lugares
     el bot nunca llena un piso: pisos en marcha no mueve el simulador hasta que E2b le dé la
     política"; "`EconomyConfig.tuned` pasa por el JSON: una clave que el decoder no lee no
     llega"; las que aparezcan.
   - **§9**: este plan y la sesión.
3. Journal AVO al día y `LOCK` liberado; `handoffs/HANDOFF-<fecha>-v2-e2a.md` con lo abierto.

- [ ] **Step 5: Commit de docs**

```bash
git add Docs/SESION-*-v2-e2a.md Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e2a): cierre de la épica E2a — mecánicas de economía"
```

---

## Lo que E2a le deja a otras épicas

- **E1 (las tareas que corren después de E2a T3/T4)**: dos firmas de EconomyKit cambian bajo sus
  pies, y su plan está escrito contra las viejas.
  - `StandardEconomy.applyTap` suma `tiers:` (T4): la fila `.tapMultiplier` de
    `EffectContractTests.modifierEffects` (E1 T15) pasa `tiers: content.tiers`.
  - `RunState.registerHire` suma `cushion:` (T3): ninguna tarea posterior de E1 la llama (la
    compra pasa por `TowerActions.hire`), pero si una lo hiciera, `cushion: config.priceCushion`.
- **E2b (calibración final y contrato)** recibe:
  1. **Las perillas, todas en v1 y leídas por el simulador**: `hire.mergeRefundCounts`,
     `hire.priceReliefPurchases`, `staffedFloorBonus`, `oro.requiresLastRunWall`, más las que ya
     existían (`hire.defaultCostGrowth`, `floors[].capacity`). E2b las declara en `economy.json`
     con sus valores (PLAN-v2: K = 24, (g, r) del barrido, 0,05, true, 15) y re-pinea lo que se
     mueva: las bandas de `PacingTests`, `GameContentValidationTests.swift:594` (capacidad) y la
     tabla de §6 del HANDOFF.
  2. **`EconomyKnobs` + `EconomyConfig.tuned(_:)`** para el CLI (`--merge-refund`,
     `--price-relief`, … mapean a un campo cada uno, sin escribir JSONs temporales).
  3. **El simulador ya pasa por las mismas puertas que el juego**: reintegro en sus fusiones,
     amortiguador en compra y frontera, bono de pisos en marcha en su ingreso, y
     `PrestigeCalculator.canReincarnate` en `wantsToReincarnate` (el piso móvil vale solo al
     prender la perilla). Lo que **no** tiene es la **política**: el bot no llena pisos a
     propósito ni usa "Fusionar todo" (perfil `.ads`); eso es de E2b.
  4. **`Report.maxTierPerRun`**: la serie del contrato 5 ("cada run llega más lejos").
  5. **La tabla de perillas medidas una por una** (T15, paso 2), con la base como primer punto.
  6. **`RewardBudgetTests`** como guarda de los premios (12 % de un día); "Juicio ganado ~20, a
     calibrar" está en `careers.json` (`lumpMinutes`).
  7. ⚠️ Las métricas de reporte `floorUnlockHireSeconds` y `peakHire` cotizan con
     `config.hireCost` pelado (v1, sin `D`): con el amortiguador prendido miden el precio de
     catálogo, no el cobrado. Si E2b las usa para calibrar el amortiguador, que pasen por
     `TowerActions.hireQuote`.
- **E3**: la botonera de E3a T8 y `StaffedFloors` dicen lo mismo (T13 lo pinea si T8 ya está).
  La capacidad 15 la pasa E2b, no E2a (duda 2): el layout de E3a ya soporta cualquier capacidad.
  El compartir de E3b T9 paga con `coinReward`, que desde T11 es `RewardScale`.
- **E4 (cimientos)**: `ActiveModifier.Effect.freeHire` y `.eventImmunity` **nacen en E2a T12**; la
  primera tarea de E4 no los vuelve a crear (si E4 T1 llega antes, T12 usa los suyos). La
  inmunidad se respeta en `eventIsApplicable`: los eventos v2 y sus escapes tienen que seguir
  pasando por ahí. El `RewardMath.coinPayout` de los cimientos **es** `RewardScale.coinPayout`
  (en la app, `GameState.coinPayout(minutes:player:content:)`): el `grant(_:multiplier:source:)`
  de `RewardSpec` lo usa para `coinsSeconds`.
- **E5**: El Colchón (monedas 20 min) y la Ruleta (30–60 min) pagan con
  `GameState.coinPayout(minutes:…)`.
- **E6**: "Fusionar todo" por ORO (20 ORO, 5/día) llama a `enqueueMergeAll(onFloor:origin:)` con
  un `Origin` propio (y su regla en `discardBoardChange`). El permanente de +3/+2 lugares tiene que
  cambiar la capacidad en **un solo lugar** que lean la torre, el reconciliador y `StaffedFloors`
  (hoy los tres leen `FloorDef.capacity`). Los packs de ORO no tocan `coinMinutes`.
- **E7b**: "Fusionar todo" por video (unidad `boost`) con su `Origin` y la compensación de E1 T14
  si el plan queda vacío; "carrera ×2" por video duplica `lumpMinutes`.
- **E8**: la cadena de "Fusionar todo" animada por código (PLAN-v2 §5): hoy cada par es un turno
  `.boardCelebration` completo, que alcanza para jugarlo pero no es la "cadena rápida".
- **E9**: lecciones de "+N % por compra", Fusionar todo, Pisos en marcha y piso móvil en
  `TutorialCoverageTests`.

## Para el dueño / dudas

Cosas que PLAN-v2 deja abiertas o que el código contradice. **Ninguna frena**: la ejecución sigue
con el default anotado hasta que el dueño diga otra cosa.

1. **El juego no cambia de precios hasta E2b.** PLAN-v2 pide las mecánicas "detrás de knobs con
   default v1", así que reintegro, amortiguador, pisos en marcha y piso móvil salen apagados.
   Default: así; el dueño los prueba desde el panel de debug (T14), que persiste entre sesiones.
2. **¿Quién pasa los pisos a 15 lugares?** El plan de E3a supone que E2a; PLAN-v2 lo pone "detrás
   de knob, calibrado en E2b". Cambiar el dato mueve el pacing medido y las bandas de
   `PacingTests`. Default: E2a no lo toca (prueba que una torre crece sin perder unidades y lo
   mide en T15); E2b lo pasa a 15 al arrancar su calibración. Si el dueño lo quiere ver antes, es
   una línea por piso en `economy.json` más el re-pin.
3. **Los premios en minutos sí cambian el juego en E2a.** No son perillas: son la tabla del dueño
   (diario, asado, cofres, packs, logros, carreras) y no tocan el simulador, así que la base se
   reproduce igual. Default: se aplican en T7, T11 y T12.
4. **Pisos en marcha multiplica en el pasivo base y en el toque, no en `ModifierMath`** (PLAN-v2
   dice "en `IncomeTicker` y `ModifierMath`"). No es un modificador temporal sino un estado del
   tablero; por eso también entra al offline y a los premios en minutos ("producción real").
   Default: así.
5. **La perilla se llama `staffedFloorBonus`, en la raíz de `economy.json`**, no
   `floors.staffedBonus`: `floors` es un array.
6. **La copia del piso móvil es "Meta para reencarnar: {personaje}"**, no "Llegá al {personaje}":
   tres personajes llevan artículo ("El Fisura") y la contracción "al" se rompe con ellos (la
   trampa de "Para tu El Trapito"). Con cuatro carreras posibles y ninguna elegida, dice el tier.
7. **"Fusionar todo" en E2a es la mecánica, no el botón.** E2a entrega el planificador, la entrada
   `enqueueMergeAll` y el botón de debug; el video es de E7b (unidad `boost`), el ORO de E6
   (20 ORO, 5/día) y la cadena animada de E8. La cadena funde del tier más bajo al más alto.
8. **Las carreras**: el Programador deja de dar el cofre de bienvenida, el Médico deja de dar el
   café y el Abogado deja el descuento; "Juicio ganado" paga **20 min** (PLAN-v2: "~20, a
   calibrar"). Default: así, ajustable en `careers.json`.
9. **El reintegro también baja la curva por piso** (`hireCounts`, la del botón de la torre), no
   sólo la por tipo: las dos viajan juntas desde siempre.
10. **El amortiguador tiene un solo `D` por run** y `ρ` sale del salto que llevó a la frontera
    actual (el save v6 sólo tiene `priceRelief`; guardar más estado sería v7). Apagado, `D` se
    ignora y vuelve a 1 en la próxima compra. Las subidas de frontera de la carga y del panel de
    debug no amortiguan.
11. **"Producción diaria" en `RewardBudgetTests`** = los minutos de pasivo base que cobra en un día
    el jugador del simulador: 80 min activos + el offline entre sesiones con la eficiencia base y
    el tope = 556 min, así que el 12 % son 66,7 min. Cuenta lo que se repite (diario promedio
    17,6 + asado 2 por día = 37,6; el mejor día, 60). Logros, carreras y cofres son de una vez.
12. **"+6 % por compra" vive en la tarjeta de FisuJobs**, junto a "fusionar lo abarata X %", no en
    el atajo del HUD (que ya muestra el precio). En el callejón dice +3 %: su curva es 1,03.
13. **Las variantes del panel**: v1 (1,06 · 0), (1,08 · 0,5), (1,12 · 1) y (1,12 · 2), más el
    amortiguador (K = 24) aparte. El callejón conserva su 1,03 en todas.
14. **El asado se lee "Una picada: 10 min de producción, cada vez"** y el día 7 sin special paga
    15 min (hoy es un `× 6` escrito en código). Las claves viejas que quedan sin uso
    (`bonus.effect.payout`, `career.reward.welcome/boost/modifier`) las saca una tarea dueña del
    catálogo.
