---
name: release-ops
description: Use when FisuEvolution (HoboEvolution) needs anything commercial or release-side touched — in-app purchases in App Store Connect (create, edit texts/locales, prices, review screenshots, readiness), AdMob ad units (create, rename, wire IDs into the code), version/build numbers, archiving/uploading a build, or a full "publish the new version with these IAPs and ad units" flow. Also when checking that App Store Connect, AdMob and the code agree.
---

# release-ops — lo comercial y la publicación, como código

La fuente de verdad es **`Distribution/release/release.json`** (versionada). Todo lo
demás se compara contra ella:

```
release.json ──validate──▶ el código (products.json, feature_flags.json, ads.json, Info.plist)
     │
     ├──asc plan/apply/diff/ready──▶ App Store Connect (API oficial)
     └──admob plan + navegador────▶ AdMob (sin API de escritura: Claude in Chrome)
```

CLI: `python3 Tools/releaseops/releaseops.py <área> <comando>` (sólo stdlib; la firma
ES256 la hace el `openssl` del sistema). Tests: `python3 -m unittest discover Tools/releaseops/tests`.

## Reglas que no se negocian

- **Siempre primero el estado, después el cambio.** `asc plan` es dry-run; `asc apply --yes` aplica
  sólo la diferencia y vuelve a leer al final. Repetirlo no duplica nada; una corrida cortada se
  retoma corriendo lo mismo.
- **Nada borra.** Un producto o unidad que sobra se reporta. Un Product ID no se reusa nunca
  (Apple lo prohíbe aunque se borre).
- **Piden OK explícito del dueño:** precios nuevos o cambios de precio (`--allow-price-change`),
  aceptar acuerdos, borrar recursos, subir un build, enviar a revisión, publicar. Escribir en
  producción también: el clasificador de auto mode frena `asc apply` hasta que el dueño lo aprueba
  en el chat.
- **Credenciales fuera del repo.** `~/.appstoreconnect/releaseops.json` (`issuerId`, `keyId`,
  `keyPath`) y la `.p8` en `~/.appstoreconnect/private_keys/`, ambos con permisos 600. El agente no
  crea keys, no tipea contraseñas ni códigos 2FA: los pide.
- **No decir "funciona" sin haberlo verificado.** Usá el vocabulario de estados de abajo.

## Estados (decir siempre cuál)

| Estado | Cómo se verifica |
|---|---|
| Configurado | `asc diff` verde / la unidad figura en la lista de AdMob |
| Listo para revisión | `asc ready` verde (precio, disponibilidad, captura, sin MISSING_METADATA) |
| En revisión / Aprobado | `asc status` (estado del producto y de cada idioma) |
| Integrado en el código | `validate` verde (IDs en products.json / adUnitIDs) |
| Validado con pruebas | tests del juego + compra sandbox / Ad Inspector en un dispositivo |
| Disponible a la venta | aprobado + la versión de la app publicada |

## Comandos

| Comando | Qué hace |
|---|---|
| `validate` | Config ↔ código, sin red. Oráculo de cualquier cambio. |
| `asc status [--json f]` | Foto de App Store Connect: tipo, estado, precio USD, idiomas. |
| `asc plan` | Dry-run: acciones para llevar ASC a la config. Exit 1 si hay diferencias. |
| `asc apply --yes [--allow-price-change]` | Aplica el plan. Log en `~/.releaseops/logs/`. |
| `asc diff` | Exit 0 si ASC == config. |
| `asc ready` | Exit 0 si todos los productos pueden ir a revisión con la versión. |
| `asc screenshot <producto> <png>` | Sube la captura de revisión (no reemplaza una existente). |
| `asc listing plan\|apply --yes\|diff` | Ficha de la versión (`store` en release.json): crea la versión si falta, textos por idioma, notas para App Review. Mac/Vision Pro quedan como pasos manuales. |
| `admob plan` | Unidades de la config sin ID: las que hay que crear. |
| `admob set-id <clave> <id>` | Anota el ID devuelto por AdMob (valida publisher y `/`). |
| `admob sync-code [--dry-run]` | Copia los IDs a `feature_flags.json` y `ads.json` (sólo esas líneas) y prende `switches.appOpen` si hay unidad. |
| `version bump [--patch\|--minor] [--dry-run]` | `project.yml`: sube el build (y la versión si se pide). |

## Recetas

