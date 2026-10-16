# BORRADOR — PARA APROBAR POR EL DUEÑO (🔒 P3) · [VERIFICAR CON ABOGADO]

> **Nada de este archivo está aplicado.** Son los textos de privacidad de la personalización de la 2.1 (E15 F1–F5:
> ayudas y ofertas según el segmento) para que el dueño los apruebe, corrija o rechace. Hasta su OK no se toca
> `privacy.md`, `terms.md`, `adergames-site` ni `release.json`. **Todo lo legal va `[VERIFICAR CON ABOGADO]`**
> (V11: hoy sin abogado). El interruptor `personalization_enabled` **no se prende** hasta que: (1) el dueño aprueba
> este borrador (P3), (2) los textos están publicados y dentro de un binario de la tienda, y (3) pasó la revisión con
> abogado (V21-F1-T9, gate G7). La 2.1 **sí** puede publicarse con el interruptor apagado: el binario declara la
> verdad de lo que **puede** hacer (manifiesto, abajo), y los textos se aplican antes de prender.

Plan: `Docs/superpowers/plans/2026-10-16-v21-e15-f1.md` (V21-F1-T7). Escrito el 2026-10-16 contra la base
`v21i/integ-ola3` = `79c1fc1a` (olas 1–3 de la 2.1). Lo que el código realmente hace:

- **El cálculo es local (R5, 5.1.2(iii)).** `PlayerValueInputsBuilder` arma `PlayerValueInputs` con: país de la
  tienda (`DeviceContext`, alfa-3), modelo (`utsname.machine`), del ledger de anuncios con premio (cuántos, promedio y
  reciente en micros), si compró (`meta.creditedPurchases`), sesiones y duración media de los últimos 7 días, videos
  vistos desde siempre, ofertas vistas y reencarnaciones de los últimos 7 días (estas dos sólo para el modelo de F6).
  `PlayerValue` (EconomyKit) devuelve `low`/`mid`/`high`; **`base` la decide la compuerta**, nunca las reglas.
- **Qué guarda el teléfono:** `Application Support/personalization.json` (`PersonalizationStore`): el último cálculo
  (segmento, micros esperados por video, score, versión de las tablas, variante), el último segmento informado y las
  últimas 30 sesiones. **No va en el save.** Con la compuerta cerrada **no se borra** (ver decisión 2).
- **Qué baja:** `rpc/personalization_config` en el Supabase del ranking (`PersonalizationConfigLoader`), sin datos
  del jugador; caché en `Caches`, respaldo en el bundle. Un `null` del servidor apaga todo y borra la caché.
- **Qué sube (C6, F1-T6), sólo por la telemetría de F0 y con su compuerta:** `segment` (`id` = low/mid/high, `ver` de
  las tablas, `src` = `rules` o `tree-<v>`) **sólo cuando cambia**; `exposure` (`exp`, `arm`, `ver`) una vez por sesión
  y brazo, sólo con el A/B del modelo prendido; y, ya no ligados a la personalización pero nuevos en la 2.1,
  `progress` con el `session_end` (`max_tier` de esta vida, `active_minutes`, `prestige`) y `ctx` en `offer` (el
  momento de necesidad: `floor_full`, `price_wall`, `mattress_ready`, `back_offline`). **No sube** el score ni los
  micros esperados. El A/B reparte por `ExperimentBucket` con el id propio de la telemetría, en el teléfono.
- **La compuerta (`PersonalizationGate`):** interruptor remoto ∧ consentimiento (`PersonalizationConsent`) ∧ sin
  señal de menor (`tagForUnderAgeOfConsent` / `tagForChildDirectedTreatment`) ∧ no UI test ∧ no `DEBUG`. Consentimiento
  (V9): con `IABTCF_gdprApplies == 1` exige los propósitos TCF **{1, 5, 6, 8, 9, 10}**; con `0` alcanza con UMP; sin la
  clave, sólo si UMP dice `notRequired`; cualquier otra cosa, no. **Fuera del RGPD no hay interruptor en el juego**
  (P9, default «no» en la 2.1).
- **Qué cambia para el jugador (F2, F3, F5):** palancas de `segments.json` que **sólo pueden dar más** que la base
  (`SegmentLevers.Caps`: premio por video hasta ×2,5 por fuente, intervalos del colchón y de los visitantes y pausas del
  costado hasta 25 % más cortos, forzados hasta 3 veces más espaciados); ofertas de video en momentos de necesidad
  (F3, opt-in, a la vista); en la Tienda, un **destaque** (`StoreRecommendation`: nunca oculta, reordena ni cambia
  precios) y audiencias en las ofertas de 24 h (F5-T3: `bienvenida` → sólo no compradores de los segmentos no-base),
  con el aviso «Oferta elegida para vos» en los storefronts de la UE (V8). Con `base`, la 2.0 bit a bit.

## Antes de aprobar: lo que decide el dueño

1. **Fuera de la UE, el Reino Unido y Suiza no hay cómo apagarla (P9).** Es lo decidido para la 2.1 (default «no»
   a la fila «Ayudas a tu medida» en Ajustes) y el texto lo dice tal cual. Pero App Store **5.1.1(ii)** pide una forma
   fácil de retirar el consentimiento a la recolección de datos de uso, y la personalización suma un fin nuevo
   (5.1.2(ii)). Es la pregunta 2 del bloque 6. Si el abogado o el dueño dicen que sí hace falta, la fila de Ajustes es
   una tarea nueva y el párrafo «Cómo se apaga» cambia a la **variante B**:
   > *Además, en cualquier país podés apagarla en **Ajustes → Ayudas a tu medida**: el juego vuelve a ser el mismo
   > para todos y el grupo deja de mandarse.* (en: *You can also turn it off anywhere in **Settings → Tailored help**:
   > the game goes back to being the same for everyone and the group stops being sent.*)
2. **Al retirar el consentimiento, el último cálculo queda en el teléfono sin usarse** (`PersonalizationService`:
   «sin borrar el último cálculo: si vuelve el consentimiento, no arranca de cero»). El texto lo dice. La alternativa
   prudente para el RGPD (ePrivacy 5(3), minimización) es **borrar** `personalization.json` cuando la compuerta se
   cierra por consentimiento; es un cambio chico en el servicio y su test (tarea nueva, no de T7). Si el dueño la
   elige, la frase «el último cálculo queda en tu teléfono, sin usarse» pasa a «y lo que tu teléfono había calculado
   se borra». `[VERIFICAR CON ABOGADO]`
3. **Device ID sin Product Personalization (default de T7).** El manifiesto suma el propósito a Product Interaction,
   Advertising Data y Purchase History (lo que alimenta `PlayerValueInputs`), **no** a Device ID: el id propio de la
   telemetría sólo reparte el A/B del cálculo, en el teléfono, y no entra en el valor. Si el dueño prefiere declarar
   de más, es una línea del `.xcprivacy` y una del test (y la fila 2 de la etiqueta).
4. **«Ningún grupo empeora el juego» vs. la audiencia de `bienvenida`.** Las ayudas sólo suman (lo garantizan los
   topes y el pacing-sim por segmento), pero F5-T3 hace que el pack de bienvenida (día 2) lo vea sólo quien no compró:
   un comprador en un segmento no-base no lo ve, y en la 2.0 sí. El texto no lo esconde (lo pone de ejemplo en la
   Tienda) y dice «un grupo sólo puede sumar **ayudas**», no «ofertas». Si el dueño quiere poder decir «nadie pierde
   nada», la audiencia de `bienvenida` tiene que ser `all` (F5-T3).
