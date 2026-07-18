#!/usr/bin/env python3
"""Generacion batch autonoma via API local de ComfyUI (camino A del asset doc).

Postea workflows/sd15_hoboevo.json (formato API) a POST /prompt por cada
entrada de prompts.json de la tanda, inyectando prompt/negative/seed y los
params fijos de config.json; espera con poll a GET /history/{id} y guarda el
PNG en raw/tanda_N/{assetKey}.png.

- Reanudable: saltea si raw/tanda_N/{key}.png ya existe (--force para pisar).
- Solo stdlib (urllib): corre sin instalar nada.
- Antes de la primera corrida: poner el nombre REAL del checkpoint SD 1.5 y
  del VAE fp32 en config.json (generation.comfyui_checkpoint / comfyui_vae)
  segun tu instalacion de ComfyUI (carpetas models/checkpoints y models/vae),
  y copiar el LoRA a models/loras/hoboevo_style.safetensors.
- Arrancar ComfyUI en Mac:  python main.py --force-fp16 --use-split-cross-attention

Uso:  python3 scripts/comfy_batch.py --tanda 1 [--only assetKey] [--force]
"""
import argparse
import copy
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import ROOT, load_config, load_prompts, entries_for_tanda  # noqa: E402

WORKFLOW_PATH = ROOT / "workflows" / "sd15_hoboevo.json"

# ids de nodos dentro de workflows/sd15_hoboevo.json (formato API)
NODE_CHECKPOINT = "1"
NODE_LORA = "2"
NODE_POSITIVE = "3"
NODE_NEGATIVE = "4"
NODE_LATENT = "5"
NODE_KSAMPLER = "6"
NODE_VAE = "7"

SAMPLER_MAP = {
    "DPM++ 2M Karras": ("dpmpp_2m", "karras"),
    "Euler a": ("euler_ancestral", "normal"),
}

POLL_SECONDS = 2
TIMEOUT_SECONDS = 600  # M1 Air: 30-90s tipico por imagen a 768; margen amplio


def _api(config, path, payload=None, timeout=30):
    url = config["generation"]["comfyui_url"].rstrip("/") + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url, data=data,
        headers={"Content-Type": "application/json"} if data else {},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def build_workflow(config, entry, seed_override=None):
    gen = config["generation"]
    if gen["comfyui_checkpoint"].startswith("PLACEHOLDER"):
        raise SystemExit(
            "[ERROR] Falta configurar generation.comfyui_checkpoint en config.json\n"
            "  (nombre del checkpoint SD 1.5 tal como figura en ComfyUI/models/checkpoints)"
        )
    sampler_name, scheduler = SAMPLER_MAP.get(gen["sampler"], ("dpmpp_2m", "karras"))

    wf = copy.deepcopy(json.loads(WORKFLOW_PATH.read_text(encoding="utf-8")))
    wf[NODE_CHECKPOINT]["inputs"]["ckpt_name"] = gen["comfyui_checkpoint"]
    # Plan sin LoRA: el workflow ya no tiene nodo LoraLoader (consistencia =
    # prompt maestro + seeds fijos + QA CLIP). Si algun dia vuelve el LoRA,
    # basta re-agregar el nodo "2" al workflow y este bloque lo configura.
    if NODE_LORA in wf:
        wf[NODE_LORA]["inputs"]["lora_name"] = gen["lora"]
        wf[NODE_LORA]["inputs"]["strength_model"] = gen["lora_strength"]
        wf[NODE_LORA]["inputs"]["strength_clip"] = gen["lora_strength"]
    wf[NODE_POSITIVE]["inputs"]["text"] = entry["prompt"]
    wf[NODE_NEGATIVE]["inputs"]["text"] = entry["negative"]
    wf[NODE_LATENT]["inputs"]["width"] = gen["resolution"]
    wf[NODE_LATENT]["inputs"]["height"] = gen["resolution"]
    ks = wf[NODE_KSAMPLER]["inputs"]
    ks["seed"] = seed_override if seed_override is not None else entry["seed"]
    ks["steps"] = gen["steps"]
    ks["cfg"] = gen["cfg"]
    ks["sampler_name"] = sampler_name
    ks["scheduler"] = scheduler
    if not gen["comfyui_vae"].startswith("PLACEHOLDER"):
        wf[NODE_VAE]["inputs"]["vae_name"] = gen["comfyui_vae"]
    else:
        # sin VAE dedicado: usar el VAE del checkpoint (rewire del VAEDecode)
        for node in wf.values():
            if node.get("class_type") == "VAEDecode":
                node["inputs"]["vae"] = [NODE_CHECKPOINT, 2]
        wf.pop(NODE_VAE, None)
    return wf


