# Render del reel promocional

Los dos reels son código: cada escena dibuja cualquier instante `t` en un
Canvas (sin estado entre frames), con los PNG reales del juego.

- **v1 · «De fisura a Dios»** (30 s): `scene.js` + `music.py` · plan en `../PLAN-promo-reel.md`
- **v2 · «¿Qué hay en el último piso?»** (45 s): `scene2.js` + `music2.py` · plan en `../PLAN-promo-reel-v2.md`
- **v3 · TOP 5 «Demasiado argentino»** (34 s): `scene3.js` + `music3.py` (cumbia)
- **v4 · «DÍA 1 → DÍA 365»** (35 s): `scene4.js` + `music4.py` (lofi)
- **v5 · QUIZ «¿En qué se convierte?»** (33 s): `scene5.js` + `music5.py` (programa de TV)
- **v6 · placa BOFU** (4,5 s): `scene6.js` + `music6.py`; `bofu.sh` arma los tres cortes BOFU

**Inglés (EE. UU.):** todas las escenas aceptan `?lang=en` (`render.mjs --lang en`, `L=en ./finish.sh`, `L=en ./bofu.sh`) y salen en `../en-US/`. Plan y tabla de localización en `../PLAN-en-us.md`; `--poster T` hornea el cuadro T como frame 0 (miniatura).

Guiones de v3–v5 en `../PLAN-anuncios-virales.md`; qué pieza va en cada etapa del embudo, en `../ESTRATEGIA-embudo.md`.

| Archivo | Qué hace |
|---|---|
| `index.html` | Carga `lib.js` y la escena: `?v=2` → v2. `?scale=2` → 4K, `?t=12.5` dibuja un frame, `?play` reproduce en vivo. |
| `lib.js` | Motor compartido: easing, partículas analíticas, tipografía cinética, sprites, motion blur por sub-frames, grano. |
| `scene.js` / `scene2.js` | Las escenas. La v2 reconstruye la UI real del juego (desde las capturas del sitio de Ader Games) con los textos de `Localizable.xcstrings`. |
| `render.mjs` | Levanta un servidor estático del repo, abre Chromium (Playwright) y captura frames. |
| `synth.py` | Instrumentos sintetizados, SFX del juego y master compartidos. |
| `music.py` / `music2.py` | Las bandas (120 y 100 BPM), sincronizadas con cada corte y cada acción. |
| `finish.sh` | Une segmentos, normaliza audio a −14 LUFS y exporta los dos MP4 (`V=2` para la v2). |
| `assets/hero_fisura.png` | El hero aprobado (`Tools/asset-pipeline/heroes/approved/fisura.png`) con el fondo blanco recortado; el dibujo no se toca. |
| `assets/adergames_logo.png`, `assets/app_icon.png` | Logo de Ader Games y el ícono real de la app, del sitio oficial (`manuader/adergames-site`, `public/`). |
| `fonts/` | Baloo 2 ExtraBold, Nunito Black, Inter SemiBold (Google Fonts, OFL). |

## Reproducir

Requisitos: Node 22 + Playwright con Chromium, Python 3 con `numpy scipy`, `ffmpeg`.

```bash
cd Distribution/promo/render
# 1) SFX del juego a wav
mkdir -p out/sfx && for f in ../../../FisuEvolution/Resources/Audio/sfx_*.caf; do
  ffmpeg -loglevel error -y -i "$f" -ar 48000 -ac 1 "out/sfx/$(basename "$f" .caf).wav"; done
# 2) audio
python3 music.py            # v1
python3 music2.py           # v2
# 3) video (4 workers; ~15 min la v1, ~25 min la v2, en 4 núcleos)
node render.mjs video --scale 2 --fps 60 --workers 4
node render.mjs video --v 2 --scale 2 --fps 60 --workers 4   # ídem --v 3, 4, 5, 6
# 4) master
./finish.sh
V=2 ./finish.sh                                                # ídem V=3, 4, 5
# 5) cortes BOFU (necesita los masters de v1, v2 y v3, y el render de la v6)
python3 music6.py && ./bofu.sh
```

Frames sueltos para revisar: `node render.mjs preview --v 2 0.5 11.8 24.5` → `out/preview/`,
y `python3 sheet.py v2` arma una hoja de contacto.

## Mapa de tiempos v1 (120 BPM)

| s | Acto |
|---|---|
| 0–3 | Hook: macro del Fisura, monedas, "DE FISURA…" |
| 3–8 | Mecánica: tap → merge ×4 (Trapito, Limpiavidrios, Cartonero, Mantero) |
| 8–17 | Montaje: calle → elegí tu carrera → torre → espacio (cortes cada ½, ¼ y ⅛ de beat) |
| 17–18,5 | Silencio |
| 18,5–23 | Dios, halo, galaxia — "…A DIOS." |
| 23–26,8 | Logo + teléfono con la mecánica real (tap, comprar, arrastrar, fusionar) |
| 26,8–30 | CTA: DESCARGALO GRATIS + App Store |

## Mapa de tiempos v2 (100 BPM)

| s | Sistema |
|---|---|
| 0–5,6 | Torre de 10 pisos cerrados, luz arriba — "¿QUÉ HAY EN EL ÚLTIMO PISO?" |
| 5,6–13 | Tap, crítico, contratar, arrastrar, fusionar, ¡NUEVO! |
| 13–17 | Ingreso pasivo, El Mantero sube, ¡PISO NUEVO!, ascensor |
| 17–20,5 | Carrera de la UBA |
| 20,5–25,3 | Regalos: racha diaria, boosts, cofre y pinta De Oro |
| 25,3–29 | Eventos (Plan Platita, Mercado Pago) y especial (Crypto Bro) |
| 29–33 | Mejoras permanentes y ganancia offline |
| 33–38 | Reencarnar → Segunda Vida, ×1,6 |
| 38–42,2 | Vuelta a la torre: +30 personajes por descubrir |
| 42,2–45 | CTA + Ader Games |

Para cambiar un tiempo hay que tocarlo en la escena y en su banda (`scene.js`↔`music.py`, `scene2.js`↔`music2.py`).