5. **El nombre en inglés del aviso UE.** El texto usa «Oferta elegida para vos» / «Offer picked for you». Los textos
   visibles de F5-T3 son 🔒 P8: si el dueño cambia el aviso, cambia también acá (tres lugares: `.md`, sitio es y en).

Lo que se mantiene coherente con lo ya publicado: el resumen sigue siendo UN párrafo y la mitad inglesa también
(`SettingsPersistenceTests`); siguen nombradas Google AdMob, Unity Ads, Supabase y Anthropic con sus links
(`privacyNamesTheNetworksAndTheRanking`); el texto no llama «anónimo» al grupo (va con el id seudónimo de la
telemetría) y repite la fórmula de la IP de Supabase de F0.

---

## 1. `privacy.md` (es y en)

Va **idéntico, byte a byte**, en `Distribution/site/privacy.md` y `FisuEvolution/Resources/Legal/privacy.md`
(`SettingsPersistenceTests.bundledCopyMatchesTheSourceOfTruth`). Qué cambia respecto de la versión vigente (la de F0):

- **El resumen** (sigue siendo UN párrafo): suma que el teléfono adapta ayudas opcionales y ofertas con datos del
  propio juego, sin tocar precios ni empeorar el juego.
- **Estadísticas de uso:** «Qué pasó» suma lo nuevo de la 2.1 (`progress` y el `ctx` de `offer`), y una viñeta nueva
  «Lo de la personalización» (`segment` y `exposure`).
- **Sección nueva «Ayudas y ofertas a tu medida»** (después de «Estadísticas de uso», antes de «Compras»): con qué se
  calcula y dónde (en el teléfono; al servidor sólo llega el grupo); qué cambia (ayudas, ofertas en el momento,
  destaque y ofertas de la Tienda, el aviso UE); qué no cambia nunca (precios, el juego base, ATT); qué nos llega y para
  qué; qué baja; qué queda en el teléfono; cómo se apaga (UMP en la UE/RU/Suiza; fuera, sin interruptor: decisión 1;
  menores: V10).
- **Compras:** el precio es el mismo para todos.
- **Menores:** no pedimos la edad; con señal de menor, nada a medida.
- **La nota de mantenimiento:** punto 4 sobre el manifiesto, la etiqueta y el gate del abogado.
- **La mitad inglesa** (UN párrafo): lo mismo, en el mismo orden.

Diff contra `Distribution/site/privacy.md` de la base (`79c1fc1a`):

