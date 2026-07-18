#!/usr/bin/env python3
"""Scoring automatico de la busqueda de templates (reemplaza el ojo humano).

Por imagen (v2 — endurecido tras el spot-check de ronda 1):
  clip_prob   softmax(100*sims) del texto objetivo vs 4 distractores
              (fotografia / boceto a lapiz / character sheet / duo). >0.5 = el
              estilo objetivo domina. clip_margin = sim_t - sum(fotografia,
              boceto, sheet) (spec del coordinador; informativo).
  solo_prob   par CLIP dedicado 1-vs-2 personajes: softmax("exactly one
              cartoon character, alone" vs "two or more cartoon characters").
              Cazador de duos que se tocan (una sola componente conexa).
  single      tras rembg (isnet-general-use) a 256px: area de la componente
              conexa mas grande / area total de foreground. >=0.75 = un blob.
  palette     fraccion de pixeles de foreground con distancia RGB < 90 a la
              paleta lockeada del doc (8 colores). Metrica LAXA (blanco/negro
              absorben mucho); solo orientativa.
  sat         saturacion media HSV del foreground (anti-grayscale).
  bg_white    fraccion del borde de la imagen (10% exterior) cercana a blanco
              — fondo limpio para rembg. Informativa (no gatea).

SCORE = 0.35*clip_prob + 0.20*solo_prob + 0.15*single + 0.15*palette
        + 0.15*min(sat/0.5, 1)
PASS  = clip_prob>0.5 AND solo_prob>0.5 AND single>=0.75 AND sat>=0.15

Uso: prompt_search_score.py <dir_pngs> <out_json>
"""
import json
import sys
from pathlib import Path

import numpy as np
import torch
import open_clip
from PIL import Image
from rembg import new_session, remove
from scipy import ndimage

PALETTE = [
    (0xFF, 0xD9, 0x3D), (0xFF, 0x6B, 0x35), (0xFF, 0x4D, 0x6D),
    (0x4D, 0x96, 0xFF), (0x6B, 0xCB, 0x77), (0xFF, 0xF8, 0xE7),
    (0x2C, 0x2C, 0x2C), (0xFF, 0xFF, 0xFF),
]
PALETTE_MAX_DIST = 90.0

TEXTS = {
    "target": "a flat vector cartoon illustration of a single character with thick black outline",
    "photo": "a photograph of a person",
    "sketch": "a pencil sketch",
    "sheet": "a character sheet with multiple figures",
    "duo": "two cartoon characters standing side by side",
}
PAIR = ["exactly one cartoon character, alone", "two or more cartoon characters"]


def main(img_dir, out_json):
    model, _, preprocess = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k")
    tokenizer = open_clip.get_tokenizer("ViT-B-32")
    model.eval()
    with torch.no_grad():
        tfeat = model.encode_text(tokenizer(list(TEXTS.values())))
        tfeat = tfeat / tfeat.norm(dim=-1, keepdim=True)
        pfeat = model.encode_text(tokenizer(PAIR))
        pfeat = pfeat / pfeat.norm(dim=-1, keepdim=True)
    session = new_session("isnet-general-use")

    rows = {}
    for png in sorted(Path(img_dir).glob("*.png")):
        im = Image.open(png).convert("RGB")

        # --- CLIP ---
        with torch.no_grad():
            ifeat = model.encode_image(preprocess(im).unsqueeze(0))
            ifeat = ifeat / ifeat.norm(dim=-1, keepdim=True)
            sims = (ifeat @ tfeat.T).squeeze(0)
            psims = (ifeat @ pfeat.T).squeeze(0)
        s = {k: float(v) for k, v in zip(TEXTS, sims)}
        prob = torch.softmax(100 * sims, dim=0)[0].item()
        solo_prob = torch.softmax(100 * psims, dim=0)[0].item()
        margin = s["target"] - s["photo"] - s["sketch"] - s["sheet"]

        # --- borde blanco (fondo limpio) ---
        arr = np.asarray(im, dtype=np.float32)
        h, w, _ = arr.shape
        m = int(min(h, w) * 0.10)
        border = np.concatenate([
            arr[:m].reshape(-1, 3), arr[-m:].reshape(-1, 3),
            arr[:, :m].reshape(-1, 3), arr[:, -m:].reshape(-1, 3)])
        bg_white = float((np.abs(border - 255).max(axis=1) < 40).mean())

        # --- foreground via rembg (256px) ---
        small = im.resize((256, 256), Image.LANCZOS)
        cut = remove(small, session=session)
        alpha = np.asarray(cut)[:, :, 3]
        mask = alpha > 127
        fg_frac = float(mask.mean())
        # figura completa con margen: el foreground NO deberia tocar el borde
        edge = np.zeros_like(mask)
        edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
        edge_touch = float((mask & edge).sum() / edge.sum())
        if mask.sum() < 256 * 256 * 0.02:
            single = palette_frac = sat = 0.0
        else:
            labels, n = ndimage.label(mask)
            sizes = ndimage.sum(mask, labels, range(1, n + 1))
            single = float(sizes.max() / mask.sum()) if n else 0.0

            rgb = np.asarray(small, dtype=np.float32)[mask]
            pal = np.asarray(PALETTE, dtype=np.float32)
            d = np.linalg.norm(rgb[:, None, :] - pal[None, :, :], axis=2).min(axis=1)
            palette_frac = float((d < PALETTE_MAX_DIST).mean())

            hsv = np.asarray(small.convert("HSV"), dtype=np.float32)[:, :, 1][mask]
            sat = float(hsv.mean() / 255.0)

        score = (0.35 * prob + 0.20 * solo_prob + 0.15 * single
                 + 0.15 * palette_frac + 0.15 * min(sat / 0.5, 1.0))
        ok = prob > 0.5 and solo_prob > 0.5 and single >= 0.75 and sat >= 0.15
        rows[png.stem] = {
            "clip_prob": round(prob, 4), "solo_prob": round(solo_prob, 4),
            "clip_margin": round(margin, 4),
            "sims": {k: round(v, 4) for k, v in s.items()},
            "single": round(single, 4), "palette": round(palette_frac, 4),
            "sat": round(sat, 4), "fg_frac": round(fg_frac, 4),
            "bg_white": round(bg_white, 4), "edge_touch": round(edge_touch, 4),
            "score": round(score, 4), "pass": ok,
        }
        print(f"{png.stem:42s} score={score:.3f} clip={prob:.2f} solo={solo_prob:.2f} "
              f"single={single:.2f} pal={palette_frac:.2f} sat={sat:.2f} "
              f"bgw={bg_white:.2f} edge={edge_touch:.2f} {'PASS' if ok else 'fail'}",
              flush=True)

    Path(out_json).write_text(json.dumps(rows, indent=1), encoding="utf-8")
    print(f"-> {out_json}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
