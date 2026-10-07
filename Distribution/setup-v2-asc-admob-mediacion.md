# Setup de la 2.0 — App Store Connect, AdMob y mediación

_Entregable del ítem 18 (PLAN-v2, E10). Escrito el 2026-10-06. Cada dato de un
panel ajeno trae la URL de la documentación oficial de donde salió, leída ese
día. Las 4 redes cambian sus paneles seguido: si algo no coincide, manda el
panel, y se corrige este doc._

**🔒 = lo hace o lo verifica el dueño en un panel.** Todo lo demás ya está
resuelto en el repo o lo resuelve una épica de código (se dice cuál).

Este doc es también el insumo del script de Selenium que algún día lo
automatice (sección 5). Por eso cada paso dice **dónde** se hace y **qué
valor** va, no sólo qué hay que lograr.

Qué manda si hay conflicto:

- **Los IDs de producto y los textos de los IAP**: `Distribution/iap-appstore-connect.md`.
- **Los nombres de las claves de anuncios** (`rewardedWheel`, `appOpen`…): el
  código de E7a. Acá se usan los del plan; si E7a los cambia, gana el código.
- **Las decisiones** (precios, cadencias, qué saca `remove_ads`): PLAN-v2 §2.
  No se re-litigan.

## Orden recomendado

Hay pasos que tardan días en aprobarse, así que van primero:

1. 🔒 **Abrir las cuentas de las 4 redes** (sección 3). Meta pide una cuenta
   de pagos antes de dejar crear placements, y cualquiera de las cuatro puede
   tardar en aprobar una cuenta nueva.
2. 🔒 **Crear las unidades nuevas de AdMob** (2.1) y pasarle los IDs a E7a
   para `feature_flags.json` y el `ads.json` remoto.
3. 🔒 **Mapear cada red en AdMob y armar los 4 grupos de mediación** (2.3).
4. 🔒 **Publicar el `app-ads.txt` con las líneas de las 4 redes** (4.1): sin
   eso, sus compradores no pujan.
5. 🔒 **Cargar y localizar los 14 productos** en App Store Connect (1.4 y 1.5).
6. Build 2.0 → TestFlight → **Ad Inspector** con cada red (2.6).
7. 🔒 Formularios de App Store Connect: edad (1.6), privacidad (1.7), notas a
   App Review (1.8), disponibilidad (1.9). Mandar a revisión **con los IAP
   adjuntos**.
8. 🔒 El día que sale la 2.0: publicar la política nueva en el sitio (4.2).
   Los Términos corregidos (4.3) no esperan: valen también para la v1.

---

## 1. App Store Connect

### 1.1 La versión 2.0.0 — Novedades

🔒 Crear la versión **2.0.0** y pegar estos textos en *What's New*.

⚠️ Antes de pegar, confirmar en TestFlight que todo lo que se nombra entró.
Si una pieza quedó afuera (por ejemplo, las familias de skins, que dependen
de un gate), se saca la línea. Los nombres en inglés de las piezas nuevas son
provisorios hasta que E4/E5 los fijen en `Localizable.xcstrings`: se copian
de ahí.

**Español (es-MX y es-ES):**

```
¡Llegó la 2.0! La reforma más grande desde que el Fisura salió del callejón.

• Visitantes: el Comisario, el Sindicalista, el Turista Gringo y compañía pasan por tu empresa con pedidos, trueques y sorpresas.
• Eventos nuevos, como ¡Salimos campeones!, el Feriado Puente, el Paro General o el Apagón, con su escape por video.
• El Paquete de la Aduana, El Colchón y la Ruleta del Conductor de TV.
• Tienda de ORO: boosts, atajos, mejoras permanentes y pintas nuevas.
• 15 lugares por piso, la botonera del ascensor y pisos en marcha que suben tus ingresos.
• El atajo de contratar ya no desaparece, y manteniéndolo presionado elegís a quién fijar.
• Un tema musical para cada piso.
• Ahora también en iPad.
• Tutorial nuevo y un recorrido por las novedades para los que vienen de la 1.0.
• Arreglos: las ganancias en segundo plano ya no se congelan, y ninguna evolución pasa sin que la veas.
```

**English (en-US):**

```
Version 2.0 is here: the biggest overhaul since the Hobo left the alley.

• Visitors: the Police Chief, the Union Boss, the Gringo Tourist and friends drop by with requests, trades and surprises.
• New events like We Won the Cup!, Long Weekend, General Strike and Blackout, each with a way out by video.
• Customs Parcels, the Mattress Stash and the TV Host's Prize Wheel.
• ORO Shop: boosts, shortcuts, permanent upgrades and new outfits.
• 15 spots per floor, an elevator panel, and fully staffed floors that boost your income.
• The quick-hire button never disappears, and pressing and holding it lets you pin who you hire.
• A music theme for every floor.
• Now on iPad too.
• A brand-new tutorial, plus a tour of what's new for 1.0 veterans.
• Fixes: background earnings no longer freeze, and no evolution happens without you seeing it.
```

### 1.2 La ficha: en-US, es-MX y **es-ES**

La ficha de la v1 tiene dos idiomas: **English (U.S.)**, el primario, y
**Spanish (Mexico)**. El porqué del primario está en
`Distribution/store-metadata.md`. La 2.0 suma uno:

- 🔒 **Agregar el idioma Spanish (Spain)** con el mismo texto que es-MX:
  nombre **FisuEvolution**, subtítulo, keywords y descripción. Sin él, un
  iPhone en España ve la ficha en inglés.

Cambios en la descripción, en los tres idiomas:

- ⚠️ **Sacar "Se cayó Mercado Pago"** de la lista de eventos (es). Mercado
  Pago es una marca real (guía 5.2.1), y en la 2.0 el evento se llama **"Se
  cayó el home banking"**. La línea queda así: *"• Eventos argentinos: Plan
  Platita, Devaluación, Se cayó el home banking, Corralito, Paro General y el
  Aguinaldo"*.
- Sumar una viñeta: *"• Visitantes con pedidos, la Ruleta, El Colchón y el
  Paquete de la Aduana"* / *"• Visitors with requests, a prize wheel, the
  Mattress Stash and Customs Parcels"*.
- Sumar *"• Ahora también en iPad"* / *"• Now on iPad too"*.

El resto de `store-metadata.md` (subtítulo, keywords, URLs) sigue igual. Sus
**Review Notes son las de la v1**: las de la 2.0 están en 1.8.

### 1.3 Capturas: iPhone y iPad 13"

La app pasa a ser universal, así que **las capturas de iPad son obligatorias**.
Según la especificación vigente
([screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)):

