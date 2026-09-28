# Evaluación: ¿incorporar Jev (TypeSafe AI) a FisuEvolution?

_Escrito el 2026-09-21. Doc verificado contra `docs.typesafe.ai` ese mismo día._

**Conclusión de una línea:** en el binario que se sube a la App Store, Jev no
tiene absolutamente nada que hacer — y eso no es un defecto de Jev, es una
propiedad del juego. Donde sí puede ganarse el lugar es **fuera del binario**,
en tres o cuatro compuertas de texto que hoy no existen y que nadie está
chequeando. El argumento para adoptarlo **no es el costo** (ver §4); es que hoy
hay chequeos que ningún `grep` puede hacer y que nadie hace.

> El prompt original venía con los campos del proyecto en blanco. Los completé
> desde el repo: **FisuEvolution** (merge-idle iOS con humor rioplatense,
> Swift 6 / SwiftUI + SpriteKit + EconomyKit, 33.578 líneas Swift, 121+ tests),
> etapa **pre-ship** (F5 código completo, F3 arte en curso, app record
> `6814521946` creado, esperando Apple Developer Program), restricciones
> heredadas: **sin backend, offline-first, sin analytics de terceros** (está
> escrito en `Resources/Legal/privacy.md`), presupuesto de una persona.

---

## 0. Correcciones al contexto del prompt

Lo que sostiene la doc pública al 2026-09-21, y lo que no:

| Claim del prompt | Estado |
|---|---|
| "No es un LLM: no genera texto" | **Verificado.** `concepts/system-one.md`: "System One models do not write replies, produce code, or generate explanations of their reasoning." |
| "Estado + preguntas tipadas, un solo pasaje" | **Verificado.** `POST /v1/systemone` con `state` + `model` + `questions`; la doc de `models.md` dice que "ingests the `state` once and evaluates every question against it in parallel". Tres primitivas: Choice, Noul, Score. |
| "70–500 ms de latencia" | **No verificable en la doc pública.** Ni `models.md`, ni `system-one.md`, ni `introduction.md` publican cifras de latencia. Lo que sí publican son **rate limits**: 250.000 tokens/s y 1.200 req/min, "adjusting dynamically" por demanda. Tratalo como claim de marketing hasta medirlo vos. |
| "~100x más barato que un LLM" | **Parcial.** El precio sí está publicado y es muy bajo: **USD 42 por mil millones de tokens de input (USD 0,042 por millón), output gratis**. Si eso es 100x depende contra qué LLM lo compares; el ratio no está en la doc. El número absoluto sí, y es el que importa acá. |
| "Sin alucinaciones fuera del esquema" | **Corregir el matiz.** El esquema sí está garantizado (salida tipada). La corrección la hace la propia doc: *"Typed output guarantees the interface, not truth"*. Y hay una página entera de limitaciones conocidas (`model-jaggedness/jev-1.13.md`) con nueve modos de falla. |
| "Lanzado en septiembre de 2026" | No pude confirmar la fecha en la doc. Lo que sí figura: modelo actual **`jev-1.13.0`** (alias `jev-latest`), estado **GA**. |

**Dos hechos de la doc que el prompt no menciona y que cambian el análisis de
este proyecto en particular:**

1. **Jev es text-only.** *"No image, audio, or video input."* Esto mata de
   entrada el candidato más obvio del repo (el QA visual del pipeline de arte).
2. **El inglés es el idioma primario de entrenamiento.** *"English is the
   primary training language and where accuracy is currently best"*; el resto
   funciona "with varying accuracy" y la doc pide testearlo. Este juego es
   **castellano rioplatense con chistes locales** (`Plan Platita`, `corralito`,
   `el del arbolito`, `Demonio de ARCA`). Es el riesgo #1 de todo el documento.

---

## 1. Qué es Jev, en términos de este proyecto

Jev recibe un bloque de contexto desordenado (acá sería: un string del catálogo
de localización, una reseña de la App Store, un par flavor-text + config JSON) y
un conjunto de preguntas cuyas respuestas posibles vos definís de antemano, y
devuelve la respuesta tipada más una probabilidad calibrada. No escribe nada.

Comparado con lo que el proyecto ya usa:

- **vs. LLMs:** el juego no usa ninguno en runtime. El único uso de LLM/IA del
  repo es el pipeline de arte (Gemini genera imágenes, CLIP las puntúa) y las
  sesiones de Claude que escriben el código. Jev no reemplaza a ninguno de los
  dos: Gemini genera píxeles, Claude escribe Swift, Jev sólo decide entre
  opciones que vos enumeraste.
