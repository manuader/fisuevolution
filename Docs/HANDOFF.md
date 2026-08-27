# HANDOFF — FisuEvolution, estado actual

> ✅ **EL REDISEÑO DE UI ESTÁ COMPLETO Y MERGEADO** — 20 de 20 tareas
> (`feature/rediseno-ui-cowevolution`, cerrado el 2026-08-16). El estado tarea
> por tarea, las decisiones del dueño y los avisos vivos siguen en
> **`Docs/SESION-2026-08-14-rediseno-ui.md`**, que es la fuente de verdad del
> detalle de ESA rama. Lo de abajo describe el juego ANTES del rediseño y
> sigue siendo válido para todo lo que el rediseño no tocó; el resumen de esa
> sesión, con los números de tests de su cierre, está en §4.
>
> ✅ **Y el ticket post-merge que ese cierre dejó triageado TAMBIÉN está hecho**
> — 7 tareas en `fix/cierre-post-merge` (18 commits sobre `89f215a`, mergeada a
> `main` en `e4d4ce6` y **PUSHEADA — `origin/main` está al día y la trampa 7
> quedó cerrada**), con review integral de rama que dio **ready to
> merge y CERO ola de fixes de código**. El detalle está en
> **`Docs/SESION-2026-08-16-cierre-post-merge.md`**. Lo que hay que saber en dos
> líneas: el calendario del daily aterrizó en Regalos, y
> **`AscentRenderingUITests` volvió de entre los muertos** — la suite de UI
> corre **43 sin un solo `-skip-testing:`** (§6).
>
> ✅ **Y el batch de los 15 iconos TAMBIÉN corrió** (2026-08-16, `d304fe3`):
> los 15 integrados al atlas con opacidad sana y cero descartes — la UI dejó
> los vectoriales, que quedan de fallback. ⚠️ **Lo único que falta son los dos
> gates humanos de F6**: la cuenta de Apple Developer (RF-02c) y la fuente de
> audio (RF-14). No queda NINGUNA tarea de código pendiente.
>
> ✅ **Y el rediseño de la PANTALLA PRINCIPAL está hecho** — 6 tareas en
> `feature/rediseno-pantalla-principal` (19 commits sobre `4c1e67c`): las 5 del
> plan más una **enmienda del dueño a mitad de vuelo**, todas cerradas y las de
> código revisadas. La pantalla dejó de ser un tablero con islas flotando:
> las **dos barras son gemelas en crema con contorno ink** y están **fundidas a
> su borde** (arriba y abajo), los **iconos de los 6 tabs son gigantes y llevan
> su nombre debajo**, la **barra de estado se oculta de verdad** (le faltaba la
> clave compañera en `project.yml`), y hay un **botón nuevo que contrata sin
> abrir FisuJobs** (`hud.quickhire`) — nació vendiendo "el mejor tier que la
> plata alcanza" y **desde el 2026-08-21 vende el TIER BASE del piso más alto**
> (§4, rebalance de pacing). El
> detalle está en **`Docs/SESION-2026-08-17-rediseno-pantalla-principal.md`**.
> Números de su cierre: EconomyKit **200** · app **370** · UI **44 sin un solo
> `-skip-testing:`** (los 183/346/43 de más abajo quedaron viejos). ⚠️ Dos cosas
> para tener a mano: en **SE la barra va a 374 de 375 pt** —los iconos no crecen
> más sin sacrificar los labels— y un `Button` de SwiftUI **publica su label
> como hijos de AX pase lo que pase**: sólo `accessibilityRepresentation` lo
> aplana sin romper el hit-testing (la tabla de las 5 formas medidas quedó en
> `QuickHireButton.swift`).
> ✅ **Y el rediseño v3 —los MATERIALES de las referencias— está aplicado a
> las 13 pantallas y los 7 popups** (2026-08-17, `feature/rediseno-v3-referencias`):
> interior pergamino, bordes tono-sobre-tono, pills caramelo, cinta con
> pliegues y destellos, la familia del menú en marco de madera vectorial,
> Regalos en madera+toldo+moño y el Ascensor en metal. Cero lógica tocada,
> cero strings nuevos, contratos de AX intactos. El detalle vive en
> **`Docs/SESION-2026-08-17-rediseno-v3.md`**; la trampa nueva que dejó la
> sesión (el cwd del agente que se vuelve solo al checkout principal) está en
> §7, trampa 16.
>
> **Empezá por acá.** Última actualización: **2026-08-25** (tres correcciones
> de UI del tutorial y los specials, y la cadena post-Xcode-26.6 desarmada —
> la sesión en §4, la trampa 30 en §7. ⚠️ Desde hoy los sims de verificación
> van con runtime **iOS 26.5**: una app compilada con el SDK 26 sobre un sim
> 18.6 se ve rota).

---

## 0. Cómo se usa este documento

**Si sos un agente que recién llega, leé dos cosas y sólo dos**: este documento
(el general) y el handoff más reciente de `handoffs/`. Con eso sabés dónde está
parado el proyecto sin leer las doce sesiones.

El reparto es a propósito:

| Dónde | Qué va | Vida |
|---|---|---|
| **este general** (`Docs/HANDOFF.md`) | lo que sigue siendo cierto: arquitectura, reglas, decisiones que no se re-litigan, trampas ya pagadas, y §4 con una entrada por sesión | permanente, se ACUMULA |
| `Docs/SESION-<fecha>-<tema>.md` | el detalle de UNA sesión: qué se pidió, qué se midió, qué se decidió y por qué | permanente, no se toca después |
| `handoffs/HANDOFF-<fecha>-<tema>.md` | el estado AL CIERRE: qué quedó abierto, qué está en vuelo, qué romper no hay que | efímero, **gitignored** |

**Al terminar tu trabajo, siempre hacés tres cosas:**

1. Escribís tu `Docs/SESION-…` con el detalle y el PORQUÉ de cada decisión.
2. Dejás tu `handoffs/HANDOFF-…` con lo que queda abierto para el que sigue.
3. **Actualizás este general**: una entrada nueva arriba de §4, y lo que
   corresponda en §5 (decisiones), §7 (trampas nuevas) y §9 (mapa).

El paso 3 es el que se olvida y el que sostiene todo: sin él, el próximo agente
tiene que leer doce sesiones para entender el presente. Si encontrás acá un dato
vencido, **corregilo** — un general desactualizado es peor que no tenerlo,
porque se le cree.

Regla de oro para lo que escribas: **anotá lo que costó tiempo y no se deduce
del código**. Los números que calibraron una decisión, el diagnóstico que
resultó falso, el orden en que hay que hacer las cosas. Lo que el código ya
dice, no lo repitas.

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
  **Salvo que el script escriba el formato canónico**: se puede, y la receta
  —con la forma de verificarla antes de escribir nada— está en la trampa 29.
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
| `Data/tiers.json` | Los 37 tiers y la cadena de evolución. **Generado** desde `Tools/generate-tiers/Sources/main.swift` — editar el JSON a mano lo pisa la próxima regeneración. Su `displayName` es el **castellano**; el inglés vive en el catálogo bajo `tier.name.<id>` |
| `Data/assets_manifest.json` | **Único puente código→arte.** Sin entrada acá, placeholder programático — ⚠️ **salvo los fondos**, ver abajo |
| `Config/skins.json` | Catálogo de apariencias |
| `Config/*.json` | Eventos, specials, upgrades, boosts, daily, feature flags |

Agregar un piso = una entrada en `floors[]` + el PNG del fondo. Agregar un
personaje = PNGs al atlas + entrada en manifest/tiers **+ su `tier.name.<id>` en
el catálogo de strings**. **Cero código.** Hay un `ExtensibilityDrillTests` que
lo prueba con un piso 12 declarado sólo como dato.

⚠️ La clave del nombre es la que se olvida, y falta **en silencio**: sin ella el
personaje se ve en castellano con el juego en inglés, porque `localizedName` cae
al dato. Quien avisa es
`GameContentValidationTests.everyTierHasItsNameInBothLanguages` (§4, sesión de
los nombres en inglés).

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

### Sesión del 2026-08-26/27 — Los cofres de skins

Las 41 pintas de piso dejaron de otorgarse al llegar a un piso: ahora **sólo salen de
cofres**. Ocho tareas cerradas, 32 commits, 78 archivos.

- **La bolsa son 41 skins en 4 rarezas** (7 comunes / 14 raras / 12 épicas / 8 legendarias),
  y la rareza sale del piso donde **vive** el personaje. "Rara" tiene 14 porque el piso
  corporativo tiene **diez** personajes: la bifurcación de carrera mete cuatro `junior` en
  T11 y cuatro `senior` en T12.
- **La promoción de rareza es lo que hace que el sistema cierre.** Hay 7 comunes con peso
  55/100: se agotan cerca del cofre 12. Sin promoción, desde ahí más de la mitad de los
  cofres pagaría plata con 34 skins sin sacar. Con promoción, todo cofre da skin nueva —41
  exactos— y las legendarias quedan para el final.
- **El mecanismo es no tocar `SkinMilestones`**: la entrada declara `chestRarity` **en lugar
  de** `floorReached`, y como `isMilestone` mira los tres criterios viejos, cae a `false`
  sola. La doble vía no puede existir por construcción.
- **Save v5**, con el arreglo de las skins doradas que estaba esperando este bump.
- **La animación son cuatro toques** y la rareza se anuncia en el segundo, con el cofre
  todavía cerrado.
- **"Cofre" se renombró**: el boost del asado ahora paga "una picada".

**Falta para que un jugador lo use**: la tarjeta en Regalos (hoy `openChest()` existe y
ningún botón lo llama salvo la puerta de debug), el carrusel de Pintas, y el cofre del
tutorial. Detalle en `Docs/SESION-2026-08-26-cofres-de-skins.md`.

### Sesión del 2026-08-23 (ter) — La desaceleración, y el build que volvió a andar

`fix/rebalance-pacing`. **El diagnóstico**: con el precio anclado a la frontera y
nada más, cada tier costaba el MISMO tiempo que el anterior — 37 tiers ×
constante— y **la run no se trababa nunca**. Por eso se podía ir de Fisura a Dios
de una sentada y por eso reencarnar no pagaba: se reencarna para correr una
pared, y no había pared. Un solo dial no podía arreglarlo porque el problema no
era la constante sino **la forma de la curva**.

**La regla de precios suma un tercer renglón** (ver §5.2): del **tier 7** para
arriba tu propia frontera se encarece un **60 %** por tier, por encima de lo que
ya sube por rendir más (`frontierEscalationPerTier` 1,6 con
`frontierEscalationFromTier` 7). El umbral no es adorno: sin él la escalada es
una exponencial desde el tier 1 y las primeras cinco runs se traban **en el
callejón**, que es la frustración que el diseño evita.

**El contrato pasó a ser una FORMA y ahora es medible.** `Report` publica tres
series nuevas y `pacing-sim` las imprime: dónde se traba cada run, cuánto corre
la pared, y cuánto paga reencarnar. "Trabarse" es un número —el primer tier cuyo
paso al siguiente cuesta más de una SESIÓN entera de juego activo— y el umbral
sale del modelo humano, no de un literal a dedo.

Medido: `— · T12 · T13 · T14 · T16 · T18 · T20`, corriendo `+1 · +1 · +2 · +2 · +2`.

**Los dos contratos que se destrabaron**: maxear las siete mide **20,67 h
activas** (el primer assert de `theOwnersTargetsAreMet` pasa por primera vez), y
**el que no reencarna ya no llega a dios** (tier 29 de 37 a los 400 días, contra
28,43 h reencarnando) — el contrato 5 nunca había cerrado en cuatro rondas.

🔴 **Lo que queda**: 9 reencarnaciones contra las ≤8, y reencarnar paga 7-40 %
contra el ≥67 % pedido. El techo del pago es estructural y está medido: volver a
la pared cuesta las mismas ACCIONES que la primera vez y el ORO saca la espera,
no las acciones. Pide una mejora permanente que acorte la SUBIDA, que hoy no
existe en el catálogo.

⚠️ **La compuerta NO se movió a 7** aunque estaba medida como jugable: con la
desaceleración dando el largo, N=7 empeora la FORMA (su piso de acciones le pone
techo a lo que puede pagar reencarnar). Se queda en 6, con el número en la
bitácora.

**Y el proyecto vuelve a compilar solo.** Desde Xcode 26 no compilaba sin flags a
mano: un header de Apple (`SKPaymentTransactionState`, deprecada en iOS 18) rompía
el build entero porque el proyecto trata los warnings como errores. Arreglado con
`-Xcc -Wno-deprecated-declarations` en `Debug` y en los dos targets que importan
`StoreKitTest`, **sin tocar `SWIFT_TREAT_WARNINGS_AS_ERRORS`** (ver §7, trampa 38).
Verificado: build limpio sin flags, cero warnings propios, y un warning nuestro
metido a propósito sigue rompiendo. **Para jugarlo alcanza con abrir el proyecto
en Xcode y darle Run.**

Detalle y barridos: `balance-log.md`, "Cuarta ronda (ter)". Doc de sesión:
**`Docs/SESION-2026-08-23-desaceleracion.md`**. Corrida:
`balance-run-t11-desaceleracion.csv`.

### Sesión del 2026-08-23 (bis) — Las fusiones se cobran, y el barrido de la profundidad

`fix/rebalance-pacing`. **El simulador dejó de regalar las fusiones**
(`HumanModel.mergeSeconds`, 1 s). Era un sesgo y no una simplificación: fusionar
es el verbo central del juego —una acción por fusión— y subir un tier de frontera
pide `2^N − 1` de ellas, así que el instrumento medía a un jugador que compra con
el dedo y fusiona con la mente. Sesga justo el eje sobre el que se calibra: la
proporción compras/fusiones es lo que mueve la profundidad de la compuerta.

