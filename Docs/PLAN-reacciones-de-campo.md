# Plan — Reacciones de campo

_Escrito el 2026-09-28. Implementa `Docs/PROMPT-reacciones-de-campo.md`._

## Contexto

Cuando cae un evento, los personajes del campo reaccionan según quiénes son: la
Devaluación funde al Fisura y le viene bárbara al Fondo Buitre. Es una tabla de
**352 celdas** (44 tipos × 8 eventos), generada fuera del juego, revisada a mano
y congelada en JSON. El runtime sólo la lee: no hay modelo en el `.ipa`, no hay
red, no se toca la economía ni el save.

## Hallazgos del planeamiento (lo que el spec no sabía)

1. **Son 44 tipos, no 37.** `tiers.json` creció (`ESTADO.md` quedó viejo). 352
   celdas. El spec ya está corregido.
2. **Bug latente en la cola de celebraciones — y rompe esta feature.**
   `announcedEventID` guarda el *id* del evento y nunca se limpia. Si la misma
   Devaluación cae dos veces seguidas (es el evento de más peso, 16), la segunda
   **no pasa por la cola**: `eventBannerIsVisible` da `true` al instante porque el
   id coincide, y el banner aparece sin arbitraje, pudiendo pisar un reveal. Para
   esta feature es peor: el disparador es el turno del banner, así que la segunda
   Devaluación **no reaccionaría**. Se arregla primero (F1), en su propio commit,
   porque vale aunque la feature no entre.
3. **`CharacterNodePool.obtain()` no limpia el sprite.** Hace
   `node.removeAllActions()`, que no alcanza a las acciones de los hijos. Un nodo
   reciclado a mitad de un emote volvería con el emote corriendo sobre *otro*
   personaje. Es el mismo bug que el comentario del pool ya documenta para el
   espejado ("sin esta línea sobreviviría al reciclado"), del otro lado.
4. **`node.position` alimenta a `MergeTargeting`** (`BoardScene.swift:889`, 921,
   959). Un emote que mueva el nodo corre, aunque sea un instante, el blanco del
   merge. Por eso los emotes van en el sprite.
5. **No hay forma de forzar un evento en DEBUG.** Sin eso, verificar cada uno
   cuesta ~15 min de espera. Se agrega (F4).
6. **Los tres eventos instantáneos sí generan banner** (`endsAt = now + 6`,
   `ContentSystems.swift`), así que el disparador por banner cubre los 8.
7. **Los specials no son `CharacterNode`**: son `SKSpriteNode` sueltos que
   `renderAnchoredSpecials` destruye y recrea en cada render. Quedan fuera de v1.

## Decisiones (⚠️ = default mío, confirmable)

1. **Disparador: el turno del banner en la cola** (`showing == .eventBanner`), no
   el cambio de `activeEvent`. Sincroniza la reacción con el cartel, la arbitra
   gratis contra reveals y cofres, y durante la fase obligatoria del tutorial no
   pasa nada solo (la cola ya está restringida a `.boardCelebration`).
2. **Identidad por disparo, no por id**: se compara el `ActiveEvent` entero
   (incluye `endsAt`, distinto en cada disparo). Aplica al fix de F1 y a la escena.
3. **Una vez por disparo, en el piso a la vista.** Cambiar de piso durante el
   evento no re-dispara. ⚠️
4. **Emotes sólo en el sprite, y sólo por canales seguros:** `yScale`,
   `zRotation`, `alpha` y un desplazamiento vertical simétrico. **Nunca**
   `node.position` (hallazgo 4) ni `sprite.xScale` (codifica hacia dónde mira;
   un `scale(to:)` ahí lo pisa). El rebote del tap escribe la escala del *nodo*,
   así que compone sin chocar.
5. **Umbral (confianza < 0,6 → `indiferente`) y revisión se aplican al generar.**
   El JSON commiteado es lo que se shippea. En runtime queda un tope de 4
   reactores por evento como red de seguridad.
6. **Feature flag `eventReactionsEnabled`** en `feature_flags.json`, como GC y
   CloudKit: si algo se ve mal en TestFlight se apaga sin tocar código.
7. **Generador en dos mitades deterministas con el juicio en el medio.**
   Extracción y post-proceso en Python stdlib (precedente: `gemini_batch.py`,
   `audio-synth`). El juicio entre ambos es intercambiable; en v1 lo escribe
   Claude en sesión leyendo `inputs.jsonl` — sin API key, sin dependencia nueva.
   Si el pipeline se vuelve frecuente, entra un `Judge` programático (ver
   `evaluacion-laya.md` §9).
8. **Dónde vive la lógica: EconomyKit.** Modelo, validación y planner son puros y
   se testean con `swift test` en segundos, como manda `ESTADO.md`. La escena
   sólo ejecuta.
9. ⚠️ **¿1.0.0 o 1.1?** Recomiendo desarrollarla ya en rama y **mergearla a la
   1.0.0 sólo si está verificada antes de que el submit esté listo**. No toca
   save, economía ni schema, y tiene flag: el riesgo es bajo. Si no llega, 1.1.
   **Decide el dueño.**

