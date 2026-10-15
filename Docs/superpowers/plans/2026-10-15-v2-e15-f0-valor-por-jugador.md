# E15 F0 — Valor por jugador: medir lo que vale cada usuario · plan por tareas

> **Para agentes:** se ejecuta con el relevo automático (PLAN-v2 §0 y §0.1) y el protocolo
> `/Users/manuader/Desktop/projects/FisuEvolution/.claude/worktrees/version-2/.superpowers/sdd/v2-agente-protocolo.md`,
> **con la regla del dueño de no compilar por tarea** (`ola-r56/comun.md` y siguientes, en la carpeta del AVO): cada
> agente escribe el código y sus tests sin correrlos, commitea y pushea; el controlador integra la ola y compila y corre
> todo **una sola vez** (E15-T8). La spec es `Docs/PLAN-v2-E15-valor-por-jugador.md` (§0 «F0 en detalle»); este doc
> es el orden, los dueños y los contratos.

**Objetivo:** que la 2.0 salga **midiendo**, sin cambiar nada de lo que el jugador vive: cuánto paga cada impresión
de anuncio (en el save), cómo convierte cada oferta con video (en el save) y, cuando el dueño lo prenda, una
telemetría anónima a Supabase. Al final de F0 existen: el ledger de impresiones enganchado a `paidEventHandler` en los
cuatro formatos; el embudo por lugar; el cliente de telemetría con cola offline, apagado por defecto en tres capas; el
SQL del esquema en el repo **sin aplicar**; y los textos de privacidad **en borrador** para el dueño.

**Arquitectura:** los datos puros viven en EconomyKit (`AdRevenueLedger`, `OfferFunnel`; sin dependencias del SDK, con
`swift test`); la app sólo los alimenta. El SDK de AdMob entra por `AdMobAdsProvider` y sale como un valor propio
(`AdImpression`) por el `AdsCoordinator`; `GameState` lo anota en el save y, si la telemetría está habilitada, lo
encola. La telemetría es un servicio aparte (`Managers/Telemetry/`) con una compuerta única (`TelemetryGate`) que
decide si algo sale del teléfono. El backend es el mismo proyecto de Supabase del ranking (E12), con una tabla nueva
de sólo-insertar para `anon`.

**Épica:** E15 confirmada contra `Docs/PLAN-v2.md` (la última épica numerada ahí es E14; E14b vive en su propio spec).

## Decisiones del dueño (2026-10-15, no se re-preguntan)

| # | Decisión |
|---|---|
| V1 | Antes de lanzar la 2.0 va **sólo F0** (medir). R1–R8 y F1–F7 van a la 2.1. |
| V2 | Telemetría **anónima a Supabase**, con un id de instalación propio (no el IDFA), respetando UMP/ATT, con `privacy.md`, los términos y la etiqueta de App Store Connect actualizados **antes** de prender el interruptor. |
| V3 | El premio por video puede crecer para los de más valor, con tope. **No es de F0** (es F2): nada de esto toca premios. |
| — | Nada de amañar en secreto ni de falsear resultados (spec §5). |

## Restricciones globales (valen para toda tarea)

- **No se compila por tarea.** Prohibido: compilar la app, `xcodebuild`, `oraculo.sh`, UI tests, `xcrun simctl` en
  cualquier forma, `xcodegen`. Se escribe con cuidado: **leer los tipos y firmas reales** antes de usarlos (nada de APIs
  inventadas; para el SDK de Google, leer los headers/fuentes del paquete resuelto, ver T2). Los tests (unit y UI) se
  escriben **sin correrlos**: el «RED» de cada tarea es el test escrito primero y commiteado junto con el código, y se
  ve rojo/verde recién en T8. Excepciones baratas, **una vez por tarea**: `swift test` en `Packages/EconomyKit` (T1) y
  `supabase/test.sh --sql` (T4: un Postgres descartable local, no toca ninguna base).
- **F0 no toca la economía ni el ritmo.** Ningún archivo de `EconomyEngine`, `PacingSimulator*`, `PacingProfile`,
  `RewardScale`, `RewardSpec`, `*_ads.json`, `ads.json`, `economy.json`, ni `grant()`/acreditación. Los tipos nuevos de
  EK **no los lee** ningún cálculo de economía. T8 lo comprueba con el diff y con la salida del pacing-sim idéntica a la
  de la base.
- **Nada sale de la máquina.** Ningún agente aplica migraciones en Supabase (ni `supabase db push`, ni el MCP de
  Supabase, ni el SQL editor), ni prende el interruptor, ni toca AdMob, ASC o `adergames-site`. Todo eso es 🔒.
- **Privacidad:** ningún dato personal. Ni IDFA, ni IDFV, ni nombre del ranking, ni IP guardada, ni texto libre.
  El único identificador es el UUID de instalación que ya existe (`InstallIdentity`, Keychain, no sincronizable).
  `NSPrivacyTracking` sigue en `false` (B22).
- **Un dueño por archivo** (tabla «Estructura de archivos»). `RootView.swift` y `FisuEvolutionApp.swift` son calientes:
  una línea cada uno, en la tarea que lo dice. `Localizable.xcstrings` no lo toca nadie (F0 no agrega textos visibles;
  si alguno hiciera falta, snapshot en `Tools/v2/claves-pendientes/e15-tN.json`).