```diff
--- a/Distribution/site/privacy.md
+++ b/Distribution/site/privacy.md
@@ -6,7 +6,9 @@
 publicidad procesa algunos datos, el ranking guarda un identificador anónimo y
 el nombre que vos elegís, y el juego nos manda estadísticas de uso, con un
 identificador al azar propio de ellas, para saber cómo se juega y cuánto rinden
-los anuncios. Abajo está exactamente cuáles y cómo los controlás.**
+los anuncios. Con datos del propio juego, tu teléfono también puede adaptar
+ayudas opcionales y ofertas, sin tocar los precios ni empeorar el juego. Abajo
+está exactamente cuáles y cómo los controlás.**
 
 ## Lo que NO hacemos
 
@@ -111,12 +113,18 @@
 lleva:
 
 - **Qué pasó:** que empezó o terminó una sesión de juego (cuánto duró y
-  cuántas sesiones llevás); que se vio un anuncio (de qué tipo, en qué lugar
-  del juego, qué red lo sirvió y cuánto pagó por esa vista, en su moneda); qué
-  pasó con una oferta de video (si apareció, si la tocaste, si te ganaste el
-  premio, si no había video o si la dejaste pasar); qué producto compraste
+  cuántas sesiones llevás) y, al terminar, hasta qué personaje llegaste en
+  esta vida, cuántos minutos jugaste en total y cuántas veces reencarnaste;
+  que se vio un anuncio (de qué tipo, en qué lugar del juego, qué red lo
+  sirvió y cuánto pagó por esa vista, en su moneda); qué pasó con una oferta
+  de video (si apareció, si la tocaste, si te ganaste el premio, si no había
+  video o si la dejaste pasar) y, si apareció por algo que te pasaba en la
+  partida, qué fue (por ejemplo, el piso lleno); qué producto compraste
   (sólo cuál: ni el precio ni los datos de la compra); y cuántas veces
   reencarnaste.
+- **Lo de la personalización:** el grupo en que te ubicó tu teléfono y con
+  qué versión de las reglas, y, si estamos probando dos formas de calcularlo,
+  cuál te tocó. Se explica en la sección siguiente.
 - **Datos técnicos:** la versión del juego y de iOS, el modelo de tu iPhone o
   iPad (por ejemplo, "iPhone16,2") y el país de tu App Store.
 - **Un identificador al azar, propio de estas estadísticas.** No es el del
@@ -156,12 +164,65 @@
 de seguimiento de iOS (App Tracking Transparency) porque no son seguimiento: no
 se cruzan con datos de otras empresas.
 
+## Ayudas y ofertas a tu medida
+
+Algunas ayudas opcionales y algunas ofertas del juego se adaptan a cada
+jugador. Para eso, **tu teléfono** estima cuánto rinde tu partida para
+nosotros, con datos del propio juego: el país de tu App Store, el modelo de
+tu iPhone o iPad, cuántos videos con premio viste y cuánto pagaron, si
+compraste algo, y cuántas sesiones jugaste y cuánto duraron en la última
+semana. Con eso te ubica en uno de tres grupos. El cálculo se hace en el
+teléfono: a nuestro servidor no le llega el valor estimado, sólo el grupo.
+
+Según el grupo, puede cambiar:
+
+- **Las ayudas opcionales:** cuánto paga un video con premio, cada cuánto
+  cae el colchón de regalo o llega un visitante, cuánto esperan las ayudas del
+  costado, y que aparezcan menos anuncios solos.
+- **Las ofertas de video en el momento justo:** por ejemplo, con el piso
+  lleno, una oferta que dice exactamente qué te da si mirás un video. La
+  elegís vos y siempre podés decir que no.
+- **Qué te destacamos en la Tienda y algunas ofertas por tiempo limitado:**
+  por ejemplo, el pack de bienvenida aparece sólo si todavía no compraste
+  nada. Ningún producto se esconde de la Tienda. En la Unión Europea, esas
+  ofertas llevan el aviso "Oferta elegida para vos".
+
+Lo que **no** cambia nunca: **el precio** de cada producto, que es el mismo
+para todos (lo fija la App Store), y el juego en sí: un grupo sólo puede
+sumar ayudas, nunca sacarlas ni hacer el juego más lento. Nada de esto
+depende de que aceptes el seguimiento de iOS (App Tracking Transparency).
+
+**Qué nos llega.** El grupo en que quedaste, con la versión de las reglas que
+lo decidió, y, si estamos probando dos formas de calcularlo, cuál te tocó.
+Viaja con las estadísticas de uso de la sección anterior, con su mismo
+identificador, su mismo consentimiento y sus mismos 400 días. Lo usamos para
+saber si las ayudas sirven y para mejorar el cálculo; no lo usamos para
+mostrarte publicidad ni se lo pasamos a nadie. Para adaptar el juego, el
+teléfono además baja de nuestro servidor las reglas de la personalización:
+ese pedido no manda ningún dato tuyo, pero, como cualquier pedido web,
+Supabase ve la dirección IP desde la que se hace.
+
+**Qué queda en tu teléfono.** El último cálculo y tus últimas sesiones, fuera
+de tu partida guardada. No salen de ahí.
+
+**Cómo se apaga.** En la Unión Europea, el Reino Unido y Suiza funciona sólo
+si en el formulario de consentimiento de Google aceptaste, además de lo de las
+estadísticas, que se arme un perfil para personalizar el contenido y que se
+use para elegirlo. Si no lo aceptaste, o si lo retirás en **Ajustes → Opciones
+de privacidad**, el juego vuelve a ser el mismo para todos y el grupo deja de
+mandarse; el último cálculo queda en tu teléfono, sin usarse. Fuera de la UE,
+el Reino Unido y Suiza el juego no tiene un interruptor propio para esto. Y
+si el formulario de Google indica que sos menor de edad, la personalización
+no se aplica.
+
 ## Compras dentro de la app
 
 Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni
 de tu método de pago — sólo recibimos de Apple la confirmación de qué
 compraste, para entregártelo. Qué producto compraste (sin el precio) también
-va en las estadísticas de uso.
+va en las estadísticas de uso. El precio de cada producto es el mismo para
+todos; lo que puede cambiar es qué te destacamos (ver «Ayudas y ofertas a tu
+medida»).
 
 ## Tu progreso de juego
 
@@ -172,7 +233,9 @@
 ## Menores
 
 El juego tiene clasificación 12+ y no está dirigido a menores de 13 años. No
-recolectamos a sabiendas datos de menores de esa edad.
+recolectamos a sabiendas datos de menores de esa edad. No te pedimos la edad;
+si el formulario de consentimiento de Google indica que sos menor, las ayudas
+y ofertas a tu medida no se aplican.
 
 ## Contacto
 
@@ -197,6 +260,12 @@
 >    (`PrivacyManifestTests`), y la etiqueta de App Store Connect también. El
 >    interruptor de la telemetría no se prende hasta que esta versión del
 >    texto esté publicada y en un binario de la tienda.
+> 4. **La personalización (2.1)**: el manifiesto suma el propósito
+>    Product Personalization a Product Interaction, Advertising Data y
+>    Purchase History, y la etiqueta de App Store Connect también. El
+>    interruptor `personalization_enabled` no se prende hasta que esta
+>    versión del texto esté publicada, en un binario de la tienda y revisada
+>    por un abogado (V21-F1-T9).
 >
 > ⚠️⚠️ **El mail de contacto tiene que ser uno que RECIBA.** El sitio publicado
 > dice `support@adergames.io` / `contact@adergames.io`, y el 2026-09-15 se
@@ -217,4 +286,4 @@
 
 # Privacy Policy — HoboEvolution (English)
 
-We ask for no personal data, but the ads process some, and the game sends us usage statistics under a random identifier of their own. HoboEvolution shows ads through Google AdMob: opt-in rewarded videos you choose to watch for in-game prizes, and ads that appear on their own (full-screen ads between parts of the game, an ad break you can always decline, and one when you return to the app), all removed by the "No Ads" purchase except rewarded videos, which stay since they're optional and pay out. To serve them, Google AdMob processes device data including your advertising identifier (IDFA), IP address and technical/usage data, under its own policy at https://policies.google.com/privacy. AdMob also has another ad network bid for each ad (mediation); in this version it is only Unity Ads (https://unity.com/legal/privacy-policy), which processes the same kind of device data under its own policy. We work with no other networks, and none of them receives your leaderboard name, install identifier or run times from us. The app downloads an ads configuration file from our website; it sends none of your data, but like any web request the site's host (Vercel) sees the IP address. On first launch iOS asks for App Tracking Transparency: accept and ads are personalized, decline and **you still get ads, just non-personalized** — you lose nothing in the game, and you can change it any time in Settings → Privacy & Security → Tracking. In the EU, UK and Switzerland we also show Google's consent form (UMP) before serving any ad, and you can review your choice in Settings → Privacy options. Your game progress stays on your device. Purchases are handled by Apple; we never see your payment details. The game also sends our server small usage statistics so we can see how it is played and what each ad earns: session start and end (its length and how many sessions you've played); each ad shown (format, place in the game, the network that served it and what it paid for that view, in its currency); what happened to each rewarded-video offer (shown, tapped, rewarded, no video, or passed); which product you bought (never the price or payment details); and how many times you reincarnated. Each one carries the app and iOS version, your device model (e.g. "iPhone16,2"), your App Store country, a random identifier of their own (not the leaderboard's, not shared with it and not tied to your name; it survives reinstalling on the same device and never moves to your other devices, whether through iCloud or a backup restored to another phone), a new session identifier each time you open the game, and your phone's time. They never carry your advertising identifier (IDFA), the iOS vendor identifier (IDFV), your leaderboard name, anything you typed or your Apple account or payment data; we don't combine them with your leaderboard name or anything that identifies you, don't use them for advertising or to track you across apps or websites, don't share them with ad networks and never sell them. Like any web request, the server's host (Supabase) sees the IP address each request (leaderboard or statistics) comes from and keeps it in its technical logs for a few days; we don't store it with the statistics, don't use it to identify you and don't combine it with them. The statistics are stored on Supabase on our behalf and deleted automatically after 400 days; while you are offline they wait on your device (at most the latest 1,000, for up to a month). In the EU, UK and Switzerland they are sent only if, in Google's consent form, you agreed to storing information on your device and to using it for measurement, statistics and improving the service; you can change that any time in Settings → Privacy options: withdraw it and they stop, and whatever was waiting on your device is deleted without leaving it. Outside the EU, UK and Switzerland the game has no switch for this; Privacy options, where they appear, control the ads. They don't depend on iOS App Tracking Transparency because they are not tracking: they are never combined with other companies' data. If you reach God you may choose to enter the leaderboard with a name; it is optional, and without it your run is not published. For that we store on our server a random anonymous install identifier (not tied to your identity, your Apple account or your advertising identifier) and the name you chose plus your run times, which other players can see. We don't use them to track you, don't link them to your identity and don't share them with advertisers. The leaderboard lives on our own server, hosted on Supabase. Names go through rules, a word list and an automated AI check by Anthropic (Claude) before being shown: we send Anthropic only the name you chose (up to 15 characters), never your install identifier, run times, advertising identifier or any device data, and it processes the name under its own policy at https://www.anthropic.com/legal/privacy. So don't put personal data in your name; anyone can report a name and a reported name is hidden. If you block a name ("Hide this name"), that choice is stored only on your device and never leaves it. To have your name or runs removed, email us. We have no accounts and no third-party analytics, our only server (on Supabase) holds the leaderboard and the usage statistics, and we never sell data. The game is rated 12+ and is not directed at children under 13. Questions: adermanu@gmail.com
+We ask for no personal data, but the ads process some, and the game sends us usage statistics under a random identifier of their own. Using in-game data, your phone may also tailor optional help and offers, without touching prices or making the game worse. HoboEvolution shows ads through Google AdMob: opt-in rewarded videos you choose to watch for in-game prizes, and ads that appear on their own (full-screen ads between parts of the game, an ad break you can always decline, and one when you return to the app), all removed by the "No Ads" purchase except rewarded videos, which stay since they're optional and pay out. To serve them, Google AdMob processes device data including your advertising identifier (IDFA), IP address and technical/usage data, under its own policy at https://policies.google.com/privacy. AdMob also has another ad network bid for each ad (mediation); in this version it is only Unity Ads (https://unity.com/legal/privacy-policy), which processes the same kind of device data under its own policy. We work with no other networks, and none of them receives your leaderboard name, install identifier or run times from us. The app downloads an ads configuration file from our website; it sends none of your data, but like any web request the site's host (Vercel) sees the IP address. On first launch iOS asks for App Tracking Transparency: accept and ads are personalized, decline and **you still get ads, just non-personalized** — you lose nothing in the game, and you can change it any time in Settings → Privacy & Security → Tracking. In the EU, UK and Switzerland we also show Google's consent form (UMP) before serving any ad, and you can review your choice in Settings → Privacy options. Your game progress stays on your device. Purchases are handled by Apple; we never see your payment details, and each product's price is the same for everyone. The game also sends our server small usage statistics so we can see how it is played and what each ad earns: session start and end (its length and how many sessions you've played) and, at the end, the highest character reached in this life, your total minutes played and how many times you reincarnated; each ad shown (format, place in the game, the network that served it and what it paid for that view, in its currency); what happened to each rewarded-video offer (shown, tapped, rewarded, no video, or passed) and, if it appeared because of something in your game, what it was (e.g. a full floor); which product you bought (never the price or payment details); how many times you reincarnated; and the personalization group your phone placed you in, with the rules version and, if we are testing two ways to compute it, which one you got. Each one carries the app and iOS version, your device model (e.g. "iPhone16,2"), your App Store country, a random identifier of their own (not the leaderboard's, not shared with it and not tied to your name; it survives reinstalling on the same device and never moves to your other devices, whether through iCloud or a backup restored to another phone), a new session identifier each time you open the game, and your phone's time. They never carry your advertising identifier (IDFA), the iOS vendor identifier (IDFV), your leaderboard name, anything you typed or your Apple account or payment data; we don't combine them with your leaderboard name or anything that identifies you, don't use them for advertising or to track you across apps or websites, don't share them with ad networks and never sell them. Like any web request, the server's host (Supabase) sees the IP address each request (leaderboard or statistics) comes from and keeps it in its technical logs for a few days; we don't store it with the statistics, don't use it to identify you and don't combine it with them. The statistics are stored on Supabase on our behalf and deleted automatically after 400 days; while you are offline they wait on your device (at most the latest 1,000, for up to a month). In the EU, UK and Switzerland they are sent only if, in Google's consent form, you agreed to storing information on your device and to using it for measurement, statistics and improving the service; you can change that any time in Settings → Privacy options: withdraw it and they stop, and whatever was waiting on your device is deleted without leaving it. Outside the EU, UK and Switzerland the game has no switch for this; Privacy options, where they appear, control the ads. They don't depend on iOS App Tracking Transparency because they are not tracking: they are never combined with other companies' data. Some optional help and offers are tailored to each player: your phone estimates what your game is worth to us, from in-game data only (your App Store country, your device model, how many rewarded videos you watched and what they paid, whether you bought anything, and how many sessions you played and how long they lasted in the last week) and places you in one of three groups. The estimate is computed on the phone; our server never receives it, only the group. Depending on the group, rewarded videos may pay more, the free Mattress and visitors may come more often, the side-column helpers may wait less, fewer ads may appear on their own, rewarded-video offers may show up at the right moment (always saying exactly what you get, always yours to decline), and the Store may highlight a different pack or show some limited-time offers only to some players, never hiding any product (in the EU, marked "Offer picked for you"). What never changes: each product's price, which is the same for everyone (set by the App Store), and the game itself, since a group can only add help, never take it away or slow the game down; none of it depends on App Tracking Transparency. The group, its rules version and, during a test, the variant you got travel with the usage statistics, under the same identifier, consent and 400 days; we use them to see whether the help works and to improve the estimate, never for advertising, and never share them. The phone also downloads the personalization rules from our server, sending none of your data (Supabase sees the IP, like any web request). The latest estimate and your recent sessions stay on your phone, outside your saved game. In the EU, UK and Switzerland it works only if, in Google's consent form, you also agreed to building a profile to personalize content and to using it to choose that content; if you didn't, or you withdraw it in Settings → Privacy options, the game goes back to being the same for everyone and the group stops being sent (the latest estimate stays on your phone, unused). Outside the EU, UK and Switzerland the game has no separate switch for this. If Google's consent form flags you as a minor, nothing is tailored. If you reach God you may choose to enter the leaderboard with a name; it is optional, and without it your run is not published. For that we store on our server a random anonymous install identifier (not tied to your identity, your Apple account or your advertising identifier) and the name you chose plus your run times, which other players can see. We don't use them to track you, don't link them to your identity and don't share them with advertisers. The leaderboard lives on our own server, hosted on Supabase. Names go through rules, a word list and an automated AI check by Anthropic (Claude) before being shown: we send Anthropic only the name you chose (up to 15 characters), never your install identifier, run times, advertising identifier or any device data, and it processes the name under its own policy at https://www.anthropic.com/legal/privacy. So don't put personal data in your name; anyone can report a name and a reported name is hidden. If you block a name ("Hide this name"), that choice is stored only on your device and never leaves it. To have your name or runs removed, email us. We have no accounts and no third-party analytics, our only server (on Supabase) holds the leaderboard and the usage statistics, and we never sell data. The game is rated 12+ and is not directed at children under 13; we never ask your age. Questions: adermanu@gmail.com
```

