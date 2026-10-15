# Sesión 2026-10-15 — relevo 58: `version-2` avanza, E14b olas 7–8, E15 F0 y el primer build único de integ-r58

Relevo por el disparo horario de la rutina `fisu-v2-relevo-a` (15:01, puerta cerrada: el 57 tenía latido). El dueño dijo
en vivo «arrancá, ya podés agarrar el lock» y el 57 lo liberó a las 15:45:47. Cuota al llegar: 5 h 7 %, semanal 31 %.
Regla del dueño vigente: **los agentes no compilan por tarea**; la ola se integra, se compila una vez y un agente arregla
lo que falle. Trabajo en `v2i/integ-r58` (worktree `.claude/worktrees.nosync/v2i-integ-r58`), armada sobre `c6034332`.

## Resultado en una línea

**`version-2` = `36697cac`** (integ-r54 VERDE: E14 T13–T26, E14b B1–B19, B26, B27 y el cofre rehecho). En
**`v2i/integ-r58` (pusheada, sin `completo`)**: E14b B20–B24, B28 y B29, E15 F0 T1–T7 y T9, `tabsMoved` sólo para
veteranos y el ícono del Ranking. El build único compiló y la unit quedó verde. El UI de las tareas nuevas dio
**60 verdes · 5 rojos · 0 salteados**. Esos 5 los aísla el 59.

## Decisiones del dueño

En vivo, en este chat:

- «Arrancá, ya podés agarrar el lock».
- «Desplegá agentes que sigan con el resto de correcciones de mientras»: la ola 7 salió en paralelo al `completo`. Es una
  excepción a «máquina sola» por orden del dueño; los agentes no compilan.
- **`tabsMoved` sólo para veteranos**: la bandera `TutorialFlags.knewOldBar` se enciende al migrar con el tour pendiente.
- **Generar `ui_menu_ranking`** con Gemini Flash y meterlo (D8: sin aprobación).
- «Seguí con todo el desarrollo».
- «Dejalo para el próximo relevo»: el cierre. Se dejó de despachar y el UI terminó solo.

Desde la sesión del dueño «Fisu Evolution v2 roadmap» (E15):

- **O1 aprobado tal cual**: el borrador `v2i/e15-t7` `99b8c7cd`, con la Opción A, el id propio y Supabase Free (logs de
  1 día).
- **O2 aplicado**: las migraciones de T4 en `oejmjpwfxpwzzakdjxwp`, versiones 20261015000001/2, con el interruptor en
  `false`, RLS y cron, y el insert anónimo rechazado. **Regla: cualquier cambio al SQL de T4 va en una migración NUEVA.**
- **O3 hecho**: impression-level ad revenue activado en AdMob.
- **O5 publicado**: `adergames-site` `main` = `658df9f` (privacidad + ORO → dólar blue en `terms.ts`), verificado en vivo.
- **O4 postergado al día del envío** de la 2.0: ASC exige reflejar la versión en tienda. La etiqueta objetivo está en
  `DUENO.md`.
- **El mensaje RGPD de UMP** existe y está publicado desde el 2026-10-12 (fines 1 y 8–10, EEE/UK/CH). Ahora también en
  español (propagación ≤ 1 h). Se verifica con `--debug-consent-eea` en E15 T8.
- Para E10: ASC pide **aceptar el acuerdo de licencia actualizado**, que BLOQUEA enviar versiones y lo acepta el dueño.
  También hay **preguntas nuevas de redes sociales** en la clasificación por edad. El borrador §4 de App Privacy y el
  setup §1.7 están mal: en ASC **no** están declarados el ranking, Product Interaction de AdMob ni Other Diagnostic Data
  de Meta (el SDK de Meta sigue en `project.yml`). Quedó como filas nuevas de E10 en `tasks.md`.

## Decisiones por default del controlador (el dueño las puede cambiar)

