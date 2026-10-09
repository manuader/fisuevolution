# SESION 2026-10-08 — v2, relevo 14: los videos reconciliados con el dueño, el plan Swift de las animaciones y cinco tareas más

Relevo 14 de la ejecución autónoma de la 2.0, despertado a las 21:03 por la rutina `fisu-v2-relevo-a` con el
`LOCK` libre (lo había liberado el relevo 13 a las 20:54). Controlador opus; implementadores sonnet en worktrees
manuales (`worktrees.nosync/v2i-<tarea>`); planificador y reconciliador opus. Todo pasó por la rama de integración
**`v2i/integ-r14`**. Cerró con 0 subagentes en vuelo, a ~245k de contexto (la regla de 250k se respetó: desde ahí no
se despachó más).

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`596cacd`** (= `v2i/integ-r13`, con E13b T5), pusheado; `rapido` VERDE: EK 605 · unit 822 + 1 declarado · release 0 |
| `v2i/integ-r14` | **`32afc93`** = `596cacd` + todo lo de abajo + estos docs. `rapido`: <<RAPIDO-R14>> |
| Progreso | **87 de 254 tareas activas en `version-2`**; **87 + 5 = 92 de 254 (36,2 %)** si el `rapido` de `integ-r14` da VERDE. El denominador pasó de 243 a 254: P-E8d sumó 15 filas y se salteaban 4 de E8b |

El primer paso fue el `rapido` de `integ-r13` (`596cacd`, con E13b T5): dio verde a las 21:23, `version-2` avanzó por
fast-forward y se pusheó. Lo demás se integró en `integ-r14`.

## Lo que se integró

### La reconciliación de los videos (opus, `5e3b707`)

La sesión del dueño había integrado los mismos videos en `v2/e8-videos` (`c739f2f`) y la spec de animaciones en
`v2/e8-animaciones-docs` (`1a54ed7`). Merges `6772790` y `ddbb560` → `5e3b707` en `integ-r14`. Regla: **manda la
versión del dueño de cada pieza** (la primera tanda la declaró lista; `video/revision.json` estaba en `{}`).

- Quedaron las **27 piezas del dueño** y su `loops_manifest.json` (`portraits`, `objects`, `cabin`, `cinematics`).
- **La cabina es `cabina_puertas_*`**; los `cine_ascensor_*` de E13b T4 se borraron. Los stills se renombraron
  `cabina_{cerrada,abierta}.png` y **siguen con la línea verde**: hay que regenerarlos con `cabina-cuadros`.
- `video_assets.py` es el del dueño + el subcomando `cabina-cuadros`; se borraron por duplicados el magenta, "medir arriba",
  el recorte a 512 y `ascensor`.
- Swift: nombres nuevos en `ElevatorCabin` y el **tope de rate de 4 a 5** en `ElevatorRideView.play` (diff leído por el
  controlador: OK). El HEVC con alfa a ×5 no se probó en un dispositivo → E13b T11 / E8d G3.
- Pipeline 81 OK; `ElevatorCabinTests` VERDE; +0,69 MB. DONE_WITH_CONCERNS.

### P-E8d, el plan Swift de las animaciones (opus, `fdb1d39`, merge `e45477c`, filas `5a14541`)

15 tareas sobre la spec del dueño: `VideoPlayerPool` de a lo sumo 3, `AnimatedArtView`, `LoopingVideoNode`, On-Demand
Resources, sonidos y los fps como gate. **Reemplaza E8b T4, T5, T6 y T12** (quedan ⏭️); E8b T8 y T9 cambian (importan de
E8d); E13b T6 sigue igual (E8d T10 va después de E13b T6 y T8). 7 gates (G6 la revisión de la segunda tanda y G7 oír los
sonidos son del dueño), 15 dudas con default.

### Tareas

| Tarea | Commit | Oráculo y nota |
|---|---|---|
| **E13b T7** la lección "Mantené apretado el ascensor", al tercer piso | `18fb478` (merge `1ffc9c4`; clave `b590da6`) | sin revisión (diff leído); nace con `unlockedFloorsCount >= 3` |
| **E3b T6** la oferta del atajo: pin, motivo, nunca `nil` | `741af10` + arreglos `6255531` (merge `e5bbde3`) | tarea unit 50, luego 29; revisión sonnet |
| **E12 T7** el cliente del ranking, la identidad en el Keychain y la config remota | `a4691a5` + `e20870a` (merge `7cc774d`) | tarea EK 606 · unit 27; el controlador leyó el cambio de EK |
| **E8d T1** el manifest entero, `ArtClip` y `CinematicID` (+intro) | `29a8d5f` (merge `1d2970a`) | tarea unit 6 (`LoopsManifestTests`); revisión ninguna |
| **E13b T10** la barra simétrica 2 + 1 + 2, sin rótulos | `66e997c` (merge `ae55483`) | tarea unit 27; UI a mano en SE, 16 Pro e iPad |

## Revisiones y sus arreglos

- **E3b T6** — sonnet: Approved con arreglos. **I1:** la lección `quickHire` nacería con el piso lleno (la oferta ya
  nunca es `nil`) → la lección exige `blocker == nil`, con test. Además comentarios de `RootView` al día y tests de
  piso lleno sin plata, paso 4 y `giveCoins`. Arreglo `6255531`, devuelto al implementador.
