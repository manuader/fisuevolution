# El generador de imágenes se mudó

**Dónde**: `~/Desktop/projects/automatic-image-generation` (repo propio, commit
inicial `6021318`). Leé su `README.md`: alcanza para operarlo entero.

Este documento era el prompt para que un agente hiciera la migración. La
migración está hecha, así que ahora sólo dice **qué se movió, qué se quedó acá y
por qué** — que es lo único que le hace falta a alguien que trabaje sobre el arte
del juego.

## Qué se movió

Lo genérico: la cola de prompts, el checkpoint, la verificación de PNG, el
recorte de fondo por conectividad y **toda la mecánica de manejar el chat web**
(tipeo por tandas con recuperación de foco, paste de la referencia por
portapapeles, extracción por canvas, huella de píxeles). Allá vive en `core/`, no
sabe qué modelo hay del otro lado ni para qué son las imágenes, y tiene 61 tests
que corren sin navegador.

Se copiaron también los 323 prompts y las 335 imágenes ya generadas a
`projects/fisu-evolution/`, con los paths de referencia remapeados. **No hay que
volver a generar nada**: la cola ve el PNG en `output/` y no lo vuelve a pedir.

## Qué se quedó acá, y por qué

Todo `Tools/asset-pipeline/` sigue igual y sigue siendo el camino del juego.
Nada se borró ni se movió: 13 de los 19 scripts referencian rutas de
FisuEvolution —`assets_manifest.json`, los atlas, `Resources/`— y son
específicamente lo que convierte una imagen en un asset **de este juego**:

- `process_dropbox.py` — recorte → `@2x/@3x` en el atlas correcto → manifest;
- `update_manifest.py`, `organize_atlases.py`, `rightsize_assets.py`;
- `gen_prompts.py`, `gen_skin_prompts.py`, `cultural_dict.py` — los generadores
  de prompts, que saben de tiers y de personajes argentinos.

Sacarlos habría roto el circuito de arte para no ganar nada: no sirven para otro
objetivo. El resultado es que hay dos herramientas y la frontera es clara —
**allá se generan las imágenes, acá se integran al juego**. Lo que se genere en
el proyecto nuevo se copia a `Tools/asset-pipeline/dropbox/` y sigue el camino de
siempre.

`gemini_selenium_runner.py` y `launch_gemini_chrome.py` quedan acá **en desuso**:
su versión viva es la de allá. No se borran todavía porque el HANDOFF los nombra
y porque son la referencia contra la que comparar si algo del motor nuevo sale
distinto.

## Lo que no se movió a propósito

- **ComfyUI** (11 GB): fallback local que el propio HANDOFF declara muerto.
- **`.venv`, `.chrome-profile`, `.secrets`**: gitignoreados y por máquina.
- **El registro `prompts/prompts.json`**: lo lee `process_dropbox.py`, o sea el
  lado del juego. El proyecto nuevo no tiene registro: la cola son los `.md`, y
  punto. Es una fuente de verdad menos.
