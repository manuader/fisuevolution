# Sesión 2026-10-07 (relevo 4) — La ola B: la frontera con un solo mutador, el save v6, el núcleo de E11 y los spikes de la pantalla

Continúa `Docs/SESION-2026-10-06-v2-integracion-y-ola-a.md`.

Lo que un agente necesita saber sin leer el resto: **`version-2` en `5a65335` tiene la ola B
integrada y el `rapido` da VERDE con EconomyKit 317 · unit 593 + 1 declarado**, la línea de base
rápida nueva. Los spikes de E3a cambian cuatro tareas de su plan, y **el texto del plan todavía
dice lo viejo**: el despacho de E3a T4, T6, T8 y T10 tiene que llevar las líneas de §3. Hay dos
🔒 nuevos para el dueño (§5).

## Cómo arrancó

- Relevo 4 del run AVO, de 01:28 a ~03:30. Lo despertó el dueño escribiendo "continua".
- El cron de un disparo que dejó el relevo 3 tampoco se vio: **es la tercera vez sin un despertar
  por cron observado**.
- Contexto al arrancar: 131k. Cuota: 5 h al 7 %, semanal al 12 %.

## 1. Qué entró en la ola B, y por qué esas tareas

El calendario de PLAN-v2 §0.1 pone en la ola B a E1 T3 → T4 ∥ el núcleo de E11, y el plan de E2a.
Entró eso, salvo E11 T3, y además dos cosas que el calendario ponía más adelante:

- **E3a T1, T2 y T3.** Ninguna toca un caliente de E1 ni de E11 (tabla de calientes del
  protocolo):
  - T1 es `Tools/v2/catalogo.py`, la pieza que deja que dos tareas de una misma ola sumen strings
    (PLAN-v2 §0.1);
  - T2 son spikes, sin commits;
  - T3 es `PlayLayout`, un archivo nuevo.
- **El plan de E4**, que el calendario ponía en la ola C. Ocupó el segundo lugar de agente de
  planes.

| Épica | Tarea | Commit | Revisión | Números del agente |
|---|---|---|---|---|
| E1 | T3: un solo mutador de la frontera, contadores `Double` y la contratación gratis que no cuenta | `111bbfb` (ff) | opus: spec ✅, 0 críticos o importantes, 4 menores | EK 279 · unit 575 + 1 |
| E1 | T4: save v6, `EngagementState` y `migrateV5toV6` | `76a69c1` (ff) | opus: spec ✅, 0 críticos o importantes, 4 menores | EK 293 · unit 582 + 1 |
| E11 | T1: `NotificationsConfig` y `NotificationPlanner`, puros en EconomyKit | `508a4c5` (ff) | sonnet: spec ✅, 0 críticos o importantes, 5 menores | EK 298 · unit 574 + 1 |
| E11 | T2: `notifications.json` validado al arrancar y 6 claves `notif.*` | `9c5847c` (ff) | sonnet: spec ✅, 0 críticos o importantes, 2 menores | unit 578 + 1, catálogo canónico |
| E3a | T1: `Tools/v2/catalogo.py`, el catálogo canónico con snapshots | `f542b16` (ff) | sonnet: spec ✅, 0 críticos o importantes, 5 menores | `test_catalogo` 3/3, ida y vuelta byte a byte |
| E3a | T3: `PlayLayout`, la geometría pura con el golden de iPhone | `fe7359a` → cherry-pick `f03950c` | sonnet: spec ✅, 0 críticos o importantes, 4 menores | unit 581 + 1 |
| E3a | T2: spikes S1, S4, S5 y S6 (opus) | sin commit | — | §3 |
| E2a | plan, 15 tareas | `ee42359` → `6be4f99` | — | 14 dudas con default |
| E4 | plan partido en E4a (motor, 10 tareas) y E4b (escena y Álbum, 10) | `37348e6` → `57aacce` | — | 26 dudas con default, 20 contradicciones |

Los implementadores fueron sonnet salvo los spikes (opus). Ningún commit lleva `Co-Authored-By`.

### La integración

