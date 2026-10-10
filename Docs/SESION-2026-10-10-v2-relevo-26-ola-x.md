# SESION 2026-10-10 — v2, relevo 26: la Ruleta en pantalla, el reto, los ×3 que se entregan, el arresto, los ×2 por video y la pausa publicitaria

La ola X. El relevo 26 arrancó a las 07:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 25 lo soltó a las 06:58), la cuota en 5 h 8 % y semanal 59 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E6a T5 (plata de ORO), E5b T1 (una *loot box*) y E7b-a T3 (el bloqueo de publicación).
E4b T5, E8b T11 y E7b-b T6 no tuvieron revisión opus: las leyó el controlador (E7b-b T6 devolvió un arreglo por su cuenta, abajo).
Todo pasó por **`v2i/integ-r26`** (BASE `version-2` en `f98a3bf`, 188 de 254). Carga de la máquina: 1,4 al arrancar; hasta 3 compilando, y 330 mientras corría un `rapido`. Los briefs salieron de `Tools/v2/brief.py`
(`v2i-integ-r26/.superpowers/sdd/ola-r26/`, con `duenos.md`). Latido: `scratchpad/latido.sh` (`sleep 30`, escritura por reloj ≥ 9 min). El contexto pasó los 250k a las 08:00: no se despachó nada nuevo
después (E7b-b T6 fue la última tarea) y se cerró con los subagentes de tarea en 0.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | `652bc6a`, la punta tras el `rapido` VERDE sobre `4b44a4e` (EK 827 · unit 1308 · 0 rojos · Release 0): **193 de 254 (76,0 %)** |
| `v2i/integ-r26` | `1f090ef` (suma E7b-a T3, 🟢) + `tasks.md` + los docs del cierre (`v2i/docs-r26`) |
| Progreso | **193 de 254 en `version-2`; 194 de 254 (76,4 %) con E7b-a T3 ✅** si el `rapido` de la punta da VERDE |
| `rapido` de la punta | VERDE (EK 827 · unit 1329 · 0 rojos · Release 0): E7b-a T3 ✅, 194 de 254 (76,4 %) |
| Bloqueadas | ninguna nueva. **El bloqueo de publicación (E7b-a T3) está hecho a falta del `rapido`: sin él no se publica E7b-a T2.** E12 T12 ⛔ (espera a E9b T8) |

