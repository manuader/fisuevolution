# SESION 2026-10-09 — v2, relevo 21c: las cinemáticas con su overlay, los cortes naturales de anuncios, el app open al volver, los cuatro cierres y la tarjeta de Dios

Tercera tanda de la misma sesión (21 → 21b → 21c): el dueño escribió «continua» en el chat a las 18:31 y el mismo controlador retomó el candado
(libre desde las 18:19; contexto ~315k, por encima del umbral de 300k, a pedido del dueño). Controlador opus; implementadores sonnet en worktrees
manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E8b T8, E7b-a T2, E8b T10 y E7b-a T4. Todo pasó por **`v2i/integ-r21c`** (BASE
`version-2` en `ea0bb23`). Carga de la máquina: 1,8 → 4 → 52 → 392 → 337 → 61; tope de 2 compilando cuando pasaba de 200.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | la punta de `c7f0330` tras su `rapido` VERDE (fast-forward y push; progreso 150 de 254) |
| `v2i/integ-r21c` | **`f830217`**: suma E13 T13 y E12 T14 (🟢 las dos) sobre `c7f0330` |
| `rapido` sobre `f830217` | RAPIDO_PENDIENTE |
| Progreso | **150 de 254 en `version-2` (59,1 %)**; **152 de 254 (59,8 %)** si el `rapido` sobre `f830217` da VERDE (`tasks.md` §2) |
| Bloqueadas | ninguna nueva. E7b-a T3 sigue ⛔ por sus dependencias y es **bloqueo de publicación** (ver «Carries») |

`rapido` de la tanda, en orden: `ebc2ddb` VERDE (EK 645 · unit 1081 · 0 rojos · Release 0); `f40323a` VERDE (EK 645 · unit 1103); `0fd90b6` VERDE
(EK 645 · unit 1117); `c7f0330` VERDE (EK 651 · unit 1117 · 0 rojos · Release 0).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E8b T8** el turno de la cinemática en la cola | `d192d76` | tarea VERDE (unit 61 · EK 644); revisión opus: Approved sin obligatorios |
| **E8b T9** overlay, sonido y «Saltar» de la cinemática | `1e70eb5` | `CinematicUITests` 3/3 (Receta R); EK 645 con `swift test` |
| **E7b-a T2** los cortes naturales de anuncios | `8f435c1` | tarea VERDE (unit 109, 12 nuevos); revisión opus: Approved sin obligatorios |
| **E8b T10** reencarnación y Dios disparan la cinemática | `fe79f0f` | tarea VERDE (unit 95, 11 nuevos); revisión opus: Approved sin obligatorios |
| **E7b-a T4** el app open al volver | `5618f4f` (+ el ajuste B del controlador) | tarea VERDE (unit 72); revisión opus: Approved sin obligatorios |
| **E8d T11** la intro como cinemática | `0da4c62` | tarea VERDE (unit 39, 5 nuevos); diff leído |
| **E2b T2** reencarnar conserva los pasivos (perilla apagada) | `396fd4d` | `swift test` EK 651; PacingTests sin cambios con la perilla apagada |
| **E13 T13** cada mejora dice qué cambia, de antes a después | `86ac82a` (+ claves `cd13a12`) | tarea VERDE (unit 39) |
| **E12 T14** la tarjeta del nombre al llegar a Dios | `82eca27` | tarea VERDE (unit 41); `RankingEntryCardUITests` 5/5 en SE |
| **Cierres:** E11 T7, E2a T15, E8c T10, E3a T12 | `91c58a2` (sesión aparte) | UN `completo`; ver `Docs/SESION-2026-10-09-v2-cierres-e11-e2a-e8c-e3a.md` |
| **`BonusHUDUITests`** | `91d0187` | aislado 3/3, la clase 3/3 |

Merges en `integ-r21c` de las últimas: `a416864` (E2b T2), `5588e7e` (BonusHUD), `5977d5b` (E13 T13), `bad9ccb` (E12 T14).

