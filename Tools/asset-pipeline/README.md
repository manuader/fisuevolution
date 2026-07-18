# Asset Pipeline — Hobo Evolution (F3)

Pipeline de arte completo: SD 1.5 local (M1 Air), LoRA gratis en la nube,
QA automatico, atlas nativos de Xcode. El codigo del juego jamas toca un
sprite: todo entra por `assets_manifest.json` (swap solo-manifest).

**Regla de oro:** en cada `[GATE HUMANO]` el pipeline FRENA y este README dice
exactamente que hacer. Nunca se simula que una imagen existe.

## Setup (una vez)

```bash
cd Tools/asset-pipeline
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt        # vtracer es opcional; si falla, comentarlo
```

Los scripts que solo arman texto/JSON (`gen_prompts.py`, `update_manifest.py
--verify`) corren con python3 pelado, sin instalar nada.

## Parametros fijos (config.json — no negociables entre tandas)

SD 1.5 · DPM++ 2M Karras · steps 28 · CFG 7 · **768x768** (fallback 512 si OOM)
· VAE fp32 · upscale RealESRGAN 2x · LoRA `hoboevo_style` peso 1.0 · seeds por
familia (characters earth 100001+ / cosmic 200001+ / specials 300001+ /
backgrounds 400001+ / ui 500001+ / fx 600001+). El seed de cada asset queda en
`prompts/prompts.json` = regeneracion identica para siempre.

## Tandas

| Tanda | Contenido | Assets |
|---|---|---|
| 0 | Heroes → LoRA (no shippean) | 3–4 |
| 1 | Characters T1–T10 (incl. 4 junior + 4 senior) | 16 |
| 2 | UI: 10 botones + 7 currency + 7 upgrades + 6 boosts + logo (sin texto) | 31 |
| 3 | Backgrounds tempranos (alley, urban, corporate) | 3 |
| 4 | Characters T11–T30 + backgrounds cosmicos | 28 |
| 5 | Specials + fx | 15 |

Total checklist: **93** (36 personajes, 10 specials, 11 bg, 24 UI, 6 boosts,
logo, 5 fx).

---

## Fase 1 — [GATE HUMANO] Heroes (de aca sale el look de TODO el juego)

1. Instalar **Draw Things** (App Store, gratis) y bajar el modelo
   **Stable Diffusion 1.5** desde la propia app.
2. Settings exactos (los mismos siempre): sampler `DPM++ 2M Karras`, steps
   `28`, CFG `7`, `768x768`, VAE fp32, SIN LoRA todavia, seed libre.
3. Generar 3–4 candidatos por sujeto con `prompts/hero_prompts.txt`
   (prompt maestro seccion 4.1 + los 4 sujetos: Fisura, Cartonero,
   Oficinista, CEO).
4. **Aprobar** 3–4 definitivos con el checklist de estilo (esta dentro de
   `hero_prompts.txt`; seccion 3 del asset doc: cabeza 55–60%, outline grueso
   uniforme, paleta lockeada, sin gradientes, silueta legible).
5. Guardar aprobados + 10–15 variantes on-style en `heroes/approved/`.

## Fase 2 — [GATE HUMANO] LoRA de estilo en Tensor.Art

```bash
python3 scripts/prepare_lora_dataset.py
```
Normaliza a 768x768 y escribe un caption `.txt` por imagen con el trigger
`hoboevo_style`. Despues, el humano:

1. tensor.art → Train → LoRA → base **SD 1.5**, defaults.
2. Subir `lora/dataset/` completo (png + txt). Trigger: `hoboevo_style`.
3. Descargar el `.safetensors` a `lora/hoboevo_style.safetensors`
   (el archivo del modelo NO tiene watermark).
4. Importarlo en Draw Things (Manage Models → LoRA) y/o copiarlo a
   `ComfyUI/models/loras/`.
5. **NUNCA** generar imagenes finales en Tensor.Art (watermark del free tier).

## Fase 3 — Prompts (automatico)

```bash
python3 scripts/gen_prompts.py
```
Lee `tiers.json` + `scripts/cultural_dict.py` (la biblia cultural en ingles
visual) + `config.json` → `prompts/prompts.json` (93 assets con seed
determinista) + `prompts/drawthings_tanda_{1..5}.txt` listos para pegar.

## Fase 4 — [GATE HUMANO] Elegir camino de generacion

Se fija en `config.json → generation.active_path` (intercambiable por tanda):

- **`drawthings`** (default, recomendado para tanda 1 — mas rapido en M1):
  el humano pega los prompts de `prompts/drawthings_tanda_N.txt` (prompt,
  negative y SEED exactos) y guarda cada imagen como
  `raw/tanda_N/{assetKey}.png`.
