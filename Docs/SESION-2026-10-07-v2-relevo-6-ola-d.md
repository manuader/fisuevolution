# Sesión 2026-10-07 (relevo 6) — La ola D: el ciclo de vida, el Release que el `rapido` no veía, la app universal, el paquete puro y el tablero `tasks.md`

Continúa `Docs/SESION-2026-10-07-v2-relevo-5-ola-c.md`.

Lo que un agente necesita saber sin leer el resto:

- **`version-2` en `3956fd3` tiene la ola D de E1 (T8 y T5c) y E3a T5.** E1 entró con
  `7110b06` (pusheado); E3a T5 con `3956fd3`, que **no se pushea hasta que su `rapido` dé verde**.
  `rapido` sobre `3956fd3`: (pendiente) — esperado EK 357 · unit 639 + 1 declarado · release 0
  warnings.
- **El `completo` sobre `8d17b8d` (la ola C entera) dio todo verde menos Release.** Release no
  compilaba desde E1 T5: `GameState.swift:545:27: error: will never be executed`. Los tres
  `rapido` verdes de la ola C no lo vieron porque **el `rapido` no compilaba Release**. Lo
  arregló E1 T5c, que además **mete el Release en el `rapido`** (§2).
- **El dueño tomó cuatro decisiones** (§1): las rutinas de relevo existen, el ORO comprado se
  arregla exacto (E1 T6c), las fusiones asistidas cuentan, y la columna de E7b es plegable (C).
- **Existe `tasks.md` en la raíz de `version-2`**: el tablero único de la 2.0, con un solo
  escritor, el controlador (§4).
- Fuera de `version-2`: **E5a T1 🟢** en `v2/e5-premios` (`a4c156f`) y **E11 T3 🔧**
  (`f084ef5`, en el worktree de su agente, con dos tests por arreglar **que no se despacharon**).
- Para el relevo 7 hay dos briefs listos (**E1 T9** y **E1 T6c**) y una decisión del
  controlador: **partir `GameState.swift` en extensiones**, porque 20 tareas pendientes lo tocan
  de a una (§8).

## Cómo arrancó

- Relevo 6 del run AVO, desde las 11:18. Lo despertó el dueño escribiendo "continua", en sesión
  nueva: **quinto relevo seguido sin un despertar por cron** (relevos 2 a 6).
- Contexto al arrancar: 115k. Cuota: 5 h al 4 %, semanal al 21 %. `CronList` y
  `list_scheduled_tasks` vacíos. Máquina: 8 núcleos, 16 GB, load ~4.
- Lo que pedía el handoff del relevo 5: la ola D (E1 T8 · E11 T3 · E3a T5 · T6b · E5a T1 en
  frío · el plan de E7b) y un `completo` temprano sobre la punta.
- A mitad del relevo, el dueño pidió un tablero: *"dejar todo en un archivo tasks.md …
  implementarla por completo cuanto antes con subagentes concurrentes que no se pisen"*.

## 1. Las cuatro decisiones del dueño (no se vuelven a preguntar)

Se las preguntó el controlador con `AskUserQuestion`, en vivo.

| Tema | Decisión | Por qué / qué descarta | Consecuencia |
|---|---|---|---|
| El relevo | **Crear las rutinas `fisu-v2-relevo-a` y `-b`** | El primario (`CronCreate` + `clear_session`) no despertó a nadie en cinco relevos; las rutinas son el secundario de PLAN-v2 §0 y crearlas pedía su OK | Creadas, **manuales** (sin horario), en `~/.claude/scheduled-tasks/fisu-v2-relevo-{a,b}/SKILL.md`. El agente que cierra lanza la otra con `run_scheduled_task`; se alternan porque una rutina con una corrida en curso no se relanza |
| 🔒 `SaveConflictResolver.swift:67/:68`, el ORO comprado entre dispositivos | **Arreglo exacto** | `max` pierde compras de dos dispositivos (160 en uno y 550 en otro dan 550); el `||` cuenta de menos; un `&&` con el `+=` de hoy contaría doble. En el reset de E9 (`oro = min(saldo, comprado)`) cualquier error lo paga el que compró | **E1 T6c** (brief `task-6c-brief.md`): un mapa crece-sólo id de transacción → ORO más un conjunto de revocados, `oroPurchasedLifetime` calculado, unión de `creditedPurchases` y `&&` en `purchasedOroReconstructed`. Absorbe T6b. **E6a tiene que pasar por `recordOroPurchase`**, no por `+=` |
| Las fusiones asistidas (`BoardChange.merge` de origen `career` o `debug`) | **Cuentan** en `totalMergesEver` | Es lo que ya hacía el video de fusión instantánea (`performInstantMerge`), y lo que ya hace el código de E1 T7 | Sin cambio de código |
| 🔒 La columna de E7b pisa la multitud en todo iPhone | **C: plegable, hermana de la botonera del ascensor**. En reposo, un botón "Premios" con el "!" abajo a la izquierda; al tocarlo despliega los cuatro por 3 s | Descartadas **A** (reservarle 64 pt en `PlayLayout`: personajes −17 % en iPhone) y **B** (encima de la multitud: tapa 15–56 pt) | E7b-b T3 cambia el contenedor y **T4 se saltea** (⏭️). `PlayLayout`, `BoardScene` y sus tests quedan intactos |