| Decisión | Por qué |
|---|---|
| **Opción A, falla cerrado** (E15 T5/T7): la compuerta de telemetría exige consentimiento TCF real (fines 1/8/9/10), dentro de `canRequestAds`; si falta `gdprApplies`, no sale nada | la revisión de T7 encontró que `canRequestAds` = «formulario completado», no consentimiento: el texto prometía un apagado que el código no cumplía |
| **Id propio de telemetría** (Keychain `ThisDeviceOnly`), no el UUID del ranking | «anónimas» era falso con el UUID compartido con el ranking |
| **La medición cruza el reset** (E15 T1: `ResetPlan` + `resolveAcrossReset`) | es medición y la economía no la lee; perderla en cada reencarnación vaciaba el embudo |
| **Las cajas viejas de B18 se reubican enteras** al cargar (B22) | el save de B18 no tenía `y`; la revisión opus lo dio por correcto |
| **El aterrizaje de la caja usa el háptico `.tick`** (`722fb0bc`) | `.tap` no existe en el enum |

## Qué entró

### A `version-2` (fast-forward a `36697cac`, pusheada)

- `completo` `20261015-154752` sobre `c6034332`, con la máquina sola al lanzar (load 1,9; pico ~140):
  - VERDES: EK 976, build, Release 0 warnings, store-unit 18, store-ui 3, iPad 4, SE 2, pipeline 99 y pacing (Dios 45,40 h · 6 reenc.).
  - unit: 2075 + 1 rojo (`ElevatorRideTests.skipWhileOpeningDoesNotDingTwice`).
  - ui: 181 + 6 rojos + 4 salteados.
- Aislamiento `20261015-180040-aislar-r58` (simulador propio): ElevatorRide 15/15 verde; 5 UI verdes (cofre es,
  CharacterSheet y Prizes ×3), o sea **6 de 7 rojos eran carga**. El único rojo real fue
  `RankingTabUITests.testConElServidorApagado…`, y era **del test**: con el 503 el store se apaga antes de abrir el Menú
  y B26 esconde la tarjeta. Se arregló el test en `36697cac` y la clase dio 6/6 aislada.
- Entraron E14 T13–T26 (y R53-UGC), E14b B1–B19, B26, B27 y el cofre rehecho.

### A `v2i/integ-r58` (pusheada; falta el `completo`)

| Tarea | Commits → merge | Qué |
|---|---|---|
| B28 | `5e641048` → `47fd6b30`; build `6d8a3ca7`, `6abec9b7`, `bbc6687b` | `BarFlapArt` (etiqueta, billete, carpeta `FolderPlate`), `BarFlapLayout` puro, `centerButtonWidth` 78 |
| fix tabsMoved | `335f079f` → `c49d31e6` | `TutorialFlags.knewOldBar`: `tabsMoved` sólo para veteranos |
| ícono del Ranking | `c5033e86` → `09bd1014` | `ui_menu_ranking` (podio + medalla, Gemini; proyecto `fisu-v2-ranking` en a-i-g `426cb0b`, sin push). `hud.ranking.label` **no** está huérfana (`BottomMenuBar:92`) |
| B20 + B21 | `1107eb76` + `b7a3c8d0` → `5f6bb08b` | el visitante a mitad del piso, `walkRange` 35–65 %, paseo 18 pt/s; el turno `.visitorEncounter` se suelta al empezar la entrada; ofertas y tips se re-encolan al llegar; `--uitest-slow-entrance`; el pop-up sólo al tocar |
| B22 + B23 | `d289a399` + `212b60a3` → `d87a0cf3` | `PackageBox.y` opcional, `PackagePlacer` (48 intentos, referencia y SE), `BoxExitPath` (el personaje sale de la caja), `BoxExitInterruption`, umbral de drag desde el dedo (un temblor <10 pt cuenta como toque) |
| E15 T4 | `254559d0` + `37ff5f26` + `25f6ca6e` → `e83c2b2f` | `telemetry_events`, `telemetry_enabled()`=false, RLS por columna, retención 400 d; `test.sh --sql` 33 OK |
| E15 T5 | `866a4b2f` + `a7a6dff2` + `cf42ebbb` → `b8771de7` | cliente sin cablear; `TelemetryConsent` pura (Opción A); id propio |
| E15 T7 | `e915fc79` + `99b8c7cd` → `d87b2603` | `Distribution/release/privacidad-e15-BORRADOR.md`, manifiesto de privacidad |
| E15 T1 | `1a76fd9a` + `a1843649` → `bae58cd0`, `070365f9` | `AdImpression`/`AdRevenueLedger`/`OfferFunnel` en EK, `MetaState` opcional sin bump; EK 1013 |
| B29 | `79d36e1c` + `13dd1c7e` → `57d728ed`; claves `ff467194` | recompensas en dos pasos (`RewardDouble`, `RewardDoubleOffer`); pacing `.free` 45,40 · `.ads` 32,19 (antes 30,60) · `.max` 30,38 |
| E15 T2 | `a810f5a2` → `74667860` | `paidEventHandler` en los 4 formatos (GMA 13.11.0), sonda `ads.ledger.count` |
| E15 T9 | `6318c844` → `92417beb` | `privacy.md` ×2 byte a byte, `terms` §3, notas 3.985, setup §1.7 |
| E15 T3 | `22ff3433` + `81bf9a72` → `0a2fedaa`, `4857a72a` | `OfferFunnelTracker` desde `RewardedOfferButton` (cubre el paso 2 de B29) |
| E15 T6 | `7c8f2c5e` + `81bf9a72` → `c3c0b94c`, `4857a72a` | telemetría cableada (sesión, impresión, oferta, compra, reencarnación); set propio de transacciones |
| fix del Ranking | `36697cac` → `3864079d` | el mismo fix del test, traído desde integ-r54 |
| B24 | `056b5259` + `8814c320` → `f0d773ef`; clave `7ef70f8d` | el colchón después del video. Detalle: **`Docs/SESION-2026-10-15-v2-e14b-b24-colchon.md`** |

