# SESION 2026-10-08 — v2, relevo 11: la ola H, las carreras gratis y el auto-tap

Relevos 10 y 11 de la ejecución autónoma de la 2.0, el mismo día. El 10 (sesión `local_399d0a72`)
despertó a las 08:11 y lo mató el dueño a las 08:25; el 11 (sesión `local_e1bbf0f9`) retomó su
trabajo y cerró. Controlador opus; implementadores sonnet en worktrees manuales; revisión opus en
lo que mueve plata (E2a T11, E2a T12, E6a T3).

## El relevo 10 que quedó vivo pero invisible

El dueño borró la rutina `fisu-v2-relevo-b` y el scheduler **archivó la sesión de run** que ella
había lanzado: el relevo 10 siguió corriendo, con el `LOCK` tomado y su latido vivo, pero sin
aparecer en la barra. Cuando la rutina `fisu-v2-relevo-a` despertó al relevo 11 a las 08:25, la puerta
del `LOCK` dio candado vivo. El dueño ordenó matar esa sesión y seguir: se mató su proceso `claude`
y su latido con `SIGTERM`.

- **Sus tres oráculos murieron con ella**: el `completo --limpio` #1 sobre `69a5f80` (sin log) y los
  `tarea` de E2a T11 y E3b T3. El #1 se relanzó.
- **Sus dos agentes habían terminado el trabajo pero no commiteado** (`v2h-e2a-t11` y `v2h-e3b-t3`).
  Se retomaron con agentes nuevos en esos mismos worktrees; los dos encontraron el trabajo casi
  completo y lo cerraron.
- Quedaron tres simuladores `oraculo-26-5-84457/86209/86390` apagados, que no se pudieron borrar
  (ver trampas).

## Lo que entró a `version-2`

`version-2` = **`e378307`**, pusheado (todo pasó por la rama de integración `v2h/integ-r11`, armada
sobre `69a5f80`).

| Tarea | Commit | Nota |
|---|---|---|
| E3b T3 el menú deslizable, las piezas | `77c277e` | `MenuSessionTests` verde; sin textos nuevos; la UI del paginador es T4 |
| E4a T8 `grant` y el momento calmo | `8376c23` (merge `288d06c`) | grant único en `GameState+Rewards`, `isCalmMoment`; `RewardGrantTests` 9 verdes; **sin llamadores** (no mueve plata todavía) |
| E2a T11 diario, asado y logros en minutos | `afca476` + `8b0ebbe` (merge `41b6909`) | revisión opus: Approved con arreglos; mueve plata (diario 5–40 min, día 7 = 15, asado 10) |
| E2a T12 las carreras | `2d42b83` (merge `860e944`, claves `e378307`) | revisión opus: Approved con arreglos; `freeHire` nace acá, las carreras pagan por el `grant` de E4a T8, la inmunidad se cablea a `eventIsApplicable` |
| E2a T13 pisos en marcha en el mapa | `ab2a137` (merge `cc958b4`) | `staffedSummary` + badge `map.staffed`; `EffectContractTests` mergeó limpio con T11 |
| E2a T14 el panel de debug | `05136be` (merge `b33b2c1`) | variantes, perillas y Fusionar todo; `DebugEconomyKnobsTests` 3 verdes; `#if DEBUG` salvo `enqueueMergeAll` (sin llamadores) |
| E6a T3 el auto-tap | `720f3fe` | `AutoTapper` + `autoTapPerSecond`; EK 549, unit 20; sin llamadores = identidad; revisión opus: Approved |

Los textos de T11, T12, T13 y E6a T3 entraron con `catalogo.py aplicar` desde sus snapshots
(`e2a-t11.json`, `e2a-t12.json`, `e2a-t13.json`, `e6a-t3.json`).

## Oráculo

