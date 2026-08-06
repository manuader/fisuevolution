# Requisitos funcionales — correcciones del playtest completo

> Fecha: 2026-08-06. Origen: un jugador externo terminó el juego de punta a punta
> y mandó 16 correcciones. Este documento las convierte en requisitos con
> criterio de aceptación, y define en qué orden y con cuánto paralelismo se hacen.
>
> Contexto previo obligatorio: `Docs/HANDOFF.md` (estado y arquitectura),
> `Docs/balance-log.md` (toda decisión de números con su costo medido).

---

## 1. Alcance

**Entra**: los 16 pedidos del playtest, listados en §3 como RF-01…RF-16.

**No entra** — ninguno de los 16 los menciona y se mantienen como están:

- El gate de contratación de **un** piso (decisión 3 del HANDOFF: con dos, el
  juego no se puede terminar; está medido).
- El multiplicador de contratación 600× arriba / 50× en el callejón (decisión 2).
- El primer Fisura a 50 (decisión 1).
- La arquitectura de tres capas y la regla de que SwiftUI nunca lee `PlayerState`.

**Se difiere por gate humano**: el alta de productos en App Store Connect
(RF-02 y RF-13 sólo en su parte comercial). Ver §6.

---

## 2. Cómo leer los requisitos

Cada uno trae:

- **Pedido**: lo que escribió el jugador, textual.
- **Hoy**: qué hace el juego ahora, verificado contra el código.
- **Requisito**: qué tiene que hacer.
- **Aceptación**: cómo se comprueba que está hecho.

---

## 3. Los requisitos

### RF-01 · Tutorial interactivo

**Pedido**: "Tutorial re villero, se ve muy mal (debería verse estilo clash
royale/clash of clans)".

**Hoy**: `TutorialOverlay.swift` es un scrim negro al 72% + una pose del Fisura
abajo a la izquierda + un globo de diálogo. Se toca **en cualquier lado** para
avanzar los 7 pasos. No señala ningún control real y no exige ninguna acción.

**Requisito**: rehacerlo con el patrón de Clash of Clans, en dos dimensiones:

1. **Interacción**: cada paso ilumina un recorte sobre el **control real** del
   juego (el botón de contratar, un personaje del tablero, el ícono de mejoras,
   el del mapa, el del carrito), con una mano animada que late sobre él. El resto
   de la pantalla queda oscurecido y **no responde al toque**. El paso avanza
   sólo cuando el jugador ejecuta esa acción, no al tocar en cualquier lado.
2. **Presentación**: globo de diálogo, tipografía y transiciones rehechos al
   nivel del resto del juego.

Se conserva el botón de saltear y el estado "ya lo vi" en `AppStorage`.

**Aceptación**: un test de UI recorre el tutorial ejecutando las acciones que
pide y llega al final; tocar fuera del recorte iluminado no avanza el paso. Con
Reduce Motion, la mano no late y las transiciones colapsan.

---

### RF-02 · La tienda tiene qué vender

**Pedido**: "el icono del carrito tiene que tener compras con plata (no tiene
ninguna)".

**Hoy**: `products.json` declara 4 productos, pero 3 son las skins de tinte que
se retiraron en la sesión del 2026-08-05 — o sea que sólo queda `remove_ads`.
Además `StoreView` **no dibuja la sección** si `store.products` viene vacío, con
lo cual una carga fallida de StoreKit se ve idéntica a una tienda sin productos.

**Requisito**, en tres partes:

1. **Diagnóstico primero** (RF-02a). Verificar en simulador si en el build que se
   jugó la tienda se veía vacía por una carga fallida de StoreKit. Si es eso,
   arreglar el estado vacío: cuando no hay productos, la tienda debe **decirlo**
   ("no se pudieron cargar las compras") en vez de mostrar un hueco.
2. **Catálogo** (RF-02b): la tienda vende packs de monedas de la run, un starter
   pack (monedas + quitar ads + una skin), y packs de ORO. Todo construido y
   testeado contra `StoreKitConfig/FisuEvolution.storekit`, que ya está cableado
   al esquema y a `SKTestSession`.
3. **Alta comercial** (RF-02c): dar de alta los productos en App Store Connect.
   **Bloqueado por la cuenta de Apple Developer** — ver §6.