El dueño preguntó también si tiene que correr algún pipeline de contenido. **Sí, tres cosas**; lo
demás (código, música, SFX, animación por código) lo hacen los agentes:

1. **El batch de imágenes**: proyecto
   `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2`, 222 prompts,
   primero el piloto 001–005 (la salida está vacía). Login en el Chrome aislado de ChatGPT y **la
   app de Claude CERRADA**, porque roba el foco. Paso a paso en su `README.md`.
2. **El OK de créditos** para el piloto de 2 loops de Higgsfield.
3. **Aprobar** los anexos A y B de PLAN-v2 y, cuando exista, la galería de efectos de skin (E6b T2).

## 2. El `completo` sobre `8d17b8d`: todo verde menos Release

Es el primero que mide la ola C (E1 T5, T6, T7 y T5b; E3a T4).

| Suite | `d22eb7a` (relevo 5, referencia) | **`8d17b8d`** |
|---|---:|---:|
| EconomyKit | 317 | **357** |
| unit (26.5) | 593 + 1 declarado | **620 + 1 declarado** (601 s) |
| Store unit (18.6) | 12 | **13** (1.945 s, con carga) |
| UI (26.5) | 57 | **59** (1.976 s) |
| `StoreUITests` (18.6) | 2 | **2** (147 s) |
| pipeline | 49 / 0 | **49 / 0** |
| `pacing-sim` | Dios en 30,73 h activas · 13 reencarnaciones | **igual** |
| Release | 0 warnings | **❌ no compila** (101 s) |

- **Todos los números esperados cuadraron**: UI 59 (+ `SaveRecoveryUITests` y
  `ScreenInsetsUITests`), Store unit 13 (+ `reconstructsTheV1OroFromTransactionHistory`),
  `StoreUITests` 2. El `pacing-sim` no se movió.
- **La causa del rojo**: `GameState.swift:545:27: error: will never be executed`, sobre el
  `loaded = .empty` adentro de `if forceNewGame {`. En Release, `forceNewGame` es un `var … =
  false` que sólo cambia dentro de `#if DEBUG`: la rama es código muerto, y con
  `SWIFT_TREAT_WARNINGS_AS_ERRORS` el aviso es un error.
- **Lo trajo E1 T5** (`38bee13`), al cambiar `if !forceNewGame, let saved = await
  repository.load()` por un if/else que asigna un `SaveLoadResult`.
- **Por qué pasó tres `rapido` verdes** (`cdd8f0a`, `d0710e1`, `8d17b8d`): el paso `release`
  sólo corría en el `completo`. Un rojo que existe sólo en Release, por un `#if DEBUG` que deja
  una variable constante, es invisible para un `rapido` que compila Debug.
- Tiempos: ~4.876 s en total (~81 min), con la máquina cargada por los agentes de la ola. El build
  salió en 37 s con el DerivedData caliente.
- Log: `version-2/build/relevo6-completo-8d17b8d.log`; el de Release, en
  `version-2/build/oraculo/20261007-112018-completo/release.log`.
- **Ninguna línea de base `completo` verde cubre todavía la ola C ni la D.** La referencia verde
  sigue siendo `d22eb7a`. El arreglo de Release se verificó con el `rapido` (que ahora lo
  compila): 0 warnings sobre `ca2d12c`.

## 3. La ola D, tarea por tarea

| Épica | Tarea | Commit (agente → integración) | Revisión | Números |
|---|---|---|---|---|
| E1 | T8: el ciclo de vida, sellar sólo al irse | `eeb7322` + arreglos `5ef7a65` (ff en la épica) | opus: spec ✅, *Needs fixes* (I1 + el doble sellado); re-revisión ✅ | `LifecycleTests` 13 · unit 633 + 1 |
| E1 | T5c: el `if` muerto en Release y el `rapido` con Release | `19247a5` + `bbf2e7f` → cherry-pick `e0a5d53` + `ca2d12c` | el controlador (diff de 12 líneas) | unit 631 + 1 · release 0 |
| E3a | T5: universal, iPad vertical, iOS 18, contrato del Info.plist | `c323dd9` (ff en `v2/e3-ux`) | sonnet: spec ✅, 0 críticos o importantes | `InfoPlistContractTests` 6 · unit 626 + 1 |
| E11 | T3: el manager 2.0 (prendidas por defecto, provisional, ausencia planificada) | `f084ef5` (**sin integrar**) | sonnet: spec ✅ byte a byte con el brief, *Needs fixes* (dos tests) | 21 tests nuevos, 9 viejos fuera · unit 632 + 1 |
| E5a | T1: el Paquete de la Aduana, puro (EK) | `b4800c5` + refuerzo `a4c156f` (ff en `v2/e5-premios`) | sonnet: código ✅, pero 7 de 8 mutantes vivos → refuerzo | EK 380 → **393** · unit 620 + 1 |
| E7b | plan, partido en E7b-a (forzados, UMP, mediación; 7) y E7b-b (columna, videos, mapa de ubicaciones; 8) | `5968823` → cherry-pick `28a298e`; re-plan con C `6c87075` → `d32688e` | — | 14 contradicciones |
| — | `tasks.md`, el tablero | `19b055a` → cherry-pick `d3c9538` | — | 133 filas de tarea |

