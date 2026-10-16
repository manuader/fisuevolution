# Cinco reels nuevos (v10–v14): guiones y storyboards para aprobar

Motion graphics 100 % programáticos, con el mismo motor de las piezas anteriores (`render/`: Canvas determinístico, 4K a 60 fps, `?lang=en` para la versión **HoboEvolution**). Solo se usan assets reales del juego (lámina `storyboards/assets_v10-v14.jpg`), sin IA, sin stock y sin personas reales. La música y los efectos son sintetizados, sumados a los SFX reales del juego.

Cada formato es **nuevo** respecto de v1–v9 (no repite ruleta, top 5, quiz, vlog, pantalla partida ni cronómetro). Ritmo: dinámico pero legible (≥ 1,5 s por texto, cámara siempre viva, pocos cortes).

| | Etapa | Formato | Hook | Mecánica de retención | Duración |
|---|---|---|---|---|---|
| **v10 · La cuenta** | TOFU | Árbol binario que se aleja sin cortes | ¿Cuántos fisuras hacen falta para hacer un Dios? | Apostar un número en los comentarios antes de la respuesta | 24 s |
| **v11 · El ticket** | TOFU | Impresora térmica que imprime la partida | Lo que cuesta llegar a Dios 🧾 | Leer renglón por renglón (cada uno es un chiste); "guardá el ticket" | 22 s |
| **v12 · $FISU** | MOFU | App de bolsa genérica en vivo | Compré acciones de un fisura | Ver cada sistema mover el gráfico; meme "stonks" | 30 s |
| **v13 · 3:07 AM** | TOFU | Pantalla bloqueada con notificaciones | POV: son las 3 AM y "una más y me duermo" | Identificación ("soy yo") + etiquetar al amigo | 25 s |
| **v14 · Línea F** | MOFU | Mapa de transporte de 37 estaciones | Próxima estación: Dios. | Seguir el tren; estaciones sin nombre (descubrir) | 28 s |

Datos verificados en el código:
- Cada fusión junta **2 iguales**. De El Fisura (nivel 1) a Dios (nivel 37) hay **36 fusiones** (`Resources/Data/tiers.json`), así que un Dios equivale a 2^36 = **68.719.476.736** Fisuras, unas 8,4 veces la población mundial.
- En **Recién Recibido** (nivel 11) la cadena se abre en **4 carreras** que se vuelven a juntar en **Director** (nivel 13).
- Efectos reales de los eventos (`events.json`):
  - Plan Platita: ingresos ×3 durante 60 s
  - Devaluación: ingresos ×0,5 durante 90 s
  - Se cayó Mercado Pago: contratar cuesta ×2 durante 60 s
  - Corralito: monedas congeladas durante 45 s
  - Inversión alienígena: ingresos ×5 durante 30 s (desde el nivel 20)
  - Te compró una big tech: evolución gratis
  - Aguinaldo: bono de monedas
- Reencarnar con +3 ORO lleva el multiplicador global de ×1,0 a ×1,6.
- Textos oficiales:
  - Notificación diaria: "Tus fisuras te extrañan / La torre siguió produciendo sin vos. Pasá a cobrar."
  - Logros: "Papá, me recibí", "Un pasito para el Fisura", "Escritura de la Luna"
  - Tarjeta para compartir: "Llegué a %@ y vos seguís de fisura 💀"

---

## v10 · TOFU · «La cuenta» (24 s) · EN: «The Math»

