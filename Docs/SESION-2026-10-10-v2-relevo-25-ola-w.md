# SESION 2026-10-10 — v2, relevo 25: el Álbum, los visitantes en la partida, el Colchón, la Ruleta y el chip del visitante

La ola W. El relevo 25 arrancó a las 05:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 24 lo soltó a las 04:38), la cuota en 5 h 4 % y semanal 58 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E4b T2 (turno y plata de los visitantes), E5a T7 (el Colchón: save y premios) y E5a T8 (la Ruleta: plata y *loot box*). E4b T3 (UI pura) no tuvo revisión opus.
Todo pasó por **`v2i/integ-r25`** (BASE `version-2` en `257d2aa`). Carga de la máquina: 1,3 al arrancar; hasta 2 compilando, y 195 mientras corría un `rapido`. Los briefs salieron de `Tools/v2/brief.py`
(`v2i-integ-r25/.superpowers/sdd/ola-r25/`, con `duenos.md`). Latido: `scratchpad/latido.sh` (`sleep 30`, escritura por reloj ≥ 9 min). El contexto pasó los 250k a las 06:48: no se despachó nada nuevo
después (E4b T3 fue la última tarea) y se cerró con los subagentes de tarea en 0.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | la punta tras el `rapido` VERDE sobre `73a7196` (EK 827 · unit 1247 · 0 rojos · Release 0): **186 de 254 (73,2 %)** |
| `v2i/integ-r25` | `c435bad` (suma E5a T8 y E4b T3, 🟢) + `tasks.md` + los docs del cierre (`v2i/docs-r25`) |
| Progreso | **186 de 254 en `version-2`; 188 de 254 (74,0 %) con E5a T8 y E4b T3 ✅** si el `rapido` de la punta da VERDE |
| `rapido` de la punta | **VERDE (EK 827 · unit 1275 · 0 rojos · Release 0): E5a T8 y E4b T3 ✅, 188 de 254 (74,0 %)** |
| Bloqueadas | ninguna nueva. E7b-a T3 sigue ⛔ y es **bloqueo de publicación**: se destraba con E5b T1, que la ola W dejó ⏳. E12 T12 ⛔ (espera a E9b T8) |

