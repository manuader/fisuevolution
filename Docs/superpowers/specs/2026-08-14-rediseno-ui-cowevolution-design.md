# Rediseño de UI estilo Cow Evolution — spec de diseño

> **Fecha**: 2026-08-14 · **Estado**: aprobado por el dueño (4 decisiones abajo)
> **Objetivo**: que FisuEvolution se vea y navegue como un juego iOS de alta
> calidad 2026, con la estructura de Cow Evolution (HUD superior contiguo +
> barra inferior de 6 pantallas) pero la identidad visual propia (paleta de 7
> colores, borde ink, crema, rounded heavy, humor argentino).
>
> Este spec asume leído `Docs/HANDOFF.md` (§2 reglas, §3 arquitectura, §7
> trampas). Todo lo que acá se referencia con `archivo:línea` fue verificado
> contra el código el 2026-08-14.

---

## 0. Decisiones del dueño (2026-08-14, no se re-litigan)

1. **La tienda de personajes se llama "FisuJobs"** — parodia propia de portal
   de empleo. Nada de "LinkedIn" literal (riesgo de marca en App Review).
2. **Nueva curva de precios por tier**: cada personaje desbloqueado se puede
   contratar con precio propio, con un premium exponencial por tier que hace
   que comprar el tier alto nunca convenga contra mergear. Se calibra con
   `pacing-sim`, se documenta en `balance-log.md`. **El gate de un piso y el
   primer Fisura a 50 NO cambian** (decisiones §5 del HANDOFF).
3. **Skins pagas: quedan las 2 actuales** (mundialista, parrillero). El
   catálogo queda preparado para sumar skins nuevas (gratis o pagas) de forma
   puramente data-driven — una entrada de config + arte (+ producto si es
   paga), cero código.
4. **Iconos: vectorial ahora, batch después.** Los iconos nuevos se dibujan en
   SwiftUI como arte provisorio de calidad; la cola de prompts de Gemini queda
   lista y el dueño corre el batch desde Terminal.app cuando quiera. La
   integración posterior es cero código (fallback atlas→vector).

---

## 1. Principios que el rediseño NO rompe

- **SwiftUI nunca lee `PlayerState`** (HANDOFF §3). Toda pantalla nueva
  consume proyecciones publicadas por `refreshProjections()` (GameState.swift:639)
  o computadas re-evaluadas contra `effectsVersion`/`coinsText`/`boardVersion`
  (patrón `floorMap`, GameState+Tower.swift:38; `characterUpgradeRows`,
  GameState+Upgrades.swift:76).
- **Ninguna proyección lleva tiempo restante ni valores que cambien solos**
  (patrón `ActiveBonus`): los countdowns los cuenta la vista con UN timer 1 Hz.
- **Contenido data-driven**: catálogos nuevos (logros) van como JSON en
  `Resources/Config/` + mirror Codable + validación en `GameContentLoader`.
- **La fórmula de precio vive en UN lugar** (EconomyKit), compartida por juego
  y `PacingSimulator`. La UI jamás recalcula precios ni gates.
- **Identidad visual**: paleta 7 colores del asset catalog, fondo crema,
  bordes `PaletteInk`, tipografía `.rounded` heavy/black, arte flat hand-made
  con outline grueso. Light mode forzado (RootView.swift:24) se mantiene.
- Reglas §2 del repo: `xcodegen generate` al agregar/borrar Swift (con Xcode
  cerrado), cero warnings, strings a `Localizable.xcstrings` (es+en) en el
  mismo commit y a mano, `accessibilityIdentifier` en todo control, commits
  atómicos en español.

---

## 2. Design system v2 (GameArt)

Se extiende `FisuEvolution/UI/Art/GameArt.swift` (o archivos hermanos nuevos
`GameArt+Components.swift`, `GameIcons.swift` si crece demasiado — GameArt ya
tiene 305 líneas). Componentes nuevos, todos con fallback vectorial:

| Componente | Extraído de / nuevo | Uso |
|---|---|---|
| `GameCard` | extrae `UpgradesView.cardBackground` (:252) + `FloorMapView.rowBackground` (:151) | tarjeta de fila universal: crema, radio 14, stroke ink 2pt, sombra suave; variante `highlighted` (borde Palette de acento) y `locked` (desaturada) |
| `GameTabBar` + `GameTabItem` | nuevo | barra inferior de 6; item = icono 30pt + estado activo (fondo `ui_tab_active` o cápsula PaletteYellow) con bounce al tocar |
| `IconButton` | extrae `hudIconButton` (HUDView.swift:185) | botón circular 52×52 con `UIArt.image(artKey) ?? Image(systemName:)` |
| `GameIcon` | nuevo (`GameIcons.swift`) | glifos vectoriales propios (ver §14): cada icono es un `View` dibujado con Paths/símbolos compuestos, mismo lenguaje flat + outline |
| `SectionHeader` | nuevo | título de sección dentro de paneles (cinta `ui_header_ribbon` 9-slice + texto) |
| `ProgressBar` | nuevo | barra de progreso (niveles de upgrade, progreso de logro): cápsula crema + fill Palette + stroke ink; usa `ui_progress_bar` si está |
| `PricePill` | variante de `CurrencyPill` | botón de precio estilo "cinta" de Cow Evolution: icono moneda/ORO + monto formateado con `CoinFormatter`, estados afford/no-afford |
| `CountBadge` | nuevo | badge circular `xN` para organigrama y contadores |
| `Tokens` | nuevo enum | tipografía (`display`, `title`, `body`, `caption` — todas `.rounded`) y espaciados (4/8/12/16/24) para dejar de repetir literales |

