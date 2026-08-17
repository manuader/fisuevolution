# Cola de celebraciones — Diseño

> Fecha: 2026-08-06. Pedido del dueño, aprobado en conversación antes de escribir
> código.

## Problema

**1. El reveal del personaje nuevo se dibuja debajo del HUD y no se lee.** Medido
en iPhone 16 Pro: el `¡NUEVO!` cae a 157 pt del borde superior y la pill de piso
—una cápsula crema **opaca** de SwiftUI— termina en ~162. El `SpriteView` está en
el fondo del `ZStack` de `GameBoardView`, así que **todo lo de SpriteKit queda
debajo de todo lo de SwiftUI, siempre**. Encima, el reveal oscurece el tablero al
72% desde adentro de la escena mientras el HUD sigue a full brillo: la
composición se ve rota aunque no hubiera texto tapado.

**2. Las celebraciones se pisan.** Hoy existe una cadena secuencial hecha a mano
para **un solo** camino —el ascenso que abre piso (`celebrationsDidFinish`)— con
tres campos `pending*` en `GameState`. Todo lo demás dispara cuando quiere: si
mientras corre un reveal se desbloquea un logro, cae un special o vence el
premio diario, se superponen.

## Alcance

Entra en la cola **todo lo que aparece solo**. Quedan afuera las pantallas que
abre el jugador (tienda, mejoras, ficha, menú) y la reencarnación, que sale de un
botón.

| Prioridad | Ítem (`CelebrationKind`) | Libera la cola cuando | Tope |
|---|---|---|---|
| 1 | `offlineEarnings` | lo cierra el jugador | — |
| 1 | `dailyReward` | lo cierra el jugador | — |
| 2 | `careerChoice` | el jugador elige | — |
| 3 | `boardCelebration` (vuelo + reveal + piso nuevo) | termina la cadena de escena | 8 s |
| 4 | `skinAward` | lo cierra el jugador | — |
| 4 | `specialDrop` | lo cierra el jugador | — |
| 5 | `eventBanner` | se va solo | 6 s |
| 6 | `achievements` | se vacía la sub-cola de toasts | 30 s |
| 6 | `towerNotice` | se va solo o lo toca el jugador | 4 s |

Prioridad 1 primero porque son de arranque de sesión: cobrás y seguís. La carrera
va antes que las celebraciones porque **bloquea la progresión**: hasta que elegís,
los merges de ese tier no se resuelven. Dentro de la misma prioridad, orden de
llegada (estable).

### El vuelo del ascenso no se separa de su reveal

