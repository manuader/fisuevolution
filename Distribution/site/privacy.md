# Política de Privacidad — FisuEvolution / HoboEvolution

_Última actualización: septiembre de 2026_

**Resumen honesto: no tenemos cuentas ni te pedimos datos personales. La
publicidad procesa algunos datos, y el ranking guarda un identificador anónimo
y el nombre que vos elegís. Abajo está exactamente cuáles y cómo los
controlás.**

## Lo que NO hacemos

- **No tenemos cuentas ni registro.** No pedimos tu email, tu nombre ni ningún
  dato personal para jugar.
- **No tenemos analytics de terceros.** Tu progreso se guarda en tu
  dispositivo. El único servidor propio es el del ranking, que se explica más
  abajo.
- **No vendemos datos** a nadie.

## Publicidad

FisuEvolution **muestra publicidad de Google AdMob**. Hay dos tipos:

- **Videos con recompensa**, que mirás sólo si querés: los ofrecemos a cambio de
  premios dentro del juego (duplicar tus ganancias, abrir otro cofre, activar un
  boost). Nunca se reproducen solos.
- **Anuncios de pantalla completa** entre partes del juego, espaciados y nunca
  en medio de una acción. La compra **"Sin anuncios"** los elimina; los videos
  con recompensa siguen disponibles, porque son opcionales y entregan premios.

Para mostrarlos, **Google AdMob procesa datos de tu dispositivo** —incluido tu
identificador de publicidad (IDFA), la dirección IP y datos técnicos y de uso—
según su propia política de privacidad:
<https://policies.google.com/privacy>.

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
revisar tu elección desde los ajustes del juego.

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
nombre reportado se oculta. Si querés que borremos tu nombre o tus partidas del
ranking, escribinos al contacto de abajo con tu nombre y lo hacemos.

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
>    `NSPrivacyTracking` está en `true`.
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

We don't collect your data, but the ads do. HoboEvolution shows Google AdMob ads: opt-in rewarded videos you choose to watch for in-game prizes, and occasional full-screen ads between parts of the game (removed by the "No Ads" purchase; rewarded videos stay, since they're optional and pay out). To serve them, Google AdMob processes device data including your advertising identifier (IDFA), IP address and technical/usage data, under its own policy at https://policies.google.com/privacy. On first launch iOS asks for App Tracking Transparency: accept and ads are personalized, decline and **you still get ads, just non-personalized** — you lose nothing in the game, and you can change it any time in Settings → Privacy & Security → Tracking. In the EU, UK and Switzerland we also show Google's consent form (UMP) before serving any ad. Your game progress stays on your device. Purchases are handled by Apple; we never see your payment details. If you reach God you may choose to enter the leaderboard with a name; it is optional, and without it your run is not published. For that we store on our server a random anonymous install identifier (not tied to your identity, your Apple account or your advertising identifier) and the name you chose plus your run times, which other players can see. We don't use them to track you, don't link them to your identity and don't share them with advertisers. Names go through rules, a word list and an automated AI check before being shown, so don't put personal data in your name; anyone can report a name and a reported name is hidden. To have your name or runs removed, email us. We have no accounts and no third-party analytics, our only server is the leaderboard's, and we never sell data. The game is rated 12+ and is not directed at children under 13. Questions: adermanu@gmail.com
