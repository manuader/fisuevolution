# LAYA en vez de Jev: análisis conceptual

_Escrito el 2026-09-27. Continuación de `evaluacion-jev.md`._
_Fuente: `github.com/NandhaKishorM/laya` + `huggingface.co/convaiinnovations/laya`, leídos hoy._

**La tesis en tres líneas.** Correrlo local no hace que LAYA sirva para lo que
Jev no servía: el gameplay sigue siendo números y un encoder sobre texto sigue
siendo la herramienta equivocada para números. Lo que local sí destraba es otra
cosa, más grande y que no estaba en el doc anterior: **este juego tiene un grafo
semántico dormido de ~8.000 relaciones entre sus personajes, eventos, pisos y
pintas, y hoy ninguna está materializada.** Ahí es donde hay juego nuevo. Y la
mejor forma de materializarlo probablemente **no sea corriendo LAYA en el
iPhone, sino corriéndolo en tu Mac y congelando la salida en JSON.**

---

## 1. Qué es LAYA, verificado

Mismo contrato que Jev —Choice / Score / Noul, decisión tipada con probabilidad
calibrada en un forward pass— pero como **pesos abiertos, Apache 2.0**, que
corren donde vos quieras.

| | Jev (TypeSafe) | LAYA |
|---|---|---|
| Dónde corre | SaaS, `POST /v1/systemone` | tu máquina. CPU, CUDA, **MPS (Apple Silicon)**, XPU |
| Modelo | propietario, `jev-1.13.0` | `laya` (ModernBERT-large, 421M), `laya-multilingual` (mmBERT-base, 322M), `laya-typed-decisions` (421M) |
| Licencia | comercial | **Apache 2.0** |
| Idiomas | inglés primario | **100+**, checkpoint multilingüe dedicado + router que elige por detección de script en <1 ms |
| Latencia publicada | ninguna en la doc | **~33 ms** (Tesla T4), 103–332 preguntas/s en batch |
| Fine-tuning | no | **sí**, receta RLCD sobre 2×T4 gratis de Kaggle |
| Costo marginal | USD 0,042 / M tokens | **cero** |
| API | propia | **compatible con la de Jev** (`POST /v1/systemone`) |

Ese último punto es más importante de lo que parece: la capa de abstracción
`Judge` que propuse en el doc de Jev **ya no es una mitigación teórica**. Los dos
hablan el mismo protocolo. Podés probar los dos con la misma implementación.

### Las tres alertas, antes de entusiasmarse

**(a) Zero-shot, en un dominio especializado, está cerca del azar.** Es el dato
más importante del model card y está escrito por los propios autores: el
checkpoint base saca **0,362 de accuracy en el benchmark typed-decisions, contra
0,461 de la baseline de clase mayoritaria**. O sea: *adivinar siempre la
respuesta más común le gana al modelo sin fine-tunear.* El 0,766 que publicitan
es **después** de fine-tunear sobre ese dominio. Para nuestro dominio —humor
rioplatense sobre personajes inventados— hay que asumir que arranca en el piso.

**(b) La procedencia es discutida.** En Hacker News el proyecto aparece como
"vibecoded" y publicado justo después de que Jev tomara tracción; un comentarista
dice que el paper *"would be a strong reject"* si pasara por revisión. El autor
responde con un arxiv de un año y un paquete PyPI previos. No tengo forma de
zanjarlo. **Lo que sí es un hecho verificable es que el benchmark donde LAYA le
gana a Jev (0,766 vs 0,727) lo publica el propio LAYA.** Es autorreportado sobre
su propio benchmark, contra el producto al que salió a responder. Dos órdenes de
escepticismo, no uno.

**(c) 26,6k estrellas en días es señal de hype, no de calidad.** No es un
argumento en contra; es un argumento en contra de usar las estrellas como
argumento.

**La buena noticia es que hay una arquitectura que hace que (a) y (b) casi no
importen**, y es el eje del resto del documento.

---

## 2. Lo que cambia por ser local

En el doc de Jev maté el runtime con tres razones estructurales. **Local las mata
a las tres:**