- E1 y E11 entraron a su rama por fast-forward.
- E3a T3 salió de `68bb47c`, pero `v2/e3-ux` ya estaba en T1: entró por cherry-pick (`f03950c`)
  desde el worktree nuevo de la épica, `.claude/worktrees/v2-e3`. El
  `git diff --stat fe7359a f03950c` sólo mostró los `.py` de la T1, así que el árbol Swift es el
  que probó el agente y su `rapido` valía (trampa C).
- A `version-2`, merges `--no-ff` de `v2/e1-correcciones` (`1a36d62`), `v2/e11-notificaciones`
  (`5e4de30`) y `v2/e3-ux` (`5a65335`). **Sin conflictos.**
- Push `68bb47c..5a65335`. El plan de E4 (`57aacce`) entró a `version-2` después.
- **`af3acde` sacó de `rojos-declarados.txt` la línea del pipeline**
  `test_ningun_asset_quedo_agujereado_por_dentro`, que pasaba 1/1 desde E8. El relevo 3 no había
  podido porque el clasificador bloqueaba `sed`; esta vez fue con Edit y no lo bloqueó.

### Lo que hay que saber de cada tarea (y no se ve en el diff)

- **E1 T3.** `debugSetMaxTier` ya no baja la frontera: el único mutador sólo la sube. Los tests de
  EconomyKit con `@testable` siguen escribiendo `maxTierReached` directo. La salida del
  `pacing-sim` con el mutador nuevo no se miró: el brief la deja para T16.
- **E1 T4.** Un solo salto de schema, de 5 a 6.
  - `migrateV5toV6` fija al veterano: seis pestañas y la reconstrucción del ORO pendiente.
  - El test `everyEntryPointArrivesAsAVeteran` traba la cadena v1…v5 → v6, y
    `v5MigrationLosesNothing` compara el estado entero.
  - `oro` sigue `public var`. `spendOro` es la salida por convención; un `earnOro` sería de E9.
- **E11 T1.** La app le pasa `Calendar.current` al planificador, así que no hay test con un huso
  con horario de verano. `disabledKinds` se guarda por `rawValue` porque `NotificationKind` no es
  `Codable`.
- **E11 T2.** `GameContentLoader` llama a `validate()`, y lo prueba un test extra,
  `loaderRejectsAnUnknownKind`. El catálogo salió canónico (+102/−0).
- **E3a T1.** Ida y vuelta byte a byte sobre `Localizable` (560 claves) e `InfoPlist`. Las ramas de
  contenedor vacío (`[\n\n]`, `{\n\n}`) no están verificadas contra Xcode: hay 0 en los dos
  catálogos reales y los snapshots sólo suman entradas es/en. Hay que revisarlas si un catálogo
  llega a tener un contenedor vacío.
- **E3a T3.** El golden de iPhone es el `BoardScene.layoutBoard` de hoy: 2 filas, celda
  `(w − 32) / 5`, x 16 y multitud al 0,44. "iPhone igual a la v1" vale sólo con capacidad 10; con
  6 o menos, la celda choca contra el tope de 112 (hoy no hay piso así). `crowdTopRatio(rows: 3)`
  quedó en 0,70 y S5 lo baja (§3).

Los menores diferidos, uno por uno, están en los ledgers de cada épica
(`version-2/.superpowers/sdd/<plan>/progress.md`). Los que un despacho tiene que arrastrar:

| Desde | Hacia | Qué |
|---|---|---|
| E1 T1 | E1 T8 | `.inactive` sella `lastSeenTimestamp` mientras el `SKView` puede seguir tickeando (paga doble ahora que se acredita desde 2 s), y `.background → .inactive → .active` puede acreditar ~0 al volver en caliente. Verificar con el log `offline earnings credited … after … s` |
| E1 T4 | el primer consumidor de `revealedTier` | `raiseFrontier` no toca `revealedTier`: los fixtures que suben la frontera (`veteranState`, los arranques `--uitest*`) dejan lo revelado por debajo. Regla: "los fixtures que suben la frontera marcan lo revelado" |
| E11 T2 | E11 T3 | `NotificationsManager.swift:218-219` todavía lee `notif.daily.*`; T3 las saca del manager y del catálogo |
| E11 T2 | E11 T4 | faltan `settings.notifications.{vault_full,daily_ready,comeback}` y su familia en el test de completitud, o las filas de Ajustes muestran la clave cruda; los comentarios de `NotificationCopy.swift:121-128` tienen que quedar ciertos |
| E3a T3 | E3a T10 | `BoardScene.horizontalInset` (:152) y `BoardScene.crowdTopRatio` (:171) duplican constantes de `PlayLayout`: se borran al adoptarlo |

