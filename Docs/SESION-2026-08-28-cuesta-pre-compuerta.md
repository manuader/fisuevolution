# Sesión del 2026-08-28 — el muro adentro de la cuesta pre-compuerta

## Lo que pidió el dueño

> «¿A qué ratio encarecen los personajes a medida que los vas comprando? El
> fisura se pone muy caro y es bastante difícil llegar al tier 8. No quiero que
> el juego se vuelva aburrido. Hacé que el multiplicador de precio sea más chico
> (hoy por hoy, para llegar al tier 8 el fisura termina costando 1M cada uno y
> seguís con personajes que ganan mucho menos que eso). No tiene que ser tan
> caro, tiene que crecer más lentamente el precio.»

La respuesta a la pregunta: **6 % por compra, compuesto**
(`hire.defaultCostGrowth` 1,06), sobre el contador de compras de ESE tipo.

## El diagnóstico, y por qué el «1M» era exacto

El muro no está en el nivel del precio sino en su ACELERACIÓN, y el número que
lo muestra es el costo de subir cada tier de la cuesta pre-compuerta medido en
clicks de tu propia frontera:

    26 · 39 · 61 · 117 · 322 · 1.931 · 61.921
      ×1,5 ×1,6 ×1,9 ×2,8 ×6,0 ×32,1

Los seis primeros tiers son 2.500 clicks entre todos y el séptimo son 62.000 él
solo: a 3 taps/s, **de 14 minutos a 5 horas y media en un solo paso**. La última
Fisura de esa cuesta vale **1.730.555** — el «1M» del reporte, al dedo.

La causa es estructural y no un valor mal elegido: el exponente de la curva es
el contador de compras, y **ese contador se duplica con cada tier** (subir uno
pide `2^(f−1)` Fisuras), así que `growth^(2^k)` es una doble exponencial. Arriba
no molesta porque hay varios tipos comprables y el contador se reparte; abajo no
hay dónde repartirlo: **hasta la frontera 7 el Fisura es lo único que la
compuerta habilita**.

## Lo que se cambió

`floors[alley].hireCostGrowth: 1.03`, con `hire.defaultCostGrowth` **intacto en
1,06**. El peor salto de la cuesta pasa de ×32,1 a ×6,1 y la cuesta entera a ~20
minutos de tapeo, que es lo que el spec pide para esta fase.

**Bajar el global —lo que el pedido decía literalmente— se probó primero y midió
peor**: saca maxear de la banda de 20-30 h (15,96 h con 1,03) y sobre todo
desarma la pared, de seis runs trabadas a dos. Ese factor era la segunda pata de
la desaceleración y la cuarta ronda le había atribuido el mérito entero a
`frontierEscalationPerTier`. El override del piso arregla el arranque donde el
arranque vive y deja la torre quieta: maxear 20,67 → 20,33 h, dios 28,43 →
30,73 h activas, la pared en seis runs corriendo T13 → T20.

Es el segundo override del callejón, y tiene el mismo motivo que el primero (el
multiplicador a 25): el arranque es el único tramo de la torre con un solo
personaje comprable.

## El guard nuevo

`thePreGateClimbHasNoWallInIt` (en `GameContentValidationTests`): ningún tier de
la cuesta pre-compuerta puede costar 8× el anterior. Es aritmética pura sobre el
contenido real, no una banda del simulador, y **eso es a propósito**:
`pacing-sim` cronometra esta fase en 96 s porque su bot tapea a 6/s con todas
las mejoras puestas, así que el muro le pasa por al lado. La bitácora venía
anotando esta fase como demasiado RÁPIDA mientras el dueño se trababa en ella.

## Las dos trampas de esta sesión

**1. El barrido salió sin catálogo de mejoras, y dio la conclusión opuesta.**
`pacing-sim` resuelve `upgrades.json` al lado del `economy.json` cuando no le
pasás `--upgrades`; las nueve variantes vivían en un directorio temporal, así
que corrieron con `derivedEffects` en cero. Con esos números parecía que
cualquier bajada rompía el contrato y que el override del callejón era lo peor
de todo. La herramienta avisaba con un `⚠️` en su segunda línea y **el `grep` con
el que filtré la salida se comió el encabezado**. Lo destapó el sanity check:
1,06 tenía que reproducir los 20,67 h pineados y no los reproducía.

**Regla que queda**: al barrer configs, correr primero la línea de base conocida
y no creerle a ninguna variante hasta que ésa dé el número pineado. Y pasar
`--upgrades` siempre que el `economy.json` no esté en `Resources/Data`.

**2. La máquina.** Dos corridas de `xcodebuild` murieron clavadas en
`CopySwiftLibs` con el load promedio arriba de 900 por otro workload de la
máquina. No es del repo, pero cuesta una hora si no se mira: `uptime` antes de
culpar al build.

## Lo que el suite encontró, y que NO era un pin

