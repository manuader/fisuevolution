# SESION 2026-10-10 — v2, relevo 23: la mudanza a eventos v2, el Paquete en la partida, el simulador de pacing con perfiles y los tres cierres

La ola U. El relevo 23 arrancó a las 00:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 22 lo soltó), la cuota en 5 h 3 % y semanal 55 %.
Controlador opus; implementadores sonnet (opus sólo en E2b T4) en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E4a T9 y E5a T6 (las dos tocan
save o el turno del tablero). Todo pasó por **`v2i/integ-r23`** (BASE `version-2` en `3982dc0`). Carga de la máquina: 1,2 → 19 → 220 (el `rapido` y E5a T5 compilando a la vez)
y de vuelta; tope de 2 compilando cuando pasaba de 200. Los briefs salieron de `Tools/v2/brief.py`. Latido: `scratchpad/latido.sh` (`sleep 30`, escritura por reloj). El contexto
llegó a 258k a las 00:54: no se despachó nada nuevo después, se terminaron E5a T6 y los cierres.

La sesión de los cierres (el `completo` de E8, E13b y E13) tiene su propio documento: **`Docs/SESION-2026-10-10-v2-cierres-r23.md`**. Acá no se repite.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`2e51d29`** tras el `rapido` VERDE sobre `9dcf469` (EK 814 · unit 1175 · 0 rojos · Release 0); **174 de 254 (68,5 %)** |
| `v2i/integ-r23` | `5fca66d`: suma los cierres (E8 T10, E13b T11, E13 T14, 🟢 las tres) y el arreglo del panel de debug (`534fd51`) sobre `2e51d29` |
| Progreso | **174 de 254 en `version-2`; 177 de 254 (69,7 %) con las tres 🟢** si el `rapido` de la punta da VERDE: VERDE (EK 814 · unit 1175 · 0 rojos · Release 0) |
| Bloqueadas | ninguna nueva. E7b-a T3 sigue ⛔ y es **bloqueo de publicación**; E12 T12 ⛔ (espera a E9b T8) |

`rapido` de la tanda, en orden: `ed85656` VERDE (EK 784 · unit 1143 · 0 rojos · Release 0); `a997a30` VERDE (EK 791 · unit 1154 · 0 rojos · Release 0); `9dcf469` VERDE
(EK 814 · unit 1175 · 0 rojos · Release 0); la punta con los cierres (`5fca66d`): VERDE (EK 814 · unit 1175 · 0 rojos · Release 0). El `completo` de los cierres (sobre `bab8a9c`) está en su documento.

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E6a T2** catálogo y cuentas de la tienda (EK) | `5577542` | EK 751; sin revisión (copia del plan, archivos nuevos) | `OroShopCatalog`/`OroShop` + 16 tests; el ×3 sin id por compra |
| **E6a T10** las ofertas de 24 h, puras | `f10a867` | EK; sin revisión (copia del plan, diff leído) | `OffersCatalog`/`OffersEngine` + 11 tests; `lastClosedAt` en todo vencimiento y compra, también **fuera de ventana**: el test del brief decía `nil` y se corrigió a `9999` |
| **E9b T7** `ResetPlan` puro | `9ed20ad` | EK; diff leído. DONE_WITH_CONCERNS | Conserva compras, ORO comprado sin gastar, `offers.everOpened`/`purchases`/`lastClosedAt` y `seenCinematics`; `floorChestsAwarded` en 0 desde `fresh`; `recordOroPurchase` sólo anota, no acredita. Carry a T8 abajo |
| **E2b T3** el simulador cobra como el juego | `2b1a024` | EK 778; diff leído, sin balance movido | Pasivo, offline y cotización por las funciones del juego; 7 tests de fidelidad; Dios 31,34 h · 13 reenc. sin cambio; sólo bajan las columnas de costo por el descuento de las líneas |
| **E6b T6** lugares extra (EK) | `1778826` | EK 784; diff leído | `FloorDef.withCapacity`, `FloorTable.expanded(by:)`, 6 tests |
| **E4a T9** la mudanza a eventos v2 | `a0c4e67` + arreglos `dec7ed5` | tarea VERDE (EK 735 · unit 132 en 12 clases); revisión opus: Approved con arreglos, hechos; `CorralitoUITests` PASS en SE; captura SE de `paro_general` vista por el controlador | Ver «Desvíos de E4a T9» |
| **E2b T4** política de pisos en marcha del bot (opus) | `babe9e8` | EK 791; diff leído (simulador) | Cambió la regla del bot con medición (abajo) |
| **E2b T11** la herencia en pantalla | `0534489` | tarea VERDE 12/12; diff leído | `PrestigePreview.inheritedPassives` con la **misma función que reencarna**; fila en `PrestigeView`; 1 clave; sin captura SE |
| **E2b T5** perfiles y fuentes gratis | `791db7b` | EK 796; 5 tests | `PacingProfile` `.bare`/`.free`/`.ads`/`.max` + `PacingSources`; tabla abajo |
| **E2b T6** el perfil `.ads` | `4e7840b` | EK 814; 18 tests | tabla abajo |
| **E5a T5** `packages/treasures/wheel.json` | `9a9cd26` | tarea VERDE (app 45 · EK 791); 6 tests; sin claves | `GameContent.packages`/`.treasures`/`.wheel`, premios validados con `validatePrize` |
| **E5a T6** el Paquete en la partida | `30807ce` | tarea VERDE (unit 62 · EK 796); revisión opus: Approved | `GameState+Packages`: buzón, candidatos por `PackageRoller` (= las filas de FisuJobs), abrir/devolver |
| **E8 T10 · E13b T11 · E13 T14** los cierres | `534fd51`, `427ebc5` (merge `0602b7d`), `5fca66d` | un `completo --limpio` sobre `bab8a9c` | `Docs/SESION-2026-10-10-v2-cierres-r23.md` |

