# SESION 2026-10-09 — v2, relevo 19: los cofres de piso por cuenta, la escena que encadena y el toque que apura; FisuJobs por pisos, los acentos de evento y el arte de las cajas

Relevo 19 de la ejecución autónoma de la 2.0, arrancado a las 10:03 del 9 de octubre (sesión
`local_e3ecd658-b708-46a9-8b48-1a3c2734fa49`). Controlador opus; implementadores sonnet en worktrees manuales
(`worktrees.nosync/v2i-<tarea>`) con briefs de `Tools/v2/brief.py` y reglas comunes; revisor opus para E8c T7, E13 T3 y E8c T8.
Todo pasó por la rama de integración **`v2i/integ-r19`** (BASE `version-2` en `87ee9f5`). Carga de la máquina: 1 → 558 → 21,
con picos cuando compilaban tres; tope de 2 compilando con carga > 200.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`f3a2155`**: el `rapido` sobre `f3a2155` dio VERDE y avanzó por fast-forward con E13 T3, E8c T7 y E13 T10 |
| `v2i/integ-r19` | **`6df1ed2`** = lo anterior más E8d T7, E13 T4, E8 T7, E8c T8 y E7b-a T1 (🟢) + los docs del cierre |
| `rapido` | sobre `f3a2155`: VERDE (EK 628 · unit 1020 + 1 declarado `theOwnersTargetsAreMet` · Release 0) → `version-2` a `f3a2155`. Final sobre `6df1ed2`: VERDE sobre `6df1ed2` (EK 628 · unit 1039 + 1 declarado `theOwnersTargetsAreMet` · Release 0) |
| Progreso | **121 de 254 en `version-2` (47,6 %); 126 de 254 (49,6 %)** si el `rapido` de `integ-r19` da VERDE (`tasks.md` §2) |

## Lo que se integró (8 tareas)

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E13 T3** cofres de piso, una vez por cuenta | `7b8035e` | tarea VERDE (EK 628 · unit 38); revisión opus: Approved |
| **E8c T7** la escena encadena sin soltar el turno | `e79696f` + `520d54c` | tarea VERDE (unit 59); revisión opus: Approved con arreglos, hechos |
| **E13 T10** FisuJobs por pisos | `54c5648` | tarea VERDE (unit 23); revisión ninguna, diff leído |
| **E8d T7** los 8 acentos de evento | `b451e4d` | 🟢; tarea VERDE (unit 43); revisión ninguna, diff leído |
| **E13 T4** el punto de Regalos avisa los boosts | `d121c97` | 🟢; tarea VERDE (unit 10); revisión ninguna, diff leído |
| **E8c T8** el toque apura; contador, remate y VoiceOver | `b6cc8f0` + `a59037f` | 🟢; tarea VERDE (unit 64); revisión opus: Approved, opcionales hechos |
| **E8 T7** paquete, colchón, ruleta, tienda y Álbum (31) | `5c33986` | 🟢; tarea VERDE (unit 61; pipeline 89 OK); la hoja de contacto la miró el controlador |
| **E7b-a T1** la config remota en marcha | `5fee22d` | 🟢; tarea VERDE (unit 43); revisión ninguna, diff leído |

### E13 T3 — los cofres de piso, una vez por cuenta

`floorChestsAwarded` pasa de `RunState` a `MetaState`. `PlayerState.init(from:)` es manual y migra `max(meta, run viejo)`
leyendo la clave vieja; el encoder sintetizado ya no la re-escribe. `SaveConflictResolver` toma el máximo. **No entra a
`resolveAcrossReset`:** el reset de cuenta vuelve el contador a 0 y gana la época nueva (test en `ResetEpochTests`).
Reencarnar conserva el contador. **Carry a E2b T5 y E9b T7:** si el reset arma el meta con `newGame`/`.fresh` sale solo; si
copia campos a mano, hay que sumarlo. **Para el dueño:** un jugador de la v1 que ya reencarnó cobra una vez más los cofres de
pisos ya alcanzados (back-fill desde el piso máximo histórico si se quiere cerrar), y builds 2.0 anteriores a E13 mezclados en
la nube re-pagan.