- **Commits** en español, estilo de la casa (`feat(ads): …`, `feat(telemetria): …`, `test(…)`, `docs(e15): …`),
  **SIN `Co-Authored-By`**. Staging selectivo y `git diff --cached --stat` antes de cada commit. Un comando git por
  llamada. Cada tarea en su worktree `.claude/worktrees.nosync/v2i-e15-tN` (rama `v2i/e15-tN`) desde la BASE que da el
  despacho; `git push -u origin v2i/e15-tN` al terminar. Ningún subagente toca `Docs/`, `handoffs/`, el journal ni
  `tasks.md`.
- **El reporte** lista lo que el controlador tiene que mirar en el build único: tests nuevos, riesgos de compilación
  (sobre todo los símbolos del SDK), y si tocó algún archivo de otra fila.

## Los contratos (fijos: las tareas en paralelo los respetan tal cual)

### C1 — `AdImpression` (EconomyKit, T1)

```swift
public enum AdFormat: String, Codable, Sendable, CaseIterable { case rewarded, interstitial, rewardedInterstitial, appOpen }
public enum AdValuePrecision: String, Codable, Sendable { case unknown, estimated, publisherProvided, precise }

public struct AdImpression: Codable, Sendable, Equatable {
    public let format: AdFormat
    public let site: String          // RewardedPlacement.rawValue para rewarded; NaturalBreak.rawValue o "adBreak"/"appOpen" para los forzados
    public let valueMicros: Int64    // valor × 1_000_000, redondeado (el SDK de iOS da un NSDecimalNumber en unidades de moneda)
    public let currency: String      // ISO 4217 del SDK, tal cual
    public let precision: AdValuePrecision
    public let adSource: String?     // responseInfo.loadedAdNetworkResponseInfo.adSourceName (Google, Unity, Meta); nil si no hay
    public let at: TimeInterval      // epoch
}
```

### C2 — `AdRevenueLedger` (EconomyKit, T1; en el save como `meta.adRevenue`)

- Por formato: `recent` (las **últimas 20** impresiones, anillo, la más vieja sale), `count`, `totalMicros`, `maxMicros`
  y `meanMicros` (derivado: `totalMicros / count`, 0 si no hay).
- Moneda: los agregados se llevan en la **moneda de la primera impresión** (`currency` del ledger; AdMob informa en la
  moneda de la cuenta, que no cambia). Una impresión en otra moneda entra al anillo pero no a los agregados y suma
  `foreignCurrencyCount`.
- Atajos con los nombres del reel: `recentMicros(format:)` (promedio del anillo), `maxMicros` (todos los formatos),
  `averageRewardedMicros` (= `meanMicros` de `.rewarded`).
- Campo **opcional** en `MetaState`: un save viejo (sin la clave) decodifica `.empty`; uno ilegible también (`try?`,
  como `ranking`). `schemaVersion` **no sube** (no hay migración: es un campo nuevo con default).
- Sincronización (`SaveConflictResolver`): por formato gana el lado con más `count` (entero, con su anillo); es el
  mismo criterio de «máximo de contadores monótonos» que `stats`.

### C3 — `OfferFunnel` (EconomyKit, T1; en el save como `meta.offerFunnel`)

- Clave: `site` (`String`), el `identifier` del botón de video (el id de accesibilidad, que ya es estable y único por
  fila del mapa de ubicaciones) — p. ej. `ads.watch.double_earnings`, `offline.x2`.
- Etapas (`OfferStage`): `shown` (el botón quedó ofreciendo, con video listo), `accepted` (primer toque),
  `completed` (premio ganado), `unfilled` (tocó y no hubo video), `dismissed` (la oferta se fue de la pantalla
  mostrada y sin aceptar: «No, gracias», cerrar el pop-up, irse). El abandono a mitad del video es
  `accepted − completed − unfilled`: no se cuenta aparte.
- Tope de claves: 64 (si se pasa, la nueva va a `_other`): un id dinámico mal elegido no infla el save.
- Opcional en el save y sincronización por máximo de cada contador, igual que C2.

### C4 — El evento de telemetría (app, T5; columnas de la tabla de T4)

| Campo JSON = columna | Tipo | Qué |
|---|---|---|
| `install_id` | uuid | `InstallIdentity.installId()` |
| `session_id` | uuid | nuevo en cada `session_start` |
| `client_ts` | timestamptz (ISO 8601) | hora del teléfono |
| `name` | text | uno de: `session_start`, `session_end`, `ad_impression`, `offer`, `purchase`, `prestige` |
| `app_version` | text ≤ 16 | `CFBundleShortVersionString` |
| `build` | text ≤ 16 | `CFBundleVersion` |
| `os_version` | text ≤ 16 | `UIDevice.current.systemVersion` |
| `device_model` | text ≤ 32 | el identificador de máquina (`utsname.machine`, p. ej. `iPhone16,2`); en simulador, `SIMULATOR_MODEL_IDENTIFIER` |
| `storefront` | text de 3 o null | `Storefront.current?.countryCode` (ISO alfa-3) |
| `props` | jsonb objeto ≤ 2 KB | por evento, abajo |

`props` por evento (claves cerradas; ningún texto libre):

- `session_start`: `{ "n": <número de sesión> }` · `session_end`: `{ "seconds": <duración> }`
- `ad_impression`: `{ "format", "site", "micros", "currency", "precision", "source" }` (C1)
- `offer`: `{ "site", "stage" }` (C3)
- `purchase`: `{ "product": <productID> }` (sin precio ni transacción)
- `prestige`: `{ "count": <reencarnaciones de la cuenta> }`

