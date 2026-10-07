# FisuEvolution v2.0 — Plan maestro

## Contexto

La v1.0.0 (build 4) de HoboEvolution/FisuEvolution está publicada. En menos de 7 días hubo ~100
descargas y USD 20. El feedback de usuarios y del dueño trajo 19 pedidos:

- **Bugs que ya afectan a jugadores**: el ingreso pasivo se congela en segundo plano, el descuento
  del Abogado "no se aplica", hay evoluciones que pasan sin que el jugador las vea, el iPad muestra
  barras con el wallpaper y algunos IAP salen en inglés.
- **Pacing y precios.**
- **Un paquete grande de features de monetización y personalidad**, inspirado en Cow Evolution.

La 2.0 es una reforma integral que reemplaza a la v1: mejor experiencia, más anuncios y más
compras, y más humor argentino. Es la base de la campaña en redes (meta: 10.000 descargas).
**Se entrega como una sola 2.0 definitiva.**

Por el tamaño, el plan es un **plan maestro de épicas** (sub-proyectos). Al arrancar cada épica se
escribe su spec y su plan de implementación detallado (skill `writing-plans`, ejecución por
subagentes), y se documenta según el sistema de handoffs del dueño.

---

## 0. Ejecución autónoma: relevo de agentes con contexto fresco (pedido del dueño)

El desarrollo corre solo: el dueño no tiene que decir "continúa". Cada agente trabaja hasta el
umbral de contexto, deja todo cerrado y documentado, y le pasa la posta a uno nuevo con contexto
limpio.

**Herramientas** (instaladas globalmente el 2026-10-06, para todos los proyectos):

