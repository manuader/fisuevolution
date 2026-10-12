# SESION 2026-10-11/12 — relevo 36 (ola AH): E9 y E6b cerradas

Relevo despertado por el disparo horario de `fisu-v2-relevo-a` (23:02 del 11). Candado libre, cuota holgada (5 h al 6 %, semanal al 80 %). `version-2` = `2185e37d` al llegar (253 de 283). Integración en `v2i/integ-r36`; briefs de la ola en `.claude/avo/2026-10-06-fisu-v2/ola-r36/` (sobreviven al barrido).

## Qué entró

| Tarea | Commit (merge) | Qué |
|---|---|---|
| E6b T10 | `9c43d19b` (`23c389b1`, + `afa6ee22`) | Cierre de E6b en `Docs/SESION-2026-10-11-v2-e6b-cierre.md`; HANDOFF §5 29; 7 escenarios 🔒 |
| E9b T3 | `8f1f8274` (`f6c0cc53`) | 16 lecciones de `legacyStep` a pasos (las 9 del plan + `elevator`, `elevatorKeypad`, `skins`, `achievements`, `oroUpgrades`, `gifts`, `store`); orden del plan fijado por test; `knownGaps` = [`skinEffects`] |
| E9b T4 | `addc5b5b` (`8b5801fc`, claves `f8cbabc8`) | Tour de novedades de 10 pasos de explicar para el veterano; cubre quickHire, menuSwipe, characterSheet, elevator, sideRail; `--uitest-veteran` |
| E9a T10 | `4354ab37` (`0f80f59e`) | Cierre de E9a: escenario por UI tests en SE e iPad, 18 capturas en `Docs/capturas/e9a/`, `Docs/SESION-2026-10-11-v2-e9a.md` |
| E9b T5 | `aaeaf37f` (`c8d8e580`, claves `9696c99e`) | Sección «Tutorial» en Ajustes: repaso con «Terminar repaso» y Tour pedido; filas apagadas con texto hasta terminar el núcleo; el Tour pedido no toca banderas |
| E9b T10 | `c35ef7ce` (`843286df`) | Cierre de E9 en `Docs/SESION-2026-10-12-v2-e9b.md`; PLAN-v2: E9 hecha salvo 🔒 |
| (controlador) | `bbabbb92` | Fixture `--uitest-lessons-done=<ids>`; `TutorialUITests` de Mejoras la usa con `quickHire` |

**259 de 283 (91,5 %).**

## Verificación

- `completo` de `f8cbabc8` (E9b T3 + T4 + E6b T10): EK 875 · unit 1755 · UI 155 + **1 rojo** + 4 salteados · store 18+2 · iPad 4 · SE 2 · Release 0 · pipeline 97 · Dios 31,34 h · 13 reencarnaciones. El rojo era real: `TutorialUITests.testLaLeccionDeMejorasSenalaCompraYSeCierra` esperaba que Mejoras fuera la primera lección con plata; el orden fijado por E9b T3 pone el atajo (`quickHire`) antes. Los unitarios ya lo habían absorbido (marcan `quickHire` dada); el UI test no. Arreglo `bbabbb92`.
- `rapido` de `9696c99e` VERDE (EK 875 · unit 1762 · Release 0) + `TutorialUITests` (10), `TutorialLessonsUITests` (5), `TutorialReplayUITests` (2), `WhatsNewTourUITests` (1), `SettingsPrivacyUITests` (2): 20/20 VERDES, en simulador propio borrado por UDID.

## Decisiones del controlador (desvíos aceptados)

- E9b T3 migró 16 lecciones y no 9: el árbol tenía 7 más en `legacyStep`, y sin ellas «ninguna lección conserva `.legacy`» no se cumple.
- `eventChip` es un paso de acción (no de explicar): el texto pide tocar y un `explain` dejaría el globo colgado sobre el popup. `wheel` usa `tutorial.tip.wheel.rail` (el texto vigente).
- El Tour pedido desde Ajustes no marca lecciones ni apaga banderas: el fin del Tour sólo lo hace si `tourPending` era verdadero.
- Repaso y Tour quedan deshabilitados, con una línea que explica por qué, mientras el núcleo no terminó.

## Trampas nuevas

- **Fijar el orden de las lecciones rompe los UI tests que asumen cuál nace primero.** Los unitarios se arreglan marcando dadas las anteriores; los UI, con `--uitest-lessons-done=<ids>`. Todo cambio de orden corre `TutorialUITests` y `TutorialLessonsUITests`.
- **`LocalizationCompletenessTests.settingsRows` lee el catálogo, no los snapshots:** una fila nueva de Ajustes se suma al test recién después de aplicar su snapshot (si no, queda rojo en la tarea).
- **Un agente sin toques en el simulador maneja el escenario a mano con los UI tests existentes y un muestreador de `simctl io screenshot`:** sirve para capturas; no sirve para la mirada visual (queda 🔒).

## Carries abiertos

- `visitor` quedó 28.º en el orden: una visita se va sola y otra lección con el turno puede comérsela.
- `tour.done` dice «Entendido» y no «¡Vamos!» (`TutorialOverlay`, `isCoreClose`).
- En una instalación nueva en simulador, el aviso de ATT sale encima de la primera tarjeta del núcleo: mirar el orden en device (🔒).
- Falta el chequeo con una v1 real actualizada (el Tour una sola vez) (🔒).
- Los carries del 35 siguen: la UI de `extraOnly` sin UI test, el chip y la fila de los eventos de 25 s sin texto, E6b T8 sin test punta a punta por `openChest`.

## Para el dueño (🔒)

Los escenarios con pasos están en `Docs/SESION-2026-10-11-v2-e6b-cierre.md`, `Docs/SESION-2026-10-11-v2-e9a.md` y `Docs/SESION-2026-10-12-v2-e9b.md`. Lo que destraba el final sigue siendo suyo: el playtest de precios (E2b), la medición en su SE (E8e), la mediación por SPM (E7b-a), Supabase (E12 T16), los dominios de B22 (E10 T14), y las notas a App Review y App Privacy.