| Bloqueo con Jev | Con LAYA |
|---|---|
| Rompe "jugá offline" (vendido en la ficha) | **Cae.** No hay red |
| Obliga a reescribir la política de privacidad y las nutrition labels | **Cae.** Nada sale del teléfono |
| Rate limits, disponibilidad, lock-in | **Cae.** Apache 2.0, pesos tuyos |

Y suma dos cosas que Jev no podía dar:

- **Fine-tuning sobre rioplatense.** El riesgo #1 de todo el doc anterior era que
  el inglés es el idioma primario de Jev. Acá hay un checkpoint multilingüe y una
  receta para entrenar sobre tus propios datos en tu propio idioma.
- **Costo marginal cero.** No es "barato": es cero. Eso cambia qué diseños son
  pensables — podés correr 8.000 decisiones y tirarlas si no te gustaron.

**Pero hay un bloqueo nuevo, y es de peso: el tamaño.** 322M parámetros en fp16
son ~644 MB; cuantizado a int8, ~322 MB. El límite de descarga por datos móviles
de Apple ronda los 200 MB. Para un juego casual gratis, que se baja por impulso,
pasar ese límite es un filtro de conversión brutal. **Embarcar el modelo no es un
detalle de implementación: es una decisión de producto que compite con la
descarga.**

De ahí sale la distinción que organiza todo lo que sigue.

---

## 3. Los dos modos, y por qué la distinción es el análisis entero

### Modo A — **Compile-time**: el modelo corre en tu Mac, nunca se embarca

Generás decisiones offline, las revisás, las congelás en JSON, y el juego hace
un lookup en una tabla. El `.ipa` no engorda ni un byte.

- Costo en runtime: **cero**. Batería: **cero**. Descarga: **cero**.
- No toca la privacidad ni el offline.
- **Y lo más importante: el modelo es auditable.** Si se equivoca, lo ves en el
  JSON y lo corregís a mano. No estás confiando en el modelo; lo estás usando
  para *redactar un borrador que revisás*.
- Eso desactiva las alertas (a) y (b) de §1 casi por completo. Un modelo de
  procedencia dudosa cuyo output vos leés línea por línea antes de mergear es un
  riesgo de horas de trabajo, no de calidad del producto.
- Encaja con cómo ya trabaja este repo: `generate-tiers` genera `tiers.json` y un
  test anti-drift lo protege. Esto es la misma figura, con juicio semántico
  en vez de fórmulas.

### Modo B — **On-device**: el modelo viaja en el `.ipa`

Sólo se justifica por una cosa: **decisiones sobre texto que el jugador escribe
en el momento**, que por definición no podés precomputar.

- Costo: +300–600 MB de descarga, batería, y un port real (LAYA es Python;
  hay export a ONNX, pero del otro lado hay que rehacer el tokenizer y el head en
  Swift, contra un target con `SWIFT_STRICT_CONCURRENCY: complete`).
- Latencia: los 33 ms son sobre una **T4, que es una GPU de datacenter**. En el
  ANE de un iPhone, con secuencias cortas, el orden es de decenas a un par de
  cientos de milisegundos. Alcanza de sobra para algo disparado por un toque.
  **No alcanza para nada por frame:** el presupuesto a 60 fps es 16,6 ms enteros.

**Regla que sale de acá:** si la decisión se puede enumerar de antemano, va en
Modo A. Modo B es exclusivamente para texto libre del jugador. Y el juego hoy
tiene **cero `TextField` en 33.578 líneas**, así que Modo B no es optimizar algo
existente: es abrir una puerta nueva.

---

## 4. La idea central: el grafo semántico que nadie recorrió

Contá lo que hay escrito en este repo:

| Entidad | Cantidad |
|---|---|
| Tiers (personajes con nombre y flavor) | 37 |
| Skins / pintas | **131** |
| Achievements | 39 |
| Specials | 10 |
| Eventos | 8 |
| Pisos de la torre | 11 |
| Boosts | 6 |
| Carreras | 4 |
| Claves de localización | 543 |

Son ~250 entidades con nombre propio, personalidad escrita a mano y humor
específico: el Crypto Bro que te muestra un JPG de un mono, el Demonio de ARCA
que vino a auditarte y se quedó a vivir, el del arbolito, el Contador de Dios.

