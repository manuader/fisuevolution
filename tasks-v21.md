# FisuEvolution 2.1 — el tablero de la implementación

> Tablero único de la 2.1: qué está hecho, qué sale ahora, qué espera a quién. Orden del dueño (2026-10-16, en vivo):
> «andá trabajando en la versión 2.1 en una branch aparte con agent teams».
> Fuentes: `Docs/v21/PLAN-v2.1.md` (alcance, §0 decisiones V4–V12, gates G1–G7), la spec
> `Docs/PLAN-v2-E15-valor-por-jugador.md`, la investigación `Docs/v21/investigacion-R1-R8.md` y los 5 planes por tareas
> `Docs/superpowers/plans/2026-10-16-v21-e15-*.md`.
>
> **Foto:** 2026-10-16, cierre del relevo 61. Rama base **`version-2.1`** (desde `v2i/integ-r59` `5b3d2cce`) =
> `15451961` (ola 5 integrada y verificada). **Nada de la 2.1 entra a `version-2`.** Progreso: **31 de 42**. Queda
> **F2-T5** (calibración), después la **ola 6** (build único) y los 🔒 del dueño.
> Si un plan por tareas dice otra cosa que este archivo, manda el plan y este archivo se corrige.

## 1. Cómo se usa

Igual que `tasks.md` §1 (la 2.0), con estas diferencias:

- **Un solo escritor: el controlador de la 2.1.** Los subagentes nunca lo editan.
- **Ramas:** cada tarea en `.claude/worktrees.nosync/v21-<fase>-tN` (rama `v21/<fase>-tN`) desde la BASE que da la
  cola (§4); la integración de la ola en `v21i/integ-<ola>`; el controlador mergea a `version-2.1`.
- **No se compila por tarea** (regla del dueño, `ola-v21/comun.md`): el agente escribe código y tests, commitea y
  pushea; el controlador compila y corre todo **una vez por ola** (las verificaciones de la ola 6 son el build único de
  la 2.1 entera; las olas intermedias pueden juntar su build con la siguiente si la Mac está ocupada con la 2.0).
  Mientras corra el `completo` de la 2.0, **nadie** de la 2.1 compila ni corre `swift test`.
- **Revisión:** opus en todo lo que toca plata, anuncios, save o privacidad (casi todo; columna «Modelo»); sonnet en
  herramientas y UI sin plata; ninguna en docs.
- **Estados:** los de `tasks.md` (✅ en `version-2.1` · 🟢 hecha y revisada en su integración · 🔧 · 🔄 · ⏳ lista ·
  ⛔ bloqueada por dependencias o por datos · 🔒 espera al dueño · ⏭️).

## 2. Progreso

**31 de 42** (olas 1–5 menos F2-T5). Por fase:

| Fase | Activas | ✅ | 🟢 | 🔧 🔄 | ⏳ | ⛔ | 🔒 |
|---|---|---|---|---|---|---|---|
| F1 | 9 | 7 |  |  |  | 1 | 1 |
| F2 | 9 | 7 |  |  | 1 | 1 |  |
| F3 | 8 | 7 |  |  |  | 1 |  |
| F4 | 3 | 1 |  |  |  | 2 |  |
| F5 | 4 | 3 |  |  |  | 1 |  |
| F6 | 5 | 3 |  |  |  | 2 |  |
| F7 | 4 | 3 |  |  |  | 1 |  |
| **Total** | **42** | **31** |  |  | **1** | **9** | **1** |

**Cómo recalcularlo** (las filas de tarea de §5 tienen el ID `V21-F<fase>-T<n>` en la 1ª columna y el estado en la 3ª):

```bash
grep -E '^\| V21-F[0-9]-T[0-9]+ \|[^|]*\| ✅' tasks-v21.md | wc -l   # integradas
grep -E '^\| V21-F[0-9]-T[0-9]+ \|' tasks-v21.md | wc -l              # filas de tarea
grep -E '^\| V21-F[0-9]-T[0-9]+ \|[^|]*\| ⏭' tasks-v21.md | wc -l    # salteadas
grep -E '^\| V21-F2-T[0-9]+ \|[^|]*\| ⏳' tasks-v21.md | wc -l        # una fase y un estado: cambiar prefijo y emoji
```

