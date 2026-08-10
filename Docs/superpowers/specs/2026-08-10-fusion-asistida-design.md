# Fusión asistida: hermanos que se destacan y doble toque

> Spec de diseño. Fecha: **2026-08-10**. Aprobado por el dueño el mismo día.
> Pedido original: *"al agarrar a un personaje, los personajes del mismo tipo
> agrandan su hitbox y saltan a la layer 1 para que sea más fácil combinar y
> evolucionarlos. También: si hay dos que están muy juntos podés darle doble
> click a uno y se mergean solos, con su debida animación. Añadí esta última
> mecánica al tutorial."*

---

## 1. El problema

Fusionar es la acción central del juego y hoy es la más fiddly. Tres causas, y
sólo dos están en el pedido:

1. **El blanco se te camina.** Los personajes deambulan a 44 pt/s
   (`BoardScene.wanderSpeed`). Mientras arrastrás uno, el que querés como
   destino se corre más de medio cuerpo por segundo.
2. **No se ve quién es compatible.** Con hasta diez personajes amontonados en la
   franja de la multitud, y con el z resuelto por profundidad (`depthZ`), el
   compañero del mismo tipo puede estar tapado por otro.
3. **El drop se resuelve contra el lugar equivocado.** `cellIndex(at:)` compara
   el punto donde soltaste contra las **anclas lógicas** del slot
   (`anchorPoints`), no contra dónde está parado el personaje. Desde que el
   reconciliador conserva la posición deambulada, esos dos puntos difieren hasta
   ~media celda. Es la **trampa 3 del HANDOFF**: "los drags por coordenadas
   fijas fallan seguido". El helper `mergeTheHighlightedPair` de
   `TutorialUITests` barre **ocho** coordenadas distintas para conseguir un
   merge, y eso no es fragilidad del test: es el radio de captura cayendo en el
   lugar equivocado.

La causa 3 no estaba en el pedido pero entra en el alcance por una razón
concreta: **agrandar la hitbox sin corregirla agranda la hitbox equivocada.**

## 2. Qué se construye

### 2.1 `MergeTargeting` — la geometría, pura y testeable

Archivo nuevo `FisuEvolution/Scenes/MergeTargeting.swift`, siguiendo el
precedente exacto de `BoardReconciliation`: un tipo puro y chico que saca una
decisión de `BoardScene` para que el test pruebe **la regla y no una copia de la
regla**.

```swift
enum MergeTargeting {
    struct Unit: Equatable { let slot: Int; let typeId: String; let position: CGPoint }

    static func partnerSlots(of unit: Unit, among units: [Unit]) -> Set<Int>
    static func nearestPartner(of unit: Unit, among units: [Unit], within radius: CGFloat) -> Unit?
    static func dropTarget(at point: CGPoint, dragging: Unit, units: [Unit],
                           anchors: [CGPoint], cellSize: CGFloat) -> Int?
}
```

`position` son los **pies** del personaje en coordenadas de `fieldNode`, que es
exactamente lo que `touchesMoved` le asigna al nodo arrastrado: así el punto del
dedo y las posiciones de los demás se comparan en la misma métrica.

Radios, todos en múltiplos de `cellSize` y declarados como constantes del tipo:

| Constante | Valor | Para qué |
|---|---|---|
| `partnerCaptureRatio` | 1,5 | Soltar sobre un compañero del mismo tipo |
| `occupiedCaptureRatio` | 0,95 | Soltar sobre cualquier otro ocupado (valor de hoy) |
| `emptyCaptureRatio` | 1,05 | Mover a un ancla libre (valor de hoy) |
| `doubleTapReachRatio` | 2,0 | El compañero que engancha el doble toque |

`dropTarget` decide en este orden: compañero más cercano dentro de
`partnerCapture` → ocupado más cercano dentro de `occupiedCapture` → ancla libre
más cercana dentro de `emptyCapture` → `nil`.

**La corrección de la causa 3 vive acá**: los slots ocupados se miden contra la
posición real del nodo; las anclas quedan sólo para los slots **vacíos**, que
por definición no tienen nodo.

`doubleTapReachRatio` es 2,0 y no 1,0 por una medición: dos vecinos de columna
están a ~0,73 celdas de ancla a ancla, pero el deambular (±17 pt en X, ±47 pt en
Y en un iPhone de 844 pt de alto) los puede separar hasta **~1,8 celdas**. Un
radio de "que se estén pisando" haría que el doble toque falle entre vecinos, y
eso se lee como "a veces no anda", que es peor que no tenerlo.

