# SESION 2026-10-12 — relevo 37 (ola AI): dos carries sin fila

Relevo despertado por el disparo horario de `fisu-v2-relevo-a` (04:02). Candado libre, cuota holgada (5 h al 3 %, semanal al 81 %). `version-2` = `32135431` al llegar (259 de 283). El dueño no destrabó nada (playtest de precios, SE, mediación por SPM, Supabase, dominios), así que el relevo tomó dos carries chicos de `tasks.md` §4.2 fila 6 y cerró corto. Integración en `v2i/integ-r37`; briefs en `.claude/avo/2026-10-06-fisu-v2/ola-r37/`.

## Qué entró

| Carry | Commit (merge) | Qué |
|---|---|---|
| El otro colchón: UI de `extraOnly` | `4ca4a581` (`1a74b8a8`) | Flag `--uitest-mattress-extra` (`debugSpawnMattress(extraSaved:)`, cableado en `+Engagement` junto al `--uitest-mattress`) y `PrizesUITests.testTheSavedExtraMattressPaysWithOnlyTheVideo`: el popup sólo ofrece el video, paga, y el chip deja de estar listo. Sin bugs en la rama `extraOnly` |
| El pager marcaba pestañas a mitad de arrastre | `c93a9781` (`2c6ea5dc`) | `MenuPagerView` asienta la página sólo con `phase == .idle` (`settledPage(...)` estático y testeable; un flag `scrolled` para que el `scrollTo(start)` inicial no cuente). `MenuSessionTests.pageSettlesOnlyWhenQuiet` (RED por mutación) y dos UI en `MenuPagerUITests` (arrastre que vuelve conserva el «new»; swipe completo lo saca) |

Sin filas nuevas en el tablero: siguen **259 de 283 (91,5 %)**.

## Verificación

- Tareas: colchón `tarea` VERDE (29 unit, EK 875) + `PrizesUITests` 3/3; pager `tarea` VERDE (70 unit, EK 875) + `MenuPagerUITests` 4/4, `CustomizationUITests` 5/5, `TutorialLessonsUITests` 5/5. Simuladores propios, borrados por UDID.
- `rapido` de `2c6ea5dc` VERDE: EK 875 · unit 1763 · Release 0.

## Lo que queda abierto de esto

- El UI de arrastre parcial **no da RED con el código viejo**: XCUITest no suelta con velocidad inversa pasada la mitad, que es lo que disparaba el bug. Queda como regresión; el RED lo da el unit. Mirarlo a mano en un iPhone (arrastrar media pestaña y volver: la de al lado conserva su «¡Nuevo!»).
- El «chip deja de estar listo» del colchón no tiene RED por mutación (lo positivo sí está probado).
- Siguen sin hacer los otros carries de la fila 6: el texto del chip y de la fila de los eventos de 25 s (no hay clave), `tour.done` con «¡Vamos!», la clave vieja `tutorial.tip.wheel`, el «Cargando…» del botón de video sin red.
