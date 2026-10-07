# Sesión 2026-10-07 (relevo 5) — La ola C: el embudo `BoardChange`, el save ilegible que no se pisa, el ORO comprado de la v1, las safe areas observables y los planes de E5 y E6

Continúa `Docs/SESION-2026-10-07-v2-relevo-4-ola-b.md`.

Lo que un agente necesita saber sin leer el resto:

- **`version-2` en `bc3bf6f` tiene la ola C de E1 (T5, T6, T7) y el fix de E3a T3 + la T4.** El
  `rapido` de fin de ola de E1 sobre `cdd8f0a` da **VERDE, EK 357 · unit 608 + 1 declarado**.
- **El `rapido` sobre `bc3bf6f` da ROJO: EK 357 · unit 611 + 2.** El rojo nuevo es
  `PersistenceTests.rotatesTheLastTenGoodLoads` (9 copias contra 10): `SaveBackupStore` nombra las
  copias por milisegundo, y dos cargas en el mismo milisegundo pisan la misma (§2, trampa I). Es
  de E1 T5, no del merge de E3a: en `cdd8f0a` pasó por suerte de timing. La cuenta cierra (611 +
  2 = 612 + 1): no se perdió ningún test.
- **Se despachó E1 T5b con BASE `bc3bf6f`** para arreglarlo en el producto, y **`bc3bf6f` no se
  pushea hasta que T5b esté verde**. `rapido` post-T5b: **(pendiente)**.
- **El `completo` VERDE de este relevo es sobre `d22eb7a`, o sea ANTES de la ola C.** Es la
  referencia `completo` nueva (la primera que mide la frontera de un solo mutador y el save v6),
  pero **nada de la ola C pasó todavía por UI, Store, `pacing-sim` ni Release dentro de un
  `completo`**. Es lo primero del relevo 6 (§8).
- Hay dos seguimientos chicos, **T5b** (en vuelo) y **T6b** (§1), y un insumo nuevo para el 🔒 de
  `SaveConflictResolver.swift:67/:68` (§3).
- Salieron los planes de **E5** (E5a + E5b) y **E6** (E6a + E6b) (§4).

## Cómo arrancó

- Relevo 5 del run AVO, desde las 07:39. Lo despertó el dueño escribiendo "continua", en sesión
  nueva: **es la cuarta vez sin un despertar por cron observado**.
- Contexto al arrancar: 119k. Cuota: 5 h al 1 %, semanal al 16 %.
- **Antes de despachar, las dos ramas de épica se adelantaron por fast-forward a la punta de
  `version-2` (`d22eb7a`)**: `v2/e1-correcciones` (desde `76a69c1`) y `v2/e3-ux` (desde
  `f03950c`). Motivo: así E1 T5 escribe sus strings sobre el catálogo que ya tiene las claves de
  E11 T2, y todas las tareas tienen `Tools/v2/catalogo.py`. **Todas las tareas de la ola salieron
  de BASE `d22eb7a`.**

## 1. Qué entró en la ola C

| Épica | Tarea | Commit (agente → rama de la épica) | Revisión (opus) | Números del agente |
|---|---|---|---|---|
| E1 | T7: el embudo `BoardChange` en EconomyKit, planear y aplicar (`evolveUnit`, `placeUnit`, `land` extraído de `applyMerge`) | `ec6fb29` (ff) | spec ✅, 0 críticos o importantes, 3 menores | `BoardChangeTests` 40 · EK 357 · unit 593 + 1 |
| E1 | T5: nunca más pisar un save ilegible (`SaveLoadResult`, `SaveBackupStore`, fase `.recovery`, `SaveRecoveryView`, 8 claves `recovery.*`) | `7b98a78` → cherry-pick `38bee13` | código ✅, 0 críticos; el único importante era el paso 6 (`completo` + captura en el SE), que quedó para después (§2) | unit 599 + 1 · `SaveRecoveryUITests` PASSED (16 Pro, 26.5) |
| E1 | T6: el ORO comprado en la v1, reconstruido desde `Transaction.all` (`PurchasedOroHistory`, `SKIncludeConsumableInAppPurchaseHistory`) | `3aeddd6` → cherry-pick `cdd8f0a` | spec ✅, 0 críticos o importantes, 5 menores | unit 602 + 1 · store-unit (18.6) 13/13 |
| E3a | fix de T3: `crowdTopRatio(rows: 3)` 0,70 → **0,63** (spike S5) | `5afb893` (ff) | spec ✅, 0 críticos o importantes, 5 menores entre los dos | `PlayLayoutTests` 7 |
| E3a | T4: `ScreenInsets` y `PlayColumn`, **con el centinela en la ventana** (spike S4), y `ScreenInsetsUITests` | `b988bc3`, `537f923` (ff) | (la misma) | unit 597 + 1 · SE: 3/3 a 19,5 pt |
| E5 | plan, partido en E5a (motor, 9 tareas) y E5b (lo que se ve, 7) | `da86b16` (ff en `version-2`) | — | 14 contradicciones, dudas con default |
| E6 | plan, partido en E6a (tienda de ORO, packs y ofertas, 13) y E6b (lugares extra, pintas, efectos y familias, 10; 3 con gates) | `f2745fa` → cherry-pick `1e3cd6b` | — | 15 contradicciones, dudas con default |

