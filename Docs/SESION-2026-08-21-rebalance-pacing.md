# Sesión 2026-08-21 — Ganarlo al máximo pasa de 15,49 h a 24,00 h, y reencarnar deja de ser un trámite

Rama `fix/rebalance-pacing`, con `fix/atajo-tier-base` y `fix/premios-y-eventos`
integradas al cierre. Seis tareas: simulador → atajo → logros → eventos →
calibración → cierre.

El registro DURABLE de la calibración —cada corrida, cada A/B y cada descarte con
su número— es **`Docs/balance-log.md`**. Este documento es el porqué: qué se
decidió, qué se descartó y qué se diagnosticó mal antes de acertar.

---

## Qué se pidió

El dueño se quejó de tres cosas, en sus términos:

1. **el juego se gana demasiado rápido** — él lo ganó al máximo en unas 3 h;
2. **casi nunca conviene reencarnar** hasta estar muy avanzado, así que el
   prestigio no funciona como hito;
3. **los logros y los eventos pagan sin mirar el progreso**: un premio fijo es
   un lingote temprano y polvo tarde.

Objetivo, puesto por él: **maxear las siete líneas permanentes —que es lo que
desbloquea las skins doradas, o sea "ganarlo al máximo"— tiene que costar 20-30 h
ACTIVAS y llegarse con 8 reencarnaciones o menos.** Restricción del cierre,
textual: *"no introduzcas ningún bug al hacer el refactor"*.

---

## Las tres métricas, antes y después

Todas medidas con el MISMO bot (el corregido — ver abajo), contra el contenido
bundleado, `--max-days 90`:

| | antes | después |
|---|---:|---:|
| **maxear las siete (h ACTIVAS)** | 15,49 | **24,00** |
| **reencarnaciones para maxear** | 34 | **8** |
| **dios (h ACTIVAS)** | 32,0 | **26,59** |
| 1ª reencarnación (pared) | 0,10 h | 62,00 h |
| dios (pared) | 566,30 h | 470,26 h |

Cadencia de las 8 reencarnaciones, en horas activas: **3,7 · 8,0 · 12,7 · 16,4 ·
19,3 · 21,2 · 22,9 · 24,0**. Antes eran 34 y la primera caía a los seis minutos
de pared.

⚠️ **El "antes" de esta tabla no es el número que el prompt citaba.** El prompt
partía de 191 h activas hasta dios, y ese número quedó **derogado**: salía de un
bot que no compraba mejoras permanentes y tapeaba 3 veces por segundo. La línea
de base real contra la economía sin tocar es la columna izquierda.

Y una forma que el dueño pidió y que ahora está pineada: **dios queda DESPUÉS de
las skins doradas** (26,59 h contra 24,00), o sea maxear sigue siendo una meta y
no un trámite del final.

---

## La causa raíz, después de corregirla dos veces

La divergencia que había que cerrar es "los costos están anclados a una constante
y los ingresos pasan por un multiplicador sin techo": entrar a un piso costaba
**0,0 s de income** del cuarto piso en adelante, o sea progresar era gratis.

**Son DOS knobs con dos efectos distintos, y la primera versión del diagnóstico
los fundió en uno solo:**

- **La curva de ORO** (`divisor` 3e6 → 3e11 → 3e12, `exponent` 0,45 → 0,25) es la
  que **cierra la divergencia**. Acota la escala del multiplicador global, y con
  eso entrar a un piso vuelve a costar segundos de income: la serie
  `0,0 s → 720 s`. **La produce la curva de ORO, no `defaultCostGrowth`.**
- **`hire.defaultCostGrowth`** (1,2 → 1,06) hace otra cosa: decide **si la torre
  es escalable**. Con el 20 % por compra y el ORO ya escaso, el pico son 70
  compras y la siguiente cuesta 384 s de income: **el bot se traba en el tier 11
  y la partida NO SE PUEDE TERMINAR**. Con el 6 %, la misma economía se juega
  entera.

La corrección salió de re-medir **un knob por vez con el mismo tap en las dos
columnas**. La primera versión había movido dos cosas a la vez y le atribuyó al
growth un efecto que era del ORO.

---

## Las decisiones del dueño

### 1. `hire.defaultCostGrowth` de 1,2 a 1,06 — enmienda a la regla de precios

