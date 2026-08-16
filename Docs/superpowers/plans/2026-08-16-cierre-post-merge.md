# Cierre post-merge del rediseño de UI — plan de implementación

> **Contexto.** El rediseño de UI (20 tareas + review integral + ola de fixes)
> ya está mergeado a `main` (`89f215a`). Este plan ejecuta lo que ese cierre
> dejó explícitamente triageado para después del merge: la integración del
> calendario del daily que quedó en la rama paralela `fix/iconos-gameicon`,
> el ticket post-merge que el review integral consolidó (cluster spawn muerto,
> StatePill→StateBadge, pase a11y en lote, residuales de la ola), y el intento
> de recuperar `AscentRenderingUITests`. Fuente del triage: el ledger del plan
> anterior (`.superpowers/sdd/2026-08-14-rediseno-ui-cowevolution/progress.md`)
> y `Docs/SESION-2026-08-14-rediseno-ui.md`.
>
> Rama de trabajo: `fix/cierre-post-merge` desde `main`. Tareas SECUENCIALES,
> un implementador por vez (comparten UpgradesView, StoreView, xcstrings).

## Global Constraints (aplican a TODAS las tareas)

- **Regla visual del dueño**: FisuJobs (`FisuEvolution/UI/Jobs/FisuJobsView.swift`)
  es la referencia canónica. Gramática: `GameCard`/`PricePill`/`ProgressBar`,
  paleta sólo `Palette*`, tipografía sólo `Tokens.*`, cabecera crema opaca,
  `ArtCloseButton`. Ninguna tarea introduce una gramática nueva.
- **Cero warnings** (`SWIFT_TREAT_WARNINGS_AS_ERRORS`). Si se agrega o borra un
  `.swift`: `/opt/homebrew/bin/xcodegen generate` obligatorio.
- **Strings nuevos** a `FisuEvolution/Resources/Localizable.xcstrings` (es+en)
  **en el mismo commit que su vista**. El catálogo NO se edita con scripts.
- **Accesibilidad**: identifier en todo control interactivo; JAMÁS un
  identifier en un contenedor que no es elemento de AX (se propaga y pisa a
  los hijos); fila informativa = una parada (patrón T8: `accessibilityHidden`
  en info/badge, nunca en el control).
- **Verificación**: simulador PROPIO creado por UDID, `-parallel-testing-enabled NO`,
  unit ANTES que UI, `-skip-testing:FisuEvolutionUITests/AscentRenderingUITests`
  (salvo la Task 6, que es sobre ese test), y **borrar el simulador al terminar**.
- **Commits en español, atómicos.**
- **Decisiones que no se re-litigan**: `Docs/HANDOFF.md` §5 y el bloque
  "Decisiones del dueño" de `Docs/SESION-2026-08-14-rediseno-ui.md`.
- Baseline de suites al arrancar este plan: EconomyKit **182** · app **342** ·
  UI **40/40** (con el skip de Ascent) · cero warnings.

## FASE 1 — Integración pendiente

### Task 1: Integrar el calendario del daily (cherry-pick de `84a2af6`)

La rama paralela `fix/iconos-gameicon` (nace de `d9f9a9d`) resolvió el único
call-site pendiente de los 15 iconos de T19: `ui_daily_calendar`. Su commit
`84a2af6` pone el icono al frente de la tarjeta del daily en
`FisuEvolution/UI/Gifts/GiftsView.swift` vía `GameIcon(artKey:)` a 44 pt en un
plato de 56 (mismo encuadre que `BoostGlyph`/`ScreenGlyph`) y reacomoda la nota
"se cobra solo" al costado, alineada a la izquierda con tres renglones.

- `git cherry-pick 84a2af6` sobre la rama de trabajo. Verificado por el
  controller: auto-mergea limpio contra el `GiftsView` post-ola.
- **NO** se toman los otros dos commits de esa rama: `c361d4d` (trofeos por
  `GameIcon`) es redundante — la ola del review ya cableó
  `AchievementsView:213` y `RootView:395` con `GameIcon(artKey: "ui_trophy_\(tier.rawValue)")`
  — y `73a1f19` es un doc de sesión superado por el de `main`.