Progreso = integradas / (filas de tarea − salteadas).

## 3. Reglas de concurrencia

- **Topes:** los de `tasks.md` §3 (≤ 3 compilando; con la regla de no compilar por tarea, compila sólo el controlador).
- **Un dueño por archivo 🔥 por ola.** Un agente que necesita un 🔥 ajeno para con `NEEDS_CONTEXT`.
- **El catálogo (`Localizable.xcstrings`) no lo toca nadie:** `Tools/v2/claves-pendientes/v21-<fase>-tN.json`, lo
  aplica el controlador con `catalogo.py aplicar` al integrar.
- **Supabase:** cambios al SQL = **migración nueva** con el timestamp que fija su plan (`20261016000001` F1-T3,
  `…02` F1-T6, `…03` F7-T1, `…04` F7-T3); nada se aplica en remoto (🔒 P4).

### 3.1 Los 🔥 y tibios de la 2.1 (dueño por ola)

| Archivo | Ola → tarea dueña |
|---|---|
| `FisuEvolutionApp.swift` (🔥) | 3 → F1-T5 (una línea) |
| `RootView.swift` (🔥) | 5 → F3-T6 (una línea) |
| `GameState.swift` (🔥) | **nadie** (todo va en extensiones nuevas; el contenido base lo guarda el servicio de F1) |
| `PlayerState.swift` (🔥) | **nadie** (el segmento no va al save) |
| `Localizable.xcstrings` (🔥) | **nadie** (snapshots) |
| `PacingProfile.swift`, `PacingSimulator*.swift` (EK) | 2 → F2-T2 · 4 → F3-T4 |
| `Tools/pacing-sim/*` | 3 → F2-T3 · 4 → F3-T4 (`SourcesLoader` sólo) |
| `FisuEvolutionTests/Support/PacingFixture.swift` | 5 → F2-T4 |
| `supabase/scripts/admin.sql`, `supabase/README.md` | 1 → F1-T3 · 2 → F1-T6 · 5 → F7-T2 |
| `GameState+Telemetry.swift`, `TelemetryEvent.swift` | 2 → F1-T6 |
| `GameState+Personalization.swift` (nuevo) | 3 → F1-T5 (lo crea) · 4 → F2-T7 (una llamada) |
| `DebugPanelView.swift` | 3 → F1-T5 |
| `GameState+RewardDouble.swift`, `RewardDouble.swift`, `RewardDoubleOffer.swift`, `GameState+AdOffers.swift`, `GameState+AdPlacements.swift` | 4 → F2-T6 |
| `GameState+Visitors/Treasures/SideRail` (no se tocan: F2-T7 transforma el contenido) | — |
| `ForcedAdsPacer.swift`, `GameState+Ads.swift` | 4 → F2-T8 |
| `GameState+FrameLoop.swift` | 4 → F3-T5 (una llamada) |
| `GameState+Moments.swift` (nuevo) | 4 → F3-T5 (lo crea) · 5 → F3-T7 |
| `GameState+OfferFunnel.swift` | 5 → F3-T7 (una llamada) |
| `OffersEngine.swift`, `OffersCatalog.swift` (EK) | 2 → F5-T1 |
| `GameState+Offers.swift`, `StoreView.swift`, hoja de oferta, `offers.json` | 4 → F5-T3 |
| `PrivacyInfo.xcprivacy`, `PrivacyManifestTests.swift` | 4 → F1-T7 |
| mapa de ubicaciones de video (`AdPlacementMapTests`) | 5 → F3-T6 |

## 4. Cola de despacho — por olas

> **Relevo 61 (2026-10-16):** olas 1–5 hechas, integradas y verificadas (ola 3 con la 2.0 final mergeada adentro); `version-2.1` =
> `15451961`. Verificación de la ola 5: EK 1253 · unit 2456+1 known issue · Release 0 · UI 6/6 · matriz C3 verde con y sin `--caps` ·
> SQL 67. Falta **F2-T5** (corre `pacing-sim` con habilitación) y la **ola 6**. Carries en las notas de F2-T4/F2-T5/F1-T7.

