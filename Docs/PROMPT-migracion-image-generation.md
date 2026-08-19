# Prompt — migrar el runner de imágenes a su propio proyecto

> Pegale esto a un agente. Está escrito para ejecutarse sin volver a preguntar
> nada que ya esté acá, y para que lo que NO se sabe quede marcado como no sabido.

---

## Qué hay que lograr

Sacar el generador de imágenes por navegador de `FisuEvolution` a su propio
proyecto, y dejarlo preparado para trabajar contra **dos proveedores**:

```
/Users/manuader/Desktop/projects/automatic-image-generation/
  gemini/      # el runner actual, funcionando
  chat-gpt/    # el mismo circuito, contra ChatGPT
```

Hoy vive en `/Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/`.

---

## Antes de escribir una línea

Leé, en este orden:

1. `FisuEvolution/Docs/HANDOFF-arte-gemini.md` — **el documento más importante**.
   Tiene "lo que funcionó y por qué", "lo que NO funcionó (no reintentar)" y seis
   bugs con su causa. Cada una de esas líneas costó horas de debug.
2. `FisuEvolution/Docs/HANDOFF.md` §2 (reglas del repo) y §7 (trampas). La 11 es
   la que te va a frenar a vos.
3. `Tools/asset-pipeline/scripts/gemini_selenium_runner.py` **entero**. Son 1.022
   líneas y los comentarios explican decisiones, no sintaxis.
4. `Tools/asset-pipeline/tests/test_gemini_selenium_runner.py` — 855 líneas, 45
   tests. Es la red y también la documentación ejecutable del contrato.

---

## El riesgo número uno, y lo primero que tenés que resolver

**El pipeline NO es autónomo: está acoplado al juego.** Medido: 13 de los 19
scripts referencian rutas de `FisuEvolution` (`assets_manifest.json`, los
`.atlas`, `Resources/`). Si movés todo tal cual, el circuito de arte del juego
deja de funcionar.

Hay tres capas y sólo una es del proveedor:

| Capa | Qué es | Ejemplos |
|---|---|---|
| **Genérica** | Cola, checkpoint, verificación de PNG, orquestación | `Asset`, `parse_asset`, `pending_assets`, `verify_png`, `RunCheckpoint`, `mark_asset_done`, `AssetRunner`, `chunk_prompt` |
| **Del proveedor** | Manejar el navegador y esa web puntual | toda la clase `GeminiBrowser`, `launch_gemini_chrome.py` |
| **Del juego** | Integrar el resultado a FisuEvolution | `process_dropbox.py`, `update_manifest.py`, `organize_atlases.py`, `manifest_keys`, `cultural_dict.py`, `gen_prompts.py`, `gen_skin_prompts.py` |

**Tu primera tarea es proponer, por escrito y antes de mover nada, qué pasa con
la tercera capa**, con sus consecuencias explícitas. No la decidas en silencio.
Las opciones obvias son: dejarla en FisuEvolution y que consuma el paquete nuevo;
duplicarla y dejar que diverjan; o moverla y apuntar FisuEvolution a la ruta
nueva. Cada una tiene un costo distinto y el dueño lo tiene que ver.

Restricción dura: **cuando termines, el circuito de arte de FisuEvolution tiene
que seguir funcionando.** Se comprueba corriendo sus tests, no mirando el código.

---

## Qué NO mover

- `ComfyUI/` — **11 GB**, gitignorado, y el propio handoff lo declara *"fallback
  muerto"*. No se mueve ni se copia.
- `.venv/`, `.chrome-profile/`, `.secrets/` — gitignorados. Se recrean.
- `state/selenium-run.json` — gitignorado, es estado de corrida.
- `dropbox/procesadas/` son **228 MB** de originales históricos, y varios son
  referencia viva de los prompts (`*.ORIGINAL-*`) o evidencia de qué no funciona
  (`*.FALLIDO-*`, `*.RECHAZADA-*`). Decidí explícitamente si van, y decilo.

## Sobre las skills

**En el repo no hay ninguna `SKILL.md`** — lo verifiqué. Si el proyecto nuevo
lleva skills, las escribís vos desde cero. Que sean pocas y sobre lo que de
verdad se repite: levantar el navegador, correr la cola, integrar el resultado.

---

## La parte de ChatGPT: lo que NO podés asumir

