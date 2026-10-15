# Sesión 2026-10-15 — relevo 57: B17–B19, B26 y B27, y el completo que se cargó solo

Relevo por el disparo horario de la rutina `fisu-v2-relevo-a` (10:02; LOCK libre, cuota 5 h 0 %, semanal 29 %). Regla del
dueño vigente: **los agentes no compilan por tarea**; la ola se integra, se compila una vez y un agente arregla lo que
falle (ver `Docs/SESION-2026-10-15-v2-relevo-56.md`). A media sesión el dueño, desde «Fisu Evolution v2 roadmap», pidió
la tercera tanda de E14b (B19–B30) y la épica E15 «Valor por jugador».

## Qué entró (en `v2i/integ-r54`, pusheada)

| Tarea | Commit → merge | Qué |
|---|---|---|
| B17 + B18 | `0ba28a6e`, `c7e67153` + `913f1ce2` → `33a42178` | Caja, colchón y caminantes ~20 pt más abajo. Cada caja pertenece a un piso: contenido sorteado al aparecer, cae en un lugar aleatorio del piso de ese personaje, persistida; abrirla da ese personaje. Un agente opus, sin compilar; EK 975, 7 mutantes muertos, Dios `.free` 45,40 h. Claves b18 al catálogo (`bf5397e6`). |
| fix-sim-r57 | `0934fb0f` → `549fdbb8` | Revisión opus de B18 (APROBADO CON CAMBIOS): en el pacing-sim las cajas trabadas sobrevivían a la reencarnación y `deliver` no chequeaba `belongs`. `tickPackages` re-sortea las que no cumplen; test `PackageBoxRebirthTests.staleBoxIsRerolled` con RED visto. Dios `.free` 45,40 h · `.ads` 30,60 · `.max` 30,02. |
| fix UI B18 | `0a13eecf` | `PackageFloorsUITests.ride()` mezclaba `expectation(for:)` + `XCTWaiter` con `waitForExpectations`: API violation (bug del test). Pasa a `XCTNSPredicateExpectation`. |
| B27 | `1dd1588f` | El crema #F1E5C9 de FisuJobs en las dos barras (D18). |
| B26 | `ae1821f1` → `bab11921` | Barra `[.store,.upgrades,.skins,.jobs,.gifts,.menu]`; el Ranking pasa a tarjeta del Menú (D19); lección `tabsMoved`; claves `b26.json` (`91af0d81`). |
| fix tabsMoved | `e473810a` | `TutorialTipsTests`: `tabsMoved` pisaba la lección de Pintas; el test marca `tabsMoved`. Tutorial 64/64. |
| B19 | `7fbbe794` → `643ba431` | Capas por profundidad: `DepthOrder` z = 30 − 0,01·y, `touchOrder` por z, el globo del visitante pasa a capa SwiftUI (`StageBubbleLayer`, se borra `SpeechBubbleNode`), `LoopingVideoNode` con z fuera de fila. |
| fix-b19-r57 | `6d3201c7` → `a473f30c` | Revisión opus de B19 (APROBADO CON CAMBIOS): el hit elíptico del empleado le ganaba a la caja o al visitante visibles detrás (flakes en BoardPackage/PackageFloors/Prizes). Ahora `CharacterHit` (puro, 3 tests) toca sólo el cuerpo visible del empleado cuando hay algo detrás; `coinBadge` a `innerStep`; `QuickHirePickerLayer` arriba del globo. Rojo de `StageBubbleTests` era del test. |
| iPhone | `6ee79bf3` | El cofre rehecho (bug del dueño) **ya está instalado** en su iPhone (Release; tercer intento, los dos primeros `NWError 54`). |
| E15 | `9c1fea0f` | Spec «Valor por jugador» commiteado (`Docs/PLAN-v2-E15-valor-por-jugador.md`); antes de lanzar sólo F0. |

## Verificación

- `completo` de `4e6dcecc` (`build/oraculo/20261015-100323-completo`), con la máquina sola al arrancar: **ROJO**, EXIT 1,
  UI tardó 13 552 s. EK, Release, store-unit 18, store-ui 3, iPad UI, SE UI, pipeline y pacing-sim VERDES.
  unit 2022 + 4 rojos; ui 167 + 16 rojos.
- **Aislamiento** (`20261015-142930-aislar-r57`, simulador propio iOS 26.5, `test-without-building`): unit 35/35 verdes;
  ui 21 verdes y 1 rojo, `testCapturaElVisitanteEnCastellano` («el visitante nunca llegó al escenario»), que en la
  corrida siguiente sobre el build de B18 salió verde (flake, 1 corrida). **20 de 21 rojos eran carga.**
