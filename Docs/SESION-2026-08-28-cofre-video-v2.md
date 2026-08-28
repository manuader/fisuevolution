# Sesión 2026-08-28 (bis) — El velo del encuadre, y el master que se desvanece

> Pedido del dueño, textual: «la animacion todavia no se ve correctamente.
> reemplace el video anterior por un nuevo video […] utiliza esa animacion.
> la idea es que el cofre se abra y luego desaparezca de forma seamless y
> completamente integrado con el juego. como podes ver en la imagen se ven los
> assets superpuestos. y el cofre cortado. debe verse perfecto.» Y a mitad de
> la verificación, con captura del velo en mano: «por alguna razon cuando la
> carta sale del cofre deja de verse translucido […] se tiene que ver
> traslucido y completamente integrado. determina a partir de que frame
> sucede y corregilo».
>
> Continuación directa de `Docs/SESION-2026-08-28-cofre-animado.md` (v1):
> misma arquitectura, master nuevo, y el bug de compositing que la v1 tenía
> sin saberlo.

## El master nuevo: por fin un sprite de verdad

El video anterior horneaba una viñeta oscura y un piso alrededor del cofre;
keyeado seguía siendo un RECTÁNGULO con clima propio, y de ahí las costuras,
el feather y el scrim "de continuación". El reemplazo del dueño está diseñado
para la integración: **verde plano de punta a punta**, el cofre estalla con
confetti, suelta la carta girando, **se desvanece solo** (~f114–f126) y el
final es el marco vacío quieto y centrado. La desaparición seamless que pidió
es del arte — no hay fade nuestro.

Recalibración medida (misma estructura, números nuevos):

| Qué | v1 (viejo) | v2 (vigente) |
|---|---|---|
| Croma en el stream | 0x0BB427 | **0x10A12A** (mismo método limited-range; `0.11:0.04` sigue) |
| `chestRect` | 431,257,407,363 | **430,257,409,365** (el generador mantuvo el encuadre) |
| Segmentos | idle [0,0] · A [7,26] · B [33,47] | idle [0,0] · **A [4,30]** (squash+salto+asentado) · **B [31,47]** |
| Crops | 860×560 / 1160×620 | **912×504 / 1144×424** — percentil 99,7 de masa ∪ bbox del cofre frame a frame (el salto de A llega a y=136 y el percentil solo lo cortaba) |
| Cinemático | f48–239 | **f48–239 (igual)** — la tapa cruje en f51, flip ~f198 (6,25 s: el háptico a 6,2 s sigue) |
| `parchmentRect` | 489,143,302,424 | **490,143,302,418** — beige MACIZO (umbral 60 px/fila): el bbox pelado se estira con los biseles claros del borde y descentra el contenido |
| Peso | 36 PNG 1,4 MB + mov 3,0 MB | **45 PNG 1.573 KB + mov 2.633 KB + still 18 KB** |

`ui_chest_closed` se regeneró del f0 nuevo (cofre violeta+dorado) con la
misma ocupación del 84,4 % — y el recorte pasó a **componente conexa**: el
video trae destellos ambiente sueltos (uno en x~1150 ya en f0) que inflaban
el bbox global y hubieran dejado el cofre a media escala en Regalos.

## El velo: el bug de compositing que la v1 tenía puesto

**Síntoma** (captura del dueño y de los smokes): desde que arranca el
cinemático, el rectángulo 1280×720 del video se delata como una veladura
CLARA sobre el juego, cortada seca en el encuadre. Medido restando capturas
(reposo − idle, columnas de margen): **+20 a +27 de luminancia** dentro del
encuadre, bordes en pantalla en 124 pt y 605 pt; afuera, solo el scrim suave.

**Causa raíz, con la aritmética que la clava**: `AVPlayerLayer` composita el
HEVC-alfa como **PREMULTIPLICADO** — `out = rgb + fondo×(1−α)` — y el mov
llevaba RGB sin premultiplicar: `chromakey` setea el alfa pero **no toca el
RGB**, así que las zonas con α=0 conservan el verde pasado por `despill`
(~RGB 16,29,42 → L≈26). Ese color se SUMABA al juego entero: velo de +26,
que es exactamente lo medido. **Empieza en el frame 48 del video** — el
primer frame del mov, el instante en que el `AVPlayerLayer` reemplaza a los
PNG (que van por SwiftUI, alfa straight, y por eso los tres toques se veían
bien). Se nota fuerte "cuando la carta sale" porque para entonces el ojo
recorre el encuadre completo.

