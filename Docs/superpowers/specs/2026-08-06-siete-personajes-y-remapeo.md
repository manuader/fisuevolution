# Los 7 personajes nuevos y el remapeo de la torre a 10 pisos

> Frente **F3** de la Ola 0 (`Docs/superpowers/plans/2026-08-06-ola-0-preparacion.md`, Task 5).
> Cierra **RF-10** de `Docs/superpowers/specs/2026-08-06-correcciones-de-playtest-design.md`
> y aporta el arte de **RF-05** (caras) y **RF-13** (dos skins pagas).
>
> **Este documento no toca ni un JSON.** Es la decisión de contenido. `tiers.json`,
> `economy.json`, `skins.json` y `products.json` se editan en la **Ola 2**, cuando el
> arte exista. Los nombres y el humor de los 7 los **aprueba el dueño** antes de que
> se genere una sola imagen.

## 1. El problema

El playtest dijo: *"en todos los pisos deben haber por lo menos 4 personajes (menos el
último que sólo contiene a Dios)"*. Hoy hay 30 tiers en 11 pisos, y **seis de los once
pisos tienen 2 personajes**. Se sube un piso, se ven dos caras, se sube otro.

## 2. La aritmética, cerrada contra el contenido real

| | Hoy | Nuevo |
|---|---|---|
| Tiers (rungs de la cadena de merge) | 30 | **37** |
| Tipos concretos (con sprite) | 36 | **43** |
| Pisos | 11 | **10** |
| Pisos con menos de 4 personajes | 7 | **0** (salvo el de Dios, que tiene 1 a propósito) |
| Fondos | 11 | **10** |

El reparto de los 7 personajes nuevos **no es una elección, sale forzado** de exigir
exactamente 4 por piso:

| Zona | Pisos | Tiers hoy | Necesita | Nuevos |
|---|---|---|---|---|
| Terrenal (alley, urban, corporate, luxury, island) | 5 | 17 | 20 | **+3** |
| moon | 1 | 4 | 4 | 0 |
| Cósmica (mars, solar, galaxy, cosmic) | 4 → **3** | 8 | 12 | **+4**, y **se retira un fondo** |
| god_realm | 1 | 1 | 1 | 0 |

Dentro de la zona terrenal el reparto también queda forzado: `corporate`, `luxury` e
`island` ya tienen 4, así que los 3 nuevos van **2 al callejón y 1 al piso urbano**.

### ⚠️ Una corrección a la aritmética del spec

RF-05 dice **44 caras** ("los 37 tipos concretos de hoy más los 7"). **Son 43.**
`tiers.json` tiene 37 tipos, pero uno —`junior` ("Recién Recibido")— es el **nodo de
elección de carrera**: `isChoiceNode: true`, no tiene sprite, nunca llega a existir como
unidad en el tablero y **no aparece en la pestaña Personajes**, que se construye con
`TierRepository.concreteTypes` (`GameState.characterUpgradeTypes`, que filtra los nodos de
elección). Generarle una cara sería arte que no se muestra en ningún lado.

Concretos hoy: **36**. Más los 7 nuevos: **43 caras**. El total de prompts de este frente
baja de 53 a **52** (7 personajes + 43 caras + 2 skins).

## 3. Decisión 1 — Los 7 personajes nuevos

El criterio: los 30 que ya existen van de *El Fisura* a *Dios* pasando por el mundo laboral
argentino y después por el espacio, y el chiste siempre es **la escala cósmica choca contra
la mezquindad argentina** (Dueño de la Luna planta una bandera con su propia cara, el
Emperador Cósmico le cobra peaje a la luz, Dios sigue tomando mate). Los 7 nuevos se
escribieron para sonar como escritos por la misma persona.

### Los 3 terrenales

