# SESION 2026-10-09 — v2, relevo 21: el viaje que suspende los videos, la pestaña del ranking en una barra de seis, los premios por video nuevos, la ficha con Despedir y el pacing que frenó el toque premiado

Relevo 21 de la ejecución autónoma de la 2.0, arrancado a las 15:03 del 9 de octubre (lo despertó el disparo horario de la rutina
`fisu-v2-relevo-a`; `LOCK` libre desde las 14:34). Controlador opus; implementadores sonnet en worktrees manuales
(`worktrees.nosync/v2i-<tarea>`) con briefs de `Tools/v2/brief.py` y reglas comunes; revisor opus para E8d T10 y E13 T2.
Todo pasó por la rama de integración **`v2i/integ-r21`** (BASE `version-2` en `929ffca`). Cuota al llegar: 5 h 4 %, semanal 51 %.
Carga de la máquina: 1,35 → 173 → 448 → 706 → 653 → 536 → 135; tope de 2 compilando cuando pasaba de 200 (y a veces ni así).

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`7604768`**: el `rapido` sobre `cad2d93` (E8d T10 + E12 T13) dio VERDE y avanzó por fast-forward |
| `v2i/integ-r21` | **`3424ae5`** + los docs del cierre (`v2i/docs-r21`): suma E13 T2 y E13 T9 (🟢) y sus claves de i18n |
| `rapido` | sobre `cad2d93`: VERDE (EK 636 · unit 1060 + 1 declarado · Release 0). Final sobre la punta de `integ-r21` (`3424ae5`): VERDE sobre `3424ae5` (EK 637 · unit 1066 + 1 declarado `theOwnersTargetsAreMet` · Release 0) |
| Progreso | **135 de 254 en `version-2` (53,1 %)**; **137 de 254 (53,9 %)** si el `rapido` final de `integ-r21` da VERDE (`tasks.md` §2) |
| Bloqueada | **E13 T7** (toque premiado, seis líneas): rama `v2i/e13-t7` (`5d587c6`) pusheada, **sin integrar** |

## Lo que se integró (4 tareas)

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E8d T10** el viaje suspende los videos, la cabina reserva su decodificador, `sfx_elevator_cable` | `81ef301` + `87de6ab` | tarea VERDE (unit 47); Receta R `ElevatorRideUITests` 3/0; revisión opus: Approved con arreglos, hechos |
| **E12 T13** la pestaña del ranking montada | `909a6e8` (+ clave `hud.ranking.label`) | tarea VERDE (unit 43); `RankingTabUITests` 6/6 en SE; captura SE mirada por el controlador; diff de `RootView` y `+Tabs` leído |
| **E13 T2** premios por video: regalo de frontera − 3 y «Fusionar todo» | `439b6e6` | 🟢; tarea VERDE (unit 102 · EK 637); revisión opus: Approved sin obligatorios |
| **E13 T9** la ficha y Despedir desde Personajes | `080a4cd` | 🟢; tarea VERDE (unit 17); Receta R `CharacterSheetUITests` 3/3; diff de `+Actions` leído |

### E8d T10 — el viaje y los decodificadores

`Warmup` reserva y libera contra un pool inyectable; el overlay lleva `.suspendsVideoPool(phase != .idle, .elevatorRide)`; el cue `.cable`
vive en `ElevatorRide.swift` (fuera de la lista del plan, en la tabla pura). **Revisión opus (Approved con arreglos):** la reserva se hacía
al abrir el viaje y vencía a los 45 s; después de eso `closingPlayer` nacía en frío sin reserva y el fundido de llegada tenía cuatro
decodificadores. Arreglo en `87de6ab`: `reserveDecoder` al crear `closingPlayer`/`openingPlayer` y el test `lazyPlayersReserve`; doc de «un
solo player» corregida. La Receta R de `ElevatorRideUITests` (que el implementador había salteado) se corrió después: 3/0.

### E12 T13 — la barra de seis

La Tienda salió de la barra, así que quedaron **seis pestañas** (no siete): `[ranking, upgrades, skins, jobs, gifts, menu]`,
`slotsPerSide` 3 y platos de pestaña de **44 pt** (`tabPlateSide`; `plateSide` 52 y `barHeight` 84 no cambian, `BoardScene.bottomInset`
tampoco). En el SE entran: 372 ≤ 375. El interruptor oculta `.ranking` con `!isEnabled`, así que **en producción la pestaña no aparece hasta
E12 T16** (`baseURL` nulo). `onStore` abre la Tienda como `menuSession.start = .store` con `.id(session.start)` (no es página del paginador).
`RankingView` lleva una X (`sheet.close`).

