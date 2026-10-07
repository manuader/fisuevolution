# E4b — Visitantes y eventos v2, lo que se ve: el escenario, los chips, los efectos y el Álbum · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que los visitantes y los presentadores de eventos **entren a escena, hablen, actúen y se
vayan** (ya no quedan chiquitos en el tablero), que se los toque desde un chip con su cara, que
cada evento deje un chip con la cara de quien lo anunció y su cuenta regresiva (se va el banner),
que el Apagón, los Campeones y la Liquidación se vean en el tablero, y que los especiales
conseguidos vivan en un Álbum en la Oficina central.

**Architecture:** E4a dejó el motor (qué, cuándo, cuánto). E4b le pone escena: un escenario en la
capa de la cámara (`StageController`, colaborador de `BoardScene`, que mueve todo por frame para
poder probarlo sin vista), una máquina de estados de una sola entrada en `GameState`
(`stageVisit`: entrando → esperando → yéndose; la entrada es un turno corto de la cola,
`.visitorEncounter`), chips SwiftUI bajo el HUD como objetivo de toque determinista y accesible, y
popups que se abren con `fisuSheet()`. El arte de los visitantes todavía no existe: todo cae a un
respaldo (canónica de la v1 para los especiales, disco con símbolo para los nuevos, foto quieta en
vez de loop).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · AVFoundation (los loops de retrato, cuando lleguen) · EconomyKit · Swift Testing ·
XCUITest · XcodeGen.

