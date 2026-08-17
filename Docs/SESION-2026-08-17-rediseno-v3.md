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
| T12 verificación (tests + capturas vs referencias) | — | ⏳ suite de UI corriendo |

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
