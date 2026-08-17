# SESIÓN 2026-08-17 — Rediseño de la pantalla principal (✅ COMPLETO)

> **Para retomar con un agente nuevo, leé `Docs/HANDOFF.md` primero y esto
> después.** Acá está el detalle de UNA rama:
> `feature/rediseno-pantalla-principal`, que saca las islas flotantes de la
> pantalla principal y le agrega un atajo de contratación.
>
> ✅ **Las 6 tareas están hechas** — las 5 del plan original más la **enmienda
> del dueño a mitad de vuelo**, y las 4 de código pasaron review sin dejar
> concerns abiertos.
>
> Suites finales, las cuatro medidas en la MISMA verificación sobre `650f089`:
> EconomyKit **200** · app **370** · UI **44/44 en una sola corrida y sin
> skips** · SE **12/12** · **cero warnings de compilador**.
>
> ⚠️ **Aviso para el dueño**: en el SE la barra inferior va a **374 de 375 pt**
> de ancho. **Los iconos no pueden crecer más sin sacrificar los labels.** Si
> algún día se piden más grandes, la decisión es "iconos gigantes SIN nombre",
> y eso es un canje, no un ajuste.

## Cómo se retoma

1. Rama: `feature/rediseno-pantalla-principal`, 19 commits sobre `4c1e67c`.
2. Plan (5 tareas del plan + la enmienda del dueño como Task 6):
   `Docs/superpowers/plans/2026-08-16-rediseno-pantalla-principal.md`. La
   sección "Referencia visual" explica qué se tomó y qué se ignoró del mockup
   que trajo el dueño.
3. Proceso: skill `superpowers:subagent-driven-development`. Workspace:
   `.superpowers/sdd/2026-08-16-rediseno-pantalla-principal/` (gitignorado) con
   `progress.md` (ledger: minors diferidos, rulings, incidentes) y un
   `task-N-report.md` por tarea. Si el workspace no existe, se reconstruye de
   este doc + `git log`.
4. Política de modelos: implementadores y reviewers en **opus**; escalada de fix
   rounds 4-5 a fable. Un implementador por vez, SECUENCIAL.
5. La regla visual del dueño sigue vigente: **FisuJobs es la referencia de
   TODAS las pantallas**. Esta rama no la rompe — cambia los CONTENEDORES
   (barras) y reusa los componentes canónicos adentro.

## Qué se pidió

Tres cosas, en las palabras del dueño:

1. **Que la barra de arriba se funda con el borde de arriba** — nada de isla
   flotante sobre el tablero.
2. **Que la barra de abajo se funda con el borde de abajo**, con los **iconos
   mucho más grandes** y el nombre de cada tab visible.
3. **Un botón que contrate al personaje del tier más alto que la plata
   alcanza**, sin tener que abrir FisuJobs.

Y **a mitad de la ejecución, con las capturas de las Tasks 1-2 en la mano**, una
enmienda: *"hace que la barra superior sea del mismo color que la barra
inferior. hace los iconos aun mas grandes"*. Eso **reemplazó** la decisión del
panel oscuro que el propio dueño había tomado el día anterior: las dos barras
quedan **gemelas** en crema con contorno ink de 3 pt mirando al tablero. Se
ejecutó como Task 6, con su propio review, en vez de parchear las tareas ya
cerradas.

## Estado por tarea