### 2.2 Agarrar: los hermanos se destacan

**Se activa cuando el arrastre arranca** (cuando se cruzan los 10 pt de
`dragThreshold`), no en el `touchesBegan`. Un tap para ganar monedas dura ~100 ms
y es la acción más repetida del juego: prender y apagar el realce en cada toque
sería un parpadeo permanente sobre el tablero.

Mientras dura el arrastre, cada personaje del mismo tipo que el arrastrado:

- **deja de deambular.** Es la mitad del valor del pedido y no estaba en él: un
  blanco quieto es lo que hace que apuntar funcione. El mecanismo ya existe —el
  recorte del tutorial congela así a su personaje iluminado.
- **sube de capa**: `depthZ(position) + candidateZLift`, con `candidateZLift = 5`.
  Queda por encima de toda la multitud (cuyo rango de `depthZ` es de ~−0,3 a
  ~2,0) y por debajo del arrastrado (50), y conserva la profundidad relativa
  **entre** candidatos, así que un par no se dibuja plano.
- **pega un pop a escala 1,12** en 0,1 s.
- **captura el drop a 1,5 celdas** en vez de 0,95.

Al soltar o cancelar se restauran los tres: la escala vuelve a 1,0, el z lo
retoma `refreshCrowdDepth` en el frame siguiente y el deambular se reinicia.

Implementación: un `Set<Int>` de slots candidatos en `BoardScene`, calculado una
vez al arrancar el arrastre. `refreshCrowdDepth` suma un `Set.contains` sobre
≤10 nodos por frame; no hay allocations nuevas por frame.

⚠️ `releaseSpotlitNode()` reinicia el deambular de todo lo que no sea `dragNode`.
Tiene que saltear también a los candidatos, o el recorte del tutorial les
devuelve el paseo en medio de un arrastre.

### 2.3 Doble toque

El tap **siempre cobra sus monedas primero**. No se demora nada esperando a ver
si viene un segundo toque: el loop principal no puede pagar 300 ms de latencia
por una comodidad de fusión. La fusión es un efecto **adicional** del segundo
toque, no un modo distinto.

Condiciones para que el segundo toque fusione:

1. Cae sobre el **mismo slot** que el anterior.
2. Dentro de **0,3 s** del anterior.
3. Hay un compañero del mismo tipo a **≤2 celdas** (`nearestPartner`).
4. No hubo otra fusión por doble toque en los últimos **0,8 s**.

La condición 4 existe porque tocar rápido *es* un doble toque: sin ella, un
jugador haciendo tap para ganar monedas encadena el piso entero en dos segundos.
Con ella el ritmo máximo es una fusión por segundo, cada una con su animación
visible. **No se puede eliminar del todo el disparo accidental** —los dos
primeros toques de una ráfaga son indistinguibles de un doble toque deliberado—
y no hace falta: fusionar nunca es una pérdida en este juego.

Animación: el compañero se desliza hacia el tocado (0,18 s, `easeIn`) y al
llegar se ejecuta **la misma resolución que un drop**:

```swift
gameState.handleDrop(fromCell: compañero, toCell: tocado)
```

El resultado queda en el slot que tocaste, que es lo intuitivo. Y por pasar por
`handleDrop`, el doble toque hereda gratis el prompt de carrera (T9), el aviso
de piso de destino lleno, el ascenso de piso, el reveal del personaje nuevo y la
cadena de celebraciones. **Un solo camino de fusión, no dos.**

Para que las dos entradas compartan comportamiento por construcción y no por
disciplina, el bloque de ~65 líneas del `case .merged` sale de `touchesEnded` a
un método propio: `resolveMerge(from:to:at:sourceNode:)`.

Con Reduce Motion el deslizamiento colapsa a 0,01 s, igual que el resto de las
animaciones de la escena.

### 2.4 Tutorial

El paso `merge` **no cambia de forma**: conserva su recorte (que ya ilumina el
par entero, no una unidad) y su condición de avance `.merged`. Cambia su texto:

> ¿Dos iguales cerca? Tocá dos veces y se fusionan. O arrastrá uno sobre el otro.

Se completa con cualquiera de los dos gestos.