Los **montos** de los packs de ORO se fijan después de RF-07, porque el rebalance
cambia cuánto vale un ORO.

**Aceptación**: con el `.storekit` local, la tienda muestra todos los productos,
se compran, y el efecto se acredita. Con StoreKit caído, muestra el mensaje de
error en vez de una lista vacía. Test de `SKTestSession` por producto.

---

### RF-03 · La lista de mejoras muestra todos los personajes desbloqueados

**Pedido**: "que aparezcan todas las personas para mejorar (x2,x3,x4,etc)".

**Hoy**: `GameState.characterUpgradeTypes` filtra por
`units[id] > 0 || charUpgradeLevels[id] > 0`. Si vendés o mergeás tu último
Fisura, **el Fisura desaparece de la lista de mejoras**, aunque su mejora te
siga rindiendo.

**Requisito**: la lista muestra todos los personajes **desbloqueados en la run
actual** — todo el que alguna vez tuviste en esta partida —, tengas o no una
copia viva ahora. El que nunca desbloqueaste no aparece (no se espoilean las
evoluciones). Requiere un campo nuevo en `run`: el conjunto de tipos vistos.

**Aceptación**: test que crea un Fisura, lo mergea hasta que no queda ninguno, y
verifica que el Fisura sigue en la lista. Reencarnar vacía la lista salvo el tipo
base.

---

### RF-04 · Ingreso pasivo desde el menú, con dos botones por fila

**Pedido**: "que se pueda comprar el pasive income desde el menu (en lugar de
manteniendo apretando al personaje)".

**Hoy**: el pasivo se compra **sólo** manteniendo apretado el personaje en el
tablero (`BoardScene`, acción `longPress`). En el menú no hay forma de comprarlo,
y la fila de personaje tiene un único botón.

**Requisito**:

1. Cada fila de la pestaña **Personajes** tiene **dos botones**: uno compra el
   ingreso pasivo (o muestra un tilde si ya está comprado) y otro sube el
   multiplicador. Cada botón lleva su costo y **dice exactamente qué hace**, con
   el número concreto de ese personaje: "plata ×5 al Fisura", no "nivel 3".
2. El long-press sobre un personaje del tablero **deja de comprar el pasivo** y
   pasa a servir únicamente para **cambiar la skin** de ese personaje.

**Aceptación**: test de UI que compra el pasivo desde el menú y verifica que el
income pasivo del tipo subió. Test que mantiene apretado un personaje y verifica
que **no** se descuenta plata y que se abre el selector de skin.

---

### RF-05 · Carita de cada personaje en el círculo

**Pedido**: "que en el circulito de la sección de mejoras aparezca la cara de
cada personaje (…) que genere un crop solo de la cara. imagen graciosa que
identifique al personaje croppeando su cara [capaz con alguna sonrisa o gesto]".

**Hoy**: el círculo es amarillo con el texto "T7" adentro.

**Requisito**: cada personaje tiene un asset de cara nuevo, **generado con el
pipeline de Gemini** (no un recorte mecánico del sprite): primer plano, expresión
graciosa característica del personaje. Entra al `assets_manifest.json` con la
clave `<id>_face`; sin entrada, la fila cae al círculo "T7" actual — o sea que la
UI **no espera al arte** para poder construirse.

Son **44 caras**: los 37 tipos concretos de hoy más los 7 que agrega RF-10.

**Aceptación**: la fila muestra la cara cuando la clave existe en el manifest, y
el círculo "T7" cuando no. Un test del manifest verifica que hay una cara por
tipo concreto una vez integrado el arte.

---

### RF-06 · Descripciones que dicen qué hace cada cosa

**Pedido**: "mejoras permanentes, descripciones claras y concisas. (muchas veces
las mejoras y los boosts no dicen que hacen)".

**Hoy**: las 7 mejoras permanentes muestran título + "nivel 3/20". Los 6 boosts
muestran nombre + duración. Ninguno dice qué efecto tiene ni cuánto.

**Requisito**: cada fila de mejora permanente, de mejora de personaje y de boost
lleva **dos líneas**:

