# Balde de islas — cómo se usa

Sirve para sacarle a cada personaje los pedacitos sueltos que no van (las
"islas"): una chispa flotando, una sombra suelta, el blanco que quedó pegado
entre las piernas. Funciona como el balde del Paint: un clic pinta la isla
entera.

- **Rojo** = esa isla se saca.
- **Verde** o **sin pintar** = esa isla se queda.

## 1. Abrir

Doble clic en **«Abrir revisión de islas.command»** (en esta misma carpeta).
Se abre una ventanita negra (Terminal) y el navegador con la revisión.
**No cierres la ventanita negra mientras trabajás**: es la que guarda.

La primera vez, macOS puede decir que no puede abrirlo: clic derecho sobre el
archivo → **Abrir** → **Abrir**. Después ya abre con doble clic.

## 2. Elegir un personaje

A la izquierda está la lista. Arriba podés **buscar** por nombre y filtrar por
grupo (Tierra, Cosmos, NPCs, cada familia, Interfaz) y por estado:

- **Sin revisar**: todavía no lo guardaste.
- **Listos**: ya lo guardaste.
- **A regenerar**: los 4 que van a volver a dibujarse (cartonero diamante,
  mantero diamante, estanciero estelar tropero y doctor senior). Podés
  limpiarlos igual, pero probablemente se reemplacen.

Con las flechas **←** y **→** pasás al anterior o al siguiente.

## 3. Pintar

1. Elegí el balde: **Sacar** (rojo, tecla **R**) o **Conservar** (verde, tecla **V**).
2. Hacé clic sobre la isla. Se pinta entera.
3. Al pasar el mouse, la isla que vas a pintar se ilumina en amarillo y un
   cartelito te dice qué es.

Para tener en cuenta:

- Las **islas chiquitas**, que casi no se ven, tienen un **círculo naranja**
  alrededor. Abajo también aparecen todas como botoncitos: pasar el mouse por
  uno la resalta y hacerle clic la pinta. Así no se te escapa ninguna.
- La **"Isla 1"** es siempre la más grande, o sea el personaje: si la pintás de
  rojo te pregunta antes, porque se borraría entero.
- Los **"huecos blancos"** son partes blancas encerradas por el dibujo (una
  camisa, o la loza blanca bajo los pies). Si es una camisa, dejala; si es
  fondo que quedó pegado, pintala de rojo.
- ¿Te equivocaste? **⌘Z** deshace. El balde verde también sirve para
  "despintar" algo rojo. **Borrar pintura** limpia todo el personaje.
- **Cómo queda** (tecla **C**) muestra el personaje sin las islas rojas, como
  va a quedar en el juego. Volvé a **Pintado** para seguir pintando.
- Zoom con **+**, **−** y **Ajustar** (o ⌘ + rueda del mouse). El fondo
  (damero, verde, negro, blanco) se cambia arriba a la derecha.

## 4. Guardar

Cuando esté como querés, tocá el botón verde **Guardar** (o **⌘S**). La imagen
limpia queda en la carpeta **`limpias/`**, el personaje se marca como
**Listo** y la revisión pasa sola al siguiente sin revisar.

Si un personaje no tiene nada que sacar, guardalo igual: así queda marcado
como revisado.

Todo lo que hagas se recuerda: si cerrás y volvés a abrir, sigue donde lo
dejaste (lo guardado y también lo pintado sin guardar). Si después cambiás
algo de uno que ya estaba listo, aparece como **Sin guardar** hasta que lo
vuelvas a guardar.

## 5. Al terminar

Cerrá la ventanita negra y avisale al controlador (el agente) que la revisión
de islas está lista. Si preferís hacerlo vos, desde la carpeta del juego:

```
cd ~/Desktop/projects/FisuEvolution/Tools/asset-pipeline
.venv/bin/python scripts/aplicar_limpias.py --dry-run   # muestra qué cambiaría
.venv/bin/python scripts/aplicar_limpias.py             # lo mete en el juego
```

Eso pone cada personaje limpio en su lugar del juego (en sus dos tamaños) y lo
protege para que un recorte automático futuro no lo pise.
