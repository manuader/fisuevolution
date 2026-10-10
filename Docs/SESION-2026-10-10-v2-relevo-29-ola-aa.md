# SESION 2026-10-10 — v2, relevo 29: la pinta comprada con ORO, los accesos y las hojas de los premios, y el primer `completo` verde desde el 23

La ola AA. El relevo 29 arrancó a las 15:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 28 lo soltó a las 14:10), la cuota en 5 h 2 % y semanal 62 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E6b T4 (plata de ORO y save) y E5b T2 (la Ruleta por ORO, el colchón y las hojas).
Los dos cierres (E4b T10 y E5a T9) son sólo docs: los hizo un sonnet en `v2i-cierres-r29` y el controlador leyó el diff.
Todo pasó por **`v2i/integ-r29`** (BASE `version-2` en `73f5494`, 204 de 254). Carga de la máquina: 2,3 al arrancar; 160 con E5b T2 compilando; 23 cuando se lanzó el `completo` solo. Los briefs salieron de `Tools/v2/brief.py`
(`v2i-integ-r29/.superpowers/sdd/ola-r29/`, con `duenos.md`). Latido: `scratchpad/latido.sh` (`sleep 30`, escritura por reloj ≥ 9 min, se corta solo si el `LOCK` deja de ser mío). El contexto llegó a 228k a las 16:25 y a ~240k al cierre:
no se despachó E8d T15 (su Step 1 necesita código nuevo) y se cerró con los subagentes de tarea en 0.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | `236080b`, la punta tras el `completo` VERDE de `integ-r29` sobre `7c494ea`: **208 de 254 (81,9 %)** |
| `v2i/integ-r29` | `7c494ea` (+ `tasks.md`) y los docs del cierre (`v2i/docs-r29`) |
| Progreso | 204 al llegar → 205 (E6b T4, `rapido` VERDE sobre `26df563`) → **208** (E5b T2, E4b T10 y E5a T9, `completo` VERDE) |
| `completo` | VERDE: EK 845 · unit 1417 · store-unit 18 · store-ui 2 · iPad 4 · SE 2 · pipeline 89 · pacing-sim ✅ · Release 0; UI 129 verdes + 2 rojos por orden, aislados VERDES |
| Bloqueadas | ninguna nueva. **E5b T2 ✅ destraba E5b T3, E5b T5, E6a T12 y E7b-b T1 (ahora ⏳).** E8d T15 sigue ⏳. E8 T9 🔒 (las elecciones del dueño ya están en `~/Desktop/revision-v2/decisiones.json`) |