### C5 — El interruptor (tres capas, todas APAGADAS por defecto)

1. **Servidor:** `public.settings` fila `telemetry_enabled = false` (la sembra la migración de T4). La política RLS de
   insert la mira: con el interruptor apagado, un insert de `anon` falla aunque el cliente se equivoque.
2. **Cliente remoto:** `TelemetrySwitch` pregunta `POST {baseURL}/rest/v1/rpc/telemetry_enabled` (la misma
   `baseURL`/`anonKey` de `RankingConfig`). Cualquier cosa que no sea un `true` explícito (error, sin red, timeout,
   `RankingConfig` no usable) es **apagado**. Se cachea en memoria por sesión y se re-pregunta al volver del
   background (como mucho cada 6 h).
3. **Compuerta local** (`TelemetryGate.canSend`): interruptor remoto `true` **y** consentimiento (UMP:
   `ConsentInformation.shared.canRequestAds == true`) **y** no es UI test (`--uitest*`) **y** no es `DEBUG` salvo
   `--telemetry-debug`. Con la compuerta cerrada **los eventos se descartan** (no se encolan): nada se junta antes de
   tiempo.

## Estructura de archivos (un dueño por fila)

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/AdValue/AdImpression.swift` (nuevo), `AdRevenueLedger.swift` (nuevo), `OfferFunnel.swift` (nuevo) | C1–C3, puros | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (sólo `MetaState`: 2 campos, init y decode) | el save | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift` (sólo las 2 líneas de merge) | la nube | 1 |
| `Packages/EconomyKit/Tests/EconomyKitTests/AdRevenueLedgerTests.swift`, `OfferFunnelTests.swift` (nuevos), `SaveCompatibilityTests.swift`, `SaveConflictResolverTests.swift` (casos nuevos) | tests EK | 1 |
| `FisuEvolution/Managers/Ads/AdMobAdsProvider.swift`, `AdsProvider.swift` (protocolo + stub), `AdsCoordinator.swift`, `AdImpressionMapping.swift` (nuevo) | `paidEventHandler` → `AdImpression` | 2 |
| `FisuEvolution/Game/State/GameState+AdRevenue.swift` (nuevo), `GameState+Services.swift` (sólo `attachAds`), `GameState+Ads.swift` (sólo el `site` de los forzados) | anotar en el save | 2 |
| `FisuEvolution/Debug/AdValueProbe.swift` (nuevo, `ViewModifier`), `RootView.swift` (**una línea**) | sonda para UI tests | 2 |
| `FisuEvolutionTests/AdImpressionMappingTests.swift`, `AdRevenueRecordingTests.swift`, `FisuEvolutionUITests/AdRevenueLedgerUITests.swift` (nuevos) | tests | 2 |
| `FisuEvolution/UI/Art/RewardedOfferButton.swift`, `FisuEvolution/UI/Art/OfferFunnelTracker.swift` (nuevo), el componente del paso 2 de B29 (p. ej. `RewardDoubleOffer`) **sólo si no usa `RewardedOfferButton`**, `GameState+OfferFunnel.swift` (nuevo) | el embudo | 3 |
| `FisuEvolutionTests/OfferFunnelTrackerTests.swift`, `FisuEvolutionUITests/OfferFunnelUITests.swift` (nuevos); `AdValueProbe.swift` (sólo agregar las líneas del embudo) | tests | 3 |
| `supabase/migrations/20261015000001_telemetry_schema.sql`, `20261015000002_telemetry_retention.sql` (nuevos), `supabase/tests/sql/05_telemetry_test.sql` (nuevo), `supabase/scripts/admin.sql` (sección nueva al final), `supabase/README.md` (sección nueva) | backend | 4 |
| `FisuEvolution/Managers/Telemetry/` (nuevo: `TelemetryEvent.swift`, `TelemetryQueue.swift`, `TelemetryGate.swift`, `TelemetrySwitch.swift`, `TelemetryUploader.swift`, `DeviceContext.swift`, `TelemetryService.swift`) | cliente | 5 |
| `FisuEvolutionTests/TelemetryEventTests.swift`, `TelemetryQueueTests.swift`, `TelemetryGateTests.swift`, `TelemetrySwitchTests.swift`, `TelemetryUploaderTests.swift` (nuevos) | tests | 5 |
| `FisuEvolution/Game/State/GameState+Telemetry.swift` (nuevo); una llamada en `GameState+Lifecycle.swift` (`handleScenePhase`), `GameState+Store.swift` (`creditStorePurchase`), `GameState+Prestige.swift` (`confirmPrestige`), `GameState+AdRevenue.swift` y `GameState+OfferFunnel.swift`; `FisuEvolutionApp.swift` (**sólo** `startServices`, una línea) | cableado | 6 |
| `FisuEvolutionTests/TelemetryWiringTests.swift` (nuevo) | tests | 6 |
| `Distribution/release/privacidad-e15-BORRADOR.md` (nuevo), `FisuEvolution/Resources/PrivacyInfo.xcprivacy`, `FisuEvolutionTests/PrivacyManifestTests.swift` | privacidad | 7 |
| `Distribution/site/privacy.md`, `FisuEvolution/Resources/Legal/privacy.md`, `Distribution/site/terms.md`, `FisuEvolution/Resources/Legal/terms.md`; rama local de `adergames-site` (`content/legal.ts`, `content/terms.ts`) | los textos **aprobados** | 9 |

