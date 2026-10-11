# Auditoría — compras y anuncios de la 2.0 (2026-10-11)

Foto de hoy de código ↔ `release.json` ↔ App Store Connect ↔ AdMob ↔ sitio, sobre el árbol `baaec2e`
(`version-2` con la ola r31 integrada hasta E7b-b T2). Todo en modo lectura: ningún `apply`, ningún
`asc screenshot`, ningún `admob set-id`, nada en un panel. Sigue el formato de
`AUDITORIA-2026-10-08.md`; los estados usan el vocabulario de `release-ops`.

## Resumen

| Frente | Resultado | Evidencia |
|---|---|---|
| `release.json` | VERDE, 0 errores, 0 avisos | `releaseops validate` (el 10-08 tenía 3 avisos: las ofertas ya las pide el código) |
| Compras (14) | ASC coincide con la config; 11 aprobadas desde la v1, 3 ofertas `MISSING_METADATA` | `asc diff` → VERDE; `asc status` |
| Listas para revisión | 11 de 14; faltan las 3 ofertas (cada una: captura + metadata) | `asc ready` → ROJO, 6 pendientes |
| Ficha de la 2.0.0 | 1 diferencia: las notas a App Review (ASC tiene las del 10-08, 3.459 caracteres; la config 3.970) y 2 manuales (Mac, Vision Pro) | `asc listing diff` → ROJO |
| Unidades de AdMob (11) | las 11 de la config tienen ID; coinciden con los dos JSON del juego y con la config remota publicada | `admob plan`; comparación de ids abajo |
| Sitio | `app-ads.txt` publicado == local, **ya con la línea de Meta**; `config/ads.json` publicado == el del juego | `curl` + `diff` |
| Código | las 14 ofertas/compras coinciden con `products.json`, `.storekit` (ids y precios) y el catálogo `iap.*`; **hay 4 hallazgos reales** (ver "No coincide" y "Falta") | secciones siguientes |

## Compras (14)

Leyenda de la columna "Código": ids, tipo y monto de `products.json`; textos del catálogo
`Localizable.xcstrings` (`iap.<id>.name/.desc`, que la UI prefiere al de StoreKit vía `IAPCopy`).

| Producto | Tipo | USD | `asc status` | Código (ids / tipo / monto) | Textos | Estado |
|---|---|---:|---|---|---|---|
| coins_small | Consumible | 0.99 | APPROVED | coins, 60 min | idénticos a release.json | Listo para revisión |
| coins_medium | Consumible | 4.99 | APPROVED | coins, 360 min | idénticos | Listo para revisión |
| coins_large | Consumible | 9.99 | APPROVED | coins, 1440 min | idénticos | Listo para revisión |
| oro_small | Consumible | 1.99 | APPROVED | oro, 160 | idénticos (el juego antepone `%@` = 160) | Listo para revisión |
| oro_medium | Consumible | 4.99 | APPROVED | oro, 550 | idénticos ("Saco de ORO"); **`.storekit` dice "Cofre de ORO"** | Listo para revisión |
| oro_large | Consumible | 9.99 | APPROVED | oro, 1400 | idénticos | Listo para revisión |
| remove_ads | No consumible | 2.99 | APPROVED | removeAds | idénticos; `.storekit` viejo | Listo para revisión |
| starter_pack | No consumible | 4.99 | APPROVED | starterPack: skin mundialista + 240 min + sin anuncios (`removeAdsProductIDs` lo incluye) | idénticos; `.storekit` viejo | Listo para revisión |
| skin_mundialista | No consumible | 2.99 | APPROVED | skin `mundialista` | idénticos; `.storekit` viejo | Listo para revisión |
| skin_parrillero | No consumible | 2.99 | APPROVED | skin `parrillero` | idénticos | Listo para revisión |
| skins_diamante | No consumible | 19.99 | APPROVED | skin `diamante` | "43 personajes": `skins.json` tiene 43 entradas `diamante` (coincide) | Listo para revisión |
| offer_bienvenida | Consumible | 0.99 | **MISSING_METADATA** | offer `bienvenida`, trigger `secondDay`, `oncePerAccount`, ventana 24 h; recompensa 120 ORO + 7200 s + 1 cofre de pintas | idénticos; "2 h de ingresos" = 7200 s | Configurado (falta captura) |
| offer_renacer | Consumible | 2.99 | **MISSING_METADATA** | offer `renacer`, trigger `reincarnation`; 300 ORO + 14400 s + ×3 por 1800 s | idénticos; "4 h", "×3 por 30 min" coinciden | Configurado (falta captura) |
| offer_mudanza | Consumible | 4.99 | **MISSING_METADATA** | offer `mudanza`, trigger `newFloor`; 500 ORO + 28800 s + 3 paquetes | idénticos; "8 h", "3 Paquetes" coinciden | Configurado (falta captura) |