def wait_for(config, prompt_id):
    start = time.time()
    while time.time() - start < TIMEOUT_SECONDS:
        try:
            history = _api(config, f"/history/{prompt_id}")
        except (urllib.error.URLError, urllib.error.HTTPError):
            time.sleep(POLL_SECONDS)
            continue
        if prompt_id in history:
            item = history[prompt_id]
            status = item.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(f"ComfyUI reporto error: {json.dumps(status)[:400]}")
            outputs = item.get("outputs", {})
            for node_output in outputs.values():
                for img in node_output.get("images", []):
                    return img
        time.sleep(POLL_SECONDS)
    raise TimeoutError(f"ComfyUI no termino en {TIMEOUT_SECONDS}s (prompt {prompt_id})")


def download_image(config, img, dest):
    query = urllib.parse.urlencode({
        "filename": img["filename"],
        "subfolder": img.get("subfolder", ""),
        "type": img.get("type", "output"),
    })
    url = config["generation"]["comfyui_url"].rstrip("/") + "/view?" + query
    with urllib.request.urlopen(url, timeout=60) as resp:
        dest.write_bytes(resp.read())


def generate_one(config, entry, seed_override=None, overwrite=False):
    """Genera un asset. Reutilizado por regen_loop. Lanza excepcion si falla."""
    out_dir = ROOT / config["paths"]["raw"] / f"tanda_{entry['tanda']}"
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / f"{entry['assetKey']}.png"
    if dest.exists() and not overwrite:
        return dest

    wf = build_workflow(config, entry, seed_override)
    result = _api(config, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})
    prompt_id = result.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"Respuesta inesperada de /prompt: {json.dumps(result)[:400]}")
    img = wait_for(config, prompt_id)
    download_image(config, img, dest)
    return dest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tanda", type=int, required=True)
    parser.add_argument("--only", help="generar un solo assetKey de la tanda")
    parser.add_argument("--force", action="store_true", help="pisar imagenes existentes")
    args = parser.parse_args()

    config = load_config()
    if config["generation"]["active_path"] != "comfyui":
        print("[AVISO] config.generation.active_path = "
              f"'{config['generation']['active_path']}'. Este script es el camino ComfyUI;"
              " se ejecuta igual, pero si la tanda la esta haciendo el humano en Draw"
              " Things vas a duplicar trabajo.")

    entries = entries_for_tanda(load_prompts(config), args.tanda)
    if not entries:
        raise SystemExit(f"[ERROR] La tanda {args.tanda} no existe en prompts.json")
    if args.only:
        entries = [e for e in entries if e["assetKey"] == args.only]
        if not entries:
            raise SystemExit(f"[ERROR] '{args.only}' no esta en la tanda {args.tanda}")

    # chequeo de conexion con mensaje claro
    try:
        _api(config, "/system_stats")
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(
            f"[ERROR] No hay ComfyUI en {config['generation']['comfyui_url']} ({exc}).\n"
            "  Arrancalo con:  python main.py --force-fp16 --use-split-cross-attention"
        )

    done = skipped = errors = 0
    for i, e in enumerate(entries, 1):
        dest = ROOT / config["paths"]["raw"] / f"tanda_{args.tanda}" / f"{e['assetKey']}.png"
        if dest.exists() and not args.force:
            print(f"  [{i}/{len(entries)}] SKIP {e['assetKey']} (ya existe)")
            skipped += 1
            continue
        print(f"  [{i}/{len(entries)}] GEN  {e['assetKey']} (seed {e['seed']})...", flush=True)
        try:
            generate_one(config, e, overwrite=args.force)
            done += 1
        except KeyboardInterrupt:
            print("\nInterrumpido. Re-correr el mismo comando retoma donde quedo.")
            raise
        except Exception as exc:  # noqa: BLE001 — seguir con el resto de la tanda
            errors += 1
            print(f"      [ERROR] {e['assetKey']}: {exc}")

    print(f"\nTanda {args.tanda}: {done} generadas, {skipped} skip, {errors} errores.")
    if errors:
        print("Re-correr el mismo comando reintenta solo las que faltan.")
    else:
        print(f"Siguiente paso: python3 scripts/cutout_batch.py --tanda {args.tanda}")


if __name__ == "__main__":
    main()
