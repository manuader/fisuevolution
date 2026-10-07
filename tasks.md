# FisuEvolution 2.0 — el tablero de la implementación

> Tablero único de la 2.0: qué está hecho, qué sale ahora, qué espera a quién. Lo pidió el dueño:
> "implementarla por completo cuanto antes, con subagentes concurrentes que no se pisen entre sí".
> Fuentes: `Docs/PLAN-v2.md` (§0.1, §4, E8–E11), los 13 planes de
> `Docs/superpowers/plans/2026-10-0*-v2-*.md`, los ledgers
> `.superpowers/sdd/<plan>/progress.md` y el journal AVO del run.
>
> **Foto:** 2026-10-07, cierre del relevo 6, sobre `version-2` = `3956fd3` (su `rapido`:
> (pendiente); se pushea después del verde). Si un ledger dice otra cosa que este archivo, manda
> el ledger y este archivo se corrige.

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
3. **Implementación**: TDD, `oraculo.sh rapido` antes del commit final, reporte en su worktree y
   respuesta de menos de 15 líneas.
4. **Revisión**: un subagente revisor de spec y calidad (skill `subagent-driven-development`; opus
   si la tarea toca calientes o el tablero, sonnet si es chica).
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
| E1 | `v2/e1-correcciones` | `ca2d12c` (T8 + arreglos + T5c; mergeada en `7110b06`) |
| E11 | `v2/e11-notificaciones` | `8d17b8d` (T3 en `worktree-agent-acb378d5ca1b3d546` = `f084ef5`, sin integrar) |
| E3a + E3b | `v2/e3-ux` | `c323dd9` (T5; mergeada en `3956fd3`) |
| E5a + E5b | `v2/e5-premios` | `a4c156f` (E5a T1; sin mergear a `version-2`) |
| E2a | `v2/e2a-mecanicas` | a crear desde `version-2` |
| E4a + E4b | `v2/e4-visitantes` | a crear desde `version-2` |
| E6a + E6b | `v2/e6-tienda` | a crear (ver "Inconsistencias", punto 5) |
| E7b-a + E7b-b | `v2/e7b-anuncios` | a crear desde `version-2` |
| E8 | `v2/e8-pipeline` | `4ea0678` (integrada; **no borrar su worktree**: `rentista_soles`) |

## 2. Progreso

**Hoy: 15 de 132 tareas activas integradas (11,4 %).** Más las de E9 y E2b cuando tengan plan.

| Épica | Activas | ✅ | 🟢 | 🔧 🔄 | ⏳ | ⛔ | 🔒 | ⏭️ |
|---|---|---|---|---|---|---|---|---|
| E1 | 16 | 8 | | | 2 | 6 | | |
| E11 | 7 | 2 | | 1 | | 4 | | |
| E3a | 12 | 5 | | | 2 | 5 | | |
| E3b | 9 | | | | 1 | 8 | | |
| E2a | 15 | | | | 3 | 12 | | |
| E4a | 10 | | | | 1 | 9 | | |
| E4b | 10 | | | | | 10 | | |
| E5a | 9 | | 1 | | | 8 | | |
| E5b | 7 | | | | | 7 | | |
| E6a | 13 | | | | | 13 | | |
| E6b | 10 | | | | 1 | 7 | 2 | |
| E7b-a | 7 | | | | | 7 | | |
| E7b-b | 7 | | | | | 7 | | 1 |
| E9, E2b | sin plan | | | | | | | |
| **Total** | **132** | **15** | **1** | **1** | **10** | **103** | **2** | **1** |

Fuera del conteo:

- los **hechos previos a los planes por tarea**: E0 oráculo, E8 pipeline, E8 audio, E7a, E3 i18n y
  E10 en papel (§5, "Hechos previos");
- los **seguimientos**: E1 T5b ✅, T5c ✅, T6c ⏳;
- las **tareas de planificación**: P-E9 ⏳, P-E2b ⏳.

**Cómo recalcularlo** (las filas de tarea de §5 tienen el ID `E<épica>-T<n>` en la 1ª columna y el
estado en la 3ª; los seguimientos `T5b`/`T5c`/`T6c` y los `P-…` no entran):

