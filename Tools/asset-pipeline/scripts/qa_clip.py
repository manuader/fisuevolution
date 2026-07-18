#!/usr/bin/env python3
"""QA de consistencia POR FAMILIA: CLIP + paleta + transparencia + contact sheet.

Familias de QA (config.qa.families): characters / ui / backgrounds / fx.
Los specials se validan contra el centroide de `characters`.

1) Calibrar (una vez por familia, tras el mini-gate humano que aprueba las
   anclas — heroes para characters; los primeros 3-4 aprobados a mano para
   ui/backgrounds/fx):

     python3 scripts/qa_clip.py --calibrate --family characters \
         --anchors heroes/approved/hero_fisura_01.png heroes/approved/hero_cartonero_01.png ...

   Persiste anchors + umbral (= min(sim vs centroide) - 0.02, piso 0.75 inicial)
   en config.json y el centroide en state/centroids/{family}.json.

2) Batch de una tanda (tras cutout_batch):

     python3 scripts/qa_clip.py --batch 1

   Por asset: score coseno CLIP vs centroide de su familia + paleta dominante
   (Pillow: cuantizar y medir distancia al set lockeado del doc, seccion 3) +
   fondo transparente (excepto backgrounds) + contact sheet de 120px para
   revision humana de silueta/outline.
   Pasa -> approved/{key}.png ; falla -> state/regen_queue.json con motivo.
   Reporte completo en state/qa_report.json.

open_clip/PIL/torch se importan dentro de las funciones que los usan.
"""
import argparse
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import (  # noqa: E402
    ROOT, load_config, save_config, load_prompts, entries_for_tanda,
    write_json, read_json,
)


# ---------------------------------------------------------------------------
# CLIP
# ---------------------------------------------------------------------------

_CLIP_CACHE = {}


def _clip(config):
    """Carga (una vez) modelo open_clip segun config.qa."""
    if not _CLIP_CACHE:
        import open_clip  # pip install open_clip_torch
        import torch

        name = config["qa"]["clip_model"]
        pretrained = config["qa"]["clip_pretrained"]
        print(f"Cargando open_clip {name} ({pretrained})...")
        model, _, preprocess = open_clip.create_model_and_transforms(
            name, pretrained=pretrained
        )
        model.eval()
        _CLIP_CACHE.update(model=model, preprocess=preprocess, torch=torch)
    return _CLIP_CACHE


def embed_image(config, path):
    from PIL import Image

    c = _clip(config)
    torch = c["torch"]
    img = Image.open(path).convert("RGBA")
    # Componer sobre blanco: alpha no aporta al embedding y evita ruido.
    from PIL import Image as _I

    base = _I.new("RGB", img.size, (255, 255, 255))
    base.paste(img, mask=img.split()[3])
    tensor = c["preprocess"](base).unsqueeze(0)
    with torch.no_grad():
        feat = c["model"].encode_image(tensor)
        feat = feat / feat.norm(dim=-1, keepdim=True)
    return feat[0].cpu().tolist()


def _cosine(a, b):
    return sum(x * y for x, y in zip(a, b))


def _normalize(v):
    norm = sum(x * x for x in v) ** 0.5
    return [x / norm for x in v]


def centroid_path(config, family):
    return ROOT / config["paths"]["state"] / "centroids" / f"{family}.json"


# ---------------------------------------------------------------------------
# Calibracion
# ---------------------------------------------------------------------------

def calibrate(config, family, anchors):
    families = config["qa"]["families"]
    if family not in families:
        raise SystemExit(f"[ERROR] Familia desconocida '{family}'. Validas: {', '.join(families)}")

    if anchors:
        families[family]["anchors"] = anchors
    anchors = families[family]["anchors"]
    if len(anchors) < 2:
        raise SystemExit(
            f"[ERROR] La familia '{family}' necesita >=2 anclas aprobadas por el humano.\n"
            f"  characters: los heroes de heroes/approved/\n"
            f"  ui/backgrounds/fx: los primeros 3-4 assets aprobados a mano (mini-gate)\n"
            f"  Pasalas con --anchors ruta1.png ruta2.png ..."
        )

    embeds = []
    for a in anchors:
        p = (ROOT / a).resolve()
        if not p.exists():
            raise SystemExit(f"[ERROR] Ancla inexistente: {p}")
        embeds.append(embed_image(config, p))
        print(f"  embedding OK: {a}")

    dim = len(embeds[0])
    centroid = _normalize([sum(e[i] for e in embeds) / len(embeds) for i in range(dim)])

    sims = [_cosine(e, centroid) for e in embeds]
    threshold = round(min(sims) - config["qa"]["threshold_margin"], 4)
    initial = config["qa"]["initial_threshold"]
    if threshold > initial:
        # arranque conservador: nunca mas estricto que el inicial del doc (0.75)
        print(f"  min(sim)-margen = {threshold} > inicial {initial}; se usa {threshold}")
    else:
        print(f"  min(sim)-margen = {threshold} (inicial de referencia: {initial})")

    families[family]["threshold"] = threshold
    save_config(config)
    write_json(centroid_path(config, family), {
        "family": family,
        "model": config["qa"]["clip_model"],
        "pretrained": config["qa"]["clip_pretrained"],
        "anchors": anchors,
        "anchor_sims": [round(s, 4) for s in sims],
        "threshold": threshold,
        "centroid": centroid,
    })
    print(f"Familia '{family}' calibrada: umbral {threshold}, {len(anchors)} anclas.")
    print(f"Centroide -> {centroid_path(config, family).relative_to(ROOT)}")