⚠️⚠️ **Acá se corta la comparación con todas las bandas anteriores de la rama**:
cualquier número previo al `800755c` se midió con el merge gratis.

Efecto: maxear 7,27 → **6,67 h**, dios 9,40 → **8,97 h**, y la 1ª reencarnación
4,28 → **9,00 h de pared**. Las horas ACTIVAS bajaron, que es lo contrario de lo
esperado: cobrar las fusiones quema presupuesto de SESIÓN, el bot llega antes al
final de cada una y parte del progreso se paga con income offline —reloj de
pared, no de dedo—.

**El barrido de la profundidad, con el instrumento corregido**: N=6 → 6,67 h ·
N=7 → 186,33 h (muro del early game) · **N=7 con el callejón destrabado
(`floors[0].hireCostGrowth` 1,02) → 13,33 h**, 8 reencarnaciones, dios a 21,21 h
y cadencia que sube pareja de 1,1 a 2,6 h · N=8 **no es jugable** (pelado no
termina; destrabado pide 9 reencarnaciones y saltos de 29-41 h).

⚠️ **La profundidad es lo ÚNICO medido que da vuelta la trampa de reencarnar**, y
el cruce cae entre 7 y 8: con N≤7 el que no reencarna llega ~3× más rápido, con
N=8 no llega nunca. El contrato 5 y los contratos 2-3 tiran para lados opuestos
del MISMO dial.

**La compra en lote se empezó y se descartó** (objeción del dueño, correcta: sólo
entran 10 por piso, comprar de a más ACORTA el juego, y por lo tanto no es una
palanca de duración). No quedó nada en el árbol; el porqué está en el doc de
sesión §4 para que no se re-proponga sin leerlo.

Detalle: **`Docs/SESION-2026-08-23-fusiones-cobradas.md`**. Números:
`balance-log.md`, "Cuarta ronda (bis)". Corrida:
`balance-run-t10-merges-cobrados.csv`.

### Sesión del 2026-08-23 — El precio atado a la frontera, y el reloj que no era de plata

`fix/rebalance-pacing`, cuarta ronda. **El precio de contratar dejó de seguir a
`tapYield(tier)` y pasa a anclarse en tu FRONTERA de merge** (decisión del dueño,
Opción 1 de la ronda anterior):

    mult(piso) × tapYield(FRONTERA) × factorDePiso
              × priceGrowthPerTier^(tier − frontera) × growth^compras

La derivación, que es lo que hace que no sea una preferencia: el diseño quiere
que subir un tier cueste siempre lo mismo en TIEMPO (⇒ precio ∝ rendimiento de tu
frontera ⇒ pendiente 2,8 por tier) **y** que la pendiente del precio sea ≤ 2, el
factor de merge (⇒ o si no comprar hondo es más barato). Con un precio `f(tier)`
las dos son contradictorias. Anclarlo a la frontera separa el **nivel** (2,8 por
tier de frontera, pacing plano) de la **pendiente** (`priceGrowthPerTier` = 1,5,
atajo cerrado). Comprar hondo pasó de costar `0,71^d` a costar **`1,33^d`**.
`tierPremium` se borró: bajo la fórmula nueva dejaría la pendiente dentro del
piso en 2,8 × 1,8 = 5,04, o sea el agujero otra vez.

Con eso **la compuerta se volvió por fin un dial de dificultad** (N=5 → 4,14 h ·
N=6 → 7,27 h · N=7 → 185,63 h) y subió a **6**.

⚠️ **El contrato de 20-30 h sigue sin cumplirse (7,27 h), y la causa que queda es
otra**: el simulador cobra 1 s por compra y **la mitad del tiempo activo del bot
es apretar el botón, no esperar plata** (sin ese segundo, maxear cae de 4,14 h a
2,19 h). Por eso todos los knobs de precio son sublineales —×16 en
`defaultCostMultiplier` compra ×1,75 de partida— y por eso el atajo viejo estaba
sosteniendo la mitad del largo del juego sin que nadie lo hubiera diseñado.
`PacingTests.theOwnersTargetsAreMet` **sigue en rojo**.

Tercera ceguera del bot arreglada, misma clase que las dos anteriores: elegía la
contratación **más barata**, que con el precio nuevo es la PEOR (el Fisura). Ahora
elige la más barata **por unidad de frontera**.

Lo que mejoró, medido: la **fase fisura casi se triplicó** (28,0 → 78,0 s activos)
sin tocar el Fisura, el **peor salto entre hitos bajó a 2,02 h** (4,45 h en la
ronda 3, 10,0 h en la segunda) y ahora hay un test que lo mide en HORAS y sobre
los diez pisos (`noHitoJumpIsLongerThanFourActiveHours`).

Detalle: **`Docs/SESION-2026-08-23-precio-atado-a-la-frontera.md`**. Números y
barridos: `balance-log.md`, "Cuarta ronda". Corrida:
`balance-run-t9-precio-frontera.csv`.

### Sesión del 2026-08-22 — La compuerta por distancia, y el bot que no era el jugador

`fix/rebalance-pacing`, tercera ronda. **La compuerta de contratación pasó de
medirse en PISOS a medirse en TIERS**: un tipo de tier `T` se contrata sólo si
`run.maxTierReached >= T + N`, con `N = 5` en `economy.json`
(`hire.gateTierDistance`) y el tier base de la torre exento. La regla vieja tenía
un borde dentado —un piso son cuatro tiers y FisuJobs los vende todos, así que lo
que ataba era el TOPE del piso habilitado, a UN tier de la frontera— y por eso
todo pasaba entre dos pisos contiguos y el ascensor no se usaba nunca.

