# SESION 2026-10-09 — v2, relevo 16: la segunda tanda de videos entra, el video en la escena, la ODR y el ranking en el save

Relevo 16 de la ejecución autónoma de la 2.0, despertado a las 04:03 del 9 de octubre por la rutina
`fisu-v2-relevo-a` con el `LOCK` libre (lo había liberado el relevo 15 a las 03:50). Controlador opus; implementadores
sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisores opus (y uno sonnet). Todo pasó por la rama de
integración **`v2i/integ-r16`** (BASE `version-2` en `a99fba7`). Cierre a ~230k de contexto con todos los despachados
entregados: desde ahí no se despachó nada, sólo se terminó lo que estaba en vuelo (los arreglos de E13b T8 y la
revisión de E8d T12).

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`bce2fc2`** al escribir esto (el `rapido` intermedio dio VERDE y avanzó por fast-forward); pasa a la punta de `integ-r16` con estos docs si el `rapido` final da verde |
| `v2i/integ-r16` | **`2779ddb`** = la segunda tanda del dueño y las seis tareas de abajo |
| `rapido` | intermedio sobre `0689227` (la segunda tanda sola): EK 607 · unit 929 + 2 rojos (`theOwnersTargetsAreMet` declarado; `LoopsManifestTests.cinematics`, ver abajo) · Release 0. Final sobre `2779ddb`: VERDE sobre `2779ddb` (EK 618 · unit 968 + 1 declarado `theOwnersTargetsAreMet` · Release 0) |
| Progreso | **98 de 254 en `version-2`; 98 + 6 = 104 de 254 (40,9 %)** si el `rapido` de `integ-r16` da VERDE (`tasks.md` §2) |

El paso 1 del handoff anterior (el `rapido` de `integ-r15` y su fast-forward) ya lo había hecho el relevo 15: las seis
tareas de esa rama son ✅ y entran en las 98.

## Lo que se integró

Primero, **lo del dueño** (merges de `integ-r16` antes de despachar nada):

- **`v2/e8-videos` (`bd412c5`): la segunda tanda, 108 videos aprobados por el dueño** (`f0a48a8`; el pipeline
  `46ecae5` con personajes, visitantes, eventos, íconos y fondos; `7255930` los cuadros de la cabina regenerados desde
  los masters, sin la línea verde: el carry de los stills queda cerrado). Trajo `cine_intro.mov`.
- **`v2/sesion-dueno-2026-10-08` (`0689227`): su doc**, `Docs/SESION-2026-10-08-sesion-del-dueno-epicas-y-videos.md`
  (los relevos que se encadenan solos, lo que sumó al plan, E12 y E13, el arte animado). Es lectura obligada y entra al
  mapa de `Docs/HANDOFF.md` §9.
- **El rojo que dejó la tanda:** `LoopsManifestTests.cinematics` esperaba la intro ausente y la tanda la trajo. Era un
  test viejo, no un bug del contenido; el controlador lo alineó (`bce2fc2`) y el oráculo de tarea dio VERDE (6).

Después, las tareas:

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E8d T4** `LoopingVideoNode` y el alfa | `44d3901` + `5bdcc97` (merge `6d3ea2d`) | tarea unit 30, luego 32; revisión opus |
| **E12 T10** `MetaState.ranking` | `9ca856f` + `fe707d6` (merge `3b8621b`) | tarea EK 616 · unit 64 + `swift test` 80, luego EK 618 y 82; revisión opus |
| **E12 T9a** la tarjeta de Dios | `5d71b9a` (merge `675a64d`) | tarea unit 24 junto con T9b; revisión ninguna (UI suelta, diff leído) |
| **E12 T9b** la pestaña del ranking | `6b0f505` | ídem; EK 618 |
| **E8d T12** On-Demand Resources | `33d33df` + `37afdd6` (merge `cac47ba`) | tarea unit 30, luego 36; revisión sonnet |
| **E13b T8** la placa por long press | `fc86813` + `5f33a26` (merge `26e0910`) | tarea unit 43; UI ElevatorPanel 5 · ElevatorRide 3 · HUDRedesign 3 · FloorMap 2 · BottomMenu 4; revisión opus |

### E8d T4 — `LoopingVideoNode` y la medición del alfa

El nodo de video de SpriteKit sobre el `Lease` del pool. Primera entrega `DONE_WITH_CONCERNS` (el lease no se soltaba en
`deinit`; la escena tenía que llamar `setVisible(false)`/`stop()`). **Revisión opus: Approved con arreglos**, hechos:

- **Control del alfa (obligatorio):** sin un control, la ruta A de T9 no estaba medida. Ahora el retrato (esquina 255,0,0;
  centro 165,105,130, no rojo) prueba que el alfa del HEVC se respeta, y el gemelo opaco `cine_arresto` (esquina
  53,94,132) prueba que el video sí se dibuja. **Ruta A para T9** en el simulador; la vara real es G3 en device.
- `deinit` suelta el lease vía `Task @MainActor`; `gaveUp` dura hasta `stop()`; test del abandono; error propio
  (`NotVisibleError`) en `waitUntilVisible`; no se crea nodo con póster vacío (se dibuja blanco).