- **Harness AVO** (`~/.claude/skills/avo-harness` + subagente `avo-supervisor` + regla en
  `~/.claude/CLAUDE.md`; repo `manuader/avo-harness`):
  - Cada tarea con oráculo corre el bucle hipótesis → variantes → acción → oráculo →
    commit/revert.
  - **El journal es el estado que sobrevive entre agentes**:
    `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal,
    excluido de git.
  - El supervisor se dispara con 3 iteraciones sin cambio en el oráculo, la misma firma de error
    dos veces o dos reverts seguidos.
- **Skills de documentación** (`handoff-system`, `writing-session-handoff`,
  `writing-general-handoff`, enlazadas a `~/Desktop/skills/documentation`): rigen cada cierre.
- **Oráculo del run**: `Tools/v2/oraculo.sh` (lo crea E0).
  - `rapido`: EconomyKit + build + unit.
  - `completo`: además UI en la matriz 26.5/18.6 y el contrato de pacing.
  - Cada épica agrega sus tests al oráculo antes de implementar.

**Al llegar, cada agente** hace esto, en orden:

1. Lee `Docs/HANDOFF.md` (en `version-2`) y el handoff más nuevo de
   `FisuEvolution/handoffs/`.
2. Lee `Docs/PLAN-v2.md` (este plan, versionado).
3. Lee el journal AVO: carta → estado actual → descartados.
4. Hace `git log`/`status` desde la fecha del handoff.
5. Revisa el **candado** (ver abajo).
6. Corre el oráculo `rapido`.
7. Toma el "Próximo paso" del journal.

**Umbral y relevo**:

- `get_usage("self").context.tokensUsed` se mira **en cada borde de tarea**.
  - **≥ 250.000**: no se arranca una tarea grande nueva.
  - **≥ 300.000**: se cierra.
- **Cerrar** = esperar a que **terminen todos los subagentes y tareas de fondo** → commit de lo
  verificado (o revert) → `SESION` + handoff + las 4 ediciones del general (skills de
  documentación) → journal al día → candado liberado.
- **Recién ahí, el relevo**:
  1. **Primario, en la misma sesión**: `CronCreate` de un solo disparo (+2–3 min) con el prompt
     "continúa — protocolo de relevo FisuEvolution v2…", y después
     `clear_session("self")`. El cron entra en la sesión ya limpia: un agente nuevo con contexto
     fresco.
  2. **Secundario, si el primario no despertó al siguiente**: las rutinas de la app
     `fisu-v2-relevo-a` / `-b`, alternadas con `run_scheduled_task`. Cada corrida es una sesión
     nueva; se alternan porque una rutina con una corrida en curso no se puede relanzar.
  3. **Último recurso**: el dueño escribe "continúa", y alcanza.
  - El agente anota en el journal **qué mecanismo lo despertó**, para que el próximo relevo use el
    que funciona.
- **Candado**: `.claude/avo/2026-10-06-fisu-v2/LOCK` (id de sesión + latido por tarea). Un agente
  que encuentra un candado de otra sesión con latido de menos de 20 min **no trabaja**: así nunca
  hay dos agentes a la vez.
- **Límites de uso**: antes del relevo se mira `get_usage().plan`. Con la ventana de 5 h ≥ 85 % o
  la semanal ≥ 90 %, el relevo se agenda para `resetsAt` + 5 min en vez de ahora.

**Gates humanos**: si la próxima tarea necesita al dueño (lista en E0, punto 6):

1. "🔒 Necesito de vos: …" en el handoff y en el journal;
2. `PushNotification` al dueño;
3. se sigue con lo que no esté bloqueado.
- Si todo lo que queda está bloqueado, **no hay relevo**: se para y se espera el "continúa" del
  dueño.

**Fin**: con el plan completo hasta los pasos humanos de E10, informe final + `PushNotification`
y no hay más relevos.

**El primer relevo es el de esta sesión de planificación**: cerró con ~770.000 tokens de
contexto, así que la ejecución arranca en un agente nuevo.

### 0.1 Despliegue de agentes concurrentes (pedido del dueño, 2026-10-06)

El desarrollo corre con varios agentes a la vez que no se pisan: cada uno en su worktree, con
archivos de dueño único por ola, y un controlador que integra de a uno.

**El mecanismo** (verificado el 2026-10-06, journal It 04):

- Todo agente que escribe en el repo se lanza con **`Agent(isolation: "worktree")`**. El harness le
  crea un worktree propio (`.claude/worktrees/agent-*`, rama `worktree-agent-*`) y el guard lo deja
  usar git y editar **sólo ahí**.
- Su primer paso: `git merge --ff-only <base>` (o `git reset --keep <base>` con el árbol limpio) y
  comprobar el hash. Commitea en su rama y reporta rama, worktree y commits.
- ❌ **No sirve** crear el worktree a mano y que el agente haga `EnterWorktree(path)`: el guard
  sigue fijado al worktree del lanzador y le rechaza Bash, Edit y Write.
- ❌ **Tampoco** escribir con rutas absolutas desde otro cwd: eso es rodear el guard.
- Los agentes que sólo escriben planes también van aislados y commitean el plan en su rama.

**El controlador** (la sesión principal):

- no escribe código de producto: despacha, revisa, integra y documenta;
- después de cada tarea, una revisión de spec y calidad con un subagente revisor (skill
  `subagent-driven-development`), antes de integrar;
- integra de a una tarea: `git rebase` de la rama del agente sobre la punta de la épica +
  `git merge --ff-only`, y `oraculo.sh rapido` sobre la integración;
- es el dueño de `Docs/`, `handoffs/`, el journal, el ledger y `rojos-declarados.txt`: los escribe él, o
  despacha **un solo** agente de docs a la vez, que no corre en paralelo con otro que toque `Docs/`.

**Archivos calientes: un solo dueño por ola.**

- Son `GameState.swift`, `RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`,
  `GameState+Bonus.swift`, `SettingsView.swift`, `PlayerState.swift`, `TowerActions.swift`,
  `project.yml` y `Localizable.xcstrings`.
- Cada despacho lleva la tabla de dueños de su ola, armada con la sección "Orden, olas y
  paralelismo" del plan de cada épica. Un agente que necesita un archivo caliente ajeno para y
  reporta `NEEDS_CONTEXT`.
- Si dos tareas de la misma ola necesitan strings, la segunda entrega sus claves como snapshot del
  catálogo (el patrón de E3) y el controlador las aplica al integrar, en formato canónico.

**Topes:**

- Hasta **3 agentes compilando a la vez**, cada uno con su DerivedData y su simulador por UDID. Un
  `completo` del oráculo cuenta como uno.
- Además, hasta **2 agentes que sólo escriben planes**.
- Antes de cada ola, `get_usage`: con la ventana de 5 h ≥ 85 % o la semanal ≥ 90 % la ola no se
  lanza y se espera el reset.
- Modelos: `sonnet` para implementar cuando el plan trae el código; `opus` para los planes de
  épica, el diseño y la revisión final de cada épica.

**Ramas:** cada épica integra en su rama (`v2/e1-correcciones`, `v2/e11-notificaciones`, …). Al
cerrar cada ola, la rama de la épica se mergea a `version-2` con el `rapido` verde, y las tareas
nuevas de otras épicas salen de `version-2`.

**El calendario de olas:**

| Ola | Código (≤ 3 compilando) | Planes (sin compilar) |
|---|---|---|
| A | E1 T1 ∥ E1 T2 | E11, E3 |
| B | E1 T3 → T4 ∥ E11 núcleo (sin ciclo de vida) | E2a |
| C | E1 T5 ∥ T6 ∥ T7 | E4 |
| D | E1 T8 ∥ E3 (lo que no toca archivos calientes de E1) ∥ E11 (Ajustes y tarjeta) | E5 |
| E | E1 T9 → E11 cableado al ciclo de vida ∥ E3 | E6 |
| F | E1 T10 ∥ T11 ∥ E2a (EconomyKit puro) | |
| G | E1 T12 → T13 → T14 ∥ E3 ∥ E2a | E7b |
| H | E1 T15 → T16: cierre de E1 | E9 |
| luego | E4 ∥ E5 por tarea (comparten `GameState`), E6, E7b, E9, E2b; E8 según los gates del arte | |

El calendario es la intención: cada ola se re-arma con las huellas reales de archivos de los
planes, y se corre de a uno lo que se pisa.

---

## 1. Punto de partida (verificado)

- **Base de trabajo: la rama `version-2`** (worktree `.claude/worktrees/version-2`, tip `7a298aa`,
  árbol limpio). Ya contiene:
  - el tag `v1.0.0-build4` y el fix del cofre (`97cb618`);
  - `feat/atajo-al-mejor-tier`: el atajo vende el MEJOR tier que alcanza la plata (§5.0-quinquies);
  - `feat/cofres-solo-desbloqueados`;
  - `MARKETING_VERSION 2.0.0` / `CURRENT_PROJECT_VERSION 5`;
  - limpieza del pipeline, de `balance-sim` y de código muerto (incluye el fix
    `ads?.setRemovedAds(...)`: comprar remove_ads ya frena los intersticiales sin reiniciar).
- ⚠️ **Otra sesión del dueño trabajó en ese worktree** durante esta planificación. Antes de
  arrancar se revisa `git log`/`status` para ver si sumó algo. Cada épica trabaja en su propio
  worktree desde el HEAD local de `version-2`, siguiendo el protocolo de sesiones paralelas:
  - `git log` + `status` antes de stagear;
  - staging selectivo y commit rápido;
  - `-derivedDataPath` absoluto;
  - `xcodegen generate` al agregar o borrar archivos Swift;
  - nunca stagear el pipeline de arte ajeno.
- **Reglas del dueño que rigen todo**:
  - commits en español, **sin `Co-Authored-By`**;
  - imitar el estilo del repo y escribir código limpio;
  - identificador de accesibilidad en cada control;
  - strings nuevos en `Localizable.xcstrings` (es + en) en el mismo commit que la vista; nunca
    editar el catálogo por script salvo en formato canónico (trampa 29);
  - **FisuJobs es la referencia visual de toda pantalla**;
  - **al cerrar cada tarea**: `Docs/SESION-<fecha>-<tema>.md`, `handoffs/HANDOFF-…` y las cuatro
    ediciones de `Docs/HANDOFF.md` (§4, §5, §7, §9).
- Verificación de siempre: EconomyKit `swift test` → unit → UI. Matriz de dos runtimes: iOS 26.5
  para todo e iOS 18.6 para las suites de Store. Simulador propio por UDID. `pacing-sim` con
  `--upgrades` explícito, y siempre corriendo primero la línea de base.

## 2. Decisiones del dueño (cerradas en esta planificación)

| Tema | Decisión |
|---|---|
| Fisu Coin | Memecoin real **fuera de la app**, como proyecto aparte con asesoría legal. **Cero menciones o links adentro del juego.** El ORO es la moneda premium. |
| Entrega | **Una sola 2.0 definitiva.** |
| Intersticiales | **Común + bonificado, alternados**, cada ≥2 min y **sólo en pausas naturales**. Más **app open** al volver. |
| Mediación | **AppLovin, Unity Ads, Mintegral y Meta** (bidding). |
| IAP | **Packs de ORO reescalados** + **ofertas por tiempo limitado**. Sin VIP ni suscripción. |
| Tienda de ORO | Cuatro categorías: boosts, atajos, permanentes, y cosméticos y azar. |
| Skins de ORO | **Efectos por código** (shaders, ver "Efectos de skin") + **3 familias dibujadas**: Pijama de Ositos, Gaucho y Disfraz de Dinosaurio (43 personajes cada una). |
| ORO comprado | **Sirve para todo** (tienda y las 7 líneas). Las **7 líneas pasan a costar el doble: 348** en vez de 193, así un pack chico no regala el juego. |
| Escala del ORO | Ancla: **1 h de producción ≈ 90 ORO**. Ejemplos: ×2 por 30 min = 30, giro extra = 12, familia de skins = 450. Los boosts tienen tope diario. Un jugador gratis junta ~12.000 ORO hasta Dios. |
| Packs de ORO | **160 / 550 / 1.400** por **USD 1,99 / 4,99 / 9,99**. Los IDs no cambian; los montos se ajustan con el simulador sin tocar el precio. |
| Ofertas (precios) | **Bienvenida** USD 0,99 = 120 ORO + 2 h de producción + 1 cofre. **Renacer** USD 2,99 = 300 ORO + 4 h + ×3 por 30 min. **Mudanza** USD 4,99 = 500 ORO + 8 h + 3 Paquetes. |
| Contrato de pacing | Se mide con un jugador que **reencarna al multiplicar ×5 su ORO** (≈6 reencarnaciones). |
| Herencia al reencarnar | **Sólo se recuerdan los pasivos desbloqueados** (la run arranca de cero, pero con el ingreso pasivo de cada personaje ya comprado). |
| iOS mínimo | **Sube de 17 a 18.** Habilita el tamaño de hojas en iPad y el historial de consumibles para reconstruir el ORO comprado en la v1. |
| Fondos | **Se regeneran los 10 con ChatGPT a 2048 px**, adjuntando el original como referencia. Mejoran iPhone y iPad. |
| Sin anuncios | `remove_ads` (y starter) sacan **los tres formatos forzados**: intersticial, pausa publicitaria y app open. Los videos opt-in siguen. |
| Lugares por piso (crítica de Marco) | **15 por piso para todos** (3 filas), y la multitud usa casi toda la pantalla: sube del 44 % al ~70 % del alto. El permanente de ORO lleva a **20 (4 filas)**. Reemplaza al "+2 lugares → 3ª fila". |
| Fusionar todo (crítica) | Boost **por video o por ORO**: fusiona de una todos los pares del piso. Los tiers nuevos se celebran igual, porque el jugador está mirando. |
| Piso móvil para reencarnar (crítica) | **Para reencarnar hay que alcanzar el tier más alto de la run anterior.** El botón lo dice ("Llegá al Rey del Ladrillo para reencarnar"). Frena el ORO fácil y encaja con "cada run llega más lejos". |
| Pisos en marcha (crítica) | **Cada piso con todos sus lugares ocupados da +5 % de ingresos globales** (hasta +50 % con los 10): los pisos bajos vuelven a tener sentido. Los visitantes piden personajes de pisos bajos y pagan bien. |
| Barra de abajo (crítica) | **Más baja y progresiva**: un jugador nuevo ve sólo **Contratar** (más grande, al centro) y **Mejoras**. Las demás pestañas aparecen con "¡Nuevo!" cuando se desbloquean, y el tutorial las presenta. El tablero gana pantalla. |
| Botonera del ascensor (crítica) | El ascensor se fusiona con la columna de pisos: **botonera de metal en el borde derecho, con un display LED** ("3 · Corporativo") que hace de cartel del piso. **En reposo sólo se ve el display**; al scrollear o tocarla se despliega como una persiana metálica y a los 2 s se recoge. La luz viaja suave entre los botones siguiendo la cámara, **sin cortar el scroll**. Tocar un botón hace "ding" + el vuelo de siempre, y el ícono del ascensor abre el mapa de hoy. |
| Nombres | Se quedan **Crypto Bro** y **Demonio de ARCA** (sátira; los guiones no usan palabras de cripto). |
| Corralito | **No podés gastar 45 s** (contratar y mejorar bloqueados); los ingresos siguen. Escape por video. |
| Loot boxes | Los giros extra y los cofres por ORO **se apagan en Bélgica y Australia**, vía la config remota por tienda. En el resto, con probabilidades visibles. |
| Popup offline | Aparece desde **30 s** afuera. Por debajo, la plata se acredita en silencio. |
| Válvulas del tutorial | **"Terminar repaso"** sólo en el replay pedido desde Ajustes. **Un paso de acción trabado se libera a los 3 min**, sin premio y con log. |
| Compartir | **Recablear y potenciar**: ofrecer compartir en los momentos virales (personaje nuevo, piso nuevo, reencarnación, Dios) con la tarjeta vertical y un premio chico. Vuelven el logro y el bonus viral. |
| Música | **Un tema chiptune por piso** (10), con crossfade al cambiar de piso. |
| Reacciones de campo | **Descartadas** (decisión del dueño en la sesión de preparación, 2026-10-06). No se portan. |
| Paquete de la Aduana (ítem 3) | Cae **cada 2 min de juego, hasta 2 esperando**. Cada tier más bajo es 2× más probable; el tier tope desbloqueado sale ~5–8 %. Con el piso lleno, espera con un cartel "LLENO". |
| Ruleta (ítem 4) | Premios variados. **6 giros por video por día** + giros extra con ORO, con probabilidades visibles. El 2º video repite el premio. La presenta el Conductor de TV. |
| Visitantes (ítem 5) | Cada **~5 min**, sin castigos fuertes: trueques, y el arresto siempre compensa. Si se los ignora, se van a los 30 s. **Ya no quedan chiquitos en el tablero**: entran, hablan, actúan y se van. Los conseguidos viven en un **Álbum de especiales** en la Oficina central. |
| Elenco nuevo | Comisario, Sindicalista, Turista Gringo, Puntero Político, Ministro de Economía, Vecina Chusma, Vendedor Ambulante y Conductor de TV. Los 10 especiales existentes también visitan. Sólo arquetipos: ni personas reales ni marcas. |
| Eventos | Los 8 actuales (**"Cayó Mercado Pago" → "Se cayó el home banking"**). Se suman **+**: ¡Salimos campeones!, Liquidación Total, Feriado Puente, Lluvia de Paquetes. Y **−**, siempre con salida por video: Paro General, Apagón, Hiperinflación, Cepo Cambiario, Piquete en la autopista, Ola de Calor. Los anuncia un visitante y queda un **chip con su cara y cuenta regresiva**. Se elimina el banner. |
| Higgsfield | Tope **600 créditos**: reencarnación, arresto, llegada a Dios y retratos animados de visitantes. Todo lo demás se anima por código. |
| Arte | **ChatGPT web** vía `automatic-image-generation` + pipeline de Fisu, con la metodología de biblia de personajes de `content-urbe`. |
| Atajo (ítem 7) | El mejor tier que alcanza y entra. Si no hay ninguno, el siguiente. **Nunca desaparece**: queda deshabilitado con el motivo ("Piso lleno" / "No te alcanza"). **Mantener presionado** abre un selector con caras para **pinear** o despinear. Lo enseña el tutorial. |
| Precios (ítem 12) | El contador se reinicia al reencarnar. **Fusionar abarata, pero no tanto**: reintegro parcial ajustable. Se muestra **"+6 % por compra"**. Selector en el panel de debug para que el dueño lo pruebe; si no convence, vuelve a v1. |
| No penalizar el avance | **Suavizar el salto de precios** al subir de tier (hoy ×2,99 instantáneo) y pagar **todos los premios en minutos de producción real**. |
| Carreras (ítem 10) | **Programador → contrataciones gratis 2 min.** **Abogado → "Juicio ganado"**: suma grande en minutos de producción. |
| Pacing (ítem 11) | Duración parecida a la actual: **Dios ≈31–35 h activas, en el reloj del simulador**, un poco más larga por **pisos finales más duros**. Early game más rápido, **4–6+ reencarnaciones** (medidas con la política ×5), las 7 líneas al máximo **antes** de Dios, y ninguna run peor que la anterior. |
| iPad (ítem 1) | App universal, **sólo vertical** (`UIRequiresFullScreen`). La clave está deprecada y se ignora al compilar con el SDK de iOS 27: riesgo documentado. |
| Tutorial (ítem 14) | **No salteable.** Los mensajes explicativos esperan **5 s fijos**; los pasos de acción sólo avanzan haciéndolos. Explica todo con cartel y dedo. En Ajustes: **"Ver tutorial de nuevo"** + **zona de peligro "Resetear partida"**. **Tour de novedades** para los veteranos de la v1. |
| Reset | Se conserva lo comprado. **El ORO comprado se conserva sólo si no se gastó** = `min(saldo, ORO comprado de por vida)`, gastando primero el ORO ganado. La confirmación es fuerte, en varios pasos y con números. |
| El Colchón (ítem 3) | Familia de tesoro aparte de los cofres de pintas, como los "Hidden Treasures" de Cow Evolution: *"Tus empleados escondieron plata en el colchón"*. Aparece cada tanto y **se abre con video**. Da plata (minutos de producción), ORO o un Paquete. **"Otro colchón"** con un 2º video. |
| Ofertas 24 h | **"Pack Renacer"** al reencarnar, **"Pack Mudanza"** al abrir un piso nuevo y **oferta de bienvenida** el 2º día de juego (una sola vez). Cada una es un IAP nuevo. |
| Médico Jr. | **"Obra social"**: inmunidad a los eventos negativos durante 30 min, **más cortar en el acto el evento negativo en curso, más 15 min de producción** al elegirla. Reemplaza al café gratis. |
| App open | Al volver tras **≥3 min afuera**, como **máximo 1 cada 20 min**. Nunca en el primer arranque, con remove_ads ni en el tutorial. Ajustable a distancia. |
| Accesos en pantalla (ítem 18) | **Columna lateral fija** a la izquierda, como en Cow Evolution: Ruleta, El Colchón, Paquetes y Boost por video. Badge "!" cuando hay algo listo, reloj cuando falta, y un latido suave. |
| Vendedor Ambulante | Ofrece un boost por video **cada ~3 min de juego activo**, intercalado con las visitas de ~5 min. Si se lo ignora, se va solo. |
| Efectos de skin (ORO) | Candidatos: Neón, Holograma, Fantasma, Arcoíris, Glitch, Pixel, Oro líquido y Sombra. **Gate: el dueño ve una muestra de cada uno antes de que entren.** Los que queden mal se descartan, y en su lugar **algunas skins existentes pasan a ser exclusivas de ORO** (las elige el dueño). |
| El Colchón, frecuencia | **Cada ~8 min de juego activo**. No se acumula más de 1. |
| Pausa publicitaria | El intersticial bonificado **rota su premio**: 10 min de producción → ×2 ingresos por 5 min → un Paquete de la Aduana. |

## 3. Causas raíz verificadas en el código (cambian el diseño)

| Pedido | Causa real | Dónde |
|---|---|---|
| 8 · Pasivo congelado en background | Al volver, iOS pasa por `.background → .inactive → .active`. La rama `.inactive` re-sella `lastSeenTimestamp = ahora` (y lo guarda), así que `.active` calcula ≈0 s (umbral 30 s) y paga 0. Encima, el popup con el ×2 por video sólo aparece si `credited > 0`: anuncio perdido. | `GameState.swift:897-917` (handleScenePhase), `RootView.swift:42-44`, `OfflineCalculator.swift:26-42`, `IncomeTicker.swift` (clamp de 2 s) |
| 10 · "El descuento del Abogado no se aplica" | **Sí se aplica**, pero sólo a contratar, y el mismo merge de la carrera sube la frontera (precios ×2,99): a la vista, los precios suben ×1,49. "Cayó Mercado Pago" (×2) lo anula. | `GameState+Bonus.swift:582-588`, `TowerActions.swift:81,128` |
| 10 · Premios que no escalan | Se calculan como `k × passiveUnlockCost(maxTier)` = 120·k s de **una** unidad sin mejoras. Ignoran los multiplicadores de piso (hasta ×620), el ORO, las mejoras y la cantidad de unidades. | carreras, diario, asado, monedas de cofre y packs de plata IAP (`ContentSystems.swift`, `GameState+Chests/+Store`) |
| 12 · Precios que se disparan | Contador **por tipo** (×1,06 por compra), de por vida en la run; no baja al fusionar. Al apoyarse en un tipo, la curva es una doble exponencial. El atajo viejo, que sólo vendía el tier base, lo empeoraba; la v2 ya lo corrigió en `version-2`. | `EconomyConfig.swift:428-438`, `TowerActions.swift:306-309` |
| 16 · "Se fusionó solo mientras dormía" | El evento **"Startup comprada"** evoluciona tu mejor unidad a un tier nunca visto, sin revelación. El reconciliador puede abrir pisos y auto-fusionar (o descartar) unidades. Un evento vencido dispara al volver. Además, **elegir carrera no revela el T11**. | `ContentSystems.swift:216-230`, `TowerReconciler.swift:56-154`, `GameState+Actions.swift:240-288` |
| 1 · Barras en iPad | La app es sólo iPhone (`TARGETED_DEVICE_FAMILY "1"`): iPadOS la corre en modo compatibilidad. El tablero escala por ancho: en el iPad 13" los personajes miden el 29 % de la altura y se estiran 2,1×. | `project.yml:42,101`, `BoardScene.swift:1226-1234` |
| 19 · IAP en inglés | El nombre sale de `product.displayName` (App Store Connect). El idioma principal de la app es inglés, así que sin localización española **aprobada** (o con el dispositivo en es-ES y sólo es-MX cargado) cae al inglés. | `StoreView.swift:612`, `Distribution/iap-appstore-connect.md` |

**Bugs adicionales encontrados (entran a la 2.0):**

1. Los videos "Evolución gratis" / "Personaje de regalo" **gastan el cooldown aunque no pase
   nada**: el jugador mira un anuncio por nada.
2. El Blanqueo pierde la unidad en silencio con el piso lleno.
3. Los especiales del día 7 nunca se dibujan.
4. `announcedEventID`: desaparece junto con el banner de eventos en E4.
5. La Milanesa ignora su valor del JSON.
6. El texto del Corralito promete algo que no hace.
7. El offline aplica los modificadores del momento de volver a todo el período.
8. El watchdog de celebraciones recibe el delta sin clamp.
9. Falta el texto de ATT en inglés.
10. **Falta el botón "Opciones de privacidad" (UMP)**, un hueco de cumplimiento en la UE.
11. Los Términos dicen que remove_ads saca los videos bonificados (falso).
12. Las notas a App Review no mencionan el intersticial al cerrar menús.
13. ⚠️ **Si el save no decodifica, el arranque graba una partida nueva encima** (`GameState.swift:532-551`): riesgo de pérdida total al migrar a v6.
14. Los packs de ORO (250/750/2000) superan todo lo gastable (193): con USD 1,99 se maxea el juego entero.
15. Los toasts flotan 53 pt de más.
16. El texto del tip del atajo quedó viejo.
17. Las etiquetas de las pestañas no coinciden con los títulos de las hojas.

## 4. Épicas y orden

**De pedido a épica** (los 19 ítems del dueño):

| # | Pedido | Épica |
|---|---|---|
| 1 | Aspect ratio en todos los iPhone y iPad | E3 (+ fondos en E8) |
| 2 | Más anuncios, intersticial cada 2 min, ORO con más usos, Fisu Coin | E7, E6. La memecoin queda fuera de la app (§7) |
| 3 | Cofres con ORO/plata + caja con personaje random | E5 (Paquete de la Aduana, El Colchón), E6 (cofre por ORO) |
| 4 | Ruleta con video y repetir premio | E5 |
| 5 | Policía/ARCA y especiales con pedidos, eventos con personaje | E4 |
| 6 | Más animaciones | E8 (+ efectos de escena en E4/E5) |
| 7 | Atajo: mejor tier, pin con mantener presionado, nunca desaparece | E3 (+ lección en E9) |
| 8 | Pasivo congelado en background | E1 |
| 9 | Ficha de skins más grande, con X y en estilo FisuJobs | E3 |
| 10 | Abogado, auditoría de efectos, premios de carrera acordes | E1 (auditoría) + E2a (carreras y premios) |
| 11 | Pacing con curva y 3+ reencarnaciones | E2b |
| 12 | Precios que se disparan | E2a (reintegro, amortiguador, "+6 %") |
| 13 | Deslizar entre pestañas del menú | E3 |
| 14 | Tutorial no salteable, replay y reset | E9 |
| 16 | Fusiones solas mientras dormía | E1 |
| 17 | Más ítems de compra con ORO | E6 |
| 18 | Más unidades de anuncios, recomendador, doc de App Store Connect y AdMob | E7 + E10 |
| 19 | IAP en inglés | E3 (`IAPCopy`) + E10 (checklist de App Store Connect) |
| C1 | Crítica de Marco: el ORO se vuelve fácil | E2b (piso móvil + calibración) + E6 (sumideros, líneas a 348) |
| C2 | Crítica: 10 lugares es incómodo, usar toda la pantalla | E3 (15 lugares, multitud al ~70 %) + E2b (calibración) + E6 (permanente → 20, "Fusionar todo") |
| C3 | Crítica: ver en qué piso estás | E3 (botonera del ascensor + display LED) |
| C4 | Crítica: la barra de abajo confunde y ocupa mucho | E3 (barra baja y progresiva) + E9 (lecciones de cada pestaña nueva) |
| C5 | Crítica: los pisos bajos pierden sentido | E2a/E2b (pisos en marcha) + E4 (visitantes que piden tiers bajos) |
| P1 | Sesión de preparación: compartir inalcanzable | E3 (compartir recableado) |
| P2 | Música por zona | E8 (un tema por piso) |
| P3 | Splash sin logo, tips sin traducir, arte calado | E3 + E8 |
| 20 | Notificaciones push prendidas por defecto y desactivables (2026-10-06) | E11 (+ E9 Ajustes y Tour, E5 ruleta) |

```
E0 Preparación
 └─ E1 Correcciones críticas + save v6 seguro      (bloquea a todos: crea el camino "celebrable")
     ├─ E2a Mecánicas de economía                    (precios, premios, carreras)
     ├─ E3 UX núcleo                                 (atajo, ficha, menú deslizable, iPad, i18n)
     ├─ E7a Infraestructura de anuncios              (proveedor, alternancia, app open, remoto, mediación)
     ├─ E11 Notificaciones                           (el núcleo en paralelo con E1; el cableado, después de E1 T8)
     └─ E8 Arte y animación                          (arranca YA: es lo más largo y tiene gates humanos)
          ├─ E4 Visitantes + Eventos v2 + Álbum      (usa placeholders hasta que llegue el arte)
          └─ E5 Paquete de la Aduana + Colchón + Ruleta
               └─ E6 Tienda de ORO + IAP + skins
                    └─ E7b Ubicaciones de anuncios + columna lateral + Vendedor
                         └─ E9 Tutorial v2 + Tour de novedades + Ajustes
                              └─ E2b Calibración final de pacing + contrato
                                   └─ E10 Release: doc ASC/AdMob, capturas, archive, TestFlight
