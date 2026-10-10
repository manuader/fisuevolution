# SESION 2026-10-10 — v2, relevo 27: los eventos con presentador, la Ruleta en Regalos, el aviso de la Ruleta, la Tienda de ORO y los presupuestos de visitantes

La ola Y. El relevo 27 arrancó a las 10:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 26 lo soltó a las 09:14), la cuota en 5 h 2 % y semanal 60 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E4b T4 (el turno de los eventos) y E6a T6 (plata de ORO).
E6a T4, E5b T4, E5b T6 y E2b T10 no tuvieron revisión opus: las leyó el controlador (contenido, UI sin plata nueva, tests y una constante de contenido).
Todo pasó por **`v2i/integ-r27`** (BASE `version-2` en `2c8c86f`, 194 de 254). Carga de la máquina: 1,3 al arrancar; hasta 3 compilando. Los briefs salieron de `Tools/v2/brief.py`
(`v2i-integ-r27/.superpowers/sdd/ola-r27/`, con `duenos.md`). Latido: `scratchpad/latido.sh` (`sleep 30`, escritura por reloj ≥ 9 min). El contexto pasó los 230k a las 11:15: no se despachó nada nuevo
después (E6a T6 y E2b T10 fueron las últimas) y se cerró a ~245k con los subagentes de tarea en 0.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | `9a0ee06`, la punta tras el `rapido3` VERDE sobre `d860556` (EK 829 · unit 1356 · 0 rojos · Release 0): **198 de 254 (78,0 %)** |
| `v2i/integ-r27` | `e2709d9` (suma E6a T6 y E2b T10, 🟢) + `tasks.md` (`05149e5`) + los docs del cierre (`v2i/docs-r27`) |
| Progreso | **198 de 254 en `version-2`; 200 de 254 (78,7 %) con E6a T6 y E2b T10 ✅** si el `rapido4` de la punta da VERDE |
| `rapido4` de la punta | RAPIDO_PENDIENTE |
| Bloqueadas | ninguna nueva. **E4b T4 destraba la cadena larga E4b T6 → T9 → E5b T2.** E6a T6 destraba E6a T7. E12 T12 ⛔ (espera a E9b T8) |

`rapido` de la tanda, en orden: `45b10c9` VERDE (EK 827 · unit 1336 · 0 rojos · Release 0; E6a T4 ✅, 195 de 254); `41d98c7` VERDE (EK 829 · unit 1341; E5b T4 y T6 ✅, 197);
`d860556` VERDE (EK 829 · unit 1356; E4b T4 ✅, 198). Tres `rapido` seguidos en VERDE, ninguno con flake. No hubo `completo` en esta ola: el último de referencia sigue siendo el de los cierres del 23 (sobre `bab8a9c`).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E6a T4** `oro_shop.json` | `ac5af90` (merge `1b13cb8`, claves `45b10c9`) | tarea VERDE (46 tests, con el snapshot de claves aplicado a mano); sin revisión opus (sólo contenido, sin plata en vuelo), diff leído por el controlador. `rapido` VERDE (unit 1336) → ✅ | 13 ítems; `GameContent.oroShop`; `OroShopCopy`; `validate(oroShop:)` con `isFinite` y el nivel de mejor proveedor contra `packages.json`; 20 claves. Destraba E6a T6 y E2b T10 |
| **E5b T4** la Ruleta en Regalos | `223b772` (merge `52345de`, claves `41d98c7`) | `WheelUITests` 3/3 en SE (giro + `repeat`, doble toque con 2 giros deja 1, giro bloqueado durante el video de `repeat`); sin revisión opus (UI sin plata nueva: el candado es de T1). DONE_WITH_CONCERNS. `rapido` VERDE (unit 1341) → ✅ | `WheelGiftCard` y sección «La Ruleta» en `GiftsView` entre cofres y diario; `WheelView` empujada en la misma hoja; el subtítulo usa `wheelAvailability(storefrontAllows: false)` (sólo gratis/video; el gate real vive en `WheelView`); 6 claves |
| **E5b T6** `wheel_ready` | `59e2ea1` (merge `90dfe3d`, claves `41d98c7`) | tarea con 1 rojo esperado (`copyNeverSells` sin snapshot), verde con las claves; EK 829; sin revisión opus. DONE_WITH_CONCERNS. `rapido` VERDE (unit 1341) → ✅ | `NotificationKind.wheelReady` al final de `notifications.json` (prioridad más baja); `NotificationSnapshot.wheelSpinsReadyAt`; `GameState.wheelSpinsReadyAt(now:)` gregoriano fijo, futuro sólo hasta mañana; avisa sólo si hoy hubo giro por video; 3 claves |
| **E4b T4** eventos con presentador; adiós al banner | `222ff56` + arreglos `1d77794` (merge `62eb52c`, claves `d860556`) | tarea VERDE (unit 124); UI 9/9 (`EventChip`, `Corralito`, `CharacterSheet`, `QuickHire`, `BonusHUD`) **antes** del arreglo; revisión opus: **Approved con arreglos**, hechos. `rapido` VERDE (unit 1356) → ✅ | presentador en escena y chip con su cara; `isBoardBusy` mira `visitorPopup`/`eventPopup`; `presentPendingEvent` antes de `advanceVisitors`; `eventIsApplicable` al llegar; fixture diferido; 6 claves |
| **E6a T6** comprar en la Tienda de ORO | `4aecfa1` + arreglos `9cf32d9` (merge `355d18c`, tasks `05149e5`) | tarea VERDE (EK 829 · unit 54, luego 56); revisión opus: **Changes requested**, arreglado. 🟢 (`rapido4`: RAPIDO_PENDIENTE) | `buyOroShopItem`: cobro y entrega en un paso con un guardado; Fusionar todo sin encolar restaura y no cobra; premio que no rinde → `.unavailable` antes de cobrar; 2º ×3 → `.refused(.alreadyPending)`; topes gregorianos; `Origin.oroShop` prepago; `bestSupplierLevel` en `openPackage`; `effectiveWheel`; `ShopPerks.swift`; sin claves (sin UI) |
| **E2b T10** presupuestos analíticos | `520f8d9` (merge `e2709d9`) | `PacingTests` VERDE (Dios 31,34 h intacto); sin revisión opus (tests y una constante de contenido), diff leído. DONE_WITH_CONCERNS. 🟢 (`rapido4`: RAPIDO_PENDIENTE) | `RewardBudget` enum compartido; `EngagementBudgetTests`: insumos finitos, visitantes + eventos dentro de lo que dejan diario y asado (12 % del día = 29,15 min), consumibles de ORO en el ancla 45–135 ORO/h; **`visitors.json` `coinsSecondsScale` 1 → 0,31**: visitantes 78,02 → 24,19 min/día, eventos 1,42, total 25,61 (87,9 %); `events.json` sin tocar; tocó `VisitorsContentTests:86` (pineaba la escala en 1; ahora 0 < escala ≤ 1) |

