# FisuEvolution — Plan del reel promocional (pauta paga)

**Pieza:** motion graphics 2D, vertical 9:16, **30 s**, 2160×3840 (4K UHD) a 60 fps + versión 1080×1920 para subir directo.
**Objetivo de pauta:** instalación (CPI) en Meta Reels / TikTok / YouTube Shorts, LatAm (foco AR).
**Una idea:** *De fisura a Dios.* El juego completo es una escalera social absurda; el reel la recorre entera en 30 segundos y te deja con la pregunta.

## 1. Qué tiene que entender el que scrollea

| Pregunta | Respuesta en pantalla |
|---|---|
| ¿Qué es? | Un juego de fusionar personajes para evolucionar (merge-idle). |
| ¿Cómo se juega? | Tapeás → plata. Arrastrás uno igual sobre otro → se fusionan en el siguiente nivel. |
| ¿Por qué me engancha? | La escalera: del Fisura al Trapito, al CEO, al dueño de la Luna… a Dios. |
| ¿Qué hago ahora? | Descargarlo gratis en el App Store. |

Humor argentino y sátira como tono; la dinámica del juego contada sin inventar nada: sólo la mecánica real (tap, merge de dos iguales, tiers, carreras, fases Tierra/Cosmos) y el arte real.

## 2. Reglas de identidad (no negociables)

- **Sólo assets del repo**: `earth.atlas`, `cosmic.atlas`, `ui.atlas`, `Backgrounds/`, `heroes/approved/fisura.png`, `logo@3x.png`, SFX de `Resources/Audio`. Ningún personaje redibujado ni generado; se animan los PNG tal cual (escala, rotación, squash & stretch, parallax, luz y partículas por encima).
- **Paleta de la app** (`Assets.xcassets`): Ink `#2C2C2C`, Cream `#FFF8E7`, Yellow `#FFD93D`, Orange `#FF6B35`, Pink `#FF4D6D`, Blue `#4D96FF`, Green `#6BCB77`, Parchment `#F1E5C9`, Brown `#7A4E26`.
- **Tipografía**: redondeada y gorda como SF Rounded de la app → *Baloo 2 ExtraBold* para titulares, *Nunito Black* para números. Titulares en crema/amarillo con **contorno de tinta grueso**, igual que el arte (stickers de trazo negro).
- 2D puro: sin 3D, sin fotorrealismo, sin stock, sin UI inventada. El tablero del cierre se arma con piezas reales del juego (sprites, moneda, botones) y muestra la mecánica real.

## 3. Retención — cómo se sostiene cada segundo

- **0,0 s ya pasa algo**: nada de logo al principio. Primer frame = ojos del Fisura en primerísimo plano + explosión de monedas. El texto aparece en el frame 6.
- **Promesa en 1 segundo**: "DE FISURA…" plantea una transformación; el cerebro espera el "a qué".
- **Loop abierto**: la palabra "DIOS" se guarda hasta el segundo 19. Todo lo del medio es el camino.
- **Cortes cada 0,5 s o menos** en el montaje (120 BPM, corte por beat → medio beat). Cada corte cambia escala, color o dirección.
- **Pattern interrupt** en el 17: silencio total y cámara lenta después de 9 s de aceleración. Es el momento más recordable y el que se screenshotea.
- **Payoff + pregunta**: "¿HASTA DÓNDE VAS A LLEGAR?" convierte el final en desafío personal; el último frame vuelve a los ojos/monedas para que el loop de Reels empalme.
- Legible **sin sonido** (todo el relato tiene texto) y **con sonido** (cada impacto está sincronizado).
- Safe zones de Reels/TikTok respetadas: nada crítico en el 12 % superior ni en el 20 % inferior (lado derecho libre para los botones de la plataforma).

## 4. Guion / storyboard (120 BPM · 1 beat = 0,5 s)