```bash
grep -cE '^\| E[0-9a-z-]+-T[0-9]+ \|[^|]*\| ✅' tasks.md   # integradas
grep -cE '^\| E[0-9a-z-]+-T[0-9]+ \|' tasks.md             # filas de tarea
grep -cE '^\| E[0-9a-z-]+-T[0-9]+ \|[^|]*\| ⏭' tasks.md     # salteadas
grep -cE '^\| E2a-T[0-9]+ \|[^|]*\| ✅' tasks.md           # una épica: cambiar el prefijo
```

Progreso = integradas / (filas de tarea − salteadas). Hoy: 15 / (133 − 1). Cualquier otro estado se
cuenta igual, cambiando el ✅. Cuando E9 y E2b tengan plan, sus tablas se suman con el mismo
formato de ID y el total sube solo.

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

## 4. Cola de despacho — lo próximo (relevo 7)

**En vuelo al cierre del relevo 6**: sólo el `rapido` sobre `3956fd3`, en el worktree de
`version-2` (log `version-2/build/relevo6-rapido-3956fd3.log`; esperado EK 357 · unit 639 + 1 ·
release 0): (pendiente). Ningún agente en vuelo. Al llegar quedan los 3 cupos de compilación (el
`rapido` ocupa uno mientras corra) y los 2 de planificación.

### 4.1 Al llegar

| # | Qué | BASE | Modelo | 🔥 que toma | Nota |
|---|---|---|---|---|---|
| 0 | **El veredicto del `rapido` sobre `3956fd3`** | — | controlador | — | VERDE → push `7110b06..3956fd3`. ROJO → fuera de los docs, el diff contra `ca2d12c` son los 4 archivos de E3a T5 |
| 1 | **E11 T3, arreglos**: I1 (`v1FalseIsRespected` tiene que llegar al interruptor maestro: refrescar la autorización antes), I2 (un test de la rama `.denied` de `refreshAuthorization`: vacía la cola) y una línea de docstring en `scheduleAbsence` (decide con la autorización ya leída) | `f084ef5` | sonnet, **agente nuevo**: el de `f084ef5` no sobrevive al relevo | ninguno (tests + un docstring) | paquete `.superpowers/sdd/2026-10-07-v2-e11-notificaciones/review-8d17b8d..f084ef5.diff` y la revisión en el ledger de E11 |
| 2 | **P-E9** ∥ **P-E2b** (planes) | punta de `version-2` | opus | un archivo nuevo en `Docs/superpowers/plans/` cada uno | no en paralelo con otro agente que edite el mismo archivo de `Docs/`. Insumos en §5 (E9, E2b) |

### 4.2 La ola E

Antes, o en el mismo `rapido` de fin de ola: integrar **E11 T3** (con sus arreglos) en
`v2/e11-notificaciones` y mergear **`v2/e5-premios` (`a4c156f`)** a `version-2`. Esperado: EK
**393** · unit **651 + 1** más los tests que sumen los arreglos de E11 T3 · release 0.

Las ramas de épica se adelantan por ff a la punta de `version-2` antes de despachar (así T9 y T6c
salen con E3a T5 adentro).

| Compila | BASE | Modelo | Dueña de | Por qué ahora |
|---|---|---|---|---|
| **E1 T9** el turno de los cambios del tablero | punta de `version-2` (`3956fd3` tras el verde) | sonnet (brief `task-9-brief.md`; carry de T7: hacer público el init de `BoardChangeOutcome` si los tests lo construyen) | `GameState.swift`; crea `+BoardChanges`; `+Celebrations`, `+Lifecycle`, `+Debug` | camino crítico: E1 bloquea a todos |
| **E1 T6c** el ORO comprado exacto (+ T6b) | ídem | sonnet (brief `task-6c-brief.md`) | `PlayerState.swift` (sólo `MetaState`); `SaveConflictResolver` y sus tests, `+Store`, `PurchasedOroHistory`, `StoreManager` y sus tests. **No** `GameState.swift` | decisión del dueño; E1 no cierra sin ella; va antes de E2a T2/T7, E6a T7/T9/T11 y E9. Corre `store-unit` en 18.6 (1.945 s con la máquina cargada en el último `completo`) |
| tercer cupo: **E11 T3 arreglos** (4.1), y al liberarse **E3a T6** hojas en iPad (destrabada por T5) o **E6b T1** los 8 efectos | E3a T6: punta de `v2/e3-ux`; E6b T1: `version-2` (rama `v2/e6-tienda` nueva) | sonnet | E3a T6: `PanelFrames`, los popups, `HUDView`, `OfflineEarningsView`; E6b T1: sólo archivos nuevos | E3a T6 abre T8 y el camino a T10; lleva las líneas de S1 y los carries de T5 (sin `#available`; los tests de plist leen el archivo). E6b T1 abre el gate de la galería, lo más largo de E6 |