### E8c T7 — la escena encadena

`endBoardChangeTurn()` es el borde único; el tempo sale de `MergeAllTempo` con `next.chain`. `playBoardMergeFeedback`
reemplaza el háptico `.merge` de `presentResolution` (al evolucionar no suena el háptico `.merge`); `soundsMerge` queda sólo
para `.merge`/`.evolve`, así que las llegadas ya no suenan a fusión. Si la cadena pierde el turno, `update` aborta.
**Arreglo obligatorio de la revisión:** guard `playingChain == nil` en `touchesBegan` (un toque durante el reveal agarraba
personajes). Sin captura ni grabación (SE + Reduce Motion).

### E13 T10 — FisuJobs por pisos

`JobGroups.make` testeable; cartel del LED `TowerNaming.ledText` (nuevo); `GameState.floorDisplayName(for:)` devuelve "Piso ???"
también en la ficha del personaje y en la tienda de pintas, lo que cierra el carry de E13 T8 (`FisuJobsView:442`,
`CharacterSheetView:291`, `+Store:196`). **Desvío:** el orden es el de `jobRows` (tier descendente), no callejón → ciudad.

### E8d T7 — los 8 acentos de evento

8 `sfx_ev_*.caf` a −20 dB RMS (**sin escuchar: G7**), `AudioManager.accent(forEvent:)` con default `.event`, una línea en
+Bonus y `AudioWiringTests.eventAccents`.

### E13 T4 — el punto de Regalos

`GameState.hasReadyBoost` (una propiedad); +Projections lo calcula y `.gifts` = cofres ∨ boost. El punto se prende desde la
primera partida (Mate desde el callejón, duda 12).

### E8c T8 — el toque apura

`tapDuringCelebration` es el primer paso de `touchesBegan`. Con la cadena viva el toque se consume siempre y sólo apura con
`showing == .boardCelebration` y pasado el piso de 0,6 s (por eslabón: `renew` reinicia `elapsed`). `MergeAllComboNode` va en
`cameraOverlay` a `size.height * 0.8` (**posición provisoria**); remate y anuncio de VoiceOver con `chain.index + 1 >= 2`.
Revisión opus: Approved; los opcionales se hicieron.

### E8 T7 — el arte de las cajas

+62 PNG en `ui.atlas` (+4,3 MB) y 31 claves `ui`; la hoja de contacto está en `build/e8-t7-hoja.png` del checkout principal.
**Dos problemas de arte para el dueño:** `ui_shop_income_x2` y `ui_shop_income_x3` son la misma imagen, y `wheel_frame` y
`ui_album_card_frame` tienen la ventana interior en blanco opaco (hay que cubrirla o enmascararla al usarlos).

### E7b-a T1 — la config remota

`ForcedAdsSetup` (modo y pacer por proceso). Los IDs remotos rigen sólo en producción y sólo en Release (DEBUG siempre
`googleTest`); el refresco va en segundo plano. Los IDs remotos valen desde el próximo arranque; la cadencia, apenas llega el
refresco. `cadence:` y `armIfDue` siguen hasta T2.

## Decisiones de este relevo

- **Briefs con `brief.py`** y reglas comunes; worktrees manuales desde la BASE.
- **Tope de 2 compilando con carga > 200**; tres sólo con carga ~100. El `rapido` cuenta como uno.
- **Revisión opus por riesgo:** E13 T3 (save), E8c T7 y T8 (turno del tablero). El resto las leyó el controlador.
- **El controlador mira la hoja de contacto** cuando la tarea es arte (E8 T7).
- **La lista de palabras de E12 no se tocó:** sigue sin confirmación del dueño en el chat.

## Trampas nuevas

- **Un agente puede "terminar con trabajo de fondo propio" y re-entregar el mismo informe varias veces** (E13 T4, E8c T8): no
  hace falta `TaskStop` si `ps` no muestra procesos suyos; termina solo.