Ids, tipos y precios: los 14 coinciden entre `release.json`, `products.json`, `FisuEvolution.storekit`
(precio `displayPrice` y tipo) y `offers.json` (los 3 `productId` de ofertas). `familySharable` es
`false` en los 14 y en el `.storekit`. Las 3 notas de revisión de ofertas de `release.json`
(24 h, 2.º día calendario, tras reencarnar, piso nuevo) coinciden con `offers.json`
(`windowHours: 24`, triggers) y con el motor (`OffersEngine`: `secondDay`, `reincarnation`,
`newFloor`; `bienvenida` una sola vez; `cooldownDays: 3` no figura en ningún texto, no hace falta).
Los montos de ORO de las notas ("Gives 160/550/1,400 ORO") coinciden con `oroAmount`.
`PurchasedOroHistory` (250/750/2000) es la foto de la v1 a propósito: no es un desfase.

## Unidades de anuncio (11)

Ids: las 11 de `release.json → admob.units` son idénticas, una por una, a las de `ads.json` y
`feature_flags.json` (`adUnitIDs`), y el `ads.json` publicado en
`adergames-site.vercel.app/config/ads.json` es idéntico al del juego. `GADApplicationIdentifier` del
`Info.plist` = `admob.appId`. Los IDs de prueba están sólo en `FeatureFlags` (`testUnitIds`) y en
`release.json → admob.testUnitIds`.

| Unidad (AdMob) | Formato | Clave | Ubicaciones en el código | Estado |
|---|---|---|---|---|
| anuncio normal | Intersticial | `interstitial` | cortes naturales (`NaturalBreakPolicy`: cerrar menú, cerrar popup offline, reencarnar, fin de celebraciones), alterna con la pausa | Integrado en el código |
| pausa publicitaria | Bonificado intersticial | `rewardedInterstitial` | `GameState+Ads.showRewardedInterstitial`, alterna con el normal; intro de 5 s | Integrado en el código |
| app open | Inicio de aplicación | `appOpen` | `GameState+Ads` (`.returnFromBackground`); `switches.appOpen: true`; 180 s fuera, 20 min entre, sesión >= 2 | Integrado en el código |
| regalos | Bonificado | `rewardedGifts` | `.gifts`: la lista de Regalos (4 premios de `rewarded_ads.json`: `double_earnings`, `temp_multiplier`, `spawn_rare`, `skin_chest`; **sin `merge_all`**) y fallback de todas las unidades sin id propio | Integrado en el código |
| offline x2 | Bonificado | `rewardedOfflineX2` | `.offlineX2`: `OfflineEarningsView` | Integrado en el código |
| cofre extra | Bonificado | `rewardedChestExtra` | `.chestExtra`: `ChestOpeningView` | Integrado en el código |
| boosts | Bonificado | `rewardedBoost` | `.boost`: el botón "activar ya" de Regalos (`GiftsView`). El comentario del enum y `setup §405` le asignan además "Fusionar todo" de la columna | Integrado; la parte de la columna **sin UI** (ver "Falta") |
| ruleta | Bonificado (1 premio) | `rewardedWheel` | `.wheel`: girar y "repetir premio" (`WheelView`) | Integrado en el código |
| colchón | Bonificado (1 premio) | `rewardedTreasure` | `.treasure`: "abrir" y "otro colchón" (`MattressPopupView`); la lluvia de paquetes de la columna iría acá | Integrado; la lluvia **sin UI** |
| visitantes | Bonificado (1 premio) | `rewardedVisitor` | `.visitor` (valor por defecto de `RewardedOfferButton`): `VisitorPopupView`, `VendorCardsView`, `EventPopupView` (escape) | Integrado en el código |
| diario | Bonificado (1 premio) | `rewardedDaily` | `.daily`: `DailyRewardView`, `CareerChoiceView` | Integrado en el código |

