# Sesión 2026-08-22 — La compuerta por distancia (tercera ronda de balance)

> **El hallazgo, y es el que importa**: arreglar dos cegueras del simulador
> destapó que **el contrato de 20-30 h nunca se cumplió**. Lo cumplía un bot que
> jugaba mal. La partida embarcada dura **13,64 h activas hasta dios** y **6,67 h
> hasta maxear las siete**; sin reencarnar dios llega en **3,28 h**, que es al
> minuto lo que el dueño reportó a mano ("me lo gané en 3 horas", 2026-08-20).
>
> Los números, los barridos completos y los descartes están en
> `Docs/balance-log.md`, sección "Tercera ronda". Acá está el **por qué** y lo
> que hay que decidir.

Commits: `5b5c82f` (el bot elegía la peor mejora) · `a03ea24` (la compuerta en
tiers + el bot compra lo que FisuJobs vende).
Diseño de partida: `Docs/superpowers/specs/2026-08-22-compuerta-por-distancia-design.md`.

---

## 1. Lo que se pidió y lo que se hizo

El dueño decidió que la compuerta de contratación pase de medirse en **pisos** a
medirse en **tiers**: un tipo de tier `T` es contratable sólo si tu frontera de
merge llegó a `T + N`, con el Fisura exento. La tarea era implementarla, calibrar
`N` con el simulador, y cerrar antes la deuda de la ronda anterior.

Se hizo todo eso. Lo que no estaba previsto es que la calibración fuera imposible
hasta arreglar el bot por segunda vez, y que al arreglarlo apareciera que el
juego mide un tercio de lo que se creía.

---

## 2. Las dos cegueras del simulador

### 2.1 Elegía la mejora por personaje más cara (deuda de la ronda 2)

`nextAction` rankeaba con `max(by: contribution)`. Eso alcanzaba mientras la
ganancia de un nivel fuera un factor **constante**: con `2^nivel`, subirle un
nivel a cualquiera duplicaba su aporte, así que el que más aportaba era también
el que más ganaba. Con el efecto secuencial (`1 + nivel`) la ganancia marginal es
`aporte × 1/(1+nivel)` y `contribution` **ya incluye** el multiplicador comprado:
el tipo más mejorado encabezaba el ranking justo cuando su próximo nivel es la
peor compra del tablero (ganancia plana contra `costGrowth^nivel`).

Y el sesgo iba para el lado peligroso: como el bot toma UN candidato de mejora
por tick, si ése no pasaba el payback se quedaba **sin comprar ninguna**. O sea
que el juego medido tardaba MÁS que el real.

Costo del arreglo, mismo árbol: maxear 24,67 → 22,33 h · dios 33,23 → 29,70 h.

### 2.2 Compraba sólo el tier BASE de cada piso (la grande)

El argumento viejo era razonable: comprar más arriba nunca conviene, lo garantiza
`tierPremium`. Y valía **mientras la compuerta se midiera en pisos** — habilitado
un piso, su tier base era la compra más barata y punto.

Con la distancia medida en tiers eso se cae: el tier más alto que podés comprar
es `frontera − N`, que **casi nunca es un tier base**. Un bot que sólo compra
bases redondea su distancia hasta el próximo borde de piso, y con N=5 se queda
mergeando Fisuras hasta que la partida no se termina (medido: maxTier 9 a los 90
días).

El arreglo es chico y no inventa política: `hireActions` ofrece todos los tiers
habilitados de cada piso, y quién gana lo sigue decidiendo la regla de siempre
—la compra deseable **más barata**—. Así el `tierPremium` sigue mandando hasta
que la curva por tipo (`growth^compras`) lo pasa, que es exactamente lo que hace
el jugador cuando el Fisura número doscientos sale más que un Trapito.

Costo del arreglo, con N=4 en las dos columnas: maxear **26,00 → 6,67 h** y el
peor paso del arco **×342,95 → ×7,47**.

