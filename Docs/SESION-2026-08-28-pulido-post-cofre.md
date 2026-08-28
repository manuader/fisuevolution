# Sesión 2026-08-28 (cuarta) — El pulido: el cofre en todos lados, el ORO que enseña y los 48 fps

> Pedidos del dueño, en tandas sobre la misma sesión:
> 1. «hace que en la pantalla de bonus donde dice "1 unopened chest" se vea el
>    nuevo cofre en 2d […] elimina todo lo relacionado al cofre viejo para que
>    no hayan mas confusiones» + «que los datos de la skin tarden menos en
>    aparecer».
> 2. «hace que cuando el usuario gane su primer ORO (con un logro) que haya un
>    tutorial que te lleve a la pestaña de mejoras permanentes y te haga
>    elegir» + «el boton de reencarnacion deberia arrancar mucho mucho antes.
>    al llegar a lujo» + «saca lo que dice 1/19 y que diga solo el
>    multiplicador. cuando llega a x20 hace max out».
> 3. «el video de la animacion del cofre se ve muy laggeado […] arregla esto».
>
> Continúa a `SESION-2026-08-28-cofre-definitivo-2d.md` (ter).

## 1. El cofre viejo en Regalos era el ATLAS COMPILADO, no el árbol

La tarjeta mostraba el cofre violeta de un master YA BORRADO con el PNG 2D
sentado en `ui.atlas/`. Causa medida (atlasc del producto con fecha vieja):
**escribir un PNG en el lugar (mismo inode) no cambia el mtime de la CARPETA
`.atlas`**, que es lo que mira el build system para recompilar el atlas — y
todo DerivedData incremental (el mío y el del dueño, mismo checkout) seguía
sirviendo el atlasc anterior. Fix de raíz: `emit_static_chest` hace
`os.utime(UI_ATLAS)` al escribir; verificado con el test de Regalos re-corrido
y su captura (el cofre 2D en la fila). **Trampa nueva en §7 del general.**

Y el purgado pedido: murieron los 4 masters `ui_chest_*` y los 3 `fx_*` del
festejo viejo en `dropbox/procesadas/`, sus 7 prompts `.md` y sus 7 entradas
de `prompts.json` — **incluida la de `ui_chest_closed`**: un batch podría
regenerarla pisando el icono derivado del video (hoy ese asset lo produce
`chest_video_frames.py` y lo gobiernan sus tests).

## 2. Los datos del premio ya no esperan la cola del video

Había ~1,5 s de marco vacío mirándote: la carta queda derecha a los 6,5 s del
tramo (f206) y el resto es cola de destellos, pero el contenido esperaba el
final (7,92 s) + el reposo. Ahora entra por reloj a los **6,5 s** — mismo
patrón que el háptico del flip — con el video corriendo detrás; los botones
siguen llegando con el reposo (el premio se lee antes de decidir).

## 3. La fila de personaje: sólo el multiplicador

«×2 · Nivel 1/19» eran dos contadores para el mismo dato. Quedó el
multiplicador solo; al tope (×20) el badge **"Al máximo" / "Maxed out"** que
ya existía cuenta el final. Deshace el pedido del 2026-08-19 (el contador en
la línea) — los dos tests que lo pineaban ahora pinean la inversa.

## 4. El botón de reencarnar arranca en lujo

El gate real de reencarnar es GANAR ≥1 ORO, y con la curva vigente
(divisor 1e10) eso llega por isla/luna. El pedido («al llegar a lujo») se
implementó SIN tocar la curva — que es contrato de pacing —: desde el piso
configurado (**`oro.prestigeTeaserFloorId` en `economy.json`**, data-driven
como manda la casa) la cápsula del HUD EXISTE en modo teaser:

- la segunda línea muestra el **porcentaje del camino al próximo ORO** en vez
  de la ganancia;
- la hoja cuenta **cuánto falta juntar** (`prestige.oro.next`, con la barra de
  la casa) y NO dibuja el confirmar — una acción que no corresponde no se
  apaga, no existe (doctrina de `ActionPill`);
- `PrestigePreview` ganó `coinsToNextOro`/`nextOroProgress`, calculados con la
  inversa de `oroTotal` (la misma cuenta que `giveEarningsForPrestigeTesting`).

Cero efecto en simulación: `PacingTests` corrió idéntico (el único rojo sigue
siendo el declarado). Tras reencarnar, la run vuelve al callejón y el teaser
se apaga hasta lujo — consistente solo.

