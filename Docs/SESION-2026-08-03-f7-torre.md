# Sesión 2026-08-03 — F7 "La Torre"

## Mandato y alcance

El usuario pidió continuar sobre `main` y completar las fases pendientes de F7,
con registro de continuidad para poder retomar tras una interrupción. F7.1 ya
está cerrada en `432e6a5`; esta sesión comienza por F7.2 y seguirá, en orden,
F7.3 a F7.6 conforme a `Docs/PLAN-F7-torre.md`.

## Decisiones y restricciones vigentes

- Trabajar directamente sobre `main`, autorizado explícitamente por el usuario.
- Conservar el plan aprobado: torre data-driven, una escena SpriteKit persistente
  con `SKCameraNode`, gestos que no interfieren con personajes, y UI pequeña
  vectorial alineada con la paleta y componentes existentes.
- Añadir pruebas antes de cada cambio de comportamiento y verificar build/tests
  al terminar cada fase.
- Actualizar este archivo y el handoff con los cambios, decisiones y comandos de
  verificación relevantes.

## Línea de base (2026-08-03)

- `graphify update .`: no ejecutable; `graphify` no está instalado en este
  entorno. Navegación temporal por los símbolos y las relaciones documentadas.
- `cd Packages/EconomyKit && swift test`: **126 tests pasaron**. Requirió acceso
  local ampliado para que Swift pudiera usar su caché de módulos.
- Build de app: `xcodebuild -scheme FisuEvolution -sdk iphonesimulator
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'
  -derivedDataPath build/DD build`: **BUILD SUCCEEDED**. También necesitó acceso
  local ampliado para CoreSimulator y cachés de Xcode.

## Próximo hito: F7.2

1. Mapear `BoardScene`, `GameState`, `GameBoardView`, HUD y nodos de personaje.
2. Añadir cobertura de la proyección/navegación que no requiera SpriteKit visual.
3. Implementar cámara, `FloorNode`, rango vivo ±1, navegación con swipe/flechas,
   pill accesible e income total de la torre.
4. Compilar, ejecutar tests de app, verificar en simulador con capturas, y dejar
   el commit/documentación de fase.

## F7.2 — cerrado

- Se agregó a `GameState` la proyección `TowerNavigation` (piso, ordinal,
  capacidad, ocupación y límites desbloqueados), `moveVisibleFloor(by:)` e
  income pasivo agregado de toda la torre. La UI no accede a `PlayerState` ni
  a `TowerState` para estos datos.
- TDD: se añadió `towerNavigationProjectsUnlockedBoundsAndTotalIncome` a
  `GameLoopWiringTests`. Inicialmente falló porque el contrato no existía; luego
  reveló y cubrió el caso de income menor que 1/s, que no puede presentarse como
  `0` en el HUD.
- `BoardScene` ahora mantiene un `SKCameraNode`; el fondo/campo se ubican a la
  altura del piso visible y la cámara hace una transición corta (sin animación
  con Reduce Motion). Flash, scrim, foto y textos del reveal viven bajo un
  overlay de cámara. Un swipe vertical sobre espacio vacío navega un solo piso;
  tocar un personaje mantiene el pipeline tap/drag/long-press.
- `HUDView` muestra flechas accesibles (`tower.arrow.up`, `tower.arrow.down`) y
  pill (`tower.pill`) con piso, ocupación e income total. Una primera captura
  reveló que poner la pill en la fila principal recortaba los botones laterales;
  se movió a una segunda fila.
- `FloorNode` nuevo concentra el fondo aspect-fill y su fallback por piso. La
  escena conserva sólo visible ±1; al desalojar, primero materializa las claves
  viejas para no mutar el `Dictionary` durante su enumeración. El render cachea
  el tamaño para no reinstalar texturas durante los ticks de HUD.
- El resultado de merge ahora transporta el `promotedType` de forma explícita.
  `BoardScene` toma una coordenada mundial antes de relayout y anima una unidad
  temporal del pool hacia arriba durante 0.7 s, con partículas y
  `fx_evolution_flash`; la respeta Reduce Motion y la devuelve al pool.
- Se agregaron los once nombres de piso y las etiquetas accesibles de navegación
  en `Localizable.xcstrings` (es/en). Una primera implementación generó la clave
  en pantalla porque `LocalizedStringKey` no admite interpolación dinámica; se
  corrigió con un mapeo exhaustivo de claves estáticas.
