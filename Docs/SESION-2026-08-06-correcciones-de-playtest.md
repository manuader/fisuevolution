# SESIÓN 2026-08-06 — las 16 correcciones del playtest

> **Para el agente que continúa.** Leé primero `Docs/HANDOFF.md`, que ya está
> actualizado con todo lo de esta sesión. Este documento es lo que el HANDOFF no
> puede contener: qué quedó a medias, qué está corriendo ahora mismo, y las
> decisiones cuyo *porqué* se pierde si no se escribe.

**105 commits.** El hermano del dueño terminó el juego y mandó 16 correcciones.
**Quince están cerradas.**

---

## 1. Lo primero que tenés que hacer

### Comprobar que tu worktree no nació viejo

```bash
git rev-list --count origin/main..main
```

**Si no da 0, `git merge --ff-only main` antes de tocar nada.** Los worktrees de
agentes se crean desde `origin/main`, y este repo se commitea local y casi no se
pushea: hoy el remoto estaba **102 commits atrás**. Los seis frentes de la sesión
arrancaron sobre el árbol de cuatro días antes —sin el plan que tenían que leer,
sin el spec, con los JSON viejos— y cada uno perdió tiempo descubriéndolo.

**La solución de fondo es pushear.** Está pendiente de decisión del dueño: son
105 commits a su repo de GitHub y no se hace sin que lo pida.

### Saber qué está rojo y no es tuyo

| Test | Por qué | Qué hacer |
|---|---|---|
| `PacingTests` | Pineado a la torre de 30 tiers | **Lo repinea A4** (ver §3). Salteálo hasta entonces |
| `AscentRenderingUITests` | Frágil por la trampa 3 (drags por coordenadas fijas, sin reintentos) | Salteálo. Arreglarlo es agregarle reintentos |

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test \
  -skip-testing:FisuEvolutionTests/PacingTests \
  -skip-testing:FisuEvolutionUITests/AscentRenderingUITests \
  -parallel-testing-enabled NO