Implementadores sonnet; revisores sonnet u opus según la tarea; planificador y agente de docs
opus. **Ningún commit del rango `8d17b8d..3956fd3` lleva `Co-Authored-By`** (verificado con
`git log --format='%(trailers:key=Co-Authored-By)'`), ni los dos de E5a.

### La integración

- **E1**: `v2/e1-correcciones` avanzó por ff `8d17b8d` → `eeb7322` → `5ef7a65`, y T5c entró
  por cherry-pick **encima** de T8 y sus arreglos (`e0a5d53` + `ca2d12c`): su BASE era `eeb7322`
  porque la línea que arregla la había movido T8 (545 → 559). `rapido` (ya con Release) sobre
  `ca2d12c`: **VERDE, EK 357 · unit 633 + 1 · release 0 warnings**. Merge `--no-ff` en
  `version-2` = `7110b06` (árbol Swift == `ca2d12c`), push `d3c9538..7110b06`.
- **E3a**: `v2/e3-ux` ff a `c323dd9`; merge `--no-ff` en `version-2` = `3956fd3`. Su `rapido`
  corría al cierre (log `version-2/build/relevo6-rapido-3956fd3.log`): (pendiente). **Se pushea
  después del verde.**
- **E5**: la rama de épica `v2/e5-premios` nació en `8d17b8d` y avanzó por ff a `a4c156f`. **No
  se mergeó a `version-2`**: va con el próximo `rapido` de fin de ola (EK pasa de 357 a 393).
- **E11 T3 no se integró**: espera sus arreglos.
- Los dos planes y `tasks.md` entraron a `version-2` antes que el código (`28a298e`, `d32688e`,
  `d3c9538`), pusheados.

### E1 T8, el ciclo de vida

Lo que hace, en una línea por pieza:

- **Se sella sólo al irse**: `active → inactive` e `inactive → background`. `background →
  inactive` (el regreso) no sella.
- **El guardado de la salida corre dentro de un `beginBackgroundTask`**
  (`App/BackgroundTasks.swift`, inyectable para los tests).
- **Con la escena inactiva, `tick` no cobra** (`isSceneActive`).
- **El watchdog de celebraciones recibe el delta con tope**: `min(delta, 2)`.
- **El evento que venció afuera se corre +60 s** al volver (`resumeGraceSeconds` en
  `events.json`).
- **Un latido sella y guarda cada 15 s** en foreground, para que un kill no repita la sesión.
- `handleScenePhase`, `seal`, `beatIfDue` y `applyOfflineProgressIfNeeded` viven en
  `GameState+Lifecycle.swift`.

**El arrastre de T1 (relevo 4) quedó cerrado, con números:**

- **(a) `.inactive` sellaba mientras la escena seguía cobrando: doble pago.** El test
  `inactiveStretchIsPaidOnce` lo fija exacto; con la lógica vieja (mutación) paga **+5,0 de
  más** (10 ticks × 0,5/s).
- **(b) `background → inactive → active` re-sellaba y el regreso en caliente acreditaba ~0.**
  En el simulador (16 Pro, 26.5, con instrumentación temporal): **45,39 s afuera → 7,943
  acreditado**, y 27,46 s → 4,805, exactos al centavo: 0,175/s = 0,5/s × 0,35 de eficiencia
  offline.
- En la misma corrida entró **un frame de SpriteKit con `delta = 28,52` mientras la escena
  todavía era `.inactive`**: el `tick` lo saltó. Ese frame es el que después destapó I1.

**El tope del watchdog rompió dos tests de `CelebrationWiringTests`**
(`watchdogUnsticksTheQueue` y `theHidingFlagDoesNotOutliveItsCelebration`): le inyectaban un
solo `tick(delta: 4.1)` o `8.1`, y con el tope ese salto ya no vence nada. No es un bug: una
escena real avanza de a 16 ms. Se adaptaron con un helper `advanceClock` de pasos de 1 s, en los
cuatro sitios con delta > 2 s. La revisión: prueban lo mismo, y más fuerte.

**La revisión (opus) pidió dos arreglos:**

- **I1, el flush se adelantaba al regreso.** `BoardScene.update` no está gateado por la fase,
  así que `flushHUD` corre con la escena `.inactive` en el regreso. Si el contador de frames
  llega a 8 en esa ventana, `fireEventIfDue` dispara el evento vencido **antes** de que `.active`
  lo corra +60 s, y `armIfDue` arma el intersticial antes de `sessionResumed()` (esto último ya
  pasaba antes de T8).