| Slot de App Store Connect | Tamaño vertical | Obligatorio |
|---|---|---|
| iPad 13-inch | 2064 × 2752 | **Sí**, si la app corre en iPad |
| iPhone with Dynamic Island (large display), el de los Pro Max | 1320 × 2868 (también 1290 × 2796 o 1260 × 2736) | No; es el que ya tiene la ficha de la v1 |
| iPhone with Dynamic Island (medium display) | 1206 × 2622 o 1179 × 2556 | **Sí**, según la página: "at least one screenshot" |

- Hasta 10 capturas por tamaño y por idioma.
- 🔒 Las 12 de la v1 (1320 × 2868, es y en) **muestran la UI vieja**: 10
  lugares, la barra de abajo vieja y el banner de eventos, que la 2.0 elimina.
  Hay que sacarlas de nuevo con `AppStoreScreenshotTests` (E3 lo extiende al
  iPad Pro 13").
- ⚠️ La página de Apple marca como obligatorio el slot *medium display*. La
  v1 se publicó sólo con 6,9", así que puede que App Store Connect escale.
  🔒 Si al cargar la versión el slot *medium* aparece en rojo, se generan
  también en 1206 × 2622 (simulador del iPhone 17 Pro).
- La captura 6 del guion de `store-metadata.md` era el banner "Se cayó
  Mercado Pago", que ya no existe. La reemplaza un **visitante con su globo**:
  "Recibí visitas (y pedidos)" / "Visitors drop by (with requests)".

### 1.4 Los productos (IAP)

La fuente de verdad es **`Distribution/iap-appstore-connect.md`**: IDs,
tipos, precios y las fichas para copiar y pegar. Acá va lo que ese archivo no
tiene: el estado de cada uno, el conteo de caracteres por idioma y las notas
de revisión por producto.

Límites del formulario
([In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)):
nombre (*Display Name*) de 2 a 30 caracteres, descripción ≤ 45, por idioma.
*Reference Name* ≤ 64 y notas de revisión ≤ 4000. El *Product ID* no se puede
editar después de guardarlo ni reusar aunque se borre el producto.

| Product ID (`com.fisuevolution.iap.`…) | Tipo | USD | Qué hay que hacer | Notas de revisión del producto |
|---|---|---:|---|---|
| `coins_small` | Consumible | 0.99 | Sumar es-ES | — |
| `coins_medium` | Consumible | 4.99 | Sumar es-ES | — |
| `coins_large` | Consumible | 9.99 | Sumar es-ES | — |
| `oro_small` | Consumible | 1.99 | Descripción nueva + es-ES | "Gives 160 ORO." |
| `oro_medium` | Consumible | 4.99 | **Nombre** y descripción nuevos + es-ES | "Gives 550 ORO." |
| `oro_large` | Consumible | 9.99 | es-ES (la descripción no cambia) | "Gives 1,400 ORO." |
| `remove_ads` | No consumible | 2.99 | Descripción nueva + es-ES | "Removes the interstitial, the ad break and the app open ad. Opt-in rewarded videos stay." |
| `skin_mundialista` | No consumible | 2.99 | Sumar es-ES | — |
| `skin_parrillero` | No consumible | 2.99 | Sumar es-ES | — |
| `skins_diamante` | No consumible | 19.99 | Sumar es-ES | — |
| `starter_pack` | No consumible | 4.99 | Descripción nueva + es-ES | "Gives 4 hours of production, the Mundialista skin and the same as Remove Ads." |
| `offer_bienvenida` | Consumible | 0.99 | **Crear** | "Offered once for 24 hours on the player's 2nd calendar day. Contains a skin chest; its odds are shown before purchase. See the app review notes." |
| `offer_renacer` | Consumible | 2.99 | **Crear** | "Offered for 24 hours right after reincarnating. See the app review notes." |
| `offer_mudanza` | Consumible | 4.99 | **Crear** | "Offered for 24 hours when a new floor opens. See the app review notes." |

Las fichas con su conteo. Se contaron con `len()` de Python sobre el archivo
de IAP: todos los caracteres son del plano básico de Unicode (incluidos `ñ`,
`ó` y `×`), así que la cuenta coincide con la de App Store Connect.

| Producto | Locale | Nombre | Car. | Descripción | Car. |
|---|---|---|---:|---|---:|
| `starter_pack` | es-MX | Pack de Arranque | 16 | Plata, la Mundialista y sin anuncios forzados | 45 |
| `starter_pack` | es-ES | Pack de Arranque | 16 | Plata, la Mundialista y sin anuncios forzados | 45 |
| `starter_pack` | en-US | Starter Pack | 12 | Cash, the Mundialista skin and no forced ads | 44 |
| `remove_ads` | es-MX | Sin anuncios | 12 | Chau a los anuncios que aparecen solos | 38 |
| `remove_ads` | es-ES | Sin anuncios | 12 | Chau a los anuncios que aparecen solos | 38 |
| `remove_ads` | en-US | Remove Ads | 10 | No more ads that pop up on their own | 36 |
| `coins_small` | es-MX | Puñado de Plata | 15 | Un vuelto para arrancar el día | 30 |
| `coins_small` | es-ES | Puñado de Plata | 15 | Un vuelto para arrancar el día | 30 |
| `coins_small` | en-US | Handful of Cash | 15 | Pocket change to get the day going | 34 |
| `coins_medium` | es-MX | Fajo de Plata | 13 | Un fajo que se nota en el bolsillo | 34 |
| `coins_medium` | es-ES | Fajo de Plata | 13 | Un fajo que se nota en el bolsillo | 34 |
| `coins_medium` | en-US | Wad of Cash | 11 | A wad you can feel in your pocket | 33 |
| `coins_large` | es-MX | Bolso de Plata | 14 | El bolso entero, sin preguntar de dónde salió | 45 |
| `coins_large` | es-ES | Bolso de Plata | 14 | El bolso entero, sin preguntar de dónde salió | 45 |
| `coins_large` | en-US | Bag of Cash | 11 | The whole duffel bag, no questions asked | 40 |
| `oro_small` | es-MX | Puñado de ORO | 13 | Para un boost o esa mejora que venís mirando | 44 |
| `oro_small` | es-ES | Puñado de ORO | 13 | Para un boost o esa mejora que venís mirando | 44 |
| `oro_small` | en-US | Handful of ORO | 14 | For a boost or that upgrade you keep eyeing | 43 |
| `oro_medium` | es-MX | Saco de ORO | 11 | Boosts, mejoras y skins, y todavía te sobra | 43 |
| `oro_medium` | es-ES | Saco de ORO | 11 | Boosts, mejoras y skins, y todavía te sobra | 43 |
| `oro_medium` | en-US | Sack of ORO | 11 | Boosts, upgrades and skins, with change left | 44 |
| `oro_large` | es-MX | Bóveda de ORO | 13 | Para el que quiere todo, y lo quiere ahora | 42 |
| `oro_large` | es-ES | Bóveda de ORO | 13 | Para el que quiere todo, y lo quiere ahora | 42 |
| `oro_large` | en-US | Vault of ORO | 12 | For those who want it all, and want it now | 42 |
| `skin_mundialista` | es-MX | Skin Mundialista | 16 | La camiseta y una copa que no ganó él | 37 |
| `skin_mundialista` | es-ES | Skin Mundialista | 16 | La camiseta y una copa que no ganó él | 37 |
| `skin_mundialista` | en-US | Mundialista Skin | 16 | The jersey, and a cup he didn't win | 35 |
| `skin_parrillero` | es-MX | Skin Parrillero | 15 | Dios con delantal chamuscado y pinza de asado | 45 |
| `skin_parrillero` | es-ES | Skin Parrillero | 15 | Dios con delantal chamuscado y pinza de asado | 45 |
| `skin_parrillero` | en-US | Parrillero Skin | 15 | God in a scorched apron, tongs in hand | 38 |
| `skins_diamante` | es-MX | Todas las skins de Diamante | 27 | Los 43 personajes tallados en diamante | 38 |
| `skins_diamante` | es-ES | Todas las skins de Diamante | 27 | Los 43 personajes tallados en diamante | 38 |
| `skins_diamante` | en-US | All Diamond Skins | 17 | All 43 characters carved in diamond, at once | 44 |
| `offer_bienvenida` | es-MX | Pack de Bienvenida | 18 | ORO, 2 h de ingresos y un cofre de pintas | 41 |
| `offer_bienvenida` | es-ES | Pack de Bienvenida | 18 | ORO, 2 h de ingresos y un cofre de pintas | 41 |
| `offer_bienvenida` | en-US | Welcome Pack | 12 | ORO, 2 h of income and a skin chest | 35 |
| `offer_renacer` | es-MX | Pack Renacer | 12 | ORO, 4 h de ingresos y ×3 por 30 minutos | 40 |
| `offer_renacer` | es-ES | Pack Renacer | 12 | ORO, 4 h de ingresos y ×3 por 30 minutos | 40 |
| `offer_renacer` | en-US | Rebirth Pack | 12 | ORO, 4 h of income and ×3 for 30 minutes | 40 |
| `offer_mudanza` | es-MX | Pack Mudanza | 12 | ORO, 8 h de ingresos y 3 Paquetes | 33 |
| `offer_mudanza` | es-ES | Pack Mudanza | 12 | ORO, 8 h de ingresos y 3 Paquetes | 33 |
| `offer_mudanza` | en-US | Moving Day Pack | 15 | ORO, 8 h of income and 3 Parcels | 32 |

Para cada producto:

- 🔒 **Precio**: el *price point* de USD de la tabla, con Estados Unidos como
  país base. App Store Connect calcula el resto de las tiendas.
- 🔒 **Captura de revisión**: la de la pantalla Tienda para los 11 de siempre;
  la de la hoja de cada oferta para las 3 nuevas. Sirve cualquier tamaño de
  captura que la app soporte (misma página de Apple). La imagen promocional
  de 1024 × 1024 es otra cosa y no hace falta.
- 🔒 **"Ready to Submit"**: los productos nuevos o editados se seleccionan en
  la página de la versión 2.0.0, sección *In-App Purchases and
  Subscriptions*, antes de mandar. Si no, no salen.

### 1.5 Checklist del ítem 19: los IAP salen en inglés

**Causa** (PLAN-v2 §3): el nombre del producto sale de App Store Connect, y el
idioma primario de la app es inglés. Sin una localización española
**aprobada** —o con el iPhone en español de España y sólo es-MX cargado— el
jugador ve el inglés. Desde la 2.0 la app muestra los nombres de su propio
catálogo (`IAPCopy`, E3) y ya no depende de esto, pero **la hoja de pago de
Apple sí**: sigue mostrando el nombre de App Store Connect.

- [ ] 🔒 En **cada uno de los 11 productos existentes**, abrir *App Store
      Localization* y verificar que **Spanish (Mexico)** existe y tiene el
      nombre y la descripción de `Distribution/iap-appstore-connect.md`.
- [ ] 🔒 En los mismos 11, **agregar Spanish (Spain)** con el mismo texto.
- [ ] 🔒 Revisar **English (U.S.)** contra el archivo (cambian `oro_small`,
      `oro_medium`, `remove_ads` y `starter_pack`).
- [ ] 🔒 Crear las 3 ofertas con sus 3 idiomas desde el principio.
- [ ] 🔒 Confirmar que **ninguna localización quedó en "Rejected" o
      "Developer Action Needed"**: una localización sin aprobar es como no
      tenerla.
- [ ] 🔒 Mandar todo **junto con el build 2.0.0** (último paso de 1.4).
- [ ] 🔒 Al aprobarse: en un iPhone en **es-ES** y en otro en **es-MX** (o
      cambiando el idioma), abrir la Tienda y tocar comprar hasta la hoja de
      Apple (sin confirmar): el nombre tiene que salir en castellano.

### 1.6 Cuestionario de edad

Las preguntas y sus definiciones están en
[Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions).
Lo nuevo de la 2.0 es la sección de **actividades de azar**:

| Pregunta | Respuesta | Por qué |
|---|---|---|
| **Loot Boxes** ("virtual containers that provide players with randomized virtual items for purchase") | **Sí** | La ruleta con giro extra pagado con ORO, el cofre de pintas por ORO y el cofre dentro del Pack de Bienvenida. El ORO se compra con plata real |
| **Simulated Gambling** ("betting or wagering without using real money…") | **No** | No hay ninguna mecánica de apostar: nunca se arriesga algo para ganar más de lo mismo. El Crypto Bro no apuesta (PLAN-v2 §6) |
| **Gambling** (con plata real o moneda canjeable) | **No** | El ORO no se canjea por nada fuera del juego (Términos §3) |
| **Contests** | **No** | Game Center sigue apagado: no hay rankings |
| **Advertising** (capacidades) | **Sí** | AdMob y mediación |
| Parental Controls / Age Assurance | No | No los hay |
| Alcohol, tabaco y drogas | Igual que la v1: **infrecuente/leve** | Los íconos caricaturescos de los boosts |
| El resto (violencia, terror, contenido sexual, lenguaje) | Igual que la v1 | El contenido nuevo (visitantes, eventos) es sátira sin violencia |

- 🔒 Con estas respuestas, Apple calcula la edad. La escala vigente ya no
  tiene 12+: son 4+, 9+, 13+, 16+ y 18+ (misma página). Anotar lo que dé y
  corregir el "12+" de `store-metadata.md` y de la política.
- ⚠️ En Australia, el azar pagado sube la clasificación local. Los giros
  extra y los cofres por ORO **se apagan en Bélgica y Australia** por la
  config remota (`restrictedStorefronts`, decisión del dueño), pero el
  cuestionario se responde por lo que el binario **puede** hacer: igual es
  **Sí**.
- La regla de Apple que obliga a mostrar las probabilidades **antes** de
  comprar es la 3.1.1
  ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)):
  *"Apps offering 'loot boxes' or other mechanisms that provide randomized
  virtual items for purchase must disclose the odds of receiving each type of
  item to customers prior to purchase."* La cumple `OddsDisclosureView` (E6).