- **vs. reglas hardcodeadas:** el 100% de la lógica de juego ya es determinista
  y está cubierta por tests (`MergeRules`, `ChestRoller` con SplitMix64
  seedeado, `SaveConflictResolver`, `EconomyEngine`). Jev sería un downgrade
  ahí: cambiaría un test reproducible por una probabilidad.
- **vs. clasificadores clásicos:** el único clasificador del repo es
  `style_score.py` (CLIP ViT-B-32 + rembg + heurísticas de paleta y blobs).
  Opera sobre píxeles. Jev no puede tocarlo.

En criollo: en este repo Jev no compite con nada de lo que hay. Sólo puede
ocupar huecos donde hoy no hay nada.

## 2. Por qué es novedoso — y por qué acá importa poco

Lo genuinamente nuevo es que **evaluar cada ítem de un conjunto grande con
criterio semántico pasa a costar menos que loguearlo**. A USD 0,042 por millón
de tokens de input con output gratis, chequear las 543 claves de
`Localizable.xcstrings` contra cinco criterios cuesta **menos de un centavo de
dólar por pasada**. Eso habilita el patrón "correlo en cada commit" en vez de
"correlo una vez antes de shippear", que es una diferencia de naturaleza, no de
grado: un chequeo que corre siempre atrapa regresiones; uno que corre una vez es
una auditoría.

**Ahora la parte honesta: este proyecto casi no tiene ese problema.**

- No hay volumen. El corpus de texto entero del juego son 543 strings y 15
  JSONs de config. No hay 100.000 filas de nada.
- No hay costo que bajar. **No hay ni una llamada a un LLM en producción**, así
  que no existe una factura que Jev pueda abaratar 100x. 100x de cero es cero.
- No hay latencia que mejorar en la experiencia de usuario. El juego corre a 60
  fps enteramente local; la decisión más "cara" del runtime es un `switch` sobre
  un enum.
- El cuello de botella real del proyecto **no es decidir, es generar**: F3 está
  frenada esperando que Gemini produzca 93 assets que convenzan. Jev no dibuja.

Así que el argumento de "costo y latencia" —que es el argumento central de
TypeSafe— **no aplica acá**. Lo que queda en pie es el otro tercio del pitch:
salida tipada y probabilidad calibrada para chequeos que hoy no existen porque
escribirlos con reglas es imposible y escribirlos con un LLM es frágil.

## 3. Inventario de puntos de decisión

Recorrí el runtime, el pipeline de arte, el tooling y el flujo de release.

### 3.a — Runtime (el binario iOS): ningún candidato

Esto es un hallazgo, no una omisión. Lo verifiqué así:

```
grep -rn "URLSession|https://|URLRequest|CKContainer" --include=*.swift  → 2 hits, ambos CKContainer
grep -rniE "openai|anthropic|gemini|\bllm\b|gpt-" --include=*.swift      → 0 hits
grep -rn "TextField|UITextField|onSubmit" --include=*.swift              → 0 hits
```

| Punto | Ubicación | Qué decide | Frecuencia | Hoy | ¿Jev? |
|---|---|---|---|---|---|
| Merge válido / inválido | `Scenes/MergeTargeting.swift`, `EconomyKit/MergeRules.swift` | booleano + celda destino | ~cada drag | geometría + igualdad de tier | **No.** Determinista y testeado |
| Selección de evento | `Managers/ContentSystems.swift` + `events.json` | 1 de 8 | cada ~900±300 s | pesos + `minTier` + cooldown | **No.** Es una lotería con reglas |
| Loot de cofre | `EconomyKit/ChestRoller.swift` | 1 de N rarezas | por cofre | SplitMix64 seedeado | **No.** Tiene que ser reproducible en tests |
| Próxima lección del tutorial | `GameState+TutorialTips.swift` | 1 de 9 | pocas por partida | orden de `allCases` + señal de gating barata | **No.** La regla de oro ("ninguna lección manda a una pantalla vacía") es una precondición booleana exacta, no un juicio |
| Mejor contratación | `GameState+Hiring.swift` + tests `BestHireTests` | 1 de N tipos | por tap del atajo | maximización de ratio costo/yield | **No.** Es aritmética; Jev "is not a calculator" |
| Conflicto de save CloudKit | `EconomyKit/SaveConflictResolver.swift` | cuál save gana | por sync | gana mayor `lifetimeEarnings` + unión de compras | **Nunca.** Probabilidad sobre el progreso de alguien = borrarle la partida el 3% de las veces |
| Daily reward / calendario | `DailyCalendarTests`, `daily_rewards.json` | día del ciclo | 1/día | aritmética de fechas | **No.** Documentado: Jev *"reads dates as text, not as ordered quantities"* |

