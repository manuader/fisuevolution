# SESION 2026-10-12 — relevo 38 (la ola AJ): el texto de los eventos de 25 s

> Base: `version-2` = `4c019685` (código `2c6ea5dc`). Sin subagentes: lo hizo el controlador en `v2i-r38-textos`.

## Qué entró

| Commit | Qué |
|---|---|
| `efd25858` | `ActiveModifier.eventPresence` deja de devolver `""`: el chip del HUD y la línea del popup del evento dicen **«En curso» / «Ongoing»** (`bonus.chip.event_presence`) junto al reloj. Sale `tutorial.tip.wheel` del catálogo (sin uso desde que la lección de la columna usa `tutorial.tip.wheel.rail`). `EffectContractTests` pide el texto nuevo. Snapshot en `Tools/v2/claves-pendientes/r38-evento-25s.json`. |

## Verificación

- `tarea ActiveBonusTests EffectContractTests LocalizationCompletenessTests`: VERDE (EK 875 · unit 25).
- `rapido` de `efd25858`: VERDE (EK 875 · unit 1763 + 10 salteados · Release 0).

## Lo que encontré de la fila 6 de `tasks.md` §4.2

- **«Cargando…» sin red ya estaba resuelto:** `RewardedOfferButton` pasa a «Sin conexión» a los 10 s (`InventoryWait`) y un toque reintenta. La fila lo arrastraba sin saberlo; se saca.
- Siguen sin hacer, a propósito: `tour.done` con «¡Vamos!» (nadie lo decidió) y la lección de la columna al terminar el núcleo en partida nueva (con el giro listo nace ahí; no está claro que sea un bug: queda para la mirada del dueño).

## Para el dueño

- En un iPhone: un evento de 25 s (p. ej. el aguinaldo) muestra «En curso» y el tiempo en el chip y en su popup.