E1 T11 queda ⏳ desde que T8 se integró, y no comparte archivos con T9 ni T6c, pero no acorta el
camino crítico (T12 espera a T10 igual): va con T10, salvo que sobre un cupo.

Nadie toca en la ola E: `RootView`, `BoardScene`, `ContentSystems`, `+Bonus`, `TowerActions`,
`SettingsView`, `project.yml`, `Localizable.xcstrings`.

### 4.3 La cola, por prioridad

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
| E1-T6c | (seguimiento) ORO comprado exacto entre dispositivos + T6b | ⏳ | T4, T6 | 🔥 PlayerState (`MetaState`); SaveConflictResolver, +Store, StoreManager | brief listo `task-6c-brief.md` | fuera del conteo; ola E (∥ T9); antes de E9 y de E6a T9/T11 |
| E1-T7 | El embudo `BoardChange` en EK | ✅ | T3, T4 | — | `ec6fb29` | carries: init público de `BoardChangeOutcome` (T9), guarda de `typeId` (T10) |
| E1-T8 | Ciclo de vida: sellar al irse, latido, evento vencido | ✅ | T5 | 🔥 GameState, RootView, +Bonus; FisuEvolutionApp, +Debug, ContentConfigs, events.json | `eeb7322` + `5ef7a65` (merge `7110b06`) | re-revisión opus ✅: `flushHUD` sólo proyecta con la escena inactiva; un sello por salida |
| E1-T9 | El turno de los cambios del tablero | ⏳ | T7, T8, T5c | 🔥 GameState; +BoardChanges (nuevo), +Celebrations, +Lifecycle, +Debug | brief listo `task-9-brief.md` | ola E (∥ T6c); carry de T7: init público de `BoardChangeOutcome` |
| E1-T10 | La escena reproduce los cambios y revela | ⛔ | T9 | 🔥 BoardScene, GameState, RootView; CelebrationQueue, +Celebrations, +Debug | | E3a T10 y E4b T1 esperan esta |
| E1-T11 | El sorteo de eventos salta lo inaplicable | ⏳ | T7; T8 integrada | 🔥 ContentSystems, +Bonus; ContentConfigs, events.json | | el plan la pone ∥ T10; por archivos también va ∥ T9 (no acorta el camino crítico) |
| E1-T12 | Startup, Blanqueo, videos y carrera por el embudo | ⛔ | T9, T10, T11 | 🔥 ContentSystems, +Bonus, GameState; +Actions, +Debug | | E2a T4 integrada antes |
| E1-T13 | El Corralito congela el gasto, con salida por video | ⛔ | T12 | 🔥 TowerActions, ContentSystems, +Bonus, GameState, RootView, catálogo; +Hiring, +Actions, ContentConfigs | | E2a T3 integrada antes |
| E1-T14 | Un video sin efecto no gasta el cooldown | ⛔ | T9–T13 | 🔥 +Bonus, GameState, RootView, catálogo; +BoardChanges, +Achievements | | |
| E1-T15 | `EffectContractTests` | ⛔ | T1–T14 | ActiveModifier, ContentConfigs, AdsProvider | | si E2a T4 entró, la fila `.tapMultiplier` pasa `tiers:` |
| E1-T16 | Cierre de E1 (controlador) | ⛔ | T1–T15, T5c, T6c | `Docs/` | | `completo --limpio` ×2; pacing-sim sin cambios |