### E13 T2 — los premios por video

`giftType` en frontera − 3 con piso 1; `Origin.rewardedMergeAll` reusa la cadena de E8c y **no compensa por eslabón** (una cadena descartada
entera no paga ni compensa); `merge_all` con cooldown de 600 s; `rewardText` de instancia. Claves: `quitar(3)` y después `aplicar(5)`.

### E13 T9 — la ficha

`characterSheet(forTypeId:)` abre el visible primero y, si no, el primer piso con la unidad (`-1` sin unidades); `canDismiss` exige piso ≥ 0
e instancias; `dismissCharacter(floorOrdinal:slot:)`; botón «Ficha» en `UpgradesView`. El test nuevo pasó en la segunda corrida (selector).

## Lo que quedó bloqueado: E13 T7 (el toque premiado, seis líneas)

El plan pide la línea `lucky` con 20 niveles y costo ×1,09 (193 → 192 ORO). El implementador entregó `5d587c6` con la tarea en ROJO
(unit 95/4): dos fallos de localización que se resuelven al integrar (claves sin aplicar) y **dos `PacingTests` reales**. Con el
`upgrades.json` viejo la tarea da VERDE, así que el rojo es de la línea nueva, no de la base.

| Medida del contrato | Con `lucky` 20/×1,09 (plan) | Pide el contrato |
|---|---|---|
| Reencarnaciones para maxear | **9** | ≤ 8 |
| Paredes | **4** | ≥ 5 |
| Corrimiento | **−2** | ≥ 4 |
| Dios (horas activas) | **31,34 h** (antes 30,73) | el plan manda parar si se mueve más de 0,5 h: **+0,61** |

El controlador, con el margen del plan («la curva y el tope los vuelve a mirar E2b»), pidió una búsqueda chica (≤ 8 variantes: `costGrowth`
→ `baseCost` → `maxLevel`) de la más cercana al plan con `PacingTests` verde y Dios dentro de 0,5 h. El agente probó **10 variantes**
(`costGrowth` 1,07–1,14, `baseCost` 1–2, `maxLevel` 16–20) y **ninguna** quedó a ±0,5 h de 30,73: Dios sólo cae en 31,34, en 29,4x o
en 28,10 h. Con `maxLevel` 16 o con `baseCost` ≥ 1,5 «las 7 al tope» sale de la banda 20–30. Además, el simulador por CLI da 9 reencarnaciones
**también con el catálogo viejo**: no replica el umbral de `PacingTests`, así que no sirve de vara para esto. `upgrades.json` quedó en el plan
(20 / 1,09) y la tarea quedó ⛔ en `tasks.md`.

**Opciones para el dueño** (también en `DUENO.md`):

1. **Aceptar Dios en 31,34 h** y re-pinear las bandas de `PacingTests` (la más barata; mueve el contrato del plan en +0,61 h).
2. **Recalibrar con la magnitud o con el reparto crítico/dorado** de la línea `lucky`, no con su curva de costo.
3. **Dejarla para la búsqueda de E2b T14**, donde la calibración final ya mira todo junto.

No es decisión de un agente: toca el contrato de pacing del dueño (E2b). Lo descartado: recalibrar sólo con la curva de costo de `lucky`.

## Decisiones del controlador

- **La barra de seis pestañas con platos de 44 pt** (E12 T13). El plan hablaba de siete; la Tienda ya no está en la barra y con 3 lugares por lado
  el plato de 52 no entra en el SE (372 contra 375 con 44). Se mira en captura. El plan B (tarjeta en la Oficina) no hizo falta; se le pregunta
  al dueño si el plato de 44 le sirve.
- **Búsqueda acotada de pacing para E13 T7** antes de dar la tarea por bloqueada (ver arriba): se agotó y se revirtió el cambio.
- **Revisión opus por riesgo:** E8d T10 (decodificadores, frame loop) y E13 T2 (dinero). E12 T13 y E13 T9 las leyó el controlador (diffs chicos).
- **Dos `rapido` en la ola:** el primero sobre E8d T10 + E12 T13 (VERDE, `version-2` avanza); el segundo, sobre la punta con E13 T2 y E13 T9.
- **Cierre por contexto:** a ~208k el controlador dejó de despachar y sólo esperó lo que estaba en vuelo (E13 T9 fue lo último en salir).

## Trampas nuevas