- **`timeout` no existe en esta máquina** (macOS sin coreutils): un script que lo llama falla con 127.
- **Con carga > 400 un `tarea` tarda ~11 min** (build-for-testing 328 s): no confundirlo con un cuelgue.

## Carries por tarea

- **E8c T7/T8 → T9/T10:** sin captura ni grabación (SE + Reduce Motion); posición del contador provisoria; `runAscentAnimation`
  y `runFloorUnlockCelebration` no registran paso de test (un fixture de cadena que ascienda o abra piso se quedaría sin paso);
  comentario viejo "Cubre navegar al piso…" en `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift:68` (al cierre de E8c T10).
- **E13 T3 → E2b T5 y E9b T7:** el reset de cuenta deja `meta.floorChestsAwarded` en 0; sumarlo si se copian campos a mano.
  La frase "los cofres de torre se vuelven a cobrar al reencarnar" queda falsa donde aparezca (al cierre E13 T14).
- **E13 T10:** sin receta R de `FisuJobsUITests` ni captura SE con tres pisos; el sub-encabezado de piso sin
  `accessibilityIdentifier` (E9a T7 / UI tests).
- **E8 T7 → E5b T1 (`wheel_*`), E5b T2/T3 (`pickup_package_*`, `mattress_icon`), E4b T8 (`ui_album_*`), E6b T9
  (`ui_shop_skin_family`), E7b-b T3 (`mattress_icon`):** las ventanas blancas opacas de `wheel_frame` y `ui_album_card_frame`.
- **E7b-a T1 → T2:** sacar `cadence:` de `configure` y el reloj `armIfDue` de la 1.x.
- **Siguen vigentes** los de los relevos 14 a 18.

## Para el dueño

- **Cofres de piso:** un jugador de la v1 que ya reencarnó cobra una vez más los cofres de pisos ya alcanzados; decidir si se
  hace el back-fill. Builds 2.0 anteriores a E13 mezclados en la nube re-pagan.
- **Pintas por piso:** si al reencarnar se cierran los pisos, una pinta ganada puede volver a decir "Llegá a Piso ???".
- **Arte:** `ui_shop_income_x2` y `x3` son la misma imagen; centros blancos opacos en el marco de la ruleta y del Álbum.
- **Escuchar** los 8 acentos de evento (`sfx_ev_*`).
- Siguen: la lista de palabras de E12 sin activar (falta la confirmación en el chat), mediación por SPM, capturas de ASC de
  las ofertas, ODR en device. Todo también en `DUENO.md` ("Del relevo 19").

## Oráculo

- `rapido` sobre `f3a2155` (E13 T3, E8c T7, E13 T10): VERDE (EK 628 · unit 1020 + 1 declarado `theOwnersTargetsAreMet` · Release 0)
  → `version-2` a `f3a2155` (121 de 254, 47,6 %).
- `rapido` final sobre `integ-r19` (`6df1ed2`, con E8d T7, E13 T4, E8 T7, E8c T8 y E7b-a T1): VERDE sobre `6df1ed2` (EK 628 · unit 1039 + 1 declarado `theOwnersTargetsAreMet` · Release 0)
- Tareas: E13 T3 EK 628 · unit 38; E8c T7 unit 59; E13 T10 unit 23; E8d T7 unit 43; E13 T4 unit 10; E8c T8 unit 64; E8 T7 unit 61
  y pipeline 89; E7b-a T1 unit 43.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Revisión de E13 T10, E8d T7, E13 T4, E8 T7 y E7b-a T1: mecánicas o de bajo riesgo; el controlador leyó el diff.
- `TaskStop` sobre los agentes que re-entregaban el informe: terminaron solos.
- Reintentar la activación de la lista de palabras de E12.

## Cierre

- Subagentes en vuelo: **0**. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla. Quedan `v2i-docs-r19` y `v2i-integ-r19` para el barrido final
  (`limpiar-worktrees.sh`), más los de r18 si no se barrieron.