**Y las únicas relaciones que el juego conoce entre ellas son numéricas.** Tier
15 va después del 14. La skin X cuesta Y. Se mergean los iguales. Eso es todo.

Toda relación *de sentido* está escrita en los flavor texts y **no está
materializada en ningún lado**:

| Relación | Pares | Qué habilitaría |
|---|---|---|
| personaje × personaje (afinidad / antipatía) | ~670 únicos | comportamiento social en el campo |
| personaje × evento (reacción) | 296 | que el campo reaccione a lo que pasa |
| personaje × piso (pertenencia) | 407 | el gag de "vos no vas acá" |
| **skin × personaje (qué pinta le queda a quién)** | **4.847** | cofres que tiran pintas que causan gracia |
| special × personaje (patronazgo) | 370 | por qué este special aparece con este |
| carrera × personaje | 148 | coherencia del árbol de carrera |
| **Total** | **~6.700** | |

**Ése es el volumen que el doc de Jev decía que no existía.** Existía; está en el
producto cartesiano del contenido, no en una tabla de eventos. Y tiene
exactamente la forma en la que un modelo de decisión rinde: muchísimos ítems,
juicio semántico sobre texto, espacio de salida chico y enumerado.

**La abstracción, entonces:** un modelo de decisión acá no sirve para *pensar en
runtime*. Sirve para **recorrer una vez ese grafo y dejarlo escrito**, para que
el runtime siga siendo tan tonto y determinista como es hoy. El comportamiento
emergente no sale de inferencia en vivo: sale de una tabla que alguien se tomó
el trabajo de llenar — y llenarla a mano son 6.700 juicios que nadie va a hacer.

---

## 5. Features — Modo A (compile-time)

Ordenadas por (impacto × facilidad). Todas: el modelo corre en la Mac, la salida
es un JSON revisado a mano, el runtime es un lookup.

### A1 · Matriz de afinidad → comportamiento social en el campo — **M**

**Qué es.** Para cada par de personajes, un Score de afinidad
`{se_evitan, indiferentes, se_buscan, inseparables}` derivado de sus nombres y
flavor texts. Se congela en `social_graph.json`.

**Qué hace en el juego.** Hoy `BoardScene` deambula a cada personaje ±34 pt
alrededor de su ancla, a 44 pt/s, **de forma independiente**. El cambio es
sesgar el destino del deambular con la afinidad de los vecinos: los que se
buscan derivan juntos, los que se evitan se corren. El campo deja de ser 30
sprites oscilando y se organiza solo en barritas, corrillos y un tipo que nadie
quiere cerca.

**Por qué es la primera de la lista.** Es la relación precio/efecto más alta de
todo el documento: el costo runtime es *un lookup y una suma vectorial dentro
del `update` que ya existe*, y el efecto es que el juego parece vivo. Y es
content-driven: los personajes que agregues después heredan comportamiento
social sin tocar código.

**Cuidados de implementación, concretos para este repo:**
- El clustering tiene que ser **puramente cosmético**. El drop de un drag resuelve
  a "ancla más cercana" y el modelo de celdas persiste: si el deambular cambiara
  qué celda queda cerca, moverías la mecánica de merge sin querer. El sesgo se
  aplica al *offset visual* dentro de la franja, nunca al ancla.
- Tiene que vivir entero adentro de `BoardScene.update`. Nada de esto puede
  invalidar SwiftUI: el deambular ya es continuo y por eso se publica a 8 Hz por
  conteo de frames, no por frame.
- Respetar Reduce Motion: con Reduce Motion, afinidad = 0.

**Métrica:** sesión media y taps por sesión antes/después. Si mirar el campo es
más lindo, la gente se queda más.

### A2 · Matriz de reacciones a eventos — **S**

**Qué es.** 296 decisiones (37 personajes × 8 eventos) → un Choice sobre ~6
emotes: `{festeja, se_agarra_la_cabeza, se_encoge_de_hombros, sonrisa_torcida, se_esconde, indiferente}`.

