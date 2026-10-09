# SESION 2026-10-09 — v2, relevo 17: la ODR por tag, el especial animado, los ganchos del ranking y la sonda de fps

Relevo 17 de la ejecución autónoma de la 2.0, despertado a las 06:03 del 9 de octubre por la rutina `fisu-v2-relevo-a`
con el `LOCK` libre (lo había liberado el relevo 16 a las 06:01). Controlador opus; implementadores sonnet en worktrees
manuales (`worktrees.nosync/v2i-<tarea>`); revisor opus para E12 T11. Todo pasó por la rama de integración
**`v2i/integ-r17`** (BASE `version-2` en `18e2fbf`). Cierre a ~250k de contexto: el último despacho (E8c T3) fue lo
último; desde ahí sólo se esperó a lo que estaba en vuelo.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`b093db5`**: el `rapido` sobre `2d33c08` dio VERDE y avanzó por fast-forward con E8d T14, E8d T5, E12 T11 y E13 T5 |
| `v2i/integ-r17` | **`b5043b5`** = lo anterior más E8d T13 y E8c T3 (🟢) + los docs del cierre |
| `rapido` | intermedio sobre `3e9e965`: EK 618 · unit 979 + 2 rojos (`theOwnersTargetsAreMet` declarado; `GameStateRankingHostTests`, ver abajo) · Release 0. Sobre `2d33c08`: VERDE (EK 618 · unit 980 + 1 declarado `theOwnersTargetsAreMet` · Release 0). Final sobre `b5043b5`: RAPIDO_PENDIENTE |
| Progreso | **108 de 254 en `version-2` (42,5 %); 110 de 254 (43,3 %)** si el `rapido` de `integ-r17` da VERDE (`tasks.md` §2) |

El paso 1 del handoff anterior (el fast-forward de `integ-r16`) ya lo había hecho el relevo 16: `version-2` llegó
a `18e2fbf`, igual que `origin`.

## Lo que se integró

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E8d T14** la segunda tanda: los tags ODR | `9a02e6b` (merge `f23733d`) | tarea unit 17; Python 89 verdes; diff de `project.yml` leído por el controlador |
| **E8d T5** el especial y la ficha, animados | `479538e` + `5854a7d` (merge en `integ-r17`, `40b9296`) | tarea unit 14; `CharacterSheetUITests` 2/2 en 16 Pro; revisión ninguna |
| **E12 T11** los ganchos en `GameState` | `9ff10dd` + `6e5a006` (merge `3e9e965`) | tarea unit 58, luego 59; revisión opus |
| **E13 T5** los precios al reencarnar, explicados | `3880ab9` (merge `2d33c08`) | tarea VERDE; UI en el SE; revisión ninguna |
| **E8d T13** la sonda de fps y memoria | `3ff331f` (merge `374d0fc`) | tarea unit 9; 🟢 en `integ-r17`; diff leído |
| **E8c T3** el tempo de la cadena, puro | `aaf9f06` (merge `16a22de`) | 7 pares ≤ 3,5 s; revisión ninguna |

### E8d T14 — la segunda tanda entra con su tag ODR

99 `.mov` a `AnimPacks/<tag>`, 14 packs: la base suma 10,2 MB y los packs 19,8 MB (vara: base ≤ +60 MB). Cero Swift de
juego salvo el manifest y `project.yml` (`ENABLE_ON_DEMAND_RESOURCES`, `resourceTags`). `AnimatedArtView` pide el pack con
un `ArtPackLease`. **Hallazgo:** el manifest que trajo la tanda del dueño tenía las claves `visitors` e `icons`, y el
lado Swift lee `talking`, `visitorActions` y `shopIcons`. El agente reescribió el manifest y dejó `video_assets.py` al
día para que la próxima tanda salga con las claves que Swift lee. Los íconos son de 256² y llevan claves `ui_oro_*`: son
para E6a. En Debug los packs van **embebidos** bajo `OnDemandResources/` (no se piden de verdad).

### E8d T5 — el póster del especial era un busto

Primera entrega `DONE_WITH_CONCERNS`: las capturas mostraron un salto al arrancar el video. El póster del especial es de
**cuerpo entero** y `.portrait` es el **busto**, así que la imagen cambiaba de encuadre cuando entraba el video. Se devolvió
al implementador: el especial anima con `.character(special.id)` (los 10 especiales están en `characters`), igual que su
póster. La captura en el 16 Pro quedó bien.