## Arquitectura

### EconomyKit (puro) — `Sources/EconomyKit/EventReactions.swift`

```swift
public enum Emote: String, Codable, CaseIterable, Sendable {
    case festeja, seAgarraLaCabeza = "se_agarra_la_cabeza",
         seEncogeDeHombros = "se_encoge_de_hombros",
         sonrisaTorcida = "sonrisa_torcida", seEsconde = "se_esconde", indiferente
}

public struct EventReactionsConfig: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let reactions: [String: [String: Emote]]   // eventId → typeId → emote
    /// Cobertura exacta en los dos sentidos: todo evento × todo tipo presente,
    /// nada sobrante. Tira error tipado con el primer hueco.
    public func validate(eventIDs: Set<String>, typeIDs: Set<String>) throws
}

public enum EventReactionPlanner {
    public struct Reaction: Equatable, Sendable { let slot: Int; let emote: Emote; let delay: TimeInterval }
    /// Filtra `indiferente`, saca `excluded`, ordena determinista por slot, corta
    /// en `cap`, y escalona 0–0,45 s por hash del slot (que se lea como una
    /// multitud reaccionando, no como una coreografía).
    public static func plan(eventID: String, onField: [(slot: Int, typeId: String)],
                            excluded: Set<Int>, config: EventReactionsConfig,
                            cap: Int = 4) -> [Reaction]
}
```

### App

- **`GameContentLoader`**: `eventReactions` como contenido #18. Decode +
  `validate` contra los ids de `events.json` y `tiers.json` →
  `GameError.contentInvalid`. Es el anti-drift en el load, igual que hoy los
  pisos contra el manifest: si alguien agrega un evento o un tier sin regenerar
  la tabla, Debug assertea al arrancar.
- **`FeatureFlags`**: `eventReactionsEnabled`, con `decodeIfPresent` y default
  `true`, para que un `feature_flags.json` sin la clave no rompa.
- **`CharacterNode`**: `playEmote(_:delay:completion:)` corre sobre el sprite con
  clave `"emote"`; `cancelEmote()` saca esa acción y restaura `yScale =
  |xScale|`, `zRotation = 0`, `alpha = 1` y la posición de reposo del sprite.
- **`CharacterNodePool.obtain()`**: llama a `cancelEmote()` (hallazgo 3). Va en
  `obtain` y no en `recycle` por la misma re-entrancia que el comentario ya
  explica para el vuelo del ascenso.
- **`BoardScene`**:
  - `reactedEvent: EventManager.ActiveEvent?` y `updateEventReactions()` al final
    de `update()`, al lado de las cuatro llamadas que ya están.
  - Guardas: flag, `!prefersReducedMotion` (el mismo que usa `startWander`),
    `!boardCelebrationRunning`, `showing == .eventBanner`,
    `activeEvent != reactedEvent`. Asigna `reactedEvent` **antes** de actuar.
  - Excluidos: `dragNode`, `mergeCandidates`, `spotlitNode`.
  - Por reacción: saca `"wander"`, `playEmote`, y al terminar
    `resumeWanderIfFree(slot:node:)`.
  - **Refactor chico:** esa guarda (no es el arrastrado, no es candidato, no tiene
    ya paseo) hoy vive adentro de `releaseSpotlitNode`. Se extrae a
    `resumeWanderIfFree` y la usan los dos. Así no hay dos copias que diverjan.
  - Agarrar un nodo en `touchesBegan` → `cancelEmote()`.
- **`GameState+Celebrations`** (F1): `announcedEventID: String?` →
  `announcedEvent: EventManager.ActiveEvent?`, comparando el valor entero.
- **`GameState+Debug` + `DebugPanelView`**: `debugFireEvent(id:)` y un selector
  con los 8 eventos. Sólo DEBUG. Lo usan la verificación manual y los tests.

### Tooling — `Tools/event-reactions/`

| Archivo | Qué hace |
|---|---|
| `extract.py` | `tiers.json` + `events.json` + `Localizable.xcstrings` → `state/inputs.jsonl`: 352 líneas en orden estable, cada una con `{event, type, personaje, escalon, evento, flavor_es, flavor_en, es_buff}` |
| `state/decisions.jsonl` | el juicio: `{event, type, emote, confidence}`. En v1 lo escribe Claude en sesión |
| `build.py` | aplica el umbral → `FisuEvolution/Resources/Data/event_reactions.json` + `state/review.md` (ordenado por confianza ascendente, más reactores por evento sobre el campo típico) |
| `build.py --check` | exit ≠ 0 si el JSON no corresponde a `inputs.jsonl` actual. Enchufable al workflow de CI |

`inputs.jsonl` y `decisions.jsonl` se commitean: la tabla se reconstruye sin
volver a juzgar.

## Fases

Rama `feat/reacciones-de-campo` desde `main`. **Stage siempre por path**: el
working tree tiene cambios sin commitear del dueño en `Distribution/` y
`project.yml` (el submit en vuelo) que no se tocan ni se incluyen. No hace falta
tocar `project.yml`: XcodeGen toma los archivos nuevos por carpeta y EconomyKit
es SPM.