`rapido` de la tanda, en orden: `c4381ea` VERDE (EK 827 · unit 1211 · 0 rojos · Release 0; E4b T8 ✅); `e6bc1a4` VERDE (EK 827 · unit 1236; E4b T2 ✅); `73a7196` VERDE (EK 827 · unit 1247; E5a T7 ✅);
la punta con E5a T8 (`ecfae53` mergeada): **ROJO por un flake**, unit 1272 con 1 rojo, `ArtPacksTests.failureDoesNotLoop` (abajo); la punta final con E4b T3 (`c435bad`): VERDE (EK 827 · unit 1275 · 0 rojos · Release 0): E5a T8 y E4b T3 ✅, 188 de 254 (74,0 %).
No hubo `completo` en esta ola: el último de referencia sigue siendo el de los cierres del 23 (sobre `bab8a9c`).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E4b T8** el Álbum de especiales | `53cafaf` (merge `6a63620`, claves `e6bdc89`, tasks `c068911`) | tarea VERDE (EK 827 · unit 24); `SpecialsAlbumUITests` 3× en SE; captura SE vista por el controlador; `MenuUITests` ok; sin revisión opus. `rapido` VERDE (unit 1211) → ✅ | `GameState+Specials/AlbumEntry`, `EffectDescriptor.amount(forSpecial:)`, `SpecialsAlbumView`, la quinta tarjeta `menu.card.specials` en `MenuView` con **glifo SF** (`ui_menu_specials` no existe como PNG), línea del Álbum en `SpecialDropView` sólo fuera del recap, lección `.album`; 11 claves por snapshot |
| **E4b T2** los visitantes en la partida | `cdda9c8` + arreglos `2aba4ed` (merge `705e410`, claves `e6bc1a4`, tasks `a5e956b`) | tarea VERDE (EK 827 · unit 82, luego 138); `CharacterSheet`/`QuickHire`/`BonusHUD` UI 3/3 cada uno; revisión opus: **Changes requested**, arreglado. DONE_WITH_CONCERNS. `rapido` VERDE (unit 1236) → ✅ | `GameState+Visitors`: llegan solos, cotizan al llegar y cierran el trato por el embudo; `presentOnStage` por `canPresentOnStage → Bool`; paciencia quieta con intersticial; `arrive`/`openStagePopup` para `.visitor` (`.presenter` queda para T4); fila `debug.visitor.call` en la sección Visitantes al final; 8 claves |
| **E5a T7** el Colchón | `95cd194` (merge `d60651f`, tasks `73a7196`/`0444e0f`) | tarea VERDE (EK 827 · unit 71, 11 tests); revisión opus: **Approved**. `rapido` VERDE (unit 1247) → ✅ | `GameState+Treasures`, `advanceTreasures` tras `advancePackages`, fixture `--uitest-mattress`; sortea **antes** de gastar; sin `scheduleSave` propio (el `grant` guarda con debounce de 2 s); 0 claves |
| **E5a T8** la Ruleta | `a6750c4` + arreglos `ecfae53` (merge `dfe7149`, tasks `386a87f`) | tarea VERDE (EK 827 · unit 92, luego 41); revisión opus: **Approved con arreglos**, hechos. 🟢 | `GameState+Wheel`; **`LootBoxGate`** (Storefront alpha-3; sin storefront/config/publisherID → no); `.wheelSpin` entregable; fixture `--uitest-wheel-spins`; `spendOro` sobre copia; `persistNow` en `Task`; test genérico de premios entregables; 0 claves. `rapido` ROJO por flake (abajo) |
| **E4b T3** el chip, el popup y el retrato | `13a0b2a` (merge `4bc3a5f`, claves `c435bad`) | tarea VERDE (EK 827 · unit 57); `VisitorUITests`/`BonusHUD`/`HUDRedesign` UI 3/3 cada uno; capturas SE vistas por el controlador. Sin revisión opus. 🟢 | `VisitorFace`/`StageChips`/`VisitorPopupView`, lección `.visitor`, `StageChips` en `hudColumn`, hoja del popup, `visitorPopup` en `boardIsCovered`; el retrato usa `AnimatedArtView` (sin `LoopingPortraitView`); detent 0,72 y retrato de 112 pt para el SE; 2 claves. 🔥 `RootView`: tres cambios chicos |

Merges en `integ-r25` (encadenados): E4b T8 `6a63620`; E4b T2 `705e410` (BASE de E5a T7: merge `b1c2169`); E5a T7 `d60651f`; E5a T8 `dfe7149`; E4b T3 `4bc3a5f`. Los worktrees se borraron al integrar (E4b T2 1.698 MB, E5a T7 1.597 MB, E5a T8 1.703 MB,
E4b T3 1.653 MB). Claves por snapshot aplicadas al integrar E4b T8 (11), E4b T2 (8) y E4b T3 (2).

## La revisión que pidió cambios: E4b T2

E4b T2 volvió de la revisión opus con **Changes requested**, tres obligatorios:

1. **El fixture `--uitest-visitor=` no hacía nada.** Corre antes de `phase == .ready` y `presentOnStage` exige `canPresentOnStage` (que pide un momento calmo). Se difirió a `advanceVisitors` bajo `#if DEBUG`, con test.
2. **`confirmPrestige` no despedía al visitante:** el regalo, la Vecina o el reto se cobraban en la run nueva con el cps viejo. Ahora limpia reto y llamado y despide al actor, con test (sin RED comprobado).
3. **El rename de `loops_manifest` rompía `ManifestVersionado` del pipeline.** T2 había renombrado `events.cayo_mercado_pago` → `events.home_banking` sin renombrar `ev_cayo_mercado_pago.mov` ni `EVENT_IDS`. Se completó: `git mv ev_home_banking.mov`, `EVENT_IDS`, file; pipeline 89 OK.

