# Matriz interacción → feedback (criterio de cierre F5)

Regla del skill iOS: **ninguna acción silenciosa** — toda interacción tiene
animación + SFX + haptic. Los SFX suenan cuando el [GATE HUMANO] de audio
entregue los archivos CC0 (`AudioManager` ya los mapea y degrada en silencio).
Canales Ambient/Voice: exclusión consciente de la v1.

| Interacción | Animación | SFX | Haptic |
|---|---|---|---|
| Tap | bounce 1.12 + label "+N" + partícula tap | `sfx_tap` | — (a 3/s saturaría) |
| Tap crítico / golden | bounce 1.22 + label grande rosa/dorado + partícula coins | `sfx_coin` | rarity |
| Spawn | nodo aparece en relayout + botón pulsa (FTUE) | `sfx_buy` | purchase |
| Merge | pop 1.25 + partícula merge | `sfx_merge` | merge |
| Merge inválido | snap-back 0.15s easeOut | — (el snap-back ES el feedback) | — |
| Evolución (tier nuevo) | flash + partículas + nombre gigante (reveal) | `sfx_evolution` | evolution |
| Unlock de pasivo | popup + cierre | `sfx_buy` | purchase |
| Compra rechazada (sin fondos) | botón disabled / snap | `sfx_error` | error |
| Compra IAP | UI de StoreKit + row pasa a ✓ | `sfx_buy` | purchase (vía StoreKit UI) |
| Upgrade | fila actualiza nivel/costo | `sfx_buy` | purchase |
| Boost activado | fila pasa a cooldown + modifier visible en income | `sfx_buy` | purchase |
| Evento (inicio) | banner entra con spring + countdown | `sfx_event` | — (no interrumpir) |
| Evento (fin) | banner sale con fade | — | — |
| Daily claim | popup con monto/special | `sfx_daily` | — |
| Special drop | sheet celebración + estrella | `sfx_rare` | rarity |
| Prestige | reset de board + popup | `sfx_prestige` | evolution |
| Share completado | bonus aplicado (visible en income) | — | purchase |

**Accesibilidad aplicada:** Reduce Motion desactiva partículas decorativas,
pulsos de FTUE y escalas del reveal (queda crossfade); banner de eventos usa
ícono ↑/↓ + texto además del color; haptics con toggle; VoiceOver con labels
en HUD/tienda/popups; Dynamic Type en todas las vistas SwiftUI (fuentes
semánticas). Pendiente del pass final F5: audit con VoiceOver activado.