Acá es donde un agente apurado rompe todo. El adaptador de Gemini es el resultado
de mucho debug contra una **defensa anti-bot deliberada**, y lo que funciona ahí
está pegado a ESA web:

- El prompt se escribe con **keystrokes reales de macOS** (`osascript` + System
  Events), no con Selenium: `send_keys` a Quill no aterriza, y CDP
  `Input.insertText` entra pero deja el botón de enviar deshabilitado porque el
  evento no es "trusted".
- La referencia se adjunta por **portapapeles + `cmd+v`**, que además da foco real
  a nivel OS.
- La imagen se extrae por **canvas → `toDataURL`**, porque el botón de descarga es
  hover-only y los `blob:` se revocan. Y cuando el canvas queda *tainted* (imagen
  cross-origin), se baja el `src` con las cookies de la sesión.
- La generada se distingue de la referencia por **huella de píxeles** (MAE sobre
  un thumbnail 32×32).

**Nada de eso es un requisito de ChatGPT: son hipótesis a re-verificar.** Puede
que ChatGPT acepte algo mucho más simple, o que rompa de otra forma.

Entonces, para `chat-gpt/`:

1. **Primero descubrí**, con el navegador abierto y una sola generación: cómo se
   escribe el prompt, cómo se adjunta la imagen, cómo se detecta que terminó y
   cómo se baja el resultado.
2. **Escribí sólo lo que comprobaste.** Nada de portar `GeminiBrowser` renombrado
   "por las dudas". Si un paso resulta innecesario en ChatGPT, no existe.
3. Anotá lo que NO funcionó, igual que hace `HANDOFF-arte-gemini.md`. Ese
   documento vale más que el código.

Si el adaptador de ChatGPT no se puede terminar sin correr el navegador, **dejalo
explícitamente incompleto y decilo**. Es infinitamente mejor que un adaptador
inventado que parece listo.

---

## El gate que te va a frenar (trampa 11)

**No vas a poder correr el runner vos.** Manda las teclas con
`osascript`/System Events, que necesita el permiso de **Accesibilidad de macOS**;
Terminal.app lo tiene, el shell de un agente no, y no se lo puede dar a sí mismo.
Falla siempre así:

```
System Events got an error: osascript is not allowed to send keystrokes. (1002)
```

Falla en el primer asset, **sin consumir cuota**, así que probarlo es barato.

Consecuencia práctica: todo lo que no sea "manejar el navegador" —la cola, el
checkpoint, la verificación, los tests, la estructura— lo desarrollás y lo probás
vos. Lo que necesita navegador se lo pasás al dueño **como un comando listo para
pegar**, y esperás su resultado antes de seguir.

---

## Cómo trabajar

- **TDD.** Los 45 tests existentes son el contrato: los que sigan aplicando tienen
  que seguir en verde, y lo nuevo se escribe con su test primero. Ojo con uno que
  ya mordió: un test que toca el navegador real es flaky — stubealo.
- **Mimetizá el código que ya está.** Mismo estilo, mismos nombres, misma densidad
  de comentarios: acá los comentarios explican **por qué**, no qué.
- **Clean code y simplicidad.** No escribas código que no hace falta hoy. No
  inventes abstracciones para un tercer proveedor que nadie pidió. Patrones
  conocidos y probados.
- **No asumas.** Si no sabés algo, verificalo o marcalo como no sabido. Un
  `--dry-run` que da la cola vacía y una tabla inventada se parecen mucho en un
  informe y nada en la realidad.
- **Commits en español**, atómicos, con el porqué en el cuerpo.
- Cada dependencia real está en `requirements.txt` (lo que importa acá:
  `selenium==4.39.0`, `pillow`, `rembg[cpu]`, `requests`).

---

## Qué entregar

1. El proyecto en `/Users/manuader/Desktop/projects/automatic-image-generation/`
   con `gemini/` y `chat-gpt/`, y lo genérico donde no se duplique.
2. **`gemini/` funcionando igual que hoy**, con sus tests en verde.
3. `chat-gpt/` hasta donde llegue sin el gate humano, con lo que falta escrito.
4. Su documentación, al nivel de `HANDOFF-arte-gemini.md`: qué funciona, qué no
   reintentar, y los bugs con su causa.
5. **La prueba de que FisuEvolution no se rompió**, con el resultado de sus tests.
6. Un informe honesto: qué moviste, qué dejaste, qué decisiones tomaste y cuáles
   necesitan al dueño, y qué quedó sin hacer y por qué.
