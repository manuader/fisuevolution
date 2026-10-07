# Sesión 2026-10-06 (noche, relevo 3) — Los cuatro frentes integrados, la línea de base nueva y la Ola A

Continúa `Docs/SESION-2026-10-06-v2-e0-oraculo.md` y las sesiones de los frentes que esa
sesión dejó en vuelo (E8 pipeline, E8 audio, E7a y E3 i18n).

Lo que un agente necesita saber sin leer el resto: **`version-2` en `6b5e408` está verde con el
oráculo `completo`, y ésa es la línea de base nueva** (unit 570 + 1 declarado). Los agentes en
paralelo se lanzan con `Agent(isolation: "worktree")` y commitean en su rama; cualquier otra
forma choca con el guard (trampa B).

## Cómo arrancó

Es el **relevo 3** del run AVO. Lo despertó el dueño escribiendo "continua", **2 min después
del `clear_session`**. El cron de un disparo no se vio. Como el protocolo lo programa a +2–3 min
(PLAN-v2 §0), no está probado que haya fallado: el dueño pudo haber escrito antes de que
disparara. Lo que sí queda: **el mecanismo primario del relevo todavía no tiene un despertar
observado.**

## El pedido

1. **Integrar los cuatro frentes** que la sesión anterior dejó sin commitear: el guard de
   aislamiento no dejaba commitear a los subagentes (HANDOFF §7, frentes en paralelo). E10 no
   entraba en la cuenta: sus cuatro commits ya estaban en `v2/e0-oraculo`.
2. **Un pedido nuevo del dueño**: agentes concurrentes que no se pisen, y notificaciones push
   prendidas por defecto y desactivables.
3. **Arrancar E1**, en la primera ola del calendario nuevo.

## 1. La integración

En cada worktree, en este orden:

1. Se borró la copia **sin trackear** de `Tools/v2/` que el frente se había traído con `cp`. Su
   hash era idéntico al de `v2/e0-oraculo`, así que no se perdía nada, y con la copia ahí el
   merge no avanza.
2. `git merge --ff-only v2/e0-oraculo`.
3. Los commits del plan que cada frente dejó en su reporte.

| Frente | Rama | Commits | Rango | Merge en `version-2` |
|---|---|---:|---|---|
| E8 pipeline | `v2/e8-pipeline` | 4 | `03fa90c`…`4ea0678` | `cd48569` |
| E8 audio | `v2/e8-audio` | 3 | `f978ee6`…`e0f6999` | `539e1e7` |
| E7a | `v2/e7a-anuncios` | 5 | `ecf8e11`…`83a3fd4` | `0e72509` |
| E3 i18n | `v2/e3-i18n` | 7 | `9d56175`…`06b8ed7` | `6b5e408` |

- En E3, los snapshots del `.xcstrings` se verificaron con `cmp` antes de commitear.
- Los cuatro merges son `--no-ff` y entraron **sin conflictos**. `RootView.swift`, que tocaban
  E8 audio (`84181b7`, el enganche de la música) y E3 (`7e4e2de`, los consejos del splash), se
  auto-mergeó.
- Push de `version-2`: `7a298aa..eaa3497`.

## 2. La línea de base nueva

Oráculo **`completo` sobre `6b5e408`: VERDE.**

| Suite | E0 (`0442022`) | Ahora (`6b5e408`) |
|---|---|---|
| EconomyKit | 267 | 267 |
| unit (26.5) | 473 + 1 declarado | **570 + 1 declarado** |
| Store unit (18.6) | 12 | 12 |
| UI (26.5) | 57 (1.515 s) | 57 (**2.398 s**) |
| `StoreUITests` (18.6) | 2 | 2 |
| pipeline | 24 + 1 declarado | **49 / 0** |
| `pacing-sim` | Dios en 30,73 h activas · 13 reencarnaciones | igual |
| Release | 0 warnings | 0 warnings |

- **El unit cuadra exacto**: 473 + 72 (E7a) + 12 (E8 audio) + 13 (E3) = 570. Ningún test se
  perdió ni se duplicó en los merges.
- **El pipeline da ✅ con un declarado que ya pasa**: `rojos.py` tolera un rojo de la lista
  que deja de fallar, y lo avisa. La línea sigue ahí por la trampa A.
- **La UI tardó 58 % más que en E0** sin un solo rojo: es la carga de la máquina (trampa C), no
  el árbol.

## 3. El pedido del dueño: `4fd77c8`

Entró al plan como **PLAN-v2 §0.1** (el despliegue de agentes) y la épica **E11** (las
notificaciones).

**§0.1, agentes concurrentes que no se pisan.**

- Todo agente que escribe en el repo se lanza con `Agent(isolation: "worktree")`, hace
  `git merge --ff-only <base>` y commitea en su rama `worktree-agent-*`.
- El controlador no escribe código de producto: despacha, revisa, integra de a una tarea y
  documenta. Es el único que toca `Docs/`, `handoffs/`, el journal y `rojos-declarados.txt`.