- Verificación intermedia: tras crear `FloorNode.swift`, el build falló porque el
  proyecto generado no lo incluía. Se ejecutó `/opt/homebrew/bin/xcodegen
  generate` (la fuente de verdad es `project.yml`) y luego el build Debug terminó
  con **BUILD SUCCEEDED**, warnings-as-errors activos.
- Tests verificados con bundles aislados: `GameLoopWiringTests` pasó **11/11**
  (incluye proyección/income y promoción con `promotedType`), y
  `LaunchSmokeTests` pasó **3/3**. Este último cubre HUD/pill/flechas bloqueadas
  en partida nueva y, con el fixture DEBUG `--uitest-unlock-tower`, una flecha
  arriba seguida de un drag vertical sobre espacio vacío que vuelve al piso
  inicial. El fixture vive sólo en `#if DEBUG` y desbloquea por `FloorTable`, no
  por ids hardcodeados.
- Dos fallas de compilación de tests quedaron corregidas y explicadas: el helper
  asumió erróneamente que `ordinal(forTier:)` era opcional, y
  `XCUICoordinate.swipeDown()` no existe en iOS; se usa
  `press(forDuration:thenDragTo:)`. `xcresulttool` puede dar `FileSystemError:3`
  si se lo consulta inmediatamente al finalizar xcodebuild; el segundo intento
  leyó el bundle correcto.
- QA visual: la captura persistente
  `scratchpad/qa-shots/F7.2-navigator.png` muestra Alley, la pill, ambos límites
  de navegación y la flecha superior habilitada en el fixture; el overlay DEBUG
  marca **60 fps**. Una captura previa de Corporate con vecinos vivos marcó 56
  fps durante transición/carga (`/private/tmp/f7-2-floor-stable.png`).
- Gate final: `swift test` de EconomyKit terminó **126/126**; la suite completa
  de la app terminó **66/66** en iPhone 16 (bundle
  `/private/tmp/f7-2-app-full.xcresult`). La lectura del bundle puede fallar
  transitoriamente con `FileSystemError:3`; reintentar luego de unos segundos
  devolvió `result: Passed`.

## Próximo hito: F7.3

Implementar solamente la UX que todavía falta sobre la lógica F7.1 ya existente:
estado de contratación bloqueada/llena, toast de destino lleno, celebración del
primer unlock con foco de cámara y los pasos de tutorial para torre/ascenso.

## Progreso F7.3 (en curso)

- Ajuste pedido el 2026-08-04: el primer Fisura vuelve a costar **50** (override
  `alley.hireCostMultiplier`); se actualizó el test anti-drift del contenido y
  quedó en el commit aislado `99af8dd`. `GameContentValidationTests` confirmó
  **9/9**. El simulador de 90 días registró urban en **5.8 min activos** y primera
  reencarnación en **0.26 h** (frente a los targets históricos 14–39 min y
  2.8–7.8 h); Dios sigue en **33.20 h**. No se tocaron más knobs: el cambio fue
  explícitamente pedido y la recalibración deliberada queda para F7.6. El detalle
  reproducible vive en `Docs/balance-log.md`.

- `GameState` ya expone `visibleFloorIsFull`, `visibleFloorIsUnlocked` y el
  mensaje efímero tipado `TowerNotice`. `buySpawn()` publica `.floorFull` y un
  ascenso que EconomyKit bloquea por capacidad publica
  `.destinationFloorFull(floorID:)`, sin convertir `TowerError` en texto dentro
  de la lógica.
- `SpawnButtonView` presenta el estado lleno/bloqueado con el patrón legible
  existente (ink + desaturación, no `.disabled`), y `RootView` muestra un toast
  accesible que se autocierra o se puede tocar. Quedaron añadidas sus claves
  es/en al catálogo.
- TDD: `destinationFullMergePublishesTowerNotice` llena luxury mediante los
  helpers DEBUG existentes, prueba que el merge sigue en `.snapBack`, verifica
  el aviso con id de piso data-driven y que se descarta por id.
- Dos errores de compilación ya corregidos durante esta subfase: faltaba
  `import EconomyKit` para `HireQuote` y un modificador `.font` había quedado
  fuera de un `@ViewBuilder`; se envolvió en `Group`. El test de wiring se lanzó
  en `/private/tmp/f7-3-wiring-fixed.xcresult`; reintentar `xcresulttool` si el
  lector devuelve inicialmente `FileSystemError:3`; el reintento confirmó
  `GameLoopWiringTests` **12/12** verde.
- `BoardScene` ahora consume `unlockedFloorId` sólo para el primer ascenso: el
  clon termina su vuelo, aparece `¡PISO NUEVO!`, se dispara haptic de rareza y
  la cámara enfoca el destino. Las promociones a pisos ya abiertos no mueven la
  cámara. Build Debug posterior verde con warnings-as-errors.