Pedidos además, hechos: `.visitor` entra en `isPrepaid` (matar la app dejaba plata + unidad cuando `release`/`sell`/`take` acreditaban antes), `canPresentOnStage` sin anuncio en pantalla, tests por `registerTap` y por doble `chooseVisitOption`.
Verificado bien: pago único, bordes de multa, cola calma, paciencia, save. **Carries** (abajo): T3 (fixture, `uiCoversBoard` en el popup: T3 los cerró), T4 (`eventIsApplicable`, orden de `pendingEvent`), T5 (el reto bloquea los cortes naturales; reloj por delta) y dueño
(un reloj adelantado vacía `visitsToday`/`oroExchangedToday`; la cuota sin plata no se atenúa). El revisor dejó el `HEAD` detached un momento en `v2i-e4b-t2` y lo devolvió (limpio en `cdda9c8`).

## La revisión de la Ruleta: E5a T8

Approved con arreglos. Obligatorios, hechos en `ecfae53`:

1. **`wheelDay` usaba `Calendar.current`:** con calendario japonés, budista o persa el año es otro y el día guardado queda en el futuro para siempre → **gregoriano fijo**, con test para esos tres calendarios.
2. **`max(guardado, hoy)` bloqueaba los cupos hasta un día futuro lejano** (reloj adelantado y vuelto atrás) → se acepta un día guardado en el futuro **sólo hasta mañana**, con test un año adelante. **Costo:** atrasar el reloj ≥ 2 días devuelve los cupos.

Opcionales hechos: repetir el cofre vacío da el respaldo (`coins_30`); `LootBoxGate` reusa `isRestricted` (se perdió el test de lista vacía). Verificado bien: el ORO se cobra una vez por giro (copia + asignación atómica), matar la app pierde o guarda todo junto,
el gate falla cerrado, alpha-3, la reencarnación conserva la ruleta. **Carries:** E5b (pasar `LootBoxGate.current()` a `wheelAvailability`/`spinWheel`, verificar el video antes de `.video`/`repeat`, bloquear el botón al animar); dueño/E2b (repetir ×5 da ×25 y los giros apilan ×30:
¿suma o renueva el mismo `sourceKey`?); dueño/E6a (la config remota puede vaciar `restrictedStorefronts`: ¿piso BEL/AUS? E6a reusa el gate).

## La revisión del Colchón: E5a T7

Approved, sin obligatorios. Verificado: sin doble cobro (llamadas síncronas, colchón gastado y premio en el mismo player), reloj de juego activo con tope de 2 s, el offline da uno. Opcionales: un test genérico `reward.kind ⊂ grantableRewardKinds` para tesoros y ruleta (hecho en T8) y RNG inyectable.
**Carries:** E5a T8 (comentario de `+Rewards:8` y `RewardGrantTests:71` al sumar `.wheelSpin`: hecho); **E5b** (ofrecer el extra sólo con `mattressExtraOpensLeft > 0`; manejar el `nil` tras el video: si aparece el siguiente mientras se mira el video del extra, el video queda sin premio; el chip con `isCalmMoment`; `MattressOutcome`);
**dueño** (el colchón sobrevive a la reencarnación; un crash dentro de los 2 s del debounce re-sortea).

## El rojo que no era: `ArtPacksTests.failureDoesNotLoop`

El `rapido` de la punta con E5a T8 dio **ROJO: unit 1272 con 1 rojo**, `ArtPacksTests.failureDoesNotLoop` (ODR). Mientras corría, la carga estaba en 120–150, y el test hace un `await settle()` que se queda corto bajo carga. E5a T8 no toca ODR.
Se corrió la tarea `ArtPacksTests` sola sobre la misma punta: **8/8 VERDE**. Se trató como flake y no se declaró. Va a la lista de trampas (HANDOFF §7): antes de arreglar un rojo de ODR, aislarlo.

## El hallazgo de UI: `MenuPagerUITests` depende del orden