| # | Tarea | Estado | Commits | Notas |
|---|---|---|---|---|
| 1 | Panel superior fundido al borde | ✅ review clean (1 ronda) | `3ec1f46` + `a133fe1` + `115fe87` | La barra de estado **se oculta de verdad**: `UIStatusBarHidden` estaba en `project.yml` desde antes pero **inerte**, porque le faltaba la clave compañera `UIViewControllerBasedStatusBarAppearance: NO` — más `RootView.statusBarHidden(true)`. El fix round salió de ahí: sin barra de estado, en los teléfonos sin notch la safe area es **0** y el HUD quedaba **contra el bezel**; se le puso piso (`minimumTopGap`, `max(2, 14 - inset)`), que no toca a los teléfonos con notch |
| 2 | Barra inferior fundida, iconos gigantes con nombre | ✅ review clean (1 ronda) | `b1a97b1` + `50874ea` (+ contenido del fix en `fba1992`/`bb06a8b` del dueño) | Panel crema de ancho completo, esquinas sólo arriba, contorno cuyos laterales mueren fuera de pantalla, relleno bajo el home indicator. Labels visibles que usan **la MISMA clave** que el label de VoiceOver: lo que se ve y lo que se escucha son idénticos por construcción. Dos textos retocados (`Personalización` → **Vestimenta**, `Ajustes` → **Menú**). El fix round cerró la **4ª desincronización** del espejo de geometría de `AscentRenderingUITests` y un caso NUEVO: en SE el aviso de torre pisaba el botón de prestigio ~6 pt |
| 6 | **Enmienda del dueño**: barras gemelas e iconos otro punto más grandes | ✅ review clean, sin rondas | código en `0d3b96d` (del dueño, ver más abajo) + `b69b8c6` + `3056e35` | Panel superior **crema** con el mismo contorno ink que el de abajo; el contenido vuelve a ink-sobre-crema. Platos 56/62, iconos **48/54**, `CoinIcon` del contador 36, `IconButton` del HUD 64 con `glyphScale` 0,66. La cuenta que manda: `2×62 + 4×56 + 5×2 + 16 = 374 ≤ 375`. De acá salió `GameTabBar.barHeight` (84) como **símbolo**, y `bottomInset` pasó a derivarse (`barHeight + 34 = 118`) en vez de copiarse a mano |
| 3 | `bestHire` — el mejor contratable que la plata alcanza | ✅ APPROVED sin C/I | `d227904` | **TDD**, 12 tests, con mutation-testing de los comparadores (los desempates son fáciles de escribir al revés). La regla reusa la compuerta que FisuJobs ya aplica: elige **entre lo que FisuJobs ofrece como contratable**, no inventa autorización; `unseen` nunca califica (no espoilea RF-03). Pins exactos contra la config real: `fast_food` t8 a **9.442.891,09** y `senior_architect` a **1.218.867.229,80**, con canario del empate a 4 |
| 4 | `QuickHireButton` en la pantalla principal | ✅ review clean (**3** rondas) | `6828ec8` + `f314537` + `a476647` + `650f089` | Cápsula con cara + nombre + precio, centrada sobre la barra: **verde** cuando alcanza, **crema desaturada** con la meta de ahorro cuando no; nunca `.disabled`, tiembla al tocar sin saldo (contrato de `PricePill`). La ronda 1 sacó el alto literal a `QuickHireButton.capsuleHeight`; la 2 corrigió dos docstrings de isolation que enseñaban una regla que el compilador rechaza; la **3 cerró la regresión de accesibilidad** de más abajo |
| 5 | Verificación integral, capturas y docs | ✅ (este doc) | (este commit) | Las suites enteras, las capturas para el dueño, y el gate que encontró la regresión de la ronda 3 |

## La regresión que encontró el gate final (y por qué importa)

La verificación de cierre corrió la suite de UI **entera, en una corrida, sin un
solo `-skip-testing:`** — y volvió **roja**:

```
FisuJobsUITests.swift:59: XCTAssertFalse failed —
"el nombre no puede ser su propio elemento de AX: lo anuncia la fila"
```

Ese test **es más viejo que la rama** y no lo tocó nadie acá. Lo que pasó es que
`QuickHireButton` dibuja el nombre del personaje ofrecido en la pantalla
principal, la pantalla principal **no sale del árbol de AX cuando hay una hoja
arriba**, y con `--uitest-coins` en partida nueva la oferta es exactamente "El
Fisura": el pin de app entera lo cazó. Un volcado del árbol de AX lo mostró
literal —`StaticText 'El Fisura'` como hijo de `hud.quickhire`— y la corrida
aislada confirmó que era determinista y no la trampa 9a.

El fix (`650f089`) dejó una tabla **medida** en el código que vale para toda la
app: un `Button` de SwiftUI **publica el contenido de su label como hijos pase
lo que pase**, y las cuatro formas que uno escribiría no lo evitan
(`.accessibilityElement(children: .ignore)` sobre el botón, `.accessibilityHidden`
sobre el contenido, `children: .ignore` adentro del label, `.accessibilityHidden`
en cada `Text` hoja). `.accessibilityChildren { EmptyView() }` sí los saca **pero
deja el botón `isHittable == false`**, que rompe la activación por VoiceOver.
La única que da las tres cosas —sin hijos, sigue siendo `Button` con su label
compuesto, sigue siendo tocable— es **`accessibilityRepresentation`**.

⚠️ **El orden de los modifiers es load-bearing**: el `accessibilityIdentifier`
va **después** de `accessibilityRepresentation` o se descarta.

📌 **La moraleja, que es el argumento del gate entero**: las rondas de
implementación verificaron con `-only-testing:` sobre las pantallas tocadas
(BottomMenu, Ascent, Tutorial, HUDRedesign) y **`FisuJobsUITests` no estaba en
ninguna de esas listas**. Nadie hizo nada mal: la regresión era invisible desde
la pantalla que se estaba tocando. **La cazó la suite completa del gate final, y
sólo ella.** Es la versión "un test no corrido no avisa" de la trampa 9a — y la
razón por la que la corrida entera sin skips no es opcional.