**Qué hace.** Hoy cae la `devaluacion` y pasa un banner con un número. Con la
matriz, el campo entero reacciona: el Fisura se agarra la cabeza, el Crypto Bro
se encoge de hombros, el Contador de Dios sonríe de costado. **El chiste deja de
estar en un banner que se lee una vez y pasa a estar en la pantalla.**

**Por qué es la más fácil de todas.** 296 decisiones, seis animaciones nuevas, un
lookup. El sistema de eventos y la cola de celebraciones ya existen. Es
probablemente la mejor relación esfuerzo/gracia del proyecto entero, con o sin
modelo de por medio.

### A3 · Afinidad skin × personaje → cofres que causan gracia — **M**

**Qué es.** 4.847 pares (131 pintas × 37 personajes) con un Score de
`{no_pega, neutro, gracioso, perfecto}`.

**Qué hace.** Hoy el `ChestRoller` sortea con pesos por rareza, agnóstico a quién
la va a usar. Con la matriz, el sorteo **dentro de la rareza que ya salió**
puede sesgarse hacia lo que le quede bien (o absurdamente mal, que suele ser más
gracioso) a tu personaje top del momento.

**La restricción que lo hace seguro:** la rareza la sigue decidiendo el RNG
seedeado. El modelo sólo desempata *adentro* del bucket ya elegido. La economía
no se mueve ni un decimal, y `ChestRollerTests` sigue valiendo.

**Por qué importa:** es la única de la lista que toca el bucle de monetización
sin tocar la economía. Un cofre que tira algo que te causa gracia es un cofre que
querés abrir de nuevo.

### A4 · Pertenencia personaje × piso — **S**

407 pares. El Fisura en el God Realm mirando para todos lados. Una animación,
una tabla, comedia estructural gratis.

### A5 · QA de localización, ahora fine-tuneable en rioplatense — **M/L**

Es la F2 del doc de Jev, y **LAYA la mejora en el punto exacto donde Jev fallaba**:
podés fine-tunear sobre castellano rioplatense en vez de rezarle a un modelo
entrenado principalmente en inglés. 543 claves × 7 idiomas = 3.801
verificaciones, re-corribles gratis en cada cambio de copy.

El costo real no es el cómputo: es **etiquetar el dataset de fine-tuning**. Ver
§9, porque acá es donde la cuenta se pone interesante.

### A6 · Sommelier de chistes — **S**

No generar: **elegir**. Claude escribe 5 variantes de flavor text, LAYA las
puntúa contra el tier y la mecánica, vos te quedás con la mejor. Encaja con
`content-strings.md`, que ya es la fuente de verdad del tono.

### A7 · Compuerta de App Review y lint contenido↔mecánica — **S**

F1 y F4 del doc de Jev, tal cual, pero gratis y local. Sin cambios de diseño.

---

## 6. Features — Modo B (on-device): la puerta que abre el texto libre

Éstas justifican los 300–600 MB, o no se hacen.

### B1 · Discutir con el Demonio de ARCA — **L** _(y es la idea grande)_

**El mecanismo.** El Demonio de ARCA te audita. Aparece una caja de texto:
*"Justificá de dónde salió la plata."* Escribís lo que se te canta. El juego
**puntúa tu excusa** y el premio escala con lo que escribiste.

**Diseño:**
- **state:** `{ excusa, coins_actuales, tier_top, ultimo_evento }`
- **preguntas** (todas en el mismo forward pass):
  - `calidad` → **Score** `{no_es_una_excusa, patética, creíble, brillante}`
  - `menciona_la_mecanica` → **Noul**: ¿alude a algo que realmente hiciste en el juego?
  - `es_ofensiva` → **Noul**: moderación, en el mismo pasaje (ver B2)
- **Premio:** escala con `calidad`. Confianza baja → premio del medio, nunca
  castigo: si el modelo no entiende tu chiste, la culpa no es tuya.
- **Umbral duro:** `es_ofensiva ≥ 0,5` → no hay premio y no se guarda el texto.

**Por qué esto es lo que el "corriendo local" realmente destraba.** Un minijuego
donde el jugador escribe y el juego lo juzga es **imposible con una API**: rompe
el offline vendido en la ficha, obliga a declarar recolección de datos, y cuesta
por partida. Local es gratis, offline e infinito. Es literalmente la feature que
sólo existe si el modelo viaja adentro.

