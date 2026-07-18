#!/usr/bin/env python3
"""Mergea assets exportados al assets_manifest.json real + modo --verify.

Merge (default): por cada asset del checklist cuyos PNG @2x y @3x ya esten
exportados en Resources/, agrega/actualiza su entrada:

  characters.{id}   = { "atlas": "earth|cosmic|specials", "key": id,
                        "anchor": [0.5, 0.1], "scale": 1.0 }
  backgrounds.{key} = { "key": key }                      (Backgrounds/ sueltos)
  ui.{key}          = { "atlas": "ui", "key": key }       (ui, boosts, logo, fx)

- No pisa campos custom que el humano haya tocado (anchor/scale existentes se
  preservan); swap solo-manifest: sin entrada => el juego usa placeholder.
- Escritura atomica (tmp + rename), reversible por git.

--verify: compara manifest + archivos presentes contra el checklist COMPLETO
(36 personajes, 10 specials, 11 backgrounds, 24 UI, 6 boosts, logo, 5 fx),
lista faltantes y huerfanos, exit code 0 SOLO si esta completo.

Uso:  python3 scripts/update_manifest.py [--verify] [--dry-run]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import (  # noqa: E402
    load_config, manifest_path, resources_root, write_json, read_json,
)
from gen_prompts import build_all_entries  # noqa: E402


def exported_files(config, entry):
    if entry["category"] == "background":
        out_dir = resources_root(config) / config["paths"]["backgrounds_dir"]
    else:
        out_dir = resources_root(config) / config["paths"]["atlases"][entry["atlas"]]
    key = entry["assetKey"]
    return [out_dir / f"{key}@2x.png", out_dir / f"{key}@3x.png"]


def manifest_section(entry):
    if entry["category"] in ("character", "special"):
        return "characters"
    if entry["category"] == "background":
        return "backgrounds"
    return "ui"  # ui, fx y logo


def build_manifest_entry(entry):
    if entry["category"] in ("character", "special"):
        return {
            "atlas": entry["atlas"],
            "key": entry["assetKey"],
            "anchor": [0.5, 0.1],
            "scale": 1.0,
        }
    if entry["category"] == "background":
        return {"key": entry["assetKey"]}
    return {"atlas": entry["atlas"], "key": entry["assetKey"]}


def merge(config, dry_run=False):
    entries = build_all_entries(config)
    path = manifest_path(config)
    manifest = read_json(path, default={"schemaVersion": 1, "characters": {}, "backgrounds": {}, "ui": {}})
    for section in ("characters", "backgrounds", "ui"):
        manifest.setdefault(section, {})

    added = updated = pending = 0
    for e in entries:
        files = exported_files(config, e)
        if not all(f.exists() for f in files):
            pending += 1
            continue
        section = manifest_section(e)
        key = e["assetKey"]
        fresh = build_manifest_entry(e)
        current = manifest[section].get(key)
        if current is None:
            manifest[section][key] = fresh
            added += 1
            print(f"  [ADD]  {section}.{key}")
        else:
            # preservar ajustes humanos (anchor/scale custom); completar faltantes
            changed = False
            for k, v in fresh.items():
                if k not in current:
                    current[k] = v
                    changed = True
            if changed:
                updated += 1
                print(f"  [FILL] {section}.{key}")

    if dry_run:
        print(f"\n[dry-run] {added} nuevas, {updated} completadas, {pending} sin exportar. No se escribio nada.")
        return
    write_json(path, manifest)
    print(f"\nManifest: {added} nuevas, {updated} completadas, {pending} sin exportar todavia.")
    print(f"-> {path}")


def verify(config):
    entries = build_all_entries(config)
    path = manifest_path(config)
    manifest = read_json(path, default={})

    expected_by_section = {"characters": {}, "backgrounds": {}, "ui": {}}
    for e in entries:
        expected_by_section[manifest_section(e)][e["assetKey"]] = e

    missing_manifest = []
    missing_files = []
    for section, expected in expected_by_section.items():
        have = manifest.get(section, {})
        for key, e in expected.items():
            if key not in have:
                missing_manifest.append(f"{section}.{key}")
            files = exported_files(config, e)
            absent = [f.name for f in files if not f.exists()]
            if absent:
                missing_files.append(f"{key}: faltan {', '.join(absent)}")

    orphans_manifest = []
    for section in ("characters", "backgrounds", "ui"):
        for key in manifest.get(section, {}):
            if key not in expected_by_section[section]:
                orphans_manifest.append(f"{section}.{key}")

    expected_keys = {e["assetKey"] for e in entries}
    orphan_files = []
    res = resources_root(config)
    scan_dirs = [res / d for d in config["paths"]["atlases"].values()]
    scan_dirs.append(res / config["paths"]["backgrounds_dir"])
    for d in scan_dirs:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.png")):
            stem = f.stem
            for suffix in ("@2x", "@3x"):
                if stem.endswith(suffix):
                    stem = stem[: -len(suffix)]
                    break
            else:
                orphan_files.append(f"{d.name}/{f.name} (sin @2x/@3x en el nombre)")
                continue
            if stem not in expected_keys:
                orphan_files.append(f"{d.name}/{f.name}")

    # resumen por grupo del checklist
    groups = {
        "personajes (36)": [e for e in entries if e["category"] == "character"],
        "specials (10)": [e for e in entries if e["category"] == "special"],
        "backgrounds (11)": [e for e in entries if e["category"] == "background"],
        "UI botones+currency+upgrades (24)": [
            e for e in entries
            if e["category"] == "ui" and not e["assetKey"].startswith("ui_boost_") and e["assetKey"] != "logo"
        ],
        "boosts (6)": [e for e in entries if e["assetKey"].startswith("ui_boost_")],
        "logo (1)": [e for e in entries if e["assetKey"] == "logo"],
        "fx (5)": [e for e in entries if e["category"] == "fx"],
    }
    print("Checklist:")
    for name, group in groups.items():
        done = sum(
            1
            for e in group
            if e["assetKey"] in manifest.get(manifest_section(e), {})
            and all(f.exists() for f in exported_files(config, e))
        )
        mark = "OK " if done == len(group) else ".. "
        print(f"  [{mark}] {name}: {done}/{len(group)}")

    problems = False
    if missing_manifest:
        problems = True
        print(f"\nFaltan en el manifest ({len(missing_manifest)}):")
        for m in missing_manifest:
            print(f"  - {m}")
    if missing_files:
        problems = True
        print(f"\nFaltan archivos exportados ({len(missing_files)}):")
        for m in missing_files:
            print(f"  - {m}")
    if orphans_manifest:
        problems = True
        print(f"\nHuerfanos en el manifest (no estan en el checklist) ({len(orphans_manifest)}):")
        for o in orphans_manifest:
            print(f"  - {o}")
    if orphan_files:
        problems = True
        print(f"\nArchivos huerfanos en Resources ({len(orphan_files)}):")
        for o in orphan_files:
            print(f"  - {o}")

    if problems:
        print("\nVERIFY: INCOMPLETO")
        sys.exit(1)
    print(f"\nVERIFY: COMPLETO — {len(entries)} assets en manifest + archivos @2x/@3x presentes.")
    sys.exit(0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="chequear completitud (exit 0 solo si completo)")
    parser.add_argument("--dry-run", action="store_true", help="mostrar merge sin escribir")
    args = parser.parse_args()

    config = load_config()
    if args.verify:
        verify(config)
    else:
        merge(config, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