```

**Línea de base: EconomyKit 149 · app 151 · UI 17 · pipeline 25.**

---

## 2. Qué está corriendo AHORA

**Frente A4 — el rebalance.** Es el único trabajo en vuelo. Su rama es
`worktree-agent-a9a33627c8fce7adb`. Si terminó, mergeala y corré la suite; si no,
**no toques `economy.json`, `tiers.json` ni `TowerActions.canHire`**, que son suyos.

---

## 3. El problema abierto más grave del proyecto

**No es ninguno de los 16 pedidos. Es un muro de 268 horas.**

La medición está entera en `Docs/balance-log.md` (las tres últimas secciones).
Resumen:

| | Torre vieja (30 tiers) | Torre nueva (37) |
|---|---|---|
| Dios | 196 h | **436 h** |
| **Corporativo se abre a** | 0,07 h | **268 h** — salto de **×368** |

**El jugador pasa 268 horas en el piso urbano.** Sale de dos decisiones que se
tomaron por separado y nadie cruzó:

1. El **gate de contratación** exime sólo al callejón: hasta que corporativo no
   abre, lo único comprable es el tier más barato y todo lo demás hay que mergearlo.
2. El **remapeo empujó el primer tier de corporativo de 6 a 9**, lo que multiplica
   por ocho la profundidad de merge necesaria (2⁸ = 256 Fisuras contra 2⁵ = 32).

⚠️ **Y hay un segundo problema, más viejo y todavía sin resolver**: los últimos
cinco pisos se abren con ratio **×1,00**, casi simultáneamente. Está medido desde
antes del remapeo. **No lo arregla el exponente del ORO**: sale de que
`incomeMultiplier` crece ×2 por piso mientras las ganancias del jugador crecen
mucho más rápido.

### El orden importa y no es el del plan

El plan original decía "bajá el exponente del ORO de 0,50 a 0,40" (RF-07).
**Se invirtió a propósito**: el ORO es la palanca del *late game* y el muro está
antes de la primera reencarnación útil. Aplicar RF-07 sobre esto haría **más
largo** un arranque que ya es injugable. **Primero el muro, después el ORO, y los
dos medidos en una sola corrida.**

### La regla de oro de esta economía

**La intuición falla.** El antecedente está en `balance-log`: subir
`hire.defaultCostMultiplier` de 300 a 600 **acortó** el juego de 264 h a 196 h,
al revés de lo esperado, porque el bot dejó de hacer backfill y volcó esa plata a
reencarnar. **Ningún knob se mueve sin correr el simulador, y cada corrida se
anota — incluidas las descartadas.**

```bash
swift run --package-path Tools/pacing-sim pacing-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json
```

---

## 4. Lo que queda, por orden de valor

| # | Qué | Bloqueado por |
|---|---|---|
| 1 | **El rebalance** (§3) | A4, en vuelo |
| 2 | **Que el dueño lo juegue** | Nada. Cambiaron seis pantallas y el arte entero |
| 3 | **Packs de monedas y de ORO** (RF-02b, parcial) | El rebalance: cambia cuánto vale un ORO |
| 4 | `bg_galaxy`, regeneración opcional | Una corrida del dueño (§6) |
| 5 | **Música y efectos** (RF-14) | **No hay fuente de audio** (§5) |
| 6 | Alta de productos en App Store Connect (RF-02c) | La cuenta de Apple Developer |

⚠️ **El punto 2 no es una formalidad.** Los tres bugs más caros de la sesión
aparecieron **mirando la pantalla**, no corriendo tests: la manito del tutorial
que nunca latía, el globo que tapaba justo los controles que el paso siguiente
ilumina, y las filas de "perdés/conservás" truncadas encima de los números. Nadie
vio el layout de las seis pantallas juntas.

---

## 5. RF-14 (audio) está BLOQUEADO, no pendiente

No hay con qué generarlo. Verificado: no existe MCP de ElevenLabs en la sesión, y
el único servidor de audio disponible **genera sólo voz** — su contrato prohíbe
explícitamente usar sus modelos de música y efectos para audio suelto.

Se desbloquea de dos maneras: conectando un MCP con música/SFX standalone, o
consiguiendo audio CC0 a mano (que era el plan original del proyecto; el
comentario del gate sigue en `AudioManager`). **Integrarlo es cero Swift**: el
contrato son los nombres de archivo.

⚠️ **Y su criterio de aceptación es humano.** Se puede medir nivel, duración y
costura del loop; el timbre y el "cansa en la décima vuelta" los juzga una
persona escuchando. Está medido que los archivos actuales están **técnicamente
bien** — el problema es estético.

---

## 6. Los gates humanos (sólo el dueño puede)

**La corrida de arte.** El runner usa `osascript` para mandar teclas y el shell
del agente **no tiene el permiso de Accesibilidad de macOS**. Se probó: el
lanzador de Chrome sí anda desde el agente, el puerto de debug responde, la
sesión de Gemini sigue logueada y la cola se arma bien — **lo único que falla es
tipear**. Falla en el asset 1 sin consumir cuota, así que intentarlo es barato,
pero el batch va desde **Terminal.app**.

Para `bg_galaxy` (lo único que queda), un solo comando:

```bash
cd Tools/asset-pipeline && python3 -c "import json;p='../../FisuEvolution/Resources/Data/assets_manifest.json';m=json.load(open(p));m['backgrounds'].pop('galaxy',None);open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+chr(10))" && .venv/bin/python scripts/gemini_selenium_runner.py --process --ref-threshold 5
```

⚠️ **Con el manifest así el juego NO arranca** (trampa: el fallback a placeholder
no cubre los fondos). La ventana dura lo que la generación; **no buildees ni
testees adentro**. `--process` repone la entrada; si sale mal,
`git checkout FisuEvolution/Resources/` restaura todo. El fondo viejo está además
copiado en `dropbox/procesadas/bg_galaxy.ORIGINAL-julio.png`.

**Y si el nuevo sale peor, no se integra**: es la salida de escape que el dueño
aprobó junto con el prompt.

---

## 7. Higiene que esta sesión aprendió a los golpes

- **Un simulador por frente, Y BORRARLO AL TERMINAR.** Compartir el device
  corrompe corridas (aparecen tests de otro worktree en tu log); no cerrarlos dejó
  la máquina en **736 procesos y load average 861**, con builds que pasaron de 7
  minutos a no terminar nunca.
- **Nada de `pkill -f xcodebuild`**: ese patrón mata las corridas de los otros
  frentes. Pasó.
- **El scratchpad es compartido**: prefijá tus archivos.
- **Corré el suite dos veces antes de cantar victoria.** Dos flakies distintos se
  descubrieron sólo así, y uno lo había introducido el propio frente.

Las 14 trampas del repo están en `HANDOFF.md` §7. Las cuatro nuevas de hoy son la
5-bis (interpolar la **clave** de localización no busca esa clave), la 6 (el
runner corre la app en **inglés**, así que un test que asserta texto en español
pasa por la razón equivocada), la 8 (`SKTexture.preload` necesita handler
`@Sendable` o mata el proceso — **y el test seguía verde con la app crasheada**) y
la 9 (`anchorPreference` **pisa** el valor del subárbol; va `transformAnchorPreference`).

---

## 8. Decisiones que NO se re-litigan

Están en `HANDOFF.md` §5 con su justificación. Las cinco de esta sesión:

1. **El fondo que se retira es `cosmic`** (el del río de gemas), no `mars`.
2. **Sale `Personal de Kiosco`** de la cadena y El Mantero ocupa su lugar.
3. **Magnate Petrolero queda en la luna** — bajarlo ensuciaba tres calces para
   arreglar uno.
4. **Las 4 recompensas de carrera**, de tipo distinto entre sí a propósito.
5. **Los 8 nombres de skin** de los personajes nuevos.

Y las cinco anteriores siguen en pie, sobre todo: **el gate es de UN piso** — con
dos se midió que el juego no se puede terminar.

---

## 9. El mapa de documentos de esta sesión

| Doc | Qué |
|---|---|
| `superpowers/specs/2026-08-06-correcciones-de-playtest-design.md` | **Los 16 pedidos como RF-01…RF-16**, con criterio de aceptación |
| `superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md` | Los 8 personajes, la baja de kiosco, el mapeo de 10 pisos |
| `superpowers/plans/2026-08-06-ola-0-preparacion.md` | Partir GameState, EffectDescriptor, contenido, audio |
| `superpowers/plans/2026-08-06-ola-1-cinco-frentes.md` | Mejoras, mapa, bonus, prestigio, tienda |
| `superpowers/plans/2026-08-06-ola-2-arte-y-tutorial.md` | Integrar el arte y rehacer el tutorial |
| **`balance-log.md`** | **Las tres mediciones del pacing. Es el activo más valioso del proyecto** |