- `TutorialOverlay` pasó de cinco a siete pasos: mantiene tap/merge/contratar/
  mejoras y suma torre + ascenso. Todos los textos de tutorial que estaban
  hardcodeados migraron al catálogo es/en, incluido Saltar y tocar para seguir.
- Se cerró la brecha de navegación que hacía inalcanzable la UX bloqueada: la
  torre deja mirar **sólo el próximo** piso todavía cerrado. `BoardScene` pinta
  allí scrim, candado vectorial y hint localizado; no hay contratación ni salto
  a un segundo piso. El contrato está en `towerNavigationProjectsUnlockedBounds…`.
- QA reciente: `GameLoopWiringTests` **13/13** (incluye T2→T3→Urban) y
  `LaunchSmokeTests` **4/4** en iPhone 16. La captura del preview bloqueado se
  conserva en `scratchpad/qa-shots/F7.3-locked-floor-preview.png`, extraída del
  smoke y con 60 fps. Una automatización adicional del drag exacto T2→T3 se
  descartó en vez de commitear una prueba frágil: el runner mapea distinto las
  coordenadas visuales de SpriteKit. La transición sigue cubierta por el wiring
  test y por el código de escena; si se requiere esa captura puntual, retomar
  desde install limpio o exponer nodos de SpriteKit con a11y determinista.
- Gate de fase: la suite completa terminó **67/67 verde** en iPhone 16 (bundle
  `/private/tmp/f7-3-app-full.xcresult`) antes de `99af8dd`; `xcresulttool`
  requirió reintentos por su `FileSystemError:3` transitorio. Tras el ajuste de
  precio, no se debe interpretar un fallo de `PacingTests` contra sus bandas
  F7.1 como una regresión accidental: la decisión de precio la contradice y está
  asentada arriba. F7.3 quedó aislada en `42d778e` (`F7.3: mejorar UX de
  contratación y desbloqueo`); el siguiente paso es F7.4.

## F7.4 — ORO, mejoras y reencarnación (cerrado, pendiente de commit)

- Línea de base revisada: el modelo ya separa correctamente `run.charUpgradeLevels`
  y `meta.oroUpgradeLevels`; `CharUpgrades` ya aplica ×2 por nivel en tap e income.
  La deuda es de orquestación/UI: `UpgradeManager.purchase` todavía cobra
  `run.coins`, `UpgradesView` es una sola lista y `PrestigeView` conserva nombres
  de soul points. F7.4 debe mover las siete líneas permanentes a ORO, exponer la
  compra de mejoras por personaje y traducir la superficie de reencarnación.
- `upgrades.json` pasó a schema v2 y declara `currency:"oro"`
  (bases 1–5, growth 2.0–3.0). `UpgradesConfig.Line` usa `decodeIfPresent` con
  fallback `.coins` para catálogos v1, mientras que `UpgradeManager` ahora debita
  ORO entero sin tocar `run.coins`. `ContentSystemsTests` verificó el contrato:
  compra + efecto, monedas intactas, insuficiencia de ORO y máximo; **16/16**
  verdes en `/private/tmp/f7-4-oro-core.xcresult`.
- La vista de mejoras se dividió en las pestañas vectoriales Personajes y
  Permanentes. La primera lista sólo tipos que existen en la run (o que tenían
  nivel) y compra con monedas; la segunda muestra las siete líneas del catálogo,
  saldo ORO y compra con `meta.oro`. Las acciones tienen IDs estables
  `upgrades.character.<type>` y `upgrades.permanent.<line>`.
- `PrestigeView` pasó a Reencarnación: nombra el ORO ganado y hace explícito qué
  se pierde (run) y qué se conserva (meta). Se renombró la proyección UI a
  `prestigeOroGained`; `OroIcon` vectorial evita introducir un PNG provisional.
- Verificación final de F7.4: `GameLoopWiringTests` **13/13**
  (`/private/tmp/f7-4-wiring-final.xcresult`) confirma que una mejora de Fisura
  consume monedas y vuelve a nivel 0 después de reencarnar; smoke UI **5/5**
  (`/private/tmp/f7-4-ui-final.xcresult`) comprueba HUD → Permanentes → compra
  ORO. La captura inspeccionada está en
  `scratchpad/qa-shots/F7.4-upgrades-permanent.png`.