Implementadores sonnet; revisores y planificadores opus. Ningún commit de la ola lleva
`Co-Authored-By` (verificado con `git log --format='%(trailers:key=Co-Authored-By)'
d22eb7a..bc3bf6f`).

### La integración

- **E1, en la rama de la épica, en orden de llegada**: T7 por fast-forward (`ec6fb29`), T5 por
  cherry-pick (`38bee13`; el diff contra el commit del agente son sólo los archivos de EK de T7)
  y T6 por cherry-pick (`cdd8f0a`). El árbol combinado no corrió hasta el `rapido` de fin de ola:
  **VERDE sobre `cdd8f0a`, EK 357 · unit 608 + 1 declarado**, exacto (593 + 6 de T5 + 9 de T6).
- **El merge a `version-2` esperó al `completo` que corría en ese worktree**: un merge le cambia
  las fuentes Swift a un oráculo en curso. Después, `--no-ff` → `cd23856` (árbol Swift igual a
  `cdd8f0a`, así que el `rapido` vale), push `d22eb7a..cd23856`.
- **E3a**: un solo agente hizo el fix de T3 y la T4 desde `d22eb7a`; `v2/e3-ux` avanzó por ff a
  `537f923` y entró a `version-2` con `--no-ff` → `bc3bf6f`.
- Los planes de E5 y E6 entraron a `version-2` antes que los merges de código (`da86b16`,
  `1e3cd6b`).

### Lo que hay que saber de cada tarea (y no se ve en el diff)

**E1 T7, `BoardChange`.**

- **Desempate determinista.** `planAutoMerge` ordenaba los pares sobre un
  `Dictionary(grouping:)`, cuyo orden cambia entre procesos: dos pares del mismo tier daban un
  plan distinto por corrida. Ahora desempatan por (tier desc, piso, `typeId`), y `planEvolve` por
  (tier desc, piso, slot). Aceptado: E3b usa el mismo comparador. Lo pinea
  `autoMergeTieBreaksByTypeId`.
- **`BoardChange.merge` cuenta en `totalMergesEver`**, porque pasa por `applyMerge`. Lo manda el
  brief y es lo que ya hace hoy el video de fusión instantánea (`performInstantMerge`). Si las
  fusiones de origen `career` o `debug` deben contar es una **pregunta de producto** abierta.
  `evolveUnit` no cuenta como fusión.
- **`planEvolve` ahora cae a la siguiente unidad** si la mejor no puede crecer. Antes, "Startup
  comprada" devolvía `nil` y el evento no hacía nada; ahora casi siempre se aplica.
- **El aplicador no compara `typeId`**: aplicar un cambio vencido sin revalidar mutaría lo que
  haya en el slot. T10 revalida antes de aplicar, así que va como arrastre (abajo).
- **`revealedTier` todavía no lo escribe nadie en producción** (`markRevealed` nace en T9/T10):
  todo llamador de `raiseFrontier` lo deja atrás. Los tests de T7 lo fijan explícito, y un test
  por mutación prueba que `revealsSomethingNew` lee `revealedTier` y no la frontera (cambiado a
  `maxTierReached`, falla exactamente ese test).

**E1 T5, el save ilegible.**

- `PlayerStateRepository.load()` devuelve `SaveLoadResult` (`empty | loaded | unreadable`): un
  save que existe y no decodifica ya no se confunde con "no hay save".
- `SaveBackupStore` vive en `Application Support/SaveBackups/` y guarda tres cosas: las últimas
  10 cargas buenas (`save-<ms>.json`), la copia premigración una sola vez
  (`save_v<N>_premigration.json`) y cada payload ilegible (`unreadable-<ms>.json`).
