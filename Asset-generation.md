# HOBO EVOLUTION — Generación de Assets (guía para Claude Code)

**Cómo generar TODO el arte del juego: gratis, consistente, en una MacBook Air M1.**

Companion del build bible (fase F3). Este doc es para vos, Claude Code. Define herramientas, estilo, prompts, consistencia y el pipeline completo. El código nunca toca un sprite directo: todo termina en `assets_manifest.json`.

---

## 0. Leé esto primero: hardware y división de trabajo

### Realidad de la M1 Air

- **Modelo a usar: Stable Diffusion 1.5.** No SDXL (16GB es el piso práctico y la Air sufre/swappea), **no Flux** (pide 24GB+, se cuelga). Para arte flat vector cartoon, SD 1.5 + un buen LoRA de estilo **alcanza y sobra** — no necesitás fotorrealismo.
- Tiempos esperables local: ~30–90s por imagen en SD 1.5 512–768. Perfecto para tandas grandes de noche.
- Si la Air es de **8GB**, andá seguro con SD 1.5 a 512, upscale después. Si es 16GB, podés estirar a 768 y probar SDXL-Turbo puntual, pero no lo necesitás.

### Qué automatizás vos (Claude Code) vs qué es del humano

**Vos NO podés** (pedíselo al humano, no lo simules):
- Aprobar los *hero images* (es criterio estético — de ahí sale el look "handmade").
- Operar la GUI de Draw Things ni la web de Tensor.Art para apretar "entrenar/generar".

**Vos SÍ podés, 100% automatizado:**
- Generar todos los archivos de prompts y la lista de batch (desde `tiers.json` + la biblia cultural).
- Manejar generación local vía **API de ComfyUI** (si se elige ese camino).
- Correr TODO el downstream: recorte de fondo, QA de consistencia, vectorizado, atlas, manifest, organización de carpetas, lista de regeneraciones.
- Instruir al humano exactamente qué hacer en cada gate manual.

> **Regla:** cuando llegues a un gate humano, frená y devolvé instrucciones precisas (qué subir, qué settings, qué descargar y dónde ponerlo). No inventes que las imágenes ya existen.

---

## 1. Herramientas (todas gratis, elegidas para M1 Air)

| Rol | Herramienta | Por qué | Dónde | Quién opera |
|---|---|---|---|---|
| **Entrenar LoRA de estilo** | **Tensor.Art** (100 créditos gratis/día, sin GPU, soporta SD 1.5 + LoRA + ControlNet) | La Air no entrena bien; esto lo hace la nube gratis. Descargás el `.safetensors` (el archivo del modelo NO tiene watermark) | Nube | Humano (vos preparás dataset + captions) |
| **Generar imágenes (camino A: automatizable)** | **ComfyUI** (MPS en Apple Silicon, tiene API local en `localhost:8188`) | Único camino donde VOS generás autónomo, sin watermark, ilimitado | Local | Claude Code (vía API) |
| **Generar imágenes (camino B: mejor en M1)** | **Draw Things** (App Store, gratis, nativo Metal, ~20% más rápido que ComfyUI, importa LoRAs y hace ControlNet/IP-Adapter) | La mejor herramienta cruda para M1, sin watermark, ilimitada. Pero es GUI | Local | Humano (en tandas) |
| **Recorte de fondo** | `rembg` (pip, corre en M1) | Fondo transparente limpio, batch | Local | Claude Code |
| **QA de consistencia** | `open_clip` (pip) para distancia de estilo; **Gemini free tier** opcional para chequeo semántico | Objetiva "¿es consistente?" sin costo. CLIP es 100% local, sin API | Local | Claude Code |
| **Vectorizado (opcional)** | `vtracer` (CLI) | PNG flat → SVG con outlines limpios, escala infinita, poco peso | Local | Claude Code |
| **Atlas de sprites** | **Carpetas `.atlas` nativas de Xcode** (SpriteKit las empaqueta solo al buildear) | Cero herramientas de terceros, cero watermark, nativo | Local | Claude Code |
| **Manifest** | script propio | Junta arte ↔ código | Local | Claude Code |