`rapido` de la tanda, en orden: `015c5f7` VERDE (EK 827 · unit 1289 · 0 rojos · Release 0; E4b T5 y E6a T5 ✅, 190 de 254); `7c6ad1d` VERDE (unit 1300; E5b T1 ✅, 191); `93d2d65` VERDE (unit 1302; E8b T11 ✅, 192);
`4b44a4e` VERDE (unit 1308; E7b-b T6 ✅, 193); la punta final con E7b-a T3 (`1f090ef`): VERDE (EK 827 · unit 1329 · 0 rojos · Release 0): E7b-a T3 ✅, 194 de 254 (76,4 %). Cuatro `rapido` seguidos en VERDE, ninguno con flake. No hubo `completo` en esta ola: el último de referencia sigue siendo el de los cierres del 23 (sobre `bab8a9c`).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E4b T5** el reto y las cartas del Vendedor | `c67c540` (merge `d475a04`, claves `55113e8`) | tarea VERDE (EK 827 · unit 44); `VisitorMechanicsUITests` 2/2 y `VisitorUITests` 3/3 en SE; sin revisión opus (el reto no toca save), diff leído por el controlador. DONE_WITH_CONCERNS. `rapido` VERDE (unit 1289) → ✅ | `ChallengeChip`, `VendorCardsView`, `challengeClock` por delta en `advanceStage` (`now` opcional para tests), `sheetOpen ||= stageChallenge` en `GameState+Ads` (fuera de la tabla de dueños; nadie más lo toca); 3 claves; `finishChallenge` en victoria mezcla `challengeClock` con pared, aceptable |
| **E6a T5** auto-tap, Offline ×3 y Diario ×3 se entregan | `4210586` + arreglos `3a97835` (merge `a9f865c`, tasks `015c5f7`) | tarea VERDE (EK 827 · unit 27, luego 18); revisión opus: **Approved** (sin obligatorios). `rapido` VERDE (unit 1289) → ✅ | el `grant` entrega `.autoTap`/`.nextOfflineMultiplier`/`.nextDailyMultiplier`; `GameState+OroShop`; `advanceAutoTap` primero en `advanceEngagement`; una línea en `+Lifecycle` y una en `+Bonus`; pendientes `Double`; el ×2 de video del offline sobre el ×3; 0 claves |
| **E5b T1** la Ruleta en pantalla | `44259ad` + arreglos `747492a` (merge `4644e67`, claves `7c6ad1d`, tasks `26396aa`) | tarea VERDE (EK 827 · unit 30, luego 33); revisión opus: **Approved con arreglos**, hechos. DONE_WITH_CONCERNS. `rapido` VERDE (unit 1300) → ✅ | `WheelGeometry`/`WheelCanvas`/`WheelView`, `OddsDisclosureView`, `RewardCopy`, `SFX.wheelTick`, `Pattern.tick`, `playWheelTick`; `LootBoxGate.current()` a `wheelAvailability`/`spinWheel` (arranca en false); `.video`/`repeat` sólo desde `onRewarded`; girar bloqueado al animar; 27 claves por snapshot; el colchón y `wheel_frame` no aplican en T1; `isFinished` con tolerancia 1e-6 |
| **E8b T11** el arresto | `5f52ed3` (merge `7acc765`, tasks `93d2d65`) | tarea VERDE (EK 827 · unit 48); sin revisión opus, diff de 1 línea leído por el controlador. `rapido` VERDE (unit 1302) → ✅ | `playCinematicIfDue(.arresto)` en `chooseVisitOption` con `.release`, antes de las salidas; la fianza no lleva cinemática; 2 tests; 0 claves. Destraba E8d T15 |
| **E7b-b T6** Diario ×2 y carrera ×2 por video | `6519071` + arreglo `2fb2e90` (merge `4548554`, claves `4b44a4e`, tasks `652bc6a`) | tarea VERDE (EK 827 · unit 27, luego 16); sin revisión opus: el controlador leyó el diff y devolvió un obligatorio. `rapido` VERDE (unit 1308) → ✅ | `doubleDailyReward` una vez por día por `rewardedActivations['daily.x2']`, sólo plata; `chooseCareerWithVideo` + `grant coinsSeconds` del `lumpMinutes`; `DailyRewardView` `daily.double` (detent 0,6 sin medir), `CareerChoiceView` `career.x2.<id>`; `isBusy`; 2 claves |
| **E7b-a T3** la pausa publicitaria | `de150c6` + arreglos `bf63962` (merge `06379f6`, claves `1f090ef`) | tarea VERDE (EK 827 · unit 80, luego 61); `AdBreakUITests` 2/2 en SE y 16 Pro; `CharacterSheet` 3/3, `QuickHire` 3/3; revisión opus: **Approved con arreglos**, hechos. DONE_WITH_CONCERNS. 🟢 (`rapido` VERDE (EK 827 · unit 1329 · 0 rojos · Release 0): E7b-a T3 ✅, 194 de 254 (76,4 %)) | previa de 5 s, «No, gracias» sin castigo, premio que rota; `isBoardBusy` como definición única de calma; `lastRewardedInterstitialAttempt` en `AdsProvider` para `recordShown`; tocó también `+FrameLoop`/`+Types`/`+Rewards`/`AdsCoordinator`/`AdMobAdsProvider`/`AdFormatsTests`; 6 claves |

Merges en `integ-r26` (encadenados): E4b T5 `d475a04`; E6a T5 `a9f865c`; E5b T1 `4644e67`; E8b T11 `7acc765`; E7b-b T6 `4548554`; E7b-a T3 `06379f6`. Los worktrees se borraron al integrar (E4b T5 1.641 MB, E6a T5 1.642 MB, E5b T1 1.767 MB, E8b T11 1.690 MB;
los de E7b-b T6 y E7b-a T3 también). Claves por snapshot aplicadas al integrar E4b T5 (3), E5b T1 (27), E7b-b T6 (2) y E7b-a T3 (6). Progreso por `rapido`: 188 → 190 → 191 → 192 → 193 en `version-2`.

## La revisión de E6a T5: Approved

