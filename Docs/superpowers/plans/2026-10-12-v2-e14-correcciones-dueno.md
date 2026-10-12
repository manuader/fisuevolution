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
| D13 | **G1 cerrada (2026-10-12): el dueño aprobó TODOS los mockups.** «Algunos no se ven exactamente como en el juego, pero la idea general está bien.» → El mockup fija **disposición, jerarquía, contenido y flujo**; la apariencia final sale de los componentes reales del juego (gramática v3, FisuJobs como referencia, el arte real). No se copian colores ni medidas del CSS del mockup. |

## Gates del dueño

- **G1 — Mockups aprobados: ✅ CERRADA (2026-10-12).** Página: https://claude.ai/artifact/CSQZvzWWFZYzst4Krx6Pn1
  (privada del dueño); copia en el repo: `Docs/correcciones-v2/mockups/fisu-e14.html` (abrir local, con su
  carpeta `a/`). Cada tarea de la fase 2 nombra su mockup (M1…M14) y lo sigue según D13.
- **G2 — Arte de imágenes aprobado** (las 27 de `fisu-v2-premios`, revisión en la interfaz local). Estado
  al cierre de la sesión: el batch de Gemini corre (`correr-batch-gemini.command`, supervisor); salida en
  `projects/fisu-v2-premios/output/`.
- **G3 — Videos aprobados** (los 11 de `fisu-v2-premios/video`). Estado: **generados** con Kling v3.0
  (720×720, 24 fps; 94,5 créditos); 8 ok y 3 dudosos (`cofre_sacude`, `cofre_abre`, `colchon_abre`) según
  `video/out/revision.md`. Los `_sacude` y `ruleta_premio` salieron de 3 s (Kling no baja de 3): T3 los
  recorta/acelera al integrar. Espera la revisión del dueño.
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

| Tarea | Qué | Corrección | Depende | Dueño de |
|---|---|---|---|---|
| T4 | Fuera los videos de fondos de piso y de los 43 personajes base | C1, C22 | — | `FloorNode`, `BoardScene` (sólo el fondo y el clip de personaje), `loops_manifest` (`floors`, `characters` base), `AnimPacks/`, `project.yml`, `video_assets.py` |
| T5 | Intercambio de tiers 7↔8 + migración del save por posición | C17 | — | `tiers.json`, EK (migración), tests de save |
| T6 | Visitantes: un solo carril, bolsa barajada por visitante, «No, gracias» en el motor, pacing compensado | C5 | — | `VisitorScheduler`, `VisitorsConfig`, `visitors.json`, save, simulador |
| T7 | ORO → dólar blue en textos (es/en), ASC y docs de review | C8 | — | `claves-pendientes/t7.json`, `Distribution/*`, `GameArt` (ícono, con fallback) |
| T8 | Desbloqueo de piso insalteable (M2) | C21 | — | `CelebrationQueue`, `BoardScene.tapDuringCelebration`, `CinematicOverlay` |
| T9 | **Componentes base**: `GameButton` (medallón, colores por función), `PopupContainer` (centrado, alto máximo, scroll interno), `RewardIllustration(kind:)` con rayos, estados (listo/en curso/bloqueado/hecho), `CornerSeal` | C4, C15, C19, C29 | — (G1 ✅) | `GameArtComponents.swift`, `PanelFrames.swift`, componentes nuevos |
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

1. **Ola 1 (el próximo relevo):** T9 (componentes base; opus, con revisión opus) · T4 · T5.
2. **Ola 2:** T6 · T8 · T10 (T7 no compila: va con ellas, sólo claves y docs).
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
- Capturas de cada pantalla tocada en SE y Pro Max contra su mockup aprobado: la revisión compara
  mockup ↔ captura.