| s | Pantalla | Texto (ES) | Texto (EN) | Audio |
|---|---|---|---|---|
| 0–2,5 | Un Fisura solo, contador "1" | ¿CUÁNTOS FISURAS HACEN FALTA PARA HACER UN DIOS? · Apostá en los comentarios 👇 | HOW MANY HOBOS DOES IT TAKE TO MAKE A GOD? · Guess in the comments 👇 | Pulso grave |
| 2,5–5 | Entra otro Fisura, se fusionan → El Trapito | 2 FISURAS = 1 TRAPITO | 2 HOBOS = 1 FAKE VALET | sfx_merge |
| 5–8 | La cámara se aleja: árbol binario con las caras reales | CADA NIVEL: EL DOBLE. · 8 → 16 → 32 | EVERY LEVEL: DOUBLE. | Una nota más aguda por nivel |
| 8–12 | Zoom out acelerado; bandas de color de los pisos; silueta del nivel 21 | NIVEL 21: UN MILLÓN DE FISURAS. | LEVEL 21: A MILLION HOBOS. | Riser continuo |
| 12–15 | El árbol se vuelve polvo de estrellas; Dios en silueta | **68.719.476.736 FISURAS.** | **68,719,476,736 HOBOS.** | Silencio 0,3 s y golpe |
| 15–18 | 8 planetas dibujados | MÁS DE 8 VECES LA GENTE QUE VIVE EN LA TIERRA. | MORE THAN 8× EVERYONE ON EARTH. | Ocho "pop" |
| 18–20,5 | Vuelve el primer Fisura; un toque, +1 | POR SUERTE, SE JUEGA DE A UN TOQUE. | LUCKILY, IT'S ONE TAP AT A TIME. | sfx_tap + sfx_coin |
| 20,5–24 | Cierre | ¿LLEGÁS A JUNTARLOS? ES GRATIS. · Comentá cuánto apostabas 👇 | CAN YOU COLLECT THEM ALL? IT'S FREE. · Comment your guess 👇 | Golpe final |

## v11 · TOFU · «El ticket» (22 s) · EN: «The Receipt»

| s | Pantalla | Texto (ES) | Texto (EN) | Audio |
|---|---|---|---|---|
| 0–2 | Sale un ticket en blanco de una impresora | LO QUE CUESTA LLEGAR A DIOS 🧾 · TICKET Nº 000037 | WHAT IT COSTS TO BECOME GOD 🧾 | Impresora térmica |
| 2–5 | Renglones + íconos al costado | 1 CARTÓN … $0 · 1 RONDA DE MATES … $0 (−30% al contratar) | 1 CARDBOARD SIGN … $0 · 1 ROUND OF MATE … $0 (−30% hiring) | Impresora + pop |
| 5–9 | Sigue imprimiendo | 1 TÍTULO DE LA UBA … $0 (no paga el alquiler) · 1 YATE … $0 (es una foto) | 1 LAW DEGREE … $0 (doesn't pay rent) · 1 YACHT … $0 (it's a photo) | Impresora |
| 9–12 | Sello rojo | DEVALUACIÓN … −50% · CORRALITO … no lo podés tocar · SE CAYÓ MERCADO PAGO … ×2 | DEVALUED … −50% · ACCOUNT FROZEN … can't touch it · PAYMENT APP DOWN … ×2 | Sello + sfx_event |
| 12–15 | Renglones más rápidos | 1 ESCRITURA DE LA LUNA … $0 · 1 REENCARNACIÓN … ×1,6 · 1 PINTA DE ORO … $0 | 1 DEED TO THE MOON … $0 · 1 REINCARNATION … ×1.6 · 1 GOLDEN LOOK … $0 | Impresora rápida |
| 15–18 | Total | SUBTOTAL 37 NIVELES · TOTAL **$0** · sello **GRATIS** | SUBTOTAL 37 LEVELS · TOTAL **$0** · **FREE** | Caja registradora |
| 18–20 | El ticket se corta y vuela | Cuenta corriente con tu dignidad: $∞ | Balance owed to your dignity: $∞ | Papel rasgado |
| 20–22 | Cierre | GUARDÁ EL TICKET. EMPEZÁ GRATIS. · Etiquetá al que te debe plata 👇 | KEEP THE RECEIPT. START FREE. · Tag the friend who owes you money 👇 | Golpe final |

## v12 · MOFU · «$FISU» (30 s) · EN: «$HOBO»

App de bolsa **genérica** (sin marcas de brokers). El "precio" es la plata de la partida y cada sistema lo mueve con su efecto real.