- **El doble sellado (duda 3 del implementador → defecto).** Cada salida pasa por los dos
  sellos; el segundo corría `lastSeen` hacia adelante y **el tramo `.inactive` previo no lo
  pagaba nadie**: ~0,5 s con Home, **20–30 s con una llamada atendida** o el Centro de control y
  después bloqueo.

**Los arreglos (`5ef7a65`, el mismo agente por `SendMessage`):**

- Con la escena inactiva, `flushHUD` **sólo proyecta**: la poda, `fireEventIfDue`, `beatIfDue`
  y `armIfDue` van adentro de `if isSceneActive`.
- `seal(now:stamping:)` estampa la hora **sólo si la escena estaba activa**; `inactive →
  background` guarda igual, en su background task. Un `begin` por salida.
- RED sobre `eeb7322`: 7 expectativas en 3 tests. GREEN: `LifecycleTests` 13 +
  `CelebrationWiringTests` + `OfflinePopupTests` = 33. `rapido` VERDE, unit 633 + 1.
- **Hallazgo del implementador que la revisión no había listado, y que es de ANTES de T8**: la
  poda de buffs (`ModifierMath.prune`) corría en esa misma ventana `.inactive` del regreso,
  borraba el buff que venció afuera, y el offline pagaba de menos, porque
  `OfflineCalculator.earnings` integra los buffs entre `lastSeen` y `now`. **630 monedas de menos
  en el test** (3 × 1.800 s). Lo cierra el mismo gate.
- La re-revisión (opus, el mismo revisor): ✅ los cuatro hallazgos.

**Lo que quedó a sabiendas:**

- **Un kill en foreground después de un `scheduleSave` re-paga a lo sumo 15 s × 0,35 ×
  pasivo.** Se corrigió el comentario ("nunca de más" era falso) en vez de estampar la hora en
  `persistNow`: estamparla ahí toca a todos sus llamadores (`Prestige`, `Debug`, los tests que
  comparan lo guardado con la memoria) y mete un `Date()` implícito en la persistencia.
- **Con la escena inactiva 2 s o más, el pasivo se paga a eficiencia offline (×0,35)**: una hoja
  del sistema larga (una compra, un permiso) paga menos que jugar. **Una pasada de menos de 2 s
  (`minimumCreditedSeconds`) no se paga**: se pierden ≤ 2 s por cada `.inactive` corto.
- El primer latido sella y guarda en el primer `flushHUD` después de `.ready` (lo exige el test
  del brief).
- **No verificado en el simulador**: el gesto de bajar el Centro de notificaciones (la
  herramienta de gestos pidió un permiso que no se concedió) y el popup offline en pantalla (en
  una partida nueva el tutorial restringe la cola a `.boardCelebration`). Lo cubren los tests.

### E1 T5c, el Release que vuelve a compilar

- `e0a5d53`: `var loaded: SaveLoadResult = .empty` + `if !forceNewGame { loaded = await
  repository.load() }`. DEBUG idéntico; en Release la condición es constante verdadera y no
  queda ningún bloque muerto. Sin `#if` nuevo. Descartado el ternario (`forceNewGame ? .empty :
  …`): el `.empty` seguiría siendo una rama muerta.
- RED: Release sobre `eeb7322`, exit 65 en `GameState.swift:559` (T8 había corrido la línea
  desde 545). GREEN: 0 warnings del compilador.
- `ca2d12c`: **`step release` corre también en el `rapido`**, después de `unit`. Usa su propio
  DerivedData, `build/DD-oraculo-release`, que **`--limpio` no borra**: ~20 s incremental, ~100 s
  la primera vez en un worktree (99 s sobre `ca2d12c`).
- T8 no dejó ningún otro rojo sólo de Release.

### E3a T5, la app universal

- `UIDeviceFamily` 1,2; iPad **sólo vertical** y con **`UIRequiresFullScreen`** (no participa
  del multitasking; esquiva el error 90474 de Validate); **iOS 18** de mínimo; la pantalla de
  lanzamiento **crema** (`PaletteCream`) en vez de blanca.
- Se fue el camino de iOS 17 de `clearNavigationBackdrop` (`LegacyClearNavigationBackdrop`):
  `presentationSizing` y `containerBackground(for: .navigation)` se usan sin `#available`.
- **`InfoPlistContractTests`** (6): RED 5 de 6 sobre BASE, GREEN 6. Uno de ellos,
  **`theSDKStillHonorsFullScreen`, se pone rojo a propósito el día que se compile con el SDK de
  iOS 27**, que ignora `UIRequiresFullScreen`. Es un guardián: **no se declara nunca**.
