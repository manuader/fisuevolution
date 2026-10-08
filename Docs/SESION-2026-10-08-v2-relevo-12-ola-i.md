# SESION 2026-10-08 — v2, relevo 12: la bandeja del dueño, las 3 regresiones de UI y tres épicas con plan

Relevo 12 de la ejecución autónoma de la 2.0 (sesión `local_98ee9428`), despertado a las 15:21 por la
rutina `fisu-v2-relevo-a` con el `LOCK` libre. Controlador opus; implementadores sonnet en worktrees
manuales (`worktrees.nosync/v2i-<tarea>`); planificadores y revisores opus. Todo pasó por la rama de
integración **`v2i/integ-r12`**. Cerró a ~270k de contexto con 0 subagentes en vuelo.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`c94f75f`**, pusheado; `rapido` #2 VERDE: EK 556 · unit 784 + 1 declarado · release 0 |
| `v2i/integ-r12` | **`acee4d8`** = `c94f75f` + E13 T1 (+ estos docs). Su `rapido` está pendiente y NO está en `version-2`: el `completo` corre ahí |
| `completo --limpio` (E1 T16) sobre `c94f75f` | **CORRIENDO al cierre** (`build/relevo12-completo-limpio.log` del worktree `version-2`). Resultado: VERDE sobre `c94f75f` — EK 556 · unit 784 + 1 declarado (`theOwnersTargetsAreMet`) · UI 70 verdes + 2 salteados · store-unit 16 · store-ui 2 · ipad-ui 2 · pipeline 65 · pacing-sim 30,73 h / 13 · release 0. **E1 T16 ✅: E1 cerrada** |
| Progreso | **68 de 210 tareas activas (32,4 %)**; el denominador subió de 167 porque E8 (arte), E12 y E13 tienen plan por tarea |

## Las 3 regresiones de UI de la ola H: dos causas, las dos silenciosas

El `completo --limpio` #2 del relevo 11 dio rojo en tres UI tests que se reproducían aislados. Las tres
eran regresiones de código, no de carga, y salieron de dos causas.

**1. La `List` perezosa del panel de debug esconde las puertas de test.** `DebugPanelView` es una `List`
de SwiftUI: lo que queda bajo el pliegue no existe en el árbol de accesibilidad hasta que se scrollea.
E2a T14 (y T12) pusieron la sección nueva "Economía 2.0" **arriba** de "Ficha" y de las puertas
`debug.chest.award`, `debug.sheet.open` y las de especiales. Los tests las buscan sin scrollear, así que
dejaron de encontrarlas (`BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos`,
`CharacterSheetUITests.testDespedirPide…`). Arreglo `402c24d` (merge `ab7ba84`): la sección de E2a pasa
**debajo** de "Peligro", así que las puertas vuelven a quedar sobre el pliegue y se arreglan las tres
clases de una vez (cofre, ficha, especiales).

- **El diagnóstico equivocado que costó un camino:** el relevo 11 sospechaba de E2a T12 / E4a T8 para
  `CharacterSheetUITests`. Era la misma causa del cofre. Un agente (`fix-despedir`, `7571409`) lo había
  resuelto a medias moviendo sólo "Ficha" arriba; chocaba en el mismo archivo con `fix-cofre`, que movía
  la sección de E2a abajo. Se **descartó** el parcial (queda en origin) y se quedó con una sola solución.
- `CharacterSheetUITests` 3/3 verde aislada con cualquiera de las dos; con la definitiva, las tres clases.

**2. `NavigationStack(path: [Destination])` descarta los push de otro tipo.** E3b T3 puso el
`NavigationStack(path:)` de `MenuView` con un path tipado `[Destination]`. El push de
`LegalDocument.Kind` (los Términos desde Ajustes) no es un `Destination`, y SwiftUI lo **descartaba sin
error**: la pila no cambiaba y el documento se veía vacío. Arreglo `2336642` (merge `05ae020`): el path
es un `NavigationPath` (type-erased), que acepta los dos tipos. `MenuUITests` 2/2 verde con la máquina
cargada.

## La bandeja del dueño (`DUENO.md`)

- **`v2/release-ops` integrada** (`5abc90c`, merge --no-ff): `Distribution/release/release.json` como fuente
  de verdad de compras y anuncios, el CLI `Tools/releaseops/` (13 tests verdes), la skill
  `.claude/skills/release-ops/`, los 5 IDs nuevos de AdMob y la ficha de la 2.0 en App Store Connect.
  `admob sync-code` no cambió nada.