Sin obligatorios. Verificado bien: sin doble cobro ni doble entrega; consumo único, también con la app matada en el medio; bordes 0, 1 y ×3 sin apilar; el auto-tap corre sólo con la escena activa y con el delta topado en 2 s.
Opcionales, devueltos al implementador y hechos en `3a97835`: la lista de entregables explícita en `RewardGrantTests` (línea 70) y `isFinite` en el `grant` de los dos pendientes (con tests de `inf` y `nan`).
**Carries:** al dueño (el Offline ×3 con un video encima da ×6; el auto-tap se pierde al reencarnar pero los ×3 pendientes sobreviven; el reset de cuenta borra un ×3 pagado; el auto-tap vence con la app cerrada);
a E2b (el simulador gasta el pendiente offline en ausencias cortas y apila con `*=`, mientras que la app usa el máximo y sólo con popup); a E6a T6 (bloquear la compra del segundo ×3 antes de cobrar; la UI no dice que el popup y el diario vienen ×3).

## La revisión de E5b T1: Approved con arreglos

Tres obligatorios, hechos en `747492a`:

1. **Con Reduce Motion el guard `spin == nil` no traba:** un doble toque cobraba ORO dos veces y gastaba dos giros. Ahora hay un `@State resolving` (con `releaseSoon` de 0,5 s) y `locked = spin || resolving || videoBusy`, que se chequea y se prende en el mismo handler síncrono.
2. **El háptico no tenía freno** (~42 por segundo, un player por tic): `WheelTickGate` de 0,08 s para el sonido y el háptico. Vive en la vista, no en `GameState` (que es caliente), y tiene su test.
3. **Con Reduce Motion se podía girar mientras cargaba el video de `repeat`** y se repetía el premio del giro nuevo: `isBusy` en los dos `RewardedOfferButton` y `.disabled(locked)` (no se ocultan: desmontar cancela el video).

Opcionales hechos: rueda quieta con la tabla viva, `reward.title.slot` en singular («+1 lugar»), id `wheel.spinning`, tests de borde. Verificado bien: la tabla efectiva, los pesos enteros que suman 100, acredita y guarda antes de animar, el gate falla cerrado y se refresca en `.task`,
el video sólo por `onRewarded` y la tolerancia de 1e-6 real. **El candado no tiene test** (vive en la vista): el UI test va en T2/T4.
**Carries:** E5b T2/T4 (aplicar `claves-pendientes/e5b-t1.json` antes del oráculo si falta; mirar con Reduce Motion; `wheel_frame` sin usar); E6a (reusar `OddsDisclosureView`/`RewardCopy` y el candado anti doble toque en el cofre por ORO);
dueño (en el SE la tabla de probabilidades queda bajo el pliegue: ¿alcanza para la 3.1.1 de Apple o va un enlace junto al botón de ORO?).

## La revisión de E7b-a T3: Approved con arreglos

La pausa publicitaria es el **bloqueo de publicación**: sin ella E7b-a T2 saca un intersticial en cada corte. Un obligatorio, hecho en `bf63962`:

1. **La oferta de Compartir quedaba tapada por la pausa** (`sheetOpen` no miraba `shareOffer`) → `sheetOpen: isBoardBusy || shareOffer != nil`, con test.

Opcionales pedidos y hechos: `persistNow` tras el grant del premio; `effectiveAdBreak` con piso de 5 s (`introSeconds`); `offerableFormats` saca la pausa si no tiene premios (un `prizes` vacío ya no deja la pausa con el turno).
Verificado bien: alterna pausa y común con piso y gracia (bordes de ±1 s, reloj atrás); «No, gracias» no da anuncio ni premio; `recordShown` sólo con `.presented` (los cuatro providers implementan `lastRewardedInterstitialAttempt`);
el premio se da una vez y sólo con `earned`; `canRequestAds` en las cuatro precargas; un solo `FullScreenAdObserver`; `CelebrationHold`; `isBoardBusy` es la definición única de calma (el reto, el ascensor, la compra y la previa ahora frenan a los visitantes, a Compartir y al ranking;
el tutorial, los paquetes y el colchón no usan `isCalmMoment`).
**Carries:** E4b T4 (una visita no entra durante un reto); E7b-a T6/T7 (prueba con el anuncio real; `BonusHUDUITests` en orden, ver abajo); E6a/dueño (el ×2 de la pausa se apila con otros ×2; ¿5 s fijos?).

## El arreglo de E7b-b T6 que no pasó por opus