- `bootstrap()` quedó partido en tres. El tramo `finishBootstrap` es el bloque de siempre movido:
  **la revisión lo comparó byte a byte, 163 líneas idénticas**. Ningún camino de escritura queda
  sin guard en `.recovery` (`persistNow` lo chequea).
- **Cambio de conducta**: tienda, Game Center y anuncios arrancan en `startServices()`, sólo con
  `phase == .ready` y una vez. **`.failed` (contenido roto) ya no los arranca**; antes arrancaban
  con `player == nil`.
- "Reintentar" re-corre el `bootstrap()` entero. Con el fixture `--uitest-unreadable-save`, que
  planta un save truncado en CoreData y en el snapshot, el fixture lo vuelve a plantar: por eso el
  UI test ve la pantalla otra vez después de reintentar.
- Las 8 claves `recovery.*` entraron por `catalogo.py aplicar`: el diff del catálogo son sólo las
  136 líneas de las claves.

**Seguimiento T5b** (chico, mismos archivos que T5). **Ya despachado** al cierre del relevo, con
BASE `bc3bf6f`, porque arregla el rojo del `rapido` (§2):

0. Los nombres de las copias en el producto: ninguna copia pisa a otra. Y el test sin reloj.
1. Guardar **cada** payload ilegible distinto. Hoy, con CoreData y snapshot ilegibles y
   distintos, se guarda uno (`unreadable ?? payload`) y "Empezar de nuevo" pisa el otro sin
   copia, aunque la pantalla promete que "la copia queda guardada".
2. Si `backupURL` es nil, copiar el snapshot crudo antes de guardar.
3. No apilar copias idénticas al reintentar con un save que sigue roto.

Lo que el despacho de T5b no nombra: la captura de `SaveRecoveryView` en el SE para el dueño
(paso 6 de T5, contra FisuJobs). Va con el próximo `completo` (§8).

**E1 T6, el ORO comprado en la v1.**

- **StoreKit Testing de 18.6 SÍ lista el consumible ya terminado en `Transaction.all`**, con la
  clave puesta (`[store] purchased ORO reconstructed from 1 transactions`). No hizo falta
  declarar un rojo. No se verificó por mutación que la clave haga falta en 18.6; en un dispositivo
  iOS 18+ es lo que habilita el historial (documentación de Apple).
- Los montos de la v1 (250 / 750 / 2000) se verificaron contra el tag `v1.0.0-build4`. Son una
  foto: no siguen a `products.json`, y E6a T9 la pinea.
- Cuenta sólo transacciones verificadas, no revocadas y que estén en `creditedPurchases`. La
  reconstrucción corre en `StoreManager.start`, antes de `loadProducts()` y del listener, así que
  no hay compra posible antes de que termine. **La revisión no encontró camino que cuente una
  compra dos veces.**
- Falla = 0 y cerrado: no se reintenta. **En iOS 17 cierra en 0 para siempre** (no lista
  consumibles terminados): depende de que E3a T5 suba el mínimo a 18.

**Seguimiento T6b** (chico, `StoreManager.swift`):

1. **En DEBUG, `startLocalStoreIfNeeded()` ANTES de reconstruir.** Hoy, una build DEBUG
   instalada por `simctl` en un runtime < 26 lee `Transaction.all` sin la `SKTestSession` y
   cierra en 0. **Es justo la prueba manual v1 → v2 del dueño** (§6, trampa E).
2. Un plazo sobre `Transaction.all` que cuente como "falló → 0 y cerrar" (la misma carrera que
   `fetchWithDeadline`).
3. Una bandera `isStarted` puesta antes del `await` (re-entrada de `start`).
4. Loguear el total, con privacidad `.public`.

**E3a, fix de T3 y T4.**

- `ScreenInsets` publica los insets desde un **`WindowSentinel`**: una `UIView` agregada una sola
  vez a la ventana (`viewWithTag`), que publica sincrónico desde `safeAreaInsetsDidChange` y al
  instalarse. El HUD, `GameTabBar` y las tarjetas del tutorial leen de ahí; se fueron las lecturas
  en `onAppear`.
- El centinela es más chico que el del spike: sin `layoutSubviews`, porque los logs de S4
  muestran que toda publicación real vino de `safeAreaInsetsDidChange`.
- **La carrera del `onAppear` de producción, que el relevo 4 daba como "probable, no medida",
  quedó medida**: sobre el código de BASE, `ScreenInsetsUITests` falla en el SE con el arranque 2
  a **7,5 pt** de `hud.coins`; con el arreglo, 3/3 a **19,5 pt**. En el mismo SE,
  `HUDRedesignUITests` 3/3 y `TutorialUITests` 9/9.