**Y encaja culturalmente como pocas cosas.** Discutirle a la AFIP es el chiste
argentino universal. Es el tipo de mecánica que la gente screenshotea, que es
exactamente el criterio que `content-strings.md` pone para el contenido.

**El costo, sin maquillar:** +300–600 MB de descarga en un casual gratis, un port
ONNX→Swift con tokenizer propio, fine-tuning en español para que el Score
signifique algo, y una mecánica nueva entera en un proyecto que está tratando de
shippear la v1. **Es una feature de v2.0, y hay que decidirla después de ver si
la v1 le importa a alguien.**

### B2 · Moderación on-device → desbloquear ponerle nombre a tu imperio — **M**

Hoy no hay ni un `TextField`, y parte del motivo es que UGC te obliga a moderar
(Guideline 1.2), y moderar parecía significar backend. **Local, no.** Eso
destraba: nombrar tu torre, tu empresa, tu personaje, y que el nombre viaje en la
share card y en el leaderboard de Game Center (ambos ya cableados).

**Advertencia honesta:** para moderación sola, 322M parámetros es matar una mosca
a cañonazos; un clasificador chico dedicado hace el trabajo en 20 MB. B2 sólo
cierra **si ya estás embarcando el modelo por B1**, y entonces sale en el mismo
forward pass y es gratis.

---

## 7. Dynamic pricing: la respuesta honesta, y la versión que sí funciona

Lo pediste explícitamente, así que va derecho.

**Pricing dinámico de IAP no se puede hacer, y no por LAYA.** Los precios de los
IAP se fijan en App Store Connect por price tier. La app no puede inventar un
precio. Lo único que podés elegir es *cuál de los 4 productos ya registrados
mostrar, cuándo y con qué texto*.

**Pricing dinámico de la economía interna sería un autogol.** Los costos de spawn
y de contratación son exactamente lo que `balance-sim` existe para controlar, con
check duro de alcanzabilidad. `balance-log.md` documenta **doce rondas** de
tuneo. Si el costo se vuelve adaptativo, el simulador deja de predecir el juego
real y perdés la única herramienta con la que este proyecto toma decisiones de
economía. Eso es más caro que cualquier upside.

**Y aunque quisieras: es aritmética.** Decidir un precio a partir de 8 features
numéricas es una regresión logística, no un transformer de 322M sobre texto
serializado. Usar LAYA ahí es la peor versión de las dos herramientas.

### La versión que sí funciona: **elegir el pitch, no el precio**

Los 4 productos y sus precios quedan fijos. Lo que decide si alguien compra no es
el número: es **el momento y el texto**. Y eso sí es semántico.

- **state:** una *situación* enumerada del jugador —`{recién_prestigió, trabado_hace_3_sesiones, racha_de_dailies, volvió_después_de_una_semana, cerca_de_un_hito, primera_sesión, ...}`— cruzada con el producto.
- **pregunta:** **Choice** sobre los ~6 textos de pitch escritos a mano, más un
  `{no_mostrar_nada}` que siempre tiene que estar.
- **12 situaciones × 4 productos = 288 decisiones. Compile-time.** Se congela en
  `store_pitch.json` y el runtime es un lookup.

Esto te da lo que la gente busca cuando dice "dynamic pricing" —que la tienda
hable de lo que te está pasando— **sin telemetría, sin backend, sin tocar un
precio, sin que App Review levante una ceja, y sin mover la economía.** Y la
situación del jugador ya es computable con el estado que `GameState` tiene hoy.

**El límite honesto:** sin analytics no vas a poder medir si funcionó más allá de
la tasa de conversión global. Es una mejora a ciegas. Vale igual, porque el
downside es cero, pero no te vendas que es optimización.

---

## 8. Dónde NO usarlo

Casi todo lo del doc de Jev sigue valiendo, más estas que son específicas de un
modelo local:

