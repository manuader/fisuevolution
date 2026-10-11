# SESION 2026-10-11 — v2, relevo 33: el núcleo del tutorial en el director, un solo renderer, el reset de la partida que no pierde plata y los cierres de E5, E6a y E7b

La ola AE. El relevo 33 arrancó a las 09:02 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (lo liberó el 32 a las 08:47). Cuota en 5 h 6 %, semanal 73 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`), **E9a T5 y E9a T6 en opus** (el director y el renderer único), y **tres revisiones opus de código** (E9a T5, E9a T6, E9b T8). Todo pasó por **`v2i/integ-r33`** (BASE `version-2` en `178dd09`, 240 de 283, que es también `origin`). El `comun.md` vive en la carpeta del run (`.claude/avo/2026-10-06-fisu-v2/ola-r33/`), que sobrevive al barrido, con copia en `v2i-integ-r33/.superpowers/sdd/ola-r33/`.
`fisu-v2-relevo-b` no existe. `DUENO.md`: sin pedidos nuevos (los `[ ]` abiertos esperan al dueño: skins con video, mediación SPM, segunda tanda, blocklist → E12 T16). Carga: 1,6 al arrancar. El último despacho del relevo fue a las 09:52 (contexto en 211k); el `LOCK` se libera al cerrar.
**E6b T8 y E8d T15 Steps 3–4 no se despacharon:** la primera espera el OK del dueño en vivo, la segunda los gates en device.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`a90a6b6f`** (código = `336cb063` = `v2i/integ-r33`, fast-forward, pusheado), desde `178dd09` |
| Progreso | 240 al llegar → **246 de 283 (86,9 %)** (el `grep` de `tasks.md` §2, con `[a-f]?`) |
| `completo` | `9af95202` **ROJO sólo en UI: 141 verdes · 3 rojos · 4 salteados**, los tres verdes aislados 2/2 (flakes de carga). Resto VERDE: EK 863 · unit 1636 · Release 0 · store 18+2 · iPad 4 · SE 2 · pipeline 97 · pacing-sim Dios 31,34 h · 13 reenc. |
| `completo2` | `336cb063` **ROJO sólo en UI: 145 verdes + 2 rojos** (`CustomizationUITests` :137 y :427, flake de la clase). Resto VERDE: EK 865 · unit 1655 · Release 0 · store 18+2 · iPad 4 · SE 2 · pipeline 97 · pacing-sim Dios 31,34 h · 13 reenc. |
| En vuelo al cierre | ninguno |

## Lo que se integró

| Tarea | Commits | Verificación y revisión | Desvíos y carries |
|---|---|---|---|
| **E5b T7** (cierre de E5, docs) | `51e63b88` (`SESION-2026-10-11-v2-e5`) | Sólo `Docs/`; el controlador leyó el diff de `PLAN-v2`. Sin opus | ff en integ + `tasks.md` (`b72b5e32`). Carry: HANDOFF §8 seguía listándola pendiente (lo corrigió el cierre de E6a) |
| **E7b-b T8** (cierre de E7b, docs) | `183ec0d7` (`SESION-2026-10-11-v2-e7b` + HANDOFF §4/§5/§7/§9 + `PLAN-v2` E5/E7) | Su plan era el oráculo (ya había `completo`) + docs; no choca con `GameState` | Entra junto con E5b T7: 242 de 283 |
| **E6a T13** (cierre de E6a) | `c11068ee` código · merge `4564b463` · claves `669c7048` · docs `d901d456` (`SESION-2026-10-11-v2-e6`) · tasks `11cdc438` | tarea `OroShopScreenTests` VERDE (EK 863 · unit 7); `OroShopUITests` 7, `OffersUITests` 1, `StoreUITests` 2 en 26,5 s; RED por mutación del `testTheStoreSubtitleFollowsTheSelectedSide`. El controlador leyó el diff: OK. Sin opus | `Segment.subtitleKey`: `store.subtitle` / `store.subtitle.spend` (ids `store.subtitle.buy`/`.spend`). **El cofre bajo la hoja no se reprodujo** (dos UI con puerta DEBUG temporal, hoja por la cola y por el chip: el cofre quedó visible y tocable al cerrar; revertidos). Cerrado por el dueño como no reproducible |
| **E9a T5** el núcleo en el director | `cbdaf82f` · merge `c674299e` · claves `9af95202` | tarea VERDE EK 863 · unit 206 (18 clases); LaunchSmoke 5/5, TutorialUITests 8/9 (el de Pintas arreglado, verde aislado); RED por 3 mutaciones: candado de 5 s, el toque no saltea, `restrict(to: nil)`. **Revisión opus: Approved, sin obligatorios** | `TutorialCurriculum.core`, `TutorialCard` mudada, `TutorialOverlay` sin `@State`/`@AppStorage`/Saltar, `finishTutorialCore`. Desvíos: overlay con `showing == nil`; `spawned`/`merged` cumplen `core.tap`/`hire` (bug real de retomar sin monedas); `startTutorialRun` rechaza otra corrida con el núcleo vivo; `startTutorialCoreIfPending`; `--uitest-tutorial-at-finish`; `tutorial.replay.end` al snapshot, `tutorial.skip` a quitar (sale en las claves) |
| **E9a T6** un solo renderer | `beb84d80` + menores `730cfa09` · merge `4f1500c5` · clave `4584c46c` | EK 865 · tarea 69 clases VERDE (unit 759); UI: LaunchSmoke 5, Prizes 2, SideRail 6, TutorialUITests 9, TutorialLockUITests 3 (nuevo); RED por 3 mutaciones. **Revisión opus: Approved con arreglos** | `.tutorialTip` sin timeout ni salto en EK; `TutorialOverlay` único renderer (núcleo con `showing == nil`, lecciones con `showing == .tutorialTip` y pasos `.board`); scrim 0,68/0,55; `TutorialTipView` y `dismissTutorialTip` borrados; `TimelineView` pausado; retiro de la lección muerta en el paso 0 (la red que pedía la opus de T4); `GameState.flagDefaults` + `IsolatedDefaults` en tests; sale `tutorial.tip.gotit` |
| **E9b T8** el reset en la app | `d0a303b5` + arreglos `3ad78b60` (merge de `e9a-t6`) y `31269136` · merge `336cb063` | tarea VERDE EK 865 · unit 139 (`GameStateResetTests` 13); RED por 12 mutaciones y, tras la revisión, `stalePlanIsRejected` y `purchaseDuringTheWriteIsNotLost` ×2. **Revisión opus: Changes requested → arreglada.** El controlador leyó el diff de `StoreManager`: OK | `GameState+Reset`: backup → época (cerrojo) → `saveVerifying` → rollback; `applyReset` repite `debugResetSave`; `debugResetSave` ahora conserva lo comprado; `repushEntitlements` por cierre; `applyStoreEntitlements(force:)`; `newGame` sin `private`. Ver «Las revisiones opus» |

## Los dos `completo` y el triaje

1. **`completo` de `9af95202`** (09:50 → 12:02, sobre E6a T13 y E9a T5): ROJO sólo en `ui` — 141 verdes, 3 rojos, 4 salteados: `CinematicUITests.testLaCinematicaTapaLaPantallaYSeSaltea` (:22) y `CustomizationUITests.testElCarruselCambiaDePersonajeYLoNuncaVistoNoSeElige` (:137) y `testPonerseUnaPintaSeLaSacaALaQueEstabaPuesta` (:427). El resto, VERDE (números en la tabla de arriba).
2. **Triaje** (sonnet, worktree detach `v2i-triaje-r33`): los 3 rojos **verdes aislados 2/2** cada uno en `9af95202`; la Cinematic tardó 104 s en el `completo` contra 20–28 s aislada: carga. Flakes. Con eso `version-2` se promovió a `9af95202` (E6a T13 ✅, E9a T5 ✅: 244 de 283).
3. **`completo2` de `336cb063`** (12:12 → 13:31, sobre E9a T6 y E9b T8, que es el obligatorio de la revisión de T6): ROJO sólo en `ui` — 145 verdes + 2 rojos, ambos de `CustomizationUITests` (:137 `testElCarruselCambiaDePersonaje…` y :427 `testSinPrecioLaSkinPaga…`): **`skins.character.homeless` no aparece en 10 s**. Lectura: intermitente de la clase (los que caen cambian entre corridas: en el `completo` cayó `testPonerseUnaPinta…`, que acá pasó; aislados 6/6 verdes en el triaje). **Carry: endurecer la espera del primer personaje del carrusel** (o scroll hasta él). `version-2` ff a `336cb063` (E9a T6 ✅, E9b T8 ✅: 246 de 283).

## Las revisiones opus

- **E9a T5 — Approved, sin obligatorios.** Sin camino a una cola congelada; las banderas, bien; no se puede saltear; la fuga de defaults no cruza a UI. Menores → carries: el watchdog en el núcleo puede dejar ~6 min muertos (`core.tap` → `hire` → `merge` a 180 s cada uno; decisión del dueño, abajo, y un test que la fije); `TimelineView` del candado a 30 Hz con el candado abierto; el `id` `tutorial.done` vs `tutorial.confirm` (T6/`TutorialLockUITests`); un test de «no segundo cofre al retomar en `core.finish`». Carries a T6 (defaults inyectados, gate `showing == nil`, pausar el `TimelineView`), a T7 (`TutorialJobsHint` en `FisuJobsView` mira `tutorialPhaseActive`) y a E9b (repaso/Tour con el núcleo vivo se rechaza en silencio; CloudKit en un dispositivo nuevo repite el núcleo; el reset es la secuencia de `debugResetSave`).
- **E9a T6 — Approved con arreglos.** Sin camino de cola congelada en producción (las lecciones de un paso las termina siempre el watchdog; los toques por recorte cumplen la señal; el retiro no oscila). **Obligatorio:** `completo` con T6 adentro + mirada visual (scrim 0,55, fundido, Reduce Motion, SE, iPad) → el `completo2` cubre lo primero y **la mirada visual queda al dueño**. Menores arreglados en `730cfa09`: `IsolatedDefaults` limpia `test.flags.*` al arrancar el proceso y `notificationsLaunched` lee `flagDefaults`. Siguen como carries: `+Debug:27/393/~620` en `.standard` (→ E9b T8, hecho para `debugResetSave`); una lección se quema si la señal parpadea un frame (opcional: < 1 s retira sin marcar); una lección sin ancla ocupa la cola hasta 180 s; el interstitial no pausa el reloj. **Carries serios:** **E9b — watchdog + `rewindToBoard` = bucle sin tope en lecciones de varios pasos (IMPORTANTE)**; `lessonMomentDied` sólo mira el paso 0; la mano `HoldHand` en la lección de la placa; T7/T8 repiten «nunca dos scrims» y `showing == .tutorialTip`; T9 migra `TabUnlockWiringTests`/`TutorialBootstrapTests` a `isolatedForTest()`.
- **E9b T8 — Changes requested.** Obligatorios: (1) **un plan viejo borraba las compras y revocaciones llegadas entre armar el plan y confirmar** (StoreKit ya había hecho `finish`) → re-armar y comparar, `ResetOutcome {done, stale, noBackup, writeFailed}`; (2) **una compra durante el `await saveVerifying` se pisaba** → `isResetting`, `creditStorePurchase`/`revoke` devuelven `Bool`, `StoreManager` no hace `finish()` sin acreditar (arregla además un bug viejo: la oferta desconocida se finalizaba sin acreditarse) y `retryUnfinished()`; (3) integración con E9a T6: `wipeGameFlags(in: flagDefaults)` y tests aislados. Menores: `clearSessionRuntime` incompleto, `CloudSaveSync` re-sube por `resetEpoch`, `repushEntitlements` sin default, el comentario de `debugResetSave`. Devuelto al mismo agente, que mergeó `v2i/e9a-t6` en su rama primero. Hecho en `3ad78b60` y `31269136`: `stale` se decide por `.result` (el `summary` tiene `unitsOnBoard`), `finishReset`, `clearSessionRuntime` con 12 propiedades; tarea VERDE EK 865 · unit 139.

## Decisiones del dueño (chat del relevo 33, 12:45)

- **El «cofre bajo la hoja» queda CERRADO como «no se reproduce».** Era una sospecha de lectura de código (carry de la opus de E6a T12); dos UI tests dieron el cofre visible y tocable al cerrar. Se reabre sólo si el dueño lo ve en device. Anotado en `tasks.md` §7 (la pregunta que el controlador le había hecho —el escenario exacto— queda respondida).
- **El vigilante del núcleo NO saltea a un paso imposible (opción B).** Si a los 180 s el jugador no cumplió el paso (p. ej. `core.tap`), el núcleo no avanza a `core.hire`/`core.merge` sin plata ni par: se queda en el mismo paso y lo vuelve a mostrar **más insistente** (reinicia el reloj). El núcleo sigue sin poder saltearse; nadie cae en un paso que no puede cumplir. Las lecciones (de un paso) siguen terminando por watchdog. **Lo hace E9a T7** (la próxima tarea que toca `GameState+Tutorial`), con un test que lo fije y RED por mutación.

## Trampas nuevas

- **Con `git -C <dir> worktree add`, una ruta relativa se resuelve contra `<dir>`:** el worktree de docs de E6a quedó anidado dentro de `version-2/.claude/worktrees.nosync/`. El agente trabajó ahí igual; hubo que borrarlo por ruta y quitar el directorio vacío. **Rutas de worktree siempre absolutas.**
- **Una lección con un paso imposible bloquea al jugador, no a la cola:** el watchdog de 180 s del núcleo avanzaba a `core.hire`/`core.merge` sin plata ni par (decisión B arriba). Todo vigilante que avanza por tiempo se pregunta si el paso siguiente se puede cumplir.
- **Un test de defaults en `.standard` contamina al host de tests:** `finishTutorialCore` dejaba `tutorial.v2.completed = true` y `IsolatedDefaults` dejaba dominios persistentes. Las banderas del tutorial se leen de `GameState.flagDefaults`, los tests usan `IsolatedDefaults`/`isolatedForTest()` y la limpieza corre al arrancar el proceso.
- **StoreKit ya hizo `finish()` cuando llega la transacción:** si el juego no la acredita (reset en curso, oferta desconocida), se pierde. `StoreManager.handle` sólo finaliza lo que quedó resuelto y `retryUnfinished()` reintenta; todo reset es una ventana en que las compras esperan.
- **Un `completo` rojo sólo en UI se aísla antes de culpar a la ola, y la clase que cae cambia entre corridas = flake.** Con `CustomizationUITests` rojo en dos corridas por motivos distintos, no se relanza el `completo`: se endurece la espera.
- **Una tarea que se creyó ⛔ puede estar destrabada:** E9a T6 y E9b T8 figuraban ⛔ por desactualizadas (sus dependencias ya estaban ✅). Revisar la columna «depende de» contra el estado real antes de decir que no hay nada despachable.
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`», las claves por snapshot, un oráculo por vez y nada de tocar `integ` mientras corre, ≤ 3 compilando, esperar por PID (nunca `pgrep -f`), borrar sólo el simulador propio por UDID, `Package.resolved` en los worktrees nuevos.