| Tier | id | displayName | Piso | Se mergea en | Por qué es gracioso |
|---|---|---|---|---|---|
| 2 | `trapito` | **El Trapito** | alley | `limpiavidrios` | Te cobra por cuidarte el auto que estacionaste solo. Es el primer ingreso de la torre y no requiere absolutamente **ningún** capital: un trapo. Después de El Fisura, que no tiene nada, tener un trapo ya es una carrera. |
| 3 | `limpiavidrios` | **Limpiavidrios** | alley | `cartonero` | El del semáforo que empieza a lavarte el parabrisas antes de que puedas decir que no, con el verde a punto de salir. Escalón siguiente porque ya invirtió en herramientas: secador, botella y balde. |
| 5 | `mantero` | **El Mantero** | urban | `kiosco` | Vende sobre una manta con las cuatro puntas ya agarradas, mitad vendedor mitad velocista. Es el eslabón que faltaba entre juntar cartón (vender basura) y atender un kiosco (tener local): acá ya tiene **mercadería**, pero le entra toda en un bulto. |

La cadena del callejón queda: **nada → un trapo → un secador → un carro**. Y la del piso
urbano: **una manta → un kiosco → una moto → un auto**. Cada piso es una idea sola.

### Los 4 cósmicos

| Tier | id | displayName | Piso | Se mergea en | Por qué es gracioso |
|---|---|---|---|---|---|
| 27 | `rey_asteroides` | **Rey de los Asteroides** | solar | `magnate_solar` | Vende el cinturón de asteroides **por kilo**, con carro flotante y balanza: es el Cartonero del sistema solar, veinticinco tiers después. El único chiste del tramo cósmico que le contesta al piso 1, que es de lo que se trata la torre entera. Astronómicamente además está donde va: el cinturón está justo después de Marte. |
| 29 | `rentista_soles` | **Rentista de Soles** | galaxy | `estanciero_estelar` | Dejó de laburar hace tres fortunas y **vive de renta**: alquila soles por mes, en pantuflas y bata, con un llavero donde cada llave es una estrella. El sueño argentino máximo, a escala estelar. |
| 30 | `estanciero_estelar` | **Estanciero Estelar** | galaxy | `senor_galaxia` | La oligarquía terrateniente, pero la pampa es un campo de estrellas y las vacas flotan. Bombacha, rastra de monedas de plata, mate en el cinto y un alambrado de postes de luz que se pierde en el horizonte. |
| 32 | `coleccionista_galaxias` | **Coleccionista de Galaxias** | galaxy | `emperador_cosmico` | Tiene el álbum de galaxias completo **menos una**, y te cambia tres por esa. Está por encima del Señor de la Galaxia (que tiene una sola) y debajo del Emperador Cósmico, y a esta altura la plata ya no significa nada: son figuritas. |

**Placeholders** (`spritePlaceholder`, mientras no exista el arte) y `phase`, para la Ola 2:

| id | phase | spritePlaceholder |
|---|---|---|
| `trapito` | `earth` | `sf:hand.raised.fill` |
| `limpiavidrios` | `earth` | `sf:drop.fill` |
| `mantero` | `earth` | `sf:bag.fill` |
| `rey_asteroides` | `cosmic` | `sf:circle.hexagongrid.fill` |
| `rentista_soles` | `cosmic` | `sf:key.fill` |
| `estanciero_estelar` | `cosmic` | `sf:leaf.fill` |
| `coleccionista_galaxias` | `cosmic` | `sf:square.grid.3x3.fill` |

El corte `earth`/`cosmic` no se mueve: sigue cayendo entre el último del piso `moon` y el
primero del siguiente (hoy tiers 21/22, después del remapeo tiers **24/25**). Es el que
elige `music_earth_loop` vs `music_cosmic_loop` y el atlas (`earth.atlas` / `cosmic.atlas`).

## 4. Decisión 2 — Se retira `bg_mars`

De los cuatro fondos cósmicos (mars, solar, galaxy, cosmic), **el que se retira es `mars`**.
Tres razones, en orden de peso:

