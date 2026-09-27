# FisuEvolution en inglés: localización de los 11 anuncios para EE. UU.

Hecho con el método de **/brag** (skill `latent-spaces/brag`, variante slim): hook en los 2 primeros segundos, mostrar el producto real, texto legible (~0,3 s por palabra), cada cuadro "posteable" y **miniatura horneada en el frame 0** (el cuadro más fuerte de cada pieza, así TikTok, Reels y X muestran esa imagen como portada). Los videos salen del mismo motor que los de español (`render/`, parámetro `?lang=en`), así que se re-renderizan igual que los originales.

- Nombre en la tienda: **"From broke to God"**. Los nombres de personajes, pisos, boosts, eventos y logros son los **oficiales en inglés** del juego (`Localizable.xcstrings`): The Hobo, The Fake Valet, Rideshare Driver, Real Estate King, "Mom, I Graduated", etc. Nada de lo que aparece como UI del juego está inventado.
- Entregables: `en-US/FisuEvolution_EN_<etapa>_<pieza>_{4K,1080}.mp4` y `en-US/BOFU/…`, más `en-US/share-copy.md` (copys de publicación).
- El español no cambió: 126 cuadros de referencia de las 9 escenas son idénticos byte a byte antes y después de localizar.

## Ángulo creativo para EE. UU.

El público yanqui no tiene los códigos argentinos, pero le encanta descubrir "el juego raro de otro país". Por eso:

1. **Donde el chiste es universal** (ser pobre, el alquiler, el jefe, el crypto bro, la reunión que pudo ser un mail) se localiza a jerga de EE. UU.: *landlord*, *student loans*, *rent*, *DoorDash energy*, *fits*, *chat*.
2. **Donde el chiste es argentino** (mate, asado, Obelisco, "Dios es argentino") no se esconde: se **anuncia como rasgo**. Es "THIS GAME FROM ARGENTINA IS UNHINGED 💀". Así el remate "GOD IS ARGENTINIAN." se entiende solo, y el mate de Dios se vuelve curiosidad en vez de ruido.
3. **Trending topics sin personas reales.** Se usan formatos y frases (six seven, "chat, is this real?", "change my mind", *POV*, *your ex*, *touch grass*, tier/rank, "place your bets"), nunca caras, nombres, voces ni imitaciones de streamers, políticos (incluido Donald Trump) o famosos. Motivo: TikTok no acepta avisos políticos, Meta exige autorización para temas políticos, y poner a alguien real sin permiso es endoso falso y violación de su derecho de imagen. A los streamers reales se llega **invitándolos a jugar** (lista al final).

## Tabla de localización por pieza