**Nota watermark:** Tensor.Art pone watermark en las *imágenes* del free tier → NO generes assets finales ahí. Usalo **solo para entrenar el LoRA** (el `.safetensors` que bajás no tiene marca) y generá las imágenes local. Así "gratis" es sostenible y sin marcas.

**Nota Civitai:** también tiene entrenador de LoRA sin GPU, pero hoy cobra en cripto y por LoRA. Tensor.Art es la opción free más limpia en 2026.

---

## 2. Local vs nube — recomendación cerrada

**Entrenás en la nube, generás local.** Es lo que mejor encaja con una M1 Air:

- **Entrenamiento → nube (Tensor.Art, gratis):** es lo pesado en GPU y lo único que la Air hace mal. Una sola vez. Descargás el LoRA.
- **Generación → local (Draw Things o ComfyUI, gratis):** es lo liviano (inference), la Air lo banca, sin watermark, sin límites, sin cuidar free tiers.
- **Downstream → local (Claude Code):** rembg + CLIP + vtracer + atlas + manifest, todo offline y gratis.

**¿Draw Things o ComfyUI para generar?**
- Si querés que **Claude Code genere solo** → **ComfyUI** (tiene API local). Más lento en M1, pero automatizable de punta a punta.
- Si preferís **velocidad y simpleza** y no te molesta apretar generate → **Draw Things**, y Claude Code te pasa la lista exacta de prompts + settings y hace todo lo demás.
- **Recomendado:** empezá con Draw Things para validar el look rápido; si el volumen te cansa, pasá la generación a ComfyUI-API para que Claude Code la corra de noche.

Nube de generación (Tensor.Art credits) queda solo como **fallback** si la Air está ocupada — recordando el watermark.

---

## 3. Estilo de generación (dirección de arte — ancla de consistencia #1)

Cada imagen tiene que verse así, sin excepción:

- **2D flat vector cartoon**, una sola dirección de arte.
- **Cabeza grande / cuerpo chico**: cabeza ≈ 55–60% de la figura.
- **Outline negro grueso y uniforme**, mismo grosor en todo.
- **Colores planos, cel-shading mínimo, SIN gradientes.** Una sola fuente de luz suave arriba-izquierda.
- **Paleta lockeada:** `#FFD93D #FF6B35 #FF4D6D #4D96FF #6BCB77` + `#FFF8E7 / #2C2C2C / #FFFFFF`.
- **Vista 3/4**, personaje centrado, cuerpo completo, pose idle neutra, margen de seguridad generoso, canvas cuadrado, **fondo transparente** (o blanco liso para recortar).
- Silueta clara y legible. Tono comedia-adulto, expresión graciosa.

**Nunca:** realismo, anime, pixel art, 3D, luz fotográfica, gradientes, fondo cargado.

Este bloque es lo que el LoRA de estilo va a "aprender" de los heroes. Es la fuente de verdad visual.

---

## 4. Sistema de prompts + consistencia

### 4.1 Prompt maestro (fase heroes / si no usás LoRA todavía)

```
Official "Hobo Evolution" game asset. 2D flat vector cartoon, single art
direction. Big-head/tiny-body (head ≈ 55–60% of figure). Uniform thick black
outline, constant weight. Flat colors, minimal cel-shading, NO gradients,
single soft light top-left. Palette: #FFD93D #FF6B35 #FF4D6D #4D96FF #6BCB77
with #FFF8E7 / #2C2C2C / #FFFFFF. 3/4 view, centered, full body, neutral idle
pose, generous safe margin, square canvas, transparent background. Clean
readable silhouette, adult-comedy tone, humorous expression. Mobile-game
production quality, cohesive studio look.
Negative: realism, anime, 3d, pixel art, photographic lighting, gradients,
busy background, blurry, extra limbs, watermark, text.
--- APPEND PER ASSET ---
Subject: {subject}. Props: {props}. Cultural cues: {ar_cues}.
Wealth cues: {wealth_cues}. Expression: {expression}.
```