| s | Pantalla | Texto (ES) | Texto (EN) | Audio |
|---|---|---|---|---|
| 0–2,5 | El gráfico explota | COMPRÉ ACCIONES DE UN FISURA (no es consejo financiero) · +3.700.000% | I BOUGHT STOCK IN A HOBO (not financial advice) | Ticks + riser |
| 2,5–6 | Rebobina a $1 | DÍA 1 · Cada toque: +1 | DAY 1 · Every tap: +1 | Rebobinado + sfx_tap |
| 6–10 | Escalones con las caras de cada fusión | CADA FUSIÓN, UN SALTO. | EVERY MERGE, A JUMP. | sfx_merge |
| 10–14 | Velas verdes y rojas, línea congelada | PLAN PLATITA ×3 · DEVALUACIÓN ×0,5 · CORRALITO: congelado | PLAN PLATITA ×3 · DEVALUATION ×0.5 · FROZEN | sfx_event + campana |
| 14–18 | Se compran íconos y la pendiente sube | SE CAYÓ MERCADO PAGO: contratar ×2 · BOOSTS · MEJORAS | PAYMENT APP DOWN: hiring ×2 · BOOSTS · UPGRADES | sfx_buy |
| 18–22 | Cae a $1 y la nueva línea le gana a la anterior | ¿VENDISTE TODO? → REENCARNÁS: ×1,6 | SOLD EVERYTHING? → REINCARNATE: ×1.6 | sfx_prestige |
| 22–26 | Escala logarítmica con los pisos; silueta de Dios arriba | INVERSIÓN ALIENÍGENA ×5 · MÁXIMO HISTÓRICO: ??? | ALIEN INVESTORS ×5 · ALL-TIME HIGH: ??? | Riser + campana |
| 26–30 | Cierre | COMPRÁ TU PRIMERA ACCIÓN. ES GRATIS. · No es consejo financiero. Es un juego 🙃 | BUY YOUR FIRST SHARE. IT'S FREE. · Not financial advice. It's a game 🙃 | Golpe final |

> El "+3.700.000%" es la suba del gráfico ficticio del anuncio, no una métrica del juego. Va con el aviso "no es consejo financiero" y sin ninguna promesa de ganancias reales.

## v13 · TOFU · «3:07 AM» (25 s) · EN: «3:07 AM»

Pantalla bloqueada **genérica** (sin logos de Apple). Los mensajes de amigos y familia son ficticios; los textos del juego son los reales.

| s | Pantalla | Texto (ES) | Texto (EN) | Audio |
|---|---|---|---|---|
| 0–2 | Se prende la pantalla: 3:07 | POV: son las 3 AM y "una más y me duermo" · notificación: Tus fisuras te extrañan | POV: it's 3 AM and "one more and I'm going to bed" · Your hobos miss you | Vibración + aviso |
| 2–6 | Se apilan notificaciones | Mamá: ¿Ya conseguiste laburo? · Mati: ¿qué es un Rentista de Soles? · Logro: Papá, me recibí | Mom: did you get a job yet? · Mati: what is a Landlord of Suns?? · Achievement: Mom, I Graduated | Un aviso por notificación |
| 6–10 | 3:41: toca la notificación y abre el juego | ¡NUEVO! | NEW! | sfx_merge + sfx_evolution |
| 10–14 | 4:12 | Mientras no estabas… +48,2K · Sofi: "Llegué a CEO y vos seguís de fisura 💀" | While you were away… +48.2K · "I made it to CEO and you're still broke 💀" | Aviso + "uh" del grupo |
| 14–18 | 5:30, amanece | Jefe: ¿Venís hoy? · Logro: Un pasito para el Fisura | Boss: you coming in today? · One Small Step for the Hobo | Pájaros |
| 18–21 | 7:00, alarma | Dormí 0 horas. Tengo la Luna. | Slept 0 hours. I own the Moon. | Alarma, corte seco |
| 21–22 | Negro | "UNA MÁS Y ME DUERMO." | "ONE MORE AND I'M GOING TO BED." | Silencio |
| 22–25 | Cierre | ¿UNA MÁS? DALE. · Etiquetá al que te escribe a las 3 AM 👇 | ONE MORE? FINE. · Tag the friend who texts you at 3 AM 👇 | Golpe final |