# ---------------------------------------------------------------------------
# Checks de batch
# ---------------------------------------------------------------------------

def _hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def palette_coverage(config, path):
    """Fraccion de pixeles (visibles) cuyo color cuantizado cae cerca de la paleta."""
    from PIL import Image

    palette = [_hex_to_rgb(c) for c in config["qa"]["palette"]]
    max_dist = config["qa"]["palette_max_distance"]

    img = Image.open(path).convert("RGBA")
    img.thumbnail((256, 256))
    base = Image.new("RGB", img.size, (255, 255, 255))
    alpha = img.split()[3]
    base.paste(img, mask=alpha)

    quant = base.quantize(colors=16)
    qpalette = quant.getpalette()
    counts = quant.getcolors()  # [(count, index)]

    # pesar solo pixeles visibles: mascara de alpha
    visible = alpha.point(lambda a: 255 if a > 32 else 0)
    total_visible = sum(1 for px in visible.getdata() if px)
    if total_visible == 0:
        return 0.0

    # aproximacion: coverage sobre la imagen compuesta completa; el blanco de
    # fondo esta en paleta (#FFFFFF) asi que no penaliza.
    total = sum(c for c, _ in counts)
    ok = 0
    for count, idx in counts:
        rgb = tuple(qpalette[idx * 3: idx * 3 + 3])
        dist = min(
            ((rgb[0] - p[0]) ** 2 + (rgb[1] - p[1]) ** 2 + (rgb[2] - p[2]) ** 2) ** 0.5
            for p in palette
        )
        if dist <= max_dist:
            ok += count
    return ok / total


def transparency_ok(path, is_background):
    """Personajes/UI/fx: alpha real y esquinas transparentes. Backgrounds: opacos."""
    from PIL import Image

    img = Image.open(path)
    if is_background:
        return True  # se copian sin recorte; no exigimos alpha
    if img.mode != "RGBA":
        return False
    alpha = img.split()[3]
    w, h = img.size
    corner = 8
    boxes = [
        (0, 0, corner, corner),
        (w - corner, 0, w, corner),
        (0, h - corner, corner, h),
        (w - corner, h - corner, w, h),
    ]
    for box in boxes:
        region = alpha.crop(box)
        data = list(region.getdata())
        if sum(data) / len(data) > 16:
            return False
    return True


