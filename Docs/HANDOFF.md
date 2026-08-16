# HANDOFF — FisuEvolution, estado actual

> ✅ **EL REDISEÑO DE UI DE ESTA RAMA ESTÁ COMPLETO** — 20 de 20 tareas
> (`feature/rediseno-ui-cowevolution`, cerrado el 2026-08-16). El estado tarea
> por tarea, las decisiones del dueño y los avisos vivos siguen en
> **`Docs/SESION-2026-08-14-rediseno-ui.md`**, que es la fuente de verdad del
> detalle de esta rama. Lo de abajo describe el juego ANTES del rediseño y
> sigue siendo válido para todo lo que el rediseño no tocó; el resumen de la
> sesión, con los números finales de tests, está en §4.
>
> ⚠️ **Lo que falta NO es implementación**: el review integral de rama con su
> ola de fixes, el batch de los 15 iconos que corre el dueño (§8) y el merge
> a `main`.
>
> **Empezá por acá.** Última actualización: **2026-08-16** (rediseño de UI).
> Este doc reemplaza al índice disperso de handoffs; los otros siguen siendo la
> fuente de verdad de SU tema y están linkeados donde corresponde.
>
> ⚠️ **Lo más importante que cambió**: el programa de las 16 correcciones del
> playtest **se terminó**. Lo único que queda son dos gates humanos (§8). No hay
> tarea de código pendiente en ese spec.
>
> **La sesión del 2026-08-10** sumó tres cosas de jugabilidad y arte, todas
> commiteadas y verdes (§4): fusionar dejó de ser fiddly, los bonus activos se
> ven en el HUD, y los 10 pisos tienen su fondo en perspectiva.
>
> ⚠️ **`main` está adelante de `origin/main`.** Mientras no se pushee, cada
> frente nuevo arranca desde un árbol viejo — es la trampa 7.

---

## 1. Qué es

**FisuEvolution** ("Hobo Evolution"): juego iOS merge-idle con humor argentino.
37 tiers de evolución (El Fisura → Dios) en una **torre de 10 pisos simultáneos**;
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
| `Data/economy.json` | Curvas, los 10 pisos (`floors[]`), costos de contratación, ORO |
| `Data/tiers.json` | Los 37 tiers y la cadena de evolución. **Generado** desde `Tools/generate-tiers/Sources/main.swift` — editar el JSON a mano lo pisa la próxima regeneración |
| `Data/assets_manifest.json` | **Único puente código→arte.** Sin entrada acá, placeholder programático — ⚠️ **salvo los fondos**, ver abajo |
| `Config/skins.json` | Catálogo de apariencias |
| `Config/*.json` | Eventos, specials, upgrades, boosts, daily, feature flags |

Agregar un piso = una entrada en `floors[]` + el PNG del fondo. Agregar un
personaje = PNGs al atlas + entrada en manifest/tiers. **Cero código.** Hay un
`ExtensibilityDrillTests` que lo prueba con un piso 12 declarado sólo como dato.

⚠️ **El fallback a placeholder NO cubre los fondos.** Un personaje sin entrada en
el manifest se dibuja con su placeholder programático y el juego sigue; **un piso
cuyo fondo falta hace que la app no arranque**. Medido el 2026-08-06 sacando
`bg_galaxy` para destrabar su regeneración: los tests unitarios seguían verdes y
los 17 de UI se cayeron con `Application com.manuader.fisuevolution is not
running`. Restaurar la entrada los devolvió a verde sin tocar nada más.

Consecuencia práctica: **regenerar un fondo exige sacarlo del manifest, y con el
manifest así el juego no corre.** La ventana tiene que ser corta y no se puede
buildear ni testear adentro. `process_dropbox.py` vuelve a poner la entrada al
integrar la imagen nueva, y si algo sale mal `git checkout` la restaura.

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

**Fusionar tiene dos gestos** (2026-08-10, spec en
`superpowers/specs/2026-08-10-fusion-asistida-design.md`):

- **Arrastrar.** Al levantar a alguien, los del **mismo tipo** se destacan: se
  congelan (dejan de deambular), suben `candidateZLift` por encima de la
  multitud, pegan un pop y capturan el drop a 1,5 celdas en vez de 0,95.
- **Doble toque.** Dos toques sobre el mismo personaje dentro de 0,3 s traen al
  compañero más cercano que esté a ≤2 celdas y lo funden. El tap **cobra
  siempre y primero**; la fusión es un efecto adicional del segundo toque.

⚠️ **Tocar rápido ES un doble toque** y no hay forma de distinguirlo: los dos
primeros toques de cualquier ráfaga van a fusionar. No es un problema —fusionar
nunca es una pérdida— pero la cascada sí, y por eso hay
`assistedMergeCooldown` de 0,8 s. No lo saques.

Los dos gestos salen por `resolveDrop`, que es el **único** camino de fusión de
la escena: por eso el doble toque hereda el prompt de carrera, el aviso de piso
lleno, el ascenso y la cadena de celebraciones sin código propio. La geometría
vive afuera, en `MergeTargeting`, y está pineada en `MergeTargetingTests`.

### Contadores de bonus activos

Bajo el HUD y a la izquierda, un chip por bonus temporal corriendo — boosts,
videos y el premio del Abogado; los eventos no, que ya tienen su banner
(2026-08-10, spec en `superpowers/specs/2026-08-10-contadores-de-bonus-activos-design.md`).