| Zona | Por qué no |
|---|---|
| **Cualquier cosa por frame** | 16,6 ms de presupuesto a 60 fps. Los 33 ms publicados son sobre una T4 de datacenter. No entra, y no entra por un orden de magnitud |
| **Pathfinding, colisiones, posiciones del deambular** | Geometría. El modelo decide *con quién*, nunca *dónde*: las coordenadas las sigue calculando `BoardScene` |
| **Balance, costos, pacing, prestigio** | Números, y además `balance-sim` es el activo que no hay que romper |
| **`SaveConflictResolver`, `MergeRules`, `ChestRoller` (la rareza)** | Deterministas, testeados, con costo de error catastrófico. El modelo puede desempatar *adentro* de un bucket ya elegido, nunca elegir el bucket |
| **Generar texto, traducir, escribir flavor** | Es un encoder. No genera. Nada |
| **Zero-shot sobre nuestro dominio, sin fine-tunear y sin revisar** | 0,362 contra 0,461 de la clase mayoritaria. Está escrito en el model card |
| **Embarcarlo "por si acaso"** | 300–600 MB en un casual gratis es una decisión de producto, no una dependencia. Si ninguna feature de Modo B entra, el modelo no sube al `.ipa` |

---

## 9. La pregunta incómoda: ¿LAYA, o directamente un LLM?

Es la pregunta que decide todo y no la puedo esquivar.

Las features de Modo A son **~6.700 decisiones, una sola vez**, más re-corridas
cuando cambia el contenido. Comparemos los dos caminos para llegar al primer
`social_graph.json` usable:

| | LAYA fine-tuneado | Claude en batch |
|---|---|---|
| Etiquetar dataset de entrenamiento (~500–1.000 ejemplos) | **horas tuyas o mías** | no hace falta |
| Entrenar (RLCD, Kaggle 2×T4 gratis) + calibrar temperatura | horas | — |
| Validar que no esté en el piso | horas | — |
| Generar las 6.700 decisiones | minutos, gratis | ~1,3 M tokens, un rato, unos dólares |
| Revisar el JSON a mano | igual en los dos | igual en los dos |
| **Tiempo hasta el primer resultado** | **2–4 días** | **una tarde** |
| Re-correr tras un cambio de contenido | gratis, minutos | unos dólares, un rato |

**Para 6.700 decisiones de una sola vez, el LLM gana claro**, porque el costo de
fine-tuning domina y el costo de inferencia es irrelevante a ese volumen. Y hay
un detalle que inclina más la balanza: **para etiquetar el dataset de
fine-tuning de LAYA, lo más práctico sería usar un LLM. Si el LLM ya puede
etiquetar bien, ya puede hacer la tarea entera.**

**LAYA se vuelve la respuesta correcta en exactamente tres escenarios:**

1. **Embarcás el modelo** (B1/B2). Ahí no hay alternativa: un LLM no entra en el
   teléfono con este presupuesto y rompe el offline.
2. **El pipeline se vuelve permanente.** Si el lint de contenido↔mecánica y el QA
   de localización corren en cada commit, para siempre, el costo marginal cero y
   los ~33 ms empiezan a importar de verdad.
3. **Necesitás probabilidades calibradas de verdad**, no un número que un LLM
   escribió porque se lo pediste. Para umbralizar una compuerta de CI en tres
   bandas, eso es la diferencia entre un mecanismo y un placebo. LAYA entrena con
   scoring rules estrictamente propias y reporta ECE 0,081 post-calibración; un
   LLM no te da nada equivalente.

**Conclusión de esta sección, que es la conclusión del documento:** las ideas de
Modo A son buenas **independientemente del motor**. Hacelas. Empezá con un LLM
porque llegás al primer resultado en una tarde. Metelas detrás del `Judge` de una
sola interfaz —que además ya es gratis, porque LAYA habla la misma API que Jev— y
si el pipeline sobrevive tres meses y lo estás corriendo seguido, ahí fine-tuneás
LAYA y cambiás una variable de entorno.

**Lo que no hay que hacer es la secuencia inversa:** fine-tunear primero y
después buscarle un uso.

---

## 10. Riesgos