## 5. La lección del primer ORO

Caso nuevo del director de lecciones (`oroUpgrades`, después de logros en el
orden): cuando un logro paga el primer ORO **y hay una permanente pagable**,
el globo lleva a Mejoras. La señal es `canAffordAnyOroUpgrade` (línea de ORO
pagable, costos crudos a 8 Hz) y no "ORO en el bolsillo": si el primer premio
no alcanza para la línea más barata, mandar a Mejoras violaría la regla de
oro. Y adentro, la **manito** de la casa late sobre la primera línea de ORO
pagable mientras ninguna esté subida — la lección dice a dónde, la mano dice
cuál, y elegida la primera se retira sola (mismo gesto que la fila
recomendada de FisuJobs).

## 6. El "lag" del video: medido, y la mejora de verdad

Diagnóstico con números, en orden:

1. **El master NO tiene frames congelados**: 5% de diffs~0 entre consecutivos,
   todos en la cola final quieta (a propósito). El movimiento es 24 fps real.
2. **El decode no es el cuello**: el mov entero decodifica a ~81 fps en
   software con la máquina cargada.
3. **A máquina quieta, el sim entrega los 24 fps clavados**: grabación del sim
   analizada por segundo — 24-26 frames DISTINTOS/s durante todo el cinemático.

**El "muy laggeado" fue la Mac saturada por las suites de verificación
corriendo mientras el dueño miraba el juego** — la segunda lección de
instrumento del día (la primera fue la cadencia de screenshots).

Y la mejora candidata se PROBÓ y se midió en las dos puntas: interpolar el
mov a 48 fps (`minterpolate` MCI sobre el VERDE, antes del keying — el alfa
no sobrevive al filtro). Visualmente impecable (sin fantasmas en confetti ni
giro, verificado a ojo frame a frame)… **pero el SIMULADOR lo reproduce PEOR
que a 24**: el software-VideoToolbox no sostiene HEVC-alfa a 48 y el tramo
del giro colapsa a ~5 fps efectivos (grabado y contado), contra los 24
clavados del mov sin interpolar. Mientras el juego se mire en el sim, 24 gana
— **la perilla quedó lista** (`CINEMATIC_OUTPUT_FPS` en el pipeline, con el
minterpolate salteado cuando vale 24): con device de verdad (F6), subirla a
48 es cambiar una constante y re-correr.

## Verificación del bloque

| qué | resultado |
|---|---|
| EconomyKit | **262/262** ✅ (OroConfig con campo nuevo opcional) |
| Unit sin Store (461: +2 nuevos) | **el único rojo es el DECLARADO de Pacing** |
| Suites tocadas (TutorialTips, PrestigePreview, UpgradeRowText, UpgradesMenu) | **27/27** ✅ |
| UI: PrestigeIndicator · Tutorial (6) · UpgradesMenu (2) · UpgradesFace | **todas verdes** ✅ |
| UI del cofre (ChestOpening 2 + circuito Regalos) | **3/3** ✅ + captura de la fila con el cofre 2D |
| Catálogo | +2 claves (`prestige.oro.next %@`, `tutorial.tip.oro`) por el script canónico de la trampa 29 (roundtrip verificado; el archivo no lleva newline final y la entrada vacía huérfana se serializa como Xcode) |
| mov | el binario embarcado es el MISMO ya verificado del `ter` (24 fps); el candidato a 48 se midió y se descartó para el sim (colapso a ~5 fps efectivos en el giro) |

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| El teaser NO mueve la curva del ORO | la curva es contrato de pacing; el pedido era el BOTÓN, y el botón con progreso enseña la mecánica sin regalar nada |
| La señal de la lección es "permanente pagable", no "primer ORO" | regla de oro: ninguna lección manda a una pantalla sin nada que hacer |
| Interpolar sobre el verde, antes del keying | minterpolate no preserva alfa, y el fondo plano estático mejora la estimación de movimiento |
| 48 y no 60 fps (la perilla) | 48 = 24×2: cada frame fuente sobrevive intacto y el sintetizado cae exactamente en el medio; a 60 la cadencia 24→60 repartiría los sintetizados de forma despareja (judder 3:2) |
| La perilla queda EN 24 | medido en el sim: a 48 el software-VT no sostiene HEVC-alfa y el giro colapsa a ~5 fps efectivos — peor que los 24 clavados; se re-evalúa con device (F6) |