⚠️ **La proyección `activeBonuses` NO lleva el tiempo restante**, y sacarlo de
ahí es lo único que hace que esto sea gratis: lleva `expiresAt` y
`totalDuration`, que son constantes, así que el array sólo cambia cuando un
bonus arranca o se muere. Con el restante adentro, `refreshProjections`
invalidaría SwiftUI una vez por segundo —y el aro, ocho— mientras hubiera un
boost activo. El tiempo lo cuenta la vista con **un** timer de 1 Hz para toda la
barra, y el aro se interpola con un tween lineal de 1 s entre tick y tick.

---

## 4. Qué cambió, sesión por sesión

### Sesión del 2026-08-14/16 — Rediseño de UI estilo Cow Evolution

**20 tareas, 53 commits** sobre `d60d886`, en `feature/rediseno-ui-cowevolution`.
101 archivos, +19.248/−1.681. El detalle tarea por tarea —con los fix rounds,
los rulings y los avisos— vive en **`Docs/SESION-2026-08-14-rediseno-ui.md`**;
acá va lo que hay que saber sin abrirlo.

**Qué es**: el juego pasó a la estructura de Cow Evolution —HUD superior
contiguo + **barra inferior de 6 pantallas**— con identidad visual propia.
Desaparecieron los 4 botones sueltos del HUD y el botón de spawn; entraron
seis pantallas reales (FisuJobs, Upgrades v2, Customization, Regalos, Tienda
v2, Menú) más el Ascensor y las cuatro sub-pantallas del menú
(organigrama, stats, logros, ajustes).

**Las piezas que importan:**

- **FisuJobs** (`FisuEvolution/UI/Jobs/FisuJobsView.swift`) es la **referencia
  visual canónica**: toda pantalla nueva se revisó contra ella (regla del
  dueño, ver el doc de sesión). Gramática compartida: `GameCard` para filas,
  `PricePill` para precios, `ProgressBar` para progreso, paleta sólo
  `Palette*`, tipografía `Tokens.*`, cabecera crema opaca, `ArtCloseButton`.
- **Curva de contratación por tipo** con `tierPremium` (1,8): cada tipo
  desbloqueado se contrata con precio propio. El gate de un piso y el Fisura a
  50 quedaron intactos.
- **39 logros data-driven** con motor de 11 hooks y cobro con recompensa.
- **Ajustes reales**: idioma, audio, notificaciones (recordatorio diario
  19:00) y los dos legales (privacidad y términos, es+en) — todo listo para
  App Store. `ConfigView` murió.
- **Facing de personajes**: miran hacia donde caminan, con flip periódico
  (7,5 s ± 5). El espejado va en `sprite.xScale`, nunca en el nodo.
- **Micro-animaciones**: contador rodante, stagger compartido, shake medido,
  toasts con spring.
- Catálogo de strings: **269 → 468 claves** (es + en).
- 34 archivos Swift nuevos; 3 borrados (`ConfigView`, `SpawnButtonView`,
  `BonusView`).

**Números finales, medidos el 2026-08-16 en un simulador propio por UDID,
`-parallel-testing-enabled NO`, unit ANTES que UI:**

| Suite | Resultado |
|---|---|
| `EconomyKit` (`swift test`) | **180/180** ✅ |
| `FisuEvolutionTests` | **336/336** ✅ |
| `FisuEvolutionUITests` | **40/40** ✅ (14 clases; `AscentRenderingUITests` salteada, rojo preexistente de `main`) |
| `Tools/asset-pipeline` | 27, **1 rojo conocido** (pide Chrome en `:9222`) |
| Warnings de compilador | **0** |

⚠️ **Ningún flaky hizo falta re-correr**: `EconomyLoopUITests`,
`BonusHUDUITests` y `StoreManagerTests` pasaron en la corrida completa, y
`PacingTests.strugglingPhaseLength` —que figuraba como rojo de entorno— pasó
también. La regla que lo hace reproducible es **correr unit antes que UI**
(§7).

### Sesión del 2026-08-10

Cuatro commits, de `853bb1b` a `de9b76e`. **Dos frentes en paralelo** —uno de
jugabilidad y uno de arte— y eso dejó una marca en el historial: ver la ⚠️ del
final de esta sección.

#### Fusión asistida (`853bb1b`)

Fusionar era la acción central del juego y la más fiddly. Detalle en §3, "La
escena". Lo que hay que saber en dos líneas: al agarrar a alguien sus hermanos
se destacan y se **congelan**, y un doble toque funde al par sin arrastrar nada.

⚠️ Y una causa que no estaba en el pedido y era la peor: el drop se resolvía
contra el **ancla** del slot y no contra dónde estaba parado el personaje, así
que **soltar encima de alguien te mudaba al hueco de al lado**. Es la vieja
trampa 3, ahora arreglada.

#### Contadores de bonus activos (`de9b76e`)

Un chip por bonus temporal corriendo, abajo del HUD y a la izquierda. Detalle en
§3, "Contadores de bonus activos". La decisión que sostiene todo: la proyección
**no** lleva el tiempo restante.

#### Los 8 fondos que faltaban (`ab5d25d`, `3791247`)

Los 10 pisos tienen piso dibujado en perspectiva y la banda de personajes usa
ese espacio. Dos cambios de código que el arte hizo necesarios:

1. `crowdTopRatio` 0,40 → **0,44**. Medido en el juego, no calculado: con 0,45
   el techo de la banda quedaba encima de la línea del piso y los de atrás
   volvían a flotar.
