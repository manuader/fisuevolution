# E8 — La integración del arte de la 2.0: el rentista, las 222 del batch y los fondos a 2048 · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que las 222 imágenes del batch de la 2.0 que aprobó el dueño, más el `rentista_soles`
regenerado con soles sólidos, estén en los atlas del juego con su entrada en `prompts.json` y en
el manifest, bajo las claves que ya esperan los planes que las consumen (E4b, E5b, E6a, E6b), sin
pasarse del gate de peso (60 MB) y sin que ninguna tarea consumidora tenga que esperar: el arte
entra antes que su código, y el código ya tiene respaldo para cuando falta.

**Architecture:** el juego no genera arte, lo integra (`Tools/asset-pipeline/README.md`). Cada PNG
viaja `generador/output/<clave>.png` → `dropbox/<assetKey>.png` → `process_dropbox.py` (recorte
por conectividad, `@2x`/`@3x` al atlas de su categoría, entrada en el manifest) →
`dropbox/procesadas/`. Este plan suma tres cosas al pipeline: el **alta** de la tanda (`prompts.json`
con `tanda: "v2"` y `generado_como` cuando la clave del juego no es la del generador), un
**traedor** (`scripts/traer_tanda.py <grupo>`) que copia un grupo entero con su nombre del juego,
y **dos reglas de exportación** (las caras de visitante al tamaño de las de la v1; los fondos como
un JPEG de 2048 sin sufijo de escala). Después, un lote por atlas.

**Tech Stack:** Python 3 (el venv del pipeline: Pillow, numpy, scipy; `rembg` sólo para la
revisión) · `unittest` · SpriteKit texture atlases (`.atlas`, compilados por Xcode) · XcodeGen
(el `.xcodeproj` no se versiona) · Swift Testing (un test nuevo en la T8).

**Fuente:** `Docs/PLAN-v2.md` §2 ("Fondos"), E3 "Arte", E6 "Familias", E8 y §5 (inventario);
`tasks.md` §5 E8 y §6 (gates "Batch de imágenes", "`rentista_soles`", "Peso de las familias");
`Docs/SESION-2026-10-06-v2-e8-pipeline.md` (categorías `npc`/`skinfam`, los soles lavados);
el proyecto generador `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/`
(`OBJETIVO.md`, `prompts/00_INDICE.md` y los 222 `.md`: **ese proyecto no tiene `prompts.json`**;
el mapa clave → destino lo arma este plan). Lo que queda abierto está en "Para el dueño / dudas",
con un default que no frena.

**Rama de la épica:** `v2/e8-arte`, desde `version-2`. Cada tarea sale de su punta en un worktree
propio (`Agent(isolation: "worktree")`) y el controlador integra de a una.

**Fuera de este plan** (siguen como filas sueltas de E8 en `tasks.md`): los loops de retrato y las
cinemáticas de Higgsfield (`video_assets.py`, `loops_manifest.json`), la cadena animada de
"Fusionar todo" y los 10 temas de música.

## Global Constraints

- **Un dueño por atlas y por archivo compartido.** `prompts.json` y `process_dropbox.py` los toca
  la T2 (y `process_dropbox.py` después la T8, en serie). Cada atlas tiene un solo lote:
  `cosmic.atlas` (T1), `fam_pijama.atlas` (T3), `fam_gaucho.atlas` (T4), `fam_dinosaurio.atlas`
  (T5), `npcs.atlas` (T6), `ui.atlas` (T7), `Backgrounds/` (T8). **`assets_manifest.json` es el
  caliente de esta épica**: lo escriben T6 (sección `npcs`, al final), T7 (`ui`, al final de su
  sección) y T8 (`backgrounds`). Van **una por ola**; las familias (T3–T5) no escriben el manifest
  y van al lado de cualquiera. `recut_assets.py`: T1 y después T9.
- **El PNG que se integra es el crudo del generador** (`output/<clave>.png`, 1024² sobre blanco;
  los fondos, 2048² ya escalados con Real-ESRGAN). **Nunca** `output/assets/` (es el recorte del
  generador) ni `originales-1254/`. El rentista sale de
  `~/Desktop/projects/automatic-image-generation/projects/fisu-retoques/output/rentista_soles.png`.
- **El recorte lo hace `process_dropbox.py` (conectividad, `whitebg_cutout`)**. Que la saliencia
  sea mejor en algún asset lo decide el dueño mirando (HANDOFF §5 decisión 6): eso es la T9, y no
  frena a nadie.
- **`test_assets_integrados` barre todo lo que entra** (itera `prompts.json`): ningún asset nuevo
  puede quedar con más de 1 % de hueco encerrado. Si uno salta, **no se lo mete en
  `RECORTE_VIEJO_A_PEDIDO` por las suyas**: se reporta con el asset y el porcentaje, y el
  controlador lo lleva a la T9.
- **Un lote que no completa no entra a medias** salvo las familias, que sí pueden entrar con menos
  de 43 (E6b T9 vende sólo las completas). Un PNG que falta en el generador → `BLOCKED` con la
  lista.