Y las tres razones estructurales por las que el runtime está cerrado para
siempre, no sólo hoy:

1. **"Jugá offline" es una feature vendida** — está en la descripción de la App
   Store, en dos idiomas. Una decisión que necesita red no puede estar en el
   loop.
2. **"No hay analytics de terceros" está en la política de privacidad** y en las
   nutrition labels. Mandar estado de partida a `api.typesafe.ai` obliga a
   reescribir ambas y a declarar un data collector nuevo.
3. **No hay SDK de Swift.** La doc publica Python y JavaScript. Integrarlo sería
   HTTP a mano dentro de un target con `SWIFT_STRICT_CONCURRENCY: complete`.

### 3.b — Pipeline de arte: un candidato, y es malo

| Punto | Ubicación | Qué decide | Frecuencia | Hoy | ¿Jev? |
|---|---|---|---|---|---|
| ¿La imagen pasa QA? | `scripts/style_score.py`, `qa_clip.py` | pass/fail + score | 93 assets × N regeneraciones | CLIP + rembg + blob/paleta/saturación, y Claude mirando los PNG | **No puede.** Jev es text-only |
| ¿Este recorte está bien? | `revision_recortes.py`, `revision_islas.py` | aceptar/rechazar/recortar | por asset | heurísticas + revisión visual | **No puede.** Ídem |
| ¿El prompt es correcto antes de gastar la llamada? | `prompts/prompts.json`, `cultural_dict.py` | pass/fail textual | 93 prompts | nada (se generan y se ve qué sale) | Técnicamente sí, pero los prompts son deterministas y ya están revisados. **No vale el cableado** |

### 3.c — Contenido y release: acá están los candidatos de verdad

| Punto | Ubicación | Qué decide | Frecuencia | Hoy | Costo actual |
|---|---|---|---|---|---|
| **¿Este texto pasa App Review?** | `boosts.json.reviewSafe` (6 boosts), `Localizable.xcstrings` (543 claves), `Distribution/store-metadata.md` | qué strings necesitan variante "store" | cada edición de copy | **el dueño a mano.** El mecanismo (`buildVariant`) existe; el criterio de cuándo aplicarlo vive en la cabeza de una persona | un rechazo de review = días + un ciclo de submit |
| **¿La traducción preserva el chiste?** | `Localizable.xcstrings` (es/en hoy; pt/fr/de/it/ja/ko/zh en `tasks.md` como "pendiente de decisión") | aprobar/rechazar por string | 543 × idioma nuevo | **no existe.** Por eso la localización está trabada | bloqueante de 7 mercados |
| **¿El flavor text sigue describiendo la mecánica?** | pares `events.json`/`boosts.json`/`specials.json` ↔ sus claves en el catálogo | concuerda / contradice | cada rebalance | **nadie lo chequea.** El test anti-drift cubre `tiers.json` numéricamente, no la prosa | `balance-log.md` documenta 12 rondas de rebalance; ningún ciclo tocó los textos |
| **Triage de reseñas de la App Store** | no existe todavía | bug / balance / monetización / arte / elogio / spam + severidad | post-launch, continuo | **no existe** — y sin analytics de terceros, **es el único canal de feedback que va a haber** | hoy cero, mañana el único |
| **Qué docs leer para retomar** | `Docs/` (46 archivos, 816 KB) + `ESTADO.md` + `FisuEvolution-plan.md` + el harness AVO | subconjunto relevante | cada arranque de sesión | "leé estos archivos antes de tocar nada" | minutos de contexto quemado por sesión |

---

## 4. Valor que aporta

**Costo: irrelevante, y conviene decirlo sin vueltas.** Las cuentas con el precio
publicado (USD 0,042 por millón de tokens de input, output gratis):

| Uso | Volumen | Tokens estimados | Costo |
|---|---|---|---|
| Barrido completo de review-safety | 543 strings × 5 preguntas | ~217 k | **~USD 0,01 por pasada** |
| QA de localización a 7 idiomas | 3.801 strings × 4 preguntas | ~1,9 M | **~USD 0,08** (una vez) |
| Triage de reseñas | ~100/mes | ~60 k | **~USD 0,003 al mes** |