**El fix es una palabra**: `premultiply`. En `encode_cinematic`, después del
`alphamerge` (para multiplicar por el alfa YA emplumado):
`alphamerge,format=gbrap,premultiply=inplace=1,format=bgra` — en `gbrap`
porque el filtro no toma rgba empaquetado. Verificado en el mov re-encodeado:
RGB medio en zonas α<2 pasó de ~26 a **0,03–0,13**, y la simulación de la
composición premultiplicada sobre gris 120 devuelve el fondo en 120,00.
Re-medido en capturas frescas: el perfil quedó suave (la forma del scrim) y
**sin escalón** en los bordes del encuadre.

**Relectura histórica que importa**: el video viejo tenía EL MISMO BUG. Su
fondo post-key era la viñeta oscura horneada, así que el término aditivo era
oscuro y se leyó como "viñeta que se corta en el borde" — el feather de 28 px
y el scrim de continuación (v1) fueron parches al síntoma. El feather queda
(desvanece el confetti que cruza el encuadre), y el scrim queda como lo que
siempre debió ser: **el foco de la casa**, no la continuación de nada.

## Lo único nuevo del runtime: el PNG de respaldo se jubila

En v1 el frame PNG quieto vivía montado debajo del video durante todo el
tramo (tapaba huecos del arranque del decoder) y era gratis: el cofre del
video nunca se movía de encima. Con el cofre desvaneciéndose, ese PNG lo
**resucitaría por detrás**. Ahora se retira (`stageRetired`) a los **0,6 s**
de video corrido — ~14 frames rendidos, y el cofre del video sigue opaco por
2 s más: margen en las dos puntas — y en todos los caminos al reposo (el
still de Reduce Motion ya no trae cofre). El cuarto de segundo de PNG bajo
el video sigue cumpliendo su función original en el arranque.

Sin más cambios de coreografía: tres toques, auto-avance 1,2 s, zoom 1→1,3
anclado al pergamino, háptico del flip a 6,2 s, `--uitest-chest-manual` a 4×.

## Verificación

| qué | dónde | resultado |
|---|---|---|
| Pipeline Python (12) | `unittest` | **12/12** ✅ (dos corridas: tras recalibrar y tras el premultiply) |
| Unit sin Store (458) | sim iOS 26.5 propio (`cofre-v2-26`, borrado al cierre) | **el ÚNICO rojo es el declarado** (`PacingTests`, 9 vs ≤8 — contrato, no se toca) |
| Unit del cofre (11) | mismo sim | **11/11** ✅ sobre el build final |
| `ChestOpeningUITests` (2) + circuito de Regalos | mismo sim | **3/3** ✅ sobre el build final |
| `BonusHUDUITests.testActivatingABoost…` | mismo sim | 🔶 rojo en la corrida de suite (primer test tras instalación fresca, 61 s), **verde aislado (35 s)** — no toca el cofre; la firma de carga/primer arranque ya documentada |
| Velo | resta de capturas | **muerto**: perfil suave sin escalón (antes +20..+27 con bordes en 124/605 pt) |
| Smoke visual (16 capturas cronometradas) | sim 26.5 | idle limpio · estallido con el callejón visible a través · **cofre desaparecido sin fantasma del PNG** · flip · marco con retrato+cinta+nombre+subtítulo centrados y botones sin rozar ✅ |

Store no se corrió: cero archivos de Store en el diff y el aviso de entorno
del general (§6) sigue vigente de la mañana.

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| Premultiplicar en el ENCODE y no tocar el runtime | es la convención que asume el compositor; arregla el velo y de paso los bordes suaves (un glow sin premultiplicar suma de más en sus rampas) |
| `parchmentRect` por beige macizo y no por bbox de claros | los biseles del borde dorado pasan el filtro de "claro" y estiran el bbox 40 px hacia abajo — el contenido quedaba ~2 pt corrido y el rect mentía |
| El PNG de respaldo se retira por reloj (0,6 s) y no por observer | mismo criterio que el háptico del flip: `.task(id:)` ya es cancelable y el margen es de segundos, no de frames |
| Los destellos ambiente del video se cortan en los crops PNG | masa <0,3 % (bajo el umbral del 0,7 %); son chispas sueltas lejos del cofre, y el crop que las incluyera pagaría lienzo entero |
| El master pisó a `chest-animation.mp4` (mismo nombre) | es EL master del pipeline; el anterior queda en git — mismo criterio que los originales de arte |