**Fuente:** `Docs/PLAN-v2.md` §4 "E4" (Escena, UI, Sacar los especiales del tablero, Álbum, Eventos
v2, Efectos de escena por código), §2, §5 y `Docs/biblia-visitantes.md` ("Dónde aparece un
visitante"). E4a (`2026-10-07-v2-e4a-visitantes-eventos.md`) es la base: **sus Global
Constraints, su sección "Verificación" y su tabla de herencia de E1/E3 valen acá enteras**; abajo
van sólo los agregados.

**Rama de la épica:** `v2/e4-visitantes` (la misma de E4a). E4b arranca cuando E4a cerró (T10).

## Global Constraints (además de las de E4a)

- **La escena no se toca más que en ganchos cortos**: `BoardScene.swift` tiene 1.828 líneas y sus
  miembros son `private` (PLAN-v2 E4). Lo nuevo vive en `Scenes/Stage/` y `BoardScene` sólo
  llama (adjuntar, ubicar, actualizar, tocar). Cada tarea que la toca dice exactamente qué líneas.
- **Todo lo que se mueve en el escenario se mueve por frame** (`update(delta:)`), no con
  `SKAction`: así el test lo ejerce con un `SKNode` pelado y deltas inyectados. Con Reduce Motion,
  fundido en vez de caminata, sin pulso y sin baile (`BoardScene.prefersReducedMotion`).
- **Escenario en x ∈ [28 %, 72 %] del ancho**, para no quedar bajo los botones flotantes de los
  costados (la botonera del ascensor de E3a, la columna lateral de E7b).
- **Toda hoja nueva con `fisuSheet()`** (`SheetPresentationGuardTests` de E3a T6 lo exige) y
  `presentationDetents` propios. Mientras un popup del escenario está abierto, `RootView` pone
  `uiCoversBoard` (como hacía con la carta del special): así frenan la paciencia, los cambios del
  tablero, las lecciones y los intersticiales.
- **Sin arte, con respaldo**: ningún flujo espera al batch de E8. El contrato de arte es el de E8
  pipeline: `manifest.npcs["<id>"|"<id>_talk"|"<id>_action"|"<id>_face"]` en `npcs.atlas`, la
  canónica de los especiales en `manifest.characters["sp_*"]`, y `loops_manifest.json`
  `portraits["<id>"]` (`loop_<id>.mov`). Con entrada se usa; sin entrada, el respaldo.
- **Un solo `AVPlayer` a la vez** (PLAN-v2 E8): el loop de retrato sólo corre en el popup abierto.
- **Toda mecánica nueva declara su lección** en el sistema de lecciones de hoy
  (`GameState.TutorialLesson` + `TutorialTarget` + `tutorial.tip.<id>`): visitante (T3), chip de
  evento (T4) y Álbum (T8). E9 las migra a su currículo y decide si la primera visita la aloja una
  `TutorialInlineCard`.
- Strings por snapshot `Tools/v2/claves-pendientes/e4b-tN.json` (y `e4b-tN.quitar` para borrar),
  con `Tools/v2/catalogo.py aplicar|quitar`.
- **Commits** `feat(visitantes): …`, `feat(eventos): …`, `feat(album): …`, `feat(escena): …`, SIN
  `Co-Authored-By`.

## Verificación

La de E4a (oráculo, Receta R con `build/DD-e4` y simulador `e4-…`). `rapido` al cerrar T1, T2,
T7; `completo` al cerrar T3, T4, T5, T6, T8, T9 (tocan lo que se ve o la escena) y la épica (T10).
Los UI tests nuevos (`StageUITests` no existe: el escenario se prueba por unit; los de UI son
`VisitorUITests`, `EventChipUITests`, `VisitorMechanicsUITests` y `SpecialsAlbumUITests`) entran
solos al `completo`.

Mirar la escena **en los dos sentidos** (trampa 9): cada tarea con escena se verifica en el
simulador con Reduce Motion prendido y apagado, en el iPhone SE y en el iPad Pro 13".

## Las referencias de PLAN-v2 E4 que toca E4b, verificadas contra el árbol (`68bb47c`)

| Lo que cita el plan | Dónde está hoy | Qué hace E4b |
|---|---|---|
| `BoardScene.swift` ya tiene 1828 líneas y sus miembros son `private` | 1.828 líneas; `cameraOverlay` `:16`, `bottomInset` `:151`, `init` `:287-303`, `update` `:322-345`, `touchesBegan` `:617`, `layoutBoard` `:1205`, `cameraOverlay.position` `:1226` (origen abajo a la izquierda), z del reveal `:1102-1185` (195–210) | T1 cuelga el escenario de `cameraOverlay` con cinco ganchos; T6 suma los efectos con tres |
| globo vectorial único `UI/Art/BubbleGeometry.swift` | no existe; `SpeechBubble`/`ui_speech_bubble` se borraron en `version-2` (PLAN-v2 §4) | T1 |
| `VisitorPopupView` con `LoopingPortraitView` "que generaliza `ChestCinematicPlayer`" | `ChestCinematicPlayer.swift` (174 líneas, el preroll y el congelón del cofre en HANDOFF §7) | T3 crea `LoopingPortraitView` **aparte** (duda 3): el cofre no se toca |
| `StageChips` bajo el HUD | `RootView.hudColumn` `:427-450` (después de E3a T11, con `playColumn()`) | T3 |
| `ActiveBonusBar` acepta toques en los chips de evento | `.allowsHitTesting(false)` sobre toda la barra (`ActiveBonusBar.swift:35`) | T4: sólo los chips de evento son botones |
| se borran `EventBannerView`, `activeEvent`, `announcedEventID`, `eventBannerIsVisible` | `EventBannerView.swift`; `GameState.swift:238, 389-391`; `GameState+Celebrations.swift:55-56, 135-137, 154-157`; `CelebrationKind.eventBanner` `CelebrationQueue.swift:27,49,69` | T4 |
| Apagón: velo, velitas, multiplicador +0,07 por velita | `EventPlanner.lightCandle` (E4a T4); `sfx_blackout.caf` sin caso en `AudioManager.SFX` (`:14-30`) | T6 |
| Campeones: baile + confeti nuevo en `ParticlePool` | `ParticlePool.EffectType` tiene `tap, merge, evolution, coins` (`:9-14`) | T6 suma `.confetti` |
| Liquidación: `HireQuote.listCost` tachado en FisuJobs y en el atajo, con piso de apilado | no existe `listCost`; FisuJobs pinta `PricePill(text: row.costText…)` (`FisuJobsView.swift:455`) | T7 lo resuelve en la app (`JobRow.listCostText`, `QuickHireOffer.listCostText`) y el piso en `ModifierMath` |
| se borran `renderAnchoredSpecials`, el long-press de especiales, `visibleFloorSpecials` y `presentSpecialInfo` | `BoardScene.swift:1236, 1240-1288, 630-642, 1747-1753` (`specialZ`); `GameState+Tower.swift:75-93`; la puerta `debug.special.info` (`DebugPanelView.swift:36-43`) y su UI test (`TutorialUITests.swift:555`) | T9 (después de T8, que mueve la carta al Álbum) |
| `meta.specialAnchors` queda sólo para decodificar | `PlayerState.swift:258,388`; lo escriben `GameState+Actions.swift:313-315` y `+Debug:334` | T9 deja de escribirlo |
| Álbum: quinta tarjeta de ancho completo `menu.card.specials`, sin tocar las cuatro | `MenuView.swift:37-42` (`Destination`), `:50-71` (las dos filas) | T8 |
| pasivo del especial con `EffectDescriptor` | `EffectDescriptor` no tiene el caso de los especiales | T8 suma `amount(forSpecial:)` |

E3a T10 **modifica** `renderAnchoredSpecials` y **suma** el test `specialsSitBetweenTheFloorAndTheCrowd`
con `PlayLayout` (`CrowdDepthTests`): E4b T9 borra los dos tal como hayan quedado.

## Lo que E4b usa (además de lo que E4a hereda de E1/E3)

| API | La define | La usa |
|---|---|---|
| `RewardSpec`, `GameState.grant`, `grantableRewardKinds`, `creditCoins`, `coinsPerProductionSecond`, `isCalmMoment` | E4a T1, T8 | T2, T4, T5 |
| `VisitorsConfig`, `VisitorScheduler`, `VisitContext`, `VisitPlanner`, `VisitOffer`, `VisitOption`, `ChallengeTerms`, `VisitValuation` | E4a T5, T6 | T2, T3, T5 |
| `VisitCopy` (`bubble`, `ask`, `optionTitle`, `text`, `effectText`, `durationText`, `name(of:)`) | E4a T7 | T2, T3, T4, T5 |
| `EventCatalog`, `EventScheduler`, `EventPlanner.running/lightCandle`, `GameState.startEvent/escapeEvent/eventFee/eventFeeText/peekUpcomingEvent/cutNegativeEvents/fireDueEvent` | E4a T4, T9 | T2, T4, T6 |
| `advanceEngagement(delta:)`, `applyEngagementFixtures`, `fixtureValue`, `engagementAutorun`, `debugStartEvent` | E4a T9 | T1, T2, T4 |
| `BoardChange.Origin.visitor`, `enqueueBoardChange`, `confirmWithoutGesture` (la escena reproduce las salidas) | E4a T6; E1 T9, T10 | T2 |
| `fisuSheet()`, `playColumn()`, `PlayLayout` | E3a T6, T4, T3 | T3, T4, T8 |
| `QuickHireOffer` y su `secondLine` | E3b T5–T7 | T7 |
| `MenuView` con `NavigationStack(path:)` y el paginador | E3b T3 | T8 |
| el `RootView` de E3a T11 y E3b T4/T8/T9 (`menuSession`, los `onChange` de `uiCoversBoard`) | E3a T11, E3b T4 | T3, T4, T9 |

## El escenario en una página

```
GameState                                   StageController (escena, por frame)
─────────                                   ───────────────────────────────────
presentOnStage(actorId, role)               (entrando y SIN turno: no se ve)
  stageVisit = .entering ──► cola: .visitorEncounter (prioridad 5, tope 10 s, salteable)
                                            turno → camina desde un borde a 90 pt/s, con bamboleo
                                            (Reduce Motion: fundido en el centro)
stageActorArrived(id) ◄──────────────────── llegó a x = centro de [28 %, 72 %]
  .waiting · arrive():                      espera: pulso suave + globo vectorial
    visitante → oferta COTIZADA ahora (VisitPlanner) y globo con sus números
    presentador → startEvent (efecto al llegar) y globo con su frase
  paciencia 30 s (presentador: 4 s), corre sólo si isCalmMoment, sin popup y sin reto
chip "stage.chip.visitor" ─ tocar ─► visitorPopup (fisuSheet, paciencia congelada)
  chooseVisitOption → revalidar → plata + grant + salidas por el embudo E1 → frase y se va
sendStageActorAway() → .leaving ──────────► camina hacia el otro borde (o fundido)
stageActorLeft(id) ◄────────────────────── salió de cuadro → stageVisit = nil

skip / watchdog del turno → settleStageArrival(): llega igual, una sola vez
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Game/State/StageVisit.swift` | **nuevo** — `StageVisit`, `VisitorPopup`, `EventPopup`, `StageChallenge`, `StageRuntime` | 1 |
| `FisuEvolution/Game/State/GameState+Stage.swift` | **nuevo** — la máquina del escenario | 1, 2, 4 |
| `FisuEvolution/Game/State/GameState.swift` | las cuatro proyecciones del escenario (T1); se van `activeEvent`/`announcedEventID` (T4) y `specialInfo` (T9) | 1, 4, 9 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` | `.visitorEncounter` (T1); se va `.eventBanner` (T4) | 1, 4 |
| `FisuEvolution/Managers/AssetsManifest.swift`, `FisuEvolution/Managers/VisitorArt.swift` | la sección `npcs` y el arte con respaldo | 1 |
| `FisuEvolution/Managers/LoopsManifest.swift` | **nuevo** — `loops_manifest.json` leído (los loops de retrato) | 3 |
| `FisuEvolution/UI/Art/BubbleGeometry.swift` | **nuevo** — el globo vectorial, para SpriteKit y SwiftUI | 1 |
| `FisuEvolution/Scenes/Stage/StageLayout.swift`, `VisitorNode.swift`, `SpeechBubbleNode.swift`, `StageController.swift` | **nuevos** — el escenario | 1 |
| `FisuEvolution/Scenes/BoardScene.swift` | ganchos del escenario (T1), de los efectos (T6); se van los especiales (T9) | 1, 6, 9 |
| `FisuEvolution/Game/State/GameState+Visitors.swift` | **nuevo** — los visitantes en la partida | 2, 3, 5 |
| `FisuEvolution/UI/Visitors/StageChips.swift`, `VisitorFace.swift`, `VisitorPopupView.swift`, `LoopingPortraitView.swift` | **nuevos** — chips, cara, popup, retrato | 3, 5 |
| `FisuEvolution/UI/Visitors/VendorCardsView.swift` | **nuevo** — las tres cartas del Vendedor | 5 |
| `FisuEvolution/UI/Art/RewardedOfferButton.swift` | **nuevo** — el botón de video reusable (cimientos de PLAN-v2) | 3 |
| `FisuEvolution/UI/Art/GameArtComponents.swift` | `ActionPill(verbatim:)` (T3); `StrikePrice` y `PricePill.strikeText` (T7) | 3, 7 |
| `FisuEvolution/Game/State/GameState+Events.swift`, `+Engagement.swift`, `+Actions.swift`, `+Debug.swift`, `FisuEvolution/UI/DebugPanelView.swift` | los ganchos de E4a y de la partida: guion llamado, presentador, toques del reto y de las velitas, puertas de debug | 1, 2, 4, 6 |
| `FisuEvolution/Game/State/GameState+Tower.swift`, `+BoardChanges.swift` | se van `visibleFloorSpecials`/`presentSpecialInfo` y el término `specialInfo` | 9 |
| `FisuEvolution/App/RootView.swift` | chips, popups, `uiCoversBoard` (T3, T4); se va el banner (T4) y la carta del special (T9) | 3, 4, 9 |
| `FisuEvolution/UI/Events/EventPopupView.swift` | **nuevo** — la frase y las salidas de un evento | 4 |
| `FisuEvolution/Game/State/ActiveBonus.swift`, `FisuEvolution/UI/HUD/ActiveBonusBar.swift` | chips de evento con cara, tocables | 4 |
| `FisuEvolution/Scenes/Stage/StageEffects.swift` | **nuevo** — velo y velitas del Apagón, baile y confeti de Campeones | 6 |
| `FisuEvolution/Game/Effects/ParticlePool.swift`, `FisuEvolution/Audio/AudioManager.swift` | `.confetti`, `.blackout` | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift`, `FisuEvolution/Game/State/GameState+Hiring.swift`, `FisuEvolution/UI/Jobs/FisuJobsView.swift`, `FisuEvolution/UI/HUD/QuickHireButton.swift` | el piso de descuentos y el precio tachado | 7 |
| `FisuEvolution/UI/Menu/SpecialsAlbumView.swift`, `FisuEvolution/Game/State/GameState+Specials.swift`, `FisuEvolution/UI/Menu/MenuView.swift`, `FisuEvolution/Managers/EffectDescriptor.swift`, `FisuEvolution/UI/Popups/SpecialDropView.swift` | el Álbum | 8 |
| `FisuEvolution/Game/State/GameState+TutorialTips.swift`, `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` | las tres lecciones | 3, 4, 8 |

## Orden, olas y paralelismo

| T | Qué | 🔥 calientes | Tibios / compartidos | Depende de |
|---|---|---|---|---|
| 1 | el escenario y su turno | `GameState.swift` (5 líneas), `BoardScene.swift` (5 ganchos) | `CelebrationQueue` (EK), `+Celebrations`, `CelebrationWiringTests`, `+Debug`, `DebugPanelView` | E4a cerrada; **E3a T10** y **E1 T10** (últimas en `BoardScene`) |
| 2 | los visitantes en la partida | — | `+Stage`, `+Engagement`, `+Events`, `+Actions` (1 línea), `+Debug`, `DebugPanelView`, `LocalizationCompletenessTests`, catálogo (snapshot) | T1 |
| 3 | chips, popup, retrato y la lección | `RootView.swift` | `GameArtComponents` (`ActionPill`), `+TutorialTips`, `TutorialAnchor`, catálogo | T2; **E3a T11, E3b T4/T8/T9** (dueños previos de `RootView`) |
| 4 | eventos con presentador; chip y popup; adiós banner | `GameState.swift`, `RootView.swift`, catálogo | `CelebrationQueue`, `+Celebrations`, `+Events`, `ActiveBonus*`, las suites del banner | T3 |
| 5 | los retos y el Vendedor en pantalla | — | `StageChips`, `VisitorPopupView`, `+Visitors`, catálogo (snapshot) | T3 (∥ T4 si el controlador aplica el snapshot) |
| 6 | Apagón y Campeones | `BoardScene.swift` (3 ganchos) | `StageEffects` (nuevo), `ParticlePool`, `AudioManager`, `AudioWiringTests`, `+Events`, `+Actions` (1 línea) | T4 |
| 7 | Liquidación: precio tachado | — | `ActiveModifier` (EK), `+Hiring`, `FisuJobsView`, `QuickHireButton`, `GameArtComponents` (`PricePill`, `StrikePrice`), catálogo (snapshot) | E4a T9; **E3b T5–T7** (dueñas de `QuickHireOffer` y `QuickHireButton`) |
| 8 | el Álbum de especiales | — | `MenuView`, `SpecialDropView`, `EffectDescriptor`, `TutorialUITests`, `+TutorialTips`, catálogo | E4a; **E3b T3** (dueña de `MenuView`) |
| 9 | los especiales salen del tablero | `BoardScene.swift`, `GameState.swift`, `RootView.swift` | `+Tower`, `+BoardChanges` (E1 T9), `+Actions`, `+Debug`, `DebugPanelView`, `SpecialDropView`, `PlayerState` (docstring), `CrowdDepthTests`, `GameLoopWiringTests`, `TutorialUITests`, catálogo (`.quitar`) | T8, T6 (última en `BoardScene`) |
| 10 | cierre | — | `Docs/` (controlador) | todas |

```
Ola 1 (caliente: GameState + BoardScene)   T1 el escenario
Ola 2 (fría)                               T2 visitantes ║ T7 Liquidación ║ T8 Álbum
Ola 3 (caliente: RootView)                 T3 chips y popup
Ola 4                                      T4 eventos con presentador (GameState + RootView) ║ T5 retos y Vendedor (snapshot)
Ola 5 (caliente: BoardScene)               T6 Apagón y Campeones
Ola 6 (caliente: BoardScene + GameState + RootView)   T9 los especiales se van
Ola 7                                      T10 cierre
```

**E4 ∥ E5 por tarea**: E4b toca `GameState.swift` en T1, T4 y T9, `BoardScene.swift` en T1, T6 y
T9, y `RootView.swift` en T3, T4 y T9. Ninguna de esas va en la misma ola que una tarea de E5 que
toque el mismo archivo. Lo demás corre al lado de E5.

## Helpers de test que EXISTEN

Los de E4a, más:

| Necesidad | Qué usar | Dónde |
|---|---|---|
| un evento arrancado ya | `debugStartEvent(id:)` | E4a T9 |
| el escenario sin vista | `StageController(gameState:)` + `attach(to: SKNode())` + `update(delta:reduceMotion:)` | T1 |
| un visitante presentado ya | `debugPresentVisitor(scriptId:)` / `--uitest-visitor=<guion>` | T2 |
| esperas de UI | `waitForExistence`, `waitForNonExistence(timeout:)`; abrir el menú: copiar `openMenu` de `MenuUITests.swift:277-301` (privado) | XCTest / `MenuUITests` |
| Reduce Motion en un test | `BoardScene.reduceMotionOverride` (DEBUG; ponerlo y sacarlo sin `await` en el medio) | `BoardScene.swift:253` |

---

### Task 1: El escenario y su turno

**Objetivo:** la máquina de estados de una sola entrada (`stageVisit`: entrando → esperando →
yéndose), su turno corto en la cola (`.visitorEncounter`: la entrada no pisa un reveal ni un
cofre, y un toque la saltea), y el escenario en la escena: el visitante entra desde un borde a 90
pt/s con bamboleo, se para en el centro de [28 %, 72 %], respira, muestra su globo vectorial y se
va por el otro borde. Con Reduce Motion, fundidos. El arte cae a su respaldo. Todavía nadie
manda visitantes: los manda T2.

**Files:**
- Create: `FisuEvolution/Game/State/StageVisit.swift`
- Create: `FisuEvolution/Game/State/GameState+Stage.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (🔥: cuatro proyecciones y un estado ignorado)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`advanceStage`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (`.visitorEncounter`)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`syncCelebrations`, `releasePayload`)
- Modify: `FisuEvolutionTests/CelebrationWiringTests.swift` (`assertPayloadExists`)
- Modify: `FisuEvolution/Managers/AssetsManifest.swift` (`npcs`)
- Create: `FisuEvolution/Managers/VisitorArt.swift`
- Create: `FisuEvolution/UI/Art/BubbleGeometry.swift`
- Create: `FisuEvolution/Scenes/Stage/StageLayout.swift`, `VisitorNode.swift`, `SpeechBubbleNode.swift`, `StageController.swift`
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (🔥: cinco ganchos)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugResetSave`, `debugPresentStageDemo`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (`debug.stage.demo`)
- Create: `FisuEvolutionTests/StageLayoutTests.swift`, `FisuEvolutionTests/StageControllerTests.swift`, `FisuEvolutionTests/VisitorArtTests.swift`

**Interfaces:**
- Consumes: `isCalmMoment`, `advanceEngagement` (E4a T8, T9); `VisitOffer`, `ChallengeTerms`,
  `EventCatalog.Event` (E4a); `BoardScene.cameraOverlay`, `bottomInset`, `cellSize`,
  `prefersReducedMotion`; `AtlasCache.texture(named:inAtlas:)`, `UIArt.characterImage(atlas:key:)`.
- Produces: `struct StageVisit` (`id`, `actorId`, `role: Role` = `.visitor(scriptId:)` |
  `.presenter(eventId:)`, `phase: Phase` = `entering | waiting | leaving`, `bubble: String?`,
  `offer: VisitOffer?`), `VisitorPopup` (`id`), `EventPopup` (`eventId`, `id`), `StageChallenge`
  (`scriptId`, `terms`, `taps`, `endsAt`), `StageRuntime` (`patienceLeft`, `pendingEvent`,
  `calledScript`).
- Produces: `GameState.stageVisit`, `visitorPopup`, `eventPopup`, `stageChallenge` (observados),
  `stageRuntime` (ignorado; `patienceLeft`, `pendingEvent`, `calledScript`, `eventPresenters`);
  `presentOnStage(actorId:role:)`, `canPresentOnStage`,
  `stageActorArrived(id:)`, `stageActorLeft(id:)`, `stageActorTapped(id:)`,
  `sendStageActorAway()`, `settleStageArrival()`, `advanceStage(delta:now:)`.
- Produces: `CelebrationKind.visitorEncounter` (prioridad 5, tope 10 s).
- Produces: `AssetsManifest.npcs: [String: String]?`; `VisitorArt.Pose`,
  `asset(for:pose:manifest:)`, `texture(for:pose:manifest:)`, `image(for:pose:manifest:)`,
  `hasOwnFace(_:manifest:)`, `placeholderImage(symbol:tint:side:)`, `placeholderTexture(symbol:tint:side:)`.
- Produces: `BubbleGeometry.path(in:tailX:yUp:)`, `BubbleGeometry.tailHeight`, `struct BubbleShape: Shape`.
- Produces: `StageLayout` (`standX`, `stageRange`, `offstageX(left:)`, `baselineY`, `actorSide`,
  `bubbleMaxWidth`, `bubbleLeft(width:tipX:)`, `walkSeconds(fromLeft:)`), `StageController`
  (`layer`, `actor`, `bubble`, `attach(to:)`, `layout(sceneSize:bottomInset:cellSize:)`,
  `update(delta:reduceMotion:)`, `handleTap(at:) -> Bool`).

- [ ] **Step 1: Los tests, en rojo**

`CelebrationQueueTests.swift`, dos tests más:

```swift
    @Test("la entrada de un visitante es un turno corto y salteable, a la altura de los avisos")
    func visitorEncounterIsAShortSkippableTurn() {
        #expect(CelebrationKind.visitorEncounter.priority == 5)
        #expect(CelebrationKind.visitorEncounter.timeout == 10)
        #expect(CelebrationKind.visitorEncounter.isSkippable)
    }

    @Test("un reveal pasa antes que la entrada de un visitante")
    func boardCelebrationGoesBeforeAVisitor() {
        var queue = CelebrationQueue()
        queue.enqueue(.towerNotice)
        queue.enqueue(.visitorEncounter)
        queue.enqueue(.boardCelebration)
        queue.finish(.towerNotice)
        #expect(queue.current == .boardCelebration)
    }
```

`FisuEvolutionTests/StageLayoutTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import FisuEvolution

@Suite("El escenario: la geometría")
struct StageLayoutTests {
    /// iPhone SE, 16 Pro, Pro Max y el iPad 13" (con la celda topeada de PlayLayout).
    static let screens: [(CGSize, CGFloat)] = [
        (CGSize(width: 375, height: 667), 68),
        (CGSize(width: 393, height: 852), 72),
        (CGSize(width: 440, height: 956), 81),
        (CGSize(width: 1032, height: 1376), 112),
    ]

    @Test("se para adentro de [28 %, 72 %] y entra desde afuera de la pantalla")
    func standsInsideTheStage() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(layout.stageRange.contains(layout.standX))
            #expect(layout.offstageX(left: true) + layout.actorSide / 2 <= 0)
            #expect(layout.offstageX(left: false) - layout.actorSide / 2 >= size.width)
        }
    }

    @Test("la caminata entra en el turno, aun en la pantalla más ancha")
    func walkFitsTheTurn() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(layout.walkSeconds(fromLeft: true) < 10 - 1, "\(size): el watchdog cortaría la entrada")
        }
    }

    @Test("el globo nunca se sale de la pantalla")
    func bubbleStaysOnScreen() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            for tipX in [0, layout.standX, size.width] {
                let left = layout.bubbleLeft(width: layout.bubbleMaxWidth, tipX: tipX)
                #expect(left >= StageLayout.bubbleMargin)
                #expect(left + layout.bubbleMaxWidth <= size.width - StageLayout.bubbleMargin + 0.5)
            }
        }
    }

    @Test("el globo vectorial ocupa su rect, con la cola abajo y adentro")
    func bubbleGeometry() {
        let rect = CGRect(x: 10, y: 20, width: 200, height: 80)
        let down = BubbleGeometry.path(in: rect, tailX: 110, yUp: false)
        #expect(down.boundingBoxOfPath.insetBy(dx: -0.5, dy: -0.5).contains(rect))
        #expect(down.contains(CGPoint(x: 110, y: rect.maxY - 2)), "la punta de la cola, abajo")
        #expect(!down.contains(CGPoint(x: rect.minX + 2, y: rect.maxY - 2)), "al costado de la cola no hay globo")
        let up = BubbleGeometry.path(in: rect, tailX: 110, yUp: true)
        #expect(up.contains(CGPoint(x: 110, y: rect.minY + 2)), "en SpriteKit la cola cuelga hacia y chico")
        let clamped = BubbleGeometry.path(in: rect, tailX: -500, yUp: false)
        #expect(clamped.boundingBoxOfPath.minX >= rect.minX - 0.5, "una cola fuera del globo se acomoda adentro")
    }
}
```

`FisuEvolutionTests/StageControllerTests.swift`:

```swift
import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("El escenario: entrar, esperar y salir")
@MainActor
struct StageControllerTests {
    private func stage() async -> (GameState, StageController) {
        let gameState = await makeGameState()
        let controller = StageController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    private func run(_ controller: StageController, seconds: Double, reduceMotion: Bool = false, until done: () -> Bool) {
        var elapsed = 0.0
        while elapsed < seconds, !done() {
            controller.update(delta: 1.0 / 60, reduceMotion: reduceMotion)
            elapsed += 1.0 / 60
        }
    }

    @Test("entra caminando en su turno, llega al centro, espera y se va por el otro lado")
    func walksInWaitsAndLeaves() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        #expect(gameState.showing == .visitorEncounter)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let entering = try #require(controller.actor)
        #expect(entering.position.x < 0 || entering.position.x > 393, "arranca afuera de la pantalla")
        run(controller, seconds: 8) { gameState.stageVisit?.phase == .waiting }
        #expect(gameState.stageVisit?.phase == .waiting)
        #expect(gameState.showing != .visitorEncounter, "llegar libera el turno")
        let actor = try #require(controller.actor)
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(layout.stageRange.contains(actor.position.x))
        gameState.sendStageActorAway()
        run(controller, seconds: 8) { gameState.stageVisit == nil }
        #expect(gameState.stageVisit == nil)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor == nil)
    }

    @Test("mientras espera su turno no se ve")
    func invisibleUntilItsTurn() async throws {
        let (gameState, controller) = await stage()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        #expect(gameState.showing == .towerNotice)
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.actor == nil)
    }

    @Test("con Reduce Motion aparece con un fundido en el centro, sin caminar")
    func reduceMotionFades() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        let actor = try #require(controller.actor)
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(actor.position.x == layout.standX)
        #expect(actor.alpha < 1)
        run(controller, seconds: 1, reduceMotion: true) { gameState.stageVisit?.phase == .waiting }
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("el globo aparece con lo que dice y se va con él")
    func bubble() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.stageVisit?.bubble = "¡Hola, vecino!"
        controller.update(delta: 0.5, reduceMotion: false)
        #expect(controller.bubble?.text == "¡Hola, vecino!")
        gameState.stageVisit?.bubble = nil
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        #expect(controller.bubble == nil)
    }

    @Test("saltear la entrada lo deja llegado, una sola vez")
    func skippingTheEntrance() async throws {
        let (gameState, _) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        gameState.advanceCelebrations(delta: CelebrationQueue.skipFloor)
        #expect(gameState.skipCurrentCelebration())
        #expect(gameState.stageVisit?.phase == .waiting)
        gameState.settleStageArrival()
        #expect(gameState.stageVisit?.phase == .waiting)
    }

    @Test("tocarlo mientras espera le avisa a la partida; antes, no")
    func tapping() async throws {
        let (gameState, controller) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        controller.update(delta: 1.0 / 60, reduceMotion: false)
        let entering = try #require(controller.actor)
        #expect(!controller.handleTap(at: entering.position))
        run(controller, seconds: 8) { gameState.stageVisit?.phase == .waiting }
        let actor = try #require(controller.actor)
        #expect(controller.handleTap(at: CGPoint(x: actor.position.x, y: actor.position.y + 10)))
        #expect(!controller.handleTap(at: CGPoint(x: 5, y: 5)))
    }

    @Test("la paciencia corre sólo en un momento calmo, y al agotarse se va")
    func patience() async throws {
        let (gameState, _) = await stage()
        gameState.presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
        // Llegar por la escena cierra el turno: con `.visitorEncounter` en pantalla
        // no es un momento calmo y la paciencia no correría.
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.uiCoversBoard = true
        gameState.advanceStage(delta: 60)
        #expect(gameState.stageVisit?.phase == .waiting, "con una hoja abierta no se impacienta")
        gameState.uiCoversBoard = false
        gameState.advanceStage(delta: 29)
        #expect(gameState.stageVisit?.phase == .waiting)
        gameState.advanceStage(delta: 2)
        #expect(gameState.stageVisit?.phase == .leaving)
    }
}
```

`FisuEvolutionTests/VisitorArtTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El arte de los visitantes, con respaldo")
@MainActor
struct VisitorArtTests {
    private func manifest(npcs: [String: String]?) throws -> AssetsManifest {
        var manifest = try GameContentLoader.load(from: .main).manifest
        manifest.npcs = npcs
        return manifest
    }

    @Test("un visitante nuevo sin arte no tiene asset; un especial cae a su canónica de la v1")
    func fallbacks() throws {
        let manifest = try manifest(npcs: nil)
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .talk, manifest: manifest) == nil)
        let special = try #require(VisitorArt.asset(for: "sp_cryptobro", pose: .face, manifest: manifest))
        #expect(special.atlas == manifest.characters["sp_cryptobro"]?.atlas)
        #expect(special.key == manifest.characters["sp_cryptobro"]?.key)
        #expect(!VisitorArt.hasOwnFace("sp_cryptobro", manifest: manifest), "la cara se recorta de la canónica")
    }

    @Test("una pose integrada gana; si falta, la canónica de npcs")
    func integratedPosesWin() throws {
        let manifest = try manifest(npcs: ["npc_comisario": "npc_comisario", "npc_comisario_talk": "npc_comisario_talk"])
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .talk, manifest: manifest)?.key == "npc_comisario_talk")
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .talk, manifest: manifest)?.atlas == "npcs")
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .action, manifest: manifest)?.key == "npc_comisario")
    }

    @Test("el manifest de hoy decodifica sin la sección npcs")
    func manifestWithoutNpcsDecodes() throws {
        let json = #"{"schemaVersion": 1, "characters": {}, "backgrounds": {}, "ui": {}}"#
        let manifest = try JSONDecoder().decode(AssetsManifest.self, from: Data(json.utf8))
        #expect(manifest.npcs == nil)
    }

    @Test("el respaldo se dibuja sin vista y del tamaño pedido")
    func placeholderRenders() {
        let image = VisitorArt.placeholderImage(symbol: "figure.stand", tint: "PaletteBlue", side: 64)
        #expect(image.size == CGSize(width: 64, height: 64))
    }
}
```

`CelebrationWiringTests.swift`, en el `switch` de `assertPayloadExists`:

```swift
        case .visitorEncounter: #expect(gameState.stageVisit != nil)
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests` (no compila:
`.visitorEncounter`) y `/opt/homebrew/bin/xcodegen generate` + Receta R con
`-only-testing:FisuEvolutionTests/StageLayoutTests -only-testing:FisuEvolutionTests/StageControllerTests -only-testing:FisuEvolutionTests/VisitorArtTests`
→ no compila.

- [ ] **Step 3: El turno en la cola**

`CelebrationQueue.swift`: el caso nuevo (con su docstring) después de `chestOpening`:

```swift
    /// La entrada de alguien a escena (un visitante o el presentador de un
    /// evento): camina desde el borde y se para. Es corta y salteable, y nunca
    /// pisa un reveal ni un cofre. Lo que pasa después —esperar a que lo toquen—
    /// ya no ocupa la cola.
    case visitorEncounter
```

en `priority`, `case .eventBanner, .visitorEncounter: 5`; en `timeout`,
`case .visitorEncounter: 10` (cubre la caminata en la pantalla más ancha, el iPad 13", con margen:
lo pinea `StageLayoutTests.walkFitsTheTurn`).

`GameState+Celebrations.swift`: en `syncCelebrations()`, junto a los otros:

```swift
        if stageVisit?.phase == .entering { celebrations.enqueue(.visitorEncounter) }
```

y en `releasePayload(for:)`:

```swift
        case .visitorEncounter:
            // Las tres salidas —la escena que avisa que llegó, el toque que saltea y
            // el watchdog— pasan por acá: llega igual, una sola vez.
            settleStageArrival()
```

- [ ] **Step 4: El estado y la máquina**

`FisuEvolution/Game/State/StageVisit.swift`:

```swift
import EconomyKit
import Foundation

/// Quién está en escena (PLAN-v2 E4): un visitante con su oferta o el
/// presentador de un evento. Lo escribe `+Stage`; lo dibuja `StageController`.
struct StageVisit: Identifiable, Equatable {
    enum Role: Equatable {
        case visitor(scriptId: String)
        case presenter(eventId: String)
    }

    enum Phase: Equatable {
        case entering, waiting, leaving
    }

    let id: UUID
    /// El id de arte (`npc_<nombre>` / `sp_<id>`), el de `visitors.json`.
    let actorId: String
    let role: Role
    var phase: Phase
    /// Lo que dice el globo. Se resuelve al llegar.
    var bubble: String?
    /// La oferta del visitante, cotizada al llegar (`VisitPlanner`). `nil` después
    /// de elegir: el chip desaparece.
    var offer: VisitOffer?
}

/// El popup de quien está en escena: lo abrió el jugador (chip o toque).
struct VisitorPopup: Identifiable, Equatable {
    let id: UUID
}

/// El popup del chip de un evento corriendo (T4).
struct EventPopup: Identifiable, Equatable {
    let eventId: String
    var id: String { eventId }
}

/// Un reto de toques en curso (la Vecina, el Zombie, el Coach).
struct StageChallenge: Equatable {
    let scriptId: String
    let terms: ChallengeTerms
    var taps: Int
    let endsAt: TimeInterval
}

/// Lo del escenario que no se dibuja: relojes y pendientes.
struct StageRuntime {
    /// Lo que le queda de paciencia (o de charla, a un presentador).
    var patienceLeft: TimeInterval = 0
    /// El evento que espera a su presentador (T4).
    var pendingEvent: EventCatalog.Event?
    /// El guion que llamó un evento (el Cepo al Arbolito, T2).
    var calledScript: String?
    /// Quién anunció cada evento corriendo: su cara va en el chip (T4). En
    /// memoria: después de relanzar, el chip cae al primer presentador del dato.
    var eventPresenters: [String: String] = [:]
}
```

`GameState.swift` (🔥), en las proyecciones observadas, después de `tutorialTip`:

```swift
    /// Quién está en escena. Lo escribe `+Stage`; la escena lo lee por frame.
    var stageVisit: StageVisit?
    /// El popup de quien está en escena (`+Visitors`).
    var visitorPopup: VisitorPopup?
    /// El popup de un chip de evento (`+Events`, T4).
    var eventPopup: EventPopup?
    /// El reto de toques en curso (`+Visitors`).
    var stageChallenge: StageChallenge?
```

y en "Authoritative state":

```swift
    /// Los relojes y pendientes del escenario (`+Stage`). No dibujan nada.
    @ObservationIgnored var stageRuntime = StageRuntime()
```

`FisuEvolution/Game/State/GameState+Stage.swift`:

```swift
import EconomyKit
import Foundation

/// El escenario (PLAN-v2 E4): quien entra, habla y se va. Esta extensión es la
/// máquina de estados; `StageController` la dibuja y avisa cuando el que entraba
/// llegó o el que se iba salió.
extension GameState {
    /// El escenario está libre y es un momento calmo: puede entrar alguien.
    var canPresentOnStage: Bool { stageVisit == nil && isCalmMoment }

    /// Pone a alguien en escena. Entra cuando la cola le da el turno
    /// (`.visitorEncounter`); hasta entonces no se ve.
    func presentOnStage(actorId: String, role: StageVisit.Role) {
        stageVisit = StageVisit(id: UUID(), actorId: actorId, role: role, phase: .entering, bubble: nil, offer: nil)
        stageRuntime.patienceLeft = 0
        syncCelebrations()
    }

    /// La escena terminó la entrada.
    func stageActorArrived(id: UUID) {
        guard stageVisit?.id == id, stageVisit?.phase == .entering else { return }
        completeArrival()
        celebrationFinished(.visitorEncounter)
    }

    /// El turno de entrada se cerró sin que la escena avisara (el toque que
    /// saltea, el watchdog): llega igual, una sola vez. Lo llama `releasePayload`.
    func settleStageArrival() {
        guard stageVisit?.phase == .entering else { return }
        completeArrival()
    }

    func stageActorLeft(id: UUID) {
        guard stageVisit?.id == id, stageVisit?.phase == .leaving else { return }
        stageVisit = nil
        visitorPopup = nil
        stageRuntime.patienceLeft = 0
    }

    /// El jugador tocó al que está en escena.
    func stageActorTapped(id: UUID) {
        guard stageVisit?.id == id, stageVisit?.phase == .waiting else { return }
        openStagePopup()
    }

    /// Que se vaya: se agotó la paciencia, se resolvió su popup o terminó de hablar.
    func sendStageActorAway() {
        guard var visit = stageVisit, visit.phase != .leaving else { return }
        let wasEntering = visit.phase == .entering
        visit.phase = .leaving
        visit.bubble = nil
        visit.offer = nil
        stageVisit = visit
        visitorPopup = nil
        if wasEntering { celebrationFinished(.visitorEncounter) }
    }

    /// La paciencia corre con el delta del tick y sólo en un momento calmo, con
    /// su popup cerrado y sin un reto en curso.
    func advanceStage(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard stageVisit?.phase == .waiting, isCalmMoment,
              visitorPopup == nil, eventPopup == nil, stageChallenge == nil
        else { return }
        stageRuntime.patienceLeft -= delta
        if stageRuntime.patienceLeft <= 0 { sendStageActorAway() }
    }

    private func completeArrival() {
        guard var visit = stageVisit, visit.phase == .entering else { return }
        visit.phase = .waiting
        stageRuntime.patienceLeft = content?.visitors.patienceSeconds ?? 30
        arrive(&visit)
        stageVisit = visit
    }

    /// Lo que pasa cuando alguien llega: la oferta del visitante se cotiza acá (T2)
    /// y el evento del presentador se aplica acá (T4).
    private func arrive(_ visit: inout StageVisit) {
        switch visit.role {
        case .visitor:
            break
        case .presenter:
            break
        }
    }

    private func openStagePopup() {
        // T2: el popup del visitante.
    }
}
```

`GameState+Engagement.swift`, `advanceEngagement(delta:)` suma al final:

```swift
        advanceStage(delta: delta)
```

`GameState+Debug.swift`: en `debugResetSave`, con los otros payloads:

```swift
        stageVisit = nil
        visitorPopup = nil
        eventPopup = nil
        stageChallenge = nil
        stageRuntime = StageRuntime()
```

y en `#if DEBUG`:

```swift
    /// Alguien en escena ya mismo, sin guion: para mirar la entrada, el globo y la
    /// salida en el simulador.
    func debugPresentStageDemo() {
        presentOnStage(actorId: "npc_vecina", role: .visitor(scriptId: "vecina_chisme"))
    }
```

`DebugPanelView.swift`, junto a "Disparar un evento":

```swift
                    Button("Escenario: que entre alguien") {
                        gameState.debugPresentStageDemo()
                    }
                    .accessibilityIdentifier("debug.stage.demo")
```

- [ ] **Step 5: El arte con respaldo**

`AssetsManifest.swift`, después de `ui`:

```swift
    /// Las poses de los visitantes (`npcs.atlas`): la canónica de los 8 nuevos y
    /// `_talk`/`_action`/`_face`. La sección la crea `process_dropbox.py` con el
    /// primer visitante integrado; hasta entonces no está y todo cae a su respaldo.
    var npcs: [String: String]? = nil
```

`FisuEvolution/Managers/VisitorArt.swift`:

```swift
import SpriteKit
import SwiftUI
import UIKit

/// El arte de un visitante, con respaldo (PLAN-v2 §5, `Docs/biblia-visitantes.md`):
/// las poses nuevas viven en `npcs.atlas` y la canónica de los 10 especiales es
/// la de la v1 (`characters`). Sin entrada, el juego no espera al batch: un disco
/// con el símbolo y el color del visitante (`visitors.json`).
@MainActor
enum VisitorArt {
    enum Pose: String {
        case canonical = ""
        case talk = "_talk"
        case action = "_action"
        case face = "_face"
    }

    /// (atlas, clave) de una pose; si la pose no está, la canónica. `nil` sin arte.
    static func asset(for visitorId: String, pose: Pose, manifest: AssetsManifest) -> (atlas: String, key: String)? {
        if let key = manifest.npcs?[visitorId + pose.rawValue] { return ("npcs", key) }
        if pose != .canonical { return asset(for: visitorId, pose: .canonical, manifest: manifest) }
        if let character = manifest.characters[visitorId] { return (character.atlas, character.key) }
        return nil
    }

    static func texture(for visitorId: String, pose: Pose, manifest: AssetsManifest) -> SKTexture? {
        guard let asset = asset(for: visitorId, pose: pose, manifest: manifest) else { return nil }
        return AtlasCache.texture(named: asset.key, inAtlas: asset.atlas)
    }

    static func image(for visitorId: String, pose: Pose, manifest: AssetsManifest) -> Image? {
        guard let asset = asset(for: visitorId, pose: pose, manifest: manifest) else { return nil }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }

    /// Hay una cara dibujada; si no, la vista recorta la cabeza de la canónica.
    static func hasOwnFace(_ visitorId: String, manifest: AssetsManifest) -> Bool {
        manifest.npcs?[visitorId + Pose.face.rawValue] != nil
    }

    static func placeholderTexture(symbol: String, tint: String, side: CGFloat = 128) -> SKTexture {
        SKTexture(image: placeholderImage(symbol: symbol, tint: tint, side: side))
    }

    /// El respaldo: un disco del color del visitante, con borde de tinta y su
    /// símbolo en blanco.
    static func placeholderImage(symbol: String, tint: String, side: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            let disc = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: 3, dy: 3)
            (UIColor(named: tint) ?? .systemBlue).setFill()
            context.cgContext.fillEllipse(in: disc)
            (UIColor(named: "PaletteInk") ?? .darkGray).setStroke()
            context.cgContext.setLineWidth(3)
            context.cgContext.strokeEllipse(in: disc)
            let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.42, weight: .heavy)
            guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            else { return }
            glyph.draw(in: CGRect(
                x: (side - glyph.size.width) / 2, y: (side - glyph.size.height) / 2,
                width: glyph.size.width, height: glyph.size.height
            ))
        }
    }
}
```

- [ ] **Step 6: El globo vectorial**

`FisuEvolution/UI/Art/BubbleGeometry.swift`:

```swift
import CoreGraphics
import SwiftUI

/// El globo de diálogo de la 2.0, uno solo para SpriteKit y SwiftUI (PLAN-v2 E4):
/// un rectángulo redondeado con la cola abajo, en un único contorno (sin costura
/// entre cuerpo y cola cuando se traza el borde).
enum BubbleGeometry {
    static let cornerRadius: CGFloat = 14
    static let tailWidth: CGFloat = 18
    static let tailHeight: CGFloat = 12

    /// `tailX` en las coordenadas de `rect`; se acomoda para no comerse una esquina.
    /// `yUp`: SpriteKit (y crece hacia arriba: la cola cuelga hacia y chico).
    static func path(in rect: CGRect, tailX: CGFloat, yUp: Bool) -> CGPath {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(0, rect.height - tailHeight))
        let radius = min(cornerRadius, body.height / 2, body.width / 2)
        let half = tailWidth / 2
        let tip = min(max(tailX, body.minX + radius + half), body.maxX - radius - half)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + radius), radius: radius)
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - radius, y: body.maxY), radius: radius)
        path.addLine(to: CGPoint(x: tip + half, y: body.maxY))
        path.addLine(to: CGPoint(x: tip, y: rect.maxY))
        path.addLine(to: CGPoint(x: tip - half, y: body.maxY))
        path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - radius), radius: radius)
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + radius, y: body.minY), radius: radius)
        path.closeSubpath()
        guard yUp else { return path }
        var flip = CGAffineTransform(translationX: 0, y: rect.minY + rect.maxY).scaledBy(x: 1, y: -1)
        return path.copy(using: &flip) ?? path
    }
}

/// El mismo globo, para SwiftUI (la frase del popup de un visitante o de un evento).
struct BubbleShape: Shape {
    /// Dónde va la cola, como fracción del ancho.
    var tailFraction: CGFloat = 0.5

    func path(in rect: CGRect) -> Path {
        Path(BubbleGeometry.path(in: rect, tailX: rect.minX + rect.width * tailFraction, yUp: false))
    }
}
```

- [ ] **Step 7: El escenario**

`FisuEvolution/Scenes/Stage/StageLayout.swift`:

```swift
import CoreGraphics

/// La geometría del escenario (PLAN-v2 E4): x ∈ [28 %, 72 %] del ancho, para no
/// quedar bajo los botones flotantes de los costados, y parado delante de la
/// multitud, arriba de la franja de abajo. Coordenadas de la capa de la cámara
/// (origen abajo a la izquierda, del tamaño de la escena).
struct StageLayout: Equatable {
    static let leftEdge: CGFloat = 0.28
    static let rightEdge: CGFloat = 0.72
    /// Lo que camina un visitante, en pt/s.
    static let walkSpeed: CGFloat = 90
    /// Un visitante es algo más alto que un empleado: viene de afuera.
    static let actorScale: CGFloat = 1.35
    static let bubbleMargin: CGFloat = 12

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat

    var actorSide: CGFloat { cellSize * Self.actorScale }
    var baselineY: CGFloat { bottomInset + cellSize * 0.25 }
    var stageRange: ClosedRange<CGFloat> { sceneSize.width * Self.leftEdge...sceneSize.width * Self.rightEdge }
    var standX: CGFloat { (stageRange.lowerBound + stageRange.upperBound) / 2 }
    var bubbleMaxWidth: CGFloat { min(sceneSize.width - Self.bubbleMargin * 2, (stageRange.upperBound - stageRange.lowerBound) + 80) }

    func offstageX(left: Bool) -> CGFloat {
        left ? -actorSide / 2 : sceneSize.width + actorSide / 2
    }

    func walkSeconds(fromLeft: Bool) -> Double {
        Double(abs(standX - offstageX(left: fromLeft)) / Self.walkSpeed)
    }

    /// El borde izquierdo del globo centrado sobre la cabeza, adentro de la pantalla.
    func bubbleLeft(width: CGFloat, tipX: CGFloat) -> CGFloat {
        min(max(tipX - width / 2, Self.bubbleMargin), sceneSize.width - Self.bubbleMargin - width)
    }
}
```

`FisuEvolution/Scenes/Stage/VisitorNode.swift`:

```swift
import SpriteKit

/// Quien está en escena. Lo mueve `StageController` por frame.
final class VisitorNode: SKSpriteNode {
    let visitId: UUID
    let actorId: String
    private var clock: TimeInterval = 0

    init(visitId: UUID, actorId: String, texture: SKTexture, side: CGFloat) {
        self.visitId = visitId
        self.actorId = actorId
        super.init(texture: texture, color: .clear, size: CGSize(width: side, height: side))
        anchorPoint = CGPoint(x: 0.5, y: 0)
        name = "stage.actor"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("VisitorNode is never decoded")
    }

    func resize(side: CGFloat) {
        size = CGSize(width: side, height: side)
    }

    /// El bamboleo al caminar: unos puntos arriba y abajo, tres pasos por segundo.
    func walkBob(delta: TimeInterval) -> CGFloat {
        clock += delta
        return CGFloat(abs(sin(clock * .pi * 3))) * 4
    }

    /// El pulso de espera: respira.
    func breathe(delta: TimeInterval) {
        clock += delta
        setScale(1 + 0.03 * CGFloat(sin(clock * .pi * 1.6)))
    }
}
```

`FisuEvolution/Scenes/Stage/SpeechBubbleNode.swift`:

```swift
import SpriteKit

/// El globo de la escena: el dibujo de `BubbleGeometry` con el texto envuelto
/// adentro. La punta de la cola está en el origen del nodo: posicionarlo es
/// posicionar la cola, y escalarlo hace el "pop" desde la boca del que habla.
final class SpeechBubbleNode: SKNode {
    static let padding: CGFloat = 12
    private let shape = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private(set) var text = ""
    private(set) var size: CGSize = .zero
    private var tailX: CGFloat = -1

    override init() {
        super.init()
        name = "stage.bubble"
        shape.fillColor = Palette.cream
        shape.strokeColor = Palette.ink
        shape.lineWidth = 2
        label.fontColor = Palette.ink
        label.fontSize = 15
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(shape)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("SpeechBubbleNode is never decoded")
    }

    /// Mide el texto y se queda con su tamaño (cola incluida).
    func setText(_ text: String, maxWidth: CGFloat) {
        self.text = text
        label.text = text
        label.preferredMaxLayoutWidth = maxWidth - Self.padding * 2
        let measured = label.frame.size
        size = CGSize(width: min(maxWidth, measured.width + Self.padding * 2),
                      height: measured.height + Self.padding * 2 + BubbleGeometry.tailHeight)
        tailX = -1
    }

    /// Redibuja con la cola a `tailX` del borde izquierdo del globo.
    func pointTail(at tailX: CGFloat) {
        guard tailX != self.tailX else { return }
        self.tailX = tailX
        let rect = CGRect(x: -tailX, y: 0, width: size.width, height: size.height)
        shape.path = BubbleGeometry.path(in: rect, tailX: 0, yUp: true)
        label.position = CGPoint(x: rect.midX, y: BubbleGeometry.tailHeight + (size.height - BubbleGeometry.tailHeight) / 2)
    }
}
```

`FisuEvolution/Scenes/Stage/StageController.swift`:

```swift
import SpriteKit

/// El escenario de la escena (PLAN-v2 E4): quien entra desde un borde, habla y se
/// va por el otro. Cuelga de la capa de la cámara para que navegar pisos no lo
/// deje atrás. Todo se mueve por frame y no con `SKAction`: lo que hace se prueba
/// con un `SKNode` pelado y deltas inyectados (`StageControllerTests`).
@MainActor
final class StageController {
    /// Delante de toda la multitud (el campo llega a ~110 con sus etiquetas) y
    /// detrás del reveal (su velo arranca en 195): un ascenso tapa al visitante,
    /// nunca al revés.
    static let layerZ: CGFloat = 190
    static let fadeDuration: TimeInterval = 0.3
    static let bubblePopDuration: TimeInterval = 0.18

    let layer = SKNode()
    private weak var gameState: GameState?
    private(set) var actor: VisitorNode?
    private(set) var bubble: SpeechBubbleNode?
    private var layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    private var entersFromLeft = false
    private var bubbleAge: TimeInterval = 0
    private var textures: [String: SKTexture] = [:]

    init(gameState: GameState) {
        self.gameState = gameState
        layer.zPosition = Self.layerZ
        layer.name = "stage"
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat) {
        layout = StageLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize)
        actor?.resize(side: layout.actorSide)
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let gameState, let visit = gameState.stageVisit,
              visit.phase != .entering || gameState.showing == .visitorEncounter
        else { return clear() }
        let node = actorNode(for: visit, reduceMotion: reduceMotion)
        switch visit.phase {
        case .entering: enter(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        case .waiting: wait(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        case .leaving: leave(node, visit: visit, delta: delta, reduceMotion: reduceMotion)
        }
    }

    /// Tocar al que espera (o su globo) abre su popup. `point` en coordenadas de `layer`.
    /// Durante un reto de toques no se come nada: los toques son para los empleados.
    /// Y tiene que estar parado en su lugar: el toque que saltea la entrada deja
    /// la fase en `waiting` en el acto, pero el nodo sigue a mitad de camino hasta
    /// el próximo frame, y ese mismo toque no puede abrir además el popup.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, let actor, let visit = gameState.stageVisit,
              visit.id == actor.visitId, visit.phase == .waiting, gameState.stageChallenge == nil,
              actor.alpha >= 1, abs(actor.position.x - layout.standX) < 1,
              actor.contains(point) || (bubble?.contains(point) ?? false)
        else { return false }
        gameState.stageActorTapped(id: visit.id)
        return true
    }

    private func actorNode(for visit: StageVisit, reduceMotion: Bool) -> VisitorNode {
        if let actor, actor.visitId == visit.id { return actor }
        clear()
        entersFromLeft.toggle()
        let node = VisitorNode(visitId: visit.id, actorId: visit.actorId,
                               texture: texture(for: visit.actorId, pose: .canonical), side: layout.actorSide)
        let walksIn = visit.phase == .entering && !reduceMotion
        node.position = CGPoint(x: walksIn ? layout.offstageX(left: entersFromLeft) : layout.standX, y: layout.baselineY)
        node.alpha = visit.phase == .entering && reduceMotion ? 0 : 1
        layer.addChild(node)
        actor = node
        return node
    }

    private func enter(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        hideBubble()
        if reduceMotion {
            node.position = CGPoint(x: layout.standX, y: layout.baselineY)
            node.alpha = min(1, node.alpha + CGFloat(delta / Self.fadeDuration))
            if node.alpha >= 1 { gameState?.stageActorArrived(id: visit.id) }
            return
        }
        let target = layout.standX
        let step = StageLayout.walkSpeed * CGFloat(delta)
        let x = node.position.x < target ? min(target, node.position.x + step) : max(target, node.position.x - step)
        let arrived = x == target
        node.position = CGPoint(x: x, y: layout.baselineY + (arrived ? 0 : node.walkBob(delta: delta)))
        if arrived { gameState?.stageActorArrived(id: visit.id) }
    }

    private func wait(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        node.alpha = 1
        node.position = CGPoint(x: layout.standX, y: layout.baselineY)
        if reduceMotion { node.setScale(1) } else { node.breathe(delta: delta) }
        let talking = visit.bubble.map { !$0.isEmpty } ?? false
        let pose = texture(for: visit.actorId, pose: talking ? .talk : .canonical)
        if node.texture !== pose { node.texture = pose }
        guard talking, let text = visit.bubble else { return hideBubble() }
        let bubble = self.bubble ?? makeBubble()
        if bubble.text != text {
            bubble.setText(text, maxWidth: layout.bubbleMaxWidth)
            bubbleAge = 0
        }
        let tip = CGPoint(x: node.position.x, y: layout.baselineY + layout.actorSide + 4)
        bubble.pointTail(at: tip.x - layout.bubbleLeft(width: bubble.size.width, tipX: tip.x))
        bubble.position = tip
        bubbleAge += delta
        let progress = reduceMotion ? 1 : min(1, bubbleAge / Self.bubblePopDuration)
        bubble.setScale(CGFloat(0.6 + 0.4 * progress))
        bubble.alpha = CGFloat(progress)
    }

    private func leave(_ node: VisitorNode, visit: StageVisit, delta: TimeInterval, reduceMotion: Bool) {
        hideBubble()
        node.setScale(1)
        if reduceMotion {
            node.alpha = max(0, node.alpha - CGFloat(delta / Self.fadeDuration))
            if node.alpha <= 0 { gameState?.stageActorLeft(id: visit.id) }
            return
        }
        let exit = layout.offstageX(left: !entersFromLeft)
        let step = StageLayout.walkSpeed * CGFloat(delta)
        let x = node.position.x < exit ? min(exit, node.position.x + step) : max(exit, node.position.x - step)
        node.position = CGPoint(x: x, y: layout.baselineY + node.walkBob(delta: delta))
        if x == exit { gameState?.stageActorLeft(id: visit.id) }
    }

    private func makeBubble() -> SpeechBubbleNode {
        let node = SpeechBubbleNode()
        node.zPosition = 1
        layer.addChild(node)
        bubble = node
        return node
    }

    private func hideBubble() {
        bubble?.removeFromParent()
        bubble = nil
    }

    private func clear() {
        hideBubble()
        actor?.removeFromParent()
        actor = nil
    }

    /// Se pide por frame (la pose cambia con el globo): va cacheada, porque el
    /// respaldo se DIBUJA y dibujarlo 60 veces por segundo se nota.
    private func texture(for actorId: String, pose: VisitorArt.Pose) -> SKTexture {
        let key = actorId + pose.rawValue
        if let cached = textures[key] { return cached }
        let texture: SKTexture
        if let manifest = gameState?.content?.manifest,
           let art = VisitorArt.texture(for: actorId, pose: pose, manifest: manifest) {
            texture = art
        } else {
            let visitor = gameState?.content?.visitors.visitor(id: actorId)
            texture = VisitorArt.placeholderTexture(symbol: visitor?.fallbackSymbol ?? "person.fill",
                                                    tint: visitor?.fallbackTint ?? "PaletteBlue")
        }
        textures[key] = texture
        return texture
    }
}
```

- [ ] **Step 8: Los cinco ganchos de `BoardScene` (🔥)**

1. Entre las propiedades de la escena:

```swift
    /// Los visitantes y presentadores (PLAN-v2 E4). Vive en su colaborador: la
    /// escena sólo lo adjunta, lo ubica, lo actualiza y le pasa los toques.
    private lazy var stage = StageController(gameState: gameState)
```

2. En `init(gameState:)`, después de `addChild(cameraNode)`: `stage.attach(to: cameraOverlay)`.
3. Al final de `layoutBoard()`, después de `renderLockedFloorOverlay()`:
   `stage.layout(sceneSize: size, bottomInset: Self.bottomInset, cellSize: cellSize)`.
4. En `update(_:)`, después de `startBoardCelebrationIfItsTurn()`:
   `stage.update(delta: delta, reduceMotion: Self.prefersReducedMotion)`.
5. En `touchesBegan`, después del bloque del skip (y del `guard playingBoardChange == nil` de
   E1 T10), antes de buscar el personaje bajo el dedo:

```swift
        // El que está en escena se toca antes que la multitud: está adelante.
        if stage.handleTap(at: touch.location(in: stage.layer)) { return }
```

- [ ] **Step 9: Verde, a mano y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests` → PASS;
`/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/StageLayoutTests -only-testing:FisuEvolutionTests/StageControllerTests -only-testing:FisuEvolutionTests/VisitorArtTests -only-testing:FisuEvolutionTests/CelebrationWiringTests`
→ PASS. A mano en el simulador propio (SE, 16 Pro y iPad Pro 13", Reduce Motion apagado y
prendido): panel de debug → "Escenario: que entre alguien" → la Vecina (disco rosa con el ojo)
entra caminando, se para entre los botones de los costados, respira 30 s y se va por el otro
lado; un toque durante la entrada la deja parada en el acto. Captura de cada uno al reporte.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 10: Commit**

```bash
git add FisuEvolution/Game/State/StageVisit.swift FisuEvolution/Game/State/GameState+Stage.swift \
  FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+Engagement.swift \
  Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift \
  FisuEvolution/Game/State/GameState+Celebrations.swift FisuEvolutionTests/CelebrationWiringTests.swift \
  FisuEvolution/Managers/AssetsManifest.swift FisuEvolution/Managers/VisitorArt.swift \
  FisuEvolution/UI/Art/BubbleGeometry.swift FisuEvolution/Scenes/Stage/StageLayout.swift \
  FisuEvolution/Scenes/Stage/VisitorNode.swift FisuEvolution/Scenes/Stage/SpeechBubbleNode.swift \
  FisuEvolution/Scenes/Stage/StageController.swift FisuEvolution/Scenes/BoardScene.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolution/UI/DebugPanelView.swift \
  FisuEvolutionTests/StageLayoutTests.swift FisuEvolutionTests/StageControllerTests.swift FisuEvolutionTests/VisitorArtTests.swift
git diff --cached --stat
git commit -m "feat(escena): el escenario — entrar desde el borde, hablar en un globo vectorial e irse"
```

---

### Task 2: Los visitantes en la partida

**Objetivo:** que los visitantes vengan solos y hagan lo suyo, todavía sin popup propio: el carril
principal y el del Vendedor corren con el juego activo (`advanceEngagement`), el guion se elige
con `VisitorScheduler` contra lo que se puede ofrecer AHORA, la oferta se cotiza al llegar
(`VisitPlanner`: así el globo y el popup dicen lo mismo), elegir una opción la revalida, cobra o
paga, entrega por `grant` y manda las salidas al embudo de E1; el reto de toques cuenta los
toques a los empleados; la Vecina adelanta el próximo evento; el Cepo llama al Arbolito. Todo
probado sin vista (el popup lo pone T3). Un visitante que llega y ya no tiene trato dice "me
equivoqué de oficina" y se va.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Visitors.swift`
- Modify: `FisuEvolution/Game/State/GameState+Stage.swift` (`arrive`, `openStagePopup`, el vencimiento del reto en `advanceStage`)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`advanceVisitors`; el fixture `--uitest-visitor=`)
- Modify: `FisuEvolution/Game/State/GameState+Events.swift` (`startEvent` anota el guion llamado)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`registerTap` → `noteStageTap()`, una línea)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugPresentVisitor(scriptId:)`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (`debug.visitor.call`)
- Modify: `FisuEvolution/Managers/VisitCopy.swift` (`lineKeys`)
- Modify: `FisuEvolutionTests/LocalizationCompletenessTests.swift` (la familia `.visitors` suma `VisitCopy.lineKeys`)
- Create: `FisuEvolutionTests/VisitorRuntimeTests.swift`
- Create: `Tools/v2/claves-pendientes/e4b-t2.json`

**Interfaces:**
- Consumes: T1 entero; `VisitorScheduler.rollDay/advance/pickNext/isAvailable/markVisited/retrySoon`,
  `VisitPlanner.offer/revalidate`, `VisitContext`, `VisitValuation`, `ChallengeTerms`, `VisitOption`
  (E4a T5, T6); `VisitCopy.bubble/text` (E4a T7); `grant`, `creditCoins`, `coinsPerProductionSecond`,
  `grantableRewardKinds` (E4a T8); `peekUpcomingEvent`, `startEvent`, `engagementAutorun`,
  `fixtureValue` (E4a T9); `enqueueBoardChange`, `settleAllPendingBoardChanges` (**E1 T9**);
  `ModifierMath.spendingFrozenUntil(_:now:)` (**E1 T13**); `DailyRewardManager.dayString(for:)`.
- Produces: `GameState.shortStaySeconds` (4), `visitContext`, `visitValuation`, `visitOffer(for:)`,
  `advanceVisitors(delta:today:)`, `presentNextVisitor(lane:)`, `presentVisitor(_:)`,
  `presentCalledScript()`, `arriveVisitor(_:scriptId:)`, `openVisitorPopup()`, `closeVisitorPopup()`,
  `canAfford(_:now:)`, `chooseVisitOption(_:now:) -> Bool`, `beginChallenge(scriptId:terms:now:)`,
  `noteStageTap(now:)`, `finishChallenge(won:now:)`, `finishVisit(saying:_:)`, `revealGossip()`,
  `static rewardSource(for:scriptId:)`, `debugPresentVisitor(scriptId:)`, `debugClearStage()`; el
  fixture `--uitest-visitor=<guion>`; `VisitCopy.lineKeys`.
- Las fuentes de los premios (`rewardSource(for:scriptId:)`): `visit.<guion>`; el "×2 con video",
  `visit.<guion>.x2`; cada carta del Vendedor, `visit.<guion>.card.<id>`. T4 les pone cara y
  duración en la barra de bonus.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/VisitorRuntimeTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los visitantes en la partida", .serialized)
@MainActor
struct VisitorRuntimeTests {
    /// Frontera en 6 (abre el arresto, el Arbolito y la compra del Turista), plata
    /// y dos pares del tier de la frontera: hay duplicados para llevarse.
    private func world(frontier: Int = 6) async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: frontier)
        gameState.debugGrantCoins()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        gameState.engagementAutorun = true
        return gameState
    }

    /// Lo pone en escena y lo hace llegar como lo haría la escena.
    private func arrive(_ gameState: GameState, _ scriptId: String) throws {
        let script = try #require(gameState.content?.visitors.script(id: scriptId))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
    }

    private func coins(_ gameState: GameState) -> Double { gameState.player?.run.coins ?? 0 }

    @Test("el carril listo pone a alguien en escena y anota la visita")
    func aReadyLaneBringsSomeone() async throws {
        let gameState = await world()
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.player?.meta.engagement.visitors.secondsUntilVendor = 999
        gameState.advanceVisitors(delta: 2)
        let visit = try #require(gameState.stageVisit)
        guard case .visitor(let scriptId) = visit.role else { Issue.record("no es un visitante"); return }
        #expect(gameState.player?.meta.engagement.visitors.recentScripts.last == scriptId)
        #expect(gameState.player?.meta.engagement.visitors.visitsToday[scriptId] == 1)
        #expect((gameState.player?.meta.engagement.visitors.secondsUntilVisit ?? 0) >= 240, "el próximo, a 4–6 min")
    }

    @Test("con el escenario ocupado el carril espera, sin perder su turno")
    func aBusyStageMakesTheLaneWait() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let first = gameState.stageVisit?.id
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.advanceVisitors(delta: 2)
        #expect(gameState.stageVisit?.id == first)
        #expect((gameState.player?.meta.engagement.visitors.secondsUntilVisit ?? 1) <= 0, "sigue listo para cuando se libere")
    }

    @Test("sin el motor prendido no viene nadie (los tests y los --uitest ajenos)")
    func autorunOffMeansNobody() async {
        let gameState = await world()
        gameState.engagementAutorun = false
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.advanceVisitors(delta: 2)
        #expect(gameState.stageVisit == nil)
    }

    @Test("la oferta se cotiza al llegar y el globo la nombra")
    func theOfferIsQuotedOnArrival() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let visit = try #require(gameState.stageVisit)
        let offer = try #require(visit.offer)
        #expect(offer.options.map(\.id) == ["accept", "video"])
        #expect(offer.options[0].coins > 0)
        #expect(offer.options[1].coins == offer.options[0].coins * 2)
        #expect(visit.bubble?.isEmpty == false)
    }

    @Test("aceptar cobra lo cotizado, agradece y se va al rato")
    func acceptingPaysAndLeaves() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let option = try #require(gameState.stageVisit?.offer?.option(id: "accept"))
        let before = coins(gameState)
        #expect(gameState.chooseVisitOption("accept"))
        #expect(abs(coins(gameState) - (before + option.coins)) < 0.01)
        #expect(gameState.stageVisit?.offer == nil, "sin oferta, el chip se va")
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.thanks"))
        gameState.advanceStage(delta: GameState.shortStaySeconds + 0.1)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("un modificador de visita lleva la fuente del guion; con video, la del ×2")
    func modifiersCarryTheScript() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_cryptobro")
        try arrive(gameState, "cryptobro_senal")
        #expect(gameState.chooseVisitOption("video"))
        let modifier = try #require(gameState.player?.run.activeModifiers.last)
        #expect(modifier.sourceKey == "visit.cryptobro_senal.x2")
        #expect(modifier.effect == .incomeMultiplier)
    }

    @Test("dejar ir al arrestado paga más de lo que cuesta reponerlo y se lo lleva a la vista")
    func releasingTheArrestedPaysAndDeparts() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let offer = try #require(gameState.stageVisit?.offer)
        let release = try #require(offer.option(id: "release"))
        let typeId = try #require(offer.subjectTypeId)
        let unitsBefore = gameState.player?.run.units[typeId] ?? 0
        let before = coins(gameState)
        #expect(gameState.chooseVisitOption("release"))
        #expect(coins(gameState) > before)
        #expect(gameState.pendingBoardChanges.count == release.departures.count, "la salida va por el embudo, a la vista")
        #expect(gameState.player?.run.units[typeId] == unitsBefore, "todavía no se fue: se va en su turno")
        gameState.settleAllPendingBoardChanges()
        #expect(gameState.player?.run.units[typeId] == unitsBefore - 1)
    }

    @Test("pagar la fianza cobra la fianza y no se lleva a nadie")
    func payingBail() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let bail = try #require(gameState.stageVisit?.offer?.option(id: "bail"))
        let before = coins(gameState)
        #expect(gameState.chooseVisitOption("bail"))
        #expect(abs(coins(gameState) - (before - bail.cost)) < 0.01)
        #expect(gameState.pendingBoardChanges.isEmpty)
    }

    @Test("sin plata, o con corralito, no se paga; la oferta sigue en pie")
    func cantPayWithoutCoinsOrFrozen() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let bail = try #require(gameState.stageVisit?.offer?.option(id: "bail"))
        gameState.player?.run.coins = 0
        #expect(!gameState.canAfford(bail))
        #expect(!gameState.chooseVisitOption("bail"))
        #expect(gameState.stageVisit?.offer != nil)
        gameState.debugGrantCoins()
        gameState.debugStartCorralito()
        #expect(!gameState.canAfford(bail), "el corralito congela también los pagos a visitantes")
        #expect(gameState.canAfford(try #require(gameState.stageVisit?.offer?.option(id: "release"))), "cobrar, sí")
    }

    @Test("si el tablero cambió y ya no hay a quién llevarse, no hay trato")
    func aStaleDealIsOff() async throws {
        let gameState = await world()
        try arrive(gameState, "comisario_arresto")
        let typeId = try #require(gameState.stageVisit?.offer?.subjectTypeId)
        gameState.player?.run.units[typeId] = 1
        let before = coins(gameState)
        #expect(!gameState.chooseVisitOption("release"))
        #expect(coins(gameState) == before)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.deal_off"))
        #expect(gameState.stageVisit?.offer == nil)
    }

    @Test("el que llega sin trato posible se equivoca de oficina y se va enseguida")
    func wrongOffice() async throws {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        try arrive(gameState, "comisario_arresto")
        #expect(gameState.stageVisit?.offer == nil)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.wrong_office"))
        gameState.advanceStage(delta: GameState.shortStaySeconds + 0.1)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("la Vecina adelanta el próximo evento, y queda anotado para salir")
    func gossipRevealsTheNextEvent() async throws {
        let gameState = await world()
        try arrive(gameState, "vecina_chisme")
        #expect(gameState.chooseVisitOption("listen"))
        let upcoming = try #require(gameState.player?.meta.engagement.events.upcomingId)
        let event = try #require(gameState.content?.events.event(id: upcoming))
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.gossip.next", [VisitCopy.text(event.titleKey)]))
    }

    @Test("el reto cuenta los toques a los empleados y paga al llegar")
    func theChallengeCountsTaps() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        try arrive(gameState, "coach_reto")
        #expect(gameState.chooseVisitOption("challenge"))
        let challenge = try #require(gameState.stageChallenge)
        #expect(gameState.visitorPopup == nil, "el reto se juega en el tablero")
        let now = Date().timeIntervalSince1970
        for _ in 0..<challenge.terms.taps { gameState.noteStageTap(now: now) }
        #expect(gameState.stageChallenge == nil)
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "visit.coach_reto" } == true)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.challenge.won"))
    }

    @Test("el reto vencido no paga nada")
    func anExpiredChallengePaysNothing() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        try arrive(gameState, "coach_reto")
        #expect(gameState.chooseVisitOption("challenge"))
        let endsAt = try #require(gameState.stageChallenge?.endsAt)
        gameState.noteStageTap(now: endsAt - 1)
        gameState.advanceStage(delta: 0.1, now: endsAt + 0.1)
        #expect(gameState.stageChallenge == nil)
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "visit.coach_reto" } != true)
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.challenge.lost"))
    }

    @Test("un reto ganado con video doble ofrece el ×2 de lo que acaba de dar")
    func aWonChallengeOffersTheDouble() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let terms = ChallengeTerms(taps: 1, windowSeconds: 10, coins: 100, rewards: [], videoDoubles: true)
        gameState.beginChallenge(scriptId: "vecina_favor", terms: terms, now: 0)
        let before = coins(gameState)
        gameState.noteStageTap(now: 1)
        #expect(coins(gameState) == before + 100)
        let double = try #require(gameState.stageVisit?.offer?.option(id: "video"))
        #expect(double.requiresVideo)
        #expect(gameState.chooseVisitOption("video"))
        #expect(coins(gameState) == before + 200)
    }

    @Test("el Cepo llama al Arbolito del blue, aunque el sorteo no lo traería nunca")
    func theCepoCallsTheArbolito() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_arbolito")
        gameState.debugStartEvent(id: "cepo")
        #expect(gameState.stageRuntime.calledScript == "arbolito_blue")
        gameState.advanceVisitors(delta: 0)
        #expect(gameState.stageVisit?.role == .visitor(scriptId: "arbolito_blue"))
        #expect(gameState.stageRuntime.calledScript == nil)
    }

    @Test("cambiar ORO con el Arbolito cuenta para el tope del día; el blue, no")
    func exchangesCountTowardsTheDailyCap() async throws {
        let gameState = await world()
        gameState.player?.meta.ownedSpecials.append("sp_arbolito")
        gameState.player?.run.coins = 1e30
        try arrive(gameState, "arbolito_cambio")
        let oro = gameState.player?.meta.oro ?? 0
        #expect(gameState.chooseVisitOption("exchange"))
        #expect(gameState.player?.meta.oro == oro + 1)
        #expect(gameState.player?.meta.engagement.visitors.oroExchangedToday == 1)
        gameState.sendStageActorAway()
        gameState.stageActorLeft(id: try #require(gameState.stageVisit?.id))
        try arrive(gameState, "arbolito_blue")
        #expect(gameState.chooseVisitOption("exchange"))
        #expect(gameState.player?.meta.engagement.visitors.oroExchangedToday == 1)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/VisitorRuntimeTests`.