**BASE de la ola 1:** `version-2.1` (= `5b3d2cce` + los docs de `v21/plan`). Cada ola sale de la punta integrada de la
anterior. Despachar con `Agent(isolation: "worktree")` o worktree manual con ruta absoluta (ver `tasks.md` §4.2).

### Ola 1 — archivos nuevos y disjuntos (8)

| # | Tarea | Modelo | Nota |
|---|---|---|---|
| 1 | V21-F1-T1 `PlayerValue` (EK) | opus | contrato C1/C2 de F1 |
| 2 | V21-F1-T3 config remota en Supabase (sin aplicar) | opus | dueña de `admin.sql` en la ola |
| 3 | V21-F2-T1 `SegmentLevers` y topes (EK) | opus | `segments.json` en identidad |
| 4 | V21-F3-T1 detectores (EK) | opus | puro |
| 5 | V21-F3-T2 bandido Thompson (EK) | opus | semilla determinista |
| 6 | V21-F4-T1 `releaseops admob floors-plan` | sonnet | dry-run, Python |
| 7 | V21-F6-T1 evaluador de árboles (EK) | opus | fixture a mano |
| 8 | V21-F6-T3 scripts de entrenamiento | sonnet | Python, sin datos reales |

F2-T1 y F3-T1/T2 usan `PlayerSegment` de F1-T1: escribirlo contra el contrato C1 del plan de F1 (el tipo es de una
línea); integrar F1-T1 primero.

### Ola 2 (8)

F1-T2 (sonnet) · F1-T4 (opus) · F1-T6 (opus; dueña de `admin.sql`, `GameState+Telemetry`) · F2-T2 (opus; dueña del
sim) · F3-T3 (opus) · F5-T1 (opus) · F5-T2 (sonnet) · F6-T2 (opus).

### Ola 3 (4)

F1-T5 (opus; dueña de `FisuEvolutionApp`, `DebugPanelView`) · F2-T3 (sonnet; CLI) · F7-T1 (opus) · F7-T3 (opus).

### Ola 4 (7)

F1-T7 (opus) · F2-T6 (opus) · F2-T7 (opus) · F2-T8 (opus) · F3-T4 (opus; sim) · F3-T5 (opus; `FrameLoop`) ·
F5-T3 (opus).

### Ola 5 (5)

F2-T4 (opus; `PacingFixture`) · F2-T5 (opus; **corre `pacing-sim` sólo con la habilitación del controlador**) ·
F3-T6 (sonnet; `RootView`) · F3-T7 (opus) · F7-T2 (sonnet; `admin.sql`).

### Ola 6 — build único de la 2.1 (controlador)

F1-T8 · F2-T9 · F3-T8 · F5-T4, en un solo `completo` + `supabase/test.sh` + `pacing-sim --segment-matrix`; los rojos
se arreglan en el momento. Revisión opus del diff entero contra `version-2`.

### Después

🔒 F1-T9 (abogado, gate G7) · ⛔ datos: F4-T2, F4-T3, F6-T4, F6-T5, F7-T4.

## 5. Las fases