```

Las épicas en paralelo trabajan **archivos disjuntos** en worktrees propios. Las que tocan
`GameState`/`BoardScene` a la vez (E4 y E5) se secuencian por tarea. `version-2` ya está limpia
(`7a298aa`): la otra sesión commiteó su limpieza. Esa limpieza **borró `SpeechBubble`/`ui_speech_bubble`**,
así que el globo de la v2 es vectorial.

**Cimientos compartidos** (primera tarea de E4, de la que dependen E5–E7):

- **`RewardSpec`**: un único vocabulario de premios para visitantes, ruleta, colchón, tienda,
  ofertas y escapes. Tipos: `coinsSeconds`, `oro`, `package`, `skinChest`, `modifier`,
  `clearBoostCooldowns`, `autoTap`, `nextOfflineMultiplier`, `nextDailyMultiplier`, `wheelSpin`,
  `extraSlots`, `eventImmunity`.
  - Se aplica en un solo punto: `GameState+Rewards.grant(_:multiplier:source:)`, donde
    `multiplier = 2` es el "×2 con video".
  - `coinsSeconds` reusa `coinReward(seconds:)` (`GameState+Achievements.swift:453-470`),
    promovida a `RewardMath.coinPayout` en EconomyKit.
- **Estado nuevo en una sola clave del save**: `meta.engagement` (`EngagementState`, con
  `decodeIfPresent ?? .initial`). Incluye `visitors`, `packages`, `treasures`, `wheel`, `shop`,
  `offers`, `firstLaunchDay` y `seenCinematics`. Es el patrón de `chestsPending` y no hace falta
  subir el schema. Se suma a `SaveConflictResolver`.
- **`isCalmMoment`**: el predicado de `GameState.swift:468-473` (sin hoja, sin celebración, sin
  tutorial), reusado por visitantes, intersticiales y ofertas.
- **Efectos nuevos en `ActiveModifier.Effect`**: `passiveMultiplier` (hoy `incomeMultiplier`
  también multiplica el tap), `packageRateMultiplier`, `autoTapPerSecond`, `spendingFrozen`
  (Corralito), `freeHire` (Programador) y `eventImmunity` (Médico). Los switches exhaustivos de
  `ActiveBonusBuilder.effectText` y `EffectDescriptor` obligan a darle texto a cada uno, y se
  agregan sin romper la decodificación de saves viejos.
- **Configs nuevos en EconomyKit** (como `SkinsConfig`/`ChestsConfig`): `visitors.json`,
  `events.json` v2, `packages.json`, `treasures.json`, `wheel.json`, `oro_shop.json`,
  `offers.json`. Cada uno con validador, siguiendo el patrón `GameContentLoader.validate`.
- **`RewardedOfferButton`**: un botón de video reusable (precarga + sondeo + spinner + id de
  accesibilidad) para los ~15 lugares nuevos. Hoy cada vista lo duplica.
- **Nada de lo nuevo corre bajo `--uitest*`** salvo que el test lo pida (patrón de
  `tutorialLessonsAutorun`).

### E0 — Preparación

1. **Hecho en la sesión de planificación**:
   - el plan versionado como `Docs/PLAN-v2.md` y la sesión `Docs/SESION-2026-10-06-plan-v2.md`;
   - el general actualizado;
   - el handoff `handoffs/HANDOFF-2026-10-06-plan-v2.md`;
   - el journal AVO y su candado.
2. **Primer agente**:
   - crea `Tools/v2/oraculo.sh` (`rapido` | `completo`) y lo corre para tener la línea de base;
   - abre `Docs/SESION-<fecha>-v2-<épica>.md` por épica.
3. Cada épica corre en un worktree propio desde el HEAD local de `version-2`, con el `.venv` del
   pipeline enlazado y `xcodegen generate`.
4. Las features a medio hacer quedan detrás de flags hasta que cierran.
5. **Cómo se ejecuta cada épica**:
   - spec corta: las decisiones ya están acá;
   - plan de implementación con `writing-plans`;
   - ejecución por subagentes;
   - **al cerrar cada tarea**: commit + `Docs/SESION-…` + `handoffs/HANDOFF-…` + las cuatro
     ediciones del HANDOFF general, antes de despachar la siguiente (regla del dueño).
6. Gates humanos, que se agendan con el dueño:
   - login de ChatGPT y la corrida del batch con la app de Claude cerrada;
   - cuentas de las 4 redes de mediación;
   - unidades de AdMob;
   - productos y localizaciones en App Store Connect;
   - aprobación de la galería de efectos de skin y de los anexos A y B;
   - playtest de las variantes de precio en el panel de debug;
   - TestFlight.

### E1 — Correcciones críticas y save v6 seguro

- **Offline (ítem 8)**:
  - `RootView`: `.onChange(of: scenePhase) { old, new in … }` → `handleScenePhase(from:to:)`.
  - **Se sella `lastSeenTimestamp` sólo en `.background`, o en `.inactive` cuando el anterior era
    `.active`.** Ese era el bug.
  - La persistencia va envuelta en `beginBackgroundTask`, que hoy no existe en el repo.
  - `OfflineCalculator` acredita cualquier ausencia de más de 2 s. **El umbral pasa a gobernar
    sólo el popup**, que aparece desde **30 s** afuera (decisión del dueño; dato en
    `economy.json`).
  - Los modificadores se **integran sobre el período** (`ModifierMath.offlineFactor`): un buff paga
    hasta que vence y los debuffs se ignoran.
  - El watchdog de celebraciones recibe el delta con clamp.
  - Un evento vencido **no dispara al volver** (se reprograma a +60 s).
  - Latido cada 15 s en foreground, para que un kill en foreground no pague de más.
  - Tests nuevos en `LifecycleTests` (la secuencia completa de fases) y `OfflineModifierTests`.
- **Cero evoluciones sin ver (ítem 16)**: embudo único `BoardChange` (`GameState+BoardChanges.swift`)
  con dos fases.
  1. **Planear** (`planAutoMerge`, `evolveUnit` y `placeUnit` en EconomyKit, sin contadores de
     compra).
  2. **Confirmar en su turno de celebración**, sólo con `boardIsVisibleForChanges` (escena
     activa, sin hoja, sin tutorial, sin carrera pendiente).
  - **La escena lo reproduce como un merge de verdad**: navega al piso, destaca a los dos, los
    funde (el vehículo ya existe: `runAssistedMerge`, `BoardScene.swift:969-1002`) y corre la
    misma cadena vuelo → revelación → piso nuevo (`presentResolution`, extraído de `resolveDrop`).
  - **La carrera T11** pasa por un merge asistido, así que **recibe su revelación**.
  - "Startup comprada" deja de mutar en el acto. Blanqueo, paquetes y visitantes son `arrival` o
    `departure`.
  - Red de seguridad persistida `run.revealedTier`: si queda un tier sin revelar, se encola su
    revelación.
  - El timeout de `boardCelebration` pasa de 8 a 14 s.
  - El orden de la cola ya deja pasar primero el popup offline y la carrera.
  - Commit atómico: el skip y el watchdog confirman exactamente una vez.
- **Bugs**:
  - Un video sin efecto ya no gasta el cooldown: `isRewardApplicable`; si deja de aplicar durante
    el video, compensa 3 min.
  - El sorteo de eventos filtra los inaplicables, y un `nil` no consume el intervalo.
  - La Milanesa lee el JSON.
  - **Corralito**: pasa a "no podés gastar 45 s". Efecto nuevo `spendingFrozen`: contratar,
    mejorar y desbloquear pasivos quedan bloqueados (el botón tiembla con el motivo), y los
    ingresos siguen. Escape por video.
  - **Contratar gratis no cuenta para la curva** (`hire(..., countsAsPurchase:)`; hoy suma los
    contadores aunque cueste 0).
  - **Un solo mutador de la frontera** `RunState.raiseFrontier`, que hoy tiene 6 escritores.
- **Contrato "lo que se muestra = lo que se aplica"** (`EffectContractTests`):
  - Enums `CaseIterable`: un efecto sin fila de contrato rompe el build.
  - Cubre multiplicadores, líneas permanentes (las dos derivaciones), premios (vista previa =
    acreditado, también cruzando un salto de frontera), descuentos compuestos, videos inaplicables,
    inmunidad, offline contra la integral y el texto de los eventos.
- **Save v6** (un solo salto de versión):
  - **RunState**: `revealedTier`, `priceRelief`, contadores `Int → Double`, buzón de paquetes,
    colchón y visitante.
  - **MetaState**: `oroPurchasedLifetime`, `lastRunMaxTier` (piso móvil), el pin del atajo,
    `wheel`, `events`, `shop`, `shopSkins`, `offers`, las pestañas desbloqueadas y estadísticas
    nuevas.
  - `MetaState.spendOro` único, que gasta primero el ORO ganado.
  - `migrateV5toV6` sólo sube la versión y fija los defaults que dependen de otros campos.
  - El ORO comprado en la v1 se reconstruye una vez desde `Transaction.all` (los consumibles
    requieren `SKIncludeConsumableInAppPurchaseHistory`, iOS 18+); si falla, 0.
- **Nunca más pisar un save ilegible**:
  - `load()` devuelve `empty | loaded | unreadable`;
  - backup crudo en `Application Support/SaveBackups/` (las últimas 10) y copia
    `save_v5_premigration.json`;
  - fase `.recovery` con la pantalla "No pudimos leer tu partida" (Reintentar o Empezar de nuevo,
    sin borrar la copia);
  - `persistNow` no escribe mientras haya recuperación pendiente.

### E2 — Economía y pacing

**E2a — Mecánicas** (detrás de knobs con default v1: con el default, el simulador reproduce la base
exacta):

- **Premios en minutos** (`RewardScale` en EconomyKit, mueve `coinReward` de logros).
  - Producción real sin boosts temporales, con piso de seguridad.
  - `rewardTier = min(tier del piso máximo histórico, frontera + 3)`.

  | Premio | Valor nuevo (minutos de producción) |
  |---|---|
  | Diario d1–d6 | 5 / 8 / 12 / 18 / 25 / 40 |
  | Diario d7 | especial, o 15 |
  | Asado | 10 |
  | Cofre completo / de reencarnación | 20 / 45 |
  | IAP de plata S / M / L | 1 h / 6 h / 24 h |
  | Starter | 4 h + skin |
  | **Juicio ganado** (Abogado) | ~20, a calibrar |
  | **Programador** | contrataciones gratis 120 s, sin contar para la curva |
  | **Obra social** (Médico) | inmunidad 30 min + corta el negativo en curso + 15 min de producción |
  | Colchón | monedas 20 min / ORO 2 / paquete |
  | Ruleta | monedas 30–60 min, ×2/×3/×5 por 10 min, ORO 1–3, paquete, cofre |

  - Las claves JSON pasan a `minutes`/`lumpMinutes`/`coinMinutes`.
  - `RewardBudgetTests` analítico: los premios sin anuncios no pasan el 12 % de la producción diaria.
- **Reintegro al fusionar**: `hire.mergeRefundCounts` (0 / 0,5 / 1 / 2), con el helper
  `refundMergeCounts` compartido por la app y el simulador. Con fusión continua, el crecimiento
  efectivo es `g^(1−r/2)`.
  - "No tanto" = **se barre en pares** (g, r): por ejemplo (1,12, 1) da ~1,058 si fusionás, y es más
    caro si acumulás.
  - Segmento en el panel de DEBUG para que el dueño lo pruebe.
- **Suavizar el salto al subir de tier — Fórmula B, el "amortiguador"** (recomendada):
  - Precio = `v1 / D`. **Al subir la frontera, `D ×= J`, así que el precio no salta.** Cada compra
    hace `D = max(1, D/ρ)` con `ρ = J^(1/K)`.
  - Con K = 24 son +4,7 % extra por compra durante 24 compras, y después el precio vuelve
    exactamente a v1: **la dificultad pasa al costo por compra**.
  - Conserva §5.2 (comprar hondo sigue sin ser atajo) y la compuerta.
  - Tests: continuidad en el salto, vuelta exacta tras K compras, `D = 1` ≡ v1 en los 37 tiers.
- **"+6 % por compra"**: se calcula como `quote(n+1)/quote(n) − 1`, así **lo mostrado es siempre lo
  aplicado** (incluye D y reintegro). Con reintegro activo se suma "fusionar lo baja X %".
- **Crítica de Marco, mecánicas** (detrás de knobs; se calibran en E2b):
  - **15 lugares por piso**: `economy.json floors[].capacity` pasa de 10 a 15 (es dato). El
    permanente de ORO suma +3 y después +2, hasta 20. Los saves viejos entran sin problema
    (la capacidad sólo crece).
  - **Pisos en marcha**: knob `floors.staffedBonus` = 0,05 por piso con todos sus lugares
    ocupados.
    - Es un multiplicador global (tap y pasivo) en `IncomeTicker` y `ModifierMath`.
    - Proyección para la UI: "Pisos en marcha 4/10 · +20 %". La luz del botón del piso en la
      botonera se pone verde.
    - Entra en `EffectContractTests`: lo mostrado es lo aplicado.
  - **Piso móvil**: `PrestigeCalculator.canReincarnate` exige además
    `run.maxTierReached ≥ meta.lastRunMaxTier`, un campo nuevo del save v6. La primera
    reencarnación conserva el requisito de hoy. `PrestigeButton` muestra la meta ("Llegá a
    {personaje}").
  - **Fusionar todo**: `TowerActions.planMergeAll(floor:)` arma la secuencia de pares, que pasa
    por el embudo `BoardChange` de E1.
    - Se anima en cadena rápida; un tier nuevo se celebra.
    - Se activa con video (`rewardedBoost`) o con ORO (tienda, tope diario).
    - Nunca toca el par de la carrera de la UBA sin elegir.

**E2b — Calibración final** (después de E4–E6, cuando existen todas las fuentes):

- **Herencia al reencarnar** (decisión del dueño: **sólo los pasivos**). En
  `PrestigeCalculator.applyReincarnation`, que es el único punto donde nace una run y lo comparten
  la app y el simulador:
  - `run.passiveUnlocked` hereda los pasivos ya comprados en runs anteriores (`meta`).
  - Saca ~15 compras de pasivo por run y hace que las primeras unidades produzcan solas desde el
    segundo uno.
  - Si con eso el principio no queda "súper fácil" en el contrato (punto 5), el knob siguiente
    son los descuentos de prestigio de la 1ª–2ª reencarnación (`prestige_unlocks.json`), no
    heredar unidades.
- **Dificultad tardía**: `escalationBands` (T8–12 ×1,45 · T13–24 ×1,6 · T25–37 ×1,7) y `g` +0,01 por
  piso desde luxury.
- **Crítica de Marco en la calibración**: el simulador modela la capacidad 15, los pisos en
  marcha (el bot llena un piso cuando el bonus paga), el piso móvil (la política ×5 sólo
  reencarna si además alcanzó la pared anterior) y "Fusionar todo" (perfil `.ads`).
  - **Las 7 líneas no se completan antes de la 5ª reencarnación** (hoy, con 4, ya están todas, que
    es lo que marcó Marco), pero sí antes de Dios: es el punto 3 del contrato.
- **ORO**:
  - las 7 líneas pasan a `baseCost` 2 (**348**) y se re-pinea `upgradeCatalogMatchesTunedValues`;
  - barrer exponente y divisor para que el ORO total al llegar a Dios sea ≈5–12k y las 7 líneas
    se completen en la 3ª–4ª reencarnación;
  - el ORO comprado puede pagar todo (decisión del dueño), así que alcanza la fórmula
    `min(saldo, comprado)` para el reset, sin ledger exacto.
- **Simulador con perfiles**:
  - `.free` (define el contrato), `.ads` (paquetes, ruleta, diario, colchón y offline ×2) y `.max`
    (más los permanentes de la tienda);
  - eventos, visitantes y consumibles con **tests de presupuesto analíticos**;
  - CLI `--profile --merge-refund --seed-fraction`;
  - el simulador usa `registerHire`, `raiseFrontier` y `refundMergeCounts` (nunca más contadores
    a mano).
- **Contrato nuevo** (reemplaza a `theOwnersTargetsAreMet`; reloj del simulador, perfil `.free`,
  política `.whenOroMultiplies(4)`, o sea ×5 por reencarnación, decisión del dueño). Va en una suite
  aparte con el reporte cacheado: el simulador completo es caro.
  Ley de diseño: `R ≈ ln(ORO_dios/ORO₁)/ln(1+m)`. Con m = 4 da ≈ 6.
  1. Dios entre 31 y 35 h activas.
  2. 4 a 6 reencarnaciones.
  3. Las 7 líneas al máximo antes del 80 % del tiempo de Dios, **y no antes de la 5ª
     reencarnación**.
  4. Primera reencarnación entre 0,75 y 1,5 h.
  5. **Cada run llega más lejos** (pared +1 tier) y es más rápida en cada tier ya visto.
  6. Rendimiento del prestigio ≥ 65 % en la run 2 en adelante.
  7. Tiempos de primera llegada por piso: urban ≤1,5 min, corporate 6–10 min, luxury 35–60 min,
     island 200–300, moon 520–680, mars 900–1100, solar 1350–1550, galaxy 1650–1850, Dios
     1900–2100.
  8. Sin reencarnar, no se llega a Dios.
  9. Guardas: el perfil `.ads` tarda ≥ 55 % de lo que tarda `.free`, y `.max` ≥ 50 %.
- **Orden de corridas**: línea de base (con `--upgrades`) → knobs en v1 (deben reproducir la base) →
  política nueva → reintegro → amortiguador → herencia → ORO → dificultad tardía → perfiles → re-pin
  de las bandas y contrato.

### E3 — UX núcleo: iPad, atajo, ficha, menú deslizable, i18n

**Ola 0, spikes** (antes de construir):

- **S1**: tamaño y fondo transparente de las hojas en iPad mini y 13", en iOS 18.6 y 26.5.
- **S2**: paginador vs el carrusel de Pintas.
- **S3**: mantener presionado sobre un `Button` (al soltar, el botón también dispara).
- **S4**: safe areas reactivas.
- **S5**: layout del tablero con 15 lugares (multitud al ~70 % del alto), la columna izquierda
  (Ruleta/Colchón/Paquetes/Boost), la botonera derecha y la barra baja, **medido en el iPhone
  SE**. Las columnas van sobre los bordes del fondo, y los personajes no deambulan debajo de
  ellas.
- **S6**: botonera del ascensor, con el scroll sincronizado y sin interceptar el gesto.
- Renombre puro `BestHire` → `QuickHireOffer` en commit propio.

**Tablero, botonera y barra** (crítica de Marco; **toda pieza respeta la identidad visual
establecida**: FisuJobs como referencia, materiales v3 —metal para el ascensor, madera,
pergamino, pills caramelo—, iconografía y paleta del juego):

- **15 lugares en 3 filas** (4 filas con el permanente). `crowdTopRatio` sube a 0,63 (medido
  por el spike S5: con 0,70 las cabezas de atrás entraban 42 pt en el display del SE) y
  `crowdBand`/`depthZ` ya están parametrizados por filas. Se re-pinean `CrowdDepthTests`, y
  `RevealLayout` no se toca.
- **Botonera del ascensor** (`UI/HUD/ElevatorPanel.swift`):
  - Es la evolución de `hud.map`: placa de metal con remaches (familia `WoodPanelBackground`
    material `.metal`).
  - **Display LED** arriba: número + nombre localizado del piso (`TowerNaming.floorName`). Al
    cambiar de piso, los dígitos "ruedan" como un indicador de ascensor real.
  - **En reposo sólo se ve el display.** Al scrollear o tocarlo, se despliega como persiana
    metálica (resorte de 0,35 s) y a los 2 s sin uso se recoge.
  - Un botón redondo por piso: bloqueado con candado; **luz verde si el piso está en marcha**;
    punto si hay algo pendiente ("lleno", paquete).
  - La luz del piso actual **interpola con la posición de la cámara**, con `board.floor`
    continuo publicado por la escena. El gesto de scroll del tablero **nunca** lo intercepta la
    botonera.
  - Tocar un botón: "ding" (sfx nuevo) + `setVisibleFloor` con el vuelo de cámara actual. El
    ícono del ascensor abre `FloorMapView` como hoy.
  - Reduce Motion: sin persiana ni rodado (fundidos).
  - AX: `hud.elevator.display`, `hud.elevator.floor.<id>` y `hud.map` (se conserva para los
    tests).
- **Barra de abajo más baja y progresiva**:
  - `GameTabBar` recibe la lista de pestañas **desbloqueadas**. Contratar va al centro, más
    grande, y la barra baja ~20 pt (se re-mide el SE: hoy son 374 de 375 pt).
  - Reglas de desbloqueo (datos):
    - Mejoras: desde el inicio;
    - Vestimenta: primera pinta;
    - Bonus: fin del núcleo del tutorial o primer cofre;
    - Tienda: 2ª sesión;
    - Menú: fin del núcleo.
  - Una pestaña nueva entra con animación + badge "¡Nuevo!" y su lección en E9.
  - El paginador del menú sólo incluye las pestañas desbloqueadas, en orden.
  - Los veteranos de la v1 tienen todo desbloqueado.

**iPad universal, sólo vertical**:

- `project.yml`: `TARGETED_DEVICE_FAMILY "1,2"` en `settings.base` **y** en el target;
  `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: Portrait` (sin "upside down");
  `INFOPLIST_KEY_UIRequiresFullScreen: YES` (claves soportadas por Xcode 26.6).
- **iOS mínimo 18** (`deploymentTarget` + `IPHONEOS_DEPLOYMENT_TARGET`):
  - se retira el camino iOS 17 de `clearNavigationBackdrop`;
  - los runtimes de prueba ya son 18.6 y 26.5;
  - se actualizan HANDOFF-v2 y la ficha.
- Se reescribe el comentario del error 90474.
- `InfoPlistContractTests` exige `[1,2]` + FullScreen + Portrait. **Se pone rojo a propósito al pasar al
  SDK 27.**
- Launch screen con color crema, para que el primer frame no sea blanco.
- **`PlayLayout`** (puro, `Scenes/PlayLayout.swift`):
  - `cell = min((W−32)/cols, 112)`, con el campo centrado y `textScale` 1,25 en iPad.
  - **En iPhone (W ≤ 440) el layout es idéntico al de hoy**, pineado con un test golden.
  - En iPad el sprite queda en 227 pt (16,5 % de la altura, como el iPhone 16 Pro) y se estira ≤1,18×.
  - Revelación con tope de 380 pt. Las `SKLabel` fijas pasan por `textScale`.
- **`PlayColumn`** (máx. 592 pt): HUD, barra de pestañas, fila del atajo, `ActiveBonusBar`, y
  tarjetas de tutorial (520). Los fondos quedan a sangre: **cero barras**.
- **`ScreenInsets`** (`@Observable`): reemplaza las dos lecturas estáticas de la safe area
  (`HUDView.swift:87-93`, `GameArtComponents.swift:1080-1086`).
- **Hojas**: se mantiene `.sheet` + `fisuSheet()` (en iOS 18+, `.presentationSizing(.page)`) con el
  contenido en una columna de 640 pt. Plan B si S1 falla: `fullScreenCover` transparente.
- **Cofre**: telón a pantalla completa, sin escalar el video.
- **Arte**:
  - Los personajes no necesitan nada nuevo gracias al tope de celda.
  - **Fondos**: los originales son de 1024 px y ya se ven estirados en iPhone. **Se regeneran los
    10 con ChatGPT a 2048 px** (decisión del dueño). Cada prompt adjunta el fondo actual como
    referencia y pide "same composition, same layout, higher detail".
    - Se comparan lado a lado; si uno sale peor, queda el viejo.
    - ⚠️ Un piso sin fondo en el manifest **no arranca la app** (HANDOFF §3): se reemplaza el PNG
      con `process_dropbox`, en una ventana corta y sin buildear en el medio.
    - Se mide memoria: 3 pisos vivos y hasta 5 en vuelo, a ~16 MB cada fondo de 2048².
    - Si la memoria aprieta, la variante de 2048 va sólo a iPad (`idiom: ipad` en el catálogo).
- **Tests**: `PlayLayoutTests` (10 tamaños, incluidas ventanas de 500×800 y 700×1000 pensando en
  el SDK 27), `RevealLayoutTests` y `IPadLayoutUITests` con el marcador `board.layout`.
- **Capturas**: `AppStoreScreenshotTests` en iPad Pro 13" (2064×2752), en en/es.

**Atajo v2**:

- `QuickHireOffer`: `affordable`, `fits`, `isPinned` y `blocker` (piso lleno gana a "no te alcanza").
- **Resolución**:
  1. el pin, si está desbloqueado; muestra su motivo y no cae a otro en silencio;
  2. el mejor que alcanza y entra;
  3. el más barato que entra, como meta de ahorro;
  4. el mejor que pagarías con lugar ("Piso lleno").
- `nil` sólo antes de cargar.
- **Pin en el save** (`meta.quickHirePinnedTypeId`, en el lote v6). Se ignora sin borrarse si el
  tipo deja de estar desbloqueado.
- **Botón**: nunca desaparece (se borra el `if let`).
  - Estados `ready` / `cantAfford` / `floorFull`: gris de la casa con el motivo en la 2ª línea;
    tiembla al tocarlo, y "Piso lleno" muestra además el toast.
  - Mismo alto y ancho mínimo (el SE está al límite).
  - Chevron "hay más" y alfiler cuando hay pin.
  - AX: valor `ready:<id>`, `…;pinned`, y una acción "Elegir a quién contratar".
- **Mantener presionado 0,45 s** (el mismo reloj que el tablero), con una bandera que anula el tap
  de soltar.
- **`QuickHirePicker`**: overlay, **no hoja**, así el juego sigue.
  - Mini `PanelCard` con cola hacia el botón; primero "Mejor disponible" y después una grilla de
    4 columnas de caras con su precio. Los de piso lleno, atenuados con "Lleno".
  - Nunca muestra tipos no desbloqueados.
  - Tocar fija; tocar el fijado o "Mejor disponible" desfija; tocar afuera cierra.
- **Tests**: `noHirableMeansNoOffer` pasa a `fullFloorKeepsAnOfferWithFloorFullBlocker`, y se suma
  `QuickHireUITests` con un fixture de piso lleno.

**Ficha de personaje**:

- Se rehace con el andamio de FisuJobs: `NavigationStack` + `panelSheet` + **`ArtCloseButton`**
  (`sheet.close`).
- **Vista grande de la pinta de 216–248 pt** (hoy ~84 pt, 2,6×), sin arte nuevo (≤1,3× del original).
  Se cambia de pinta deslizando, con chevrons a los costados y una tira de miniaturas.
- Equipar es un `ActionPill`, o la etiqueta "Puesta" (nunca un botón deshabilitado); comprar es un
  `PricePill`.
- **Despedir con `GameConfirmCard` propia**, no con la alerta de sistema. Se reusa en el reset.
- **Tests**: `CharacterSheetUITests` (sin alertas de sistema, alto ≥200 pt).

**Menú deslizable**:

- **Una sola hoja** `MenuPagerView` (`ScrollView` + `.scrollTargetBehavior(.paging)` +
  `.scrollPosition`). **Cada página conserva su `NavigationStack`, su marco y su cierre**: lo que el
  "telón" rechazó era cambiar contenido dentro de un panel fijo.
  - `menuSession` con identidad estable: cambiar de página no re-presenta la hoja.
  - Se montan la página actual ± 1. Las ocultas, sin AX y sin toques, para que `sheet.close` sea
    único.
- **Gestos**:
  - El carrusel de Pintas gana dentro de su cuadro.
  - Con un destino empujado en Menú (Ajustes, Legales) el paginador se bloquea, así funciona el
    "volver".
  - Cerrar arrastrando es ortogonal.
- **Flechas ‹ › en el renglón del título** (`PagerChevronButton`) + **6 puntos** sobre la banda de
  madera (activo = cápsula caramelo). Sin vuelta en los extremos.
- **Anuncios**: el intersticial se pide **una vez al cerrar la sesión de menú**, no por página.
  `GameState+Menu`: `menuDidOpen` / `menuPageChanged` / `menuDidClose`.
- **Tests**: `MenuPagerUITests`, y `testCadaTabAbreSuPantallaYSeCierra` tiene que seguir verde sin
  cambios.

**Compartir** (decisión del dueño: recablear y potenciar):

- Hoy nada llama a `offerShareCard` desde julio. Por eso el logro `ach_share_1` es imposible, el
  bonus viral (`viral.json`) no corre y Estadísticas dice 0 compartidos.
- Se ofrece compartir en los **momentos virales**: personaje nuevo (al cerrar la revelación),
  piso nuevo, reencarnación y llegada a Dios. Va con la tarjeta vertical existente
  (`ShareCardView`, "Pasé de Fisura a CEO"), en es y en.
- Compartir da un premio chico (minutos de producción, una vez por momento). Vuelven el logro y
  el bonus viral (+0,5 % por compartida, tope 20).
- Se ofrece como botón en el cierre de la celebración, **nunca como popup que interrumpe**. El
  tutorial lo presenta la primera vez.

**Bugs que dejó anotados la sesión de preparación**:

- **El splash nunca muestra el logo**: `SplashView` se dibuja antes de `UIArt.configure`.
- **Sus tips están en castellano con `Text(verbatim:)`**: el jugador en inglés los ve en
  castellano. Pasan al catálogo.

**i18n**:

- **`IAPCopy`**: claves `iap.<productID>.name` y `.desc`, con `displayName` de respaldo.
- ATT en inglés en `InfoPlist.xcstrings`.
- **`LocalizationCompletenessTests`**:
  - toda clave con es + en `translated` y los mismos placeholders;
  - **familias dinámicas contra el contenido**: tiers, IAP, skins, eventos, visitantes, etc.;
  - `InfoPlist` completo.
- `LocalizationLayoutUITests` en el SE con el idioma en español.
- Checklist de App Store Connect en E10.

### E4 — Visitantes + Eventos v2 + Álbum de especiales

- **Motor puro** (`EconomyKit/Visitors/`):
  - `VisitorsConfig` (definición, guiones por tipo y condiciones).
  - `VisitorScheduler.advance/pickNext`: cuenta **sólo juego activo** (delta con clamp de 2 s);
    primera visita a los 600 s y después cada 240–360 s. Anti-repetición, topes diarios.
  - **Carril aparte para el Vendedor Ambulante, cada ~180 s**.
  - `VisitPlanner.offer/revalidate/effects`: la oferta se concreta **al llegar**, así el globo y
    el popup dicen lo mismo, y se revalida al aceptar.
  - Invariantes pineadas por test: nunca se lleva la última unidad ni deja menos de 2; el arresto
    siempre indemniza más de lo que cuesta reponer; toda visita es de suma positiva o neutra.
- **Paciencia de 30 s sólo en momento calmo**; con el popup abierto se congela. Si se cierra la app
  con alguien en escena, se pierde sin penalidad. Fixture `--uitest-visitor=<scriptId>`.
- **Escena**:
  - Colaborador `Scenes/StageController.swift`. `BoardScene` ya tiene 1828 líneas y sus miembros
    son `private`.
  - Nodos `VisitorNode`, `SpeechBubbleNode` y `PickupNode`; globo vectorial único en
    `UI/Art/BubbleGeometry.swift`, compartido entre SwiftUI y SpriteKit.
  - Entrada desde el borde a 90 pt/s con bamboleo, pop del globo y pulso en espera. Con Reduce
    Motion, fundido.
  - Escenario en x ∈ [28 %, 72 %], para no quedar bajo los botones flotantes.
- **UI**:
  - `VisitorPopupView`: `PanelCard`, retrato animado (`LoopingPortraitView`, que generaliza
    `ChestCinematicPlayer`), 1–3 `ActionPill` y `ArtCloseButton`. El botón de video va separado
    del de aceptar (política de clics accidentales).
  - `StageChips` bajo el HUD, para el visitante y la oferta: objetivo de toque determinista y
    accesible. Ruleta, Colchón, Paquetes y Boost viven en la columna lateral (E7).
  - Nuevos kinds en `CelebrationQueue`: `visitorEncounter`, `packageOpening`, `cinematic` y
    `offer`. Se elimina `eventBanner`.
- **Sacar los especiales del tablero** (pedido del dueño):
  - Se borran `renderAnchoredSpecials`, el long-press de especiales, `visibleFloorSpecials` y
    `presentSpecialInfo` (`BoardScene.swift:1240-1288`, `GameState+Tower.swift:72-93`).
  - `meta.specialAnchors` queda sólo para decodificar saves viejos. Con eso deja de importar el
    bug de "los especiales del día 7 no se dibujan".
- **Álbum de especiales**:
  - Quinta tarjeta de ancho completo en `MenuView` (`menu.card.specials`), sin tocar las cuatro
    actuales.
  - Grilla de `GameCard`: los conseguidos en color con su pasivo (`EffectDescriptor`); los que
    faltan en silueta, con una pista armada con datos (piso y prestigio) sin spoilear.
  - Tocar uno reabre su ficha más su frase.
- **Eventos v2**:
  - `events.json` pasa a schema 2: **efectos compuestos**, `polarity`, `presenters[]` y
    `escapes[]` (`video` | `fee` | `free`).
  - El motor se muda a EconomyKit (`EventScheduler`).
  - **El efecto se aplica cuando el presentador llega a escena**; si hay una hoja abierta, espera a
    un momento calmo.
  - Los chips de evento salen de los modifiers persistidos (sobreviven a un relanzamiento) y llevan
    la **cara del presentador** (`ActiveBonus.Icon.face`). `ActiveBonusBar` acepta toques en esos
    chips, y tocar uno abre el popup con la frase y los escapes.
  - **Obra social del Médico** = `eventImmunity` 1800 s: filtra los negativos, no los mixtos.
    Además, al elegirla corta el negativo en curso y paga 15 min de producción.
  - Se borran `EventBannerView`, `activeEvent`, `announcedEventID` y `eventBannerIsVisible`.
- **Efectos de escena por código**:
  - Apagón: velo oscuro, velitas al tocar, y el multiplicador sube de ~0,07 por velita.
  - Campeones: baile de todos + confeti nuevo en `ParticlePool`.
  - Liquidación: `HireQuote.listCost` tachado en FisuJobs y en el atajo, con piso de apilado de
    descuentos.
- **Reacciones de campo: NO se portan.** `feat/reacciones-de-campo` quedó **descartada por el
  dueño** el 2026-10-06 en la sesión de preparación de `version-2`; sigue en GitHub sin tocar. Las
  reacciones del tablero a los eventos son las de código nuevo de este plan: baile de Campeones,
  velitas del Apagón y emote corto del personaje al llegar el presentador.
- **Guiones y frases**: catálogo en el **Anexo A** (24 guiones + 18 frases de eventos), para
  aprobar.

### E5 — Paquete de la Aduana + El Colchón + Ruleta

- **Paquete** (`packages.json`, `PackageScheduler`, `PackageRoller`):
  - 1 cada 120 s de juego activo, hasta 2 en espera; sin acumular offline. Los paquetes regalados
    pueden pasar el tope.
  - **El sorteo es al tocar**: candidatos = tipos contratables con lugar.
  - **Ventana de los 4 tiers más altos elegibles** con pesos 1, r, r², r³ (r = 2): el tope sale
    el 6,7 %. El permanente "mejor proveedor" baja r a 1,8 / 1,6 / 1,4.
  - Sin lugar: cartel **LLENO** y el paquete no se gasta.
  - Coloca con `placeGrantedUnit` generalizado, que **no toca el contador de contrataciones**.
  - Apertura procedural: sacudida, tapa que vuela, partículas y resorte. Un tipo nunca visto pasa
    por la revelación de E1.
- **El Colchón** (`treasures.json`, familia aparte del cofre):
  - Aparece cada ~8 min de juego activo (decisión del dueño). Se ve como `PickupNode` en el borde
    del tablero y como botón de la columna lateral, con el badge "!".
  - **Espera hasta que lo abras**; no se acumula más de 1.
  - Se abre **sólo con video** (`RewardedPlacement.treasure`); "otro colchón" con un 2º video.
  - Tabla de premios: plata en minutos de producción, paquete u ORO.
  - ⚠️ Con esa frecuencia, el valor esperado se calibra en E2b.
- **Ruleta** (`wheel.json`, `WheelRoller`, `UI/Wheel/WheelView`):
  - 10 segmentos con pesos que suman 100 y son la tabla visible. Si el cofre no tiene nada que
    dar, su peso pasa a plata, y **la tabla mostrada es la efectiva**.
  - El premio se aplica **antes** de animar, así sobrevive a que maten la app.
  - Giro con `Canvas` y ease-out de ~3,8 s, con ticks hápticos.
  - **"Repetir premio" = un 2º video que vuelve a dar el mismo premio** (no es otro giro).
  - 6 giros por video por día; giro extra con ORO a **12 ORO**, tope 6 por día (apagado en Bélgica y
    Australia).
  - Vive en Regalos y en la columna lateral; la presenta el Conductor de TV.
  - Reset por día calendario (como el diario).

### E6 — Tienda de ORO + IAP + skins

- **UI**: `StoreView` gana un selector **"Comprar ORO" / "Gastar ORO"** (no hay séptima pestaña).
  `OroShopView` con estantes Boosts, Atajos, Permanentes, Cosméticos y Suerte, en filas
  `GameCard` + `PricePill`. Catálogo en `oro_shop.json` con niveles, límites y desbloqueos.
- **Precios** (escala aprobada: 1 h de producción ≈ 90 ORO; los números finales salen del
  simulador). Los consumibles de poder tienen tope diario, porque tarde en la partida un jugador
  gratis tiene miles de ORO:

  | Ítem | ORO | Límite |
  |---|---:|---|
  | ×2 ingresos 30 min | 30 | 3/día |
  | ×3 ingresos 30 min | 60 | 2/día |
  | Lluvia de paquetes 60 s | 15 | 5/día |
  | Auto-tap 10 min | 25 | 3/día |
  | Salto de 1 h | 90 | 2/día, ×1,25 por compra |
  | Salto de 4 h | 320 | 1/día |
  | Offline ×3 | 120 | 1 pendiente |
  | Diario ×3 | 40 | 1/día |
  | Saltear cooldowns | 25 | — |
  | +3 / +2 lugares por piso (→ 18 → 20) | 600 / 1.500 | 2 niveles |
  | Fusionar todo (piso actual) | 20 | 5/día |
  | Mejor proveedor N1/N2/N3 | 150 / 400 / 1.000 | permanente |
  | +1/+2/+3 giros diarios | 120 / 300 / 750 | permanente |
  | Efecto de skin | 150 c/u | — |
  | Familia dibujada (los 43) | 450 c/u | — |
  | Cofre de pintas | 45 | probabilidades visibles |
  | Giro extra de ruleta | 12 | 6/día |

  El gasto de ORO no toca `oroEarnedLifetime` (no se nerfea el multiplicador global). Un solo
  `MetaState.spendOro`.
- **`extraSlots`**: base 15 (3 filas) por dato, y el permanente lleva a 20 (4 filas).
  - `TowerState.Floor` nace con `def.capacity + meta.shop.extraSlots`.
  - Pasan a `slots.count`: `TowerReconciler`, `PacingSimulator`, `FloorMapEntry`,
    `BoardScene.layoutBoard` y `floorOccupancy`.
  - `boardRows` = ⌈lugares/5⌉. Se re-pinea `CrowdDepthTests` y se mide en el SE (spike S5).
- **Skins**:
  - `skins.json` v2 con `oroPrice`, `family`, `shaderId` y `textureAtlas`. Comprar una familia la
    da para los 43, como pasa con oro y diamante.
  - **Shaders**: `Scenes/Shaders/SkinShaders.swift`, con un `SKShader` compartido por efecto y
    variación por `SKAttributeValue`. Con Reduce Motion o en Bajo consumo se detienen
    (`u_speed = 0`). Cuesta hasta +10 draws por piso (se mide).
  - **Gate: galería de muestras de los 8 efectos para que el dueño apruebe.**
  - **Familias**: atlas propio por familia (`fam_<familia>.atlas`), para no mover las páginas
    actuales. Suman **~44 MB**; On-Demand Resources queda como mejora futura.
- **IAP**:
  - **Packs de ORO: 160 / 550 / 1.400 por USD 1,99 / 4,99 / 9,99** (aprobado). Los IDs siguen
    iguales; el monto vive en `products.json` (`oroAmount`). Los compradores de la v1 conservan su
    saldo. Se actualizan la descripción en App Store Connect y `iap-appstore-connect.md`.
  - **Ofertas** en `offers.json` + `OffersEngine` (aprobadas):

    | Oferta | Cuándo | Precio | Contenido |
    |---|---|---|---|
    | `offer_bienvenida` | 2º día, una vez | USD 0,99 | 120 ORO + 2 h de producción + 1 cofre de pintas |
    | `offer_renacer` | al reencarnar | USD 2,99 | 300 ORO + 4 h + ×3 por 30 min |
    | `offer_mudanza` | piso nuevo | USD 4,99 | 500 ORO + 8 h + 3 Paquetes |

    - Reloj real de 24 h que no se reinicia al volver a dispararse; cooldown de 3 días.
    - Son consumibles con un bundle de `RewardSpec`. Nunca se rechaza una compra ya pagada fuera
      de la ventana.
    - Chip `hud.offer.chip` + `OfferSheet`. Nunca durante el tutorial.
  - **Bélgica y Australia** (decisión del dueño): `restrictedStorefronts` en la config remota
    apaga el giro extra y el cofre por ORO según `Storefront.current?.countryCode`.
  - **Nombres en español**: clave `iap.<productID>.name/.desc` en `Localizable`, que cae a
    `displayName`. Reemplaza los `Text(verbatim: product.displayName)` de `StoreView.swift`.
- **Probabilidades**: `OddsDisclosureView` compartida por la ruleta, el cofre por ORO y el
  Colchón (Apple 3.1.1).

### E7 — Anuncios v2

- **Protocolo**: `showRewardedInterstitial()` y `showAppOpen()`, más sus `isReady`/`preload`. La
  vida del inventario es de 55 min, y de 3 h 30 para app open.
- **Unidades nuevas**:
  - `rewardedWheel`, `rewardedTreasure`, `rewardedVisitor` y `rewardedDaily`, con fallback a
    `rewardedGifts`;
  - `rewardedInterstitial` (la unidad existente `…/1615619906`);
  - `appOpen`, nueva.
  - Cada unidad es un **momento** (AdMob reporta por unidad). El switch exhaustivo de
    `rewarded(for:)` impide un placement sin unidad.
- **Config remota** `AdsRemoteConfig`:
  - `https://adergames-site.vercel.app/config/ads.json`, con IDs, cadencia, alternancia, app
    open, interruptores de apagado y `restrictedStorefronts`.
  - Sólo HTTPS. **Cada ID se valida contra el publisher propio**; si uno no cumple, se descarta el
    archivo entero.
  - Caché + respaldo del bundle. No bloquea el arranque y no manda datos del jugador.