Todo lo que propongo en §5 junto cuesta **menos de USD 5 al año**. Eso corta los
dos lados del argumento: el costo no es razón para adoptarlo, pero tampoco lo es
para rechazarlo. La pregunta es sólo si el chequeo vale la pena existir.

**Latencia: importa en un solo lugar, y no es el que vende TypeSafe.** No en la
app (offline). Sí en **CI y pre-commit**: la diferencia entre una compuerta de
~200 ms y una de ~8 s es la diferencia entre un hook que sobrevive y uno que el
dueño desactiva a la semana. Pero ojo: **esto depende del claim de latencia que
no pude verificar.** Si en la práctica son 2 s, el argumento se debilita bastante
y hay que medirlo antes de construir nada encima.

**Confiabilidad: acá está el valor real, y es el único que no depende de claims
sin verificar.** Un `Noul` devuelve una probabilidad sobre la que podés poner un
umbral y fallar el build de forma determinista. Un LLM con structured output te
da el mismo JSON pero con una "confianza" que se inventó al escribirla. La doc
de TypeSafe es explícita en que las probabilidades están *"optimized against
outcomes to reflect uncertainty"* — eso es exactamente lo que necesita una
compuerta de CI para tener tres bandas (pasa / avisa / frena). **Pero la misma
doc aclara que hay que validar la calibración en tu dominio**, y el dominio de
este proyecto es humor rioplatense, o sea el peor caso posible para un modelo
entrenado principalmente en inglés.

**Escala: la única cosa que se vuelve posible a 100x que hoy no lo es** es la
localización a 7 idiomas con verificación por string. No porque cueste plata hoy
—no cuesta nada, porque no se hace— sino porque hoy **no hay ningún criterio**
para decidir si la traducción al japonés de "Se cayó Mercado Pago" funciona.

**Experiencia de usuario: cero impacto directo.** Nada de esto lo ve el jugador.
El impacto es indirecto y llega por dos caminos: no comerse un rechazo de App
Review, y que los textos no contradigan las mecánicas después de un rebalance.

---

## 5. Features propuestas

Ordenadas por impacto × facilidad. Las tres primeras habilitan algo que hoy no
existe; las dos últimas son conveniencia.

### F1 · Compuerta de App Review sobre el copy — **S**

**Qué hace:** clasifica cada string user-facing y cada texto de
`store-metadata.md` contra las guidelines que este juego efectivamente roza, y
falla el build cuando encuentra algo sin su variante `reviewSafe`.

**Problema y para quién:** hoy el mecanismo existe (`buildVariant` "dev"/"store"
elige `boosts.json.reviewSafe`) pero **el criterio de cuándo aplicarlo es
memoria humana**. El dueño decidió a mano que `fernet` necesita gemelo seguro y
`mate` no. Cada string nuevo reabre esa decisión, y el costo de errarle se paga
recién en el submit. El juego tiene alcohol (fernet), crypto, referencias a
evasión impositiva (`blanqueo`, `Demonio de ARCA`), un cambista informal
(`el del arbolito`) y humor político argentino: no es una preocupación teórica.

**Diseño:**
- **state:** `{ key, es, en, contexto: "boost|evento|special|logro|tienda|ASO", mecanica: "<effectType + magnitude>" }`
- **preguntas** (todas independientes, un solo request):
  - `alcohol_drogas` → **Noul**: ¿el texto presenta consumo de alcohol o drogas de forma positiva o como recompensa? (1.1.x / rating)
  - `exageracion` → **Noul**: ¿promete un beneficio que la app no entrega? (2.3.1)
  - `actividad_ilegal` → **Noul**: ¿presenta evasión, contrabando o cambio informal como algo a imitar y no como sátira? (1.1.x)
  - `apuestas_crypto` → **Noul**: ¿sugiere ganancia financiera real?
  - `severidad` → **Choice**: `{ninguna, reescribir_flavor, requiere_reviewSafe, no_shippear}`
- **Umbrales:** `Noul ≥ 0,7` → falla el build. `0,4–0,7` → warning que lista el
  string y exige un `// review-ok:` explícito en el config. `< 0,4` → pasa.
  Estos números son el punto de partida de §8, no un resultado.
- **Baja confianza:** cae a humano, nunca a "pasa". Es una compuerta, y el costo
  asimétrico (falso positivo = 30 segundos de un humano; falso negativo = un
  ciclo de review) justifica calibrar conservador.