- **Desviación del brief, correcta según la revisión**: el test lee el ARCHIVO
  `Bundle.main.bundleURL/Info.plist` con `PropertyListSerialization`, no
  `Bundle.main.infoDictionary`. En un simulador iPhone, CFBundle colapsa las claves `~ipad`:
  `UISupportedInterfaceOrientations~ipad` da `nil` aunque el `.app` la trae (visto con `plutil
  -p`). Además el archivo compilado es el que tiene `DTSDKName` y `MinimumOSVersion`.
- En un **iPad Pro 13" (M4) con 26.5** abre vertical y a pantalla completa (2064 × 2752, sin
  ventana, barra de estado oculta). **El tablero se estira de borde a borde**: es lo que resuelve
  E3a T10.
- Revisión (sonnet): 0 críticos o importantes. Menores: un docstring dice "idioma" por "tipo de
  dispositivo"; la trampa que cita es la de `UIViewControllerBasedStatusBarAppearance`; un
  `@testable import` sin uso.
- Arrastres: a **T6**, `presentationSizing` y `containerBackground` sin `#available`, y todo
  test de contrato del plist lee el archivo. A **T10**, el paso `ipad-ui` con un iPad Pro 13" sin
  tocar `rojos-declarados.txt`. A **T12 y E10**, **fijar Xcode 26.x como SDK del release** hasta
  que se decida horizontal / sólo iPhone / ventanas, y las capturas de iPad 13" en App Store
  Connect (sin verificar que se exijan).
- `Packages/EconomyKit/Package.swift:6` sigue en `.iOS(.v17)`: inocuo (un paquete con piso
  menor compila igual); lo sube quien sea dueño de EK.

### E11 T3, el manager 2.0 (🔧, sin integrar)

- `NotificationsManager` reescrito según el brief (preferencia, permiso y ausencia), con
  `InMemoryNotificationCenter` (DEBUG) para los fixtures `--uitest-notifications-provisional` y
  `-denied`. Salen `notif.daily.*` del manager y del catálogo (cierra el arrastre de T2).
- 21 tests nuevos en `NotificationsManagerTests`; salen 9 viejos de `SettingsPersistenceTests`.
  `rapido` VERDE sobre su BASE: unit 632 + 1.
- **No toca `FisuEvolutionApp.swift`**: era de E1 T8 en esta ola. El comentario de sus líneas
  10-11 pasa a E11 T6.
- **La revisión pide dos tests:**
  - **I1**: `v1FalseIsRespected` pasa por la razón equivocada. Nunca refresca la autorización,
    así que sale por `canDeliver` antes de mirar el interruptor maestro.
  - **I2**: la rama `.denied` de `refreshAuthorization` (vaciar la cola) quedó sin test cuando
    salió la suite vieja (`revokedPermissionSyncsBack`).
  - **Un contrato, no un defecto**: `scheduleAbsence` decide con la autorización YA leída. Quien
    cablea el ciclo de vida (T6) llama `appBecameActive()` o `refreshAuthorization()` antes. Va
    como línea de docstring.
- **Los arreglos no se despacharon**: el controlador estaba en 284k de contexto. En el relevo 7
  ese agente ya no está en la sesión: van con un agente nuevo, BASE `f084ef5`, y el paquete de
  revisión `version-2/.superpowers/sdd/2026-10-07-v2-e11-notificaciones/review-8d17b8d..f084ef5.diff`.
- Arrastres (ledger de E11): a **T4**, `settings.notifications` y `.denied` siguen en `stale` en
  el catálogo y pasan a `manual`. A **T5**, `refreshAuthorization()` antes de
  `permissionCardDue`, y los UI tests necesitan `--uitest-notifications-provisional`. A **T6**,
  el comentario de `FisuEvolutionApp.swift:10-11`, un test del camino real
  `notificationsLaunched → background → pending` sin pre-refrescar en el rig, y
  `GameState+Debug.swift:37` (`removeObject(defaultsKey)`), que quedó redundante.

### E5a T1, el Paquete de la Aduana puro (🟢 en `v2/e5-premios`)

- `b4800c5`: cinco archivos nuevos de EK (`Prizes/WeightedDraw`, `PackagesConfig`,
  `PackagesState`, `PackageEngine` y sus tests). EK 380 (+23). Ninguna firma consumida cambió
  desde `d22eb7a`.
- **La revisión aprobó el código byte a byte con el brief, y aun así 7 de 8 mutantes
  sobrevivían con los 23 tests verdes**: la compuerta `canHire` (el `fxConfig` la tenía apagada),
  el arrastre del sobrante del reloj, las caídas múltiples, `WeightedDraw` sin test directo, y
  `randomElement` → `first`.
- Un menor real: con el Piquete (`rateMultiplier` 0) y `secondsUntilNext ≤ 0`, igual caía un
  paquete.
- **El refuerzo (`a4c156f`)**: `WeightedDrawTests` (7) + 6 en `PackagesEngineTests`; **los 8
  mutantes mueren**, probados a mano. En producción, `guard rateMultiplier > 0` (RED real →
  GREEN) y una costura interna `WeightedDraw.index(weights:ticket:)` para llegar al respaldo
  `lastIndex`, que ninguna semilla razonable toca. EK **393**.
