# El campo reacciona — spec

_Escrito el 2026-09-27. Sale de `evaluacion-laya.md` §5 (A2). Es el experimento
barato que decide si el grafo semántico del contenido vale la pena._

---

## 1. El problema, en una escena

Cae la **Devaluación**. Hoy pasa esto:

1. Entra un banner con spring: *"Devaluación sorpresa: tu plata vale la mitad.
   Tranqui, ya estás entrenado."*
2. El ingreso se multiplica por 0,5 durante 90 s.
3. **En el campo no pasa absolutamente nada.** El Fisura, el Cartonero y el
   Fondo Buitre Estelar siguen deambulando exactamente igual, a 44 pt/s, ±34 pt
   alrededor de su ancla, como si no hubiera pasado nada.
4. A los 6 s el banner se va y no queda rastro.

**Y ahí está el problema real, que es más grande que la falta de una animación:
el chiste central del juego no se ve en ninguna parte.**

Este juego se llama "de fisura a Dios". Su tesis es que la misma cosa le pasa
distinto a cada escalón de la pirámide. Una devaluación **destruye** al Fisura y
le viene **bárbara** al Fondo Buitre Estelar. Un blanqueo hace sonreír de costado
al Contador de Dios y al Cartonero no le mueve un pelo. El Corralito no le
importa nada al que nunca tuvo un peso en el banco.

Esa asimetría es el juego entero. **Y hoy es invisible:** vive en la cabeza del
que escribió los nombres, no en la pantalla.

Hay además una regla del propio proyecto que esto incumple. `feedback-matrix.md`
dice, como criterio de cierre de F5: *"ninguna acción silenciosa — toda
interacción tiene animación + SFX + haptic"*. Los eventos tienen banner y SFX,
sí — pero el campo, que es el 70% de la pantalla y donde están los personajes que
el evento afecta, **no se entera**.

## 2. La feature

Una tabla precomputada de **352 decisiones** (44 tipos × 8 eventos) que dice
cómo reacciona cada personaje a cada evento. Cuando un evento arranca, los
personajes que están en el campo reaccionan. Después vuelven a deambular.

Seis emotes, y uno de ellos es no hacer nada:

| emote | qué se ve | quién, típicamente |
|---|---|---|
| `festeja` | salto + pop de escala | al que el evento le viene bien |
| `se_agarra_la_cabeza` | encoge + sacudida corta | al que lo funde |
| `se_encoge_de_hombros` | sube y baja chico | al que le da lo mismo pero se entera |
| `sonrisa_torcida` | inclinación sutil + pausa del deambular | al que sabe algo que vos no |
| `se_esconde` | encoge y se queda quieto | al que le conviene no figurar |
| `indiferente` | **nada** | el default, y el más común |

**`indiferente` siendo el más común no es una concesión: es el diseño.** Si los
diez personajes del campo reaccionan a todo, es ruido y en dos eventos ya no lo
mirás. Si reaccionan tres, el ojo va a esos tres y el chiste se lee. La tabla
tiene que estar **sesgada al silencio**, y el trabajo del modelo es tanto decidir
quién reacciona como quién no.

## 3. Cómo se genera la tabla

El modelo corre **en la Mac, una vez**. Nunca viaja en el `.ipa`.

**Lo que entra por decisión:**

```
state = {
  personaje: "El Fisura",          // tier.name.homeless
  escalon:   "tier 1 de 30, fase earth",
  evento:    "Devaluación",
  flavor:    "Devaluación sorpresa: tu plata vale la mitad. Tranqui, ya estás entrenado.",
  es_buff:   false
}
```

Todo eso ya existe: los nombres salen de `Localizable.xcstrings` (44 claves
`tier.name.*`), el escalón de `tiers.json`, y el evento con su flavor de
`events.json` + el catálogo.

**La pregunta:** un **Choice** sobre los seis emotes.
*"¿Cómo reacciona este personaje cuando se entera de este evento? Pensá en su
lugar en la escalera social: a quién lo beneficia y a quién lo funde."*

**Cómo se usa la probabilidad —y acá está la parte fina:**

- `confianza ≥ 0,6` → se escribe el emote.
- `confianza < 0,6` → se escribe **`indiferente`**.