### F1 — VEJ v1 con reglas (`2026-10-16-v21-e15-f1.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F1-T1 | `PlayerValue` en EconomyKit: segmento, estimación, tablas con validación e histéresis | ✅ | — | EK `Personalization/*` (nuevos) | | opus + rev. opus · ola 1 |
| V21-F1-T2 | La tabla semilla `player_value.json` (tiers públicos de país, dispositivo por año) | ✅ | F1-T1 | `Resources/Config/player_value.json` (nuevo) | | sonnet + rev. opus · ola 2 · V5 |
| V21-F1-T3 | La config remota en Supabase, apagada y sin aplicar (`personalization_config()`) | ✅ | — | migración `…000001`, `06_personalization_test.sql`, `admin.sql`, `README` | | opus + rev. opus · ola 1 |
| V21-F1-T4 | Consentimiento TCF {1,5,6,8,9,10}, compuerta (con señal de menor) y cargador remoto | ✅ | F1-T1, F1-T3 | `Managers/Personalization/*` (nuevos) | | opus + rev. opus · ola 2 · V9, V10 |
| V21-F1-T5 | El servicio, `GameState.segment` y el evento `segment` | ✅ | F1-T2, F1-T4, F1-T6 | `FisuEvolutionApp` (1 línea), `DebugPanelView`, `GameState+Personalization` (nuevo) | | opus + rev. opus · ola 3 |
| V21-F1-T6 | Telemetría de la 2.1: `segment`, `exposure`, `progress`, `ctx` en `offer` (una migración nueva) | ✅ | F1-T3 (`admin.sql`) | `TelemetryEvent`, `GameState+Telemetry`, migración `…000002`, `admin.sql` | | opus + rev. opus · ola 2 · R4 |
| V21-F1-T7 | Privacidad de la personalización: borrador (6 bloques) y manifiesto | ✅ | F1-T4, F1-T6 | `privacidad-v21-BORRADOR.md` (nuevo), `PrivacyInfo.xcprivacy` | 75f46b60 | opus + rev. opus · ola 4 · 🔒 P3 después  · 5 decisiones abiertas del borrador para el dueño (🔒 P3)|
| V21-F1-T8 | Verificación de F1 (controlador): identidad con la 2.0, compuerta, SQL | ⛔ | F1-T1…T7 | integración | | controlador · ola 6 |
| V21-F1-T9 | Revisión legal antes de prender (gate G7) | 🔒 | F1-T7 | — | | **del dueño** (V11: hoy sin abogado; la personalización sale apagada) |

### F2 — Palancas por segmento (`2026-10-16-v21-e15-f2.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F2-T1 | `SegmentLevers` y sus topes en el código; `segments.json` en identidad | ✅ | F1-T1 (tipo) | EK `Personalization/SegmentLevers.swift`, `segments.json` (nuevos) | | opus + rev. opus · ola 1 |
| V21-F2-T2 | El simulador por segmento (`PacingSegment`, `acceptRate`) | ✅ | F2-T1 | `PacingProfile`, `PacingSimulator*` | | opus + rev. opus · ola 2 · R7 |
| V21-F2-T3 | `pacing-sim --segment` y `--segment-matrix` | ✅ | F2-T2 | `Tools/pacing-sim/*` | | sonnet · ola 3 |
| V21-F2-T4 | El contrato de ritmo por segmento en CI (G1) y el presupuesto de visitantes | ✅ | F2-T2, F2-T7, F3-T4 | `PacingFixture`, `SegmentPacingContractTests` (nuevo) | 65976aa6 | opus + rev. opus · ola 5 · V7  · C3.3 redefinido (high ≤ mid ≤ low): decisión para el dueño|
| V21-F2-T5 | Calibración de `segments.json` y de los topes por fuente (30 h con ×2,5 acotado) | ⏳ | F2-T3, F2-T4, F3-T4 | `segments.json`, `SegmentLevers.Caps` | | opus + rev. opus · ola 5 · corre `pacing-sim` con habilitación · 🔒 P2 · tabla a `balance-log.md`  · **Relevo 61:** lo único que falta de las olas 1–5; el presupuesto de visitantes y dos pares de C3.3 (low .ads 0,25 y high .ads 1 contra la base) están en `withKnownIssue` apuntando acá: con los topes high cobra ≈79 min/día contra ≈52,8 (multiplicador/escala ≤ ≈2,17), y C3.3 necesita tolerancia o más semillas (caos del sim, ±1 h)|
| V21-F2-T6 | El premio por video según el segmento, a la vista (paso 2 de B29) | ✅ | F2-T1, F1-T5 | `GameState+RewardDouble`, `RewardDouble`, `RewardDoubleOffer`, `+AdOffers`, `+AdPlacements` | 3a55c198 | opus + rev. opus · ola 4 · 🔒 P8 textos  · textos nuevos 🔒 P8|
| V21-F2-T7 | Los relojes de las ayudas (colchón, visitantes, costado) por transformación del contenido | ✅ | F2-T1, F1-T5 | `GameContent+Segment` (nuevo), `GameState+SegmentLevers` (nuevo), `GameState+Personalization` | c9c3661d | opus + rev. opus · ola 4 |
| V21-F2-T8 | Menos forzados para el segmento que mira videos | ✅ | F2-T1, F1-T5 | `ForcedAdsPacer`, `GameState+Ads` | 1bc4b4b3 | opus + rev. opus · ola 4 |
| V21-F2-T9 | Verificación de F2 (controlador): G1, G2, G4 | ⛔ | F2-T1…T8 | integración | | controlador · ola 6 |

