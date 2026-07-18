# HOBO EVOLUTION — Agent Build Bible

**Versión ejecutable del design doc, pensada para construirse 100% con Claude (Fable) + subagentes vía Claude Code.**

Este documento NO cambia la funcionalidad definida en el design doc original. Le agrega: data model, economía numérica, arquitectura técnica, identidad cultural argentina, pipeline de assets gratuito y plan por fases. Todo lo marcado como `[TUNEABLE]` o `[DEFAULT — ajustar]` es una propuesta de arranque, no una decisión cerrada.

---

## 0. Cómo se construye esto (Claude Code + subagentes)

La app se arma en fases verificables. El arte va **al final**: se construye todo con placeholders programáticos y se enchufa el arte real cambiando rutas en un manifest. El código nunca toca un sprite directo, lee `assets_manifest.json`.

### Subagentes sugeridos (roles)

| Subagente | Responsabilidad |
|---|---|
| **Architect** | Setup del proyecto Xcode/SwiftPM, data model, schemas JSON, `assets_manifest.json`, CoreData stack |
| **Gameplay** | SpriteKit board, drag-and-drop, merge/tap/pasivo, motor de economía, offline progression |
| **UI** | SwiftUI: menús, HUD, popups, animaciones — respetando paleta y estilo |
| **Content** | Llena los JSON de tiers, economía y la biblia cultural argentina |
| **AssetPipeline** | ComfyUI/free-tier + hero refs + VLM judge + vectorización + atlas + wiring al manifest (corre en F3+) |
| **QA** | Unit tests, `xcodebuild`, chequeo de compilación y balance |

Cada subagente arranca de este bible como fuente de verdad. Recomendado: un `CLAUDE.md` por subagente que apunte a la sección relevante de este doc.

### Regla de oro

> **Arte desacoplado del código.** F0–F2 se juegan enteras con formas de colores + SF Symbols + labels de tier. El arte real entra en F3 cambiando solo el manifest. Esto permite tener un juego jugable y balanceado antes de generar una sola imagen.

---

## 1. Identidad cultural y tono (la biblia argentina)

**Tono:** adulto, medio bizarro, gracioso, meme-culture argentino. La sátira ES el marketing. Objetivo: que cada evolución sea screenshot-eable y compartible.

### Personajes por tier (guiño cultural)

**Fase Tierra**

| Tier | Personaje | Guiño AR |
|---|---|---|
| 1 | **El Fisura** | Homeless con actitud: ojos girados, botella, mirada perdida, medio zarpado pero entrañable |
| 2 | **Cartonero** | Carrito típico repleto de cartón, chaleco reflectante, el clásico de la city |
| 3 | **Personal de Kiosco** | Detrás del mostrador, atado de puchos, el gato del kiosco durmiendo al lado |
| 4 | **Repartidor** | Mochila de delivery (marca parodiada, ver §nota legal), casco, bici/moto destartalada |
| 5 | **Chofer de App** | Auto con la botellita de agua y el chupetín de cortesía (el gag clásico) |
| 6 | **Empleado de Fast Food** | "McRonald's" (parodia), gorrito, cara de resignación |
| 7 | **Oficinista** | Camisa, ojeras, mate infaltable en el escritorio |
| 8 | **Administrativo** | Pilas de papeles, sello en la mano, ventilador de escritorio |
| 9 | **Recién Recibido** | **"Egresado de la UBA"** — título bajo el brazo, orgullo + bolsillo vacío. Al llegar acá el juego te hace **elegir carrera** con mención explícita a la UBA |
| 10 | **Senior** | El mismo pero con canas, más facha, notebook mejor |
| 11 | **Director** | Traje, café en vaso de cartón caro |
| 12 | **Fundador de Startup** | Hoodie, "disrupción", pitch deck en la mano |
| 13 | **Dueño de PYME** | Camioneta, "pyme sufrida" |
| 14 | **Emprendedor** | Curso de coaching ontológico, remera motivacional |
| 15 | **CEO** | Oficina con ventanal |
| 16 | **Millonario** | Reloj caro, actitud |
| 17 | **Multimillonario** | Yate de fondo |
| 18 | **Rey del Ladrillo** | Real estate — "el ladrillo", maqueta de torre |
| 19 | **Magnate Petrolero** | Sombrero, barril |
| 20 | **Space Billionaire** | Cohete estilo parodia |
| 21 | **Trillonario** | Nada tiene sentido ya |