### E11 — Notificaciones (`2026-10-07-v2-e11-notificaciones.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E11-T1 | Catálogo y planificador de la ausencia (EK) | ✅ | — | — | `508a4c5` | |
| E11-T2 | `notifications.json` validado y sus textos | ✅ | T1 | 🔥 catálogo; GameContentLoader | `9c5847c` | |
| E11-T3 | El manager 2.0: prendidas por defecto, permiso en dos pasos | 🔧 | T1, T2 | 🔥 SettingsView, catálogo | `f084ef5` (en `worktree-agent-acb378d5ca1b3d546`; sin integrar) | faltan 2 tests (I1, I2) + un docstring; arreglos NO despachados: agente nuevo con BASE `f084ef5` (§4.1) |
| E11-T4 | Ajustes: el maestro, uno por motivo, "Abrir Ajustes" | ⛔ | T3 | 🔥 SettingsView, catálogo | | antes de E7b-a T5 |
| E11-T5 | La tarjeta del permiso en el popup offline | ⛔ | T3 | catálogo (snapshot si va con T4); OfflineEarningsView | | no con E3a T6 |
| E11-T6 | El cableado al ciclo de vida | ⛔ | T3; E1-T1, E1-T5, E1-T8, E1-T9 | 🔥 GameState; +Lifecycle, +Celebrations, FisuEvolutionApp | | carry: el comentario de `FisuEvolutionApp.swift:10-11` |
| E11-T7 | Cierre de E11 (controlador) | ⛔ | T1–T6 | `Docs/` | | |

