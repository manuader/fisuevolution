# Sesión 2026-08-05 — Fallback de contratación, y la fila trasera invisible

## Qué se pidió

> "Hacé que mientras esté bloqueado el piso de arriba, el botón de comprar te
> deje comprar el personaje del piso de abajo (hasta que aparezca el cartel de
> que ya está el piso lleno)."

Y corregir el plan del gate, que había quedado escrito en la versión "dos pisos".

---

## 1. El fallback de contratación

### El problema

El gate (`d39b57d` y anteriores) exige el piso de arriba desbloqueado para
contratar. Consecuencia no buscada: **parado en tu frontera el botón no hacía
nada**, y la frontera es justo donde más falta hace material de merge. El
jugador quedaba con un botón que sólo decía "Todavía no".

### La regla

`TowerActions.hireTargetFloor(visibleOrdinal:unlockedFloors:floorTable:) -> Int?`
decide **dónde cae** la contratación:

1. Si el gate del piso visible pasa → ahí mismo.
2. Si no → el piso de abajo.
3. `nil` si el piso visible ni siquiera está abierto (el preview con candado):
   ahí el botón sigue diciendo "Piso bloqueado", como antes.

Baja **un solo piso** y no hace falta más: si el piso visible está abierto,
entonces el de abajo tiene el de arriba abierto y su gate pasa por construcción.
O sea que el destino del fallback es siempre el piso más alto donde el gate sí
deja contratar.

### Por qué NO cambia el balance

No es una regla económica nueva: contratar en el piso de abajo ya estaba
permitido, y `PacingSimulator` ya barre todos los pisos habilitados buscando
backfill rentable. El fallback es una afordancia de UI sobre acciones que el
juego ya permitía. **`PacingTests` pasó sin tocar una banda** — no hubo que
re-pinear nada ni traerle números al dueño.

### El botón

`GameState` pasó de tres booleanos ordenados (`visibleFloorIsFull`,
`visibleFloorAllowsHiring`, `visibleFloorIsUnlocked`) a **una** proyección
`HireOffer`, porque el botón dibuja título y detalle por separado y con
booleanos había que repetir el mismo if/else en dos lugares y mantenerlos
sincronizados a mano. Quedan cinco casos: `.here`, `.floorBelow(floorID:)`,
`.full(belowFloorID:)`, `.floorLocked`, `.unavailable`.

`visibleFloorIsUnlocked` sobrevive porque lo usa `BoardScene` para el scrim del
piso bloqueado. Los otros dos murieron con el cambio.

**Cuando la compra cae abajo, el detalle nombra el piso** ("🪙 50 · Alley"). Sin
eso la unidad aparecía en un piso que no estás mirando y el tap se sentía como
que no pasó nada — que es exactamente lo que la matriz de feedback prohíbe. Se
usa `TowerNaming.floorNameKey`, con claves estáticas: `LocalizedStringKey` no
resuelve claves armadas por interpolación y en este proyecto eso ya rompió dos
veces.

**Cero claves nuevas en el catálogo.** Las seis que hacían falta ya existían, así
que no hubo que tocar `Localizable.xcstrings` ni arriesgar el reformateo de
Xcode.

### Verificación

- `swift test` de EconomyKit: **144/144** (eran 141).
- Suite de app: **87/87** (eran 85), UI tests verdes, build con
  warnings-as-errors limpio.
- Dos wiring tests nuevos: uno recorre el ciclo completo (la unidad cae abajo, el
  piso visible no cambia, la cámara no se mueve, y al llenarse el callejón la
  oferta pasa a `.full`), otro fija que con el gate abierto no hay fallback.
- QA visual en iPhone 16 Pro con `--uitest-reset --uitest-unlock-tower`, que deja
  alley + urban abiertos y corporate cerrado:
  - `scratchpad/qa-shots/hire-fallback-piso-de-abajo.png` — parado en City, el
    botón ofrece "Hire El Fisura · 🪙 50 · Alley".
  - `scratchpad/qa-shots/hire-fallback-destino-lleno.png` — con el callejón en
    10/10, "Floor full · Merge to make room · Alley".
  - Parado **en** el callejón lleno el botón dice "Floor full" **sin** el tag de
    piso: el caso `belowFloorID: nil`. 60 fps en las dos.

### Detalle que conviene saber

El estado `.unavailable` (el viejo "Todavía no / Abrí el piso de arriba") quedó
**inalcanzable en la torre real**: requeriría que el piso visible esté abierto y
el de abajo no, y los pisos se abren de abajo hacia arriba. Se conservó como
caso total del enum y sus claves siguen en el catálogo.

