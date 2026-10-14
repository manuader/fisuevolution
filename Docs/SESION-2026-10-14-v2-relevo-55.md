# Sesión 2026-10-14 — relevo 55: los 6 rojos, E14 T16/T20/T24, el cofre de C26 y la E14b

Relevo automático (rutina `fisu-v2-relevo-a`, disparo de las 08:03). El dueño estuvo en vivo en el chat y, en
paralelo, su sesión «Fisu Evolution v2 roadmap» (`local_4ddbb4c3`) mandó por mensaje directo la E14b y sus
respuestas; todo quedó también en `DUENO.md`.

## Qué entró (en `v2i/integ-r54`, pusheada)

| Tarea | Commit / merge | Qué |
|---|---|---|
| E14 T16 (C10) | `3ce3d434` → `239621c5` | Caja y colchón del tablero +85 % (`sideRatio` 1,15) y apoyados en `StageLayout.standY`; x entre la columna de sellos y el visitante; toque ≥ 60 pt. |
| Los 6 rojos del `completo` de `38e86376` | `efd5b706` → `100ec72e` | `StoreUITests` en iOS 18.6: la app **abortaba en dyld** (`lib_TestingInterop.dylib`) porque el rpath de Debug de `9f7e16a2` ponía `@executable_path/Frameworks` primero y cargaba el XCTest copiado al `.app` (los tests son host de la app). Arreglo en `project.yml`: ese rpath va último. Sólo builds Debug de tests; la Release no embebe XCTest. `IAPCopyTests` y `RankingWiringTests` ×2: tests viejos frente a T7 (blue) y T23 (la card `.newCharacter(.god)` va antes que el ranking, correcto por D14). |
| Cofre con los clips de C26 | `c56d5e4e` → `d2d9c238` | `ChestOpeningView` con `cofre_espera` → `cofre_sacude` (toques 1 y 2) → `cofre_abre` (3.º); el premio arriba del cofre (`ChestStage`/`ChestClip`). Retirados `Resources/ChestAnim/` (31 archivos), `ChestAnimation*`; `ChestCinematicPlayer` queda (lo usa el ascensor). |
| E14 T20 (C29) | `b7bbad19` → `3d493d22` | Regalos por estado: hero «Para cobrar ahora», «Pronto», «Más adelante», racha al final con «?»; `GiftsAgenda` pura. |
| E14 T24 (C25) | `ff850a11` → `cccbf6f5` | Efecto `openShop` + `ShopEventPolicy` (1/sesión, 4 h entre eventos, 24 h sin comprar, nunca en el arranque ni en la 1.ª sesión) y 4 eventos (textos aprobados por el dueño); foco con aro (`ShopFocus`), sin cuenta regresiva. Pacing 45,40 h. |
| Pipeline sin `ChestAnim` | `8b3f6819` | El retiro del cofre dejó 7 rojos en la suite de Python: fuera la clase `LoIntegrado`; la sonda de alfa usa `obj_cofre_espera.mov`. 99/99. |
| E14b B1 | `4fba7bb1` → `db03489c` | `AudioManager.pauseForAd/resumeAfterAd` (idempotentes, sólo reanudan lo que sonaba) y `AdsCoordinator.presenting {}` con `defer` en los 4 formatos. |
| E14b B2 | `58c2e62f` → `af054ae3` | El duplicado: `PickupNode` dibujaba PNG + póster (misma textura) + `SKVideoNode` con alfa que encuadra distinto. Póster transparente, el PNG se apaga mientras se ve el video, `PickupNode.layerZ = 5` (debajo del campo y de los visitantes). |
| Docs E14b | `c010c399` … `6204766f` | Spec `Docs/PLAN-v2-E14b-correcciones.md` (D1–D11, B1–B15) y su sección en `tasks.md` §5. |

## E14b — en qué quedó cada tarea (para no repetir)

