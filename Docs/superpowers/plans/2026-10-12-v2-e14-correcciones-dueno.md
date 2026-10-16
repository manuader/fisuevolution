# E14 — Correcciones del dueño antes de la App Store: plan por tareas

> **Para agentes:** se ejecuta con el relevo automático (PLAN-v2 §0 y §0.1) y el protocolo
> `.superpowers/sdd/v2-agente-protocolo.md`. **E14 tiene prioridad absoluta** sobre el resto de la
> cola de `tasks.md` (decisión del dueño, 2026-10-12). Lo que pide cada tarea está en
> `Docs/PLAN-v2-E14-correcciones.md` (C1–C29): ese doc es la spec; este, el orden y los dueños.

**Objetivo:** dejar la 2.0 lista para la App Store con las 29 correcciones del dueño: una UI con la
gramática de Cow Evolution / AdVenture Capitalist en la identidad del Fisu, premios siempre
ilustrados, visitantes que no estorban y una economía de visitantes pareja.

**Arquitectura:** primero los cimientos que no dependen del diseño (estáticos, motor de visitantes,
tiers, renombre, celebraciones), después los **componentes base** de la UI (botón, popup, ilustración de
premio, estados) y recién ahí las pantallas, una por tarea, sobre esos componentes. Todo lo visual pasa
antes por la **aprobación del dueño en mockups** (G1).

## Decisiones del dueño (2026-10-12, no se re-preguntan)

| # | Decisión |
|---|---|
| D1 | Fondos de piso: quedan en 2048 (no se reescala a 4K). |
| D2 | La moneda premium en inglés: «Blue Dollars», abreviado «Blue». |
| D3 | Pintas, familias y el cofre de skins pagados con blue van a la hoja de Pintas. |
| D4 | El que pide un empleado (C16): **opción A, en el horizonte al medio** (el dueño aprobó todos los mockups sin elegir; A era la recomendada y es la que encaja con C2/C10). Si al verla en el juego prefiere la B (abajo a la izquierda, calcada del alien), se cambia en T15: las dos están en el mockup. |
| D5 | La card de personaje nuevo con «¡Compartir!» va en **todos** los personajes nuevos, también los del tutorial. |
| D6 | Reencarnar: el re-desbloqueo de piso es insalteable la primera vez de cada vida, en versión corta. |
| D7 | Los eventos que llevan a la Tienda o al blue no traen descuento; tope 1 por sesión, nunca en el arranque. |
| D8 | Los sellos de premios que todavía no están disponibles no aparecen (entran con animación al desbloquearse). |
| D9 | E14 primero; lo demás de la cola, detrás. E2b T12/T13 siguen en paralelo sólo sin pisar archivos. |
| D10 | El arte (27 imágenes con Gemini Flash, 11 videos con Higgsfield) se genera ya, en paralelo a los mockups, y pasa por la revisión del dueño. |
| D11 | Si C5 mueve el pacing, el agente compensa para sostener Dios en ~45 h e informa los números. |
| D12 | Mockups en alta fidelidad con el arte real, aprobados antes de programar cada pantalla. |
| D13 | **G1 cerrada (2026-10-12): el dueño aprobó TODOS los mockups.** Regla del dueño: los mockups son **inspiración, no especificación**: buena disposición, pero no se ven exactamente como el juego. **Nada pixel perfect.** Se usan igual que las referencias de Cow Evolution y AdVenture Capitalist: de ahí se toman la idea, la disposición, la jerarquía y el flujo; la apariencia la dan la identidad del Fisu, la gramática v3 y el arte real. No se copian colores, medidas ni tipografías del CSS del mockup. |
| D14 | Regla del dueño (2026-10-12): **Cero superposición:** cada elemento tiene un único lugar fijo; nada tapa a nada ni tapa el tablero donde se juega; nada de amontonamiento; todo se toca cómodo (≥ 44 pt, sin vecinos pegados). **Única excepción aceptada:** la botonera del ascensor mientras está abierta tapa la columna de boosts (C30); al cerrarse, todo vuelve a estar a la vista. Cada tarea de pantalla lo comprueba en SE y Pro Max (con el tablero lleno, visitante, caja, colchón, 4+ boosts y un aviso a la vez) y lo deja en su captura. |

