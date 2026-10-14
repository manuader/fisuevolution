# Política de Privacidad — FisuEvolution / HoboEvolution

_Última actualización: octubre de 2026_

**Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La
publicidad procesa algunos datos, y el ranking guarda un identificador anónimo
y el nombre que vos elegís. Abajo está exactamente cuáles y cómo los
controlás.**

## Lo que NO hacemos

- **No tenemos cuentas ni registro.** No pedimos tu email, tu nombre ni ningún
  dato personal para jugar.
- **No tenemos analytics de terceros.** Tu progreso se guarda en tu
  dispositivo. El único servidor propio es el del ranking, que se explica más
  abajo (alojado en Supabase).
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

Los datos del ranking viven en un servidor propio, alojado en **Supabase**, que
los guarda por cuenta nuestra. Es el único dato tuyo que sale del dispositivo
hacia nosotros, y sólo si entrás al ranking.

## Compras dentro de la app

Las procesa **Apple**. Nosotros no vemos ni guardamos datos de tu tarjeta ni de
tu método de pago — sólo recibimos de Apple la confirmación de qué compraste,
para entregártelo.

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

We don't collect your data, but the ads do. HoboEvolution shows ads through Google AdMob: opt-in rewarded videos you choose to watch for in-game prizes, and ads that appear on their own (full-screen ads between parts of the game, an ad break you can always decline, and one when you return to the app), all removed by the "No Ads" purchase except rewarded videos, which stay since they're optional and pay out. To serve them, Google AdMob processes device data including your advertising identifier (IDFA), IP address and technical/usage data, under its own policy at https://policies.google.com/privacy. AdMob also has other ad networks bid for each ad (mediation); in this version they are Unity Ads (https://unity.com/legal/privacy-policy) and Meta Audience Network (https://www.facebook.com/privacy/policy/), and each processes the same kind of device data under its own policy. We work with no other networks, and none of them receives your leaderboard name, install identifier or run times from us. The app downloads an ads configuration file from our website; it sends none of your data, but like any web request the site's host (Vercel) sees the IP address. On first launch iOS asks for App Tracking Transparency: accept and ads are personalized, decline and **you still get ads, just non-personalized** — you lose nothing in the game, and you can change it any time in Settings → Privacy & Security → Tracking. In the EU, UK and Switzerland we also show Google's consent form (UMP) before serving any ad, and you can review your choice in Settings → Privacy options. Your game progress stays on your device. Purchases are handled by Apple; we never see your payment details. If you reach God you may choose to enter the leaderboard with a name; it is optional, and without it your run is not published. For that we store on our server a random anonymous install identifier (not tied to your identity, your Apple account or your advertising identifier) and the name you chose plus your run times, which other players can see. We don't use them to track you, don't link them to your identity and don't share them with advertisers. The leaderboard lives on our own server, hosted on Supabase. Names go through rules, a word list and an automated AI check by Anthropic (Claude) before being shown: we send Anthropic only the name you chose (up to 15 characters), never your install identifier, run times, advertising identifier or any device data, and it processes the name under its own policy at https://www.anthropic.com/legal/privacy. So don't put personal data in your name; anyone can report a name and a reported name is hidden. If you block a name ("Hide this name"), that choice is stored only on your device and never leaves it. To have your name or runs removed, email us. We have no accounts and no third-party analytics, our only server is the leaderboard's (on Supabase), and we never sell data. The game is rated 12+ and is not directed at children under 13. Questions: adermanu@gmail.com