## 2. `terms.md`

**La línea mínima** (plan): una viñeta nueva al final de §3 «Compras», después de «Precios y catálogo pueden
cambiar», en español e inglés. No toca las frases que fija `termsCarryTheUserContentClauses`. Va idéntico en
`Distribution/site/terms.md` y `FisuEvolution/Resources/Legal/terms.md`. §4 ya manda el tratamiento de datos a la
Política de Privacidad.

```diff
--- a/Distribution/site/terms.md
+++ b/Distribution/site/terms.md
@@ -75,6 +75,10 @@
   precio de los productos, y podemos ajustar el balance del Juego (costos,
   ganancias, recompensas) en cualquier momento. Los cambios de balance no dan
   derecho a reembolso de compras anteriores.
+- **Ofertas a tu medida, precios iguales.** Algunas ayudas opcionales y
+  ofertas del Juego, incluido qué te destaca la Tienda, se eligen según
+  cómo jugás, como explica la Política de Privacidad. El precio de cada
+  producto es el mismo para todos.
 
 ## 4. Anuncios
 
@@ -262,6 +266,10 @@
 - **Prices and catalogue may change.** We may add, remove or reprice
   products, and we may rebalance the Game (costs, earnings, rewards) at any
   time. Balance changes do not entitle you to a refund of past purchases.
+- **Tailored offers, same prices.** Some optional help and offers in the
+  Game, including what the Store highlights for you, are chosen based on how you
+  play, as the Privacy Policy explains. Each product's price is the same for
+  everyone.
 
 ## 4. Ads
 
```

## 3. `adergames-site` (`content/legal.ts`, `content/terms.ts`)