- **Cortes naturales**:
  - `enum NaturalBreak` (`sheetClosed`, `celebrationsDrained`, `reincarnation`,
    `offlinePopupDismissed`, `returnFromBackground`) reemplaza a `showInterstitialIfAppropriate`.
  - `lastFullScreenAt` es único entre formatos, y la alternancia común/bonificado queda
    persistida.
  - Nunca dos formatos en el mismo corte, nunca en el tutorial, nunca con una hoja o celebración,
    y gracia de 90 s después de un bonificado.
- **Pausa publicitaria**: `RewardedInterstitialIntroView` con cuenta regresiva de 5 s y **"No,
  gracias" visible**; rechazarla no castiga. Premio rotativo (decisión del dueño).
- **App open**: sólo `returnFromBackground`, con ≥180 s afuera, 1 cada 20 min y desde la 2ª sesión.
- **remove_ads** (y starter): la llamada `setRemovedAds` ya está cableada en `version-2`.
  **Corta los tres formatos forzados** (intersticial, pausa publicitaria y app open) y deja los
  videos opt-in. Decisión del dueño.
- **Copia**: `terms.md` es/en y el espejo del sitio dicen hoy que remove_ads saca los videos con
  premio. Se corrige.
- **UMP**: fila "Opciones de privacidad" en Ajustes (`settings.privacy.options`), visible si
  `AdsConsent.showsPrivacyOptions`.