Merges en `integ-r27` (encadenados): E6a T4 `1b13cb8`; E5b T4 `52345de`; E5b T6 `90dfe3d`; E4b T4 `62eb52c`; E6a T6 `355d18c`; E2b T10 `e2709d9`. Los worktrees se borraron al integrar (E6a T4 1.620 MB, E5b T4 1.476 MB, E5b T6 1.688 MB,
E6a T6 1.783 MB, E2b T10 1.705 MB; el de E4b T4 también). Claves por snapshot aplicadas al integrar E6a T4 (20), E5b T4 y T6 (9 entre las dos) y E4b T4 (6). Progreso por `rapido`: 194 → 195 → 197 → 198 en `version-2`.

## La revisión de E4b T4: Approved con arreglos

El presentador cambia el turno de los eventos: por eso pasó por opus. Un obligatorio, hecho en `1d77794`:

1. **`completeArrival` escribía `.waiting` después de `arrive(&visit)`:** con T4 `startEvent` re-encola `.visitorEncounter` y un toque durante la entrada dejaba un fantasma en `current` (calma en `false`, charla congelada hasta un toque o el watchdog).
   Ahora se escribe `stageVisit` antes; test RED/GREEN con `skipCurrentCelebration`.

Pedidos hechos: `advanceEvents` no sortea con un `pendingEvent` (el segundo pisaba al primero con el enfriamiento ya gastado; test); el popup sólo ofrece salidas que sirven (`escapeStillRemoves`/`usableEscapes`) y `escapeEvent` da `false` si ya no saca nada
(Hiperinflación: ocultar la salida por video cuando ya no hay qué sacar; test).
Verificado bien: el turno (evento antes que visitante, misma puerta), `debugScript`/`calledScript`, `isBoardBusy`/`boardIsCovered`/`sheetOpen` ven `eventPopup`, `eventIsApplicable` al llegar sin colgados, sin doble cobro de cuota,
video sólo en `onRewarded`, sin eventos prepagos, save sin restos, `switch` exhaustivos, fixture diferido.
**Los UI tests no se re-corrieron tras el arreglo** (la tarea quedó VERDE por unit 124); el `rapido` no corre UI.
**Carries:** dueño (matar la app con un evento pendiente lo pierde con el enfriamiento gastado, sin cobro; el presentador que se va sin globo); E4b T6/T9 (`eventPresenters` nunca se vacía, menor; re-correr los UI de eventos).

## La revisión de E6a T6: Changes requested

Plata de ORO. Un obligatorio, hecho en `9cf32d9`:

1. **Doble cobro de Fusionar todo:** `planMergeAll` no ve la cola; con la tienda abierta la cola no avanza, así que un segundo toque cobra y encola pares duplicados que se descartan sin compensar (hasta 80 ORO perdidos).
   Ahora `mergeAllPairs` da 0 si hay un `.oroShop` o una cadena en `pendingBoardChanges`/`inFlight` → `.nothingToDo` antes de cobrar; test `mergeAllDoubleTap` (**sin RED comprobado**).

Pedidos hechos: un solo guardado (`scheduleSave` + `persistNow` duplicaban; ahora un `persistNow` que cancela el `saveTask`); `oroShopRows` filtra `canDeliver`; test con calendario no gregoriano (`gregorianDay`).
Verificado bien: cobro sobre copia y entrega en el mismo paso, restauración segura, segundo ×3 `.alreadyPending`, precios 90 → 113, ORO justo y −1, `canDeliver` 0/1, `chanceAllowed` sin default,
`effectiveWheel` sólo agranda `videoSpinsPerDay`, la reencarnación asienta la cola.
**Carries:** E6a T7 (`LootBoxGate` → `chanceAllowed`; ítems sin tope como `skin_chest` cobran dos veces con dos toques → la vista, de T8, deshabilita el botón mientras compra; `chestHasSomethingToGive` no cuenta `chestsPending`);
E6a T12 (gregoriano para días y enfriamiento); E2b (los boosts de la tienda multiplican: 3 × `income_x2` + 2 × `income_x3` = ×72 por 30 min);
dueño (el par de Fusionar todo descartado sin compensar es plata IAP; mover el reloj resetea los topes diarios; los boosts por tiempo se pierden al reencarnar → avisar en la UI; un kill en primer plano antes de asentar pierde los pares de Fusionar todo ya cobrados).

## Decisiones de la ola (sin decisiones nuevas del dueño)

- **Los visitantes pagan ~un tercio de lo que pagaban** (E2b T10): `coinsSecondsScale` 1 → 0,31 deja visitantes + eventos en 25,61 min/día (87,9 % de lo que dejan diario y asado). Es la lectura del presupuesto analítico; va al dueño como pregunta.
- **El obligatorio de Fusionar todo se resuelve antes de cobrar:** `.nothingToDo` si ya hay un cambio `.oroShop` o una cadena en cola o en vuelo.
- **La tarjeta de la Ruleta en Regalos no decide el gate:** el subtítulo mira sólo gratis/video (`storefrontAllows: false`); el candado real vive en `WheelView`.
- **`wheel_ready` es el aviso de menor prioridad:** con `maxPerAbsence` 3 y cuatro motivos, queda afuera si entran los otros tres.
- **Ningún `rapido` con una tarea mergeándose:** cada merge esperó al fin del oráculo en curso.

## Las trampas de la tanda

- **Los agentes lanzan `find /` buscando `v2-agente-protocolo.md`:** el archivo **no está versionado**; vive sólo en `.claude/worktrees/version-2/.superpowers/sdd/`, así que ningún worktree de tarea lo tiene. Los agentes de E5b T4 y E4b T4
  dejaron un `find /` colgado 40 min cada uno (ya habían entregado); se mataron los dos `bfs` por PID (77496 y 77505). **El brief tiene que dar la ruta absoluta del protocolo y prohibir `find /`** (los briefs de E6a T6 y E2b T10 ya lo decían; el agente de E6a T4 dijo no ver el archivo).
- **`limpiar-worktrees.sh --apply` procesa un solo worktree por llamada:** barrer varios exige un `--apply` por cada uno (con el shell fuera del worktree).
- **`maxPerAbsence` es 3 y hay 4 motivos de notificación** (E5b T6): `wheelReady`, de prioridad más baja, queda afuera si entran los otros tres. Subir el tope o aceptarlo es una decisión de E11/dueño.
- **`planMergeAll` no ve la cola** (E6a T6): con la tienda abierta la cola no avanza, un segundo toque cobra de nuevo y los pares duplicados se descartan sin compensar. Toda compra que encola cambios de tablero tiene que mirar `pendingBoardChanges` e `inFlight` **antes** de cobrar.
- **Un test sin RED comprobado no prueba el arreglo** (`mergeAllDoubleTap`): pedir el RED en el brief de todo arreglo de un obligatorio.
- **Una tarea de contenido que mueve una constante rompe el test que la pineaba** (E2b T10 tocó `VisitorsContentTests:86`): buscar con `grep` quién fija el valor antes de moverlo.
- **Los UI tests no se re-corren tras un arreglo de revisión** (E4b T4): la tarea queda verde por unit y el `rapido` no corre UI; el siguiente que toque ese archivo los corre.
- Siguen: el oráculo usa el repo de su propia ruta, `setsid` no existe en macOS, las EK puras no ocupan cupo, `rapido` uno por vez, la tabla de dueños va en cada brief, un `tarea` no corre UI, el reporte de arreglos que no llega,
  el modo auto que deja de aprobar `Bash` tras una denegación.