- **E12 T7** — la revisión la hizo el controlador sobre el cambio de EK (`clientRunId` en la partida): OK.
- **E13b T7, E8d T1, E13b T10** — sin revisión (mecánicas o de lectura del controlador).

## Decisiones de este relevo

- **Manda la versión del dueño de cada pieza de arte.** El relevo no re-litiga videos: sólo entra lo que el dueño marque
  `va`; la segunda tanda espera su revisión (E8d T14, 🔒).
- **Los 18 retratos de E8b T3 y sus cinemáticas dejaron de ser un camino propio:** el manifest del dueño los reemplaza y el
  lado Swift es E8d.
- **E8d T10 va después de E13b T6 y T8**, y no frena a E13b T6: el ascensor sigue siendo la prioridad alta del dueño.
- **El `rapido` de `596cacd` antes de integrar nada más**, y no mergear a `version-2` con un oráculo corriendo ahí.

## Trampas nuevas

- **Los agentes dejan bucles de espera vivos y se re-despiertan.** Los de E13b T7 y E3b T6 seguían despertándose por
  trabajo de fondo propio (`while pgrep …`, `sleep`) sin procesos visibles en `ps`. Antes de dar por cerrado un agente:
  preguntar si dejó algo en el fondo, y no borrar su worktree hasta que cierre.
- **Un bucle con el cwd en el worktree de OTRO agente impide borrarlo.** Los `sleep` de `v2i-e3b-t6` no eran de E3b T6:
  esperaban `oraculo.sh tarea LoopsManifestTests` de E8d T1 y su shell tenía el cwd ahí. **Mirar el comando del bucle antes
  de cortarlo.** Se le hizo `TaskStop` al agente de E3b T6 (ya había entregado) creyendo que eran suyos, y a los minutos se corrigió el diagnóstico.
- **`TaskStop` sólo a un agente que ya entregó** (commit hecho e integrado). Nunca a uno en vuelo, ni para "destrabar" un
  worktree: primero ver de quién es el proceso.
- **Reconciliar con la rama del dueño antes de planificar.** El plan Swift (P-E8d) recién tuvo sentido sobre el manifest
  del dueño; planificar antes hubiera repetido el solape del relevo 13.

## Carries por tarea

- **E13b T7 → T8:** llamar `gameState.elevatorKeypadOpened()` al desplegar la placa. Sin T8 en una release la lección
  no se marca.
- **E3b T6 → T7:** `QuickHireButton` no usa `blocker` (temblor sólo con `!affordable`, label "Contratar a X",
  `accessibilityState`) y marca la lección al tocar bloqueado. T7 lo arregla.
- **E12 T7 → T8:** `RankingState.startAttemptId` y **persistir antes del `start-run`**; la config remota es `null` hasta
  T16 (el switch queda apagado).
- **HEVC con alfa a ×5 en un iPhone real** (tope de rate de la cabina): E13b T11 / E8d G3. Memoria del SE y parpadeo de
  la cabina siguen sin medir.
- **Los stills de la cabina** (`cabina_{cerrada,abierta}.png`) tienen la línea verde: regenerar con `cabina-cuadros`.
- **E8d T2/T6/T3/T4:** ola 1 incompleta; T6 tiene dueño en `AudioManager` (E8c T4 → E8d T6 → T7 → E8b T9).
- **Los de las olas H, I y J siguen vigentes** (ver los docs de los relevos 11 a 13): `resolveAcrossReset`,
  `carriedSubmission`, `prepare()`/`release()` de la cabina, `sp_contador_dios` y `sp_bug_simulacion` al dueño.

## Oráculo

- `rapido` sobre `596cacd`: **VERDE** (21:23) — EK 605 · unit 822 + 1 declarado (`theOwnersTargetsAreMet`) · release 0.
- `rapido` sobre `v2i/integ-r14` (`32afc93`): <<RAPIDO-R14>>
- Tareas: E13b T10 unit 27 · E3b T6 unit 29 · E12 T7 EK 606 · unit 27 · E8d T1 unit 6 · `ElevatorCabinTests` VERDE.
  Pipeline 81 OK.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`. El siguiente va al cierre de
  E13b (T11).

## Lo descartado

- Los `cine_ascensor_*` de E13b T4 y el `ascensor` de `video_assets.py`: la cabina del dueño (`cabina_puertas_*`) los
  reemplaza.
- E8b T4/T5/T6/T12: reemplazadas por E8d T1, T2+T3, T5 y T15.
- Dos pipelines de video en paralelo: queda el del dueño con `cabina-cuadros`.

## Cierre

- Subagentes en vuelo: **0**. `LOCK`: lo libera el controlador.
- Worktrees borrados al integrar cada tarea: `v2i-integ-r13` (1968 MB), `v2i-e13b-t7`, `v2i-reconciliar-videos`,
  `v2i-plan-e8-anim` y `v2i-e12-t7`. Quedan para el barrido final (`limpiar-worktrees.sh`, todo ya en GitHub):
  `v2i-e3b-t6`, `v2i-e13b-t10`, `v2i-e8d-t1` y `v2i-docs-r14`.
- Siguen los tres simuladores `oraculo-26-5-*` del relevo 10 (los borra el dueño).
- Cuota al cierre: 5 h ~4 %, semanal ~44 %.