- **Columna lateral** (decisión del dueño): Ruleta, El Colchón, Paquetes y Boost, con badge, reloj y
  latido, en estilo FisuJobs.
- **Mediación**:
  - Adaptadores SPM de AppLovin, Unity, Mintegral y Meta en `project.yml`. **Verificar URLs y
    vigencia al implementar.**
  - SKAdNetwork IDs en `Info.plist`; Ad Inspector en el panel de debug. Si una red no soporta app
    open o la pausa publicitaria, ese formato queda sólo en AdMob.
  - Alinear `PrivacyInfo.xcprivacy` y la sección App Privacy con lo que declaren los SDK.
- **Mapa de ubicaciones** (unidad entre paréntesis):
  - **Videos opt-in:**
    - Regalos ×5 (gifts);
    - offline ×2 (offlineX2);
    - otro cofre (chestExtra);
    - boost sin esperar y **Fusionar todo** (boost);
    - ruleta giro y repetir (wheel);
    - colchón, otro colchón y lluvia de paquetes (treasure);
    - visitante ×2, multa perdonada, boosts del Vendedor, ×2 del reto y escapes de eventos
      (visitor);
    - diario ×2 y carrera ×2 (daily).
  - **Formatos forzados:** intersticial y pausa publicitaria alternados (interstitial /
    rewardedInterstitial); app open (appOpen).