## v14 · MOFU · «Línea F» (28 s) · EN: «Next Stop: God»

Mapa de transporte **propio** (no el del Subte, que tiene marca registrada). El tren es la cara del Fisura.

| s | Pantalla | Texto (ES) | Texto (EN) | Audio |
|---|---|---|---|---|
| 0–2,5 | Cartel de andén, estación 1 | PRÓXIMA ESTACIÓN: DIOS. | NEXT STOP: GOD. | Chicharra de puertas |
| 2,5–7 | Estaciones 1–5 con nombre | ZONA CALLEJÓN · Combinación: fusioná 2 iguales | THE ALLEY · Transfer: merge 2 of a kind | Traqueteo + sfx_merge |
| 7–11 | Estaciones 6–8 | ZONA CIUDAD · sticker "six seven 🤷" | THE CITY · "six seven 🤷" | Traqueteo |
| 11–15 | La línea se abre en 4 colores y se junta | ELEGÍ TU CARRERA · Todas terminan en el mismo jefe. | PICK YOUR MAJOR · They all end at the same boss. | Acorde en 4 notas |
| 15–20 | El mapa se aleja; estaciones "???" y zonas | 37 ESTACIONES. LA MAYORÍA SIN NOMBRE (todavía). | 37 STOPS. MOST HAVE NO NAME (yet). | Traqueteo rápido + riser |
| 20–23 | Línea dorada que vuelve al inicio | COMBINACIÓN: REENCARNACIÓN · ×1,6 | TRANSFER: REINCARNATION · ×1.6 | sfx_prestige |
| 23–25 | Terminal con silueta de Dios | TERMINAL. ¿Te bajás antes? | LAST STOP. Getting off early? | Frenada + coro |
| 25–28 | Cierre | PRÓXIMA ESTACIÓN: VOS. ¿HASTA DÓNDE VIAJÁS? · Comentá en qué estación estás 👇 | NEXT STOP: YOU. HOW FAR WILL YOU RIDE? · Comment your stop 👇 | Golpe final |

---

## Assets (lámina `storyboards/assets_v10-v14.jpg`)

- **Sprites de personajes:** homeless, trapito, junior_lawyer, millonario (pinta Yate), ceo, dueno_luna. space_billionaire y god aparecen **solo en silueta**.
- **Caras (ui.atlas):** de El Fisura a Director, para los nodos del árbol (v10), las marcas del gráfico (v12) y las estaciones (v14).
- **UI y efectos:** moneda, fx_merge, fx_tap, Unos Mates, Más Platita, ORO, botón de reencarnar, trofeo, ui_million, ui_billion.
- **Fondos:**
  - v10, v12 y v14: como bandas de color o desenfocados.
  - v13: tal cual, dentro del juego.
- **Marca:** ícono de la app y logo de Ader Games.
- **Audio:**
  - SFX del juego: tap, coin, merge, evolution, event, buy, prestige.
  - Música y efectos (impresora, chicharra, alarma, pájaros): sintetizados.
- **Opcional:** fisura_wave (recorte limpio), para el cierre del v13.
- **No se usan:**
  - fisura_celebrate: recorte con blanco.
  - fisura_explain: tiene fondo.
  - fisura_point: otro estilo de dibujo, no es el del juego.
  - Fernet: alcohol.
- **Se dibujan con vectores propios** (no son personajes): impresora y ticket, app de bolsa, pantalla bloqueada, mapa de transporte y planetas.

## Para aprobar

1. Los 5 conceptos, o cuáles cambiar.
2. Los assets de la lámina, incluido el opcional fisura_wave.
3. Idioma de entrega: los 5 en español y en inglés (HoboEvolution), o solo uno de los dos.