`chooseCareerWithVideo` pagaba el ×2 **aunque `chooseCareer` no hubiera aplicado la elección** (doble toque, o sin prompt abierto): se cobraba un premio sin carrera. Lo vio el controlador al leer el diff y volvió al implementador.
`2fb2e90`: sale sin pagar si no hay prompt, si la opción es ajena o si el prompt sigue abierto; test `careerTimesTwoOnlyWhenApplied`. Es la misma clase de trampa que el candado de E5b T1: **un video no paga si la acción que premia no se aplicó** (abajo, en las trampas).
**Dudas al dueño:** el Diario ×3 con el video da ×6 del base; en la Obra social el ×2 duplica sólo la plata.

## Decisiones de la ola (sin decisiones nuevas del dueño)

- **Un ×3 pendiente y un video se multiplican** (E6a T5, E7b-b T6): el Offline ×3 con video da ×6 y el Diario ×3 con video da ×6 del base. No se capó: va a la lista del dueño.
- **La Ruleta se bloquea con un candado de vista** (`resolving`, `videoBusy`) y no desde `GameState`: el estado caliente no se toca por un caso de Reduce Motion. El costo: sin test unitario; lo cubre el UI test de E5b T2/T4.
- **El freno del tic (0,08 s) vive en la vista**, no en `GameState`.
- **`isBoardBusy` es la única definición de calma** (E7b-a T3): sustituye a `isCalmMoment` e `isSafeMomentForInterstitial`, que se habían copiado uno del otro.
- **La pausa tiene piso de 5 s** aunque la config diga menos; sin premios no se ofrece.

## Las trampas de la tanda

- **El modo auto deja de aprobar TODO `Bash` tras una denegación y vuelve solo:** a las 07:15, después de que el clasificador denegó un `push --delete` (borrar la rama remota `v2/e12-plan`), el modo auto pidió aprobación hasta para `date`. `Read`/`Edit` siguieron. Sin `Bash` no se integra, no se corre el oráculo ni se pushea:
  se esperó a los agentes y se reintentó hasta que volvió. **No pedir operaciones destructivas de git desde el agente; dejarlas al dueño.**
- **Un agente con monitores de espera re-entrega el aviso:** el de E6a T5 mandó tres veces el aviso de sus monitores; la última notificación dijo «sin hijos de fondo vivos» y terminó solo. Sin `TaskStop` hacía falta: mirar esa frase antes de cortar.
- **Un video no paga si la acción que premia no se aplicó:** `chooseCareerWithVideo` pagaba sin elección aplicada (E7b-b T6); la Ruleta pagaba dos veces con Reduce Motion (E5b T1). Antes de pagar, comprobar que la acción se aplicó; probar el doble toque.
- **`BonusHUDUITests.testTwoBonusesShowAtTheSameTime` dio rojo en la primera corrida de E7b-a T3 y verde sola:** ¿orden de los UI tests en el simulador? (la misma familia del `MenuPagerUITests` del 25). El UI test de la pausa se relajó a 1…5. Correr la clase sola sobre la base antes de culpar a la tarea.
- **Una tarea que cambia la definición de calma toca más de lo que dice el brief:** E7b-a T3 tocó `+FrameLoop`, `+Types`, `+Rewards`, `AdsCoordinator`, `AdMobAdsProvider` y `AdFormatsTests`. La tabla de dueños tiene que listarlos.
- **El `sheetOpen` de una tarea nueva tiene que mirar toda oferta modal** (`shareOffer`, `stageChallenge`, ...): lo que no figura ahí queda tapado por la pausa o tapa a la pausa.
- Siguen: el oráculo usa el repo de su propia ruta, `setsid` no existe en macOS, las EK puras no ocupan cupo, `rapido` uno por vez (no se mergea a `integ` mientras corre), la tabla de dueños va en cada brief, un `tarea` no corre UI, el reporte de arreglos que no llega.

## Carries

