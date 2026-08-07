# SESIÓN 2026-08-06 — las 16 correcciones del playtest

> **Para el agente que continúa.** `Docs/HANDOFF.md` ya está actualizado con el
> estado y las 14 trampas. Este documento es lo que el HANDOFF no puede contener:
> qué quedó abierto, y el *porqué* de las decisiones, que se pierde si no se escribe.

**~110 commits, todos pusheados.** El hermano del dueño terminó el juego y mandó
16 correcciones. **Quince están cerradas**; la que falta (audio) está bloqueada
por falta de herramienta, no por falta de trabajo.

---

## 1. Antes de tocar nada

### Los dos tests rojos que NO son tuyos

| Test | Por qué | Qué hacer |
|---|---|---|
| `AscentRenderingUITests` | Frágil por la trampa 3: arrastra por coordenadas fijas y los personajes deambulan, así que el merge no engancha | Salteálo. Arreglarlo es agregarle reintentos |
| `EconomyLoopUITests` · `StoreManagerTests.refundRevokesEntitlement` | Flakies **sensibles a carga**: pasan aislados y fallan con la máquina ocupada | No los persigas |

⚠️ **Tres agentes quemaron su cuota persiguiendo el primero**, uno lo diagnosticó
como "el simulador no arranca" y se puso a borrar dispositivos. No es el entorno.

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test \
  -skip-testing:FisuEvolutionUITests/AscentRenderingUITests -parallel-testing-enabled NO