- **Gates de `tasks.md` §6 cerrados** (`a0fedd4` y después): Unidades de AdMob (11, 5 nuevas), Productos en
  App Store Connect (14 IAP, `asc diff` VERDE, salvo las capturas de las 3 ofertas hasta que exista la hoja
  de E6a T11), batch de imágenes (222/222 aprobado), `rentista_soles` (cerrado por E8 T1) y, más tarde,
  **Supabase para E12** (proyecto creado, `ANTHROPIC_API_KEY` cargada por el dueño; `c94f75f`).
- **Un switch remoto cambió un default que un test pineaba.** release-ops prendió `switches.appOpen: true`
  (decisión del dueño, gate de AdMob cumplido). `NaturalBreakPolicy.default` y su test seguían con el app
  open **apagado** "hasta que exista la unidad", y el `rapido` sobre `05ae020` dio ROJO NUEVO
  (`NaturalBreakPolicyTests.valuesComeFromTheRemoteConfig`). Arreglo `832a4f6`: el default lleva `.appOpen` y
  los tests al día; tarea `NaturalBreakPolicy/AdsRemoteConfig/AdUnitIDs` VERDE (unit 56).
- **Reglas del dueño nuevas del día:** `ESTADO.md` reescrito en cada borde de tarea (66 de 199 al empezar) y
  el barrido de worktrees con `limpiar-worktrees.sh` (aplicado: se liberaron varios GB, ver "Cierre").
- **Pedidos sin plan que quedan** (no se tocaron; planificador opus cada uno en el relevo 13): el lado Swift
  de las cinemáticas y la cadena animada de "Fusionar todo". Los clips de Higgsfield están listos en
  `automatic-image-generation/projects/fisu-evolution-v2/video/` (ver `DUENO.md`).

## E8 (arte): el plan y seis de diez tareas

Plan **P-E8** `dec80f9` (10 tareas, `2026-10-08-v2-e8-integracion-arte.md`, 13 dudas con default, peso
estimado +29 MB). Integradas, todas sólo pipeline salvo T8:

| Tarea | Commit | Resultado |
|---|---|---|
| T1 el rentista con soles sólidos | `6dae6b2` (merge `e0d683d`) | hueco 0,0025 %, alfa de los soles 0,956–0,996; el barrido dio rojo en el paso intermedio y verde con el PNG nuevo; cierra el gate |
| T2 el alta del batch y las reglas de export | `6d2f8c3` (merge `a4c77ee`) | pipeline 49 → 63; crea `traer_tanda.py` |
| T3 Pijama de Ositos · T4 Gaucho · T5 Dinosaurio | `3004952` · `a2e0458` · `61463e5` | 43/43 cada una, manifest intacto; 15 MB por atlas (45 MB, estimado 41) |
| T8 los diez fondos a 2048, en JPEG | `6029e73` (merge `1bf7c12`) | `Backgrounds/` 38 → 9 MB; tarea VERDE (EK 553, unit 36) |

Faltan T6 y T7 (en serie por `assets_manifest.json`), T9 (la revisión de recortes, 🔒) y T10 (cierre).

## E12 (ranking de la llegada a Dios): el plan, T1 y T2

Épica nueva que llegó por la sesión "Fisu Evolution v2 roadmap" (docs `7671880` → `92dbc45`), con el
nombre moderado y Supabase. Plan **P-E12** `0a1bf1e` (19 tareas, T9 partida en 9a/9b, 11 dudas con
default). Integradas:

- **T2 el backend** (`b498fa2`, merge `b8a6c2e`, opus): esquema, RLS cerrado y funciones SQL atómicas;
  `supabase/test.sh` VERDE con 23 casos. La vista se partió en `leaderboard` pública y
  `leaderboard_internal`.
- **El oráculo del backend rompía en un checkout limpio** (arreglo `9c26baa`): en un clon no existe
  `supabase/functions/` y un `find` con `set -o pipefail` corta el script. El `rapido` de la integración
  dio exit 1 **sin salida**. Ver trampas.
- **T1 `NameRules`** (`82dcab9`, merge `3e7772c`): las reglas del nombre en EK y una tabla de **31 casos**
  que comparten la app y el servidor (`supabase/tests/fixtures/`). EK 553 → 556; tarea VERDE.

Gate de E12 que sigue abierto: la lista de palabras (🔒 3) y la revisión del ranking (permanente).