O sea: la duda del modelo cae para el lado del silencio, que es exactamente para
donde queremos que caiga. Un falso positivo es un personaje festejando algo que
no tiene sentido —se nota y rompe el chiste—. Un falso negativo es un personaje
que sigue caminando, que es el statu quo. Costos asimétricos, umbral asimétrico.

**Y después se revisa a mano.** El script emite dos archivos: la tabla, y un
`review.md` con las 352 decisiones **ordenadas por confianza ascendente**. Mirás
las 30 más dudosas en diez minutos, corregís lo que no te cause gracia, y el
resto lo spot-chequeás. Eso es lo que hace que no importe si el modelo es bueno:
**no le estás confiando el contenido, le estás pidiendo un borrador de 352
celdas que vos no ibas a llenar nunca a mano.**

**Salida:** `FisuEvolution/Resources/Data/event_reactions.json`

```json
{
  "schemaVersion": 1,
  "reactions": {
    "devaluacion": { "homeless": "se_agarra_la_cabeza", "fondo_buitre": "festeja", "cartonero": "indiferente" },
    "blanqueo":    { "contador_dios": "sonrisa_torcida", "homeless": "indiferente" }
  }
}
```

## 4. Cómo se conecta, en este código

La buena noticia es que **no hay nada que inventar**: los cuatro ganchos que hace
falta ya existen y hay que seguir el idioma que ya está.

**(a) El disparador.** `BoardScene.update` ya compara una versión contra la
renderizada para decidir si relayoutear:

```swift
if gameState.boardVersion != renderedBoardVersion { layoutBoard() }
```

El evento se detecta igual, contra `gameState.activeEvent?.id`, con un
`reactedEventID` propio de la escena. Se agrega **una línea** al final del
`update`, al lado de las cuatro que ya están:

```swift
startBoardCelebrationIfItsTurn()
refreshCrowdDepth()
updateFTUEHint()
publishTutorialSpotlight()
updateEventReactions()   // ← nueva
```

**(b) Congelar y devolver el deambular.** Ya es un patrón establecido en la
escena: el spotlight del tutorial, el arrastre y los candidatos a fusión
congelan con `node.removeAction(forKey: "wander")` y `releaseSpotlitNode()`
devuelve. El emote es el mismo ciclo: congelar → correr la acción → `startWander`.

**(c) A quién NO tocar.** Copiar la lista de exclusiones que `releaseSpotlitNode`
ya respeta, más una:

- el `dragNode` (maneja su propio paseo en `touchesEnded`/`cancelDrag`)
- los `mergeCandidates` (si no, recuperan el paseo en medio de un arrastre)
- el `spotlitNode` (el tutorial lo congeló a propósito)
- **y nada si `boardCelebrationRunning`**: el vuelo del ascenso y el reveal son
  el momento, y un evento no los pisa

**(d) La trampa de `CharacterNode`.** El propio archivo la deja escrita: el
espejado va en el **sprite**, nunca en el nodo, porque los `SKAction.scale(to:)`
del tablero escriben `xScale` e `yScale` a la vez. Los emotes que escalan
(`festeja`, `se_agarra_la_cabeza`, `se_esconde`) van sobre el **nodo**, igual que
el rebote del tap. Cualquier emote que espeje va sobre el **sprite**.

**(e) Accesibilidad.** Con Reduce Motion activo, no hay emotes. El evento ya
tiene banner con ícono ↑/↓ + texto, que es el canal accesible y no se toca.

**(f) Performance.** Son ~10 nodos visibles (no 44: el campo muestra la capacidad
del piso), una vez por evento, o sea cada ~900 s. No hay nada por frame más allá
de la comparación de un `String?`. Es despreciable contra el presupuesto que
`HANDOFF-perf.md` ya tiene medido.

**(g) Audio.** Nada nuevo. `sfx_event` ya suena con el banner; diez emotes con
sonido sería exactamente el ruido que `indiferente` existe para evitar.

## 5. Tests

Siguiendo el molde anti-drift que `generate-tiers` ya estableció:

- **Cobertura:** las 352 celdas existen. Si entra un evento o un tier nuevo y la
  tabla no se regeneró, falla el build.
- **Vocabulario:** todo emote del JSON está en el enum. Nada de strings sueltos.
- **Sesgo al silencio:** ningún evento tiene más de ~4 reactores de 10 en el
  campo típico. Si la tabla se pasa de habladora, el test lo dice.