Merges en `integ-r23` (encadenados, cada uno con su EK/`rapido`): E6a T2 + T10 + E9b T7 `34cbc17`; E2b T3 → `fd52395`; E6b T6 `ed85656`; E4a T9 + 38 claves aplicadas y 9 quitadas `a997a30`;
E2b T11 + T5 + E5a T5 `bab8a9c`; E2b T6 y E5a T6 (`9dcf469`). Los worktrees se borraron al integrar (886 MB el de E2b T3, 1.582 MB el de E4a T9).

### Desvíos de E4a T9 (la llave de la cadena)

- `events.json` pasa a schema 2 con los 18 eventos; `GameState+Events` y `GameState+Engagement` nuevos; se van `EventManager` y `EventsConfig`. **38 claves nuevas y 9 a quitar** por snapshot.
- `Startup` con `startupTiersBelowFrontier = 2`; acento genérico para 10 eventos (8 con acento propio tras el arreglo).
- Tests reescritos fuera del brief: `CareerReward`, `BoardChangeProducers`, `AudioManager`/`Wiring`.
- Carries del brief resueltos: el reset de debug ya reemplazaba el `player` (test sumado), `.visitor` intacto (no prepago), `grantableRewardKinds` respetado; **`isCalmMoment` no se unificó** (`naturalBreakContext`
  suma `fullScreenUI`/`adOnScreen`).
- Revisión opus, obligatorios hechos en `dec7ed5`: `home_banking` → acento de Mercado Pago y se saca el id fantasma `cayo_mercado_pago` de `AudioWiringTests` (el test se había debilitado);
  `advanceEngagement` fuera del comentario del watchdog de `+FrameLoop`; la cuota sin plata no se atenúa (→ E4b). Save viejo y reloj: OK según la revisión.

### Lo que midió E2b T4 y por qué se desvió del brief

La regla literal («el piso que se llena no se fusiona») **nunca completaba un piso con capacidad 10/15** porque cada contratación se fusionaba antes de llenarlo. Ahora el piso que se llena
no se fusiona y el objetivo se busca debajo del piso de compra; `fillingSurvivesTheMerges` (cap 10) lo discrimina. Base sin bono **idéntica byte a byte** (Dios 31,34 h · 13 reenc.); con bono 0,05 y
cap 10/15: Dios 25,76 h · 11 reenc. · 7 pisos en marcha. Dudas a **T8** (imprimir `maxStaffedFloors`) y **T13** (cap 10 vs 15 casi igual).

### Los perfiles del simulador (E2b T5 y T6)

La vara de cada tarea fue «la base queda idéntica línea por línea» antes de sumar fuentes. T5: determinismo por ritmo ±5 % en vez de ±2 paquetes; `markSeen` en contratar/fusionar; cotización con reloj;
`PackageEngine.eligibleTypes(occupancy:)` sin cambio para la torre. T6:

| Perfil | Dios | Reencarnaciones | Notas |
|---|---|---|---|
| base | 31,34 h activas (pared 561 h) | 13 | sin cambio |
| `.free` | 28,05 h | | |
| `.ads` | 23,71 h | 13 | 662 videos |

Aceptado: el offline ×2 a 1 día llega antes a Dios y suma menos offline total. «Fusionar todo» literal aunque sea pérdida neta para el bot → **E2b T13**.

## Las revisiones opus y sus carries

- **E4a T9** (arriba). **A E4b:** el presentador re-chequea `eventIsApplicable`; `loops_manifest` `events.cayo_mercado_pago` → `home_banking`; atenuar la cuota sin plata. **Previos, al dueño/E1:** `.eventStartup` y `.eventBlanqueo`
  no son prepagos si se mata la app. **A EK:** `startupTiersBelowFrontier` al schema. **Al dueño:** el video de salida no sirve si el evento vence mientras corre.
