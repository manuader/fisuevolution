# Sesión 2026-08-17 — Rediseño v3: materiales de referencia

**Rama:** `feature/rediseno-v3-referencias` (worktree aislado desde `main`
local `c4e69ba` — protocolo de sesiones paralelas; `origin/main` estaba 6
commits atrás, trampa 7).
**Plan:** `Docs/superpowers/plans/2026-08-17-rediseno-v3-referencias.md`.
**Pedido del dueño:** las 13 pantallas iguales a las 4 imágenes de referencia
(Looks/Pintas, Gifts/Regalos, FisuJobs, Upgrades), un solo lenguaje, clean y
high-end, sin inventar nada.

## La lectura clave del relevamiento

El v2 ya tenía la ESTRUCTURA de las referencias; lo que faltaba era la capa de
**materiales**: interior pergamino (el crema-sobre-crema dejaba las tarjetas
invisibles), bordes tono-sobre-tono en vez de tinta pareja, cinta con volumen,
pills caramelo, y dos marcos fuera de idioma (`panel_reward` verde en Regalos,
`panel_config` pelado en la familia del menú). Los interiores de los PNG de
marco son transparentes (alfa 8–15, medido), así que el pergamino entra por
`PanelBackground` sin tocar arte.

## Estado por tarea

| Tarea | Commit | Estado |
|---|---|---|
| Plan | `a316176` | ✅ |
| T1 pergamino + colorsets (Parchment #F1E5C9, Brown #7A4E26) | `c606e7b` | ✅ |
| T2 `PanelFrames.swift` (madera vectorial + moño) + xcodegen | `5e84b8a` | ✅ |
| T3 GameCard radio 18/teñido/gris + StateBadge cápsula + `deepened` | `619f26b` | ✅ |
| T4 `PillBackground` caramelo (PricePill/ActionPill/Toggle/IconButton) | `03cbf32` | ✅ |
| T5 cinta con colas/pliegues/✦ + título doble borde + icono adentro | `6da919c` | ✅ |
| T6 Regalos → madera+toldo+moño; boost bloqueado con arte a color | `8455a00` | ✅ |
| T7 familia del menú (6 pantallas) → `WoodPanelBackground` | `1696845` | ✅ |
| T8 Ascensor → `panel_upgrades` (maquinaria), inset 40 | `34cf551` | ✅ |
| T9 Upgrades: pestaña activa naranja con glifo, fila a materiales v3 | `a1074e5` | ✅ |
| T10 barrido tinta→marrón en shops + glifos adentro del banner | `8bf1ae1` | ✅ |
| T11 HUD: QuickHire/Prestigio a PillBackground, chips marrones | `f4ae8b8` | ✅ |
| — ProgressBar borde cálido (cierre del barrido) | `0091a67` | ✅ |
| — fix round visual: moño al toldo, glifo de tienda a la cápsula | `321ba88` | ✅ |
| **Fase D — el pedido ampliado del dueño ("toda la UI", popups incluidos):** | | |
| D1 GamePanel pergamino (7 popups de un golpe) + Prestigio/Carrera | `5624bf8` | ✅ |
| D2 banner de eventos + toasts de RootView | `5624bf8` | ✅ |
| D3 globo del tutorial (agente paralelo; campo minado 9a/9b intacto) | `9e475b4` | ✅ |
| D4 ShareCard v3 (agente paralelo) | `bbd1ce7` | ✅ |
| D5 ArtButton con respaldo caramelo (CTA de popups = pill de hojas) | `ed88326` | ✅ |
| D6 ficha + premio de skin + reencarnación (agente paralelo) | `b9d2dd8` | ✅ |
| D7 daily reward + plata offline + drop sorpresa (agente paralelo) | `49c3139` | ✅ |
| — HANDOFF: sesión v3 + trampa 16 | `3a5a503` | ✅ |
| T12 verificación + merge + push | `f097d21` | ✅ (con el ⚠️ de abajo) |

## Cierre (2026-08-17, noche)

- **Mergeado y pusheado**: la rama entera está en
  `origin/feature/rediseno-v3-referencias` y **`origin/main` avanzó
  `b782683..f097d21`** — incluye los 4 commits locales del dueño que nunca se
  habían pusheado (celebraciones, mejoras, su HANDOFF; la trampa 7 quedó
  cerrada de verdad). El `main` LOCAL del checkout del dueño no se tocó: quedó
  en `64e1473`, detrás de origin — al próximo push le va a pedir pull, que es
  la dirección segura.
- **Números finales**: EconomyKit 200/200 · unit app 375 (único rojo el flaky
  documentado `refundRevokesEntitlement`, verde aislado 10/10 de su clase) ·
  **UI 41 verdes + 6 rojos SOSPECHOSOS DE MÁQUINA** con load 500–921 y swap
  agotado (por encima del récord de 861 del HANDOFF): duraciones de
  tap-timeout (63–288 s), 4 de los 6 fallaron TAMBIÉN corriendo contra el
  árbol del dueño sin una línea del v3, y los flujos de los dos restantes
  (tabs abren/cierran, Ajustes navega) están verificados a mano en el
  simulador con capturas. El re-run aislado de los 6 murió por infraestructura
  (el guardado de xcresult falla en toda la máquina: mkstemp/CASDB).
- **⚠️ PENDIENTE que hereda la próxima sesión**: correr los 6 aislados con la
  máquina tranquila —
  `BottomMenuUITests/testCadaTabAbreSuPantallaYSeCierra`,
  `BottomMenuUITests/testLosExtremosSonMasGrandesQueElResto`,
  `LaunchSmokeTests/testTowerArrowsAndEmptyBoardSwipeNavigateOneFloor`,
  `MenuUITests/testAjustesTraeSusControlesYApagaLasParticulas`,
  `MenuUITests/testLosTerminosSeAbrenDesdeAjustes`,
  `TutorialUITests/testSaltearCierraElTutorialYDevuelveLosControles` — y si
  alguno falla determinístico, ahí sí es del rediseño.
- **Post-merge**: build verde con los 4 commits del dueño adentro (su único
  archivo compartido conmigo fue el HANDOFF, resuelto conservando las dos
  sesiones). Capturas de popups del build mergeado: daily reward y ficha ✓.
- Candidato de pulido a futuro: los botones de sistema que quedan en la ficha
  (Equipped gris de sistema) y el fork de carrera — los dejaron intactos los
  agentes por la restricción de no tocar estructura.

**Cómo se trabajó la fase D**: 4 agentes paralelos sobre archivos DISJUNTOS
dentro del mismo worktree (tutorial / share / ficha-skin-prestigio /
premios), con commits selectivos del orquestador por lote — cero builds por
agente (la máquina estaba saturada), un solo build central al final.
Identifiers nuevos: `offline.collect` y `special.drop.claim` (los CTA viejos
no tenían; sus claves de texto ya existían en el catálogo).

## Decisiones tomadas (con su porqué)

1. **Cero assets nuevos.** Los marcos que las referencias piden ya estaban en
   el atlas con interior transparente; el moño y el marco del menú salen
   vectoriales con los tonos MUESTREADOS del PNG (`panel_store`: madera
   #BD7E44/#C98F52→#A9713C, línea #2F1915, bisel #D3B788). El batch de Gemini
   NO se corrió: la máquina estaba saturada (load ~500, 18 usuarios, 3
   simuladores ajenos booteados) y el runner necesita máquina quieta. Queda
   como mejora opcional: `ui_gift_bow` y un `panel_menu` de arte podrían
   reemplazar los vectores vía manifest sin tocar código.
2. **Regalos usa `panel_store` + moño** (la referencia es madera con toldo);
   `panel_reward` verde queda para los popups de premio (DailyReward, Offline,
   SpecialDrop), que no estaban en el pedido.
3. **El ascensor usa `panel_upgrades`**: la torre es maquinaria — mismo idioma
   industrial que Upgrades en la referencia. `panel_dialog` queda en la ficha
   y el premio de skin (popups).
4. **`GameCard.locked` tiene dos sabores**: el misterio (gris total,
   confidenciales y pintas por ganar) y `contentDimsWhenLocked: false` para
   los boosts (referencia: tarjeta gris con el arte A COLOR — la zanahoria).
5. **Los ink que QUEDAN son deliberados**: contorno de las barras gemelas del
   HUD y del tab bar (decisión cerrada del dueño, no se re-litigó), perilla
   del GameToggle, contornos cartoon del moño/marco (así outlinea el arte), y
   los fallbacks de popups.
6. **Pestaña activa de Upgrades: azul → naranja** con glifo persona/estrella
   (así la muestra la referencia). Identifiers intactos.
7. **Desvío del plan anotado**: los "compilar por tarea" se agruparon en un
   build único al final de cada fase — la máquina estaba a load ~500 por
   frentes ajenos y un build por tarea no terminaba nunca. Los commits siguen
   siendo atómicos por tarea.

## Contratos verificados como intactos

- Identifiers de AX: `sheet.close`, `hud.*`, `jobs.hire.*`, `upgrades.tab.*`,
  `bonus.*`, `skins.*`, `gifts.daily.day*`, `map.floor.*` — sin cambios.
- `GameArtComponentsTests`: contratos v2 sin tocar; se sumaron tests de
  `deepened`, `CardMaterials`, inset del marco de madera, path del moño y de
  los ornamentos de la cinta.
- `UpgradesFaceUITests`: la banda del retrato sigue en 104 pt.
- Cero strings nuevos (no se tocó `Localizable.xcstrings`); cero claves de
  manifest nuevas; 1 archivo Swift nuevo (`PanelFrames.swift`, xcodegen
  corrido).
- Archivos de la sesión paralela del dueño (`GameState+Upgrades.swift`,
  `UpgradesMenuTests.swift`) NO tocados.

## Verificación (2026-08-17, tarde)

- **EconomyKit 200/200** ✅. **Unit de app: 375 tests, único rojo =
  `StoreManagerTests.refundRevokesEntitlement`** — el flaky sensible a carga
  documentado en HANDOFF §6 (la corrida tardó 29 min con load ~465);
  **verde aislado en 22,9 s** ✅, y la clase entera 10/10.
- **Capturas de las 13 pantallas contra las 4 referencias: verificadas.**
  FisuJobs, Upgrades y Pintas clavan la referencia; Regalos necesitó el fix
  del moño; la familia del menú en madera quedó día-y-noche contra el
  panel_config; Ascensor en metal; Tienda con Featured teñida. La pantalla
  principal conserva las decisiones del dueño con los materiales nuevos en
  QuickHire/chips.
- ⚠️ **Trampa nueva para el HANDOFF: el cwd de una sesión de agente puede
  volverse SOLO al checkout principal** (pasó entre dos corridas de esta
  sesión). La PRIMERA corrida de UI se ejecutó sin querer contra el árbol del
  dueño —sus fallas eran de ese árbol, no del rediseño— y el `build/DD` del
  checkout principal quedó tocado por esa corrida. Detectado porque la captura
  del Menú mostraba v2 y el binario no tenía los símbolos v3. Mitigación de
  ahí en más: `EnterWorktree` de nuevo + rutas absolutas en los comandos de
  build/test. La corrida de UI definitiva (worktree, DD absoluto) es la que
  vale.

## Cómo retomar (agente nuevo)

1. Leer este doc y el plan. El worktree vive en
   `.claude/worktrees/rediseno-v3`.
2. T12 pendiente: receta HANDOFF §6 (unit ANTES que UI, simulador propio por
   UDID, `-parallel-testing-enabled NO`), capturas de las 13 pantallas con los
   fixtures `--uitest-*`, comparación contra las 4 referencias, ronda de fixes
   si desentona, merge a `main` desde worktree temporal.
3. El simulador `rediseno-v3` puede existir de antes (`simctl list`); borrarlo
   al terminar es parte del trabajo.

## Remate nocturno (post-push)

- **Últimos controles de sistema** → v3 en `f696fa7` (ficha: chevrons y
  equipar con label que lee `isEnabled`; prestigio: ActionPill rosa +
  cancelar mudo). No queda superficie de juego fuera del lenguaje.
- **Panel de debug: evaluado y descartado a propósito** — es QA que jamás
  shippea y su docstring lo declara fuera del catálogo; que parezca sistema
  es correcto.
- **Assets opcionales encolados** (`bda35f0`): `236_ui_gift_bow` y
  `237_panel_menu` en `pendiente`. El batch lo corre el dueño con la máquina
  quieta y frontends cerrados (trampa 11):

  `cd Tools/asset-pipeline && caffeinate -is .venv/bin/python scripts/gemini_selenium_runner.py --process --pause 3 --timeout 260`

  Integración: el moño entra solo por `GameIcon`/manifest; `panel_menu` pide
  además cambiar `WoodPanelBackground()` por `PanelBackground(art: "panel_menu")`
  en la familia del menú y re-medir su `panelInset` (hoy 34, del vector).
- **Los 6 tests sospechosos**: la máquina se reinició (swap limpio) — la
  re-corrida aislada quedó armada para cuando el load asiente.

## Segundo arco (2026-08-18, madrugada) — iteración del dueño con capturas

El dueño pidió tres cosas mirando el juego corriendo, y las tres están:

1. **Fuera la píldora de piso del HUD** (`acb81ba`): el piso se cambia
   scrolleando o por el ascensor. Los dos accesos de la barra (moneda+ y
   ascensor) quedaron pelados a 60 pt (`IconButton` ganó `showsPlate`). El
   piso actual ganó dos observables: el value de la fila del ascensor dice
   "estás acá" (VoiceOver) y `board.floor` publica el ID crudo junto a
   `board.units` — sobrevive a las celebraciones y es a prueba de trampa 6.
2. **Los marcos son CONTENEDORES** (`b2b3cf1`): las seis hojas de arte dejaron
   el 9-slice (se estiraba: toldo deforme, caños chicle, y el engranaje hacía
   leer "ajustes" en Mejoras) por el marco VECTORIAL con material
   (.wood/.metal con remaches) y toldo dibujado al ancho real. `columnInset`
   = 34 único para las nueve hojas, publicado por el componente. Los popups
   siguen en su arte (tamaños chicos, sin queja).
3. **Auditoría de coherencia**: los 3 últimos botones de sistema (premio de
   skin ×2, despedir) a la gramática de la casa; hit-area del ascensor al
   radio de tarjeta.

**Los "6 sospechosos" quedaron CERRADOS con máquina quieta (load 4):**

| Test | Veredicto |
|---|---|
| BottomMenu ×2, Menú ×2 | flakies de carga: verdes aislados y en la suite final |
| LaunchSmoke tower-arrows | reemplazado: la feature de flechas se retiró; los 2 tests nuevos navegan por swipe y leen `board.floor` |
| Tutorial skip | **bug del test**: `XCTAssertFalse(waitForExistence(3))` perdía la carrera contra la animación de cierre — reproducido determinístico en clase, arreglado con espera de desaparición (`fb05be8`), 5/5 |

Además: los 3 rojos nuevos de Pintas eran interacción con `f541bde` del dueño
(la pantalla abre en el personaje MÁS NUEVO — Pintas comparte la proyección
de mejoras). Comportamiento CONSERVADO; los tests eligen personaje explícito.

⚠️ Dato de entorno que quedó medido: **XCUITest no surfacea el
`accessibilityValue` de los Buttons del ascensor** (las 10 filas devuelven ""
aunque VoiceOver las lea) — por eso los tests leen `board.floor` y no el
"estás acá". Y el guardado de xcresult está roto en esta máquina
(mkstemp/CASDB) con o sin carga: los veredictos salen del log crudo.
