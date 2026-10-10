# SESION 2026-10-10 — v2, relevo 28: el Apagón y los Campeones, las probabilidades del cofre, los especiales fuera del tablero y la Tienda de ORO en pantalla

La ola Z. El relevo 28 arrancó a las 12:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 27 lo soltó a las 11:37), la cuota en 5 h 6 % y semanal 61 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E6a T7 (probabilidades) y E6a T8 (la pantalla de ORO).
E4b T6 y E4b T9 no tuvieron revisión opus (sin plata ni save: las leyó el controlador; T9 sólo borra).
Todo pasó por **`v2i/integ-r28`** (BASE `version-2` en `87f205e`, 200 de 254). Carga de la máquina: 1,4 al arrancar; hasta 2 compilando más el `rapido`, con un pico de ~400. Los briefs salieron de `Tools/v2/brief.py`
(`v2i-integ-r28/.superpowers/sdd/ola-r28/`, con `duenos.md` y `duenos-2.md`). Latido: `scratchpad/latido2.sh` (`sleep 30`, escritura por reloj ≥ 9 min; el primero, con `sleep 600`, se reemplazó). El contexto pasó los 265k a las 13:42:
no se despachó nada nuevo después (E6a T8 y sus arreglos fueron lo último) y se cerró con los subagentes de tarea en 0.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | `a5ef14c`, la punta tras el `rapido3` VERDE (EK 838 · unit 1389 · 0 rojos · Release 0): **203 de 254 (79,9 %)** |
| `v2i/integ-r28` | `40f076e` (suma E6a T8, 🟢) + `tasks.md` + los docs del cierre (`v2i/docs-r28`) |
| Progreso | **203 de 254 en `version-2`; 204 de 254 (80,3 %) con E6a T8 ✅** si el `rapido4` de la punta da VERDE |
| `rapido4` de la punta | RAPIDO_PENDIENTE |
| Bloqueadas | ninguna nueva. **E4b T9 ✅ destraba E5b T2 (la cabecera de la cadena larga) y E4b T10;** E6a T7 ✅ destraba E6a T8 → T12. E8 T9 🔒 (elige el dueño). E12 T12 ⛔ (espera a E9b T8) |

`rapido` de la tanda, en orden: `b0ad1c2` **ROJO** (EK 838 · unit 1388 verdes · 1 rojo: `AudioManagerTests.eventAccents`), arreglo `a8289d5`; `a8289d5` **ROJO** (1 rojo: `GameLoopWiringTests.hireUnlockedNoticeWaitsItsTurn`, un flake bajo carga ~400: aislado, VERDE);
`a5ef14c` VERDE (EK 838 · unit 1389 · 0 rojos · Release 0; E4b T6, E6a T7 y E4b T9 ✅, 203 de 254). No hubo `completo` en esta ola: el último de referencia sigue siendo el de los cierres del 23 (sobre `bab8a9c`).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E6a T7** la suerte: probabilidades | `63692b6` (merge `431e291`) | tarea VERDE (EK 838 · unit 28), sin RED comprobado; revisión opus **Approved** (sin obligatorios). `rapido3` VERDE → ✅ | `ChestOddsTable` + `effectiveOdds` por el mismo `firstWithStock` que el roll; `reachableSkinCount`; `LootBoxGate.lastKnown` falla cerrado y se refresca en `StoreManager.start` salvo XCTest; `GameState.chestOdds`; `ChestRarityStyle.name/symbol`; `chestHasSomethingToGive` descuenta `pendingChestCount` (incluye prestigio); 0 claves |
| **E4b T6** el Apagón y los Campeones | `c756035` (merge `b0ad1c2`, arreglo `a8289d5`) | tarea VERDE (unit 10); `EventChipUITests` 1/1 y `CorralitoUITests` 1/1; sin revisión opus (sin plata ni save, diff leído por el controlador). `rapido3` VERDE → ✅ | `StageEffects`: velo ∝ velitas apagadas + 10 velitas; baile con `zRotation` y confeti cada 1,2 s; Reduce Motion deja velo/velitas; `runningEventScenes`/`blackoutCandles`/`lightCandleIfBlackout`; `registerTap` prende una velita; `SFX.blackout` por `accent(forEvent: apagon)`, que va en `eventAccents` y no en `declaredCases`; 0 claves; sin pasada a mano en SE/iPad |
| **E4b T9** los especiales salen del tablero | `0fc9ea9` (merge `0d3d327`, 2 claves quitadas `3a1b514`) | tarea VERDE (EK 838 · unit 63, siete clases por el `grep` de los símbolos borrados); UI Tutorial 8/8, CharacterSheet 3/3, QuickHire 3/3, BonusHUD 3/3, SpecialsAlbum 1/1; el diff sólo borra. `rapido3` VERDE → ✅ | se van `renderAnchoredSpecials`, `specialID`, el long-press, `specialInfo`, `visibleFloorSpecials`, `presentSpecialInfo`, `isRecap` y `debug.special.info`; `rollSpecialDrop` y `debugDropFirstSpecial` ya no anclan; `SpecialsOffTheBoardTests` sin RED |
| **E6a T8** la pantalla Comprar ORO / Gastar ORO | `93caa07` + arreglos `aaa8767` (merge `8cd96c5`, 12 claves `40f076e`) | tarea VERDE (unit 7); `OroShopUITests` 6/6 (26,5 s y 18,6 s), `StoreUITests` 2/2, `BottomMenu` 4/4; revisión opus: **Approved con arreglos**, hechos. 🟢 (el `rapido4` de la punta: RAPIDO_PENDIENTE) | selector Comprar/Gastar ORO en `StoreView`; `OroShopView` con `PurchaseLatch` de 0,6 s; `LootBoxGate.current` en `.task` (cerrado al arrancar); `ChestOddsDisplay` (`.coins` con copy, `.nothingYet` sin fila); avisos de reencarnar y ×3; `--uitest-oro` sólo DEBUG; 12 claves en `e6a-t8.json` |
| **E8 T9** Step 1 de la revisión de recortes | `2c805cc` (merge `a5ef14c`) | `unittest` del pipeline 89 OK; sin `xcodebuild`. → 🔒 | `revision_recortes.py` suma `npcs` + 3 `fam_*` y 4 sueltos de `ui`; sospechosos arriba; la página `~/Desktop/revision-v2/index.html` (359 recortes: earth 117, cosmic 57, npcs 52, 3 × 43 familias, ui 4) con el botón «Bajar decisiones.json» → `~/Downloads/decisiones.json` |