## Gates del dueño

- **G1 — Mockups aprobados: ✅ CERRADA (2026-10-12).** Página: https://claude.ai/artifact/CSQZvzWWFZYzst4Krx6Pn1
  (privada del dueño); copia en el repo: `Docs/correcciones-v2/mockups/fisu-e14.html` (abrir local, con su
  carpeta `a/`). Cada tarea de la fase 2 nombra su mockup (M1…M14) como inspiración (D13: nada pixel perfect).
- **G2 — Arte de imágenes aprobado: ✅ (2026-10-12)**, las 27 de `fisu-v2-premios/output/`.
- **G3 — Videos aprobados** (los 11 de `fisu-v2-premios/video`). Estado: **generados** con Kling v3.0
  (720×720, 24 fps; 94,5 créditos); 8 ok y 3 dudosos (`cofre_sacude`, `cofre_abre`, `colchon_abre`) según
  `video/out/revision.md`. Los `_sacude` y `ruleta_premio` salieron de 3 s (Kling no baja de 3): T3 los
  recorta/acelera al integrar. Espera la revisión del dueño.
  **2026-10-12: el dueño aprobó 10 de 11**; `colchon_abre` se regenera (v2: explosión de dinero, billetes sin verde)
  y vuelve a revisión. T3 ya puede integrar el resto.
- **G4 — Pasada en iPhone real** (SE y Pro Max) al cierre, con la lista de escenarios del doc de sesión.

Mientras un asset no esté aprobado, la tarea que lo usa integra con su fallback (el vector de la casa o
el asset viejo) y deja la clave lista: el arte entra después sin tocar código.

## Archivos calientes (un dueño por ola)

`RootView.swift` (al límite del type-checker: hojas nuevas en un `ViewModifier`),
`GameArtComponents.swift`, `PanelFrames.swift`, `BoardScene.swift`, `GameState*.swift` del área,
`Localizable.xcstrings` (nadie lo edita: claves nuevas en `claves-pendientes/<tarea>.json`; lo vuelca
T26), `loops_manifest.json` (sólo con `video_assets.py`, nunca en paralelo), `project.yml`.

## Las tareas

Leyenda: **Fase 0** gates y arte · **Fase 1** cimientos (no esperan G1) · **Fase 2** pantallas (esperan
G1 y T9). Modelo sugerido: opus para EK, migraciones y componentes base; sonnet para pantallas.

### Fase 0

| Tarea | Qué | Corrección | Depende | Dueño de |
|---|---|---|---|---|
| T0 | Mockups de alta fidelidad + aprobación ✅ (G1) | todas | — | sesión del dueño (hecho) |
| T1 | Generar las 27 imágenes (Gemini Flash) y la revisión | C4, C8, C9, C15, C19, C28 | — | `automatic-image-generation/projects/fisu-v2-premios` |
| T2 | Generar los 11 videos (Higgsfield) y la revisión | C26, C27 | — | `fisu-v2-premios/video` |
| T3 | Integrar el arte aprobado al juego (pipeline, atlas, manifest) | — | T1+G2, T2+G3 | `Tools/asset-pipeline`, `Resources/*.atlas`, `loops_manifest.json` |

### Fase 1 — cimientos

> **T29 (C32) va PRIMERO**, antes que la ola 1: es un exploit de economía en la versión que se va a subir.

