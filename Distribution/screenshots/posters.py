"""Pósters promocionales de App Store, 1284x2778, hechos con el arte REAL del juego.

Sin IA: personajes y fondos salen del repo del juego. Los personajes se toman
de los originales 1024 del pipeline y se recortan con `core.cutout` (conectividad,
el mismo que no se come lo blanco del sujeto); si alguno no está, cae al atlas
512 que ya viene con alpha.
"""
import os, sys
sys.path.insert(0, "/Users/manuader/Desktop/projects/automatic-image-generation")

#: Idioma del titular (ver ai_posters.py). El arte es el mismo.
LANG = sys.argv[1] if len(sys.argv) > 1 else "es"
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
from core.cutout import cutout

W, H = 1284, 2778
GAME = "/Users/manuader/Desktop/projects/fisuevolution/FisuEvolution/Resources"
ORIG = "/Users/manuader/Desktop/projects/fisuevolution/Tools/asset-pipeline/dropbox/procesadas"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "posters-6.5" if LANG == "es" else f"posters-6.5-{LANG}")
os.makedirs(OUT, exist_ok=True)
FONT = "/System/Library/Fonts/SFNSRounded.ttf"


def font(size, weight="Black"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def character(key):
    """1024 recortado por conectividad; si no está, el atlas 512 con alpha."""
    p = os.path.join(ORIG, f"{key}.png")
    if os.path.exists(p):
        im = Image.open(p).convert("RGB")
        return cutout(im)
    for atlas in ("earth.atlas", "cosmic.atlas", "specials.atlas", "ui.atlas"):
        q = f"{GAME}/{atlas}/{key}_idle@3x.png"
        if os.path.exists(q):
            return Image.open(q).convert("RGBA")
    raise SystemExit(f"no encontré arte para {key}")


def trim(im):
    """Recorta el aire transparente alrededor para poder escalar por altura útil."""
    bb = im.getchannel("A").getbbox()
    return im.crop(bb) if bb else im


def backdrop(name, accent, darken=0.72):
    src = Image.open(f"{GAME}/Backgrounds/{name}@3x.png").convert("RGB")
    s = max(W / src.width, H / src.height)
    src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS)
    bg = src.crop(((src.width - W) // 2, (src.height - H) // 3,
                   (src.width - W) // 2 + W, (src.height - H) // 3 + H))
    bg = bg.filter(ImageFilter.GaussianBlur(5))
    bg = ImageEnhance.Brightness(bg).enhance(darken)
    bg = ImageEnhance.Color(bg).enhance(1.3)

    veil = Image.new("L", (1, H))
    for y in range(H):
        t = y / H
        a = int(175 - 105 * (t / 0.36)) if t < 0.36 else (int(120 * ((t - .82) / .18)) if t > .82 else 62)
        veil.putpixel((0, y), a)
    bg = Image.composite(Image.new("RGB", (W, H), (14, 11, 30)), bg, veil.resize((W, H)))

    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([-200, 1000, W + 200, 2500], fill=accent + (58,))
    return Image.alpha_composite(bg.convert("RGBA"), halo.filter(ImageFilter.GaussianBlur(190)))


def glow(im, accent, r=26):
    """Contorno luminoso para despegar al personaje del fondo."""
    a = im.getchannel("A")
    g = Image.new("RGBA", im.size, accent + (0,))
    g.putalpha(a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(r)))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.alpha_composite(g)
    out.alpha_composite(im)
    return out


def headline(canvas, lines, accent, top=190):
    d = ImageDraw.Draw(canvas)
    size = 122
    f = font(size)
    while max(d.textlength(l, font=f) for l in lines) > W - 150 and size > 58:
        size -= 4
        f = font(size)
    y = top
    for i, line in enumerate(lines):
        x = (W - d.textlength(line, font=f)) / 2
        for dx in range(-7, 8, 2):
            for dy in range(-7, 8, 2):
                if dx * dx + dy * dy <= 49:
                    d.text((x + dx, y + dy), line, font=f, fill=(15, 11, 28, 240))
        d.text((x, y), line, font=f, fill=(255, 255, 255) if i == 0 else accent)
        y += int(size * 1.17)
    return y


def place(canvas, im, target_h, cx, bottom, accent, halo=True):
    im = trim(im)
    s = target_h / im.height
    im = im.resize((max(1, int(im.width * s)), target_h), Image.LANCZOS)
    if halo:
        im = glow(im, accent)
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(bottom - im.height)))


def poster(key, bg, accent, lines, build):
    c = backdrop(bg, accent)
    y = headline(c, lines, accent)
    build(c, y, accent)
    p = os.path.join(OUT, f"{key}.png")
    c.convert("RGB").save(p, "PNG", optimize=True)
    return p


# ---- los cinco ----------------------------------------------------------
def p1(c, y, a):                                   # el Fisura, solo y grande
    place(c, character("homeless"), 1780, W / 2, H - 130, a)

def p2(c, y, a):                                   # la progresión, de chico a grande
    xs = [(215, 560), (450, 700), (740, 870), (1060, 1080)]
    for key, (cx, h) in zip(["homeless", "cartonero", "repartidor", "oficinista"], xs):
        place(c, character(key), h, cx, H - 230, a)

def p3(c, y, a):                                   # las cuatro carreras
    for key, cx, cy in [("junior_programmer", 380, 1760), ("junior_architect", 900, 1760),
                        ("junior_doctor", 380, 2620), ("junior_lawyer", 900, 2620)]:
        place(c, character(key), 720, cx, cy, a)

def p4(c, y, a):                                   # el rey del ladrillo y el millonario
    place(c, character("millonario"), 1080, 370, H - 210, a)
    place(c, character("rey_ladrillo"), 1320, 880, H - 150, a)

def p5(c, y, a):                                   # Dios, con su mate
    place(c, character("god"), 1620, W / 2, H - 120, a)


TITLES = {
    "es": [["Arrancás", "de fisura"], ["Fusioná", "y evolucioná"],
           ["Elegí tu destino", "(con título)"], ["Hacete el", "rey del ladrillo"],
           ["Llegá a Dios", "(literal)"]],
    "en": [["You start", "as a hobo"], ["Merge", "and evolve"],
           ["Pick your destiny", "(degree included)"], ["Become the", "brick king"],
           ["Reach God", "(literally)"]],
}

PANELS = [
    ("01_fisura",    "bg_alley",     (255, 196, 61),  p1),
    ("02_evolucion", "bg_urban",     (126, 235, 140), p2),
    ("03_carrera",   "bg_corporate", (120, 220, 255), p3),
    ("04_ladrillo",  "bg_luxury",    (255, 170, 220), p4),
    ("05_dios",      "bg_god_realm", (255, 225, 130), p5),
]

if __name__ == "__main__":
    for (key, bg, accent, fn), lines in zip(PANELS, TITLES[LANG]):
        p = poster(key, bg, accent, lines, fn)
        im = Image.open(p)
        print(f"[{LANG}] {os.path.basename(p):18} {im.width}x{im.height}  {os.path.getsize(p)//1024} KB")
