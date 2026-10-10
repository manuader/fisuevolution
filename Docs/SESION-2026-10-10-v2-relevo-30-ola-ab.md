# SESION 2026-10-10 — v2, relevo 30: los recortes del dueño y el Estudio entran, y los videos empiezan a verse en el juego (E8e)

La ola AB. El relevo 30 arrancó a las 18:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 29 lo soltó a las 17:49), la cuota en 5 h 10 % y semanal 64 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); un opus para el plan de E8e T10 (sólo doc). No hubo revisión opus de código: ninguna tarea de la ola toca plata, save ni turno de tablero, y el controlador leyó cada diff.
Todo pasó por **`v2i/integ-r30`** (BASE `version-2` en `6f91d64`, 208 de 254). Los briefs y la tabla de dueños salieron de `v2i-integ-r30/.superpowers/sdd/ola-r30/` (`comun.md`). Latido: un bucle de fondo con `sleep 600` que reescribe `ultimo_latido` y se corta solo si el `LOCK` deja de estar TOMADO.
`fisu-v2-relevo-b` no existe (`list_scheduled_tasks` sólo lista `relevo-a`). Carga: 1,6 al arrancar; 446 con tres tareas y un `rapido` compilando (por eso no se despachó más hasta que bajó); 194 después.
El contexto llegó a ~215k al lanzar el `rapido2`, ~232k al despachar E8e T5 y ~248k al cierre: ésa fue la última tanda y se cerró con los subagentes de tarea en 0.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | `56d7bfb`, la punta tras el `rapido3` VERDE de `integ-r30` sobre `c2708aa`: **213 de 269 (79,2 %)** |
| `v2i/integ-r30` | `6c4a770` (suma E8e T5, 🟢) y los docs del cierre (`v2i/docs-r30b`) |
| Progreso | 208 al llegar → 209 (E8 T9, `rapido1` sobre `2dcf084`) → 211 (E8e T1 y T7, `rapido2` sobre `76de0ff`) → **213** (E8e T2 y T3, `rapido3` sobre `c2708aa`) |
| `rapido4` | **EN CURSO sobre `6c4a770`** (`build/relevo30-rapido4.log`, PID 99084): decide E8e T5. Al escribir esto estaba en `build-for-testing` |
| El total subió de 254 a 269 | el plan E8e (9 tareas) y el de E8e T10 (6 tareas, 10a–10f) entraron al tablero; E8 T9 y E8e T1–T3, T5 y T7 se suman a las integradas |
| Bloqueadas | ninguna nueva. E8e T1 ✅ destraba T2, T3, T4 y T8; **E8e T4 queda ⏳**, T6 espera a E5b T3 y T8 a una ventana de `BoardScene` |

Los cuatro `rapido` de la ola, todos `--limpio`:

