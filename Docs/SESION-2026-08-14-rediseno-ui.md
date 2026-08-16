# SESIÓN 2026-08-14/15 — Rediseño de UI estilo Cow Evolution (EN CURSO)

> **Para retomar con un agente nuevo, leé esto y alcanza.** Actualizado
> después de CADA tarea (regla del dueño: ninguna tarea nueva arranca sin
> que la anterior esté documentada acá).

## Cómo se retoma

1. Rama de trabajo: `feature/rediseno-ui-cowevolution`. Verificá `git log`.
2. Spec: `Docs/superpowers/specs/2026-08-14-rediseno-ui-cowevolution-design.md`.
   Plan (20 tareas): `Docs/superpowers/plans/2026-08-14-rediseno-ui-cowevolution.md`.
3. Proceso: skill `superpowers:subagent-driven-development`. Workspace del
   plan: `.superpowers/sdd/2026-08-14-rediseno-ui-cowevolution/` (gitignorado)
   con `progress.md` (ledger detallado: minors diferidos, rulings, agentIds),
   `task-N-brief.md` pre-generados para TODAS las tareas, `task-N-report.md`
   por tarea hecha, y tres borradores de autoría listos:
   `draft-iconos-prompts.md` (T19), `draft-logros-copy.md` (T14, ⚠️ son
   **39 logros, no 36** — error de suma del titular del spec; 78 claves),
   `draft-terms-es-en.md` (T16). Si el workspace no existe, reconstruí de
   este doc + `git log`.
4. Política de modelos: implementadores y reviewers en **opus**; escalada de
   fix rounds 4-5 en el modelo de la sesión. Un implementador por vez,
   SECUENCIAL (comparten RootView/GameArt/xcstrings). Cada agente crea su
   simulador por UDID y lo borra al terminar.
5. Al terminar cada tarea: review de spec+calidad → fix loop si hace falta →
   ledger → **actualizar este doc y commitearlo** → recién ahí la siguiente.

## Estado por tarea