### Las cinemáticas: E8b T8 → T9 → T10 → E8d T11

- **T8** (`CelebrationQueue`): el caso `.cinematic` con un watchdog de 12 s; `GameState.cinematic` y `cinematicsAutorun`; topes por tipo: intro 1,
  Dios 1, arresto 2, reencarnación ∞; fixture `--uitest-cinematic`; `ElevatorRideOverlay.coversElevator` le suma `.cinematic` (el switch es
  exhaustivo). La duda del controlador («sin el overlay, ¿se encola en producción y traba 12 s?») se la llevó la revisión opus: **no**, porque
  `playCinematicIfDue` no tiene llamadores fuera de tests; T8 se integra sola. **Obligatorio a futuro (ya resuelto):** el disparador no entra a
  `version-2` antes que el overlay de T9.
- **T9:** `CinematicOverlay` a pantalla completa con holder propio y lease `fullscreen` del pool de videos; ducking en `AudioManager`;
  `isSkippable` excluye `.cinematic` (un toque al tablero no la saltea: el overlay se come los toques; sólo «Saltar»). `DebugPanel` con una
  sección Cinemáticas. El oráculo `tarea` dio ROJO en economykit por un test que no compilaba: se arregló y EK 645 pasó con `swift test` sin
  re-correr el oráculo. `isModal` se sacó: XCUITest lo trata como `Alert` y rompía los selectores.
- **T10:** `confirmPrestige` pide la de reencarnación antes del cofre; `markRevealed(godTier)` pide la de Dios; `reconcileCinematics` en el bootstrap
  re-encola la de Dios no vista (muerte de la app a mitad); la de reencarnación se descarta si Dios espera; `isCalmMoment` es falso con Dios en cola;
  `debugResetSave` suelta `cinematic` (una línea en `+Debug`).
- **E8d T11:** `reconcileIntro` corre antes de `beginTutorialPhase`: una partida nueva la pide; un save anterior la da por vista sin mostrarla;
  manifest inyectable. **La intro ya sale en partida nueva** (el manifest real ya trae `cine_intro`). La clave de accesibilidad se redactó sin ver
  el video.

### Los anuncios: E7b-a T2 y T4

- **T2** (`GameState+Ads` nuevo): cortes `sheetClosed`, `offlinePopupDismissed`, `reincarnation` y `celebrationsDrained`; el **reloj 1.x se borró**
  (`cadence:`, `armIfDue`, la sección `interstitial` de `rewarded_ads.json`); `fullScreenUIActive` (ascensor, botonera, compra) frena los cortes;
  `celebrationsDrained` usa `bigCelebrationSinceIdle` (el último en irse puede ser un toast).
- **T4:** app open al volver. Precarga al irse si `couldShowAppOpenOnReturn`; decide **antes del offline** y retiene la cola; los `show*` devuelven
  `Bool` y `recordShown` sólo si salió; `restrictionBeforeAd`; plazo de 10 s en el observer de AdMob; `preloadAppOpen` exige `canRequestAds`. Tocó
  `AdsProvider`, `Coordinator`, `AdMob`, `Stub` y `Scripted`. Sin la pasada manual en simulador. **Ajuste B del controlador:** `defer
  releaseCelebrationsAfterAd` en `presentHeld`.

### E2b T2, E13 T13, E12 T14

- **E2b T2:** `OroConfig.inheritsPassiveUnlocks` (default `false`); `PrestigeCalculator.inheritedPassiveUnlocks` mergeado sobre `.fresh`; perilla en el
  informe (`Report.passiveUnlocksPerRun`). Con la perilla apagada, `PacingTests` no cambia.