Expected: no compila (`presentVisitor`, `chooseVisitOption`, `noteStageTap`…).

- [ ] **Step 3: `GameState+Visitors.swift`**

```swift
import EconomyKit
import Foundation

/// Los visitantes enganchados a la partida (PLAN-v2 E4). El motor es puro
/// (`VisitorScheduler`, `VisitPlanner`); acá se resuelve lo que necesita la
/// partida y se aplica. Quién entra y cómo camina es del escenario (`+Stage`).
extension GameState {
    /// Lo que se queda el que no tiene trato (o ya lo cerró) antes de irse.
    static let shortStaySeconds: TimeInterval = 4

    var visitContext: VisitContext? {
        guard let player else { return nil }
        return VisitContext(maxTier: player.run.maxTierReached,
                            ownedSpecials: Set(player.meta.ownedSpecials),
                            grantable: Self.grantableRewardKinds)
    }

    /// La misma valuación que FisuJobs: el segundo de producción y el descuento
    /// de prestigio (reponer a alguien cuesta lo que cuesta contratarlo).
    var visitValuation: VisitValuation {
        let discount = content?.prestigeUnlocks.cumulativeSpawnDiscount(
            atPrestigeLevel: player?.meta.prestigeLevel ?? 0
        ) ?? 0
        return VisitValuation(coinsPerSecond: coinsPerProductionSecond, hireCostMultiplier: 1 - discount)
    }

    func visitOffer(for script: VisitorsConfig.Script) -> VisitOffer? {
        guard let content, let economy, let player, let tower else { return nil }
        return VisitPlanner.offer(script, config: content.visitors, state: player, tower: tower,
                                  tiers: content.tiers, floorTable: content.floorTable,
                                  economy: economy, valuation: visitValuation)
    }

    /// Lo llama `advanceEngagement` con el delta del tick (juego activo, con tope).
    /// El guion que llamó un evento entra primero; un evento esperando a su
    /// presentador, antes que cualquier visitante (T4).
    func advanceVisitors(delta: TimeInterval, today: String = DailyRewardManager.dayString(for: Date())) {
        if stageRuntime.calledScript != nil, canPresentOnStage {
            presentCalledScript()
            return
        }
        guard engagementAutorun, !tutorialPhaseActive, let content, var player else { return }
        VisitorScheduler.rollDay(&player.meta.engagement.visitors, today: today)
        let lane = VisitorScheduler.advance(&player.meta.engagement.visitors, delta: delta,
                                            config: content.visitors, rng: &rng)
        self.player = player
        guard let lane, canPresentOnStage, stageRuntime.pendingEvent == nil else { return }
        presentNextVisitor(lane: lane)
    }

    func presentNextVisitor(lane: VisitorsConfig.Lane) {
        guard let content, var player, let context = visitContext else { return }
        // Lo ofrecible se resuelve ANTES: el sorteo no puede leer `self` mientras
        // `rng` está prestado como `inout` (la misma regla que `fireDueEvent`).
        let offerable = Set(content.visitors.scripts.filter { visitOffer(for: $0) != nil }.map(\.id))
        guard let script = VisitorScheduler.pickNext(
            lane: lane, config: content.visitors, state: player.meta.engagement.visitors,
            context: context, isOfferable: { offerable.contains($0.id) }, rng: &rng
        ) else {
            VisitorScheduler.retrySoon(lane: lane, state: &player.meta.engagement.visitors, config: content.visitors)
            self.player = player
            return
        }
        presentVisitor(script)
    }

    /// Pone en escena un guion ya elegido: el sorteo, el llamado de un evento o
    /// la puerta de debug. Cuenta como visita (repetidos, tope del día, próximo).
    func presentVisitor(_ script: VisitorsConfig.Script) {
        guard let content, var player else { return }
        VisitorScheduler.markVisited(script, state: &player.meta.engagement.visitors,
                                     config: content.visitors, rng: &rng)
        self.player = player
        scheduleSave()
        presentOnStage(actorId: script.visitor, role: .visitor(scriptId: script.id))
        Log.economy.info("visitor presented: \(script.id)")
    }

    /// El guion que llamó un evento (el blue del Arbolito, en el Cepo). Si ya no
    /// puede venir (no tenés al especial, se pasó del tope), el llamado se pierde:
    /// el evento igual pasó.
    func presentCalledScript() {
        guard let id = stageRuntime.calledScript else { return }
        stageRuntime.calledScript = nil
        guard let content, let player, let context = visitContext,
              let script = content.visitors.script(id: id),
              VisitorScheduler.isAvailable(script, config: content.visitors, state: player.meta.engagement.visitors,
                                           context: context, isOfferable: { visitOffer(for: $0) != nil })
        else { return }
        presentVisitor(script)
    }

    /// Llegó: se cotiza la oferta y el globo la cuenta. Sin trato posible (el
    /// tablero cambió mientras caminaba), una disculpa y se va.
    func arriveVisitor(_ visit: inout StageVisit, scriptId: String) {
        guard let content, let script = content.visitors.script(id: scriptId),
              let offer = visitOffer(for: script)
        else {
            visit.bubble = VisitCopy.text("visit.wrong_office")
            stageRuntime.patienceLeft = Self.shortStaySeconds
            return
        }
        visit.offer = offer
        visit.bubble = VisitCopy.bubble(for: script, offer: offer, content: content)
    }

    func openVisitorPopup() {
        guard let visit = stageVisit, visit.phase == .waiting, visit.offer != nil, stageChallenge == nil else { return }
        visitorPopup = VisitorPopup(id: visit.id)
    }

    /// Cerrar sin elegir no lo echa: sigue esperando con su paciencia.
    func closeVisitorPopup() {
        visitorPopup = nil
    }

    /// Lo que se paga se puede pagar: alcanza la plata y no hay corralito.
    func canAfford(_ option: VisitOption, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard option.cost > 0 else { return true }
        guard let player, ModifierMath.spendingFrozenUntil(player.run.activeModifiers, now: now) == nil else { return false }
        return player.run.coins >= option.cost
    }

    /// El jugador eligió (y, si pedía video, ya lo miró: lo llama la vista al
    /// terminar). Se revalida contra el tablero y la caja de AHORA. Devuelve si
    /// hubo trato.
    @discardableResult
    func chooseVisitOption(_ optionId: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard let visit = stageVisit, visit.phase == .waiting, let offer = visit.offer,
              let option = offer.option(id: optionId)
        else { return false }
        guard canAfford(option, now: now) else { return false }
        guard let player, let tower, let checked = VisitPlanner.revalidate(option, state: player, tower: tower) else {
            finishVisit(saying: "visit.deal_off")
            return false
        }
        let source = Self.rewardSource(for: checked, scriptId: offer.scriptId)
        switch checked.kind {
        case .startChallenge:
            guard let terms = checked.challenge else { return false }
            beginChallenge(scriptId: offer.scriptId, terms: terms, now: now)
            return true
        case .listen:
            creditCoins(checked.coins)
            grant(checked.rewards, source: source, now: now)
            revealGossip()
            return true
        case .accept, .acceptWithVideo, .payBail, .release, .payFine, .forgiveWithVideo, .sell, .exchange, .card:
            creditCoins(checked.coins)
            grant(checked.rewards, source: source, now: now)
            noteOroExchanged(checked, scriptId: offer.scriptId)
            // La plata ya está; la salida, a la vista y en su turno (E1). Si al
            // llegar su turno ya no es válida se descarta y la plata queda: el
            // trato se cerró con lo que había (duda 6 de E4a).
            for change in checked.departures { enqueueBoardChange(change) }
            finishVisit(saying: "visit.thanks")
            return true
        }
    }

    /// El origen de lo que da una opción: con él la barra de bonus le pone la
    /// cara y la duración (T4). Cada carta del Vendedor dura lo suyo; el "×2 con
    /// video" tiene su propia fuente porque dura el doble.
    static func rewardSource(for option: VisitOption, scriptId: String) -> String {
        switch option.kind {
        case .card: "visit.\(scriptId).\(option.id)"
        case .acceptWithVideo: "visit.\(scriptId).x2"
        case .accept, .payBail, .release, .payFine, .forgiveWithVideo, .sell, .exchange, .startChallenge, .listen:
            "visit.\(scriptId)"
        }
    }

    /// El reto arranca: el popup se cierra y los toques van al tablero.
    func beginChallenge(scriptId: String, terms: ChallengeTerms, now: TimeInterval) {
        visitorPopup = nil
        stageChallenge = StageChallenge(scriptId: scriptId, terms: terms, taps: 0, endsAt: now + terms.windowSeconds)
        stageVisit?.bubble = nil
    }

    /// Un toque a un empleado (`registerTap`). Sólo cuenta dentro de la ventana.
    func noteStageTap(now: TimeInterval = Date().timeIntervalSince1970) {
        guard var challenge = stageChallenge, now < challenge.endsAt else { return }
        challenge.taps += 1
        stageChallenge = challenge
        if challenge.taps >= challenge.terms.taps { finishChallenge(won: true, now: now) }
    }

    func finishChallenge(won: Bool, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let challenge = stageChallenge else { return }
        stageChallenge = nil
        guard won else { return finishVisit(saying: "visit.challenge.lost") }
        creditCoins(challenge.terms.coins)
        grant(challenge.terms.rewards, source: "visit.\(challenge.scriptId)", now: now)
        guard challenge.terms.videoDoubles, var visit = stageVisit else {
            return finishVisit(saying: "visit.challenge.won")
        }
        // El ×2 del reto es OTRA tanda igual, por video: lo ofrece el mismo
        // visitante, con su chip y su popup, y si no lo querés se va igual.
        let double = VisitOption(id: "video", kind: .acceptWithVideo, coins: challenge.terms.coins,
                                 rewards: challenge.terms.rewards, departures: [], requiresVideo: true, challenge: nil)
        visit.offer = VisitOffer(scriptId: challenge.scriptId, visitorId: visit.actorId, subjectTypeId: nil, options: [double])
        visit.bubble = VisitCopy.text("visit.challenge.double")
        stageVisit = visit
        stageRuntime.patienceLeft = content?.visitors.patienceSeconds ?? 30
    }

    /// Cierra el trato: sin oferta (el chip desaparece), una frase y se va al rato.
    func finishVisit(saying key: String, _ arguments: [String] = []) {
        guard var visit = stageVisit else { return }
        visitorPopup = nil
        visit.offer = nil
        visit.bubble = VisitCopy.text(key, arguments)
        stageVisit = visit
        stageRuntime.patienceLeft = Self.shortStaySeconds
    }

    /// La Vecina: el próximo evento, que queda anotado y es el que sale.
    func revealGossip() {
        guard let event = peekUpcomingEvent() else {
            return finishVisit(saying: "visit.gossip.none")
        }
        finishVisit(saying: "visit.gossip.next", [VisitCopy.text(event.titleKey)])
    }

    /// El tope diario de ORO es del cambio con tope (el Arbolito de siempre); el
    /// blue del Cepo no lo usa ni lo gasta.
    private func noteOroExchanged(_ option: VisitOption, scriptId: String) {
        guard option.kind == .exchange, var player,
              case .exchange(_, _, let cap?) = content?.visitors.script(id: scriptId)?.mechanic, cap > 0
        else { return }
        player.meta.engagement.visitors.oroExchangedToday += option.rewards.reduce(0) { total, reward in
            if case .oro(let amount) = reward { return total + amount }
            return total
        }
        self.player = player
    }
}
```