- En iPhone el layout queda idéntico por análisis (`PlayColumn` de 592 no entra en juego). La
  confirmación en el 16 Pro llega con el próximo `completo`.
- **Hueco del oráculo**: `ScreenInsetsUITests` sólo discrimina en el SE (y en iPad cuando la app
  sea universal). La matriz UI del oráculo es sólo 16 Pro, y el `se-ui` de E3a T12 sólo corre
  `LocalizationLayoutUITests`. Además, el RED es probabilístico: con 3 arranques, ~6 % de falso
  verde sobre el código viejo; con 5, ~1 %.
- Menores: el comentario de `PlayLayout.swift:58` contradice la línea siguiente, y `:61` nombra
  el display del ascensor, que todavía no existe (debería nombrar `ElevatorPanel`).

### Arrastres para los despachos

| Desde | Hacia | Qué |
|---|---|---|
| E1 T7 | E1 T10 | `BoardChangeApplier.apply` no compara el `typeId` del plan: un `guard` barato contra el tipo del slot lo blinda, aunque T10 revalide antes |
| E1 T7 | E1 T9 | `BoardChangeOutcome` tiene init interno: hacerlo público si los tests de T9 lo construyen |
| E1 T6 | E3a T5 | iOS 17 cierra la reconstrucción en 0 para siempre: es un motivo más para el mínimo 18 |
| E1 T6 | E9 (el reset) | un reembolso en la v2 no resta de `oroPurchasedLifetime` (la revocación sólo toca `purchasedProductIDs`): con `oro = min(saldo, comprado)`, el que reembolsó se queda ese ORO |
| E3a T4 | E3a T12 y T10 | sumar `ScreenInsetsUITests` al `se-ui` de T12 y al `ipad-ui` de T10, y subir a 5 arranques |
| E1 T1 | E1 T8 | sigue en pie desde el relevo 4: `.inactive` sella `lastSeenTimestamp` con el `SKView` tickeando |
| suite | — | subir `StoreManager.loadTimeout` en los tests con StoreKit real (trampa C) |

Los menores diferidos, uno por uno, están en los ledgers:
`version-2/.superpowers/sdd/2026-10-06-v2-e1-correcciones-criticas/progress.md` y
`…/2026-10-07-v2-e3a-ux-nucleo/progress.md`, con los briefs, reportes y paquetes de revisión.

## 2. Los números del oráculo

### `completo` sobre `d22eb7a` (= `5a65335` + docs): **VERDE**, la referencia nueva

| Suite | `6b5e408` (relevo 3) | **`d22eb7a`** |
|---|---:|---:|
| EconomyKit | 267 | **317** |
| unit (26.5) | 570 + 1 declarado | **593 + 1 declarado** |
| Store unit (18.6) | 12 | **12** |
| UI (26.5) | 57 | **57** (2.563 s) |
| `StoreUITests` (18.6) | 2 | **2** |
| pipeline | 49 / 0 | **49 / 0** |
| `pacing-sim` | Dios en 30,73 h activas · 13 reencarnaciones | **igual** |
| Release | 0 warnings | **0 warnings** |

- **La frontera de un solo mutador y el save v6 no movieron el pacing**: el `pacing-sim` da lo
  mismo que en `6b5e408`.
- Tiempos con la máquina cargada: 4.886 s en total (~81 min). Unit 503 s, store-unit 995 s, UI
  2.563 s, store-ui 499 s, Release 193 s. El build salió en 25 s porque el DerivedData estaba
  caliente.
- Log: `version-2/build/relevo5-completo-d22eb7a.log`.

### `rapido` de fin de ola

| Árbol | EK | unit | De dónde sale |
|---|---:|---:|---|
| `cdd8f0a` (E1 ola C) | **357** | **608 + 1** | +40 EK de T7 · unit +6 de T5 (`PersistenceTests` +2, `SaveRecoveryTests` 4) · +9 de T6 (`PurchasedOroHistoryTests`) |
| `bc3bf6f` (+ E3a) | **357** | **611 + 2** — **ROJO** | +4 de `ScreenInsetsTests`; el segundo rojo es `rotatesTheLastTenGoodLoads` |

- `cdd8f0a`: economykit 68 s, build 155 s, unit 977 s. Log:
  `v2-e1/build/relevo5-rapido-cdd8f0a.log`.