El vuelo, el reveal y la celebración de piso son **un solo ítem**, encadenados
internamente como ya lo están hoy. Es lo que el dueño pidió ("que el vuelo también
espere su turno") y además es lo correcto: `layoutBoard()` ya corre ANTES del
vuelo (`BoardScene.swift:592`), así que lo que vuela es un clon desde una
coordenada capturada y el tablero ya está reacomodado. El vuelo nunca estuvo
atado al estado; separarlo de su reveal sólo lo dejaría huérfano.

Dos consecuencias asumidas:

- Si la cola estaba ocupada, el clon vuela desde donde el personaje ya no está.
  Se lee como repetición, no como error.
- Si el jugador navega de piso mientras el ítem espera, la coordenada capturada
  queda vieja: **se descarta el vuelo y se pasa directo al reveal**.

### Los logros ocupan un casillero, no tres

Ya existe `pendingAchievementToasts`, y su decisión está documentada: un piso
nuevo puede cerrar tres logros de un saque y cada uno se muestra **con su
título**, porque agruparlos haría que el jugador no se entere de dos de ellos.
Eso se respeta. Lo que cambia es que la sub-cola entera ocupa **un** casillero de
la cola global: los logros no se interleavean con el reveal ni con el diario, y
recién cuando el último toast se va se libera el turno.

## Arquitectura

### `CelebrationQueue` (EconomyKit, puro)

Opera sobre identificadores sin payload: no toca UI, cumple la regla de capas del
proyecto y se testea en milisegundos en vez de con `xcodebuild`.

```swift
public enum CelebrationKind: String, CaseIterable, Hashable, Sendable { … }

public struct CelebrationQueue: Sendable {
    public private(set) var current: CelebrationKind?
    /// Segundos que lleva el ítem actual en pantalla.
    public private(set) var elapsed: TimeInterval

    public mutating func enqueue(_ kind: CelebrationKind)
    public mutating func finish(_ kind: CelebrationKind)   // idempotente
    /// `true` si el tap salteó algo (el llamador no tiene que consultar antes).
    public mutating func skip() -> Bool
    /// Devuelve el ítem que el watchdog destrabó, para loguearlo.
    public mutating func tick(_ delta: TimeInterval) -> CelebrationKind?
}
```

- **`enqueue` deduplica**: encolar `.achievements` tres veces deja una entrada.
- **`finish` es idempotente y tolera el ítem equivocado**: la carrera entre el
  completion de la animación, el tap y el watchdog no puede romper nada. Si el
  kind no es el actual, se lo saca de los pendientes.
- **`skip` sólo actúa sobre los salteables** y respeta el piso de tiempo.

### `GameState`

- Guarda la cola y publica **una** proyección nueva: `showing: CelebrationKind?`.
- Los payloads **no se mueven**: `skinAward`, `dailyClaim`, `achievementToast` y
  compañía se siguen asignando donde se asignan hoy. Lo que cambia es que se
  **muestran sólo en su turno**.
- `celebrate(_:)` encola; `celebrationFinished(_:)` libera.
- El watchdog descuenta dentro de `tick(delta:)`, que `BoardScene.update` ya
  llama cada frame: **sin `Timer`** (regla 2 de concurrencia) y con tests que
  inyectan deltas en vez de esperar segundos reales.
- `celebrationDimsHUD: Bool` — true sólo durante `boardCelebration`.

### Vistas

Un gate de una línea por superficie:

```swift
.sheet(item: Binding(
    get: { gameState.showing == .skinAward ? gameState.skinAward : nil }, …))
```

### `BoardScene`

Sus animaciones dejan de dispararse en el instante del merge: capturan sus
parámetros, encolan `.boardCelebration`, y `update` —que ya corre cada frame— las
lanza cuando les toca. Al terminar llaman `celebrationFinished(.boardCelebration)`.

## Cancelar con un tap

Un tap en el tablero saltea el ítem actual **entero** (en el ascenso: vuelo,
reveal y piso nuevo de una), siempre que:

1. El ítem sea **salteable**: `boardCelebration`, `eventBanner`, `achievements`,
   `towerNotice`. Los sheets no se saltean con un tap al vacío; tienen su botón.
2. Hayan pasado **0,6 s** desde que empezó.

El tap **sigue contando como tap de juego**: es el verbo principal del juego y
consumirlo se sentiría como un tap perdido.

El piso de 0,6 s existe porque sin él las celebraciones no se llegarían a ver: el
jugador tapea varias veces por segundo, así que el siguiente tap mataría el reveal
a los 0,3 s, la cola avanzaría y el próximo tap mataría al siguiente. La cola se
vaciaría en un segundo y el problema volvería, pero peor.

⚠️ Con Reduce Motion las duraciones colapsan, así que el piso sería más largo que
la animación. El piso efectivo es `min(0,6 s, lo que dure el ítem)`.

## El foco visual

**El HUD se atenúa al 20% sólo durante `boardCelebration`**, con fade de 0,25 s
para que no sea un corte. Un toast de logro de 4 s no justifica apagar el HUD
entero, y los sheets ya cubren la pantalla.

**El texto del reveal se ancla debajo de la banda del HUD**, no en una fracción
del alto. Poner ratios nuevos a ojo repite el bug en otra pantalla: en un iPhone
SE la misma banda se come una fracción mucho mayor del alto. `BoardScene.topInset`
ya existe **y no lo usa nadie** —era para esto—: se mide el alto real del HUD en
el simulador, se corrige esa constante y el bloque del reveal se ancla ahí.

## Qué se testea

**EconomyKit** (rápido): orden por prioridad; empates por orden de llegada;
deduplicación; `finish` idempotente y con el kind equivocado; el watchdog
descontando por delta; `skip` respetando el piso de tiempo y no tocando los no
salteables.

**Wiring de la app**: dos celebraciones simultáneas salen de a una; la cola
**nunca apunta a una superficie sin payload** —es el contra conocido de guardar
sólo el turno y se pinea acá—; el ascenso libera la cola; los logros liberan
recién con el último toast.

**Regresión del bug reportado**: el bloque del reveal queda por debajo de la banda
del HUD en todos los tamaños de pantalla. Numérico, como `CrowdDepthTests`.

**Visual en el simulador**: capturas del reveal con el HUD atenuado y del caso de
dos celebraciones encoladas.

## Deuda que este cambio toca de frente

`AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent` está roto
desde el cambio de la franja de la multitud y su arreglo quedó sin decidir. Este
trabajo recorre exactamente ese camino, así que **exponer los nodos del tablero
como elementos accesibles** (`board.slot.N`) —la opción durable de aquella
decisión— entra acá: el test deja de calcular coordenadas y arrastra elementos
reales, lo que además cierra el hueco de VoiceOver sobre el tablero que el
handoff tiene anotado como pendiente.

## Fuera de alcance

- Las pantallas que abre el jugador y la reencarnación.
- Persistir la cola entre arranques: lo que quedó pendiente se vuelve a derivar
  del estado en el próximo bootstrap (el diario y los logros ya funcionan así).
- Rediseñar ninguna celebración. Se cambia **cuándo** se muestran y dónde cae el
  texto del reveal, no cómo se ven.