- [ ] **Step 4: El escenario llama a los visitantes**

`GameState+Stage.swift`, en `arrive(_:)`:

```swift
        case .visitor(let scriptId):
            arriveVisitor(&visit, scriptId: scriptId)
```

`openStagePopup()` pasa a:

```swift
    private func openStagePopup() {
        guard let visit = stageVisit else { return }
        switch visit.role {
        case .visitor:
            openVisitorPopup()
        case .presenter:
            break
        }
    }
```

y `advanceStage(delta:now:)` vence el reto ANTES de su `guard` (el reto corre con reloj de
pared: es corto y se juega mirando):

```swift
    func advanceStage(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        if let challenge = stageChallenge, now >= challenge.endsAt {
            finishChallenge(won: false, now: now)
        }
        guard stageVisit?.phase == .waiting, isCalmMoment,
              visitorPopup == nil, eventPopup == nil, stageChallenge == nil
        else { return }
        stageRuntime.patienceLeft -= delta
        if stageRuntime.patienceLeft <= 0 { sendStageActorAway() }
    }
```

`GameState+Engagement.swift`: `advanceEngagement(delta:)` queda

```swift
    func advanceEngagement(delta: TimeInterval) {
        advanceEvents(delta: delta)
        advanceVisitors(delta: delta)
        advanceStage(delta: delta)
    }
```

y en `applyEngagementFixtures(arguments:)`:

```swift
        if let scriptId = Self.fixtureValue("--uitest-visitor=", in: arguments) {
            debugPresentVisitor(scriptId: scriptId)
        }
```

`GameState+Events.swift`, en `startEvent(_:now:)`, después de sumar los modificadores:

```swift
        if let called = application.calledScript { stageRuntime.calledScript = called }
```

`GameState+Actions.swift`, en `registerTap(cellIndex:)`, después de `self.player = player`:

```swift
        noteStageTap()
```

`GameState+Debug.swift`, en `#if DEBUG`:

```swift
    /// Un visitante en escena ya mismo, con su guion real y salteando el sorteo
    /// (no el tope ni el tier: eso lo decide el que lo llama). Los visitantes
    /// vienen cada 4–6 min de juego: sin esta puerta no se pueden ni fotografiar
    /// ni probar.
    func debugPresentVisitor(scriptId: String) {
        guard let script = content?.visitors.script(id: scriptId) else { return }
        debugClearStage()
        presentVisitor(script)
    }

    /// Saca a quien esté en escena, sin despedida (es una puerta de debug, no una
    /// regla del juego). Si estaba entrando, su turno de la cola se cierra.
    func debugClearStage() {
        guard stageVisit != nil else { return }
        stageVisit = nil
        visitorPopup = nil
        stageChallenge = nil
        celebrationFinished(.visitorEncounter)
    }
```

`DebugPanelView.swift`, junto a "Disparar un evento":

```swift
                    Menu("Llamar a un visitante") {
                        ForEach(gameState.content?.visitors.scripts ?? []) { script in
                            Button(script.id) { gameState.debugPresentVisitor(scriptId: script.id) }
                        }
                    }
                    .accessibilityIdentifier("debug.visitor.call")
```

- [ ] **Step 5: Las frases nuevas**

`VisitCopy.swift`, arriba de `optionKey`:

```swift
    /// Lo que dice un visitante fuera de su guion: al cerrar el trato, al
    /// quedarse sin él y en los retos. `LocalizationCompletenessTests` las pide.
    static let lineKeys = [
        "visit.wrong_office", "visit.deal_off", "visit.thanks", "visit.gossip.next", "visit.gossip.none",
        "visit.challenge.won", "visit.challenge.double", "visit.challenge.lost",
    ]
```

`LocalizationCompletenessTests.swift`, en `case .visitors:` se suma `+ VisitCopy.lineKeys`.

`Tools/v2/claves-pendientes/e4b-t2.json`:

```json
{
  "visit.wrong_office": {"es": "Uy, me equivoqué de oficina. ¡Perdón, perdón!", "en": "Oops, wrong office. Sorry, sorry!"},
  "visit.deal_off": {"es": "Ya no hay trato: cambió todo. ¡Otra vez será!", "en": "Deal's off: everything changed. Next time!"},
  "visit.thanks": {"es": "¡Un placer hacer negocios con vos!", "en": "A pleasure doing business with you!"},
  "visit.gossip.next": {"es": "Dicen que se viene… %1$@. ¡Yo no te dije nada!", "en": "Word is… %1$@ is coming. You didn't hear it from me!"},
  "visit.gossip.none": {"es": "Hoy está todo tranquilo. Raro, ¿no?", "en": "All quiet today. Weird, huh?"},
  "visit.challenge.won": {"es": "¡Bien ahí! Lo prometido es deuda.", "en": "Nailed it! A promise is a promise."},
  "visit.challenge.double": {"es": "¡Ganaste! ¿Lo duplicamos con un video?", "en": "You won! Double it with a video?"},
  "visit.challenge.lost": {"es": "Casi… ¡la próxima sale!", "en": "So close… next time!"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4b-t2.json` → `8 claves nuevas`.

- [ ] **Step 6: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/VisitorRuntimeTests -only-testing:FisuEvolutionTests/StageControllerTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/EventsRuntimeTests`
→ PASS (17 tests nuevos). A mano: panel de debug → "Llamar a un visitante" → `turista_propina`:
entra, el globo dice la propina, se queda 30 s y se va (todavía sin chip: el popup es de T3).
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Visitors.swift FisuEvolution/Game/State/GameState+Stage.swift \
  FisuEvolution/Game/State/GameState+Engagement.swift FisuEvolution/Game/State/GameState+Events.swift \
  FisuEvolution/Game/State/GameState+Actions.swift FisuEvolution/Game/State/GameState+Debug.swift \
  FisuEvolution/UI/DebugPanelView.swift FisuEvolution/Managers/VisitCopy.swift \
  FisuEvolutionTests/LocalizationCompletenessTests.swift FisuEvolutionTests/VisitorRuntimeTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t2.json, según la ola
git diff --cached --stat
git commit -m "feat(visitantes): vienen solos, cotizan al llegar y cierran el trato por el embudo"
```

---

### Task 3: El chip, el popup y el retrato del visitante

**Objetivo:** que el jugador pueda hablar con quien está en escena. Un chip con su cara bajo el
HUD (`stage.chip.visitor`: el objetivo de toque determinista y accesible; el visitante en la
escena también se toca), un popup con su retrato —el loop si existe, la foto si no—, su pedido en
un globo y una opción por botón: lo que da es `ActionPill`, lo que cobra es `ActionPill` naranja
o, si no alcanza o hay corralito, un `StateBadge` apagado, y lo que pide video es el
`RewardedOfferButton` nuevo. Con el popup abierto el tablero queda tapado (`uiCoversBoard`). Y la
lección: la primera visita la enseña.

**Files:**
- Create: `FisuEvolution/UI/Visitors/VisitorFace.swift`, `StageChips.swift`, `VisitorPopupView.swift`, `LoopingPortraitView.swift`
- Create: `FisuEvolution/Managers/LoopsManifest.swift`
- Create: `FisuEvolution/UI/Art/RewardedOfferButton.swift`
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`ActionPill`: `init(verbatim:…)`)
- Modify: `FisuEvolution/Game/State/GameState+Visitors.swift` (`openVisitorPopup` cumple la lección)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (lección `.visitor`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`TutorialTarget.visitor`)
- Modify: `FisuEvolution/App/RootView.swift` (🔥: los chips, la hoja, `uiCoversBoard`)
- Create: `FisuEvolutionTests/LoopsManifestTests.swift`, `FisuEvolutionUITests/VisitorUITests.swift`
- Modify: `FisuEvolutionTests/TutorialTipsTests.swift` (la lección nueva)
- Create: `Tools/v2/claves-pendientes/e4b-t3.json`

**Interfaces:**
- Consumes: T1 (`StageVisit`, `VisitorArt`, `BubbleShape`), T2 (`openVisitorPopup`,
  `closeVisitorPopup`, `chooseVisitOption`, `canAfford`); `VisitCopy.name/ask/optionTitle`
  (E4a T7); `fisuSheet()` (**E3a T6**), `playColumn()` (**E3a T4**), `PanelTitleBanner(verbatim:)`
  (**E3b T2**); `AdsCoordinator.showRewarded(for: .visitor)`; `PanelCard`, `ArtCloseButton`,
  `StateBadge`, `ActionPill`.
- Produces: `VisitorFace(visitorId:side:)`; `StageChips` (con `VisitorChip`, y el lugar del
  `ChallengeChip` de T5); `VisitorPopupView`; `RewardedOfferButton(title:identifier:placement:onRewarded:)`;
  `ActionPill(verbatim:systemImage:tint:identifier:accessibilityLabel:action:)`;
  `LoopsManifest` (`load(from:)`, `main`, `portraitURL(for:in:)`); `LoopingPortraitView(url:fallback:)`;
  `GameState.TutorialLesson.visitor`, `TutorialTarget.visitor`.
- Identificadores: `stage.chip.visitor`, `visit.option.<id de opción>` (`accept`,
  `video`, `bail`, `release`, `pay`, `sell`, `exchange`, `challenge`, `listen`, `card.<id>`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/LoopsManifestTests.swift` (el lado Swift del contrato de E8 pipeline):

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("loops_manifest.json: el contrato de los retratos")
@MainActor
struct LoopsManifestTests {
    @Test("decodifica, y cada retrato es de un visitante y tiene su archivo")
    func portraitsBelongToVisitorsAndExist() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.schemaVersion == 1)
        let visitors = Set(try GameContentLoader.load(from: .main).visitors.visitors.map(\.id))
        for (id, entry) in manifest.portraits {
            #expect(visitors.contains(id), "\(id): un retrato sin visitante no lo pide nadie")
            #expect(entry.file == "loop_\(id).mov", "\(id): el prefijo evita que Xcode pise archivos al aplanar")
            #expect(manifest.portraitURL(for: id) != nil, "\(id): está en el manifest pero no en el bundle")
        }
    }

    @Test("sin entrada no hay loop: el popup cae a la foto")
    func noEntryNoLoop() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.portraitURL(for: "npc_que_no_existe") == nil)
    }
}
```

`FisuEvolutionTests/TutorialTipsTests.swift`, un test más:

```swift
    @Test("la primera visita enseña el chip, y abrir su popup la cumple")
    func theFirstVisitorTeachesTheChip() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 2)
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .visitor)
        #expect(gameState.showing == .tutorialTip)
        gameState.openVisitorPopup()
        #expect(gameState.visitorPopup != nil)
        #expect(gameState.showing != .tutorialTip)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.visitor.defaultsKey))
    }
```

`FisuEvolutionUITests/VisitorUITests.swift`:

```swift
import XCTest

/// Un visitante de punta a punta: entra, se toca su chip, se cierra el trato y
/// se va. La entrada sale de `--uitest-visitor=<guion>` (los visitantes vienen
/// cada 4–6 min de juego: sin la puerta el test mediría la paciencia).
final class VisitorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ script: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-visitor=\(script)"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testElVisitanteEntraSeLoTocaYCierraElTrato() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "el turista tiene que llegar y dejar su chip")
        attach(app, "visitante: en escena con su chip")
        chip.tap()
        let accept = app.buttons["visit.option.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6), "el popup ofrece aceptar")
        XCTAssertTrue(app.buttons["visit.option.video"].exists, "y el ×2 con video")
        attach(app, "visitante: el popup")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 6), "elegir cierra el popup")
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6), "y sin trato no queda chip")
    }

    @MainActor
    func testElVideoDelVisitanteCierraElTratoAlTerminar() throws {
        let app = launch("ministro_subsidio")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let video = app.buttons["visit.option.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 6))
        video.tap()
        // El anuncio del stub dura 2 s; el trato se cierra cuando termina.
        XCTAssertTrue(video.waitForNonExistence(timeout: 10))
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6))
    }

    @MainActor
    func testCerrarElPopupSinElegirLoDejaEsperando() throws {
        let app = launch("turista_propina")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 6))
        close.tap()
        XCTAssertTrue(app.buttons["visit.option.accept"].waitForNonExistence(timeout: 6))
        XCTAssertTrue(chip.exists, "cerrar no lo echa: sigue esperando")
    }
}
```

(`sheet.close` es el identifier de `ArtCloseButton`, `GameArt.swift:205`.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/LoopsManifestTests -only-testing:FisuEvolutionTests/TutorialTipsTests`
→ no compila (`LoopsManifest`, `.visitor`).

- [ ] **Step 3: Los componentes**

`GameArtComponents.swift`, `ActionPill` pasa a guardar el título ya hecho `Text` (los nombres de
visitantes y montos vienen del dato, no del catálogo), con los dos inits; el `body` usa `title`
donde decía `Text(titleKey)`, y la etiqueta hablada cae a `title`:

```swift
struct ActionPill: View {
    let title: Text
    let systemImage: String
    var tint: Color = Color("PaletteGreen")
    let identifier: String
    /// Etiqueta hablada. El título solo ("Ponérsela") no dice de QUÉ, y en una
    /// grilla de tres tarjetas hay tres botones que dicen lo mismo.
    var accessibilityLabel: Text?
    let action: () -> Void

    init(
        titleKey: LocalizedStringKey, systemImage: String, tint: Color = Color("PaletteGreen"),
        identifier: String, accessibilityLabel: Text? = nil, action: @escaping () -> Void
    ) {
        self.init(title: Text(titleKey), systemImage: systemImage, tint: tint, identifier: identifier,
                  accessibilityLabel: accessibilityLabel, action: action)
    }

    /// Un título que ya viene resuelto: el nombre de un visitante, un monto
    /// interpolado por `VisitCopy`.
    init(
        verbatim title: String, systemImage: String, tint: Color = Color("PaletteGreen"),
        identifier: String, accessibilityLabel: Text? = nil, action: @escaping () -> Void
    ) {
        self.init(title: Text(verbatim: title), systemImage: systemImage, tint: tint, identifier: identifier,
                  accessibilityLabel: accessibilityLabel, action: action)
    }

    private init(
        title: Text, systemImage: String, tint: Color, identifier: String,
        accessibilityLabel: Text?, action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.identifier = identifier
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                title
                    .font(Tokens.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 92)
            .background(PillBackground(fill: tint))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}
```

(Los llamadores de hoy usan `ActionPill(titleKey:…)` con etiquetas: no cambian.)

`FisuEvolution/UI/Art/RewardedOfferButton.swift`:

```swift
import SwiftUI

/// El botón de "mirá un video y…" de la 2.0 (PLAN-v2, cimientos): visitantes,
/// salidas de eventos, cartas del Vendedor y, después, ruleta y ofertas. Mientras
/// el anuncio corre, una ruedita en su lugar; la recompensa se entrega SÓLO si
/// el anuncio terminó con premio (`onRewarded`).
struct RewardedOfferButton: View {
    let title: String
    let identifier: String
    var placement: RewardedPlacement = .visitor
    let onRewarded: () -> Void

    @Environment(AdsCoordinator.self) private var ads
    @State private var watching = false

    var body: some View {
        if watching {
            ProgressView()
                .frame(minWidth: 92, minHeight: 36)
                .accessibilityIdentifier("\(identifier).watching")
        } else {
            ActionPill(verbatim: title, systemImage: "play.fill", tint: Color("PaletteGreen"), identifier: identifier) {
                watching = true
                Task {
                    if await ads.showRewarded(for: placement) { onRewarded() }
                    watching = false
                }
            }
        }
    }
}
```

`FisuEvolution/UI/Visitors/VisitorFace.swift`:

```swift
import SwiftUI

/// La cara de un visitante en un círculo: la dibujada (`<id>_face`) si existe;
/// si no, la cabeza recortada de su canónica; si tampoco, su respaldo (disco con
/// símbolo). Es la cara del chip, del popup y del chip de evento (T4).
struct VisitorFace: View {
    let visitorId: String
    var side: CGFloat = 40
    @Environment(GameState.self) private var gameState

    var body: some View {
        face
            .frame(width: side, height: side)
            .background(Color("PaletteCream"))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: max(1.5, side / 22)))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        if let manifest = gameState.content?.manifest, VisitorArt.hasOwnFace(visitorId, manifest: manifest),
           let image = VisitorArt.image(for: visitorId, pose: .face, manifest: manifest) {
            image.resizable().scaledToFill()
        } else if let manifest = gameState.content?.manifest,
                  let image = VisitorArt.image(for: visitorId, pose: .canonical, manifest: manifest) {
            // Sin cara dibujada: el tercio de arriba de la canónica, agrandado.
            image.resizable().scaledToFit()
                .scaleEffect(1.9, anchor: .top)
                .offset(y: side * 0.04)
        } else {
            let visitor = gameState.content?.visitors.visitor(id: visitorId)
            Image(uiImage: VisitorArt.placeholderImage(symbol: visitor?.fallbackSymbol ?? "person.fill",
                                                      tint: visitor?.fallbackTint ?? "PaletteBlue", side: side))
                .resizable()
        }
    }
}
```

`FisuEvolution/Managers/LoopsManifest.swift`:

```swift
import Foundation

/// `loops_manifest.json` (PLAN-v2 E8 pipeline): los loops de retrato de los
/// visitantes y las cinemáticas. Lo escribe `video_assets.py`; acá sólo se lee.
/// Hoy está vacío: todo popup cae a la foto quieta.
struct LoopsManifest: Decodable, Sendable, Equatable {
    struct Entry: Decodable, Sendable, Equatable {
        let file: String
        let width: Int
        let height: Int
        let alpha: Bool
    }

    let schemaVersion: Int
    let portraits: [String: Entry]
    let cinematics: [String: Entry]

    static func load(from bundle: Bundle) throws -> LoopsManifest {
        guard let url = bundle.url(forResource: "loops_manifest", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(contentsOf: url))
    }

    /// El del bundle, leído una vez. Sin archivo o roto, vacío: ningún flujo
    /// depende de que haya loops.
    static let main: LoopsManifest = (try? load(from: .main))
        ?? LoopsManifest(schemaVersion: 1, portraits: [:], cinematics: [:])

    /// El archivo del loop de un visitante. Xcode aplana los recursos en la raíz
    /// del bundle: se busca por nombre, sin la carpeta `Loops/`.
    func portraitURL(for visitorId: String, in bundle: Bundle = .main) -> URL? {
        guard let entry = portraits[visitorId] else { return nil }
        let file = entry.file as NSString
        return bundle.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension)
    }
}
```

`FisuEvolution/UI/Visitors/LoopingPortraitView.swift`:

```swift
import AVFoundation
import SwiftUI
import UIKit

/// El retrato animado de un visitante (PLAN-v2 E4): su loop HEVC con alfa,
/// en loop y mudo, SÓLO mientras su popup está abierto —un solo `AVPlayer` a la
/// vez (PLAN-v2 E8)—. Sin loop, o con Reduce Motion, la foto quieta.
///
/// Va aparte de `ChestCinematicPlayer` a propósito: el cofre tiene su preroll y
/// su congelón en el último cuadro (HANDOFF §7), y un loop no tiene ninguno.
struct LoopingPortraitView<Fallback: View>: View {
    let url: URL?
    @ViewBuilder let fallback: () -> Fallback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let url, !reduceMotion {
            LoopPlayerView(url: url)
                .accessibilityHidden(true)
        } else {
            fallback()
        }
    }
}

private struct LoopPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopPlayerUIView {
        LoopPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopPlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

/// La capa del video. `AVPlayerLooper` repite sin costura (el primer cuadro y el
/// último son el mismo: así se generan los loops).
final class LoopPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        if let layer = layer as? AVPlayerLayer {
            layer.player = player
            layer.videoGravity = .resizeAspect
            // HEVC con alfa: sin BGRA el fondo transparente sale negro.
            layer.pixelBufferAttributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        }
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LoopPlayerUIView is never decoded")
    }

    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }
}
```

- [ ] **Step 4: El chip y el popup**

`FisuEvolution/UI/Visitors/StageChips.swift`:

```swift
import SwiftUI

/// Los chips del escenario, bajo el HUD (PLAN-v2 E4): el objetivo de toque
/// determinista y accesible de quien está en escena. La escena también se toca,
/// pero un nodo de SpriteKit que camina no es un control para VoiceOver.
struct StageChips: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        Group {
            if let visit = gameState.stageVisit, visit.phase == .waiting,
               visit.offer != nil, gameState.stageChallenge == nil {
                VisitorChip(visit: visit) { gameState.openVisitorPopup() }
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: gameState.stageVisit?.offer != nil)
    }
}

/// La cara de quien espera, su nombre y un "!" que late.
struct VisitorChip: View {
    let visit: StageVisit
    let action: () -> Void
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var name: String {
        gameState.content?.visitors.visitor(id: visit.actorId).map { VisitCopy.name(of: $0) } ?? ""
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VisitorFace(visitorId: visit.actorId, side: 38)
                Text(verbatim: name)
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color("PaletteOrange"))
                    .scaleEffect(pulse ? 1.15 : 1)
            }
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stage.chip.visitor")
        .accessibilityLabel(Text("visit.chip.ax \(name)"))
        .tutorialAnchor(.visitor)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
```

`FisuEvolution/UI/Visitors/VisitorPopupView.swift`:

```swift
import EconomyKit
import SwiftUI

/// El popup de un visitante (PLAN-v2 E4): su retrato, su pedido en el globo de
/// la 2.0 y una opción por botón. Lo que da es verde; lo que cobra, naranja —o
/// un badge apagado si no alcanza o hay corralito: nunca `.disabled`—; lo que
/// pide video, `RewardedOfferButton`. Los montos son los que se cotizaron al
/// llegar, los mismos del globo.
struct VisitorPopupView: View {
    @Environment(GameState.self) private var gameState
    private static let portraitSide: CGFloat = 132