### 1.7 App Privacy

La app en sí no recolecta nada: `PrivacyInfo.xcprivacy` declara
`NSPrivacyCollectedDataTypes = []` y `NSPrivacyTracking = false` (HANDOFF-v2
explica por qué `true` sin dominios hizo rechazar el build: ITMS-91064). Lo
que hay que declarar es **lo que juntan los SDK de anuncios**.

**Lo que declara Google** para el SDK de AdMob
([data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)):

| Tipo de dato en App Store Connect | Qué es |
|---|---|
| Location → Coarse Location | La IP, que puede usarse para estimar la ubicación general |
| Identifiers → Device ID | El identificador de publicidad (IDFA) u otros identificadores del dispositivo |
| Usage Data → Advertising Data | Los anuncios que vio el usuario |
| Usage Data → Product Interaction | Toques al abrir la app, vistas de video |
| Diagnostics → Crash Data / Performance Data | Crashes del SDK y rendimiento (tiempo de arranque, cuelgues) |

Propósitos que declara Google: publicidad de terceros, analytics y
desarrollo del producto. La misma página pide que, **con mediación**, cada
adaptador y SDK traiga su propio manifiesto de privacidad.

Cómo armar la declaración de la 2.0:

1. 🔒 Archive del build 2.0 → **Organizer → clic derecho en el archive →
   Generate Privacy Report**. Xcode junta los `PrivacyInfo.xcprivacy` de
   todos los SDK en un PDF con el formato de las etiquetas
   ([WWDC23, Get started with privacy manifests](https://developer.apple.com/videos/play/wwdc2023/10060/)).
2. ⚠️ Revisar que el PDF **traiga los SDK de las 4 redes**. Hay reportes de
   que sólo incluye los frameworks embebidos
   ([foro de Apple](https://developer.apple.com/forums/thread/734971)), y este
   proyecto ya tuvo los frameworks de AdMob como stubs en el archive
   (`checklist-submission.md`, punto 6). Si falta alguno, abrir el
   `PrivacyInfo.xcprivacy` del paquete SPM de esa red.
3. 🔒 Declarar en App Store Connect **la unión** de lo que dicen Google y las
   4 redes. Como punto de partida, la v1 declaró **"Data Used to Track You"**
   (identificador de publicidad) más datos de uso y diagnóstico de
   publicidad de terceros (`checklist-submission.md`, punto 5).
4. Tiene que coincidir con la política del sitio (4.2). Declarar de menos es
   rechazo, y declarar de más también es declarar mal.

### 1.8 Notas a App Review

🔒 Van en **App Review Information → Notes** (máximo 4000 caracteres). Este
texto tiene 3.459 caracteres, todos ASCII. Cubre lo que las notas de
la v1 no decían: el intersticial al **cerrar menús** (bug 12 del plan) y el
**app open**.

⚠️ Antes de pegar, confirmarlo contra el build de TestFlight: si E7 cambió una
cadencia o E6 cambió dónde se ven las ofertas, se corrige acá primero.

```
HoboEvolution 2.0 - notes for the reviewer

Satirical single-player merge/idle game with Argentine humor. Brands are parodies and characters are archetypes, not real people. No accounts, no login and no server of ours: progress is stored on device. Game Center and iCloud are disabled.

HOW TO TEST
Tap the character to earn coins, tap Hire to buy another one, and drag one onto another to merge them. The tutorial cannot be skipped; it ends with a welcome chest. Everything else unlocks as you play. The Store tab has every IAP and Restore Purchases.

ADS (Google AdMob, with AppLovin, Unity Ads, Mintegral and Meta Audience Network as mediation partners)
1. Opt-in rewarded videos. Always started by an explicit tap on a button that says what you get; they never autoplay. Places: the Gifts list (Bonus tab), doubling offline earnings, opening another skin chest, starting a boost without waiting and "Merge all", the prize wheel (spin and "repeat prize"), the Mattress Stash ("another mattress"), parcel rain, visitor rewards x2, forgiving a fine, the street vendor's boosts, escaping a negative event, and daily or career rewards x2.
2. Ads that appear on their own, only at natural breaks: at least 2 minutes apart, never during the tutorial, never over an open screen or a celebration, and never two in the same break.
- Interstitial and "ad break" (rewarded interstitial) alternate. Breaks: closing a menu screen and returning to the board, dismissing the offline-earnings popup, reincarnating, and the end of a chain of celebrations. The ad break always shows an intro screen with a 5-second countdown and a visible "No, thanks" button; declining has no penalty.
- App open: only when returning to the app after 3+ minutes away, at most once every 20 minutes, from the second session on, never on first launch or during the tutorial.
"Remove Ads" (US$2.99) and the Starter Pack remove these three formats (interstitial, ad break and app open). Opt-in rewarded videos stay, because they are optional and pay out prizes; the purchase description says so.
ATT is requested on first launch; declining is fully supported. In the EEA, UK and Switzerland, Google's UMP consent form is shown before any ad, and Settings > Privacy options lets the player change it.

RANDOMIZED ITEMS (Guideline 3.1.1)
The prize wheel, the skin chest bought with ORO, the Mattress Stash and the skin chest inside the Welcome Pack give randomized items. The odds of every prize are shown on screen before spinning, buying or opening. ORO, the premium currency, can be bought with real money; it has no real-world value and cannot be cashed out or transferred. There is no real-money gambling and no betting. Extra wheel spins and chests bought with ORO are turned off in Belgium and Australia.

24-HOUR OFFERS (consumable IAPs)
- Welcome Pack (US$0.99): offered once, on the player's 2nd calendar day. To see it: play once, set the device date one day ahead and reopen the app.
- Rebirth Pack (US$2.99): offered right after reincarnating.
- Moving Day Pack (US$4.99): offered when a new floor opens outside the tutorial; the early floors open within the first minutes of play.
Each one stays available for 24 hours behind a chip at the top of the board, and never shows during the tutorial.

IAPs (14): starter pack, remove ads, three cash packs, three ORO packs, three skin purchases and the three offers above. Consumables are not restored by design; remove ads and skins are.
```

### 1.9 Disponibilidad en Mac y en Apple Vision Pro

Por defecto, una app de iPhone y iPad **se publica sola** en las Mac con Apple
silicon ("Designed for iPad") y en Apple Vision Pro. Nada de eso se probó, así
que se apaga:

- 🔒 **Pricing and Availability → iPhone and iPad Apps on Apple Silicon Mac**:
  destildar *Make this app available*
  ([Apple](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon/)).
- 🔒 **Pricing and Availability → Apple Vision Pro**: destildar *Make this app
  available on Apple Vision Pro*
  ([Apple](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)).

Se prende cuando alguien lo pruebe, no antes.

---

## 2. AdMob

App **HoboEvolution (iOS)**, App ID `ca-app-pub-8575641544774372~3243441080`.
Es el `GADApplicationIdentifier` del `Info.plist` y no cambia. Lo básico de la
consola (UMP, IDFA, pisos, qué mirar) ya está en
`Docs/monetizacion-anuncios.md`; acá va lo de la 2.0.

### 2.1 Las unidades

Cada unidad es un **momento** del juego, no un premio: AdMob reporta por
unidad, y lo que conviene comparar es "¿rinde más el video de la ruleta o el
del colchón?". Las 5 que usa la v1 **no se borran**: la v1 sigue instalada en
teléfonos que no actualizan.

| Unidad en AdMob | Formato | ID | Clave en `adUnitIDs` | Dónde aparece en la 2.0 |
|---|---|---|---|---|
| anuncio normal | Intersticial | `…/5270838626` | `interstitial` | Corte natural, alternado con la pausa publicitaria |
| unidad → 🔒 renombrar **pausa publicitaria** | Intersticial bonificado | `…/1615619906` | `rewardedInterstitial` | Pausa publicitaria (con pantalla previa y "No, gracias") |
| x2 de income → 🔒 renombrar **regalos** | Bonificado | `…/8304196070` | `rewardedGifts` | Los 5 premios de Regalos. Es la unidad de respaldo de todas |
| offline x2 | Bonificado | `…/6825744243` | `rewardedOfflineX2` | Duplicar lo ganado offline |
| cofre extra | Bonificado | `…/3981807683` | `rewardedChestExtra` | Abrir otro cofre |
| boosts | Bonificado | `…/4913896772` | `rewardedBoost` | Boost sin esperar y **Fusionar todo** |
| 🔒 **ruleta** (nueva) | Bonificado | a crear | `rewardedWheel` | Giro de la ruleta y "repetir premio" |
| 🔒 **colchón** (nueva) | Bonificado | a crear | `rewardedTreasure` | El Colchón, "otro colchón" y lluvia de paquetes |
| 🔒 **visitantes** (nueva) | Bonificado | a crear | `rewardedVisitor` | Visitante ×2, multa perdonada, boosts del Vendedor, ×2 del reto y escapes de eventos |
| 🔒 **diario** (nueva) | Bonificado | a crear | `rewardedDaily` | Diario ×2 y carrera ×2 |
| 🔒 **app open** (nueva) | Inicio de aplicación (*App open*) | a crear | `appOpen` | Al volver a la app (≥3 min afuera, 1 cada 20 min) |

Todos los IDs llevan delante `ca-app-pub-8575641544774372/`. ⚠️ Las unidades
llevan **`/`** y el App ID **`~`**: confundirlos falla recién en runtime.

🔒 Al crear cada bonificada, AdMob pide la recompensa (cantidad e ítem). Poné
**1** y **premio**: el juego no lee ese valor, decide el premio él solo.

🔒 Cuando estén creadas, los 5 IDs nuevos van a `feature_flags.json`
(`adUnitIDs`) y al `ads.json` del sitio (4.4). Las claves nuevas son
opcionales y caen a `rewardedGifts` si faltan, así que un build sin ellas
funciona, pero pierde el reporte por momento.

### 2.2 Ajustes de cada unidad

En **Apps → HoboEvolution → Unidades de anuncios → (unidad) → Configuración
avanzada**:

- 🔒 **Tipos de anuncio**: dejar habilitados todos los que ofrezca el formato
  (imagen y video). Cuantos más acepta, más anunciantes compiten.
- 🔒 **Piso de eCPM → Optimizado por Google**, en *Alto* si aparece. Es lo
  mismo que `monetizacion-anuncios.md` pide para las 5 de la v1, ahora en las
  nuevas.
- 🔒 **Sin límite de frecuencia**: la cadencia la controla el juego (y ahora
  también la config remota). Un límite en AdMob sólo resta impresiones.

### 2.3 Los grupos de mediación

Uno por formato, plataforma **iOS**
([Create a mediation group](https://support.google.com/admob/answer/13412127)):
**Mediación → Crear grupo de mediación → formato → iOS → Agregar unidades**,
y en la tabla **Bidding → Agregar fuente de anuncios** se suma cada red con su
mapeo (sección 3). AdMob sigue participando de la subasta.

No todas las redes soportan todos los formatos por bidding. Según la guía de
Google de cada una (sección 3):

| Grupo | Unidades | AppLovin | Unity Ads | Mintegral | Meta |
|---|---|:---:|:---:|:---:|:---:|
| **Bonificados iOS** | las 8 bonificadas | ✅ | ✅ | ✅ | ✅ |
| **Intersticial iOS** | anuncio normal | ✅ | ✅ | ✅ | ✅ |
| **Intersticial bonificado iOS** | pausa publicitaria | ✅ | ❌ | ✅ | ✅ |
| **App open iOS** | app open | ✅ | ❌ | ✅ | ❌ |

Donde una red no está, ese formato lo sirve AdMob con las que sí (PLAN-v2 E7:
"si una red no soporta app open o la pausa publicitaria, ese formato queda
sólo en AdMob").

### 2.4 Privacidad y mensajes

- UMP (GDPR) y el mensaje de IDFA: los pasos están en
  `Docs/monetizacion-anuncios.md`, Parte 1, pasos 2 y 3. Si ya se hicieron
  para la v1, sirven.
- 🔒 **Sumar las 4 redes a la lista de socios publicitarios** del mensaje de
  GDPR ([European regulations settings](https://support.google.com/admob/answer/10113004))
  **y** de los estados de EE. UU.
  ([US state regulations settings](https://support.google.com/admob/answer/14125907)).
  Pide el permiso *Account Management*. Los nombres que usa cada guía de
  Google: **AppLovin Corp.**, **Unity Ads**, **Mobvista/Mintegral** y
  **Meta**. Una red que no está en la lista no recibe el consentimiento del
  jugador europeo, aunque lo haya dado.
- Meta no está en la lista de proveedores de IAB Europe (GVL): su
  consentimiento viaja por la especificación *Additional Consent*, no por TCF
  ([guía de Meta en AdMob](https://developers.google.com/admob/ios/mediation/meta)).
  Por eso es la que más depende de estar en la lista de socios del mensaje.

### 2.5 Bloqueo de categorías

**Apps → HoboEvolution → Controles de bloqueo → Contenido → Categorías
sensibles**
([Block ads](https://support.google.com/admob/answer/3150235),
[categorías sensibles](https://support.google.com/admob/answer/3150953)):

- **Gambling & Betting (18+)** es una categoría *restringida*: viene
  **bloqueada por defecto**. 🔒 Verificar que siga bloqueada.
- 🔒 **Social Casino Games** es una categoría *estándar*: viene **permitida
  por defecto**. **Bloquearla.** Son juegos de casino simulado, y mostrar sus
  anuncios en un juego que se declara sin apuesta simulada y 13+ es una
  contradicción que un revisor puede marcar.
- El contenido máximo de los anuncios sigue en **T** (decisión de la v1, en
  `store-metadata.md`).
- 🔒 Los bloqueos de AdMob no garantizan lo que muestran las otras redes.
  Revisar en el panel de cada red si tiene control de categorías y bloquear
  juego de azar ahí también.

### 2.6 Dispositivos de prueba y Ad Inspector

- 🔒 **Configuración → Dispositivos de prueba → Agregar**, con el IDFA de cada
  iPhone y iPad de prueba. Un dispositivo de prueba ve anuncios marcados y no
  genera tráfico inválido. **Nunca tocar anuncios propios en un teléfono que
  no esté registrado.**
- **Ad Inspector** se abre desde el panel de debug (E7). Con él, *single ad
  source testing* sobre cada fuente: **AppLovin (Bidding)**, **Unity Ads
  (Bidding)**, **Mintegral (Bidding)** y **Meta Audience Network (Bidding)**
  (nombres de cada guía de Google, sección 3). Cada una tiene que traer un
  anuncio de prueba.
- Cada red tiene además su **modo de prueba** propio (sección 3). ⚠️ Las 4
  guías de Google repiten lo mismo: **apagar el modo de prueba de AdMob y de
  cada red antes de publicar.**
- En DEBUG la app usa los IDs de prueba de Google a propósito
  (`FeatureFlags.effectiveAdUnitIDs`). Los IDs de prueba de los formatos
  nuevos: app open `ca-app-pub-3940256099942544/5575463023`
  ([Google](https://developers.google.com/admob/ios/app-open)) e intersticial
  bonificado `ca-app-pub-3940256099942544/6978759866`
  ([Google](https://developers.google.com/admob/ios/rewarded-interstitial)).

### 2.7 Dos reglas de política que el código de E7 tiene que cumplir

- **Intersticial bonificado**: *"you must present the user with an intro
  screen that provides clear reward messaging and an option to skip the ad
  before it starts"*
  ([Google](https://developers.google.com/admob/ios/rewarded-interstitial),
  [política](https://support.google.com/admob/answer/9884467)). Es la
  `RewardedInterstitialIntroView` de E7, con "No, gracias" visible.
- **App open**: el anuncio vence a las **4 horas** de pedido, y Google
  recomienda no mostrarlo en los primeros arranques
  ([Google](https://developers.google.com/admob/ios/app-open)). El juego lo
  recarga a las 3 h 30 y lo muestra desde la 2ª sesión.

---

## 3. Las cuatro redes

Todas van por **bidding** a través de AdMob: compiten en la misma subasta y
no hace falta armar *waterfall*. Para cada una: cuenta, registro de la app,
placements, las claves que pide AdMob, la línea de `app-ads.txt` y de dónde
salen los SKAdNetwork IDs.

### 3.1 AppLovin

Fuente principal:
[Integrate AppLovin with mediation (Google, iOS)](https://developers.google.com/admob/ios/mediation/applovin).

1. 🔒 **Cuenta**: crear la cuenta de publisher en el panel de AppLovin
   (`dash.applovin.com`).
2. 🔒 **Claves**: **Account → Keys**. Copiar el **SDK Key**. El **Report Key**
   sólo hace falta para waterfall: no se usa.
3. **Registro y placements**: para bidding **no hace falta crear zonas** (las
   *Zone ID* son sólo de waterfall). La guía de Google igual recomienda una
   zona por unidad si algún día se usa waterfall.
4. 🔒 **En AdMob**, al agregar AppLovin a cada grupo: el mapeo pide el **SDK
   Key** y nada más.
5. **Formatos por bidding**: app open, intersticial, bonificado, intersticial
   bonificado y nativo. Banner, no.
6. 🔒 **`app-ads.txt`**: la línea está en **Account → General → App-ads.txt
   Info**. Tiene la forma `applovin.com, <id de la cuenta>, DIRECT`. El
   dominio raíz del sitio se registra en **Account → General → Basic Info**:
   tiene que ser `adergames-site.vercel.app`, el mismo de la ficha
   ([AppLovin, IAB supply chain validation](https://support.applovin.com/en/max/max-dashboard/account/iab-supply-chain-validation)).
7. **SKAdNetwork**: la lista oficial está en
   `https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json` (y `.xml`)
   ([AppLovin, SKAdNetwork](https://support.applovin.com/en/max/ios/overview/skadnetwork)).
   El 2026-10-06 traía **152 IDs, 102 que no están** en nuestro `Info.plist`.
   El propio de AppLovin (`ludvb6z3bs`) ya está.
8. 🔒 **Prueba**: registrar el dispositivo y prender el *test mode* en el
   panel de AppLovin. Ad Inspector: **AppLovin (Bidding)**.

### 3.2 Unity Ads

Fuente principal:
[Integrate Unity Ads with mediation (Google, iOS)](https://developers.google.com/admob/ios/mediation/unity).

1. 🔒 **Cuenta y proyecto**: en el panel de Unity (`cloud.unity.com`),
   **Projects → New**. En el formulario elegir **"I will use Mediation"** con
   **Google AdMob** como socio.
2. 🔒 **Game ID**: aparece al terminar de crear el proyecto, en la
   configuración de monetización. Es el de la tienda **Apple App Store**.
3. 🔒 **Placements**: **Monetization → Placements**, uno por formato
   (bonificado e intersticial). Anotar cada **Placement ID**.
4. 🔒 **En AdMob**, el mapeo pide **Game ID** y **Placement ID**. El Game ID
   tiene que ser el de esta app en el panel de Unity.
5. **Formatos por bidding**: banner, intersticial, bonificado y nativo. **Ni
   intersticial bonificado ni app open.** El waterfall de Unity terminó el
   2026-01-31: sólo bidding.
6. 🔒 **`app-ads.txt`**: en el panel, **Setup → Organization Settings →
   Developer Website**, poner `https://adergames-site.vercel.app` (tiene que
   coincidir con el dominio de la ficha). Después, sección **App-ads.txt →
   Show full list**: el panel arma la lista completa en el formato correcto, y
   se copia entera ([Unity, app-ads.txt](https://docs.unity.com/grow/en-us/ads/optimization/app-ads-txt)).
   Puede ser más de una línea: se copia todo lo que muestre.
7. **SKAdNetwork**: `https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json`
   ([Unity, configure ad network IDs](https://docs.unity.com/en-us/grow/ads/ios-sdk/ios14/configure-ad-network-ids)).
   El 2026-10-06: **76 IDs, 39 nuevos** para nosotros. El propio de Unity
   (`4dzt52r2t5`) ya está. El panel avisa si a la app publicada le faltan IDs
   recomendados.
8. 🔒 **Prueba**: **Monetization → Testing**, forzar el modo de prueba o
   **Add Test Device**. Ad Inspector: **Unity Ads (Bidding)**.

### 3.3 Mintegral

Fuente principal:
[Integrate Mintegral with mediation (Google, iOS)](https://developers.google.com/admob/ios/mediation/mintegral).

1. 🔒 **Cuenta**: registrarse en `dev.mintegral.com`.
2. 🔒 **App Key**: pestaña **APP Setting**.
3. 🔒 **Registro de la app**: **Add APP**, plataforma iOS, completar el
   formulario. Anotar el **APP ID**.
4. 🔒 **Placements**: **Placements & Units → Add Placement**: nombre, formato
   y tipo **Header Bidding**. Anotar el **Placement ID**, y en el desplegable
   "1 AD Units", el **AD Unit ID**. Uno por formato: bonificado, intersticial,
   intersticial bonificado y app open (si el panel no muestra "App Open" en la
   lista de formatos, buscar su equivalente; no se pudo verificar el nombre
   exacto en la doc de Mintegral).
5. 🔒 **En AdMob**, el mapeo pide los cuatro: **App Key**, **App ID**,
   **Placement ID** y **Ad Unit ID**. App ID y App Key tienen que ser los de
   esta app.
6. **Formatos por bidding**: todos (app open, banner, intersticial,
   bonificado, intersticial bonificado y nativo).
7. 🔒 **`app-ads.txt`**: ⚠️ dato **no verificado contra la doc de
   Mintegral** (su página no carga sin JavaScript). Según su blog, la línea
   es `mintegral.com, <Publisher ID>, DIRECT`, con el Publisher ID en
   **Account → Account Info**
   ([Mintegral, app-ads.txt](https://www.mintegral.com/en/blog/how-app-ads-txt-can-help-fight-ad-fraud)).
   Copiar la línea exacta que muestre el panel: si trae un cuarto campo (el
   ID de autoridad de certificación), va también.
8. **SKAdNetwork**: `https://dev.mintegral.com/skadnetworkids.json`, del
   dominio oficial. Su doc de iOS
   ([Mintegral iOS SDK](https://dev.mintegral.com/doc/index.html?file=sdk-m_sdk-ios&lang=en))
   es la que enlaza la guía de Google. El 2026-10-06: **105 IDs, 65
   nuevos**. El propio (`kbd757ywx3`) ya está.
9. 🔒 **Prueba**: usar las App Keys, App IDs, Placement IDs y Ad Unit IDs de
   prueba de la página *Test ID* de Mintegral (misma doc de iOS). Ad
   Inspector: **Mintegral (Bidding)**.

### 3.4 Meta Audience Network

Fuente principal:
[Integrate Meta Audience Network with bidding (Google, iOS)](https://developers.google.com/admob/ios/mediation/meta).

1. 🔒 **Cuenta**: en `business.facebook.com/pub/start`, **Get started →
   Create new account**, datos del negocio.
2. 🔒 **Propiedad**: crear una propiedad para la app, plataforma **iOS**,
   datos de la app y **cuenta de pagos**. Sin la cuenta de pagos no se puede
   seguir.
3. 🔒 **Placements**: uno por formato (*Interstitial*, *Rewarded* y, si el
   panel lo ofrece, *Rewarded interstitial*). Anotar cada **Placement ID**.
4. 🔒 **En AdMob**, el mapeo pide sólo el **Placement ID**.
5. **Formatos por bidding**: banner, intersticial, bonificado, intersticial
   bonificado y nativo. **App open, no.** Meta es sólo bidding desde 2021.
6. 🔒 **`app-ads.txt`**: `facebook.com, <Property ID o Business ID>, RESELLER,
   c3e20eee3f780d68`. Con varias propiedades conviene el Business ID. La
   página de Meta no dice en qué menú está el ID: buscarlo en la propiedad
   dentro de Monetization Manager. Meta pide esperar 24 h después de
   actualizar el archivo antes de volver a verificar
   ([Meta, authorized sellers](https://developers.facebook.com/docs/audience-network/optimization/best-practices/authorized-sellers-app-ads/)).
7. **SKAdNetwork**: dos IDs, `v9wttpbfk9.skadnetwork` y `n38lu8286q.skadnetwork`
   ([Meta, SKAdNetwork](https://developers.facebook.com/documentation/audience-network/setting-up/platform-setup/ios/SKAdNetwork.md)).
   **Los dos ya están** en el `Info.plist` (vienen en la lista de Google).
8. 🔒 **Prueba**: registrar el dispositivo y prender el modo de prueba en
   Monetization Manager. ⚠️ Para probar, **el dispositivo tiene que tener la
   app de Facebook instalada y una sesión iniciada**. Ad Inspector: **Meta
   Audience Network (Bidding)**.

### 3.5 SKAdNetwork: el número

Hoy el `Info.plist` tiene **50** identificadores, los de Google. La lista de
Google ([3p-skadnetworks](https://developers.google.com/admob/ios/3p-skadnetworks))
sigue teniendo 50 el 2026-10-06. Con las listas de las 4 redes, sin
repetidos, son **156: 106 nuevos**.

| Lista | IDs | Que no tenemos |
|---|---:|---:|
| Google (AdMob) | 50 | 0 |
| AppLovin | 152 | 102 |
| Unity Ads | 76 | 39 |
| Mintegral | 105 | 65 |
| Meta | 2 | 0 |
| **Unión** | **156** | **106** |

Lo hace E7a, en el `Info.plist`: la unión sin repetidos de las 5 listas,
bajadas de las URLs de arriba **el día que se arma el build**. Las listas
crecen: el comentario del `Info.plist` ya lo advierte. Sin un ID, no falla
nada; esa red sólo factura menos, y por eso es fácil no notarlo.

### 3.6 Lo que le toca al código (E7a)

No es del panel, pero sale de las mismas guías y conviene tenerlo junto:

| Red | Paquete SPM (rama `main`) | Mínimo SPM | Última versión (2026-10-06) | Código extra |
|---|---|---|---|---|
| AppLovin | `https://github.com/googleads/googleads-mobile-ios-mediation-applovin.git` | 13.3.1.0 | 13.6.4.0 | EE. UU.: `ALPrivacySettings.setDoNotSell(…)` antes de iniciar AdMob |
| Unity Ads | `https://github.com/googleads/googleads-mobile-ios-mediation-unity.git` | 4.16.0.0 | 4.20.1.0 | EE. UU.: `UADSMetaData` con `privacy.consent`. GDPR: el adaptador lo toma de TCF |
| Mintegral | `https://github.com/googleads/googleads-mobile-ios-mediation-mintegral.git` | 7.7.9.0 | 8.1.7.0 | — |
| Meta | `https://github.com/googleads/googleads-mobile-ios-mediation-meta.git` | 6.20.1.0 | 6.22.0.0 (pide iOS 15+) | `FBAdSettings.setAdvertiserTrackingEnabled(…)` **antes** de iniciar AdMob |

Fuente: la guía de Google de cada red (3.1 a 3.4). ⚠️ Las versiones cambian
cada pocas semanas: E7a usa la última al implementar y verifica que el
adaptador y el SDK traigan manifiesto de privacidad (1.7).

---

## 4. El sitio `adergames-site`

Sólo se describen los cambios: este frente no toca ese repo.

⚠️ **El checkout local está atrasado.** `~/Desktop/projects/adergames-site`
es del 2026-09-02: no tiene `public/app-ads.txt`, y su `content/legal.ts`
tiene la política de julio. El sitio publicado ya tiene las dos cosas
(verificado con `curl` el 2026-10-06). 🔒 Antes de tocar: `git pull` desde
`manuader/adergames-site`. Vercel publica solo al pushear a `main`.

### 4.1 `public/app-ads.txt`

Hoy publicado, una sola línea:

```
google.com, pub-8575641544774372, DIRECT, f08c47fec0942fa0
```

🔒 Queda esa línea **más las de las 4 redes, copiadas de cada panel**:

```
google.com, pub-8575641544774372, DIRECT, f08c47fec0942fa0
applovin.com, <de Account → General → App-ads.txt Info>, DIRECT
<la lista completa de Unity: Setup → Organization Settings → App-ads.txt → Show full list>
mintegral.com, <Publisher ID de Account → Account Info>, DIRECT
facebook.com, <Property ID o Business ID>, RESELLER, c3e20eee3f780d68
```

- Las formas de arriba son las de la sección 3; **lo que vale es lo que dé
  cada panel**.
- El archivo vive en la raíz del dominio de la ficha
  (`https://adergames-site.vercel.app/app-ads.txt`). Las redes lo encuentran
  por el sitio de desarrollador de la App Store, así que ese dominio y el de
  sus paneles tienen que ser el mismo.
- Verificar con `curl https://adergames-site.vercel.app/app-ads.txt`, y a las
  24 h, en cada panel (AdMob: **Apps → app-ads.txt**).

### 4.2 `content/legal.ts`: la política de privacidad

La fuente de verdad del texto es `Distribution/site/privacy.md`, que viaja
también en el bundle (`Resources/Legal/privacy.md`, con un test que exige que
sean idénticos). Hoy nombra sólo a Google AdMob. Para la 2.0 cambia en tres
puntos, que se aplican **en los tres lugares a la vez** (`privacy.md` del
repo, su copia del bundle y `legal.ts`) **cuando salga la 2.0, no antes**: la
v1 no usa esas redes.

1. **Las redes**: "Google AdMob y las redes que le venden anuncios a través
   de AdMob: AppLovin, Unity Ads, Mintegral y Meta Audience Network. Cada una
   procesa datos según su propia política", con el link de cada política.
2. **Los formatos**: los videos con recompensa, opcionales, y los que
   aparecen solos (pantalla completa, pausa publicitaria y al volver a la
   app). "Sin anuncios" saca los que aparecen solos, y los videos siguen. Es
   lo mismo que dicen los Términos §4.
3. **La configuración remota**: la app baja un archivo de configuración de
   anuncios de nuestro sitio (`/config/ads.json`). **No manda datos del
   jugador**, pero como cualquier pedido web, el proveedor del sitio (Vercel)
   ve la IP. Hoy la política dice "no tenemos servidores propios": sigue
   siendo cierto (es un archivo estático), pero conviene decirlo para que no
   haya sorpresas.

Además, la fila de Ajustes **"Opciones de privacidad"** (UMP) ya se puede
nombrar: "podés revisar tu elección desde Ajustes → Opciones de privacidad".

🔒 El texto final lo escribe quien publique la 2.0, con estos tres puntos.
Tiene que coincidir con App Privacy (1.7).

### 4.3 Los Términos

`Distribution/site/terms.md` y su copia del bundle ya están corregidos en el
repo (este frente): la sección **4. Anuncios / 4. Ads** dice que "Sin
anuncios" saca los anuncios que aparecen solos y que los videos con
recompensa siguen. Antes decía lo contrario: que sacaba los videos.

🔒 En el sitio, los términos viven en **`content/terms.ts`** (no en
`legal.ts`). Hay que copiar la sección 4 nueva en sus dos idiomas y la fecha
de "última actualización", con el mismo formato de bloques que usa ese
archivo (`p` y `list`).

- Esta corrección **vale también para la v1**: dice "pueden ser" y no nombra
  los formatos que la v1 no tiene. Se puede publicar ya.
- Hoy el sitio publicado todavía dice "Si la versión instalada muestra
  anuncios recompensados… Podés eliminarlos con la compra 'Sin anuncios'"
  (verificado el 2026-10-06 en `/terms` y `/es/terms`).

### 4.4 `public/config/ads.json`: la config remota

Hoy da **404** (verificado el 2026-10-06). Lo crea E7a (`AdsRemoteConfig`):
IDs de unidades, cadencia, alternancia, app open, interruptores de apagado y
`restrictedStorefronts`.

- 🔒 El contenido es **el mismo que el respaldo que viaja en el bundle**, que
  define E7a. Este doc no inventa el esquema: se copia el archivo del repo de
  la app tal cual.
- Reglas que pone el plan y que hay que respetar al editarlo a mano:
  - sólo HTTPS;
  - **cada ID tiene que ser del publisher `pub-8575641544774372`**: si uno no
    lo es, la app descarta **el archivo entero** y usa el del bundle;
  - JSON válido: si no parsea, también se descarta.
- Los países de `restrictedStorefronts` van como los devuelve StoreKit
  (`Storefront.countryCode`, de tres letras): **`BEL`** y **`AUS`**.
- Verificar con `curl -i https://adergames-site.vercel.app/config/ads.json`:
  `200` y `content-type: application/json`.
- Sirve para cambiar cadencia, apagar un formato o cambiar un ID **sin pasar
  por Apple**. Lo que no puede hacer es sumar una red o un formato nuevos:
  eso sigue pidiendo un build.

### 4.5 Orden en el sitio

1. **Ya**: los Términos corregidos (4.3) y el `app-ads.txt` en cuanto haya
   líneas de las redes (4.1). Se pueden publicar antes que la 2.0.
2. **Antes de mandar el build a TestFlight**: `config/ads.json` (4.4), así la
   prueba real lee el remoto.
3. **El día que sale la 2.0**: la política nueva (4.2).

---

## 5. A futuro: automatizarlo (fuera de alcance)

Queda anotado (PLAN-v2 §7): un script de Selenium que haga las secciones 1 y
2 solo. Este doc es su insumo: cada paso dice el menú, el campo y el valor.
Lo que no se puede automatizar sin el dueño son los pasos 🔒 de cuentas
nuevas, pagos y aceptación de términos de las redes.