`rapido` de la tanda: `26df563` VERDE (EK 845 · unit 1403 · 0 rojos · Release 0; E6b T4 ✅, 205 de 254). No hubo `rapido` de E5b T2: entró directo al `completo` (nada compilando al lado, carga 23).
Es el primer `completo` desde los cierres del 23 (sobre `bab8a9c`): cubre además E4b T10, E5a T9 y todo lo integrado en los relevos 24 a 28.

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E6b T4** la pinta comprada con ORO es tuya | `fa6b4cc` + arreglos `08fbf82` (merge `d6b8450`, 1 clave `26df563`) | tarea VERDE (EK 845 · unit 17); `CharacterSheetUITests` 3/3 y `CustomizationUITests` 5/5; RED visto del guard `alreadyOwned`; revisión opus **Approved con arreglos** (sin obligatorios), hechos. `rapido` VERDE → ✅ | `OroShop.purchaseSkin`: `alreadyOwned` **antes** de `spendOro`, y la pinta a `shop.skins`; `allOwnedSkins` une `shop.skins`; `buySkinWithOro` síncrono, un solo guardado; `.oroPurchasable` en `skinState`; `PricePill(.oro)` sin `.disabled` en Pintas y en la ficha; `purchaseSkin` rechaza `price <= 0` (`invalidPrice`, con RED); `alreadyOwned` sale como `.unavailable`; tocó `SkinCatalogRowsTests` (`switch` exhaustivo); 1 clave `e6b-t4.json` |
| **E5b T2** los accesos y las hojas | `18e45d1` + arreglos `a502ef6` (merge + 10 claves `7c494ea`) | tarea VERDE (unit 51); UI Prizes 2/2, Wheel 4/4, BonusHUD 3/3 (y, antes de los arreglos, CharacterSheet 3/3, QuickHire 3/3, EventChip 1/1, Visitor 3/3); revisión opus **Approved con arreglos** + un **BUG ALTO** de T1, hechos. `completo` VERDE → ✅ | `PrizeAccess`, `+Prizes`, `PrizeChips`, `MattressPopupView`, `StageChips`, `DebugPanelView`; las hojas nuevas en **`PrizeSheets`, un `ViewModifier`** (`RootView.body` quedó al límite del type-checker); `refreshPrizeAccess` en `+Projections`; `isBoardBusy` (`+Ads`) suma `mattressPopup` y `wheelSheet`; Reduce Motion leído en los chips; 10 claves `e5b-t2.json`; RED visto de los dos cerrojos del colchón |
| **E4b T10** cierre de E4 | `b25a52e` (merge `6ff2b2c`) | sólo docs; diff leído | `Docs/SESION-2026-10-10-v2-e4b.md` + `HANDOFF` §4 + nota en `PLAN-v2`; `COMPLETO_PENDIENTE` → resuelto por el `completo` de esta ola. 🔒 dueño: siete escenarios |
| **E5a T9** cierre de E5a | `a8a8591` (merge `6ff2b2c`) | sólo docs; diff leído | `Docs/SESION-2026-10-10-v2-e5a.md` + `HANDOFF` §4/§5/§7/§9 + nota en `PLAN-v2`. 🔒 dueño: tres escenarios |

## Las dos revisiones opus

**E6b T4: Approved con arreglos menores (sin obligatorios).** Verificado bien: sin doble cobro (`MainActor` síncrono); cobro y entrega atómicos; `applyStoreEntitlements` filtra contra `allOwnedSkins`; `shop.skins` vive en `meta` y sobrevive a la reencarnación;
`ShopState.resolve` une `skins`; todos los `switch` cubiertos. Pedidos devueltos al implementador, hechos en `08fbf82`: el `axValue` de `.oroPurchasable` con `price.ax.oro` y el comentario movido; la unión redundante fuera de `ResetPlan`;
`purchaseSkin` rechaza `price <= 0` (con RED: `0` regalaba, `-50` daba `cantAfford`); comentarios de `TowerSync`/`TutorialTips`.
**Carries:** dueño/E9b T8 — **el reset de cuenta pierde las pintas de ORO** (la pantalla del reset debe decirlo en `skinsLost`); dueño — **el logro `skinsAll` ahora exige comprar las 3 familias** (1350 ORO); E6b T5 — la leyenda «incluye 43» (`packSize` es `nil` para `.oroPurchasable`); E6a T12 — `.unavailable` cubre `alreadyOwned`.

**E5b T2: Approved con arreglos (sin obligatorios propios de T2) y un BUG ALTO heredado de T1.**

1. **BUG ALTO, `WheelView` (de E5b T1): el video se veía y no pagaba.** `videoBusy` entraba en el guard de los callbacks premiados; al apagarse en el siguiente `onChange`, el callback del video de giro/repetir encontraba el guard cerrado y **no acreditaba**. El jugador miraba el anuncio entero y no recibía el giro.
   Arreglo (`a502ef6`): `videoBusy` fuera del guard del giro por video, y el cerrojo del giro por ORO pasó de `.disabled(locked)` (contra `GameArtComponents`) a `PurchaseLatch` por `GameState.beginWheelSpin`, testeable con RED.
   Tests: `oroSpinChargesOnce` (RED visto) y el UI test que mira el pago. **`testTheVideoSpinSpinsAndCountsDown` no tuvo RED contra el viejo** (anotado).