### Agregar una compra
1. Sumarla a `release.json` (`productId` con el prefijo, `type`, `priceUSD`, `referenceName`, las
   tres localizaciones —es-MX y es-ES llevan el mismo texto—, `reviewNote`, `since`). Límites:
   nombre 2–30, descripción ≤ 45, Reference Name ≤ 64, nota ≤ 4000.
2. `validate` → el aviso "el código todavía no lo pide" es esperable hasta que el juego la sume a
   `products.json` y al `.storekit`.
3. `asc plan` → mostrar el plan al dueño (precio incluido) → `asc apply --yes` con su OK.
4. Cuando la pantalla exista: `asc screenshot <producto> captura.png` → `asc ready`.

### Cambiar textos de una compra aprobada
Se edita `release.json` y `asc apply`. ⚠️ Un idioma APPROVED no se puede editar (409 "ACTIVE"):
Apple abre un **borrador** (PREPARE_FOR_SUBMISSION) cuando se toca el producto —p. ej. al sumar un
idioma o la nota de revisión— y el texto nuevo va ahí; el aprobado sigue en vivo hasta que la
versión se aprueba. `apply` hace la segunda pasada solo. `status` compara contra el borrador.

### Agregar una unidad de AdMob (navegador)
1. Sumarla a `release.json` → `admob.units` con `id: null` (clave = la de `adUnitIDs` en el código).
2. `admob plan` → la lista de lo que falta. Verificá en la lista del panel que no exista ya.
3. Claude in Chrome: `https://admob.google.com/v2/apps/<appId sin ~>/adunits/list` →
   "Agregar unidad de anuncios" → formato → nombre → (bonificado: recompensa **1 premio**) →
   "Configuración avanzada": todos los tipos, sin límite de frecuencia, eCPM "Optimizada por
   Google" + **Límite mínimo alto** → "Cree una unidad de anuncios".
4. Leer el ID de la pantalla de éxito (`get_page_text`): el de la unidad lleva **`/`**; el que
   lleva `~` es el de la app. `admob set-id <clave> <id>` **inmediatamente** (si se corta, no se
   pierde ni se duplica).
5. `admob sync-code` → `validate` → tests del juego que fijan IDs (`AdUnitIDsTests`,
   `AdsRemoteConfigTests`) → actualizar el `ads.json` publicado en `adergames-site`.

Trampas de la ficha (2026-10-08): crear la ficha de un idioma (`appInfoLocalization`) hace que
Apple cree sola la localización de la versión, vacía → `listing apply` crea las fichas primero y
recalcula. La ficha sólo es editable con una versión nueva abierta (la publicada no se toca).
App Privacy, Mac y Vision Pro no están en la API: navegador, con la sesión del dueño.

Trampas medidas del panel (2026-10-08): la tarjeta de formato a veces no toma el primer click si
la página no terminó de cargar → buscar el "Seleccionar" con `find` y confirmar que se está en el
paso 2 antes de tipear; al elegir un piso aparece un aviso que corre el botón de crear → clickear
por referencia (`find`), nunca por coordenadas; en el campo de nombre el triple click no
selecciona → `cmd+a`.

### Mediación (redes por bidding vía AdMob) — sirve para cualquier juego

Estrategia: AdMob es el mediador y las redes entran **sólo por bidding** (sin waterfall). Cada red
se configura una vez como "fuente del anuncio" y después se suma a un grupo por formato. Los datos
de cada red viven en `release.json → mediation`. Medido el 2026-10-08:

| Red | Estado | Qué pide AdMob | Formatos por bidding |
|---|---|---|---|
| Unity Ads | ✅ activa | Game ID (app) + Placement ID (por unidad) | bonificado, intersticial (no app open, no intersticial bonificado) |
| Meta Audience Network | ⏳ espera el onboarding de Meta | Placement ID por unidad | bonificado, intersticial, intersticial bonificado (no app open) |
| AppLovin | ✗ no acepta publishers nuevos | SDK Key | — |
| Mintegral | ✗ no se pudo crear la cuenta | App Key, App ID, Placement ID, Ad Unit ID | — |

Pasos (Claude in Chrome, con la sesión del dueño en cada panel):
1. **Panel de la red** (lo crea el dueño: cuenta, términos, 2FA, pagos e impuestos son suyos):
   app iOS con el Apple ID de la app; un placement por formato; "Developer website" =
   el dominio del `app-ads.txt`. Anotar los IDs en `release.json → mediation.networks`.
