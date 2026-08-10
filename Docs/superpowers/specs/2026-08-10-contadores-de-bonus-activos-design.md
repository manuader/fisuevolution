# Contadores de bonus activos en el HUD

> Spec de diseño. Fecha: **2026-08-10**. Aprobado por el dueño el mismo día.
> Pedido original: *"cuando tengas un boost activado, que aparezca el contador
> en la pantalla principal (esquina superior izquierda, abajo del menú). Debe
> verse con la estética del juego y muy bien. Si hay dos boosts al mismo tiempo,
> deben aparecer los dos en simultáneo."*

---

## 1. El problema

Activás el Fernet, el panel de Bonus se cierra y **no queda ni un rastro en
pantalla de que tenés un ×3 corriendo**. Ni cuánto le falta. El único lugar
donde el efecto existe es `player.run.activeModifiers`, que no lo lee ninguna
vista.

## 2. Alcance: todo lo temporal menos los eventos

Decisión del dueño (2026-08-10). Tres cosas dejan un multiplicador corriendo y
ninguna se ve hoy:

| Origen | `sourceKey` | Ejemplos |
|---|---|---|
| Boosts | `boost.<id>` | mate (−30% contratar, 60 s), café (×2 tap, 45 s), fernet (×3 ingresos, 90 s), turbo (×5 ingresos, 30 s) |
| Videos | `rewarded.<id>` | ×2 ingresos por 120 s, ×3 por 60 s |
| Carrera | `career.<optionId>` | Abogado: contratar a −50% por 600 s |

Para el jugador son la misma cosa —"tengo un ×3 corriendo, le quedan 42 s"— y
para el código también: los tres son `ActiveModifier` con `expiresAt`.

**Los eventos (`event.*`) quedan afuera** porque ya tienen `EventBannerView`,
con su propia cuenta regresiva, y ese banner además lleva el chiste del evento y
funciona como anuncio de que algo pasó. Un chip chico no lo reemplaza.

**Los permanentes también quedan afuera**: la Milanesa sube la eficiencia
offline para siempre (`expiresAt == .infinity`) y un contador sin fin no es un
contador. El Asado no crea modificador: paga un cofre al toque.

## 3. `ActiveBonus`: qué se muestra

Archivo nuevo `Game/State/ActiveBonus.swift`, con el struct y un **constructor
puro** al estilo de `MergeTargeting`: recibe los modificadores, un catálogo
`sourceKey → (iconKey, duración total)` armado desde los configs, y el reloj.

```swift
struct ActiveBonus: Identifiable, Equatable {
    let id: UUID              // el del ActiveModifier
    let effect: ActiveModifier.Effect
    let iconKey: String?      // arte del boost; nil para video y carrera
    let effectText: String    // "×3", "−30%"
    let startedAt: TimeInterval
    let expiresAt: TimeInterval
}
```

Filtra: vivos, `expiresAt` finito, `sourceKey` que no arranque con `event.`.
Ordena **por el que vence primero**, que es el que urge.

`effectText` sale de `EffectDescriptor`, el **mismo** formateador que usa el menú
de Bonus, mapeando `ActiveModifier.Effect` a `BoostsConfig.EffectType` (los tres
casos temporales son 1:1). Así el mate dice `−30%` en los dos lados y no `×0,7`
en uno y `−30%` en el otro.

⚠️ **El struct no lleva el tiempo restante.** Lleva `startedAt` y `expiresAt`,
que son constantes. Es la decisión que hace que esto no cueste nada — ver §4.
`startedAt` sale de `expiresAt − duración total`, y la duración total no está en
el `ActiveModifier`: la resuelve el catálogo por `sourceKey`. Si un `sourceKey`
no está en el catálogo (un config editado, una fuente nueva), el chip igual se
muestra con el aro lleno; **nunca desaparece por no saber la duración**.

## 4. El costo por frame, que es donde esto se arruina

La regla del proyecto: SwiftUI **nunca** lee `PlayerState`, lee proyecciones que
`refreshProjections` publica a 8 Hz comparando antes de escribir.

Si el chip llevara "42 s" adentro, la proyección cambiaría una vez por segundo
—y el aro, ocho— invalidando SwiftUI para siempre mientras haya un boost. Con
`startedAt`/`expiresAt`, el array **sólo cambia cuando un bonus arranca o se
muere**: en una partida normal, casi nunca.

El tiempo lo maneja la vista:

- **Un solo** `Timer.publish(every: 1)` para toda la barra, con un `@State now`
  — el mismo patrón que ya usa `EventBannerView`. No uno por chip.
- El aro se interpola con `.animation(.linear(duration: 1), value: progress)`:
  tick de 1 Hz, tween de 1 s. Se ve continuo sin animación de larga duración ni
  estado por frame.