El mismo cambio en el sitio, como diff propuesto contra `main` = `658df9f` del repo
`/Users/manuader/Desktop/projects/adergames-site` (sin aplicar; quien aplique lo hace en una rama local sin pushear y
el push es del dueño). La sección nueva va como `a-tu-medida` / `tailored`, entre `estadisticas` / `usage-stats` y
`compras` / `purchases`, con el mismo texto que el `.md` (el sitio no corta líneas). Los dos archivos se comprobaron
con `node --experimental-strip-types` (importan bien; 13 secciones en cada idioma, en orden).

```diff
--- a/content/legal.ts
+++ b/content/legal.ts
@@ -9,7 +9,7 @@
 export const privacyES: LegalDoc = {
   title: "Política de Privacidad — FisuEvolution",
   updated: "octubre de 2026",
-  summary: "Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La publicidad procesa algunos datos, el ranking guarda un identificador anónimo y el nombre que vos elegís, y el juego nos manda estadísticas de uso, con un identificador al azar propio de ellas, para saber cómo se juega y cuánto rinden los anuncios. Abajo está exactamente cuáles y cómo los controlás.",
+  summary: "Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La publicidad procesa algunos datos, el ranking guarda un identificador anónimo y el nombre que vos elegís, y el juego nos manda estadísticas de uso, con un identificador al azar propio de ellas, para saber cómo se juega y cuánto rinden los anuncios. Con datos del propio juego, tu teléfono también puede adaptar ayudas opcionales y ofertas, sin tocar los precios ni empeorar el juego. Abajo está exactamente cuáles y cómo los controlás.",
   sections: [
     { id: "no-hacemos", title: "Lo que NO hacemos", blocks: [
       { list: [
@@ -61,7 +61,8 @@
     { id: "estadisticas", title: "Estadísticas de uso", blocks: [
       { p: "Para entender cómo se juega y cuánto rinde cada anuncio, el juego le manda a nuestro servidor mensajes cortos sobre lo que pasa en la partida. Cada uno lleva:" },
       { list: [
-        "**Qué pasó:** que empezó o terminó una sesión de juego (cuánto duró y cuántas sesiones llevás); que se vio un anuncio (de qué tipo, en qué lugar del juego, qué red lo sirvió y cuánto pagó por esa vista, en su moneda); qué pasó con una oferta de video (si apareció, si la tocaste, si te ganaste el premio, si no había video o si la dejaste pasar); qué producto compraste (sólo cuál: ni el precio ni los datos de la compra); y cuántas veces reencarnaste.",
+        "**Qué pasó:** que empezó o terminó una sesión de juego (cuánto duró y cuántas sesiones llevás) y, al terminar, hasta qué personaje llegaste en esta vida, cuántos minutos jugaste en total y cuántas veces reencarnaste; que se vio un anuncio (de qué tipo, en qué lugar del juego, qué red lo sirvió y cuánto pagó por esa vista, en su moneda); qué pasó con una oferta de video (si apareció, si la tocaste, si te ganaste el premio, si no había video o si la dejaste pasar) y, si apareció por algo que te pasaba en la partida, qué fue (por ejemplo, el piso lleno); qué producto compraste (sólo cuál: ni el precio ni los datos de la compra); y cuántas veces reencarnaste.",
+        "**Lo de la personalización:** el grupo en que te ubicó tu teléfono y con qué versión de las reglas, y, si estamos probando dos formas de calcularlo, cuál te tocó. Se explica en la sección siguiente.",
         "**Datos técnicos:** la versión del juego y de iOS, el modelo de tu iPhone o iPad (por ejemplo, \"iPhone16,2\") y el país de tu App Store.",
         "**Un identificador al azar, propio de estas estadísticas.** No es el del ranking ni se comparte con él, y no está ligado a tu nombre, a tu cuenta de Apple ni a tu identificador de publicidad. Sigue siendo el mismo si reinstalás el juego en el mismo dispositivo y no pasa a tus otros dispositivos (ni por iCloud ni al restaurar una copia de seguridad en otro teléfono). Además, un identificador de sesión nuevo cada vez que abrís el juego y la hora de tu teléfono.",
       ]},
@@ -70,14 +71,27 @@
       { p: "Las estadísticas se guardan en Supabase por cuenta nuestra y **se borran solas a los 400 días** (un año y un mes, para comparar cada mes con el mismo del año anterior). Si estás sin conexión, esperan en tu dispositivo —como mucho, las últimas 1.000 y hasta un mes— hasta que haya red." },
       { p: "**Cómo se apagan.** En la Unión Europea, el Reino Unido y Suiza se mandan sólo si en el formulario de consentimiento de Google aceptaste que se guarde información en tu dispositivo y que se use para medir, hacer estadísticas y mejorar el servicio. Podés cambiar tu elección cuando quieras en **Ajustes → Opciones de privacidad**: si la retirás, dejan de mandarse y lo que estaba esperando en tu dispositivo se borra sin salir de él. Fuera de la UE, el Reino Unido y Suiza el juego no tiene un interruptor para esto; las Opciones de privacidad, donde aparezcan, controlan los anuncios. No dependen del permiso de seguimiento de iOS (App Tracking Transparency) porque no son seguimiento: no se cruzan con datos de otras empresas." },
     ]},
+    { id: "a-tu-medida", title: "Ayudas y ofertas a tu medida", blocks: [
+      { p: "Algunas ayudas opcionales y algunas ofertas del juego se adaptan a cada jugador. Para eso, **tu teléfono** estima cuánto rinde tu partida para nosotros, con datos del propio juego: el país de tu App Store, el modelo de tu iPhone o iPad, cuántos videos con premio viste y cuánto pagaron, si compraste algo, y cuántas sesiones jugaste y cuánto duraron en la última semana. Con eso te ubica en uno de tres grupos. El cálculo se hace en el teléfono: a nuestro servidor no le llega el valor estimado, sólo el grupo." },
+      { p: "Según el grupo, puede cambiar:" },
+      { list: [
+        "**Las ayudas opcionales:** cuánto paga un video con premio, cada cuánto cae el colchón de regalo o llega un visitante, cuánto esperan las ayudas del costado, y que aparezcan menos anuncios solos.",
+        "**Las ofertas de video en el momento justo:** por ejemplo, con el piso lleno, una oferta que dice exactamente qué te da si mirás un video. La elegís vos y siempre podés decir que no.",
+        "**Qué te destacamos en la Tienda y algunas ofertas por tiempo limitado:** por ejemplo, el pack de bienvenida aparece sólo si todavía no compraste nada. Ningún producto se esconde de la Tienda. En la Unión Europea, esas ofertas llevan el aviso \"Oferta elegida para vos\".",
+      ]},
+      { p: "Lo que **no** cambia nunca: **el precio** de cada producto, que es el mismo para todos (lo fija la App Store), y el juego en sí: un grupo sólo puede sumar ayudas, nunca sacarlas ni hacer el juego más lento. Nada de esto depende de que aceptes el seguimiento de iOS (App Tracking Transparency)." },
+      { p: "**Qué nos llega.** El grupo en que quedaste, con la versión de las reglas que lo decidió, y, si estamos probando dos formas de calcularlo, cuál te tocó. Viaja con las estadísticas de uso de la sección anterior, con su mismo identificador, su mismo consentimiento y sus mismos 400 días. Lo usamos para saber si las ayudas sirven y para mejorar el cálculo; no lo usamos para mostrarte publicidad ni se lo pasamos a nadie. Para adaptar el juego, el teléfono además baja de nuestro servidor las reglas de la personalización: ese pedido no manda ningún dato tuyo, pero, como cualquier pedido web, Supabase ve la dirección IP desde la que se hace." },
+      { p: "**Qué queda en tu teléfono.** El último cálculo y tus últimas sesiones, fuera de tu partida guardada. No salen de ahí." },
+      { p: "**Cómo se apaga.** En la Unión Europea, el Reino Unido y Suiza funciona sólo si en el formulario de consentimiento de Google aceptaste, además de lo de las estadísticas, que se arme un perfil para personalizar el contenido y que se use para elegirlo. Si no lo aceptaste, o si lo retirás en **Ajustes → Opciones de privacidad**, el juego vuelve a ser el mismo para todos y el grupo deja de mandarse; el último cálculo queda en tu teléfono, sin usarse. Fuera de la UE, el Reino Unido y Suiza el juego no tiene un interruptor propio para esto. Y si el formulario de Google indica que sos menor de edad, la personalización no se aplica." },
+    ]},
     { id: "compras", title: "Compras dentro de la app", blocks: [
-      { p: "Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni de tu método de pago — sólo recibimos de Apple la confirmación de qué compraste, para entregártelo. Qué producto compraste (sin el precio) también va en las estadísticas de uso." },
+      { p: "Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni de tu método de pago — sólo recibimos de Apple la confirmación de qué compraste, para entregártelo. Qué producto compraste (sin el precio) también va en las estadísticas de uso. El precio de cada producto es el mismo para todos; lo que puede cambiar es qué te destacamos (ver «Ayudas y ofertas a tu medida»)." },
     ]},
     { id: "progreso", title: "Tu progreso de juego", blocks: [
       { p: "Se guarda **en tu dispositivo**. Si en alguna versión futura activamos el guardado en iCloud, iría a **tu** base de datos privada de iCloud, a la que no tenemos acceso, y lo diríamos acá antes de hacerlo." },
     ]},
     { id: "menores", title: "Menores", blocks: [
-      { p: "El juego tiene clasificación 12+ y no está dirigido a menores de 13 años. No recolectamos a sabiendas datos de menores de esa edad." },
+      { p: "El juego tiene clasificación 12+ y no está dirigido a menores de 13 años. No recolectamos a sabiendas datos de menores de esa edad. No te pedimos la edad; si el formulario de consentimiento de Google indica que sos menor, las ayudas y ofertas a tu medida no se aplican." },
     ]},
     { id: "contacto", title: "Contacto", blocks: [
       { p: "Cualquier consulta sobre privacidad: {SUPPORT_EMAIL}" },
@@ -88,7 +102,7 @@
 export const privacyEN: LegalDoc = {
   title: "Privacy Policy — HoboEvolution",
   updated: "October 2026",
-  summary: "Honest summary: we have no accounts and ask for no personal data. The ads process some data, the leaderboard stores an anonymous identifier and the name you choose, and the game sends us usage statistics, under a random identifier of their own, to see how it is played and what the ads earn. Below is exactly which and how you control them.",
+  summary: "Honest summary: we have no accounts and ask for no personal data. The ads process some data, the leaderboard stores an anonymous identifier and the name you choose, and the game sends us usage statistics, under a random identifier of their own, to see how it is played and what the ads earn. Using in-game data, your phone may also tailor optional help and offers, without touching prices or making the game worse. Below is exactly which and how you control them.",
   sections: [
     { id: "dont", title: "What we do NOT do", blocks: [
       { list: [
@@ -140,7 +154,8 @@
     { id: "usage-stats", title: "Usage statistics", blocks: [
       { p: "To understand how the game is played and what each ad earns, the game sends our server short messages about what happens in play. Each one carries:" },
       { list: [
-        "**What happened:** a play session started or ended (how long it lasted and how many sessions you've played); an ad was shown (its format, the place in the game, the network that served it and what it paid for that view, in its currency); what happened to a rewarded-video offer (shown, tapped, rewarded, no video available, or passed); which product you bought (only which one: never the price or payment details); and how many times you reincarnated.",
+        "**What happened:** a play session started or ended (how long it lasted and how many sessions you've played) and, at the end, the highest character reached in this life, your total minutes played and how many times you reincarnated; an ad was shown (its format, the place in the game, the network that served it and what it paid for that view, in its currency); what happened to a rewarded-video offer (shown, tapped, rewarded, no video available, or passed) and, if it appeared because of something in your game, what it was (e.g. a full floor); which product you bought (only which one: never the price or payment details); and how many times you reincarnated.",
+        "**Personalization:** the group your phone placed you in and the rules version, and, if we are testing two ways to compute it, which one you got. Explained in the next section.",
         "**Technical data:** the app and iOS version, your iPhone or iPad model (e.g. \"iPhone16,2\") and your App Store country.",
         "**A random identifier of their own.** It is not the leaderboard's and is not shared with it, and it is not tied to your name, your Apple account or your advertising identifier. It stays the same if you reinstall on the same device and never moves to your other devices (not through iCloud, and not by restoring a backup to another phone). Plus a new session identifier each time you open the game, and your phone's time.",
       ]},
@@ -149,14 +164,27 @@
       { p: "The statistics are stored on Supabase on our behalf and **deleted automatically after 400 days** (a year and a month, to compare each month with the same one a year earlier). While you are offline they wait on your device — at most the latest 1,000, for up to a month — until there is a connection." },
       { p: "**How to turn them off.** In the EU, the UK and Switzerland they are sent only if, in Google's consent form, you agreed to storing information on your device and to using it for measurement, statistics and improving the service. You can change your choice any time in **Settings → Privacy options**: withdraw it and they stop, and whatever was waiting on your device is deleted without leaving it. Outside the EU, the UK and Switzerland the game has no switch for this; Privacy options, where they appear, control the ads. They don't depend on iOS App Tracking Transparency because they are not tracking: they are never combined with other companies' data." },
     ]},
+    { id: "tailored", title: "Help and offers tailored to you", blocks: [
+      { p: "Some optional help and some offers in the game are tailored to each player. To do that, **your phone** estimates what your game is worth to us, using in-game data only: your App Store country, your iPhone or iPad model, how many rewarded videos you watched and what they paid, whether you bought anything, and how many sessions you played and how long they lasted in the last week. With that it places you in one of three groups. The estimate is computed on the phone: our server never receives it, only the group." },
+      { p: "Depending on the group, this may change:" },
+      { list: [
+        "**Optional help:** how much a rewarded video pays, how often the free Mattress drops or a visitor arrives, how long the side-column helpers wait, and fewer ads appearing on their own.",
+        "**Rewarded-video offers at the right moment:** for example, with a full floor, an offer that says exactly what you get if you watch a video. It is your choice and you can always say no.",
+        "**What the Store highlights for you, and some limited-time offers:** for example, the welcome pack appears only if you haven't bought anything yet. No product is ever hidden from the Store. In the EU, those offers are marked \"Offer picked for you\".",
+      ]},
+      { p: "What **never** changes: **each product's price**, which is the same for everyone (set by the App Store), and the game itself: a group can only add help, never take it away or slow the game down. None of this depends on accepting iOS App Tracking Transparency." },
+      { p: "**What reaches us.** The group you were placed in, with the rules version that decided it, and, if we are testing two ways to compute it, which one you got. It travels with the usage statistics in the previous section, under the same identifier, the same consent and the same 400 days. We use it to see whether the help works and to improve the estimate; we never use it to show you ads and never share it. To tailor the game, the phone also downloads the personalization rules from our server: that request sends none of your data, but, like any web request, Supabase sees the IP address it comes from." },
+      { p: "**What stays on your phone.** The latest estimate and your recent sessions, outside your saved game. They never leave it." },
+      { p: "**How to turn it off.** In the EU, the UK and Switzerland it works only if, in Google's consent form, you also agreed to building a profile to personalize content and to using it to choose that content. If you didn't, or you withdraw it in **Settings → Privacy options**, the game goes back to being the same for everyone and the group stops being sent; the latest estimate stays on your phone, unused. Outside the EU, the UK and Switzerland the game has no separate switch for this. And if Google's consent form flags you as a minor, nothing is tailored." },
+    ]},
     { id: "purchases", title: "In-app purchases", blocks: [
-      { p: "Handled by **Apple**. We never see or store your card or payment details — Apple only tells us what you bought, so we can deliver it. Which product you bought (without the price) is also part of the usage statistics." },
+      { p: "Handled by **Apple**. We never see or store your card or payment details — Apple only tells us what you bought, so we can deliver it. Which product you bought (without the price) is also part of the usage statistics. Each product's price is the same for everyone; what may change is what we highlight for you (see \"Help and offers tailored to you\")." },
     ]},
     { id: "progress", title: "Your game progress", blocks: [
       { p: "It stays **on your device**. If a future version enables iCloud saving, it would go to **your** private iCloud database, which we cannot access, and we would say so here before doing it." },
     ]},
     { id: "minors", title: "Minors", blocks: [
-      { p: "The game is rated 12+ and is not directed at children under 13. We do not knowingly collect data from children under that age." },
+      { p: "The game is rated 12+ and is not directed at children under 13. We do not knowingly collect data from children under that age. We never ask your age; if Google's consent form flags you as a minor, nothing is tailored to you." },
     ]},
     { id: "contact", title: "Contact", blocks: [
       { p: "Any privacy question: {SUPPORT_EMAIL}" },
```

