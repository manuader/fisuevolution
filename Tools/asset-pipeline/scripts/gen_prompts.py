#!/usr/bin/env python3
"""Genera prompts/prompts.json + prompts/drawthings_tanda_N.txt.

Lee tiers.json (los 36 personajes reales; el choice node T9 `junior` es
abstracto y se saltea) + cultural_dict.py + config.json. No requiere ningun
paquete pip: solo stdlib.

Seeds deterministas: seed = base de la familia (config.seeds) + indice del
asset dentro del orden canonico de su familia. Regenerar identico siempre.

Tandas (plan F3):
  1 = characters T1-T10 (16, incluye 4 junior + 4 senior)
  2 = UI completa (31: 10 botones + 7 currency + 7 upgrades + 6 boosts + logo)
  3 = backgrounds tempranos (3: alley, urban, corporate)
  4 = characters T11-T30 (20) + backgrounds cosmicos (8)
  5 = specials (10) + fx (5)

Uso:  python3 scripts/gen_prompts.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import ROOT, load_config, tiers_path, write_json  # noqa: E402
import cultural_dict as cd  # noqa: E402


def _join_prompt(trigger, entry, suffix):
    parts = [trigger]
    for field in ("subject", "props", "ar_cues", "wealth_cues", "expression"):
        value = entry.get(field, "").strip()
        if value:
            parts.append(value)
    if suffix:
        parts.append(suffix)
    return ", ".join(parts)


SUFFIXES = {
    "character": "full body, centered, transparent background",
    "special": "full body, centered, transparent background",
    "background": "wide flat vector background scene, no characters, no people, full canvas",
    "ui": "simple flat vector game icon, centered, transparent background",
    "fx": "simple flat particle sprite, centered, transparent background",
}


def build_all_entries(config=None):
    """Lista canonica de los 93 assets con seed/tanda/atlas/prompt."""
    config = config or load_config()
    trigger = config["generation"]["trigger"]
    negative = config["negative_prompt_lora"]
    seeds = config["seeds"]

    with open(tiers_path(config), "r", encoding="utf-8") as f:
        tiers = json.load(f)["types"]

    entries = []
    counters = {family: 0 for family in seeds}

    def add(key, category, family, qa_family, atlas, tanda, cultural, tier=None, phase=None):
        idx = counters[family]
        counters[family] += 1
        entry = {
            "assetKey": key,
            "category": category,
            "atlas": atlas,
            "family": family,
            "qa_family": qa_family,
            "tanda": tanda,
            "subject": cultural["subject"],
            "props": cultural["props"],
            "ar_cues": cultural["ar_cues"],
            "wealth_cues": cultural["wealth_cues"],
            "expression": cultural["expression"],
            "seed": seeds[family] + idx,
            "prompt": _join_prompt(trigger, cultural, SUFFIXES[category]),
            "negative": negative,
        }
        if tier is not None:
            entry["tier"] = tier
        if phase is not None:
            entry["phase"] = phase
        entries.append(entry)

    # --- personajes (orden de tiers.json; el choice node no lleva sprite) ---
    missing = []
    for t in tiers:
        if t.get("isChoiceNode"):
            continue
        key = t["id"]
        cultural = cd.CHARACTERS.get(key)
        if cultural is None:
            missing.append(key)
            continue
        phase = t["phase"]
        family = f"characters_{phase}"
        add(
            key, "character", family, "characters", phase,
            1 if t["tier"] <= 10 else 4, cultural,
            tier=t["tier"], phase=phase,
        )
    if missing:
        raise SystemExit(
            "[ERROR] tiers.json tiene ids sin entrada en cultural_dict.CHARACTERS: "
            + ", ".join(missing)
        )
    extra = set(cd.CHARACTERS) - {t["id"] for t in tiers}
    if extra:
        raise SystemExit(
            "[ERROR] cultural_dict.CHARACTERS tiene claves que no existen en tiers.json: "
            + ", ".join(sorted(extra))
        )

    # --- UI (tanda 2) ---
    for key in cd.UI_ORDER:
        add(key, "ui", "ui", "ui", "ui", 2, cd.UI[key])

    # --- backgrounds (tanda 3 los tempranos, tanda 4 el resto) ---
    for i, key in enumerate(cd.BACKGROUNDS_ORDER):
        tanda = 3 if i < cd.EARLY_BACKGROUNDS else 4
        add(key, "background", "backgrounds", "backgrounds", "backgrounds",
            tanda, cd.BACKGROUNDS[key])

    # --- specials + fx (tanda 5) ---
    for key in cd.SPECIALS_ORDER:
        add(key, "special", "specials", "characters", "specials", 5, cd.SPECIALS[key])
    for key in cd.FX_ORDER:
        add(key, "fx", "fx", "fx", "ui", 5, cd.FX[key])

    return entries


def write_drawthings_exports(entries, config):
    gen = config["generation"]
    prompts_dir = ROOT / config["paths"]["prompts"]
    prompts_dir.mkdir(parents=True, exist_ok=True)
    tandas = sorted({e["tanda"] for e in entries})
    files = []
    for tanda in tandas:
        batch = [e for e in entries if e["tanda"] == tanda]
        lines = []
        bar = "=" * 72
        lines.append(bar)
        lines.append(f"HOBO EVOLUTION — Draw Things — TANDA {tanda} ({len(batch)} assets)")
        lines.append(bar)
        lines.append(f"Modelo: {gen['model']} + LoRA {gen['lora']} (peso {gen['lora_strength']})")
        lines.append(
            f"Sampler: {gen['sampler']} | Steps: {gen['steps']} | CFG: {gen['cfg']} | "
            f"{gen['resolution']}x{gen['resolution']} | VAE: {gen['vae']}"
        )
        lines.append(f"Guardar cada imagen como: raw/tanda_{tanda}/{{assetKey}}.png")
        lines.append("El seed va EXACTO (permite regenerar identico).")
        lines.append(bar)
        lines.append("")
        for i, e in enumerate(batch, 1):
            lines.append(f"[{i}/{len(batch)}] {e['assetKey']}   (seed {e['seed']})")
            lines.append(f"PROMPT:   {e['prompt']}")
            lines.append(f"NEGATIVE: {e['negative']}")
            lines.append("-" * 72)
        path = prompts_dir / f"drawthings_tanda_{tanda}.txt"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        files.append(path)
    return files


def main():
    config = load_config()
    entries = build_all_entries(config)

    prompts_path = ROOT / config["paths"]["prompts"] / "prompts.json"
    write_json(prompts_path, entries)

    files = write_drawthings_exports(entries, config)

    print(f"prompts.json: {len(entries)} entradas -> {prompts_path}")
    for tanda in sorted({e["tanda"] for e in entries}):
        batch = [e for e in entries if e["tanda"] == tanda]
        by_cat = {}
        for e in batch:
            by_cat[e["category"]] = by_cat.get(e["category"], 0) + 1
        detail = ", ".join(f"{v} {k}" for k, v in sorted(by_cat.items()))
        print(f"  tanda {tanda}: {len(batch):3d}  ({detail})")
    for f in files:
        print(f"export Draw Things -> {f.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
