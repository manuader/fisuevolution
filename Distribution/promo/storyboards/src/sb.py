# Storyboards de baja fidelidad: bocetos en grises con los assets reales en su lugar.
import math, os, sys, re
EMO = re.compile('[\U0001F000-\U0001FFFF\u2600-\u27BF\u23F0\uFE0F]')
def noemo(x): return re.sub(' +', ' ', EMO.sub('', x)).strip()
from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageFilter
RES = '/home/user/fisuevolution/FisuEvolution/Resources/'
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(s, b=False): return ImageFont.truetype(FB if b else F, s)
PW, PH = 300, 533           # viñeta 9:16
K = PW / 1080               # escala lógica → viñeta
CAPH = 230
COLS = 4
_cache = {}
def asset(key):
    if key in _cache: return _cache[key]
    p = key if key.startswith('/') else None
    if not p:
        for c in [RES + 'earth.atlas/' + key + '@3x.png', RES + 'cosmic.atlas/' + key + '@3x.png', RES + 'ui.atlas/' + key + '@3x.png',
                  RES + 'specials.atlas/' + key + '@3x.png', RES + 'Backgrounds/' + key + '@3x.png', RES + 'ChestAnim/' + key + '.png',
                  '/home/user/fisuevolution/Distribution/promo/render/assets/' + key + '.png']:
            if os.path.exists(c): p = c; break
    if not p:
        for d in ['earth.atlas', 'cosmic.atlas']:
            c = RES + d + '/' + key + '_idle@3x.png'
            if os.path.exists(c): p = c; break
    im = Image.open(p).convert('RGBA'); bb = im.getchannel('A').getbbox()
    if bb: im = im.crop(bb)
    _cache[key] = im; return im
def gray(im, a=.85):
    g = ImageOps.grayscale(im.convert('RGB')); g = ImageOps.autocontrast(g, cutoff=1)
    g = g.point(lambda v: 90 + v * .6)
    out = Image.merge('RGBA', (g, g, g, im.getchannel('A').point(lambda v: int(v * a))))
    return out

def panel(spec):
    im = Image.new('RGB', (PW, PH), spec.get('bg', '#E9E6E0'))
    d = ImageDraw.Draw(im, 'RGBA')
    for el in spec['els']:
        t = el[0]
        if t == 'bgimg':
            b = gray(asset(el[1]), .55).resize((PW, int(PW * asset(el[1]).height / asset(el[1]).width)))
            im.paste(b, (0, int((PH - b.height) / 2)), b)
        elif t == 'img':
            _, key, cx, by, h = el[:5]; o = el[5] if len(el) > 5 else {}
            a = asset(key); w = h * a.width / a.height
            g = gray(a, o.get('a', .9)).resize((max(1, int(w * K)), max(1, int(h * K))))
            if o.get('sil'): g = Image.merge('RGBA', (*[g.getchannel('A').point(lambda v: 0)] * 3, g.getchannel('A')))
            if o.get('flip'): g = ImageOps.mirror(g)
            im.paste(g, (int(cx * K - g.width / 2), int(by * K - g.height)), g)
        elif t == 'box':
            _, x, y, w, h = el[:5]; o = el[5] if len(el) > 5 else {}
            d.rounded_rectangle([x * K, y * K, (x + w) * K, (y + h) * K], radius=o.get('r', 24) * K,
                                fill=o.get('fill', (255, 255, 255, 160)), outline=o.get('line', (60, 60, 60, 255)), width=o.get('lw', 2))
            if o.get('label'):
                fs = int(o.get('size', 36) * K * 1.6); lab = noemo(o['label'])
                while d.textlength(lab, font=font(fs, True)) > w * K - 10 and fs > 7: fs -= 1
                d.text(((x + w / 2) * K, (y + h / 2) * K), lab, font=font(fs, True), fill=o.get('tc', (40, 40, 40)), anchor='mm')
        elif t == 'txt':
            _, cx, cy, s, size = el[:5]; o = el[5] if len(el) > 5 else {}
            fs = int(size * K * 1.25)
            lines = noemo(s).split('\n')
            for i, ln in enumerate(lines):
                yy = cy * K + (i - (len(lines) - 1) / 2) * fs * 1.15
                f = font(fs, o.get('b', True))
                while d.textlength(ln, font=f) > PW - 14 and fs > 7: fs -= 1; f = font(fs, o.get('b', True))
                if o.get('hl'): 
                    tw = d.textlength(ln, font=f); d.rectangle([cx * K - tw / 2 - 4, yy - fs * .62, cx * K + tw / 2 + 4, yy + fs * .62], fill=o['hl'])
                d.text((cx * K, yy), ln, font=f, fill=o.get('c', (30, 30, 30)), anchor='mm', stroke_width=o.get('sw', 0), stroke_fill='white')
        elif t == 'circle':
            _, cx, cy, r = el[:4]; o = el[4] if len(el) > 4 else {}
            d.ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=o.get('fill'), outline=o.get('line', (60, 60, 60)), width=o.get('lw', 2))
        elif t == 'line':
            _, pts = el[:2]; o = el[2] if len(el) > 2 else {}
            d.line([(x * K, y * K) for x, y in pts], fill=o.get('c', (60, 60, 60)), width=o.get('lw', 3), joint='curve')
        elif t == 'arrow':
            _, x1, y1, x2, y2 = el[:5]; o = el[5] if len(el) > 5 else {}
            c = o.get('c', (200, 70, 50)); d.line([(x1 * K, y1 * K), (x2 * K, y2 * K)], fill=c, width=3)
            ang = math.atan2(y2 - y1, x2 - x1)
            for s in (-1, 1): d.line([(x2 * K, y2 * K), (x2 * K - 12 * math.cos(ang + s * .5), y2 * K - 12 * math.sin(ang + s * .5))], fill=c, width=3)
            if o.get('label'): d.text(((x1 + x2) / 2 * K + 6, (y1 + y2) / 2 * K), o['label'], font=font(11, True), fill=c, anchor='lm')
        elif t == 'tree':  # árbol binario: niveles desde abajo
            _, levels, top, bot = el[:4]
            for L in range(levels):
                n = 2 ** (levels - 1 - L); y = bot - (bot - top) * L / max(1, levels - 1)
                for i in range(n):
                    x = 60 + (960) * (i + .5) / n
                    if L < levels - 1:
                        pn = n // 2; px = 60 + 960 * (i // 2 + .5) / pn; py = bot - (bot - top) * (L + 1) / max(1, levels - 1)
                        d.line([(x * K, y * K), (px * K, py * K)], fill=(120, 120, 120), width=1)
                    r = max(1.2, 9 * K * 3 / (1 + L * 0 + math.log2(n + 1)))
                    d.ellipse([x * K - r, y * K - r, x * K + r, y * K + r], fill=(70, 70, 70))
        elif t == 'noise':
            import random; r = random.Random(el[1])
            for _ in range(el[2]): x, y = r.random() * PW, r.random() * PH; d.point((x, y), fill=(60, 60, 60))
    # safe zones de Reels/TikTok
    for y0, y1 in [(0, .12), (.80, 1)]:
        d.rectangle([0, y0 * PH, PW, y1 * PH], fill=(255, 80, 80, 22))
    d.rectangle([0, 0, PW - 1, PH - 1], outline=(40, 40, 40), width=2)
    return im