### F3 — Momento justo (`2026-10-16-v21-e15-f3.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F3-T1 | Detectores de necesidad natural (EK) | ✅ | — | EK `Moments/*` (nuevos) | | opus + rev. sonnet · ola 1 |
| V21-F3-T2 | Bandido Thompson con semilla (EK) | ✅ | — | EK `Moments/ThompsonBandit.swift` (nuevo) | | opus + rev. opus · ola 1 |
| V21-F3-T3 | `MomentsConfig` con topes y el planificador | ✅ | F3-T1, F3-T2, F1-T1 | EK `Moments/*`, `moments.json` (nuevos) | | opus + rev. opus · ola 2 |
| V21-F3-T4 | Los momentos en el simulador (peor caso) | ✅ | F3-T3, F2-T2, F2-T3 | `PacingProfile`, `PacingSimulator+Sources`, `SourcesLoader` | 67ba78ee | opus + rev. opus · ola 4 |
| V21-F3-T5 | Los momentos en el juego (`GameState+Moments`, `exposure`, `ctx`) | ✅ | F3-T3, F1-T5, F1-T6 | `GameState+Moments` (nuevo), `GameState+FrameLoop` (1 llamada) | 947f4ff2 | opus + rev. opus · ola 4 · bloque `gifts` (V4/§3.7) |
| V21-F3-T6 | La tarjeta del momento, a la vista | ✅ | F3-T5 | `MomentOfferCard` (nuevo), `RootView` (1 línea), mapa de ubicaciones | b8d85e4b | sonnet + rev. opus · ola 5 · 🔒 P8 textos  · textos nuevos 🔒 P8|
| V21-F3-T7 | El bandido aprende (`BanditStore`, resultado desde el embudo) | ✅ | F3-T5 | `BanditStore` (nuevo), `GameState+OfferFunnel` (1 llamada), `GameState+Moments` | f3787cda | opus + rev. opus · ola 5 |
| V21-F3-T8 | Verificación de F3 (controlador) | ⛔ | F3-T1…T7 | integración | | controlador · ola 6 |

### F4 — Pisos por país (`2026-10-16-v21-e15-f4-f6-f7-andamiaje.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F4-T1 | `releaseops admob floors-plan` (dry-run, CSV opcional) | ✅ | — (contrato C2 de F1) | `Tools/releaseops/rocore/admob_floors.py` (nuevo), `releaseops.py` | | sonnet + rev. opus · ola 1 |
| V21-F4-T2 | Aplicar los pisos (receta manual con el CSV exportado a mano) | ⛔ | F4-T1, 2–4 semanas de la 2.0 | AdMob (UI, sesión del dueño) | | post-lanzamiento · V5, V6 |
| V21-F4-T3 | Medir el efecto de los pisos | ⛔ | F4-T2 + 2 semanas, F7-T1 | — | | post-lanzamiento |

### F5 — Tienda por segmento (`2026-10-16-v21-e15-f5.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F5-T1 | Audiencia por oferta (EK), `base` = 2.0 | ✅ | F1-T1 | `OffersCatalog`, `OffersEngine`, `OfferAudience` (nuevo) | | opus + rev. opus · ola 2 |
| V21-F5-T2 | El pack de blue destacado (EK) | ✅ | F1-T1 | `Shop/StoreRecommendation.swift` (nuevo) | | sonnet + rev. opus · ola 2 |
| V21-F5-T3 | Cableado, destaque y aviso «Oferta elegida para vos» en la UE | ✅ | F5-T1, F5-T2, F1-T5 | `GameState+Offers`, `offers.json`, `StoreView`, hoja de oferta, `OfferNotice` (nuevo) | 88841e75 | opus + rev. opus · ola 4 · V8 · 🔒 P8 textos  · textos nuevos 🔒 P8|
| V21-F5-T4 | Verificación de F5 (controlador): precios intactos, `asc diff` sin cambios | ⛔ | F5-T1…T3 | integración | | controlador · ola 6 |