2. **`backgroundOffset` a 0** en urban, island, moon y mars. Ese knob existía
   para hundir la franja plana del arte VIEJO; con el arte nuevo esa franja es
   el piso generado, así que el offset lo empujaba fuera de pantalla. El bug
   quedaba vivo en 4 de los 10 pisos.

#### ⚠️ Dos agentes en paralelo se pisaron en git

`853bb1b` —la fusión asistida— **lo commiteó la sesión del arte, no la que
escribió el código**: encontró el trabajo sin commitear en el árbol y lo barrió
dentro de su tanda (su propio mensaje lo aclara). No se perdió nada y quedó con
su spec, pero es autoría cruzada y explica por qué el commit de una feature de
tablero aparece entre dos de arte.

**La lección práctica**: con más de un frente sobre el mismo working tree,
commiteá lo tuyo apenas esté verde. Lo que queda sin commitear no es "tuyo": es
del próximo `git add` que pase.

### Sesión del 2026-08-05

19 commits, de `2001e24` a `d39b57d`.

#### Fluidez — plan CERRADO (ver `Docs/HANDOFF-perf.md`)

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

#### Gate de contratación (spec y plan en `Docs/superpowers/`)

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

#### Secuencia de celebraciones

Un merge que asciende y abre piso disparaba **cinco cosas en t=0**. Ahora
encadena: vuelo → reveal → piso nuevo → `celebrationsDidFinish()` → sheet de skin
→ toast. Encadena **por completion, no por delays**: con Reduce Motion las
duraciones colapsan y ningún offset puede esperar a un sheet que cierra el jugador.

#### Skins

- Se retiraron los tres tintes globales (golden/galaxy/god). Cada personaje tiene
  **base + la suya**. ⚠️ Eran los tres productos IAP: **la tienda quedó vendiendo
  sólo `remove_ads`**. El sistema de tintes sigue entero, una skin futura entra
  por config. (Ya no es el estado actual: RF-13 sumó las dos skins de arte propio
  y RF-02b los packs — hoy la tienda vende **10 productos**.)
- Las bloqueadas se ven en **silueta** de tinta plena.
- El popup del premio gana "Ponérsela".
- **El arte de las 36 skins está hecho y verificado.** Una (`home_office`) se
  regeneró porque había salido idéntica al arte base.

#### Balance

`hire.defaultCostMultiplier` 300 → 600 (el callejón sigue en 50). Medido:
**acortó** el juego de 264 h a 196 h, porque el bot deja de hacer backfill y
vuelca esa plata a reencarnar. Ver `Docs/balance-log.md`.

#### UI

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
   ⚠️ Su PROFUNDIDAD es la decisión; su COBERTURA no. En la Ola 3 el piso urbano
   se declaró exento (`hireGateExempt` en `floors[]`) porque el gate, combinado
   con el remapeo a 37 tiers, dejaba 268 h de pared antes de corporativo. Sigue
   siendo un gate de un piso. Ver `balance-log`, "El muro de ×368, cerrado".
4. **Los tintes IAP se retiraron** aunque eran los únicos productos pagos además
   de remove_ads.
5. `PacingTests` está pineado a la **conducta actual**, no al pacing que el spec
   pedía. `pacing-sim` sigue imprimiendo los targets de DISEÑO para que la brecha
   quede visible.

---

## 6. Cómo verificar

⚠️ **Creá tu propio simulador y apuntá por UDID** (trampa 2), y **corré unit
ANTES que UI** — la asimetría es real y direccional, ver abajo.

```bash
UDID=$(xcrun simctl create "mi-frente" "iPhone 16 Pro")

cd Packages/EconomyKit && swift test                      # 180
cd - && /opt/homebrew/bin/xcodegen generate               # si agregaste/borraste Swift

# 1) UNIT PRIMERO
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/DD -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests test                   # 336

# 2) UI DESPUÉS
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/DD -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionUITests \
  -skip-testing:FisuEvolutionUITests/AscentRenderingUITests test   # 40

cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q   # 27, 1 rojo

xcrun simctl shutdown $UDID && xcrun simctl delete $UDID   # ⚠️ el cierre es parte del trabajo
```

Estado, medido entero el **2026-08-16** al cierre del rediseño de UI:
**EconomyKit 180 · app 336 · UI 40 · pipeline 27 (1 rojo conocido)**, cero
warnings de compilador.

- El rojo del pipeline es `test_wait_for_survives_a_stale_element_and_retries`:
  pide un Chrome escuchando en `:9222`. Es de entorno y es el baseline.
- `AscentRenderingUITests` sigue siendo el único rojo de UI (frágil por la
  vieja trampa 3): salteálo con `-skip-testing:` y usá siempre
  `-parallel-testing-enabled NO`.

⚠️⚠️ **UNIT ANTES QUE UI, siempre.** Correr los tests de UI primero rompe
`StoreManagerTests` **enteros**, y no es carga: fallan igual aislados. Una
corrida de UI deja la tienda local del simulador en un estado que
`SKTestSession` ya no puede usar. Con el device recién creado y unit primero,
pasan los 336 sin tocar nada.

⚠️ **`PacingTests.strugglingPhaseLength` figuraba como rojo de entorno** (moría
con `Test crashed with signal kill`) y el 2026-08-16 **pasó en la corrida
completa**. Si te falla, tratalo como entorno, no como economía.