Todas las unidades: existentes en AdMob desde el 10-08 (6 de la v1, 5 creadas ese día; ninguna
duplicada). Formato `rewarded` con 1 "premio" para las cuatro nuevas, `eCPM` "optimizada, límite
alto", sin tope de frecuencia: sin cambios desde la auditoría anterior. **Esta sesión no leyó el
panel de AdMob** (sin sesión de navegador del dueño; `admob plan` es sólo coherencia de la config,
no consulta la cuenta): el estado "existe en AdMob" es el del 10-08.

Mediación (`release.json → mediation`, sin cambios hoy): Unity activa (9 asignaciones), Meta con
onboarding del dueño pendiente, AppLovin y Mintegral afuera. Grupos: "Rewarded iOS" (8 unidades,
unity + meta), "Interstitial iOS" (1 unidad), "Rewarded interstitial iOS" (sólo meta, a crear
cuando Meta esté activa).

## Lo que sobra

- Nada de sobra en las 14 compras ni en las 11 unidades: cada producto tiene entrada en
  `products.json` y cada unidad tiene al menos una ubicación viva (salvo lo de "Falta").
- `PurchasedOroHistory.v1OroAmountByProductID` (250/750/2000) parece un desfase con 160/550/1400
  pero es la foto de la v1, intencional.

## Lo que no coincide

| # | Qué | Dónde | Detalle | Dueño |
|---|---|---|---|---|
| 1 | **Notas a App Review nombran a AppLovin y Mintegral** | `release.json → store.reviewNotes` (encabezado "ADS …"); ASC tiene la copia del 10-08 de 3.459 caracteres (`asc listing diff` pide `set-review-notes`) | La decisión del dueño del 10-08: las redes son Google + Unity + Meta. Las notas siguen con las cuatro. Además no hay margen: 3.970 de 4.000 caracteres | E10 T5/T11 (`release.json` tiene un dueño) y 🔒 `asc listing apply` |
| 2 | **`FisuEvolution.storekit` con textos viejos** | `StoreKitConfig/FisuEvolution.storekit` | Difieren de `release.json` y del catálogo: `oro_medium` ("Cofre de ORO"/"Chest of ORO" vs "Saco de ORO"/"Sack of ORO"; el nombre viejo es el que la guía 3.1.1 hizo cambiar), `oro_small`, `remove_ads`, `skin_mundialista`, `starter_pack` (en es y en en), y `skins_diamante` (sufijo ", de una"/"at once"; en el catálogo la versión en inglés sí lo tiene). Ids, tipos y precios sí coinciden. Sólo afecta el desarrollo local y las capturas con StoreKit local (el nombre en pantalla sale del catálogo `iap.*`; el `.storekit` es el `fallback` y lo que ve el diálogo de compra local) | tarea de E6/E10 sobre `StoreKitConfig/` |
| 3 | **Lista de ubicaciones de las notas anterior a la columna de E7b-b** | `release.json → store.reviewNotes` ("Places: …") | Menciona "Merge all" junto a "starting a boost without waiting" (lugar `boost`) y "parcel rain" junto al colchón, pero **sin la columna lateral**: hoy "Fusionar todo" por video sólo se alcanza desde la columna (`SideRailModel`, `mergeAllVideoWatched`), no desde Regalos. La frase "the Gifts list (Bonus tab)" es correcta (Regalos tiene 4 premios sin `merge_all`, ratificado por `GameContentValidationTests` línea 250). Hay que reescribir el párrafo cuando E7b-b T3 deje la columna a la vista | E10 T11 (tras E7b-b T8) |
| 4 | **Comentarios de unidad desfasados** | `Distribution/setup-v2-asc-admob-mediacion.md` (§ unidades) y el doc del enum `RewardedPlacement.boost` | Dicen que `rewardedBoost` sirve "Fusionar todo"; en el código la columna todavía no tiene UI que lo pida, y aún no hay decisión escrita de qué `RewardedPlacement` usa cada video de la columna (`mergeAllVideoWatched`/`packageRainVideoWatched` no reciben placement). No es un error, es una decisión sin tomar | E7b-b T3 |

## Lo que falta