## Las dos revisiones opus

**E6a T7: Approved, sin obligatorios.** `effectiveOdds` sigue el embudo de roll; 20.000 sorteos deterministas (tolerancia 0,01 ≈ 3σ); el RED de `pendingChestsCountAgainstStock` es válido; `lastKnown` falla cerrado y no tiene llamadores con `true` fijo.
**Menores:** refrescar `lastKnown` antes de `loadProducts` (si el catálogo falla no se refresca nunca; falla cerrado); `lastKnownFailsClosed` sin dientes.
**Carries:** T12 recibe `chanceAllowed` por parámetro y lee `lastKnown` sólo en producción; T8 usa `chestOdds` con el copy de `.coins`/`.nothingYet`; `lastKnown` no observa `Storefront.updates`; E2b valida pesos no negativos de `ChestsConfig`;
dueño: la tabla no proyecta los cofres pendientes (3.1.1).

**E6a T8: Approved con arreglos.** Dos obligatorios, hechos en `aaa8767`:

1. **`.disabled(buyingLocked)` en `PricePill`** iba contra la regla de `GameArtComponents` (línea 507): durante los 0,6 s del cerrojo todo el estante parpadeaba.
   Ahora el cerrojo corta el cobro y no apaga el botón, y sólo corre cuando se cobra (sin blocker).
2. **El UI test del doble toque dependía del reloj:** rojo falso si el segundo `tap()` llegaba pasados los 0,6 s, y el `doubleTap()` pasaba aun sin el cerrojo.
   Ahora hay un unitario determinista de `PurchaseLatch` con RED visto (sin el guard → «ROJO NUEVO latch()»), restaurado, y el UI queda en `testOneTapChargesOnce`.

Menores hechos: «todas las pintas del cofre»; sin la nota «espera en Regalos» (no confirmada → carry). Verificado bien: el cerrojo global se suelta siempre, `buyOroShopItem` es síncrono, `chanceAllowed` arranca en `false`, el cofre se oculta con la puerta cerrada y `.nothingYet` no se compra,
Reduce Motion no condiciona, `--uitest-oro` sólo en DEBUG, las 12 claves están bien formadas.
**Carries (T12/dueño):** el cofre sin UI test (el gate es nil en el simulador); Reduce Motion por argumento sin confirmar; `store.subtitle` viejo en Gastar ORO; el ancla `.oroShop` sin consumidor;
`chanceAllowed` por aparición (escuchar `Storefront.updates` en T12); el `segment` no se reinicia si el paginador mantiene la vista; la tabla no proyecta los cofres pendientes.

