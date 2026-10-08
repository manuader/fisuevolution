# Sesión 2026-10-07 (relevo 8) — La ola F: el primer `completo` verde desde la ola B, el embudo de E1 y lo pagado que no se pierde

Continúa `Docs/SESION-2026-10-07-v2-relevo-7-ola-e.md`.

Lo que un agente necesita saber sin leer el resto:

- **`version-2` en `baabced` tiene las ramas sueltas del relevo 7 y la ola F** (E1 T12; E3a T7–T8;
  E11 T5; E2a T2 y T6; E6b T3). `rapido` sobre `f9207c2`: **VERDE (EK 506 · unit 704 + 1 declarado ·
  release 0 warnings)**, pusheado. `baabced` es `f9207c2` más `tasks.md` al cierre.
- **El `completo` sobre `15318a0` dio VERDE** y es la referencia nueva (reemplaza la de `d22eb7a`):
  EK 484 · unit 691 + 1 · Store unit 16 · UI 63 · `StoreUITests` 2 · pipeline 49/0 · `pacing-sim`
  igual (Dios en 30,73 h, 13 reencarnaciones) · Release 0 (§3). El rojo de E11 T4 en `MenuUITests`
  era flaky de carga.
- **Progreso: 35 de 167 tareas activas integradas (21,0 %)**, más E2a T7 🟢 en su rama
  (`acf633d`, sin integrar).
- **E1 T12 abrió y cerró una pérdida de video pagado** (§2): en `.inactive` se asienta lo que el
  jugador ya pagó, también el cambio que está en vuelo; el resto espera a `.background`.
- **E2a T3/T4 pasan a después de E1 T14** (regla 2 de E2a), porque E1 T12 salió antes.
- En vuelo al cierre: **E1 T13 (el Corralito) y E3b T1 (spikes S2/S3)**. La cola del relevo 9 está
  en `tasks.md` §4.

## Cómo arrancó

- Relevo 8 del run AVO, desde las 20:00 (-0300) hasta ~23. **Lo despertó la rutina
  `fisu-v2-relevo-a`**: es la primera vez que un relevo despierta solo. El relevo 7 la había lanzado
  con `run_scheduled_task`. El LOCK estaba libre y se tomó.
- Lo que pedía el relevo 7 (§7 de su sesión): los arreglos de E1 T10, integrar las ramas sueltas, un
  `completo` sobre esa punta y la ola F.

## 1. La llegada: las ramas sueltas y el `completo`

Todo con `merge --no-ff`, sin conflictos:

| Merge | Qué entra |
|---|---|
| `a24a57f` | E1 T10, los arreglos de la revisión (la escena corta el cambio asentado por afuera) |
| `0fa932c` | E5a T2–T3, los refuerzos de mutantes (92 de 93 muertos) |
| `d3a4912` | E11 T4, Ajustes con el maestro y un toggle por motivo |
| `9018bae` | E2a T1, `RewardScale`: los premios en minutos |
| `15318a0` | E6b T1–T2, los 8 efectos de skin y su galería |

Sobre `15318a0` corrió el `completo` (§3). Después, `0323944` corrigió los planes de E6b T7 y
E2a T9, que todavía citaban `resyncTower` y `performInstantMerge`: E1 T12 los borró, y E6b T7 llama
ahora a `reconcileTower` en `GameState+TowerSync.swift`.

## 2. Decisiones del controlador

| Tema | Decisión | Por qué / qué descarta | Consecuencia |
|---|---|---|---|
| Orden de E1 T12 y E2a T3/T4 | **E1 T12 sale primero** | E1 es el camino crítico. La regla 2 de E2a dice que E2a T3/T4 y E1 T12–T14 nunca van a la vez: o T4 entra antes de que arranque T12, o todo E2a T3–T5 va después de T14 | **E2a T3 → T4 → T5 van después de E1 T14** (`tasks.md` §4.2) |
| El catálogo de strings en la ola F | **E11 T5 fue dueña del catálogo**; E3a T8 entregó snapshot | E1 T12 no sumó strings, así que el catálogo quedaba libre para una sola tarea | El controlador aplicó las 4 claves de E3a T8 al integrar (`f9207c2`, snapshot `e3a-t8.json`) |
| E1 T12: el sello en `.inactive` | **En `.inactive` se asienta sólo lo pagado** (los orígenes `rewardedInstantMerge`, `rewardedRareUnit` y `career`), **también el cambio que está en vuelo**; el resto espera a `.background` | Ver abajo | `settlePrepaidBoardChanges()` en `GameState+BoardChanges.swift`; lo llama `handleScenePhase` en `GameState+Lifecycle.swift` |

