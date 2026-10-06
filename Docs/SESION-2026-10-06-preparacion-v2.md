# Sesión 2026-10-06 — La rama `version-2`: integrar lo suelto y sacar lo que sobra

## El pedido

La v1.0.0 (build 4) se publicó el 2026-09-23. Con los primeros días de
feedback, el dueño pidió dejar todo listo para programar la segunda versión a
partir de un plan que trae él: **todo funcionando, sin archivos de más ni
funcionalidades obsoletas, en una rama nueva** que al terminar se mergea a
`main` para lanzar.

## Decisiones del dueño (2026-10-06)

| Pregunta | Decisión |
|---|---|
| Nombre de la rama | `version-2` |
| `feat/reacciones-de-campo` (352 reacciones a eventos, sobre el `main` viejo) | **Descartada.** Sigue en GitHub sin tocar |
| `feat/atajo-al-mejor-tier` y `feat/cofres-solo-desbloqueados` (28/08, nunca mergeadas) | **Integrar las dos** |
| Limpieza local de la máquina | **Sólo lo 100 % seguro**: ramas ya mergeadas y `fisu-wts/` |
| Versión de la tienda | **2.0.0**, build 5 |

## Lo que se encontró antes de tocar nada

- **El build se hizo en otra máquina.** En la del dueño no existe el worktree de
  Conductor, y `~/Desktop/projects/fisuevolution` es el mismo checkout que
  `FisuEvolution` (el disco no distingue mayúsculas, mismo inodo).
- **El build publicado tiene el congelón de 466 ms al abrir el cofre.** El
  arreglo (`97cb618`, 2026-09-03) estaba sólo en un `main` local sin pushear.
- El HANDOFF-v2 decía "30 tiers": son **37 tiers y 44 tipos en 10 pisos**. El
  error venía de `ESTADO.md` y `tasks.md`, vencidos desde julio.

## Lo que se hizo

### 1. La rama

`version-2` sale de la punta de `appstore-submission-check` (`80f789a`) y
mergea, en este orden: `origin/main` (`59c0d61`, el mismo arte del Influencer
que el build), el `main` local (el arreglo del cofre), y las dos features del
28/08. Como contiene a `main`, el merge final es un fast-forward.

