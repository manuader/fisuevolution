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
| 11 | Customization Shop | ⏳ **PRÓXIMA** | — | CustomizationView + skinCatalogRows; brief en el workspace |
| 12-20 | — | pendientes | — | Ver plan |

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
- El HANDOFF de `main` (commit `6156c59`) apunta a esta sesión pero dice
  "retomar en Task 3": este doc es la fuente de verdad del estado; el
  HANDOFF se re-sincroniza al cierre de la sesión o del branch.
