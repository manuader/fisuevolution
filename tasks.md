# FisuEvolution 2.0 — el tablero de la implementación

> Tablero único de la 2.0: qué está hecho, qué sale ahora, qué espera a quién. Lo pidió el dueño:
> "implementarla por completo cuanto antes, con subagentes concurrentes que no se pisen entre sí".
> Fuentes: `Docs/PLAN-v2.md` (§0.1, §4, E8–E11), los 13 planes de
> `Docs/superpowers/plans/2026-10-0*-v2-*.md`, los ledgers
> `.superpowers/sdd/<plan>/progress.md` y el journal AVO del run.
>
> **Foto:** 2026-10-09, cierre del relevo 22 (la ola T, un solo relevo abierto por el disparo horario de `fisu-v2-relevo-a`).
> `version-2` = la punta de `9cccaf6` (`rapido` VERDE: EK 708 · unit 1136 · 0 rojos · Release 0; suma E3b T9, E12 T15, E6b T9, E4a T3/T4/T5 y E5a T4, todas ✅).
> `v2i/integ-r22` = `8ab8b33` + los docs del cierre (suma E4a T6, E4a T7 y E6a T1, 🟢 las tres; `rapido` sobre `8ab8b33`: VERDE (EK 735 · unit 1143 · 0 rojos · Release 0)).
> **Progreso: 159 de 254 en `version-2`; 162 con las tres 🟢.** **No publicar E7b-a T2 sin E7b-a T3.**
> El último `completo` de referencia es el de los cierres, sobre `0383a1d`. Detalle en `Docs/SESION-2026-10-09-v2-relevo-22-ola-t.md`.
> **Ojo:** los videos ya se reconciliaron con la rama del dueño (manda su versión de cada pieza); el lado Swift es E8d (§5).
> Si un ledger dice otra cosa que este archivo, manda el ledger y este archivo se corrige.

## 1. Cómo se usa

- **Un solo escritor: el controlador** (la sesión principal). Lo actualiza en cada borde de tarea:
  al despachar, al recibir el reporte, al integrar y al cerrar la ola. Los subagentes **nunca** lo
  editan: reportan, y el controlador pasa el dato acá.
- El detalle fino (carries, menores diferidos, reportes) sigue en el ledger de cada épica. Acá va una
  línea por tarea.
- Una tarea pasa de ⛔ a ⏳ cuando todas sus dependencias están ✅ (o 🟢 en su misma rama de épica) y
  ningún agente en vuelo es dueño de sus 🔥.

**Estados**

| | Significa |
|---|---|
| ✅ | integrada en `version-2` |
| 🟢 | hecha y revisada, integrada en la rama de su épica (o lista para integrarse encima de otra) |
| 🔧 | hecha, con arreglos de revisión pendientes o en curso |
| 🔄 | en vuelo (un agente la está haciendo) |
| ⏳ | lista para despachar |
| ⛔ | bloqueada (la columna "depende de" dice por qué) |
| 🔒 | espera al dueño |
| ⏭️ | salteada (decisión del dueño) |

**El ciclo de una tarea**

1. **Brief**: el controlador extrae la tarea del plan a `.superpowers/sdd/<plan>/task-N-brief.md`, con
   los carries del ledger, y actualiza la tabla de dueños de la ola en
   `.superpowers/sdd/v2-agente-protocolo.md`.
2. **Despacho**: `Agent(isolation: "worktree")` desde la BASE de la cola (§4), con el modelo de la cola.
   El paso 0 del agente es `merge --ff-only <BASE>` y comprobar el hash. → 🔄
3. **Implementación**: TDD y `oraculo.sh tarea <sus clases de test>` antes del commit (no el `rapido`:
   la suite entera y el Release van una vez por ola, en el paso 7). El brief es la tarea recortada con
   `Tools/v2/brief.py <plan> <N> <brief>` + los carries; el agente no lee el plan entero. Respuesta < 15 líneas.
4. **Revisión** (desde el relevo 7, por costo): **sonnet** por defecto; **opus** sólo si la tarea cambia
   lógica de save, del frame loop, del turno del tablero o de dinero; **ninguna** (lee el diff el
   controlador) si es mecánica, sólo tests o docs.
5. **Arreglos**: al **mismo** agente con `SendMessage` (retoma su worktree y su contexto). → 🔧
   Sólo dentro de la misma sesión: en un relevo nuevo va un agente nuevo con BASE = el commit del
   agente y el paquete `review-<base>..<commit>.diff` del ledger.
6. **Integración en la rama de la épica**: `rebase`/cherry-pick sobre la punta + `merge --ff-only`, y
   `rapido` sobre la integración. → 🟢
7. **`rapido` de fin de ola** y merge `--no-ff` de la rama de la épica a `version-2`; push. → ✅
   Las tareas nuevas de otras épicas salen de esa punta.
8. **Docs**: ledger y journal en cada borde; `SESION` + las cuatro ediciones de `Docs/HANDOFF.md` +
   handoff efímero al cerrar (un solo agente de docs a la vez); y este archivo.

**Ramas de épica**

| Épica | Rama | Punta hoy |
|---|---|---|
| E1 | `v2/e1-correcciones` (worktree `v2-e1`) | integrada en `version-2`; **E1 cerrada** (T16 ✅, relevo 12) |
| E11 | `v2/e11-notificaciones` (worktree `v2-e11`) | `597b60e` (T5; mergeada en `c47d93e`) |
| E3a + E3b | `v2/e3-ux` (worktree `v2-e3`) | `aae3a7f` (T8; mergeada en `9eeb9eb`) |
| E5a + E5b | `v2/e5-premios` (worktree `v2-e5`) | `f6f8e2f` (mergeada en `0fa932c`) |
| E2a | `v2/e2a-mecanicas` (worktree `v2-e2a`, nuevo) | T1–T14 integradas en `version-2` (`e378307`); falta T15 |
| E4a + E4b | `v2/e4-visitantes` | `8d0a311` (T1; mergeada) |
| E6a + E6b | `v2/e6-tienda` | `2ba7c2e` (T3; mergeada en `e27efb1`) |
| E7b-a + E7b-b | `v2/e7b-anuncios` | a crear desde `version-2` |
| E8 | `v2/e8-pipeline` | `4ea0678` (integrada; su worktree `v2-e8-pipeline` ya no existe) |
| E8 (arte) | `v2/e8-arte` | T1–T6 y T8 integradas; faltan T7, T9 (🔒 el dueño) y T10 |
| E12 | — (ramas de tarea `v2i/*`) | T1–T11 y T13 integradas (T13 en el relevo 21, barra de seis pestañas); sigue T12 (⛔); el plan y la spec vienen de `v2/e12-plan` (worktree `v2-e12-plan`, **de la sesión del dueño**) |
| E13 | — (ramas de tarea `v2i/*`) | T1, T3, T4, T5, T6, T8, T10, T11 y T12 integradas; T2 y T9 integradas (relevo 21); **T7 🟢 en `v2i/integ-r21b` (opción a del dueño: Dios 31,34 h, bandas re-pineadas)**; siguen T13 y T14 |
| E13b | — (ramas de tarea `v2i/*`) | T1–T5 y T9 integradas (`596cacd`); T7 y T10 en `v2i/integ-r14` (`32afc93`); siguen T6 y T8 |
| E3b | (en `v2/e3-ux`, ya mergeada) + ramas de tarea `v2i/*` | T1–T7 integradas, T8 🟢 en `v2i/integ-r21b`; sigue T9 (se destraba con T8 ✅; E1 T16 ya está) |
| E8b / E8c | — (ramas de tarea `v2i/*`) | E8b T1–T3, T7 integradas; T4/T5/T6/T12 reemplazadas por E8d; E8c T1–T9 integradas; sigue T10 (cierre) |
| E8d | — (ramas de tarea `v2i/*`) | T1–T10 y T12–T14 integradas (T10 en el relevo 21); siguen T11 y T15 |

## 2. Progreso

**Hoy: 167 de 254 tareas activas integradas en `version-2` (65,7 %): en el relevo 23 pasaron a ✅ E6a T2, E6a T10, E9b T7, E2b T3 y E6b T6 (`rapido` VERDE sobre `ed85656`: EK 784 · unit 1143 · 0 rojos · Release 0; la tabla por épica la recalcula el cierre del 23). Antes, 162 (63,8 %): en el relevo 22 pasaron a ✅ E3b T9, E12 T15, E6b T9 (`rapido` VERDE sobre `ddea816`), E4a T3, T4, T5 y E5a T4 (VERDE sobre `9cccaf6`) y E4a T6, E4a T7 y E6a T1 (VERDE sobre `8ab8b33`: EK 735 · unit 1143 · 0 rojos · Release 0).** Antes: 152 (59,8 %) al cierre del 21c. El relevo 22 también corrigió un test (`SkinCatalogRowsTests`, `ababa57`) que pineaba el catálogo sin las tres familias. 259 filas, 5 salteadas (E8b T4/T5/T6/T12 reemplazadas por E8d, E7b-b), más los
seguimientos (E1 T5b/T5c/T6c/T9b, E6b T1r, todos ✅). Quedan ⏳ 9 (E8 T10 y E13b T11 ya lo estaban; E4a T9, E6a T2 y T10, E9b T7, E2b T3 y T11 y E13 T14 los pasó a ⏳ el relevo 22 al revisar §5 contra las 🟢 y los ✅). E12 T12 está ⛔, E12 T16 🔒 y E7b-a T3 ⛔ (bloqueo de publicación, §4.2).

| Épica | Activas | ✅ | 🟢 | 🔧 🔄 | ⏳ | ⛔ | 🔒 | ⏭️ |
|---|---|---|---|---|---|---|---|---|
| E1 | 16 | 16 |  |  |  |  |  |  |
| E11 | 7 | 7 |  |  |  |  |  |  |
| E3a | 12 | 12 |  |  |  |  |  |  |
| E3b | 9 | 9 |  |  |  |  |  |  |
| E2a | 15 | 15 |  |  |  |  |  |  |
| E4a | 10 | 6 | 2 |  | 1 | 1 |  |  |
| E4b | 10 |  |  |  |  | 10 |  |  |
| E5a | 9 | 4 |  |  |  | 5 |  |  |
| E5b | 7 |  |  |  |  | 7 |  |  |
| E6a | 13 | 2 | 1 |  | 2 | 8 |  |  |
| E6b | 10 | 4 |  |  |  | 6 |  |  |
| E7b-a | 7 | 4 |  |  |  | 3 |  |  |
| E7b-b | 7 |  |  |  |  | 7 |  | 1 |
| E9a | 10 |  |  |  |  | 10 |  |  |
| E9b | 10 | 1 |  |  | 1 | 8 |  |  |
| E2b | 15 | 2 |  |  | 2 | 11 |  |  |
| E8 | 10 | 8 |  |  | 1 | 1 |  |  |
| E8b | 8 | 7 |  |  |  | 1 |  | 4 |
| E8c | 10 | 10 |  |  |  |  |  |  |
| E8d | 15 | 14 |  |  |  | 1 |  |  |
| E12 | 19 | 15 |  |  |  | 3 | 1 |  |
| E13 | 14 | 13 |  |  | 1 |  |  |  |
| E13b | 11 | 10 |  |  | 1 |  |  |  |
| **Total** | **254** | **159** | **3** | | **9** | **82** | **1** | **5** |

Fuera del conteo:

- los **hechos previos a los planes por tarea**: E0 oráculo, E8 pipeline, E8 audio, E7a, E3 i18n y
  E10 en papel (§5, "Hechos previos");
- los **seguimientos** (filas marcadas "(seguimiento)"): E1 T5b, T5c, T6c y T9b, y E6b T1r, todos ✅;
- las filas `P-…` (planes).

**Cómo recalcularlo** (las filas de tarea de §5 tienen el ID `E<épica>-T<n>` en la 1ª columna, con sufijo `a`/`b`
en E12 T9a/T9b, y el estado en la 3ª; las filas "(seguimiento)" y las `P-…` no entran):

```bash
grep -E '^\| E[0-9a-z-]+-T[0-9]+[ab]? \|[^|]*\| ✅' tasks.md | grep -vc seguimiento   # integradas
grep -E '^\| E[0-9a-z-]+-T[0-9]+[ab]? \|' tasks.md | grep -vc seguimiento              # filas de tarea
grep -E '^\| E[0-9a-z-]+-T[0-9]+[ab]? \|[^|]*\| ⏭' tasks.md | grep -vc seguimiento    # salteadas
grep -E '^\| E2a-T[0-9]+ \|[^|]*\| ✅' tasks.md | grep -vc seguimiento                   # una épica: cambiar el prefijo
```

Progreso = integradas / (filas de tarea − salteadas). Hoy: 159 / (259 − 5); con las 🟢 (mismo grep cambiando ✅ por 🟢: 3), 162 / 254. Con el sufijo `[ab]?` el grep levanta
también `E1-T5b` y `E1-T9b`; por eso el `grep -v seguimiento`. Cualquier otro estado se cuenta igual, cambiando el ✅.
La tabla por épica se recalculó en el relevo 22 (con un `awk` sobre las mismas filas); la columna ⏭️ cuenta las salteadas, que no entran en "Activas"; si discrepa, vale el `grep`.

## 3. Reglas de concurrencia (PLAN-v2 §0.1, operativas)

- **Topes**: hasta **3 agentes compilando** a la vez (un `completo` cuenta como uno; una tarea pura
  de EconomyKit cuenta cuando corre su `rapido`; los spikes compilan y cuentan) y hasta **2
  planificando**. Cada uno con su DerivedData y su simulador por UDID, que apaga y borra.
- **`get_usage` antes de cada ola**: con la ventana de 5 h ≥ 85 % o la semanal ≥ 90 %, la ola no se
  lanza y se espera `resetsAt`.
- **Contexto del controlador** (en cada borde de tarea): ≥ 250.000 tokens, no se arranca una tarea
  grande nueva; ≥ 300.000, se cierra (esperar a todos los agentes, commit, docs, journal, candado) y
  se releva: `CronCreate` + `clear_session("self")` (en los relevos 2 a 6 no despertó nunca), y las
  rutinas manuales `fisu-v2-relevo-a/-b`, que existen desde el relevo 6: el que cierra lanza la otra
  con `run_scheduled_task` (su prompt todavía no nombra este archivo). Último recurso, el dueño
  escribe "continúa".
- **Un dueño por archivo 🔥 a la vez.** Un agente que necesita un 🔥 ajeno para con
  `NEEDS_CONTEXT`. El catálogo de strings: la tarea que no es su dueña en la ola entrega
  `Tools/v2/claves-pendientes/<épica>-tN.json` y el controlador lo aplica con `catalogo.py aplicar`
  al integrar.
- **No se mergea a `version-2`** mientras corre un oráculo en ese worktree si el merge trae Swift.
- **El exit de una tarea de fondo no es el del oráculo** (`oraculo.sh …; echo` termina en 0): leer la
  última línea del log.
- La limpieza de worktrees de agentes la hace el dueño (el clasificador bloquea `worktree remove
  --force` + `branch -D`).

### 3.1 Los 🔥 y quién los toma (pendientes, en orden de plan)

| 🔥 | Tareas que faltan y lo tocan |
|---|---|
| `GameState.swift` | E1 T9, T10, T12, T13, T14 · E11 T6 · E3a T9, T10 · E3b T5, T9 · E2a T9 · E4a T9 · E4b T1, T4, T9 · E5b T2 · E6b T7 · E7b-a T2, T3 · E7b-b T1 |
| `RootView.swift` | E1 T10, T13, T14 · E3a T10, T11 · E3b T4, T5 (comentarios), T8, T9 · E4b T3, T4, T9 · E5b T2 · E6a T12 · E7b-a T2, T3 · E7b-b T3 |
| `BoardScene.swift` | E1 T10 · E3a T10 · E4b T1, T6, T9 · E5b T3 · E6b T5 |
| `ContentSystems.swift` | E1 T11, T12, T13 · E2a T11 · E4a T9 |
| `GameState+Bonus.swift` | E1 T11, T12, T13, T14 · E3b T9 · E2a T11, T12 · E4a T9 · E4b T4 · E6a T5 |
| `PlayerState.swift` | E1 T6c (sólo `MetaState`) · E2a T2, T3 · E4b T9 (un docstring) · E6b T4 |
| `TowerActions.swift` | E1 T13 · E2a T3, T9, T12 |
| `SettingsView.swift` | E11 T4 · E7b-a T5 · (E9, Ajustes) |
| `project.yml` | E7b-a T6 |
| `Localizable.xcstrings` | casi toda tarea con UI: una dueña por ola, el resto por snapshot |

⚠️ **`GameState.swift` es el cuello de botella**: 20 tareas que faltan lo tocan, de a una. Sus
ventanas libres durante E1 son mínimas (E1 T11 y T15 no lo tocan, pero T10 corre al lado de T11) y
se abren de verdad después de E1 T14. El orden de la cola (§4) lo tiene en cuenta, y §4.4 propone
partirlo.

### 3.2 Tibios (no calientes, pero varias épicas los tocan: se secuencian)

| Tibio | Quién lo toca |
|---|---|
| `GameState+Debug.swift` | E1 T9, T10, T12, T13 · E3a T9 · E3b T9 · E2a T14 · E4a T9 · E4b T1, T2, T4, T9 |
| `GameState+Celebrations.swift` | E1 T9, T10 · E11 T6 · E4b T1, T4 · E6a T12 · E7b-a T2 |
| `GameState+Lifecycle.swift` | E1 T9 · E11 T6 · E6a T5 · E7b-a T2 |
| `GameState+BoardChanges.swift` | E1 T9 (lo crea), T14 · E2a T9, T14 · E3b T9 · E4a T6 · E4b T9 · E5a T6 · E6a T6 · E7b-b T1 |
| `GameState+Hiring.swift` | E1 T13 · E3b T5, T6 · E2a T10 · E4b T7 |
| `GameState+Engagement.swift` | E4a T9 (lo crea) · E4b T1, T2, T4 · E5a T6, T7, T8 · E6a T5, T8, T12 · E6b T7 |
| `GameState+Rewards.swift` | E4a T8 (lo crea) · E5a T6, T8 · E5b T2 · E6a T5 |
| `FisuEvolutionApp.swift` | E11 T6 · E7b-a T1, T2 |
| `Info.plist` | E7b-a T6 |
| `EngagementState.swift` (EK) | E3b T9 → E4a T3 → E5a T4 → E6a T1 (en ese orden: cada una suma sus campos al mismo `init`) |
| `BoardChange.swift` (EK) | E2a T6, T9 · E4a T6 · E5a T6 · E6a T6 · E7b-b T1 |
| `GameContentLoader.swift` | E3a T9 · E2a T9, T12 · E4a T7, T9 · E5a T5 · E6a T4, T11 · E6b T3, T7 |
| `LocalizationCompletenessTests.swift` | E11 T4 · E4a T7, T9 · E4b T2 · E6a T4, T11 |
| `ContentConfigs.swift` | E1 T11, T13, T15 · E2a T11, T12 · E3b T9 · E4a T9 |
| `ActiveModifier.swift`, `ActiveBonus*.swift`, `EffectContractTests.swift` | E1 T13, T15 · E2a T11, T12, T13 · E4a T2, T9 · E4b T4, T7 · E6a T3 |
| `DebugPanelView.swift` | E2a T14 · E3b T2, T8, T9 · E4b T1, T2, T4, T9 · E5b T2 · E6b T2 · E7b-a T3, T6 |
| `GameState+Store.swift`, `StoreManager.swift`, `products.json`, `StoreManagerTests.swift` | E1 T6c · E2a T7 · E6a T7, T9, T11 · E6b T4, T5 |
| `PanelFrames.swift` | E3a T6, T8 · E3b T3 |
| `OfflineEarningsView.swift` | E3a T6 · E11 T5 (y la lección offline de E9) |
| `CelebrationQueue.swift` (EK) | E1 T10 · E4b T1, T4 · E6a T12 |
| `GameState+TutorialTips.swift`, `TutorialAnchor.swift` | E3b T5, T9 · E4b T3, T4, T8 · E5b T5 · E6a T8, T12 · E7b-b T3, T5 |