**Elección de carrera (Tier 9):** el popup dice algo tipo *"Te recibiste en la UBA. ¿Ahora qué?"* con las 4 variantes:
- **Programador Jr.** → notebook con stickers y dark mode, muchos monitores
- **Arquitecto Jr.** → rollos de planos, maqueta, escalímetro
- **Médico Jr.** → guardapolvo, ojeras de guardia infinita
- **Abogado Jr.** → Código bajo el brazo, corbata

**Fase Cósmica (22–30):** se mantiene tal cual el design doc (Owns The Moon → God), con winks argentinos en los textos de flavor.

### Boosts (temática mate / café / sustancias)

**Versión "review-safe" (recomendada para pasar Apple):**

| Boost | Efecto | [TUNEABLE] |
|---|---|---|
| **Unos Mates** | +spawn rate temporal | +30% x 60s |
| **Café Cargado** | +tap yield temporal | x2 tap x 45s |
| **Fernet con Coca** | multiplicador social nocturno | x3 income x 90s |
| **Milanesa** | mejora offline earnings | +offline efficiency permanente |
| **Asado del Domingo** | bonus periódico grande | cada 6h, cofre gordo |
| **Modo Turbo** | el boost "zarpado" abstraído — clarísimamente absurdo | x5 income x 30s, con animación bizarra |

> **Nota de review:** mate y café pasan sin problema. Para el humor de "drogas", `Modo Turbo` lo deja satírico y abstracto (nada realista, nada aspiracional) → shipea. Si querés el **full send** con referencias más explícitas, es tu llamada, pero sabé que Apple puede rechazar apps que se lean como apología de drogas ilegales. Recomendación: full send para difusión en redes/TikTok, versión safe en la build de la store.

### Special characters (rare drops, argentinizados)

Base del design doc + capa AR. **Regla: arquetipos, no personas reales con nombre** (nada de caricaturizar políticos identificables por nombre).

- Demonio de ARCA (ex-AFIP) — el "IRS Demon" local
- El Contador de Dios
- Crypto Bro (cripto es enorme en AR)
- El del Arbolito (cueva de cambio)
- Coach Ontológico
- El Influencer
- Zombie CEO / Lizard Billionaire / Alien Investor / Bug de la Simulación (del doc original)

### Eventos (argentinizados, mantienen la mecánica del doc)

| Evento | Efecto (= evento del doc) |
|---|---|
| **Plan Platita** | Income x5 (= Lottery Winner) |
| **Startup Comprada** | Evolución instantánea (= Startup Acquired) |
| **Devaluación** | Income -50% (= Crypto Crash) |
| **Blanqueo de Capitales** | Personaje high-tier gratis (= Inheritance) |
| **Se cayó Mercado Pago** | Slowdown temporal (= Tax Audit) |
| **Inversión Alienígena** | Income x10 |
| **Corralito** *(opcional, flavor)* | Coins congelados X segundos |
| **Aguinaldo** *(opcional)* | Bonus semestral |

### Nota legal (marcas)

PedidosYa, Uber, McDonald's, etc. son trademarks → riesgo en la store. Parodiá: mochila de delivery genérica, "McRonald's", "app de viajes". Mantenés el guiño, evitás el problema.

---

## 2. Data model

Todo data-driven. Los tiers y la economía viven en JSON bundleado, no hardcodeados.

### 2.1 `CharacterType` (definición, en `tiers.json`)

```json
{
  "id": "homeless",
  "tier": 1,
  "phase": "earth",
  "displayName": "El Fisura",
  "spritePlaceholder": "sf:person.fill",
  "spriteAssetKey": null,
  "tapYield": 1,
  "passiveYieldPerInstance": 0.3,
  "passiveUnlockCost": 100,
  "spawnBaseCost": 15,
  "spawnCostGrowth": 1.15,
  "mergesInto": "cartonero",
  "isChoiceNode": false,
  "choiceOptions": null
}
```

Nodo de elección (Tier 9):
```json
{
  "id": "junior",
  "tier": 9,
  "isChoiceNode": true,
  "choiceOptions": ["junior_programmer", "junior_architect", "junior_doctor", "junior_lawyer"]
}
```

### 2.2 `PlayerState` (CoreData + snapshot JSON)