> **La lección de método, por tercera vez en esta rama**: cuando una regla del
> juego cambia, hay que preguntarse qué SUPUESTO del bot dependía de la regla
> vieja. Acá el supuesto ni siquiera estaba escrito como supuesto: estaba
> escrito como una optimización ("comprar arriba nunca conviene") con su
> justificación al lado.

---

## 3. Por qué N=5, y por qué N no es un dial de dificultad

El barrido completo está en la bitácora. En resumen: **N ≥ 8 rompe el juego**
(hasta que la frontera llega a `N+2` lo único contratable es el Fisura, así que
hay que mergear `2^(N+1)` de ellos contra una curva de `1,06^compras`), **N=7**
concentra ese mismo muro en el paso a corporativo (×342,95) y manda la primera
reencarnación a 24 h de pared, **N=6** empeora el gradiente sin alargar nada, y
**N=4 y N=5 miden igual**. Se eligió **5**: es lo que pidió el dueño y deja el
corte de lo contratable a mitad de piso en más tramos.

Lo que el barrido enseñó de paso es más importante que el valor:

**Una compuerta más profunda ABARATA este juego.** `yieldGrowthPerTier` es 2,8 y
el factor de merge es 2, así que bajar un tier abarata la unidad 2,8× y sólo
duplica cuántas hacen falta. Y el `tierPremium` no lo frena porque se reinicia en
cada piso: bajar un piso entero sale `2⁴/2,8⁴ = 0,26×`. Medido: N=4 → 6,67 h,
N=6 → 5,34 h.

Es también por qué reencarnar volvió a ser una trampa. Si la torre se sube con
monedas y backfill barato, el ORO no hace falta.

---

## 4. Qué quedó del contrato

| métrica | contrato | medido | |
|---|---|---:|---|
| maxear las siete | 20-30 h activas | 6,67 h | 🔴 |
| reencarnaciones al maxear | ≤ 8 | 7 | ✅ |
| dios después de maxear | sí | 13,64 vs 6,67 h | ✅ |
| sin reencarnar más lento | sí | 3,28 vs 13,64 h | 🔴 |

`PacingTests.theOwnersTargetsAreMet` **queda en rojo a propósito** (unit 410/411).
No se aflojó y no se re-pinea: esa suite existe para gritar cuando el juego deja
de cumplir lo que el dueño pidió, y hoy no lo cumple. Su docstring lleva el
diagnóstico y el puntero a la bitácora.

Lo que **sí** mejoró, y no es poco: el acantilado corporate → luxury pasó de
×90,86 a ×5,27, el peor paso del arco de ×90,86 a ×7,85 (la guarda de
`floorGradient` bajó de 118,1 a 10,21, o sea que aprieta once veces más), y
ningún salto entre hitos pasa de 4,45 h activas contra el agujero de 10,0 h que
dejó la ronda 2.

---

## 5. Lo que hay que decidir (es del dueño, no de una calibración)

Ningún knob disponible llega a 20-30 h: los nueve están medidos en la bitácora y
ninguno pasa de ~13-17 h, **porque la torre entera dura eso**. Las tres salidas:

1. **Que el precio de contratar deje de seguir a `tapYield(tier)` tan de cerca.**
   Es la causa raíz. Toca la regla de "600 clicks".
2. **Que `tierPremium` deje de reiniciarse en cada piso.** Cierra el agujero sin
   tocar los 600 clicks dentro de un piso, pero `1,8³⁶` hace impagable el tope de
   la torre: pediría una constante mucho más chica y re-pinear precios.
3. **Re-enunciar el contrato sobre la partida real.** Si 13,64 h a dios y 6,67 h
   a maxear le sirven, lo que cambia es el número y no la economía.

---

## 6. El tutorial: lo que se tocó y lo que falta

Se hizo el **cambio mínimo** para que el guion no enseñe una mecánica que ya no
existe. Dos strings (es + en):