## 4. Cola de despacho — lo próximo (relevo 23)

### 4.1 Al llegar

| # | Qué | Nota |
|---|---|---|
| 1 | **`rapido` sobre `v2i/integ-r22` (`8ab8b33`) con los docs del cierre**, si no quedó hecho. Resultado del relevo 22: VERDE (EK 735 · unit 1143 · 0 rojos · Release 0) | Con VERDE: fast-forward de `version-2` (hoy la punta de `9cccaf6`) a la punta con los docs, y push (E4a T6, E4a T7 y E6a T1 pasan a ✅: 162 de 254). Con ROJO: leer primero **qué test** cae (el del relevo 22 fue `SkinCatalogRowsTests`, un test que pinea un catálogo que la tarea agrandó a propósito). No mergear a `version-2` mientras corra otro oráculo ahí. **Lanzarlo con `nohup perl -e 'setpgrp(0,0); exec @ARGV' bash <ruta absoluta del worktree que querés verificar>/Tools/v2/oraculo.sh rapido > build/<log> 2>&1 &`** (`setsid` no existe en macOS; el oráculo usa el repo de su propia ruta, no el `cwd`), con la carga baja (**con carga > 200 y dos agentes compilando excede el tope**) y esperarlo por PID (`$!`) o por la última línea del log, no con `pgrep -f` |
| 2 | **Mirar la carga de la máquina** (`uptime`) antes de despachar | el relevo 22 vio 1,8 → 265 → 232 → 154 → 10. Con carga > 200: **no más de 2 compilando** (el `rapido` cuenta); con carga ~100, 3. **Las tareas de EK pura (`swift test`, sin compilar la app) no ocupan cupo**: se pueden despachar mientras corre el `rapido`. `xcodebuild` con `-disableAutomaticPackageResolution -skipPackageUpdates`, simulador booteado y esperas por PID (**`timeout` no existe en esta máquina**). **El latido es un script con `sleep 30` y escritura por reloj.** **Nunca `pkill -f`**: sólo `kill <PID>` propio; los simuladores `oraculo-*` se borran por UDID propio. Un agente con una espera de fondo puede re-entregar el mismo reporte: no hace falta `TaskStop` si `ps` no muestra procesos suyos |
| 3 | Leer `DUENO.md` entero por pendientes nuevos | **El clasificador del modo auto no deja escribir en `DUENO.md`** (ni las aprobaciones del chat): las decisiones del dueño del 21b (E13 T7 opción a, barra de seis con platos de 44 pt, E13 T2 tal cual, lista de palabras, cable del ascensor) están en el journal, en los SESION y acá; **no las re-preguntes**. La mediación por SPM espera al dueño. Los worktrees `v2-e12-plan`, `v2-release-ops` y las ramas `v2/e8-*` son de la sesión del dueño; no tocar |
| 4 | Pasar a ✅ las tres 🟢 (E4a T6, E4a T7, E6a T1) cuando el `rapido` dé VERDE y recalcular §2 | las filas ⏳ de abajo ya están marcadas; el script de dependencias da lo mismo |
| 5 | Barrer los worktrees `v2i-*` que queden con `limpiar-worktrees.sh` | sólo `v2i-*`, nunca `v2-*`; todo en GitHub antes; nunca `--force`; **con el shell fuera del worktree**. Quedan `v2i-integ-r22` y `v2i-docs-r22` (y los anteriores si no se barrieron) |

### 4.2 La ola siguiente (≤ 3 compilando con carga ~100, ≤ 2 con la máquina cargada; un dueño por archivo)

BASE de todas: `version-2` tras el paso 1 (o `v2i/integ-r22` si el `rapido` no se corrió). Worktrees manuales `worktrees.nosync/v2i-<tarea>`.
**Un solo dueño de `RootView` y de `GameState` por ola.** Revisar cada dependencia contra la tabla de §5 antes de despachar.

| # | Tarea | Modelo | Dueña de / nota |
|---|---|---|---|
| 1 | **E4a T9** (la mudanza a eventos v2) | sonnet, rev. opus | ⏳ **la llave de la cadena**: la esperan E5a T5/T6, E4a T10, E4b T7, E6a T5 y E2b T10. 🔥 `GameState`, +Bonus, `ContentSystems`, catálogo. Va primero y sola en `GameState`. Con los carries: el reset de debug (`debugResetSave`) **no limpia `visitors` ni `events`** (E4a T3); `.visitor` **no es prepago** (E4a T6, también a E4b T2); `isCalmMoment` duplica `isSafeMomentForInterstitial` (E4a T8); los kinds fuera de `grantableRewardKinds` no se ofrecen (E4a T8) |
| 2 | **E6a T2** (catálogo y cuentas de la tienda, EK) y **E6a T10** (ofertas de 24 h, puras) | sonnet | ⏳ **EK puro: sólo `swift test`, no ocupa cupo**; archivos nuevos, en paralelo con la 1. **Carry de E6a T1:** marcan `lastClosedAt` en toda compra y vencimiento; la política del ×3 que reaparece es la de `chestsPending` (el arreglo pide ids por compra) |
| 3 | **E9b T7** (`ResetPlan` puro, matriz del ORO) | sonnet | ⏳ EK puro, sin cupo. **Carry de E6a T1:** `resolveAcrossReset` **no cruza `engagement.offers`** |
| 4 | **E2b T3** (el simulador cobra como el juego, EK) | sonnet | ⏳ EK puro, sin cupo; abre la cadena T4–T8 (fase A). E2b T11 (la herencia en pantalla, catálogo por snapshot) también ⏳, de menor prioridad |
| 5 | **E5a T5** (`packages/treasures/wheel.json`) | sonnet | ⛔→⏳ **cuando E4a T9 esté en `version-2`**: sus dependencias (E5a T1–T3 ✅, E4a T7, E4a T9) las deja cumplidas. Dueña de `GameContentLoader`; carry: validador `isFinite`. Después E5a T6 → T7 → T8 (en serie) |
| 6 | **E8 T10** (peso, memoria y cierre; `completo --limpio`), **E13b T11** (cierre de E13b; `completo`, grabaciones para el dueño) y **E13 T14** (cierre de E13; `completo`, HANDOFF §5.7 «las seis») | controlador | ⏳ **un solo `completo`** cubre los tres. E8 T10: 🔒 sólo si el bundle crece > 60 MB (E6b T9 no cambió el peso: los atlas ya estaban desde E8; estimado ≈ +29 MB) |
| 7 | **E7b-a T3** (la pausa publicitaria) | sonnet | ⛔ hasta que se destrabe (T2 ✅, E4a T8 ✅, E1 T14 ✅; faltan **E5a T6, E5b T1, E4b T3**, es decir la cadena de E4a T9). **BLOQUEO DE PUBLICACIÓN:** sin T3 sale un intersticial en cada corte. Despacharla en cuanto se destrabe, con los carries de T2 y T4 de su fila (`canRequestAds` en intersticial y rewarded, un solo observador de AdMob, `recordShown`, `Set<CelebrationKind>??` → enum) y el de E3b T9 (la oferta de compartir puede gastar sus 10 s detrás del intersticial de `celebrationsDrained`) |
| 8 | **E12 T12** | sonnet, rev. opus | sigue **⛔** (E9b T7/T8; T7 sale hoy en la fila 3) |
| 9 | **🔒 del dueño** | — | **E12 T16** (credenciales de Supabase y `ANTHROPIC_API_KEY`; ahí se despliega `20261009000001_blocklist.sql`); **mediación por SPM** (E7b-a T6: Unity + Meta); **capturas de iPad a ASC** (E10); **escenarios de E11 en device** (diálogo del sistema de notificaciones) y de E2a/E8c (Reduce Motion, hoja, fondo, ORO/video); las dudas del relevo 22 de abajo (E3b T9, E6a T1, E12 T15) |

Lo que **no** se despacha todavía: E4a T10 (cierra tras T9); E4b entera (arranca en E4b T1, que espera a E4a T10); E5a T6–T9 y E5b (cadena de E5a T5); E6a T4–T9 y T11–T13
(cadena de E5a/E5b); E6b T4 y T6 (esperan a E6a T2 y T8); E8 T9 (revisión de recortes: su fila sigue ⛔ aunque sus dependencias están ✅; la elige el dueño y no frena a nadie, la deja el controlador); E8d T15 (espera a E8b T11, que
espera al arresto de E4b T2); E2b T4–T10 y T12–T15 (cadena de la EK); E9b T8 (espera a E9a T3 y E6a T11); E9a (espera a E6a T12).

Carries del relevo 22 (detalle en `Docs/SESION-2026-10-09-v2-relevo-22-ola-t.md`): **E3b T9 → al dueño y a E7b-a T3:** la oferta descartada se pierde; puede gastar sus 10 s detrás del
intersticial de `celebrationsDrained`; premio de reencarnación casi nulo (5 min de la run nueva). **E6a T1 → al dueño, a T2/T10, a T11 y a E9b T7:** una oferta abierta sólo en
el save perdedor (la Bienvenida) se pierde para siempre; ¿se acepta el ×3 regalado en el caso raro?; T2/T10 marcan `lastClosedAt`; T11 acredita aunque la oferta ya no figure
abierta; `resolveAcrossReset` no cruza `engagement.offers`. **E12 T15 → E10 y al dueño:** `NSPrivacyTracking` sigue en `false` (de antes) aunque haya AdMob/ATT; la nota a
App Review no da atajo para ver el ranking; la privacidad no nombra al proveedor de IA. **E4a T6 → E4b T2 / E4a T9:** `.visitor` no es prepago (una visita pagada con video
que se descarte no se compensa). **E4a T3 → E4a T9:** el reset de debug no limpia `visitors`/`events`. **E4a T7:** carga el Anexo A con los guiños.

Carries del relevo 21c (detalle en `Docs/SESION-2026-10-09-v2-relevo-21c-ola-s.md`): **E7b-a T2/T4 → T3 y al dueño:** no publicar sin T3; falta `canRequestAds` en
intersticial y rewarded; un solo observador de AdMob para todos los formatos; verificar el *fill* del app open en device. **E8b T10 → al dueño:** el corte
`.reincarnation` casi siempre se saltea por la cinemática y el intersticial sale por `.celebrationsDrained` antes del cofre; un veterano v1 en Dios ve la de Dios en
el primer arranque. **E8d T11 → T15:** la intro sale en partida nueva; clave de accesibilidad redactada sin ver el video. **E13 T13:** verificar 2 renglones en el SE;
borrar `ui_up_crit`. **E12 T14 → T16:** con el ranking apagado la tarjeta no sale. **E2a T15 → E2b:** tabla de perillas (base Dios 31,34 h) en el SESION de los cierres.

Carries vigentes (detalle en `Docs/SESION-2026-10-09-v2-relevo-21-ola-r.md` (relevos 21 y 21b), `…relevo-20-ola-q.md` y `…relevo-19-ola-p.md`):
**De E8d T10 a T15 y al dueño:** el sonido del cable (1,2 s) se superpone con el ding en los tramos de un piso y sigue sonando si se saltea
(escuchar en el iPhone); falta la nota de Reduce Motion en el doc. **De E12 T13 a T16 y al dueño:** la pestaña del ranking no aparece en producción
hasta que haya servidor (`baseURL` nulo); ¿sirve el plato de 44 pt de la barra de seis? **De E13 T2:** `BoardChangeWiringTests.inactiveSettlesOnlyWhatWasPaidFor`
tiene un límite flojo (`settled <= units - links`) → fijarlo exacto; `rewardUnavailableReason(.mergeAll)` ignora `pendingBoardChanges` (un video
podría planear pares de una cadena ya en fila y no pagar) → a E6a (por ORO) y E7b-b; «Te llega un %@, de regalo» es masculino fijo; al dueño y a
E2b: `merge_all` de 600 s da más valor que la Evolución gratis (14400 s), y frontera − 3 cae en pisos llenos más seguido (con frontera ≤ 4, un tier 1).
**De E13 T9 a E9b T1:** texto de `tutorial.character_sheet.hold`. **De E13 T7 a E2b T14 y al dueño:** el simulador por CLI no replica el umbral de
`PacingTests` (9 reencarnaciones también con el catálogo viejo); la vara es el test. Revisión opus (relevo 21b): un veterano de un solo lado pierde crítico (25 % → 12,5 % + 2,5 % dorado); la última run se traba más abajo (T17 → T12); una app vieja que lea un save 2.0 ve crit/golden en 0 (verificar el versionado); el piso de 3 tiers del corrimiento no tiene margen; `ui_up_crit` sin uso; la fila de `lucky` no muestra el dorado → E13 T13.
**de E8d T8/T9 a T15 y al dueño:** el fondo animado de los pisos **ya está activo en producción** (10 `bgloop_*` sin `odrTag`); mirar en device
el ablande 1024² → 2048² al fundir, el `SKVideoNode` en `SKCropNode` y el tirón al soltar un swipe en el SE (G1/G2/G3); los overlays de
SwiftUI no suspenden el fondo; la revelación con video depende de ODR (53 `characters` con `odrTag`; se precarga el del próximo tier al
asentarse) y **no hay test ODR con un `ArtPackSource` falso**; `closeReveal` sin identidad; el whoosh del reveal suena siempre. **De E3a T11 a
E3a T12:** no corrió `BottomMenuUITests`, `BonusHUDUITests` ni `HUDRedesignUITests` en iPhone; los toasts de logros y el aviso de torre no
usan `playColumn`. **De E3b T4:** sólo la página quieta queda montada (pierde el `NavigationStack` al deslizar); Tienda en sesión de una sola
página; cinco páginas; `BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos` rojo también en la base (sospecha de E2a T14). **De E7b-a T5:**
sin prueba en región UE con el SDK real. **De E8c T9 a T10:** el fixture no cubre ascenso ni piso nuevo (`runAscentAnimation` y
`runFloorUnlockCelebration` sin paso de test); sin captura ni grabación (SE + Reduce Motion); la posición del contador es provisoria
(`size.height * 0.8`); T10 corrige el comentario viejo "Cubre navegar al piso…" de `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift:68`.
**De E13 T3 a E2b T5 y E9b T7:** el reset de cuenta deja `meta.floorChestsAwarded` en 0 (sale solo si arma el meta con `newGame`/`.fresh`; si
copia campos a mano, sumarlo); en el HANDOFF la frase "los cofres de torre se vuelven a cobrar al reencarnar" queda falsa (al cierre E13 T14).
**De E13 T10:** sin receta R de `FisuJobsUITests` ni captura SE con tres pisos; el sub-encabezado de piso sin `accessibilityIdentifier`.
**De E8 T7 a E5b T1 (`wheel_*`), E5b T2/T3 (`pickup_package_*`, `mattress_icon`), E4b T8 (`ui_album_*`), E6b T9 (`ui_shop_skin_family`) y
E7b-b T3 (`mattress_icon`):** `wheel_frame` y `ui_album_card_frame` tienen la ventana interior blanca opaca (cubrirla o enmascararla).
**De E8d T7:** los 8 `sfx_ev_*` sin escuchar (G7). **De E13 T11:** sin captura del piso con pasivos (¿la moneda tapa la cara del de atrás?)
→ E13 T14 / dueño. **De E13 T12:** captura SE y la receta R de `CustomizationUITests`. **De E8c T1:** helper `linked(_:)` en vez de rearmar el
struct. **De E8c T5:** un video que compense en `discardBoardChange` compensaría por eslabón (E6/E7b); `SFX.mergeAllDone` sin escuchar (G7).
**De E12 T11:** el parseo de `--uitest-ranking-*` en `RankingStore.live()` **no está bajo `#if DEBUG`**; la config remota y el `godTier` siguen
`null`/`nil` hasta T16. **De E8d T13:** sin captura de la fila "Rendimiento" del panel; la vara de fps/memoria es G1/G2/G4 en device. **De
E8d T14:** el manifest lee `talking`/`visitorActions`/`shopIcons`; **el ODR real nunca se probó en device (G5)**. De E8d T4 (`setVisible(false)`,
nunca póster vacío, la vara del alfa es G3 en device); de E8d T12 (`prefetch` sin llamadores); de E12 T10 (un build viejo deja el ranking en
`.legacy`, `carriedSubmission` 403); de E12 T9a/T9b a T13 (`RankingEntryCard` modal con `store.entryPrompt != nil`; `RankingView(store:state:now:onStore:)`
con el `RankingState`; `pager?.lock`; con `isEnabled == false` muestra `ranking.disabled`); de E13b T8 (sin test con el tip `.elevatorKeypad`; flake
de 'saltear con las puertas abriendo' bajo carga; comentarios de 'la luz de la botonera' en `GameState.swift:130` y `BoardScene.swift:1926`; motor
a gain 0,4 a ojo); **para el dueño:** `installId` que no viaja por CloudKit, el botón Entrar con `.disabled` contra la convención de `ActionPill`,
la placa de 10 pisos que tapa parte de Reencarnar; HEVC-alfa a ×5 en device (E13b T11 / E8d G3); de E9b T6 a T7/T8 (`OffersState.purchases` y
`seenCinematics` cruzan `resolveAcrossReset`); de E12 T6 (reenvío idempotente de `carriedSubmission`; `pendingWork .start`); de E12 T4 a T5/T16
(`prepare: false`, límite por IP); de E8b T3 (`sp_contador_dios`, `sp_bug_simulacion` al dueño); de E13b T9 a E3b T4 (cinco páginas); de E13 T1 a
E4b T3 / E7b-b T7 (`RewardedOfferButton`); los de las olas H a M.

### 4.3 La cola, por prioridad

> ⚠️ Relevo 8: las filas 1, 4–9, 11 y 12 ya están hechas, y E2a T3/T4 van **después** de E1 T14 (no antes de T12, como dicen las filas 2 y 3). Para lo inmediato manda §4.2.

Cada cupo que se libera toma **la primera fila cuyas dependencias estén cumplidas** y que no choque
con un dueño en vuelo. E1 siempre primero en cuanto su tarea se destraba.