⚠️ **Y el titular es otro, incómodo: el contrato de 20-30 h nunca se cumplió.**
Arreglar dos cegueras del simulador —elegía la peor mejora por personaje, y sólo
compraba el tier BASE de cada piso cuando FisuJobs vende todo lo contratable—
destapó que la partida embarcada dura **13,64 h activas hasta dios y 6,67 h hasta
maxear las siete**, no las 24,67 h que la ronda 2 creyó medir. Sin reencarnar,
dios llega en **3,28 h**, que es al minuto lo que el dueño reportó a mano ("me lo
gané en 3 horas"). `PacingTests.theOwnersTargetsAreMet` **queda en rojo a
propósito** (unit 410/411): no se afloja y no se re-pinea.

La causa es estructural y está medida: `yieldGrowthPerTier` (2,8) le gana al
factor de merge (2), así que comprar hondo siempre sale más barato y **una
compuerta más profunda ABARATA el juego** (N=4 → 6,67 h · N=6 → 5,34 h · N=8 → la
partida no se termina). Ningún knob llega a 20-30 h: los nueve están medidos en
`balance-log.md` y ninguno pasa de ~13-17 h porque la torre entera dura eso. Las
tres salidas —y son decisión del dueño— están en el doc de sesión.

Lo que sí mejoró: el acantilado corporate → luxury pasó de **×90,86 a ×5,27** (la
guarda de `floorGradient` bajó de 118,1 a 10,21), ningún salto entre hitos pasa
de 4,45 h activas, los dos parches por piso (callejón exento y `hireGateExempt`
del urbano) desaparecieron, y **la autorización por tipo existe**: antes el único
lugar del juego que gateaba por tipo era la proyección `jobRows`.

Detalle: **`Docs/SESION-2026-08-22-compuerta-por-distancia.md`**. Números y
barridos: `balance-log.md`, "Tercera ronda". Corrida: `balance-run-t8-compuerta.csv`.

### Sesión del 2026-08-22 — El multiplicador secuencial, y el atajo de no reencarnar

`fix/rebalance-pacing`, segunda ronda. **Las mejoras POR PERSONAJE dejaron de ser
`2^nivel` y pasaron a ser `1 + nivel`: ×2, ×3, ×4 … ×20** (pedido textual del
dueño). El efecto al tope cayó de ×1.048.576 a ×20 y el knob se renombró
(`effectFactorPerLevel` → `effectStepPerLevel`) porque ya no es la base de una
potencia; `maxLevel` bajó de 20 a 19, que es lo que clava el ×20 que él escribió.

La otra mitad del pedido —"hacé que sea más difícil subir de piso"— se contestó
midiendo la partida que él describió, que **el simulador no podía correr**: de
fisura a dios SIN REENCARNAR. Eran **10,47 h activas** contra las 26,59 h de
reencarnar, o sea el atajo era 2,5× más rápido; ahora son **66,34 h**, 2,0× más
lento. Y el barrido de política quedó monótono: cuanto más se posterga la
reencarnación, peor, en las dos métricas.

Las cuatro métricas: **maxear 24,67 h activas · 8 reencarnaciones · dios 33,23 h
activas · dios sin reencarnar 66,34 h**. Calibrado con dos knobs
(`charUpgrades.costGrowth` 4,0 → 1,5 y `oro.divisor` 3e12 → 1e9), cada uno medido
solo. Detalle y descartes en `Docs/SESION-2026-08-22-multiplicador-secuencial.md`
y `Docs/balance-log.md`.
### Sesión del 2026-08-25 — Tres correcciones de UI, y Xcode 26.6

El botón del cierre del tutorial ganó su aire; **la manito de «tocá acá» se
volvió UN componente (`TapHereHand`)** y vive ahora también en el coach de
lecciones, la fila recomendada de FisuJobs, la tarjeta de Logros (junto al
badge) y las pintas sin estrenar; y **la carta del personaje especial muestra
la SKIN en grande** (168 pt, detent 0,66) y se REABRE manteniendo apretado al
personaje en el tablero (`specialInfo`, fuera de la cola; fixture nuevo
`--uitest-special`; UI test del circuito completo). En el medio, **Xcode
saltó a 26.6 y el juego «se veía espantoso»**: era la cadena post-update —
override de runtime, runtime 26 ausente, module cache mixto, el -Werror del
importer y el abort de SKTestSession — desarmada eslabón por eslabón en la
**trampa 30**. Detalle en
**`Docs/SESION-2026-08-25-correcciones-ui-y-xcode-26.md`**. Números del
cierre (sim iOS 26.5, receta §6): EconomyKit **234** · unit **413** · UI
**49 sin fallos ni skips**.

### Sesión del 2026-08-21 (noche) — Los personajes se llaman en inglés cuando el juego está en inglés

Lo vio el dueño jugando: con el idioma en English el personaje seguía diciendo
"El Fisura". No era un hueco del catálogo —**las 475 claves tenían su
`en`**— sino que el nombre nunca pasaba por el catálogo: sale de `tiers.json`,
que es dato en castellano, y las 15 vistas lo dibujaban `verbatim`. Ahora pasa
por `CharacterType.localizedName`, que busca `tier.name.<id>` y **cae al
castellano del dato si la clave falta**, igual que las skins con
`skin.name.<id>`. Se sumaron las 44 claves y se corrigieron los 3 textos ya
traducidos que nombraban al personaje en castellano (el tutorial decía "I am El
Fisura").

La traducción es **cultural, no literal**, y el arte manda: el trapito es "The
Fake Valet", el limpiavidrios es "Squeegee Guy", el médico Jr. es "Medical
Resident" (que es lo que sos en EE.UU. cuando te recibís) y el dueño de PYME es
"Small Business Owner". Las 17 que no son literales están en una tabla con su
porqué en **`Docs/SESION-2026-08-21-nombres-en-ingles.md`**. ⚠️ **El tono no lo
aprobó el dueño todavía**: cambiar cualquiera es editar un `value` del catálogo,
no hay código atado a un nombre.

Números del cierre: app **413** · UI **48 sin skips** · EconomyKit **234** (no se
tocó el paquete). Cuatro asserts que pineaban el nombre en castellano pasaban
**por casualidad** —el runner corre en inglés (trampa 6) y el nombre no era
traducible— y pasaron a pinear lo que querían probar; `RevealBannerFitTests` ahora
mide los dos idiomas.

### Sesión del 2026-08-21 — El rebalance de pacing: ganarlo al máximo cuesta 24 h

`fix/rebalance-pacing`, con `fix/atajo-tier-base` y `fix/premios-y-eventos`
integradas — **y mergeada a `main` en `9efc8f7` el mismo día** (verificación
del árbol final en `Docs/SESION-2026-08-21-merge-rebalance-y-manito.md`). **Maxear las siete líneas permanentes —"ganarlo al máximo", lo que
desbloquea las skins doradas— pasó de 15,49 h a 24,00 h ACTIVAS y de 34
reencarnaciones a 8**; dios quedó a 26,59 h activas, o sea DESPUÉS de las skins.
Detalle en **`Docs/SESION-2026-08-21-rebalance-pacing.md`**, calibración corrida
por corrida en `balance-log.md`.

Lo que hay que saber sin abrirlo:

- **Son DOS knobs con dos efectos distintos**, y confundirlos costó una ronda: la
  **curva de ORO** (`divisor` 3e6 → 3e12, `exponent` 0,45 → 0,25) cierra la
  divergencia costos-vs-ingresos —entrar a un piso volvió a costar segundos de
  income en vez de 0,0 s—, y **`hire.defaultCostGrowth` (1,2 → 1,06)** es lo que
  hace la torre escalable: con el 20 % por compra **la partida no se puede
  terminar** (el bot se traba en el tier 11).
- **El atajo del HUD cambió de regla**: vende el **tier base** del piso más alto
  pagable, no el tier más alto. Ofrecer el más alto te saltea el merge, que es el
  juego. FisuJobs no cambió: sigue vendiendo todo lo desbloqueado.
- **Los premios de logros son SEGUNDOS de tu producción**, no un múltiplo de un
  costo: dos jugadores en el mismo tier con torres distintas cobran distinto. Y
  los **doce logros de ORO fijo bajaron de 620 a 33** — sumaban 3,2 veces lo que
  cuesta ganar el juego (§5).
- **Los eventos se espaciaron** de uno cada 5-8 min a uno cada 15-20 min, y la
  cara mala pasó a ser mayoría de peso sin apagar ninguno.
- **`PacingTests` se re-pineó entero** y ganó dos asserts que NO son bandas sino
  el objetivo del dueño (20-30 h activas, ≤8 reencarnaciones). El bot que medían
  las bandas viejas no era el jugador: se construía sin catálogo de mejoras
  permanentes.
### Sesión del 2026-08-21 (tarde) — El tutorial high-end

El tutorial se rehizo entero contra `PROMPT-tutorial-high-end.md`: la **fase
obligatoria quedó en 4 pasos** (tap → contratar → fusionar → cierre; murieron
los dos pasos que abrían vidrieras vacías) y **el resto de la app se enseña en
lecciones contextuales** — kind nuevo `.tutorialTip` en la CelebrationQueue,
una por vez, disparada la primera vez que hay algo que HACER en su pantalla
(la regla de oro del dueño; tabla de señales en la doc de sesión). La cola
ganó `restrict(to:)`: con la fase viva sólo el reveal del tablero toma el
turno, el resto espera en `pending` — eso mató el deadlock del daily
día-2-a-medias (repro en `CelebrationWiringTests`) y el reveal del primer
merge se ve **entero y limpio** (el overlay entero se esconde mientras dura).
El puntito rojo de logros (`ui_badge`, recortado al bbox: traía 86% de aire)
vive como `.overlay` en el tab Menú y la tarjeta de Logros, avisando por
`accessibilityValue`; su señal es la proyección nueva
`hasClaimableAchievements`. La tarjeta habla v3 (pergamino, retrato 96 pt
pisando el borde, pop de spring); la mano probó un vectorial de la casa y
volvió al SF Symbol del sistema por pedido del dueño (2026-08-21, post-merge
del rebalance). Poses: sólo `wave`/`celebrate` hasta que 117/118 se regeneren. Detalle y por qué de
cada decisión en **`Docs/SESION-2026-08-21-tutorial-high-end.md`**; trampas
nuevas 24 y 25 en §7. Números del cierre: EconomyKit **213** · app **395**
(3 rojos Pacing preexistentes) · UI **48 sin fallos ni skips**.

### Sesión del 2026-08-21 — El telón de las empujadas

Las cinco pantallas EMPUJADAS del menú (las cuatro de gabinete y los legales)
mostraban un telón blanco donde todas las demás hojas muestran el juego
atenuado: UIKit le pinta `systemBackground` al hosting controller de un destino
empujado y el `.presentationBackground(.clear)` de la hoja no alcanza. Arreglo:
`clearNavigationBackdrop()` (PanelFrames.swift) sobre el contenido de los dos
`navigationDestination` — en iOS 18 la API, en 17 una sonda UIKit **que quedó
sin verificar** (no hay runtime 17 instalado). Medido antes/después con
píxeles de captura. Detalle en **`Docs/SESION-2026-08-21-telon-del-menu.md`**;
la trampa es la 23.

### Sesión del 2026-08-19 — Oro y diamante para los 43

**86 skins nuevas** (43 de oro macizo + 43 de diamante tallado), una por cada
personaje con arte: los 44 tipos menos `junior`, que es el nodo de carrera y no
tiene sprite. Detalle en **`Docs/SESION-2026-08-19-skins-oro-diamante.md`**.

Lo que hay que saber sin abrirlo:

- **Un id por material, no por personaje.** Las 43 de oro comparten `id: "oro"`
  y las de diamante `id: "diamante"`. Eso movió la unicidad de
  `SkinsConfig.validate` de global a **(personaje, id)** — la convención
  `<baseKey>__<skinId>` exige que el id sea el sufijo. A cambio sale gratis lo
  que se quería: la propiedad se guarda POR ID, así que **un único producto
  desbloquea el bundle entero** sin inventar un campo de paquete.
- **Desbloqueo**: el oro NO se vende (`upgradesMaxed`, las siete mejoras
  permanentes al tope); el diamante sólo por
  `com.fisuevolution.iap.skins_diamante` (19,99).
- **La silueta es el argumento de venta**: la ficha esconde TODO lo no
  adquirido, también lo que está a la venta. La tienda las muestra a color a
  propósito.
- **El recorte se eligió a mano, asset por asset**: las 43 de oro con saliencia,
  33 de diamante con conectividad y 10 con saliencia. Ninguna herramienta gana
  siempre — ver §5.
- Tres bugs del pipeline de generación quedaron medidos y arreglados (el umbral
  de descarte, la cola compartida y la multiplicación de reintentos): §7.

### Sesión del 2026-08-18 — El recorte deja de comerse lo blanco

`process_dropbox.py` recortaba con `rembg`, un modelo de **saliencia**: con arte
cartoon sobre fondo blanco leía como fondo cualquier blanco del dibujo. Medido
sobre los 219 assets integrados, **102 tenían al menos un 2% del dibujo calado y
73 pasaban el 5%** — el guardapolvo del `senior_doctor` entero, las caras
translúcidas, los paneles sin su pergamino.

El criterio nuevo (`scripts/whitebg_cutout.py`) es **topológico**: fondo es lo
blanco que se toca con el borde del lienzo. Una camisa blanca está rodeada por
la línea del dibujo y por lo tanto no se puede recortar. **206 assets rehechos**
desde sus originales, que ya estaban en git. Detalle en
**`Docs/SESION-2026-08-18-recorte-de-fondo.md`**.

### Sesión del 2026-08-18 (tarde) — La hoja contenida

**Todas las hojas cambiaron de anatomía** (pedido del dueño, mismo
`feature/rediseno-v3-referencias`): el marco dejó de entrar como `.background`
y pasó a CONTENER a su hoja — cabecera adentro del pergamino y scroll
recortado que muere contra la banda inferior del marco, que quedó a la vista.
El patrón es `panelSheet(material:awning:header:ornament:)` en
`FisuEvolution/UI/Art/PanelFrames.swift`; por qué esto mata de raíz el
"título flotante" está contado en §8. Migraron las 12 hojas —FisuJobs,
Tienda, Mejoras, Pintas, Regalos (su `GiftBowOrnament` ahora entra por el
slot `ornament`), Menú, el mapa del Ascensor, organigrama, stats, logros,
ajustes y Legales— y todas se presentan con `.presentationBackground(.clear)`:
aplicado en `RootView` para las 6 de la barra y en `HUDView` para el
ascensor. `PrestigeView`, `CareerChoiceView` y `SkinAwardView` lo ganaron
también (los otros popups ya lo tenían): ya ningún popup muestra el
rectángulo del material de sistema alrededor de su marco de arte. El detalle
vive en el tercer arco de **`Docs/SESION-2026-08-17-rediseno-v3.md`**.

Cinco cosas más del día:

- **`IconButton` ganó `glyphAspect`** — el ancho del glifo como fracción del
  alto; con un valor ≠ 1 el arte se ESTIRA a propósito (pedido del dueño para
  el ascensor). Tras una ronda de ajuste en caliente (×0,85), la moneda+
  quedó en **56 pt** y el ascensor en **61 pt** con `glyphAspect` 0,86.
- **`ui_elevator`, `ui_coin_plus` y `ui_gift_bow` se recortaron al bbox del
  alfa** (+2% de aire): traían ~40–60% de lienzo transparente y por eso
  rendían chicos. ⚠️ Si el batch los regenera, vuelven con márgenes — la
  advertencia quedó en §8, punto 1.
- **Mejoras volvió a MADERA con toldo** (y el glifo de su tab en el título,
  como Pintas/Regalos/Tienda; el Menú ganó el suyo y sus tarjetas muestran el
  icono pelado a 84 pt). El metal quedó SOLO para el Ascensor: dos materiales,
  un criterio — metal = maquinaria de verdad.
- **La tienda funciona fuera de Xcode** (`fix(store)`): el `.storekit` del
  scheme sólo se inyecta cuando Xcode lanza la app; instalada por `simctl`
  StoreKit devolvía catálogo vacío y la pantalla quedaba en "sin conexión"
  eterno. Ahora el `.storekit` viaja en el bundle y `StoreManager` levanta en
  DEBUG una `SKTestSession` idéntica (bajo XCTest NO — los tests manejan la
  suya; trampa 4 sin agrandar). `StoreKitTest` vive fuera de los search paths
  de una app: sólo Debug prende `ENABLE_TESTING_SEARCH_PATHS`, y Release ni
  importa ni linkea el framework (el autolink sigue al `#if DEBUG import`).
- **Los siete popups hablan `PanelCard`** (PanelFrames.swift): el tablón de
  las hojas en escala de tarjeta —banda fina, tornillos, pergamino, ink,
  sombra— reemplazó a los CUATRO marcos de arte 9-slice con insets medidos
  por PNG. La familia de premio (daily/AFK/sorpresa) lleva el moño asomando
  arriba. `GamePanel` y `PanelBackground` quedaron sin llamadores y se
  RETIRARON de `GameArt.swift`; sus PNG (`panel_reward/career/prestige/
  dialog`) siguen en el atlas como reserva, igual que `panel_menu`.

### Sesión del 2026-08-17 (tarde) — Rediseño v3: los materiales de las referencias

**12 tareas + 2 rondas de fix** en `feature/rediseno-v3-referencias`, sobre
`c4e69ba`. La lectura que ordenó todo: el v2 ya TENÍA la estructura de las
referencias del dueño; lo que faltaba era la capa de materiales. Cinco
movimientos: (1) interior **pergamino** bajo todos los marcos (los PNG de
panel tienen interior transparente, alfa 8–15 — así que fue UN cambio en
`PanelBackground`/`GamePanel`); (2) bordes **tono-sobre-tono** vía
`Color.deepened()` (verde con verde oscuro, crema con marrón — la tinta quedó
sólo donde es decisión del dueño o contorno cartoon); (3) **`PillBackground`**,
la cápsula caramelo compartida (luz arriba, labio de brillo, borde hundido);
(4) la **cinta** con colas caídas, pliegues y ✦; (5) los dos marcos fuera de
idioma reemplazados — la familia del menú a `WoodPanelBackground` (madera
VECTORIAL con los tonos muestreados de `panel_store`) y Regalos a
madera+toldo+`GiftBowOrnament`. Detalle, decisiones y capturas en
**`Docs/SESION-2026-08-17-rediseno-v3.md`**.

⚠️ Dos cosas de esa sesión que valen más que el diff: la trampa 16 (§7, el
cwd que se vuelve solo), y que `GameCard.locked` ahora tiene dos sabores —el
misterio gris entero y `contentDimsWhenLocked: false` para el boost bloqueado
que se muestra a color (así lo pide la referencia de Regalos).

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
  `Palette*`, tipografía `Tokens.*`, cabecera crema opaca (retirada el
  2026-08-18: la cabecera vive adentro del panel — `panelSheet`, ver §8),
  `ArtCloseButton`.
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
| `FisuEvolutionUITests` | **40/40** ✅ (**15 clases corriendo de las 16** que tiene la suite; `AscentRenderingUITests` salteada, rojo preexistente de `main` — **recuperada más tarde ese mismo día**: la receta vigente de §6 corre las 16, **43 sin skips**) |
| `Tools/asset-pipeline` | 27, **1 rojo conocido** (pide Chrome en `:9222`) |
| Warnings de compilador | **0** |

⚠️ **Ningún flaky hizo falta re-correr**: `EconomyLoopUITests`,
`BonusHUDUITests` y `StoreManagerTests` pasaron en la corrida completa, y
`PacingTests.strugglingPhaseLength` —que figuraba como rojo de entorno— pasó
también. La regla que lo hace reproducible es **correr unit antes que UI**
(§7).

### Sesión del 2026-08-17 — Celebraciones de a una, y dos pantallas al día

**La cola de celebraciones** (detalle arriba y en su spec). Lo que hay que saber
si se la toca: el turno del ascenso lo pide `handleDrop` y **no** la escena, y esa
no es una preferencia de estilo — `updateMaxFloorStat()` acredita la skin de
milestone DENTRO del mismo merge, así que si la escena encolara después, el sheet
ya tendría el turno y taparía el vuelo y el reveal. Que es exactamente el bug que
la cola viene a arreglar. Lo cazó el test de wiring, no el simulador.

**La franja de abajo**: contratar y reencarnar comparten fila, cada uno contra su
borde. `PrestigeButton` es el espejo de `QuickHireButton` —misma cápsula, mismo
borde ink, mismo alto derivado de `QuickHireButton.capsuleHeight`— y era el último
`.buttonStyle(.borderedProminent)` de la pantalla principal.

**El fork de carrera** (`CareerChoiceView`) pasó a la anatomía de fila de
FisuJobs, con el **retrato de cada carrera**: era la última pantalla con botones
del sistema, y pedía la decisión más definitiva del juego sin mostrar a quién
elegías.

⚠️ **Y era la única pantalla del juego sin un solo test de UI** — no por descuido:
alcanzarla cuesta horas de partida y no vuelve hasta la próxima reencarnación. Por
eso se hizo vieja sin que nadie lo notara. Ahora hay `--uitest-career` (que además
marca `fisuTutorialDone`, porque el sheet está gateado por él y `--uitest-reset`
no lo toca) y `CareerChoiceUITests`. **Si una pantalla no se puede abrir con un
fixture, se va a poner vieja: es la lección, no el caso puntual.**

**La skin Reparto Cohete**, regenerada. Lo que fallaba era el prompt, no el
modelo: le sacaba a la vez los DOS anclajes de silueta del Repartidor (la
mochila-cubo y el casco) y encima pedía naranja, que es el color del personaje
base. Sin nada a lo que agarrarse, la primera pasada devolvió un vendedor
callejero con bandeja de golosinas y un gato. La receta que funcionó está en el
`.md` del prompt: **reskinear los anclajes en vez de borrarlos**.

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

**La contratación no queda muerta cuando el gate cierra** (2026-08-05): parado en
tu frontera, cae en el piso de **abajo** —que por la propia regla del gate es
siempre el más alto donde sí se puede—. `TowerActions.hireTargetFloor` decide el
destino.

⚠️ El botón que la dibujaba murió con la barra inferior, y su proyección
(`GameState.HireOffer`) se retiró el 2026-08-16 al quedar sin consumidor. **La
regla no cambió**: vive en EconomyKit, y la pinean `GameLoopWiringTests` —contra
el `economy.json` real, incluida la exención del urbano— y `EconomyKitTests`
sobre fixtures sintéticos.

📌 **Lo que se retiró es la proyección, NO el requisito de UX que la
justificaba**, y este ata a cualquier pantalla de contratación futura: **el
botón NOMBRABA el piso de destino, para que la compra no pareciera no haber
pasado.** Contratás parado en tu frontera, el personaje aparece un piso más
abajo y la cámara no se mueve: sin decirlo en pantalla, el jugador ve que pagó
y que no cambió nada, y eso se lee como un bug. Hoy la deuda está **latente y
no visible**, porque nadie ejerce el fallback desde la UI — FisuJobs contrata
por tipo y su `floorTag` nombra el piso PROPIO de cada fila, que es otro dato,
y `buySpawn()` quedó sin call-site de UI (sólo lo llaman los tests). El día que
una pantalla vuelva a ofrecer contratar "acá", **tiene que decir dónde cayó**;
el dato lo da `TowerActions.hireTargetFloor`.

#### Cola de celebraciones (2026-08-17)

**Todo lo que aparece solo se reproduce de a uno.** `CelebrationQueue`
(EconomyKit, pura) ordena TURNOS sobre identificadores; los payloads siguen donde
estaban y las vistas se presentan sólo si `GameState.showing` las nombra. Nueve
ítems con prioridad: offline y diario primero, después la carrera —que bloquea la
progresión—, el ascenso, los sheets de premio, y al final banners y toasts.

- **Un tap saltea** el ítem entero, pasados 0,6 s. Ese piso no es cosmético: sin
  él el tap siguiente mataría cada celebración y la cola se vaciaría en un segundo.
- **Watchdog por ítem**: lo que se cierra solo declara un tope y, si la señal no
  llega, la cola avanza y loguea. Con cola global, un bug así congelaría TODAS las
  celebraciones hasta reiniciar.
- **El turno del ascenso lo pide `handleDrop`**, no la escena: `updateMaxFloorStat`
  acredita la skin dentro del mismo merge, y si el ascenso encolara después el
  sheet ya tendría el turno y taparía el vuelo.
- La UI se apaga **del todo** —opacidad 0 y sin hit-testing (`celebrationHidesUI`)—
  pero **sólo cuando el merge trae algo NUEVO**: un personaje que no se había
  visto (reveal de tier — apaga SIEMPRE, abra piso o no) o un piso que se
  desbloquea por primera vez (`6afe1d8` + `7b0d613`, las dos frases del dueño
  citadas en `GameState.swift`). El único ascenso con el HUD a la vista es el de
  un personaje conocido a un piso ya abierto — el de todos los días, donde apagar
  escondería monedas y botones que el jugador está usando. La bandera la lleva el
  PAYLOAD (`celebrateBoard(showsSomethingNew:)`), no el turno, y no se pisa si la
  celebración ya está en pantalla — si no, el HUD se prendería a mitad del vuelo.
  ⚠️ Hueco conocido para decidir: `chooseCareer` nunca encola `.boardCelebration`,
  y el merge de carrera SIEMPRE produce personaje nuevo — por la regla debería
  apagar, hoy no celebra nada (concern 3 del report de la rama).
- El reveal va **centrado a pantalla completa**: desde `0d3b96d` ya no se ancla
  bajo la banda del HUD, así que no tiene nada que esquivar.
  `BoardScene.topInset` (176) quedó sin uso, y se conserva sólo porque es el
  número MEDIDO de la banda del HUD.

Detalle en `Docs/SESION-2026-08-17-cola-de-celebraciones.md` y su spec.

### Secuencia de celebraciones

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

0. **Los cofres** (2026-08-26). Las 41 pintas de piso salen **sólo** de cofres. Rareza con
   **promoción hacia arriba** cuando la sorteada se agota. Cuatro fuentes: cada 2 pisos, un
   video, el día 7 (como **segundo escalón** después del special, sin robarle el turno) y la
   reencarnación con **épica garantizada**. El primero se abre solo, el resto se guardan. La
   palabra "cofre" es de las pintas; el asado paga "una picada". Las estrellas van en PNG.
0-bis. **La migración v5 reescala SÓLO las líneas por encima de su tope**, no las tres
   (2026-08-26). Motivo: no tocarle nada a lo comprado legítimamente después del rebalance.
   ⚠️ Costo aceptado a sabiendas: la línea parada **exacto** en el tope sigue pudiendo
   llevarse las doradas, y ese agujero **creció** —antes bajaba de rebote cuando el save
   disparaba la huella—. Se eligió con esa información arriba de la mesa.

1. **El primer Fisura cuesta 25** (el dueño lo bajó de 50 el 2026-08-18; pineado
   en `GameContentValidationTests`) y los targets de pacing se bajaron a la
   conducta real en vez de recalibrar knobs. Costo medido en `balance-log §F7.6`.
2. **LA REGLA DE PRECIOS, reescrita el 2026-08-23 (decisión del dueño).** La
   vieja —"el tier base de un piso cuesta 600 veces lo que rinde un click SUYO
   ahí"— **ya no vale**, y su reemplazo son dos renglones:

   > **(a)** Contratar **a tu frontera** cuesta **600 clicks** de ese personaje
   > (el callejón, **25** por su `hireCostMultiplierOverride` — el primer Fisura
   > sigue saliendo 25).
   > **(b)** Cada tier que **bajás** descuenta sólo un tercio (÷`priceGrowthPerTier`
   > = 1,5) y fusionar necesita el **doble** de unidades: bajar un tier deja la
   > unidad de tu frontera **1,33× más cara**. Comprar hondo dejó de ser un atajo.
   > **(c)** Y del **tier 7** para arriba, tu propia frontera se encarece un
   > **60 %** por tier (`frontierEscalationPerTier` 1,6 desde
   > `frontierEscalationFromTier` 7), **por encima** de lo que ya sube por rendir
   > más. Eso es lo que pone densa la torre arriba y lo que hace que la run **se
   > trabe** — que es lo que le da trabajo al prestigio.

   ✅ **APROBADA POR EL DUEÑO el 2026-08-23, tal cual está enunciada arriba.**
   Reemplaza al enunciado anterior y a la regla original de los "600 clicks" del
   2026-08-04. No se re-litiga.

   El renglón (c) es lo que convirtió el contrato en una FORMA: la run se traba,
   cada reencarnación corre la pared, y sin reencarnar ya no se llega a dios. El
   umbral del tier 7 es lo que deja el early game y el tutorial intactos —el
   exponente es `max(0, frontera − 7)`— y sin él las primeras cinco runs se
   traban en el callejón (medido).

   ⚠️ **El retorno del prestigio (7-40 %) también está ACEPTADO** por el dueño el
   2026-08-23: no se agrega contenido nuevo para llegar al 67 %. Y hay un **techo
   matemático** que hace inútil intentarlo con knobs — está en `balance-log.md`,
   "El techo del prestigio": volver a la pared cuesta las mismas ACCIONES que la
   primera vez y el ORO saca la espera, no las acciones, así que
   `pago ≤ 1 − acciones(1..T)/primera_vez(T)`. **Los precios entran en el
   denominador, no en el numerador: ningún knob de precio puede cruzarlo.**

   Por qué cambió: la vieja ataba el precio a `tapYield(tier)`, la MISMA curva que
   el rendimiento (2,8 por tier), y como fusionar sólo multiplica por 2, comprar
   `d` tiers abajo salía `(2/2,8)^d`. Comprar hondo siempre ganaba, y por eso una
   compuerta más profunda ABARATABA el juego. El ancla en la frontera separa el
   NIVEL del precio (2,8 por tier de frontera, que mantiene el pacing plano) de su
   PENDIENTE (1,5 por tier comprado). Ningún precio que dependa sólo del tier
   puede tener las dos cosas.
   Pineada en `GameContentValidationTests.hirePricesFollowTheOwnersRule`, con las
   dos mitades y sobre los 37 tiers.
   ⚠️ **Consecuencia user-visible**: los precios de FisuJobs **suben cada vez que
   la torre sube** (×2,8/1,5 = ×1,867 por tier de frontera). Lo que se mantiene
   plano es el TIEMPO, porque tu ingreso también sale de la frontera.
   ⚠️ **La única costura es el callejón** (25 contra 600): comprar ahí sale 24×
   menos y la mitad (b) no vale al cruzar ese borde. Es un descuento ACOTADO y no
   compuesto que se agota solo en el tier 22 de 37; lo pinea
   `elDescuentoDelCallejonSeAgotaSolo`.
   ⚠️ **`hire.tierPremium` ya no existe.** Su trabajo —que comprar arriba no sea
   un atajo contra mergear— lo hace la compuerta; y con la fórmula nueva dejaría
   la pendiente real dentro del piso en 2,8 × 1,8 = 5,04, o sea el agujero otra vez.
   ⚠️ **Enmienda del 2026-08-21 que sigue en pie: `hire.defaultCostGrowth` es
   1,06** — de +20 % a +6 % por compra. El motivo, medido: con el 20 % el bot
   llega a un pico de 70 compras y la siguiente cuesta 384 s de income, así que
   **se traba en el tier 11 y la partida no se puede terminar**.
2bis. **Las mejoras por personaje son SECUENCIALES** (dueño, 2026-08-22): el
   multiplicador es `1 + nivel`, o sea ×2, ×3, ×4 … **×20**, y no el `2^nivel`
   que llegaba a ×1.048.576. Su palabra: *"esto va a reducir mucho las ganancias
   de plata y hacer que los personajes ganen una cantidad de plata 'real'"*.
   `maxLevel` es **19** porque `1 + 19 × 1` es el ×20 que él escribió (con 20
   niveles el tope sería ×21). Pineado en `GameContentValidationTests` y en
   `CharUpgradesTests.theMultiplierIsSequential`.
   ⚠️ `charUpgrades.costGrowth` bajó de 4,0 a 1,5 como CONSECUENCIA, no como
   ajuste suelto: contra un efecto lineal un costo ×4 por nivel mata la línea
   —medido, el bot no pasaba del nivel 7 de 19 y la mediana era 4—, así que el
   ×20 del pedido no lo veía nadie.
3. ~~**El gate es de UN piso**, no dos~~ — **REEMPLAZADA el 2026-08-22 por
   decisión del dueño: la compuerta se mide en TIERS.** Un tipo de tier `T` se
   contrata sólo si `run.maxTierReached >= T + hire.gateTierDistance` (**5**), con
   el tier base de la torre EXENTO. La regla por pisos tenía un borde dentado —un
   piso son cuatro tiers y FisuJobs los vende todos, así que lo que ataba era el
   TOPE del piso habilitado, a UN tier de la frontera— y por eso el jugador nunca
   usaba el ascensor. Medida en tiers, la distancia es la misma compres donde
   compres.
   ⚠️ **Los dos parches por piso ya no existen**: el callejón entero exento y el
   `hireGateExempt` del urbano (que cerró el muro de 268 h de la Ola 3) se
   borraron, y la clave salió de `FloorDef` y del JSON. La única excepción es el
   tier base de la torre, que es una regla de diseño y no un parche.
   ⚠️ **N = 6 desde el 2026-08-23, y recién ahí pasó a ser un dial de verdad.**
   Mientras el precio siguió a `tapYield(tier)`, una compuerta más profunda
   ABARATABA el juego (N=4 → 6,67 h · N=6 → 5,34 h). Con el precio anclado a la
   frontera va para el lado que el diseño esperaba: **N=5 → 4,14 h · N=6 → 7,27 h
   · N=7 → 185,63 h**, porque cada tier de profundidad duplica las compras que
   hacen falta. Arriba de 6 se despierta el muro del early game —hasta que la
   frontera llega a `N+2` lo único contratable es el Fisura—: es lo que pone el
   peor paso en ×4.441 y la primera reencarnación a 28 h de pared. Los números,
   en `balance-log`, "Cuarta ronda".
4. **Los tintes IAP se retiraron** aunque eran los únicos productos pagos además
   de remove_ads.
5. 🟡 **`PacingTests.theOwnersTargetsAreMet` sigue en ROJO, pero por OTRA cosa —
   y ése es el progreso.** El primer assert (maxear en 20-30 h activas) **pasa
   desde el 2026-08-23**: mide 20,67 h. Lo que queda rojo es el segundo,
   **9 reencarnaciones contra ≤8**.
   ⚠️ **No se fuerza, y está medido por qué**: los dos knobs que llegan a 8
   (`oro.exponent` 0,32 y `oro.globalMultiplierPerOro` 0,24) sacan maxear de la
   banda de 20-30, y el segundo además hace que la pared RETROCEDA. Cambiar un
   assert verde por otro no es arreglarlo. Números en `balance-log.md`.
   ⚠️ **Y el total NO se escaló a propósito**: 20,67 h de simulador son ~6,9 h del
   dueño y él pidió 20-30 suyas, pero ese ÷3 sale de UNA comparación. El knob
   está identificado (`oro.divisor` 1e10 → 1e11 da 30,33 h de sim) y espera al
   playtest — subirlo alarga pero **clava la pared** cuatro runs en el mismo tier.
   ⚠️ **Y antes de calibrar contra ese número hay una pregunta abierta para el
   dueño**: las 20-30 h, ¿son del reloj del SIMULADOR o del suyo? Él hizo en
   menos de 1 h la partida que el bot tarda 2,97 h, o sea que juega **~3× más
   rápido**. En su reloj, N=7 con el callejón destrabado da 4,4 h y N=8 da 25,8 h.
   La respuesta cambia qué configuración es la correcta y no la puede contestar
   una calibración. Cuadro completo en `balance-log.md`, "Cuarta ronda (bis)". Se descubrió arreglando el simulador, no cambiando la economía.
   La causa de la ronda 3 (el precio atado a `tapYield(tier)`) **ya está
   cerrada**; la que queda es otra y también está medida: **la mitad del tiempo
   activo del bot es apretar el botón, no esperar plata**, así que los knobs de
   precio son sublineales. Antes de tocar nada leé
   `Docs/SESION-2026-08-23-precio-atado-a-la-frontera.md` §3 y §7: las salidas
   son decisiones del dueño y hay cuatro, medidas.
   `PacingTests` tiene **dos clases de assert y no hay que confundirlas**: las
   cuatro BANDAS son ±30 % de la conducta medida (se re-pinean cada vez que el
   dueño cambia el balance a propósito), y `theOwnersTargetsAreMet` es el
   OBJETIVO —maxear las siete en 20-30 h activas con ≤8 reencarnaciones— que
   **no se re-pinea**: si se pone en rojo, el juego dejó de cumplir lo que se
   pidió. `pacing-sim` sigue imprimiendo los targets de DISEÑO del plan F7.1c
   para que la brecha que queda (la fase fisura) siga visible.
6. **El recorte de fondo se elige a ojo, asset por asset, y no lo decide el
   pipeline.** Ninguna de las dos herramientas gana siempre: la conectividad
   conserva el blanco encerrado del dibujo (una camisa, pero también la sombra
   del piso) y la saliencia se lo come (la sombra, pero también la camisa). Hoy
   hay **98 assets elegidos a mano** —las 86 skins de material y 12 personajes—
   y `recut_assets.py` y el barrido del atlas los SALTEAN para no pisar la
   decisión. Cambiar uno es una corrida de `scripts/elegir_recorte.py`.
7. **Las skins de oro no se venden.** Su única vía es maxear las siete mejoras
   permanentes. El diamante es al revés: sólo el bundle, sin condición.
8. **El precio de contratar usa el MISMO factor de piso que el click**
   (`tapFloorMultiplier(for:)`), no el `incomeMultiplier` crudo — salida (a),
   elegida por el dueño el 2026-08-21 sobre otras dos corridas enteras.
   El motivo: `tapFloorMultiplierExponent: 0` le sacó al TAP el multiplicador de
   piso y el precio lo seguía llevando crudo, así que contratar el tier base del
   reino divino pasó de 600 clicks a **372.000** sin que nada hiciera ruido — y
   el test que debía protegerlo seguía verde porque replicaba la fórmula vieja
   del click. Atadas por construcción (las dos llaman a la MISMA función), la
   regla no se puede volver a romper en silencio. Costo medido: 1,3 h de largo
   (25,33 → 24,00 h). Las descartadas: devolverle el multiplicador al tap da
   15,26 h y 9 reencarnaciones (no cumple ninguno de los dos objetivos), y
   dejarlo como estaba obliga a re-enunciar la regla como "600 ×
   `incomeMultiplier` clicks".
9. **El atajo del HUD vende el TIER BASE del piso más alto pagable**, no el tier
   más alto. FisuJobs sigue vendiendo todo lo desbloqueado: el recorte es de
   PACING y sólo del atajo. Ofrecer el tier más alto te saltea la profundidad de
   merge del piso, que es lo que el juego cobra.
10. **Los doce logros de ORO fijo suman 33, no 620.** Con 620 contra los 193 que
   cuesta maxear las siete líneas, juntando logros se ganaba el juego 3,2 veces.
   El dueño los quiso en montos FIJOS (más legibles en la ficha que un
   porcentaje) aportando el 15-20 % del camino; la regla del re-escalado es el
   monto viejo ÷ 20 redondeado para arriba, con piso en 1. Pineado en
   `fixedOroAchievementsFundAFifthOfTheRun`.

---

## 6. Cómo verificar

⚠️ **Creá tu propio simulador y apuntá por UDID** (trampa 2), y **corré unit
ANTES que UI** — la asimetría es real y direccional, ver abajo.

⚠️⚠️ **Desde Xcode 26.6 (2026-08-25) la verificación es una MATRIZ de dos
runtimes** (trampa 30, eslabón 6): TODO corre en un sim **iOS 26.5** SALVO
las tres suites de Store —`StoreManagerTests`, `StoreProductsTests`,
`StoreUITests`—, que corren en un sim **iOS 18.6** porque StoreKit Testing
está roto entero en el runtime 26. En 26 se las saltea con
`-skip-testing:` (las tres, nada más); en 18.6 se corren solas con
`-only-testing:`. Señal de re-unificación: `StoreProductsTests` verde en un
sim 26 virgen.

```bash
UDID=$(xcrun simctl create "mi-frente" "iPhone 16 Pro")

cd Packages/EconomyKit && swift test                      # 230
cd - && /opt/homebrew/bin/xcodegen generate               # si agregaste/borraste Swift

# 1) UNIT PRIMERO
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/DD -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests test                   # 401

# 2) UI DESPUÉS
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/DD -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionUITests test                  # 46, sin skips

cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q   # 27, 1 rojo

xcrun simctl shutdown $UDID && xcrun simctl delete $UDID   # ⚠️ el cierre es parte del trabajo
```

Estado el **2026-08-23** (cierre del precio anclado a la frontera):
**EconomyKit 243 · app 413 con 12 rojos (1 DECLARADO + 11 de máquina) · UI 48 ·
pipeline 27 (1 rojo conocido)**, cero warnings de compilador. Los tres primeros
salen de la MISMA verificación y **la suite de UI entera corrió en una sola
pasada, sin un solo `-skip-testing:` y sin flakies**.

🔴 El rojo declarado es **`PacingTests.theOwnersTargetsAreMet`** y es la verdad,
no un flaky: maxear las siete mide 7,27 h contra las 20-30 pedidas. Ver §5.5.

🔴 Los otros 11 son **StoreKit y NO son del proyecto**: contra el runtime iOS
26.5 la tienda local vuelve vacía (`store.products == []`), así que caen las 10
de `StoreManagerTests` y la de `StoreProductsTests`. **Verificado a mano en un
worktree limpio en `8f884ea`**, con el mismo simulador y el mismo comando: fallan
igual sin ningún cambio encima. Es un gate de máquina.

✅ **El runtime de iOS 26 ya está instalado** (26.5 - 23F77): el gate humano del
2026-08-22 está resuelto y **`Assets.xcassets` NO hay que sacarlo del target**.
Lo que sigue haciendo falta es el flag de `StoreKitTest`:

```bash
xcodebuild … OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'
```

<details><summary>La receta de la ronda 3, cuando la máquina no tenía runtime de iOS 26 (histórica)</summary>

```bash
# 1) sin esto xcodebuild no lista NINGÚN destino de simulador
xcrun simctl runtime match set iphoneos26.5 22G86
# 2) actool no puede compilar el catálogo: AssetCatalogSimulatorAgent está
#    compilado para iOS-simulator 26.4 y el runtime 18.6 no tiene
#    _swift_coroFrameAlloc. No hay flag que lo evite.
mv FisuEvolution/Resources/Assets.xcassets /tmp/ && /opt/homebrew/bin/xcodegen generate
# 3) el header de StoreKitTest usa API deprecada en iOS 18 y el target compila
#    con -warnings-as-errors
xcodebuild … OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'
```

**El parche 2 cambia lo que se ejecuta**: la app corre sin catálogo de colores y
los `Color("Palette…")` caen al default. No afecta a unit; la suite de UI pasó
igual (48/48), pero un test que juzgue color no serviría así.
`xcodebuild -downloadPlatform iOS` **no sirve** (cree que la plataforma ya está
por el 18.6 y ninguna 26.x figura disponible). El arreglo de verdad es instalar
el runtime desde **Xcode > Settings > Components**: es un gate humano — y el
2026-08-25 alguien lo hizo, así que esto es historia.
⚠️ Y al terminar, **volvé a poner `Assets.xcassets` en su lugar antes de
commitear** — es fácil dejarse una veintena de borrados en el `git status`.

</details>

ℹ️ El **27 del pipeline** es el único que no se re-midió el 2026-08-21 (es Python
y esta rama no lo tocó): viene del cierre de `fix/cierre-post-merge`.

⚠️ **El número de UI se toma de UNA sola corrida y sin un solo skip**
—`AscentRenderingUITests` adentro—, que fue lo último que quedó pendiente de
medir en `fix/cierre-post-merge`: hasta ese día salía de SUMAR los 3 de esa clase,
verificados aparte, a los que se medían con ella salteada.

⚠️ Y se tomó **en malas condiciones a propósito**: arrancó con la máquina en
`load average` **~156** por frentes ajenos y la suite pasó entera igual, con
**cero flakies re-corridos**. O sea que el 43 no es un número de laboratorio.

#### Cómo se movieron desde entonces (2026-08-17)

Los cuatro de arriba son **el último cuádruple tomado con la receta completa**.
Lo que se sumó después está medido, pero cada suite por su lado y en el simulador
compartido, así que no lo reemplaza:

| Suite | 2026-08-16 | Hoy (2026-08-21, main `9efc8f7`+manito) | Qué entró |
|---|---|---|---|
| EconomyKit | 183 | **234, cero rojos** | `CelebrationQueueTests` + la restricción del tutorial (sesión tutorial) y `PacingSimulatorTests` + `PermanentUpgrades` (rebalance) |
| app | 346 | **411, cero rojos** | tutorial: `CelebrationWiringTests` (+fase), `TutorialTipsTests`; rebalance: `PacingTests` re-pineado ENTERO (los «3 rojos conocidos» YA NO EXISTEN como categoría), `BestHireTests`, `SaveMigratorTests` |
| UI | 43 | **48, cero rojos, sin skips** | `CareerChoiceUITests`, `MenuUITests`, `TutorialUITests` reescrita (lección + puntito) |
| pipeline | 27 | 53 | frentes de arte ajenos; 1 rojo ajeno (4 PNG calados de `estanciero_estelar__tropero`) |

⚠️ Los cuatro de la columna «Hoy» son del árbol FINAL del 2026-08-21 —el
merge del rebalance a main más la manito— tomados en la verificación del
merge (`SESION-2026-08-21-merge-rebalance-y-manito.md`): EconomyKit por
`swift test`, app + UI en el MISMO simulador propio por UDID con la receta
completa (unit antes que UI, `-parallel-testing-enabled NO`, sin skips). El
quinto número de ese cierre es el `pacing-sim`: **24,00 h activas · 8
reencarnaciones**, que es el contrato del dueño.

**El próximo cuádruple hay que tomarlo con la receta de arriba**, no sumando
estos. Y ojo con `refundRevokesEntitlement` (StoreKit + `SKTestSession`): falló
tres veces en corridas completas de este día y pasó aislado todas ellas.

- El rojo del pipeline es `test_wait_for_survives_a_stale_element_and_retries`:
  pide un Chrome escuchando en `:9222`. Es de entorno y es el baseline.
- **Ya no hay ningún `-skip-testing:` en la receta de UI.** El único rojo que
  quedaba, `AscentRenderingUITests`, se migró a doble toque el 2026-08-16 y pasa
  (ver la trampa 2). Los 3 tests de esa clase entran al conteo: 40 → **43**.
- Usá siempre `-parallel-testing-enabled NO`.
- ⚠️ La suite de UI pasó de ~40 a 43 tests y `AscentRenderingUITests` es la más
  lenta de todas (~4 min de las tres juntas, porque escala el callejón fusión
  por fusión). Si una corrida completa empieza a rozar los flakies sensibles a
  carga que se listan más abajo, es por eso — mirá el reloj antes que el código.

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
| `--uitest-daily-popup` | El popup del premio del día, ya abierto (T18). Retrocede `lastClaimDay` a **ayer** —no lo borra, que un día salteado resetea el ciclo a 1— y corre el claim real, el mismo que acredita al volver a foreground. Existe porque el daily se cobra solo y una sola vez por día, y una partida nueva marca `lastClaimDay` en HOY para no pisar el tutorial: sin esta puerta, la única pantalla que celebra la racha no se puede ni fotografiar ni ejercitar sin cambiarle la fecha al simulador. Combinado con `--uitest-daily-streak` muestra el día 4. Desde el 2026-08-21 **ya no necesita `--uitest-skip-tutorial`**: la cola arbitra (con la fase viva el popup espera su turno y aparece al cerrarla — usarlo SIN skip es justamente el repro del viejo deadlock) |
| `--uitest-lessons` | Prende las lecciones contextuales del tutorial, que en cualquier corrida `--uitest-*` arrancan APAGADAS (trampa 27). Sólo lo usa el test que ejercita el coach-mark |
| `--uitest-special` | El primer special del catálogo, caído y ANCLADO al piso visible, con la carta del drop abierta. Es la única forma de ver la carta (el drop real es RNG sobre merges) y de ejercitar el recap del mantener-apretado |

El panel de debug es el ícono de herramientas del HUD.

---

## 7. Trampas en las que ya caímos

### De los cofres (2026-08-26)

**Siete tests que quedaban verdes con la funcionalidad desenchufada.** Casi todos escritos
por el controller en el plan. Los cazó siempre lo mismo: **romper la cosa y mirar si el test
cae**, nunca leerlo. Los tres que más enseñan:

- El de la migración v5 asertaba "los campos valen cero", que es cierto **con o sin** migrar,
  porque se decodifican con `decodeIfPresent ?? 0`. Lo único que detecta el cableado roto es
  `schemaVersion == 5`.
- El de la cola **no podía pasar nunca**: `enqueue` sobre una cola vacía promueve en el acto,
  así que el ítem nuevo tomaba `current`. Para comparar prioridades hay que ocupar el turno
  con un tercero primero.
- El de la animación quedaba verde **por el reloj**: con el auto-avance prendido, la
  aserción de que los tres toques revientan el cofre pasa igual con los toques muertos. Pidió
  un flag (`--uitest-chest-manual`) que apague el auto-avance.

**Un renombre de claves de localización NO lo protege el compilador.** `String(localized:)`
con la clave borrada **compila** e imprime la clave cruda en pantalla, y los tests que sólo
miran `!texto.isEmpty` pasan porque una clave cruda no es vacía. El repo ya tenía el idioma
correcto en `DailyCalendarTests` (`!copy.contains("daily.")`); ahora está también en
`BoostUnlockTests` y `CareerRewardTests`, y **generaliza** a toda la familia de claves.

**Y el error que lo destapó: `| head` truncando la propia verificación.** El controller
escribió en el plan "son exactamente esos cuatro call sites, ni más ni menos" desde un grep
que devolvía 11 líneas y estaba cortado en 10. Eran seis. Los dos que faltaban eran justo los
de falla silenciosa. **Nunca afirmar completitud desde una salida truncada, y menos
escribirla en un plan: le dice al implementador que deje de buscar.**

**`ParticlePool` no sirve desde SwiftUI** (`emit(_:at:in parent: SKNode)`, único cliente
`BoardScene`), y **`HapticsManager` no tiene `.light`/`.medium`/`.heavy`/`.success`**: el
juego usa vocabulario semántico sobre CoreHaptics (`.merge`, `.purchase`, `.error`,
`.evolution`, `.rarity`). Las dos cosas estaban afirmadas al revés en el plan.

**El cofre puede congelar la cola de celebraciones entera.** `.chestOpening` tiene
`timeout: nil` (el tick nunca lo vence) e `isSkippable == false` (el tap nunca lo saltea): si
la vista no limpia `chestReward` **antes** de `celebrationFinished`, `syncCelebrations` lo
reencola en el mismo frame, `showing` queda pegado para siempre y **el HUD queda apagado sin
watchdog que lo destrabe**. El embudo único es `dismissChestReward()`.

1. **El build incremental NO recompila los atlas.** Si medís páginas de atlas o
   peso del `.app` y no cierran, borrá `build/DD`.
2. **Un test de UI puede pasar sin probar nada.** Si automatizás gestos sobre
   SpriteKit, **asertá el efecto**, no que el gesto no crashee.

   ✅ **`AscentRenderingUITests` YA NO ES ROJO** (migrado y verificado el
   2026-08-16, 3 corridas verdes: fría, tibia y fría). Estuvo diez días salteado
   por un diagnóstico que era **verdadero pero incompleto**, y las tres causas
   valen más que el arreglo:

   1. **El arrastre por coordenadas fijas** (la vieja trampa 3). Arreglado
      migrando a **doble toque**, como `mergeTheHighlightedPair`: sólo hay que
      acertarle al personaje de ORIGEN, del destino se encarga
      `MergeTargeting.nearestPartner`. Se barren los slots y se asserta que
      `board.units` **baje**, que es lo único que prueba que hubo fusión.
   2. **Un supuesto de economía vencido, y esto es lo que lo mantuvo rojo aun
      después de arreglar el gesto.** El test decía "par de Cartoneros → Kiosco
      (T3) **asciende**" y hace rato que no: el callejón cubre los tiers **1..4**
      (`economy.json`), así que el primer piso nuevo lo abre un **T5** y hacen
      falta **cuatro** fusiones, no dos. Ahora el test **no hardcodea el número**:
      fusiona hasta que la pill cambia de piso, con tope. Un rebalanceo no lo
      vuelve a romper.
   3. **El device frío** (trampa 9a). El primer toque de la corrida sobre
      `hud.debug` moría con `Failed to scroll to visible (by AX action)`, porque
      `board.units` es del tamaño del tablero y XCUITest cree que tapa al HUD.
      Este test es el primero de su suite, así que era el que se lo comía. Se
      toca por COORDENADA, igual que `CustomizationUITests`.

   ⚠️ **Ya se llevó puestos dos agentes** que lo diagnosticaron como "el
   simulador no arranca" y se pusieron a borrar dispositivos. No es eso, nunca lo
   fue: el modo de falla "la app no corre" era una entrada de background que
   faltaba en el manifest, arreglada hace rato.

   📌 **La moraleja, que es la de la trampa entera:** un test salteado se pudre
   solo. Este acumuló un espejo de geometría desactualizado (`bottomInset` en 110
   cuando la escena ya iba en 114), un `sheet.close` tapeado sin guarda —migrado
   a ciegas mientras estaba salteado— y un supuesto de economía vencido, todo
   sin que nadie se enterara, porque nadie lo corría. **Si vas a saltear algo,
   ponele fecha de vencimiento.**

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

   ⚠️⚠️ **Y una tercera forma, que muerde al revés: `stale` NO quiere decir
   borrable.** El reformateo del catálogo que dejó el último build de Xcode
   (`07789d7`) marcó `extractionState: stale` en **175 de las 459 claves**, y
   muchas están **VIVAS**: `settings.haptics`, `daily.title`,
   `notif.daily.title`/`.body` y ~20 de ajustes. El extractor no ve a través de
   un parámetro `titleKey:` —la clave viaja como `LocalizedStringKey` hasta una
   vista propia en vez de aparecer como literal de `Text`— ni siempre a través
   de `String(localized:)`. **Una pasada de limpieza que borre por
   `extractionState` se lleva claves vivas y deja la clave cruda en pantalla**,
   que es la misma falla de esta trampa por otra puerta. Verificá por `grep`
   antes de borrar una sola.

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

    ✅ **Y hay una salida para agentes, probada el 2026-08-16**: escribir un
    `.command` con los comandos del batch y lanzarlo con `open` — Terminal.app
    pasa a ser el responsible process de TCC y `osascript` hereda su permiso.
    El tipeo funcionó (2146/2150 caracteres del asset 2 llegaron al editor).
    ⚠️ Lo que lo mata no es el permiso sino **el foco**: con otros frontends
    activos en la máquina, las teclas caen en la ventana equivocada (probado
    el mismo día: dos assets con 0 caracteres tipeados). Desde `acaf3e6` el
    runner lo detecta y aborta con cuota cero — nunca manda un prompt a medias
    ni barajado — pero el batch sólo AVANZA con la máquina quieta: si hay
    sesiones de agentes corriendo, que lo lance el dueño con todo cerrado.
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

16. **El cwd de una sesión de agente puede volverse SOLO al checkout
   principal a mitad de sesión** (pasó el 2026-08-17, entre dos corridas de
   test de la misma sesión). El síntoma es venenoso porque nada falla en el
   momento: los builds "SUCCEEDED" —del árbol equivocado—, la suite de UI
   corre —contra el código del dueño, con SUS rojos— y la app instalada en el
   simulador es la vieja. Se detectó porque una captura mostraba la UI de
   antes del rediseño y `strings` sobre el binario no encontraba los símbolos
   nuevos (ni un literal de `Color("...")` recién agregado, que es la prueba
   más barata).

   **La regla**: en sesiones largas de agente, TODO comando de build/test va
   con ruta absoluta de `-derivedDataPath` y verificación de `pwd` — y si el
   resultado de una corrida se contradice con el código (falla algo que no
   tocaste, en cluster), lo primero que se chequea es QUÉ árbol corrió:
   `xcrun xcresulttool`/el log imprimen la ruta del xcresult, y esa ruta
   nombra al culpable. Los commits se salvaron porque cada uno imprime su
   rama: `[feature/... hash]` en el output es el pinning gratis que siempre
   hay que mirar.

---

### Trabajar en paralelo con otra sesión (2026-08-17)

Dos cosas que costaron tiempo este día y que no están en ninguna otra parte:

1. **El simulador es un recurso compartido.** Otra sesión tomó el mismo
   simulador dos veces a mitad de una QA visual: aparecía SU app en el
   foreground y mis taps entraban ahí. Se pierde la captura y, peor, se
   interfiere con el trabajo del otro. **Creá el tuyo** (`xcrun simctl create` +
   `bootstatus -b`) y cerralo al terminar, que además es la receta que §6 ya pide
   para medir.
2. **`git add` amplio se come trabajo ajeno.** Un `git add -A FisuEvolution` metió
   un cambio de la otra sesión (`bottomInset` a computado) adentro de un commit de
   celebraciones. Con dos frentes sobre el mismo checkout, **stagear por archivo**
   y mirar `git status` antes de cada commit no es ceremonia.

### Del pipeline de arte (2026-08-19)

17. **El descarte por huella se come lo bueno si la variante conserva la pose.**
    El runner tira la imagen extraída si queda a menos de `--ref-threshold` de la
    referencia, pero la huella es un thumbnail de **32×32** y el fondo blanco
    ocupa el **74%** del cuadro. Medido: la referencia re-codificada da ≤ 0,37,
    un dorado típico 9,51, y el peor caso —`magnate_solar`, que ya vestía de
    amarillo— **3,84**. Ni un personaje enteramente NEGRO pasa de 25,80. El
    default quedó en **1,5**; con 12 no pasaba ninguna y el runner agotaba el
    timeout de cada asset sin encontrar candidato.

18. **El timeout de generación no puede bajar de ~250 s.** Es el piso real
    medido. Con un cap de 200 s se mata la imagen unos segundos antes de que
    Gemini la renderice, y como no se guarda PNG el asset **nunca sale de la
    cola**: se regenera para siempre. Se vio al Fisura generarse diez veces.

19. **`--retries N` son N+1 generaciones** (`range(retries + 1)`). Multiplicado
    por un driver que también reintenta daban cuatro por asset: 344 en vez de
    86. `batch_uno_por_uno.py` fija `--retries 0` y la política de reintento vive
    en un solo lugar. Y **`--only` NO es acumulable**: es un valor único, así que
    un `--only a --only b` se queda callado con el último.

20. **La cola compartida regenera desde el principio.** Los 86 assets comparten
    un proceso: si uno se cuelga hay que matar la corrida entera y al relanzar
    empieza por el primero. Un asset por proceso (`--only`) lo aísla.

21. **Al integrar arte hay que stagear DOS lugares.** Marcar el `.md` como
    `hecho` no versiona el PNG: van el atlas Y `dropbox/procesadas/`. Un commit
    que staged sólo los `.md` dejó `origin/main` con 84 de 86 skins, detectado
    recién al verificar el push.

22. **Instrumentar antes que deducir.** Dos diagnósticos seguidos salieron
    erróneos razonando desde los números (primero "el umbral descarta el
    dorado", después "el filtro de 512 px lo deja afuera"). El que acertó salió
    de imprimir los anchos de las imágenes en pantalla: `imgs en pantalla:
    1024,150,150,128,64,32` mostró que la generada **no existía todavía** cuando
    el runner miraba. Cuando el log no alcanza, agregale una línea al código en
    vez de inferir.

### De SwiftUI (2026-08-21)

23. **Una vista EMPUJADA en `NavigationStack` no hereda el telón transparente
    de su hoja.** SÍNTOMA: la franja bajo la banda de madera (y todo lo que
    rodea al panel) se ve blanca —gris 240 medido— en vez del juego atenuado,
    sólo en pantallas empujadas. CAUSA: UIKit le pinta `systemBackground` al
    hosting controller del destino; el `.presentationBackground(.clear)` de la
    hoja no lo cubre. ARREGLO: `clearNavigationBackdrop()` (PanelFrames.swift)
    sobre el contenido de cada `navigationDestination`. Ojo: el placement
    `.navigation` de `containerBackground` es **iOS 18+** —verificado en la
    swiftinterface del SDK—, por eso hay un fallback UIKit para 17.

### De diseño y de build (2026-08-23, ter)

35. **Una pared que la run nunca alcanza no existe.** Con el umbral de la
    escalada por encima del tier 9, la métrica de forma daba `paredes: ninguna`
    — y no porque la curva fuera suave, sino porque el bot reencarna al duplicar
    el ORO **antes** de llegar a la zona con escalada. Cuando una métrica de
    forma da vacío, mirá primero **hasta dónde llega la run**, no la fórmula.

36. **Un knob que arregla un contrato puede romper otro que acaba de cerrar.**
    Los dos candidatos para bajar de 9 a 8 reencarnaciones sacaban maxear de la
    banda de 20-30 que se acababa de cumplir. Antes de aplicar un knob "barato",
    corré las OTRAS métricas — y si el saldo es cambiar un verde por otro, no lo
    apliques.

37. **Un error de build puede estar tapando a otro.** Arreglado el header de
    `StoreKitTest` apareció un `tmp*.json couldn't be opened` que parecía del
    cambio: era un artefacto de build incremental y no volvió. La atribución
    correcta fue construir **sin** el cambio y ver que ahí fallaba antes y en
    otro lado. Mismo método que con las rojas de StoreKit y las de UI.

38. **`-Xcc` es lo que hace acotado un `-Wno-*`.** El proyecto trata los warnings
    como errores y un header de Apple (`SKPaymentTransactionState`, deprecada en
    iOS 18) rompía el build entero. `OTHER_SWIFT_FLAGS: -Xcc -Wno-deprecated-declarations`
    se lo pasa **sólo al importador de Clang** —headers C/ObjC del SDK— y deja
    `SWIFT_TREAT_WARNINGS_AS_ERRORS` intacto para nuestro Swift. Si alguna vez
    hace falta silenciar otro warning del SDK, ése es el molde: `-Xcc`, en
    `Debug`, y en cada target que importe el módulo. **Nunca** bajando
    `SWIFT_TREAT_WARNINGS_AS_ERRORS`.

### De tests y calibración (2026-08-23, bis)

33. **El device de simulador es de UNA corrida por vez, y el segundo proceso
    puede ser tuyo.** Lanzar `-only-testing:FisuEvolutionTests/PacingTests`
    mientras la suite de UI corría en el MISMO simulador tiró **31 de 48** tests
    con "la app no está corriendo", `board.floor never appeared` y
    `kAXError -25218`. El general ya decía "dos agentes en paralelo no pueden
    compartir el device"; la ampliación es que **no hace falta otro agente**.
    Si una suite de UI empieza a fallar en masa con "la app no está corriendo",
    mirá `ps aux | grep xcodebuild` ANTES que el diff.

34. **Un costo agregado al instrumento puede BAJAR la métrica.** Cobrar las
    fusiones (0 → 1 s) bajó maxear de 7,27 a 6,67 h activas, que es lo contrario
    de lo que uno espera. El mecanismo: el costo quema presupuesto de SESIÓN (20
    min), el bot llega antes al final de cada una y parte del progreso se paga con
    income **offline**, que es reloj de pared y no de dedo. Cuando un cambio de
    instrumento mueva una métrica para el lado raro, mirá si el modelo tiene un
    presupuesto por sesión antes de buscar el bug.

### De tests y calibración (2026-08-23)

30. **Antes de barrer knobs, medí si el bot es *money-bound* o *action-bound*.**
    `PacingSimulator` cobra **1 s de manipulación por compra** (`elapsed += wait + 1`)
    y ese segundo era, medido, **la mitad del tiempo activo** de la partida
    embarcada — con la compuerta en 5, maxear pasa de 4,14 h a 2,19 h poniéndolo
    en cero. Es por qué todos los knobs de precio de tres rondas dieron
    sublineales (×16 en `defaultCostMultiplier` compra ×1,75 de partida) y por qué
    el barrido tenía techo. La pregunta se contesta con un experimento de dos
    líneas y ahorra un día de barridos.
    ⚠️ Y el corolario: **cerrar un atajo puede ACORTAR el juego.** Comprar hondo
    era barato pero pedía `2^(frontera−1)` compras, así que estaba sosteniendo la
    mitad del largo sin que nadie lo hubiera diseñado. Cerrarlo bajó la partida
    de 6,67 h a 4,14 h ANTES de subir la compuerta.

31. **Dos invariantes de precio pueden ser complementarios y no poder valer
    juntos.** "Comprar el tier de arriba nunca conviene contra mergear dos del de
    abajo" es `costo(t+1) > 2 × costo(t)`; "comprar hondo nunca sale más barato"
    es `costo(t+1) < 2 × costo(t)`. El filo es el factor de merge y no hay tercera
    opción: elegís un lado, y el otro lo tiene que cubrir OTRA regla (acá, la
    compuerta). Un test que assertee los dos está pidiendo un imposible, y uno que
    assertee el viejo después de cambiar la política parece un aflojamiento y no
    lo es.

32. **Un ratio no distingue una pared de un arranque corto.** La guarda de
    `PacingTests.floorGradient` mide RATIOS entre hitos, y con la compuerta en 6
    el peor paso da ×16,38 — que son **1,3 min → 21,3 min**. El acantilado que esa
    guarda nació para cazar eran **13,3 h de un solo salto**. Si vas a moverle el
    techo, ponele al lado el assert en HORAS
    (`noHitoJumpIsLongerThanFourActiveHours`), o la banda se debilita justo en la
    dimensión que importa.

### De tests y calibración (2026-08-22)

27. **Cuando una regla del juego cambia, preguntate qué SUPUESTO del bot
    dependía de la regla vieja** — no sólo qué llamada. El simulador compraba
    sólo el tier BASE de cada piso, con una justificación escrita al lado
    ("comprar más arriba nunca conviene, lo garantiza `tierPremium`") que era
    cierta **mientras la compuerta se midiera en pisos**. Medida en tiers, el
    tier más alto que podés comprar casi nunca es un tier base, y el mismo bot
    pasó de medir 6,67 h a medir 26,00 h — y con la distancia real ni terminaba
    la partida. Un supuesto escrito como optimización no se lee como supuesto.

28. **Un knob de `economy.json` puede estar HORNEADO en el contenido y no hacer
    nada.** `passiveRatio` y `passiveUnlockCostMultiplier` dieron corridas
    idénticas hasta el último decimal en tres valores cada uno: los rendimientos
    pasivos y el precio de desbloquearlos viven en `tiers.json`
    (`passiveYieldPerInstance`, `passiveUnlockCost`, generados) y las claves de
    `economy.json` sólo las usa `StandardEconomy` para los premios. Antes de
    descartar un knob "porque no mueve la aguja", verificá que el sim lo LEA.

29. **Un `while` de test que espera que el estado avance cuelga la suite en vez
    de fallarla.** `hiringOnTheFrontierFallsBackToTheFloorBelow` llenaba un piso
    con `while occupied < capacity`; cuando la compra empezó a caer en otro
    piso, el `#expect` de adentro falló en cada vuelta y el loop giró hasta un
    log de **141 MB**. Acotá el loop por la capacidad, no por la condición.

### De tests y calibración (2026-08-21)

24. **Un test puede CAMBIAR DE SIGNIFICADO y quedar verde**, y en una rama de
    balance pasa de a tres. SÍNTOMA: el test sigue en verde después de mover un
    knob que debería haberlo roto. CAUSA: o replica la fórmula vieja en vez de
    llamar a la del código (`hirePricesFollowTheOwnersRule` seguía calculando el
    click a la vieja, así que no vio que contratar en el reino divino pasó de
    600 a **372.000** clicks), o su fixture deja el knob nuevo en su valor
    neutro (dos tests de EconomyKit pineaban que el precio lleva el
    `incomeMultiplier` crudo: verdes sólo porque sus fixtures dejan el exponente
    en 1), o el literal del escenario **dejó de caer donde su nombre dice** (el
    "9.000.000, un peso menos que el Fast Food" de `BestHireTests` pasó a
    alcanzarle). REMEDIO: derivá el corte de la config y llamá a la función del
    código en vez de replicarla; y cuando un knob cambia, **grepeá también el
    código y los comentarios**, no sólo el catálogo.

25. **Un fixture puede ser PUNTO FIJO de la transformación que dice cubrir.** El
    save v3 de `SaveMigratorTests` traía `tap: 1` y el reescalado del rebalance
    manda `1 → 1`, así que **borrar la llamada de `migrateV3toV4` dejaba la
    suite entera verde**: la conversión estaba probada como función y no como
    parte de la migración. Al escribir un fixture para una transformación,
    elegí un valor que la transformación MUEVA.

26. **Una serie de métricas puede no poder medir el knob que se está
    discutiendo.** `floorUnlockHireSeconds` (lo que cuesta entrar a cada piso)
    **no puede ver `hireCostGrowth`**: un piso se abre mergeando, no comprando,
    así que el contador de compras de su tier base vale 0 y `growth^0 = 1`. Se
    defendió el growth con esa serie durante una ronda entera. Para el
    compounding están `floorUnlockPeakHire{Type,Purchases,Seconds}`, que publican
    el tipo más comprado de la run (en el árbol de hoy el bot llega a **785
    compras** del mismo tipo; 870 en el A/B pre-(a) de la bitácora).
27. **Una lección contextual del tutorial puede nacer EN MEDIO de un test de
    UI ajeno y comerse sus taps por coordenada.** SÍNTOMA: un test que venía
    verde falla con "no apareció X" tras darse monedas o abrir pisos con el
    panel de debug — medido con `AscentRenderingUITests` (113 s): su +1M
    encendió `canAffordAnyUpgrade`, la lección de Mejoras nació y su globo,
    en la mitad superior, se comió el tap por coordenada a `hud.debug`.
    ARREGLO de diseño: en cualquier corrida `--uitest-*` las lecciones
    arrancan APAGADAS (`tutorialLessonsAutorun`, `+Debug`); el único test que
    las quiere las pide con `--uitest-lessons`. Bajo unit tests (XCTest en el
    host) el director y el gate del bootstrap también arrancan apagados —
    `XCTestConfigurationFilePath`, mismo criterio que StoreManager — y cada
    test arma su escenario (`beginTutorialPhase()` /
    `tutorialLessonsAutorun = true`).

28. **El tap sintético del MCP del simulador no activa las filas-botón del
    `ScrollView` de FisuJobs** (medido: tres taps al centro exacto de la fila
    con `ftue.spawned` en falso), aunque sí activa tabs, cierres y tablero.
    XCUITest (`.tap()` sobre el elemento) compra sin drama, y el dedo humano
    también. Si un recorrido manual por agente "no compra": verificar el
    efecto en el plist del contenedor (`simctl get_app_container … data`)
    antes de sospechar del juego, y hacer ese paso vía XCUITest.

29. **El catálogo de strings SÍ se puede editar con un script — si el script
    escribe el formato de Xcode.** La regla del §2 (no lo toques, te deja un
    diff de 2.400 líneas) describe la consecuencia, no una imposibilidad: lo que
    la desactiva es reproducir el formato canónico. Son tres cosas —dos espacios
    de sangría, `" : "` como separador, y las claves en **orden natural**— y la
    tercera es la que se hace mal sola: Xcode compara los números como números,
    así que `skins_5` va ANTES que `skins_20` y un `sorted()` pelado los da
    vuelta. La verificación es barata y va ANTES de escribir: serializá el
    archivo sin cambiarle nada y exigí `diff` vacío.

    Con eso medido salió también que el archivo tenía **3 claves fuera de orden
    al final** (`skin.name.diamante`, `skin.name.oro`,
    `skins.unlock.upgrades_maxed`), de algún append anterior a mano. Al
    reescribirlo ordenado se acomodaron; el orden relativo de las otras 472
    quedó intacto.

30. **Actualizar Xcode A MITAD de un frente rompe en cadena, y cada eslabón
    engaña distinto** (Xcode 26.6, medido el 2026-08-25). Los cinco eslabones
    y sus arreglos, EN ORDEN: (1) un **`runtime match` override**
    (`xcrun simctl runtime match list` → «User Override») puede dejar el SDK
    nuevo corriendo sobre el runtime viejo: la app compila pero **se ve
    espantosa** — los colores y paneles del asset catalog no decodifican y
    SpriteKit se ve bien (el síntoma es «la UI de SwiftUI desnuda») — y el
    override además le miente al descargador («iOS is already downloaded»).
    Fix: `runtime match set <sdk> --default`. (2) Recién ahí
    `xcodebuild -downloadPlatform iOS` resuelve y baja el runtime que
    corresponde. (3) `build/DD` con module cache de dos SDKs se borra entero
    (trampa 1 agravada). (4) `SWIFT_TREAT_WARNINGS_AS_ERRORS` ahora alcanza
    al clang importer: un header DEPRECADO del propio SDK (StoreKitTest) mata
    el build — `OTHER_SWIFT_FLAGS: -Xcc -Wno-error=deprecated-declarations`
    en `project.yml` (los warnings de NUESTRO Swift siguen siendo errores).
    (5) El `StoreKitTest` del **runtime 26 aborta** `SKTestSession` fuera de
    un runner XCTest (SIGABRT; cargar XCTest con `dlopen` NO alcanza) —
    `StoreManager` degrada con `#available(iOS 26.0, *)`: la tienda local por
    `simctl` queda ausente en 26 (por Xcode el scheme la inyecta igual). Y la
    asimetría de §6 (unit ANTES que UI) **sigue viva en runtime 26**: se
    re-midió con los 11 rojos exactos de StoreKit.

## 8. Qué queda

### Lo que dejó el rediseño de UI (2026-08-16)

**1. ✅ HECHO (2026-08-16) — el batch de los 15 iconos corrió entero y está
integrado y pusheado** (`d304fe3`): opacidad sana en los 15 (18–51%, umbral
12), cero descartes, suites de las pantallas tocadas en verde, y los
vectoriales quedan de fallback. Costó dos hallazgos que ya están corregidos y
documentados: el robo de foco (runner endurecido, ver arriba) y **las vocales
con tilde que el keystroke pierde** (bug #7 de `HANDOFF-arte-gemini.md`; los
prompts nuevos van en ASCII). Lo de abajo queda como referencia para el
próximo batch. — La
cola está armada y verificada (tarea 19): 15 prompts `.md` numerados
**213–227** en `Tools/asset-pipeline/prompts/gemini_pro/` con sus 15 entradas
gemelas en `prompts.json`, **los 15 sin generar** —cada `.md` con su línea
`- **estado**: pendiente`— y **sin campo `referencia`** (los iconos de UI no
adjuntan el Fisura). Cero PNG de esas claves en `ui.atlas`, verificado el
2026-08-16.

⚠️ **El estado de la cola vive en los `.md`, no en `prompts.json`.** Los dos
runners parsean esa línea (`STATE_RE` en `gemini_selenium_runner.py`), y
`pending_assets()` saltea un asset por cuatro caminos: `estado: hecho`, el PNG
ya en `dropbox/`, el PNG en `dropbox/procesadas/`, o la clave ya presente en
`assets_manifest.json`. `mark_asset_done` reescribe el `.md` a `hecho` recién
después de verificar el PNG. Si editás un `.md` a mano, ese es el campo.

No se generó ninguna imagen a propósito: el runner tipea con `osascript` y el
permiso de Accesibilidad lo tiene **Terminal.app y nada más** (trampa 11, que
ahora tiene una salida para agentes — ver ahí). ⚠️ **El batch se intentó el
2026-08-16 y frenó con cuota CERO**: la ruta del permiso funcionó, pero con
otros frontends usando la máquina el foco se roba a mitad del tipeo (asset 1:
0 de 2099 caracteres; asset 2: 2146 de 2150) y el guard `prompt_landed` abortó
antes de enviar las tres veces. De ahí salió el **runner endurecido**
(`78119ef` + `acaf3e6`, review adversarial con fuzz de 1.000 robos: cero
prompts corruptos enviados): tipea en tandas de 250 con verificación de
frontmost y de prefijo, avisa `⚠️ foco robado por «X»` nombrando a la app
ladrona, y su peor caso es abortar con cuota cero — nunca mandar un prompt
barajado. Knobs nuevos: `--type-chunk` (250) y `--type-pause` (0,25 s).
**Corré el batch con la máquina quieta**: cada robo de foco quema un
reintento y a los 3 fallos seguidos frena. La receta, con el Chrome dedicado
en `:9222` logueado en Gemini **Pro**:

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

⚠️ **Y tres claves del atlas están recortadas A MANO, cosa que el pipeline no
sabe**: `ui_elevator`, `ui_coin_plus` y `ui_gift_bow` (`@2x`/`@3x`) se
recortaron al bbox del alfa +2% de aire el 2026-08-18, porque salían con
~40–60% de lienzo transparente y el dibujo rendía chico en pantalla. Si el
batch los regenera, vuelven con esos márgenes: hay que re-recortarlos antes
de integrar.

**2. Costura de los 15 iconos: ✅ COMPLETA — las copas y el calendario.**

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

✅ **Y `ui_daily_calendar` aterrizó el 2026-08-16** (cierre post-merge, tarea 1:
cherry-pick de `84a2af6` desde la rama paralela `fix/iconos-gameicon`, esta vez
sí revisado). El calendario va **al frente de la tarjeta del daily** en
`FisuEvolution/UI/Gifts/GiftsView.swift`, a 44 pt dentro del mismo plato de
56 que usan `BoostGlyph` y `ScreenGlyph`, con la nota "se cobra solo" corrida
al costado. Era el único de los 15 iconos sin call-site: **ya no queda
ninguno**. Mientras el atlas no tenga la clave, cae al `VectorCalendarIcon` y
se ve igual de bien — que es exactamente lo que hace el fallback.

**3. Los ajustes ya están listos para App Store.** `SettingsView` trae las
seis secciones del spec: **idioma** (sistema/es/en, con su clave propia
además de `AppleLanguages`), audio, juego, compras (con "Restaurar"),
**legales** y "Acerca de". Las **notificaciones** tienen recordatorio diario a
las 19:00 vía `NotificationsManager`, y los **dos documentos legales**
(privacidad y términos) se leen adentro del juego, en es+en, desde
`Resources/Legal`. O sea que RF-02c ya no necesita nada de UI: lo único que
falta sigue siendo la cuenta de Apple Developer.

**4. ✅ El review integral de la rama y el ticket post-merge: los dos HECHOS.**
El review integral del rediseño corrió con su ola de fixes
(`ecf35b2..2f71ff3`), y lo que dejó triageado para DESPUÉS del merge se ejecutó
entero en `fix/cierre-post-merge`: **7 tareas**, y el review integral de esa
rama dio **ready to merge con CERO ola de fixes de código**. Commits y detalle
tarea por tarea en **`Docs/SESION-2026-08-16-cierre-post-merge.md`**; lo que
entró:

- **El calendario del daily**, acá arriba en el punto 2.
- **El cluster spawn muerto se fue de `GameState`** (`HireOffer`,
  `showSpawnHint`, `hireOffer` y el cálculo que los refrescaba). No se perdió
  ninguna aserción: los pins se mudaron a `TowerActions`, que es donde vive la
  conducta. ⚠️ Lo que ese borrado sí dejó huérfano es un requisito de UX — está
  en el 📌 de §4, "Gate de contratación".
- **`StatePill` → `StateBadge`** en Upgrades: una sola gramática de badge, y
  tocarla ya no castiga con haptic+audio de error.
- **Un pase de accesibilidad en lote**: `PricePill` dice la moneda y **qué**
  compra en vez de un monto suelto, `ProgressBar` tiene label, se fueron las
  paradas mudas de VoiceOver, y el número de piso y el "estás acá" del ascensor
  escalan con Dynamic Type.
- **Los residuales de la ola**: la tarjeta de la tienda degradada se centra
  aunque haya banner de error; el riel fijo de la tienda (**104**, derivado del
  `minWidth` 92 del `PricePill`, igual que el 96 de FisuJobs) devuelve los
  títulos de producto a un renglón; `MetaState.init(from:)` decodifica
  `derivedEffects` con `decodeIfPresent`, así que un sobre sin esa clave ya no
  se lleva la partida puesta; el migrador estrenó un e2e desde JSON crudo v3; y
  `ui_pill_currency` salió del manifest y del atlas, y quedó **anotado como
  "retirado" en el índice de prompts** (la fila 113 sigue ahí, y su `.md`
  también: es historia de otra tanda, no se borra).
- ✅ **`AscentRenderingUITests` volvió** — las tres causas están en la trampa 2.
  La que nadie tenía: el callejón cubre los tiers **1..4**, así que el primer
  ascenso pide **cuatro** fusiones y no dos. **Ya no queda ningún
  `-skip-testing:` en la receta de §6.**

**Después de esto quedan dos cosas, y ninguna es código**: el batch de los 15
iconos del punto 1 —la cola 213–227 está intacta y verificada— y los dos gates
humanos de F6, la cuenta de Apple Developer (RF-02c) y una fuente de audio
(RF-14).

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
| **14** · música y efectos | **No hay fuente de audio.** Re-verificado el 2026-08-07 y otra vez el **2026-08-16**: el MCP de audio disponible en la sesión hace **sólo TTS**, y su contrato prohíbe usarlo para música o efectos standalone (esos modelos existen, pero para otro pipeline). Detalle en `SESION-2026-08-16-cierre-post-merge.md` | Un MCP con música/SFX standalone, o audio CC0 a mano |

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
- ~~**El título flotante de los paneles deja pasar el texto por detrás** al
  scrollear. Es de todos los paneles, no de uno.~~ **MUERTO DE RAÍZ
  (2026-08-18, la hoja contenida).** El parche eran las bandas crema opacas de
  las 12 cabeceras (y sus `.toolbarBackground(Color("PaletteCream"))`); se
  retiraron junto con el defecto que tapaban. Las hojas ya no ponen el marco
  como `.background`: se envuelven en
  `panelSheet(material:awning:header:ornament:)` (`UI/Art/PanelFrames.swift`),
  que mete la cabecera ADENTRO del pergamino —debajo del toldo, al ancho de
  la columna, sin banda opaca— y hace del `ScrollView` una región recortada
  con fundido en los bordes que muere contra la banda inferior del marco,
  ahora a la vista. El texto no PUEDE pasar por detrás del título: el scroll
  arranca debajo de la cabecera y está clipeado. La hoja flota recortada a
  sus esquinas y con sombra sobre el juego atenuado
  (`.presentationBackground(.clear)`).
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

- `Docs/superpowers/specs/2026-08-26-cofres-de-skins-design.md` — el diseño de los cofres:
  la bolsa, el sorteo, las fuentes con su cuenta medida, los siete latidos de la animación.
- `Docs/superpowers/plans/2026-08-26-cofres-de-skins.md` — el plan de 12 tareas. ⚠️ Lleva
  adentro un **mapa de los helpers de test que existen de verdad**, porque el plan inventó
  cuatro que no existían.
- `Docs/SESION-2026-08-26-cofres-de-skins.md` — la sesión: las ocho decisiones del dueño, los
  dos assets que se regeneraron y por qué, y lo que falta.

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
| **`SESION-2026-08-23-desaceleracion.md`** | **La desaceleración: por qué una run que no se traba no le da trabajo al prestigio, el knob de escalada con su umbral (y por qué el umbral no es adorno), "trabarse" convertido en métrica publicada, las 9 reencarnaciones que NO se forzaron, el total que NO se escaló, y el arreglo acotado del build para que el dueño pueda jugarlo** |
| **`SESION-2026-08-23-fusiones-cobradas.md`** | **Las fusiones dejan de ser gratis en el simulador (y por qué eso era un sesgo, no una simplificación), el barrido de la profundidad N=6/7/8 con las cinco métricas, la conversión a horas del dueño con el factor de 3×, y por qué la compra en lote se empezó y se descartó** |
| **`SESION-2026-08-23-precio-atado-a-la-frontera.md`** | **La cuarta ronda de balance: el precio de contratar anclado a tu FRONTERA (la regla de precios nueva, que reemplaza a la de los 600 clicks), la compuerta convertida por fin en dial de dificultad, la tercera ceguera del bot, y el hallazgo de que la mitad del tiempo activo es apretar el botón y no esperar plata — con las cuatro salidas que el dueño tiene que elegir** |
| **`SESION-2026-08-22-compuerta-por-distancia.md`** | **La tercera ronda de balance: la compuerta medida en tiers, las dos cegueras del simulador y el hallazgo de que el contrato de 20-30 h nunca se cumplió — con las tres salidas que el dueño tiene que elegir. Y la trampa del Xcode 26.6 sin runtime de iOS 26** |
| **`SESION-2026-08-21-nombres-en-ingles.md`** | **La sesión más reciente: por qué el nombre del personaje no se traducía, la mesa de las 17 traducciones culturales con su porqué, y qué se descartó (un campo por idioma en `tiers.json`)** |
| **`SESION-2026-08-21-rebalance-pacing.md`** | **El rebalance de pacing: las tres métricas antes/después, los dos knobs que hacen cosas distintas, las tres decisiones del dueño con lo descartado y su número, y los cuatro diagnósticos que salieron errados antes del bueno** |
| **`SESION-2026-08-25-correcciones-ui-y-xcode-26.md`** | **La sesión más reciente: el aire del botón, la manito única, la carta del special con recap, y los cinco eslabones de Xcode 26.6** |
| **`SESION-2026-08-21-tutorial-high-end.md`** | **La sesión más reciente: el tutorial rehecho — la fase corta arbitrada por la cola, las 8 lecciones con sus señales, el puntito de logros y las trampas 24/25** |
| **`SESION-2026-08-21-telon-del-menu.md`** | **El telón blanco de las pantallas empujadas del menú: la medición, el arreglo por versión de iOS y qué quedó sin verificar** |
| **`SESION-2026-08-19-skins-oro-diamante.md`** | **Las 86 skins de material: el catálogo de un id por material, el desbloqueo de cada una y los tres bugs medidos del pipeline de generación** |
| **`SESION-2026-08-18-recorte-de-fondo.md`** | **Por qué el recorte dejó de ser por saliencia, con la medición de los 219 assets y el criterio topológico que lo reemplazó** |
| **`SESION-2026-08-17-rediseno-v3.md`** | **La sesión más reciente: los materiales v3 de las referencias, tarea por tarea, con la verificación y la trampa del cwd — y sus arcos del 2026-08-18, el tercero es la hoja contenida** |
| **`SESION-2026-08-16-cierre-post-merge.md`** | **Las 7 tareas del ticket post-merge con sus commits, el veredicto del review de rama y el backlog que sobrevive** |
| **`SESION-2026-08-14-rediseno-ui.md`** | **Las 20 tareas del rediseño de UI, con sus fix rounds, rulings y avisos vivos. La fuente de verdad del detalle de esa rama** |
| **`SESION-2026-08-06-correcciones-de-playtest.md`** | **El estado de la sesión de las 16 correcciones: qué quedó abierto, qué está en vuelo y los gates humanos. Empezá por acá si retomás ese trabajo** |
| `SESION-2026-08-05-fallback-de-contratacion.md` | El fallback del botón y la fila trasera invisible |
| `SESION-2026-08-17-cola-de-celebraciones.md` | La cola que reproduce las celebraciones de a una |
| `superpowers/specs/2026-08-10-fusion-asistida-design.md` | Los dos gestos de fusión, con los radios y por qué cada uno |
| `superpowers/specs/2026-08-10-contadores-de-bonus-activos-design.md` | Los contadores del HUD y por qué la proyección no lleva el tiempo |
| `superpowers/specs/`, `superpowers/plans/` | Specs y planes por feature |