1. El **efecto numérico**, calculado a partir del JSON de configuración: lo que
   tenés ahora y lo que vas a tener si comprás ("ahora +30% → con este nivel
   +40%"). Al salir del config, no se puede desincronizar de un cambio de balance.
2. Un **texto de color corto** con el humor del juego.

La traducción de `effectType` + magnitud + nivel a texto vive en **una sola
pieza** en EconomyKit (`EffectDescriptor`), consumida por las mejoras, los boosts
y el prestigio. Los `effectType` a cubrir son los 7 de `upgrades.json`
(`incomeMultiplier`, `spawnCostDiscount`, `offlineEfficiency`, `tapMultiplier`,
`critChance`, `goldenTouchChance`, `prestigeBonusPerSoulPoint`) y los 5 de
`boosts.json` (`spawnCostMultiplier`, `tapMultiplier`, `incomeMultiplier`,
`offlineEfficiencyPermanent`, `periodicChest`).

**Aceptación**: test unitario de `EffectDescriptor` con un caso por `effectType`,
incluyendo el nivel máximo y el nivel 0. Ninguna fila de las tres pantallas
queda sin línea de efecto.

---

### RF-07 · El ORO de reencarnar, más difícil

**Pedido**: "que no sea tan exponencial el oro que ganas al reencarnar (que sea
mas dificil de obtenerlo)".

**Hoy**: `ORO = (lifetimeEarnings / 3.000.000) ^ 0,5`. La fórmula ya es
sublineal — es una raíz cuadrada —; lo que crece exponencial son las ganancias
que entran a la fórmula. Cada ORO vale +12% de multiplicador global
(`globalMultiplierPerOro: 0.12`).

**Requisito**: bajar el exponente de **0,5 a ~0,40**, calibrado con `pacing-sim`.
Aplasta la curva entera: las primeras reencarnaciones quedan casi iguales y las
tardías rinden mucho menos, que es exactamente la queja.

Este cambio se mide **junto con RF-10** en una sola corrida (§5), porque los dos
mueven la misma curva y medirlos por separado da dos números que se contradicen.

**Aceptación**: `pacing-sim` corrido sobre la torre final, con la tabla de ORO
por reencarnación en `Docs/balance-log.md` junto al valor viejo. `PacingTests`
repineado a la conducta nueva.

---

### RF-08 · Mapa de pisos

**Pedido**: "poder tener un mapita para poder navegar por todos los pisos y que
no sea solo subir y bajar (…) los bloqueados en gris. al darle click podes ir
directamente del piso 1 al 10 (con una transicion en donde sube rapido)".

**Hoy**: sólo se navega de a un piso, con las flechas de la pill del HUD o con un
swipe vertical. No hay ninguna vista de la torre completa.

**Requisito**: un panel **ascensor vertical** — los pisos apilados como un
edificio, Dios arriba y el callejón abajo — donde cada piso muestra:

- una miniatura de su fondo real,
- su nombre,
- su ocupación (por ejemplo 4/10),
- y en **gris, sin poder tocarse**, los que todavía no desbloqueaste.

Al tocar un piso desbloqueado, la cámara **vuela pasando por los pisos
intermedios** hasta frenar en el destino (≈0,6–0,9 s), cargando y descargando el
rango visible sin tirones. Con Reduce Motion activado, corta directo.

**Aceptación**: test de UI que abre el mapa desde el piso 1, toca el piso más
alto desbloqueado y verifica que el piso visible es ése. Los bloqueados no
responden al toque. La vista es data-driven: sale de `floors[]`, así que sigue
funcionando cuando RF-10 pase la torre de 11 a 10 pisos.

---

### RF-09 · Invertir el sentido del deslizamiento

**Pedido**: "el scroll (bajar de piso scrolleando) esta al reves. scrollear para
abajo te lleva para arriba y viceversa. deberia ser alreves".

**Hoy**: en `BoardScene.touchesEnded`, un swipe con `deltaY > 0` (dedo hacia
arriba) sube un piso. Es la metáfora "deslizá hacia donde querés ir".

**Requisito**: invertir el signo, adoptando la metáfora de **agarrar la torre y
moverla**, que es la de cualquier lista de iOS: arrastrás el dedo hacia **abajo**
y **subís** un piso. Los umbrales actuales (48 pt de recorrido, y que el
movimiento vertical supere 1,5× al horizontal) no cambian.