| # | Tarea | BASE | Modelo | 🔥 | No en paralelo con |
|---|---|---|---|---|---|
| 1 | **E1 T10** ∥ **E1 T11** (T10 tras T9; T11 ya ⏳) | punta de `v2/e1-correcciones` | sonnet (revisión opus) | T10: `BoardScene`, `GameState`, `RootView`; T11: `ContentSystems`, `+Bonus` | todo lo que toque esos archivos; E3a T9/T10, E3b T5. Carry de T7 a T10: la guarda de `typeId` en el aplicador |
| 2 | **E1 T12 → T13 → T14 → T15 → T16** (en serie) | punta de `v2/e1-correcciones` | sonnet; T16 controlador | ver §5 E1 | E2a T3/T4 (deben entrar antes de T12) |
| 3 | **E2a T2 → T3 → T4** (T2 tras E1 T6c) | `version-2` tras la ola E (rama `v2/e2a-mecanicas`) | sonnet | T2/T3: `PlayerState`; T3: `TowerActions` | E1 T6c; T3 antes de E1 T13; **T4 integrada antes de que arranque E1 T12**, o todo pasa a después de E1 T14 (regla 2 de E2a) |
| 4 | **E6b T2** la galería (tras T1) → 🔒 el dueño | punta de `v2/e6-tienda` | sonnet | `DebugPanelView` (tibio) | E2a T14, E3b T2/T8 (`DebugPanelView`) |
| 5 | **E3a T7** la barra baja | punta de `v2/e3-ux` | sonnet | `GameArtComponents` (tibio) | E3a T9, E3b T2, E4b T3/T7 |
| 6 | **E3a T8** la botonera (tras T6) | punta de `v2/e3-ux` | sonnet | catálogo (o snapshot); `PanelFrames`, `HUDView` | E3b T3 (`PanelFrames`). Despacho con las líneas de S6 del ledger (botones de 30 pt) |
| 7 | **E11 T4** ∥ **E11 T5** (tras T3 integrada) | punta de `v2/e11-notificaciones` | sonnet | T4: `SettingsView` + catálogo; T5: snapshot | T5 no con E3a T6; T4 antes de E7b-a T5. Carries de T3 en el ledger |
| 8 | **E4a T1** `RewardSpec` | `version-2` (rama `v2/e4-visitantes`) | sonnet | ninguno (EK, archivos nuevos) | — |
| 9 | **E5a T2** ∥ **E5a T3** (tras E4a T1) | punta de `v2/e5-premios` con `version-2` mergeada | sonnet | ninguno (EK) | — · carry de T1: `validate()` rechaza peso ≤ 0 |
| 10 | **E3b T1** spikes S2/S3 | punta de `v2/e3-ux` | opus (sin commit) | ninguno | cuenta como compilando |
| 11 | **E2a T1** ∥ **E2a T6** | punta de `v2/e2a-mecanicas` | sonnet | ninguno (EK; T6 toca `BoardChange.swift`) | T6 no con E4a T6, E5a T6 |
| 12 | **E6b T3** `skins.json` v2 (tras T1) | punta de `v2/e6-tienda` | sonnet | `GameContentLoader` (tibio) | otra tarea en el loader |
| 13 | **E11 T6** (tras E1 T9 y E11 T3 integradas) | punta de `v2/e11-notificaciones` con `version-2` (E1 T9 adentro) | sonnet | `GameState.swift` | E1 T10/T12–T14 y todo dueño de `GameState`: va en una ventana (E11 la quiere justo tras T9; si eso frena a E1 T10, después de E1 T14) |
| 14 | **E3a T9**, **E3b T5 → T6 → T7**, **E2a T9** | sus ramas, con `version-2` (E1 T14 adentro) | sonnet | `GameState.swift` (de a una) | entre sí y con E1 T10–T14 |

Después de E1 T16 se destraban E3b T9 → E4a T3 y E4a T9, y con ellos E4b, E5a T4–T8, E5b, E6a y
E7b. La cola se rearma con las tablas de §5.

### 4.4 Para decidir en el relevo 7: partir `GameState.swift` en extensiones

**Es una propuesta, no una decisión**: la toma el controlador del relevo 7.

- **El problema.** 20 tareas pendientes tocan `GameState.swift` (§3.1) y, con un dueño por ola, van
  de a una. Hasta E1 T14 casi no hay ventanas.
- **Qué hacen ahí casi todas** (según sus planes): sumar una o dos propiedades o proyecciones y su
  línea en `refreshProjections` (E1 T9, T10; E3a T9, T10; E11 T6; E4b T1; E3b T9), un caso de
  `TowerNotice.Kind` (E1 T13, T14), un método (E2a T9), un renombre (E3b T5) o borrar algo (E1 T12
  `resyncTower`; E4b T4 `activeEvent`; E4b T9 `specialInfo`). Pocas tocan lógica compartida: el
  frame loop (E1 T9, T10) y `bootstrap`.
- **La forma hoy** (1.169 líneas): tipos anidados (~140, líneas 19–160), el estado observado y el
  autoritativo (~360, 163–527), `bootstrap` (~390, 529–920), el frame loop (`tick`, `flushHUD`) y
  lo interno (`refreshProjections` ~115, `scheduleSave`, `persistNow`).
- **La propuesta.** Una tarea mecánica (sonnet, sin cambio de conducta): en `GameState.swift`
  quedan sólo las propiedades almacenadas y el init, porque Swift no deja ponerlas en una
  extensión; el resto se muda a `+Types`, `+Bootstrap`, `+FrameLoop`, `+Projections` (con
  `refreshProjections` partido en un ayudante por zona) y `+Persistence`. Se verifica con el
  `rapido` con la misma cuenta de tests, y la revisión compara los bloques movidos byte a byte (como
  se hizo con `finishBootstrap` en E1 T5).
- **Lo que ganaría.** Con el estado en un bloque por épica (`// MARK: E4b`, …), sumar propiedades
  deja de ser "tomar el archivo": dos tareas que agregan en bloques distintos se integran sin
  conflicto, y el 🔥 pasa a ser por extensión. Las tareas que sólo suman estado y una proyección
  podrían compartir ola (E11 T6 al lado de E1 T10, E3a T9 al lado de E1 T12–T14, E4b T1 con E5b
  T2). Seguiría en serie lo que toca la misma lógica: el frame loop y `bootstrap`.
- **El costo.** Una tarea más en el camino crítico de E1 (toma el archivo entero en su ola). Los
  planes que citan `GameState.swift:NNN` quedan apuntando a otro archivo; esas líneas ya están
  corridas desde E1 T5 y T8, y las tareas hacen un paso 0 con `grep`, pero cada brief nuevo tiene
  que nombrar la extensión. Se recupera si después dos o más tareas comparten ola.
- **Cuándo.** Antes de E1 T9 retrasa T9 y no cambia su brief (T9 suma dos propiedades al cuerpo y
  crea su propia extensión); entre T9 y T10 no retrasa T9, pero sí T10.

## 5. Las épicas (orden de PLAN-v2 §4)

Columnas: **ID** · título corto · **estado** · depende de (sin prefijo = misma épica) · 🔥 / tibios
que toma · commit o rama · nota.

### Hechos previos a los planes por tarea (fuera del conteo)

| Pieza | Estado | Dónde |
|---|---|---|
| E0 — el oráculo `Tools/v2/oraculo.sh` (`rapido`/`completo`), `rojos.py`, `rojos-declarados.txt` | ✅ | `958ec9a` · `Docs/SESION-2026-10-06-v2-e0-oraculo.md` |
| E8 pipeline — calado, `npc`/`skinfam`, contrato de loops | ✅ | `Docs/SESION-2026-10-06-v2-e8-pipeline.md` |
| E8 audio — 10 temas por piso + 3 SFX sin cablear | ✅ | `Docs/SESION-2026-10-06-v2-e8-audio.md` |
| E7a — protocolo, unidades por momento, `AdsRemoteConfig`, `NaturalBreakPolicy`, remove_ads | ✅ | `Docs/SESION-2026-10-06-v2-e7a-anuncios.md` |
| E3 i18n — `IAPCopy` y lo de idioma | ✅ | `Docs/SESION-2026-10-06-v2-e3-i18n.md` |
| E10 en papel — doc ASC/AdMob/mediación, IAP, store metadata, Términos | ✅ | `Docs/SESION-2026-10-06-v2-e10-docs.md` |

### E1 — Correcciones críticas y save v6 seguro (`2026-10-06-v2-e1-correcciones-criticas.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E1-T1 | Offline: toda ausencia se paga, popup desde 30 s | ✅ | — | 🔥 GameState | `3693044` | |
| E1-T2 | La Milanesa lee su magnitud del JSON | ✅ | — | 🔥 ContentSystems, +Bonus | `37c565f` | |
| E1-T3 | Un solo mutador de la frontera, contadores Double | ✅ | — | 🔥 PlayerState, TowerActions | `111bbfb` | |
| E1-T4 | Save v6 y el contenedor de engagement | ✅ | T3 | 🔥 PlayerState | `76a69c1` | el 🔒 de `SaveConflictResolver:67/:68` lo resuelve T6c |
| E1-T5 | Nunca más pisar un save ilegible | ✅ | T4 | 🔥 GameState, RootView, catálogo | `38bee13` | |
| E1-T5b | (seguimiento) copias que no se pisan, cada payload ilegible | ✅ | T5 | — | `08b9329` + `0cfe6c9` | fuera del conteo |
| E1-T5c | (seguimiento) el `if` muerto en Release + `rapido` compila Release | ✅ | T8 | 🔥 GameState (sólo `bootstrap`); `oraculo.sh` | `e0a5d53` + `ca2d12c` (merge `7110b06`) | fuera del conteo; cherry-pick encima de T8 y sus arreglos |
| E1-T6 | Reconstruir el ORO comprado de la v1 | ✅ | T4 | Info.plist | `cdd8f0a` | T6b la absorbe T6c |
| E1-T6c | (seguimiento) ORO comprado exacto entre dispositivos + T6b | ✅ | T4, T6 | 🔥 PlayerState (`MetaState`); SaveConflictResolver, +Store, StoreManager | `40df25e` + `4252402` + `ec5d296` (merge `b09b4c4`) | el plazo vencido deja abierta la reconstrucción; E6a usa `recordOroPurchase` |
| E1-T7 | El embudo `BoardChange` en EK | ✅ | T3, T4 | — | `ec6fb29` | carries: init público de `BoardChangeOutcome` (T9), guarda de `typeId` (T10) |
| E1-T8 | Ciclo de vida: sellar al irse, latido, evento vencido | ✅ | T5 | 🔥 GameState, RootView, +Bonus; FisuEvolutionApp, +Debug, ContentConfigs, events.json | `eeb7322` + `5ef7a65` (merge `7110b06`) | re-revisión opus ✅: `flushHUD` sólo proyecta con la escena inactiva; un sello por salida |
| E1-T9 | El turno de los cambios del tablero | ✅ | T7, T8, T5c | 🔥 GameState; +BoardChanges (nuevo), +Celebrations, +Lifecycle, +Debug | `65881ce` + `4572e6a` (merge `b09b4c4`) | re-revisado por el controlador; carries a T10/T12/T14 en el ledger |
| E1-T9b | (seguimiento) partir `GameState.swift` en extensiones por zona, sin cambio de conducta | ✅ | T9 | 🔥 GameState (entero) | `3d4fb8d` (merge `b09b4c4`) | 1.174 → 334 líneas; mapa símbolo→archivo en `task-9b-report.md`; los `private(set)` pasan a `var` (no hay otra en Swift) |
| E1-T10 | La escena reproduce los cambios y revela | ✅ | T9 | 🔥 BoardScene, GameState, RootView; CelebrationQueue, +Celebrations, +Debug | `4c11a0a` + arreglos `92b2b9f` (merges `b09b4c4`, `a24a57f`) | |
| E1-T11 | El sorteo de eventos salta lo inaplicable | ✅ | T7; T8 integrada | 🔥 ContentSystems, +Bonus; ContentConfigs, events.json | `70f216f` (merge `b09b4c4`) | el plan la pone ∥ T10; por archivos también va ∥ T9 (no acorta el camino crítico) |
| E1-T12 | Startup, Blanqueo, videos y carrera por el embudo | ✅ | T9, T10, T11 | 🔥 ContentSystems, +Bonus, GameState; +Actions, +Debug | `7febd2b` + `c355f14` + `664f3cc` (merge `5fafaf4`) | en `.inactive` se asienta lo pagado (videos, carrera; también en vuelo); el resto en `.background`. E2a T3/T4 pasaron a después de T14|
| E1-T13 | El Corralito congela el gasto, con salida por video | ✅ | T12 | 🔥 TowerActions, ContentSystems, +Bonus, GameState, RootView, catálogo; +Hiring, +Actions, ContentConfigs | `d838fdb` + arreglos `8adab56` (merge `9a641c7`) | revisión opus + arreglos (precarga del video, UI coherente con contratar gratis, UpgradeManager, pill debajo en el SE); M5 → E4 |
| E1-T14 | Un video sin efecto no gasta el cooldown | ✅ | T9–T13 | 🔥 +Bonus, GameState, RootView, catálogo; +BoardChanges, +Achievements | `36885a3` + arreglos `f01e7b6` (merge `545208b`, claves `3d568f6`) | revisión opus + arreglos (test por el camino real con monto exacto, logros, audio) |
| E1-T15 | `EffectContractTests` | ✅ | T1–T14 | ActiveModifier, ContentConfigs, AdsProvider | `02952ce` (merge `9f9933e`) | mutantes del controlador: 2 rojos |
| E1-T16 | Cierre de E1 (controlador) | ✅ | T1–T15, T5c, T6c | `Docs/` | | `completo --limpio` #1 sobre `69a5f80`: EK (tras `swift package clean`), unit 760+1, Store, pipeline, pacing-sim VERDES; UI 69/70 con `MenuUITests` flaky (aislada 7/7 ×2). **#2 sobre `e378307` en curso** (`build/relevo11-completo-limpio-2.log`): ROJO en UI por 3 REGRESIONES reales de la ola H (se repiten aisladas sobre e378307): MenuUITests.testLosTerminosSeAbrenDesdeAjustes (el documento de Términos se dibuja vacío; pasaba aislado sobre 69a5f80 → sospecha E3b T3, NavigationStack(path:) en MenuView), BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos (no encuentra debug.chest.award → sospecha E2a T14, sección nueva del panel de debug) y CharacterSheetUITests.testDespedirPideLaTarjetaDeLaCasaYNoUnaAlerta (sospecha E2a T12 o E4a T8). Todo lo demás VERDE: EK 553 · unit 782+1 · release 0 · store-unit 16 · store-ui 2 · ipad-ui 2 · pipeline 49 · pacing-sim 30,73 h / 13. E1 T16 NO cierra: primera tarea del relevo 12 = arreglar las 3 (bisecar con los merges de la ola H si la sospecha no alcanza), re-correr esas clases aisladas y después un completo --limpio sobre la punta. Con el #2 verde, se cierra E1 y se escriben los docs de cierre; cerrada en el relevo 12: `completo --limpio` sobre `c94f75f` VERDE (UI 70/70) |

### E11 — Notificaciones (`2026-10-07-v2-e11-notificaciones.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E11-T1 | Catálogo y planificador de la ausencia (EK) | ✅ | — | — | `508a4c5` | |
| E11-T2 | `notifications.json` validado y sus textos | ✅ | T1 | 🔥 catálogo; GameContentLoader | `9c5847c` | |
| E11-T3 | El manager 2.0: prendidas por defecto, permiso en dos pasos | ✅ | T1, T2 | 🔥 SettingsView, catálogo | `3430d72` + `f7dff48` (merge `b0f6f6c`) | arreglos I1/I2 con mutación verificada; `rapido` VERDE 653 + 1 |
| E11-T4 | Ajustes: el maestro, uno por motivo, "Abrir Ajustes" | ✅ | T3 | 🔥 SettingsView, catálogo | `02cc5fb` (merge `d3a4912`) | el rojo de `MenuUITests…ApagaLasParticulas` era flaky: verde en el `completo` de `15318a0`|
| E11-T5 | La tarjeta del permiso en el popup offline | ✅ | T3 | catálogo (snapshot si va con T4); OfflineEarningsView | `597b60e` (merge `c47d93e`) | SE e iPad sin medir (E3a T12)|
| E11-T6 | El cableado al ciclo de vida | ✅ | T3; E1-T1, E1-T5, E1-T8, E1-T9 | 🔥 GameState; +Lifecycle, +Celebrations, FisuEvolutionApp | `3825d8c` (merge `2604119`) | completo pendiente (sin UI tests propios) |
| E11-T7 | Cierre de E11 (controlador) | ✅ | T1–T6 | `Docs/` | | |

### E3a — UX núcleo, la pantalla (`2026-10-07-v2-e3a-ux-nucleo.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E3a-T1 | El catálogo canónico (`catalogo.py`) | ✅ | — | — | `f542b16` | |
| E3a-T2 | Spikes S1, S4, S5, S6 | ✅ | — | — | sin commit (ledger de E3a) | cambian T4, T6, T8, T10 |
| E3a-T3 | `PlayLayout` | ✅ | — | — | `f03950c` + `5afb893` (0,63) | |
| E3a-T4 | `ScreenInsets` y `PlayColumn` | ✅ | T3 | — | `b988bc3` + `537f923` | |
| E3a-T5 | Universal, iOS 18, contrato del Info.plist | ✅ | — | 🔥 project.yml; Info.plist, PanelFrames | `c323dd9` (merge `3956fd3`; `rapido` VERDE) | carries a T6, T10, T12 en el ledger; el release con Xcode 26.x |
| E3a-T6 | Hojas y popups en iPad (`fisuSheet`) | ✅ | T4, T5 | PanelFrames, 8 popups, HUDView, OfflineEarningsView | `428f55f` (merge `2087d71`) + RootView `60af174` | quedan 2 `.sheet` a propósito en RootView (share, debug) |
| E3a-T7 | La barra de abajo más baja, Contratar al centro | ✅ | T4 | GameArtComponents, BottomMenuBar | `c6a4a90` (merge `9eeb9eb`) | carry T10: `BoardScene.bottomInset` → `panelHeight` (64)|
| E3a-T8 | La botonera del ascensor | ✅ | T6 | catálogo (o snapshot); PanelFrames, HUDView, AudioManager | `aae3a7f` + claves `f9207c2` (merge `9eeb9eb`) | carry T12: en DEBUG el display tapa el chip ×1,0; medir SE|
| E3a-T9 | Las pestañas aparecen de a poco | ✅ | T7; E1-T4; ventana de GameState | 🔥 GameState, catálogo; +Debug, GameContentLoader | `02ee23b` (merge `c76af46`, claves `528d10b`) | carry T12: captura del ¡Nuevo! y SE con 4 pestañas; carry E9: lecciones sobre pestañas cerradas |
| E3a-T10 | La escena: PlayLayout, 3 filas, cámara, iPad | ✅ | T3, T7, T8; E1-T10 | 🔥 BoardScene, GameState, RootView; `oraculo.sh` | `789c200` (merge) | sin capturas SE/16 Pro → T12; ElevatorPanelUITests sensible a carga |
| E3a-T11 | La raíz: chrome en la columna, seis hojas | ✅ | T6, T10 | 🔥 RootView | `558b6cf` (integ-r20) | no con E1 T13–T14; **hecha (r20):** `playColumn` en ActiveBonusBar/EventBannerView/fila atajo-prestigio; seis hojas por `fisuSheet`; iPad Pro 13 `IPadLayoutUITests` 4/0; sin iPhone de `BottomMenu`/`BonusHUD`/`HUDRedesign` |
| E3a-T12 | Cierre de E3a: SE en castellano, capturas de iPad | ✅ | T1–T11 | `oraculo.sh` | | carries: `ScreenInsetsUITests` al `se-ui`; fijar Xcode 26.x como SDK del release (el SDK 27 ignora `UIRequiresFullScreen`); **destrabada (r20):** T11 ✅; corre `BottomMenuUITests`, `BonusHUDUITests` y `HUDRedesignUITests` en iPhone (T11 no los corrió); controlador, con el `completo` |