- **`comfyui`** (100% autonomo, ideal corridas nocturnas):
  1. Poner los nombres reales de checkpoint SD 1.5 y VAE fp32 en
     `config.json → generation.comfyui_checkpoint / comfyui_vae`.
  2. Arrancar: `python main.py --force-fp16 --use-split-cross-attention`
  3. `python3 scripts/comfy_batch.py --tanda 1`   (reanudable: skip si existe)

Fallback si un tier dificil falla 3 intentos: IP-Adapter con los heroes en
Draw Things.

## Fase 5 — Loop por tanda (automatico salvo mini-gates)

```bash
# 1. Recorte de fondo (rembg isnet-general-use; backgrounds se copian tal cual)
python3 scripts/cutout_batch.py --tanda 1

# 2. (SOLO la primera vez por familia) [GATE HUMANO] calibrar QA:
#    - characters: anclas = los heroes aprobados
python3 scripts/qa_clip.py --calibrate --family characters \
    --anchors heroes/approved/hero_fisura_01.png heroes/approved/hero_cartonero_01.png \
              heroes/approved/hero_oficinista_01.png heroes/approved/hero_ceo_01.png
#    - ui / backgrounds / fx: mini-gate — el humano aprueba a ojo los primeros
#      3-4 recortes de esa familia y esos pasan a ser las anclas:
python3 scripts/qa_clip.py --calibrate --family ui \
    --anchors cutout/tanda_2/ui_btn_primary.png cutout/tanda_2/ui_coin.png \
              cutout/tanda_2/ui_boost_mate.png
#    (umbral = min(similitud de anclas) - 0.02; arranque de referencia 0.75)

# 3. QA de la tanda: CLIP por familia + paleta lockeada + fondo transparente
#    + contact sheet 120px  ->  approved/ o state/regen_queue.json
python3 scripts/qa_clip.py --batch 1
#    [GATE HUMANO] mirar state/contact_sheet_tanda_1.png (silueta/outline a 120px)

# 4. Fallados: seed nueva (= original + 1000*intento), max 3 intentos
python3 scripts/regen_loop.py
#    - camino comfyui: regenera solo -> repetir pasos 1 y 3
#    - camino drawthings: imprime las instrucciones exactas para el humano

# 5. Export a atlas nativos (@2x/@3x, SIN @1x) + manifest
python3 scripts/organize_atlases.py --tanda 1
python3 scripts/update_manifest.py
```

Destinos (lowercase exacto = campo `atlas` del manifest):
`Resources/earth.atlas/`, `cosmic.atlas/`, `specials.atlas/`, `ui.atlas/`
(fx y logo van a ui.atlas), `Resources/Backgrounds/` (sueltos).

Verificacion por tanda: build ok, arte visible, y
`git diff --stat` toca SOLO `Resources/` y `Tools/asset-pipeline/`.

## Fase 6 — [GATE HUMANO] Rescate de rejected + cierre

- `rejected/{key}.reason.txt` explica cada descarte tras 3 intentos. El humano
  lo regenera a mano (IP-Adapter con heroes suele destrabar) y guarda el PNG
  final directo en `approved/{key}.png` → repetir fase 5 pasos 5.
- Cierre de F3:

```bash
python3 scripts/update_manifest.py --verify   # exit 0 SOLO con checklist completo
```

- AppIcon: exportar el `logo` aprobado a 1024x1024 **sin alpha** al asset
  catalog (reemplaza el placeholder de F0).
- [GATE HUMANO] final: jugar el build completo y aprobar el arte en contexto.

## Extras

- **Vectorizado opcional** (no bloquea nada):
  `vtracer --input cutout/tanda_1/homeless.png --output svg/homeless.svg --mode polygon --color_precision 6`
- **Upscale premium opcional:** dejar un master 1536 en `approved/masters/{key}.png`
  y `organize_atlases.py` lo usa en lugar del upscale automatico.
- Errores tipicos M1: artefactos de color → VAE fp32; OOM → 512 y upscale;
  halos de rembg → ya usamos `isnet-general-use`; ComfyUI lento → tanda de noche.

## Estado en disco

```
prompts/prompts.json          fuente de verdad de los 93 assets (seed incluido)
raw/tanda_N/                  generaciones crudas
cutout/tanda_N/               tras rembg
approved/                     pasaron QA (input de organize_atlases)
approved/masters/             masters 1536 opcionales
rejected/                     descartados tras 3 intentos + motivo
state/qa_report.json          scores CLIP/paleta por asset
state/regen_queue.json        cola de regeneracion con intentos
state/centroids/{familia}.json  centroide CLIP calibrado por familia
state/contact_sheet_tanda_N.png revision humana a 120px
```
