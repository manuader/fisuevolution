# Sesión 2026-08-21 — El tutorial high-end: la fase corta, las lecciones y el puntito

> Ejecuta `Docs/PROMPT-tutorial-high-end.md` (commit `2224a42`), que trae la
> investigación medida: el recorrido del tutorial viejo en simulador, el
> inventario file:line del sistema y el deadlock latente del daily. Esta doc
> cuenta QUÉ se construyó y POR QUÉ cada decisión; el estado del arte pendiente
> queda en el handoff efímero.

## Qué se pidió (resumen; el textual está en el prompt)

Tutorial que enseñe **toda la app en el momento en que hay algo que hacer** en
cada pantalla (la regla de oro del dueño), sin pisarse con las celebraciones,
sólo con fotos del Fisura, con la UI v3, y el puntito rojo de logros cobrables
en el tab Menú y la tarjeta de Logros — enseñado por el propio tutorial.

## Lo construido, en el orden del prompt

### 1. El arbitraje: el tutorial es un cliente de la cola (`e28ed50`)

- `CelebrationQueue.restrict(to:)` (EconomyKit): mientras está puesto, sólo los
  kinds permitidos toman el turno; el resto queda en `pending` — **no se
  presenta ni se pierde**. `promoteIfIdle` saltea lo no permitido y conserva
  prioridad + orden de llegada. Levantarla promueve en el acto.
- `beginTutorialPhase()` (en el bootstrap, si `fisuTutorialDone` es falso)
  restringe a `[.boardCelebration]`: el reveal del primer merge es EL momento
  de la fase, lo único que pasa. `tutorialPhaseFinished()` (las dos salidas del
  overlay: «¡Vamos!» y «Saltar») levanta la restricción y lo retenido desfila.
- El overlay entero se esconde mientras `showing != nil` (su `body`): el reveal
  se reproduce **limpio, a pantalla completa y sin segundo scrim**, y el paso
  del cierre aparece recién con `celebrationFinished`. Verificado a ojo (video,
  frame en el reporte del recorrido) y con test (el marker `tutorial.step`
  desaparece del árbol y vuelve en `finish`).
- **Murieron** el parche `hidesUIForCelebration && tutorialDone` y el gate
  `tutorialDone` de los cinco bindings de sheets de la cola: la cola es el
  único árbitro. (La ficha de personaje conserva su gate: no es una celebración.)
- El deadlock del daily día-2-a-medias quedó **repro-ducido en test**
  (`CelebrationWiringTests`, 3 casos nuevos) y muerto por construcción. Bonus:
  `--uitest-daily-popup` ya no necesita `--uitest-skip-tutorial`.

### 2. El guion nuevo: fase de 4 pasos + lecciones contextuales (`ed5c7e0`)

- **Fase obligatoria**: tap → contratar → fusionar → cierre. Los pasos de
  abrir-Mejoras y abrir-mapa **murieron** (abrían vidrieras vacías: mejoras a
  50/60 contra ~0-10 monedas, mapa con 1/10 pisos). Sus claves quedan en el
  catálogo como reserva (no podar: `extractionState: stale` es normal acá).
  El cierre deja UN objetivo: «con un T5 se abre el piso 2».
- Todo el avance sale de los milestones `ftue.*` **persistidos**: matar la app
  a mitad de guion no rehace nada (los eventos `.ui` que se perdían murieron
  con los pasos que los usaban; `TutorialEvents` ya no existe).
- **Guía dentro de FisuJobs** (paso contratar): banda compacta pergamino+halo
  amarillo arriba de la lista (`TutorialJobsHint`), viva sólo con
  `tutorialPhaseActive && !spawned`. La hoja se sigue presentando encima del
  overlay (decisión conservada); ahora el guía vive en las dos capas.
- **Lecciones contextuales** (`GameState+TutorialTips` + `TutorialTipView`):
  kind nuevo `.tutorialTip` (prioridad 7, timeout 12 s, skippable). El director
  corre al final de `refreshProjections` contra señales YA publicadas y
  dispara **una lección por vez**, la primera elegible del orden, sólo con la
  fase terminada y sin hojas tapando el tablero. El coach-mark es un globo
  pergamino + anillo latiendo sobre el control, **sin scrim y sin bloquear un
  toque**: el juego nunca se congela por un tip.