La regla del 2026-08-04 dice que contratar cuesta **600 veces lo que rinde un
click de ese personaje ahí**, y que cada compra sube la curva un 20 %. El dueño
aprobó bajar ese 20 % a **6 %**.

Lo que **no** cambia: el primer Fisura sigue costando 25 y
`defaultCostMultiplier` sigue en 600. **Cambia sólo la PENDIENTE**: el segundo
Fisura pasa de 30 a 26,5.

### 2. La salida (a) para la otra mitad de la regla

`tapFloorMultiplierExponent: 0` le sacó al TAP el multiplicador de piso, pero el
PRECIO lo seguía llevando crudo. Las dos puntas estaban atadas por casualidad, no
por construcción, y con ellas sueltas contratar el tier base del reino divino
pasó de 600 clicks a **600 × 620 = 372.000** sin que nada hiciera ruido.

Las tres salidas se corrieron enteras:

| | maxear | reenc | dios (activo) | la regla |
|---|---:|---:|---:|---|
| **(a)** el precio usa `tapFloorMultiplier` + `oro.divisor` 3e12 | **24,00 h** ✅ | **8** ✅ | **26,59 h** ✅ | **vale literal** |
| (b) devolverle el multiplicador al tap | 15,26 h ❌ | 9 ❌ | 20,32 h | vale como siempre |
| (c) dejarlo y re-enunciar la regla | 25,33 h ✅ | 8 ✅ | 30,33 h ✅ | **cambia de significado** |

**El dueño eligió (a).** Costo medido: 1,3 h de largo (25,33 → 24,00). A cambio,
`hireCost` y `applyTap` llaman a la MISMA función y no a dos expresiones
equivalentes: si mañana el exponente del tap cambia, el precio lo sigue solo.

### 3. Los doce logros de ORO fijo se re-escalan

Sumaban **620 ORO** contra los **193** que cuesta maxear las siete líneas:
juntando logros se ganaba el juego **3,2 veces**. El dueño pidió montos **fijos**
—más legibles en la ficha del logro que un porcentaje— para que los logros
**aporten** el camino en vez de reemplazarlo: 15-20 %.

Regla del re-escalado, para que el próximo logro de ORO tenga de dónde salir: **el
monto viejo dividido 20, redondeado para arriba, con piso en 1**. Conserva el
orden entero del catálogo y ninguno pasa a pagar cero.

**Total nuevo: 33 ORO, el 17,1 % de los 193.**

---

## La queja 2, contestada con un barrido: ¿conviene reencarnar temprano?

El criterio de aceptación del prompt (§4.2) pide medirlo, no opinarlo: si el
óptimo sigue siendo "reencarnar recién cuando no podés avanzar más", el arreglo
no funcionó. Barrido con `--prestige-threshold N` sobre el árbol FINAL
(`--max-days 3000`, la tabla completa en `balance-log.md`):

| política | maxear / reencarnaciones |
|---|---|
| **×1 (duplicar — el default)** | **24,00 h / 8** |
| ×8 | 15,29 h / 4 |
| ×1000 (contra la pared) | **no maxea antes de dios** (1 reenc · dios a 230,13 h) |

Antes de la rama, esperar contra la pared costaba **864,97 h**. Ahora esa
política ni siquiera llega a maxear dentro de la run: dios aparece primero.
Guardarse las reencarnaciones dejó de ser lo óptimo, que era exactamente lo que
había que arreglar.

⚠️ Dos cosas que hay que leer con la tabla. **El umbral no mueve la PRIMERA
reencarnación** —el múltiplo es sobre el ORO histórico, que arranca en cero, así
que `N × 0 = 0` para cualquier N y la primera cae siempre a las 3,67 h activas—,
y **"no maxea antes de dios" es literal**: la simulación corta cuando el bot llega
a dios, así que la fila dice que dios llega primero, no que maxear sea imposible.

---

## Lo que se descartó, con su número

Ninguno de estos se re-litiga sin traer un número mejor.

- **Anclar los costos al multiplicador (`M^0,8`)**, "el arreglo estándar de los
  idle". En esta torre la profundidad se COMPRA con el multiplicador, así que
  aplanarlo la achica: con k = 0,8 el bot se traba en **tier 12** y dios queda
  inalcanzable. La torre deja de ser escalable.