**Aceptación**: test que simula el gesto en cada dirección y asserta el piso
resultante. El test es el que impide que se vuelva a invertir sin querer.

---

### RF-10 · Mínimo 4 personajes por piso

**Pedido**: "en todos los pisos deben haber por lo menos 4 personajes (menos el
ultimo que solo contiene a dios). esto significa que va a haber que generar mas
personajes entre los 30 actuales".

**Hoy**: 30 tiers distintos (37 tipos: la bifurcación de carrera agrega tipos
paralelos en los tiers 9 y 10) repartidos en 11 pisos. Sólo 4 pisos llegan a 4
tiers; seis tienen 2 y uno tiene 3.

| Piso | Tiers hoy | Cantidad |
|---|---|---|
| alley | 1–2 | 2 |
| urban | 3–5 | 3 |
| corporate | 6–9 | 4 |
| luxury | 10–13 | 4 |
| island | 14–17 | 4 |
| moon | 18–21 | 4 |
| mars | 22–23 | 2 |
| solar | 24–25 | 2 |
| galaxy | 26–27 | 2 |
| cosmic | 28–29 | 2 |
| god_realm | 30 | 1 |

**Requisito**: **7 tiers nuevos**, para llegar a 36 tiers no-Dios = **9 pisos de
exactamente 4** + el piso de Dios = **10 pisos**. Se retira **un** fondo, de la
zona cósmica.

El reparto de los 7 sale de la aritmética:

- Zona terrenal (alley, urban, corporate, luxury, island): 17 tiers en 5 pisos →
  necesita 20 → **+3 personajes**.
- moon: ya tiene 4, no se toca.
- Zona cósmica (mars, solar, galaxy, cosmic): 8 tiers en 4 pisos → 12 tiers en 3
  pisos → **+4 personajes y se retira 1 fondo**.

Qué fondo se retira y en qué tier entra cada personaje nuevo lo decide la tarea
A1 (§5), junto con los nombres y el humor de los 7 — que aprueba el dueño antes
de que se genere una sola imagen.

Los saves viejos **no se rompen**: `TowerReconciler` recalcula la ubicación
contra el mapeo vigente en cada carga, que es exactamente el caso para el que se
construyó.

**Aceptación**: `FloorTable` valida cobertura exacta 1…37 sin solapes; ningún
piso no-Dios tiene menos de 4 tiers; `ExtensibilityDrillTests` sigue verde; una
partida guardada con el mapeo viejo carga y reacomoda sus unidades.

---

### RF-11 · Un video cada 4 horas

**Pedido**: "solo poder ver un video cada 4 horas".

**Hoy**: las 4 recompensas por video (`rewarded_ads.json`) están siempre
disponibles y sin ningún cooldown: se pueden mirar los 4 videos seguidos, y otra
vez enseguida.

**Requisito**: cada recompensa tiene su **propio cooldown de 4 horas** (los 4
corren en paralelo). La fila muestra la cuenta regresiva en lugar del botón
mientras está en cooldown, con el mismo formato que ya usan los boosts. El
cooldown sobrevive a cerrar la app.

**Aceptación**: test con reloj inyectado que mira una recompensa, verifica que
queda bloqueada, avanza 4 h y verifica que vuelve. Cerrar y abrir la app no la
resetea.

---

### RF-12 · Boosts que se desbloquean por piso

**Pedido**: "los boosts tienen que tener las descripciones de cada uno, y que se
vayan desbloqueando a medida que vas avanzando en el juego".

**Hoy**: los 6 boosts están visibles y usables desde el primer minuto de la
primera partida.

**Requisito**: cada boost se desbloquea al **alcanzar cierto piso**. Los que
todavía no están se ven en gris, con el requisito escrito ("se desbloquea en la
oficina"). El mapeo boost → piso vive en `boosts.json`, no en código. La parte de
descripciones es RF-06.

Los 6 boosts se reparten a lo largo de los 9 pisos desbloqueables, de modo que
el jugador reciba uno nuevo cada dos o tres pisos en vez de todos juntos.

**Aceptación**: test que verifica que en una partida nueva sólo está disponible
el primer boost, y que cada uno aparece al desbloquear su piso. El mapeo se puede
cambiar tocando sólo el JSON.

---

### RF-13 · Skins exclusivas en la tienda

**Pedido**: "agregar algunas skins a la tienda (generar skins exclusivas para 2
personajes [fisura, dios])".