## E13 (feedback de la v1): el plan, T1 y los ítems 13–14

- **Plan P-E13** `a9433f2`: 13 tareas (T2–T14), 14 dudas con default; le suma dependencias a E2b, E4a, E7b-b y
  E9b (`8b36846`).
- **T1, el botón de video al primer toque** (sonnet, revisión opus): `24ab6f0` (el video espera su carga hasta
  8 s y un toque es un solo video) + `e4b514f` (`RewardedOfferButton` y los cuatro lugares migrados, es y en).
  La revisión opus: **Approved con arreglos**, tres Important: (1) las salidas seguían activas durante la
  espera, (2) `AdLoadWait` con un `Task` que no se cancelaba con la vista, (3) el flag `lastRewardedPresented`
  compartido entre botones. Arreglos `a1a4997` (`RewardedAttempt` con `.presented/.noInventory/.busy`,
  `AdLoadWait` cancelable, salidas bloqueadas durante la espera, `onWillPresent`, +3 tests; tarea VERDE; UI ×1)
  → merge **`acee4d8`** en `v2i/integ-r12`. **Falta su `rapido`.**
- **Ítems 13–14, prioridad alta del dueño** (`bcc00b9`, `3846f11`, cherry-pick de `v2/e12-plan`): el ascensor
  pasa a ser una **placa colgante de una columna** al mantener apretado el ícono del HUD, sin LED, con viaje
  en cabina al elegir piso (placa o mapa, nunca al scrollear), y la **Tienda sale de la barra**: cinco
  pestañas simétricas. Referencia `Docs/superpowers/specs/referencias/2026-10-08-ascensor-y-barra.png`. Manda
  sobre E3a T8 y la barra de E3a. Falta el plan: **P-E13b** (`c94f75f`, el tablero).

## Oráculo

- `rapido` #1 sobre `05ae020`: build OK, unit 783, **ROJO NUEVO** `NaturalBreakPolicyTests.valuesComeFromTheRemoteConfig`
  (la causa del app open, arriba) más el declarado `theOwnersTargetsAreMet`. Arreglado en `832a4f6`.
- **`rapido` #2 sobre `c94f75f`: VERDE** — EK 556 · unit 784 + 1 declarado · release 0. `version-2` avanzó
  por fast-forward a `c94f75f` y se pusheó. El rojo declarado `theOwnersTargetsAreMet` **ya no falla**:
  revisar `rojos-declarados.txt` y sacarlo si corresponde.
- **`completo --limpio` sobre `c94f75f`** (E1 T16): corriendo al cierre, en el worktree `version-2`, log
  `build/relevo12-completo-limpio.log`. Resultado: VERDE sobre `c94f75f` — EK 556 · unit 784 + 1 declarado (`theOwnersTargetsAreMet`) · UI 70 verdes + 2 salteados · store-unit 16 · store-ui 2 · ipad-ui 2 · pipeline 65 · pacing-sim 30,73 h / 13 · release 0. **E1 T16 ✅: E1 cerrada**
- Tareas: E12 T1 y E8 T8 VERDES; E13 T1 VERDE (UI doble toque ×2, luego ×1 tras los arreglos).

## Decisiones de este relevo

- **Una sola solución para el panel de debug:** las puertas de test van sobre el pliegue y las secciones
  nuevas van debajo de "Peligro". Se descartó la solución parcial de `fix-despedir`.
- **El path del menú es un `NavigationPath`**, no `[Destination]`: la pila acepta los legales.
- **Fondos en JPEG q90 a 2048** aunque el PSNR da 35–40 dB (bajo la vara de 40 del plan): a ojo no se ven
  bloques y q95 se ve igual, así que no se paga el peso de q95. La memoria del vuelo queda para E8 T10.
- **No se mergea E12 T1 con un oráculo corriendo:** se mergeó recién tras el `rapido`. Y con el `completo`
  corriendo sobre `version-2`, E13 T1 se integró **sólo** a la rama de integración.
- **El dueño manda sobre E3a T8** para el ascensor y la barra (ítems 13–14).
- **Las dos cosas sin plan** (cinemáticas Swift, cadena de "Fusionar todo") van a un planificador opus cada una.

## Carries (de los DONE_WITH_CONCERNS y las revisiones)

- **E8 T1:** el barrido de recortes dio rojo en el paso intermedio y verde con el PNG definitivo; revisado
  a ojo en el @2x (soles enteros).