- **Aplanar sólo el ORO**, dejando la relación costo/ingreso: pasa el titular
  (29,67 h) pero deja **9 reencarnaciones**, dios a **915 h** y el hire del cuarto
  piso otra vez en **0,0 s** de income. Arregla el número que se mira y no el que
  duele.
- **La salida (b)**, devolverle al tap el multiplicador de piso: **15,26 h y 9
  reencarnaciones**, o sea no cumple ninguno de los dos objetivos.
- **Un `hireCostGrowth` por piso**: no hizo falta. El 6 % es global y
  `floorHireOverridesMatchTunedValues` pinea que nadie lo overridee — un override
  por piso sería drift, no tuning.
- **Unificar `cheapestAffordableUpgrade`** (filtra por el precio entero que la app
  cobra y ordena por el `Double` crudo). Medido: **no mueve ninguna de las cuatro
  métricas**, pero SÍ mueve la conducta del bot (`lifetimeEarnings` final 2,440e26
  → 2,349e26). Es un cambio de comportamiento y le corresponde su propio test, no
  un arreglo de paso en la tarea de cierre. Queda declarado en el código.

---

## Los diagnósticos ERRADOS (valen tanto como el acertado)

Cada uno costó una ronda entera y ninguno se deduce del código.

### 1. La evidencia que no medía su propio knob

Se defendió el `defaultCostGrowth` con la serie `floorUnlockHireSeconds` — lo que
cuesta entrar a cada piso. **Esa serie NO PUEDE ver el growth**: un piso se abre
**mergeando**, no comprando, así que el contador de compras de su tier base vale
0 al abrirlo y `growth^0 = 1`. La discusión sobre el compounding se estuvo dando
con una métrica ciega al compounding.

El arreglo fue instrumental: `floorUnlockPeakHire{Type,Purchases,Seconds}` publica
el tipo MÁS comprado de la run, su contador y lo que cuesta el próximo. Ahí
aparece el número real con el que hay que discutir la curva (**785 compras del
mismo tipo** en el árbol de hoy; 870 en el A/B pre-(a) de la bitácora), en vez de
uno supuesto.

### 2. El `blanqueo` que el plan describía al revés

El plan de la tarea de eventos decía "el blanqueo regala 2 personajes, bajarlo a
1". **`blanqueo.magnitude` no es una cantidad de personajes: es un OFFSET DE
TIER** — el evento regala UNO solo, de `maxTierReached − magnitude`. Aplicado al
pie de la letra, el plan lo habría hecho **más generoso**, que es lo contrario de
lo que la tarea venía a hacer. Se detectó leyendo `EventManager.apply` antes de
tocar el JSON, y quedó pineado en `ContentSystemsTests` con el comentario que lo
dice.

### 3. La migración que no cubría su propio caso

`SaveMigrator.rescaleUpgradeLevelsForRebalance` estaba probada **como función** y
no **como parte de la migración**: el fixture v3 traía `tap: 1`, que es **punto
fijo** del reescalado (1/20 × 10 = 0,5 → 1), así que borrar la llamada de
`migrateV3toV4` dejaba la suite entera verde. Un test verde que no cablea nada.

Y su comentario afirmaba idempotencia sobre el camino más peligroso de la rama:
la función **no es idempotente**, `crit 25 → 10 → 4 → 2 → 1 → 0`. Lo que la hace
segura es el cableado —UN solo call site y `migrate` despachando por versión—, no
la función.

### 4. Los tests que cambiaron de significado y quedaron verdes

Es la clase de bug que esta rama produjo tres veces, y vale nombrarla:

- `hirePricesFollowTheOwnersRule` **replicaba la fórmula VIEJA del click**, así
  que cuando el precio y el tap se separaron siguió verde. Ahora mide **en
  clicks**, con el mismo `tapFloorMultiplier` que cobra `applyTap`.
- `precioEscalaConElIncomeDelPiso` (EconomyKit) y el drill de extensibilidad
  pineaban que el precio lleva el `incomeMultiplier` CRUDO: una propiedad que el
  juego embarcado **ya no tiene**, verde sólo porque sus fixtures dejan el
  exponente en 1. El primero corre ahora en las dos configuraciones.