- **Qué sigue haciendo un LLM:** escribir la variante `reviewSafe` cuando Jev
  marca que hace falta. Jev detecta, Claude redacta, el dueño aprueba.
- **Dependencias:** ninguna. Script Python sobre `.xcstrings` + los JSONs.
- **Métrica:** submit v1.0.0 sin rechazo por contenido; y, antes de eso, que
  reproduzca los `reviewSafe` que el dueño ya decidió a mano (ver §8).

### F2 · QA de localización a 7 idiomas — **M**

**Qué hace:** el LLM traduce las 543 claves; Jev verifica cada string traducido
contra criterios tipados. Nada se mergea sin pasar.

**Problema y para quién:** `tasks.md` tiene la localización a pt/fr/de/it/ja/ko/zh
como "pendiente de decisión" y va a seguir ahí, porque el valor del juego **es el
chiste** ("el humor es el marketing", dice `content-strings.md`) y nadie en el
proyecto puede juzgar si el chiste sobrevivió al japonés. Esta es la única
feature de la lista que **desbloquea mercados**.

**Diseño:**
- **state:** `{ key, original_es, ingles_de_referencia, traduccion, idioma, nota_cultural, chars_max }`
- **preguntas:**
  - `sentido` → **Noul**: ¿la traducción transmite el mismo hecho mecánico que el original?
  - `intencion_comica` → **Score** (4 niveles, descritos en concreto): `{literal_sin_gracia, entendible_pero_plana, adaptada_funciona, equivalente_local_logrado}`
  - `registro` → **Noul**: ¿es informal y hablado, no de manual?
  - `referencia_sin_adaptar` → **Noul**: ¿deja una referencia local intraducible sin equivalente? (el caso "corralito" en alemán)
- **Umbrales:** `sentido < 0,9` → rechazo automático, vuelve al traductor.
  `intencion_comica` en los dos niveles bajos → reescritura. `registro` y
  `referencia_sin_adaptar` → warning acumulado por idioma; si un idioma junta
  >15% de warnings, **ese idioma no se shippea** (señal de que Jev o el traductor
  no están rindiendo ahí).
- **Baja confianza:** a revisor humano nativo. Si no hay presupuesto para eso, el
  string se shippea **en inglés**, que es la degradación honesta.
- **Qué sigue haciendo un LLM:** todo lo generativo. Jev acá es exclusivamente
  juez. La división es limpia porque Jev no puede generar aunque quisiera.
- **Longitud:** la mide `len()`, no Jev — es un número.
- **Dependencias:** F1 conviene primero (mismo cableado, mismo parser de
  `.xcstrings`). Requiere que v1.0.0 esté shippeada.
- **Métrica:** % de strings que pasan en primera vuelta por idioma, y —la que
  importa— retención D1 del mercado nuevo vs. el hispanohablante.

### F3 · Triage de reseñas de la App Store — **S**

**Qué hace:** cada reseña nueva entra clasificada por tema, severidad y tier
mencionado.

**Problema y para quién:** el proyecto decidió no tener analytics de terceros —
decisión correcta y escrita en la política de privacidad. La consecuencia es que
**las reseñas son el único canal de feedback que va a existir**. Sin triage, eso
son 200 textos sin leer en tres meses. Con triage, es un backlog priorizado.

**Diseño:**
- **state:** `{ titulo, cuerpo, rating, version, locale }`
- **preguntas:**
  - `tema` → **Choice**: `{bug_crash, balance_progresion, monetizacion_precio, arte_ui, contenido_humor, rendimiento, elogio, spam_irrelevante}`
  - `menciona_perdida_de_progreso` → **Noul** (esto es P0 y merece pregunta propia: el save tiene migraciones v1→v2→v3 y sync CloudKit con resolución de conflictos, el lugar exacto donde un bug es catastrófico y silencioso)
  - `punto_del_juego` → **Choice**: `{tutorial, primeras_horas, mid_game, cerca_de_dios, post_prestige, no_dice}`
  - `severidad` → **Score** (4 niveles: `{comentario, molestia, deja_de_jugar, desinstala}`)
- **Umbrales:** `menciona_perdida_de_progreso ≥ 0,6` → alerta inmediata, sin
  importar el resto. `severidad` en el nivel más alto con `confidence ≥ 0,7` →
  al tope del backlog. Confianza baja en `tema` → bucket "sin clasificar", que
  el dueño lee entero (con este volumen, es perfectamente viable).
