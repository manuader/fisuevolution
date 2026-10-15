# BORRADOR — PARA APROBAR POR EL DUEÑO (🔒 O1)

> **Nada de este archivo está aplicado.** Son los textos de privacidad de E15 F0 (las estadísticas de uso) para que el
> dueño los apruebe, corrija o rechace. Hasta su OK no se toca `privacy.md`, `terms.md` ni `adergames-site`: eso lo
> hace E15-T9 copiando **tal cual** lo aprobado. El interruptor de la telemetría (🔒 O6) no se prende hasta que esta
> política esté publicada y dentro de un binario de la tienda.

Plan: `Docs/superpowers/plans/2026-10-15-v2-e15-f0-valor-por-jugador.md` (E15-T7). Escrito el 2026-10-15 contra lo
que el código realmente junta:

- **Servidor (T4, `37ff5f26`):** `supabase/migrations/20261015000001_telemetry_schema.sql` — tabla
  `public.telemetry_events` (columnas de C4, `props` con claves cerradas por evento, ≤ 2 KB), sólo-insertar para
  `anon`, interruptor `settings.telemetry_enabled = false`, borrado a los **400 días** (cron diario). La tabla **no
  guarda la IP**; los logs del gateway/PostgREST de Supabase **sí** la registran durante su retención
  (`supabase/README.md`, «Telemetría»).
- **Cliente (T5, `a7a6dff2` + `cf42ebbb`):** `FisuEvolution/Managers/Telemetry/` — seis eventos (`session_start`,
  `session_end`, `ad_impression`, `offer`, `purchase`, `prestige`), **un id propio de la telemetría** (otro UUID al
  azar, distinto del `installId` del ranking: Keychain `com.adergames.fisu.telemetry`, sólo de este dispositivo y no
  sincronizable, sobrevive a reinstalar), un `session_id` nuevo por sesión, versión de app/iOS, modelo de máquina,
  país de la tienda. Cola offline de hasta **1.000** eventos en Application Support; lo que tiene la hora corrida más
  de 29 días no sale (en la práctica, esperan hasta un mes). Con la compuerta cerrada descarta (no encola) y, sin
  consentimiento (`TelemetryConsent`, ver decisión 1), vacía la cola; ni siquiera pregunta el interruptor.

## Antes de aprobar: lo que decide el dueño