- **Un agente corrió `pkill -f "x"` por error** (~15:08, `v2i-e13-t7`) y pudo matar procesos de otros: probablemente el primer latido (salió
  con 144 a las ~15:11) y alguna corrida ajena. Sólo `kill <PID>` propio. Las «exit 144» posteriores eran kills del propio controlador.
- **`sleep 600` dentro del latido se colgó 65 min con la carga en ~500** (último latido 15:41, descubierto a las 16:47). Un `sleep` largo bajo carga
  se estira sin avisar. El latido ahora es `scratchpad/latido.sh`: `sleep 30` y escritura por reloj (cada ≥ 9 min), de modo que un retraso no lo
  deja mudo.
- **Los agentes borran simuladores `oraculo-*` «por tiempo» en vez de por UDID** (E8d T10): puede llevarse el simulador de otro agente que está
  corriendo. Borrar sólo el UDID propio.
- **El script de limpieza conserva un worktree si tu propio shell tiene el `cwd` adentro:** salir del worktree (usar rutas absolutas) antes de
  `limpiar-worktrees.sh`, o queda sin barrer.

## Carries por tarea

- **E8d T10 → T15 y el dueño:** el sonido del cable (1,2 s) **se superpone con el ding** en los tramos de un piso y sigue sonando si se saltea:
  para escuchar en el iPhone. Opcional de la revisión: nota de Reduce Motion en el doc. Sin `ElevatorRideUITests` antes del arreglo (hoy 3/0).
- **E12 T13 → T16:** la pestaña no aparece en producción hasta que el ranking tenga servidor. Se pregunta al dueño por el plato de 44 pt. Una sola
  pasada de `RankingTabUITests` en SE (en dos tandas, con carga ~340).
- **E13 T2 → E6a / E7b-b / E2b:** (1) `BoardChangeWiringTests.inactiveSettlesOnlyWhatWasPaidFor` tiene un límite flojo (`settled <= units - links`):
  fijarlo exacto. (2) `rewardUnavailableReason(.mergeAll)` ignora `pendingBoardChanges`: un video podría planear pares de una cadena ya en fila y no
  pagar → a E6a (por ORO) y E7b-b. (3) «Te llega un %@, de regalo» es masculino fijo. **Al dueño:** `merge_all` de 600 s da más valor que la
  Evolución gratis (14400 s) → E2b; frontera − 3 cae en pisos llenos más seguido y con frontera ≤ 4 es un tier 1 por video.
- **E13 T9 → E9b T1:** texto de `tutorial.character_sheet.hold` (la pista de mantener apretado).
- **E13 T7 → el dueño y E2b T14:** ver arriba. Cuando se resuelva, la rama `v2i/e13-t7` está lista salvo el pacing; el reset de cuenta (E2b T5 / E9b T7)
  tiene que sumar `meta.floorChestsAwarded` si copia campos a mano.
- **Siguen vigentes** los de los relevos 14 a 20.

## Para el dueño

- **Decidir E13 T7** (tres opciones arriba).
- **¿Te sirve el plato de pestaña de 44 pt** (la barra de seis), o preferís el plan B (una tarjeta en la Oficina)?
- **Premios por video:** «Fusionar todo» cada 10 min da más valor que la Evolución gratis de 4 h; el regalo cae en pisos bajos que suelen estar
  llenos y con frontera ≤ 4 es un tier 1; «Te llega un %@, de regalo» es masculino fijo. ¿Así está bien?
- **Escuchar** el cable del ascensor (1,2 s) contra el ding en los viajes de un piso.
- Siguen: la lista de palabras de E12 sin activar (falta la confirmación en el chat), mediación por SPM, el fondo animado y la revelación en device
  (G1/G2/G3/G5), «Opciones de privacidad» en región UE, capturas de ASC, el back-fill de los cofres de piso de la v1. Todo también en `DUENO.md`.

## Oráculo

- `rapido` sobre `cad2d93` (E8d T10 + E12 T13): VERDE (EK 636 · unit 1060 + 1 declarado · Release 0) → `version-2` a `7604768`.
- `rapido` final sobre la punta de `integ-r21` (`3424ae5`, con E13 T2 y E13 T9): VERDE sobre `3424ae5` (EK 637 · unit 1066 + 1 declarado `theOwnersTargetsAreMet` · Release 0)
- Tareas: E8d T10 unit 47 · Receta R `ElevatorRideUITests` 3/0; E12 T13 unit 43 · `RankingTabUITests` 6/6; E13 T2 unit 102 · EK 637; E13 T9 unit 17 ·
  `CharacterSheetUITests` 3/3; E13 T7 ROJO (unit 95/4).
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Recalibrar E13 T7 sólo con la curva de costo de `lucky` (10 variantes, ninguna sirve).
- Revisión aparte de E12 T13 y E13 T9: diffs acotados que leyó el controlador.
- Reintentar la activación de la lista de palabras de E12.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla (E8d T10 2268 MB, E12 T13 1977 MB, E13 T7 1718 MB). Quedan `v2i-docs-r21` y `v2i-integ-r21`
  para el barrido final (`limpiar-worktrees.sh`, sin `cwd` adentro), más los de r20 si no se barrieron.