- **Atlas y build incremental** (HANDOFF §7, "reemplazar un PNG en el lugar no recompila el
  atlas"): para mirar el resultado en el simulador, DerivedData limpio o `touch` de la carpeta
  `.atlas`. El `rapido` de integración de cada ola de esta épica va con `--limpio`.
- **Los originales se commitean en `dropbox/procesadas/`** (convención de la casa: es de donde
  `recut_assets.py` y `elegir_recorte.py` recortan de nuevo). Atlas, manifest y `procesadas/` van
  en el mismo commit.
- **Sin Swift salvo la T8** (un test nuevo, `BackgroundArtTests`). Ninguna tarea toca
  `GameState.swift`, `RootView.swift`, `BoardScene.swift` ni el catálogo de strings. **Ninguna
  mueve plata.**
- **Commits en español, estilo `feat(arte): …` / `fix(arte): …` / `feat(pipeline): …`, SIN
  `Co-Authored-By`.** Staging selectivo por archivo y `git diff --cached --stat` antes de cada
  commit (un lote son cientos de archivos: el `--stat` tiene que contar lo esperado).
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración con
  `oraculo.sh rapido --limpio` → `Docs/SESION-<fecha>-v2-e8-arte.md` → las cuatro ediciones de
  `Docs/HANDOFF.md` → journal AVO y latido del `LOCK`. Ningún subagente toca `Docs/`,
  `handoffs/`, el journal, `tasks.md` ni `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
cd Tools/asset-pipeline
ln -sfn /Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/.venv .venv   # el worktree no trae venv
.venv/bin/python -m unittest discover -s tests -q
```

- Termina en `OK`. Hoy son 49 verdes (HANDOFF, sesión E8 pipeline); cada tarea dice cuántos suma.
  `test_assets_integrados` tarda (recorta los originales con permiso): no se corta.
- Las tareas que tocan el bundle de forma que un test de Swift lo ve corren además
  `Tools/v2/oraculo.sh tarea <Clases>` (lo dice cada una). El `rapido --limpio` y el Release van
  una vez por ola (controlador).
- ⚠️ "0 tests" con éxito no prueba nada: mirá que la salida nombre las clases.

## Las referencias, verificadas contra el árbol (`38b87ae`)

| Lo que cita la fuente | Dónde está hoy | Qué significa para E8 |
|---|---|---|
| `process_dropbox.py` con `npc` y `skinfam` | `ATLAS_BY_CATEGORY` (`scripts/process_dropbox.py:24-48`); `npc` → `npcs.atlas` + manifest `npcs` (sección nueva, `setdefault`); `skinfam` → `fam_{family}.atlas` sin manifest | los lotes usan las categorías tal cual |
| "Integrar = alta en `prompts.json`" | `prompts.json` tiene 321 entradas y **sólo 10 de las 222** (los `bg_*` de la v1); el generador **no tiene `prompts.json`**, sólo los `.md` | la T2 da de alta 212 (incluida la duplicada del ×3) y retoca las 10 de fondo |
| tamaños de export | `export_size` (`process_dropbox.py:55-68`): `background` (1024, 1536); personajes/skins/`npc`/`skinfam` (384, 512); `panel_`/`fisura_`/`logo` (448, 640); el resto (192, 256) | las caras `npc_*_face`/`sp_*_face` saldrían a 512 (720 KB el par, medido): la T2 las baja a 256 como las 43 caras de la v1 (`ui.atlas/<tipo>_face`); la ruleta (300 pt), las cajas del tablero (~96 pt) y la carta del Álbum suben de tamaño |
| fondos a 2048 | `Backgrounds/bg_<piso>@2x.png` (1024²) y `@3x.png` (1536²), 38 MB entre los diez; `FloorNode.render` (`Scenes/Nodes/FloorNode.swift:54-70`) hace aspect-fill sobre `texture.size()`, así que la escala del archivo no importa | la T8 los pasa a **un JPEG de 2048 sin sufijo** (`bg_<piso>.jpg`); el iPad (que es `@2x`) hoy dibuja el de 1024 |
| fondos en el manifest | `manifest.backgrounds[<piso>] = "bg_<piso>"`; `GameContentLoader.swift:70` exige la entrada; `FloorNode` y `FloorThumbnail` (`UI/Popups/FloorMapView.swift:374-381`) cargan con `UIImage(named:)` y caen a colores planos si no la encuentran | el manifest pasa a `"bg_<piso>.jpg"` y la T8 suma un test que pide que cada fondo **cargue**, no sólo que esté en el manifest |
| `rentista_soles` lavado | en `RECORTE_VIEJO_A_PEDIDO` (`scripts/recut_assets.py:43-86`); atlas `cosmic.atlas/rentista_soles_idle@2x/@3x.png`; original en `dropbox/procesadas/rentista_soles.png`; gate abierto en `tasks.md` §6 | T1. El nuevo es 1254² opaco sobre blanco: recortado por conectividad da **0,004 % de hueco** (medido sobre este plan) |
| el manifest decodifica sin `npcs` | `AssetsManifest` (`Managers/AssetsManifest.swift:8-21`) no tiene `npcs`; `JSONDecoder` ignora claves de más | la T6 puede escribir la sección antes de que E4b T1 sume el campo |
| `UIArt` = el manifest | `UIArtTests.uiArtKnowsItsArtBeforeTheBootstrap` (`GameArtComponentsTests.swift:300-306`): los nombres del bundle == `manifest.ui.keys` | la T7 lo corre |
| claves que esperan los consumidores | E5b: `pickup_package`, `pickup_package_lid`, `pickup_mattress` (+ `pickup_mattress_open` "si se hace") y `wheel_icon`; E6a T4: `ui_shop_<id>` de `oro_shop.json`; E6b: `ui_shop_extra_slots`; E4b T8: `ui_menu_specials`; E4b: `npcs["<id>"|"<id>_talk"|"<id>_action"|"<id>_face"]`; E6b T9: `fam_<familia>.atlas/<tipo>_idle__<familia>` | el generador usa otros nombres (`ui_oro_autotap`, `ui_package_closed`, `ui_menu_album`…): el alta los traduce con `generado_como` |

## El inventario: PNG del generador → destino en el juego

Los 222 del batch más el rentista. **Clave** = el `assetKey` de `prompts.json` y nombre del
archivo en `dropbox/`; si difiere del PNG del generador, la entrada lleva
`"generado_como": "<nombre del generador>"`.

### Visitantes y especiales (T6 → `npcs.atlas`, manifest `npcs`, categoría `npc`) — 52

| PNG del generador | Clave | Export | La consume |
|---|---|---|---|
| `npc_<n>.png` para n ∈ {comisario, sindicalista, turista, puntero, ministro, vecina, vendedor, conductor} (8) | igual | 384/512 | E4b T1 (el escenario), T2, T5 |
| `npc_<n>_talk.png`, `npc_<n>_action.png` (16) | igual | 384/512 | E4b T1/T2 (poses en escena; sin la pose, la canónica) |
| `npc_<n>_face.png` (8) | igual | **192/256** | E4b T3 (chip y popup), T4 (cara del presentador), E5b T1 (el Conductor en la ruleta) |
| `sp_<id>_talk.png` para id ∈ {cryptobro, demonio_arca, contador_dios, zombie_ceo, lizard, alien_investor, bug_simulacion, arbolito, coach, influencer} (10) | igual | 384/512 | E4b T2–T5 (los especiales como visitantes) |
| `sp_<id>_face.png` (10) | igual | **192/256** | E4b T3, T4, T8 (Álbum) |

### Familias de skins (T3/T4/T5 → `fam_<familia>.atlas`, sin manifest, categoría `skinfam`) — 129

| PNG del generador | Clave | Sprite | La consume |
|---|---|---|---|
| `<tipo>__pijama.png` (43) | igual | `fam_pijama.atlas/<tipo>_idle__pijama` | E6b T9 (la vende), T5 (resuelve el atlas), E6a T8 (estante Cosméticos) |
| `<tipo>__gaucho.png` (43) | igual | `fam_gaucho.atlas/<tipo>_idle__gaucho` | ídem |
| `<tipo>__dinosaurio.png` (43) | igual | `fam_dinosaurio.atlas/<tipo>_idle__dinosaurio` | ídem |

Los 43 tipos son los de `tiers.json`, de `homeless` a `god` (incluido `rentista_soles`).

### Paquete, Colchón, Ruleta, tienda y Álbum (T7 → `ui.atlas`, manifest `ui`, categoría `ui`) — 30 PNG, 31 claves

| PNG del generador | Clave en el juego | Export | La consume | Sin arte |
|---|---|---|---|---|
| `ui_package_closed` | `pickup_package` | 384/512 | E5b T3 (`PickupArt`), T2 (chip) | `PickupArt.placeholder`, `PackageGlyph` |
| `ui_package_lid` | `pickup_package_lid` | 384/512 | E5b T3 (la tapa que vuela) | ídem |
| `ui_package_opening` | `pickup_package_opening` | 384/512 | ⚠️ duda 4: carry a E5b T3 (cuadro de la apertura) | apertura procedural |
| `ui_package_open` | `pickup_package_open` | 384/512 | ⚠️ duda 4: carry a E5b T3 | ídem |
| `ui_package_full` | `pickup_package_full` | 384/512 | ⚠️ duda 4: carry a E5b T2/T3 (el cartel LLENO; el juego escribe la palabra encima) | chip "LLENO" por código |
| `ui_mattress_closed` | `pickup_mattress` | 384/512 | E5b T3 | `MattressGlyph` |
| `ui_mattress_open` | `pickup_mattress_open` | 384/512 | E5b T3 (lo pide el propio plan "si se hace") | ídem |
| `ui_mattress_icon` | `mattress_icon` | 192/256 | ⚠️ duda 4: carry a E5b T2 y E7b-b T3 (botón chico de la columna) | `MattressGlyph` |
| `ui_wheel_button` | `wheel_icon` | 192/256 | E5b T1/T2 (tarjetas y chips) | `WheelGlyph` |
| `ui_wheel_frame` | `wheel_frame` | **640/960** | ⚠️ duda 4: carry a E5b T1 (`WheelView`, 300 pt) | el `Canvas` de E5b |
| `ui_wheel_pointer` | `wheel_pointer` | 192/256 | ⚠️ duda 4: carry a E5b T1 | ídem |
| `ui_wheel_hub` | `wheel_hub` | 192/256 | ⚠️ duda 4: carry a E5b T1 | ídem |
| `ui_wheel_seg_jackpot` | `wheel_seg_jackpot` | 192/256 | ⚠️ duda 4: carry a E5b T1 (ícono del segmento) | ídem |
| `ui_wheel_seg_respin` | `wheel_seg_respin` | 192/256 | ⚠️ duda 4: carry a E5b T1 | ídem |
| `ui_oro_income_boost` | `ui_shop_income_x2` **y** `ui_shop_income_x3` | 192/256 | E6a T4/T8 | SF Symbol del dato |
| `ui_oro_package_rain` | `ui_shop_package_rain` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_autotap` | `ui_shop_auto_tap` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_time_skip` | `ui_shop_time_jump_1h` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_time_skip_big` | `ui_shop_time_jump_4h` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_offline_boost` | `ui_shop_offline_x3` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_daily_boost` | `ui_shop_daily_x3` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_skip_cooldown` | `ui_shop_skip_cooldowns` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_merge_all` | `ui_shop_merge_all` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_better_supplier` | `ui_shop_better_supplier` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_extra_spins` | `ui_shop_wheel_spins` | 192/256 | E6a T4/T8 | ídem |
| `ui_oro_extra_slots` | `ui_shop_extra_slots` | 192/256 | E6b T6/T7 | ídem |
| `ui_oro_skin_family` | `ui_shop_skin_family` | 192/256 | ⚠️ duda 4: carry a E6b T9 (la fila de la familia) | ídem |
| `ui_oro_skin_effect` | — | — | ⚠️ duda 5: **no entra** (el dueño descartó los efectos por código, E6b T1r) | — |
| `ui_menu_album` | `ui_menu_specials` | 192/256 | E4b T8 (`artKey(for: .specials)`) | el glifo del menú |
| `ui_album_card_frame` | `ui_album_card_frame` | **448/640** | ⚠️ duda 4: carry a E4b T8 (la carta) | `GameCard` |
| `ui_album_locked` | `ui_album_locked` | 192/256 | ⚠️ duda 4: carry a E4b T8 (el que falta) | silueta por código |

Sin arte en el batch, **quedan con respaldo** (SF Symbol del dato): `ui_shop_skin_chest` (cofre de
pintas, E6a) y `ui_offer_bienvenida`/`_renacer`/`_mudanza` (ofertas, E6a T11/T12). Ver duda 7.

### Fondos (T8 → `Backgrounds/`, manifest `backgrounds`, categoría `background`) — 10

| PNG del generador | Clave (ya existe en `prompts.json`) | En el juego | La consume |
|---|---|---|---|
| `bg_<piso>.png` (2048², RGB) para piso ∈ {alley, urban, corporate, luxury, island, moon, mars, solar, galaxy, god_realm} | `bg_<piso>` | `Backgrounds/bg_<piso>.jpg` (2048², q90), manifest `"bg_<piso>.jpg"`; se borran `bg_<piso>@2x.png` y `@3x.png` | todo el juego (`FloorNode`, `FloorMapView`, la precarga del vuelo); E10 (capturas) |

`bg_cosmic` sigue en `prompts.json` sin piso (`GameContentValidationTests.cosmicBackgroundIsGone`):
no se toca.

### Retoque (T1 → `cosmic.atlas`, manifest `characters` sin cambios)

| PNG | Clave | En el juego |
|---|---|---|
| `fisu-retoques/output/rentista_soles.png` (1254², opaco sobre blanco) | `rentista_soles` (ya existe, `character`, atlas `cosmic`) | `cosmic.atlas/rentista_soles_idle@2x/@3x.png` |

## Peso del bundle (gate: On-Demand Resources si crece > 60 MB)

Estimado sobre PNGs exportados de verdad (`whitebg_cutout` + `LANCZOS` + `PIL.save`, muestras del
batch) y sobre los promedios de los atlas de hoy. Es peso de `Resources/`; el `.app` compilado
(páginas de `.atlasc`, `pngcrush`) lo mide la T10.

| Lote | Piezas | Por par @2x+@3x (medido) | Total |
|---|---|---|---|
| Familias (T3–T5) | 129 | 248–395 KB (`homeless__pijama` 309, `ceo__gaucho` 248, `god__dinosaurio` 395) | **≈ 41 MB** |
| Visitantes, cuerpos (T6) | 34 | ~250 KB (`npc_comisario` 254, `sp_coach_talk` 243) | ≈ 8,5 MB |
| Visitantes, caras (T6) | 18 | 720 KB a 512 (`npc_vecina_face`) → ~200 KB a 256 | ≈ 3,5 MB (13 MB si quedaran a 512) |
| UI (T7) | 31 | 62–78 KB los íconos; la ruleta y las cajas, más | ≈ 3 MB |
| Fondos (T8) | 10 | hoy 3,8 MB (1,26 + 2,55); JPEG q90 2048 **1,05 MB** | **≈ −27 MB** |
| Rentista (T1) | 1 | reemplaza | ≈ 0 |
| **Total con los defaults** | | | **≈ +29 MB** |

Las alternativas para los fondos, medidas sobre `bg_alley`: PNG 2048 sólo `@2x` = 6,4 MB por piso
(**+26 MB**, total ≈ +82 MB → dispara el gate); PNG 2048 `@2x` + 1536 `@3x` (**+64 MB**, total
≈ +120 MB). Sin tocar los fondos, el resto solo suma ≈ +56 MB: al filo. Por eso el default de la
T8 es JPEG (duda 1). Las familias solas (≈ 41 MB) no disparan el gate de E6b T9.

**Memoria** (no es peso, pero sale de los fondos): una textura de 2048² son 16 MB decodificada.
`BoardScene.preloadFlightBackgrounds` precarga **todo** el rango del vuelo (hasta 10 pisos): hoy
≈ 94 MB en un iPhone `@3x` y 42 MB en un iPad; con 2048, ≈ 168 MB en los dos. La T8 lo mide
(duda 2).

**Repo** (tampoco es bundle): los originales a `procesadas/` suman ≈ 190 MB al historial de git
(91 familias, 35 visitantes, 13 UI, 51 fondos). Ver duda 9.

## Quién consume cada lote, y qué pasa mientras no está

Ninguna tarea de otra épica espera a E8 para escribirse: todas tienen respaldo por código. Lo que
cambia es qué se **ve** cuando el lote ya está.

| Lote | Tarea E8 | Tareas que lo consumen | Mientras no está | Destraba |
|---|---|---|---|---|
| Rentista | T1 | ninguna (reemplazo) | los soles lavados | cierra el gate `rentista_soles` de §6; el worktree `v2-e8-pipeline` se puede borrar |
| Familias | T3, T4, T5 | **E6b T9** (bloqueada por "arte de E8"), E6b T5, E6a T8 | la familia no se vende | **E6b T9 pasa de 🔒 a ⛔** (le queda T5); cada familia completa entra sola |
| Visitantes | T6 | E4b T1, T2, T3, T4, T5, T8; E5b T1 | canónica de la v1 (especiales), disco con símbolo (nuevos), cara recortada de la canónica | nada se destraba: E4b ya iba con respaldo; con el lote se ve el arte |
| UI | T7 | E5b T1, T2, T3; E6a T4, T8; E6b T6/T7, T9; E4b T8; E7b-b T3 | `PickupArt.placeholder`, `PackageGlyph`, `MattressGlyph`, `WheelGlyph`, SF Symbols, glifo del menú | ídem; las claves con ⚠️ entran como **carry** al brief de su consumidor |
| Fondos | T8 | todo el juego; E10 (capturas en iPad 13") | los de 1536 (iPad dibuja el de 1024) | la fila "Fondos regenerados a 2048 px" de E8 |

**Carries para los briefs** (el controlador los pega en el brief de la tarea consumidora cuando la
despache; no se editan los otros planes):

- **E4b T1/T2:** el manifest ya trae `npcs` (52 claves); `VisitorArt` lo lee en cuanto
  `AssetsManifest` sume el campo.
- **E4b T8:** `ui_menu_specials` existe. Hay también `ui_album_card_frame` (448/640, el marco
  dorado de la carta, con la ventana vacía) y `ui_album_locked` (silueta con candado): usarlos si
  no pelean con `GameCard` (FisuJobs manda); si no se usan, decirlo en el reporte.
- **E5b T1:** `wheel_icon`, y además `wheel_frame` (640/960, para los 300 pt de `WheelView`),
  `wheel_pointer`, `wheel_hub`, `wheel_seg_jackpot`, `wheel_seg_respin`, todos con el `Canvas`
  como respaldo.
- **E5b T2/T3:** `pickup_package`, `pickup_package_lid`, `pickup_mattress`, `pickup_mattress_open`,
  y además `pickup_package_opening`, `pickup_package_open` (cuadros de la apertura),
  `pickup_package_full` (cartel en blanco: el juego escribe "LLENO"/"FULL") y `mattress_icon`.
- **E6a T4:** los `iconKey` del `oro_shop.json` del plan ya coinciden con las claves de la T7; no
  se renombra nada.
- **E6b T9:** `ui_shop_skin_family` para la fila de las familias.
- **E7b-b T3:** `mattress_icon` para el botón del Colchón en la columna.

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Tools/asset-pipeline/scripts/recut_assets.py` | sale `rentista_soles` de `RECORTE_VIEJO_A_PEDIDO` | 1 |
| `Tools/asset-pipeline/prompts/prompts.json` | **el alta**: 212 entradas nuevas (incluida la duplicada del ×3) con `tanda: "v2"`; las 10 de fondo pasan a `tanda: "v2"` con el prompt del generador | 2 |
| `Tools/asset-pipeline/scripts/process_dropbox.py` | caras de visitante a 192/256 y los tamaños grandes de la 2.0 (T2); fondos como JPEG 2048 (T8) | 2, 8 |
| `Tools/asset-pipeline/scripts/traer_tanda.py` | **nuevo** — copia un grupo del generador al dropbox con su clave del juego | 2 |
| `Tools/asset-pipeline/tests/test_tanda_v2.py` | **nuevo** — el alta cubre el batch, cada clave tiene destino, el traedor renombra | 2 |
| `Tools/asset-pipeline/tests/test_process_dropbox.py` | los tamaños nuevos (T2) y el fondo JPEG (T8) | 2, 8 |
| `Tools/asset-pipeline/dropbox/procesadas/*.png` | los originales (223) | 1, 3–8 |
| `FisuEvolution/Resources/cosmic.atlas/rentista_soles_idle@2x/@3x.png` | el rentista nuevo | 1 |
| `FisuEvolution/Resources/fam_pijama.atlas/`, `fam_gaucho.atlas/`, `fam_dinosaurio.atlas/` | **nuevos** — 43 × 2 PNG cada uno | 3, 4, 5 |
| `FisuEvolution/Resources/npcs.atlas/` | **nuevo** — 52 × 2 PNG | 6 |
| `FisuEvolution/Resources/ui.atlas/` | 31 × 2 PNG nuevos | 7 |
| `FisuEvolution/Resources/Backgrounds/` | 10 `bg_<piso>.jpg`; se van los 20 PNG | 8 |
| `FisuEvolution/Resources/Data/assets_manifest.json` | `npcs` (T6), `ui` (T7), `backgrounds` (T8) | 6, 7, 8 |
| `FisuEvolutionTests/BackgroundArtTests.swift` | **nuevo** — cada fondo del manifest carga y mide 2048 | 8 |
| `Tools/asset-pipeline/scripts/revision_recortes.py` | la página de revisión mira también `npcs.atlas` y `fam_*.atlas` | 9 |

## Orden, olas y paralelismo

| T | Qué | 🔥 / tibios | Depende de | Compila | Plata |
|---|---|---|---|---|---|
| 1 | el rentista con soles sólidos | `cosmic.atlas`, `recut_assets.py` | — | no | no |
| 2 | el alta del batch y las reglas de export | `prompts.json`, `process_dropbox.py` | — | no | no |
| 3 | familia Pijama | `fam_pijama.atlas` | T2 | no | no |
| 4 | familia Gaucho | `fam_gaucho.atlas` | T2 | no | no |
| 5 | familia Dinosaurio | `fam_dinosaurio.atlas` | T2 | no | no |
| 6 | visitantes y especiales | `npcs.atlas`, 🔥 manifest (`npcs`) | T2 | `tarea` | no |
| 7 | Paquete, Colchón, Ruleta, tienda y Álbum | `ui.atlas`, 🔥 manifest (`ui`) | T2 | `tarea` | no |
| 8 | los fondos a 2048 | `Backgrounds/`, `process_dropbox.py`, 🔥 manifest (`backgrounds`) | T2 | `tarea` | no |
| 9 | 🔒 la revisión de recortes de la 2.0 | `recut_assets.py`, los atlas que cambie | T1, T3–T7 | no | no |
| 10 | peso, memoria y cierre | `Docs/` (controlador) | T1–T8 (T9 si ya volvió) | `completo --limpio` | no |

```
Ola 1 (ya, sin dependencias)     T1 rentista ║ T2 el alta
Ola 2                            T3 Pijama ║ T4 Gaucho ║ T5 Dinosaurio ║ T8 fondos   (T8 dueña del manifest)
Ola 3                            T6 visitantes                                       (T6 dueña del manifest)
Ola 4                            T7 UI                                               (T7 dueña del manifest)
Ola 5                            T9 la página de revisión → 🔒 dueño → aplicar ║ T10 cierre
```

**Reglas del paralelismo:**

1. T6, T7 y T8 escriben `assets_manifest.json`: **una por ola**, en cualquier orden. El orden de
   arriba pone primero la más riesgosa (T8: un fondo que no carga deja el piso de colores) y
   después la de E4b, que es la épica consumidora más cercana.
2. Las familias no compilan ni tocan el manifest: van al lado de cualquier tarea, de esta o de otra
   épica. T3–T5 corren juntas.
3. Ninguna tarea de E8 toca un 🔥 de otra épica (`GameState.swift`, `RootView.swift`,
   `BoardScene.swift`, el catálogo): E8 corre al lado de cualquier ola del run. Lo único que
   cuenta es el tope de **3 compilando** (T6, T7, T8 y T10 compilan).
4. Un lote es mecánico: **revisión ninguna** (el controlador lee el `--stat` y mira 3 PNG al azar).
   T2 y T8 cambian el pipeline: revisión **sonnet**.

---

### Task 1: El rentista con soles sólidos

**Objetivo:** el `rentista_soles` del tablero pasa a la versión que regeneró el dueño, con los 12
soles sólidos, recortada por conectividad; y sale de `RECORTE_VIEJO_A_PEDIDO`, porque el permiso
de "recorte viejo" era por los soles lavados y ya no hace falta. Cierra el gate `rentista_soles`
de `tasks.md` §6.

**Files:**
- Modify: `Tools/asset-pipeline/scripts/recut_assets.py` (una línea)
- Modify: `FisuEvolution/Resources/cosmic.atlas/rentista_soles_idle@2x.png`, `@3x.png`
- Modify: `Tools/asset-pipeline/dropbox/procesadas/rentista_soles.png` (el original nuevo)
- Sin cambios esperados: `FisuEvolution/Resources/Data/assets_manifest.json`, `prompts.json`

**Oráculo:** los tests del pipeline (49 → 49, sin tests nuevos: el barrido de
`test_assets_integrados` empieza a mirar al rentista, que hoy saltea).

- [ ] **Step 0: Pararse en la base**

```bash
cd Tools/asset-pipeline
ln -sfn /Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/.venv .venv
grep -n '"rentista_soles",' scripts/recut_assets.py      # una línea
ls ../../FisuEvolution/Resources/cosmic.atlas/rentista_soles_idle@3x.png
ls ~/Desktop/projects/automatic-image-generation/projects/fisu-retoques/output/rentista_soles.png
```

- [ ] **Step 1: Sacarlo de la lista**

Sacar `"rentista_soles",` de `RECORTE_VIEJO_A_PEDIDO` (dejar `"rentista_soles__jubilado"`, que es
otra skin y no cambia). Correr sólo el barrido:

```bash
.venv/bin/python -m unittest tests.test_assets_integrados -q
```

Esperado: **pasa igual** (el recorte viejo del atlas no tiene huecos encerrados: los soles lavados
son islas casi transparentes, no huecos; SESION E8 pipeline). No hay rojo que mostrar: el criterio
de esta tarea es el PNG.

- [ ] **Step 2: Integrar**

```bash
cp ~/Desktop/projects/automatic-image-generation/projects/fisu-retoques/output/rentista_soles.png dropbox/
.venv/bin/python scripts/process_dropbox.py
git status --short ../../FisuEvolution/Resources ../asset-pipeline/dropbox
git diff --stat ../../FisuEvolution/Resources/Data/assets_manifest.json   # vacío
```

Esperado: `✓ rentista_soles → cosmic.atlas/rentista_soles_idle@2x/@3x + manifest`; cambian los dos
PNG del atlas y `procesadas/rentista_soles.png`; el manifest no cambia (misma entrada). Si el
manifest cambia, parar y reportar el diff.

- [ ] **Step 3: Mirarlo**

Componer el `@3x` sobre gris medio (como se ve en el tablero) y mirar el PNG: los 12 soles enteros
y opacos, sin halo crema dentado, sin parche blanco entre el llavero y la bata (los dos costos de la
conectividad sobre el original viejo). Medir: alfa medio de los soles > 0,9.

- [ ] **Step 4: Oráculo y commit**

```bash
.venv/bin/python -m unittest discover -s tests -q
git add scripts/recut_assets.py dropbox/procesadas/rentista_soles.png \
  ../../FisuEvolution/Resources/cosmic.atlas/rentista_soles_idle@2x.png \
  ../../FisuEvolution/Resources/cosmic.atlas/rentista_soles_idle@3x.png
git diff --cached --stat
git commit -m "fix(arte): el rentista de los soles con sus doce soles enteros"
```

Reporte: los dos números (hueco, alfa de los soles) y que el manifest no cambió. Al integrar, el
controlador cierra el gate `rentista_soles` de §6 y avisa que el worktree `v2-e8-pipeline` ya se
puede borrar.

---

### Task 2: El alta del batch y las reglas de exportación

**Objetivo:** que `process_dropbox.py` conozca las 222 claves del batch con el nombre que espera el
juego, que un solo comando traiga un grupo del generador al dropbox, y que las piezas de la 2.0 se
exporten al tamaño al que se dibujan. No integra ninguna imagen.

**Files:**
- Modify: `Tools/asset-pipeline/prompts/prompts.json` (+212 entradas, 31 de ellas de UI con la duplicada del ×3; 10 retocadas)
- Modify: `Tools/asset-pipeline/scripts/process_dropbox.py` (`export_size`)
- Create: `Tools/asset-pipeline/scripts/traer_tanda.py`
- Create: `Tools/asset-pipeline/tests/test_tanda_v2.py`
- Modify: `Tools/asset-pipeline/tests/test_process_dropbox.py`
- Modify: `Tools/asset-pipeline/README.md` (la fila de `traer_tanda.py` y la regla de `generado_como`)

**Interfaces:**
- Produces: entradas `{assetKey, category, atlas?, tanda: "v2", prompt, generado_como?}`;
  `traer_tanda.GRUPOS` (`npc`, `pijama`, `gaucho`, `dinosaurio`, `ui`, `fondos`),
  `traer_tanda.origen(entry) -> Path`, `traer_tanda.traer(grupo, dropbox=DROPBOX) -> list[str]`;
  `export_size` con las caras y `TAMANO_POR_PREFIJO`.

**Oráculo:** los tests del pipeline (49 → ~58).

- [ ] **Step 1: Los tests, en rojo**

`tests/test_process_dropbox.py`, en `NpcCategoryTests`:

```python
    def test_a_visitor_face_exports_at_the_size_of_the_v1_faces(self):
        """Las 43 caras de la v1 viven en ui.atlas a 192/256 y el chip las dibuja chicas:
        a 512, las 18 caras de la 2.0 pesaban 13 MB en vez de 3,5."""
        self.assertEqual(export_size("npc", "npc_comisario_face"), export_size("ui", "homeless_face"))
        self.assertEqual(export_size("npc", "sp_coach_face"), export_size("ui", "homeless_face"))

    def test_the_poses_of_a_visitor_stay_at_the_size_of_a_character(self):
        self.assertEqual(export_size("npc", "npc_comisario_talk"), export_size("character", "homeless"))
```

Y una clase nueva:

```python
class BigUiPiecesTests(unittest.TestCase):
    """Las piezas de UI de la 2.0 que se dibujan más grandes que un ícono."""

    def test_the_wheel_frame_covers_the_300_points_of_the_wheel(self):
        self.assertGreaterEqual(export_size("ui", "wheel_frame")[1], 900)

    def test_the_board_pickups_export_like_a_character(self):
        self.assertEqual(export_size("ui", "pickup_package"), export_size("character", "homeless"))

    def test_the_album_card_exports_like_a_panel(self):
        self.assertEqual(export_size("ui", "ui_album_card_frame"), export_size("ui", "panel_menu"))

    def test_an_icon_stays_an_icon(self):
        self.assertEqual(export_size("ui", "wheel_icon"), (192, 256))
        self.assertEqual(export_size("ui", "ui_shop_auto_tap"), (192, 256))
```

`tests/test_tanda_v2.py`:

```python
"""El alta de la tanda de la 2.0: cada PNG del generador tiene destino, y el
traedor lo deja en el dropbox con la clave del juego."""

import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import traer_tanda  # noqa: E402
from process_dropbox import PIPELINE, SKIN_FAMILIES, destination  # noqa: E402

# Lo que el dueño aprobó y no tiene dónde ir (PLAN E8 "integración", duda 5).
SIN_DESTINO = frozenset({"ui_oro_skin_effect"})


def registro() -> list[dict]:
    return json.loads((PIPELINE / "prompts" / "prompts.json").read_text())


def tanda() -> list[dict]:
    return [e for e in registro() if e.get("tanda") == "v2"]


class AltaTests(unittest.TestCase):
    def test_no_asset_key_is_registered_twice(self):
        repetidas = [k for k, n in Counter(e["assetKey"] for e in registro()).items() if n > 1]
        self.assertEqual(repetidas, [])

    def test_every_entry_of_the_batch_has_a_destination(self):
        for entry in tanda():
            with self.subTest(entry["assetKey"]):
                destination(entry)

    def test_the_batch_has_the_size_of_the_plan(self):
        por_categoria = Counter(e["category"] for e in tanda())
        self.assertEqual(por_categoria, {"skinfam": 129, "npc": 52, "ui": 31, "background": 10})

    def test_every_family_has_its_43(self):
        familias = Counter(e["assetKey"].partition("__")[2] for e in tanda() if e["category"] == "skinfam")
        self.assertEqual(familias, {familia: 43 for familia in SKIN_FAMILIES})

    @unittest.skipUnless(traer_tanda.GENERADOR.is_dir(), "sin el proyecto generador")
    def test_every_png_of_the_generator_has_an_entry_or_a_reason(self):
        generados = {png.stem for png in traer_tanda.GENERADOR.glob("*.png")}
        cubiertos = {e.get("generado_como", e["assetKey"]) for e in tanda()}
        self.assertEqual(generados - cubiertos, set(SIN_DESTINO))
        self.assertEqual(cubiertos - generados, set())


class TraerTests(unittest.TestCase):
    def test_brings_a_group_with_the_key_of_the_game(self):
        with tempfile.TemporaryDirectory() as tmp:
            generador, dropbox = Path(tmp) / "out", Path(tmp) / "dropbox"
            generador.mkdir()
            (generador / "ui_oro_autotap.png").write_bytes(b"png")
            entradas = [{"assetKey": "ui_shop_auto_tap", "category": "ui", "tanda": "v2",
                         "generado_como": "ui_oro_autotap"}]
            with mock.patch.object(traer_tanda, "GENERADOR", generador), \
                 mock.patch.object(traer_tanda, "entradas_v2", return_value=entradas):
                traidas = traer_tanda.traer("ui", dropbox=dropbox)
            self.assertEqual(traidas, ["ui_shop_auto_tap"])
            self.assertEqual((dropbox / "ui_shop_auto_tap.png").read_bytes(), b"png")

    def test_one_png_can_feed_two_keys(self):
        claves = sorted(e["assetKey"] for e in tanda() if e.get("generado_como") == "ui_oro_income_boost")
        self.assertEqual(claves, ["ui_shop_income_x2", "ui_shop_income_x3"])

    def test_a_missing_png_fails_loudly(self):
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(traer_tanda, "GENERADOR", Path(tmp)), \
                 mock.patch.object(traer_tanda, "entradas_v2",
                                   return_value=[{"assetKey": "npc_x", "category": "npc", "tanda": "v2"}]):
                with self.assertRaises(FileNotFoundError):
                    traer_tanda.traer("npc", dropbox=Path(tmp) / "d")
```

Run: `.venv/bin/python -m unittest tests.test_process_dropbox tests.test_tanda_v2 -q`
Esperado: FAIL (`traer_tanda` no existe; las caras salen a 512).

- [ ] **Step 2: `export_size`**

En `process_dropbox.py`, arriba de `export_size`:

```python
# Piezas de UI de la 2.0 que se dibujan más grandes que un ícono.
TAMANO_POR_PREFIJO = (
    ("wheel_frame", (640, 960)),           # la ruleta mide 300 pt (WheelView, E5b)
    ("pickup_", (384, 512)),               # cajas y colchón del tablero, ~96 pt
    ("ui_album_card_frame", (448, 640)),   # la carta del Álbum de especiales
)
```

y en `export_size`, antes de la rama de personajes:

```python
    if category == "npc" and asset_key.endswith("_face"):
        return (192, 256)    # como las 43 caras de la v1 (ui.atlas): chip y Álbum
```

y antes de la rama `panel_`/`fisura_`/`logo`:

```python
    for prefijo, tamanos in TAMANO_POR_PREFIJO:
        if asset_key.startswith(prefijo):
            return tamanos
```

- [ ] **Step 3: `traer_tanda.py`**

```python
#!/usr/bin/env python3
"""Trae al dropbox un grupo de la tanda de la 2.0 desde el proyecto generador.

El generador nombra cada PNG con SU clave y el juego a veces espera otra
(`ui_oro_autotap` es `ui_shop_auto_tap` en `oro_shop.json`): la entrada de
`prompts.json` lo dice con `generado_como`. Un mismo PNG puede alimentar dos
claves (el ×2 y el ×3 de ingresos comparten ícono).

    .venv/bin/python scripts/traer_tanda.py pijama
    .venv/bin/python scripts/traer_tanda.py ui --dry-run
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import DROPBOX, PIPELINE  # noqa: E402

GENERADOR = (
    Path.home() / "Desktop" / "projects" / "automatic-image-generation"
    / "projects" / "fisu-evolution-v2" / "output"
)

GRUPOS = {
    "npc": lambda e: e["category"] == "npc",
    "pijama": lambda e: e["category"] == "skinfam" and e["assetKey"].endswith("__pijama"),
    "gaucho": lambda e: e["category"] == "skinfam" and e["assetKey"].endswith("__gaucho"),
    "dinosaurio": lambda e: e["category"] == "skinfam" and e["assetKey"].endswith("__dinosaurio"),
    "ui": lambda e: e["category"] == "ui",
    "fondos": lambda e: e["category"] == "background",
}


def entradas_v2() -> list[dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return [e for e in prompts if e.get("tanda") == "v2"]


def origen(entry: dict) -> Path:
    return GENERADOR / f"{entry.get('generado_como', entry['assetKey'])}.png"


def traer(grupo: str, dropbox: Path = DROPBOX, dry_run: bool = False) -> list[str]:
    elegidas = sorted((e for e in entradas_v2() if GRUPOS[grupo](e)), key=lambda e: e["assetKey"])
    faltan = [str(origen(e)) for e in elegidas if not origen(e).exists()]
    if faltan:
        raise FileNotFoundError(f"faltan en el generador: {faltan}")
    if not dry_run:
        dropbox.mkdir(parents=True, exist_ok=True)
        for entry in elegidas:
            shutil.copyfile(origen(entry), dropbox / f"{entry['assetKey']}.png")
    return [e["assetKey"] for e in elegidas]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("grupo", choices=sorted(GRUPOS))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    traidas = traer(args.grupo, dry_run=args.dry_run)
    print(f"{'se traerían' if args.dry_run else 'traídas'}: {len(traidas)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: El alta (datos)**

Con un script descartable en el scratchpad (no se commitea), leer los 222
`<generador>/prompts/NNN_<clave>.md` (el prompt es lo que sigue a `## Prompt`) y escribir en
`prompts.json`, **al final y en el orden del índice** (`00_INDICE.md`):

- `npc_*` y `sp_*_talk/_face` → `{"assetKey": <clave>, "category": "npc", "tanda": "v2", "prompt": …}`;
- `<tipo>__<familia>` → `{"assetKey": <clave>, "category": "skinfam", "tanda": "v2", "prompt": …}`;
- `ui_*` → con la clave de la tabla del inventario, `"category": "ui"`, `"atlas": "ui"`,
  `"tanda": "v2"`, `"prompt": …` y `"generado_como": <clave del generador>` cuando difiere;
  `ui_oro_income_boost` da **dos** entradas (`ui_shop_income_x2` y `ui_shop_income_x3`);
  `ui_oro_skin_effect` no entra;
- los 10 `bg_*` **ya existen**: se les pone `"tanda": "v2"` y se reemplaza `prompt` por el del
  generador (el que de verdad hizo la imagen). No se agrega ninguna entrada de fondo.

El JSON se escribe con el mismo formato que ya tiene (`json.dumps(…, indent=2,
ensure_ascii=False)` + salto final): `git diff` tiene que mostrar sólo agregados al final y los
10 retoques. Los `.md` **no** se copian a `prompts/gemini_pro/` (duda 8).

- [ ] **Step 5: Verde, README y commit**

```bash
.venv/bin/python -m unittest discover -s tests -q          # todo verde
.venv/bin/python scripts/traer_tanda.py ui --dry-run       # se traerían: 31
.venv/bin/python scripts/traer_tanda.py pijama --dry-run   # se traerían: 43
```

README, sección "Integrar un asset nuevo": una línea para la tanda de la 2.0
(`scripts/traer_tanda.py <grupo>` en lugar del paso 3 a mano, y qué es `generado_como`).

```bash
git add prompts/prompts.json scripts/process_dropbox.py scripts/traer_tanda.py \
  tests/test_tanda_v2.py tests/test_process_dropbox.py README.md
git diff --cached --stat
git commit -m "feat(pipeline): el alta de las 222 de la 2.0 y un traedor por grupo"
```

---

### Task 3: La familia Pijama de Ositos

**Objetivo:** las 43 skins de la familia Pijama en `fam_pijama.atlas`, con la clave
`<tipo>_idle__pijama` que espera E6b T9.

**Files:**
- Create: `FisuEvolution/Resources/fam_pijama.atlas/` (86 PNG)
- Create: `Tools/asset-pipeline/dropbox/procesadas/<tipo>__pijama.png` (43)

**Oráculo:** los tests del pipeline (sin tests nuevos: el barrido de `test_assets_integrados`
suma 86 PNG).

- [ ] **Step 0:** `.venv/bin/python scripts/traer_tanda.py pijama --dry-run` → 43. Si no, `BLOCKED`
  con la lista.
- [ ] **Step 1: Integrar**

```bash
ls dropbox/*.png 2>/dev/null          # vacío: el dropbox arranca limpio
.venv/bin/python scripts/traer_tanda.py pijama
.venv/bin/python scripts/process_dropbox.py
ls ../../FisuEvolution/Resources/fam_pijama.atlas | grep -c "@2x.png"     # 43
git diff --stat ../../FisuEvolution/Resources/Data/assets_manifest.json  # vacío
```

- [ ] **Step 2: Mirar** una hoja de contacto de los 43 `@3x` sobre gris (script descartable en el
  scratchpad). Anotar en el reporte los que traen **loza blanca a los pies** (sombra del piso que
  la conectividad conserva) o **islas de papel** (blanco encerrado que no es dibujo): no se
  arreglan acá, van a la T9.
- [ ] **Step 3: Oráculo y commit**

```bash
.venv/bin/python -m unittest discover -s tests -q
git add ../../FisuEvolution/Resources/fam_pijama.atlas dropbox/procesadas/*__pijama.png
git diff --cached --stat     # 129 archivos
git commit -m "feat(arte): la familia Pijama de Ositos, los 43"
```

Si un asset salta en `test_assets_integrados`, **no** se commitea ese asset (se borra su par del
atlas y su original vuelve al generador): la familia entra con 42 y el reporte lo dice. E6b T9 no
la vende hasta que esté completa.

---

### Task 4: La familia Gaucho

Igual que la Task 3 con `gaucho`: `traer_tanda.py gaucho`, `fam_gaucho.atlas`,
`procesadas/*__gaucho.png`, commit `feat(arte): la familia Gaucho, los 43`.

---

### Task 5: La familia Disfraz de Dinosaurio

Igual que la Task 3 con `dinosaurio`: `traer_tanda.py dinosaurio`, `fam_dinosaurio.atlas`,
`procesadas/*__dinosaurio.png`, commit `feat(arte): la familia Disfraz de Dinosaurio, los 43`.
⚠️ `homeless__dinosaurio` fue el piloto (004): está en el generador como los otros, sin trato
aparte.

---

### Task 6: Los visitantes y los especiales

**Objetivo:** las 52 piezas de visitantes (8 nuevos × canónica, hablando, acción y cara; 10
especiales × hablando y cara) en `npcs.atlas`, y la sección `npcs` del manifest con las 52
claves, que es el contrato que E4b ya lee (`manifest.npcs["<id>"|"<id>_talk"|…]`).

**Files:**
- Create: `FisuEvolution/Resources/npcs.atlas/` (104 PNG)
- Modify: `FisuEvolution/Resources/Data/assets_manifest.json` (sección `npcs`, nueva, al final)
- Create: `Tools/asset-pipeline/dropbox/procesadas/npc_*.png`, `sp_*_talk.png`, `sp_*_face.png` (52)

**Oráculo:** los tests del pipeline; `Tools/v2/oraculo.sh tarea GameContentValidationTests
GameArtComponentsTests` (el manifest sigue decodificando con una sección que el código todavía
no conoce, y `UIArt` no cambia).

- [ ] **Step 0:** `traer_tanda.py npc --dry-run` → 52; el manifest no tiene `npcs`
  (`grep -c '"npcs"' ../../FisuEvolution/Resources/Data/assets_manifest.json` → 0).
- [ ] **Step 1: Integrar**

```bash
.venv/bin/python scripts/traer_tanda.py npc
.venv/bin/python scripts/process_dropbox.py
python3 -c "import json;m=json.load(open('../../FisuEvolution/Resources/Data/assets_manifest.json'));print(len(m['npcs']))"   # 52
sips -g pixelWidth ../../FisuEvolution/Resources/npcs.atlas/npc_comisario_face@3x.png   # 256
sips -g pixelWidth ../../FisuEvolution/Resources/npcs.atlas/npc_comisario@3x.png        # 512
```

- [ ] **Step 2: Mirar** la hoja de contacto de las 52: la camiseta del Turista con el **67** (guiño
  aprobado, PLAN-v2 §2); ninguna marca, insignia ni texto; las caras centradas. Lo raro va al
  reporte (y a la T9 si es de recorte).
- [ ] **Step 3: Oráculo y commit**

```bash
.venv/bin/python -m unittest discover -s tests -q
cd ../.. && Tools/v2/oraculo.sh tarea GameContentValidationTests GameArtComponentsTests; cd -
git add ../../FisuEvolution/Resources/npcs.atlas ../../FisuEvolution/Resources/Data/assets_manifest.json \
  dropbox/procesadas/npc_*.png dropbox/procesadas/sp_*_talk.png dropbox/procesadas/sp_*_face.png
git diff --cached --stat     # 157 archivos
git commit -m "feat(arte): los ocho visitantes y las poses nuevas de los especiales"
```

---

### Task 7: Paquete, Colchón, Ruleta, tienda de ORO y Álbum

**Objetivo:** las 31 claves de UI de la tabla del inventario en `ui.atlas` y en `manifest.ui`,
con los nombres que ya usan E5b, E6a, E6b y E4b; `ui_oro_skin_effect` no entra.

**Files:**
- Modify: `FisuEvolution/Resources/ui.atlas/` (+62 PNG)
- Modify: `FisuEvolution/Resources/Data/assets_manifest.json` (31 entradas al final de `ui`)
- Create: `Tools/asset-pipeline/dropbox/procesadas/<clave>.png` (31: el del ×3 es copia del ×2)

**Oráculo:** los tests del pipeline; `Tools/v2/oraculo.sh tarea GameArtComponentsTests
GameContentValidationTests` (`UIArt.bundledNames() == manifest.ui.keys`).

- [ ] **Step 0:** `traer_tanda.py ui --dry-run` → 31; ninguna de las 31 claves existe hoy en
  `manifest.ui` ni en `ui.atlas` (`ls ui.atlas | grep -c '^pickup_\|^wheel_\|^ui_shop_\|^mattress_'` → 0).
- [ ] **Step 1: Integrar**

```bash
.venv/bin/python scripts/traer_tanda.py ui
.venv/bin/python scripts/process_dropbox.py
sips -g pixelWidth ../../FisuEvolution/Resources/ui.atlas/wheel_frame@3x.png      # 960
sips -g pixelWidth ../../FisuEvolution/Resources/ui.atlas/pickup_package@3x.png   # 512
sips -g pixelWidth ../../FisuEvolution/Resources/ui.atlas/ui_shop_auto_tap@3x.png # 256
```

- [ ] **Step 2: Mirar** la hoja de contacto de las 31 sobre el pergamino (`PaletteCream`): el
  marco de la ruleta y el de la carta con la **ventana vacía** (el juego dibuja adentro; si el
  recorte se comió el borde interior o dejó papel en la ventana, al reporte); el cartel LLENO en
  blanco, sin letras; las cajas y el colchón sin loza blanca.
- [ ] **Step 3: Oráculo y commit**

```bash
.venv/bin/python -m unittest discover -s tests -q
cd ../.. && Tools/v2/oraculo.sh tarea GameArtComponentsTests GameContentValidationTests; cd -
git add ../../FisuEvolution/Resources/ui.atlas ../../FisuEvolution/Resources/Data/assets_manifest.json \
  dropbox/procesadas/pickup_*.png dropbox/procesadas/mattress_icon.png dropbox/procesadas/wheel_*.png \
  dropbox/procesadas/ui_shop_*.png dropbox/procesadas/ui_menu_specials.png dropbox/procesadas/ui_album_*.png
git diff --cached --stat     # 94 archivos
git commit -m "feat(arte): las cajas, el colchón, la ruleta, la tienda y el Álbum"
```

---

### Task 8: Los fondos a 2048

**Objetivo:** los 10 fondos regenerados a 2048 px entran como un JPEG por piso, sin sufijo de
escala, y el iPad deja de estirar el de 1024. Un test pide que cada fondo del manifest **cargue**
(hoy sólo se pide que esté en el manifest, y un fondo que no carga cae a colores planos sin que
nada falle).

**Files:**
- Modify: `Tools/asset-pipeline/scripts/process_dropbox.py` (`export_background`; la rama
  `background` sale de `export_size`)
- Modify: `Tools/asset-pipeline/tests/test_process_dropbox.py`
- Modify: `FisuEvolution/Resources/Backgrounds/` (+10 `.jpg`, −20 `.png`)
- Modify: `FisuEvolution/Resources/Data/assets_manifest.json` (los 10 valores de `backgrounds`)
- Modify: `Tools/asset-pipeline/dropbox/procesadas/bg_*.png` (los originales de 2048)
- Create: `FisuEvolutionTests/BackgroundArtTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Produces: `process_dropbox.export_background(img, asset_key) -> str` (devuelve el nombre del
  archivo con extensión, que es lo que va al manifest); `BACKGROUND_SIDE = 2048`,
  `BACKGROUND_QUALITY = 90`.

**Oráculo:** los tests del pipeline (+2); `Tools/v2/oraculo.sh tarea BackgroundArtTests
GameContentValidationTests`.

- [ ] **Step 1: Los tests, en rojo**

`tests/test_process_dropbox.py`, en `ProcessNewCategoriesTests` (que ya monta un `Resources` de
mentira):

```python
    def test_a_background_becomes_one_2048_jpeg_and_retires_its_pngs(self):
        backgrounds = self.resources / "Backgrounds"
        backgrounds.mkdir()
        for escala in ("@2x", "@3x"):
            Image.new("RGB", (8, 8)).save(backgrounds / f"bg_alley{escala}.png")
        path = self.root / "bg_alley.png"
        Image.new("RGB", (64, 64), "teal").save(path)
        with redirect_stdout(io.StringIO()):
            process_dropbox.process(path, {"assetKey": "bg_alley", "category": "background"})

        self.assertEqual(sorted(p.name for p in backgrounds.iterdir()), ["bg_alley.jpg"])
        self.assertEqual(self.size_of(backgrounds / "bg_alley.jpg"), (2048, 2048))
        manifest = json.loads(self.manifest.read_text())
        self.assertEqual(manifest["backgrounds"], {"alley": "bg_alley.jpg"})

    def test_a_background_is_never_cut_out(self):
        path = self.root / "bg_moon.png"
        Image.new("RGB", (64, 64), "white").save(path)
        with redirect_stdout(io.StringIO()):
            process_dropbox.process(path, {"assetKey": "bg_moon", "category": "background"})
        with Image.open(self.resources / "Backgrounds" / "bg_moon.jpg") as image:
            self.assertEqual(image.getpixel((32, 32)), (255, 255, 255))
```

`FisuEvolutionTests/BackgroundArtTests.swift`:

```swift
import Testing
import UIKit
@testable import FisuEvolution

/// Un fondo que no carga no rompe nada: `FloorNode` cae a dos colores planos.
/// Por eso no alcanza con que esté en el manifest (`floorBackgroundsExistInManifest`).
@Suite("Los fondos de los pisos")
@MainActor
struct BackgroundArtTests {
    private let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("cada piso tiene un fondo que carga")
    func everyFloorBackgroundLoads() throws {
        for floor in content.floorTable.floors {
            let name = try #require(content.manifest.backgrounds[floor.background], "\(floor.id)")
            #expect(UIImage(named: name) != nil, "\(floor.id): \(name) no carga")
        }
    }

    @Test("los fondos de la 2.0 miden 2048")
    func backgroundsAre2048() throws {
        for (stage, name) in content.manifest.backgrounds {
            let image = try #require(UIImage(named: name), "\(stage)")
            #expect(image.size.width * image.scale >= 2048, "\(stage): \(image.size.width * image.scale) px")
        }
    }
}
```

Run: los del pipeline → FAIL (`bg_alley@2x/@3x.png` siguen; el manifest dice `bg_alley`).
`/opt/homebrew/bin/xcodegen generate` y `Tools/v2/oraculo.sh tarea BackgroundArtTests` → la
primera pasa, la segunda FAIL (1536).

- [ ] **Step 2: `export_background`**

En `process_dropbox.py`:

```python
# Fondos de la 2.0 (PLAN-v2 E3 "Arte"): un solo JPEG de 2048 sin sufijo de escala.
# Son opacos y `FloorNode` hace aspect-fill sobre el tamaño de la textura, así que
# la escala del archivo no importa; el iPad, que es @2x, deja de dibujar el de
# 1024. En PNG los diez sumaban +26 MB al bundle; en JPEG restan 27.
BACKGROUND_SIDE = 2048
BACKGROUND_QUALITY = 90


def export_background(img, asset_key: str) -> str:
    """Escribe `Backgrounds/<key>.jpg` y retira los PNG de la v1. Devuelve el nombre
    con extensión, que es lo que el juego busca con `UIImage(named:)`."""
    from PIL import Image

    target_dir = RESOURCES / "Backgrounds"
    target_dir.mkdir(parents=True, exist_ok=True)
    name = f"{asset_key}.jpg"
    side = (BACKGROUND_SIDE, BACKGROUND_SIDE)
    img.convert("RGB").resize(side, Image.LANCZOS).save(target_dir / name, quality=BACKGROUND_QUALITY)
    for escala in ("@2x", "@3x"):
        (target_dir / f"{asset_key}{escala}.png").unlink(missing_ok=True)
    return name
```

En `process`: si `category == "background"`, `asset_name = export_background(img, asset_key)` en
lugar de `export_atlas`, y la rama `backgrounds` del manifest guarda `asset_name`. La rama
`background` de `export_size` se borra (ya no la usa nadie; `recut_assets.py` saltea fondos).

- [ ] **Step 3: Integrar los diez, en una sola pasada**

⚠️ Entre el borrado de los PNG y el manifest nuevo no se buildea (HANDOFF §3: un piso sin fondo no
arranca). `process` hace las dos cosas por fondo, así que la ventana es el comando:

```bash
.venv/bin/python scripts/traer_tanda.py fondos        # 10
.venv/bin/python scripts/process_dropbox.py
ls ../../FisuEvolution/Resources/Backgrounds          # 10 .jpg, ningún .png
du -sh ../../FisuEvolution/Resources/Backgrounds      # ≈ 11 MB (hoy 37 MB)
```

- [ ] **Step 4: El ojo y la memoria**

1. **Calidad:** por cada fondo, el PSNR del JPEG contra el PNG de 2048 (> 40 dB) y un recorte al
   100 % de la zona más fina (bordes de edificios, estrellas) lado a lado, PNG y JPEG. Si algún
   fondo muestra bloques, ese fondo va a `quality=95` (un número más, en el reporte).
2. **Memoria:** con el simulador del oráculo, la app en Debug, volar del piso 1 al 10 (panel de
   debug: desbloquear pisos y usar el ascensor) y medir con
   `footprint -p $(pgrep -f 'FisuEvolution.app/FisuEvolution')` antes y durante el vuelo, con
   los fondos de hoy (la base, compilada aparte) y con los nuevos. Anotar los dos picos en el
   reporte. **No se arregla acá** (duda 2).

- [ ] **Step 5: Oráculo y commit**

```bash
.venv/bin/python -m unittest discover -s tests -q
cd ../.. && /opt/homebrew/bin/xcodegen generate && Tools/v2/oraculo.sh tarea BackgroundArtTests GameContentValidationTests; cd -
git add scripts/process_dropbox.py tests/test_process_dropbox.py dropbox/procesadas/bg_*.png \
  ../../FisuEvolution/Resources/Backgrounds ../../FisuEvolution/Resources/Data/assets_manifest.json \
  ../../FisuEvolutionTests/BackgroundArtTests.swift
git diff --cached --stat     # 10 jpg nuevos, 20 png borrados, 10 originales, manifest, 3 de código
git commit -m "feat(arte): los diez fondos a 2048, en JPEG"
```

---

### Task 9: 🔒 La revisión de recortes de la 2.0

**Objetivo:** que el dueño elija a ojo, como con la v1, qué assets de la 2.0 van con la saliencia
en vez de la conectividad, y que su elección quede aplicada y protegida del próximo
`recut_assets.py`. **No frena a nadie**: mientras tanto el juego usa la conectividad.

**Files:**
- Modify: `Tools/asset-pipeline/scripts/revision_recortes.py` (`ATLASES` suma `npcs.atlas` y los
  tres `fam_*.atlas`; los sprites de `npcs` no terminan en `_idle`: el filtro los incluye por
  atlas)
- Modify (al aplicar): `Tools/asset-pipeline/scripts/recut_assets.py`
  (`RECORTE_VIEJO_A_PEDIDO`), los atlas de los assets elegidos

**Oráculo:** los tests del pipeline.

- [ ] **Step 1:** extender `ATLASES` y correr
  `.venv/bin/python scripts/revision_recortes.py --salida ~/Desktop/revision-v2`, con la lista
  de sospechosos de los reportes de T3–T7 primero. Commit del script
  (`feat(pipeline): la revisión de recortes mira los atlas de la 2.0`).
- [ ] **Step 2 (🔒 dueño):** el dueño recorre la página y baja `decisiones.json`. El controlador
  marca la tarea 🔒 hasta que vuelva.
- [ ] **Step 3:** `.venv/bin/python scripts/aplicar_revision.py ~/Desktop/revision-v2/decisiones.json`;
  tests del pipeline; commit `fix(arte): los recortes de la 2.0 que eligió el dueño` con los atlas
  tocados y `recut_assets.py`.

---

### Task 10: Peso, memoria y cierre de E8 arte (controlador)

**Objetivo:** medir el bundle de verdad contra el gate de 60 MB, dejar asentada la memoria de los
fondos y cerrar las filas de E8 y los gates de §6.

- [ ] **Step 1: El peso.** `Tools/v2/oraculo.sh completo --limpio` sobre la punta. Del Release que
  arma, `du -sk` del `.app` y de cada `.atlasc`/`Backgrounds`; lo mismo sobre `version-2` antes de
  E8 (el Release del último `completo` de referencia). Si la diferencia pasa de **60 MB**, 🔒
  dueño: On-Demand Resources para `fam_*.atlas` (es lo único que se carga a pedido sin tocar el
  arranque) o PNG cuantizado en las familias.
- [ ] **Step 2: Docs.** `Docs/SESION-<fecha>-v2-e8-arte.md` con: los números del peso (estimado
  contra medido), los dos picos de memoria de la T8, los sospechosos de recorte y lo que eligió el
  dueño; las cuatro ediciones de `Docs/HANDOFF.md` (§4 la sesión; §5 "los fondos son JPEG de 2048
  sin sufijo" y "`generado_como`"; §7 "un asset del batch que salta en `test_assets_integrados`
  no se mete solo en `RECORTE_VIEJO_A_PEDIDO`"; §9 este plan).
- [ ] **Step 3: `tasks.md`.** E8: las filas "El batch de imágenes" y "Fondos regenerados a 2048
  px" → ✅; §6: "Batch de imágenes" ✅, "`rentista_soles`" ✅ (con T1), "Peso de las familias"
  según el Step 1; E6b T9 de 🔒 a ⛔ (le queda T5) en cuanto entran T3–T5.

```bash
git add Docs/SESION-*-v2-e8-arte.md Docs/HANDOFF.md tasks.md
git diff --cached --stat
git commit -m "docs(v2-e8): cierre de la integración del arte de la 2.0"
```

---

## Lo que E8 arte le deja a otras épicas

- **E4b:** `npcs.atlas` con las 52 piezas y `manifest.npcs`; T1 suma `AssetsManifest.npcs` y con
  eso `VisitorArt` deja el respaldo solo. Las caras son de 256 (85 pt nítidos): si el Álbum
  dibuja el retrato más grande, usa la canónica o la pose, no la cara.
- **E5b:** las claves `pickup_*`, `mattress_icon` y `wheel_*` (carries de arriba). `WheelView`
  puede dibujar el marco de arte debajo del `Canvas` de segmentos: el marco viene con la ventana
  vacía.
- **E6a:** íconos de la tienda con las claves de su `oro_shop.json`; quedan con SF Symbol el cofre
  de pintas y las tres ofertas.
- **E6b:** los tres atlas de familias completos (si un asset no entró, el reporte de su tarea lo
  dice y T9 vende esa familia cuando se complete); `ui_shop_extra_slots` y `ui_shop_skin_family`.
- **E10:** las capturas del iPad 13" ya salen con los fondos de 2048; el peso medido en T10 va a
  las notas si pasa de los 200 MB de descarga por datos móviles.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default anotado hasta que el dueño diga otra cosa.

1. **Los fondos van en JPEG.** A 2048 en PNG los diez suman +26 MB (sólo `@2x`) o +64 MB (`@2x` y
   `@3x`), y con el resto del batch el bundle pasa el gate de 60 MB. **Default:** un JPEG q90 de
   2048 por piso, sin sufijo de escala (≈ 1 MB cada uno, −27 MB contra hoy); la T8 mide el PSNR
   y mira recortes al 100 %. Si el dueño no quiere JPEG: PNG 2048 sólo `@2x` (+26 MB, total
   ≈ +82 MB) y se decide On-Demand Resources para las familias.
2. **La precarga del vuelo con fondos de 2048.** `preloadFlightBackgrounds` carga todos los pisos
   del rango: ≈ 168 MB de texturas en un vuelo del 1 al 10 (hoy ≈ 94 MB en iPhone y 42 MB en
   iPad). PLAN-v2 hablaba de "hasta 5 en vuelo". **Default:** la T8 mide y reporta; si el pico
   preocupa, es una tarea aparte en `BoardScene.swift` (🔥, fuera de E8) que limita la precarga a
   los pisos que de verdad se ven; la salida del PLAN ("2048 sólo en iPad") queda de reserva.
3. **Las caras de visitante a 256.** `process_dropbox` las exportaba a 512 como un personaje
   (720 KB el par). **Default:** 192/256, como las 43 caras de la v1 (≈ −9,5 MB); nítidas hasta
   85 pt, que cubre chips y popups.
4. **Piezas que el batch trae y los planes consumidores no piden** (las cajas abriéndose y
   abiertas, el cartel LLENO, el ícono del colchón, el marco/puntero/centro/segmentos de la
   ruleta, el marco y la carta bloqueada del Álbum, el ícono de familia). E5b decía "el marco, el
   puntero y los íconos de la ruleta siguen por código salvo que el dueño quiera arte": el dueño
   los generó y los aprobó. **Default:** entran con clave y van como carry al brief de su
   consumidor, con el respaldo por código intacto; si al cerrar la épica consumidora alguna no
   tiene llamador, se retira del atlas y del manifest (el precedente de `ui_chest_*` y los `fx_*`).
5. **`ui_oro_skin_effect` no entra:** el dueño descartó los efectos de skin por código (E6b T1r) y
   no hay nada que vender con ese ícono.
6. **El ×2 y el ×3 de ingresos comparten ícono** (el batch hizo uno solo, `ui_oro_income_boost`).
   **Default:** dos claves con el mismo PNG (≈ 60 KB de más) en vez de tocar el `oro_shop.json`
   de E6a.
7. **Sin arte en el batch:** el cofre de pintas (`ui_shop_skin_chest`) y las tres ofertas
   (`ui_offer_*`). **Default:** SF Symbol del dato, como ya prevé E6a. Si el dueño los quiere,
   son 4 prompts más en el generador y una fila del alta.
8. **Los `.md` del batch no se copian a `prompts/gemini_pro/`.** La numeración del generador
   (001–227) choca con la de acá (1–323) y el generador es la fuente. **Default:** el prompt viaja
   en `prompts.json` y `generado_como` dice de qué PNG salió.
9. **≈ 190 MB de originales al historial de git** (`dropbox/procesadas/`, convención de la casa:
   `recut_assets.py` y `elegir_recorte.py` recortan desde ahí; hoy son 225 MB). Los fondos solos
   son 51 MB. **Default:** se commitean como siempre. La alternativa (dejarlos en el repo
   generador y que `original_de` los busque allá) ata el pipeline a una ruta de esta máquina.
10. **El recorte de la 2.0 es conectividad hasta la T9.** La saliencia se elige a ojo y sólo la
    elige el dueño. **Default:** entra todo por conectividad; la página de la T9 llega con los
    sospechosos marcados.
11. **La cara del rentista (`ui.atlas/rentista_soles_face`) no se regenera:** es otro asset y sus
    soles no se reportaron lavados. **Default:** queda.
12. **Las skins de familia del rentista** se generaron contra el original de los soles con brillo.
    **Default:** entran (el dueño aprobó las 222); si se ven distintas al lado del nuevo, se
    regeneran las tres en el generador y entran con `traer_tanda.py` + `process_dropbox.py`.
13. **Una familia incompleta** (un asset que no pasa el barrido) entra con lo que tiene; E6b T9 ya
    vende sólo las completas.

## Filas para `tasks.md`

Para pegar en §5, debajo de "### E8 — Arte y animación", como tabla por tareas (la tabla de
"Pieza / Estado / Qué falta" se queda para los loops, la cadena de "Fusionar todo" y los temas).
La rama de la épica, `v2/e8-arte`, va a la tabla "Ramas de épica" de §1.

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8 | Plan de E8 integración de arte | ✅ | — | — | (el commit de este plan) | 10 tareas; `2026-10-08-v2-e8-integracion-arte.md`; 13 dudas con default |
| E8-T1 | El rentista con soles sólidos | ⏳ | — | `cosmic.atlas`, `recut_assets.py` | | pipeline; cierra el gate `rentista_soles` de §6 y libera el worktree `v2-e8-pipeline`; no mueve plata |
| E8-T2 | El alta del batch (`prompts.json`) y las reglas de export | ⏳ | — | `prompts.json`, `process_dropbox.py` | | pipeline; crea `traer_tanda.py`; revisión sonnet |
| E8-T3 | Familia Pijama (43) | ⛔ | T2 | `fam_pijama.atlas` | | pipeline, no compila; ∥ T4, T5 y cualquiera; destraba (con T4, T5) el arte de E6b T9 |
| E8-T4 | Familia Gaucho (43) | ⛔ | T2 | `fam_gaucho.atlas` | | ídem |
| E8-T5 | Familia Disfraz de Dinosaurio (43) | ⛔ | T2 | `fam_dinosaurio.atlas` | | ídem |
| E8-T6 | Visitantes y especiales (52) | ⛔ | T2 | `npcs.atlas`; 🔥 `assets_manifest.json` (`npcs`) | | `oraculo.sh tarea GameContentValidationTests GameArtComponentsTests`; la ven E4b T1–T5, T8 y E5b T1 (todas con respaldo) |
| E8-T7 | Paquete, Colchón, Ruleta, tienda y Álbum (31) | ⛔ | T2 | `ui.atlas`; 🔥 `assets_manifest.json` (`ui`) | | `oraculo.sh tarea GameArtComponentsTests GameContentValidationTests`; carries a E5b T1–T3, E6b T9, E4b T8, E7b-b T3 |
| E8-T8 | Los fondos a 2048 (JPEG) | ⛔ | T2 | `Backgrounds/`, `process_dropbox.py`; 🔥 `assets_manifest.json` (`backgrounds`) | | crea `BackgroundArtTests` (xcodegen); mide la memoria del vuelo; revisión sonnet |
| E8-T9 | 🔒 La revisión de recortes de la 2.0 | ⛔ | T1, T3–T7 | `recut_assets.py`, los atlas elegidos | | la página la arma el agente; elige el dueño; no frena a nadie |
| E8-T10 | Peso, memoria y cierre (controlador) | ⛔ | T1–T8 | `Docs/`, `tasks.md` | | `completo --limpio`; 🔒 sólo si el bundle crece > 60 MB (estimado ≈ +29 MB) |

Y en §5 E6b, la nota de E6b-T9 pasa a decir: "🔒 arte de E8 = E8 T3–T5; 🔒 si el bundle crece
> 60 MB (E8 T10 lo mide; estimado ≈ +29 MB con fondos en JPEG)".
