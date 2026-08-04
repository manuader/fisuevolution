#!/usr/bin/env python3
"""Genera los .md de Gemini Pro y las entradas de prompts.json para las skins.

Una skin es "el mismo personaje con otra ropa": conserva pose, cuerpo, cara y
expresión del original, y cambia SOLO vestuario, props y paleta. Por eso el
prompt adjunta como referencia el PNG del propio personaje (no el Fisura) y se
lo dice explícitamente al modelo.

El cambio cromático tiene que ser fuerte, y no sólo por diseño: el runner
descarta la imagen generada si su huella de píxeles se parece demasiado a la
referencia adjunta. Una skin tímida se confundiría con el original y quedaría
descartada hasta el timeout.

    .venv/bin/python scripts/gen_skin_prompts.py [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PIPELINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PIPELINE / "scripts"))

from cultural_dict import CHARACTERS  # noqa: E402

PROMPTS_DIR = PIPELINE / "prompts" / "gemini_pro"
PROMPTS_JSON = PIPELINE / "prompts" / "prompts.json"
REPO = PIPELINE.parent.parent
TIERS = REPO / "FisuEvolution" / "Resources" / "Data" / "tiers.json"

STYLE_LINE = (
    "Match EXACTLY the art style, line weight, proportions and color treatment "
    "of the attached reference character — same game, same studio."
)
FRAMING_LINE = (
    "Full body standing character, both feet planted on the ground, hands "
    "visible, complete figure with generous margins, centered on a plain pure "
    "white background, square image, no text, no watermark, no cropping."
)

# Personajes sin original pre-rembg en dropbox/procesadas/: el Fisura vive como
# hero aprobado y junior_programmer sólo quedó en el atlas del juego.
REFERENCE_OVERRIDES = {
    "homeless": "heroes/approved/fisura.png",
    "junior_programmer": "../../FisuEvolution/Resources/earth.atlas/junior_programmer_idle@3x.png",
}

# skinId, nombre es, nombre en, y QUÉ CAMBIA (vestuario/props/paleta).
# El id no se repite entre personajes: es la clave del catálogo.
SKINS: dict[str, tuple[str, str, str, str]] = {
    "homeless": (
        "second_life", "Segunda Vida", "Second Life",
        "he came back from the other side: his tattered coats are now ghostly "
        "translucent white and pale spectral blue, the green bottle glows with "
        "soft blue light like a spirit lamp, a thin halo of pale light floats "
        "over the patched beanie, and faint wisps of blue mist trail from his "
        "shoulders. Palette shifts from dirty browns to cold white-blue",
    ),
    "cartonero": (
        "urban_trailblazer", "Pionero Urbano", "Urban Trailblazer",
        "he became the explorer of the city: khaki safari jacket with many "
        "pockets and a wide-brimmed explorer hat replace the hi-vis vest, the "
        "hand cart is now a canvas-covered expedition wagon with a rolled map "
        "and a lantern strapped to it, binoculars hang from his neck. Palette "
        "shifts from grey street tones to warm khaki, olive and leather brown",
    ),
    "kiosco": (
        "nocturno", "Turno Noche", "Night Shift",
        "the kiosk went neon: his apron is deep midnight blue, the counter and "
        "snack racks glow with hot pink and cyan neon tubes, a small buzzing "
        "neon sign floats beside him, and everything is lit from below with "
        "electric magenta. Palette shifts from daylight colors to dark navy "
        "with vivid neon pink and cyan",
    ),
    "repartidor": (
        "cohete", "Reparto Cohete", "Rocket Courier",
        "delivery went orbital: a chrome jetpack with two lit thrusters is "
        "strapped to his back, his bike is gone, the delivery backpack is a "
        "sleek white-and-orange capsule with a glowing seal, and he wears "
        "aviator goggles. Palette shifts to white, chrome silver and hot orange",
    ),
    "chofer_app": (
        "taxi_clasico", "Taxi Clásico", "Classic Cab",
        "he drives the old porteño cab now: black jacket with a yellow roof-"
        "light emblem, a chequered black-and-yellow cap, a paper street guide "
        "under his arm and an old mechanical fare meter in his hand instead of "
        "the phone. Palette shifts to glossy black and taxi yellow",
    ),
    "fast_food": (
        "chef_estrella", "Chef de Estrella", "Star Chef",
        "he graduated to fine dining: crisp white double-breasted chef jacket "
        "and a tall pleated toque replace the fast food uniform, he holds a "
        "silver cloche platter instead of the paper bag, and a small gold star "
        "medal is pinned to his chest. Palette shifts from red-and-yellow fast "
        "food colors to pristine white, silver and gold",
    ),
    "oficinista": (
        "home_office", "Home Office", "Home Office",
        "the office moved home: striped pyjamas and fluffy slippers replace the "
        "shirt and shoes, a knitted blanket is draped over his shoulders like a "
        "cape, he holds a big mate gourd in one hand, and the laptop rests on a "
        "cushion. Palette shifts from office grey-blue to cozy cream, soft "
        "green and warm brown",
    ),
    "administrativo": (
        "sindicalista", "Delegado Sindical", "Union Rep",
        "he took over the union: a leather jacket over a union t-shirt, a "
        "megaphone raised in one hand instead of the folders, a whistle around "
        "his neck and a rolled banner under his arm. Palette shifts from beige "
        "office tones to bold red, black and white",
    ),
    "junior_programmer": (
        "hacker", "Modo Hacker", "Hacker Mode",
        "he went underground: a black hoodie with the hood up shadowing his "
        "face, the sticker-covered laptop now glows acid green with cascading "
        "code reflected on his glasses, and thin green data streams float "
        "around him. Palette shifts to near-black with vivid acid green",
    ),
    "junior_architect": (
        "obra", "Pie de Obra", "On Site",
        "he left the studio for the building site: a bright yellow hard hat, "
        "an orange hi-vis vest over the shirt, muddy work boots, and the "
        "drawing tube is replaced by a bundle of rolled blueprints and a spirit "
        "level. Palette shifts to safety yellow, hi-vis orange and concrete grey",
    ),
    "junior_doctor": (
        "guardia", "Guardia", "ER Shift",
        "straight out of a night in the emergency room: rumpled teal surgical "
        "scrubs, a paper cap and a surgical mask pulled down under his chin, "
        "the stethoscope now slung over one shoulder, plus a clipboard of "
        "charts. Palette shifts from white coat to teal-green scrubs",
    ),
    "junior_lawyer": (
        "tribunales", "Tribunales", "Courthouse",
        "he made it to the courtroom: a black judicial robe with a white "
        "starched collar over the suit, a wooden gavel in one hand and a thick "
        "leather-bound code under the other arm. Palette shifts to deep black, "
        "white and dark polished wood",
    ),
    "senior_programmer": (
        "open_source", "Gurú Open Source", "Open Source Guru",
        "he became the bearded sage of the community: a long grey beard, a "
        "faded conference t-shirt under an open plaid shirt, sandals, and a "
        "vintage mechanical keyboard held like a sacred tablet. Palette shifts "
        "to earthy plaid reds and browns with grey hair",
    ),
    "senior_architect": (
        "starchitect", "Arquitecto Estrella", "Starchitect",
        "he became a design celebrity: an all-black turtleneck and black "
        "designer glasses, a minimalist white scale model of a tower held on "
        "one palm, and a sleek black portfolio case. Palette shifts to stark "
        "monochrome black and white",
    ),
    "senior_doctor": (
        "cirujano", "Cirujano", "Surgeon",
        "he stepped into the operating room: a sterile blue surgical gown, "
        "surgical loupes over his eyes, blue gloves raised at chest height, "
        "and a bright overhead surgical lamp glow on him. Palette shifts to "
        "sterile surgical blue with bright white light",
    ),
    "senior_lawyer": (
        "penalista", "Penalista", "Criminal Defense",
        "he took the big criminal cases: a sharp pinstriped double-breasted "
        "suit, dark sunglasses, a slim metal briefcase chained to his wrist and "
        "a cigar. Palette shifts to charcoal pinstripe with deep burgundy",
    ),
    "director": (
        "directorio", "Sala de Directorio", "Boardroom",
        "he now runs the board: a tailored charcoal three-piece suit with a "
        "silk pocket square, a laser pointer in one hand and a floating bar "
        "chart hologram beside him. Palette shifts to charcoal grey with cool "
        "corporate blue accents",
    ),
    "fundador_startup": (
        "unicornio", "Unicornio", "Unicorn",
        "the startup hit unicorn status: a pastel purple hoodie with a small "
        "unicorn horn on the hood, iridescent rainbow sneakers, and the "
        "lightbulb is replaced by a glowing pastel unicorn figurine. Palette "
        "shifts to pastel lilac, mint and iridescent rainbow",
    ),
    "dueno_pyme": (
        "industrial", "Nave Industrial", "Industrial",
        "the shop became a factory: a navy work coverall with the sleeves "
        "rolled up, welding goggles pushed up on his forehead, a clipboard of "
        "production orders and a steel toolbox at his feet. Palette shifts to "
        "industrial navy blue, steel grey and warning orange",
    ),
    "emprendedor": (
        "conferencia", "Charla TED", "Keynote",
        "he sells the vision from the stage: a slim black turtleneck with a "
        "clip-on headset microphone, a clicker in his hand and a big glowing "
        "presentation slide floating behind his shoulder. Palette shifts to "
        "black with a bright stage-lit blue glow",
    ),
    "ceo": (
        "magnate", "Magnate", "Tycoon",
        "peak corporate excess: a cream double-breasted suit with a fur-collared "
        "overcoat draped over the shoulders, a diamond tie pin, and a fat cigar "
        "clamped in his teeth. Palette shifts from dark suit to cream, camel "
        "fur and glinting diamond white",
    ),
    "millonario": (
        "yate", "Yate", "Yacht",
        "he took the money to sea: a navy blazer with gold buttons over a "
        "striped sailor shirt, a white captain's cap with gold braid, boat "
        "shoes, and a champagne glass in hand. Palette shifts to navy, crisp "
        "white and gold",
    ),
    "multimillonario": (
        "filantropo", "Filántropo", "Philanthropist",
        "he is buying his legacy: a soft grey cardigan over an open shirt, "
        "half-moon reading glasses, an oversized charity cheque held in both "
        "hands instead of the banknotes. Palette shifts from flashy tones to "
        "warm muted grey, cream and soft green",
    ),
    "rey_ladrillo": (
        "rascacielos", "Rascacielos", "Skyscraper",
        "he builds only towers now: a golden hard hat, a long white architect "
        "coat, and a tall glass skyscraper model held upright beside him "
        "instead of the bricks. Palette shifts from brick red to gold, white "
        "and glass blue",
    ),
    "magnate_petrolero": (
        "esquisto", "Esquisto", "Shale Baron",
        "he moved to the shale fields: a long oiled duster coat, a wide "
        "cattleman hat, leather gloves and a small black gushing derrick model "
        "at his side, with dark oil sheen on everything. Palette shifts to "
        "black leather, oil-slick iridescence and desert tan",
    ),
    "space_billionaire": (
        "traje_presurizado", "Traje Presurizado", "Pressure Suit",
        "he suited up for real: a sleek white pressure suit with a clear bubble "
        "helmet tucked under one arm, blue life-support lines running along the "
        "torso and heavy magnetic boots. Palette shifts to glossy white, "
        "chrome and electric blue",
    ),
    "trillonario": (
        "moneda_propia", "Moneda Propia", "Own Currency",
        "he printed his own money: a suit woven from banknote patterns, a "
        "crown of stacked coins, and a floating holographic currency symbol "
        "bearing his own face spinning beside him. Palette shifts to banknote "
        "green, gold and holographic cyan",
    ),
    "dueno_luna": (
        "selenita", "Selenita", "Selenite",
        "he went native on the moon: a suit of grey moon-rock plates, a helmet "
        "shaped from a crater, glowing pale-blue moon dust drifting around his "
        "boots and a small flag planted at his side. Palette shifts to lunar "
        "grey, chalk white and pale glowing blue",
    ),
    "dueno_marte": (
        "terraformador", "Terraformador", "Terraformer",
        "he is greening the red planet: a rust-red exosuit with a transparent "
        "greenhouse dome backpack full of sprouting plants, a watering "
        "apparatus in one hand and green shoots pushing through the red soil at "
        "his feet. Palette shifts to rust red with vivid living green",
    ),
    "magnate_solar": (
        "corona_solar", "Corona Solar", "Solar Corona",
        "he wears the star itself: robes of white-hot plasma with flowing solar "
        "flares along the sleeves, a crown of fire, and a small blazing sun "
        "orbiting his open hand. Palette shifts to incandescent white, blazing "
        "orange and deep solar red",
    ),
    "senor_galaxia": (
        "agujero_negro", "Agujero Negro", "Black Hole",
        "he mastered the dark side of the galaxy: a black void cloak whose "
        "edges bend the starlight around them, a glowing accretion-disc ring "
        "tilted behind his shoulders, and light visibly spiralling into his "
        "palm. Palette shifts to absolute black with searing orange-white "
        "accretion light",
    ),
    "emperador_cosmico": (
        "dinastia", "Dinastía", "Dynasty",
        "the empire became a dynasty: heavy imperial armour of engraved gold "
        "over deep purple robes, a taller crown fused with a ringed planet, and "
        "the sceptre is now a long ceremonial staff with a comet at its tip. "
        "Palette shifts to imperial purple and heavy engraved gold",
    ),
    "ser_ascendido": (
        "iluminado", "Iluminado", "Enlightened",
        "he completed the ascension: his body is translucent pure light with "
        "constellations visible inside it, concentric golden rings rotate around "
        "his torso, and his feet float just above the ground. Palette shifts to "
        "luminous white-gold with deep indigo",
    ),
    "semidios": (
        "titan", "Titán", "Titan",
        "he chose raw power: cracked stone-and-bronze titan armour with molten "
        "light glowing through the cracks, a thunderbolt gripped like a spear, "
        "and storm clouds curling around his shoulders. Palette shifts to "
        "weathered bronze, dark stone and molten orange",
    ),
    "deidad": (
        "oraculo", "Oráculo", "Oracle",
        "she turned inward to prophecy: flowing white-and-indigo temple robes, "
        "a blindfold of woven gold over the eyes, and the four hands now hold a "
        "candle, an hourglass, a star chart and a mate gourd. Palette shifts to "
        "deep indigo, temple white and soft gold",
    ),
    "god": (
        "genesis", "Génesis", "Genesis",
        "the very first day: robes of raw creation light, the cloud beard now "
        "made of swirling nebula, and instead of a finished universe his open "
        "palm holds a single bright spark about to become one. Palette shifts "
        "to pure white and gold with newborn-nebula pink and cyan",
    ),
}

# Piso al que hay que llegar para ganar la skin: el SIGUIENTE al del personaje
# (se lee como recuerdo de haberlo superado). El tope de la torre no tiene
# "siguiente", así que se gana reencarnando.
FLOOR_OF_TIER = [
    (1, 2, "alley", "urban"),
    (3, 5, "urban", "corporate"),
    (6, 9, "corporate", "luxury"),
    (10, 13, "luxury", "island"),
    (14, 17, "island", "moon"),
    (18, 21, "moon", "mars"),
    (22, 23, "mars", "solar"),
    (24, 25, "solar", "galaxy"),
    (26, 27, "galaxy", "cosmic"),
    (28, 29, "cosmic", "god_realm"),
    (30, 30, "god_realm", None),
]

# Milestones ya publicados: no se tocan, hay tests que dependen de ellos.
PINNED_MILESTONES = {
    "second_life": {"reincarnations": 1},
    "urban_trailblazer": {"floorReached": "urban"},
}


def unlock_for(tier: int, skin_id: str) -> dict:
    if skin_id in PINNED_MILESTONES:
        return dict(PINNED_MILESTONES[skin_id])
    for first, last, _floor, next_floor in FLOOR_OF_TIER:
        if first <= tier <= last:
            return {"floorReached": next_floor} if next_floor else {"reincarnations": 3}
    raise ValueError(f"tier fuera de la torre: {tier}")


def short_subject(subject: str) -> str:
    """Primer sintagma del subject, para nombrar al personaje sin repetir la pose."""
    return subject.split(" standing")[0].split(",")[0].strip()


def build_prompt(char_id: str, display: str, skin_name_en: str, change: str) -> str:
    entry = CHARACTERS[char_id]
    return "\n\n".join([
        STYLE_LINE,
        (
            f"{display} — ALTERNATE OUTFIT \"{skin_name_en}\". This is the same "
            f"character as the attached reference: the {short_subject(entry['subject'])} "
            f"from Fisura Evolution, an Argentine merge-idle mobile game. Keep his "
            f"pose, body proportions, face and his {entry['expression']} EXACTLY as "
            f"in the reference — the silhouette must read as the same character. "
            f"Change ONLY the clothing, the props and the palette: {change}. The "
            f"new outfit must be boldly different in color from the reference so "
            f"the two are never confused at a glance."
        ),
        FRAMING_LINE,
    ])


def build_oro_prompt() -> str:
    return "\n\n".join([
        (
            "ORO is a UI icon for Fisura Evolution, an Argentine merge-idle mobile "
            "game. Design it as a premium prestige currency icon, featuring: a "
            "chunky golden ingot bar seen at a slight angle with a bright four-"
            "point sparkle glinting off its top corner, clearly richer and rarer "
            "than a plain coin."
        ),
        (
            "Flat, simple icon in the same visual language as the rest of the game: "
            "uniform thick black outline, flat colors with minimal cel-shading, no "
            "gradients, no photorealism. Centered on a plain pure white background, "
            "square image, generous margins, no text, no watermark, no cropping."
        ),
    ])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    tiers = {t["id"]: t for t in json.loads(TIERS.read_text())["types"]}
    prompts = json.loads(PROMPTS_JSON.read_text())
    known = {entry["assetKey"] for entry in prompts}

    # Los .md nuevos arrancan después del último número usado.
    used = sorted(int(p.name[:3].rstrip("_")) for p in PROMPTS_DIR.glob("[0-9][0-9]*.md"))
    order = max(used) + 1

    catalog: list[dict] = []
    written = 0
    for char_id, (skin_id, name_es, name_en, change) in SKINS.items():
        tier_entry = tiers[char_id]
        asset_key = f"{char_id}__{skin_id}"
        reference = REFERENCE_OVERRIDES.get(char_id, f"dropbox/procesadas/{char_id}.png")
        phase = "cosmic" if tier_entry["phase"] == "cosmic" else "earth"

        body = "\n".join([
            f"# {order} — {name_es} (skin de {tier_entry['displayName']})",
            "",
            f"- **archivo**: `{asset_key}.png`",
            "- **estado**: pendiente",
            f"- **referencia**: adjuntar `{reference}`",
            "- **destino**: Tools/asset-pipeline/dropbox/",
            "",
            "## Prompt",
            "",
            build_prompt(char_id, tier_entry["displayName"], name_en, change),
            "",
        ])
        target = PROMPTS_DIR / f"{order}_{asset_key}.md"
        if not args.dry_run:
            target.write_text(body, encoding="utf-8")
        written += 1

        if asset_key not in known:
            prompts.append({
                "assetKey": asset_key,
                "category": "skin",
                "atlas": phase,
                "prompt": build_prompt(char_id, tier_entry["displayName"], name_en, change),
            })

        catalog.append({
            "id": skin_id,
            "characterType": char_id,
            "treatment": "texture",
            "textureKey": f"{char_id}_idle__{skin_id}",
            "displayNameKey": f"skin.name.{skin_id}",
            **unlock_for(tier_entry["tier"], skin_id),
        })
        order += 1

    # Icono ORO: el único asset de UI que pedía F7.6.
    oro_md = "\n".join([
        f"# {order} — Icono ORO (UI — Currency)",
        "",
        "- **archivo**: `ui_oro.png`",
        "- **estado**: pendiente",
        "- **destino**: Tools/asset-pipeline/dropbox/",
        "",
        "## Prompt",
        "",
        build_oro_prompt(),
        "",
    ])
    if not args.dry_run:
        (PROMPTS_DIR / f"{order}_ui_oro.md").write_text(oro_md, encoding="utf-8")
    if "ui_oro" not in known:
        prompts.append({
            "assetKey": "ui_oro",
            "category": "ui",
            "prompt": build_oro_prompt(),
        })

    if not args.dry_run:
        PROMPTS_JSON.write_text(json.dumps(prompts, indent=2, ensure_ascii=False))
        (PIPELINE / "prompts" / "skins_catalog.json").write_text(
            json.dumps(catalog, indent=2, ensure_ascii=False)
        )

    print(f"{written} prompts de skin + icono ORO")
    print(f"entradas en prompts.json: {len(prompts)}")
    print(f"catálogo intermedio: prompts/skins_catalog.json ({len(catalog)} skins)")


if __name__ == "__main__":
    main()