| Tarea | Qué | Corrección | Depende | Dueño de |
|---|---|---|---|---|
| T4 | Fuera los videos de fondos de piso y de los 43 personajes base | C1, C22 | — | `FloorNode`, `BoardScene` (sólo el fondo y el clip de personaje), `loops_manifest` (`floors`, `characters` base), `AnimPacks/`, `project.yml`, `video_assets.py` |
| T5 | Intercambio de tiers 7↔8 + migración del save por posición | C17 | — | `tiers.json`, EK (migración), tests de save |
| T6 | Visitantes: un solo carril, bolsa barajada por visitante, «No, gracias» en el motor, pacing compensado | C5 | — | `VisitorScheduler`, `VisitorsConfig`, `visitors.json`, save, simulador |
| T7 | ORO → dólar blue en textos (es/en), ASC y docs de review | C8 | — | `claves-pendientes/t7.json`, `Distribution/*`, `GameArt` (ícono, con fallback) |
| T8 | Desbloqueo de piso insalteable (M2) | C21 | — | `CelebrationQueue`, `BoardScene.tapDuringCelebration`, `CinematicOverlay` |
| T9 | **Componentes base**: `GameButton` (medallón, colores por función), `PopupContainer` (centrado, alto máximo, scroll interno), `RewardIllustration(kind:)` con rayos, estados (listo/en curso/bloqueado/hecho), `CornerSeal` | C4, C15, C19, C29 | — (G1 ✅) | `GameArtComponents.swift`, `PanelFrames.swift`, componentes nuevos |
| T28 | El ATT antes de la intro: la intro espera al consentimiento (tope 10 s sólo sin formulario en pantalla), el ATT nunca encima de una cinemática ni de una lección, y la geografía de prueba de UMP en DEBUG | C31 | — | `AdsCoordinator`, `AdsConsent`, `FisuEvolutionApp.startServices`, `GameState+Cinematics` |
| T29 | **CRÍTICO:** el boost por video, una vez por ciclo con cooldown completo; el mismo boost no se apila | C32 | — | `GameState+AdOffers`, `BoostManager` (`ContentSystems.swift`), `GiftsView.BoostCard`, save, EK `ModifierMath` |
| T10 | Atajo de contratar: modo «el primero del piso» (M12) | C14 | — | `QuickHirePicker`, `GameState+Hiring`, save |

### Fase 2 — pantallas (mockups aprobados: cada una sigue el suyo y espera T9)

| Tarea | Qué | Corrección | Depende | Dueño de |
|---|---|---|---|---|
| T11 | Los 10 popups al `PopupContainer`; ritmo Cow Evolution; ofertas del vendedor en una fila (M3, M7b) | C15 | T9 | las 10 vistas con `presentationDetents` |
| T12 | Barra inferior a todo el ancho con leyendas + Contratar/Reencarnar como solapas (M1) | C12, C18 | T9 | `BottomMenuBar`, `GameTabBar`, `RootView.bottomBar`, `QuickHireButton`, `PrestigeButton` |
| T13 | Esquinas: sellos de premios (izq.) y especial › eventos › boosts (der.), sello de oferta (M1) | C3, C9, C19 | T9, T12 | `SideRailView` (se reemplaza), `ActiveBonusBar`, `StageChips`, `HUDView` |
| T14 | Avisos arriba sin comer toques; la botonera del ascensor encima de la columna derecha (M1, M1b) | C20, C30 | T13 | `TowerNoticeView`, toast de logros, `RootView` (overlay) |
| T15 | Escenario de visitantes: horizonte, popup automático, anclado al piso, pedido con la cara (opción A, D4), arrastrar para entregar, berretín del vendedor (M3, M3b, M4, C16-A) | C2, C6, C15, C16 | T6, T11, T13 | `StageLayout`, `StageController`, `VisitorNode`, `SpeechBubbleNode`, `VisitorPopupView`, `VendorCardsView` |
| T16 | Caja y colchón del tablero: +85 % y al horizonte (M1) | C10 | T12, T15 (la línea) | `PickupLayout`, `PickupController`, `PickupNode` |
| T17 | Pantallas de premio en tres momentos: Ruleta (gajos con imagen), Colchón, cofre (M6, M7) | C4, C26, C27 | T9, T11 | `WheelView`/`WheelCanvas`, `MattressPopupView`, `ChestOpeningView`/`ChestCinematicPlayer` |
| T18 | El Paquete de la Aduana: vuelo al sello, pantalla con las caras posibles y chances, apertura, lección (M5, M5b, M5c) | C28 | T13, T17 | `GameState+Packages`, `PackageOpeningPlayer`, `PrizeSheets`, lección |
| T19 | Mejoras con Personajes · Permanentes · Boosts; la Tienda sólo plata real; cosméticos a Pintas; jerarquía del blue («Tu meta») (M10) | C11, C29 | T9 | `StoreView`, `OroShopView`, `UpgradesView`, hoja de Pintas |
| T20 | Regalos por estado: «Para cobrar ahora», «Pronto», racha al final (M9) | C29 | T9, T18 | `GiftsView` |
| T21 | El menú deslizable: un solo marco fijo y transparente afuera (M9, M11) | C13 | T9 | `MenuPagerView`, `panelSheet` |
| T22 | El ascensor: la torre apilada por las ventanas (M13) | C7 | T4 | `ElevatorRideView`, `ElevatorCabin`, `BoardScene` (cámara del viaje) |
| T23 | Compartir: card de personaje nuevo bloqueante y la imagen con el personaje real (M8, M8b) | C23, C24 | T11 | `ShareCardView`, `ShareMomentChip`, celebración de personaje nuevo |
| T24 | Eventos `openShop` y los 4 eventos nuevos (M14) | C25 | T11, T19 | `events.json`, EK de eventos, `EventPopupView`, navegación con foco |
| T25 | Barrido de SF Symbols y auditoría de UX de las pantallas restantes | C19, C29 | T11–T24 | lo que quede, una pantalla por commit |
| T26 | Textos: catálogo, tutorial, Tour de novedades y lecciones de todo E14 | todas | T7, T11–T24 | `Localizable.xcstrings`, `Tutorial*` |
| T27 | Cierre: `completo`, capturas SE/15/Pro Max/iPad, doc de sesión, HANDOFF, lista para G4 | — | todo | docs |