| Tiempo | Acto | Imagen | Texto | Sonido |
|---|---|---|---|---|
| 0,0–3,0 | **Hook** | Callejón porteño (`bg_alley`). Macro del Fisura (hero 2048 px) → zoom-out dramático con parallax piso/pared. Una moneda gira, cae y **explotan monedas** hacia cámara. | **DE FISURA…** (golpe letra por letra) | Impacto sub + lluvia de monedas (`sfx_coin` en capas) + riser |
| 3,0–5,5 | **Mecánica: tap + merge** | Dedo tapea al Fisura: `fx_tap`, "+1" con `ui_coin`. El Fisura **se duplica**; los dos se cruzan, *squash & stretch*, flash dorado, rayos y partículas → aparece **El Trapito**. | **TAPEÁ** → **FUSIONÁ.** | Tap, whoosh inverso, `sfx_merge` + boom |
| 5,5–8,0 | **Mecánica: evolución** | Segundo merge al doble de velocidad: Trapito + Trapito → **Limpiavidrios**. Contador "NIVEL 3". | **EVOLUCIONÁ.** | `sfx_evolution`, arranca el beat completo |
| 8,0–11,0 | **Montaje: la calle** | Cartonero → Mantero → Repartidor → Chofer de App → Fast Food. Match cuts sobre la silueta, camera punches, fondo `bg_urban`. Contador de plata $ subiendo. | **DE LA CALLE…** | Kick 4/4, hats a 16avos, whoosh por corte |
| 11,0–12,5 | **Carreras** | Grilla 2×2 de los Junior (programador, arquitecta/o, médico, abogado) — la elección real del tier 11. | **ELEGÍ TU CARRERA** | Stabs |
| 12,5–15,0 | **Montaje: la torre** | Whip pan a `bg_corporate` / `bg_luxury`: CEO → Millonario → Rey del Ladrillo → Magnate Petrolero → Space Billionaire. | **…A LA TORRE…** | Riser ascendente, cortes cada medio beat |
| 15,0–17,0 | **Montaje: el espacio** | Whip pan vertical al cielo: `bg_moon` → `bg_mars` → `bg_solar` → `bg_galaxy` con Dueño de la Luna, Dueño de Marte, Magnate Solar, Señor de la Galaxia. | **…AL ESPACIO…** | Todo acelera, pitch sube |
| 17,0–18,5 | **Silencio** | Corte seco. Negro/cielo profundo, polvo de estrellas flotando lento. | — | Silencio total → viento suave |
| 18,5–23,0 | **Dios** | `bg_god_realm`: sube **Dios** sobre las nubes, halo dorado que se expande, galaxia rotando detrás, rayos. | **…A DIOS.** | Pad coral + boom + brillo |
| 23,0–26,5 | **Juego real** | Logo (emblema real) golpea + wordmark. Tablero con piezas del juego: dos Fisuras, la manito arrastra uno sobre el otro → merge → contador sube. | **FISUEVOLUTION** · **¿HASTA DÓNDE VAS A LLEGAR?** | Vuelve el beat, monedas |
| 26,5–30,0 | **CTA** | End card: logo, "DESCARGALO GRATIS", badge App Store, fila de caras de todos los tiers pasando. | **DESCARGALO GRATIS** | Golpe final + cola |

## 5. Movimiento

- Easing propio por intención: `expoOut` para entradas (llegan rápido y frenan), `backOut` para golpes de texto/logo, `expoIn` para salidas y whips.
- Squash & stretch en todo lo que aterriza (conservación de volumen: `sx = 1/sy`).
- Motion blur real por acumulación de sub-frames en whip pans y en los golpes.
- Parallax: fondo al 30–50 % de la velocidad de cámara, personaje al 100 %, partículas y texto al 120 %.
- Camera shake con decaimiento exponencial en cada impacto; nunca continuo.
- Luz animada: rayos rotando, glow aditivo, flash de 2 frames en cada merge.

## 6. Entregables

- `FisuEvolution_Reel_30s_4K.mp4` — 2160×3840, 60 fps, H.264 High, AAC 320 kbps (master).
- `FisuEvolution_Reel_30s_1080.mp4` — 1080×1920, 60 fps (subida directa a Meta/TikTok).
- Código fuente reproducible en `Distribution/promo/render/` (escena en Canvas, render determinístico por frame con Playwright + ffmpeg, música sintetizada en `music.py`).

## 7. Pauta — recomendaciones

- **Test A/B de hook** (primeros 2 s) antes de escalar: (A) macro de ojos + monedas (este corte); (B) arrancar en el merge. Medir *thumb-stop rate* (3 s views / impresiones) y hold al 50 %.
- Copy del anuncio: *"Arrancás de fisura. ¿Llegás a Dios? 🪙 Gratis en iPhone."*
- Segmentación inicial: AR 18–34, intereses juegos casuales/idle/humor; luego lookalike de instaladores.
- Cortes derivados con el mismo código: 15 s (hook + merge + Dios + CTA) y 6 s bumper (merge + logo).
- Reemplazo recomendado cuando haya build de store: el tramo 23–26,5 s por captura real del simulador con el mismo encuadre, para cumplir 100 % con políticas de "gameplay representativo".