- El reintento de `xcresulttool` tras 10–30 s sigue siendo necesario cuando
  Xcode entrega primero un bundle `Staging` sin metadata. No se ejecutó Pacing
  como gate verde: el cambio solicitado de Fisura a 50 lo deja deliberadamente
  fuera de las bandas F7.1 hasta la recalibración F7.6.

## Próximo hito: F7.5 — skins + ficha

- Implementar catálogo `skins.json`, modelo y resolución data-driven en
  EconomyKit, y reemplazar `PassiveUnlockView` por la ficha con selección de
  skin, pasivo y despedida confirmada. Mantener el registro de TDD, capturas y
  verificaciones en esta misma bitácora.

## F7.5 — skins y ficha (en curso; worktree sin commit)

- TDD primero: `SkinMilestonesTests` nació en rojo por faltar el modelo y quedó
  **2/2 verde** con `SkinsConfig` + `SkinMilestones` puros en EconomyKit. El
  catálogo `Resources/Config/skins.json` declara los tres tintes IAP globales
  y dos skins de milestone por tipo (`urban_trailblazer`, `second_life`). El
  loader lo valida contra tipos y pisos reales.
- Otro contrato en rojo fijó que resolver una skin sea data-driven y scoped al
  tipo. `SkinResolver` ahora retorna `.base/.tint(hex:)/.texture(key:)`, sin IDs
  hardcodeados; la escena calcula la apariencia unidad por unidad. Una textura
  de skin no existente cae a la textura base sin mostrar un placeholder roto.
  `GameContentValidationTests` quedó **11/11 verde** en
  `/private/tmp/f7-5-resolver-green.xcresult`.
- `updateMaxFloorStat()` acredita skins de milestone de forma idempotente y
  separada de StoreKit. `tier2MergePromotesToUrbanAndUnlocksIt` ahora prueba
  también `urban_trailblazer`; wiring **13/13 verde** en
  `/private/tmp/f7-5-milestone-green.xcresult`.
- La selección por ficha se agregó con `activeSkinID(forCharacterType:)` y
  `equipSkin(id:forCharacterType:)`: exige propiedad + compatibilidad de
  catálogo, no altera otros tipos y sobrevive una reencarnación. TDD de ese
  ciclo: wiring **14/14 verde** en `/private/tmp/f7-5-sheet-green.xcresult`.
- `CharacterSheetView` reemplaza (y elimina) `PassiveUnlockView`: long-press
  abre retrato, pager de apariencia, pasivo y despedida destructiva confirmada.
  `UIArt` tiene caché `atlas/key` para retratos y la ficha puede iniciar una
  compra IAP del skin bloqueado. La integración compiló y repitió wiring
  **14/14 verde** en `/private/tmp/f7-5-character-sheet-2.xcresult`.
  Al borrar/agregar los Swift fue necesario `xcodegen generate`; el proyecto
  generado conservaba `PassiveUnlockView.swift` como input y el build falló
  hasta regenerarlo.
- Estado exacto al interrumpir: cambios **sin stage y sin commit** de F7.5 en
  `GameState`, loader, resolver, escena, renderer, UIArt, RootView, strings,
  tests; nuevos `skins.json`, `SkinsConfig.swift`, `SkinMilestonesTests.swift`
  y `CharacterSheetView.swift`; borrado `PassiveUnlockView.swift`. Falta QA
  visual/UI screenshot de la ficha, fallback visual de retrato texture ausente,
  retirar el CTA global viejo de Store, celebración de milestone gateada por
  tutorial, y el visual de specials anclados. Después ejecutar suites finales y
  documentar/commitear. Pacing no debe usarse como gate verde: sigue fuera de
  rango por Fisura=50 y se arregla deliberadamente en F7.6.

---

## Sesión 2026-08-04 (madrugada-mañana) — cierre de F7 + skins

### F7.5 cerrada (`05a3e24`)

Los cinco pendientes que el handoff dejaba anotados, verificados contra el
código y no contra la bitácora:

1. **Fallback del retrato**: la ficha caía al SF Symbol `person.fill` cuando
   faltaba el arte de una skin; ahora cae al retrato base, mismo criterio que el
   tablero (`PlaceholderRenderer`).
2. **CTA legacy del Store**: `StoreView` seguía equipando con `setActiveSkin`,
   que aplicaba la skin a TODOS los tipos y competía con la selección por tipo de
   la ficha. La tienda ahora vende y apunta a la ficha; murieron
   `GameState.setActiveSkin` y la proyección `activeSkin`.
3. **Celebración de milestone**: `awardEligibleMilestoneSkins` sólo logueaba.
   Se publica `skinAward` y `SkinAwardView` la presenta gateada por tutorial. Se
   celebra UNA por tanda: encadenar popups interrumpe el loop.