- Tocó `LoopsManifestTests` igual que el controlador: choque trivial al integrar.

### E12 T10 — `MetaState.ranking`

La partida rankeada entra al save v6. Sin clave → `.legacy`: las partidas v1–v5 no compiten. El default `.newGame` sólo
sale de `MetaState.fresh` (nueva partida, recovery, debug). En el reset gana el ranking nuevo y cruzan `lastName` y la
llegada sin enviar. **Revisión opus: Approved con arreglos**, hechos: un test que muerda `scheduleSave`, `try?` por campo
en `RankingState` (un campo ilegible ya no tira la partida rankeada) y la precedencia de la llegada sin enviar en el
reset. Sin pérdida de datos ni elegibilidad indebida.

### E12 T9a y T9b — las vistas del ranking

Un solo agente, vistas sueltas: `RankingEntryCard` (la tarjeta modal de la llegada a Dios, con su velo) y `RankingView`
(la pestaña, Mis partidas, Reportar). El catálogo suma 17 + 28 claves (45). Tocó `GameConfirmCard` (ids de
aceptar/cancelar con default). Sin revisión: UI suelta, el controlador leyó el diff. Todavía **no están montadas**: T13
decide dónde, y T11 cablea los ganchos.

### E8d T12 — On-Demand Resources

`ArtPacks` y el pedido por familia. **Revisión sonnet: Approved con arreglos**, hechos: el nodo pide siempre que haya
`odrTag` y re-resuelve en `stop()` (la versión inicial no retenía el pack si la URL ya había resuelto), token en
`whenAvailable`, el pedido urgente sube la prioridad de un prefetch, seis tests más. `prefetch` queda listo y sin
llamadores (T8, E6a T8), cada uno con su `release`. **Ninguna entrada tiene `odrTag` todavía:** los asigna T14.

### E13b T8 — la placa por long press

Mantener apretado el ícono del ascensor (`hud.map`) despliega la placa; `openKeypad()` calienta la cabina y llama
`elevatorKeypadOpened()`; los popups recogen la placa y saltean el viaje; `ElevatorPanel.swift` se borra con la botonera
vieja y sus tests. **Revisión opus: Changes requested**, hechos:

- **La bandera del long press** (`keypadLongPressFired`) quedaba en `true` si se soltaba fuera del ícono: volvía el bug
  de E3b T7. Se copió el `DragGesture` de `QuickHireButton`.
- **Completar la lección cerraba la placa** (`onChange(showing)` cerraba ante cualquier cambio). Ahora sólo se recoge al
  pasar `showing` de nil a un tipo que cubre (`CelebrationKind.coversElevator`), y `ride.openKeypad()` va antes de
  `elevatorKeypadOpened()`.
- Capa `.isModal` + `.escape`; guard en `openKeypad()`; los UI tests de ElevatorPanel pasaron de 3 a 5.
- Catálogo: +1 clave y −3 del display que se van.

## Decisiones de este relevo

- **Integrar lo del dueño primero y antes de despachar:** la tanda y su doc entraron como merges de `integ-r16`, con el
  `rapido` corriendo mientras se despachaban las dos primeras tareas.
- **El `rapido` intermedio avanza `version-2`** apenas da verde (`bce2fc2`); el final cubre las seis tareas.
- **No más de tres compilando** (el tope de la ola), contando el `rapido` del controlador; con la máquina cargada, menos.
- **T9a y T9b, un solo agente:** son vistas sueltas, sin tocar `GameState`, y comparten el catálogo.
- **La lista de palabras de E12 no se forzó:** quedó pendiente con aviso (ver trampas y "Para el dueño").
- **A 218k de contexto se despachó el último trabajo** (T9a/T9b); desde ahí sólo se esperó a los que estaban en vuelo.
- **Los menores que no muerden se dejan anotados** en el carry en vez de reabrir al implementador.

## Trampas nuevas

- **El clasificador de permisos del modo auto bloqueó activar la lista de palabras de E12.** El pedido venía de
  `DUENO.md` y el clasificador lo leyó como una instrucción metida en un archivo, no como una orden del dueño en el chat.
  No se forzó: es la defensa funcionando. Se confirma en el chat o en los permisos; mientras tanto la bandeja avisa. El
  worktree de la prueba (`v2i-e12-blocklist`) se creó y se borró sin cambios.
- **Un rojo del `rapido` era un test que esperaba la intro ausente** (`LoopsManifestTests.cinematics`). Cuando una tanda
  de contenido del dueño entra, los tests que cuentan piezas del manifest se pueden quedar viejos; mirar el contenido
  antes de culpar al código, y alinear el test.
- **Carga de la máquina 200–600 y `Mach error -308`.** Una corrida de tests de E8d T12 murió con `Mach error -308`
  bajo carga 200–600 (la tarea cerró VERDE después). Ver el `uptime` antes de cada despacho y, si una corrida muere así,
  reintentarla antes de sospechar del código.