- Arrastres: a **T2 y T3**, `validate()` rechaza pesos ≤ 0. A **T5**, `tierRatio` se cae con un
  arreglo vacío y el validador necesita `isFinite` (una razón enorme → `pow` desborda → NaN →
  "LLENO" falso). A **T6**, `PackageRoller.Odds` no tiene init público; la chance por tipo es
  `probability / typeIds.count` (si la divulgación de 3.1.1 pide odds por tipo, un adaptador a
  `[PrizeOdds]`); `planArrival` indexa `floors[ordinal]` sin chequear; los arribos en cola no
  reservan lugar (lo cubre `refundPackage`). `fxPackages` vive en `PackagesEngineTests.swift`
  para T2 en adelante.

### El plan de E7b, y su re-plan con la opción C

- **`28a298e`**: E7b-a (los forzados, UMP y la mediación, 7 tareas) y E7b-b (la columna, sus
  videos y el mapa de ubicaciones, 8). 14 contradicciones en
  `version-2/.superpowers/sdd/2026-10-07-v2-e7b/plan-report.md`. Las que más pesan:
  - **La config remota de anuncios nunca se carga ni se refresca en la app**:
    `AdsRemoteConfigLoader` no se instancia y nadie llama `refresh()`. `LootBoxGate` (E5a T8) y
    todo lo remoto leen sólo el respaldo del bundle hasta E7b-a T1.
  - **Una hoja de SwiftUI no se presenta debajo de un anuncio forzado** (trampa nueva que el
    plan absorbe).
  - **El Vendedor no es de E7b**: lo implementan E4a T5 y E4b T5.
- **`d32688e`**, el re-plan con C, por el **mismo planificador** (`SendMessage`), commit nuevo
  encima: 7 tareas, **T4 salteada**. T3 copia la botonera del ascensor de E3a T8: el mismo
  `MetalPlate`, un botón en reposo de 44 pt, una persiana 2 × 2 de botones de 30 pt con reloj LED;
  se pliega a los 3 s o al tocar un botón. T5 suma una lección `.sideRail` (abrir la columna
  primero; la persiana queda abierta mientras una lección apunta a uno de sus botones).
- **En el SE**, el botón "Premios" cuelga 10 pt arriba de la fila del atajo, no choca con ningún
  control y en reposo tapa ~20 pt del personaje de la celda 0. La columna y el ascensor abren en
  esquinas opuestas.
- **Cinco dudas nuevas con default** (para el dueño, no frenan): el "!" cuenta la ruleta, así que
  queda prendido casi todo el día · la columna se pliega a los 3 s y el ascensor a los 2 s · son
  independientes (abrir una no cierra la otra) · la columna no se abre sola por un "!" nuevo ·
  metal, no madera.

## 4. `tasks.md`, el tablero único

- Lo pidió el dueño (cita arriba). Lo armó un agente de docs (opus): `d3c9538`, en la raíz de
  `version-2`, 598 líneas.
- **Un solo escritor: el controlador.** Los subagentes reportan y el controlador pasa el dato. El
  detalle fino (arrastres, menores, reportes) sigue en los ledgers; `tasks.md` lleva una línea
  por tarea, el estado (✅ 🟢 🔧 🔄 ⏳ ⛔ 🔒 ⏭️), dependencias, archivos calientes y tibios, la
  cola de despacho y los gates del dueño.
- La foto con la que nació: 133 filas de tarea en los planes, 132 activas: 13 ✅ · 1 🟢 · 3 🔧 o
  🔄 · 7 ⏳ · 106 ⛔ · 2 🔒 · 1 ⏭️. Al cierre de este relevo: 15 ✅ (11,4 %).
- **Ocho inconsistencias entre planes** que el agente encontró (§5 de `tasks.md`):
  1. E8 (integración del arte, cinemáticas, la cadena de Fusionar todo) y la parte de agente de
     E10 no tienen plan por tareas.
  2. E7b-b: el encabezado pide E4–E6 cerradas; la tabla da dependencias más finas.
  3. **El `init` de `EngagementState` deja cuatro épicas en fila detrás de E1 T16** (E3b T9 →
     E4a T3 → E5a T4 → E6a T1).
  4. E2b: PLAN-v2 §4 la pone después de E9; su texto, después de E4–E6.
  5. `v2/e6-tienda` tiene que existir para E6b T1/T2 antes de tener E5.
  6. E6a T9/T11 escriben `oroPurchasedLifetime +=`: con T6c pasan por `recordOroPurchase`.
  7. Los anexos A/B son gate en E0, pero ningún plan los gatea.
  8. El texto del plan de E3a quedó viejo después de los spikes.
- **El cuello de botella: `GameState.swift`.** 20 tareas pendientes lo tocan, y por la regla de
  un dueño por ola van de a una. La propuesta de partirlo es la decisión del controlador del
  relevo 7 (§8).

## 5. Los números del oráculo

### `rapido` de la ola D

