# Auditoría — compras y anuncios de la 2.0 (2026-10-08)

Qué se configuró en App Store Connect y en AdMob para la próxima build, en qué estado quedó cada
cosa y qué falta. Lo hizo `Tools/releaseops` contra `Distribution/release/release.json`; el cómo
está en la skill `.claude/skills/release-ops/`.

## Resumen

| Frente | Resultado | Evidencia |
|---|---|---|
| Compras (14) | Configuradas: ASC coincide con la config | `asc diff` → VERDE |
| Listas para revisión | 11 de 14: faltan las capturas de las 3 ofertas | `asc ready` → ROJO, 6 pendientes (3 capturas + 3 MISSING_METADATA) |
| Unidades de AdMob (11) | 5 creadas hoy + 6 de la v1; ninguna duplicada | lista del panel: 11 unidades |
| Código | IDs en `feature_flags.json` y `ads.json`; `switches.appOpen` prendido | `validate` → VERDE (3 avisos: ofertas que el código todavía no pide) |
| Tests del juego | `AdUnitIDsTests` y `AdsRemoteConfigTests` actualizados al gate cumplido | `oraculo.sh tarea AdUnitIDsTests AdsRemoteConfigTests GameContentValidationTests` |

## App Store Connect — HoboEvolution (6814521946)

Lo que había antes (leído por API, no supuesto): las 11 compras de la v1 **APPROVED**, con en-US y
es-MX **aprobados**, disponibles en 175 territorios y en los nuevos, sin nota de revisión, con su
captura de revisión. Los Reference Name reales son los nombres en inglés ("Handful of Gold"…): la
config los adoptó y no se tocaron.

| Producto | Tipo | USD | Estado del producto | Qué se hizo |
|---|---|---:|---|---|
| coins_small / medium / large | Consumible | 0.99 / 4.99 / 9.99 | APPROVED | + es-ES |
| oro_small | Consumible | 1.99 | APPROVED | + es-ES; textos 2.0 en en-US y es-MX; nota "Gives 160 ORO." |
| oro_medium | Consumible | 4.99 | APPROVED | + es-ES; **"Cofre de ORO" → "Saco de ORO"** ("Chest of Gold" → "Sack of ORO"), por la guía 3.1.1; nota |
| oro_large | Consumible | **9.99** (era 4.99) | APPROVED | + es-ES; typo en vivo corregido ("want it alland…"); nota; **precio 4.99 → 9.99, aprobado por el dueño** |
| remove_ads | No consumible | 2.99 | APPROVED | + es-ES; descripción 2.0; nota |
| skin_mundialista | No consumible | 2.99 | APPROVED | + es-ES; en-US "World Cup Skin" → "Mundialista Skin"; es-MX descripción completa |
| skin_parrillero | No consumible | 2.99 | APPROVED | + es-ES; es-MX descripción completa |
| skins_diamante | No consumible | 19.99 | APPROVED | + es-ES; en-US descripción completa |
| starter_pack | No consumible | 4.99 | APPROVED | + es-ES; descripción 2.0; nota |
| offer_bienvenida | Consumible | 0.99 | MISSING_METADATA | **creada**: es-MX, es-ES, en-US, precio, 175 territorios, nota |
| offer_renacer | Consumible | 2.99 | MISSING_METADATA | **creada**, ídem |
| offer_mudanza | Consumible | 4.99 | MISSING_METADATA | **creada**, ídem |

Los textos nuevos de las 11 viven en **borradores** (PREPARE_FOR_SUBMISSION) que conviven con los
aprobados: en la tienda se sigue viendo el texto aprobado hasta que la 2.0 pase revisión con estas
compras adjuntas. Todos los idiomas nuevos y editados están en PREPARE_FOR_SUBMISSION.

Logs: `~/.releaseops/logs/20261008-042243-asc-apply.jsonl` y `…-042743-asc-apply.jsonl`.

## AdMob — app `ca-app-pub-8575641544774372~3243441080`

| Unidad | Formato | ID | Clave en `adUnitIDs` | Estado |
|---|---|---|---|---|
| anuncio normal | Intersticial | …/5270838626 | interstitial | existía |
| pausa publicitaria (era "unidad") | Intersticial bonificado | …/1615619906 | rewardedInterstitial | existía, **renombrada** |
| regalos | Bonificado | …/8304196070 | rewardedGifts | existía (ya renombrada antes) |
| offline x2 | Bonificado | …/6825744243 | rewardedOfflineX2 | existía |
| cofre extra | Bonificado | …/3981807683 | rewardedChestExtra | existía |
| boosts | Bonificado | …/4913896772 | rewardedBoost | existía |
| ruleta | Bonificado (1 premio) | …/1366235671 | rewardedWheel | **creada** |
| colchón | Bonificado (1 premio) | …/1912941292 | rewardedTreasure | **creada** |
| visitantes | Bonificado (1 premio) | …/8454388206 | rewardedVisitor | **creada** |
| diario | Bonificado (1 premio) | …/1697408166 | rewardedDaily | **creada** |
| app open | Inicio de aplicación | …/3573507326 | appOpen | **creada** |