- **Los archivos calientes tienen un solo dueño por ola**: `GameState.swift`, `RootView.swift`,
  `BoardScene.swift`, `project.yml`, `Localizable.xcstrings` y cinco más (lista en §0.1).
- **Tope: 3 agentes compilando a la vez, y un `completo` cuenta como uno.** Sale de la trampa C.
  Además, hasta 2 agentes que sólo escriben planes.
- Cada épica integra en su rama (`v2/e1-correcciones`, …) y se mergea a `version-2` al cerrar
  cada ola, con el `rapido` verde. El calendario va de la Ola A a la H.

**E11, notificaciones prendidas por defecto y desactivables.**

- **Locales, no remotas.** El push remoto (APNs) necesita servidor, entitlement y token, y
  cambia App Privacy. Queda fuera de la 2.0 salvo que el dueño lo pida (🔒).
- **El permiso va en dos pasos**:
  - *provisional* al terminar el núcleo del tutorial: llegan en silencio al Centro de
    notificaciones, sin diálogo, y quedan prendidas desde el día 1;
  - *completo* con una tarjeta previa, en la primera vuelta con popup offline.
- Un veterano que las apagó en la v1 las sigue teniendo apagadas.
- Catálogo data-driven `notifications.json`, y las reglas en un `NotificationPlanner` puro en
  EconomyKit: horario silencioso, espaciado, tope por ausencia, y nunca anuncios ni precios.

## 4. La Ola A

| Qué | Estado al cierre | Dónde |
|---|---|---|
| E1 T1, offline | implementado, **en revisión**; `rapido` VERDE 573 + 1 | `3693044`, rama `worktree-agent-ad8266ba8ff82fd51` |
| E1 T2, la Milanesa | en curso | — |
| Plan de E11 | commiteado, 7 tareas | `eaa3497` |
| Plan de E3 | partido en **E3a** (la pantalla, 12 tareas) y **E3b** (las interacciones, 9) | `aff6a6e` |

- **El plan de E3 se partió en dos** para que corra al lado de E1: cada uno trae su tabla de
  archivos calientes por tarea.
- **E3a T1 propone `Tools/v2/catalogo.py`**: escribe el catálogo en formato canónico (trampa
  29) y aplica los snapshots de claves que dejan las tareas paralelas. Es la pieza que hace
  posible la regla de §0.1 para `Localizable.xcstrings`.

### E1, tarea por tarea

La completa el controlador al cierre de la sesión.

| Tarea | Ola | Estado |
|---|---|---|
| T1 — Offline: toda ausencia se paga, el popup desde 30 s y los modificadores integrados | A | en revisión (`3693044`) |
| T2 — La Milanesa lee su magnitud del JSON | A | en curso |
| T3 — Un solo mutador de la frontera, contadores en `Double` y la contratación gratis que no cuenta | B | pendiente |
| T4 — Save v6 | B | pendiente |
| T5 — Nunca más pisar un save ilegible | C | pendiente |
| T6 — El ORO comprado en la v1 desde `Transaction.all` | C | pendiente |
| T7 — El embudo `BoardChange` en EconomyKit | C | pendiente |
| T8 — El ciclo de vida: sellar sólo al irse | D | pendiente |
| T9 — El turno de los cambios del tablero | E | pendiente |
| T10 — La escena reproduce los cambios como merges | F | pendiente |
| T11 — El sorteo de eventos salta lo inaplicable | F | pendiente |
| T12 — Startup, Blanqueo, los videos y la carrera por el embudo | G | pendiente |
| T13 — El Corralito congela el gasto, no los ingresos | G | pendiente |
| T14 — Un video sin efecto no gasta el cooldown | G | pendiente |
| T15 — `EffectContractTests` | H | pendiente |
| T16 — Cierre de la épica | H | pendiente |

## Trampas nuevas

### A. El clasificador del modo auto no deja usar `sed`

Al sacar de `Tools/v2/rojos-declarados.txt` la línea del pipeline que ya pasa, el clasificador
bloqueó el `sed -i` por "Irreversible Local Destruction". Desde ahí rechazó **cualquier**
`sed`, incluso un `sed -n` de lectura. Para leer, `awk` o Read.

- **Consecuencia**: `pipeline test_ningun_asset_quedo_agujereado_por_dentro` **sigue
  declarada aunque el test pasa**. El oráculo no se rompe por eso: `rojos.py` tolera un
  declarado que pasa, y el pipeline dio ✅ en el `completo`.
- **La saca el dueño.** No se rodeó el bloqueo con otra herramienta.

### B. El guard de aislamiento: lo que funciona y lo que no

La recomendación que dejaron los frentes, "lanzar cada agente con el cwd en su worktree", **no
alcanza si el worktree se crea a mano**. Un subagente que hace `EnterWorktree(path)` a un
worktree creado a mano sigue fijado al worktree del lanzador, que le rechaza Bash, Edit y
Write.

**Lo que funciona:**