### El carry que abrió una pérdida, y cómo se cerró

El carry del relevo 7 para T12 decía: **`seal` corre también en `.inactive` y asienta la cola sin
animación**. El controlador se lo pidió así al agente, y la revisión opus encontró que eso abría
**I1: una pérdida de video pagado**.

- **El caso.** El jugador ve un video (fusión instantánea o unidad rara) y el cambio queda en la
  cola o en vuelo. Abre el App Switcher (`.active → .inactive`) y mata la app desde ahí: iOS no
  manda `.background`. Lo que no se asentó en `.inactive`, se perdió, y el video ya se había pagado.
- **El arreglo** (`664f3cc`). Al pasar a `.inactive` se asienta lo que el jugador ya pagó —un
  video visto, una carrera elegida—, **también el que está en vuelo**; Startup, Blanqueo y debug
  esperan a `.background`.
- **Lo que queda por diseño**: un Startup o un Blanqueo que se descarta en el turno no se
  compensa. Un video cuyo plan sale `nil` (no hay cambio aplicable) se compensa en **E1 T14**.
- `CareerChoiceUITests` 2/2.

## 3. La evidencia: los dos oráculos

### El `completo` sobre `15318a0` (la referencia nueva)

| Suite | **`15318a0`** | Esperado (relevo 7) |
|---|---|---|
| EconomyKit | **484** | ≈ 480 |
| unit (26.5) | **691 + 1 declarado** (746 s) | ≥ 690 + 1 |
| Store unit (18.6) | **16** (1.338 s) | 13 |
| UI (26.5) | **63** (2.935 s) | 59 + lo de la ola |
| `StoreUITests` (18.6) | **2** (399 s) | 2 |
| pipeline | **49 / 0** (21 s) | 49 / 0 |
| `pacing-sim` | **Dios en 30,73 h activas · 13 reencarnaciones** (552 h de pared, maxTier 37) | igual |
| Release | **0 warnings** (478 s) | 0 |

- **Es el primer `completo` VERDE desde `d22eb7a`** (relevo 5): el de `8d17b8d` había dado rojo en
  Release. Ahora las olas C, D y E pasaron por UI, Store y `pacing-sim`.
- **`MenuUITests.testAjustesTraeSusControlesYApagaLasParticulas`**, rojo en E11 T4 en el relevo 7,
  dio VERDE: **era flaky de carga**, no de T4.
- Los +3 de Store unit y los +4 de UI no están desglosados por tarea.
- ~101 min en total (suma de las etapas). Log: `version-2/build/relevo8-completo-15318a0.log`.

### El `rapido` de la ola F sobre `f9207c2`

| Árbol | EK | unit (26.5) | Release | Veredicto |
|---|---:|---:|---|---|
| `15318a0` (`completo`) | 484 | 691 + 1 | 0 warnings | VERDE |
| `f9207c2` (la ola F) | **506** | **704 + 1** | **0 warnings** (411 s) | **VERDE** |

- unit 1.032 s. Log: `version-2/build/relevo8-rapido-f9207c2.log`. Pusheado.
- **El `pacing-sim` no corrió sobre la ola F.** E2a T2 entró con la perilla `EconomyKnobs` en 0,
  que es la v1 con huella idéntica; E2a T7, que sí sube montos, todavía no está integrada.

## 4. La ola F, tarea por tarea