## El pedido del dueño en el chat

A las 12:29 el dueño pidió tres cosas: (1) preparar la revisión de recortes de arte (E8 T9) para ir aprobando, (2) seguir el desarrollo en paralelo y (3) pasarle todas sus preguntas y gates.

1. **Hecho:** el Step 1 de E8 T9 (arriba). El dueño elige en la página y baja `decisiones.json`; un relevo lo aplica (Step 3) con `aplicar_revision.py`; los `.quitar` van con `catalogo.py quitar $(cat archivo)`, no con `aplicar`.
2. **Hecho:** E4b T9 y E6a T8 salieron en paralelo al `rapido2`, con una tabla de dueños aparte (`duenos-2.md`).
3. **Hecho:** **`.claude/avo/2026-10-06-fisu-v2/PREGUNTAS-DUENO.md`** con **A1–A10 (los gates)** y **B1–B26 (las preguntas, cada una con su default)**; copia sin commitear en `Docs/PREGUNTAS-DUENO-v2.md` del checkout principal. Enviado al dueño.
   **Sus respuestas se vuelcan a decisiones:** al journal, a este tipo de SESION, a `Docs/HANDOFF.md` §5 y a `tasks.md`.

## Decisiones de la ola (sin decisiones nuevas del dueño)

- **Las probabilidades del cofre fallan cerradas:** `LootBoxGate.lastKnown` dice que no mientras no haya una lectura, y T12 recibe `chanceAllowed` por parámetro.
- **El cerrojo de compra corta el cobro, no apaga el botón:** sin `.disabled` en `PricePill`; sólo corre cuando se cobra, y se prueba con un unitario con RED visto.
- **`SFX.blackout` va en `eventAccents`, no en `declaredCases`:** el apagón tiene acento propio; `AudioManagerTests.eventAccents` pasó de ocho a nueve.
- **Ningún `rapido` con una tarea mergeándose:** E6a T8 esperó al `rapido3` para entrar a `integ-r28`, y E8 T9 entró en el merge de `a5ef14c` cuando no corría el oráculo.

## Las trampas de la tanda