| lección | señal (proyección) | destino |
|---|---|---|
| Mejoras | `canAffordAnyUpgrade` (nueva: costos crudos vs. balances, nunca `characterUpgradeRows`) | tab `hud.upgrades` |
| Ascensor | `unlockedFloorsCount >= 2` (nueva) | `hud.map` |
| Atajo | `bestHire.affordable` | `hud.quickhire` |
| Pintas | `!ownedSkins.isEmpty` | tab `hud.skins` |
| Logros | `hasClaimableAchievements` (nueva: resta de sets) | tab `hud.settings` |
| Regalos | `meta.daily.cycleDay > 1` (= ya cobró un daily de verdad, sin bandera nueva) | tab `hud.bonus` |
| Tienda | 2ª sesión con la fase hecha (`tutorial.sessionsAfterPhase`) | tab `hud.store` |
| Prestigio | `prestigeAvailable` | botón de prestigio |

- **Salidas de una lección**: hacer lo que señala (la mejor — abrir el destino
  la cumple al instante, `tutorialTipHandled`/`tutorialTipCompleted`), el botón
  «¡Dale!», el tap que saltea (piso 0,6 s de la cola) o el timeout. Las tres
  últimas pasan por `releasePayload`, que la marca dada — **una lección se da
  una sola vez**, la hayan leído o ignorado.
- **La regla de oro vale hasta el último frame**: si la condición muere
  mientras la lección espera turno (gastó las monedas), el director la retira
  **sin marcarla** y vuelve cuando su momento vuelva. Pineado en test.
- Persistencia: `tutorial.lesson.<id>` en UserDefaults; `--uitest-reset` barre
  lecciones y contador de sesiones (misma trampa que el tutorial y los ajustes).

### 3. El puntito rojo (`917aa38`)

- `hasClaimableAchievements` publicada a 8 Hz (escribe sólo si cambió);
  re-evaluada también vía el `refreshProjections` de `claimAchievement`.
- `NotificationBadge`: `ui_badge` del atlas con fallback vectorial (rojo
  muestreado del PNG: 227/58/51). El PNG venía con **86% de aire** (el mismo
  mal de `ui_elevator`): recortado al bbox del alfa +2% — 192×192 → 90×99.
  El centro estaba sano (alfa 255): no era el bug #6.
- Dos superficies, siempre `.overlay` (jamás un hijo del layout: la barra va
  374 ≤ 375 en SE): esquina del plato del tab Menú (dentro del
  `keyframeAnimator`: el puntito rebota con su tab) y esquina del icono de la
  tarjeta `menu.card.achievements`.
- AX: el aviso viaja en `accessibilityValue` del botón existente («Rewards to
  claim» / «Hay premios para cobrar») — trampa 9a respetada. El circuito
  entero (nace en el tab → tarjeta → cobrar los 3 → muere) quedó pineado en
  `TutorialUITests`.

### 4. Sólo el Fisura (`39dd336` + pendiente de batch)

- El fallback a `person.fill` **murió**: sin atlas se cae a `wave` →
  `celebrate`, y sin ninguna el globo habla solo.
- La mano dejó de ser un SF Symbol: `VectorTutorialHandIcon` (GameIcons.swift)
  — el guante sin dedos del Fisura señalando, índice y pulgar piel, puño de
  lana, mismo lienzo 100×100 e `inked` de la casa.
- El guion usa **sólo `wave` y `celebrate`** (las dos sanas) mientras
  `fisura_point`/`fisura_explain` no se regeneren — los prompts 117/118 ya
  describen las poses correctas. **El batch se intentó al cierre y abortó
  0/2 con cuota intacta**: el ladrón de foco fue «Claude» — la app del
  propio agente; con una sesión activa el runner no puede tipear (nueva
  evidencia para la regla de la memoria: el batch lo corre el dueño con los
  frontends cerrados). La ventana de regeneración quedó abierta, estable y
  con la suite verde encima; el detalle operativo, en el handoff efímero.

### 5. La tarjeta y el overlay en v3 (`39dd336`)

- `TutorialCard` en pergamino con su luz (la receta de `PanelCard` a escala de
  tarjeta), borde tono-sobre-tono, retrato **96×112 pisando el borde**
  (offset, sin clip), dots caramelo (el activo con gradiente `lifted()` y
  borde `deepened()`), transición de paso con **pop de spring** (0,42 s,
  bounce 0,24) en vez del `.opacity` pelado. Reduce Motion colapsa todo
  (regla existente conservada; smoke hecho).
- El scrim 0.68 quedó SOLO para la fase; las lecciones van sin scrim.
- «¡NUEVO!» del reveal salió del hardcode a `board.reveal.new` (es+en) —
  verificado en vivo: el reveal del runner dice «NEW!».