### Olas (≤ 3 compilando, un dueño por archivo) — G1 ya está cerrada

0. **Antes que nada: T29** (C32, el exploit del boost por video), opus + revisión opus.
1. **Ola 1 (el próximo relevo):** T9 (componentes base; opus, con revisión opus) · T4 · T5.
2. **Ola 2:** T6 · T8 · T10 (T7 no compila: va con ellas, sólo claves y docs). T28 entra en la primera ola con
   lugar libre (archivos disjuntos de todo lo demás).
3. **Ola 3:** T11 · T12 · T21.
4. **Ola 4:** T13 · T17 · T19.
5. **Ola 5:** T14 · T15 · T22.
6. **Ola 6:** T16 · T18 · T23.
7. **Ola 7:** T20 · T24 · T3 (T3 cuando G2/G3).
8. **Ola 8:** T25 · T26.
9. **Ola 9:** T27 (y después G4, el dueño en iPhone).

Fuera del relevo, ya en marcha: T1 (batch de Gemini) y T2 (videos generados, esperan G3).

## Verificación

- Cada tarea: `Tools/v2/oraculo.sh tarea <clases>` una vez; UI tests sólo si el cambio sólo se ve por UI.
- Cada ola: `rapido` en la integración; `completo` al cerrar las olas 3, 6 y 10.
- EK: tests de C5 (bolsa barajada pareja, el vendedor no repite), C17 (migración), C24/C28 (bonus una
  vez, chances del paquete = `PackageRoller`), C25 (`openShop` no toca la economía).
- Pacing: el simulador después de T6 y al cierre; Dios en ~45 h (D11).
- **Chequeo de superposición (D14)** en cada tarea de pantalla: SE y Pro Max en el peor caso (tablero lleno,
  visitante esperando, caja y colchón, 4+ boosts, un aviso); ningún elemento tapa a otro ni al tablero, salvo la
  botonera del ascensor abierta.
- Capturas de cada pantalla tocada en SE y Pro Max. La revisión mira que respete la **idea** de su mockup
  (qué hay, en qué orden, qué se destaca), no que se le parezca al píxel (D13).

---

## Cierre de E14 (T27) (relevo 59, 2026-10-15; cerrado en el 60)

> Borrador del 59, cerrado en el relevo 60: el `completo` de la integración final dio VERDE y `version-2` quedó en `06ca8760` (build 6).

### Qué está hecho

- **T0–T26 y T28–T29 ✅.** Las 30 tareas de código están en `version-2`: T13–T26 entraron con `36697cac` (el `completo`
  `20261015-154752` más el aislamiento del relevo 58); T1–T12, T28 y T29 venían de los relevos 49–54.