`EconomyLoopUITests`, `BonusHUDUITests` y
`StoreManagerTests.refundRevokesEntitlement` son flakies **sensibles a carga**:
pasan aislados. El 2026-08-16 pasaron los tres en la corrida completa sin
re-correr nada. **Si una suite empieza a fallar en una corrida que va lenta,
mirá el reloj antes que el código** — y `uptime`, que un simulador ajeno
booteado o un `simctl` huérfano de otra tanda alcanzan para ensuciarla.

Simulador a mano:

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app
xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

Fixtures DEBUG por launch argument — **son doce, no tres**:

| Argumento | Qué deja listo |
|---|---|
| `--uitest-reset` | Partida nueva. Resetea también `fisuTutorialDone`, las banderas `ftue.*` y **los ajustes que viven en `UserDefaults`** (partículas, notificaciones e idioma — T16): sin eso, un test que apaga las partículas se las deja apagadas al siguiente |
| `--uitest-skip-tutorial` | Sin tutorial. **Casi todo test de tablero lo necesita**: si no, el scrim se come los toques (trampa 9) |
| `--uitest-coins` | Plata para contratar sin dar ~50 toques |
| `--uitest-unlock-tower` | Abre pisos hasta el del tier 5. ⚠️ **NO toca `maxFloorOrdinalEver`**, así que no desbloquea boosts |
| `--uitest-seen-types` | Marca tipos vistos: es lo que llena la pestaña Personajes |
| `--uitest-prestige` | Acredita lifetime para llegar a reencarnar |
| `--uitest-open-sheet` | Abre la ficha sobre la primera unidad |
| `--uitest-skins` | Acredita las skins de milestone de los tipos YA VISTOS (van con `--uitest-seen-types`, que es lo que decide cuáles). Es lo que permite ejercer "Ponérsela" en Pintas sin abrir pisos ni reencarnar |
| `--uitest-storekit-empty` | `StoreManager` no carga productos: simula la tienda que no contesta. Es la ÚNICA forma de ejercer desde un test la rama "Precio no disponible", porque el runner inyecta la configuración de StoreKit del scheme y si no los productos cargan siempre |
| `--uitest-daily-streak` | Deja el ciclo del daily en el día 4: la tira del calendario de Regalos con días cobrados atrás. El único otro camino a un día con tilde es **volver mañana** |
| `--uitest-achievements` | Siembra los contadores históricos que cruzan tres logros (`ach_merges_1`, `ach_taps_1000`, `ach_videos_1`) y los deja **conseguidos y sin cobrar**: es lo único que llena la sección "Para cobrar" de la pantalla de Logros. Conseguir uno jugando pide fusionar, mirar un video con el proveedor real o dar mil toques — nada automatizable. Usa `max`, así que no pisa un save con más. ⚠️ Acredita durante `phase == .loading`, así que **NO desfila los tres banners**, y un logro ya acreditado no vuelve a cruzarse: para filmar el toast hay que cruzar uno EN RUNTIME y con el tablero despejado. El único barato es `ach_merges_1` — contratar uno en FisuJobs, cerrar la hoja y fusionar el par con doble toque. Contratar diez cruza `ach_hires_10` pero deja el banner tapado por la hoja |
| `--uitest-daily-popup` | El popup del premio del día, ya abierto (T18). Retrocede `lastClaimDay` a **ayer** —no lo borra, que un día salteado resetea el ciclo a 1— y corre el claim real, el mismo que acredita al volver a foreground. Existe porque el daily se cobra solo y una sola vez por día, y una partida nueva marca `lastClaimDay` en HOY para no pisar el tutorial: sin esta puerta, la única pantalla que celebra la racha no se puede ni fotografiar ni ejercitar sin cambiarle la fecha al simulador. Combinado con `--uitest-daily-streak` muestra el día 4. ⚠️ **Va con `--uitest-skip-tutorial`: la hoja está gateada por `tutorialDone`** |

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

   ⚠️ **Vale la pena volver a correrlo.** El 2026-08-10 se arregló justamente la
   causa que este diagnóstico le atribuye: el drop ya no se resuelve contra el
   ancla, y ahora hay doble toque, que no necesita puntería en el destino. **No
   se comprobó** —se lo salteó en las dos corridas de esa sesión—, así que sigue
   figurando como rojo; pero si alguien lo mira, empezá por correrlo tal cual
   antes de tocarle nada, y si sigue rojo pasalo a doble toque como se hizo con
   `mergeTheHighlightedPair`.

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

   ⚠️⚠️ **Y APAGALO AL TERMINAR.** Un simulador booteado son ~200 procesos que
   no se van solos. Con seis frentes creando el suyo y ninguno apagándolo, esta
   máquina llegó a **736 procesos `iOS` y load average 861**: los builds pasaron
   de 7 minutos a no terminar nunca, y varios frentes reportaron "la máquina
   está saturada" sin saber que la saturaban ellos. El cierre es parte del
   trabajo, no una cortesía:

   ```bash
   xcrun simctl shutdown <UDID> && xcrun simctl delete <UDID>
   ```

   ⚠️ **`EconomyLoopUITests.testTappingEarnsCoinsAndSpawnButtonExists` también es
   flaky**, por la misma trampa 3: falló una vez y pasó las tres siguientes sin
   que nadie tocara nada. No es un tercer bug, es el mismo patrón.