### E3b — UX núcleo, las interacciones (`2026-10-07-v2-e3b-ux-nucleo.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E3b-T1 | Spikes S2, S3 | ✅ | — | — | sin commit (reporte en el ledger de E3b) | S2: no hace falta scrollDisabled; carries a T3 (scrollTo inicial, un solo `sheet.close`). S3: la bandera de T7 hace falta |
| E3b-T2 | La ficha de personaje | ✅ | E3a-T6, E3a-T7 | catálogo (snapshot); GameArtComponents, DebugPanelView | `e33b844` (merge `171241e`, claves `2408acc`) | carry E3a T12: detent `.large` con vacío abajo; captura SE |
| E3b-T3 | El menú deslizable, las piezas | ✅ | T2; E3a-T8 | catálogo; PanelFrames, MenuView | `77c277e` (merge `e378307`) | MenuSessionTests verde; carries a T4: MenuPagerUITests, menuDidOpen/PageChanged/Close en RootView, comprobar S2 (carrusel de Pintas vs gesto) en simulador |
| E3b-T4 | El menú deslizable, montado | ✅ | T3; E3a-T9, E3a-T11 | 🔥 RootView | `62e4315`+`49aecc0` (integ-r20) | **hecha (r20):** `menuSession` en `RootView`; sólo la página quieta queda montada; Tienda = sesión de 1 página; 5 páginas; `BonusHUDUITests` del cofre rojo también en la base |
| E3b-T5 | Renombre `BestHire` → `QuickHireOffer` | ✅ | ventana sin E1 en GameState y +Hiring | 🔥 GameState, RootView (comentarios); +Hiring, +TutorialTips | `61a661d` |; tocó también `GameState+Projections.swift` (2 líneas) y dos tests; `PacingSimulator.bestHire` es otra cosa y queda |
| E3b-T6 | La oferta del atajo v2: pin, motivo, nunca `nil` | ✅ | T5; E1-T4, E1-T13 | +Hiring | `741af10`+`6255531` (integ-r14) | revisión sonnet: Approved con arreglos (la lección del atajo pide `blocker == nil`; tests de piso lleno; comentarios de RootView), hechos. **Carry a T7**: `QuickHireButton` todavía no usa `blocker` (temblor sólo con `!affordable`, label "Contratar a X", `accessibilityState` sin usar) y marca la lección al tocar aunque esté bloqueado; la oferta ya nunca es nil (el botón queda siempre) |
| E3b-T7 | El botón del atajo nunca desaparece | ✅ | T6 | catálogo; QuickHireButton | `06990b0`+`dc08eb9` (en `v2i/integ-r15`) |; usa `blocker` (gris, "Piso lleno", temblor; la lección sólo con blocker nil); long press 0,45 s → `onChoose` (lo pasa T8 desde RootView); la bandera la baja un DragGesture 250 ms tras soltar; UI QuickHireButton 3, Tutorial 6, BottomMenu verdes |
| E3b-T8 | El selector del atajo | ✅ | T7, T4 | 🔥 RootView, catálogo; DebugPanelView | `42c61f0` (en `v2i/integ-r21b`) | `QuickHirePicker` overlay anclado a `resolved[.quickHire]` junto al `TutorialOverlay`; `QuickHireButton(onChoose:)` cableado; sección «Atajo» en el panel de debug; Receta R 16 Pro: QuickHire 3/3, QuickHireButton 3/3 (2 ajustados: el selector tapa el atajo), BottomMenu 4/4, Tutorial 9/9; sin oráculo `tarea` (sin unit nuevo); diff de `RootView` leído; +3 claves. Destraba a E3b T9 y a E4b T3 |
| E3b-T9 | Compartir recableado (y cierre de E3) | ✅ | T8; E1-T16 | 🔥 GameState, +Bonus, RootView, catálogo; +BoardChanges, +Debug, ContentConfigs, EngagementState | `2189a09`+`c8af0ca` (en `v2i/integ-r22`) | su `sharedMoments` lo esperan E4a T3 y E5a T4 ; rev. opus: arreglos hechos (lifetimeEarnings, comentario de BoardScene, la X cierra la lección); **al dueño:** la oferta descartada se pierde; puede gastar sus 10 s detrás del intersticial de `celebrationsDrained` (→ E7b-a T3); el premio de reencarnación es casi nulo |

### E2a — Mecánicas de economía (`2026-10-07-v2-e2a-mecanicas.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E2a-T1 | `RewardScale`: premios en minutos | ✅ | E1-T3 | — | `434b0ee` (merge `9018bae`) | EK|
| E2a-T2 | El reintegro al fusionar + `EconomyKnobs` | ✅ | E1-T3, E1-T4 | 🔥 PlayerState | `cf6dfa9` → `446397c` (merge `968d504`) | perilla en 0 = v1|
| E2a-T3 | El amortiguador y el "+6 %" | ✅ | T2 | 🔥 PlayerState, TowerActions | `eae6082` (merge `545208b`) | perilla 0 |
| E2a-T4 | Pisos en marcha y la capacidad que sólo crece | ✅ | T3 | +Actions | `f38d50e` (merge `545208b`) | perilla 0 |
| E2a-T5 | El piso móvil para reencarnar | ✅ | T4; E1-T4 | — | `4ba38d8` (merge `6976f2f`) | perilla ausente; carry: el botón puede mostrar `lastRunWallGoal` |
| E2a-T6 | "Fusionar todo", el plan | ✅ | E1-T7 | BoardChange.swift | `2c4ca71` (merge `968d504`) | EK|
| E2a-T7 | Cofres y packs de plata en minutos | ✅ | T1; E1-T6 | +Store, products.json, StoreManagerTests | `acf633d` (merge `b0bcf7b`) | store-unit + pacing-sim → próximo `completo` |
| E2a-T8 | El piso móvil en pantalla | ✅ | T5; E1-T4 | catálogo (snapshot) | `2ae35c1` (merge, claves `72a236b`) | deps listas (T5 🟢); catálogo por snapshot |
| E2a-T9 | Las fusiones del juego al amortiguador y al reintegro | ✅ | T2, T3, T6; E1-T7, E1-T9, E1-T12, E1-T14 | 🔥 TowerActions, GameState; GameContentLoader, +Actions, +BoardChanges | `18e8e77` (merge `6976f2f`) | perillas 0 = identidad |
| E2a-T10 | "+6 % por compra" en FisuJobs | ✅ | T3, T9; E1-T13 | +Hiring; catálogo (snapshot) | `db669f0` (merge, claves `72a236b`) | carry E3a T12: truncados previos en el SE |
| E2a-T11 | Diario, asado y logros en minutos + presupuesto | ✅ | T1, T7; E1-T14, E1-T15 | 🔥 ContentSystems, +Bonus | `afca476` + arreglos `8b0ebbe` (merge `e378307`) | revisión opus: Approved con arreglos (día 7 pinea 15 min exactos). Carries: indentación `ContentSystems.swift:426-428`; clave muerta `bonus.effect.payout %@`; las carreras seguían con `passiveUnlockCost` (lo cierra T12) |
| E2a-T12 | Las carreras: gratis, Juicio ganado, Obra social | ✅ | T11, T7; E1-T11, E1-T13, E1-T15 | 🔥 TowerActions, +Bonus | `2d42b83` (merge `860e944`, claves `e378307`) | revisión opus: Approved con arreglos (M3 hecho en el merge). `freeHire` nace acá; `eventImmunity` cableada a `eventIsApplicable`. Carries Minor: M1 `activeEvent` no se persiste (el Médico no corta un evento negativo tras relanzar: sacar modificadores `event.*` !isBuff si `activeEvent == nil`); M2 `eventIsApplicable` usa `Date()` y criterio !isBuff vs "mixtos" de E4a (reconciliar en E4a); M4 contratar gratis atraviesa el Corralito (decisión a anotar); M5 FisuJobs muestra "0" y no "Gratis"; claves huérfanas `career.reward.welcome %@`, `career.reward.boost %@ %@`, `career.reward.modifier %@ %@` y `bonus.effect.payout %@` (las saca una tarea dueña del catálogo) |
| E2a-T13 | Pisos en marcha en el mapa | ✅ | T4, T9; E1-T15 | catálogo (snapshot) | `ab2a137` (merge `e378307`, claves aplicadas) | `staffedSummary` + badge `map.staffed` |
| E2a-T14 | El panel de debug: variantes, perillas, Fusionar todo | ✅ | T5, T6, T9 | +Debug, DebugPanelView, +BoardChanges | `05136be` (merge `e378307`) | todo bajo #if DEBUG salvo `enqueueMergeAll` (sin llamadores); falta la prueba manual del paso 4 del plan (el dueño) |
| E2a-T15 | Cierre de E2a + tabla de perillas para E2b | ✅ | T1–T14 | `Docs/` | | |

### E4a — Visitantes y eventos v2, el motor (`2026-10-07-v2-e4a-visitantes-eventos.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E4a-T1 | `RewardSpec` | ✅ | — | — | `8d0a311` (merge `bba9e39`) | EK; cimiento de E5–E7 |
| E4a-T2 | Efectos nuevos: paro, inmunidad, ritmo de paquetes | ✅ | E1-T13, E1-T15 | catálogo (snapshot); ActiveModifier, ActiveBonus*, EffectContractTests | `a031ee8` (merge, claves `8cf4e73`) | paro, inmunidad, ritmo de paquetes |
| E4a-T3 | Los relojes en `meta.engagement` | ✅ | E1-T4, E3b-T9 | EngagementState | `938efcb` (en `v2i/integ-r22`) | (ambigua: ver "Inconsistencias", punto 3) |
| E4a-T4 | El motor de eventos v2 (EK) | ✅ | T1, T2, T3 | — | `9db72db` (en `v2i/integ-r22`) | |
| E4a-T5 | Los visitantes, puros | ✅ | T1, T3 | — | `7f51f23` (en `v2i/integ-r22`) | |
| E4a-T6 | `VisitPlanner` | ✅ | T5; E1-T7, E1-T14 | BoardChange.swift, +BoardChanges | `d37ab28` (en `v2i/integ-r22`) |  carry a E4b T2/E4a T9: `.visitor` no es prepago, una visita pagada con video que se descarte no se compensa |
| E4a-T7 | El contenido de los visitantes | ✅ | T5, T6; E11-T2, E3a-T1 | catálogo (snapshot); GameContentLoader, LocalizationCompletenessTests | `9eb8efd` (en `v2i/integ-r22`, 81 claves) | carga el Anexo A (con los guiños: Coach 67 toques, Crypto Bro "six seven", Vecina "andá pa' allá, bobo"; PLAN-v2 §2) |
| E4a-T8 | `grant` y el momento calmo | ✅ | T1, T2; E1-T8, E1-T14 | — | `8376c23` (merge `e378307`) | sin llamadores todavía; carries a T9: `isCalmMoment` duplica `isSafeMomentForInterstitial` (E7b lo unifica); los kinds fuera de `grantableRewardKinds` no se ofrecen (VisitorScheduler/`eventIsApplicable`) |
| E4a-T9 | La mudanza a eventos v2 | 🔄 | T2, T4, T7, T8; E1-T16 | 🔥 GameState, +Bonus, ContentSystems, catálogo | | |
| E4a-T10 | Cierre de E4a | ⛔ | T1–T9 | `Docs/` | | |

### E4b — Visitantes y eventos v2, lo que se ve (`2026-10-07-v2-e4b-visitantes-eventos.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E4b-T1 | El escenario y su turno | ⛔ | E4a-T10; E3a-T10, E1-T10 | 🔥 GameState, BoardScene; CelebrationQueue, +Celebrations, +Debug | | |
| E4b-T2 | Los visitantes en la partida | ⛔ | T1 | catálogo (snapshot); +Engagement, +Debug, DebugPanelView | | no con E5a T6 |
| E4b-T3 | El chip, el popup y el retrato | ⛔ | T2; E3a-T11, E3b-T4, E3b-T8, E3b-T9 | 🔥 RootView, catálogo; +TutorialTips, TutorialAnchor | | crea `RewardedOfferButton` (lo completa E7b-b T7) |
| E4b-T4 | Eventos con presentador; adiós al banner | ⛔ | T3 | 🔥 GameState, RootView, catálogo, +Bonus; CelebrationQueue, +Celebrations, ActiveBonus* | | |
| E4b-T5 | El reto y las cartas del Vendedor | ⛔ | T3 | catálogo (snapshot) | | ∥ T4 |
| E4b-T6 | El Apagón y los Campeones | ⛔ | T4 | 🔥 BoardScene; AudioManager | | cablea `sfx_blackout` |
| E4b-T7 | La Liquidación en el precio | ⛔ | E4a-T9; E3b-T5, E3b-T6, E3b-T7 | ActiveModifier, +Hiring, GameArtComponents; catálogo (snapshot) | | |
| E4b-T8 | El Álbum de especiales | ⛔ | E4a (cerrada); E3b-T3 | catálogo; MenuView, +TutorialTips | | |
| E4b-T9 | Los especiales salen del tablero | ⛔ | T8, T6 | 🔥 BoardScene, GameState, RootView, PlayerState (docstring); +BoardChanges, +Debug | | |
| E4b-T10 | Cierre de E4 | ⛔ | T1–T9 | `Docs/` | | |

### E5a — Aduana, Colchón y Ruleta, el motor (`2026-10-07-v2-e5a-aduana-colchon-ruleta.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E5a-T1 | El Paquete de la Aduana, puro | ✅ | E1-T3 | — | `b4800c5` + `a4c156f` (merge `bba9e39`) | carries a T2/T3/T5/T6 en el ledger |
| E5a-T2 | El Colchón, puro | ✅ | T1; E4a-T1 | — | `d6a1421` (merge `bba9e39`) + mutantes `f6f8e2f` (merge `0fa932c`) | |
| E5a-T3 | La Ruleta, pura | ✅ | T1; E4a-T1 | — | `4d1d426` (merge `bba9e39`) + mutantes `f6f8e2f` (merge `0fa932c`) | mutantes T2+T3: 92/93 |
| E5a-T4 | Paquetes, colchón y ruleta en `meta.engagement` | ✅ | T1–T3; E3b-T9, E4a-T3 | EngagementState | `c00943c` (en `v2i/integ-r22`) | |
| E5a-T5 | El contenido: `packages/treasures/wheel.json` | ⛔ | T1–T3; E4a-T7, E4a-T9 | GameContentLoader | | carry: validador `isFinite` |
| E5a-T6 | El Paquete en la partida | ⛔ | T4, T5; E1-T9, E1-T10, E1-T14; E4a-T2, E4a-T6, E4a-T8, E4a-T9 | +Rewards, +Engagement, +BoardChanges, BoardChange.swift | | no con E4b T2 |
| E5a-T7 | El Colchón en la partida | ⛔ | T6 | +Engagement | | |
| E5a-T8 | La Ruleta en la partida | ⛔ | T7 | +Rewards, +Engagement | | crea `LootBoxGate` |
| E5a-T9 | Cierre de E5a | ⛔ | T1–T8 | `Docs/` | | |

### E5b — Aduana, Colchón y Ruleta, lo que se ve (`2026-10-07-v2-e5b-aduana-colchon-ruleta.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E5b-T1 | La Ruleta en pantalla | ⛔ | E5a-T8; E4b-T3 | catálogo (snapshot); AudioManager | | cablea `sfx_wheel_tick`; crea `OddsDisclosureView` y `RewardCopy` |
| E5b-T2 | Los accesos y las hojas | ⛔ | T1; E5a-T6, E5a-T7, E5a-T8; E4b-T3, E4b-T4, E4b-T9; E3a-T6, E3a-T11 | 🔥 GameState, RootView, catálogo; +Rewards, DebugPanelView | | |
| E5b-T3 | La escena: cajas, colchón, apertura | ⛔ | T2; E1-T10; E4b-T1, E4b-T6, E4b-T9; E3a-T10 | 🔥 BoardScene | | |
| E5b-T4 | La Ruleta en Regalos | ⛔ | T1 | catálogo (dueña o snapshot) | | |
| E5b-T5 | Las lecciones del paquete, el colchón y la ruleta | ⛔ | T2, T4 | catálogo (snapshot); +TutorialTips, TutorialAnchor | | |
| E5b-T6 | `wheel_ready` | ⛔ | T1; E11-T4, E11-T6 | catálogo (snapshot) | | |
| E5b-T7 | Cierre de E5 | ⛔ | T1–T6 | `Docs/` | | |

### E6a — Tienda de ORO, packs y ofertas (`2026-10-07-v2-e6a-tienda-ofertas.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E6a-T1 | Tienda y ofertas en `meta.engagement` | ✅ | E1-T4; E3b-T9, E4a-T3, E5a-T4 | EngagementState | `229579f`+`f52c803` (en `v2i/integ-r22`) |  rev. opus Approved; carries: T2/T10 marcan `lastClosedAt` en toda compra y vencimiento; T11 acredita aunque la oferta ya no figure abierta; E9b T7: `resolveAcrossReset` no cruza `engagement.offers`; al dueño: oferta abierta sólo en el save perdedor (Bienvenida) se pierde, ×3 regalado en el caso raro |
| E6a-T2 | Catálogo y cuentas de la tienda (EK) | ✅ | T1; E4a-T1 | — | | |
| E6a-T3 | El auto-tap | ✅ | E1-T15; E4a-T2; E2a-T4 | catálogo (snapshot); ActiveModifier, ActiveBonus*, EffectContractTests | `720f3fe` (merge `e378307`, claves aplicadas) | revisión opus: Approved. Carries a T5: el "mejor" se elige por tier y no por pago (fiel al plan; anotar la decisión); un `now` para todo el delta (despreciable con tope 2 s); `RewardSpec` admite `.modifier(autoTapPerSecond)` y saltea `.autoTap` (rechazarlo en `validate` o declararlo válido) |
| E6a-T4 | `oro_shop.json` | ⛔ | T2; E5b-T1; E5a-T5 | catálogo (dueña); GameContentLoader | | |
| E6a-T5 | Se entregan auto-tap, Offline ×3 y Diario ×3 | ⛔ | T3; E4a-T8, E4a-T9; E5a-T6, E5a-T8; E2a-T11 | 🔥 +Bonus; +Lifecycle (T8 mudó ahí el offline), +Rewards, +Engagement | | |
| E6a-T6 | Comprar en la tienda | ⛔ | T4, T5; E2a-T14; E1-T14; E5a-T1, E5a-T3, E5a-T6, E5a-T8 | BoardChange.swift, +BoardChanges | | |
| E6a-T7 | La suerte: probabilidades | ⛔ | T6; E5a-T1, E5a-T8; E1-T6 | StoreManager | | sale con E1 T6c adentro |
| E6a-T8 | La pantalla "Comprar ORO / Gastar ORO" | ⛔ | T6, T7; E3b-T4; E5b-T1; E5a-T8 | catálogo (dueña); StoreView | | |
| E6a-T9 | Los packs 160 / 550 / 1.400 | ✅ | E1-T6; E2a-T7 | products.json, StoreManagerTests | `7cc20d9` (merge `2446069`) | StoreManagerTests 13/14 a mano (timeout de carga, solo pasa) |
| E6a-T10 | Las ofertas de 24 h, puras | ✅ | T1; E4a-T1 | — | | |
| E6a-T11 | Las ofertas se cobran | ⛔ | T9, T10; E4a-T8; E2a-T7; E5a-T6 | catálogo (snapshot); products.json, +Store | | con T6c: por `recordOroPurchase`, no `+=` |
| E6a-T12 | Las ofertas se ven | ⛔ | T7, T8, T11; E5a-T8; E4b-T3; E3a-T6; E5b-T1, E5b-T2 | 🔥 RootView, catálogo; CelebrationQueue, +Celebrations | | |
| E6a-T13 | Cierre de E6a | ⛔ | T1–T12 | `Docs/` | | |