**Por qué un paso y no dos** (decisión del dueño, 2026-08-10): después de
contratar hay **un solo par mergeable**. Darle un paso propio al doble toque
deja al paso del arrastre sin par, y conseguirle otro cuesta tres pasos más
—ganar plata, contratar, fusionar— porque el paso de contratar tiene el tablero
bajo el scrim y no se puede tapear para ganar. El tutorial pasaría de 6 a 9
pasos justo donde el jugador quiere jugar.

El string nuevo va a `Localizable.xcstrings` en es + en, en el mismo commit que
la vista.

## 3. Tests

**`MergeTargetingTests`** (nuevo, 11 tests, unitario y puro): los radios justo
adentro y justo afuera; el compañero le gana a un ocupado incompatible más
cercano; entre dos compañeros gana el más cercano; el peor caso de deambular
entre vecinos sigue enganchando; soltarse encima de uno mismo no fusiona; y
**el drop se mide contra la posición real y no contra el ancla**, reproduciendo
la forma exacta del bug: soltar encima de un personaje deambulado te mudaba al
hueco de al lado.

**`BoardGestureTests`** (nuevo, 8 tests): la escena de verdad, armada con
`BoardScene(gameState:)` + `layoutBoard()` como ya hace `GameLoopWiringTests`.
Se testea acá y no con una captura porque las dos cosas son **invisibles en una
imagen**: el z sólo se nota cuando dos cuerpos se superponen y el deambular
congelado sólo se nota comparando cuadros. Cubre: el hermano sube
`candidateZLift` y queda adelante de los de otro tipo, deja de deambular, el de
otro tipo no se toca, soltar lo devuelve; y el doble toque manda al compañero
sólo si los dos toques son sobre el mismo personaje, dentro de la ventana, con
compañero cerca y fuera de la gracia.

Pide cuatro puntos de entrada `#if DEBUG` en `BoardScene` (`simulateGrab`,
`simulateRelease`, `simulateTap`, `debugNode`), en la línea de `simulateSwipe`:
ejecutan las **mismas** funciones que los gestos. Sin `SKView` nadie evalúa las
`SKAction`, así que el test observa el estado que los gestos dejan y no el final
de las animaciones.

**`BoardGestureUITests`** (nuevo, 1 test): el doble toque fusiona **fuera del
tutorial**, que es el caso difícil — ahí los dos personajes deambulan, mientras
que bajo el recorte del tutorial están congelados.

**`TutorialUITests`**: el recorrido entero sigue pasando. `mergeTheHighlightedPair`
pasa a hacer un doble toque sobre el recorte y deja de barrer ocho coordenadas —
el mismo test, mucho menos frágil.

⚠️ **Los tres frentes de test se verificaron al revés** (trampa 2: un test de UI
puede pasar sin probar nada). Con el realce anulado y el doble toque
cortocircuitado, fallan exactamente los cuatro tests que dependen de ellos y
ninguno más. La primera corrida al revés **no compiló** y `test-without-building`
corrió el binario viejo dando ocho verdes: hay que mirar que el build haya
pasado antes de creerle a una corrida negativa.

**EconomyKit no se toca.** Ni `MergeRules`, ni `TowerActions`, ni la economía,
ni el balance. Todo el cambio es de presentación y de resolución de gestos.

## 4. Fuera de alcance, a propósito

- Auto-merge global, botón de "fusionar todo" o cualquier automatización.
- Afordancia permanente entre pares cercanos (un glow o un ícono entre los dos):
  con diez personajes deambulando es ruido visual constante.
- Tocar los radios de la multitud, `crowdTopRatio` o el deambular.

## 5. Archivos

| Archivo | Qué pasa |
|---|---|
| `FisuEvolution/Scenes/MergeTargeting.swift` | **nuevo** |
| `FisuEvolutionTests/MergeTargetingTests.swift` | **nuevo** |
| `FisuEvolutionTests/BoardGestureTests.swift` | **nuevo** |
| `FisuEvolutionUITests/BoardGestureUITests.swift` | **nuevo** |
| `FisuEvolution/Scenes/BoardScene.swift` | candidatos, doble toque, `resolveDrop` y `returnToAnchor` extraídos, `cellIndex(at:)` borrado |
| `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` | texto del paso `merge` |
| `FisuEvolution/Resources/Localizable.xcstrings` | el string, es + en |
| `FisuEvolutionUITests/TutorialUITests.swift` | el helper pasa a doble toque |

⚠️ Cuatro archivos Swift nuevos ⇒ **`xcodegen generate` es obligatorio**.
`CharacterNode` no cambia: ya expone `typeId`. `EconomyKit` tampoco.