## 2. Los números del oráculo

`rapido` sobre `5a65335`, con las tres épicas integradas: **VERDE.**

| Suite | `68bb47c` (fin del relevo 3) | **`5a65335`** | De dónde sale la diferencia |
|---|---:|---:|---|
| EconomyKit | 274 | **317** | +5 E1 T3 · +14 E1 T4 · +24 E11 T1 |
| unit (26.5) | 574 + 1 declarado | **593 + 1 declarado** | +1 E1 T3 · +7 E1 T4 · +4 E11 T2 · +7 E3a T3 |

- **Las dos cuentas cierran exacto** con lo que reportó cada agente: ningún test se perdió ni se
  duplicó en los merges.
- Build 75 s, unit 497 s.
- **No se corrió un `completo`** en este relevo. La última línea de base completa sigue siendo la
  de `6b5e408` (HANDOFF §6), así que la UI, Store, el pipeline, el `pacing-sim` y Release no se
  midieron con la frontera nueva ni con el save v6.
- `rojos-declarados.txt` quedó con un solo rojo, `unit theOwnersTargetsAreMet`. **El pipeline ya
  no tiene rojo declarado.**

## 3. Lo que midieron los spikes de E3a, y qué tareas cambian

Los corrió un agente opus sobre `68bb47c`, sin commits. Usó un solo build con las variantes detrás
de flags `--spike-*` y un simulador por vez, borrado al terminar. La carga estuvo entre 145 y 280.
El reporte entero está en `version-2/.superpowers/sdd/2026-10-07-v2-e3a-ux-nucleo/task-2-report.md`.
Las capturas, los logs y el código del spike están en `version-2/build/spikes-e3a/`.

### S1, las hojas en iPad: **NO** con `.presentationSizing(.page)` → cambia la Task 6

| Dispositivo | Ancho | ¿Transparente? |
|---|---:|---|
| iPad Pro 13" · 26.5 | 936 | **No**: el popup flota sobre una página opaca gris |
| iPad mini · 26.5 | 744 | **No**: página opaca de ancho completo |
| iPad Pro 13" · 18.6 | 704 | Sí |
| iPad mini · 18.6 | 744 | Sí, pero queda como hoja de iPhone: el juego se achica como tarjeta y aparece la barra de estado |

- Los cuatro dan ≥ 640 pt, pero fallan 3 de 4 en transparencia y velo.
- No son los detents: sin `.presentationDetents` da la misma página opaca.
- **El plan B anda en los cuatro**: `fullScreenCover` + `.presentationBackground(.clear)` + velo
  0,35 + panel de 640, **con `.statusBarHidden(true)` adentro del cover**. Sin eso, la barra de
  estado vuelve mientras el cover está arriba, y el HUD de atrás baja 32 pt en 26.5 y 24 pt en
  18.6.
- En iPhone queda igual que hoy, con `.page` o sin él: **0,000 % de píxeles distintos**.
- No se probó `.presentationSizing(.form)`.

### S4, las safe areas: **NO** con la sonda de la Task 4 → cambia la Task 4

Valores reales con la barra oculta:

| Dispositivo (26.5) | top / bottom |
|---|---|
| iPhone SE 3 | 0 / 0 |
| iPhone 16 Pro | 62 / 34 |
| iPad mini y Pro 13" | 0 / 25 (no los ≈ 24/20 que suponía el plan) |