```json
{
  "coins": 0,
  "board": [ { "cellIndex": 0, "typeId": "homeless" } ],
  "passiveUnlocked": { "homeless": false, "cartonero": false },
  "chosenCareerPath": null,
  "globalMultiplier": 1.0,
  "soulPoints": 0,
  "prestigeLevel": 0,
  "spawnPurchases": { "homeless": 0 },
  "upgrades": { "offlineEfficiency": 0.5, "tapMultiplier": 1.0, "critChance": 0.0 },
  "lastSeenTimestamp": 1700000000,
  "unlockedBackgrounds": ["alley"],
  "ownedSpecials": [],
  "removedAds": false
}
```

### 2.3 Reglas del core loop (EXACTAS, según lo definido)

1. **Tap:** tocar un personaje da `tapYield × tapMultiplier × globalMultiplier` coins. Siempre disponible desde el inicio.
2. **Merge:** arrastrar un personaje sobre otro **idéntico** (mismo `typeId`) → se fusionan en 1 del `mergesInto`. Merge-2 clásico.
3. **Pasivo (se compra):** por default un tipo NO genera pasivo. Comprando el `passiveUnlockCost` de ese tipo, **todos los personajes de ese tipo en el board** empiezan a generar `passiveYieldPerInstance × count × globalMultiplier` por segundo. Se compra por tipo, independiente. Ej: comprás "El Fisura pasivo" → todos los fisuras rinden; el cartonero sigue siendo solo-tap hasta que compres el suyo.
4. **Spawn:** comprar un nuevo personaje base (Tier 1) cuesta `spawnBaseCost × spawnCostGrowth^(spawnPurchases)`. Sube con cada compra (curva idle estándar).
5. **Evolución:** merges sucesivos suben la escalera de tiers hasta God (Tier 30).
6. **Reincarnation:** al llegar a God → reset, ganás Soul Points y multiplicadores permanentes (§5).

### 2.4 Tick de income (pseudocódigo)

```
passivePerSecond = 0
for type in distinctTypesOnBoard:
    if playerState.passiveUnlocked[type]:
        count = board.count(type)
        passivePerSecond += type.passiveYieldPerInstance * count
passivePerSecond *= globalMultiplier
coins += passivePerSecond * deltaTime
```

---

## 3. Economía [TUNEABLE — arranque, ajustar con playtesting]

Curva exponencial estándar de merge-idle.

```json
{
  "baseTapYieldTier1": 1,
  "yieldGrowthPerTier": 3.8,
  "passiveRatio": 0.3,
  "passiveUnlockCostMultiplier": 100,
  "spawnBaseCost": 15,
  "spawnCostGrowth": 1.15,
  "critChanceBase": 0.0,
  "critMultiplier": 5.0,
  "offlineEfficiencyBase": 0.5,
  "offlineCapHours": 8,
  "prestige": {
    "soulPointsFormula": "floor((lifetimeEarnings / 1e6) ^ 0.5)",
    "globalMultiplierPerSoulPoint": 0.02
  }
}
```

Reglas derivadas:
- `tapYield(tier) = baseTapYieldTier1 × yieldGrowthPerTier^(tier-1)`
- `passiveYieldPerInstance(tier) = tapYield(tier) × passiveRatio`
- `passiveUnlockCost(tier) = tapYield(tier) × passiveUnlockCostMultiplier`
- **Offline:** `min(offlineSeconds, offlineCapHours×3600) × passivePerSecond × offlineEfficiency`
- **Prestige:** `globalMultiplier = 1 + soulPoints × globalMultiplierPerSoulPoint`

> El Content agent genera la tabla completa de 30 tiers a partir de estas fórmulas. No inventar números sueltos: todo sale de acá.

---

## 4. Arquitectura técnica

Stack confirmado del doc: SwiftUI + SpriteKit + CoreData + Game Center + CloudKit + StoreKit 2 + Haptics + offline + iCloud. 60 FPS. iPhone (iPad post-MVP).

### 4.1 División de responsabilidades

- **SwiftUI:** menú principal, HUD (coins, botones), popups (store, unlock, reincarnation, daily, settings, event), share cards.
- **SpriteKit (`SKScene` vía `SpriteView`):** el board de merge. Drag-and-drop, spawn, partículas, evolución flash. **El board lo maneja SpriteKit entero** para no re-renderizar SwiftUI en cada frame.
- **Puente:** el estado vive en un `@Observable GameState` (o `ObservableObject`); SpriteKit lee/escribe ahí, SwiftUI observa para el HUD.