**Cuatro tests dijeron lo mismo**, y cuando cuatro coinciden el que está mal no
es el test. Con el 3 % el segundo Fisura vale 25,75 y `CoinFormatter` truncaba a
`"25"`: la primera contratación no movía el precio en pantalla. Con el 1,06
anterior valía 26,5 y con el 1,2 valía 30, así que el salto siempre se había
visto **por casualidad del redondeo**.

Los cuatro:

- `BestHireTests.buyingMovesTheOffer` — pinaba "26".
- `JobRowsTests.hiringMovesItsOwnCurve` — pinaba "26".
- `BestHireTests.theProjectionOnlyPublishesOnChange` — la proyección no se
  republicaba, y **tenía razón en no hacerlo**: `BestHire` lleva sólo lo que se
  dibuja, y no se dibujaba nada distinto.
- `FisuJobsUITests.testContratarSubeElPrecioDeLaFilaYPoneLaUnidadEnElTablero` —
  punta a punta: "el precio de la fila tenía que subir después de contratar;
  quedó en 25 (era 25)".

### El arreglo: `CoinFormatter.cost`, que redondea los precios hacia ARRIBA

Un precio truncado miente **para el lado que rompe**: el botón decía 25 y cobraba
25,75, así que un jugador con 25 monedas exactas leía el precio, tocaba, y la
compra le rebotaba. Eso ya pasaba antes de esta ronda (26 contra 26,5) y nadie lo
había visto porque el redondeo lo tapaba casi siempre.

La asimetría con `string(from:)` es a propósito y ahora tiene las dos mitades
escritas: **el saldo trunca** para no anunciar plata que no se puede gastar
(`theLowBoundaryStillTruncates`, que ya existía) y **el precio sube** para no
anunciar una compra más barata de lo que se cobra. Sólo toca el tramo exacto
(< 1000): de ahí para arriba el número ya es una abreviatura y no promete el
valor exacto.

Cuatro call sites: los dos precios de contratación (`GameState+Hiring`) y los dos
de mejoras (`UpgradesView`). El resto de los usos de `CoinFormatter.string` son
saldos, ganancias y rendimientos, y ésos siguen truncando.

**Con eso los cuatro tests volvieron a verde sin tocar un solo assert de los
originales.** Ésa es la señal de que el arreglo estaba del lado del código.

## El susto del tutorial, y cómo se descartó

`TutorialUITests.testRecorreElTutorialEnteroHastaElFinal` se puso rojo justo
después del arreglo del formateador, y la correlación era buena: verde antes,
rojo después, rojo otra vez aislado. Fue **casualidad**, y lo que lo probó fue
correr el MISMO test con el mismo selector en las dos versiones:

| corrida | código | resultado |
|---|---|---|
| suite de UI | antes del formateador | verde |
| suite de UI | con el formateador | **rojo** |
| `TutorialUITests` solo | con el formateador | **rojo (6 de 9)** |
| ese test solo | formateador revertido | verde |
| ese test solo | formateador puesto | **verde** |

El último renglón rompe la historia causal, y el tercero la rompe por otro lado:
entre esa corrida y la anterior **no cambió una línea de código** y los rojos
pasaron de 1 a 6. Un cambio de lógica no falla MÁS tests cuando lo corrés solo.

⚠️ **La trampa de método**: el primer intento de aislarlo no valía nada. Revertí
las tres fuentes y dejé `CoinFormatterTests.swift`, que usa `CoinFormatter.cost`,
así que el "`** TEST FAILED **`" era un error de COMPILACIÓN disfrazado de
resultado. Al revertir para bisecar hay que revertir el test con su fuente.

## Estado

- `Packages/EconomyKit` **262/262** verde.
- `FisuEvolutionTests` en el sim 26.5 con los skips de Store de la matriz:
  **465 tests, 1 issue** — y ese uno es el declarado de siempre
  (`theOwnersTargetsAreMet` pide ≤8 reencarnaciones al maxear y mide 9). **Esta
  ronda no lo movió**: medía 9 antes también.
- `FisuEvolutionUITests`: **53 de 53, sin un rojo.**
- `StoreManagerTests` + `StoreProductsTests` en un sim **18.6** aparte, que es lo
  que manda la matriz de dos runtimes: `StoreProductsTests` verde y
  `StoreManagerTests` **9 de 10**, con `refundRevokesEntitlement` rojo en las DOS
  corridas. Es el breakage de máquina que el general ya describe por su firma
  (§7 y la entrada del 2026-08-27): el diff de esta sesión no toca un archivo de
  Store —lo único bajo `UI/Store/` es la pantalla de mejoras, y ahí cambian dos
  etiquetas de precio— y el rojo ya estaba en la corrida anterior a ese cambio.
  ⚠️ Correr esas suites en el 26.5 da **10 rojos de entorno** que no son del
  árbol: me pasó, y perdí una corrida entera en descartarlo.
- `pacing-sim` con el contenido embarcado:
  `Docs/balance-run-t12-cuesta-pre-compuerta.csv`.
