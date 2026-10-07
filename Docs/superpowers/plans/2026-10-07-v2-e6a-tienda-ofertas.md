# E6a — La tienda de ORO, los packs reescalados y las ofertas de 24 h · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que el ORO tenga en qué gastarse (la tienda de ORO con sus cuatro estantes de consumo:
Boosts, Atajos, Permanentes y Suerte, con topes diarios y la escala aprobada de 1 h ≈ 90 ORO),
que los packs de ORO sean los de la 2.0 (160 / 550 / 1.400 sin tocar los IDs ni la foto de la
v1), y que las tres ofertas de 24 h (Bienvenida, Renacer y Mudanza) se abran solas en su
momento, se cobren con StoreKit y entreguen su contenido por el punto único de premios.

**Architecture:** las cuentas viven puras en EconomyKit: `ShopState` y `OffersState` en
`meta.engagement` (sin subir el schema), `OroShopCatalog` + `OroShop` (qué se ve, cuánto cuesta
hoy, qué lo bloquea y qué se compra, con `MetaState.spendOro` como única salida de ORO),
`AutoTapper` (el único efecto de premio nuevo), `ChestRoller.effectiveOdds` (las probabilidades
que se muestran son las que se sortean) y `OffersCatalog` + `OffersEngine` (disparadores, reloj
real de 24 h y enfriamiento de 3 días). La app sólo engancha: los premios salen por
`GameState.grant` (E4a T8), "Fusionar todo" por `enqueueMergeAll` (E2a T14), las ofertas por
`creditStorePurchase` y el reloj de las ofertas por `advanceEngagement` (E4a T9). Lo que se ve
—el selector "Comprar ORO / Gastar ORO", los estantes, el chip y la hoja de la oferta— no
decide nada.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · StoreKit 2 (+ StoreKit Testing en iOS 18.6) · EconomyKit (SPM puro, `Sendable`) ·
Swift Testing · XCUITest · XcodeGen (el `.xcodeproj` no se versiona) · Python 3 (la
herramienta del catálogo).

**Fuente:** `Docs/PLAN-v2.md` §4 "E6 — Tienda de ORO + IAP + skins" (la mitad de tienda,
packs y ofertas), §2 (decisiones cerradas del dueño: la escala de ORO, los packs, las ofertas,
"Bélgica y Australia", "ORO comprado sirve para todo"; **no se re-litigan**), §0.1 (agentes
concurrentes y calientes), §6 (Apple 3.1.1: probabilidades **antes** de comprar; 4.5.4: ni
ofertas ni precios en notificaciones). `Distribution/iap-appstore-connect.md` ya tiene las fichas
es/en de las tres ofertas y la tabla de montos nuevos (E10 en papel): este plan las usa tal cual.
Lo que el código contradice o la spec deja abierto está en "Para el dueño / dudas", con un
default que no frena.

**Rama de la épica:** `v2/e6-tienda`, desde `version-2` **con E5 integrada** (PLAN-v2: E5 → E6).
Cada tarea sale de su punta en un worktree propio (`Agent(isolation: "worktree")`, PLAN-v2 §0.1)
y el controlador integra de a una. Las dos primeras tareas de E6b (los shaders y la galería del
dueño) salen antes y desde `version-2`: no dependen de nada (ver "Orden, olas y paralelismo").

### Por qué E6 va en dos planes

E6 son dos cosas que comparten estante y nada más:

- **E6a (este plan) — la economía de la tienda:** el estado, el catálogo y las cuentas de la
  tienda de ORO, los premios nuevos que entrega (auto-tap, Offline ×3, Diario ×3), "Fusionar
  todo" por ORO, los permanentes que mejoran E5 (mejor proveedor, giros diarios), la suerte con
  probabilidades y su apagado en Bélgica y Australia, la pantalla, los packs de ORO reescalados y
  las ofertas de 24 h. Todo es código: no espera a ningún gate de arte (los íconos caen a SF
  Symbols hasta que E8 entregue los íconos de la tienda).
- **E6b (`2026-10-07-v2-e6b-lugares-skins.md`) — lo que se ve en el tablero:** el permanente de
  lugares extra (`extraSlots`, 4 filas), skins.json v2, las pintas compradas con ORO, los 8
  efectos por shader y las 3 familias dibujadas. Tiene **dos gates humanos**: la galería de los
  8 efectos (la aprueba el dueño) y los atlas de las familias (los entrega E8).