## El árbol compartido: la sesión paralela del dueño

El dueño trabajó en **su propia sesión sobre el MISMO checkout** durante toda la
rama (refactor de la cola de celebraciones —`Docs/SESION-2026-08-17-cola-de-celebraciones.md`—
y tandas de arte). Eso dejó marcas que conviene tener contadas antes de leer el
`git log`:

- **Tres commits llevan autoría mezclada.** El dueño commitea con `git add -A`,
  que barre lo que haya sin commitear en el working tree. `fba1992` y `bb06a8b`
  se llevaron los fixes de la ronda 1 de la Task 2, y **`0d3b96d` —que dice
  "celebraciones"— contiene TODA la Task 6**: barras gemelas, tamaños nuevos,
  `barHeight`, `bottomInset` y los dos toasts. El contenido se verificó bloque
  por bloque contra las versiones originales: entró **correcto**; lo que se
  perdió es la atomicidad y el mensaje.
- **El sweep dejó `HEAD` desincronizado un commit**: `BoardScene.bottomInset` en
  118 con el espejo de `AscentRenderingUITests` en 116 — la **quinta**
  desincronización histórica de ese archivo, que es exactamente contra lo que
  avisa el bloque ⚠️ que tiene arriba. La cerró `b69b8c6` acto seguido.
- **El riesgo inverso también se materializó**: en la ronda 1 de la Task 2, un
  blob de `RootView` reconstruido sobre la base vieja **iba a borrar 94 líneas**
  del dueño. Se cazó **porque el protocolo obliga a chequear `HEAD` antes de
  stagear**; se reseteó el índice sin commitear nada.
- **Nada barrido se re-commiteó.** Reescribir la historia de una sesión paralela
  sobre un árbol compartido es peor que un mensaje de commit impreciso.

📌 **Lo que quedó como protocolo** para cualquier frente que comparta checkout:
`git log --oneline -3` + `git status` **antes de cada staging**, stagear **sólo
rutas explícitas** (nunca `-A`), commitear apenas hay algo verde, y si el árbol
no compila por ediciones ajenas en vuelo, **worktree aislado** en vez de esperar.

## Backlog post-rama

Del ledger del workspace. **Ninguna es tarea abierta del HANDOFF**: son
follow-ups sin dueño. Los cerrados durante la rama no están (el 9 lo cerró
`50874ea`, el 16 la Task 6, el 18 y el 23 la Task 4, y el 8 la verificación de
cierre al correr `TutorialUITests` en SE por primera vez desde el cambio de
alto: 5/5).

1. El comentario de `project.yml:47` sobreafirma: la puerta cerrada son las
   `INFOPLIST_KEY_*` bajo `GENERATE_INFOPLIST_FILE`, no el plist entero.
2. `.frame(maxWidth: .infinity)` duplicado en `HUDView:31` y `:87`.
3. El `UnevenRoundedRectangle` de `topPanel` está literal dos veces (fill y
   stroke pueden divergir sin que nada avise).
4. **Sin pin de regresión de la status bar oculta** — un XCUITest de una línea, y
   es lo único que sostiene el pedido nº 1 del dueño.
5. Nit de report: el mecanismo declarado del `maxY` del tutorial no es el real
   (la conclusión sí vale).
6. `BoardScene.topInset` (:142) sigue siendo código muerto — hoy con docstring
   honesto: su único cliente, el reveal, pasó a ir centrado en pantalla.
7. El fallback `?? 0` de `HUDView:87` apunta al lado equivocado (irrealizable
   hoy: el HUD monta con la window key).
10. Salto de 12 pt en el primer frame del SE por el seed 34 (gemelo del HUD, ya
    documentado).
11. Los dos pisos de aire divergen (12/max0 contra 14/max2) y el comentario dice
    "el mismo piso".
12. El comentario del recorte del tutorial y el report son ambos imprecisos
    sobre si tapa el label (sin defecto demostrado).
13. `screenBottomSafeArea` duplica `screenTopSafeArea` verbatim — al tercer uso,
    helper.
14. El comentario del aviso de torre asume que el botón de prestigio siempre
    está (cosmético, 1 pt).
15. El clearance de 0,5 pt en SE vale a Dynamic Type default (preexistente y
    estrictamente mejorado por esta rama).
17. **Observación de juego**: el aviso `.floorFull` es casi inalcanzable desde
    FisuJobs — la fila cambia `PricePill` por `StateBadge` al llenarse.
19. El `8` del `VStack` quedó transcripto como literal en `RootView:550/620`.
20. El toast de logros re-deriva el offset del aviso en vez de consumirlo (un
    `towerNoticeBottom` compartido lo cierra).
21. El método de píxeles no midió las esquinas del contorno (zoom ocular
    pendiente).