2. **`openWheel` sin guard de `isBoardBusy`:** el hueco de 0,3 s tras `finishVisit` apilaba la hoja y trababa `uiCoversBoard`. Ahora `openWheel` exige `!isBoardBusy`; **si el tablero no está calmo, el giro queda en Regalos** (`bonusSpins`). RED visto: `theWheelWaitsForACalmBoard`, `theHostOpensTheWheel`.
3. **`packageTapped` no descontaba `pendingBoardChanges`/`inFlight`:** con 2 paquetes y 1 lugar el chip rebotaba y «LLENO» nunca salía. Ahora `packageCandidates` cuenta la cola y lo que vuela (RED visto: `queuedArrivalsTakeTheRoom`). Puede dejar «LLENO» un instante de más: es conservador.
4. **El popup del colchón:** `isBusy` + `interactiveDismissDisabled`. 5. `wheelOpensAfterVisit` sólo con `visitorPopup`. 6. Reduce Motion reactivo en `MattressChip`.

Verificado bien: los dos cerrojos del colchón tienen RED visto; `refreshPrizeAccess` en `+Projections`; las 10 claves.
**Carries:** E7b-b T1 reusa `packageTapped`/`mattressTapped`/`openWheel`; E5b T3 'LLENO' de la misma cuenta; `wheel_frame` sin usar; dueño — matar la app con el popup del colchón abierto pierde el 'otro colchón'.
Los UI de CharacterSheet, QuickHire, EventChip y Visitor **no se re-corrieron tras los arreglos**: los corrió el `completo` (verdes).

## El `completo`

`completo` de `integ-r29` sobre `7c494ea`, lanzado **solo** a las 16:25 (nada compilando, carga 23; `build/relevo29-completo.log`, PID 54308) y terminado a las 17:43: **VERDE.**
EK 845 · unit 1417 · store-unit 18 · store-ui 2 · iPad 4 · SE 2 · pipeline 89 · pacing-sim ✅ · Release 0 · UI 129 verdes + **2 rojos**:

- `MenuPagerUITests.testDeslizarYLasFlechas…` y `CustomizationUITests.testElCarrusel…` (navegación de menú).
- **Aislados sobre la misma build, VERDES:** Customization 5/5, MenuPager 2/2. Es la contaminación por orden de los UI tests de un mismo simulador (carry conocido de E12: `--uitest-reset` no apaga el ranking). **No son regresiones de esta ola.**
- Declarado VERDE: E5b T2, E4b T10 y E5a T9 → ✅; `version-2` ff → `236080b`, pusheado. Se reemplazaron todos los `COMPLETO_PENDIENTE` (SESION de e4b y e5a, `HANDOFF` §4, `PLAN-v2`).

## Pedidos del dueño en el chat (fuera del relevo)

El `LOCK` era del relevo 29; el dueño trabajó en paralelo en su sesión:

- **15:29** mandó sus elecciones de recortes (354: 113 rembg; a regenerar: `cartonero__diamante`, `mantero__diamante`, `estanciero_estelar__tropero`, `senior_doctor`) → `~/Desktop/revision-v2/decisiones.json`. Además pidió el balde de islas y respuestas sobre las animaciones de Higgsfield.
  Hecho en **`v2/e8-recortes`** (no es `v2i-*`; el barrido no la toca): `9394a8f` (30 sprites / 60 PNG), `f33bb20` (balde de islas + `aplicar_limpias.py`), `32a3b29` (47 islas aplicadas; recut protege 112); pipeline OK, tarea VERDE unit 62. **Listo para integrar** (E8 T9 Step 3).
- **16:00** «agregá todo al juego» / «hacé todo lo recomendado» de `PREGUNTAS-DUENO-v2.md`: A5 hecho (`push --delete v2/e12-plan`; `git cherry` confirmó los 4 commits en `version-2`; respaldo local `respaldo/v2-e12-plan`). Volcado a `DUENO.md`: 48 videos sin usar + Álbum, skins con video si hay clip
  (no animar skins sin OK de créditos), **B1–B26 con los defaults aceptados + B22 como tarea**. Despachados: planificador opus de **E8e** (`v2/e8e-plan`, `bba2385`, 9 tareas: T1 `ArtClips` + contrato y T7 Álbum ⏳; T2–T4 y T8 tras T1; T5 tras E5b T2; T6 tras E5b T3 con rev. opus; T9 cierre) y la galería local `~/Desktop/galeria-animaciones` (135 animaciones, 0 faltantes).