```diff
--- a/content/terms.ts
+++ b/content/terms.ts
@@ -25,6 +25,7 @@
         "**El progreso se puede perder.** Tu partida vive en tu dispositivo y, si activás iCloud, en tu base privada de iCloud. No guardamos copias de tu partida: lo que sale de tu dispositivo es, si entrás al ranking, tu nombre y tus tiempos de partida (con un identificador anónimo), que se guardan en Supabase (el nombre lo revisa un modelo de Anthropic para filtrar insultos), y las estadísticas de uso que explica la Política de Privacidad, con las que no se puede rearmar tu partida. Si borrás la app, perdés el dispositivo o desactivás iCloud, el progreso —incluidos objetos comprados que ya se consumieron— puede perderse y no podemos recuperarlo.",
         "**Reencarnar reinicia cosas a propósito.** Reencarnar (prestigio) borra parte de tu progreso a cambio de dólares blue y multiplicadores permanentes. Es una mecánica del juego, está avisada en pantalla antes de confirmar, y no da derecho a reembolso.",
         "**Precios y catálogo pueden cambiar.** Podemos agregar, sacar o cambiar el precio de los productos, y podemos ajustar el balance del Juego (costos, ganancias, recompensas) en cualquier momento. Los cambios de balance no dan derecho a reembolso de compras anteriores.",
+        "**Ofertas a tu medida, precios iguales.** Algunas ayudas opcionales y ofertas del Juego, incluido qué te destaca la Tienda, se eligen según cómo jugás, como explica la Política de Privacidad. El precio de cada producto es el mismo para todos.",
       ]},
     ]},
     { id: "anuncios", title: "4. Anuncios", blocks: [
@@ -97,6 +98,7 @@
         "**Progress can be lost.** Your save lives on your device and, if you enable iCloud, in your private iCloud database. We keep no copy of your game: what leaves your device is, if you join the leaderboard, your name and run times (with an anonymous identifier), stored on Supabase (an Anthropic model checks the name to filter insults), and the usage statistics described in the Privacy Policy, which cannot be used to rebuild your game. If you delete the app, lose the device or turn off iCloud, your progress — including already-consumed purchased items — may be lost and we cannot recover it.",
         "**Reincarnating resets things on purpose.** Reincarnating (prestige) wipes part of your progress in exchange for Blue Dollars and permanent multipliers. It's a game mechanic, it is shown on screen before you confirm, and it does not entitle you to a refund.",
         "**Prices and catalogue may change.** We may add, remove or reprice products, and we may rebalance the Game (costs, earnings, rewards) at any time. Balance changes do not entitle you to a refund of past purchases.",
+        "**Tailored offers, same prices.** Some optional help and offers in the Game, including what the Store highlights for you, are chosen based on how you play, as the Privacy Policy explains. Each product's price is the same for everyone.",
       ]},
     ]},
     { id: "ads", title: "4. Ads", blocks: [
```