| `rapido` | Punta | EK | unit | Release | Entró |
|---|---|---|---|---|---|
| 1 | `2dcf084` | 845 | 1417 | 0 | E8 T9 (los recortes del dueño y el Estudio de assets) |
| 2 | `76de0ff` | 845 | 1435 | 0 | E8e T1, E8e T7 y B22 |
| 3 | `c2708aa` | 845 | 1444 | 0 | E8e T2 y E8e T3 (atlas nuevo) |
| 4 | `6c4a770` | en curso | en curso | en curso | E8e T5 (si da VERDE) |

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos y carries |
|---|---|---|---|
| **E8 T9** los recortes del dueño + el Estudio de assets | `2dcf084` (merge de `v2/estudio-assets`, que trae `v2/e8-recortes` `32a3b29` debajo) | `rapido1` VERDE; pipeline 94 · estudio 15 | Cierra E8 T9 (Step 3: las elecciones del dueño ya estaban aplicadas en su rama). El plan E8e entró por cherry-pick (`bba2385` → `a360450`; conflicto en `tasks.md` §4.1: quedó la fila 1 del 29 y la fila 0 de E8e). Las ramas del dueño no se reescribieron |
| **Plan E8e T10** el tablero animado con los videos base | `f5dc07f` (cherry-pick, sólo doc) | opus, sólo doc | 6 tareas (10a–10f), 12 dudas con default; **gate 🔒 del dueño en el SE antes de integrar: ≥ 59 fps, ≤ 1 % de cuadros > 25 ms, animado − quieto ≤ 20 MB**; T10d son tres líneas de `BoardScene`, después de E5b T3. Filas en `tasks.md` §5 y §3.1 |
| **E8e T1** `ArtClips` y el contrato manifest ↔ contenido | `a8d3da4` (merge `17e4430`) | RED visto (sin `ArtClips` no compila); tarea VERDE EK 845 · unit 25; diff leído. ✅ con el `rapido2` | Resolvedor puro + 9 tests + 6 contratos en `LoopsManifestTests`. La tabla ítem → clip de la tienda está en `ArtClips.shopIconKeys` (`ui_oro_*` ≠ `ui_shop_*`); `ui_oro_extra_slots` en `pendingShopIcons` (E6b T7 lo mueve o el contrato queda rojo) |
| **E8e T7** el Álbum, con la tarjeta enfocada animada | `8a879e6` (merge `360d5b2`) | RED visto; tarea VERDE unit 5; `SpecialsAlbumUITests` 1/1 claro y oscuro; diff leído. ✅ con el `rapido2` | `AlbumFocus`: sólo la tarjeta enfocada **y tuya** monta `AnimatedArtView(.character(sp_*), .popup)` con el póster debajo; tap enfoca; el id `album.card.*` no cambia. Las capturas sin `--uitest-video` muestran el póster quieto: **el movimiento real no se vio (🔒 dueño en device)** |
| **B22** privacidad: tracking, IA en la política, atajo a App Review | `addbc12`, `ed4dd6a`, `8e1045e` (entró con el `rapido2`) | `PrivacyManifestTests` VERDE unit 5; releaseops 13 OK; diff leído | Test `trackingNeedsDomains`; la política nombra a Anthropic (sólo recibe el nombre; verificado en `supabase/functions/_shared/prod.ts`); `reviewNotes` con el atajo al Ranking, 3970 de 4000 caracteres. **`NSPrivacyTracking` sigue en `false` a propósito** (ver trampas). No tiene fila en `tasks.md` |
| **E8e T2** el visitante habla y actúa en el escenario | `d2b6d63` (merge `d37611a`) | RED visto; tarea VERDE unit 32; `VisitorUITests` 2 y `VisitorMechanicsUITests` 3; captura 16 Pro con `--uitest-video`; diff leído. ✅ con el `rapido3` | `VisitorNode.showClip` con `LoopingVideoNode .popup` (el actor suelta su textura); `StageController` pide `ArtClips.stageVisitor` esperando, y entra y sale sin video; `visitorArrive` una vez por visita y `talkBlip` por globo nuevo; sin `BoardScene` |
| **E8e T3** la ilustración del evento, animada | `20500d6` + `666f614` (merge `c2708aa`) | RED visto; pipeline 94; tarea `--limpio` VERDE unit 34; capturas SE y 16 Pro; diff leído. ✅ con el `rapido3` | 8 pósters `ui_event_*` al `ui.atlas` por `process_dropbox`, tanda e8e en `prompts.json`; `EventPopupView.illustrationClip` + `AnimatedArtView .popup` de 120 pt, detent 0,62 con ilustración |
| **E8e T5** el colchón espera y se abre | `6809336` (merge `6c4a770`, 🟢) | RED por mutación (`PrizeAccessTests.theMattressVideoPaysOnce` + 2 de `MattressStageTests`); tarea VERDE unit 4; `PrizesUITests` 2/2; diff leído. **Falta el `rapido4`** | `MattressStage` waiting → opening → revealed: `colchon_espera` en loop, `colchon_abre` `.once` → resultado. El premio se acredita **como antes** en `mattressVideoWatched`, sin guard nuevo; Reduce Motion → resultado al toque |
| **Docs B1–B26** | `6e280f3` | sólo docs | `tasks.md` §7 + `HANDOFF` §5.22: los 26 defaults del dueño como decisiones que no se re-litigan. `DUENO.md` marcado |

## Carries

| A | Qué |
|---|---|
| **Dueño (device)** | el movimiento real nunca se vio en simulador: Álbum (T7), visitante (T2), ilustración del evento (T3) y colchón (T5; `colchon_abre` por ODR en simulador). Hace falta un pase en un iPhone con `--uitest-video` apagado |
| **E8e T2** | `visitorArrive` suena también con el presentador de evento: ¿sólo visitantes? (un `if case .visitor`); captura SE pendiente |
| **E8e T3 / dueño** | aguinaldo, blanqueo y `startup_comprada` duran **0 s**: su ilustración no se ve nunca (otra superficie; decide el dueño). `EventChipUITests` y `CorralitoUITests` no corridos: al `completo` |
| **E8e T5** | el tamaño del video pasó de 88 a 160 pt y el detent a 0,66 en la apertura; los sonidos del colchón siguen en `pendingWiring`. Mientras no haya movimiento visto en device, T5 depende del `rapido4` |
| **E8e T1 / E6b T7** | `ui_oro_extra_slots` en `pendingShopIcons`: quien haga E6b T7 lo mueve o el contrato queda rojo |
| **B22 / dueño** | los dominios de tracking (AdMob, Unity, Meta): ninguno confirmable desde el repo ni el SDK. Sin ellos `NSPrivacyTracking` no pasa a `true` |
| **B10 / B15 → E9b T8** | los avisos del reset de cuenta (un ×3 pagado, las pintas de ORO) no tienen fila: van al brief de E9b T8. **B24** (chip vs columna) → gate A8 |
| **Los del 29** | siguen: E6a T12, E5b T3, E7b-b T1, E5b T5, E8d T15, E9b T8, E2b/E11, E12 (los dos UI por orden) |