| # | Tarea | Estado | Commits | Notas |
|---|---|---|---|---|
| 1 | Decoders del save + campos nuevos | ✅ review clean | `0f8654d` | Arregló bug latente real: el default de `seenTypes` no protegía el decode (save v4 viejo se perdía) |
| 2 | Contadores en choke points | ✅ review clean | `f2b97c9` | Auto-merge del reconciliador NO cuenta (pineado) |
| 3 | hireQuote por tipo + tierPremium | ✅ review clean (1 fix round) | `d18d5c4` + `8bd8bb2` | tierPremium 1.8; pacing-sim idéntico byte a byte; overload viejo de hireCost BORRADO (supera la letra del plan) |
| 4 | Design system v2 | ✅ review clean | `587f55a` | GameArtComponents + GameIcons (16 iconos vectoriales verificados renderizados); +`b17cb6b` (.gitignore de .superpowers/, del controller) |
| 5 | jobRows + hireCharacter | ✅ review clean | `66992c1` | Retomó parcial de un agente interrumpido (auditado, conservado). ⚠️ payloads `...NameKey` llevan el nombre YA RESUELTO |
| 6 | HUD superior nuevo | ✅ review clean | `30b8e98` | Barra contigua (moneda+/monedas+`X /s`/ascensor) + fix de la clave muerta de la pill (trampa 5). Los 4 botones viejos quedaron TRANSITORIOS |
| 7 | Barra inferior + tutorial | ✅ review clean | `18f45d3` | 6 tabs (ids `hud.hire/upgrades/skins/bonus/store/settings`), SpawnButtonView borrado, bottomInset 110→114, tutorial por milestone, EconomyLoop/Tutorial UITests reescritos, BottomMenuUITests nuevo. Placeholders: jobs (lista cruda), skins, menu |
| 8 | FisuJobsView | ✅ review clean (1 fix round) | `55736ba` + `3d2eb64` | Pantalla real de contratación (3 secciones, wordmark parodia, silueta "???"). Fix: la fila es UNA parada de VoiceOver + label hablable. +`65fac2a` (reformateo xcstrings de Xcode, controller). ⚠️ el patrón de fila accesible (accessibilityHidden en info/badge) es el que deben copiar las pantallas siguientes |
| 9 | Upgrades v2 | ✅ review clean (1 fix round) | `0b47a8b` + `f6d7e68` | Restyle con GameCard/ProgressBar/PricePill, ORO en header, margen 40pt medido del arte; VoiceOver: nombre UNA vez en el retrato (tests pineados intactos). Retrato 104pt (test manda sobre el 88 del spec) |
| 10 | ElevatorView | ✅ review clean | `72dc510` | El mapa es un ascensor (GameCard por piso, actual en amarillo, riel, `elevator.title`). Coherencia con FisuJobs CONFIRMADA por review (cabecera literal, mismo Tone, margen 36pt medido) |
| 11 | Customization Shop | ✅ review clean (1 fix round) | `bd9b64d` + `e539876` | Carrusel de caras + grilla de skins (4 estados); unificó JobStateBadge→StateBadge (FisuJobs intacto, verificado); fixture nuevo `--uitest-storekit-empty` (9º arg). Coherencia con FisuJobs CONFIRMADA. Fix: StoreKit caído ya no miente "no está a la venta" |
| 12 | Tienda IAP v2 + timeout | ✅ review clean | `e4e7fe6` + `1b71856` | Timeout del Loading con carrera de canal (sin task group — el grupo mudaba el cuelgue), retry real, vidriera restyleada (starter destacado, packs, skins con preview), settings FUERA de la tienda (sin superficie hasta T16). Coherencia con FisuJobs CONFIRMADA. ⚠️ entorno: tras `simctl erase`, correr unit antes de UI o el plazo vence sin tienda local |
| 13 | GiftsView | ✅ review clean | `4f64aa2` | Regalos v2: calendario diario NUEVO en pantalla + boosts + videos; BonusView borrada. Retomó un parcial de un agente cortado por API (auditado, conservado casi entero). `rewardText` saca el ×N del dato y no de la copy. Fixture nuevo `--uitest-daily-streak` (10º arg). Coherencia con FisuJobs CONFIRMADA por captura lado a lado; el fix visual salió de la captura, no de leer. ⚠️ el flavor de varios boosts REPITE el efecto (copy a triage) |
| 14 | Logros (catálogo+motor) | ✅ review clean (1 fix round) | `274af9d` + `f056dcc` + `d95cc36` | 39 logros data-driven (el draft mandó), motor con 11 hooks, claim con recompensas, toast `ach.toast`, 82 claves. Fix: seen_all mide los 37 ALCANZABLES derivados del dato, portero eliminado, premio con suelo histórico (rewardText = claim). La pantalla la hace T15 |
| 15 | Menú + org/stats/logros | ✅ review clean (1 fix round: `f08099e` — organigrama sin rearme por tick, tier con "(esta vida)") | `ce07c8a`..`f08099e` | Las 4 pantallas del menú. `menu.placeholder` MURIÓ (`ScreenPlaceholderView` borrado: las seis hojas de la barra existen). Es la ÚNICA hoja que navega hacia adentro. `statsSnapshot` (18 stats en texto) + `orgChartRows` (43 nodos, tier DESC). Margen 34pt medido en panel_config (marco DOBLE). Fixture nuevo `--uitest-achievements` (11º arg). 43 claves. Coherencia con FisuJobs verificada por captura lado a lado |
| 16-20 | — | pendientes | — | Ver plan. ⚠️ **T16 arranca reemplazando `SettingsPlaceholderView`** (privado dentro de `MenuView.swift`) y el `case .settings` del `navigationDestination` |

**Suites al cierre de T15**: `FisuEvolutionTests` **306** (294 + 12 de
`StatsSnapshotTests`) · `MenuUITests` 6/6 · `BottomMenuUITests` 2/2 · cero
warnings de compilador.

**Suites al cierre de T8**: `FisuEvolutionTests` 235 · UI verdes (FisuJobs 2,
EconomyLoop 2, BottomMenu 2, Tutorial 5; suite completa 28/28 en T7, con
`-skip-testing:FisuEvolutionUITests/AscentRenderingUITests`, rojo
preexistente) · EconomyKit 180 · cero warnings.