E6b depende de E6a en tres puntos que nombra con tarea y archivo (`ShopState.skins` de T1,
`OroShop` de T2 y la pantalla de T8). Sus tareas de shaders y de galería salen antes que todo,
porque el gate del dueño es lo más largo.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build (una `var` que no se muta, también). **Nada de `Timer` para lógica de juego**
  (regla 2): el auto-tap y el reloj de las ofertas avanzan con el delta del tick
  (`advanceEngagement`, E4a T9), con tope de 2 s y sólo con la escena activa (E1 T8). El reloj
  de 24 h de una oferta es de **pared** (`Date()`), no de juego: lo decidió el dueño ("reloj real
  de 24 h").
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo** (Swift, JSON de `Resources/Config` o test), en el mismo paso en que se crea. Un
  archivo nuevo de EconomyKit no lo pide (el proyecto referencia el paquete, no sus archivos).
- **Strings nuevos, es + en, en el mismo commit que el código que los usa**, siempre por
  `Tools/v2/catalogo.py` (E3a T1, formato canónico, trampa 29). Cada tarea escribe sus claves en
  `Tools/v2/claves-pendientes/e6a-tN.json` y las aplica con
  `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6a-tN.json` para correr sus tests.
  **Si en su ola es dueña de `Localizable.xcstrings`** (lo dice el despacho), commitea el catálogo
  y borra el JSON; **si no**, commitea sólo el JSON y descarta el catálogo
  (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`): el controlador lo aplica al
  integrar. A una clave con `%@` se le interpola un `String`, nunca un `Int` (trampa 5).
- **Los textos con números interpolan el dato, nunca lo escriben a mano** (la regla de
  `IAPCopy`, HANDOFF §5): el precio, el tope, la duración y el multiplicador salen de
  `oro_shop.json` / `offers.json` y entran por `%1$@`/`%2$@`.
- **El precio en plata sale SIEMPRE de `product.displayPrice`** (regla de `StoreView`). Un
  "USD 0,99" escrito en el catálogo es rechazo de App Review.
- **`MetaState.spendOro` es la única salida de ORO** (E1 T4). Gastar ORO **nunca** toca
  `oroEarnedLifetime` (el multiplicador global no se nerfea) y siempre suma a
  `stats.oroSpentEver`. El ORO de una oferta es **ORO comprado**: suma a
  `meta.oroPurchasedLifetime`, igual que un pack (E1 T6).
- **Lo mostrado es lo aplicado**: el precio que dice la fila es el que se cobra (la misma
  `OroShop.quote` cotiza y compra), la probabilidad que dice el cofre es la que se sortea
  (`ChestRoller.effectiveOdds` recorre el mismo embudo que `roll`), y el chip del auto-tap cobra
  lo que dice (`EffectContractTests`).
- **Apple 3.1.1**: todo lo que E6 vende con azar (el cofre de pintas por ORO y el cofre de la
  oferta de Bienvenida; el giro extra por ORO es de E5) **muestra sus probabilidades antes de
  comprar**, en la misma pantalla del botón, sin un toque de por medio, con la
  `OddsDisclosureView` de E5b T1. En las tiendas de `restrictedStorefronts` (hoy `BEL` y `AUS`,
  `ads.json`) **no se ofrece** (decisión del dueño), por el `LootBoxGate` de E5a T8, que **falla
  cerrado**: sin país conocido, no se ofrece.
- **Nunca se rechaza una compra ya pagada**: una transacción de oferta que llega fuera de su
  ventana de 24 h (o en una tienda restringida) se acredita igual. La ventana gobierna qué se
  **ofrece**, no qué se **entrega**.
- **Ofertas: nunca durante el tutorial**, nunca como notificación (guía 4.5.4, PLAN-v2 E11) y
  nunca encima de otra cosa: se abren solas una sola vez, en su turno de la cola de
  celebraciones (`.offer`, la de menor prioridad), y después viven en el chip.
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis). **FisuJobs es la referencia visual**: `PanelCard`/`GameCard`, `ActionPill`,
  `PricePill` (`.oro` para el ORO, `.money` para StoreKit), `StateBadge`, `Tokens`, paleta de la
  casa. Nada de botones ni alertas del sistema. Toda hoja nueva se presenta con `fisuSheet()`
  (E3a T6).
- **Nada nuevo corre bajo XCTest ni bajo `--uitest*` salvo que el test lo pida**: las ofertas se
  evalúan sólo con `engagementAutorun` (E4a T9). Las puertas de test son `--uitest-oro=<n>`
  (T8) y `--uitest-offer=<id>` (T12), colgadas de `applyEngagementFixtures`.
- **Data-driven**: precios, topes, niveles, valores de los permanentes, ventanas, enfriamientos y
  contenido de las ofertas viven en `oro_shop.json` y `offers.json`, con validador al arrancar
  (patrón `GameContentLoader.validate`). En código sólo quedan constantes con nombre y su porqué.
- **EconomyKit no conoce UI, `Bundle`, StoreKit ni `Date()`**: recibe el día (`"yyyy-MM-dd"`, de
  `DailyRewardManager.dayString`), el `now` y los predicados ya resueltos (lo entregable, el
  azar permitido, los pares de "Fusionar todo"). `EconomyKitTests` no tiene recursos: sus tests
  usan catálogos sintéticos; los hechos de los JSON reales se pinean del lado de la app.
- **Todo estado nuevo vive en `meta.engagement`** (`EngagementState`, E1 T4) con
  `decodeIfPresent ?? default` y su regla en `resolve`: **no se sube el schema** (v6). Trampa
  E7a: un `Codable` con `var x = 0` no decodifica un JSON sin esa clave; todo lo que se persiste
  lleva su `init(from:)`.
- **Ningún cambio del tablero que no hizo el jugador se aplica en el acto**: "Fusionar todo"
  encola por el embudo `BoardChange` de E1 (cada par en su turno, revalidado y con revelación).
- Código nuevo limpio y con pocos comentarios (regla del dueño: prolijidad antes que
  comentarios); los heredados no se borran por deporte, pero **el que miente se corrige** en el
  commit que lo vuelve mentira (los que dicen "packs de 250/750/2000" o "el ORO sólo compra
  mejoras", sobre todo).
- **Commits en español, estilo `feat(tienda): …` / `feat(ofertas): …`, SIN `Co-Authored-By`.**
  Staging selectivo por archivo y `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración con
  `oraculo.sh rapido` (o `completo` donde la tarea lo dice) → `Docs/SESION-<fecha>-v2-e6.md` →
  las cuatro ediciones de `Docs/HANDOFF.md` (§4, §5, §7, §9) → journal AVO y latido del `LOCK`.
  Ningún subagente toca `Docs/`, `handoffs/`, el journal ni `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

**El oráculo del run** juzga cada integración:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + store-unit y StoreUITests (18.6) + UI (26.5) + pipeline + pacing-sim + Release
```

- Termina en 0 (`VERDE`) sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`. **E6a no
  declara rojos.** Los tests nuevos entran solos (el oráculo corre las suites enteras): las
  suites de EconomyKit suben la cuenta de `economykit`, las de la app la de `unit`. Un VERDE con
  la misma cuenta que antes de sumar tests no probó nada (HANDOFF §6).
- ⚠️ **`StoreManagerTests` y `StoreProductsTests` sólo corren en la suite `store-unit` del
  `completo`, en iOS 18.6** (StoreKit Testing está roto en el runtime 26, trampa 30). El `rapido`
  las saltea: **una tarea que toca StoreKit, `products.json` o el `.storekit` corre la Receta S
  antes del commit y el `completo` al integrarse** (T9, T11). Si `store-unit` falla rotativo con
  un diff que no toca Store, es la máquina (HANDOFF §6): `git diff … | grep -i store` antes de
  sospechar del código.
- `rapido` al cerrar T1–T7 y T10. `completo` al cerrar T8 (pantalla nueva y `StoreUITests`), T9
  y T11 (Store), T12 (chip y hoja) y la épica (T13).
- ⚠️ El `pacing-sim` no modela la tienda ni las ofertas (es trabajo de E2b): su número **no se
  mueve** con E6a. Si se mueve, se busca por qué antes de integrar.

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…")
swift test --package-path Packages/EconomyKit --filter "OroShopTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE (sin "()" no corre nada)
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e6-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e6" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e6" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/OroShopPurchaseTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

**Receta S — las suites de Store, en iOS 18.6** (lo mismo que hace el `completo`: se compila
contra el 26.5 y se prueba en un 18.6):

```bash
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e6-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
UDID18=$(xcrun simctl create "e6-18-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-18-6)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e6" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID18" -derivedDataPath "$WT/build/DD-e6" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/StoreManagerTests -only-testing:FisuEvolutionTests/StoreProductsTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
xcrun simctl shutdown "$UDID18"; xcrun simctl delete "$UDID18"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y de `-only-testing:`). Mirá la salida. Ante un rojo en masa, antes
de culpar al código: `uptime`, `ps aux | grep '[x]codebuild'` y las rutas de los `SwiftCompile`
en el log (trampas 16, 33 y 44).

## Las referencias de PLAN-v2 E6, verificadas contra el árbol (`d22eb7a`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E6a |
|---|---|---|
| `StoreView` gana un selector "Comprar ORO / Gastar ORO" | `UI/Store/StoreView.swift:28-410`: una sola vidriera de IAP, sin selector; la cabecera (`:98-128`) es donde vive "Restaurar" | T8 suma el selector **en la cabecera** (se ve siempre, aunque StoreKit no cargue). Abre en "Comprar ORO": `StoreUITests.swift:49-75` busca las filas de IAP sin tocar nada |
| "Reemplaza los `Text(verbatim: product.displayName)` de `StoreView.swift`" | **ya hecho** por E3 i18n: `IAPCopy.name(for:fallback:)` en `StoreView.swift:212-217`, `Managers/Store/IAPCopy.swift` | nada: las ofertas nuevas sólo necesitan sus claves `iap.<id>.name/.desc` (T11) |
| `OroShopView`, `oro_shop.json`, `offers.json`, `OffersEngine` | no existen | T2, T4, T8, T10, T11 |
| `OddsDisclosureView` "compartida por la ruleta, el cofre por ORO y el Colchón" | no existe; **la crea E5b T1** (`UI/Art/OddsDisclosureView.swift`, con `RewardCopy`), porque la ruleta y el colchón la necesitan antes | E6 la **reusa** (T8, T12): no se crea otra |
| un solo `MetaState.spendOro` | `PlayerState.swift:482-489`: gasta del balance y suma `stats.oroSpentEver`; no toca `oroEarnedLifetime` (`:286`) | T2 compra por ahí y nada más |
| packs 160/550/1.400, "los IDs no cambian; el monto vive en `products.json` (`oroAmount`)" | `products.json:36-53`: 250 / 750 / 2000; `creditStorePurchase` `.oro` en `GameState+Store.swift:243-247` | T9 cambia los tres números. La foto de la v1 (`PurchasedOroHistory.v1OroAmountByProductID`, **E1 T6**, todavía no en el árbol) **no se toca** |
| "Los compradores de la v1 conservan su saldo" | `meta.oro` no se recalcula en ningún lado al cambiar `products.json` | nada que hacer; T9 lo pinea |
| "Se actualizan la descripción en App Store Connect y `iap-appstore-connect.md`" | `Distribution/iap-appstore-connect.md:140-201` **ya** tiene las tres ofertas y la tabla 160/550/1.400 (E10 en papel) | ASC es un gate humano de E10; T11 copia las fichas al `.storekit` y al catálogo |
| ofertas: chip `hud.offer.chip` + `OfferSheet` | `CelebrationQueue.swift:11-37`: no hay `.offer` (PLAN-v2 E4 lo nombra y E4b lo dejó para E6) | T12 suma el kind `.offer` (prioridad 6, sin timeout) |
| `restrictedStorefronts` en la config remota, según `Storefront.current?.countryCode` | `AdsRemoteConfig.swift:126-134` (`isRestricted(storefront:)`) y `ads.json:32` (`["BEL","AUS"]`); **`AdsRemoteConfigLoader` no se instancia en la app** (sólo en `AdsRemoteConfigTests`); nadie lee `Storefront` | **`LootBoxGate` lo crea E5a T8** (`Managers/LootBoxGate.swift`: `allows(countryCode:restricted:)`, `current(loader:) async`, falla cerrado). E6 lo **reusa**; T7 sólo le suma la última respuesta guardada, para los caminos síncronos (el tick de las ofertas) |
| probabilidades del cofre | `chests.json`: 55 / 28 / 12 / 5; `ChestRoller.roll` **promociona y degrada** la rareza sorteada cuando no hay stock (`ChestRoller.swift:46-75`, `:108-116`) y filtra por personajes desbloqueados | mostrar los pesos crudos mentiría: T7 crea `ChestRoller.effectiveOdds` (E5 no la hace: su ruleta da cofres, no muestra lo que hay adentro), que recorre el mismo embudo y devuelve las `PrizeOdds` de E5a T1 |
| "×2 ingresos 30 min", "Salto de 1 h" | `ActiveModifier.Effect.incomeMultiplier` (`ActiveModifier.swift:9`); los premios en segundos de producción pasan por `grant(.coinsSeconds)` (E4a T8) → `coinReward` → `RewardScale` (E2a T11) | no hay mecánica nueva: son filas del catálogo con su `RewardSpec` |
| "Auto-tap 10 min" | `ActiveModifier.Effect` no lo tiene; E4a lo deja explícitamente para E6 ("`autoTapPerSecond` es de E6") | T3: el efecto `autoTapPerSecond` y `AutoTapper` |
| "Offline ×3 · 1 pendiente", "Diario ×3 · 1/día" | el popup offline nace en `GameState.applyOfflineProgressIfNeeded` (`GameState.swift:919-939`, E1 T1; E1 T8 puede mudarlo a `+Lifecycle`); el diario se cobra solo en `claimDailyIfAvailable` (`GameState+Bonus.swift:258-281`) con `DailyRewardManager.Claim` (`ContentSystems.swift:349-355`) | T5: dos líneas, una por punto de consumo |
| "Saltear cooldowns" | `RewardSpec.clearBoostCooldowns` (E4a T1) y `BoostManager.cooldownRemaining` (`ContentSystems.swift:261`) | se ofrece sólo si hay un boost esperando |
| "Fusionar todo (piso actual) · 20 · 5/día" | `enqueueMergeAll(onFloor:origin:)` (**E2a T14**) sobre `BoardChangePlanner.planMergeAll` (E2a T6/T9); `BoardChange.Origin` (E1 T7) sin caso de tienda | T6 suma `Origin.oroShop` y su regla en `discardBoardChange` (E1 T14) |
| "Cofre de pintas · 45" | `RewardSpec.skinChest` → `meta.chestsPending` (E4a T8); se abre en Regalos (`GameState+Chests.swift:76-111`) | el cofre comprado espera en Regalos (duda 6) |
| "Giro extra de ruleta · 12 · 6/día" | lo nombran **las dos** secciones de PLAN-v2 (E5 y E6); **lo implementa E5a T8** (`spinWheel(.oro, storefrontAllows:)`, `wheel.json` → `oroSpinCost` 12, `oroSpinsPerDay` 6, `spendOro`, `LootBoxGate`) y se vende adentro de la ruleta, con sus probabilidades al lado | E6 **no** lo vende otra vez ni lo repite en el estante de Suerte (duda 3) |
| "Mejor proveedor N1/N2/N3", "+1/+2/+3 giros diarios" | E5a deja los enchufes: la tabla de `r` por nivel ya está en `packages.json` (`tierRatioByBestSupplierLevel` = 2 / 1,8 / 1,6 / 1,4, `PackagesConfig.tierRatio(bestSupplierLevel:)`) y `openPackage()` lee el nivel 0 con un comentario "E6"; los giros por video salen de `WheelConfig.videoSpinsPerDay` en `WheelRoller.spinsLeft` | T2 modela los dos permanentes por nivel (el de proveedor **sólo da el nivel**: el `r` es dato de E5); T6 cambia el `0` por el nivel y suma los giros con `WheelConfig.withBonusVideoSpins(_:)` en un solo lugar |
| las 7 líneas a 348 ("E6: sumideros, líneas a 348", tabla §4 C1) | `upgrades.json`; PLAN-v2 E2b lo hace ("las 7 líneas pasan a `baseCost` 2 (348)") | **E6 no lo toca**: es de E2b, que re-pinea `upgradeCatalogMatchesTunedValues` en su calibración |
| `meta.shop`, `meta.shopSkins`, `meta.offers` (PLAN-v2 E1) | E1 T4 dejó el contenedor `meta.engagement` (`EngagementState.swift:1-14`, vacío) y su plan pone ahí `shop`, `shopSkins`, `offers` y `firstLaunchDay` | T1: `engagement.shop` (con las pintas de ORO adentro), `engagement.offers` y `engagement.firstLaunchDay` |
| el anclaje del tutorial (`TutorialTarget.oroShop`) | `TutorialAnchor.swift:8-29`: no está | T8 suma `.oroShop`; T12, `.offerChip` (los ganchos de E9) |

## Lo que E6a hereda de otras épicas (todavía no está en el árbol)

E6 corre "luego" (PLAN-v2 §0.1): **después de E5**. Las APIs se citan como las definen sus
planes; cada tarea dice de cuál depende y su **paso 0 lo comprueba con `grep`**. Si al despachar
una tarea su API no está en la punta de `v2/e6-tienda`, el agente para con `NEEDS_CONTEXT`: no
se inventa.

| API | La define | La usa |
|---|---|---|
| `MetaState.engagement: EngagementState` (con su `init(from:)` y su `resolve`), `MetaState.spendOro`, `oroPurchasedLifetime` | E1 T4 (**en el árbol**) | T1, T2, T11 |
| `PurchasedOroHistory.v1OroAmountByProductID` (250/750/2000, foto); `creditStorePurchase` `.oro` suma a `oroPurchasedLifetime` | E1 T6 (**en curso**) | T9 (no lo toca: lo pinea), T11 |
| `BoardChange.Origin` (`eventStartup`, …, `debug`), `discardBoardChange` con `switch` exhaustivo sobre `Origin` | E1 T7, T14 | T6 |
| `GameState.isSceneActive`, el tick con `guard isSceneActive` | E1 T8 | T5 (por `advanceEngagement`) |
| `ActiveModifier.Effect: CaseIterable`, `EffectContractTests.modifierEffects` (con `producing()`, `passive(_:)`, `applied(_:as:)`) | E1 T15 | T3 |
| `RewardScale` y `coinReward(seconds:)` sobre él; `GameState.coinPayout(minutes:player:content:)` | E2a T1, T7, T11 | T5 (vía `grant`), T11 |
| `StandardEconomy.applyTap(type:state:tiers:floorTable:now:)` (suma `tiers:`) | E2a T4 | T3 |
| `BoardChangePlanner.planMergeAll(floorOrdinal:state:tower:tiers:floorTable:config:origin:)`, `GameState.enqueueMergeAll(onFloor:origin:) -> Int` | E2a T6, T9, T14 | T6 |
| `products.json` con `coinMinutes` y `creditStorePurchase`/`packRewardText` en minutos | E2a T7 | T9, T11 (mismo archivo y misma función) |
| `DailyRewardManager.claimIfAvailable(…)` con su firma nueva (minutos) | E2a T11 | T5 (sólo envuelve el resultado) |
| `Tools/v2/catalogo.py` (`aplicar`, `verificar`) y `Tools/v2/claves-pendientes/` | E3a T1 (**en el árbol**) | toda tarea con strings |
| `fisuSheet()` | E3a T6 | T12 (la `OfferSheet`) |
| `MenuPagerView` (Tienda es una página con su `NavigationStack`) | E3b T3/T4 | T8 (el selector vive adentro de `StoreView`: el paginador no cambia) |
| `RewardSpec` (12 tipos, `scaled(by:)`, `validate()`, JSON) | E4a T1 | T2, T4, T10, T11 |
| `ActiveModifier.Effect.passiveMultiplier`, `.eventImmunity`, `.packageRateMultiplier` | E4a T2 (`freeHire` y `eventImmunity` pueden venir de E2a T12) | T3 (filas vecinas), T4 (Lluvia de paquetes) |
| `EngagementState` con `visitors` y `events` (E4a T3), `sharedMoments` (E3b T9) y los campos de E5 | E4a T3, E3b T9, E5 | T1 (suma los suyos al mismo `init` y `resolve`) |
| `GameState.grant(_:multiplier:source:now:)`, `grantableRewardKinds`, `isCalmMoment`, `creditCoins` | E4a T8 | T5, T6, T11, T12 |
| `GameState.advanceEngagement(delta:)`, `engagementAutorun`, `applyEngagementFixtures()`, `fixtureValue(_:in:)` | E4a T9 | T5, T8, T12 |
| `StageChips` en `RootView.hudColumn` | E4b T3 | T12 (el chip de la oferta va al lado) |
| `GameContentLoader` con `notifications` (E11 T2), `tabs` (E3a T9), `visitors`/`events` v2 (E4a T7/T9) y los configs de E5 | varios | T4, T11 (suman los suyos al lado) |
| `LocalizationCompletenessTests.DynamicFamily` con las familias de E4/E5/E11 | varios | T4, T11 (suman `oroShop`, `offers`) |
| **E5** — ver la sección siguiente, con los nombres exactos | E5a, E5b | T4, T6, T7, T8, T11, T12 |

## Lo que E6a consume de E5 (plan integrado en `version-2`, `da86b16`)

Los planes de E5 (`2026-10-07-v2-e5a-aduana-colchon-ruleta.md`, el motor, y `…-e5b-…`, lo que se
ve) se quedaron con varias piezas que PLAN-v2 ponía en E6. **E6a las consume y no las crea**: si
al despachar una tarea su pieza de E5 no está en la punta de `v2/e6-tienda`, el agente para con
`NEEDS_CONTEXT`.

| Pieza de E5 | Nombre exacto | Nace en | La usa E6a en |
|---|---|---|---|
| El paquete y el giro se entregan por el punto único | `.package` (→ `meta.engagement.packages.waiting += n`, pasa el tope) y `.wheelSpin` (→ `meta.engagement.wheel.bonusSpins += n`) en `grantableRewardKinds` y en `grant` | E5a T6, T8 | T5 (la lista de lo entregable), T6 (Lluvia de paquetes), T11 (Mudanza: `.package(3)`) |
| El ritmo del Paquete lee el modificador de Lluvia | el reloj de `advancePackages` lee `.packageRateMultiplier` | E5a T6 | T4 (Lluvia de paquetes = `grant(.modifier(effect: .packageRateMultiplier, magnitude: 10, seconds: 60))`) |
| La tabla de `r` por nivel de "mejor proveedor" | `PackagesConfig.tierRatioByBestSupplierLevel` (2 / 1,8 / 1,6 / 1,4) y `PackagesConfig.tierRatio(bestSupplierLevel:) -> Double` | E5a T1, T5 | T2 (el permanente sólo da el **nivel**), T6 |
| El enchufe del proveedor | en `openPackage()` (`GameState+Packages.swift`, E5a T6): `content.packages.tierRatio(bestSupplierLevel: 0)` con el comentario `// E6: el nivel del permanente "mejor proveedor".` | E5a T6 | T6 cambia el `0` por `bestSupplierLevel` |
| El cupo de giros por video | `WheelConfig.videoSpinsPerDay` (6), leído por `WheelRoller.spinsLeft(_:state:config:)` y `consume(_:state:config:)`; los llamadores son `wheelAvailability(storefrontAllows:now:)` y `spinWheel(_:storefrontAllows:now:)` (`GameState+Wheel.swift`, E5a T8) y la notificación `wheel_ready` (E5b T6) | E5a T3, T8; E5b T6 | T6: "+1/+2/+3 giros diarios" les pasa `effectiveWheel` (= `content.wheel.withBonusVideoSpins(bonusDailyWheelSpins)`) en vez de `content.wheel`, en un solo cálculo |
| El giro extra con ORO | `spinWheel(.oro, storefrontAllows:)`, `wheel.json` → `oroSpinCost` 12 y `oroSpinsPerDay` 6, `spendOro` | E5a T8 | **ni se re-vende ni se repite en el estante**: se compra adentro de la ruleta, con su tabla al lado (duda 3) |
| La puerta de Bélgica y Australia | `enum LootBoxGate` (`FisuEvolution/Managers/LootBoxGate.swift`): `allows(countryCode:restricted:) -> Bool` (sin país, **no**: falla cerrado) y `current(loader:) async -> Bool` | E5a T8 | T7 (le suma la última respuesta para lo síncrono), T8, T12 |
| Las probabilidades a la vista | `OddsDisclosureView(titleKey:rows:identifier:)` con `OddsDisclosureView.Row(id:title:symbol:probability:)` (probabilidad 0…1) y `OddsDisclosureView.percent(_:)`, en `UI/Art/OddsDisclosureView.swift` | E5b T1 | T8 (la fila del cofre), T12 (la hoja de Bienvenida) |
| Cómo se dice un premio | `enum RewardCopy` (`title(_:)`, `slice(_:)`, `symbol(_:)`, `text(_:_:)`), cubre los 12 tipos de `RewardSpec` (también `.autoTap` y los ×3 pendientes) | E5b T1 | T4 (lo que da cada consumible), T12 (los renglones de una oferta) |
| La tabla que se muestra | `public struct PrizeOdds` (`id`, `probability`) y `WeightedDraw` | E5a T1 | T7 (`ChestRoller.effectiveOdds` devuelve `PrizeOdds`) |

**E6a produce para E5:** el nivel del permanente "mejor proveedor" (`GameState.bestSupplierLevel`,
leído de `engagement.shop.levels`), los giros por video de más (`bonusDailyWheelSpins` y
`WheelConfig.withBonusVideoSpins(_:)`), `ChestRoller.effectiveOdds` (por si la ruleta quiere un
día mostrar lo que hay adentro de su cofre) y `LootBoxGate.lastKnown` (la última respuesta, para
lo que no puede esperar a StoreKit).

## La tienda de ORO en una página

```
oro_shop.json ── OroShopCatalog (EK) ── validate(floorIDs:) al cargar
   │  ítem = consumible (precio + premios o acción, tope diario, ×1,25 por compra)
   │       | permanente (perk + niveles con precio y valor)
   ▼
OroShop.visibleItems(catalog:, context:)           ← qué se ve: lo entregable, el piso alcanzado,
   │                                                  el azar sólo si LootBoxGate lo permite
OroShop.quote(item, state:, context:)  ──►  Quote { price, level, boughtToday, blocker? }
   │        blocker: cantAfford · dailyLimitReached · alreadyPending · maxed · nothingToDo
   ▼
GameState.buyOroShopItem(id:chanceAllowed:)  (T6)
   │  OroShop.purchase → spendOro (la ÚNICA salida) + topes del día / nivel
   ├─ premios  → grant(rewards, source: "shop.<id>")   (×2/×3, salto de 1 h, auto-tap, Lluvia,
   │                                                   cofre, Offline ×3, Diario ×3, cooldowns)
   ├─ acción   → enqueueMergeAll(onFloor: visible, origin: .oroShop)   (cada par en su turno)
   └─ perk     → el nivel lo leen E5 (el r de packages.json, los giros por video) y E6b (los lugares)

(el giro extra con ORO no pasa por acá: lo vende la ruleta de E5a T8)
```

## Las ofertas en una página

```
tick (escena activa, delta ≤ 2 s) → advanceEngagement → advanceOffers   (sólo con engagementAutorun,
   │                                                                     nunca en el tutorial)
   │  OfferSignals { hoy, primer día, nivel de prestigio, pisos abiertos en la run }
   ▼
OffersEngine.evaluate: cierra las vencidas (reloj de pared, 24 h) → toma la línea de base la
   │   primera vez (un veterano no recibe tres ofertas al actualizar) → dispara:
   │     secondDay (hoy > primer día) · reincarnation (sube el prestigio) · newFloor (sube la cuenta de pisos)
   │   abre si: no está abierta · no se usó (las de una vez) · pasó el enfriamiento (3 días desde
   │   que cerró) · es ofrecible (todo su contenido es entregable; con azar, LootBoxGate)
   ▼
ActiveOffer { abierta, vence, presentada }  ── chip `hud.offer.chip` con la cuenta regresiva
   │                                         ── la primera vez, `.offer` en la cola (menor prioridad)
   ▼
OfferSheet → store.purchase(product) → StoreKit → creditStorePurchase(.offer)   (T11)
   grant(rewards) + oroPurchasedLifetime += ORO de la oferta + OffersEngine.markPurchased
   ⚠️ fuera de la ventana también se acredita: lo pagado se entrega
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/Shop/ShopState.swift` | **nuevo** — topes del día, niveles, multiplicadores pendientes, pintas de ORO; `resolve`, `on(day:)` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/Offers/OffersState.swift` | **nuevo** — ofertas abiertas, enfriamientos, las de una vez, compras, líneas de base | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` | `shop`, `offers`, `firstLaunchDay` en el `init(from:)` y en `resolve` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift` | **nuevo** — `oro_shop.json` como tipo y su validador | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift` | **nuevo** — visibles, cotizar, comprar, perks | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` | `autoTapPerSecond`, `ModifierMath.autoTapsPerSecond` | 3 |
| `Packages/EconomyKit/Sources/EconomyKit/AutoTapper.swift` | **nuevo** — a quién toca y cuánto paga | 3 |
| `FisuEvolution/Game/State/ActiveBonus.swift`, `FisuEvolution/UI/HUD/ActiveBonusBar.swift` | texto y color del chip del auto-tap | 3 |
| `FisuEvolution/Resources/Config/oro_shop.json` | **nuevo** — los 13 ítems de la tabla aprobada (sin cosméticos ni lugares extra, que son de E6b, ni el giro extra, que es de E5) | 4 |
| `FisuEvolution/Managers/OroShopCopy.swift` | **nuevo** — nombres, descripciones y estantes, con los números del dato | 4 |
| `FisuEvolution/Managers/GameContentLoader.swift` | carga y valida `oro_shop.json` (T4) y `offers.json` (T11) | 4, 11 |
| `FisuEvolution/Game/State/GameState+Rewards.swift` | `.autoTap`, `.nextOfflineMultiplier`, `.nextDailyMultiplier` entregables | 5 |
| `FisuEvolution/Game/State/GameState+OroShop.swift` | **nuevo** — consumir los ×3, el tick del auto-tap (T5); contexto, filas, comprar, perks (T6); probabilidades del cofre (T7) | 5, 6, 7 |
| `FisuEvolution/Game/State/GameState+Engagement.swift` | el auto-tap (T5) y las ofertas (T12) en `advanceEngagement`; las puertas `--uitest-oro=` (T8) y `--uitest-offer=` (T12) | 5, 8, 12 |
| `FisuEvolution/Game/State/GameState.swift` (o `+Lifecycle` si E1 T8 lo mudó) | el popup offline consume el Offline ×3 (una línea) | 5 |
| `FisuEvolution/Game/State/GameState+Bonus.swift` | el diario consume el Diario ×3 (una línea) | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift`, `FisuEvolution/Game/State/GameState+BoardChanges.swift` | `Origin.oroShop` y su regla al descartarse | 6 |
| los llamadores de E5 (`PackageRoller.roll`, el cupo de giros) | el `r` y los giros extra de los permanentes | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/Shop/ShopPerks.swift` | **nuevo** — `WheelConfig.withBonusVideoSpins(_:)` (el enchufe de giros de E5, en un archivo de E6) | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/ChestRoller.swift` | `ChestOddsTable`, `effectiveOdds` (con las `PrizeOdds` de E5a) | 7 |
| `FisuEvolution/Managers/LootBoxGate+LastKnown.swift` | **nuevo** — la última respuesta del `LootBoxGate` de E5a, para lo síncrono | 7 |
| `FisuEvolution/Managers/Store/StoreManager.swift` | refresca esa respuesta al arrancar | 7 |
| `FisuEvolution/UI/Popups/ChestOpeningView.swift` | `ChestRarityStyle.name(_:)` y `.symbol(_:)` para la tabla del cofre | 7 |
| `FisuEvolution/UI/Store/OroShopView.swift` | **nuevo** — estantes, filas, saldo | 8 |
| `FisuEvolution/UI/Store/StoreView.swift` | el selector en la cabecera (T8); la oferta abierta arriba de la vidriera (T12) | 8, 12 |
| `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` | `.oroShop` (T8), `.offerChip` (T12) | 8, 12 |
| `FisuEvolution/Resources/Config/products.json` | 160/550/1.400 (T9); las tres ofertas (T11) | 9, 11 |
| `StoreKitConfig/FisuEvolution.storekit` | las tres ofertas, con las fichas de `iap-appstore-connect.md` | 11 |
| `Packages/EconomyKit/Sources/EconomyKit/Offers/OffersCatalog.swift`, `OffersEngine.swift` | **nuevos** — `offers.json` como tipo, disparadores, ventana, enfriamiento | 10 |
| `FisuEvolution/Managers/Store/ProductCatalog.swift` | `Entitlement.offer`, `offerId` | 11 |
| `FisuEvolution/Game/State/GameState+Store.swift` | `creditStorePurchase` y `packRewardText` con `.offer` | 11 |
| `FisuEvolution/Managers/Store/IAPCopy.swift` | `quantity(for:)` con `.offer` | 11 |
| `FisuEvolution/Resources/Config/offers.json` | **nuevo** — las tres ofertas aprobadas | 11 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift`, `FisuEvolution/Game/State/GameState+Celebrations.swift` | el kind `.offer` | 12 |
| `FisuEvolution/Game/State/GameState+Offers.swift` | **nuevo** — avanzar, ofrecible, la que se presenta | 12 |
| `FisuEvolution/Managers/OfferCopy.swift`, `FisuEvolution/UI/Offers/OfferChip.swift`, `OfferSheet.swift` | **nuevos** — el contenido en palabras, el chip, la hoja | 12 |
| `FisuEvolution/App/RootView.swift` | el chip en la columna del HUD y la hoja | 12 |
| tests | EK: `ShopOffersStateTests`, `OroShopCatalogTests`, `OroShopTests`, `AutoTapTests`, `ChestOddsTests`, `OffersEngineTests`; app: `OroShopContentTests`, `PendingMultiplierTests`, `OroShopPurchaseTests`, `ChestOddsAppTests`, `OffersPurchaseTests`, `OffersRuntimeTests` + `EffectContractTests`, `RewardGrantTests`, `StorePacksTests`, `StoreManagerTests` (18.6) y, de E5a, `PackageRuntimeTests`/`WheelRuntimeTests` (sin cambios de expectativa); UI: `OroShopUITests`, `OffersUITests` | 1–12 |

## Orden, olas y paralelismo

**Archivos calientes** (un solo dueño por ola, PLAN-v2 §0.1): `GameState.swift`,
`RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`, `GameState+Bonus.swift`,
`SettingsView.swift`, `PlayerState.swift`, `TowerActions.swift`, `project.yml`,
`Localizable.xcstrings`. **Tibios** (♨️, otra épica los toca en su ventana):
`EngagementState.swift` (E3b T9, E4a T3, E5), `GameContentLoader.swift` (E4a, E5, E11),
`LocalizationCompletenessTests.swift`, `GameState+Rewards.swift` (E4a T8, E5),
`GameState+Engagement.swift` (E4a T9, E4b, E5), `GameState+BoardChanges.swift` (E1, E2a),
`BoardChange.swift` (E1 T7, E2a T6/T9), `GameState+Store.swift` y `products.json` (E1 T6, E2a T7),
`StoreManager.swift` (E1 T6), `CelebrationQueue.swift` / `GameState+Celebrations.swift` (E4b),
`ActiveModifier.swift` / `ActiveBonus.swift` / `ActiveBonusBar.swift` / `EffectContractTests.swift`
(E1 T13/T15, E2a T12, E4a T2), `StoreView.swift` (E3b T3/T4), los archivos de E5.

E6a **no toca** `BoardScene.swift`, `ContentSystems.swift`, `SettingsView.swift`,
`PlayerState.swift`, `TowerActions.swift` ni `project.yml`.

| T | Qué | Archivos | 🔥 / ♨️ | Depende de |
|---|---|---|---|---|
| 1 | estado de tienda y ofertas | `ShopState.swift`, `OffersState.swift`, `EngagementState.swift`, `ShopOffersStateTests.swift` | ♨️ `EngagementState` | E1 T4 ✅; los dueños previos del `init` de `EngagementState` (E3b T9, E4a T3, **E5a T4**: `packages`, `treasures`, `wheel`) |
| 2 | catálogo y cuentas (EK) | `OroShopCatalog.swift`, `OroShop.swift`, `OroShopCatalogTests.swift`, `OroShopTests.swift` | — | T1, **E4a T1** |
| 3 | auto-tap | `ActiveModifier.swift`, `AutoTapper.swift`, `AutoTapTests.swift`, `ActiveBonus.swift`, `ActiveBonusBar.swift`, `EffectContractTests.swift`, catálogo | catálogo (o snapshot) · ♨️ `ActiveModifier`, `ActiveBonus*`, `EffectContractTests` | **E1 T15**, **E4a T2**, **E2a T4** |
| 4 | el contenido | `oro_shop.json`, `OroShopCopy.swift`, `GameContentLoader.swift`, `OroShopContentTests.swift`, `LocalizationCompletenessTests.swift`, catálogo | catálogo · ♨️ loader, `LocalizationCompletenessTests` | T2; loader de E4a/E5/E11; **E5b T1** (`RewardCopy`); **E5a T5** (`packages.json` con la tabla del proveedor, para el test cruzado) |
| 5 | los premios nuevos se entregan | `GameState+Rewards.swift`, `GameState+OroShop.swift`, `GameState+Engagement.swift`, `GameState.swift` (o `+Lifecycle`), `GameState+Bonus.swift`, `PendingMultiplierTests.swift`, `RewardGrantTests.swift` | 🔥 `GameState.swift`, `GameState+Bonus.swift` · ♨️ `+Rewards`, `+Engagement` | T3; **E4a T8, T9**; **E5a T6, T8** (`.package`/`.wheelSpin` entregables); **E2a T11** |
| 6 | comprar en la tienda | `GameState+OroShop.swift`, `ShopPerks.swift`, `BoardChange.swift`, `GameState+BoardChanges.swift`, `GameState+Packages.swift`, `GameState+Wheel.swift` (E5), `OroShopPurchaseTests.swift` | ♨️ `BoardChange`, `+BoardChanges`, `+Packages`, `+Wheel` | T4, T5; **E2a T14**; **E1 T14**; **E5a T1, T3, T6, T8** |
| 7 | la suerte | `ChestRoller.swift`, `ChestOddsTests.swift`, `LootBoxGate+LastKnown.swift`, `StoreManager.swift`, `ChestOpeningView.swift`, `GameState+OroShop.swift` (probabilidades), `ChestOddsAppTests.swift` | ♨️ `StoreManager`, `+OroShop` | T6 (mismo archivo de la app); **E5a T1** (`PrizeOdds`), **E5a T8** (`LootBoxGate`); **E1 T6** |
| 8 | la pantalla | `StoreView.swift`, `OroShopView.swift`, `TutorialAnchor.swift`, `GameState+Engagement.swift` (`--uitest-oro=`), `OroShopUITests.swift`, catálogo | catálogo · ♨️ `StoreView`, `+Engagement` | T6, T7; **E3b T4**; **E5b T1** (`OddsDisclosureView`); **E5a T8** (`LootBoxGate`) |
| 9 | packs reescalados | `products.json`, `StorePacksTests.swift`, `StoreManagerTests.swift` | ♨️ `products.json`, `StoreManagerTests` | **E1 T6**, **E2a T7** |
| 10 | ofertas (EK) | `OffersCatalog.swift`, `OffersEngine.swift`, `OffersEngineTests.swift` | — | T1, **E4a T1** |
| 11 | ofertas: el cobro | `products.json`, `FisuEvolution.storekit`, `ProductCatalog.swift`, `GameState+Store.swift`, `IAPCopy.swift`, `offers.json`, `GameContentLoader.swift`, `LocalizationCompletenessTests.swift`, `OffersPurchaseTests.swift`, `StoreManagerTests.swift`, catálogo | catálogo · ♨️ `products.json`, `+Store`, loader | T9, T10; **E4a T8**; **E2a T7**; **E5a T6** (`.package` entregable: Mudanza) |
| 12 | ofertas: lo que se ve | `CelebrationQueue.swift`, `GameState+Celebrations.swift`, `GameState+Offers.swift`, `GameState+Engagement.swift`, `OfferCopy.swift`, `OfferChip.swift`, `OfferSheet.swift`, `RootView.swift`, `StoreView.swift`, `TutorialAnchor.swift`, `OffersRuntimeTests.swift`, `OffersUITests.swift`, catálogo | 🔥 `RootView.swift`, catálogo · ♨️ `CelebrationQueue`, `+Celebrations`, `+Engagement` | T7, T8 (la clave `oroShop.chest.odds`), T11; **E5a T8** (`LootBoxGate`); **E4b T3**; **E3a T6**; **E5b T1** (`OddsDisclosureView`, `RewardCopy`); **E5b T2** (último dueño previo de `RootView`) |
| 13 | cierre | `Docs/` (controlador) | — | todas |

```
Ola 1 (EK puro + un JSON)   T1 estado → T2 catálogo ║ T10 ofertas EK ║ T9 packs
Ola 2                        T3 auto-tap ║ T4 contenido (dueña del catálogo)
── caliente ──
Ola 3                        T5 premios nuevos (dueña de GameState.swift y +Bonus) → T6 comprar ║ T11 ofertas: el cobro (snapshot)
Ola 4                        T7 suerte → T8 pantalla (dueña del catálogo)
Ola 5                        T12 ofertas: lo que se ve (dueña de RootView y del catálogo)
Ola 6                        T13 cierre
```

E6b corre al lado (su plan tiene la tabla completa): sus T1–T2 (shaders y galería) **antes de la
Ola 1**, porque el gate del dueño es lo más largo; su T3 y T6 (EK puro) en la Ola 1–2; su T4
(`PlayerState.swift`) después de T8 de E6a; su T5 (`BoardScene.swift`) y su T7 (`GameState.swift`)
después de T5 y de T12 de E6a.

**Reglas del paralelismo:**

1. Cada tarea corre en su worktree aislado desde la punta de `v2/e6-tienda`, con su DerivedData
   (`build/DD-e6`) y su simulador por UDID, que apaga y borra al terminar. Hasta 3 compilando a
   la vez en todo el run; las tareas puras de EK (T1, T2, T10) no compilan la app salvo en el
   paso de oráculo.
2. Si en una ola dos tareas necesitan strings, la que **no** es dueña del catálogo entrega su
   snapshot (`e6a-tN.json`) y el controlador lo aplica al integrar.
3. **E6 ∥ E5 por tarea** (comparten `GameState+Engagement.swift`, `GameState+Rewards.swift` y los
   archivos de E5): T5 y T6 salen de una `v2/e6-tienda` con `version-2` mergeada **y E5 entera
   adentro**. Su paso 0 lo comprueba (`grep -n "case .package" FisuEvolution/Game/State/GameState+Rewards.swift`).
4. **T5 es la única de E6a que toca `GameState.swift` y `GameState+Bonus.swift`; T12 la única que
   toca `RootView.swift`.** No van en la misma ola que otra tarea (de cualquier épica) que toque
   esos archivos. Un agente que necesita un caliente ajeno para con `NEEDS_CONTEXT`.
5. T9 y T11 tocan StoreKit: corren la Receta S antes de su commit.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` (async, **no** throws; repo en memoria) | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| el contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift:31` |
| config/estado sintético de EK | `fxConfig`, `fxEconomy`, `fxType`, `fxTiers`, `fxFloorTable`, `fxState`, `fxStateAndTower`, `fxSlots` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` |
| la bolsa de cofres sintética y su desbloqueo | `fxChestSkins()`, `fxChests()`, `fxTodoDesbloqueado(_:)`, `fxDesbloqueadoHasta(_:_:)` | `Fixtures.swift:152-200` |
| RNG determinista en EK | `SeededRNG(seed:)` | `Fixtures.swift:134` |
| ORO, frontera, pisos | `gameState.player?.meta.oro = 500` (el `player` es `var`), `debugUnlockFloors(throughTier:)`, `debugSetMaxTier(_:)`, `debugGrantCoins()` | `GameState+Debug.swift` |
| el día de hoy como lo cuenta el diario | `DailyRewardManager.dayString(for:calendar:)` | `ContentSystems.swift:358` |
| el cooldown de un boost | `BoostManager.cooldownRemaining(of:state:now:)` | `ContentSystems.swift:261` |
| a quién puede darle algo un cofre | `chestUnlockedCharacterTypes`, `canOpenChest` | `GameState+Chests.swift:134-157` |
| nombre y color de una rareza | `ChestRarityStyle.nameKey(_:)`, `.color(_:)` | `ChestOpeningView.swift:14-31` |
| un pack sintético | `oroPack(id:amount:)` (privado: copiarlo) | `StorePacksTests.swift:49` |
| la tienda local de StoreKit | `makeSession()` + `waitUntil(timeout:_:)` (privados) | `StoreManagerTests.swift:15-42` |
| leer el catálogo de strings | `LocalizationCompletenessTests.catalog("Localizable")` | `LocalizationCompletenessTests.swift` |
| vaciar la cola de celebraciones | `drainCelebrations(_:)` (privado: copiarlo) | `CelebrationWiringTests.swift` |
| abrir la tienda en UI | `app.buttons["hud.store"]` + `--uitest-reset --uitest-skip-tutorial` | `StoreUITests.swift:19-27` |
| el punto único de premios | `grant(_:multiplier:source:now:)`, `grantableRewardKinds` | **E4a T8** |
| "Fusionar todo" | `enqueueMergeAll(onFloor:origin:)`, `pendingBoardChanges`, `inFlightBoardChange` | **E2a T14**, E1 T9 |

La escalera sintética de EK: `a(1) → b(2) → [choice] c_prog/c_law (3) → d(4)`; pisos `f1 {1–2}`
y `f2 {3–4}`, capacidad 5. El tipo base real es `homeless`; los pisos reales `alley` (1–4) …
`god_realm` (37).

---

### Task 1: La tienda y las ofertas recuerdan en `meta.engagement`

**Objetivo:** el estado persistente de E6 entra al contenedor de E1 sin subir el schema:
`shop` (los topes del día, los niveles de los permanentes, los ×3 comprados que esperan su
offline o su diario, y las pintas compradas con ORO, que E6b usa), `offers` (las abiertas con su
vencimiento, los enfriamientos, las de una vez y las líneas de base de los disparadores) y
`firstLaunchDay` (el día del primer arranque de la 2.0, para la oferta del 2º día). Un save que
no los tiene decodifica con `.initial`; dos saves en conflicto no pierden nada comprado ni
duplican el cupo del día.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Shop/ShopState.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Offers/OffersState.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/ShopOffersStateTests.swift`

**Interfaces:**
- Consumes: `EngagementState` (E1 T4) con los campos que ya le sumaron E3b T9 (`sharedMoments`),
  E4a T3 (`visitors`, `events`) y **E5a T4** (`packages`, `treasures`, `wheel`).
- Produces: `public struct ShopState: Codable, Sendable, Equatable` con `day: String?`,
  `purchasesToday: [String: Int]`, `levels: [String: Int]`, `pendingOfflineMultiplier: Double?`,
  `pendingDailyMultiplier: Double?`, `skins: Set<String>`, `static let initial`,
  `func on(day:) -> ShopState`, `static func resolve(winner:loser:)`.
- Produces: `public struct ActiveOffer: Codable, Sendable, Equatable, Identifiable` con
  `id: String`, `openedAt: Double`, `expiresAt: Double`, `presented: Bool`.
- Produces: `public struct OffersState: Codable, Sendable, Equatable` con `active: [ActiveOffer]`,
  `lastClosedAt: [String: Double]`, `everOpened: Set<String>`, `purchases: [String: Int]`,
  `seenPrestigeLevel: Int?`, `seenUnlockedFloors: Int?`, `static let initial`,
  `static func resolve(winner:loser:)`.
- Produces: `EngagementState.shop: ShopState`, `.offers: OffersState`, `.firstLaunchDay: String?`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "public var\|decodeIfPresent\|resolved\." Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
Anotá los campos que ya tiene (E3b T9, E4a T3, E5): esta tarea los **conserva** en el `init`,
en el `init(from:)` y en `resolve`, y suma los suyos al final. Si E5 todavía no sumó los suyos,
igual se puede correr (las dos tareas escriben las mismas tres funciones: el controlador integra
de a una).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/ShopOffersStateTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// La tienda de ORO y las ofertas de 24 h recuerdan en `meta.engagement`
/// (PLAN-v2 E6), sin subir el schema del save.
@Suite("EngagementState: tienda y ofertas")
struct ShopOffersStateTests {
    @Test("un engagement escrito antes de E6 decodifica con los tres en su estado inicial")
    func decodesWithoutTheKeys() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.shop == .initial)
        #expect(state.offers == .initial)
        #expect(state.firstLaunchDay == nil)
    }

    @Test("un estado a medias también decodifica")
    func partialStatesDecode() throws {
        let json = #"{"shop": {"levels": {"better_supplier": 2}}, "offers": {"everOpened": ["bienvenida"]}}"#
        let state = try JSONDecoder().decode(EngagementState.self, from: Data(json.utf8))
        #expect(state.shop.levels == ["better_supplier": 2])
        #expect(state.shop.purchasesToday.isEmpty)
        #expect(state.shop.skins.isEmpty)
        #expect(state.offers.everOpened == ["bienvenida"])
        #expect(state.offers.active.isEmpty)
        #expect(state.offers.seenPrestigeLevel == nil, "sin línea de base: la toma el motor la primera vez")
    }

    @Test("ida y vuelta, adentro del save entero")
    func roundTripInsideTheSave() throws {
        var player = fxState()
        player.meta.engagement.shop = ShopState(
            day: "2026-10-07", purchasesToday: ["income_x2": 2], levels: ["wheel_spins": 1],
            pendingOfflineMultiplier: 3, pendingDailyMultiplier: nil, skins: ["neon"]
        )
        player.meta.engagement.offers = OffersState(
            active: [ActiveOffer(id: "renacer", openedAt: 100, expiresAt: 86_500, presented: false)],
            lastClosedAt: ["mudanza": 50], everOpened: ["renacer", "mudanza"], purchases: ["mudanza": 1],
            seenPrestigeLevel: 2, seenUnlockedFloors: 3
        )
        player.meta.engagement.firstLaunchDay = "2026-10-06"
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(player))
        #expect(decoded.meta.engagement == player.meta.engagement)
    }

    @Test("otro día: los topes vuelven a cero y lo demás queda")
    func anotherDayResetsTheCaps() {
        let shop = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 3], levels: ["better_supplier": 1],
                             pendingOfflineMultiplier: 3)
        let tomorrow = shop.on(day: "2026-10-08")
        #expect(tomorrow.day == "2026-10-08")
        #expect(tomorrow.purchasesToday.isEmpty)
        #expect(tomorrow.levels == ["better_supplier": 1])
        #expect(tomorrow.pendingOfflineMultiplier == 3, "lo comprado espera su offline, no vence con el día")
        #expect(shop.on(day: "2026-10-07") == shop)
    }

    @Test("al resolver un conflicto, lo comprado no retrocede")
    func resolveKeepsWhatWasBought() {
        let winner = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 1], levels: ["better_supplier": 1],
                               pendingOfflineMultiplier: nil, pendingDailyMultiplier: 3, skins: ["neon"])
        let loser = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 2, "merge_all": 1],
                              levels: ["better_supplier": 2, "wheel_spins": 1], pendingOfflineMultiplier: 3,
                              skins: ["pijama"])
        let resolved = ShopState.resolve(winner: winner, loser: loser)
        #expect(resolved.levels == ["better_supplier": 2, "wheel_spins": 1])
        #expect(resolved.skins == ["neon", "pijama"])
        #expect(resolved.pendingOfflineMultiplier == 3)
        #expect(resolved.pendingDailyMultiplier == 3)
        #expect(resolved.purchasesToday == ["income_x2": 2, "merge_all": 1], "dos dispositivos no duplican el cupo")
    }

    @Test("el cupo de otro día no cuenta")
    func resolveIgnoresAnotherDaysCaps() {
        let winner = ShopState(day: "2026-10-08", purchasesToday: ["income_x2": 1])
        let loser = ShopState(day: "2026-10-07", purchasesToday: ["income_x2": 3])
        #expect(ShopState.resolve(winner: winner, loser: loser).purchasesToday == ["income_x2": 1])
    }

    @Test("ofertas: las abiertas viajan con el ganador; lo usado y lo comprado, unidos")
    func resolveOffers() {
        let winner = OffersState(
            active: [ActiveOffer(id: "renacer", openedAt: 10, expiresAt: 100, presented: true)],
            lastClosedAt: ["mudanza": 5], everOpened: ["renacer"], purchases: [:],
            seenPrestigeLevel: 3, seenUnlockedFloors: 2
        )
        let loser = OffersState(
            active: [], lastClosedAt: ["mudanza": 50, "renacer": 7], everOpened: ["bienvenida"],
            purchases: ["bienvenida": 1], seenPrestigeLevel: 1, seenUnlockedFloors: 5
        )
        let resolved = OffersState.resolve(winner: winner, loser: loser)
        #expect(resolved.active == winner.active)
        #expect(resolved.lastClosedAt == ["mudanza": 50, "renacer": 7])
        #expect(resolved.everOpened == ["renacer", "bienvenida"], "la de una vez no vuelve por el otro dispositivo")
        #expect(resolved.purchases == ["bienvenida": 1])
        #expect(resolved.seenPrestigeLevel == 3)
        #expect(resolved.seenUnlockedFloors == 2)
    }

    @Test("el primer día es el más viejo de los dos")
    func resolveFirstLaunchDay() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.firstLaunchDay = "2026-10-08"
        loser.firstLaunchDay = "2026-10-06"
        #expect(EngagementState.resolve(winner: winner, loser: loser).firstLaunchDay == "2026-10-06")
        loser.firstLaunchDay = nil
        #expect(EngagementState.resolve(winner: winner, loser: loser).firstLaunchDay == "2026-10-08")
    }

    @Test("EngagementState.resolve usa las reglas de la tienda y de las ofertas")
    func engagementResolveDelegates() {
        var winner = EngagementState.initial
        var loser = EngagementState.initial
        winner.shop = ShopState(levels: ["wheel_spins": 1])
        loser.shop = ShopState(levels: ["wheel_spins": 3])
        loser.offers = OffersState(everOpened: ["bienvenida"])
        let resolved = EngagementState.resolve(winner: winner, loser: loser)
        #expect(resolved.shop.levels == ["wheel_spins": 3])
        #expect(resolved.offers.everOpened == ["bienvenida"])
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter ShopOffersStateTests`
Expected: no compila (`ShopState` no existe).

- [ ] **Step 3: La implementación**

`Packages/EconomyKit/Sources/EconomyKit/Shop/ShopState.swift`:

```swift
import Foundation

/// Lo que se recuerda de la tienda de ORO (PLAN-v2 E6): los topes del día, los
/// niveles de los permanentes, los multiplicadores comprados que esperan su
/// próximo offline o diario, y las pintas compradas con ORO.
public struct ShopState: Codable, Sendable, Equatable {
    /// El día calendario ("yyyy-MM-dd") de `purchasesToday`.
    public var day: String?
    /// Compras de hoy por ítem: los topes diarios y el ×1,25 del salto de 1 h.
    public var purchasesToday: [String: Int]
    /// Nivel comprado de cada permanente (sin clave = no comprado).
    public var levels: [String: Int]
    /// El próximo offline con popup se multiplica por esto (Offline ×3).
    public var pendingOfflineMultiplier: Double?
    /// El próximo diario que paga plata se multiplica por esto (Diario ×3).
    public var pendingDailyMultiplier: Double?
    /// Pintas compradas con ORO. Viven acá y no en `meta.ownedSkins`, que es la
    /// caché de StoreKit y se reescribe entera en cada sincronización.
    public var skins: Set<String>

    public static let initial = ShopState()

    public init(
        day: String? = nil,
        purchasesToday: [String: Int] = [:],
        levels: [String: Int] = [:],
        pendingOfflineMultiplier: Double? = nil,
        pendingDailyMultiplier: Double? = nil,
        skins: Set<String> = []
    ) {
        self.day = day
        self.purchasesToday = purchasesToday
        self.levels = levels
        self.pendingOfflineMultiplier = pendingOfflineMultiplier
        self.pendingDailyMultiplier = pendingDailyMultiplier
        self.skins = skins
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decodeIfPresent(String.self, forKey: .day)
        purchasesToday = try container.decodeIfPresent([String: Int].self, forKey: .purchasesToday) ?? [:]
        levels = try container.decodeIfPresent([String: Int].self, forKey: .levels) ?? [:]
        pendingOfflineMultiplier = try container.decodeIfPresent(Double.self, forKey: .pendingOfflineMultiplier)
        pendingDailyMultiplier = try container.decodeIfPresent(Double.self, forKey: .pendingDailyMultiplier)
        skins = try container.decodeIfPresent(Set<String>.self, forKey: .skins) ?? []
    }

    /// El estado visto desde `today`: en otro día los topes vuelven a cero. Lo
    /// comprado (niveles, pintas, ×3 pendientes) no vence con el día.
    public func on(day today: String) -> ShopState {
        guard day != today else { return self }
        var fresh = self
        fresh.day = today
        fresh.purchasesToday = [:]
        return fresh
    }

    /// Lo comprado no retrocede: niveles al más alto, pintas unidas y el ×3
    /// pendiente de cualquiera de los dos. Los topes, si los dos saves hablan
    /// del mismo día, se quedan con lo más alto: dos dispositivos no duplican
    /// el cupo.
    public static func resolve(winner: ShopState, loser: ShopState) -> ShopState {
        var resolved = winner
        resolved.levels = winner.levels.merging(loser.levels, uniquingKeysWith: max)
        resolved.skins = winner.skins.union(loser.skins)
        resolved.pendingOfflineMultiplier = winner.pendingOfflineMultiplier ?? loser.pendingOfflineMultiplier
        resolved.pendingDailyMultiplier = winner.pendingDailyMultiplier ?? loser.pendingDailyMultiplier
        if winner.day != nil, winner.day == loser.day {
            resolved.purchasesToday = winner.purchasesToday.merging(loser.purchasesToday, uniquingKeysWith: max)
        }
        return resolved
    }
}
```

`Packages/EconomyKit/Sources/EconomyKit/Offers/OffersState.swift`:

```swift
import Foundation

/// Una oferta de 24 h abierta (PLAN-v2 E6). El reloj es de pared: lo decidió el
/// dueño ("reloj real de 24 h que no se reinicia al volver a dispararse").
public struct ActiveOffer: Codable, Sendable, Equatable, Identifiable {
    /// El id de la oferta en `offers.json`.
    public let id: String
    public let openedAt: Double
    public let expiresAt: Double
    /// Ya se mostró sola su única vez (la hoja que aparece al abrirse).
    public var presented: Bool

    public init(id: String, openedAt: Double, expiresAt: Double, presented: Bool) {
        self.id = id
        self.openedAt = openedAt
        self.expiresAt = expiresAt
        self.presented = presented
    }
}

/// Lo que se recuerda de las ofertas: las abiertas, cuándo cerró cada una (el
/// enfriamiento cuenta desde ahí), las que ya se usaron y las líneas de base de
/// los disparadores.
public struct OffersState: Codable, Sendable, Equatable {
    public var active: [ActiveOffer]
    /// Cuándo cerró por última vez cada oferta: venció o se compró.
    public var lastClosedAt: [String: Double]
    /// Las que se abrieron alguna vez: las de una sola vez por cuenta no vuelven.
    public var everOpened: Set<String>
    public var purchases: [String: Int]
    /// La línea de base de "al reencarnar": un prestigio que ya se vio no dispara.
    public var seenPrestigeLevel: Int?
    /// La de "piso nuevo": la cantidad de pisos abiertos en la run.
    public var seenUnlockedFloors: Int?

    public static let initial = OffersState()

    public init(
        active: [ActiveOffer] = [],
        lastClosedAt: [String: Double] = [:],
        everOpened: Set<String> = [],
        purchases: [String: Int] = [:],
        seenPrestigeLevel: Int? = nil,
        seenUnlockedFloors: Int? = nil
    ) {
        self.active = active
        self.lastClosedAt = lastClosedAt
        self.everOpened = everOpened
        self.purchases = purchases
        self.seenPrestigeLevel = seenPrestigeLevel
        self.seenUnlockedFloors = seenUnlockedFloors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decodeIfPresent([ActiveOffer].self, forKey: .active) ?? []
        lastClosedAt = try container.decodeIfPresent([String: Double].self, forKey: .lastClosedAt) ?? [:]
        everOpened = try container.decodeIfPresent(Set<String>.self, forKey: .everOpened) ?? []
        purchases = try container.decodeIfPresent([String: Int].self, forKey: .purchases) ?? [:]
        seenPrestigeLevel = try container.decodeIfPresent(Int.self, forKey: .seenPrestigeLevel)
        seenUnlockedFloors = try container.decodeIfPresent(Int.self, forKey: .seenUnlockedFloors)
    }

    /// Las abiertas y las líneas de base viajan con el ganador (son del estado de
    /// ese dispositivo). Lo usado y lo comprado, unido: una oferta de una vez que
    /// se abrió en el otro dispositivo no vuelve, y su enfriamiento tampoco se pierde.
    public static func resolve(winner: OffersState, loser: OffersState) -> OffersState {
        var resolved = winner
        resolved.lastClosedAt = winner.lastClosedAt.merging(loser.lastClosedAt, uniquingKeysWith: max)
        resolved.everOpened = winner.everOpened.union(loser.everOpened)
        resolved.purchases = winner.purchases.merging(loser.purchases, uniquingKeysWith: max)
        return resolved
    }
}
```

`EngagementState.swift`: los tres campos nuevos van **después** de los que ya tiene (los de abajo
marcados `// ya estaba` son el ejemplo con E3b T9 y E4a T3; se conservan los que el paso 0
encontró, también los de E5):

```swift
    // … los campos que ya estaban (sharedMoments, visitors, events, los de E5) …
    /// La tienda de ORO: topes del día, permanentes, ×3 pendientes y pintas de ORO (E6).
    public var shop: ShopState
    /// Las ofertas de 24 h (E6).
    public var offers: OffersState
    /// El día del primer arranque con la 2.0 ("yyyy-MM-dd"). Para un veterano de
    /// la v1 es el día que actualizó: la oferta de Bienvenida es del 2º día (E6).
    public var firstLaunchDay: String?
```

En el `init(...)` memberwise, tres parámetros más al final, con default:

```swift
        shop: ShopState = .initial,
        offers: OffersState = .initial,
        firstLaunchDay: String? = nil
```

y sus tres asignaciones. En `init(from:)`, al final:

```swift
        shop = try container.decodeIfPresent(ShopState.self, forKey: .shop) ?? .initial
        offers = try container.decodeIfPresent(OffersState.self, forKey: .offers) ?? .initial
        firstLaunchDay = try container.decodeIfPresent(String.self, forKey: .firstLaunchDay)
```

y en `resolve(winner:loser:)`, antes del `return`:

```swift
        resolved.shop = ShopState.resolve(winner: winner.shop, loser: loser.shop)
        resolved.offers = OffersState.resolve(winner: winner.offers, loser: loser.offers)
        resolved.firstLaunchDay = [winner.firstLaunchDay, loser.firstLaunchDay].compactMap { $0 }.min()
```

(Si `resolve` todavía es `winner` a secas —ninguna épica le sumó campos—, se reescribe como
`var resolved = winner` + las tres líneas + `return resolved`.)

- [ ] **Step 4: Verde**

Run: `swift test --package-path Packages/EconomyKit` → PASS, con `ShopOffersStateTests` (9) y las
suites del save (`SaveCompatibilityTests`, `SaveConflictResolverTests`, `EngagementStateTests`,
`EngagementStageStateTests`) sin cambios. `Tools/v2/oraculo.sh rapido` → `VERDE` (la cuenta de
`economykit` sube 9).

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Shop/ShopState.swift \
  Packages/EconomyKit/Sources/EconomyKit/Offers/OffersState.swift \
  Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/ShopOffersStateTests.swift
git diff --cached --stat
git commit -m "feat(save): la tienda de ORO y las ofertas recuerdan en meta.engagement"
```

---

### Task 2: El catálogo de la tienda de ORO y sus cuentas, puros

**Objetivo:** `oro_shop.json` como tipo validado y las cuatro preguntas de la tienda en
EconomyKit: qué se ve (lo entregable, el piso alcanzado, el azar sólo donde se permite), cuánto
cuesta hoy (×1,25 por compra del día en el salto de 1 h; el precio del nivel en los
permanentes), qué lo bloquea (no alcanza, tope del día, ya hay uno pendiente, al máximo, nada que
hacer) y qué pasa al comprar (`spendOro` y los contadores, nada más). Los premios los entrega la
app (T6), porque `grant` es de la app.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/OroShopCatalogTests.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/OroShopTests.swift`

**Interfaces:**
- Consumes: `ShopState` (T1); `RewardSpec`, `RewardSpec.Kind`, `validate()` (**E4a T1**);
  `MetaState.spendOro` (E1 T4).
- Produces: `public struct OroShopCatalog: Codable, Sendable, Equatable` con `Shelf`
  (`boosts`, `shortcuts`, `permanents`, `luck`), `Perk` (`extraSlots`, `bestSupplier`,
  `wheelDailySpins`), `Action` (`mergeAll`), `Level { price: Int; value: Double }`, `Item`
  (`id`, `shelf`, `iconKey`, `symbol`, `price: Int?`, `dailyLimit: Int?`,
  `priceGrowthPerPurchase: Double?`, `rewards: [RewardSpec]`, `action: Action?`, `perk: Perk?`,
  `levels: [Level]`, `isChance: Bool`, `unlockFloorId: String?`, `isPermanent`),
  `item(id:)`, `validate(floorIDs:)`, `ValidationError`.
- Produces: `public enum OroShop` con `Context`, `Blocker`, `Quote`, `PurchaseError`, `Purchase`,
  `visibleItems(catalog:context:)`, `quote(_:state:context:)`,
  `purchase(_:state:catalog:context:) throws -> Purchase`, `extraSlots(levels:catalog:) -> Int`,
  `bestSupplierLevel(levels:catalog:) -> Int` (el nivel que lee `PackagesConfig.tierRatio(bestSupplierLevel:)`
  de E5a: el `r` es dato de E5, la tienda sólo vende el nivel),
  `bonusDailyWheelSpins(levels:catalog:) -> Int`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "public enum RewardSpec\|public func validate" Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift`
(E4a T1) y `grep -n "public struct ShopState" -r Packages/EconomyKit/Sources` (T1). Si falta
alguno, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/OroShopCatalogTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("oro_shop.json: el catálogo y su validador")
struct OroShopCatalogTests {
    static let json = """
    {
      "schemaVersion": 1,
      "items": [
        {"id": "income_x2", "shelf": "boosts", "iconKey": "ui_shop_x2", "symbol": "chart.line.uptrend.xyaxis",
         "price": 30, "dailyLimit": 3,
         "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 1800}]},
        {"id": "time_jump_1h", "shelf": "shortcuts", "iconKey": "ui_shop_jump1", "symbol": "forward.fill",
         "price": 90, "dailyLimit": 2, "priceGrowthPerPurchase": 1.25,
         "rewards": [{"kind": "coinsSeconds", "seconds": 3600}]},
        {"id": "merge_all", "shelf": "shortcuts", "iconKey": "ui_shop_mergeall", "symbol": "arrow.triangle.merge",
         "price": 20, "dailyLimit": 5, "action": "mergeAll"},
        {"id": "better_supplier", "shelf": "permanents", "iconKey": "ui_shop_supplier", "symbol": "shippingbox.fill",
         "perk": "bestSupplier",
         "levels": [{"price": 150, "value": 1}, {"price": 400, "value": 2}, {"price": 1000, "value": 3}]},
        {"id": "skin_chest", "shelf": "luck", "iconKey": "ui_shop_chest", "symbol": "gift.fill",
         "price": 45, "isChance": true, "rewards": [{"kind": "skinChest", "count": 1}]}
      ]
    }
    """

    static func catalog() throws -> OroShopCatalog {
        try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
    }

    @Test("se lee la forma del JSON, con sus defaults")
    func decodes() throws {
        let catalog = try Self.catalog()
        #expect(catalog.items.map(\.id) == ["income_x2", "time_jump_1h", "merge_all", "better_supplier", "skin_chest"])
        let x2 = try #require(catalog.item(id: "income_x2"))
        #expect(x2.rewards == [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 1800)])
        #expect(x2.levels.isEmpty)
        #expect(!x2.isChance)
        #expect(!x2.isPermanent)
        let supplier = try #require(catalog.item(id: "better_supplier"))
        #expect(supplier.isPermanent)
        #expect(supplier.levels.map(\.price) == [150, 400, 1000])
        #expect(throws: Never.self) { try catalog.validate(floorIDs: ["alley"]) }
    }

    private func rejects(_ item: String, with error: OroShopCatalog.ValidationError) throws {
        let json = #"{"schemaVersion": 1, "items": [\#(item)]}"#
        let catalog = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        #expect(throws: error) { try catalog.validate(floorIDs: ["alley"]) }
    }

    @Test("un ítem que no da nada no entra")
    func emptyItem() throws {
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 10}"#, with: .emptyItem("x"))
    }

    @Test("un consumible que además es permanente no entra")
    func mixedKinds() throws {
        try rejects(
            #"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 10, "perk": "bestSupplier", "levels": [{"price": 1, "value": 1}], "rewards": [{"kind": "oro", "amount": 1}]}"#,
            with: .mixedKinds("x")
        )
    }

    @Test("precios, topes y crecimiento tienen que tener sentido")
    func numbers() throws {
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 0, "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .nonPositivePrice("x"))
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "dailyLimit": 0, "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .invalidLimit("x"))
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "priceGrowthPerPurchase": 0.9, "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .invalidGrowth("x"))
        try rejects(#"{"id": "x", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "bestSupplier", "levels": [{"price": 400, "value": 1}, {"price": 150, "value": 2}]}"#,
                    with: .descendingPrices("x"))
    }

    @Test("un premio inválido o un piso desconocido no entran")
    func references() throws {
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "rewards": [{"kind": "coinsSeconds", "seconds": 0}]}"#,
                    with: .badReward("x"))
        try rejects(#"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "unlockFloorId": "luna", "rewards": [{"kind": "oro", "amount": 1}]}"#,
                    with: .unknownFloor("luna"))
    }

    @Test("ids repetidos no entran")
    func duplicates() throws {
        let item = #"{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "rewards": [{"kind": "oro", "amount": 1}]}"#
        let catalog = try JSONDecoder().decode(OroShopCatalog.self, from: Data(#"{"schemaVersion": 1, "items": [\#(item), \#(item)]}"#.utf8))
        #expect(throws: OroShopCatalog.ValidationError.duplicateID("x")) { try catalog.validate(floorIDs: []) }
    }
}
```

`Packages/EconomyKit/Tests/EconomyKitTests/OroShopTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("La tienda de ORO: qué se ve, cuánto cuesta, qué lo bloquea y qué se compra")
struct OroShopTests {
    let catalog: OroShopCatalog

    init() throws {
        catalog = try OroShopCatalogTests.catalog()
    }

    private func context(
        today: String = "2026-10-07",
        grantable: Set<RewardSpec.Kind> = Set(RewardSpec.Kind.allCases),
        chanceAllowed: Bool = true,
        reached: Set<String> = ["alley"],
        mergeAllPairs: Int = 3,
        anyBoostCoolingDown: Bool = true,
        chestHasSomethingToGive: Bool = true,
        perks: Set<OroShopCatalog.Perk> = Set(OroShopCatalog.Perk.allCases)
    ) -> OroShop.Context {
        OroShop.Context(
            today: today, grantableKinds: grantable, chanceAllowed: chanceAllowed, reachedFloorIds: reached,
            mergeAllPairs: mergeAllPairs, anyBoostCoolingDown: anyBoostCoolingDown,
            chestHasSomethingToGive: chestHasSomethingToGive, supportedPerks: perks
        )
    }

    private func rich(_ oro: Int = 10_000) -> PlayerState {
        var state = fxState()
        state.meta.oro = oro
        return state
    }

    private func item(_ id: String) throws -> OroShopCatalog.Item {
        try #require(catalog.item(id: id))
    }

    @Test("se ve lo que se puede entregar; el azar, sólo donde se permite")
    func visibility() throws {
        #expect(OroShop.visibleItems(catalog: catalog, context: context()).map(\.id)
                == ["income_x2", "time_jump_1h", "merge_all", "better_supplier", "skin_chest"])
        let restricted = OroShop.visibleItems(catalog: catalog, context: context(chanceAllowed: false)).map(\.id)
        #expect(!restricted.contains("skin_chest"), "Bélgica y Australia: el azar con ORO se apaga")
        let noChests = OroShop.visibleItems(catalog: catalog, context: context(grantable: [.coinsSeconds, .modifier])).map(\.id)
        #expect(!noChests.contains("skin_chest"), "lo que la app no sabe entregar no se vende")
        let noPerk = OroShop.visibleItems(catalog: catalog, context: context(perks: [])).map(\.id)
        #expect(!noPerk.contains("better_supplier"), "un permanente sin quien lo lea no se vende")
    }

    @Test("el salto de 1 h sube ×1,25 por compra del día y vuelve al otro día")
    func priceGrowsWithinTheDay() throws {
        var state = rich()
        let jump = try item("time_jump_1h")
        #expect(OroShop.quote(jump, state: state, context: context()).price == 90)
        _ = try OroShop.purchase("time_jump_1h", state: &state, catalog: catalog, context: context())
        #expect(OroShop.quote(jump, state: state, context: context()).price == 113, "90 × 1,25 = 112,5 → 113")
        _ = try OroShop.purchase("time_jump_1h", state: &state, catalog: catalog, context: context())
        let capped = OroShop.quote(jump, state: state, context: context())
        #expect(capped.blocker == .dailyLimitReached)
        #expect(capped.boughtToday == 2)
        let tomorrow = OroShop.quote(jump, state: state, context: context(today: "2026-10-08"))
        #expect(tomorrow.price == 90)
        #expect(tomorrow.blocker == nil)
    }

    @Test("comprar gasta ORO por spendOro, nunca el ORO de por vida")
    func purchaseSpends() throws {
        var state = rich(100)
        state.meta.oroEarnedLifetime = 500
        let purchase = try OroShop.purchase("income_x2", state: &state, catalog: catalog, context: context())
        #expect(purchase.price == 30)
        #expect(purchase.item.id == "income_x2")
        #expect(state.meta.oro == 70)
        #expect(state.meta.stats.oroSpentEver == 30)
        #expect(state.meta.oroEarnedLifetime == 500, "gastar no nerfea el multiplicador")
        #expect(state.meta.engagement.shop.purchasesToday == ["income_x2": 1])
        #expect(state.meta.engagement.shop.day == "2026-10-07")
    }

    @Test("sin ORO, no compra ni toca nada")
    func cantAfford() throws {
        var state = rich(10)
        let before = state
        #expect(OroShop.quote(try item("income_x2"), state: state, context: context()).blocker == .cantAfford)
        #expect(throws: OroShop.PurchaseError.blocked(.cantAfford)) {
            try OroShop.purchase("income_x2", state: &state, catalog: catalog, context: context())
        }
        #expect(state == before)
    }

    @Test("los permanentes suben de a un nivel y paran en el máximo")
    func permanents() throws {
        var state = rich()
        let supplier = try item("better_supplier")
        #expect(OroShop.bestSupplierLevel(levels: state.meta.engagement.shop.levels, catalog: catalog) == 0)
        for price in [150, 400, 1000] {
            #expect(OroShop.quote(supplier, state: state, context: context()).price == price)
            let purchase = try OroShop.purchase("better_supplier", state: &state, catalog: catalog, context: context())
            #expect(purchase.newLevel == [150, 400, 1000].firstIndex(of: price)! + 1)
        }
        let maxed = OroShop.quote(supplier, state: state, context: context())
        #expect(maxed.price == nil)
        #expect(maxed.blocker == .maxed)
        #expect(maxed.level == 3)
        #expect(OroShop.bestSupplierLevel(levels: state.meta.engagement.shop.levels, catalog: catalog) == 3)
        #expect(state.meta.engagement.shop.purchasesToday.isEmpty, "un permanente no gasta cupo del día")
    }

    @Test("lo que no tiene nada que hacer no cobra")
    func nothingToDo() throws {
        var state = rich()
        #expect(OroShop.quote(try item("merge_all"), state: state, context: context(mergeAllPairs: 0)).blocker == .nothingToDo)
        #expect(OroShop.quote(try item("skin_chest"), state: state, context: context(chestHasSomethingToGive: false)).blocker == .nothingToDo)
        #expect(throws: OroShop.PurchaseError.blocked(.nothingToDo)) {
            try OroShop.purchase("merge_all", state: &state, catalog: catalog, context: context(mergeAllPairs: 0))
        }
        #expect(state.meta.oro == 10_000)
    }

    @Test("un ítem que no se ve no se compra, aunque alguien lo pida por id")
    func hiddenCantBeBought() throws {
        var state = rich()
        #expect(throws: OroShop.PurchaseError.notOffered) {
            try OroShop.purchase("skin_chest", state: &state, catalog: catalog, context: context(chanceAllowed: false))
        }
        #expect(throws: OroShop.PurchaseError.unknownItem) {
            try OroShop.purchase("nope", state: &state, catalog: catalog, context: context())
        }
    }

    @Test("un ×3 pendiente bloquea comprar otro hasta que se use")
    func pendingMultipliers() throws {
        let json = #"""
        {"schemaVersion": 1, "items": [
          {"id": "offline_x3", "shelf": "shortcuts", "iconKey": "k", "symbol": "s", "price": 120,
           "rewards": [{"kind": "nextOfflineMultiplier", "multiplier": 3}]},
          {"id": "daily_x3", "shelf": "shortcuts", "iconKey": "k", "symbol": "s", "price": 40, "dailyLimit": 1,
           "rewards": [{"kind": "nextDailyMultiplier", "multiplier": 3}]}
        ]}
        """#
        let pending = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        var state = rich()
        state.meta.engagement.shop.pendingOfflineMultiplier = 3
        #expect(OroShop.quote(try #require(pending.item(id: "offline_x3")), state: state, context: context()).blocker == .alreadyPending)
        #expect(OroShop.quote(try #require(pending.item(id: "daily_x3")), state: state, context: context()).blocker == nil)
        state.meta.engagement.shop.pendingDailyMultiplier = 3
        #expect(OroShop.quote(try #require(pending.item(id: "daily_x3")), state: state, context: context()).blocker == .alreadyPending)
    }

    @Test("los perks salen de los niveles: los lugares se suman, el resto es el del nivel")
    func perks() throws {
        let json = #"""
        {"schemaVersion": 1, "items": [
          {"id": "extra_slots", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "extraSlots",
           "levels": [{"price": 600, "value": 3}, {"price": 1500, "value": 2}]},
          {"id": "wheel_spins", "shelf": "permanents", "iconKey": "k", "symbol": "s", "perk": "wheelDailySpins",
           "levels": [{"price": 120, "value": 1}, {"price": 300, "value": 2}, {"price": 750, "value": 3}]}
        ]}
        """#
        let perks = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        #expect(OroShop.extraSlots(levels: [:], catalog: perks) == 0)
        #expect(OroShop.extraSlots(levels: ["extra_slots": 1], catalog: perks) == 3)
        #expect(OroShop.extraSlots(levels: ["extra_slots": 2], catalog: perks) == 5)
        #expect(OroShop.extraSlots(levels: ["extra_slots": 9], catalog: perks) == 5, "un nivel de más en el save no inventa lugares")
        #expect(OroShop.bonusDailyWheelSpins(levels: ["wheel_spins": 2], catalog: perks) == 2)
        #expect(OroShop.bonusDailyWheelSpins(levels: [:], catalog: perks) == 0)
    }

    @Test("un ítem de piso no se ve hasta llegar")
    func unlockFloor() throws {
        let json = #"{"schemaVersion": 1, "items": [{"id": "x", "shelf": "boosts", "iconKey": "k", "symbol": "s", "price": 5, "unlockFloorId": "urban", "rewards": [{"kind": "oro", "amount": 1}]}]}"#
        let gated = try JSONDecoder().decode(OroShopCatalog.self, from: Data(json.utf8))
        #expect(OroShop.visibleItems(catalog: gated, context: context(reached: ["alley"])).isEmpty)
        #expect(OroShop.visibleItems(catalog: gated, context: context(reached: ["alley", "urban"])).map(\.id) == ["x"])
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "OroShopCatalogTests|OroShopTests"`
Expected: no compila (`OroShopCatalog` no existe).

- [ ] **Step 3: El catálogo**

`Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift`:

```swift
import Foundation

/// La tienda de ORO como dato (`oro_shop.json`, PLAN-v2 E6). Un ítem es una de dos
/// cosas: un **consumible** (precio, premios o una acción, tope por día) o un
/// **permanente** (un perk con niveles, cada uno con su precio y su valor).
/// Los cosméticos no viven acá: son skins con `oroPrice` en `skins.json` (E6b).
public struct OroShopCatalog: Codable, Sendable, Equatable {
    public enum Shelf: String, Codable, Sendable, CaseIterable {
        case boosts, shortcuts, permanents, luck
    }

    /// Lo que un permanente cambia del juego. Lo lee quien lo usa, desde los niveles.
    public enum Perk: String, Codable, Sendable, CaseIterable {
        /// Lugares extra por piso (E6b). Los valores de los niveles se SUMAN.
        case extraSlots
        /// "Mejor proveedor" del Paquete de la Aduana (E5). Manda el valor del nivel,
        /// que ES el nivel: el `r` de cada uno vive en `packages.json` (E5a T1).
        case bestSupplier
        /// Giros por video de más por día en la ruleta (E5). Manda el valor del nivel.
        case wheelDailySpins
    }

    public enum Action: String, Codable, Sendable {
        /// "Fusionar todo" sobre el piso visible, por el embudo de E1.
        case mergeAll
    }

    public struct Level: Codable, Sendable, Equatable {
        public let price: Int
        public let value: Double

        public init(price: Int, value: Double) {
            self.price = price
            self.value = value
        }
    }

    public struct Item: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let shelf: Shelf
        /// Clave del arte del ícono (E8). Sin arte, la vista dibuja `symbol`.
        public let iconKey: String
        /// SF Symbol de respaldo mientras no llega el ícono.
        public let symbol: String
        /// Consumibles: el precio de la primera compra del día.
        public let price: Int?
        public let dailyLimit: Int?
        /// Cada compra del día multiplica el precio por esto (el salto de 1 h: 1,25).
        public let priceGrowthPerPurchase: Double?
        public let rewards: [RewardSpec]
        public let action: Action?
        public let perk: Perk?
        public let levels: [Level]
        /// Azar pagado con ORO (Apple 3.1.1): probabilidades a la vista y apagado en
        /// las tiendas restringidas.
        public let isChance: Bool
        /// Desde qué piso alcanzado en la cuenta aparece.
        public let unlockFloorId: String?

        public var isPermanent: Bool { perk != nil }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            shelf = try container.decode(Shelf.self, forKey: .shelf)
            iconKey = try container.decode(String.self, forKey: .iconKey)
            symbol = try container.decode(String.self, forKey: .symbol)
            price = try container.decodeIfPresent(Int.self, forKey: .price)
            dailyLimit = try container.decodeIfPresent(Int.self, forKey: .dailyLimit)
            priceGrowthPerPurchase = try container.decodeIfPresent(Double.self, forKey: .priceGrowthPerPurchase)
            rewards = try container.decodeIfPresent([RewardSpec].self, forKey: .rewards) ?? []
            action = try container.decodeIfPresent(Action.self, forKey: .action)
            perk = try container.decodeIfPresent(Perk.self, forKey: .perk)
            levels = try container.decodeIfPresent([Level].self, forKey: .levels) ?? []
            isChance = try container.decodeIfPresent(Bool.self, forKey: .isChance) ?? false
            unlockFloorId = try container.decodeIfPresent(String.self, forKey: .unlockFloorId)
        }
    }

    public enum ValidationError: Error, Equatable {
        case duplicateID(String)
        /// Ni premios, ni acción, ni perk: no da nada.
        case emptyItem(String)
        /// Consumible y permanente a la vez, o premios y acción a la vez.
        case mixedKinds(String)
        case nonPositivePrice(String)
        case invalidLimit(String)
        case invalidGrowth(String)
        case descendingPrices(String)
        case badReward(String)
        case unknownFloor(String)
    }

    public let schemaVersion: Int
    public let items: [Item]

    public func item(id: String) -> Item? {
        items.first { $0.id == id }
    }

    public func validate(floorIDs: Set<String>) throws {
        var seen = Set<String>()
        for item in items {
            guard seen.insert(item.id).inserted else { throw ValidationError.duplicateID(item.id) }
            if let floor = item.unlockFloorId, !floorIDs.contains(floor) {
                throw ValidationError.unknownFloor(floor)
            }
            if item.isPermanent {
                guard item.price == nil, item.rewards.isEmpty, item.action == nil, item.dailyLimit == nil else {
                    throw ValidationError.mixedKinds(item.id)
                }
                guard !item.levels.isEmpty else { throw ValidationError.emptyItem(item.id) }
                guard item.levels.allSatisfy({ $0.price > 0 }) else { throw ValidationError.nonPositivePrice(item.id) }
                guard zip(item.levels, item.levels.dropFirst()).allSatisfy({ $0.price < $1.price }) else {
                    throw ValidationError.descendingPrices(item.id)
                }
                continue
            }
            guard item.levels.isEmpty else { throw ValidationError.mixedKinds(item.id) }
            guard !item.rewards.isEmpty || item.action != nil else { throw ValidationError.emptyItem(item.id) }
            guard item.rewards.isEmpty || item.action == nil else { throw ValidationError.mixedKinds(item.id) }
            guard let price = item.price, price > 0 else { throw ValidationError.nonPositivePrice(item.id) }
            if let limit = item.dailyLimit, limit < 1 { throw ValidationError.invalidLimit(item.id) }
            if let growth = item.priceGrowthPerPurchase, !(growth >= 1) { throw ValidationError.invalidGrowth(item.id) }
            do {
                try item.rewards.forEach { try $0.validate() }
            } catch {
                throw ValidationError.badReward(item.id)
            }
        }
    }
}
```

- [ ] **Step 4: Las cuentas**

`Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift`:

```swift
import Foundation

/// Las cuentas de la tienda de ORO (PLAN-v2 E6). Pura: la app le pasa lo que
/// sólo ella sabe (lo que puede entregar, si el azar está permitido en esta
/// tienda, cuántos pares fundiría "Fusionar todo") y entrega los premios ella.
public enum OroShop {
    public struct Context: Sendable, Equatable {
        /// "yyyy-MM-dd", el mismo día del premio diario.
        public let today: String
        /// Lo que la app ya sabe entregar (`GameState.grantableRewardKinds`).
        public let grantableKinds: Set<RewardSpec.Kind>
        /// `false` en las tiendas de `restrictedStorefronts` (Bélgica y Australia).
        public let chanceAllowed: Bool
        /// Los pisos que la cuenta alcanzó alguna vez.
        public let reachedFloorIds: Set<String>
        /// Cuántos pares fundiría "Fusionar todo" ahora en el piso visible.
        public let mergeAllPairs: Int
        /// Hay algún boost esperando su cooldown.
        public let anyBoostCoolingDown: Bool
        /// El cofre de pintas tiene algo para dar hoy (`ChestRoller.hasSomethingToGive`).
        public let chestHasSomethingToGive: Bool
        /// Los perks que alguien lee hoy (el de paquetes necesita E5; el de lugares, E6b).
        public let supportedPerks: Set<OroShopCatalog.Perk>

        public init(
            today: String,
            grantableKinds: Set<RewardSpec.Kind>,
            chanceAllowed: Bool,
            reachedFloorIds: Set<String>,
            mergeAllPairs: Int,
            anyBoostCoolingDown: Bool,
            chestHasSomethingToGive: Bool,
            supportedPerks: Set<OroShopCatalog.Perk>
        ) {
            self.today = today
            self.grantableKinds = grantableKinds
            self.chanceAllowed = chanceAllowed
            self.reachedFloorIds = reachedFloorIds
            self.mergeAllPairs = mergeAllPairs
            self.anyBoostCoolingDown = anyBoostCoolingDown
            self.chestHasSomethingToGive = chestHasSomethingToGive
            self.supportedPerks = supportedPerks
        }
    }

    /// Por qué no se puede comprar AHORA algo que sí se ve. El orden de los casos
    /// es el de prioridad: "al máximo" gana a todo, "no te alcanza" a nada.
    public enum Blocker: Sendable, Equatable {
        case maxed
        case dailyLimitReached
        case alreadyPending
        case nothingToDo
        case cantAfford
    }

    public struct Quote: Sendable, Equatable {
        public let itemId: String
        /// `nil` = al máximo (no hay próximo nivel).
        public let price: Int?
        /// Permanentes: el nivel comprado. Consumibles: 0.
        public let level: Int
        public let boughtToday: Int
        public let blocker: Blocker?
    }

    public enum PurchaseError: Error, Equatable {
        case unknownItem
        case notOffered
        case blocked(Blocker)
    }

    public struct Purchase: Sendable, Equatable {
        public let item: OroShopCatalog.Item
        public let price: Int
        /// Permanentes: el nivel que quedó. Consumibles: `nil`.
        public let newLevel: Int?
    }

    /// Lo que se ofrece hoy, en el orden del catálogo.
    public static func visibleItems(catalog: OroShopCatalog, context: Context) -> [OroShopCatalog.Item] {
        catalog.items.filter { isOffered($0, context: context) }
    }

    public static func quote(_ item: OroShopCatalog.Item, state: PlayerState, context: Context) -> Quote {
        let shop = state.meta.engagement.shop.on(day: context.today)
        let bought = shop.purchasesToday[item.id] ?? 0
        if item.isPermanent {
            let level = shop.levels[item.id] ?? 0
            guard item.levels.indices.contains(level) else {
                return Quote(itemId: item.id, price: nil, level: level, boughtToday: 0, blocker: .maxed)
            }
            let price = item.levels[level].price
            let blocker: Blocker? = state.meta.oro >= price ? nil : .cantAfford
            return Quote(itemId: item.id, price: price, level: level, boughtToday: 0, blocker: blocker)
        }
        let base = Double(item.price ?? 0)
        let price = Int((base * pow(item.priceGrowthPerPurchase ?? 1, Double(bought))).rounded())
        return Quote(itemId: item.id, price: price, level: 0, boughtToday: bought,
                     blocker: consumableBlocker(item, shop: shop, bought: bought, price: price, oro: state.meta.oro, context: context))
    }

    /// Compra: cobra por `MetaState.spendOro` (la única salida de ORO) y anota el
    /// cupo del día o el nivel. NO entrega los premios: eso es de la app.
    @discardableResult
    public static func purchase(
        _ itemId: String,
        state: inout PlayerState,
        catalog: OroShopCatalog,
        context: Context
    ) throws -> Purchase {
        guard let item = catalog.item(id: itemId) else { throw PurchaseError.unknownItem }
        guard isOffered(item, context: context) else { throw PurchaseError.notOffered }
        let quote = quote(item, state: state, context: context)
        if let blocker = quote.blocker { throw PurchaseError.blocked(blocker) }
        guard let price = quote.price, state.meta.spendOro(price) else { throw PurchaseError.blocked(.cantAfford) }

        var shop = state.meta.engagement.shop.on(day: context.today)
        var newLevel: Int?
        if item.isPermanent {
            newLevel = quote.level + 1
            shop.levels[item.id] = newLevel
        } else {
            shop.purchasesToday[item.id, default: 0] += 1
        }
        state.meta.engagement.shop = shop
        return Purchase(item: item, price: price, newLevel: newLevel)
    }

    // MARK: Perks

    /// Lugares extra por piso: la suma de los valores de los niveles comprados.
    public static func extraSlots(levels: [String: Int], catalog: OroShopCatalog) -> Int {
        catalog.items.filter { $0.perk == .extraSlots }.reduce(0) { total, item in
            let level = min(levels[item.id] ?? 0, item.levels.count)
            return total + item.levels.prefix(level).reduce(0) { $0 + Int($1.value) }
        }
    }

    /// El nivel de "mejor proveedor" (0 sin comprar). Lo lee el Paquete de E5a
    /// con `PackagesConfig.tierRatio(bestSupplierLevel:)`: el `r` es dato de E5.
    public static func bestSupplierLevel(levels: [String: Int], catalog: OroShopCatalog) -> Int {
        Int(levelValue(of: .bestSupplier, levels: levels, catalog: catalog) ?? 0)
    }

    /// Giros por video de más por día en la ruleta.
    public static func bonusDailyWheelSpins(levels: [String: Int], catalog: OroShopCatalog) -> Int {
        Int(levelValue(of: .wheelDailySpins, levels: levels, catalog: catalog) ?? 0)
    }

    // MARK: Internals

    private static func levelValue(of perk: OroShopCatalog.Perk, levels: [String: Int], catalog: OroShopCatalog) -> Double? {
        guard let item = catalog.items.first(where: { $0.perk == perk }) else { return nil }
        let level = min(levels[item.id] ?? 0, item.levels.count)
        return level > 0 ? item.levels[level - 1].value : nil
    }

    private static func isOffered(_ item: OroShopCatalog.Item, context: Context) -> Bool {
        if let floor = item.unlockFloorId, !context.reachedFloorIds.contains(floor) { return false }
        if item.isChance, !context.chanceAllowed { return false }
        if let perk = item.perk, !context.supportedPerks.contains(perk) { return false }
        return item.rewards.allSatisfy { isDeliverable($0, grantable: context.grantableKinds) }
    }

    /// Un ritmo de paquetes sin paquetes no es un premio: pide `.package` (el
    /// mismo criterio que los eventos de E4a).
    private static func isDeliverable(_ reward: RewardSpec, grantable: Set<RewardSpec.Kind>) -> Bool {
        guard grantable.contains(reward.kind) else { return false }
        if case .modifier(.packageRateMultiplier, _, _) = reward { return grantable.contains(.package) }
        return true
    }

    private static func consumableBlocker(
        _ item: OroShopCatalog.Item,
        shop: ShopState,
        bought: Int,
        price: Int,
        oro: Int,
        context: Context
    ) -> Blocker? {
        if let limit = item.dailyLimit, bought >= limit { return .dailyLimitReached }
        for reward in item.rewards {
            switch reward {
            case .nextOfflineMultiplier where shop.pendingOfflineMultiplier != nil: return .alreadyPending
            case .nextDailyMultiplier where shop.pendingDailyMultiplier != nil: return .alreadyPending
            case .clearBoostCooldowns where !context.anyBoostCoolingDown: return .nothingToDo
            case .skinChest where !context.chestHasSomethingToGive: return .nothingToDo
            default: continue
            }
        }
        if item.action == .mergeAll, context.mergeAllPairs == 0 { return .nothingToDo }
        return oro >= price ? nil : .cantAfford
    }
}
```

⚠️ `case .modifier(.packageRateMultiplier, _, _)` necesita el efecto de **E4a T2**; si el
compilador no lo encuentra, la tarea salió antes de tiempo (`NEEDS_CONTEXT`).

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter "OroShopCatalogTests|OroShopTests"` →
PASS (6 + 10). Después `swift test --package-path Packages/EconomyKit` entero → PASS y
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Shop/OroShopCatalog.swift \
  Packages/EconomyKit/Sources/EconomyKit/Shop/OroShop.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/OroShopCatalogTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/OroShopTests.swift
git diff --cached --stat
git commit -m "feat(tienda): el catálogo de ORO y sus cuentas, puros en EconomyKit"
```

---

### Task 3: El auto-tap — toques automáticos al mejor que tenés

**Objetivo:** el único efecto de premio que la 2.0 no tenía: "Auto-tap 10 min" (PLAN-v2 E6;
E4a lo deja explícitamente para E6). Un modificador `autoTapPerSecond` cuya magnitud son toques
por segundo (se **suman**, no se multiplican), y `AutoTapper`, que cobra esos toques sobre el
personaje de tier más alto que tenés, con la misma cuenta que un toque del jugador. No paga
offline (los toques son de juego activo), no cuenta para las estadísticas ni los logros de
toques, y su chip dice lo que cobra (fila nueva en `EffectContractTests`).

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (`Effect` + `ModifierMath.autoTapsPerSecond`)
- Create: `Packages/EconomyKit/Sources/EconomyKit/AutoTapper.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/AutoTapTests.swift`
- Modify: `FisuEvolution/Game/State/ActiveBonus.swift` (`ActiveBonusBuilder.effectText`, `autoTapRateText`)
- Modify: `FisuEvolution/UI/HUD/ActiveBonusBar.swift` (`tint`)
- Modify: `FisuEvolutionTests/EffectContractTests.swift` (`modifierEffects`, una fila)
- Strings: `Tools/v2/claves-pendientes/e6a-t3.json` (1 clave)

**Interfaces:**
- Consumes: `ActiveModifier.Effect: CaseIterable` y `EffectContractTests.modifierEffects` (**E1
  T15**); los efectos de E1 T13, E2a T12 y E4a T2 (filas vecinas del mismo `switch`);
  `StandardEconomy.applyTap(type:state:tiers:floorTable:now:)` (**E2a T4**).
- Produces: `ActiveModifier.Effect.autoTapPerSecond`;
  `ModifierMath.autoTapsPerSecond(_ modifiers: [ActiveModifier], now: TimeInterval) -> Double`;
  `public enum AutoTapper` con `target(state:tiers:) -> CharacterType?` y
  `@discardableResult advance(state:delta:now:tiers:floorTable:economy:) -> Double`;
  `static func ActiveBonusBuilder.autoTapRateText(_ perSecond: Double) -> String`.

- [ ] **Step 0: Pararse en la base**

Run, uno por uno:
`grep -n "CaseIterable" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (E1 T15),
`grep -n "case packageRateMultiplier\|case eventImmunity" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (E4a T2),
`grep -n "func modifierEffects" FisuEvolutionTests/EffectContractTests.swift` (E1 T15) y
`grep -n "tiers: TierRepository" Packages/EconomyKit/Sources/EconomyKit/GameActions.swift` (E2a T4).
Si falta alguno de los tres primeros, `NEEDS_CONTEXT`. Si falta el último (E2a T4 todavía no
sumó `tiers:` a `applyTap`), se borra el argumento `tiers: tiers` / `tiers: content.tiers` de las
llamadas a `applyTap` de esta tarea, y nada más.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/AutoTapTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("El auto-tap: toques automáticos al mejor que tenés")
struct AutoTapTests {
    let tiers: TierRepository
    let floorTable: FloorTable
    let economy = fxEconomy()

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func autoTap(_ perSecond: Double, until expiresAt: TimeInterval = 100) -> ActiveModifier {
        ActiveModifier(effect: .autoTapPerSecond, magnitude: perSecond, expiresAt: expiresAt, sourceKey: "shop.auto_tap")
    }

    @Test("toca al de tier más alto que tenés")
    func targetsTheBest() {
        #expect(AutoTapper.target(state: fxState(units: ["a": 3, "b": 1]), tiers: tiers)?.id == "b")
        #expect(AutoTapper.target(state: fxState(units: [:]), tiers: tiers) == nil)
    }

    @Test("cobra toques por segundo × segundos × lo que paga un toque al mejor")
    func paysTapsTimesSeconds() throws {
        var state = fxState(units: ["a": 1, "b": 1])
        state.run.activeModifiers = [autoTap(5)]
        var probe = state
        let oneTap = economy.applyTap(type: try #require(tiers.type(id: "b")), state: &probe, tiers: tiers,
                                      floorTable: floorTable, now: 10)
        let coins = state.run.coins
        let earned = state.meta.lifetimeEarnings
        let paid = AutoTapper.advance(state: &state, delta: 2, now: 10, tiers: tiers, floorTable: floorTable, economy: economy)
        #expect(abs(paid - oneTap * 5 * 2) < 1e-9 * max(1, paid))
        #expect(abs(state.run.coins - coins - paid) < 1e-9 * max(1, paid))
        #expect(abs(state.meta.lifetimeEarnings - earned - paid) < 1e-9 * max(1, paid))
        #expect(state.meta.stats.totalTapsEver == 0, "los toques automáticos no son del jugador")
    }

    @Test("dos auto-taps se suman; vencido, no paga")
    func ratesAddAndExpire() {
        let modifiers = [autoTap(5, until: 100), autoTap(3, until: 50)]
        #expect(ModifierMath.autoTapsPerSecond(modifiers, now: 10) == 8)
        #expect(ModifierMath.autoTapsPerSecond(modifiers, now: 60) == 5)
        #expect(ModifierMath.autoTapsPerSecond([], now: 0) == 0)
        var state = fxState(units: ["a": 1])
        state.run.activeModifiers = modifiers
        #expect(AutoTapper.advance(state: &state, delta: 1, now: 200, tiers: tiers, floorTable: floorTable, economy: economy) == 0)
    }

    @Test("no toca el pasivo ni los multiplicadores de ingresos")
    func doesNotTouchIncome() {
        var state = fxState(units: ["a": 2])
        state.run.passiveUnlocked["a"] = true
        let passive = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 10)
        state.run.activeModifiers = [autoTap(5)]
        #expect(IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 10) == passive)
        #expect(ModifierMath.factor(state.run.activeModifiers, effect: .incomeMultiplier, now: 10) == 1)
        #expect(ModifierMath.factor(state.run.activeModifiers, effect: .tapMultiplier, now: 10) == 1)
    }

    @Test("sin nadie en el tablero no paga")
    func nobodyToTap() {
        var state = fxState(units: [:])
        state.run.activeModifiers = [autoTap(5)]
        #expect(AutoTapper.advance(state: &state, delta: 1, now: 10, tiers: tiers, floorTable: floorTable, economy: economy) == 0)
    }

    @Test("el efecto se lee de un save que todavía no lo conocía")
    func decodes() throws {
        let json = #"{"id":"6A1D2F3E-0000-0000-0000-000000000001","effect":"autoTapPerSecond","magnitude":5,"expiresAt":600,"sourceKey":"shop.auto_tap"}"#
        #expect(try JSONDecoder().decode(ActiveModifier.self, from: Data(json.utf8)).effect == .autoTapPerSecond)
    }
}
```

En `FisuEvolutionTests/EffectContractTests.swift`, dentro del `switch effect` de `modifierEffects`
(sin `default`; `magnitude` vale 3 para este efecto), la fila nueva:

```swift
            case .autoTapPerSecond:
                #expect(chip == String(localized: "bonus.chip.autotap \(ActiveBonusBuilder.autoTapRateText(magnitude))"))
                #expect(passive(boosted) == passive(plain), "tocar solo no es el pasivo")
                let target = try #require(AutoTapper.target(state: plain, tiers: content.tiers))
                var probe = plain
                let oneTap = economy.applyTap(type: target, state: &probe, tiers: content.tiers,
                                              floorTable: content.floorTable, now: 0)
                let paid = AutoTapper.advance(state: &boosted, delta: 1, now: 0, tiers: content.tiers,
                                              floorTable: content.floorTable, economy: economy)
                #expect(abs(paid - oneTap * magnitude) < 1e-9 * max(1, paid), "el chip dice \(magnitude) por segundo y eso cobra")
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter AutoTapTests`
Expected: no compila (`autoTapPerSecond` no existe).

- [ ] **Step 3: EconomyKit**

`ActiveModifier.swift`, en `enum Effect`, después del último caso que ya esté:

```swift
        /// Toques automáticos por segundo (el auto-tap de la tienda de ORO). La
        /// magnitud son toques, no un factor: dos auto-taps se SUMAN. Lo cobra
        /// `AutoTapper` y no entra en ningún `factor` de ingresos.
        case autoTapPerSecond
```

y en `ModifierMath`:

```swift
    /// Cuántos toques por segundo dan los auto-taps vivos: la suma de sus magnitudes.
    public static func autoTapsPerSecond(_ modifiers: [ActiveModifier], now: TimeInterval) -> Double {
        modifiers
            .filter { $0.effect == .autoTapPerSecond && $0.isActive(at: now) }
            .reduce(0) { $0 + $1.magnitude }
    }
```

`Packages/EconomyKit/Sources/EconomyKit/AutoTapper.swift`:

```swift
import Foundation

/// El auto-tap (PLAN-v2 E6): toques automáticos que pagan como un toque del
/// jugador sobre el personaje de tier más alto que tiene. Sin crítico ni toque
/// dorado (son tiradas del gesto, no del toque) y sin contar para las
/// estadísticas: el que toca es la tienda, no el jugador.
public enum AutoTapper {
    /// El de tier más alto. A igual tier (las ramas de carrera) gana el id, para
    /// que la elección no dependa del orden de un diccionario.
    public static func target(state: PlayerState, tiers: TierRepository) -> CharacterType? {
        state.run.units
            .filter { $0.value > 0 }
            .compactMap { tiers.type(id: $0.key) }
            .filter { !$0.isChoiceNode }
            .max { ($0.tier, $0.id) < ($1.tier, $1.id) }
    }

    /// Cobra `delta` segundos de auto-tap. Devuelve lo cobrado (0 sin auto-tap vivo).
    @discardableResult
    public static func advance(
        state: inout PlayerState,
        delta: TimeInterval,
        now: TimeInterval,
        tiers: TierRepository,
        floorTable: FloorTable,
        economy: StandardEconomy
    ) -> Double {
        let rate = ModifierMath.autoTapsPerSecond(state.run.activeModifiers, now: now)
        guard rate > 0, delta > 0, let type = target(state: state, tiers: tiers) else { return 0 }
        // El toque se cotiza sobre una copia: `applyTap` acredita, y acá se
        // acredita una sola vez el total.
        var probe = state
        let perTap = economy.applyTap(type: type, state: &probe, tiers: tiers, floorTable: floorTable, now: now)
        let paid = perTap * rate * delta
        state.run.coins += paid
        state.meta.lifetimeEarnings += paid
        return paid
    }
}
```

- [ ] **Step 4: La app**

`ActiveBonus.swift`, en el `switch modifier.effect` de `ActiveBonusBuilder.effectText(for:)`
(los casos que ya están se conservan; éste devuelve antes de mapear a un boost):

```swift
        case .autoTapPerSecond:
            return String(localized: "bonus.chip.autotap \(Self.autoTapRateText(modifier.magnitude))")
```

y en `ActiveBonusBuilder`:

```swift
    /// "5" toques por segundo: sin decimales salvo que el dato los traiga. Lo usa
    /// también `EffectContractTests` para leer el chip con la misma vara.
    static func autoTapRateText(_ perSecond: Double) -> String {
        perSecond.formatted(.number.precision(.fractionLength(0...1)))
    }
```

`ActiveBonusBar.tint(_:)`:

```swift
        case .autoTapPerSecond: Color("PaletteBlue")
```

`Tools/v2/claves-pendientes/e6a-t3.json`:

```json
{
  "bonus.chip.autotap %@": {"es": "%@ toques/s", "en": "%@ taps/s"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6a-t3.json`.

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `AutoTapTests`, 6 tests).
Receta R con `-only-testing:FisuEvolutionTests/EffectContractTests -only-testing:FisuEvolutionTests/ActiveBonusTests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift Packages/EconomyKit/Sources/EconomyKit/AutoTapper.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/AutoTapTests.swift FisuEvolution/Game/State/ActiveBonus.swift \
  FisuEvolution/UI/HUD/ActiveBonusBar.swift FisuEvolutionTests/EffectContractTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6a-t3.json, según la ola
git diff --cached --stat
git commit -m "feat(tienda): el auto-tap, toques automáticos al mejor que tenés"
```

---

### Task 4: `oro_shop.json` — la tabla aprobada, con sus textos

**Objetivo:** la tienda de ORO como dato: los 13 ítems de la tabla de PLAN-v2 §4 E6 que son de
esta mitad (todo menos los lugares extra y los cosméticos, que son de E6b, y el giro extra, que
vende la ruleta de E5a T8), validados al arrancar, con nombre en es + en. Lo que da un consumible
se dice con el `RewardCopy` de E5b T1 (los números salen del dato); sólo "Fusionar todo" y los
permanentes tienen descripción propia. Un test pinea la tabla aprobada: si el simulador mueve un
precio (E2b), se cambia en el mismo commit; y otro cruza el permanente "mejor proveedor" con la
tabla de `r` de `packages.json` (E5a): un nivel que E5 no conoce no se vende.

**Files:**
- Create: `FisuEvolution/Resources/Config/oro_shop.json` (+ `xcodegen generate`)
- Create: `FisuEvolution/Managers/OroShopCopy.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`GameContent.oroShop`, carga y validación)
- Modify: `FisuEvolutionTests/LocalizationCompletenessTests.swift` (`DynamicFamily.oroShop`)
- Create: `FisuEvolutionTests/OroShopContentTests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6a-t4.json` (20 claves)

**Interfaces:**
- Consumes: `OroShopCatalog`, `OroShopCatalog.validate(floorIDs:)` (T2); `RewardSpec` (E4a T1);
  `RewardCopy.title(_:)` (**E5b T1**); `PackagesConfig.tierRatioByBestSupplierLevel` (**E5a T1**,
  `packages.json` de E5a T5).
- Produces: `GameContent.oroShop: OroShopCatalog`; `enum OroShopCopy` con
  `nameKey(_:)`, `descriptionKey(_:)`, `shelfKey(_:)`, `hasOwnDescription(_:)`,
  `name(for:bundle:)`, `detail(for:level:bundle:)`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "let notifications\|let visitors\|let events\|let wheel\|let packages" FisuEvolution/Managers/GameContentLoader.swift`
para ver qué configs ya suman las otras épicas (`oroShop` va **al final** de `GameContent`, de las
lecturas y del `return`), y `grep -n "enum RewardCopy" FisuEvolution/Managers/RewardCopy.swift`
(E5b T1). Sin `RewardCopy`, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/OroShopContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La tabla de la tienda de ORO que aprobó el dueño (PLAN-v2 §4 E6; la escala
/// es 1 h de producción ≈ 90 ORO). Los números finales los mueve el simulador
/// en E2b: si cambia uno, se cambia acá y en `oro_shop.json` en el mismo commit.
@Suite("oro_shop.json: la tabla aprobada")
@MainActor
struct OroShopContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    static let approvedPrices: [String: [Int]] = [
        "income_x2": [30], "income_x3": [60], "package_rain": [15], "auto_tap": [25],
        "time_jump_1h": [90], "time_jump_4h": [320], "offline_x3": [120], "daily_x3": [40],
        "skip_cooldowns": [25], "merge_all": [20],
        "better_supplier": [150, 400, 1000], "wheel_spins": [120, 300, 750],
        "skin_chest": [45],
    ]

    static let approvedDailyLimits: [String: Int] = [
        "income_x2": 3, "income_x3": 2, "package_rain": 5, "auto_tap": 3,
        "time_jump_1h": 2, "time_jump_4h": 1, "daily_x3": 1, "merge_all": 5,
    ]

    private func item(_ id: String) throws -> OroShopCatalog.Item {
        try #require(content.oroShop.item(id: id), "falta \(id)")
    }

    @Test("los precios y los topes son los aprobados")
    func pricesAndCaps() throws {
        #expect(Set(content.oroShop.items.map(\.id)) == Set(Self.approvedPrices.keys))
        for item in content.oroShop.items {
            let prices = item.isPermanent ? item.levels.map(\.price) : [item.price ?? 0]
            #expect(prices == Self.approvedPrices[item.id], "\(item.id)")
            #expect(item.dailyLimit == Self.approvedDailyLimits[item.id], "\(item.id)")
        }
        #expect(try item("time_jump_1h").priceGrowthPerPurchase == 1.25)
    }

    @Test("lo que dice cada fila es lo que da")
    func rewardsAreTheTable() throws {
        #expect(try item("income_x2").rewards == [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 1800)])
        #expect(try item("income_x3").rewards == [.modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 1800)])
        #expect(try item("package_rain").rewards == [.modifier(effect: .packageRateMultiplier, magnitude: 10, seconds: 60)])
        #expect(try item("auto_tap").rewards == [.autoTap(perSecond: 5, seconds: 600)])
        #expect(try item("time_jump_1h").rewards == [.coinsSeconds(3600)])
        #expect(try item("time_jump_4h").rewards == [.coinsSeconds(14_400)])
        #expect(try item("offline_x3").rewards == [.nextOfflineMultiplier(3)])
        #expect(try item("daily_x3").rewards == [.nextDailyMultiplier(3)])
        #expect(try item("skip_cooldowns").rewards == [.clearBoostCooldowns])
        #expect(try item("skin_chest").rewards == [.skinChest(1)])
        #expect(try item("merge_all").action == .mergeAll)
        #expect(try item("better_supplier").perk == .bestSupplier)
        #expect(try item("better_supplier").levels.map(\.value) == [1, 2, 3])
        #expect(try item("wheel_spins").perk == .wheelDailySpins)
        #expect(try item("wheel_spins").levels.map(\.value) == [1, 2, 3])
    }

    @Test("cada nivel de 'mejor proveedor' tiene su r en packages.json, el 1,8 / 1,6 / 1,4 aprobado")
    func supplierLevelsExistInE5() throws {
        let levels = try item("better_supplier").levels.map { Int($0.value) }
        #expect(content.packages.tierRatioByBestSupplierLevel.count == levels.count + 1, "el nivel 0 más los que se venden")
        #expect(levels.map { content.packages.tierRatio(bestSupplierLevel: $0) } == [1.8, 1.6, 1.4])
    }

    @Test("el azar con ORO que vende la tienda es exactamente el cofre (Apple 3.1.1); el giro extra es de la ruleta")
    func chanceItems() {
        #expect(Set(content.oroShop.items.filter(\.isChance).map(\.id)) == ["skin_chest"])
        #expect(!content.oroShop.items.contains { $0.rewards.contains(.wheelSpin(1)) })
    }

    @Test("cada ítem y cada estante tienen nombre en los dos idiomas; lo propio, también descripción",
          arguments: ["es", "en"])
    func copyInBothLanguages(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        for item in content.oroShop.items {
            #expect(OroShopCopy.name(for: item, bundle: bundle) != OroShopCopy.nameKey(item.id), "\(item.id): sin nombre en \(language)")
            guard OroShopCopy.hasOwnDescription(item) else { continue }
            let detail = OroShopCopy.detail(for: item, level: 0, bundle: bundle)
            #expect(detail != OroShopCopy.descriptionKey(item.id), "\(item.id): sin descripción en \(language)")
            #expect(!detail.contains("%"), "\(item.id): quedó un placeholder sin llenar en \(language)")
        }
        for shelf in OroShopCatalog.Shelf.allCases {
            let key = OroShopCopy.shelfKey(shelf)
            #expect(bundle.localizedString(forKey: key, value: "(falta)", table: nil) != "(falta)", "\(key) en \(language)")
        }
    }

    @Test("lo que da un consumible se dice como cualquier premio (RewardCopy)")
    func consumablesSayTheirReward() throws {
        for item in content.oroShop.items where !item.rewards.isEmpty {
            #expect(OroShopCopy.detail(for: item, level: 0) == item.rewards.map(RewardCopy.title).joined(separator: " + "))
        }
    }
}
```

`LocalizationCompletenessTests.swift`, en `enum DynamicFamily`, al final de los casos:

```swift
        /// `oroShop.item.<id>.name` (y `.desc` en lo que no es un premio: Fusionar
        /// todo y los permanentes), sobre `oro_shop.json`, y los estantes (`OroShopCopy`).
        case oroShop
```

y en `keys(in:)`:

```swift
            case .oroShop:
                return content.oroShop.items.flatMap { item in
                    [OroShopCopy.nameKey(item.id)] + (OroShopCopy.hasOwnDescription(item) ? [OroShopCopy.descriptionKey(item.id)] : [])
                } + OroShopCatalog.Shelf.allCases.map(OroShopCopy.shelfKey)
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/OroShopContentTests`.
Expected: no compila (`content.oroShop`, `OroShopCopy`).

- [ ] **Step 3: El dato**

`FisuEvolution/Resources/Config/oro_shop.json`:

```json
{
  "schemaVersion": 1,
  "items": [
    {"id": "income_x2", "shelf": "boosts", "iconKey": "ui_shop_income_x2", "symbol": "chart.line.uptrend.xyaxis",
     "price": 30, "dailyLimit": 3,
     "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 2, "seconds": 1800}]},
    {"id": "income_x3", "shelf": "boosts", "iconKey": "ui_shop_income_x3", "symbol": "flame.fill",
     "price": 60, "dailyLimit": 2,
     "rewards": [{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 3, "seconds": 1800}]},
    {"id": "auto_tap", "shelf": "boosts", "iconKey": "ui_shop_auto_tap", "symbol": "hand.tap.fill",
     "price": 25, "dailyLimit": 3,
     "rewards": [{"kind": "autoTap", "perSecond": 5, "seconds": 600}]},
    {"id": "package_rain", "shelf": "boosts", "iconKey": "ui_shop_package_rain", "symbol": "cloud.rain.fill",
     "price": 15, "dailyLimit": 5,
     "rewards": [{"kind": "modifier", "effect": "packageRateMultiplier", "magnitude": 10, "seconds": 60}]},
    {"id": "time_jump_1h", "shelf": "shortcuts", "iconKey": "ui_shop_time_jump_1h", "symbol": "forward.fill",
     "price": 90, "dailyLimit": 2, "priceGrowthPerPurchase": 1.25,
     "rewards": [{"kind": "coinsSeconds", "seconds": 3600}]},
    {"id": "time_jump_4h", "shelf": "shortcuts", "iconKey": "ui_shop_time_jump_4h", "symbol": "forward.end.fill",
     "price": 320, "dailyLimit": 1,
     "rewards": [{"kind": "coinsSeconds", "seconds": 14400}]},
    {"id": "offline_x3", "shelf": "shortcuts", "iconKey": "ui_shop_offline_x3", "symbol": "moon.zzz.fill",
     "price": 120,
     "rewards": [{"kind": "nextOfflineMultiplier", "multiplier": 3}]},
    {"id": "daily_x3", "shelf": "shortcuts", "iconKey": "ui_shop_daily_x3", "symbol": "calendar.badge.plus",
     "price": 40, "dailyLimit": 1,
     "rewards": [{"kind": "nextDailyMultiplier", "multiplier": 3}]},
    {"id": "skip_cooldowns", "shelf": "shortcuts", "iconKey": "ui_shop_skip_cooldowns", "symbol": "timer",
     "price": 25,
     "rewards": [{"kind": "clearBoostCooldowns"}]},
    {"id": "merge_all", "shelf": "shortcuts", "iconKey": "ui_shop_merge_all", "symbol": "arrow.triangle.merge",
     "price": 20, "dailyLimit": 5, "action": "mergeAll"},
    {"id": "better_supplier", "shelf": "permanents", "iconKey": "ui_shop_better_supplier", "symbol": "shippingbox.fill",
     "perk": "bestSupplier",
     "levels": [{"price": 150, "value": 1}, {"price": 400, "value": 2}, {"price": 1000, "value": 3}]},
    {"id": "wheel_spins", "shelf": "permanents", "iconKey": "ui_shop_wheel_spins", "symbol": "circle.dashed",
     "perk": "wheelDailySpins",
     "levels": [{"price": 120, "value": 1}, {"price": 300, "value": 2}, {"price": 750, "value": 3}]},
    {"id": "skin_chest", "shelf": "luck", "iconKey": "ui_shop_skin_chest", "symbol": "gift.fill",
     "price": 45, "isChance": true,
     "rewards": [{"kind": "skinChest", "count": 1}]}
  ]
}
```

(El `value` de "mejor proveedor" es el **nivel** que lee `PackagesConfig.tierRatio(bestSupplierLevel:)`;
los `r` 1,8 / 1,6 / 1,4 viven en `packages.json`, de E5a. El giro extra no está: lo vende la
ruleta.)

`GameContentLoader.swift`: en `GameContent`, al final,

```swift
    /// La tienda de ORO: consumibles, permanentes y suerte (PLAN-v2 E6).
    let oroShop: OroShopCatalog
```

en `load(from:)`, junto a las otras lecturas, `let oroShop: OroShopCatalog = try decode("oro_shop", from: bundle)`;
después de validar las notificaciones:

```swift
        do {
            try oroShop.validate(floorIDs: floorIDs)
        } catch {
            throw GameError.contentInvalid(file: "oro_shop.json", reason: "\(error)")
        }
```

y `oroShop: oroShop` al final del `return GameContent(...)`.

- [ ] **Step 4: Los textos**

`FisuEvolution/Managers/OroShopCopy.swift`:

```swift
import EconomyKit
import Foundation

/// Lo que dice cada fila de la tienda de ORO. Lo que da un consumible se dice
/// como cualquier premio (`RewardCopy`, E5b T1): una sola forma de decir "×3
/// durante 30 min" en todo el juego. Sólo "Fusionar todo" y los permanentes, que
/// no son un premio, tienen descripción propia, con sus números del dato.
enum OroShopCopy {
    static func nameKey(_ id: String) -> String { "oroShop.item.\(id).name" }
    static func descriptionKey(_ id: String) -> String { "oroShop.item.\(id).desc" }
    static func shelfKey(_ shelf: OroShopCatalog.Shelf) -> String { "oroShop.shelf.\(shelf.rawValue)" }

    /// Lo que no es un premio dice lo suyo; lo demás lo dice `RewardCopy`.
    static func hasOwnDescription(_ item: OroShopCatalog.Item) -> Bool {
        item.rewards.isEmpty
    }

    static func name(for item: OroShopCatalog.Item, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: nameKey(item.id), value: nil, table: nil)
    }

    /// Qué da. `level` es el nivel comprado de un permanente: la fila describe el
    /// PRÓXIMO (o el último, al máximo).
    static func detail(for item: OroShopCatalog.Item, level: Int, bundle: Bundle = .main) -> String {
        guard hasOwnDescription(item) else {
            return item.rewards.map(RewardCopy.title).joined(separator: " + ")
        }
        let template = bundle.localizedString(forKey: descriptionKey(item.id), value: nil, table: nil)
        let arguments = arguments(for: item, level: level)
        // Sin números no se formatea: un `%` literal se comería el carácter de al lado.
        guard !arguments.isEmpty else { return template }
        return String(format: template, arguments: arguments)
    }

    private static func arguments(for item: OroShopCatalog.Item, level: Int) -> [String] {
        guard let perk = item.perk, !item.levels.isEmpty else { return [] }
        let next = min(max(0, level), item.levels.count - 1)
        switch perk {
        case .bestSupplier:
            return [String(next + 1), String(item.levels.count)]
        case .wheelDailySpins, .extraSlots:
            return [item.levels[next].value.formatted(.number.precision(.fractionLength(0)))]
        }
    }
}
```

`Tools/v2/claves-pendientes/e6a-t4.json` (los nombres, con el humor de la casa; las
descripciones de los consumibles las pone `RewardCopy`):

```json
{
  "oroShop.shelf.boosts": {"es": "Boosts", "en": "Boosts"},
  "oroShop.shelf.shortcuts": {"es": "Atajos", "en": "Shortcuts"},
  "oroShop.shelf.permanents": {"es": "Permanentes", "en": "Permanent"},
  "oroShop.shelf.luck": {"es": "Suerte", "en": "Luck"},
  "oroShop.item.income_x2.name": {"es": "Doble turno", "en": "Double Shift"},
  "oroShop.item.income_x3.name": {"es": "Triple turno", "en": "Triple Shift"},
  "oroShop.item.auto_tap.name": {"es": "Dedo de goma", "en": "Rubber Finger"},
  "oroShop.item.package_rain.name": {"es": "Lluvia de paquetes", "en": "Parcel Rain"},
  "oroShop.item.time_jump_1h.name": {"es": "Hora extra", "en": "Overtime"},
  "oroShop.item.time_jump_4h.name": {"es": "Media jornada", "en": "Half Shift"},
  "oroShop.item.offline_x3.name": {"es": "Siesta productiva", "en": "Productive Nap"},
  "oroShop.item.daily_x3.name": {"es": "Diario reforzado", "en": "Boosted Daily"},
  "oroShop.item.skip_cooldowns.name": {"es": "Recarga express", "en": "Express Recharge"},
  "oroShop.item.merge_all.name": {"es": "Fusionar todo", "en": "Merge Everything"},
  "oroShop.item.merge_all.desc": {"es": "Fusiona todos los pares del piso que estás mirando", "en": "Merges every pair on the floor you're looking at"},
  "oroShop.item.better_supplier.name": {"es": "Mejor proveedor", "en": "Better Supplier"},
  "oroShop.item.better_supplier.desc": {"es": "Nivel %1$@ de %2$@: los Paquetes traen más seguido a los de arriba", "en": "Level %1$@ of %2$@: Parcels bring top hires more often"},
  "oroShop.item.wheel_spins.name": {"es": "Abono a la ruleta", "en": "Wheel Pass"},
  "oroShop.item.wheel_spins.desc": {"es": "+%@ giros por video, todos los días", "en": "+%@ video spins, every day"},
  "oroShop.item.skin_chest.name": {"es": "Cofre de pintas", "en": "Outfit Chest"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6a-t4.json`. (Los nombres son
propuesta: el dueño los cambia en el catálogo sin tocar código. "Paquetes"/"Parcels" es el
nombre que usa E5 para el Paquete de la Aduana.)

- [ ] **Step 5: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/OroShopContentTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/GameContentValidationTests`
→ PASS (`OroShopContentTests`: 6, uno con 2 argumentos). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Resources/Config/oro_shop.json FisuEvolution/Managers/OroShopCopy.swift \
  FisuEvolution/Managers/GameContentLoader.swift FisuEvolutionTests/LocalizationCompletenessTests.swift \
  FisuEvolutionTests/OroShopContentTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6a-t4.json, según la ola
git diff --cached --stat
git commit -m "feat(tienda): oro_shop.json con la tabla aprobada y sus textos"
```

---

### Task 5: Los premios nuevos se entregan — auto-tap, Offline ×3 y Diario ×3

**Objetivo:** que el punto único de premios (E4a T8) sepa dar los tres tipos que eran de E6
(`.autoTap`, `.nextOfflineMultiplier`, `.nextDailyMultiplier`), que el auto-tap cobre en cada
tick y que los dos ×3 comprados se consuman donde corresponde: el Offline ×3 en la próxima
vuelta **que muestra el popup** (una ausencia corta, que se acredita en silencio, no lo gasta) y
el Diario ×3 en el próximo diario **que paga plata** (un día de especial o de cofre no lo gasta).
`.extraSlots` sigue sin entregarse: el permanente de lugares es un nivel (duda 2).

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Rewards.swift` (`grantableRewardKinds`, tres casos de `grant`)
- Create: `FisuEvolution/Game/State/GameState+OroShop.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`advanceEngagement`)
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (o `GameState+Lifecycle.swift`, si E1 T8 mudó `applyOfflineProgressIfNeeded`): una línea
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` 🔥 (`claimDailyIfAvailable`): una línea
- Modify: `FisuEvolutionTests/RewardGrantTests.swift` (lo entregable)
- Create: `FisuEvolutionTests/PendingMultiplierTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `ShopState.pendingOfflineMultiplier/pendingDailyMultiplier` (T1);
  `ActiveModifier.Effect.autoTapPerSecond`, `AutoTapper` (T3); `grant`, `grantableRewardKinds`
  (**E4a T8**) con `.package`/`.wheelSpin` (**E5a T6, T8**); `advanceEngagement(delta:)` (**E4a T9**);
  `DailyRewardManager.Claim` (con la firma que dejó **E2a T11**).
- Produces: `GameState.applyPendingOfflineMultiplier(to: Double) -> Double`,
  `applyPendingDailyMultiplier(to: DailyRewardManager.Claim) -> DailyRewardManager.Claim`,
  `advanceAutoTap(delta:now:)`.

- [ ] **Step 0: Pararse en la base**

Run, uno por uno:
`grep -n "static let grantableRewardKinds" -A4 FisuEvolution/Game/State/GameState+Rewards.swift` (E4a T8; con `.package` y `.wheelSpin` de E5),
`grep -n "func advanceEngagement" -A6 FisuEvolution/Game/State/GameState+Engagement.swift` (E4a T9),
`grep -rn "offlineReward = OfflineReward(amount: credit.amount)" FisuEvolution/Game` (dónde quedó el popup offline),
`grep -n "dailyClaim = claim" FisuEvolution/Game/State/GameState+Bonus.swift` y
`grep -n "struct Claim" -A8 FisuEvolution/Managers/ContentSystems.swift` (los campos de `Claim` hoy).
Si falta `grant` o `advanceEngagement`, `NEEDS_CONTEXT`. Si `.package` no está en la lista, E5
no entró: `NEEDS_CONTEXT` (regla 3 del paralelismo).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PendingMultiplierTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los premios nuevos de la tienda: auto-tap, Offline ×3 y Diario ×3")
@MainActor
struct PendingMultiplierTests {
    /// Tres Fisuras con su pasivo: la torre produce y una ausencia paga.
    private func producing() async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 3]
        gameState.player?.run.passiveUnlocked["homeless"] = true
        gameState.reconcileTower()
        return gameState
    }

    @Test("el Offline ×3 triplica la vuelta del popup y se consume")
    func offlineTriples() async throws {
        let plain = await producing()
        let boosted = await producing()
        boosted.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        #expect(boosted.player?.meta.engagement.shop.pendingOfflineMultiplier == 3)
        for gameState in [plain, boosted] {
            gameState.player?.meta.lastSeenTimestamp = 1_000
            gameState.applyOfflineProgressIfNeeded(now: 1_000 + 3_600)
        }
        let base = try #require(plain.offlineReward?.amount)
        let tripled = try #require(boosted.offlineReward?.amount)
        #expect(abs(tripled - base * 3) < 1e-6 * tripled)
        #expect(boosted.player?.meta.engagement.shop.pendingOfflineMultiplier == nil)
    }

    @Test("una ausencia corta, sin popup, no gasta el ×3")
    func shortAbsenceKeepsIt() async throws {
        let gameState = await producing()
        gameState.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        gameState.player?.meta.lastSeenTimestamp = 1_000
        gameState.applyOfflineProgressIfNeeded(now: 1_000 + 10)
        #expect(gameState.offlineReward == nil)
        #expect(gameState.player?.meta.engagement.shop.pendingOfflineMultiplier == 3)
    }

    @Test("lo que agrega el ×3 llega a la caja y a lo ganado de por vida")
    func extraIsCredited() async throws {
        let gameState = await makeGameState()
        gameState.grant(.nextOfflineMultiplier(3), source: "shop.offline_x3")
        let before = try #require(gameState.player)
        #expect(gameState.applyPendingOfflineMultiplier(to: 100) == 300)
        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins + 200)
        #expect(after.meta.lifetimeEarnings == before.meta.lifetimeEarnings + 200)
        #expect(gameState.applyPendingOfflineMultiplier(to: 100) == 100, "se usa una vez")
    }

    @Test("el Diario ×3 triplica la plata del próximo diario y se consume")
    func dailyTriples() async throws {
        let plain = await makeGameState()
        let boosted = await makeGameState()
        boosted.grant(.nextDailyMultiplier(3), source: "shop.daily_x3")
        let yesterday = DailyRewardManager.dayString(for: Date().addingTimeInterval(-86_400))
        for gameState in [plain, boosted] {
            gameState.player?.meta.daily.lastClaimDay = yesterday
            gameState.player?.meta.daily.cycleDay = 1
            gameState.claimDailyIfAvailable()
        }
        let base = try #require(plain.dailyClaim?.coinsGranted)
        let tripled = try #require(boosted.dailyClaim?.coinsGranted)
        #expect(base > 0)
        #expect(abs(tripled - base * 3) < 1e-6 * tripled)
        #expect(boosted.player?.meta.engagement.shop.pendingDailyMultiplier == nil)
    }

    @Test("el auto-tap cobra en cada tick, también sin los motores de engagement")
    func autoTapPaysOnTheTick() async throws {
        let gameState = await producing()
        #expect(!gameState.engagementAutorun, "bajo XCTest los motores arrancan apagados")
        let now = Date().timeIntervalSince1970
        gameState.grant(.autoTap(perSecond: 5, seconds: 600), source: "shop.auto_tap", now: now)
        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.effect == .autoTapPerSecond })
        #expect(modifier.magnitude == 5)
        #expect(modifier.sourceKey == "shop.auto_tap")
        let coins = try #require(gameState.player?.run.coins)
        gameState.advanceEngagement(delta: 1)
        #expect((gameState.player?.run.coins ?? 0) > coins, "un efecto comprado no espera al autorun")
    }

    @Test("comprar dos ×3 no los apila: queda el más alto")
    func pendingDoesNotStack() async throws {
        let gameState = await makeGameState()
        gameState.grant(.nextDailyMultiplier(3), source: "a")
        gameState.grant(.nextDailyMultiplier(2), source: "b")
        #expect(gameState.player?.meta.engagement.shop.pendingDailyMultiplier == 3)
    }
}
```

En `RewardGrantTests.swift`: `notYetGrantable` queda con `arguments: [RewardSpec.extraSlots(3)]`
(más lo que E5 haya dejado sin entregar), y `grantableKinds` pasa a esperar
`Set(RewardSpec.Kind.allCases).subtracting([.extraSlots])`.

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/PendingMultiplierTests -only-testing:FisuEvolutionTests/RewardGrantTests`.
Expected: no compila (`applyPendingOfflineMultiplier` no existe).

