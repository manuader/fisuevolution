# Sesión 2026-08-17 — Las celebraciones se reproducen de a una

Spec: `Docs/superpowers/specs/2026-08-06-cola-de-celebraciones-design.md`.

## Qué se pidió

Dos cosas, que resultaron ser la misma:

1. **El reveal del personaje nuevo se ve por debajo de la UI y no se lee el texto.**
2. **Las animaciones se superponen** — te llega un logro encima del reveal y queda
   feo. Cada animación tiene que reproducirse por separado, **una por una, como
   regla general para toda la app**.

## La causa del texto tapado (medida, no estimada)

En iPhone 16 Pro: el `¡NUEVO!` caía a **157 pt** del borde superior y la pill de
piso —una cápsula crema **opaca** de SwiftUI— termina en **~162**. El `SpriteView`
está en el fondo del `ZStack` de `GameBoardView`, así que **todo lo de SpriteKit
queda debajo de todo lo de SwiftUI, siempre**. Un scrim de SwiftUI tampoco servía:
oscurecería también el reveal.

Encima, el reveal apaga el tablero al 72% desde adentro de la escena mientras el
HUD sigue a full brillo: la composición se veía rota aunque no hubiera texto
tapado.

## Lo que se construyó

### `CelebrationQueue` (EconomyKit, puro)

Guarda **turnos, no contenidos**: opera sobre identificadores, sin payloads ni
tipos de UI. Por eso vive en el paquete y se testea en milisegundos — pinear el
watchdog cuesta un delta inyectado en vez de 8 segundos reales.

Nueve ítems con prioridad: los de arranque de sesión primero (offline, diario),
después la elección de carrera —que **bloquea la progresión**—, después el ascenso,
los sheets de premio, y al final banners y toasts.

### `GameState` publica UNA proyección: `showing`

Los payloads **no se movieron**: `skinAward`, `dailyClaim` y compañía se siguen
asignando donde se asignaban. Lo que cambió es que se **muestran sólo en su
turno**, con un gate de una línea por superficie.

El enganche es único: `refreshProjections()` llama a `syncCelebrations()`, que
encola todo lo que tenga payload. Es idempotente por la deduplicación de la cola,
así que el modo de fallar es "se llamó de más", no "alguien se olvidó de encolar y
esa celebración no aparece nunca" — mismo criterio que `evaluateAchievements` con
`phase`.

Murió la cadena a mano (`celebrationChainActive` + dos campos `pending*`), que
cubría un solo camino.

### ⚠️ El bug que apareció implementando, y que la app tenía de verdad

La primera versión hacía que `BoardScene` encolara el ascenso al recibir el
`.merged`. **No funciona**: `handleDrop` llama por dentro a `updateMaxFloorStat()`,
que acredita la skin de milestone y pide turno — así que para cuando la escena
encolaba, la cola ya estaba ocupada con el sheet, y como no se expropia lo que
está en pantalla, el sheet tapaba el vuelo y el reveal. Exactamente el bug que
esto viene a arreglar.

Ahora **el turno lo pide `handleDrop` apenas sabe que hay algo que celebrar**,
antes de acreditar nada. La escena sigue siendo la que reproduce; sólo dejó de ser
la que pide. Lo cazó el test de wiring, no el simulador.

### Cancelar con un tap

Un tap saltea el ítem **entero** (en el ascenso: vuelo, reveal y piso nuevo de
una), si es salteable —lo que se cierra solo— y pasaron **0,6 s**.

Ese piso no es cosmético: el tap es el verbo principal del juego y el jugador
tapea varias veces por segundo, así que sin él el siguiente tap mataría el reveal
a los 0,3 s, la cola avanzaría, y el próximo mataría al que sigue. **La cola se
vaciaría en un segundo y el problema volvería, pero peor.** El tap no se consume:
también juega.

### El watchdog

Cada ítem que se cierra solo declara un tope. Si la señal de "terminé" no llega,
la cola avanza igual y deja un log.

Con una cola global el cálculo de riesgo cambia: antes un bug así perdía una skin,
ahora congelaría **todas** las celebraciones hasta reiniciar la app. El spec de la
cadena vieja ya dejaba anotado que el smoke **no detecta** ese caso, así que
confiar en el test solo era justamente lo que ya había fallado una vez.

Corre en el `tick(delta:)` que ya existe por frame: sin `Timer` (regla 2 de
concurrencia) y con tests deterministas.

### El foco visual

- **El HUD se atenúa al 20%** con fade de 0,25 s, y **sólo** durante la
  celebración a pantalla completa. Un toast de logro de 4 s no justifica apagar
  el HUD entero.
- **El reveal se acomoda dentro de la franja libre entre el HUD y la barra de
  abajo**, calculada, en vez de en fracciones del alto. Con ratios fijos el bug
  vuelve en otra pantalla: a 568 pt de alto la foto de `0.52 × alto` deja **5 pt**
  libres arriba. Ahora la foto cede y el texto entra siempre.
  - ⚠️ **Superado desde `0d3b96d`**: la UI se apaga entera durante el reveal y el
    texto va **centrado a pantalla completa**, así que ya no hay franja que
    calcular ni banda del HUD que esquivar. `BoardScene.topInset` (176) quedó sin
    uso. El párrafo de arriba queda como la historia del bug que lo motivó.
- `BoardScene.topInset` existía y **no lo usaba nadie** — era para esto. Quedó en
  176 (162 medidos + 14 de aire).

### Los logros: un casillero, no tres

Ya existía `pendingAchievementToasts` con una decisión documentada: tres logros de
un saque se muestran **de a uno con su título**, porque agruparlos haría que el
jugador no se entere de dos. Eso se respetó. Lo que cambió es que la sub-cola
entera ocupa **un** casillero de la cola global: no se interleavean con el reveal
ni con el diario, y recién el último toast libera el turno.

## Lo que NO se hizo, y por qué

Exponer los nodos del tablero como elementos accesibles estaba en el spec para
destrabar `AscentRenderingUITests`. **Ya no hacía falta**: ese test se arregló por
otra vía —doble toque con `MergeTargeting.nearestPartner` y barrido con
reintentos— así que se revirtió la sonda `board.probe` en vez de dejar dos
mecanismos para lo mismo.

## Verificación

- **EconomyKit 200/200** (+17 de la cola) · **pipeline 45/45**.
- Suites nuevas: `CelebrationQueueTests` (orden, dedupe, `finish` idempotente y
  con el kind equivocado, watchdog por delta, `skip` con piso),
  `CelebrationWiringTests` (dos a la vez salen de a una; **la cola nunca apunta a
  una superficie sin payload**, que es el riesgo conocido de guardar el turno
  aparte; lo que se cierra solo no se reencola; el HUD sólo se atenúa en la del
  tablero) y `RevealLayoutTests` (el bloque del reveal queda bajo la banda del HUD
  en seis tamaños de pantalla).

### Trampa que costó dos builds

`RootView.body` cayó en **"the compiler is unable to type-check this expression in
reasonable time"** al sumarle la atenuación: el `ZStack` ya venía al límite con
diez `.sheet` encadenados. Se arregló en dos pasos —extraer la columna del HUD a
`hudColumn`, y sacar las bindings de las hojas a propiedades con **tipo
explícito**—. Si alguien vuelve a meter lógica en esas bindings, esto reaparece.