- **E5a T6** (Approved, sin obligatorios; todos los caminos devuelven el paquete; sin `syncCelebrations` está bien: `flushHUD` a 8 Hz lo encola y una llegada no abre tier). **Opcionales a la UI del paquete (E5b):**
  - `packageCandidates` no descuenta las llegadas en cola: un doble toque devuelve el paquete al buzón sin aviso y «LLENO» miente.
  - `advancePackages` guarda sólo al caer un paquete.
  - Las llegadas asentadas al pasar a inactivo entran sin animación (dueño).
  - Desvío deliberado: descartar devuelve al buzón sin compensar el video.
- **E9b T7 → T8:** `resolveAcrossReset` **todavía no une `offers.purchases` ni `seenCinematics`** desde el lado viejo.
- **E5a T5:** validadores `isFinite` en `PackagesConfig`/`TreasuresConfig`/`WheelConfig`/`RewardSpec.validate` (EK, no calientes).
- **E6a T2/T10 → T11:** el ×3 sin id por compra; T11 acredita aunque la oferta ya no figure abierta (carry del 22, vigente).
- **E2b T11:** sin captura SE del popup de reencarnar con la fila nueva.

## El bug que encontró el `completo`: el panel de debug

(Detalle y números en la sesión de los cierres.) E4a T9 puso el menú «Disparar un evento» en la sección Offline del `DebugPanelView`, arriba de las puertas de los UI tests; la `List` perezosa dejó
`debug.floor.fill` y `debug.quickhire.many` bajo el pliegue y 3 UI tests dieron rojo (`534fd51`). Un `tarea` no corre UI, así que ni la tarea ni el `rapido` lo vieron.
**Regla nueva:** quien toque `DebugPanelView` corre `CharacterSheetUITests` y `QuickHireUITests` (y `BonusHUDUITests`). Va en el brief de toda tarea que lo toque (E3b T9 ya lo tocó, E4b T1/T2/T4/T9, E5b T2, E6b T2, E7b-a T3/T6 lo van a tocar).

## Las trampas de la tanda

- **El clasificador del modo auto no deja escribir en `.claude/worktrees/version-2/.superpowers/`** ni crear archivos ahí: la escritura de `ola-r23-duenos.md` (la tabla de dueños de la ola) se frenó. La tabla de dueños
  va **en cada brief de despacho**. Los briefs nuevos quedaron en `.superpowers/sdd/` del worktree `v2i-integ-r23` (gitignoreado y efímero: no es un lugar para guardar nada).
- **Un `tarea` no corre UI.** Si la tarea toca un archivo que las UI leen por accesibilidad (el panel de debug), el rojo sale recién en el `completo`.
- **Las EK puras terminadas esperan al `rapido`:** E2b T11/T5 y E5a T5 quedaron en su worktree hasta el VERDE de `a997a30` y se mergearon juntas; el `rapido` de la punta siguiente las cubrió.
- **Una regla de bot «literal» puede no ejecutarse nunca** (E2b T4): el test que discrimina (cap 10) es lo que la hizo visible; en los simuladores, siempre comparar la base sin la perilla byte a byte antes de medir con ella.
- Siguen: el oráculo usa el repo de su propia ruta, `setsid` no existe en macOS, `rapido` uno por vez.

## Para el dueño

- E4a T9: el video de salida no sirve si el evento vence mientras corre; `.eventStartup`/`.eventBlanqueo` no son prepagos al matar la app (previo).
- E5a T6: las llegadas asentadas al pasar a inactivo entran sin animación.
- E8 T10 (memoria): un viaje 1 → 10 a mano en un SE real; ya tiene las tres grabaciones del ascensor (sesión de los cierres). Sin 🔒 de ODR.
- Siguen los del 22 (E3b T9, E6a T1, E12 T15 / `NSPrivacyTracking`) y los del 21c (**no publicar E7b-a T2 sin T3**). Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `ed85656` · `a997a30` · `9dcf469` VERDES (arriba). Punta con los cierres: VERDE (EK 814 · unit 1175 · 0 rojos · Release 0).
- `completo --limpio` sobre `bab8a9c`: ver la sesión de los cierres (3 rojos de UI reales y arreglados; 1 rojo de carga del store que pasa aislado).

## Lo descartado

- Despachar E7b-a T3: sigue ⛔ (faltan **E5b T1, E4b T3**; E5a T6 ya está ✅).
- Más despacho tras los 258k de contexto: se terminaron E5a T6 y los cierres y se cerró.
- Unificar `isCalmMoment` con `isSafeMomentForInterstitial` en E4a T9: lo hace E7b.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan por barrer `v2i-integ-r23`, `v2i-cierres-r23` y `v2i-docs-r23` (con el shell fuera).