- [ ] **Step 3: El punto único sabe dar los tres**

`GameState+Rewards.swift`: la lista y su comentario quedan

```swift
    /// Lo que este punto sabe dar. `.extraSlots` no: los lugares extra son un
    /// permanente de la tienda que se lee de su nivel (E6b), no un premio que se
    /// pueda entregar dos veces. Un guion, evento u oferta que da algo de afuera
    /// de esta lista **no se ofrece**.
    static let grantableRewardKinds: Set<RewardSpec.Kind> = [
        .coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity,
        .package, .wheelSpin,
        .autoTap, .nextOfflineMultiplier, .nextDailyMultiplier,
    ]
```

y en el `switch reward.scaled(by: multiplier)` de `grant`, los tres casos salen de la rama que
devuelve 0 (queda sólo `.extraSlots`):

```swift
        case let .autoTap(perSecond, seconds):
            player.run.activeModifiers.append(ActiveModifier(
                effect: .autoTapPerSecond, magnitude: perSecond, expiresAt: now + seconds, sourceKey: source
            ))
        case .nextOfflineMultiplier(let multiplier):
            // Dos no se apilan: queda el más alto, y se usa una vez.
            let pending = player.meta.engagement.shop.pendingOfflineMultiplier ?? 1
            player.meta.engagement.shop.pendingOfflineMultiplier = max(pending, multiplier)
        case .nextDailyMultiplier(let multiplier):
            let pending = player.meta.engagement.shop.pendingDailyMultiplier ?? 1
            player.meta.engagement.shop.pendingDailyMultiplier = max(pending, multiplier)
        case .extraSlots:
            return 0
```