## Orden, olas y la relación con B29

| Ola | Tareas | Puede ir | Choques a evitar |
|---|---|---|---|
| A | **T1** · **T4** · **T5** | en cualquier hueco de E14b (no tocan los botones de oferta) | T1 **no ∥ B22 ni B25** (los dos tocan el save / `PlayerState.swift`); T4 y T5 no chocan con nada de E14b |
| B | **T2** | después de T1 | si B29 tocó `AdsCoordinator`/`AdsProvider`, la BASE de T2 tiene que traer B29 |
| C | **T3** | **después de que E14b-B29 esté integrada** (B29 rehace `RewardedOfferButton` y crea el paso 2 «×2 con video / No, gracias») y de T1 | no ∥ B25 (usa el paso 2 de B29) |
| D | **T6** · **T7** | T6 después de T2, T3 y T5; T7 después de T4 y T5 | archivos disjuntos entre sí |
| E | **T8** (controlador) | con A–D integradas | build único |
| 🔒 | **T9** | después del 🔒 O1 del dueño | — |

**B29, explícito:** el embudo (T3) se instrumenta **sobre** la versión de B29, no antes: B29 cambia qué botones existen
(el ×2 sale del primer pop-up y pasa a un segundo pop-up) y unifica el «Repetir premio» de la Ruleta con ese paso 2.
Instrumentar antes obligaría a rehacerlo. Lo que T3 toma de B29: el nombre real del componente del paso 2, sus
identificadores de accesibilidad y el UI test del Ministro (con stub), que T3 extiende para el embudo. T1, T2, T4 y T5
**no** dependen de B29.

---

### E15-T1 — `AdRevenueLedger` y `OfferFunnel` en EconomyKit, en el save

**Modelo:** opus (save). **Revisión:** opus. **Depende:** — (no ∥ B22/B25).

**Files:** los de T1 en la tabla. Nada fuera de EK.

- [ ] **Step 1 (RED, escrito):** `AdRevenueLedgerTests`: (a) una impresión suma `count`, `totalMicros`, `maxMicros` y
  entra al anillo; (b) la 21.ª saca a la más vieja y los agregados siguen contando las 21; (c) `meanMicros` con 0
  impresiones es 0 (sin dividir por cero); (d) otra moneda va al anillo y a `foreignCurrencyCount`, no a los agregados;
  (e) `averageRewardedMicros` sólo mira `.rewarded`; (f) ida y vuelta `Codable` byte-estable.
  `OfferFunnelTests`: suma por etapa y por `site`; tope de 64 claves con `_other`; ida y vuelta.
  `SaveCompatibilityTests`: un save v7 **sin** las dos claves decodifica `.empty`; uno con basura en esas claves
  también (el resto de la partida intacto); un save con ledger hace ida y vuelta igual.
  `SaveConflictResolverTests`: por formato gana el lado con más `count`; el embudo toma el máximo por contador; nada de
  lo demás del resolver cambia.
- [ ] **Step 2 (GREEN):** los tres tipos (C1–C3), los dos campos opcionales en `MetaState` (`init` con default
  `.empty`, `decodeIfPresent` con `try?` como `ranking`) y las dos líneas del resolver.
- [ ] **Step 3:** `swift test --package-path Packages/EconomyKit` **una vez** (la excepción permitida). Pegar el
  resumen en el reporte.
- [ ] **Step 4:** commit `feat(ek): el ledger de impresiones y el embudo de ofertas viven en el save (E15 T1)`.

**Listo cuando:** EK verde con los tests nuevos nombrados en la salida; `schemaVersion` sigue en 7; ningún archivo de
economía/pacing en el diff.

---

### E15-T2 — `paidEventHandler` en los cuatro formatos → el ledger

**Modelo:** opus (anuncios + save). **Revisión:** opus. **Depende:** T1.

**Files:** los de T2 en la tabla.

**Interfaces:**
- `AdsProvider` gana `var onImpression: (@MainActor (AdImpression) -> Void)? { get set }`. `AdsCoordinator` lo
  reenvía desde el proveedor activo (también cuando cambia de stub a AdMob en `configure`) y le pone el `site` a los
  forzados: `GameState+Ads` le pasa el `NaturalBreak.rawValue` del corte antes de `showInterstitial()`; la pausa es
  `"adBreak"`; el app open, `"appOpen"`.
- `AdMobAdsProvider`: al **cargar** cada anuncio (rewarded por placement, interstitial, rewarded interstitial, app open)
  se le asigna `paidEventHandler`; el handler salta al main actor y emite un `AdImpression` armado por
  `AdImpressionMapping.make(value:format:site:source:now:)`.
- ⚠️ **Los símbolos del SDK no se adivinan:** antes de escribir, leer en el paquete resuelto de Google Mobile Ads
  (`~/Library/Developer/Xcode/DerivedData/*/SourcePackages/` o el `checkouts/` del proyecto; sólo lectura) el nombre
  real de la propiedad (`paidEventHandler`), del tipo del valor (`AdValue`, antes `GADAdValue`: `value` es
  `NSDecimalNumber` en unidades de moneda, `currencyCode`, `precision`) y del enum de precisión. Si el SDK resuelto no
  está en la máquina, **NEEDS_CONTEXT**, no se inventa.