Con LoRA entrenado, el prompt operativo se **acorta** a:
```
<hoboevo_style>, {subject}, {props}, {ar_cues}, {wealth_cues}, {expression}
Negative: watermark, text, blurry, extra limbs
```
(el estilo ya vive en el LoRA — dejás de pelear el prompt).

### 4.2 `prompts.json` (Claude Code lo genera y maneja el batch)

Generalo desde `tiers.json` + la biblia cultural. Estructura:
```json
[
  {
    "assetKey": "homeless_idle",
    "category": "character",
    "tier": 1,
    "atlas": "earth",
    "subject": "scruffy street man with attitude",
    "props": "bottle, tattered layered clothes",
    "ar_cues": "Buenos Aires street 'fisura' vibe, disheveled but endearing",
    "wealth_cues": "none, dirty patched clothes",
    "expression": "dazed goofy stare",
    "seed": 100001
  }
]
```

### 4.3 Disciplina de consistencia (lo técnico — no negociable)

Para que 38 personajes + UI + fondos parezcan del mismo estudio:

1. **LoRA de estilo fijo** en todas las generaciones (o IP-Adapter con los heroes si no hay LoRA).
2. **Trigger word único**: `hoboevo_style` en cada prompt.
3. **Seed por familia**: mismo seed base para toda una familia de personajes ayuda a la coherencia; variá solo lo necesario. Guardá el seed usado en `prompts.json` para poder regenerar idéntico.
4. **Parámetros fijos SD 1.5** (mismos en todo):
   - Sampler: `DPM++ 2M Karras` o `Euler a`
   - Steps: `28`
   - CFG: `7`
   - Resolución: `512×512` (o `768×768` si 16GB), upscale a 2x con RealESRGAN
   - VAE: fp32 en Mac para evitar artefactos
5. **IP-Adapter con los 3–4 heroes** como refuerzo de estilo (opcional si el LoRA es bueno; útil para los tiers difíciles).

---

## 5. Creatividad, bizarro, argentino (inyección de tono)

**Concepto clave:** SD 1.5 no "sabe" qué es un cartonero ni un egresado de la UBA. La argentinidad se logra por **descripción visual explícita de props**, no por escribir "argentino". El LoRA de estilo unifica el look; los `ar_cues` + `props` meten la cultura; la creatividad vive en props/expresión/pose (nunca en el estilo, que queda fijo).

**Balance creatividad ↔ consistencia:** el estilo es constante (LoRA). Lo que varía y le da vida: props absurdos, expresiones exageradas, guiños culturales. Ahí metés el humor adulto-bizarro.

### Recetas de prompt por arquetipo (los `ar_cues` + `props`)

| Personaje | props / ar_cues (en inglés, específicos) |
|---|---|
| El Fisura (T1) | `bottle, tattered clothes, dazed eyes, disheveled street man` |
| Cartonero (T2) | `pushing a cart piled with flattened cardboard, hi-vis reflective vest` |
| Kiosco (T3) | `behind a small shop counter, pack of cigarettes, sleeping cat beside him` |
| Repartidor (T4) | `generic food-delivery backpack (parody, no real brand), helmet, beat-up scooter` |
| Chofer de App (T5) | `car, courtesy water bottle and lollipop on the dashboard` |
| Fast food (T6) | `fast-food uniform and paper hat (parody 'McRonald's'), resigned face` |
| Oficinista (T7) | `dress shirt, eye bags, a mate gourd on the desk` |
| Egresado UBA (T9) | `young graduate holding a rolled diploma proudly, empty pockets` |
| Programador Jr | `laptop covered in stickers, dark-mode screen glow, multiple monitors` |
| Arquitecto Jr | `rolled blueprints, small building model, scale ruler` |
| Rey del Ladrillo (T18) | `real-estate mogul, holding a brick and a tower model` |
| Crypto Bro (special) | `flashy watch, phone showing green candlestick chart, smug grin` |
| Demonio de ARCA (special) | `bureaucratic demon with tax forms and a red stamp, bat wings` |