- `bc3bf6f`: economykit 22 s, build 56 s, **unit 374 s**. Log:
  `version-2/build/relevo5-rapido-bc3bf6f.log`; el detalle, en
  `version-2/build/oraculo/20261007-095823-rapido/unit.log`.

**El rojo de `bc3bf6f` es el menor que la revisión de T5 había dejado anotado.**

- `SaveBackupStore.rotate` nombra cada copia `save-<ms>.json`, y el test hace 12 cargas seguidas
  y exige 10 copias. Si dos cargas caen en el mismo milisegundo, la segunda pisa a la primera.
  Para quedar en 9 hacen falta al menos tres choques: el test entero tardó 27 ms, ~2 ms por carga.
- La revisión lo había medido 20/20 verde y lo dejó como menor: "si alguna vez falla, inyectar
  las fechas".
- **Pasó en los dos `rapido` anteriores, más lentos, y falló en éste**: unit 568 s (el `rapido`
  de T5) y 977 s (`cdd8f0a`) contra 374 s acá, 2,6 veces más rápido que `cdd8f0a`. Es la trampa I.
- **No lo causó el merge de E3a**: el test y el código son de E1 T5 y ya estaban en `cdd8f0a`.
- El arreglo va en el producto y no sólo en el test: T5b cambia los nombres para que ninguna copia
  pise a otra, y saca el reloj del test.

### Lo que el `completo` no midió todavía

El `completo` es de antes de la ola C. **Sobre `bc3bf6f` se espera**: UI **59** (57 +
`SaveRecoveryUITests` + `ScreenInsetsUITests`), Store unit **13** (+
`reconstructsTheV1OroFromTransactionHistory`), `StoreUITests` 2, y el `pacing-sim` igual
(`BoardChange` todavía no lo usa nadie fuera de sus tests). Un número distinto es un test perdido
o duplicado.

## 3. Para el dueño

### 🔒 `SaveConflictResolver.swift:67/:68` — hay insumo nuevo, y conviene decidir las dos líneas juntas

Es el 🔒 de E1 T4 (relevo 4, §5). Latente mientras `cloudKitEnabled` sea `false`; hay que
decidirlo antes de E9 o antes de prender CloudKit.

- **`:68`, el `||` sobre `purchasedOroReconstructed`.** Con la implementación de T6, el `||`
  sólo puede contar **de menos** en multi-dispositivo: si A ya reconstruyó y B no, B hereda `true`
  y el total de A, y las compras de la v1 hechas en B no se cuentan nunca. En el reset, el que
  pagó pierde ORO.
- **Un `&&` contaría doble**: `completePurchasedOroReconstruction` hace `+=` sobre el total
  existente, y el resolver no une `creditedPurchases` (conserva la del ganador). Reconstruir sobre
  un save que ya traía compras de la v2 contadas las suma otra vez.
- **`:67`, el `max` de `oroPurchasedLifetime`** (lo marcó el plan de E6): pierde compras hechas en
  dos dispositivos. 160 en uno y 550 en otro dan 550.
- **La exactitud pide otro diseño, no otro operador**: que la reconstrucción asigne en vez de
  sumar, y que el resolver una `creditedPurchases`.
- **E6 lo agrava en grado, no en clase**: con 3 packs y 3 ofertas hay más saves nuevos con el flag
  en `true` y más ORO comprado en juego.

### Sigue abierto

- **La columna izquierda de E7b pisa la multitud en todo iPhone** (relevo 4). E5 no depende de
  esto: sus accesos van como chips en `StageChips` y las cajas lejos de los bordes.
- **Pregunta de producto, sin candado**: ¿una fusión de origen `career` o `debug` cuenta en
  `totalMergesEver` (estadísticas y logros)? Hoy sí, igual que el video de fusión instantánea.

### Dudas con default (no frenan)

- E5a 12 y E5b 13; E6a 15 y E6b 9. Las que más pesan, en §4.
- **Tres gates de E6b**: la galería de los 8 efectos (el dueño mira las fotos), los 3 atlas de
  familias que entrega E8, y la medición de 4 filas en el SE (si el apiñado no entra, decide el
  dueño).
- Las 14 de E2a y las 26 de E4a/E4b, del relevo 4.

### Siguen abiertos del relevo anterior

- `rentista_soles`: no borrar el worktree `v2-e8-pipeline`.
- Las 8 dudas de E11 y las 6 de E3.
- El piloto de arte y los gates de E10.
- Las rutinas `fisu-v2-relevo-a/-b`: crearlas pide el OK del dueño.
- **La limpieza de los worktrees de agentes integrados es del dueño** (trampa A). Hay unos 20
  `agent-*` en `git worktree list`.