- `tutorial.step.hire`: "contratá a otro para el callejón" → "contratá otro
  Fisura. **Es el único que se compra de una**".
- `tutorial.step.finish`: "Seguí fusionando: con un T5 se abre el piso 2" →
  "Comprá Fisuras, fusionalos, y **los nuevos aparecen en los pisos de arriba**.
  Ése es el juego."

Y uno que ya estaba viejo desde la Task 2 y ahora mentía más: `tutorial.tip.quickhire`
decía "contrata al mejor que te alcance" (el atajo vende el tier base desde el
2026-08-21, y ahora además lo acota la compuerta) → "al mejor que tengas
habilitado".

**Lo que faltaría para el tutorial completo** (es trabajo de otra ronda y el
dueño lo va a querer mirar):

1. **Un paso propio del ascensor.** El diseño dice "el ascensor se usa": comprás
   abajo y el resultado aparece arriba. Hoy eso sólo se cuenta en el cierre; el
   ascensor tiene su lección contextual (`tutorial.tip.elevator`) pero se dispara
   por piso nuevo, no por el bucle.
2. **Una lección contextual dentro de FisuJobs para la fila bloqueada.** El
   mensaje nuevo ("Fusioná hasta el tier N") explica QUÉ falta pero no CÓMO; la
   primera vez que el jugador ve una fila gris es el momento de enseñar que se
   compra abajo y se sube mergeando.
3. **El paso de contratar apunta al tab, no a la fila.** Con una sola compra
   libre, iluminar la fila del Fisura adentro de FisuJobs enseñaría la regla en
   vez de sólo la navegación.

---

## 7. Trampa de máquina que costó una hora (no es del proyecto)

Xcode se actualizó a **26.6 el 2026-08-24** y la máquina quedó con el único
runtime de simulador **iOS 18.6**, que es de Xcode 16. Consecuencias en cadena, y
cada una tapa a la siguiente:

1. `xcodebuild` **no lista ningún destino de simulador**. Se destraba con
   `xcrun simctl runtime match set iphoneos26.5 22G86`, que empareja el runtime
   viejo con el SDK nuevo.
2. Después falla `actool`: **`AssetCatalogSimulatorAgent` no arranca** porque el
   `DVTFoundation` de Xcode 26 está compilado para iOS-simulator 26.4 y el
   runtime 18.6 no tiene `_swift_coroFrameAlloc`. No hay flag que lo evite —
   falla igual sin `--app-icon` y con destino genérico. Lo único que lo saltea es
   **sacar `Assets.xcassets` del target y regenerar con xcodegen**.
3. Y después falla el módulo de **`StoreKitTest`**: su header usa
   `SKPaymentTransactionState`, deprecado en iOS 18, y el target compila con
   `-warnings-as-errors`. Se destraba con
   `OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'`.

`xcodebuild -downloadPlatform iOS` **no sirve**: cree que la plataforma ya está
descargada (por el 18.6) y ninguna versión 26.x figura como disponible. La salida
de verdad es instalar el runtime de iOS 26 desde Xcode > Settings > Components,
que es un gate humano.

⚠️ Las corridas de esta sesión se hicieron con esos tres parches. El de
`Assets.xcassets` es el único que cambia lo que se ejecuta: la app corre **sin
catálogo de colores**, así que los `Color("Palette…")` caen al default. No afecta
a los tests unitarios y la suite de UI pasó igual (**48/48, sin skips ni
flakies**), pero un test que juzgara color no serviría así.

---

## 8. Cómo terminó

| suite | número |
|---|---|
| EconomyKit (`swift test`) | **242 verdes** |
| `FisuEvolutionTests` | **411, con 1 rojo declarado** (`theOwnersTargetsAreMet`) |
| `FisuEvolutionUITests` | **48/48**, una corrida, sin `-skip-testing:` ni flakies |

Cero warnings de compilador. Simulador propio (`t8-compuerta`) por UDID, borrado
al cerrar.
