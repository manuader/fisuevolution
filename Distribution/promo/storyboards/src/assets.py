import sys; import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sb import asset, font, noemo
from PIL import Image, ImageDraw
G = [
 ('PERSONAJES (sprites reales, sin redibujar)', [('homeless', 'v10 v11 v13'), ('trapito', 'v10 v13'), ('junior_lawyer', 'v11'), ('millonario_idle__yate', 'v11'), ('ceo', 'v13'),
   ('dueno_luna', 'v11 v13'), ('space_billionaire', 'v10 · solo silueta'), ('god', 'v10 v12 v14 · solo silueta')]),
 ('CARAS (ui.atlas) para nodos, marcas y estaciones', [(k + '_face', u) for k, u in [('homeless', 'v12 v14'), ('trapito', 'v10 v12 v14'), ('limpiavidrios', 'v10 v12 v14'), ('cartonero', 'v10 v12 v14'),
   ('mantero', 'v14'), ('repartidor', 'v14'), ('chofer_app', 'v14'), ('fast_food', 'v14'), ('junior_programmer', 'v14'), ('junior_architect', 'v14'), ('junior_doctor', 'v14'), ('junior_lawyer', 'v14'), ('director', 'v14')]]),
 ('UI Y EFECTOS DEL JUEGO', [('ui_coin', 'todas'), ('fx_merge', 'v10 v13'), ('fx_tap', 'v10 v12'), ('ui_boost_mate', 'v11 v12'), ('ui_up_income', 'v12'), ('ui_oro', 'v11 v12'),
   ('ui_btn_reincarnate', 'v12'), ('ui_menu_trophy', 'v13'), ('ui_million', 'v10'), ('ui_billion', 'v10')]),
 ('FONDOS (en v10/v12/v14 como bandas de color o desenfocados; en v13 dentro del juego)', [(f'bg_{b}', '') for b in ['alley', 'urban', 'corporate', 'luxury', 'island', 'moon', 'mars', 'solar', 'galaxy', 'god_realm']]),
 ('MARCA', [('app_icon', 'cierres'), ('adergames_logo', 'cierres')]),
 ('¿LOS USO? poses del Fisura (recorte limpio, verificar)', [('fisura_wave', 'v13 cierre (opcional)')]),
 ('NO SE USAN', [('fisura_point', 'otro estilo de dibujo'), ('fisura_celebrate', 'recorte con blanco'), ('fisura_explain', 'tiene fondo'), ('ui_boost_fernet', 'alcohol')]),
]
TW, TH, M = 150, 150, 18
COLS = 8
rows = sum((len(it) + COLS - 1) // COLS for _, it in G)
H = 120 + len(G) * 50 + rows * (TH + 54) + M
Wd = COLS * (TW + M) + M
im = Image.new('RGB', (Wd, H), '#F7F5F0'); d = ImageDraw.Draw(im)
d.text((M, 20), 'ASSETS PARA v10–v14 · para aprobar', font=font(34, True), fill='#222')
d.text((M, 66), 'Todo sale de FisuEvolution/Resources (atlas, fondos, SFX) y de render/assets (ícono, logo). Música: sintetizada (synth.py). Sin IA, sin stock, sin fotos.', font=font(15), fill='#444')
y = 110
for title, items in G:
    col = '#B03A2E' if title.startswith('NO') else '#C2502E' if title.startswith('¿') else '#222'
    d.text((M, y), noemo(title), font=font(18, True), fill=col); y += 34
    for i, (k, use) in enumerate(items):
        c, r = i % COLS, i // COLS
        x0 = M + c * (TW + M); y0 = y + r * (TH + 54)
        d.rectangle([x0, y0, x0 + TW, y0 + TH], fill='#E3DFD6' if not k.startswith('bg_') else '#ccc')
        a = asset(k).copy(); a.thumbnail((TW - 10, TH - 10))
        if k.startswith('bg_'):
            a = asset(k).copy(); a.thumbnail((TW, TH))
        im.paste(a, (x0 + (TW - a.width) // 2, y0 + (TH - a.height) // 2), a)
        if title.startswith('NO'): d.line([x0, y0, x0 + TW, y0 + TH], fill='#B03A2E', width=4); d.line([x0 + TW, y0, x0, y0 + TH], fill='#B03A2E', width=4)
        d.text((x0, y0 + TH + 4), k, font=font(11, True), fill='#222')
        d.text((x0, y0 + TH + 20), use, font=font(11), fill='#555')
    y += ((len(items) + COLS - 1) // COLS) * (TH + 54) + 16
im = im.crop((0, 0, Wd, y + M))
im.save('/home/user/fisuevolution/Distribution/promo/storyboards/assets_v10-v14.jpg', quality=90); print(im.size)