3. ~~**Los drags por coordenadas fijas fallan seguido**~~ **ARREGLADO en buena
   parte (2026-08-10, fusión asistida).** La causa era peor que "los tests son
   frágiles": la escena resolvía el drop contra el **ancla lógica** del slot y
   no contra dónde estaba parado el personaje, que desde que el reconciliador
   conserva la posición deambulada difieren hasta media celda. O sea que
   **soltar encima de alguien te mudaba al hueco de al lado**, en el juego y no
   sólo en el runner.

   Ahora la decisión vive en `MergeTargeting.dropTarget`, que mide contra las
   posiciones **reales**; las anclas quedan sólo para los slots vacíos, que no
   tienen nodo. `mergeTheHighlightedPair` pasó de barrer ocho coordenadas a un
   doble toque.

   ⚠️ Lo que **no** cambió: los personajes siguen deambulando, así que un gesto
   automatizado por coordenada fija sigue necesitando reintentos para acertarle
   al CUERPO. Lo que ya no hace falta es barrer el DESTINO.
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

   ⚠️⚠️ **Y su worktree se crea desde `origin/main`, no desde `main` local.**
   El 2026-08-06 `origin/main` estaba **102 commits atrás** —este repo se
   commitea local y casi no se pushea—, así que **todos** los frentes
   arrancaron sobre el árbol de cuatro días antes: sin el plan que tenían que
   leer, sin el spec, y con los JSON viejos. Cada uno lo detectó y se puso al
   día solo, pero uno lo dijo bien: *"si otro frente arrancó igual, trabajó
   sobre un repo fantasma"*.

   **Lo primero que hace un frente nuevo es comprobarlo:**

   ```bash
   git rev-list --count origin/main..main
   ```

   Si no da 0, `git merge --ff-only main` antes de tocar nada. Y la solución de
   fondo es pushear: mientras `origin` esté viejo, esto se repite en cada tanda.

8. **El handler de `SKTexture.preload` TIENE que ser `@Sendable`.** SpriteKit lo
   llama desde una cola de fondo y `BoardScene` es `@MainActor` (`SKScene` lo es
   en el SDK), así que un `{}` pelado hereda el aislamiento y **mata el proceso
   con SIGTRAP** al terminar la precarga.

   ```swift
   SKTexture.preload(textures) { @Sendable in }   // ✅
   ```

   ⚠️ Y lo grave: **el test de UI seguía en verde con la app crasheada.** Es la
   trampa 2 otra vez — un test de UI puede pasar sin probar nada.

9. ~~**Los tests de UI existentes pasan según el ORDEN en que corren.**~~
   **ARREGLADO (2026-08-07, RF-01).** `LaunchSmokeTests` y `EconomyLoopUITests`
   funcionaban sólo porque `--uitest-open-sheet` dejaba `fisuTutorialDone`
   seteado en ese simulador; en un device limpio el scrim del tutorial les tapaba
   los controles. Reproducido antes de tocar nada: `EconomyLoopUITests` fallaba
   con "coins never changed after tapping" en un simulador recién creado.

   El arreglo **no** fue que el tutorial deje de bloquear la pantalla —el patrón
   Clash of Clans exige que la bloquee, y RF-01 lo pide explícitamente— sino que
   el estado del tutorial pasó a ser **declarado y no heredado**:
   `--uitest-reset` ahora resetea también `fisuTutorialDone` y las tres banderas
   `ftue.*` (antes "partida nueva" sólo rehacía la PARTIDA), y el test que no
   quiere ver el tutorial lo dice con `--uitest-skip-tutorial`. Ningún test
   depende ya de lo que dejó otro.

   ⚠️ **Dos trampas nuevas de SwiftUI salieron de acá** y las dos se ven igual:
   todo compila, la pantalla se ve bien y el test falla en otro lado.

   a. **Un elemento de accesibilidad a pantalla completa TAPA a todos los
      controles de abajo en el árbol de AX.** Los marcadores del tutorial eran
      dos `Color.clear` arriba del `ZStack`; con eso, XCUITest dejaba de
      considerar "hittable" a cualquier botón —incluido el de saltear del propio
      tutorial— y todo `.tap()` moría con "Failed to scroll to visible", que es
      la trampa 4 con disfraz nuevo. Los toques por COORDENADA seguían
      funcionando, así que en el simulador no se notaba. Van de fondo y de 1×1,
      como `board.units` en `RootView`.

   a-bis. **Y la forma general, encontrada el 2026-08-10 con los contadores de
      bonus**: un `accessibilityIdentifier` puesto sobre un **contenedor que no
      es elemento de accesibilidad** (un `VStack` pelado) **se propaga y pisa el
      de sus hijos**. La barra tenía `hud.bonuses` en el `VStack` y cada chip su
      `hud.bonus.chip`: en el árbol quedaba **un solo** elemento, llamado
      `hud.bonuses`, y el test no encontraba ni un chip **mientras en pantalla
      se veían perfectos**. La cura es no ponerle identificador al contenedor.
      Se vio exportando los attachments del xcresult y mirando la captura —por
      eso conviene tomarla ANTES de los asserts, que un assert que corta se
      lleva puesta la evidencia.

   b. **`anchorPreference` PISA el valor del subárbol; no se suma.** Marcar la
      franja del HUD borraba de un saque los anclas del contador de monedas, de
      mejoras y del mapa, que viven adentro. El tutorial dibujaba el scrim entero
      sin recorte y el paso quedaba sin salida. Se usa
      `transformAnchorPreference`, que mergea.

   c. Y una de tests: `.tap()` sobre un elemento que XCUITest considera no
      hittable se pasa **~60 s** reintentando y después toca igual. Un test que
      quiere probar que algo NO se puede tocar tiene que tocar por coordenada: si
      no, tarda dos minutos y confunde "el scrim se comió el toque" con "XCUITest
      se negó a tocar".