Todas pasaron por revisión opus. B20, B22, B24, B29, T1, T3, T5, T6 y T7 salieron APROBADO CON CAMBIOS y los cambios
están arreglados; T2 salió APROBADO. El crítico de B29 (C1: `onDisappear` de la capa en las hojas rechazaba el paso 2
mientras AdMob presentaba, así que el video se veía sin cobrar) se arregló con `isWatching`/`declinePending` en el
estado y 1 s de gracia para un premio tardío. El crítico de B24 (tras reencarnar, el colchón quedaba en un piso cerrado)
se arregló reubicándolo en `tick` y en `confirmPrestige`.

## Inventario de B29 (las fuentes de recompensa y su ×2)

El paso 1 cobra con el vuelo de B13. El paso 2 (`RewardDoubleOffer`: «¿Lo duplicás?», «×2 con video» / «No, gracias»)
sale **sólo si hay un video listo** (`ads.isRewardedReady`). El `site` es el id de accesibilidad del botón y el lugar del
embudo de E15.

| Con paso 2 | `site` |
|---|---|
| Visitantes que regalan (Ministro, Turista, Sindicalista, Puntero bolsón, Influencer código, Cryptobro, Alien, Arca, Contador, Lizard, Vecina chisme) y retos ganados (Vecina favor, Zombie, Coach) | `double.visit.<guion>` |
| Ganancias offline | `double.offline` |
| Diario (días de plata; el special y el cofre del día 7 no) | `double.daily` |
| Carrera (premio de una vez) | `double.career` |
| Ruleta, giro gratis o de bonus: **es el «repetir premio» unificado** | `double.wheel` |
| Colchón de regalo (`TreasuresState.gifted`) | `double.mattress` |
| Logros con plata o blue | `double.achievement` |
| Evento con plata (Aguinaldo) | `double.event.aguinaldo` |

**Sin paso 2:** lo que ya costó un video (colchón por video, giro por video, cartas del Vendedor, lluvia, Fusionar todo,
boosts, videos de Regalos, pausa, cofre extra), lo pagado (Ruleta con blue, Tienda, ofertas) y lo único (skins, caja de
la Aduana, specials). Tampoco tienen paso 2 los tratos (arresto, venta, acto), Compartir y el boost gratis. **La Marcha
(B25)** se engancha después de cobrar con
`offerGrantDouble(site: "double.marcha", placement: .visitor, coins: 0, rewards: [.blue(30)], source: …)`.

Cómo se paga el ×2: la plata ya cotizada, sin volver a cotizar; blue y cajas otra vez por `grant`; un efecto con
duración dura el doble, sin apilarse.

## El build único de integ-r58

- `rapido` sobre `7ef70f8d`. Los errores salieron **de a uno**: `SparkleShape` duplicado (`6d8a3ca7`), háptico `.tap` →
  `.tick` (`722fb0bc`), `BarFlapArt` con `Face.Type` no `Sendable`. Ahí el controlador despachó `fix-build-r58` (opus)
  con permiso de compilar sólo el build hasta verde: `6abec9b7` (el vaivén de la carpeta sale a un `ViewModifier`) y
  `d87449a8` (los tests de B29 y B22 compilan contra la integración).
