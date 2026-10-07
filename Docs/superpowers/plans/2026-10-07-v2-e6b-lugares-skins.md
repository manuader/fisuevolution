# E6b — Lugares extra, pintas con ORO, los 8 efectos y las 3 familias · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que el ORO también se gaste en lo que se ve: el permanente de lugares extra (+3 y +2
por piso, hasta 4 filas), las pintas compradas con ORO (que StoreKit no puede borrar), los 8
efectos de skin hechos por código (con la galería que el dueño aprueba antes de venderlos) y las
3 familias dibujadas de 43 personajes (cuando E8 entregue sus atlas).

**Architecture:** la capacidad cambia en **un solo lugar**: `FloorTable.expanded(by:)` en
EconomyKit, y la app reemplaza `content.floorTable` por la tabla agrandada antes de reconstruir la
torre, así la torre, el reconciliador, los pisos en marcha (E2a), el mapa y la escena leen la
misma capacidad sin saber que existen los lugares extra. Las skins de ORO son dato
(`skins.json` v2: `oroPrice`, `family`, `shaderId`, `textureAtlas`), se poseen en
`meta.engagement.shop.skins` (E6a T1) y entran a `allOwnedSkins`. Los efectos son `SKShader`
compartidos por efecto, con la variación por personaje en atributos; en SwiftUI se muestran como
una foto del mismo shader (`SkinEffectRenderer`), así hay una sola implementación.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit (`SKShader`, `SKAttribute`) · EconomyKit (SPM puro, `Sendable`) · Swift Testing ·
XCUITest · XcodeGen · Python 3 (el pipeline de arte de E8, `process_dropbox.py`).

**Fuente:** `Docs/PLAN-v2.md` §4 "E6 — Tienda de ORO + IAP + skins" (la mitad de `extraSlots` y
skins), §2 (decisiones cerradas: "Skins de ORO", "Efectos de skin (ORO)", "Lugares por piso";
**no se re-litigan**), §5 (producción de arte: las 3 familias, 129 imágenes, ~44 MB) y §6
(riesgo del peso del bundle). La otra mitad es `2026-10-07-v2-e6a-tienda-ofertas.md` (E6a): la
tienda, los packs y las ofertas; **leé su sección "Por qué E6 va en dos planes"**. Lo que el
código contradice o la spec deja abierto está en "Para el dueño / dudas".

**Rama de la épica:** `v2/e6-tienda` (la misma que E6a). T1 y T2 salen antes, desde `version-2`,
porque no dependen de nada y el gate de la galería es lo más largo de toda la épica.

**Los dos gates humanos de este plan:**

1. 🔒 **La galería de los 8 efectos** (T2 → T8): el dueño ve una muestra de cada efecto y elige
   cuáles entran. Los que queden mal se descartan, y en su lugar **algunas skins existentes pasan
   a ser exclusivas de ORO** (las elige el dueño). Hasta su respuesta, ningún efecto se vende.
2. 🔒 **Los atlas de las familias** (E8 → T9): Pijama de Ositos, Gaucho y Disfraz de Dinosaurio,
   43 personajes cada una, generados por E8 e integrados por `process_dropbox.py` (categoría
   `skinfam` → `fam_<familia>.atlas`). Hasta que estén los 43 de una familia, esa familia no se
   vende.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build (un API deprecado de `SKUniform`, también: por eso la velocidad de los shaders se
  cambia reemplazando el uniform, no escribiendo su valor). Nada de `Timer`: los shaders animan
  con `u_time`, que pone SpriteKit.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo** (Swift, JSON o test), en el mismo paso. Un archivo nuevo de EconomyKit no lo pide.
- **Strings nuevos, es + en, por `Tools/v2/catalogo.py`** con su snapshot
  `Tools/v2/claves-pendientes/e6b-tN.json` (la regla de E6a: la dueña del catálogo en su ola lo
  commitea; las demás commitean el JSON).
- **La capacidad de un piso se lee de `FloorTable` y de nada más.** Nadie suma lugares extra por
  su cuenta: si un lector necesita la capacidad, la saca de la tabla que recibe. La única que
  agranda la tabla es `GameState.applyExtraSlots()`.
- **`meta.ownedSkins` es la caché de StoreKit y se reescribe entera en cada sincronización**
  (`applyStoreEntitlements`): una pinta comprada con ORO **nunca** va ahí. Va a
  `meta.engagement.shop.skins` y `allOwnedSkins` la une.
- **No se vende lo que no se puede ver**: un efecto entra a `skins.json` sólo si el dueño lo
  aprobó en la galería (T8); una familia, sólo con sus 43 texturas en el atlas (T9). El respaldo a
  la textura base (`missingSkinArtFallsBackToTheBaseTexture`) es para el arte que se demora, no
  para vender una pinta que no existe.
- **Reduce Motion y Bajo consumo detienen los efectos** (`u_speed = 0`, PLAN-v2): se ven, pero
  quietos.
- **Lo mostrado es lo aplicado**: la foto del efecto en Pintas sale del mismo `SKShader` que el
  tablero; el precio en ORO de una pinta es el de `skins.json`, que es el que cobra
  `OroShop.purchaseSkin`.
- `accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos; FisuJobs es
  la referencia visual (`GameCard`, `PricePill(.oro)`, `StateBadge`); nada de alertas del sistema.
- **Nada nuevo corre bajo `--uitest*`** salvo que el test lo pida: `--uitest-extra-slots` (T7).
  La galería es `#if DEBUG` y se abre desde el panel de debug.
- **Todo estado nuevo vive en `meta.engagement.shop`** (E6a T1): no se sube el schema.
- Código nuevo limpio y con pocos comentarios; el comentario que miente se corrige en el commit
  que lo vuelve mentira (los de `allOwnedSkins` "IAP ∪ milestones", sobre todo).
- **Commits en español, estilo `feat(skins): …` / `feat(tienda): …`, SIN `Co-Authored-By`.**
  Staging selectivo y `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (el controlador): integración con el oráculo → `Docs/SESION-…-v2-e6.md`
  → las cuatro ediciones de `Docs/HANDOFF.md` → journal y `LOCK`. Ningún subagente toca `Docs/`,
  `handoffs/`, el journal ni `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
Tools/v2/oraculo.sh completo --limpio # después de tocar arte (T9): el build incremental NO recompila los atlas
```

- `rapido` al cerrar T1, T3, T4, T6. `completo` al cerrar T2 (UI), T5 (escena y pantallas), T7
  (escena y UI), T8 y T9 (`--limpio`: atlas nuevos), y la épica (T10).
- **E6b no declara rojos.** El `pacing-sim` no se mueve (el simulador no compra lugares extra
  hasta E2b).
- Las Recetas R (una suite) y S (Store en 18.6) son las de E6a. Para medir en el iPhone SE
  (T7), el simulador es `"iPhone SE (3rd generation)"` con el runtime 26.5, creado y borrado por
  UDID igual que en la Receta R.
- ⚠️ Una corrida que no nombra los tests esperados no probó nada. Ante un rojo en masa: `uptime`,
  `ps aux | grep '[x]codebuild'` y las rutas de los `SwiftCompile`.

## Las referencias de PLAN-v2 E6, verificadas contra el árbol (`d22eb7a`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E6b |
|---|---|---|
| "`extraSlots`: base 15 (3 filas) por dato" | `economy.json` `floors[].capacity` = 10 en los diez pisos (pineado en `GameContentValidationTests.swift:594`); E2a **no** la cambia (su duda 2): la pasa E2b | los lugares extra son **deltas** (+3, +2): con base 10 dan 13/15, con base 15 dan 18/20 (duda 1) |
| "`TowerState.Floor` nace con `def.capacity + meta.shop.extraSlots`" | `TowerState.swift:26-29` (`slots` = `def.capacity`) | **no** se toca: la tabla que recibe ya viene agrandada (`FloorTable.expanded(by:)`) |
| "Pasan a `slots.count`: `TowerReconciler`, `PacingSimulator`, `FloorMapEntry`, `BoardScene.layoutBoard` y `floorOccupancy`" | reconciliador `TowerReconciler.swift:64`; simulador `PacingSimulator.swift:550`, `:655` (no arma torre: no tiene `slots`); mapa `GameState+Tower.swift:50` (`definition.capacity`); escena `BoardScene.swift:1205-1229`; ocupación `GameState+Tower.swift:106-110`; y **`StaffedFloors`** (E2a T4) lee `floorTable[$0].capacity` | pasar todo a `slots.count` deja afuera al simulador y a `StaffedFloors`, que no tienen torre: la capacidad vive en la tabla (contradicción 1) |
| "`boardRows` = ⌈lugares/5⌉" | `PlayLayout.rows(forCapacity:)` (`PlayLayout.swift:53-55`, E3a T3, **en el árbol**); `BoardScene.layoutBoard` todavía fija `boardRows = 2` (`:1215`) hasta E3a T10 | E6b no toca la escena para las filas: E3a T10 ya lee la capacidad del piso visible |
| "Se re-pinea `CrowdDepthTests` y se mide en el SE (spike S5)" | `PlayLayout.crowdTopRatio(rows:)` da 0,70 para ≥ 3 filas (`:59-61`); el spike S5 midió **0,63** como máximo en el SE para 3 filas y nadie midió 4; E3a T10 ya suma la capacidad 20 a `CrowdDepthTests` | T7 mide las 4 filas en el SE (la separación entre filas baja de `usable/3` a `usable/4`, `BoardScene.swift:1733-1745`) |
| `skins.json` v2 con `oroPrice`, `family`, `shaderId` y `textureAtlas` | `skins.json` es `schemaVersion: 1`, 131 entradas, todas `texture`; `SkinsConfig.Treatment` sólo `tint`/`texture` (`SkinsConfig.swift:6-9`) | T3 suma `effect` y los cuatro campos; el dato sube a v2 cuando entra la primera skin de ORO (T8) |
| "Comprar una familia la da para los 43, como pasa con oro y diamante" | la convención ya existe: el MISMO id repetido por personaje (`oro`, `diamante`), y `exclusiveCharacterTypeBySkinID` lo trata como compartido (`SkinsConfig.swift:125-138`) | las familias usan el id de la familia (`pijama`) en las 43 entradas |
| las skins de ORO se poseen | `meta.ownedSkins` es la caché de StoreKit (`PlayerState.swift:299`), reescrita entera por `applyStoreEntitlements` (`GameState+Store.swift:213-225`), que además **desequipa** lo que no esté en `allOwnedSkins` (`PlayerState.swift:521`) | T4: `shop.skins` (E6a T1) entra a `allOwnedSkins` (🔥 `PlayerState.swift`, una línea) |
| "Shaders: `Scenes/Shaders/SkinShaders.swift`, un `SKShader` compartido por efecto y variación por `SKAttributeValue`" | no existe; `CharacterNode.configure` sólo tiñe (`CharacterNode.swift:55-87`) | T1 (los shaders), T5 (el nodo) |
| "Con Reduce Motion o en Bajo consumo se detienen (`u_speed = 0`)" | nada observa el modo Bajo consumo en el repo | T1 observa los dos avisos del sistema |
| "Cuesta hasta +10 draws por piso (se mide)" | no medido | T2 lo mide en la galería (`showsDrawCount`) y T5 en el tablero |
| "Familias: atlas propio por familia (`fam_<familia>.atlas`)" | `process_dropbox.py:42-50` ya manda `skinfam` a `fam_{family}.atlas` con la clave `<tipo>_idle__<familia>` (`:67-78`); **`PlaceholderRenderer` busca la textura de una skin en el atlas del personaje** (`PlaceholderRenderer.swift:12-27`), igual que las vistas de SwiftUI (`CustomizationView.swift:514`, `CharacterSheetView.swift:306`) | T5 suma el atlas de la skin a la resolución (`SkinResolver.atlas`) |
| "Suman ~44 MB; On-Demand Resources queda como mejora futura" | sin medir | T9 mide el `.app` antes y después |
| la galería que aprueba el dueño | no existe; el panel de debug es `UI/DebugPanelView.swift` (`List` en `NavigationStack`, se abre con `hud.debug`) | T2: una pantalla de debug + un test de UI que exporta las 8 fotos |
| "algunas skins existentes pasan a ser exclusivas de ORO (las elige el dueño)" | las candidatas son de cofre (`chestRarity`) o de milestone | T8: salen del cofre o del milestone y ganan `oroPrice` (el validador exige que sean excluyentes) |

## Lo que E6b hereda (todavía no está en el árbol)

| API | La define | La usa |
|---|---|---|
| `ShopState.skins`, `ShopState.levels`, `EngagementState.shop` | **E6a T1** | T4, T7 |
| `OroShop` (`purchase`, `extraSlots(levels:catalog:)`), `OroShopCatalog.Perk.extraSlots`, `OroShopOutcome`, `buyOroShopItem` | **E6a T2, T6** | T4, T6, T7 |
| `OroShopShelves`, `OroShopCopy` | **E6a T4, T8** | T5, T7 |
| `GameContent.oroShop`, `OroShopContentTests` | **E6a T4** | T7 |
| `StaffedFloors.ordinals(state:tiers:floorTable:)` | **E2a T4** | T6 (el test) |
| `PlayLayout` en la escena, `CrowdDepthTests` con 10/15/20, `board.layout`, `hud.elevator.display` | **E3a T8, T10** | T7 |
| la ficha reescrita (`CharacterSheetView` con `CharacterPortrait(type:treatment:asSilhouette:)` y la pinta en grande) | **E3b T2** | T4, T5 |
| `applyEngagementFixtures(arguments:)`, `fixtureValue(_:in:)` | **E4a T9** | T7 |
| `fam_pijama.atlas`, `fam_gaucho.atlas`, `fam_dinosaurio.atlas` con 43 texturas cada uno | **E8** (generación) + `process_dropbox.py` | T9 |
| los dueños previos de `BoardScene.swift` (E1 T10, E3a T10, E4b T1/T6/T9, **E5b T3** la caja del paquete en la escena) y de `CharacterSheetView`/`CustomizationView` (E3b T2) | E1, E3a, E3b, E4b, E5b | T5 |
| **E5** (plan integrado en `version-2`, `da86b16`): los cofres de la ruleta y del colchón preguntan `ChestRoller.hasSomethingToGive(owned: player.meta.allOwnedSkins, …)` (`wheelChestHasSomethingToGive`, E5a T8); el paquete llega por `BoardChangePlanner.planArrival(origin: .package)` + `placeUnit` y se bloquea con la torre llena (`packagesBlocked`, E5a T6) | **E5a T6, T8** | T4 (una pinta de ORO cuenta como tenida también para esos cofres: no hay que tocar E5), T7 (los lugares extra le dan lugar al paquete: `ExtraSlotsWiringTests` suma que con la torre llena + lugares comprados el paquete deja de estar bloqueado), T8 (una exclusiva de ORO sale del `chestPool`, así que tampoco la reparten la ruleta ni el colchón) |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Scenes/Shaders/SkinShaders.swift` | **nuevo** — los 8 shaders, su caché, los atributos, la velocidad | 1 |
| `FisuEvolution/Scenes/Shaders/SkinEffectRenderer.swift` | **nuevo** — la foto de un efecto para SwiftUI | 1 |
| `FisuEvolution/UI/Debug/SkinEffectsGalleryView.swift` | **nuevo** (`#if DEBUG`) — la galería del dueño | 2 |
| `FisuEvolution/UI/DebugPanelView.swift` | la entrada a la galería | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift` | `Treatment.effect`, `shaderId`, `oroPrice`, `family`, `textureAtlas`, el validador, `oroSkinIDs`, `oroPrice(of:)` | 3 |
| `FisuEvolution/Managers/Store/SkinResolver.swift` | `Treatment.effect(shaderId:)` (T3); `atlas(for:characterType:config:)` (T5) | 3, 5 |
| `FisuEvolution/Managers/GameContentLoader.swift` | los ids de shader al validador (T3); `baseFloorTable` y `var floorTable` (T7) | 3, 7 |
| `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` 🔥 | `allOwnedSkins` une `engagement.shop.skins` | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift` | `purchaseSkin` | 4 |
| `FisuEvolution/Game/State/GameState+Store.swift` | `SkinCatalogRow.State.oroPurchasable`, `buySkinWithOro` (T4); `textureAtlas`/`shaderId` en la fila (T5) | 4, 5 |
| `FisuEvolution/UI/Skins/CustomizationView.swift`, `FisuEvolution/UI/Popups/CharacterSheetView.swift` | comprar con ORO (T4); la foto del efecto y el atlas de la familia (T5) | 4, 5 |
| `FisuEvolution/Scenes/PlaceholderRenderer.swift`, `FisuEvolution/Scenes/Nodes/CharacterNode.swift`, `FisuEvolution/Scenes/BoardScene.swift` 🔥 | el atlas de la skin y el shader en el tablero | 5 |
| `FisuEvolution/Game/State/GameState+Cosmetics.swift` | **nuevo** — las filas de Cosméticos | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift`, `FisuEvolution/UI/Store/OroShopView.swift` | el estante `cosmetics` | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/FloorTable.swift` | `expanded(by:)`, `FloorDef.withCapacity(_:)` | 6 |
| `FisuEvolution/Game/State/GameState.swift` 🔥 | `applyExtraSlots()` y su llamada en `reconcileTower`/`resyncTower` | 7 |
| `FisuEvolution/Game/State/GameState+OroShop.swift` | comprar lugares rehace la torre | 7 |
| `FisuEvolution/Resources/Config/oro_shop.json` | el ítem `extra_slots` | 7 |
| `FisuEvolution/Game/State/GameState+Engagement.swift` | `--uitest-extra-slots` | 7 |
| `FisuEvolution/Resources/Config/skins.json` | los efectos aprobados y las exclusivas (T8); las 129 de familia (T9) | 8, 9 |
| `FisuEvolution/Resources/fam_*.atlas` | los atlas de E8 (no se generan acá) | 9 |
| tests | EK: `SkinsConfigV2Tests`, `OroSkinPurchaseTests`, `ExtraSlotsTests`; app: `SkinShadersTests`, `OroSkinOwnershipTests`, `SkinEffectRenderingTests`, `CosmeticsRowsTests`, `ExtraSlotsWiringTests`, `OroSkinsContentTests`, `FamilySkinsContentTests` + `GameContentValidationTests`, `OroShopContentTests`; UI: `SkinGalleryCaptureUITests`, `ExtraSlotsLayoutUITests`, `CosmeticsUITests` | 1–9 |