- `StubAdsProvider`: bajo `--uitest*` cada «anuncio» completado emite un `AdImpression` de `10_000` micros, `USD`,
  `.unknown`, `adSource: "stub"`. Fuera de UI tests el stub no emite nada.
- `GameState+AdRevenue`: `recordImpression(_:)` anota en `player.meta.adRevenue` y marca el save sucio (el mismo
  camino que usan los demás campos de `meta`). Nada más: no acredita, no cambia cooldowns.
- Sonda: `AdValueProbe` (un `ViewModifier` que `RootView` aplica en **una línea**) muestra, sólo con
  `--uitest-ad-value-probe`, un `Text` invisible-pero-accesible `ads.ledger.count` con el total de impresiones.

- [ ] **Step 1 (RED, escrito):** `AdImpressionMappingTests` (decimal → micros con redondeo, `0.000123` → 123; cada
  precisión del SDK → la nuestra; moneda tal cual; `adSource` nil); `AdRevenueRecordingTests` (con el stub y un
  `GameState` de prueba: un rewarded completado anota 1 con el placement como `site`; un interstitial lleva el
  `NaturalBreak`; un video cerrado a la mitad **también** anota —la impresión se pagó— pero no acredita premio);
  `AdRevenueLedgerUITests` (`--uitest-reset --uitest-skip-tutorial --uitest-ad-value-probe`: abrir Regalos, mirar
  `ads.watch.double_earnings` con el stub, esperar el cooldown y leer `ads.ledger.count == 1`).
- [ ] **Step 2 (GREEN):** lo de «Interfaces».
- [ ] **Step 3:** commit `feat(ads): cada impresión queda anotada con su valor (paidEventHandler, E15 T2)`.

**Listo cuando:** (en T8) los tres tests verdes; con el SDK real, el handler está asignado en los cuatro `load`; el
contrato de `showRewarded` (true sólo con premio) no cambió.

---

### E15-T3 — El embudo de ofertas por lugar (sobre B29)

**Modelo:** opus (anuncios). **Revisión:** opus. **Depende:** T1, **E14b-B29 integrada** (y T2 si se quiere la sonda
ya hecha; si no, T3 la crea con el mismo nombre).

**Files:** los de T3 en la tabla. **No toca** los pop-ups uno por uno: todo sale de `RewardedOfferButton` (y del
componente del paso 2 de B29 sólo si ése no usa `RewardedOfferButton` por dentro).

**Interfaces:**
- `OfferFunnelTracker` (struct puro): recibe las transiciones del botón (`appearedReady`, `tapped`, `earned`,
  `noInventory`, `disappeared`) y devuelve qué etapas contar. Reglas: `shown` una vez por aparición (no por cada sondeo
  ni por cada vuelta de `generation`); `accepted` una vez por toque efectivo (el doble toque es uno, como
  `RewardedOffer`); `dismissed` al desaparecer sólo si hubo `shown` y no hubo `accepted`; `unfilled` cuando el intento
  terminó en `.noInventory`.
- `RewardedOfferButton` lee de su entorno un `OfferFunnelReporter` (closure; por defecto no hace nada, así los previews
  y tests no cambian) y le pasa `(identifier, stage)`. `GameState+OfferFunnel` lo implementa anotando en
  `player.meta.offerFunnel` (y, desde T6, avisando a la telemetría).
- El «No, gracias» del paso 2 de B29 cuenta como `dismissed` del `site` del paso 2 (sale solo de la regla de
  `disappeared` si el paso 2 usa `RewardedOfferButton`).
- La sonda suma `ads.funnel.<site>.<stage>` con el contador, sólo con `--uitest-ad-value-probe`.

- [ ] **Step 1 (RED, escrito):** `OfferFunnelTrackerTests` (aparece listo → `shown` 1; tres sondeos más → sigue 1;
  doble toque → `accepted` 1; premio → `completed`; se va sin tocar → `dismissed`; se va después de tocar → nada;
  `noInventory` → `unfilled`); `OfferFunnelUITests`: (a) Regalos, mirar el video → `shown`, `accepted`, `completed`
  = 1; (b) con el Ministro del UI test de B29 (stub): «¡Dale!» y en el paso 2 «No, gracias» → `dismissed` = 1 en el
  `site` del paso 2.
- [ ] **Step 2 (GREEN).**
- [ ] **Step 3:** commit `feat(ads): el embudo cuenta cada oferta por lugar (E15 T3)`.

**Listo cuando:** (en T8) los tests verdes, el UI test de B29 del Ministro sigue verde, y ningún pop-up cambió de
comportamiento ni de layout (el embudo es invisible).

---

### E15-T4 — El esquema de Supabase en el repo, sin aplicar

**Modelo:** opus (privacidad: RLS). **Revisión:** opus. **Depende:** — (contrato C4/C5).

**Files:** los de T4 en la tabla.

- Migración `20261015000001_telemetry_schema.sql`:
  - `public.telemetry_events` con las columnas de C4 + `id uuid primary key default gen_random_uuid()` y
    `received_at timestamptz not null default now()`. `check`s: `name` en la lista cerrada, largos de C4,
    `storefront ~ '^[A-Z]{3}$'` o null, `jsonb_typeof(props) = 'object'`, `pg_column_size(props) <= 2048`,
    `client_ts` dentro de ±30 días de `now()`.
  - Índices `(name, received_at)` y `(install_id, received_at)`.
  - `insert into public.settings (key, value) values ('telemetry_enabled', 'false'::jsonb)`.
  - `public.telemetry_enabled()` `stable security definer set search_path = ''` que lee esa fila (falso si falta);
    `grant execute … to anon`.
  - RLS: `enable row level security`; **una sola política**, `for insert to anon with check
    (public.telemetry_enabled())`. `grant insert on public.telemetry_events to anon`; **ningún** `select`, `update` ni
    `delete` para `anon`/`authenticated` (respeta el `revoke all` y los default privileges de E12).