Las cinco nuevas: todos los tipos de anuncio, sin límite de frecuencia, eCPM "Optimizada por
Google" con **límite mínimo alto**, sin "ofertas para socios". AdMob avisa que una unidad nueva
puede tardar hasta una hora en servir.

## Ficha de la versión 2.0.0 (agregado 09:37)

`asc listing diff` → VERDE. Versión **2.0.0 creada** en App Store Connect (PREPARE_FOR_SUBMISSION,
no enviada). en-US y es-MX con la descripción de la 2.0 (sin "Mercado Pago", con visitantes e
iPad) y las Novedades; **es-ES nuevo** (FisuEvolution, mismos textos que es-MX); notas para App
Review de la 2.0 (3459 caracteres). Cuestionario de edad: ya estaba como pide el setup desde la
v1 (loot boxes sí, apuestas no, publicidad sí), no se tocó. `ads.json` publicado en
`adergames-site.vercel.app/config/ads.json` (200, idéntico al del juego). Las Novedades y las
notas se revisan contra la build de TestFlight antes de enviar.

## Mediación (agregado 12:50)

| Pieza | Estado | Evidencia |
|---|---|---|
| Unity Ads en AdMob | ✅ fuente activa; 9 asignaciones (Game ID 800392624; BP_Rewarded_iOS ×8, BP_Interstitial_iOS ×1) | AdMob: "La asociación está activa"; "Los cambios se guardaron correctamente" |
| Grupo "Rewarded iOS" | ✅ ID 1870390862: 8 unidades bonificadas, AdMob + Unity por licitación | edición del grupo releída |
| Grupo "Interstitial iOS" | ✅ ID 2477738028: "anuncio normal", AdMob + Unity | ídem |
| Unity: Developer website | ✅ `https://adergames-site.vercel.app`; Unity ya lee el `app-ads.txt` del sitio | Monetization > Settings |
| `app-ads.txt` | ✅ 163 vendedores (Google + 161 de Unity + Meta), `text/plain` | `curl` 200 |
| Meta en AdMob | ⏳ paso 1 aceptado; el acuerdo de socio (paso 2) espera que Meta termine su onboarding | AdMob: "Usted inició un formulario de acuerdo de socio" |
| Meta: propiedad y ubicaciones | ✅ HoboEvolution iOS, 3 ubicaciones "listas para publicar"; mediación = Google AdMob | Monetization Manager |
| Meta: onboarding | 🔒 dueño: 2FA, cuenta de pagos, datos fiscales, vincular la app al pago, verificar la app | "5 tareas por completar" |
| Grupo "Rewarded interstitial iOS" | ⏳ sólo Meta puja en ese formato: se crea cuando Meta esté activa | — |
| App open | sin grupo: ni Unity ni Meta pujan en app open (queda AdMob) | — |
| Consentimiento UE (socios) | ✅ "Agregar automáticamente fuentes como socios publicitarios" encendido | guardado |
| **Mensaje de consentimiento UE / estados de EE. UU.** | ❌ **no existe ninguno** (la tarjeta dice "Crear") | Privacidad y mensajería |

## Pendiente (y de quién)

| Pendiente | Bloquea | Quién |
|---|---|---|
| Capturas de revisión de las 3 ofertas (`asc screenshot`) | que las ofertas pasen a READY_TO_SUBMIT | relevo, cuando exista la hoja de oferta (E6a T11, `--uitest-offer=<id>`) |
| Las ofertas en `products.json`, el `.storekit`, `offers.json` y `iap.<id>.*` | que el juego las pida | E6a T11 |
| `.storekit` local con textos viejos | sólo el desarrollo local | E6 (sincronizar con release.json) |
| Mac y Vision Pro apagados; App Privacy | publicar | navegador con la sesión del dueño en ASC; App Privacy tras el reporte del archive y las 4 redes |
| Grupos de mediación (4) y las 4 redes | relleno de anuncios | dueño: cuentas de AppLovin, Unity, Mintegral y Meta |
| `app-ads.txt` con las redes; SKAdNetwork (+106) | mediación | E7b-a T6 + dueño |
| Adjuntar las 14 compras a la versión 2.0.0 y enviar | revisión | 🔒 dueño, con la build |
| Probar compra sandbox y Ad Inspector en dispositivo | "validado con pruebas" | después de la build |

Nada de esto quedó "funcionando" todavía en el sentido fuerte: las compras están configuradas
(y 11 aprobadas desde la v1), las unidades creadas e integradas en la config; la validación con
pruebas reales es posterior a la build.