- **Invariante de mecánica:** el emote no toca el ancla ni la celda. Es el test
  que protege lo único importante — que el merge siga funcionando igual.
- **Exclusiones:** con un drag en curso, el nodo arrastrado no emotea.

## 6. Esfuerzo

| Parte | Tiempo |
|---|---|
| Script generador + las 352 decisiones + `review.md` | media tarde |
| Revisión a mano de las dudosas + spot-check | 30 min |
| Los 6 emotes como `SKAction` en `CharacterNode` | medio día |
| `updateEventReactions` + exclusiones + Reduce Motion | medio día |
| Tests | 2 h |
| **Total** | **~2 días** |

Sin arte nuevo, sin audio nuevo, sin texto nuevo, sin tocar la economía, sin
tocar el save, sin migración de schema.

## 7. Qué valor agrega

**1. Hace visible la tesis del juego.** Es lo principal y no es decorativo. "De
fisura a Dios" hoy es un número que sube. Con esto, es una devaluación que funde
al Fisura y le viene bárbara al Fondo Buitre, en la misma pantalla y al mismo
tiempo. El comentario social que el juego hace con los nombres pasa a hacerlo
también con el comportamiento.

**2. Convierte los eventos de aviso en momento.** Hoy un evento es un banner y un
multiplicador: información. Los eventos son el sistema de contenido más denso que
tiene el juego —ocho piezas de escritura buenas, cada ~15 min— y se consumen
leyendo un cartel. Con reacciones, el evento *pasa* en el campo.

**3. Cierra un hueco del propio criterio del proyecto.** `feedback-matrix.md`
pide que ninguna acción sea silenciosa. El campo es el único lugar de la app que
hoy no se entera de los eventos.

**4. Es un multiplicador de contenido, no contenido nuevo.** No hay que escribir
ni dibujar nada: hace trabajar más a los 44 nombres y las 8 piezas de flavor que
ya están escritas y pagadas. 352 relaciones nuevas a partir de cero contenido
nuevo.

**5. Screenshots.** `content-strings.md` fija el criterio: *"cada flavor tiene
que dar ganas de screenshotear"*. Un banner no se screenshotea. Diez personajes
reaccionando distinto al mismo desastre, sí. Y hay una share card ya cableada.

**6. Escala sola.** Agregás un evento o un tier y hereda su comportamiento
regenerando la tabla. No hay if-else que crezca.

**7. Y lo que valida más allá de sí misma:** si 352 celdas revisadas te hacen
sonreír, quedó demostrado que el grafo semántico del contenido —las ~6.700
relaciones de `evaluacion-laya.md` §4— es real y da juego. Entonces siguen el
grafo social (A1) y la afinidad de pintas (A3), que son más caras. **Si te
aburre, cerraste la tesis entera por el precio de dos días.** Es el experimento
barato que compra información sobre una apuesta grande.

## 8. Qué NO agrega — para no venderlo de más

- **No toca la economía.** Ni un decimal. Es a propósito: `balance-sim` tiene que
  seguir prediciendo el juego real.
- **No monetiza.** Es game feel, no conversión.
- **No es medible.** Sin analytics —decisión correcta del proyecto— no vas a
  poder demostrar que subió la retención. El criterio de éxito honesto es: lo
  mirás en el simulador y te causa gracia, o no.
- **Puede leerse como ruido si la tabla queda habladora.** Es el riesgo real y
  tiene tres frenos: `indiferente` como default, el umbral de confianza en 0,6, y
  el test que limita reactores por evento.

## 9. Y el motor cuál es

**Para las 352 celdas, un LLM en batch.** Es una sola pasada, el costo es de
centavos y llegás al resultado en una tarde, sin dataset de fine-tuning ni
entrenamiento (ver `evaluacion-laya.md` §9).

Se escribe detrás de una interfaz `Judge` de un método
—`decide(state, question, options) -> (option, confidence)`— para que el
generador sea intercambiable. LAYA y Jev hablan la misma API, así que cambiar de
motor después es una variable de entorno, no una reescritura. **Y la decisión de
motor es reversible gratis, porque lo que llega al juego es un JSON revisado a
mano: si mañana regenerás la tabla con otro modelo, el juego no se entera.**