- `rapido` sobre `d87449a8`: **EK 1017 ✅, Release 0 warnings ✅, unit 2259 + 4 rojos**. Uno era
  `verbatimTextCarriesNoWords`: «FisuJobs» pasa a `brandWords` (`bbc6687b`). Los otros 3 eran tests viejos (el brillo
  del colchón con la misma textura; el fixture casi inviable de `boxesKeepClearOfTheMattress`; `wasSeen = onStage` de
  B21) y se arreglaron en `7c26a20b`. Las 8 clases dieron 133/133 verde.
- **UI de las tareas nuevas** (`build/oraculo/20261015-191613-ui-integ58`, 19 clases, simulador propio):
  **60 verdes · 5 rojos · 0 salteados**:
  1. `PrestigeIndicatorUITests.testLosBotonesDeLaBarraNoPisanElPlato`: el billete (246…394) pisa el plato (191…269). Es de B28.
  2. `PrizesUITests.testTheGiftedMattressOpensOnTheBoard`: no sale el pop-up del premio. Puede ser B24 o el paso 2 de B29.
  3. `TutorialUITests.testElPuntitoDeLogrosNaceEnElTabYMuereAlCobrarElUltimo`: `ach.claim` sigue tocable. ¿El paso 2 de B29 en Logros?
  4. `VisitorMechanicsUITests.testElVendedorMuestraTresCartasYSeLlevaUna`: tocar la tarjeta no abre el pop-up. Es de B21.
  5. `VisitorUITests.testUnMergeEnMedioDeLaEntradaNoLaCortaYTocarloAbreElPopup`: «el fixture no sembró los ocho». Es de
     B21 y usa la entrada lenta (`--uitest-slow-entrance`).

  **Aislar los 5 primero.** El 4 y el 5 pueden compartir causa: el pop-up que se abre al tocar la tarjeta.

## Trampas nuevas

- **El stash de git es compartido entre worktrees**: un agente lo usó. Hay que mirar `git stash list` antes de un merge
  (acá estaba vacío) y prohibir `git stash` a secas en los briefs.
- **Compilar en tandas da los errores de a uno**: cada `rapido` frena en el primer error de Swift. Con varias tareas
  integradas sin compilar, conviene un agente con permiso de compilar sólo el build hasta verde, en vez de ir y volver
  con el controlador.
- **`keyframeAnimator` con genéricos pide `@Sendable`/tipos `Sendable`**: `Face.Type` no lo era. Una closure animada que
  captura un tipo genérico va mejor en un `ViewModifier` propio.
- **Hay tests que no se corrieron nunca hasta el build único**: con agentes que no compilan, los tests nuevos se
  escriben contra APIs que otra rama cambió. Tres rojos de unit eran tests viejos y no código roto. Leer el test antes de
  tocar el código.
- **`canRequestAds` no es consentimiento** (UMP): sólo dice que el formulario se completó. La telemetría mira TCF.

## Carries para decidir (el 59 o el dueño)

- El visitante espejado da vuelta el texto de las remeras (`drawnHeading`), y no tiene bob al caminar.
- La oferta de compra del presentador se abre sola. Viene de antes.
- Tocar el aviso de un congelado mientras entra sólo lleva al piso.
- B29 M3: el modificador de la Ruleta en el ×2 alarga en vez de apilar. M4: la carrera puede pagar menos en el paso 2.
  Hay −~3 impresiones/día por el giro sin «repetir».
- El colchón puede caer pisado si el piso está lleno (sorteo de y 0…1).
- 1 s más de «Cargando video…» por la gracia del premio tardío (fix de B29).
- B28: `flapHeight` sigue en 44; la Fisura sobresale ~16 pt; el ancla `.hire` del tutorial cae en la cara.
- B22: falta el póster de caja abierta para bajar el clip mientras espera.

## Para el dueño

- Ver «Decisiones por default» arriba (Opción A, id propio, medición que cruza el reset, cajas reubicadas, `.tick`).
- E10: aceptar el **acuerdo de licencia de ASC** (bloquea enviar) y responder las **preguntas de redes sociales** de la
  clasificación por edad. O4 (etiqueta de ASC) el día del envío; O6 (prender el interruptor) cuando quiera.
- B24 H4: en su iPhone, el log `reward after dismiss` dice si el premio llega después de cerrar el video.