### E8 — Arte y animación

Ver §5. Lo que suma el diseño:

- **Biblia de los 8 visitantes nuevos**: Anexo B, con descriptor en inglés ASCII listo para el
  prompt, paleta y 3 poses.
- **Proyecto `projects/fisu-evolution-v2/`** (no se mezcla con los 335 originales):
  - `references/fisura.png` + `references/chars/<tipo>.png`;
  - motor `chat-gpt`, salida `game-asset`, `reference_threshold: 4`;
  - **piloto de 5 imágenes** antes del lote. Si hay deriva de estilo, las 129 skins van con
    `gemini`.
- **`process_dropbox.py`** gana las categorías `npc` (→ `npcs.atlas`) y `skinfam`
  (→ `fam_<familia>.atlas`).
- **Arte calado ya publicado** (lo encontró la sesión de preparación):
  - `estanciero_estelar__tropero` tiene 6,4 % de agujeros y `senior_doctor` 1,2 %.
  - Se arregla eligiendo otro recorte con `scripts/elegir_recorte.py`, mirando el PNG.
  - `test_assets_integrados` queda en verde.
- **Higgsfield** (piloto de 2 loops para medir el costo real primero):

  | Pieza | Modelo | Créditos |
  |---|---|---|
  | 18 loops de retrato (cuadro inicial = final) | Kling v3.0 | ≈ 170 |
  | Reencarnación | Seedance 2.5 | ≈ 80 |
  | Arresto | Seedance 2.5 | ≈ 60 |
  | Llegada a Dios | Seedance 2.5 | ≈ 150 |
  | Reserva | | ≈ 90 |
  | **Total** | | **≈ 550 ≤ 600** |

- **Pipeline de video**: `scripts/video_assets.py` reusa `chest_video_frames.py`. **El color de
  key se vuelve a medir en cada master.**
  - Retratos: HEVC con alfa de 512² en `Resources/Loops/`.
  - Cinemáticas: 720×1280 en `Resources/Cinematics/`.
  - Contrato `loops_manifest.json` pineado por tests en Swift y en Python.
- **Cuándo se reproducen**: la de reencarnación antes del cofre; la de arresto las 2 primeras veces;
  la de Dios una vez por cuenta (`seenCinematics`). Un solo `AVPlayer` activo a la vez.
- **Sonido**: `sfx_wheel_tick` y `sfx_blackout`, sintetizados con el script del tag
  (`git show v1.0.0-build4:Tools/audio-synth/generate_audio.py`).

### E9 — Tutorial v2 + Tour de novedades + Ajustes

- **Motor**:
  - `.tutorialTip` pasa a no tener timeout y deja de ser salteable: se corta el acople
    `isSkippable = timeout != nil` (`CelebrationQueue.swift:64-81`) y el toque al tablero ya no
    saltea.
  - **Se borra el botón "Saltar"** (`TutorialOverlay.swift:503-518`).
  - Un solo renderer (`TutorialOverlay` absorbe las lecciones) y un modelo
    `TutorialStep { explain | action(signal) }` con superficie tablero, hoja o embebido.
  - **Explicar**: "Entendido" se habilita a los **5 s fijos**, con un relleno de progreso en el
    botón. El candado vive en el estado y se cuenta con el tick, no con un `Timer`.
  - **Acción**: avanza sólo con la señal (`tapped`, `hired`, `hiredViaQuickHire`, `pickerOpened`,
    `pinned`, `merged`, `screenOpened`, `pagerMoved`, `mapOpened`, `floorChanged`…).
  - Dos manos: `TapHereHand` y una nueva `SwipeHand`.
  - **`TutorialSheetCoach`** adentro de cada página del menú: hoy una hoja no le pasa el ancla a la
    pantalla que la presenta.
  - **Ritmo**: una lección por vez, 20 s entre lecciones, y sólo nace sin toques al tablero en el
    último segundo, para no comerse taps.
  - **Watchdog** (aprobado): un paso de acción trabado 3 min se libera, con log y sin premio.
- **Currículo**:
  - **Núcleo** (secuencial, con scrim): `core.tap` → `core.hire` → `core.merge` → `core.finish`, que
    entrega el cofre de bienvenida.
  - **Lecciones**, cada una cuando su función aparece:
    - atajo: tocar → mantener presionado → fijar → desfijar → botón bloqueado;
    - pasivo; multiplicadores; organigrama; ascensor; deslizar pisos; piso lleno;
    - offline ×2 (en el popup); boosts; regalos; pintas; logros; cofres;
    - prestigio y ORO; carrera de la UBA (en su popup); tienda;
    - deslizar el menú; ficha del personaje (mantener presionado);
    - Paquete de la Aduana, El Colchón, Ruleta, visitante, chip de evento y Álbum;
    - **crítica de Marco**: botonera del ascensor (display, desplegar, tocar un piso, mapa);
      Fusionar todo; Pisos en marcha (la luz verde y el +%); piso móvil (qué hace falta para
      reencarnar); cada **pestaña nueva** cuando aparece con "¡Nuevo!".
  - **Regla de cobertura**: **toda mecánica del juego tiene su lección** (pedido explícito del
    dueño: tutorial high-end que explique absolutamente todo).
    - `TutorialCoverageTests` cruza un registro de mecánicas (cada feature declara su
      `TutorialLesson` y su ancla) contra el currículo. Una mecánica sin lección no compila o
      pone el test en rojo.
  - Los borradores de texto en español ya están escritos en el diseño. **Cada épica nueva publica
    su ancla de tutorial** (`TutorialTarget`: `.sideWheel`, `.sideMattress`, `.sidePackages`,
    `.sideBoost`, `.visitor`, `.eventChip`, `.albumCard`, `.oroShop`, `.pickerFace`…) y declara su
    lección.
- **Primeras veces que son interactivas** (visitante, Paquete, offline, carrera): las aloja la
  propia celebración con un `TutorialInlineCard` (mismo candado de 5 s).
- **Relojes**: los que tienen paciencia (visitante, colchón) se congelan mientras un paso bloquea.
  Durante el núcleo no nace ningún paquete ni visitante.
- **Persistencia**: `UserDefaults` (`tutorial.v2.completed`, `tutorial.v2.version`).
  `TutorialMigration` (función pura) mapea las banderas de la v1. **Los veteranos (hay save y no
  hay `v2.version`) reciben el Tour**: intro, atajo con pin, deslizar el menú, ficha nueva, columna
  lateral, visitantes y eventos, Álbum y Ajustes. Lo que depende de eventos se enseña en su primera
  ocurrencia.
- **"Ver tutorial de nuevo"** (`settings.tutorial.replay`) y **"Ver novedades de la 2.0"**:
  - modo demostración: señala y explica con el candado de 5 s, sin exigir acciones, porque el
    estado es arbitrario;
  - no toca el save y no vuelve a dar el cofre de bienvenida (`welcomeChestGiven`);
  - en el **repaso** se puede salir ("Terminar repaso", aprobado); en el primer recorrido y en el
    Tour, no.
- **Ajustes**:
  - **"Opciones de privacidad"** (UMP), visible sólo si `AdsConsent.showsPrivacyOptions`.
  - **Zona de peligro** al final: cinta y tarjeta rosa, con un `ActionPill` "Resetear partida" que
    abre `ResetGameFlowView`. **Tres pasos**:
    1. Resumen con números: qué se borra y qué se conserva. Incluye la cuenta del ORO, por ejemplo
       "tenés 1.250: comprados 500, ganados 750 → conservás 500", y una casilla "entiendo que no
       se puede deshacer".
    2. Escribir **RESETEAR** / **RESET**.
    3. **Mantener presionado 3 s** con un anillo de progreso.
  - Ningún botón se deshabilita: tiemblan.
- **Reset técnico**:
  - `ResetPlan` puro: lo que se muestra es exactamente lo que se ejecuta.
  - Contador nuevo **`meta.oroPurchasedLifetime`**. Hoy no existe: `creditStorePurchase` sólo suma a
    `meta.oro`.
  - Partida nueva + `removedAds`, `ownedSkins` y **`creditedPurchases` intactos** (si no, una
    transacción re-entregada se acreditaría dos veces) + `oro = min(saldo, comprado)`.
  - Backup del save antes de sobrescribir.
  - `StoreManager.repushEntitlements()` público: hoy `applyStoreEntitlements` no hace nada si el
    estado no cambió.
  - Se borran las banderas de tutorial y se conservan las de dispositivo (idioma, audio, UMP,
    ATT). Arranca el núcleo y vuelve el cofre de bienvenida.
  - ⚠️ Antes de prender CloudKit hace falta un `resetEpoch`. Si no, el save viejo de la nube
    "gana" y resucita la partida.
- **Tests**:
  - `TutorialLockTests`: bloqueado a 4,9 s y libre a 5,0 s; el toque al tablero no saltea.
  - `TutorialCurriculumTests`: claves es + en y anclas existentes.
  - `TutorialMigrationTests`, `ResetPlanTests` (matriz de ORO) y `GameStateResetTests` (no hay doble
    acreditación).
  - UI: el núcleo real, o un fixture con `--uitest-tutorial-lock=0.3`; un `TutorialLockUITests` con
    el candado real; y `SettingsResetUITests` (escribir RESET + presionar 3,5 s).