| Etapa | Pieza EN (archivo) | Chiste / texto original | Versión EE. UU. | Por qué funciona | Riesgo en pauta |
|---|---|---|---|---|---|
| TOFU | **v7 · Pause & find out which one you are** (`EN_TOFU_PauseWhichOneAreYou`) | Ruleta de arquetipos argentinos; "¿El Pepe? 🤨" | 18 cartas: The Delivery Guy ("driver is 2 min away"), The Fake Valet ("$20 to 'watch' your car"), **The Streamer** ("Chat, is this real? 💀"), **The Influencer** ("Use code HOBO for 2% off", chiste oficial del juego), The Landlord ("Raised your rent. Again."), The Space Billionaire ("Can't fix Earth. Buying a new one."), SIX SEVEN, Change my mind. Giro: "WHO IS IT? 👀 → **YOUR EX? 🤨** → NO." | Arquetipos que se etiquetan entre amigos ("tag the friend who's The Landlord"). "Your ex" reemplaza al Pepe con el mismo scratch de disco | Bajo |
| TOFU | **v3 · Top 5 unhinged** (`EN_TOFU_Top5Unhinged`) | "Este juego es demasiado argentino 💀" | "THIS GAME FROM ARGENTINA IS UNHINGED 💀" · sello DEVALUED −50% · ACCOUNT FROZEN / THE PAYMENT APP IS DOWN / BONUS PAYCHECK DAY ("lasts about as long as ice cream in July") · #2 **THE FITS** · #1 GOD IS ARGENTINIAN | Curiosidad cultural y el caos económico que cualquiera reconoce. "Ice cream in July": el hemisferio ajustado | Bajo (la economía se trata como sátira, sin partidos) |
| TOFU | **v5 · Quiz** (`EN_TOFU_Quiz`) | "El 97 % no adivina la última"; respuestas falsas argentinas | "NOBODY GETS THE LAST ONE 👀" (se sacó el 97 %, que era una cifra inventada) · respuestas falsas: *A congressman*, *A limo driver*, *A city bus*, **A happy tenant** ("A happy tenant doesn't exist."), *A timeshare* | Formato de trivia de TV que se entiende sin idioma; el chiste del inquilino funciona igual en EE. UU. | Bajo |
| TOFU | **v4 · Day 1 → 365** (`EN_TOFU_Day1To365`) | Vlog del callejón a Puerto Madero | "I WENT FROM THE STREETS TO A YACHT IN ONE YEAR (day 365 is insane. watch till the end)" · "I got my law degree. / Only $200K in student loans." · "Okay… a photo WITH a yacht." · "Rent can't reach me here… yet." · logros oficiales en inglés | Formato "day X of" nativo de TikTok; deuda estudiantil y alquiler son dolores de EE. UU. | Bajo |
| MOFU | **v8 · Jake vs. Emma** (`EN_MOFU_JakeVsEmma`) | Tomi vs. Sofi; "¿Quién sos, el Pepe? 😂" | Jake vs. Emma, TEAM JAKE / TEAM EMMA, "Place your bets in the comments 👇", SIX SEVEN cuando Emma pasa del nivel 6 al 7, "Back to broke?? Bro hit reset on his whole life 😂" | Debate en comentarios; enseña fusionar, piso lleno, boosts, mejoras y reencarnar | Bajo |
| MOFU | **v2 · What's on the top floor?** (`EN_MOFU_WhatsOnTheTopFloor`) | Recorrido por todos los sistemas; "Sobreviví a la economía argentina" | UI completa en inglés oficial (Gifts, Daily streak, Focus Mode, Reincarnate now…) · "SURVIVE A BROKEN ECONOMY." · "POP BOOSTS." · "OPEN CHESTS. WIN FITS." | Muestra profundidad real de juego con la UI que el usuario va a ver | Bajo |
| MOFU | **v1 · From broke to God** (`EN_MOFU_FromBrokeToGod`) | "De fisura… a Dios" | "FROM BROKE… …TO GOD." (el subtítulo de la tienda) · TAP. MERGE. EVOLVE. · PICK YOUR CAREER · HOW FAR WILL YOU GO? | La promesa del juego en 5 palabras | Bajo |
| BOFU | **v9 · Your first minute** (`EN_BOFU_YourFirstMinute`) | Cronómetro sobre el primer minuto real | "HOW FAST CAN YOU UNLOCK YOUR FIRST CHARACTER? We're timing you." · TAP: 1 COIN PER TAP · HIRE ANOTHER (25) · DRAG IT AND MERGE · UNDER A MINUTE! · FREE / NO ACCOUNT NEEDED / PLAYS OFFLINE | Saca la objeción "¿me va a costar arrancar?" con la mecánica real | Bajo |
| BOFU | **A · Gameplay**, **B · God is Argentinian**, **C · From broke to God** (`en-US/BOFU/`) | Cortes + placa v6 | Mismos cortes que en español, desde los masters en inglés, con la placa "DOWNLOAD IT FREE · NO ACCOUNT NEEDED · PLAYS OFFLINE · 37 LEVELS TO DISCOVER" | Retargeting a quien ya vio TOFU/MOFU | Bajo |

**Placa v6 y texto promocional:** en español cita el texto promocional real del App Store. En inglés no hay uno cargado todavía, así que la placa dice *"Bonus paycheck day! Cash it in before inflation eats it."* (usa el nombre oficial del evento en inglés). **Cargá ese mismo texto como Promotional Text (en-US) en App Store Connect** para que el anuncio y la ficha coincidan.

## Hooks alternativos para test A/B (TOFU)

Se cambian con una línea en la escena y se re-renderiza solo el tramo del hook (`--from 0 --to 3`).

| Pieza | Hook actual | Alternativa A | Alternativa B |
|---|---|---|---|
| v7 | PAUSE THE VIDEO / and find out which one you are | POV: you pause and it says you're The Landlord | Pause now. Tag whoever you get. |
| v3 | THIS GAME FROM ARGENTINA / IS UNHINGED 💀 | Argentina made a game about being broke 💀 | This game's economy is more stable than mine |
| v5 | NOBODY GETS / THE LAST ONE 👀 | Only real gamers get #4 👀 | Two hobos merge. What do you get? |
| v4 | I WENT FROM THE STREETS / TO A YACHT / IN ONE YEAR | Day 1 of going from broke to God | Tell me you're broke without telling me: day 1 |

## Miniaturas (frame 0 de cada video)

