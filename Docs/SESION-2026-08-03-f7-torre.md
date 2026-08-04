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