## 4. Los planes nuevos

### E5, el Paquete de la Aduana, El Colchón y la Ruleta (`da86b16`)

Partido como E3 y E4:

- **E5a, el motor** (`Docs/superpowers/plans/2026-10-07-v2-e5a-aduana-colchon-ruleta.md`): 9
  tareas (8 + cierre). **No toca ningún archivo caliente ni el catálogo.** T1 (el paquete puro:
  `WeightedDraw`, `PackageScheduler`, `PackageRoller`) puede ir ya; T2–T5 esperan a E4a T1/T3/T7
  y a E3b T9.
- **E5b, lo que se ve** (`…-e5b-aduana-colchon-ruleta.md`): 7 tareas (6 + cierre). T2 es la única
  con `GameState.swift` y `RootView.swift`, y T3 la única con `BoardScene.swift`: van en olas sin
  E4b T1/T3/T4/T6/T9. 48 strings, todas por snapshot.

Las contradicciones que importan para despachar (de 14, en
`version-2/.superpowers/sdd/2026-10-07-v2-e5-aduana-colchon-ruleta/plan-report.md`):

- **`placeGrantedUnit` no se generaliza**: es un `private` que muta el tablero en el acto y
  pierde el regalo con el piso lleno, y E1 T12 lo borra. El paquete llega por
  `planArrival(origin: .package)` en el turno del tablero.
- **`LootBoxGate` y `OddsDisclosureView` nacen en E5** (PLAN-v2 los ponía en E6), porque la
  ruleta y el colchón los necesitan antes. `LootBoxGate` lee `restrictedStorefronts` de E7a +
  `Storefront.current` y **falla cerrado**. Hasta hoy nadie leía `Storefront` en la app.
- **`RewardedPlacement.treasure` ya existe** (E7a): no hay que sumarlo.
- **El buzón de paquetes y el colchón van en `meta.engagement`**, no en `RunState`, para no subir
  a v7: sobreviven a la reencarnación.
- **La tabla de la ruleta la propone el plan**, porque PLAN-v2 no da pesos: plata 30/45/60 =
  18/12/8, ×2/×3/×5 = 14/8/3, ORO 1/3 = 15/5, Paquete 12, Cofre 5. Toca cumplimiento (Apple
  3.1.1) y economía.
- **El paquete gratis cada 2 min ≈ 30 empleados por hora** sin anuncios: es la fuente que más
  acorta el juego, y la calibra E2b.
- **E5 no usa la columna de E7b**: chips en `StageChips` y cajas en el borde de abajo, a ≥ 72 pt
  de cada costado.
- `.packageOpening` no se usa: la apertura es parte del turno `.boardCelebration` de E1.
  `PickupNode` lo crea E5b T3 (E4b no lo crea). `sfx_wheel_tick.caf` está en el bundle sin caso
  en `AudioManager.SFX`.

### E6, la tienda de ORO, los IAP y las skins (`1e3cd6b`)

- **E6a** (`Docs/superpowers/plans/2026-10-07-v2-e6a-tienda-ofertas.md`): 13 tareas. Tienda de
  ORO, packs 160/550/1.400 con los mismos IDs, ofertas de 24 h. Seis olas.
- **E6b** (`…-e6b-lugares-skins.md`): 10 tareas. Lugares extra, pintas con ORO, 8 efectos por
  shader y familias. **Código y arte separados**: T1 y T3–T7 se integran solos; T8 y T9 sólo
  editan `skins.json` y el catálogo, y esperan su gate (sin respuesta, el validador impide
  venderlas).
- **Se coordinó con E5 en vuelo**: el controlador le pasó al planificador de E6, por
  `SendMessage`, lo que E5 ya reclamaba. E6 consume `LootBoxGate`, `OddsDisclosureView`,
  `RewardCopy` y `PrizeOdds` con sus nombres exactos, y le devuelve a E5 los enchufes
  `bestSupplierLevel` y `effectiveWheel`.

Las contradicciones que importan (de 15, en
`version-2/.superpowers/sdd/2026-10-07-v2-e6-tienda-skins/plan-report.md`):

- **La capacidad vive en la tabla de pisos, no en `slots.count`**: el simulador y `StaffedFloors`
  no tienen torre. `FloorTable.expanded(by:)` reemplaza `content.floorTable` antes de rehacer la
  torre.