### E10 — Release 2.0

- **Doc de configuración** `Distribution/setup-v2-asc-admob-mediacion.md` (entregable del
  ítem 18):
  1. **App Store Connect**:
     - versión 2.0.0 con novedades en es y en;
     - **tabla de IAP**: los nuevos `offer_bienvenida/renacer/mudanza`; los packs de ORO
       reescalados con su descripción nueva; los 11 existentes revisados. Cada uno con nombre
       ≤ 30 y descripción ≤ 45 en **es-MX, es-ES y en-US**, precio, captura de revisión y "listo
       para enviar" junto al build;
     - ficha en en-US, es-MX y es-ES;
     - **capturas de iPhone 6.9" y de iPad 13"** por idioma;
     - **cuestionario de edad**: loot boxes sí, apuesta simulada no;
     - **App Privacy**, con los datos de AdMob y de las 4 redes;
     - **notas a App Review**: todos los lugares de anuncios (incluido el cierre de menús y el app
       open), dónde se ven las probabilidades, las ofertas de 24 h y cómo probar;
     - disponibilidad en Mac ("Designed for iPad") y visionOS: por defecto se deshabilita lo que
       no se probó.
  2. **AdMob**:
     - las unidades nuevas (`rewardedWheel`, `rewardedTreasure`, `rewardedVisitor`,
       `rewardedDaily`, `appOpen`), más la existente `…/1615619906` para la pausa publicitaria;
     - formatos de imagen y video, y piso de eCPM optimizado;
     - **grupos de mediación** por formato con las 4 redes por bidding;
     - mensajes de UMP (GDPR) e IDFA;
     - bloqueo de la categoría de anunciantes de juego de azar;
     - dispositivos de prueba y Ad Inspector.
  3. **Por red** (AppLovin, Unity Ads, Mintegral, Meta): cuenta, registro de la app, placements,
     claves para AdMob, líneas de `app-ads.txt` y SKAdNetwork IDs. Cada dato se verifica en el
     panel de la red.
  4. **Sitio `adergames-site`**:
     - `public/app-ads.txt`;
     - `content/legal.ts` (política con las redes);
     - Términos corregidos (lo que saca remove_ads);
     - **`public/config/ads.json`** (config remota).
  5. A futuro, fuera de alcance: automatizar este doc con un script de Selenium.
- **Ítem 19 (IAP en inglés), checklist para el dueño en App Store Connect**:
  - En los 11 productos existentes, verificar y completar las localizaciones **Español (México)**
    y **Español (España)**. Los textos están en `Distribution/iap-appstore-connect.md`; hay que
    acortar los 5 que pasan de 45 caracteres.
  - Mandarlas a revisión junto al build. Lo mismo para los productos nuevos.
  - Igual, desde la 2.0 la app muestra los nombres desde su propio catálogo (`IAPCopy`), así que ya
    no depende de App Store Connect.
- **Archive**:
  - build ≥ 5 (sube si ya se quemó) y `DerivedData` nuevo;
  - las verificaciones de §8;
  - ⚠️ `ExportOptions.plist` **sube directo**.
- **TestFlight**: 1–2 días de playtest del dueño, con pacing real, anuncios reales por unidad,
  compras en sandbox e iPad real si lo hay.
- **Docs**:
  - `HANDOFF.md`: §4, §5 (decisiones nuevas, incluida la que reemplaza §5.5 y §5.7), §7 y §9;
  - `HANDOFF-v2.md`: iPad, iOS 18 y "37 tiers";
  - `balance-log.md`, con la calibración.

### E11 — Notificaciones (pedido del dueño, 2026-10-06)

**Hoy**: `NotificationsManager` programa un recordatorio local diario a las 19:00 y está **apagado
por defecto**. El permiso se pide al prender el toggle de Ajustes (`settings.notifications`). La
2.0 lo da vuelta:

- **Prendidas por defecto y desactivables.**
  - `settings.notificationsEnabled` pasa a valer `true` cuando la clave no existe. Un veterano que
    las apagó en la v1 (clave en `false`) las sigue teniendo apagadas.
  - El permiso de iOS va en dos pasos:
    1. **provisional** (`.provisional`) al terminar el núcleo del tutorial (`core.finish`): sin
       diálogo, los avisos llegan en silencio al Centro de notificaciones. Así quedan prendidas
       desde el día 1 sin interrumpir;
    2. **completo** (`.alert`, `.sound`, `.badge`) con una tarjeta previa en estilo FisuJobs, en la
       primera vuelta con popup offline: "¿Te aviso cuando la caja fuerte se llene?". "Sí, avisame"
       abre el diálogo del sistema. "Ahora no" deja el provisional y la tarjeta se ofrece una sola
       vez más, 3 días después.
  - Si iOS las tiene denegadas, la fila de Ajustes lo dice y ofrece un `ActionPill` "Abrir Ajustes"
    (`UIApplication.openNotificationSettingsURLString`), sin alertas del sistema.
- **Locales, no remotas.** Todo lo que se avisa se calcula en el dispositivo. El push remoto (APNs)
  necesita servidor, entitlement y token, y cambia App Privacy: queda fuera de la 2.0 salvo que el
  dueño lo pida (🔒).
- **Catálogo data-driven**: `notifications.json` + `NotificationsConfig` con validador, y los textos
  `notif.<id>.title` / `.body` en es + en, con el humor de la casa.

  | id | Cuándo | Nace en |
  |---|---|---|
  | `vault_full` | la caja fuerte se llenó: al irse, ahora + el tope offline (`offlineCapHours`) | E11 |
  | `daily_ready` | el premio diario está sin cobrar: a las 19:00 de ese día (reemplaza al recordatorio fijo) | E11 |
  | `comeback` | 72 h sin entrar, una sola vez por ausencia | E11 |
  | `wheel_ready` | giros nuevos de la ruleta | E5 |

  **Cada épica que suma un motivo para volver declara su notificación** en el catálogo, igual que
  declara su lección de tutorial.
- **Reglas**, en `NotificationPlanner` (puro, en EconomyKit, recibe todo ya resuelto):
  - se programa todo al irse (`.background`, en el sellado de E1 T8) y se borra todo al volver
    (`.active`);
  - horario silencioso de 22:00 a 09:00 local: lo que cae adentro se corre a las 09:00;
  - ≥ 4 h entre dos avisos y tope de 3 por ausencia;
  - **nunca anuncios, ofertas ni precios** (guía 4.5.4 de App Store): sólo el estado del juego;
  - nada bajo `--uitest*` ni XCTest (ni el permiso ni la programación), salvo que el test lo pida.
- **Ajustes**:
  - el toggle maestro "Notificaciones", prendido por defecto, y uno por tipo
    (`settings.notifications.<id>`);
  - apagar el maestro borra todo lo pendiente;
  - es preferencia de dispositivo: sobrevive al "Resetear partida" de E9.
- **Tutorial**: la tarjeta previa es la lección `notifications.permission`, registrada en
  `TutorialCoverageTests` (E9). El Tour de los veteranos suma un paso en Ajustes.
- **Tests**:
  - `NotificationPlannerTests`: tope offline, horario silencioso, espaciado, tope por ausencia,
    tipo apagado y maestro apagado (no programa nada);
  - `NotificationsManagerTests`: prendido por defecto sin clave, el `false` de la v1 respetado,
    provisional y denegado;
  - la familia `notif.*` en `LocalizationCompletenessTests`;
  - un UI test de los toggles de Ajustes.
- **E10**: App Privacy no cambia (lo local no junta datos) y no hace falta el entitlement
  `aps-environment`. Las notas a App Review dicen que son locales, opcionales y sin promociones.
- **Orden**: el plan y el núcleo (catálogo, planner, manager, Ajustes y tarjeta) van en paralelo con
  E1; el cableado al ciclo de vida, después de E1 T8.

### Anexo A — Guiones de visitantes y frases de eventos (propuesta para aprobar)

`S(n)` = n segundos de producción real. "×2 video" = el premio se duplica mirando un video.
Las claves de texto van por convención (`visit.<guion>.bubble/.ask/.btn.<opción>`) y un test
exige es + en en todas.

| Visitante | Guion | Efecto | Frase (globo) |
|---|---|---|---|
| Comisario | arresto | Se lleva un duplicado de tier bajo. Fianza = 1× su precio; si lo dejás ir, cobrás 2×. | "¡Alto! Su {empleado} queda demorado por {motivo absurdo según el tier}." (ej.: Trapito → "cuidar autos sin habilitación"; Cartonero → "carrito en doble fila") |
| Comisario | multa | Multa S(180), tope 8 % de la caja. Pagarla da un sello (×1,25 por 3 min); un video la perdona. Si lo ignorás, se va sin cobrar. | "Exceso de productividad en vía pública. Tiene 24 horas para quejarse… o sea, ahora." |
| Demonio de ARCA | paraíso fiscal (tu ejemplo) | Arresto de tu tier alto con duplicado: fianza, o te lo llevás compensado. | "Su Rey del Ladrillo declaró un monoambiente y tiene tres islas en el Caribe. Queda detenido." |
| Demonio de ARCA | factura | Contratar −30 % por 90 s. | "Con factura A todo sale más barato. Firmá acá, acá y acá." |
| Influencer | novio (tu ejemplo) | Se lleva un empleado "de novio" y deja un canje (plata + paquete). | "¡Me puse de novio con tu Cartonero! Nos vamos a Tulum. Te dejo un canje." |
| Influencer | código | Contratar −30 % por 60 s; ×2 video. | "¡Chicos! Con el código FISURA tienen 30 % off en TODO. Link en la bio." |
| Sindicalista | aumento | Ingresos ×1,5 por 10 min; ×2 video. | "¡Paritaria cerrada! Tus muchachos cobran un plus. Yo me llevo el aplauso." |
| Sindicalista | asado | 1 paquete + S(900); ×2 video. | "Hoy hay asado en el sindicato. Traje un paquetito para el barrio." |
| Turista Gringo | compra | Compra tu tier más alto con ≥2 unidades (tope: frontera − 2) por 4× su precio. | "¡Wow, very authentic! Pago cash por ese empleado. Todo es barato acá, che." |
| Turista Gringo | propina | S(900); ×2 video. | "¡Propina! En mi país es el 20 por ciento. Acá es más que un sueldo." |
| Puntero Político | acto | Se lleva 3 del tier más bajo y deja un bolsón (1 paquete + S(600), ≥1,5× su valor). | "Necesito tres muchachos para un acto. Vuelven con choripán y un bolsón de regalo." |
| Puntero Político | bolsón | 1 paquete; 2 con video. | "Te dejo un bolsón. No preguntes de dónde sale ni quién lo manda." |
| Ministro de Economía | subsidio | S(1200); ×2 video. | "Subsidio focalizado a tu empresa. Focalizado en vos, sí." |
| Vecina Chusma | chisme | Te adelanta cuál es el próximo evento + S(300). | "¿Viste lo que dicen? Que se viene un evento… ¡yo no dije nada!" |
| Vecina Chusma | favor | 15 toques en 20 s → 1 paquete; ×2 video. | "Nene, ayudame con las bolsas del súper que me duele la cintura." |
| Vendedor Ambulante | ofertas | 3 cartas por video: Mate (contratar −30 % 90 s), Café (tap ×2 60 s), Turbo (×3 60 s). | "¡Llevá, llevá! Boost calentito, recién salido del horno. Con video te lo regalo." |
| Conductor de TV | ruleta | Abre la ruleta y da +1 giro gratis por día. | "¡Y ahora… el momento que todos esperaban… LA RULETA! ¡Aplausos!" |
| Crypto Bro | señal | Ingresos ×2 por 60 s; ×2 video. | "Hermano, vi una señal: todo en verde. Duplicá por un minuto y no preguntes cómo." |
| Contador de Dios | crédito | S(2400). | "Encontré un crédito fiscal en una dimensión que ni sabías que tenías." |
| Zombie CEO | reto | 40 toques en 30 s → ×2 por 90 s. | "No… duermo… hace… tres… quinquenios. ¿Tocamos… cuarenta… veces?" |
| Lizard | lengua | Tap ×3 por 45 s. | "Sssí, soy de este barrio. Tocá, tocá, que te rinde por tres." |
| Alien Investor | inversión | S(1500); ×2 video. | "Mi planeta invierte en tu esquina. No entendemos la economía, pero nos gusta el dulce de leche." |
| Bug de la Simulación | reinicio | Reinicia los cooldowns de todos los boosts. | "Encontré un bug en la Matrix: tus cooldowns se reiniciaron. Que no se entere nadie." |
| El del Arbolito | cambio | 1 ORO por S(5400); tope 3 ORO por día. | "¡Cambio, cambio, cambiooo! Plata por ORO, buen precio, sin preguntar." |
| El del Arbolito | blue (sólo en Cepo) | ×1,5 ORO por plata, sin tope (compensa el +50 %). | "Con el cepo el único que te cambia soy yo… ¡al blue, ni preguntes!" |
| Coach Ontológico | reto | 60 toques en 30 s → ×2 por 120 s. Si no llegás, "es un proceso" (sin castigo). | "¿Y si el techo era una creencia limitante? Dale: sesenta toques, ahora." |

**Eventos**: lo anuncia su presentador; duran 30–90 s.