Reglas: los contenedores NO llevan `accessibilityIdentifier` (trampa 9a-bis);
scrims/fondos decorativos siempre `.allowsHitTesting(false)` (trampa 9a).

---

## 3. HUD superior

Reemplaza el cuerpo de `HUDView` conservando proyecciones, anclas de tutorial
e identifiers pineados. Estructura (de arriba a abajo):

1. **Barra contigua** (una sola pieza visual, cápsula/panel crema ancho
   completo con borde ink):
   - **Izquierda**: botón moneda-con-`+` (`CoinIcon` + badge "+" rosa) → abre
     la tienda IAP. Id nuevo `hud.coins.plus`, label `hud.coins.plus.label`.
   - **Centro**: monto de monedas (`coinsText`, id `hud.coins`, ancla
     `.coins`) y debajo, en la misma columna, `X /s` con
     `towerIncomePerSecondText` — id nuevo `hud.income`, elemento de estado
     (`.accessibilityValue`).
   - **Derecha**: botón **ascensor** (icono elevador) → abre `ElevatorView`
     (el FloorMapView restyleado, §6). Conserva id `hud.map`, label
     `map.hud.label` y ancla `.map`.
2. **Fila de torre compacta**: flecha abajo · pill del piso (nombre +
   `ocupados/capacidad`) · flecha arriba. Conserva `tower.arrow.down`,
   `tower.pill`, `tower.arrow.up` y `moveVisibleFloor(by:)`. El coins/sec se
   MUDA de esta pill a la barra (punto 1). ⚠️ Al tocar esta línea se arregla
   la clave rota `%@/%@ · %@/%@ · %@/s` (trampa 5 viva en HUDView.swift:84):
   la línea nueva interpola SOLO `String(_:)`.
3. **Multiplicador de reencarnación**: chip `×N` (→ `×M` si conviene), igual
   semántica que hoy (`prestigePreview`), conserva `hud.prestige.multiplier`.
4. `ActiveBonusBar` y `EventBannerView` quedan como están (debajo, a la
   izquierda).

El botón de reencarnar (`hud.prestige`) se muda de la bottomBar a un botón
flotante sobre el tablero, arriba de la barra inferior, visible sólo con
`prestigeAvailable` (igual que hoy).

Los 4 `hudIconButton` actuales desaparecen del HUD: sus destinos pasan a la
barra inferior (§4) conservando los identifiers ahí.

---

## 4. Barra inferior de 6 pantallas

Nueva `BottomMenuBar` en `GameBoardView.bottomBar` (RootView.swift:246-269),
conservando el ancla `.bottomBar`. Orden (espejo de Cow Evolution):

| Pos | Pantalla | Icono | Identifier | Nota |
|---|---|---|---|---|
| 1 | **FisuJobs** (grande, destacado a la izquierda como la vaca) | cara del Fisura (`homeless_face` del atlas) | `hud.hire` (nuevo) + ancla `.hire` | reemplaza a `SpawnButtonView` |
| 2 | Upgrades | flecha verde | `hud.upgrades` + ancla `.upgrades` | conserva id pineado |
| 3 | Customization | gorra+pincel | `hud.skins` (nuevo) | pantalla nueva |
| 4 | Regalos | caja de regalo | `hud.bonus` | conserva id pineado |
| 5 | Tienda IAP | bolsa | `hud.store` | conserva id pineado |
| 6 | Menú (grande a la derecha, como el cuaderno) | libreta | `hud.settings` | conserva id (ningún test lo usa hoy) |

- Cada botón abre su `.sheet` (se mantiene el patrón sheet; nada de
  `fullScreenCover`). Los `@State showX` de RootView colapsan en un
  `@State activeScreen: GameScreen?` (enum) + un solo `.sheet(item:)` para las
  6 pantallas del menú; los popups `item:`-driven quedan como están.
- `SpawnButtonView` se elimina de la pantalla principal. El id `hud.spawn`
  muere; los tests que lo usaban se reescriben (§19).
- La barra achica el alto útil del tablero: se ajusta
  `BoardScene.bottomInset` (BoardScene.swift:128) al alto real de la barra y
  se corre `CrowdDepthTests`/`CrowdBandTests` (trampa 13).
- El swipe vertical para cambiar de piso sigue funcionando sobre campo vacío.

### Ascensor (`ElevatorView`)

`FloorMapView` restyleado como panel de ascensor: columna de "botones de
piso" (miniatura del fondo + nombre + `ocupados/cap` + candado si bloqueado),
piso actual resaltado con un marco amarillo, botones deshabilitados para
pisos bloqueados. Conserva `map.floor.<id>`, `jumpToFloor`, el caché
`FloorThumbnail` y el scroll inicial centrado. Título nuevo: `elevator.title`
("Ascensor" / "Elevator").