    var body: some View {
        PanelCard {
            if let visit = gameState.stageVisit, let offer = visit.offer, let content = gameState.content,
               let script = content.visitors.script(id: offer.scriptId),
               let visitor = content.visitors.visitor(id: offer.visitorId) {
                VStack(spacing: Tokens.s12) {
                    PanelTitleBanner(verbatim: VisitCopy.name(of: visitor))
                    LoopingPortraitView(url: LoopsManifest.main.portraitURL(for: visitor.id)) {
                        VisitorFace(visitorId: visitor.id, side: Self.portraitSide)
                    }
                    .frame(width: Self.portraitSide, height: Self.portraitSide)
                    Text(verbatim: VisitCopy.ask(for: script, offer: offer, content: content))
                        .font(Tokens.prose)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Tokens.s12)
                        .padding(.top, BubbleGeometry.tailHeight)
                        .background(
                            BubbleShape(tailFraction: 0.5)
                                .rotation(.degrees(180))
                                .fill(Color("PaletteCream"))
                                .overlay(BubbleShape(tailFraction: 0.5).rotation(.degrees(180))
                                    .stroke(Color("PaletteInk"), lineWidth: 2))
                        )
                    VStack(spacing: Tokens.s8) {
                        ForEach(offer.options) { option in
                            optionButton(option, script: script, content: content)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.s8)
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.closeVisitorPopup() }
                .padding(10)
        }
        .padding(16)
        // Sin identifier en el contenedor: pisaría el de los botones (trampa 9a-bis).
        .presentationDetents([.fraction(0.62)])
        // Transparente y del tamaño de página en iPad: `fisuSheet()` (E3a T6).
        // Un `.presentationBackground(.clear)` a mano lo rechaza `SheetPresentationGuardTests`.
        .fisuSheet()
    }

    @ViewBuilder
    private func optionButton(_ option: VisitOption, script: VisitorsConfig.Script, content: GameContent) -> some View {
        let title = VisitCopy.optionTitle(option, script: script, content: content)
        let identifier = "visit.option.\(option.id)"
        if option.requiresVideo {
            RewardedOfferButton(title: title, identifier: identifier) {
                gameState.chooseVisitOption(option.id)
            }
        } else if option.cost > 0, !gameState.canAfford(option) {
            StateBadge(text: title, systemImage: "lock.fill", textAlignment: .center, muted: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
        } else {
            ActionPill(verbatim: title, systemImage: Self.symbol(for: option.kind),
                       tint: option.cost > 0 ? Color("PaletteOrange") : Color("PaletteGreen"),
                       identifier: identifier) {
                gameState.chooseVisitOption(option.id)
            }
        }
    }

    private static func symbol(for kind: VisitOption.Kind) -> String {
        switch kind {
        case .payBail, .payFine, .exchange: "banknote.fill"
        case .release, .sell: "hand.wave.fill"
        case .startChallenge: "hand.tap.fill"
        case .listen: "ear.fill"
        case .accept, .acceptWithVideo, .forgiveWithVideo, .card: "checkmark"
        }
    }
}
```

(La cola del globo apunta ARRIBA, al retrato: por eso la forma va rotada 180°.)

`GameState+Visitors.swift`, `openVisitorPopup()` suma al final:

```swift
        tutorialTipCompleted(.visitor)
```

- [ ] **Step 5: La lección**

`TutorialAnchor.swift`, en `TutorialTarget`, después de `prestige`:

```swift
    /// El chip de quien está en escena (`StageChips`).
    case visitor
```

`GameState+TutorialTips.swift`: `.visitor` es el **primer** caso de `TutorialLesson` (una visita
se va sola: si espera su turno detrás de otra lección, se pierde):

```swift
        /// Alguien en escena esperando que lo toquen: la primera visita enseña el chip.
        case visitor
```

y en los cuatro `switch`: `anchorTarget` → `case .visitor: .visitor`; `destinationScreen` → `.visitor`
se suma a la fila de `nil`; `textKey` → `case .visitor: "tutorial.tip.visitor"`; `isEligible` →

```swift
        case .visitor:
            stageVisit?.phase == .waiting && stageVisit?.offer != nil && stageChallenge == nil
```

- [ ] **Step 6: `RootView` (🔥)**

1. En `hudColumn`, después del bloque de `ActiveBonusBar`:

```swift
            // Quien está en escena se toca desde acá: la cara, el nombre y su "!".
            StageChips()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .playColumn()
```

2. Junto a las otras hojas:

```swift
        .sheet(item: Binding(
            get: { gameState.visitorPopup },
            set: { if $0 == nil { gameState.closeVisitorPopup() } }
        )) { _ in
            VisitorPopupView()
        }
```

3. `uiCoversBoard`: los términos que hoy repite cada `onChange` (y los que sumaron E3a T11 y
   E3b T4) pasan a una sola propiedad, y cada `onChange` que escribe `uiCoversBoard` escribe
   `coversBoard`:

```swift
    /// Lo que tapa el tablero: una hoja de la barra, el prestigio, la carta de un
    /// special y los popups del escenario. Con esto en `true` frenan la paciencia
    /// de los visitantes, los cambios del tablero, las lecciones y los
    /// intersticiales.
    private var coversBoard: Bool {
        activeScreen != nil || showPrestige || gameState.specialInfo != nil
            || gameState.visitorPopup != nil || gameState.eventPopup != nil
    }
```

```swift
        .onChange(of: gameState.visitorPopup) { _, _ in
            gameState.uiCoversBoard = coversBoard
        }
        .onChange(of: gameState.eventPopup) { _, _ in
            gameState.uiCoversBoard = coversBoard
        }
```

- [ ] **Step 7: Los textos**

`Tools/v2/claves-pendientes/e4b-t3.json`:

```json
{
  "visit.chip.ax %@": {"es": "%@ quiere hablar con vos", "en": "%@ wants to talk to you"},
  "tutorial.tip.visitor": {"es": "¡Tenés visita! Tocá su cara para ver qué trae.", "en": "You've got a visitor! Tap their face to see what they brought."}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4b-t3.json` → `2 claves nuevas`.

- [ ] **Step 8: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/LoopsManifestTests -only-testing:FisuEvolutionTests/TutorialTipsTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/SheetPresentationGuardTests`
→ PASS; UI: `-only-testing:FisuEvolutionUITests/VisitorUITests` → PASS (3). A mano (SE y iPad 13",
claro y oscuro, VoiceOver una pasada): `comisario_arresto` con duplicados (fianza naranja y "que
se lo lleve" verde; sin plata, la fianza es un badge con candado); `arbolito_cambio` sin plata;
`sindicalista_aumento` (video). Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 9: Commit**

```bash
git add FisuEvolution/UI/Visitors/VisitorFace.swift FisuEvolution/UI/Visitors/StageChips.swift \
  FisuEvolution/UI/Visitors/VisitorPopupView.swift FisuEvolution/UI/Visitors/LoopingPortraitView.swift \
  FisuEvolution/Managers/LoopsManifest.swift FisuEvolution/UI/Art/RewardedOfferButton.swift \
  FisuEvolution/UI/Art/GameArtComponents.swift FisuEvolution/Game/State/GameState+Visitors.swift \
  FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/UI/Tutorial/TutorialAnchor.swift \
  FisuEvolution/App/RootView.swift FisuEvolutionTests/LoopsManifestTests.swift \
  FisuEvolutionTests/TutorialTipsTests.swift FisuEvolutionUITests/VisitorUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t3.json, según la ola
git diff --cached --stat
git commit -m "feat(visitantes): el chip con su cara, el popup con su retrato y la primera visita enseñada"
```

---

### Task 4: Los eventos entran con su presentador; el chip con su cara reemplaza al banner

**Objetivo:** un evento ya no aparece de golpe en un banner: lo **anuncia alguien** que entra a
escena (el Ministro la Devaluación, la Vecina el Apagón…), y recién cuando llega el evento pasa;
dice la frase en su globo y se va a los 4 s. Lo que queda corriendo es un **chip en la barra de
bonus con la cara de quien lo anunció**, su efecto y su cuenta regresiva; tocarlo abre el popup
del evento con la frase, qué cambia, cuánto falta y las salidas (video, cuota, gratis). Si el
escenario está ocupado, el evento espera a que se libere (y ningún visitante entra antes). Se
borra el banner entero: `EventBannerView`, `activeEvent`, `announcedEventID`,
`eventBannerIsVisible` y `CelebrationKind.eventBanner`.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Events.swift` (presentador; popup; sin `ActiveEvent`)
- Modify: `FisuEvolution/Game/State/GameState+Stage.swift` (`arrive` y `openStagePopup` del presentador)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`presentPendingEventIfPossible`; el fixture)
- Modify: `FisuEvolution/Game/State/GameState.swift` (🔥: se van `activeEvent`, `announcedEventID` y su línea de `flushHUD`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (se va `.eventBanner`)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift`
- Modify: `FisuEvolutionTests/CelebrationWiringTests.swift`
- Modify: `FisuEvolution/Game/State/ActiveBonus.swift` (`Icon.face`, `eventId`, `polarity`, `EventChipSource`, el agrupado)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`makeActiveBonuses` con los eventos; el catálogo de visitas)
- Modify: `FisuEvolution/UI/HUD/ActiveBonusBar.swift` (los chips de evento son botones)
- Create: `FisuEvolution/UI/Events/EventPopupView.swift`
- Delete: `FisuEvolution/UI/HUD/EventBannerView.swift`
- Modify: `FisuEvolution/App/RootView.swift` (🔥: se va el banner; la barra abre el popup; la hoja)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugPresentEvent`; `debugResetSave`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` ("Disparar un evento" pasa por el presentador)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`, `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (lección `.eventChip`)
- Modify: `FisuEvolutionTests/ActiveBonusTests.swift`, `FisuEvolutionTests/EventsRuntimeTests.swift`, `FisuEvolutionTests/TutorialTipsTests.swift`
- Create: `FisuEvolutionTests/EventPresenterTests.swift`
- Modify: `FisuEvolutionUITests/CorralitoUITests.swift`; Create: `FisuEvolutionUITests/EventChipUITests.swift`
- Create: `Tools/v2/claves-pendientes/e4b-t4.json`

**Interfaces:**
- Consumes: T1–T3; `EventCatalog`, `EventPlanner`, `startEvent`, `escapeEvent`, `eventFee`,
  `eventFeeText`, `fireDueEvent`, `debugStartEvent` (E4a T4, T9); `ModifierMath.isImmuneToEvents`
  (E4a T2); `RewardedOfferButton`, `VisitorFace` (T3).
- Produces: `GameState.presentEvent(_:)`, `presentPendingEventIfPossible()`, `presenter(for:)`,
  `eventPresenterId(_:)`, `arrivePresenter(_:eventId:now:)`, `openEventPopup(id:)`,
  `closeEventPopup()`, `isEventRunning(id:now:)`, `debugPresentEvent(id:)`; `EventChipSource`;
  `ActiveBonus.Icon.face(String)`, `ActiveBonus.eventId`, `ActiveBonus.polarity`;
  `ActiveBonusBar(bonuses:onEventTap:)`; `EventPopupView(eventId:)`;
  `GameState.TutorialLesson.eventChip`, `TutorialTarget.eventChip`.
- Identificadores: `hud.event.chip.<id>`, `event.escape` (video), `event.escape.fee`, `event.escape.free`.
- `debugStartEvent(id:)` **sigue aplicando en el acto** (los tests de unidad y el Corralito);
  `--uitest-event=<id>` y el panel de debug pasan ahora por el presentador.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/EventPresenterTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los eventos entran con su presentador", .serialized)
@MainActor
struct EventPresenterTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 10)
        gameState.debugGrantCoins()
        return gameState
    }

    private func arrive(_ gameState: GameState) throws {
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
    }

    private func running(_ gameState: GameState, _ id: String) -> Bool {
        gameState.player?.run.activeModifiers.contains { $0.sourceKey == "event.\(id)" } == true
    }

    @Test("el sorteo manda al presentador; el evento no pasa hasta que llega")
    func theDrawSendsThePresenter() async throws {
        let gameState = await world()
        gameState.fireDueEvent(now: Date().timeIntervalSince1970)
        let visit = try #require(gameState.stageVisit)
        guard case .presenter(let id) = visit.role else { Issue.record("no es un presentador"); return }
        #expect(!running(gameState, id))
        let event = try #require(gameState.content?.events.event(id: id))
        #expect(event.presenters.contains(visit.actorId))
    }

    @Test("al llegar, el evento pasa, el globo dice su frase y se va enseguida")
    func arrivingStartsTheEvent() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "devaluacion")
        #expect(!running(gameState, "devaluacion"))
        try arrive(gameState)
        #expect(running(gameState, "devaluacion"))
        let event = try #require(gameState.content?.events.event(id: "devaluacion"))
        #expect(gameState.stageVisit?.bubble == VisitCopy.text(event.phraseKey))
        #expect(gameState.stageRuntime.eventPresenters["devaluacion"] == gameState.stageVisit?.actorId)
        gameState.advanceStage(delta: (gameState.content?.visitors.presenterTalkSeconds ?? 4) + 0.1)
        #expect(gameState.stageVisit?.phase == .leaving)
    }

    @Test("con inmunidad, el presentador de un negativo llega y no pasa nada")
    func immunityStopsANegativeAtTheDoor() async throws {
        let gameState = await world()
        gameState.grant(.eventImmunity(seconds: 600), source: "visit.test")
        gameState.debugPresentEvent(id: "devaluacion")
        try arrive(gameState)
        #expect(!running(gameState, "devaluacion"))
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("event.immune"))
    }

    @Test("con el escenario ocupado el evento espera, y entra antes que el próximo visitante")
    func theEventWaitsForTheStage() async throws {
        let gameState = await world()
        let script = try #require(gameState.content?.visitors.script(id: "turista_propina"))
        gameState.presentVisitor(script)
        try arrive(gameState)
        gameState.debugPresentEvent(id: "ola_calor")
        #expect(gameState.stageRuntime.pendingEvent?.id == "ola_calor")
        #expect(gameState.stageVisit?.role == .visitor(scriptId: "turista_propina"))
        let visitor = try #require(gameState.stageVisit?.id)
        gameState.sendStageActorAway()
        gameState.stageActorLeft(id: visitor)
        gameState.advanceEngagement(delta: 0)
        #expect(gameState.stageVisit?.role == .presenter(eventId: "ola_calor"))
        #expect(gameState.stageRuntime.pendingEvent == nil)
    }

    @Test("tocar al presentador abre el popup del evento")
    func tappingThePresenterOpensTheEvent() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "devaluacion")
        try arrive(gameState)
        gameState.stageActorTapped(id: try #require(gameState.stageVisit?.id))
        #expect(gameState.eventPopup?.eventId == "devaluacion")
    }

    @Test("salir del evento cierra su popup; un evento que no corre no abre ninguno")
    func escapingClosesThePopup() async throws {
        let gameState = await world()
        gameState.openEventPopup(id: "paro_general")
        #expect(gameState.eventPopup == nil, "no está corriendo")
        gameState.debugStartEvent(id: "paro_general")
        gameState.openEventPopup(id: "paro_general")
        #expect(gameState.eventPopup?.eventId == "paro_general")
        #expect(gameState.escapeEvent(id: "paro_general", via: .fee))
        #expect(gameState.eventPopup == nil)
    }

    @Test("el chip del evento lleva la cara de quien lo anunció")
    func theChipCarriesThePresentersFace() async throws {
        let gameState = await world()
        gameState.debugPresentEvent(id: "hiperinflacion")
        let presenter = try #require(gameState.stageVisit?.actorId)
        try arrive(gameState)
        gameState.refreshProjections()
        let chip = try #require(gameState.activeBonuses.first { $0.eventId == "hiperinflacion" })
        #expect(chip.icon == .face(presenter))
        #expect(chip.polarity == .mixed)
        #expect(gameState.activeBonuses.filter { $0.eventId == "hiperinflacion" }.count == 1,
                "un evento con dos efectos es UN chip")
    }
}
```

`ActiveBonusTests.swift`: el test `eventsStayOutBecauseTheyHaveTheirOwnBanner` pasa a

```swift
    @Test("un evento sin su fuente no entra: el chip de evento necesita la cara")
    func eventsWithoutTheirSourceStayOut() {
        let bonuses = build([modifier(source: "event.plan_platita"), modifier(source: "boost.mate")])

        #expect(bonuses.count == 1)
        #expect(bonuses.first?.icon == .art("ui_boost_mate"))
    }

    @Test("los modificadores de un evento son UN chip, con la cara, la polaridad y sus efectos")
    func anEventIsOneChipWithAFace() throws {
        let events = ["event.hiperinflacion": EventChipSource(presenterId: "npc_ministro", polarity: .mixed, duration: 60)]
        let bonuses = ActiveBonusBuilder.bonuses(
            from: [
                modifier(.spawnCostMultiplier, magnitude: 2, source: "event.hiperinflacion"),
                modifier(.incomeMultiplier, magnitude: 3, source: "event.hiperinflacion"),
                modifier(source: "boost.fernet"),
            ],
            catalog: catalog, events: events, now: now
        )
        #expect(bonuses.count == 2)
        let chip = try #require(bonuses.first { $0.eventId == "hiperinflacion" })
        #expect(chip.icon == .face("npc_ministro"))
        #expect(chip.polarity == .mixed)
        #expect(chip.totalDuration == 60)
        #expect(chip.effectText.contains(" · "), "los dos efectos, en el mismo chip")
    }
```

`EventsRuntimeTests.swift`: se borran `bannerShowsTheEvent` y `bannerLifetime` (el banner ya no
existe; lo que pinean lo pinea ahora `EventPresenterTests`).

`TutorialTipsTests.swift`:

```swift
    @Test("el primer evento corriendo enseña su chip, y abrirlo la cumple")
    func theFirstEventTeachesItsChip() async throws {
        let gameState = await makeGameState()
        gameState.markLessonDone(.visitor)
        gameState.debugStartEvent(id: "devaluacion")
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .eventChip)
        gameState.openEventPopup(id: "devaluacion")
        #expect(gameState.showing != .tutorialTip)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.eventChip.defaultsKey))
    }
```

`CelebrationQueueTests.swift`, en `elapsedResetsPerItem`: `.eventBanner` → `.visitorEncounter`
(dos veces) y el comentario `// tope 10 s`; el mensaje del `#expect`, "la entrada recién
empieza, no hereda los 3,9 s". `CelebrationWiringTests.swift`: se borra el `case .eventBanner`.

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests` → PASS todavía
(el caso existe); `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/EventPresenterTests -only-testing:FisuEvolutionTests/ActiveBonusTests`
→ no compila (`debugPresentEvent`, `EventChipSource`).

- [ ] **Step 3: El presentador**

`GameState+Events.swift`:

1. Se borran `struct ActiveEvent`, `instantEventBannerSeconds` y `expireActiveEvent(now:)`.
2. En `startEvent`, se borra la asignación a `activeEvent` (el `audio?.play(.event)` y lo demás
   quedan); en `escapeEvent`, el bloque `if activeEvent?.id == id, …` pasa a

```swift
        if eventPopup?.eventId == id, !isEventRunning(id: id, now: now) { eventPopup = nil }
```

   y en `cutNegativeEvents`, la línea de `activeEvent` pasa a

```swift
        if let popup = eventPopup, !isEventRunning(id: popup.eventId, now: now) { eventPopup = nil }
```

3. `fireDueEvent(now:)` termina en `presentEvent(event)` en vez de `startEvent(event, now: now)`.
4. Al final de la extensión:

```swift
    // MARK: El presentador (E4b)

    /// El evento sale con su presentador: entra a escena, lo anuncia y recién al
    /// llegar pasa. Con el escenario ocupado espera, y ningún visitante entra antes.
    func presentEvent(_ event: EventCatalog.Event) {
        stageRuntime.pendingEvent = event
        presentPendingEventIfPossible()
    }

    func presentPendingEventIfPossible() {
        guard let event = stageRuntime.pendingEvent, canPresentOnStage else { return }
        stageRuntime.pendingEvent = nil
        presentOnStage(actorId: presenter(for: event), role: .presenter(eventId: event.id))
    }

    /// Uno de sus presentadores que pueda venir: un especial, sólo si lo tenés.
    func presenter(for event: EventCatalog.Event) -> String {
        let owned = Set(player?.meta.ownedSpecials ?? [])
        let candidates = event.presenters.filter { id in
            content?.visitors.visitor(id: id)?.kind == .npc || owned.contains(id)
        }
        return candidates.randomElement(using: &rng) ?? event.presenters.first ?? "npc_conductor"
    }

    /// La cara del chip: quien lo anunció, o el primero del dato (después de relanzar).
    func eventPresenterId(_ event: EventCatalog.Event) -> String {
        stageRuntime.eventPresenters[event.id] ?? event.presenters.first ?? "npc_conductor"
    }

    /// Llegó el presentador: el evento pasa ahora y él dice la frase. Contra un
    /// negativo con inmunidad (la Obra social), llega y avisa que no te toca.
    func arrivePresenter(_ visit: inout StageVisit, eventId: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let event = content.events.event(id: eventId), let player else { return }
        stageRuntime.patienceLeft = content.visitors.presenterTalkSeconds
        if event.polarity == .negative, ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: now) {
            visit.bubble = VisitCopy.text("event.immune")
            return
        }
        stageRuntime.eventPresenters[event.id] = visit.actorId
        startEvent(event, now: now)
        visit.bubble = VisitCopy.text(event.phraseKey)
    }

    func isEventRunning(id: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        player?.run.activeModifiers.contains { $0.sourceKey == "event.\(id)" && $0.isActive(at: now) } == true
    }

    /// El popup de un evento corriendo (su chip o su presentador).
    func openEventPopup(id: String) {
        guard isEventRunning(id: id) else { return }
        eventPopup = EventPopup(eventId: id)
        tutorialTipCompleted(.eventChip)
    }

    func closeEventPopup() {
        eventPopup = nil
    }
```

`GameState+Stage.swift`, en `arrive(_:)`:

```swift
        case .presenter(let eventId):
            arrivePresenter(&visit, eventId: eventId)
```

y en `openStagePopup()`:

```swift
        case .presenter(let eventId):
            openEventPopup(id: eventId)
```

`GameState+Engagement.swift`:

```swift
    func advanceEngagement(delta: TimeInterval) {
        advanceEvents(delta: delta)
        presentPendingEventIfPossible()
        advanceVisitors(delta: delta)
        advanceStage(delta: delta)
    }
```

y el fixture `--uitest-event=` llama `debugPresentEvent(id:)` en vez de `debugStartEvent(id:)`.

`GameState+Debug.swift`, en `#if DEBUG`:

```swift
    /// Un evento con su presentador, ya mismo: lo que ve el jugador. Si hay alguien
    /// en escena, el evento espera a que se vaya, como en el juego.
    func debugPresentEvent(id: String) {
        guard let event = content?.events.event(id: id) else { return }
        presentEvent(event)
    }
```

y en `debugResetSave` se borra `activeEvent = nil`. `DebugPanelView.swift`, en el menú "Disparar
un evento": `gameState.debugStartEvent(id:)` → `gameState.debugPresentEvent(id:)`.

- [ ] **Step 4: Adiós al banner (🔥 `GameState.swift`)**

- `GameState.swift`: se borran `var activeEvent` (con su comentario) y `announcedEventID` (con el
  suyo, `:389-391`); en `flushHUD()`, la línea `expireActiveEvent(now: now)`.
- `GameState+Celebrations.swift`: en `syncCelebrations()` se borra el `if let event = activeEvent …`;
  se borra `eventBannerIsVisible` entero; en `releasePayload`, el `case .eventBanner:` con su
  cuerpo.
- `CelebrationQueue.swift`: se borra `case eventBanner` con su docstring; en `priority`,
  `case .visitorEncounter: 5`; en `timeout`, se borra `case .eventBanner: 6`.
- `git rm FisuEvolution/UI/HUD/EventBannerView.swift`.
- `ActiveBonus.swift` y `ActiveBonusBar.swift`: los comentarios que nombran a `EventBannerView`
  pasan a nombrar al chip de evento.

- [ ] **Step 5: El chip de evento**

`ActiveBonus.swift`:

```swift
struct ActiveBonus: Identifiable, Equatable {
    /// Con qué se dibuja. Los boosts tienen arte en el atlas UI; el video y el
    /// premio de carrera, un glifo; los eventos y las visitas, la cara de quien
    /// los trajo.
    enum Icon: Equatable {
        case art(String)
        case symbol(String)
        case face(String)
    }

    let id: UUID
    let effect: ActiveModifier.Effect
    let icon: Icon
    /// "×3", "−30%". Sale del mismo formateador que el menú de Bonus. Un evento
    /// con dos efectos los junta: "+100% · ×3".
    let effectText: String
    let expiresAt: TimeInterval
    let totalDuration: TimeInterval?
    /// El evento de este chip: lo vuelve un botón que abre su popup.
    var eventId: String? = nil
    var polarity: EventCatalog.Polarity? = nil
}

/// Lo que un chip de evento necesita y el modificador no sabe: la cara de quien
/// lo anunció, su polaridad y cuánto dura.
struct EventChipSource: Equatable {
    let presenterId: String
    let polarity: EventCatalog.Polarity
    let duration: TimeInterval
}
```

y `ActiveBonusBuilder.bonuses` pasa a:

```swift
    /// Los modificadores de un evento.
    private static let eventPrefix = "event."

    static func bonuses(
        from modifiers: [ActiveModifier],
        catalog: [String: BonusSource],
        events: [String: EventChipSource] = [:],
        now: TimeInterval
    ) -> [ActiveBonus] {
        let live = modifiers.filter { modifier in
            modifier.isActive(at: now)
                // Los permanentes no son un contador: la Milanesa sube la
                // eficiencia offline para siempre y no tiene nada que contar.
                && modifier.expiresAt.isFinite
        }
        let plain = live.filter { !$0.sourceKey.hasPrefix(eventPrefix) }.map { modifier in
            let source = catalog[modifier.sourceKey]
            return ActiveBonus(
                id: modifier.id,
                effect: modifier.effect,
                icon: source?.icon ?? .symbol(fallbackSymbol),
                effectText: effectText(for: modifier),
                expiresAt: modifier.expiresAt,
                totalDuration: source?.duration
            )
        }
        // Un evento es UN chip aunque traiga dos efectos (la Hiperinflación). Sin
        // su fuente no hay cara que mostrar y no entra.
        let byEvent = Dictionary(grouping: live.filter { $0.sourceKey.hasPrefix(eventPrefix) }, by: \.sourceKey)
        let eventChips = byEvent.compactMap { sourceKey, group -> ActiveBonus? in
            guard let source = events[sourceKey], let first = group.first else { return nil }
            return ActiveBonus(
                id: first.id,
                effect: first.effect,
                icon: .face(source.presenterId),
                effectText: group.map(effectText(for:)).joined(separator: " · "),
                expiresAt: group.map(\.expiresAt).max() ?? first.expiresAt,
                totalDuration: source.duration,
                eventId: String(sourceKey.dropFirst(eventPrefix.count)),
                polarity: source.polarity
            )
        }
        // Primero el que vence, que es el que urge; el id desempata para que el
        // orden no baile entre dos lecturas.
        return (plain + eventChips).sorted {
            $0.expiresAt != $1.expiresAt ? $0.expiresAt < $1.expiresAt : $0.id.uuidString < $1.id.uuidString
        }
    }
```

(se borra `excludedPrefix`).

`GameState+Bonus.swift`, `makeActiveBonuses` pasa `events:`:

```swift
        return ActiveBonusBuilder.bonuses(
            from: player.run.activeModifiers,
            catalog: Self.bonusCatalog(content: content),
            events: Dictionary(uniqueKeysWithValues: content.events.events.map { event in
                (event.sourceKey, EventChipSource(presenterId: eventPresenterId(event), polarity: event.polarity,
                                                  duration: event.durationSeconds))
            }),
            now: Date().timeIntervalSince1970
        )
```

y `bonusCatalog(content:)` suma las visitas antes del `return` (las fuentes de
`rewardSource(for:scriptId:)`, T2):

```swift
        for script in content.visitors.scripts {
            let face = ActiveBonus.Icon.face(script.visitor)
            switch script.mechanic {
            case .vendor(let cards):
                for card in cards {
                    guard case let .modifier(_, _, seconds) = card.reward else { continue }
                    catalog["visit.\(script.id).card.\(card.id)"] = BonusSource(icon: .art(card.iconKey), duration: seconds)
                }
            case .challenge(_, _, let rewards, _):
                // El ×2 de un reto es otra tanda igual: dura lo mismo.
                for case let .modifier(_, _, seconds) in rewards {
                    catalog["visit.\(script.id)"] = BonusSource(icon: face, duration: seconds)
                    catalog["visit.\(script.id).x2"] = BonusSource(icon: face, duration: seconds)
                }
            default:
                for case let .modifier(_, _, seconds) in script.mechanic.rewards {
                    catalog["visit.\(script.id)"] = BonusSource(icon: face, duration: seconds)
                    catalog["visit.\(script.id).x2"] = BonusSource(icon: face, duration: seconds * 2)
                }
            }
        }
```

`ActiveBonusBar.swift`: la barra recibe `onEventTap`, se va el `.allowsHitTesting(false)` del
contenedor y lo lleva cada chip que no es de evento; los de evento son botones:

