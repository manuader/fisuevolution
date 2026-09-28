# Capturas de App Store — 6.5" (1284×2778)

Tres juegos, todos a la medida exacta que pide Apple. Se sube **uno**.

| Carpeta | Qué es | Cuándo conviene |
|---|---|---|
| `ai-posters-6.5/` | Ilustración generada con ChatGPT desde las referencias del juego + titular | Las más vistosas. **No muestran UI**: ver el aviso de abajo. |
| `ai-posters-6.5-en/` | Las mismas, con titular en inglés | Para la ficha **HoboEvolution**. |
| `posters-6.5/` | Arte real del juego recortado sobre su fondo + titular | Mismo efecto sin IA. Tampoco muestra UI. |
| `posters-6.5-en/` | Las mismas, con titular en inglés | Alternativa sin IA para la ficha en inglés. |
| `promo-6.5/` | Titular + la captura real dentro de un mockup de teléfono | **La mezcla más segura.** Se ve la interfaz de verdad. |
| `crudas-6.5/` | La captura pelada del simulador, sin nada encima | Si preferís que Apple vea la app sin adornos. |
| `ai-crudas/` | Lo que devolvió el modelo, 941×1672, sin recortar ni titular | El original. Rehacer el recorte no cuesta cuota. |

⚠️ Las capturas en `crudas-6.5/` y `promo-6.5/` tienen la **UI en español**.
Para la ficha en inglés hay que volver a sacarlas con `-AppleLanguages "(en)"`;
la app está localizada y el simulador cambia solo. Los pósters no dependen
de eso porque no muestran interfaz.

⚠️ **No subas las cinco puramente ilustradas.** La guideline 2.3.3 pide que las
capturas muestren la app *en uso*. Un set donde no se ve una sola pantalla real
es motivo de rechazo conocido. La mezcla sana: 2 pósters adelante (venden) y
3 de `promo-6.5/` o `crudas-6.5/` atrás (muestran el juego). Las tres primeras
son las que Apple usa en la hoja de instalación, así que ahí van los pósters.

## Cómo se rehacen

```bash
V=/Users/manuader/Desktop/projects/automatic-image-generation/.venv/bin/python
cd Distribution/screenshots
$V ai_posters.py es   # IA + titular español   → ai-posters-6.5/
$V ai_posters.py en   # IA + titular inglés    → ai-posters-6.5-en/
$V posters.py    es   # arte real, español     → posters-6.5/
$V posters.py    en   # arte real, inglés      → posters-6.5-en/
$V mockups.py         # mockup de teléfono     → promo-6.5/ (lee crudas-6.5/)
```

**El idioma es sólo el titular.** El arte no cambia entre `es` y `en`: los
prompts piden cero texto justamente para eso, así que la versión en inglés **no
vuelve a gastar cuota del modelo** — se recompone sobre los mismos PNG de
`ai-crudas/`. Los titulares viven en el dict `TITLES` de cada script.

| # | es | en |
|---|---|---|
| 01 | Arrancás de fisura | You start as a hobo |
| 02 | Fusioná y evolucioná | Merge and evolve |
| 03 | Elegí tu destino (con título) | Pick your destiny (degree included) |
| 04 | Hacete el rey del ladrillo | Become the brick king |
| 05 | Llegá a Dios (literal) | Reach God (literally) |

`posters.py` no usa IA: toma los personajes de
`Tools/asset-pipeline/dropbox/procesadas/` (1024 px, recortados con
`core.cutout` del repo de generación) y los fondos de
`FisuEvolution/Resources/Backgrounds/`. El titular lo dibuja PIL con SF Rounded
Black, que es lo que garantiza que las tildes salgan bien.

## Cómo se sacaron las crudas

Simulador **iPhone 14 Plus** (428×926 pt @3x = 1284×2778 exactos; el 16 Plus NO
sirve, da 1290×2796). Build Debug lanzado así:

```
--screenshot-mode --uitest-skip-tutorial --uitest-unlock-tower
--uitest-seen-types --uitest-coins -AppleLanguages "(es)" -AppleLocale es_AR
```

`--screenshot-mode` apaga el contador de FPS y el botón de debug sin llevarse
los fixtures. La pantalla de carrera sale con `--uitest-career`: jugando cuesta
horas y no vuelve a aparecer hasta reencarnar.

⚠️ La tienda **no carga** en este camino (`No se pudieron cargar las compras`):
le falta la config de StoreKit adjunta al run. No es un bug de la app.

## Los pósters de IA

Generados el 2026-09-21 con el motor **chat-gpt** de
`automatic-image-generation`, proyecto `fisu-store-promo`: 5/5 a la primera
(el 04 necesitó un reintento). Cada prompt adjunta el personaje del juego como
referencia y pide explícitamente **cero texto** —el titular lo dibuja PIL, que
es lo único que garantiza las tildes— y **ninguna marca real**, por lo que se
encontró en el arte de El Influencer.

El modelo devuelve 941×1672 (9:16). App Store pide 1284×2778, que es más alto:
`ai_posters.py` escala a cubrir por altura y recorta al centro en ancho.

Para regenerarlos hace falta el permiso de Accesibilidad de macOS (Ajustes →
Privacidad y seguridad → Accesibilidad) **y reiniciar la app que tildaste**.
Sin eso todo falla con `osascript is not allowed to send keystrokes (1002)`, y
cambiar de motor no ayuda: Gemini y ChatGPT comparten el tipeo en
`core/webchat.py:100`.

⚠️ `generate.py --engine chat-gpt --probe` reporta `"blocked": "alcanzó su
límite de uso"` **aunque no haya ningún límite**. Es un bug del probe: escanea
`page_source` hardcodeado (`core/webchat.py:697`) en vez de respetar
`BLOCK_SCAN = "visible"` del motor, y el HTML de ChatGPT trae esa frase dentro
de un script de la interfaz. La corrida real usa `_check_blocked()`, que sí lo
respeta, así que el falso positivo no frena nada. Ignorá ese campo del probe.