| A | Qué |
|---|---|
| **E4b T4** | una visita no entra durante un reto (E7b-a T3); `eventIsApplicable` y el orden de `pendingEvent`; `.presenter` en `arrive`/`openStagePopup`; los `switch` y la prioridad 5 de `.visitorEncounter` al irse `.eventBanner`; las dos palabras en `false` (`endsInNaturalBreak`, `coversElevator`) |
| **E5b T2/T4** | aplicar `claves-pendientes/e5b-t1.json` antes del oráculo si falta; probar el candado con Reduce Motion; `wheel_frame` sin usar; los del colchón (extra sólo con `mattressExtraOpensLeft > 0`, el `nil` tras el video, chip con `isCalmMoment`, `MattressOutcome`) |
| **E6a T4/T6** | T6: bloquear la compra del segundo ×3 antes de cobrar; la UI dice que el popup y el diario vienen ×3. Reusar `OddsDisclosureView`/`RewardCopy` y el candado anti doble toque en el cofre por ORO |
| **E7b-a T6/T7** | prueba con el anuncio real; `BonusHUDUITests` en orden; el ×2 de la pausa se apila con otros ×2 |
| **E2b T9+** | el simulador gasta el pendiente offline en ausencias cortas y apila con `*=`, la app usa el máximo y sólo con popup; repetir ×5 da ×25 y los giros apilan ×30 (¿suma o renueva el mismo `sourceKey`?) |
| **E8d T15** | E8b T11 ✅: el arresto lleva cinemática las dos primeras veces; la fianza no |
| **E9b T8 / E6a T12** | los del 25 y anteriores (oferta reembolsada, no ofrecer la Bienvenida en BE/AU) |
| **E12 / próximo `completo`** | `--uitest-reset` no apaga el ranking: `MenuPagerUITests` falla tras `MenuUITests` |
| **Dueño** | ver «Para el dueño»; más los del 25 y anteriores |

## Para el dueño

- **Offline ×3 con un video encima da ×6; el Diario ×3 con video da ×6 del base; en la Obra social el ×2 duplica sólo la plata.** ¿Se acepta o se capa?
- **En el SE la tabla de probabilidades de la Ruleta queda bajo el pliegue:** ¿alcanza para la 3.1.1 de Apple o va un enlace junto al botón de ORO?
- **El auto-tap se pierde al reencarnar** y **vence con la app cerrada**; **el reset de cuenta borra un ×3 pagado**; los ×3 pendientes sí sobreviven a la reencarnación.
- **La pausa publicitaria: ¿5 s fijos?** Y su ×2 se apila con otros ×2.
- **Borrar la rama remota `v2/e12-plan`:** sus 4 commits ya están en `version-2` (`git cherry` da `-`), el worktree no existe, y el clasificador del modo auto bloqueó el `push --delete` [Git Destructive]. Lo hace el dueño: `git push origin --delete v2/e12-plan`.
- Sin pasada a mano del reto, de las cartas del Vendedor, de la Ruleta ni de la pausa en SE, iPad, modo oscuro, VoiceOver ni Reduce Motion.
- Siguen los del 25 (el chip contra la llave de debug, el loop real del retrato, cupos de la ruleta con el reloj atrasado, el colchón que sobrevive a la reencarnación), los del 24, 23, 22 y 21c (**no publicar E7b-a T2 sin T3**: T3 ya está, pendiente del `rapido`). Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `015c5f7` VERDE (EK 827 · unit 1289); `7c6ad1d` VERDE (unit 1300); `93d2d65` VERDE (unit 1302); `4b44a4e` VERDE (unit 1308); punta final con E7b-a T3 (`1f090ef` + docs): VERDE (EK 827 · unit 1329 · 0 rojos · Release 0): E7b-a T3 ✅, 194 de 254 (76,4 %).
- Todos los VERDE: EK 827, 0 rojos, Release 0.
- UI sueltos: `VisitorMechanicsUITests` 2/2 y `VisitorUITests` 3/3 (SE); `AdBreakUITests` 2/2 en SE y en 16 Pro; `CharacterSheet`/`QuickHire` 3/3; `BonusHUDUITests.testTwoBonusesShowAtTheSameTime` rojo la 1ª vez y verde sola.
- Sin `completo`: el de referencia sigue siendo el de los cierres del 23 sobre `bab8a9c`.

## Lo descartado

- Despachar nada más tras los 250k de contexto: se terminó E7b-b T6 y E7b-a T3 y se cerró.
- Mergear a `integ-r26` con un `rapido` corriendo: cada tarea esperó el fin del oráculo en curso.
- Revisión opus de E4b T5 (el reto no toca save), E8b T11 (una línea) y E7b-b T6 (el controlador leyó el diff y encontró el obligatorio).
- Poner el candado de la Ruleta en `GameState`: se queda en la vista.
- Borrar la rama remota `v2/e12-plan` desde el agente: lo bloqueó el clasificador; queda para el dueño.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan por barrer `v2i-integ-r26` y `v2i-docs-r26` (con el shell fuera), más los de relevos anteriores si no se barrieron.