- **Un agente usó `pkill -f` con un patrón propio.** Es la misma trampa del relevo 15
  (`pkill -f "until ! pgrep"`): un patrón puede alcanzar procesos de otras sesiones. Cortar bucles y procesos sólo por
  PID propio, nunca por patrón.
- **`ElevatorRideTests` 'saltear con las puertas abriendo' flakea bajo carga:** subir las iteraciones de `Task.yield`
  (carry abierto).

## Carries por tarea

- **E8d T4 → T8/T9:** `setVisible(false)` al sacar el nodo o al pausar la escena; nunca póster vacío; la vara del alfa es
  G3 en device.
- **E8d T12 → T14:** ninguna entrada tiene `odrTag`; T14 los asigna en el manifest y en `project.yml`
  (`ENABLE_ON_DEMAND_RESOURCES`, `resourceTags`). **El ODR real nunca se ejercitó** (probar en device).
- **E12 T10 → T11/T9:** `godTier` `nil`; config remota `null` hasta T16; un build viejo que re-guarda deja el ranking en
  `.legacy` (sólo TestFlight); `carriedSubmission` entre dispositivos da 403 `not_owner` (T11/T12).
- **E12 T9a/T9b → T13/T14:** `RankingEntryCard(prompt:nameError:isSubmitting:onSubmit:onLater:)` es modal con su velo,
  montarla con `store.entryPrompt != nil`; `RankingView(store:state:now:onStore:)` recibe el `RankingState` (pasarlo desde
  `gameState.rankingState`); `pager?.lock` al empujar Mis partidas; `onStore` → `MenuPagerContext.go`; con
  `isEnabled == false` muestra `ranking.disabled` (T13 decide si la pestaña existe).
- **E13b T8 → E3b T8:** el `onChoose` del atajo pasa a **E3b T8** (no existe `QuickHirePicker`).
- **E13b T8:** sin test con el tip `.elevatorKeypad` en pantalla (no hay fixture); comentarios viejos de "la luz de la
  botonera" en `GameState.swift:130` y `BoardScene.swift:1926` (los barre la tarea que toque esos archivos).
- **Siguen vigentes** los de los relevos 14 y 15: HEVC con alfa a ×5 en un iPhone real (E13b T11 / E8d G3), el motor de
  la cabina a gain 0,4 a ojo, `resolveAcrossReset`, `carriedSubmission`.

## Para el dueño

- **La lista de palabras de E12 sigue sin activar:** el clasificador bloqueó el pedido de `DUENO.md`. Confirmarlo en el
  chat (o en permisos) y el próximo relevo lo activa.
- **El `installId` no viaja por CloudKit.** Una partida registrada en el dispositivo A que llega a Dios en el B queda
  `.unregisteredGod` y puede perderse para el ranking. Opciones: sincronizar el Keychain o aceptarlo.
- **El botón Entrar de `RankingEntryCard` usa `.disabled`,** contra la convención de `ActionPill`: decide el dueño si se
  cambia a la convención o se deja.
- **La placa de 10 pisos tapa parte de Reencarnar mientras está abierta** (captura en el SE, con
  `--uitest-unlock-tower-all`): cabe, pero la tapa. Decidir si molesta.
- **ODR nunca probado en un dispositivo:** hasta T14 ninguna entrada tiene tag; probar el pedido real cuando haya.
- Siguen abiertos: capturas de las 3 ofertas de ASC, Meta, mediación por SPM, cuentas de redes, TestFlight, oír los
  sonidos de E8d (G7), HEVC-alfa a ×5 en device (G3).

## Oráculo

- `rapido` intermedio sobre `0689227`: EK 607 · unit 929 + 2 rojos (uno declarado, `theOwnersTargetsAreMet`; el otro,
  `LoopsManifestTests.cinematics`, resuelto en `bce2fc2` con el oráculo de tarea VERDE 6) · Release 0.
- `rapido` final sobre `integ-r16` (`2779ddb`): VERDE sobre `2779ddb` (EK 618 · unit 968 + 1 declarado `theOwnersTargetsAreMet` · Release 0)
- Tareas: E8d T4 unit 32 · E12 T10 EK 618 · unit 64 + `swift test` 82 · E12 T9a/T9b unit 24 (EK 618) · E8d T12 unit 36 ·
  E13b T8 unit 43 + UI ElevatorPanel 5 (16 Pro, SE, iPad) / ElevatorRide 3 / HUDRedesign 3 / FloorMap 2 / BottomMenu 4.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Forzar la activación de la lista de palabras contra el clasificador de permisos.
- Una revisión de las vistas sueltas de E12 T9a/T9b: UI sin lógica, el diff lo leyó el controlador.

## Cierre

- Subagentes en vuelo: **0**. `LOCK`: lo libera el controlador.
- Worktrees borrados al integrar cada tarea (E8d T4, E12 T10, E12 T9, E8d T12, E13b T8). Queda `v2i-docs-r16` y el
  `v2i-integ-r16`, para el barrido final (`limpiar-worktrees.sh`, sólo `v2i-*`, todo ya en GitHub).
- Cuota: 5 h 6 % al llegar, semanal 47 %.