- El cambio NUNCA pasó por el pipeline de review — el gate de esta tarea es su
  review real: build verde, tests de la zona (`DailyCalendarTests`, UI de
  Regalos si existe), y coherencia visual con la regla de FisuJobs (el plato de
  56 y el ritmo de las tres secciones de la pantalla).
- Antes del batch de iconos el atlas no tiene `ui_daily_calendar`: `GameIcon`
  cae al vectorial (`VectorCalendarIcon`) y eso es lo esperado. Verificar que
  el fallback dibuja (captura o test de render si ya existe patrón).

## FASE 2 — El ticket post-merge

### Task 2: Retirar el cluster spawn muerto de GameState

El botón de spawn murió en T7 y `ConfigView` en T16; su proyección quedó viva
sin consumidores de UI (verificado por grep: sólo GameState y tests).

- Borrar de `FisuEvolution/Game/State/GameState.swift`: `enum HireOffer`
  (:103), `showSpawnHint` (:211), `hireOffer` (:245), y el cálculo que los
  refresca (:733-742 y :786). Si `refreshProjections` queda con trabajo
  muerto alrededor, retirarlo también.
- ⚠️ **Los pins NO se pierden**: `GameLoopWiringTests.swift:230-284` usa
  `gameState.hireOffer` para pinear la semántica del gate y el fallback
  (urbano exento → `.here`; `floorBelow(floorID: "urban")`; `.full(belowFloorID:)`).
  Esa conducta vive en `TowerActions.hireTargetFloor`/`canHire` (EconomyKit) y
  sigue siendo la del juego real (FisuJobs contrata por tipo encima de ese
  gate). Migrar esos tests para pinear la MISMA conducta contra la capa real
  (TowerActions directo, o el camino de contratación que FisuJobs consume) —
  ninguna aserción de conducta desaparece, sólo cambia el punto de lectura.
- No hay claves de catálogo huérfanas de este cluster (`spawn.*` ya no está;
  verificado). No hay `.swift` que borrar entero, así que no hace falta
  xcodegen.

### Task 3: Unificar StatePill→StateBadge en Upgrades

`UpgradesView.swift:459` declara una `StatePill` privada usada en :259 y :395;
duplica el rol del `StateBadge` compartido (`GameArtComponents.swift:441`).
Precedente ya ejecutado: T11 unificó `JobStateBadge`→`StateBadge`
booleano-por-booleano.

- Reemplazar los usos por `StateBadge` conservando el texto y el estado visual
  actual de cada caso ("Ya genera" / "Al máximo").
- Incluye el minor diferido de T9: la `StatePill` de hoy dispara
  haptic+audio de error al tocarla (llama a `buy*` que rechaza). El reemplazo
  no debe ser interactivo (o silencia la acción) — tocarla no castiga.
- Deben seguir verdes los pineados: `UpgradesMenuTests`, `UpgradeRowTextTests`,
  `UpgradesFaceUITests`, `UpgradesMenuUITests` (VoiceOver: el nombre se dice
  UNA vez, en el retrato).

### Task 4: Pase de accesibilidad en lote

Los diferidos a11y del ledger del plan anterior, en una sola pasada:

- `PricePill` se anuncia sólo con el monto — sin moneda ni qué compra
  (T4/T9). Resolver a nivel componente (parámetro de label) o call-site;
  afecta FisuJobs, Upgrades, Tienda y Regalos. Claves nuevas es+en si hacen
  falta.
- `ProgressBar` expone `value` sin label (T4).
- `UpgradesView`: los 7 glifos de la pestaña permanente son paradas MUDAS de
  VoiceOver (T9) — `accessibilityHidden` según el patrón T8.
- FisuJobs: `axLabel` repite el piso en filas `.lockedFloor` — label y value
  lo nombran (T8); condicionar el append.
- Upgrades: texto de efecto `lineLimit(2)` sin `minimumScaleFactor` (T9) —
  puede truncar con Dynamic Type grande.