| Árbol | EK | unit (26.5) | Release | Veredicto | De dónde sale |
|---|---:|---:|---|---|---|
| `8d17b8d` (ola C, BASE de la ola) | 357 | 620 + 1 | — | VERDE | — |
| `eeb7322` (E1 T8) | 357 | 631 + 1 | — | VERDE (2ª corrida) | +11 de `LifecycleTests`; la 1ª corrida dio 2 rojos de `CelebrationWiringTests` (el tope) |
| `5ef7a65` (+ arreglos de T8) | 357 | 633 + 1 | — | VERDE | +2 |
| `bbf2e7f` (T5c sobre `eeb7322`) | 357 | 631 + 1 | **0 warnings** | VERDE | el primer `rapido` con Release (20 s) |
| **`ca2d12c`** (E1 ola D; árbol Swift == `7110b06`) | **357** | **633 + 1** | **0 warnings** | **VERDE** | build 97 s, unit 656 s, release 99 s |
| `f084ef5` (E11 T3, sobre `8d17b8d`; sin integrar) | 357 | 632 + 1 | — | VERDE | +21 − 9 |
| `c323dd9` (E3a T5, sobre `8d17b8d`) | 357 | 626 + 1 | — | VERDE | +6 de `InfoPlistContractTests` |
| `a4c156f` (E5a T1; sólo `swift test`) | **393** | 620 + 1 (en `b4800c5`) | — | VERDE | +23 en `b4800c5` y +13 del refuerzo |
| **`3956fd3`** (`version-2`) | 357 | (pendiente) | (pendiente) | (pendiente) | esperado 633 + 6 = **639 + 1** |

- La cuenta cierra: 620 + 11 de T8 + 2 de sus arreglos = 633; + 6 de E3a T5 = 639. Un número
  distinto es un test perdido o duplicado.
- **Con E11 T3 y E5a T1 integrados** se espera EK 393 y unit 651 + 1 (639 + 21 − 9), más lo que
  sumen los arreglos de E11 T3.
- La máquina corrió casi toda la ola con load average de 300 a 550 (hasta 3 agentes compilando,
  más el `completo`). Ningún rojo espurio por carga.

### Lo que el próximo `completo` tiene que dar

Sobre `3956fd3` o la punta que venga: EK 357 · unit 639 + 1 · Store unit 13 · UI 59 ·
`StoreUITests` 2 · pipeline 49/0 · `pacing-sim` igual (Dios en 30,73 h, 13 reencarnaciones) ·
Release 0 warnings. **Nada de la ola D pasó todavía por UI, Store ni `pacing-sim`.**

## 6. Trampas nuevas

### A. Un `rapido` sin Release no ve los rojos de `#if DEBUG`

Tres `rapido` verdes seguidos (`cdd8f0a`, `d0710e1`, `8d17b8d`) no vieron que Release no
compilaba: una variable que sólo cambia dentro de `#if DEBUG` es constante en Release, y la rama
que la usa es código muerto, error con warnings como errores. **Desde `ca2d12c` el `rapido`
compila Release** (~20 s incremental, ~100 s la primera vez, DerivedData propio que `--limpio` no
borra).

### B. `Bundle.main.infoDictionary` colapsa las claves `~ipad` en un simulador iPhone

`UISupportedInterfaceOrientations~ipad` da `nil` aunque el `.app` la trae (`plutil -p`). Todo
test de contrato del plist lee el archivo `Bundle.main.bundleURL/Info.plist` con
`PropertyListSerialization`.

### C. `oraculo.sh …; echo EXIT $?` en una tarea de fondo enmascara el exit

La tarea de fondo termina en 0 aunque el oráculo dé 1, porque el último comando es el `echo`.
**Se lee la última línea del log** (`VERDE` o `ROJO: …`), no el exit de la tarea.

### D. `AskUserQuestion` bloquea el turno del controlador

La pregunta de las cuatro decisiones bloqueó el turno **~90 min**, hasta que el dueño contestó.
Los agentes en fondo siguieron trabajando y sus avisos llegaron todos juntos al volver. Sirve,
pero **se despacha todo lo despachable antes de preguntar**.

### E. El grep del brief de E11 T3 no da vacío

`grep -rn "notif.daily"` matchea `notif.daily_ready.*`, porque el `.` es comodín. Para buscar las
claves viejas: `notif\.daily\.`.

### F. Un test que inyecta un delta grande al watchdog dejó de probar algo

Con el tope de 2 s de T8, un `tick(delta: 4.1)` no vence nada. Los tests que necesitan que pase
el tiempo lo avanzan de a pasos (`advanceClock`, de a 1 s), como la escena real.

### G. Un test se pone rojo a propósito con el SDK de iOS 27

`InfoPlistContractTests.theSDKStillHonorsFullScreen` falla el día que se compile con el SDK 27,
que ignora `UIRequiresFullScreen`. **No se declara**: avisa que hay que decidir horizontal, sólo
iPhone o ventanas antes de cambiar de SDK. Hasta entonces, el release se compila con Xcode 26.x.