```

**Línea de base: EconomyKit 150 · app 156 · UI 17 · pipeline 25.**
`PacingTests` ya está repineado a la torre nueva y **entra en los 156**.

### El worktree ya nace bien

`origin/main` está al día (se pusheó al cierre de la sesión). Igual, el chequeo
cuesta una línea y hoy hizo perder tiempo a seis frentes:

```bash
git rev-list --count origin/main..main   # si no da 0: git merge --ff-only main
```

---

## 2. El estado del juego

**La torre**: 37 tiers en 10 pisos. **El arte**: completo — 8 personajes nuevos,
43 caras, 2 skins pagas. **El pacing**, recién rebalanceado:

| Piso | Pared | Ratio |
|---|---|---|
| urban | 0,04 h | — |
| corporate | 14,00 h | ×24,6 |
| luxury | 110,05 h | ×6,4 |
| island | 134,12 h | ×1,22 |
| moon | 158,14 h | ×1,17 |
| mars | 182,28 h | ×1,16 |
| solar | 230,06 h | ×1,23 |
| galaxy | 312,04 h | ×1,33 |
| god_realm | **345,28 h** | ×1,13 |

Sin muros y sin tramos de ×1,00, que era el objetivo.

⚠️ **Queda una decisión del dueño abierta: 345 h contra las 196 h de la torre
vieja.** El camino medido de vuelta a ~196 h es abrir el gate del urbano y bajarle
el `hireCostMultiplier` a 50, pero eso mueve el precipicio a luxury (×39) **y
re-litiga la decisión 2 del HANDOFF §5**. Por eso se frenó ahí en vez de hacerlo.

---

## 3. Lo que la Ola 3 dejó enseñado (y lo que corrigió)

El muro estaba en **268 h antes de corporativo, con un salto de ×368**. Se cerró
a 14 h. Pero lo que vale para el futuro no es el número, son las tres cosas que
la medición **desmintió**:

**1. El `incomeMultiplier` NO causaba el colapso de ×1,00.** Yo lo había
diagnosticado así en `balance-log` y estaba equivocado. Está medido: barrer la
curva de ×1,5 a ×3 por piso —compuesto, ~3.000×— deja el colapso intacto. Mueve
el largo total, no la forma.

**2. La causa real es la potencia del barrido de reencarnación.** El patrón
"un salto grande y después dos o tres pisos casi gratis" es el jugador barriendo
pisos enteros con el multiplicador global que trae de la reencarnación anterior.
Por eso lo arregla el ORO y no el income. Y por eso **`globalMultiplierPerOro` es
el knob más peligroso de los tres**: a 0,25 el colapso vuelve entero.

**3. El 0,40 que pedía RF-07 no servía**: da 1094 h con luxury a 782 h. El spec
estimó ese número antes de que existiera la torre de 37 tiers. El valor calibrado
es **0,45**.

Y un knob resultó **inerte**: bajar el `hireCostMultiplier` del urbano de 600 a 50
con el gate cerrado deja corporativo en 268,00 h, **idéntico al centavo**. No se
puede ponerle precio a algo que el gate prohíbe comprar.

### La regla de oro de esta economía

**La intuición falla, y hay dos antecedentes medidos que lo prueban**: subir
`hire.defaultCostMultiplier` de 300 a 600 **acortó** el juego de 264 h a 196 h, y
el knob de arriba resultó inerte. **Ningún knob se mueve sin correr el simulador,
y cada corrida se anota — incluidas las descartadas.** Las 17 de la Ola 3 están
en `balance-log`.

⚠️ **Una trampa de método que costó cuatro corridas**: se escribió el override
como `hireCostMultiplierOverride`, que es el nombre en Swift y no la clave del
JSON. **El decoder ignora claves desconocidas en silencio**, así que las cuatro
usaron el default y salieron **byte-idénticas** — lo que parecía prueba limpia de
que el knob era inerte. La señal fue que un cambio de ×40 diera dígitos iguales.

```bash
swift run --package-path Tools/pacing-sim pacing-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json
```

---

## 4. Lo que queda, por orden de valor

| # | Qué | Bloqueado por |
|---|---|---|
| 1 | **Que el dueño lo juegue** | Nada |
| 2 | Decidir sobre las 345 h (§2) | El dueño |
| 3 | **Packs de monedas y de ORO** (RF-02b, parcial) | Nada: el rebalance ya cerró |
| 4 | `bg_galaxy`, regeneración opcional | Una corrida del dueño (§6) |
| 5 | **Música y efectos** (RF-14) | **No hay fuente de audio** (§5) |
| 6 | Alta en App Store Connect (RF-02c) | La cuenta de Apple Developer |

⚠️ **El punto 1 no es una formalidad.** Los bugs más caros de la sesión
aparecieron **mirando la pantalla**, no corriendo tests: la manito del tutorial
que **nunca latía** (el `@State` cambiaba antes de que la vista existiera), el
globo que tapaba justo los controles que el paso siguiente ilumina, las filas de
"perdés/conservás" truncadas encima de los números, y un `upgrades.flavor.income`
impreso literal en pantalla. **Nadie vio el layout de las seis pantallas juntas.**

---

## 5. RF-14 (audio) está BLOQUEADO, no pendiente

No hay con qué generarlo. Verificado: no existe MCP de ElevenLabs en la sesión, y
el único servidor de audio disponible **genera sólo voz** — su contrato prohíbe
explícitamente usar sus modelos de música y efectos para audio suelto.

Se desbloquea conectando un MCP con música/SFX standalone, o consiguiendo audio
CC0 a mano (el plan original del proyecto; el comentario del gate sigue en
`AudioManager`). **Integrarlo es cero Swift**: el contrato son los nombres de archivo.

⚠️ **Su criterio de aceptación es humano.** Se puede medir nivel, duración y
costura del loop; el timbre y el "cansa en la décima vuelta" los juzga una persona
escuchando. Está medido que los archivos actuales están **técnicamente bien** — el
problema es estético, así que más síntesis por código no lo resuelve.

---

## 6. Los gates humanos

**La corrida de arte va desde Terminal.app.** El runner usa `osascript` para
mandar teclas y el shell del agente **no tiene el permiso de Accesibilidad**. Está
probado con precisión: el lanzador de Chrome **sí** anda desde el agente, el
puerto de debug responde, la sesión de Gemini sigue viva y la cola se arma bien —
**lo único que falla es tipear**. Falla en el asset 1 sin consumir cuota, así que
intentarlo es barato; sirve igual para preparar todo.

Queda pendiente sólo `bg_galaxy`:

```bash
cd Tools/asset-pipeline && python3 -c "import json;p='../../FisuEvolution/Resources/Data/assets_manifest.json';m=json.load(open(p));m['backgrounds'].pop('galaxy',None);open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+chr(10))" && .venv/bin/python scripts/gemini_selenium_runner.py --process --ref-threshold 5
```

⚠️ **Con el manifest así el juego NO arranca** — el fallback a placeholder no
cubre los fondos. La ventana dura lo que la generación: **no buildees ni testees
adentro**. `--process` repone la entrada; si sale mal, `git checkout
FisuEvolution/Resources/` restaura todo, y el fondo viejo está archivado en
`dropbox/procesadas/bg_galaxy.ORIGINAL-julio.png`. **Si el nuevo sale peor, no se
integra**: es la salida de escape que el dueño aprobó junto con el prompt.

---

## 7. Higiene, aprendida a los golpes

- **Un simulador por frente, Y BORRARLO AL TERMINAR.** Compartir el device
  corrompe corridas —aparecen tests de otro worktree en tu log— y no cerrarlos
  dejó la máquina en **736 procesos y load average 861**, con builds que pasaron
  de 7 minutos a no terminar nunca.
- **Nada de `pkill -f xcodebuild`**: ese patrón mata las corridas de los otros
  frentes. Pasó.
- **El scratchpad es compartido**: prefijá tus archivos.
- **Corré el suite dos veces antes de cantar victoria.** Dos flakies distintos
  aparecieron sólo así, y uno lo había introducido el propio frente.
- **Verificá cada test al revés** —rompé a propósito lo que prueba y mirá que
  falle— antes de creerle. Así se encontró el bug de la manito.

Las 14 trampas están en `HANDOFF.md` §7. Las cinco nuevas de hoy:

| # | Qué |
|---|---|
| 5-bis | Interpolar la **clave** de localización no busca esa clave: `LocalizedStringKey("x.\(id)")` arma `x.%@` y dibuja el formato |
| 6 | **El runner de UI corre la app en inglés**: un test que asserta texto en español pasa por la razón equivocada |
| 8 | `SKTexture.preload` necesita handler `@Sendable` o mata el proceso — **y el test seguía verde con la app crasheada** |
| 9 | `anchorPreference` **pisa** el valor del subárbol; va `transformAnchorPreference` |
| 11 | Dónde exactamente falla el runner de arte desde un agente |

---

## 8. Decisiones que NO se re-litigan

Están en `HANDOFF.md` §5 con su justificación. Las cinco de esta sesión:

1. **El fondo retirado es `cosmic`** (el del río de gemas), no `mars`.
2. **Sale `Personal de Kiosco`** y El Mantero ocupa su lugar.
3. **Magnate Petrolero queda en la luna** — bajarlo ensuciaba tres calces para
   arreglar uno.
4. **Las 4 recompensas de carrera**, de tipo distinto entre sí a propósito.
5. **Los 8 nombres de skin** de los personajes nuevos.

Y de las anteriores, la que más se rozó hoy: **el gate es de UN piso**. La Ola 3
cambió su *cobertura* (el urbano ahora está exento) pero no su *profundidad*, que
es lo que está medido que rompe el juego.

---

## 9. Mapa de documentos

| Doc | Qué |
|---|---|
| `superpowers/specs/2026-08-06-correcciones-de-playtest-design.md` | **Los 16 pedidos como RF-01…RF-16**, con criterio de aceptación |
| `superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md` | Los 8 personajes, la baja de kiosco, el mapeo de 10 pisos |
| `superpowers/plans/2026-08-06-ola-{0,1,2}-*.md` | Los tres planes de ejecución, con el reparto por frentes |
| **`balance-log.md`** | **Las tres mediciones y las 17 corridas de la Ola 3. Es el activo más valioso del proyecto** |