def make_contact_sheet(config, images, out_path):
    """Grilla de thumbnails a 120px (test de silueta legible, doc seccion 7)."""
    from PIL import Image, ImageDraw

    thumb = config["qa"]["contact_sheet_thumb"]
    cols = 8
    label_h = 14
    cell = (thumb, thumb + label_h)
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell[0], rows * cell[1]), (46, 46, 46))
    draw = ImageDraw.Draw(sheet)
    for i, (key, path) in enumerate(images):
        x = (i % cols) * cell[0]
        y = (i // cols) * cell[1]
        try:
            img = Image.open(path).convert("RGBA")
            img.thumbnail((thumb, thumb))
            sheet.paste(img, (x + (thumb - img.width) // 2, y + (thumb - img.height) // 2), img)
        except Exception:
            draw.rectangle([x, y, x + thumb, y + thumb], outline=(255, 77, 109))
        draw.text((x + 2, y + thumb), key[:20], fill=(255, 248, 231))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)
    return out_path


# ---------------------------------------------------------------------------
# Batch
# ---------------------------------------------------------------------------

def run_batch(config, tanda):
    entries = entries_for_tanda(load_prompts(config), tanda)
    if not entries:
        raise SystemExit(f"[ERROR] La tanda {tanda} no existe en prompts.json")

    cutout_dir = ROOT / config["paths"]["cutout"] / f"tanda_{tanda}"
    approved_dir = ROOT / config["paths"]["approved"]
    state_dir = ROOT / config["paths"]["state"]
    approved_dir.mkdir(parents=True, exist_ok=True)

    # centroides necesarios
    needed_families = sorted({e["qa_family"] for e in entries})
    centroids = {}
    for fam in needed_families:
        data = read_json(centroid_path(config, fam))
        threshold = config["qa"]["families"][fam]["threshold"]
        if data is None or threshold is None:
            raise SystemExit(
                f"[ERROR] Familia '{fam}' sin calibrar. Corre antes:\n"
                f"  python3 scripts/qa_clip.py --calibrate --family {fam} --anchors ..."
            )
        centroids[fam] = (data["centroid"], threshold)

    report = read_json(state_dir / "qa_report.json", default={})
    queue = read_json(state_dir / "regen_queue.json", default=[])
    queue_by_key = {q["assetKey"]: q for q in queue}

    results = {}
    sheet_images = []
    passed = failed = missing = 0
    min_coverage = config["qa"]["palette_min_coverage"]

    for e in entries:
        key = e["assetKey"]
        path = cutout_dir / f"{key}.png"
        if not path.exists():
            print(f"  [FALTA] {key} — corre cutout_batch (o genera la imagen)")
            missing += 1
            continue
        sheet_images.append((key, path))

        centroid, threshold = centroids[e["qa_family"]]
        sim = _cosine(embed_image(config, path), centroid)
        coverage = palette_coverage(config, path)
        transparent = transparency_ok(path, e["category"] == "background")

        reasons = []
        if sim < threshold:
            reasons.append(f"clip {sim:.3f} < umbral {threshold} (familia {e['qa_family']})")
        if coverage < min_coverage:
            reasons.append(f"paleta {coverage:.2f} < {min_coverage} (colores fuera del set lockeado)")
        if not transparent:
            reasons.append("fondo no transparente / esquinas con residuo tras rembg")

        ok = not reasons
        results[key] = {
            "clip": round(sim, 4),
            "clip_threshold": threshold,
            "qa_family": e["qa_family"],
            "palette_coverage": round(coverage, 4),
            "transparent_ok": transparent,
            "pass": ok,
            "reasons": reasons,
        }
        if ok:
            shutil.copyfile(path, approved_dir / f"{key}.png")
            queue_by_key.pop(key, None)  # si antes fallo y ahora paso, sale de la cola
            passed += 1
            print(f"  [PASS] {key}  clip={sim:.3f} paleta={coverage:.2f}")
        else:
            prev = queue_by_key.get(key)
            queue_by_key[key] = {
                "assetKey": key,
                "tanda": tanda,
                "seed_original": e["seed"],
                "attempt": prev["attempt"] if prev else 0,
                "reasons": reasons,
                "status": "pending",
            }
            failed += 1
            print(f"  [FAIL] {key}  -> {'; '.join(reasons)}")

    sheet = None
    if sheet_images:
        sheet = make_contact_sheet(
            config, sheet_images, state_dir / f"contact_sheet_tanda_{tanda}.png"
        )

    report[f"tanda_{tanda}"] = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "passed": passed,
        "failed": failed,
        "missing": missing,
        "contact_sheet": str(sheet.relative_to(ROOT)) if sheet else None,
        "results": results,
    }
    write_json(state_dir / "qa_report.json", report)
    write_json(state_dir / "regen_queue.json", sorted(queue_by_key.values(), key=lambda q: q["assetKey"]))

    print(f"\nTanda {tanda}: {passed} PASS, {failed} FAIL, {missing} sin imagen.")
    print(f"Reporte:       state/qa_report.json")
    if sheet:
        print(f"Contact sheet: {sheet.relative_to(ROOT)}  <- [GATE HUMANO] revisar silueta/outline a 120px")
    if failed:
        print(f"Cola de regen: state/regen_queue.json -> python3 scripts/regen_loop.py")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--calibrate", action="store_true", help="calibrar una familia")
    parser.add_argument("--family", help="familia a calibrar (characters/ui/backgrounds/fx)")
    parser.add_argument("--anchors", nargs="*", default=None,
                        help="rutas (relativas al pipeline) de las anclas aprobadas")
    parser.add_argument("--batch", type=int, metavar="TANDA", help="correr QA sobre una tanda")
    args = parser.parse_args()

    config = load_config()
    if args.calibrate:
        if not args.family:
            raise SystemExit("[ERROR] --calibrate requiere --family")
        calibrate(config, args.family, args.anchors)
    elif args.batch is not None:
        run_batch(config, args.batch)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