(⚠️ el parámetro `multiplier` de `grant` y la variable del `case` se llaman igual: el `case`
la sombrea a propósito, porque `scaled(by:)` no toca un multiplicador pendiente.)

- [ ] **Step 4: Consumirlos y el tick**

`FisuEvolution/Game/State/GameState+OroShop.swift`:

```swift
import EconomyKit
import Foundation

/// La tienda de ORO en la partida (PLAN-v2 E6): los ×3 comprados que esperan su
/// momento, el auto-tap, y (T6) cotizar y comprar.
extension GameState {
    /// El Offline ×3 comprado multiplica la vuelta que muestra el popup y se
    /// consume ahí. Una ausencia corta, que se acredita en silencio, no lo gasta:
    /// el jugador lo compró para ver el número grande.
    func applyPendingOfflineMultiplier(to amount: Double) -> Double {
        guard amount > 0, var player, let multiplier = player.meta.engagement.shop.pendingOfflineMultiplier else {
            return amount
        }
        let extra = amount * (multiplier - 1)
        player.run.coins += extra
        player.meta.lifetimeEarnings += extra
        player.meta.engagement.shop.pendingOfflineMultiplier = nil
        self.player = player
        Log.economy.info("offline ×\(multiplier) from the oro shop: +\(extra)")
        return amount + extra
    }

    /// El Diario ×3 multiplica la plata del próximo diario. Un día que da un
    /// especial o un cofre no lo gasta: espera al que pague plata.
    func applyPendingDailyMultiplier(to claim: DailyRewardManager.Claim) -> DailyRewardManager.Claim {
        guard claim.coinsGranted > 0, var player,
              let multiplier = player.meta.engagement.shop.pendingDailyMultiplier
        else { return claim }
        let extra = claim.coinsGranted * (multiplier - 1)
        player.run.coins += extra
        player.meta.lifetimeEarnings += extra
        player.meta.engagement.shop.pendingDailyMultiplier = nil
        self.player = player
        return DailyRewardManager.Claim(
            day: claim.day,
            coinsGranted: claim.coinsGranted + extra,
            specialGranted: claim.specialGranted,
            chestGranted: claim.chestGranted
        )
    }

    /// Los toques automáticos. Lo llama `advanceEngagement` con el delta del tick
    /// (juego activo, con tope de 2 s). No espera a `engagementAutorun`: es un
    /// efecto que el jugador compró, no un motor que aparece solo.
    func advanceAutoTap(delta: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, let economy, var player else { return }
        let paid = AutoTapper.advance(
            state: &player, delta: delta, now: now,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy
        )
        guard paid > 0 else { return }
        self.player = player
    }
}
```

