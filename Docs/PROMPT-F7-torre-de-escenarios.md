# PROMPT — F7 "La Torre": mundo vertical persistente, economía larga y prestigio con ORO

> Copiar este prompt completo en una sesión nueva de Claude Code parado en
> `/Users/manuader/Desktop/projects/FisuEvolution`.

---

## Rol y misión

Sos el dev principal de **FisuEvolution** (iOS, SwiftUI + SpriteKit + EconomyKit). Vas a diseñar e implementar el rediseño **F7 "La Torre"**: los escenarios dejan de reemplazarse y pasan a convivir apilados verticalmente, la economía se rebalancea para que el juego sea MUCHO más largo y difícil, y el prestigio pasa a una moneda nueva (ORO) con mejoras permanentes. Todo con acabado high-end y respetando a rajatabla el sistema visual existente.

Dos requisitos transversales, tan importantes como las features:
1. **Contenido 100% data-driven.** La cantidad de escenarios y de personajes VA a cambiar: agregar un fondo, un personaje o una skin mañana tiene que ser cuestión de config + assets, nunca de tocar código. La arquitectura entera se diseña para eso (§6 — los principios son requisito, no sugerencia).
2. **Skins por personaje, persistentes.** Ganadas por progreso o compradas, sobreviven la reencarnación igual que el ORO, y se ven reflejadas de verdad en el tablero.

**Antes de tocar código: entrá en plan mode.** Leé el contexto del §0, consultá el grafo de código, y presentá un plan por fases. Las decisiones marcadas ⚠️ tienen un default elegido — confirmalas o discutilas en el plan, no las descubras a mitad de implementación.

---

## 0. Contexto del repo (leer primero)

- **Stack:** SwiftUI (HUD/menús/popups) + SpriteKit (`BoardScene`) + **EconomyKit** (paquete SPM con la lógica de economía, pura y testeada). iOS 17+, Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` (cero warnings).
- **El `.xcodeproj` NO se versiona**: se regenera con `xcodegen generate` desde `project.yml` (globbea `FisuEvolution/`, los archivos nuevos entran solos). Nunca edites el proyecto desde la UI de Xcode.
- **Grafo de código:** usá `graphify explain "<Símbolo>"` y `graphify path "<A>" "<B>"` (lee `graphify-out/graph.json`; refrescá con `graphify update .`, gratis y local) en vez de grepear a ciegas.
- **Leé estos archivos antes de planear:**
  - `Docs/SESION-2026-07-23-arte-ui-tutorial.md` (estado actual del frontend y por qué)
  - `FisuEvolution/Game/State/GameState.swift` (orquestador: spawn, merge, prestige, popups, income loop)
  - `FisuEvolution/Scenes/BoardScene.swift` (render: fondo por etapa aspect-fill, franja de piso, anchors, hit-testing)
  - `Packages/EconomyKit/Sources/EconomyKit/` (`BoardActions`, `StandardEconomy`, `PlayerState`) y sus tests
  - `FisuEvolution/Resources/Data/economy.json` (board 4×2 = 8 slots hoy, curvas, etapas) y `assets_manifest.json`
  - `FisuEvolution/UI/Art/GameArt.swift` (UIArt puente atlas→SwiftUI + componentes: `GamePanel`, `ArtButton`, `PanelTitleBanner`, `CurrencyPill`, `GameToggle`, `CoinIcon`, `SpeechBubble`)
  - `UI/HUD/HUDView.swift` + `SpawnButtonView.swift`, `UI/Store/UpgradesView.swift`, `UI/Store/StoreView.swift` + `Managers/Store/StoreManager.swift` (sistema de skins embrionario: `skinId(for:)`, `activeSkin`/`setActiveSkin`), `UI/Popups/PassiveUnlockView.swift`, `UI/Popups/PrestigeView.swift`, `UI/Tutorial/TutorialOverlay.swift`
- **Sistema visual vigente (respetarlo, no inventar otro):**
  - Paleta 5+3: `#FFD93D` amarillo, `#FF6B35` naranja, `#FF4D6D` rosa, `#4D96FF` azul, `#6BCB77` verde + crema `#FFF8E7` / ink `#2C2C2C` (colorsets `Palette*`).
  - Tipografía: SF Rounded pesada para títulos y números (`.system(design: .rounded).weight(.heavy)`), body en sistema.
  - Iconos de HUD: círculo crema + borde ink 3pt + glifo SF tintado por función (sistema unificado, no romperlo).
  - UI chica funcional = **vector nativo** (`GameToggle`, `CurrencyPill`); PNG generado solo para lo ilustrativo. Motivo: rembg dejó interiores transparentes en varios PNGs de UI (bug histórico del toggle).
  - Los 11 fondos (`bg_alley`, `bg_urban`, `bg_corporate`, `bg_luxury`, `bg_island`, `bg_moon`, `bg_mars`, `bg_solar`, `bg_galaxy`, `bg_cosmic`, `bg_god_realm`) son cuadrados 1024²/1536², tercio inferior = piso caminable, renderizados aspect-fill anclados abajo.
  - La app fuerza light mode (`preferredColorScheme(.light)`).