- **Qué sigue haciendo un LLM:** redactar la respuesta pública a la reseña, si
  se decide responder. Jev no escribe.
- **Dependencias:** app publicada + App Store Connect API Key (ya está en el
  checklist de F6).
- **Métrica:** tiempo desde que aparece una reseña que reporta pérdida de
  progreso hasta que el dueño la ve. Hoy es indefinido.
- **Privacidad:** las reseñas son públicas y llevan nickname, no PII. Igual,
  strippear el nickname antes de mandar: no aporta a la clasificación.

### F4 · Lint semántico contenido ↔ mecánica — **S/M**

**Qué hace:** para cada par (flavor text, config JSON), pregunta si el texto
sigue describiendo lo que el número hace.

**Problema y para quién:** `balance-log.md` documenta **doce rondas de
rebalance**, y ninguna tocó la prosa. Si mañana `devaluacion` pasa de
`magnitude: 0.5` a `0.7`, el texto va a seguir diciendo "tu plata vale la mitad"
y nadie se va a enterar hasta que un jugador lo escriba en una reseña. El test
anti-drift protege `tiers.json` a nivel numérico; la prosa no tiene equivalente
porque no se puede escribir con `assert`.

**Diseño:**
- **state:** `{ id, effectType, magnitude, durationSeconds, flavor_es, flavor_en, nombre }`
- **preguntas:**
  - `contradice` → **Noul**: ¿el flavor afirma algo numérico o direccional que el config contradice?
  - `direccion` → **Choice**: `{texto_dice_buff_config_buff, texto_dice_nerf_config_nerf, invertido, texto_neutro}`
  - `magnitud_verbalizada` → **Choice**: `{coincide, texto_exagera, texto_subestima, texto_no_dice_magnitud}`
- **Umbrales:** `contradice ≥ 0,6` o `direccion == invertido` → falla el build.
  El resto, warning.
- **Cuidado documentado:** Jev *"is not a calculator"*. Por eso las preguntas son
  **direccionales y cualitativas** ("¿dice mitad y es mitad?"), nunca "¿0.5 × 3.0
  da 1.5?". Cualquier comparación numérica fina la hace el script en Python
  antes de armar el `state`.
- **Qué sigue haciendo un LLM:** reescribir el flavor cuando el lint falla.
- **Dependencias:** F1 (mismo runner).
- **Métrica:** que atrape, en backtest, las contradicciones que las 12 rondas de
  rebalance ya introdujeron. Si no encuentra ninguna, la feature no hacía falta —
  y eso también es un resultado útil.

### F5 · Router del corpus de handoff — **M** _(herramienta interna, no producto)_

**Qué hace:** dados una tarea y los 46 docs de `Docs/` (816 KB) más `ESTADO.md`,
el bible y `tasks.md`, rankea qué leer.

**Problema y para quién:** para las sesiones de Claude sobre este repo — incluida
la que escribió esto. `ESTADO.md` dice "leerlos antes de tocar nada" sobre cuatro
documentos rectores, y hay cuarenta y dos más. Es el caso de reranking del
cookbook de TypeSafe, y es el único lugar del proyecto con volumen que Jev
maneja bien (texto, muchos ítems, decisión acotada).

**Diseño:** un **Score** de relevancia por documento (state = tarea + título +
primeras ~300 palabras), más un **Noul** de "¿este doc documenta una trampa que
se puede volver a pisar?" — porque el repo tiene un patrón explícito de "no
re-tropezar" (la tabla de problemas resueltos de `ESTADO.md`, la trampa de método
al final de `balance-log.md`).

- **Umbrales:** top-5 por score; los `Noul` de trampa ≥ 0,7 entran siempre, aunque
  el score sea bajo. Es el caso donde un falso positivo cuesta 2 KB de contexto y
  un falso negativo cuesta una tarde.
- **Contra qué compite:** `grep`. Y `grep` es muy bueno y gratis. Por eso va
  último: el margen sobre la baseline es chico y probablemente no lo justifique.
- **Métrica:** que los docs elegidos contengan la trampa que la sesión terminó
  pisando. Medible a posteriori sobre las sesiones ya escritas.

### Lo que dejé afuera a propósito

**Dificultad dinámica / personalización del pacing en runtime.** Suena a la
feature más sexy de la lista y por eso la nombro: ajustar la curva según cómo
juega cada uno. No va, y no por Jev: rompe el offline que está vendido en la
ficha, obliga a declarar recolección de datos, y —lo peor— haría que
`balance-sim` deje de predecir el juego real, que es la única herramienta con la
que este proyecto toma decisiones de economía.

