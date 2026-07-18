"""Helpers compartidos del pipeline (solo stdlib)."""
import json
from pathlib import Path

# Raiz del pipeline: Tools/asset-pipeline/
ROOT = Path(__file__).resolve().parents[1]


def load_config():
    with open(ROOT / "config.json", "r", encoding="utf-8") as f:
        return json.load(f)


def save_config(config):
    path = ROOT / "config.json"
    tmp = path.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")
    tmp.replace(path)


def load_prompts(config=None):
    config = config or load_config()
    path = ROOT / config["paths"]["prompts"] / "prompts.json"
    if not path.exists():
        raise SystemExit(
            f"[ERROR] No existe {path}. Corre primero: python3 scripts/gen_prompts.py"
        )
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def entries_for_tanda(entries, tanda):
    return [e for e in entries if e["tanda"] == tanda]


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    tmp.replace(path)


def read_json(path, default=None):
    path = Path(path)
    if not path.exists():
        return default
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def resources_root(config=None):
    config = config or load_config()
    return (ROOT / config["paths"]["resources"]).resolve()


def tiers_path(config=None):
    return resources_root(config) / "Data" / "tiers.json"


def manifest_path(config=None):
    return resources_root(config) / "Data" / "assets_manifest.json"