| Pieza | Cuadro elegido |
|---|---|
| v7 | 2,0 s: carta boca abajo + "PAUSE THE VIDEO" |
| v3 | 29,9 s: "GOD IS ARGENTINIAN." con Dios parrillero |
| v5 | 16,2 s: ronda 3 con las tres respuestas y el reloj |
| v4 | 29,6 s: "WHO AM I?" + tarjeta "I made it to level 37 and you're still broke 💀" |
| v8 | 2,7 s: pantalla partida, "WHO GETS FURTHER?", TEAM JAKE / TEAM EMMA |
| v9 | 2,2 s: cronómetro en 00:00.0 + "HOW FAST CAN YOU UNLOCK YOUR FIRST CHARACTER?" |
| v2 | 1,5 s: la torre con la silueta arriba + "WHAT'S ON THE TOP FLOOR?" |
| v1 | 20,2 s: "…TO GOD." |
| v6 (placa) | 3,5 s: placa completa |

## Reglas aplicadas

1. Ninguna persona real identificable (nombres, caras, voces, handles, imitaciones). Charlie Kirk, Donald Trump, streamers y famosos quedan afuera de la pauta.
2. Nada de política partidaria: la sátira es económica y de clase, como en el original.
3. Audio 100 % propio (bandas sintetizadas + SFX del juego). Los sonidos virales de TikTok los agrega cada creador en su posteo orgánico.
4. Solo assets reales del juego; nada redibujado ni generado.
5. Solo afirmaciones verificables: Free, No account needed, Plays offline, 37 levels (`store-metadata.md`, `tiers.json`).
6. Safe zones de Reels/TikTok respetadas (mismo layout que las versiones en español).

## Los streamers: invitarlos, no ponerlos en el anuncio

El formato que mejor aprovecha la cultura streamer es **"Chat picks my career"**: el chat vota la carrera (developer, architect, doctor, lawyer), las fusiones y cuándo reencarnar, en una carrera en vivo hasta Dios. Diez invitaciones, de la investigación `investigacion/03-creadores-eeuu-global.md` (verificar audiencias antes de pagar):

| # | Creador | Por qué | Contacto |
|---|---|---|---|
| 1 | **Squeex** (Twitch) | Su formato es "el chat trae juegos raros" | About de Twitch |
| 2 | **Kosh Idle / Kosh Mobile** (YouTube + Twitch kosh_gaming) | Idle y mobile, exactamente el género | X @Kosh_Gaming_ / Discord |
| 3 | **Idle Cub** (YouTube, ~176k) | Canal de incrementales más activo | About de YouTube / Discord |
| 4 | **MrMacRight** (YouTube) | Referencia de juegos en iPhone | business@mrmacright.com |
| 5 | **Retromation** (YouTube/Twitch, ~290k) | Indies nuevos todos los días, sims de progresión | retromation750@gmail.com |
| 6 | **Olexa** (YouTube/Twitch) | Juegos raros e inventivos | Discord del canal |
| 7 | **Indie James** (YouTube) | Longplays de indies: la carrera de 37 niveles sin cortes | X @IndieJ4mes |
| 8 | **RTGame** (Twitch/YouTube) | Humor absurdo | Perfiles |
| 9 | **DougDoug** (Twitch/YouTube) | Desafíos armados por el chat | Perfiles |
| 10 | **Northernlion** (Twitch) | Historial con incrementales | Perfiles |

**DM (EN):**

> Hey [name]! I'm Manu, the solo dev behind *FisuEvolution — From broke to God*, a free iPhone merge-idle game from Argentina where you start as a hobo and merge your way through delivery guy, landlord, space billionaire… all the way to God (37 levels).
>
> I think it'd be a great **"chat picks my career"** stream: chat votes your college major, when to merge and when to reincarnate, and you race to God live. Free, no account, plays offline, and early runs take minutes to get going.
>
> Happy to send a TestFlight build, a creator code and a little in-game shout-out if you play it. Full creative freedom. No script. Want a key?

## Reproducir

```bash
cd Distribution/promo/render
node render.mjs video --v 7 --lang en --scale 2 --fps 60 --workers 4 --poster 2.0
V=7 L=en ./finish.sh          # ídem 3, 5, 4, 8, 9, 2, 1 (posters en la tabla de arriba)
node render.mjs video --v 6 --lang en --scale 2 --fps 60 --workers 4 --poster 3.5
L=en ./bofu.sh                 # los tres cortes BOFU en inglés
```

`out/chain_en.sh` corre todo en orden. Para revisar cuadros: `node render.mjs preview --v 7 --lang en 1.0 5.2` y `python3 sheet.py v7_en`.