- Con Reduce Motion el tween se anula y el aro salta de a un segundo.

## 5. Cómo se ve

Columna alineada a la izquierda debajo del HUD, un chip por bonus, 6 pt entre
medio. Cápsula con el lenguaje que ya usan la píldora de la torre y el indicador
de prestigio: relleno `PaletteCream`, borde `PaletteInk` de 2, sombra suave.

```
[ ◍ arte ] ×3   0:42
```

- **Ícono**: el arte real del boost (`ui_boost_fernet` y compañía, ya están en el
  atlas UI del manifest). Video y carrera no tienen arte: glifo SF
  (`play.rectangle.fill` / `briefcase.fill`) en el mismo círculo.
- **Aro**: se vacía con el tiempo alrededor del ícono, teñido por efecto —
  `PaletteGreen` ingresos, `PaletteOrange` tap, `PaletteBlue` costo de
  contratación. **Nunca sólo color**: al lado siempre están el número y el
  tiempo, que es la misma regla que sigue `EventBannerView` para daltónicos.
- **Tiempo**: dígitos monoespaciados. `42s` abajo del minuto, `1:42` arriba.
- Entra y sale con spring + escala, para que aparecer no sea un salto.
- **`allowsHitTesting(false)`**. Es estado, no un control: no puede comerse un
  toque destinado al tablero que tiene debajo.

Va en el `VStack` de `RootView` justo después de `HUDView`, con el banner de
evento debajo.

Sin tope de cantidad: con los cooldowns reales (30 min a 2 h) tener más de dos a
la vez es raro, y cuatro chips compactos entran sin tapar nada.

## 6. Tests

**`ActiveBonusTests`** (nuevo, puro): descarta los vencidos, los permanentes y
los `event.*`; ordena por vencimiento más próximo; resuelve ícono y duración
desde el `sourceKey`; un `sourceKey` desconocido sigue dando chip; y el texto del
efecto es el mismo que muestra el menú de Bonus (`×3` y `−30%`, no `×0,7`).

**`BonusHUDUITests`** (nuevo, 2 tests):

1. Partida nueva → abrir Bonus → activar el mate (arranca desbloqueado y sin
   cooldown) → cerrar → el chip está, dice `−30%` y dice cuánto le queda. Y
   antes de activar nada **no** hay ningún chip.
2. **Dos a la vez**, que es lo que pidió el dueño: mate + el ×2 del video (el
   stub de ads tarda 2 s y siempre paga). Dos chips, de dos orígenes distintos,
   y el mate arriba porque vence primero — el orden también queda fijado en la
   app y no sólo en el modelo.

⚠️ **Dos trampas de tests de UI salieron de acá**, las dos con el mismo disfraz:
la pantalla se ve perfecta y el elemento "no existe".

a. **Un `accessibilityIdentifier` sobre un contenedor que no es elemento de
   accesibilidad se propaga y PISA el de sus hijos.** Con `hud.bonuses` en el
   `VStack`, el árbol mostraba **un solo** elemento con ese identificador y los
   chips desaparecían del test aunque en pantalla se vieran bien. Es la trampa
   9a del HANDOFF con otra cara. La barra quedó sin identificador propio.

b. **`List` es perezosa**: la fila del video vive abajo de los seis boosts y no
   existe en el árbol hasta scrollear. El test baja antes de buscarla.

Las dos se encontraron **mirando la captura**, y por eso la captura se toma
ANTES de los asserts: un assert que corta se lleva puesta la evidencia.

**No se toca EconomyKit** ni la persistencia: `ActiveModifier` queda igual, así
que no hay migración de saves.

## 7. Archivos

| Archivo | Qué pasa |
|---|---|
| `FisuEvolution/Game/State/ActiveBonus.swift` | **nuevo**: el struct y el constructor puro |
| `FisuEvolution/UI/HUD/ActiveBonusBar.swift` | **nuevo**: la barra y el chip |
| `FisuEvolutionTests/ActiveBonusTests.swift` | **nuevo** |
| `FisuEvolutionUITests/BonusHUDUITests.swift` | **nuevo** |
| `FisuEvolution/Game/State/GameState.swift` | la proyección `activeBonuses` |
| `FisuEvolution/Game/State/GameState+Bonus.swift` | el catálogo `sourceKey → (icono, duración)` |
| `FisuEvolution/App/RootView.swift` | monta la barra bajo el HUD |
| `FisuEvolution/Resources/Localizable.xcstrings` | la clave de accesibilidad |

⚠️ Cuatro archivos Swift nuevos ⇒ **`xcodegen generate` es obligatorio**.