- **16:34** Higgsfield: 200 videos en la cuenta, ninguno de skin (el dueño dice que animó todas: pendiente de que diga dónde). Estudio de assets (opus, **`v2/estudio-assets`**: `231de65`, `1d427ac`, `f6a7e16`; 529 fichas, 135 videos; tests estudio 15 + pipeline 94; `revision.json` intacto; `regenerar-desde-estudio.json` con 4). Listo para integrar junto con `v2/e8-recortes`.
- **16:38** «utilizá los assets que hay (los de los personajes base)»: videos base en todo lugar sin skin + **E8e T10** (tablero animado con secuencias de cuadros de los videos base, con gate de memoria/fps en SE). Todo en `DUENO.md`.

## Decisiones de la ola (sin decisiones nuevas del dueño sobre el juego)

- **El reset de cuenta pierde las pintas de ORO:** la pantalla del reset (E9b T8/T9) tiene que decirlo en `skinsLost`.
- **`skinsAll` exige las 3 familias:** con las pintas compradas con ORO, el logro pide comprar las tres (1350 ORO).
- **La ruleta del Conductor no se abre si el tablero no está calmo:** `openWheel` exige `!isBoardBusy`; el giro queda en Regalos (`bonusSpins`), no se pierde.
- **El paquete cuenta la cola:** `packageCandidates` descuenta `pendingBoardChanges` e `inFlight`; «LLENO» puede tardar un instante de más (conservador).
- **`alreadyOwned` va antes de `spendOro`** y `purchaseSkin` rechaza precios `<= 0`.
- **Las hojas de premios van en un `ViewModifier` (`PrizeSheets`):** `RootView.body` está al límite del type-checker.
- **El `completo` se lanza solo,** con nada compilando, y E8d T15 no se despacha con el contexto cerca de los 250k.

## Las trampas de la tanda