- **La sonda de la Task 4 queda pegada en 20 (SE) o 32 (iPad) en 5 de 9 arranques.** La barra se
  oculta después de `didMoveToWindow`, y a una vista que vive adentro de la safe area no le llega
  ni `safeAreaInsetsDidChange` ni `layoutSubviews`. El HUD queda 12 pt más arriba, contra el
  bezel.
- **Una `UIView` agregada directo a la ventana acertó 9 de 9.** Publica sincrónico, sin `Task`, y
  dio 0 avisos de "Modifying state" en más de 30 arranques. En iPhone hace ≤ 2 publicaciones por
  arranque; en iPad, hasta 3, todas en el arranque.
- El cambio: la sonda sigue de fondo del HUD, pero sólo instala ese centinela, que es el que
  publica.
- **Probablemente el `onAppear` de producción tenga la misma carrera**, porque lee en el mismo
  momento. No se midió sobre la base.
- Recomendado: un test de UI en el SE que pinee `hud.coins.minY ≥ 14` en varios arranques. Hoy
  `HUDRedesignUITests` pasaría o fallaría según la carrera.

### S5, 15 lugares en tres filas: **NO** con 0,70; el techo medido es **0,63** → cambia la Task 3 (ya integrada) y la Task 10

| Dispositivo | Cabezas de atrás al 0,70 | Ratio máximo sin tapar el display |
|---|---|---:|
| iPhone SE 3 | 42 pt adentro del display | **0,637** |
| iPhone 16 Pro | 38,5 pt adentro | 0,656 |
| iPhone 16 Pro Max | 25,8 pt adentro | 0,673 |
| iPad Pro 13" | sin cruce | — |

- Manda el SE. Con 0,63, la cabeza más alta queda 4,5 pt bajo el display en el SE y 22,6 pt en el
  16 Pro.
- El techo se tomó en el tope de la caja del sprite: el aire transparente de arriba va del 2,3 %
  al 8,9 % del lado en los 43 sprites `*_idle@2x`.
- **Fix pendiente**: `PlayLayout.crowdTopRatio(rows: 3)` de 0,70 a 0,63, junto con
  `crowdHeightFollowsTheRows`. Es una tarea chica sobre `v2/e3-ux`.
- **La columna izquierda de E7b pisa la multitud en todo iPhone.** Tapa entre 15 y 56 pt de la
  primera columna de personajes en toda su altura. En el iPad 13" no, porque los sprites van de
  x 210 a 814.