**Hoy**: hay 36 skins con arte hecho y verificado, todas ganables. Las 3 skins
pagas que existían eran **tintes globales** y se retiraron en la sesión anterior;
la tienda quedó vendiendo sólo `remove_ads`.

**Requisito**: dos skins nuevas —una del Fisura y una de Dios— con **arte propio
generado**, no un tinte de color: outfit distinto, reconocible. Se venden como
productos IAP.

Esto **cambia la decisión 4 del HANDOFF** ("los tintes IAP se retiraron"), con
una diferencia sustantiva: aquellas se cayeron justamente por ser tintes sin
cambio real, y estas son arte nuevo. Queda registrado como cambio de decisión, no
como olvido.

El **arte** de las dos skins no depende de la cuenta de Apple y sale en la misma
corrida de Gemini que RF-05 y RF-10. Sólo la **venta** queda detrás del gate.

**Aceptación**: las dos skins existen en `skins.json` y en el manifest, se pueden
equipar desde la ficha de personaje, y se compran contra el `.storekit` local.

---

### RF-14 · Música nueva y efectos de sonido

**Pedido**: "cambiar la musiquita y agregar aun mas efectos de sonido".

**Hoy**: dos loops de música (`music_earth_loop.caf`, `music_cosmic_loop.caf`) y
efectos **sintetizados por código** (`Tools/audio-synth`).

**Requisito**:

1. Reemplazar los **dos loops** por dos temas nuevos, en el mismo lugar y con la
   misma lógica de cuándo suena cada uno (no se agregan zonas musicales).
2. Efectos de sonido propios —ya no sintetizados— para: merge, evolución,
   contratar, comprar mejora, piso nuevo desbloqueado, moneda, acción inválida y
   las celebraciones.

**Fuente del audio**: se generan con ElevenLabs, que está conectado a la sesión.
Los volúmenes siguen respetando los sliders de música y efectos que ya existen en
Ajustes.

**Aceptación**: cada evento de la lista dispara un archivo distinto; con el
slider de efectos en 0 no suena ninguno; la precarga sigue ocurriendo fuera del
hilo principal, como quedó tras el arreglo de hitch de la sesión pasada.

---

### RF-15 · Elegir carrera da una recompensa distinta

**Pedido**: "que elegir la carrera en 'corporativo' defina algo. o que tengan
distintas recompensas elegir una carrera u otra".

**Hoy**: en el tier 9 el juego pregunta la carrera (`CareerChoiceView`) entre
**cuatro** opciones —Programador, Arquitecto, Médico y Abogado—, cada una con su
versión Sr. en el tier 10. Las cuatro ramas se reabsorben en el Director del tier
11, así que el jugador termina exactamente igual sin importar qué eligió: la
elección no define nada.

**Requisito**: cada una de las cuatro carreras entrega una **recompensa distinta
de una sola vez** al elegirla, y de **tipo distinto** entre sí, para que la
decisión se lea como una decisión y no como cuatro variantes del mismo premio.
Los cuatro tipos, todos aplicables con efectos que la economía ya sabe ejecutar:

- un **cofre de plata** proporcional al income del momento,
- un **boost gratis** que se activa sin consumir su cooldown,
- una **skin** desbloqueada,
- un **modificador temporal** (por ejemplo, contratar más barato un rato).

Qué tipo le toca a cada carrera se declara en configuración, no en código, y lo
firma el dueño durante el frente D. La pantalla de elección **muestra la
recompensa de cada opción antes de elegir**, para que la decisión sea informada.

**Aceptación**: un test por carrera verifica que se acredita su recompensa y que
las cuatro son de tipo distinto. La pantalla muestra las cuatro recompensas antes
de tocar. Cambiar qué recompensa da cada carrera se hace tocando sólo el JSON.

---

### RF-16 · Cuánto multiplicador te da reencarnar