### 4.2 Performance (60 FPS)

- Sprite pooling (reusar nodos, no crear/destruir).
- Texture atlases (`SKTextureAtlas`) — un atlas por fase.
- Partículas con `SKEmitterNode` pooled.
- Nada de layout SwiftUI atado al loop del board.

### 4.3 Persistencia

- **CoreData** para el save principal + snapshot JSON de respaldo.
- **CloudKit** detrás de feature flag → **deferido** hasta cuenta paga.
- Offline progression en `applicationDidBecomeActive`: calcular elapsed, aplicar pasivo.

### 4.4 Monetización

- **StoreKit 2** con un archivo **`.storekit` local** para testear TODO sin cuenta paga.
- Rewarded ads: **stubear** en dev (un botón que simula la recompensa) hasta integrar el SDK real (AdMob) más adelante. Efectos de ads del doc: doblar earnings / spawn rare / acelerar evolución / multiplicador temporal.
- Premium purchase: remove ads + cosméticos (golden/galaxy/god skins).

### 4.5 Game Center

- Behind feature flag → **deferido** hasta cuenta paga. Leaderboards (más rico, más tier alcanzado) y achievements se codean pero se activan al final.

### 4.6 Qué necesita la cuenta paga ($99) y cuándo

**No la necesitás hasta F6.** Con Apple ID gratis:
- ✅ Simulador (todo el desarrollo)
- ✅ Device propio (firma personal, re-firmar cada 7 días)
- ✅ StoreKit testing local
- ❌ TestFlight, submission, Game Center prod, CloudKit prod, push → requieren los $99/año

---

## 5. Reincarnation / Prestige

Al llegar a God (Tier 30):
- Reset de progreso (board, coins).
- Ganás **Soul Points** (fórmula en §3).
- Multiplicadores permanentes globales.
- Desbloqueás: spawn rate más rápido, backgrounds nuevos, skins exclusivas, special characters secretos.

Loop de retención: cada reincarnation hace el próximo run más rápido y absurdo.

---

## 6. Sistema de assets (pipeline gratuito, corre en F3+)

### 6.1 Estrategia

Arte al final, por tandas, gratis. Consistencia garantizada por **hero references** que viajan a cualquier tool.

1. **Style bible a mano:** vos generás y aprobás 2–4 hero images que fijan: grosor de outline, ratio cabeza/cuerpo (≈55–60%), paleta exacta, luz única top-left, shading flat (sin gradientes).
2. **Generación:**
   - **Primario: ComfyUI local** (gratis ilimitado). Entrenás un style LoRA sobre las semillas + IP-Adapter. API-able para el AssetPipeline agent.
   - **Plan B: Leonardo AI** (créditos gratis diarios) u otras apps free, **siempre metiendo las hero refs** como character/style reference para no perder consistencia entre tools.
3. **QA con VLM judge:** cada asset → Gemini 2.5 Flash lo puntúa contra el bible (¿outline consistente? ¿paleta en rango? ¿proporción? ¿fondo limpio?). Debajo del umbral → auto-regenera.
4. **Curaduría:** FiftyOne para revisar la grilla completa y descartar outliers.
5. **Post-proceso:** background removal → vectorización opcional (raster→SVG) → empaquetado en `SKTextureAtlas`. Sombras en engine, no bakeadas.
6. **Wiring:** `assets_manifest.json` conecta arte ↔ código.

### 6.2 Formato [DEFAULT — ajustar]

- Raster PNG **@1x/@2x/@3x** con background transparente. (Alternativa: SVG vectorizado si querés escala infinita y menos peso — cambia el pipeline de export.)

### 6.3 Prompt maestro (fase de semillas / tools sin training)

```
Official "Hobo Evolution" game asset. 2D flat vector cartoon, single art
direction. Big-head/tiny-body proportions (head ≈ 55–60% of figure). Uniform
thick black outline, constant weight. Flat colors, minimal cel-shading, NO
gradients, single soft light source top-left. Palette locked to: #FFD93D
#FF6B35 #FF4D6D #4D96FF #6BCB77 with #FFF8E7 / #2C2C2C / #FFFFFF. Character
in 3/4 view, centered, full body, neutral idle pose, generous safe margin,
square canvas, transparent background. Clean readable silhouette, adult-comedy
tone, humorous expression. Mobile-game production quality, cohesive studio
look. NO realism, NO anime, NO pixel art, NO 3D, NO photographic lighting.
--- APPEND PER CHARACTER ---
Subject: {profesion}. Props: {props}. Cultural cues: {ar_cues}.
Wealth cues: {wealth_cues}. Expression: {expression}.
```