9. **Un `repeatForever` no arranca si su `@State` cambió ANTES de que la vista
    exista.** La mano del tutorial no latía: el `onAppear` que ponía la bandera
    vivía en el overlay y corría mientras el recorte del tablero todavía no había
    llegado desde la escena, así que la mano se insertaba con la bandera ya en
    `true` — sin cambio que animar, sin animación. La bandera va en la **misma
    vista** que anima, con su propio `onAppear`.

    ⚠️ Lo importante es **cómo se encontró**, porque no se ve en una captura: la
    mano estaba ahí y en su pose grande. Se ve comparando **cuatro capturas
    seguidas** y hasheando la región. Y sólo se detecta si además se corre **al
    revés**: con Reduce Motion las cuatro daban idéntico —correcto— y sin Reduce
    Motion **también**, que es el bug. Una verificación visual que no discrimina
    en los dos sentidos no está verificando nada; es la trampa 2 fuera de los
    tests.

    ```bash
    xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
    ```

10. **Congelar lo que animaba baja los fps del overlay de DEBUG a ~1, y está
    bien.** Con el recorte del tutorial sobre el tablero no queda nada animando
    en SpriteKit (el anillo de FTUE se calla y el personaje deja de deambular) y
    el contador marca `1.0 fps`. No se pierde income: `tick` integra por `delta`,
    así que la misma plata se acredita en tramos más largos, y el tap refresca
    las proyecciones por su cuenta sin pasar por el frame loop. Vuelve a 60 al
    salir del paso. Ver también la trampa 11: ese contador miente fácil.
11. **`osascript`/System Events no funciona desde el shell del agente** — y ahora
    se sabe **exactamente dónde** (probado el 2026-08-06):

    | Paso | Desde el shell del agente |
    |---|---|
    | `launch_gemini_chrome.py` | ✅ **funciona**. Abre el Chrome aislado y `:9222` responde |
    | La sesión de Gemini en ese perfil | ✅ sigue logueada |
    | `build_queue` y el checkpoint | ✅ funcionan |
    | **Mandar las teclas al compose box** | ❌ `System Events got an error: osascript is not allowed to send keystrokes. (1002)` |

    Es el permiso de **Accesibilidad** de macOS, que el shell del agente no tiene
    y no puede pedirse a sí mismo. Falla en el asset 1 de 53, **sin consumir
    cuota y sin ensuciar el checkpoint** — así que intentarlo es barato, pero no
    sirve. El batch se corre **desde Terminal.app**, que sí tiene el permiso.

    El batch
   de arte hay que correrlo desde Terminal.app.
12. **Medir fps con un build corriendo en paralelo da números basura.**
13. **La multitud y los fondos comparten espacio de `zPosition`, y eso ya rompió
   una vez.** `depthZ` da negativo apenas una fila queda por encima de
   `rows × cellSize`, y los `FloorNode` viven en `ordinal × 0.01`: cuando las dos
   bandas se tocan, el fondo tapa a los personajes y quedan **invisibles pero
   clickeables** (el hit-testing es geométrico y no mira el z). `fieldNode` va
   montado en `BoardScene.fieldBaseZ` para que no puedan tocarse, y
   `CrowdDepthTests` lo pinea. Si tocás `frontRowRatio`/`rowDepthRatio`/wander,
   ese test es el que te avisa.
14. **Un personaje invisible no siempre es `alpha = 0`.** Ese era el bug viejo del
   pool. Si además ves su etiqueta "T1" flotando sin cuerpo, es z: dentro de un
   `CharacterNode` todos los hijos comparten z, y con `ignoresSiblingOrder`
   SpriteKit batchea labels y sprites del atlas por separado, así que contra el
   fondo pierden los cuerpos y sobreviven los labels.
15. **`xcodegen generate` con Xcode ABIERTO rompe el proyecto que ves en Xcode**,
   y el síntoma no se parece a la causa: Xcode dice
   **`Missing package product 'EconomyKit'`** y el build falla.

   Pasó el 2026-08-07. El `.xcodeproj` no se versiona y se regenera seguido, así
   que la sesión abierta de Xcode se queda con el grafo de paquetes del archivo
   viejo; cuando el archivo se reemplaza abajo, la referencia al paquete local
   queda colgando. **El disco está perfecto** — se comprobó con un build de
   device completo, que compiló y firmó:

   ```bash
   xcodebuild -scheme FisuEvolution -destination 'generic/platform=iOS' -configuration Debug build
   ```

   Y `xcodebuild -resolvePackageDependencies -scheme FisuEvolution` imprime
   `EconomyKit: .../Packages/EconomyKit`, o sea que la resolución tampoco está rota.

   **La cura es del lado de Xcode**, no del repo: cerrar el proyecto (⌘⇧W) y
   volver a abrirlo. Si insiste, *File ▸ Packages ▸ Reset Package Caches*.

   ⚠️ Y la prevención, que importa más si hay agentes trabajando: **cerrá Xcode
   antes de dejar correr un frente**, o contá con reabrir el proyecto cuando
   vuelvas. Un agente regenera el `.xcodeproj` cada vez que agrega o borra un
   archivo Swift, que es todo el tiempo.

   ⚠️ Corolario: **un build de línea de comando con `-derivedDataPath build/DD`
   NO reproduce esto** —usa su propia DerivedData y su propio estado de
   paquetes—, así que la suite puede estar entera en verde mientras Xcode no
   compila. Para reproducir lo que ve Xcode hay que buildear **sin**
   `-derivedDataPath`.