- Migración `20261015000002_telemetry_retention.sql`: job de `pg_cron` (mismo patrón que `ranking_cron`) que borra lo
  de más de **400 días** una vez por día.
- `supabase/tests/sql/05_telemetry_test.sql` (mismo estilo que `02_rls_test.sql`): con el interruptor apagado `anon` no
  inserta; prendido, inserta; `anon` nunca lee ni borra; cada `check` rechaza su basura; el cron existe.
- `admin.sql`, sección nueva al final «Telemetría (E15)»: prender y apagar el interruptor (`update settings …`), y
  consultas de lectura: impresiones y eCPM por país × formato, el embudo por `site`, sesiones por día, instalaciones
  activas por día.
- `README.md`: cómo aplicar (🔒 O2) y qué datos guarda.

- [ ] **Step 1 (RED):** `05_telemetry_test.sql` primero.
- [ ] **Step 2 (GREEN):** las dos migraciones y lo demás.
- [ ] **Step 3:** `supabase/test.sh --sql` **una vez** (Postgres descartable; no toca ninguna base). Pegar el resumen.
- [ ] **Step 4:** commit `feat(backend): la tabla de telemetría, de sólo insertar y apagada (E15 T4)`.

**Listo cuando:** los tests SQL verdes (los de E12 también); el interruptor sembrado en `false`; nada aplicado en el
proyecto real.

---

### E15-T5 — El cliente de telemetría (sin cablear)

**Modelo:** opus (privacidad). **Revisión:** opus. **Depende:** — (contratos C4/C5; ∥ T4).

**Files:** los de T5 en la tabla. No toca `GameState` ni `FisuEvolutionApp` (eso es T6).

**Interfaces:**
- `TelemetryEvent` (Codable con las claves de C4 en `snake_case`; `props` como `[String: TelemetryValue]` con
  `TelemetryValue` = string | int | double; constructores tipados por evento, sin `String` libre de afuera).
- `TelemetryQueue`: actor; persiste en `Application Support/telemetry-queue.json` (escritura atómica); tope **1000**
  eventos (saca los más viejos); `nextBatch(max: 50)` y `ack(batch)`; un archivo roto se descarta entero.
- `TelemetryGate`: C5.3, puro y con los insumos inyectados (`remoteEnabled`, `canRequestAds`, `arguments`,
  `isDebug`).
- `TelemetrySwitch`: C5.2, con `Fetch` inyectable como `HTTPRankingClient`; sesión efímera.
- `TelemetryUploader`: `POST {baseURL}/rest/v1/telemetry_events` con `apikey`/`Authorization: Bearer <anonKey>`,
  `Content-Type: application/json`, **`Prefer: return=minimal`** (sin `select` para `anon`, `return=representation`
  fallaría), cuerpo = arreglo del lote. 2xx → `ack`; 4xx → se descarta el lote (es un bug, reintentar no lo arregla) y
  se loguea; 5xx o sin red → queda en la cola con backoff (30 s, ×2, tope 30 min).
- `TelemetryService` (`@MainActor`): `record(_ event:)` → si `gate.canSend` encola, si no **descarta**; `flush()` al
  irse a background y cada 50 eventos; nunca bloquea el main actor.
- `DeviceContext`: `device_model`, `os_version`, `app_version`, `build`, `storefront` (async, cacheado).

- [ ] **Step 1 (RED, escrito):**
  - `TelemetryGateTests` — **el «Listo cuando» de la spec:** con un `Fetch` falso que cuenta pedidos, (a) interruptor
    apagado + consentimiento → **0 pedidos a `telemetry_events`** y la cola vacía; (b) interruptor prendido + sin
    consentimiento (`canRequestAds == false`) → 0 pedidos y cola vacía; (c) RPC con error/timeout/cuerpo raro →
    apagado; (d) bajo `--uitest-reset` → 0; (e) prendido + consentimiento → 1 pedido con el lote.
  - `TelemetryEventTests`: las claves codificadas son **exactamente** las de C4 (lista blanca: un campo nuevo rompe el
    test a propósito); `props` de cada evento con sus claves cerradas; nada de IDFA/IDFV/nombre.
  - `TelemetryQueueTests`: ida y vuelta por disco; tope 1000; lotes de 50; archivo roto → cola vacía.
  - `TelemetrySwitchTests`: `true` → prendido; `false`/404/sin red/no-HTTPS/`RankingConfig` no usable → apagado.
  - `TelemetryUploaderTests`: headers (incl. `Prefer: return=minimal`), 2xx ack, 4xx descarta, 5xx conserva.
- [ ] **Step 2 (GREEN).**
- [ ] **Step 3:** commit `feat(telemetria): el cliente con cola offline y compuerta, apagado por defecto (E15 T5)`.

**Listo cuando:** (en T8) todos verdes; con cualquier insumo dudoso, la compuerta dice que no.

---

### E15-T6 — Cablear la telemetría

**Modelo:** opus. **Revisión:** opus. **Depende:** T2, T3, T5.

