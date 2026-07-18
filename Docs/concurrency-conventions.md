# Convenciones de concurrencia (Swift 6, strict concurrency = complete)

Fijadas en F0; valen para todas las fases. El proyecto compila con
`SWIFT_STRICT_CONCURRENCY = complete` y warnings-as-errors, así que estos
patrones no son sugerencias: son lo que compila.

## Regla 1 — El mundo del juego es MainActor

`GameState` es `@Observable @MainActor`. `SKNode`/`SKScene` heredan de
`UIResponder`, que ya es `@MainActor`, así que la escena accede a `GameState`
directo, sin hops.

## Regla 2 — Nada de `Timer` para trabajo del frame loop

`Timer.scheduledTimer(withTimeInterval:repeats:block:)` toma un closure
`@Sendable`: capturar `GameState` ahí es error de compilación. El flush del HUD
(8 Hz, F2) se hace **contando frames dentro de `BoardScene.update(_:)`**, que ya
es MainActor. Mismo criterio para cualquier trabajo periódico ligado al juego.

## Regla 3 — Callbacks legacy no anotados

`SKTextureAtlas.preload(completionHandler:)`, handlers de `CHHapticEngine`
(`resetHandler`/`stoppedHandler`) y similares llegan en colas arbitrarias sin
anotación. Patrón: rebotar con `Task { @MainActor in ... }`, o
`MainActor.assumeIsolated {}` SOLO si la API documenta que llama en main.

## Regla 4 — CoreData encapsulado, sin subclases generadas

`PersistenceController` es un **actor** con el modelo construido en código
(sin `.xcdatamodeld`, codegen none). Todo acceso pasa por
`context.performAndWait {}` dentro del actor; los `NSManagedObject` (no
Sendable) jamás salen de ese closure. Lo único que cruza fronteras es el
`PlayerState` Codable (`Sendable`) de EconomyKit.

## Regla 5 — El motor es puro

Todo lo de `Packages/EconomyKit` es `Sendable`, sin UIKit/SpriteKit, funciones
puras con clock/RNG inyectables. Si una pieza de lógica necesita un tipo de UI,
está en la capa equivocada.

## Regla 6 — La escena se crea una sola vez

`BoardScene` vive en `@State` de `GameBoardView`. Nunca construir la escena en
el `body` (cada invalidación del HUD la recrearía y resetearía el board).