- **G1, G2 y G3 cerradas** (mockups, 27 imágenes y 11 videos aprobados por el dueño). Las 27 imágenes y los 11 clips están
  integrados (T3).
- **La E14b (B1–B30) corrió encima**: B1–B19, B26 y B27 en `version-2`; B20–B24, B28 y B29 en `v2i/integ-r58`; B25 en
  `v2i/integ-r59`; B30 en su rama aparte, sin mergear (espera el OK del dueño). Detalle en `tasks.md` §5 «E14b».
- **Cero SF Symbols en controles visibles (T25)** y los textos al catálogo (T26). La 2.0 sale **sin Meta** y con la
  moneda premium en dólar blue (T7, B14).
- El pacing no se movió por E14: Dios en 45,40 h (`.free`) y 32,19 h (`.ads`), 6 reencarnaciones.

### Qué faltaba para cerrar T27 (hecho en el 60, salvo el G4)

1. **El `completo` de la integración final** (integ-r59 con `version-2` mergeada): EK, build, Release 0 warnings,
   unit, UI, store-unit, iPad, SE y pacing. Del 59: integ-r58 tuvo EK 1017 ✅, Release ✅, unit 2263 + 1 rojo (arreglado). **Hecho en el 60:** el `completo` de integ-r60 (`20261016-050819`) dio VERDE (ver abajo).
2. **Hecho (relevo 60, `capturas-r60`, 43 capturas):** las capturas de las pantallas tocadas en SE, iPhone 15 y Pro Max, e iPad (chequeo de superposición, D14). Las
   saca el arnés de E10 T9 (`AppStoreScreenshotTests`, rama `v2i/e10-capturas`) más las del plan.
3. **Hecho:** `Docs/SESION-2026-10-16-v2-relevo-60.md` y las ediciones del `HANDOFF.md` (banner, §4, §5, §7, §8).
4. **G4 🔒 (el dueño):** la pasada en iPhone real, **al final** de todo, con la lista de abajo.

### Lo que queda del dueño (🔒), en orden

La lista completa hasta el envío vive en el plan de E10 («Cierre de E10 → Lo que queda del dueño»). Para E14 son los
puntos 1, 4, 5 y 6 de esa lista: **B30 sí/no**, los **textos de La Marcha y Novedades**, los **gates de E8d/E8e en el
SE** y la **pasada final G4**.

### Lista de la pasada G4 (iPhone SE y Pro Max)

Sin números: se mira, no se mide.

- **Superposición (D14):** nada tapa a nada ni al tablero; la única excepción es la botonera del ascensor abierta sobre los
  boosts. Peor caso en el SE: tablero lleno, visitante esperando, caja y colchón, 4+ boosts y un aviso.
- **La barra de abajo:** las leyendas se leen, los botones «Etiqueta y billete» no pisan el plato, Contratar y
  Reencarnar son solapas; la Tienda está en la barra y el Ranking dentro del Menú › Oficina.
- **Los visitantes:** llegan sin cortes, se paran a mitad de piso, el popup abre solo al tocar, «No, gracias» los manda
  ofendidos; hay uno por piso y varios a la vez.
- **Las cajas y el colchón:** caen en cualquier lugar de su piso, el personaje sale de la caja, el colchón se ve después
  del video (el log `reward after dismiss` dice si el premio llega después de cerrar el video).
- **Los premios en dos pasos (B29):** «¡Dale!» cobra y después «×2 con video» / «No, gracias»; las monedas vuelan al HUD.
- **La Marcha del Puntero:** el chip, los 420 toques en una hora, el cobro de 30 blue una vez, el cupo semanal (el dueño pidió bajar los 420 toques a 2 minutos: cargado en `DUENO.md`, no implementado).
- **La Ruleta, el cofre y el Paquete:** antes, durante y después con su imagen; los premios siempre ilustrados.
- **Los menús:** el pager desliza sin trabas, un solo marco, transparente afuera; cabecera con las flechas a la altura
  del título; Ajustes sin naranja fuera de las cintas.