- **E13 T13:** `upgradeEffectText` con una plantilla por efecto: lucky muestra crítico **y** dorado de antes a después; offline 35 % base + nivel;
  prestigio ORO × (1 + nivel × magnitud); decimal sólo si no es entero; 6 claves de i18n. Sin la Receta R de `UpgradesMenuUITests` ni captura SE.
- **E12 T14:** overlay `rankingCardLayer` bajo la cinemática; sale con `entryPrompt && isEnabled && isCalmMoment`; publica `uiCoversBoard` (el intersticial
  y los visitantes lo respetan); `uiTestMarkers` / `boardIsCovered` para que el type-checker no se ahogue. Con el ranking apagado la tarjeta **no sale
  y no gasta `cardOffered`**.

### El arreglo de `BonusHUDUITests`

Era el test, no el juego: el commit `d121c97` (`feat(regalos)`) enciende el puntito de `hud.bonus` también con un boost gratis listo, y el mate
nace listo. El test ahora gasta el mate al arrancar (`91d0187`, sólo `BonusHUDUITests.swift`). Ya no hace falta declararlo en `rojos-declarados.txt`.

## Las revisiones opus y sus carries

- **E8b T8 → T9/T10 (hechos):** un toque al tablero saltea la cinemática y `abortBoardCelebration` borra `pendingBoardCelebration` (T9 traga los toques
  y saltea sólo con «Saltar»); lo pendiente no se guarda (`reconcileCinematics`); la intro detrás del tutorial (`allowedKinds`); una cinemática
  colgada tras un reset (T10 suelta `cinematic` en `debugResetSave`).
- **E7b-a T2 → T3 y al dueño:**
  - **NO publicar T2 sin E7b-a T3.** Hasta que entre T3 sale un intersticial en **cada** corte, no alterna (`readyFormats` excluye la pausa,
    `GameState+Ads.swift:32`). El primero puede salir a los 3 min (en la 1.x eran 7).
  - Sin consentimiento UMP, el stub no dibuja nada en Release (`useRealAds` es true y está validado): no sale anuncio falso.
  - **Falta `canRequestAds` antes de precargar o mostrar el intersticial y el rewarded** (sólo el app open lo chequea): en la UE sin consentimiento
    se piden anuncios. Tarea aparte / E7b-a.
  - `recordShown` corre aunque no se haya mostrado (`GameState+Ads.swift:74`): T4 lo saldó con el `Bool` de `show*`.
- **E7b-a T4 → E7b-a/E7b-b:** (A) **un solo observador de AdMob para todos los formatos** → ignorar los avisos de otro anuncio (`ObjectIdentifier`);
  (C) `canRequestAds` sólo en el app open; falta en intersticial y rewarded (el mismo faltante de T2); (D) `Set<CelebrationKind>??` → un enum. El plazo de
  10 s sólo corta si nunca llegó `adWillPresent`; el orden app open → offline → diario está bien; el reloj común de 120 s frena los dos sentidos.
  **Al dueño:** verificar en device el *fill* del app open (la precarga ocurre al pasar a background).
- **E8b T10 → al dueño:**
  - El corte `.reincarnation` casi siempre **se saltea por la cinemática**, y el intersticial sale por `.celebrationsDrained` al cerrarla, **antes del cofre**.
  - Un **veterano v1 parado en Dios ve la de Dios en el primer arranque** de la 2.0, antes del offline y del diario (lo pide el plan).
  - Dios en cola tras reencarnar sale en la run nueva.
  - Opcionales: test del SFX, test de `!isSafeMoment` tras `confirmPrestige`, hápticos bajo la cinemática, CloudKit a mitad de sesión.
- **E8d T11 → E8d T15:** la intro ya sale en partida nueva; la clave de accesibilidad se redactó sin ver el video; mirar la intro detrás del tutorial.
- **E13 T13 → E13 T14 / dueño:** verificar los **2 renglones en el SE** (lucky con dos efectos, offline) y **borrar `ui_up_crit`** (lucky usa `ui_up_golden`).
- **E12 T14 → E12 T16:** con el ranking apagado la tarjeta no sale (producción, hasta que haya servidor); `RankingEntryCard` publica `uiCoversBoard`.