**Boosts (íconos):** mate gourd, cargado coffee cup, Fernet-and-cola glass, milanesa, asado grill — mismo estilo flat, misma paleta.

**Tono:** exageración, ojos gigantes, poses ridículas. Adulto-bizarro pero **shipeable** (ver nota de review en el build bible: nada realista de drogas). La comedia es el marketing — cada personaje tiene que dar ganas de mandarlo por WhatsApp.

---

## 6. Pipeline paso a paso (lo que ejecutás vos, Claude Code)

```
[HUMANO] Genera 3–4 hero images → aprueba el look
   ↓
[HUMANO + CC] Entrenar LoRA de estilo en Tensor.Art
   ↓         (CC prepara dataset + captions + trigger word 'hoboevo_style')
[CC] Genera prompts.json desde tiers.json + biblia cultural
   ↓
[CC o HUMANO] Generar batch  (CC via ComfyUI API  |  Humano en Draw Things)
   ↓
[CC] rembg → recorte de fondo (batch)
   ↓
[CC] QA de consistencia (CLIP + opcional Gemini) → lista de reject/regenerate
   ↓         (loop hasta pasar umbral o N intentos → escalar a humano)
[CC] Vectorizar (opcional) con vtracer
   ↓
[CC] Organizar en carpetas .atlas por fase
   ↓
[CC] Generar assets_manifest.json y wirear
```

### Comandos de referencia (todo local, todo gratis)

```bash
# Setup
pip install rembg open_clip_torch pillow
brew install vtracer            # vectorizado opcional

# Recorte de fondo (batch, carpeta → carpeta)
rembg p ./raw ./cutout

# ComfyUI en Mac (si camino A). Flags para Apple Silicon:
python main.py --force-fp16 --use-split-cross-attention
# (si hay artefactos de VAE, forzar VAE fp32 en el workflow)

# Vectorizado flat → SVG
vtracer --input cutout/homeless_idle.png --output svg/homeless_idle.svg \
        --mode polygon --color_precision 6
```

### QA con CLIP (script que Claude Code escribe)

Lógica: computás el embedding CLIP de cada hero, sacás el **centroide**, y para cada asset medís la **similitud coseno** contra ese centroide. Debajo de umbral → outlier de estilo → regenerar con seed nueva.

```python
# pseudo: open_clip
hero_embeds = [clip_embed(h) for h in heroes]
centroid = normalize(mean(hero_embeds))
for asset in assets:
    sim = cosine(clip_embed(asset), centroid)
    if sim < THRESHOLD:      # arrancar en ~0.75, calibrar con los heroes
        mark_for_regeneration(asset)
```

Gemini free tier (opcional, chequeo semántico): *"¿Esta imagen muestra claramente {subject} con {props}? ¿El fondo está limpio? ¿El outline es grueso y uniforme? Respondé JSON {ok, reason}."*

### Atlas nativo de Xcode (cero herramientas de terceros)

Organizá los PNG finales en carpetas nombradas `Earth.atlas`, `Cosmic.atlas`, `UI.atlas`, etc. SpriteKit las empaqueta solo al buildear. No necesitás TexturePacker.

---

## 7. Definición de "consistente" + gate de QA

Un asset **pasa** si cumple:
- ✅ CLIP cosine ≥ umbral vs centroide de heroes (calibrá el umbral corriendo los heroes entre sí primero).
- ✅ Outline grueso y uniforme.
- ✅ Paleta dentro del set (chequeo de colores dominantes opcional).
- ✅ Proporción cabeza ≈ 55–60%.
- ✅ Fondo limpio tras rembg (sin halos).
- ✅ Silueta legible a tamaño chico (probá a 120px).