- `theOfferFallsBackToWhatTheCoinsActuallyCover` daba 9.000.000 "un peso menos que
  el Fast Food", y con los precios nuevos ese literal **pasó a alcanzar** para el
  tier 8: medía lo contrario de lo que dice su nombre. El corte se deriva de la
  config.

---

## El cierre: integrar tres ramas con un conflicto SEMÁNTICO

`FisuEvolutionTests/BestHireTests.swift` lo reescribieron dos ramas por razones
distintas y **las dos tenían razón**:

- `fix/atajo-tier-base` cambió **QUÉ se ofrece**: el atajo del HUD vende sólo el
  **tier base** de cada piso, porque venderte el tier más alto que la plata
  alcanza te saltea el merge, que es el juego. Cuatro tests cambiaron de
  significado y conservaron su escenario a propósito (los Senior de corporativo
  siguen estando pagados y contratables: es lo que prueba que lo que queda afuera
  del atajo no está simplemente fuera de alcance).
- El rebalance cambió **CUÁNTO cuesta**: el precio dejó de llevar el
  `incomeMultiplier` crudo y el growth bajó a 1,06.

**La resolución combina las dos**: la semántica nueva del atajo con los montos
re-derivados a mano contra `economy.json` (Oficinista **2.266.811,99** · Mantero
**36.879,36** · Senior **290.206.483,29**), y el corte de "un peso menos"
derivado de la config en vez de escrito.

---

## Lo que quedó declarado en vez de tapado

- **Un save v4 ANTERIOR al rebalance con `crit` entre 10 y 24** se lleva las skins
  doradas: el `>=` de `awardEligibleMilestoneSkins` lo cuenta como tope.
  Distinguirlo pide un bump de schema a v5 y las skins son cosméticas.
- **El redondeo de la migración no es neutro en los bordes**: regala hasta un
  nivel arriba (`income`/`tap` 19 → 10) y destruye el último abajo (`crit` 1 → 0).
- **Cruzar de piso es ahora el salto más BARATO** (0,48× contra 5,04× adentro del
  piso): el tier base de lujo sale 139,3 M y el tope de corporativo 290,2 M. No es
  explotable —un piso se abre mergeando— pero `TypeHireQuoteTests` documentaba lo
  contrario.
- **Quedan dos idiomas de cofre**: los logros cotizan producción (segundos de tu
  torre) y el Asado, el diario, los packs y el premio de carrera siguen en
  `passiveUnlockCost × factor`. Ocho call sites.
- **El arranque de los premios bajó 8×**: `ach_merges_1` pasó de 120 a 15 monedas
  en el segundo cero.

---

## Cómo se corre

La calibración:

```bash
cd Tools/pacing-sim && swift run -c release pacing-sim \
  --economy ../../FisuEvolution/Resources/Data/economy.json \
  --tiers ../../FisuEvolution/Resources/Data/tiers.json \
  --max-days 90 [--csv salida.csv] [--prestige-threshold X]
```

Sin `--upgrades` busca `upgrades.json` solo y el bot compra las siete líneas. Para
la corrida "sin mejoras" hay que apuntarle a un catálogo **vacío**
(`{"schemaVersion": 1, "upgrades": []}`): omitir la flag no alcanza.

`--prestige-threshold N` cambia la política de reencarnación (1 = duplicar el ORO
histórico, la conducta de siempre). Sirve para contestar con un número la pregunta
del dueño sobre si reencarnar temprano conviene.

---

## Cómo terminó

**EconomyKit 230 · unit 401 · UI 46, sin un solo `-skip-testing:`**, cero
warnings de compilador, simulador propio por UDID y `-parallel-testing-enabled NO`.
Las tres corridas salieron verdes a la primera; ningún test de UI necesitó
reintento aislado.

Las cuatro bandas de `PacingTests` estaban **4/4 en rojo** y quedaron re-pineadas
a ±30 % de lo medido, con la corrida escrita en el docstring. Y se le sumaron **los
dos asserts del objetivo del dueño** —maxear en 20-30 h activas, ≤8
reencarnaciones—, que a diferencia de las bandas **no se re-pinean**: si se ponen
en rojo, el juego dejó de cumplir lo que se pidió.