## Los números del cierre

- EconomyKit: **213/213** (`swift test`; +4 del gate).
- App: **395 tests, 3 rojos** — exactamente los 3 preexistentes de
  `PacingTests` (fase fisura, gradiente, dios 242-449 h), que tienen su propio
  prompt de rebalance. Cero rojos de esta sesión. (+7 `TutorialTipsTests`,
  +3 en `CelebrationWiringTests`.)
- UI: **48/48, cero fallos y sin skips** en la corrida completa del cierre
  (sim propio por UDID, unit antes que UI, `-parallel-testing-enabled NO`);
  `TutorialUITests` reescrita para el guion nuevo quedó en 7 tests (+2: la
  lección y el puntito).
- Pipeline: 53 tests, **1 rojo AJENO**: `test_ningun_asset_quedo_agujereado`
  acusa 4 PNG de la skin `estanciero_estelar__tropero` (frente de skins del
  2026-08-19, no de esta sesión — el único toque de atlas de hoy fue el
  recorte de `ui_badge`, que no figura). El rojo histórico de Chrome `:9222`
  PASÓ esta vez porque el Chrome del batch estaba levantado.
- Cero warnings.
- Recorrido manual: fase entera con **reveal limpio** (video, frame guardado),
  día-2 sin deadlock (capturas antes/después del skip), lección de Mejoras en
  es y en, badge en tab+tarjeta, Reduce Motion, y pase SE (barra con badge sin
  mover un punto; tarjeta completa).

## Decisiones de esta sesión (además de las del prompt)

1. **El director de lecciones y el gate del bootstrap arrancan APAGADOS bajo
   XCTest** (`XCTestConfigurationFilePath`, mismo criterio que la
   `SKTestSession` de StoreManager): los tests de wiring existentes cuentan
   con que nada se encole solo, y cada test arma su escenario con
   `beginTutorialPhase()` / `tutorialLessonsAutorun = true`.
2. **Tienda va** (recomendación del prompt): una vez, suave, en la 2ª sesión
   con la fase hecha. **Prestigio se enseña apenas se enciende** el indicador.
   Las dos eran preguntas abiertas al dueño; están implementadas así y son un
   flag de un renglón si las quiere distinto.
3. **Una lección ignorada no vuelve** (timeout/skip la marcan dada): menos
   insistencia es más high-end; el badge de logros queda como recordatorio
   permanente de SU circuito, y las pantallas siguen ahí.
4. `uiCoversBoard` lo publica `RootView` (los `@State` de hojas son invisibles
   para `GameState`); el tip además se auto-oculta si una hoja sube justo
   cuando le toca (la carrera queda cubierta por el timeout, que la marca
   dada — ventana de 12 s, aceptada).

## Trampas nuevas (van también al general)

- **Una lección contextual puede nacer EN MEDIO de un test ajeno y comerse sus
  taps por coordenada.** Medido con `AscentRenderingUITests`: su `grantCoins`
  (el +1M del panel de debug) enciende `canAffordAnyUpgrade`, la lección de
  Mejoras nace, su globo se posiciona en la mitad superior y el siguiente tap
  por coordenada a `hud.debug` cae en el globo — «no apareció el botón de
  invocar par» a los 113 s. El arreglo es de diseño, no de ese test: **las
  lecciones arrancan apagadas en cualquier corrida `--uitest-*`** y sólo el
  test que las quiere las pide con `--uitest-lessons` (fixture nuevo). Es el
  mismo criterio de siempre: el estado del tutorial lo decide cada test, nunca
  el azar del gating.
- **El tap sintético del MCP del simulador no activa las filas-botón dentro
  del `ScrollView` de FisuJobs** (tres taps medidos sobre el centro exacto de
  la fila, `ftue.spawned` siguió en falso), aunque sí activa tabs, X y
  tablero. XCUITest (`.tap()` sobre el elemento) compra sin drama — el flujo
  del jugador no está afectado; es un artefacto del inyector. Para recorridos
  manuales por agente: verificar efectos en los defaults del contenedor, no
  asumir del tap.
- **La transición de entrada con escala rompe taps tempranos de XCUITest**: el
  primer tap puede caer con el botón en su frame de entrada (0.92) y perderse
  — medido con «Saltar» (fallaba en suite, pasaba aislado). El patrón de la
  casa (reintento releyendo estado, como `tapSpotlight`) lo cubre; quedó
  anotado en el propio test.