### E6b — Lugares extra, pintas con ORO, efectos y familias (`2026-10-07-v2-e6b-lugares-skins.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E6b-T1 | Los 8 efectos, por código | ✅ | — | — | `f9cd4b9` (merge `15318a0`) | |
| E6b-T2 | La galería de los 8 efectos (→ 🔒 dueño) | ✅ | T1 | DebugPanelView | `d3c0889` (merge `15318a0`) | el dueño no aprobó ningún efecto → se borra en T1r |
| E6b-T3 | `skins.json` v2 (EK) | ✅ | T1 | GameContentLoader | `2ba7c2e` (merge `e27efb1`) | el caso `.effect` se quita en T1r |
| E6b-T1r | Sin skins por código: borrar shaders (T1), galería (T2) y `Treatment.effect`/`shaderId` (T3) | ✅ | E3b-T2 (dueña de DebugPanelView) | DebugPanelView, GameContentLoader | `255749b` (merge `9c5df1e`) | −495 líneas; grep vacío |
| E6b-T4 | La pinta comprada con ORO es tuya | ⛔ | T3; E6a-T1, E6a-T2, E6a-T8; E3b-T2 | 🔥 PlayerState, catálogo; +Store | | |
| E6b-T5 | Familias se ven (sin efectos) | ⛔ | T1, T4; E6a-T8; E5b-T3 | 🔥 BoardScene, catálogo; +Store | | |
| E6b-T6 | Lugares extra (EK) | ✅ | E6a-T2; E2a-T4 | — | | |
| E6b-T7 | Lugares extra en la partida | ⛔ | T6; E6a-T6, E6a-T8, E6a-T12; E3a-T10; E5a-T6 | 🔥 GameState, catálogo; GameContentLoader, +Engagement | | 🔒 si las 4 filas no entran en el SE |
| E6b-T8 | Exclusivas de ORO elegidas entre skins de la v1 | ⛔ | T1r, T5 | catálogo | | el agente propone y se las muestra al dueño antes de cerrar |
| E6b-T9 | Las tres familias entran | ✅ | E8 T3–T5; T5 | catálogo | `b9e2cd0` (en `v2i/integ-r22`) | 🔒 arte de E8 = E8 T3–T5; 🔒 si el bundle crece > 60 MB (E8 T10 lo mide; estimado ≈ +29 MB con fondos en JPEG) |
| E6b-T10 | Cierre de E6b | ⛔ | T1–T9 | `Docs/` | | |

### E7b-a — Anuncios v2, los forzados (`2026-10-07-v2-e7b-a-forzados-mediacion.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E7b-a-T1 | La config remota en marcha | ✅ | E1-T8, E11-T6 | FisuEvolutionApp | `5fee22d` (integ-r19) |; **hecha (r19):** `ForcedAdsSetup` (modo, pacer por proceso); IDs remotos sólo en producción y Release (DEBUG siempre `googleTest`); rigen desde el próximo arranque; carry a T2: sacar `cadence:` de `configure` y el reloj `armIfDue` |
| E7b-a-T2 | Los cortes naturales | ✅ | T1; E1-T8; E3b-T4; E4a-T8 | 🔥 GameState, RootView; +Lifecycle, +Celebrations, FisuEvolutionApp | | **destrabada (r20):** E3b T4 🟢; dueña de `RootView` y `GameState`; saca `cadence:` de `configure` y el reloj `armIfDue` |
| E7b-a-T3 | La pausa publicitaria | ⛔ | T2; E4a-T8; E5a-T6; E5b-T1; E4b-T3; E1-T14 | 🔥 GameState, RootView, catálogo; DebugPanelView | | · **carries de E7b-a T2 (r21c, rev. opus):** hasta que entre T3 sale un intersticial en CADA corte (no alterna: `readyFormats` excluye la pausa, GameState+Ads.swift:32) → **no publicar T2 sin T3**; `recordShown` aunque no se haya mostrado (GameState+Ads.swift:74, usar un aviso de presentación); `releaseCelebrationsAfterAd` hace `restrict(to: nil)` a ciegas (:90-91, guardar/restaurar); sin plazo si el SDK no llama al delegado (congela la cola) |
| E7b-a-T4 | El app open al volver | ✅ | T2 | — | | no ∥ T3 (los dos editan `+Ads`) |
| E7b-a-T5 | "Opciones de privacidad" (UMP) en Ajustes | ✅ | E11-T4 | 🔥 SettingsView, catálogo | `86e6413` (integ-r20) | antes de los Ajustes de E9; **hecha (r20):** `AdsConsent.privacyRowVisible`, fila tras `purchasesSection`, +3 claves; sin prueba en región UE con el SDK real |
| E7b-a-T6 | La mediación: adaptadores, SKAdNetwork, Ad Inspector | ⛔ | T1; E3a-T5 | 🔥 project.yml; Info.plist, DebugPanelView | | las cuentas de las redes no la bloquean. **Dueño (2026-10-08):** sólo adaptadores de **Unity Ads** y **Meta Audience Network** por SPM (no AppLovin ni Mintegral); SKAdNetwork de Unity (`https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json`) al `Info.plist` (los de Meta `v9wttpbfk9`, `n38lu8286q` ya están); IDs en `Distribution/release/release.json → mediation` |
| E7b-a-T7 | Cierre de E7b-a (controlador) | ⛔ | T1–T6 | `Docs/` | | |

### E7b-b — Anuncios v2, la columna plegable (`2026-10-07-v2-e7b-b-columna-ubicaciones.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E7b-b-T1 | La columna, pura | ⛔ | E5b-T2; E2a-T14; E1-T14; E5a-T4…T8; E6a-T6 | 🔥 GameState; BoardChange.swift, +BoardChanges | | (ambigua: ver "Inconsistencias", punto 2) |
| E7b-b-T2 | Los videos de la columna | ⛔ | T1; E4a-T2, E4a-T8 | — | | |
| E7b-b-T3 | La columna plegable en pantalla | ⛔ | T2; E3a-T8, E3a-T10, E3a-T11; E5b-T2, E5b-T5; E4b-T3; E6a-T12; E7b-a-T3 | 🔥 RootView, catálogo; StageChips, PrizeChips, TutorialAnchor, ElevatorPanel | | |
| E7b-b-T4 | La multitud le deja lugar a la columna | ⏭️ | — | — | | el dueño eligió C (plegable) |
| E7b-b-T5 | Las lecciones de la columna | ⛔ | T3 | catálogo (snapshot); +TutorialTips | | ∥ T7 |
| E7b-b-T6 | Diario ×2 y carrera ×2 por video | ⛔ | E2a-T11, E2a-T12; E1-T12; E4a-T8; E4b-T3 | catálogo (snapshot) | | |
| E7b-b-T7 | El botón de video completo y el mapa de ubicaciones | ⛔ | T3, T6; E4b-T3…T5; E5b-T1, E5b-T2 | catálogo (snapshot) | | |
| E7b-b-T8 | Cierre de E7b (controlador) | ⛔ | T1–T7 | `Docs/` | | |

### E8 — Arte y animación (sin plan por tareas)

| Pieza | Estado | Qué falta |
|---|---|---|
| Pipeline y audio | ✅ | ver "Hechos previos" |
| El batch de imágenes (~200: visitantes, especiales hablando, paquete, colchón, tienda, álbum, 129 de familias) | 🔄 | aprobado (222/222); se integra con E8-T1…T10 (abajo) |
| Higgsfield: 18 loops de retrato + cinemáticas de reencarnación, arresto y Dios | 🔄 | los videos los generó la sesión del dueño (ver `DUENO.md`, "Videos de Higgsfield LISTOS"); falta el plan del lado Swift de `.cinematic` y `seenCinematics` (planificador opus, ningún plan lo tiene) |
| Fondos regenerados a 2048 px | ✅ | E8 T8 (`6029e73`); falta medir la memoria del vuelo (E8 T10) |
| La cadena animada de "Fusionar todo" | ⛔ | E2a la deja a E8; ningún plan la toma |
| Los 10 temas | 🔒 | el dueño los escucha (gate de E8 audio) |

Integración del arte aprobado (plan `2026-10-08-v2-e8-integracion-arte.md`, rama de épica `v2/e8-arte`):

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8 | Plan de E8 integración de arte | ✅ | — | — | `dec80f9` | 10 tareas; `2026-10-08-v2-e8-integracion-arte.md`; 13 dudas con default |
| E8-T1 | El rentista con soles sólidos | ✅ | — | `cosmic.atlas`, `recut_assets.py` | `6dae6b2` (merge `e0d683d`) | pipeline; cierra el gate `rentista_soles` de §6 y libera el worktree `v2-e8-pipeline`; no mueve plata; hueco 0,0025 %, alfa de los soles 0,956–0,996, manifest sin cambios |
| E8-T2 | El alta del batch (`prompts.json`) y las reglas de export | ✅ | — | `prompts.json`, `process_dropbox.py` | `6d2f8c3` (merge `a4c77ee`) | pipeline; crea `traer_tanda.py`; revisión sonnet; pipeline 49 → 63; revisada por el controlador |
| E8-T3 | Familia Pijama (43) | ✅ | T2 | `fam_pijama.atlas` | `3004952` (merge `8dd7258`) | pipeline, no compila; ∥ T4, T5 y cualquiera; destraba (con T4, T5) el arte de E6b T9; 43/43; a T9: loza en cartonero, estanciero_estelar; islas en dueno_pyme, magnate_solar, dueno_marte; 15 MB por atlas |
| E8-T4 | Familia Gaucho (43) | ✅ | T2 | `fam_gaucho.atlas` | `a2e0458` (merge `d0b6f9e`) | ídem; 43/43; a T9: cartonero (loza + isla entre carrito y cuerpo); 15 MB por atlas |
| E8-T5 | Familia Disfraz de Dinosaurio (43) | ✅ | T2 | `fam_dinosaurio.atlas` | `61463e5` (merge `cb1b606`) | ídem; 43/43; a T9: loza en cartonero; god (nube) y ser_ascendido (halo) parecen dibujo; 15 MB por atlas |
| E8-T6 | Visitantes y especiales (52) | ✅ | T2 | `npcs.atlas`; 🔥 `assets_manifest.json` (`npcs`) | `d74f330` | `oraculo.sh tarea GameContentValidationTests GameArtComponentsTests`; la ven E4b T1–T5, T8 y E5b T1 (todas con respaldo); npcs.atlas 13 MB (recursos 152 MB); notas para T9: islas intencionales en sp_bug_simulacion_talk/_face, sp_influencer_talk, sp_contador_dios_talk, npc_conductor_action; caras `_face` cortadas por el encuadre del generador |
| E8-T7 | Paquete, Colchón, Ruleta, tienda y Álbum (31) | ✅ | T2 | `ui.atlas`; 🔥 `assets_manifest.json` (`ui`) | `5c33986` (integ-r19) | `oraculo.sh tarea GameArtComponentsTests GameContentValidationTests`; carries a E5b T1–T3, E6b T9, E4b T8, E7b-b T3; **hecha (r19):** +62 PNG en `ui.atlas` (+4,3 MB), 31 claves `ui`; `wheel_frame` y `ui_album_card_frame` con la ventana interior blanca opaca; `ui_shop_income_x2` y `x3` son la misma imagen |
| E8-T8 | Los fondos a 2048 (JPEG) | ✅ | T2 | `Backgrounds/`, `process_dropbox.py`; 🔥 `assets_manifest.json` (`backgrounds`) | `6029e73` | crea `BackgroundArtTests` (xcodegen); mide la memoria del vuelo; revisión sonnet; `Backgrounds/` 38 → 9 MB; PSNR q90 35–40 dB (bajo la vara de 40 del plan; a ojo sin bloques, q95 igual a la vista → q90); **memoria del vuelo SIN medir → carry a T10** |
| E8-T9 | 🔒 La revisión de recortes de la 2.0 | ⛔ | T1, T3–T7 | `recut_assets.py`, los atlas elegidos | | la página la arma el agente; elige el dueño; no frena a nadie |
| E8-T10 | Peso, memoria y cierre (controlador) | ⏳ | T1–T8 | `Docs/`, `tasks.md` | | `completo --limpio`; 🔒 sólo si el bundle crece > 60 MB (estimado ≈ +29 MB) |
| P-E8b | Plan de E8b: cinemáticas y retratos animados | ✅ | — | — | `f035a5d` | 12 tareas; `2026-10-08-v2-e8b-cinematicas.md`; 11 dudas con default; ⚠️ `loops/` hoy es blanco, no croma |
| E8b-T1 | `video_assets.py`: el retrato mide arriba y el key acepta magenta | ✅ | — | video_assets.py, test_video_assets.py | `25c6b35` | pipeline, no compila; los dos ajustes de `DUENO.md`; los 18 de croma miden sin error (`medir --clase retrato`) |
| E8b-T2 | `video_assets.py`: retratos sobre blanco por conectividad | ✅ | T1 | video_assets.py, test_video_assets.py | (merge en integ-r13) | pipeline; `whitebg_cutout` cuadro por cuadro a 512²; revisión sonnet; 29–51 s por loop escalando a 512 antes de recortar (no 270); mirar el cuello del lagarto en T3 |
| E8b-T3 | Los 18 retratos y las 3 cinemáticas, integrados y pesados | ✅ | T2 | Resources/Loops, Resources/Cinematics, loops_manifest.json, masters | `2a6cb5e` | pipeline (~25 min en background); hoja de contacto al controlador; estimado +8,5 MB de bundle, ≈ 41 MB de masters; +10 MB (loops 3,5 · cinemáticas 6,5, el doble de lo estimado); masters NO versionados; arresto = toma 2; 🔒 el dueño mira `sp_contador_dios` (el saco blanco quedó comido: regenerar con otro color o fondo) y `sp_bug_simulacion` (sale chico); hojas de contacto en `build/e8b-contacto/` del checkout principal |
| E8b-T4 | `LoopsManifest`, `CinematicID` y `LoopsManifestTests` | ⏭️ | T3 | — | | **reemplazada por E8d-T1** (plan E8d, spec de animaciones del dueño, relevo 14); la API de E4b T3 (carry: E4b T3 no los crea) |
| E8b-T5 | `VideoSlot` y `LoopingPortraitView` | ⏭️ | — | — | | **reemplazada por E8d-T2 + T3** (plan E8d, spec de animaciones del dueño, relevo 14); archivos nuevos; ∥ T1–T4, T7 |
| E8b-T6 | El especial que te cayó, animado | ⏭️ | T4, T5 | SpecialDropView | | **reemplazada por E8d-T5** (plan E8d, spec de animaciones del dueño, relevo 14); revisión ninguna; captura SE/16 Pro (duda 3) |
| E8b-T7 | `seenCinematics` en `meta.engagement` | ✅ | E1-T4 ✅ | EngagementState (EK) | `4714671` | sonnet, **rev. opus** (save); antes de E3b T9 o al final de su cadena; revisión opus (controlador): Approved. Carry a E9b T7/T8: `seenCinematics` es de la cuenta y `resolveAcrossReset` hoy no lo cruza (duda 8: el reset lo conserva) |
| E8b-T8 | El turno de la cinemática (`.cinematic`, payload, autorun) | ✅ | E8d-T1, T7 | 🔥 GameState (dos propiedades); CelebrationQueue, +Celebrations, +Debug, +Bootstrap | | **cambia (E8d)**: importa `CinematicID`/`LoopsManifest` de E8d T1 y suma `.intro`; sonnet, **rev. opus**; ventana libre de GameState.swift; antes de E9a T1; **destrabada (r20):** E8d T1 y T7 ✅ |
| E8b-T9 | La cinemática en pantalla (overlay, sonido, Saltar) | ✅ | E8d-T2, T8 | 🔥 RootView, catálogo (snapshot, 4 claves); AudioManager, DebugPanelView | | **cambia (E8d)**: lease `fullscreen` del `VideoPlayerPool`; `.suspendsVideoPool()` en el overlay del cofre; sonnet; `CinematicUITests` por Receta R; capturas SE + iPad; **destrabada (r20):** E8d T2 y T8 ✅; dueña de `RootView` (no ∥ E3b T8, E12 T13) |
| E8b-T10 | Reencarnación y Dios | ✅ | T8, T9 | +Prestige, +BoardChanges, +Bootstrap | | sonnet, **rev. opus**; pinea el momento calmo que espera E12 T14; carry `godTier` a E12 T11 |
| E8b-T11 | El arresto | ⛔ | T10; E4b-T2 | +Visitors | | sonnet; al dejarlo ir (duda 5) |
| E8b-T12 | Cierre de E8b (controlador) | ⏭️ | T1–T11 | `Docs/` | | **reemplazada por E8d-T15** (plan E8d, spec de animaciones del dueño, relevo 14); `completo`; en un iPhone real (HEVC-alfa por hardware) y la memoria a E8 T10 |
| P-E8c | Plan de E8c: la cadena animada de Fusionar todo | ✅ | — | — | (el commit de este plan) | 10 tareas (T1–T10); `2026-10-08-v2-e8c-fusionar-todo.md`; 11 dudas con default; **un solo 🔥 (BoardScene, T7/T8); no toca GameState ni RootView** |
| E8c-T1 | El eslabón en el plan (`BoardChange.Chain`) | ✅ | E2a-T6 ✅ | BoardChange.swift (tibio: E13 T2, E6a T6, E7b-b T1), MergeAllPlannerTests | `cbb97f3` (integ-r18) | EK; sonnet, **rev. opus** (la igualdad que compara `confirmBoardChange`); ola 1 |
| E8c-T2 | El reloj del turno se renueva (`CelebrationQueue.renew`) | ✅ | — | CelebrationQueue.swift (tibio: E4b T1, E8b T8, E6a T12) | `6550e6b` (integ-r18) | EK; sonnet; ola 1 |
| E8c-T3 | El tempo de la cadena, puro (`MergeAllTempo`) | ✅ | — | nuevos (`Scenes/MergeAllTempo.swift`) | | revisión ninguna; 7 pares ≤ 3,5 s; ola 1 |
| E8c-T4 | El plin que sube de tono y el remate | ✅ | — | AudioManager (tibio: E13b T3, E5b), HapticsManager, +Services, generate_audio.py, 1 `.caf` | `db94359` (integ-r18) | revisión ninguna; las fusiones del embudo hoy no suenan |
| E8c-T5 | El turno de la cadena en GameState | ✅ | T1, T2 | +BoardChanges, +Celebrations, +Debug (tibios) | `ae952bf`+`de11f12` (integ-r18) | sonnet, **rev. opus** (turno, watchdog, HUD); crea `debugSeedMergeAll` |
| E8c-T6 | El contador "×N" | ✅ | — | nuevos (`Scenes/Nodes/MergeAllComboNode.swift`); catálogo (snapshot, 1 clave) | `0c15d3d` (integ-r18; catálogo +1) | revisión ninguna; `claves-pendientes/e8c-t6.json` |
| E8c-T7 | La escena encadena sin soltar el turno | ✅ | T3, T4, T5; ventana de BoardScene (tras E13 T11) | 🔥 BoardScene | `e79696f`+`520d54c` (integ-r19) | sonnet, **rev. opus**; `endBoardChangeTurn` es el borde único; grabación; **hecha (r19, opus: Approved con arreglos hechos):** tempo por `MergeAllTempo` con `next.chain`; `playBoardMergeFeedback` reemplaza el háptico `.merge`; aborto en `update` si la cadena pierde el turno; guard `playingChain == nil` en `touchesBegan`; sin captura ni grabación (SE + Reduce Motion) |
| E8c-T8 | El toque apura; contador, remate y VoiceOver | ✅ | T6, T7 | 🔥 BoardScene | `b6cc8f0`+`a59037f` (integ-r19) | sonnet, **rev. opus**; duda 1 (apura, no corta); SE + Reduce Motion; **hecha (r19, opus: Approved):** `tapDuringCelebration` primer paso de `touchesBegan`; con cadena viva el toque se consume siempre y sólo apura pasado el piso de 0,6 s por eslabón; `MergeAllComboNode` en `cameraOverlay` a `size.height * 0.8` (posición provisoria); remate y VoiceOver con `chain.index + 1 >= 2` |
| E8c-T9 | El fixture `--uitest-merge-all` y `MergeAllChainUITests` | ✅ | T8 | +Bootstrap (tibio) | `fd9623d`+`ea019c1` (integ-r20) | sonnet; receta R en un 16 Pro; **hecha (r20):** cadena 19,9 s / 28,5 s con toques en un 16 Pro; techo del UI test 20 → 30 s (controlador) |
| E8c-T10 | Cierre de E8c (controlador) | ✅ | T1–T9 | `Docs/` | | `completo`; grabaciones para el dueño (sin tocar, tocando, por ORO/video si ya existen); destrabada (r20): T9 ✅ |