**Files:** los de T6 en la tabla. En los `GameState+*.swift` ajenos, **una llamada** cada uno; en
`FisuEvolutionApp.startServices`, una línea (crear y adjuntar `TelemetryService` después de los anuncios, con la
`RankingConfig` cargada).

- Eventos: `session_start`/`session_end` desde `handleScenePhase` (activa / background, con la duración);
  `ad_impression` desde `recordImpression` (T2); `offer` desde el reporter del embudo (T3); `purchase` desde
  `creditStorePurchase` cuando acredita de verdad (no en restaurar ni en revocar); `prestige` desde `confirmPrestige`.
  `flush()` al irse a background.
- Todo pasa por `TelemetryService.record`: la compuerta de T5 manda. Nada se cablea por fuera.

- [ ] **Step 1 (RED, escrito):** `TelemetryWiringTests` con un `TelemetryService` de prueba que registra eventos:
  cada fuente emite **un** evento con sus `props` de C4; una compra restaurada no emite; con la compuerta cerrada
  (interruptor apagado) no sale ningún pedido de red aunque pasen las seis fuentes.
- [ ] **Step 2 (GREEN).**
- [ ] **Step 3:** commit `feat(telemetria): sesiones, impresiones, ofertas, compras y reencarnaciones (E15 T6)`.

**Listo cuando:** (en T8) verde; el arranque no espera a la red (el `TelemetrySwitch` corre en segundo plano).

---

### E15-T7 — Privacidad: borradores para el dueño y el manifiesto

**Modelo:** opus (privacidad). **Revisión:** opus. **Depende:** T4, T5 (los datos reales que se juntan).

**Files:** los de T7 en la tabla. **No toca** `privacy.md` ni `terms.md` (eso es T9, después del 🔒).

- `Distribution/release/privacidad-e15-BORRADOR.md`, con cada bloque listo para copiar:
  1. **`privacy.md`** (es y en; el bundle y el sitio son la misma copia byte a byte, y `SettingsPersistenceTests` exige
     que el resumen siga siendo un párrafo): qué se junta (C4), para qué (analítica propia y medir anuncios), qué **no**
     (IDFA, nombre, IP guardada), dónde (Supabase), cuánto dura (400 días), que no se vincula a la identidad, que no se
     vende ni se usa para rastrear, y cómo se apaga (el consentimiento de UMP en Ajustes > Opciones de privacidad).
  2. **`terms.md`:** la línea mínima que haga falta (si no hace falta ninguna, decirlo).
  3. **`adergames-site`** (`content/legal.ts`, `content/terms.ts`): el mismo cambio, como diff propuesto.
  4. **Etiqueta de App Privacy de ASC:** tabla de tipos de dato → «Usage Data · Product Interaction», «Usage Data ·
     Advertising Data», «Purchases · Purchase History», «Identifiers · Device ID» (el install id; ya declarado por el
     ranking, suma el propósito Analytics); todos **no vinculados** a la identidad, **sin tracking**, propósito
     Analytics (+ App Functionality donde ya estaba). Cómo se carga con `release-ops` (si la CLI no lo soporta,
     decirlo: lo hace el dueño en el panel).
  5. **AdMob:** los pasos para activar «impression-level ad revenue» con `release-ops` por Chrome (si pide la sesión
     del dueño, va a 🔒).
  6. Las notas a App Review: una línea nueva propuesta para `release.json → store.reviewNotes` **con el recorte** que la
     haga entrar en 4.000 caracteres (hoy 3.970; ver E10).
- `PrivacyInfo.xcprivacy`: el manifiesto tiene que decir la verdad del binario que se sube (aunque el interruptor esté
  apagado, el código junta): suma `NSPrivacyCollectedDataTypeProductInteraction`,
  `NSPrivacyCollectedDataTypeAdvertisingData`, `NSPrivacyCollectedDataTypePurchaseHistory` (Analytics, no vinculados,
  sin tracking) y el propósito Analytics a `DeviceID`. `NSPrivacyTracking` sigue `false`.
- `PrivacyManifestTests`: el conjunto esperado nuevo y los propósitos por tipo.

- [ ] **Step 1 (RED, escrito):** el test del manifiesto con el conjunto nuevo.
- [ ] **Step 2 (GREEN):** el manifiesto y el borrador.
- [ ] **Step 3:** commit `docs(e15): los textos de privacidad en borrador y el manifiesto al día (E15 T7)`.

**Listo cuando:** el borrador está completo (6 bloques) y marcado BORRADOR arriba; el manifiesto y su test coinciden.

---

### E15-T8 — Verificación única de F0 (controlador)

**Modelo:** el controlador del relevo. **Revisión:** opus sobre el diff entero de E15 (T1–T7). **Depende:** T1–T7
integradas en la integración.

- [ ] `xcodegen generate`, build y la suite: `swift test` de EK; las clases unit nuevas (`AdImpressionMapping`,
  `AdRevenueRecording`, `OfferFunnelTracker`, `Telemetry*`, `PrivacyManifest`, `SettingsPersistence`) y los UI
  `AdRevenueLedgerUITests`, `OfferFunnelUITests`, `RewardedOfferUITests` y el del Ministro de B29 (Receta R para los
  UI). Lo más barato: entra en el `completo` de la ola si coincide.