## Para el dueño

- **Mirar el tutorial en device:** el scrim (0,55), el fundido, Reduce Motion, el SE y el iPad (la mirada visual que dejó la opus de E9a T6).
- **E6b T8** espera tu OK en vivo.
- **Publicar el sitio** (rama local `fisu-v2-release`, `3f03716`) y `terms.md` §3, como en el 32.
- **Si ves el cofre bajo la hoja de una oferta en device,** avisá: hoy está cerrado como no reproducible.
- Siguen los del 32 y el 31: la medición del spike en tu SE, B22, `releaseops asc builds` real, publicar notas y políticas, `PREGUNTAS-DUENO.md`, mirar lo animado de E8e en un iPhone.

## Lo descartado

- **Relanzar el `completo` por los 3 rojos de UI:** aislados 2/2 verdes en la misma punta; carga.
- **Que el núcleo salte al paso siguiente a los 180 s aunque no se pueda cumplir:** el dueño eligió la opción B (repetir el mismo paso, más insistente); y el botón «Saltar» salió en E9a T5.
- **Reabrir el cofre bajo la hoja con más UI tests:** sin evidencia de device, no.
- **Despachar más tareas pasadas las 09:52** (contexto 211k, dos oráculos largos en vuelo): sólo arreglos y oráculos.

## Cierre

- Subagentes de tarea en vuelo al cerrar: 0. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla (y el de triaje); quedan `v2i-integ-r33` y `v2i-docs-r33` (más los de relevos anteriores si no se barrieron). Un `--apply` por worktree, con el shell fuera de él. `v2-e8-recortes`, `v2-e8e-plan` y el de `v2/estudio-assets` **no son `v2i-*`: no tocar.** El worktree del sitio (`adergames-site.worktrees/fisu-v2`) queda: el dueño publica desde esa rama.