Con E4b T8 mergeada, `MenuUITests` pasó, `SpecialsAlbumUITests` pasó, pero **`MenuPagerUITests` dio 2 rojos**: los puntos del paginador decían 6 páginas (2/6, 6/6) y el test espera 5. Aparece la pestaña Ranking.
Para saber si era de T8 se chequeó la **base `257d2aa` sola** (worktree `v2i-base-r25`, detached, borrado después): `MenuPagerUITests` 2/2 VERDE; `integ-r25` sola, 2/2 VERDE. No es de T8: es **contaminación por el orden en el mismo simulador**. `unlockedTabsInBarOrder` usa
`ranking?.isEnabled != false` (nil o no deshabilitado cuenta como prendido) y `--uitest-reset` no lo apaga, así que lo que `MenuUITests` deja prendido lo ve el paginador. El `completo` corre `MenuPager` antes que `MenuUITests` (orden alfabético), así que ahí no cae.
**Carry a E12 / al próximo `completo`:** que `--uitest-reset` apague el ranking.

## Decisiones de la ola (sin decisiones nuevas del dueño)

- **Los visitantes pagados con video se compensan:** `.visitor` entra en `isPrepaid` (arreglo de la revisión). El brief de T2 decía «sin prepago por diseño»; el revisor mostró que mataba la plata y la unidad si se cerraba la app, y se cambió.
- **El día de los cupos de la Ruleta es gregoriano y aguanta un guardado futuro sólo hasta mañana:** el costo (atrasar el reloj ≥ 2 días devuelve cupos) se aceptó contra el bloqueo de cupos hasta una fecha lejana.
- **`LootBoxGate` falla cerrado:** sin storefront, sin config o sin `publisherID` no hay *loot box*. E6a lo reusa, no crea otro.
- **El Álbum usa un glifo SF** en la tarjeta del menú hasta que exista el arte (`ui_menu_specials` no está como PNG).
- **El colchón sortea antes de gastar y no guarda por su cuenta:** el `grant` guarda con debounce de 2 s.

## Las trampas de la tanda

- **Un fixture de arranque que necesita un momento calmo no entra:** corre antes de `phase == .ready` y `isCalmMoment` falla. Se difiere a la rutina que corre por tick (`advanceVisitors`), bajo `#if DEBUG`.
- **Renombrar un id de `loops_manifest` exige renombrar el `.mov` y `EVENT_IDS` del pipeline:** si no, `ManifestVersionado` cae. El rename de T2 salió a medias y lo agarró la revisión opus.
- **Las fechas de día con `Calendar.current` dependen del calendario del usuario:** japonés, budista y persa dan otro año. Usar gregoriano fijo (con test para esos tres).
- **El orden de los UI tests en un mismo simulador contamina:** `MenuUITests` deja el ranking prendido y `MenuPagerUITests` cuenta una página de más. Antes de culpar a una tarea, correr la clase sola sobre la base y sobre la rama.
- **Un flake de ODR bajo carga:** `ArtPacksTests.failureDoesNotLoop` (`await settle()`). Aislarlo antes de declararlo.
- Siguen: el oráculo usa el repo de su propia ruta, `setsid` no existe en macOS, las EK puras no ocupan cupo, `rapido` uno por vez, la tabla de dueños va en cada brief, un agente con trabajo de fondo re-entrega el mismo reporte, un `tarea` no corre UI.

## Carries