---

## 8. Qué queda

### Lo que dejó el rediseño de UI (2026-08-16)

**1. El batch de los 15 iconos lo corre EL DUEÑO, desde Terminal.app.** La
cola está armada y verificada (tarea 19): 15 prompts `.md` numerados
**213–227** en `Tools/asset-pipeline/prompts/gemini_pro/` con sus 15 entradas
gemelas en `prompts.json`, todas en `estado: pendiente` y **sin campo
`referencia`** (los iconos de UI no adjuntan el Fisura). No se generó ninguna
imagen a propósito: el runner tipea con `osascript` y el permiso de
Accesibilidad lo tiene **Terminal.app y nada más** (trampa 11), así que desde
el shell de un agente falla en el primer asset. La receta, con el Chrome
dedicado en `:9222` logueado en Gemini **Pro**:

```bash
cd Tools/asset-pipeline
.venv/bin/python scripts/launch_gemini_chrome.py          # 1 vez, login manual
.venv/bin/python scripts/gemini_selenium_runner.py --dry-run   # tiene que listar 213–227
nohup caffeinate -is .venv/bin/python scripts/gemini_selenium_runner.py \
  --process --pause 3 --timeout 260 &
```

Sin `--ref-threshold` y sin `xcodegen` (no hay Swift y el atlas es folder
reference). ⚠️ **Post-batch hay que medir el % de píxeles opacos del `@2x`**
en `FisuEvolution/Resources/ui.atlas/`: `rembg` se come los rellenos
interiores claros y grandes (bug #6 de `HANDOFF-arte-gemini.md`), y los de
riesgo alto son `ui_menu_stats`, `ui_trophy_silver` y `ui_daily_calendar`. El
que salga hueco **no se integra** — se borran sus `@2x`/`@3x` y su clave de
`manifest.ui`, y el juego vuelve solo al icono vectorial, que para eso está.

**2. Costura de los 15 iconos: las tres copas ya están; falta el calendario.**

✅ **Los tres `ui_trophy_*` quedaron cableados en la ola final del review**
(2026-08-16). Eran **DOS** call-sites y no tres —el conteo de tres que figuraba
acá estaba mal: `MenuView.swift:65` nunca fue un pendiente, porque su copa ya
pasaba por `GameIcon` vía la clave `ui_menu_trophy` del propio menú—. Los dos
que faltaban ahora envuelven el vector con
`GameIcon(artKey: "ui_trophy_\(tier.rawValue)")`, que mapea el metal al sufijo
de la clave del atlas:

- `FisuEvolution/UI/Menu/AchievementsView.swift` (la copa de cada fila, 42 pt)
- `FisuEvolution/App/RootView.swift` (la copa del toast, 34 pt)

Mientras el atlas no tenga las claves siguen cayendo al vector y no cambia
nada en pantalla; el día que el batch entre, entran solas.

⚠️ **El pendiente real es `ui_daily_calendar`.** `VectorCalendarIcon` sólo se
declara en `GameIcons.swift:543` y no se usa en ninguna vista: no hay dónde
aterrizarlo sin **decidir antes dónde va el calendario** (la tira de días de
Regalos tiene su propio dibujo, y meterle un icono es una decisión de diseño
del dueño, no una costura mecánica). Hasta que esa decisión exista, ese PNG
entra al atlas y el juego lo ignora.

**3. Los ajustes ya están listos para App Store.** `SettingsView` trae las
seis secciones del spec: **idioma** (sistema/es/en, con su clave propia
además de `AppleLanguages`), audio, juego, compras (con "Restaurar"),
**legales** y "Acerca de". Las **notificaciones** tienen recordatorio diario a
las 19:00 vía `NotificationsManager`, y los **dos documentos legales**
(privacidad y términos) se leen adentro del juego, en es+en, desde
`Resources/Legal`. O sea que RF-02c ya no necesita nada de UI: lo único que
falta sigue siendo la cuenta de Apple Developer.

**4. Falta el review integral de la rama** —con su ola de fixes sobre los
minors diferidos de las 20 tareas, que viven en el ledger del workspace SDD—
y después el **merge a `main`**.

---

⚠️ **El programa de las 16 correcciones está CERRADO** (2026-08-07). Un jugador
externo terminó el juego y mandó 16 pedidos; las cuatro olas se ejecutaron y
**14 de los 16 están hechos y testeados**. Los otros dos no esperan código.

Auditado el 2026-08-07 **contra el código, no contra los docs** — porque un
handoff que dice "hecho" es exactamente lo que nadie vuelve a comprobar:

| RF | Dónde se comprueba |
|---|---|
| 01 tutorial · 03 lista · 04 dos botones · 06 descripciones · 08 mapa · 15 carreras · 16 prestigio | sus tests de UI y unitarios |
| 05 caras | **43 caras para 43 tipos concretos**: cobertura exacta del manifest |
| 07 ORO | `oro.exponent` en 0,45, calibrado con `pacing-sim` (`balance-log`) |
| 09 scroll | `BoardScene.floorDelta`, invertido, umbrales de 48 pt y 1,5× intactos |
| 10 torre | 37 tiers en 10 pisos, `FloorTable` valida la cobertura |
| 11 videos | `cooldownSeconds: 14400` por recompensa, en `meta.rewardedActivations` |
| 12 boosts | los 6 gateados por piso en `boosts.json`: mate→alley, café→corporate, fernet→island, asado→mars, milanesa→galaxy, turbo→god_realm |
| 13 skins pagas | las dos, vendidas contra el `.storekit` |
| 02a/02b tienda | 10 productos; packs de plata, de ORO y el combo |

**Los dos que faltan, y por qué ninguno es programación:**

| RF | Bloqueado por | Qué lo destraba |
|---|---|---|
| **02c** · alta en App Store Connect | La cuenta de Apple Developer (USD 99) | Que el dueño la saque |
| **14** · música y efectos | **No hay fuente de audio.** Re-verificado el 2026-08-07: no queda ninguna herramienta de generación de audio en la sesión | Un MCP con música/SFX standalone, o audio CC0 a mano |

📄 **Los dos están desarrollados hasta donde se puede sin el gate, en
`Docs/HANDOFF-gates-pendientes.md`**: la lista de los 12 archivos de audio con su
evento y su duración, y la tabla de los 10 productos lista para cargar en App
Store Connect. Ahí también está corregido un error del spec: **"integrarlo es
cero Swift" no es exacto** — RF-14 pide un efecto para "piso nuevo desbloqueado"
y ese evento **no existe** (hoy suena `.evolution`, compartido con cualquier
ascenso). Son tres líneas, y se hacen junto con el archivo.

| Documento | Qué es |
|---|---|
| `superpowers/specs/2026-08-06-correcciones-de-playtest-design.md` | **Los 16 pedidos como RF-01…RF-16**, con criterio de aceptación |
| `superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md` | Los 8 personajes nuevos, la baja de `kiosco` y el remapeo a 10 pisos |
| `superpowers/plans/2026-08-06-ola-{0,1,2}-*.md` | Los planes de ejecución, con el reparto por frentes |

### Lo que queda, y que NO sale del spec

Encontrado de paso y sin dueño. Ninguno es urgente:

- **La tienda se cuelga en "Loading…" cuando StoreKit no responde**, en vez de
  caer al mensaje de error que sí existe. `Product.products(for:)` no vuelve
  nunca y no hay timeout. Se ve lanzando por `simctl`, que **no** inyecta el
  `.storekit` (sólo lo hace el esquema de Xcode, también en device).
- **La fila de mejoras dice el nombre dos veces con VoiceOver**: la carita quedó
  como elemento de accesibilidad con el nombre de etiqueta, y el `Text` de al
  lado sigue ahí.
- **El título flotante de los paneles deja pasar el texto por detrás** al
  scrollear. Es de todos los paneles, no de uno.
- **~81 MB de los ~115 del `.app` son los fondos**, con ~54% de píxeles que no
  se ven nunca (`HANDOFF-perf.md`).

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
4. **Las 4 recompensas de carrera** (aprobadas 2026-08-06). Programador → cofre
   de plata · Arquitecto → la skin "Pie de Obra" · Médico → un Café Cargado
   gratis que no consume cooldown · Abogado → contratar a −50% por 10 minutos.
   Son de **tipo distinto entre sí a propósito**: cuatro variantes del mismo
   premio no son una elección. Viven en `Config/careers.json`.
5. **Los 8 nombres de skin de los personajes nuevos** (aprobados 2026-08-06):
   `naranjita`, `malabarista`, `feriante`, `chatarrero`, `holdout`, `jubilado`,
   `tropero`, `figurita`. Son **ganables, no pagas** — las únicas pagas siguen
   siendo las dos del Fisura y Dios. Existen porque el repo pinea que todo
   personaje concreto tenga skin catalogada.

**Con el spec cerrado, lo que sigue es F6**, que son todos gates humanos: cuenta
Apple Developer (USD 99), nombre comercial, App Store Connect, TestFlight,
submit. El ship-prep técnico ya está (`Distribution/`, entitlements, CI, privacy
pages). Y antes que nada, **que el dueño lo juegue**: los bugs más caros de estas
sesiones aparecieron mirando la pantalla, no corriendo tests.

✅ **Y eso ya pasó, el 2026-08-10.** De jugarlo salieron los dos pedidos de esa
sesión, y los dos apuntaban a lo mismo: cosas que el juego hacía pero no se
veían ni se sentían. Fusionar era fiddly —y abajo había un bug real de puntería
que ningún test agarraba— y los bonus corrían sin ningún rastro en pantalla.
**El patrón se repite: lo que falta no es lógica, es que la lógica se note.**

Anotado por si algún día importa, con su medición:

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
| **`HANDOFF-gates-pendientes.md`** | **RF-14 y RF-02c, los dos únicos pendientes. La lista de audio y la tabla de productos, listas para ejecutar cuando el gate se abra** |
| **`SESION-2026-08-06-correcciones-de-playtest.md`** | **El estado de la sesión de las 16 correcciones: qué quedó abierto, qué está en vuelo y los gates humanos. Empezá por acá si retomás ese trabajo** |
| `SESION-2026-08-05-fallback-de-contratacion.md` | El fallback del botón y la fila trasera invisible |
| `superpowers/specs/2026-08-10-fusion-asistida-design.md` | Los dos gestos de fusión, con los radios y por qué cada uno |
| `superpowers/specs/2026-08-10-contadores-de-bonus-activos-design.md` | Los contadores del HUD y por qué la proyección no lleva el tiempo |
| `superpowers/specs/`, `superpowers/plans/` | Specs y planes por feature |