- **`AudioManagerTests.eventAccents` también pinea los acentos de eventos:** el agente de E4b T6 corrió `AudioWiringTests` pero no `AudioManagerTests`, y el `rapido1` cayó rojo (el test mismo pedía «sumalo a la lista»). Arreglo `a8289d5`. Una tarea que toca acentos corre las dos clases.
- **`GameLoopWiringTests.hireUnlockedNoticeWaitsItsTurn` es un flake bajo carga:** la carga llegó a ~400 con dos agentes compilando y el `rapido`; aislado verde y verde también en la tarea de E4b T9. Aislar la clase sola sobre la misma punta antes de declarar.
- **Los agentes re-entregan por esperas de fondo colgadas:** el de E6a T7 entregó el mismo reporte tres veces ya integrado, y el de E4b T6 también. `TaskStop` apenas estén entregados **e integrados** (la regla lo permite; se hizo a las 12:24 y a las 12:29).
- **Un `doubleTap()` de XCUITest no prueba un cerrojo, y dos `tap()` dependen del reloj:** el cerrojo se prueba con un unitario con RED visto.
- **`.disabled` en `PricePill` va contra la regla de `GameArtComponents`.**
- **`.quitar` se aplica con `catalogo.py quitar $(cat archivo)`, no con `aplicar`.**
- **El latido con `sleep 600`:** el primero del 28 lo era; se detuvo por PID y se reemplazó por `latido2.sh` (`sleep 30`, escritura por reloj ≥ 9 min).
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`» (esta vez no hubo `find /` colgado), las claves por snapshot, un `tarea` no corre UI, `rapido` uno por vez, `setsid` inexistente en macOS, el reporte de arreglos que no llega.

## Carries

| A | Qué |
|---|---|
| **E4b T10** | `eventPresenters` acotado por id (nunca se vacía); `Array(characterNodes.values)` por frame; la `zRotation` del baile se comparte con el deambular; `meta.specialAnchors` sin escritores (se borra en el próximo bump de schema); el presentador que se va sin globo |
| **E5b T2** | probar el doble cobro de ORO de la Ruleta (sin fixture de ORO el gate cierra en el simulador); confirmar que la vista lee Reduce Motion; `wheel_frame` sin usar; los del colchón; cerrojos con unitario con RED |
| **E6a T12** | `chanceAllowed` por parámetro y por aparición (escuchar `Storefront.updates`); gregoriano para días y enfriamiento; no ofrecer la Bienvenida en BE/AU; el cofre sin UI test; `store.subtitle` viejo; ancla `.oroShop` sin consumidor; el `segment` que no se reinicia |
| **E6a (menores de T7)** | refrescar `lastKnown` antes de `loadProducts`; `lastKnownFailsClosed` sin dientes |
| **E2b** | validar pesos no negativos de `ChestsConfig`; los boosts de la tienda multiplican (×72 por 30 min); el simulador gasta el pendiente offline en ausencias cortas; los visitantes con la escala 0,31 |
| **E11 / E2b** | `maxPerAbsence` 3 con 4 motivos: `wheel_ready` queda afuera si entran los otros tres |
| **E7b-a T6/T7** | prueba con el anuncio real; `BonusHUDUITests` en orden |
| **E8d T15** | los gates G1–G5 en device son del dueño; el `completo` va solo |
| **E8 T9** | Step 2: elige el dueño; Step 3: un relevo aplica con `aplicar_revision.py` |
| **Dueño** | ver «Para el dueño»; más `PREGUNTAS-DUENO.md` y los del 27 y anteriores |

## Para el dueño

- **`PREGUNTAS-DUENO.md`** (A1–A10 gates, B1–B26 preguntas con default): sus respuestas se vuelcan a decisiones.
- **Elegir en la página de recortes:** `~/Desktop/revision-v2/index.html` (359 recortes, los sospechosos primero) y bajar `decisiones.json`.
- **La tabla de probabilidades del cofre no proyecta los cofres pendientes:** ¿alcanza para 3.1.1 o se proyecta?
- Sin pasada a mano del Apagón y los Campeones, ni de la Tienda de ORO (Comprar/Gastar) en SE, iPad, modo oscuro, VoiceOver ni Reduce Motion.
- Siguen los del 27 (los visitantes pagan ~un tercio; Fusionar todo con el par descartado sin compensar; los topes que resetea el reloj; los boosts por tiempo que se pierden al reencarnar; el evento pendiente que se pierde al matar la app; `wheel_ready` fuera del aviso con 4 motivos),
  los del 26, 25, 24, 23, 22 y 21c (**no publicar E7b-a T2 sin T3**: T3 ya está ✅) y borrar la rama remota `v2/e12-plan`. Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `b0ad1c2` ROJO (EK 838 · unit 1388 · 1 rojo: `AudioManagerTests.eventAccents`); `a8289d5` ROJO (1 rojo: `GameLoopWiringTests.hireUnlockedNoticeWaitsItsTurn`, flake bajo carga, aislado VERDE); `a5ef14c` VERDE (EK 838 · unit 1389 · 0 rojos · Release 0);
  punta final con E6a T8 (`40f076e` + docs): RAPIDO_PENDIENTE.
- UI sueltos: `EventChipUITests` 1/1 y `CorralitoUITests` 1/1 (E4b T6); Tutorial 8/8, CharacterSheet 3/3, QuickHire 3/3, BonusHUD 3/3 y SpecialsAlbum 1/1 (E4b T9); `OroShopUITests` 6/6, `StoreUITests` 2/2 y `BottomMenu` 4/4 (E6a T8).
- Sin `completo`: el de referencia sigue siendo el de los cierres del 23 sobre `bab8a9c`.

## Lo descartado

- Despachar nada más tras los 265k de contexto: se terminó E6a T8 (revisión y arreglos) y el `rapido3`, y se cerró.
- Revisión opus de E4b T6 (sin plata ni save) y de E4b T9 (sólo borra): el controlador leyó el diff.
- El doble toque como prueba del cerrojo (UI con `doubleTap()` o dos `tap()`): se reemplazó por un unitario con RED visto.
- El `.disabled` en `PricePill` como cerrojo visible: va contra la regla de `GameArtComponents`.

## Cierre

- Subagentes de tarea en vuelo: 0 al despachar los docs del cierre. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla (el journal registra el borrado de los de E4b T9, E8 T9 y E6a T8; los de E4b T6 y E6a T7 hay que verificarlos); quedan por barrer `v2i-integ-r28` y `v2i-docs-r28` (con el shell fuera), más los de relevos anteriores si no se barrieron. Un `--apply` por worktree.