- Tarea B18 sobre `bf5397e6`: build ✅, EK 975, unit 125/125 en las 11 clases. UI de B18 `150357`: PackageFloorsUITests
  verde con el fix.
- Tarea B26 sobre `91af0d81`: un rojo (`TutorialTipsTests`, arreglado); tutorial 64/64.
- Tarea B19 sobre `643ba431`: build ✅ a la primera, unit 103 + 1 rojo (`StageBubbleTests`) → `6d3201c7`; tarea VERDE: EK 976, unit 81.
- **No se corrió el `completo` sobre la punta** (`a473f30c`): `version-2` sigue en `d53a4098`.

## Para el próximo relevo (en orden)

1. `Tools/v2/oraculo.sh completo` sobre la punta de `integ-r54`, **con la máquina sola**; si la carga sube por Spotlight, anotarlo. Aislar los rojos una vez; VERDE → fast-forward de `version-2`, push, filas 🟢 a ✅. Hay UI tests de B18/B19/B26 que mirar (lista en el handoff) y capturas de B17/B18/B19/B26/B27 que piden los specs.
2. E14b olas 7–9: B20+B21 (un agente), B22+B23 (un agente; cambia el save de B18: +y), B28; luego B24, B29 → B25; luego B30 en `v2/e14b-b30-escala`, sin merge sin OK del dueño.
3. E15 sólo F0, después de E14b y antes de los cierres (coordinar con B29 por el embudo de ofertas).
4. Cierres: E14 T27, E8d T15, E8e T9, E12 T17/T18, E10 T9/T11/T12/T13.

## Trampas nuevas

- **El `completo` se puede cargar solo:** la carga llegó a ~150 por `mds_stores`/Spotlight + CoreSimulator con 0 agentes compilando. Con carga así los UI tests dan rojos que no son del código (20 de 21 acá). Aislar una vez antes de dar un rojo por real.
- **`expectation(for:)` + `XCTWaiter` + `waitForExpectations` = API violation:** la misma expectativa se espera dos veces. Usar `XCTNSPredicateExpectation` con un solo mecanismo.
- **`gameState` es `weak` en los tests de `StageController`:** se libera a mitad del test y el feed pasa a `nil`. Envolver en `withExtendedLifetime`.
- **El pacing-sim no es el juego:** las cajas trabadas sobrevivían a la reencarnación porque `deliver` no chequeaba `belongs`. Cualquier regla nueva del juego se replica en el sim con un test que falle sin ella.
- **Un hit inflado gana por z:** el empleado (elipse inflada) se llevaba el toque de lo que se ve detrás; con capas por profundidad, el toque se decide por el cuerpo visible.
- **Los `Tools/v2/oraculo.sh` UI de más de 3 h** (13 552 s) no son un cuelgue: mirar la carga antes de matarlos.

## Carries (los decide el 58)

- **Lección `tabsMoved`** es elegible también para jugadores NUEVOS apenas completan `newTabs`; debería ser sólo para veteranos con la barra vieja. Un intento de marcarla al hacer `newTabs` se revirtió porque rompe `only()` y los tests de la lección.
- Ícono del Ranking en el Menú sin arte (`ui_menu_ranking`, D8): cae a la corona. `hud.ranking.label` quedó huérfana.
- Ratios del cuerpo visible (0,5 / 0,92) **estimados**, no medidos.
- El «!» del pedido (`makeMark`, z 30) puede asomarse sobre capas de adelante.
- El selector del atajo queda ahora arriba de los avisos.
- `RankingView` con `Group`/`NavigationStack` condicional; `TutorialTips`/`Lessons` esperan `tutorialTip == nil` tras el núcleo.
- Menores de la revisión de B18: el save viejo se sortea en el primer tick (no al cargar), `assignPending` sin reserva de lugar, la caja trabada cuenta contra `maxWaiting`, `packageBoxOpenable` por frame sin caché, refund con otra x, la marca del ascensor no refresca con la placa abierta (`@ObservationIgnored`), y D14 (visitante vs hilera de atrás) a confirmar en capturas. Concerns de B18: la x al azar casi sin juego en teléfono (6 pt en el SE), cajas sin asignar se dibujan en el piso mirado.

## Para el dueño

- El cofre rehecho (`6ee79bf3`) ya está en su iPhone: probarlo con **Bajo consumo** prendido.
- Decisiones por default de B18 que puede cambiar: columna y Regalos abren la caja del piso actual o llevan al de la más vieja; la pantalla de la 1.ª caja muestra la cara del que llega; el ascensor marca pisos con cajas.
- E15: sólo F0 antes de lanzar (medir, sin tocar la economía); lo demás va a la 2.1.