| A | Qué |
|---|---|
| **E5b T1** | `LootBoxGate.current()` a `wheelAvailability`/`spinWheel`; verificar el video antes de `.video`/`repeat`; bloquear el botón al animar; el extra del colchón sólo con `mattressExtraOpensLeft > 0`; el `nil` tras el video (siguiente colchón que aparece mientras se mira el extra); chip con `isCalmMoment`; `MattressOutcome` |
| **E7b-a T3** | los del 24 (`canRequestAds`, un solo observador de AdMob, `recordShown`, `Set<CelebrationKind>??` → enum, `isCalmMoment` vs `isSafeMomentForInterstitial`); respetar `visitorPopup` en `boardIsCovered` y el chip en `hudColumn` |
| **E4b T4/T5** | `eventIsApplicable` y el orden de `pendingEvent` (T4); `.presenter` en `arrive`/`openStagePopup` (T4); el reto bloquea los cortes naturales y reloj por delta (T5); los `switch` y la prioridad 5 de `.visitorEncounter` al irse `.eventBanner` |
| **E4b T9** | `debugDropFirstSpecial` también ancla en `specialAnchors` |
| **E6a T5/T12** | reusar `LootBoxGate`; la config remota puede vaciar `restrictedStorefronts` (¿piso BEL/AUS?); no ofrecer la Bienvenida (cofre) en BE/AU (del 24) |
| **E2b / dueño** | repetir ×5 da ×25 y los giros apilan ×30: ¿suma o renueva el mismo `sourceKey`? |
| **E12 / próximo `completo`** | `--uitest-reset` no apaga el ranking: `MenuPagerUITests` falla tras `MenuUITests` |
| **Dueño** | atrasar el reloj ≥ 2 días devuelve cupos de la Ruleta; un reloj adelantado vacía `visitsToday`/`oroExchangedToday`; la cuota sin plata no se atenúa; el colchón sobrevive a la reencarnación; un crash dentro de los 2 s del debounce re-sortea; los del 24 y anteriores |

## Para el dueño

- E4b T3: el chip del visitante quedó pegado a la llave de debug (arriba a la derecha): mirarlo contra la columna de E7b en release. El loop real del retrato no se vio nunca. Sin pasada a mano de iPad, modo oscuro, VoiceOver ni Reduce Motion. Las capturas SE están en `build/e4b-t3-*.png` del checkout principal.
- E5a T8: atrasar el reloj ≥ 2 días devuelve cupos de la ruleta (el costo del tope «hasta mañana»); y la pregunta de si los giros ×30 apilan o renuevan.
- E5a T7: el colchón sobrevive a la reencarnación.
- Siguen los del 24 (captura SE del precio tachado, visual del escenario, reembolso de una oferta), los del 23 (video de salida de un evento que vence corriendo, `.eventStartup`/`.eventBlanqueo`, llegadas del Paquete en inactivo), los del 22 (E3b T9, E6a T1, E12 T15 / `NSPrivacyTracking`) y los del 21c
  (**no publicar E7b-a T2 sin T3**). Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `c4381ea` VERDE (EK 827 · unit 1211); `e6bc1a4` VERDE (EK 827 · unit 1236); `73a7196` VERDE (EK 827 · unit 1247); punta con E5a T8 ROJO por flake (unit 1272 / 1: `ArtPacksTests.failureDoesNotLoop`, aislado 8/8 VERDE); punta final (`c435bad` + docs): **VERDE (EK 827 · unit 1275 · 0 rojos · Release 0): E5a T8 y E4b T3 ✅, 188 de 254 (74,0 %)**.
- Todos los VERDE: 0 rojos, Release 0.
- UI sueltos: `MenuUITests`, `SpecialsAlbumUITests` y `MenuPagerUITests` (cada uno sola: VERDE); `CharacterSheet`/`QuickHire`/`BonusHUD`/`HUDRedesign` y `VisitorUITests` 3/3.
- Sin `completo`: el de referencia sigue siendo el de los cierres del 23 sobre `bab8a9c`.

## Lo descartado

- Despachar nada más tras los 250k de contexto: se terminó E4b T3 y E5a T8 y se cerró.
- Declarar el rojo de `ArtPacksTests` y arreglar ODR: era un flake bajo carga.
- Culpar a E4b T8 por `MenuPagerUITests`: la base y la rama, cada una sola, dan VERDE.
- Revisión opus de E4b T3: UI sin plata, save ni turno; el diff de `RootView` (tres cambios chicos) lo leyó el controlador.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan por barrer `v2i-integ-r25` y `v2i-docs-r25` (con el shell fuera), más los de relevos anteriores si no se barrieron.