- `ElevatorView`: número de piso `.system(17)` (~:232) y `herePill`
  `.system(10)` (~:285) sin `Tokens.*` (T10) — no escalan con Dynamic Type.
- **Decisión del controller (no re-abrir):** los dos modelos de navegación AX
  (FisuJobs fila-colapsada vs Upgrades multi-parada) se QUEDAN como están —
  son formas de pantalla distintas y ambas deliberadas. El pase es de labels,
  glifos mudos y escalado, no de re-arquitectura.
- Los pins de AX existentes siguen verdes (patrón T8 en FisuJobs, retrato en
  Upgrades).

### Task 5: Residuales de la ola del review

- `StoreView.swift:268` — `centeredInPanel` no resta el `errorBanner` en
  `.failed`: tarjeta descentrada + scroll corto en esa combinación
  (call-sites :63-72).
- Títulos de productos que parten ("Puñado / de Plata"): el riel de la tienda
  no tiene ancho fijo (T12; FisuJobs usa `railWidth = 96`) — dar rail fijo o
  aire + `minimumScaleFactor` para que el título no se quiebre.
- EconomyKit `PlayerState.swift:343` — `MetaState.init(from:)` hard-decodea
  `derivedEffects`: pasar a `decodeIfPresent` con default neutro + test de
  decode del sobre sin esa clave.
- Falta un test end-to-end del migrador: los fixtures decodifican
  `PlayerState` directo. Agregar un test que corra `SaveMigrator` sobre un
  blob JSON crudo (v3 → v4) de punta a punta.
- `assets_manifest.json:546` — `ui_pill_currency` huérfano (la `CurrencyPill`
  murió en la ola): sacar la entrada. ⚠️ La cola de iconos 213-227 NO lo
  incluye (verificado); el prompt 113 es historia de otra tanda y NO se toca.
- ⚠️ `offlineEfficiency` default 0 en un v3 roto: trade-off ya aceptado y
  documentado — NO tocar.

## FASE 3 — Recuperar el test rojo de main

### Task 6: AscentRenderingUITests — correrlo tal cual, y recién ahí decidir

`AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent` está
rojo en `main` desde antes del rediseño y se saltea en todas las corridas. El
diagnóstico que lo condenó (drag por coordenadas contra un personaje que
deambula, drop resuelto contra el ancla) se ARREGLÓ el 2026-08-10 (fusión
asistida: `MergeTargeting.dropTarget` mide contra posiciones reales, y existe
el doble toque) — y nadie lo volvió a correr (HANDOFF trampa 2).

- **Primero correrlo SIN tocar nada**, solo, en un simulador propio por UDID.
- Si pasa: quitar el `-skip-testing:` de las recetas (HANDOFF §6) y anotar el
  baseline nuevo (41 de UI). Correrlo dos veces más para no bendecir un flaky.
- Si sigue rojo: migrar el arrastre a doble toque como se hizo con
  `mergeTheHighlightedPair`, asertando el EFECTO (el ascenso ocurre y los
  personajes siguen visibles), no el gesto. ⚠️ El test hoy tapea `sheet.close`
  sin guarda (~:150, migrado a ciegas en T7 del plan anterior).
- El resultado (verde des-skippeado, o migrado y verde) actualiza HANDOFF §6
  y la trampa 2 en el MISMO commit.

## FASE 4 — Verificación y cierre

### Task 7: Suite completa, docs y push

- Las cuatro suites ENTERAS según `Docs/HANDOFF.md` §6: EconomyKit (`swift
  test`), unit ANTES que UI, pipeline de assets. Cero warnings. Baseline
  esperado: EconomyKit 182+ · app 342+ · UI 40-41/41.
- Actualizar `Docs/HANDOFF.md` y `Docs/SESION-2026-08-14-rediseno-ui.md`: el
  ticket post-merge ya no está pendiente, el calendario aterrizó, el estado de
  Ascent, y qué queda (batch de iconos + gates F6).
- El merge a `main` y el push a `origin` los hace el controller al cerrar
  (trampa 7: `origin/main` está 65 commits atrás — el push es parte del
  cierre).
