# Sesión 2026-08-23 (bis) — Las fusiones se cobran, y el barrido de la profundidad

> **Lo que se hizo**: el simulador dejó de regalar las fusiones, y con el
> instrumento corregido se barrió la profundidad de la compuerta (N = 6, 7, 8)
> con las cinco métricas.
>
> **Lo que NO se hizo, y por qué**: la compra en lote. Se empezó y se descartó a
> mitad —el dueño la objetó con tres razones correctas— y no quedó nada de eso en
> el árbol. Está contado en §4 para que nadie la vuelva a proponer sin leer la
> objeción.
>
> **La decisión que queda abierta es una sola y es del dueño**: si las 20-30 h se
> miden en el reloj del simulador o en el suyo. Con el factor de 3× medido, la
> respuesta cambia qué configuración es la correcta. §3.

Commit: `800755c`. Números: `Docs/balance-log.md`, "Cuarta ronda (bis)".
Corrida: `Docs/balance-run-t10-merges-cobrados.csv`.

---

## 1. Por qué el merge gratis era un sesgo y no una simplificación

Fusionar es el verbo central del juego: se arrastra o se toca dos veces, **una
acción por fusión**, y subir un tier de frontera pide `2^N − 1` de ellas. El
simulador las cobraba a cero, así que medía a un jugador que **compra con el dedo
y fusiona con la mente**.

No es una imprecisión pareja: sesga todo lo que cambie la **proporción entre
compras y fusiones**. La profundidad de la compuerta la cambia (más profundo =
más fusiones por compra), y cualquier idea de comprar de a varias también. O sea
que era exactamente el eje sobre el que se estaba calibrando.

Los dos costos de manipulación pasan a ser knobs con nombre —`hireSeconds` (era
un `+ 1` literal adentro del loop) y `mergeSeconds`—: un número que resultó ser
la mitad del tiempo activo de la partida no puede vivir escondido en un literal.

⚠️ **Detalle de implementación que importa**: el reloj avanza **fusión por
fusión**, no al final de la tanda. `doAllMerges` lleva el `elapsed` `inout` y
registra cada hito con el tiempo que le corresponde. Si se cobrara al final, una
cadena larga de merges aparecería como instantánea en la tabla de pisos, que es
justo de donde se lee el gradiente.

### Lo que movió, y la sorpresa

| | merge gratis | merge a 1 s |
|---|---:|---:|
| maxear las siete | 7,27 h | **6,67 h** |
| dios (activas) | 9,40 h | **8,97 h** |
| 1ª reencarnación (pared) | 4,28 h | **9,00 h** |
| fase fisura | 78,0 s | **96,0 s** |

**Las horas activas BAJARON**, que es lo contrario de lo que uno espera al
agregar un costo. El mecanismo: cobrar las fusiones quema presupuesto de SESIÓN
(20 min), así que el bot llega antes al final de cada una y parte del progreso se
paga con income **offline** — reloj de pared, no de dedo. Lo que sube es la
espera (la primera reencarnación se duplica) y el arranque, que es puro Fisura.

⚠️⚠️ **Acá se corta la comparación con todas las bandas anteriores de esta rama.**
Está dicho en el encabezado de `PacingTests` y en la bitácora, en vez de dejarlo
implícito: cualquier número previo se midió con el merge gratis.

---

## 2. El barrido de la profundidad: N=7 es el techo de lo jugable

| N | maxear | reenc | dios | peor paso | salto máx | sin reencarnar |
|---|---:|---:|---:|---:|---:|---:|
| **6 (embarcado)** | 6,67 h | 7 ✅ | 8,97 h | ×14,65 | 2,15 h | 2,97 h 🔴 |
| 7 | 186,33 h | 8 | 193,03 h | ×3.726 🔴 | 96,31 h 🔴 | — |
| **7 + callejón 1,02** | **13,33 h** | **8** ✅ | **21,21 h** | ×16,86 | 4,94 h | 7,41 h 🔴 |
| 8 | no termina | — | — | ×3.726 🔴 | — | — |
| 8 + callejón 1,02 | 77,33 h | 9 🔴 | 108,66 h | ×16,86 | 41,11 h 🔴 | **nunca llega** ✅ |