| Evento | Pol. | Efecto | Presenta | Frase | Escape |
|---|---|---|---|---|---|
| Plan Platita | + | ×3 por 60 s | Ministro | "¡Plan Platita! Imprimimos alegría ×3 por un minuto. No preguntes de dónde sale." | — |
| Startup comprada | + | Evolución gratis (con revelación, ver E1) | Conductor | "¡Última hora! Una big tech te compró la startup. Tu mejor empleado evoluciona gratis." | — |
| Devaluación | − | ×0,5 por 90 s | Ministro | "Pequeño ajuste técnico: tu plata vale la mitad por un rato. Es por tu bien." | video |
| Blanqueo | + | Unidad gratis (frontera − 3) | Ministro | "Blanqueo de capitales: apareció un empleado top que siempre estuvo declarado." | — |
| Se cayó el home banking | − | Contratar ×2 por 60 s | Vendedor | "¡Se cayó el home banking! Hoy sólo efectivo: todo sale el doble." | video |
| Inversión Alienígena | + | ×5 por 30 s | Alien Investor | "Inversores de otra galaxia apuestan por vos: ×5. No entienden la economía argentina." | — |
| Corralito | − | No podés gastar por 45 s; los ingresos siguen | Ministro | "Corralito express: tu plata está, pero no la podés tocar. ¿Te suena?" | video |
| Aguinaldo | + | S(300) | Sindicalista | "¡Aguinaldo conseguido! Disfrutalo antes de que se licúe." | — |
| ¡Salimos campeones! | + | ×4 por 60 s + baile + confeti | Conductor | "¡¡SALIMOS CAMPEONES!! Todo el mundo festeja y la caja se multiplica ×4." | — |
| Liquidación Total | + | Contratar ×0,5 por 60 s (precio tachado) | Vendedor | "¡Liquidación total! Contratar sale la mitad. ¡Llevá, llevá, que no se repite!" | — |
| Feriado Puente | + | Tap ×3 por 60 s | Sindicalista | "Feriado puente por decreto: cada toque vale ×3. Descansar es trabajar." | — |
| Lluvia de Paquetes | + | Paquetes ×10 por 60 s | Puntero | "¡Llegaron los bolsones! Lluvia de paquetes: andá recogiendo, muchachos." | — |
| Paro General | − | Pasivo ×0 por 30 s | Sindicalista | "¡Paro general! Hoy no produce ni el loro. Pagá la cuota o esperá que se negocie." | cuota S(120) o video |
| Apagón | − | ×0,3 por 45 s, con velitas | Vecina | "¡Se cortó la luz en todo el barrio! Prendé velitas tocando a tus empleados." | velitas o video |
| Hiperinflación | mixto | Contratar ×2 + ingresos ×3 por 60 s | Ministro | "Hiperinflación controlada: contratar sale el doble, pero la caja rinde ×3." | video (saca sólo el ×2) |
| Cepo Cambiario | − | Contratar ×1,5 por 60 s + aparece el Arbolito | Ministro | "Cepo cambiario: contratar +50 %. Pero aparece un señor que cambia al blue." | video |
| Piquete en la autopista | − | Sin paquetes por 90 s | Vecina | "Piquete en la autopista: no llegan los paquetes por 90 s. Yo vi todo desde el balcón." | video |
| Ola de Calor | − | Tap ×0,5 por 45 s | Vecina | "¡Ola de calor! Nadie quiere moverse: tus toques valen la mitad." | video |

### Anexo B — Biblia de los 8 visitantes nuevos

Prompts en ASCII. Cada uno arranca con: *"Match EXACTLY the art style, line weight, proportions
and color treatment of the attached reference character — same game, same studio."* Después va el
descriptor. Cierre: *"Full body standing character, both feet planted on the ground, hands
visible, generous margins, centered on a plain pure white background, square image, no text, no
watermark, no cropping."* Sólo arquetipos: ni personas ni insignias reales.

| ID | Descriptor (EN, para el prompt) | Paleta | Poses (canónica · habla · acción) |
|---|---|---|---|
| `char_fisu_npc_comisario_v1` | a heavyset police chief with a thick mustache, navy cap with a plain gold badge shape, whistle on a cord, ticket booklet, generic uniform with no real insignia | azul marino, dorado, crema | dedo levantado · anota la multa |
| `char_fisu_npc_sindicalista_v1` | a stocky union organizer in a work vest, headband, holding a megaphone and a plain blank banner with no logo | rojo ladrillo, gris, amarillo | megáfono · puño en alto |
| `char_fisu_npc_turista_v1` | a tall tourist in a wide sun hat, camera around the neck, fanny pack, socks with sandals, folding map | turquesa, beige, rojo | señala el mapa · saca la foto |
| `char_fisu_npc_puntero_v1` | a local political fixer in a sleeveless jacket with a plain violet armband, carrying a big reusable bag of groceries, wide friendly grin | violeta, verde oliva, gris | palmada · entrega el bolsón |
| `char_fisu_npc_ministro_v1` | an economy minister in a gray suit and thick glasses, briefcase, holding a chart board with a downward arrow | gris, azul, verde billete | señala el gráfico · tacha números |
| `char_fisu_npc_vecina_v1` | a nosy neighbor in a house dress and hair curlers, leaning on a broom, hand beside her mouth whispering | rosa, celeste, lila | cuchichea · mira con prismáticos |
| `char_fisu_npc_vendedor_v1` | a street vendor with an enormous backpack and a hanging tray of mate gourds, socks and gadgets, whistle | naranja, marrón, verde | ofrece · abre el abrigo lleno de cosas |
| `char_fisu_npc_conductor_v1` | a flashy TV host in a shiny jacket with a huge smile, holding a microphone | magenta, dorado, celeste | brazos abiertos · gira una ruleta imaginaria |

## 5. Producción de arte y animación

**Metodología** (de `content-urbe/design-system/biblia/personajes.md`):

- **Biblia de visitantes** en `Docs/biblia-visitantes.md`. Una fila por personaje con:
  - ID `char_fisu_<nombre>_v1`;
  - quién es;
  - referencia canónica;
  - descriptor en inglés para pegar en el prompt;
  - poses;
  - dónde aparece.
- **Variantes**: cada una sale de la canónica con un solo cambio.
- **Estilo**: estilo maestro del juego más la referencia `Tools/asset-pipeline/heroes/approved/fisura.png`. Prompts en ASCII puro.

**Generación con ChatGPT web**:

- Proyecto `projects/fisu-evolution-v2/` en `automatic-image-generation`: motor `chat-gpt`,
  salida `game-asset`, tamaños `[384, 512]`. Con el tope de celda de iPad no hace falta 768. Los
  fondos se exportan aparte, a 2048.
- Se encadena: la canónica primero, y cada pose adjunta la canónica.
- Integración: `Tools/asset-pipeline/dropbox/` → alta en `prompts/prompts.json` →
  `process_dropbox.py` → atlas + `assets_manifest.json`.
- **Gates humanos**:
  1. Login en el Chrome aislado de ChatGPT (`--launch`), más `--probe` con una palabra tipeada.
     El motor está "medio verificado".
  2. **El batch lo corre el dueño con la app de Claude cerrada**: la app de Claude le roba el
     foco al tipeo (medido).
  - Plan B: los mismos prompts con el motor `gemini`, verificado en 335 imágenes.

**Inventario estimado (~200 imágenes)**:

| Grupo | Piezas |
|---|---|
| 8 visitantes nuevos | canónica + hablando + acción, y la cara para chip y álbum ≈ 32 |
| 10 especiales existentes | pose "hablando" + cara ≈ 20 |
| Paquete de la Aduana | caja cerrada con sello, caja abriéndose, cartel LLENO, tapa ≈ 5 |
| El Colchón | cerrado y abierto con plata ≈ 3 |
| Ruleta | marco, puntero, centro, íconos de segmento ≈ 6 |
| Tienda de ORO | íconos de ítems ≈ 14 |
| Álbum de especiales | marco de carta, silueta ≈ 2 |
| Familias de skins | Pijama, Gaucho, Dinosaurio = 3 × 43 = 129 |
| Fondos | 10 regenerados con ChatGPT a 2048 px (con el original como referencia). Los personajes no necesitan nada nuevo: el tope de celda de iPad los deja ≤1,18× |

**Higgsfield (tope 600 créditos)**:

- Kling v3.0 image-to-video desde la canónica, sobre fondo verde liso, para recortar con el
  pipeline del cofre (`chest_video_frames.py` → HEVC con alfa). Los retratos van enmarcados y no
  necesitan alfa.
- Estimado, con reintentos incluidos (detalle en E8):
  - 18 retratos (Kling) ≈ 170;
  - reencarnación ≈ 80, arresto ≈ 60 y Dios ≈ 150 (Seedance 2.5, por calidad);
  - reserva ≈ 90.
- Total ≈ **550 ≤ 600**. Primero un piloto de 2 loops mide el costo real; si las cinemáticas con
  Kling salen bien, se ahorra ~150.

**Por código**: entradas y salidas de visitantes, globos, squash & stretch, caja y colchón,
ruleta, confeti, monedas que vuelan al contador, chips, efectos de skin (SKShader), la
**botonera del ascensor** (persiana metálica, display LED con dígitos que ruedan, luces de piso),
la cadena de "Fusionar todo" y la aparición de pestañas nuevas. Las reacciones de campo no se
portan: la rama quedó descartada por el dueño. Sonidos nuevos, sintetizados como los de la v1:
`sfx_wheel_tick`, `sfx_blackout` y `sfx_elevator_ding`. **Todo respeta la identidad visual
establecida** (FisuJobs, materiales v3, paleta e iconografía del juego).

**Música por piso** (decisión del dueño):

- 10 temas chiptune, uno por piso, sintetizados con el generador de la v1
  (`git show v1.0.0-build4:Tools/audio-synth/generate_audio.py`, sin licencias). Cada tema
  refleja su piso: callejón, ciudad, corporativo, lujo, isla, Luna, Marte, sistema solar, galaxia
  y reino divino.
- **Crossfade de ~1,5 s al cambiar de piso** (scroll o ascensor) en `AudioManager`, con un solo
  tema sonando. Respeta el volumen de música de Ajustes.
- Peso: ~10 loops comprimidos (AAC/CAF); se mide el bundle.

## 6. Riesgos y cumplimiento

| Riesgo | Mitigación |
|---|---|
| **Apple 3.1.1, loot boxes**: la ruleta extra y los cofres por ORO son azar con moneda comprable | Probabilidades **visibles antes de comprar**. Al cuestionario de edad se le suma "loot boxes" (en Australia, M15+). |
| Apuesta simulada (13+/18+; en Australia, R18+) | **Ninguna mecánica de apostar plata.** El Crypto Bro no apuesta. |
| Apple 5.2.1, marcas | Se renombra "Cayó Mercado Pago". Parodias, nunca marcas. |
| Sátira política (Puntero, Ministro, Sindicalista) | Sólo arquetipos: sin nombres, partidos ni caras reales. La guía 1.1.1 exime a la sátira, y el texto del juego no apunta a grupos protegidos. |
| Política de AdMob | Intersticiales **sólo en pausas naturales**, nunca uno pegado al otro. El intersticial bonificado lleva **pantalla previa con opción de rechazarlo**. App open sólo al volver. Dispositivos de prueba registrados. |
| Memecoin | **Cero menciones o links en la app** (guías 3.1.1/3.1.5 y CNV RG 1058). |
| `UIRequiresFullScreen` deprecada | Funciona compilando con Xcode 26. Al pasar al SDK de iOS 27 (obligatorio hacia abril de 2027) habrá que soportar ventanas redimensionables. Queda anotado en el HANDOFF. |
| Migración del save v5 → v6 | Backup del save previo. **Si falla el decode, nunca se sobrescribe**: se avisa y se restaura. |
| Las fuentes nuevas acortan el juego | El simulador de pacing **modela** paquetes, ruleta, colchón, visitantes y tienda, o la calibración mide una ficción. |
| Otra sesión trabajando en `version-2` | Worktrees aislados, commits rápidos y staging selectivo (protocolo de la memoria). |
| Motor de ChatGPT "medio verificado" | `--probe` primero; plan B con Gemini y los mismos prompts. |
| iOS 18 como mínimo | Quien siga en iOS 17 no recibe la 2.0, pero conserva la v1 instalada: no pierde el juego. |
| Muchos formatos forzados + ~15 lugares de video → retención | Interruptores de apagado y cadencia **remotos**: se ajustan sin build nuevo. remove_ads como válvula. Se miran D1/D7 en AdMob y App Store Connect después del lanzamiento. |
| Peso del bundle (+~44 MB por las 3 familias, +loops y cinemáticas) | Atlas por familia. On-Demand Resources queda para después si el peso molesta. |
| Fondos regenerados distintos al original | Se adjunta el original como referencia y se comparan lado a lado; si uno sale peor, queda el viejo. |
| Revisión de Apple más estricta (azar con ORO, muchos anuncios) | Probabilidades a la vista, notas de revisión detalladas (E10) y cuestionario de edad actualizado. |

## 7. Fuera de alcance de la 2.0

- La **memecoin Fisu Coin** (proyecto aparte, con asesoría legal).
- El **script de Selenium que automatice App Store Connect y AdMob**: queda anotado como trabajo
  futuro, y su insumo va a ser el doc de configuración de la épica E10.
- Game Center e iCloud (siguen apagados por flag).
- El iPad en horizontal.
- Los videos publicitarios para redes (próxima etapa).

## 8. Verificación de punta a punta

- **Por tarea**:
  1. EconomyKit `swift test`;
  2. unit;
  3. UI, en la matriz iOS 26.5 / 18.6, con simulador propio y `-derivedDataPath` absoluto;
  4. `pacing-sim`: la línea de base y después la nueva.
  - Los tests contrato nuevos van **en rojo antes del fix**.
- **Escenarios clave**, con el reloj inyectado donde aplique:
  - vuelta en caliente después de 1 h → popup con ganancias y ×2 por video;
  - evento "Startup comprada" en segundo plano → la revelación se reproduce al volver;
  - carreras: contratación gratis 2 min, Juicio ganado y Obra social;
  - reset con ORO comprado gastado y sin gastar;
  - tutorial: el botón de seguir bloqueado 5 s y sin salteo;
  - pin del atajo y botón deshabilitado con su motivo;
  - deslizar el menú entre las 6 pestañas;
  - nombres de IAP en dispositivos es-AR, es-ES y en-US;
  - anuncios con IDs de prueba más el Ad Inspector de AdMob para la mediación;
  - config remota caída → se usa el respaldo del bundle;
  - **crítica de Marco**:
    - 15 lugares en el SE sin pisar el HUD ni las columnas;
    - "Fusionar todo" con un tier nuevo en el medio, que se celebra;
    - la luz del piso en marcha y el +% aplicado (contrato);
    - el botón de reencarnar bloqueado hasta la pared anterior;
    - la botonera se despliega y recoge sin cortar el scroll;
    - las pestañas aparecen de a una en una partida nueva y están todas para un veterano.
- **Dispositivos** (capturas comparadas): iPhone SE, 16 Pro y Pro Max; iPad mini, Air 11" y Pro 13".
- **Archive desde cero** con build nuevo. Verificar en el `.app`:
  - `UIDeviceFamily = [1,2]`;
  - `UIRequiresFullScreen`;
  - `NSPrivacyTracking = false`;
  - `GADApplicationIdentifier`;
  - los SKAdNetwork IDs de las 4 redes.
- **TestFlight**: playtest del dueño de 1–2 días antes de mandar a revisión.