(Si E2a T11 le sumó campos a `DailyRewardManager.Claim`, el `Claim(...)` de arriba los copia
todos del `claim` que recibe: el paso 0 los listó.)

`GameState+Engagement.swift`, en `advanceEngagement(delta:)`, **primero** (antes de los motores
con autorun):

```swift
        advanceAutoTap(delta: delta)
```

🔥 Donde el paso 0 encontró el popup offline (`GameState.swift` o `+Lifecycle`):

```swift
        offlineReward = OfflineReward(amount: applyPendingOfflineMultiplier(to: credit.amount))
```

🔥 `GameState+Bonus.swift`, en `claimDailyIfAvailable()`:

```swift
            dailyClaim = applyPendingDailyMultiplier(to: claim)
```

(el `self.player = player` de la línea de arriba queda **antes**: el ×3 lee el `player` ya
cobrado.)

- [ ] **Step 5: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/PendingMultiplierTests -only-testing:FisuEvolutionTests/RewardGrantTests -only-testing:FisuEvolutionTests/OfflinePopupTests -only-testing:FisuEvolutionTests/DailyCalendarTests`
→ PASS (`PendingMultiplierTests`: 6). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Rewards.swift FisuEvolution/Game/State/GameState+OroShop.swift \
  FisuEvolution/Game/State/GameState+Engagement.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolutionTests/RewardGrantTests.swift FisuEvolutionTests/PendingMultiplierTests.swift
git add FisuEvolution/Game/State/GameState.swift   # o +Lifecycle.swift: el archivo donde quedó el popup offline
git diff --cached --stat
git commit -m "feat(tienda): auto-tap, Offline ×3 y Diario ×3 se entregan y se consumen en su momento"
```

---

### Task 6: Comprar en la tienda de ORO — y lo que mejora a E5

**Objetivo:** el camino de la app: el contexto que sólo ella sabe (lo entregable, el piso
alcanzado, los pares de "Fusionar todo", los boosts esperando, si el cofre tiene algo para dar),
las filas que dibuja la pantalla y `buyOroShopItem`, que cobra por `OroShop.purchase` y después
entrega: premios por `grant`, "Fusionar todo" por `enqueueMergeAll` con su origen propio, y los
permanentes quedan en su nivel, donde los leen los dos enchufes que dejó E5a: el `0` de
`openPackage()` (el nivel de "mejor proveedor", cuyo `r` está en `packages.json`) y el cupo de
giros por video de la ruleta (`WheelConfig.videoSpinsPerDay`, que el abono agranda en un solo
cálculo, `effectiveWheel`).

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+OroShop.swift` (contexto, filas, comprar, perks, `effectiveWheel`)
- Create: `Packages/EconomyKit/Sources/EconomyKit/Shop/ShopPerks.swift` (`WheelConfig.withBonusVideoSpins(_:)`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (`Origin.oroShop`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (`discardBoardChange`)
- Modify: `FisuEvolution/Game/State/GameState+Packages.swift` (E5a T6: el `0` de `openPackage()`)
- Modify: `FisuEvolution/Game/State/GameState+Wheel.swift` (E5a T8: `content.wheel` → `effectiveWheel` en `wheelAvailability` y `spinWheel`)
- Create: `FisuEvolutionTests/OroShopPurchaseTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `OroShop`, `OroShopCatalog` (T2); `GameContent.oroShop` (T4); los tres premios nuevos
  (T5); `BoardChangePlanner.planMergeAll(…config:origin:)`, `enqueueMergeAll(onFloor:origin:)`
  (**E2a T9, T14**); `discardBoardChange` (**E1 T14**); `chestUnlockedCharacterTypes`
  (`GameState+Chests.swift:134`); `BoostManager.cooldownRemaining` (`ContentSystems.swift:261`);
  `openPackage()`, `PackagesConfig.tierRatio(bestSupplierLevel:)` (**E5a T1, T6**);
  `WheelConfig` (su `init` público), `wheelAvailability(storefrontAllows:now:)`,
  `spinWheel(_:storefrontAllows:now:)`, `WheelRoller.spinsLeft` (**E5a T3, T8**).
- Produces: `struct OroShopRow: Identifiable, Equatable { item; quote; id }`,
  `enum OroShopOutcome: Equatable { bought, refused(OroShop.Blocker), unavailable }`,
  `GameState.oroShopContext(chanceAllowed:now:) -> OroShop.Context?`,
  `oroShopRows(chanceAllowed:now:) -> [OroShopRow]`,
  `@discardableResult buyOroShopItem(id:chanceAllowed:now:) -> OroShopOutcome`,
  `bestSupplierLevel: Int`, `bonusDailyWheelSpins: Int`, `effectiveWheel: WheelConfig?`;
  `WheelConfig.withBonusVideoSpins(_:) -> WheelConfig`; `BoardChange.Origin.oroShop`.

- [ ] **Step 0: Pararse en la base**

Run, uno por uno:
`grep -n "func enqueueMergeAll" FisuEvolution/Game/State/GameState+BoardChanges.swift` (E2a T14),
`grep -n "func discardBoardChange" -A6 FisuEvolution/Game/State/GameState+BoardChanges.swift` (E1 T14),
`grep -n "public enum Origin" -A12 Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift`,
`grep -n "tierRatio(bestSupplierLevel: 0)" FisuEvolution/Game/State/GameState+Packages.swift` (E5a T6: tiene que dar **una** línea) y
`grep -n "content.wheel" FisuEvolution/Game/State/GameState+Wheel.swift` (E5a T8: los usos del cupo
en `wheelAvailability` y `spinWheel`). Si no hay `enqueueMergeAll` o falta alguno de los dos
enchufes de E5: `NEEDS_CONTEXT` con lo que encontraste.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/OroShopPurchaseTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Comprar en la tienda de ORO")
@MainActor
struct OroShopPurchaseTests {
    private func rich(_ oro: Int = 5_000) async -> GameState {
        let gameState = await makeGameState()
        gameState.player?.meta.oro = oro
        return gameState
    }

    @Test("un boost cobra ORO, gasta cupo y arranca su modificador con el origen de la tienda")
    func boostStarts() async throws {
        let gameState = await rich(100)
        #expect(gameState.buyOroShopItem(id: "income_x2", chanceAllowed: true) == .bought)
        let player = try #require(gameState.player)
        #expect(player.meta.oro == 70)
        #expect(player.meta.stats.oroSpentEver == 30)
        #expect(player.meta.engagement.shop.purchasesToday["income_x2"] == 1)
        let modifier = try #require(player.run.activeModifiers.first { $0.sourceKey == "shop.income_x2" })
        #expect(modifier.effect == .incomeMultiplier)
        #expect(modifier.magnitude == 2)
    }

    @Test("lo gastado en la tienda no toca el multiplicador global")
    func spendingDoesNotNerf() async throws {
        let gameState = await rich()
        let before = try #require(gameState.player?.meta)
        gameState.buyOroShopItem(id: "income_x3", chanceAllowed: true)
        let after = try #require(gameState.player?.meta)
        #expect(after.oroEarnedLifetime == before.oroEarnedLifetime)
        #expect(after.globalMultiplier == before.globalMultiplier)
    }

    @Test("el salto de 1 h paga una hora de producción, lo mismo que un premio de 3.600 s")
    func timeJumpPaysAnHour() async throws {
        let gameState = await rich()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let expected = GameState.coinReward(seconds: 3600, player: before, content: content, economy: economy)
        #expect(gameState.buyOroShopItem(id: "time_jump_1h", chanceAllowed: true) == .bought)
        let after = try #require(gameState.player)
        #expect(abs(after.run.coins - before.run.coins - expected) < 1e-6 * max(1, expected))
        let second = try #require(gameState.oroShopRows(chanceAllowed: true).first { $0.id == "time_jump_1h" })
        #expect(second.quote.price == 113, "la segunda del día sale ×1,25")
    }

    @Test("el tope del día frena y no cobra")
    func dailyCap() async throws {
        let gameState = await rich()
        for _ in 0..<3 {
            #expect(gameState.buyOroShopItem(id: "income_x2", chanceAllowed: true) == .bought)
        }
        let oro = try #require(gameState.player?.meta.oro)
        #expect(gameState.buyOroShopItem(id: "income_x2", chanceAllowed: true) == .refused(.dailyLimitReached))
        #expect(gameState.player?.meta.oro == oro)
    }

    @Test("Fusionar todo encola los pares del piso visible por el embudo, con su origen")
    func mergeAll() async throws {
        let gameState = await rich()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        #expect(gameState.buyOroShopItem(id: "merge_all", chanceAllowed: true) == .bought)
        let queued = gameState.pendingBoardChanges + [gameState.inFlightBoardChange].compactMap { $0 }
        #expect(queued.count == 3)
        #expect(queued.allSatisfy { $0.origin == .oroShop })
    }

    @Test("sin pares, Fusionar todo no cobra")
    func mergeAllWithoutPairs() async throws {
        let gameState = await rich()
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        let oro = try #require(gameState.player?.meta.oro)
        #expect(gameState.buyOroShopItem(id: "merge_all", chanceAllowed: true) == .refused(.nothingToDo))
        #expect(gameState.player?.meta.oro == oro)
    }

    @Test("el cofre por ORO no se vende donde el azar está apagado; donde sí, espera en Regalos")
    func chest() async throws {
        let gameState = await rich()
        gameState.debugUnlockFloors(throughTier: 12)
        let chests = try #require(gameState.player?.meta.chestsPending)
        #expect(gameState.buyOroShopItem(id: "skin_chest", chanceAllowed: false) == .unavailable)
        #expect(gameState.player?.meta.chestsPending == chests)
        #expect(!gameState.oroShopRows(chanceAllowed: false).contains { $0.id == "skin_chest" })
        #expect(gameState.buyOroShopItem(id: "skin_chest", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.chestsPending == chests + 1)
    }

    @Test("Saltear cooldowns sólo se vende con un boost esperando")
    func skipCooldowns() async throws {
        let gameState = await rich()
        #expect(gameState.buyOroShopItem(id: "skip_cooldowns", chanceAllowed: true) == .refused(.nothingToDo))
        let boost = try #require(gameState.content?.boosts.boosts.first)
        gameState.player?.meta.boostActivations[boost.id] = Date().timeIntervalSince1970
        #expect(gameState.buyOroShopItem(id: "skip_cooldowns", chanceAllowed: true) == .bought)
        #expect(gameState.player?.meta.boostActivations.isEmpty == true)
    }

    @Test("mejor proveedor sube de a un nivel, para en el tercero, y el Paquete usa su r")
    func supplier() async throws {
        let gameState = await rich()
        let packages = try #require(gameState.content?.packages)
        #expect(gameState.bestSupplierLevel == 0)
        for (level, ratio) in zip(1...3, [1.8, 1.6, 1.4]) {
            #expect(gameState.buyOroShopItem(id: "better_supplier", chanceAllowed: true) == .bought)
            #expect(gameState.bestSupplierLevel == level)
            #expect(packages.tierRatio(bestSupplierLevel: gameState.bestSupplierLevel) == ratio)
        }
        #expect(gameState.buyOroShopItem(id: "better_supplier", chanceAllowed: true) == .refused(.maxed))
    }

    @Test("el abono a la ruleta suma giros por video al día, también en lo que ofrece la ruleta")
    func wheelSpins() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.wheel.videoSpinsPerDay)
        #expect(gameState.bonusDailyWheelSpins == 0)
        #expect(gameState.wheelAvailability(storefrontAllows: false).videoLeft == base)
        gameState.buyOroShopItem(id: "wheel_spins", chanceAllowed: true)
        #expect(gameState.bonusDailyWheelSpins == 1)
        #expect(gameState.wheelAvailability(storefrontAllows: false).videoLeft == base + 1)
        gameState.buyOroShopItem(id: "wheel_spins", chanceAllowed: true)
        #expect(gameState.effectiveWheel?.videoSpinsPerDay == base + 2)
    }

    @Test("los giros de más se pueden gastar: spinWheel cobra contra el cupo agrandado")
    func bonusSpinsAreSpendable() async throws {
        let gameState = await rich()
        let base = try #require(gameState.content?.wheel.videoSpinsPerDay)
        gameState.buyOroShopItem(id: "wheel_spins", chanceAllowed: true)
        for _ in 0..<(base + 1) {
            #expect(gameState.spinWheel(.video) != nil)
        }
        #expect(gameState.spinWheel(.video) == nil, "pasado el cupo agrandado, no hay más")
    }

    @Test("un ×3 se compra una vez hasta que se use")
    func pendingOnce() async throws {
        let gameState = await rich()
        #expect(gameState.buyOroShopItem(id: "offline_x3", chanceAllowed: true) == .bought)
        #expect(gameState.buyOroShopItem(id: "offline_x3", chanceAllowed: true) == .refused(.alreadyPending))
    }

    @Test("sin ORO no compra nada y lo dice")
    func broke() async throws {
        let gameState = await rich(5)
        #expect(gameState.buyOroShopItem(id: "income_x2", chanceAllowed: true) == .refused(.cantAfford))
        #expect(gameState.player?.meta.oro == 5)
    }
}
```

(`gameState.content?.packages` y `.wheel` son los configs de E5a T5; `spinWheel(.video)` usa el
default de `storefrontAllows`. Si E5 los nombró distinto, el paso 0 lo dice y se usan los suyos.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/OroShopPurchaseTests`.
Expected: no compila (`buyOroShopItem`, `Origin.oroShop`).

- [ ] **Step 3: El origen de la tienda en el embudo**

`BoardChange.swift`, en `enum Origin`, al final de los casos que ya estén:

```swift
        /// "Fusionar todo" comprado con ORO (E6).
        case oroShop
```

`GameState+BoardChanges.swift`, en el `switch change.origin` de `discardBoardChange`, `.oroShop`
va con los que no compensan (`… , .debug, .oroShop: break`): "Fusionar todo" se cobró por el
plan entero, y un par que dejó de existir porque el jugador lo fusionó a mano no es una pérdida
(duda 4).

- [ ] **Step 4: Comprar**

`GameState+OroShop.swift`, arriba de la extensión de T5:

```swift
/// Una fila de la tienda de ORO, ya cotizada: la vista no le pregunta nada más al estado.
struct OroShopRow: Identifiable, Equatable {
    let item: OroShopCatalog.Item
    let quote: OroShop.Quote

    var id: String { item.id }
}

enum OroShopOutcome: Equatable {
    case bought
    case refused(OroShop.Blocker)
    /// No se ofrece (tienda restringida, nada que entregar, sin contenido).
    case unavailable
}
```

y en la extensión:

```swift
    /// Lo que la tienda necesita saber de la partida, resuelto acá. `chanceAllowed`
    /// lo pone quien llama (`LootBoxGate`, T7), para que un test no dependa del
    /// país de la máquina.
    func oroShopContext(chanceAllowed: Bool, now: Date = Date()) -> OroShop.Context? {
        guard let content, let player, let tower else { return nil }
        let reached = Set(content.floorTable.floors.prefix(player.meta.stats.maxFloorOrdinalEver + 1).map(\.id))
        let pairs = BoardChangePlanner.planMergeAll(
            floorOrdinal: visibleFloorOrdinal, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy, origin: .oroShop
        ).count
        let seconds = now.timeIntervalSince1970
        let coolingDown = content.boosts.boosts.contains {
            BoostManager.cooldownRemaining(of: $0, state: player, now: seconds) > 0
        }
        var perks: Set<OroShopCatalog.Perk> = [.extraSlots]
        if Self.grantableRewardKinds.contains(.package) { perks.insert(.bestSupplier) }
        if Self.grantableRewardKinds.contains(.wheelSpin) { perks.insert(.wheelDailySpins) }
        return OroShop.Context(
            today: DailyRewardManager.dayString(for: now),
            grantableKinds: Self.grantableRewardKinds,
            chanceAllowed: chanceAllowed,
            reachedFloorIds: reached,
            mergeAllPairs: pairs,
            anyBoostCoolingDown: coolingDown,
            chestHasSomethingToGive: ChestRoller.hasSomethingToGive(
                owned: player.meta.allOwnedSkins, unlocked: chestUnlockedCharacterTypes, skins: content.skins
            ),
            supportedPerks: perks
        )
    }

    /// Las filas de la tienda, en el orden del catálogo y ya cotizadas.
    func oroShopRows(chanceAllowed: Bool, now: Date = Date()) -> [OroShopRow] {
        guard let content, let player, let context = oroShopContext(chanceAllowed: chanceAllowed, now: now) else { return [] }
        return OroShop.visibleItems(catalog: content.oroShop, context: context).map {
            OroShopRow(item: $0, quote: OroShop.quote($0, state: player, context: context))
        }
    }

    /// Compra un ítem: cobra por `OroShop.purchase` (`spendOro`, la única salida
    /// de ORO) y después entrega. Un permanente queda en su nivel: lo leen quienes
    /// lo usan (`bestSupplierLevel`, `effectiveWheel`, los lugares de E6b).
    @discardableResult
    func buyOroShopItem(id: String, chanceAllowed: Bool, now: Date = Date()) -> OroShopOutcome {
        guard let content, var player, let context = oroShopContext(chanceAllowed: chanceAllowed, now: now) else {
            return .unavailable
        }
        let purchase: OroShop.Purchase
        do {
            purchase = try OroShop.purchase(id, state: &player, catalog: content.oroShop, context: context)
        } catch OroShop.PurchaseError.blocked(let blocker) {
            return .refused(blocker)
        } catch {
            return .unavailable
        }
        self.player = player
        if purchase.item.action == .mergeAll {
            enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .oroShop)
        }
        if !purchase.item.rewards.isEmpty {
            grant(purchase.item.rewards, source: "shop.\(id)", now: now.timeIntervalSince1970)
        }
        effectsVersion += 1
        audio?.play(.coin)
        refreshProjections()
        scheduleSave()
        Log.economy.info("oro shop: \(id) for \(purchase.price) ORO")
        return .bought
    }

    /// El nivel de "mejor proveedor" (0 sin comprar). El `r` de cada nivel es
    /// dato de E5 (`packages.json`); `openPackage()` lo lee de acá.
    var bestSupplierLevel: Int {
        guard let content, let player else { return 0 }
        return OroShop.bestSupplierLevel(levels: player.meta.engagement.shop.levels, catalog: content.oroShop)
    }

    /// Los giros por video de más por día del "abono a la ruleta".
    var bonusDailyWheelSpins: Int {
        guard let content, let player else { return 0 }
        return OroShop.bonusDailyWheelSpins(levels: player.meta.engagement.shop.levels, catalog: content.oroShop)
    }

    /// La ruleta con el abono aplicado: el ÚNICO lugar donde el cupo de giros por
    /// video crece. `wheelAvailability` y `spinWheel` (E5a T8) cuentan contra ésta.
    var effectiveWheel: WheelConfig? {
        content.map { $0.wheel.withBonusVideoSpins(bonusDailyWheelSpins) }
    }
```

`Packages/EconomyKit/Sources/EconomyKit/Shop/ShopPerks.swift` (el enchufe de giros en un archivo
de E6, sin tocar el `WheelConfig.swift` de E5):

```swift
import Foundation

extension WheelConfig {
    /// La misma ruleta con `bonus` giros por video de más por día (el "abono a
    /// la ruleta" de la tienda de ORO). Todo lo demás, igual.
    public func withBonusVideoSpins(_ bonus: Int) -> WheelConfig {
        guard bonus > 0 else { return self }
        return WheelConfig(
            schemaVersion: schemaVersion,
            videoSpinsPerDay: videoSpinsPerDay + bonus,
            oroSpinCost: oroSpinCost,
            oroSpinsPerDay: oroSpinsPerDay,
            spinSeconds: spinSeconds,
            chestFallbackSegmentId: chestFallbackSegmentId,
            segments: segments
        )
    }
}
```

(Si E5 sumó un campo a `WheelConfig`, se copia acá también: el paso 0 de esta tarea mira su
`init`.)

- [ ] **Step 5: Los dos enchufes de E5**

`GameState+Packages.swift` (E5a T6), en `openPackage()`, la línea del comentario
`// E6: el nivel del permanente "mejor proveedor".` pasa a:

```swift
        let ratio = content.packages.tierRatio(bestSupplierLevel: bestSupplierLevel)
```

(y el comentario se va: ya no es una promesa).

`GameState+Wheel.swift` (E5a T8): en `wheelAvailability(storefrontAllows:now:)` y en
`spinWheel(_:storefrontAllows:now:)`, cada `config: content.wheel` que cuenta o gasta cupo
(`WheelRoller.spinsLeft` y `WheelRoller.consume`) pasa a `config: wheelConfig` con, al principio
de cada función, junto al `guard let content` (en `spinWheel` la variable `wheel` ya es el
estado del día; por eso el nombre distinto):

```swift
        guard let wheelConfig = effectiveWheel else { return .none }   // en spinWheel: else { return nil }
```

El costo del giro con ORO (`content.wheel.oroSpinCost`) y la tabla (`wheelSegments`) no cambian.
Todo lo que E5b lee de la ruleta (la vista, Regalos, `wheelSpinsReadyAt` de `wheel_ready`) pasa
por `wheelAvailability`, así que con estos dos cambios el abono se ve en todos lados.

- [ ] **Step 6: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/OroShopPurchaseTests -only-testing:FisuEvolutionTests/DebugEconomyKnobsTests -only-testing:FisuEvolutionTests/PackageRuntimeTests -only-testing:FisuEvolutionTests/WheelRuntimeTests`
→ PASS (`OroShopPurchaseTests`: 13; las dos de E5 sin cambios: el nivel 0 da el `r` de siempre y
sin abono el cupo es el de siempre). `swift test --package-path Packages/EconomyKit` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+OroShop.swift Packages/EconomyKit/Sources/EconomyKit/Shop/ShopPerks.swift \
  Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift FisuEvolution/Game/State/GameState+BoardChanges.swift \
  FisuEvolution/Game/State/GameState+Packages.swift FisuEvolution/Game/State/GameState+Wheel.swift \
  FisuEvolutionTests/OroShopPurchaseTests.swift
git diff --cached --stat
git commit -m "feat(tienda): comprar con ORO, Fusionar todo por el embudo y los permanentes que enchufan en E5"
```

---

### Task 7: La suerte — probabilidades que no mienten, y la puerta de E5 también para lo síncrono

**Objetivo:** las dos garantías del azar pagado (Apple 3.1.1 y la decisión del dueño), sin crear
de nuevo lo que ya dejó E5:
**(1)** la probabilidad que se muestra es la que se sortea: `ChestRoller.effectiveOdds` recorre el
mismo embudo que `roll` (una rareza agotada pasa su chance a la que el sorteo promociona o
degrada; sólo cuentan los personajes desbloqueados; con la colección completa, el cofre paga
plata), devuelve las `PrizeOdds` de E5a (id = la rareza) y un test lo cruza contra 20.000
sorteos; **(2)** en las tiendas de `restrictedStorefronts` no se vende: la puerta es el
`LootBoxGate` de **E5a T8** (`current()` es `async` y falla cerrado). Esta tarea sólo le suma
**la última respuesta** (`lastKnown`), refrescada al arrancar, para el único camino síncrono de
E6: el tick que decide si la oferta de Bienvenida (que trae un cofre) se puede presentar.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ChestRoller.swift` (`ChestOddsTable`, `effectiveOdds`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/ChestOddsTests.swift`
- Create: `FisuEvolution/Managers/LootBoxGate+LastKnown.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Managers/Store/StoreManager.swift` (`start`: refresca la última respuesta)
- Modify: `FisuEvolution/Game/State/GameState+OroShop.swift` (`chestOdds`)
- Modify: `FisuEvolution/UI/Popups/ChestOpeningView.swift` (`ChestRarityStyle.name(_:)`, `.symbol(_:)`)
- Create: `FisuEvolutionTests/ChestOddsAppTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `ChestRoller.roll` y su `firstWithStock` privado (mismo archivo);
  `public struct PrizeOdds { id: String; probability: Double }` (**E5a T1**, `init(id:probability:)`);
  `enum LootBoxGate` con `allows(countryCode:restricted:)` y `current(loader:) async -> Bool`
  (**E5a T8**, `FisuEvolution/Managers/LootBoxGate.swift`).
- Produces: `public enum ChestOddsTable { skins([PrizeOdds]), coins, nothingYet }` (cada `id` es
  `SkinsConfig.Rarity.rawValue`), `ChestRoller.effectiveOdds(owned:unlocked:skins:config:minRarity:) -> ChestOddsTable`;
  `@MainActor static var LootBoxGate.lastKnown: Bool` (arranca en `false`) y
  `@MainActor static func LootBoxGate.refreshLastKnown(loader:) async -> Bool`;
  `GameState.chestOdds: ChestOddsTable`; `ChestRarityStyle.name(_:) -> String`,
  `ChestRarityStyle.symbol(_:) -> String`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "enum LootBoxGate\|static func current\|static func allows" FisuEvolution/Managers/LootBoxGate.swift`
(E5a T8) y `grep -rn "public struct PrizeOdds" Packages/EconomyKit/Sources` (E5a T1). Si no están,
**se para**: esta tarea va después de E5a (tabla de olas). Y
`grep -rn "struct OddsDisclosureView" FisuEvolution` (E5b T1): la usan la T8 y la T12, no ésta;
si E5b todavía no se integró, la T8 espera.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/ChestOddsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Las probabilidades del cofre: lo que se muestra es lo que se sortea")
struct ChestOddsTests {
    /// Las `PrizeOdds` de E5a llevan la rareza en el `id`.
    private func shares(_ table: ChestOddsTable) -> [SkinsConfig.Rarity: Double] {
        guard case .skins(let odds) = table else { return [:] }
        return Dictionary(uniqueKeysWithValues: odds.compactMap { row in
            SkinsConfig.Rarity(rawValue: row.id).map { ($0, row.probability) }
        })
    }