1. `Agent(isolation: "worktree")`: el harness crea el worktree y la rama `worktree-agent-*`.
2. El agente hace `git merge --ff-only <base>` y commitea en su rama.
3. El controlador integra: fast-forward, cherry-pick o rebase.

**Lo que el guard rechaza dentro de una sesión aislada**, aunque el agente esté donde debe:

- `git -C <otro worktree>`;
- comandos compuestos con git ("too complex"): un comando de git por llamada;
- `Edit`/`Write` sobre el checkout principal, que es donde vive el journal. **Un append por
  Bash al journal sí anda.**

### C. La carga de la máquina

Con 3 builds de agentes más el `completo` corriendo, el `load average` llegó a **~600**.

| Medición | Tranquila (E0) | Con esa carga |
|---|---:|---:|
| UI del `completo` | 1.515 s | **2.398 s** |
| unit de un `rapido` | 411 s | **1.573 s** |

No hubo rojos en masa: se estira el tiempo, no se rompen los tests. Igual, el tope de §0.1
(3 compilando, el `completo` cuenta como uno) sale de acá.

## Contradicciones que se encontraron entre docs

- **La sesión de E0 dice que "el orquestador commitea entrando con `EnterWorktree(path:)`"** y
  que los subagentes "pueden escribir archivos con rutas absolutas". PLAN-v2 §0.1 cuenta eso
  como rodear el guard. Manda §0.1, y el general ya lo dice (§7, frentes en paralelo).
- **La sesión de E3 deja pendiente actualizar el párrafo de `iap-appstore-connect.md`** que
  decía que el jugador lee los textos "de StoreKit". Ya está hecho: la versión de E10
  (`5b8547b`) habla de `IAPCopy`.

## Qué queda

- **E1 T1**: revisión de spec y calidad, y después integrar en `v2/e1-correcciones` con el
  `rapido`. **E1 T2**: terminar.
- **Ola B**: E1 T3 → T4 ∥ el núcleo de E11 (sin ciclo de vida); el plan de E2a.
- **Gates del dueño**:
  - sacar la línea del pipeline de `rojos-declarados.txt` (trampa A);
  - escuchar los diez temas de piso;
  - `rentista_soles`;
  - todo lo marcado 🔒 en `Distribution/setup-v2-asc-admob-mediacion.md`;
  - la unidad de app open en AdMob.

## Para el HANDOFF general

### §4 (sesión)

> ### Sesión del 2026-10-06 (noche, relevo 3) — Los cuatro frentes integrados, la línea de base nueva y la Ola A
>
> Entraron a `version-2` los cuatro frentes que habían quedado sin commitear: E8 pipeline
> (`cd48569`), E8 audio (`539e1e7`), E7a (`0e72509`) y E3 i18n (`6b5e408`), sin conflictos.
> El oráculo `completo` sobre `6b5e408` dio **VERDE** y es la línea de base nueva (§6): unit
> **570 + 1 declarado**, exacto con la suma de los frentes. El dueño pidió agentes concurrentes
> y notificaciones prendidas por defecto: entraron como PLAN-v2 §0.1 y la épica E11
> (`4fd77c8`). En la Ola A, E1 T1 quedó implementado y en revisión (`3693044`), T2 en curso, y
> salieron los planes de E11 (`eaa3497`) y de E3, partido en E3a y E3b (`aff6a6e`). Detalle en
> **`Docs/SESION-2026-10-06-v2-integracion-y-ola-a.md`**.

### §5 (decisiones)

> - **Agentes concurrentes** (PLAN-v2 §0.1): `Agent(isolation: "worktree")`, archivos calientes
>   con un solo dueño por ola, hasta 3 compilando (un `completo` cuenta como uno), y un
>   controlador que integra de a una tarea y es el único que toca `Docs/`, el journal y
>   `rojos-declarados.txt`.
> - **Notificaciones** (E11): locales, prendidas por defecto y desactivables; provisional al
>   terminar el núcleo del tutorial y completo con tarjeta previa. El push remoto queda fuera
>   salvo que el dueño lo pida.

### §6 (verificar)

> La línea de base pasa a ser la de `6b5e408` (tabla de arriba).

### §7 (trampas)

> - El clasificador del modo auto bloquea `sed`, incluso de lectura: usar `awk` o Read.
> - El guard: `EnterWorktree(path)` a un worktree creado a mano no sirve; sí
>   `Agent(isolation: "worktree")`. En la sesión aislada, nada de `git -C`, git compuesto, ni
>   Edit/Write sobre el checkout principal (el journal se apendea por Bash).
> - Con 3 builds más un `completo`, la carga llega a ~600 y los tiempos se multiplican hasta
>   ×3,8 sin rojos.
> - El relevo por cron todavía no tiene un despertar observado.

### §9 (mapa)

> - Esta sesión; `Docs/superpowers/plans/2026-10-07-v2-e11-notificaciones.md`;
>   `Docs/superpowers/plans/2026-10-07-v2-e3a-ux-nucleo.md` y `…-e3b-ux-nucleo.md`; y en el
>   bullet de `PLAN-v2.md`, §0.1 y E11.