- **`extraSlots` son deltas +3/+2 sobre la base**: dan 13/15 con los 10 de hoy, y 18/20 recién
  cuando E2b suba la base a 15.
- **Las pintas de ORO no pueden ir a `meta.ownedSkins`**: es la caché de StoreKit, se reescribe y
  desequipa (`GameState+Store.swift:213-225`). Van a `engagement.shop.skins`.
- **Los pesos crudos del cofre (55/28/12/5) mienten** como probabilidades, porque
  `ChestRoller.roll` promociona y degrada. Se publican `effectiveOdds`, con un test contra 20.000
  sorteos.
- **Las 7 líneas a 348 son de E2b**, no de E6.
- **Bélgica y Australia**: la oferta de Bienvenida trae un cofre, así que también se apaga ahí.
  Y sin país conocido no se vende nada de azar (regla de E5a).
- **El giro extra con ORO queda sólo en la ruleta** (E5a T8), sin fila en la tienda.

## 5. El estado por épica

### E1

| Tarea | Ola | Estado |
|---|---|---|
| T1 — Offline | A | ✅ `3693044` |
| T2 — La Milanesa del JSON | A | ✅ `37c565f` |
| T3 — Un solo mutador de la frontera | B | ✅ `111bbfb` |
| T4 — Save v6 | B | ✅ `76a69c1` |
| T5 — Nunca más pisar un save ilegible | C | ✅ `38bee13`; T5b en vuelo (arregla el rojo del `rapido`) |
| T6 — El ORO comprado en la v1 desde `Transaction.all` | C | ✅ `cdd8f0a`; falta T6b |
| T7 — El embudo `BoardChange` en EconomyKit | C | ✅ `ec6fb29` |
| T8 — El ciclo de vida: sellar sólo al irse | D | pendiente; lleva lo arrastrado de T1 |
| T9 a T16 | E a H | pendientes; T9 y T10 llevan lo arrastrado de T7 |

### E3a

| Tarea | Estado |
|---|---|
| T1 — El catálogo canónico | ✅ `f542b16` |
| T2 — Spikes | ✅ sin commit |
| T3 — `PlayLayout` | ✅ `f03950c` + fix 0,63 `5afb893` |
| T4 — `ScreenInsets` y `PlayColumn` | ✅ `b988bc3` + `537f923` |
| T5 — Universal, iOS 18 | pendiente; **ya se puede**: hereda `Info.plist` de E1 T6, integrada |
| T6 — Hojas y popups en iPad | pendiente; cambia por S1 (`fullScreenCover` + `.statusBarHidden(true)`) |
| T7, T9, T11 | pendientes |
| T8 — La botonera del ascensor | pendiente; cambia por S6 (botones de 30 pt) |
| T10 — La escena con `PlayLayout` | pendiente; cambia por S5 y lleva lo arrastrado de T3 y T4 |
| T12 — Cierre | pendiente; lleva `ScreenInsetsUITests` al `se-ui` |

### E11

T1 y T2 ✅. **T3 ya se puede**: esperaba a que E1 T5 se integrara, porque hereda
`Localizable.xcstrings` y `FisuEvolutionApp.swift`. El brief está generado (`task-3-brief.md`, 902
líneas) y lleva las líneas arrastradas de T2. T4–T7 pendientes.

## 6. Trampas nuevas

### A. El clasificador del modo auto bloquea la limpieza de worktrees

`git worktree remove --force` + `git branch -D` sobre los 10 worktrees de agentes del relevo 4
dio "Irreversible Local Destruction", **aun con `git cherry version-2 <rama>` sin un `+` y el
árbol limpio**. El relevo 4 sí había podido borrar los 5 del relevo 3. La limpieza la hace el
dueño.

### B. El guard rechaza `$(git …)` y `$(inherited)` dentro de un comando del agente

La receta a mano (§6 del general) lleva `OTHER_SWIFT_FLAGS='$(inherited) …'`, y el guard la
rechaza escrita en la línea. E1 T5 y T6 la corrieron desde un script propio gitignoreado
(`build/e1t5.sh`, `build/e1t6-build.sh`, `build/e1t6-test.sh`). El oráculo no tiene el problema:
es un script.

### C. Con la máquina cargada, `store-unit` puede dar rojo por el plazo de carga de productos

Con un `load average` de ~450–600, `loadsTheCatalogProducts` falló por el plazo de 10 s de
`StoreManager.loadTimeout`. La repetición, con menos carga, pasó 13/13. Si el `completo` da un
rojo suelto en `store-unit` con la máquina así, es eso: hay que mirar `uptime` antes que el
código. La revisión recomienda subir `loadTimeout` en los tests con StoreKit real.