### E12 T11 — los ganchos del ranking

`GameState` conecta el store del ranking: `attachRanking` llama `becameActive` en el arranque en frío, y
`--uitest-ranking-god` se combina con los otros fixtures. Encontró que `GameState+Ranking` ya existía con `godTier`
`nil` (de T10) y lo reescribió. **Revisión opus: Approved con arreglos**, hechos en `6e5a006`:

- **Obligatorio:** `becameActive` durante el tutorial **arrancaba la partida rankeada y corría el cronómetro** con el
  jugador todavía en las lecciones. Ahora `rankingBecameActive` tiene un guard `!tutorialPhaseActive`, y un test que
  muerde (`tutorialDoesNotRunTheClock`).
- Opcionales hechos: el `reconcile` redundante sólo corre en `attach`, y los tests que no mordían ahora muerden.
- **No hecho (d):** el parseo de `--uitest-ranking-*` en `RankingStore.live()` **no está bajo `#if DEBUG`**. Es un bloque
  de T8 y no de T11: queda para el dueño u otra tarea.
- **El test viejo:** `GameStateRankingHostTests` (de T10) esperaba `godTier == nil`; T11 lo cambió a propósito y el test
  quedó rojo en el `rapido` sobre `3e9e965`. Se alineó junto con el merge de E13 T5 (`2d33c08`) y el `rapido` siguiente
  dio verde. El rojo no era un bug: era un test que fijaba el estado anterior de una tarea.

### E13 T5 — los precios al reencarnar

`PrestigeView` explica los precios; las claves van en `claves-pendientes/e13-t5.json` y entran al catálogo en el merge
(+1 al conteo). Un assert más en `PrestigeIndicatorUITests`. La tarea cerró VERDE con la clave aplicada a mano; la captura
en el SE muestra que el botón queda dentro de la hoja. Esperó a que terminara el `rapido` en vuelo antes de mergearse
(no se mergea con un oráculo corriendo).

### E8d T13 — la sonda de fps

`FrameStats` y `FrameRateProbe`; una fila "Rendimiento" y "Llegar a Dios" (`debugReachGod`) en el panel de debug; el
fixture `--uitest-anim-stress` entra por `LoopsManifest.main` bajo `#if DEBUG`. En el simulador: 60 fps, peor cuadro
17 ms, 81 MB. **No es la vara** (la vara es device: G1/G2/G4). Sin captura de la fila del panel.

### E8c T3 — el tempo de la cadena

`MergeAllTempo`, puro y sin dependencias: 7 pares cuentan ≤ 3,5 s. Lo hizo un agente sonnet sin revisión. Ver la trampa
de la red más abajo.

## Decisiones de este relevo

- **Briefs con `brief.py`** (la tarea recortada, no el plan entero) y worktrees manuales desde la BASE.
- **Tope de 2 compilando** desde que la carga pasó de 200 (llegó a 555 a 15 min): el `rapido` cuenta como uno.
- **No se mergea con un `rapido` corriendo:** E13 T5 y E8d T13 esperaron en su rama pusheada.
- **La lista de palabras de E12 no se reintentó:** sigue sin confirmación del dueño en el chat.
- **A 225k se despachó el último trabajo** (E8c T3, pura); desde ahí sólo se esperó.
- **Los menores que no muerden se anotan en el carry** en vez de reabrir al implementador.

## Trampas nuevas

- **El primer `rapido` en background murió con exit 127** (`oraculo.sh` no encontrado): se lanzó con un `cd` relativo y el
  shell de fondo no estaba en el worktree. Lanzarlo siempre con la ruta absoluta:
  `bash <ruta absoluta>/Tools/v2/oraculo.sh rapido`.
- **Carga 150–550 con tres compilando:** el tope es 2, contando el `rapido`. Mirar `uptime` en cada borde; con la carga
  alta, una corrida lenta no es un cuelgue (esperar, con timeout de 15 minutos).
- **Un agente sin red a GitHub no resuelve los paquetes.** El de E8c T3 no pudo bajar `SourcePackages`; copió el
  directorio de `version-2/build/DD-oraculo.noindex` y siguió con `-disableAutomaticPackageResolution
  -skipPackageUpdates`.