1. **Es el único que duplica visualmente a su vecino.** `bg_moon` ya es un suelo rocoso
   craterizado sin atmósfera con un cuerpo celeste grande en el cielo; `bg_mars` es la misma
   composición con otra paleta ("llanura de polvo rojo, dunas y mesetas, dos lunas chicas en
   un cielo rosa"). Se suben dos pisos y parece que no se movió nada.
2. **Su escala ya está contenida por la de al lado.** El arco cósmico es un zoom-out
   monótono: superficie de un cuerpo (moon) → sistema (solar) → galaxia (galaxy) → cosmos
   abstracto (cosmic) → cielo (god_realm). Marte es **un planeta adentro del sistema solar**,
   así que sacarlo no rompe la escalera; sacar `solar` o `galaxy` le haría un salto, y sacar
   `cosmic` dejaría a los cuatro tiers divinos (Emperador Cósmico, Ser Ascendido, Semidiós,
   Deidad) parados sobre un campo de estrellas literal en vez del reino abstracto que es
   justo lo que ese tramo necesita.
3. **La coherencia personaje↔fondo mejora en vez de empeorar.** Con `mars` retirado, el piso
   `solar` queda con **Dueño de la Luna, Dueño de Marte, Rey de los Asteroides y Magnate del
   Sistema Solar**: los cuatro dueños de cosas que están adentro del sistema solar, parados
   sobre la plataforma de órbitas. Hoy el Dueño de la Luna está parado sobre Marte, que ya
   era raro. Y el piso `cosmic` queda para los cuatro divinos, solos.

Cuesta ~7 MB del `.app` (los fondos se comen 81 MB de los que pesa hoy). El personaje
**Dueño de Marte no se toca**: sigue existiendo, sólo cambia de piso; Marte se le ve en el
cielo del fondo `solar`, que ya trae "planetas alineados sobre arcos de órbita".

El `.md` del prompt (`53_bg_mars.md`) y el PNG en `dropbox/procesadas/` **se dejan donde
están**: son historia del pipeline, no del juego. Lo que se saca en la Ola 2 es la entrada
`"mars"` de `assets_manifest.json` → `backgrounds` y los `Backgrounds/bg_mars@2x.png` /
`@3x.png` del bundle.

## 5. Decisión 3 — El mapeo final de 10 pisos

`incomeMultiplier` **interpolado, no inventado**: la tabla vieja va de 1,0 a 620,0 en 11
pisos (10 saltos, razón media 1,902); la nueva tiene que ir de 1,0 a 620,0 en 10 pisos
(9 saltos), o sea razón `620^(1/9) = 2,0431`. Los valores propuestos son esa progresión
geométrica redondeada al estilo de la tabla vieja: **ningún piso se desvía más de 2,4% del
valor ideal y todos los saltos caen entre ×2,00 y ×2,09** (la vieja iba entre ×1,80 y ×2,00).

| # | Piso | firstTier | lastTier | Personajes | `incomeMultiplier` | ideal | salto |
|---|---|---|---|---|---|---|---|
| 1 | `alley` | 1 | 4 | El Fisura · **El Trapito** · **Limpiavidrios** · Cartonero | **1,0** | 1,00 | — |
| 2 | `urban` | 5 | 8 | **El Mantero** · Personal de Kiosco · Repartidor · Chofer de App | **2,0** | 2,04 | ×2,00 |
| 3 | `corporate` | 9 | 12 | Empleado de Fast Food · Oficinista · Administrativo · *(elección de carrera)* | **4,2** | 4,17 | ×2,10 |
| 4 | `luxury` | 13 | 16 | *(Sr. de la carrera elegida)* · Director · Fundador de Startup · Dueño de PYME | **8,5** | 8,53 | ×2,02 |
| 5 | `island` | 17 | 20 | Emprendedor · CEO · Millonario · Multimillonario | **17,0** | 17,42 | ×2,00 |
| 6 | `moon` | 21 | 24 | Rey del Ladrillo · Magnate Petrolero · Space Billionaire · Trillonario | **35,0** | 35,59 | ×2,06 |
| 7 | `solar` | 25 | 28 | Dueño de la Luna · Dueño de Marte · **Rey de los Asteroides** · Magnate del Sistema Solar | **72,0** | 72,71 | ×2,06 |
| 8 | `galaxy` | 29 | 32 | **Rentista de Soles** · **Estanciero Estelar** · Señor de la Galaxia · **Coleccionista de Galaxias** | **150,0** | 148,55 | ×2,08 |
| 9 | `cosmic` | 33 | 36 | Emperador Cósmico · Ser Ascendido · Semidiós · Deidad | **305,0** | 303,48 | ×2,03 |
| 10 | `god_realm` | 37 | 37 | Dios | **620,0** | 620,00 | ×2,03 |

Verificado con el script del plan (Task 5, Step 3): `mapeo válido: 10 pisos` — cobertura
exacta 1…37, sin huecos ni solapes, y los 9 pisos no-Dios con exactamente 4 tiers.

El bloque `floors[]` de `economy.json` para la Ola 2, con los campos que **no** cambian
(`capacity`, `hireCostMultiplier` del callejón y los `backgroundOffset` de cada fondo, salvo
el de `mars` que se va con él):

```json
[
  { "id": "alley",     "background": "alley",     "firstTier":  1, "lastTier":  4, "capacity": 10, "incomeMultiplier":   1.0, "hireCostMultiplier": 50 },
  { "id": "urban",     "background": "urban",     "firstTier":  5, "lastTier":  8, "capacity": 10, "incomeMultiplier":   2.0, "backgroundOffset": 0.135 },
  { "id": "corporate", "background": "corporate", "firstTier":  9, "lastTier": 12, "capacity": 10, "incomeMultiplier":   4.2 },
  { "id": "luxury",    "background": "luxury",    "firstTier": 13, "lastTier": 16, "capacity": 10, "incomeMultiplier":   8.5 },
  { "id": "island",    "background": "island",    "firstTier": 17, "lastTier": 20, "capacity": 10, "incomeMultiplier":  17.0, "backgroundOffset": 0.18 },
  { "id": "moon",      "background": "moon",      "firstTier": 21, "lastTier": 24, "capacity": 10, "incomeMultiplier":  35.0, "backgroundOffset": 0.12 },
  { "id": "solar",     "background": "solar",     "firstTier": 25, "lastTier": 28, "capacity": 10, "incomeMultiplier":  72.0 },
  { "id": "galaxy",    "background": "galaxy",    "firstTier": 29, "lastTier": 32, "capacity": 10, "incomeMultiplier": 150.0 },
  { "id": "cosmic",    "background": "cosmic",    "firstTier": 33, "lastTier": 36, "capacity": 10, "incomeMultiplier": 305.0 },
  { "id": "god_realm", "background": "god_realm", "firstTier": 37, "lastTier": 37, "capacity": 10, "incomeMultiplier": 620.0 }
]
```

### Los `mergesInto` que cambian

Sólo estos siete; el resto de la cadena queda igual.

| id | `mergesInto` hoy | `mergesInto` nuevo |
|---|---|---|
| `homeless` | `cartonero` | **`trapito`** |
| `trapito` | — | **`limpiavidrios`** |
| `limpiavidrios` | — | **`cartonero`** |
| `cartonero` | `kiosco` | **`mantero`** |
| `mantero` | — | **`kiosco`** |
| `dueno_marte` | `magnate_solar` | **`rey_asteroides`** |
| `rey_asteroides` | — | **`magnate_solar`** |
| `magnate_solar` | `senor_galaxia` | **`rentista_soles`** |
| `rentista_soles` | — | **`estanciero_estelar`** |
| `estanciero_estelar` | — | **`senor_galaxia`** |
| `senor_galaxia` | `emperador_cosmico` | **`coleccionista_galaxias`** |
| `coleccionista_galaxias` | — | **`emperador_cosmico`** |

### La curva de la economía por tier

`tiers.json` es hoy una progresión geométrica exacta: cada tier vale **×2,8** el anterior en
`passiveYieldPerInstance`, `passiveUnlockCost` y `tapYield` (60 → 168 → 470,4…). Los 7 tiers
nuevos **no se calculan a mano**: se insertan en su posición y se vuelve a derivar la cadena
entera con el mismo generador (`Tools/generate-tiers/`) y la misma razón, que es lo que hace
que la curva no cambie de forma, sólo se alargue.

⚠️ Alargar la torre 7 tiers multiplica el techo por `2,8^7 ≈ 1.349×`. Eso **mueve el mismo
número que RF-07** (el exponente del ORO de 0,50 a ~0,40). Los dos se miden **en una sola
corrida de `pacing-sim` en la Ola 2**, no por separado: medidos aparte dan dos números que se
contradicen.

### Qué pasa con los saves viejos

Nada. `TowerReconciler` recalcula la ubicación de cada unidad contra el mapeo vigente en cada
carga — es exactamente el caso para el que se construyó. Un save con el mapeo de 11 pisos
carga y reacomoda solo. La aceptación de RF-10 ya lo pide como test.

## 6. Los 52 prompts de arte

Escritos en `Tools/asset-pipeline/prompts/gemini_pro/`, numerados **158–209**, todos en
`estado: pendiente`, listos para **una sola corrida** del runner.

| Rango | Qué | Cuántos | Referencia de estilo |
|---|---|---|---|
| 158–164 | Cuerpo entero de los 7 personajes nuevos | 7 | `heroes/approved/fisura.png` |
| 165–207 | Cara (`<id>_face`) de los 43 tipos concretos | 43 | el PNG del **propio personaje** en `dropbox/procesadas/` |
| 208–209 | Las 2 skins pagas (Fisura y Dios) | 2 | el PNG del propio personaje |

**El orden importa y por eso los cuerpos van primero.** Las caras de los 7 nuevos adjuntan
como referencia `dropbox/procesadas/<id>.png`, que no existe hasta que su cuerpo se generó y
se procesó. Hay que correr el batch **con `--process`** (integra por-asset ni bien cae en
dropbox), que es como se corrió el batch original.

Dos excepciones, porque no tienen PNG propio en `procesadas/`: la cara de **`homeless`**
adjunta `heroes/approved/fisura.png` (que *es* el Fisura aprobado) y la de
**`junior_programmer`** también, porque su original nunca quedó archivado — su prompt
describe el personaje entero para compensar.

⚠️ **Bajar `--ref-threshold` a ~5 para las caras y las skins.** El runner descarta la imagen
generada si su huella de píxeles se parece demasiado a la referencia adjunta, con un umbral
de 12 calibrado para cuando la referencia era *otro* personaje. Acá la referencia es **el
mismo personaje**, así que el umbral de fábrica puede tirar imágenes buenas. Es la misma
precaución que documenta el propio runner (`gemini_selenium_runner.py`, `--ref-threshold`).

### Las 2 skins: son outfits, no tintes

Las tres skins pagas anteriores (`golden`, `galaxy`, `god`) se retiraron **porque eran tintes
globales**: el mismo dibujo con otro color. Estas dos cambian **la ropa y los props**, y el
prompt lo exige de forma explícita ("Change ONLY the clothing, the props and the palette",
manteniendo pose y silueta, que es lo que hace que se lea como el mismo personaje).

| Personaje | skin id | displayName | El outfit | Producto IAP sugerido |
|---|---|---|---|---|
| `homeless` | `mundialista` | **Mundialista** | Los abrigos rotos se los tapa una camiseta a rayas celestes y blancas (genérica: sin escudo, sin número, sin ninguna marca real), gorro bucket en vez del gorrito de lana, dos rayas de pintura en cada cachete, una corneta al cuello, y la botella verde reemplazada por una copa abollada que claramente no ganó él. | `com.fisuevolution.iap.skin_mundialista` |
| `god` | `parrillero` | **Parrillero** | La túnica de estrellas queda tapada por un delantal de parrillero chamuscado, la barba de nubes metida adentro del delantal para que no se prenda fuego, el universo de la palma es ahora una brasa que está soplando, y en la otra mano una pinza de asado gigante en vez del mate (que le cuelga del delantal, porque el mate no se negocia). | `com.fisuevolution.iap.skin_parrillero` |

Las dos entran a `skins.json` con `treatment: "texture"` y `textureKey`
`homeless_idle__mundialista` / `god_idle__parrillero`, igual que las 36 ganables. **La venta**
queda detrás del gate de la cuenta de Apple; el arte no.

## 7. Lo que hace la Ola 2 con este documento

1. `tiers.json`: regenerar con los 7 tipos nuevos insertados y los 12 `mergesInto` de §5.
2. `economy.json`: reemplazar `floors[]` por el bloque de §5.
3. `assets_manifest.json`: sacar `backgrounds["mars"]`; agregar los 7 personajes, las 43
   caras (`<id>_face`) y las 2 skins cuando el arte esté integrado.
4. `skins.json` + `products.json`: las 2 skins pagas de §6.
5. Borrar `Backgrounds/bg_mars@2x.png` y `@3x.png` del bundle (~7 MB).
6. `Localizable.xcstrings`: los 7 `displayName`, los 2 nombres de skin.
7. Correr `pacing-sim` **una sola vez** con RF-07 aplicado, y anotar la tabla en
   `Docs/balance-log.md`.
