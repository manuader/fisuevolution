# Checklist de submission — v1.0.0 como **Individual**

_Estado al 2026-09-15. Enrollment `MQ7QN7UL5R`, Apple Developer Program,
modalidad **Individual**. Team ID `2TS7P7VDQJ`._

> **La decisión de fondo**: se publica ahora como Individual y se mueve a
> **ADERGAMES S.A.S.** cuando el trámite de IGJ esté inscripto. El **App
> Transfer** conserva reviews, ranking, ventas y compras de los usuarios, así
> que no se pierde nada por no esperar. Lo que sí cuesta esperar es el tiempo.
>
> Para transferir después hacen falta dos cosas que hoy no existen: la SAS
> inscripta y un **D-U-N-S** a su nombre, más un enrollment **Organization**
> nuevo (el Team ID cambia; hay que tocar `project.yml` y `ExportOptions.plist`
> a la vez).

---

## ✅ Verificado y listo — no requiere acción

Todo esto se comprobó sobre el `.xcarchive` de Release, no sobre el código
fuente, que es la diferencia entre "debería estar" y "está".

| Qué | Cómo se verificó |
|---|---|
| `ARCHIVE SUCCEEDED`, arm64, 6,7 MB | `xcodebuild archive -configuration Release` |
| `ITSAppUsesNonExemptEncryption = false` | `PlistBuddy` sobre el `Info.plist` compilado |
| `GADApplicationIdentifier` = `…~3243441080` | ídem |
| 50 `SKAdNetworkItems` | ídem |
| Nombre por mercado: es → **FisuEvolution**, en → **HoboEvolution** | `InfoPlist.strings` de cada `.lproj` en el `.app` |
| `NSPrivacyTracking = true` | `PrivacyInfo.xcprivacy` embebido |
| `NSUserTrackingUsageDescription` presente | `Info.plist` compilado |
| Ícono 1024 en el catálogo | `assetutil --info Assets.car` |
| Los 5 ad unit IDs **reales** embebidos | `feature_flags.json` dentro del `.app` |
| StoreKitTest **no** linkeado en Release | `otool -L` |
| 12 capturas en 1320×2868 (6.9"), es + en | `sips -g pixelWidth -g pixelHeight` |
| Textos de ficha completos | `Distribution/store-metadata.md` |
| Unit tests | 467/479; los 12 rojos son los dos entornos documentados en `Docs/HANDOFF.md` §6 |

---

## 🔴 Lo que falta

### 1 · El sitio — arrancá por acá, no depende de nada

- [ ] **Cambiar el mail de contacto.** `/privacy` y `/terms` publican
      `support@adergames.io` y el footer `contact@adergames.io`. Verificado
      contra 8.8.8.8, 1.1.1.1 y `whois` el 2026-09-15: **el dominio
      `adergames.io` no está registrado** — sin NS, sin MX, `Domain not found`.
      Todo lo que se mande ahí rebota. Poner `adermanu@gmail.com`, que es lo
      que dicen los documentos del repo.
      *(Alternativa válida: registrar el dominio y darle mail andando. Pero
      entonces hay que cambiar el repo también, y el pin de
      `SettingsPersistenceTests`.)*
- [ ] **Sacar el "TODO"** que el footer muestra literalmente donde va el nombre
      de la empresa.
- [ ] **Pegar la política de privacidad nueva** (`Distribution/site/privacy.md`).
      La publicada todavía habla de los anuncios en condicional y no declara
      ATT — si no coincide con lo que hace la app, es rechazo por 5.1.1.

⚠️ Las rutas son **en minúscula**: `/privacy` y `/terms` responden 200,
`/Privacy` y `/Terms` dan **404**. Copiar de la tabla de
`store-metadata.md`, no de memoria.

### 2 · Crear el app record en App Store Connect

- [ ] Bundle ID `com.manuader.fisuevolution`.
- [ ] **Idioma primario: English (U.S.)**, nombre **HoboEvolution**.
- [ ] Agregar locale **es-MX** con nombre **FisuEvolution**.

⚠️ **El idioma primario no se cambia después.** El porqué de que sea inglés y
no castellano está en `store-metadata.md`, sección "Nombre".

⚠️ **Primer gate que puede frenar todo**: que **HoboEvolution** esté libre. Si
está tomado hay que elegir alternativa antes de seguir, porque el nombre viaja
también en el binario (`InfoPlist.xcstrings`).

### 3 · Cargar los 11 IAP

- [ ] Los once, con los ids y **tipos** exactos.

La tabla —ids, tipo, precio, reference name y nombres es/en— está en
`Docs/HANDOFF-gates-pendientes.md` § RF-02c. La fuente de verdad es
`StoreKitConfig/FisuEvolution.storekit`, que es lo que pinean
`StoreProductsTests` en los dos sentidos.

⚠️ **El tipo importa**: marcar un pack de plata como no consumible lo deja
comprable una sola vez. Y `Product.products(for:)` **omite en silencio**
cualquier id que no resuelva — un tipeo no da error, da una tienda con una fila
menos.

⚠️ Van **todos en la primera submission**, junto con la build.

### 4 · Archive → Distribute

- [ ] En Xcode: **Product → Archive**.
- [ ] En el Organizer: **Distribute App → App Store Connect**.

Esto es lo que crea el certificado de **Apple Distribution**, que hoy no existe
en el llavero (sólo hay uno de *Apple Development*). Por eso este paso va por
Xcode y no por CLI: necesita la sesión de tu Apple ID para emitirlo.

`Distribution/ExportOptions.plist` ya tiene el `teamID` real por si después se
automatiza por línea de comandos.

### 5 · Los formularios de App Store Connect

- [ ] **Nutrition labels** — hay que declarar **"Data Used to Track You"**
      (identificador de publicidad) por AdMob, más datos de uso/diagnóstico
      vinculados a publicidad de terceros. Tiene que coincidir con
      `PrivacyInfo.xcprivacy` (`NSPrivacyTracking = true`) y con la política.
      Declarar de menos acá es rechazo; declarar de más también es declarar mal.
- [ ] **Rating 12+**, con las referencias a alcohol declaradas (son íconos
      caricaturescos de boosts, y el build de tienda sirve sólo contenido
      review-safe).
- [ ] Categoría y precio (gratis).
- [ ] Pegar capturas, textos y **Review Notes** desde `store-metadata.md`.

Las Review Notes explican el punto que más fácil se lee como IAP engañoso:
**`Remove Ads` saca los interstitials pero no los rewarded**. No las resumas.

### 6 · TestFlight, antes de mandar a review

- [ ] Abrir una oferta de video en Regalos y confirmar que **carga un anuncio
      real**.

Es el único lugar donde se puede verificar: en Debug la app fuerza los ad unit
IDs de prueba de Google a propósito (ver `FeatureFlags.effectiveAdUnitIDs` —
pedir anuncios reales desde un build de desarrollo es click fraud contra tu
propia cuenta y Google suspende por eso).

⚠️ **Riesgo abierto**, y es el único del checklist. En el archive, los
frameworks de AdMob aparecen como stubs de 51 KB (el xcframework real pesa
12 MB) y el binario principal **no tiene ninguna entrada `@rpath`**. La
evidencia dice que el código igual está adentro —1258 strings internos del SDK
en el binario principal contra 8028 del xcframework completo, y cero en los
stubs—, o sea mergeado con dead-stripping. Lo que no cierra es que
`MERGED_BINARY_TYPE = none` en los build settings, así que no hay explicación
limpia de por qué Xcode lo mergeó.

Si en TestFlight no aparece ningún anuncio, empezar por acá y no por la cuenta
de AdMob.

### 7 · Submit

- [ ] Mandar a review con los 11 IAP adjuntos a la versión.

---

## Después, cuando la SAS esté inscripta

- [ ] Sacar **D-U-N-S** a nombre de ADERGAMES S.A.S.
- [ ] Enrollment **Organization** nuevo (Team ID distinto).
- [ ] **App Transfer** desde la cuenta Individual.
- [ ] Actualizar `DEVELOPMENT_TEAM` en `project.yml` y `teamID` en
      `Distribution/ExportOptions.plist` **a la vez**.

⚠️ El Team ID `2TS7P7VDQJ` es el mismo que ya estaba como equipo personal:
Apple **conserva** el Team ID al enrolarse como individuo. Recién con el
Organization aparece uno nuevo.