Ejemplo Tier 1:
```
Subject: scruffy homeless man with attitude. Props: bottle, tattered clothes.
Cultural cues: Buenos Aires street character ("fisura"), disheveled but
endearing. Wealth cues: none, dirty patched clothes. Expression: dazed goofy stare.
```

> Con LoRA entrenado, el prompt operativo se reduce a `<trigger_word>, {profesion}, {props}, {ar_cues}`. El mega-prompt es solo para generar semillas.

### 6.4 `assets_manifest.json` (juntura arte ↔ código)

```json
{
  "characters": {
    "homeless": { "atlas": "earth", "key": "homeless_idle", "anchor": [0.5, 0.1], "scale": 1.0 }
  },
  "backgrounds": { "alley": "bg_alley", "urban": "bg_urban" },
  "ui": { "coin": "ui_coin", "btn_primary": "ui_btn_primary" }
}
```

Backgrounds evolutivos (11 stages del doc): alley → urban → corporate → luxury → island → moon → mars → solar → galaxy → cosmic → god_realm.

---

## 7. Plan por fases (milestones verificables)

| Fase | Entregable | Verificás |
|---|---|---|
| **F0** | Scaffold: proyecto Xcode/SwiftPM, `GameState`, CoreData stack, `.storekit`, manifest vacío, board SpriteKit con placeholders (formas + labels) | Compila en Simulador, se ve un board |
| **F1** | Economía: `tiers.json` + fórmulas, tap genera coins, spawn con curva | Podés tapear y comprar unidades |
| **F2** | Merge + pasivo: drag-and-drop merge-2, compra de pasivo por tipo, offline progression, prestige | Loop completo jugable con placeholders |
| **F3** | Arte real: pipeline §6 corre por tandas, se swappea el manifest | Juego con arte consistente |
| **F4** | Monetización: StoreKit local, rewarded ads stub→real, remove ads, skins | Compras funcionan en sandbox |
| **F5** | Pulido: partículas, haptics, animaciones de evolución, daily reward, eventos, specials, share cards | Se siente premium a 60fps |
| **F6** | Ship: cuenta Apple Developer, Game Center/CloudKit prod, TestFlight, submission | En la store |

Los subagentes trabajan en paralelo donde no hay dependencia (ej: Content llena JSONs mientras Gameplay codea el motor).

---

## 8. Viralidad y ASO

- **Share card automática:** al evolucionar/reincarnar se genera una imagen vertical ("Pasé de Fisura a CEO en 3 días 💀") para TikTok/IG/WhatsApp. Botón de compartir nativo.
- **Nombres meme-ables en español:** el humor ES la difusión. "El Fisura", "Egresado UBA", "Rey del Ladrillo".
- **Momentos de reveal absurdos:** la transición de tier como gancho de video corto vertical.
- **Referral con Soul Points:** compartir da un pequeño boost permanente.
- **ASO:** nombre + subtítulo apoyados en el chiste (ej: *"De fisura a Dios"*), keywords AR, capturas que muestren las evoluciones más ridículas.

---

## 9. Riesgos y gates (resumen)

| Riesgo | Mitigación |
|---|---|
| Cuenta Apple no lista | Todo dev en Simulador; $99 recién en F6 |
| Marcas reales (trademark) | Parodiar (McRonald's, delivery genérico) |
| Boost de drogas → review | Versión satírica/abstracta en la build de store |
| Consistencia de arte entre free tools | Hero refs viajan a toda app; VLM judge descarta drift |
| Balance de economía | Números `[TUNEABLE]`, playtesting en F2 antes del arte |
| SpriteKit + SwiftUI performance | Board 100% SpriteKit, pooling, atlases |

---

*Fin del bible. Todo `[TUNEABLE]`/`[DEFAULT]` está para que lo ajustes. El código nunca hardcodea tiers/economía/arte: todo sale de los JSON y del manifest.*