- **Convenciones:** strings nuevos en `Localizable.xcstrings` (es idioma base), accessibility identifiers en todo control interactivo, popups automáticos gateados por `fisuTutorialDone`, commits atómicos por fase.

---

## 1. El problema (datos de un jugador real)

1. **Terminó el juego entero (fisura → dios) en ~20 minutos.** Un idle/merge game debería medirse en días o semanas.
2. **La fase "struggling" del fisura es demasiado corta.** Es la identidad del juego y pasa volando.
3. **El passive income es inútil por diseño:** comprás el passive de un tier, evolucionás al siguiente, y perdiste la inversión — nunca conviene comprarlo.

---

## 2. La idea (norte de diseño)

Los escenarios se vuelven **fijos y simultáneos**: una **torre de N pisos** (hoy 11: piso 1 = callejón … piso 11 = reino de dios) navegable con **swipe vertical + dos flechas** (arriba/abajo). Cada piso aloja hasta **10 personajes de los tiers de su etapa**, todos produciendo **a la vez** — ahí el passive income cobra sentido, porque nunca dejás de tener fisuras, oficinistas, CEOs… conviviendo. El giro de dificultad: **solo se contratan fisuras (T1), y solo existen en el piso 1** — todo lo demás se consigue mergeando desde abajo, siempre. Encima de eso: **mejoras por personaje compradas con plata** (se pierden al reencarnar), las mejoras globales actuales pasan a ser **permanentes, compradas con ORO** (la moneda que ganás al reencarnar), y un **sistema de skins por personaje** que persiste entre reencarnaciones y se ve en el tablero.

---

## 3. Diseño funcional detallado

### 3.1 La Torre
- Los escenarios conviven apilados. El mapeo **etapa→tiers ya existe** en la config: hacelo explícito en `economy.json` v2 como `floors[]`, cada uno con `id`, `background`, `tierRange`, `capacity: 10`.
- **El número de pisos y de personajes NO es una constante.** Hoy son 11 fondos y ~46 tipos; el mes que viene pueden ser más. Prohibido hardcodear conteos, ranges o switches por etapa en código: todo sale de `floors[]` y del catálogo de tipos, y la UI (navegación, pills, listas de mejoras) escala sola con N. Agregar un piso nuevo = 1 entrada en `floors[]` + el PNG del fondo; agregar un personaje = PNGs al atlas + entrada en manifest/economy. Nada más.
- **El mapeo tier→piso es INTERCAMBIABLE, no fijo.** Qué tiers viven en cada piso y con qué tier se desbloquea cada escenario es puro dato de `floors[]` — tiene que poder reasignarse en cualquier momento (mover un tier de un piso a otro, correr el tier de desbloqueo de un escenario) editando solo la config. Consecuencia arquitectónica clave: **los saves guardan unidades por TIPO, nunca por índice de piso** — la ubicación se recalcula contra el mapeo vigente al cargar (reconciliación). Así, un remapeo entre versiones reacomoda solo las partidas existentes en vez de romperlas.
- **Todos los tiers existentes** quedan repartidos entre los 11 pisos según ese mapeo. Ojo: existe el **fork de carrera en T9** (`CareerChoiceView`, ramas junior/senior programmer/architect/doctor/lawyer) — el mapeo tier→piso debe contemplar que las ramas del mismo nivel comparten piso.
- Capacidad total teórica: 110 personajes. Hoy el board es 4×2=8 global — esto lo reemplaza.