1. **Opción A — integrada en T5 (`cf42ebbb`, default del controlador).** `ConsentInformation.shared.canRequestAds`
   solo no alcanza: según el header del SDK resuelto (`UMPConsentInformation.h`: *«Indicates whether the SDK has
   gathered consent aligned with the app's configured messages»*) es «el formulario ya se completó», **no** «el
   jugador aceptó»; un jugador europeo que rechaza todo también da `canRequestAds == true`. Lo implementado:
   - **Dónde:** `TelemetryConsent` (`FisuEvolution/Managers/Telemetry/TelemetryConsent.swift`), llamado **dentro**
     del closure `canRequestAds` de `TelemetryService.live(config:)`. Al estar en la compuerta, retirar el
     consentimiento la cierra y `localGateAllows` **vacía la cola** igual que sin UMP: lo juntado no sale nunca.
   - **La regla, que falla cerrada:** (1) si UMP dice que no puede pedir anuncios → no; (2) si
     `IABTCF_gdprApplies == 1` → exige en `IABTCF_PurposeConsents` los propósitos TCF v2.2 **1** (guardar o leer
     información del dispositivo: el id vive en el Keychain), **8** (medir el rendimiento del contenido), **9**
     (entender a la audiencia con estadísticas) y **10** (desarrollar y mejorar los servicios), los cuatro a la vez;
     (3) con `IABTCF_gdprApplies == 0` alcanza con UMP; (4) **sin la clave**, pasa sólo si UMP informa que la región
     no requiere consentimiento (`consentStatus == .notRequired`); (5) cualquier otro valor, o algo ilegible → no.
   - **Por qué esos cuatro:** describen lo que hace la telemetría (guardar el id, medir sesiones y ofertas,
     estadísticas por país y modelo, mejorar el juego); ante la duda, el conjunto más estricto. Se lee el
     consentimiento por propósito porque es lo que deja UMP; si algún día el mensaje configura propósitos propios del
     editor, `IABTCF_PublisherConsent` sería la señal más exacta (un cambio chico en `TelemetryConsent`).
   - **Tests:** `FisuEvolutionTests/TelemetryConsentTests.swift` (sin GDPR, GDPR con y sin los propósitos, clave
     ausente, valores raros, y el propósito retirado → la cola se vacía); escritos sin correr, los corre T8.
   - **🔒 Precondición de O6** (el interruptor no se prende sin esto): el **mensaje RGPD de UMP publicado en AdMob**
     (Privacidad y mensajes → RGPD) y verificado en un build DEBUG con `--telemetry-debug`: con `debugGeography`
     **EEA** (`--debug-consent-eea`, `AdsConsent.debugSettings`) aparece el formulario, aceptar todo deja pasar la
     telemetría y rechazar (o desmarcar 8, 9 o 10 en «Gestionar opciones») la cierra y vacía la cola; **fuera de la
     EEA** (sin el argumento) no aparece el formulario RGPD y la telemetría pasa. Confirmar además en AdMob que el
     mensaje RGPD cubre **Suiza** y el Reino Unido: `debugGeography` sólo simula la EEA.
   - **Si A no está integrada** cuando T9 aplique los textos, T9 copia la **variante B** en vez del párrafo «Cómo se
     apagan» (es y en, `.md` y sitio): *«En la Unión Europea, el Reino Unido y Suiza se mandan sólo después de que
     respondiste el formulario de consentimiento de Google»*, sin «si la retirás, dejan de mandarse…». Es verdad,
     pero en Europa es flojo, y sin A la telemetría no debería prenderse allá (leer un id del Keychain para analítica
     es justamente lo que pide consentimiento según ePrivacy).
   Fuera de la UE, el Reino Unido y Suiza no hay interruptor en el juego (Dudas 2 del plan: sin fila nueva en Ajustes
   en F0); el texto lo dice así, y aclara que las Opciones de privacidad, donde aparecen, controlan los anuncios.
2. **El identificador — resuelta por default: un id aparte** (decisión del controlador; el dueño puede cambiarla al
   aprobar O1). La telemetría ya no usa el `installId` del ranking: tiene su propio UUID al azar en el Keychain
   (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no sincronizable), leído una sola vez y fuera del main actor.
   En la base, `telemetry_events.install_id` y `players` del ranking ya no comparten valor, así que un evento no se
   puede unir con un nombre por el id. El texto dice que el identificador es al azar, propio de estas estadísticas y
   no compartido con el ranking ni con tu nombre, y **no** las llama «anónimas» (un id estable las hace seudónimas
   en sentido RGPD). La etiqueta de ASC y el manifiesto no cambian de tipo: sigue siendo «Identifiers · Device ID»,
   no vinculado, que el ranking ya declaraba; la telemetría le suma Analytics. Si el dueño prefiere el mismo id, hay
   que revertir esa parte de T5 y volver a la redacción anterior («el mismo identificador… no lo cruzamos»).
3. **Cuántos días guarda la IP Supabase.** El texto dice «unos pocos días». Depende del plan del proyecto: según la
   documentación de Supabase (a confirmar en el panel), la retención de logs es 1 día en Free y 7 en Pro (28 en
   Team). Si el proyecto está o pasa a Team o más, cambiar «unos pocos días» por el número. Lo mismo vale, de rebote,
   para el ranking (que ya pasaba por Supabase y la política no lo decía): el texto nuevo lo cubre.

Lo que ya se dijo antes y se mantiene coherente: la política vigente dice que, al bajar `/config/ads.json`, «como
cualquier pedido web, el proveedor del sitio (Vercel) ve la dirección IP»; la telemetría usa la misma fórmula para
Supabase. La política vigente **no** decía nada de la IP en el ranking (E12): este borrador lo corrige para los dos.

---

## 1. `privacy.md` (es y en)

Va **idéntico, byte a byte**, en `Distribution/site/privacy.md` y `FisuEvolution/Resources/Legal/privacy.md`
(`SettingsPersistenceTests.bundledCopyMatchesTheSourceOfTruth`). Qué cambia respecto de la versión actual:

- **El resumen** (sigue siendo UN párrafo): suma «el juego nos manda estadísticas de uso, con un identificador al
  azar propio de ellas…».
- **Lo que NO hacemos:** el servidor propio ya no es «sólo el del ranking».
- **El cierre del ranking:** ya no es «el único dato tuyo que sale del dispositivo».
- **Sección nueva «Estadísticas de uso»** (antes de «Compras»): qué se junta (C4, en palabras de jugador, con
  cuántas sesiones llevás), el id propio (al azar, no compartido con el ranking ni con tu nombre, no pasa a tus otros
  dispositivos), qué **no** (IDFA, IDFV, nombre del ranking, texto, cuenta de Apple, pago), para qué (cómo se juega y
  cuánto rinde cada anuncio), que no se cruza con la identidad, no se usa para publicidad ni seguimiento, no se
  comparte ni se vende; la IP en los logs de Supabase (corrección 1 del despacho); dónde (Supabase) y cuánto (400
  días; sin red, hasta 1.000 eventos y hasta un mes); cómo se apaga (UMP en la UE/RU/Suiza, ver decisión 1; fuera de
  ahí no hay interruptor y las Opciones de privacidad controlan los anuncios) y por qué no depende de ATT. No dice
  «anónimas»: son seudónimas (decisión 2).
- **Compras:** el producto (sin precio) también va en las estadísticas.
- **La nota de mantenimiento** (no se le muestra al jugador): punto 3 sobre el manifiesto y la etiqueta.
- **La mitad inglesa sigue siendo UN párrafo** (lo exige `SettingsPersistenceTests`): cambia la primera oración
  («We don't collect your data» ya no es verdad), suma lo mismo que la sección nueva y corrige «our only server is
  the leaderboard's». Sigue nombrando a Google AdMob, Unity Ads, Meta Audience Network, Supabase y Anthropic con sus
  links (`privacyNamesTheNetworksAndTheRanking`).

El archivo completo propuesto:

````markdown
# Política de Privacidad — FisuEvolution / HoboEvolution

_Última actualización: octubre de 2026_

**Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La
publicidad procesa algunos datos, el ranking guarda un identificador anónimo y
el nombre que vos elegís, y el juego nos manda estadísticas de uso, con un
identificador al azar propio de ellas, para saber cómo se juega y cuánto rinden
los anuncios. Abajo está exactamente cuáles y cómo los controlás.**

## Lo que NO hacemos

- **No tenemos cuentas ni registro.** No pedimos tu email, tu nombre ni ningún
  dato personal para jugar.
- **No tenemos analytics de terceros.** Tu progreso se guarda en tu
  dispositivo. Tenemos un solo servidor propio, alojado en Supabase: guarda el
  ranking y las estadísticas de uso, que se explican más abajo.
- **No vendemos datos** a nadie.

## Publicidad

FisuEvolution **muestra publicidad a través de Google AdMob**. Hay dos tipos:

- **Videos con recompensa**, que mirás sólo si querés: los ofrecemos a cambio de
  premios dentro del juego (duplicar tus ganancias, abrir otro cofre, activar un
  boost). Nunca se reproducen solos.
- **Anuncios que aparecen solos**: los de pantalla completa entre partes del
  juego, la pausa publicitaria (que siempre podés rechazar) y el que aparece al
  volver a la app. La compra **"Sin anuncios"** los elimina; los videos con
  recompensa siguen disponibles, porque son opcionales y entregan premios.

### Quiénes procesan tus datos por los anuncios

Para mostrarlos, **Google AdMob procesa datos de tu dispositivo** —incluido tu
identificador de publicidad (IDFA), la dirección IP y datos técnicos y de uso—
según su propia política de privacidad:
<https://policies.google.com/privacy>.

AdMob también hace competir por cada anuncio a otras redes publicitarias
(mediación, por puja o *bidding*). En esta versión son dos, y cada una procesa
datos de tu dispositivo —el identificador de publicidad, la IP y datos técnicos
y de uso— según su propia política:

- **Unity Ads** (Unity Technologies): <https://unity.com/legal/privacy-policy>.
- **Meta Audience Network** (Meta Platforms): <https://www.facebook.com/privacy/policy/>.

No trabajamos con otras redes. Ninguna de estas empresas recibe de nosotros tu
nombre del ranking, el identificador de tu instalación ni tus tiempos de
partida.

### Configuración de anuncios

La app baja de nuestro sitio un archivo de configuración de anuncios
(`/config/ads.json`). **No manda ningún dato tuyo**, pero como cualquier pedido
web, el proveedor del sitio (Vercel) ve la dirección IP desde la que se pide.

### Vos controlás si es personalizada

La primera vez que abrís el juego, iOS te muestra el diálogo de **App Tracking
Transparency** preguntando si permitís el seguimiento.

- **Si aceptás**, los anuncios se personalizan usando tu identificador de
  publicidad.
- **Si rechazás**, **los anuncios se siguen viendo igual, sólo que sin
  personalizar**. No perdés nada del juego.

Podés cambiar esta decisión cuando quieras en **Ajustes → Privacidad y
seguridad → Rastreo**.

En la Unión Europea, el Reino Unido y Suiza, además te mostramos el formulario
de consentimiento de Google (UMP) antes de servir cualquier anuncio, y podés
revisar tu elección desde **Ajustes → Opciones de privacidad**.

## El ranking de la llegada a Dios

Si llegás a Dios, podés **entrar al ranking** con un nombre. Es opcional: si no
entrás, tu partida no se publica. Para que funcione guardamos en nuestro
servidor:

- **Un identificador anónimo de tu instalación**, que generamos al azar y que
  no está ligado a tu identidad, a tu cuenta de Apple ni a tu identificador de
  publicidad. Sirve para saber qué partidas son tuyas y para limitar abusos.
- **El nombre que elegiste** y tus **tiempos de partida**, que se muestran a
  los demás jugadores.

No los usamos para seguirte ni los vinculamos con tu identidad, y no los
compartimos con anunciantes. Los nombres pasan por reglas, una lista de
palabras y una revisión automática con IA antes de mostrarse; no pongas datos
personales en el nombre.

### Quién hace la revisión con IA

La revisión automática la hace **Anthropic** con su modelo **Claude**, a pedido de
nuestro servidor. Le mandamos **sólo el nombre que elegiste** (el texto, hasta
15 caracteres): no le mandamos el identificador de tu instalación, tus tiempos,
tu identificador de publicidad ni ningún dato de tu dispositivo. Anthropic la
procesa según su propia política de privacidad: <https://www.anthropic.com/legal/privacy>. Cualquier jugador puede **reportar** un nombre, y un
nombre reportado se oculta. Si bloqueás un nombre ("No ver más este nombre"),
esa decisión se guarda **sólo en tu dispositivo** y no sale de él. Si querés que
borremos tu nombre o tus partidas del ranking, escribinos al contacto de abajo
con tu nombre y lo hacemos.

Los datos del ranking viven en nuestro servidor, alojado en **Supabase**, que
los guarda por cuenta nuestra, y salen de tu dispositivo sólo si entrás al
ranking. Lo otro que nos llega son las estadísticas de uso de la
sección siguiente.

## Estadísticas de uso

Para entender cómo se juega y cuánto rinde cada anuncio, el juego le manda a
nuestro servidor mensajes cortos sobre lo que pasa en la partida. Cada uno
lleva:

- **Qué pasó:** que empezó o terminó una sesión de juego (cuánto duró y
  cuántas sesiones llevás); que se vio un anuncio (de qué tipo, en qué lugar
  del juego, qué red lo sirvió y cuánto pagó por esa vista, en su moneda); qué
  pasó con una oferta de video (si apareció, si la tocaste, si te ganaste el
  premio, si no había video o si la dejaste pasar); qué producto compraste
  (sólo cuál: ni el precio ni los datos de la compra); y cuántas veces
  reencarnaste.
- **Datos técnicos:** la versión del juego y de iOS, el modelo de tu iPhone o
  iPad (por ejemplo, "iPhone16,2") y el país de tu App Store.
- **Un identificador al azar, propio de estas estadísticas.** No es el del
  ranking ni se comparte con él, y no está ligado a tu nombre, a tu cuenta de
  Apple ni a tu identificador de publicidad. Sigue siendo el mismo si
  reinstalás el juego en el mismo dispositivo y no pasa a tus otros
  dispositivos (ni por iCloud ni al restaurar una copia de seguridad en otro
  teléfono). Además, un identificador de sesión nuevo cada vez que abrís el
  juego y la hora de tu teléfono.

Lo que **no** llevan: tu identificador de publicidad (IDFA), el identificador
de proveedor de iOS (IDFV), tu nombre del ranking, texto que hayas escrito, ni
datos de tu cuenta de Apple o de tu pago. No las cruzamos con tu nombre del
ranking ni con nada que te identifique, no las usamos para mostrarte
publicidad ni para seguirte por otras apps o sitios, no se las pasamos a las
redes de anuncios y no las vendemos.

Como cualquier pedido web, el proveedor del servidor (Supabase) ve la
dirección IP desde la que llega cada envío —del ranking o de estas
estadísticas— y la anota en sus registros técnicos por unos pocos días.
Nosotros no la guardamos junto a las estadísticas, no la usamos para
identificarte y no la cruzamos con ellas.

Las estadísticas se guardan en Supabase por cuenta nuestra y **se borran solas
a los 400 días** (un año y un mes, para comparar cada mes con el mismo del año
anterior). Si estás sin conexión, esperan en tu dispositivo —como mucho, las
últimas 1.000 y hasta un mes— hasta que haya red.

**Cómo se apagan.** En la Unión Europea, el Reino Unido y Suiza se mandan sólo
si en el formulario de consentimiento de Google aceptaste que se guarde
información en tu dispositivo y que se use para medir, hacer estadísticas y
mejorar el servicio. Podés cambiar tu elección cuando quieras en **Ajustes →
Opciones de privacidad**: si la retirás, dejan de mandarse y lo que estaba
esperando en tu dispositivo se borra sin salir de él. Fuera de la UE, el Reino
Unido y Suiza el juego no tiene un interruptor para esto; las Opciones de
privacidad, donde aparezcan, controlan los anuncios. No dependen del permiso
de seguimiento de iOS (App Tracking Transparency) porque no son seguimiento: no
se cruzan con datos de otras empresas.

## Compras dentro de la app

Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni
de tu método de pago — sólo recibimos de Apple la confirmación de qué
compraste, para entregártelo. Qué producto compraste (sin el precio) también
va en las estadísticas de uso.

## Tu progreso de juego

Se guarda **en tu dispositivo**. Si en alguna versión futura activamos el
guardado en iCloud, iría a **tu** base de datos privada de iCloud, a la que no
tenemos acceso, y lo diríamos acá antes de hacerlo.

## Menores

El juego tiene clasificación 12+ y no está dirigido a menores de 13 años. No
recolectamos a sabiendas datos de menores de esa edad.

## Contacto

Cualquier consulta sobre privacidad: **adermanu@gmail.com**

---

> ⚠️ **Nota para quien mantiene el sitio (no es parte de la política):** este
> texto es la fuente de verdad y tiene que coincidir con dos cosas o Apple lo
> marca en review —
>
> 1. **Las *nutrition labels* de App Store Connect**, que con AdMob tienen que
>    declarar "Data Used to Track You" (identificador de publicidad) y datos de
>    uso/diagnóstico vinculados a publicidad de terceros.
> 2. **`FisuEvolution/Resources/PrivacyInfo.xcprivacy`**, donde
>    `NSPrivacyTracking` está hoy en `false` a propósito: pasa a `true` sólo
>    con la lista de dominios de seguimiento (ITMS-91064), y entonces las
>    *nutrition labels* y este texto ya lo dicen.
> 3. **Las estadísticas de uso (E15)**: el manifiesto declara
>    Product Interaction, Advertising Data, Purchase History y Device ID con
>    propósito Analytics, no vinculados y sin seguimiento
>    (`PrivacyManifestTests`), y la etiqueta de App Store Connect también. El
>    interruptor de la telemetría no se prende hasta que esta versión del
>    texto esté publicada y en un binario de la tienda.
>
> ⚠️⚠️ **El mail de contacto tiene que ser uno que RECIBA.** El sitio publicado
> dice `support@adergames.io` / `contact@adergames.io`, y el 2026-09-15 se
> comprobó que **el dominio `adergames.io` no está registrado**: sin NS, sin MX,
> `whois` devuelve `Domain not found`. Todo lo que se mande ahí rebota, incluida
> la correspondencia de App Review, que es como se pierde una revisión sin
> enterarse — y un dominio libre al que la política manda pedidos de privacidad
> lo puede registrar cualquiera y leerlos. Por eso acá va el Gmail, que existe.
> Cuando `adergames.io` esté registrado y con mail andando, se cambia en los dos
> lugares a la vez (este archivo y el sitio) y se actualiza el pin de
> `SettingsPersistenceTests`.
>
> La versión anterior hablaba de los anuncios **en condicional** ("si la versión
> instalada muestra anuncios") y mencionaba iCloud y Game Center como si
> estuvieran activos — los dos están apagados por feature flag
> (`cloudKitEnabled`, `gameCenterEnabled` en `false`). Declarar de más también
> es declarar mal.

# Privacy Policy — HoboEvolution (English)

We ask for no personal data, but the ads process some, and the game sends us usage statistics under a random identifier of their own. HoboEvolution shows ads through Google AdMob: opt-in rewarded videos you choose to watch for in-game prizes, and ads that appear on their own (full-screen ads between parts of the game, an ad break you can always decline, and one when you return to the app), all removed by the "No Ads" purchase except rewarded videos, which stay since they're optional and pay out. To serve them, Google AdMob processes device data including your advertising identifier (IDFA), IP address and technical/usage data, under its own policy at https://policies.google.com/privacy. AdMob also has other ad networks bid for each ad (mediation); in this version they are Unity Ads (https://unity.com/legal/privacy-policy) and Meta Audience Network (https://www.facebook.com/privacy/policy/), and each processes the same kind of device data under its own policy. We work with no other networks, and none of them receives your leaderboard name, install identifier or run times from us. The app downloads an ads configuration file from our website; it sends none of your data, but like any web request the site's host (Vercel) sees the IP address. On first launch iOS asks for App Tracking Transparency: accept and ads are personalized, decline and **you still get ads, just non-personalized** — you lose nothing in the game, and you can change it any time in Settings → Privacy & Security → Tracking. In the EU, UK and Switzerland we also show Google's consent form (UMP) before serving any ad, and you can review your choice in Settings → Privacy options. Your game progress stays on your device. Purchases are handled by Apple; we never see your payment details. The game also sends our server small usage statistics so we can see how it is played and what each ad earns: session start and end (its length and how many sessions you've played); each ad shown (format, place in the game, the network that served it and what it paid for that view, in its currency); what happened to each rewarded-video offer (shown, tapped, rewarded, no video, or passed); which product you bought (never the price or payment details); and how many times you reincarnated. Each one carries the app and iOS version, your device model (e.g. "iPhone16,2"), your App Store country, a random identifier of their own (not the leaderboard's, not shared with it and not tied to your name; it survives reinstalling on the same device and never moves to your other devices, whether through iCloud or a backup restored to another phone), a new session identifier each time you open the game, and your phone's time. They never carry your advertising identifier (IDFA), the iOS vendor identifier (IDFV), your leaderboard name, anything you typed or your Apple account or payment data; we don't combine them with your leaderboard name or anything that identifies you, don't use them for advertising or to track you across apps or websites, don't share them with ad networks and never sell them. Like any web request, the server's host (Supabase) sees the IP address each request (leaderboard or statistics) comes from and keeps it in its technical logs for a few days; we don't store it with the statistics, don't use it to identify you and don't combine it with them. The statistics are stored on Supabase on our behalf and deleted automatically after 400 days; while you are offline they wait on your device (at most the latest 1,000, for up to a month). In the EU, UK and Switzerland they are sent only if, in Google's consent form, you agreed to storing information on your device and to using it for measurement, statistics and improving the service; you can change that any time in Settings → Privacy options: withdraw it and they stop, and whatever was waiting on your device is deleted without leaving it. Outside the EU, UK and Switzerland the game has no switch for this; Privacy options, where they appear, control the ads. They don't depend on iOS App Tracking Transparency because they are not tracking: they are never combined with other companies' data. If you reach God you may choose to enter the leaderboard with a name; it is optional, and without it your run is not published. For that we store on our server a random anonymous install identifier (not tied to your identity, your Apple account or your advertising identifier) and the name you chose plus your run times, which other players can see. We don't use them to track you, don't link them to your identity and don't share them with advertisers. The leaderboard lives on our own server, hosted on Supabase. Names go through rules, a word list and an automated AI check by Anthropic (Claude) before being shown: we send Anthropic only the name you chose (up to 15 characters), never your install identifier, run times, advertising identifier or any device data, and it processes the name under its own policy at https://www.anthropic.com/legal/privacy. So don't put personal data in your name; anyone can report a name and a reported name is hidden. If you block a name ("Hide this name"), that choice is stored only on your device and never leaves it. To have your name or runs removed, email us. We have no accounts and no third-party analytics, our only server (on Supabase) holds the leaderboard and the usage statistics, and we never sell data. The game is rated 12+ and is not directed at children under 13. Questions: adermanu@gmail.com
````

## 2. `terms.md`

**Hace falta una línea.** El punto «El progreso se puede perder» (§3 en español e inglés) dice hoy que **lo único**
que sale del dispositivo es lo del ranking: con la telemetría eso deja de ser verdad. El cambio lo corrige y aclara
que con las estadísticas no se puede rearmar la partida (que es lo que ese punto quiere decir). Nada más de los
Términos cambia: §4 ya manda el tratamiento de datos a la Política de Privacidad. Va idéntico en
`Distribution/site/terms.md` y `FisuEvolution/Resources/Legal/terms.md`; las frases que fija
`termsCarryTheUserContentClauses` no se tocan.

```diff
--- a/Distribution/site/terms.md
+++ b/Distribution/site/terms.md
@@ -60,12 +60,13 @@
   solo uso por diseño.
 - **El progreso se puede perder.** Tu partida vive en tu dispositivo y, si
   activás iCloud, en tu base privada de iCloud. No guardamos copias de tu
-  partida: lo único que sale de tu dispositivo es, si entrás al ranking, tu
-  nombre y tus tiempos de partida (con un identificador anónimo), que se
-  guardan en Supabase; el nombre lo revisa un modelo de Anthropic para filtrar
-  insultos. Si borrás la app, perdés el dispositivo o desactivás iCloud,
-  el progreso —incluidos objetos comprados que ya se consumieron— puede
-  perderse y no podemos recuperarlo.
+  partida: lo que sale de tu dispositivo es, si entrás al ranking, tu nombre y
+  tus tiempos de partida (con un identificador anónimo), que se guardan en
+  Supabase (el nombre lo revisa un modelo de Anthropic para filtrar insultos),
+  y las estadísticas de uso que explica la Política de Privacidad,
+  con las que no se puede rearmar tu partida. Si borrás la app, perdés el
+  dispositivo o desactivás iCloud, el progreso —incluidos objetos comprados
+  que ya se consumieron— puede perderse y no podemos recuperarlo.
 - **Reencarnar reinicia cosas a propósito.** Reencarnar (prestigio) borra
   parte de tu progreso a cambio de dólares blue y multiplicadores permanentes. Es una
   mecánica del juego, está avisada en pantalla antes de confirmar, y no da
@@ -246,12 +247,14 @@
   Apple Account. Consumables already spent are not restorable: they are
   single-use by design.
 - **Progress can be lost.** Your save lives on your device and, if you enable
-  iCloud, in your private iCloud database. We keep no copy of your game: the
-  only thing that leaves your device is, if you join the leaderboard, your
-  name and run times (with an anonymous identifier), stored on Supabase; an
-  Anthropic model checks the name to filter insults. If you delete the app, lose the device or turn off iCloud,
-  your progress — including already-consumed purchased items — may be lost
-  and we cannot recover it.
+  iCloud, in your private iCloud database. We keep no copy of your game: what
+  leaves your device is, if you join the leaderboard, your name and run times
+  (with an anonymous identifier), stored on Supabase (an Anthropic model
+  checks the name to filter insults), and the usage statistics
+  described in the Privacy Policy, which cannot be used to rebuild your game.
+  If you delete the app, lose the device or turn off iCloud, your progress —
+  including already-consumed purchased items — may be lost and we cannot
+  recover it.
 - **Reincarnating resets things on purpose.** Reincarnating (prestige) wipes
   part of your progress in exchange for Blue Dollars and permanent multipliers. It's a
   game mechanic, it is shown on screen before you confirm, and it does not
```

## 3. `adergames-site` (`content/legal.ts`, `content/terms.ts`)

El mismo cambio en el sitio, como diff propuesto contra `main` = `6791efa` del repo
`/Users/manuader/Desktop/projects/adergames-site` (sin aplicar; T9 lo hace en una rama local sin pushear y el push es
🔒 O5). En `legal.ts` la sección nueva va como `estadisticas` / `usage-stats`, entre la revisión con IA y las compras,
con el mismo texto que el `.md` (el sitio no corta líneas). Los dos archivos se comprobaron con
`node --experimental-strip-types` (importan bien y las secciones quedan en orden).

```diff
--- a/content/legal.ts
+++ b/content/legal.ts
@@ -9,12 +9,12 @@
 export const privacyES: LegalDoc = {
   title: "Política de Privacidad — FisuEvolution",
   updated: "octubre de 2026",
-  summary: "Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La publicidad procesa algunos datos, y el ranking guarda un identificador anónimo y el nombre que vos elegís. Abajo está exactamente cuáles y cómo los controlás.",
+  summary: "Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La publicidad procesa algunos datos, el ranking guarda un identificador anónimo y el nombre que vos elegís, y el juego nos manda estadísticas de uso, con un identificador al azar propio de ellas, para saber cómo se juega y cuánto rinden los anuncios. Abajo está exactamente cuáles y cómo los controlás.",
   sections: [
     { id: "no-hacemos", title: "Lo que NO hacemos", blocks: [
       { list: [
         "**No tenemos cuentas ni registro.** No pedimos tu email, tu nombre ni ningún dato personal para jugar.",
-        "**No tenemos analytics de terceros.** Tu progreso se guarda en tu dispositivo. El único servidor propio es el del ranking, que se explica más abajo (alojado en Supabase).",
+        "**No tenemos analytics de terceros.** Tu progreso se guarda en tu dispositivo. Tenemos un solo servidor propio, alojado en Supabase: guarda el ranking y las estadísticas de uso, que se explican más abajo.",
         "**No vendemos datos** a nadie.",
       ]},
     ]},
@@ -56,10 +56,22 @@
     ]},
     { id: "revision-ia", title: "Quién hace la revisión con IA", blocks: [
       { p: "La revisión automática la hace **Anthropic** con su modelo **Claude**, a pedido de nuestro servidor. Le mandamos **sólo el nombre que elegiste** (el texto, hasta 15 caracteres): no le mandamos el identificador de tu instalación, tus tiempos, tu identificador de publicidad ni ningún dato de tu dispositivo. Anthropic la procesa según su propia política de privacidad: https://www.anthropic.com/legal/privacy. Cualquier jugador puede **reportar** un nombre, y un nombre reportado se oculta. Si bloqueás un nombre (\"No ver más este nombre\"), esa decisión se guarda **sólo en tu dispositivo** y no sale de él. Si querés que borremos tu nombre o tus partidas del ranking, escribinos al contacto de abajo con tu nombre y lo hacemos." },
-      { p: "Los datos del ranking viven en un servidor propio, alojado en **Supabase**, que los guarda por cuenta nuestra. Es el único dato tuyo que sale del dispositivo hacia nosotros, y sólo si entrás al ranking." },
+      { p: "Los datos del ranking viven en nuestro servidor, alojado en **Supabase**, que los guarda por cuenta nuestra, y salen de tu dispositivo sólo si entrás al ranking. Lo otro que nos llega son las estadísticas de uso de la sección siguiente." },
     ]},
+    { id: "estadisticas", title: "Estadísticas de uso", blocks: [
+      { p: "Para entender cómo se juega y cuánto rinde cada anuncio, el juego le manda a nuestro servidor mensajes cortos sobre lo que pasa en la partida. Cada uno lleva:" },
+      { list: [
+        "**Qué pasó:** que empezó o terminó una sesión de juego (cuánto duró y cuántas sesiones llevás); que se vio un anuncio (de qué tipo, en qué lugar del juego, qué red lo sirvió y cuánto pagó por esa vista, en su moneda); qué pasó con una oferta de video (si apareció, si la tocaste, si te ganaste el premio, si no había video o si la dejaste pasar); qué producto compraste (sólo cuál: ni el precio ni los datos de la compra); y cuántas veces reencarnaste.",
+        "**Datos técnicos:** la versión del juego y de iOS, el modelo de tu iPhone o iPad (por ejemplo, \"iPhone16,2\") y el país de tu App Store.",
+        "**Un identificador al azar, propio de estas estadísticas.** No es el del ranking ni se comparte con él, y no está ligado a tu nombre, a tu cuenta de Apple ni a tu identificador de publicidad. Sigue siendo el mismo si reinstalás el juego en el mismo dispositivo y no pasa a tus otros dispositivos (ni por iCloud ni al restaurar una copia de seguridad en otro teléfono). Además, un identificador de sesión nuevo cada vez que abrís el juego y la hora de tu teléfono.",
+      ]},
+      { p: "Lo que **no** llevan: tu identificador de publicidad (IDFA), el identificador de proveedor de iOS (IDFV), tu nombre del ranking, texto que hayas escrito, ni datos de tu cuenta de Apple o de tu pago. No las cruzamos con tu nombre del ranking ni con nada que te identifique, no las usamos para mostrarte publicidad ni para seguirte por otras apps o sitios, no se las pasamos a las redes de anuncios y no las vendemos." },
+      { p: "Como cualquier pedido web, el proveedor del servidor (Supabase) ve la dirección IP desde la que llega cada envío —del ranking o de estas estadísticas— y la anota en sus registros técnicos por unos pocos días. Nosotros no la guardamos junto a las estadísticas, no la usamos para identificarte y no la cruzamos con ellas." },
+      { p: "Las estadísticas se guardan en Supabase por cuenta nuestra y **se borran solas a los 400 días** (un año y un mes, para comparar cada mes con el mismo del año anterior). Si estás sin conexión, esperan en tu dispositivo —como mucho, las últimas 1.000 y hasta un mes— hasta que haya red." },
+      { p: "**Cómo se apagan.** En la Unión Europea, el Reino Unido y Suiza se mandan sólo si en el formulario de consentimiento de Google aceptaste que se guarde información en tu dispositivo y que se use para medir, hacer estadísticas y mejorar el servicio. Podés cambiar tu elección cuando quieras en **Ajustes → Opciones de privacidad**: si la retirás, dejan de mandarse y lo que estaba esperando en tu dispositivo se borra sin salir de él. Fuera de la UE, el Reino Unido y Suiza el juego no tiene un interruptor para esto; las Opciones de privacidad, donde aparezcan, controlan los anuncios. No dependen del permiso de seguimiento de iOS (App Tracking Transparency) porque no son seguimiento: no se cruzan con datos de otras empresas." },
+    ]},
     { id: "compras", title: "Compras dentro de la app", blocks: [
-      { p: "Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni de tu método de pago — sólo recibimos de Apple la confirmación de qué compraste, para entregártelo." },
+      { p: "Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni de tu método de pago — sólo recibimos de Apple la confirmación de qué compraste, para entregártelo. Qué producto compraste (sin el precio) también va en las estadísticas de uso." },
     ]},
     { id: "progreso", title: "Tu progreso de juego", blocks: [
       { p: "Se guarda **en tu dispositivo**. Si en alguna versión futura activamos el guardado en iCloud, iría a **tu** base de datos privada de iCloud, a la que no tenemos acceso, y lo diríamos acá antes de hacerlo." },
@@ -76,12 +88,12 @@
 export const privacyEN: LegalDoc = {
   title: "Privacy Policy — HoboEvolution",
   updated: "October 2026",
-  summary: "Honest summary: we have no accounts and ask for no personal data. The ads process some data, and the leaderboard stores an anonymous identifier and the name you choose. Below is exactly which and how you control them.",
+  summary: "Honest summary: we have no accounts and ask for no personal data. The ads process some data, the leaderboard stores an anonymous identifier and the name you choose, and the game sends us usage statistics, under a random identifier of their own, to see how it is played and what the ads earn. Below is exactly which and how you control them.",
   sections: [
     { id: "dont", title: "What we do NOT do", blocks: [
       { list: [
         "**No accounts, no sign-up.** We never ask for your email, your name or any personal data to play.",
-        "**No third-party analytics.** Your progress stays on your device. Our only server is the leaderboard's, explained below (hosted on Supabase).",
+        "**No third-party analytics.** Your progress stays on your device. We have a single server of our own, hosted on Supabase: it holds the leaderboard and the usage statistics, both explained below.",
         "**We never sell data** to anyone.",
       ]},
     ]},
@@ -123,10 +135,22 @@
     ]},
     { id: "ai-check", title: "Who does the AI check", blocks: [
       { p: "The automated check is done by **Anthropic** with its **Claude** model, at our server's request. We send **only the name you chose** (the text, up to 15 characters): never your install identifier, run times, advertising identifier or any device data. Anthropic processes it under its own privacy policy: https://www.anthropic.com/legal/privacy. Any player can **report** a name, and a reported name is hidden. If you block a name (\"Hide this name\"), that choice is stored only on your device and never leaves it. To have your name or runs removed from the leaderboard, email us at the contact below with your name and we will do it." },
-      { p: "The leaderboard data lives on our own server, hosted on **Supabase**, which stores it on our behalf. It is the only data of yours that leaves your device to reach us, and only if you enter the leaderboard." },
+      { p: "The leaderboard data lives on our server, hosted on **Supabase**, which stores it on our behalf, and it leaves your device only if you enter the leaderboard. The only other thing that reaches us is the usage statistics in the next section." },
     ]},
+    { id: "usage-stats", title: "Usage statistics", blocks: [
+      { p: "To understand how the game is played and what each ad earns, the game sends our server short messages about what happens in play. Each one carries:" },
+      { list: [
+        "**What happened:** a play session started or ended (how long it lasted and how many sessions you've played); an ad was shown (its format, the place in the game, the network that served it and what it paid for that view, in its currency); what happened to a rewarded-video offer (shown, tapped, rewarded, no video available, or passed); which product you bought (only which one: never the price or payment details); and how many times you reincarnated.",
+        "**Technical data:** the app and iOS version, your iPhone or iPad model (e.g. \"iPhone16,2\") and your App Store country.",
+        "**A random identifier of their own.** It is not the leaderboard's and is not shared with it, and it is not tied to your name, your Apple account or your advertising identifier. It stays the same if you reinstall on the same device and never moves to your other devices (not through iCloud, and not by restoring a backup to another phone). Plus a new session identifier each time you open the game, and your phone's time.",
+      ]},
+      { p: "What they do **not** carry: your advertising identifier (IDFA), the iOS vendor identifier (IDFV), your leaderboard name, anything you typed, or your Apple account or payment data. We don't combine them with your leaderboard name or anything that identifies you, don't use them to show you ads or to track you across other apps or websites, don't share them with ad networks and never sell them." },
+      { p: "Like any web request, the server's host (Supabase) sees the IP address each request comes from — leaderboard or statistics — and keeps it in its technical logs for a few days. We don't store it with the statistics, don't use it to identify you and don't combine it with them." },
+      { p: "The statistics are stored on Supabase on our behalf and **deleted automatically after 400 days** (a year and a month, to compare each month with the same one a year earlier). While you are offline they wait on your device — at most the latest 1,000, for up to a month — until there is a connection." },
+      { p: "**How to turn them off.** In the EU, the UK and Switzerland they are sent only if, in Google's consent form, you agreed to storing information on your device and to using it for measurement, statistics and improving the service. You can change your choice any time in **Settings → Privacy options**: withdraw it and they stop, and whatever was waiting on your device is deleted without leaving it. Outside the EU, the UK and Switzerland the game has no switch for this; Privacy options, where they appear, control the ads. They don't depend on iOS App Tracking Transparency because they are not tracking: they are never combined with other companies' data." },
+    ]},
     { id: "purchases", title: "In-app purchases", blocks: [
-      { p: "Handled by **Apple**. We never see or store your card or payment details — Apple only tells us what you bought, so we can deliver it." },
+      { p: "Handled by **Apple**. We never see or store your card or payment details — Apple only tells us what you bought, so we can deliver it. Which product you bought (without the price) is also part of the usage statistics." },
     ]},
     { id: "progress", title: "Your game progress", blocks: [
       { p: "It stays **on your device**. If a future version enables iCloud saving, it would go to **your** private iCloud database, which we cannot access, and we would say so here before doing it." },
```

```diff
--- a/content/terms.ts
+++ b/content/terms.ts
@@ -22,7 +22,7 @@
         "**Reembolsos.** Los gestiona Apple según sus políticas. Si querés pedir uno, se hace desde reportaproblem.apple.com — nosotros no podemos emitir reembolsos ni revertir un cobro. Si algo falló del lado del Juego, escribinos igual y vemos qué podemos hacer.",
         "**Los objetos virtuales no valen plata real.** La plata, el ORO, las skins, los personajes y cualquier otro objeto del Juego son una licencia limitada de uso dentro del Juego. No son moneda, no son un activo, no tienen valor monetario, no se cambian por dinero ni por bienes fuera del Juego, y no se pueden vender, transferir ni heredar.",
         "**Restaurar compras.** Las compras no consumibles (pack inicial, \"Sin anuncios\", skins) se restauran desde Ajustes → Restaurar compras, con el mismo Apple Account. Los consumibles ya gastados no se restauran: son de un solo uso por diseño.",
-        "**El progreso se puede perder.** Tu partida vive en tu dispositivo y, si activás iCloud, en tu base privada de iCloud. No guardamos copias de tu partida: lo único que sale de tu dispositivo es, si entrás al ranking, tu nombre y tus tiempos de partida (con un identificador anónimo), que se guardan en Supabase; el nombre lo revisa un modelo de Anthropic para filtrar insultos. Si borrás la app, perdés el dispositivo o desactivás iCloud, el progreso —incluidos objetos comprados que ya se consumieron— puede perderse y no podemos recuperarlo.",
+        "**El progreso se puede perder.** Tu partida vive en tu dispositivo y, si activás iCloud, en tu base privada de iCloud. No guardamos copias de tu partida: lo que sale de tu dispositivo es, si entrás al ranking, tu nombre y tus tiempos de partida (con un identificador anónimo), que se guardan en Supabase (el nombre lo revisa un modelo de Anthropic para filtrar insultos), y las estadísticas de uso que explica la Política de Privacidad, con las que no se puede rearmar tu partida. Si borrás la app, perdés el dispositivo o desactivás iCloud, el progreso —incluidos objetos comprados que ya se consumieron— puede perderse y no podemos recuperarlo.",
         "**Reencarnar reinicia cosas a propósito.** Reencarnar (prestigio) borra parte de tu progreso a cambio de ORO y multiplicadores permanentes. Es una mecánica del juego, está avisada en pantalla antes de confirmar, y no da derecho a reembolso.",
         "**Precios y catálogo pueden cambiar.** Podemos agregar, sacar o cambiar el precio de los productos, y podemos ajustar el balance del Juego (costos, ganancias, recompensas) en cualquier momento. Los cambios de balance no dan derecho a reembolso de compras anteriores.",
       ]},
@@ -94,7 +94,7 @@
         "**Refunds** are handled by Apple under Apple's policies, via reportaproblem.apple.com. We cannot issue refunds or reverse a charge. If something went wrong on the Game's side, write to us anyway and we'll see what we can do.",
         "**Virtual items have no real-world value.** Coins, ORO, skins, characters and any other in-game item are a limited licence to use them inside the Game. They are not currency, not an asset, have no monetary value, cannot be exchanged for money or goods outside the Game, and cannot be sold, transferred or inherited.",
         "**Restoring purchases.** Non-consumable purchases (starter pack, \"No ads\", skins) can be restored from Settings → Restore Purchases with the same Apple Account. Consumables already spent are not restorable: they are single-use by design.",
-        "**Progress can be lost.** Your save lives on your device and, if you enable iCloud, in your private iCloud database. We keep no copy of your game: the only thing that leaves your device is, if you join the leaderboard, your name and run times (with an anonymous identifier), stored on Supabase; an Anthropic model checks the name to filter insults. If you delete the app, lose the device or turn off iCloud, your progress — including already-consumed purchased items — may be lost and we cannot recover it.",
+        "**Progress can be lost.** Your save lives on your device and, if you enable iCloud, in your private iCloud database. We keep no copy of your game: what leaves your device is, if you join the leaderboard, your name and run times (with an anonymous identifier), stored on Supabase (an Anthropic model checks the name to filter insults), and the usage statistics described in the Privacy Policy, which cannot be used to rebuild your game. If you delete the app, lose the device or turn off iCloud, your progress — including already-consumed purchased items — may be lost and we cannot recover it.",
         "**Reincarnating resets things on purpose.** Reincarnating (prestige) wipes part of your progress in exchange for ORO and permanent multipliers. It's a game mechanic, it is shown on screen before you confirm, and it does not entitle you to a refund.",
         "**Prices and catalogue may change.** We may add, remove or reprice products, and we may rebalance the Game (costs, earnings, rewards) at any time. Balance changes do not entitle you to a refund of past purchases.",
       ]},
```

Ojo (no es de E15): el `terms.ts` del sitio todavía dice «ORO» donde el repo ya dice «dólares blue» (C8 de E14).
El diff de arriba no lo toca para no mezclar cambios; conviene alinearlo en la misma rama de T9 si el dueño quiere.

## 4. Etiqueta de App Privacy (App Store Connect)

La etiqueta de ASC se declara **por tipo de dato**, como la unión de todo lo que junta la app (nuestro código, AdMob
y las redes de mediación). Esto es lo que **suma la telemetría**; lo que ya declaran AdMob/Unity/Meta y el ranking
(E12) no se toca.

| Tipo de dato (ASC) | Qué es en la telemetría | Vinculado a la identidad | Tracking | Propósito que suma |
|---|---|---|---|---|
| Usage Data · Product Interaction | sesiones (inicio, fin, duración), etapas de cada oferta de video, reencarnaciones | No | No | Analytics |
| Usage Data · Advertising Data | cada impresión: formato, lugar, red, valor y moneda | No | No | Analytics |
| Purchases · Purchase History | el id del producto comprado (sin precio ni transacción) | No | No | Analytics (tipo **nuevo** en la etiqueta) |
| Identifiers · Device ID | el id propio de la telemetría (otro UUID al azar, distinto del `installId` del ranking; el tipo ya está declarado por el ranking con App Functionality) | No | No | Analytics (se suma a App Functionality) |

Cómo leerla en el panel:

- **Device ID y Advertising Data ya figuran** por AdMob/Meta como «usados para rastrearte» y vinculados (el IDFA y
  los datos de publicidad de terceros; ver `Distribution/setup-v2-asc-admob-mediacion.md` §1.7). ASC muestra un solo
  estado por tipo: esos dos **siguen** apareciendo como tracking/vinculados por los SDK de anuncios, y lo nuestro sólo
  les **suma el propósito Analytics**. No hay que desmarcar nada.
- **Product Interaction** probablemente ya está por AdMob (toques, vistas de video); si está, se le suma Analytics.
- **Purchase History** es nuevo: no vinculado, sin tracking, Analytics.
- **No se declara** Coarse Location por el país de la tienda (es el país de la cuenta de App Store, no una ubicación
  del dispositivo) ni por la IP de los logs de Supabase (no la usamos ni la guardamos con los eventos). Coarse
  Location ya figura por AdMob de todos modos. Tampoco se declara «Other Diagnostic Data» por la versión de iOS y el
  modelo: van como contexto técnico de cada evento, no como diagnóstico. Ese tipo **ya figura** en la etiqueta por
  Meta Audience Network (Analytics, no vinculado, sin tracking; tabla de los SDK en
  `Distribution/setup-v2-asc-admob-mediacion.md`), así que sumarle el propósito no cambiaría lo que ve el jugador. Si
  el dueño prefiere declarar de más en alguno de estos, es su decisión; el manifiesto quedaría igual.
- Tiene que coincidir con `PrivacyInfo.xcprivacy` (ya actualizado en esta tarea, abajo) y con el texto aprobado del
  bloque 1.

**Cómo se carga:** `release-ops` **no** lo soporta (la CLI no tiene comando de App Privacy, y la API de App Store
Connect no expone las etiquetas de privacidad). Lo hace **el dueño en el panel** (🔒 O4): App Store Connect →
la app → **App Privacy** → editar cada tipo de la tabla → **Publish**. Hay que hacerlo antes de mandar la 2.0 a
revisión, porque el binario ya lleva el manifiesto nuevo.

## 5. AdMob: ingresos a nivel de impresión

**Hecho por el dueño (🔒 O3, 2026-10-15):** la cuenta de AdMob ya tiene activado **«Ingresos publicitarios a nivel
de las impresiones»** (*impression-level ad revenue*). Sin eso `paidEventHandler` no recibe valores; con eso, cada
impresión de los cuatro formatos trae su `AdValue` (valor, moneda y precisión), que T2 vuelca en `meta.adRevenue`.

Queda como **verificación**, no como pasos pendientes:

1. **En la consola:** AdMob → **Configuración** → pestaña **Cuenta** → «Ingresos publicitarios a nivel de las
   impresiones» aparece **activado**. (Si un día aparece apagado, se vuelve a prender ahí; no hace falta nada del lado
   de la app.)
2. **En un build de TestFlight con anuncios reales** (no los de prueba, que pueden venir en cero): después de ver un
   par de anuncios, la sonda de T2 (`AdValueProbe`) o el save muestran `meta.adRevenue` con `count > 0` y
   `totalMicros > 0` en el formato visto, con `precision` distinta de `unknown`. Con mediación es normal ver
   `estimated` para Unity/Meta y `precise`/`publisherProvided` para Google.
3. **Con el interruptor ya prendido (después de O6):** las consultas de `supabase/scripts/admin.sql` (impresiones y
   eCPM por país × formato) devuelven filas con `micros > 0`.

Si el paso 2 da todo en cero con anuncios reales, lo primero es mirar el paso 1 y que hayan pasado unas horas desde
que se activó (Google lo aplica a las impresiones nuevas, no a las viejas).

## 6. Notas a App Review (`release.json → store.reviewNotes`)

Hoy las notas dicen «Our only server is the optional leaderboard», que con la telemetría deja de ser verdad. El
texto actual tiene **3.996** caracteres (no los 3.970 del plan: creció con los términos de tolerancia cero); el tope
de App Store Connect es **4.000**. La línea nueva más el recorte deja **3.985**, todo ASCII:

| Reemplazar | Por | Δ |
|---|---|---|
| `Our only server is the optional leaderboard (see LEADERBOARD).` | `Our only server (Supabase): the optional leaderboard (see LEADERBOARD) and pseudonymous analytics (own random ID; no IDFA, no tracking).` | +74 |
| `HoboEvolution 2.0 - notes for the reviewer` | `HoboEvolution 2.0 - review notes` | -10 |
| `Opt-in rewarded videos stay (optional, they pay prizes); the purchase description says so.` | `Opt-in rewarded videos stay (optional, they pay prizes).` | -34 |
| `Tap the character to earn coins, tap Hire to buy another one, and drag one onto another to merge them.` | `Tap the character for coins, tap Hire to buy another, and drag one onto another to merge.` | -13 |
| `Each stays for 24 hours behind a chip at the top of the board, never during the tutorial.` | `Each stays 24 hours behind a chip atop the board, never in the tutorial.` | -17 |
| `(God), hours of play, so not reachable in review` | `(God), hours in, so not reachable in review` | -5 |
| `linked right above the button` | `linked above the button` | -6 |

La oración nueva, sola (para leerla):

> Our only server (Supabase): the optional leaderboard (see LEADERBOARD) and pseudonymous analytics (own random ID;
> no IDFA, no tracking).

Ningún recorte saca información que el revisor necesite: el encabezado se acorta, «the purchase description says
so» repite lo que ya dice la descripción de la compra, y el resto son las mismas instrucciones con menos palabras.
Se aplica en `release.json` (T9 o quien cierre E10) y se sube con `releaseops asc listing apply`, que muestra el
conteo (`set-review-notes … caracteres`) antes de aplicar.

---

## Lo que ya quedó hecho en esta tarea (no es borrador)

- `FisuEvolution/Resources/PrivacyInfo.xcprivacy`: el manifiesto dice la verdad del binario aunque el interruptor esté
  apagado. Suma `NSPrivacyCollectedDataTypeProductInteraction`, `NSPrivacyCollectedDataTypeAdvertisingData` y
  `NSPrivacyCollectedDataTypePurchaseHistory` (Analytics, no vinculados, sin tracking) y el propósito Analytics a
  `NSPrivacyCollectedDataTypeDeviceID`. `NSPrivacyTracking` sigue en `false` (B22). La telemetría no usa ninguna API
  de razón requerida nueva (la cola usa archivos en Application Support; `uname` y `ProcessInfo` no están en la lista).
- `FisuEvolutionTests/PrivacyManifestTests.swift`: el conjunto esperado nuevo (cinco tipos, sin repetir) y los
  propósitos exactos por tipo. El manifiesto describe **sólo nuestro código**: los SDK de anuncios traen el suyo, y
  ASC muestra la unión (por eso Device ID y Advertising Data aparecen allá como vinculados, por Meta).
- El id propio de la telemetría (decisión 2) no cambia el manifiesto: el tipo sigue siendo Device ID, no vinculado.

## Para T9

- Si la Opción A **no** está integrada cuando se apliquen los textos, copiar la variante B (decisión 1).
- `Distribution/setup-v2-asc-admob-mediacion.md:292-293` (§1.7) está **desactualizado**: dice que el manifiesto
  declara `NSPrivacyCollectedDataTypes = []`, y desde E12 declara lo del ranking y ahora lo de la telemetría.
  Corregirlo junto con los textos.
- En el sitio, el título de la sección nueva es «Estadísticas de uso» / «Usage statistics» (ids `estadisticas` /
  `usage-stats`).
