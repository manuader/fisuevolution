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