- **`RootView.body` al límite del type-checker:** sumarle una `.sheet` más da «unable to type-check in reasonable time». Las hojas nuevas van en un `ViewModifier` (`PrizeSheets`); E6a T12, E5b T3 y T5 lo respetan.
- **Un guard con estado que se apaga en el próximo `onChange` se come el pago de un video premiado** (`videoBusy` en `WheelView`): el video se ve y no paga. Ningún test lo veía; la opus lo encontró leyendo. Todo callback premiado se prueba de punta a punta **mirando el pago**.
- **Los UI `CustomizationUITests`/`MenuPagerUITests` se contaminan por orden en el `completo`:** 2 rojos que aislados dan VERDE. Aislar la clase sola sobre la misma build antes de declarar.
- **El `.xcodeproj` no se versiona:** se regenera de `project.yml`; un worktree nuevo lo genera antes de compilar y no se commitea.
- **Una tarea con 0 de precio:** `purchaseSkin` con `price = 0` regalaba y con `-50` daba `cantAfford`; probar 0, 1 y negativo (la regla de magnitud de las revisiones de precios).
- **Un `switch` exhaustivo de un test:** sumar un caso a `skinState` rompió `SkinCatalogRowsTests`; `grep` de quién hace `switch` sobre el enum antes de mover.
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`», las claves por snapshot, un `tarea` no corre UI, `rapido` uno por vez, `setsid` inexistente en macOS, el reporte de arreglos que no llega.

## Carries

| A | Qué |
|---|---|
| **E6a T12** | `chanceAllowed` por parámetro y por aparición (escuchar `Storefront.updates`); gregoriano para días y enfriamiento; no ofrecer la Bienvenida en BE/AU; el cofre sin UI test; `store.subtitle` viejo; ancla `.oroShop` sin consumidor; el `segment` que no se reinicia; `.unavailable` cubre `alreadyOwned`; hojas en un `ViewModifier` |
| **E5b T3** | 'LLENO' de la misma cuenta que `packageTapped`; la escena (cajas, colchón, apertura) |
| **E7b-b T1** | reusa `packageTapped`/`mattressTapped`/`openWheel` (con su guard de `isBoardBusy`) |
| **E5b T5 / E6b T5** | la leyenda «incluye 43» (`packSize` nil para `.oroPurchasable`) |
| **E9b T8 / T9** | el reset de cuenta pierde las pintas de ORO: `skinsLost` debe decirlo; unir `offers.purchases` y `seenCinematics` en `resolveAcrossReset` |
| **E8d T15** | Step 1: escribir `AnimatedPlacesTests` (no existe; sonnet); después un `completo` solo; los gates G1–G5 en device son del dueño |
| **E12 / próximo `completo`** | los dos UI por orden; `--uitest-reset` no apaga el ranking |
| **E2b / E11** | `maxPerAbsence` 3 con 4 motivos; los del 28: pesos no negativos de `ChestsConfig`, boosts ×72, simulador offline en ausencias cortas |
| **Dueño** | ver «Para el dueño»; más `PREGUNTAS-DUENO.md` y los del 28 y anteriores |

## Para el dueño

- **`PREGUNTAS-DUENO.md` sigue sin respuestas** (A1–A10, B1–B26 con default). Pediste aceptar los defaults de B1–B26 y B22 como tarea: está volcado en `DUENO.md`.
- **Integrar `v2/e8-recortes` y `v2/estudio-assets`** (listos): lo hace un relevo; si preferís integrarlas vos, avisá.
- **Reset de cuenta:** pierde las pintas compradas con ORO. ¿Se acepta o el reset las conserva (como `shop.skins` ya sobrevive a la reencarnación)?
- **`skinsAll`:** ahora cuesta comprar las 3 familias (1350 ORO). ¿Está bien o se baja el logro?
- **Matar la app con el popup del colchón abierto** pierde el 'otro colchón'.
- **Higgsfield:** ¿dónde están las animaciones de skins que decís que hiciste? La cuenta tiene 200 videos y ninguno de skin.
- Sin pasada a mano del colchón, los accesos y la Ruleta por ORO (E5b T2) ni de la pinta comprada con ORO (E6b T4) en SE, iPad, modo oscuro, VoiceOver ni Reduce Motion. Los 🔒 de los cierres: siete escenarios de E4b y tres de E5a.
- Siguen los del 28 (la tabla de probabilidades no proyecta los cofres pendientes; elegir en la página de recortes —ya hecho—), los del 27, 26, 25, 24, 23, 22 y 21c (**no publicar E7b-a T2 sin T3**: T3 ya está ✅). Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `26df563` VERDE (EK 845 · unit 1403 · 0 rojos · Release 0): E6b T4 ✅, 205 de 254.
- `completo`: `7c494ea` VERDE (EK 845 · unit 1417 · store-unit 18 · store-ui 2 · iPad 4 · SE 2 · pipeline 89 · pacing-sim ✅ · Release 0; UI 129 + 2 rojos por orden, aislados VERDES): E5b T2, E4b T10 y E5a T9 ✅, 208 de 254 (81,9 %).
- UI sueltos: `CharacterSheetUITests` 3/3 y `CustomizationUITests` 5/5 (E6b T4); Prizes 2/2, Wheel 4/4 y BonusHUD 3/3 tras los arreglos de E5b T2.

## Lo descartado

- Despachar E8d T15 durante el `completo` o con el contexto a 250k: su Step 1 es código nuevo (`AnimatedPlacesTests`), queda para el relevo 30.
- Un `rapido` previo de E5b T2: nada compilando al lado era lo que pedía el `completo`, que lo cubre.
- Apagar el botón con `.disabled` como cerrojo de la Ruleta por ORO: va contra `GameArtComponents`; se usó `PurchaseLatch`.

## Cierre

- Subagentes de tarea en vuelo: 0 al despachar los docs del cierre. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla (`v2i-cierres-r29` 623 MB, `v2i-e6b-t4` 1676 MB, `v2i-e5b-t2` 1828 MB); quedan por barrer `v2i-integ-r29` y `v2i-docs-r29` (con el shell fuera), más los de relevos anteriores si no se barrieron. Un `--apply` por worktree.
  `v2-e8-recortes`, `v2-e8e-plan` y el de `v2/estudio-assets` **no son `v2i-*`: no tocar.**