```swift
struct ActiveBonusBar: View {
    let bonuses: [ActiveBonus]
    /// Tocar el chip de un evento abre su popup.
    var onEventTap: (String) -> Void = { _ in }

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let iconSide: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(bonuses) { bonus in
                Group {
                    if let eventId = bonus.eventId {
                        Button { onEventTap(eventId) } label: { chip(bonus) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hud.event.chip.\(eventId)")
                            .accessibilityLabel(Text("hud.event.chip.ax \(eventTitle(eventId))"))
                            .tutorialAnchor(.eventChip)
                    } else {
                        // Es estado, no un control: no puede comerse un toque
                        // destinado al tablero que tiene abajo.
                        chip(bonus)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("hud.bonus.chip")
                            .accessibilityLabel(Text("hud.bonus.active.label"))
                    }
                }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.32), value: bonuses.map(\.id))
        .onReceive(timer) { now = $0 }
    }

    private func eventTitle(_ id: String) -> String {
        gameState.content?.events.event(id: id).map { VisitCopy.text($0.titleKey) } ?? id
    }

    private func chip(_ bonus: ActiveBonus) -> some View {
        let remaining = max(0, bonus.expiresAt - now.timeIntervalSince1970)
        let time = Self.timeText(remaining)
        let tint = bonus.polarity.map(Self.tint) ?? Self.tint(bonus.effect)
        return HStack(spacing: 7) {
            icon(bonus, tint: tint, progress: Self.progress(remaining: remaining, total: bonus.totalDuration))
            // El número y el tiempo van SIEMPRE, no sólo el color: un evento
            // suma además su flecha (sube, baja, las dos).
            if let polarity = bonus.polarity {
                Image(systemName: Self.symbol(polarity))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(tint)
            }
            Text(verbatim: bonus.effectText)
                .font(.system(size: 15, design: .rounded).weight(.heavy))
                .foregroundStyle(tint)
            Text(verbatim: time)
                .font(.system(size: 13, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        )
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(bonus.effectText) \(time)"))
    }

    private func icon(_ bonus: ActiveBonus, tint: Color, progress: Double) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.16))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            glyph(bonus, tint: tint)
        }
        .frame(width: Self.iconSide, height: Self.iconSide)
    }

    @ViewBuilder
    private func glyph(_ bonus: ActiveBonus, tint: Color) -> some View {
        switch bonus.icon {
        case .art(let key):
            if let art = UIArt.image(key) {
                art.resizable().scaledToFit()
                    .frame(width: Self.iconSide * 0.62, height: Self.iconSide * 0.62)
            } else {
                symbol("bolt.fill", tint: tint)
            }
        case .symbol(let name):
            symbol(name, tint: tint)
        case .face(let visitorId):
            VisitorFace(visitorId: visitorId, side: Self.iconSide - 6)
        }
    }

    private func symbol(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(tint)
    }

    /// El color de un evento dice hacia dónde va (y la flecha lo repite).
    static func tint(_ polarity: EventCatalog.Polarity) -> Color {
        switch polarity {
        case .positive: Color("PaletteGreen")
        case .negative: Color("PalettePink")
        case .mixed: Color("PaletteOrange")
        }
    }

    static func symbol(_ polarity: EventCatalog.Polarity) -> String {
        switch polarity {
        case .positive: "arrow.up.circle.fill"
        case .negative: "arrow.down.circle.fill"
        case .mixed: "arrow.up.arrow.down.circle.fill"
        }
    }
```

(`progress`, `timeText` y `tint(_ effect:)` quedan como están, con los casos de E4a T2.)

`FisuEvolution/UI/Events/EventPopupView.swift`:

```swift
import EconomyKit
import SwiftUI

/// El popup de un evento corriendo (PLAN-v2 E4): quien lo anunció, su frase en
/// el globo, qué cambia, cuánto falta y por dónde se sale. Se cierra solo
/// cuando el evento termina.
struct EventPopupView: View {
    let eventId: String
    @Environment(GameState.self) private var gameState
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        PanelCard {
            if let event = gameState.content?.events.event(id: eventId) {
                VStack(spacing: Tokens.s12) {
                    PanelTitleBanner(verbatim: VisitCopy.text(event.titleKey))
                    HStack(alignment: .center, spacing: Tokens.s12) {
                        VisitorFace(visitorId: gameState.eventPresenterId(event), side: 76)
                        Text(verbatim: VisitCopy.text(event.phraseKey))
                            .font(Tokens.prose)
                            .foregroundStyle(Color("PaletteInk"))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(Tokens.s12)
                            .background(
                                RoundedRectangle(cornerRadius: BubbleGeometry.cornerRadius, style: .continuous)
                                    .fill(Color("PaletteCream"))
                                    .overlay(RoundedRectangle(cornerRadius: BubbleGeometry.cornerRadius, style: .continuous)
                                        .strokeBorder(Color("PaletteInk"), lineWidth: 2))
                            )
                    }
                    if let chip = gameState.activeBonuses.first(where: { $0.eventId == eventId }) {
                        HStack(spacing: Tokens.s8) {
                            Image(systemName: ActiveBonusBar.symbol(event.polarity))
                            Text(verbatim: chip.effectText)
                            Spacer(minLength: Tokens.s8)
                            Text("event.popup.remaining \(ActiveBonusBar.timeText(max(0, chip.expiresAt - now.timeIntervalSince1970)))")
                                .monospacedDigit()
                        }
                        .font(Tokens.body)
                        .foregroundStyle(ActiveBonusBar.tint(event.polarity))
                    }
                    escapes(event)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.s8)
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { gameState.closeEventPopup() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(0.52)])
        .fisuSheet()
        .onReceive(timer) { tick in
            now = tick
            if !gameState.isEventRunning(id: eventId, now: tick.timeIntervalSince1970) { gameState.closeEventPopup() }
        }
    }

    @ViewBuilder
    private func escapes(_ event: EventCatalog.Event) -> some View {
        if event.escapes.isEmpty {
            // Dos `Text` y no un ternario adentro de uno: el ternario de dos literales
            // es un `String` y `Text` lo mostraría crudo, sin traducir.
            (event.polarity == .negative ? Text("event.popup.wait") : Text("event.popup.enjoy"))
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        } else {
            VStack(spacing: Tokens.s8) {
                ForEach(event.escapes, id: \.kind) { escape in
                    escapeButton(escape, of: event)
                }
            }
        }
    }

    @ViewBuilder
    private func escapeButton(_ escape: EventCatalog.Escape, of event: EventCatalog.Event) -> some View {
        switch escape.kind {
        case .video:
            RewardedOfferButton(title: String(localized: "event.escape.video"), identifier: "event.escape") {
                gameState.escapeEvent(id: event.id, via: .video)
            }
        case .fee:
            let title = String(localized: "event.escape.fee \(gameState.eventFeeText(id: event.id))")
            if (gameState.player?.run.coins ?? 0) >= (gameState.eventFee(id: event.id) ?? .infinity) {
                ActionPill(verbatim: title, systemImage: "banknote.fill", tint: Color("PaletteOrange"),
                           identifier: "event.escape.fee") {
                    gameState.escapeEvent(id: event.id, via: .fee)
                }
            } else {
                StateBadge(text: title, systemImage: "lock.fill", textAlignment: .center, muted: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("event.escape.fee")
            }
        case .free:
            ActionPill(titleKey: "event.escape.free", systemImage: "xmark", tint: Color("PaletteBlue"),
                       identifier: "event.escape.free") {
                gameState.escapeEvent(id: event.id, via: .free)
            }
        }
    }
}
```

- [ ] **Step 6: `RootView` (🔥) y la lección**

`RootView.hudColumn`: se borran el bloque `if let event = gameState.activeEvent, …
EventBannerView(…)` y su `.animation(…, value: gameState.activeEvent)`; la barra pasa a

```swift
                ActiveBonusBar(bonuses: gameState.activeBonuses) { gameState.openEventPopup(id: $0) }
```

y junto a la hoja del visitante:

```swift
        .sheet(item: Binding(
            get: { gameState.eventPopup },
            set: { if $0 == nil { gameState.closeEventPopup() } }
        )) { popup in
            EventPopupView(eventId: popup.eventId)
        }
```

El comentario de `RootView.swift:185` que nombra "el `VStack` del `EventBannerView`" pasa a
nombrar sólo el de `ActiveBonusBar`.

`TutorialAnchor.swift`: `case eventChip` (el chip de un evento, en la barra de bonus).
`GameState+TutorialTips.swift`: `.eventChip` es el **segundo** caso (después de `.visitor`):

```swift
        /// Un evento corriendo deja su chip: la primera vez se enseña a tocarlo.
        case eventChip
```

con `anchorTarget` → `.eventChip`, `destinationScreen` → `nil`, `textKey` →
`"tutorial.tip.event_chip"` e `isEligible` →

```swift
        case .eventChip:
            activeBonuses.contains { $0.eventId != nil }
```

- [ ] **Step 7: UI**

`CorralitoUITests.swift`: la primera espera pasa del botón del banner al chip, y la salida se
busca en el popup:

```swift
        let chip = app.buttons["hud.event.chip.corralito"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(app.buttons["event.escape"].waitForExistence(timeout: 6), "la salida por video vive en el popup")
        app.buttons["sheet.close"].tap()
        XCTAssertTrue(app.buttons["event.escape"].waitForNonExistence(timeout: 6))
```

(el resto del test, igual.)

`FisuEvolutionUITests/EventChipUITests.swift`:

```swift
import XCTest

/// Un evento de punta a punta: entra su presentador, lo anuncia, queda su chip
/// con la cara, y el popup ofrece la salida.
final class EventChipUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElPresentadorAnunciaYElChipAbreLaSalida() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-event=devaluacion"]
        app.launch()
        let chip = app.buttons["hud.event.chip.devaluacion"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "el presentador llega y el evento deja su chip")
        let anuncio = XCTAttachment(screenshot: app.screenshot())
        anuncio.name = "evento: el presentador y el chip"
        anuncio.lifetime = .keepAlways
        add(anuncio)
        chip.tap()
        let escape = app.buttons["event.escape"]
        XCTAssertTrue(escape.waitForExistence(timeout: 6))
        escape.tap()
        // El anuncio del stub dura 2 s; al terminar, el evento se va y su chip también.
        XCTAssertTrue(chip.waitForNonExistence(timeout: 12))
    }
}
```

- [ ] **Step 8: Los textos**

`Tools/v2/claves-pendientes/e4b-t4.json`:

```json
{
  "event.immune": {"es": "¡Tenés obra social! Este no te toca.", "en": "You're covered! This one doesn't touch you."},
  "event.popup.remaining %@": {"es": "Termina en %@", "en": "Ends in %@"},
  "event.popup.enjoy": {"es": "¡Aprovechalo mientras dura!", "en": "Make the most of it while it lasts!"},
  "event.popup.wait": {"es": "No hay con qué zafar: aguantá, que ya pasa.", "en": "No way out of this one: hang in there, it'll pass."},
  "hud.event.chip.ax %@": {"es": "Evento: %@", "en": "Event: %@"},
  "tutorial.tip.event_chip": {"es": "Cada evento deja acá la cara de quien lo trajo. Tocala para ver qué cambia y cómo zafar.", "en": "Every event leaves the face of whoever brought it here. Tap it to see what changes and how to get out of it."}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4b-t4.json` → `6 claves nuevas`.

- [ ] **Step 9: Verde, a mano y oráculo**

Run: `grep -rn "activeEvent\|announcedEventID\|eventBannerIsVisible\|EventBannerView\|\.eventBanner" FisuEvolution FisuEvolutionTests FisuEvolutionUITests Packages`
→ sin resultados. `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests`
→ PASS. `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/EventPresenterTests -only-testing:FisuEvolutionTests/ActiveBonusTests -only-testing:FisuEvolutionTests/EventsRuntimeTests -only-testing:FisuEvolutionTests/CorralitoTests -only-testing:FisuEvolutionTests/CelebrationWiringTests -only-testing:FisuEvolutionTests/TutorialTipsTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/SheetPresentationGuardTests`
→ PASS; UI: `-only-testing:FisuEvolutionUITests/EventChipUITests -only-testing:FisuEvolutionUITests/CorralitoUITests`
→ PASS. A mano: panel → "Disparar un evento" → `hiperinflacion` (un chip naranja con la cara
del Ministro y los dos efectos; el video saca sólo el ×2 de contratar), `paro_general` (la cuota;
sin plata, el badge apagado), `startup_comprada` (sin chip: dura 0; la evolución por el embudo
cuando el presentador llega). `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 10: Commit**

```bash
git rm FisuEvolution/UI/HUD/EventBannerView.swift
git add FisuEvolution/Game/State/GameState+Events.swift FisuEvolution/Game/State/GameState+Stage.swift \
  FisuEvolution/Game/State/GameState+Engagement.swift FisuEvolution/Game/State/GameState.swift \
  Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift \
  FisuEvolution/Game/State/GameState+Celebrations.swift FisuEvolutionTests/CelebrationWiringTests.swift \
  FisuEvolution/Game/State/ActiveBonus.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/UI/HUD/ActiveBonusBar.swift FisuEvolution/UI/Events/EventPopupView.swift \
  FisuEvolution/App/RootView.swift FisuEvolution/Game/State/GameState+Debug.swift FisuEvolution/UI/DebugPanelView.swift \
  FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/UI/Tutorial/TutorialAnchor.swift \
  FisuEvolutionTests/ActiveBonusTests.swift FisuEvolutionTests/EventsRuntimeTests.swift \
  FisuEvolutionTests/TutorialTipsTests.swift FisuEvolutionTests/EventPresenterTests.swift \
  FisuEvolutionUITests/CorralitoUITests.swift FisuEvolutionUITests/EventChipUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t4.json, según la ola
git diff --cached --stat
git commit -m "feat(eventos): cada evento lo anuncia alguien en escena y deja un chip con su cara; adiós al banner"
```

---

### Task 5: El reto en pantalla y las cartas del Vendedor

**Objetivo:** las dos mecánicas que en T3 quedaron "con botón genérico" se ven como lo que son.
Durante un reto de toques, el chip del visitante pasa a ser el **chip del reto**: su cara, "12/15",
la consigna y un aro que se vacía con el tiempo. El Vendedor Ambulante muestra sus boosts como
**tres cartas** (arte, nombre, efecto, duración) con el video en cada una; una carta por visita.

**Files:**
- Modify: `FisuEvolution/Game/State/StageVisit.swift` (`StageChallenge.progress`, `remaining(at:)`)
- Modify: `FisuEvolution/UI/Visitors/StageChips.swift` (`ChallengeChip`)
- Create: `FisuEvolution/UI/Visitors/VendorCardsView.swift`
- Modify: `FisuEvolution/UI/Visitors/VisitorPopupView.swift` (el Vendedor muestra cartas)
- Create: `FisuEvolutionTests/StageChallengeTests.swift`, `FisuEvolutionUITests/VisitorMechanicsUITests.swift`
- Create: `Tools/v2/claves-pendientes/e4b-t5.json`

**Interfaces:**
- Consumes: T1–T3; `VisitorsConfig.VendorCard`, `VisitCopy.effectText/durationText/text` (E4a T5, T7);
  `UIArt.image(_:)`, `GameCard`.
- Produces: `StageChallenge.progress: Double`, `StageChallenge.remaining(at:) -> TimeInterval`;
  `ChallengeChip`; `VendorCardsView(script:offer:)`.
- Identificadores: `stage.chip.challenge`; las cartas usan los de T3 (`visit.option.card.<id>`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/StageChallengeTests.swift`:

```swift
import EconomyKit
import Testing
@testable import FisuEvolution

@Suite("El reto de toques: lo que dibuja su chip")
struct StageChallengeTests {
    private let terms = ChallengeTerms(taps: 15, windowSeconds: 20, coins: 0, rewards: [], videoDoubles: false)

    @Test("el avance es toques sobre la meta, con tope")
    func progress() {
        #expect(StageChallenge(scriptId: "x", terms: terms, taps: 0, endsAt: 20).progress == 0)
        #expect(StageChallenge(scriptId: "x", terms: terms, taps: 6, endsAt: 20).progress == 0.4)
        #expect(StageChallenge(scriptId: "x", terms: terms, taps: 40, endsAt: 20).progress == 1)
    }

    @Test("lo que falta nunca es negativo")
    func remaining() {
        let challenge = StageChallenge(scriptId: "x", terms: terms, taps: 0, endsAt: 20)
        #expect(challenge.remaining(at: 5) == 15)
        #expect(challenge.remaining(at: 25) == 0)
    }
}
```

`FisuEvolutionUITests/VisitorMechanicsUITests.swift`:

```swift
import XCTest

/// Las dos mecánicas con pantalla propia: el reto (su chip reemplaza al del
/// visitante) y el Vendedor (tres cartas, una por visita). Los toques del reto
/// no se automatizan: son toques al tablero por coordenada (HANDOFF §7); los
/// cuenta `VisitorRuntimeTests`.
final class VisitorMechanicsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ script: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-visitor=\(script)"]
        app.launch()
        return app
    }

    @MainActor
    func testAceptarElRetoCambiaElChipPorElDelReto() throws {
        let app = launch("coach_reto")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let accept = app.buttons["visit.option.challenge"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6))
        accept.tap()
        let challenge = app.otherElements["stage.chip.challenge"]
        XCTAssertTrue(challenge.waitForExistence(timeout: 6), "el reto se juega en el tablero, con su contador")
        XCTAssertFalse(chip.exists, "mientras dura el reto no hay popup que abrir")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "reto: el chip con el contador"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testElVendedorMuestraTresCartasYSeLlevaUna() throws {
        let app = launch("vendedor_ofertas")
        let chip = app.buttons["stage.chip.visitor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        for card in ["mate", "cafe", "turbo"] {
            XCTAssertTrue(app.buttons["visit.option.card.\(card)"].waitForExistence(timeout: 6), "falta la carta \(card)")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "vendedor: las tres cartas"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["visit.option.card.mate"].tap()
        // El anuncio del stub dura 2 s; el boost queda corriendo y el Vendedor se va.
        XCTAssertTrue(app.otherElements["hud.bonus.chip"].waitForExistence(timeout: 10)
            || app.staticTexts["hud.bonus.chip"].waitForExistence(timeout: 1))
        XCTAssertTrue(chip.waitForNonExistence(timeout: 6))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/StageChallengeTests`
→ no compila (`progress`).

- [ ] **Step 3: El reto**

`StageVisit.swift`, al final:

```swift
extension StageChallenge {
    /// Toques sobre la meta, con tope en 1.
    var progress: Double {
        min(1, Double(taps) / Double(max(terms.taps, 1)))
    }

    func remaining(at now: TimeInterval) -> TimeInterval {
        max(0, endsAt - now)
    }
}
```

`StageChips.swift`: el `Group` del `body` suma, después del `if` del visitante:

```swift
            if let challenge = gameState.stageChallenge, let visit = gameState.stageVisit {
                ChallengeChip(challenge: challenge, visitorId: visit.actorId)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
```

y al final del archivo:

```swift
/// El reto en curso: la cara de quien lo propuso, la consigna, "12/15" y un aro
/// con el tiempo que queda. No es un botón: los toques van a los empleados.
struct ChallengeChip: View {
    let challenge: StageChallenge
    let visitorId: String
    @State private var now = Date()

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = challenge.remaining(at: now.timeIntervalSince1970)
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .trim(from: 0, to: remaining / max(challenge.terms.windowSeconds, 1))
                    .stroke(Color("PaletteOrange"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VisitorFace(visitorId: visitorId, side: 32)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("visit.challenge.hint")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.75))
                Text(verbatim: "\(challenge.taps)/\(challenge.terms.taps)")
                    .font(.system(size: 20, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
            }
            Text(verbatim: "\(Int(remaining.rounded(.up)))s")
                .font(.system(size: 13, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteOrange"))
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteOrange"), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("stage.chip.challenge")
        .accessibilityLabel(Text("visit.challenge.ax \(challenge.taps) \(challenge.terms.taps)"))
        .onReceive(timer) { now = $0 }
    }
}
```

- [ ] **Step 4: Las cartas del Vendedor**

`FisuEvolution/UI/Visitors/VendorCardsView.swift`:

```swift
import EconomyKit
import SwiftUI

/// Las cartas del Vendedor Ambulante (PLAN-v2 E4, Anexo A): cada boost con su
/// arte, su nombre, su efecto y su duración, y el video que lo regala. Una carta
/// por visita: elegir una cierra el trato.
struct VendorCardsView: View {
    let script: VisitorsConfig.Script
    let offer: VisitOffer
    @Environment(GameState.self) private var gameState

    private var cards: [VisitorsConfig.VendorCard] {
        guard case .vendor(let cards) = script.mechanic else { return [] }
        return cards.filter { offer.option(id: "card.\($0.id)") != nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.s8) {
            ForEach(cards) { card in
                GameCard(style: .normal) {
                    VStack(spacing: Tokens.s4) {
                        Group {
                            if let art = UIArt.image(card.iconKey) {
                                art.resizable().scaledToFit()
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundStyle(Color("PaletteOrange"))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                        Text(verbatim: VisitCopy.text(card.nameKey))
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                        if case let .modifier(effect, magnitude, seconds) = card.reward {
                            Text(verbatim: "\(VisitCopy.effectText(effect, magnitude: magnitude)) · \(VisitCopy.durationText(seconds))")
                                .font(Tokens.caption)
                                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        RewardedOfferButton(title: String(localized: "visit.vendor.take"),
                                            identifier: "visit.option.card.\(card.id)") {
                            gameState.chooseVisitOption("card.\(card.id)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
```

`VisitorPopupView.swift`: el bloque de opciones pasa a elegir entre las cartas y la lista:

```swift
                    if case .vendor = script.mechanic {
                        VendorCardsView(script: script, offer: offer)
                    } else {
                        VStack(spacing: Tokens.s8) {
                            ForEach(offer.options) { option in
                                optionButton(option, script: script, content: content)
                            }
                        }
                    }
```

y el detent pasa a `[.fraction(0.62), .large]` (tres cartas en un SE piden más alto).

- [ ] **Step 5: Los textos**

`Tools/v2/claves-pendientes/e4b-t5.json`:

```json
{
  "visit.challenge.hint": {"es": "¡Tocá a tus empleados!", "en": "Tap your workers!"},
  "visit.challenge.ax %lld %lld": {"es": "Reto: %1$lld de %2$lld toques", "en": "Challenge: %1$lld of %2$lld taps"},
  "visit.vendor.take": {"es": "Llevalo", "en": "Take it"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4b-t5.json` → `3 claves nuevas`.

- [ ] **Step 6: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/StageChallengeTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS; UI: `-only-testing:FisuEvolutionUITests/VisitorMechanicsUITests` → PASS (2). A mano:
`coach_reto` → aceptar → tocar empleados: el contador sube, a los 67 el Coach dice que ganaste y
queda el chip del ×2 en la barra; dejarlo vencer: "Casi… ¡la próxima sale!". El Vendedor en el SE
(las tres cartas sin cortar texto) y en el iPad. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/StageVisit.swift FisuEvolution/UI/Visitors/StageChips.swift \
  FisuEvolution/UI/Visitors/VendorCardsView.swift FisuEvolution/UI/Visitors/VisitorPopupView.swift \
  FisuEvolutionTests/StageChallengeTests.swift FisuEvolutionUITests/VisitorMechanicsUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t5.json, según la ola
git diff --cached --stat
git commit -m "feat(visitantes): el reto se juega con su contador y el Vendedor muestra sus tres cartas"
```

---

### Task 6: El Apagón y los Campeones se ven en el tablero

**Objetivo:** los dos eventos con escena propia. **Apagón**: un velo oscuro sobre el tablero y una
fila de velitas apagadas abajo; cada toque a un empleado prende una (el multiplicador sube
`candleStep`, de ×0,3 hasta ×1) y el velo se aclara en proporción; suena `sfx_blackout` al
empezar. **Campeones**: los empleados bailan (se balancean, cada uno a su tiempo) y cae confeti
de colores mientras dura. Con Reduce Motion, el velo y las velitas sí (son información), el baile
y el confeti no. La Liquidación tiene su escena en el precio tachado (T7).

**Files:**
- Create: `FisuEvolution/Scenes/Stage/StageEffects.swift`
- Modify: `FisuEvolution/Game/State/GameState+Events.swift` (`runningEventScenes`, `blackoutCandles`, `lightCandleIfBlackout`; el sonido)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`registerTap` → `lightCandleIfBlackout()`, una línea)
- Modify: `FisuEvolution/Game/Effects/ParticlePool.swift` (`.confetti`)
- Modify: `FisuEvolution/Audio/AudioManager.swift` (`.blackout`)
- Modify: `FisuEvolutionTests/AudioWiringTests.swift` (`declaredCases` suma `"blackout"`)
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (🔥: tres ganchos)
- Create: `FisuEvolutionTests/StageEffectsTests.swift`

**Interfaces:**
- Consumes: `EventPlanner.running/lightCandle`, `EventCatalog.Scene`, `candleStep` (E4a T4); T1
  (`StageController` como modelo de colaborador); `BoardScene.characterNodes` (privado: lo pasa la
  escena).
- Produces: `GameState.runningEventScenes(now:) -> Set<EventCatalog.Scene>`,
  `blackoutCandles(now:) -> (lit: Int, total: Int)?`, `lightCandleIfBlackout(now:) -> Bool`;
  `ParticlePool.EffectType.confetti`; `AudioManager.SFX.blackout`; `StageEffects` (`layer`,
  `attach(to:)`, `layout(sceneSize:bottomInset:)`, `update(delta:reduceMotion:units:)`,
  `veilAlpha`, `litCandles`, `isDancing`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/StageEffectsTests.swift`:

```swift
import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Los efectos de escena: Apagón y Campeones", .serialized)
@MainActor
struct StageEffectsTests {
    private func effects() async -> (GameState, StageEffects) {
        let gameState = await makeGameState()
        let effects = StageEffects(gameState: gameState)
        effects.attach(to: SKNode())
        effects.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118)
        return (gameState, effects)
    }

    @Test("el Apagón baja el velo y cada toque prende una velita, hasta ×1")
    func blackoutCandles() async throws {
        let (gameState, effects) = await effects()
        gameState.debugStartEvent(id: "apagon")
        #expect(gameState.runningEventScenes(now: Date().timeIntervalSince1970).contains(.blackout))
        let start = try #require(gameState.blackoutCandles(now: Date().timeIntervalSince1970))
        #expect(start.lit == 0)
        #expect(start.total == 10)
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        let dark = effects.veilAlpha
        #expect(dark > 0.5)
        #expect(gameState.lightCandleIfBlackout())
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        #expect(effects.litCandles == 1)
        #expect(effects.veilAlpha < dark)
        while gameState.lightCandleIfBlackout() {}
        #expect(gameState.blackoutCandles(now: Date().timeIntervalSince1970)?.lit == 10)
        let income = gameState.player?.run.activeModifiers.first { $0.sourceKey == "event.apagon" }
        #expect(income?.magnitude == 1)
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        #expect(effects.veilAlpha == 0)
    }

    @Test("sin apagón no hay velo ni velitas, y tocar no prende nada")
    func noBlackoutNoVeil() async {
        let (gameState, effects) = await effects()
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        #expect(effects.veilAlpha == 0)
        #expect(!gameState.lightCandleIfBlackout())
    }

    @Test("con Campeones bailan; con Reduce Motion, no; al terminar quedan derechos")
    func championsDance() async throws {
        let (gameState, effects) = await effects()
        let units = [SKNode(), SKNode(), SKNode()]
        gameState.debugStartEvent(id: "campeones")
        effects.update(delta: 0.2, reduceMotion: false, units: units)
        #expect(effects.isDancing)
        #expect(units.contains { $0.zRotation != 0 })
        effects.update(delta: 0.2, reduceMotion: true, units: units)
        #expect(!effects.isDancing)
        #expect(units.allSatisfy { $0.zRotation == 0 })
        effects.update(delta: 0.2, reduceMotion: false, units: units)
        gameState.player?.run.activeModifiers.removeAll { $0.sourceKey == "event.campeones" }
        effects.update(delta: 0.2, reduceMotion: false, units: units)
        #expect(units.allSatisfy { $0.zRotation == 0 })
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/StageEffectsTests`
→ no compila (`StageEffects`).