22. Número ambiguo en el docstring del `debugButton` ("tres puntos y medio de
    vida").
24. Nota de perf: `refreshProjections` corre a tap-rate además de a 8 Hz — la
    conclusión (decenas de µs) se sostiene; hay hoists baratos anotados por si
    el device los pide.
26. Asserts nil-tolerantes en el smoke del atajo (ambos lados `nil` daría verde
    vacío; hay precedente estricto en `AscentRenderingUITests:251`).
27. `price.ax.coins` ahora tiene una segunda call site fuera de `PricePill`: es
    el punto de sincronización de cómo se dice la moneda.
28. Preexistente: el `showing` de celebraciones hace que los dos toasts no
    puedan apilarse, pese a lo que dice el comentario del +63.
29. **Observación de juego**: no hay camino de UI que produzca el aviso
    `floorFull` (el botón se esconde al llenarse el piso, y FisuJobs también).
30. `@MainActor` redundantes en `bottomFloor`/`screenBottomSafeArea`.
31. Precisión: "SKScene es `@MainActor`" vale por herencia de `UIResponder`
    (`NS_SWIFT_UI_ACTOR`), no por anotación propia de SpriteKit — quien lo
    re-verifique grepeando SpriteKit no lo va a encontrar.
32. `hud.quickhire` y `jobs.hire.homeless` publican **el mismo label hablado
    exacto** cuando la oferta es el tier base: dos botones idénticos para
    VoiceOver en distinto contexto. Nit inherente, no lo pinea nada.
34. Un comentario apunta a un test que no existe
    (`testContratarSubeElContadorDeLaFila`; el real es
    `testContratarSubeElPrecioDeLaFilaYPoneLaUnidadEnElTablero`).
35. El orden load-bearing de los modifiers del atajo no está documentado **como
    regla**, y la nota de la trampa 9a-bis que tiene al lado invita justo a
    subir el identifier, que es lo que lo rompería.
36. **Observación**: `hud.prestige` y los seis tabs también publican sus labels
    como `StaticText` hijos. Son strings de catálogo y no nombres propios, así
    que la regla del pin de FisuJobs no se les exige — pero si alguien
    generaliza el patrón, ya sabe dónde está el resto.

## Verificación de cierre

Simuladores **propios por UDID**, creados y **borrados** al terminar. Orden
respetado: `xcodegen` → build → **unit ANTES que UI** → UI completa, todo con
`-parallel-testing-enabled NO` y en serie.

| Suite | Cómo | Resultado |
|---|---|---|
| EconomyKit | `swift test` en `Packages/EconomyKit` | ✅ **200/200** |
| build Debug (16 Pro) | `xcodebuild … build` | ✅ **0 warnings de compilador** |
| `FisuEvolutionTests` (16 Pro) | `-only-testing:FisuEvolutionTests` | ✅ **370/370** |
| `FisuEvolutionUITests` (16 Pro) | **una corrida, sin skips** | ✅ **44/44**, 15 clases |
| UI en SE 3 (BottomMenu, FisuJobs, HUDRedesign, Tutorial) | `-only-testing:` ×4 | ✅ **12/12** |

Los números del banner del HANDOFF quedaron actualizados: eran **183 / 346 / 43**
y ahora son **200 / 370 / 44**. El +17 de EconomyKit es de la cola de
celebraciones (sesión paralela); el +24 de la app y el +1 de UI son de esta rama
y de esa.

### Las capturas

En el workspace SDD (`.superpowers/sdd/2026-08-16-rediseno-pantalla-principal/`),
tomadas sobre la build de la verificación:

- `task-5-16pro-pobre-boton-crema.png` — contador en **0**, la cápsula en crema
  con la meta de ahorro (El Fisura, 50).
- `task-5-16pro-pagable-boton-verde.png` — el mismo encuadre con **1M**: la
  cápsula en verde. Es el A/B limpio del botón.
- `task-5-16pro-tier-alto.png` — con la torre abierta, la oferta **salta de tier
  sola**: "Repartidor", **372K**. Es la prueba visual de que el botón ofrece el
  mejor pagable REAL y no un tier fijo.
- `task-5-se-barras-gemelas.png` — SE 3: las dos barras gemelas fundidas a los
  bordes, los **seis labels enteros en un renglón**, sin recortes.

En las cuatro se ve lo que se pidió: **ninguna isla**, las dos barras fundidas a
su borde, **sin barra de estado**, y los iconos legibles a un brazo de distancia.

## Qué queda

Nada de esta rama. Los dos gates humanos de F6 siguen siendo lo único pendiente
del proyecto (cuenta de Apple Developer y fuente de audio), sin cambios respecto
de `Docs/SESION-2026-08-16-cierre-post-merge.md`.