Los conflictos fueron sólo de `Docs/HANDOFF.md` (entradas de sesión que
crecieron en paralelo; se quedaron todas). La decisión 9 de §5 ("el atajo
vende el tier base") quedó tachada y apuntando a §5.0-quinquies, que la
revierte con sus tres datos.

### 2. Dos bugs arreglados (y una carrera en un test)

- **La oferta "abrí otro cofre" no sabía de la regla de desbloqueo.** Las dos
  ramas se cruzaron recién al integrarse: con todo lo alcanzable ya ganado,
  `openChest()` guarda el cofre en silencio, así que el jugador miraba el
  anuncio y no veía nada abrirse. `canOfferExtraChest` pregunta lo mismo que
  el sorteo antes de ofrecer. Dos tests en `ChestSourcesTests`.
- **Comprar "Quitar anuncios" a mitad de sesión no apagaba el intersticial**
  hasta reabrir la app: `AdsCoordinator.setRemovedAds` existía y nadie lo
  llamaba. Ahora lo llama `applyStoreEntitlements`, por donde pasan compra,
  restauración y reembolso. Test en `StorePacksTests`. **Está en producción
  en la v1**: los que compraron siguieron viendo un intersticial hasta cerrar
  la app.
- Dos tests del tutorial tocaban el HUD mientras el cofre todavía salía: ver
  la primera trampa.

### 3. La limpieza

Tres auditorías de sólo lectura (código Swift con el índice de Xcode, assets y
strings, y archivos del repo). Cada borrado se re-verificó antes de aplicarlo.

**De la app** (lo que viaja en el `.app`):

- 39 imágenes de `ui.atlas` que nunca se piden (78 PNG, ~4,2 MB): los nueve
  `panel_*` "de reserva", doce `ui_btn_*`, los numerales (`ui_dollar`,
  `ui_million`…), cuatro `fx_*`, toggles, cinta, barra, globo de diálogo y las
  poses `fisura_point`/`fisura_explain`. Salieron también sus 37 entradas del
  manifest. Los originales siguen en `dropbox/procesadas/` (salvo las dos poses,
  que están en git y tienen los prompts 117/118).
- `music_cosmic_loop.caf` (2,3 MB): la música por zona nunca se cableó.
- 12 claves del catálogo de strings que nada usa, escritas en el formato
  canónico de Xcode (trampa 29, con el ida y vuelta verificado byte a byte).
- Código muerto: `SpeechBubble`, `boostCooldownRemaining`, `AtlasCache.reset`,
  `BoardScene.topInset`, `UIArt.has`, `PrestigeButton.capsuleHeight`,
  `ChestAnimationFeed.FramePin`, `FloorNode.ordinal`, la rama `cosmic` de
  `TowerNaming`, `prestigeOroGained`, y en EconomyKit `EconomyCalculating`,
  `TowerError.noHireableType`, `TowerMergeResult.requiresCareerChoice`,
  `TowerState.isFull/totalUnits`, `CharacterType.spriteAssetKey`,
  `PlayerState.markSeen` y los tres `unlock*` de `prestige_unlocks.json`, que
  además mentían: los specials por reencarnación los manda `specials.json`.

**Del repo:**

- `Tools/asset-pipeline`: la generación (era SD/ComfyUI, el runner de Gemini y
  sus rutas abandonadas), los scripts rotos o dañinos si se vuelven a correr
  (`gen_prompts`, `update_manifest`, `rightsize_assets`), los 32 `.pyc`
  versionados, las rechazadas y las 4 entradas `appicon` de `prompts.json`.
  README y `requirements.txt` reescritos para el pipeline de hoy.
- `Tools/balance-sim` (no compilaba desde F7), el CI de julio (Xcode 16.4 contra
  un proyecto que pide 26.6: no podía pasar y gastaba minutos en cada PR),
  `ESTADO.md` y `tasks.md` (vencidos; lo que seguía vigente de `ESTADO.md` pasó
  a HANDOFF §7), las capturas de julio y dos CSV de F2 sin referencias, y el
  `support.md` del plan de GitHub Pages.

### 4. Versión

`MARKETING_VERSION 2.0.0`, `CURRENT_PROJECT_VERSION 5`.

## Verificación

Sobre el árbol final, con la matriz de HANDOFF §6 (sims propios por UDID,
unit antes que UI, `-parallel-testing-enabled NO`):

| Qué | Resultado |
|---|---|
| EconomyKit (`swift test`) | **267/267** |
| Unit, iOS 26.5 (sin las dos suites de Store) | **474, un solo rojo**: `PacingTests.theOwnersTargetsAreMet`, el declarado (9 contra ≤8), igual que en el build |
| `StoreManagerTests` + `StoreProductsTests`, iOS 18.6 | **12/12** |
| UI, iOS 26.5 (sin `StoreUITests`) | **57/57** |
| `StoreUITests`, iOS 18.6 | **2/2** |
| Pipeline (`unittest discover`) | **25, un rojo**: el calado de arte (ver "Para el plan") |
| Release para dispositivo, sin firmar | **BUILD SUCCEEDED, cero warnings**. En el `.app`: 2.0.0 (5), `UIDeviceFamily = [1]`, `NSPrivacyTracking = false`, `GADApplicationIdentifier` presente |
| `Tools/generate-tiers` y `Tools/pacing-sim` | compilan contra el EconomyKit limpio |

En el medio apareció un rojo nuevo de UI y se fue a la causa: ver la primera
trampa.

## Lo que NO se sacó, y por qué

| Qué | Por qué queda |
|---|---|
| Game Center y CloudKit detrás de flags | Backlog de la v2 (HANDOFF-v2 §8) |
| `floorReached` | Decisión 0-quater: no se re-abre |
| `SaveMigrator` v1→v5 y los `decodeIfPresent` | Saves reales de jugadores |
| `spawnQuote`, `buySpawn`, `hireQuote(floorOrdinal:)` | El precio por piso sobrevive para `canAffordSpawn` del tutorial y para los tests del descuento de prestigio. Sacarlo es un refactor, no una limpieza |
| El camino de skins por **tinte** (0 de 131 skins lo usan) | Es una capacidad del motor; sacarla toca `SkinResolver`, `CharacterNode` y sus tests. A decidir en el plan |
| `PacingSimulator` dentro del binario de la app | Moverlo a un target aparte es un refactor |
| `anchor`/`scale` del manifest de personajes | Se decodifican y no se leen, pero `process_dropbox` los escribe |
| El PNG `logo` | Ver "Para el plan", punto 3 |
| `dropbox/procesadas/` y `prompts/gemini_pro/` | Los originales del arte y el archivo de prompts |

## Para el plan (encontrado de paso)

1. **El compartir no se puede alcanzar**: nada llama a `offerShareCard` desde
   julio. Consecuencia user-visible: **el logro `ach_share_1` es imposible**,
   la fila "compartidos" de Estadísticas siempre da 0 y el bonus viral no
   corre. Paga plata (no ORO), así que sacarlo no toca el contrato de los
   logros de ORO. Recablear o retirar: es decisión de producto.
2. **Falta el punto de entrada de privacidad de UMP en Ajustes**:
   `AdsConsent.presentPrivacyOptions()` existe y nadie lo llama. Google pide
   que el usuario del EEE pueda cambiar su consentimiento.
3. **El splash nunca muestra el logo**: `SplashView` se dibuja antes de
   `UIArt.configure`, así que cae al texto. Y sus tips están escritos en
   castellano con `Text(verbatim:)`: **el jugador en inglés los ve en
   castellano** (la ficha primaria es en inglés).
4. **El refactor del precio por piso** (ver tabla de arriba).
5. **Arte calado**: `test_assets_integrados` marca agujeros en
   `estanciero_estelar__tropero` (6,4 %) y `senior_doctor` (1,2 %), que ya
   están en el build publicado. Desde el 2026-09-02 lo tapaba el `KeyError` de
   las entradas `appicon`. Se arregla eligiendo otro recorte
   (`elegir_recorte.py`), mirando el PNG.
6. **Game Center**: `pendingAuthViewController` se escribe y nadie lo muestra.
   Arreglarlo antes de prender el flag.
7. **Música por zona**: si el plan la quiere, `music_cosmic_loop` y su
   generador están en `v1.0.0-build4`
   (`git show v1.0.0-build4:Tools/audio-synth/generate_audio.py`).
8. **CI**: no hay. Si se quiere, va con Xcode 26.6 y la matriz de dos runtimes
   de HANDOFF §6.
9. **Las capturas de la ficha** salen de `AppStoreScreenshotTests`; la
   descripción de la tienda ya dice 37 niveles (decía 30).
10. **Sigue en rojo el contrato de pacing** (9 reencarnaciones contra ≤8),
    igual que en el build: HANDOFF §5.5.

## Trampas nuevas

- **Un cambio sin lógica puede tumbar un test de UI, y la culpa es del test.**
  Después de la limpieza, `testRecorreElTutorialEnteroHastaElFinal` pasó a
  fallar 5 de 6: tocaba "Pintas" y la hoja no abría. Se bisecó archivo por
  archivo hasta UN cambio de cuatro líneas en `ChestAnimationFeed`
  (semánticamente idéntico: sacar un parámetro con default que nadie usaba),
  con 9 de 9 verdes sin él. La causa no estaba ahí: el test tocaba el HUD en el
  mismo instante en que cerraba el cofre, y el cofre es un **overlay** que se
  desvanece. El toque que cae mientras sale se lo come el overlay. El cambio
  sólo corrió el timing. Arreglo en el test (`awaitChestGone`): 6 de 6.
  ⚠️ Antes de culpar a la carga, correlo **aislado y varias veces**: acá la
  primera explicación ("load 190 por el borrado de 8 GB") era falsa.
- **Un test que se cae en el armado tapa las aserciones que vienen detrás.**
  El `KeyError` de `appicon` hacía fallar `test_assets_integrados` antes del
  barrido de calados, así que durante un mes el reporte decía "error de
  datos" y nadie vio que había arte agujereado.
- **Dos ramas correctas pueden dar un bug al juntarse**: la oferta del cofre
  extra y el filtro de desbloqueo eran cada una correcta en su rama.
- **La herramienta nativa de worktrees arranca de `origin/main`**, que acá no es
  el build: se crea con `git worktree add -b version-2 <ruta> <base>` y se entra
  con `EnterWorktree(path:)`. Y en una sesión aislada en un worktree el harness
  rechaza comandos compuestos que nombran git (`for`, `source`, `$((…))`):
  comandos simples o un script en el scratchpad.
- **Trampa 29, dos detalles más del formato de Xcode**: el objeto vacío se
  escribe `{`, línea en blanco, `}`; y el catálogo **no** termina en salto de
  línea.