def wraptext(d, s, f, w):
    out = []
    for para in s.split('\n'):
        cur = ''
        for wd in para.split(' '):
            tt = (cur + ' ' + wd).strip()
            if d.textlength(tt, font=f) > w and cur: out.append(cur); cur = wd
            else: cur = tt
        out.append(cur)
    return out

def board(meta, panels, path):
    rows = (len(panels) + COLS - 1) // COLS
    M = 24; HEAD = 210
    W = COLS * PW + (COLS + 1) * M
    H = HEAD + rows * (PH + CAPH + M) + M
    im = Image.new('RGB', (W, H), '#F7F5F0'); d = ImageDraw.Draw(im)
    d.text((M, 22), meta['title'], font=font(36, True), fill='#222')
    d.text((M, 72), noemo(meta['sub']), font=font(19, True), fill='#C2502E')
    y = 106
    for ln in wraptext(d, noemo(meta['desc']), font(16), W - 2 * M):
        d.text((M, y), ln, font=font(16), fill='#333'); y += 22
    for i, p in enumerate(panels):
        r, c = divmod(i, COLS)
        x0 = M + c * (PW + M); y0 = HEAD + r * (PH + CAPH + M)
        im.paste(panel(p), (x0, y0))
        d.rounded_rectangle([x0 + 8, y0 + 8, x0 + 92, y0 + 34], radius=8, fill='#222')
        d.text((x0 + 50, y0 + 21), f"{i + 1} · {p['t']}", font=font(13, True), fill='white', anchor='mm')
        yy = y0 + PH + 8
        for lab, key, col in [('PANTALLA', 'on', '#222'), ('MOVIMIENTO', 'mv', '#555'), ('AUDIO', 'sfx', '#2E6FC2')]:
            if not p.get(key): continue
            f = font(13, key == 'on')
            lines = wraptext(d, noemo(p[key]), f, PW - 4)
            d.text((x0, yy), lab, font=font(10, True), fill=col); yy += 14
            for ln in lines[:5]: d.text((x0, yy), ln, font=f, fill=col); yy += 16
            yy += 4
    im.save(path, quality=90)
    print(path, im.size)