**Pedido**: "que al reencarnar te diga que tanto potenciador te da".

**Hoy**: `PrestigeView` dice cuánto **ORO** vas a ganar, pero no que cada ORO
vale +12% de multiplicador global. El jugador ve un número chico ("ganás 14") y
no tiene forma de saber qué compra.

**Requisito**:

1. En el popup de reencarnación, el **antes y el después** del multiplicador
   global: "ganás 14 ORO → tu multiplicador pasa de ×2,3 a ×3,9".
2. Un **indicador permanente en el HUD** que muestre cuánto daría reencarnar
   ahora, y que crezca mientras jugás.

**Aceptación**: el número del popup coincide con el multiplicador real después de
confirmar (test). El indicador del HUD se actualiza al ritmo de las proyecciones,
sin observar `PlayerState`.

---

## 4. Hallazgos de arquitectura que condicionan el reparto

Estos son los que determinan qué se puede hacer en paralelo. Verificados contra
el código, no supuestos.

1. **`GameState.swift` son 1.493 líneas y lo tocan cinco de los siete frentes.**
   Ya está seccionado por dominio con 16 `// MARK:`, así que partirlo en
   extensiones es mecánico y de bajo riesgo. Sin ese corte, cinco agentes editan
   el mismo archivo y el paralelismo es ficticio.

2. **Las propiedades observadas no pueden vivir en extensiones.** Swift no
   permite propiedades almacenadas ahí, así que el bloque de proyecciones sigue
   siendo compartido aunque se parta el archivo. Mitigación: cada frente agrega
   **una sola propiedad**, de tipo struct, y el struct vive en su propio archivo.
   El choque baja de "muchas líneas dispersas" a "una línea en un lugar conocido".

3. **En `BoardScene.swift`, RF-09 y la mitad de RF-04 están en el mismo método.**
   Repartirlos en dos frentes cuesta más que hacerlos juntos: los dos van al
   trabajo de preparación.

4. **`project.yml` toma el directorio con glob.** Agregar archivos Swift no toca
   `project.yml`; sólo hace falta `xcodegen generate` en local. Cero conflictos
   de build entre frentes.

5. **El catálogo de strings está ordenado alfabéticamente por clave** (221 hoy).
   Si cada frente usa su prefijo (`map.*`, `upgrades.*`, `bonus.*`, `prestige.*`,
   `tutorial.*`, `store.*`), las inserciones caen en zonas distintas del JSON y
   git las mergea solo. Sigue vigente la regla del HANDOFF: **no editarlo con
   scripts**, y commitear aparte el reformateo que hace Xcode en el primer build.

6. **El runner de Gemini no corre desde el shell del agente** (trampa 6 del
   HANDOFF: `osascript`/System Events no funciona ahí). La corrida de arte es un
   gate humano que se larga desde Terminal.app, pero **no bloquea a nadie**
   mientras corre.

7. **`HUDView.swift` (130 líneas) lo tocan dos frentes** — el botón del mapa y el
   indicador de prestigio. Son dos inserciones de unas cinco líneas en zonas
   distintas. Se acepta el conflicto en vez de inventar andamios.

---

## 5. Plan de ejecución en olas

### Ola 0 — dos frentes en simultáneo

| Frente | Qué hace | Toca |
|---|---|---|
| **P · Preparación** | Parte `GameState` en extensiones por dominio; crea `EffectDescriptor` en EconomyKit; **RF-09** (invertir el scroll); **RF-04a** (long-press → sólo skins); **RF-02a** (diagnóstico de la tienda vacía). | Swift |
| **A1 · Contenido** | Define los 7 personajes de RF-10, el remapeo 11→10 pisos y qué fondo se retira; escribe los **53 prompts** de Gemini (7 personajes + 44 caras + 2 skins). | JSON y prompts |

No chocan: P es sólo Swift, A1 es sólo datos. **P no cambia ninguna conducta**
salvo esos dos arreglos, y los 144 tests actuales de EconomyKit más los 90 de la
app son la red que lo prueba.

**Gate**: los nombres y el humor de los 7 personajes los aprueba el dueño antes
de generar una sola imagen.

### Ola 1 — seis frentes en simultáneo