- [ ] **Step 3: El estado**

`GameState+Events.swift`, al final:

```swift
    // MARK: Las escenas (E4b T6)

    /// Las escenas de los eventos corriendo (Apagón, Campeones, Liquidación).
    func runningEventScenes(now: TimeInterval = Date().timeIntervalSince1970) -> Set<EventCatalog.Scene> {
        guard let content, let player else { return [] }
        return Set(EventPlanner.running(player.run.activeModifiers, catalog: content.events, now: now).compactMap(\.scene))
    }

    /// Las velitas del Apagón: cuántas hay prendidas y cuántas llevan a ×1.
    func blackoutCandles(now: TimeInterval = Date().timeIntervalSince1970) -> (lit: Int, total: Int)? {
        guard let content, let player,
              let event = content.events.events.first(where: { $0.scene == .blackout }),
              let step = event.candleStep, step > 0,
              let live = player.run.activeModifiers.first(where: {
                  $0.sourceKey == event.sourceKey && $0.effect == .incomeMultiplier && $0.isActive(at: now)
              })
        else { return nil }
        var base = live.magnitude
        for case let .modifier(effect, magnitude) in event.effects where effect == .incomeMultiplier {
            base = magnitude
        }
        // El épsilon salva el redondeo de 0,7 / 0,07 (= 10,000000000000002).
        let total = max(1, Int(((1 - base) / step - 1e-9).rounded(.up)))
        let lit = Int(((live.magnitude - base) / step).rounded())
        return (min(max(lit, 0), total), total)
    }

    /// Un toque a un empleado durante el Apagón prende una velita: el ingreso del
    /// evento sube `candleStep`, hasta ×1. Lo llama `registerTap`, que después
    /// refresca y guarda.
    @discardableResult
    func lightCandleIfBlackout(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard let content, var player,
              let event = content.events.events.first(where: { $0.scene == .blackout }),
              let lit = EventPlanner.lightCandle(player.run.activeModifiers, event: event, now: now)
        else { return false }
        player.run.activeModifiers = lit
        self.player = player
        effectsVersion += 1
        return true
    }
```

En `startEvent`, el `audio?.play(.event)` pasa a:

```swift
        audio?.play(event.scene == .blackout ? .blackout : .event)
```

`GameState+Actions.swift`, en `registerTap(cellIndex:)`, después de `noteStageTap()` (T2):

```swift
        lightCandleIfBlackout()
```

`AudioManager.swift`, en `enum SFX`, después de `daily`:

```swift
        /// El corte de luz del Apagón (E4b).
        case blackout = "sfx_blackout"
```

`AudioWiringTests.swift`: `declaredCases` suma `"blackout"` (la lista va a mano a propósito: el
test falla si el enum crece y el cableado no). Lo cablea el `audio?.play(…)` de `+Events`, que
el test lee con ternario y todo; el archivo ya está en `Resources/Audio/`.

`ParticlePool.swift`, en `EffectType`, `case confetti`; y en `makeEmitter`:

```swift
        case .confetti:
            emitter.numParticlesToEmit = 26
            emitter.particleBirthRate = 120
            emitter.particleLifetime = 2.2
            emitter.particleSpeed = 60
            emitter.particleSpeedRange = 40
            emitter.emissionAngle = -.pi / 2
            emitter.emissionAngleRange = .pi / 3
            emitter.yAcceleration = -140
            emitter.particleRotationRange = .pi * 2
            emitter.particleRotationSpeed = 3
            emitter.particleScale = 0.45
            emitter.particleScaleRange = 0.2
            emitter.particleAlphaSpeed = -0.35
            emitter.particleColorBlendFactor = 1
            emitter.particleColorSequence = SKKeyframeSequence(
                keyframeValues: [Palette.yellow, SKColor(named: "PalettePink") ?? .magenta,
                                 SKColor(named: "PaletteBlue") ?? .cyan, SKColor(named: "PaletteGreen") ?? .green],
                times: [0, 0.33, 0.66, 1]
            )
```

- [ ] **Step 4: `StageEffects`**

`FisuEvolution/Scenes/Stage/StageEffects.swift`:

```swift
import SpriteKit

/// Lo que los eventos le hacen a la escena (PLAN-v2 E4): el velo y las velitas
/// del Apagón, el baile y el confeti de los Campeones. Colaborador de
/// `BoardScene`, como `StageController`: todo por frame, probado sin vista.
@MainActor
final class StageEffects {
    /// Encima del tablero y DEBAJO del escenario (190): el presentador del Apagón
    /// se ve aunque esté oscuro.
    static let layerZ: CGFloat = 185
    static let maxVeilAlpha: CGFloat = 0.62
    static let confettiEvery: TimeInterval = 1.2
    /// El balanceo del baile: radianes y vaivenes por segundo.
    static let danceAngle: CGFloat = 0.12
    static let danceRate: Double = 1.6

    let layer = SKNode()
    private weak var gameState: GameState?
    private let veil = SKSpriteNode(color: .black, size: .zero)
    private var candles: [SKNode] = []
    private let particles = ParticlePool()
    private var sceneSize = CGSize(width: 393, height: 852)
    private var bottomInset: CGFloat = 118
    private var clock: TimeInterval = 0
    private var confettiClock: TimeInterval = 0
    private(set) var veilAlpha: CGFloat = 0
    private(set) var litCandles = 0
    private(set) var isDancing = false

    init(gameState: GameState) {
        self.gameState = gameState
        layer.zPosition = Self.layerZ
        layer.name = "stage.effects"
        veil.anchorPoint = .zero
        veil.alpha = 0
        layer.addChild(veil)
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat) {
        self.sceneSize = sceneSize
        self.bottomInset = bottomInset
        veil.size = sceneSize
        candles.forEach { $0.removeFromParent() }
        candles = []
    }

    /// `units`: los personajes del piso visible (los pasa la escena, que es su dueña).
    func update(delta: TimeInterval, reduceMotion: Bool, units: [SKNode]) {
        clock += delta
        let scenes = gameState?.runningEventScenes() ?? []
        updateBlackout(delta: delta, reduceMotion: reduceMotion)
        updateChampions(scenes.contains(.champions) && !reduceMotion, delta: delta, units: units)
    }

    // MARK: Apagón

    private func updateBlackout(delta: TimeInterval, reduceMotion: Bool) {
        guard let candlesState = gameState?.blackoutCandles() else {
            veilAlpha = 0
            veil.alpha = 0
            litCandles = 0
            candles.forEach { $0.isHidden = true }
            return
        }
        litCandles = candlesState.lit
        veilAlpha = Self.maxVeilAlpha * (1 - CGFloat(candlesState.lit) / CGFloat(candlesState.total))
        veil.alpha = veilAlpha
        if candles.count != candlesState.total { buildCandles(count: candlesState.total) }
        for (index, candle) in candles.enumerated() {
            candle.isHidden = false
            let flame = candle.childNode(withName: "flame")
            let isLit = index < candlesState.lit
            flame?.alpha = isLit ? 1 : 0
            if isLit, !reduceMotion {
                flame?.setScale(1 + 0.12 * CGFloat(sin(clock * 9 + Double(index))))
            }
        }
    }

    private func buildCandles(count: Int) {
        candles.forEach { $0.removeFromParent() }
        let spacing = sceneSize.width * 0.44 / CGFloat(max(count - 1, 1))
        let startX = sceneSize.width * 0.28
        candles = (0..<count).map { index in
            let candle = SKNode()
            candle.position = CGPoint(x: startX + CGFloat(index) * spacing, y: bottomInset + 6)
            let stick = SKShapeNode(rectOf: CGSize(width: 6, height: 16), cornerRadius: 2)
            stick.fillColor = Palette.cream
            stick.strokeColor = Palette.ink
            stick.lineWidth = 1
            stick.position = CGPoint(x: 0, y: 8)
            candle.addChild(stick)
            let flame = SKShapeNode(ellipseOf: CGSize(width: 8, height: 12))
            flame.name = "flame"
            flame.fillColor = Palette.yellow
            flame.strokeColor = SKColor(named: "PaletteOrange") ?? .orange
            flame.glowWidth = 4
            flame.position = CGPoint(x: 0, y: 22)
            flame.alpha = 0
            candle.addChild(flame)
            layer.addChild(candle)
            return candle
        }
    }

    // MARK: Campeones

    private func updateChampions(_ active: Bool, delta: TimeInterval, units: [SKNode]) {
        guard active else {
            if isDancing {
                units.forEach { $0.zRotation = 0 }
                isDancing = false
            }
            return
        }
        isDancing = true
        for (index, unit) in units.enumerated() {
            unit.zRotation = Self.danceAngle * CGFloat(sin(clock * 2 * .pi * Self.danceRate + Double(index) * 0.9))
        }
        confettiClock += delta
        if confettiClock >= Self.confettiEvery {
            confettiClock = 0
            let x = CGFloat.random(in: sceneSize.width * 0.15...sceneSize.width * 0.85)
            particles.emit(.confetti, at: CGPoint(x: x, y: sceneSize.height - 60), in: layer)
        }
    }
}
```

(Si el baile y el deambular pelean —el deambular no toca `zRotation` hoy—, el test de arriba lo
dice; `CharacterNodePool.recycle` ya pone `zRotation = 0` al reciclar.)

- [ ] **Step 5: Los tres ganchos de `BoardScene` (🔥)**

1. Junto a `stage`: `private lazy var stageEffects = StageEffects(gameState: gameState)`.
2. En `init`, después de `stage.attach(to: cameraOverlay)`: `stageEffects.attach(to: cameraOverlay)`.
3. En `layoutBoard()`, junto a `stage.layout(…)`:
   `stageEffects.layout(sceneSize: size, bottomInset: Self.bottomInset)`; y en `update(_:)`,
   después de `stage.update(…)`:

```swift
        stageEffects.update(delta: delta, reduceMotion: Self.prefersReducedMotion,
                            units: Array(characterNodes.values))
```

(`layout` se llama en cada `layoutBoard`; las velitas se reconstruyen solas en el próximo frame.)

- [ ] **Step 6: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/StageEffectsTests -only-testing:FisuEvolutionTests/AudioWiringTests -only-testing:FisuEvolutionTests/EventsRuntimeTests -only-testing:FisuEvolutionTests/CrowdDepthTests`
→ PASS. A mano (SE y iPad 13", Reduce Motion apagado y prendido): panel → "Disparar un evento" →
`apagon`: entra la Vecina, se corta la luz con su sonido, las diez velitas abajo; tocar
empleados las prende y aclara, el chip del evento sube de ×0,3 a ×1. `campeones`: el Conductor lo
anuncia, bailan y llueve confeti un minuto; con Reduce Motion, quietos. Con las partículas
apagadas en Ajustes, sin confeti. Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Scenes/Stage/StageEffects.swift FisuEvolution/Game/State/GameState+Events.swift \
  FisuEvolution/Game/State/GameState+Actions.swift FisuEvolution/Game/Effects/ParticlePool.swift \
  FisuEvolution/Audio/AudioManager.swift FisuEvolution/Scenes/BoardScene.swift \
  FisuEvolutionTests/StageEffectsTests.swift FisuEvolutionTests/AudioWiringTests.swift
git diff --cached --stat
git commit -m "feat(escena): el Apagón con sus velitas y los Campeones con baile y confeti"
```

---

### Task 7: La Liquidación se ve en el precio

**Objetivo:** un descuento temporal de contratar (la Liquidación, el Mate, la Factura A del
Demonio de ARCA) se **ve**: FisuJobs y el atajo de contratar muestran el precio de lista tachado
arriba del que se cobra. Y los descuentos apilados tienen piso: contratar nunca sale menos que
un cuarto del precio de lista (`ModifierMath.spawnCostStackFloor = 0,25`). Un recargo (Home
banking, Cepo, Hiperinflación) no tacha nada.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (`spawnCostStackFloor` en `factor`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/SpawnCostFloorTests.swift`
- Modify: `FisuEvolution/Game/State/GameState+Hiring.swift` (`listCostText`; `JobRow.listCostText`; `QuickHireOffer.listCostText`)
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`StrikePrice`; `PricePill.strikeText`)
- Modify: `FisuEvolution/UI/Jobs/FisuJobsView.swift` (el `PricePill` de la fila)
- Modify: `FisuEvolution/UI/HUD/QuickHireButton.swift` (el precio del atajo)
- Create: `FisuEvolutionTests/DiscountedPriceTests.swift`
- Create: `Tools/v2/claves-pendientes/e4b-t7.json`

**Interfaces:**
- Consumes: `ModifierMath.factor` (EK); `currentQuote(player:typeId:)`, `jobRows`,
  `computeQuickHireOffer()`, `QuickHireOffer` (**E3b T5–T6**: el rename de `BestHire` y sus campos);
  `debugStartEvent` (E4a T9).
- Produces: `ModifierMath.spawnCostStackFloor`; `GameState.listCostText(typeId:cost:player:) -> String?`;
  `JobRow.listCostText: String?`, `QuickHireOffer.listCostText: String?`; `StrikePrice(text:)`;
  `PricePill.strikeText: String?`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/SpawnCostFloorTests.swift`:

```swift
import Testing
@testable import EconomyKit

@Suite("El piso de los descuentos de contratar")
struct SpawnCostFloorTests {
    private func discount(_ magnitude: Double, _ source: String) -> ActiveModifier {
        ActiveModifier(effect: .spawnCostMultiplier, magnitude: magnitude, expiresAt: 100, sourceKey: source)
    }

    @Test("apilados, nunca bajan de un cuarto del precio de lista")
    func stackedDiscountsHaveAFloor() {
        let stacked = [discount(0.5, "event.liquidacion"), discount(0.7, "boost.mate"), discount(0.7, "visit.arca_factura")]
        #expect(ModifierMath.factor(stacked, effect: .spawnCostMultiplier, now: 0) == ModifierMath.spawnCostStackFloor)
    }

    @Test("arriba del piso, el producto de siempre")
    func aboveTheFloorNothingChanges() {
        let two = [discount(0.5, "event.liquidacion"), discount(0.7, "boost.mate")]
        #expect(abs(ModifierMath.factor(two, effect: .spawnCostMultiplier, now: 0) - 0.35) < 1e-12)
    }

    @Test("el piso es sólo de contratar: un ingreso puede bajar más")
    func onlyHiringHasAFloor() {
        let income = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.3, expiresAt: 100, sourceKey: "event.apagon"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.5, expiresAt: 100, sourceKey: "event.devaluacion"),
        ]
        #expect(abs(ModifierMath.factor(income, effect: .incomeMultiplier, now: 0) - 0.15) < 1e-12)
    }
}
```

`FisuEvolutionTests/DiscountedPriceTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El precio tachado de un descuento temporal", .serialized)
@MainActor
struct DiscountedPriceTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugMarkTypesSeen(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        return gameState
    }

    private func hirable(_ gameState: GameState) -> [JobRow] {
        gameState.jobRows.filter { $0.state == .hirable }
    }

    @Test("sin descuento no hay nada tachado")
    func noDiscountNoStrike() async throws {
        let gameState = await world()
        #expect(!hirable(gameState).isEmpty)
        #expect(hirable(gameState).allSatisfy { $0.listCostText == nil })
        #expect(gameState.quickHireOffer?.listCostText == nil)
    }

    @Test("con la Liquidación, FisuJobs y el atajo tachan el precio de lista")
    func theSaleStrikesTheListPrice() async throws {
        let gameState = await world()
        gameState.debugStartEvent(id: "liquidacion")
        gameState.refreshProjections()
        let row = try #require(hirable(gameState).first)
        let list = try #require(row.listCostText)
        #expect(list != row.costText)
        #expect(gameState.quickHireOffer?.listCostText != nil)
    }

    @Test("un recargo no tacha nada")
    func aSurchargeStrikesNothing() async throws {
        let gameState = await world()
        gameState.debugStartEvent(id: "home_banking")
        gameState.refreshProjections()
        #expect(hirable(gameState).allSatisfy { $0.listCostText == nil })
    }

    @Test("tres descuentos juntos cobran el piso: un cuarto de la lista")
    func stackedDiscountsChargeTheFloor() async throws {
        let gameState = await world()
        let player = try #require(gameState.player)
        let typeId = try #require(hirable(gameState).first?.id)
        let list = try #require(gameState.currentQuote(player: player, typeId: typeId)?.cost)
        gameState.debugStartEvent(id: "liquidacion")
        let now = Date().timeIntervalSince1970
        gameState.player?.run.activeModifiers += [
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.7, expiresAt: now + 60, sourceKey: "boost.mate"),
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.7, expiresAt: now + 60, sourceKey: "visit.arca_factura"),
        ]
        let charged = try #require(gameState.currentQuote(player: try #require(gameState.player), typeId: typeId)?.cost)
        #expect(abs(charged / list - ModifierMath.spawnCostStackFloor) < 0.01)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter SpawnCostFloorTests` → no compila
(`spawnCostStackFloor`). `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/DiscountedPriceTests` → no compila (`listCostText`).

- [ ] **Step 3: El piso**

`ActiveModifier.swift`, en `ModifierMath`:

```swift
    /// El piso de los descuentos de contratar apilados (Liquidación × Mate ×
    /// Factura A): contratar nunca sale menos que un cuarto del precio de lista.
    /// Sin él, tres descuentos juntos regalan la torre.
    public static let spawnCostStackFloor = 0.25

    /// Product of the magnitudes of every live modifier with the given effect.
    /// The hiring cost has a floor (`spawnCostStackFloor`).
    public static func factor(_ modifiers: [ActiveModifier], effect: ActiveModifier.Effect, now: TimeInterval) -> Double {
        let product = modifiers
            .filter { $0.effect == effect && $0.isActive(at: now) }
            .map(\.magnitude)
            .reduce(1, *)
        return effect == .spawnCostMultiplier ? max(product, spawnCostStackFloor) : product
    }
```

- [ ] **Step 4: El precio de lista**

`GameState+Hiring.swift`:

1. `JobRow` suma, después de `costText`:

```swift
    /// El precio sin los descuentos del momento, tachado arriba del que se cobra.
    /// `nil` sin descuento (un recargo no tacha nada).
    var listCostText: String? = nil
```

2. `QuickHireOffer` suma, después de `costText`, el mismo campo con el mismo docstring
   (`var listCostText: String? = nil`).
3. El cálculo:

```swift
    /// El precio de lista de un tipo: el mismo quote sin los descuentos temporales
    /// de contratar (los recargos se quedan: no son "el precio de lista"). `nil`
    /// si no hay descuento que mostrar.
    func listCostText(typeId: String, cost: Double, player: PlayerState) -> String? {
        var bare = player
        bare.run.activeModifiers.removeAll { $0.effect == .spawnCostMultiplier && $0.magnitude < 1 }
        guard bare.run.activeModifiers.count != player.run.activeModifiers.count,
              let list = currentQuote(player: bare, typeId: typeId)?.cost,
              list > cost * 1.005
        else { return nil }
        return CoinFormatter.cost(from: list)
    }
```

4. En `jobRows`, el `JobRow(…)` suma al final
   `listCostText: unseen ? nil : listCostText(typeId: type.id, cost: quote.cost, player: player)`
   (el `guard` de arriba corta en una comparación de conteo cuando no hay descuento: las 43 filas
   no pagan un segundo quote).
5. En `computeQuickHireOffer()`, el `QuickHireOffer(…)` suma al final
   `listCostText: listCostText(typeId: pick.type.id, cost: pick.cost, player: player)`.

- [ ] **Step 5: El tachado**

`GameArtComponents.swift`, después de `PricePill`:

```swift
// MARK: - StrikePrice

/// El precio de lista tachado, arriba del que se cobra (la Liquidación, el Mate,
/// la Factura A): el descuento se VE, no sólo se nota en la caja. Lo usan
/// `PricePill` y el atajo de contratar.
struct StrikePrice: View {
    let text: String
    var color: Color = Color("PaletteInk").opacity(0.6)

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, design: .rounded).weight(.bold))
            .monospacedDigit()
            .strikethrough(true, color: color)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityHidden(true)
    }
}
```

y `PricePill` suma `var strikeText: String?` (después de `accessibilityPurpose`, así los
llamadores de hoy no cambian); en el `label`, el `Text(verbatim: text)` pasa a ir en una columna
con el tachado arriba:

```swift
                VStack(spacing: -2) {
                    if let strikeText {
                        StrikePrice(text: strikeText,
                                    color: affordable ? .white.opacity(0.8) : Color("PaletteInk").opacity(0.6))
                    }
                    Text(verbatim: text)
                        .font(Tokens.body)
                        .monospacedDigit()
                        .foregroundStyle(affordable ? .white : Color("PaletteInk"))
                        .shadow(color: .black.opacity(affordable ? 0.45 : 0), radius: 1, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
```

y `spokenLabel` suma el precio de antes:

```swift
    private var spokenLabel: Text {
        let was = strikeText.map { Text(verbatim: ", ") + Text("price.ax.was \($0)") } ?? Text(verbatim: "")
        guard let accessibilityPurpose else { return Text(verbatim: spokenAmount) + was }
        return accessibilityPurpose + Text(verbatim: ", \(spokenAmount)") + was
    }
```

`FisuJobsView.swift`, en el `PricePill` de `rail`: `strikeText: row.listCostText,` después de
`accessibilityPurpose:`.

`QuickHireButton.swift`: donde el atajo dibuja `Text(verbatim: offer.costText)` (el layout que
dejó E3b T7), arriba del precio y en la misma columna:

```swift
                        if let list = offer.listCostText {
                            StrikePrice(text: list)
                        }
```

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e4b-t7.json`:

```json
{
  "price.ax.was %@": {"es": "antes %@", "en": "was %@"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4b-t7.json` → `1 claves nuevas`.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `SpawnCostFloorTests`, 3).
`/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/DiscountedPriceTests -only-testing:FisuEvolutionTests/QuickHireOfferTests -only-testing:FisuEvolutionTests/GameArtComponentsTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS. A mano: panel → "Disparar un evento" → `liquidacion` → FisuJobs (cada precio con su lista
tachada encima; en el SE el número no se corta) y el atajo. `Tools/v2/oraculo.sh rapido` → `VERDE`
(el `pacing-sim` no cambia: no modela descuentos apilados).

- [ ] **Step 8: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/SpawnCostFloorTests.swift \
  FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolution/UI/Art/GameArtComponents.swift \
  FisuEvolution/UI/Jobs/FisuJobsView.swift FisuEvolution/UI/HUD/QuickHireButton.swift \
  FisuEvolutionTests/DiscountedPriceTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t7.json, según la ola
git diff --cached --stat
git commit -m "feat(eventos): la Liquidación tacha el precio de lista y los descuentos apilados tienen piso"
```

---

### Task 8: El Álbum de especiales

**Objetivo:** los especiales conseguidos dejan de ser un decorado en el piso donde cayeron y
pasan a un **Álbum** en la Oficina central: una quinta tarjeta de ancho completo
(`menu.card.specials`) debajo de las cuatro —que no se tocan— abre una grilla con los diez: los
que tenés con su retrato, su nombre, su chiste y lo que te dan mientras los tengas
("+3 % de ingresos"); los que faltan, en silueta con desde qué tier pueden caer. La carta del
drop avisa que el especial queda en el Álbum, y una lección lo enseña la primera vez.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Specials.swift` (`AlbumEntry`, `albumEntries`, `albumOwnedCount`)
- Modify: `FisuEvolution/Managers/EffectDescriptor.swift` (`amount(forSpecial:magnitude:)`)
- Create: `FisuEvolution/UI/Menu/SpecialsAlbumView.swift`
- Modify: `FisuEvolution/UI/Menu/MenuView.swift` (`Destination.specials` y la tarjeta)
- Modify: `FisuEvolution/UI/Popups/SpecialDropView.swift` (la línea del Álbum)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (lección `.album`)
- Create: `FisuEvolutionTests/SpecialsAlbumTests.swift`, `FisuEvolutionUITests/SpecialsAlbumUITests.swift`
- Modify: `FisuEvolutionTests/TutorialTipsTests.swift`
- Create: `Tools/v2/claves-pendientes/e4b-t8.json`

**Interfaces:**
- Consumes: `SpecialsConfig`, `player.meta.ownedSpecials`, `EffectFormatter`, `VisitorArt.image`
  (T1); `MenuView` con `NavigationStack(path:)` (**E3b T3**); `PanelTitleBanner`, `GameCard`,
  `panelSheet`, `ArtCloseButton`.
- Produces: `struct AlbumEntry` (`id`, `owned`, `nameKey`, `flavorKey`, `effectText`, `minTier`);
  `GameState.albumEntries`, `albumOwnedCount`, `static albumEffectText(_:)`;
  `EffectDescriptor.amount(forSpecial:magnitude:)`; `SpecialsAlbumView(close:)`;
  `GameState.TutorialLesson.album`.
- Identificadores: `menu.card.specials`, `album.progress`, `album.card.<id del especial>.owned` /
  `.locked`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/SpecialsAlbumTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El Álbum de especiales")
@MainActor
struct SpecialsAlbumTests {
    @Test("están los diez, en el orden del catálogo; sin conseguir, sin efecto")
    func allTenInCatalogOrder() async throws {
        let gameState = await makeGameState()
        let catalog = try #require(gameState.content?.specials.specials.map(\.id))
        #expect(gameState.albumEntries.map(\.id) == catalog)
        #expect(gameState.albumEntries.allSatisfy { !$0.owned && $0.effectText.isEmpty })
        #expect(gameState.albumOwnedCount == 0)
    }

    @Test("uno conseguido muestra lo que da, con el formateador de siempre")
    func anOwnedSpecialShowsItsEffect() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.ownedSpecials.append("sp_cryptobro")
        let entry = try #require(gameState.albumEntries.first { $0.id == "sp_cryptobro" })
        #expect(entry.owned)
        #expect(entry.effectText == String(localized: "album.effect.income \("+3%")"))
        #expect(gameState.albumOwnedCount == 1)
    }

    @Test("el pasivo de un especial se lee como bonus o descuento, nunca como factor")
    func specialAmounts() {
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .incomeMultiplier, magnitude: 1.1)) == "+10%")
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .offlineEfficiencyBonus, magnitude: 0.05)) == "+5%")
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .critChanceBonus, magnitude: 0.02)) == "+2%")
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .spawnDiscount, magnitude: 0.05)) == "−5%")
    }
}
```

`TutorialTipsTests.swift`:

```swift
    @Test("el primer especial enseña el Álbum, y abrir la Oficina la cumple")
    func theFirstSpecialTeachesTheAlbum() async throws {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .album { gameState.markLessonDone(lesson) }
        gameState.player?.meta.ownedSpecials.append("sp_cryptobro")
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .album)
        gameState.tutorialTipHandled(opening: .menu)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.album.defaultsKey))
    }
```

`FisuEvolutionUITests/SpecialsAlbumUITests.swift`:

```swift
import XCTest