### 3.2 Navegación vertical
- **Swipe** arriba/abajo sobre la escena + **dos flechas** en el borde derecho (estilo `hudIconButton`: círculo crema, borde ink, chevron tintado). La flecha hacia un piso bloqueado muestra candado y un hint del requisito.
- **Pill indicador** (vector, estilo `CurrencyPill`): "Callejón · 1/11" + ocupación "7/10".
- Transición de cámara con spring + parallax sutil + haptic `.light`. Nada de cortes secos.

### 3.3 Contratación (el giro de dificultad) — DECISIÓN CERRADA con el dueño
- El merge puro es matemáticamente inviable para el final del juego (T30 = 2²⁹ fisuras), así que la contratación es **contextual al piso**: parado en un piso desbloqueado, el botón contrata el **TIER BASE de ese piso**.
- **Piso 1 = El Fisura, barato** (la fase struggling es 100% merge puro).
- **Pisos superiores = PRECIO PUNITIVO**: contratar el tier base de un piso recién desbloqueado tiene que ser claramente NO rentable (horas de income); recién se vuelve rentable como *backfill* cuando tu frontera está 2-3 pisos más arriba. La curva por piso (`hireCounts` por piso + multiplicador punitivo) vive en config y la CALIBRA LA SIMULACIÓN.
- Piso bloqueado o lleno → botón en el patrón legible ya resuelto (texto ink + desaturación, NUNCA `.disabled` con dimming).
- Desaparece el spawn progresivo global (`spawnQuote` por `tierOffset`).
- **Queda RECHAZADO** el "ascenso directo pagado" (pagar para subir de tier a una unidad): el dueño lo vetó explícitamente.

### 3.4 Merge y ascenso
- El merge (arrastrar dos iguales) queda **confinado al piso actual**.
- Si el resultado pertenece al piso siguiente → **animación de ascenso** (la unidad vuela hacia arriba; usar `fx_evolution_flash`/`fx_unlock` + partículas; opcional: la cámara lo sigue en el primer ascenso a cada piso).
- ⚠️ **Default:** si el piso destino está lleno, el merge se **bloquea** (bounce + toast "Piso lleno — hacé lugar arriba"). Alternativa a discutir: cola de ascenso.
- **Long-press sobre un personaje ya no abre la hoja destructiva directa: abre su ficha (§3.10)**, que incluye "dejar de contratar" entre otras acciones. La regla de seguridad se mantiene: nunca puede dejar la partida rota sin unidades (validar la regla actual de `dismissCharacter`).

### 3.5 Passive income (ahora el corazón del juego)
- **Todos los personajes de todos los pisos producen siempre** — visibles o no, y offline (integrar con el sistema de offline earnings existente).
- El income por tap aplica solo al piso visible.
- Los passive unlocks por tipo se mantienen y ahora nunca quedan huérfanos: siempre vas a tener instancias de tiers bajos. Su punto de compra pasa a la **ficha de personaje** (§3.10). DECIDIDO en plan: el popup proactivo de `PassiveUnlockView` **se retira** (la ficha es el único entry point; menos interrupciones).
- El contador del HUD muestra el income/sec **total de la torre**.

### 3.6 Mejoras con PLATA (nuevas, por personaje)
- Una línea de mejora por **cada tipo de personaje**: "Ganancias de El Fisura ×2" — multiplica el income (activo + pasivo) de TODAS las instancias de ese tipo.
- ⚠️ **Default:** niveles ×2 por nivel (×2, ×4, ×8…), costo creciente agresivo, sin tope. Config-driven.
- Se compran con **monedas** y **se pierden al reencarnar**.
- Solo se listan los tipos ya desbloqueados. Cada fila muestra el retrato del personaje (extender `UIArt` para servir retratos desde `earth.atlas`/`cosmic.atlas`).

### 3.7 ORO y mejoras permanentes
- Nueva moneda de prestigio: **ORO**. Reemplaza los soul points actuales (⚠️ migración default: conversión 1:1).
- Se gana **solo al reencarnar**; fórmula tunable en config (p.ej. `floor(sqrt(lifetimeEarnings / K))`) calibrada para que el primer ORO significativo llegue alrededor del piso 5-6.
- Las mejoras globales actuales (More Cash, Price Control, Siesta Mode, Hardened Fingers, Hit It Big, Golden Touch, Soul Interest…) **pasan a costar ORO y son PERMANENTES** — sobreviven la reencarnación.
- **Reencarnar resetea (RunState):** monedas, todos los pisos/personajes (volvés al piso 1 vacío), mejoras de plata. **Mantiene (MetaState):** ORO, mejoras de ORO, skins ganadas/compradas y la skin activa por personaje (§3.9), tutorial visto, máximo piso histórico (para stats, no para saltear progresión).
- **UI:** `UpgradesView` rediseñada con dos pestañas — **[Personajes]** (plata) y **[Permanentes]** (ORO) — usando `ui_tab_active/inactive` o segmented vectorial si esos PNG tienen el interior comido. El balance de ORO se muestra en esa pestaña y en `PrestigeView` ("Vas a ganar X ORO"). ⚠️ NO agregar otra pill al HUD sin validarlo: la fila ya va justa de ancho (bug de desborde ya arreglado una vez).
- Icono de ORO: ver §5.