- **E8 T8 → T10:** la **memoria del vuelo con los fondos a 2048 está sin medir**; PSNR 35–40 dB.
- **E8 T3–T5 → T9:** notas de recorte para la revisión del dueño: loza en `cartonero` y `estanciero_estelar`;
  islas en `dueno_pyme`, `magnate_solar`, `dueno_marte`; `cartonero` (loza + isla entre carrito y cuerpo);
  `god` (nube) y `ser_ascendido` (halo) parecen dibujo.
- **E12 T2 → T3:** fijar `npm:@anthropic-ai/sdk`, agregar `deno.lock`; **deno no está instalado** y el
  Docker del backend no se probó.
- **E12 T1:** destraba T3 y T9a.
- **E13 T1 → E4b T3 / E7b-b T7:** `RewardedOfferButton` ya existe (lo adelantó E13 T1): reusarlo.
- **E13 T1:** `BonusHUDUITests.testTwoBonusesShowAtTheSameTime` flaky 1/3 bajo carga (carry de ola H).
- **E13 T6** (primera de E13): suma `catalogo.py quitar` (E4a T9 lo saltea); carries a E4a T4/T7/T9, E2b T10.
- **Los de la ola H siguen vigentes** (ver `Docs/SESION-2026-10-08-v2-relevo-11-ola-h.md`): E4a (T9,
  `activeEvent`, `eventIsApplicable`), E6a T5 (auto-tap), E3b T4 (`MenuPagerUITests`), E2a (M4, M5, prueba
  manual del paso 4 de T14), claves huérfanas del catálogo.

## Trampas nuevas

- **Una `List` perezosa esconde las puertas de test.** Una sección nueva ARRIBA en una `List` empuja las
  puertas (`debug.*`) bajo el pliegue y los UI tests dejan de encontrarlas sin que nada falle en unit: tres
  clases rojas por una sola sección. Regla: las puertas de test van arriba; lo nuevo, abajo.
- **`NavigationStack(path: [Destination])` tira en silencio un push de otro tipo.** No hay error ni log: el
  documento se dibuja vacío. Si la pila recibe más de un tipo de valor, el path es un `NavigationPath`.
- **`find` + `pipefail` en un checkout limpio.** `supabase/functions/` no existe en un clon limpio, `find`
  sale con error, `pipefail` lo propaga y el oráculo termina con exit 1 sin una línea de salida. El síntoma
  parecía un fallo del build. Arreglo `9c26baa`: el oráculo del backend corre en un checkout sin ese
  directorio.
- **Carga de máquina 300–600 por sesiones paralelas → flakes de UI.** `MenuUITests.openMenu` pasa su timeout
  de 10 s y `BonusHUDUITests.testTwoBonusesShowAtTheSameTime` falla 1/3. Antes de declarar regresión: aislar
  la clase ×2 con la máquina en calma (el load llegó a pico 600; con 26 ya pasan).
- **Un switch remoto que cambia un default pineado por un test.** Prender `switches.appOpen` en
  `ads.json`/`release.json` movió `NaturalBreakPolicy.default`, y el test que pinea el default se puso rojo
  en el `rapido`. Quien prenda un switch, corre las clases de config de anuncios.
- **No mergear a `version-2` con un oráculo corriendo ahí** (vigente): con el `completo` sobre `c94f75f`
  en marcha, la integración se acumula en `v2i/integ-r12`.
- **Dos arreglos al mismo archivo del mismo bug** (`DebugPanelView`): elegir uno antes de integrar; el otro
  se descarta, no se mergea encima.

## Cierre

- Subagentes en vuelo: **0**. Quedó corriendo sólo el `completo --limpio` sobre `c94f75f`.
- Worktrees barridos con `limpiar-worktrees.sh`: `v2i-plan-e8`, `v2i-e8-t1…t5`, `v2i-e8-t8`, `v2i-fix-cofre`,
  `v2i-fix-despedir`, `v2i-fix-terminos`, `v2i-e12-t2`, `v2i-plan-e13`, `v2i-e13-t1`, `v2i-plan-e12`
  (varios GB). **Se conservan:** `v2i-integ-r12` (la rama de integración, hasta que entre a `version-2`) y
  `v2-e12-plan`, que es **de la sesión del dueño** (sigue sumando commits; no se toca sin su OK).
- Siguen los tres simuladores `oraculo-26-5-84457/86209/86390` del relevo 10 (los borra el dueño: el
  clasificador frena `simctl delete`).
- Cuota al cierre: 5 h 9 %, semanal 39 %.