- **B1 ✅ integrada** (`db03489c`). Carry: en un rewarded el audio calla durante la espera de carga, no en `adWillPresent`.
- **B2 ✅ integrada** (`af054ae3`). Carry: el fantasma en vivo no se vio en el simulador (carga); verlo en el iPhone.
- **B11 NO empezada.** Brief listo: `.claude/avo/2026-10-06-fisu-v2/ola-r55/e14b-b11.md` (base: cambiar a la punta nueva).
- **B3–B10, B12–B15 sin empezar.** B13 (recompensas animadas) y B14 (cero ORO) son pedidos del dueño en el chat de
  este relevo; B15 (giros con blue gastan el cupo, 6/día en total) llegó por la sesión del dueño. El aviso del SE que
  pisa un chip ancho **se baja** (decisión del dueño) y va con B3.
- **Arte de B9 y B14 APROBADO por el dueño** (las 11): `automatic-image-generation/projects/fisu-v2-blue/output/assets/`
  (con `_384/_512/_768`); destinos y lo que se resuelve por código en su `OBJETIVO.md` (`OroIcon` → `ui_dolar_blue`,
  borrar `ui_oro` y `wheel_seg_jackpot`, renombrar `icon_ui_oro_*.mov`; la Ruleta «cortada» es layout:
  `WheelView` `.frame(WheelStage.size)` + `.clipped()`; «todos los premios» ya es `rw_mystery_all`).

## Verificación

- `completo` de `cccbf6f5` (con 2–3 agentes encima, carga 300–650): EK 923 · unit 1907 · store-unit 18 · Release 0 ·
  **store-ui 3/3 en iOS 18.6** (el arreglo del rpath, confirmado) · iPad 4 · SE 2 · Dios 45,40 h (6 reenc.) VERDES;
  pipeline 7 rojos (reales, arreglados en `8b3f6819`: 99/99) y UI 167 + 5 rojos.
- `rapido` de `af054ae3` (la punta, con B1 y B2): EK 923 · Release 0 VERDES; unit 1920 + 1 rojo,
  `ElevatorRideTests.skipWhileOpeningDoesNotDingTwice` (flake conocido bajo carga, §4.1 de `tasks.md`).
- Los 5 rojos de UI, aislados sobre la punta: `ShareMomentUITests` 3/3, `SideRailUITests` 6/6, `VisitorUITests` 3/3
  VERDES (eran carga). **`TowerNoticeUITests.testElAvisoSaleArribaEntreLasColumnasYSeVaSolo` ROJO también aislado**
  («el rebote no avisa» con `--uitest-corralito`): real, verde en el `completo` de `38e86376`; lo trajo algo de este
  relevo (sospecha T24: los topes pasaron de `eventIsApplicable` a `eventIsRollable`). **Primera tarea del 56.**
- `version-2` **NO** se adelantó (sigue en `d53a4098`).

## Decisiones del dueño de hoy (no se re-preguntan)

Sacudidas a 1 s OK · D5: los 3 primeros del tutorial sólo «¡Genial!» · textos de los 4 eventos de T24 aprobados ·
globo del visitante OK en su iPhone · el aviso del SE se baja (no se achican los chips) · las 11 imágenes de
`fisu-v2-blue` aprobadas · E14b antes de los cierres T25/T26/T27.

## Trampas nuevas

- **Un rpath de Debug con `@executable_path/Frameworks` primero** carga el XCTest copiado al `.app` y aborta en dyld en
  iOS 18 (en 26 lo tapa `/usr/lib/swift`). Los ~60 s «a idle» eran XCTest esperando a una app muerta: mirar los `.ips`
  de `~/Library/Logs/DiagnosticReports` antes de suponer lentitud.
- **Retirar recursos rompe la suite de Python del pipeline**, que el `tarea` de un agente no corre: quien borre algo
  de `Resources/` corre `Tools/asset-pipeline` tests.
- **Un video con alfa encima de su PNG póster** se ve doble si encuadran distinto: el póster de un `LoopingVideoNode`
  con alfa va transparente.
- **Un worktree nuevo recompila todo** (~15 min de Release con carga): para una build urgente del iPhone, reusar el
  worktree de integración.