### 3.8 Desbloqueo de pisos
- Cada piso declara en config su **tier de desbloqueo**: campo `unlockTier` en `floors[]` (default: el primer tier de su `tierRange`, pero **overrideable por piso** — diseño/balance puede decidir que un escenario se abra antes o después sin tocar código). El piso se desbloquea al **crear por primera vez** (vía merge) ese tier. Celebración: reveal existente + ascenso de cámara al piso nuevo.
- Persistir el desbloqueo por **id de piso** (no por índice ni por tier): si un futuro remapeo cambia `unlockTier`, los pisos ya desbloqueados siguen desbloqueados.
- ⚠️ **Specials** (`sp_*`, 10 tipos): definir en plan dónde viven — default: anclados al piso donde cayeron, **sin ocupar slot** de los 10.

### 3.9 Skins por personaje (persistentes, como el ORO)
- **Ya existe un embrión**: la tienda vende skins (`StoreManager.skinId(for:)`, `GameState.activeSkin`/`setActiveSkin`). Leé esa implementación y evolucionala a un sistema general — no dupliques un segundo sistema al lado.
- **Modelo:** catálogo `skins[]` en config/manifest: `{ id, characterType, displayNameKey, textureKey, source }`, donde `source` es `purchase` (producto de la tienda existente) o `milestone` (p.ej. "llegaste al piso 5", "reencarnaste 3 veces") — las condiciones de milestone también son data-driven, no código.
- **Cualquier personaje puede tener N skins en cualquier momento**: agregar una skin = PNGs @2x/@3x al atlas del personaje + una entrada en el catálogo. Cero código nuevo por skin. El sistema no asume qué personajes tienen skins ni cuántas.
- **Persistencia:** skins poseídas + skin activa por tipo viven en el **MetaState** (§6) — sobreviven la reencarnación exactamente igual que el ORO.
- **Render real en el juego:** `CharacterNode` resuelve su textura vía un `SkinResolver` (tipo + skin activa → textureKey; si el arte falta, fallback silencioso a la textura base). Aplica a TODAS las instancias del tipo, en todos los pisos, y también a los retratos en las filas de mejoras. Si el fisura tiene skin, cada fisura del piso 1 se ve con esa skin.
- **UI de selección:** la superficie principal es la **ficha de personaje** (long-press, §3.10), con flechas ‹ › para navegar skins y **siluetas negras no equipables** para las bloqueadas. Ganar una skin por milestone dispara una celebración (popup estilo reveal existente, gateado por tutorial como el resto).

### 3.10 Ficha de personaje (long-press) — la superficie canónica por personaje
Mantener presionado cualquier personaje del tablero abre su **ficha**: un sheet con `GamePanel` que concentra todo lo de ese personaje. Contenido:

1. **Retrato grande** del personaje — renderizado **con la skin activa aplicada** (mismo `SkinResolver` del tablero) — y su **nombre** arriba (estilo `PanelTitleBanner`).
2. **Selector de skin con flechas ‹ ›** a los costados del retrato: navega TODAS las skins catalogadas del tipo (base incluida), con dots o "2/4" abajo.
   - Skin **desbloqueada**: se ve a color; botón "Equipar" habilitado; equipar aplica al instante a todas las instancias del tipo en todos los pisos (§3.9).
   - Skin **bloqueada**: se ve como **SILUETA NEGRA** (el sprite renderizado en tinta plena `PaletteInk`, estilo "personaje misterioso") con su condición de desbloqueo o precio debajo; el botón de equipar queda **deshabilitado y NO permite guardarla** (patrón legible ya establecido: texto ink + desaturación, nunca dimming del sistema).
   - Cerrar la ficha sin equipar no cambia nada; la selección solo persiste al confirmar sobre una skin desbloqueada.