- **N=7 pelado no sirve, y el que lo arregla es el callejón.** El muro es el early
  game: hasta que la frontera llega a `N+2` lo único contratable es el Fisura, así
  que hay que mergear `2^(N+1)` de ellos contra `1,06^compras`. Bajarle la curva
  SÓLO al callejón (`hireCostGrowth` 1,02) lo destraba entero.
- **N=8 no es jugable.** Pelado la partida no se termina (maxTier 9 a los 400
  días); destrabado pide 9 reencarnaciones y mete saltos de 29 a 41 h activas
  entre dos hitos. Eso no es dificultad, es una pared con otro nombre.
- ⚠️ **La profundidad es lo único medido que da vuelta la trampa de reencarnar**,
  y el cruce cae entre 7 y 8: con N=6 y N=7 el que no reencarna llega ~3× más
  rápido; **con N=8 no llega nunca**. O sea que el contrato 5 y los contratos 2-3
  tiran para lados opuestos del MISMO dial, y eso es un hallazgo de diseño, no un
  problema de calibración.

---

## 3. La pregunta que hay que hacerle al dueño

El dueño hizo en **menos de 1 h** la partida que el bot tarda **2,97 h**: juega
**~3× más rápido**. Con ese factor:

| configuración | maxear (sim) | **maxear (dueño)** | dios (sim) | **dios (dueño)** |
|---|---:|---:|---:|---:|
| N=6 (hoy) | 6,67 h | **2,2 h** | 8,97 h | **3,0 h** |
| N=7 + callejón | 13,33 h | **4,4 h** | 21,21 h | **7,1 h** |
| N=8 + callejón 1,01 | 48,67 h | **16,2 h** | 87,97 h | **29,3 h** |
| N=8 + callejón 1,02 | 77,33 h | **25,8 h** | 108,66 h | **36,2 h** |

**Las 20-30 h, ¿son del reloj del simulador o del suyo?**

- **Del simulador**: nada jugable llega. El techo es 13,33 h, y pasar de ahí
  cuesta romper el ≤8 o meter saltos de 30-40 h.
- **Del suyo (÷3)**: N=8 + callejón 1,02 cae adentro de la banda (25,8 h), pero
  con 9 reencarnaciones y un salto de 13,7 h suyas entre dos hitos. El sano
  —N=7 + callejón— le da 4,4 h.

No es una decisión que pueda tomar una calibración: cambia qué configuración es
la correcta.

---

## 4. La compra en lote: se empezó, se descartó, no quedó nada

Se llegó a implementar y testear la fórmula del precio en lote —la suma
geométrica exacta `precio(n) × (gᵏ − 1)/(g − 1)`, con su guarda para `g == 1`, y
cinco tests en verde, incluido el que prueba que el lote cuesta **lo mismo** que
comprar de a una para todo `k` y todo `n`—. **Se revirtió entero** cuando el dueño
objetó la idea, y las tres objeciones son correctas:

1. **Sólo entran 10 por piso**, así que un ×100 no existe: el lote útil se topea
   en 10 y el selector prometería lo que no puede colocar.
2. **Comprar de a más hace el juego MÁS CORTO**, no más largo — saca acciones del
   reloj, que es lo único que hoy lo sostiene.
3. Por lo tanto **no sirve como palanca de duración**: el lote es UX, no pacing.

Queda anotado acá y no en el código porque en el código no quedó nada. Si vuelve
a proponerse, que sea como mejora de UX y con estas tres cosas ya contestadas.

---

## 5. Trampa que costó una corrida entera de UI (mía, y evitable)

Lancé `-only-testing:FisuEvolutionTests/PacingTests` **mientras la suite de UI
corría en el MISMO simulador**. Resultado: 31 de 48 tests con "la app no está
corriendo", `board.floor never appeared` y `kAXError -25218`. No es el código: es
el modo de falla que el general ya documenta ("dos agentes en paralelo no pueden
compartir el mismo device") y que yo reproduje solo, con dos `xcodebuild` míos.

**La regla, ampliada**: el device es de UNA corrida por vez, sea de quien sea el
segundo proceso — incluido vos mismo dos ventanas más allá. Si una suite de UI
empieza a fallar en masa con "la app no está corriendo", lo primero que hay que
mirar es `ps aux | grep xcodebuild`, antes que el diff.