/// El especial que cae queda en el Álbum de la Oficina central (PLAN-v2 E4),
/// con lo que te da. El drop sale de `--uitest-special` (es RNG sobre merges).
final class SpecialsAlbumUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElEspecialConseguidoApareceEnElAlbum() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-special"]
        app.launch()
        let claim = app.buttons["special.drop.claim"]
        XCTAssertTrue(claim.waitForExistence(timeout: 12))
        claim.tap()
        XCTAssertTrue(claim.waitForNonExistence(timeout: 8))

        let tab = app.buttons["hud.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: tab)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed)
        tab.tap()

        let albumCard = app.buttons["menu.card.specials"]
        XCTAssertTrue(albumCard.waitForExistence(timeout: 10), "la Oficina tiene la tarjeta del Álbum")
        XCTAssertTrue(app.buttons["menu.card.orgchart"].exists, "y las cuatro de siempre")
        albumCard.tap()

        let owned = app.descendants(matching: .any)["album.card.sp_cryptobro.owned"]
        XCTAssertTrue(owned.waitForExistence(timeout: 8), "el que cayó está en el Álbum")
        XCTAssertTrue(app.descendants(matching: .any)["album.card.sp_lizard.locked"].exists, "y los que faltan, en silueta")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "álbum: uno conseguido y nueve por conseguir"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
```

(`descendants(matching: .any)`: con el `combine`, la tarjeta puede salir en el árbol como
`staticText` o como `other` según el runtime.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/SpecialsAlbumTests -only-testing:FisuEvolutionTests/TutorialTipsTests`
→ no compila (`albumEntries`, `.album`).

- [ ] **Step 3: El modelo**

`EffectDescriptor.swift`, en `enum EffectDescriptor`, después de `amount(forBoost:)`:

```swift
    /// Especiales: lo que da tenerlo (el Álbum). `incomeMultiplier` es un factor
    /// (1,03 = +3 %); los otros tres ya son la fracción que se suma o se descuenta.
    static func amount(forSpecial effectType: SpecialsConfig.PassiveEffect.Kind, magnitude: Double) -> EffectAmount {
        switch effectType {
        case .incomeMultiplier: EffectAmount(unit: .percentBonus, value: magnitude - 1, isCapped: false)
        case .offlineEfficiencyBonus, .critChanceBonus: EffectAmount(unit: .percentBonus, value: magnitude, isCapped: false)
        case .spawnDiscount: EffectAmount(unit: .percentDiscount, value: magnitude, isCapped: false)
        }
    }
```

`FisuEvolution/Game/State/GameState+Specials.swift`:

```swift
import EconomyKit
import Foundation

/// Una figurita del Álbum de especiales (PLAN-v2 E4).
struct AlbumEntry: Identifiable, Equatable {
    let id: String
    let owned: Bool
    let nameKey: String
    let flavorKey: String
    /// "+3 % de ingresos": lo que da mientras lo tenés. Vacío si falta.
    let effectText: String
    /// Desde qué tier puede caer: la pista de los que faltan.
    let minTier: Int
}

extension GameState {
    /// Los diez, en el orden del catálogo. Computada: el Álbum es una pantalla
    /// del menú y casi nunca está abierta.
    var albumEntries: [AlbumEntry] {
        guard let content, let player else { return [] }
        let owned = Set(player.meta.ownedSpecials)
        return content.specials.specials.map { special in
            let has = owned.contains(special.id)
            return AlbumEntry(id: special.id, owned: has, nameKey: special.displayNameKey,
                              flavorKey: special.flavorTextKey,
                              effectText: has ? Self.albumEffectText(special.passiveEffect) : "",
                              minTier: special.minTier)
        }
    }

    var albumOwnedCount: Int {
        albumEntries.filter(\.owned).count
    }

    static func albumEffectText(_ effect: SpecialsConfig.PassiveEffect) -> String {
        let amount = EffectFormatter.text(EffectDescriptor.amount(forSpecial: effect.type, magnitude: effect.magnitude))
        switch effect.type {
        case .incomeMultiplier: return String(localized: "album.effect.income \(amount)")
        case .offlineEfficiencyBonus: return String(localized: "album.effect.offline \(amount)")
        case .critChanceBonus: return String(localized: "album.effect.crit \(amount)")
        case .spawnDiscount: return String(localized: "album.effect.discount \(amount)")
        }
    }
}
```

- [ ] **Step 4: La pantalla**

`FisuEvolution/UI/Menu/SpecialsAlbumView.swift`:

```swift
import SwiftUI

/// **Álbum de especiales** (PLAN-v2 E4): los diez personajes raros, los que
/// tenés con su retrato y lo que te dan, los que faltan en silueta. Se empuja
/// desde la Oficina central como las otras cuatro pantallas del menú.
struct SpecialsAlbumView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra la HOJA entera (ver `MenuView`: `dismiss` acá desapilaría).
    let close: () -> Void

    private let columns = [GridItem(.flexible(), spacing: Tokens.s12), GridItem(.flexible(), spacing: Tokens.s12)]

    var body: some View {
        let entries = gameState.albumEntries
        ScrollView {
            VStack(spacing: Tokens.s12) {
                Text("album.progress \(entries.filter(\.owned).count) \(entries.count)")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                    .accessibilityIdentifier("album.progress")
                // `VStack` de filas y no `LazyVGrid`: son diez tarjetas contadas y
                // tienen que existir en el árbol de accesibilidad sin scrollear
                // (la misma razón que la grilla de `MenuView`).
                Grid(horizontalSpacing: Tokens.s12, verticalSpacing: Tokens.s12) {
                    ForEach(Array(stride(from: 0, to: entries.count, by: 2)), id: \.self) { index in
                        GridRow {
                            card(entries[index])
                            if index + 1 < entries.count { card(entries[index + 1]) } else { Color.clear }
                        }
                    }
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
        }
        .panelSheet { PanelTitleBanner(titleKey: "album.title") }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
    }

    private func card(_ entry: AlbumEntry) -> some View {
        GameCard(style: entry.owned ? .highlighted(Color("PaletteYellow")) : .normal) {
            VStack(spacing: Tokens.s4) {
                portrait(entry)
                    .frame(width: 84, height: 84)
                Text(entry.owned ? LocalizedStringKey(entry.nameKey) : "album.unknown")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if entry.owned {
                    Text(verbatim: entry.effectText)
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteGreen").deepened(0.3))
                    Text(LocalizedStringKey(entry.flavorKey))
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("album.locked \(entry.minTier)")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        // El estado va en el id y no en un valor hablado: VoiceOver ya dice el
        // nombre o "Por descubrir", y un "owned" crudo se leería en inglés.
        .accessibilityIdentifier("album.card.\(entry.id).\(entry.owned ? "owned" : "locked")")
    }

    @ViewBuilder
    private func portrait(_ entry: AlbumEntry) -> some View {
        if let manifest = gameState.content?.manifest,
           let image = VisitorArt.image(for: entry.id, pose: .canonical, manifest: manifest) {
            image.resizable().scaledToFit()
                // Los que faltan, en silueta: se sabe que existen, no cómo son.
                .colorMultiply(entry.owned ? .white : .black)
                .opacity(entry.owned ? 1 : 0.35)
        } else {
            Image(systemName: entry.owned ? "star.circle.fill" : "questionmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(entry.owned ? Color("PaletteYellow") : Color("PaletteInk").opacity(0.3))
        }
    }
}
```

(`Color.deepened(_:)` es el de `GameArtComponents.swift:55`.)

`MenuView.swift` (sobre lo que dejó E3b T3: `NavigationStack(path:)`, el paginador):

1. `Destination` suma `case specials`.
2. Debajo del segundo `HStack` de tarjetas, sola y de ancho completo:

```swift
                    // El Álbum: quinta tarjeta, sola y de ancho completo, para no
                    // tocar la grilla de las cuatro (PLAN-v2 E4).
                    card(.specials, "menu.card.specials", identifier: "menu.card.specials") {
                        AnyView(Image(systemName: "rectangle.stack.badge.person.crop.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(Color("PaletteBrown")))
                    }
```

3. En `navigationDestination`, `case .specials: SpecialsAlbumView(close: { dismiss() })`.
4. En `artKey(for:)`, `case .specials: "ui_menu_specials"` (el PNG no existe: cae al glifo).

`SpecialDropView.swift`, debajo del texto del chiste, adentro de la `GameCard`:

```swift
                        Text("special.drop.album_hint")
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk").opacity(0.55))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
```

- [ ] **Step 5: La lección**

`GameState+TutorialTips.swift`: `.album` va **al final** de `TutorialLesson` (no apura: el Álbum
no se va a ningún lado):

```swift
        /// El primer especial conseguido: vive en el Álbum de la Oficina central.
        case album
```

con `anchorTarget` → `.menu`, `destinationScreen` → `.menu`, `textKey` → `"tutorial.tip.album"` e
`isEligible` →

```swift
        case .album:
            !(player?.meta.ownedSpecials.isEmpty ?? true)
```

(Una partida vieja con especiales la ve una vez: es justo el aviso de que se mudaron del piso al
Álbum.)

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e4b-t8.json`:

```json
{
  "menu.card.specials": {"es": "Álbum", "en": "Album"},
  "album.title": {"es": "Álbum de especiales", "en": "Specials Album"},
  "album.progress %lld %lld": {"es": "Tenés %1$lld de %2$lld", "en": "You have %1$lld of %2$lld"},
  "album.unknown": {"es": "Por descubrir", "en": "Yet to find"},
  "album.locked %lld": {"es": "Puede caer desde el tier %lld", "en": "Can drop from tier %lld"},
  "album.effect.income %@": {"es": "%@ de ingresos", "en": "%@ income"},
  "album.effect.offline %@": {"es": "%@ de ganancia offline", "en": "%@ offline earnings"},
  "album.effect.crit %@": {"es": "%@ de golpe crítico", "en": "%@ critical hit chance"},
  "album.effect.discount %@": {"es": "%@ al contratar", "en": "%@ on hiring"},
  "special.drop.album_hint": {"es": "Desde ahora lo tenés en el Álbum de la Oficina central.", "en": "From now on you'll find them in the Head Office Album."},
  "tutorial.tip.album": {"es": "Tus especiales viven en el Álbum de la Oficina central.", "en": "Your specials live in the Head Office Album."}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e4b-t8.json` → `11 claves nuevas`.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/SpecialsAlbumTests -only-testing:FisuEvolutionTests/TutorialTipsTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/MenuSessionTests`
→ PASS; UI: `-only-testing:FisuEvolutionUITests/SpecialsAlbumUITests -only-testing:FisuEvolutionUITests/MenuUITests -only-testing:FisuEvolutionUITests/MenuPagerUITests`
→ PASS. A mano (SE, iPad 13", claro y oscuro): la Oficina con sus cuatro tarjetas intactas y el
Álbum abajo; el Álbum con uno conseguido y nueve en silueta. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Specials.swift FisuEvolution/Managers/EffectDescriptor.swift \
  FisuEvolution/UI/Menu/SpecialsAlbumView.swift FisuEvolution/UI/Menu/MenuView.swift \
  FisuEvolution/UI/Popups/SpecialDropView.swift FisuEvolution/Game/State/GameState+TutorialTips.swift \
  FisuEvolutionTests/SpecialsAlbumTests.swift FisuEvolutionTests/TutorialTipsTests.swift \
  FisuEvolutionUITests/SpecialsAlbumUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t8.json, según la ola
git diff --cached --stat
git commit -m "feat(album): los especiales conseguidos viven en el Álbum de la Oficina central"
```

---

### Task 9: Los especiales salen del tablero

**Objetivo:** con el Álbum andando (T8), los especiales dejan de dibujarse anclados al piso donde
cayeron: se borran el render, el mantener-apretado que reabría su carta, su profundidad, la
proyección `visibleFloorSpecials`, `presentSpecialInfo`/`specialInfo` y la hoja del recap. Ya no
se escribe `meta.specialAnchors` (queda en el save sólo para decodificar: no hay bump de schema).
El drop sigue igual: su carta, por la cola.

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (🔥: se van `renderAnchoredSpecials`, `specialID(at:)`, la rama del long-press, `specialZ`, `specialNodePrefix`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (🔥: se va `specialInfo`)
- Modify: `FisuEvolution/App/RootView.swift` (🔥: la hoja del recap y su término de `coversBoard`)
- Modify: `FisuEvolution/Game/State/GameState+Tower.swift` (se van `visibleFloorSpecials`, `presentSpecialInfo`, `dismissSpecialInfo`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (el término `specialInfo == nil`, **E1 T9**)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`rollSpecialDrop` no ancla)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugDropFirstSpecial` no ancla)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (se va `debug.special.info`)
- Modify: `FisuEvolution/UI/Popups/SpecialDropView.swift` (se va `isRecap`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (sólo el docstring de `specialAnchors`)
- Modify: `FisuEvolutionTests/CrowdDepthTests.swift`, `FisuEvolutionTests/GameLoopWiringTests.swift`, `FisuEvolutionUITests/TutorialUITests.swift`
- Create: `FisuEvolutionTests/SpecialsOffTheBoardTests.swift`
- Create: `Tools/v2/claves-pendientes/e4b-t9.quitar`

**Interfaces:**
- Consumes: T8 (el Álbum ya muestra lo que el recap mostraba).
- Produces: nada nuevo; `PlayerState.meta.specialAnchors` queda sin escritores.

- [ ] **Step 1: El test, en rojo**

`FisuEvolutionTests/SpecialsOffTheBoardTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los especiales viven en el Álbum, no en el piso")
@MainActor
struct SpecialsOffTheBoardTests {
    @Test("el drop ya no ancla al especial a un piso")
    func theDropDoesNotAnchor() async throws {
        let gameState = await makeGameState()
        gameState.debugDropFirstSpecial()
        let special = try #require(gameState.content?.specials.specials.first)
        #expect(gameState.player?.meta.ownedSpecials.contains(special.id) == true)
        #expect(gameState.player?.meta.specialAnchors.isEmpty == true)
        #expect(gameState.specialDrop?.id == special.id, "la carta del drop sigue saliendo")
    }

    @Test("un save viejo con anclas decodifica y las ignora")
    func oldAnchorsStillDecode() async throws {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "anchors-\(UUID().uuidString).json")
        )
        var seeded = PlayerState.newGame(startTypeId: "homeless", startFloorId: "alley",
                                         offlineEfficiencyBase: 0.35, critChanceBase: 0,
                                         now: Date().timeIntervalSince1970)
        seeded.meta.ownedSpecials = ["sp_arbolito"]
        seeded.meta.specialAnchors = ["sp_arbolito": "alley"]
        await repository.save(seeded)
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        #expect(gameState.player?.meta.ownedSpecials == ["sp_arbolito"])
        #expect(gameState.albumOwnedCount == 1)
    }
}
```

Run: Receta R con `-only-testing:FisuEvolutionTests/SpecialsOffTheBoardTests` → FAIL
(`specialAnchors` no está vacío).

- [ ] **Step 2: Lo que se va del estado**

- `GameState+Actions.swift`, `rollSpecialDrop()`: se borra el bloque "Anclaje visual: el special
  queda en el piso donde cayó (⚠️5)" (`if let floorId = visibleFloorDef?.id { … }`).
- `GameState+Debug.swift`, `debugDropFirstSpecial()`: se borran `let floorId = visibleFloorDef?.id`
  del `guard` y la línea `player.meta.specialAnchors[special.id] = floorId`; el docstring pasa a
  "El primer especial del catálogo, caído ya mismo: deja la carta del drop abierta (vía la cola,
  como el drop real) y al especial en el Álbum".
- `GameState+Tower.swift`: se borran `visibleFloorSpecials`, `presentSpecialInfo(id:)` y
  `dismissSpecialInfo()` con sus docstrings.
- `GameState.swift` (🔥): se borra `var specialInfo` con su docstring.
- `GameState+BoardChanges.swift`: en `boardIsVisibleForChanges`, se borra `&& specialInfo == nil`.
- `PlayerState.swift`: el docstring de `specialAnchors` pasa a "Sin escritores desde E4b: los
  especiales viven en el Álbum. Se decodifica para no romper saves viejos; se borra con el
  próximo bump de schema."

- [ ] **Step 3: Lo que se va de la escena (🔥 `BoardScene.swift`)**

- En `layoutBoard()`, la línea `renderAnchoredSpecials(content: content)`.
- `specialID(at:)` y `renderAnchoredSpecials(content:)` enteros, con sus docstrings (en la forma
  que les dejó E3a T10).
- En `touchesBegan`, dentro del `guard let node = characterNode(at:) else { … }`, el bloque
  "Mantener apretado un special reabre su carta" (`if let specialID = specialID(at: point) { … }`);
  quedan `emptyTouchStart = point` y el `return`.
- `static func specialZ(band:rows:cellSize:)` con su docstring, y `specialNodePrefix`.
- El comentario de `init` que nombra "specials por debajo de la multitud" pasa a no nombrarlos.

- [ ] **Step 4: La UI, el panel y los tests viejos**

- `RootView.swift` (🔥): se borran `.sheet(item: $gameState.specialInfo) { … }` con su comentario
  y el `.onChange(of: gameState.specialInfo)`; en `coversBoard`, el término
  `gameState.specialInfo != nil`.
- `SpecialDropView.swift`: se va `var isRecap`; el título es siempre `"special.drop.title"`, el
  botón `"special.drop.claim"` y el cierre `gameState.dismissSpecialDrop()`. El docstring pierde
  el párrafo del RECAP.
- `DebugPanelView.swift`: se borra la `Section("Specials")` de `debug.special.info` con su
  comentario.
- `CrowdDepthTests.swift`: se borra `specialsSitBetweenTheFloorAndTheCrowd` (con lo que le sumó
  E3a T10).
- `GameLoopWiringTests.swift`: se borra `anchoredSpecialsAreScopedToTheirFloor` (lo reemplaza
  `SpecialsOffTheBoardTests.oldAnchorsStillDecode`).
- `TutorialUITests.swift`: `testElSpecialMuestraSuSkinYSuCartaSePuedeReabrir` pasa a
  `testElSpecialMuestraSuSkin`: queda la mitad de la carta del drop (hasta `claimGone`), se va la
  reapertura por `debug.special.info` (la consulta del beneficio es del Álbum:
  `SpecialsAlbumUITests`). El docstring lo dice.

`Tools/v2/claves-pendientes/e4b-t9.quitar` (las claves del recap, sin usos):

```
special.info.ok
special.info.title
```

Run: `Tools/v2/catalogo.py quitar $(cat Tools/v2/claves-pendientes/e4b-t9.quitar)` → `2 claves borradas`.

- [ ] **Step 5: Verde, a mano y oráculo**

Run: `grep -rn "specialInfo\|visibleFloorSpecials\|presentSpecialInfo\|dismissSpecialInfo\|renderAnchoredSpecials\|specialZ\|specialNodePrefix\|isRecap\|debug.special.info\|special.info" FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
→ sin resultados. `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/SpecialsOffTheBoardTests -only-testing:FisuEvolutionTests/CrowdDepthTests -only-testing:FisuEvolutionTests/GameLoopWiringTests -only-testing:FisuEvolutionTests/BoardChangeProducersTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS; UI: `-only-testing:FisuEvolutionUITests/TutorialUITests -only-testing:FisuEvolutionUITests/SpecialsAlbumUITests`
→ PASS. A mano: un save con especiales anclados (el de la sesión de prueba) abre sin nadie
decorando el piso y con los especiales en el Álbum. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Scenes/BoardScene.swift FisuEvolution/Game/State/GameState.swift FisuEvolution/App/RootView.swift \
  FisuEvolution/Game/State/GameState+Tower.swift FisuEvolution/Game/State/GameState+BoardChanges.swift \
  FisuEvolution/Game/State/GameState+Actions.swift FisuEvolution/Game/State/GameState+Debug.swift \
  FisuEvolution/UI/DebugPanelView.swift FisuEvolution/UI/Popups/SpecialDropView.swift \
  Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift \
  FisuEvolutionTests/CrowdDepthTests.swift FisuEvolutionTests/GameLoopWiringTests.swift \
  FisuEvolutionUITests/TutorialUITests.swift FisuEvolutionTests/SpecialsOffTheBoardTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e4b-t9.quitar, según la ola
git diff --cached --stat
git commit -m "feat(album): los especiales dejan el tablero; el recap del mantener-apretado se va con ellos"
```

---

### Task 10: Cierre de E4

**Objetivo:** la verificación de punta a punta de la épica entera (E4a + E4b) y la documentación.
La hace el controlador.

- [ ] **Step 1: Oráculo completo**

Run: `Tools/v2/oraculo.sh completo`.
Expected: `VERDE`, con las suites nuevas de E4b en la salida: `StageLayoutTests`,
`StageControllerTests`, `VisitorArtTests`, `VisitorRuntimeTests`, `LoopsManifestTests`,
`EventPresenterTests`, `StageChallengeTests`, `StageEffectsTests`, `SpawnCostFloorTests`,
`DiscountedPriceTests`, `SpecialsAlbumTests`, `SpecialsOffTheBoardTests`; y las de UI
`VisitorUITests`, `EventChipUITests`, `VisitorMechanicsUITests`, `SpecialsAlbumUITests`.
`rojos-declarados.txt` no cambió por E4.

- [ ] **Step 2: Los escenarios a mano (SE y iPad 13", claro/oscuro, Reduce Motion sí/no)**

1. Con `--uitest-engagement` y los relojes del dato bajados en un build local (no se commitea):
   a los 10 min de juego entra el primer visitante; el Vendedor cada ~3 min por su carril; a los
   15 min el primer evento, con su presentador.
2. Un visitante esperando + abrir FisuJobs: la paciencia se congela; cerrar: sigue.
3. Un evento que sale con un visitante en escena: espera a que se vaya y entra antes que el
   próximo.
4. `comisario_arresto` → "que se lo lleve": la salida del arrestado se ve en el tablero (E1) al
   cerrar el popup.
5. `apagon` + tocar empleados hasta ×1; `campeones` con y sin Reduce Motion; `liquidacion` con
   el Mate encima (el piso de 0,25 en el precio).
6. Un save con especiales anclados: el piso vacío de decorado, el Álbum con lo suyo, la lección
   del Álbum una vez.
7. Home en medio de la caminata de un visitante y volver: sigue donde estaba; matar la app con
   un visitante esperando: al volver, nadie en escena (no se persiste) y el reloj del carril
   donde estaba.

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e4.md` (o el de E4a, ampliado): la tabla por tarea de E4b con su
   commit, las capturas del reporte y el porqué de cada default de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: "E4 — Visitantes, eventos v2 y Álbum": el escenario (`StageController` +
     `stageVisit` de una sola entrada, la entrada como turno `.visitorEncounter`), los chips
     bajo el HUD, el popup con loop o foto, los eventos con presentador y chip con cara, el
     Apagón/Campeones/Liquidación, el Álbum; el banner de eventos no existe más.
   - **§5**: los defaults de las dudas que el dueño no cambió.
   - **§7**: las trampas nuevas — "el escenario es de una sola entrada: un evento espera al
     visitante y ningún visitante entra con un evento esperando"; "todo lo que se mueve en el
     escenario va por frame, nunca `SKAction`: así se prueba sin vista"; "una hoja nueva va con
     `fisuSheet()` y su `onChange` escribe `coversBoard`, si no la paciencia de los visitantes
     corre con la hoja abierta"; "`ActionPill(verbatim:)` para títulos del dato";
     "`debugStartEvent` aplica en el acto, `debugPresentEvent` pasa por el presentador";
     "`meta.specialAnchors` no tiene escritores: se borra en el próximo bump"; las que aparezcan.
   - **§9**: los dos planes y la sesión.
3. `Docs/PLAN-v2.md`: E4 marcada hecha, con los desvíos (las dudas que el dueño confirmó).

---

## Lo que E4 le deja a otras épicas

- **E5 (paquetes, ruleta, colchón):** sumar `.package` y `.wheelSpin` a
  `GameState.grantableRewardKinds` y su caso en `grant` (E4a T8) despierta solos los cinco guiones
  que hoy esperan (acto, bolsón, asado, novio, favor), el del Conductor y los eventos Lluvia y
  Piquete (el `packageRateMultiplier` ya existe). El `PickupNode` del paquete cuelga del escenario
  como `StageEffects` (un colaborador más de `BoardScene`, por frame). Las celebraciones que PLAN-v2
  pone en E4 y no se usan acá (`.packageOpening`) son de E5.
- **E6 (ofertas, auto-tap, lugares extra):** `.autoTap`, `.nextOfflineMultiplier`,
  `.nextDailyMultiplier` y `.extraSlots` en `grantableRewardKinds`; `RewardedOfferButton` es el
  botón de video de sus ofertas; `.offer` como kind de la cola si la oferta interrumpe.
- **E7b (intersticiales):** los intersticiales siguen con `isSafeMomentForInterstitial`; E7b los
  pasa a `isCalmMoment` (que ya mira el escenario, las hojas y `uiCoversBoard`, incluidos los
  popups de E4b).
- **E8 (arte y video):** el contrato está puesto y probado por los dos lados: `npcs` en el manifest
  (`<id>`, `_talk`, `_action`, `_face`; `VisitorArt` y `VisitorArtTests`), `loops_manifest.json`
  `portraits[<id>]` (`LoopsManifestTests`); `process_dropbox.py` tiene que crear la sección
  `npcs` en `assets_manifest.json` al integrar el primer visitante. La cinemática del arresto
  engancha en `chooseVisitOption` cuando la opción es `.release` del guion `comisario_arresto` (las
  dos primeras veces, `seenCinematics`); `.cinematic` como kind de la cola es suyo.
- **E9 (tutorial v2):** tres lecciones nuevas con el sistema de hoy (`.visitor`, `.eventChip`,
  `.album`) para migrar a su currículo; la primera visita puede alojarse en una
  `TutorialInlineCard` junto al chip.
- **E2b (calibración):** los relojes del escenario (`patienceSeconds`, `presenterTalkSeconds`) y el
  piso de descuentos (`spawnCostStackFloor`) son perillas; la plata de los retos sale de
  `coinsSecondsScale` como la del resto de los guiones.
- **E10 (store / QA):** las capturas del App Store pueden mostrar un visitante en escena con
  `--uitest-visitor=<guion>` y un evento con `--uitest-event=<id>`.

## Para el dueño / dudas

Las de E4a siguen en pie. Éstas son de E4b; **ninguna frena**: la ejecución sigue con el default.

1. **De las cuatro celebraciones nuevas que PLAN-v2 pone en E4, E4b usa una**
   (`.visitorEncounter`, la entrada). Lo que pasa después —esperar a que lo toquen— no ocupa la
   cola: si la ocupara, nada más podría pasar mientras un visitante espera 30 s.
   **Default:** `.packageOpening` es de E5, `.cinematic` de E8 y `.offer` de E6.
2. **El visitante se mueve por frame, no con `SKAction`.** Cuesta unas líneas más y deja probar
   entrada, espera, toque y salida sin vista (`StageControllerTests`). **Default:** así.
3. **`LoopingPortraitView` va aparte de `ChestCinematicPlayer`** y no lo generaliza (PLAN-v2 dice
   "generaliza"): el cofre tiene su preroll y su congelón (HANDOFF §7) y un loop no tiene
   ninguno; tocar el cofre para esto es riesgo sin premio. **Default:** aparte.
4. **Un visitante sobrevive al background pero no a matar la app:** `stageVisit` vive en memoria;
   el reloj de su carril sí está en el save. **Default:** así (persistir una visita a medio
   cerrar es un estado más del save para un caso raro).
5. **El precio tachado sale con cualquier descuento temporal de contratar**, no sólo con la
   Liquidación (también el Mate, la Factura A, el Influencer). **Default:** todos; un recargo no
   tacha.
6. **El piso de los descuentos apilados es 0,25** (contratar nunca sale menos de un cuarto de la
   lista) y vive en código (`ModifierMath.spawnCostStackFloor`), no en el JSON. **Default:** 0,25;
   E2b lo mueve si el simulador lo pide.
7. **El Vendedor da una carta por visita.** **Default:** una (elegir cierra el trato); viene cada
   ~3 min.
8. **Pagar a un visitante con el corralito puesto no se puede** (la fianza, la multa, el cambio);
   cobrar sí. **Default:** así: "tu plata está, pero no la podés tocar".
9. **El reto ganado con "×2 con video" ofrece OTRA tanda igual** por video (el mismo visitante, su
   chip, su popup); si no lo querés, se va igual. **Default:** así.
10. **Los presentadores hablan 4 s** (`presenterTalkSeconds`) y se van; la frase completa queda en
    el popup del chip. **Default:** 4 s.
11. **El evento espera al escenario y le gana al próximo visitante.** **Default:** así; un evento
    nunca interrumpe a un visitante a mitad de trato.
12. **El escenario va a z 190** (delante de la multitud, detrás del reveal) y el velo del Apagón a
    185 (detrás del presentador). **Default:** así; el reveal de un ascenso tapa al visitante.
13. **La silueta del Álbum es la canónica teñida de negro**, y los que faltan dicen desde qué tier
    pueden caer. **Default:** así (no espoilea el chiste; sí que existe).