3. **Comprar passive income** del tipo — absorbe el entry point de `PassiveUnlockView`: muestra yield por instancia × instancias actuales; una vez comprado, badge de "activo" en la ficha.
4. **"Dejar de contratar"** — despide la unidad long-presseada; botón destructivo (`PalettePink`) con confirmación, mismas reglas de seguridad que hoy (§3.4).

Diseñala como **lista de secciones componible** (retrato+skins / acciones económicas / acciones destructivas), no como layout fijo: es la superficie donde van a entrar futuras acciones por personaje (boosts dirigidos, stats, logros del tipo). Accessibility identifiers en flechas, equipar, passive y despedir.

---

## 4. Balance (economy.json v2) — el juego tiene que ser LARGO

- Curvas 100% en config, nada hardcodeado. Knobs mínimos: costo del fisura y su crecimiento, income por tier, multiplicador por piso, fórmula de ORO, costos de mejoras por personaje, costos de mejoras de ORO, caps de offline.
- **Targets de pacing** (tunables — validarlos conmigo en el plan):
  - Piso 1 (fase fisura struggling): **≥ 20-30 min de juego activo** antes del primer ascenso al piso 2.
  - Cada piso ~1.5-2× la duración del anterior.
  - Primera reencarnación conveniente: piso 5-6 (≥ 4-6 h acumuladas).
  - Llegar a Dios: requiere **varias reencarnaciones**; ≥ 30-50 h de juego óptimo total.
- **OBLIGATORIO — harness de simulación en EconomyKit:** un bot greedy headless que juega (contrata, mergea, compra mejoras, reencarna cuando conviene) a tiempo simulado y reporta tiempo-a-hito (piso 2, piso 5, primera reencarnación, dios). Tests que asserten los targets con tolerancia (±30%). Sin esto es imposible saber si el juego dura 20 minutos o 50 horas — es exactamente el bug de diseño que estamos arreglando.

---

## 5. Arte y assets (consistencia hand-made)

- **NO regenerar los 11 fondos** — ya existen, son coherentes y cada piso es una pantalla.
- **Vector nativo** (estilo `GameToggle`/`CurrencyPill`): flechas de navegación, pill de piso, contador de ocupación, candado/scrim de piso bloqueado, tabs (si los PNG `ui_tab_*` tienen interior transparente), toasts.
- **Generar con el pipeline SOLO 1 asset: el icono de ORO** — moneda/lingote dorado con destello, mismo lenguaje flat + outline negro grueso de los 93 (basar el prompt en el de `ui_coin` con la misma referencia de estilo; pipeline en `Tools/asset-pipeline/`, prompts en `prompts/gemini_pro/`). Fallback vectorial mientras tanto (círculo dorado + borde ink), como hace todo el design system.
- Retratos en filas de mejoras: servirlos desde los atlas de personajes vía `UIArt` extendido (sprite completo a tamaño chico alcanza; evaluar crop de cabeza en plan).
- **Skins:** convención de nombre de textura `"<baseKey>__<skinId>"` (p.ej. `homeless_idle__pirata`) en el mismo atlas del personaje, @2x/@3x como todo lo demás. El juego debe **tolerar skins catalogadas cuyo arte todavía no existe** (fallback a la base) para poder shippear catálogo y arte por separado.
- Animación de ascenso: `fx_evolution_flash`/`fx_unlock` existentes + partículas SpriteKit simples. Microinteracciones con spring y haptics en: ascenso, desbloqueo de piso, compra de mejora, reencarnación. Acabado high-end: cero placeholders visibles.

---

## 6. Arquitectura técnica y principios (los principios son requisito)

