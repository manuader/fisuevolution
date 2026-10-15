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