## 4. Etiqueta de App Privacy (App Store Connect)

**Sumar el propósito *Product Personalization* a los tipos que ya junta F0 y que alimentan el segmento.** Ningún tipo
nuevo, ningún cambio de «vinculado» ni de «tracking»: se parte de la tabla de 8 tipos de
`privacidad-e15-BORRADOR.md` §4 (la que se carga con la 2.0) y sólo cambian tres filas.

| # | Tipo de dato (ASC) | Vinculado | Tracking | Propósitos (en **negrita**, lo nuevo de la 2.1) |
|---|---|---|---|---|
| 2 | Identifiers · Device ID | Sí (por AdMob) | Sí (por AdMob) | Third-Party Advertising + App Functionality + Analytics — **sin cambio** (decisión 3) |
| 3 | Usage Data · Advertising Data | Sí (por AdMob) | Sí (por AdMob) | Third-Party Advertising + Analytics + **Product Personalization** |
| 4 | Usage Data · Product Interaction | Sí (por AdMob) | Sí (por AdMob) | Analytics + Third-Party Advertising + **Product Personalization** |
| 6 | Purchases · Purchase History | No | No | Analytics + **Product Personalization** |

Cómo leerla:

- **Por qué esas tres:** son las que entran en `PlayerValueInputs` (ledger de anuncios → Advertising Data; sesiones,
  videos y ofertas vistas → Product Interaction; si compró → Purchase History) y, a la vez, las que la telemetría
  junta y con las que F6 entrena el modelo. País de la tienda y modelo del aparato no son tipos declarables nuevos (ya
  razonado en F0 §4: el país de la tienda no es una ubicación; el modelo es contexto técnico).
- **Product Personalization no es tracking** («customizing what the user sees… within your app»): no se cruza con
  datos de otras empresas. Las filas 3 y 4 ya figuran con tracking **por AdMob**, no por esto.
- **El resumen de la ficha no cambia:** los tres tipos ya están en las secciones donde estaban.
- **Cuándo se carga:** el formulario pide declarar lo que recolecta **esta versión**. El binario de la 2.1 **puede**
  personalizar (el código está, el interruptor es remoto), así que el propósito se declara con el envío de la 2.1,
  aunque salga apagado, igual que el manifiesto. Lo hace **el dueño en el panel** (App Store Connect → la app → **App
  Privacy** → editar las filas 3, 4 y 6 → **Publish**); `release-ops` no lo soporta.
- Tiene que coincidir con el bloque 1 y con `PrivacyInfo.xcprivacy` (abajo, ya hecho).