### E8d — Todo el juego animado, lado Swift (`2026-10-08-v2-e8d-animaciones-swift.md`)

Plan del relevo 14 sobre la spec del dueño `2026-10-08-v2-e8-animaciones-design.md`. Reemplaza E8b T4/T5/T6/T12; E8b T8/T9
cambian; E13b T6 sigue igual (E8d T10 va después de E13b T6 y T8). Olas: T1 ∥ T2 ∥ T6 → T3 ∥ T4 → T5, T12, T13 → T7, T8 → T9;
T14 espera el 🔒 de la segunda tanda. Gates G1–G7 en el plan (G6 revisión de la segunda tanda y G7 oír los sonidos: 🔒 dueño).
Encargos a E4b T3/T4/T8, E5b T2/T3, E6a T8, E9a/E9b, E7b-a T2: plan, "Lo que E8d le deja a otras épicas".

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8d | Plan de E8d: todo el juego animado, lado Swift | ✅ | — | — | `fdb1d39` | 15 tareas; reemplaza E8b T4/T5/T6/T12; E8b T8/T9 cambian; E13b T6 igual; 15 dudas con default; 7 gates |
| E8d-T1 | El manifest entero, `ArtClip` y `CinematicID` (+intro) | ✅ | — | nuevos | `29a8d5f` (integ-r14) | sonnet, revisión ninguna; reemplaza E8b T4 con su API; ola 1 |
| E8d-T2 | `VideoPlayerPool` y `VideoPlaybackPolicy` (≤ 3 vivos, roles, suspensiones, reservas) | ✅ | — | nuevos | `e097c1e`+`0866227` (en `v2i/integ-r15`) | sonnet, **rev. opus**; reemplaza `VideoSlot` (E8b T5); ola 1; revisión opus: Approved con arreglos (forcedStill apaga la cinemática; `policy` legible; `recompute` reentrante con `notified`; `suspendsVideoPool(active:reason:)`; `launch(arguments:environment:xctestLoaded:)` puro), hechos; tarea VERDE unit 19. Carries: T3/T4 guardan el `Lease`, crean el player sólo con `isLive`; T10 usa `suspend(.elevatorRide)` y `reserve()`; la cinemática ignora suspensiones (si el viaje debe apagarla, cambiar `liveIDs`) |
| E8d-T3 | `AnimatedArtView`: póster instantáneo, video con fundido, loop o una vez | ✅ | T1, T2 | nuevos | `cd38b39`+`e31b466` (en `v2i/integ-r15`) | sonnet, **rev. opus** (AVFoundation); reemplaza `LoopingPortraitView` (E8b T5); ∥ T4; revisión opus: Approved con arreglos, hechos (video como overlay del póster; `.id(url|rol)`; un `.once` no revive y desmontar no llama `onEnd`; vigía de 1 s del `.once`; `.loop` siempre pide lease; al agotar el sondeo suelta todo; `art.video` live/still); el publisher de `isReadyForDisplay` no disparó en el simulador → sigue el sondeo 50 ms × 40; tarea VERDE unit 9. Carries: T12 la capa no re-resuelve la URL (lo cubre `.id`); el test de `queue.play()` es débil |
| E8d-T4 | `LoopingVideoNode` (SpriteKit) y la medición del alfa en `SKVideoNode` | ✅ | T1, T2 | nuevos | `44d3901`+`5bdcc97` (en `v2i/integ-r16`) | sonnet, **rev. opus**: Approved con arreglos, hechos (control del alfa: centro del retrato no rojo + gemelo opaco `cine_arresto`; `deinit` suelta el lease vía `Task @MainActor`; `gaveUp` hasta `stop()`; test del abandono; `NotVisibleError`); tarea VERDE unit 32. **Ruta A para T9** (en simulador; la vara es G3 en device). Carries a T8/T9: `setVisible(false)` al sacar el nodo o pausar la escena; nunca póster vacío (se dibuja blanco) |
| E8d-T5 | El especial que te cayó y la ficha, animados | ✅ | T3 | SpecialDropView, CharacterSheetView (tibio: E13 T9) | | sonnet, revisión ninguna; capturas SE/16 Pro con `--uitest-video`; reemplaza E8b T6 |
| E8d-T6 | Sonidos nuevos A (paquete, colchón, visitante, tienda, revelación, cable) | ✅ | — | AudioManager (tibio: E8c T4 → E8d T6 → T7 → E8b T9), generate_audio.py, AudioWiringTests | `7c31fc8` (merge `0079647` en `v2i/integ-r15`) | sonnet; 11 `.caf`; `pendingWiring` con dueño; 🔒 oído del dueño (no frena); ola 1; 11 `.caf` a −18/−24 dB RMS; `Gain` acción/ambiente, `startAmbient`, `talkPitch`; `pendingWiring` con dueños (E5b T2/T3, E4b T3, E6a T8, E8d T5/T9/T10); `elevatorCases` los cablea E13b T6; el motor sigue a −8,5 (bajarlo con `.ambient` o `SFX_RMS_DB`) |
| E8d-T7 | Los 8 acentos de evento | ✅ | T6; ventana de +Bonus (o E4a T9) | 🔥 +Bonus (una línea); AudioManager, generate_audio.py | `b451e4d` (integ-r19) | sonnet, revisión ninguna; **hecha (r19):** 8 `sfx_ev_*.caf` a −20 dB RMS **sin escuchar (G7)**; `AudioManager.accent(forEvent:)` con default `.event`; `AudioWiringTests.eventAccents` |
| E8d-T8 | El fondo del piso visible, animado | ✅ | T4; ventana de BoardScene | 🔥 BoardScene; FloorNode | `2260105`+`0b0ecd0` (integ-r20) | sonnet, **rev. opus**; inerte hasta T14; scroll y viaje = póster; **hecha (r20):** los 10 `bgloop_*` sin `odrTag` → **activo en producción**; revisión opus con arreglos (`willMove`, test del cableado real) |
| E8d-T9 | La revelación con el cuerpo entero | ✅ | T8 | 🔥 BoardScene | `1970662`+`9acbf04` (integ-r20) | sonnet, **rev. opus**; ruta A (`SKVideoNode`) o B (overlay) según T4; **hecha (r20):** ruta A, `LoopingVideoNode .popup`; revisión opus con arreglos (fundido del contenedor, whoosh siempre, prefetch ODR del próximo tier); sin test ODR con `ArtPackSource` falso |
| E8d-T10 | El viaje suspende los videos; la cabina reserva su decodificador; `sfx_elevator_cable` | ✅ | T2, T6; E13b T6, T8 | ElevatorCabin.swift, ElevatorRideOverlay | | sonnet, **rev. opus**; no frena a E13b T6; **destrabada (r20):** E13b T6 y T8 ✅; sin dueño de `BoardScene` en vuelo |
| E8d-T11 | La intro, la primera vez | ✅ | E8b T10 | +Cinematics, +Bootstrap (tibio); catálogo (snapshot, 1 clave) | | sonnet, rev. sonnet; inerte sin `cinematics.intro` |
| E8d-T12 | On-Demand Resources: `ArtPacks` y el pedido por familia | ✅ | T1, T3, T4 | nuevos + LoopsManifest, AnimatedArtView, LoopingVideoNode | `33d33df`+`37afdd6` (en `v2i/integ-r16`) | sonnet, rev. sonnet: Approved con arreglos, hechos (el nodo pide siempre que haya `odrTag` y re-resuelve en `stop()`; token en `whenAvailable`; `raisePriority` sobre un prefetch; 6 tests más); tarea VERDE unit 36. Carries a T14: ninguna entrada tiene `odrTag` todavía — T14 asigna los tags en el manifest y en `project.yml` (`ENABLE_ON_DEMAND_RESOURCES`, `resourceTags`); ODR real nunca ejercitado (verificar en device). `prefetch` listo pero sin llamadores (T8, E6a T8): cada uno con su `release` |
| E8d-T13 | La sonda de fps y memoria (DEBUG) y `--uitest-anim-stress` | ✅ | T3, T4 | DebugPanelView, +Bootstrap, +Debug (tibios) | | sonnet, revisión ninguna; habilita G1/G2/G4 antes de la segunda tanda |
| E8d-T14 | La segunda tanda entra (sólo lo `va`) | ✅ | T12 (🔒 de la revisión cerrado: 135 `va`; los 108 ya están en `Resources` desde `integ-r16`, falta el tag ODR) | 🔥 project.yml; Resources, loops_manifest.json | | cero Swift; ODR por tag; base ≤ +60 MB |
| E8d-T15 | Cierre de E8d: gates en dispositivo y barrido de lugares (controlador) | ⛔ | T1–T14; E8b T8–T11 | `Docs/` | | `completo`; G1–G5 con números; `AnimatedPlacesTests` |

### E9 — Tutorial v2 + Tour de novedades + Ajustes (`2026-10-07-v2-e9a-…` motor, `…-e9b-…` currículo y reset)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E9 | Plan de E9 | ✅ | — | — | `df2d688` | 20 tareas; reporte `.superpowers/sdd/2026-10-07-v2-e9/plan-report.md` (17 contradicciones) |
| E9a-T1 | Relojes (candado 5 s, watchdog 180 s, ritmo 20 s/1 s) y migración, puros en EK; `isSkippable` explícito | ⛔ | E6a-T12 (último en `CelebrationQueue`) | CelebrationQueue (EK) | | sonnet |
| E9a-T2 | El modelo (`TutorialStep`, `TutorialSignal`, `TutorialProbe`, `TutorialRun`) y `TutorialFlags` | ⛔ | T1 | — | | sonnet |
| E9a-T3 | Las banderas cableadas: `tutorial.v2.*` en todos los lectores, migración en el arranque | ⛔ | T2; E3a-T9, E11-T6 | 🔥 GameState, RootView; +Debug, +Tabs, +Notifications, TutorialOverlay, CelebrationWiringTests | | sonnet (rev. opus) |
| E9a-T4 | El director: guiones de pasos, ritmo, watchdog; las 18 lecciones a un paso | ⛔ | T3; E7b-b-T5 (último en +TutorialTips) | 🔥 GameState; +TutorialTips, +Celebrations, +Menu, +Debug, TutorialTipView | | opus |
| E9a-T5 | El núcleo en el director, sin "Saltar", cierre con candado (`finishTutorialCore`) | ⛔ | T4 | TutorialOverlay, +Celebrations, +Notifications, +Debug, catálogo | | opus |
| E9a-T6 | Las lecciones en el renderer único; `.tutorialTip` sin timeout ni salto; `TutorialTipView` se borra | ⛔ | T5 | 🔥 RootView, catálogo; CelebrationQueue (EK), TutorialOverlay | | opus |
| E9a-T7 | `TutorialSheetCoach`, `HoldHand`, `SwipeHand`; el núcleo contrata adentro de FisuJobs | ⛔ | T6 | MenuPagerView, CharacterSheetView, QuickHirePicker, FisuJobsView, TutorialAnchor | | sonnet |
| E9a-T8 | `TutorialInlineCard`: offline, carrera, primer visitante | ⛔ | T6 | OfflineEarningsView, CareerChoiceView, popup del visitante, catálogo (snapshot) | | sonnet |
| E9a-T9 | `TutorialMechanic` + `TutorialCoverageTests` + `TutorialCurriculumTests` (20 huecos declarados) | ⛔ | T7, T8 | TutorialCurriculum, tests | | sonnet |
| E9a-T10 | Cierre de E9a (controlador) | ⛔ | T1–T9 | `Docs/` | | controlador |
| E9b-T1 | Lecciones del tablero y la torre (atajo con pin en 5 pasos, pasivo, botonera, ficha, piso móvil…) | ⛔ | E9a-T9; E3a-T8, E3b-T8, E2a-T8, E2a-T13 | catálogo (dueña); +TutorialTips, varias vistas | | sonnet |
| E9b-T2 | Lecciones de economía, ORO, tienda y menú (18) | ⛔ | T1; E2a-T10, E3a-T9, E6a-T8, E6a-T12, E6b-T7 | catálogo; +TutorialTips, varias vistas | | sonnet |
| E9b-T3 | Las 9 heredadas al formato, orden fijado, cero huecos | ⛔ | T2 | catálogo (snapshot); +TutorialTips | | sonnet |
| E9b-T4 | El Tour de novedades (veteranos) | ⛔ | E9a-T6; T3 | +Tutorial, +Debug, catálogo | | sonnet |
| E9b-T5 | "Ver tutorial de nuevo" / "Ver novedades" en Ajustes | ⛔ | T4; E11-T4, E7b-a-T5 | 🔥 SettingsView, catálogo | | sonnet |
| E9b-T6 | `resetEpoch` en `MetaState` + regla en el resolver | ✅ | E1-T6c | 🔥 PlayerState (MetaState); SaveConflictResolver | `8e50efa`+`cccde55` (merge `8d1eeeb`) | revisión opus: Approved con arreglos (el ORO no visto se acredita en las dos ramas del resolver). Carries a T7/T8: el reset sube la época y lleva oroPurchases/revoked/credited/removedAds/ownedSkins con `oro = min(saldo, comprado)`; `OffersState.purchases` (E6a T1) debe cruzar en `resolveAcrossReset`; un build viejo que reescribe el save pierde la época |
| E9b-T7 | `ResetPlan` puro (matriz del ORO) | ✅ | T6; E1-T6c, E6a-T1 | — | | sonnet |
| E9b-T8 | El reset en la app (backup, entitlements re-empujados, `clearSessionRuntime`) | ⛔ | T7; E9a-T3; E6a-T11 | +Reset (nuevo), +Debug, +Store, StoreManager, SaveBackupStore, PlayerStateRepository (GameState.swift sólo si `newGame` sigue private) | | sonnet (rev. opus) |
| E9b-T9 | Zona de peligro + `ResetGameFlowView` (3 pasos, nada deshabilitado) | ⛔ | T8, T5; E3b-T2 | 🔥 SettingsView, catálogo | | sonnet |
| E9b-T10 | Cierre de E9 (controlador) | ⛔ | E9a, T1–T9 | `Docs/` | | controlador |

E9b T6–T8 (el reset) pueden ir al lado de E9a T4–T9. Dudas top: una lección bloquea el tablero (scrim 0,55; revierte la regla v1); lo comprado con ORO no sobrevive al reset; el Tour pedido desde Ajustes no se corta. UMP lo hace E7b-a T5, no E9.

### E2b — Calibración final y contrato de pacing (`2026-10-07-v2-e2b-calibracion.md`)

> Relevo 12: E13 agrega dependencias a T5, T6, T10, T12 y T14 (ver §5 E13).

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E2b | Plan de E2b | ✅ | — | — | `5b15b82` | 15 tareas; reporte `.superpowers/sdd/2026-10-07-v2-e2b/plan-report.md` |
| E2b-T1 | Bandas de escalada y curva por piso (EK) | ✅ | E2a-T3, E2a-T5 | — | `42b2e8c` (integ-r20) | **hecha (r20):** `EscalationBand` + `escalation(atFrontier:)` única fórmula (`hireCost`, `PriceCushion.jump`), `costGrowthStepPerFloor`; apagadas (umbral 7 = v1) |
| E2b-T2 | Herencia de pasivos al reencarnar (EK) | ✅ | T1 | — | | |
| E2b-T3 | El simulador cobra como el juego (EK) | ✅ | T2; E2a-T3, E2a-T4, E2a-T5 | — | | |
| E2b-T4 | Política de pisos en marcha del bot (EK, opus) | 🟢 | T3; E2a-T4 | — | | |
| E2b-T5 | Perfiles y fuentes gratis (EK) | ⛔ | T4; E5a-T1 | archivo de `PackageRoller` | | |
| E2b-T6 | El perfil `.ads` (EK) | ⛔ | T5; E4a-T1, E4a-T8, E5a-T2, E5a-T3 | — | | |
| E2b-T7 | El perfil `.max` (EK) | ⛔ | T6; E6a-T2, E6b-T6 | — | | |
| E2b-T8 | El CLI del pacing-sim | ⛔ | T7 | — | | |
| E2b-T9 | La suite del contrato (apagada) | ⛔ | T8; E5a-T5, E6a-T4, E7b-a-T3, E7b-b-T2, E2a-T11, E2a-T12 | — | | |
| E2b-T10 | Presupuestos analíticos | ⛔ | E2a-T11, E4a-T7, E4a-T9, E6a-T4 | `visitors.json` | | |
| E2b-T11 | La herencia en pantalla | 🔄 | T2; E2a-T8 | catálogo (snapshot) | | |
| E2b-T12 | Medir cada mecánica, en orden | ⛔ | T9; 🔒 playtest E2a-T14 | — | | |
| E2b-T13 | La búsqueda (run AVO, opus) | ⛔ | T12; E4a-T10, E5a-T9, E6a-T13, E6b-T7, E7b-b-T8 | — | | |
| E2b-T14 | Declarar la calibración y prender el contrato | ⛔ | T13 | `economy.json`, `upgrades.json`, `achievements.json`, tests de pacing | | |
| E2b-T15 | Cierre de E2b (controlador) | ⛔ | T1–T14 | `Docs/` | | |

Fase A (T1–T4) tras E2a T15, EK puro ∥ E4–E7; fase B en paralelo con E9 y antes de su cierre (decide el punto 4 de "Inconsistencias"). Reemplaza el rojo declarado `theOwnersTargetsAreMet` (T14). Dudas top del plan: contrato 6 (≥ 65 %) choca con HANDOFF §5.2 (se mide en T3/T12; si no llega, al dueño); `.free` incluye paquete y diario base; los visitantes rompen el 12 % de E2a (T10 baja `coinsSecondsScale`); logros 33 → 66 ORO con las líneas a 348.

### E12 — Ranking de la llegada a Dios (spec `2026-10-08-v2-e12-ranking-design.md`; plan `2026-10-08-v2-e12-ranking.md`)