## ⚠️⚠️ REGLA VISUAL DEL DUEÑO (2026-08-15, SUMA IMPORTANCIA)

**FisuJobs (`FisuEvolution/UI/Jobs/FisuJobsView.swift`) es la REFERENCIA
VISUAL canónica. Todas las pantallas — menú, upgrades, personalización,
bonus/regalos, tienda IAP y el ascensor — tienen que verse coherentes con
ella. Todo el juego mantiene UNA identidad visual.** Cada dispatch de
implementación o review de una pantalla incluye esta regla explícita.

La gramática compartida (extraída de FisuJobs, T8):
- Filas/celdas = `GameCard`; precios = `PricePill`; niveles/progreso =
  `ProgressBar`; badges de estado con el mismo lenguaje (unificar
  StatePill/JobStateBadge está en el triage).
- Paleta SOLO `Color("Palette*")`; tipografía SOLO `Tokens.*` (rounded
  heavy); bordes ink; crema de fondo.
- Margen del panel MEDIDO contra el arte del `panel_*` que use la vista
  (T8 midió 30pt en panel_store, T9 40pt en panel_upgrades, T10 36pt en
  panel_dialog) — las tarjetas nunca pisan el marco de madera.
- Cabecera fija con fondo crema OPACO + `toolbarBackground` crema (el
  contenido no se transparenta al scrollear).
- Cierre siempre `ArtCloseButton` (`sheet.close`).
- Accesibilidad: fila informativa = una parada (patrón T8: hidden en
  info/badge, nunca en el control); controles con identifier propio;
  jamás identifier en contenedores.

## Decisiones del dueño (no re-litigar)

FisuJobs como nombre · curva por tier con tierPremium (gate de un piso y
Fisura a 50 intactos) · 2 skins pagas con catálogo extensible por dato ·
iconos vectoriales ahora + batch de Gemini después (lo corre el dueño desde
Terminal.app) · logros: la enumeración (39) manda sobre el "36" del titular.

## Avisos vivos

- **Xcode estuvo ABIERTO durante todos los `xcodegen generate`** (trampa 15):
  cuando el dueño abra el proyecto y vea `Missing package product
  'EconomyKit'`, cerrar y reabrir el proyecto.
- Los minors diferidos de cada review viven en el ledger — la ola final del
  review de rama los triagea. Los más jugosos: CurrencyPill huérfana (T6),
  ConfigView + `hireOffer`/`showSpawnHint`/strings `spawn.*` muertos hasta
  T12/T16 (T7), glifo de VectorCoinPlusIcon chico en su círculo (T6/T19).
- `jobRows` se re-evalúa por invalidación de proyecciones — vigilar con 43
  tarjetas en T8.
- Flakies conocidos sensibles a carga: `StoreManagerTests`,
  `EconomyLoopUITests`, `BonusHUDUITests` — re-correr aislados antes de
  culpar al código.
- ⚠️⚠️ **Correr los tests de UI ANTES que la suite unitaria rompe
  `StoreManagerTests` ENTEROS** (medido en T15: 13 issues, ninguna compra
  acreditada, y **fallaban igual aislados** — o sea que NO es carga). Con el
  device borrado y `StoreManagerTests` primero, 10/10 verdes sin tocar nada.
  Es la otra mitad del dato de T12: la asimetría es real y direccional —
  una corrida de UI deja la tienda local del simulador en un estado que
  SKTestSession ya no puede usar. **Unit siempre primero.**
- ⚠️ **Dentro de una vista EMPUJADA de un `NavigationStack`,
  `@Environment(\.dismiss)` DESAPILA, no cierra la hoja** (T15). Si una
  sub-vista tiene que cerrar el sheet entero, el cierre viaja como closure
  desde la raíz del stack. Con `dismiss`, `sheet.close` se comporta como el
  chevron de atrás que ya está al lado.
- El HANDOFF de `main` (commit `6156c59`) apunta a esta sesión pero dice
  "retomar en Task 3": este doc es la fuente de verdad del estado; el
  HANDOFF se re-sincroniza al cierre de la sesión o del branch.