    @Test("cada fila es una rareza, en orden, y suman 1")
    func rowsAreRarities() {
        let skins = fxChestSkins()
        guard case .skins(let odds) = ChestRoller.effectiveOdds(
            owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()
        ) else {
            Issue.record("con todo desbloqueado hay tabla")
            return
        }
        #expect(odds.map(\.id) == SkinsConfig.Rarity.allCases.map(\.rawValue))
        #expect(abs(odds.map(\.probability).reduce(0, +) - 1) < 1e-12)
    }

    @Test("con todo disponible, son los pesos del dato")
    func rawWeights() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()))
        #expect(abs((odds[.comun] ?? 0) - 0.55) < 1e-12)
        #expect(abs((odds[.rara] ?? 0) - 0.28) < 1e-12)
        #expect(abs((odds[.epica] ?? 0) - 0.12) < 1e-12)
        #expect(abs((odds[.legendaria] ?? 0) - 0.05) < 1e-12)
    }

    @Test("una rareza agotada pasa su chance a la que el sorteo promociona")
    func exhaustedPromotes() {
        let skins = fxChestSkins()
        let comunes = Set(skins.chestPool.filter { $0.chestRarity == .comun }.map(\.id))
        let odds = shares(ChestRoller.effectiveOdds(owned: comunes, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()))
        #expect(odds[.comun] == nil)
        #expect(abs((odds[.rara] ?? 0) - 0.83) < 1e-12, "las comunes suben a raras")
    }

    @Test("sólo lo desbloqueado: lo de arriba degrada hacia abajo")
    func lockedDegrades() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(
            owned: [], unlocked: fxDesbloqueadoHasta(skins, .comun, .rara), skins: skins, config: fxChests()
        ))
        #expect(abs((odds[.comun] ?? 0) - 0.55) < 1e-12)
        #expect(abs((odds[.rara] ?? 0) - 0.45) < 1e-12, "épica y legendaria bajan a rara")
        #expect(odds[.epica] == nil)
    }

    @Test("el cofre de prestigio sólo sortea de épica para arriba")
    func minimumRarity() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(
            owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), minRarity: .epica
        ))
        #expect(abs((odds[.epica] ?? 0) - 12.0 / 17.0) < 1e-12)
        #expect(abs((odds[.legendaria] ?? 0) - 5.0 / 17.0) < 1e-12)
    }

    @Test("colección completa: paga plata; nada alcanzable todavía: no hay tabla")
    func noSkinsCases() {
        let skins = fxChestSkins()
        let all = Set(skins.chestPool.map(\.id))
        #expect(ChestRoller.effectiveOdds(owned: all, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()) == .coins)
        #expect(ChestRoller.effectiveOdds(owned: [], unlocked: [], skins: skins, config: fxChests()) == .nothingYet)
    }

    @Test("la tabla coincide con 20.000 sorteos de verdad")
    func matchesTheRolls() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.filter { $0.chestRarity == .comun }.prefix(5).map(\.id))
        let unlocked = fxDesbloqueadoHasta(skins, .comun, .rara, .epica)
        let odds = shares(ChestRoller.effectiveOdds(owned: owned, unlocked: unlocked, skins: skins, config: fxChests()))
        var rng = SeededRNG(seed: 7)
        var counts: [SkinsConfig.Rarity: Int] = [:]
        let rolls = 20_000
        for _ in 0..<rolls {
            if case .prize(.skin(_, _, let rarity)) = ChestRoller.roll(
                owned: owned, unlocked: unlocked, skins: skins, config: fxChests(), using: &rng
            ) {
                counts[rarity, default: 0] += 1
            }
        }
        for rarity in SkinsConfig.Rarity.allCases {
            let seen = Double(counts[rarity] ?? 0) / Double(rolls)
            #expect(abs(seen - (odds[rarity] ?? 0)) < 0.01, "\(rarity): sorteado \(seen), mostrado \(odds[rarity] ?? 0)")
        }
    }
}
```

`FisuEvolutionTests/ChestOddsAppTests.swift` (las reglas de la puerta ya las prueba
`LootBoxGateTests` de E5a; acá sólo lo que E6 le suma):

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La suerte de la tienda: la tabla del cofre y la última respuesta de la puerta")
@MainActor
struct ChestOddsAppTests {
    @Test("sin config que leer, la última respuesta queda cerrada (falla cerrado, como E5a)")
    func lastKnownFailsClosed() async {
        let nowhere = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "no-cache-\(UUID().uuidString).json"),
            bundledURL: nil
        )
        #expect(await LootBoxGate.refreshLastKnown(loader: nowhere) == false)
        #expect(LootBoxGate.lastKnown == false)
    }

    @Test("el juego muestra las probabilidades de su cofre de hoy")
    func gameStateOdds() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 12)
        guard case .skins(let odds) = gameState.chestOdds else {
            Issue.record("con pisos abiertos el cofre tiene qué dar")
            return
        }
        #expect(abs(odds.map(\.probability).reduce(0, +) - 1) < 1e-9)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter ChestOddsTests` → no compila
(`effectiveOdds`). `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/ChestOddsAppTests` → no compila (`refreshLastKnown`, `chestOdds`).

- [ ] **Step 3: Las probabilidades efectivas**

`ChestRoller.swift`, arriba de `public enum ChestRoller`:

```swift
/// Lo que un cofre puede dar hoy, para mostrarlo ANTES de comprar (Apple 3.1.1).
public enum ChestOddsTable: Sendable, Equatable {
    /// Las rarezas con su chance real (`id` = `Rarity.rawValue`), en orden de
    /// rareza; suman 1. Las mismas `PrizeOdds` que la ruleta y el colchón.
    case skins([PrizeOdds])
    /// La colección está completa: el cofre paga plata.
    case coins
    /// No hay ninguna pinta alcanzable todavía: el cofre espera (`needsProgress`).
    case nothingYet
}
```

y dentro de `ChestRoller`, después de `hasSomethingToGive`:

```swift
    /// Las probabilidades que de verdad sortea `roll`: el peso de cada rareza
    /// candidata va a la rareza en la que TERMINA (`firstWithStock`: sube si se
    /// agotó, baja si lo de arriba está bloqueado). Mostrar los pesos crudos de
    /// `chests.json` mentiría apenas el jugador tiene la mitad de la colección.
    public static func effectiveOdds(
        owned: Set<String>,
        unlocked: Set<String>,
        skins: SkinsConfig,
        config: ChestsConfig,
        minRarity: SkinsConfig.Rarity? = nil
    ) -> ChestOddsTable {
        let candidatas = SkinsConfig.Rarity.allCases.filter { $0 >= (minRarity ?? .comun) }
        let total = candidatas.reduce(0) { $0 + config.weight(for: $1) }
        var odds: [SkinsConfig.Rarity: Double] = [:]
        for rarity in candidatas {
            // Sin pesos, `weightedPick` devuelve la primera: la misma regla.
            let share = total > 0
                ? Double(config.weight(for: rarity)) / Double(total)
                : (rarity == candidatas.first ? 1 : 0)
            guard share > 0 else { continue }
            guard let resuelta = firstWithStock(from: rarity, owned: owned, unlocked: unlocked, skins: skins) else {
                return skins.chestPool.allSatisfy { owned.contains($0.id) } ? .coins : .nothingYet
            }
            odds[resuelta, default: 0] += share
        }
        return .skins(SkinsConfig.Rarity.allCases.compactMap { rarity in
            odds[rarity].map { PrizeOdds(id: rarity.rawValue, probability: $0) }
        })
    }
```

- [ ] **Step 4: La última respuesta de la puerta de E5a**

`FisuEvolution/Managers/LootBoxGate+LastKnown.swift` (al lado del `LootBoxGate.swift` de E5a T8,
que no se toca):

```swift
import Foundation

/// `LootBoxGate.current()` (E5a) pregunta a StoreKit y es `async`. Lo que se
/// decide dentro de un tick —si la oferta de Bienvenida, que trae un cofre, se
/// puede presentar— necesita una respuesta ya: la última que se obtuvo. Arranca
/// cerrada, como la puerta: hasta que StoreKit conteste, no se ofrece azar.
extension LootBoxGate {
    @MainActor static private(set) var lastKnown = false

    /// Pregunta de nuevo y guarda la respuesta.
    @MainActor
    @discardableResult
    static func refreshLastKnown(loader: AdsRemoteConfigLoader = AdsRemoteConfigLoader()) async -> Bool {
        let allows = await current(loader: loader)
        lastKnown = allows
        return allows
    }
}
```

`StoreManager.start(gameState:)`, después de `await loadProducts()`:

```swift
        // La puerta del azar (E5a), para lo que se decide sin esperar a StoreKit.
        // Bajo XCTest no: las suites deciden la puerta por parámetro.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            await LootBoxGate.refreshLastKnown()
        }
```

(Las pantallas —la tienda de ORO de la T8, la hoja de la oferta de la T12— no leen `lastKnown`:
preguntan `await LootBoxGate.current()` en su `.task`, como la ruleta de E5b.)

`GameState+OroShop.swift`:

```swift
    /// Las probabilidades del cofre de pintas para ESTE jugador (Apple 3.1.1): la
    /// tabla que sortea `ChestRoller.roll`, con su colección y su desbloqueo de hoy.
    var chestOdds: ChestOddsTable {
        guard let content, let player else { return .nothingYet }
        return ChestRoller.effectiveOdds(
            owned: player.meta.allOwnedSkins, unlocked: chestUnlockedCharacterTypes,
            skins: content.skins, config: content.chests
        )
    }
```

`ChestOpeningView.swift`, en `ChestRarityStyle` (las claves de a una, por la regla de su
comentario):

```swift
    /// El nombre ya traducido, para las tablas de probabilidades.
    static func name(_ rarity: SkinsConfig.Rarity) -> String {
        switch rarity {
        case .comun: String(localized: "chest.rarity.comun")
        case .rara: String(localized: "chest.rarity.rara")
        case .epica: String(localized: "chest.rarity.epica")
        case .legendaria: String(localized: "chest.rarity.legendaria")
        }
    }

    /// El ícono de la fila (SF Symbols), para `OddsDisclosureView.Row.symbol`.
    static func symbol(_ rarity: SkinsConfig.Rarity) -> String {
        switch rarity {
        case .comun: "circle.fill"
        case .rara: "diamond.fill"
        case .epica: "star.fill"
        case .legendaria: "crown.fill"
        }
    }
```

No se crea ninguna vista de probabilidades: la T8 y la T12 usan la `OddsDisclosureView` de
**E5b T1** (`UI/Art/OddsDisclosureView.swift`). Esta tarea no agrega claves al catálogo.

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter ChestOddsTests` → PASS (7); el
paquete entero → PASS. `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/ChestOddsAppTests -only-testing:FisuEvolutionTests/LootBoxGateTests -only-testing:FisuEvolutionTests/ChestSourcesTests`
→ PASS (`LootBoxGateTests` es la de E5a, sin cambios). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ChestRoller.swift Packages/EconomyKit/Tests/EconomyKitTests/ChestOddsTests.swift \
  FisuEvolution/Managers/LootBoxGate+LastKnown.swift FisuEvolution/Managers/Store/StoreManager.swift \
  FisuEvolution/Game/State/GameState+OroShop.swift FisuEvolution/UI/Popups/ChestOpeningView.swift \
  FisuEvolutionTests/ChestOddsAppTests.swift
git diff --cached --stat
git commit -m "feat(tienda): las probabilidades del cofre son las que se sortean, y la puerta del azar también responde sin esperar"
```

---

### Task 8: La pantalla — "Comprar ORO / Gastar ORO"

**Objetivo:** la tienda gana su segunda mitad sin una séptima pestaña (PLAN-v2): un selector en
la cabecera de `StoreView` —visible siempre, también con StoreKit caído— que abre en "Comprar
ORO" (las filas de IAP de siempre; `StoreUITests` no cambia) y pasa a "Gastar ORO": el saldo y
los cuatro estantes de `oro_shop.json` en filas `GameCard` + `PricePill(.oro)`, con el motivo
cuando algo no se puede comprar (tope del día, uno pendiente, al máximo, nada que hacer) y las
probabilidades **debajo** de cada fila de azar. La pestaña "Gastar ORO" publica el ancla del
tutorial `.oroShop` para la lección de E9.

**Files:**
- Modify: `FisuEvolution/UI/Store/StoreView.swift` (`Segment`, el selector en la cabecera, el cuerpo según el segmento)
- Create: `FisuEvolution/UI/Store/OroShopView.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`TutorialTarget.oroShop`)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`--uitest-oro=<n>`)
- Create: `FisuEvolutionUITests/OroShopUITests.swift` (+ `xcodegen generate`)
- Strings: `Tools/v2/claves-pendientes/e6a-t8.json` (8 claves)

**Interfaces:**
- Consumes: `oroShopRows`, `buyOroShopItem`, `OroShopRow`, `OroShopOutcome` (T6); `chestOdds`,
  `ChestRarityStyle.name/symbol` (T7); `LootBoxGate.current() async` (**E5a T8**);
  `OddsDisclosureView(titleKey:rows:identifier:)` y `OddsDisclosureView.Row(id:title:symbol:probability:)`
  (**E5b T1**); `OroShopCopy` (T4); `applyEngagementFixtures(arguments:)`, `fixtureValue(_:in:)`
  (**E4a T9**).
- Produces: `StoreView.Segment` (`buy`, `spend`) con los ids `store.segment.buy` /
  `store.segment.spend`; `struct OroShopShelves: View`; los ids `oroShop.balance`,
  `oroShop.buy.<id>`, `oroShop.status.<id>`, `oroShop.blocked.<id>`, `oroShop.maxed.<id>`;
  `TutorialTarget.oroShop`; la puerta `--uitest-oro=<n>`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "struct OddsDisclosureView\|struct Row\|let identifier" FisuEvolution/UI/Art/OddsDisclosureView.swift`
(E5b T1). Si E5b cambió un nombre al integrarse, `oddsRows(for:)` y la T12 usan el suyo (el
reporte lo anota); **no se crea otra vista**. Y copiá los argumentos de lanzamiento de
`StoreUITests.openStore()` (E3a T9 pudo sumar uno para que la pestaña Tienda esté visible en una
partida nueva): `OroShopUITests` usa los mismos.

- [ ] **Step 1: El test de UI, en rojo**

`FisuEvolutionUITests/OroShopUITests.swift`:

```swift
import XCTest

/// La tienda de ORO (PLAN-v2 E6): el selector en la cabecera de la Tienda, las
/// filas que cobran y el saldo que baja. Todo por identifier: el runner corre en
/// inglés (trampa 6).
final class OroShopUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openStore(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
        app.launch()
        let store = app.buttons["hud.store"]
        XCTAssertTrue(store.waitForExistence(timeout: 20), "el botón de la tienda nunca apareció")
        store.tap()
        return app
    }

    @MainActor
    func testTheStoreStillOpensOnTheMoneySide() throws {
        let app = openStore()
        XCTAssertTrue(app.buttons["store.segment.buy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["store.segment.spend"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["oroShop.balance"].exists, "abre en Comprar ORO: App Review ve primero los IAP")
    }

    @MainActor
    func testTheOroShopChargesAndCountsTheDay() throws {
        let app = openStore(["--uitest-oro=500"])
        let spend = app.buttons["store.segment.spend"]
        XCTAssertTrue(spend.waitForExistence(timeout: 10))
        spend.tap()

        // `descendants(.any)`: la píldora combina ícono y texto, y el tipo del
        // elemento combinado no está garantizado.
        let balance = app.descendants(matching: .any)["oroShop.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        XCTAssertEqual(balance.value as? String, "500")

        let buy = app.buttons["oroShop.buy.income_x2"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        attach(app, named: "E6 la tienda de ORO")
        buy.tap()

        let charged = NSPredicate(format: "value == %@", "470")
        expectation(for: charged, evaluatedWith: balance)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["oroShop.status.income_x2"].exists, "la fila dice cuántos van hoy")
        attach(app, named: "E6 después de comprar")
    }

    @MainActor
    func testEveryShelfIsThere() throws {
        let app = openStore(["--uitest-oro=500"])
        app.buttons["store.segment.spend"].tap()
        for id in ["income_x2", "time_jump_1h", "offline_x3"] {
            XCTAssertTrue(app.buttons["oroShop.buy.\(id)"].waitForExistence(timeout: 5), "\(id) no se ofrece")
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate`, el `build-for-testing` de la Receta R y
`-only-testing:FisuEvolutionUITests/OroShopUITests`.
Expected: falla (`store.segment.buy` no existe).

- [ ] **Step 3: La puerta de test y el ancla**

`GameState+Engagement.swift`, en `applyEngagementFixtures(arguments:)` (dentro del `#if DEBUG`):

```swift
        // El ORO para ejercitar la tienda sin reencarnar.
        if let oro = Self.fixtureValue("--uitest-oro=", in: arguments).flatMap(Int.init), var player {
            player.meta.oro = oro
            self.player = player
            refreshProjections()
        }
```

`TutorialAnchor.swift`, en `TutorialTarget`, después de `store`:

```swift
    /// La mitad "Gastar ORO" de la tienda (E6): la lección de la tienda de ORO (E9).
    case oroShop
```

- [ ] **Step 4: Los estantes**

`FisuEvolution/UI/Store/OroShopView.swift`:

```swift
import EconomyKit
import SwiftUI

/// "Gastar ORO" (PLAN-v2 E6): el saldo y los estantes de `oro_shop.json`. Vive
/// ADENTRO de la hoja de la Tienda, debajo de su selector: misma columna, mismas
/// `GameCard` y el mismo `PricePill` que FisuJobs y Mejoras.
///
/// La vista no decide nada: dibuja `oroShopRows` y llama a `buyOroShopItem`.
/// Se re-evalúa contra `effectsVersion` y `oroText`, que es lo que mueve una compra.
struct OroShopShelves: View {
    @Environment(GameState.self) private var gameState
    /// El azar pagado se vende acá (`LootBoxGate` de E5a); lo resuelve la hoja una vez.
    let chanceAllowed: Bool

    var body: some View {
        let _ = gameState.effectsVersion
        let _ = gameState.oroText
        let rows = gameState.oroShopRows(chanceAllowed: chanceAllowed).filter { !$0.item.isChance || oddsRows(for: $0) != nil }
        VStack(spacing: Tokens.s12) {
            OroBalancePill(text: gameState.oroText)
            ForEach(OroShopCatalog.Shelf.allCases, id: \.self) { shelf in
                let shelfRows = rows.filter { $0.item.shelf == shelf }
                if !shelfRows.isEmpty {
                    SectionHeader(LocalizedStringKey(OroShopCopy.shelfKey(shelf)))
                        .frame(maxWidth: .infinity)
                        .padding(.top, Tokens.s8)
                    ForEach(Array(shelfRows.enumerated()), id: \.element.id) { offset, row in
                        OroShopItemRow(row: row, odds: oddsRows(for: row)) {
                            gameState.buyOroShopItem(id: row.id, chanceAllowed: chanceAllowed)
                        }
                        .staggeredAppearance(index: offset)
                    }
                }
            }
        }
    }

    /// Las probabilidades de una fila de azar, o `nil` si no las hay: una fila de
    /// azar sin probabilidades no se dibuja (Apple 3.1.1). El único azar de este
    /// estante es el cofre de pintas; el giro extra lo vende la ruleta (E5a T8).
    private func oddsRows(for row: OroShopRow) -> [OddsDisclosureView.Row]? {
        guard row.item.isChance else { return [] }
        guard case .skinChest? = row.item.rewards.first,
              case .skins(let odds) = gameState.chestOdds
        else { return nil }
        return odds.compactMap { odds in
            SkinsConfig.Rarity(rawValue: odds.id).map {
                OddsDisclosureView.Row(id: odds.id, title: ChestRarityStyle.name($0),
                                       symbol: ChestRarityStyle.symbol($0), probability: odds.probability)
            }
        }
    }
}

/// El saldo de ORO, con el número como valor de accesibilidad para los tests.
private struct OroBalancePill: View {
    let text: String

    var body: some View {
        HStack(spacing: Tokens.s4) {
            OroIcon(size: 18)
                .accessibilityHidden(true)
            Text("upgrades.oro_balance \(text)")
                .font(Tokens.body)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color("PaletteYellow").opacity(0.35))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.6), lineWidth: 2))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("oroShop.balance")
        .accessibilityValue(Text(verbatim: text))
    }
}

/// Una fila: ícono, nombre, qué da, cuántas van hoy (o el nivel) y el precio. La
/// tarjeta informa, el botón cobra (el patrón de FisuJobs).
private struct OroShopItemRow: View {
    let row: OroShopRow
    let odds: [OddsDisclosureView.Row]?
    let buy: () -> Void

    private var name: String { OroShopCopy.name(for: row.item) }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                HStack(spacing: Tokens.s12) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: name)
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(verbatim: OroShopCopy.detail(for: row.item, level: row.quote.level))
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteBlue"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        if let status {
                            Text(verbatim: status)
                                .font(Tokens.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                                .accessibilityIdentifier("oroShop.status.\(row.id)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    rail
                        .layoutPriority(1)
                }
                if let odds, !odds.isEmpty {
                    OddsDisclosureView(titleKey: "oroShop.chest.odds", rows: odds, identifier: "oroShop.odds")
                }
            }
        }
    }

    /// "Hoy: 1 de 3" en los que tienen tope; "Nivel 1/3" en los permanentes.
    private var status: String? {
        if row.item.isPermanent {
            return String(localized: "upgrades.level \(String(row.quote.level)) \(String(row.item.levels.count))")
        }
        guard let limit = row.item.dailyLimit else { return nil }
        return String(localized: "oroShop.today \(String(row.quote.boughtToday)) \(String(limit))")
    }

    @ViewBuilder private var rail: some View {
        switch row.quote.blocker {
        case .maxed?:
            StateBadge(text: String(localized: "upgrades.maxed"), systemImage: "star.circle.fill",
                       textAlignment: .center, muted: false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("oroShop.maxed.\(row.id)")
        case .dailyLimitReached?, .alreadyPending?, .nothingToDo?:
            StateBadge(text: blockedText, systemImage: "clock.fill", textAlignment: .center, muted: true)
                .frame(maxWidth: 110)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("oroShop.blocked.\(row.id)")
        case .cantAfford?, nil:
            PricePill(
                text: String(row.quote.price ?? 0),
                currency: .oro,
                affordable: row.quote.blocker == nil,
                identifier: "oroShop.buy.\(row.id)",
                accessibilityPurpose: Text("oroShop.buy.ax \(name)")
            ) {
                buy()
            }
        }
    }

    private var blockedText: String {
        switch row.quote.blocker {
        case .dailyLimitReached?: String(localized: "oroShop.blocked.daily")
        case .alreadyPending?: String(localized: "oroShop.blocked.pending")
        default: String(localized: "oroShop.blocked.nothing")
        }
    }

    /// El ícono de E8 si ya llegó; si no, el SF Symbol del dato, en el mismo marco
    /// que las filas de Mejoras.
    private var icon: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Color.clear
            .frame(width: 48, height: 48)
            .overlay {
                Group {
                    if let art = UIArt.image(row.item.iconKey) {
                        art.resizable().scaledToFit()
                    } else {
                        Image(systemName: row.item.symbol)
                            .resizable().scaledToFit()
                            .foregroundStyle(Color("PaletteOrange"))
                    }
                }
                .padding(8)
            }
            .background(Color("PaletteYellow").opacity(0.3))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }
}
```

(`ForEach(OroShopCatalog.Shelf.allCases, id: \.self)` necesita `Shelf: Hashable`, que ya tiene
por ser un `enum` con `rawValue`. Las filas de probabilidades quedan con ids
`oroShop.odds.<rareza>`, por el `identifier` de la vista de E5b.)

- [ ] **Step 5: El selector en la cabecera**

`StoreView.swift`:

```swift
    /// Las dos mitades de la tienda (PLAN-v2 E6): lo que se paga con plata y lo
    /// que se paga con ORO. Abre siempre en la plata: es lo que revisa App Review
    /// y lo que pinea `StoreUITests`.
    enum Segment: String, CaseIterable {
        case buy
        case spend
    }

    @State private var segment: Segment = .buy
    /// La puerta del azar de E5a, una vez por apertura. Arranca cerrada, como la
    /// puerta: hasta que StoreKit conteste, el cofre no se ofrece.
    @State private var chanceAllowed = false
```

En `body`, el `VStack(spacing: Tokens.s12) { switch store.loadState { … } }` pasa a:

```swift
                VStack(spacing: Tokens.s12) {
                    switch segment {
                    case .buy:
                        moneySide
                    case .spend:
                        OroShopShelves(chanceAllowed: chanceAllowed)
                    }
                }
```

con `moneySide` = el `switch store.loadState { … }` de hoy, sin cambios, movido a una propiedad
`@ViewBuilder private var moneySide: some View`. Después de `.onReceive(tick)`:

```swift
            .task { chanceAllowed = await LootBoxGate.current() }
```

En `header`, entre la bajada (`store.subtitle`) y "Restaurar", `segmentPicker`:

```swift
    /// Las dos mitades. Vive en la cabecera fija —se ve aunque StoreKit no
    /// cargue— y copia las pestañas de Mejoras (`UpgradesView.tabPicker`).
    /// ⚠️ El `HStack` no lleva identifier (trampa 9a-bis): lo lleva cada botón.
    private var segmentPicker: some View {
        HStack(spacing: Tokens.s4) {
            segmentButton(.buy, key: "store.segment.buy", symbol: "cart.fill")
            segmentButton(.spend, key: "store.segment.spend", symbol: "sparkles")
                .tutorialAnchor(.oroShop)
        }
        .padding(Tokens.s4)
        .background {
            Capsule()
                .fill(Color("PaletteBrown").opacity(0.12))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2))
        }
        .animation(.snappy(duration: 0.2), value: segment)
    }

    private func segmentButton(_ value: Segment, key: LocalizedStringKey, symbol: String) -> some View {
        let selected = segment == value
        return Button { segment = value } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .black))
                    .accessibilityHidden(true)
                Text(key)
                    .font(Tokens.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? Color.white : Color("PaletteInk").opacity(0.55))
            .shadow(color: .black.opacity(selected ? 0.35 : 0), radius: 1, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.s8)
            .background {
                if selected { PillBackground(fill: Color("PaletteOrange")) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("store.segment.\(value.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
```

El comentario de cabecera de `StoreView` ("lo único que se paga con plata de verdad…") se
corrige en el mismo commit: la hoja ahora tiene dos mitades y la de ORO no cobra plata.

`Tools/v2/claves-pendientes/e6a-t8.json`:

```json
{
  "store.segment.buy": {"es": "Comprar ORO", "en": "Buy ORO"},
  "store.segment.spend": {"es": "Gastar ORO", "en": "Spend ORO"},
  "oroShop.today %@ %@": {"es": "Hoy: %1$@ de %2$@", "en": "Today: %1$@ of %2$@"},
  "oroShop.blocked.daily": {"es": "Mañana hay más", "en": "More tomorrow"},
  "oroShop.blocked.pending": {"es": "Ya tenés uno esperando", "en": "One is already waiting"},
  "oroShop.blocked.nothing": {"es": "Ahora no hace nada", "en": "Nothing to do now"},
  "oroShop.buy.ax %@": {"es": "Comprar %@", "en": "Buy %@"},
  "oroShop.chest.odds": {"es": "Qué puede salir", "en": "What you can get"}
}
```

("Comprar ORO" es el nombre de la mitad de IAP aunque también venda plata y skins: es la palabra
que eligió el dueño en PLAN-v2.)

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6a-t8.json`.

- [ ] **Step 6: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionUITests/OroShopUITests -only-testing:FisuEvolutionUITests/BottomMenuUITests`
→ PASS (3 + los de siempre). Después `Tools/v2/oraculo.sh completo` → `VERDE` (`StoreUITests` en
18.6 sigue verde sin cambios: la tienda abre en la mitad de plata).

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/UI/Store/StoreView.swift FisuEvolution/UI/Store/OroShopView.swift \
  FisuEvolution/UI/Tutorial/TutorialAnchor.swift FisuEvolution/Game/State/GameState+Engagement.swift \
  FisuEvolutionUITests/OroShopUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6a-t8.json, según la ola
git diff --cached --stat
git commit -m "feat(tienda): Comprar ORO / Gastar ORO, los estantes con su tope y las probabilidades a la vista"
```

---

### Task 9: Los packs de ORO de la 2.0 — 160 / 550 / 1.400

**Objetivo:** los tres packs pasan a los montos aprobados (PLAN-v2 §2) sin tocar sus IDs ni su
precio, y dos garantías quedan pineadas: la foto de la v1 con la que E1 T6 reconstruye el ORO
comprado (250 / 750 / 2000) **no siguió** a `products.json`, y un pack nuevo suma a
`oroPurchasedLifetime` exactamente lo que dice el dato.

**Files:**
- Modify: `FisuEvolution/Resources/Config/products.json` (tres números)
- Modify: `FisuEvolutionTests/StorePacksTests.swift` (dos tests)
- Modify: `FisuEvolutionTests/StoreManagerTests.swift` (`purchasingAnOroPackCreditsSpendableOro`: 160)

**Interfaces:**
- Consumes: `PurchasedOroHistory.v1OroAmountByProductID` y `creditStorePurchase` `.oro` con
  `oroPurchasedLifetime` (**E1 T6**); `products.json` con `coinMinutes` (**E2a T7**).
- Produces: nada nuevo; los montos 160 / 550 / 1.400.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "v1OroAmountByProductID" -r FisuEvolution` (E1 T6) y
`grep -n "oroPurchasedLifetime" FisuEvolution/Game/State/GameState+Store.swift`. Si falta alguno,
`NEEDS_CONTEXT`: sin la foto de la v1, cambiar los montos le borraría a un veterano su ORO
comprado en el `min(saldo, comprado)` de E9.

- [ ] **Step 1: Los tests, en rojo**

En `StorePacksTests.swift`:

```swift
    @Test("los packs de ORO son los de la 2.0, con los mismos IDs, y la foto de la v1 no los siguió")
    func oroPacksAreThe2_0Amounts() throws {
        let catalog = try ProductCatalog.load(from: .main)
        let amounts = Dictionary(uniqueKeysWithValues: catalog.products.compactMap { entry in
            entry.oroAmount.map { (entry.id, $0) }
        })
        #expect(amounts == [
            "com.fisuevolution.iap.oro_small": 160,
            "com.fisuevolution.iap.oro_medium": 550,
            "com.fisuevolution.iap.oro_large": 1400,
        ])
        #expect(Set(amounts.keys) == Set(PurchasedOroHistory.v1OroAmountByProductID.keys), "los IDs no cambian")
        #expect(PurchasedOroHistory.v1OroAmountByProductID["com.fisuevolution.iap.oro_small"] == 250,
                "lo comprado en la v1 se reconstruye con lo que la v1 acreditaba")
    }

    @Test("un pack de la 2.0 suma al ORO comprado lo que dice products.json")
    func newPackCountsAsPurchased() async throws {
        let gameState = await makeGameState()
        let entry = try #require(try ProductCatalog.load(from: .main).products.first { $0.id == "com.fisuevolution.iap.oro_small" })
        let before = try #require(gameState.player?.meta)
        gameState.creditStorePurchase(entry, transactionID: "2.0-1")
        let after = try #require(gameState.player?.meta)
        #expect(after.oro == before.oro + 160)
        #expect(after.oroPurchasedLifetime == before.oroPurchasedLifetime + 160)
        #expect(after.oroEarnedLifetime == before.oroEarnedLifetime)
    }
```

(`makeGameState` acá es el privado de la suite, el que ya usa `makeRepository()`.) En
`StoreManagerTests.purchasingAnOroPackCreditsSpendableOro`: `before + 250` → `before + 160`, más
`#expect(gameState.player?.meta.oroPurchasedLifetime == 160)`.

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/StorePacksTests`.
Expected: FAIL en `oroPacksAreThe2_0Amounts` (250 ≠ 160) y `newPackCountsAsPurchased`.

- [ ] **Step 3: El dato**

`products.json`: `oro_small` → `"oroAmount": 160`, `oro_medium` → `550`, `oro_large` → `1400`.
Nada más (los packs de plata y su `coinMinutes` son de E2a T7).

Run: `grep -rn "250\|750\|2000\|2\.000" FisuEvolution/Managers/Store FisuEvolution/UI/Store FisuEvolution/Game/State/GameState+Store.swift`:
todo comentario que cite los montos viejos como vigentes se corrige ("los packs de la v1" o el
monto nuevo); la foto de `PurchasedOroHistory` **no se toca**.

- [ ] **Step 4: Verde, Receta S y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/StorePacksTests -only-testing:FisuEvolutionTests/IAPCopyTests -only-testing:FisuEvolutionTests/PurchasedOroHistoryTests`
→ PASS (`IAPCopyTests.everyOroPackSaysItsOwnAmount` lee el dato: pasa sin cambios). **Receta S**
(`StoreManagerTests`, `StoreProductsTests` en 18.6) → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Resources/Config/products.json FisuEvolutionTests/StorePacksTests.swift FisuEvolutionTests/StoreManagerTests.swift
git diff --cached --stat
git commit -m "feat(tienda): los packs de ORO de la 2.0, 160, 550 y 1.400, sin tocar la foto de la v1"
```

---

### Task 10: Las ofertas de 24 h, puras — disparadores, ventana y enfriamiento

**Objetivo:** `offers.json` como tipo validado y `OffersEngine`, que decide cuándo se abre cada
oferta (PLAN-v2 §2 y E6): **Bienvenida** el 2º día de juego y una sola vez por cuenta,
**Renacer** al reencarnar, **Mudanza** al abrir un piso nuevo; un reloj **real** de 24 h que no se
reinicia si el disparador vuelve a ocurrir; 3 días de enfriamiento desde que la ventana cierra
(venció o se compró); y la línea de base la primera vez, para que un veterano que actualiza no
reciba las tres de golpe. Lo que no se puede ofrecer (contenido que la app todavía no entrega,
azar en una tienda restringida) no se abre ni se gasta.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/Offers/OffersCatalog.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/Offers/OffersEngine.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/OffersEngineTests.swift`