Épica nueva del dueño (2026-10-08, llegó por la sesión "Fisu Evolution v2 roadmap", commit de docs
`7671880` → `92dbc45`). Depende de E9b T8 (reset), E3 (menú deslizable) y E1 (save v6); termina
antes de E2b (fija el piso `minRealSecondsToGod`) y E10 (App Privacy, Términos, notas a App Review).
`NameRules`, el backend y el cliente van en paralelo con el resto.

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E12 | Plan de E12 por tareas | ✅ | — | — | `0a1bf1e` | 19 tareas (T1–T18, la T9 partida en 9a/9b); ya: T1, T2, T6 (y T3 tras T1); 11 dudas con default |
| E12-T1 | `NameRules` (EK) + la tabla compartida | ✅ | — | — | `82dcab9` (merge `3e7772c`) | sonnet; EK puro + `supabase/tests/fixtures/`; tabla de 31 casos compartida con el servidor; EK 553 → 556; tarea VERDE; destraba T3 y T9a |
| E12-T2 | Backend: esquema, RLS, funciones SQL, `supabase/test.sh` | ✅ | — | — | `b498fa2` (merge `b8a6c2e`; arreglo del oráculo `9c26baa`) | opus; Postgres local, sin compilar la app; `supabase/test.sh` VERDE 23 casos SQL; vista partida en `leaderboard` pública + `leaderboard_internal`; carries a T3: fijar `npm:@anthropic-ai/sdk`, `deno.lock`, deno no instalado (Docker sin probar) |
| E12-T3 | Backend: reglas, lista y moderación (Deno) | ✅ | T1 | — | `f61195b` (merge en integ-r13) | sonnet; Haiku inyectable, sin red en tests; DONE_WITH_CONCERNS: `haikuClassifier` sin probar contra la API real (prueba manual con la clave: dueño o T16); SDK fijado en 0.131.0 (la política de 24 h de Deno bloqueó 0.132.x); deno 2.9.7 por brew; `supabase/test.sh` VERDE (sql 23 · deno 52) |
| E12-T4 | Backend: las cuatro Edge Functions | ✅ | T2, T3 | — | `3ab325d`+`30cf56a` | sonnet, rev. opus; integración contra Postgres temporal; revisión opus: Approved con arreglos (start-run idempotente por `clientRunId`; Haiku después del chequeo de dueño; sólo reporta quien selló una partida; lint en test.sh). Carries: **T7/T8** el cliente genera `clientRunId` una vez por partida nueva o reset, lo guarda (en `RankingState.awaitingStart`: el EK de T6 no lo tiene todavía) y lo reusa en cada reintento; forma de `mine` en el contrato del plan; **T5** limpiar `api_calls`/`players` viejos en el cron y evaluar límite por IP; **T16** `prepare:false` verificado contra el pooler |
| E12-T5 | Backend: cron, propuesta de lista, deploy y panel | ✅ | T4 | — | `27e9986`+`e9a2027` | sonnet; la lista es propuesta (🔒 3); propuesta de 137 términos en `supabase/blocklist/propuesta.txt` SIN activar (🔒 3; ojo: el matcher es por subcadena, `puta`/`cum` quedaron afuera por falsos positivos: decide el dueño); limpieza de players sin partida sellada a 90 días; límite por IP propuesto para T16 (decidir qué `x-forwarded-for` es confiable); T16 prueba pg_cron, pg_net, el Vault y `vault.create_secret` |
| E12-T6 | `RankingState` (EK) | ✅ | — | — | `97c15fa`+`ab3492a` | revisión opus: Approved con arreglos (la fase más avanzada sólo con el mismo runId; max de playedSeconds sólo en la misma partida; `CarriedSubmission.sealed`). Carries: T8/T12 reenvío de la llegada arrastrada idempotente (409/not_active = hecho) y `sessionBegan` tras `forNewGame()`; T10 `ranking` con `(try? …) ?? .legacy` (Phase sintetizado) y default `.newGame`; T8/T11 mandar el start sólo tras `newGameStarted`, no al abrir la app |
| E12-T7 | Cliente, identidad en el Keychain y config remota | ✅ | T6 | — | `a4691a5`+`e20870a` (integ-r14) | sonnet; compila (archivos nuevos + xcodegen); revisión: el controlador leyó el cambio de EK (`RankingState.clientRunId` + `startAttemptId`, se suelta al registrar). Carries a T8: llamar `startAttemptId` y persistir antes del start-run; `ranking.json` con `baseURL`/`anonKey` null hasta T16 (el cliente real tira `.disabled`; el loader remoto rechaza otra clave); escenarios `--uitest-ranking-*` |
| E12-T8 | `RankingStore` | ✅ | T6, T7 | — | `40e6eaf`+`b5c8a55` (en `v2i/integ-r15`) | sonnet, rev. opus; revisión opus: Approved con arreglos, hechos (`CarriedSubmission.playedSeconds` en EK; reintento sin nombre ante invalidName; `nameError` aparte de `entryPrompt`; `offerCardIfDue()` en reachedGod y becameActive; guards de respuesta vieja; cliente suspendible en tests); tarea VERDE EK 607 · unit 29. Carries: T10 GameState conforma `RankingStateHost`; T9/T11 leen board/myRuns/entryPrompt/nameError/isSubmitting/isEnabled; `godTier` sin uso todavía |
| E12-T9a | La tarjeta de Dios (vista suelta) | ✅ | T1, T8 | catálogo (snapshot) | `5d71b9a` (en `v2i/integ-r16`; catálogo 17 claves) | sonnet, revisión ninguna (UI suelta; diff leído); tarea VERDE con T9b. Carry a T14: `RankingEntryCard(prompt:nameError:isSubmitting:onSubmit:onLater:)` es modal con su velo; montarla con `store.entryPrompt != nil` |
| E12-T9b | La pestaña (vista suelta) | ✅ | T8 | catálogo (snapshot) | `6b0f505` (en `v2i/integ-r16`; catálogo 28 claves) | sonnet, revisión ninguna (UI suelta); tarea VERDE EK 618 · unit 24 (RankingCopy, RankingBoardModel, LocalizationCompleteness). Tocó `GameConfirmCard` (ids de aceptar/cancelar con default). Carries a T13: `RankingView(store:state:now:onStore:)` recibe el `RankingState` (pasarlo desde `gameState.rankingState`); `pager?.lock` al empujar Mis partidas; `onStore` → `MenuPagerContext.go`; con `isEnabled == false` muestra `ranking.disabled` (T13 decide si la pestaña existe); el botón Entrar usa `.disabled` (rompe la convención de `ActionPill`: decide el dueño) |
| E12-T10 | `MetaState.ranking` + resolver | ✅ | T6; E1-T16 | 🔥 PlayerState; SaveConflictResolver, SaveMigratorTests | `9ca856f`+`fe707d6` (en `v2i/integ-r16`) | sonnet, **rev. opus**: Approved con arreglos, hechos (test que muerde `scheduleSave`; `try?` por campo en `RankingState`; precedencia de la llegada sin enviar en el reset); tarea VERDE EK 618 · unit 64 + `swift test` 82. Sin clave → `.legacy` (v1–v5 no compiten); default `.newGame` sólo en `MetaState.fresh`; reset: gana el nuevo, cruzan `lastName` y la llegada sin enviar. **Para el dueño:** el `installId` no viaja por CloudKit → partida registrada en A que llega a Dios en B queda `.unregisteredGod` (sincronizar el Keychain o aceptarlo); un build pre-T10 que re-guarda deja el ranking en `.legacy` (sólo TestFlight). Carries a T11/T9: `godTier` `nil`, config remota `null` hasta T16 |
| E12-T11 | Los ganchos en `GameState` | ✅ | T8, T10 | 🔥 GameState (una línea); +Celebrations, +Lifecycle, +BoardChanges, +Bootstrap, +Debug, FisuEvolutionApp | | sonnet, **rev. opus**; ventana libre de `GameState.swift` |
| E12-T12 | El reset abre un intento nuevo | ⛔ | T11; E9b-T7, E9b-T8 | ResetPlan, +Reset | | sonnet, rev. opus |
| E12-T13 | La 7.ª pestaña montada | ✅ | T9b, T11; E3b-T4, E3a-T11 | 🔥 RootView, catálogo; GameArtComponents, BottomMenuBar, MenuPagerView, TabUnlocks, tabs.json, +Tabs | | sonnet; captura SE (plan B: tarjeta en la Oficina); **destrabada (r20):** E3b T4 🟢 y E3a T11 ✅; dueña de `RootView` (no ∥ E3b T8, E7b-a T2) |
| E12-T14 | La tarjeta de Dios montada | ✅ | T9a, T11, T13 | 🔥 RootView, catálogo | | sonnet; de a una con T13 |
| E12-T15 | Privacidad, Términos y notas a App Review | ✅ | T11 | PrivacyInfo.xcprivacy, Legal | `700c02a`+`a223c0b` (en `v2i/integ-r22`) | sonnet; insumo de E10 ; **carry a E10 y al dueño:** `NSPrivacyTracking` sigue en `false` (de antes) aunque AdMob/ATT; la nota no da atajo al revisor para ver el ranking; la privacidad no nombra al proveedor de la IA que modera |
| E12-T16 | Despliegue real y humo | 🔒 | T5, T14 | — | | Supabase (URL + anon), `ANTHROPIC_API_KEY`, lista aprobada |
| E12-T17 | El piso calibrado | ⛔ | T16; E2b-T14 | — | | controlador; no frena el cierre |
| E12-T18 | Cierre de E12 (controlador) | ⛔ | T1–T16 | `Docs/` | | |

### E13 — Ajustes del feedback de la v1 (PLAN-v2 E13; plan `2026-10-08-v2-e13-feedback-v1.md`)

Épica nueva del dueño (2026-10-08, docs `63a55a0` → cherry-pick en el relevo 12). 12 ítems. **El 1 va
primero y solo** (bug que el dueño ve en cada video); 2, 3, 6 y 7 tocan la economía y van **antes de
E2b**; 4, 5 y 8–12 son UI chica en paralelo respetando §3.1.

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E13-T1 | El botón de video responde al primer toque (ítem 1) | ✅ | — | `AdMobAdsProvider`, `GiftsView`, `OfflineEarningsView`, `ChestOpeningView`, `EventBannerView`; adelanta el contrato de `RewardedOfferButton` (E4b T3 / E7b-b T7) | `24ab6f0` + `e4b514f` + `a1a4997` (merge `acee4d8`) | **primera de la cola**; despacho directo desde PLAN-v2 E13 ítem 1 (no espera al plan); revisión opus (mueve el enfriamiento de los videos): Approved con arreglos (salidas activas durante la espera, `AdLoadWait` cancelable, flag `lastRewardedPresented` compartido), arreglados en `a1a4997`; `RewardedOfferButton` y los 4 lugares migrados; **integrada en `v2i/integ-r12`, `rapido` pendiente** (el `completo` corre en `version-2`) |
| P-E13 | Plan de E13 por tareas (ítems 2–12) | ✅ | — | — | `a9433f2` | 13 tareas (T2–T14); `2026-10-08-v2-e13-feedback-v1.md`; 14 dudas con default |
| E13-T2 | Premios por video: regalo de frontera − 3, Fusionar todo en lugar de la Evolución gratis | ✅ | T1, T6 | 🔥 +Bonus, catálogo (snapshot); AdsProvider, rewarded_ads.json, BoardChange.swift, +BoardChanges, EffectContractTests | | revisión opus (plata); crea `Origin.rewardedMergeAll` y `giftType` (carries a E7b-b T1/T2, E4a T4, E2b T6); **destrabada:** T1 y T6 ✅ |
| E13-T3 | Cofres de piso, una vez por cuenta | ✅ | E9b-T6 | 🔥 PlayerState; SaveConflictResolver, +Chests | `7b8035e` (integ-r19) | revisión opus (save); migra en el decodificador; carries a E2b T5 y E9b T7; todo campo de cuenta nuevo que sobreviva al reset se suma a `resolveAcrossReset` con test en `ResetEpochTests`; **hecha (r19, opus: Approved):** `floorChestsAwarded` pasa de `RunState` a `MetaState`; `PlayerState.init(from:)` migra max(meta, run viejo) y el encoder no re-escribe la clave vieja; NO entra a `resolveAcrossReset` (gana la época nueva, test en `ResetEpochTests`); carry a E2b T5 y E9b T7: el reset de cuenta deja el contador en 0 |
| E13-T4 | El punto de Regalos avisa los boosts listos | ✅ | ventana de GameState.swift | 🔥 GameState (una propiedad); +Projections, BottomMenuBar | `d121c97` (integ-r19) | no ∥ dueños de GameState (E3b T5 en la ola I); **hecha (r19):** `GameState.hasReadyBoost`; `.gifts` = cofres ∨ boost; el punto se prende desde la primera partida |
| E13-T5 | Los precios al reencarnar, explicados | ✅ | — | catálogo (snapshot); PrestigeView | | revisión ninguna; carry de texto a E9b T1; antes de E2b T11 (PrestigeView) |
| E13-T6 | La Startup evoluciona dos tiers abajo de la frontera o paga | ✅ | — | 🔥 +Bonus, catálogo (snapshot); events.json, ContentConfigs, BoardChange.swift, catalogo.py | `bc878cc` | revisión opus (plata); PRIMERA de E13 (camino a E2b); suma `catalogo.py quitar` (E4a T9 lo saltea); carries a E4a T4/T7/T9, E2b T10; revisión opus: Approved (tope frontera−2 sin off-by-one; pago una vez, sincrónico). Carries: E4a T4/T9 pagar el `fallback` si la evolución encolada se descarta en `revalidate`; `.evolveBestUnit` con `tiersBelowFrontier: 2` y el fallback; T7 el banner muestra la clave `.cash`; T9 muda `startupEvolution`/`payStartupFallback` a `+Events` y pasa `maxSourceTier`; `GameState+Debug` arma `EventsConfig.Event` a mano; E2b T10 mide la Startup con S(300); el test `result.tier <= 4` no pinea bien el tope (armar tablero con tier 4) |
| E13-T7 | Toque premiado: seis líneas, los niveles se suman | ✅ | T3, T6; E9b-T6 | 🔥 PlayerState, ContentSystems, catálogo (snapshot); upgrades.json, ContentConfigs, PermanentUpgrades, EffectDescriptor, pacing-sim, GameContentValidationTests, PacingTests | `421817b`+`592ef99` (en `v2i/integ-r21b`) | revisión opus (save + plata): Approved con arreglos, hechos; 193 → 192 ORO (348 con baseCost 2); HANDOFF §5.7 pasa a "las seis" (hecho en el relevo 21b). **Opción (a) del dueño:** `lucky` 20/×1,09 tal cual (Dios 30,73 → 31,34 h) y `PacingTests` re-pineado a lo medido (paredes ≥ 4, reenc. ≤ 9, corrimiento = pared más lejana ≥ 3 sobre la primera; el extremo da −2). Arreglos de la revisión: `recomputeDerivedEffects` en el bootstrap + test (lucky 11 → crit 0,1375 / dorado 0,0275), textos «las seis» / «≤ 9». Tarea VERDE (unit 103). **Carries a E2b T14 y al dueño:** un veterano de un solo lado (crit 10 / golden 0) pierde (crítico 25 % → 12,5 % + 2,5 % dorado); la última run se traba más abajo (T17 → T12), aceptado; una app vieja que lea un save 2.0 ve crit/golden en 0 (verificar el versionado); el piso de 3 tiers del corrimiento no tiene margen; `ui_up_crit` sin uso; la fila de `lucky` no muestra el dorado → **E13 T13**; el reset de cuenta (E2b T5 / E9b T7) tiene que sumar `meta.floorChestsAwarded` si copia campos a mano |
| E13-T8 | Pisos de arriba con misterio ("Piso ???") | ✅ | — | catálogo (snapshot); FloorMapView, ElevatorPanel, TowerNaming, +Types, +Projections | `545521f` (integ-r18; catálogo +1) | ElevatorPanel es tibio de E7b-b T3; integrar en serie con T4 (+Projections) |
| E13-T9 | Ficha y Despedir desde Personajes | ✅ | verificar CharacterSheetUITests sobre `ab7ba84` (arreglo del panel de debug) | catálogo (snapshot); UpgradesView, +Types, +Actions, CharacterSheetView | | no ∥ T13 (UpgradesView) ni T11 (+Actions); carry de texto a E9b T1; paso 0: verificar `CharacterSheetUITests` |
| E13-T10 | FisuJobs por pisos | ✅ | T8 | FisuJobsView | `54c5648` (integ-r19) | revisión ninguna; `JobGroups` testeable; **hecha (r19):** `GameState.floorDisplayName(for:)` → "Piso ???" también en la ficha y la tienda de pintas (cierra el carry de E13 T8); cartel del LED `TowerNaming.ledText`; el orden es el de `jobRows`; sin receta R ni captura SE con tres pisos |
| E13-T11 | La moneda sobre quien genera plata | ✅ | — | 🔥 BoardScene; CharacterNode, BoardReconciliation, +Actions | `17b29fb` (integ-r18) | no ∥ T9 (+Actions); un nodo por personaje, sin animación |
| E13-T12 | El Diamante dice "Pack de las 43" | ✅ | — | catálogo (snapshot); +Store, CustomizationView | `221f9b6`+`ff3b1ef` (integ-r18; catálogo +1) | revisión ninguna; +Store es tibio de E6b T4/T5 |
| E13-T13 | Las mejoras dicen su efecto, de antes a después | ✅ | T7 | catálogo (snapshot); +Upgrades, EffectDescriptor, UpgradesView | | no ∥ T9 (UpgradesView) |
| E13-T14 | Cierre de E13 (controlador) | ⏳ | T2–T13 | `Docs/` | | `completo`; HANDOFF §5.7 "las seis" |
| P-E13b | Plan de E13 ítems 13–14 (ascensor y barra) | ✅ | — | — | `2560366` (merge `f395ac2`) | 11 tareas (T1–T11); `2026-10-08-v2-e13b-ascensor-barra.md`; 14 dudas con default; **no toca RootView ni GameState** |
| E13b-T1 | El director del viaje en cabina y sus tiempos (≤ 3 s, nunca menos que el vuelo) | ✅ | — | nuevos (`UI/Elevator/ElevatorRide.swift`) | `8b090d4` | sonnet; ola 1 |
| E13b-T2 | La placa colgante: modelo, medidas (34–46 pt) y vista, sin cablear | ✅ | — | nuevos (`ElevatorKeypad.swift`); catálogo (snapshot) | `a7f6eea` | sonnet; ola 1; `ElevatorLED` público (carry E7b-b T3); tocó `PanelFrames.swift` (MetalTone/PanelScrew pasan a internos); `ui_elevator_spring` sin arte: resorte vectorial; previews sin mirar (T8 saca capturas) |
| E13b-T3 | Los sonidos del ascensor (resorte, clic, puertas, motor) y `AudioManager.stop` | ✅ | — | AudioManager (tibio, E5b); generate_audio.py, 4 `.caf` | `440e610` | revisión ninguna; 4 `.caf` (269 KB) SIN escuchar; el motor queda a −8,5 dB RMS (los otros −17 a −24): bajar su volumen al reproducirlo (T6) si suena fuerte; T5/T6 `AudioManager.stop(.elevatorMotor)` al saltear |
| E13b-T4 | Los clips y los cuadros de la cabina (`video_assets.py ascensor`) | ✅ | — | video_assets.py (tibio: pedido de cinemáticas); Resources/Cinematics, loops_manifest.json | `93a76cf` | Python, no compila; key medido en el hueco y las ventanas; masters por `--video`; 4 recursos en `Resources/Cinematics/` (cine_ascensor_{cierra,abre}.mov 87+76 KB; cine_ascensor_{cerrada,abierta}.png 0,86+0,51 MB); sin despill (viraba el amarillo); `xcodegen generate` al integrar |
| E13b-T5 | La cabina y la vista del viaje (clip → cuadros → vectorial) | ✅ | T1 | nuevos (`ElevatorCabin.swift`, `ElevatorRideView.swift`); catálogo (snapshot) | `f008f85`+`d3d3b7c`+`6fb8e83` | **revisión opus** (AVFoundation, memoria de fondos en el SE); no espera a T4; revisión opus: Approved con arreglos (lookups que no crean players; respaldo vectorial si el clip falla; el expiry se cancela al viajar; Reduce Motion = cabina vectorial; dos capas sin parpadeo; thumbnails de a 2). En integ-r13, **SIN `rapido`** (entró después). Carries a T6: `prepare()` al abrir la placa y en `requestFromMap`, `release()` si se cierra sin viajar, montar `ElevatorRideView` con `.environment(gameState)` sólo con `phase != .idle`; memoria del SE y el parpadeo sin medir (T11, en device) |
| E13b-T6 | El viaje montado encima de RootView; el mapa viaja | ✅ | T1, T3, T5 | FisuEvolutionApp (tibio), FloorMapView (tibio, E13 T8); nuevo ElevatorRideOverlay | `5e8b9a5`+`7fcd753`+`323e4bc` (en `v2i/integ-r15`) | **revisión opus**; bajo `--uitest*` el viaje es 0 s (los UI tests de siempre no cambian); revisión opus: Approved con arreglos, hechos (`.idle` = llegado, sin parpadeo; `--uitest-elevator-ride-slow`; `ElevatorSound`/`Cue.sound` puro y testeado; saltear en `.opening` sin doble ding; `.isModal`; `prepare()` no calienta con Reduce Motion; `requestFromMap` ignora con viaje en curso); tarea VERDE unit 44; UI ElevatorRide 3 en 16 Pro + iPad (el onDisappear del mapa dispara), FloorMap 2, CareerChoice 2, AscentRendering 1. Carry a T8: los popups de RootView se dibujan encima de la cabina |
| E13b-T7 | La lección "Mantené apretado el ascensor" al tercer piso | ✅ | — | +TutorialTips (tibio); catálogo (snapshot) | `18fb478` (merge `1ffc9c4` en `v2i/integ-r14`) | revisión ninguna (diff leído por el controlador); clave `tutorial.tip.elevator.hold`, nace con `unlockedFloorsCount >= 3`; **carry a T8: llamar `gameState.elevatorKeypadOpened()` al desplegar la placa** (no sale en una release sin T8); carry E9a T9 / E9b T1 |
| E13b-T8 | Mantener apretado el ascensor despliega la placa; el display LED se va | ✅ | T2, T6, T7; T9 integrada | 🔥 HUDView (épica); ElevatorRideOverlay; borra ElevatorPanel.swift; catálogo (snapshot) | `fc86813`+`5f33a26` (en `v2i/integ-r16`; catálogo +1 −3) | revisión opus: Changes requested → hechos (la bandera del long press baja con `DragGesture` como E3b T7; la placa sólo se recoge al pasar `showing` de nil a un tipo que cubre —`CelebrationKind.coversElevator`—, y `ride.openKeypad()` va antes de `elevatorKeypadOpened()`; capa `.isModal` + `.escape`; guard en `openKeypad()`); tarea VERDE unit 43; UI ElevatorPanel 5 en 16 Pro, SE e iPad, ElevatorRide 3, HUDRedesign 3; placa de 10 pisos en el SE cabe (`--uitest-unlock-tower-all`; tapa parte de Reencarnar mientras está abierta). Carries: `onChoose` del atajo pasa a **E3b T8** (no existe `QuickHirePicker`); sin test con el tip `.elevatorKeypad` en pantalla (no hay fixture); flake bajo carga en `ElevatorRideTests` 'saltear con las puertas abriendo' (subir las iteraciones de `Task.yield`); comentarios viejos de 'la luz de la botonera' en `GameState.swift:130` y `BoardScene.swift:1926` |
| E13b-T9 | La Tienda sale de la barra (se abre con el + de la moneda) | ✅ | — | 🔥 HUDView (una línea); GameArtComponents (barOrder), TabUnlocks, tabs.json, +Tabs, BottomMenuBar; catálogo (snapshot) | `98d7d9f` | ola 1; migra BottomMenu/Store/ProgressiveTabs UITests al `hud.coins.plus`; carry E3b T4 (5 páginas) — duda 1; tarea VERDE unit 89 + UI a mano (BottomMenu/ProgressiveTabs/HUDRedesign 8 en 26.5, Store 2 en 18.6); queda `TabUnlockCondition.secondSession` sin uso; `sixTabsFitTheSE` lo rehace T10; comentarios "seis pantallas" ajenos |
| E13b-T10 | La barra simétrica 2 + 1 + 2, sin rótulos y con íconos grandes | ✅ | T9 | GameArtComponents (GameTabBar), BottomMenuBar | `66e997c` (integ-r14) | `panelHeight` 64 y `barHeight` 84 se conservan; capturas SE e iPad; platos 52/72, íconos 46/64, `bottomPadding` 6; `fiveTabsFitTheSE`, `sidesFillTowardTheCenter`; UI BottomMenu 4/4 en SE, 16 Pro e iPad; `TabUnlockCondition.secondSession` sigue sin uso |
| E13b-T11 | Cierre de E13b (controlador) | ⏳ | T1–T10 | `Docs/` | | `completo`; grabaciones para el dueño |