### E3a — UX núcleo, la pantalla (`2026-10-07-v2-e3a-ux-nucleo.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E3a-T1 | El catálogo canónico (`catalogo.py`) | ✅ | — | — | `f542b16` | |
| E3a-T2 | Spikes S1, S4, S5, S6 | ✅ | — | — | sin commit (ledger de E3a) | cambian T4, T6, T8, T10 |
| E3a-T3 | `PlayLayout` | ✅ | — | — | `f03950c` + `5afb893` (0,63) | |
| E3a-T4 | `ScreenInsets` y `PlayColumn` | ✅ | T3 | — | `b988bc3` + `537f923` | |
| E3a-T5 | Universal, iOS 18, contrato del Info.plist | ✅ | — | 🔥 project.yml; Info.plist, PanelFrames | `c323dd9` (merge `3956fd3`; `rapido` (pendiente)) | carries a T6, T10, T12 en el ledger; el release con Xcode 26.x |
| E3a-T6 | Hojas y popups en iPad (`fisuSheet`) | ⏳ | T4, T5 | PanelFrames, 8 popups, HUDView, OfflineEarningsView | | S1: `fullScreenCover` + `statusBarHidden`; carry de T5: sin `#available` |
| E3a-T7 | La barra de abajo más baja, Contratar al centro | ⏳ | T4 | GameArtComponents, BottomMenuBar | | |
| E3a-T8 | La botonera del ascensor | ⛔ | T6 | catálogo (o snapshot); PanelFrames, HUDView, AudioManager | | S6: botones de 30 pt; cablea `elevatorDing` |
| E3a-T9 | Las pestañas aparecen de a poco | ⛔ | T7; E1-T4; ventana de GameState | 🔥 GameState, catálogo; +Debug, GameContentLoader | | |
| E3a-T10 | La escena: PlayLayout, 3 filas, cámara, iPad | ⛔ | T3, T7, T8; E1-T10 | 🔥 BoardScene, GameState, RootView; `oraculo.sh` | | carries: `ScreenInsetsUITests` al `ipad-ui` (iPad Pro 13", sin tocar `rojos-declarados.txt`); si se puede, saltear los especiales (E4b T9 los borra) |
| E3a-T11 | La raíz: chrome en la columna, seis hojas | ⛔ | T6, T10 | 🔥 RootView | | no con E1 T13–T14 |
| E3a-T12 | Cierre de E3a: SE en castellano, capturas de iPad | ⛔ | T1–T11 | `oraculo.sh` | | carries: `ScreenInsetsUITests` al `se-ui`; fijar Xcode 26.x como SDK del release (el SDK 27 ignora `UIRequiresFullScreen`) |

### E3b — UX núcleo, las interacciones (`2026-10-07-v2-e3b-ux-nucleo.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E3b-T1 | Spikes S2, S3 | ⏳ | — | — | | opus, sin commit |
| E3b-T2 | La ficha de personaje | ⛔ | E3a-T6, E3a-T7 | catálogo (snapshot); GameArtComponents, DebugPanelView | | |
| E3b-T3 | El menú deslizable, las piezas | ⛔ | T2; E3a-T8 | catálogo; PanelFrames, MenuView | | |
| E3b-T4 | El menú deslizable, montado | ⛔ | T3; E3a-T9, E3a-T11 | 🔥 RootView | | |
| E3b-T5 | Renombre `BestHire` → `QuickHireOffer` | ⛔ | ventana sin E1 en GameState y +Hiring | 🔥 GameState, RootView (comentarios); +Hiring, +TutorialTips | | |
| E3b-T6 | La oferta del atajo v2: pin, motivo, nunca `nil` | ⛔ | T5; E1-T4, E1-T13 | +Hiring | | |
| E3b-T7 | El botón del atajo nunca desaparece | ⛔ | T6 | catálogo; QuickHireButton | | |
| E3b-T8 | El selector del atajo | ⛔ | T7, T4 | 🔥 RootView, catálogo; DebugPanelView | | |
| E3b-T9 | Compartir recableado (y cierre de E3) | ⛔ | T8; E1-T16 | 🔥 GameState, +Bonus, RootView, catálogo; +BoardChanges, +Debug, ContentConfigs, EngagementState | | su `sharedMoments` lo esperan E4a T3 y E5a T4 |

### E2a — Mecánicas de economía (`2026-10-07-v2-e2a-mecanicas.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E2a-T1 | `RewardScale`: premios en minutos | ⏳ | E1-T3 | — | | EK |
| E2a-T2 | El reintegro al fusionar + `EconomyKnobs` | ⏳ | E1-T3, E1-T4 | 🔥 PlayerState | | no con E1 T6c |
| E2a-T3 | El amortiguador y el "+6 %" | ⛔ | T2 | 🔥 PlayerState, TowerActions | | antes de E1 T13 o después de T14 |
| E2a-T4 | Pisos en marcha y la capacidad que sólo crece | ⛔ | T3 | +Actions | | antes de E1 T12 o después de T14 |
| E2a-T5 | El piso móvil para reencarnar | ⛔ | T4; E1-T4 | — | | EK |
| E2a-T6 | "Fusionar todo", el plan | ⏳ | E1-T7 | BoardChange.swift | | EK |
| E2a-T7 | Cofres y packs de plata en minutos | ⛔ | T1; E1-T6 | +Store, products.json, StoreManagerTests | | no con E1 T6c |
| E2a-T8 | El piso móvil en pantalla | ⛔ | T5; E1-T4 | catálogo (snapshot) | | |
| E2a-T9 | Las fusiones del juego al amortiguador y al reintegro | ⛔ | T2, T3, T6; E1-T7, E1-T9, E1-T12, E1-T14 | 🔥 TowerActions, GameState; GameContentLoader, +Actions, +BoardChanges | | |
| E2a-T10 | "+6 % por compra" en FisuJobs | ⛔ | T3, T9; E1-T13 | +Hiring; catálogo (snapshot) | | de a una con E3b T5/T6 |
| E2a-T11 | Diario, asado y logros en minutos + presupuesto | ⛔ | T1, T7; E1-T14, E1-T15 | 🔥 ContentSystems, +Bonus | | por tarea con E4/E5 |
| E2a-T12 | Las carreras: gratis, Juicio ganado, Obra social | ⛔ | T11, T7; E1-T11, E1-T13, E1-T15 | 🔥 TowerActions, +Bonus | | `.freeHire`/`.eventImmunity`: nacen acá o en E4a T2, la que llegue primero |
| E2a-T13 | Pisos en marcha en el mapa | ⛔ | T4, T9; E1-T15 | catálogo (snapshot) | | E3a T8 opcional |
| E2a-T14 | El panel de debug: variantes, perillas, Fusionar todo | ⛔ | T5, T6, T9 | +Debug, DebugPanelView, +BoardChanges | | habilita el playtest de precios del dueño |
| E2a-T15 | Cierre de E2a + tabla de perillas para E2b | ⛔ | T1–T14 | `Docs/` | | |

### E4a — Visitantes y eventos v2, el motor (`2026-10-07-v2-e4a-visitantes-eventos.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E4a-T1 | `RewardSpec` | ⏳ | — | — | | EK; cimiento de E5–E7 |
| E4a-T2 | Efectos nuevos: paro, inmunidad, ritmo de paquetes | ⛔ | E1-T13, E1-T15 | catálogo (snapshot); ActiveModifier, ActiveBonus*, EffectContractTests | | |
| E4a-T3 | Los relojes en `meta.engagement` | ⛔ | E1-T4, E3b-T9 | EngagementState | | (ambigua: ver "Inconsistencias", punto 3) |
| E4a-T4 | El motor de eventos v2 (EK) | ⛔ | T1, T2, T3 | — | | |
| E4a-T5 | Los visitantes, puros | ⛔ | T1, T3 | — | | |
| E4a-T6 | `VisitPlanner` | ⛔ | T5; E1-T7, E1-T14 | BoardChange.swift, +BoardChanges | | |
| E4a-T7 | El contenido de los visitantes | ⛔ | T5, T6; E11-T2, E3a-T1 | catálogo (snapshot); GameContentLoader, LocalizationCompletenessTests | | carga el Anexo A |
| E4a-T8 | `grant` y el momento calmo | ⛔ | T1, T2; E1-T8, E1-T14 | — | | |
| E4a-T9 | La mudanza a eventos v2 | ⛔ | T2, T4, T7, T8; E1-T16 | 🔥 GameState, +Bonus, ContentSystems, catálogo | | |
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
| E5a-T1 | El Paquete de la Aduana, puro | 🟢 | E1-T3 | — | `b4800c5` + `a4c156f` en `v2/e5-premios` | carries a T2/T3/T5/T6 en el ledger |
| E5a-T2 | El Colchón, puro | ⛔ | T1; E4a-T1 | — | | |
| E5a-T3 | La Ruleta, pura | ⛔ | T1; E4a-T1 | — | | |
| E5a-T4 | Paquetes, colchón y ruleta en `meta.engagement` | ⛔ | T1–T3; E3b-T9, E4a-T3 | EngagementState | | |
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
| E6a-T1 | Tienda y ofertas en `meta.engagement` | ⛔ | E1-T4; E3b-T9, E4a-T3, E5a-T4 | EngagementState | | |
| E6a-T2 | Catálogo y cuentas de la tienda (EK) | ⛔ | T1; E4a-T1 | — | | |
| E6a-T3 | El auto-tap | ⛔ | E1-T15; E4a-T2; E2a-T4 | catálogo (snapshot); ActiveModifier, ActiveBonus*, EffectContractTests | | |
| E6a-T4 | `oro_shop.json` | ⛔ | T2; E5b-T1; E5a-T5 | catálogo (dueña); GameContentLoader | | |
| E6a-T5 | Se entregan auto-tap, Offline ×3 y Diario ×3 | ⛔ | T3; E4a-T8, E4a-T9; E5a-T6, E5a-T8; E2a-T11 | 🔥 +Bonus; +Lifecycle (T8 mudó ahí el offline), +Rewards, +Engagement | | |
| E6a-T6 | Comprar en la tienda | ⛔ | T4, T5; E2a-T14; E1-T14; E5a-T1, E5a-T3, E5a-T6, E5a-T8 | BoardChange.swift, +BoardChanges | | |
| E6a-T7 | La suerte: probabilidades | ⛔ | T6; E5a-T1, E5a-T8; E1-T6 | StoreManager | | sale con E1 T6c adentro |
| E6a-T8 | La pantalla "Comprar ORO / Gastar ORO" | ⛔ | T6, T7; E3b-T4; E5b-T1; E5a-T8 | catálogo (dueña); StoreView | | |
| E6a-T9 | Los packs 160 / 550 / 1.400 | ⛔ | E1-T6; E2a-T7 | products.json, StoreManagerTests | | con T6c: por `recordOroPurchase` |
| E6a-T10 | Las ofertas de 24 h, puras | ⛔ | T1; E4a-T1 | — | | |
| E6a-T11 | Las ofertas se cobran | ⛔ | T9, T10; E4a-T8; E2a-T7; E5a-T6 | catálogo (snapshot); products.json, +Store | | con T6c: por `recordOroPurchase`, no `+=` |
| E6a-T12 | Las ofertas se ven | ⛔ | T7, T8, T11; E5a-T8; E4b-T3; E3a-T6; E5b-T1, E5b-T2 | 🔥 RootView, catálogo; CelebrationQueue, +Celebrations | | |
| E6a-T13 | Cierre de E6a | ⛔ | T1–T12 | `Docs/` | | |

### E6b — Lugares extra, pintas con ORO, efectos y familias (`2026-10-07-v2-e6b-lugares-skins.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E6b-T1 | Los 8 efectos, por código | ⏳ | — | — | | sale de `version-2`; ola E |
| E6b-T2 | La galería de los 8 efectos (→ 🔒 dueño) | ⛔ | T1 | DebugPanelView | | al terminar, el gate |
| E6b-T3 | `skins.json` v2 (EK) | ⛔ | T1 | GameContentLoader | | |
| E6b-T4 | La pinta comprada con ORO es tuya | ⛔ | T3; E6a-T1, E6a-T2, E6a-T8; E3b-T2 | 🔥 PlayerState, catálogo; +Store | | |
| E6b-T5 | Efectos y familias se ven | ⛔ | T1, T4; E6a-T8; E5b-T3 | 🔥 BoardScene, catálogo; +Store | | |
| E6b-T6 | Lugares extra (EK) | ⛔ | E6a-T2; E2a-T4 | — | | |
| E6b-T7 | Lugares extra en la partida | ⛔ | T6; E6a-T6, E6a-T8, E6a-T12; E3a-T10; E5a-T6 | 🔥 GameState, catálogo; GameContentLoader, +Engagement | | 🔒 si las 4 filas no entran en el SE |
| E6b-T8 | Los efectos aprobados entran | 🔒 | gate de T2; T5 | catálogo | | la respuesta del dueño |
| E6b-T9 | Las tres familias entran | 🔒 | arte de E8; T5 | catálogo | | 🔒 si el bundle crece > 60 MB |
| E6b-T10 | Cierre de E6b | ⛔ | T1–T9 | `Docs/` | | |

### E7b-a — Anuncios v2, los forzados (`2026-10-07-v2-e7b-a-forzados-mediacion.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| E7b-a-T1 | La config remota en marcha | ⛔ | E1-T8, E11-T6 | FisuEvolutionApp | | |
| E7b-a-T2 | Los cortes naturales | ⛔ | T1; E1-T8; E3b-T4; E4a-T8 | 🔥 GameState, RootView; +Lifecycle, +Celebrations, FisuEvolutionApp | | |
| E7b-a-T3 | La pausa publicitaria | ⛔ | T2; E4a-T8; E5a-T6; E5b-T1; E4b-T3; E1-T14 | 🔥 GameState, RootView, catálogo; DebugPanelView | | |
| E7b-a-T4 | El app open al volver | ⛔ | T2 | — | | no ∥ T3 (los dos editan `+Ads`) |
| E7b-a-T5 | "Opciones de privacidad" (UMP) en Ajustes | ⛔ | E11-T4 | 🔥 SettingsView, catálogo | | antes de los Ajustes de E9 |
| E7b-a-T6 | La mediación: adaptadores, SKAdNetwork, Ad Inspector | ⛔ | T1; E3a-T5 | 🔥 project.yml; Info.plist, DebugPanelView | | las cuentas de las redes no la bloquean |
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
| El batch de imágenes (~200: visitantes, especiales hablando, paquete, colchón, tienda, álbum, 129 de familias) | 🔒 | lo corre el dueño (§6); después: alta en `prompts.json`, `process_dropbox.py` (sección `npcs`), atlas |
| Higgsfield: 18 loops de retrato + cinemáticas de reencarnación, arresto y Dios | 🔒 | OK de créditos para el piloto de 2 loops; el lado Swift de `.cinematic` y `seenCinematics` no lo tiene ningún plan |
| Fondos regenerados a 2048 px | 🔒 | salen del batch |
| La cadena animada de "Fusionar todo" | ⛔ | E2a la deja a E8; ningún plan la toma |
| Los 10 temas | 🔒 | el dueño los escucha (gate de E8 audio) |

### E9 — Tutorial v2 + Tour de novedades + Ajustes (sin plan)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E9 | Plan de E9 | ⏳ | — | un archivo nuevo en `Docs/superpowers/plans/` | | opus; insumos: PLAN-v2 E9 y las secciones "Lo que … le deja a E9" de E11, E2a, E3b (duda 10), E4a/E4b, E5a/E5b, E6a/E6b, E7b-b; el reset usa T6c |

Ejecución: después de E7b (árbol de PLAN-v2 §4), con E1 T6c (el reset) y E7b-a T5 (UMP) adentro.

### E2b — Calibración final y contrato de pacing (sin plan)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E2b | Plan de E2b | ⏳ | — | un archivo nuevo en `Docs/superpowers/plans/` | | opus; insumos: PLAN-v2 E2b, "Lo que E2a le deja", las bullets de E2b de E4a, E5a, E6a/E6b y E7b-b, y la nota de E1 T1 (el offline del simulador) |

Ejecución: necesita la tabla de perillas de E2a T15, el playtest de precios del dueño (E2a T14) y
todas las fuentes (E4–E6 y E7b-b) (ambigua: ver "Inconsistencias", punto 4). Reemplaza el rojo
declarado `theOwnersTargetsAreMet` por el contrato nuevo y pasa las 7 líneas a 348 (E6a duda 15).

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
| Batch de imágenes | login en el Chrome aislado de ChatGPT (`--launch` + `--probe`) y correr el batch **con la app de Claude cerrada** (roba el foco); proyecto `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2` (222 prompts), **primero el piloto 001–005**; paso a paso en su `README.md` | E6b T9 (familias), el resto de E8 (visitantes, fondos, íconos); E4b y E6a caen a respaldos y no esperan | 🔒 abierto |
| Higgsfield | OK de créditos para el piloto de 2 loops (tope 600) | los loops de retrato y las 3 cinemáticas (E8); E4b T3 cae a la foto quieta | 🔒 abierto |
| Anexos A y B | aprobar los guiones y frases (A) y la biblia de los 8 visitantes (B) | (ambigua: ningún plan lo gatea) A: E4a T7 y T9; B: los prompts del batch | 🔒 abierto |
| Galería de 8 efectos | mirar las 8 fotos (E6b T2) y elegir cuáles entran; por cada descartado, qué skins existentes pasan a ser exclusivas de ORO | E6b T8 | ⛔ hasta E6b T2 |
| Cuentas de las 4 redes | AppLovin, Unity Ads, Mintegral, Meta: cuenta, app, placements, claves | E10 (mapeo en AdMob, `app-ads.txt`); no bloquea E7b-a T6 | 🔒 abierto |
| Unidades de AdMob | crear app open + las 4 de video; IDs en `feature_flags.json` y en el `ads.json` publicado; prender `switches.appOpen` | E10; hasta entonces app open apagado y videos con respaldo | 🔒 abierto |
| Productos en App Store Connect | las 3 ofertas, los packs reescalados, las localizaciones es-MX/es-ES/en-US de los 11 existentes | E10 (el desarrollo usa el `.storekit` local) | 🔒 abierto |
| Playtest de precios | probar las variantes (g, r) y el amortiguador en el panel de debug | E2b (qué variante se calibra); necesita E2a T14 | ⛔ hasta E2a T14 |
| TestFlight | 1–2 días de playtest con anuncios reales y compras en sandbox | mandar a revisión | ⛔ hasta E10 |
| `rentista_soles` | elegir: dejarlo, conectividad con halos, o regenerar los soles | ninguna tarea; **no borrar el worktree `v2-e8-pipeline`** | 🔒 abierto |
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
| 🔒 La columna de E7b pisa la multitud | **C: plegable**, hermana de la botonera del ascensor ("Premios" abajo a la izquierda; despliega los cuatro por 3 s) | E7b-b T3 cambia el contenedor y T4 se saltea. Descartadas A (reserva de 64 pt) y B (encima) |

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