4. **Specials anclados**: `meta.specialAnchors` se escribía desde F7.1 y no lo
   leía nadie. `visibleFloorSpecials` + render en `BoardScene` (decorado, sin
   slot, no interactivo).
5. **Smoke UI de la ficha**: fixture `--uitest-open-sheet` en vez de long-press
   sobre SpriteKit, que no da coordenadas estables en el runner.

**Bug encontrado en la QA visual** (el motivo por el que la QA con screenshot no
es opcional): `character.count` y `character.skin.index` se veían como claves
crudas en pantalla. Están declaradas con `%@` pero el código interpolaba `Int`,
que SwiftUI convierte a `%lld`, y el lookup fallaba. Se pasan como `String`,
igual que `passive.explainer`. Un barrido sobre el resto de las claves no
encontró más casos.

### F7.6 cerrada (`e7021c2`)

- **Balance**: el dueño eligió conservar el primer Fisura a 50 y BAJAR los
  targets. Queda registrado en `Docs/balance-log.md §F7.6` con la tabla de lo que
  cuesta: fase fisura de 16.2 → **5.8 min**, 1ª reencarnación de 4.0 → **0.26 h**.
  Dios (33.2 h) y reencarnaciones (13) siguen en banda. `economy.json` intacto,
  así que el grid search de 6 knobs no se hizo. `pacing-sim` gana `--csv` y
  sigue imprimiendo los targets de DISEÑO para que la brecha se vea.
- **Drill de extensibilidad** (nuevo, no existía): piso 12 + personaje + skin
  declarados sólo como datos. Encontró de entrada una cobertura de tiers
  inconsistente en su propio fixture, que es exactamente para lo que sirve.
- **Drill de remapeo**: se agregó el caso `unlockTier` corrido que pedía el spec
  §7 y no estaba cubierto.
- **Polish**: el ascenso era indistinguible de un merge (ahora tiene acento
  propio), al desbloqueo de piso le faltaba SFX y a la reencarnación háptica.
  Reduce Motion ya cubría cámara, vuelo, reveal, celebración y wander; los
  micro-rebotes de <150 ms de manipulación directa se dejaron a propósito.

### Skins: expansión de alcance (`de16870`, `3d5a1a2`)

El §9 del spec ponía el **arte** de skins nuevas fuera de alcance (entraba el
sistema; el catálogo podía shippear con arte pendiente gracias al fallback). El
dueño pidió generarlo: **una skin por personaje, 36**.

**Pipeline** — tres cambios, con tests (17/17):
1. El runner leía el campo `**referencia**` del `.md` como un booleano y
   adjuntaba SIEMPRE `fisura.png`. Con 93 assets del mismo personaje base daba
   igual; con skins no: cada una necesita a SU personaje como referencia de
   estilo. Ahora el path del `.md` manda, y la caché de huella se indexa por path.
2. `--ref-threshold`: con la referencia siendo el MISMO personaje, el filtro
   anti-falsos-positivos puede descartar la skin legítima. Para skins va en ~5.
3. `process_dropbox` gana la categoría `skin`: deja el PNG en el atlas del
   personaje base y NO escribe el manifest (meterlo ahí rompería
   `manifestEntriesReferenceRealTypes`). La key se arma con `skin_asset_key`
   porque la convención es `<char>_idle__<skin>`, con el `__` DESPUÉS de `_idle`.

**Prompts**: 36 generados desde `cultural_dict` (`gen_skin_prompts.py`). Cada
skin conserva pose, cara y expresión y cambia sólo vestuario, props y paleta,
con cambio cromático fuerte pedido explícitamente — además de diseño, es lo que
evita que el filtro de huella la confunda con la referencia. Más el icono ORO.

**Catálogo**: 39 entradas con `displayNameKey` (estaba en el modelo del spec
§3.9 y nunca se había implementado) y 39 nombres es/en. La condición de
desbloqueo dejó de interpolar el id crudo del piso; `TowerNaming` se extrajo del
HUD porque ahora lo usan dos superficies.

### ⛔ Bloqueo: el arte no se generó

El batch se frenó con **"Gemini alcanzó su límite de uso"** (dos intentos,
registrados en `state/selenium-run.json`). No es un bug del pipeline: el
circuito quedó armado y probado. El comando exacto para retomar está al tope de
`Docs/HANDOFF-F7-estado.md`. El juego funciona hoy sin ese arte: las 36 skins
caen a la textura base, contrato cubierto por
`missingSkinArtFallsBackToTheBaseTexture`.