---

## 5. FisuJobs — tienda de contratación

### 5.1 Pantalla (`FisuJobsView`)

Estética de "portal de empleo" parodia: header con logo "FisuJobs" (cinta) y
subtítulo tipo "Conseguí laburo… para otros". Lista vertical de tarjetas
(`GameCard`), ordenada por tier DESCENDENTE entre los desbloqueados (como el
Animal Shop: el mejor arriba), y debajo la sección de bloqueados.

Cada tarjeta de tipo contratable:
- Retrato (`<char>_face` del manifest — las 43 caras ya existen), nombre,
  `produce X /s` (tapYield + pasiva, textos ya resueltos en la proyección),
  `— N contratados` (contador por tipo), tag del piso destino.
- Botón `PricePill` con el precio cotizado. Id `jobs.hire.<typeId>`.
- Estados: contratable / sin plata (botón desaturado pero tappable, como
  SpawnButtonView.swift:25-33 — nunca `.disabled`) / piso lleno ("Piso
  lleno") / gate cerrado ("Desbloqueá <piso de arriba>").

Tipos no contratables:
- **Visto pero piso bloqueado**: tarjeta gris con candado y "Se desbloquea
  con el piso <nombre>".
- **Nunca visto** (`!seenTypes.contains(id)`): silueta + "???" — sin
  espoilear nombres (criterio RF-03).

### 5.2 Economía por tipo (EconomyKit)

Nueva cotización `TowerActions.hireQuote(typeId:state:config:floorTable:tiers:costMultiplier:now:)`:

```
floor  = floorTable.floor(forTier: type.tier)
base   = hireCostMultiplier(floor) × tapYield(type.tier) × floor.incomeMultiplier
premium = pow(config.hire.tierPremium, type.tier - floor.firstTier)
cost   = base × premium × pow(hireCostGrowth(floor), purchasesOfType)
       × costMultiplier × ModifierMath.factor(.spawnCostMultiplier) × (1 − spawnDiscount)
```

- `tierPremium` es un campo nuevo de `economy.json → hire` (default inicial
  **1.8**, se calibra con `pacing-sim`). Para el **tier base de cada piso**
  `premium = 1`, así que los precios actuales (y los pins: primer Fisura 50,
  segundo 60, regla 600×/50×) **no cambian** — la curva nueva sólo agrega los
  tiers no-base, que hoy no se podían comprar.
- Con `tapYield` creciendo 2.8×/tier y premium 1.8, el salto efectivo por
  tier dentro de un piso es ~5×: comprar el tier alto directo siempre pierde
  contra comprar 2 del tier anterior y mergear (2.8×p > 2 con margen).
- `purchasesOfType` es un contador nuevo `run.hireCountsByType: [String: Int]`
  (§15). `run.hireCounts` por piso se conserva (lo usan tests y saves) pero
  deja de alimentar el exponente.
- `TowerActions.hire(quote:...)` gana la variante por tipo: mismos guards
  (floorLocked → canHire del piso del tipo → coins → slot libre), incrementa
  `hireCounts[floorId]`, `hireCountsByType[typeId]`, `units`, `markSeen`.
- `canHire` y `hireTargetFloor` NO cambian (gate de un piso pineado).
  `baseHireType` queda para el tutorial/reconciliación.
- `PacingSimulator` migra a la cotización por tipo comprando siempre el tier
  base de cada piso → su conducta y los `PacingTests` no se mueven. Se corre
  `pacing-sim` antes y después y se anota en `balance-log.md`.

### 5.3 GameState

- Proyección computada `jobRows: [JobRow]` en `GameState+Hiring.swift` nuevo
  (patrón `boostRows`): struct Equatable con typeId, displayName,
  faceKey, incomeText, hiredCount, costText, afford, estado
  (hirable/full/gated/locked/unseen), floorNameKey. Se re-evalúa contra
  `coinsText` + `boardVersion` + `effectsVersion`.
- Acción `hireCharacter(typeId:)` (reemplaza el rol de `buySpawn` para la
  tienda): resuelve la cotización por tipo, marca `ftue.spawned`, haptics
  `.purchase`, audio `.buy`, `bumpBoard()`, `scheduleSave()`, captura
  `floorFull` → `TowerNotice`.
- `spawnQuote`/`hireOffer`/`canAffordSpawn` quedan publicadas (las usan
  tests unitarios) pero sin consumidor de UI; se marca su comentario.

---

## 6. Upgrades v2

`UpgradesView` se restylea sin tocar su lógica ni proyecciones:
- Mismas 2 pestañas (personajes / permanentes ORO) con `GameTabBar` chica
  (ids `upgrades.tab.*` conservados).
- Filas → `GameCard` con retrato grande a la izquierda (como Cow Evolution:
  icono 88pt), efecto `X → Y` en color de acento, `ProgressBar` de nivel
  (`Level N/M`) y `PricePill` a la derecha.
- La fila del bug de VoiceOver (carita como elemento con nombre duplicado,
  HANDOFF §8) se arregla de paso: la carita pasa a `.accessibilityHidden(true)`.
- Header con saldo de ORO visible en la pestaña permanente (`oroText`).
- Identifiers `upgrades.character.<id>.*` y `upgrades.permanent.<id>`
  conservados.

---

## 7. Customization Shop (skins)

Pantalla nueva `CustomizationView` (id de tab `hud.skins`):

- **Selector de personaje** arriba: carrusel horizontal de caras (sólo tipos
  con `seenTypes`; los demás silueta "???"). Id `skins.character.<typeId>`.
- **Grilla de skins** del personaje elegido (base + sus skins de
  `skinOptions(forCharacterType:)`): tarjeta con preview (textura del atlas
  vía `UIArt.characterImage`), nombre y estado:
  - equipada (marco amarillo + check) → tap = nada
  - poseída → botón "Ponérsela" (`equipSkin`), id `skins.equip.<skinId>`
  - milestone bloqueada → silueta tinta + condición legible ("Llegá a
    <piso>", "Reencarná N veces") — textos resueltos en el estado, nunca
    clave interpolada
  - IAP no comprada → precio real de StoreKit (`displayPrice`) + botón de
    compra vía `StoreManager` (id `store.buy.<productId>`, mismo namespace
    que la tienda)
- Proyección computada `skinCatalogRows(forCharacterType:)` en
  `GameState+Store.swift` (extiende lo que ya existe: `skinOptions`,
  `ownsSkin`, `activeSkinID`).
- `CharacterSheetView` conserva su carrusel (mismas funciones de estado); la
  ficha y la tienda de skins no duplican lógica, sólo superficie.
- **Extensibilidad** (decisión 3): sumar una skin = entrada en `skins.json`
  (+ PNGs al atlas, + producto en `products.json`/`.storekit` si es paga).
  La pantalla se genera 100% del catálogo; cero código por skin nueva. Se
  documenta el checklist en el propio spec de skins de F7
  (`HANDOFF-F7-estado.md` ya trae el circuito de arte).

---

## 8. Tienda IAP v2

`StoreView` se restylea manteniendo `StoreManager` intacto salvo el fix:

- **Fix del hang "Loading…"** (HANDOFF §8): `loadProducts()` corre
  `Product.products(for:)` en carrera contra `Task.sleep(10 s)`; al vencer,
  `loadState = .failed` → la vista muestra `store.retry`. Además la rama
  `.loading` gana el botón de reintento tras el timeout. Test unitario del
  timeout con reloj inyectable.
- Secciones como tarjetas grandes (starter pack destacado tipo "offer",
  remove-ads como banner ancho, packs de monedas/ORO como filas con icono,
  skins con preview). Ids `store.buy.<id>`, `store.reward.<id>`,
  `store.restore`, `store.retry`, `store.unavailable` conservados.
- El **bloque de settings se va** de StoreView (StoreView.swift:56-66) — vive
  sólo en Settings (§12.4). Restore queda visible sin scroll profundo.
- El estado "tienda vacía" (sin App Store Connect) debe verse digno: mensaje
  + retry (ya existe la rama, se restylea).
- `meta.removedAds` sigue sin consumidor (decisión de ads abierta,
  `Docs/ads-integration.md`); la tienda no promete más de lo que hay: el
  copy de remove-ads se limita a los rewarded actuales.

---

## 9. Regalos v2 (`GiftsView`, reemplaza BonusView)

Tres secciones en un solo panel:

1. **Daily**: calendario horizontal de 7 días (día actual resaltado,
   pasados con check, día 7 con cofre). Proyección computada nueva
   `dailyCalendar: [DailyDayRow]` (cycleDay + coinsFactor de
   `content.dailyRewards`). El claim SIGUE siendo automático (bootstrap +
   foreground) — el calendario es informativo; así no se introduce la carrera
   documentada del doble camino de claim. El popup `DailyRewardView` se
   restylea.
2. **Boosts**: filas actuales de `boostRows` con arte `ui_boost_*`, cooldown
   en aro + texto, candado con nombre del piso si `!isUnlocked`. SIEMPRE vía
   `displayNameKey(buildVariant:)`/`flavorTextKey(buildVariant:)` (textos
   review-safe). Ids `bonus.activate/cooldown/locked.<id>` conservados.
3. **Videos**: filas de `rewardRows` con botón "play" (`ads.watch.<id>`,
   `ads.cooldown.<id>` conservados) y el premio explícito en el copy (hoy la
   fila no dice qué da: se agrega `rewardText` a la proyección, resuelto en
   el estado).

Timer 1 Hz único de la vista (patrón actual). El chip del HUD no cambia.

---

## 10. Menú (`MenuView`)

Panel estilo "cuaderno" con grilla de tarjetas grandes (como el MENU de Cow
Evolution): **Organigrama · Stats · Logros · Ajustes** (2×2). Ids
`menu.card.orgchart/stats/achievements/settings`.

### 10.1 Organigrama (`OrgChartView`)

- Arriba de todo: tarjeta del jugador ("El Jefe" — vos), con multiplicador
  global y nivel de reencarnación.
- Debajo, la cadena de evolución agrupada por piso (de Dios a callejón o
  invertido — se elige descendente, jefe arriba = tiers altos arriba):
  por cada tipo VISTO una tarjeta con retrato + nombre + `CountBadge xN`
  donde `N = run.units[typeId] ?? 0`; con `N == 0` la tarjeta va gris con
  `x0` (desbloqueado pero no contratado). Tipos nunca vistos: silueta "???".
  Conectores verticales dibujados entre tiers consecutivos (línea ink).
- Proyección computada `orgChartRows: [OrgChartRow]` en
  `GameState+Stats.swift` (typeId, faceKey, name, count, tier, floorId,
  seen). Datos: `content.tiers.concreteTypes` + `run.units` + `seenTypes` —
  todo ya disponible.
- Ids: `orgchart.node.<typeId>` (elemento de estado con value `xN`).

### 10.2 Stats (`StatsView`)

Lista de `GameCard` por grupos. **Fuentes existentes**: lifetimeEarnings,
oro/oroEarnedLifetime, prestigeLevel, maxFloorOrdinalEver (nombre vía
`TowerNaming`), maxTierReached, unitCount, seenTypes/43, skins/45,
specials/10, sharesCompleted, pisos desbloqueados/10, income/s.
**Contadores nuevos** (§13): merges totales (histórico), contrataciones
totales (histórico), taps totales, videos vistos, boosts activados.
Aclaración de semántica: el "N contratados" de FisuJobs es el contador **de
la run** (`run.hireCountsByType`, el mismo que mueve el precio); Stats
muestra los **históricos** de `meta.stats`, que sobreviven a reencarnar.
Proyección computada `statsSnapshot: StatsSnapshot` (Equatable, textos ya
formateados con `CoinFormatter`). Ids `stats.row.<clave>` como elementos de
estado.

### 10.3 Logros (`AchievementsView`)

**Catálogo data-driven nuevo**: `Resources/Config/achievements.json` +
mirror `AchievementsConfig` en ContentConfigs + campo en `GameContent` +
validación en `GameContentLoader` (ids únicos, triggers conocidos, rewards
bien formadas, floorIds existentes).

Schema por entrada:
```json
{ "id": "ach_merges_100", "titleKey": "ach.merges_100.title",
  "descKey": "ach.merges_100.desc", "icon": "trophy_silver",
  "trigger": { "type": "totalMerges", "value": 100 },
  "reward": { "kind": "coins", "factor": 12.0 } }
```
- `trigger.type` ∈ { floorUnlocked(floorId), tierReached, totalMerges,
  totalHires, totalTaps, prestigeLevel, skinsOwned, skinsAll, specialsOwned,
  videosWatched, boostsActivated, lifetimeEarnings, seenAllTypes, dailyDay7,
  sharesCompleted }.
- `reward.kind` ∈ { coins (factor × `passiveUnlockCost(maxTierReached)` —
  escala con el progreso, como los packs), oro (monto fijo), freeBoost
  (boostId, mismo mecanismo del premio del Médico) }.

**Catálogo inicial (36 logros)** — fáciles y difíciles, con los momentos
clave pedidos:
- Pisos (9): desbloquear urban → god_realm, coins crecientes; god_realm da ORO.
- Merges (4): 1 / 100 / 1.000 / 10.000.
- Contrataciones (3): 10 / 100 / 1.000 ("los 1000 personajes").
- Tiers (3): elegir carrera (T11) / T24 / T37 (Dios).
- Reencarnación (3): 1 / 3 / 8.
- Skins (3): 5 / 20 / todas (45) — "todas las skins" da ORO grande.
- Specials (2): 1 / 10.
- Videos (2): mirar 1 ("Mirar un video") / 20.
- Boosts (2): 1 / 50 activaciones.
- Taps (2): 1.000 / 100.000.
- Riqueza (3): 1 M / 1 B / 1 Q de lifetime.
- Descubrimiento (1): ver los 43 tipos.
- Daily (1): completar el ciclo de 7 días.
- Share (1): compartir 1 vez.

**Motor** (`AchievementEngine` en capa app, patrón ContentSystems):
`evaluate(state:content:) -> [String]` devuelve los ids nuevos comparando
triggers contra los contadores; GameState lo llama en los mismos puntos que
`awardEligibleMilestoneSkins()` + tras hire/video/boost/share, y en
bootstrap. Desbloqueo → `meta.unlockedAchievements.insert(id)` + toast/banner
(reusa el patrón de `TowerNoticeView`) + audio `.reward`.
**El reclamo es manual en la pantalla** (botón "Reclamar" por logro
desbloqueado y no reclamado → acredita la reward, `meta.claimedAchievements`),
para que la pantalla tenga gameplay. Ids: `ach.claim.<id>`, filas
`ach.row.<id>` con value `locked|unlocked|claimed`.
- Game Center: el subsistema actual (5 achievements de `gamecenter.json`)
  queda como está, apagado por flag; los 5 ids se mapean 1:1 a logros del
  catálogo nuevo para reportar cuando se encienda.
- La pantalla funciona 100% offline/local: no consulta GameKit.

### 10.4 Ajustes (`SettingsView`, reemplaza ConfigView)

Secciones (todas localizadas + con identifier, cosa que ConfigView hoy no
tiene):
1. **Idioma**: Sistema / Español / English. Escribe `AppleLanguages` en
   UserDefaults y muestra alert "Reiniciá el juego para aplicar" (camino
   estándar; con es+en el selector nativo per-app de iOS Settings también
   funciona). Id `settings.language`.
2. **Audio**: sliders música y SFX (bindings existentes de `AudioManager`),
   toggle hápticos (`HapticsManager`). Ids `settings.music/sfx/haptics`.
3. **Partículas**: toggle nuevo `settings.particlesEnabled` (AppStorage,
   default true); `ParticlePool` lo consulta antes de emitir (y el juego con
   partículas apagadas sigue idéntico en lógica).
4. **Notificaciones**: toggle que pide permiso (`NotificationsManager` nuevo,
   `@Observable @MainActor`, `UNUserNotificationCenter`); programa 1
   recordatorio local diario ("tus fisuras te extrañan") y se cancela al
   apagar. Id `settings.notifications`.
5. **Compras**: botón "Restaurar compras" (`StoreManager.restore`,
   id `settings.restore`).
6. **Legales**: Política de privacidad y Términos de servicio como vistas
   in-app (los .md de `Distribution/site/` se empaquetan como recurso;
   **se escribe `Distribution/site/terms.md` es+en**, hoy no existe). Ids
   `settings.privacy`, `settings.terms`. Cuando exista URL pública, pasan a
   `Link`.
7. **Acerca de**: versión, créditos.

La `Section("settings.title")` de StoreView se elimina en el mismo commit.

---

## 11. Espejado y animaciones de personajes

### 11.1 Facing (espejado horizontal)

- API nueva `CharacterNode.setFacing(left:)` que escribe **`sprite.xScale`**
  (CharacterNode.swift:17), NUNCA `node.xScale` (los `SKAction.scale(to:)`
  del tap bounce/pop/ascenso lo pisarían — riesgo verificado). Sombra y
  labels no se espejan.
- **Rumbo**: dentro de `startWander` (BoardScene.swift:1536), cada paso
  antepone al `.move` un `.run { setFacing(dx < 0) }` — el personaje mira
  hacia donde camina. Costo cero.
- **Flip periódico**: `repeatForever` con clave `"facing"`, período 5–10 s
  sembrado por el hash de `cellIndex` (mismo de BoardScene.swift:1540) para
  desincronizar la multitud. Se arranca en `renderPlacements` junto a
  `startWander` y NO comparte ciclo de vida con `"wander"` (sobrevive a los
  congelamientos de candidato/tutorial).
- Reduce Motion: los dos mecanismos viven detrás del mismo guard que el
  wander (un flip es movimiento). Verificación en los DOS sentidos (trampa 9
  del HANDOFF: capturas con y sin Reduce Motion deben diferir).
- El pool resetea `xScale` en `obtain()` — el facing se re-arranca en
  `renderPlacements`, así que no hay estado que persistir en
  `RenderedUnit`.

### 11.2 Micro-animaciones de pulido (SwiftUI)

Todas condicionadas a `accessibilityReduceMotion`:
- Tab bar: bounce del icono al tocar (spring 0.3) + badge pop.
- Contador de monedas: transición `.numericText()` (rolling digits).
- Tarjetas: aparición escalonada al abrir panel (opacity+offset, 30 ms de
  stagger, tope 8 filas).
- Botones de precio: shake horizontal breve al intentar comprar sin saldo.
- Logro desbloqueado: banner que baja del HUD con trofeo (patrón
  TowerNotice).
- Ascensor: la transición de piso ya existe (vuelo de cámara); el panel
  resalta el destino con un pulso.
- Prohibido: `repeatForever` siempre encendidos (mantienen vivo el display
  link — precedente SpawnButtonView.swift:36-46). Sólo pulsos condicionados.

---

## 12. Iconos — vectorial ahora, batch después

### 12.1 Inventario de iconos nuevos

Tab bar (6): `ui_tab_jobs`* (usa `homeless_face` mientras tanto),
`ui_tab_upgrades`, `ui_tab_skins`, `ui_tab_gifts`, `ui_tab_shop`,
`ui_tab_menu`. HUD (2): `ui_coin_plus`, `ui_elevator`. Menú (4):
`ui_menu_orgchart`, `ui_menu_stats`, `ui_menu_trophy`, `ui_menu_settings`.
Logros (3): `ui_trophy_bronze`, `ui_trophy_silver`, `ui_trophy_gold`.
Regalos (1): `ui_daily_calendar`. Total: **16**.

### 12.2 Camino vectorial (ahora)

`GameIcons.swift`: cada icono es un `View` SwiftUI dibujado (Path/formas +
outline ink 2pt + fills de paleta), consumido vía `IconButton`/`GameIcon`
con la firma `GameIcon(artKey: "ui_tab_gifts") { VectorGiftIcon() }` — si el
manifest tiene la clave usa el PNG, si no dibuja el vector. **Integrar el
batch después = cero código.**

### 12.3 Cola de Gemini (después, la corre el dueño)

- Un `.md` por icono en `Tools/asset-pipeline/prompts/gemini_pro/` numerado
  desde `max(usados)+1`, sin `referencia`, `- **estado**: pendiente`, y
  entrada gemela `{"assetKey", "category": "ui", "prompt"}` en
  `prompts/prompts.json` (patrón `gen_skin_prompts.py`).
- Prompts con el estilo maestro flat (paleta lockeada, outline grueso, sin
  gradientes, "Simple flat vector game icon, centered, plain white
  background") + descripción específica por icono.
- ⚠️ Aviso al dueño en el handoff: iconos con fill interior plano (calendario,
  trofeos) pueden salir con el centro transparente por rembg (pasó con
  `ui_toggle_*`): verificar el % de píxeles opacos post-proceso; si falla,
  se quedan los vectoriales, que para eso son de calidad.
- Comandos (desde Terminal.app): `launch_gemini_chrome.py` → runner con
  `--process`. `process_dropbox.py` exporta a 192/256 px (prefijo no-panel)
  y agrega `manifest.ui[key]`, sin `xcodegen` (el atlas es folder reference).

---

## 13. Persistencia — contadores, logros y compatibilidad

**Sin bump de versión** (queda v4): todos los campos nuevos entran con
decodificador manual + `decodeIfPresent ?? default`, patrón `MetaState`
(PlayerState.swift:235-257).

1. `RunState` gana `init(from decoder:)` **manual** con `decodeIfPresent`
   para TODOS sus campos opcionales-por-default. Esto además arregla el bug
   latente verificado: el default de `seenTypes` NO protege el decode (el
   Codable sintetizado ignora defaults) — hoy un save v4 sin esa clave se
   pierde. Campo nuevo: `hireCountsByType: [String: Int] = [:]`.
   `RunState.fresh` lo resetea (muere al reencarnar: el precio por tipo
   arranca de cero en cada run, coherente con `hireCounts`).
2. `MetaStats` gana `init(from decoder:)` manual y los campos:
   `totalMergesEver`, `totalHiresEver`, `totalTapsEver`,
   `videosWatchedEver`, `boostsActivatedEver` (todos `Int = 0`).
3. `MetaState` suma `unlockedAchievements: Set<String>` y
   `claimedAchievements: Set<String>` (decodeIfPresent ?? []).
4. **Puntos de emisión** (los choke points mapeados):
   - merges → `TowerActions.applyMerge` (TowerActions.swift:270, junto a
     `maxTierReached`) — cubre drop, carrera y video. El auto-merge del
     reconciliador NO cuenta (no es acción del jugador).
   - hires → `TowerActions.hire` (:204) — `totalHiresEver` +
     `hireCountsByType`.
   - taps → `GameState.registerTap` (capa app; NO en EconomyKit para no
     ensuciar `applyTap` puro).
   - videos → `applyRewardedReward` (GameState+Bonus.swift:36), boosts →
     `activateBoost`.
5. `SaveConflictResolver.resolve` gana reglas explícitas: contadores de
   stats por `max`, `unlockedAchievements`/`claimedAchievements` por unión
   (igual que `milestoneSkins`).
6. Tests: decode de un JSON v4 real SIN las claves nuevas (round-trip),
   pins de incremento por camino (drop/carrera/video), reglas de merge de
   conflictos, y el fixture de SaveMigratorTests no cambia (v4 sigue siendo
   la versión).

---

## 14. Localización

- Decenas de claves nuevas con prefijos: `jobs.*`, `skins.*`, `gifts.*`,
  `menu.*`, `orgchart.*`, `stats.*`, `ach.*` (título+desc por logro),
  `settings.*`, `elevator.*`, `hud.income.label`, `terms.*`/`privacy.*`.
  **Todas es+en, editadas a mano en Xcode, en el mismo commit que su vista.**
- Claves data-driven (por id de logro/personaje/skin): SIEMPRE
  `String(localized: String.LocalizationValue(key))` en una función del
  estado (patrón `upgradeFlavorText`) o `GameState.localized(_:)` para las
  que vienen de JSON; el test ejercita ESA función. Números en `%@` →
  `String(x)`.
- Se arregla la clave muerta del pill de torre (§3).
- ConfigView muere → sus 3 strings hardcodeados desaparecen con ella.

---

## 15. Tutorial / FTUE

- El paso "contratá" apunta al tab FisuJobs: el ancla `.hire` se muda al
  botón del tab. El flujo: spotlight sobre el tab → el jugador lo toca → se
  abre FisuJobs (sheet por encima del overlay) → contrata al primer Fisura
  (50, pineado) → `ftue.spawned` se marca en `hireCharacter` → al cerrar la
  hoja el tutorial avanza al paso de merge.
- El paso de "mejoras" y el de "mapa" se re-apuntan a los nuevos botones
  (tab `hud.upgrades`, botón ascensor `hud.map`) — mismos targets del enum,
  nuevas posiciones; `TutorialOverlay.steps` se reescribe con el copy nuevo.
- `--uitest-skip-tutorial` y el reset de banderas no cambian.

---

## 16. Accesibilidad e identifiers (contrato de tests)

**Se conservan** (pineados por la suite): `hud.store`, `hud.upgrades`,
`hud.bonus`, `hud.settings`, `hud.coins`, `hud.map`, `hud.prestige`,
`hud.prestige.multiplier`, `hud.bonus.chip`, `tower.pill`,
`tower.arrow.up/down`, `board.units`, `tower.notice`, `sheet.close`,
`map.floor.<id>`, `upgrades.*`, `store.*`, `bonus.*`, `ads.*`,
`career.option.<id>`, `character.*`, `prestige.*`, `skin.award.*`,
`tutorial.*`, `share.button`.

**Nuevos**: `hud.coins.plus`, `hud.income`, `hud.hire`, `hud.skins`,
`jobs.hire.<typeId>`, `jobs.row.<typeId>`, `skins.character.<typeId>`,
`skins.equip.<skinId>`, `skins.row.<skinId>`, `menu.card.*`,
`orgchart.node.<typeId>`, `stats.row.<key>`, `ach.row.<id>`,
`ach.claim.<id>`, `settings.language/music/sfx/haptics/particles/notifications/restore/privacy/terms`,
`gifts.daily.day<i>`.

**Muere**: `hud.spawn` (con SpawnButtonView).

Reglas: identifier nunca en contenedores; capas decorativas
`.allowsHitTesting(false)`; elementos de estado con el trío
`.accessibilityElement(children:.ignore)` + id + value.

---

## 17. Tests y verificación

- **Unitarios nuevos**: curva `hireQuote(typeId:)` (premium por tier, growth
  por tipo, pins del tier base = precios actuales), `jobRows` (estados),
  `AchievementEngine` (cada trigger type), contadores (3 caminos de merge),
  decode v4 sin claves nuevas, `SaveConflictResolver` con stats,
  `dailyCalendar`, `statsSnapshot`, timeout de StoreManager, textos
  data-driven (anti-trampa 5, patrón UpgradeRowTextTests).
- **UI tests**: se reescriben `EconomyLoopUITests` (hire vía FisuJobs),
  `TutorialUITests` (los pasos re-apuntados; hoy usa `hud.spawn` en
  :65/:81/:128) y `StoreUITests.scrollUntilVisible` si cambia el layout;
  `BoardGestureUITests` y `AscentRenderingUITests` sólo cambian si usaban
  `hud.spawn` para sembrar unidades (pasan a `--uitest-coins` + FisuJobs o a
  fixtures debug); nuevos smoke por
  pantalla (abrir cada tab, asertar un id interno, cerrar con
  `sheet.close`), captura ANTES de asserts. Fixtures nuevos:
  `--uitest-stats` (siembra contadores) y `--uitest-achievements`
  (desbloquea 3 logros).
- **Pins de contenido**: `GameContentValidationTests` gana el pin de
  `tierPremium` y la validación de `achievements.json`.
- **Escena**: `CrowdDepthTests` tras ajustar `bottomInset`; test unitario del
  facing (`action(forKey: "facing")` existe tras `renderPlacements`, xScale
  del sprite cambia, y con Reduce Motion no se instala) — patrón
  BoardGestureTests.
- **Comandos** (§6 del HANDOFF): EconomyKit `swift test` (150 hoy), app+UI
  con `-skip-testing:FisuEvolutionUITests/AscentRenderingUITests
  -parallel-testing-enabled NO`, pipeline 27 (1 rojo conocido por Chrome
  ausente). Cada frente con simulador propio por UDID, apagado al terminar.
- **Verificación visual obligatoria**: capturas por pantalla en simulador
  (las trampas 2 y 9 enseñan que los tests pueden pasar con la UI rota);
  Reduce Motion en los dos sentidos para el facing.

---

## 18. Fuera de alcance (explícito)

- Encender Game Center / dar de alta productos (gates humanos F6/RF-02c).
- AdMob real (`useRealAds` sigue muerto; decisión en `ads-integration.md`).
- Audio nuevo (RF-14 sigue gateado por criterio estético).
- Dark mode.
- Skins pagas nuevas (sólo queda el catálogo preparado).
- Cambiar el gate de contratación, los precios del tier base, o cualquier
  decisión de §5 del HANDOFF.

## 19. Orden de implementación sugerido (para el plan)

1. **F1 — Fundaciones**: design system v2 + persistencia (decoders manuales,
   contadores, choke points) + EconomyKit `hireQuote(typeId:)` + pacing-sim.
2. **F2 — Cáscara**: HUD superior + BottomMenuBar + navegación (enum de
   pantalla) + ajuste de `bottomInset` + tutorial re-apuntado.
3. **F3 — Pantallas** (paralelizable): FisuJobs · Upgrades v2 · Customization
   · Tienda v2 (+fix Loading) · Regalos v2 · Menú (organigrama/stats/logros/
   settings + achievements.json + terms.md).
4. **F4 — Vida**: facing + micro-animaciones + iconos vectoriales + cola de
   prompts.
5. **F5 — Verificación**: suites completas, capturas, balance-log, HANDOFF.