2. **AdMob → Mediación → Fuentes de licitación → Configurar fuente del anuncio** → la red →
   aceptar sus acuerdos (🔒 OK explícito del dueño: son contratos) → mapeo: el ID de app de la red
   y, por cada unidad, una asignación con su placement (nombre `"<Red> <Formato> iOS - <unidad>"`).
3. **Grupos de mediación** (uno por formato y plataforma): Crear → formato + iOS → nombre →
   "Agregar unidades" (tildar la app selecciona todas las de ese formato) → Licitación →
   "Agregar fuente" → la red → elegir la asignación de cada unidad → Guardar. Si la unidad ya
   tiene asignación, AdMob ofrece copiarla (pestaña Licitación del diálogo).
4. **Privacidad y mensajería → Reglamentos europeos → Configuración**: tildar "Agregar
   automáticamente fuentes de anuncios como socios publicitarios" y Guardar.
5. **`app-ads.txt`** del sitio: las líneas que da cada red (Unity: Monetization > Settings >
   App-ads.txt, lista completa; Meta: `facebook.com, <Business ID>, RESELLER, c3e20eee3f780d68`).
   Guardar la lista en `Distribution/release/app-ads.<red>.txt`, publicar y verificar con `curl`.
6. **Código** (relevo/E7): adaptador SPM de la red, sus SKAdNetwork IDs en el Info.plist y
   probar con Ad Inspector en un dispositivo.

Trampas del panel: el combo de asignaciones de un grupo no toma el click por referencia — hay
que clickear la opción por coordenadas (aparece ~110 px debajo del desplegable abierto); el
diálogo "Configurar fuente del anuncio" pagina de a 10 (Unity está en la anteúltima página); la
pestaña Configuración de una fuente marca "cambios sin guardar" aunque no se toque nada.

### Publicar una versión (pipeline)

| # | Etapa | Estado de la automatización |
|---|---|---|
| 1 | Monetización (AdMob) | ✅ `admob plan/set-id/sync-code` + navegador |
| 2 | Compras | ✅ `asc plan/apply/diff/ready/screenshot` |
| 3 | Metadatos y localizaciones de la ficha | ✅ `asc listing` (versión, idiomas, Novedades, notas de revisión); Mac/Vision Pro y App Privacy por navegador |
| 4 | Versión y build | ✅ `version bump` |
| 5 | Compilar y validar | 📋 `xcodegen generate` + `Tools/v2/oraculo.sh rapido` (o `completo`) |
| 6 | Archivo de distribución | 📋 `xcodebuild archive -scheme FisuEvolution -configuration Release -archivePath build/FisuEvolution.xcarchive` |
| 7 | Subida a ASC | 📋 🔒 `xcodebuild -exportArchive -archivePath … -exportOptionsPlist Distribution/ExportOptions.plist -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<KEY>.p8 -authenticationKeyID <KEY> -authenticationKeyIssuerID <ISSUER> -allowProvisioningUpdates` (la misma key; ExportOptions ya dice `destination: upload`) |
| 8 | TestFlight | 🔜 API (`builds`, `betaGroups`) |
| 9 | Preparar la versión | 🔜 API (`appStoreVersions`, asociar build y compras nuevas) |
| 10 | Enviar a revisión | 🔒 sólo con aprobación explícita del dueño |
| 11 | Seguimiento | 🔜 `asc status` + estado de la versión |
| 12 | Post-lanzamiento | 📋 compra sandbox, Ad Inspector, `app-ads.txt`, `ads.json` publicado |

✅ hecho y probado · 📋 comando documentado, se corre a mano · 🔜 diseño, falta implementar · 🔒 pide OK.

Para extender: cada etapa nueva es un módulo en `Tools/releaseops/rocore/` con el mismo contrato
(`snapshot` → `plan` → `apply` que vuelve a leer), un subcomando en `releaseops.py`, sus tests y
su fila en esta tabla.

## Pedido completo, de punta a punta
"Publicá la nueva versión, agregá estas tres compras y estas dos unidades":
1. Editar `release.json` (compras + unidades) → `validate`.
2. `asc plan` + `admob plan` → resumir al dueño, con precios → OK.
3. `asc apply --yes`; crear las unidades en el panel; `admob set-id` + `sync-code`.
4. `validate` + tests del juego → commit.
5. `version bump` → etapas 5–7 (la subida pide OK) → TestFlight → etapa 9 → 🔒 envío.
6. Reporte: qué quedó en qué estado (tabla de estados) y qué falta.