**Loop:** falla → regenerar con seed nueva (mismos params/LoRA) → re-scorear → hasta 3 intentos → si sigue fallando, escalá al humano con el asset y el motivo. Nunca metas al juego un asset que no pasó el gate.

---

## 8. Checklist completo de assets (scope + naming)

Naming: `snake_case`, `{key}_{estado}`. Cada uno declara su `atlas`.

**Personajes (≈38):**
- 30 tiers (T1–T30). En T9 y T10, 4 variantes cada uno (junior/senior × programmer/architect/doctor/lawyer) → +6 sobre el conteo base.
- `homeless_idle`, `cartonero_idle`, … → atlas por fase (`Earth`, `Cosmic`).

**Special characters:** `sp_cryptobro`, `sp_demonio_arca`, `sp_contador_dios`, `sp_zombie_ceo`, `sp_lizard`, `sp_alien_investor`, `sp_bug_simulacion`, `sp_arbolito`, `sp_coach`, `sp_influencer` → atlas `Specials`.

**Backgrounds (11):** `bg_alley`, `bg_urban`, `bg_corporate`, `bg_luxury`, `bg_island`, `bg_moon`, `bg_mars`, `bg_solar`, `bg_galaxy`, `bg_cosmic`, `bg_god_realm` → atlas `Backgrounds` (o texturas sueltas por peso).

**UI — botones:** `ui_btn_primary/secondary/danger/disabled/store/upgrade/reincarnate/watch_ad/claim/collect`.

**UI — currency:** `ui_coin`, `ui_money`, `ui_dollar`, `ui_million`, `ui_billion`, `ui_trillion`, `ui_infinity`.

**UI — upgrade icons:** `ui_up_income`, `ui_up_spawn`, `ui_up_offline`, `ui_up_tap`, `ui_up_crit`, `ui_up_golden`, `ui_up_prestige`.

**Boosts:** `ui_boost_mate`, `ui_boost_cafe`, `ui_boost_fernet`, `ui_boost_milanesa`, `ui_boost_asado`, `ui_boost_turbo`.

**Logo + partículas:** `logo`, `fx_merge`, `fx_money`, `fx_tap`, `fx_unlock`, `fx_evolution_flash` (las partículas pueden ser sprites simples + `SKEmitterNode`).

Todo esto va a parar a `assets_manifest.json` (esquema en el build bible §6.4).

---

## 9. Orden de ejecución (tandas, priorizado)

1. **Heroes → LoRA** (una vez).
2. **Characters tier bajo (T1–T10)**: son los que más se ven, máximo impacto.
3. **UI + currency + boosts**: desbloquean que el juego se vea terminado.
4. **Backgrounds tempranos** (alley, urban, corporate).
5. **Resto de tiers + backgrounds cósmicos.**
6. **Specials + skins (golden/galaxy/god).**

Como generás **local (Draw Things/ComfyUI)**, no hay free tier que cuidar: es ilimitado. Tensor.Art solo se toca para entrenar el LoRA. Por eso el esquema es sostenible sin malabares de trials.

---

## 10. Errores comunes en M1 / SD 1.5 (para no colgarte)

- **No** intentar Flux ni SDXL sin 16GB+. En Air: SD 1.5.
- Artefactos de color en Mac → forzar **VAE fp32**.
- Imágenes lavadas/rotas → bajar a **512**, subir con upscaler después; steps 20–30, no más.
- ComfyUI lento/OOM → cerrá apps, generá de a una, corré la tanda de noche.
- Halos tras rembg → probá el modelo `isnet-general-use` de rembg para bordes limpios.
- Watermark → nunca uses el free tier de Tensor.Art para *imágenes*; solo para *entrenar*.

---

*Fin. El estilo lo fija el LoRA (entrenado en la nube gratis), la cultura la fijan los props/ar_cues, la consistencia la garantiza CLIP, y el arte se enchufa al código por el manifest. Cero costo, corriendo en una M1 Air.*