**Interfaces:**
- Consumes: `OffersState`, `ActiveOffer` (T1); `RewardSpec` (E4a T1).
- Produces: `public struct OffersCatalog` con `Trigger` (`secondDay`, `reincarnation`,
  `newFloor`), `Offer` (`id`, `productId`, `trigger`, `oncePerAccount`, `isChance`, `iconKey`,
  `symbol`, `rewards`, `oroAmount`), `windowHours`, `cooldownDays`, `windowSeconds`,
  `cooldownSeconds`, `offer(id:)`, `offer(productId:)`, `validate()`, `ValidationError`;
  `public struct OfferSignals { today; firstLaunchDay; prestigeLevel; unlockedFloorCount }`;
  `public enum OffersEngine` con `evaluate(_:catalog:signals:now:isOfferable:) -> [String]`,
  `open(_:in:catalog:now:) -> Bool`, `canOpen(_:state:catalog:now:)`,
  `activeOffers(_:now:) -> [ActiveOffer]`, `markPurchased(_:in:now:)`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/OffersEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Las ofertas de 24 h: disparadores, ventana y enfriamiento")
struct OffersEngineTests {
    static let json = """
    {"schemaVersion": 1, "windowHours": 24, "cooldownDays": 3, "offers": [
      {"id": "bienvenida", "productId": "p.bienvenida", "trigger": "secondDay", "oncePerAccount": true, "isChance": true,
       "iconKey": "k", "symbol": "s",
       "rewards": [{"kind": "oro", "amount": 120}, {"kind": "coinsSeconds", "seconds": 7200}, {"kind": "skinChest", "count": 1}]},
      {"id": "renacer", "productId": "p.renacer", "trigger": "reincarnation", "iconKey": "k", "symbol": "s",
       "rewards": [{"kind": "oro", "amount": 300}]},
      {"id": "mudanza", "productId": "p.mudanza", "trigger": "newFloor", "iconKey": "k", "symbol": "s",
       "rewards": [{"kind": "oro", "amount": 500}, {"kind": "package", "count": 3}]}
    ]}
    """

    let catalog: OffersCatalog
    private let day: Double = 86_400

    init() throws {
        catalog = try JSONDecoder().decode(OffersCatalog.self, from: Data(Self.json.utf8))
    }

    private func signals(
        today: String = "2026-10-07", first: String? = "2026-10-07", prestige: Int = 0, floors: Int = 1
    ) -> OfferSignals {
        OfferSignals(today: today, firstLaunchDay: first, prestigeLevel: prestige, unlockedFloorCount: floors)
    }

    @discardableResult
    private func evaluate(_ state: inout OffersState, _ signals: OfferSignals, now: Double, offerable: Bool = true) -> [String] {
        OffersEngine.evaluate(&state, catalog: catalog, signals: signals, now: now, isOfferable: { _ in offerable })
    }

    @Test("el catálogo se lee y se valida")
    func catalogDecodes() throws {
        try catalog.validate()
        #expect(catalog.windowSeconds == 86_400)
        #expect(catalog.cooldownSeconds == 3 * 86_400)
        #expect(catalog.offer(id: "renacer")?.oroAmount == 300)
        #expect(catalog.offer(productId: "p.mudanza")?.id == "mudanza")
        #expect(catalog.offer(id: "bienvenida")?.oncePerAccount == true)
        #expect(catalog.offer(id: "renacer")?.oncePerAccount == false)
    }

    @Test("la primera vez sólo toma la línea de base: un veterano no recibe tres ofertas al actualizar")
    func baselineFirst() {
        var state = OffersState.initial
        #expect(evaluate(&state, signals(prestige: 4, floors: 6), now: 0).isEmpty)
        #expect(state.seenPrestigeLevel == 4)
        #expect(state.seenUnlockedFloors == 6)
    }

    @Test("Bienvenida sale el 2º día, y una sola vez por cuenta")
    func welcomeOnce() {
        var state = OffersState.initial
        #expect(evaluate(&state, signals(), now: 0).isEmpty, "el primer día, no")
        #expect(evaluate(&state, signals(today: "2026-10-08"), now: day) == ["bienvenida"])
        evaluate(&state, signals(today: "2026-10-09"), now: 2 * day)
        #expect(OffersEngine.activeOffers(state, now: 2 * day).isEmpty, "venció a las 24 h")
        #expect(evaluate(&state, signals(today: "2026-10-20"), now: 13 * day).isEmpty, "no vuelve nunca")
    }

    @Test("Renacer sale al reencarnar y dura 24 h de reloj")
    func rebirthWindow() throws {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        #expect(evaluate(&state, signals(prestige: 2), now: 100) == ["renacer"])
        let offer = try #require(OffersEngine.activeOffers(state, now: 100).first)
        #expect(offer.expiresAt == 100 + day)
        #expect(!offer.presented)
        #expect(OffersEngine.activeOffers(state, now: 100 + day).isEmpty)
    }

    @Test("volver a dispararse no estira la ventana")
    func retriggerDoesNotExtend() throws {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        evaluate(&state, signals(prestige: 2), now: 100)
        #expect(evaluate(&state, signals(prestige: 3), now: 3_700).isEmpty)
        #expect(try #require(state.active.first).expiresAt == 100 + day)
    }

    @Test("cerrada la ventana, 3 días de enfriamiento")
    func cooldown() {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        evaluate(&state, signals(prestige: 2), now: 0)
        evaluate(&state, signals(prestige: 2), now: day)
        #expect(state.lastClosedAt["renacer"] == day)
        #expect(evaluate(&state, signals(prestige: 3), now: day + 2 * day).isEmpty, "a los 2 días, todavía no")
        #expect(evaluate(&state, signals(prestige: 4), now: day + 3 * day) == ["renacer"])
    }

    @Test("Mudanza sale al abrir un piso; reencarnar no la dispara")
    func movingDay() {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 0, floors: 3), now: 0)
        #expect(evaluate(&state, signals(prestige: 0, floors: 4), now: 10) == ["mudanza"])
        var other = OffersState.initial
        evaluate(&other, signals(prestige: 0, floors: 5), now: 0)
        #expect(evaluate(&other, signals(prestige: 1, floors: 1), now: 10) == ["renacer"], "la run nueva arranca con un piso")
        #expect(other.seenUnlockedFloors == 1)
    }

    @Test("comprar cierra la ventana y arranca el enfriamiento")
    func purchaseCloses() {
        var state = OffersState.initial
        evaluate(&state, signals(prestige: 1), now: 0)
        evaluate(&state, signals(prestige: 2), now: 0)
        OffersEngine.markPurchased("renacer", in: &state, now: 500)
        #expect(state.active.isEmpty)
        #expect(state.purchases["renacer"] == 1)
        #expect(state.lastClosedAt["renacer"] == 500)
    }

    @Test("una compra fuera de la ventana se cuenta igual")
    func purchaseOutsideTheWindow() {
        var state = OffersState.initial
        OffersEngine.markPurchased("mudanza", in: &state, now: 9_999)
        #expect(state.purchases["mudanza"] == 1)
        #expect(state.lastClosedAt["mudanza"] == nil, "no había ventana que cerrar")
    }

    @Test("lo que no se puede ofrecer no se abre, y no se gasta")
    func notOfferable() {
        var state = OffersState.initial
        #expect(evaluate(&state, signals(today: "2026-10-08"), now: day, offerable: false).isEmpty)
        #expect(!state.everOpened.contains("bienvenida"))
        #expect(evaluate(&state, signals(today: "2026-10-09"), now: 2 * day) == ["bienvenida"])
    }

    @Test("el validador rechaza ids repetidos, ofertas vacías y azar sin declarar")
    func validation() throws {
        func decode(_ offers: String) throws -> OffersCatalog {
            try JSONDecoder().decode(OffersCatalog.self, from: Data(#"{"schemaVersion": 1, "windowHours": 24, "cooldownDays": 3, "offers": [\#(offers)]}"#.utf8))
        }
        let a = #"{"id": "a", "productId": "p.a", "trigger": "newFloor", "iconKey": "k", "symbol": "s", "rewards": [{"kind": "oro", "amount": 1}]}"#
        #expect(throws: OffersCatalog.ValidationError.duplicateID("a")) { try decode("\(a), \(a)").validate() }
        let empty = #"{"id": "e", "productId": "p.e", "trigger": "newFloor", "iconKey": "k", "symbol": "s", "rewards": []}"#
        #expect(throws: OffersCatalog.ValidationError.emptyRewards("e")) { try decode(empty).validate() }
        let chest = #"{"id": "c", "productId": "p.c", "trigger": "newFloor", "iconKey": "k", "symbol": "s", "rewards": [{"kind": "skinChest", "count": 1}]}"#
        #expect(throws: OffersCatalog.ValidationError.chanceNotDeclared("c")) { try decode(chest).validate() }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter OffersEngineTests`
Expected: no compila (`OffersCatalog` no existe).

- [ ] **Step 3: El catálogo**

`Packages/EconomyKit/Sources/EconomyKit/Offers/OffersCatalog.swift`:

```swift
import Foundation

/// Las ofertas de 24 h (`offers.json`, PLAN-v2 E6). Cada una es un consumible de
/// StoreKit que entrega un paquete de `RewardSpec`.
public struct OffersCatalog: Codable, Sendable, Equatable {
    public enum Trigger: String, Codable, Sendable, CaseIterable {
        /// El 2º día de juego (con `oncePerAccount`, una sola vez).
        case secondDay
        /// Al reencarnar.
        case reincarnation
        /// Al abrir un piso nuevo en la run.
        case newFloor
    }

    public struct Offer: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let productId: String
        public let trigger: Trigger
        public let oncePerAccount: Bool
        /// Trae azar (un cofre): probabilidades a la vista y apagada en las
        /// tiendas restringidas (Apple 3.1.1, decisión "loot boxes").
        public let isChance: Bool
        public let iconKey: String
        public let symbol: String
        public let rewards: [RewardSpec]

        /// El ORO que trae: es ORO **comprado** (`oroPurchasedLifetime`).
        public var oroAmount: Int {
            rewards.reduce(0) { total, reward in
                guard case .oro(let amount) = reward else { return total }
                return total + amount
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            productId = try container.decode(String.self, forKey: .productId)
            trigger = try container.decode(Trigger.self, forKey: .trigger)
            oncePerAccount = try container.decodeIfPresent(Bool.self, forKey: .oncePerAccount) ?? false
            isChance = try container.decodeIfPresent(Bool.self, forKey: .isChance) ?? false
            iconKey = try container.decode(String.self, forKey: .iconKey)
            symbol = try container.decode(String.self, forKey: .symbol)
            rewards = try container.decode([RewardSpec].self, forKey: .rewards)
        }
    }

    public enum ValidationError: Error, Equatable {
        case duplicateID(String)
        case duplicateProduct(String)
        case emptyRewards(String)
        case badReward(String)
        /// Trae un cofre y no lo declara: se vendería azar sin probabilidades.
        case chanceNotDeclared(String)
        case nonPositiveWindow
        case negativeCooldown
    }

    public let schemaVersion: Int
    public let windowHours: Double
    public let cooldownDays: Double
    public let offers: [Offer]

    public var windowSeconds: Double { windowHours * 3600 }
    public var cooldownSeconds: Double { cooldownDays * 86_400 }

    public func offer(id: String) -> Offer? { offers.first { $0.id == id } }
    public func offer(productId: String) -> Offer? { offers.first { $0.productId == productId } }

    public func validate() throws {
        guard windowHours > 0 else { throw ValidationError.nonPositiveWindow }
        guard cooldownDays >= 0 else { throw ValidationError.negativeCooldown }
        var ids = Set<String>()
        var products = Set<String>()
        for offer in offers {
            guard ids.insert(offer.id).inserted else { throw ValidationError.duplicateID(offer.id) }
            guard products.insert(offer.productId).inserted else { throw ValidationError.duplicateProduct(offer.productId) }
            guard !offer.rewards.isEmpty else { throw ValidationError.emptyRewards(offer.id) }
            do {
                try offer.rewards.forEach { try $0.validate() }
            } catch {
                throw ValidationError.badReward(offer.id)
            }
            if offer.rewards.contains(where: { $0.kind == .skinChest }), !offer.isChance {
                throw ValidationError.chanceNotDeclared(offer.id)
            }
        }
    }
}
```

- [ ] **Step 4: El motor**

`Packages/EconomyKit/Sources/EconomyKit/Offers/OffersEngine.swift`:

```swift
import Foundation

/// Lo que la app sabe de la partida y el motor necesita para disparar.
public struct OfferSignals: Sendable, Equatable {
    /// "yyyy-MM-dd" de hoy.
    public let today: String
    public let firstLaunchDay: String?
    public let prestigeLevel: Int
    /// Pisos abiertos en la run (`run.unlockedFloors.count`).
    public let unlockedFloorCount: Int

    public init(today: String, firstLaunchDay: String?, prestigeLevel: Int, unlockedFloorCount: Int) {
        self.today = today
        self.firstLaunchDay = firstLaunchDay
        self.prestigeLevel = prestigeLevel
        self.unlockedFloorCount = unlockedFloorCount
    }
}

/// Cuándo se abre y se cierra cada oferta (PLAN-v2 E6). Puro: el `now` es de
/// pared y lo pasa la app; el "ofrecible" también (lo entregable y el azar los
/// sabe ella).
public enum OffersEngine {
    /// Cierra las vencidas, mira los disparadores y abre lo que corresponde.
    /// Devuelve los ids que se abrieron ahora.
    @discardableResult
    public static func evaluate(
        _ state: inout OffersState,
        catalog: OffersCatalog,
        signals: OfferSignals,
        now: Double,
        isOfferable: (OffersCatalog.Offer) -> Bool
    ) -> [String] {
        closeExpired(&state, now: now)
        var fired: Set<OffersCatalog.Trigger> = []
        if let first = signals.firstLaunchDay, signals.today > first { fired.insert(.secondDay) }
        // La primera vez sólo se toma la línea de base: lo que ya pasó no dispara.
        if let seen = state.seenPrestigeLevel, signals.prestigeLevel > seen { fired.insert(.reincarnation) }
        state.seenPrestigeLevel = signals.prestigeLevel
        // Una run nueva arranca con menos pisos: se baja la línea sin disparar.
        if let seen = state.seenUnlockedFloors, signals.unlockedFloorCount > seen { fired.insert(.newFloor) }
        state.seenUnlockedFloors = signals.unlockedFloorCount

        var opened: [String] = []
        for offer in catalog.offers where fired.contains(offer.trigger) && isOfferable(offer) {
            if open(offer.id, in: &state, catalog: catalog, now: now) { opened.append(offer.id) }
        }
        return opened
    }

    /// Abre una oferta si se puede. Lo usa `evaluate` y la puerta de test.
    @discardableResult
    public static func open(_ id: String, in state: inout OffersState, catalog: OffersCatalog, now: Double) -> Bool {
        guard let offer = catalog.offer(id: id), canOpen(offer, state: state, catalog: catalog, now: now) else { return false }
        state.active.append(ActiveOffer(id: id, openedAt: now, expiresAt: now + catalog.windowSeconds, presented: false))
        state.everOpened.insert(id)
        return true
    }

    /// No está abierta (la ventana no se estira), no se usó (las de una vez) y
    /// pasó el enfriamiento desde que cerró.
    public static func canOpen(_ offer: OffersCatalog.Offer, state: OffersState, catalog: OffersCatalog, now: Double) -> Bool {
        guard !state.active.contains(where: { $0.id == offer.id }) else { return false }
        if offer.oncePerAccount, state.everOpened.contains(offer.id) { return false }
        if let closed = state.lastClosedAt[offer.id], now < closed + catalog.cooldownSeconds { return false }
        return true
    }

    public static func activeOffers(_ state: OffersState, now: Double) -> [ActiveOffer] {
        state.active.filter { $0.expiresAt > now }
    }

    /// Una compra pagada: se cuenta siempre, y si la oferta estaba abierta la
    /// cierra (arranca el enfriamiento).
    public static func markPurchased(_ id: String, in state: inout OffersState, now: Double) {
        state.purchases[id, default: 0] += 1
        guard let index = state.active.firstIndex(where: { $0.id == id }) else { return }
        state.active.remove(at: index)
        state.lastClosedAt[id] = now
    }

    private static func closeExpired(_ state: inout OffersState, now: Double) {
        for offer in state.active where offer.expiresAt <= now {
            state.lastClosedAt[offer.id] = max(state.lastClosedAt[offer.id] ?? 0, offer.expiresAt)
        }
        state.active.removeAll { $0.expiresAt <= now }
    }
}
```

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter OffersEngineTests` → PASS (11);
el paquete entero → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/Offers/OffersCatalog.swift \
  Packages/EconomyKit/Sources/EconomyKit/Offers/OffersEngine.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/OffersEngineTests.swift
git diff --cached --stat
git commit -m "feat(ofertas): las ofertas de 24 h, puras: disparadores, ventana real y enfriamiento"
```

---

### Task 11: Las ofertas se cobran — tres consumibles de StoreKit

**Objetivo:** las tres ofertas existen como productos (`products.json`, el `.storekit` local con
las fichas de `iap-appstore-connect.md` y las claves `iap.<id>.name/.desc` de `IAPCopy`), y una
compra entrega su paquete por el punto único de premios: el ORO cuenta como **comprado**
(`oroPurchasedLifetime`), la oferta se marca comprada (cierra su ventana) y **nada se rechaza**:
una transacción que llega fuera de la ventana, en una tienda restringida o repetida en otro
dispositivo se acredita igual (la guarda contra la doble acreditación es la de la transacción).

**Files:**
- Modify: `FisuEvolution/Resources/Config/products.json` (tres productos al final)
- Modify: `StoreKitConfig/FisuEvolution.storekit` (tres consumibles)
- Modify: `FisuEvolution/Managers/Store/ProductCatalog.swift` (`Entitlement.offer`, `offerId`)
- Modify: `FisuEvolution/Managers/Store/IAPCopy.swift` (`quantity(for:)`)
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (`creditStorePurchase`, `packRewardText`)
- Create: `FisuEvolution/Game/State/GameState+Offers.swift` (+ `xcodegen generate`)
- Create: `FisuEvolution/Resources/Config/offers.json` (+ `xcodegen generate`)
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`GameContent.offers`)
- Create: `FisuEvolutionTests/OffersContentTests.swift`, `FisuEvolutionTests/OffersPurchaseTests.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolutionTests/StoreManagerTests.swift` (el catálogo cargado y una compra de oferta)
- Strings: `Tools/v2/claves-pendientes/e6a-t11.json` (6 claves)

**Interfaces:**
- Consumes: `OffersCatalog`, `OffersEngine.markPurchased` (T10); `grant` (**E4a T8**);
  `creditStorePurchase` con la guarda de transacción y `.oro` → `oroPurchasedLifetime`
  (**E1 T6**), en minutos (**E2a T7**); `.package` entregable (**E5a T6**).
- Produces: `ProductCatalog.Entry.Entitlement.offer`, `ProductCatalog.Entry.offerId: String?`;
  `GameContent.offers: OffersCatalog`; `GameState.creditOffer(_:now:)`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "func creditStorePurchase" -A30 FisuEvolution/Game/State/GameState+Store.swift`
(cómo quedó después de E1 T6 y E2a T7: la guarda de transacción, el `.oro` con
`oroPurchasedLifetime` y los packs en minutos) y
`grep -c "0000000000E" StoreKitConfig/FisuEvolution.storekit` (tiene que dar 0: los
`internalID` nuevos terminan en `E1`, `E2`, `E3`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/OffersContentTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las tres ofertas que aprobó el dueño (PLAN-v2 §2): precio en el `.storekit`,
/// contenido en `offers.json`.
@Suite("offers.json: las tres ofertas aprobadas")
@MainActor
struct OffersContentTests {
    let content: GameContent
    let products: ProductCatalog

    init() throws {
        content = try GameContentLoader.load(from: .main)
        products = try ProductCatalog.load(from: .main)
    }

    @Test("las tres, con su disparador y su contenido")
    func theApprovedOffers() throws {
        let offers = content.offers
        #expect(offers.windowHours == 24)
        #expect(offers.cooldownDays == 3)
        let welcome = try #require(offers.offer(id: "bienvenida"))
        #expect(welcome.trigger == .secondDay)
        #expect(welcome.oncePerAccount)
        #expect(welcome.isChance)
        #expect(welcome.rewards == [.oro(120), .coinsSeconds(7200), .skinChest(1)])
        let rebirth = try #require(offers.offer(id: "renacer"))
        #expect(rebirth.trigger == .reincarnation)
        #expect(rebirth.rewards == [.oro(300), .coinsSeconds(14_400), .modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 1800)])
        let moving = try #require(offers.offer(id: "mudanza"))
        #expect(moving.trigger == .newFloor)
        #expect(moving.rewards == [.oro(500), .coinsSeconds(28_800), .package(3)])
    }

    @Test("cada oferta tiene su consumible y cada consumible de oferta, su oferta")
    func offersAndProductsMatch() throws {
        for offer in content.offers.offers {
            let entry = try #require(products.products.first { $0.id == offer.productId }, "\(offer.id) sin producto")
            #expect(entry.entitlement == .offer)
            #expect(entry.offerId == offer.id)
            #expect(entry.isConsumable, "Renacer y Mudanza vuelven: un no consumible se compra una vez en la vida")
        }
        for entry in products.products where entry.entitlement == .offer {
            #expect(content.offers.offer(id: entry.offerId ?? "") != nil, "\(entry.id) sin oferta")
        }
    }

    @Test("todo lo que trae una oferta se puede entregar")
    func everythingIsGrantable() {
        for offer in content.offers.offers {
            for reward in offer.rewards {
                #expect(GameState.grantableRewardKinds.contains(reward.kind), "\(offer.id): \(reward.kind) no se entrega")
            }
        }
    }
}
```

`FisuEvolutionTests/OffersPurchaseTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Comprar una oferta")
@MainActor
struct OffersPurchaseTests {
    private func entry(_ offerId: String) throws -> ProductCatalog.Entry {
        try #require(try ProductCatalog.load(from: .main).products.first { $0.offerId == offerId })
    }

    @Test("Renacer entrega su ORO como comprado, sus 4 h y su ×3")
    func rebirthDelivers() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let production = GameState.coinReward(seconds: 14_400, player: before, content: content, economy: economy)
        gameState.creditStorePurchase(try entry("renacer"), transactionID: "offer-1")
        let after = try #require(gameState.player)
        #expect(after.meta.oro == before.meta.oro + 300)
        #expect(after.meta.oroPurchasedLifetime == before.meta.oroPurchasedLifetime + 300)
        #expect(after.meta.oroEarnedLifetime == before.meta.oroEarnedLifetime, "lo comprado no es multiplicador")
        #expect(abs(after.run.coins - before.run.coins - production) < 1e-6 * max(1, production))
        let boost = try #require(after.run.activeModifiers.first { $0.sourceKey == "offer.renacer" })
        #expect(boost.effect == .incomeMultiplier)
        #expect(boost.magnitude == 3)
        #expect(after.meta.engagement.offers.purchases["renacer"] == 1)
    }

    @Test("Bienvenida trae su cofre")
    func welcomeBringsAChest() async throws {
        let gameState = await makeGameState()
        let chests = try #require(gameState.player?.meta.chestsPending)
        gameState.creditStorePurchase(try entry("bienvenida"), transactionID: "offer-2")
        #expect(gameState.player?.meta.chestsPending == chests + 1)
        #expect(gameState.player?.meta.oroPurchasedLifetime == 120)
    }

    @Test("la misma transacción no se acredita dos veces")
    func creditsOnce() async throws {
        let gameState = await makeGameState()
        let renacer = try entry("renacer")
        gameState.creditStorePurchase(renacer, transactionID: "offer-3")
        gameState.creditStorePurchase(renacer, transactionID: "offer-3")
        #expect(gameState.player?.meta.oroPurchasedLifetime == 300)
    }

    @Test("una compra cierra su ventana; fuera de la ventana se entrega igual")
    func windowClosesButNeverRefuses() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let now = Date().timeIntervalSince1970
        var player = try #require(gameState.player)
        OffersEngine.open("mudanza", in: &player.meta.engagement.offers, catalog: content.offers, now: now)
        gameState.player = player
        gameState.creditStorePurchase(try entry("mudanza"), transactionID: "offer-4")
        #expect(gameState.player?.meta.engagement.offers.active.isEmpty == true)
        #expect(gameState.player?.meta.oro == 500)
        // Ya cerrada (y en enfriamiento), otra transacción también se entrega.
        gameState.creditStorePurchase(try entry("mudanza"), transactionID: "offer-5")
        #expect(gameState.player?.meta.oro == 1000)
        #expect(gameState.player?.meta.engagement.offers.purchases["mudanza"] == 2)
    }

    @Test("una oferta no inventa una línea de pack ni un número en su descripción")
    func noPackLine() async throws {
        let gameState = await makeGameState()
        let renacer = try entry("renacer")
        #expect(gameState.packRewardText(for: renacer) == nil)
        #expect(IAPCopy.quantity(for: renacer, skins: gameState.content?.skins) == nil)
    }
}
```

En `StoreManagerTests.swift`: `loadsTheCatalogProducts` suma al final de la lista
`"com.fisuevolution.iap.offer_bienvenida"`, `"com.fisuevolution.iap.offer_renacer"` y
`"com.fisuevolution.iap.offer_mudanza"`; y un test nuevo:

```swift
    /// Una oferta es un consumible: se cobra por el listener como un pack, se
    /// entrega entera y se vuelve a vender.
    @Test func purchasingAnOfferCreditsItsBundle() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)
        let before = try #require(gameState.player).meta

        let offer = try #require(store.products.first { $0.id == "com.fisuevolution.iap.offer_renacer" })
        await store.purchase(offer)

        await waitUntil { (gameState.player?.meta.oro ?? 0) > before.oro }
        #expect(gameState.player?.meta.oro == before.oro + 300)
        #expect(gameState.player?.meta.oroPurchasedLifetime == before.oroPurchasedLifetime + 300)
        #expect(gameState.player?.run.activeModifiers.contains { $0.sourceKey == "offer.renacer" } == true)
        #expect(!store.isPurchased("com.fisuevolution.iap.offer_renacer"), "consumible: se vuelve a vender")
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/OffersContentTests -only-testing:FisuEvolutionTests/OffersPurchaseTests`.
Expected: no compila (`content.offers`, `Entitlement.offer`, `offerId`).

- [ ] **Step 3: El dato**

`FisuEvolution/Resources/Config/offers.json`:

```json
{
  "schemaVersion": 1,
  "windowHours": 24,
  "cooldownDays": 3,
  "offers": [
    {"id": "bienvenida", "productId": "com.fisuevolution.iap.offer_bienvenida", "trigger": "secondDay",
     "oncePerAccount": true, "isChance": true, "iconKey": "ui_offer_bienvenida", "symbol": "hand.wave.fill",
     "rewards": [{"kind": "oro", "amount": 120}, {"kind": "coinsSeconds", "seconds": 7200}, {"kind": "skinChest", "count": 1}]},
    {"id": "renacer", "productId": "com.fisuevolution.iap.offer_renacer", "trigger": "reincarnation",
     "iconKey": "ui_offer_renacer", "symbol": "arrow.counterclockwise.circle.fill",
     "rewards": [{"kind": "oro", "amount": 300}, {"kind": "coinsSeconds", "seconds": 14400},
                 {"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 3, "seconds": 1800}]},
    {"id": "mudanza", "productId": "com.fisuevolution.iap.offer_mudanza", "trigger": "newFloor",
     "iconKey": "ui_offer_mudanza", "symbol": "box.truck.fill",
     "rewards": [{"kind": "oro", "amount": 500}, {"kind": "coinsSeconds", "seconds": 28800}, {"kind": "package", "count": 3}]}
  ]
}
```

`products.json`, al final de `products`:

```json
    {
      "id": "com.fisuevolution.iap.offer_bienvenida",
      "type": "consumable",
      "entitlement": "offer",
      "offerId": "bienvenida"
    },
    {
      "id": "com.fisuevolution.iap.offer_renacer",
      "type": "consumable",
      "entitlement": "offer",
      "offerId": "renacer"
    },
    {
      "id": "com.fisuevolution.iap.offer_mudanza",
      "type": "consumable",
      "entitlement": "offer",
      "offerId": "mudanza"
    }
```

`StoreKitConfig/FisuEvolution.storekit`, en `products`, tres objetos con la forma de los packs de
ORO (las fichas son las de `Distribution/iap-appstore-connect.md:140-157`, tal cual):

```json
    {
      "displayPrice" : "0.99",
      "familyShareable" : false,
      "internalID" : "F15CE001-0000-4000-8000-0000000000E1",
      "localizations" : [
        { "description" : "ORO, 2 h de ingresos y un cofre de pintas", "displayName" : "Pack de Bienvenida", "locale" : "es" },
        { "description" : "ORO, 2 h of income and a skin chest", "displayName" : "Welcome Pack", "locale" : "en" }
      ],
      "productID" : "com.fisuevolution.iap.offer_bienvenida",
      "referenceName" : "Offer Bienvenida",
      "type" : "Consumable"
    },
    {
      "displayPrice" : "2.99",
      "familyShareable" : false,
      "internalID" : "F15CE001-0000-4000-8000-0000000000E2",
      "localizations" : [
        { "description" : "ORO, 4 h de ingresos y ×3 por 30 minutos", "displayName" : "Pack Renacer", "locale" : "es" },
        { "description" : "ORO, 4 h of income and ×3 for 30 minutes", "displayName" : "Rebirth Pack", "locale" : "en" }
      ],
      "productID" : "com.fisuevolution.iap.offer_renacer",
      "referenceName" : "Offer Renacer",
      "type" : "Consumable"
    },
    {
      "displayPrice" : "4.99",
      "familyShareable" : false,
      "internalID" : "F15CE001-0000-4000-8000-0000000000E3",
      "localizations" : [
        { "description" : "ORO, 8 h de ingresos y 3 Paquetes", "displayName" : "Pack Mudanza", "locale" : "es" },
        { "description" : "ORO, 8 h of income and 3 Parcels", "displayName" : "Moving Day Pack", "locale" : "en" }
      ],
      "productID" : "com.fisuevolution.iap.offer_mudanza",
      "referenceName" : "Offer Mudanza",
      "type" : "Consumable"
    }
```

(⚠️ El `.storekit` lo escribe Xcode con su formato: antes de commitear, abrir el diff y mirar que
sólo se sumaron los tres objetos. Si hay que editarlo a mano, con Edit, nunca con un script que
reformatee el archivo entero.)

`GameContentLoader.swift`: `let offers: OffersCatalog` al final de `GameContent`, su
`decode("offers", from: bundle)`, `try offers.validate()` envuelto en
`GameError.contentInvalid(file: "offers.json", …)` y `offers: offers` en el `return`.

- [ ] **Step 4: El producto de oferta y el cobro**

`ProductCatalog.swift`, en `Entitlement`:

```swift
            /// Consumible: una oferta de 24 h (`offers.json`). Lo que entrega lo
            /// dice la oferta, no el producto.
            case offer
```

en `Entry`, después de `oroAmount`:

```swift
        /// `offer`: el id de la oferta en `offers.json`.
        var offerId: String? = nil
```

y `isConsumable`: `case .coins, .oro, .offer: true`.

`IAPCopy.quantity(for:skins:)`: `.offer` va con los que devuelven `nil` (la descripción de una
oferta no lleva número: los números los dice la hoja de la oferta, desde el dato).

`GameState+Store.swift`, en `creditStorePurchase`, el caso nuevo del `switch` (después de la
guarda de transacción, que ya insertó el id):

```swift
        case .offer:
            // Lo pagado se entrega siempre: fuera de la ventana, en una tienda
            // restringida o repetido en otro dispositivo. La guarda es la de la
            // transacción, que ya pasó.
            self.player = player
            creditOffer(entry.offerId)
            return
```

y en `packRewardText(for:)`, `.offer` va con `.removeAds, .skin` (`return nil`).

`FisuEvolution/Game/State/GameState+Offers.swift`:

```swift
import EconomyKit
import Foundation

/// Las ofertas de 24 h en la partida (PLAN-v2 E6): el cobro (T11) y, en la T12,
/// cuándo se abren y cuál se presenta.
extension GameState {
    /// Lo que trae una oferta pagada. Su ORO es ORO **comprado**: el reset de E9
    /// lo conserva si no se gastó, igual que el de un pack.
    func creditOffer(_ offerId: String?, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let offerId, let offer = content?.offers.offer(id: offerId) else {
            Log.store.error("offer purchase without a known offer: \(offerId ?? "nil")")
            scheduleSave()
            return
        }
        grant(offer.rewards, source: "offer.\(offerId)", now: now)
        guard var player else { return }
        player.meta.oroPurchasedLifetime += offer.oroAmount
        OffersEngine.markPurchased(offerId, in: &player.meta.engagement.offers, now: now)
        self.player = player
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        Log.store.info("offer credited: \(offerId)")
    }
}
```

`Tools/v2/claves-pendientes/e6a-t11.json` (los nombres son los de las fichas; las descripciones
del juego no llevan números —los dice la hoja, desde el dato—):

```json
{
  "iap.com.fisuevolution.iap.offer_bienvenida.name": {"es": "Pack de Bienvenida", "en": "Welcome Pack"},
  "iap.com.fisuevolution.iap.offer_bienvenida.desc": {"es": "ORO, horas de ingresos y un cofre de pintas", "en": "ORO, hours of income and a skin chest"},
  "iap.com.fisuevolution.iap.offer_renacer.name": {"es": "Pack Renacer", "en": "Rebirth Pack"},
  "iap.com.fisuevolution.iap.offer_renacer.desc": {"es": "ORO, horas de ingresos y un turbo de ingresos", "en": "ORO, hours of income and an income boost"},
  "iap.com.fisuevolution.iap.offer_mudanza.name": {"es": "Pack Mudanza", "en": "Moving Day Pack"},
  "iap.com.fisuevolution.iap.offer_mudanza.desc": {"es": "ORO, horas de ingresos y Paquetes de la Aduana", "en": "ORO, hours of income and Parcels"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6a-t11.json`.

- [ ] **Step 5: Verde, Receta S y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/OffersContentTests -only-testing:FisuEvolutionTests/OffersPurchaseTests -only-testing:FisuEvolutionTests/IAPCopyTests -only-testing:FisuEvolutionTests/StorePacksTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS. **Receta S** → `StoreManagerTests` (con la compra de la oferta) y `StoreProductsTests`
(los dos lados del catálogo: `products.json` ⇄ `.storekit`) en 18.6 → PASS.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Resources/Config/products.json StoreKitConfig/FisuEvolution.storekit \
  FisuEvolution/Managers/Store/ProductCatalog.swift FisuEvolution/Managers/Store/IAPCopy.swift \
  FisuEvolution/Game/State/GameState+Store.swift FisuEvolution/Game/State/GameState+Offers.swift \
  FisuEvolution/Resources/Config/offers.json FisuEvolution/Managers/GameContentLoader.swift \
  FisuEvolutionTests/OffersContentTests.swift FisuEvolutionTests/OffersPurchaseTests.swift \
  FisuEvolutionTests/StoreManagerTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e6a-t11.json, según la ola
git diff --cached --stat
git commit -m "feat(ofertas): Bienvenida, Renacer y Mudanza se cobran por StoreKit y entregan su paquete"
```

---

### Task 12: Las ofertas se ven — se abren solas una vez y viven en un chip

**Objetivo:** el reloj de las ofertas corre en `advanceEngagement` (sólo con `engagementAutorun`
y nunca en el tutorial), una oferta que se abre se presenta **una sola vez** en su turno de la
cola (`.offer`, la de menor prioridad junto a los avisos: nunca encima de otra celebración) y
después vive en el chip `hud.offer.chip` con su cuenta regresiva, que reabre la hoja. La hoja
dice qué trae (con los números del dato), cuánto falta, el precio de StoreKit y —en la de
Bienvenida— las probabilidades del cofre **antes** del botón. La primera vez que aparece el chip
publica el ancla `.offerChip` para la lección de E9.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (`CelebrationKind.offer`)
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`syncCelebrations`, `releasePayload`)
- Modify: `FisuEvolution/Game/State/GameState+Offers.swift` (avanzar, ofrecible, la que se presenta, la puerta de test)
- Modify: `FisuEvolution/Game/State/GameState+Engagement.swift` (`advanceOffers` y `--uitest-offer=`)
- Create: `FisuEvolution/Managers/OfferCopy.swift`, `FisuEvolution/UI/Offers/OfferChip.swift`, `FisuEvolution/UI/Offers/OfferSheet.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/App/RootView.swift` 🔥 (el chip en `hudColumn`, la hoja)
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`.offerChip`)
- Create: `FisuEvolutionTests/OffersRuntimeTests.swift`, `FisuEvolutionUITests/OffersUITests.swift` (+ `xcodegen generate`)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift` (si pinea la lista de prioridades)
- Strings: `Tools/v2/claves-pendientes/e6a-t12.json` (4 claves; los renglones de cada premio los
  pone `RewardCopy` de E5b T1, con sus `reward.title.*`)

**Interfaces:**
- Consumes: `OffersEngine`, `OfferSignals` (T10); `creditOffer` (T11); `chestOdds`,
  `ChestRarityStyle.name/symbol`, `LootBoxGate.lastKnown` (T7); `LootBoxGate.current() async`
  (**E5a T8**); `OddsDisclosureView(titleKey:rows:identifier:)` y `RewardCopy.title(_:)`
  (**E5b T1**); `engagementAutorun`, `advanceEngagement`, `applyEngagementFixtures`, `fixtureValue`
  (**E4a T9**); `StageChips` en `hudColumn` (**E4b T3**); `fisuSheet()` (**E3a T6**).
- Produces: `CelebrationKind.offer`; `GameState.advanceOffers(now:chanceAllowed:)`,
  `isOfferOfferable(_:chanceAllowed:)`, `activeOffers(now:) -> [ActiveOffer]`,
  `offerToPresent: ActiveOffer?`, `markOfferPresented()`, `debugOpenOffer(id:now:)`;
  `OfferPresentation`, `OfferChip`, `OfferSheet`, `OfferCopy`; `TutorialTarget.offerChip`;
  la puerta `--uitest-offer=<id>`.

- [ ] **Step 0: Pararse en la base**

Run: `grep -n "case \|var priority\|var timeout" Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift`
(qué kinds dejaron E4b y E5), `grep -n "StageChips" FisuEvolution/App/RootView.swift` (E4b T3) y
`grep -rn "case .chestOpening" FisuEvolution` (todo `switch` exhaustivo sobre `CelebrationKind`
de la app: cada uno suma `.offer`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/OffersRuntimeTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las ofertas en la partida: cuándo se abren y cómo se presentan")
@MainActor
struct OffersRuntimeTests {
    /// Reloj de pared real: `offerToPresent` y el chip miran `Date()`, y el día del
    /// disparador de Bienvenida sale del `now`. Un `now` de 1970 los separaría.
    private let now = Date().timeIntervalSince1970

    /// Un juego con los motores prendidos y la línea de base ya tomada.
    private func running() async -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.advanceOffers(now: now, chanceAllowed: true)
        return gameState
    }

    @Test("el primer arranque anota el día, aunque los motores estén apagados")
    func firstLaunchDayIsRecorded() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.engagementAutorun)
        gameState.advanceOffers(now: now, chanceAllowed: true)
        #expect(gameState.player?.meta.engagement.firstLaunchDay == DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now)))
        #expect(gameState.activeOffers(now: now).isEmpty)
    }

    @Test("reencarnar abre Renacer, y la oferta se presenta una sola vez")
    func rebirthOpensAndPresentsOnce() async throws {
        let gameState = await running()
        gameState.player?.meta.prestigeLevel += 1
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 1).map(\.id) == ["renacer"])
        #expect(gameState.offerToPresent?.id == "renacer")
        gameState.syncCelebrations()
        drain(gameState)
        #expect(gameState.offerToPresent == nil, "ya se presentó")
        #expect(gameState.activeOffers(now: now + 2).map(\.id) == ["renacer"], "sigue en el chip")
    }

    @Test("durante el tutorial no se abre ninguna")
    func neverDuringTheTutorial() async throws {
        let gameState = await running()
        gameState.beginTutorialPhase()
        gameState.player?.meta.prestigeLevel += 1
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 1).isEmpty)
    }

    @Test("la de Bienvenida no se abre donde el azar está apagado")
    func welcomeRespectsTheGate() async throws {
        let gameState = await running()
        let yesterday = DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now - 86_400))
        gameState.player?.meta.engagement.firstLaunchDay = yesterday
        gameState.advanceOffers(now: now + 1, chanceAllowed: false)
        #expect(gameState.activeOffers(now: now + 1).isEmpty)
        gameState.advanceOffers(now: now + 2, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 2).map(\.id) == ["bienvenida"])
    }

    @Test("abrir un piso abre Mudanza")
    func newFloorOpensMovingDay() async throws {
        let gameState = await running()
        gameState.debugUnlockFloors(throughTier: 5)
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 1).map(\.id).contains("mudanza"))
    }

    @Test("a las 24 h se va del chip")
    func expires() async throws {
        let gameState = await running()
        gameState.debugOpenOffer(id: "renacer", now: now)
        #expect(gameState.activeOffers(now: now + 86_399).count == 1)
        #expect(gameState.activeOffers(now: now + 86_400).isEmpty)
    }

    /// El cofre de bienvenida y lo que haya esperando toman su turno antes.
    private func drain(_ gameState: GameState) {
        for _ in 0..<12 {
            guard let current = gameState.showing else { return }
            if current == .chestOpening { gameState.chestReward = nil }
            gameState.celebrationFinished(current)
        }
    }
}
```

`FisuEvolutionUITests/OffersUITests.swift`:

```swift
import XCTest