- **Cero «ORO»:** ni en textos, ni en imágenes, ni en el ícono de la moneda; sólo «dólar blue».
- **Compartir:** la imagen exportada es el personaje con su skin (no un símbolo).
- **Tutorial y Tour:** un jugador nuevo no ve «las pestañas se mudaron»; un veterano sí.
- **Lo que B30 cambia**, si el dueño dice que sí: los de atrás hasta un 15 % más chicos, sin saltos al deambular.

### Actualización del relevo 60 (2026-10-16)

- **B30 tiene el sí del dueño** y entró a la integración: `v2i/integ-r60` (`ab2f41ad`, merge de `b30-merge` con 2 conflictos resueltos en
  `PickupController` y `BarFlapLayoutTests`, sin Meta). La Marcha (B25) y B31–B33 ya estaban en integ-r59; entró además **B34** (el logo blanco de Ader
  Games en el splash y la pantalla de lanzamiento, `2ac58b41`, con el arreglo del cuelgue de arranque `ce0a5c99`). La E14b queda con **B1–B34 ✅ en
  `version-2`** (`06ca8760`).
- **El `completo` de integ-r59** (`20261016-011825`, sobre `5b3d2cce`): EK 1057 · build · unit 2283 · Release 0 warnings · store-ui 3 · iPad 4 ·
  SE 2 · pipeline 107 · pacing Dios 45,40 h (6 reenc.) · UI 199 + 6 rojos + 4 salteados (los 6, resueltos por `fix-ui-r60`; ver
  `Docs/SESION-2026-10-16-v2-relevo-60.md`). **El `completo` de integ-r60** (`20261016-050819`, sobre `0c0676b0`): EK 1057 ✅ · build ✅ · Release 0 ✅ · store-unit 18 ✅ · UI 205 con 0 rojos y
  4 salteados ✅ · store-ui 3 · iPad 4 · SE 2 · pipeline 107 · pacing Dios 45,40 h / 6 reenc. ✅ · unit 2286 + 6 rojos (B30: `PackageFloors` ×2,
  `DepthOrder`, `StageBubble`; B34: `VisibleLiteralsGuard`; `ElevatorRide` = flake conocido). `fix-unit2-r60` (`cc7ffb4e`) los resolvió **sólo en
  tests** (la app era coherente: los tests ahora miden con `depthScale`; «Ader Games» a las `brandWords` de la guardia; `ElevatorRide` 15/15 ×3
  aislado) y `version-2` avanzó por ff a `cc7ffb4e`. Cierra el punto 1 de «Qué falta».
- **Después del 59, el dueño vio en vivo dos defectos** y entraron al **build 6** (`06ca8760`, rapido VERDE: EK 1057 · build · unit 2292 · Release 0):
  **B34** (el splash: el arranque en frío cortaba la subida del logo con el Fisura apareciendo a la vez; el layout estaba bien, era de tiempo; ahora el
  Fisura aparece al terminar la subida, `c8501c11`) y **B32** (el difuminado de la caja no se veía: los clips son premultiplicados y sólo se había
  multiplicado el alfa; `bf8cb930` multiplica color y alfa y rehorneó 3 clips). Ver la trampa nueva en la sesión del 60.
- **Las capturas** de B34 (splash y paso a la pantalla principal) y las de los de atrás con B30 están en el set de `capturas-r60` (`b34/`); el logo que tapaba la cabeza del Fisura quedó arreglado en el build 6 (capturas del arreglo en `b34-fix/`).
- **Lista de la pasada G4, sumas:** (a) el **splash**: el logo blanco de Ader Games aparece centrado, sube en 0,4 s (con Reduce Motion, un fundido),
  y la pantalla de lanzamiento no salta al pasar al splash; (b) **B30 ya no es opcional:** los de atrás hasta un 15 % más chicos, sin saltos al
  deambular, de pie sobre su piso y fáciles de tocar (mínimo 44 pt); (c) el **botón de compra** con un nombre largo en castellano («Coleccionista de
  cartón») no se corta en el SE.
- **Decisión del dueño:** E8d T15 y E8e T9 se miden en el simulador del SE (no hay SE real); el G4 sigue siendo en su iPhone 15 Pro.
