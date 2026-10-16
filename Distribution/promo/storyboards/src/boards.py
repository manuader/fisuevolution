import sys; import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sb import board
OUT = '/home/user/fisuevolution/Distribution/promo/storyboards/'
import os; os.makedirs(OUT, exist_ok=True)
DARK = '#3A3A3A'
W = (255, 255, 255)
def cta(lines, foot):
    return {'t': 'CTA', 'bg': '#5A5048', 'els': [
        ('txt', 540, 300, lines[0], 70, {'c': W}), ('txt', 540, 400, lines[1], 76, {'c': (255, 220, 120)}),
        ('img', 'app_icon', 540, 820, 300), ('txt', 540, 920, 'FISUEVOLUTION', 80, {'c': W}), ('txt', 540, 1030, 'DESCARGALO GRATIS', 72, {'c': (255, 220, 120)}),
        ('box', 330, 1110, 420, 140, {'fill': (20, 20, 20, 255), 'label': 'App Store', 'size': 40}),
        ('img', 'adergames_logo', 540, 1420, 120), ('txt', 540, 1480, foot, 40, {'c': W})],
        'on': f'"{lines[0]} {lines[1]}" · ícono · DESCARGALO GRATIS · badge · Ader Games · "{foot}"',
        'mv': 'Cierre común de la serie (ctaEnd), con pulso en el badge.', 'sfx': 'Golpe final + brillo; la música resuelve.'}