## Trampas nuevas

- **Un test que nace verde y no prueba nada:** `doubleVideoPaysOnce` (E8e T5) pasaba sin el arreglo. La tarea lo comprobó **por mutación** (romper el código y mirar que caiga) y quedó `theMattressVideoPaysOnce` más dos de `MattressStageTests`. Todo test de un pago único se prueba por mutación, no sólo por verlo en verde.
- **Los eventos de 0 s no muestran su ilustración:** si el evento dura 0 s (aguinaldo, blanqueo, `startup_comprada`), el popup nunca llega a mostrarse. Una ilustración animada nueva se comprueba contra la duración real del evento antes de dar la tarea por vista.
- **`NSPrivacyTracking = true` sin `NSPrivacyTrackingDomains` = rechazo ITMS-91064** (la v1 lo sufrió dos veces). Por eso B22 deja `false` hasta que el dueño confirme los dominios; el test `trackingNeedsDomains` lo cuida.
- **No se toca el árbol de `integ` mientras corre un `rapido`:** T1, T7, B22 y T5 esperaron a que terminara el `rapido` en curso para mergearse. Mergear en medio compila otra cosa que lo que se declara.
- **Una captura sin `--uitest-video` es el póster quieto:** declarar «se ve» exige la captura con el flag, y aun así el movimiento real se mira en device.
- **Carga 446 con tres tareas y un `rapido`:** tres compilando + `rapido` exceden el cupo con la máquina cargada; el controlador no despachó hasta que bajó (194).
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`», las claves por snapshot, `rapido` uno por vez, el `.xcodeproj` no versionado, los UI que se contaminan por orden.

## Para el dueño

- **Mirar en un iPhone, sin `--uitest-video`:** el Álbum con la tarjeta enfocada, el visitante hablando, la ilustración del evento y el colchón esperando y abriéndose. Nada de eso se vio moverse todavía.
- **Eventos de 0 s** (aguinaldo, blanqueo, `startup_comprada`): su ilustración no se ve nunca. ¿Se les da una pausa de popup o se queda sin ilustración?
- **B22:** `NSPrivacyTracking` sigue en `false`. Hacen falta los dominios de AdMob, Unity y Meta para pasarlo a `true` sin que Apple rechace.
- **E8e T10 (tablero animado):** el spike lo mide el dueño en su SE (≥ 59 fps, ≤ 1 % > 25 ms, ≤ 20 MB). Sin esa medición T10b en adelante no se despacha.
- Siguen `PREGUNTAS-DUENO.md` (A1–A10 gates; B1–B26 ya con su default), el reset que pierde las pintas de ORO, `skinsAll` a 1350 ORO, y los del 29 y anteriores.

## Oráculo

- `rapido1` `2dcf084`: VERDE (EK 845 · unit 1417 · Release 0): E8 T9 ✅, 209 de 269.
- `rapido2` `76de0ff`: VERDE (EK 845 · unit 1435 · Release 0): E8e T1 y T7 ✅ (B22 entra con ellas), 211 de 269.
- `rapido3` `c2708aa`: VERDE (EK 845 · unit 1444 · Release 0): E8e T2 y T3 ✅, 213 de 269 (79,2 %).
- `rapido4` `6c4a770`: **en curso**. Veredicto en `build/relevo30-rapido4.log`; si es VERDE, E8e T5 ✅ (214 de 269) y `version-2` avanza por ff.
- No hubo `completo` en la ola: el último VERDE es el del 29 (`7c494ea`). Lo pide E8d T15 y E8e T9.

## Lo descartado

- Un `completo` en esta ola: cada merge se cubrió con su `rapido --limpio` y las tareas de E8e no tocan plata ni save; el `completo` queda para E8d T15 y el cierre de E8e.
- Despachar E8e T4: comparte `OroShopView` con E6a T12 (y E6b T7), y E6a T12 todavía no se despachó. Queda ⏳ para cuando no corra en paralelo con T12.
- Despachar E8e T6 (necesita `BoardScene`, espera a E5b T3) y T8 (ventana de `BoardScene`).
- Reescribir las ramas del dueño (`v2/e8-*`, `v2/estudio-assets`): se integraron tal cual con `--no-ff`.

## Cierre

- Subagentes de tarea en vuelo: 0 al despachar los docs del cierre. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla (`v2i-e8e-t1` 1667 MB, `v2i-e8e-t7` 1680, `v2i-b22` 1670, `v2i-e8e-t10-plan`, el de docs B1–B26, `v2i-e8e-t2`, `v2i-e8e-t3`, `v2i-e8e-t5`); quedan por barrer `v2i-integ-r30` y `v2i-docs-r30b`, más los de relevos anteriores si no se barrieron. Un `--apply` por worktree.
  `v2-e8-recortes`, `v2-e8e-plan` y el de `v2/estudio-assets` **no son `v2i-*`: no tocar.**