- **El póster y el video tienen que ser del mismo encuadre.** `.portrait` es el busto y `.character` el cuerpo entero; un
  póster de uno y un video del otro da un salto al arrancar (E8d T5). Mirar la captura del primer cuadro.
- **Un test que fija el estado anterior de una tarea se pone rojo cuando la siguiente lo cambia a propósito**
  (`GameStateRankingHostTests` esperaba `godTier == nil`). Mirar si el test quedó viejo antes de culpar al código.
- **Un hook de arranque que corre en el tutorial arranca la partida** (E12 T11): cualquier gancho nuevo del arranque
  necesita su guard `!tutorialPhaseActive`.

## Carries por tarea

- **E12 T11 → T12/T13:** T12 (el reset abre un intento nuevo) y T13 (la 7.ª pestaña montada) quedaron destrabadas **por
  T11**, pero siguen ⛔ por otras dependencias (T12: E9b T7/T8; T13: E3b T4 y E3a T11). `--uitest-ranking-*` en
  `RankingStore.live()` no está bajo `#if DEBUG`. La config remota y el `godTier` siguen `null`/`nil` hasta T16.
- **E8d T13:** sin captura de la fila del panel; el estrés de `shopIcons` y del fondo **no mide hasta T8** (inerte hasta
  que haya fondos con tag); la vara es device.
- **E8d T14:** **el ODR real nunca se ejercitó en device (G5)**; las claves `ui_oro_*` de los íconos 256² son para E6a;
  en Debug los packs van embebidos.
- **La lista de palabras de E12** sigue sin activar (ver "Para el dueño").
- **Siguen vigentes** los de los relevos 14 a 16: HEVC con alfa a ×5 en un iPhone real (E13b T11 / E8d G3), el motor de
  la cabina a gain 0,4 a ojo, `resolveAcrossReset`, `carriedSubmission`, `setVisible(false)` de T4 a T8/T9.

## Para el dueño

- **La lista de palabras de E12 sigue sin activar:** confirmarla en el chat y el próximo relevo la activa.
- **`--uitest-ranking-*` en `RankingStore.live()` no está bajo `#if DEBUG`:** es un parseo de argumentos de prueba en
  código de release. Decidir si se cierra en T8 o en una tarea chica.
- **ODR nunca probado en un dispositivo:** hasta ahora sólo hay packs embebidos en Debug.
- Siguen abiertos: el `installId` que no viaja por CloudKit, el botón Entrar con `.disabled`, la placa de 10 pisos que tapa
  Reencarnar, capturas de las 3 ofertas de ASC, Meta, mediación por SPM, cuentas de redes, TestFlight, oír los sonidos
  de E8d (G7), HEVC-alfa a ×5 en device (G3).

## Oráculo

- `rapido` sobre `integ-r17` `3e9e965`: EK 618 · unit 979 + 2 rojos (`theOwnersTargetsAreMet` declarado;
  `GameStateRankingHostTests`, test viejo alineado en `2d33c08`) · Release 0.
- `rapido` sobre `2d33c08`: VERDE (EK 618 · unit 980 + 1 declarado `theOwnersTargetsAreMet` · Release 0). Avanzó
  `version-2` a `b093db5`.
- `rapido` final sobre `integ-r17` (`b5043b5`): RAPIDO_PENDIENTE
- Tareas: E8d T14 unit 17 + Python 89 · E8d T5 unit 14 + `CharacterSheetUITests` 2 · E12 T11 unit 59 · E13 T5 VERDE +
  `PrestigeIndicatorUITests` · E8d T13 unit 9.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Reintentar la activación de la lista de palabras contra el clasificador de permisos.
- Una revisión de E8d T5, E8d T13 y E13 T5: UI suelta o herramienta de DEBUG, el controlador leyó el diff.
- Abrir `--uitest-ranking-*` bajo `#if DEBUG` dentro de T11: es de T8.

## Cierre

- Subagentes en vuelo: **0** (E8c T3 entregó). `LOCK`: lo libera el controlador.
- Worktrees borrados al integrar cada tarea (E8d T14, T5, E12 T11, E13 T5, E8d T13: 1,5 GB cada uno). Quedan
  `v2i-docs-r17` y `v2i-integ-r17` (y `v2i-e8c-t3` si no se borró) para el barrido final (`limpiar-worktrees.sh`).
- Cuota: 5 h 10 % al llegar, semanal 48 %.
