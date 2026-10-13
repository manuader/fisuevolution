# Sesión 2026-10-13 — relevo 52: la ola 3 de E14, primera mitad (T11, T12)

Relevo automático (rutina `fisu-v2-relevo-a`, 12:03 -03) con la cuota semanal en 94 % → 95 %: ola de dos, sonnet,
y cierre sin despachar más. La máquina pasó la mayor parte del relevo con carga 200–800 por otra sesión del dueño.

## Qué entró

| Tarea | Commit / merge | Qué |
|---|---|---|
| E14 T12 (C12, C18, M1) | `1cd27f03` → `58040d72` | `GameTabBar` reparte el ancho (Contratar ×1,4), plato al 80 % de la celda, leyendas visibles, 1–7 pestañas. Contratar y Reencarnar dejan la franja y pasan a ser solapas de la barra (`UI/HUD/BarFlaps.swift`). La pila de abajo pasa de 156 a 112 pt: el tablero gana 44 pt (`BoardScene.bottomInset` 98→108, leído de `GameTabBar.panelHeight`). |
| E14 T11 (C15, M3, M7b) | `2daee5d1`+`c43356a7` → `f932463e` | Las 10 hojas con detents pasan a `.gamePopup` (centradas, alto máximo, scroll interno), presentadas desde un único `ViewModifier` (`UI/Popups/GamePopups.swift`). Botones `GameButton`. Cartas del vendedor en una fila. «No, gracias» al vendedor → `npc_vendedor_enojado`, una de 3 frases y «Chau»; `declineVisit()` al cerrar. |

Progreso: **283 de 306 (92,5 %)**.

## Decisiones y trampas

- **Con la semanal en 94 % alcanza para una ola de dos sonnet** (cada una ~0,5 %). Al llegar a 95 % no se despacha más, aunque la puerta sea «≥ 95 % al llegar».
- **T11 y T12 tocaron `RootView` en regiones distintas** (cadena de hojas vs. `bottomBar`) y el merge salió limpio: el reparto «Dueño de» por región de `RootView` funciona.
- **Los popups son overlay de `GameBoardView`:** uno que aparece mientras el menú u otra hoja está abierta queda debajo. La cola de celebraciones lo evita en la práctica; vigilarlo en T13/T14.
- **`ViewThatFits` en `PopupContainer` recrea el contenido** al pasar de scroll a sin scroll y se pierde el `@State` de los botones de video (ya en el doc del componente).

## Carries (en las filas de `tasks.md`)

- T12: `QuickHireUITests` no concluyente por la carga (el mantener-presionado → picker sin validar por UI); `MenuPagerUITests.testConAjustesAbiertoElMenuNoSeDesliza` rojo bajo carga, sin comparar con la base; sin captura de iPad, 7 pestañas ni Reencarnar visible; Dynamic Type grande sin medir; el comentario de `BoardScene.bottomInset` dice 64/84; revisar el ancla `.bottomBar` del tutorial (ahora 112 pt).
- T11: claves crudas hasta T26; «Doble…» del offline se trunca en SE; `NotificationPermissionCard`, `OddsDisclosureView` y `StateBadge` siguen con SF Symbols (→ T25); capturas previas a `c43356a7`.

## Oráculo

`rapido` de `f932463e` (el código es la punta): **VERDE** — EK 901, unit 1828 · 0 rojos, Release 0 warnings. Las clases UI de la barra y los popups corrieron en las tareas (ver carries); el `completo` toca al cerrar la ola 3.

## Lo próximo

Resto de la ola 3: **T21** (menú deslizable de un solo marco) y **T22** (la torre por las ventanas del ascensor). Al cerrarla, el `completo`. Después la ola 4: T13 · T17 · T19.
