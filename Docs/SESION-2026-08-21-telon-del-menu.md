# Sesión 2026-08-21 — El telón blanco de las pestañas del menú

## Qué se pidió

Las pestañas de adentro del menú (Organigrama, Estadísticas, Logros, Ajustes)
se veían "con fondo blanco, sin el png"; el pedido fue que se vean como el
fondo de las demás cards y menúes.

## El diagnóstico, medido

El panel de esas pantallas estaba BIEN: mismo marco de madera vectorial y
pergamino v3 que todas las hojas. Lo distinto era el **telón** — lo que se ve
por detrás y por debajo del panel, en la franja que la hoja contenida deja a la
vista al respetar la safe area de abajo.

Se midió sobre capturas del simulador (columna x=5, filas 2448/2472/2526 de un
16 Pro):

| Pantalla | Píxeles de la franja |
|---|---|
| FisuJobs (hoja raíz) | (74,62,48), (0,0,0), (0,0,0) — el juego atenuado |
| Menú raíz | idéntico a FisuJobs |
| Organigrama (empujada) | (205,193,179), (224,224,224), **(240,240,240)** — blanco |

La causa: las hojas flotan sobre el juego porque se presentan con
`.presentationBackground(.clear)`, pero al **empujar** un destino en el
`NavigationStack`, UIKit le pinta `systemBackground` al hosting controller de
la vista empujada — y ese blanco tapa al juego. Las cinco pantallas empujadas
(las cuatro del menú y los legales desde Ajustes) eran las únicas de la app
que no flotaban.

## El arreglo

`clearNavigationBackdrop()` en `PanelFrames.swift`, aplicado al contenido de
los DOS `navigationDestination` (el switch de `MenuView` y los legales de
`SettingsView`):

- **iOS 18**: `containerBackground(.clear, for: .navigation)` — la API dice
  exactamente esto. El placement `.navigation` es **iOS 18+** (verificado en la
  swiftinterface del SDK, no en docs de terceros).
- **iOS 17** (target del proyecto): el placement no existe, así que una sonda
  `UIViewRepresentable` sube por la cadena de responders hasta el PRIMER view
  controller —el hosting del destino, dueño del `systemBackground`— y le limpia
  el fondo. No sigue más arriba: el navigation controller y la hoja ya son
  transparentes.

### Qué se descartó

- **Presentar las cuatro como hojas nuevas**: ya lo descartó el dueño en el
  diseño del menú ("una hoja sobre otra hoja apila dos marcos").
- **Swapear contenido adentro de un panel fijo**: rompe la pila restaurable,
  el chevron de atrás y los identifiers que los UI tests pinean.

## Verificación

- Build verde con `-warnings-as-errors` y Swift 6 estricto.
- Píxeles post-fix de Organigrama, Ajustes y Privacy policy (segundo nivel de
  push): **idénticos a FisuJobs** — (74,62,48), (0,0,0), (0,0,0).
- `MenuUITests` completo en simulador propio por UDID.
- ⚠️ **El camino de iOS 17 quedó SIN verificar**: la máquina sólo tiene el
  runtime 18.6. Es el patrón conocido de limpiar el fondo del hosting
  controller, pero nadie lo vio andar acá. Si se instala un runtime 17, correr
  el smoke de menú ahí.