---

## 6. Dónde NO usarlo

| Zona | Por qué no |
|---|---|
| **Cualquier cosa dentro del binario iOS** | Rompe "jugá offline" (feature vendida), obliga a reescribir la política de privacidad y las nutrition labels, y no hay SDK de Swift. Tres razones independientes; cualquiera alcanza |
| **QA visual del pipeline de arte** | Jev es text-only. No es "sería peor": no puede |
| **Generar copy, flavor text o traducciones** | No genera texto, y la doc dice que rinde mal si lo forzás |
| **Balance, pacing, economía** | Son números. *"Jev is not a calculator"*. Y ya existe `balance-sim` con check duro de alcanzabilidad, que es reproducible y auditable — cambiarlo por un juicio probabilístico sería retroceder |
| **`SaveConflictResolver`** | La regla es "gana mayor `lifetimeEarnings` + unión de compras". Exacta, testeada, y el costo de errarle es borrarle la partida a alguien. Una probabilidad no tiene lugar acá |
| **`MergeRules`, `ChestRoller`, selección de eventos, `BestHire`** | Deterministas por diseño y cubiertos por tests. Un RNG seedeado es reproducible; Jev no |
| **Aritmética de fechas (daily reward, cooldowns, offline cap)** | Documentado: *"reads dates as text, not as ordered quantities"* |
| **Moderación de contenido de usuario** | No hay contenido de usuario. Cero `TextField` en 33.578 líneas |
| **El tutorial contextual** | La regla de oro del dueño ("ninguna lección manda a una pantalla donde no hay nada que hacer") es una precondición booleana exacta sobre el estado. Ya está bien resuelta |
| **Tandas grandes de texto en un solo `state`** | La doc advierte *"context rot"* con contexto irrelevante grande. Un string por request, no las 543 juntas |

Regla general para este repo: **si un test lo puede afirmar, no es para Jev.**

## 7. Riesgos

| Riesgo | Severidad acá | Mitigación concreta |
|---|---|---|
| **Calidad en rioplatense** | **Alta** — es el riesgo #1. La doc dice que el inglés es el idioma primario, y el valor del juego son chistes locales | Mandar siempre el par es+en en el `state` (el catálogo ya tiene ambos, gratis). Medir por separado el acierto en es vs. en en §8. Si la brecha es grande, usar el inglés como entrada principal y tratar el español como señal secundaria |
| **Lock-in con un proveedor nuevo** | **Baja** — porque nada de esto está en el binario | Una interfaz `Judge` con dos implementaciones desde el día uno: `JevJudge` y `LLMJudge` (structured output). Son ~40 líneas de Python. Si TypeSafe desaparece, se cambia una variable de entorno y se pierde la calibración, no la feature |
| **Disponibilidad / rate limits** | **Baja** — nada corre en el camino del usuario | Todo corre en CI o batch offline. Los rate limits publicados (1.200 req/min) exceden por dos órdenes de magnitud lo que este proyecto necesita. Ojo con la nota de la doc: *"adjusting dynamically...may change without notice"* — no construir nada que asuma un piso |
| **Privacidad de los datos enviados** | **Baja, con una condición** | Lo que sale del repo es copy del juego: ya va a ser público en la App Store. El único flujo con datos de terceros es F3; strippear el nickname antes de enviar. La doc dice *"Jev is not trained on customer requests or responses"* y ofrece zero data retention por DPA — para este uso no hace falta |
| **Falta de benchmarks independientes** | **Media** | No adoptarlo por los claims. §8 es un experimento con baseline explícita. Si Jev no le gana al LLM en la misma tarea, no entra |
| **Claims sin verificar (latencia, 100x)** | **Media** | Medir latencia p50/p95 en la primera tanda y escribirlo en este doc. F1 y F4 corren en pre-commit y sólo tienen sentido si son rápidas |
| **`jev-latest` cambia bajo tus pies** | Media | Pinear `jev-1.13.0`, no el alias. Un modelo nuevo mueve los umbrales de §5; el pin convierte eso en un cambio deliberado con re-baseline |
| **Falsa sensación de seguridad en la compuerta de review** | **Media-alta** | Que Jev no rechace **no es** aprobación de App Review. El dueño sigue leyendo el copy antes del submit. Jev atrapa lo que se pasó, no reemplaza la lectura |
| **Cableado que sobrevive a su utilidad** | Media | Todo en `Tools/`, con `--dry-run`, y sin que el build de la app dependa nunca de una llamada de red: la compuerta corre y escribe un reporte; el build lee el reporte |

