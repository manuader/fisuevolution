# E8e — Los videos aprobados que no se usan, al juego; las pintas con video cuando exista el clip · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Pedido del dueño (2026-10-10, `DUENO.md`), con prioridad:** "agregá todo al juego… aplicá todo e
integralo correctamente al juego".

**Goal:** que **las 135 piezas** de `loops_manifest.json` tengan quien las pida. Hoy (verificado el
2026-10-10 sobre `73f5494`) ningún Swift consume `talking` (18), `visitorActions` (8), `events` (8),
`shopIcons` (10) ni `objects` (4); el Álbum dibuja el PNG aunque los 10 especiales tienen clip en
`characters`; la ficha anima sólo la pinta base. Además, **las pintas (skins) ganan su video cuando
el clip exista** (`characters["<tipo>__<pinta>"]`): sin clip de la pinta, la ficha y la revelación
quedan **quietas**, nunca la base animada con la pinta equivocada.

**Architecture:** no se crea ningún componente de video: todo usa lo de E8d
(`AnimatedArtView`, `LoopingVideoNode`, `VideoPlayerPool` con tope 3 y roles
`popup > background > icon`, `VideoPlaybackPolicy`, `ArtPacks` por `odrTag`). Lo nuevo es
**un resolvedor puro** (`ArtClips`: qué clip le corresponde a cada lugar, con sus caídas) y **el
contrato manifest ↔ contenido** pineado por tests (cada clave del manifest es de algo que existe en
el juego y cada clip tiene quien lo pida). El único cambio a un componente de E8d es `.once` en
`LoopingVideoNode` (T6, revisión opus). Las grillas (tienda, Álbum) montan **una sola**
`AnimatedArtView`: la de la tarjeta enfocada; las demás son póster puro (el pool deja vivo al más
nuevo de cada rol, que no es necesariamente el que se mira).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · AVFoundation (sólo T6) · Swift Testing · XCUITest · XcodeGen · Python 3
(`Tools/asset-pipeline/scripts/video_assets.py`, `process_dropbox.py`).

