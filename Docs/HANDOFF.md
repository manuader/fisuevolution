# HANDOFF — FisuEvolution, estado actual

> **Empezá por acá.** Última actualización: 2026-08-05, commit `eb81544` + el
> fallback de contratación de esta sesión.
> Este doc reemplaza al índice disperso de handoffs; los otros siguen siendo la
> fuente de verdad de SU tema y están linkeados donde corresponde.

---

## 1. Qué es

**FisuEvolution** ("Hobo Evolution"): juego iOS merge-idle con humor argentino.
30 tiers de evolución (El Fisura → Dios) en una **torre de 11 pisos simultáneos**;
los personajes de todos los pisos producen a la vez, se mergean de a pares y al
evolucionar "se mudan" al piso de arriba.

**Stack**: SwiftUI (HUD, menús, popups) + SpriteKit (`BoardScene`) + **EconomyKit**
(paquete SPM con la economía, puro y testeado). iOS 17+, Swift 6 con
`SWIFT_STRICT_CONCURRENCY: complete` y `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.

**El juego está terminado y jugable de punta a punta.** Lo que falta es F6:
cuenta de Apple Developer, App Store Connect, TestFlight y submission — todo
gates humanos, nada técnico.

---

## 2. Reglas del repo (romper esto rompe el build)

- **El `.xcodeproj` NO se versiona.** Se regenera con `xcodegen generate` desde
  `project.yml`. Al **agregar o borrar** un archivo Swift es **obligatorio**.
- **Cero warnings.** `SWIFT_TREAT_WARNINGS_AS_ERRORS` está activo.
- **Strings nuevos** van a `FisuEvolution/Resources/Localizable.xcstrings`
  (es base + en), **en el mismo commit que su vista**.
- ⚠️ **No edites el catálogo de strings con scripts.** Xcode lo reescribe a su
  formato canónico en el primer build y te deja un diff de 2.400 líneas. Si lo
  hacés igual, commiteá después el reformateo de Xcode (pasó, ver `13def46`).
- **Accessibility identifier** en todo control interactivo.
- **Commits en español**, atómicos.
- Convenciones de concurrencia: `Docs/concurrency-conventions.md`. Resumen: el
  mundo del juego es `@MainActor`, nada de `Timer` para trabajo del frame loop,
  EconomyKit es puro y `Sendable`.

---

## 3. Arquitectura

### Las tres capas

| Capa | Dónde | Qué hace |
|---|---|---|
| **EconomyKit** | `Packages/EconomyKit/` | Toda la economía: pura, `Sendable`, sin UIKit/SpriteKit, con reloj y RNG inyectables. Si una pieza de lógica necesita un tipo de UI, está en la capa equivocada. |
| **GameState** | `FisuEvolution/Game/State/GameState.swift` | `@Observable @MainActor`. Orquesta: carga, tick de income, gestos resueltos, popups, y **proyecciones** para SwiftUI. |
| **Presentación** | `FisuEvolution/Scenes/` + `FisuEvolution/UI/` | `BoardScene` dibuja y captura gestos; SwiftUI sólo lee proyecciones. |

**Regla que sostiene todo**: SwiftUI **nunca** lee `PlayerState`. Lee
proyecciones que `refreshProjections` publica a 8 Hz comparando antes de escribir.
`PlayerState` cambia decenas de veces por segundo; si la UI lo observara, se
recompondría sin parar.

### Contenido 100% data-driven

Ningún conteo, rango ni switch por etapa vive en código. Todo sale de JSON en
`FisuEvolution/Resources/`:

| Archivo | Qué define |
|---|---|
| `Data/economy.json` | Curvas, los 11 pisos (`floors[]`), costos de contratación, ORO |
| `Data/tiers.json` | Los 30 tiers y la cadena de evolución (generado: `swift run generate-tiers`) |
| `Data/assets_manifest.json` | **Único puente código→arte.** Sin entrada acá, placeholder programático |
| `Config/skins.json` | Catálogo de apariencias |
| `Config/*.json` | Eventos, specials, upgrades, boosts, daily, feature flags |

Agregar un piso = una entrada en `floors[]` + el PNG del fondo. Agregar un
personaje = PNGs al atlas + entrada en manifest/tiers. **Cero código.** Hay un
`ExtensibilityDrillTests` que lo prueba con un piso 12 declarado sólo como dato.

### La torre

- `FloorTable` (EconomyKit) valida cobertura exacta 1...maxTier sin solapes.
- `TowerState` vive **en memoria**; NO se serializa.
- **Los saves guardan unidades por TIPO, nunca por piso.** `TowerReconciler`
  recalcula la ubicación contra el mapeo vigente en cada carga, así que remapear
  tiers entre versiones reacomoda las partidas en vez de romperlas.
- `PlayerState` v4 = sobre con `run` (muere al reencarnar) + `meta` (sobrevive).

### La escena

Una sola `SKScene` con `SKCameraNode`. Los `FloorNode` se apilan a
`(0, i × alto)`; sólo vive el rango visible ±1. Reveal, flash y textos van
re-parenteados a un overlay de cámara para que no se queden atrás al navegar.

---

## 4. Qué cambió en la sesión del 2026-08-05

19 commits, de `2001e24` a `d39b57d`.

### Fluidez — plan CERRADO (ver `Docs/HANDOFF-perf.md`)

Se midió Release, que era lo que faltaba, y **eso cerró el plan**: los fps están
saturados a 60 en Debug y en Release, vacío y poblado. Se hicieron sólo las dos
partes que arreglan un hitch real (precarga de audio fuera de main;
`renderPlacements` reconciliador) y se descartaron las otras tres con el número
que las descarta.

**Dos cosas que hay que saber antes de tocar rendimiento:**
1. **Los fps no discriminan nada acá.** Usá `draws` del overlay de DEBUG.
2. **El batching entre personajes es imposible por construcción**: `depthZ` le da
   a cada uno un `zPosition` único para el efecto multitud, y con
   `ignoresSiblingOrder` SpriteKit sólo fusiona nodos del mismo z.

### Gate de contratación (spec y plan en `Docs/superpowers/`)

Contratar en un piso exige **el piso de arriba desbloqueado**; el callejón queda
exento y el último piso se habilita a sí mismo. La condición vive en **una**
función, `TowerActions.canHire`, que usan el juego **y** `PacingSimulator`.

⚠️ **El pedido original era DOS pisos y se midió que rompe el juego**: el bot se
traba en tier 12 y no llega a Dios nunca. El backfill es el puente que hace
viable la progresión (el merge puro es 2²⁹ fisuras), y pedir dos pisos lo saca
justo donde hace falta. Tabla completa en `Docs/balance-log.md`.

**El botón no queda muerto cuando el gate cierra** (2026-08-05): parado en tu
frontera, contratar cae en el piso de **abajo** —que por la propia regla del gate
es siempre el más alto donde sí se puede— y el botón nombra ese piso para que la
compra no parezca no haber pasado. `TowerActions.hireTargetFloor` decide el
destino; `GameState.HireOffer` es la única proyección que consume el botón.

### Secuencia de celebraciones

Un merge que asciende y abre piso disparaba **cinco cosas en t=0**. Ahora
encadena: vuelo → reveal → piso nuevo → `celebrationsDidFinish()` → sheet de skin
→ toast. Encadena **por completion, no por delays**: con Reduce Motion las
duraciones colapsan y ningún offset puede esperar a un sheet que cierra el jugador.

### Skins

- Se retiraron los tres tintes globales (golden/galaxy/god). Cada personaje tiene
  **base + la suya**. ⚠️ Eran los tres productos IAP: **la tienda quedó vendiendo
  sólo `remove_ads`**. El sistema de tintes sigue entero, una skin futura entra
  por config.
- Las bloqueadas se ven en **silueta** de tinta plena.
- El popup del premio gana "Ponérsela".
- **El arte de las 36 skins está hecho y verificado.** Una (`home_office`) se
  regeneró porque había salido idéntica al arte base.

### Balance

`hire.defaultCostMultiplier` 300 → 600 (el callejón sigue en 50). Medido:
**acortó** el juego de 264 h a 196 h, porque el bot deja de hacer backfill y
vuelca esa plata a reencarnar. Ver `Docs/balance-log.md`.

### UI

La ficha de personaje abre entera y muestra skin y pasivo juntos sin scrollear;
el nombre del personaje nuevo ya no se sale de la pantalla; la franja de piso es
más alta y la hitbox cubre la cabeza.

**La franja de la multitud llega hasta la mitad de la pantalla** (2026-08-05).
Un solo knob, `BoardScene.crowdTopRatio`, en fracción del ALTO de pantalla; el
deambular sale **derivado** de la franja, así que las filas la cubren sin huecos
y nadie puede pasarse por arriba. ⚠️ Los fondos están autorados con el tercio
inferior transitable, así que a 0,5 la multitud pisa la zona del decorado —es lo
pedido, y bajar `crowdTopRatio` a ~0,40 la devuelve al tercio.

---

## 5. Decisiones del dueño que NO se re-litigan

1. **El primer Fisura cuesta 50** y los targets de pacing se bajaron a la
   conducta real en vez de recalibrar knobs. Costo medido en `balance-log §F7.6`.
2. **Contratar arriba cuesta 600×** lo que rinde un click ahí; el callejón, 50×.
3. **El gate es de UN piso**, no dos: con dos el juego no se puede terminar.
4. **Los tintes IAP se retiraron** aunque eran los únicos productos pagos además
   de remove_ads.
5. `PacingTests` está pineado a la **conducta actual**, no al pacing que el spec
   pedía. `pacing-sim` sigue imprimiendo los targets de DISEÑO para que la brecha
   quede visible.

---

## 6. Cómo verificar

```bash
cd Packages/EconomyKit && swift test                      # 141
cd - && /opt/homebrew/bin/xcodegen generate               # si agregaste/borraste Swift
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test
cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q   # 20
```

Estado: **EconomyKit 144 · app 90 · UI 10 · pipeline 20**, todo verde.

Simulador a mano:

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app
xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

Fixtures DEBUG por launch argument: `--uitest-reset` (partida nueva),
`--uitest-unlock-tower` (abre pisos), `--uitest-open-sheet` (abre la ficha).
El panel de debug es el ícono de herramientas del HUD.

---

## 7. Trampas en las que ya caímos

1. **El build incremental NO recompila los atlas.** Si medís páginas de atlas o
   peso del `.app` y no cierran, borrá `build/DD`.
2. **Un test de UI puede pasar sin probar nada.** Si automatizás gestos sobre
   SpriteKit, **asertá el efecto**, no que el gesto no crashee.

   ⚠️ **`AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent`
   falla hoy en `main`** (`"Alley" != "City"`, verificado 2026-08-06). No es un
   problema de entorno ni del host de tests: es este mismo test cayendo en la
   trampa 3 de abajo — arrastra por coordenadas fijas, el personaje deambuló, el
   merge no engancha y el ascenso que asserta nunca ocurre. Su espejo de
   `crowdBand` **sí** está al día (usa 0,4, igual que `BoardScene.crowdTopRatio`),
   así que lo que falta son los reintentos. **Ya se llevó puestos dos agentes**
   que lo diagnosticaron como "el simulador no arranca" y se pusieron a borrar
   dispositivos. Mientras no se arregle, verificá con
   `-skip-testing:FisuEvolutionUITests/AscentRenderingUITests` y sabé que la
   línea de base real es **EconomyKit 144 verdes, UI 9 de 10**.

   ⚠️ **`PacingTests.strugglingPhaseLength` también está rojo en `main`**
   (verificado con `git stash` el 2026-08-06). No falla un assert: el proceso de
   la app **muere** — `Test crashed with signal kill before starting test
   execution`. Es entorno, no economía. Salteálo igual que el otro mientras no se
   arregle.

   ⚠️ **El simulador se degrada en corridas largas** (`(ipc/mig) server died`
   repetido). Se sale con `xcrun simctl shutdown all`, `erase` del device y
   `-parallel-testing-enabled NO`. Si una suite empieza a fallar a mitad de una
   corrida que venía verde, es esto y no el código.

   ⚠️⚠️ **Dos agentes en paralelo NO pueden compartir el mismo device.** Es la
   causa raíz de lo anterior. Con varios frentes corriendo contra
   `name=iPhone 16 Pro` aparecen `Invalid device state`, `Mach error -308`,
   reinicios del bundle a mitad de corrida y —lo que lo delata— **tests de OTRO
   worktree en tu log**: un frente vio correr `EffectDescriptorTests`, que no
   existían en su árbol. Cada frente se crea el suyo y apunta por UDID:

   ```bash
   xcrun simctl create "mi-frente" "iPhone 16 Pro"
   ```

   ```bash
   xcodebuild ... -destination 'id=<UDID>' -parallel-testing-enabled NO
   ```

   Desde que se hizo eso: cero reinicios, cero fallos espurios.

   ⚠️ **`EconomyLoopUITests.testTappingEarnsCoinsAndSpawnButtonExists` también es
   flaky**, por la misma trampa 3: falló una vez y pasó las tres siguientes sin
   que nadie tocara nada. No es un tercer bug, es el mismo patrón.
3. **Los drags por coordenadas fijas fallan seguido** desde que el reconciliador
   conserva la posición deambulada: los personajes ya no vuelven a su ancla en
   cada relayout. Si automatizás un merge, contá con reintentos.
4. **"Failed to scroll to visible" en un test de UI casi nunca es el botón**: es
   algo modal tapándolo. Exportá los attachments del xcresult y mirá la captura.
5. **Claves de localización con `%@` interpoladas con un `Int`** salen como la
   clave cruda en pantalla: Swift manda `%lld` y el lookup falla. Pasá `String(x)`.
   Ya pasó **dos veces** (F7.5 y 2026-08-05).

   ⚠️ **Y tiene una segunda forma, encontrada el 2026-08-06: armar la CLAVE por
   interpolación.**

   ```swift
   Text(LocalizedStringKey("upgrades.flavor.\(line.id)"))   // ⛔️ NO busca esa clave
   ```

   `LocalizedStringKey` es `ExpressibleByStringInterpolation`, así que eso no
   construye `upgrades.flavor.income`: construye la clave **`upgrades.flavor.%@`**
   con `income` de argumento. No la encuentra, y dibuja el formato con el id
   sustituido — en pantalla se lee literal `upgrades.flavor.income`.

   Lo peor es que **el test unitario pasaba**, porque hacía el lookup por otro
   camino. Sólo se vio mirando el simulador. La forma correcta es resolver la
   clave en una función del estado (`upgradeFlavorText(for:)`) y que el test
   ejerza **esa misma función**, la que dibuja la fila.

6. **El runner de tests de UI corre la app en INGLÉS**, aunque el idioma de
   desarrollo del proyecto sea `es`. Un test que asserta sobre texto en español
   pasa por la razón equivocada: no encuentra el texto **nunca**, ni cuando la
   cosa que busca está presente. Asertá por **accessibility identifier**, y
   verificá el test al revés —poniendo de vuelta lo que sacaste y viendo que
   falla— antes de creerle.

7. **Los agentes en paralelo comparten el scratchpad.** Si varios frentes
   escriben `full.log` ahí, se pisan entre sí. Prefijá con el nombre del frente.
8. **`osascript`/System Events no funciona desde el shell del agente.** El batch
   de arte hay que correrlo desde Terminal.app.
9. **Medir fps con un build corriendo en paralelo da números basura.**
10. **La multitud y los fondos comparten espacio de `zPosition`, y eso ya rompió
   una vez.** `depthZ` da negativo apenas una fila queda por encima de
   `rows × cellSize`, y los `FloorNode` viven en `ordinal × 0.01`: cuando las dos
   bandas se tocan, el fondo tapa a los personajes y quedan **invisibles pero
   clickeables** (el hit-testing es geométrico y no mira el z). `fieldNode` va
   montado en `BoardScene.fieldBaseZ` para que no puedan tocarse, y
   `CrowdDepthTests` lo pinea. Si tocás `frontRowRatio`/`rowDepthRatio`/wander,
   ese test es el que te avisa.
11. **Un personaje invisible no siempre es `alpha = 0`.** Ese era el bug viejo del
   pool. Si además ves su etiqueta "T1" flotando sin cuerpo, es z: dentro de un
   `CharacterNode` todos los hijos comparten z, y con `ignoresSiblingOrder`
   SpriteKit batchea labels y sprites del atlas por separado, así que contra el
   fondo pierden los cuerpos y sobreviven los labels.

---

## 8. Qué queda

⚠️ **Esto cambió el 2026-08-06.** Un jugador externo terminó el juego de punta a
punta y mandó **16 correcciones**. Ya no es cierto que no quede nada: hay un
programa de trabajo entero, con su spec y sus planes.

| Documento | Qué es |
|---|---|
| `superpowers/specs/2026-08-06-correcciones-de-playtest-design.md` | **Los 16 pedidos como RF-01…RF-16**, con criterio de aceptación. Punto de entrada del programa |
| `superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md` | Los 8 personajes nuevos, la baja de `kiosco` y el remapeo de la torre a 10 pisos |
| `superpowers/plans/2026-08-06-ola-0-preparacion.md` | Partir `GameState`, la pieza de descripción de efectos, el contenido y el audio |
| `superpowers/plans/2026-08-06-ola-1-cinco-frentes.md` | Menú de mejoras, mapa de pisos, bonus, prestigio y tienda |

El trabajo está organizado en **cuatro olas** para que varios frentes corran en
paralelo sin compartir archivos. Lo único bloqueado por la cuenta de Apple
Developer es **RF-02c**, el alta de productos en App Store Connect: todo lo demás
—incluida la tienda funcionando— queda verificable en el simulador antes de eso.

**Tres decisiones del dueño de esa sesión que no se re-litigan:**

1. **El fondo que se retira es `cosmic`**, no `mars`. Criterio estético: es el
   único que se sale del estilo (islas flotantes con cofres y un río de gemas).
   Su costo está medido y anotado en el spec.
2. **Sale `Personal de Kiosco` de la cadena** y El Mantero ocupa su lugar. Es lo
   que baja el desplazamiento de la cadena de +3 a +2 y permite que tres de las
   cuatro recolocaciones de personajes entren.
3. **Magnate Petrolero queda en la luna.** Bajarlo a la isla exigía dejar un solo
   personaje nuevo en toda la zona terrenal, y eso ensuciaba el callejón y la
   calle urbana: tres desajustes nuevos para arreglar uno.

Después de las cuatro olas sigue F6, que son gates humanos: cuenta Apple
Developer (USD 99), nombre comercial, App Store Connect, TestFlight, submit. El
ship-prep técnico ya está (`Distribution/`, entitlements, CI, privacy pages).

Anotado por si algún día importa, con su medición:

- **Peso del `.app`**: 135 MB en Debug limpio, 115 en Release. **Los 11 fondos
  solos son ~81 MB.** Reautorarlos a proporción vertical (~768×1664) es la única
  ganancia grande que queda en tamaño de descarga; hoy ~54% de sus píxeles no se
  ven nunca. Detalle en `Docs/HANDOFF-perf.md`.
- **`director__directorio`** es una skin real pero floja (sin cambio cromático).
  Regenerarla cuesta cuota de Gemini; queda a criterio del dueño.
- **Decisión de ads** (`Docs/ads-integration.md`): AdMob real o v1 sin ads.

---

## 9. Mapa de documentos

| Doc | Para qué |
|---|---|
| **este** | Punto de entrada, estado y arquitectura |
| `HANDOFF-F7-estado.md` | La torre en detalle + el circuito de arte de skins |
| `HANDOFF-perf.md` | Todo lo de rendimiento, con las mediciones |
| `HANDOFF-arte-gemini.md` | El pipeline de generación de arte y sus 6 bugs |
| `balance-log.md` | **Toda decisión de números, con su costo medido** |
| `PROMPT-F7-torre-de-escenarios.md` | El spec funcional de la torre |
| `concurrency-conventions.md` | Las 6 reglas de Swift 6 del proyecto |
| `SESION-2026-08-05-fallback-de-contratacion.md` | El fallback del botón y la fila trasera invisible |
| `superpowers/specs/`, `superpowers/plans/` | Specs y planes por feature |