- Tampoco hay lugar para subir la columna por encima de la franja: en el SE el display termina en
  135 y las cabezas empiezan en 139,5. **El supuesto del plan ("las columnas van por encima de la
  franja") no se cumple**: 🔒 dueño (§5).

### S6, la botonera sobre el tablero: **SÍ** con el gesto, con botones de 30 pt → cambia la Task 8

- **El gesto anda.**
  - Un arrastre que arranca a 10 pt del display cambia de piso como hoy.
  - Uno que arranca sobre el display no cambia de piso ni le llega un toque a la escena.
  - Tocar el display abre la persiana, y se recoge sola a los 3 s.
- **El tamaño.** Con botones de 34 pt, la grilla abierta llega al **52,3 %** del alto del SE. Con
  **30 pt**, al **49,3 %**. En el 16 Pro, 34 pt dan 45,7 % y 30 pt, ~43 %.
- En el SE la grilla abierta tapa las dos filas de atrás mientras está desplegada, con cualquier
  tamaño. Es transitorio.
- En DEBUG, la llave inglesa (`RootView.debugButton`) cae encima del display. Conviene correrla en
  la Task 8 para que no ensucie las capturas.

### E3a, tarea por tarea

| Tarea | Estado |
|---|---|
| T1 — El catálogo canónico con snapshots | ✅ `f542b16` |
| T2 — Spikes S1, S4, S5, S6 | ✅ sin commit |
| T3 — `PlayLayout` | ✅ `f03950c`; falta el fix 0,70 → 0,63 (S5) |
| T4 — `ScreenInsets` y `PlayColumn` | pendiente; **cambia por S4** (centinela en la ventana) |
| T5 — Universal: iPhone y iPad vertical, iOS 18 | pendiente |
| T6 — Hojas y popups en iPad (`fisuSheet()`) | pendiente; **cambia por S1** (`fullScreenCover` + `.statusBarHidden(true)`) |
| T7 — La barra de abajo más baja | pendiente |
| T8 — La botonera del ascensor | pendiente; **cambia por S6** (botones de 30 pt) |
| T9 — Las pestañas de a poco | pendiente |
| T10 — La escena con `PlayLayout` | pendiente; **cambia por S5** (0,63) y por lo arrastrado de T3 |
| T11 — La raíz y las seis hojas con `fisuSheet` | pendiente |
| T12 — Cierre | pendiente |

## 4. El estado por épica

### E1

| Tarea | Ola | Estado |
|---|---|---|
| T1 — Offline | A | ✅ `3693044` |
| T2 — La Milanesa del JSON | A | ✅ `37c565f` |
| T3 — Un solo mutador de la frontera, contadores `Double`, la contratación gratis que no cuenta | B | ✅ `111bbfb` |
| T4 — Save v6 | B | ✅ `76a69c1` |
| T5 — Nunca más pisar un save ilegible | C | pendiente |
| T6 — El ORO comprado en la v1 desde `Transaction.all` | C | pendiente |
| T7 — El embudo `BoardChange` en EconomyKit | C | pendiente |
| T8 — El ciclo de vida: sellar sólo al irse | D | pendiente; lleva lo arrastrado de T1 |
| T9 a T16 | E a H | pendientes |

### E11

| Tarea | Estado |
|---|---|
| T1 — El catálogo y el planificador, puros | ✅ `508a4c5` |
| T2 — `notifications.json` validado y sus textos | ✅ `9c5847c` |
| T3 — El manager de la 2.0 | pendiente; **es lo que queda de la ola B**. El brief ya está generado (`task-3-brief.md`, 902 líneas) |
| T4 — Ajustes | pendiente; lleva lo arrastrado de T2 |
| T5 — La tarjeta del permiso en el popup offline | pendiente |
| T6 — El cableado al ciclo de vida | pendiente; después de E1 T8 |
| T7 — Cierre | pendiente |

## 5. Para el dueño

### 🔒 Nuevos

1. **`SaveConflictResolver.swift:68`**, de E1 T4. Lo pidió el plan, y queda latente mientras
   `cloudKitEnabled` sea `false`.
   - **El problema**: el `||` sobre `purchasedOroReconstructed` hace que una instalación nueva
     (`true`, 0 comprado) contra un veterano migrado de v5 (`false`) deje el flag en `true`. Con
     eso, la reconstrucción del ORO comprado nunca corre, y el `min(saldo, comprado)` de E9 le
     borraría ORO pagado al veterano.
   - **Hay que decidirlo antes de E9 o antes de prender CloudKit.** Dos salidas: que gane el lado
     pendiente (sirve si la reconstrucción es un `max` idempotente), o que el flag viaje con el
     ganador.
2. **La columna izquierda de E7b pisa la multitud en todo iPhone** (S5). Hay tres salidas:
   - se corre la columna;
   - `PlayLayout` reserva un margen, lo que achica el tablero (≥ ~22 pt en el SE) y deja de valer
     el golden de iPhone;
   - los personajes dejan de deambular debajo de la columna.

   Default del plan: E7b agrega el margen a `PlayLayout`.

### Dudas con default (no frenan)

- Las 14 del plan de E2a y las 26 de E4a/E4b, al final de cada plan.

### Siguen abiertos del relevo anterior

- `rentista_soles`: no borrar el worktree `v2-e8-pipeline`.
- Las 8 dudas de E11 y las 6 de E3.
- El piloto de arte y los gates de E10.
- Las rutinas `fisu-v2-relevo-a/-b`: crearlas pide el OK del dueño.

## 6. Los planes nuevos

### E2a, las mecánicas de economía (`6be4f99`, 15 tareas)

- **Todo detrás de perillas con default v1**: reintegro al fusionar, amortiguador del salto de
  precio, pisos en marcha y piso móvil para reencarnar.
  - El juego no cambia de precios hasta que E2b calibre.
  - El dueño las prueba desde el panel de debug (T14), que persiste.
- **Lo único que sí cambia el juego en E2a son los premios en minutos de producción** (T7, T11,
  T12). Son la tabla del dueño, no perillas, y no tocan el simulador.
- Corre en las olas F a H y después. T1–T6 son de EconomyKit (T3 y T4 con un toque mínimo en la
  app). T9, T11 y T12 tocan calientes y van después de E1 T14/T15.
- Cada tarea tiene un "Step 0" con el `grep` que comprueba que existen las APIs de E1 que consume.

Las contradicciones que importan para despachar:

- **`applyTap` suma `tiers:`** (E2a T4) y **`registerHire` suma `cushion:`** (E2a T3). Las tareas
  de E1 están escritas contra las firmas viejas; la fila `.tapMultiplier` de `EffectContractTests`
  (E1 T15) tiene que pasar `tiers:`.
- **La capacidad 15.** El plan de E3a supone que la cambia E2a; PLAN-v2 la pone "detrás de knob,
  calibrado en E2b". Default: la pasa E2b.
- **`freeHire` y `eventImmunity` nacen en E2a T12**, aunque los cimientos de E4 los listan como
  suyos: los crea la épica que llegue primero.
- **`RewardScale.coinPayout` (E2a) y `RewardMath.coinPayout` (E4) son el mismo concepto con dos
  nombres** en PLAN-v2.
- **`rewardTier = min(tier del piso máximo, frontera + 3)`, leído literal, queda por debajo de la
  frontera** adentro del mismo piso. Se implementa `min(rewardTier v1, frontera + 3)`.
- **El simulador no pasaba por `canReincarnate`**, así que el piso móvil no habría valido para el
  bot. T5 lo enchufa.
- **El día 7 sin special paga `passiveUnlockCost × 6.0` escrito en código**
  (`ContentSystems.swift:423`). T11 lo pasa a `minutes: 15` en el JSON.
- **Las métricas `floorUnlockHireSeconds` y `peakHire` del simulador cotizan con
  `config.hireCost` pelado.** Con el amortiguador prendido miden el precio de catálogo, no el
  cobrado. Queda anotado para E2b.

El reporte del plan enumera 12 contradicciones entre PLAN-v2, el código y los otros planes:
`version-2/.superpowers/sdd/2026-10-07-v2-e2a-mecanicas/plan-report.md`.

### E4, visitantes y eventos v2, en dos planes (`57aacce`)

- **Por qué se partió.** Son 20 tareas. E4a es casi todo EconomyKit y JSON, con un solo toque
  caliente grande (T9, la mudanza a `events.json` schema 2, sola en su ola). E4b es la escena, la
  UI y el Álbum: los calientes `BoardScene`, `RootView` y `GameState`. E4b arranca con E4a
  cerrada.
- **E4a T9 necesita E1 cerrada.** E4b T1 va después de E1 T10 y de E3a T10.
- **E4 ∥ E5 por tarea**: E4b no comparte ola con una tarea de E5 que toque `GameState.swift`,
  `BoardScene.swift` o `RootView.swift`.

Las contradicciones que importan para despachar (de 20, en
`version-2/.superpowers/sdd/2026-10-07-v2-e4a-visitantes-eventos/plan-report.md`):

- **E3a T10 modifica `renderAnchoredSpecials` y suma un test que E4b T9 borra.** Es trabajo que se
  tira: si se puede, E3a T10 saltea los especiales.
- **La plata de los visitantes del Anexo A rompe el 12 % de `RewardBudgetTests`** (el guard que
  crea E2a T11). Default: Anexo tal cual, con la palanca `coinsSecondsScale` para E2b.
- **El Arbolito cambia 1 ORO por S(5400), ~135× peor que el ancla de la tienda.** Default: Anexo
  tal cual.
- **El Anexo A dice 24 guiones y su tabla tiene 26.** El plan implementa los 26.
- **El reloj de eventos v1 es de pared y en memoria** (`nextEventAt`): se reinicia en cada
  arranque. E4a lo pasa a juego activo y al save, con el primero a los 15 min.
- **`isCalmMoment`, `ActiveBonus.Icon.face` y `HireQuote.listCost` no existen**, y `coinReward` es
  `private static` (depende de E1 T14).
- **El manifest no tiene sección `npcs`**, aunque `process_dropbox.py` manda `npc_*` a
  `npcs.atlas`. E4b T1 la suma como opcional.
- **`loops_manifest.json` está vacío y nada lo lee en Swift**: E4b T3 crea el lado Swift del
  contrato de E8.

## 7. Trampas nuevas

### A. Después del primer `EnterWorktree` del controlador, el guard se pone estricto

La sesión queda "aislada" en ese worktree, y el guard empieza a rechazar lo que antes pasaba:

- los comandos compuestos con git;
- cualquier comando cuyo nombre sale de una variable. Por ejemplo, `$S/scripts/review-package …`
  da "command whose name is computed at runtime".

Antes del primer `EnterWorktree`, los compuestos andaban. **Arreglo: rutas literales y un comando
por llamada.**

### B. Integrar sin worktree

Si la rama de la épica no está checkouteada en ningún lado y el commit del agente desciende de su
punta, este par es un fast-forward que no toca archivos:

```bash
git merge-base --is-ancestor <rama> <commit>
git branch -f <rama> <commit>
```

Un cherry-pick sí necesita un worktree de la épica (`git worktree add`). Por eso existe
`.claude/worktrees/v2-e3`.

### C. Un cherry-pick no siempre pide otro `rapido`

Hay que mirar `git diff --stat <commit del agente> <cherry-pick>`. Si sólo muestra archivos que no
son Swift (en E3a T3, los `.py` de la T1), el árbol Swift es el que el agente probó y su `rapido`
vale. El `rapido` de fin de ola lo re-verifica.

### D. La carga

- Con 3 agentes compilando más los revisores, el `load average` llegó a **~770** (en el relevo 3,
  ~600).
- La corrida enfocada de E3a T3 tardó **~11 min**.
- Otra vez, sin rojos espurios.

### E. Un agente puede notificar dos veces

Un agente que termina con trabajo de fondo propio vuelve a notificar con el mismo reporte. No es
un error, y no hay que integrar dos veces.

## 8. El mecanismo que funcionó (mantenerlo)

- **Un protocolo común de agentes en un archivo**:
  `version-2/.superpowers/sdd/v2-agente-protocolo.md`, con el paso 0, el guard, la tabla de
  calientes de la ola, los commits y el reporte.
  - Con eso, los despachos quedan en ~15 líneas.
  - **La tabla de calientes hay que actualizarla en cada ola.**
- **Los revisores reciben el template del skill por ruta**, no pegado: "leé el template y seguilo
  con estos valores".
- **Los reportes de los agentes se copian al workspace de su plan**
  (`version-2/.superpowers/sdd/<plan>/task-N-report.md`). Así sobreviven al borrado del worktree
  del agente.

Limpieza: se borraron los 5 worktrees de agentes del relevo 3 con sus ramas, después de comprobar
que `git cherry version-2 <rama>` daba limpio en los 5.

## 9. Qué sigue (relevo 5)

1. **E11 T3**, con BASE en la punta de `v2/e11-notificaciones` (`9c5847c`). El brief ya está
   generado; hay que arrastrarle las líneas de T2.
2. **E1, ola C**: T5 ∥ T6 ∥ T7, con BASE en la punta de la épica. Lo de T1 se arrastra a T8, y lo
   de `revealedTier` al primer consumidor.
3. **E3a**:
   - primero, el fix chico de `crowdTopRatio` (0,63);
   - después, la ola 2 fría: T4 ∥ T5;
   - los despachos de T4, T6, T8 y T10 llevan las líneas de §3, porque el plan todavía dice lo
     viejo.
4. **Planes**: E5 (ola D) y E6 (ola E).
5. **Al cerrar la ola**, un `completo`: el último es de `6b5e408`.