## Carries

| A | Qué |
|---|---|
| **E4b T6 / T9** | `eventPresenters` nunca se vacía (menor); re-correr los UI de eventos tras el arreglo; el presentador que se va sin globo |
| **E5b T2** | probar el doble cobro de ORO de la Ruleta (sin fixture de ORO el gate cierra en el simulador); confirmar que la vista lee Reduce Motion (por `simctl` no se vio); los de siempre: `wheel_frame` sin usar, los del colchón |
| **E6a T7** | `LootBoxGate` → `chanceAllowed`; `chestHasSomethingToGive` no cuenta `chestsPending`; ítems sin tope (`skin_chest`) cobran dos veces con dos toques |
| **E6a T8** | la vista deshabilita el botón mientras compra; avisar que los boosts por tiempo se pierden al reencarnar; reusar `OddsDisclosureView`/`RewardCopy` |
| **E6a T12** | gregoriano para días y enfriamiento; no ofrecer la Bienvenida en BE/AU |
| **E2b T9+** | los boosts de la tienda multiplican (3 × `income_x2` + 2 × `income_x3` = ×72 por 30 min); el simulador gasta el pendiente offline en ausencias cortas y apila con `*=`; los visitantes con la escala 0,31 |
| **E11 / E2b** | `maxPerAbsence` 3 con 4 motivos: `wheel_ready` queda afuera si entran los otros tres |
| **E7b-a T6/T7** | prueba con el anuncio real; `BonusHUDUITests` en orden |
| **E8d T15** | los gates G1–G5 en device son del dueño; el `completo` va solo |
| **E9b T8 / E12 / próximo `completo`** | los del 26 y anteriores (oferta reembolsada; `MenuPagerUITests` tras `MenuUITests`) |
| **Dueño** | ver «Para el dueño»; más los del 26 y anteriores |

## Para el dueño

- **Los visitantes pagan ~un tercio de lo que pagaban** (`coinsSecondsScale` 1 → 0,31, E2b T10): ¿se acepta o se sube la escala?
- **Fusionar todo en la Tienda de ORO:** un par descartado sin compensar es plata IAP; un kill en primer plano antes de asentar pierde los pares ya cobrados. ¿Se acepta?
- **Mover el reloj resetea los topes diarios de la tienda;** los boosts por tiempo se pierden al reencarnar (¿avisarlo en la UI?).
- **Matar la app con un evento pendiente lo pierde** con el enfriamiento gastado y sin cobro; **el presentador que se va, se va sin globo.**
- **`wheel_ready` queda afuera del aviso si entran los otros tres motivos** (`maxPerAbsence` 3 con 4 motivos): ¿se sube el tope?
- Sin pasada a mano de los eventos con presentador, de la Ruleta en Regalos ni de la Tienda de ORO en SE, iPad, modo oscuro, VoiceOver ni Reduce Motion.
- Siguen los del 26 (Offline ×3 y Diario ×3 con video dan ×6; la tabla de probabilidades de la Ruleta bajo el pliegue del SE; la pausa de 5 s fijos; borrar la rama remota `v2/e12-plan`), los del 25, 24, 23, 22 y 21c
  (**no publicar E7b-a T2 sin T3**: T3 ya está ✅). Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `45b10c9` VERDE (EK 827 · unit 1336); `41d98c7` VERDE (EK 829 · unit 1341); `d860556` VERDE (EK 829 · unit 1356); punta final con E6a T6 y E2b T10 (`e2709d9` + docs): RAPIDO_PENDIENTE.
- Todos los VERDE: 0 rojos, Release 0.
- UI sueltos: `WheelUITests` 3/3 (SE); `EventChip`/`Corralito`/`CharacterSheet`/`QuickHire`/`BonusHUD` 9/9 (antes del arreglo de E4b T4, no re-corridos).
- Sin `completo`: el de referencia sigue siendo el de los cierres del 23 sobre `bab8a9c`.

## Lo descartado

- Despachar nada más tras los 230k de contexto: se terminó E6a T6 y E2b T10 y se cerró.
- Mergear a `integ-r27` con un `rapido` corriendo: cada tarea esperó el fin del oráculo en curso.
- Revisión opus de E6a T4 (contenido), E5b T4 (UI sin plata nueva), E5b T6 y E2b T10 (el controlador leyó el diff).
- `TaskStop` a los agentes con el `find /` colgado: se mataron los `bfs` por PID (ya habían entregado).

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan por barrer `v2i-integ-r27` y `v2i-docs-r27` (con el shell fuera), más los de relevos anteriores si no se barrieron. Un `--apply` por worktree.