Cada fase: build verde con warnings-as-errors + tests + commit.

### F0 — Docs · 15 min
Commit de `evaluacion-jev.md`, `evaluacion-laya.md`, `PROMPT-reacciones-de-campo.md`
y este plan.

### F1 — Fix de la cola de celebraciones · 1 h
- `announcedEvent` por valor (decisión 2).
- Test de regresión en `CelebrationWiringTests`: la misma Devaluación dos veces,
  con la primera terminada, pasa **dos** veces por `.eventBanner`.
- `fix(celebraciones): un evento repetido vuelve a pedir turno`.
- Independiente de la feature: se mergea aunque lo demás no entre.

### F2 — EconomyKit · medio día
- `EventReactions.swift` + `EventReactionsTests`: decode; cobertura faltante y
  sobrante rechazadas; emote desconocido rechazado; el planner filtra
  `indiferente`, respeta exclusiones, corta en el tope, es determinista y
  escalona dentro de 0–0,45 s; tabla vacía → nada.
- `swift test --package-path Packages/EconomyKit` verde.

### F3 — La tabla · media tarde + revisión del dueño
- `extract.py`, juicio de las 352 celdas, `build.py`.
- **[DUEÑO]** leer `review.md`: las ~30 más dudosas y un spot-check. 30 minutos.
- **No bloquea F4/F5**: corregir la tabla después es editar el JSON y correr
  `build.py --check`. Misma regla que el manifest de arte: el ajuste de contenido
  nunca toca código.

### F4 — App: carga, flag, emotes, pool, debug · 1 día
- Loader, flag, `playEmote`/`cancelEmote`, pool, `debugFireEvent`.
- Los 6 emotes con duración total ≤ 1,6 s; `indiferente` no tiene animación.
- Tests: `GameContentValidationTests` (el JSON real cubre los eventos y tipos
  reales — el anti-drift); `CharacterNodePoolTests` (nodo reciclado a mitad de
  emote vuelve sin acción, con `yScale`, `zRotation` y `alpha` de reposo y
  mirando a la derecha); flags sin la clave → `true`.

### F5 — Escena · medio día
- `updateEventReactions`, `resumeWanderIfFree`, cancelación al agarrar.
- Tests nuevos en `EventReactionsWiringTests`, con `reduceMotionOverride` y
  `debugFireEvent`:
  - reacciona una sola vez por disparo;
  - dos disparos seguidos del mismo evento → dos reacciones (depende de F1);
  - flag apagado o Reduce Motion → nada;
  - el nodo arrastrado no reacciona;
  - con `boardCelebrationRunning` → nada;
  - **invariante del merge**: `node.position`, `cellIndex` y el resultado de
    `MergeTargeting` son idénticos antes, durante y después de un emote.
- Verificación en el simulador **CI iPhone**: forzar los 8 eventos desde el panel,
  un screenshot por evento a `Docs/reacciones-<evento>.png`.

### F6 — Afinación y cierre · 2 h
- **[DUEÑO]** mirar los 8 eventos en el simulador y ajustar duraciones y
  escalonado a ojo.
- Actualizar `ESTADO.md`, `tasks.md` y `feedback-matrix.md` (la fila "Evento
  (inicio)" suma la reacción del campo).
- Decidir 1.0.0 o 1.1 (decisión 9) y mergear o esperar.

**Total: ~3 días de trabajo + ~1 h del dueño** (revisión de la tabla y afinación).

## Criterios de aceptación (por comando)

```bash
swift test --package-path Packages/EconomyKit
xcodebuild ... -derivedDataPath build-ci test -parallel-testing-enabled NO
xcodebuild ... build 2>&1 | grep -cE " warning:"     # == 0
python3 Tools/event-reactions/build.py --check        # exit 0
```

Más: 8 screenshots en `Docs/`, y con el flag apagado el juego se comporta
idéntico a `main` (lo cubre un test de F5).

## Fuera de alcance de v1

- **Specials reaccionando** (hallazgo 7). Es la v1.1 obvia y la más graciosa —el
  Demonio de ARCA ante el Blanqueo—, pero obliga a darles a los specials un
  camino de render persistente. 80 celdas más.
- Reacciones a otras cosas (merges, compras, prestigio): otra tabla.
- SFX por emote: `sfx_event` ya suena, y diez sonidos serían el ruido que
  `indiferente` existe para evitar.
- Re-disparar al cambiar de piso (decisión 3).
- El grafo social (A1 de `evaluacion-laya.md`), que se decide después de ver esto.

## Qué necesita el dueño

1. **Decidir 1.0.0 o 1.1** (decisión 9). Recomendación: rama ya, mergear sólo
   si llega verificada antes del submit.
2. **30 min** para leer `review.md` (F3).
3. **Mirar los 8 eventos** en el simulador y decir si causa gracia (F6). Sin
   analytics, ése es el criterio de éxito.