---

## 2. Corrección del plan del gate

`Docs/superpowers/plans/2026-08-04-gate-de-contratacion-y-secuencia-de-celebraciones.md`
seguía escrito en la versión **"dos pisos"** en 18 lugares: el goal, los snippets
de tests, `let required = floorOrdinal + 2`, la tabla de strings ("Abrí dos pisos
más arriba") y los mensajes de commit. Era el único doc que contradecía al resto
y describía justo la variante que se midió que hace el juego interminable.

Se reescribió al número final (**uno**) con un recuadro al tope que deja asentado
el desvío, su medición y en qué commit ocurrió (`cdd8262`), para que el plan sirva
de referencia sin poder reintroducir la regla rota.

**También había dos comentarios en código con el número viejo** — el `MARK` de
`GameActionsTests.swift` y el del barrido de backfill en `PacingSimulator.swift`.
El comportamiento estaba bien en los dos (ambos delegan en `canHire`); eran sólo
los comentarios. Corregidos.

El `HANDOFF.md`, el `balance-log.md`, el spec y el doc-comment de
`TowerActions.canHire` ya estaban bien: dicen "el pedido original era dos y se
midió que rompe el juego", que es lo correcto.

---

## 3. La fila trasera era invisible (regresión de `d39b57d`)

### El síntoma

> "Los personajes que están arriba de cierto nivel de la pantalla son invisibles.
> Se pueden clickear y están ahí, pero no se ven."

### La medición

Se instrumentó `layoutBoard` con un log temporal de la posición y el z reales de
cada nodo, en vez de deducirlo. Con 9 unidades en el callejón, iPhone 16 Pro:

| | y | z |
|---|---|---|
| fila delantera (slots 0-4) | 38-43 | **+1.05 … +1.10** |
| fila trasera (slots 5-8) | **156-157** | **−0.078 … −0.092** |
| fondo del piso visible | — | **0.00** |

`alpha = 1.0` en las nueve, así que **no** era el bug viejo del pool. La fila
trasera estaba en z negativo, debajo del fondo de su propio piso. En pantalla: la
pill decía 9/10 y se dibujaban 6.

Pista que lo delató antes del log: se veían **cuatro etiquetas "T1" flotando sin
cuerpo**. Dentro de un `CharacterNode` todos los hijos comparten z, pero con
`ignoresSiblingOrder` SpriteKit batchea los labels aparte de los sprites del
atlas, así que contra el fondo perdían los cuerpos y sobrevivían los labels.

### La causa raíz

`depthZ` = `(rows × cellSize − y) × 0.01` sólo es positivo mientras
`y < rows × cellSize`, o sea **148** con `cellSize` 74. Y `fieldNode` estaba en
z 0, la **misma banda** que ocupan los `FloorNode` (`ordinal × 0.01`, 0 … 0.10).

`d39b57d` ("franja de piso más alta") subió `rowDepthRatio` de 0.95 a 1.55, lo
que mandó la fila trasera de y≈111 a y≈156 y la cruzó. El commit no introdujo el
defecto: **destapó** que las dos escalas de z compartían espacio y que cualquier
cambio de layout podía hundir a la multitud detrás de su propio fondo.

### El arreglo

`fieldNode` va montado en `BoardScene.fieldBaseZ = 10`, por encima de toda la
banda de fondos. Así `depthZ` puede seguir dando negativo sin hundir a nadie, y
la colisión se vuelve **imposible por construcción** en vez de depender de que
los ratios de fila queden por debajo de 148. No se tocaron los ratios: eso habría
sido arreglar el síntoma y el próximo ajuste visual lo reintroduce.

Todo lo que vive dentro del campo sube junto y conserva su orden relativo
(arrastre 50, labels de tap 100, ring 80, specials −1), y lo que tiene que ir por
encima está muy arriba (vuelo del ascenso 120, overlays de cámara 195-220).

**De paso cura un segundo síntoma del mismo origen**: `cancelDrag` deja el nodo
en `zPosition = 0` durante el snap-back, que en cualquier piso con ordinal ≥ 1 ya
estaba por debajo del fondo — el personaje desaparecía los 0,15 s que dura la
vuelta. Ahora ese 0 es un 10 absoluto.

### Verificación

`CrowdDepthTests` (nuevo, 3 tests) pinea la invariante: para cada piso del
catálogo real y seis anchos de pantalla, el z más bajo que puede alcanzar un
personaje queda por encima del z más alto de los fondos. Se lo vio **fallar
primero** con los números reales (−0.26 contra 0.1) fijando `fieldBaseZ` en 0, que
es lo que la escena tenía.

Suites: EconomyKit **144/144**, app **90/90**, UI verdes, pipeline 20/20.
Captura con el mismo save de la repro: `scratchpad/qa-shots/multitud-fila-trasera-visible.png`
— 9/10 en la pill y las nueve dibujadas, profundidad intacta, `nodes:65 draws:49`
igual que antes (el arreglo no cuesta render) y 60 fps.

⚠️ En la corrida completa falló una vez `refundRevokesEntitlement` (StoreKit con
`SKTestSession`); pasa aislado y no toca nada de esto. Es flake.

---

## 4. La multitud llega hasta la mitad de la pantalla

Pedido del dueño, siguiendo el hilo de `d39b57d` ("franja de piso más alta"):
**que se pueda llevar a los personajes aún más arriba, hasta la mitad de la
pantalla.**

### El cambio de modelo

La franja estaba definida en múltiplos de `cellSize` (`frontRowRatio` +
`rowDepthRatio`) y el deambular era una constante aparte sumada encima del ancla.
Eso tenía dos problemas para lo que se pidió:

1. `cellSize` sale del **ancho** de pantalla. Atar una medida vertical ahí hace
   que la franja encoja en un teléfono angosto y alto, que es justo donde sobra
   lugar.
2. Un deambular independiente puede sacar a un personaje fuera de la franja. Es
   exactamente así como la fila trasera terminó detrás del fondo (§3).

Ahora hay **un solo knob**, `crowdTopRatio = 0.5`: el techo de la franja en
fracción del ALTO de pantalla. `BoardScene.crowdBand(sceneHeight:cellSize:rows:)`
reparte las filas dentro de la franja y **deriva el deambular de ella** — cada
fila recorre exactamente `1/rows` del total, así que las filas cubren la franja
entera sin huecos y **ningún personaje puede pasarse por arriba**.

Medido en iPhone 16 Pro (874 de alto): `frontY` 112,3 · `rowDepth` 143,2 ·
deambular ±71,6 · techo **437,0**, que es la mitad exacta de 874. La fila
trasera llega a 424 de 437 en la captura.

### Dos cosas que el cambio arrastraba y hubo que resolver

- **La velocidad del deambular.** La duración de cada paso era fija (1,2 s), así
  que agrandar la franja no los hacía pasear más lejos sino **caminar 3× más
  rápido**. Ahora la duración sale de la distancia contra
  `wanderSpeed = 44 pt/s`, que es la velocidad que ya tenían.
- **El z se calculaba una sola vez desde el ancla.** Con ±20 no se notaba; con
  ±71 dos personajes pueden cruzarse de fila y el que quedó adelante se dibujaba
  detrás. Se vio en el log: `z=0.379` fijo mientras `y` iba de 110 a 171 a 68.
  `refreshCrowdDepth()` lo recalcula por frame sobre ≤10 nodos.

También hubo que mover el z de los **specials**: estaba en `−1` fijo, que
alcanzaba cuando el mínimo de la multitud era −0,09, pero con la franja alta ese
mínimo llega a −2,05 en las pantallas grandes y los specials se les habrían
puesto adelante. Ahora sale de la franja (`depthZ(topY) − 1`), así que se corrige
solo si la franja vuelve a cambiar. `CrowdDepthTests` lo cubre.

### ⚠️ Consecuencia visual, para el dueño

Los fondos están autorados con el **tercio inferior** transitable ("tercio
inferior despejado" pedía el prompt). La mitad de la pantalla queda por encima de
ese tercio, así que ahora la multitud pisa la zona donde el arte tiene la pared,
los fardos de cartón y el graffiti: se ven parados "adentro" del decorado en vez
de sobre el piso. Es inherente a lo pedido, no un bug.

**El knob para dialarlo es uno solo**: `crowdTopRatio`. 0,5 es lo pedido; 0,40
los deja justo arriba del tercio transitable. Decisión visual del dueño.

### Verificación

`CrowdBandTests` (nuevo) pinea las tres propiedades: el techo cae en la mitad
exacta de la pantalla, ningún personaje se pasa de él, y las filas cubren la
franja sin dejar hueco entre lo que recorre una y lo que recorre la otra — con
tres tamaños de pantalla. `CrowdDepthTests` ganó el caso de los specials.

Captura: `scratchpad/qa-shots/multitud-hasta-media-pantalla.png` — 10/10 con los
diez dibujados, profundidad correcta, 60 fps.
