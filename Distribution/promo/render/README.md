# Render del reel promocional

Todo el reel es código: `scene.js` dibuja cualquier instante `t` en un Canvas
(sin estado entre frames), con los PNG reales del juego. El plan creativo está
en `../PLAN-promo-reel.md`.

| Archivo | Qué hace |
|---|---|
| `index.html` + `scene.js` | Escena 9:16 (1080×1920 lógicos, `?scale=2` → 4K). `?t=12.5` dibuja un frame; `?play` la reproduce en vivo. |
| `render.mjs` | Levanta un servidor estático del repo, abre Chromium (Playwright) y captura frames. |
| `music.py` | Sintetiza la banda (120 BPM) y mezcla los SFX del juego, sincronizados con los cortes. |
| `finish.sh` | Une segmentos, normaliza audio a −14 LUFS y exporta los dos MP4. |
| `assets/hero_fisura.png` | El hero aprobado (`Tools/asset-pipeline/heroes/approved/fisura.png`) con el fondo blanco recortado; el dibujo no se toca. |
| `fonts/` | Baloo 2 ExtraBold, Nunito Black, Inter SemiBold (Google Fonts, OFL). |

## Reproducir

Requisitos: Node 22 + Playwright con Chromium, Python 3 con `numpy scipy`, `ffmpeg`.

```bash
cd Distribution/promo/render
# 1) SFX del juego a wav
mkdir -p out/sfx && for f in ../../../FisuEvolution/Resources/Audio/sfx_*.caf; do
  ffmpeg -loglevel error -y -i "$f" -ar 48000 -ac 1 "out/sfx/$(basename "$f" .caf).wav"; done
# 2) audio
python3 music.py
# 3) video (4 workers, ~15–20 min en 4 núcleos)
node render.mjs video --scale 2 --fps 60 --workers 4
# 4) master
./finish.sh
```

Frames sueltos para revisar: `node render.mjs preview 0.5 4.8 19.5` → `out/preview/`.

## Mapa de tiempos (120 BPM)

| s | Acto |
|---|---|
| 0–3 | Hook: macro del Fisura, monedas, "DE FISURA…" |
| 3–8 | Mecánica: tap → merge ×4 (Trapito, Limpiavidrios, Cartonero, Mantero) |
| 8–17 | Montaje: calle → elegí tu carrera → torre → espacio (cortes cada ½, ¼ y ⅛ de beat) |
| 17–18,5 | Silencio |
| 18,5–23 | Dios, halo, galaxia — "…A DIOS." |
| 23–26,8 | Logo + teléfono con la mecánica real (tap, comprar, arrastrar, fusionar) |
| 26,8–30 | CTA: DESCARGALO GRATIS + App Store |

Para cambiar un tiempo hay que tocarlo en los dos lados: `scene.js` (MERGES, MONTAGE, escenas) y `music.py`.