| Qué | Bloquea | Dueño |
|---|---|---|
| **UI de la columna lateral**: nadie llama a `canOfferMergeAllVideo`, `canOfferPackageRainVideo`, `mergeAllVideoWatched` ni `packageRainVideoWatched` (sólo los tests). Sin eso "Fusionar todo" por video y la lluvia de paquetes **no se pueden ver en el juego**, y las notas a App Review los prometen. Es la "columna de E7b-b" con "Fusionar todo" sólo ahí y Regalos sin `merge_all` | que el reviewer encuentre lo que las notas describen; relleno de la unidad `boosts`/`colchón` con esos usos | E7b-b T3 (en vuelo) |
| Capturas de revisión de las 3 ofertas (`reviewScreenshot: offer-sheet`) | que pasen de `MISSING_METADATA` a `READY_TO_SUBMIT` (`asc ready` los lista como 6 pendientes: 3 capturas + 3 metadata) | T9 (capturas con `--uitest-offer=<id>`) + 🔒 `asc screenshot` |
| Notas a App Review actualizadas en ASC | que lo publicado diga lo mismo que `release.json` | 🔒 `asc listing apply`, tras corregir el hallazgo 1 |
| Mac y Vision Pro destildados en Pricing and Availability | publicar | 🔒 dueño, en el panel (`asc listing diff`: 2 acciones manuales) |
| Onboarding de Meta (5 tareas: 2FA, pagos, datos fiscales, vincular app, verificar) y el acuerdo de socio en AdMob | que Meta puje; el grupo "Rewarded interstitial iOS" | 🔒 dueño |
| Lista ampliada de SKAdNetwork de Unity (+39) en el `Info.plist` (hoy 50, la de Google) | relleno de Unity | E7b-a T6 (SPM, 🔒 dueño) |
| Mensaje de consentimiento UE/EE. UU. en AdMob "Privacidad y mensajería" (no existía el 10-08; hoy no se pudo releer) | ads en la UE | 🔒 dueño; verificar en el panel |
| Adjuntar las 14 compras a la 2.0.0 y enviar | revisión | 🔒 dueño con el build |
| Probar compra sandbox y Ad Inspector en dispositivo | "validado con pruebas" | tras el build |

## Ya resuelto desde el 10-08 (tachado de la lista de entonces)

- Las ofertas en `products.json`, `offers.json` y `iap.<id>.*`: hechas (E6a T11/T12). Los 3 avisos de `validate` desaparecieron.
- `app-ads.txt` con la línea de Meta (`facebook.com, 4634477516796912, RESELLER, c3e20eee3f780d68`, línea 167): **ya está publicada** y es idéntica a la local (HTTP 200). El plan de E10 daba esa línea por faltante: ya no hace falta T4 para eso (ver T4 por `legal.ts`/`terms.ts`).
- Regalos sin `merge_all`: verificado en `rewarded_ads.json` y en el test de contenido.

## Cómo se verificó

```
python3 Tools/releaseops/releaseops.py validate        # VERDE: 0 errores, 0 avisos
python3 Tools/releaseops/releaseops.py asc status      # 14 productos, 11 APPROVED, 3 MISSING_METADATA
python3 Tools/releaseops/releaseops.py asc diff        # VERDE: App Store Connect == config
python3 Tools/releaseops/releaseops.py asc ready       # ROJO: 6 pendientes (3 capturas + 3 MISSING_METADATA)
python3 Tools/releaseops/releaseops.py asc listing diff # ROJO: set-review-notes + 2 manuales
python3 Tools/releaseops/releaseops.py admob plan      # todas las unidades tienen ID
curl -s https://adergames-site.vercel.app/app-ads.txt | diff - <adergames-site>/public/app-ads.txt   # sin diferencias
curl -s https://adergames-site.vercel.app/config/ads.json  # idéntico a FisuEvolution/Resources/Config/ads.json
```

Código: comparación de `release.json` con `products.json`, `offers.json`, `ads.json`,
`feature_flags.json`, `FisuEvolution.storekit`, el catálogo `iap.*` de `Localizable.xcstrings`,
`RewardedPlacement`/`FeatureFlags.AdUnitIDs`, `NaturalBreakPolicy`, `GameState+SideRail` y los usos
de `RewardedOfferButton`/`placement:` en `FisuEvolution/UI`. Sin credenciales nuevas, sin navegador,
sin escrituras.
