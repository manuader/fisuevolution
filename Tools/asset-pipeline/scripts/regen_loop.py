#!/usr/bin/env python3
"""Loop de regeneracion sobre state/regen_queue.json (falla de QA -> reintento).

Por entrada pendiente:
  - seed nueva determinista = seed_original + 1000 * numero_de_intento
  - camino `comfyui`   -> regenera SOLO (via comfy_batch) y deja la imagen en
                          raw/tanda_N/; despues hay que re-correr cutout + QA.
  - camino `drawthings`-> imprime instrucciones EXACTAS para el humano
                          (prompt, negative, seed nueva, params) y marca la
                          entrada como waiting_human.
  - max 3 intentos (config.qa.max_regen_attempts) -> rejected/ con motivo
    ([GATE HUMANO] de rescate: ver README fase 6).

Uso:  python3 scripts/regen_loop.py [--tanda N]
"""
import argparse
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import (  # noqa: E402
    ROOT, load_config, load_prompts, write_json, read_json,
)


def reject(config, item, entry):
    """Mueve el asset (si hay imagen) a rejected/ y deja el motivo por escrito."""
    rejected_dir = ROOT / config["paths"]["rejected"]
    rejected_dir.mkdir(parents=True, exist_ok=True)
    key = item["assetKey"]
    tanda = item["tanda"]
    for folder in ("cutout", "raw"):
        src = ROOT / config["paths"][folder] / f"tanda_{tanda}" / f"{key}.png"
        if src.exists():
            shutil.copyfile(src, rejected_dir / f"{key}_{folder}.png")
    reason_file = rejected_dir / f"{key}.reason.txt"
    reason_file.write_text(
        f"assetKey: {key}\n"
        f"tanda: {tanda}\n"
        f"intentos: {item['attempt']}\n"
        f"motivos ultimo QA: {'; '.join(item.get('reasons', []))}\n"
        f"seed original: {item['seed_original']}\n"
        f"prompt: {entry['prompt']}\n"
        f"negative: {entry['negative']}\n"
        "\nRescate humano: regenerarlo a mano (IP-Adapter con heroes en Draw\n"
        "Things suele destrabar tiers dificiles), guardarlo directo en\n"
        "approved/{key}.png y seguir con organize_atlases.\n",
        encoding="utf-8",
    )
    print(f"  [REJECTED] {key} tras {item['attempt']} intentos -> {reason_file.relative_to(ROOT)}")


def print_drawthings_instructions(config, item, entry, new_seed):
    gen = config["generation"]
    key = item["assetKey"]
    print("-" * 72)
    print(f"[GATE HUMANO] Regenerar en Draw Things: {key} (intento {item['attempt']})")
    print(f"  Motivos QA: {'; '.join(item.get('reasons', []))}")
    print(f"  Modelo:   {gen['model']} + LoRA {gen['lora']} (peso {gen['lora_strength']})")
    print(f"  Sampler:  {gen['sampler']} | Steps {gen['steps']} | CFG {gen['cfg']} | "
          f"{gen['resolution']}x{gen['resolution']} | VAE {gen['vae']}")
    print(f"  SEED:     {new_seed}   <-- nueva (original {item['seed_original']})")
    print(f"  PROMPT:   {entry['prompt']}")
    print(f"  NEGATIVE: {entry['negative']}")
    print(f"  Guardar como: raw/tanda_{item['tanda']}/{key}.png (pisar la anterior)")
    print(f"  Despues: python3 scripts/cutout_batch.py --tanda {item['tanda']} --force")
    print(f"           python3 scripts/qa_clip.py --batch {item['tanda']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tanda", type=int, help="limitar a una tanda")
    args = parser.parse_args()

    config = load_config()
    max_attempts = config["qa"]["max_regen_attempts"]
    active_path = config["generation"]["active_path"]
    state_dir = ROOT / config["paths"]["state"]

    queue = read_json(state_dir / "regen_queue.json", default=[])
    if args.tanda is not None:
        selected = [q for q in queue if q["tanda"] == args.tanda]
    else:
        selected = list(queue)
    pending = [q for q in selected if q.get("status") in (None, "pending")]
    if not pending:
        print("Cola de regeneracion vacia (o todo esta waiting_human/rejected).")
        return

    entries = {e["assetKey"]: e for e in load_prompts(config)}

    for item in pending:
        entry = entries.get(item["assetKey"])
        if entry is None:
            print(f"  [WARN] {item['assetKey']} no existe en prompts.json; se saltea")
            continue

        item["attempt"] += 1
        if item["attempt"] > max_attempts:
            reject(config, item, entry)
            item["status"] = "rejected"
            continue

        new_seed = item["seed_original"] + 1000 * item["attempt"]
        item["last_seed"] = new_seed

        if active_path == "comfyui":
            from comfy_batch import generate_one  # import local (usa stdlib)

            print(f"  [COMFY] {item['assetKey']} intento {item['attempt']} seed {new_seed}")
            try:
                generate_one(config, entry, seed_override=new_seed, overwrite=True)
                item["status"] = "pending"  # queda pendiente de cutout+QA
                print(f"    OK -> re-correr: cutout_batch --tanda {item['tanda']} --force y qa_clip --batch {item['tanda']}")
            except Exception as exc:  # noqa: BLE001 — reportar y seguir con el resto
                item["attempt"] -= 1  # el intento no se consumio
                print(f"    [ERROR] ComfyUI fallo: {exc}")
        else:
            print_drawthings_instructions(config, item, entry, new_seed)
            item["status"] = "waiting_human"

    write_json(state_dir / "regen_queue.json", queue)
    print("\nCola actualizada: state/regen_queue.json")


if __name__ == "__main__":
    main()