/// Las ofertas de 24 h (PLAN-v2 E6): se presentan solas una vez y después viven
/// en el chip, que reabre la hoja.
final class OffersUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAnOpenOfferPresentsOnceAndLivesInTheChip() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-offer=renacer"]
        app.launch()

        let sheet = app.descendants(matching: .any)["offer.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 20), "la oferta no se presentó sola")
        attach(app, named: "E6 la oferta Renacer")
        app.buttons["sheet.close"].firstMatch.tap()

        let chip = app.buttons["hud.offer.chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "la oferta no quedó en el chip")
        chip.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "el chip no reabre la hoja")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/OffersRuntimeTests`.
Expected: no compila (`advanceOffers`, `offerToPresent`).

- [ ] **Step 3: El turno de la oferta en la cola**

`CelebrationQueue.swift`, en `CelebrationKind`, después de `towerNotice`:

```swift
    /// Una oferta de 24 h que se acaba de abrir (E6). Se presenta UNA vez y
    /// después vive en el chip: comparte el último lugar con los avisos, así que
    /// nunca le pasa por encima a un premio ni a una celebración.
    case offer
```

en `priority`: `case .achievements, .towerNotice, .offer: 6`; en `timeout`, `.offer` va con los
que devuelven `nil` (es una hoja: la cierra el jugador). Si `CelebrationQueueTests` pinea la lista
de prioridades o de `allCases`, se suma `.offer` ahí.

`GameState+Celebrations.swift`: en `syncCelebrations()`, antes de `publishCelebration()`,

```swift
        if offerToPresent != nil { celebrations.enqueue(.offer) }
```

y en `releasePayload(for:)`:

```swift
        case .offer:
            // Se mostró su única vez: de acá en más vive en el chip.
            markOfferPresented()
```

- [ ] **Step 4: El reloj y la presentación**

`GameState+Offers.swift`, en la extensión de la T11:

```swift
    /// Lo llama `advanceEngagement` en cada tick. El reloj de una oferta es de
    /// pared, pero se ABRE sólo jugando: una oferta nunca vence sin haber
    /// aparecido. El primer día se anota siempre, también con los motores
    /// apagados: es un dato de la cuenta, no un motor.
    func advanceOffers(now: TimeInterval = Date().timeIntervalSince1970, chanceAllowed: Bool? = nil) {
        guard let content, var player else { return }
        let before = player.meta.engagement
        let today = DailyRewardManager.dayString(for: Date(timeIntervalSince1970: now))
        if player.meta.engagement.firstLaunchDay == nil {
            player.meta.engagement.firstLaunchDay = today
        }
        if engagementAutorun, !tutorialPhaseActive {
            let signals = OfferSignals(
                today: today,
                firstLaunchDay: player.meta.engagement.firstLaunchDay,
                prestigeLevel: player.meta.prestigeLevel,
                unlockedFloorCount: player.run.unlockedFloors.count
            )
            // La puerta de E5a es async; en el tick rige su última respuesta (T7),
            // que arranca cerrada: Bienvenida no se abre hasta que StoreKit conteste.
            OffersEngine.evaluate(&player.meta.engagement.offers, catalog: content.offers, signals: signals, now: now) {
                self.isOfferOfferable($0, chanceAllowed: chanceAllowed ?? LootBoxGate.lastKnown)
            }
        }
        guard player.meta.engagement != before else { return }
        self.player = player
        effectsVersion += 1
        syncCelebrations()
        scheduleSave()
    }

    /// Se ofrece si todo lo que trae se puede entregar y, si trae azar, si en
    /// esta tienda se vende azar.
    func isOfferOfferable(_ offer: OffersCatalog.Offer, chanceAllowed: Bool) -> Bool {
        guard offer.rewards.allSatisfy({ Self.grantableRewardKinds.contains($0.kind) }) else { return false }
        return !offer.isChance || chanceAllowed
    }

    func activeOffers(now: TimeInterval = Date().timeIntervalSince1970) -> [ActiveOffer] {
        guard let player else { return [] }
        return OffersEngine.activeOffers(player.meta.engagement.offers, now: now)
    }

    /// La oferta que todavía no se mostró sola. Nunca en el tutorial.
    var offerToPresent: ActiveOffer? {
        guard !tutorialPhaseActive else { return nil }
        return activeOffers().first { !$0.presented }
    }

    func markOfferPresented() {
        guard var player, let offer = offerToPresent,
              let index = player.meta.engagement.offers.active.firstIndex(where: { $0.id == offer.id })
        else { return }
        player.meta.engagement.offers.active[index].presented = true
        self.player = player
        scheduleSave()
    }

    #if DEBUG
    /// Una oferta abierta ya mismo: se disparan a las horas, sin esta puerta no
    /// se pueden ni fotografiar ni probar.
    func debugOpenOffer(id: String, now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, var player else { return }
        guard OffersEngine.open(id, in: &player.meta.engagement.offers, catalog: content.offers, now: now) else { return }
        self.player = player
        effectsVersion += 1
        syncCelebrations()
    }
    #endif
```

`GameState+Engagement.swift`: en `advanceEngagement(delta:)`, después del auto-tap,
`advanceOffers()`; y en `applyEngagementFixtures(arguments:)`:

```swift
        if let offer = Self.fixtureValue("--uitest-offer=", in: arguments) {
            debugOpenOffer(id: offer)
        }
```

- [ ] **Step 5: El chip, la hoja y la raíz**

`FisuEvolution/Managers/OfferCopy.swift`:

```swift
import EconomyKit
import Foundation

/// Lo que trae una oferta, renglón por renglón, con los números del dato. Cada
/// renglón lo dice `RewardCopy` (E5b T1): la ruleta, el colchón, la tienda y las
/// ofertas nombran un premio de una sola manera.
enum OfferCopy {
    static func lines(for offer: OffersCatalog.Offer) -> [String] {
        offer.rewards.map(RewardCopy.title)
    }

    /// "23:59:58": lo que falta para que venza.
    static func countdown(until expiresAt: TimeInterval, now: Date) -> String {
        let left = max(0, expiresAt - now.timeIntervalSince1970)
        return Duration.seconds(left).formatted(.time(pattern: .hourMinuteSecond))
    }
}
```

`FisuEvolution/UI/Offers/OfferChip.swift`:

```swift
import EconomyKit
import SwiftUI

/// La oferta abierta, bajo el HUD: su ícono y cuánto falta. Tocarlo reabre la
/// hoja. Sin oferta abierta no ocupa lugar. El reloj es de la vista (1 Hz), como
/// el de `ActiveBonusBar`: el tiempo restante nunca va a una proyección.
struct OfferChip: View {
    @Environment(GameState.self) private var gameState
    let onOpen: (String) -> Void

    var body: some View {
        let _ = gameState.effectsVersion
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let offer = gameState.activeOffers(now: context.date.timeIntervalSince1970).first,
               let definition = gameState.content?.offers.offer(id: offer.id) {
                Button { onOpen(offer.id) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: definition.symbol)
                            .font(.system(size: 14, weight: .black))
                            .accessibilityHidden(true)
                        Text(verbatim: OfferCopy.countdown(until: offer.expiresAt, now: context.date))
                            .font(Tokens.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Tokens.s12)
                    .padding(.vertical, 6)
                    .background(PillBackground(fill: Color("PalettePink")))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hud.offer.chip")
                .accessibilityLabel(Text("offer.chip.ax \(IAPCopy.name(for: definition.productId, fallback: definition.id))"))
                .tutorialAnchor(.offerChip)
            }
        }
    }
}
```

`FisuEvolution/UI/Offers/OfferSheet.swift`:

```swift
import EconomyKit
import StoreKit
import SwiftUI

/// Qué oferta está en pantalla. `Identifiable` para `.sheet(item:)`.
struct OfferPresentation: Identifiable, Equatable {
    let id: String
}

/// La hoja de una oferta de 24 h: qué trae (con los números del dato), cuánto
/// falta, el precio de StoreKit y —si trae azar— las probabilidades ANTES del
/// botón (Apple 3.1.1). "No, gracias" está siempre a la vista: rechazarla no
/// cuesta nada.
struct OfferSheet: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    let offerId: String

    private var offer: OffersCatalog.Offer? { gameState.content?.offers.offer(id: offerId) }
    private var product: Product? { offer.flatMap { definition in store.products.first { $0.id == definition.productId } } }

    var body: some View {
        let _ = gameState.effectsVersion
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.s12) {
                    if let offer {
                        contents(offer)
                    }
                }
                .padding(.horizontal, WoodPanelBackground.columnInset)
                .padding(.vertical, Tokens.s12)
            }
            .panelSheet(awning: true) { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
        .background {
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("offer.sheet")
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        PanelTitleBanner(titleKey: LocalizedStringKey(IAPCopy.nameKey(for: offer?.productId ?? "")))
    }

    @ViewBuilder private func contents(_ offer: OffersCatalog.Offer) -> some View {
        GameCard(style: .highlighted(Color("PaletteYellow"))) {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                ForEach(Array(OfferCopy.lines(for: offer).enumerated()), id: \.offset) { _, line in
                    Label { Text(verbatim: line) } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color("PaletteGreen"))
                    }
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                }
                if let active = gameState.activeOffers().first(where: { $0.id == offer.id }) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("offer.endsIn \(OfferCopy.countdown(until: active.expiresAt, now: context.date))")
                            .font(Tokens.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if offer.isChance, case .skins(let odds) = gameState.chestOdds {
            OddsDisclosureView(titleKey: "oroShop.chest.odds", rows: odds.compactMap { odds in
                SkinsConfig.Rarity(rawValue: odds.id).map {
                    OddsDisclosureView.Row(id: odds.id, title: ChestRarityStyle.name($0),
                                           symbol: ChestRarityStyle.symbol($0), probability: odds.probability)
                }
            }, identifier: "offer.odds")
        }
        if let product {
            PricePill(
                text: product.displayPrice,
                currency: .money,
                affordable: true,
                identifier: "offer.buy",
                accessibilityPurpose: Text("offer.buy.ax \(IAPCopy.name(for: offer.productId, fallback: product.displayName))")
            ) {
                Task { await store.purchase(product) }
            }
        } else {
            Text("skins.price.unavailable")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
        Button { dismiss() } label: {
            Text("offer.decline")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                .padding(Tokens.s8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("offer.decline")
    }
}
```

(`skins.price.unavailable` es la clave que Pintas ya usa cuando StoreKit no cargó. Si la
Bienvenida trae cofre pero `chestOdds` no es `.skins` —colección completa o nada alcanzable—, la
oferta igual se vende sin tabla: el cofre paga plata o espera, y eso lo dice el cofre al
abrirse.)

`RootView.swift` 🔥: un `@State private var chipOffer: OfferPresentation?` junto a los otros
`@State`; en `hudColumn`, después de la `ActiveBonusBar` (y de `StageChips`, si E4b lo puso ahí):

```swift
            OfferChip { chipOffer = OfferPresentation(id: $0) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
```

la hoja, después de la de `dailyClaimBinding`:

```swift
        .sheet(item: offerSheetBinding, onDismiss: offerSheetDismissed) { presentation in
            OfferSheet(offerId: presentation.id)
                .fisuSheet()
        }
```

y en la sección de bindings:

```swift
    /// La oferta en pantalla: la que se presenta sola en su turno de la cola (su
    /// única vez) o la que el jugador abrió desde el chip.
    private var offerSheetBinding: Binding<OfferPresentation?> {
        Binding(
            get: {
                if gameState.showing == .offer, let offer = gameState.offerToPresent {
                    return OfferPresentation(id: offer.id)
                }
                return chipOffer
            },
            set: { if $0 == nil { chipOffer = nil } }
        )
    }

    private func offerSheetDismissed() {
        if gameState.showing == .offer { gameState.celebrationFinished(.offer) }
    }
```

`TutorialAnchor.swift`, en `TutorialTarget`, después de `oroShop`:

```swift
    /// El chip de la oferta abierta (E6): la lección de las ofertas (E9).
    case offerChip
```

`Tools/v2/claves-pendientes/e6a-t12.json`:

```json
{
  "offer.endsIn %@": {"es": "Termina en %@", "en": "Ends in %@"},
  "offer.decline": {"es": "No, gracias", "en": "No, thanks"},
  "offer.buy.ax %@": {"es": "Comprar %@", "en": "Buy %@"},
  "offer.chip.ax %@": {"es": "Oferta: %@", "en": "Offer: %@"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e6a-t12.json`.

- [ ] **Step 6: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (`CelebrationQueueTests` con `.offer`).
`/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/OffersRuntimeTests -only-testing:FisuEvolutionTests/CelebrationWiringTests -only-testing:FisuEvolutionUITests/OffersUITests`
→ PASS (`OffersRuntimeTests`: 6). `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift FisuEvolution/Game/State/GameState+Celebrations.swift \
  FisuEvolution/Game/State/GameState+Offers.swift FisuEvolution/Game/State/GameState+Engagement.swift \
  FisuEvolution/Managers/OfferCopy.swift FisuEvolution/UI/Offers/OfferChip.swift FisuEvolution/UI/Offers/OfferSheet.swift \
  FisuEvolution/App/RootView.swift FisuEvolution/UI/Tutorial/TutorialAnchor.swift \
  FisuEvolutionTests/OffersRuntimeTests.swift FisuEvolutionUITests/OffersUITests.swift
# + CelebrationQueueTests si cambió, y el catálogo o Tools/v2/claves-pendientes/e6a-t12.json, según la ola
git diff --cached --stat
git commit -m "feat(ofertas): se abren solas una vez, viven en un chip con su cuenta regresiva y muestran sus probabilidades"
```

---

### Task 13: Cierre de E6a

Lo hace **el controlador** (nunca un subagente):

1. `Tools/v2/oraculo.sh completo` sobre la punta de `v2/e6-tienda` → `VERDE`. La cuenta de
   `economykit` sube por `ShopOffersStateTests` (9), `OroShopCatalogTests` (6), `OroShopTests`
   (10), `AutoTapTests` (6), `ChestOddsTests` (7), `OffersEngineTests` (11); la de `unit`, por
   `OroShopContentTests`, `PendingMultiplierTests`, `OroShopPurchaseTests`, `ChestOddsAppTests`,
   `OffersContentTests`, `OffersPurchaseTests`, `OffersRuntimeTests` y los tests sumados a
   `StorePacksTests`, `RewardGrantTests` y `EffectContractTests`; las de E5a
   (`PackageRuntimeTests`, `WheelRuntimeTests`, `LootBoxGateTests`) siguen verdes sin cambios;
   `store-unit` suma uno; la UI, `OroShopUITests` (3) y `OffersUITests` (1). El `pacing-sim` no
   se mueve.
2. Escenarios a mano en un simulador propio (iOS 26.5 para todo, 18.6 para comprar):
   - comprar ×3 de ingresos con ORO, ver el chip y la plata subir; el tope del día;
   - "Fusionar todo" con un tier nuevo en el medio: se revela;
   - Offline ×3 + 1 h afuera: el popup paga el triple, y el video lo duplica;
   - abrir la oferta Renacer con `--uitest-offer=renacer`, cerrarla, reabrirla por el chip, y
     comprarla en 18.6 (StoreKit local);
   - la tienda en `BEL` (en 18.6, el `.storekit` local con storefront `BEL` en el esquema): no
     se ven ni el cofre por ORO, ni el giro extra de la ruleta (E5a), ni la oferta de Bienvenida;
     y con el storefront de vuelta en `USA`, los tres vuelven después de reabrir la app.
3. `Docs/SESION-<fecha>-v2-e6.md` (estado por tarea, lo medido, las dudas que el dueño
   contestó), las cuatro ediciones de `Docs/HANDOFF.md` (§4 la sesión; §5 las decisiones nuevas:
   "el ORO de una oferta es ORO comprado", "una oferta se presenta sola una vez", "lo que no tiene
   probabilidades no se vende"; §7 las trampas; §9 el mapa con los archivos nuevos), journal AVO y
   latido del `LOCK`.

```bash
git add Docs/SESION-<fecha>-v2-e6.md Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e6): cierre de E6a — la tienda de ORO, los packs y las ofertas"
```

---

## Lo que E6a le deja a otras épicas

- **E6b**: `ShopState.skins` (las pintas compradas con ORO) y `OroShop` (donde suma
  `purchaseSkin` y lee `extraSlots(levels:catalog:)`); el perk `extraSlots` ya existe en el
  catálogo y en el contexto (`supportedPerks` lo trae siempre): E6b sólo agrega el ítem
  `extra_slots` a `oro_shop.json`. El estante "Cosméticos" se suma a `OroShopShelves`.
- **E5**: sus dos enchufes quedan ocupados (T6): `openPackage()` lee `bestSupplierLevel` (el `r`
  sigue siendo dato de `packages.json`) y `wheelAvailability`/`spinWheel` cuentan contra
  `effectiveWheel` (= `content.wheel.withBonusVideoSpins(bonusDailyWheelSpins)`). Si E5 cambia su
  sorteo o su cupo, tiene que seguir pasando por ahí. El giro extra con ORO **sigue siendo de la
  ruleta** (E5a T8): la tienda no lo revende. `LootBoxGate` gana `lastKnown` (T7), que E5 puede
  usar si alguna vez necesita la respuesta sin esperar.
- **E7b**: "Fusionar todo" por video usa su propio `Origin`; el de ORO es `.oroShop`. Cerrar la
  `OfferSheet` **no** debería contar como corte natural para un intersticial (es una venta: un
  anuncio pegado a una oferta rechazada se lee como castigo); si E7b engancha `sheetClosed` en la
  raíz, que excluya la hoja de la oferta. El chip de la oferta y la columna lateral de E7b
  comparten el lado izquierdo bajo el HUD: medir en el SE.
- **E9** (sin plan): los ganchos quedan puestos —`TutorialTarget.oroShop` (la pestaña "Gastar
  ORO") y `.offerChip`—. Lecciones que faltan escribir: la tienda de ORO (las dos mitades, los
  topes del día), los ×3 pendientes (qué pasa con el próximo offline y el próximo diario), el
  auto-tap (su chip), la suerte (dónde se ven las probabilidades) y las ofertas (el chip y sus
  24 h). Para `TutorialCoverageTests`: cada ítem de `oro_shop.json` es una mecánica, y su lección
  puede ser una sola para el estante. **Reset**: `engagement.shop` se borra con la partida (es
  gasto de ORO), pero `engagement.offers.everOpened` y `firstLaunchDay` no (si no, la oferta de
  una vez vuelve); el ORO de las ofertas ya está en `oroPurchasedLifetime`.
- **E2b**: el simulador no modela la tienda: el perfil `.max` ("más los permanentes de la
  tienda") lee `OroShop.bestSupplierLevel` (y con él `packages.tierRatio(bestSupplierLevel:)`),
  `bonusDailyWheelSpins` y `extraSlots` desde los niveles, y
  los consumibles de poder entran a los tests de presupuesto (son gasto de ORO, no premios
  gratis). Los precios de `oro_shop.json` y los montos de los packs se re-pinean en
  `OroShopContentTests` y `StorePacksTests` si el simulador los mueve.
- **E10**: App Review: dónde se ven las probabilidades (las filas de Suerte y la hoja de
  Bienvenida), que las ofertas duran 24 h y que en `BEL`/`AUS` no hay azar pagado; una captura de
  revisión por oferta (la hoja con `--uitest-offer=<id>`); el cuestionario de edad con loot boxes.
- **E11**: ninguna notificación nueva (guía 4.5.4: ni ofertas ni precios). Queda dicho para que
  nadie la sume después.

## Para el dueño / dudas

Cosas que PLAN-v2 deja abiertas o que el código contradice. **Ninguna frena**: la ejecución sigue
con el default anotado hasta que el dueño diga otra cosa.

1. **La oferta se presenta sola una vez y después vive en el chip.** PLAN-v2 dice "chip +
   `OfferSheet`"; no dice si la hoja aparece sola. Default: sí, una vez, en su turno de la cola
   (después de premios y celebraciones), nunca en el tutorial. Si molesta, se apaga sacando una
   línea de `syncCelebrations`.
2. **Los lugares extra son un nivel, no un premio.** `RewardSpec.extraSlots` (los "cimientos")
   queda sin productor: el permanente de +3/+2 se lee de su nivel, y un nivel no se "entrega" dos
   veces. Default: `.extraSlots` sigue fuera de `grantableRewardKinds`.
3. **El giro extra de la ruleta lo vende la ruleta, no la tienda** (las dos secciones de PLAN-v2
   lo nombran; E5a T8 ya lo implementa: 12 ORO, 6 por día, con su tabla de probabilidades al
   lado). El coordinador dejó abierto "ponerle estante si hace falta". Default: **sin fila en la
   tienda de ORO** — una fila ahí tendría que abrir la ruleta desde adentro de la hoja de la
   Tienda (dos hojas apiladas) o duplicar su animación, y el giro ya se ve donde se usa. Si el
   dueño la quiere, es una fila "Ir a la Ruleta" que cierra la Tienda y presenta `wheelSheet`
   (E5b T2), sin precio propio.
4. **"Fusionar todo" no devuelve ORO si un par se descarta** (porque el jugador lo fusionó a mano
   antes de su turno). Se cobra si al comprar había al menos un par. Default: así.
5. **Un boost comprado con ORO muere al reencarnar** (vive en `run.activeModifiers`, como los de
   video y los eventos). Default: así, sin aviso; el ×3 de Renacer llega después de reencarnar, así
   que no se pierde.
6. **El cofre de pintas comprado espera en Regalos** (no se abre adentro de la tienda: la
   animación del cofre no puede ir sobre una hoja). Default: así, y la fila lo dice.
7. **El Offline ×3 y el ×2 del video se multiplican** (×6), y el ×3 sólo se gasta en una vuelta con
   popup (≥ 30 s). El Diario ×3 sólo se gasta en un diario que paga plata. Default: así.
8. **El auto-tap**: 5 toques por segundo, al personaje de tier más alto que tenés, sin crítico ni
   toque dorado, sin contar para los logros de toques y sin pagar offline. PLAN-v2 no dice la
   velocidad. Default: 5/s, en el dato.
9. **Sin país de tienda conocido, el azar NO se vende** (se adopta la regla de E5a T8:
   `LootBoxGate` falla cerrado). El costo: sin red o antes de que StoreKit conteste, el cofre por
   ORO no aparece y la oferta de Bienvenida espera al próximo arranque con respuesta. Default:
   cerrado, para que la ruleta y la tienda digan lo mismo.
10. **La oferta de Bienvenida no se ofrece en Bélgica ni en Australia** (trae un cofre: azar
    pagado con plata). PLAN-v2 sólo nombra "giros extra y cofres por ORO". Default: no se ofrece;
    en el tick se decide con `LootBoxGate.lastKnown` (la última respuesta de la puerta de E5a).
11. **Mudanza se dispara con cualquier piso que abre la run**, no sólo con el primero de la
    cuenta: el enfriamiento de 3 días ya la vuelve rara. Default: cualquier piso de la run.
12. **Los veteranos de la v1 reciben la oferta de Bienvenida** el día después de actualizar (su
    `firstLaunchDay` es el día que abrieron la 2.0). Default: sí, una vez.
13. **Los nombres de los ítems de la tienda** ("Doble turno", "Dedo de goma", "Siesta productiva",
    "Abono a la ruleta"…) son propuesta; viven en el catálogo y se cambian sin código.
14. **La tienda abre siempre en "Comprar ORO"** (lo que revisa App Review y pinea `StoreUITests`).
    Default: así, sin recordar la última mitad elegida.
15. **Las 7 líneas a 348 no son de E6** aunque la tabla §4 C1 las nombre acá: las pasa E2b, que es
    quien re-pinea el catálogo de mejoras en su calibración.

### 🔒 El `||` de `SaveConflictResolver.swift:68` — E6 lo empeora en grado, no en clase

No se resuelve acá (es del dueño, antes de E9 o de prender CloudKit). Lo que E6 cambia:

- **Más ORO comprado en juego.** Las ofertas suman 120/300/500 a `oroPurchasedLifetime` y los
  packs nuevos siguen sumando: hay más saves "nuevos" (`purchasedOroReconstructed = true`) con
  ORO comprado > 0. Un conflicto entre uno de ésos y un veterano migrado (`false`) deja el flag en
  `true`, la reconstrucción de la v1 no corre, y el `min(saldo, comprado)` de E9 le borraría al
  veterano el ORO que pagó en la v1. La clase del problema es la misma; lo que crece es cuánto se
  pierde.
- **La línea `:67` (`max` sobre `oroPurchasedLifetime`) también pierde plata con E6**: un pack
  comprado en cada dispositivo (160 en uno, 550 en el otro) resuelve a 550, no a 710. Con un solo
  producto de ORO pasaba poco; con tres packs y tres ofertas, el caso deja de ser raro. Si el
  dueño elige "que gane el lado pendiente" para `:68`, conviene decidir `:67` en la misma pasada.
- **La foto de la v1 no se toca** (T9 lo pinea), así que la reconstrucción sigue contando 250 /
  750 / 2000 aunque `products.json` diga 160 / 550 / 1.400. Si una transacción de un pack de la
  2.0 llegara a `creditedPurchases` **antes** de que corra la reconstrucción (un save v5
  restaurado de una copia de E1 T5 después de haber comprado en la 2.0), se contaría con el
  monto de la v1. `StoreManager.start` reconstruye antes de cargar productos, así que en el
  camino normal no pasa; el caso queda anotado para la decisión de `:68`.