---

# Relevo 21b — el dueño aprobó, y la ola siguió en la misma sesión

El relevo 21 cerró a las 17:22 con el candado libre. El dueño escribió en el chat «aproba todo y continua con el desarrollo» y el mismo
controlador siguió (contexto ~270k, así que no despachó más que lo imprescindible). Todo pasó por **`v2i/integ-r21b`** (BASE `version-2`
en `9972f95`). Controlador opus; implementadores sonnet en worktrees manuales; revisión opus para E13 T7.

| Qué | Estado |
|---|---|
| `v2i/integ-r21b` | **`34f2266`**: la lista de palabras (`a42a94b`), E3b T8 y E13 T7 (🟢 las dos) |
| `rapido` sobre `34f2266` | VERDE sobre `34f2266` (EK 642 · unit 1070 · 0 rojos · Release 0) |
| `version-2` | sigue en `9972f95` hasta que el `rapido` dé VERDE; entonces avanza por fast-forward (E3b T8 y E13 T7 pasan a ✅) |

## Las decisiones del dueño (en el chat, no se vuelven a preguntar)

- **E13 T7, opción (a):** Dios en **31,34 h** y las bandas de `PacingTests` re-pineadas a lo medido. `upgrades.json` queda en el plan (20 / ×1,09).
- **La barra de seis pestañas con platos de 44 pt** (E12 T13): aprobada, el plan B (tarjeta en la Oficina) queda descartado.
- **E13 T2 tal cual** (el regalo de frontera − 3, «Fusionar todo» de 600 s).
- **Activar la lista de palabras de E12** (137 términos, tal cual).
- **El cable del ascensor tal cual** (E8d T10: 1,2 s, superpuesto al ding en los tramos de un piso).

## Lo integrado

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **Lista de palabras de E12 ACTIVA** | `a42a94b` (`propuesta.txt` con encabezado ACTIVA + migración `20261009000001_blocklist.sql`, 137 términos) | gate de `tasks.md` §6 cerrado; se despliega con E12 T16 (🔒 credenciales de Supabase y `ANTHROPIC_API_KEY`) |
| **E3b T8** el selector del atajo | `42c61f0` | 🟢; sin oráculo `tarea` (sin unit nuevo); Receta R en iPhone 16 Pro: `QuickHireUITests` 3/3, `QuickHireButtonUITests` 3/3 (2 ajustados: el selector tapa el atajo), `BottomMenuUITests` 4/4, `TutorialUITests` 9/9; diff de `RootView` leído |
| **E13 T7** toque premiado, seis líneas, opción (a) | `421817b` + arreglos `592ef99` | 🟢; tarea VERDE (unit 103); revisión opus: Approved con arreglos, hechos |

### Lista de palabras

Era un pedido de `DUENO.md` que los relevos 16 a 21 no pudieron ejecutar (ver la trampa del clasificador, abajo). Con la confirmación del dueño
en el chat quedó hecha en un commit: la propuesta (`supabase/blocklist/propuesta.txt`) pasó a ACTIVA y la migración la carga. El matcher
sigue siendo por subcadena (`puta` y `cum` quedaron afuera por falsos positivos). No hay efecto en producción hasta E12 T16.

### E3b T8 — el selector

`QuickHirePicker` es un overlay anclado a `resolved[.quickHire]`, junto al `TutorialOverlay`; `QuickHireButton(onChoose:)` queda cableado
(mantener apretado 0,45 s); sección «Atajo» en el panel de debug; los comentarios viejos de `RootView` quedaron corregidos. Destraba a E3b T9
y a E4b T3 (en la medida en que sus otras dependencias estén).

### E13 T7 — la línea `lucky` y el pacing re-pineado