## 8. Plan de validación

**Un solo experimento, de una tarde, sobre F1.** Es el que tiene etiquetas ya
existentes, el de mayor costo de error, y el que no depende de nada bloqueado.

**Punto de decisión:** review-safety sobre strings del juego.

**Dataset (~90 ítems, etiquetado en ~1 hora):**
- **Positivos que ya existen:** los boosts con gemelo `reviewSafe` distinto del
  original — hoy `fernet` es el caso claro. Son pocos, pero son etiquetas que el
  dueño puso pensando exactamente en esto.
- **Negativos que ya existen:** los boosts cuyo `reviewSafe` apunta a la misma
  clave (`mate`, `cafe`, `milanesa`): el dueño ya decidió que no hacían falta.
- **El grueso:** 80 strings muestreados de las 543 (estratificado por contexto:
  eventos, specials, logros, tienda, ASO), etiquetados por el dueño en una
  planilla de dos columnas. Incluir a propósito los bordes duros del juego:
  `blanqueo`, `Demonio de ARCA`, `el del arbolito`, `cryptobro`, `corralito`,
  y el copy de ASO que ya está escrito en `checklist-submission.md`.

**Baselines (las dos, sobre exactamente los mismos 90):**
1. **Regex de palabras clave** — la que un dev escribiría en 20 minutos
   (`fernet|alcohol|crypto|apuesta|evadir|...`). Si Jev no le gana claramente a
   esto, la respuesta es "una regla simple alcanza" y se cierra el tema.
2. **Un LLM con structured output**, mismas preguntas, mismo formato de salida.
   Es la comparación que importa, porque es la alternativa real.

**Qué medir:**
- Accuracy y, sobre todo, **recall de los positivos** (un falso negativo cuesta
  un ciclo de review; un falso positivo, 30 segundos).
- **Accuracy en `es` vs. en `en` por separado.** Esta es la medición que decide
  todo lo demás, y es la que la doc de TypeSafe pide explícitamente hacer.
- **Calibración:** agrupar por bandas de probabilidad y ver si la banda 0,7–0,8
  acierta ~75%. Si la probabilidad no significa nada, el argumento central de
  Jev sobre un LLM se cae y no queda razón para adoptarlo.
- Latencia p50/p95 y costo real de la tanda.

**Qué resultado justifica seguir:**
- Recall de positivos **≥ 0,9** con menos de ~20% de falsos positivos, **y**
- la brecha es vs. inglés **≤ 10 puntos** de accuracy, **y**
- la calibración es monótona (bandas más altas aciertan más), **y**
- empata o gana al LLM en la misma tarea a una fracción del costo y del tiempo.

**Qué resultado lo mata:**
- Recall < 0,75 en español, o
- la brecha es/en > 20 puntos — significa que el idioma del juego está fuera de
  lo que el modelo maneja hoy, y F1/F2/F4 (todas en español) caen con ella, o
- el LLM gana por margen claro — entonces la respuesta es "structured output con
  el LLM que ya usás y listo".

**Si sale bien:** F1 a pre-commit con umbrales calibrados sobre estos datos (no
los que puse en §5, que son un punto de partida), F4 detrás con el mismo runner,
y F3 cuando la app esté publicada. F2 recién después de v1.0.0 y sólo si la
brecha es/en fue chica. **Si sale mal:** queda este documento, que ya sirvió para
constatar que el runtime de FisuEvolution no tiene ni un punto de decisión
semántica — y eso es una propiedad buena del diseño, no una carencia.

---

## Recomendación

**No adoptar Jev "para el proyecto". Adoptarlo —si el experimento da— para una
compuerta específica de CI, y medir antes de construir.**

FisuEvolution es un juego offline determinista con el 100% de su lógica cubierta
por tests. Eso es exactamente el perfil de proyecto donde un modelo de decisión
tiene menos para aportar, y conviene decirlo así en vez de inventarle un lugar.
Los cuatro huecos reales que encontré son de texto, están fuera del binario, y
suman menos de USD 5 al año — o sea que la decisión no es económica: es si vale
la pena mantener el cableado. Para F1 creo que sí, porque el costo de un rechazo
de App Review sobre un juego cuyo humor es el producto es alto y el dueño paga
USD 99 y espera. Para el resto, el experimento de §8 decide.