## Orden, olas y paralelismo

Calientes (PLAN-v2 §0.1) y tibios (♨️) como en E6a. E6b **no toca** `RootView.swift`,
`ContentSystems.swift`, `GameState+Bonus.swift`, `SettingsView.swift`, `TowerActions.swift` ni
`project.yml`.

| T | Qué | Archivos | 🔥 / ♨️ | Depende de |
|---|---|---|---|---|
| 1 | los 8 efectos por código | `SkinShaders.swift`, `SkinEffectRenderer.swift`, `SkinShadersTests.swift` | — | nada (sale de `version-2`) |
| 2 | 🔒 la galería del dueño | `SkinEffectsGalleryView.swift`, `DebugPanelView.swift`, `SkinGalleryCaptureUITests.swift` | ♨️ `DebugPanelView` (E2a T14, E3b) | T1 |
| 3 | `skins.json` v2 (EK) | `SkinsConfig.swift`, `SkinResolver.swift`, `GameContentLoader.swift`, `SkinsConfigV2Tests.swift`, `GameContentValidationTests.swift` | ♨️ loader | T1 |
| 4 | pintas con ORO | `PlayerState.swift`, `OroShop.swift`, `GameState+Store.swift`, `CustomizationView.swift`, `CharacterSheetView.swift`, `OroSkinPurchaseTests.swift`, `OroSkinOwnershipTests.swift`, catálogo | 🔥 `PlayerState.swift`, catálogo · ♨️ `+Store` | T3; **E6a T1, T2**; **E3b T2** |
| 5 | los efectos y las familias se ven | `PlaceholderRenderer.swift`, `CharacterNode.swift`, `BoardScene.swift`, `SkinResolver.swift`, `GameState+Store.swift`, `GameState+Cosmetics.swift`, `CustomizationView.swift`, `CharacterSheetView.swift`, `OroShopCatalog.swift`, `OroShopView.swift`, `SkinEffectRenderingTests.swift`, `CosmeticsRowsTests.swift`, catálogo | 🔥 `BoardScene.swift`, catálogo | T1, T4; **E6a T8**; los dueños previos de `BoardScene` (el último de E5 es **E5b T3**) |
| 6 | lugares extra (EK) | `FloorTable.swift`, `ExtraSlotsTests.swift` | — | **E6a T2**; **E2a T4** (sólo un test) |
| 7 | lugares extra en la partida | `GameContentLoader.swift`, `GameState.swift`, `GameState+OroShop.swift`, `oro_shop.json`, `GameState+Engagement.swift`, `OroShopContentTests.swift`, `ExtraSlotsWiringTests.swift`, `ExtraSlotsLayoutUITests.swift`, catálogo | 🔥 `GameState.swift`, catálogo · ♨️ loader, `+Engagement` | T6; **E6a T6, T8, T12**; **E3a T10**; **E5a T6** (sólo el test del paquete) |
| 8 | 🔒 los efectos aprobados entran | `skins.json`, `OroSkinsContentTests.swift`, `CosmeticsUITests.swift`, catálogo | catálogo | **el gate de T2**; T5 |
| 9 | 🔒 las familias entran | `skins.json`, `fam_*.atlas` (de E8), `FamilySkinsContentTests.swift`, catálogo | catálogo | **el arte de E8**; T5 |
| 10 | cierre | `Docs/` (controlador) | — | todas |

```
Ola 0 (ya, desde version-2)     T1 shaders → T2 galería → 🔒 el dueño mira las 8 fotos (corre en paralelo con todo)
Ola 1 (EK, junto a E6a Ola 1)    T3 skins v2 ║ T6 lugares extra EK
Ola 2 (tras E6a T8)              T4 pintas con ORO (dueña de PlayerState.swift)
Ola 3 (tras E6a T12)             T5 lo que se ve (dueña de BoardScene.swift) ║ T7 lugares extra (dueña de GameState.swift)
Gates                            T8 (con la respuesta del dueño) ║ T9 (con los atlas de E8)
Cierre                           T10
```

**Reglas del paralelismo:** las de E6a. Además: **T5 y T7 tocan calientes distintos y pueden ir
juntas**, pero las dos escriben el catálogo (una entrega snapshot) y T7 toca
`GameState+Engagement.swift` después de E6a T12 (que también lo toca). T8 y T9 sólo tocan
`skins.json` y el catálogo: van de a una (las dos editan el mismo JSON).

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| el contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift:31` |
| config/estado/torre sintéticos de EK | `fxConfig(capacity:)`, `fxTiers`, `fxFloorTable(config:)`, `fxState(units:)`, `fxStateAndTower` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` |
| una bolsa de skins sintética | `fxChestSkins()` | `Fixtures.swift:152` |
| el renderer y las texturas del tablero | `PlaceholderRenderer().texture(for:manifest:skinTextureKey:)` | `PlaceholderRenderer.swift:12` |
| una textura de atlas | `AtlasCache.atlas(named:)`, `AtlasCache.texture(named:inAtlas:)` | `AtlasCache.swift:16-27` |
| la imagen SwiftUI de un personaje | `UIArt.characterImage(atlas:key:)` | `GameArt.swift` |
| equipar y dar pintas | `equipSkin(id:forCharacterType:)`, `grantMilestoneSkinsForTests(_:)`, `applyStoreEntitlements(removedAds:ownedSkins:)` | `GameState+Store.swift`, `GameState+Debug.swift:67` |
| la tienda de ORO | `buyOroShopItem(id:chanceAllowed:)`, `oroShopRows(chanceAllowed:)` | **E6a T6** |
| el panel de debug en UI | `app.buttons["hud.debug"]` | `RootView.swift:578-597` |
| la geometría del tablero | `PlayLayout(size:capacity:)`, `BoardScene.crowdBand(sceneHeight:cellSize:rows:)` | `PlayLayout.swift`, `BoardScene.swift:1733` |

---

### Task 1: Los 8 efectos, por código

**Objetivo:** los candidatos de PLAN-v2 §2 —Neón, Holograma, Fantasma, Arcoíris, Glitch, Pixel,
Oro líquido y Sombra— como `SKShader`: **uno compartido por efecto** (los personajes con el mismo
efecto se dibujan en la misma tanda), la variación por personaje en dos atributos (`a_phase`,
para que no latan sincronizados, y `a_rect`, el rectángulo de la textura en su página de atlas,
para que un efecto que muestrea vecinos no se coma el sprite de al lado), y la velocidad en un
uniform que Reduce Motion y Bajo consumo bajan a 0. Más `SkinEffectRenderer`, que saca la foto de
un efecto con el mismo shader para SwiftUI (Pintas, la ficha, la tienda) y para el test que
prueba que cada efecto compila y cambia el dibujo.

**Files:**
- Create: `FisuEvolution/Scenes/Shaders/SkinShaders.swift` (+ `xcodegen generate`)
- Create: `FisuEvolution/Scenes/Shaders/SkinEffectRenderer.swift` (+ `xcodegen generate`)
- Create: `FisuEvolutionTests/SkinShadersTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Produces: `@MainActor enum SkinShaders` con `nonisolated static let ids: [String]` (los 8, en el
  orden de PLAN-v2), `static func shader(for id: String) -> SKShader?`,
  `static func apply(_ id: String?, to sprite: SKSpriteNode, phase: Float)`,
  `static private(set) var speed: Float`, `static func setAnimated(_ animated: Bool)`,
  `static var systemWantsMotion: Bool`; `@MainActor enum SkinEffectRenderer` con
  `static func snapshot(of texture: SKTexture, shaderID: String?, side: CGFloat) -> CGImage?`
  (`nil` = la foto sin efecto).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/SkinShadersTests.swift`:

```swift
import CoreGraphics
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Los efectos de skin por código")
@MainActor
struct SkinShadersTests {
    /// 64×64: un margen transparente de 8 y adentro un damero rojo y azul de 4 px.
    /// Tiene borde (Neón, Sombra), color (Arcoíris, Oro) y detalle fino (Pixel).
    private func checker() throws -> SKTexture {
        let side = 64
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        for y in stride(from: 8, to: side - 8, by: 4) {
            for x in stride(from: 8, to: side - 8, by: 4) {
                let red = (x / 4 + y / 4).isMultiple(of: 2)
                context.setFillColor(red ? CGColor(red: 1, green: 0, blue: 0, alpha: 1) : CGColor(red: 0, green: 0, blue: 1, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        return SKTexture(cgImage: try #require(context.makeImage()))
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &buffer, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }

    @Test("son los 8 candidatos del dueño, en su orden")
    func theEightCandidates() {
        #expect(SkinShaders.ids == ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"])
    }

    @Test("un shader por efecto, compartido, con su velocidad y sus dos atributos", arguments: SkinShaders.ids)
    func oneSharedShaderPerEffect(id: String) throws {
        let shader = try #require(SkinShaders.shader(for: id))
        #expect(SkinShaders.shader(for: id) === shader, "compartido: los mismos efectos van en la misma tanda")
        #expect(shader.uniformNamed("u_speed") != nil)
        #expect(Set(shader.attributes.map(\.name)) == ["a_phase", "a_rect"])
    }

    @Test("un id desconocido no tiene shader")
    func unknownID() {
        #expect(SkinShaders.shader(for: "jackpot") == nil)
    }

    @Test("aplicar pone el shader y la fase; sin efecto, lo saca")
    func applyAndClear() throws {
        let sprite = SKSpriteNode(texture: try checker())
        SkinShaders.apply("neon", to: sprite, phase: 0.9)
        #expect(sprite.shader === SkinShaders.shader(for: "neon"))
        #expect(sprite.value(forAttributeNamed: "a_phase")?.floatValue == 0.9)
        SkinShaders.apply(nil, to: sprite, phase: 0)
        #expect(sprite.shader == nil)
    }

    @Test("quieto con Reduce Motion o Bajo consumo: la velocidad baja a 0")
    func motionStops() {
        defer { SkinShaders.setAnimated(SkinShaders.systemWantsMotion) }
        SkinShaders.setAnimated(false)
        #expect(SkinShaders.speed == 0)
        SkinShaders.setAnimated(true)
        #expect(SkinShaders.speed == 1)
    }

    @Test("cada efecto compila y cambia el dibujo", arguments: SkinShaders.ids)
    func everyEffectChangesTheDrawing(id: String) throws {
        let texture = try checker()
        let plain = try #require(SkinEffectRenderer.snapshot(of: texture, shaderID: nil, side: 64))
        let shaded = try #require(SkinEffectRenderer.snapshot(of: texture, shaderID: id, side: 64), "\(id) no dibujó")
        let shadedPixels = try pixels(shaded)
        #expect(shadedPixels != (try pixels(plain)), "\(id) dibuja igual que sin efecto: el shader no compiló")
        #expect(stride(from: 3, to: shadedPixels.count, by: 4).contains { shadedPixels[$0] > 0 }, "\(id) quedó transparente")
    }
}
```