Dependencias que E13 le suma a otras épicas (plan E13, "Lo que E13 le deja a otras épicas"): **E2b**
T5 ← E13-T3; T6 ← E13-T2; T10 ← E13-T6; T12 ← E13-T2, T3, T6, T7; T14 ← E13-T7 (seis líneas, 348 ORO).
**E7b-b** T1/T2 reusan `.rewardedMergeAll` y el video `merge_all` (ya no crean `siderail.mergeAll`).
**E4a** T4/T7/T9: `evolveBestUnit` con `tiersBelowFrontier: 2` y respaldo en plata; `planEvolve` pide
`maxSourceTier`. **E9b** T1 (textos `tutorial.prestige.oro`, `tutorial.character_sheet.hold`) y T7
(el reset vuelve `meta.floorChestsAwarded` a 0). En §3.1 E13 suma: `GameState.swift` (T4), `+Bonus`
(T2, T6), `ContentSystems` (T7), `PlayerState` (T3, T7), `BoardScene` (T11).

### E10 — Release 2.0

| Pieza | Estado | Qué falta |
|---|---|---|
| E10 en papel | ✅ | ver "Hechos previos" |
| Parte de agente: archive desde cero (build ≥ 5), las verificaciones del `.app` de PLAN-v2 §8, capturas de iPhone 6,9" y iPad 13" por idioma, notas a App Review con todos los lugares de anuncios, archivos de `adergames-site` (`app-ads.txt`, `legal.ts`, Términos, `config/ads.json`), `HANDOFF-v2.md` y `balance-log.md` | ⛔ | sin plan por tareas; va al final (§8). ⚠️ `ExportOptions.plist` sube directo |
| Parte humana | 🔒 | §8 |

### Inconsistencias y huecos entre planes (abiertas)

1. **E8 y la parte de agente de E10 no tienen plan por tareas.** Sin ellos no hay forma de contar
   su avance ni de despacharlos; lo mínimo es un plan chico de E8 cuando vuelva el piloto de arte
   y uno de E10 antes del archive.
2. **E7b-b, cuándo arranca**: su encabezado dice "cuando E4, E5 y E6 cerraron y E7b-a T3 entró";
   su tabla de "Orden" da dependencias más finas por tarea (T6 sólo necesita E2a T11/T12, E1 T12,
   E4a T8 y E4b T3). La tabla de arriba copia la del plan; el controlador decide si adelanta.
3. **`EngagementState.init` serializa cuatro épicas detrás de E1 T16**: E3b T9 (tras E1 T16) →
   E4a T3 → E5a T4 → E6a T1. La dependencia de E4a T3 con E3b T9 es sólo de orden en el mismo
   `init` (suma `sharedMoments` primero); si el controlador acepta otro orden, E4a T3 podría ir
   antes y E3b T9 rebasar.
4. **E2b, antes o después de E9**: el árbol de PLAN-v2 §4 la pone después de E9; el texto de E2b
   pide "después de E4–E6", y E7b-b le suma fuentes al perfil `.ads`.
5. **La rama de E6**: E6b T1/T2 salen "desde `version-2`", pero `v2/e6-tienda` se define "desde
   `version-2` con E5 integrada" (E6a). Hay que crearla para T1 y mergearle `version-2` (con E5)
   antes de E6a T1.
6. **E6a escribe `oroPurchasedLifetime +=`** (T9, T11 y sus tests): con E1 T6c el contador pasa a
   calculado y la puerta es `recordOroPurchase`. El plan de E6a quedó viejo en eso.
7. **Los anexos A y B**: E0 los lista como gate humano, pero ningún plan los gatea. E4a T7 carga los
   26 guiones del Anexo A tal cual; conviene la aprobación antes de despacharla.
8. **El texto del plan de E3a quedó viejo** después de los spikes (`fisuSheet` con `.page`, la sonda
   de T4, botones de 34 pt, `crowdTopRatio` 0,70): los despachos de T6, T8 y T10 llevan las líneas
   S1/S6/S5 del ledger de E3a.

## 6. Gates humanos y 🔒 del dueño

| Gate | Qué hace el dueño | Bloquea | Estado |
|---|---|---|---|
| Supabase para E12 | crear el proyecto de Supabase y pasar URL + clave anónima; cargar `ANTHROPIC_API_KEY` como secreto de Supabase | E12 (backend y cliente real; mientras tanto, cliente simulado) | ✅ proyecto creado y `ANTHROPIC_API_KEY` cargada por el dueño (2026-10-08); ref, URL y clave pública en DUENO.md "Hecho por el dueño — Supabase de E12" (la clave entra al repo en E12 T16); los agentes lo ven por el conector de Supabase |
| Lista de palabras de E12 | aprobar la lista inicial de palabras bloqueadas | E12 (moderación en `finish-run`) | ✅ cerrado (2026-10-09, el dueño en el chat: aprobada tal cual; migración `20261009000001_blocklist.sql`, se despliega con E12 T16) |
| Revisión del ranking | revisar las partidas en `review` (bajo el piso de plausibilidad) y los nombres reportados | operación de E12 tras el lanzamiento | 🔒 permanente |
| Batch de imágenes | (2026-10-07: corriendo, ~155/222; los 10 `bg_*` esperan a ChatGPT) login en el Chrome aislado de ChatGPT (`--launch` + `--probe`) y correr el batch **con la app de Claude cerrada** (roba el foco); proyecto `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2` (222 prompts), **primero el piloto 001–005**; paso a paso en su `README.md` | E6b T9 (familias), el resto de E8 (visitantes, fondos, íconos); E4b y E6a caen a respaldos y no esperan | ✅ terminado y APROBADO por el dueño (222/222, 2026-10-08); los 10 `bg_*` escalados a 2048 (Real-ESRGAN). Crudos en `automatic-image-generation/projects/fisu-evolution-v2/output/`. Destraba la integración de E8 (dropbox → `process_dropbox.py`, `npc`/`skinfam`, `prompts.json`, atlas) y E6b T9 |
| Higgsfield | OK de créditos para el piloto de 2 loops (tope 600) | los loops de retrato y las 3 cinemáticas (E8); E4b T3 cae a la foto quieta | ✅ OK a todo, tope 600 (2026-10-07) |
| Anexos A y B | aprobar los guiones y frases (A) y la biblia de los 8 visitantes (B) | (ambigua: ningún plan lo gatea) A: E4a T7 y T9; B: los prompts del batch | ✅ aprobados sin cambios (2026-10-07) |
| Galería de 8 efectos | mirar las 8 fotos (E6b T2) y elegir cuáles entran; por cada descartado, qué skins existentes pasan a ser exclusivas de ORO | E6b T8 | ✅ ninguno entra; exclusivas de ORO: de la v1, las propone el agente y el dueño da el OK en T8 |
| Cuentas de las 4 redes | AppLovin, Unity Ads, Mintegral, Meta: cuenta, app, placements, claves | E10 (mapeo en AdMob, `app-ads.txt`); no bloquea E7b-a T6 | 🔒 abierto |
| Unidades de AdMob | crear app open + las 4 de video; IDs en `feature_flags.json` y en el `ads.json` publicado; prender `switches.appOpen` | E10; hasta entonces app open apagado y videos con respaldo | ✅ (2026-10-08) 11 unidades (5 nuevas: ruleta, colchón, visitantes, diario, app open); IDs en `feature_flags.json` y `ads.json` (publicado, 200) y `switches.appOpen: true`; integrado con `v2/release-ops` (relevo 12). Fuente de verdad: `Distribution/release/release.json` |
| Productos en App Store Connect | las 3 ofertas, los packs reescalados, las localizaciones es-MX/es-ES/en-US de los 11 existentes | E10 (el desarrollo usa el `.storekit` local) | ✅ salvo capturas (2026-10-08): 14 IAP configuradas, `asc diff` VERDE; `oro_large` a USD 9.99 (OK del dueño). Queda: las capturas de revisión de las 3 ofertas cuando exista la hoja (E6a T11): `releaseops asc screenshot offer_<id> <png>` → `asc ready`. Auditoría: `Distribution/release/AUDITORIA-2026-10-08.md` |
| Playtest de precios | probar las variantes (g, r) y el amortiguador en el panel de debug | E2b (qué variante se calibra); necesita E2a T14 | ⛔ hasta E2a T14 |
| TestFlight | 1–2 días de playtest con anuncios reales y compras en sandbox | mandar a revisión | ⛔ hasta E10 |
| `rentista_soles` | elegir: dejarlo, conectividad con halos, o regenerar los soles | ninguna tarea; **no borrar el worktree `v2-e8-pipeline`** | ✅ integrado (E8 T1, relevo 12): soles sólidos en `cosmic.atlas`, fuera de `RECORTE_VIEJO_A_PEDIDO`. El worktree `v2-e8-pipeline` ya no existe (lo barrió el mantenimiento del dueño) |
| 4 filas en el SE | decidir si la fila de atrás no entra (escalón de `crowdTopRatio`, sprites más chicos o sólo pantallas grandes) | E6b T7, sólo si la medición falla | ⛔ |
| Peso de las familias | On-Demand Resources si el bundle crece > 60 MB | E6b T9, sólo si pasa | ⛔ |

### Las dudas con default de cada plan (ninguna frena)

| Plan | Dónde | Cuántas |
|---|---|---|
| E1 | `2026-10-06-v2-e1-correcciones-criticas.md:4758` | 12 (la 11, CloudKit y lo comprado, la resuelve T6c) |
| E11 | `2026-10-07-v2-e11-notificaciones.md:3026` | 8 |
| E2a | `2026-10-07-v2-e2a-mecanicas.md:3937` | 14 |
| E3a | `2026-10-07-v2-e3a-ux-nucleo.md:3463` | 11 (la 2, la columna, la resolvió C) |
| E3b | `2026-10-07-v2-e3b-ux-nucleo.md:3199` | 10 |
| E4a | `2026-10-07-v2-e4a-visitantes-eventos.md:5616` | 13 |
| E4b | `2026-10-07-v2-e4b-visitantes-eventos.md:5242` | 13 |
| E5a | `2026-10-07-v2-e5a-aduana-colchon-ruleta.md:3221` | 12 |
| E5b | `2026-10-07-v2-e5b-aduana-colchon-ruleta.md:3172` | 13 |
| E6a | `2026-10-07-v2-e6a-tienda-ofertas.md:5217` | 15 (+ el 🔒 de `:67/:68`, resuelto: T6c) |
| E6b | `2026-10-07-v2-e6b-lugares-skins.md:2621` | 9 |
| E7b-a | `2026-10-07-v2-e7b-a-forzados-mediacion.md:2691` | 12 |
| E7b-b | `2026-10-07-v2-e7b-b-columna-ubicaciones.md:2502` | 17 (la 1 decidida: C) |

Las cinco nuevas de E7b-b (relevo 6), con su default:

- El "!" de "Premios" cuenta la ruleta, así que queda prendido casi todo el día.
- La columna se recoge a los 3 s y la botonera del ascensor a los 2 s.
- La columna y la botonera son independientes: abrir una no cierra la otra.
- La columna nunca se abre sola por un "!" nuevo: sólo al tocarla o por una lección.
- La columna es de metal (`MetalPlate`), no de madera.

## 7. Decisiones del dueño del relevo 6 (no se vuelven a preguntar)

| Tema | Decisión | Consecuencia |
|---|---|---|
| Relevo | Crear las rutinas `fisu-v2-relevo-a/-b` | Creadas, manuales. El agente que cierra lanza la otra con `run_scheduled_task` |
| 🔒 `SaveConflictResolver.swift:67/:68` | **Arreglo exacto** | E1 T6c: mapa crece-sólo id → ORO + revocados, `oroPurchasedLifetime` calculado, unión de `creditedPurchases`, `&&` en `purchasedOroReconstructed`; absorbe T6b. E6a pasa por `recordOroPurchase` |
| Fusiones asistidas (`BoardChange.merge` de carrera y debug) | **Cuentan** en `totalMergesEver` | Sin cambio |
| Guiños ocultos (relevo 7) | **"Six Seven" en 3 lugares, "andá pa' allá, bobo" en 1**, sin nombrar a nadie real | Turista con camiseta 67 (prompts 016–019 del batch), Crypto Bro y Coach (67 toques) en E4a T7, Vecina en E4a T7. Tope: no se suman más |
| 🔒 La columna de E7b pisa la multitud | **C: plegable**, hermana de la botonera del ascensor ("Premios" abajo a la izquierda; despliega los cuatro por 3 s) | E7b-b T3 cambia el contenedor y T4 se saltea. Descartadas A (reserva de 64 pt) y B (encima) |

### Decisiones del dueño del 2026-10-07 (recogidas en otra sesión; no se vuelven a preguntar)

| Tema | Decisión | Consecuencia |
|---|---|---|
| Skins por código (E6b T2) | **Ninguna.** "Solamente las skins propuestas por el plan de la versión 2 y las que ya estaban en la versión 1" | E6b T1r borra shaders, galería y `.effect`; T5 sólo familias; T8 = exclusivas de ORO de la v1 con OK del dueño. Detalle: `Docs/SESION-2026-10-08-v2-e6.md` |
| Higgsfield | OK a todo, tope 600 créditos | E8 no espera al piloto |
| Anexos A y B | Aprobados sin cambios | Destraba E4a T7 y T9 |
| Batch de imágenes | Corriendo | Integrarlo es una tarea aparte cuando termine (`process_dropbox.py`, categorías `npc`/`skinfam`, `prompts.json`) |
| Worktrees viejos | Limpiados por el dueño | El sintetizador sustractivo vive en `rescate/audio-sintesis-sustractiva`, candidato para los temas de E8 |

## 8. El camino hasta el final

**La meta del run** (carta del journal): FisuEvolution 2.0 lista para mandar a App Review, con E0–E11
cerradas y su oráculo `completo` en verde, y sólo los pasos humanos de E10 pendientes.

**Orden en que cierran las épicas** (cada una con su tarea de cierre):

1. **E1** (T16, con T5c y T6c adentro). Bloquea a todas.
2. **E11** (T7): T6 necesita E1 T9.
3. **E3** (E3a T12; E3b T9 cierra E3): E3b T9 sale tras E1 T16.
4. **E2a** (T15): T11 y T12 después de E1 T15. Deja la tabla de perillas para E2b.
5. **E4** (E4a T10 → E4b T10): E4a T9 tras E1 T16; E4a T3 tras E3b T9.
6. **E5** (E5a T9 → E5b T7): por tarea, al lado de E4.
7. **E6** (E6a T13, E6b T10): después de E5; E6b T8 y T9 esperan sus gates.
8. **E7b** (E7b-a T7, E7b-b T8): E7b-b cuando E4, E5 y E6 cerraron.
9. **E9** (falta el plan): después de E7b.
10. **E2b** (falta el plan): con todas las fuentes adentro (punto 4 de "Inconsistencias").
11. **E8** (resto): según los gates del arte; antes de las capturas de E10.
12. **E10**: la parte de agente (archive, verificaciones, capturas, notas, sitio) y después la
    humana.

**Lo que queda humano en E10:**

- App Store Connect: versión 2.0.0 con novedades es/en; los productos (3 ofertas, packs
  reescalados, los 11 existentes con es-MX/es-ES/en-US); subir capturas; cuestionario de edad
  (loot boxes sí); App Privacy con AdMob y las 4 redes ("Data Used to Track You"); pegar las notas
  a App Review; Mac y visionOS deshabilitados si no se probaron.
- AdMob: las unidades nuevas, los grupos de mediación con las 4 redes, mensajes de UMP e IDFA,
  bloqueo de la categoría de juego de azar, dispositivos de prueba.
- Las 4 redes: cuentas, registro de la app, placements y claves para AdMob.
- Publicar en `adergames-site` lo que prepare el agente (`app-ads.txt`, política, Términos,
  `config/ads.json`).
- Subir el build (el `ExportOptions.plist` sube directo), TestFlight de 1–2 días y mandar a
  revisión.