El implementador resolvió el conflicto del merge de `version-2` en `GameContentValidationTests` (`theVideoCatalogFollowsE13` + el pin de
6 líneas / 192 ORO) y re-pineó `PacingTests` a lo medido, sin tocar `upgrades.json`: paredes ≥ 5 → ≥ 4, reencarnaciones ≤ 8 → ≤ 9, y el
corrimiento pasó de «≥ 4» a «la pared más lejana ≥ 3 sobre la primera» (el extremo da −2; el comentario cita la decisión del dueño y el carry a
E2b T14). El simulador por CLI da: las 6 al tope en 20,67 h (9 reencarnaciones) y Dios en 31,34 h.

**Revisión opus: Approved con arreglos.** La migración está bien (`foldingMergedLines` idempotente, `max` con el `lucky` existente, tope 20, ORO y
`floorChestsAwarded` intactos, sin mezcla con CloudKit). Obligatorios, hechos en `592ef99`: (1) `derivedEffects` no se recalculaba al cargar →
`recomputeDerivedEffects` en el bootstrap + test (`lucky` 11 → crítico 0,1375 / dorado 0,0275); (2) los textos «las siete» / «≤ 8» de
`PacingTests` y del `pacing-sim` pasaron a «las seis» / «≤ 9» (la etiqueta del simulador la corrigió el controlador). Se ajustó además la
tolerancia de `critChance`. Claves: `quitar(4)` y después `aplicar(2)`.

## Carries de la revisión de E13 T7 (para el dueño y E2b T14)

- **Un veterano de un solo lado pierde crítico.** Con el crítico en 10 y el dorado en 0 (o al revés), la fusión de líneas lo deja en
  crítico 25 % → 12,5 % + 2,5 % de dorado. Aceptado; se mira en la calibración de E2b T14.
- **La última run se traba más abajo** (T17 → T12) con la línea nueva: aceptado, a E2b T14.
- **Una app vieja que lea un save 2.0 ve crit/golden en 0.** Verificar el versionado del save (¿una app 1.x rechaza o degrada un save más nuevo?)
  antes de E10.
- **El piso de tres tiers del corrimiento no tiene margen:** pasa justo en lo medido; cualquier retoque de costos de E2b lo rompe y hay que
  repinearlo conscientemente.
- **`ui_up_crit` queda sin uso** (la línea de crítico dejó de existir como fila propia): borrarlo o reutilizarlo (E8 / E13 T14).
- **La fila de `lucky` no muestra el dorado** en la lista de mejoras → **E13 T13** (la descripción de la fila).
- El reset de cuenta (E2b T5 / E9b T7) sigue debiendo sumar `meta.floorChestsAwarded` si copia campos a mano.

## Trampa nueva: el clasificador del modo auto no deja escribir en `DUENO.md`

El clasificador de permisos bloqueó escribir en `DUENO.md` las aprobaciones del dueño **aunque vinieran del chat**: el archivo es de los que los
relevos leen como instrucciones, así que una escritura ahí se lee como una instrucción inyectada. (Es la misma causa por la que el pedido de la
lista de palabras no se pudo ejecutar desde el archivo en los relevos 16 a 21.) Las aprobaciones quedaron en el journal y en este documento; para
que cuenten hay que confirmarlas **en el chat**, y el controlador las pasa a `tasks.md`/`HANDOFF.md`, no a `DUENO.md`. Si el dueño quiere que
`DUENO.md` refleje algo, lo escribe él.

## Para el dueño

- **E13 T7:** el costo de las seis líneas (Dios en 31,34 h) y los tres carries de arriba (veterano de un solo lado, última run, save viejo).
- **E3b T8:** probar en el iPhone el selector del atajo (mantener apretado el botón).
- Siguen: el despliegue de la lista de palabras (E12 T16, necesita las credenciales de Supabase), mediación por SPM, el fondo animado y la revelación
  en device (G1/G2/G3/G5), «Opciones de privacidad» en región UE, capturas de ASC, el back-fill de los cofres de piso de la v1.

## Oráculo

- `rapido` sobre la punta de `integ-r21b` (`34f2266`: lista de palabras + E3b T8 + E13 T7): VERDE sobre `34f2266` (EK 642 · unit 1070 · 0 rojos · Release 0).
- Tareas: E3b T8 Receta R (QuickHire 3/3 · QuickHireButton 3/3 · BottomMenu 4/4 · Tutorial 9/9); E13 T7 unit 103.

## Lo descartado

- Recalibrar E13 T7 con la curva de costo de `lucky` (ya descartado en el relevo 21).
- Escribir las aprobaciones en `DUENO.md` (el clasificador lo bloquea; van en el chat).