### D. Adelantar `version-2` con commits sólo de `Docs/` mientras corre un `completo` ahí es inocuo

El oráculo lee el hash una vez al arrancar. Lo que no se hace es un merge con fuentes Swift bajo
un oráculo en curso: por eso el merge de E1 esperó al `completo`.

### E. La prueba manual v1 → v2 del dueño cierra el ORO comprado en 0 hasta T6b

Una build DEBUG instalada por `simctl` en un runtime < 26 lee `Transaction.all` sin la
`SKTestSession` local, ve el historial vacío y cierra la reconstrucción en 0, sin reintento.
**Hasta que entre T6b, esa prueba no prueba nada**, y el save sobre el que corra queda con
`purchasedOroReconstructed` en `true` y 0 comprado: no se vuelve a intentar.

### F. El `completo` VERDE de este relevo no cubre la ola C

Es sobre `d22eb7a`. El "importante" de la revisión de T5 (paso 6: `completo` + captura en el SE)
y la confirmación de E3a T4 en el 16 Pro quedan para el `completo` sobre `bc3bf6f`.

### G. Un `completo` verde no prueba las safe areas

`ScreenInsetsUITests` pasa en el 16 Pro con o sin el arreglo; sólo el SE (y el iPad, cuando la
app sea universal) lo pone en rojo, y aun ahí con 3 arranques hay ~6 % de falso verde. Hasta que
E3a T12 y T10 lo sumen a sus matrices, la cobertura real es la corrida a mano del agente.

### H. El cron, otra vez

Cuarto relevo sin un despertar por cron observado: el relevo 5 también lo despertó el dueño.

### I. Los tests de copias con nombre por milisegundo pasan con la máquina cargada y fallan con la máquina libre

Toda la ola corrió con la máquina cargada, y `rotatesTheLastTenGoodLoads` pasó siempre. Falló en
la primera corrida rápida (unit 374 s): con ~2 ms por carga, tres de las 12 cargas cayeron en un
milisegundo ya usado y pisaron su copia. **Un nombre de archivo sacado de `Date()` es un rojo
esperando a una máquina libre**, y la carga lo esconde. Es la trampa C al revés: aquélla es un
rojo por lentitud.

## 7. El mecanismo que funcionó (mantenerlo)

- **Adelantar las ramas de épica por fast-forward a la punta de `version-2` antes de despachar**:
  las tareas parten del catálogo con las claves de todos y con las herramientas nuevas.
- **La tabla de calientes de la ola incluye lo que sale después**, con su herencia: E11 T3 hereda
  el catálogo y `FisuEvolutionApp.swift` de E1 T5, y E3a T5 hereda `Info.plist` de E1 T6.
- **Despachos de ~15 líneas** sobre el protocolo común (`v2-agente-protocolo.md`).
- **`SendMessage` a un planificador en vuelo**, para coordinarlo con un plan que acaba de
  llegar: funcionó (E5 → E6), y E6 salió ajustado sin una segunda vuelta.
- **El journal AVO se compactó**: las its 00–05 y los relevos 1–4 quedaron resumidos, y el
  original está en `journal-pre-compact-2026-10-07.md`.
- **Disciplina de contexto**: con ~245–255k el controlador dejó de lanzar tareas grandes. E11
  T3, E3a T5 y T6b quedaron para el relevo 6 en vez de quedar a medio integrar. T5b salió igual
  porque arregla el rojo del `rapido`.

## 8. Qué sigue (relevo 6)

0. **Integrar E1 T5b** (en vuelo al cierre) y correr su `rapido`: esperado EK 357 · unit
   612 + 1 más los tests que sume T5b. Recién ahí se pushea `version-2`.
1. **El `completo` sobre la punta de `version-2`**, con los números esperados de §2, y la captura
   de `SaveRecoveryView` en el SE.
2. **E11 T3**, con su brief y las líneas de T2.
3. **E3a T5** (universal, iOS 18), con el motivo de T6 sobre iOS 17.
4. **T6b**: chico, sólo `StoreManager.swift`.
5. **La ola D**: E1 T8 (con lo de T1) ∥ E3 en frío ∥ E11 T4 y T5. **E5a T1 puede ir ya**: no toca
   calientes ni strings.
6. **Planes que faltan**: E7b, E9 y E2b.
7. Del dueño: los 🔒 de §3 y la limpieza de worktrees.