(Si `SKView.texture(from:)` devuelve `nil` en el host de tests —sin dispositivo Metal—, el último
test se mueve tal cual a `SkinGalleryCaptureUITests` de la T2 como un test que corre en la app; no
se borra la aserción. El reporte lo anota.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/SkinShadersTests`.
Expected: no compila (`SkinShaders` no existe).

- [ ] **Step 3: Los shaders**

`FisuEvolution/Scenes/Shaders/SkinShaders.swift`:

```swift
import simd
import SpriteKit
import UIKit

/// Los efectos de skin por código (PLAN-v2 E6, decisión "Efectos de skin (ORO)").
///
/// Un `SKShader` por efecto, compartido por todos los personajes que lo llevan:
/// SpriteKit dibuja en una sola tanda los sprites con el mismo shader. Lo que
/// varía por personaje va en atributos —`a_phase` (para que no latan
/// sincronizados) y `a_rect` (el rectángulo de la textura en su página de atlas:
/// un efecto que muestrea vecinos no puede leer el sprite de al lado)—, no en
/// uniforms, que valen para todo el shader.
///
/// La velocidad es un uniform (`u_speed`) que Reduce Motion y Bajo consumo bajan
/// a 0: el efecto se ve, quieto.
@MainActor
enum SkinShaders {
    /// Los candidatos del dueño, en su orden. Los que entran a la venta los elige
    /// él en la galería (T2 → T8).
    nonisolated static let ids = ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"]

    private(set) static var speed: Float = 1
    private static var cache: [String: SKShader] = [:]
    private static var observers: [NSObjectProtocol] = []

    static var systemWantsMotion: Bool {
        !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    static func shader(for id: String) -> SKShader? {
        if let cached = cache[id] { return cached }
        guard let body = bodies[id] else { return nil }
        startObservingIfNeeded()
        let shader = SKShader(source: prelude + body, uniforms: [SKUniform(name: "u_speed", float: speed)])
        shader.attributes = [
            SKAttribute(name: "a_phase", type: .float),
            SKAttribute(name: "a_rect", type: .vectorFloat4),
        ]
        cache[id] = shader
        return shader
    }

    /// Pone (o saca, con `nil`) el efecto de un sprite. Se llama cada vez que el
    /// sprite cambia de textura: `a_rect` es el de ESA textura.
    static func apply(_ id: String?, to sprite: SKSpriteNode, phase: Float) {
        guard let id, let shader = shader(for: id) else {
            sprite.shader = nil
            return
        }
        sprite.shader = shader
        let rect = sprite.texture?.textureRect() ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        sprite.setValue(SKAttributeValue(float: phase), forAttribute: "a_phase")
        sprite.setValue(
            SKAttributeValue(vectorFloat4: vector_float4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height))),
            forAttribute: "a_rect"
        )
    }

    /// Anima o congela todos los efectos. El uniform se REEMPLAZA (no se escribe
    /// su valor): así no se toca ningún API deprecado de `SKUniform`.
    static func setAnimated(_ animated: Bool) {
        speed = animated ? 1 : 0
        for shader in cache.values {
            shader.removeUniformNamed("u_speed")
            shader.addUniform(SKUniform(name: "u_speed", float: speed))
        }
    }

    private static func startObservingIfNeeded() {
        guard observers.isEmpty else { return }
        speed = systemWantsMotion ? 1 : 0
        let center = NotificationCenter.default
        for name in [UIAccessibility.reduceMotionStatusDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { setAnimated(systemWantsMotion) }
            })
        }
    }

    // MARK: Los programas

    /// Lo que comparten los 8: pasar de la coordenada de la página de atlas a la
    /// del sprite (0…1) y volver, sin salirse del sprite.
    private static let prelude = """
    vec2 skin_local(vec2 uv, vec4 rect) { return (uv - rect.xy) / rect.zw; }
    vec2 skin_atlas(vec2 local, vec4 rect) { return rect.xy + clamp(local, 0.0, 1.0) * rect.zw; }
    float skin_rand(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    vec3 skin_rainbow(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }

    """

    /// Las texturas de SpriteKit vienen premultiplicadas: el color nunca pasa al alfa.
    private static let bodies: [String: String] = [
        "neon": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float d = 0.02;
            float around = texture2D(u_texture, skin_atlas(l + vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l + vec2(0.0, d), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(0.0, d), a_rect)).a;
            float edge = clamp(around * 0.25 - c.a, 0.0, 1.0);
            vec3 glow = vec3(0.25, 1.0, 0.9) * (0.7 + 0.3 * sin(t * 4.0));
            gl_FragColor = vec4(c.rgb + glow * edge, max(c.a, edge));
        }
        """,
        "holograma": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float scan = 0.75 + 0.25 * sin(l.y * 140.0 - t * 6.0);
            float k = 0.8 * (0.85 + 0.15 * sin(t * 23.0));
            float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
            vec3 rgb = min(vec3(0.35, 0.85, 1.0) * luma * 1.4 * scan * k, vec3(c.a * k));
            gl_FragColor = vec4(rgb, c.a * k);
        }
        """,
        "fantasma": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec2 l = skin_local(v_tex_coord, a_rect);
            l.x += sin(l.y * 10.0 + t * 2.0) * 0.015;
            vec4 c = texture2D(u_texture, skin_atlas(l, a_rect));
            float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
            float fade = 0.45 + 0.15 * sin(t * 1.5);
            vec3 ghost = mix(c.rgb, vec3(luma) * vec3(0.85, 0.95, 1.0), 0.7);
            gl_FragColor = vec4(ghost * fade, c.a * fade);
        }
        """,
        "arcoiris": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            vec3 band = skin_rainbow(fract(l.y * 0.8 + t * 0.25));
            gl_FragColor = vec4(mix(c.rgb, band * c.a, 0.45), c.a);
        }
        """,
        "glitch": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec2 l = skin_local(v_tex_coord, a_rect);
            float slice = floor(l.y * 18.0);
            float tick = floor(t * 8.0);
            float jump = step(0.82, skin_rand(vec2(slice, tick))) * (skin_rand(vec2(tick, slice)) - 0.5) * 0.12;
            vec2 g = l + vec2(jump, 0.0);
            vec4 base = texture2D(u_texture, skin_atlas(g, a_rect));
            float r = texture2D(u_texture, skin_atlas(g + vec2(0.012, 0.0), a_rect)).r;
            float b = texture2D(u_texture, skin_atlas(g - vec2(0.012, 0.0), a_rect)).b;
            gl_FragColor = vec4(min(r, base.a), base.g, min(b, base.a), base.a);
        }
        """,
        "pixel": """
        void main() {
            float t = u_time * u_speed + a_phase;
            float cells = 24.0 + 4.0 * sin(t * 0.5);
            vec2 l = skin_local(v_tex_coord, a_rect);
            vec2 p = (floor(l * cells) + 0.5) / cells;
            gl_FragColor = texture2D(u_texture, skin_atlas(p, a_rect));
        }
        """,
        "oro_liquido": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114)) / max(c.a, 0.001);
            vec3 gold = vec3(1.0, 0.78, 0.25) * (0.55 + 0.6 * luma);
            float shine = 1.0 - smoothstep(0.0, 0.08, abs(fract(l.x + l.y * 0.5 - t * 0.35) - 0.5));
            gl_FragColor = vec4(min((gold + vec3(shine)) * c.a, vec3(c.a)), c.a);
        }
        """,
        "sombra": """
        void main() {
            float t = u_time * u_speed + a_phase;
            vec4 c = texture2D(u_texture, v_tex_coord);
            vec2 l = skin_local(v_tex_coord, a_rect);
            float d = 0.015;
            float around = texture2D(u_texture, skin_atlas(l + vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(d, 0.0), a_rect)).a
                + texture2D(u_texture, skin_atlas(l + vec2(0.0, d), a_rect)).a
                + texture2D(u_texture, skin_atlas(l - vec2(0.0, d), a_rect)).a;
            float rim = clamp(c.a - around * 0.25, 0.0, 1.0) * 4.0;
            vec3 purple = vec3(0.55, 0.25, 0.85) * (0.7 + 0.3 * sin(t * 2.0));
            gl_FragColor = vec4(min(c.rgb * 0.18 + purple * rim * c.a, vec3(c.a)), c.a);
        }
        """,
    ]
}
```

(Los colores, frecuencias y amplitudes son la primera versión: la galería es para que el dueño los
juzgue, y un ajuste suyo es cambiar un número acá.)

- [ ] **Step 4: La foto para SwiftUI**

`FisuEvolution/Scenes/Shaders/SkinEffectRenderer.swift`:

```swift
import SpriteKit

/// La foto de un efecto, con el MISMO `SKShader` del tablero, para las pantallas
/// de SwiftUI (Pintas, la ficha, la tienda). Una sola implementación del efecto:
/// lo que se ve antes de comprar es lo que se ve en el tablero, quieto.
@MainActor
enum SkinEffectRenderer {
    private static let view = SKView(frame: CGRect(x: 0, y: 0, width: 256, height: 256))
    private static let cache = NSCache<NSString, CGImage>()