**Principios de diseño — el juego va a seguir creciendo; dejalo listo para eso:**
1. **Content-driven, no code-driven.** Pisos, tipos de personaje, cadena de evolución (incluido el fork de carrera), mejoras, skins y milestones se definen en config/manifest. Agregar contenido = editar JSON + soltar PNGs. Un **`ContentRegistry`** único carga y valida todo en el bootstrap; ningún otro módulo parsea JSON por su cuenta ni conoce conteos.
2. **RunState vs MetaState.** Split explícito de la persistencia: `RunState` = lo que muere al reencarnar (monedas, pisos/unidades, mejoras de plata); `MetaState` = lo que sobrevive (ORO, mejoras permanentes, skins + skin activa, stats, tutorial). Reencarnar se vuelve trivial y a prueba de bugs: `run = RunState.fresh()` — imposible "olvidarse" de resetear o de preservar algo.
3. **Cero números mágicos.** Nada de `11`, `46` ni switches por etapa en el código. Conteos, ranges y orden salen del registry.
4. **Validación como contrato.** `GameContentValidationTests` es el guardián: todo tier tiene piso y arte, todo piso tiene fondo, toda skin referencia un tipo existente, la cadena de evolución es contigua (ramas incluidas). Contenido mal referenciado rompe tests en CI, nunca el runtime en manos del jugador.
5. **Esquema versionado + migraciones aditivas.** `schemaVersion` en saves y config; toda migración con su test; campos nuevos siempre opcionales con default. Los saves de usuarios reales no se rompen jamás.
6. **Composición chica y testeable**, al estilo actual de EconomyKit: la lógica vive pura en el paquete; SwiftUI/SpriteKit solo presentan. Cada sistema nuevo (skins, milestones, torre) entra como tipo chico con su test, no como métodos sueltos en GameState.

- **BoardScene:** una sola `SKScene` con `SKCameraNode`. Pisos como `FloorNode` (sprite de fondo + capa de personajes) apilados con offset fijo = alto de pantalla. La cámara anima entre pisos con spring.
- **Rendimiento:** animar SOLO el piso visible (pausar `SKAction`s de los demás); lazy-load de texturas de fondo (mantener piso actual ±1, descargar lejanos); el income de pisos no visibles se computa numéricamente en GameState/EconomyKit (la escena solo dibuja — ya es así hoy). Target: 60 fps con 5+ pisos poblados en el simulador (el overlay DEBUG ya muestra fps).
- **EconomyKit:** `PlayerState` v2 dividido en **`RunState`** (unidades, monedas, mejoras de plata) + **`MetaState`** (ORO, mejoras permanentes, skins poseídas + activa por tipo, stats). **Persistencia de unidades por TIPO** (§3.1): en memoria podés modelar `floors: [FloorState]` para el gameplay, pero lo serializado guarda las unidades por tipo y la ubicación se **reconcilia contra el mapeo vigente al cargar** — un remapeo tier→piso en config reacomoda las partidas, no las rompe. `BoardActions` stage-aware: `applySpawn` (solo T1 → piso del tier inicial), `applyMerge` (piso + promoción al que corresponda por config), `removeUnit(floor:)`. Mantener la pureza del paquete y su cobertura de tests.
- **Migración de saves v1→v2** (obligatoria y testeada): distribuir las unidades existentes al piso de su tier (respetando capacidad 10), soul points → ORO (⚠️ 1:1 default), skins compradas + `activeSkin` actuales → MetaState, mejoras globales ya compradas → decidir en plan si se convierten a versión ORO o se reembolsan.
- **GameState:** piso visible, navegación, income agregado de la torre, gating de popups por tutorial intacto.

---

## 7. Testing y criterios de aceptación

- [ ] Build verde con warnings-as-errors; todos los tests existentes migrados y en verde.
- [ ] Tests nuevos de EconomyKit: spawn solo-T1/piso-1, merge con promoción de piso, bloqueo por piso destino lleno, fórmula de ORO, permanencia de mejoras ORO tras reencarnar, pérdida de mejoras de plata al reencarnar, migración v1→v2.
- [ ] Simulación de pacing con asserts (§4) pasando.
- [ ] `GameContentValidationTests` actualizado: `floors[]` completo, cada tier mapeado a exactamente un piso, capacidad 10, specials contemplados, catálogo de skins íntegro (toda skin referencia un tipo existente).
- [ ] **Drill de extensibilidad (test, no promesa):** un fixture de config con un piso extra + un personaje extra + una skin extra (arte dummy) pasa la validación y aparece funcionando en el juego **sin tocar una línea de código**. Este test es la prueba de que el principio §6.1 se cumplió.
- [ ] **Drill de remapeo (test):** cargar un save existente con una config donde un tier cambió de piso y un `unlockTier` se corrió → las unidades quedan reubicadas según el mapeo nuevo, los pisos ya desbloqueados (por id) siguen desbloqueados, y no se pierde ninguna unidad (si el piso nuevo desborda la capacidad, aplicar la regla de reconciliación de mayor-tier ya existente).
- [ ] **Skins end-to-end:** ganar una por milestone, comprar una, seleccionarla, verla renderizada en TODAS las instancias del tipo en el tablero y en los retratos, reencarnar y verificar que la skin activa sobrevive; fallback limpio si el arte falta.
- [ ] **Ficha de personaje (§3.10):** long-press abre la ficha con retrato (con skin activa) + nombre; flechas ‹ › recorren las skins; una bloqueada se ve como silueta negra con su condición y NO se puede equipar (botón deshabilitado legible); comprar passive income desde la ficha funciona y queda con badge; "dejar de contratar" pide confirmación y respeta las reglas de seguridad.
- [ ] **Verificación en simulador (obligatoria, con screenshots):** install limpio → tutorial → fase fisura → primer ascenso con animación → navegación con flechas y swipe → pestañas de mejoras (plata y ORO) → reencarnación completa (ganar ORO, comprar permanente, verificar que sobrevive al reset) → arrancar con un save v1 y ver la migración correcta.
- [ ] 60 fps con varios pisos poblados; sin leaks de texturas al navegar toda la torre.
- [ ] Accessibility identifiers en flechas, pill de piso, tabs y filas de mejoras.