### H. Tests verdes que no muerden

E5a T1 tenía 23 tests verdes y el código idéntico al brief, y 7 de 8 mutantes sobrevivían. Para
una tarea pura de EK, la revisión prueba mutantes a mano, no sólo que los tests pasen.

### I. El cron, otra vez

Quinto relevo sin un despertar por cron: los relevos 2 a 6 los despertó el dueño. Desde este
relevo existen las rutinas manuales (§1).

## 7. El mecanismo (mantener lo que funcionó)

- **Los arreglos de una revisión van al MISMO implementador con `SendMessage`**, que retoma su
  worktree y su contexto (T8, E5a T1). Lo mismo con un re-plan por una decisión del dueño: al
  mismo planificador, commit nuevo encima (E7b-b). **Sólo dentro de la misma sesión**: en un
  relevo nuevo va un agente nuevo con BASE = el commit del agente.
- **El `completo` temprano sobre la punta encontró lo que tres `rapido` no**. Hay que correrlo al
  principio de cada relevo, no sólo al cierre de una épica.
- **Una tarea de seguimiento chica se integra encima de la que movió su línea**: T5c salió con
  BASE `eeb7322` (T8) y entró por cherry-pick encima de los arreglos.
- **Disciplina de contexto**: a los 284k el controlador dejó de lanzar tareas. T6c y los
  arreglos de E11 T3 pasaron al relevo 7 en vez de quedar a medio integrar.
- **El push espera al verde**: `3956fd3` no se pushea hasta que su `rapido` lo confirme.

## 8. Lo que quedó abierto (relevo 7)

1. **El `rapido` sobre `3956fd3`**: (pendiente). Con VERDE (esperado EK 357 · unit 639 + 1 ·
   release 0), push de `version-2`. Con ROJO: fuera de los docs, el diff contra `ca2d12c` son
   sólo los cuatro archivos de E3a T5.
2. **Los arreglos de E11 T3** (I1 e I2 + el docstring del contrato), con un agente nuevo, BASE
   `f084ef5`. Después, `v2/e11-notificaciones` por ff o cherry-pick y su integración.
3. **Mergear `v2/e5-premios` (`a4c156f`) a `version-2`** con el próximo `rapido` de fin de ola
   (EK 357 → 393).
4. **La ola E**: E1 T9 (brief `task-9-brief.md`, lleva el init público de
   `BoardChangeOutcome` de T7) ∥ E1 T6c (brief `task-6c-brief.md`, corre `store-unit` en 18.6).
   No comparten archivos. Para el tercer cupo: los arreglos de E11 T3, y después E6b T1 o E3a T6
   (destrabada por T5). La cola completa está en `tasks.md` §4.
5. **Decisión del controlador: partir `GameState.swift`** (1.169 líneas) en extensiones antes de
   E1 T10. Swift no deja mover propiedades almacenadas a una extensión, así que el cuerpo de la
   clase se queda con el estado (~360 líneas); el resto puede irse: los tipos anidados (~140),
   `bootstrap` (~390), el frame loop, `refreshProjections` (~115, el que más se toca) y la
   persistencia. **Lo que ganaría**: la mayoría de las 20 tareas toca `GameState.swift` para sumar
   una o dos propiedades, una proyección o un caso de `TowerNotice`, y esas tareas podrían
   compartir ola. El costo: una tarea mecánica que toma el archivo, y los planes que citan
   `GameState.swift:NNN` (ya vencidos desde T5 y T8). El detalle, en `tasks.md` §4.4.
6. **Un `completo` sobre la punta**: nada de la ola D pasó por UI, Store ni `pacing-sim`. Números
   esperados en §5.
7. **Docs que todavía dicen "sólo iPhone" o "iOS 17"**: `Distribution/store-metadata.md` (no dice
   nada de iPad ni del mínimo; es de E10). `Packages/EconomyKit/Package.swift:6` sigue en
   `.iOS(.v17)` (inocuo).
8. **Las rutinas no nombran `tasks.md`**: su prompt
   (`~/.claude/scheduled-tasks/fisu-v2-relevo-{a,b}/SKILL.md`) manda leer el general, el handoff
   y el journal. Vive fuera del repo; se ajusta con `update_scheduled_task`.
9. **La prueba manual v1 → v2 del dueño sigue cerrando el ORO comprado en 0** hasta que entre
   T6c, que absorbió a T6b (trampa E del relevo 5).
10. **La captura de `SaveRecoveryView` en el SE** para el dueño (paso 6 de E1 T5): el `completo`
    corre en el 16 Pro y no consta que se haya hecho.
11. **Del dueño**: el batch de imágenes, el OK de Higgsfield, los anexos A/B, las cinco dudas
    nuevas de E7b-b, `rentista_soles` (no borrar el worktree `v2-e8-pipeline`) y la limpieza de
    los worktrees de agentes (hay 29 `agent-*`; el clasificador bloquea borrarlos desde un
    agente).