- [ ] `supabase/test.sh` (SQL y deno: el ranking no se rompió).
- [ ] **Economía intacta:** el pacing-sim da **exactamente** lo mismo que en la BASE (Dios y reencarnaciones), y
  `git diff --stat <BASE>..` no nombra ningún archivo de la lista de «F0 no toca la economía».
- [ ] La revisión opus mira: la compuerta (tres capas apagadas, descarta sin encolar), que ningún evento lleve datos
  personales, que el contrato de `showRewarded` siga igual, que el save viejo abra, y B22 (`NSPrivacyTracking` false).
- [ ] Los rojos se arreglan en el momento (regla del dueño: build único por ola, correcciones ahí).
- [ ] Al cierre: filas E15-T1…T7 a 🟢 en `tasks.md`; los 🔒 O1–O6 cargados en `DUENO.md`; doc de sesión.

**Listo cuando:** todo lo anterior verde, y los 🔒 del dueño anotados. **F0 queda cerrada del lado del código** aunque el
interruptor siga apagado.

---

### E15-T9 — Aplicar los textos aprobados (después del 🔒 O1)

**Modelo:** sonnet (copiar texto aprobado). **Revisión:** opus. **Depende:** 🔒 O1.

- Copiar el texto **tal cual lo aprobó el dueño** a `Distribution/site/privacy.md` y `FisuEvolution/Resources/Legal/privacy.md`
  (byte a byte), y a los `terms.md` si correspondía; el sitio, en una rama local de `adergames-site` sin pushear (el
  push es 🔒 O5). `SettingsPersistenceTests` al día si el texto lo pide.
- Si el 🔒 O1 llega **después** del archive de la 2.0 (E10 T12), el bundle sale con el texto viejo y el interruptor
  sigue apagado hasta que un binario con el texto nuevo esté en la tienda (ver Dudas, 4).

**Listo cuando:** las dos copias iguales, la rama del sitio lista, el dueño avisado.

---

## 🔒 Del dueño (nada de esto lo hace un agente)

| # | Qué | Cuándo |
|---|---|---|
| O1 | **Aprobar los textos** de `Distribution/release/privacidad-e15-BORRADOR.md` (privacidad, términos, sitio, etiqueta de ASC). | después de T7; idealmente antes del archive de la 2.0 (E10 T12) |
| O2 | **Aplicar las migraciones** de T4 en el proyecto de Supabase (`supabase db push` o el SQL editor). | después de T8; el interruptor queda en `false` |
| O3 | **Activar «impression-level ad revenue»** en la cuenta de AdMob (con `release-ops` por Chrome; si pide su sesión, la hace él). | antes de lanzar: sin esto `paidEventHandler` no recibe valores |
| O4 | **Actualizar la etiqueta de App Privacy** en App Store Connect con lo aprobado en O1 (`release-ops`). | antes de mandar la 2.0 a revisión |
| O5 | **Publicar el sitio** (`git push` de `adergames-site`: Vercel despliega) con la política nueva. | después de O1 y T9 |
| O6 | **Prender el interruptor** (`update settings set value = 'true'::jsonb where key = 'telemetry_enabled';`, en `admin.sql`). | sólo con O1–O5 hechos y un binario con el texto nuevo en la tienda |

## Dudas (con el default que se usa si nadie dice otra cosa)

1. **ATT no frena la telemetría; UMP sí.** El install id es propio, no se cruza con datos de terceros ni se comparte:
   no es «tracking» para Apple, así que pedir ATT para mandarlo cortaría la mayoría de los datos sin necesidad. La
   compuerta usa el consentimiento de UMP (`canRequestAds`), que en la UE/RU/Suiza es la respuesta del jugador y en el
   resto es «no hace falta». **Default:** así. Si el dueño prefiere lo más conservador (también ATT autorizado), es
   una línea en `TelemetryGate`.
2. **Sin interruptor propio en Ajustes en F0.** El jugador lo apaga desde las opciones de privacidad de UMP (donde
   aplica). **Default:** no se agrega una fila nueva a Ajustes (sería UI y textos nuevos); si el dueño la quiere, va
   como tarea aparte en F1.
3. **`device_model` crudo** (`iPhone16,2`) en vez de un «rango»: el rango es una tabla que arma R3 en la 2.1 con datos
   reales, y el identificador de modelo no identifica a nadie. **Default:** crudo.
4. **Si O1 llega después del archive**, el binario sale con la política vieja y el manifiesto nuevo (que es lo que
   el código hace); el interruptor no se prende hasta que haya un binario con el texto nuevo. **Default:** así; no se
   frena el lanzamiento por F0.
5. **Spam con la clave anon:** la clave es pública (va en el bundle) y RLS no limita la tasa. **Default:** se acepta
   en F0 (los `check` y el tope de 2 KB acotan el daño, y el interruptor lo corta en un segundo); si aparece abuso,
   F7 pasa la ingesta a una edge function con límite por `install_id`.
6. **Retención de 400 días** (un año y un mes, para comparar contra el mismo mes del año anterior). **Default:** 400.
7. **Moneda de los agregados del ledger:** la de la primera impresión (AdMob informa en la moneda de la cuenta).
   **Default:** así, con el contador de impresiones en otra moneda para verlo si pasa.
8. **El «site» del embudo es el id de accesibilidad del botón.** Ya es estable y único por fila del mapa de
   ubicaciones (`AdPlacementMapTests`). **Default:** así; si un id lleva partes dinámicas, el tope de 64 claves lo
   contiene.