---

## 8. Proceso

1. **Plan mode primero.** Leé el §0, consultá graphify, resolvé las decisiones ⚠️ y presentá el plan por fases.
2. Fases sugeridas (una = un commit, compilada y verificada en simulador antes de seguir):
   - **F7.1** EconomyKit v2: modelo de pisos + migración + tests + simulador de pacing.
   - **F7.2** La Torre en BoardScene: cámara, FloorNodes, navegación (swipe + flechas), lazy-loading.
   - **F7.3** Contratación solo-T1, merge con ascenso, desbloqueo de pisos con celebración.
   - **F7.4** Mejoras por personaje (plata) + tienda permanente (ORO) + reencarnación nueva sobre el split Run/Meta.
   - **F7.5** Sistema de skins + ficha de personaje (§3.10): catálogo, milestones, SkinResolver en el tablero, ficha con flechas/siluetas/passive/despedir, migración de las skins de tienda.
   - **F7.6** Balance fino contra la simulación + polish (animaciones, sonido, haptics, icono ORO) + drill de extensibilidad.
3. **Tutorial:** sumá 1-2 pasos del Fisura explicando la torre ("Cuando evolucionan se mudan arriba — subí a visitarlos") usando el `TutorialOverlay` existente.
4. Al cerrar: actualizá `Docs/ESTADO.md` y dejá bitácora `Docs/SESION-<fecha>-f7-torre.md` con el formato de las anteriores.

---

## 9. Fuera de alcance

Monetización/ads nuevos (productos StoreKit nuevos NO; integrar las skins de tienda existentes al catálogo nuevo SÍ), Game Center, `fisura_wave`, regeneración de fondos o personajes, **arte de skins nuevas** (entra el SISTEMA de skins completo; el catálogo puede shippear con las skins de tienda existentes y los milestones definidos con arte pendiente, gracias al fallback), cambios al pipeline de arte (salvo el icono de ORO), fuente de marca embebida.

---

## ⚠️ Decisiones default tomadas (confirmar en plan, no re-litigar después)

1. ~~Hire desde cualquier piso cae al piso 1~~ **REEMPLAZADA por decisión del dueño**: contratación contextual al piso (tier base del piso, precio punitivo — §3.3). Gate de reencarnación pasa a `oroGained ≥ 1` (consecuencia del pacing aprobado: 1ª reencarnación en piso 5-6, no requiere a Dios en el tablero).
2. Merge bloqueado si el piso destino está lleno — vs. cola de ascenso.
3. Soul points → ORO 1:1 en la migración.
4. Mejoras por personaje: ×2 por nivel, sin tope.
5. Specials no ocupan slot y quedan anclados al piso donde cayeron.
6. Targets de pacing del §4 (los números exactos se calibran con la simulación).
7. Skins: **una skin activa por tipo de personaje** (no por instancia); se cambian desde la ficha de personaje (§3.10, flechas ‹ › + siluetas negras para bloqueadas); fuentes = compra (tienda existente) + milestones config-driven.
8. Convención de textura de skins: `"<baseKey>__<skinId>"` en el mismo atlas del personaje.
9. `unlockTier` de cada piso = primer tier de su `tierRange` salvo override explícito en config; el desbloqueo se persiste por id de piso.
10. Saves guardan unidades por tipo; la ubicación en pisos se reconcilia contra la config vigente en cada carga.