| Frente | Requisitos | Archivos propios |
|---|---|---|
| **B · Menú de mejoras** | RF-03, RF-04b, RF-06 (mejoras) | `GameState+Upgrades`, `UpgradesView` |
| **C · Mapa de pisos** | RF-08 | `GameState+Tower`, `BoardScene`, `FloorMapView` |
| **D · Bonus y carrera** | RF-11, RF-12, RF-06 (boosts), RF-15 | `GameState+Bonus`, `BonusView`, `CareerChoiceView`, `boosts.json`, `rewarded_ads.json` |
| **E · Audio** | RF-14 | `AudioManager`, `Resources/Audio` |
| **F · Prestigio** | RF-16 | `GameState+Prestige`, `PrestigeView` |
| **G1a · Tienda local** | RF-02b | `GameState+Store`, `StoreView`, `.storekit`, `products.json` |
| **A2 · Arte** | RF-05, RF-10, RF-13 (una sola corrida) | ninguno — gate humano |

**Por qué una sola corrida de arte**: el runner de selenium maneja un único
Chrome con un checkpoint compartido; dos corridas simultáneas se pisan.

Si no se pueden largar seis a la vez, la prioridad es **B → C → D → F → G1a → E**.
B primero porque concentra 4 de los 16 pedidos y es la pantalla donde más se
quejó el jugador.

### Ola 2 — dos frentes en simultáneo

| Frente | Qué hace |
|---|---|
| **A3 · Integrar el arte** | Atlas, `assets_manifest.json`, `tiers.json`, `floors[]` de 11 a 10 pisos. |
| **H · Tutorial** | RF-01. Va acá y no antes porque ilumina controles reales, y esos controles los acaban de cambiar B y C. Hacerlo en la Ola 1 es hacerlo dos veces. |

### Ola 3 — dos frentes en simultáneo

| Frente | Qué hace |
|---|---|
| **A4 · Rebalance conjunto** | RF-07 + RF-10 en **una sola** corrida de `pacing-sim`, una entrada en `balance-log`, `PacingTests` repineado. Va solo y al final porque es lo único que necesita el juego entero armado para poder medir. |
| **G1b · Vender las skins** | RF-13, contra el `.storekit` local. El arte ya salió en A3. |

### Ola 4 — lo único bloqueado por la cuenta de Apple

**G2**: alta de los productos en App Store Connect, precios, revisión (RF-02c).
Nada más. Todo lo demás queda terminado y verificable en el simulador antes de
gastar los USD 99.

---

## 6. Gates humanos

| Gate | Qué bloquea | Quién |
|---|---|---|
| Aprobar los 7 personajes nuevos | La corrida de arte (A2) | Dueño |
| Correr el runner de Gemini desde Terminal.app | RF-05, RF-10, RF-13 | Dueño |
| Cuenta de Apple Developer (USD 99) + App Store Connect | **Sólo** RF-02c | Dueño |

---

## 7. Riesgos

1. **RF-10 rompe `PacingTests`**, que está pineado a la conducta actual de 30
   tiers (decisión 5 del HANDOFF). Es esperable y se repinea en A4, pero durante
   las olas 2 y 3 ese test deja de ser una red de seguridad.
2. **RF-07 y RF-10 juntos mueven mucho el pacing.** El antecedente está medido:
   subir `hire.defaultCostMultiplier` de 300 a 600 **acortó** el juego de 264 h a
   196 h, al revés de lo esperado. Ningún número de esta tanda se da por bueno
   sin correr el simulador.
3. **RF-13 reabre la decisión 4 del HANDOFF.** Documentado en §3 con su
   justificación; si el arte de las dos skins vuelve a salir sin diferencia real
   contra la base, el pedido no está cumplido —ya pasó con `home_office`, que
   hubo que regenerar.
4. **El peso del `.app` sube** con 7 personajes y ~43 caras nuevas, y baja con el
   fondo retirado. Hoy está en 115 MB en Release, con los fondos pesando ~81 MB.
   Se mide después de A3 con `build/DD` borrado, porque el build incremental no
   recompila los atlas.
5. **RF-01 depende de superficies que cambian.** Si el tutorial se empieza antes
   de que B y C terminen, se reescribe.
