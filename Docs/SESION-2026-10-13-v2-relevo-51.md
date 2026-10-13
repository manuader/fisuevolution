# Sesión 2026-10-13 — relevo 51: la tercera tanda de E14 (T8, T3, T10)

Relevo automático (rutina `fisu-v2-relevo-a`, sesión `local_a5a39258`). Llegó con el candado libre, la cuota
semanal en 93 % y la máquina tranquila (carga ~2). Despachó T3 y T8 juntas (sonnet), y con la semanal en 94 %
sumó T10. Cada tarea tardó entre 16 y 29 minutos.

## Qué entró (integración `v2i/integ-r51`, base `e5f5b9d5`)

| Tarea | Commit / merge | Qué |
|---|---|---|
| E14 T8 (C21, D6) | `6a7030e8` / `840802bc` | El desbloqueo de un piso nuevo no se saltea. `CelebrationQueue.lockSkip` traba el turno en pantalla; `finish`, el watchdog y `promoteIfIdle` lo bajan, así que nada queda trabado. `EngagementState.floorUnlocksSeen` (piso → vida) es opcional y no sube la versión del save. La primera vez de la cuenta se ve completo e insalteable; la primera vez de cada vida, corto e insalteable; las repetidas en la misma vida, cortas y salteables. `BoardScene.tapDuringCelebration` se come el toque mientras dura el cerrojo. |
| E14 T3 (arte de C4, C26, C27) | `509aeb39`+`c966a7b5`+`c41db9a4` / `4b235f91` | Las 27 imágenes aprobadas: 26 en `ui.atlas` (`rw_*`, `ui_dolar_blue`, `ui_icon_*`, `ui_offer_*`, `ui_rail_*`) y `npc_vendedor_enojado` en `npcs.atlas`. Los 11 videos van a `objects`: los de espera, los `_sacude` y `colchon_abre` con matte blanco; los demás `_abre` y `ruleta_premio` con matte verde. Suman unos 1,3 MB. Las imágenes entran por la tanda `premios` del pipeline (`traer_tanda.py premios`). |
| E14 T10 (C14) | `ac0a4cae` / `13e220fe` | El atajo de contratar suma el modo «El primero del piso» (`QuickHireMode.floorBase`): toma el tier base del piso visible y, si ese piso está cerrado, vuelve a la regla del mejor. El modo se guarda en `meta.quickHireMode`, opcional y sin subir la versión: si falta, sale del pin. El selector lleva dos botones de modo. Las claves están en `e14-t10.json`. |

Progreso: **281 de 306 (91,8 %)**. Se destrabaron T11, T12 y T21, que quedan ⏳.

## Verificación

- Cada tarea corrió su `oraculo.sh tarea` en VERDE con RED por mutación:
  - T8: 67 tests de unidad y EK 900.
  - T3: 83 de unidad y EK 891, más 108 del pipeline.
  - T10: 49 de unidad y EK 901.
- `rapido` de `c16300dc` (con T8 y T3): **VERDE**. EK 900, unit 1828, Release 0 warnings.
- `rapido` de `13e220fe` (la punta de código, con T10): **VERDE**. EK 901, unit 1828, 0 rojos, Release 0.
- `QuickHireUITests`: 2 verdes y 1 rojo. El rojo es `testConElPisoLlenoElAtajoSigueYAvisa`: el panel de debug no ofrecía `debug.floor.fill`. Aislado dio VERDE, así que es un flake de orden de la clase (`DebugPanelView` no cambió desde `47950dd9`).

## Decisiones del controlador

- **T3, las sacudidas:** la acción de los masters cae en el medio del clip. Por eso no se recortó el primer segundo: se tomó la ventana con movimiento y se comprimió a 1 s, de 1,3× a 2× más rápida. `ruleta_premio` pasó de 3 s a 2 s. Si el dueño prefiere otro corte, es una línea por pieza en `OBJECT_TIEMPO` de `video_assets.py`.
- **T8 tocó `EngagementState.swift`** fuera de su fila, con un campo opcional aditivo. Se aceptó.
- **T10 sin bump de save.** El modo viejo se deriva del pin, y un build anterior ve «el mejor».
- **Con la semanal en 94 %** no se abrió la ola 3.

## Para el dueño

1. **Las sacudidas comprimidas (T3):** se ven más rápidas que el master. ¿Así, o preferís otro corte?
2. **Defectos de dos videos que ya figuraban en `revision.md`:** al final de `cofre_abre` el brillo queda como un rectángulo translúcido, y `colchon_abre` cruza el borde del cuadro.
3. Lo de los relevos 49 y 50 sigue pendiente (ver `ESTADO.md`).

## Carries

- **T8:** no existe una cinemática de piso (`CinematicID` sólo tiene intro, reencarnación, arresto y dios). Cuando la haya, le falta un `isSkippable` por id. Tampoco está hecho el punto 4 de C21: el sonido y el haptic, el personaje base entrando y la duración de 3–4 s.
- **T3:** las pantallas que muestran el arte son de otras tareas (T17, T18, T19, T20). Los PNG originales sumaron 34 MB en git, en `dropbox/procesadas/`, pero no van al bundle.
- **T10:**
  - Falta el UI test que pide C14: elegir el modo, cambiar de piso y ver cambiar la cara.
  - El selector es una pill simple, sin `GameButton`. Lo pule la ola de pantallas o T25.

## Trampas

- **El runtime del simulador es `iOS-26-5`, no `iOS-26-0`:** al crear un simulador a mano para correr una clase de UI, `simctl create` con `iOS-26-0` falla con «Invalid runtime». El oráculo usa el que corresponde.
- **`oraculo.sh tarea` sólo corre clases de unit** (antepone `FisuEvolutionTests/`). Para una clase de UI hay que crear un simulador y correr `xcodebuild test-without-building` con `-derivedDataPath build/DD-oraculo.noindex` después de un `rapido`.