## 5. Nota a App Review (`release.json → store.reviewNotes`)

Una línea, después de la del servidor. El texto vigente tiene **3.949** caracteres; con la línea (+98) serían 4.047,
sobre el tope de **4.000**. Con el recorte queda en **3.994**, todo ASCII (contado con `python3` sobre
`release.json` de la base):

| Reemplazar | Por | Δ |
|---|---|---|
| `Our only server (Supabase): the optional leaderboard and pseudonymous analytics (own random ID; no IDFA, no tracking).` | `Our only server (Supabase): the optional leaderboard and pseudonymous analytics (own random ID; no IDFA, no tracking). Optional help and offers adapt on the device; prices and the base game are the same for everyone.` | +98 |
| `the free Mattress that drops on the board every 30 minutes` | `the free Mattress that drops every 30 minutes` | −13 |
| `and the weekly Puntero's March, a 1-hour tap challenge)` | `and the weekly Puntero's March tap challenge)` | −10 |
| `Google's UMP consent form is shown before any ad, and Settings > Privacy options lets the player change it.` | `Google's UMP consent form is shown before any ad; Settings > Privacy options changes it.` | −19 |
| `bottom-bar tabs appear one by one as you play` | `tabs appear one by one as you play` | −11 |

La oración nueva, sola:

> Optional help and offers adapt on the device; prices and the base game are the same for everyone.

Ningún recorte saca algo que el revisor necesite para probar. **Cuándo:** con el envío de la 2.1 aunque el interruptor
salga apagado (el revisor ve la 2.0 de hecho, y la nota describe el binario). Se aplica en `release.json` y se sube con
`releaseops asc listing apply`, que muestra el conteo antes de aplicar.

## 6. Para el abogado (V21-F1-T9)

Listas para mandar. Contexto común, para pegar arriba del mail:

> Juego para iOS (FisuEvolution / HoboEvolution), 12+, gratis con anuncios (Google AdMob + Unity Ads por mediación)
> y compras dentro de la app. Sin cuentas. Desarrollador individual en Argentina. Servidor propio en Supabase (región
> del proyecto: a confirmar en el panel). Ya junta estadísticas de uso seudónimas (id al azar propio, sin IDFA) con
> consentimiento TCF {1, 8, 9, 10} en la UE/RU/Suiza. La 2.1 agrega: el teléfono calcula, con datos del propio juego
> (país de la tienda, modelo del aparato, anuncios con premio vistos y cuánto pagaron, si compró, sesiones de la última
> semana), un grupo de tres (bajo, medio, alto); según el grupo, **más** ayudas opcionales (premios por video más
> grandes, regalos más seguidos, menos anuncios forzados), ofertas de video opt-in en momentos de necesidad, y en la
> Tienda un producto destacado y ofertas de 24 h para no compradores. **Nunca cambia el precio** de un producto (los
> fija Apple por tier) y **nunca empeora** el juego base. Al servidor sólo sube el grupo (no el valor estimado), con el
> id seudónimo de las estadísticas. En la UE/RU/Suiza exige TCF {1, 5, 6, 8, 9, 10}; fuera, no hay interruptor. No se
> pide edad; con la señal de menor del SDK, nada se personaliza. Hoy está **apagado** por un interruptor remoto hasta su
> revisión. Adjunto: la política propuesta (bloque 1) y los términos (bloque 2).

1. **TCF {1, 5, 6, 8, 9, 10} (V9).** ¿Alcanzan para perfilar y personalizar contenido propio del juego (no publicidad)
   en la UE, el Reino Unido y Suiza? ¿Sobra alguno, o falta (p. ej. 3/4 si se considera publicidad propia, o un
   propósito del editor con `IABTCF_PublisherConsent`)? ¿Hay que guardar prueba del consentimiento más allá de lo que
   guarda UMP?
2. **App Store 5.1.1(ii) y 5.1.2(ii).** ¿Las ayudas extra de un grupo cuentan como un beneficio atado a dar datos (no
   se puede condicionar)? Con consentimiento denegado el jugador queda en la base (la 2.0), no peor. ¿Hace falta un
   interruptor propio **fuera** de la UE/RU/Suiza (decisión 1, P9), dado que allí hoy no hay forma de retirarlo?
3. **App Store 5.1.2(iii) («no armar perfiles»).** El evento `segment` (el grupo por instalación, con el id seudónimo)
   y el entrenamiento del modelo de F6 con eventos por instalación: ¿es «armar un perfil» en el sentido de Apple? ¿Basta
   con que el cálculo sea local y suba sólo el grupo, o conviene no mandarlo (y medir sólo agregados)?
4. **Aviso UE (Omnibus 2019/2161, art. 6(1)(ea) de la Dir. 2011/83/UE) y prácticas desleales (Dir. 2005/29/CE).**
   El precio no cambia; cambia qué se destaca y a quién se le ofrece un pack de 24 h. ¿Hace falta el aviso
   «Oferta elegida para vos» (lo ponemos igual en la UE, V8)? ¿También en el Reino Unido y Suiza? ¿Alcanza en la hoja
   de la oferta o tiene que estar antes de la compra en otro lugar? ¿El destaque de un pack de blue «siguiente al
   último comprado» puede leerse como presión a gastar (principios de la red CPC sobre moneda virtual, 2025)?
5. **Argentina: Ley 24.240 y Ley 25.326.** ¿El id seudónimo con país y modelo es «dato personal»? ¿Hace falta registrar
   la base ante la AAIP? ¿La transferencia internacional a Supabase (región a confirmar) necesita cláusulas o
   consentimiento específico? ¿El texto cumple «información cierta, clara y detallada» sobre las ofertas a medida?
6. **Menores en un 12+ sin pedir edad (V10, COPPA).** ¿Alcanza con no personalizar ante la señal de menor del SDK y no
   pedir edad? ¿Conviene apagar la personalización para todos en algún storefront?
7. **Retención y borrado (decisión 2).** Al retirar el consentimiento, ¿hay que borrar el cálculo local guardado
   (`personalization.json`)? ¿Los 400 días de las estadísticas valen también para el grupo?
8. **La redacción.** ¿El bloque 1 y la línea de términos (bloque 2) alcanzan como información previa, o hace falta un
   aviso en el juego la primera vez que una ayuda o una oferta es «a tu medida»?

**Listo cuando:** el dueño anota el resultado en `DUENO.md`; si algo cambia, va como tarea nueva (en la mayoría de
los casos una constante y su test: consentimiento, aviso, evento, borrado).

---

## Lo que ya quedó hecho en esta tarea (no es borrador)

- `FisuEvolution/Resources/PrivacyInfo.xcprivacy`: suma `NSPrivacyCollectedDataTypePurposeProductPersonalization` a
  `ProductInteraction`, `AdvertisingData` y `PurchaseHistory` (siguen no vinculados, sin tracking). Device ID y Other
  User Content no cambian. `NSPrivacyTracking` sigue en `false` (B22). Dice la verdad del binario aunque el
  interruptor esté apagado, como en F0. La personalización no usa APIs de razón requerida nuevas (`personalization.json`
  en Application Support y la caché en `Caches`, como la telemetría).
- `FisuEvolutionTests/PrivacyManifestTests.swift`: los propósitos exactos por tipo con Product Personalization y un
  test nuevo («la personalización declara su propósito sin volverse seguimiento»). Escritos sin correr: los corre la
  verificación de la fase.