- **`completo --limpio` #1 sobre `69a5f80`** (E1 T16): unit 760 + 1 · Release · Store 16 · StoreUI 2 ·
  iPad UI 2 · pipeline 49 · pacing-sim, **VERDES**. Dos rojos, ninguno de código:
  - `economykit`: `swift-frontend` murió con signal 11 por el `ModuleCache` de `.build` con la ruta
    vieja `.claude/worktrees/version-2` (la mudanza a `.nosync`). `swift package clean` y
    `swift test` → 543 VERDE.
  - `ui` 69/70: `MenuUITests.testLosTerminosSeAbrenDesdeAjustes` ("el tab del menú nunca quedó
    tocable"). Aislada ×2: 7/7 y 7/7 → flaky de carga.
- **`rapido` sobre `e378307`: VERDE** — EK 553 · unit 782 + 1 · release 0.
- **`completo --limpio` #2 sobre `e378307`** (E1 T16): en curso al cierre
  (`build/relevo11-completo-limpio-2.log`). Resultado: ROJO en UI por 3 REGRESIONES reales de la ola H (se repiten aisladas sobre e378307): MenuUITests.testLosTerminosSeAbrenDesdeAjustes (el documento de Términos se dibuja vacío; pasaba aislado sobre 69a5f80 → sospecha E3b T3, NavigationStack(path:) en MenuView), BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos (no encuentra debug.chest.award → sospecha E2a T14, sección nueva del panel de debug) y CharacterSheetUITests.testDespedirPideLaTarjetaDeLaCasaYNoUnaAlerta (sospecha E2a T12 o E4a T8). Todo lo demás VERDE: EK 553 · unit 782+1 · release 0 · store-unit 16 · store-ui 2 · ipad-ui 2 · pipeline 49 · pacing-sim 30,73 h / 13. E1 T16 NO cierra: primera tarea del relevo 12 = arreglar las 3 (bisecar con los merges de la ola H si la sospecha no alcanza), re-correr esas clases aisladas y después un completo --limpio sobre la punta

## Decisiones de este relevo

- **Reescribir `AchievementEngineTests.coinRewardKeepsItsHistoricFloor` es legítimo** (ahora
  `...HistoryCapped`): el tope de `RewardScale` de E2a T1 lo exige (PLAN-v2:501, frontera + 3) y el
  plan no lo había previsto. La revisión opus lo confirmó.
- **El día 7 del diario pinea 15 minutos exactos** por el camino real (`ContentSystemsTests`), no sólo
  el piso.
- **El Médico (Obra social) y la inmunidad se cablean a `eventIsApplicable`**; hasta que E4a reconcilie
  el criterio, vale `!isBuff`.
- **Contratar gratis atraviesa el Corralito** (continúa la decisión del relevo 9); queda anotado como M4.
- **`Agent(isolation: "worktree")` no se usa** mientras `.claude/worktrees` sea un symlink: el
  controlador arma los worktrees (`worktrees.nosync/v2h-<tarea>`, rama `v2h/<tarea>`) y despacha
  agentes sin `isolation`, apuntados ahí.
- **Regla del dueño (09:27)**: borrar el worktree de cada tarea al integrarla y barrer al cerrar con
  `~/.claude/scheduled-tasks/fisu-v2-relevo-a/limpiar-worktrees.sh` (todo en GitHub antes; nunca
  `--force`). Y nueva bandeja `DUENO.md` en `.claude/avo/2026-10-06-fisu-v2/` con cuatro pendientes
  que no están en `tasks.md`: integrar `v2/release-ops`, cerrar los gates de AdMob/ASC, el batch de
  arte aprobado y el rentista regenerado. A las 09:30 el dueño publicó `ads.json` en `adergames-site`
  (commit `331b694`, 200 `application/json`).

## Carries (de las revisiones y los reportes)

**E2a T11** (opus): indentación en `ContentSystems.swift:426-428`; clave muerta `bonus.effect.payout %@`;
las carreras seguían con `passiveUnlockCost` (lo cierra T12).

**E2a T12** (opus, todos Minor):
- M1: `activeEvent` no se persiste → el Médico no corta un evento negativo tras relanzar. Arreglo:
  sacar los modificadores `event.*` `!isBuff` si `activeEvent == nil`.
- M2: `eventIsApplicable` usa `Date()` y el criterio `!isBuff` choca con los eventos "mixtos" de E4a →
  reconciliar en E4a.
- M4: contratar gratis atraviesa el Corralito (decisión a anotar).
- M5: FisuJobs muestra "0" y no "Gratis".
- Claves huérfanas: `career.reward.welcome %@`, `career.reward.boost %@ %@`,
  `career.reward.modifier %@ %@` y `bonus.effect.payout %@`; las saca una tarea dueña del catálogo.
- M3 (comentario "premio del Médico" en `+Achievements`) se corrigió en el merge.

**E6a T3 → T5** (opus, Minor): el "mejor" auto-tap se elige por tier y no por pago (fiel al plan;
anotar la decisión); un `now` para todo el delta (despreciable con el tope de 2 s); `RewardSpec` admite
`.modifier(autoTapPerSecond)` y saltea `.autoTap` → rechazarlo en `validate` o declararlo válido. El
cableado y el premio son de T5.

**E4a T8 → T9**: `isCalmMoment` duplica `isSafeMomentForInterstitial` (E7b lo unifica); los kinds fuera
de `grantableRewardKinds` no se ofrecen (`VisitorScheduler`/`eventIsApplicable`).

**E3b T3 → T4**: `MenuPagerUITests`; `menuDidOpen/PageChanged/Close` en `RootView`; comprobar S2 (el
carrusel de Pintas contra el gesto del paginador) en el simulador.

**E2a T14**: falta la prueba manual del paso 4 del plan; `enqueueMergeAll` y `planMergeAll` siguen sin
llamador en la app.

## Trampas nuevas

- **El `ModuleCache` de SwiftPM guarda rutas absolutas**: tras mover los worktrees a `*.nosync`,
  `swift-frontend` crashea con signal 11 (`_DarwinFoundation1 defined in both`). No es código:
  `swift package clean` en cada worktree movido.
- **`Agent(isolation: "worktree")` falla** porque `.claude/worktrees` es un symlink (mantenimiento de
  iCloud). Workaround: worktrees manuales en `worktrees.nosync/v2h-<tarea>`.
- **El clasificador de auto mode bloquea `xcrun simctl delete` de simuladores ajenos**: los
  `oraculo-26-5-*` del relevo 10 quedaron apagados y sin borrar (inofensivos). Los borra el dueño.
- **Borrar una rutina archiva la sesión de run que lanzó** sin matar su proceso: queda un controlador
  vivo e invisible con el `LOCK` tomado. Antes de borrar una rutina, mirar el `LOCK` y su latido.
- **Matar la sesión mata sus oráculos** (todos colgaban de ella): no queda log del `completo`. Lanzar los
  oráculos largos en su propio grupo de procesos, con el log a disco.
- **Integrar en serie lo que toca `EffectContractTests`/`ActiveModifier`** (T11, T12, T13, E6a T3): dos
  conflictos reales (enum `Effect`, `ModifierMath`, `tint`, filas del test) se resolvieron a mano
  conservando ambos lados.
- **Agentes con trabajo previo sin commitear**: al retomar, el primer paso es leer el diff del worktree
  y correr su `tarea`, no reescribir.

## Cierre

- Subagentes en vuelo al cierre: **0**. Quedó corriendo sólo el `completo --limpio` #2.
- Limpieza pendiente: los worktrees `v2h-*` (todos integrados) y los tres simuladores; ver el handoff.