# ───────── v10 · LA CUENTA ─────────
board({'title': 'v10 · TOFU · «LA CUENTA» (24 s)', 'sub': 'EN: «THE MATH» · Hook: ¿cuántos fisuras hacen falta para hacer un Dios?',
 'desc': 'Dato real del juego: cada fusión junta 2 iguales y de El Fisura (nivel 1) a Dios (nivel 37) hay 36 fusiones → 2^36 = 68.719.476.736 Fisuras. '
         'Un árbol binario que se aleja sin cortes muestra la escala: se ve la profundidad del juego sin enseñar los personajes de arriba. '
         'Retención: el público apuesta un número en los comentarios antes de ver la respuesta.'},
[
 {'t': '0–2,5 s', 'bg': DARK, 'els': [('txt', 540, 330, '¿CUÁNTOS FISURAS\nHACEN FALTA', 70, {'c': W}), ('txt', 540, 470, 'PARA HACER UN DIOS?', 74, {'c': (255, 220, 120)}),
   ('img', 'homeless', 540, 1300, 620), ('box', 390, 1380, 300, 110, {'label': '1', 'size': 60}), ('txt', 540, 1560, 'Apostá en los comentarios 👇', 40, {'c': W})],
  'on': 'Un solo Fisura al centro + contador "1".', 'mv': 'El texto entra palabra por palabra; el Fisura respira.', 'sfx': 'Pulso grave solo.'},
 {'t': '2,5–5 s', 'bg': DARK, 'els': [('img', 'homeless', 330, 1150, 480), ('img', 'homeless', 750, 1150, 480, {'flip': 1}), ('arrow', 430, 1180, 520, 1260), ('arrow', 650, 1180, 560, 1260),
   ('img', 'trapito', 540, 1600, 300), ('box', 290, 380, 500, 110, {'label': '2 fisuras = 1 Trapito', 'size': 34}), ('box', 390, 1640, 300, 90, {'label': '2', 'size': 50})],
  'on': '2 FISURAS = 1 TRAPITO · contador 2', 'mv': 'Entra un segundo Fisura y se fusionan (la fusión real del juego).', 'sfx': 'sfx_merge real del juego.'},
 {'t': '5–8 s', 'bg': DARK, 'els': [('tree', 4, 700, 1500), ('txt', 900, 700, 'NIVEL 4', 34, {'c': W}), ('txt', 900, 1500, 'NIVEL 1', 34, {'c': W}),
   ('txt', 540, 360, 'CADA NIVEL: EL DOBLE.', 62, {'c': W}), ('box', 340, 1620, 400, 100, {'label': '8 → 16 → 32', 'size': 40})],
  'on': 'CADA NIVEL: EL DOBLE. · contador 8 → 16 → 32', 'mv': 'La cámara se aleja: cada nodo es la cara real del personaje (Trapito, Limpiavidrios…).', 'sfx': 'Una nota más aguda por nivel.'},
 {'t': '8–12 s', 'bg': '#4A4A4A', 'els': [('tree', 7, 450, 1600), ('box', 160, 330, 760, 90, {'label': 'Nivel 21 · 1.048.576 fisuras', 'size': 32}),
   ('img', 'space_billionaire', 540, 300, 200, {'sil': 1})],
  'on': 'NIVEL 21: UN MILLÓN DE FISURAS.', 'mv': 'Más rápido; el fondo cambia por bandas de piso (Ciudad → Corporativo → Lujo).', 'sfx': 'Riser continuo (tono de Shepard).'},
 {'t': '12–15 s', 'bg': '#2A2A30', 'els': [('noise', 1, 2500), ('img', 'god', 540, 760, 520, {'sil': 1}), ('circle', 540, 520, 300, {'line': (230, 200, 120), 'lw': 2}),
   ('txt', 540, 1200, '68.719.476.736', 96, {'c': (255, 220, 120)}), ('txt', 540, 1330, 'FISURAS.', 80, {'c': W})],
  'on': '68.719.476.736 FISURAS. (Dios en silueta, no se revela)', 'mv': 'El árbol se vuelve polvo de estrellas; el número golpea al centro.', 'sfx': 'Silencio de 0,3 s y golpe.'},
 {'t': '15–18 s', 'bg': '#2A2A30', 'els': [*[('circle', 200 + (i % 4) * 230, 760 + (i // 4) * 260, 95, {'fill': (120, 140, 170, 255)}) for i in range(8)],
   ('txt', 540, 380, 'MÁS DE 8 VECES', 72, {'c': W}), ('txt', 540, 480, 'LA GENTE DE LA TIERRA.', 60, {'c': (255, 220, 120)})],
  'on': 'MÁS DE 8 VECES LA GENTE QUE VIVE EN LA TIERRA.', 'mv': 'Aparecen 8 planetas dibujados (vector propio, sin fotos).', 'sfx': 'Ocho "pop" en tempo.'},
 {'t': '18–20,5 s', 'bg': DARK, 'els': [('txt', 540, 360, 'POR SUERTE', 70, {'c': W}), ('txt', 540, 460, 'SE JUEGA DE A UN TOQUE.', 62, {'c': (255, 220, 120)}),
   ('img', 'homeless', 540, 1350, 600), ('circle', 600, 950, 70, {'line': (255, 255, 255), 'lw': 3}), ('txt', 760, 900, '+1', 60, {'c': (255, 220, 120)})],
  'on': 'POR SUERTE, SE JUEGA DE A UN TOQUE.', 'mv': 'Vuelve el primer Fisura; un dedo lo toca y salta una moneda.', 'sfx': 'sfx_tap + sfx_coin.'},
 cta(['¿LLEGÁS A JUNTARLOS?', 'ES GRATIS.'], 'Comentá cuánto apostabas 👇'),
], OUT + 'v10_LaCuenta.jpg')

# ───────── v11 · EL TICKET ─────────
def receipt(lines, top=300, extra=()):
    els = [('box', 170, top, 740, 1500, {'fill': (250, 250, 245, 255), 'r': 6}), ('txt', 540, top + 70, 'TICKET Nº 000037', 34, {'b': True}),
           ('txt', 540, top + 120, '- - - - - - - - - - - - - -', 30, {'b': False})]
    for i, ln in enumerate(lines): els.append(('txt', 540, top + 200 + i * 90, ln, 30, {'b': True}))
    return els + list(extra)
board({'title': 'v11 · TOFU · «EL TICKET» (22 s)', 'sub': 'EN: «THE RECEIPT» · Hook: lo que cuesta llegar a Dios 🧾',
 'desc': 'Una impresora térmica imprime el ticket de una partida: cada renglón es algo real del juego (boosts, carreras, eventos, logros, reencarnar), con el chiste en el precio. '
         'El total es GRATIS. El formato "ticket" es satisfactorio de mirar y muy compartible ("guardá el ticket"). Al lado de cada renglón aparece el personaje u objeto.'},
[
 {'t': '0–2 s', 'bg': DARK, 'els': [('box', 140, 260, 800, 90, {'fill': (20, 20, 20, 255)}), *receipt([], 300), ('box', 60, 1580, 960, 140, {'fill': (30, 30, 30, 240), 'label': 'LO QUE CUESTA LLEGAR A DIOS', 'size': 40, 'tc': (255, 255, 255)})],
  'on': 'LO QUE CUESTA LLEGAR A DIOS 🧾 · ticket en blanco saliendo de la ranura', 'mv': 'El papel sale con tirones cortos, como una impresora real.', 'sfx': 'Impresora térmica (sintetizada).'},
 {'t': '2–5 s', 'bg': DARK, 'els': receipt(['1 CARTÓN ............ $0', '1 RONDA DE MATES .... $0', '  (−30% al contratar)'], 300,
   [('img', 'homeless', 900, 760, 330), ('img', 'ui_boost_mate', 900, 960, 180)]),
  'on': '1 CARTÓN … $0 · 1 RONDA DE MATES … $0 (−30% al contratar)', 'mv': 'Cada renglón se imprime y su ícono salta al costado.', 'sfx': 'Impresora + pop por ícono.'},
 {'t': '5–9 s', 'bg': DARK, 'els': receipt(['1 CARTÓN ............ $0', '1 RONDA DE MATES .... $0', '1 TÍTULO DE LA UBA .. $0', '  (no paga el alquiler)', '1 YATE .............. $0', '  (es una foto)'], 300,
   [('img', 'junior_lawyer', 920, 1060, 300), ('img', 'millonario_idle__yate', 920, 1350, 300)]),
  'on': 'TÍTULO DE LA UBA (no paga el alquiler) · YATE (es una foto)', 'mv': 'El ticket baja; la cámara lo sigue.', 'sfx': 'Impresora.'},
 {'t': '9–12 s', 'bg': DARK, 'els': receipt(['DEVALUACIÓN ......... −50%', 'CORRALITO ... no lo podés tocar', 'SE CAYÓ MERCADO PAGO .. ×2'], 300,
   [('box', 200, 470, 680, 130, {'fill': (255, 200, 200, 200), 'line': (200, 40, 40), 'label': 'SELLO ROJO', 'size': 30})]),
  'on': 'Eventos reales: DEVALUACIÓN −50% · CORRALITO · SE CAYÓ MERCADO PAGO ×2', 'mv': 'Un sello rojo golpea el ticket.', 'sfx': 'Golpe de sello + sfx_event.'},
 {'t': '12–15 s', 'bg': DARK, 'els': receipt(['1 ESCRITURA DE LA LUNA  $0', '1 REENCARNACIÓN ...... ×1,6', '1 PINTA DE ORO ...... $0'], 300,
   [('img', 'dueno_luna', 920, 760, 330), ('img', 'ui_oro', 920, 960, 150)]),
  'on': 'ESCRITURA DE LA LUNA (logro real) · REENCARNACIÓN ×1,6', 'mv': 'Los renglones se aceleran.', 'sfx': 'Impresora más rápida.'},
 {'t': '15–18 s', 'bg': DARK, 'els': receipt(['SUBTOTAL ..... 37 NIVELES', '', 'TOTAL'], 300,
   [('txt', 540, 900, '$0', 150), ('box', 260, 1000, 560, 170, {'fill': (200, 255, 200, 220), 'line': (40, 140, 60), 'label': 'GRATIS', 'size': 60})]),
  'on': 'SUBTOTAL 37 NIVELES · TOTAL $0 · sello GRATIS', 'mv': 'Pausa; el total aparece y cae el sello verde.', 'sfx': 'Caja registradora ("ding").'},
 {'t': '18–20 s', 'bg': DARK, 'els': [('arrow', 540, 1200, 900, 400, {'label': 'el ticket vuela'}), ('box', 380, 300, 400, 500, {'fill': (250, 250, 245, 255), 'r': 6}),
   ('txt', 540, 1500, 'Cuenta corriente con tu dignidad:', 40, {'c': W}), ('txt', 540, 1580, '$∞', 70, {'c': (255, 220, 120)})],
  'on': 'Cuenta corriente con tu dignidad: $∞', 'mv': 'El ticket se corta (rasgado) y sale volando.', 'sfx': 'Papel rasgado.'},
 cta(['GUARDÁ EL TICKET.', 'EMPEZÁ GRATIS.'], 'Etiquetá al que te debe plata 👇'),
], OUT + 'v11_ElTicket.jpg')

# ───────── v12 · $FISU ─────────
def chart(pts, extra=(), bg='#2F3338'):
    P = [(80 + x * 920, 1500 - y * 1000) for x, y in pts]
    return {'bg': bg, 'els': [('box', 60, 230, 960, 150, {'fill': (255, 255, 255, 30), 'line': (200, 200, 200)}),
            ('txt', 300, 285, '$FISU', 56, {'c': W}), ('txt', 760, 285, '▲ ...', 46, {'c': (120, 220, 140)}),
            ('line', [(80, 1500), (1000, 1500)], {'c': (150, 150, 150), 'lw': 1}), ('line', P, {'c': (120, 220, 140), 'lw': 4}), *extra]}
board({'title': 'v12 · MOFU · «$FISU» (30 s)', 'sub': 'EN: «$HOBO» · Hook: compré acciones de un fisura',
 'desc': 'Una app de bolsa genérica (sin marcas) sigue el "precio" de la partida en vivo. Cada sistema del juego mueve el gráfico con su efecto real (events.json): '
         'toques, fusiones, Plan Platita ×3, Devaluación ×0,5, Corralito (congelado 45 s), Mercado Pago (contratar ×2), boosts, mejoras, reencarnar (×1,6) e Inversión alienígena ×5. '
         'Explica la profundidad del juego (MOFU) con el meme "stonks" sin mostrar personajes de arriba.'},
[
 {**chart([(0, .05), (.3, .1), (.5, .3), (.7, .45), (1, .95)], [('txt', 540, 520, 'COMPRÉ ACCIONES', 64, {'c': W}), ('txt', 540, 610, 'DE UN FISURA', 64, {'c': (255, 220, 120)}),
   ('txt', 540, 700, '(no es consejo financiero)', 34, {'c': W, 'b': False}), ('txt', 760, 900, '+3.700.000%', 50, {'c': (120, 220, 140)})]), 't': '0–2,5 s',
  'on': 'COMPRÉ ACCIONES DE UN FISURA (no es consejo financiero) · gráfico que explota', 'mv': 'La línea se dibuja hacia arriba a toda velocidad.', 'sfx': 'Ticks + riser.'},
 {**chart([(0, .05), (.4, .06), (.6, .07)], [('txt', 540, 520, 'DÍA 1', 70, {'c': W}), ('img', 'homeless_face', 640, 1520, 120), ('txt', 540, 1650, 'Cada toque: +1', 44, {'c': W})]), 't': '2,5–6 s',
  'on': 'DÍA 1 · Cada toque: +1', 'mv': 'Rebobina a $1; con cada toque la línea sube un pelito.', 'sfx': 'Rebobinado + sfx_tap.'},
 {**chart([(0, .05), (.2, .05), (.2, .12), (.4, .12), (.4, .2), (.6, .2), (.6, .3)], [('img', 'trapito_face', 260, 1400, 90), ('img', 'limpiavidrios_face', 450, 1300, 90),
   ('img', 'cartonero_face', 630, 1200, 90), ('txt', 540, 520, 'CADA FUSIÓN, UN SALTO.', 56, {'c': W})]), 't': '6–10 s',
  'on': 'CADA FUSIÓN, UN SALTO. (marcas con las caras reales)', 'mv': 'Escalones; cada escalón deja la cara del personaje nuevo.', 'sfx': 'sfx_merge en cada salto.'},
 {**chart([(0, .3), (.3, .32), (.4, .6), (.55, .62), (.7, .35), (.85, .35), (1, .37)], [('box', 330, 820, 380, 100, {'fill': (120, 220, 140, 200), 'label': 'PLAN PLATITA ×3', 'size': 28}),
   ('box', 560, 1050, 420, 100, {'fill': (240, 120, 120, 220), 'label': 'DEVALUACIÓN ×0,5', 'size': 28}), ('box', 700, 1260, 300, 90, {'label': '🔒 CORRALITO', 'size': 26})]), 't': '10–14 s',
  'on': 'Eventos reales con su efecto: PLAN PLATITA ×3 · DEVALUACIÓN ×0,5 · CORRALITO (congelado)', 'mv': 'Vela verde, vela roja, línea congelada con candado.', 'sfx': 'sfx_event + campana de bolsa.'},
 {**chart([(0, .35), (.5, .5), (1, .7)], [('box', 140, 560, 800, 100, {'label': 'SE CAYÓ MERCADO PAGO · contratar ×2', 'size': 26}),
   ('img', 'ui_boost_mate', 300, 900, 150), ('img', 'ui_up_income', 760, 900, 150), ('txt', 540, 1000, 'BOOSTS  ·  MEJORAS', 40, {'c': W})]), 't': '14–18 s',
  'on': 'SE CAYÓ MERCADO PAGO (contratar ×2) · BOOSTS · MEJORAS', 'mv': 'Los íconos reales se "compran" y la pendiente sube.', 'sfx': 'sfx_buy.'},
 {**chart([(0, .7), (.3, .02), (1, .9)], [('line', [(80, 800), (1000, 600)], {'c': (160, 160, 160), 'lw': 2}), ('txt', 540, 520, 'REENCARNÁS: ×1,6', 60, {'c': (255, 220, 120)}),
   ('txt', 360, 1440, '¿vendiste todo?', 34, {'c': W}), ('img', 'ui_oro', 860, 1650, 120)]), 't': '18–22 s',
  'on': '¿VENDISTE TODO? → REENCARNÁS: ×1,6 · línea fantasma de la vida anterior', 'mv': 'Cae a $1, gana ORO y la nueva línea le gana a la anterior.', 'sfx': 'sfx_prestige real.'},
 {**chart([(0, .2), (.5, .55), (1, .98)], [('box', 140, 560, 800, 100, {'label': 'INVERSIÓN ALIENÍGENA ×5', 'size': 30}), ('img', 'god', 900, 520, 260, {'sil': 1}),
   ('txt', 540, 1650, 'MÁXIMO HISTÓRICO: ???', 44, {'c': W})], bg='#22222E'), 't': '22–26 s',
  'on': 'INVERSIÓN ALIENÍGENA ×5 · eje en escala logarítmica con pisos (Luna, Marte…) · MÁXIMO HISTÓRICO: ???', 'mv': 'Fondo espacial; la línea llega a la silueta de Dios.', 'sfx': 'Riser + campana.'},
 cta(['COMPRÁ TU PRIMERA ACCIÓN.', 'ES GRATIS.'], 'No es consejo financiero. Es un juego 🙃'),
], OUT + 'v12_FISU.jpg')

# ───────── v13 · 3:07 AM ─────────
def lock(time, notifs, extra=(), bg='#2B2D3A'):
    els = [('txt', 540, 360, time, 150, {'c': W}), ('txt', 540, 470, 'martes', 34, {'c': W, 'b': False})]
    for i, (a, b) in enumerate(notifs):
        y = 620 + i * 190
        els += [('box', 80, y, 920, 160, {'fill': (255, 255, 255, 200), 'r': 34}), ('txt', 540, y + 50, a, 30), ('txt', 540, y + 108, b, 28, {'b': False})]
    return {'bg': bg, 'els': els + list(extra)}
board({'title': 'v13 · TOFU · «3:07 AM» (25 s)', 'sub': 'EN: «3:07 AM» · Hook: POV: son las 3 AM y "una más y me duermo"',
 'desc': 'La pantalla bloqueada de un celular (genérica, sin logos de Apple) cuenta la noche con notificaciones: la notificación real del juego ("Tus fisuras te extrañan"), '
         'logros reales, la ganancia offline y la tarjeta para compartir ("Llegué a … y vos seguís de fisura 💀"). Los mensajes de amigos y familia son ficticios. Relatable y etiquetable.'},
[
 {**lock('3:07', [('FisuEvolution · Tus fisuras te extrañan', 'La torre siguió produciendo sin vos. Pasá a cobrar.')], [('txt', 540, 1450, 'POV: son las 3 AM y', 46, {'c': W}), ('txt', 540, 1530, '"una más y me duermo"', 52, {'c': (255, 220, 120)})]), 't': '0–2 s',
  'on': 'POV: son las 3 AM y "una más y me duermo" · notificación real del juego', 'mv': 'La pantalla se enciende; entra la notificación.', 'sfx': 'Vibración + aviso (sintetizado).'},
 {**lock('3:08', [('Mamá', '¿Ya conseguiste laburo?'), ('Los del barrio · Mati', '¿qué es un Rentista de Soles?'), ('🏆 Logro desbloqueado', 'Papá, me recibí')]), 't': '2–6 s',
  'on': 'Mamá: ¿Ya conseguiste laburo? · Mati: ¿qué es un Rentista de Soles? · Logro: Papá, me recibí', 'mv': 'Se apilan de a una, con rebote.', 'sfx': 'Un aviso por notificación, en tempo.'},
 {'t': '6–10 s', 'bg': '#3A3A3A', 'els': [('box', 160, 260, 760, 1400, {'fill': (230, 225, 215, 255), 'r': 60}), ('bgimg', 'bg_alley'), ('img', 'trapito', 540, 1300, 520),
   ('txt', 540, 520, '¡NUEVO!', 70), ('txt', 900, 300, '3:41', 46, {'c': W})],
  'on': 'El reloj salta 3:08 → 3:41 · ¡NUEVO! dentro del juego', 'mv': 'Toca la notificación: zoom al juego (UI real), fusión rápida.', 'sfx': 'sfx_merge + sfx_evolution.'},
 {**lock('4:12', [('FisuEvolution', 'Mientras no estabas… +48,2K'), ('Los del barrio · Sofi', 'Llegué a CEO y vos seguís de fisura 💀')], [('img', 'ceo', 860, 1450, 330)]), 't': '10–14 s',
  'on': 'Mientras no estabas… +48,2K · Sofi manda la tarjeta "Llegué a CEO y vos seguís de fisura 💀"', 'mv': 'La tarjeta para compartir se abre grande.', 'sfx': 'Aviso + "uh" del grupo.'},
 {**lock('5:30', [('Jefe', '¿Venís hoy?'), ('🏆 Logro desbloqueado', 'Un pasito para el Fisura')], [('img', 'dueno_luna', 540, 1680, 360)], bg='#4A4A58'), 't': '14–18 s',
  'on': 'Jefe: ¿Venís hoy? · Logro: Un pasito para el Fisura (llegó a la Luna)', 'mv': 'El fondo amanece de a poco.', 'sfx': 'Pájaros (sintetizados) entrando.'},
 {**lock('7:00', [('⏰ Alarma', 'Laburo')], [('txt', 540, 1150, 'Dormí 0 horas.', 64, {'c': (30, 30, 30)}), ('txt', 540, 1260, 'Tengo la Luna.', 70, {'c': (30, 30, 30)})], bg='#C8C2B0'), 't': '18–21 s',
  'on': 'Alarma 7:00 · "Dormí 0 horas. Tengo la Luna."', 'mv': 'La alarma sacude la pantalla.', 'sfx': 'Alarma, corte seco.'},
 {'t': '21–22 s', 'bg': DARK, 'els': [('txt', 540, 900, '"UNA MÁS', 90, {'c': W}), ('txt', 540, 1020, 'Y ME DUERMO."', 90, {'c': (255, 220, 120)})],
  'on': '"UNA MÁS Y ME DUERMO."', 'mv': 'Negro y texto; respiro antes del cierre.', 'sfx': 'Silencio.'},
 cta(['¿UNA MÁS?', 'DALE.'], 'Etiquetá al que te escribe a las 3 AM 👇'),
], OUT + 'v13_3AM.jpg')

# ───────── v14 · LÍNEA F ─────────
def metro(stations, extra=(), branch=False, bg='#E4E1DA'):
    els = [('line', [(140, 1700), (140, 300)], {'c': (230, 120, 40), 'lw': 10})]
    for i, (y, name) in enumerate(stations):
        els += [('circle', 140, y, 26, {'fill': (255, 255, 255), 'lw': 4}), ('txt', 520, y, name, 40)]
    if branch:
        for k, x in enumerate([320, 480, 640, 800]):
            els += [('line', [(140, 1150), (x, 1050), (x, 760), (140, 640)], {'c': [(80, 140, 230), (90, 180, 90), (200, 70, 70), (130, 90, 190)][k], 'lw': 8})]
    return {'bg': bg, 'els': els + list(extra)}
board({'title': 'v14 · MOFU · «LÍNEA F» (28 s)', 'sub': 'EN: «NEXT STOP: GOD» · Hook: próxima estación: Dios',
 'desc': 'Un mapa de transporte propio (sin la marca del Subte) con las 37 estaciones = 37 niveles, siguiendo la cadena real de tiers.json: '
         'en "Recién Recibido" la línea se abre en 4 ramales (las 4 carreras) que se juntan otra vez en "Director". '
         'Después de Director las estaciones no tienen nombre (se descubren jugando) y solo se ven las zonas (Lujo, Isla, Luna, Marte, Sistema solar, Galaxia). La reencarnación es una "combinación" que vuelve al inicio con ×1,6.'},
[
 {**metro([(1500, 'EL FISURA')], [('box', 100, 330, 880, 140, {'fill': (30, 30, 30, 230), 'label': '', 'r': 20}), ('txt', 540, 400, 'PRÓXIMA ESTACIÓN: DIOS.', 52, {'c': W}),
   ('img', 'homeless_face', 140, 1580, 150)]), 't': '0–2,5 s',
  'on': 'Cartel tipo andén: PRÓXIMA ESTACIÓN: DIOS. · el tren es la cara del Fisura', 'mv': 'Zoom cerrado sobre la estación 1.', 'sfx': 'Chicharra de puertas (sintetizada).'},
 {**metro([(1600, 'El Fisura'), (1450, 'El Trapito'), (1300, 'Limpiavidrios'), (1150, 'Cartonero'), (1000, 'El Mantero')], [('img', 'homeless_face', 140, 1080, 120),
   ('box', 560, 1700, 460, 90, {'label': 'ZONA CALLEJÓN', 'size': 30}), ('box', 240, 400, 600, 100, {'label': 'Combinación: 2 iguales', 'size': 30})]), 't': '2,5–7 s',
  'on': 'ZONA CALLEJÓN · estaciones 1–5 con nombre · "Combinación: fusioná 2 iguales"', 'mv': 'El tren arranca; cada estación se enciende al pasar.', 'sfx': 'Traqueteo en tempo + sfx_merge en cada estación.'},
 {**metro([(1500, 'Repartidor'), (1300, 'Chofer de App'), (1100, 'Fast Food')], [('box', 640, 1360, 380, 100, {'fill': (255, 200, 220, 230), 'label': 'six seven 🤷', 'size': 32}),
   ('box', 560, 1700, 460, 90, {'label': 'ZONA CIUDAD', 'size': 30})]), 't': '7–11 s',
  'on': 'ZONA CIUDAD · sticker "six seven 🤷" entre las estaciones 6 y 7', 'mv': 'El mapa se desliza hacia arriba.', 'sfx': 'Traqueteo.'},
 {**metro([(1250, 'Recién Recibido'), (560, 'Director')], [('txt', 560, 900, 'PROG · ARQ · MÉD · ABOG', 34), ('box', 160, 330, 760, 100, {'label': 'ELEGÍ TU CARRERA', 'size': 40}),
   ('txt', 540, 1650, 'Todas terminan en el mismo jefe.', 40)], branch=True), 't': '11–15 s',
  'on': 'ELEGÍ TU CARRERA (4 ramales) · "Todas terminan en el mismo jefe." (se juntan en Director)', 'mv': 'La línea se abre en 4 colores y se vuelve a juntar.', 'sfx': 'Acorde que se abre en 4 notas.'},
 {**metro([(1600, 'Director'), (1400, '???'), (1200, '???'), (1000, '???'), (800, '???'), (600, '???')], [('txt', 880, 1300, 'LUJO', 30), ('txt', 880, 1000, 'ISLA', 30), ('txt', 880, 700, 'LUNA', 30),
   ('box', 160, 330, 760, 120, {'label': '37 ESTACIONES', 'size': 44})]), 't': '15–20 s',
  'on': '37 ESTACIONES. LA MAYORÍA SIN NOMBRE (todavía). · solo se ven las zonas', 'mv': 'El mapa se aleja y acelera; líneas de velocidad.', 'sfx': 'Traqueteo rápido + riser.'},
 {**metro([(1500, 'El Fisura'), (700, '???')], [('line', [(140, 700), (900, 700), (900, 1500), (170, 1500)], {'c': (200, 160, 40), 'lw': 6}), ('txt', 700, 1100, 'COMBINACIÓN:\nREENCARNACIÓN', 40),
   ('box', 560, 1600, 300, 90, {'label': '×1,6', 'size': 44})]), 't': '20–23 s',
  'on': 'Combinación con REENCARNACIÓN → vuelve al inicio con ×1,6', 'mv': 'Una línea dorada punteada cierra el circuito.', 'sfx': 'sfx_prestige real.'},
 {**metro([(900, 'DIOS')], [('img', 'god', 540, 1500, 700, {'sil': 1}), ('txt', 540, 400, 'TERMINAL.', 70, {'c': W}), ('txt', 540, 500, '¿Te bajás antes?', 50, {'c': W})], bg='#30302E'), 't': '23–25 s',
  'on': 'TERMINAL: DIOS (silueta) · ¿Te bajás antes?', 'mv': 'La última estación brilla; el tren frena.', 'sfx': 'Frenada + coro suave.'},
 cta(['PRÓXIMA ESTACIÓN: VOS.', '¿HASTA DÓNDE VIAJÁS?'], 'Comentá en qué estación estás 👇'),
], OUT + 'v14_LineaF.jpg')