| Riesgo | Severidad | Mitigación |
|---|---|---|
| **Zero-shot cerca del azar en nuestro dominio** | **Alta** | Es el riesgo principal. Se desactiva con el Modo A: el output se revisa a mano antes de mergear. Nunca dejar que una salida sin revisar llegue al juego |
| **Procedencia y benchmarks autorreportados** | Media | Idem: en Modo A el modelo no es una autoridad, es un redactor. Y compará contra la baseline tonta (clase mayoritaria) en tus propios datos, no contra su benchmark |
| **Tamaño del `.ipa` (Modo B)** | **Alta** si entra B1 | Decisión de producto, no técnica. Medir conversión con y sin. Alternativa: On-Demand Resources, a costa de que la primera partida necesite red — lo cual contradice el pitch |
| **Latencia real en ANE vs. los 33 ms de una T4** | Media (sólo Modo B) | Medir antes de diseñar la mecánica. Si son 400 ms, B1 necesita una animación de "el Demonio está leyendo" — que igual es mejor UX que una respuesta instantánea |
| **El grafo social cambia la mecánica de merge sin querer** | **Alta y silenciosa** | El sesgo va al offset visual, jamás al ancla. Test: con afinidad activada, la celda resuelta por un drop dado no cambia |
| **Perf en el campo con 30+ nodos** | Media | Todo adentro de `BoardScene.update`, presupuesto de ~7 Hz como el deambular actual. `HANDOFF-perf.md` tiene la línea de base |
| **Tabla congelada que se desincroniza del contenido** | Media | Lo mismo que ya hace `generate-tiers`: un test anti-drift que falla si el JSON no corresponde al contenido actual |
| **Proyecto nuevo, mantenimiento incierto** | Baja | Apache 2.0 y pesos descargados. El peor caso es que se congele en la versión que tenés, y en Modo A eso no te afecta en nada |
| **Scope creep sobre un proyecto que está tratando de shippear** | **La más alta de todas** | A2 sola es dos días y mejora el juego. B1 es semanas. No mezclarlas. F6 primero |

---

## 11. Recomendación

**Sobre LAYA vs Jev:** LAYA es mejor opción para este proyecto en casi todo
sentido —local, gratis, Apache 2.0, multilingüe, fine-tuneable, misma API— con la
salvedad grande de que zero-shot arranca cerca del azar. Pero la comparación
importa menos de lo que parece, porque:

**El hallazgo no es el motor: es el grafo.** El doc de Jev concluyó que este
proyecto no tenía volumen. Estaba mirando el lugar equivocado. El volumen está en
el producto cartesiano del contenido —6.700 relaciones semánticas entre 250
entidades con personalidad escrita a mano— y no lo está usando **nadie**. Esa
es la oportunidad, y existe con LAYA, con Jev o con Claude.

**Qué haría, en orden:**

1. **Ahora, y sin modelo de por medio: terminar F6.** Nada de esto le gana a
   shippear.
2. **Primer experimento, una tarde: A2 (reacciones a eventos).** 296 decisiones,
   generadas con un LLM, revisadas a mano, congeladas en `event_reactions.json`,
   seis emotes en `CharacterNode`. Es el test barato de toda la tesis: si esa
   tabla revisada te hace sonreír, el grafo vale y seguís. Si te aburre, cerraste
   el tema por el precio de una tarde.
3. **Si A2 funciona: A1 (grafo social).** Es la que cambia cómo se siente el
   juego, y la que más cuidado de implementación necesita.
4. **A3 y el pitch de la tienda de §7** cuando haya jugadores.
5. **LAYA fine-tuneado entra recién si el pipeline se vuelve permanente** (A5/A7
   corriendo en cada commit) **o si decidís B1.**
6. **B1 es la apuesta grande y va después de la v1.** Discutirle al Demonio de
   ARCA es la mejor idea de este documento y también la más cara. No la empieces
   antes de saber si el juego le importa a alguien.

**Y la línea que hay que sostener aunque todo lo demás cambie:** el runtime de
FisuEvolution es determinista, testeado y offline. Todo lo de acá se puede hacer
**sin tocar esa propiedad**, porque el trabajo semántico ocurre antes de
compilar y lo que llega al teléfono es una tabla. La única excepción es B1, y por
eso B1 es una decisión de producto y no una de arquitectura.