## El conflicto resuelto en `confirmPrestige`

La rama de E8b T10 chocó con la de E7b-a T2 en `GameState+Prestige.swift` (`confirmPrestige`). T10 sólo cambiaba el comentario del reloj viejo y T2 había
puesto el corte nuevo: **quedó `scheduleNaturalBreak(.reincarnation)`** (de T2) con el pedido de la cinemática de T10 encima. No hay otra decisión escondida.

## Las perillas de E2a T15 (para E2b; `--upgrades`, base nueva)

Detalle y método en `Docs/SESION-2026-10-09-v2-cierres-e11-e2a-e8c-e3a.md`. La base es la línea vigente (**Dios 31,34 h**, 13 reencarnaciones), no la del brief (30,73).

| Variante | Dios activo | Reenc. | Las 6 al tope |
|---|---|---|---|
| base | **31,34 h** | 13 | 20,67 h · 9 |
| `defaultCostGrowth` 1,12 + `mergeRefundCounts` 1 | 27,76 h | 12 | 15,67 h · 8 |
| `priceReliefPurchases` 24 | 30,05 h | 13 | 19,67 h · 9 |
| `staffedFloorBonus` 0,05 · `requiresLastRunWall` · `capacity` 15 | = base | = base | = base |

Sólo el par growth+refund y el amortiguador mueven el simulador; pisos en marcha y capacidad 15 no mueven nada porque el bot nunca llena un piso.

## Para el dueño

- **No publicar E7b-a T2 sin T3** (intersticial en cada corte); verificar el *fill* del app open en device; consentimiento en la UE (`canRequestAds`).
- Probar en el iPhone: la intro en partida nueva, la cinemática de reencarnación (se saltea y el intersticial sale antes del cofre), la de Dios en un save v1.
- Escenarios a mano de E11 (diálogo del sistema de notificaciones), E2a y E8c (Reduce Motion, hoja, fondo, ORO/video); PNG de iPad a ASC (E10).
- Siguen los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16, ahí se despliega la lista de palabras), mediación por SPM (E7b-a T6).

## Trampas nuevas

- **Un agente con una espera de fondo propia puede re-entregar el mismo reporte varias veces** (visto otra vez en esta tanda). No hace falta `TaskStop`
  si `ps` no muestra procesos suyos: termina solo. Ya estaba en la ola P; sigue pasando.
- **El oráculo usa el repo de su propia ruta, no el `cwd`.** Un `bash <ruta>/Tools/v2/oraculo.sh` corre sobre el repo donde vive ese script: lanzarlo con
  la ruta del worktree que se quiere verificar, o se verifica otra rama.
- **Un test del cierre puede estar rojo por el test y no por el juego** (`BonusHUDUITests`): mirar primero qué commit cambió la semántica de lo que mide.

## Oráculo

- `rapido` sobre la punta de `integ-r21c` (`f830217`: todo lo de arriba): RAPIDO_PENDIENTE.
- `completo` de los cierres sobre `0383a1d`: EK 642 · unit 1070 · store 16 · Release 0 · ui 96/4/4 (los 4 rojos de `LocalizationLayoutUITests` se corrigieron;
  `BonusHUD…Regalos` se arregló en `91d0187`; `RankingTabUITests.testSeDeslizaHastaElRankingDesdeMejoras` flaky 6/6 aislado) · store-ui 2 · ipad-ui 4 · pipeline 89.

## Lo descartado

- Tratar a `BonusHUDUITests` como rojo de base declarado: era el test, se arregló.
- Integrar el disparador de cinemáticas antes que el overlay de T9.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan por barrer `v2i-integ-r21c` y `v2i-docs-r21c` (con el shell fuera) y los anteriores si no se barrieron.