**Fuente:** la spec del dueño `Docs/superpowers/specs/2026-10-08-v2-e8-animaciones-design.md`
(manda: tabla de inventario, "un vivo por rol", "los íconos animan sólo el centrado", "el tablero no
usa video para los personajes"); el plan `2026-10-08-v2-e8d-animaciones-swift.md` ("El manifest de la
segunda tanda", "Lo que E8d le deja a otras épicas", dudas 3, 8 y 11); `tasks.md` §3, §4.1 #8 y §5
E4b/E5b/E6a/E6b/E8d. El código en `73f5494`.

**Rama de la épica:** `v2/e8e-videos`, desde `version-2`. Cada tarea sale de su punta en un worktree
propio (manual, `.claude/worktrees.nosync/v2i-e8e-tN`) y el controlador integra de a una.

**Fuera de este plan:** generar clips nuevos (las pintas no tienen ninguno todavía: `video/personajes/`
del generador no tiene ningún `__`); eso es de la sesión del dueño y entra por manifest, sin Swift,
con T7 hecha. El chip del evento y los chips del escenario **no** animan (miden 40 pt y competirían
con la tienda por el rol `icon`). Los personajes del tablero siguen sin video (spec).

## Las referencias, verificadas contra el árbol (`73f5494`)

| Lo que usa el plan | Dónde está hoy | Qué significa para E8e |
|---|---|---|
| `ArtClip` | `Managers/LoopsManifest.swift`: ya tiene `.talking`, `.visitorAction`, `.event`, `.shopIcon`, `.object`, `.character` | **no faltan casos**: T1 suma el resolvedor y el contrato, no casos nuevos |
| `talking` | 18 claves = `npc_*` (8) + `sp_*` (10), `vis_<id>_talk.mov`, pack `anim-visitantes` | el globo **del escenario** (T2) |
| `visitorActions` | 8 claves `npc_*`, `vis_<id>_action.mov`, `anim-visitantes` | el visitante que espera sin globo (T2) |
| `events` | 8 claves, todas ids de `events.json` (`home_banking` es el master `cayo_mercado_pago`); los otros 10 eventos no tienen clip | el popup del evento (T3) |
| `shopIcons` | 10 claves `ui_oro_*` (256²); `oro_shop.json` tiene 13 ítems con `iconKey` `ui_shop_*`: **los nombres no coinciden** | T1 fija la tabla ítem → clip; T4 la usa |
| `objects` | `colchon_espera`, `colchon_abre`, `paquete_espera`, `paquete_abre`, en el paquete base | T5 (popup del colchón, de E5b T2) y T6 (el tablero, de E5b T3) |
| `characters` | 53 claves (43 tipos + 10 `sp_*`), `odrTag` `anim-piso-<n>` / `anim-especiales`; ninguna `<tipo>__<pinta>` | Álbum (T7) y pintas (T8) |
| Pinta | `skins.json`: 260 entradas; el `id` **no es único** (`pijama` existe para cada tipo de la familia): la pinta es el par `(characterType, id)` | la clave del clip es `"<tipo>__<pinta>"`, la misma convención que los PNG del generador (`administrativo__dinosaurio.png`) |
| `AnimatedArtView` | `UI/Art/Video/AnimatedArtView.swift`: `init(clip:role:playback:poster:)`, `.loop` / `.once(onEnd:)`, pide el pack ODR mientras está en pantalla | todo lugar SwiftUI |
| `LoopingVideoNode` | `Scenes/Nodes/LoopingVideoNode.swift`: `init(clip:poster:size:role:manifest:pool:packs:)`, `setVisible`, `stop`; **sólo loop** | escenario (T2); T6 le suma `.once` |
| `VideoPlayerPool` | `maxLive = 3`; el más nuevo de cada rol, `popup > background > icon` | una sola vista por rol en grillas (T4, T7) |
| Popup del visitante | `UI/Visitors/VisitorPopupView.swift:21` ya anima `.portrait(visitor.id)` (E4b T3) | **no se toca** (duda 1) |
| Escenario | `Scenes/Stage/StageController.swift`: `wait()` cambia la textura a `.talk` con globo y a `.canonical` sin él (`:103-105`); `VisitorNode` es un `SKSpriteNode` | T2 cuelga un `LoopingVideoNode` del actor |
| Popup del evento | `UI/Events/EventPopupView.swift`: cara del presentador (76 pt) + globo; sin ilustración del evento | T3 suma la ilustración |
| Póster del evento | **no existe**: `assets_manifest.json` no tiene arte de eventos; los cuadros están en el generador: `automatic-image-generation/projects/fisu-evolution-v2/video/eventos/frames/<master>.png` (8) | T3 Step 1 los integra como `ui_event_<id>` |
| Tienda de ORO | `UI/Store/OroShopView.swift`: `OroShopShelves` (lista vertical dentro del `ScrollView` de `StoreView`), `OroShopItemRow.icon` 48 pt con `UIArt.image(row.item.iconKey)` | T4 |
| Álbum | `UI/Menu/SpecialsAlbumView.swift:80-93`: `Grid` de 10 tarjetas, retrato 84 pt de `VisitorArt.image(.canonical)` = el PNG de `manifest.characters[sp_*]` (el mismo póster que `SpecialDropView`) | T7, `.character(sp_*)` |
| Ficha | `UI/Popups/CharacterSheetView.swift`: `TabView(.page)` con un `CharacterPortrait` por opción; `animated: option.skin == nil` (`:109`); `CharacterPortrait` anima `.character(type.id)` (`:333`) | T8. ⚠️ el `.page` monta las vecinas: con más de una opción animada, el pool deja viva la **más nueva**, no la seleccionada |
| Revelación | `Scenes/BoardScene.swift:1540-1545` `mountRevealVideo` (`.character(type.id)`) y `:1714-1720` `prefetchNextRevealPack` 🔥 | T8 (dos líneas) |
| Pinta activa | `GameState+Store.swift:349` `activeSkinID(forCharacterType:)` | T8 |
| `odr_tag` / `validate_id` | `video_assets.py:583-592` / `:281-309`; `CHARACTER_ID` (`:253`) **rechaza `__`** y `floor_of_character()` no conoce `homeless__pijama` | T8 Step 5 |
| Sonidos sin cablear | `AudioWiringTests.pendingWiring` (`:30-35`): `visitorArrive`, `talkBlip` (dueño E4b T3, ya ✅), `shopShimmer` (E6a T8, ya ✅), los del colchón (E5b T2) y del paquete (E5b T3) | T2 cablea los del visitante; T4 el brillo; T5/T6 sólo sincronizan con E5b |
| El barrido de lugares | `AnimatedPlacesTests` **no existe**: lo crea E8d T15 (⏳) con `pendingPlaces` | T9 lo deja con `pendingPlaces` vacío |

## Global Constraints

Las de E8d valen enteras (`Docs/superpowers/plans/2026-10-08-v2-e8d-animaciones-swift.md`, "Global
Constraints"). Las que más pesan acá:

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`. Nada de `Timer` para
  lógica de juego.
- **El póster primero, siempre.** Toda vista o nodo con video dibuja su PNG de siempre y queda así si
  no hay clip, si el pack ODR no bajó, si el pool no la pone viva o con Reduce Motion / bajo consumo /
  térmica / `--uitest*`. **El póster es el primer cuadro del clip** (duda 3 de E8d): si no lo es, se
  integra el cuadro como PNG (T3) o se anota el salto para G3.
- **Sin clip, quieto: nunca otro clip "parecido".** Una pinta sin video es estática (no la base
  animada); un evento sin clip no muestra ilustración nueva; un visitante sin `talking` no usa el
  retrato del popup en el escenario.
- **Una sola `AnimatedArtView` por grilla**: la de la tarjeta enfocada. Las demás dibujan el póster
  directo (sin `AnimatedArtView`, sin lease, sin pedir pack).
- **El `body` de una vista no crea objetos con efectos**; el manifest llega por
  `@Environment(\.loopsManifest)` o `LoopsManifest.main`.
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis). La capa de video sigue siendo `art.video` (hoja), y bajo `--uitest*` no existe: los UI
  tests de siempre ven el póster y no cambian.
- **Ids del manifest** (trampa del 25, `tasks.md` §4.1 #8): renombrar una clave exige renombrar el
  `.mov` y los ids del pipeline. **Este plan no renombra ninguna**: traduce con tablas (T1).
- **Strings nuevos**: ninguno previsto. Si una tarea necesita uno, `Tools/v2/claves-pendientes/e8e-tN.json`.
- **Un dueño por archivo 🔥** (`BoardScene.swift`, `RootView.swift`, `GameState.swift`, `project.yml`,
  catálogo). Una tarea que necesita un 🔥 ajeno para con `NEEDS_CONTEXT`; las dos líneas de
  `BoardScene` de T8 las puede aplicar el controlador al integrar (precedente E12 T11).
- **Prohibido `find /`** y toda búsqueda fuera del worktree. El protocolo de agente vive en
  `/Users/manuader/Desktop/projects/FisuEvolution/.claude/worktrees/version-2/.superpowers/sdd/v2-agente-protocolo.md`.
- **Commits en español, estilo de la casa** (`feat(video): …`, `test(video): …`), **SIN
  `Co-Authored-By`**. Staging selectivo y `git diff --cached --stat` antes de cada commit. Un comando
  git por llamada.
- **Al cerrar cada tarea** (el controlador, nunca un subagente): integración, ledger, journal y
  `tasks.md`. Ningún subagente toca `Docs/`, `handoffs/`, el journal ni `tasks.md`.

## Verificación (vale para toda tarea)

```bash
# App: EconomyKit entero + build + esas clases de FisuEvolutionTests
Tools/v2/oraculo.sh tarea <Clases>

# Pipeline (T3, T8)
PY=/Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/.venv/bin/python
(cd Tools/asset-pipeline && "$PY" -m unittest discover -s tests)   # sin salteados
```

- Los UI tests que una tarea toca se corren aislados con la **Receta R** de
  `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md`.
- **Capturas con `--uitest-video`** (SE y 16 Pro) donde la tarea lo pide: el clip se mueve, el marco no
  cambia de tamaño, el alfa deja ver el fondo (no un cuadrado negro) y no hay salto visible
  póster → video.
- ⚠️ "0 tests" con éxito no prueba nada: la salida nombra las clases. Ante un rojo en masa, `uptime`
  y `ps aux | grep '[x]codebuild'` antes de culpar al código.
- ⚠️ El simulador decodifica HEVC con alfa por software: fps y memoria se miden en el dispositivo (T9).

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Managers/ArtClips.swift` | **nuevo** — el resolvedor puro: pinta, visitante, evento, ícono de la tienda | 1 |
| `FisuEvolutionTests/ArtClipsTests.swift` | **nuevo** | 1 |
| `FisuEvolutionTests/LoopsManifestTests.swift` | el contrato manifest ↔ contenido | 1 |
| `FisuEvolution/Scenes/Stage/StageController.swift`, `Scenes/Stage/VisitorNode.swift` | el visitante del escenario habla y actúa | 2 |
| `FisuEvolution/Game/State/GameState+Stage.swift` (tibio), `FisuEvolutionTests/AudioWiringTests.swift`, `FisuEvolutionTests/StageControllerTests.swift` | `visitorArrive` y `talkBlip`; tests del escenario | 2 |
| `FisuEvolution/Resources/ui.atlas/ui_event_*.png`, `Resources/Data/assets_manifest.json` | los 8 pósters de evento | 3 |
| `FisuEvolution/UI/Events/EventPopupView.swift`, `FisuEvolutionTests/EventArtTests.swift` (nuevo) | la ilustración del evento, animada | 3 |
| `FisuEvolution/UI/Store/OroShopView.swift`, `FisuEvolutionTests/ShopIconFocusTests.swift` (nuevo) | el ícono enfocado anima; brillo; prefetch | 4 |
| `FisuEvolution/UI/Prizes/MattressPopupView.swift` (de E5b T2) | el colchón espera y se abre | 5 |
| `FisuEvolution/Scenes/Nodes/LoopingVideoNode.swift`, `FisuEvolutionTests/LoopingVideoNodeTests.swift` | `.once` en SpriteKit | 6 |
| `FisuEvolution/Scenes/Prizes/PickupNode.swift`, `PackageOpeningPlayer.swift` (de E5b T3) | la caja espera y se abre | 6 |
| `FisuEvolution/UI/Menu/SpecialsAlbumView.swift`, `FisuEvolutionTests/SpecialsAlbumTests.swift` | el Álbum con la tarjeta enfocada animada | 7 |
| `FisuEvolution/UI/Popups/CharacterSheetView.swift`, `Scenes/BoardScene.swift` 🔥 (dos líneas), `Tools/asset-pipeline/scripts/video_assets.py`, `Tools/asset-pipeline/tests/test_video_assets.py` | las pintas con video | 8 |
| `FisuEvolutionTests/AnimatedPlacesTests.swift` (de E8d T15) | `pendingPlaces` vacío | 9 |

## Orden, olas y paralelismo

| T | Qué | 🔥 / tibios | Depende de | Revisión · modelo |
|---|---|---|---|---|
| 1 | `ArtClips` + contrato manifest ↔ contenido | — (nuevos) + `LoopsManifestTests` | — | ninguna · sonnet |
| 2 | El visitante habla y actúa en el escenario | `StageController`, `VisitorNode`; `+Stage` (tibio), `AudioWiringTests` | T1 | controlador lee el diff + capturas · sonnet |
| 3 | La ilustración del evento, animada | `EventPopupView`; `ui.atlas`, `assets_manifest.json` | T1 | ninguna (capturas) · sonnet |
| 4 | El ícono enfocado de la Tienda de ORO | `OroShopView`; `AudioWiringTests` | T1 | ninguna (capturas) · sonnet |
| 5 | El colchón espera y se abre | `MattressPopupView` | **E5b T2** | ninguna (capturas) · sonnet |
| 6 | `.once` en `LoopingVideoNode`; la caja espera y se abre | `LoopingVideoNode`; `PickupNode`, `PackageOpeningPlayer` | **E5b T3** | **opus** (AVFoundation) · sonnet |
| 7 | El Álbum, con la tarjeta enfocada animada | `SpecialsAlbumView` | — | ninguna (capturas) · sonnet |
| 8 | Las pintas con video (ficha, revelación, pipeline) | `CharacterSheetView`; 🔥 `BoardScene` (dos líneas); `video_assets.py` | T1; ventana de `BoardScene` | ninguna · sonnet |
| 9 | Cierre (controlador) | `Docs/` | T1–T8; **E8d T15** | — |

```
Ola A (ya)                         T1 ║ T7            (T1 es chica: T2/T3/T4/T8 salen detrás)
Ola B                              T2 ║ T3 ║ T4      (archivos disjuntos)
Tras T1 + ventana de BoardScene    T8              (o el controlador aplica sus dos líneas)
Tras E5b T2                        T5
Tras E5b T3                        T6
Cierre                             T9 (tras E8d T15)
```

**Choques con la cola (`tasks.md` §4.2):**

1. **E5b T2** (en vuelo, relevo 29): crea `MattressPopupView` y toca `StageChips`, `RootView`,
   `GameState`, catálogo. E8e no toca ninguno de esos salvo `MattressPopupView` en T5, que espera.
2. **E5b T3** (⛔): crea `PickupNode`/`PackageOpeningPlayer` y toca `BoardScene` 🔥. T6 va después;
   T8 compite por la ventana de `BoardScene` (dos líneas: va antes o después, nunca en la misma ola).
3. **E6b T4 / T5 / T7** (`+Store`, `PlayerState`, `BoardScene`, la tienda): T8 lee
   `activeSkinID` (no lo cambia); T4 no ∥ con la tarea que toque `OroShopView` (E6b T7 suma los
   lugares extra a la tienda: es quien estrena `ui_oro_extra_slots`).
4. **E6a T12** (las ofertas se ven): si toca `OroShopView` o `StoreView`, T4 va antes o después.
5. **E7b-b** (la columna, T3/T7): toca `StageChips` y `RewardedOfferButton`, no el escenario ni el
   popup del evento. Sin choque con T2/T3; T9 mira en el `completo` que la columna no tape al
   visitante animado.
6. **E9a T7** toca `CharacterSheetView`: T8 no ∥ con E9a T7.
7. **E8d T15** (⏳): crea `AnimatedPlacesTests`. Si corre antes que E8e, su `pendingPlaces` nombra
   las tareas de E8e como dueñas; T9 lo vacía.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift` |
| contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift` |
| el manifest real | `try LoopsManifest.load(from: .main)` | `LoopsManifest.swift` |
| un manifest de fixture | `LoopsManifestTests.fixture(floors:)` y el `init` con secciones por defecto | `LoopsManifestTests.swift:19-34`, `LoopsManifest.swift` |
| un pool con política forzada | `VideoPlayerPool(policy:)` | `VideoPlayerPoolTests.swift` |
| un escenario con `SKNode` pelado y deltas | el patrón de `StageControllerTests` | `FisuEvolutionTests/StageControllerTests.swift` |
| el parser de `audio?.play(...)` | `AudioWiringTests.playArguments`/`enumCases` | `AudioWiringTests.swift` |
| las `.caf` de E8d T6 | `AudioManager.SFX.visitorArrive`, `.talkBlip`, `.shopShimmer`, `talkPitch(for:)` | `Audio/AudioManager.swift` |

---

### Task 1: `ArtClips` y el contrato manifest ↔ contenido

**Objetivo:** un solo lugar decide qué clip le toca a cada cosa del juego, con sus caídas, y los
tests garantizan que cada clave del manifest es de algo que existe. Sin cambiar vistas.

**Files:**
- Create: `FisuEvolution/Managers/ArtClips.swift`
- Create: `FisuEvolutionTests/ArtClipsTests.swift`
- Modify: `FisuEvolutionTests/LoopsManifestTests.swift`
- `/opt/homebrew/bin/xcodegen generate` (archivos nuevos)

**Interfaces:**
- Consumes: `LoopsManifest`, `ArtClip` (E8d T1); `GameContent` (`visitors`, `events`, `oroShop`,
  `skins`, `tiers`, `specials`).
- Produces:

```swift
/// Qué clip le toca a cada lugar. `nil` = el lugar se queda con su póster: nunca otro clip "parecido".
enum ArtClips {
    /// La clave de una pinta en `characters`: `"<tipo>__<pinta>"` (el id de pinta no es único).
    static func skinKey(type: String, skin: String) -> String

    /// Sin pinta, el cuerpo entero base; con pinta, SÓLO el de esa pinta. Una pinta sin clip → nil.
    static func character(type: String, skin: String?, in manifest: LoopsManifest) -> ArtClip?

    /// El visitante del escenario: con globo, `.talking`; esperando sin globo, `.visitorAction`.
    static func stageVisitor(_ id: String, talking: Bool, in manifest: LoopsManifest) -> ArtClip?

    static func event(_ id: String, in manifest: LoopsManifest) -> ArtClip?

    /// Ítem de `oro_shop.json` → clave de `shopIcons` (los nombres no coinciden: tabla fija).
    static let shopIconKeys: [String: String]
    /// Clips de la tienda que todavía no tienen ítem, con la tarea que lo estrena.
    static let pendingShopIcons: [String: String]
    static func shopIcon(item: String, in manifest: LoopsManifest) -> ArtClip?
}
```

La tabla (duda 4):

| Ítem (`oro_shop.json`) | Clip (`shopIcons`) |
|---|---|
| `income_x2`, `income_x3` | `ui_oro_income_boost` |
| `auto_tap` | `ui_oro_autotap` |
| `package_rain` | `ui_oro_package_rain` |
| `time_jump_1h`, `time_jump_4h` | `ui_oro_time_skip` |
| `offline_x3` | `ui_oro_offline_boost` |
| `daily_x3` | `ui_oro_daily_boost` |
| `merge_all` | `ui_oro_merge_all` |
| `better_supplier` | `ui_oro_better_supplier` |
| `wheel_spins` | `ui_oro_extra_spins` |
| `skip_cooldowns`, `skin_chest` | — (póster) |
| (sin ítem todavía) | `ui_oro_extra_slots` → `pendingShopIcons`, dueño **E6b T7** |

**Oráculo:** `Tools/v2/oraculo.sh tarea ArtClipsTests LoopsManifestTests`

- [ ] **Step 1: RED — `ArtClipsTests`** (manifest de fixture con el `init` de secciones):
  - `baseWithoutSkin`: `character(type: "homeless", skin: nil)` con `characters["homeless"]` → `.character("homeless")`.
  - `skinWithClip`: con `characters["homeless__pijama"]` → `.character("homeless__pijama")`.
  - `skinWithoutClipIsStill`: con `characters["homeless"]` y **sin** `homeless__pijama` →
    `character(type: "homeless", skin: "pijama") == nil` (**no** la base).
  - `noBaseNoClip`: tipo sin entrada y sin pinta → `nil`.
  - `stageVisitorTalksWithBubble` / `stageVisitorActsWithoutBubble`: `npc_vecina` con las dos
    secciones → `.talking` / `.visitorAction`; `sp_coach` sin `visitorActions` y sin globo → `nil`
    (no cae a `.portrait`).
  - `shopIconMapsItems`: `income_x3` → `.shopIcon("ui_oro_income_boost")`; `skin_chest` → `nil`;
    ítem mapeado cuyo clip falta en el manifest → `nil`.
  - `eventClipOnlyWhenPresent`: `aguinaldo` → `.event("aguinaldo")`; `apagon` → `nil`.
- [ ] **Step 2: RED — el contrato, en `LoopsManifestTests`** (manifest real + contenido real):
  - `talkingBelongsToVisitorsOrSpecials`: cada clave de `talking` es un visitante de `visitors.json`
    o un especial de `specials.json`.
  - `actionsBelongToVisitors`: cada clave de `visitorActions` es un visitante.
  - `eventsBelongToEvents`: cada clave de `events` es un id de `events.json`.
  - `shopIconsHaveAnOwner`: cada clave de `shopIcons` está en los valores de `shopIconKeys` o en
    `pendingShopIcons` (no en los dos); cada valor de `shopIconKeys` es clave del manifest; cada
    clave de `shopIconKeys` es un ítem de `oro_shop.json`.
  - `charactersBelongToTypesSpecialsOrSkins`: cada clave de `characters` es un tipo de `tiers.json`,
    un especial, o `<tipo>__<pinta>` con una entrada de `skins.json` de ese `characterType` y ese `id`.
  - `objectsAreTheFourOfE5`: `objects` es exactamente `{colchon_espera, colchon_abre, paquete_espera,
    paquete_abre}`.
- [ ] **Step 3: GREEN** — `ArtClips.swift` con lo de arriba (funciones puras, sin `@MainActor`:
  sólo leen `LoopsManifest.entry(for:)`).
- [ ] **Step 4:** oráculo. Commit: `feat(video): un solo lugar decide qué clip le toca a cada cosa`.

**No se hace:** cablear vistas; renombrar claves del manifest o ids del contenido.

---

### Task 2: El visitante habla y actúa en el escenario

**Objetivo:** el visitante parado en el escenario se mueve: **con el globo abierto, su clip
`talking`; esperando sin globo, su clip `visitorAction`** (spec: "mientras el globo de texto está
abierto" / "el momento del visitante"). Entrando y saliendo, la textura de siempre (camina con el
`walkBob` por código). Suenan `sfx_visitor_arrive` al llegar y `sfx_talk_blip` (tono por personaje)
al abrirse cada globo: los dos están en `pendingWiring` desde E8d T6 con dueño E4b T3, que cerró sin
cablearlos.

**Files:**
- Modify: `FisuEvolution/Scenes/Stage/StageController.swift`, `FisuEvolution/Scenes/Stage/VisitorNode.swift`
- Modify: `FisuEvolution/Game/State/GameState+Stage.swift` (tibio: el `audio?.play` tiene que vivir en
  `Game/State` para el parser de `AudioWiringTests`)
- Modify: `FisuEvolutionTests/StageControllerTests.swift`, `FisuEvolutionTests/AudioWiringTests.swift`

**Interfaces:**
- Consumes: T1 (`ArtClips.stageVisitor`); `LoopingVideoNode` (E8d T4: `setVisible`, `stop`);
  `VisitorArt.texture(for:pose:)`; `AudioManager.talkPitch(for:)`.
- Produces: `VisitorNode.showClip(_ clip: ArtClip?, poster: SKTexture)` (monta, cambia o saca el
  `LoopingVideoNode` hijo; mismo clip → no hace nada); `VisitorNode.videoClip: ArtClip?` (para tests);
  `StageController` lo llama desde `wait` y lo apaga en `enter`/`leave`/`clear`.
- Rol del pool: **`.popup`** (duda 2). Póster del nodo: la textura de la pose del clip
  (`_talk` / `_action`), que es su primer cuadro.

**Oráculo:** `Tools/v2/oraculo.sh tarea StageControllerTests AudioWiringTests AudioManagerTests` +
Receta R `VisitorUITests` y `VisitorMechanicsUITests` (póster bajo `--uitest*`: nada cambia) +
**captura con `--uitest-video`** en el SE y el 16 Pro (con globo y sin globo).

- [ ] **Step 1: RED — `StageControllerTests`** (el patrón del archivo, manifest de fixture inyectado):
  - `waitingWithBubbleShowsTalking`: visita en `.waiting` con `bubble` no vacío →
    `actor.videoClip == .talking(actorId)`.
  - `waitingWithoutBubbleShowsAction`: sin globo → `.visitorAction(actorId)`.
  - `noClipNoVideoNode`: actor sin entradas → `videoClip == nil` y ningún `LoopingVideoNode` hijo.
  - `enteringAndLeavingHaveNoVideo`: en `.entering` y `.leaving` → `nil` (y el nodo anterior recibió
    `stop()`: se ve en que `videoClip` vuelve a `nil`).
  - `sameClipIsNotRemounted`: dos `update` seguidos con globo → el mismo `LoopingVideoNode`
    (`ObjectIdentifier` igual).
  - `clearStopsVideo`: `stageVisit = nil` → el actor sale y no queda lease vivo en un
    `VideoPlayerPool(policy:)` de prueba (`liveCount == 0`).
- [ ] **Step 2: GREEN** — `VisitorNode.showClip`; `StageController.wait` calcula
  `ArtClips.stageVisitor(visit.actorId, talking:, in: manifest)` y llama `showClip` (el manifest y el
  pool se inyectan con default `.main`/`.shared`, como `LoopingVideoNode`). `setVisible(true)` al
  montar; `stop()` al sacar.
- [ ] **Step 3: RED → GREEN — sonidos.** En `AudioWiringTests`: `visitorArrive` y `talkBlip` pasan de
  `pendingWiring` a `declaredCases`. En `GameState+Stage.swift`: `audio?.play(.visitorArrive, gain:
  .action)` cuando una visita de visitante pasa a `.entering` (una vez por visita), y
  `audio?.play(.talkBlip, gain: .action, pitch: AudioManager.talkPitch(for: actorId))` cuando el globo
  cambia a un texto no vacío (una vez por globo, no por frame; duda 11 de E8d se simplifica: no hay
  máquina de escribir).
- [ ] **Step 4:** si la pausa de la escena (`isPaused`) no llega al `LoopingVideoNode` del actor (mirar
  cómo lo resolvió `FloorNode` en E8d T8) y hace falta una línea en `BoardScene` 🔥: **parar con
  `NEEDS_CONTEXT`** y dejar la línea escrita en el reporte; la aplica el controlador.
- [ ] **Step 5:** oráculo + UI + capturas. Commit: `feat(video): el visitante del escenario habla y actúa`.

**No se hace:** el popup del visitante (sigue con `.portrait`, duda 1); los chips; el presentador de
un evento en el escenario usa el mismo camino (`actorId` puede ser `sp_*`: tiene `talking`, no
`visitorAction`).

---

### Task 3: La ilustración del evento, animada

**Objetivo:** el popup del evento muestra la ilustración del evento en movimiento (spec: "Eventos
(ilustración + loop) | popup … del evento") arriba de la fila del presentador. Los 8 eventos con clip
ganan la ilustración; los otros 10 quedan como hoy.

**Files:**
- Create: `FisuEvolution/Resources/ui.atlas/ui_event_<id>.png` (8) y sus entradas en
  `FisuEvolution/Resources/Data/assets_manifest.json` (`ui`)
- Modify: `FisuEvolution/UI/Events/EventPopupView.swift`
- Create: `FisuEvolutionTests/EventArtTests.swift`

**Interfaces:**
- Consumes: T1 (`ArtClips.event`); `UIArt.image(_:)`; `AnimatedArtView` (E8d T3).
- Produces: `EventPopupView.illustration(_ event:)` — `AnimatedArtView(clip:, role: .popup) {
  UIArt.image("ui_event_\(id)") }`, 120 pt de alto, `.accessibilityHidden(true)`; sólo si hay póster
  **y** clip. Identificador del contenedor: ninguno (la capa `art.video` ya es hoja).

**Oráculo:** pipeline sin salteados + `Tools/v2/oraculo.sh tarea EventArtTests EventPresenterTests
LoopsManifestTests` + Receta R `EventChipUITests` y `CorralitoUITests` + captura con
`--uitest-video` (SE y 16 Pro) de `aguinaldo` y de `apagon` (sin ilustración: igual que hoy).

- [ ] **Step 1: los pósters.** Copiar los 8 cuadros de
  `/Users/manuader/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/video/eventos/frames/`
  a `Tools/asset-pipeline/dropbox/` con el nombre `ui_event_<id>.png` (**`cayo_mercado_pago.png` →
  `ui_event_home_banking.png`**; los demás, igual) y correr el camino de `ui` de siempre
  (`process_dropbox.py`, recorte blanco). Si los cuadros no están en esa ruta: **parar con
  `NEEDS_CONTEXT`** (no buscar en otro lado).
- [ ] **Step 2: RED — `EventArtTests`**: cada clave de `loops.events` tiene `ui_event_<id>` en
  `assets_manifest.ui` y en el atlas; ningún `ui_event_*` sin clip (los dos lados).
- [ ] **Step 3: GREEN** — `illustration(event)` entre el `PanelTitleBanner` y la fila del presentador.
  Si el detent `.fraction(0.52)` corta los botones de salida en el SE, subirlo a `0.62` (el del
  visitante) **sólo** cuando hay ilustración.
- [ ] **Step 4:** oráculo + UI + capturas. Commits: `feat(arte): los pósters de los ocho eventos`,
  `feat(video): el evento se ve y se mueve en su popup`.

**No se hace:** el chip del evento (40 pt, competiría con la tienda por el rol `icon`); pósters para
los 10 eventos sin clip.

---

### Task 4: El ícono enfocado de la Tienda de ORO

**Objetivo:** en "Gastar ORO", **sólo la fila del medio de las visibles** anima su ícono (spec:
"anima sólo el que está centrado"); las demás, su PNG de siempre. Suena `sfx_shop_shimmer` muy bajo
cuando el ícono enfocado cambia. El pack `anim-tienda` se precarga al abrir la tienda.

**Files:**
- Modify: `FisuEvolution/UI/Store/OroShopView.swift` (`OroShopShelves`, `OroShopItemRow.icon`)
- Create: `FisuEvolutionTests/ShopIconFocusTests.swift`
- Modify: `FisuEvolutionTests/AudioWiringTests.swift` (`shopShimmer` a `declaredCases`; si el parser
  no mira `UI/Store`, se suma el directorio: una línea)

**Interfaces:**
- Consumes: T1 (`ArtClips.shopIcon`); `onScrollVisibilityChange(threshold:)` (iOS 18, el target);
  `ArtPacks.shared.prefetch/release`; `AudioManager.SFX.shopShimmer` (ambiente: `gain: .ambient`).
- Produces: `enum ShopIconFocus { static func pick(visibleInOrder: [String], animatable: Set<String>)
  -> String? }` (el del medio de los visibles que tienen clip; empate → el de arriba);
  `OroShopItemRow(…, animated: Bool)`.
- Rol del pool: **`.icon`**. Una sola `AnimatedArtView` montada (la enfocada).

**Oráculo:** `Tools/v2/oraculo.sh tarea ShopIconFocusTests AudioWiringTests AudioManagerTests
OroShopScreenTests` + Receta R `OroShopUITests` (6/6, póster) + captura con `--uitest-video --uitest-oro`
en el SE (scroll: el ícono que anima cambia, uno solo a la vez).

- [ ] **Step 1: RED — `ShopIconFocusTests`**: `[]` → `nil`; `["a"]` → `"a"`; `["a","b","c"]` → `"b"`;
  `["a","b"]` → `"a"`; el del medio sin clip → el más cercano al medio con clip; ninguno con clip →
  `nil`.
- [ ] **Step 2: GREEN** — cada fila reporta su visibilidad (`threshold: 0.8`) a un `@State
  visibleRows` de `OroShopShelves` (orden = el de `rows`); `focused = ShopIconFocus.pick(…)`; la fila
  enfocada recibe `animated: true` y su `icon` envuelve el póster en
  `AnimatedArtView(clip: ArtClips.shopIcon(item:…)!, role: .icon)`. `.onAppear` prefetch del tag de
  cualquier clip de la tienda (`manifest.odrTag(for:)`), `.onDisappear` release.
- [ ] **Step 3: RED → GREEN — brillo.** `onChange(of: focused)` con valor no nulo →
  `audio.play(.shopShimmer, gain: .ambient)` vía `GameState` (el parser exige el `play` en
  `Game/State`: un `func shopIconFocused()` en `GameState+OroShop.swift`).
- [ ] **Step 4:** oráculo + UI + captura. Si el primer cuadro de `ui_oro_*` no es el PNG `ui_shop_*`
  y el salto se nota en la captura: anotarlo para G3 (duda 5), no rehacer arte.
- [ ] **Step 5:** commit: `feat(video): la Tienda de ORO anima el ícono del medio`.

**No se hace:** "Comprar ORO" (los packs no tienen clip); `ui_oro_extra_slots` (lo estrena E6b T7 con
`ArtClips.shopIcon` y lo saca de `pendingShopIcons`).

---

### Task 5: El colchón espera y se abre

> ⛔ **Depende de E5b T2** (crea `MattressPopupView`; en vuelo en el relevo 29).

**Objetivo:** en el popup del colchón, mientras está cerrado, `colchon_espera` en loop; al abrirlo,
`colchon_abre` una vez y, al terminar, lo que salió. **El premio se acredita como hoy** (en
`mattressTapped()` / `mattressVideoWatched()` de E5b T2): el video sólo demora mostrarlo.

**Files:**
- Modify: `FisuEvolution/UI/Prizes/MattressPopupView.swift`
- Modify: el test de la vista que deje E5b T2 (`PrizeAccessTests` o el que corresponda)

**Interfaces:**
- Consumes: E5b T2 (`MattressPopup.outcome`, `MattressGlyph`, los sonidos `mattressSqueak/Rip/
  cashBurst` si E5b T2 los cableó); `AnimatedArtView(.object(…), role: .popup, playback: .once(onEnd:))`.
- Produces: `@State revealed: Bool` (el resultado se dibuja con `revealed`); sin identificadores nuevos.

**Oráculo:** `Tools/v2/oraculo.sh tarea <las clases de E5b T2 que toquen el popup> AnimatedArtViewTests`
+ Receta R `PrizesUITests` (bajo `--uitest*` el `.once` termina en el acto: el resultado aparece
como hoy) + captura con `--uitest-video` en el SE.

- [ ] **Step 1: RED** — un test de la regla "el resultado se ve tras el `onEnd` o en el acto con
  política quieta": con `VideoPlayerPool(policy: forcedStill)` el `onEnd` llega sin esperar
  (`AnimatedArtViewTests` ya lo cubre para la vista; acá se prueba que `revealed` pasa a `true`).
- [ ] **Step 2: GREEN** — `outcome == nil` → `AnimatedArtView(.object("colchon_espera"), role: .popup)
  { MattressGlyph }`; `outcome != nil && !revealed` → `.object("colchon_abre")` con
  `.once { revealed = true }`; `revealed` → el resultado de E5b T2. Si E5b T2 dispara `cashBurst` al
  mostrar el resultado, se mueve al `onEnd` (mismo `play`, otro momento).
- [ ] **Step 3:** oráculo + UI + captura. Commit: `feat(video): el colchón espera y se abre`.

**No se hace:** el colchón del tablero (es de T6, por el mismo nodo de E5b T3).

---

### Task 6: `.once` en `LoopingVideoNode`; la caja espera y se abre

> ⛔ **Depende de E5b T3** (crea `PickupNode` y `PackageOpeningPlayer`; espera a E5b T2).

**Objetivo:** el nodo de SpriteKit gana una pasada sola (`.once(onEnd:)`, el mismo contrato que
`AnimatedArtView`: sin video, con política quieta o si el primer cuadro no llega, `onEnd` en el acto;
nunca dos veces; desmontar no lo llama). Con eso: la caja de arriba de la pila y el colchón del
tablero esperan en loop (`paquete_espera`, `colchon_espera`) y el paquete que se abre donde llega el
empleado usa `paquete_abre` una vez en vez de (o debajo de) la animación por código de E5b T3.

**Files:**
- Modify: `FisuEvolution/Scenes/Nodes/LoopingVideoNode.swift`, `FisuEvolutionTests/LoopingVideoNodeTests.swift`
- Modify: `FisuEvolution/Scenes/Prizes/PickupNode.swift`, `PackageOpeningPlayer.swift` (de E5b T3)
  y sus tests (`PickupControllerTests`, `PackageOpeningPlayerTests`)

**Interfaces:**
- Produces: `LoopingVideoNode.init(…, playback: ArtPlayback = .loop)`; mismo `ArtPlayback` que la vista.
- Rol del pool: la caja y el colchón esperando, **`.icon`** (son ambiente; duda 6); la apertura,
  **`.popup`** (es el momento).
- El turno del tablero (`performBoardChange`, `confirmWithoutGesture`) **no cambia**: la llegada se
  confirma en el `onEnd` de la apertura, que con política quieta es inmediato.

**Oráculo:** `Tools/v2/oraculo.sh tarea LoopingVideoNodeTests PickupControllerTests
PackageOpeningPlayerTests BoardChangeWiringTests` + captura con `--uitest-video` en el SE.
**Revisión: opus** (AVFoundation en un componente compartido) · **Modelo:** sonnet.

- [ ] **Step 1: RED — `LoopingVideoNodeTests`**: `onceWithoutEntryEndsAtOnce`;
  `onceForcedStillEndsAtOnce` (`VideoPlayerPool(policy: forcedStill)`); `onceEndsExactlyOnce`
  (dos `setVisible(true)` y un fin → un `onEnd`); `stopDoesNotCallOnEnd`; `onceDoesNotLoop` (con
  `loop_npc_vecina.mov`: no hay `AVPlayerLooper`, es un `AVPlayer` y su fin lo detecta el sondeo o
  `AVPlayerItem.didPlayToEndTime` por `NotificationCenter` con `@MainActor`).
- [ ] **Step 2: GREEN** — `.once` en el nodo, copiando el criterio de `ArtVideoUIView` (vigía de 1 s,
  `onceFinished`).
- [ ] **Step 3:** `PickupNode` monta `LoopingVideoNode(.object("paquete_espera"|"colchon_espera"),
  role: .icon)` sobre su textura (póster = la textura de `PickupArt`) sólo en la caja de arriba y el
  colchón; `setVisible(false)` al salir. `PackageOpeningPlayer.play` monta `paquete_abre` en `.once`
  y llama `opened` en su `onEnd`; si E5b T3 dejó una animación por código, queda como la de Reduce
  Motion.
- [ ] **Step 4:** oráculo + captura. Commits: `feat(video): el nodo de video sabe pasar una sola vez`,
  `feat(video): la caja y el colchón del tablero esperan y se abren`.

**No se hace:** cambiar el turno del tablero ni el orden de las celebraciones.

---

### Task 7: El Álbum, con la tarjeta enfocada animada

**Objetivo:** en el Álbum de especiales, **una** tarjeta (la enfocada) muestra el cuerpo entero en
movimiento (`.character(sp_*)`, pack `anim-especiales`); las demás, el PNG de siempre. Al entrar, la
enfocada es el primer especial que tenés; tocar otra tarjeta que tenés la enfoca. Las que faltan
(silueta) nunca animan.

**Files:**
- Modify: `FisuEvolution/UI/Menu/SpecialsAlbumView.swift`
- Modify: `FisuEvolutionTests/SpecialsAlbumTests.swift`

**Interfaces:**
- Consumes: `gameState.albumEntries` (`id`, `owned`); `AnimatedArtView` (E8d T3);
  `ArtPacks.shared.prefetch("anim-especiales")` (o el tag que diga el manifest) al aparecer.
- Produces: `enum AlbumFocus { static func initial(_ entries: [AlbumEntry]) -> String?;
  static func tap(_ id: String, entries: [AlbumEntry], current: String?) -> String? }`;
  `@State focusedID: String?`. La tarjeta tocable suma `.accessibilityAddTraits(.isButton)` sólo si
  es tuya; **el identificador `album.card.<id>.<estado>` no cambia** (los UI tests no se tocan).
- Rol del pool: `.popup` (el Álbum es una hoja).

**Oráculo:** `Tools/v2/oraculo.sh tarea SpecialsAlbumTests` + Receta R `SpecialsAlbumUITests` (1/1) +
captura con `--uitest-video` (SE: la enfocada se mueve; tocar otra la pasa).

- [ ] **Step 1: RED — `SpecialsAlbumTests`**: `initial` → el primer `owned` en el orden de
  `albumEntries`; ninguno tuyo → `nil`; `tap` sobre uno tuyo lo enfoca; sobre uno que falta deja el
  actual; sobre el enfocado lo deja (no lo apaga).
- [ ] **Step 2: GREEN** — `portrait(entry)`: si `entry.id == focusedID`,
  `AnimatedArtView(clip: .character(entry.id), role: .popup) { <la imagen de hoy> }`; si no, la de
  hoy. `onTapGesture` en la tarjeta. Prefetch al aparecer, release al irse.
- [ ] **Step 3:** oráculo + UI + captura. Commit: `feat(video): el Álbum mueve al especial que mirás`.

**No se hace:** animar todas las tarjetas (tope 3 del pool); el retrato de busto (`portraits`) en el
Álbum (spec: el Álbum es cuerpo entero).

---

### Task 8: Las pintas con video (ficha, revelación, pipeline)

**Objetivo:** con una pinta puesta, la ficha y la revelación muestran **el clip de la pinta si
existe** y, si no, **quietas** (nunca la base animada). El pipeline acepta clips de pinta
(`<tipo>__<pinta>`) y los mete en el pack del piso del tipo. Hoy no hay ningún clip de pinta: todo
queda listo para que entren por manifest, sin Swift.

**Files:**
- Modify: `FisuEvolution/UI/Popups/CharacterSheetView.swift`
- Modify: `FisuEvolution/Scenes/BoardScene.swift` 🔥 (dos líneas: `mountRevealVideo` y
  `prefetchNextRevealPack`)
- Modify: `FisuEvolutionTests/RevealVideoTests.swift`, `FisuEvolutionTests/CharacterSheetFromMenuTests.swift`
  (o un `CharacterSheetVideoTests` nuevo si no encaja)
- Modify: `Tools/asset-pipeline/scripts/video_assets.py`, `Tools/asset-pipeline/tests/test_video_assets.py`

**Interfaces:**
- Consumes: T1 (`ArtClips.character(type:skin:in:)`, `skinKey`); `GameState.activeSkinID(forCharacterType:)`.
- Produces: `CharacterPortrait(…, clip: ArtClip?)` en vez de `animated: Bool` (la ficha calcula el clip
  por opción: `ArtClips.character(type:, skin: option.skin?.id)`); **sólo la opción seleccionada recibe
  clip** (`option.id == selectedID`), porque el `TabView(.page)` monta las vecinas y el pool dejaría
  viva la más nueva; la silueta nunca. En la revelación: el clip de la pinta activa del tipo o
  ninguno. Python: `validate_id("personaje", "<tipo>__<pinta>")` y `odr_tag` por el tipo base.

**Oráculo:** pipeline sin salteados + `Tools/v2/oraculo.sh tarea ArtClipsTests RevealVideoTests
CharacterSheetFromMenuTests` + Receta R `CharacterSheetUITests` (3/3, póster).

- [ ] **Step 1: RED (Python) — `test_video_assets.py`**:
  - `test_el_clip_de_una_pinta_va_al_pack_del_piso_del_tipo`: `odr_tag("personaje",
    "homeless__pijama") == "anim-piso-1"`; `odr_tag("personaje", "god__dinosaurio") == "anim-piso-10"`.
  - `test_valida_la_pinta_contra_skins_json`: `validate_id("personaje", "homeless__pijama")` pasa;
    `"homeless__no_existe"`, `"no_tipo__pijama"`, `"homeless__"` y `"homeless___pijama"` levantan
    `ValueError`.
  - `test_registra_la_pinta_en_characters`: `target("personaje", "homeless__pijama") ==
    ("characters", "homeless__pijama")`.
- [ ] **Step 2: GREEN (Python)** — `SKIN_ID = re.compile(r"([a-z0-9]+(?:_[a-z0-9]+)*)__([a-z0-9]+(?:_[a-z0-9]+)*)")`;
  `validate_id` lo prueba antes que `CHARACTER_ID` y valida el par contra
  `Resources/Config/skins.json` (`characterType`, `id`); `odr_tag` toma `piece_id.split("__")[0]`
  para el piso. `sp_*__<pinta>` → `anim-especiales`.
- [ ] **Step 3: RED (Swift)**:
  - `RevealVideoTests.skinWithoutClipRevealsStill`: tipo con pinta activa sin clip y base con clip →
    no se monta `LoopingVideoNode` en el reveal.
  - `RevealVideoTests.skinWithClipRevealsSkin`: manifest de fixture con `<tipo>__<pinta>` → el nodo
    del reveal es de ese clip.
  - Ficha: con base + pinta con clip + pinta sin clip, sólo la seleccionada lleva clip, y la pinta sin
    clip da `nil` (mirar el valor que calcula la vista por una función estática testeable, p. ej.
    `CharacterSheetView.clip(for:type:selectedID:owned:manifest:)`).
- [ ] **Step 4: GREEN (Swift)** — `CharacterSheetView` y las dos líneas de `BoardScene`
  (`guard let clip = ArtClips.character(type: type.id, skin: gameState.activeSkinID(forCharacterType:
  type.id), in: loops)`; el prefetch pide el tag de ese clip). **Si `BoardScene` tiene dueño en la ola,
  parar con `NEEDS_CONTEXT`** y dejar el diff de las dos líneas en el reporte.
- [ ] **Step 5:** oráculo + UI. Commits: `feat(pipeline): los clips de pinta entran al pack del piso`,
  `feat(video): la pinta se mueve sólo con su propio clip`.

**No se hace:** generar clips de pinta; la pinta en el tablero (los personajes del tablero no usan
video, spec).

---

### Task 9: Cierre de E8e (controlador)

- [ ] **Step 1: el barrido.** `AnimatedPlacesTests` (de E8d T15): cada sección con entradas
  (`talking`, `visitorActions`, `events`, `shopIcons`, `objects`, `characters`) tiene quien pida su
  `ArtClip` en `FisuEvolution/` y `pendingPlaces` queda **vacío** (salvo `ui_oro_extra_slots` →
  E6b T7, que vive en `ArtClips.pendingShopIcons`). Si E8d T15 no corrió, este paso espera.
- [ ] **Step 2:** `Tools/v2/oraculo.sh completo` sobre la punta de `v2/e8e-videos` con `version-2`
  mergeada → VERDE con todas las clases de E8e.
- [ ] **Step 3: gates en el dispositivo del dueño** (🔒, los mide él; la vara es la de G1–G5 de E8d):
  - **fps en el SE con el tope de 3**: piso animado + visitante del escenario hablando + Tienda de
    ORO abierta con el ícono enfocado; y piso + popup del evento. ≥ 59 fps promedio, ≤ 1 % de cuadros
    > 25 ms, ningún toque demorado. Si no pasa: la escalera de G1 (el `icon` del SE a póster primero).
  - **Memoria** (G4): pico con 3 vivos ≤ el de la escena en póster + 40 MB; 10 min sin jetsam.
  - **Reduce Motion** y **Modo de bajo consumo**: todo quieto; el colchón y la caja muestran el
    resultado en el acto; ningún hueco donde había video.
  - **ODR** (G5): primera apertura de la tienda, del Álbum, de un evento y de un visitante con el
    pack sin bajar: póster y después video; en modo avión, póster para siempre.
  - **Alfa y salto póster → video** (G3): eventos, íconos, Álbum, escenario.
- [ ] **Step 4: docs.** `Docs/SESION-<fecha>-v2-e8e.md`; `Docs/HANDOFF.md` §4/§5 (`ArtClips` y la
  tabla de la tienda; dónde anima cada sección), §7 (trampas: el `TabView(.page)` monta las vecinas;
  el pool deja vivo al más nuevo, no al que se mira); `tasks.md` (filas y carries). Journal y `LOCK`.

---

## Dudas con default

Ninguna frena: la ejecución sigue con el default.

1. **El popup del visitante sigue con el retrato** (`.portrait`, E4b T3), no con `talking`: la spec
   asigna los retratos al popup y el globo de texto "abierto" es el del escenario; el clip `talking`
   es de cuerpo entero y no entra en el plato circular sin un salto contra la cara. **Default:** así;
   si el dueño quiere el cuerpo hablando en el popup, es una línea en `VisitorPopupView` y el plato
   pasa a cuadrado.
2. **El visitante del escenario usa el rol `popup`**: es el momento del juego en el tablero; un popup
   que se abre encima lo baja a póster (el más nuevo gana), y la revelación también. **Default:** así.
3. **El visitante "en acción" es el que espera sin globo** (el comisario labra, el vendedor muestra):
   el código no tiene otro "momento del pedido" en el tablero, y la pose `_action` hoy no se usa en
   ningún lado. **Default:** así.
4. **La tabla ítem → clip de la tienda vive en Swift** (`ArtClips.shopIconKeys`), no en
   `oro_shop.json`: es arte, como `VisitorArt`, y no toca EconomyKit. `time_jump_1h/4h` comparten
   `ui_oro_time_skip`; `income_x2/x3`, `ui_oro_income_boost`; `skip_cooldowns` y `skin_chest` sin
   clip. **Default:** así; el dueño puede reasignar (sobre todo: ¿`time_skip` es el salto de tiempo o
   "saltear enfriamientos"?).
5. **El póster de la tienda es el `ui_shop_*` de hoy**, aunque los clips salieron de otro arte
   (`ui_oro_*`): si el salto se nota, se integra el primer cuadro como póster (como los eventos en T3).
   **Default:** se mira en la captura de T4 y en G3.
6. **Caja y colchón del tablero esperando usan el rol `icon`** (ambiente): con la tienda abierta el
   ícono enfocado les gana. **Default:** así.
7. **El Álbum enfoca al primero que tenés** al entrar (no hay "fecha de obtenido" en `AlbumEntry`).
   **Default:** así; tocar otra tarjeta la enfoca.
8. **La tienda anima la fila del medio de las visibles** (lista vertical, no carrusel). **Default:**
   así (duda 8 de E8d).
9. **Una pinta sin clip queda quieta en la ficha y en la revelación** (pedido del controlador): nunca
   la base animada con la pinta equivocada. **Default:** así.
10. **Los clips de pinta van al pack del piso del tipo** (`anim-piso-<n>`), no a un pack aparte.
    **Default:** así; si el pack crece de más se parte por familia en el pipeline.
11. **El chip del evento no anima.** **Default:** así.
12. **`talkBlip` suena una vez por globo**, no por sílaba (no hay máquina de escribir). **Default:** así.

## Filas para `tasks.md` §5

Nueva sección "E8e — Videos al juego (plan 2026-10-10-v2-e8e-videos-al-juego.md)", después de E8d, y
una fila al tope de §4 (pedido del dueño con prioridad, `DUENO.md` 2026-10-10). Las filas están en
`tasks.md`.