| Épica | Tarea | Commit (agente → integración) | Revisión | Nota |
|---|---|---|---|---|
| E1 | T12: Startup, Blanqueo, videos y carrera por el embudo | `7febd2b` + `c355f14` + `664f3cc` (merge `5fafaf4`) | opus: spec ✅, I1 arreglado (§2) | borró `resyncTower` y `performInstantMerge` |
| E3a | T7: la barra baja | `c6a4a90` (merge `9eeb9eb`) | el controlador, por captura | `panelHeight` 64, platos 44/64; `barHeight` 84 se conserva |
| E3a | T8: la botonera del ascensor | `aae3a7f` + claves `f9207c2` (merge `9eeb9eb`) | el controlador, por captura | botones de 30 pt, persiana de 2 s, `elevatorDing` |
| E11 | T5: la tarjeta del permiso en el popup offline | `597b60e` (merge `c47d93e`) | el controlador, por diff | detent +0,26 |
| E2a | T2: el reintegro detrás de `EconomyKnobs` | `cf6dfa9` → `446397c` (merge `968d504`) | el controlador + mutantes | perilla en 0 = v1, huella idéntica |
| E2a | T6: el plan de Fusionar todo | `2c4ca71` (merge `968d504`) | mutantes | EK |
| E6b | T3: `skins.json` v2 y su validador | `2ba7c2e` (merge `e27efb1`) | el controlador, por diff | — |
| E2a | T7: cofres y packs en minutos | `acf633d` (en `v2/e2a-mecanicas`, **sin integrar**) | opus: spec ✅ | los montos suben (cofre ×1,67 … pack large ×3,27) |

### Los carries que dejó la ola (en los ledgers)

- **E3a T7 → T10**: `BoardScene.bottomInset` tiene que pasar a `panelHeight` para ganar los 20 pt
  que la barra baja liberó.
- **E3a T8 → T12**: en DEBUG el display corrido de la botonera tapa el chip ×1,0. Falta medir en SE.
- **E11 T5**: el detent no se midió en SE ni en iPad.
- **E6b T3 → T5**: dibujar `.effect`.
- **E2a T7**: `StoreManagerTests` (store-unit en 18.6) y el `pacing-sim` lo validan en el próximo
  `completo`.

**Ningún commit del rango `2a83e26..baabced` lleva `Co-Authored-By`.**

## 5. Trampas nuevas

1. **Un agente puede reportar con trabajo de fondo todavía vivo.** Pasó dos veces (E3a T7, E2a T7):
   la notificación dice "stopped with background work still running". La regla del protocolo no
   alcanza; **el controlador lo chequea en cada notificación y hace `TaskStop` antes de integrar**.
   Quedó en `tasks.md` §4.
2. **El load de 5 min llegó a 780 y no eran builds**: eran `fileproviderd`, `bird` y `mds`, o sea
   iCloud. No se mata nada; se espera.
3. **El clasificador le niega `catalogo.py aplicar` a un subagente que no es dueño del catálogo.**
   No es un error del agente: el que entrega snapshot no aplica. **El controlador aplica las claves
   al integrar** (como `f9207c2` para E3a T8).

## 6. El mecanismo (mantener lo que funcionó)

- **El `rapido` una vez por ola**: el de la ola F tardó ~25 min de unit + Release; en el relevo 7
  cada tarea pagaba ~30 min. Es la primera medida, todavía gruesa, del ahorro que pidió el dueño.
- **El `completo` va sobre la punta con las ramas sueltas integradas**, antes de la ola: así un
  rojo se atribuye a una integración y no a una ola entera.
- **Revisar un carry antes de despacharlo.** El de T12 venía del relevo 7 y estaba incompleto: la
  revisión opus lo atrapó porque la tarea tocaba el turno del tablero y la plata.

## 7. Lo que quedó abierto (relevo 9)

1. **En vuelo al cierre**: E1 T13 (el Corralito, dueña del catálogo) y E3b T1 (spikes S2/S3, sin
   commit). Si llegaron, revisar e integrar; si no, agente nuevo con BASE = su commit.
2. **Integrar E2a T7** (`acf633d`) y E1 T13 → `rapido` → push, y un **`completo`** sobre esa
   punta: valida `StoreManagerTests` y el `pacing-sim` con los montos nuevos.
3. **La ola G** (`tasks.md` §4.2): E1 T14, E11 T6, E3b T2, E3a T9; E2a T3 → T4 → T5 después de
   E1 T14.
4. **Del dueño**, sin cambios desde el relevo 7: la prueba manual v1 → v2, el batch de imágenes (los
   prompts 016–019 siguen sin commitear), el OK de Higgsfield, los anexos A y B, las dudas de E7b-b,
   `rentista_soles` y limpiar los worktrees de agentes.