### F6 — VEJ v2 con modelo (`2026-10-16-v21-e15-f4-f6-f7-andamiaje.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F6-T1 | Evaluador de árboles (EK) con fixture a mano | ✅ | — | EK `Personalization/TreeEnsemble.swift` (nuevo) | | opus + rev. opus · ola 1 |
| V21-F6-T2 | Features, camino v2 y reparto A/B (EK) | ✅ | F1-T1, F6-T1 | EK `Personalization/*` (nuevos) | | opus + rev. opus · ola 2 |
| V21-F6-T3 | Scripts de entrenamiento (`Tools/player-value-model/`) | ✅ | — | `Tools/player-value-model/*` (nuevos) | | sonnet + rev. opus · ola 1 |
| V21-F6-T4 | Entrenar el modelo real | ⛔ | R8 (miles de etiquetados), 🔒 P4, F1-T9 | — | | post-lanzamiento, datos |
| V21-F6-T5 | A/B 7–14 días y despliegue | ⛔ | F6-T4, F7-T1 | config remota | | post-lanzamiento · 🔒 P11 |

### F7 — Panel (`2026-10-16-v21-e15-f4-f6-f7-andamiaje.md`)

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| V21-F7-T1 | Vistas del panel (valor, embudo, retención, ritmo real) | ✅ | F1-T6 | migración `…000003`, `08_panel_test.sql` | | opus + rev. opus · ola 3 |
| V21-F7-T2 | Consultas del dueño (`admin.sql`) y `Tools/v21/panel.sh` | ✅ | F7-T1, F7-T3 | `admin.sql`, `README`, `Tools/v21/panel.sh` (nuevo) | 2a475f32 | sonnet + rev. opus · ola 5 |
| V21-F7-T3 | Priors del bandido y guardián de retención (sólo informan) | ✅ | F7-T1 (nombres) | migración `…000004`, `09_guards_test.sql` | | opus + rev. opus · ola 3 |
| V21-F7-T4 | Leer el panel y recalibrar (países, umbrales, priors, brazos, ritmo real) | ⛔ | datos (2–4 semanas prendida) | configs | | post-lanzamiento |

## 6. Gates humanos y 🔒 del dueño

| Gate | Qué hace el dueño | Bloquea | Estado |
|---|---|---|---|
| P2 | Aprobar los valores de `segments.json` y los topes por fuente de F2-T5 | prender F2 | 🔒 después de F2-T5 |
| P3 | Aprobar el borrador de privacidad/términos/ASC de la personalización (F1-T7) | prender F1–F5 | 🔒 después de F1-T7 |
| P4 | Aplicar las migraciones de la 2.1 en Supabase (`…000001`–`…000004`) | prender; F7 en producción | 🔒 después de la ola 6 |
| P5 | Prender `personalization_enabled` por etapas | todo lo visible | 🔒 **sólo después de F1-T9** (G7) |
| P8 | Aprobar los textos nuevos (momento, «×2,5 con video», avisos) | F2-T6, F3-T6, F5-T3 al integrar | 🔒 |
| P9 | Interruptor propio en Ajustes | — | default no (sin tarea) |
| P11 | Prender el modelo v2 | F6-T5 | 🔒 post-lanzamiento |
| F1-T9 | Revisión con abogado (V11) | **prender** (G7) | 🔒 cuando el dueño quiera |

## 7. Decisiones del dueño (no se vuelven a preguntar)

V1–V3 de la spec; **V4–V12 del 2026-10-16** en `Docs/v21/PLAN-v2.1.md` §0: sin MAX (V4); sin exportes de AdMob/ASC,
tabla semilla (V5); sin API ni OAuth de AdMob, pisos por receta manual (V6); piso 30 h con ×2,5 acotado por fuente
(V7); aviso «Oferta elegida para vos» en la UE (V8); TCF {1,5,6,8,9,10} para segmentar (V9); sin edad, señal de menor
→ base (V10); sin abogado por ahora, personalización apagada hasta F1-T9 (V11); corrección de 5.6 en la spec (V12).
Regla general: nada que implique pagar ni trámites que demoren la 2.0.