    /// `shaderID == nil` es la foto sin efecto (la usa el test para comparar).
    static func snapshot(of texture: SKTexture, shaderID: String?, side: CGFloat) -> CGImage? {
        let key = "\(ObjectIdentifier(texture).hashValue)|\(shaderID ?? "-")|\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: side, height: side))
        SkinShaders.apply(shaderID, to: sprite, phase: 0.37)
        guard let image = view.texture(from: sprite)?.cgImage() else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
```

(⚠️ La clave del caché usa la identidad de la textura: dos `SKTexture` distintas del mismo
sprite son dos fotos. Los llamadores piden la textura por `AtlasCache`, que la reusa.)

- [ ] **Step 5: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `-only-testing:FisuEvolutionTests/SkinShadersTests`
→ PASS (6 tests, dos con 8 argumentos). Mirá el log: un shader que no compila deja una línea de
SpriteKit con el error; si aparece, el test de "cambia el dibujo" ya tiene que estar rojo.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Scenes/Shaders/SkinShaders.swift FisuEvolution/Scenes/Shaders/SkinEffectRenderer.swift \
  FisuEvolutionTests/SkinShadersTests.swift
git diff --cached --stat
git commit -m "feat(skins): los 8 efectos de skin por código, un shader compartido por efecto"
```

---

### Task 2: 🔒 La galería de los 8 efectos, para que el dueño apruebe

**Objetivo:** el gate de PLAN-v2 ("el dueño ve una muestra de cada uno antes de que entren"):
una pantalla de debug que muestra los 8 efectos sobre personajes de verdad, animados y quietos,
con el conteo de draws a la vista (PLAN-v2: "cuesta hasta +10 draws por piso, se mide"), y un
test de UI que saca una foto por efecto y la deja en el `.xcresult`, para que el controlador se
las pase al dueño sin que nadie tenga que navegar el panel a mano.

**Files:**
- Create: `FisuEvolution/UI/Debug/SkinEffectsGalleryView.swift` (`#if DEBUG`, + `xcodegen generate`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (la entrada)
- Create: `FisuEvolutionUITests/SkinGalleryCaptureUITests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `SkinShaders`, `SkinEffectRenderer` (T1); `GameContentLoader`, `PlaceholderRenderer`,
  `AtlasCache`.
- Produces: `SkinEffectsGalleryView` (DEBUG), los ids `debug.skinGallery`,
  `gallery.effect.<id>`, `gallery.effect.all`, `gallery.animated`, `gallery.stage`.

- [ ] **Step 1: El test de captura, en rojo**

`FisuEvolutionUITests/SkinGalleryCaptureUITests.swift`:

```swift
import XCTest

/// Las fotos de la galería de efectos (PLAN-v2 E6, gate del dueño). No juzga
/// nada: deja una captura por efecto en el `.xcresult`, con su nombre, para que
/// el dueño elija cuáles entran. Se exportan con
/// `xcrun xcresulttool export attachments --path <xcresult> --output-path build/galeria-efectos`.
final class SkinGalleryCaptureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureEveryEffect() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"]
        app.launch()
        let debug = app.buttons["hud.debug"]
        XCTAssertTrue(debug.waitForExistence(timeout: 20))
        debug.tap()
        let gallery = app.buttons["debug.skinGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 10))
        gallery.tap()
        XCTAssertTrue(app.descendants(matching: .any)["gallery.stage"].waitForExistence(timeout: 10))

        app.buttons["gallery.effect.all"].tap()
        attach(app, named: "efectos-todos")
        for id in ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"] {
            let button = app.buttons["gallery.effect.\(id)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "falta \(id) en la galería")
            button.tap()
            attach(app, named: "efecto-\(id)")
        }
        // Un `Toggle` es un switch para XCUITest, no un botón.
        app.switches["gallery.animated"].tap()
        attach(app, named: "efecto-sombra-quieto")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate`, el `build-for-testing` de la Receta R y
`-only-testing:FisuEvolutionUITests/SkinGalleryCaptureUITests` → FAIL (`debug.skinGallery` no existe).

- [ ] **Step 3: La galería**

`FisuEvolution/UI/Debug/SkinEffectsGalleryView.swift`:

```swift
#if DEBUG
import SpriteKit
import SwiftUI

/// La galería del dueño (PLAN-v2 E6): los 8 efectos sobre personajes de verdad,
/// parados sobre el fondo del callejón, a escala de tablero. "Todos" pone una
/// columna por efecto; tocar uno lo muestra grande. Con los draws a la vista:
/// es la medición que pide PLAN-v2.
struct SkinEffectsGalleryView: View {
    @State private var selected: String?
    @State private var animated = true
    @State private var scene = SkinGalleryScene(size: CGSize(width: 390, height: 520))

    var body: some View {
        VStack(spacing: 8) {
            SpriteView(scene: scene, options: [.allowsTransparency], debugOptions: [.showsDrawCount, .showsNodeCount, .showsFPS])
                .frame(height: 520)
                .accessibilityElement()
                .accessibilityIdentifier("gallery.stage")
            ScrollView(.horizontal) {
                HStack {
                    Button("Todos") { show(nil) }
                        .accessibilityIdentifier("gallery.effect.all")
                    ForEach(SkinShaders.ids, id: \.self) { id in
                        Button(id) { show(id) }
                            .buttonStyle(.bordered)
                            .tint(selected == id ? .orange : .gray)
                            .accessibilityIdentifier("gallery.effect.\(id)")
                    }
                }
                .padding(.horizontal)
            }
            Toggle("Animado", isOn: $animated)
                .padding(.horizontal)
                .accessibilityIdentifier("gallery.animated")
                .onChange(of: animated) { _, on in SkinShaders.setAnimated(on) }
        }
        .navigationTitle("Efectos de skin")
        .onDisappear { SkinShaders.setAnimated(SkinShaders.systemWantsMotion) }
    }

    private func show(_ id: String?) {
        selected = id
        scene.show(effect: id)
    }
}

/// El escenario: el fondo del callejón y, por efecto, el tipo base y uno de tier
/// alto, al tamaño del tablero del iPhone 16 Pro.
final class SkinGalleryScene: SKScene {
    private var content: GameContent?
    private let renderer = PlaceholderRenderer()

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        content = try? GameContentLoader.load(from: .main)
        show(effect: nil)
    }

    func show(effect: String?) {
        removeAllChildren()
        guard let content else { return }
        if let key = content.manifest.backgrounds["alley"] {
            let floor = SKSpriteNode(imageNamed: key)
            floor.size = size
            floor.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(floor)
        }
        let effects = effect.map { [$0] } ?? SkinShaders.ids
        let types = [content.tiers.baseType] + Array(content.tiers.concreteTypes.suffix(1))
        let column = size.width / CGFloat(effects.count)
        let side = min(column * 1.6, 220)
        for (x, id) in effects.enumerated() {
            for (y, type) in types.enumerated() {
                guard let texture = renderer.texture(for: type, manifest: content.manifest) else { continue }
                let sprite = SKSpriteNode(texture: texture, size: CGSize(width: side, height: side))
                sprite.position = CGPoint(x: column * (CGFloat(x) + 0.5), y: side * 0.55 + CGFloat(y) * side * 0.95)
                SkinShaders.apply(id, to: sprite, phase: Float(x) * 0.9)
                addChild(sprite)
            }
        }
    }
}
#endif
```

`DebugPanelView.swift`, una sección nueva antes de "Peligro":

```swift
                Section("Skins") {
                    NavigationLink("Galería de efectos de skin") {
                        SkinEffectsGalleryView()
                    }
                    .accessibilityIdentifier("debug.skinGallery")
                }
```

- [ ] **Step 4: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionUITests/SkinGalleryCaptureUITests` → PASS. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Las fotos para el dueño (en el reporte, no en el repo)**

Run, sobre el `.xcresult` de la corrida del paso 4:
`xcrun xcresulttool export attachments --path <ruta del .xcresult> --output-path build/galeria-efectos`.
Anotá en el reporte la ruta de las 10 PNG y, de la foto "efectos-todos", **el conteo de draws**
que muestra el overlay (los 16 personajes con 8 efectos) contra el de una foto sin efectos (el
paso de "Todos" con `animated` en cualquiera). Ésa es la medición de "+10 draws por piso".

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/UI/Debug/SkinEffectsGalleryView.swift FisuEvolution/UI/DebugPanelView.swift \
  FisuEvolutionUITests/SkinGalleryCaptureUITests.swift
git diff --cached --stat
git commit -m "feat(skins): la galería de los 8 efectos, para que el dueño elija cuáles entran"
```

- [ ] **Step 7: 🔒 El gate (lo hace el controlador)**

El controlador publica las fotos (artifact o carpeta) y escribe en el handoff y en el journal:
"🔒 Necesito de vos: mirá los 8 efectos y decime cuáles entran; por cada uno que no, elegí una
skin existente que pase a ser exclusiva de ORO". La respuesta se anota en
`Docs/SESION-<fecha>-v2-e6.md` con dos listas (**efectos aprobados**, **exclusivas de ORO** con
su precio si no es 150) y es la entrada de la T8. Mientras tanto, todo lo demás sigue.

---

### Task 3: `skins.json` v2 — efectos, familias y precio en ORO

**Objetivo:** el catálogo de skins sabe decir lo que PLAN-v2 pide: un tratamiento `effect`
(con su `shaderId`), un precio en ORO (`oroPrice`), una familia (`family`) y el atlas de su
textura cuando no es el del personaje (`textureAtlas`). El validador cuida que nada se venda
mal: un efecto con un shader que no existe, una pinta de ORO que además sale de un cofre o se
gana por milestone, una familia sin atlas, o el mismo id con dos precios. El dato todavía no
cambia (las skins de ORO entran en T8 y T9).

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/SkinsConfigV2Tests.swift`
- Modify: `FisuEvolution/Managers/Store/SkinResolver.swift` (`Treatment.effect`)
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (los ids de shader al validador)
- Modify: `FisuEvolutionTests/GameContentValidationTests.swift` (`skinResolverIsDataDrivenAndScopedToCharacterType`)

**Interfaces:**
- Consumes: `SkinShaders.ids` (T1).
- Produces: `SkinsConfig.Treatment.effect`; `Entry.shaderId`, `.oroPrice`, `.family`,
  `.textureAtlas` (con default `nil` en el `init`); `ValidationError.missingShader`,
  `.unknownShader`, `.nonPositiveOroPrice`, `.oroAndChest`, `.oroAndMilestone`,
  `.inconsistentOroPrice`, `.familyWithoutAtlas`;
  `validate(characterTypeIDs:floorIDs:shaderIDs:)` (`shaderIDs` con default `[]`: sin shaders
  conocidos, ningún efecto valida); `oroSkinIDs: [String]`, `oroPrice(of:) -> Int?`;
  `SkinResolver.Treatment.effect(shaderId:)`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/SkinsConfigV2Tests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("skins.json v2: efectos, familias y precio en ORO")
struct SkinsConfigV2Tests {
    private let types: Set<String> = ["homeless", "cartonero"]
    private let shaders: Set<String> = ["neon", "pixel"]

    private func config(_ entries: [SkinsConfig.Entry]) -> SkinsConfig {
        SkinsConfig(schemaVersion: 2, skins: entries)
    }

    private func validate(_ entries: [SkinsConfig.Entry]) throws {
        try config(entries).validate(characterTypeIDs: types, floorIDs: [], shaderIDs: shaders)
    }

    @Test("se leen los cuatro campos nuevos, y una entrada vieja sigue leyéndose")
    func decodes() throws {
        let json = #"""
        {"schemaVersion": 2, "skins": [
          {"id": "neon", "characterType": "*", "treatment": "effect", "shaderId": "neon", "oroPrice": 150},
          {"id": "pijama", "characterType": "homeless", "treatment": "texture", "textureKey": "homeless_idle__pijama",
           "textureAtlas": "fam_pijama", "family": "pijama", "oroPrice": 450},
          {"id": "cohete", "characterType": "cartonero", "treatment": "texture", "textureKey": "cartonero_idle__cohete", "chestRarity": "comun"}
        ]}
        """#
        let skins = try JSONDecoder().decode(SkinsConfig.self, from: Data(json.utf8))
        #expect(skins.skins[0].treatment == .effect)
        #expect(skins.skins[0].shaderId == "neon")
        #expect(skins.skins[1].textureAtlas == "fam_pijama")
        #expect(skins.skins[1].family == "pijama")
        #expect(skins.skins[2].oroPrice == nil)
        #expect(throws: Never.self) { try skins.validate(characterTypeIDs: types, floorIDs: [], shaderIDs: shaders) }
    }

    @Test("las de ORO: una vez por id, en el orden del catálogo, con su precio")
    func oroSkins() {
        let skins = config([
            .init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150),
            .init(id: "pijama", characterType: "homeless", treatment: .texture, textureKey: "homeless_idle__pijama",
                  oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "pijama", characterType: "cartonero", treatment: .texture, textureKey: "cartonero_idle__pijama",
                  oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "cohete", characterType: "cartonero", treatment: .texture, textureKey: "k", chestRarity: .comun),
        ])
        #expect(skins.oroSkinIDs == ["neon", "pijama"])
        #expect(skins.oroPrice(of: "pijama") == 450)
        #expect(skins.oroPrice(of: "cohete") == nil)
        #expect(skins.exclusiveCharacterTypeBySkinID["pijama"] == nil, "una familia viste a varios: no trae a nadie")
        #expect(skins.exclusiveCharacterTypeBySkinID["neon"] == nil)
        #expect(skins.entries(forCharacterType: "homeless").map(\.id) == ["neon", "pijama"])
    }

    @Test("un efecto necesita un shader que exista")
    func effectNeedsAShader() {
        #expect(throws: SkinsConfig.ValidationError.missingShader("x")) {
            try validate([.init(id: "x", characterType: "*", treatment: .effect, oroPrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.unknownShader("glitchy")) {
            try validate([.init(id: "x", characterType: "*", treatment: .effect, shaderId: "glitchy", oroPrice: 150)])
        }
    }

    @Test("una pinta de ORO no sale de un cofre, no se gana por milestone y tiene un solo precio")
    func oroIsExclusive() {
        #expect(throws: SkinsConfig.ValidationError.nonPositiveOroPrice("x")) {
            try validate([.init(id: "x", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 0)])
        }
        #expect(throws: SkinsConfig.ValidationError.oroAndChest("x")) {
            try validate([.init(id: "x", characterType: "homeless", treatment: .texture, textureKey: "k", chestRarity: .rara, oroPrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.oroAndMilestone("x")) {
            try validate([.init(id: "x", characterType: "homeless", treatment: .texture, textureKey: "k", reincarnations: 1, oroPrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.inconsistentOroPrice("p")) {
            try validate([
                .init(id: "p", characterType: "homeless", treatment: .texture, textureKey: "a", oroPrice: 450, family: "p", textureAtlas: "fam_p"),
                .init(id: "p", characterType: "cartonero", treatment: .texture, textureKey: "b", oroPrice: 400, family: "p", textureAtlas: "fam_p"),
            ])
        }
    }

    @Test("una familia dice en qué atlas vive")
    func familyNeedsAnAtlas() {
        #expect(throws: SkinsConfig.ValidationError.familyWithoutAtlas("p")) {
            try validate([.init(id: "p", characterType: "homeless", treatment: .texture, textureKey: "a", oroPrice: 450, family: "p")])
        }
    }

    @Test("sin shaders conocidos, ningún efecto valida")
    func noShadersNoEffects() {
        #expect(throws: SkinsConfig.ValidationError.unknownShader("neon")) {
            try config([.init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150)])
                .validate(characterTypeIDs: types, floorIDs: [])
        }
    }
}
```

En `GameContentValidationTests.skinResolverIsDataDrivenAndScopedToCharacterType`, una entrada
más en el `SkinsConfig` del test, `.init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150)`,
y la aserción
`#expect(SkinResolver.treatment(for: "neon", characterType: "homeless", config: config) == .effect(shaderId: "neon"))`.

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter SkinsConfigV2Tests`
Expected: no compila (`Treatment.effect`, `shaderId`).

- [ ] **Step 3: EconomyKit**

`SkinsConfig.swift`:

```swift
    public enum Treatment: String, Codable, Sendable {
        case tint
        case texture
        /// Un efecto por código sobre el arte base (PLAN-v2 E6): lo dibuja la app
        /// con el shader de `shaderId`.
        case effect
    }
```

En `Entry`, después de `displayNameKey`:

```swift
        /// `effect`: el id del shader (`SkinShaders.ids`, en la app).
        public let shaderId: String?
        /// Se compra con ORO en la tienda (E6). Excluyente con el cofre y con los
        /// milestones: una pinta tiene una sola vía.
        public let oroPrice: Int?
        /// La familia dibujada a la que pertenece (pijama, gaucho, dinosaurio): el
        /// mismo id repetido en los 43, como `oro` y `diamante`.
        public let family: String?
        /// El atlas de su textura cuando no es el del personaje (`fam_<familia>`).
        public let textureAtlas: String?
```

el `init` suma `shaderId: String? = nil, oroPrice: Int? = nil, family: String? = nil, textureAtlas: String? = nil`
al final de sus parámetros, con sus asignaciones; en `ValidationError`:

```swift
        case missingShader(String)
        case unknownShader(String)
        case nonPositiveOroPrice(String)
        case oroAndChest(String)
        case oroAndMilestone(String)
        case inconsistentOroPrice(String)
        case familyWithoutAtlas(String)
```

las dos consultas, después de `exclusiveCharacterTypeBySkinID`:

```swift
    /// Las pintas que se compran con ORO, una vez por id y en el orden del catálogo.
    public var oroSkinIDs: [String] {
        var seen = Set<String>()
        return skins.compactMap { skin in
            guard skin.oroPrice != nil, seen.insert(skin.id).inserted else { return nil }
            return skin.id
        }
    }

    public func oroPrice(of skinID: String) -> Int? {
        skins.first { $0.id == skinID && $0.oroPrice != nil }?.oroPrice
    }
```

y el validador:

```swift
    public func validate(characterTypeIDs: Set<String>, floorIDs: Set<String>, shaderIDs: Set<String> = []) throws {
        var vistas = Set<String>()
        var precios: [String: Int] = [:]
        for skin in skins {
            // … las comprobaciones de siempre, sin cambios, hasta `chestAndMilestone` …
            if let price = skin.oroPrice {
                guard price > 0 else { throw ValidationError.nonPositiveOroPrice(skin.id) }
                guard skin.chestRarity == nil else { throw ValidationError.oroAndChest(skin.id) }
                guard !skin.isMilestone else { throw ValidationError.oroAndMilestone(skin.id) }
                if let anterior = precios[skin.id], anterior != price { throw ValidationError.inconsistentOroPrice(skin.id) }
                precios[skin.id] = price
            }
            if skin.family != nil, skin.textureAtlas?.isEmpty != false {
                throw ValidationError.familyWithoutAtlas(skin.id)
            }
            switch skin.treatment {
            case .tint:
                guard skin.tintHex?.isEmpty == false else { throw ValidationError.missingTint(skin.id) }
            case .texture:
                guard skin.textureKey?.isEmpty == false else { throw ValidationError.missingTexture(skin.id) }
            case .effect:
                guard let shader = skin.shaderId, !shader.isEmpty else { throw ValidationError.missingShader(skin.id) }
                guard shaderIDs.contains(shader) else { throw ValidationError.unknownShader(shader) }
            }
        }
    }
```

(El orden de las comprobaciones viejas no cambia: el bloque de ORO va después de
`chestAndMilestone` y antes del `switch`.)

- [ ] **Step 4: La app**

`SkinResolver.swift`:

```swift
    enum Treatment: Equatable {
        case base
        case tint(hex: String)
        case texture(key: String)
        /// Un efecto por código: el arte es el base, con `SkinShaders` encima.
        case effect(shaderId: String)
    }
```

y en `treatment(for:characterType:config:)`:

```swift
        case .effect:
            return skin.shaderId.map(Treatment.effect(shaderId:)) ?? .base
```

`GameContentLoader.swift`, la validación de skins pasa los shaders:

```swift
            try skins.validate(
                characterTypeIDs: Set(tiers.concreteTypes.map(\.id)),
                floorIDs: Set(floorTable.floors.map(\.id)),
                shaderIDs: Set(SkinShaders.ids)
            )
```

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (`SkinsConfigV2Tests`: 6, y
`SkinMilestonesTests`, `ChestRollerTests`, `ExtensibilityDrillTests` sin cambios). Receta R con
`-only-testing:FisuEvolutionTests/GameContentValidationTests -only-testing:FisuEvolutionTests/SkinCatalogRowsTests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift Packages/EconomyKit/Tests/EconomyKitTests/SkinsConfigV2Tests.swift \
  FisuEvolution/Managers/Store/SkinResolver.swift FisuEvolution/Managers/GameContentLoader.swift \
  FisuEvolutionTests/GameContentValidationTests.swift
git diff --cached --stat
git commit -m "feat(skins): skins.json v2 con efectos, familias y precio en ORO, y su validador"
```

---

### Task 4: Una pinta comprada con ORO es tuya para siempre

**Objetivo:** comprar una pinta con ORO (`OroShop.purchaseSkin`: `spendOro` y a
`engagement.shop.skins`) y que la sincronización de StoreKit no la borre ni la desequipe:
`allOwnedSkins` une las tres vías (IAP, milestone, ORO). En Pintas y en la ficha, una pinta de ORO
que no tenés muestra su precio en ORO (`PricePill(.oro)`), que tiembla si no alcanza.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` 🔥 (`allOwnedSkins`, una línea y su comentario)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift` (`purchaseSkin`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/OroSkinPurchaseTests.swift`
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (`SkinCatalogRow.State.oroPurchasable`, `skinState`, `buySkinWithOro`)
- Modify: `FisuEvolution/UI/Skins/CustomizationView.swift` (los `switch` sobre el estado y el botón)
- Modify: `FisuEvolution/UI/Popups/CharacterSheetView.swift` (el precio en ORO en la ficha)
- Create: `FisuEvolutionTests/OroSkinOwnershipTests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6b-t4.json` (1 clave)

**Interfaces:**
- Consumes: `ShopState.skins` (**E6a T1**); `OroShop`, `OroShopOutcome` (**E6a T2, T6**);
  `SkinsConfig.oroPrice(of:)` (T3); la ficha de **E3b T2**.
- Produces: `OroShop.SkinPurchaseError` (`alreadyOwned`, `cantAfford`),
  `OroShop.purchaseSkin(_:price:state:) throws`; `SkinCatalogRow.State.oroPurchasable(price: Int)`;
  `GameState.buySkinWithOro(skinID:) -> OroShopOutcome`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "public var skins: Set<String>" Packages/EconomyKit/Sources/EconomyKit/Shop/ShopState.swift` (E6a T1),
`grep -n "case .purchasable" FisuEvolution/UI/Skins/CustomizationView.swift FisuEvolution/UI/Popups/CharacterSheetView.swift`
(todo `switch` sobre `SkinCatalogRow.State` suma el caso nuevo) y
`grep -n "lockedDetails\|PricePill" FisuEvolution/UI/Popups/CharacterSheetView.swift` (la ficha de E3b T2).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/OroSkinPurchaseTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Comprar una pinta con ORO")
struct OroSkinPurchaseTests {
    @Test("cobra por spendOro y la deja entre las tuyas")
    func buys() throws {
        var state = fxState()
        state.meta.oro = 500
        try OroShop.purchaseSkin("neon", price: 150, state: &state)
        #expect(state.meta.oro == 350)
        #expect(state.meta.stats.oroSpentEver == 150)
        #expect(state.meta.engagement.shop.skins == ["neon"])
        #expect(state.meta.allOwnedSkins.contains("neon"))
    }

    @Test("no cobra lo que ya tenés, ni lo que no te alcanza")
    func refuses() throws {
        var state = fxState()
        state.meta.oro = 100
        #expect(throws: OroShop.SkinPurchaseError.cantAfford) { try OroShop.purchaseSkin("neon", price: 150, state: &state) }
        state.meta.milestoneSkins = ["neon"]
        state.meta.oro = 500
        #expect(throws: OroShop.SkinPurchaseError.alreadyOwned) { try OroShop.purchaseSkin("neon", price: 150, state: &state) }
        #expect(state.meta.oro == 500)
    }

    @Test("lo tuyo es la unión de las tres vías")
    func ownedIsTheUnion() {
        var state = fxState()
        state.meta.ownedSkins = ["mundialista"]
        state.meta.milestoneSkins = ["second_life"]
        state.meta.engagement.shop.skins = ["pijama"]
        #expect(state.meta.allOwnedSkins == ["mundialista", "second_life", "pijama"])
    }
}
```

`FisuEvolutionTests/OroSkinOwnershipTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Una pinta de ORO sobrevive a StoreKit")
@MainActor
struct OroSkinOwnershipTests {
    @Test("la sincronización de StoreKit no la borra ni la desequipa")
    func survivesTheSync() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        // "oro" viste a los 43: cualquier personaje sirve para equiparla.
        let type = content.tiers.baseType
        gameState.player?.meta.engagement.shop.skins.insert("oro")
        gameState.equipSkin(id: "oro", forCharacterType: type.id)
        #expect(gameState.activeSkinID(forCharacterType: type.id) == "oro")
        gameState.applyStoreEntitlements(removedAds: true, ownedSkins: [])
        #expect(gameState.ownsSkin("oro"))
        #expect(gameState.activeSkinID(forCharacterType: type.id) == "oro", "StoreKit no desequipa lo comprado con ORO")
    }

    @Test("una pinta sin precio en ORO no se vende por ORO")
    func notForSale() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 10_000
        #expect(gameState.buySkinWithOro(skinID: "mundialista") == .unavailable)
        #expect(gameState.player?.meta.oro == 10_000)
    }
}
```

(La compra de punta a punta, con una pinta de ORO de verdad en el catálogo, la prueba
`CosmeticsUITests` en la T8: hasta el gate de la galería, `skins.json` no tiene ninguna.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter OroSkinPurchaseTests` → no compila
(`purchaseSkin`). Receta R con `-only-testing:FisuEvolutionTests/OroSkinOwnershipTests` → FAIL
(`buySkinWithOro` no existe; y `survivesTheSync` rojo: StoreKit borra la pinta).

- [ ] **Step 3: EconomyKit**

🔥 `PlayerState.swift`:

```swift
    /// Todas las skins que el jugador posee: IAP ∪ milestones ∪ compradas con ORO.
    /// Las de ORO viven en `engagement.shop` porque `ownedSkins` es la caché de
    /// StoreKit y se reescribe entera en cada sincronización.
    public var allOwnedSkins: Set<String> {
        Set(ownedSkins).union(milestoneSkins).union(engagement.shop.skins)
    }
```

`OroShop.swift`:

```swift
    public enum SkinPurchaseError: Error, Equatable {
        case alreadyOwned
        case cantAfford
    }

    /// Una pinta con ORO: `spendOro` y a `shop.skins`. El precio lo trae quien
    /// llama, desde `skins.json` (`SkinsConfig.oroPrice(of:)`).
    public static func purchaseSkin(_ skinID: String, price: Int, state: inout PlayerState) throws {
        guard !state.meta.allOwnedSkins.contains(skinID) else { throw SkinPurchaseError.alreadyOwned }
        guard state.meta.spendOro(price) else { throw SkinPurchaseError.cantAfford }
        state.meta.engagement.shop.skins.insert(skinID)
    }
```

- [ ] **Step 4: La app**

`GameState+Store.swift`, en `SkinCatalogRow.State`:

```swift
        /// Skin que se compra con ORO en la tienda (E6) y todavía no tenés.
        case oroPurchasable(price: Int)
```

en `skinState(for:activeSkinID:)`, entre el milestone y el producto de StoreKit:

```swift
        if let price = content?.skins.oroPrice(of: entry.id) {
            return .oroPurchasable(price: price)
        }
```

y la compra:

```swift
    /// Compra con ORO una pinta de `skins.json`. Se equipa en Pintas o en la ficha,
    /// como cualquier otra (la tienda vende, no viste).
    @discardableResult
    func buySkinWithOro(skinID: String) -> OroShopOutcome {
        guard let content, var player, let price = content.skins.oroPrice(of: skinID) else { return .unavailable }
        do {
            try OroShop.purchaseSkin(skinID, price: price, state: &player)
        } catch OroShop.SkinPurchaseError.cantAfford {
            return .refused(.cantAfford)
        } catch {
            return .unavailable
        }
        self.player = player
        skinSelectionVersion &+= 1
        effectsVersion += 1
        evaluateAchievements()
        audio?.play(.coin)
        refreshProjections()
        scheduleSave()
        return .bought
    }
```

`CustomizationView.swift` — `SkinCard` suma `let oroBalance: Int` y `let buyWithOro: () -> Void`
(los pasa `card(_:asset:type:)`: `gameState.player?.meta.oro ?? 0` y
`{ gameState.buySkinWithOro(skinID: row.id) }`), y cada `switch row.state`:

```swift
        // tone
        case .purchasable, .oroPurchasable: .plain
```

```swift
        // el riel
        case .oroPurchasable(let price):
            PricePill(
                text: String(price),
                currency: .oro,
                affordable: oroBalance >= price,
                identifier: "skins.buyOro.\(row.id)",
                accessibilityPurpose: Text("skins.buy.ax \(row.displayName)"),
                action: buyWithOro
            )
```

```swift
        // axValue
        case .oroPurchasable(let price): String(price)
```

y en `isSilhouette`, `.oroPurchasable` va con `.purchasable` (lo que no tenés, en silueta: la regla
de Pintas; la tienda las muestra a color).

`CharacterSheetView.swift` (la de E3b T2): en `lockedDetails`, después del `PricePill` de
StoreKit, el de ORO:

```swift
        if let skin = selected.skin, let price = gameState.content?.skins.oroPrice(of: skin.id) {
            PricePill(
                text: String(price),
                currency: .oro,
                affordable: (gameState.player?.meta.oro ?? 0) >= price,
                identifier: "character.skin.buyOro",
                accessibilityPurpose: Text("skins.buy.ax \(skinName(selected))")
            ) {
                gameState.buySkinWithOro(skinID: skin.id)
            }
        }
```

y `unlockDescription` (el texto bajo el candado) suma la rama de ORO: `String(localized: "character.skin.oro_shop")`.

`Tools/v2/claves-pendientes/e6b-t4.json`:

```json
{
  "character.skin.oro_shop": {"es": "Se compra con ORO, acá o en la Tienda", "en": "Bought with ORO, here or in the Store"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6b-t4.json`.

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (`OroSkinPurchaseTests`: 3; `SkinMilestonesTests`
sin cambios). Receta R con
`-only-testing:FisuEvolutionTests/OroSkinOwnershipTests -only-testing:FisuEvolutionTests/SkinCatalogRowsTests -only-testing:FisuEvolutionUITests/CustomizationUITests -only-testing:FisuEvolutionUITests/CharacterSheetUITests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/OroSkinPurchaseTests.swift FisuEvolution/Game/State/GameState+Store.swift \
  FisuEvolution/UI/Skins/CustomizationView.swift FisuEvolution/UI/Popups/CharacterSheetView.swift \
  FisuEvolutionTests/OroSkinOwnershipTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6b-t4.json, según la ola
git diff --cached --stat
git commit -m "feat(skins): una pinta comprada con ORO es tuya y StoreKit no la borra"
```

---

### Task 5: Los efectos y las familias se ven — en el tablero, en Pintas, en la ficha y en la tienda

**Objetivo:** que una pinta de efecto se vea con su shader en el tablero (animada, con su fase por
personaje) y como foto quieta del mismo shader en SwiftUI; que una pinta de familia busque su
textura en el atlas de la familia (`fam_<familia>`) y no en el del personaje; y que la tienda de
ORO tenga su estante **Cosméticos** (entre Permanentes y Suerte, el orden de PLAN-v2) con los
efectos, las familias y las exclusivas, a color y con precio en ORO.

**Files:**
- Modify: `FisuEvolution/Managers/Store/SkinResolver.swift` (`atlas(for:characterType:config:)`)
- Create: `FisuEvolution/Managers/Store/SkinArt.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Scenes/PlaceholderRenderer.swift` (`skinAtlas:`)
- Modify: `FisuEvolution/Scenes/Nodes/CharacterNode.swift` (`skinShaderID:`, `appliedShaderID`)
- Modify: `FisuEvolution/Scenes/BoardScene.swift` 🔥 (los dos lugares que configuran un personaje: `:1443-1463`, `:1621-1640` en la base)
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (`SkinCatalogRow.textureAtlas`, `.shaderId`)
- Modify: `FisuEvolution/UI/Skins/CustomizationView.swift`, `FisuEvolution/UI/Popups/CharacterSheetView.swift` (la imagen por `SkinArt`)
- Create: `FisuEvolution/Game/State/GameState+Cosmetics.swift` (+ `xcodegen generate`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift` (`Shelf.cosmetics`)
- Modify: `FisuEvolution/UI/Store/OroShopView.swift` (el estante)
- Create: `FisuEvolutionTests/SkinEffectRenderingTests.swift`, `FisuEvolutionTests/CosmeticsRowsTests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6b-t5.json` (5 claves)

**Interfaces:**
- Consumes: `SkinShaders`, `SkinEffectRenderer` (T1); `SkinsConfig` v2 (T3); `buySkinWithOro`,
  `.oroPurchasable` (T4); `OroShopShelves`, `OroShopCopy.shelfKey` (**E6a T4, T8**);
  `AutoTapper.target(state:tiers:)` (**E6a T3**, para elegir a quién mostrarle el efecto).
- Produces: `SkinResolver.atlas(for:characterType:config:) -> String?`;
  `enum SkinArt { static func image(type:skinID:skins:manifest:side:) -> Image? }`;
  `PlaceholderRenderer.texture(for:manifest:skinTextureKey:skinAtlas:)`;
  `CharacterNode.configure(…, skinShaderID:)` y `appliedShaderID`;
  `struct CosmeticRow` (`id`, `kind`, `price`, `owned`) con `static func rows(skins:owned:)`;
  `GameState.cosmeticRows`, `cosmeticPreviewType`; `OroShopCatalog.Shelf.cosmetics`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "SkinResolver.treatment(" FisuEvolution/Scenes/BoardScene.swift` (los dos lugares
que configuran personajes: anotá sus líneas, E3a T10 y E4b pudieron moverlas) y
`grep -n "case let .texture(key) = treatment\|struct CharacterPortrait" FisuEvolution/UI/Popups/CharacterSheetView.swift`
(la ficha de E3b T2). Si `BoardScene.swift` tiene un dueño en la ola, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/SkinEffectRenderingTests.swift`:

```swift
import EconomyKit
import SpriteKit
import SwiftUI
import Testing
@testable import FisuEvolution

@Suite("Los efectos y las familias se ven")
@MainActor
struct SkinEffectRenderingTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private var skins: SkinsConfig {
        SkinsConfig(schemaVersion: 2, skins: [
            .init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150),
            .init(id: "pijama", characterType: content.tiers.baseType.id, treatment: .texture,
                  textureKey: "\(content.tiers.baseType.id)_idle__pijama", oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
        ])
    }

    @Test("una familia busca su textura en el atlas de la familia")
    func familyAtlas() {
        let base = content.tiers.baseType.id
        #expect(SkinResolver.atlas(for: "pijama", characterType: base, config: skins) == "fam_pijama")
        #expect(SkinResolver.atlas(for: "neon", characterType: base, config: skins) == nil)
        #expect(SkinResolver.atlas(for: nil, characterType: base, config: skins) == nil)
    }

    @Test("sin el atlas de la familia todavía, el tablero cae a la textura base")
    func missingFamilyArtFallsBack() throws {
        let type = content.tiers.baseType
        let texture = try #require(PlaceholderRenderer().texture(
            for: type, manifest: content.manifest, skinTextureKey: "\(type.id)_idle__pijama", skinAtlas: "fam_pijama"
        ))
        #expect(texture.size().width > 1)
    }

    @Test("el nodo lleva el shader del efecto, y lo suelta al reciclarse")
    func nodeCarriesTheShader() throws {
        let type = content.tiers.baseType
        let texture = PlaceholderRenderer().texture(for: type, manifest: content.manifest)
        let node = CharacterNode()
        node.configure(type: type, texture: texture, cellIndex: 3, cellSize: 70, hasRealArt: true, skinShaderID: "neon")
        #expect(node.appliedShaderID == "neon")
        node.configure(type: type, texture: texture, cellIndex: 3, cellSize: 70, hasRealArt: true)
        #expect(node.appliedShaderID == nil)
    }

    @Test("SwiftUI muestra la foto del efecto, no el arte pelado")
    func swiftUIShowsTheEffect() {
        let type = content.tiers.baseType
        #expect(SkinArt.image(type: type, skinID: "neon", skins: skins, manifest: content.manifest) != nil)
        #expect(SkinArt.image(type: type, skinID: nil, skins: skins, manifest: content.manifest) != nil)
    }
}
```

`FisuEvolutionTests/CosmeticsRowsTests.swift`:

```swift
import EconomyKit
import Testing
@testable import FisuEvolution

@Suite("El estante de Cosméticos")
struct CosmeticsRowsTests {
    private let skins = SkinsConfig(schemaVersion: 2, skins: [
        .init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150),
        .init(id: "pijama", characterType: "homeless", treatment: .texture, textureKey: "a", oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
        .init(id: "pijama", characterType: "cartonero", treatment: .texture, textureKey: "b", oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
        .init(id: "cohete", characterType: "repartidor", treatment: .texture, textureKey: "c", oroPrice: 150),
        .init(id: "urban", characterType: "cartonero", treatment: .texture, textureKey: "d", chestRarity: .comun),
    ])

    @Test("una fila por pinta de ORO, con su clase, su precio y si ya es tuya")
    func rows() {
        let rows = CosmeticRow.rows(skins: skins, owned: ["pijama"])
        #expect(rows.map(\.id) == ["neon", "pijama", "cohete"])
        #expect(rows[0].kind == .effect(shaderId: "neon"))
        #expect(rows[1].kind == .family(name: "pijama"))
        #expect(rows[2].kind == .outfit(characterType: "repartidor"))
        #expect(rows.map(\.price) == [150, 450, 150])
        #expect(rows.map(\.owned) == [false, true, false])
    }

    @Test("el estante va entre Permanentes y Suerte")
    func shelfOrder() {
        #expect(OroShopCatalog.Shelf.allCases == [.boosts, .shortcuts, .permanents, .cosmetics, .luck])
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/SkinEffectRenderingTests -only-testing:FisuEvolutionTests/CosmeticsRowsTests`.
Expected: no compila (`skinAtlas:`, `skinShaderID:`, `SkinArt`, `CosmeticRow`, `.cosmetics`).

- [ ] **Step 3: La resolución**

`SkinResolver.swift`:

```swift
    /// El atlas de la textura de una skin cuando no es el del personaje (las
    /// familias viven en `fam_<familia>`), o `nil`.
    static func atlas(for skinID: String?, characterType typeID: String, config: SkinsConfig) -> String? {
        guard let skinID else { return nil }
        return config.entries(forCharacterType: typeID).first { $0.id == skinID }?.textureAtlas
    }
```

`PlaceholderRenderer.texture(for:manifest:skinTextureKey:)` suma `skinAtlas: String? = nil` y busca
la textura de la skin en `skinAtlas ?? asset.atlas` (el respaldo a la base no cambia).

`FisuEvolution/Managers/Store/SkinArt.swift`:

```swift
import EconomyKit
import SwiftUI

/// La imagen de SwiftUI de un personaje con su pinta: la textura (en su atlas o
/// en el de su familia) o la foto del efecto con el MISMO shader del tablero.
/// Una sola resolución para Pintas, la ficha y la tienda. El tinte (`tint`) lo
/// pone quien la dibuja, con `colorMultiply`, como siempre.
@MainActor
enum SkinArt {
    static func image(
        type: CharacterType,
        skinID: String?,
        skins: SkinsConfig,
        manifest: AssetsManifest,
        side: CGFloat = 220
    ) -> Image? {
        guard let asset = manifest.characters[type.id] else { return nil }
        let base = UIArt.characterImage(atlas: asset.atlas, key: asset.key)
        switch SkinResolver.treatment(for: skinID, characterType: type.id, config: skins) {
        case .texture(let key):
            let atlas = SkinResolver.atlas(for: skinID, characterType: type.id, config: skins) ?? asset.atlas
            return UIArt.characterImage(atlas: atlas, key: key) ?? base
        case .effect(let shaderId):
            let texture = AtlasCache.atlas(named: asset.atlas).textureNamed(asset.key)
            guard let photo = SkinEffectRenderer.snapshot(of: texture, shaderID: shaderId, side: side) else { return base }
            return Image(decorative: photo, scale: 2)
        case .base, .tint:
            return base
        }
    }
}
```

- [ ] **Step 4: El tablero**

`CharacterNode.swift`: `configure(…)` suma `skinShaderID: String? = nil` al final;
`private(set) var appliedShaderID: String?`; en la rama `hasRealArt`, después de fijar la
textura y el tamaño:

```swift
            // El efecto va sobre el sprite y su `a_rect` es el de ESTA textura: se
            // aplica después de cambiarla. La fase sale de la celda para que dos
            // vecinos con el mismo efecto no latan juntos.
            SkinShaders.apply(skinShaderID, to: sprite, phase: Float(abs(cellIndex) % 7) * 0.9)
            appliedShaderID = sprite.shader == nil ? nil : skinShaderID
            return
```

y en la rama del placeholder, `SkinShaders.apply(nil, to: sprite, phase: 0)` y
`appliedShaderID = nil` (un nodo del pool nunca hereda el efecto de otro).

🔥 `BoardScene.swift`, en los dos lugares del paso 0 (el vuelo del ascenso y el render de los
placements): la llamada al renderer suma el atlas y la de `configure` el shader:

```swift
            texture: renderer.texture(
                for: type,
                manifest: content.manifest,
                skinTextureKey: { if case let .texture(key) = skinTreatment { return key }; return nil }(),
                skinAtlas: SkinResolver.atlas(for: gameState.activeSkinID(forCharacterType: type.id),
                                              characterType: type.id, config: content.skins)
            ),
```

```swift
            skinTint: SkinResolver.tintColor(for: skinTreatment),
            hasRealArt: hasRealArt,
            skinShaderID: { if case let .effect(id) = skinTreatment { return id }; return nil }()
```

- [ ] **Step 5: Pintas y la ficha**

`GameState+Store.swift`: `SkinCatalogRow` suma `let textureAtlas: String?` y `let shaderId: String?`
(la base: `nil` y `nil`; cada entrada: `entry.textureAtlas` y `entry.shaderId`).

`CustomizationView.swift`: `card(_:asset:type:)` resuelve la imagen con
`SkinArt.image(type: type, skinID: row.id == GameState.baseSkinRowID ? nil : row.id, skins: content.skins, manifest: content.manifest, side: 104)`
y se la pasa a `SkinCard` (`let art: Image?`), cuyo `previewImage` pasa a ser `art`; el respaldo a
la base ya lo hace `SkinArt`. `CharacterSheetView.swift`: el retrato grande y las miniaturas usan
`SkinArt.image(…)` en vez de buscar `.texture(key)` en el atlas del personaje (la silueta y el
tinte quedan como los dejó E3b T2).

- [ ] **Step 6: El estante de Cosméticos**

`OroShopCatalog.swift`, `Shelf` en el orden de PLAN-v2:

```swift
    public enum Shelf: String, Codable, Sendable, CaseIterable {
        case boosts, shortcuts, permanents
        /// Las pintas de ORO (`skins.json`, E6b): ningún ítem de `oro_shop.json` va acá.
        case cosmetics
        case luck
    }
```

`FisuEvolution/Game/State/GameState+Cosmetics.swift`:

```swift
import EconomyKit
import Foundation

/// Una fila del estante de Cosméticos: una pinta de ORO de `skins.json`.
struct CosmeticRow: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Un efecto para los 43.
        case effect(shaderId: String)
        /// Una familia dibujada para los 43.
        case family(name: String)
        /// Una pinta de un solo personaje (las exclusivas de ORO que elige el dueño).
        case outfit(characterType: String)
    }

    let id: String
    let kind: Kind
    let price: Int
    let owned: Bool

    static func rows(skins: SkinsConfig, owned: Set<String>) -> [CosmeticRow] {
        skins.oroSkinIDs.compactMap { id in
            guard let entry = skins.entry(id: id), let price = entry.oroPrice else { return nil }
            let kind: Kind
            if entry.treatment == .effect, let shader = entry.shaderId {
                kind = .effect(shaderId: shader)
            } else if let family = entry.family {
                kind = .family(name: family)
            } else {
                kind = .outfit(characterType: entry.characterType)
            }
            return CosmeticRow(id: id, kind: kind, price: price, owned: owned.contains(id))
        }
    }
}

extension GameState {
    var cosmeticRows: [CosmeticRow] {
        guard let content, let player else { return [] }
        return CosmeticRow.rows(skins: content.skins, owned: player.meta.allOwnedSkins)
    }

    /// A quién se le muestra un efecto o una familia en la tienda: al de tier más
    /// alto que tenés (el mismo criterio que el auto-tap).
    var cosmeticPreviewType: CharacterType? {
        guard let content, let player else { return nil }
        return AutoTapper.target(state: player, tiers: content.tiers) ?? content.tiers.baseType
    }
}
```

`OroShopView.swift`, en `OroShopShelves.body`, adentro del `ForEach` de estantes: para
`.cosmetics` se dibujan `gameState.cosmeticRows` (con su `SectionHeader` sólo si hay filas):

```swift
                if shelf == .cosmetics {
                    let cosmetics = gameState.cosmeticRows
                    if !cosmetics.isEmpty {
                        SectionHeader(LocalizedStringKey(OroShopCopy.shelfKey(.cosmetics)))
                            .frame(maxWidth: .infinity)
                            .padding(.top, Tokens.s8)
                        ForEach(cosmetics) { row in
                            CosmeticItemRow(row: row, preview: preview(for: row)) {
                                gameState.buySkinWithOro(skinID: row.id)
                            }
                        }
                    }
                } else {
                    // … lo de siempre (las filas de oro_shop.json) …
                }
```

con

```swift
    /// A color, siempre: en la tienda el arte es el argumento de venta (en Pintas,
    /// lo que no tenés va en silueta).
    private func preview(for row: CosmeticRow) -> Image? {
        guard let content = gameState.content else { return nil }
        let type: CharacterType? = switch row.kind {
        case .outfit(let typeID): content.tiers.type(id: typeID)
        case .effect, .family: gameState.cosmeticPreviewType
        }
        guard let type else { return nil }
        return SkinArt.image(type: type, skinID: row.id, skins: content.skins, manifest: content.manifest, side: 96)
    }
```

y la fila (privada, en el mismo archivo):

```swift
private struct CosmeticItemRow: View {
    @Environment(GameState.self) private var gameState
    let row: CosmeticRow
    let preview: Image?
    let buy: () -> Void

    private var name: String {
        gameState.content?.skins.entry(id: row.id).map(gameState.skinDisplayName(for:)) ?? row.id
    }

    private var detail: String {
        switch row.kind {
        case .effect: String(localized: "oroShop.cosmetic.effect")
        case .family: String(localized: "oroShop.cosmetic.family")
        case .outfit(let typeID):
            String(localized: "oroShop.cosmetic.outfit \(gameState.content?.tiers.type(id: typeID)?.localizedName ?? typeID)")
        }
    }

    var body: some View {
        GameCard {
            HStack(spacing: Tokens.s12) {
                Group {
                    if let preview { preview.resizable().scaledToFit() } else { Image(systemName: "sparkles") }
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name).font(Tokens.title).foregroundStyle(Color("PaletteInk")).lineLimit(1).minimumScaleFactor(0.6)
                    Text(verbatim: detail).font(Tokens.body).foregroundStyle(Color("PaletteBlue")).lineLimit(2).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if row.owned {
                    StateBadge(text: String(localized: "oroShop.cosmetic.owned"), systemImage: "checkmark.circle.fill",
                               textAlignment: .center, muted: false)
                        .frame(maxWidth: 110)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("oroShop.cosmetic.owned.\(row.id)")
                } else {
                    PricePill(
                        text: String(row.price),
                        currency: .oro,
                        affordable: (gameState.player?.meta.oro ?? 0) >= row.price,
                        identifier: "oroShop.cosmetic.buy.\(row.id)",
                        accessibilityPurpose: Text("oroShop.buy.ax \(name)"),
                        action: buy
                    )
                    .layoutPriority(1)
                }
            }
        }
    }
}
```

`Tools/v2/claves-pendientes/e6b-t5.json`:

```json
{
  "oroShop.shelf.cosmetics": {"es": "Cosméticos", "en": "Cosmetics"},
  "oroShop.cosmetic.effect": {"es": "Un efecto para tus 43 personajes", "en": "An effect for all 43 characters"},
  "oroShop.cosmetic.family": {"es": "La familia entera: los 43 personajes", "en": "The whole family: all 43 characters"},
  "oroShop.cosmetic.outfit %@": {"es": "Sólo para %@", "en": "Only for %@"},
  "oroShop.cosmetic.owned": {"es": "Tuya: ponétela en Pintas", "en": "Yours: wear it in Outfits"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6b-t5.json`. (`OroShopContentTests`
de E6a recorre `Shelf.allCases`: la clave del estante nuevo es la que lo deja en verde.)

- [ ] **Step 7: Verde, la medición y el oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/SkinEffectRenderingTests -only-testing:FisuEvolutionTests/CosmeticsRowsTests -only-testing:FisuEvolutionTests/OroShopContentTests -only-testing:FisuEvolutionTests/GameContentValidationTests -only-testing:FisuEvolutionTests/CharacterNodePoolTests`
→ PASS. **La medición de PLAN-v2** ("cuesta hasta +10 draws por piso"): en DEBUG, un piso con 15
personajes, la mitad con efectos distintos (equipados a mano con `equipSkin` desde la galería o
el panel) y `showsDrawCount` en el `SKView` del tablero: anotá los draws con y sin efectos en el
reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Managers/Store/SkinResolver.swift FisuEvolution/Managers/Store/SkinArt.swift \
  FisuEvolution/Scenes/PlaceholderRenderer.swift FisuEvolution/Scenes/Nodes/CharacterNode.swift \
  FisuEvolution/Scenes/BoardScene.swift FisuEvolution/Game/State/GameState+Store.swift \
  FisuEvolution/UI/Skins/CustomizationView.swift FisuEvolution/UI/Popups/CharacterSheetView.swift \
  FisuEvolution/Game/State/GameState+Cosmetics.swift Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift \
  FisuEvolution/UI/Store/OroShopView.swift FisuEvolutionTests/SkinEffectRenderingTests.swift \
  FisuEvolutionTests/CosmeticsRowsTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6b-t5.json, según la ola
git diff --cached --stat
git commit -m "feat(skins): los efectos se ven en el tablero y en foto, las familias usan su atlas, y la tienda vende Cosméticos"
```

---

### Task 6: Los lugares extra, en EconomyKit — la capacidad cambia en un solo lugar

**Objetivo:** el permanente de +3 y +2 lugares (PLAN-v2: "→ 18 → 20") agranda **la tabla de
pisos** y nada más: `FloorTable.expanded(by:)` devuelve la misma torre con `extra` lugares más en
cada piso. La torre, el reconciliador, el simulador y los pisos en marcha (E2a) ya leen la
capacidad de la tabla que reciben, así que no se enteran de que existe el permanente. Pineado:
una torre agrandada acomoda sin fusionar lo que antes desbordaba, y si los lugares se van (el
reset de E9) el reconciliador reacomoda con sus reglas de siempre.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/FloorTable.swift` (`expanded(by:)`, `FloorDef.withCapacity(_:)`, un `init` validado)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/ExtraSlotsTests.swift`

**Interfaces:**
- Consumes: `OroShop.extraSlots(levels:catalog:)` (**E6a T2**, en el test); `StaffedFloors`
  (**E2a T4**, un test).
- Produces: `FloorTable.expanded(by extra: Int) -> FloorTable` (no tira: la tabla ya está
  validada y la capacidad sólo crece); `FloorDef.withCapacity(_:) -> FloorDef`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "public let" Packages/EconomyKit/Sources/EconomyKit/FloorTable.swift` (los campos de
`FloorDef`: `withCapacity` los copia **todos**; si alguna épica sumó uno, va también) y
`grep -n "enum StaffedFloors" -r Packages/EconomyKit/Sources` (E2a T4). Sin `StaffedFloors`, el
último test se saltea (se borra de esta tarea y se anota en el reporte).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/ExtraSlotsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Lugares extra: la capacidad cambia en la tabla de pisos y en ningún otro lado")
struct ExtraSlotsTests {
    @Test("agranda todos los pisos y no mueve ningún tier")
    func expandsEveryFloor() throws {
        let table = try fxFloorTable()
        let bigger = table.expanded(by: 3)
        #expect(bigger.floors.map(\.capacity) == [8, 8])
        for tier in 1...4 {
            #expect(bigger.ordinal(forTier: tier) == table.ordinal(forTier: tier))
        }
        #expect(bigger.floors.map(\.id) == table.floors.map(\.id))
        #expect(table.expanded(by: 0) == table)
        #expect(table.expanded(by: -2) == table, "los lugares nunca restan")
    }

    @Test("la torre nace con los lugares de la tabla agrandada")
    func towerUsesTheTable() throws {
        let bigger = try fxFloorTable().expanded(by: 3)
        #expect(TowerState(floorTable: bigger).floors.map(\.slots.count) == [8, 8])
    }

    @Test("lo que desbordaba entra sin fusionar")
    func reconcileFitsMore() throws {
        let tiers = try fxTiers()
        var small = fxState(units: ["a": 8]).run
        let squeezed = TowerReconciler.reconcile(run: &small, floorTable: try fxFloorTable(), tiers: tiers)
        #expect(squeezed.autoMerged > 0, "con 5 lugares, 8 no entran")
        var roomy = fxState(units: ["a": 8]).run
        let fits = TowerReconciler.reconcile(run: &roomy, floorTable: try fxFloorTable().expanded(by: 3), tiers: tiers)
        #expect(fits.autoMerged == 0)
        #expect(fits.discarded.isEmpty)
        #expect(roomy.units["a"] == 8)
    }

    @Test("si los lugares se van, el reconciliador reacomoda con sus reglas")
    func shrinkingReconciles() throws {
        let tiers = try fxTiers()
        var run = fxState(units: ["a": 8]).run
        TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable().expanded(by: 3), tiers: tiers)
        let back = TowerReconciler.reconcile(run: &run, floorTable: try fxFloorTable(), tiers: tiers)
        #expect(back.autoMerged > 0)
        #expect(back.tower.floors[0].occupiedCount <= 5)
    }

    @Test("los niveles del permanente dan los lugares que dice el dato")
    func perkFromLevels() throws {
        let json = #"{"schemaVersion": 1, "items": [{"id": "extra_slots", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "extraSlots", "levels": [{"price": 600, "value": 3}, {"price": 1500, "value": 2}]}]}"#
        let catalog = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        let table = try fxFloorTable()
        #expect(table.expanded(by: OroShop.extraSlots(levels: ["extra_slots": 1], catalog: catalog)).floors[0].capacity == 8)
        #expect(table.expanded(by: OroShop.extraSlots(levels: ["extra_slots": 2], catalog: catalog)).floors[0].capacity == 10)
    }

    @Test("un piso en marcha con lugares extra pide más gente")
    func staffedNeedsMorePeople() throws {
        let tiers = try fxTiers()
        let state = fxState(units: ["a": 5])
        #expect(StaffedFloors.ordinals(state: state, tiers: tiers, floorTable: try fxFloorTable()) == [0])
        #expect(StaffedFloors.ordinals(state: state, tiers: tiers, floorTable: try fxFloorTable().expanded(by: 2)).isEmpty)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter ExtraSlotsTests`
Expected: no compila (`expanded(by:)`).

- [ ] **Step 3: La implementación**

`FloorTable.swift`, en `FloorDef`:

```swift
    /// El mismo piso con otra capacidad (los lugares extra de la tienda de ORO).
    /// Copia TODOS los campos: uno que se olvide acá cambia el piso en silencio.
    public func withCapacity(_ capacity: Int) -> FloorDef {
        FloorDef(
            id: id, background: background, firstTier: firstTier, lastTier: lastTier,
            capacity: capacity, incomeMultiplier: incomeMultiplier,
            hireCostMultiplierOverride: hireCostMultiplierOverride,
            hireCostGrowthOverride: hireCostGrowthOverride,
            unlockTierOverride: unlockTierOverride,
            backgroundOffset: backgroundOffset
        )
    }
```

y en `FloorTable`:

```swift
    /// Una tabla ya validada, con los mismos índices: lo usa `expanded(by:)`.
    private init(validated floors: [FloorDef], ordinalByTier: [Int], ordinalById: [String: Int]) {
        self.floors = floors
        self.ordinalByTier = ordinalByTier
        self.ordinalById = ordinalById
    }

    /// La misma torre con `extra` lugares más en cada piso: el permanente de la
    /// tienda de ORO (PLAN-v2 E6). Es el ÚNICO lugar donde cambia la capacidad: la
    /// torre, el reconciliador, los pisos en marcha y el simulador la leen de la
    /// tabla que reciben. No tira: la tabla ya está validada y sólo crece.
    public func expanded(by extra: Int) -> FloorTable {
        guard extra > 0 else { return self }
        return FloorTable(
            validated: floors.map { $0.withCapacity($0.capacity + extra) },
            ordinalByTier: ordinalByTier,
            ordinalById: ordinalById
        )
    }
```

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter ExtraSlotsTests` → PASS (6); el
paquete entero → PASS (`TowerReconcilerTests`, `FloorTableTests`, `ExtensibilityDrillTests` sin
cambios). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/FloorTable.swift Packages/EconomyKit/Tests/EconomyKitTests/ExtraSlotsTests.swift
git diff --cached --stat
git commit -m "feat(torre): los lugares extra agrandan la tabla de pisos, el único lugar donde vive la capacidad"
```

---

### Task 7: Los lugares extra en la partida — comprarlos, verlos y medir las 4 filas en el SE

**Objetivo:** el permanente "+3 / +2 lugares por piso" se vende en el estante de Permanentes
(600 / 1.500 ORO, PLAN-v2), y comprarlo agranda todos los pisos en el acto: la app reemplaza
`content.floorTable` por la tabla agrandada **antes** de reconstruir la torre (en la carga, al
reencarnar y al comprar), así el mapa, la ocupación, los pisos en marcha y la escena (que ya
arma las filas desde la capacidad, E3a T10) ven la capacidad nueva sin código propio. Y la
medición que pide PLAN-v2: las 4 filas en el iPhone SE.

**Files:**
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`baseFloorTable`, `var floorTable`)
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (`applyExtraSlots()` y dos llamadas)
- Modify: `FisuEvolution/Game/State/GameState+OroShop.swift` (comprar lugares rehace la torre)
- Modify: `FisuEvolution/Resources/Config/oro_shop.json` (el ítem `extra_slots`)
- Modify: `FisuEvolutionTests/OroShopContentTests.swift` (la tabla aprobada suma el ítem)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`--uitest-extra-slots`)
- Create: `FisuEvolutionTests/ExtraSlotsWiringTests.swift`, `FisuEvolutionUITests/ExtraSlotsLayoutUITests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6b-t7.json` (2 claves)

**Interfaces:**
- Consumes: `FloorTable.expanded(by:)` (T6); `OroShop.extraSlots(levels:catalog:)`,
  `buyOroShopItem` (**E6a T2, T6**); `OroShopContentTests` (**E6a T4**); `PlayLayout`,
  `board.layout`, `hud.elevator.display` (**E3a T8, T10**); `applyEngagementFixtures` (**E4a T9**);
  `packagesBlocked`, `debugAddPackages(_:)` (**E5a T6**: `packageCandidates` lee
  `content.floorTable`, así que el paquete ve la capacidad agrandada sin tocar E5).
- Produces: `GameContent.baseFloorTable: FloorTable`, `GameContent.floorTable` como `var`;
  `GameState.applyExtraSlots()`; el ítem `extra_slots`; la puerta `--uitest-extra-slots`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "func reconcileTower\|func resyncTower\|func replaceEconomy" FisuEvolution/Game/State/GameState.swift`
(las dos funciones que rehacen la torre; `replaceEconomy` es de E2a T9 y no se toca),
`grep -n "board.layout\|hud.elevator.display" -r FisuEvolution` (E3a T8/T10) y
`grep -n "let floorTable" FisuEvolution/Managers/GameContentLoader.swift`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/ExtraSlotsWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Lugares extra en la partida")
@MainActor
struct ExtraSlotsWiringTests {
    private func rich() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = 5_000
        return gameState
    }

    @Test("comprar los lugares agranda todos los pisos en el acto: torre, mapa y ocupación")
    func buyingGrowsEveryFloor() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.baseFloorTable.floors.map(\.capacity))
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.content?.floorTable.floors.map(\.capacity) == base.map { $0 + 3 })
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base[0] + 3)
        #expect(gameState.tower?.floors[0].slots.count == base[0] + 3)
        #expect(gameState.floorMap.last?.capacity == base[0] + 3, "el mapa dice cuánto entra")
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base[0] + 5)
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .refused(.maxed))
    }

    @Test("lo que desbordaba entra: con los lugares, nadie se fusiona solo al cargar")
    func moreRoomNoAutoMerge() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.baseFloorTable[0].capacity)
        gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true)
        let type = try #require(gameState.content?.tiers.baseType)
        gameState.player?.run.units = [type.id: base + 3]
        gameState.reconcileTower()
        #expect(gameState.player?.run.units[type.id] == base + 3)
    }

    @Test("los lugares se recuerdan: una carga nueva los vuelve a aplicar")
    func levelsArePersisted() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.baseFloorTable[0].capacity)
        gameState.player?.meta.engagement.shop.levels["extra_slots"] = 2
        gameState.reconcileTower()
        #expect(gameState.floorOccupancy(ordinal: 0).capacity == base + 5)
    }

    @Test("el Paquete de la Aduana (E5a) entra en los lugares comprados")
    func packagesUseTheExtraRoom() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(1)
        #expect(gameState.packagesBlocked, "con la torre llena, LLENO")
        #expect(gameState.buyOroShopItem(id: "extra_slots", chanceAllowed: true) == .bought)
        #expect(!gameState.packagesBlocked, "E5a lee content.floorTable: con los lugares nuevos, entra")
    }

    @Test("con 20 lugares, el tablero son 4 filas")
    func fourRows() {
        #expect(PlayLayout.rows(forCapacity: 20) == 4)
        #expect(PlayLayout(size: CGSize(width: 375, height: 667), capacity: 20).rows == 4)
    }
}
```

En `OroShopContentTests` (E6a T4): `approvedPrices` suma `"extra_slots": [600, 1500]` y
`rewardsAreTheTable` suma
`#expect(try item("extra_slots").perk == .extraSlots)` y
`#expect(try item("extra_slots").levels.map(\.value) == [3, 2])`.

`FisuEvolutionUITests/ExtraSlotsLayoutUITests.swift`:

```swift
import XCTest

/// Las 4 filas (el permanente de lugares extra) en la pantalla más chica que
/// soporta la app. No juzga el arte: deja la captura y pinea que el tablero
/// tenga la capacidad agrandada y el piso lleno. La medición de PLAN-v2 ("se mide
/// en el SE") se corre con un simulador SE (Task 7, paso 5).
final class ExtraSlotsLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheFullFloorWithExtraSlots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-extra-slots"]
        app.launch()
        let layout = app.descendants(matching: .any)["board.layout"]
        XCTAssertTrue(layout.waitForExistence(timeout: 20))
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 10))
        let marker = try XCTUnwrap(layout.value as? String)
        let rows = try XCTUnwrap(Int(marker.split(separator: "x")[1].split(separator: "@")[0]))
        let count = try XCTUnwrap(Int(units.value as? String ?? ""))
        XCTAssertEqual(rows, (count + 4) / 5, "las filas son las de la capacidad agrandada")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "E6 lugares extra, piso lleno (\(marker))"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/ExtraSlotsWiringTests`.
Expected: no compila (`baseFloorTable`).

- [ ] **Step 3: La tabla agrandada, en un solo lugar**

`GameContentLoader.swift`, en `GameContent`:

```swift
    /// La Torre (F7): mapeo tier→piso validado, derivado de `economy.floors`, CON
    /// los lugares extra del permanente de ORO aplicados (`GameState.applyExtraSlots`).
    /// Es lo que leen la torre, el reconciliador, el mapa y la escena.
    var floorTable: FloorTable
    /// La misma tabla tal como la declara `economy.json`, sin lugares extra.
    let baseFloorTable: FloorTable
```

(`let floorTable` pasa a `var`; el `return GameContent(...)` pasa `floorTable: floorTable` y
`baseFloorTable: floorTable`.)

🔥 `GameState.swift`, junto a `reconcileTower()`:

```swift
    /// Los lugares extra del permanente de ORO (E6) agrandan TODOS los pisos en un
    /// solo lugar: la tabla que leen la torre, el reconciliador, los pisos en
    /// marcha y la escena. Corre antes de reconstruir la torre: en la carga, al
    /// reencarnar y al comprar.
    func applyExtraSlots() {
        guard var content, let player else { return }
        let extra = OroShop.extraSlots(levels: player.meta.engagement.shop.levels, catalog: content.oroShop)
        let table = content.baseFloorTable.expanded(by: extra)
        guard table != content.floorTable else { return }
        content.floorTable = table
        self.content = content
    }
```

y su llamada, **primera línea** de `reconcileTower()` y de `resyncTower()`:

```swift
        applyExtraSlots()
```

`GameState+OroShop.swift`, en `buyOroShopItem`, después de entregar:

```swift
        if purchase.item.perk == .extraSlots {
            // La torre se rehace sobre la tabla agrandada sin mover el piso visible.
            resyncTower()
            bumpBoard()
        }
```

`oro_shop.json`, en el estante de Permanentes (antes de `better_supplier`):

```json
    {"id": "extra_slots", "shelf": "permanents", "iconKey": "ui_shop_extra_slots", "symbol": "square.grid.3x3.fill",
     "perk": "extraSlots",
     "levels": [{"price": 600, "value": 3}, {"price": 1500, "value": 2}]},
```

`GameState+Engagement.swift`, en `applyEngagementFixtures(arguments:)`:

```swift
        // Los dos niveles de lugares extra y el piso de abajo lleno: la foto de las
        // 4 filas sin jugar horas.
        if arguments.contains("--uitest-extra-slots"), var player, let content {
            player.meta.engagement.shop.levels["extra_slots"] = 2
            self.player = player
            reconcileTower()
            if var filled = self.player {
                filled.run.units = [content.tiers.baseType.id: self.content?.floorTable[0].capacity ?? 0]
                self.player = filled
                reconcileTower()
            }
        }
```

`Tools/v2/claves-pendientes/e6b-t7.json`:

```json
{
  "oroShop.item.extra_slots.name": {"es": "Ampliación", "en": "Expansion"},
  "oroShop.item.extra_slots.desc": {"es": "+%@ lugares en cada piso", "en": "+%@ spots on every floor"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6b-t7.json`.

- [ ] **Step 4: Verde**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/ExtraSlotsWiringTests -only-testing:FisuEvolutionTests/OroShopContentTests -only-testing:FisuEvolutionTests/OroShopPurchaseTests -only-testing:FisuEvolutionTests/FloorMapTests -only-testing:FisuEvolutionTests/CrowdDepthTests -only-testing:FisuEvolutionTests/PlayLayoutTests -only-testing:FisuEvolutionTests/PackageRuntimeTests`
→ PASS (`ExtraSlotsWiringTests`: 5; `PackageRuntimeTests` de E5a, sin cambios).

- [ ] **Step 5: La medición en el iPhone SE**

Con un simulador `"iPhone SE (3rd generation)"` (runtime 26.5, por UDID, se borra al terminar):
`-only-testing:FisuEvolutionUITests/ExtraSlotsLayoutUITests` → PASS, y su captura al reporte.
Anotá en el reporte:

1. la cabeza más alta de la fila de atrás contra el borde de abajo de `hud.elevator.display`
   (la vara del spike S5: con 3 filas había 4,5 pt de aire en el SE a 0,63);
2. la separación entre filas `BoardScene.crowdBand(sceneHeight: 667, cellSize: PlayLayout(size: CGSize(width: 375, height: 667), capacity: N).cellSize, rows: R).rowDepth`
   para la capacidad de 3 filas y la de 4 (`usable/3` contra `usable/4`), y cuántas celdas es;
3. si con la base en 10 (antes de E2b) los lugares extra dan 13/15 —3 filas—, la captura de 4
   filas se toma igual con `PlayLayout.rows(forCapacity: 20)` en un test de escena (E3a T10), y
   el reporte lo aclara.

Si la fila de atrás pisa el display o se tapa entera con la de adelante, **no se toca el
layout**: es 🔒 del dueño (opciones: un escalón más de `crowdTopRatio(rows: 4)`, sprites más
chicos con 4 filas, o el permanente sólo en pantallas grandes). Default: así, medido.

- [ ] **Step 6: Oráculo y commit**

Run: `Tools/v2/oraculo.sh completo` → `VERDE` (el `pacing-sim` no se mueve: el simulador no compra
lugares).

```bash
git add FisuEvolution/Managers/GameContentLoader.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/Game/State/GameState+OroShop.swift FisuEvolution/Resources/Config/oro_shop.json \
  FisuEvolution/Game/State/GameState+Engagement.swift FisuEvolutionTests/OroShopContentTests.swift \
  FisuEvolutionTests/ExtraSlotsWiringTests.swift FisuEvolutionUITests/ExtraSlotsLayoutUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6b-t7.json, según la ola
git diff --cached --stat
git commit -m "feat(tienda): los lugares extra agrandan todos los pisos en el acto, medidos en el SE"
```

---

### Task 8: 🔒 Los efectos aprobados entran — y las exclusivas de ORO que eligió el dueño

**Bloqueada por el gate de la T2.** Su entrada es la respuesta del dueño, anotada por el
controlador en `Docs/SESION-<fecha>-v2-e6.md`: la lista de **efectos aprobados** y la de
**exclusivas de ORO** (skins existentes que pasan a venderse con ORO en lugar de los efectos
descartados, con su precio si no es 150).

**Objetivo:** el catálogo vende lo aprobado: una entrada `effect` por efecto aprobado
(`characterType: "*"`, 150 ORO, su nombre en es + en) y, por cada exclusiva, su entrada existente
deja el cofre (o el milestone) y gana `oroPrice`. `skins.json` pasa a `schemaVersion: 2`. Un test
pinea la decisión del dueño, y un test de UI compra un efecto de punta a punta.

**Files:**
- Modify: `FisuEvolution/Resources/Config/skins.json`
- Create: `FisuEvolutionTests/OroSkinsContentTests.swift`, `FisuEvolutionUITests/CosmeticsUITests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6b-t8.json` (una clave por efecto aprobado)

**Interfaces:**
- Consumes: todo lo de T1–T5; la decisión del dueño.
- Produces: las skins de ORO de efecto en el catálogo real.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "Efectos aprobados\|exclusivas de ORO" Docs/SESION-*-v2-e6.md`. Sin la respuesta
del dueño: `BLOCKED` (no `NEEDS_CONTEXT`: no falta código, falta una decisión).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/OroSkinsContentTests.swift` (las dos listas se copian de la sesión; abajo, el
ejemplo con todos aprobados y ninguna exclusiva):

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Lo que el dueño aprobó en la galería (`Docs/SESION-…-v2-e6.md`).
@Suite("Las skins de ORO del catálogo")
@MainActor
struct OroSkinsContentTests {
    static let approvedEffects = ["neon", "holograma", "fantasma", "arcoiris", "glitch", "pixel", "oro_liquido", "sombra"]
    static let oroExclusives: [String: Int] = [:]

    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("los efectos aprobados, a 150, para los 43")
    func approvedEffects() throws {
        for id in Self.approvedEffects {
            let entry = try #require(content.skins.skins.first { $0.id == id && $0.treatment == .effect }, "falta \(id)")
            #expect(entry.characterType == "*")
            #expect(entry.shaderId == id)
            #expect(entry.oroPrice == 150)
        }
        let effects = Set(content.skins.skins.filter { $0.treatment == .effect }.map(\.id))
        #expect(effects == Set(Self.approvedEffects), "lo que el dueño no aprobó no se vende")
    }

    @Test("las exclusivas dejaron el cofre y se venden con ORO")
    func exclusives() throws {
        for (id, price) in Self.oroExclusives {
            let entries = content.skins.skins.filter { $0.id == id }
            #expect(!entries.isEmpty, "falta \(id)")
            #expect(entries.allSatisfy { $0.chestRarity == nil && !$0.isMilestone && $0.oroPrice == price })
        }
    }

    @Test("cada pinta de ORO tiene nombre en los dos idiomas", arguments: ["es", "en"])
    func names(language: String) throws {
        let bundle = try #require(Bundle(path: try #require(Bundle.main.path(forResource: language, ofType: "lproj"))))
        for id in content.skins.oroSkinIDs {
            let key = content.skins.entry(id: id)?.displayNameKey ?? "skin.name.\(id)"
            #expect(bundle.localizedString(forKey: key, value: "(falta)", table: nil) != "(falta)", "\(key) en \(language)")
        }
    }
}
```

`FisuEvolutionUITests/CosmeticsUITests.swift`:

```swift
import XCTest

/// Comprar un efecto con ORO en la tienda y ponérselo en Pintas (PLAN-v2 E6).
final class CosmeticsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBuyAnEffectAndItIsYours() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-oro=500"]
        app.launch()
        let store = app.buttons["hud.store"]
        XCTAssertTrue(store.waitForExistence(timeout: 20))
        store.tap()
        app.buttons["store.segment.spend"].tap()
        let buy = app.buttons["oroShop.cosmetic.buy.\(OroSkinsContentFirst.id)"]
        for _ in 0..<6 where !buy.exists { app.swipeUp() }
        XCTAssertTrue(buy.exists, "el primer efecto aprobado no se vende")
        buy.tap()
        XCTAssertTrue(app.descendants(matching: .any)["oroShop.cosmetic.owned.\(OroSkinsContentFirst.id)"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "E6 un efecto comprado"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// El primer efecto de la lista aprobada (el UI test no ve el catálogo).
private enum OroSkinsContentFirst {
    static let id = "neon"
}
```

(Si `neon` no quedó aprobado, `OroSkinsContentFirst.id` es el primero de la lista del dueño.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/OroSkinsContentTests`.
Expected: FAIL (`falta neon`).

- [ ] **Step 3: El dato**

`skins.json`: `"schemaVersion": 2`, y al final de `skins`, una entrada por efecto aprobado:

```json
    {
      "id": "neon",
      "characterType": "*",
      "treatment": "effect",
      "shaderId": "neon",
      "oroPrice": 150,
      "displayNameKey": "skin.name.neon"
    }
```

Por cada exclusiva de ORO: en sus entradas, se borra `chestRarity` (o el campo de milestone) y se
suma `"oroPrice": <precio>`. **Quien ya la tenía la conserva** (está en `milestoneSkins`); el
cofre deja de repartirla y su lugar en la bolsa lo toma el resto de su rareza (`ChestRoller`
promociona/degrada solo).

`Tools/v2/claves-pendientes/e6b-t8.json` (los aprobados de esta lista):

```json
{
  "skin.name.neon": {"es": "Neón", "en": "Neon"},
  "skin.name.holograma": {"es": "Holograma", "en": "Hologram"},
  "skin.name.fantasma": {"es": "Fantasma", "en": "Ghost"},
  "skin.name.arcoiris": {"es": "Arcoíris", "en": "Rainbow"},
  "skin.name.glitch": {"es": "Glitch", "en": "Glitch"},
  "skin.name.pixel": {"es": "Pixel", "en": "Pixel"},
  "skin.name.oro_liquido": {"es": "Oro líquido", "en": "Liquid Gold"},
  "skin.name.sombra": {"es": "Sombra", "en": "Shadow"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6b-t8.json`.

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con
`-only-testing:FisuEvolutionTests/OroSkinsContentTests -only-testing:FisuEvolutionTests/GameContentValidationTests -only-testing:FisuEvolutionTests/ChestSourcesTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionUITests/CosmeticsUITests`
→ PASS. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Resources/Config/skins.json FisuEvolutionTests/OroSkinsContentTests.swift FisuEvolutionUITests/CosmeticsUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6b-t8.json, según la ola
git diff --cached --stat
git commit -m "feat(skins): los efectos que aprobó el dueño se venden con ORO"
```

---

### Task 9: 🔒 Las tres familias entran — Pijama de Ositos, Gaucho y Disfraz de Dinosaurio

**Bloqueada por el arte de E8**: las 129 imágenes (43 × 3) generadas con la biblia de
`Docs/biblia-visitantes.md` e integradas por `process_dropbox.py` (categoría `skinfam`) en
`FisuEvolution/Resources/fam_pijama.atlas`, `fam_gaucho.atlas` y `fam_dinosaurio.atlas`, con las
claves `<tipo>_idle__<familia>`.

**Objetivo:** una familia se vende **sólo con sus 43**: 43 entradas en `skins.json` con el mismo
id (la convención de `oro` y `diamante`), `family`, `textureAtlas` y 450 ORO; un test que pinea
que cada textura existe en su atlas; y la medición del peso que pide PLAN-v2 (~44 MB).

**Files:**
- Modify: `FisuEvolution/Resources/Config/skins.json` (129 entradas)
- Create: `FisuEvolutionTests/FamilySkinsContentTests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6b-t9.json` (3 claves)

**Interfaces:**
- Consumes: T3, T5; los atlas de E8.
- Produces: las familias en el catálogo real.

- [ ] **Step 0: Pararse en la base**

Run: `ls FisuEvolution/Resources/ | grep "^fam_"` y, por cada atlas,
`ls FisuEvolution/Resources/fam_pijama.atlas | grep -c "@2x.png"` (tiene que dar 43). Una familia
con menos de 43 **no entra** (las otras sí): si ninguna está completa, `BLOCKED`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/FamilySkinsContentTests.swift`:

```swift
import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

/// Las familias dibujadas (PLAN-v2 E6): una familia se vende con los 43 o no se vende.
@Suite("Las tres familias")
@MainActor
struct FamilySkinsContentTests {
    /// Las que ya tienen su atlas completo (paso 0). Se suman de a una.
    static let families = ["pijama", "gaucho", "dinosaurio"]

    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("cada familia viste a los 43, con el mismo id y 450 de ORO", arguments: families)
    func everyCharacter(family: String) throws {
        let entries = content.skins.skins.filter { $0.family == family }
        #expect(Set(entries.map(\.characterType)) == Set(content.tiers.concreteTypes.map(\.id)))
        #expect(entries.allSatisfy { $0.id == family && $0.oroPrice == 450 && $0.textureAtlas == "fam_\(family)" })
    }

    @Test("cada textura existe en el atlas de su familia", arguments: families)
    func everyTextureExists(family: String) throws {
        let atlas = AtlasCache.atlas(named: "fam_\(family)")
        let names = Set(atlas.textureNames.map { $0.replacingOccurrences(of: "@2x", with: "").replacingOccurrences(of: "@3x", with: "").replacingOccurrences(of: ".png", with: "") })
        for entry in content.skins.skins where entry.family == family {
            let key = try #require(entry.textureKey)
            #expect(names.contains(key), "\(family): falta \(key)")
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/FamilySkinsContentTests`.
Expected: FAIL (ninguna entrada de familia).

- [ ] **Step 3: El dato**

Las 129 entradas se generan **una vez** desde los tipos del juego (un solo `python3` por llamada;
el script no se commitea). Para cada familia completa del paso 0:

```python
import json
from pathlib import Path

families = ["pijama", "gaucho", "dinosaurio"]          # sólo las del paso 0
res = Path("FisuEvolution/Resources")
tiers = json.loads((res / "Data/tiers.json").read_text())
manifest = json.loads((res / "Data/assets_manifest.json").read_text())
skins_path = res / "Config/skins.json"
skins = json.loads(skins_path.read_text())
types = [t for t in tiers["types"] if not t.get("isChoiceNode")]
for family in families:
    for t in types:
        key = manifest["characters"][t["id"]]["key"]
        skins["skins"].append({
            "id": family, "characterType": t["id"], "treatment": "texture",
            "textureKey": f"{key}__{family}", "textureAtlas": f"fam_{family}",
            "family": family, "oroPrice": 450, "displayNameKey": f"skin.name.{family}",
        })
skins_path.write_text(json.dumps(skins, indent=2, ensure_ascii=False) + "\n")
```

Después, `git diff --stat FisuEvolution/Resources/Config/skins.json` tiene que mostrar **sólo
líneas agregadas**: si el `json.dumps` reformateó el archivo entero, se descarta
(`git checkout -- FisuEvolution/Resources/Config/skins.json`) y se ajusta el formato del script al
del archivo (sangría, separadores, salto final) antes de volver a correrlo.

`Tools/v2/claves-pendientes/e6b-t9.json`:

```json
{
  "skin.name.pijama": {"es": "Pijama de Ositos", "en": "Teddy Pajamas"},
  "skin.name.gaucho": {"es": "Gaucho", "en": "Gaucho"},
  "skin.name.dinosaurio": {"es": "Disfraz de Dinosaurio", "en": "Dino Costume"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6b-t9.json`.

- [ ] **Step 4: Verde, el peso y el oráculo**

Run: Receta R con
`-only-testing:FisuEvolutionTests/FamilySkinsContentTests -only-testing:FisuEvolutionTests/GameContentValidationTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS (`textureSkinKeysFollowTheNamingConvention` también: la clave es `<base>__<familia>`). **El
peso**: `du -sh` del `.app` del build Release antes de esta tarea (la punta anterior) y después;
la diferencia va al reporte contra los ~44 MB de PLAN-v2. Si pasa de 60 MB, 🔒 dueño
(On-Demand Resources). `Tools/v2/oraculo.sh completo --limpio` → `VERDE` (atlas nuevos: sin
`--limpio` el build incremental no los compila).

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Resources/Config/skins.json FisuEvolutionTests/FamilySkinsContentTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6b-t9.json, según la ola
git diff --cached --stat
git commit -m "feat(skins): las familias dibujadas se venden con ORO, los 43 de cada una"
```

(Los atlas los commitea E8 al integrarlos, nunca esta tarea.)

---

### Task 10: Cierre de E6b

Lo hace **el controlador**:

1. `Tools/v2/oraculo.sh completo --limpio` sobre la punta de `v2/e6-tienda` → `VERDE`. La cuenta
   de `economykit` sube por `SkinsConfigV2Tests` (6), `OroSkinPurchaseTests` (3), `ExtraSlotsTests`
   (6); la de `unit`, por `SkinShadersTests`, `OroSkinOwnershipTests`, `SkinEffectRenderingTests`,
   `CosmeticsRowsTests`, `ExtraSlotsWiringTests`, `OroSkinsContentTests` y
   `FamilySkinsContentTests` (los dos últimos, cuando sus gates se abrieron); la UI, por
   `SkinGalleryCaptureUITests`, `ExtraSlotsLayoutUITests` y `CosmeticsUITests`.
2. Escenarios a mano: comprar un efecto, ponérselo a dos personajes y ver que no laten juntos;
   Reduce Motion en el simulador → los efectos quietos; comprar los dos niveles de lugares y ver
   el piso de 4 filas en un SE; comprar una familia (si entró) y ver los 43.
3. `Docs/SESION-<fecha>-v2-e6.md` (las fotos de la galería y la respuesta del dueño, las
   mediciones de draws, del SE y del peso), las cuatro ediciones de `Docs/HANDOFF.md` (§5: "la
   capacidad vive en la tabla de pisos", "una pinta de ORO vive en `shop.skins`", "no se vende lo
   que no se ve"; §7: las trampas; §9: el mapa), journal y `LOCK`.

```bash
git add Docs/SESION-<fecha>-v2-e6.md Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e6): cierre de E6b — lugares extra, pintas con ORO, efectos y familias"
```

---

## Lo que E6b le deja a otras épicas

- **E2b**: el simulador ya compra con la tabla que recibe: el perfil `.max` ("más los permanentes
  de la tienda") le pasa `floorTable.expanded(by: OroShop.extraSlots(...))` y nada más. Con la base
  en 15 (E2b), los lugares extra dan 18 y 20, que es la tabla de PLAN-v2.
- **E5**: nada que cambiar. Sus cofres (ruleta, colchón) cuentan las pintas de ORO como tenidas
  porque leen `allOwnedSkins` (T4), no reparten las exclusivas de ORO porque salen del
  `chestPool` (T8), y el Paquete ve los lugares extra porque `packageCandidates` lee
  `content.floorTable` (T7, pineado en `ExtraSlotsWiringTests`). Si E5 alguna vez arma su propia
  tabla de pisos, tiene que partir de `content.floorTable`, no de `baseFloorTable`.
- **E3a/E3b**: `crowdTopRatio(rows: 4)` sigue igual que el de 3 (su duda 11); la medición del SE
  de la T7 dice si hace falta un escalón (🔒 dueño). Las miniaturas de la ficha muestran el efecto
  quieto (la foto del shader); el tablero, animado.
- **E8**: las 129 imágenes de las familias con la biblia, por `process_dropbox.py` (`skinfam`); la
  T9 las vende cuando estén las 43 de cada una. El inventario de §5 ("Tienda de ORO, íconos de
  ítems ≈ 14") son los `iconKey` `ui_shop_<id>` de `oro_shop.json` (E6a T4) más
  `ui_shop_extra_slots`: con arte, la fila lo usa; sin arte, el SF Symbol.
- **E9** (sin plan): lecciones de "Cosméticos" (dónde se compra, dónde se pone), de los efectos
  (que se equipan por personaje en Pintas) y de los lugares extra (el piso de 4 filas). **Reset**:
  `engagement.shop.skins` y `shop.levels` son gasto de ORO: se borran con la partida salvo que el
  dueño diga otra cosa (duda 5). Si los lugares se van, el reconciliador reacomoda la torre con
  sus reglas (fusiona o descarta lo que sobra): el reset arranca de cero igual.
- **E10**: el peso del bundle medido en la T9 va a las notas de App Store Connect si pasa de los
  200 MB de descarga por datos móviles.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default anotado.

1. **Los lugares extra son +3 y +2 sobre la base, sea la que sea.** PLAN-v2 dice "→ 18 → 20"
   porque cuenta con la base de 15 que pasa E2b; con la base de hoy (10) darían 13 y 15. Default:
   deltas (+3, +2), en el dato; si E2b mueve la base, el permanente sigue sumando lo mismo.
2. **La capacidad no pasa a `slots.count`** (lo que pide PLAN-v2): el simulador y los pisos en
   marcha de E2a no tienen torre. Vive en la tabla de pisos, agrandada en un solo lugar. Default:
   así.
3. **Los efectos son globales**: comprar Neón lo da para los 43, y se equipa por personaje en
   Pintas (como `oro` y `diamante`). Default: así, a 150 cada uno.
4. **En Pintas y en la ficha el efecto se ve quieto** (una foto del mismo shader); en el tablero,
   animado. Hacerlo animado en SwiftUI pide un `SKView` por tarjeta. Default: quieto.
5. **¿Las pintas y los lugares comprados con ORO sobreviven al "Resetear partida" de E9?** PLAN-v2
   sólo dice "se conserva lo comprado" (con plata). Default: no (son gasto de ORO, y el ORO
   comprado se devuelve como `min(saldo, comprado)`); lo decide E9 con el dueño.
6. **Una exclusiva de ORO sale del cofre** (o del milestone): quien ya la tenía la conserva, y su
   lugar en la bolsa lo toman las demás de su rareza. Default: así.
7. **Sin el atlas completo, una familia no se vende** aunque las otras sí. Default: de a una.
8. **Los colores y ritmos de los 8 efectos son una primera versión** (`SkinShaders.swift`): la
   galería es para que el dueño los juzgue, y un ajuste suyo es cambiar un número.
9. **El permanente de lugares cambia el layout en el acto** (al comprarlo se rehace la torre sin
   mover el piso visible). Default: así, con el "ding" de la compra.

